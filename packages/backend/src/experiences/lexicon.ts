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
  /** Tested against `squeezed` (spacing-proof). */
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
  { flag: "slur_or_dehumanizing", squeezedPattern: /(nigg(er|a)|fagg?ot|retard(ed)?|chink|spic|kike)/ },
  { flag: "slur_or_dehumanizing", deleetedPattern: /(retard|nigg(er|a))/ },
  { flag: "slur_or_dehumanizing", pattern: /(去死|畜生|贱人|婊子)/ },
  // Sexualized content involving minors — absolute block.
  { flag: "sexual_minor_context", pattern: /\b(sex|nude|naked)\b.{0,40}\b(student|minor|kid|child)\b/ },
];

export function lexicalScan(text: NormalizedText): LexicalFlag[] {
  const flags = new Set<LexicalFlag>();
  for (const rule of RULES) {
    if (rule.pattern?.test(text.folded)) flags.add(rule.flag);
    if (rule.deleetedPattern?.test(text.deleeted)) flags.add(rule.flag);
    if (rule.squeezedPattern?.test(text.squeezed)) flags.add(rule.flag);
  }
  return [...flags];
}
