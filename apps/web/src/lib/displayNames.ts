// Human display of the school portal's raw labels (review v1.1 §6.6): a
// portal course string such as
//   "CIE Chinese Language & Literature 2026秋CIEAL中文备考班 赵流畅"
// is one administrative concatenation — subject, term + class code + class
// type, teacher — with no separators. The domain keeps the raw string (it is
// the identity the portal uses); presentation splits it ONCE here into a
// title and secondary metadata, so no screen has to compensate with type
// size or CSS overflow. Deterministic and reversible: nothing is invented.

export interface CourseDisplay {
  /** "CIE Chinese Language & Literature" */
  title: string;
  /** "2026 Autumn · 中文备考班 · 赵流畅" — empty when the raw name had no term token. */
  meta: string;
}

const SEASONS: Record<string, string> = { 春: "Spring", 夏: "Summer", 秋: "Autumn", 冬: "Winter" };
const TERM = /^(20\d\d)年?([春夏秋冬])/;
const CJK_RUN = /[㐀-鿿][㐀-鿿0-9A-Za-z]*班?/g;

export function parseCourseName(raw: string, teacherName?: string | null): CourseDisplay {
  const tokens = raw.trim().split(/\s+/);
  const termAt = tokens.findIndex((t) => TERM.test(t));
  if (termAt <= 0) return { title: raw.trim(), meta: "" };
  const title = tokens.slice(0, termAt).join(" ");
  const rest = tokens.slice(termAt);
  const m = TERM.exec(rest[0]!)!;
  const term = `${m[1]} ${SEASONS[m[2]!] ?? m[2]}`;
  // The teacher is the last token when it matches the known name, or when it
  // carries no digits and is not the term token itself.
  let teacher = "";
  const last = rest[rest.length - 1]!;
  if (rest.length > 1 && (last === teacherName || !/\d/.test(last))) {
    teacher = last;
    rest.pop();
  }
  // Class type: the CJK run(s) after the season, e.g. 中文备考班 / 强化班 / 活动课.
  const afterSeason = [rest[0]!.slice(m[0].length), ...rest.slice(1)].join(" ");
  const runs = afterSeason.match(CJK_RUN) ?? [];
  const classType = runs.map((r) => r.replace(/^[0-9A-Za-z]+/, "")).filter(Boolean).join(" ");
  const meta = [term, classType, teacher].filter(Boolean).join(" · ");
  return { title, meta };
}

/** The human title of a course entity name; other entity types pass through. */
export function entityTitle(type: string, name: string): string {
  return type === "course" ? parseCourseName(name).title : name;
}

/** Secondary line for a course entity; empty for everything else. */
export function entityMeta(type: string, name: string): string {
  return type === "course" ? parseCourseName(name).meta : "";
}

/** "Room 309" — a bare room number gets the word; a named place keeps its name. */
export function roomLabel(room: string | null | undefined): string {
  if (!room) return "";
  return /^[0-9]+[A-Za-z]?$/.test(room.trim()) ? `Room ${room.trim()}` : room;
}
