import { createHmac, randomUUID, timingSafeEqual } from "node:crypto";
import type { DatabaseSync } from "node:sqlite";
import { deriveKey, generateToken, hashToken } from "../crypto.js";
import { lexicalScan } from "./lexicon.js";
import { extractFeatures, type LlmVerdict } from "./llm.js";
import { normalizeText } from "./normalize.js";
import { decide, POLICY_VERSION, type PolicyDecision } from "./policy.js";
import { contentHashOf, contextHashOf, issuePass, markHash, verifyPass, type PassPayload } from "./pass.js";
import type { EntityRegistry } from "./entities.js";
import type { SettingsService } from "./settings.js";
import type { CheckExperienceResponse, PublicExperience, ReportCategory } from "@honey/shared/api";

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
const COOLDOWN_MS = 24 * 3600 * 1000;
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
        const notBefore = this.now() + COOLDOWN_MS;
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
      // Lexical hard-blocks skip the LLM entirely (cheap + fail-safe).
      const decision = decide({ lexical, llm: null, entityType, hasRating: rating !== null });
      return decision.action === "failed_closed" ? { ...decision, action: "blocked_serious" } : decision;
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
      clauses.push("ctx_course_id = ?");
      params.push(opts.courseId);
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
    return this.selectPublic(clauses.join(" AND "), params, order, opts.limit);
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
    return this.selectPublic(clauses.join(" AND "), params, "DESC", opts.limit);
  }

  /** Shared public projection: frozen-entity filter, reaction hiding, day bucket. */
  private selectPublic(where: string, params: (string | number)[], order: "ASC" | "DESC", rawLimit?: number): PublicExperience[] {
    const limit = Math.min(Math.max(Math.trunc(Number.isFinite(rawLimit) ? (rawLimit as number) : 50), 1), 200);
    const rows = this.db
      .prepare(
        `SELECT id, entity_key, ctx_teacher_id, ctx_course_id, ctx_room_id, body, rating,
                provenance, published_at
         FROM experiences WHERE ${where} ORDER BY published_at ${order} LIMIT ${limit}`,
      )
      .all(...params) as unknown as {
        id: string; entity_key: string; ctx_teacher_id: string | null; ctx_course_id: string | null;
        ctx_room_id: string | null; body: string | null; rating: number | null; provenance: string;
        published_at: number | null;
      }[];

    const minCount = this.settings.reactionMinCount();
    const countStmt = this.db.prepare(
      "SELECT SUM(value = 1) AS likes, SUM(value = -1) AS dislikes FROM reactions WHERE experience_id = ?",
    );
    return rows
      // Hide posts whose primary or context entity is frozen (S2).
      .filter((r) => !this.frozenAnywhere(r.entity_key, r.ctx_teacher_id, r.ctx_room_id))
      .map((r) => {
        const c = countStmt.get(r.id) as unknown as { likes: number | null; dislikes: number | null };
        const likes = c.likes ?? 0;
        const dislikes = c.dislikes ?? 0;
        const reactions = likes + dislikes >= minCount ? { likes, dislikes } : null;
        // Publicly expose only a coarse day bucket, never exact ms (S5); the raw
        // lesson token is omitted entirely (C1), as are all internal fields.
        const { published_at, ...pub } = r;
        return {
          ...pub,
          provenance: r.provenance as PublicExperience["provenance"],
          publishedDay: published_at ? this.dayBucket(published_at) : null,
          reactions,
        };
      });
  }

  // ---------- reactions (§10) ----------

  react(honeyId: string, experienceId: string, value: 1 | -1 | 0): { ok: boolean; error?: string } {
    if (this.settings.killSwitch("DISABLE_REACTIONS")) return { ok: false, error: "reactions_disabled" };
    const row = this.db
      .prepare("SELECT id, entity_key, lesson_id, ctx_teacher_id FROM experiences WHERE id = ? AND status = 'published'")
      .get(experienceId) as unknown as
      | { id: string; entity_key: string; lesson_id: string | null; ctx_teacher_id: string | null }
      | undefined;
    if (!row) return { ok: false, error: "not_found" };
    // Frozen entity: no new reactions (S2).
    if (
      this.settings.frozenEntity(row.entity_key) ||
      (row.ctx_teacher_id && this.settings.frozenEntity(`teacher:${row.ctx_teacher_id}`))
    ) {
      return { ok: false, error: "entity_frozen" };
    }

    // Verified-exposure gate: reacting requires having encountered the context
    // (the lesson's teacher, or the standalone entity itself).
    let eligible = false;
    if (row.lesson_id) {
      eligible = !!(
        (row.ctx_teacher_id &&
          this.db
            .prepare("SELECT 1 FROM user_lesson_exposures WHERE honey_id = ? AND teacher_id = ? LIMIT 1")
            .get(honeyId, row.ctx_teacher_id)) ||
        this.db
          .prepare("SELECT 1 FROM user_lesson_exposures WHERE honey_id = ? AND lesson_instance_id = ?")
          .get(honeyId, row.lesson_id)
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
      return { ok: true };
    }
    this.db
      .prepare(
        `INSERT INTO reactions (experience_id, dedup_hash, value, created_at) VALUES (?, ?, ?, ?)
         ON CONFLICT(experience_id, dedup_hash) DO UPDATE SET value = excluded.value`,
      )
      .run(experienceId, dedup, value, this.now());
    return { ok: true };
  }

  // ---------- reports (§22): category-only, auto re-evaluation, no human queue ----------

  async report(experienceId: string, category: ReportCategory): Promise<{ ok: boolean; error?: string }> {
    const row = this.db
      .prepare("SELECT id, entity_key, body, rating FROM experiences WHERE id = ? AND status = 'published'")
      .get(experienceId) as unknown as
      | { id: string; entity_key: string; body: string | null; rating: number | null }
      | undefined;
    if (!row || !row.body) return { ok: false, error: "not_found" };

    const reportId = randomUUID();
    this.db
      .prepare("INSERT INTO reports (id, experience_id, category, outcome, created_at) VALUES (?, ?, ?, 'pending', ?)")
      .run(reportId, experienceId, category, this.now());

    // Automatic re-evaluation with the CURRENT policy (rules decide, not votes).
    const entityType = row.entity_key.split(":")[0] ?? "lesson";
    const decision = await this.computeDecision(row.body, entityType, row.rating);
    // Hide on any non-publishable outcome, INCLUDING failed_closed/uncertain: a
    // reported post must not stay public just because the classifier is down (S1).
    const shouldHide = decision.action !== "publish" && decision.action !== "publish_nudge";
    if (shouldHide) {
      this.db
        .prepare("UPDATE experiences SET status = 'blocked', body = NULL, rating = NULL, status_detail = ? WHERE id = ?")
        .run("report_reevaluation", experienceId);
      this.db.prepare("UPDATE reports SET outcome = 'reevaluated_hidden' WHERE id = ?").run(reportId);
    } else {
      this.db.prepare("UPDATE reports SET outcome = 'reevaluated_kept' WHERE id = ?").run(reportId);
    }
    return { ok: true };
  }
}
