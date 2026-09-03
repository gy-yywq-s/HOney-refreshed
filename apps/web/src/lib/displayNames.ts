// Display helpers for canonical names. Domain meaning is settled at the
// import boundary on the backend (canonical Course "AL ECON U4", section
// "2026 Autumn · Prep Class", teacher, room); nothing here corrects a name —
// these helpers only abbreviate and typeset for narrow places.

/** The lesson's title: the canonical Course students mean ("AL ECON U4"), else its Subject. */
export function lessonTitle(lesson: { courseName: string | null; subjectName: string }): string {
  return lesson.courseName ?? lesson.subjectName;
}

const LEVEL_PREFIX = /^(AL|AS|A2|IGCSE|GCSE|IB|AP)\s+/;

/** Week-matrix cell form of the title: a course code drops its level ("ECON U4"); a subject compacts. */
export function compactLessonTitle(lesson: { courseName: string | null; subjectName: string }, phone = false): string {
  if (lesson.courseName) {
    const code = lesson.courseName.replace(LEVEL_PREFIX, "").trim();
    return phone && code.length > 8 ? shortSubjectName(code) : code;
  }
  return phone ? shortSubjectName(lesson.subjectName) : compactSubjectName(lesson.subjectName);
}

/** "Room 309" — a bare room number gets the word; a named place keeps its name. */
export function roomLabel(room: string | null | undefined): string {
  if (!room) return "";
  return /^[0-9]+[A-Za-z]?$/.test(room.trim()) ? `Room ${room.trim()}` : room;
}

/**
 * The subject as a Week-matrix cell reads it (addendum §9.4): a stable,
 * meaningful short form — never initials invented from every capital.
 * "Edexcel Economics-U4" → "Economics"; "CIE Chinese Language & Literature"
 * → "Chinese"; "IELTS-Speaking" → "IELTS"; "CIE Physics-A2" → "Physics";
 * "Activity" → "Activity"; "Public Speaking" → "Public Speaking".
 */
const BOARD_WORDS = /^(Edexcel|CIE|Cambridge|AQA|OCR|IGCSE|GCSE|IAL|IB|AP)\b\s*/i;
const UNIT_SUFFIX = /[-\s](U\d+|A[12]|AS|P\d+|L\d+|Y\d+)$/i;
export function compactSubjectName(subject: string): string {
  let s = subject.trim().replace(BOARD_WORDS, "").replace(UNIT_SUFFIX, "").trim();
  if (!s) return subject.trim();
  // "IELTS-Speaking" → "IELTS": a hyphenated qualifier after a short head.
  const hy = s.match(/^([A-Za-z]{3,8})-([A-Za-z].*)$/);
  if (hy) s = hy[1]!;
  if (s.length <= 16) return s;
  // "Chinese Language & Literature" → "Chinese": the head word carries the identity.
  const head = s.split(/\s+/)[0]!;
  return head.length >= 4 ? head : s;
}

/**
 * The narrowest tier (addendum §9.3 / §19.2): a stable short form for phone
 * columns where the compact name would still break mid-word. A curated map,
 * never initials; anything unmapped keeps its compact name.
 */
const SHORT: Record<string, string> = {
  Economics: "Econ",
  Mathematics: "Maths",
  Chemistry: "Chem",
  Geography: "Geog",
  Literature: "Lit",
  Psychology: "Psych",
  Computing: "Comp",
  Business: "Bus",
  Accounting: "Acc",
  Sociology: "Soc",
  Philosophy: "Phil",
  Statistics: "Stats",
};
export function shortSubjectName(subject: string, maxChars = 8): string {
  const compact = compactSubjectName(subject);
  if (compact.length <= maxChars) return compact;
  return SHORT[compact] ?? compact;
}
