# 00 — Scope (design-is audit, HOney, 2026-09-01, r2 — verification round)

## Audited artifact
- The DEPLOYED web app at https://honey.gaelisus.com — branch `integration/product-v2`, commit `3d91cb3` ("design-is r1 handoff: tokens-up presentation redesign + registry hygiene"), which implements the full r1 handoff (type ramp + spacing tokens, route-settle containing-block fix, AA fixes, 44px targets, label fixes, feed Share entry, Explore chip strip, prefers-color-scheme at boot, Dash code-split, SW "/" precache, humanized countdown, registry hygiene, timetable canvas flex, Home focal card).
- Source at `/home/honey/HOney-refreshed/apps/web`:
  - styles: `src/styles/` (tokens.css, foundations.css, components.css, features.css, admin.css)
  - pages: `src/pages/` (HomePage, TimetablePage, DashPage, HistoryPage, SettingsPage, LoginPage, NotFoundPage, experiences/{FeedPage, ExplorePage, ComposePage, EntityPage, MinePage, WhyPage})
  - stream components: `src/features/experiences/` (ExperiencePost.tsx, useFeedController.ts)

## Round framing
This is ROUND 2 of an iterative audit. Round 1 (design-is-2026-09-01-r1/) scored 16/30 → REDESIGN; the handoff was executed and deployed. R2 (a) verifies every r1 finding's fix on the live app, (b) hunts for NEW defects the fixes may have introduced (57-size token sweep + spacing sweep: broken layouts, crowded rows, clipped text at 320/390/430), (c) re-measures the r1 metric tables. Scores are re-anchored from scratch against the same rubric — no credit for unverified fixes, no inflation for effort.

## Primary user
A high-school student on their phone (installed PWA). Typical viewport 390×844; must hold down to 320×568.

## Primary tasks
1. Check today's timetable / next lesson.
2. Read the Experiences stream.
3. Share an experience.

## Constraints
- Quiet-humanist design language: single font (Source Sans 3), narrow cool palette, ONE muted blue-teal accent `#33667c`, no warm tones.
- No small ALL-CAPS titles (owner rule).
- Every finite option set fully displayed (owner rule — search only filters, never hides the set).
- Honest privacy copy — never overclaim anonymity.
- iOS wire compatibility — no API changes may be proposed.

## Evidence mode
- Dynamic behavior is first-class evidence: the live app was OPERATED in a real browser (playwright, authenticated via the audit harness at /root/claude-work/design-audit/), not just screenshotted. Viewports: 390×844 (primary), 320×568, 430×932, desktop.
- Static code/CSS reading complements browser evidence.
- Hard limits honored: no publishing of experience posts (no moderation-preflight submission), no report submission, no secrets read or reproduced; reactions only if reverted.

## Out of scope
- iOS app, admin pages (/admin), backend moderation logic, login portal internals.
