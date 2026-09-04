// HOney ⇄ OASIS school portal integration contract (Band 4 boundary).
// Re-authored from the connector-analysis blueprint. The portal uses a raw
// `Authorization: <token>` header (no Bearer), server-authoritative `exp`,
// and has NO refresh endpoint — recovery is a full re-login.

export type UnixSeconds = number;

export interface AuthSession {
  token: string;
  expiresAt: Date;
  studentId: string;
}

export interface StoredCredentials {
  username: string;
  password: string;
}

export interface PortalIdentity {
  studentId: string;
  name: string;
  schoolAccountIdentifier: string;
  type: number;
  campusId?: number;
  dayStudent?: boolean;
  tokenExpiresAt: Date;
}

export interface WeeklyLessonWire {
  lesson_id: number;
  start_time: UnixSeconds;
  end_time: UnixSeconds;
  teacher: string;
  subject_name: string;
  room_name: string;
  topic_name: string;
  students: string | string[];
  class_id: number;
  class_name: string;
  conflict: number;
  conflict_with: unknown[];
}

export interface LessonTableWire {
  room_name: string;
  room_id: number;
  lesson_id: number;
  subject_id: number;
  subject_name: string;
  start_time: UnixSeconds;
  topic_id: number;
  end_time: UnixSeconds;
  teacher: string;
  week_num: number;
  conflict: number;
  conflict_with: unknown[];
}

export interface Lesson {
  id: string;
  classId?: string;
  subjectId?: string;
  topicId?: string;
  roomId?: string;
  subjectName: string;
  className?: string;
  topicName?: string;
  teacherDisplayName?: string;
  roomDisplayName?: string;
  startsAt: Date;
  endsAt: Date;
  conflict: boolean;
  conflictWith: string[];
}

export type PermitStatus = 0 | 1 | 2 | 3;

export interface ExitPermitWire {
  record_id: number;
  staff_id: number;
  staff_name: string;
  status: PermitStatus;
  status_name: string;
  note: string;
  flag: number;
  start_time: string;
  end_time: string;
  create_time: string;
  update_time: string;
}

/**
 * Campus card (GET /api/card/get_card_list) — one row per card. Balances are
 * yuan as numbers; `useStatus` 1 = usable. Captured live 2026-09-03.
 */
export interface CampusCardWire {
  cardId: string;
  cardNo: string;
  personName: string;
  genAccount: number;
  subAccount: number;
  totalAccount: number;
  useStatus: number;
  startDate: string;
  endDate: string;
}

/**
 * GET /api/card/card-consume-record?cardNo=&page=&limit= — spending, newest
 * first. NOTE (captured 2026-09-03): passing `cardId` answers HTTP 500; only
 * `cardNo` works, and /api/card/recharge-record answered 500 for every
 * parameter shape tried.
 */
export interface CardConsumeWire {
  chargeNo: string;
  personId: string;
  personName: string;
  merchantName: string;
  /** Amount taken off the card. */
  deduction: number;
  /** Balance after this purchase. */
  balance: number;
  preAccount: number;
  /** "2025-03-28 08:44:56.000", school local time. */
  debitTime: string;
}

/**
 * GET /api/card/recharge-record?card_id= — top-ups on one card. The portal's
 * own web app addresses this one by card_id (its bundle, 2026-09-03); cardNo
 * answers 500 here, the mirror image of the consume endpoint.
 */
export interface CardRechargeWire {
  cardNo: string;
  personName: string;
  /** Yuan, as a string upstream. */
  amount: string;
  status: number;
  status_str: string;
  trade_number: string;
  create_time: string;
  update_time: string;
}

/** GET /api/students/get_my_warning — this student's disciplinary records. */
export interface StudentWarningWire {
  record_id: number;
  campus_name: string;
  warn_type: number;
  warn_type_str: string;
  /** The rule as the school words it. */
  warn_select_str: string;
  warn_reason: string;
  warn_time: string;
  operator_name: string;
  create_time: string;
  update_time: string;
}

/**
 * GET /api/students/get_feedback — the lessons still waiting for this
 * student's feedback (the portal's own "My Notification" page).
 */
