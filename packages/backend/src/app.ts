import { existsSync } from "node:fs";
import { dirname, join } from "node:path";
import Fastify, { type FastifyInstance } from "fastify";
import fastifyStatic from "@fastify/static";
import { HOneyPortalConnector, PortalApi, PortalHttp } from "@honey/portal-connector";
import type { CredentialVault } from "@honey/portal-connector";
import { loadConfig, type HOneyConfig } from "./config.js";
import { ensureSchool, openDatabase } from "./db/database.js";
import { makeAuthHelpers, type AppContext } from "./context.js";
import { AccountService } from "./services/accounts.js";
import { ImportService } from "./services/importer.js";
import { TimetableService } from "./services/timetable.js";
import { registerAuthRoutes } from "./routes/auth.js";
import { registerDataRoutes } from "./routes/data.js";
import { registerEntityRoutes } from "./routes/entities.js";
import { registerAdminRoutes } from "./routes/admin.js";
import { registerCommunityRoutes } from "./routes/community.js";
import { registerVaultRoutes } from "./routes/vault.js";
import { EntityDirectory } from "./school/directory.js";
import { profileFor } from "./school/profiles/huayaopudong.js";
import { SettingsService } from "./experiences/settings.js";
import { EligibilityIssuer, type IssuerKeyFile } from "./community-issuer/issuer.js";
import { EligibilityService } from "./community-issuer/eligibility.js";
import { IssuanceLimits } from "./community-issuer/issuance-limits.js";
import { CommunityAdminClient } from "./community-issuer/community-admin.js";
import { openVaultDatabase } from "./control-vault/vault-db.js";
import { ControlVaultStore } from "./control-vault/vault-records.js";
import { deriveKey } from "./crypto.js";

// HOney Core (Bands 3 & 4): accounts, canonical school data, the blind
// eligibility issuer and the Control Vault. UI-agnostic domain API only — no
// screen shapes here (spec §14). The server-side connector never holds a
// school password. Posts live in the Community process; Core has no handle
// to them by construction.

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
  /** Issuer key for tests (the checked-in test key); production loads from the keys directory. */
  issuerKey?: IssuerKeyFile;
  /** vault.sqlite path for tests (defaults to config.vaultDbPath). */
  vaultDbPath?: string;
  /** Community admin transport for tests. */
  communityFetch?: typeof fetch;
}

export function buildApp(opts: BuildAppOptions = {}): FastifyInstance & { ctx: AppContext } {
  const config: HOneyConfig = {
    ...loadConfig(),
    ...opts.config,
  };
  if (opts.portalBaseUrl) config.portalBaseUrl = opts.portalBaseUrl;
  if (opts.dbPath) {
    // The vault file and key directory follow the core database unless set explicitly.
    config.dbPath = opts.dbPath;
    config.vaultDbPath = opts.vaultDbPath ?? join(dirname(opts.dbPath), "vault.db");
    config.keysDir = opts.config?.keysDir ?? join(dirname(opts.dbPath), "keys");
  }

  const db = openDatabase(config.dbPath);
  const profile = profileFor(config.schoolId);
  ensureSchool(db, profile.id, config.schoolName);
  const connector = new HOneyPortalConnector({ baseUrl: config.portalBaseUrl, vault: emptyVault });
  const portalApi = new PortalApi(new PortalHttp({ baseUrl: config.portalBaseUrl }));
  const accounts = new AccountService(db, config);
  const entities = new EntityDirectory(db, profile);
  const importer = new ImportService(db, accounts, portalApi, profile);
  const timetable = new TimetableService(db);
  const settings = new SettingsService(db);
  const eligibility = new EligibilityService(db, entities, settings, config.sealKey);
  const limits = new IssuanceLimits(db, deriveKey(config.sealKey, "issuance-mark"));
  const vaultDb = openVaultDatabase(opts.vaultDbPath ?? config.vaultDbPath);
  const vault = new ControlVaultStore(vaultDb, deriveKey(config.sealKey, "vault-locator"));
  const communityAdmin = new CommunityAdminClient(config.communityInternalUrl, config.internalSecret, opts.communityFetch ?? fetch);

  const ctx: AppContext = {
    db,
    config,
    connector,
    accounts,
    importer,
    timetable,
    profile,
    entities,
    settings,
    eligibility,
    issuer: null,
    issuerReady: Promise.resolve(),
    limits,
    vault,
    communityAdmin,
    ...makeAuthHelpers(accounts),
  };
  // The issuer key is read asynchronously (WebCrypto import); routes await it.
  ctx.issuerReady = (opts.issuerKey
    ? EligibilityIssuer.fromKeyFile(opts.issuerKey, { production: config.production })
    : EligibilityIssuer.load(config.keysDir, { production: config.production })
  )
    .then((issuer) => {
      ctx.issuer = issuer;
    })
    .catch((err: unknown) => {
      // A broken key file must not take the whole service down: eligibility
      // reports issuer_unavailable and the rest of HOney keeps working.
      // eslint-disable-next-line no-console
      console.error("issuer key unavailable:", err instanceof Error ? err.message : err);
    });

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
  registerEntityRoutes(app, ctx);
  registerAdminRoutes(app, ctx);
  registerCommunityRoutes(app, ctx);
  registerVaultRoutes(app, ctx);

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
        if (path.endsWith("/sw.js") || path.endsWith("/version.json")) res.setHeader("cache-control", "no-cache");
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
    vaultDb.close();
  });

  return app;
}
