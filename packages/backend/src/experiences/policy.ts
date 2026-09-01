import type { LexicalFlag } from "./lexicon.js";
import type { LlmFeatures } from "./llm.js";

// The DETERMINISTIC policy engine. Classification is parallel (lexicon + one
// LLM feature extraction); ENFORCEMENT IS ORDERED (review v3 §11):
//
//   Standing → Expression → Scope → Timing   (composition help is not a gate)
//
//   Standing   — is this the contributor's experience to speak from?
//   Expression — can HOney carry these exact words? (judged on the current
//                text's transmission form, not on which institution should
//                handle the substance)
//   Scope      — is the substance still ordinary peer knowledge, or would
//                accepting it reasonably call for institutional action?
//   Timing     — publish now, or let the user decide again after arousal falls?
//
// The user sees only the FRONTMOST unpassed boundary: a text that is both
// targeted profanity AND a serious allegation first gets the Expression
// revision; only once the words are carriable does Scope answer. The engine —
// and only it — chooses the action; the signing service accepts nothing else.
// Every serious lane fails closed.
//
// Wire-lane names are kept stable for existing clients; the gate semantics
// live in the ordered checks below and in the gate-prefixed reason codes.

export const POLICY_VERSION = 7;

export type ActionState =
  | "publish"
  | "publish_nudge"
  | "cooldown_24h"
  | "rephrase_required"
  | "blocked_serious"
  | "blocked_out_of_scope"
  | "failed_closed";

export interface PolicyInput {
  lexical: LexicalFlag[];
  llm: LlmFeatures | null; // null → extractor outage/invalid (fail closed)
  /** Entity type of the primary entity ("dish" is the only scalar-ratable type). */
  entityType: string;
  hasRating: boolean;
}

export interface PolicyDecision {
  action: ActionState;
  reasons: string[];
  policyVersion: number;
}

function outcome(action: ActionState, ...reasons: string[]): PolicyDecision {
  return { action, reasons, policyVersion: POLICY_VERSION };
}

export function decide(input: PolicyInput): PolicyDecision {
  // Structural rating discipline (domain rule, not a moderation gate): scalar
  // ratings exist ONLY for dishes (App A §8.2).
  if (input.hasRating && input.entityType !== "dish") {
    return outcome("rephrase_required", "rating_not_allowed_for_entity");
  }

  // ---- Expression, deterministic lexical layer -----------------------------
  // All four lexical flags are Expression-gate findings on the exact wording.
  // When one fires the LLM is never consulted (cheap + fail-safe), so Standing
  // is judged on the next attempt once the words are carriable — the user
  // still sees exactly one actionable boundary at a time.
  if (input.lexical.includes("sexual_minor_context") || input.lexical.includes("direct_threat")) {
    return outcome("blocked_serious", "expression:lexical:" + input.lexical.join(","));
  }
  if (input.lexical.includes("slur_or_dehumanizing")) {
    return outcome("blocked_serious", "expression:lexical:slur");
  }
  if (input.lexical.includes("doxxing_pattern")) {
    // Contact/identifying details are an EXPRESSION problem — remove them and
    // the experience can still be told (review v3 §11.6). This is deliberately
    // no longer "out of scope": PII is not an institutional-channel matter.
    return outcome("rephrase_required", "expression:lexical:identifying_information");
  }

  // Extractor outage/invalid output → fail closed (§16.5): save privately,
  // never publish-first-inspect-later.
  if (!input.llm) {
    return outcome("failed_closed", "llm_unavailable");
  }
  const f = input.llm;

  // ---- Gate A — Standing ---------------------------------------------------
  // Rumour reported as fact is not the contributor's experience to publish.
  if (f.hearsay) {
    return outcome("rephrase_required", "standing:hearsay");
  }

  // ---- Gate B — Expression -------------------------------------------------
  if (f.slur_or_dehumanizing) {
    return outcome("blocked_serious", "expression:slur_or_dehumanizing");
  }
  if (f.targeted_profanity) {
    return outcome("rephrase_required", "expression:targeted_profanity");
  }
  if (f.targets_student) {
    // Students are not public subjects here; the wording that evaluates or
    // identifies a fellow student must go — a revision, not a scope verdict.
    return outcome("rephrase_required", "expression:targets_student");
  }
  if (f.privacy_invasion) {
    return outcome("rephrase_required", "expression:privacy_invasion");
  }
  if (f.injection_attempt) {
    return outcome("rephrase_required", "expression:injection_attempt");
  }
  // Unresolved semantic opacity → say it more directly (distinct from an
  // extractor OUTAGE, which is failed_closed above).
  if (f.uncertain) {
    return outcome("rephrase_required", "expression:uncertain");
  }

  // ---- Gate C — Scope ------------------------------------------------------
  // The words are carriable; is the substance still peer context? A serious
  // allegation may be entirely true — HOney is still not the right public
  // institution for it (investigation/safeguarding/discipline territory).
  if (f.serious_allegation) {
    return outcome("blocked_out_of_scope", "scope:serious_allegation");
  }

  // ---- Gate D — Timing -----------------------------------------------------
  // High-arousal ordinary opinion → 24 h private delay with reconfirm (§13.3).
  // Cooldown is a timing intervention, never a wrongness verdict.
  if (f.high_arousal) {
    return outcome("cooldown_24h", "timing:high_arousal");
  }

  // ---- Composition help (not a gate) ---------------------------------------
  // Low-information content publishes; the nudge is advisory only.
  if (f.low_information) {
    return outcome("publish_nudge", "composition:low_information");
  }

  return outcome("publish");
}
