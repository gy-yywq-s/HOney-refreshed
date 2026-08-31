import type { DatabaseSync } from "node:sqlite";

// Read-side queries over the normalized store (Band 3). History is a VIEW over
// lesson_instances ⋈ user_lesson_exposures — never a separate source of truth
// (spec §13.3). All results are scoped to the requesting user's exposure.

export interface LessonView {
  id: string;
  subjectName: string;
  topicName: string | null;
  teacherId: string | null;
  teacherName: string | null;
  courseId: string | null;
  courseName: string | null;
  roomId: string | null;
  roomName: string | null;
  startsAt: number;
  endsAt: number;
}

export interface NextLessonView extends LessonView {
  /** Temporal state for Home: "now" | "upcoming" | "none". */
  temporalState: "now" | "upcoming";
  minutesUntilStart: number;
}

const LESSON_SELECT = `
  SELECT li.id, li.subject_name AS subjectName, li.topic_name AS topicName,
         li.teacher_id AS teacherId, t.display_name AS teacherName,
         li.course_id AS courseId, c.name AS courseName,
         li.room_id AS roomId, r.name AS roomName,
         li.starts_at AS startsAt, li.ends_at AS endsAt
  FROM user_lesson_exposures e
  JOIN lesson_instances li ON li.id = e.lesson_instance_id
  LEFT JOIN teachers t ON t.id = li.teacher_id
  LEFT JOIN courses c ON c.id = li.course_id
  LEFT JOIN rooms r ON r.id = li.room_id
  WHERE e.honey_id = ?`;

export class TimetableService {
  constructor(private readonly db: DatabaseSync, private readonly now: () => number = Date.now) {}

  /** Lessons whose span intersects the local day containing `dayStartMs..dayEndMs`. */
  lessonsForDay(honeyId: string, dayStartMs: number, dayEndMs: number): LessonView[] {
    return this.db
      .prepare(`${LESSON_SELECT} AND li.ends_at > ? AND li.starts_at < ? ORDER BY li.starts_at ASC`)
      .all(honeyId, dayStartMs, dayEndMs) as unknown as LessonView[];
  }

  /** Home "Next Lesson": current lesson if one is running, else next upcoming today/later. */
  nextLesson(honeyId: string): NextLessonView | null {
    const now = this.now();
    const current = this.db
      .prepare(`${LESSON_SELECT} AND li.starts_at <= ? AND li.ends_at > ? ORDER BY li.starts_at ASC LIMIT 1`)
      .get(honeyId, now, now) as unknown as LessonView | undefined;
    if (current) return { ...current, temporalState: "now", minutesUntilStart: 0 };

    const upcoming = this.db
      .prepare(`${LESSON_SELECT} AND li.starts_at > ? ORDER BY li.starts_at ASC LIMIT 1`)
      .get(honeyId, now) as unknown as LessonView | undefined;
    if (!upcoming) return null;
    return {
      ...upcoming,
      temporalState: "upcoming",
      minutesUntilStart: Math.round((upcoming.startsAt - now) / 60_000),
    };
  }

  /** Shared History page query: chronological, searchable, filterable (spec §9.3). */
  history(
    honeyId: string,
    opts: {
      q?: string;
      teacherId?: string;
      courseId?: string;
      before?: number;
      limit?: number;
      order?: "asc" | "desc";
    } = {},
  ): LessonView[] {
    const clauses: string[] = [];
    const params: (string | number)[] = [honeyId];
    // History shows past lessons only.
    clauses.push("li.ends_at <= ?");
    params.push(opts.before ?? this.now());
    if (opts.teacherId) {
      clauses.push("li.teacher_id = ?");
      params.push(opts.teacherId);
    }
    if (opts.courseId) {
      clauses.push("li.course_id = ?");
      params.push(opts.courseId);
    }
    if (opts.q) {
      clauses.push("(li.subject_name LIKE ? OR li.topic_name LIKE ? OR t.display_name LIKE ? OR c.name LIKE ?)");
      const like = `%${opts.q}%`;
      params.push(like, like, like, like);
    }
    const order = opts.order === "asc" ? "ASC" : "DESC";
    const limit = Math.min(Math.max(opts.limit ?? 100, 1), 500);
    return this.db
      .prepare(`${LESSON_SELECT} AND ${clauses.join(" AND ")} ORDER BY li.starts_at ${order} LIMIT ${limit}`)
      .all(...([honeyId, ...params.slice(1)] as (string | number)[])) as unknown as LessonView[];
  }

  /** Derived count for selection UX ("42 lessons with Ms X") — spec §9.3 allows it. */
  lessonCountWithTeacher(honeyId: string, teacherId: string): number {
    const row = this.db
      .prepare(
        "SELECT COUNT(*) AS n FROM user_lesson_exposures WHERE honey_id = ? AND teacher_id = ?",
      )
      .get(honeyId, teacherId) as unknown as { n: number };
    return row.n;
  }

  /** Directory of entities this user has actually encountered (for filters). */
  directory(honeyId: string): {
    teachers: { id: string; name: string }[];
    courses: { id: string; name: string }[];
    rooms: { id: string; name: string }[];
  } {
    const teachers = this.db
      .prepare(
        `SELECT DISTINCT t.id, t.display_name AS name FROM user_lesson_exposures e
         JOIN teachers t ON t.id = e.teacher_id WHERE e.honey_id = ? ORDER BY t.display_name`,
      )
      .all(honeyId) as unknown as { id: string; name: string }[];
    const courses = this.db
      .prepare(
        `SELECT DISTINCT c.id, c.name FROM user_lesson_exposures e
         JOIN courses c ON c.id = e.course_id WHERE e.honey_id = ? ORDER BY c.name`,
      )
      .all(honeyId) as unknown as { id: string; name: string }[];
    const rooms = this.db
      .prepare(
        `SELECT DISTINCT r.id, r.name FROM user_lesson_exposures e
         JOIN lesson_instances li ON li.id = e.lesson_instance_id
         JOIN rooms r ON r.id = li.room_id WHERE e.honey_id = ? ORDER BY r.name`,
      )
      .all(honeyId) as unknown as { id: string; name: string }[];
    return { teachers, courses, rooms };
  }
}
