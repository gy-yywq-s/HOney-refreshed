// The current school's profile (OASIS portal at huayaopudong.com). Every rule
// here traces to the real records in fixtures/school/oasis-2026-autumn.json;
// a new label format gets a fixture first, then an alias or a rule. The
// portal's `subject_name` is the closest thing to a curricular course, so it
// resolves the Course; `class_name` resolves the operational section only.

import type { CanonicalCourseCandidate, SchoolProfile, SectionLabel } from "../types.js";
import { collapseWhitespace, isPlaceholder, normalizeForMatch, stripSubjectPrefix, stripTeacherSuffix } from "../preprocess.js";

type Candidate = Omit<CanonicalCourseCandidate, "confidence">;

/** Subject dictionary: the broad area a course belongs to (never a course by itself). */
const SUBJECTS: Record<string, { code: string; name: string }> = {
  economics: { code: "ECON", name: "Economics" },
  physics: { code: "PHYS", name: "Physics" },
  chemistry: { code: "CHEM", name: "Chemistry" },
  biology: { code: "BIO", name: "Biology" },
  mathematics: { code: "MATH", name: "Mathematics" },
  maths: { code: "MATH", name: "Mathematics" },
  "further mathematics": { code: "FM", name: "Further Mathematics" },
  "chinese language & literature": { code: "CHIN", name: "Chinese Language & Literature" },
  chinese: { code: "CHIN", name: "Chinese Language & Literature" },
  english: { code: "ENG", name: "English" },
  "english language": { code: "ENG", name: "English" },
  history: { code: "HIST", name: "History" },
  geography: { code: "GEOG", name: "Geography" },
  psychology: { code: "PSYC", name: "Psychology" },
  business: { code: "BUS", name: "Business" },
  "business studies": { code: "BUS", name: "Business" },
  accounting: { code: "ACC", name: "Accounting" },
  "computer science": { code: "CS", name: "Computer Science" },
  art: { code: "ART", name: "Art" },
  "art & design": { code: "ART", name: "Art" },
};

/**
 * Curated exact matches for the labels this school actually emits. The level
 * for Chinese comes from its section label ("CIEAL中文备考班"): the subject
 * label alone does not carry it, so it is written here rather than guessed.
 */
const COURSE_ALIASES: Record<string, Candidate> = {
  "edexcel economics-u4": course("ECON", "Economics", "AL ECON U4", { qualification: "Edexcel IAL", level: "AL", unitCode: "U4" }),
  "edexcel economics-u3": course("ECON", "Economics", "AL ECON U3", { qualification: "Edexcel IAL", level: "AL", unitCode: "U3" }),
  "cie physics-a2": course("PHYS", "Physics", "AL PHYS A2", { qualification: "CIE", level: "AL", unitCode: "A2" }),
  "cie chinese language & literature": course("CHIN", "Chinese Language & Literature", "AL CHIN", { qualification: "CIE", level: "AL" }),
  "ielts-speaking": course("IELTS", "IELTS", "IELTS Speaking", { qualification: "IELTS", unitCode: "Speaking" }),
  "public speaking": course("PS", "Public Speaking", "Public Speaking", {}),
  tmua: course("TMUA", "TMUA", "TMUA", { qualification: "TMUA" }),
  activity: course("ACT", "Activity", "Activity", {}),
};

function course(
  subjectCode: string,
  subjectName: string,
  canonicalCode: string,
  extra: { qualification?: string; level?: string; unitCode?: string },
): Candidate {
  const c: Candidate = { subjectCode, subjectName, canonicalCode, displayName: canonicalCode };
  if (extra.qualification) c.qualification = extra.qualification;
  if (extra.level) c.level = extra.level;
  if (extra.unitCode) c.unitCode = extra.unitCode;
  return c;
}

const BOARDS: Record<string, string> = { edexcel: "Edexcel IAL", cie: "CIE", cambridge: "CIE", aqa: "AQA", ocr: "OCR" };
/** Unit/paper codes and the level they imply. */
function levelForUnit(unit: string): string | undefined {
  const u = unit.toUpperCase();
  if (u === "AS" || u === "U1" || u === "U2") return "AS";
  if (u === "A2" || /^U[3-6]$/.test(u) || /^FP\d$/.test(u) || /^[MS][3-6]$/.test(u)) return "AL";
  return undefined;
}

