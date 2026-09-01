import type { NormalizedText } from "./normalize.js";

// Deterministic lexical layer (App A §15.2): hard, cheap, pre-LLM. Matches on
// `folded` directly and on a squeezed projection of `deleeted`, so spacing and
// confusable evasion still hit. The seed set is intentionally structural — the
// versioned regression corpus (App A §24/§26) is where coverage grows; every
// addition bumps POLICY_VERSION.

export type LexicalFlag =
  | "slur_or_dehumanizing"
  | "direct_threat"
  | "doxxing_pattern"
  | "sexual_minor_context";

interface Rule {
  flag: LexicalFlag;
  /** Tested against `folded` (digits intact — phone/id/threat wording). */
  pattern?: RegExp;
  /** Tested against the squeezed projection of `deleeted`, word-bounded on `folded` (spacing/l33t-proof). */
  squeezedPattern?: RegExp;
}

const RULES: Rule[] = [
  // Direct threats of violence.
  { flag: "direct_threat", pattern: /\b(i('|)ll|i will|gonna|going to)\s+(kill|hurt|beat up|stab|shoot)\s+(you|him|her|them|mr|ms|mrs)\b/ },
  { flag: "direct_threat", pattern: /(打死你|弄死你|杀了(你|他|她|老师))/ },
  // Doxxing: phone numbers, home-address markers, national-id shapes.
  { flag: "doxxing_pattern", pattern: /\b1[3-9]\d{9}\b/ }, // CN mobile
  { flag: "doxxing_pattern", pattern: /\b\d{17}[\dx]\b/ }, // CN national id
  { flag: "doxxing_pattern", pattern: /(家住|home address|lives at)\s*\S+/ },
  // Slur/dehumanizing seeds (squeezed over deleeted, so spacing AND l33t both collapse).
  { flag: "slur_or_dehumanizing", squeezedPattern: /(nigg(er|a)s?|fagg?ots?|retard(ed)?s?|chinks?|spics?|kikes?)/ },
  { flag: "slur_or_dehumanizing", pattern: /(去死|畜生|贱人|婊子)/ },
  // Sexualized content involving minors — absolute block.
  { flag: "sexual_minor_context", pattern: /\b(sex|nude|naked)\b.{0,40}\b(student|minor|kid|child)\b/ },
];

// Squeezing strips every separator, so a bare substring test would also hit
// benign words that merely CONTAIN a blocked term. Instead, map each squeezed
// match back to its code-unit span and require a word boundary (string edge or
// non-letter/digit) on both sides. Three subtleties:
//   * The squeezed stream is built from `deleeted` (confusables INSIDE a term
//     still count), but boundary NEIGHBOURS are judged on `folded` — the
//     pre-deleet text. Judged on `deleeted`, trailing confusable punctuation
//     would deleet into a letter neighbour and un-flag a real match. Deleet
//     maps one code unit to one code unit, so `deleeted` and `folded` indices
//     always coincide.
//   * Neighbours are read as whole code points, never lone UTF-16 units, so an
//     astral-plane letter beside a match is judged as the letter it is.
//   * On boundary rejection, scanning resumes ONE code unit past the match
//     START (after first re-testing shorter same-start candidates): a greedy
//     optional suffix may have swallowed the head of an overlapping candidate
//     (e.g. two adjacent terms joined by squeezing), which a resume past the
//     match END would skip forever.
const WORD_CHAR = /[\p{L}\p{N}]/u; // mirrors the squeeze filter below

function codePointBefore(s: string, index: number): string | undefined {
  if (index <= 0) return undefined;
  const low = s.charCodeAt(index - 1);
  if (low >= 0xdc00 && low <= 0xdfff && index >= 2) {
    const high = s.charCodeAt(index - 2);
    if (high >= 0xd800 && high <= 0xdbff) return s.slice(index - 2, index);
  }
  return s[index - 1];
}

function codePointStartingAt(s: string, index: number): string | undefined {
  if (index >= s.length) return undefined;
  return String.fromCodePoint(s.codePointAt(index)!);
}

function squeezedRuleHits(text: NormalizedText, pattern: RegExp): boolean {
  const { folded, deleeted } = text;
  const map: number[] = []; // squeezed code-unit index → folded/deleeted code-unit index
  let squeezed = "";
  let at = 0;
  for (const ch of deleeted) {
    if (WORD_CHAR.test(ch)) {
      for (let k = 0; k < ch.length; k += 1) map.push(at + k);
      squeezed += ch;
    }
    at += ch.length;
  }

  const boundaryOk = (index: number, length: number): boolean => {
    const start = map[index];
    const end = map[index + length - 1];
    if (start === undefined || end === undefined) return false; // unreachable: map covers all of squeezed
    const before = codePointBefore(folded, start);
    const after = codePointStartingAt(folded, end + 1);
    return (before === undefined || !WORD_CHAR.test(before)) && (after === undefined || !WORD_CHAR.test(after));
  };

  const scanner = new RegExp(pattern.source, pattern.flags.includes("g") ? pattern.flags : pattern.flags + "g");
  const anchored = new RegExp(`^(?:${pattern.source})$`, pattern.flags.replace(/g/g, ""));
  let m: RegExpExecArray | null;
  while ((m = scanner.exec(squeezed)) !== null) {
    if (boundaryOk(m.index, m[0].length)) return true;
    // The greedy match may have overrun the true span — re-test every shorter
    // candidate at the same start before moving one code unit forward.
    for (let len = m[0].length - 1; len >= 1; len -= 1) {
      if (anchored.test(squeezed.slice(m.index, m.index + len)) && boundaryOk(m.index, len)) return true;
    }
    scanner.lastIndex = m.index + 1;
  }
  return false;
}

export function lexicalScan(text: NormalizedText): LexicalFlag[] {
  const flags = new Set<LexicalFlag>();
  for (const rule of RULES) {
    if (rule.pattern?.test(text.folded)) flags.add(rule.flag);
    if (rule.squeezedPattern && squeezedRuleHits(text, rule.squeezedPattern)) flags.add(rule.flag);
  }
  return [...flags];
}
