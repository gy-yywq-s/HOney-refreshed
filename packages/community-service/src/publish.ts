// Identity-free check + publish (spec §32). Check: verify token + scope,
// reserve, verify posting signature, suspension, moderation → lane (+ a
// content-bound pass). Publish: verify the pass binds this exact envelope,
// consume the token once, compute the authorTag, insert. Nothing here knows
// an account; the strikes that used to count on the account count on the
// school/year posting identity.

import { createHmac, randomUUID, timingSafeEqual } from "node:crypto";
import type { DatabaseSync } from "node:sqlite";
import {
  authorTag,
  fromBase64Url,
  tokenHash,
  verifyStatement,
  type CheckErrorV2,
  type CheckRequestV2,
  type CheckResponseV2,
  type PublishErrorV2,
  type PublishRequestV2,
  type PublishResponseV2,
  type SignedPostEnvelopeV2,
} from "@honey/shared/community-v2";
import { computeDecision, POLICY_VERSION, type LlmRunner, type PolicyDecision } from "./moderation/index.js";
import { bodyHashOf, contextHashOf, issuePass, openPass } from "./passes.js";
import type { CommunitySettings } from "./settings.js";
import type { TokenRedemption } from "./token-redemption.js";

const PASS_TTL_MS = 10 * 60_000;
const COOLDOWN_TICKET_LIFE_MS = 7 * 24 * 3600 * 1000;
const B64URL = /^[A-Za-z0-9_-]+$/;
const ENTITY_TYPES = new Set(["teacher", "course", "room", "dish", "lesson"]);

export type CheckOutcome = { ok: true; response: CheckResponseV2 } | { ok: false; error: CheckErrorV2 };
export type PublishOutcome = { ok: true; response: PublishResponseV2 } | { ok: false; error: PublishErrorV2 };

function validEnvelope(e: unknown, schoolId: string): e is SignedPostEnvelopeV2 {
  if (!e || typeof e !== "object") return false;
  const x = e as Record<string, unknown>;
  if (x.protocolVersion !== 2 || x.schoolId !== schoolId || typeof x.academicYear !== "string") return false;
  const p = x.primaryEntity as { type?: unknown; id?: unknown } | undefined;
  if (!p || typeof p.type !== "string" || !ENTITY_TYPES.has(p.type) || typeof p.id !== "string" || !p.id) return false;
  const c = x.contexts as Record<string, unknown> | undefined;
  if (!c || typeof c !== "object") return false;
  for (const k of ["lessonId", "courseId", "teacherId", "roomId", "topicName"]) {
    if (c[k] !== undefined && (typeof c[k] !== "string" || (c[k] as string).length > 200)) return false;
  }
  if (typeof x.body !== "string") return false;
  if (x.rating !== null && (typeof x.rating !== "number" || !Number.isInteger(x.rating) || x.rating < 1 || x.rating > 5)) return false;
  for (const k of ["postNonce", "postingPublicKey", "controlPublicKey"]) {
    if (typeof x[k] !== "string" || !B64URL.test(x[k] as string) || fromBase64Url(x[k] as string).length !== 32) return false;
  }
  if (typeof x.clientNonce !== "string" || x.clientNonce.length < 8 || x.clientNonce.length > 64) return false;
  return true;
}

function contextsMatch(envelope: SignedPostEnvelopeV2, info: CheckRequestV2["token"]["info"]): boolean {
  const keys = ["lessonId", "courseId", "teacherId", "roomId"] as const;
  return keys.every((k) => (envelope.contexts[k] ?? null) === (info.contexts[k] ?? null));
}

export class PublicationService {
  llmRunner: LlmRunner;
  now: () => number;
  private readonly signKey: Buffer;
  private readonly cooldownKey: Buffer;

  constructor(
    private readonly db: DatabaseSync,
    private readonly settings: CommunitySettings,
    private readonly redemption: TokenRedemption,
    private readonly schoolId: string,
    sealKey: Buffer,
    llmRunner: LlmRunner,
    now: () => number = Date.now,
  ) {
    this.llmRunner = llmRunner;
    this.now = now;
    this.signKey = createHmac("sha256", sealKey).update("community/pass").digest();
    this.cooldownKey = createHmac("sha256", sealKey).update("community/cooldown").digest();
  }

