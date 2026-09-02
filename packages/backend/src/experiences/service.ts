import { createHmac, randomUUID, timingSafeEqual } from "node:crypto";
import type { DatabaseSync } from "node:sqlite";
import { deriveKey, generateToken, hashToken, open, seal } from "../crypto.js";
import { lexicalScan } from "./lexicon.js";
import { extractFeatures, type LlmVerdict } from "./llm.js";
import { normalizeText } from "./normalize.js";
import { decide, POLICY_VERSION, type PolicyDecision } from "./policy.js";
import { contentHashOf, contextHashOf, issuePass, markHash, verifyPass, type PassPayload } from "./pass.js";
import type { EntityRegistry } from "./entities.js";
import type { SettingsService } from "./settings.js";
import type {
  CheckExperienceResponse,
  EntitySummary,
  FeedPage,
  FeedScope,
  PublicExperience,
  ReportCategory,
  SearchResponse,
  EntityStats,
} from "@honey/shared/api";

// The Experiences core (App A). Publication is a TWO-CALL flow (audit §3.7/§3.8):
//
//   1. eligibility (authenticated)  — issues a single-use scope-bound token;
//      the server stores only sha256(token) + the unlinkable HMAC dedup mark.
//   2. check (authenticated)        — runs the whole moderation pipeline
//      SYNCHRONOUSLY on the draft and returns a lane; when the lane permits
//      publication it returns a short-lived content-bound pass. The draft body
//      is NEVER persisted here — there is no pending state anywhere.
//   3. publish (NO session auth)    — verifies eligibility token + pass and
//      stores the post. The request carries no account identity; the stored
//      row has no author column. Ownership is provable only by a client-held
//      key (users are warned it is device-only).
//
// A `nudge` lane still requires the user's explicit choice — the server never
// auto-publishes. §21 strikes are recorded at check time (check is
// authenticated and is where violations are detected).

export interface EligibilityInput {
  honeyId: string;
  /** Either a lessonId (lesson-linked) or a standalone entityKey. */
  lessonId?: string;
  entityKey?: string;
}

export interface CheckInput {
  honeyId: string;
  lessonId?: string;
  entityKey?: string;
  body: string;
  rating?: number;
  cooldownTicket?: string;
}

export interface PublishInput {
  eligibilityToken: string;
  pass: string;
  body: string;
  rating?: number;
}

export type CheckOutcome = ({ ok: true } & CheckExperienceResponse) | { ok: false; error: string };

export interface ExperienceRow {
  id: string;
  entity_key: string;
  lesson_id: string | null;
  ctx_teacher_id: string | null;
  ctx_course_id: string | null;
  ctx_room_id: string | null;
  body: string | null;
  rating: number | null;
  provenance: string;
  status: string;
  status_detail: string | null;
  ownership_hash: string;
  content_hash: string;
  policy_version: number;
  created_at: number;
  published_at: number | null;
}

interface Target {
  entityKey: string;
  entityType: string;
  provenance: string;
  ctx: { teacher: string | null; course: string | null; room: string | null };
  mark: string;
}

interface SelectRow {
  id: string;
  entity_key: string;
  ctx_teacher_id: string | null;
  ctx_course_id: string | null;
  ctx_room_id: string | null;
  body: string | null;
  rating: number | null;
  provenance: string;
  published_at: number | null;
}

interface EligibilityRow {
  token_hash: string;
  mark_hash: string;
  entity_key: string;
  ctx_teacher_id: string | null;
  ctx_course_id: string | null;
  ctx_room_id: string | null;
  provenance: string;
  issued_at: number;
  expires_at: number;
  used_at: number | null;
}

export type LlmRunner = (text: string) => Promise<LlmVerdict>;

const ELIGIBILITY_TTL_MS = 60 * 60 * 1000; // ample for check + a nudge decision
const PASS_TTL_MS = 10 * 60 * 1000;
const COOLDOWN_TICKET_LIFE_MS = 7 * 24 * 3600 * 1000;

export class ExperienceService {
  /** Injectable for tests; default uses SettingsService config. */
  llmRunner: LlmRunner;
  /** Injectable clock (tests advance it to cross the cooldown window). */
  now: () => number;
  // Domain-separated subkeys (S4): marks, signing, cooldown tickets and
  // lesson-scoping never share a key with each other or at-rest encryption.
  private readonly markKey: Buffer;
  private readonly signKey: Buffer;
  private readonly lessonScopeKey: Buffer;
  private readonly cooldownKey: Buffer;
  // Feed cursors are SEALED (AES-GCM): they carry the exact publish instant,
  // which must never exist publicly (S5) — opacity by encryption, not base64.
  private readonly cursorKey: Buffer;

  constructor(
    private readonly db: DatabaseSync,
    private readonly registry: EntityRegistry,
    private readonly settings: SettingsService,
    sealKey: Buffer,
    now: () => number = Date.now,
  ) {
    this.now = now;
    this.markKey = deriveKey(sealKey, "exp-mark");
    this.signKey = deriveKey(sealKey, "exp-sign");
    this.lessonScopeKey = deriveKey(sealKey, "lesson-scope");
    this.cooldownKey = deriveKey(sealKey, "exp-cooldown");
    this.cursorKey = deriveKey(sealKey, "feed-cursor");
    this.llmRunner = async (text) => {
      const config = this.settings.llmConfig();
      if (!config) return { ok: false };
      return extractFeatures(text, config);
    };
  }

  /**
   * Opaque, roster-unjoinable token for a lesson instance (C1). The raw
   * lesson_instance_id must never be persisted on or exposed from a public post:
   * it joins directly to user_lesson_exposures and would identify the author's
   * class roster. This HMAC gives a stable grouping/dedup handle instead.
   */
  private lessonToken(lessonInstanceId: string): string {
    return createHmac("sha256", this.lessonScopeKey).update(lessonInstanceId).digest("hex").slice(0, 24);
  }

  /** Coarse public time bucket (S5): calendar day only, never exact ms. */
  private dayBucket(ms: number): number {
    return Math.floor(ms / 86_400_000);
  }

  // ---------- shared gates & target resolution ----------

  /** Kill switches + §21 suspension. Applies to eligibility and check alike. */
  private gate(honeyId: string): string | null {
    if (this.settings.killSwitch("DISABLE_NEW_PUBLICATIONS") || this.settings.killSwitch("PRIVATE_NOTES_ONLY_MODE")) {
      return "publications_disabled";
    }
    // Abuse restriction (§21): a repeatedly-prohibited account is suspended from
    // NEW publications. Enforced on the identity, never by linking to any post.
    const suspended = this.db
      .prepare("SELECT suspended_until FROM abuse_counters WHERE honey_id = ?")
      .get(honeyId) as unknown as { suspended_until: number | null } | undefined;
    if (suspended?.suspended_until && suspended.suspended_until > this.now()) {
      return "temporarily_suspended";
    }
    return null;
  }

