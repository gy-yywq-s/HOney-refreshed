```text
/make-plan Refine HOney Ionic Web/PWA based on a Dieter Rams audit (total 27/30).

Verdict paragraph (quoted from 03-verdict.md):
> REFINE: R4 reaches 27/30, clears the numeric gate, and closes the last audited truth contradiction, so the candidate is accepted for commit, push and development deployment while admin-language clarity and authenticated bundle weight remain non-blocking refinement opportunities.

Keep (already strong, do NOT touch in this pass):
- Principle #2 (useful) scored 3 — Evidence: R4 changes no route/control and current Home/Feed/Explore paths remain direct (`DESIGN-IS-2026-09-01-R4/01-evidence.md#structural-lane`). Regression check: preserve immediate Now/Next, direct actions, feed-first default and complete finite lists.
- Principle #3 (aesthetic) scored 3 — Evidence: six unchanged-layout regression images retain one visual system (`docs/web/evidence/ionic-fidelity/r3-candidate/`). Regression check: preserve type/color/spacing/alignment and terminal clearances.
- Principle #5 (unobtrusive) scored 3 — Evidence: initial overlays remain zero and settled idle motion is zero (`DESIGN-IS-2026-09-01-R4/01-evidence.md#visual-lane`). Regression check: add no ambient motion, banner, modal, badge or decorative layer.
- Principle #6 (honest) scored 3 — Evidence: Settings now states session-plus-key truth and integrity assertions reject every prior overclaim (`apps/web-ionic/src/pages/SettingsPage.tsx:83-87`, `apps/web-ionic/src/lib/copyIntegrity.test.ts:45-94`). Regression check: `audit:copy`, integrity tests and grep must continue to find zero shipped high-risk mismatch.
- Principle #7 (long-lasting) scored 3 — Evidence: neutral type, cool palette, hairlines and standard controls (`apps/web-ionic/src/styles/tokens.css:13-70`). Regression check: introduce no trend font, gradient, glass effect, illustration or ornamental animation.
- Principle #8 (thorough) scored 3 — Evidence: all six states, AA contrast, 44px targets, focus and terminal details remain represented (`DESIGN-IS-2026-09-01-R4/01-evidence.md#accessibility-lane`). Regression check: preserve every state and accessibility floor.
- Principle #10 (as little design as possible) scored 3 — Evidence: R4 adds no visible element or step (`DESIGN-IS-2026-09-01-R4/01-evidence.md#structural-lane`). Regression check: persistent route/control count must not increase.

Fix in priority order (top 3–5 moves from the audit, verbatim):
1. Principle #4 — Understandable: Replace admin-facing `Moderation LLM`, `sealed at rest`, `entity key`, and `Reaction count threshold` labels with plain operational wording while retaining technical detail in secondary text. Evidence: `apps/web-ionic/src/pages/DashPage.tsx:100,400-401,493-496,586-601`.
2. Principle #9 — Environmentally friendly: Reduce the authenticated initial App path below 500 KiB raw without weakening the public/auth split or Ionic behavior. Evidence: authenticated App 970.93 KiB raw / 214.70 KiB gzip plus shared entry 153.58/49.54 KiB (`DESIGN-IS-2026-09-01-R4/01-evidence.md#weight-and-friction-lane`).
3. Principle #9 — Environmentally friendly: Add a reproducible authenticated cold-load performance gate that records exact request count, TTI/INP and parsed JS, because R4 intentionally contains no current runtime trace. Evidence: `DESIGN-IS-2026-09-01-R4/01-evidence.md#weight-and-friction-lane`.

Out of scope for this optional follow-up: blocking the current accepted development deployment; preserved `apps/web`; iOS; backend/shared API/database or product behavior; portal access; new routes/features; restyling principles already scoring 3.

Deliverables for the plan:
- Per-fix: target files, exact change, verification step
- Token/spec changes consolidated in one place
- Regression checklist for every "Keep" item above

Phase 0 documentation discovery must inspect current Dash copy, Vite/Ionic/React chunk graph, and supported lazy-loading APIs before proposing work. Admin wording changes should be direct copy edits. Performance changes must preserve public/auth separation, routes, overlays, safe areas, accessibility, offline behavior and every current truth assertion.

Final verification must include scoped lint, typecheck, 42+ tests, `audit:copy`, production build, the six visual regressions, zero idle animation, public cold path excluding authenticated App, and a reproducible authenticated network/performance trace if performance work is undertaken.

Anti-patterns to guard against (specific to REFINE):
- Blocking the accepted deployment on optional optimization
- Restyling areas already scoring 3
- Reintroducing abstract user-facing privacy language
- Claiming raw-parse improvement from gzip numbers alone
- Loading authenticated Ionic code on the public doorway
- Inventing unsupported manualChunks boundaries
```
