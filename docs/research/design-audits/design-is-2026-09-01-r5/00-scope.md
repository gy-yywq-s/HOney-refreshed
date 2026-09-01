# 00 — Scope (design-is audit, HOney, 2026-09-01, r5 — verification round)

## Audited artifact
- The DEPLOYED web app at https://honey.gaelisus.com — branch `integration/product-v2`, commit `487c1c4` ("css: one .view rule (settle animation folded into the layout rule)") on top of `1f87fae` ("design-is r4 handoff: interaction states, one dialog per purpose, CSS hygiene, SW scope"), which sits on `5d810d8` (r4's audited commit). Served bundle `index-c6M0Emr3.js` / `index-D-vVlHpE.css` (matches `apps/web/dist` built from HEAD); live `sw.js` still reads `honey-v3` (the handoff asked for an `sw.js` byte change — the file changed by 42 lines, the cache name did not). `git diff --stat 5d810d8..487c1c4` touches 20 web source files (`AppLayout`, `PullToRefresh`, `ReconnectDialog`, new `lib/useRetryFocus.ts`, `ExperiencePost`, `HistoryPage`, `HomePage`, `LoginPage`, `SettingsPage`, `TimetablePage`, `ComposePage`, `EntityPage`, `ExplorePage`, `FeedPage`, `MinePage`, the three non-admin stylesheets), `public/sw.js`, and `packages/shared/src/api/contract.ts`. No backend source files changed. The commits claim to implement the full r4 handoff.
- Source at `/home/honey/HOney-refreshed/apps/web`:
  - styles: `src/styles/` (tokens.css, foundations.css, components.css, features.css, admin.css)
  - pages: `src/pages/` (HomePage, TimetablePage, DashPage, HistoryPage, SettingsPage, LoginPage, NotFoundPage, experiences/{FeedPage, ExplorePage, ComposePage, EntityPage, MinePage, WhyPage, shared})
  - components: `src/components/` (AppLayout, PullToRefresh, ReconnectDialog, SchoolLoginForm …); `src/lib/useRetryFocus.ts`
  - stream components: `src/features/experiences/` (ExperiencePost.tsx, useFeedController.ts, useLoadMoreSentinel.ts)
  - backend (unchanged, read for honesty mapping only): `packages/backend/src/routes/auth.ts`, `services/timetable.ts`, `services/importer.ts`, `db/database.ts`

## Round framing
This is ROUND 5 of an iterative audit. r1 16/30, r2 16/30, r3 16/30, r4 18/30 (all REDESIGN by the <20 rule). r4 audited `5d810d8`: #6 and #10 each gained a point; #3, #4 and #8 stayed at 1 on new defects the r3 wave introduced. The r4 handoff has been executed and deployed as `1f87fae` + `487c1c4`. R5 (a) verifies every r4 move on the live app, (b) hunts for NEW defects the fixes introduced (the retry focus landings on all seven surfaces, the row-of-three compose actions at 320×568, the merged `.daynav__date` stepper rule, the two `ReconnectDialog` purposes, the SW live-asset set and navigation-triggered eviction, the composer skeleton, per-route titles, the feed tabpanel), (c) re-measures the standard metric tables (rendered spacing census, type table, contrast on stone AND a genuine dark boot, touch targets, modal containment, idle-animation count, bundle size, `tsc --noUnusedLocals`, request counts, duplicate-selector and consumer-less-class counts). Scores are re-anchored from scratch against the same rubric — no credit for unverified fixes, no inflation for effort, tie-breaker lower; where an r4 blocking condition is verifiably gone, the anchor is re-read and the evidence scored as it stands.

Owner's product decision (standing, not up for re-litigation): timetable import is part of the account — there is NO consent gate and no switch by design; it is disclosed (Settings "Timetable import" row + login footnote). The audit scores the *disclosure* (visible, true, complete?), not the absence of a toggle.

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
- Dynamic behavior is first-class evidence: the live app was OPERATED in a real browser (playwright, authenticated via the audit harness at /root/claude-work/design-audit/, `lib.js` → `authedPage({viewport, desktop})`), not just screenshotted. Viewports: 390×844 (primary), 320×568, 430×932, desktop 1280×800; `matrix.js` = 9-device regression. Probe scripts `r5-*.js` (+ `.log`) and screenshots `r5-*.png` retained in the harness directory. The three `r5-*.png` files dated 20:33 (`r5-compose-320.png`, `r5-save-dialog.png`, `r5-timetable.png`) pre-date this audit — they are the implementer's own checks and are NOT audit evidence.
- Static code/CSS reading complements browser evidence.
- Hard limits honored: no publishing of experience posts (no moderation-preflight submission), no report submission, no state-changing Settings actions (Sync now / Reconnect / Save school login / Disconnect / Delete / Sign out not pressed — dialogs opened and cancelled only), no secrets read or reproduced (`/home/honey/.secrets/` never opened, `.session.json` never printed or copied); reactions only if reverted.

## Out of scope
- iOS app, admin pages (/admin, /dash internals), backend moderation logic, login portal internals.