  private frozenAnywhere(envelope: SignedPostEnvelopeV2): boolean {
    const keys = [`${envelope.primaryEntity.type}:${envelope.primaryEntity.id}`];
    if (envelope.contexts.teacherId) keys.push(`teacher:${envelope.contexts.teacherId}`);
    if (envelope.contexts.roomId) keys.push(`room:${envelope.contexts.roomId}`);
    if (envelope.contexts.courseId) keys.push(`course:${envelope.contexts.courseId}`);
    return keys.some((k) => this.settings.frozenEntity(k));
  }

  private suspended(envelope: SignedPostEnvelopeV2, tag: string): boolean {
    const row = this.db
      .prepare("SELECT suspended_until FROM community_suspensions WHERE school_id = ? AND academic_year = ? AND author_tag = ?")
      .get(envelope.schoolId, envelope.academicYear, tag) as { suspended_until: number | null } | undefined;
    return !!row?.suspended_until && row.suspended_until > this.now();
  }

  private alreadyPosted(envelope: SignedPostEnvelopeV2, tag: string): boolean {
    return !!this.db
      .prepare(
        "SELECT 1 FROM experiences WHERE school_id = ? AND academic_year = ? AND author_tag = ? AND primary_entity_type = ? AND primary_entity_id = ?",
      )
      .get(envelope.schoolId, envelope.academicYear, tag, envelope.primaryEntity.type, envelope.primaryEntity.id);
  }

  /** §21 strikes on the posting identity, not on any account. */
  private recordProhibitedAttempt(envelope: SignedPostEnvelopeV2, tag: string): void {
    const THRESHOLD = 3;
    const SUSPEND_MS = 7 * 24 * 3600 * 1000;
    const row = this.db
      .prepare("SELECT blocked_attempts FROM community_suspensions WHERE school_id = ? AND academic_year = ? AND author_tag = ?")
      .get(envelope.schoolId, envelope.academicYear, tag) as { blocked_attempts: number } | undefined;
    const count = (row?.blocked_attempts ?? 0) + 1;
    this.db
      .prepare(
        `INSERT INTO community_suspensions (school_id, academic_year, author_tag, blocked_attempts, suspended_until) VALUES (?, ?, ?, ?, ?)
         ON CONFLICT(school_id, academic_year, author_tag) DO UPDATE SET
           blocked_attempts = excluded.blocked_attempts,
           suspended_until = COALESCE(excluded.suspended_until, community_suspensions.suspended_until)`,
      )
      .run(envelope.schoolId, envelope.academicYear, tag, count, count >= THRESHOLD ? this.now() + SUSPEND_MS : null);
  }

  // ---- cooldown tickets (stateless) ----
  private cooldownSig(bodyHash: string, scope: string, notBefore: number, expiresAt: number): string {
    return createHmac("sha256", this.cooldownKey).update([bodyHash, scope, notBefore, expiresAt].join("|")).digest("hex");
  }
  private issueCooldownTicket(bodyHash: string, scope: string, notBefore: number): string {
    const expiresAt = this.now() + COOLDOWN_TICKET_LIFE_MS;
    return Buffer.from(JSON.stringify({ nb: notBefore, exp: expiresAt, s: this.cooldownSig(bodyHash, scope, notBefore, expiresAt) })).toString("base64url");
  }
  private verifyCooldownTicket(ticket: string, bodyHash: string, scope: string): { ok: true; notBefore: number } | { ok: false } {
    try {
      const parsed = JSON.parse(Buffer.from(ticket, "base64url").toString("utf8")) as { nb: number; exp: number; s: string };
      if (typeof parsed.nb !== "number" || typeof parsed.exp !== "number" || typeof parsed.s !== "string" || parsed.exp <= this.now()) return { ok: false };
      const expected = Buffer.from(this.cooldownSig(bodyHash, scope, parsed.nb, parsed.exp), "hex");
      const given = Buffer.from(parsed.s.padEnd(64, "0").slice(0, 64), "hex");
      if (expected.length !== given.length || !timingSafeEqual(expected, given)) return { ok: false };
      return { ok: true, notBefore: parsed.nb };
    } catch {
      return { ok: false };
    }
  }

