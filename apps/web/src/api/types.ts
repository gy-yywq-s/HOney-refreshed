// Wire types for the HOney backend HTTP API (same-origin /api/*).

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
  startsAt: string;
  endsAt: string;
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
