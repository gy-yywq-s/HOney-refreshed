import type { FastifyInstance } from "fastify";
import { portalWeekIndex } from "@honey/shared";
import type { CommunityScope, EligibilityInfo, EligibilityIssued, EligibilityRequest, IssuerDescriptor } from "@honey/shared/community-v2";
import type { AppContext } from "../context.js";
import { ISSUANCE_MEMBER_PER_DAY, ISSUANCE_PER_SCOPE_PER_DAY } from "../community-issuer/issuance-limits.js";

// Core's side of Anonymous Control v2 (spec §31): the issuer verifies
// standing and blind-signs; the public descriptor lets Community verify
// offline; the scope call tells a client its own canonical exposure so it
// can ask Community for "Your classes" without Community knowing who asks.
// No route here returns a post, an authorTag or a Community id.

const B64URL = /^[A-Za-z0-9_-]+$/;

export function registerCommunityRoutes(app: FastifyInstance, ctx: AppContext): void {
  app.get("/api/community/issuer", async (_req, reply): Promise<IssuerDescriptor | { error: string }> => {
    await ctx.issuerReady;
    if (!ctx.issuer) return reply.code(503).send({ error: "issuer_unavailable" });
    void reply.header("cache-control", "public, max-age=300");
    return ctx.issuer.descriptor;
  });

  app.get("/api/community/scope", { preHandler: ctx.requireAuth }, async (req): Promise<CommunityScope> => {
    const user = ctx.userOf(req);
    const ids = (sql: string) => (ctx.db.prepare(sql).all(user.honey_id) as { id: string }[]).map((r) => r.id);
    return {
      schoolId: ctx.profile.id,
      academicYear: ctx.profile.academicYearFor(Date.now()),
      teachers: ids("SELECT DISTINCT teacher_id AS id FROM user_lesson_exposures WHERE honey_id = ? AND teacher_id IS NOT NULL"),
      courses: ids("SELECT DISTINCT course_id AS id FROM user_lesson_exposures WHERE honey_id = ? AND course_id IS NOT NULL"),
      lessons: ids("SELECT lesson_instance_id AS id FROM user_lesson_exposures WHERE honey_id = ?").map((id) => ctx.eligibility.lessonToken(id)),
    };
  });

  /** The public metadata the issuer would sign for a target — standing checks, no signature, no count. */
  function describe(honeyId: string, body: { lessonId?: string; entityKey?: string; schoolMember?: boolean }): { ok: true; info: EligibilityInfo; limitScope: string; limit: number } | { ok: false; error: string; status: number } {
    const gated = ctx.eligibility.gate();
    if (gated) return { ok: false, error: gated, status: 422 };
    const now = Date.now();
    const week = portalWeekIndex(new Date(now));
    if (body.schoolMember) {
      // Membership only (reactions/reports): the scope is the school.
      return {
        ok: true,
        limitScope: "school-member",
        limit: ISSUANCE_MEMBER_PER_DAY,
        info: { v: 2, schoolId: ctx.profile.id, academicYear: ctx.profile.academicYearFor(now), scope: `school-member:${ctx.profile.id}`, contexts: {}, provenance: "verified_member", week },
      };
    }
    const resolved = ctx.eligibility.resolveTarget(honeyId, body.lessonId, body.entityKey);
    if (!resolved.ok) return { ok: false, error: resolved.error, status: 422 };
    const t = resolved.target;
    // The academic year of a lesson is its section's; standalone targets use today's.
    let academicYear = ctx.profile.academicYearFor(now);
    if (t.lessonInstanceId) {
      const row = ctx.db
        .prepare(
          `SELECT cs.academic_year AS year, li.starts_at AS startsAt FROM lesson_instances li
           LEFT JOIN class_sections cs ON cs.id = li.class_section_id WHERE li.id = ?`,
        )
        .get(t.lessonInstanceId) as { year: string | null; startsAt: number } | undefined;
      academicYear = row?.year ?? ctx.profile.academicYearFor(row?.startsAt ?? now);
    }
    const contexts: EligibilityInfo["contexts"] = {};
    if (t.entityType === "lesson") contexts.lessonId = t.entityKey.slice("lesson:".length);
    if (t.ctx.course) contexts.courseId = t.ctx.course;
    if (t.ctx.teacher) contexts.teacherId = t.ctx.teacher;
    if (t.ctx.room) contexts.roomId = t.ctx.room;
    return {
      ok: true,
      limitScope: t.entityKey,
      limit: ISSUANCE_PER_SCOPE_PER_DAY,
      info: { v: 2, schoolId: ctx.profile.id, academicYear, scope: t.entityKey, contexts, provenance: t.provenance, week },
    };
  }

  /**
   * Step 1 of issuance: the metadata the issuer would bind (so the client can
   * blind under exactly that). Standing is checked; nothing is signed or counted.
   */
  app.post<{ Body: { lessonId?: string; entityKey?: string; schoolMember?: boolean } }>(
    "/api/community/eligibility/info",
    { preHandler: ctx.requireAuth },
    async (req, reply): Promise<{ ok: true; info: EligibilityInfo } | { error: string }> => {
      await ctx.issuerReady;
      if (!ctx.issuer) return reply.code(503).send({ error: "issuer_unavailable" });
      const d = describe(ctx.userOf(req).honey_id, req.body ?? {});
      if (!d.ok) return reply.code(d.status).send({ error: d.error });
      return { ok: true, info: d.info };
    },
  );

  /**
   * Step 2: blind issuance. The account proves standing for ONE scope; the
   * issuer signs the blinded message with that scope + canonical context as
   * public metadata. It never sees the token it signs. Counted per day.
   */
  app.post<{ Body: EligibilityRequest & { schoolMember?: boolean } }>(
    "/api/community/eligibility",
    { preHandler: ctx.requireAuth },
    async (req, reply): Promise<EligibilityIssued | { error: string }> => {
      await ctx.issuerReady;
      if (!ctx.issuer) return reply.code(503).send({ error: "issuer_unavailable" });
      const user = ctx.userOf(req);
      const { blindedMessage } = req.body ?? {};
      if (typeof blindedMessage !== "string" || !B64URL.test(blindedMessage) || blindedMessage.length < 300 || blindedMessage.length > 400) {
        return reply.code(400).send({ error: "blinded_message_invalid" });
      }
      const d = describe(user.honey_id, req.body ?? {});
      if (!d.ok) return reply.code(d.status).send({ error: d.error });
      if (!ctx.limits.take(user.honey_id, d.limitScope, d.limit)) return reply.code(429).send({ error: "issuance_rate_limited" });
      try {
        const blindSignature = await ctx.issuer.sign(blindedMessage, d.info);
        return { ok: true, keyId: ctx.issuer.descriptor.keyId, info: d.info, blindSignature };
      } catch (e) {
        if (e instanceof Error && e.message === "blinded_message_invalid") return reply.code(400).send({ error: "blinded_message_invalid" });
        throw e;
      }
    },
  );
}
