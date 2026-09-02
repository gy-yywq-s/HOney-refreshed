// Transactional canonical import (spec §6.4). One lesson's subject / course /
// section / teacher / room / lesson / exposure land in ONE transaction; a
// label the resolver cannot place leaves the lesson subject-only and is
// recorded on the import run — a whole day's timetable is never dropped for
// one unknown course label, and an unknown label never becomes a public Course.

import { randomUUID } from "node:crypto";
import type { DatabaseSync } from "node:sqlite";
import type { Lesson } from "@honey/shared";
import { candidatesFromLessons } from "./adapter.js";
import { CanonicalResolver } from "./resolver.js";
import type { SchoolProfile } from "./types.js";

export interface ImportCounts {
  lessons: number;
  teachers: number;
  courses: number;
  rooms: number;
  unresolved: number;
  importRunId: string;
}

export class SchoolImportService {
  constructor(
    private readonly db: DatabaseSync,
    readonly profile: SchoolProfile,
    private readonly now: () => number = Date.now,
  ) {}

  /** Canonicalize + persist normalized lessons for one account, in one transaction. */
  importLessons(honeyId: string, lessons: Lesson[]): ImportCounts {
    const runId = randomUUID();
    const startedAt = this.now();
    const resolver = new CanonicalResolver(this.db, this.profile, this.now);
    const candidates = candidatesFromLessons(lessons, this.profile.sourceSystem);

    const lessonStmt = this.db.prepare(
      `INSERT INTO lesson_instances (id, school_id, source_system, source_lesson_id, subject_id, course_id, class_section_id,
         teacher_id, room_id, subject_name, topic_name, starts_at, ends_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
       ON CONFLICT(id) DO UPDATE SET
         subject_id = excluded.subject_id, course_id = excluded.course_id, class_section_id = excluded.class_section_id,
         teacher_id = excluded.teacher_id, room_id = excluded.room_id, subject_name = excluded.subject_name,
         topic_name = excluded.topic_name, starts_at = excluded.starts_at, ends_at = excluded.ends_at`,
    );
    const exposureStmt = this.db.prepare(
      `INSERT INTO user_lesson_exposures (honey_id, lesson_instance_id, teacher_id, course_id, class_section_id)
       VALUES (?, ?, ?, ?, ?)
       ON CONFLICT(honey_id, lesson_instance_id) DO UPDATE SET
         teacher_id = excluded.teacher_id, course_id = excluded.course_id, class_section_id = excluded.class_section_id`,
    );

    const teachers = new Set<string>();
    const courses = new Set<string>();
    const rooms = new Set<string>();

    this.db.exec("BEGIN");
    try {
      this.db
        .prepare("INSERT INTO import_runs (id, honey_id, school_id, source_system, started_at, status) VALUES (?, ?, ?, ?, ?, 'running')")
        .run(runId, honeyId, this.profile.id, this.profile.sourceSystem, startedAt);
      for (const c of candidates) {
        const r = resolver.resolve(c);
        lessonStmt.run(
          r.lessonId, this.profile.id, c.sourceSystem, c.sourceLessonId, r.subjectId, r.courseId, r.classSectionId,
          r.teacherId, r.roomId, r.subjectName, r.topicName, r.startsAt, r.endsAt,
        );
        exposureStmt.run(honeyId, r.lessonId, r.teacherId, r.courseId, r.classSectionId);
        if (r.teacherId) teachers.add(r.teacherId);
        if (r.courseId) courses.add(r.courseId);
        if (r.roomId) rooms.add(r.roomId);
      }
      const unresolvedStmt = this.db.prepare(
        "INSERT INTO unresolved_import_labels (id, import_run_id, field_kind, raw_value, suggested_value, occurrence_count) VALUES (?, ?, ?, ?, ?, 1)",
      );
      for (const u of resolver.unresolved) unresolvedStmt.run(randomUUID(), runId, u.fieldKind, u.rawValue, u.suggestedValue);
      this.db
        .prepare("UPDATE import_runs SET finished_at = ?, lesson_count = ?, unresolved_count = ?, status = 'ok' WHERE id = ?")
        .run(this.now(), candidates.length, resolver.unresolved.length, runId);
      this.db.exec("COMMIT");
    } catch (e) {
      this.db.exec("ROLLBACK");
      throw e;
    }
    return {
      lessons: candidates.length,
      teachers: teachers.size,
      courses: courses.size,
      rooms: rooms.size,
      unresolved: resolver.unresolved.length,
      importRunId: runId,
    };
  }

  /** Labels the resolver could not place, newest runs first (Dash / developer view). */
  unresolvedLabels(limit = 100): { fieldKind: string; rawValue: string; suggestedValue: string | null; seenAt: number }[] {
    return this.db
      .prepare(
        `SELECT u.field_kind AS fieldKind, u.raw_value AS rawValue, u.suggested_value AS suggestedValue, r.started_at AS seenAt
         FROM unresolved_import_labels u JOIN import_runs r ON r.id = u.import_run_id
         ORDER BY r.started_at DESC LIMIT ?`,
      )
      .all(limit) as unknown as { fieldKind: string; rawValue: string; suggestedValue: string | null; seenAt: number }[];
  }
}
