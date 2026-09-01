import type { Lesson, LessonTableWire, WeeklyLessonWire } from "@honey/shared";

// Timetable normalization (spec §5.1/§13.2): join the two upstream sources on
// lesson_id. Weekly provides class/students display data; the Lesson Table
// provides stable subject/topic/room ids and week_num. Teacher remains a
// display string only — the portal exposes no stable teacher id.

const toDate = (unixSeconds: number): Date => new Date(unixSeconds * 1000);

export function joinLessons(
  weekly: WeeklyLessonWire[],
  table: Record<string, LessonTableWire>,
): Lesson[] {
  return weekly.map((w) => {
    const t = table[String(w.lesson_id)];
    const lesson: Lesson = {
      id: String(w.lesson_id),
      subjectName: w.subject_name ?? t?.subject_name ?? "",
      startsAt: toDate(w.start_time),
      endsAt: toDate(w.end_time),
      conflict: w.conflict !== 0,
      conflictWith: Array.isArray(w.conflict_with) ? w.conflict_with.map(String) : [],
    };
    if (w.class_id !== undefined && w.class_id !== null) lesson.classId = String(w.class_id);
    if (w.class_name) lesson.className = w.class_name;
    if (w.topic_name) lesson.topicName = w.topic_name;
    if (w.teacher) lesson.teacherDisplayName = w.teacher;
    if (w.room_name) lesson.roomDisplayName = w.room_name;
    if (t) {
      if (t.subject_id !== undefined) lesson.subjectId = String(t.subject_id);
      if (t.topic_id !== undefined) lesson.topicId = String(t.topic_id);
      // room_id -1 means unassigned upstream.
      if (t.room_id !== undefined && t.room_id !== -1) lesson.roomId = String(t.room_id);
    }
    return lesson;
  });
}

/**
 * Normalize lessons straight from the Lesson Table. This endpoint alone carries
 * the whole current+future term with real times, so it is the primary source;
 * the weekly schedule is only needed for past weeks and per-section class data.
 */
export function normalizeTableLessons(table: Record<string, LessonTableWire>): Lesson[] {
  return Object.values(table).map((t) => {
    const lesson: Lesson = {
      id: String(t.lesson_id),
      subjectName: t.subject_name ?? "",
      startsAt: toDate(t.start_time),
      endsAt: toDate(t.end_time),
      conflict: t.conflict !== 0,
      conflictWith: Array.isArray(t.conflict_with) ? t.conflict_with.map(String) : [],
    };
    if (t.subject_id !== undefined) lesson.subjectId = String(t.subject_id);
    if (t.topic_id !== undefined) lesson.topicId = String(t.topic_id);
    if (t.teacher) lesson.teacherDisplayName = t.teacher;
    if (t.room_name) lesson.roomDisplayName = t.room_name;
    if (t.room_id !== undefined && t.room_id !== -1) lesson.roomId = String(t.room_id);
    return lesson;
  });
}

/** Union two lesson lists by id; entries in `overlay` win over `base`. */
export function mergeLessonsById(base: Lesson[], overlay: Lesson[]): Lesson[] {
  const byId = new Map<string, Lesson>();
  for (const l of base) byId.set(l.id, l);
  for (const l of overlay) byId.set(l.id, l);
  return [...byId.values()];
}

/** Sort lessons chronologically; stable for equal starts. */
export function sortLessons(lessons: Lesson[]): Lesson[] {
  return [...lessons].sort((a, b) => a.startsAt.getTime() - b.startsAt.getTime());
}
