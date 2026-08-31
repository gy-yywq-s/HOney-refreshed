import Fastify, { type FastifyInstance } from "fastify";

// In-process replica of the OASIS portal's observed behavior, including its
// quirks: raw Authorization token, 401+400001 envelope, door list success as
// status===1 with doors in `message`, lesson table keyed by id string.
// Used by connector tests and (later) backend integration tests.

export interface MockPortalState {
  validUsername: string;
  validPassword: string;
  /** Currently valid tokens → expiry unix seconds. */
  tokens: Map<string, number>;
  studentId: number;
  tokenTtlSeconds: number;
  loginCount: number;
  /** Counts every openDoor HTTP request that passed auth — including hangs. */
  doorRequestCount: number;
  openDoorCalls: Array<{ record_id: number; door_id: string; indexcode: string }>;
  /** Behavior switches for failure-matrix tests. */
  mode:
    | "normal"
    | "offline5xx"
    | "maintenanceHtml"
    | "unknownHtml"
    | "loginChallengeHtml"
    | "openDoorHang"
    | "doorRejects"
    | "loginMaintenanceHtml";
  now: () => number;
}

export function makeMockPortal(overrides?: Partial<MockPortalState>): {
  app: FastifyInstance;
  state: MockPortalState;
} {
  const state: MockPortalState = {
    validUsername: "s0088",
    validPassword: "pw-good",
    tokens: new Map(),
    studentId: 88,
    tokenTtlSeconds: 86_400,
    loginCount: 0,
    doorRequestCount: 0,
    openDoorCalls: [],
    mode: "normal",
    now: () => Math.floor(Date.now() / 1000),
    ...overrides,
  };

  // forceCloseConnections keeps teardown fast even with client-aborted
  // in-flight requests (the door-hang scenario).
  const app = Fastify({ logger: false, forceCloseConnections: true });

  const unauthorized = { status: 400001, message: "Unauthorized", data: {} };

  function authed(req: { headers: Record<string, unknown> }): string | null {
    const tok = req.headers["authorization"];
    if (typeof tok !== "string") return null;
    const exp = state.tokens.get(tok);
    if (exp === undefined || exp <= state.now()) return null;
    return tok;
  }

  app.addHook("onRequest", async (req, reply) => {
    if (state.mode === "offline5xx") {
      return reply.code(503).send({ message: "upstream down" });
    }
    if (state.mode === "maintenanceHtml") {
      return reply.code(200).type("text/html").send("<html><body>系统维护 maintenance</body></html>");
    }
    if (state.mode === "unknownHtml") {
      return reply.code(200).type("text/html").send("<html><body>totally new portal</body></html>");
    }
  });

  app.post("/api/login", async (req, reply) => {
    if (state.mode === "loginChallengeHtml") {
      return reply.code(200).type("text/html").send("<html>CAPTCHA required</html>");
    }
    if (state.mode === "loginMaintenanceHtml") {
      return reply.code(200).type("text/html").send("<html><body>系统维护中</body></html>");
    }
    const body = (req.body ?? {}) as { username?: string; password?: string };
    state.loginCount += 1;
    if (body.username !== state.validUsername || body.password !== state.validPassword) {
      return reply.code(401).send({ message: "Invalid credentials" });
    }
    const token = `tok-${state.loginCount}-${Math.random().toString(36).slice(2, 10)}`;
    state.tokens.set(token, state.now() + state.tokenTtlSeconds);
    return { status: 0, message: "ok", data: {}, token };
  });

  app.post("/api/logout", async (req, reply) => {
    const tok = authed(req as never);
    if (tok) state.tokens.delete(tok);
    return reply.send({ status: 0, message: "ok", data: {} });
  });

  app.get("/api/public/user_info", async (req, reply) => {
    const tok = authed(req as never);
    if (!tok) return reply.code(401).send(unauthorized);
    return {
      status: 0,
      message: "ok",
      data: {
        id: state.studentId,
        name: "Mock Student",
        email: "s0088@school.test",
        type: 1,
        campus_id: 1,
        day_student: 1,
        exp: state.tokens.get(tok),
      },
    };
  });

  app.get<{ Params: { sid: string; week: string } }>(
    "/api/students/schedule/:sid/:week",
    async (req, reply) => {
      const tok = authed(req as never);
      if (!tok) return reply.code(401).send(unauthorized);
      const week = Number(req.params.week);
      // One deterministic lesson per requested week, Monday 09:00–09:40 local.
      // 1970-01-01 is a Thursday; the Monday belonging to portal week W is
      // epoch + W*7 + 4 days (matches portalWeekIndex()).
      const monday = new Date(1970, 0, 1);
      monday.setDate(monday.getDate() + week * 7 + 4);
      monday.setHours(9, 0, 0, 0);
      const start = Math.floor(monday.getTime() / 1000);
      return {
        status: 0,
        message: "ok",
        data: {
          student_exam: [],
          special_day: [],
          lessons: [
            {
              lesson_id: 1000 + week,
              start_time: start,
              end_time: start + 2400,
              teacher: "Ms Mock",
              subject_name: "Physics",
              room_name: "Room 204",
              topic_name: "Mechanics",
              students: "Mock Student",
              class_id: 55,
              class_name: "PHY-A",
              conflict: 0,
              conflict_with: [],
            },
          ],
        },
      };
    },
  );

  app.get("/api/students/get_lesson_table", async (req, reply) => {
    const tok = authed(req as never);
    if (!tok) return reply.code(401).send(unauthorized);
    const data: Record<string, unknown> = {};
    for (let week = 2900; week < 2990; week++) {
      data[String(1000 + week)] = {
        room_name: "Room 204",
        room_id: 204,
        lesson_id: 1000 + week,
        subject_id: 7,
        subject_name: "Physics",
        start_time: 0,
        topic_id: 70,
        end_time: 0,
        teacher: "Ms Mock",
        week_num: week,
        conflict: 0,
        conflict_with: [],
      };
    }
    return { status: 0, message: "ok", data };
  });

  app.get("/api/exit/get_student_list", async (req, reply) => {
    const tok = authed(req as never);
    if (!tok) return reply.code(401).send(unauthorized);
    return {
      status: 0,
      message: "ok",
      data: {
        rows: [
          {
            record_id: 501,
            staff_id: 9,
            staff_name: "Mr Approver",
            status: 1,
            status_name: "通过",
            note: "出门",
            flag: 0,
            start_time: "2026-08-31 08:00:00",
            end_time: "2026-08-31 22:00:00",
            create_time: "2026-08-30 12:00:00",
            update_time: "2026-08-30 13:00:00",
          },
        ],
        total: 1,
      },
    };
  });

  app.get("/api/user/get_door_list", async (req, reply) => {
    const tok = authed(req as never);
    if (!tok) return reply.code(401).send(unauthorized);
    // Quirk: success is status===1 and the doors ride in `message`.
    return {
      status: 1,
      message: [
        { key: "door-front-01", value: "正门 Front Gate" },
        { key: "door-back-02", value: "后门 Back Gate" },
      ],
      data: {},
    };
  });

  app.post("/api/exit/update_door_flag", async (req, reply) => {
    const tok = authed(req as never);
    if (!tok) return reply.code(401).send(unauthorized);
    state.doorRequestCount += 1;
    if (state.mode === "doorRejects") {
      return reply.send({ status: 1, message: "no permission", data: {} });
    }
    if (state.mode === "openDoorHang") {
      // Respond far later than any client timeout: simulates unknown outcome
      // (kept short enough that server teardown stays fast in tests).
      await new Promise((r) => setTimeout(r, 2_000));
      return reply.code(504).send({ message: "gateway timeout" });
    }
    const body = (req.body ?? {}) as { record_id: number; door_id: string; indexcode: string };
    state.openDoorCalls.push({
      record_id: body.record_id,
      door_id: body.door_id,
      indexcode: body.indexcode,
    });
    return { status: 0, message: "ok", data: {} };
  });

  app.post("/api/exit/add_record", async (req, reply) => {
    const tok = authed(req as never);
    if (!tok) return reply.code(401).send(unauthorized);
    return { status: 0, message: "ok", data: {} };
  });

  app.post("/api/exit/delete_record", async (req, reply) => {
    const tok = authed(req as never);
    if (!tok) return reply.code(401).send(unauthorized);
    return { status: 0, message: "ok", data: {} };
  });

  return { app, state };
}
