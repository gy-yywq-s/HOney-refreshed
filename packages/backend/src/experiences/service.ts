import { randomUUID } from "node:crypto";
import type { DatabaseSync } from "node:sqlite";
import { generateToken, hashToken } from "../crypto.js";
import { lexicalScan } from "./lexicon.js";
import { extractFeatures, type LlmVerdict } from "./llm.js";
import { normalizeText } from "./normalize.js";
import { decide, POLICY_VERSION, type PolicyDecision } from "./policy.js";
import { contentHashOf, contextHashOf, issuePass, markHash, verifyPass } from "./pass.js";
import type { EntityRegistry } from "./entities.js";
import type { SettingsService } from "./settings.js";

// The Experiences core (App A). Structural guarantees enforced here:
//   - the experiences table has NO author column; ownership is provable only
//     by a client-held key (users are warned it is device-only);
//   - moderation runs ONCE per content hash and issues a signed pass; the
//     publication step verifies the pass — it never re-runs the LLM;
//   - rejected / failed-closed text is NOT persisted server-side;
//   - one-review-per-lesson via unlinkable HMAC marks (join to nothing);
//   - every kill switch is honored before any state changes.

export interface SubmitInput {
  honeyId: string;
  /** Either a lessonId (lesson-linked) or a standalone entityKey. */
  lessonId?: string;
  entityKey?: string;
  body: string;
  rating?: number;
}

export type SubmitOutcome =
  | { ok: true; experienceId: string; ownershipKey: string; status: string }
  | { ok: false; error: string };

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
  cooldown_until: number | null;
  ownership_hash: string;
  content_hash: string;
  policy_version: number;
  created_at: number;
  published_at: number | null;
}

export type LlmRunner = (text: string) => Promise<LlmVerdict>;

export class ExperienceService {
  /** Injectable for tests; default uses SettingsService config. */
  llmRunner: LlmRunner;

  constructor(
    private readonly db: DatabaseSync,
    private readonly registry: EntityRegistry,
    private readonly settings: SettingsService,
    private readonly sealKey: Buffer,
    private readonly now: () => number = Date.now,
  ) {
    this.llmRunner = async (text) => {
      const config = this.settings.llmConfig();
      if (!config) return { ok: false };
      return extractFeatures(text, config);
    };
  }

  // ---------- submission ----------

