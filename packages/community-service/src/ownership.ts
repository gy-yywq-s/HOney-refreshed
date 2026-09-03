// "Your posts" and revoke (spec §34): challenge–response signed with the
// school/year posting key (mine) or the per-post control key (revoke). No
// HOney session anywhere. A revoked post is deleted, which also frees the
// one-post-per-primary slot for that posting identity.

import { randomBytes } from "node:crypto";
import type { DatabaseSync } from "node:sqlite";
import { authorTag, fromBase64Url, verifyStatement, type MineExperience, type MineRequest, type RevokeRequest } from "@honey/shared/community-v2";

const CHALLENGE_TTL_MS = 5 * 60_000;
const B64URL = /^[A-Za-z0-9_-]+$/;

export class OwnershipService {
  constructor(
    private readonly db: DatabaseSync,
    private readonly schoolId: string,
    private readonly now: () => number = Date.now,
  ) {}

  challenge(purpose: "honey/v2/mine" | "honey/v2/revoke"): { challenge: string; expiresAt: number } {
    this.db.prepare("DELETE FROM challenges WHERE expires_at < ?").run(this.now());
    const challenge = randomBytes(24).toString("base64url");
    const expiresAt = this.now() + CHALLENGE_TTL_MS;
    this.db.prepare("INSERT INTO challenges (challenge, purpose, expires_at) VALUES (?, ?, ?)").run(challenge, purpose, expiresAt);
    return { challenge, expiresAt };
  }

  /** Consume the challenge (single use); false when unknown, expired or for another purpose/expiry. */
  private takeChallenge(challenge: unknown, purpose: string, expiresAt: unknown): boolean {
    if (typeof challenge !== "string" || typeof expiresAt !== "number") return false;
    const row = this.db.prepare("SELECT purpose, expires_at FROM challenges WHERE challenge = ?").get(challenge) as { purpose: string; expires_at: number } | undefined;
    if (!row || row.purpose !== purpose || row.expires_at !== expiresAt || row.expires_at < this.now()) return false;
    this.db.prepare("DELETE FROM challenges WHERE challenge = ?").run(challenge);
    return true;
  }

  mine(req: MineRequest): { ok: true; experiences: MineExperience[] } | { ok: false; error: string } {
    const s = req?.statement;
    if (!s || s.purpose !== "honey/v2/mine" || s.schoolId !== this.schoolId || typeof s.academicYear !== "string") return { ok: false, error: "statement_invalid" };
    if (typeof req.postingPublicKey !== "string" || !B64URL.test(req.postingPublicKey) || fromBase64Url(req.postingPublicKey).length !== 32) return { ok: false, error: "statement_invalid" };
    if (typeof req.signature !== "string" || !B64URL.test(req.signature)) return { ok: false, error: "signature_invalid" };
    if (!this.takeChallenge(s.challenge, "honey/v2/mine", s.expiresAt)) return { ok: false, error: "challenge_invalid" };
    if (!verifyStatement(fromBase64Url(req.postingPublicKey), s as never, fromBase64Url(req.signature))) return { ok: false, error: "signature_invalid" };
    const tag = authorTag(fromBase64Url(req.postingPublicKey));
    const rows = this.db
      .prepare(
        `SELECT id, primary_entity_type, primary_entity_id, body, rating, provenance, status, status_detail, post_nonce, control_public_key, created_at
         FROM experiences WHERE school_id = ? AND academic_year = ? AND author_tag = ? ORDER BY created_at DESC LIMIT 500`,
      )
      .all(this.schoolId, s.academicYear, tag) as {
        id: string; primary_entity_type: string; primary_entity_id: string; body: string | null; rating: number | null; provenance: string;
        status: string; status_detail: string | null; post_nonce: string; control_public_key: string; created_at: number;
      }[];
    const contexts = this.db.prepare("SELECT entity_type, entity_id FROM experience_associations WHERE experience_id = ? AND relationship = 'context'");
    return {
      ok: true,
      experiences: rows.map((r) => ({
        id: r.id,
        primaryEntity: { type: r.primary_entity_type, id: r.primary_entity_id, name: null },
        contexts: (contexts.all(r.id) as { entity_type: string; entity_id: string }[]).map((c) => ({ type: c.entity_type, id: c.entity_id, name: null })),
        body: r.body,
        rating: r.rating,
        provenance: r.provenance,
        status: r.status === "blocked" ? "blocked" : "published",
        statusDetail: r.status_detail,
        postNonce: r.post_nonce,
        controlPublicKey: r.control_public_key,
        createdAt: r.created_at,
      })),
    };
  }

  revoke(experienceId: string, req: RevokeRequest): { ok: true } | { ok: false; error: string } {
    const s = req?.statement;
    if (!s || s.purpose !== "honey/v2/revoke" || s.experienceId !== experienceId) return { ok: false, error: "statement_invalid" };
    if (typeof req.signature !== "string" || !B64URL.test(req.signature)) return { ok: false, error: "signature_invalid" };
    const row = this.db.prepare("SELECT control_public_key FROM experiences WHERE id = ? AND school_id = ?").get(experienceId, this.schoolId) as { control_public_key: string } | undefined;
    if (!row) return { ok: false, error: "not_found" };
    if (!this.takeChallenge(s.challenge, "honey/v2/revoke", s.expiresAt)) return { ok: false, error: "challenge_invalid" };
    if (!verifyStatement(fromBase64Url(row.control_public_key), s as never, fromBase64Url(req.signature))) return { ok: false, error: "signature_invalid" };
    this.db.prepare("DELETE FROM experiences WHERE id = ?").run(experienceId);
    return { ok: true };
  }
}