  /** Resolve + authorize the review target for this account (lesson or standalone). */
  private resolveTarget(honeyId: string, lessonId?: string, entityKey?: string): { ok: true; target: Target } | { ok: false; error: string } {
    let target: Target;
    if (lessonId) {
      // Lesson-linked: unconditional right to review one's OWN lessons, once each.
      const lesson = this.db
        .prepare(
          `SELECT li.id, li.teacher_id, li.course_id, li.room_id FROM user_lesson_exposures e
           JOIN lesson_instances li ON li.id = e.lesson_instance_id
           WHERE e.honey_id = ? AND li.id = ?`,
        )
        .get(honeyId, lessonId) as unknown as
        | { id: string; teacher_id: string | null; course_id: string | null; room_id: string | null }
        | undefined;
      if (!lesson) return { ok: false, error: "lesson_not_yours" };
      // The scope uses an OPAQUE lesson token, never the roster-joinable id (C1).
      const key = `lesson:${this.lessonToken(lesson.id)}`;
      target = {
        entityKey: key,
        entityType: "lesson",
        provenance: "verified_lesson",
        ctx: { teacher: lesson.teacher_id, course: lesson.course_id, room: lesson.room_id },
        mark: markHash(this.markKey, honeyId, key),
      };
    } else if (entityKey) {
      const entity = this.registry.get(entityKey);
      if (!entity) return { ok: false, error: "entity_unknown" };
      if (this.settings.frozenEntity(entity.entity_key)) return { ok: false, error: "entity_frozen" };
      const mode = this.settings.standaloneMode(entity.entity_key, entity.type);
      if (mode === "closed") return { ok: false, error: "standalone_closed" };
      let provenance: string;
      if (mode === "invite") {
        const invited = this.db
          .prepare("SELECT 1 FROM invite_marks WHERE entity_key = ? AND mark_hash = ?")
          .get(entity.entity_key, markHash(this.markKey, honeyId, `invite:${entity.entity_key}`));
        if (!invited) return { ok: false, error: "not_invited" };
        provenance = "verified_member";
      } else if (mode === "verified") {
        provenance = this.verifiedExposure(honeyId, entity.entity_key, entity.type);
        if (!provenance) return { ok: false, error: "no_verified_exposure" };
      } else {
        provenance = "verified_member"; // open
      }
      target = {
        entityKey: entity.entity_key,
        entityType: entity.type,
        provenance,
        ctx: { teacher: null, course: null, room: null },
        mark: markHash(this.markKey, honeyId, entity.entity_key),
      };
    } else {
      return { ok: false, error: "target_required" };
    }

    // FREEZE_ENTITY (S2): no new posts whose primary OR context entity is frozen.
    if (this.frozenAnywhere(target.entityKey, target.ctx.teacher, target.ctx.room)) {
      return { ok: false, error: "entity_frozen" };
    }
    return { ok: true, target };
  }

  /** One review per scope (lesson always; standalone per current rules). */
  private markTaken(mark: string): boolean {
    return !!this.db.prepare("SELECT 1 FROM review_marks WHERE mark_hash = ?").get(mark);
  }

  private frozenAnywhere(entityKey: string, teacherId: string | null, roomId: string | null): boolean {
    return [entityKey, teacherId && `teacher:${teacherId}`, roomId && `room:${roomId}`]
      .filter((k): k is string => !!k)
      .some((k) => this.settings.frozenEntity(k));
  }

  // ---------- step 1: eligibility (authenticated, single-use, unlinkable) ----------

