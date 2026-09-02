// Reactions and reports (spec §29.2, §34.3): a purpose-separated per
// school/year reactor key, registered once with a membership token, signs
// every reaction/report. Community sees a reactor tag — a hash of that key —
// never an account, and never joins it with the posting identity.

import { randomUUID } from "node:crypto";
import type { DatabaseSync } from "node:sqlite";
import {
  fromBase64Url,
  reactorTag,
  verifyStatement,
  type ReactRequestV2,
  type RegisterReactorRequest,
  type ReportRequestV2,
} from "@honey/shared/community-v2";
import { computeDecision, POLICY_VERSION, type LlmRunner } from "./moderation/index.js";
import type { CommunitySettings } from "./settings.js";
import type { TokenRedemption } from "./token-redemption.js";

const B64URL = /^[A-Za-z0-9_-]+$/;
const REPORT_CATEGORIES = new Set(["serious_allegation", "doxxing", "slur", "targets_student", "not_experience", "other_rule"]);
const REPORT_RETRY_MS = 30 * 60_000;
const REPORT_RATE_WINDOW_MS = 24 * 3600 * 1000;
const REPORT_RATE_MAX = 10;

export class ReactionService {
  llmRunner: LlmRunner;
  now: () => number;

  constructor(
    private readonly db: DatabaseSync,
    private readonly settings: CommunitySettings,
    private readonly redemption: TokenRedemption,
    private readonly schoolId: string,
    llmRunner: LlmRunner,
    now: () => number = Date.now,
  ) {
    this.llmRunner = llmRunner;
    this.now = now;
  }

  /** One membership token registers one reactor key for the school/year. */
  async register(req: RegisterReactorRequest): Promise<{ ok: true } | { ok: false; error: string }> {
    const s = req?.statement;
    if (!s || s.purpose !== "honey/v2/register-reactor" || s.schoolId !== this.schoolId || typeof s.academicYear !== "string") return { ok: false, error: "statement_invalid" };
    if (typeof s.reactionPublicKey !== "string" || !B64URL.test(s.reactionPublicKey) || fromBase64Url(s.reactionPublicKey).length !== 32) return { ok: false, error: "statement_invalid" };
    if (typeof req.signature !== "string" || !B64URL.test(req.signature) || !verifyStatement(fromBase64Url(s.reactionPublicKey), s as never, fromBase64Url(req.signature))) {
      return { ok: false, error: "signature_invalid" };
    }
    const tag = reactorTag(fromBase64Url(s.reactionPublicKey));
    const existing = this.db.prepare("SELECT 1 FROM reactor_identities WHERE reactor_tag = ?").get(tag);
    if (existing) return { ok: true }; // idempotent: the key is already known
    const tokenError = await this.redemption.verify(req.token);
    if (tokenError) return { ok: false, error: tokenError === "issuer_unavailable" ? "token_invalid" : tokenError };
    const info = req.token.info;
    if (info.scope !== `school-member:${this.schoolId}` || info.schoolId !== s.schoolId || info.academicYear !== s.academicYear) return { ok: false, error: "token_scope_mismatch" };
    this.db.exec("BEGIN");
    try {
      const consumed = this.redemption.consume(req.token);
      if (consumed) {
        this.db.exec("ROLLBACK");
        return { ok: false, error: consumed === "issuer_unavailable" ? "token_invalid" : consumed };
      }
      this.db
        .prepare("INSERT INTO reactor_identities (reactor_tag, school_id, academic_year, public_key, registered_at) VALUES (?, ?, ?, ?, ?)")
        .run(tag, s.schoolId, s.academicYear, s.reactionPublicKey, this.now());
      this.db.exec("COMMIT");
    } catch (e) {
      this.db.exec("ROLLBACK");
      throw e;
    }
    return { ok: true };
  }

  private registered(reactionPublicKey: unknown, schoolId: unknown, academicYear: unknown): string | null {
    if (typeof reactionPublicKey !== "string" || !B64URL.test(reactionPublicKey) || fromBase64Url(reactionPublicKey).length !== 32) return null;
    const tag = reactorTag(fromBase64Url(reactionPublicKey));
    const row = this.db.prepare("SELECT public_key, school_id, academic_year FROM reactor_identities WHERE reactor_tag = ?").get(tag) as
      | { public_key: string; school_id: string; academic_year: string }
      | undefined;
    if (!row || row.public_key !== reactionPublicKey || row.school_id !== schoolId || row.academic_year !== academicYear) return null;
    return tag;
  }