/** "Board Subject-Unit" and bare known subjects; anything else is a fallback. */
function parseCourse(label: string): Candidate | null {
  const m = /^(?:(edexcel|cie|cambridge|aqa|ocr|ial)\s+)?(.+?)(?:[-\s]+(u\d|a2|as|fp\d|p\d|m\d|s\d|d\d))?$/i.exec(label);
  if (!m) return null;
  const board = m[1] ? BOARDS[m[1].toLowerCase()] : undefined;
  const subjectWords = normalizeForMatch(m[2] ?? "");
  const unit = m[3]?.toUpperCase();
  const subject = SUBJECTS[subjectWords];
  if (!subject) return null;
  const level = unit ? levelForUnit(unit) : undefined;
  const code = [level, subject.code, unit].filter(Boolean).join(" ") || subject.name;
  const c: Candidate = { subjectCode: subject.code, subjectName: subject.name, canonicalCode: code, displayName: code };
  if (board) c.qualification = board;
  if (level) c.level = level;
  if (unit) c.unitCode = unit;
  return c;
}

const SEASONS: Record<string, string> = { 春: "Spring", 夏: "Summer", 秋: "Autumn", 冬: "Winter" };
const TERM = /^(20\d\d)年?([春夏秋冬])/;
/** Group-type suffixes → the label students would read; unknown runs stay verbatim. */
const GROUP_TYPES: [RegExp, (m: RegExpExecArray) => string][] = [
  [/备考(\d+)班$/, (m) => `Prep Class ${m[1]}`],
  [/备考班$/, () => "Prep Class"],
  [/强化(\d+)班$/, (m) => `Intensive Class ${m[1]}`],
  [/强化班$/, () => "Intensive Class"],
  [/进阶(\d+)班$/, (m) => `Advanced Class ${m[1]}`],
  [/进阶班$/, () => "Advanced Class"],
  [/活动课$/, () => "Activity"],
];

function parseSection(input: { className: string | null; subjectName: string | null; teacherName: string | null }): SectionLabel {
  const none: SectionLabel = { sectionName: null, academicYear: null, term: null };
  if (!input.className) return none;
  // "<subject> 2026秋EdexcelIALECONU4备考班 <teacher>" → "2026秋EdexcelIALECONU4备考班"
  const rest = stripTeacherSuffix(stripSubjectPrefix(input.className, input.subjectName), input.teacherName);
  if (!rest) return none;
  const termMatch = TERM.exec(rest);
  let term: string | null = null;
  let academicYear: string | null = null;
  let remainder = rest;
  if (termMatch) {
    const year = Number(termMatch[1]);
    const season = SEASONS[termMatch[2]!] ?? termMatch[2]!;
    term = `${year} ${season}`;
    academicYear = season === "Autumn" || season === "Winter" ? `${year}-${String(year + 1).slice(2)}` : `${year - 1}-${String(year).slice(2)}`;
    remainder = collapseWhitespace(rest.slice(termMatch[0].length));
  }
  // The group type is the trailing CJK run (with a digit for numbered classes).
  const run = /([㐀-鿿]+\d*[㐀-鿿]*)$/.exec(remainder)?.[1] ?? "";
  let type: string | null = null;
  if (run) {
    for (const [re, label] of GROUP_TYPES) {
      const m = re.exec(run);
      if (m) {
        type = label(m);
        break;
      }
    }
    if (!type) type = run;
  }
  const sectionName = [term, type].filter(Boolean).join(" · ") || null;
  return { sectionName, academicYear, term };
}

function academicYearFor(startsAtMs: number): string {
  // The school's local calendar (Asia/Shanghai); August starts a new year.
  const d = new Date(startsAtMs + 8 * 3600 * 1000);
  const y = d.getUTCFullYear();
  const m = d.getUTCMonth() + 1;
  return m >= 8 ? `${y}-${String(y + 1).slice(2)}` : `${y - 1}-${String(y).slice(2)}`;
}

function normalizeTopic(raw: string | null, subjectName: string | null): string | null {
  if (!raw || isPlaceholder(raw)) return null;
  const topic = collapseWhitespace(raw);
  // The portal repeats the subject as the topic when there is none.
  if (subjectName && normalizeForMatch(topic) === normalizeForMatch(subjectName)) return null;
  return topic;
}

export const huayaopudong: SchoolProfile = {
  id: "huayaopudong",
  canonicalName: "huayaopudong.com",
  sourceSystem: "oasis",
  courseAliases: COURSE_ALIASES,
  parseCourse,
  parseSection,
  academicYearFor,
  teacherAliases: {},
  roomPlaceholders: ["Not selected"],
  normalizeTopic,
};

export const PROFILES: Record<string, SchoolProfile> = { huayaopudong };

export function profileFor(schoolId: string): SchoolProfile {
  const p = PROFILES[schoolId];
  if (!p) throw new Error(`no school profile for ${schoolId}`);
  return p;
}
