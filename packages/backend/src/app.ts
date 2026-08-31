import Fastify, { type FastifyInstance } from "fastify";
import { HoneyPortalConnector, PortalApi, PortalHttp } from "@honey/portal-connector";
import type { CredentialVault } from "@honey/portal-connector";
import { loadConfig, type HoneyConfig } from "./config.js";
import { openDatabase } from "./db/database.js";
import { makeAuthHelpers, type AppContext } from "./context.js";
import { AccountService } from "./services/accounts.js";
import { ImportService } from "./services/importer.js";
import { TimetableService } from "./services/timetable.js";
import { registerAuthRoutes } from "./routes/auth.js";
import { registerDataRoutes } from "./routes/data.js";

// Honey Core backend (Bands 3 & 4). UI-agnostic domain API only — no screen
// shapes here (spec §14). The server-side connector never holds a school
// password: it acts on per-login transients or sealed short-lived tokens.

/** Server-side vault: no credentials, no persisted coordinator session (login-per-request model). */
const emptyVault: CredentialVault = {
  loadSession: async () => null,
  saveSession: async () => undefined,
  deleteSession: async () => undefined,
  loadAuthorizedCredentialsSilently: async () => null,
  deleteCredentials: async () => undefined,
};

export interface BuildAppOptions {
  config?: Partial<HoneyConfig>;
  /** Override the portal base URL (tests point at the mock portal). */
  portalBaseUrl?: string;
  dbPath?: string;
}

export function buildApp(opts: BuildAppOptions = {}): FastifyInstance & { ctx: AppContext } {
  const config: HoneyConfig = {
    ...loadConfig(),
    ...opts.config,
  };
  if (opts.portalBaseUrl) config.portalBaseUrl = opts.portalBaseUrl;
  if (opts.dbPath) config.dbPath = opts.dbPath;

  const db = openDatabase(config.dbPath);
  const connector = new HoneyPortalConnector({ baseUrl: config.portalBaseUrl, vault: emptyVault });
  const portalApi = new PortalApi(new PortalHttp({ baseUrl: config.portalBaseUrl }));
  const accounts = new AccountService(db, config);
  const importer = new ImportService(db, accounts, portalApi);
  const timetable = new TimetableService(db);

  const ctx: AppContext = {
    db,
    config,
    connector,
    accounts,
    importer,
    timetable,
    ...makeAuthHelpers(accounts),
  };

  const app = Fastify({ logger: false }) as unknown as FastifyInstance & { ctx: AppContext };
  app.ctx = ctx;

  app.get("/api/health", async () => ({ status: "ok", service: "honey-backend" }));
  registerAuthRoutes(app, ctx);
  registerDataRoutes(app, ctx);

  app.addHook("onClose", async () => {
    db.close();
  });

  return app;
}