export interface StudentFeedbackWire {
  lesson_id: number;
  teacher_name: string;
  topic_name: string;
  /** Unix seconds. */
  start_time: number;
  week_num: number;
}

/**
 * POST /api/students/update_feedback — the body the portal's own form sends
 * (its bundle, 2026-09-04). The flags are its own wording: was late · used
 * mobile for non-academic purposes · was unprepared for class · did not
 * understand the teaching.
 */
export interface StudentFeedbackSubmission {
  lesson_id: number;
  rating: number;
  feedback: string;
  late: 0 | 1;
  used_mobile: 0 | 1;
  unprepared: 0 | 1;
  understandable: 0 | 1;
}

/** GET /api/weekend/live_list — this student's weekend stay-over records. */
export interface WeekendStayWire {
  record_id: number;
  campus_name: string;
  mentor_name: string;
  live_date: string;
  live_date_str: string;
  create_time: string;
}

export interface DoorOptionWire {
  key: string;
  value: string;
}

/**
 * GET /api/notice/get_notice_list → { rows, total } (captured 2026-09-03 from
 * the live portal with the authorized test account; page/limit are ignored —
 * the whole list arrives at once). `content` is plain text with newlines, not
 * HTML. There is no per-student read flag: /api/user/get_dashboard_notice
 * gives only an `unread_count`, never which ones, so HOney keeps "read" on the
 * device.
 */
export interface SchoolNoticeWire {
  id: number;
  title: string;
  content: string;
  campus_id: number;
  operator_id: number;
  create_time: string;
  update_time: string;
}

/** Commuter (day-student) direct-open sentinel used as record_id. */
export const COMMUTER_RECORD_ID = -2 as const;

export interface OpenDoorRequest {
  permitRecordId: number;
  doorKey: string;
}

export type ConnectorError =
  | { kind: "networkUnavailable"; retryable: true }
  | { kind: "timeout"; retryable: true; outcomeUnknown?: boolean }
  | { kind: "serverUnavailable"; retryable: true; httpStatus?: number }
  | { kind: "sessionExpired"; retryable: true }
  | { kind: "credentialsRejected"; retryable: false }
  | { kind: "userActionRequired"; reason: "captcha" | "mfa" | "passwordChanged" | "unknown" }
  /** Well-formed envelope, but the portal refused the operation (NOT a schema problem). */
  /** `reason` = the portal's own words for the refusal (its `message`), when it gave any. */
  | { kind: "operationRejected"; endpoint: string; status?: number; reason?: string; /** Keys + value kinds of the refusal envelope (no values) — loggable, so an unknown layout can be learned. */ shape?: string }
  | { kind: "schemaIncompatible"; endpoint: string };

export interface PortalConnector {
  login(credentials: StoredCredentials): Promise<AuthSession>;
  validate(session: AuthSession): Promise<PortalIdentity>;
  reauthenticate(credentials: StoredCredentials): Promise<AuthSession>;
  /** refresh() is intentionally unsupported: the portal has no refresh flow. */
  getLessons(from: Date, to: Date): Promise<Lesson[]>;
  getPermits(): Promise<ExitPermitWire[]>;
  getDoors(): Promise<DoorOptionWire[]>;
  openDoor(request: OpenDoorRequest): Promise<void>;
  logout(): Promise<void>;
}

/** Portal-specific week index; intentionally NOT the ISO week number. */
export function portalWeekIndex(date: Date): number {
  const monday = new Date(date);
  monday.setHours(0, 0, 0, 0);
  const day = monday.getDay();
  monday.setDate(monday.getDate() + (day === 0 ? -6 : 1 - day));
  const epochLocal = new Date(1970, 0, 1);
  return Math.floor(Math.floor((monday.getTime() - epochLocal.getTime()) / 86_400_000) / 7);
}

/** The portal signals an expired session as HTTP 401 with status 400001 or message "Unauthorized". */
export function isUnauthorized(httpStatus: number, body: unknown): boolean {
  if (httpStatus !== 401 || !body || typeof body !== "object") return false;
  const value = body as { status?: unknown; message?: unknown };
  return value.status === 400001 || value.message === "Unauthorized";
}
