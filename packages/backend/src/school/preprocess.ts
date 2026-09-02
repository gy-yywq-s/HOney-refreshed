// Privacy-safe preprocessing (spec §6.2): whitespace and Unicode normalization
// for MATCHING only, placeholder discarding, and roster redaction. Student
// names must never become canonical entities or reach a stored label — this
// module is the boundary that guarantees it, and it runs before the resolver.

const PLACEHOLDERS = new Set(["", "-", "--", "-1", "0", "null", "none", "n/a", "na", "tbd", "tba", "not selected", "未选择", "无", "未定", "待定"]);

/** Collapse runs of whitespace; trim. Keeps case and script. */
export function collapseWhitespace(value: string): string {
  return value.replace(/\s+/g, " ").trim();
}

/** Matching form: NFKC, collapsed, case-folded. Never displayed. */
export function normalizeForMatch(value: string): string {
  return collapseWhitespace(value.normalize("NFKC")).toLowerCase();
}

export function isPlaceholder(value: string | null | undefined, extra: readonly string[] = []): boolean {
  if (value === null || value === undefined) return true;
  const n = normalizeForMatch(value);
  return PLACEHOLDERS.has(n) || extra.some((p) => normalizeForMatch(p) === n);
}

/** A run of CJK ideographs, optionally with digits/Latin glued on (class codes). */
const CJK_ONLY = /^[㐀-鿿]+$/;
/** Tokens ending in 班 / 课 / 组 name a teaching group and 老师 names a role — labels, not rosters. */
const GROUP_SUFFIX = /([班课组]|老师)$/;

/**
 * Cut the roster out of a class label. The portal appends the students of a
 * class to its name ("… 备考班 朱昂明 张李王…"): everything after the lesson's
 * teacher token is roster and goes; without a teacher token, any pure-CJK
 * token of 4+ characters that is not a group label (班/课/组) is treated as
 * roster too. The result carries at most subject, term/class code and teacher.
 */
export function redactRoster(className: string, teacherName: string | null | undefined): string {
  const tokens = collapseWhitespace(className).split(" ").filter(Boolean);
  if (tokens.length === 0) return "";
  const teacher = teacherName ? collapseWhitespace(teacherName) : "";
  const at = teacher ? tokens.lastIndexOf(teacher) : -1;
  const kept = at >= 0 ? tokens.slice(0, at + 1) : tokens.filter((t) => !(CJK_ONLY.test(t) && t.length >= 4 && !GROUP_SUFFIX.test(t)));
  return kept.join(" ");
}

/** Remove a leading subject label from a class label ("<subject> <rest>" → "<rest>"). */
export function stripSubjectPrefix(className: string, subjectName: string | null | undefined): string {
  const cls = collapseWhitespace(className);
  if (!subjectName) return cls;
  const subj = collapseWhitespace(subjectName);
  if (subj && normalizeForMatch(cls).startsWith(normalizeForMatch(subj))) {
    return collapseWhitespace(cls.slice(subj.length));
  }
  return cls;
}

/** Remove a trailing teacher token from a (roster-free) class label. */
export function stripTeacherSuffix(label: string, teacherName: string | null | undefined): string {
  if (!teacherName) return collapseWhitespace(label);
  const tokens = collapseWhitespace(label).split(" ").filter(Boolean);
  const teacher = collapseWhitespace(teacherName);
  if (tokens.length > 0 && tokens[tokens.length - 1] === teacher) tokens.pop();
  return tokens.join(" ");
}

/** Stable short id from a canonical key — deterministic across development resets. */
export function shortHash(input: string): string {
  // FNV-1a 64-bit folded to 12 hex chars: no crypto needed for an identifier,
  // and node:crypto stays out of the pure normalization layer.
  let h1 = 0x811c9dc5;
  let h2 = 0x01000193;
  for (let i = 0; i < input.length; i++) {
    const c = input.charCodeAt(i);
    h1 = Math.imul(h1 ^ c, 0x01000193) >>> 0;
    h2 = Math.imul(h2 ^ c, 0x811c9dc5) >>> 0;
  }
  return (h1.toString(16).padStart(8, "0") + h2.toString(16).padStart(8, "0")).slice(0, 12);
}