  private validate(req: { envelope: unknown; postSignature: unknown; token: unknown }): CheckErrorV2 | null {
    if (!validEnvelope(req.envelope, this.schoolId)) return "envelope_invalid";
    const e = req.envelope;
    const body = e.body.trim();
    if (!body || body.length > 5000) return "body_invalid";
    if (e.rating !== null && e.primaryEntity.type !== "dish") return "rating_not_allowed";
    if (typeof req.postSignature !== "string" || !B64URL.test(req.postSignature)) return "signature_invalid";
    if (!verifyStatement(fromBase64Url(e.postingPublicKey), e as never, fromBase64Url(req.postSignature))) return "signature_invalid";
    return null;
  }

  async check(req: CheckRequestV2): Promise<CheckOutcome> {
    if (this.settings.killSwitch("DISABLE_NEW_PUBLICATIONS")) return { ok: false, error: "publications_disabled" };
    const invalid = this.validate(req);
    if (invalid) return { ok: false, error: invalid };
    const e = req.envelope;
    const tokenError = await this.redemption.verify(req.token);
    if (tokenError) return { ok: false, error: tokenError === "issuer_unavailable" ? "token_invalid" : tokenError };
    const info = req.token.info;
    if (info.schoolId !== e.schoolId || info.academicYear !== e.academicYear || info.scope !== `${e.primaryEntity.type}:${e.primaryEntity.id}` || !contextsMatch(e, info)) {
      return { ok: false, error: "token_scope_mismatch" };
    }
    const reserved = this.redemption.reserve(req.token);
    if (reserved) return { ok: false, error: reserved === "issuer_unavailable" ? "token_invalid" : reserved };
    const tag = authorTag(fromBase64Url(e.postingPublicKey));
    if (this.suspended(e, tag)) return { ok: false, error: "temporarily_suspended" };
    if (this.frozenAnywhere(e)) return { ok: false, error: "entity_frozen" };
    if (this.alreadyPosted(e, tag)) return { ok: false, error: "already_posted" };

    const body = e.body.trim();
    const bodyHash = bodyHashOf(body, e.rating);
    const scope = info.scope;
    let reconfirming = false;
    if (req.cooldownTicket !== undefined) {
      const ticket = this.verifyCooldownTicket(req.cooldownTicket, bodyHash, scope);
      if (!ticket.ok) return { ok: false, error: "cooldown_ticket_invalid" };
      if (ticket.notBefore > this.now()) {
        return { ok: true, response: { lane: "cooldown", reasons: ["cooldown_active"], policyVersion: POLICY_VERSION, cooldown: { ticket: req.cooldownTicket, retryAt: ticket.notBefore } } };
      }
      reconfirming = true;
    }
    let decision = await computeDecision(body, e.primaryEntity.type, e.rating, this.llmRunner);
    if (reconfirming && decision.action === "cooldown_24h") decision = { ...decision, action: "publish" };
    if (decision.action === "blocked_serious") this.recordProhibitedAttempt(e, tag);
    return { ok: true, response: this.laneOf(decision, e, bodyHash, req) };
  }

  private laneOf(decision: PolicyDecision, e: SignedPostEnvelopeV2, bodyHash: string, req: CheckRequestV2): CheckResponseV2 {
    const base = { reasons: decision.reasons, policyVersion: decision.policyVersion };
    switch (decision.action) {
      case "publish":
      case "publish_nudge": {
        const pass = issuePass(
          {
            bodyHash,
            contextHash: contextHashOf(e),
            schoolId: e.schoolId,
            academicYear: e.academicYear,
            postingPublicKey: e.postingPublicKey,
            controlPublicKey: e.controlPublicKey,
            postNonce: e.postNonce,
            tokenHash: tokenHash(req.token),
            policyVersion: decision.policyVersion,
          },
          this.signKey,
          PASS_TTL_MS,
          this.now(),
        );
        return { ...base, lane: decision.action === "publish_nudge" ? "nudge" : "publish", pass };
      }
      case "cooldown_24h": {
        const notBefore = this.now() + this.settings.cooldownHours() * 3600 * 1000;
        return { ...base, lane: "cooldown", cooldown: { ticket: this.issueCooldownTicket(bodyHash, req.token.info.scope, notBefore), retryAt: notBefore } };
      }
      case "rephrase_required":
        return { ...base, lane: "edit_required" };
      case "blocked_serious":
        return { ...base, lane: "blocked_serious" };
      case "blocked_out_of_scope":
        return { ...base, lane: "out_of_scope" };
      case "failed_closed":
        return { ...base, lane: "failed_closed" };
    }
  }

