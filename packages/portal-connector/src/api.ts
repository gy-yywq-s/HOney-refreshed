import type {
  DoorOptionWire,
  ExitPermitWire,
  LessonTableWire,
  WeeklyLessonWire,
} from "@honey/shared";
import {
  credentialsRejected,
  operationRejected,
  refusalReason,
  schemaIncompatible,
  serverUnavailable,
  userActionRequired,
} from "./errors.js";
import { looksLikeMaintenance, type PortalHttp } from "./http.js";

// Typed wrappers for the 8 confirmed V1 portal endpoints. Success convention
// is inconsistent upstream and handled per endpoint:
//   most: { status: 0, message, data }
//   door list: { status: 1, message: DoorOptionWire[], data: {} }  ← doors live in `message`
//   login success: { status: 0, ..., token }; invalid creds: HTTP 401 { message } (no status field)

interface Envelope {
  status?: unknown;
  message?: unknown;
  data?: unknown;
  token?: unknown;
}

function asEnvelope(body: unknown, endpoint: string): Envelope {
  if (body === null || typeof body !== "object") throw schemaIncompatible(endpoint);
  return body as Envelope;
}

export interface UserInfoWire {
  id: number;
  name?: string;
  email?: string;
  first_name?: string;
  last_name?: string;
  gender?: number;
  campus_id?: number;
  day_student?: number | boolean;
  type: number;
  exp: number;
  [k: string]: unknown;
}

export interface WeeklyScheduleWire {
  student_exam: unknown[];
  special_day: unknown[];
  lessons: WeeklyLessonWire[];
}

export class PortalApi {
  constructor(private readonly http: PortalHttp) {}

  /** POST /api/login — one attempt per call; never auto-looped on rejection. */
  async login(username: string, password: string): Promise<string> {
    const resp = await this.http.request({
      method: "POST",
      path: "/api/login",
      jsonBody: { username, password },
    });
    if (resp.httpStatus >= 500) throw serverUnavailable(resp.httpStatus);
    if (resp.httpStatus === 401) throw credentialsRejected();
    if (resp.body === undefined) {
      // Maintenance windows must NEVER surface as a password prompt (the
      // zero-manual-login invariant); only a real interactive challenge may.
      if (looksLikeMaintenance(resp.rawText)) throw serverUnavailable(resp.httpStatus);
      throw userActionRequired("unknown");
    }
    const env = asEnvelope(resp.body, "/api/login");
    if (typeof env.token === "string" && env.token.length > 0) return env.token;
    if (env.status === 0 && typeof env.data === "object" && env.data !== null) {
      const tok = (env.data as { token?: unknown }).token;
      if (typeof tok === "string" && tok.length > 0) return tok;
    }
    throw schemaIncompatible("/api/login");
  }

  /** GET /api/public/user_info — identity + server-authoritative exp (Unix seconds). */
  async userInfo(token: string): Promise<UserInfoWire> {
    const resp = await this.http.request({ method: "GET", path: "/api/public/user_info", token });
    const env = asEnvelope(this.http.triage(resp, "/api/public/user_info"), "/api/public/user_info");
    if (env.status !== 0 || env.data === null || typeof env.data !== "object") {
      throw schemaIncompatible("/api/public/user_info");
    }
    const d = env.data as UserInfoWire;
    if (typeof d.id !== "number" || typeof d.exp !== "number") {
      throw schemaIncompatible("/api/public/user_info");
    }
    return d;
  }

  /** GET /api/students/schedule/{studentId}/{weekIndex} — weekIndex is the portal's own epoch-week. */
  async weeklySchedule(token: string, studentId: number, weekIndex: number): Promise<WeeklyScheduleWire> {
    const path = `/api/students/schedule/${studentId}/${weekIndex}`;
    const resp = await this.http.request({ method: "GET", path, token });
    const env = asEnvelope(this.http.triage(resp, path), path);
    if (env.data === null || typeof env.data !== "object") {
      throw schemaIncompatible(path);
    }
    // The portal returns status:1 with a message (e.g. "只能查看过去两周内的课表")
    // for weeks outside the viewable range — that is a legitimately EMPTY week,
    // not a schema error. A whole sync must not fail because one week is
    // out of range.
    if (env.status !== 0) {
      return { student_exam: [], special_day: [], lessons: [] };
    }
    const d = env.data as Partial<WeeklyScheduleWire>;
    return {
      student_exam: Array.isArray(d.student_exam) ? d.student_exam : [],
      special_day: Array.isArray(d.special_day) ? d.special_day : [],
      lessons: Array.isArray(d.lessons) ? d.lessons : [],
    };
  }

