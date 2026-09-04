// Canonical school data — the vocabulary (spec 2026-09-03 §4). Five distinct
// objects, never five names for one thing:
//
//   Subject        Economics                       broad area, search alias, fallback label
//   Course         AL ECON U4                      the curricular unit students mean; PUBLIC entity
//   Class section  2026 Autumn · Prep Class · Ms Z operational teaching group; stored, never public
//   Lesson         Wed 13:30–15:00 · Room 309      one occurrence; the "what just happened" anchor
//   Topic          Market structures revision      lesson-level text, never an entity
//
// Normalization happens ONCE, at the import write boundary. Reads never guess.

/** What a source adapter is allowed to say: facts about the source, no canonical guesses. */
export interface ImportedLessonCandidate {
  sourceSystem: string;
  sourceLessonId: string;
  sourceSubjectId?: string;
  rawSubjectName?: string;
  sourceClassId?: string;
  /** Roster-free by the time it reaches the resolver (see preprocess.ts). */
  rawClassName?: string;
  sourceTopicId?: string;
  rawTopicName?: string;
  rawTeacherName?: string;
  sourceRoomId?: string;
  rawRoomName?: string;
  startsAt: number;
  endsAt: number;
}

export type CourseConfidence = "exact_alias" | "parsed" | "fallback";

export interface CanonicalCourseCandidate {
  subjectCode: string; // ECON
  subjectName: string; // Economics
  canonicalCode: string; // AL ECON U4
  displayName: string; // AL ECON U4
  qualification?: string; // Edexcel IAL
  level?: string; // AL
  unitCode?: string; // U4
  confidence: CourseConfidence;
}

export interface SectionLabel {
  /** "2026 Autumn · Prep Class" — null when the source carries no section fact. */
  sectionName: string | null;
  academicYear: string | null;
  term: string | null;
}

/**
 * A school profile: the deterministic, curated knowledge that turns this
 * school's labels into canonical objects. No classifier — alias entries and a
 * small set of token rules, grown by adding a fixture first, then a rule.
 */
export interface SchoolProfile {
  id: string;
  canonicalName: string;
  sourceSystem: string;
  /** Curated exact matches: normalized subject label → canonical course. */
  courseAliases: Record<string, Omit<CanonicalCourseCandidate, "confidence">>;
  /** Deterministic rules for common variants the alias table has not seen. */
  parseCourse(normalizedLabel: string): Omit<CanonicalCourseCandidate, "confidence"> | null;
  /** Operational section facts from the (roster-free) class label. */
  parseSection(input: { className: string | null; subjectName: string | null; teacherName: string | null }): SectionLabel;
  /** The academic year a lesson at this instant belongs to ("2026-27"). */
  academicYearFor(startsAtMs: number): string;
  /** Explicit teacher merges: normalized alias → normalized canonical alias. */
  teacherAliases: Record<string, string>;
  /** Room labels that mean "no room". */
  roomPlaceholders: string[];
  /** Lesson-level topic text, or null when the source carries none. */
  normalizeTopic(raw: string | null, subjectName: string | null): string | null;
}

export interface ResolvedLesson {
  lessonId: string;
  subjectId: string;
  subjectName: string;
  courseId: string | null;
  classSectionId: string | null;
  teacherId: string | null;
  roomId: string | null;
  topicName: string | null;
  startsAt: number;
  endsAt: number;
}

export interface UnresolvedLabel {
  fieldKind: "course" | "teacher" | "room" | "topic" | "section";
  rawValue: string;
  suggestedValue: string | null;
}