  issueEligibility(input: EligibilityInput): { ok: true; eligibilityToken: string; expiresAt: number } | { ok: false; error: string } {
    const gated = this.gate(input.honeyId);
    if (gated) return { ok: false, error: gated };
    const resolved = this.resolveTarget(input.honeyId, input.lessonId, input.entityKey);
    if (!resolved.ok) return resolved;
    const t = resolved.target;
    if (this.markTaken(t.mark)) return { ok: false, error: "already_reviewed" };
    const token = generateToken();
    const expiresAt = this.now() + ELIGIBILITY_TTL_MS;
    // Stored: token hash + unlinkable mark + scope snapshot. NO user column —
    // the publish step must not learn (or need) who was issued the token.
    this.db
      .prepare(
        `INSERT INTO experience_eligibility
           (token_hash, mark_hash, entity_key, ctx_teacher_id, ctx_course_id, ctx_room_id, provenance, issued_at, expires_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      )
      .run(hashToken(token), t.mark, t.entityKey, t.ctx.teacher, t.ctx.course, t.ctx.room, t.provenance, this.now(), expiresAt);
    return { ok: true, eligibilityToken: token, expiresAt };
  }

  // ---------- step 2: check (authenticated moderation preflight; persists NOTHING) ----------

  async check(input: CheckInput): Promise<CheckOutcome> {
    const gated = this.gate(input.honeyId);
    if (gated) return { ok: false, error: gated };
    const body = (input.body ?? "").trim();
    if (!body || body.length > 5000) return { ok: false, error: "body_invalid" };
    const rating = input.rating ?? null;
    if (rating !== null && (rating < 1 || rating > 5 || !Number.isInteger(rating))) {
      return { ok: false, error: "rating_invalid" };
    }
    const resolved = this.resolveTarget(input.honeyId, input.lessonId, input.entityKey);
    if (!resolved.ok) return resolved;
    const t = resolved.target;
    if (rating !== null && t.entityType !== "dish") return { ok: false, error: "rating_not_allowed" };
    if (this.markTaken(t.mark)) return { ok: false, error: "already_reviewed" };

    const contentHash = contentHashOf(body, rating);

    // Cooldown reconfirm (§13.3), adapted to the stateless flow: the ticket —
    // not any server row — proves this exact content already served its 24 h.
    let reconfirming = false;
    if (input.cooldownTicket !== undefined) {
      const ticket = this.verifyCooldownTicket(input.cooldownTicket, contentHash, t.entityKey);
      if (!ticket.ok) return { ok: false, error: "cooldown_ticket_invalid" };
      if (ticket.notBefore > this.now()) {
        // Window not over yet — same lane, same ticket (idempotent).
        return {
          ok: true, lane: "cooldown", reasons: ["cooldown_active"], policyVersion: POLICY_VERSION,
          cooldown: { ticket: input.cooldownTicket, retryAt: ticket.notBefore },
        };
      }
      reconfirming = true;
    }

    // Moderation runs synchronously — deterministic lexicon, one small LLM
    // call, deterministic policy. The CURRENT policy always applies, so a
    // reconfirm after a policy change is re-judged under the new rules.
    let decision = await this.computeDecision(body, t.entityType, rating);
    // The cooling-off period already elapsed; a repeat high-arousal verdict must
    // not re-cool the same content — reconfirm publishes ordinary opinion (§13.3).
    if (reconfirming && decision.action === "cooldown_24h") decision = { ...decision, action: "publish" };

    // §21: count high-confidence prohibited attempts on the ACCOUNT (no text,
    // no post id). Check is where violations are detected — strikes land here.
    if (decision.action === "blocked_serious") this.recordProhibitedAttempt(input.honeyId);

    return this.laneOf(decision, { body, rating, contentHash, target: t });
  }

  /** Map a policy decision to the client-facing lane (+ pass / cooldown ticket). */
  private laneOf(
    decision: PolicyDecision,
    c: { body: string; rating: number | null; contentHash: string; target: Target },
  ): CheckOutcome {
    const base = { ok: true as const, reasons: decision.reasons, policyVersion: decision.policyVersion };
    switch (decision.action) {
      case "publish":
      case "publish_nudge": {
        // A pass is issued for BOTH lanes: a nudge is advisory — the user
        // chooses add-context / publish-as-is / keep-private; only an explicit
        // publish call makes anything public.
        const { payload, signature } = issuePass(
          {
            contentHash: c.contentHash,
            entityKey: c.target.entityKey,
            contextHash: contextHashOf({ t: c.target.ctx.teacher, c: c.target.ctx.course, r: c.target.ctx.room }),
            policyVersion: decision.policyVersion,
          },
          this.signKey,
          PASS_TTL_MS,
          this.now(),
        );
        const pass = Buffer.from(JSON.stringify({ p: payload, s: signature })).toString("base64url");
        return { ...base, lane: decision.action === "publish_nudge" ? "nudge" : "publish", pass };
      }
      case "cooldown_24h": {
        const notBefore = this.now() + this.settings.cooldownHours() * 3600 * 1000;
        return {
          ...base, lane: "cooldown",
          cooldown: { ticket: this.issueCooldownTicket(c.contentHash, c.target.entityKey, notBefore), retryAt: notBefore },
        };
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

  // ---------- cooldown tickets (stateless — no draft is ever stored) ----------

  private cooldownSig(contentHash: string, entityKey: string, notBefore: number, expiresAt: number): string {
    return createHmac("sha256", this.cooldownKey)
      .update([contentHash, entityKey, notBefore, expiresAt].join("|"))
      .digest("hex");
  }

  private issueCooldownTicket(contentHash: string, entityKey: string, notBefore: number): string {
    const expiresAt = this.now() + COOLDOWN_TICKET_LIFE_MS;
    const sig = this.cooldownSig(contentHash, entityKey, notBefore, expiresAt);
    return Buffer.from(JSON.stringify({ nb: notBefore, exp: expiresAt, s: sig })).toString("base64url");
  }

  private verifyCooldownTicket(ticket: string, contentHash: string, entityKey: string): { ok: true; notBefore: number } | { ok: false } {
    try {
      const parsed = JSON.parse(Buffer.from(ticket, "base64url").toString("utf8")) as { nb: number; exp: number; s: string };
      if (typeof parsed.nb !== "number" || typeof parsed.exp !== "number" || typeof parsed.s !== "string") return { ok: false };
      if (parsed.exp <= this.now()) return { ok: false };
      const expected = Buffer.from(this.cooldownSig(contentHash, entityKey, parsed.nb, parsed.exp), "hex");
      const given = Buffer.from(parsed.s.padEnd(expected.length * 2, "0").slice(0, expected.length * 2), "hex");
      if (expected.length !== given.length || !timingSafeEqual(expected, given)) return { ok: false };
      return { ok: true, notBefore: parsed.nb };
    } catch {
      return { ok: false };
    }
  }

  // ---------- step 3: publish (NO session — eligibility token + pass only) ----------

  publish(input: PublishInput): { ok: true; experienceId: string; ownershipKey: string } | { ok: false; error: string } {
    if (this.settings.killSwitch("DISABLE_NEW_PUBLICATIONS") || this.settings.killSwitch("PRIVATE_NOTES_ONLY_MODE")) {
      return { ok: false, error: "publications_disabled" };
    }
    // 1. The content-bound pass: signature, expiry, content binding.
    let payload: PassPayload;
    let signature: string;
    try {
      const parsed = JSON.parse(Buffer.from(input.pass, "base64url").toString("utf8")) as { p: PassPayload; s: string };
      payload = parsed.p;
      signature = parsed.s;
    } catch {
      return { ok: false, error: "pass_invalid" };
    }
    if (!payload || typeof signature !== "string" || !verifyPass(payload, signature, this.signKey, this.now())) {
      return { ok: false, error: "pass_invalid" };
    }
    const body = (input.body ?? "").trim();
    const rating = input.rating ?? null;
    if (contentHashOf(body, rating) !== payload.contentHash) {
      return { ok: false, error: "pass_content_mismatch" };
    }
    // 2. The single-use eligibility token (scope authority; joins to no account).
    const elig = this.db
      .prepare("SELECT * FROM experience_eligibility WHERE token_hash = ?")
      .get(hashToken(input.eligibilityToken)) as unknown as EligibilityRow | undefined;
    if (!elig) return { ok: false, error: "eligibility_invalid" };
    if (elig.used_at !== null) return { ok: false, error: "eligibility_used" };
    if (elig.expires_at <= this.now()) return { ok: false, error: "eligibility_expired" };
    // 3. Pass and eligibility must describe the same scope.
    if (
      payload.entityKey !== elig.entity_key ||
      payload.contextHash !== contextHashOf({ t: elig.ctx_teacher_id, c: elig.ctx_course_id, r: elig.ctx_room_id })
    ) {
      return { ok: false, error: "pass_scope_mismatch" };
    }
    const entityType = elig.entity_key.split(":")[0] ?? "lesson";
    if (rating !== null && entityType !== "dish") return { ok: false, error: "rating_not_allowed" };
    if (this.frozenAnywhere(elig.entity_key, elig.ctx_teacher_id, elig.ctx_room_id)) {
      return { ok: false, error: "entity_frozen" };
    }
    // 4. Replay + dedup: the nonce burns with the pass; the review mark is
    // claimed here, atomically with the post.
    if (this.db.prepare("SELECT 1 FROM pass_nonces WHERE nonce = ?").get(payload.nonce)) {
      return { ok: false, error: "pass_invalid" }; // replay
    }
    if (this.markTaken(elig.mark_hash)) {
      return { ok: false, error: "already_reviewed" };
    }

    const id = randomUUID();
    const ownershipKey = generateToken();
    const lessonToken = elig.entity_key.startsWith("lesson:") ? elig.entity_key.slice("lesson:".length) : null;
    this.db.exec("BEGIN");
    try {
      this.db.prepare("UPDATE experience_eligibility SET used_at = ? WHERE token_hash = ?").run(this.now(), elig.token_hash);
      this.db.prepare("INSERT INTO pass_nonces (nonce, used_at) VALUES (?, ?)").run(payload.nonce, this.now());
      this.db.prepare("INSERT INTO review_marks (mark_hash) VALUES (?)").run(elig.mark_hash);
      this.db
        .prepare(
          `INSERT INTO experiences (id, entity_key, lesson_id, ctx_teacher_id, ctx_course_id, ctx_room_id,
             body, rating, provenance, status, ownership_hash, content_hash, policy_version, created_at, published_at)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 'published', ?, ?, ?, ?, ?)`,
        )
        .run(
          id, elig.entity_key, lessonToken, elig.ctx_teacher_id, elig.ctx_course_id, elig.ctx_room_id,
          body, rating, elig.provenance, hashToken(ownershipKey), payload.contentHash,
          payload.policyVersion, this.now(), this.now(),
        );
      // Domain associations (review v3 §12.5): the generic query surface.
      const assoc = this.db.prepare(
        "INSERT OR IGNORE INTO experience_associations (experience_id, entity_type, entity_id, relationship) VALUES (?, ?, ?, ?)",
      );
      const sep = elig.entity_key.indexOf(":");
      if (sep > 0) assoc.run(id, elig.entity_key.slice(0, sep), elig.entity_key.slice(sep + 1), "primary");
      if (elig.ctx_teacher_id) assoc.run(id, "teacher", elig.ctx_teacher_id, "context");
      if (elig.ctx_course_id) assoc.run(id, "course", elig.ctx_course_id, "context");
      if (elig.ctx_room_id) assoc.run(id, "room", elig.ctx_room_id, "context");
      this.db.exec("COMMIT");
    } catch (e) {
      this.db.exec("ROLLBACK");
      throw e;
    }
    return { ok: true, experienceId: id, ownershipKey };
  }

  private recordProhibitedAttempt(honeyId: string): void {
    const THRESHOLD = 3;
    const SUSPEND_MS = 7 * 24 * 3600 * 1000;
    const row = this.db
      .prepare("SELECT blocked_attempts FROM abuse_counters WHERE honey_id = ?")
      .get(honeyId) as unknown as { blocked_attempts: number } | undefined;
    const count = (row?.blocked_attempts ?? 0) + 1;
    const suspendUntil = count >= THRESHOLD ? this.now() + SUSPEND_MS : null;
    this.db
      .prepare(
        `INSERT INTO abuse_counters (honey_id, blocked_attempts, last_blocked_at, suspended_until)
         VALUES (?, ?, ?, ?)
         ON CONFLICT(honey_id) DO UPDATE SET
           blocked_attempts = excluded.blocked_attempts,
           last_blocked_at = excluded.last_blocked_at,
           suspended_until = COALESCE(excluded.suspended_until, abuse_counters.suspended_until)`,
      )
      .run(honeyId, count, this.now(), suspendUntil);
  }

  /** normalize → lexical → (LLM unless lexical hard-block) → deterministic decide. */
  private async computeDecision(
    body: string,
    entityType: string,
    rating: number | null,
  ): Promise<PolicyDecision> {
    const normalized = normalizeText(body);
    const lexical = lexicalScan(normalized);
    if (lexical.length > 0) {
      // Lexical findings are all Expression-gate outcomes and skip the LLM
      // entirely (cheap + fail-safe); the ordered engine resolves them directly.
      return decide({ lexical, llm: null, entityType, hasRating: rating !== null });
    }
    const verdict = await this.llmRunner(normalized.original);
    return decide({
      lexical,
      llm: verdict.ok && verdict.features ? verdict.features : null,
      entityType,
      hasRating: rating !== null,
    });
  }

  private verifiedExposure(honeyId: string, entityKey: string, type: string): string {
    if (type === "teacher") {
      const id = entityKey.slice("teacher:".length);
      const hit = this.db
        .prepare("SELECT 1 FROM user_lesson_exposures WHERE honey_id = ? AND teacher_id = ? LIMIT 1")
        .get(honeyId, id);
      return hit ? "verified_retrospective" : "";
    }
    if (type === "course") {
      const id = entityKey.slice("course:".length);
      const hit = this.db
        .prepare("SELECT 1 FROM user_lesson_exposures WHERE honey_id = ? AND course_id = ? LIMIT 1")
        .get(honeyId, id);
      return hit ? "verified_retrospective" : "";
    }
    if (type === "room") {
      const id = entityKey.slice("room:".length);
      const hit = this.db
        .prepare(
          `SELECT 1 FROM user_lesson_exposures e JOIN lesson_instances li ON li.id = e.lesson_instance_id
           WHERE e.honey_id = ? AND li.room_id = ? LIMIT 1`,
        )
        .get(honeyId, id);
      return hit ? "verified_retrospective" : "";
    }
    // Dishes: the portal cannot prove consumption — honest provenance is membership.
    return "verified_member";
  }

  // ---------- ownership: history / revoke ----------

  /** Look up the caller's own submissions by their client-held keys. */
  mine(ownershipKeys: string[]): ExperienceRow[] {
    const rows: ExperienceRow[] = [];
    const stmt = this.db.prepare("SELECT * FROM experiences WHERE ownership_hash = ?");
    for (const key of ownershipKeys.slice(0, 200)) {
      const row = stmt.get(hashToken(key)) as unknown as ExperienceRow | undefined;
      if (row) rows.push(row);
    }
    return rows;
  }

  /**
   * Revoke (authenticated + key-proved). The mark is recomputed transiently to
   * free the user's one-review slot; nothing persisted links user to post.
   */
  revoke(honeyId: string, ownershipKey: string): { ok: boolean; error?: string } {
    const row = this.byKey(ownershipKey);
    if (!row) return { ok: false, error: "not_found" };
    if (row.status === "revoked") return { ok: false, error: "already_revoked" };
    const scope = row.entity_key; // dedup scope is always the entity key
    this.db.exec("BEGIN");
    try {
      this.db
        .prepare("UPDATE experiences SET status = 'revoked', body = NULL, rating = NULL WHERE id = ?")
        .run(row.id);
      this.db
        .prepare("DELETE FROM review_marks WHERE mark_hash = ?")
        .run(markHash(this.markKey, honeyId, scope));
      this.db.exec("COMMIT");
    } catch (e) {
      this.db.exec("ROLLBACK");
      throw e;
    }
    return { ok: true };
  }

  private byKey(ownershipKey: string): ExperienceRow | null {
    const row = this.db
      .prepare("SELECT * FROM experiences WHERE ownership_hash = ?")
      .get(hashToken(ownershipKey)) as unknown as ExperienceRow | undefined;
    return row ?? null;
  }

  /** Invite mark for an entity (admin route uses this so keys stay consistent). */
  inviteMark(honeyId: string, entityKey: string): string {
    return markHash(this.markKey, honeyId, `invite:${entityKey}`);
  }

  // ---------- browsing (raw-first, §9) ----------

  feed(opts: {
    entityKey?: string;
    teacherId?: string;
    courseId?: string;
    roomId?: string;
    q?: string;
    sort?: "newest" | "oldest";
    before?: number;
    limit?: number;
    /** Authenticated viewer — lets the projection restore `myReaction`. */
    viewer?: string;
  }): PublicExperience[] {
    if (this.settings.killSwitch("HIDE_PUBLIC_EXPERIENCES")) return [];
    const clauses = ["status = 'published'"];
    const params: (string | number)[] = [];
    if (opts.entityKey) {
      clauses.push("entity_key = ?");
      params.push(opts.entityKey);
    }
    // Filter-time association (decisions doc): a lesson experience surfaces
    // under its teacher/course/room context without being pre-classified.
    if (opts.teacherId) {
      clauses.push("(ctx_teacher_id = ? OR entity_key = ?)");
      params.push(opts.teacherId, `teacher:${opts.teacherId}`);
    }
    if (opts.courseId) {
      clauses.push("(ctx_course_id = ? OR entity_key = ?)");
      params.push(opts.courseId, `course:${opts.courseId}`);
    }
    if (opts.roomId) {
      clauses.push("(ctx_room_id = ? OR entity_key = ?)");
      params.push(opts.roomId, `room:${opts.roomId}`);
    }
    if (opts.q) {
      // Parameterized (no injection); escape LIKE metacharacters so a user
      // cannot use % / _ as wildcards (S6).
      clauses.push("body LIKE ? ESCAPE '\\'");
      params.push(`%${opts.q.replace(/[\\%_]/g, (c) => "\\" + c)}%`);
    }
    const before = Number.isFinite(opts.before) ? (opts.before as number) : undefined;
    if (before !== undefined) {
      clauses.push("published_at < ?");
      params.push(before);
    }
    const order = opts.sort === "oldest" ? "ASC" : "DESC"; // allowed sorts only
    return this.selectPublic(clauses.join(" AND "), params, order, opts.limit, opts.viewer);
  }

  /**
   * Domain query (audit §4.2): the chronological slice of published posts
   * relevant to THIS user's verified exposure — their teachers, rooms and
   * lessons from imports. The UI only renders it.
   */
  fromMyClasses(honeyId: string, opts: { before?: number; limit?: number } = {}): PublicExperience[] {
    if (this.settings.killSwitch("HIDE_PUBLIC_EXPERIENCES")) return [];
    const teacherIds = (this.db
      .prepare("SELECT DISTINCT teacher_id AS id FROM user_lesson_exposures WHERE honey_id = ? AND teacher_id IS NOT NULL")
      .all(honeyId) as unknown as { id: string }[]).map((r) => r.id);
    const courseIds = (this.db
      .prepare("SELECT DISTINCT course_id AS id FROM user_lesson_exposures WHERE honey_id = ? AND course_id IS NOT NULL")
      .all(honeyId) as unknown as { id: string }[]).map((r) => r.id);
    const roomIds = (this.db
      .prepare(
        `SELECT DISTINCT li.room_id AS id FROM user_lesson_exposures e
         JOIN lesson_instances li ON li.id = e.lesson_instance_id
         WHERE e.honey_id = ? AND li.room_id IS NOT NULL`,
      )
      .all(honeyId) as unknown as { id: string }[]).map((r) => r.id);
    const lessonIds = (this.db
      .prepare("SELECT lesson_instance_id AS id FROM user_lesson_exposures WHERE honey_id = ?")
      .all(honeyId) as unknown as { id: string }[]).map((r) => r.id);
    // Match standalone posts on the entities themselves, and lesson posts via
    // their context snapshot or their (opaque) lesson scope.
    const entityKeys = [
      ...teacherIds.map((id) => `teacher:${id}`),
      ...courseIds.map((id) => `course:${id}`),
      ...roomIds.map((id) => `room:${id}`),
      ...lessonIds.map((id) => `lesson:${this.lessonToken(id)}`),
    ];
    const ors: string[] = [];
    const params: (string | number)[] = [];
    const inList = (col: string, ids: string[]) => {
      if (ids.length === 0) return;
      ors.push(`${col} IN (${ids.map(() => "?").join(",")})`);
      params.push(...ids);
    };
    inList("entity_key", entityKeys);
    inList("ctx_teacher_id", teacherIds);
    inList("ctx_course_id", courseIds);
    inList("ctx_room_id", roomIds);
    if (ors.length === 0) return [];
    const clauses = [`status = 'published'`, `(${ors.join(" OR ")})`];
    const before = Number.isFinite(opts.before) ? (opts.before as number) : undefined;
    if (before !== undefined) {
      clauses.push("published_at < ?");
      params.push(before);
    }
    return this.selectPublic(clauses.join(" AND "), params, "DESC", opts.limit, honeyId);
  }

  // ---------- cursor feed (review v3 §12.6): the social stream ----------

  private sealCursor(t: number, id: string, scope: string): string {
    return seal(JSON.stringify({ v: 1, t, id, s: scope }), this.cursorKey).toString("base64url");
  }

  private openCursor(cursor: string, scope: string): { t: number; id: string } | null {
    try {
      const parsed = JSON.parse(open(Buffer.from(cursor, "base64url"), this.cursorKey)) as {
        v: number; t: number; id: string; s: string;
      };
      if (parsed.v !== 1 || parsed.s !== scope) return null; // scope-bound (§12.6)
      if (typeof parsed.t !== "number" || typeof parsed.id !== "string") return null;
      return { t: parsed.t, id: parsed.id };
    } catch {
      return null;
    }
  }

  /** WHERE fragment for a feed scope; null = viewer has no exposure yet. */
  private scopeWhere(
    honeyId: string,
    scope: FeedScope,
  ): { clause: string; params: (string | number)[] } | null {
    if (scope === "school") return { clause: "1=1", params: [] };
    const ids = (col: string, sql: string) =>
      (this.db.prepare(sql).all(honeyId) as unknown as { id: string }[]).map((r) => r.id);
    const teacherIds = ids("t", "SELECT DISTINCT teacher_id AS id FROM user_lesson_exposures WHERE honey_id = ? AND teacher_id IS NOT NULL");
    const courseIds = ids("c", "SELECT DISTINCT course_id AS id FROM user_lesson_exposures WHERE honey_id = ? AND course_id IS NOT NULL");
    const lessonIds = ids("l", "SELECT lesson_instance_id AS id FROM user_lesson_exposures WHERE honey_id = ?");
    // Room exposure deliberately does NOT scope the class feed (review v3
    // §9.6A): "same classroom once" would mix everything into Your classes.
    const pairs: [string, string][] = [
      ...teacherIds.map((id): [string, string] => ["teacher", id]),
      ...courseIds.map((id): [string, string] => ["course", id]),
      ...lessonIds.map((id): [string, string] => ["lesson", this.lessonToken(id)]),
    ];
    if (pairs.length === 0) return null;
    const clause = `id IN (SELECT experience_id FROM experience_associations WHERE (${pairs
      .map(() => "(entity_type = ? AND entity_id = ?)")
      .join(" OR ")}))`;
    return { clause, params: pairs.flat() };
  }

  /**
   * Cursor-paged chronological stream. Stable order (published_at, id) DESC;
   * reactions never re-rank; a light adjacency rule keeps at most two
   * consecutive posts on one primary entity WITHIN a page (order-preserving
   * otherwise, and cursoring is computed on the RAW chronology so pages never
   * skip or duplicate).
   */
  feedPage(
    honeyId: string,
    scope: FeedScope,
    opts: {
      cursor?: string;
      limit?: number;
      entityKey?: string;
      teacherId?: string;
      courseId?: string;
      roomId?: string;
    } = {},
  ): { ok: true; page: FeedPage } | { ok: false; error: string } {
    if (this.settings.killSwitch("HIDE_PUBLIC_EXPERIENCES")) {
      return { ok: true, page: { items: [], nextCursor: null, headCursor: null } };
    }
    const scoped = this.scopeWhere(honeyId, scope);
    if (!scoped) return { ok: true, page: { items: [], nextCursor: null, headCursor: null } };
    const clauses = ["status = 'published'", scoped.clause];
    const params: (string | number)[] = [...scoped.params];
    if (opts.entityKey) {
      clauses.push("entity_key = ?");
      params.push(opts.entityKey);
    }
    if (opts.teacherId) {
      clauses.push("(ctx_teacher_id = ? OR entity_key = ?)");
      params.push(opts.teacherId, `teacher:${opts.teacherId}`);
    }
    if (opts.courseId) {
      clauses.push("(ctx_course_id = ? OR entity_key = ?)");
      params.push(opts.courseId, `course:${opts.courseId}`);
    }
    if (opts.roomId) {
      clauses.push("(ctx_room_id = ? OR entity_key = ?)");
      params.push(opts.roomId, `room:${opts.roomId}`);
    }
    if (opts.cursor) {
      const c = this.openCursor(opts.cursor, scope);
      if (!c) return { ok: false, error: "bad_cursor" };
      clauses.push("(published_at < ? OR (published_at = ? AND id < ?))");
      params.push(c.t, c.t, c.id);
    }
    const rawLimit = Number.isFinite(opts.limit) ? (opts.limit as number) : 20;
    const limit = Math.min(Math.max(Math.trunc(rawLimit), 5), 25);
    // Over-fetch by 1 to learn whether a next page exists.
    const raw = this.db
      .prepare(
        `SELECT id, entity_key, ctx_teacher_id, ctx_course_id, ctx_room_id, body, rating,
                provenance, published_at
         FROM experiences WHERE ${clauses.join(" AND ")}
         ORDER BY published_at DESC, id DESC LIMIT ${limit + 1}`,
      )
      .all(...params) as unknown as SelectRow[];
    const hasMore = raw.length > limit;
    const pageRows = raw.slice(0, limit).filter(
      (r) => !this.frozenAnywhere(r.entity_key, r.ctx_teacher_id, r.ctx_room_id),
    );
    const last = raw.length > 0 ? raw[Math.min(limit, raw.length) - 1]! : null;
    // Head = the newest RAW position at fetch time (pre-filter): a frozen
    // newest post must advance the head too, or the new-posts probe would
    // signal forever about something the feed can never show. An empty
    // unpaged feed arms at the zero position so the FIRST post still lands.
    const first = raw[0] ?? null;
    const items = this.diversify(pageRows).map((r) => this.toPublic(r, honeyId));
    return {
      ok: true,
      page: {
        items,
        nextCursor: hasMore && last ? this.sealCursor(last.published_at ?? 0, last.id, scope) : null,
        headCursor: opts.cursor
          ? null
          : this.sealCursor(first?.published_at ?? 0, first?.id ?? "", scope),
      },
    };
  }

  /** Quiet new-content probe: never disturbs the reader's position (§9.6C). */
  feedUpdates(honeyId: string, scope: FeedScope, head: string): { ok: true; newItemsAvailable: boolean } | { ok: false; error: string } {
    if (this.settings.killSwitch("HIDE_PUBLIC_EXPERIENCES")) return { ok: true, newItemsAvailable: false };
    const c = this.openCursor(head, scope);
    if (!c) return { ok: false, error: "bad_cursor" };
    const scoped = this.scopeWhere(honeyId, scope);
    if (!scoped) return { ok: true, newItemsAvailable: false };
    const hit = this.db
      .prepare(
        `SELECT 1 FROM experiences WHERE status = 'published' AND ${scoped.clause}
         AND (published_at > ? OR (published_at = ? AND id > ?)) LIMIT 1`,
      )
      .get(...scoped.params, c.t, c.t, c.id);
    return { ok: true, newItemsAvailable: !!hit };
  }

  /** ≤2 consecutive posts per primary entity, minimal stable displacement (§9.6A). */
  private diversify<T extends { entity_key: string }>(rows: T[]): T[] {
    const out: T[] = [];
    const deferred: T[] = [];
    for (const row of rows) {
      const n = out.length;
      if (n >= 2 && out[n - 1]!.entity_key === row.entity_key && out[n - 2]!.entity_key === row.entity_key) {
        deferred.push(row); // hold until a different entity breaks the run
      } else {
        out.push(row);
        // Re-admit deferred rows as soon as adjacency allows.
        while (deferred.length > 0) {
          const m = out.length;
          const d = deferred[0]!;
          if (m >= 2 && out[m - 1]!.entity_key === d.entity_key && out[m - 2]!.entity_key === d.entity_key) break;
          out.push(d);
          deferred.shift();
        }
      }
    }
    out.push(...deferred); // never drop content — worst case the run stays
    return out;
  }

  /** Shared public projection: frozen-entity filter, reaction hiding, day bucket. */
  private selectPublic(
    where: string,
    params: (string | number)[],
    order: "ASC" | "DESC",
    rawLimit?: number,
    viewer?: string,
  ): PublicExperience[] {
    const limit = Math.min(Math.max(Math.trunc(Number.isFinite(rawLimit) ? (rawLimit as number) : 50), 1), 200);
    const rows = this.db
      .prepare(
        `SELECT id, entity_key, ctx_teacher_id, ctx_course_id, ctx_room_id, body, rating,
                provenance, published_at
         FROM experiences WHERE ${where} ORDER BY published_at ${order} LIMIT ${limit}`,
      )
      .all(...params) as unknown as SelectRow[];
    return rows
      // Hide posts whose primary or context entity is frozen (S2).
      .filter((r) => !this.frozenAnywhere(r.entity_key, r.ctx_teacher_id, r.ctx_room_id))
      .map((r) => this.toPublic(r, viewer));
  }

  /**
   * One row → the complete public domain representation (review v3 §12.4):
   * named primary + contexts ride ON the payload, so clients never join a
   * directory to render a post. Coarse day bucket only (S5); the raw lesson
   * token appears only inside EntitySummary ids (already opaque, C1).
   */
  /**
   * Find mode (review §8.1): entity names first (registry, case-folded
   * substring), then published experiences whose words contain the query.
   * Raw chronology, capped; the viewer's reactions restored like the feed.
   */
  search(honeyId: string, q: string): SearchResponse {
    const query = q.trim().slice(0, 60);
    if (!query) return { q: "", entities: [], experiences: [] };
    const entities = this.registry.list(undefined, query).slice(0, 30);
    let experiences: PublicExperience[] = [];
    if (!this.settings.killSwitch("HIDE_PUBLIC_EXPERIENCES")) {
      const rows = this.db
        .prepare(
          `SELECT * FROM experiences WHERE status = 'published' AND body LIKE ? ESCAPE '\\'
           ORDER BY published_at DESC, id DESC LIMIT 20`,
        )
        .all(`%${query.replace(/[\\%_]/g, (m) => "\\" + m)}%`) as unknown as SelectRow[];
      experiences = rows.map((r) => this.toPublic(r, honeyId));
    }
    return { q: query, entities, experiences };
  }

  /** Descriptive counts for an entity page (review §8.3): never a score. */
  entityStats(entityKey: string): EntityStats {
    const [type, id] = entityKey.split(":");
    if (!type || !id) return { experiences: 0, courses: 0, teachers: 0 };
    const ids = this.db
      .prepare(
        `SELECT DISTINCT e.id FROM experiences e
         LEFT JOIN experience_associations a ON a.experience_id = e.id
         WHERE e.status = 'published' AND (e.entity_key = ? OR (a.entity_type = ? AND a.entity_id = ?))`,
      )
      .all(entityKey, type, id) as unknown as { id: string }[];
    if (ids.length === 0) return { experiences: 0, courses: 0, teachers: 0 };
    const marks = ids.map(() => "?").join(",");
    const count = (kind: string) =>
      (this.db
        .prepare(
          `SELECT COUNT(DISTINCT entity_id) AS n FROM experience_associations
           WHERE entity_type = ? AND experience_id IN (${marks})`,
        )
        .get(kind, ...ids.map((r) => r.id)) as { n: number }).n;
    return { experiences: ids.length, courses: count("course"), teachers: count("teacher") };
  }

  private toPublic(r: SelectRow, viewer?: string): PublicExperience {
    const c = this.db
      .prepare("SELECT SUM(value = 1) AS likes, SUM(value = -1) AS dislikes FROM reactions WHERE experience_id = ?")
      .get(r.id) as unknown as { likes: number | null; dislikes: number | null };
    const likes = c.likes ?? 0;
    const dislikes = c.dislikes ?? 0;
    const reactions = likes + dislikes >= this.settings.reactionMinCount() ? { likes, dislikes } : null;
    // The viewer's own reaction survives refresh/devices: the dedup mark is
    // recomputable from (viewer, post), so no separate account-linked state
    // is stored (review v3 §9.9 Option A, with the HMAC construction kept).
    let myReaction: 1 | -1 | 0 = 0;
    if (viewer) {
      const mine = this.db
        .prepare("SELECT value FROM reactions WHERE experience_id = ? AND dedup_hash = ?")
        .get(r.id, markHash(this.markKey, viewer, `react:${r.id}`)) as unknown as
        | { value: number }
        | undefined;
      if (mine?.value === 1 || mine?.value === -1) myReaction = mine.value;
    }
    const sep = r.entity_key.indexOf(":");
    const primaryType = (sep > 0 ? r.entity_key.slice(0, sep) : "lesson") as EntitySummary["type"];
    const primaryId = sep > 0 ? r.entity_key.slice(sep + 1) : r.entity_key;
    const primary: EntitySummary = {
      type: primaryType,
      id: primaryId,
      name: primaryType === "lesson" ? null : this.entityName(primaryType, primaryId),
    };
    const contexts: EntitySummary[] = [];
    if (r.ctx_teacher_id) contexts.push({ type: "teacher", id: r.ctx_teacher_id, name: this.entityName("teacher", r.ctx_teacher_id) });
    if (r.ctx_course_id) contexts.push({ type: "course", id: r.ctx_course_id, name: this.entityName("course", r.ctx_course_id) });
    if (r.ctx_room_id) contexts.push({ type: "room", id: r.ctx_room_id, name: this.entityName("room", r.ctx_room_id) });
    const { published_at, ...pub } = r;
    return {
      ...pub,
      provenance: r.provenance as PublicExperience["provenance"],
      publishedDay: published_at ? this.dayBucket(published_at) : null,
      reactions,
      myReaction,
      primary,
      contexts,
    };
  }

  /** Display name for an entity id (normalized tables first, registry for the rest). */
  private entityName(type: EntitySummary["type"], id: string): string | null {
    const bySql: Partial<Record<EntitySummary["type"], string>> = {
      teacher: "SELECT display_name AS name FROM teachers WHERE id = ?",
      course: "SELECT name FROM courses WHERE id = ?",
      room: "SELECT name FROM rooms WHERE id = ?",
    };
    const sql = bySql[type];
    if (sql) {
      const row = this.db.prepare(sql).get(id) as unknown as { name: string } | undefined;
      if (row?.name) return row.name;
    }
    const reg = this.registry.get(`${type}:${id}`);
    return reg?.name ?? null;
  }

  // ---------- reactions (§10) ----------

  react(
    honeyId: string,
    experienceId: string,
    value: 1 | -1 | 0,
  ): { ok: true; value: 1 | -1 | 0; reactions: { likes: number; dislikes: number } | null } | { ok: false; error: string } {
    if (this.settings.killSwitch("DISABLE_REACTIONS")) return { ok: false, error: "reactions_disabled" };
    const row = this.db
      .prepare(
        "SELECT id, entity_key, lesson_id, ctx_teacher_id, ctx_room_id FROM experiences WHERE id = ? AND status = 'published'",
      )
      .get(experienceId) as unknown as
      | { id: string; entity_key: string; lesson_id: string | null; ctx_teacher_id: string | null; ctx_room_id: string | null }
      | undefined;
    if (!row) return { ok: false, error: "not_found" };
    // Frozen entity: no new reactions (S2) — same scope as publish/feed
    // (primary + teacher + room context), so a post hidden from feeds can't
    // keep collecting reactions via a remembered id.
    if (this.frozenAnywhere(row.entity_key, row.ctx_teacher_id, row.ctx_room_id)) {
      return { ok: false, error: "entity_frozen" };
    }

    // Verified-exposure gate: reacting requires having encountered the context
    // (the lesson's teacher, or the standalone entity itself).
    let eligible = false;
    if (row.lesson_id) {
      // row.lesson_id is the OPAQUE lesson token (C1) — never compare it to a
      // raw lesson_instance_id (different namespaces; review v3 §12.15C). Match
      // via the teacher context or by re-deriving tokens from OUR exposures.
      eligible = !!(
        (row.ctx_teacher_id &&
          this.db
            .prepare("SELECT 1 FROM user_lesson_exposures WHERE honey_id = ? AND teacher_id = ? LIMIT 1")
            .get(honeyId, row.ctx_teacher_id)) ||
        this.userLessonTokens(honeyId).has(row.lesson_id)
      );
    } else {
      const entity = this.registry.get(row.entity_key);
      eligible = !!entity && this.verifiedExposure(honeyId, row.entity_key, entity.type) !== "";
    }
    if (!eligible) return { ok: false, error: "not_eligible" };

    const dedup = markHash(this.markKey, honeyId, `react:${experienceId}`);
    if (value === 0) {
      this.db
        .prepare("DELETE FROM reactions WHERE experience_id = ? AND dedup_hash = ?")
        .run(experienceId, dedup);
    } else {
      this.db
        .prepare(
          `INSERT INTO reactions (experience_id, dedup_hash, value, created_at) VALUES (?, ?, ?, ?)
           ON CONFLICT(experience_id, dedup_hash) DO UPDATE SET value = excluded.value`,
        )
        .run(experienceId, dedup, value, this.now());
    }
    // Authoritative echo (review v3 §12.15C): the caller renders THIS, and
    // rolls its optimistic UI back to it on failure.
    return { ok: true, value, reactions: this.reactionCounts(experienceId) };
  }

  /** Opaque lesson tokens for every lesson this user was exposed to. */
  private userLessonTokens(honeyId: string): Set<string> {
    const rows = this.db
      .prepare("SELECT lesson_instance_id AS id FROM user_lesson_exposures WHERE honey_id = ?")
      .all(honeyId) as unknown as { id: string }[];
    return new Set(rows.map((r) => this.lessonToken(r.id)));
  }

  /** Public counts with the small-cohort threshold applied (null = hidden). */
  private reactionCounts(experienceId: string): { likes: number; dislikes: number } | null {
    const c = this.db
      .prepare("SELECT SUM(value = 1) AS likes, SUM(value = -1) AS dislikes FROM reactions WHERE experience_id = ?")
      .get(experienceId) as unknown as { likes: number | null; dislikes: number | null };
    const likes = c.likes ?? 0;
    const dislikes = c.dislikes ?? 0;
    return likes + dislikes >= this.settings.reactionMinCount() ? { likes, dislikes } : null;
  }

  // ---------- reports (§22 + review v3 §12.15B): category-only, tri-state ----------
  //
  // A report triggers automatic re-evaluation under the CURRENT policy (rules
  // decide, not votes) with THREE possible resolutions:
  //   CONFIDENT_VIOLATION → hide;  CONFIDENT_ALLOWED → keep;
  //   UNAVAILABLE/UNCERTAIN → keep the post's current public state and queue an
  //   automatic retry. The post already crossed the publication boundary once —
  //   a classifier outage is not evidence of violation, so it must NOT unpublish.

  private static readonly REPORT_RETRY_MS = 30 * 60 * 1000;
  private static readonly REPORT_RATE_WINDOW_MS = 24 * 3600 * 1000;
  private static readonly REPORT_RATE_MAX = 10;

  async report(honeyId: string, experienceId: string, category: ReportCategory): Promise<{ ok: boolean; error?: string }> {
    if (this.settings.killSwitch("DISABLE_REPORTS")) return { ok: false, error: "reports_disabled" };
    const row = this.db
      .prepare("SELECT id, entity_key, body, rating FROM experiences WHERE id = ? AND status = 'published'")
      .get(experienceId) as unknown as
      | { id: string; entity_key: string; body: string | null; rating: number | null }
      | undefined;
    if (!row || !row.body) return { ok: false, error: "not_found" };

    // Reporter dedup: an unlinkable HMAC mark (same construction as reaction
    // dedup — recomputable per account+post, joins to nothing). A repeat
    // report by the same account is idempotent and never re-runs the LLM.
    const reporterMark = markHash(this.markKey, honeyId, `report:${experienceId}`);
    const existing = this.db
      .prepare("SELECT id FROM reports WHERE experience_id = ? AND reporter_mark = ?")
      .get(experienceId, reporterMark);
    if (existing) return { ok: true };

    // Per-account rate limit (rolling 24 h window; counts only, no post ids).
    const rate = this.db
      .prepare("SELECT window_start, count FROM report_rate WHERE honey_id = ?")
      .get(honeyId) as unknown as { window_start: number; count: number } | undefined;
    const windowLive = rate && rate.window_start > this.now() - ExperienceService.REPORT_RATE_WINDOW_MS;
    if (windowLive && rate!.count >= ExperienceService.REPORT_RATE_MAX) {
      return { ok: false, error: "report_rate_limited" };
    }
    this.db
      .prepare(
        `INSERT INTO report_rate (honey_id, window_start, count) VALUES (?, ?, 1)
         ON CONFLICT(honey_id) DO UPDATE SET
           window_start = CASE WHEN report_rate.window_start > ? THEN report_rate.window_start ELSE excluded.window_start END,
           count = CASE WHEN report_rate.window_start > ? THEN report_rate.count + 1 ELSE 1 END`,
      )
      .run(honeyId, this.now(),
        this.now() - ExperienceService.REPORT_RATE_WINDOW_MS,
        this.now() - ExperienceService.REPORT_RATE_WINDOW_MS);

    const reportId = randomUUID();
    this.db
      .prepare(
        "INSERT INTO reports (id, experience_id, category, outcome, created_at, reporter_mark) VALUES (?, ?, ?, 'pending', ?, ?)",
      )
      .run(reportId, experienceId, category, this.now(), reporterMark);

    // Same post already confidently re-judged KEPT under the current policy →
    // don't pay for another identical LLM verdict (S: no repeat spend).
    const priorKept = this.db
      .prepare(
        "SELECT 1 FROM reports WHERE experience_id = ? AND outcome = 'reevaluated_kept' AND policy_version = ? AND id != ?",
      )
      .get(experienceId, POLICY_VERSION, reportId);
    if (priorKept) {
      this.db
        .prepare("UPDATE reports SET outcome = 'reevaluated_kept', policy_version = ? WHERE id = ?")
        .run(POLICY_VERSION, reportId);
      return { ok: true };
    }

    await this.reevaluate(reportId, experienceId);
    return { ok: true };
  }

  /** Re-run moderation for one report and resolve it tri-state. */
  private async reevaluate(reportId: string, experienceId: string): Promise<void> {
    const row = this.db
      .prepare("SELECT id, entity_key, body, rating, status FROM experiences WHERE id = ?")
      .get(experienceId) as unknown as
      | { id: string; entity_key: string; body: string | null; rating: number | null; status: string }
      | undefined;
    if (!row || row.status !== "published" || !row.body) {
      // Nothing public left to judge (revoked/hidden meanwhile) — close out.
      this.db
        .prepare("UPDATE reports SET outcome = 'reevaluated_kept', retry_at = NULL, policy_version = ? WHERE id = ?")
        .run(POLICY_VERSION, reportId);
      return;
    }
    const entityType = row.entity_key.split(":")[0] ?? "lesson";
    const decision = await this.computeDecision(row.body, entityType, row.rating);

    const unavailable =
      decision.action === "failed_closed" ||
      (decision.action === "rephrase_required" && decision.reasons.includes("expression:uncertain"));
    if (unavailable) {
      // UNAVAILABLE/UNCERTAIN: keep the current public state, retry later.
      this.db
        .prepare("UPDATE reports SET outcome = 'reevaluation_pending', retry_at = ? WHERE id = ?")
        .run(this.now() + ExperienceService.REPORT_RETRY_MS, reportId);
      return;
    }

    // Timing (cooldown) is a pre-publication intervention, not a violation —
    // it never retro-hides an already-published post.
    const kept =
      decision.action === "publish" ||
      decision.action === "publish_nudge" ||
      decision.action === "cooldown_24h";
    if (kept) {
      this.db
        .prepare("UPDATE reports SET outcome = 'reevaluated_kept', retry_at = NULL, policy_version = ? WHERE id = ?")
        .run(POLICY_VERSION, reportId);
      return;
    }

    // CONFIDENT_VIOLATION under the current policy → hide.
    this.db
      .prepare("UPDATE experiences SET status = 'blocked', body = NULL, rating = NULL, status_detail = ? WHERE id = ?")
      .run("report_reevaluation", experienceId);
    this.db
      .prepare("UPDATE reports SET outcome = 'reevaluated_hidden', retry_at = NULL, policy_version = ? WHERE id = ?")
      .run(POLICY_VERSION, reportId);
  }

  /**
   * Retry queue sweep: re-run re-evaluations that failed closed earlier, plus
   * any report stranded at 'pending' (a crash between INSERT and the first
   * reevaluate, or legacy rows) once it is 10+ minutes old.
   */
  async processPendingReevaluations(): Promise<number> {
    const due = this.db
      .prepare(
        `SELECT id, experience_id FROM reports
         WHERE (outcome = 'reevaluation_pending' AND retry_at IS NOT NULL AND retry_at <= ?)
            OR (outcome = 'pending' AND created_at <= ?)
         LIMIT 20`,
      )
      .all(this.now(), this.now() - 10 * 60_000) as unknown as { id: string; experience_id: string }[];
    for (const r of due) await this.reevaluate(r.id, r.experience_id);
    return due.length;
  }
}