  /** GET /api/students/get_lesson_table — object keyed by lesson-id string, NOT an array. */
  async lessonTable(token: string): Promise<Record<string, LessonTableWire>> {
    const resp = await this.http.request({ method: "GET", path: "/api/students/get_lesson_table", token });
    const env = asEnvelope(this.http.triage(resp, "/api/students/get_lesson_table"), "/api/students/get_lesson_table");
    if (env.status !== 0 || env.data === null || typeof env.data !== "object") {
      throw schemaIncompatible("/api/students/get_lesson_table");
    }
    return env.data as Record<string, LessonTableWire>;
  }

  /** GET /api/exit/get_student_list — exit permits ({ rows, total }, unpaginated). */
  async permitList(token: string): Promise<ExitPermitWire[]> {
    const resp = await this.http.request({ method: "GET", path: "/api/exit/get_student_list", token });
    const env = asEnvelope(this.http.triage(resp, "/api/exit/get_student_list"), "/api/exit/get_student_list");
    if (env.status !== 0 || env.data === null || typeof env.data !== "object") {
      throw schemaIncompatible("/api/exit/get_student_list");
    }
    const rows = (env.data as { rows?: unknown }).rows;
    if (!Array.isArray(rows)) throw schemaIncompatible("/api/exit/get_student_list");
    return rows as ExitPermitWire[];
  }

  /** GET /api/user/get_door_list — NON-standard: success is status===1, doors in `message`. */
  async doorList(token: string): Promise<DoorOptionWire[]> {
    const resp = await this.http.request({ method: "GET", path: "/api/user/get_door_list", token });
    const env = asEnvelope(this.http.triage(resp, "/api/user/get_door_list"), "/api/user/get_door_list");
    // status!==1 is a degraded endpoint (failure matrix: "temporarily
    // unavailable, no open attempt") — distinct from a genuine empty list.
    if (env.status !== 1 || !Array.isArray(env.message)) throw serverUnavailable();
    return (env.message as DoorOptionWire[]).filter(
      (d) => typeof d?.key === "string" && typeof d?.value === "string",
    );
  }

  /**
   * POST /api/exit/update_door_flag — physically opens a gate. NON-IDEMPOTENT:
   * callers must never auto-retry or replay this. door_id and indexcode carry
   * the same door-key value; commuter route uses record_id = -2.
   */
  async openDoor(token: string, recordId: number, doorKey: string): Promise<void> {
    const resp = await this.http.request({
      method: "POST",
      path: "/api/exit/update_door_flag",
      token,
      jsonBody: { record_id: recordId, status: 1, door_id: doorKey, indexcode: doorKey },
      mutation: true,
    });
    const env = asEnvelope(this.http.triage(resp, "/api/exit/update_door_flag"), "/api/exit/update_door_flag");
    const code = (env as { code?: unknown }).code;
    // Success is ONLY status 0 / code 200 (doc 07). status===1 is the success
    // quirk of a DIFFERENT endpoint (door list) — a nonzero status here means
    // the portal refused to open the gate, and must never read as success.
    if (env.status === 0 || code === 200) return;
    throw operationRejected("/api/exit/update_door_flag", typeof env.status === "number" ? env.status : undefined, refusalReason(env));
  }

  /** POST /api/exit/add_record — create an exit permit request. Explicit user action only. */
  async addPermit(token: string, startTime: string, endTime: string, note: string): Promise<void> {
    const resp = await this.http.request({
      method: "POST",
      path: "/api/exit/add_record",
      token,
      jsonBody: { start_time: startTime, end_time: endTime, note },
      mutation: true,
    });
    const env = asEnvelope(this.http.triage(resp, "/api/exit/add_record"), "/api/exit/add_record");
    const code = (env as { code?: unknown }).code;
    if (env.status === 0 || code === 200) return;
    throw operationRejected("/api/exit/add_record", typeof env.status === "number" ? env.status : undefined, refusalReason(env));
  }

  /** POST /api/exit/delete_record — destructive; explicit user action only, never retried. */
  async deletePermit(token: string, recordId: number): Promise<void> {
    const resp = await this.http.request({
      method: "POST",
      path: "/api/exit/delete_record",
      token,
      jsonBody: { record_id: recordId },
      mutation: true,
    });
    const env = asEnvelope(this.http.triage(resp, "/api/exit/delete_record"), "/api/exit/delete_record");
    const code = (env as { code?: unknown }).code;
    if (env.status === 0 || code === 200) return;
    throw operationRejected("/api/exit/delete_record", typeof env.status === "number" ? env.status : undefined, refusalReason(env));
  }

  /** POST /api/logout — never retried; callers clear local state even if this fails. */
  async logout(token: string): Promise<void> {
    await this.http
      .request({ method: "POST", path: "/api/logout", token, mutation: true })
      .catch(() => undefined);
  }
}
