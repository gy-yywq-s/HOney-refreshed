import { execSync } from "node:child_process";
import { dirname, join } from "node:path";

// The Access Service (spec §16.1): its own process, port and SQLite file; the
// typed portal connector; no Core/Community/Vault database, no school
// password, no generic proxy. It knows Core's signing public key (a file Core
// writes in the shared keys directory) and writes its own HPKE public key
// there for Core to seal portal sessions to.

export interface AccessConfig {
  dbPath: string;
  keysDir: string;
  portalBaseUrl: string;
  internalSecret: string;
  serviceVersion: string;
  production: boolean;
  /** Only this origin may ever be contacted (app-layer egress policy). */
  allowedEgressOrigins: string[];
}

function serviceVersion(): string {
  if (process.env.HONEY_SERVICE_VERSION) return process.env.HONEY_SERVICE_VERSION;
  try {
    return execSync("git rev-parse --short HEAD", { stdio: ["ignore", "pipe", "ignore"] }).toString().trim();
  } catch {
    return "dev";
  }
}

export function loadAccessConfig(env: NodeJS.ProcessEnv = process.env): AccessConfig {
  const production = env.NODE_ENV === "production";
  if (production && !env.HONEY_INTERNAL_SECRET) throw new Error("HONEY_INTERNAL_SECRET is required in production");
  const dbPath = env.HONEY_ACCESS_DB_PATH ?? "./access.db";
  const portalBaseUrl = (env.PORTAL_BASE_URL ?? "https://www.huayaopudong.com").replace(/\/$/, "");
  return {
    dbPath,
    keysDir: env.HONEY_KEYS_DIR ?? join(dirname(dbPath), "keys"),
    portalBaseUrl,
    internalSecret: env.HONEY_INTERNAL_SECRET ?? "dev-internal-secret",
    serviceVersion: serviceVersion(),
    production,
    allowedEgressOrigins: [new URL(portalBaseUrl).origin],
  };
}