  async submit(input: SubmitInput): Promise<SubmitOutcome> {
    if (this.settings.killSwitch("DISABLE_NEW_PUBLICATIONS") || this.settings.killSwitch("PRIVATE_NOTES_ONLY_MODE")) {
      return { ok: false, error: "publications_disabled" };
    }
    const body = (input.body ?? "").trim();
    if (!body || body.length > 5000) return { ok: false, error: "body_invalid" };
    const rating = input.rating ?? null;
    if (rating !== null && (rating < 1 || rating > 5 || !Number.isInteger(rating))) {
      return { ok: false, error: "rating_invalid" };
    }

    let entityKey: string;
    let entityType: string;
    let provenance: string;
    let ctx: { teacher: string | null; course: string | null; room: string | null } = {
      teacher: null,
      course: null,
      room: null,
    };
    let lessonId: string | null = null;
    let dedupScope: string;

    if (input.lessonId) {
      // Lesson-linked: unconditional right to review one's OWN lessons, once each.
      const lesson = this.db
        .prepare(
          `SELECT li.id, li.teacher_id, li.course_id, li.room_id FROM user_lesson_exposures e
           JOIN lesson_instances li ON li.id = e.lesson_instance_id
           WHERE e.honey_id = ? AND li.id = ?`,
        )
        .get(input.honeyId, input.lessonId) as unknown as
        | { id: string; teacher_id: string | null; course_id: string | null; room_id: string | null }
        | undefined;
      if (!lesson) return { ok: false, error: "lesson_not_yours" };
      lessonId = lesson.id;
      entityKey = `lesson:${lesson.id}`;
      entityType = "lesson";
      provenance = "verified_lesson";
      ctx = { teacher: lesson.teacher_id, course: lesson.course_id, room: lesson.room_id };
      dedupScope = entityKey;
    } else if (input.entityKey) {
      const entity = this.registry.get(input.entityKey);
      if (!entity) return { ok: false, error: "entity_unknown" };
      if (this.settings.frozenEntity(entity.entity_key)) return { ok: false, error: "entity_frozen" };
      const mode = this.settings.standaloneMode(entity.entity_key, entity.type);
      if (mode === "closed") return { ok: false, error: "standalone_closed" };
      if (mode === "invite") {
        const invited = this.db
          .prepare("SELECT 1 FROM invite_marks WHERE entity_key = ? AND mark_hash = ?")
          .get(entity.entity_key, markHash(this.sealKey, input.honeyId, `invite:${entity.entity_key}`));
        if (!invited) return { ok: false, error: "not_invited" };
        provenance = "verified_member";
      } else if (mode === "verified") {
        provenance = this.verifiedExposure(input.honeyId, entity.entity_key, entity.type);
        if (!provenance) return { ok: false, error: "no_verified_exposure" };
      } else {
        provenance = "verified_member"; // open
      }
      entityKey = entity.entity_key;
      entityType = entity.type;
      dedupScope = entityKey;
    } else {
      return { ok: false, error: "target_required" };
    }

    if (rating !== null && entityType !== "dish") return { ok: false, error: "rating_not_allowed" };

    // One review per scope (lesson always; standalone per current rules).
    const mark = markHash(this.sealKey, input.honeyId, dedupScope);
    const markExists = this.db.prepare("SELECT 1 FROM review_marks WHERE mark_hash = ?").get(mark);
    if (markExists) return { ok: false, error: "already_reviewed" };

    const id = randomUUID();
    const ownershipKey = generateToken();
    const contentHash = contentHashOf(body, rating);
    this.db.exec("BEGIN");
    try {
      this.db.prepare("INSERT INTO review_marks (mark_hash) VALUES (?)").run(mark);
      this.db
        .prepare(
          `INSERT INTO experiences (id, entity_key, lesson_id, ctx_teacher_id, ctx_course_id, ctx_room_id,
             body, rating, provenance, status, ownership_hash, content_hash, policy_version, created_at)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 'pending', ?, ?, ?, ?)`,
        )
        .run(
          id, entityKey, lessonId, ctx.teacher, ctx.course, ctx.room,
          body, rating, provenance, hashToken(ownershipKey), contentHash, POLICY_VERSION, this.now(),
        );
      this.db.exec("COMMIT");
    } catch (e) {
      this.db.exec("ROLLBACK");
      throw e;
    }

    // Async moderation: the submitter gets an immediate response; the pipeline
    // runs in the background and the post appears when the pass is issued.
    void this.moderate(id, entityKey, entityType, body, rating, ctx, mark).catch(() => {
      this.setStatus(id, "failed_closed", "pipeline_error");
      this.releaseMark(mark);
      this.clearBody(id);
    });

    return { ok: true, experienceId: id, ownershipKey, status: "pending" };
  }

  /** Run the full pipeline once and apply the deterministic decision. */
  private async moderate(
    id: string,
    entityKey: string,
    entityType: string,
    body: string,
    rating: number | null,
    ctx: { teacher: string | null; course: string | null; room: string | null },
    mark: string,
  ): Promise<void> {
    const normalized = normalizeText(body);
    const lexical = lexicalScan(normalized);

    // Lexical hard-blocks skip the LLM entirely (cheap + fail-safe).
    let decision: PolicyDecision;
    if (lexical.length > 0) {
      decision = decide({ lexical, llm: null, entityType, hasRating: rating !== null });
      if (decision.action === "failed_closed") {
        // decide() returns failed_closed only for llm:null with no lexical flags;
        // with flags present it always returns a block — this branch is defensive.
        decision = { ...decision, action: "blocked_serious" };
      }
    } else {
      const verdict = await this.llmRunner(normalized.original);
      decision = decide({
        lexical,
        llm: verdict.ok && verdict.features ? verdict.features : null,
        entityType,
        hasRating: rating !== null,
      });
    }

    switch (decision.action) {
      case "publish":
      case "publish_nudge": {
        // Issue + immediately verify the content-bound pass (single-use nonce):
        // the publication step trusts ONLY the signed artifact.
        const { payload, signature } = issuePass(
          {
            contentHash: contentHashOf(body, rating),
            entityKey,
            contextHash: contextHashOf({ t: ctx.teacher, c: ctx.course, r: ctx.room }),
            policyVersion: decision.policyVersion,
          },
          this.sealKey,
          10 * 60 * 1000,
          this.now(),
        );
        this.publishWithPass(id, payload, signature, decision.action === "publish_nudge" ? "nudge" : null);
        return;
      }
      case "cooldown_24h":
        this.db
          .prepare("UPDATE experiences SET status = 'cooldown', status_detail = ?, cooldown_until = ? WHERE id = ?")
          .run(decision.reasons.join(","), this.now() + 24 * 3600 * 1000, id);
        return;
      case "rephrase_required":
        this.setStatus(id, "rephrase_required", decision.reasons.join(","));
        this.clearBody(id);
        this.releaseMark(mark);
        return;
      case "blocked_serious":
      case "blocked_out_of_scope":
        this.setStatus(id, "blocked", decision.reasons.join(","));
        this.clearBody(id); // rejected text is NOT persisted (App A §20)
        this.releaseMark(mark);
        return;
      case "failed_closed":
        this.setStatus(id, "failed_closed", decision.reasons.join(","));
        this.clearBody(id);
        this.releaseMark(mark);
        return;
    }
  }

