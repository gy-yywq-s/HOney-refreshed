import { scryptSync } from "node:crypto";
import { dirname, join } from "node:path";

export interface HOneyConfig {
  dbPath: string;
  /** 32-byte key for sealing portal tokens at rest (AES-256-GCM). */
  sealKey: Buffer;
  portalBaseUrl: string;
  /** HOney access-token TTL (ms). */
  accessTtlMs: number;
  /** HOney refresh-token TTL (ms). */
  refreshTtlMs: number;
  adminStudentId: string;
  /** The single school this deployment serves (canonical-data scope). */
  schoolId: string;
  schoolName: string;
  /** Where service key files live (issuer private key 0600, public descriptors for peers). */
  keysDir: string;
  /** vault.sqlite — a separate file from the core database by design. */
  vaultDbPath: string;
  production: boolean;
}

export function loadConfig(env: NodeJS.ProcessEnv = process.env): HOneyConfig {
  const secret = env.HONEY_SECRET ?? "";
  if (!secret && env.NODE_ENV === "production") {
    throw new Error("HONEY_SECRET is required in production");
  }
  // On hostd the only path that survives a deploy is $HOSTD_DATA_DIR.
  const defaultDb = env.HOSTD_DATA_DIR ? `${env.HOSTD_DATA_DIR}/honey.db` : "./honey.db";
  const dbPath = env.HONEY_DB_PATH ?? defaultDb;
  const dataDir = dirname(dbPath);
  return {
    dbPath,
    keysDir: env.HONEY_KEYS_DIR ?? join(dataDir, "keys"),
    vaultDbPath: env.HONEY_VAULT_DB_PATH ?? join(dataDir, "vault.db"),
    production: env.NODE_ENV === "production",
    // scrypt turns the deploy secret into a stable 32-byte seal key.
    sealKey: scryptSync(secret || "honey-dev-secret", "honey-seal-v1", 32),
    portalBaseUrl: env.PORTAL_BASE_URL ?? "https://www.huayaopudong.com",
    accessTtlMs: 60 * 60 * 1000,
    refreshTtlMs: 30 * 24 * 60 * 60 * 1000,
    adminStudentId: env.HONEY_ADMIN_STUDENT_ID ?? "0088",
    schoolId: env.HONEY_SCHOOL_ID ?? "huayaopudong",
    schoolName: env.HONEY_SCHOOL_NAME ?? "huayaopudong.com",
  };
}