  async publish(req: PublishRequestV2): Promise<PublishOutcome> {
    if (this.settings.killSwitch("DISABLE_NEW_PUBLICATIONS")) return { ok: false, error: "publications_disabled" };
    const invalid = this.validate(req);
    if (invalid) return { ok: false, error: invalid };
    const e = req.envelope;
    if (typeof req.pass !== "string") return { ok: false, error: "pass_invalid" };
    const pass = openPass(req.pass, this.signKey, this.now());
    if (!pass) return { ok: false, error: "pass_invalid" };
    const tokenError = await this.redemption.verify(req.token);
    if (tokenError) return { ok: false, error: tokenError === "issuer_unavailable" ? "token_invalid" : tokenError };
    const body = e.body.trim();
    if (
      pass.bodyHash !== bodyHashOf(body, e.rating) ||
      pass.contextHash !== contextHashOf(e) ||
      pass.schoolId !== e.schoolId ||
      pass.academicYear !== e.academicYear ||
      pass.postingPublicKey !== e.postingPublicKey ||
      pass.controlPublicKey !== e.controlPublicKey ||
      pass.postNonce !== e.postNonce ||
      pass.tokenHash !== tokenHash(req.token)
    ) {
      return { ok: false, error: "pass_mismatch" };
    }
    if (this.frozenAnywhere(e)) return { ok: false, error: "entity_frozen" };
    if (this.db.prepare("SELECT 1 FROM content_pass_nonces WHERE nonce = ?").get(pass.nonce)) return { ok: false, error: "pass_invalid" };
    const tag = authorTag(fromBase64Url(e.postingPublicKey));
    if (this.suspended(e, tag)) return { ok: false, error: "temporarily_suspended" };

    const id = randomUUID();
    const now = this.now();
    this.db.exec("BEGIN");
    try {
      this.db.prepare("INSERT INTO content_pass_nonces (nonce, used_at) VALUES (?, ?)").run(pass.nonce, now);
      const consumed = this.redemption.consume(req.token);
      if (consumed) {
        this.db.exec("ROLLBACK");
        return { ok: false, error: consumed === "issuer_unavailable" ? "token_invalid" : consumed };
      }
      try {
        this.db
          .prepare(
            `INSERT INTO experiences (id, school_id, academic_year, primary_entity_type, primary_entity_id, body, rating, provenance,
               status, policy_version, author_tag, posting_public_key, post_nonce, control_public_key, content_hash, client_nonce,
               published_day, created_at)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'published', ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
          )
          .run(
            id, e.schoolId, e.academicYear, e.primaryEntity.type, e.primaryEntity.id, body, e.rating, req.token.info.provenance,
            pass.policyVersion, tag, e.postingPublicKey, e.postNonce, e.controlPublicKey, pass.bodyHash, e.clientNonce,
            Math.floor(now / 86_400_000), now,
          );
      } catch (err) {
        this.db.exec("ROLLBACK");
        if (err instanceof Error && /UNIQUE/.test(err.message)) return { ok: false, error: "already_posted" };
        throw err;
      }
      const assoc = this.db.prepare("INSERT OR IGNORE INTO experience_associations (experience_id, entity_type, entity_id, relationship) VALUES (?, ?, ?, ?)");
      assoc.run(id, e.primaryEntity.type, e.primaryEntity.id, "primary");
      if (e.contexts.lessonId && e.primaryEntity.type !== "lesson") assoc.run(id, "lesson", e.contexts.lessonId, "context");
      if (e.contexts.courseId) assoc.run(id, "course", e.contexts.courseId, "context");
      if (e.contexts.teacherId) assoc.run(id, "teacher", e.contexts.teacherId, "context");
      if (e.contexts.roomId) assoc.run(id, "room", e.contexts.roomId, "context");
      this.db.exec("COMMIT");
    } catch (err) {
      try {
        this.db.exec("ROLLBACK");
      } catch {
        /* already rolled back */
      }
      throw err;
    }
    return { ok: true, response: { ok: true, experienceId: id, postNonce: e.postNonce } };
  }
}
