import { createRequire } from "node:module";
import type { DatabaseSync as DatabaseSyncType } from "node:sqlite";

// access.sqlite (spec §18): the enable/pause switch, the operation journal
// (deduplication, crash recovery, not-sent vs rejected vs unknown), stage
// timestamps and latency samples. Never: a password, a portal token, a
// capability or commit secret, a name, email or honeyId, an upstream body.

const { DatabaseSync } = createRequire(import.meta.url)("node:sqlite") as {
  DatabaseSync: typeof DatabaseSyncType;
};
export type { DatabaseSyncType as DatabaseSync };

const SCHEMA = `
  CREATE TABLE IF NOT EXISTS access_settings (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL,
    updated_at INTEGER NOT NULL
  ) STRICT;

  CREATE TABLE IF NOT EXISTS access_operations (
    id TEXT PRIMARY KEY,
    subject_hash TEXT NOT NULL,
    kind TEXT NOT NULL,                     -- open_gate | apply_permit | withdraw_permit
    gate_key TEXT,
    permit_record_id INTEGER,
    state TEXT NOT NULL,
    commit_hash TEXT NOT NULL UNIQUE,
    client_nonce TEXT,
    payload TEXT,                           -- JSON of the non-identifying request fields (permit window/reason)
    created_at INTEGER NOT NULL,
    prepared_at INTEGER NOT NULL,
    committed_at INTEGER,
    dispatch_started_at INTEGER,
    upstream_headers_at INTEGER,
    upstream_finished_at INTEGER,
    terminal_at INTEGER,
    outcome_code TEXT,
    upstream_status INTEGER,
    upstream_status_class TEXT,
    service_version TEXT NOT NULL,
    updated_at INTEGER NOT NULL
  ) STRICT;
  CREATE INDEX IF NOT EXISTS idx_ops_subject_state ON access_operations(subject_hash, state);
  CREATE INDEX IF NOT EXISTS idx_ops_created ON access_operations(created_at);

  CREATE TABLE IF NOT EXISTS access_latency_samples (
    id INTEGER PRIMARY KEY,
    kind TEXT NOT NULL,
    warm INTEGER NOT NULL,
    duration_ms INTEGER NOT NULL,
    service_version TEXT NOT NULL,
    created_at INTEGER NOT NULL
  ) STRICT;
  CREATE INDEX IF NOT EXISTS idx_latency_kind ON access_latency_samples(kind, created_at DESC);
`;

export function openAccessDatabase(path: string): DatabaseSyncType {
  const db = new DatabaseSync(path);
  db.exec("PRAGMA journal_mode = WAL");
  db.exec(SCHEMA);
  return db;
}
