import type { FastifyInstance } from "fastify";
import type { AppContext } from "../context.js";
import type {
  SyncResponse,
  PortalEntryResponse,
  TimetableResponse,
  TimetableRangeResponse,
  NextLessonResponse,
  HistoryResponse,
  DirectoryResponse,
} from "@honey/shared/api";

// Data surface (spec §14.3): UI-agnostic domain queries. Screens compose these;
// none of them encodes a screen.

export function registerDataRoutes(app: FastifyInstance, ctx: AppContext): void {
  app.post("/api/sync", { preHandler: ctx.requireAuth }, async (req): Promise<SyncResponse> => {
    const user = ctx.userOf(req);
    const result = await ctx.importer.syncTimetable(user.honey_id);
    return result;
  });

  // The school portal's web app signs in from a token in its login URL (the
  // path its WeChat mini-program uses); HOney hands the student over with
  // the token it already holds, so "School Portal" opens signed in (Gary,
  // 2026-09-02 — staying signed in must not be the student's configuration).
  // Tokens live about a day: a small margin keeps a nearly-dead one from
  // landing the student on the login page anyway.
  app.get("/api/portal/entry", { preHandler: ctx.requireAuth }, async (req, reply): Promise<PortalEntryResponse> => {
    const user = ctx.userOf(req);
    void reply.header("cache-control", "no-store");
    const session = ctx.accounts.loadPortalToken(user.honey_id);
    if (!session || session.expiresAt.getTime() - Date.now() < 5 * 60_000) {
      return { status: "portal_reconnect_required" };
    }
    // The clock is not the truth: the school invalidates a token when the
    // student signs in elsewhere (the official site, the app), and a dead
    // token would land them on the portal's login page (Gary 2026-09-02).
    // One cheap identity call tells; a portal outage keeps the token.
    try {
      await ctx.connector.api.userInfo(session.token);
    } catch (e) {
      const kind = e instanceof Error && "info" in e ? (e as { info: { kind: string } }).info.kind : "";
      if (kind === "sessionExpired" || kind === "credentialsRejected") {
        ctx.accounts.markPortalExpired(user.honey_id);
        return { status: "portal_reconnect_required" };
      }
    }
    const url = `${ctx.config.portalBaseUrl}/student/login?token=${encodeURIComponent(session.token)}`;
    return { status: "ok", url, expiresAt: session.expiresAt.getTime() };
  });

  app.get<{ Querystring: { date?: string } }>(
    "/api/timetable",
    { preHandler: ctx.requireAuth },
    async (req, reply): Promise<TimetableResponse> => {
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

  // The Week overview (addendum v1.1 §18.1): one request for up to 8 days.
  app.get<{ Querystring: { from?: string; to?: string } }>(
    "/api/timetable/range",
    { preHandler: ctx.requireAuth },
    async (req, reply): Promise<TimetableRangeResponse> => {
      const user = ctx.userOf(req);
      const from = req.query.from ? new Date(`${req.query.from}T00:00:00`) : null;
      const to = req.query.to ? new Date(`${req.query.to}T00:00:00`) : null;
      if (!from || !to || Number.isNaN(from.getTime()) || Number.isNaN(to.getTime()) || to < from)
        return reply.code(400).send({ error: "bad range" });
      const days: TimetableRangeResponse["days"] = [];
      const cursor = new Date(from);
      cursor.setHours(0, 0, 0, 0);
      for (let i = 0; i < 8 && cursor <= to; i++) {
        const dayStart = new Date(cursor);
        const dayEnd = new Date(cursor);
        dayEnd.setDate(dayEnd.getDate() + 1);
        days.push({
          date: `${dayStart.getFullYear()}-${String(dayStart.getMonth() + 1).padStart(2, "0")}-${String(dayStart.getDate()).padStart(2, "0")}`,
          lessons: ctx.timetable.lessonsForDay(user.honey_id, dayStart.getTime(), dayEnd.getTime()),
        });
        cursor.setDate(cursor.getDate() + 1);
      }
      const connection = ctx.accounts.getConnection(user.honey_id);
      return {
        from: days[0]?.date ?? req.query.from!,
        to: days[days.length - 1]?.date ?? req.query.to!,
        days,
        lastSyncedAt: connection.lastSyncedAt?.toISOString() ?? null,
      };
    },
  );

  app.get("/api/next-lesson", { preHandler: ctx.requireAuth }, async (req): Promise<NextLessonResponse> => {
    const user = ctx.userOf(req);
    const connection = ctx.accounts.getConnection(user.honey_id);
    return {
      nextLesson: ctx.timetable.nextLesson(user.honey_id),
      lastSyncedAt: connection.lastSyncedAt?.toISOString() ?? null,
    };
  });

  app.get<{
    Querystring: { q?: string; teacherId?: string; courseId?: string; before?: string; limit?: string; order?: string };
  }>("/api/history", { preHandler: ctx.requireAuth }, async (req): Promise<HistoryResponse> => {
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

  app.get("/api/directory", { preHandler: ctx.requireAuth }, async (req): Promise<DirectoryResponse> => {
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
