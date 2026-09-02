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

/**
 * The schema epoch. The canonical-data cut (2026-09) recreated the school data
 * tables from scratch instead of migrating the pre-canonical development
 * database; a file from the earlier epoch is refused with instructions rather
 * than silently reshaped or deleted (`pnpm --filter @honey/backend db:reset:dev`).
 */
export const SCHEMA_EPOCH = "canonical-2026-09";

const MIGRATIONS: string[] = [
  // 001 — accounts & sessions (unchanged from the first cut).
  `
  CREATE TABLE honey_users (
    honey_id TEXT PRIMARY KEY,
    school_account_key TEXT NOT NULL UNIQUE,
    display_name TEXT NOT NULL DEFAULT '',
    student_type INTEGER NOT NULL DEFAULT 1,
    created_at INTEGER NOT NULL,
    is_admin INTEGER NOT NULL DEFAULT 0
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
  // 002 — canonical school data (spec 2026-09-03 Part I). Five distinct
  // layers: Subject · Course (the curricular unit, the public entity) · Class
  // section (operational teaching group, stored but never an Experiences
  // entity) · Lesson instance · Topic. Alias tables keep canonical objects
  // stable while portal spellings drift; unresolved labels are recorded, never
  // promoted into the browse list. Roster text never reaches these tables.
  `
  CREATE TABLE schools (
    id TEXT PRIMARY KEY,
    canonical_name TEXT NOT NULL
  ) STRICT;

  CREATE TABLE subjects (
    id TEXT PRIMARY KEY,
    school_id TEXT NOT NULL REFERENCES schools(id),
    code TEXT NOT NULL,
    display_name TEXT NOT NULL,
    UNIQUE (school_id, code)
  ) STRICT;

  CREATE TABLE courses (
    id TEXT PRIMARY KEY,
    school_id TEXT NOT NULL REFERENCES schools(id),
    subject_id TEXT REFERENCES subjects(id),
    canonical_code TEXT NOT NULL,          -- AL ECON U4
    display_name TEXT NOT NULL,            -- normally the canonical code
    qualification TEXT,                    -- Edexcel IAL
    level TEXT,                            -- AL / AS / IGCSE / IELTS
    unit_code TEXT,                        -- U4 / FP3 / Speaking
    source TEXT NOT NULL DEFAULT 'import', -- import | admin
    active INTEGER NOT NULL DEFAULT 1,
    created_at INTEGER NOT NULL,
    UNIQUE (school_id, canonical_code)
  ) STRICT;

  CREATE TABLE course_aliases (
    school_id TEXT NOT NULL REFERENCES schools(id),
    source_system TEXT NOT NULL,
    alias_kind TEXT NOT NULL,              -- subject_name | subject_id | manual
    alias_value TEXT NOT NULL,
    course_id TEXT NOT NULL REFERENCES courses(id),
    PRIMARY KEY (school_id, source_system, alias_kind, alias_value)
  ) STRICT;

  CREATE TABLE teachers (
    id TEXT PRIMARY KEY,
    school_id TEXT NOT NULL REFERENCES schools(id),
    display_name TEXT NOT NULL,
    source TEXT NOT NULL DEFAULT 'import',
    active INTEGER NOT NULL DEFAULT 1,
    created_at INTEGER NOT NULL
  ) STRICT;

  CREATE TABLE teacher_aliases (
    school_id TEXT NOT NULL REFERENCES schools(id),
    normalized_alias TEXT NOT NULL,
    teacher_id TEXT NOT NULL REFERENCES teachers(id),
    PRIMARY KEY (school_id, normalized_alias)
  ) STRICT;

  CREATE TABLE rooms (
    id TEXT PRIMARY KEY,
    school_id TEXT NOT NULL REFERENCES schools(id),
    display_name TEXT NOT NULL,
    source TEXT NOT NULL DEFAULT 'import',
    active INTEGER NOT NULL DEFAULT 1,
    created_at INTEGER NOT NULL
  ) STRICT;

  CREATE TABLE room_aliases (
    school_id TEXT NOT NULL REFERENCES schools(id),
    alias_kind TEXT NOT NULL,              -- source_id | name
    alias_value TEXT NOT NULL,
    room_id TEXT NOT NULL REFERENCES rooms(id),
    PRIMARY KEY (school_id, alias_kind, alias_value)
  ) STRICT;

  CREATE TABLE class_sections (
    id TEXT PRIMARY KEY,
    school_id TEXT NOT NULL REFERENCES schools(id),
    source_system TEXT NOT NULL,
    source_class_id TEXT NOT NULL,
    course_id TEXT REFERENCES courses(id),
    teacher_id TEXT REFERENCES teachers(id),
    section_name TEXT,                     -- safe operational label, never a roster
    academic_year TEXT,
    term TEXT,
    active INTEGER NOT NULL DEFAULT 1,
    UNIQUE (school_id, source_system, source_class_id)
  ) STRICT;

  CREATE TABLE lesson_instances (
    id TEXT PRIMARY KEY,
    school_id TEXT NOT NULL REFERENCES schools(id),
    source_system TEXT NOT NULL,
    source_lesson_id TEXT NOT NULL,
    subject_id TEXT REFERENCES subjects(id),
    course_id TEXT REFERENCES courses(id),
    class_section_id TEXT REFERENCES class_sections(id),
    teacher_id TEXT REFERENCES teachers(id),
    room_id TEXT REFERENCES rooms(id),
    subject_name TEXT NOT NULL,            -- canonical/fallback subject display
    topic_name TEXT,
    starts_at INTEGER NOT NULL,
    ends_at INTEGER NOT NULL,
    UNIQUE (school_id, source_system, source_lesson_id)
  ) STRICT;
  CREATE INDEX idx_lessons_start ON lesson_instances(starts_at);

  CREATE TABLE user_lesson_exposures (
    honey_id TEXT NOT NULL REFERENCES honey_users(honey_id) ON DELETE CASCADE,
    lesson_instance_id TEXT NOT NULL REFERENCES lesson_instances(id) ON DELETE CASCADE,
    teacher_id TEXT,
    course_id TEXT,
    class_section_id TEXT,
    PRIMARY KEY (honey_id, lesson_instance_id)
  ) STRICT;
  CREATE INDEX idx_exposures_user_teacher ON user_lesson_exposures(honey_id, teacher_id);
  CREATE INDEX idx_exposures_user_course ON user_lesson_exposures(honey_id, course_id);

  CREATE TABLE import_runs (
    id TEXT PRIMARY KEY,
    honey_id TEXT NOT NULL,
    school_id TEXT NOT NULL,
    source_system TEXT NOT NULL,
    started_at INTEGER NOT NULL,
    finished_at INTEGER,
    lesson_count INTEGER NOT NULL DEFAULT 0,
    unresolved_count INTEGER NOT NULL DEFAULT 0,
    status TEXT NOT NULL
  ) STRICT;

  CREATE TABLE unresolved_import_labels (
    id TEXT PRIMARY KEY,
    import_run_id TEXT NOT NULL REFERENCES import_runs(id) ON DELETE CASCADE,
    field_kind TEXT NOT NULL,              -- course | teacher | room | topic | section
    raw_value TEXT NOT NULL,               -- roster-free by construction
    suggested_value TEXT,
    occurrence_count INTEGER NOT NULL DEFAULT 1
  ) STRICT;

  -- Community entities that no import produces (canteen dishes, admin-listed).
  CREATE TABLE dishes (
    id TEXT PRIMARY KEY,
    school_id TEXT NOT NULL REFERENCES schools(id),
    display_name TEXT NOT NULL,
    normalized_name TEXT NOT NULL,
    active INTEGER NOT NULL DEFAULT 1,
    created_at INTEGER NOT NULL,
    UNIQUE (school_id, normalized_name)
  ) STRICT;
  `,
  // 003 — Experiences (App A), the two-call publication flow. The experiences
  // table has NO author column, by architecture: ownership is provable only via
  // a client-held key hash, and one-per-scope dedup uses unlinkable HMAC marks
  // that reference no post id. Course associations carry CANONICAL course ids.
  `
  CREATE TABLE experiences (
    id TEXT PRIMARY KEY,
    entity_key TEXT NOT NULL,             -- primary entity "<type>:<id>"
    lesson_id TEXT,                       -- opaque lesson token for lesson-linked posts
    ctx_teacher_id TEXT,
    ctx_course_id TEXT,                   -- canonical course id
    ctx_room_id TEXT,
    body TEXT,                            -- NULLed when hidden/revoked
    rating INTEGER,                       -- only ever non-null for dish entities
    provenance TEXT NOT NULL,             -- verified_lesson | verified_retrospective | verified_member
    status TEXT NOT NULL,                 -- published | blocked | revoked
    status_detail TEXT,
    ownership_hash TEXT NOT NULL UNIQUE,  -- sha256 of the client-held ownership key
    content_hash TEXT NOT NULL,
    policy_version INTEGER NOT NULL,
    created_at INTEGER NOT NULL,
    published_at INTEGER
  ) STRICT;
  CREATE INDEX idx_exp_entity ON experiences(entity_key, status, published_at);
  CREATE INDEX idx_exp_ctx_teacher ON experiences(ctx_teacher_id, status);
  CREATE INDEX idx_exp_ctx_course ON experiences(ctx_course_id, status);

  CREATE TABLE experience_associations (
    experience_id TEXT NOT NULL REFERENCES experiences(id) ON DELETE CASCADE,
    entity_type TEXT NOT NULL,            -- teacher | course | room | lesson | dish
    entity_id TEXT NOT NULL,              -- canonical id; lessons use the opaque token
    relationship TEXT NOT NULL,           -- primary | context
    PRIMARY KEY (experience_id, entity_type, entity_id, relationship)
  ) STRICT;
  CREATE INDEX idx_assoc_entity ON experience_associations(entity_type, entity_id);

  CREATE TABLE experience_eligibility (
    token_hash TEXT PRIMARY KEY,          -- sha256 of the client-held token
    mark_hash TEXT NOT NULL,              -- HMAC(server, honeyId ‖ scope) — joins to nothing
    entity_key TEXT NOT NULL,             -- "<type>:<id>"; lessons use the opaque lesson token
    ctx_teacher_id TEXT,
    ctx_course_id TEXT,
    ctx_room_id TEXT,
    provenance TEXT NOT NULL,
    issued_at INTEGER NOT NULL,
    expires_at INTEGER NOT NULL,
    used_at INTEGER
  ) STRICT;

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
    outcome TEXT,                         -- pending | reevaluated_kept | reevaluated_hidden | reevaluation_pending
    created_at INTEGER NOT NULL,
    reporter_mark TEXT,
    policy_version INTEGER,
    retry_at INTEGER
  ) STRICT;
  CREATE UNIQUE INDEX idx_reports_reporter ON reports(experience_id, reporter_mark);
  CREATE INDEX idx_reports_retry ON reports(retry_at) WHERE retry_at IS NOT NULL;

  CREATE TABLE report_rate (
    honey_id TEXT PRIMARY KEY REFERENCES honey_users(honey_id) ON DELETE CASCADE,
    window_start INTEGER NOT NULL,
    count INTEGER NOT NULL DEFAULT 0
  ) STRICT;

  CREATE TABLE invite_marks (
    entity_key TEXT NOT NULL,
    mark_hash TEXT NOT NULL,              -- HMAC(server, honeyId ‖ entity_key)
    PRIMARY KEY (entity_key, mark_hash)
  ) STRICT;

  CREATE TABLE abuse_counters (
    honey_id TEXT PRIMARY KEY REFERENCES honey_users(honey_id) ON DELETE CASCADE,
    blocked_attempts INTEGER NOT NULL DEFAULT 0,
    last_blocked_at INTEGER,
    suspended_until INTEGER
  ) STRICT;

  CREATE TABLE settings (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL
  ) STRICT;
  `,
];

export class SchemaEpochError extends Error {
  constructor(path: string, found: string | null) {
    super(
      `HOney database ${path} is from schema epoch ${found ?? "(pre-canonical)"}, this build expects ${SCHEMA_EPOCH}. ` +
        "Development data is not migrated across epochs: stop the service and run `pnpm --filter @honey/backend db:reset:dev -- --yes`.",
    );
    this.name = "SchemaEpochError";
  }
}

export function openDatabase(path: string): DatabaseSyncType {
  const db = new DatabaseSync(path);
  db.exec("PRAGMA journal_mode = WAL");
  db.exec("PRAGMA foreign_keys = ON");
  db.exec(
    "CREATE TABLE IF NOT EXISTS schema_migrations (version INTEGER PRIMARY KEY, applied_at INTEGER NOT NULL) STRICT",
  );
  db.exec("CREATE TABLE IF NOT EXISTS schema_epoch (epoch TEXT PRIMARY KEY) STRICT");
  const appliedRow = db.prepare("SELECT MAX(version) AS v FROM schema_migrations").get() as
    | { v: number | null }
    | undefined;
  const applied = appliedRow?.v ?? 0;
  const epochRow = db.prepare("SELECT epoch FROM schema_epoch LIMIT 1").get() as { epoch: string } | undefined;
  if (applied > 0 && epochRow?.epoch !== SCHEMA_EPOCH) {
    db.close();
    throw new SchemaEpochError(path, epochRow?.epoch ?? null);
  }
  if (applied === 0) {
    db.prepare("INSERT OR IGNORE INTO schema_epoch (epoch) VALUES (?)").run(SCHEMA_EPOCH);
  }
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

/** The deployment's school row: every canonical object hangs off it. */
export function ensureSchool(db: DatabaseSyncType, id: string, canonicalName: string): void {
  db.prepare(
    "INSERT INTO schools (id, canonical_name) VALUES (?, ?) ON CONFLICT(id) DO UPDATE SET canonical_name = excluded.canonical_name",
  ).run(id, canonicalName);
}
