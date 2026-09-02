# Acceptance — current (facts only)

> Regenerate this file from measurements; never hand-edit claims that live elsewhere. History
> and narrative: `docs/status/acceptance-history.md`. Source-of-truth hierarchy:
> `docs/product/product-and-style-constitution.md`.

| Fact | Value | How measured |
|---|---|---|
| Working branch / live deploy | `integration/product-v2` @ HEAD; honey.gaelisus.com runs the latest green commit | `git log -1`, deploy checkout `/home/honey/app` |
| Tests | backend 125 pass / 23 live-gated; web 26; shared 3; connector 17 | `pnpm -r test` |
| Policy version / corpus | `POLICY_VERSION` 7, ordered Standing → Expression → Scope → Timing | `packages/backend/src/experiences/policy.ts`, `corpus/regression.json` |
| Report re-evaluation | tri-state (violation hides; allowed keeps; unavailable keeps + retries every 10 min) | `service.ts` `reevaluate()` / `processPendingReevaluations()` |
| Live portal probe | school test account signs in and syncs (126 lessons) | `POST /api/sync` via the audit harness |
| Design audit (web) | design-is r9 = 18/30 (REDESIGN by the <20 rule; ties on #8/#9); loop paused for the product-review pass; r9 handoff pending | `docs/research/design-audits/design-is-2026-09-01-r9/` |
| Design status | web + iOS `experimental_not_approved` (owner approval is a separate state) | `docs/status/current.md` |
| Served CSS | parses clean (`scripts/check-css.mjs` in the build) | `pnpm build` |
| Launch blockers (recorded) | HttpOnly cookie sessions + CSRF; LLM provider retention verification; protocol unlinkability (Option B) | `docs/status/current.md` |