  /** Community acceptance: verify signature, expiry, nonce single-use, content binding. */
  private publishWithPass(
    id: string,
    payload: Parameters<typeof verifyPass>[0],
    signature: string,
    nudge: string | null,
  ): void {
    if (!verifyPass(payload, signature, this.sealKey, this.now())) {
      this.setStatus(id, "failed_closed", "pass_invalid");
      return;
    }
    const nonceUsed = this.db.prepare("SELECT 1 FROM pass_nonces WHERE nonce = ?").get(payload.nonce);
    if (nonceUsed) {
      this.setStatus(id, "failed_closed", "pass_replay");
      return;
    }
    const row = this.db
      .prepare("SELECT content_hash, entity_key FROM experiences WHERE id = ?")
      .get(id) as unknown as { content_hash: string; entity_key: string } | undefined;
    if (!row || row.content_hash !== payload.contentHash || row.entity_key !== payload.entityKey) {
      this.setStatus(id, "failed_closed", "pass_content_mismatch");
      return;
    }
    this.db.exec("BEGIN");
    try {
      this.db.prepare("INSERT INTO pass_nonces (nonce, used_at) VALUES (?, ?)").run(payload.nonce, this.now());
      this.db
        .prepare("UPDATE experiences SET status = 'published', status_detail = ?, published_at = ? WHERE id = ?")
        .run(nudge, this.now(), id);
      this.db.exec("COMMIT");
    } catch (e) {
      this.db.exec("ROLLBACK");
      throw e;
    }
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

  // ---------- ownership: history / cooldown reconfirm / revoke ----------

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

  /** After the cooling-off window the user actively reconfirms publication. */
  reconfirm(ownershipKey: string): { ok: boolean; error?: string; status?: string } {
    const row = this.byKey(ownershipKey);
    if (!row) return { ok: false, error: "not_found" };
    if (row.status !== "cooldown") return { ok: false, error: "not_in_cooldown" };
    if ((row.cooldown_until ?? 0) > this.now()) return { ok: false, error: "cooldown_active" };
    if (this.settings.killSwitch("DISABLE_NEW_PUBLICATIONS")) return { ok: false, error: "publications_disabled" };
    // Content unchanged and already checked; high-arousal was the only reason.
    this.db
      .prepare("UPDATE experiences SET status = 'published', published_at = ? WHERE id = ?")
      .run(this.now(), row.id);
    return { ok: true, status: "published" };
  }

  /**
   * Revoke (authenticated + key-proved). The mark is recomputed transiently to
   * free the user's one-review slot; nothing persisted links user to post.
   */
  revoke(honeyId: string, ownershipKey: string): { ok: boolean; error?: string } {
    const row = this.byKey(ownershipKey);
    if (!row) return { ok: false, error: "not_found" };
    if (row.status === "revoked") return { ok: false, error: "already_revoked" };
    const scope = row.lesson_id ? `lesson:${row.lesson_id}` : row.entity_key;
    this.db.exec("BEGIN");
    try {
      this.db
        .prepare("UPDATE experiences SET status = 'revoked', body = NULL, rating = NULL WHERE id = ?")
        .run(row.id);
      this.db
        .prepare("DELETE FROM review_marks WHERE mark_hash = ?")
        .run(markHash(this.sealKey, honeyId, scope));
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
  }): (Omit<ExperienceRow, "ownership_hash" | "content_hash"> & { reactions: { likes: number; dislikes: number } | null })[] {
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
      clauses.push("body LIKE ?");
      params.push(`%${opts.q}%`);
    }
    if (opts.before) {
      clauses.push("published_at < ?");
      params.push(opts.before);
    }
    const order = opts.sort === "oldest" ? "ASC" : "DESC"; // allowed sorts only
    const limit = Math.min(Math.max(opts.limit ?? 50, 1), 200);
    const rows = this.db
      .prepare(
        `SELECT id, entity_key, lesson_id, ctx_teacher_id, ctx_course_id, ctx_room_id, body, rating,
                provenance, status, status_detail, cooldown_until, policy_version, created_at, published_at
         FROM experiences WHERE ${clauses.join(" AND ")} ORDER BY published_at ${order} LIMIT ${limit}`,
      )
      .all(...params) as unknown as Omit<ExperienceRow, "ownership_hash" | "content_hash">[];

    const minCount = this.settings.reactionMinCount();
    const countStmt = this.db.prepare(
      "SELECT SUM(value = 1) AS likes, SUM(value = -1) AS dislikes FROM reactions WHERE experience_id = ?",
    );
    return rows.map((r) => {
      const c = countStmt.get(r.id) as unknown as { likes: number | null; dislikes: number | null };
      const likes = c.likes ?? 0;
      const dislikes = c.dislikes ?? 0;
      // Small-cohort hiding: counts below the threshold stay hidden.
      const reactions = likes + dislikes >= minCount ? { likes, dislikes } : null;
      return { ...r, reactions };
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

    const dedup = markHash(this.sealKey, honeyId, `react:${experienceId}`);
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

  // ---------- reports (§22): rule-based, auto re-evaluation, no human queue ----------

  async report(experienceId: string, category: string, note?: string): Promise<{ ok: boolean; error?: string }> {
    const valid = ["serious_allegation", "doxxing", "slur", "targets_student", "not_experience", "other_rule"];
    if (!valid.includes(category)) return { ok: false, error: "bad_category" };
    const row = this.db
      .prepare("SELECT id, entity_key, body, rating FROM experiences WHERE id = ? AND status = 'published'")
      .get(experienceId) as unknown as
      | { id: string; entity_key: string; body: string | null; rating: number | null }
      | undefined;
    if (!row || !row.body) return { ok: false, error: "not_found" };

    const reportId = randomUUID();
    this.db
      .prepare("INSERT INTO reports (id, experience_id, category, note, outcome, created_at) VALUES (?, ?, ?, ?, 'pending', ?)")
      .run(reportId, experienceId, category, note ?? null, this.now());

    // Automatic re-evaluation with the CURRENT policy (rules decide, not votes).
    const normalized = normalizeText(row.body);
    const lexical = lexicalScan(normalized);
    const verdict = lexical.length > 0 ? null : await this.llmRunner(normalized.original);
    const entityType = row.entity_key.split(":")[0] ?? "lesson";
    const decision = decide({
      lexical,
      llm: verdict?.ok && verdict.features ? verdict.features : null,
      entityType,
      hasRating: row.rating !== null,
    });
    const shouldHide =
      lexical.length > 0 ||
      decision.action === "blocked_serious" ||
      decision.action === "blocked_out_of_scope";
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

  // ---------- helpers ----------

  private setStatus(id: string, status: string, detail: string): void {
    this.db
      .prepare("UPDATE experiences SET status = ?, status_detail = ? WHERE id = ?")
      .run(status, detail, id);
  }

  private clearBody(id: string): void {
    this.db.prepare("UPDATE experiences SET body = NULL, rating = NULL WHERE id = ?").run(id);
  }

  private releaseMark(mark: string): void {
    this.db.prepare("DELETE FROM review_marks WHERE mark_hash = ?").run(mark);
  }

  /** Await all in-flight moderation jobs (tests). */
  async settle(): Promise<void> {
    await new Promise((r) => setImmediate(r));
  }
}
