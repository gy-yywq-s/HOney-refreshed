import type { FastifyInstance } from "fastify";
import { isPortalError } from "@honey/portal-connector";
import type { Me, LoginResponse } from "@honey/shared/api";
import type { AppContext } from "../context.js";

// Auth surface (spec §3): school login IS signup. The password transits this
// process exactly once per login call — it is never persisted, never logged,
// and never included in any error path.

interface LoginBody {
  username?: string;
  password?: string;
}

export function registerAuthRoutes(app: FastifyInstance, ctx: AppContext): void {
  app.post<{ Body: LoginBody }>("/api/auth/login", async (req, reply) => {
    const { username, password } = req.body ?? {};
    if (!username || !password) {
      return reply.code(400).send({ error: "username and password are required" });
    }
    try {
      const portalSession = await ctx.connector.login({ username, password });
      const identity = await ctx.connector.validate(portalSession);
      const result = ctx.accounts.provisionFromPortal(identity, portalSession);

      // The login payload never touches the consent row (consent-looking
      // fields are ignored); import is part of the account since 2026-09-01.
      const consent = ctx.accounts.getConsent(result.user.honey_id);
      if (result.created) {
        // First sign-in = first import, in the background. Later sign-ins
        // never import; Sync now / pull-to-refresh are the manual paths.
        void ctx.importer.syncTimetable(result.user.honey_id).catch(() => undefined);
      }
      return reply.send({
        honeyId: result.user.honey_id,
        displayName: result.user.display_name,
        created: result.created,
        isAdmin: ctx.accounts.isAdmin(result.user.honey_id),
        consent,
        session: {
          accessToken: result.session.accessToken,
          accessExpiresAt: result.session.accessExpiresAt.toISOString(),
          refreshToken: result.session.refreshToken,
          refreshExpiresAt: result.session.refreshExpiresAt.toISOString(),
        },
      });
    } catch (e) {
      if (isPortalError(e)) {
        switch (e.kind) {
          case "credentialsRejected":
            return reply.code(401).send({ error: "school_credentials_rejected" });
          case "userActionRequired":
            return reply.code(409).send({ error: "portal_interactive_challenge" });
          case "schemaIncompatible":
            return reply.code(502).send({ error: "portal_incompatible" });
          default:
            return reply.code(503).send({ error: "portal_unavailable" });
        }
      }
      throw e;
    }
  });

  app.post<{ Body: { refreshToken?: string } }>("/api/auth/refresh", async (req, reply) => {
    const token = req.body?.refreshToken;
    if (!token) return reply.code(400).send({ error: "refreshToken required" });
    const session = ctx.accounts.refresh(token);
    if (!session) return reply.code(401).send({ error: "invalid_refresh_token" });
    return reply.send({
      accessToken: session.accessToken,
      accessExpiresAt: session.accessExpiresAt.toISOString(),
      refreshToken: session.refreshToken,
      refreshExpiresAt: session.refreshExpiresAt.toISOString(),
    });
  });

  app.post("/api/auth/logout", { preHandler: ctx.requireAuth }, async (req, reply) => {
    ctx.accounts.signOut(ctx.bearerToken(req));
    return reply.send({ ok: true });
  });

  app.get("/api/me", { preHandler: ctx.requireAuth }, async (req): Promise<Me> => {
    const user = ctx.userOf(req);
    const consent = ctx.accounts.getConsent(user.honey_id);
    const connection = ctx.accounts.getConnection(user.honey_id);
    // Emit the wire shape explicitly (ISO strings) rather than relying on
    // Fastify's implicit Date serialization — the contract types the wire.
    return {
      honeyId: user.honey_id,
      displayName: user.display_name,
      isAdmin: ctx.accounts.isAdmin(user.honey_id),
      consent: { timetable: consent.timetable, grantedAt: consent.grantedAt?.toISOString() ?? null },
      connection: {
        connected: connection.connected,
        lastSyncedAt: connection.lastSyncedAt?.toISOString() ?? null,
        portalTokenValid: connection.portalTokenValid,
      },
    };
  });

  /**
   * Client-obtained portal token hand-off (iOS path): the app logs into the
   * portal itself (Keychain creds) and pushes only the token here for sync.
   * The backend validates it against the portal before accepting.
   */
  app.post<{ Body: { token?: string } }>(
    "/api/portal/token",
    { preHandler: ctx.requireAuth },
    async (req, reply) => {
      const user = ctx.userOf(req);
      const token = req.body?.token;
      if (!token) return reply.code(400).send({ error: "token required" });
      try {
        const identity = await ctx.connector.validate({
          token,
          expiresAt: new Date(Date.now() + 60_000),
          studentId: "unknown",
        });
        ctx.accounts.storePortalToken(user.honey_id, identity.studentId, {
          token,
          expiresAt: identity.tokenExpiresAt,
          studentId: identity.studentId,
        });
        return reply.send({ ok: true, tokenExpiresAt: identity.tokenExpiresAt.toISOString() });
      } catch (e) {
        if (isPortalError(e) && e.kind === "sessionExpired") {
          return reply.code(401).send({ error: "portal_token_invalid" });
        }
        if (isPortalError(e)) return reply.code(503).send({ error: "portal_unavailable" });
        throw e;
      }
    },
  );

  app.post<{ Body: { timetable?: boolean } }>(
    "/api/consent",
    { preHandler: ctx.requireAuth },
    async (req, reply) => {
      const user = ctx.userOf(req);
      const timetable = req.body?.timetable;
      if (typeof timetable !== "boolean") {
        return reply.code(400).send({ error: "timetable boolean required" });
      }
      ctx.accounts.setConsent(user.honey_id, timetable);
      return reply.send({ ok: true, consent: ctx.accounts.getConsent(user.honey_id) });
    },
  );

  app.post("/api/school/disconnect", { preHandler: ctx.requireAuth }, async (req) => {
    const user = ctx.userOf(req);
    ctx.accounts.disconnectSchool(user.honey_id);
    return { ok: true };
  });

  app.delete("/api/imported-data", { preHandler: ctx.requireAuth }, async (req) => {
    const user = ctx.userOf(req);
    ctx.accounts.deleteImportedData(user.honey_id);
    return { ok: true };
  });

  app.delete("/api/account", { preHandler: ctx.requireAuth }, async (req) => {
    const user = ctx.userOf(req);
    ctx.accounts.deleteAccount(user.honey_id);
    return { ok: true };
  });
}
