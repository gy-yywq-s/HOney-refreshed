# How moderation handles your text — external LLM processing truth

Review v3 §12.15E: `check` never writing the HOney database does NOT mean the
candidate text never leaves HOney infrastructure. This file is the deployment
truth the user-facing copy must stay inside.

## What actually happens (as implemented)

1. `POST /api/experiences/check` runs a deterministic lexicon scan locally.
   If a lexical finding fires, the LLM is never called — the text does not
   leave the server.
2. Otherwise the candidate text — the text ONLY, with no account identity,
   no school identity, no target metadata attached — is sent over TLS to
   **OpenRouter** (`openrouter.ai/api/v1`), which routes it to the
   configured model: default `mistralai/mistral-small-3.2-24b-instruct`,
   fallback `deepseek/deepseek-v4-flash` after two failed attempts (the
   fallback is a DIFFERENT model/processor — an outage changes who processes
   the text).
3. The model returns boolean features; the deterministic engine decides.
   HOney persists neither the text nor the features at check time.
4. A report re-evaluation (`§12.15B`) re-runs the same pipeline on the
   already-public body — the same external processing applies.

## What HOney can and cannot promise

- HOney sends no identity with the text. But the text itself may contain
  whatever the student typed — that content reaches the provider verbatim.
- Retention/logging at OpenRouter and the underlying model vendors is
  governed by THEIR policies. HOney has **not** verified or purchased a
  contractual no-retention tier. Copy must therefore never claim "your text
  is never stored anywhere" — the honest claim is "HOney does not store your
  text at check time; an external moderation processor sees it transiently,
  under its own retention policy."
- Region/subprocessor routing is OpenRouter's; HOney does not pin a region.

## Deployment decision (dev stage, 2026-09-01)

Accepted for the dev deployment. Before public launch: either (a) verify and
enable a no-retention/privacy mode with the provider and record evidence
here, or (b) keep the current setup and make sure the user-facing
"How moderation handles your text" copy states it plainly. Tracked as a
launch gate, not silently.

## User-facing surface

`Settings → How privacy works` links this truth in plain words; the composer
footnote points at the same section. Never bury this in marketing copy.
