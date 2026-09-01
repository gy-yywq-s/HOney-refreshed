import type { NormalizedText } from "./normalize.js";

// Deterministic lexical layer (App A §15.2): hard, cheap, pre-LLM. Matches on
// the folded/squeezed forms so spacing/confusable evasion still hits. The seed
// set is intentionally structural — the versioned regression corpus (App A
// §24/§26) is where coverage grows; every addition bumps POLICY_VERSION.

export type LexicalFlag =
  | "slur_or_dehumanizing"
  | "direct_threat"
  | "doxxing_pattern"
  | "sexual_minor_context";

interface Rule {
  flag: LexicalFlag;
  /** Tested against `folded` (digits intact — phone/id/threat wording). */
  pattern?: RegExp;
  /** Tested against `deleeted` (confusables collapsed — slur wording). */
  deleetedPattern?: RegExp;
  /** Tested against the squeezed projection of `deleeted`, word-bounded (spacing-proof). */
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
  // Slur/dehumanizing seeds (deleeted + squeezed to defeat l33t and spacing).
  { flag: "slur_or_dehumanizing", squeezedPattern: /(nigg(er|a)s?|fagg?ots?|retard(ed)?s?|chinks?|spics?|kikes?)/ },
  { flag: "slur_or_dehumanizing", deleetedPattern: /(?<![\p{L}\p{N}])(retard(ed)?s?|nigg(er|a)s?)(?![\p{L}\p{N}])/u },
  { flag: "slur_or_dehumanizing", pattern: /(去死|畜生|贱人|婊子)/ },
  // Sexualized content involving minors — absolute block.
  { flag: "sexual_minor_context", pattern: /\b(sex|nude|naked)\b.{0,40}\b(student|minor|kid|child)\b/ },
];

// Squeezing strips every separator, so a bare substring test would also hit
// benign words that merely CONTAIN a blocked term. Instead, map each squeezed
// match back to its span in `deleeted` and require a word boundary (string
// edge or non-letter/digit) on both sides THERE. Spacing/punctuation/emoji
// evasion still hits: those separators fall INSIDE the span, never at its
// edges — only an unbroken longer word supplies letter neighbours.
const WORD_CHAR = /[\p{L}\p{N}]/u; // mirrors the squeeze step in normalize.ts

function squeezedRuleHits(deleeted: string, pattern: RegExp): boolean {
  const map: number[] = []; // squeezed code-unit index → deleeted code-unit index
  let squeezed = "";
  let at = 0;
  for (const ch of deleeted) {
    if (WORD_CHAR.test(ch)) {
      for (let k = 0; k < ch.length; k += 1) map.push(at + k);
      squeezed += ch;
    }
    at += ch.length;
  }
  const flags = pattern.flags.includes("g") ? pattern.flags : pattern.flags + "g";
  for (const m of squeezed.matchAll(new RegExp(pattern.source, flags))) {
    const start = map[m.index];
    const end = map[m.index + m[0].length - 1];
    if (start === undefined || end === undefined) continue; // unreachable: map covers all of squeezed
    const before = deleeted[start - 1];
    const after = deleeted[end + 1];
    if ((before === undefined || !WORD_CHAR.test(before)) && (after === undefined || !WORD_CHAR.test(after))) {
      return true;
    }
  }
  return false;
}

export function lexicalScan(text: NormalizedText): LexicalFlag[] {
  const flags = new Set<LexicalFlag>();
  for (const rule of RULES) {
    if (rule.pattern?.test(text.folded)) flags.add(rule.flag);
    if (rule.deleetedPattern?.test(text.deleeted)) flags.add(rule.flag);
    if (rule.squeezedPattern && squeezedRuleHits(text.deleeted, rule.squeezedPattern)) flags.add(rule.flag);
  }
  return [...flags];
}
