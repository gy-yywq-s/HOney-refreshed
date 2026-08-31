import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";
import { lexicalScan } from "./lexicon.js";
import { normalizeText } from "./normalize.js";
import { decide, POLICY_VERSION } from "./policy.js";
import { extractFeatures, DEFAULT_LLM_MODEL, type LlmFeatures } from "./llm.js";

// Regression + adversarial corpus runner (App A §24/§26). The deterministic
// halves run in CI always; the live LLM half runs only when OPENROUTER_API_KEY
// is set (so CI stays hermetic while the real model is still exercised locally).

interface Corpus {
  policyVersion: number;
  lexical: { id: string; text: string; expect: string; reason?: string }[];
  features: { id: string; features: Partial<LlmFeatures> | null; expect: string; reason?: string }[];
  live: { id: string; text: string; expectPublishable: boolean }[];
}

const corpus: Corpus = JSON.parse(
  readFileSync(fileURLToPath(new URL("./corpus/regression.json", import.meta.url)), "utf8"),
);

const CLEAN: LlmFeatures = {
  serious_allegation: false,
  targets_student: false,
  slur_or_dehumanizing: false,
  privacy_invasion: false,
  high_arousal: false,
  hearsay: false,
  targeted_profanity: false,
  low_information: false,
  injection_attempt: false,
  uncertain: false,
};

describe("regression corpus — deterministic layers", () => {
  it("corpus is pinned to the current policy version", () => {
    expect(corpus.policyVersion).toBe(POLICY_VERSION);
  });

  it.each(corpus.lexical)("lexical: $id → $expect ($reason)", (c) => {
    const flags = lexicalScan(normalizeText(c.text));
    expect(flags.length).toBeGreaterThan(0); // must be caught WITHOUT the LLM
    const decision = decide({ lexical: flags, llm: null, entityType: "lesson", hasRating: false });
    const action = decision.action === "failed_closed" ? "blocked_serious" : decision.action;
    expect(action).toBe(c.expect);
  });

  it.each(corpus.features)("features: $id → $expect ($reason)", (c) => {
    const llm = c.features === null ? null : { ...CLEAN, ...c.features };
    const entityType = c.id === "ordinary-negative" ? "lesson" : "lesson";
    expect(decide({ lexical: [], llm, entityType, hasRating: false }).action).toBe(c.expect);
  });

  // §26.2 launch gates over the deterministic corpus.
  it("launch gate: zero serious/out-of-scope examples publish", () => {
    for (const c of corpus.lexical) {
      const flags = lexicalScan(normalizeText(c.text));
      const action = decide({ lexical: flags, llm: null, entityType: "lesson", hasRating: false }).action;
      expect(action).not.toBe("publish");
    }
    for (const c of corpus.features.filter((f) => /serious|slur|student|privacy|doxx/.test(f.id))) {
      const llm = c.features === null ? null : { ...CLEAN, ...c.features };
      expect(decide({ lexical: [], llm, entityType: "lesson", hasRating: false }).action).not.toBe("publish");
    }
  });

  it("launch gate: outage fails closed (never publishes)", () => {
    expect(decide({ lexical: [], llm: null, entityType: "lesson", hasRating: false }).action).toBe("failed_closed");
  });

  it("launch gate: ordinary negative is NOT systematically blocked", () => {
    expect(decide({ lexical: [], llm: { ...CLEAN }, entityType: "lesson", hasRating: false }).action).toBe("publish");
  });
});

// Live model half — real OpenRouter, gated on the key. Uses the deterministic
// engine on top of the model's actual features to assert publishability.
const KEY = process.env.OPENROUTER_API_KEY;
describe.runIf(!!KEY)("regression corpus — live LLM", () => {
  it.each(corpus.live)("live: $id publishable=$expectPublishable", async (c) => {
    const normalized = normalizeText(c.text);
    const lexical = lexicalScan(normalized);
    let action: string;
    if (lexical.length > 0) {
      action = "blocked_serious";
    } else {
      const v = await extractFeatures(normalized.original, { apiKey: KEY!, model: DEFAULT_LLM_MODEL, timeoutMs: 12_000 });
      action = decide({
        lexical: [],
        llm: v.ok && v.features ? v.features : null,
        entityType: "lesson",
        hasRating: false,
      }).action;
    }
    const publishable = action === "publish" || action === "publish_nudge";
    expect(publishable).toBe(c.expectPublishable);
  }, 20_000);
});
