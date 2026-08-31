import { createHash } from "node:crypto";
import type { DatabaseSync } from "node:sqlite";
import type { Lesson } from "@honey/shared";
import { PortalApi, joinLessons, retrySafeRead } from "@honey/portal-connector";
import { portalWeekIndex } from "@honey/shared";
import type { AccountService } from "./accounts.js";
import type { EntityRegistry } from "../experiences/entities.js";

// Timetable import (Band 4 → Band 3 handoff): pulls upstream weeks with the
// stored portal token, normalizes into canonical entities, records the user's
// lesson exposure. Raw payloads never leave this module (spec §5.2).

/** Teacher has no stable upstream id — derive one from the display string. */
export function teacherIdFor(displayName: string): string {
  return "t_" + createHash("sha256").update(displayName.trim()).digest("hex").slice(0, 12);
}

export interface SyncResult {
  lessons: number;
  teachers: number;
  courses: number;
  rooms: number;
  status: "ok" | "portal_reconnect_required" | "no_consent";
}

export class ImportService {
  constructor(
    private readonly db: DatabaseSync,
    private readonly accounts: AccountService,
    private readonly api: PortalApi,
    private readonly registry?: EntityRegistry,
    private readonly now: () => Date = () => new Date(),
  ) {}

  /**
   * Sync a window of [-8 weeks, +4 weeks] around now. Uses the sealed portal
   * token; on expiry marks the connection for client-driven reconnect (the
   * backend holds no school password — by design it cannot re-login itself).
   */
  async syncTimetable(honeyId: string): Promise<SyncResult> {
    const consent = this.accounts.getConsent(honeyId);
    if (!consent.timetable) return { lessons: 0, teachers: 0, courses: 0, rooms: 0, status: "no_consent" };

    const conn = this.accounts.loadPortalToken(honeyId);
    if (!conn) return { lessons: 0, teachers: 0, courses: 0, rooms: 0, status: "portal_reconnect_required" };

    const nowDate = this.now();
    const from = new Date(nowDate.getTime() - 8 * 7 * 86_400_000);
    const to = new Date(nowDate.getTime() + 4 * 7 * 86_400_000);

    let lessons: Lesson[];
    try {
      const studentId = Number(conn.studentId);
      const table = await retrySafeRead(() => this.api.lessonTable(conn.token));
      const firstWeek = portalWeekIndex(from);
      const lastWeek = portalWeekIndex(to);
      const weekly = await Promise.all(
        Array.from({ length: lastWeek - firstWeek + 1 }, (_, i) =>
          retrySafeRead(() => this.api.weeklySchedule(conn.token, studentId, firstWeek + i)),
        ),
      );
      lessons = joinLessons(weekly.flatMap((w) => w.lessons), table);
    } catch (e) {
      if (e instanceof Error && "info" in e) {
        const kind = (e as { info: { kind: string } }).info.kind;
        if (kind === "sessionExpired") {
          this.accounts.markPortalExpired(honeyId);
          return { lessons: 0, teachers: 0, courses: 0, rooms: 0, status: "portal_reconnect_required" };
        }
      }
      throw e;
    }

    const counts = this.upsertLessons(honeyId, lessons);
    this.registry?.syncOrganic(); // organic entity accrual (decisions doc)
    this.accounts.markSynced(honeyId);
    return { ...counts, status: "ok" };
  }

  /** Pure persistence of already-normalized lessons (also used by tests/seeds). */
  upsertLessons(honeyId: string, lessons: Lesson[]): { lessons: number; teachers: number; courses: number; rooms: number } {
    const teacherStmt = this.db.prepare(
      "INSERT INTO teachers (id, display_name) VALUES (?, ?) ON CONFLICT(id) DO NOTHING",
    );
    const courseStmt = this.db.prepare(
      `INSERT INTO courses (id, subject_id, name) VALUES (?, ?, ?)
       ON CONFLICT(id) DO UPDATE SET subject_id = excluded.subject_id, name = excluded.name`,
    );
    const roomStmt = this.db.prepare(
      "INSERT INTO rooms (id, name) VALUES (?, ?) ON CONFLICT(id) DO UPDATE SET name = excluded.name",
    );
    const lessonStmt = this.db.prepare(
      `INSERT INTO lesson_instances (id, course_id, teacher_id, room_id, subject_name, topic_name, starts_at, ends_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?)
       ON CONFLICT(id) DO UPDATE SET
         course_id = excluded.course_id, teacher_id = excluded.teacher_id,
         room_id = excluded.room_id, subject_name = excluded.subject_name,
         topic_name = excluded.topic_name, starts_at = excluded.starts_at, ends_at = excluded.ends_at`,
    );
    const exposureStmt = this.db.prepare(
      `INSERT INTO user_lesson_exposures (honey_id, lesson_instance_id, teacher_id, course_id)
       VALUES (?, ?, ?, ?)
       ON CONFLICT(honey_id, lesson_instance_id) DO UPDATE SET
         teacher_id = excluded.teacher_id, course_id = excluded.course_id`,
    );

    const teachers = new Set<string>();
    const courses = new Set<string>();
    const rooms = new Set<string>();

    this.db.exec("BEGIN");
    try {
      for (const l of lessons) {
        let teacherId: string | null = null;
        if (l.teacherDisplayName) {
          teacherId = teacherIdFor(l.teacherDisplayName);
          teacherStmt.run(teacherId, l.teacherDisplayName.trim());
          teachers.add(teacherId);
        }
        let courseId: string | null = null;
        if (l.classId) {
          courseId = `c_${l.classId}`;
          courseStmt.run(courseId, l.subjectId ?? null, l.className ?? l.subjectName);
          courses.add(courseId);
        }
        let roomId: string | null = null;
        if (l.roomId) {
          roomId = `r_${l.roomId}`;
          roomStmt.run(roomId, l.roomDisplayName ?? l.roomId);
          rooms.add(roomId);
        } else if (l.roomDisplayName) {
          roomId = `r_${createHash("sha256").update(l.roomDisplayName).digest("hex").slice(0, 12)}`;
          roomStmt.run(roomId, l.roomDisplayName);
          rooms.add(roomId);
        }
        lessonStmt.run(
          l.id,
          courseId,
          teacherId,
          roomId,
          l.subjectName,
          l.topicName ?? null,
          l.startsAt.getTime(),
          l.endsAt.getTime(),
        );
        exposureStmt.run(honeyId, l.id, teacherId, courseId);
      }
      this.db.exec("COMMIT");
    } catch (e) {
      this.db.exec("ROLLBACK");
      throw e;
    }
    return { lessons: lessons.length, teachers: teachers.size, courses: courses.size, rooms: rooms.size };
  }
}
