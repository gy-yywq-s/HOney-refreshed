import type { FastifyInstance } from "fastify";
import type { AppContext } from "../context.js";

// Experiences surface (App A). Feeds are raw-first with allowed sorts only;
// submission is async — the response returns immediately with the client-held
// ownership key, and the post appears once the signed pass is issued.

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

  app.get<{ Querystring: { type?: string; q?: string } }>(
    "/api/entities",
    { preHandler: ctx.requireAuth },
    async (req) => {
      const type = req.query.type as "teacher" | "room" | "dish" | undefined;
      return { entities: ctx.entities.list(type, req.query.q) };
    },
  );

  app.post<{ Body: { lessonId?: string; entityKey?: string; body?: string; rating?: number } }>(
    "/api/experiences",
    { preHandler: ctx.requireAuth },
    async (req, reply) => {
      const user = ctx.userOf(req);
      const { lessonId, entityKey, body, rating } = req.body ?? {};
      const input: Parameters<typeof ctx.experiences.submit>[0] = {
        honeyId: user.honey_id,
        body: body ?? "",
      };
      if (lessonId) input.lessonId = lessonId;
      if (entityKey) input.entityKey = entityKey;
      if (rating !== undefined) input.rating = rating;
      const result = await ctx.experiences.submit(input);
      if (!result.ok) return reply.code(422).send({ error: result.error });
      return reply.send(result);
    },
  );

  /** Client-held-keys lookup: the caller's own submission history (any status). */
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
    "/api/experiences/reconfirm",
    { preHandler: ctx.requireAuth },
    async (req, reply) => {
      const key = req.body?.ownershipKey;
      if (!key) return reply.code(400).send({ error: "ownershipKey required" });
      const result = ctx.experiences.reconfirm(key);
      if (!result.ok) return reply.code(422).send({ error: result.error });
      return reply.send(result);
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

  app.post<{ Params: { id: string }; Body: { category?: string; note?: string } }>(
    "/api/experiences/:id/report",
    { preHandler: ctx.requireAuth },
    async (req, reply) => {
      const { category, note } = req.body ?? {};
      if (!category) return reply.code(400).send({ error: "category required" });
      const result = await ctx.experiences.report(req.params.id, category, note);
      if (!result.ok) return reply.code(422).send({ error: result.error });
      return reply.send(result);
    },
  );
}
