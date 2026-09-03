import type { FastifyInstance } from "fastify";
import { createHmac } from "node:crypto";
import type { AccessSessionResponse } from "@honey/shared/access";
import type { AppContext } from "../context.js";

// Web Access session (spec §17): the signed-in student asks Core for a
// short-lived capability. Core opens its own sealed copy of the portal
// token, seals it to the Access Service and signs the envelope. The
// browser only carries it; the subject is a keyed pseudonym of the account
// that the Access Service cannot reverse and Core does not store.

export function registerAccessRoutes(app: FastifyInstance, ctx: AppContext): void {
  app.post("/api/access/session", { preHandler: ctx.requireAuth }, async (req, reply): Promise<AccessSessionResponse> => {
    const user = ctx.userOf(req);
    // Every "not now" answer is a 200 with ok:false: a 401 here would read as
    // a lost HOney session to the web client, and it is not one.
    if (!ctx.accessSigner) return reply.send({ ok: false, error: "access_unavailable" });
    const connection = ctx.accounts.getConnection(user.honey_id);
    if (!connection.connected) return reply.send({ ok: false, error: "no_school_connection" });
    const portal = ctx.accounts.loadPortalToken(user.honey_id);
    if (!portal) return reply.send({ ok: false, error: "portal_reconnect_required" });
    const subject = createHmac("sha256", ctx.config.sealKey).update("honey/access/subject\n" + user.honey_id).digest("base64url").slice(0, 32);
    const issued = await ctx.accessSigner.issue({
      subject,
      schoolId: ctx.config.schoolId,
      session: { token: portal.token, tokenExpiresAt: portal.expiresAt.getTime(), portalStudentId: portal.studentId, schoolId: ctx.config.schoolId },
      now: Date.now(),
    });
    if (!issued) return reply.send({ ok: false, error: "access_unavailable" });
    return { ok: true, capability: issued.capability, expiresAt: issued.expiresAt };
  });
}
