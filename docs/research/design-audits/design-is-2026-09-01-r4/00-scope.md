# 00 — Scope (design-is audit, HOney, 2026-09-01, r4 — verification round)

## Audited artifact
- The DEPLOYED web app at https://honey.gaelisus.com — branch `integration/product-v2`, commit `5d810d8` ("design-is r3 handoff: honesty + detail finishing pass"), on top of `fd522c3` (r3's audited commit). Served bundle `index-BQhfgddr.js` / `index-D7RZ4AWU.css` (matches `apps/web/dist` built from HEAD); live `sw.js` reads `honey-v3`. `git diff --stat fd522c3..5d810d8` touches 19 web source files (`LoginPage`, `SchoolLoginForm`, `SettingsPage`, `TimetablePage`, `HistoryPage`, `HomePage`, `ComposePage`, `EntityPage`, `ExplorePage`, `FeedPage`, `MinePage`, `shared.tsx`, `ExperiencePost`, `api/client.ts`, the three non-admin stylesheets), `public/sw.js`, and backend `routes/auth.ts` + `services/timetable.ts`. The commit claims to implement the full r3 handoff.
- Source at `/home/honey/HOney-refreshed/apps/web`:
  - styles: `src/styles/` (tokens.css, foundations.css, components.css, features.css, admin.css)
  - pages: `src/pages/` (HomePage, TimetablePage, DashPage, HistoryPage, SettingsPage, LoginPage, NotFoundPage, experiences/{FeedPage, ExplorePage, ComposePage, EntityPage, MinePage, WhyPage, shared})
  - stream components: `src/features/experiences/` (ExperiencePost.tsx, useFeedController.ts, useLoadMoreSentinel.ts)
  - backend touched: `packages/backend/src/routes/auth.ts`, `services/timetable.ts` (plus the unchanged `experiences/entities.ts`, `services/importer.ts`, `db/database.ts` migration 009)

## Round framing
This is ROUND 4 of an iterative audit. r1 16/30, r2 16/30, r3 16/30 (all REDESIGN by the <20 rule). r3 audited `fd522c3`: #9 reached 3, #6 dropped to 1 over the silent consent change. The r3 handoff has been executed and deployed as `5d810d8`. R4 (a) verifies every r3 move on the live app, (b) hunts for NEW defects the fixes introduced (··· menu behaviour, the date button, login layout at 320/390/430, the caption margin reset, the seven Try again controls, the Settings disclosure row), (c) re-measures the standard metric tables (rendered spacing census, type table, contrast on stone AND a genuine dark boot, touch targets, modal containment, idle-animation count, bundle size, `tsc --noUnusedLocals`, request counts). Scores are re-anchored from scratch against the same rubric — no credit for unverified fixes, no inflation for effort, tie-breaker lower; where an r3 blocking condition is verifiably gone, the anchor is re-read and the evidence scored as it stands.

Owner's product decision recorded for this round: timetable import is part of the account — there is NO consent gate and no switch by design. The audit scores the *disclosure* of that fact (is it visible, true, and complete?), not the absence of a toggle.

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
- Dynamic behavior is first-class evidence: the live app was OPERATED in a real browser (playwright, authenticated via the audit harness at /root/claude-work/design-audit/, `lib.js` → `authedPage()`), not just screenshotted. Viewports: 390×844 (primary), 320×568, 430×932, desktop 1280×800. Probe scripts `r4-*.js` and screenshots `r4-*.png` retained in the harness directory.
- Static code/CSS reading complements browser evidence.
- Hard limits honored: no publishing of experience posts (no moderation-preflight submission), no report submission, no state-changing Settings actions (Sync now / Reconnect / Save school login / Disconnect / Delete / Sign out not pressed), no secrets read or reproduced (`/home/honey/.secrets/` never opened, `.session.json` never printed); reactions only if reverted.

## Out of scope
- iOS app, admin pages (/admin, /dash internals), backend moderation logic, login portal internals.
