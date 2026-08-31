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

/** Sort lessons chronologically; stable for equal starts. */
export function sortLessons(lessons: Lesson[]): Lesson[] {
  return [...lessons].sort((a, b) => a.startsAt.getTime() - b.startsAt.getTime());
}
