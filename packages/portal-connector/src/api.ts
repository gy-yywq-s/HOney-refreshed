import type {
  CampusCardWire,
  CardConsumeWire,
  CardRechargeWire,
  DoorOptionWire,
  ExitPermitWire,
  LessonTableWire,
  SchoolNoticeWire,
  StudentFeedbackSubmission,
  StudentFeedbackWire,
  StudentWarningWire,
  WeekendStayWire,
  WeeklyLessonWire,
} from "@honey/shared";
import {
  credentialsRejected,
  operationRejected,
  refusalReason,
  envelopeShape,
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

  /**
   * GET /api/notice/get_notice_list — the school's notices ({ rows, total },
   * unpaginated: page/limit are ignored upstream). A safe read; the portal's
   * own words are passed through untouched.
   */
  async noticeList(token: string): Promise<SchoolNoticeWire[]> {
    const resp = await this.http.request({ method: "GET", path: "/api/notice/get_notice_list", token });
    const env = asEnvelope(this.http.triage(resp, "/api/notice/get_notice_list"), "/api/notice/get_notice_list");
    if (env.status !== 0 || env.data === null || typeof env.data !== "object") {
      throw schemaIncompatible("/api/notice/get_notice_list");
    }
    const rows = (env.data as { rows?: unknown }).rows;
    if (!Array.isArray(rows)) throw schemaIncompatible("/api/notice/get_notice_list");
    return (rows as SchoolNoticeWire[]).filter(
      (r) => r && typeof r.id === "number" && typeof r.title === "string" && typeof r.content === "string",
    );
  }

  /** Rows out of the portal's usual `{ status: 0, data: { rows } }` envelope. */
  private async rows<T>(token: string, path: string): Promise<T[]> {
    const resp = await this.http.request({ method: "GET", path, token });
    const env = asEnvelope(this.http.triage(resp, path), path);
    if (env.status !== 0) throw schemaIncompatible(path);
    const data = env.data;
    if (Array.isArray(data)) return data as T[];
    if (data === null || typeof data !== "object") throw schemaIncompatible(path);
    const rows = (data as { rows?: unknown }).rows;
    if (!Array.isArray(rows)) throw schemaIncompatible(path);
    return rows as T[];
  }

  /** GET /api/card/get_card_list — the student's campus card(s) and balances. */
  cardList(token: string): Promise<CampusCardWire[]> {
    return this.rows<CampusCardWire>(token, "/api/card/get_card_list");
  }

  /**
   * GET /api/card/card-consume-record — spending on one card, newest first.
   * The card is addressed by NUMBER: cardId answers 500 upstream.
   */
  cardConsume(token: string, cardNo: string, limit = 60): Promise<CardConsumeWire[]> {
    const path = `/api/card/card-consume-record?cardNo=${encodeURIComponent(cardNo)}&page=1&limit=${Math.min(Math.max(limit, 1), 200)}`;
    return this.rows<CardConsumeWire>(token, path);
  }

  /**
   * GET /api/card/recharge-record — top-ups on one card. Addressed by card_id
   * (the portal's own web app does the same); cardNo answers 500.
   */
  cardRecharges(token: string, cardId: string): Promise<CardRechargeWire[]> {
    return this.rows<CardRechargeWire>(token, `/api/card/recharge-record?card_id=${encodeURIComponent(cardId)}`);
  }

  /** GET /api/students/get_feedback — lessons still waiting for feedback. */
  pendingFeedback(token: string): Promise<StudentFeedbackWire[]> {
    return this.rows<StudentFeedbackWire>(token, "/api/students/get_feedback");
  }

  /** POST /api/students/update_feedback — one lesson's feedback. */
  async submitFeedback(token: string, body: StudentFeedbackSubmission): Promise<void> {
    const path = "/api/students/update_feedback";
    const resp = await this.http.request({ method: "POST", path, token, jsonBody: body, mutation: true });
    const env = asEnvelope(this.http.triage(resp, path), path);
    if (env.status === 0) return;
    throw operationRejected(path, typeof env.status === "number" ? env.status : undefined, refusalReason(env as Record<string, unknown>), envelopeShape(env as Record<string, unknown>));
  }

  /**
   * POST /api/students/student_complaints — the school's own feedback channel
   * (its form sends `{ complaint }` and nothing else). This is NOT anonymous:
   * it arrives at the school under the student's portal identity.
   */
  async submitComplaint(token: string, complaint: string): Promise<void> {
    const path = "/api/students/student_complaints";
    const resp = await this.http.request({ method: "POST", path, token, jsonBody: { complaint }, mutation: true });
    const env = asEnvelope(this.http.triage(resp, path), path);
    if (env.status === 0) return;
    throw operationRejected(path, typeof env.status === "number" ? env.status : undefined, refusalReason(env as Record<string, unknown>), envelopeShape(env as Record<string, unknown>));
  }

  /** GET /api/students/get_my_warning — the student's own disciplinary records. */
  warnings(token: string): Promise<StudentWarningWire[]> {
    return this.rows<StudentWarningWire>(token, "/api/students/get_my_warning");
  }

  /** GET /api/weekend/live_list — the student's own weekend stay-overs. */
  weekendStays(token: string): Promise<WeekendStayWire[]> {
    return this.rows<WeekendStayWire>(token, "/api/weekend/live_list");
  }

  /**
   * GET /api/weekend/weekend_select/{kind} — the days that can be chosen.
   * The path segment is the KIND (1 = staying over, 2 = meals), not a student
   * id: the portal's own weekend page calls it with 1 and 2 (its bundle,
   * 2026-09-04). `special_day` is folded in the same way it folds them.
   */
  async weekendDays(token: string, kind: 1 | 2 = 1): Promise<string[]> {
    const path = `/api/weekend/weekend_select/${kind}`;
    const resp = await this.http.request({ method: "GET", path, token });
    const env = asEnvelope(this.http.triage(resp, path), path);
    if (env.status !== 0 || env.data === null || typeof env.data !== "object") return [];
    const d = env.data as { day_list?: unknown; special_day?: unknown };
    const list = [...(Array.isArray(d.day_list) ? d.day_list : []), ...(Array.isArray(d.special_day) ? d.special_day : [])];
    return [...new Set(list.filter((x): x is string => typeof x === "string"))].sort();
  }

  /**
   * POST /api/weekend/apply_live — apply to stay over. The portal sends the
   * dates comma-joined in `live_dates` (its own weekend page does exactly
   * this). Applying twice for the same day is the school's business, not
   * ours: its answer is passed back as it is.
   */
  async applyWeekendStay(token: string, dates: string[]): Promise<void> {
    const path = "/api/weekend/apply_live";
    const resp = await this.http.request({ method: "POST", path, token, jsonBody: { live_dates: dates.join(",") }, mutation: true });
    const env = asEnvelope(this.http.triage(resp, path), path);
    if (env.status === 0) return;
    throw operationRejected(path, typeof env.status === "number" ? env.status : undefined, refusalReason(env as Record<string, unknown>), envelopeShape(env as Record<string, unknown>));
  }

  /** POST /api/weekend/delete_live_record — withdraw one stay-over. */
  async withdrawWeekendStay(token: string, recordId: number): Promise<void> {
    const path = "/api/weekend/delete_live_record";
    const resp = await this.http.request({ method: "POST", path, token, jsonBody: { record_id: recordId }, mutation: true });
    const env = asEnvelope(this.http.triage(resp, path), path);
    if (env.status === 0) return;
    throw operationRejected(path, typeof env.status === "number" ? env.status : undefined, refusalReason(env as Record<string, unknown>), envelopeShape(env as Record<string, unknown>));
  }

  /**
   * POST /api/card/do-recharge — asks the school to OPEN a top-up order and
   * hand back where to pay it. No money moves here: the student pays in
   * Alipay afterwards, or never (an unpaid order simply stays unpaid). The
   * portal's own web app sends exactly `{ card_id, amount }`.
   *
   * What comes back was not observable without creating an order, so this
   * reads the envelope tolerantly: the first http(s) URL anywhere in the
   * answer is the place to pay, and a payment FORM (the other common
   * gateway shape) is handed back as markup for the client to submit.
   */
  async startRecharge(token: string, cardId: string, amount: number): Promise<{ payUrl: string | null; formHtml: string | null; message: string; shape: string }> {
    const path = "/api/card/do-recharge";
    const resp = await this.http.request({ method: "POST", path, token, jsonBody: { card_id: cardId, amount }, mutation: true });
    const env = asEnvelope(this.http.triage(resp, path), path);
    const message = typeof env.message === "string" ? env.message : "";
    if (env.status !== 0) {
      throw operationRejected(path, typeof env.status === "number" ? env.status : undefined, refusalReason(env as Record<string, unknown>), envelopeShape(env as Record<string, unknown>));
    }
    const serialized = JSON.stringify(env.data ?? null) ?? "";
    const url = /https?:\/\/[^"'\\ ]+/.exec(serialized);
    const form = /<form[\s\S]*<\/form>/i.exec(typeof env.data === "string" ? env.data : serialized);
    return {
      payUrl: url ? url[0].replace(/\\\//g, "/") : null,
      formHtml: form ? form[0].replace(/\\"/g, '"').replace(/\\\//g, "/") : null,
      message,
      /** Keys + value kinds only — no values: enough to learn the layout. */
      shape: envelopeShape((env.data && typeof env.data === "object" ? env.data : { data: env.data }) as Record<string, unknown>),
    };
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
    throw operationRejected("/api/exit/update_door_flag", typeof env.status === "number" ? env.status : undefined, refusalReason(env as Record<string, unknown>), envelopeShape(env as Record<string, unknown>));
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
    throw operationRejected("/api/exit/add_record", typeof env.status === "number" ? env.status : undefined, refusalReason(env as Record<string, unknown>), envelopeShape(env as Record<string, unknown>));
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
    throw operationRejected("/api/exit/delete_record", typeof env.status === "number" ? env.status : undefined, refusalReason(env as Record<string, unknown>), envelopeShape(env as Record<string, unknown>));
  }

  /** POST /api/logout — never retried; callers clear local state even if this fails. */
  async logout(token: string): Promise<void> {
    await this.http
      .request({ method: "POST", path: "/api/logout", token, mutation: true })
      .catch(() => undefined);
  }
}
