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
      lessons: ids("SELECT lesson_instance_id AS id FROM user_lesson_exposures WHERE honey_id = ?").map((id) => ctx.experiences.lessonToken(id)),
    };
  });

  /**
   * Blind issuance. The account proves standing for ONE scope; the issuer
   * signs the blinded message with that scope + canonical context as public
   * metadata. It never sees the token it signs.
   */
  app.post<{ Body: EligibilityRequest & { schoolMember?: boolean } }>(
    "/api/community/eligibility",
    { preHandler: ctx.requireAuth },
    async (req, reply): Promise<EligibilityIssued | { error: string }> => {
      await ctx.issuerReady;
      if (!ctx.issuer) return reply.code(503).send({ error: "issuer_unavailable" });
      const user = ctx.userOf(req);
      const { lessonId, entityKey, blindedMessage, schoolMember } = req.body ?? {};
      if (typeof blindedMessage !== "string" || !B64URL.test(blindedMessage) || blindedMessage.length < 300 || blindedMessage.length > 400) {
        return reply.code(400).send({ error: "blinded_message_invalid" });
      }
      const gated = ctx.experiences.gate(user.honey_id);
      if (gated) return reply.code(422).send({ error: gated });

      const now = Date.now();
      let info: EligibilityInfo;
      if (schoolMember) {
        // Membership only (reactions/reports): the scope is the school.
        if (!ctx.limits.take(user.honey_id, "school-member", ISSUANCE_MEMBER_PER_DAY)) {
          return reply.code(429).send({ error: "issuance_rate_limited" });
        }
        info = {
          v: 2,
          schoolId: ctx.profile.id,
          academicYear: ctx.profile.academicYearFor(now),
          scope: `school-member:${ctx.profile.id}`,
          contexts: {},
          provenance: "verified_member",
          week: portalWeekIndex(new Date(now)),
        };
      } else {
        const resolved = ctx.experiences.resolveTarget(user.honey_id, lessonId, entityKey);
        if (!resolved.ok) return reply.code(422).send({ error: resolved.error });
        const t = resolved.target;
        if (!ctx.limits.take(user.honey_id, t.entityKey, ISSUANCE_PER_SCOPE_PER_DAY)) {
          return reply.code(429).send({ error: "issuance_rate_limited" });
        }
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
        info = {
          v: 2,
          schoolId: ctx.profile.id,
          academicYear,
          scope: t.entityKey,
          contexts,
          provenance: t.provenance as EligibilityInfo["provenance"],
          week: portalWeekIndex(new Date(now)),
        };
      }
      try {
        const blindSignature = await ctx.issuer.sign(blindedMessage, info);
        return { ok: true, keyId: ctx.issuer.descriptor.keyId, info, blindSignature };
      } catch (e) {
        if (e instanceof Error && e.message === "blinded_message_invalid") return reply.code(400).send({ error: "blinded_message_invalid" });
        throw e;
      }
    },
  );
}
