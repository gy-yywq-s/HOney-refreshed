import type { FastifyInstance } from "fastify";
import type { AppContext } from "../context.js";

// Data surface (spec §14.3): UI-agnostic domain queries. Screens compose these;
// none of them encodes a screen.

export function registerDataRoutes(app: FastifyInstance, ctx: AppContext): void {
  app.post("/api/sync", { preHandler: ctx.requireAuth }, async (req) => {
    const user = ctx.userOf(req);
    const result = await ctx.importer.syncTimetable(user.honey_id);
    return result;
  });

  app.get<{ Querystring: { date?: string } }>(
    "/api/timetable",
    { preHandler: ctx.requireAuth },
    async (req, reply) => {
      const user = ctx.userOf(req);
      const dateStr = req.query.date;
      const base = dateStr ? new Date(`${dateStr}T00:00:00`) : new Date();
      if (Number.isNaN(base.getTime())) return reply.code(400).send({ error: "bad date" });
      const dayStart = new Date(base);
      dayStart.setHours(0, 0, 0, 0);
      const dayEnd = new Date(dayStart);
      dayEnd.setDate(dayEnd.getDate() + 1);
      const connection = ctx.accounts.getConnection(user.honey_id);
      return {
        date: dayStart.toISOString().slice(0, 10),
        lessons: ctx.timetable.lessonsForDay(user.honey_id, dayStart.getTime(), dayEnd.getTime()),
        lastSyncedAt: connection.lastSyncedAt?.toISOString() ?? null,
      };
    },
  );

  app.get("/api/next-lesson", { preHandler: ctx.requireAuth }, async (req) => {
    const user = ctx.userOf(req);
    const connection = ctx.accounts.getConnection(user.honey_id);
    return {
      nextLesson: ctx.timetable.nextLesson(user.honey_id),
      lastSyncedAt: connection.lastSyncedAt?.toISOString() ?? null,
    };
  });

  app.get<{
    Querystring: { q?: string; teacherId?: string; courseId?: string; before?: string; limit?: string; order?: string };
  }>("/api/history", { preHandler: ctx.requireAuth }, async (req) => {
    const user = ctx.userOf(req);
    const { q, teacherId, courseId, before, limit, order } = req.query;
    const opts: Parameters<typeof ctx.timetable.history>[1] = {};
    if (q) opts.q = q;
    if (teacherId) opts.teacherId = teacherId;
    if (courseId) opts.courseId = courseId;
    if (before) opts.before = Number(before);
    if (limit) opts.limit = Number(limit);
    if (order === "asc" || order === "desc") opts.order = order;
    return { lessons: ctx.timetable.history(user.honey_id, opts) };
  });

  app.get("/api/directory", { preHandler: ctx.requireAuth }, async (req) => {
    const user = ctx.userOf(req);
    return ctx.timetable.directory(user.honey_id);
  });

  app.get<{ Params: { teacherId: string } }>(
    "/api/directory/teachers/:teacherId/lesson-count",
    { preHandler: ctx.requireAuth },
    async (req) => {
      const user = ctx.userOf(req);
      return { count: ctx.timetable.lessonCountWithTeacher(user.honey_id, req.params.teacherId) };
    },
  );
}
