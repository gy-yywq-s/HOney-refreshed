// Source adapter (spec §6.1): describes what the portal said, nothing more.
// It never invents a course id from a class id; it hands the resolver source
// ids and labels, with the roster already cut (§6.2).

import type { Lesson, LessonTableWire, WeeklyLessonWire } from "@honey/shared";
import { joinLessons, mergeLessonsById, normalizeTableLessons } from "@honey/portal-connector";
import type { ImportedLessonCandidate } from "./types.js";
import { redactRoster } from "./preprocess.js";

export function candidatesFromLessons(lessons: Lesson[], sourceSystem: string): ImportedLessonCandidate[] {
  return lessons.map((l) => {
    const c: ImportedLessonCandidate = {
      sourceSystem,
      sourceLessonId: l.id,
      startsAt: l.startsAt.getTime(),
      endsAt: l.endsAt.getTime(),
    };
    if (l.subjectId) c.sourceSubjectId = l.subjectId;
    if (l.subjectName) c.rawSubjectName = l.subjectName;
    if (l.classId) c.sourceClassId = l.classId;
    if (l.className) c.rawClassName = redactRoster(l.className, l.teacherDisplayName ?? null);
    if (l.topicId) c.sourceTopicId = l.topicId;
    if (l.topicName) c.rawTopicName = l.topicName;
    if (l.teacherDisplayName) c.rawTeacherName = l.teacherDisplayName;
    if (l.roomId) c.sourceRoomId = l.roomId;
    if (l.roomDisplayName) c.rawRoomName = l.roomDisplayName;
    return c;
  });
}

/** The checked-in real-record fixture (packages/backend/fixtures/school/*.json). */
export interface SchoolFixture {
  source: string;
  school: string;
  lessonTable: Record<string, LessonTableWire>;
  weekly: Record<string, { lessons: WeeklyLessonWire[] }>;
}

/** The same merge the live sync performs: the table is primary, weekly overlays win. */
export function lessonsFromFixture(fixture: SchoolFixture): Lesson[] {
  const table = normalizeTableLessons(fixture.lessonTable);
  const weekly = joinLessons(Object.values(fixture.weekly).flatMap((w) => w.lessons), fixture.lessonTable);
  return mergeLessonsById(table, weekly);
}
