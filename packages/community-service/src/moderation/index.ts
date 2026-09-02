// normalize → lexical → (LLM unless lexical hard-block) → deterministic decide.
// The same pipeline the first cut ran inside Core, now inside the identity-free
// Community process: the moderation model receives the text only — never an
// authorTag, a key, or anything about who wrote it.

import { lexicalScan } from "./lexicon.js";
import { extractFeatures, type LlmVerdict } from "./llm.js";
import { normalizeText } from "./normalize.js";
import { decide, type PolicyDecision } from "./policy.js";

export type LlmRunner = (text: string) => Promise<LlmVerdict>;

export async function computeDecision(body: string, entityType: string, rating: number | null, llm: LlmRunner): Promise<PolicyDecision> {
  const normalized = normalizeText(body);
  const lexical = lexicalScan(normalized);
  if (lexical.length > 0) return decide({ lexical, llm: null, entityType, hasRating: rating !== null });
  const verdict = await llm(normalized.original);
  return decide({ lexical, llm: verdict.ok && verdict.features ? verdict.features : null, entityType, hasRating: rating !== null });
}

export function defaultLlmRunner(config: () => { apiKey: string; model: string; timeoutMs: number } | null): LlmRunner {
  return async (text) => {
    const c = config();
    if (!c) return { ok: false };
    return extractFeatures(text, c);
  };
}

export { POLICY_VERSION } from "./policy.js";
export type { PolicyDecision } from "./policy.js";
