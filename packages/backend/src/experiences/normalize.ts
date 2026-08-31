// Deterministic text normalization for the moderation pipeline (App A §15).
// Runs BEFORE both the lexical layer and the LLM: evasion via confusables,
// zero-width characters or spacing must collapse to the plain form.

const ZERO_WIDTH = /[​-‏⁠﻿­]/g;

/** Common Latin confusable substitutions used to dodge lexicons. */
const CONFUSABLES: Record<string, string> = {
  "0": "o", "1": "i", "3": "e", "4": "a", "5": "s", "7": "t", "8": "b",
  "@": "a", "$": "s", "!": "i", "|": "i",
  "а": "a", "е": "e", "о": "o", "р": "p", "с": "c", "х": "x", // Cyrillic lookalikes
};

export interface NormalizedText {
  /** Original, byte-for-byte — what gets published if compliant (raw-first). */
  original: string;
  /** Casefolded, zero-width-stripped; digits INTACT (phone/id patterns need them). */
  folded: string;
  /** folded + confusable substitution (l33t/Cyrillic) — for slur matching. */
  deleeted: string;
  /** deleeted with all non-letter/digit removed — catches s p a c e d slurs. */
  squeezed: string;
}

export function normalizeText(input: string): NormalizedText {
  const original = input;
  const folded = input.normalize("NFKC").replace(ZERO_WIDTH, "").toLowerCase();
  const deleeted = folded.replace(/[0134578@$!|аеорсх]/g, (c) => CONFUSABLES[c] ?? c);
  const squeezed = deleeted.replace(/[^\p{L}\p{N}]/gu, "");
  return { original, folded, deleeted, squeezed };
}

/** Cheap URL/markup detector (embedded links are a moderation feature, not a hard block). */
export function containsUrl(text: string): boolean {
  return /https?:\/\/|www\.[a-z0-9]/i.test(text);
}
