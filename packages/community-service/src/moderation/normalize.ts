// Deterministic text normalization for the moderation pipeline (App A §15).
// Runs BEFORE both the lexical layer and the LLM: evasion via confusables or
// zero-width characters must collapse to the plain form. (Spacing evasion is
// defeated downstream: the lexical layer squeezes `deleeted` itself, so it can
// map every match back to positions in the text produced here.)

const ZERO_WIDTH = /[​-‏⁠﻿­]/g;

/**
 * Common Latin confusable substitutions used to dodge lexicons. Every entry
 * maps ONE code unit to ONE code unit — the lexical layer relies on `deleeted`
 * and `folded` staying index-aligned.
 */
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
  /**
   * folded + confusable substitution (l33t/Cyrillic) — for slur matching.
   * Index-aligned with `folded`, so word boundaries can be judged on the
   * pre-deleet text.
   */
  deleeted: string;
}

export function normalizeText(input: string): NormalizedText {
  const original = input;
  const folded = input.normalize("NFKC").replace(ZERO_WIDTH, "").toLowerCase();
  const deleeted = folded.replace(/[0134578@$!|аеорсх]/g, (c) => CONFUSABLES[c] ?? c);
  return { original, folded, deleeted };
}

/** Cheap URL/markup detector (embedded links are a moderation feature, not a hard block). */
export function containsUrl(text: string): boolean {
  return /https?:\/\/|www\.[a-z0-9]/i.test(text);
}
