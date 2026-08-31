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
