```text
/make-plan Refine HOney Ionic Web/PWA based on a Dieter Rams audit (total 25/30).

Verdict paragraph (quoted from 03-verdict.md):
> REFINE: R2 reaches 25/30 and clears the numeric quality gate with the visual, structural, accessibility, and public-weight defects corrected, but the candidate still needs a narrow honesty pass because three over-absolute privacy/storage claims do not match all current behavior paths.

Keep (already strong, do NOT touch in this pass):
- Principle #2 (useful) scored 3 — Evidence: Home retains immediate Now/Next plus direct Timetable/Share paths; Feed stays default and Explore remains complete (`apps/web-ionic/src/pages/HomePage.tsx:52-150`, `apps/web-ionic/src/pages/experiences/FeedPage.tsx:51-160`, `apps/web-ionic/src/pages/experiences/ExplorePage.tsx:31-167`). Regression check: render Home/Feed/Explore and confirm no new step, decoy action, truncated finite list, or changed default route.
- Principle #3 (aesthetic) scored 3 — Evidence: `docs/web/evidence/ionic-fidelity/r2-candidate/` shows one coherent type/color/spacing system, two correct scope states, filled Compose, clear terminal geometry, and centered desktop Home. Regression check: repeat the same six screenshots and token/color inventory; require zero new orphan style or alignment break.
- Principle #5 (unobtrusive) scored 3 — Evidence: raw student words remain dominant and current Home/Timetable have no idle pulses (`apps/web-ionic/src/features/experiences/ExperiencePost.tsx:139-245`, `apps/web-ionic/src/styles/features.css:78-100,331-354`). Regression check: confirm zero idle animation and no new banner, badge, overlay, decorative layer, or content-demoting chrome.
- Principle #7 (long-lasting) scored 3 — Evidence: one neutral humanist family, restrained cool palette, hairlines and standard controls (`apps/web-ionic/src/styles/tokens.css:13-70`). Regression check: prevent new trend fonts, gradients, glass effects, illustration or ornamental motion.
- Principle #8 (thorough) scored 3 — Evidence: empty/loading/error/success/focus/disabled exist and R2 proves AA tokens, 44px targets and terminal clearances (`DESIGN-IS-2026-09-01-R2/01-evidence.md#accessibility-lane`). Regression check: retain all six states, focus rules, 44px targets, 4.5:1 text minimum and current Compose/Timetable gaps.
- Principle #10 (as little design as possible) scored 3 — Evidence: public Login omits authenticated Ionic chrome and core persistent elements remain task-bound (`apps/web-ionic/src/main.tsx:14-40`, `apps/web-ionic/src/PublicApp.tsx:1-27`, `apps/web-ionic/src/components/navTabs.tsx:17-28`). Regression check: do not add a destination, dashboard layer, duplicate action, explanatory modal, or decorative element.

Fix in priority order (top 3–5 moves from the audit, verbatim):
1. Principle #6 — Honest: Replace `never sent anywhere` / `Private notes never leave this device` with path-accurate copy that distinguishes a local private-note record from text already sent through an optional safety check; put the external-processing fact beside the Share action. Evidence: `apps/web-ionic/src/pages/experiences/ComposePage.tsx:160-168,302-305,329-351` and `apps/web-ionic/src/pages/experiences/useComposer.ts:117-132`.
2. Principle #6 — Honest: Replace every bare `Nothing was stored` / `Nothing was kept` with `Nothing was published or stored on the HOney server; your draft remains saved in this browser`, preserving the actual autosave guarantee. Evidence: `apps/web-ionic/src/pages/experiences/useComposer.ts:44-47,65-81,111-112` and `apps/web-ionic/src/pages/experiences/ComposePage.tsx:379-380`.
3. Principles #6 and #4 — Honest + Understandable: Rename `ownership key` to `post-control key` in ordinary-user copy and state the current operational truth: managing/revoking requires both a signed-in HOney session and the device-held key; replace `relevant exposure` with a plain first-hand-context explanation. Evidence: `apps/web-ionic/src/pages/SettingsPage.tsx:213-216,345-348`, `apps/web-ionic/src/pages/experiences/ComposePage.tsx:303-304`, and `apps/web-ionic/src/pages/experiences/WhyPage.tsx:63-65`.
4. Principle #9 — Environmentally friendly: Reduce the authenticated initial App path below 500 KiB raw without weakening the public/auth split or route behavior, and record a fresh signed-in cold-load chunk/waterfall measurement. Evidence: current build `App-CbaASB99.js` = 970.93 KiB raw / 214.71 KiB gzip plus 153.58/49.54 KiB shared entry (`DESIGN-IS-2026-09-01-R2/01-evidence.md#weight-and-friction-lane`).

Out of scope for this refine pass: preserved `apps/web`; iOS; backend/shared API/database changes; changing anonymity, moderation, consent, reaction or report semantics; external school portal access; brand replacement; deployment topology; adding features/destinations; visual restyling of principles already scoring 3.

Deliverables for the plan:
- Per-fix: target files, exact change, verification step
- Token/spec changes consolidated in one place
- Regression checklist for every "Keep" item above

Phase 0 documentation discovery must inspect the current local copy inventory/test pattern, actual Compose state machine, actual API client boundary, and current Vite/Ionic chunk graph before planning. Prefer direct copy corrections over new abstractions. Any performance split must cite supported Vite/Ionic/React lazy-loading APIs and preserve current routing, overlays, safe areas, accessibility and offline behavior.

Final verification must include: scoped lint, typecheck, all Ionic tests, production build, `audit:copy`, focused label→behavior assertions for all corrected phrases and alternate paths, grep proving the over-absolute phrases are gone, the six R2 visual regression screenshots, zero idle animation, public cold path still excluding authenticated App, and an R3 Design-Is pass focused on #4/#6/#9 without reusing R2 scores.

Anti-patterns to guard against (specific to REFINE):
- Adding new abstractions where a direct change suffices
- Restyling areas that already scored 3
- Scope creep into structural redesign
- Letting copy fixes change product/privacy semantics instead of describing current behavior
- Hiding external processing behind another navigation layer
- Claiming key-only control while the authenticated session remains required
- Treating gzip-only improvement as proof that the authenticated raw parse cost is solved
```
