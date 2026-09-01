import type { LexicalFlag } from "./lexicon.js";
import type { LlmFeatures } from "./llm.js";

// The DETERMINISTIC policy engine (App A §16.3): given lexical flags + LLM
// features, it — and only it — chooses the action state. The signing service
// accepts nothing but this engine's output. No single confidence scalar; every
// serious lane fails closed.

export const POLICY_VERSION = 5;

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

export function decide(input: PolicyInput): PolicyDecision {
  const reasons: string[] = [];

  // 1. Deterministic hard blocks — the LLM cannot override these.
  if (input.lexical.includes("sexual_minor_context") || input.lexical.includes("direct_threat")) {
    return { action: "blocked_serious", reasons: ["lexical:" + input.lexical.join(",")], policyVersion: POLICY_VERSION };
  }
  if (input.lexical.includes("slur_or_dehumanizing")) {
    return { action: "blocked_serious", reasons: ["lexical:slur"], policyVersion: POLICY_VERSION };
  }
  if (input.lexical.includes("doxxing_pattern")) {
    return { action: "blocked_out_of_scope", reasons: ["lexical:doxxing"], policyVersion: POLICY_VERSION };
  }

  // 2. Rating discipline: scalar ratings exist ONLY for dishes (App A §8.2).
  if (input.hasRating && input.entityType !== "dish") {
    return { action: "rephrase_required", reasons: ["rating_not_allowed_for_entity"], policyVersion: POLICY_VERSION };
  }

  // 3. Extractor outage/invalid output → fail closed (§16.5): save privately,
  // never publish-first-inspect-later.
  if (!input.llm) {
    return { action: "failed_closed", reasons: ["llm_unavailable"], policyVersion: POLICY_VERSION };
  }
  const f = input.llm;

  // 4. Serious / out-of-scope lanes (§13.5–13.6): block even if possibly true.
  if (f.slur_or_dehumanizing) {
    return { action: "blocked_serious", reasons: ["llm:slur_or_dehumanizing"], policyVersion: POLICY_VERSION };
  }
  if (f.serious_allegation) {
    return { action: "blocked_out_of_scope", reasons: ["llm:serious_allegation"], policyVersion: POLICY_VERSION };
  }
  if (f.targets_student) {
    return { action: "blocked_out_of_scope", reasons: ["llm:targets_student"], policyVersion: POLICY_VERSION };
  }
  if (f.privacy_invasion) {
    return { action: "blocked_out_of_scope", reasons: ["llm:privacy_invasion"], policyVersion: POLICY_VERSION };
  }

  // 5. Correctable violations → ask for a direct rephrase (§13.4, EDIT_REQUIRED):
  // hearsay stated as fact, profanity aimed at a person, or a manipulation attempt.
  if (f.hearsay) {
    return { action: "rephrase_required", reasons: ["llm:hearsay"], policyVersion: POLICY_VERSION };
  }
  if (f.targeted_profanity) {
    return { action: "rephrase_required", reasons: ["llm:targeted_profanity"], policyVersion: POLICY_VERSION };
  }
  if (f.injection_attempt) {
    return { action: "rephrase_required", reasons: ["llm:injection_attempt"], policyVersion: POLICY_VERSION };
  }
  // Unresolved semantic uncertainty → rephrase directly (§13.7 UNCERTAIN_REPHRASE),
  // distinct from an extractor OUTAGE (llm:null above) which is failed_closed.
  if (f.uncertain) {
    return { action: "rephrase_required", reasons: ["llm:uncertain"], policyVersion: POLICY_VERSION };
  }

  // 6. High-arousal ordinary opinion → 24 h private cooldown with reconfirm (§13.3).
  if (f.high_arousal) {
    return { action: "cooldown_24h", reasons: ["llm:high_arousal"], policyVersion: POLICY_VERSION };
  }

  // 7. Low-harm vague content → publish, but with an OPTIONAL nudge to add a
  // detail (§13.2 / §27.7). It still publishes; the nudge is advisory only.
  if (f.low_information) {
    return { action: "publish_nudge", reasons: ["llm:low_information"], policyVersion: POLICY_VERSION };
  }

  // 8. Ordinary content — publish.
  return { action: "publish", reasons, policyVersion: POLICY_VERSION };
}
