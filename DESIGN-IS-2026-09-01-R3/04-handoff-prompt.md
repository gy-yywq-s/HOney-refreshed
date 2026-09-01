```text
/make-plan Refine HOney Ionic Web/PWA based on a Dieter Rams audit (total 26/30).

Verdict paragraph (quoted from 03-verdict.md):
> REFINE: R3 reaches 26/30 and clears the numeric quality gate with the targeted honesty defects substantially corrected, but one contradictory key-only account-deletion sentence must be fixed before deployment and authenticated bundle weight remains the principal non-blocking quality risk.

Keep (already strong, do NOT touch in this pass):
- Principle #2 (useful) scored 3 — Evidence: current Home/Feed/Explore task paths remain direct and R3 adds no control or step (`apps/web-ionic/src/pages/HomePage.tsx:52-150`, `apps/web-ionic/src/pages/experiences/FeedPage.tsx:51-160`, `apps/web-ionic/src/pages/experiences/ExplorePage.tsx:31-167`). Regression check: confirm immediate Now/Next, direct Timetable/Share, feed-first default and complete finite lists.
- Principle #3 (aesthetic) scored 3 — Evidence: `docs/web/evidence/ionic-fidelity/r3-candidate/` retains one visual system and renders the longer Compose disclosure without overlap. Regression check: repeat the six images and require unchanged alignment, type/color tokens and terminal clearances.
- Principle #5 (unobtrusive) scored 3 — Evidence: disclosure stays inline, content remains dominant and idle animation remains zero (`apps/web-ionic/src/styles/features.css:78-100,331-354`). Regression check: no new overlay, banner, badge, decorative layer or ambient motion.
- Principle #7 (long-lasting) scored 3 — Evidence: neutral type, cool palette, hairlines and standard controls (`apps/web-ionic/src/styles/tokens.css:13-70`). Regression check: no trend font, gradient, glass effect, illustration or ornamental animation.
- Principle #8 (thorough) scored 3 — Evidence: all six states plus AA contrast, 44px targets, focus and terminal geometry remain represented (`DESIGN-IS-2026-09-01-R3/01-evidence.md#accessibility-lane`). Regression check: preserve each state and accessibility floor.
- Principle #10 (as little design as possible) scored 3 — Evidence: R3 adds no visible element or step (`DESIGN-IS-2026-09-01-R3/01-evidence.md#structural-lane`). Regression check: persistent route/control count must not increase.

Fix in priority order (top 3–5 moves from the audit, verbatim):
1. Principle #6 — Honest: Replace the Settings account-deletion summary's `controlled only by the keys on your devices` with the same session-plus-post-control-key truth used in the detailed section and Mine, then add that exact sentence to the integrity assertions. Evidence: `apps/web-ionic/src/pages/SettingsPage.tsx:83-86,201-216` and `apps/web-ionic/src/pages/experiences/MinePage.tsx:148-154`.
2. Principle #4 — Understandable: Replace admin-facing `Moderation LLM`, `sealed at rest`, `entity key`, and `Reaction count threshold` labels with plain operational wording while retaining precise technical detail in secondary copy. Evidence: `apps/web-ionic/src/pages/DashPage.tsx:100,400-401,493-496,586-601`.
3. Principle #9 — Environmentally friendly: Reduce the authenticated initial App path below 500 KiB raw without weakening the public/auth split, and record a real signed-in cold-load waterfall plus TTI/INP evidence. Evidence: current build App = 970.93 KiB raw / 214.71 KiB gzip plus entry 153.58/49.54 KiB (`DESIGN-IS-2026-09-01-R3/01-evidence.md#weight-and-friction-lane`).

Out of scope for this refine pass: preserved `apps/web`; iOS; backend/shared API/database or product-behavior changes; portal access; brand replacement; new routes/features; visual restyling of principles already scoring 3; deployment before the truth sentence is corrected.

Deliverables for the plan:
- Per-fix: target files, exact change, verification step
- Token/spec changes consolidated in one place
- Regression checklist for every "Keep" item above

Phase 0 documentation discovery must inspect the current copy-inventory/test generator, Settings/Dash source, current Vite chunk graph, and supported React/Vite/Ionic lazy-loading patterns. The truth correction is a direct copy-and-test edit; do not change backend behavior to preserve an inaccurate label. Admin wording must remain operationally exact. Performance work must preserve the public/auth boundary, all route semantics, Ionic overlay/safe-area behavior, accessibility and offline behavior.

Final verification must include scoped lint, typecheck, 42+ tests, `audit:copy`, production build, grep proving the contradictory key-only sentence is gone from shipped copy, integrity assertions for session-plus-key truth, the six R3 visual regressions, zero idle animation, public cold path excluding authenticated App, and a real authenticated cold-load performance trace if the bundle task is undertaken.

Anti-patterns to guard against (specific to REFINE):
- Adding abstractions for a one-sentence truth correction
- Changing privacy/backend behavior instead of correcting the label
- Restyling areas already scoring 3
- Reintroducing abstract jargon without a plain explanation
- Claiming a raw-parse win from gzip numbers alone
- Loading authenticated Ionic code on the public doorway
```
