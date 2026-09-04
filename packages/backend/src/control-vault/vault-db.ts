import { createRequire } from "node:module";
import type { DatabaseSync as DatabaseSyncType } from "node:sqlite";

// vault.sqlite — a separate file from core.sqlite by design (spec §29): Core
// can locate an account's ciphertext, never read it, and nothing in here
// names a Community post.

const { DatabaseSync } = createRequire(import.meta.url)("node:sqlite") as {
  DatabaseSync: typeof DatabaseSyncType;
};

const SCHEMA = `
  CREATE TABLE IF NOT EXISTS vaults (
    vault_id TEXT PRIMARY KEY,
    owner_locator TEXT NOT NULL UNIQUE,     -- HMAC(server, honeyId): locates, joins to no post
    revision INTEGER NOT NULL,
    iv TEXT NOT NULL,
    ciphertext TEXT NOT NULL,
    wrappers TEXT NOT NULL,                 -- JSON array of wrapper records (ciphertext of R only)
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL
  ) STRICT;

  CREATE TABLE IF NOT EXISTS pairings (
    pairing_id TEXT PRIMARY KEY,
    owner_locator TEXT NOT NULL,
    recipient_public_key TEXT NOT NULL,
    enc TEXT,
    ciphertext TEXT,
    created_at INTEGER NOT NULL,
    expires_at INTEGER NOT NULL
  ) STRICT;
`;

export function openVaultDatabase(path: string): DatabaseSyncType {
  const db = new DatabaseSync(path);
  db.exec("PRAGMA journal_mode = WAL");
  db.exec(SCHEMA);
  return db;
}
