import type { FastifyReply, FastifyRequest } from "fastify";
import type { DatabaseSync } from "node:sqlite";
import type { HoneyPortalConnector } from "@honey/portal-connector";
import type { HoneyConfig } from "./config.js";
import type { AccountService, HoneyUserRow } from "./services/accounts.js";
import type { ImportService } from "./services/importer.js";
import type { TimetableService } from "./services/timetable.js";
import type { EntityRegistry } from "./experiences/entities.js";
import type { ExperienceService } from "./experiences/service.js";
import type { SettingsService } from "./experiences/settings.js";

// Assembled per-app dependency context. Routes receive this instead of
// importing singletons, so tests wire mock portals in freely.

export interface AppContext {
  db: DatabaseSync;
  config: HoneyConfig;
  connector: HoneyPortalConnector;
  accounts: AccountService;
  importer: ImportService;
  timetable: TimetableService;
  entities: EntityRegistry;
  experiences: ExperienceService;
  settings: SettingsService;
  requireAuth: (req: FastifyRequest, reply: FastifyReply) => Promise<void>;
  bearerToken: (req: FastifyRequest) => string;
  userOf: (req: FastifyRequest) => HoneyUserRow;
}

const USER_KEY = Symbol("honeyUser");

export function bearerToken(req: FastifyRequest): string {
  const h = req.headers.authorization ?? "";
  return h.startsWith("Bearer ") ? h.slice(7) : "";
}

export function makeAuthHelpers(accounts: AccountService): Pick<AppContext, "requireAuth" | "bearerToken" | "userOf"> {
  return {
    bearerToken,
    async requireAuth(req, reply) {
      const token = bearerToken(req);
      const user = token ? accounts.authenticate(token) : null;
      if (!user) {
        await reply.code(401).send({ error: "unauthorized" });
        return;
      }
      (req as unknown as Record<symbol, HoneyUserRow>)[USER_KEY] = user;
    },
    userOf(req) {
      const user = (req as unknown as Record<symbol, HoneyUserRow | undefined>)[USER_KEY];
      if (!user) throw new Error("userOf called on unauthenticated request");
      return user;
    },
  };
}
