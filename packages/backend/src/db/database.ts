import { createRequire } from "node:module";
import type { DatabaseSync as DatabaseSyncType } from "node:sqlite";

// Storage is Node's standard-library SQLite (stdlib-first rule). One writer,
// WAL mode; plenty for a single-school deployment and zero native deps.
// Loaded via createRequire because `node:sqlite` is a prefix-only builtin that
// Vite 5's resolver mishandles under vitest; require() bypasses that cleanly.
const { DatabaseSync } = createRequire(import.meta.url)("node:sqlite") as {
  DatabaseSync: typeof DatabaseSyncType;
};
export type { DatabaseSyncType as DatabaseSync };

const MIGRATIONS: string[] = [
  // 001 — accounts & sessions
  `
  CREATE TABLE honey_users (
    honey_id TEXT PRIMARY KEY,
    school_account_key TEXT NOT NULL UNIQUE,
    display_name TEXT NOT NULL DEFAULT '',
    student_type INTEGER NOT NULL DEFAULT 1,
    created_at INTEGER NOT NULL
  ) STRICT;

  CREATE TABLE honey_sessions (
    access_hash TEXT PRIMARY KEY,
    honey_id TEXT NOT NULL REFERENCES honey_users(honey_id) ON DELETE CASCADE,
    refresh_hash TEXT NOT NULL UNIQUE,
    access_expires_at INTEGER NOT NULL,
    refresh_expires_at INTEGER NOT NULL,
    created_at INTEGER NOT NULL
  ) STRICT;
  CREATE INDEX idx_sessions_user ON honey_sessions(honey_id);

  CREATE TABLE school_connections (
    honey_id TEXT PRIMARY KEY REFERENCES honey_users(honey_id) ON DELETE CASCADE,
    student_id TEXT NOT NULL,
    portal_token_sealed BLOB,
    token_expires_at INTEGER,
    connected INTEGER NOT NULL DEFAULT 1,
    last_synced_at INTEGER
  ) STRICT;

  CREATE TABLE import_consents (
    honey_id TEXT PRIMARY KEY REFERENCES honey_users(honey_id) ON DELETE CASCADE,
    timetable INTEGER NOT NULL DEFAULT 0,
    granted_at INTEGER,
    revoked_at INTEGER
  ) STRICT;
  `,
  // 002 — normalized timetable domain (spec §5.1/§13.2). No exams table, by design.
  `
  CREATE TABLE teachers (
    id TEXT PRIMARY KEY,
    display_name TEXT NOT NULL UNIQUE
  ) STRICT;

  CREATE TABLE courses (
    id TEXT PRIMARY KEY,
    subject_id TEXT,
    name TEXT NOT NULL
  ) STRICT;

  CREATE TABLE rooms (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL
  ) STRICT;

  CREATE TABLE lesson_instances (
    id TEXT PRIMARY KEY,
    course_id TEXT REFERENCES courses(id),
    teacher_id TEXT REFERENCES teachers(id),
    room_id TEXT REFERENCES rooms(id),
    subject_name TEXT NOT NULL,
    topic_name TEXT,
    starts_at INTEGER NOT NULL,
    ends_at INTEGER NOT NULL
  ) STRICT;
  CREATE INDEX idx_lessons_start ON lesson_instances(starts_at);

  CREATE TABLE user_lesson_exposures (
    honey_id TEXT NOT NULL REFERENCES honey_users(honey_id) ON DELETE CASCADE,
    lesson_instance_id TEXT NOT NULL REFERENCES lesson_instances(id) ON DELETE CASCADE,
    teacher_id TEXT,
    course_id TEXT,
    PRIMARY KEY (honey_id, lesson_instance_id)
  ) STRICT;
  CREATE INDEX idx_exposures_user_teacher ON user_lesson_exposures(honey_id, teacher_id);
  CREATE INDEX idx_exposures_user_course ON user_lesson_exposures(honey_id, course_id);
  `,
  // 003 — Experiences (App A). The experiences table has NO author column, by
  // architecture: ownership is provable only via a client-held key hash, and
  // one-per-lesson dedup uses unlinkable HMAC marks that reference no post id.
  `
  CREATE TABLE entity_registry (
    entity_key TEXT PRIMARY KEY,          -- "<type>:<id>", e.g. "teacher:t_ab12"
    type TEXT NOT NULL,                   -- teacher | room | dish (V1 standalone set) | lesson (implicit)
    name TEXT NOT NULL,
    source TEXT NOT NULL DEFAULT 'organic', -- organic (from imports) | admin (imported by admin)
    active INTEGER NOT NULL DEFAULT 1,
    created_at INTEGER NOT NULL
  ) STRICT;

  CREATE TABLE experiences (
    id TEXT PRIMARY KEY,
    entity_key TEXT NOT NULL,             -- primary entity
    lesson_id TEXT,                       -- set for lesson-linked contributions
    ctx_teacher_id TEXT,                  -- context snapshot for filter-time association
    ctx_course_id TEXT,
    ctx_room_id TEXT,
    body TEXT,                            -- NULLed for rejected/failed text (not persisted)
    rating INTEGER,                       -- only ever non-null for dish entities
    provenance TEXT NOT NULL,             -- verified_lesson | verified_retrospective | verified_member
    status TEXT NOT NULL,                 -- pending | cooldown | published | rephrase_required | blocked | failed_closed | revoked
    status_detail TEXT,
    cooldown_until INTEGER,
    ownership_hash TEXT NOT NULL UNIQUE,  -- sha256 of the client-held ownership key
    content_hash TEXT NOT NULL,
    policy_version INTEGER NOT NULL,
    created_at INTEGER NOT NULL,
    published_at INTEGER
  ) STRICT;
  CREATE INDEX idx_exp_entity ON experiences(entity_key, status, published_at);
  CREATE INDEX idx_exp_ctx_teacher ON experiences(ctx_teacher_id, status);
  CREATE INDEX idx_exp_ctx_course ON experiences(ctx_course_id, status);

  CREATE TABLE review_marks (
    mark_hash TEXT PRIMARY KEY            -- HMAC(server, honeyId ‖ scope) — joins to nothing
  ) STRICT;

  CREATE TABLE reactions (
    experience_id TEXT NOT NULL REFERENCES experiences(id) ON DELETE CASCADE,
    dedup_hash TEXT NOT NULL,             -- HMAC(server, honeyId ‖ experienceId) — never displayed
    value INTEGER NOT NULL,               -- 1 like | -1 dislike
    created_at INTEGER NOT NULL,
    PRIMARY KEY (experience_id, dedup_hash)
  ) STRICT;

  CREATE TABLE pass_nonces (
    nonce TEXT PRIMARY KEY,
    used_at INTEGER NOT NULL
  ) STRICT;

  CREATE TABLE reports (
    id TEXT PRIMARY KEY,
    experience_id TEXT NOT NULL REFERENCES experiences(id) ON DELETE CASCADE,
    category TEXT NOT NULL,               -- rule-based, not disagreement
    note TEXT,
    outcome TEXT,                         -- pending | reevaluated_kept | reevaluated_hidden
    created_at INTEGER NOT NULL
  ) STRICT;

  CREATE TABLE invite_marks (
    entity_key TEXT NOT NULL,
    mark_hash TEXT NOT NULL,              -- HMAC(server, honeyId ‖ entity_key)
    PRIMARY KEY (entity_key, mark_hash)
  ) STRICT;

  CREATE TABLE settings (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL
  ) STRICT;
  `,
  // 004 — abuse restriction (App A §21): count high-confidence prohibited
  // publication attempts per account WITHOUT storing the text or any post link.
  `
  CREATE TABLE abuse_counters (
    honey_id TEXT PRIMARY KEY REFERENCES honey_users(honey_id) ON DELETE CASCADE,
    blocked_attempts INTEGER NOT NULL DEFAULT 0,
    last_blocked_at INTEGER,
    suspended_until INTEGER
  ) STRICT;
  `,
];

export function openDatabase(path: string): DatabaseSyncType {
  const db = new DatabaseSync(path);
  db.exec("PRAGMA journal_mode = WAL");
  db.exec("PRAGMA foreign_keys = ON");
  db.exec(
    "CREATE TABLE IF NOT EXISTS schema_migrations (version INTEGER PRIMARY KEY, applied_at INTEGER NOT NULL) STRICT",
  );
  const appliedRow = db.prepare("SELECT MAX(version) AS v FROM schema_migrations").get() as
    | { v: number | null }
    | undefined;
  const applied = appliedRow?.v ?? 0;
  for (let i = applied; i < MIGRATIONS.length; i++) {
    db.exec("BEGIN");
    try {
      db.exec(MIGRATIONS[i]!);
      db.prepare("INSERT INTO schema_migrations (version, applied_at) VALUES (?, ?)").run(
        i + 1,
        Date.now(),
      );
      db.exec("COMMIT");
    } catch (e) {
      db.exec("ROLLBACK");
      throw e;
    }
  }
  return db;
}