  private takeNonce(nonce: unknown): boolean {
    if (typeof nonce !== "string" || nonce.length < 8 || nonce.length > 64) return false;
    if (this.db.prepare("SELECT 1 FROM reaction_nonces WHERE nonce = ?").get(nonce)) return false;
    this.db.prepare("INSERT INTO reaction_nonces (nonce, used_at) VALUES (?, ?)").run(nonce, this.now());
    return true;
  }

  private frozenPost(experienceId: string): boolean {
    const keys = this.db.prepare("SELECT entity_type, entity_id FROM experience_associations WHERE experience_id = ?").all(experienceId) as { entity_type: string; entity_id: string }[];
    return keys.some((k) => this.settings.frozenEntity(`${k.entity_type}:${k.entity_id}`));
  }

  private counts(experienceId: string): { likes: number; dislikes: number } | null {
    const c = this.db.prepare("SELECT SUM(value = 1) AS likes, SUM(value = -1) AS dislikes FROM reactions WHERE experience_id = ?").get(experienceId) as { likes: number | null; dislikes: number | null };
    const likes = c.likes ?? 0;
    const dislikes = c.dislikes ?? 0;
    return likes + dislikes >= this.settings.reactionMinCount() ? { likes, dislikes } : null;
  }

  react(experienceId: string, req: ReactRequestV2): { ok: true; value: 1 | -1 | 0; reactions: { likes: number; dislikes: number } | null } | { ok: false; error: string } {
    if (this.settings.killSwitch("DISABLE_REACTIONS")) return { ok: false, error: "reactions_disabled" };
    const s = req?.statement;
    if (!s || s.purpose !== "honey/v2/react" || s.experienceId !== experienceId || ![1, -1, 0].includes(s.value)) return { ok: false, error: "statement_invalid" };
    const tag = this.registered(req.reactionPublicKey, s.schoolId, s.academicYear);
    if (!tag) return { ok: false, error: "reactor_unregistered" };
    if (typeof req.signature !== "string" || !B64URL.test(req.signature) || !verifyStatement(fromBase64Url(req.reactionPublicKey), s as never, fromBase64Url(req.signature))) {
      return { ok: false, error: "signature_invalid" };
    }
    const row = this.db.prepare("SELECT 1 FROM experiences WHERE id = ? AND school_id = ? AND status = 'published'").get(experienceId, this.schoolId);
    if (!row) return { ok: false, error: "not_found" };
    if (this.frozenPost(experienceId)) return { ok: false, error: "entity_frozen" };
    if (!this.takeNonce(s.nonce)) return { ok: false, error: "nonce_used" };
    if (s.value === 0) {
      this.db.prepare("DELETE FROM reactions WHERE experience_id = ? AND reactor_tag = ?").run(experienceId, tag);
    } else {
      this.db
        .prepare("INSERT INTO reactions (experience_id, reactor_tag, value, created_at) VALUES (?, ?, ?, ?) ON CONFLICT(experience_id, reactor_tag) DO UPDATE SET value = excluded.value")
        .run(experienceId, tag, s.value, this.now());
    }
    return { ok: true, value: s.value, reactions: this.counts(experienceId) };
  }

