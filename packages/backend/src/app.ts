import { existsSync } from "node:fs";
import { join } from "node:path";
import Fastify, { type FastifyInstance } from "fastify";
import fastifyStatic from "@fastify/static";
import { HOneyPortalConnector, PortalApi, PortalHttp } from "@honey/portal-connector";
import type { CredentialVault } from "@honey/portal-connector";
import { loadConfig, type HOneyConfig } from "./config.js";
import { openDatabase } from "./db/database.js";
import { makeAuthHelpers, type AppContext } from "./context.js";
import { AccountService } from "./services/accounts.js";
import { ImportService } from "./services/importer.js";
import { TimetableService } from "./services/timetable.js";
import { registerAuthRoutes } from "./routes/auth.js";
import { registerDataRoutes } from "./routes/data.js";
import { registerExperienceRoutes } from "./routes/experiences.js";
import { registerAdminRoutes } from "./routes/admin.js";
import { EntityRegistry } from "./experiences/entities.js";
import { ExperienceService } from "./experiences/service.js";
import { SettingsService } from "./experiences/settings.js";

// HOney Core backend (Bands 3 & 4). UI-agnostic domain API only — no screen
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
  config?: Partial<HOneyConfig>;
  /** Override the portal base URL (tests point at the mock portal). */
  portalBaseUrl?: string;
  dbPath?: string;
  /** Absolute path to the built web app; when present, served with SPA fallback. */
  webDist?: string;
}

export function buildApp(opts: BuildAppOptions = {}): FastifyInstance & { ctx: AppContext } {
  const config: HOneyConfig = {
    ...loadConfig(),
    ...opts.config,
  };
  if (opts.portalBaseUrl) config.portalBaseUrl = opts.portalBaseUrl;
  if (opts.dbPath) config.dbPath = opts.dbPath;

  const db = openDatabase(config.dbPath);
  const connector = new HOneyPortalConnector({ baseUrl: config.portalBaseUrl, vault: emptyVault });
  const portalApi = new PortalApi(new PortalHttp({ baseUrl: config.portalBaseUrl }));
  const accounts = new AccountService(db, config);
  const entities = new EntityRegistry(db);
  const importer = new ImportService(db, accounts, portalApi, entities);
  const timetable = new TimetableService(db);
  const settings = new SettingsService(db, config.sealKey);
  const experiences = new ExperienceService(db, entities, settings, config.sealKey);

  const ctx: AppContext = {
    db,
    config,
    connector,
    accounts,
    importer,
    timetable,
    entities,
    experiences,
    settings,
    ...makeAuthHelpers(accounts),
  };

  const app = Fastify({ logger: false }) as unknown as FastifyInstance & { ctx: AppContext };
  app.ctx = ctx;

  // Bodyless POST actions (e.g. /api/sync) may arrive with an application/json
  // content-type and an empty body — treat that as {} rather than a 400.
  app.addContentTypeParser("application/json", { parseAs: "string" }, (_req, body, done) => {
    const text = (body as string).trim();
    if (text.length === 0) return done(null, {});
    try {
      done(null, JSON.parse(text));
    } catch (err) {
      done(err as Error, undefined);
    }
  });

  app.get("/api/health", async () => ({ status: "ok", service: "honey-backend" }));
  registerAuthRoutes(app, ctx);
  registerDataRoutes(app, ctx);
  registerExperienceRoutes(app, ctx);
  registerAdminRoutes(app, ctx);

  // Single-origin production deployment: the backend serves the built web app
  // and falls back to index.html for client-side routes (deep links §6.3).
  const webDist = opts.webDist ?? process.env.HONEY_WEB_DIST;
  if (webDist && existsSync(join(webDist, "index.html"))) {
    void app.register(fastifyStatic, {
      root: webDist,
      cacheControl: false, // we set it ourselves below, per file class
      setHeaders(res, path) {
        // Origin intent: the service worker re-checks on every load, hashed
        // assets are immutable by construction, everything else revalidates.
        // (The public edge — hostd gateway / Cloudflare, outside this repo —
        // currently rewrites sw.js to max-age=14400.)
        if (path.endsWith("/sw.js")) res.setHeader("cache-control", "no-cache");
        else if (path.includes("/assets/")) res.setHeader("cache-control", "public, max-age=31536000, immutable");
        else res.setHeader("cache-control", "public, max-age=0, must-revalidate");
      },
    });
    app.setNotFoundHandler((req, reply) => {
      if (req.url.startsWith("/api/")) {
        return reply.code(404).send({ error: "not_found" });
      }
      return reply.sendFile("index.html");
    });
  }

  app.addHook("onClose", async () => {
    db.close();
  });

  return app;
}
