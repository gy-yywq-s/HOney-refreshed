// The canonical resolver (spec §6.3). Resolution order, per field:
//
//   1. exact source-id alias        (course_aliases.subject_id, room_aliases.source_id)
//   2. exact normalized-label alias (course_aliases.subject_name, teacher/room name aliases)
//   3. the deterministic school profile (curated aliases, then token rules)
//   4. a safe fallback              (subject-only lesson; room/teacher by name)
//   5. an unresolved record         (visible to the developer, never in a browse list)
//
// It writes canonical rows and their aliases as a side effect, inside the
// caller's transaction, so a spelling seen once resolves the same way forever.

import type { DatabaseSync } from "node:sqlite";
import type { CanonicalCourseCandidate, ImportedLessonCandidate, ResolvedLesson, SchoolProfile, UnresolvedLabel } from "./types.js";
import { collapseWhitespace, isPlaceholder, normalizeForMatch, shortHash } from "./preprocess.js";

export class CanonicalResolver {
  readonly unresolved: UnresolvedLabel[] = [];
  private readonly seenUnresolved = new Set<string>();

  constructor(
    private readonly db: DatabaseSync,
    readonly profile: SchoolProfile,
    private readonly now: () => number = Date.now,
  ) {}

  /** Canonicalize one candidate; every referenced row exists when this returns. */
  resolve(c: ImportedLessonCandidate): ResolvedLesson {
    const subjectLabel = c.rawSubjectName && !isPlaceholder(c.rawSubjectName) ? collapseWhitespace(c.rawSubjectName) : null;
    const teacherName = c.rawTeacherName && !isPlaceholder(c.rawTeacherName) ? collapseWhitespace(c.rawTeacherName) : null;

    const teacherId = teacherName ? this.resolveTeacher(teacherName) : null;
    const course = subjectLabel ? this.resolveCourse(c.sourceSystem, subjectLabel, c.sourceSubjectId ?? null) : null;
    const subject = this.resolveSubject(course, subjectLabel);
    const roomId = this.resolveRoom(c.sourceRoomId ?? null, c.rawRoomName ?? null);
    const classSectionId = c.sourceClassId
      ? this.resolveSection(c.sourceSystem, c.sourceClassId, c.rawClassName ?? null, subjectLabel, teacherName, teacherId, course?.id ?? null, c.startsAt)
      : null;
    const topicName = this.profile.normalizeTopic(c.rawTopicName ?? null, subjectLabel);

    return {
      lessonId: c.sourceLessonId,
      subjectId: subject.id,
      subjectName: subject.displayName,
      courseId: course?.id ?? null,
      classSectionId,
      teacherId,
      roomId,
      topicName,
      startsAt: c.startsAt,
      // The source writes period slots; the school profile says when teaching ends.
      endsAt: this.profile.teachingEnd(c.startsAt, c.endsAt),
      slotEndsAt: c.endsAt,
    };
  }

  // ---------- subjects ----------

  private resolveSubject(course: { subjectId: string; subjectName: string } | null, label: string | null): { id: string; displayName: string } {
    if (course) {
      const row = this.db.prepare("SELECT display_name FROM subjects WHERE id = ?").get(course.subjectId) as { display_name: string } | undefined;
      return { id: course.subjectId, displayName: row?.display_name ?? course.subjectName };
    }
    // Subject-only fallback: the raw label IS the subject for the timetable.
    const name = label ?? "Lesson";
    const code = normalizeForMatch(name).toUpperCase().replace(/[^A-Z0-9㐀-鿿]+/g, "_").slice(0, 32) || "LESSON";
    return { id: this.ensureSubject(code, name), displayName: name };
  }

  private ensureSubject(code: string, displayName: string): string {
    const existing = this.db
      .prepare("SELECT id FROM subjects WHERE school_id = ? AND code = ?")
      .get(this.profile.id, code) as { id: string } | undefined;
    if (existing) return existing.id;
    const id = `subj_${shortHash(`${this.profile.id}\0${code}`)}`;
    this.db.prepare("INSERT INTO subjects (id, school_id, code, display_name) VALUES (?, ?, ?, ?)").run(id, this.profile.id, code, displayName);
    return id;
  }