  async report(experienceId: string, req: ReportRequestV2): Promise<{ ok: true } | { ok: false; error: string }> {
    if (this.settings.killSwitch("DISABLE_REPORTS")) return { ok: false, error: "reports_disabled" };
    const s = req?.statement;
    if (!s || s.purpose !== "honey/v2/report" || s.experienceId !== experienceId || !REPORT_CATEGORIES.has(s.category)) return { ok: false, error: "statement_invalid" };
    const tag = this.registered(req.reactionPublicKey, s.schoolId, s.academicYear);
    if (!tag) return { ok: false, error: "reactor_unregistered" };
    if (typeof req.signature !== "string" || !B64URL.test(req.signature) || !verifyStatement(fromBase64Url(req.reactionPublicKey), s as never, fromBase64Url(req.signature))) {
      return { ok: false, error: "signature_invalid" };
    }
    const row = this.db.prepare("SELECT body FROM experiences WHERE id = ? AND school_id = ? AND status = 'published'").get(experienceId, this.schoolId) as { body: string | null } | undefined;
    if (!row?.body) return { ok: false, error: "not_found" };
    if (!this.takeNonce(s.nonce)) return { ok: false, error: "nonce_used" };
    if (this.db.prepare("SELECT 1 FROM reports WHERE experience_id = ? AND reporter_tag = ?").get(experienceId, tag)) return { ok: true }; // idempotent
    const rate = this.db.prepare("SELECT window_start, count FROM report_rate WHERE reactor_tag = ?").get(tag) as { window_start: number; count: number } | undefined;
    const live = rate && rate.window_start > this.now() - REPORT_RATE_WINDOW_MS;
    if (live && rate!.count >= REPORT_RATE_MAX) return { ok: false, error: "report_rate_limited" };
    this.db
      .prepare(
        `INSERT INTO report_rate (reactor_tag, window_start, count) VALUES (?, ?, 1)
         ON CONFLICT(reactor_tag) DO UPDATE SET
           window_start = CASE WHEN report_rate.window_start > ? THEN report_rate.window_start ELSE excluded.window_start END,
           count = CASE WHEN report_rate.window_start > ? THEN report_rate.count + 1 ELSE 1 END`,
      )
      .run(tag, this.now(), this.now() - REPORT_RATE_WINDOW_MS, this.now() - REPORT_RATE_WINDOW_MS);
    const reportId = randomUUID();
    this.db.prepare("INSERT INTO reports (id, experience_id, category, outcome, reporter_tag, created_at) VALUES (?, ?, ?, 'pending', ?, ?)").run(reportId, experienceId, s.category, tag, this.now());
    const priorKept = this.db
      .prepare("SELECT 1 FROM reports WHERE experience_id = ? AND outcome = 'reevaluated_kept' AND policy_version = ? AND id != ?")
      .get(experienceId, POLICY_VERSION, reportId);
    if (priorKept) {
      this.db.prepare("UPDATE reports SET outcome = 'reevaluated_kept', policy_version = ? WHERE id = ?").run(POLICY_VERSION, reportId);
      return { ok: true };
    }
    await this.reevaluate(reportId, experienceId);
    return { ok: true };
  }

  /** Tri-state re-evaluation: violation → hide; allowed → keep; outage/uncertain → keep + retry. */
  private async reevaluate(reportId: string, experienceId: string): Promise<void> {
    const row = this.db.prepare("SELECT primary_entity_type, body, rating, status FROM experiences WHERE id = ?").get(experienceId) as
      | { primary_entity_type: string; body: string | null; rating: number | null; status: string }
      | undefined;
    if (!row || row.status !== "published" || !row.body) {
      this.db.prepare("UPDATE reports SET outcome = 'reevaluated_kept', retry_at = NULL, policy_version = ? WHERE id = ?").run(POLICY_VERSION, reportId);
      return;
    }
    const decision = await computeDecision(row.body, row.primary_entity_type, row.rating, this.llmRunner);
    const unavailable = decision.action === "failed_closed" || (decision.action === "rephrase_required" && decision.reasons.includes("expression:uncertain"));
    if (unavailable) {
      this.db.prepare("UPDATE reports SET outcome = 'reevaluation_pending', retry_at = ? WHERE id = ?").run(this.now() + REPORT_RETRY_MS, reportId);
      return;
    }
    const kept = decision.action === "publish" || decision.action === "publish_nudge" || decision.action === "cooldown_24h";
    if (kept) {
      this.db.prepare("UPDATE reports SET outcome = 'reevaluated_kept', retry_at = NULL, policy_version = ? WHERE id = ?").run(POLICY_VERSION, reportId);
      return;
    }
    this.db.prepare("UPDATE experiences SET status = 'blocked', body = NULL, rating = NULL, status_detail = 'report_reevaluation' WHERE id = ?").run(experienceId);
    this.db.prepare("UPDATE reports SET outcome = 'reevaluated_hidden', retry_at = NULL, policy_version = ? WHERE id = ?").run(POLICY_VERSION, reportId);
  }

  async processPendingReevaluations(): Promise<number> {
    const due = this.db
      .prepare(
        `SELECT id, experience_id FROM reports
         WHERE (outcome = 'reevaluation_pending' AND retry_at IS NOT NULL AND retry_at <= ?) OR (outcome = 'pending' AND created_at <= ?) LIMIT 20`,
      )
      .all(this.now(), this.now() - 10 * 60_000) as { id: string; experience_id: string }[];
    for (const r of due) await this.reevaluate(r.id, r.experience_id);
    return due.length;
  }
}
