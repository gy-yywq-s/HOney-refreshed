# 00 — Scope (design-is audit, HOney, 2026-09-01, r3 — verification round)

## Audited artifact
- The DEPLOYED web app at https://honey.gaelisus.com — branch `integration/product-v2`, commit `26812cb` ("web: explore history mark never wraps; anchored sections get scroll margin"), which sits on top of `3815b19` ("design-is r2 handoff remainder: spacing on the ladder, no idle motion") and `d7a0fcc` ("design-is r2 defects: land what r1 claimed, fix what r2 measured"). Together these three commits claim to implement the full r2 handoff. Deployed assets `index-OOE7rlZj.js` / `index-CHlTuHHx.css` / `DashPage-C6vl-eAk.js` match the local `apps/web/dist` build; the live `sw.js` reads `honey-v2`.
- Source at `/home/honey/HOney-refreshed/apps/web`:
  - styles: `src/styles/` (tokens.css, foundations.css, components.css, features.css, admin.css)
  - pages: `src/pages/` (HomePage, TimetablePage, DashPage, HistoryPage, SettingsPage, LoginPage, NotFoundPage, experiences/{FeedPage, ExplorePage, ComposePage, EntityPage, MinePage, WhyPage, shared})
  - stream components: `src/features/experiences/` (ExperiencePost.tsx, useFeedController.ts, useLoadMoreSentinel.ts)
  - backend touched by the r2 handoff: `packages/backend/src/experiences/entities.ts`, `packages/backend/src/services/importer.ts`

## Round framing
This is ROUND 3 of an iterative audit. Round 1 scored 16/30 → REDESIGN; round 2 (auditing `3d91cb3`, the r1 implementation) again scored 16/30 → REDESIGN because each principle's blocking condition survived even though most r1 sub-findings verified fixed. The r2 handoff has since been executed and deployed. R3 (a) verifies every r2 move on the live app, (b) hunts for NEW defects the spacing sweep (150 margin/padding/gap declarations moved to the `--sp-*` ladder) may have introduced — crowded or loose rhythm, clipped text, misaligned rows at 320/390/430, (c) re-measures the r1/r2 metric tables (rendered spacing census, type table, contrast on stone AND a genuine dark boot, touch targets, modal containment, idle-animation count, bundle size, `tsc --noUnusedLocals`). Scores are re-anchored from scratch against the same rubric — no credit for unverified fixes, no inflation for effort; where an r2 blocking condition is verifiably gone, the anchor is re-read and the evidence scored as it stands.

## Primary user
A high-school student on their phone (installed PWA). Typical viewport 390×844; must hold down to 320×568.

## Primary tasks
1. Check today's timetable / next lesson.
2. Read the Experiences stream.
3. Share an experience.

## Constraints
- Quiet-humanist design language: single font (Source Sans 3), narrow cool palette, ONE muted blue-teal accent `#33667c` (night `#8fc2d4`), no warm tones except semantic danger/ok.
- No small ALL-CAPS titles (owner rule).
- Every finite option set fully displayed (owner rule — search only filters, never hides the set).
- Honest privacy copy — never overclaim anonymity.
- iOS wire compatibility — no API changes may be proposed.

## Evidence mode
- Dynamic behavior is first-class evidence: the live app was OPERATED in a real browser (playwright, authenticated via the audit harness at /root/claude-work/design-audit/, `lib.js` → `authedPage()`), not just screenshotted. Viewports: 390×844 (primary), 320×568, 430×932, desktop 1280×800. Probe scripts `r3-*.js` and screenshots `r3-*.png` retained in the harness directory.
- Static code/CSS reading complements browser evidence.
- Hard limits honored: no publishing of experience posts (no moderation-preflight submission), no report submission, no secrets read or reproduced (`/home/honey/.secrets/` never opened, `.session.json` never printed); reactions only if reverted.

## Out of scope
- iOS app, admin pages (/admin, /dash internals), backend moderation logic, login portal internals.
