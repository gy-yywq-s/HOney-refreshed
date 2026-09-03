// The HOney Core HTTP API contract — the SINGLE SOURCE OF TRUTH for every /api/*
// request and response shape. Backend routes and the web client both depend on these
// types; clients never import backend code, so the only coupling is this contract over HTTP.
//
// Posts live in the Community process (`/community/v2/*`, identity-free): their contract
// is `@honey/shared/community-v2`. Core here is accounts, canonical school data, the
// blind eligibility issuer and the Control Vault.

export interface SessionTokens {
  accessToken: string;
  accessExpiresAt: string;
  refreshToken: string;
  refreshExpiresAt: string;
}

/**
 * Login carries ONLY identity. Import is part of the account (2026-09-01):
 * the first sync runs on creation; `POST /api/consent` remains only for
 * wire compatibility with older iOS builds and no longer gates anything.
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

/**
 * One lesson instance, read from the canonical school data (2026-09): the
 * five layers are distinct objects — Subject (broad area), Course (the
 * curricular unit students mean, e.g. "AL ECON U4"), Class section (the
 * school's operational teaching group — never an Experiences entity),
 * Lesson instance, Topic. Every name here is canonical; clients never
 * re-parse portal strings.
 */
export interface Lesson {
  id: string;
  subjectId: string | null;
  subjectName: string;
  /** Canonical course id / display name ("AL ECON U4"); null when the label is unresolved. */
  courseId: string | null;
  courseName: string | null;
  /** Operational section ("2026 Autumn · Prep Class"); context only, not an entity. */
  classSectionId: string | null;
  classSectionName: string | null;
  topicName: string | null;
  teacherId: string | null;
  teacherName: string | null;
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

/** Several consecutive days in one request (the Week overview). */
export interface TimetableRangeResponse {
  from: string;
  to: string;
  days: { date: string; lessons: Lesson[] }[];
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

/**
 * A notice the school published on the portal (GET /api/notice/get_notice_list,
 * captured 2026-09-03: id · title · content · campus_id · create_time ·
 * operator_id · update_time — plain text with newlines, no HTML, no per-student
 * read flag, no attachments). HOney stores the school's words verbatim and
 * never translates them; "read" is a per-device fact and stays on the device.
 */
export interface SchoolNotice {
  id: string;
  title: string;
  /** The school's own text, plain, newlines preserved. */
  body: string;
  postedAt: number;
  /** When the school last edited it (equals postedAt when never edited). */
  updatedAt: number;
}

export interface NoticesResponse {
  notices: SchoolNotice[];
  /** When HOney last read the portal's notice list. */
  fetchedAt: number | null;
  /**
   * The portal's origin, so a link the school wrote as a site-relative path
   * (its attachments read `[name.pdf](</static/upload/name.pdf>)`) can be
   * opened. The text itself is never rewritten.
   */
  portalOrigin: string;
}

/**
 * The student's own records at the school (Gary 2026-09-03). HOney never
 * stores these: every request reads them live with the student's own portal
 * session. `unavailable` means the portal could not be read just now.
 */
export type SchoolReadStatus = "ok" | "portal_reconnect_required" | "unavailable";

export interface CampusCard {
  cardNo: string;
  /** Yuan. `balance` is what the card can spend; the school splits it in two. */
  balance: number;
  general: number;
  subsidy: number;
  usable: boolean;
  validFrom: string;
  validTo: string;
}

export interface CardPurchase {
  id: string;
  /** The canteen or shop the school names on the record. */
  where: string;
  amount: number;
  balanceAfter: number;
  /** Epoch ms, school local time. */
  at: number;
}

export interface CardTopUp {
  id: string;
  amount: number;
  /** The school's own word for the state ("成功"). */
  state: string;
  at: number;
}

export interface CardResponse {
  status: SchoolReadStatus;
  card: CampusCard | null;
  purchases: CardPurchase[];
  topUps: CardTopUp[];
}

export interface StudentWarning {
  id: number;
  /** "宿舍口头警告" — the school's own wording. */
  kind: string;
  rule: string;
  reason: string;
  on: string;
  by: string;
  recordedAt: string;
}

export interface WarningsResponse {
  status: SchoolReadStatus;
  warnings: StudentWarning[];
}

export interface WeekendStay {
  id: number;
  date: string;
  label: string;
  mentor: string;
  campus: string;
}

export interface WeekendResponse {
  status: SchoolReadStatus;
  stays: WeekendStay[];
  /** The days the school currently allows to be chosen. */
  selectableDays: string[];
}

export type SyncStatus = "ok" | "portal_reconnect_required" | "no_consent";

export interface SyncResponse {
  status: SyncStatus;
  lessons: number;
  teachers: number;
  courses: number;
  rooms: number;
  /** Source labels the canonical resolver could not place (visible in Dash, never in browse lists). */
  unresolved?: number;
}

/**
 * GET /api/portal/entry (additive, 2026-09-02): a URL that opens the school
 * portal's web app already signed in — its login page accepts the portal
 * token in the query and stores it itself. "portal_reconnect_required" when
 * HOney holds no valid token; the client reconnects with the saved login
 * and asks again.
 */
export type PortalEntryResponse =
  | { status: "ok"; url: string; expiresAt: number }
  | { status: "portal_reconnect_required" };

// ---------------------------------------------------------------------------
// The public entity directory (canonical teachers · courses · rooms · dishes).
// Community posts reference these ids; clients join names from here.
// ---------------------------------------------------------------------------

export type EntityType = "teacher" | "course" | "room" | "dish";

export interface EntityRef {
  entity_key: string;
  type: EntityType;
  name: string;
  source: "organic" | "admin";
}

export interface EntitiesResponse {
  entities: EntityRef[];
}

// ---------------------------------------------------------------------------
// Admin dash (isAdmin only). Core owns entities, invites, standalone modes and
// the issuance switches; post-side settings are proxied to Community.
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
  killSwitches: Record<string, boolean>;
  /** Cooling-off period before a high-arousal draft may be re-checked (whole hours). */
  cooldownHours: number;
  llm: { configured: boolean; model: string };
  /** False when the Community process could not be reached for this overview. */
  communityReachable: boolean;
  /** False until the blind-eligibility issuer key is loaded. */
  issuerReady: boolean;
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

/**
 * Moderation models the Dash offers on its wheel (Gary 2026-09-03): only
 * models that were live-benchmarked against the real schema request
 * (docs/architecture/moderation-pipeline.md §Model choice). A model that
 * has not been benched is not on the wheel; the configured model is always
 * shown even when it is not listed here.
 */
export interface CuratedLlmModel {
  id: string;
  label: string;
  /** What the bench found, in a few words. */
  note: string;
}
export const CURATED_LLM_MODELS: readonly CuratedLlmModel[] = [
  { id: "mistralai/mistral-small-3.2-24b-instruct", label: "Mistral Small 3.2 (24B)", note: "Default · 2–4 s · 100 % schema-valid" },
  { id: "deepseek/deepseek-v4-flash", label: "DeepSeek V4 Flash", note: "Fallback · 2–9 s · one malformed in nine" },
];

export interface AdminReport {
  id: string;
  experience_id: string;
  category: string;
  /** `reevaluation_pending` = classifier unavailable/uncertain; the post KEEPS
   *  its current public state and an automatic retry is queued. */
  outcome: "pending" | "reevaluated_kept" | "reevaluated_hidden" | "reevaluation_pending" | null;
  created_at: number;
}

export interface AdminReportsResponse {
  reports: AdminReport[];
}

export interface UnresolvedLabel {
  fieldKind: string;
  rawValue: string;
  suggestedValue: string | null;
  seenAt: number;
}
