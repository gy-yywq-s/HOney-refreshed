// The HOney HTTP API contract — the SINGLE SOURCE OF TRUTH for every /api/* request
// and response shape. Backend routes and the web client both depend on these types;
// clients never import backend code, so the only coupling is this contract over HTTP.

export interface SessionTokens {
  accessToken: string;
  accessExpiresAt: string;
  refreshToken: string;
  refreshExpiresAt: string;
}

/**
 * Login carries ONLY identity. Signing in and copying school data are two
 * different decisions (review v3 §12.15A): no login payload can grant import
 * consent — `POST /api/consent` is the single consent mutation path.
 */
export interface LoginInput {
  username: string;
  password: string;
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
//
// V1 Experiences objects (Gary, 2026-08-31): lesson / teacher / classroom /
// canteen dish ONLY. "Course" is NOT a browsable Experiences entity in V1 —
// course ids appear only as lesson CONTEXT for filter-time association.
//
// Publication is a two-call flow (no server-side pending state, ever):
//   1. POST /api/experiences/eligibility (authenticated) → single-use token
//   2. POST /api/experiences/check       (authenticated) → moderation lane
//      (+ short-lived content-bound pass when the lane permits publication);
//      the draft body is NEVER persisted by check.
//   3. POST /api/experiences/publish     (NO session auth) → verifies the
//      eligibility token + pass and stores the post. The publish request
//      carries no account identity; published posts store no author ID.
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

export type ExperienceProvenance = "verified_lesson" | "verified_retrospective" | "verified_member";

/**
 * A published post as the PUBLIC feed exposes it: no author, no raw lesson id,
 * no internal status/policy fields, and only a coarse day bucket (days since
 * epoch) — exact timestamps never exist publicly.
 */
export interface PublicExperience {
  id: string;
  entity_key: string;
  ctx_teacher_id: string | null;
  ctx_course_id: string | null;
  ctx_room_id: string | null;
  body: string | null;
  rating: number | null;
  provenance: ExperienceProvenance;
  publishedDay: number | null;
  /** null means counts are hidden (below the small-cohort threshold). */
  reactions: ReactionCounts | null;
}

export interface ExperiencesFeedParams {
  entityKey?: string;
  teacherId?: string;
  /** Context filter only (filter-time association) — course is not an entity. */
  courseId?: string;
  roomId?: string;
  q?: string;
  sort?: "newest" | "oldest";
  /** Epoch ms; return posts published strictly before this instant. */
  before?: number;
  limit?: number;
}

export interface ExperiencesFeedResponse {
  experiences: PublicExperience[];
}

/** GET /api/experiences/from-my-classes?before=&limit= (authenticated). */
export interface FromMyClassesParams {
  before?: number;
  limit?: number;
}

// ---- step 1: eligibility (authenticated; single-use, scope-bound) ----

export interface ExperienceEligibilityInput {
  /** Exactly one of lessonId / entityKey. */
  lessonId?: string;
  entityKey?: string;
}

export interface ExperienceEligibilityResponse {
  ok: true;
  /** Single-use, client-held. The server stores only its sha256. */
  eligibilityToken: string;
  expiresAt: number;
}

export type ExperienceEligibilityError =
  | "publications_disabled"
  | "temporarily_suspended"
  | "target_required"
  | "lesson_not_yours"
  | "entity_unknown"
  | "entity_frozen"
  | "standalone_closed"
  | "not_invited"
  | "no_verified_exposure"
  | "already_reviewed";

// ---- step 2: moderation preflight (authenticated; NEVER persists the body) ----

export interface CheckExperienceInput {
  /** Exactly one of lessonId / entityKey (same target the eligibility is for). */
  lessonId?: string;
  entityKey?: string;
  body: string;
  rating?: number;
  /** Present only when re-checking after a cooldown lane result. */
  cooldownTicket?: string;
}

export type CheckLane =
  | "publish"
  | "nudge"
  | "cooldown"
  | "edit_required"
  | "blocked_serious"
  | "out_of_scope"
  | "failed_closed";

export interface CheckExperienceResponse {
  lane: CheckLane;
  reasons: string[];
  policyVersion: number;
  /**
   * Opaque short-lived content-bound publication pass. Present for lanes
   * `publish` and `nudge` — a nudge STILL requires the user's explicit choice
   * (add context / publish as-is / keep private); the server never publishes.
   */
  pass?: string;
  /** Present for lane `cooldown`: re-check with this ticket after retryAt. */
  cooldown?: { ticket: string; retryAt: number };
}

export type CheckExperienceError =
  | ExperienceEligibilityError
  | "body_invalid"
  | "rating_invalid"
  | "rating_not_allowed"
  | "cooldown_ticket_invalid";

// ---- step 3: publish (NO session auth — token + pass only) ----

export interface PublishExperienceInput {
  eligibilityToken: string;
  pass: string;
  body: string;
  rating?: number;
}

export interface PublishExperienceResponse {
  ok: true;
  experienceId: string;
  /** Client-held; the server keeps only a hash. Shown once — store it. */
  ownershipKey: string;
}

export type PublishExperienceError =
  | "publications_disabled"
  | "pass_invalid"
  | "pass_content_mismatch"
  | "pass_scope_mismatch"
  | "eligibility_invalid"
  | "eligibility_expired"
  | "eligibility_used"
  | "already_reviewed"
  | "entity_frozen"
  | "rating_not_allowed";

// ---- own-submission lifecycle (looked up by client-held ownership keys) ----

export type MyExperienceStatus = "published" | "blocked" | "revoked";

/** Own-submission row. Only ever exists for posts that were actually published. */
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
  provenance: ExperienceProvenance;
  status: MyExperienceStatus;
  status_detail: string | null;
  policy_version: number;
  created_at: number;
  published_at: number | null;
}

export interface MyExperiencesResponse {
  experiences: MyExperience[];
}

// ---- reports (category-only; free text is never accepted) ----

export type ReportCategory =
  | "serious_allegation"
  | "doxxing"
  | "slur"
  | "targets_student"
  | "not_experience"
  | "other_rule";

export interface ReportExperienceInput {
  category: ReportCategory;
}

// ---------------------------------------------------------------------------
// Admin dash (isAdmin only)
// ---------------------------------------------------------------------------

export type KillSwitchName =
  | "DISABLE_NEW_PUBLICATIONS"
  | "DISABLE_REACTIONS"
  | "DISABLE_REPORTS"
  | "HIDE_PUBLIC_EXPERIENCES"
  | "PRIVATE_NOTES_ONLY_MODE";

export type StandaloneMode = "verified" | "open" | "invite" | "closed";

export interface AdminOverview {
  counts: {
    users: number;
    published: number;
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
  category: ReportCategory;
  /** `reevaluation_pending` = classifier unavailable/uncertain; the post KEEPS
   *  its current public state and an automatic retry is queued (§12.15B). */
  outcome: "pending" | "reevaluated_kept" | "reevaluated_hidden" | "reevaluation_pending" | null;
  created_at: number;
}

export interface AdminReportsResponse {
  reports: AdminReport[];
}
