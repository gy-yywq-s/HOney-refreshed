import { createRequire } from "node:module";
import type { DatabaseSync as DatabaseSyncType } from "node:sqlite";

// community.sqlite (spec §33). Rules: no honey_id, no account foreign key,
// no v1 ownership hash, no raw class id, no protocol dual path. `author_tag`
// exists for mine/rate bounds/suspension only and never enters a public or
// admin DTO (redaction.ts + tests enforce it).

const { DatabaseSync } = createRequire(import.meta.url)("node:sqlite") as {
  DatabaseSync: typeof DatabaseSyncType;
};
export type { DatabaseSyncType as DatabaseSync };

const SCHEMA = `
  CREATE TABLE IF NOT EXISTS experiences (
    id TEXT PRIMARY KEY,
    school_id TEXT NOT NULL,
    academic_year TEXT NOT NULL,
    primary_entity_type TEXT NOT NULL,
    primary_entity_id TEXT NOT NULL,
    body TEXT,
    rating INTEGER,
    provenance TEXT NOT NULL,
    status TEXT NOT NULL,                  -- published | blocked
    status_detail TEXT,
    policy_version INTEGER NOT NULL,
    author_tag TEXT NOT NULL,
    posting_public_key TEXT NOT NULL,
    post_nonce TEXT NOT NULL,
    control_public_key TEXT NOT NULL,
    content_hash TEXT NOT NULL,
    client_nonce TEXT NOT NULL UNIQUE,
    published_day INTEGER,
    created_at INTEGER NOT NULL,
    UNIQUE (school_id, academic_year, author_tag, primary_entity_type, primary_entity_id)
  ) STRICT;
  CREATE INDEX IF NOT EXISTS idx_experiences_stream ON experiences(school_id, status, created_at DESC, id DESC);
  CREATE INDEX IF NOT EXISTS idx_experiences_author ON experiences(school_id, academic_year, author_tag, created_at DESC);

  CREATE TABLE IF NOT EXISTS experience_associations (
    experience_id TEXT NOT NULL REFERENCES experiences(id) ON DELETE CASCADE,
    entity_type TEXT NOT NULL,
    entity_id TEXT NOT NULL,
    relationship TEXT NOT NULL,            -- primary | context
    PRIMARY KEY (experience_id, entity_type, entity_id, relationship)
  ) STRICT;
  CREATE INDEX IF NOT EXISTS idx_assoc_entity ON experience_associations(entity_type, entity_id);

  CREATE TABLE IF NOT EXISTS anonymous_token_reservations (
    token_hash TEXT PRIMARY KEY,
    scope_hash TEXT NOT NULL,
    reserved_until INTEGER NOT NULL,
    consumed_at INTEGER
  ) STRICT;

  CREATE TABLE IF NOT EXISTS content_pass_nonces (
    nonce TEXT PRIMARY KEY,
    used_at INTEGER NOT NULL
  ) STRICT;

  CREATE TABLE IF NOT EXISTS community_suspensions (
    school_id TEXT NOT NULL,
    academic_year TEXT NOT NULL,
    author_tag TEXT NOT NULL,
    blocked_attempts INTEGER NOT NULL DEFAULT 0,
    suspended_until INTEGER,
    PRIMARY KEY (school_id, academic_year, author_tag)
  ) STRICT;

  CREATE TABLE IF NOT EXISTS challenges (
    challenge TEXT PRIMARY KEY,
    purpose TEXT NOT NULL,
    expires_at INTEGER NOT NULL
  ) STRICT;

  -- Reactions/reports come from a purpose-separated per school/year key,
  -- registered once with a membership token. The tag is a hash of that key.
  CREATE TABLE IF NOT EXISTS reactor_identities (
    reactor_tag TEXT PRIMARY KEY,
    school_id TEXT NOT NULL,
    academic_year TEXT NOT NULL,
    public_key TEXT NOT NULL,
    registered_at INTEGER NOT NULL
  ) STRICT;

  CREATE TABLE IF NOT EXISTS reactions (
    experience_id TEXT NOT NULL REFERENCES experiences(id) ON DELETE CASCADE,
    reactor_tag TEXT NOT NULL,
    value INTEGER NOT NULL,
    created_at INTEGER NOT NULL,
    PRIMARY KEY (experience_id, reactor_tag)
  ) STRICT;

  CREATE TABLE IF NOT EXISTS reaction_nonces (
    nonce TEXT PRIMARY KEY,
    used_at INTEGER NOT NULL
  ) STRICT;

  CREATE TABLE IF NOT EXISTS reports (
    id TEXT PRIMARY KEY,
    experience_id TEXT NOT NULL REFERENCES experiences(id) ON DELETE CASCADE,
    category TEXT NOT NULL,
    outcome TEXT,                          -- pending | reevaluated_kept | reevaluated_hidden | reevaluation_pending
    reporter_tag TEXT,
    policy_version INTEGER,
    retry_at INTEGER,
    created_at INTEGER NOT NULL
  ) STRICT;
  CREATE UNIQUE INDEX IF NOT EXISTS idx_reports_reporter ON reports(experience_id, reporter_tag);
  CREATE INDEX IF NOT EXISTS idx_reports_retry ON reports(retry_at) WHERE retry_at IS NOT NULL;

  CREATE TABLE IF NOT EXISTS report_rate (
    reactor_tag TEXT PRIMARY KEY,
    window_start INTEGER NOT NULL,
    count INTEGER NOT NULL DEFAULT 0
  ) STRICT;

  CREATE TABLE IF NOT EXISTS settings (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL
  ) STRICT;
`;

export function openCommunityDatabase(path: string): DatabaseSyncType {
  const db = new DatabaseSync(path);
  db.exec("PRAGMA journal_mode = WAL");
  db.exec("PRAGMA foreign_keys = ON");
  db.exec(SCHEMA);
  return db;
}
