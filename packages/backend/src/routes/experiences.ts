import type { FastifyInstance } from "fastify";
import type { AppContext } from "../context.js";
import type { ReportCategory } from "@honey/shared/api";

// Experiences surface (App A). Two-call publication flow (audit §3.7/§3.8):
//   eligibility (auth) → check (auth, synchronous moderation, persists nothing)
//   → publish (NO session auth: eligibility token + content-bound pass only).
// Feeds are raw-first with allowed sorts only.

const REPORT_CATEGORIES: ReportCategory[] = [
  "serious_allegation",
  "doxxing",
  "slur",
  "targets_student",
  "not_experience",
  "other_rule",
];

export function registerExperienceRoutes(app: FastifyInstance, ctx: AppContext): void {
  app.get<{
    Querystring: {
      entityKey?: string; teacherId?: string; courseId?: string; roomId?: string;
      q?: string; sort?: string; before?: string; limit?: string;
    };
  }>("/api/experiences", { preHandler: ctx.requireAuth }, async (req) => {
    const { entityKey, teacherId, courseId, roomId, q, sort, before, limit } = req.query;
    const opts: Parameters<typeof ctx.experiences.feed>[0] = {};
    if (entityKey) opts.entityKey = entityKey;
    if (teacherId) opts.teacherId = teacherId;
    if (courseId) opts.courseId = courseId;
    if (roomId) opts.roomId = roomId;
    if (q) opts.q = q;
    if (sort === "oldest") opts.sort = "oldest";
    if (before) opts.before = Number(before);
    if (limit) opts.limit = Number(limit);
    return { experiences: ctx.experiences.feed(opts) };
  });

  /** Domain query (audit §4.2): published posts relevant to MY verified exposure. */
  app.get<{ Querystring: { before?: string; limit?: string } }>(
    "/api/experiences/from-my-classes",
    { preHandler: ctx.requireAuth },
    async (req) => {
      const user = ctx.userOf(req);
      const opts: { before?: number; limit?: number } = {};
      if (req.query.before) opts.before = Number(req.query.before);
      if (req.query.limit) opts.limit = Number(req.query.limit);
      return { experiences: ctx.experiences.fromMyClasses(user.honey_id, opts) };
    },
  );

  app.get<{ Querystring: { type?: string; q?: string } }>(
    "/api/entities",
    { preHandler: ctx.requireAuth },
    async (req) => {
      const type = req.query.type as "teacher" | "room" | "dish" | undefined;
      return { entities: ctx.entities.list(type, req.query.q) };
    },
  );

  /** Step 1 — single-use, scope-bound eligibility token (stored unlinkably). */
  app.post<{ Body: { lessonId?: string; entityKey?: string } }>(
    "/api/experiences/eligibility",
    { preHandler: ctx.requireAuth },
    async (req, reply) => {
      const user = ctx.userOf(req);
      const { lessonId, entityKey } = req.body ?? {};
      const input: Parameters<typeof ctx.experiences.issueEligibility>[0] = { honeyId: user.honey_id };
      if (lessonId) input.lessonId = lessonId;
      if (entityKey) input.entityKey = entityKey;
      const result = ctx.experiences.issueEligibility(input);
      if (!result.ok) return reply.code(422).send({ error: result.error });
      return reply.send(result);
    },
  );

  /** Step 2 — synchronous moderation preflight. The draft is NEVER persisted. */
  app.post<{ Body: { lessonId?: string; entityKey?: string; body?: string; rating?: number; cooldownTicket?: string } }>(
    "/api/experiences/check",
    { preHandler: ctx.requireAuth },
    async (req, reply) => {
      const user = ctx.userOf(req);
      const { lessonId, entityKey, body, rating, cooldownTicket } = req.body ?? {};
      const input: Parameters<typeof ctx.experiences.check>[0] = {
        honeyId: user.honey_id,
        body: body ?? "",
      };
      if (lessonId) input.lessonId = lessonId;
      if (entityKey) input.entityKey = entityKey;
      if (rating !== undefined) input.rating = rating;
      if (cooldownTicket !== undefined) input.cooldownTicket = cooldownTicket;
      const result = await ctx.experiences.check(input);
      if (!result.ok) return reply.code(422).send({ error: result.error });
      const { ok: _ok, ...response } = result;
      return reply.send(response);
    },
  );

  /**
   * Step 3 — publish. Deliberately NO session auth: the request authenticates
   * purely by eligibility token + content-bound pass, so it carries no account
   * identity. Publication happens ONLY here, on explicit client action.
   */
  app.post<{ Body: { eligibilityToken?: string; pass?: string; body?: string; rating?: number } }>(
    "/api/experiences/publish",
    async (req, reply) => {
      const { eligibilityToken, pass, body, rating } = req.body ?? {};
      if (!eligibilityToken || !pass) {
        return reply.code(400).send({ error: "eligibilityToken and pass required" });
      }
      const input: Parameters<typeof ctx.experiences.publish>[0] = {
        eligibilityToken,
        pass,
        body: body ?? "",
      };
      if (rating !== undefined) input.rating = rating;
      const result = ctx.experiences.publish(input);
      if (!result.ok) return reply.code(422).send({ error: result.error });
      return reply.send(result);
    },
  );

  /** Client-held-keys lookup: the caller's own published-post history. */
  app.post<{ Body: { keys?: string[] } }>(
    "/api/experiences/mine",
    { preHandler: ctx.requireAuth },
    async (req, reply) => {
      const keys = req.body?.keys;
      if (!Array.isArray(keys)) return reply.code(400).send({ error: "keys required" });
      const rows = ctx.experiences.mine(keys.filter((k) => typeof k === "string"));
      // Ownership/content hashes stay server-side.
      return {
        experiences: rows.map(({ ownership_hash: _o, content_hash: _c, ...rest }) => rest),
      };
    },
  );

  app.post<{ Body: { ownershipKey?: string } }>(
    "/api/experiences/revoke",
    { preHandler: ctx.requireAuth },
    async (req, reply) => {
      const user = ctx.userOf(req);
      const key = req.body?.ownershipKey;
      if (!key) return reply.code(400).send({ error: "ownershipKey required" });
      const result = ctx.experiences.revoke(user.honey_id, key);
      if (!result.ok) return reply.code(422).send({ error: result.error });
      return reply.send(result);
    },
  );

  app.post<{ Params: { id: string }; Body: { value?: number } }>(
    "/api/experiences/:id/react",
    { preHandler: ctx.requireAuth },
    async (req, reply) => {
      const user = ctx.userOf(req);
      const value = req.body?.value;
      if (value !== 1 && value !== -1 && value !== 0) {
        return reply.code(400).send({ error: "value must be 1, -1 or 0" });
      }
      const result = ctx.experiences.react(user.honey_id, req.params.id, value as 1 | -1 | 0);
      if (!result.ok) return reply.code(422).send({ error: result.error });
      return reply.send(result);
    },
  );

  /** Reports are category-only (audit §3.9): free text is rejected outright. */
  app.post<{ Params: { id: string }; Body: { category?: string; note?: unknown } }>(
    "/api/experiences/:id/report",
    { preHandler: ctx.requireAuth },
    async (req, reply) => {
      const { category, note } = req.body ?? {};
      if (note !== undefined) return reply.code(400).send({ error: "free_text_not_accepted" });
      if (!category || !REPORT_CATEGORIES.includes(category as ReportCategory)) {
        return reply.code(400).send({ error: "bad_category" });
      }
      const result = await ctx.experiences.report(req.params.id, category as ReportCategory);
      if (!result.ok) return reply.code(422).send({ error: result.error });
      return reply.send(result);
    },
  );
}
