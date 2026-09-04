import { scryptSync } from "node:crypto";
import { dirname, join } from "node:path";

// HOney Community — its own process, its own database, no account lookup.
// It knows the issuer's PUBLIC key (a file Core writes beside its keys), an
// internal secret for the Dash proxy, and its own sealing secret. It never
// receives HONEY_SECRET, the core database path or the school portal.

export interface CommunityConfig {
  dbPath: string;
  /** Path of the issuer public descriptor written by Core (`issuer.public.json`). */
  issuerPublicPath: string;
  /** Shared with Core for /internal/admin/* only (loopback + secret). */
  internalSecret: string;
  /** Community's own key for content passes, cursors and the sealed LLM key. */
  sealKey: Buffer;
  schoolId: string;
  production: boolean;
  /** Fallback moderation key from the environment; Dash can seal one into settings. */
  openRouterApiKey: string;
}

export function loadCommunityConfig(env: NodeJS.ProcessEnv = process.env): CommunityConfig {
  const secret = env.HONEY_COMMUNITY_SECRET ?? "";
  const production = env.NODE_ENV === "production";
  if (production && !secret) throw new Error("HONEY_COMMUNITY_SECRET is required in production");
  if (production && !env.HONEY_INTERNAL_SECRET) throw new Error("HONEY_INTERNAL_SECRET is required in production");
  const dbPath = env.HONEY_COMMUNITY_DB_PATH ?? "./community.db";
  return {
    dbPath,
    issuerPublicPath: env.HONEY_ISSUER_PUBLIC_PATH ?? join(env.HONEY_KEYS_DIR ?? join(dirname(dbPath), "keys"), "issuer.public.json"),
    internalSecret: env.HONEY_INTERNAL_SECRET ?? "dev-internal-secret",
    sealKey: scryptSync(secret || "honey-community-dev-secret", "honey-community-v2", 32),
    schoolId: env.HONEY_SCHOOL_ID ?? "huayaopudong",
    production,
    openRouterApiKey: env.OPENROUTER_API_KEY ?? "",
  };
}
