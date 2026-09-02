import type { FastifyReply, FastifyRequest } from "fastify";
import type { DatabaseSync } from "node:sqlite";
import type { HOneyPortalConnector } from "@honey/portal-connector";
import type { HOneyConfig } from "./config.js";
import type { AccountService, HOneyUserRow } from "./services/accounts.js";
import type { ImportService } from "./services/importer.js";
import type { TimetableService } from "./services/timetable.js";
import type { EntityDirectory } from "./school/directory.js";
import type { SchoolProfile } from "./school/types.js";
import type { ExperienceService } from "./experiences/service.js";
import type { SettingsService } from "./experiences/settings.js";
import type { EligibilityIssuer } from "./community-issuer/issuer.js";
import type { IssuanceLimits } from "./community-issuer/issuance-limits.js";
import type { ControlVaultStore } from "./control-vault/vault-records.js";

// Assembled per-app dependency context. Routes receive this instead of
// importing singletons, so tests wire mock portals in freely.

export interface AppContext {
  db: DatabaseSync;
  config: HOneyConfig;
  connector: HOneyPortalConnector;
  accounts: AccountService;
  importer: ImportService;
  timetable: TimetableService;
  /** The school profile: curated, deterministic canonicalization knowledge. */
  profile: SchoolProfile;
  entities: EntityDirectory;
  experiences: ExperienceService;
  settings: SettingsService;
  /** Blind eligibility issuer (Anonymous Control v2); null until a key exists. */
  issuer: EligibilityIssuer | null;
  /** Resolves once the issuer key file has been read (keys load asynchronously). */
  issuerReady: Promise<void>;
  limits: IssuanceLimits;
  vault: ControlVaultStore;
  requireAuth: (req: FastifyRequest, reply: FastifyReply) => Promise<void>;
  bearerToken: (req: FastifyRequest) => string;
  userOf: (req: FastifyRequest) => HOneyUserRow;
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
      (req as unknown as Record<symbol, HOneyUserRow>)[USER_KEY] = user;
    },
    userOf(req) {
      const user = (req as unknown as Record<symbol, HOneyUserRow | undefined>)[USER_KEY];
      if (!user) throw new Error("userOf called on unauthenticated request");
      return user;
    },
  };
}