  // ---------- courses ----------

  private resolveCourse(sourceSystem: string, label: string, sourceSubjectId: string | null): { id: string; subjectId: string; subjectName: string } | null {
    const aliasHit = this.db.prepare(
      "SELECT course_id FROM course_aliases WHERE school_id = ? AND source_system = ? AND alias_kind = ? AND alias_value = ?",
    );
    const normalized = normalizeForMatch(label);
    // 1. exact source id alias
    let courseId: string | null = null;
    if (sourceSubjectId) {
      courseId = (aliasHit.get(this.profile.id, sourceSystem, "subject_id", sourceSubjectId) as { course_id: string } | undefined)?.course_id ?? null;
    }
    // 2. exact normalized label alias
    if (!courseId) {
      courseId = (aliasHit.get(this.profile.id, sourceSystem, "subject_name", normalized) as { course_id: string } | undefined)?.course_id ?? null;
    }
    // 3. the school profile: curated aliases, then deterministic rules
    if (!courseId) {
      const curated = this.profile.courseAliases[normalized];
      const candidate: CanonicalCourseCandidate | null = curated
        ? { ...curated, confidence: "exact_alias" }
        : (() => {
            const parsed = this.profile.parseCourse(normalized);
            return parsed ? { ...parsed, confidence: "parsed" } : null;
          })();
      if (candidate) courseId = this.ensureCourse(candidate);
    }
    if (!courseId) {
      // 4/5. subject-only fallback + a visible unresolved record. The label
      // never becomes a public Course entity by itself.
      this.recordUnresolved("course", label, null);
      return null;
    }
    // Remember both spellings so the next import skips the parser.
    const remember = this.db.prepare(
      "INSERT OR IGNORE INTO course_aliases (school_id, source_system, alias_kind, alias_value, course_id) VALUES (?, ?, ?, ?, ?)",
    );
    remember.run(this.profile.id, sourceSystem, "subject_name", normalized, courseId);
    if (sourceSubjectId) remember.run(this.profile.id, sourceSystem, "subject_id", sourceSubjectId, courseId);
    const row = this.db
      .prepare("SELECT c.subject_id, s.display_name FROM courses c JOIN subjects s ON s.id = c.subject_id WHERE c.id = ?")
      .get(courseId) as { subject_id: string; display_name: string };
    return { id: courseId, subjectId: row.subject_id, subjectName: row.display_name };
  }

  private ensureCourse(candidate: CanonicalCourseCandidate): string {
    const subjectId = this.ensureSubject(candidate.subjectCode, candidate.subjectName);
    const existing = this.db
      .prepare("SELECT id FROM courses WHERE school_id = ? AND canonical_code = ?")
      .get(this.profile.id, candidate.canonicalCode) as { id: string } | undefined;
    if (existing) return existing.id;
    const id = `c_${shortHash(`${this.profile.id}\0${candidate.canonicalCode}`)}`;
    this.db
      .prepare(
        `INSERT INTO courses (id, school_id, subject_id, canonical_code, display_name, qualification, level, unit_code, source, active, created_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'import', 1, ?)`,
      )
      .run(
        id,
        this.profile.id,
        subjectId,
        candidate.canonicalCode,
        candidate.displayName,
        candidate.qualification ?? null,
        candidate.level ?? null,
        candidate.unitCode ?? null,
        this.now(),
      );
    return id;
  }

  // ---------- teachers ----------

  resolveTeacher(displayName: string): string {
    const normalizedRaw = normalizeForMatch(displayName);
    const normalized = this.profile.teacherAliases[normalizedRaw] ?? normalizedRaw;
    const hit = this.db
      .prepare("SELECT teacher_id FROM teacher_aliases WHERE school_id = ? AND normalized_alias = ?")
      .get(this.profile.id, normalized) as { teacher_id: string } | undefined;
    let teacherId = hit?.teacher_id ?? null;
    if (!teacherId) {
      teacherId = `t_${shortHash(`${this.profile.id}\0${normalized}`)}`;
      this.db
        .prepare("INSERT OR IGNORE INTO teachers (id, school_id, display_name, source, active, created_at) VALUES (?, ?, ?, 'import', 1, ?)")
        .run(teacherId, this.profile.id, displayName, this.now());
      this.db
        .prepare("INSERT OR IGNORE INTO teacher_aliases (school_id, normalized_alias, teacher_id) VALUES (?, ?, ?)")
        .run(this.profile.id, normalized, teacherId);
    }
    if (normalizedRaw !== normalized) {
      this.db
        .prepare("INSERT OR IGNORE INTO teacher_aliases (school_id, normalized_alias, teacher_id) VALUES (?, ?, ?)")
        .run(this.profile.id, normalizedRaw, teacherId);
    }
    return teacherId;
  }

