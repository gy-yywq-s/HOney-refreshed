// The HOney HTTP API contract — the SINGLE SOURCE OF TRUTH for every /api/* request
// and response shape. Backend routes and the web client both depend on these types;
// clients never import backend code, so the only coupling is this contract over HTTP.

export interface SessionTokens {
  accessToken: string;
  accessExpiresAt: string;
  refreshToken: string;
  refreshExpiresAt: string;
}

export interface LoginInput {
  username: string;
  password: string;
  consentTimetable?: boolean;
}

export interface LoginResponse {
  honeyId: string;
  displayName: string;
  created: boolean;
  isAdmin: boolean;
  consent: { timetable: boolean };
  session: SessionTokens;
}

export interface Me {
  honeyId: string;
  displayName: string;
  isAdmin: boolean;
  consent: { timetable: boolean; grantedAt: string | null };
  connection: { connected: boolean; lastSyncedAt: string | null; portalTokenValid: boolean };
}

export interface Lesson {
  id: string;
  subjectName: string;
  topicName: string | null;
  teacherId: string | null;
  teacherName: string | null;
  courseId: string | null;
  courseName: string | null;
  roomId: string | null;
  roomName: string | null;
  /** Epoch milliseconds (the backend sends numbers, not ISO strings). */
  startsAt: number;
  endsAt: number;
}

export type TemporalState = "now" | "upcoming";

export interface NextLesson extends Lesson {
  temporalState: TemporalState;
  minutesUntilStart: number;
}

export interface TimetableResponse {
  date: string;
  lessons: Lesson[];
  lastSyncedAt: string | null;
}

export interface NextLessonResponse {
  nextLesson: NextLesson | null;
  lastSyncedAt: string | null;
}

export interface HistoryParams {
  q?: string;
  teacherId?: string;
  courseId?: string;
  before?: string;
  limit?: number;
  order?: "asc" | "desc";
}

export interface HistoryResponse {
  lessons: Lesson[];
}

export interface DirectoryEntry {
  id: string;
  name: string;
}

export interface DirectoryResponse {
  teachers: DirectoryEntry[];
  courses: DirectoryEntry[];
  rooms: DirectoryEntry[];
}

export type SyncStatus = "ok" | "portal_reconnect_required" | "no_consent";

export interface SyncResponse {
  status: SyncStatus;
  lessons: number;
  teachers: number;
  courses: number;
  rooms: number;
}

// ---------------------------------------------------------------------------
// Experiences (anonymous community — App A). Field names mirror the wire
// exactly (snake_case where the backend sends snake_case).
// ---------------------------------------------------------------------------

export type EntityType = "teacher" | "room" | "dish";

export interface EntityRef {
  entity_key: string;
  type: EntityType;
  name: string;
  source: "organic" | "admin";
}

export interface EntitiesResponse {
  entities: EntityRef[];
}

export interface ReactionCounts {
  likes: number;
  dislikes: number;
}

/**
 * A published post as the public feed exposes it: no author, no raw lesson id,
 * and only a coarse day bucket (days since epoch) — exact timestamps never
 * exist publicly.
 */
export interface PublicExperience {
  id: string;
  entity_key: string;
  ctx_teacher_id: string | null;
  ctx_course_id: string | null;
  ctx_room_id: string | null;
  body: string | null;
  rating: number | null;
  provenance: string;
  status: string;
  status_detail: string | null;
  policy_version: number;
  publishedDay: number | null;
  /** null means counts are hidden (below the small-cohort threshold). */
  reactions: ReactionCounts | null;
}

export interface ExperiencesFeedParams {
  entityKey?: string;
  teacherId?: string;
  courseId?: string;
  roomId?: string;
  q?: string;
  sort?: "newest" | "oldest";
  limit?: number;
}

export interface ExperiencesFeedResponse {
  experiences: PublicExperience[];
}

export interface SubmitExperienceInput {
  /** Exactly one of lessonId / entityKey. */
  lessonId?: string;
  entityKey?: string;
  body: string;
  rating?: number;
}

export interface SubmitExperienceResponse {
  ok: true;
  experienceId: string;
  /** Client-held; the server keeps only a hash. Shown once — store it. */
  ownershipKey: string;
  status: "pending";
}

/** 422 error codes the submit endpoint can return. */
export type SubmitExperienceError =
  | "publications_disabled"
  | "body_invalid"
  | "rating_invalid"
  | "lesson_not_yours"
  | "entity_unknown"
  | "entity_frozen"
  | "standalone_closed"
  | "not_invited"
  | "no_verified_exposure"
  | "rating_not_allowed"
  | "already_reviewed";

export type MyExperienceStatus =
  | "pending"
  | "published"
  | "cooldown"
  | "rephrase_required"
  | "blocked"
  | "failed_closed"
  | "revoked";

/** Own-submission row (looked up by client-held keys; includes non-public fields). */
export interface MyExperience {
  id: string;
  entity_key: string;
  /** Opaque lesson token — never the roster-joinable instance id. */
  lesson_id: string | null;
  ctx_teacher_id: string | null;
  ctx_course_id: string | null;
  ctx_room_id: string | null;
  body: string | null;
  rating: number | null;
  provenance: string;
  status: MyExperienceStatus;
  status_detail: string | null;
  cooldown_until: number | null;
  policy_version: number;
  created_at: number;
  published_at: number | null;
}

export interface MyExperiencesResponse {
  experiences: MyExperience[];
}

export interface ReconfirmResponse {
  ok: boolean;
  status?: string;
}

export type ReportCategory =
  | "serious_allegation"
  | "doxxing"
  | "slur"
  | "targets_student"
  | "not_experience"
  | "other_rule";

// ---------------------------------------------------------------------------
// Admin dash (isAdmin only)
// ---------------------------------------------------------------------------

export type KillSwitchName =
  | "DISABLE_NEW_PUBLICATIONS"
  | "DISABLE_REACTIONS"
  | "HIDE_PUBLIC_EXPERIENCES"
  | "PRIVATE_NOTES_ONLY_MODE";

export type StandaloneMode = "verified" | "open" | "invite" | "closed";

export interface AdminOverview {
  counts: {
    users: number;
    published: number;
    pending: number;
    openReports: number;
    entities: number;
  };
  policyVersion: number;
  killSwitches: Record<KillSwitchName, boolean>;
  llm: { configured: boolean; model: string };
}

export interface AdminImportResult {
  ok: boolean;
  added: number;
  merged: number;
  skippedInvalid: number;
}

export interface AdminLlmTestResponse {
  ok: boolean;
  latencyMs: number | null;
  model: string | null;
}

export interface AdminReport {
  id: string;
  experience_id: string;
  category: string;
  note: string | null;
  outcome: "pending" | "reevaluated_kept" | "reevaluated_hidden" | null;
  created_at: number;
}

export interface AdminReportsResponse {
  reports: AdminReport[];
}