  // ---------- rooms ----------

  resolveRoom(sourceRoomId: string | null, rawName: string | null): string | null {
    const name = rawName && !isPlaceholder(rawName, this.profile.roomPlaceholders) ? collapseWhitespace(rawName) : null;
    const sourceId = sourceRoomId && !isPlaceholder(sourceRoomId) ? sourceRoomId : null;
    if (!name && !sourceId) return null;
    const alias = this.db.prepare("SELECT room_id FROM room_aliases WHERE school_id = ? AND alias_kind = ? AND alias_value = ?");
    let roomId: string | null = null;
    if (sourceId) roomId = (alias.get(this.profile.id, "source_id", sourceId) as { room_id: string } | undefined)?.room_id ?? null;
    if (!roomId && name) roomId = (alias.get(this.profile.id, "name", normalizeForMatch(name)) as { room_id: string } | undefined)?.room_id ?? null;
    if (!roomId) {
      if (!name) return null; // an id with no readable name is not a place students know
      roomId = `r_${shortHash(`${this.profile.id}\0room\0${normalizeForMatch(name)}`)}`;
      this.db
        .prepare("INSERT OR IGNORE INTO rooms (id, school_id, display_name, source, active, created_at) VALUES (?, ?, ?, 'import', 1, ?)")
        .run(roomId, this.profile.id, name, this.now());
    }
    const remember = this.db.prepare("INSERT OR IGNORE INTO room_aliases (school_id, alias_kind, alias_value, room_id) VALUES (?, ?, ?, ?)");
    if (sourceId) remember.run(this.profile.id, "source_id", sourceId, roomId);
    if (name) remember.run(this.profile.id, "name", normalizeForMatch(name), roomId);
    return roomId;
  }

  // ---------- class sections ----------

  private resolveSection(
    sourceSystem: string,
    sourceClassId: string,
    className: string | null,
    subjectName: string | null,
    teacherName: string | null,
    teacherId: string | null,
    courseId: string | null,
    startsAt: number,
  ): string {
    const id = `sec_${shortHash(`${this.profile.id}\0${sourceSystem}\0${sourceClassId}`)}`;
    const label = this.profile.parseSection({ className, subjectName, teacherName });
    const academicYear = label.academicYear ?? this.profile.academicYearFor(startsAt);
    this.db
      .prepare(
        `INSERT INTO class_sections (id, school_id, source_system, source_class_id, course_id, teacher_id, section_name, academic_year, term, active)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 1)
         ON CONFLICT(school_id, source_system, source_class_id) DO UPDATE SET
           course_id = COALESCE(excluded.course_id, class_sections.course_id),
           teacher_id = COALESCE(excluded.teacher_id, class_sections.teacher_id),
           section_name = COALESCE(excluded.section_name, class_sections.section_name),
           academic_year = COALESCE(excluded.academic_year, class_sections.academic_year),
           term = COALESCE(excluded.term, class_sections.term)`,
      )
      .run(id, this.profile.id, sourceSystem, sourceClassId, courseId, teacherId, label.sectionName, academicYear, label.term);
    if (className && !label.sectionName && normalizeForMatch(className) !== normalizeForMatch(subjectName ?? "")) {
      this.recordUnresolved("section", className, null);
    }
    return id;
  }

  private recordUnresolved(fieldKind: UnresolvedLabel["fieldKind"], rawValue: string, suggested: string | null): void {
    const key = `${fieldKind}\0${rawValue}`;
    if (this.seenUnresolved.has(key)) return;
    this.seenUnresolved.add(key);
    this.unresolved.push({ fieldKind, rawValue, suggestedValue: suggested });
  }
}
