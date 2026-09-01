# 00 — Scope (design-is audit, HOney, 2026-09-01, r6 — verification round)

## Audited artifact
- The DEPLOYED web app at https://honey.gaelisus.com — branch `integration/product-v2`, commit `03875ed` ("design-is r5 handoff: empty state in flow, compact compose rows, landings, dialogs, SW eviction"), one commit on top of `487c1c4` (r5's audited commit). Served bundle `index-D47LYHws.js` / `index-CFkg1jp9.css` — matches `apps/web/dist` built from HEAD (confirmed by `curl` of `/` before fan-out). Live `sw.js` still reads `honey-v3` and is still served `cache-control: public, max-age=14400` (the r5 relay asked for `no-cache` via the hostd manifest; not done). `git diff --stat 487c1c4..03875ed` touches 22 web source files (`AppLayout`, `Modal`, `PullToRefresh`, `ReconnectDialog`, `SchoolLoginForm`, `ExperiencePost`, `lib/useRetryFocus.ts`, `HistoryPage`, `HomePage`, `LoginPage`, `NotFoundPage`, `SettingsPage`, `TimetablePage`, `ComposePage`, `EntityPage`, `ExplorePage`, `FeedPage`, `MinePage`, the three non-admin stylesheets — 38 insertions / 99 deletions), `public/sw.js` (42 lines), and one backend comment (`packages/backend/src/routes/auth.ts:30-31`, now "… "Sync now" (POST /api/sync) is the manual path."). No backend logic changed. The commit message claims to implement the full r5 handoff.
- Source at `/home/honey/HOney-refreshed/apps/web`:
  - styles: `src/styles/` (tokens.css, foundations.css, components.css, features.css, admin.css)
  - pages: `src/pages/` (HomePage, TimetablePage, DashPage, HistoryPage, SettingsPage, LoginPage, NotFoundPage, experiences/{FeedPage, ExplorePage, ComposePage, EntityPage, MinePage, WhyPage, shared})
  - components: `src/components/` (AppLayout, Modal, PullToRefresh, ReconnectDialog, SchoolLoginForm …); `src/lib/useRetryFocus.ts`
  - stream components: `src/features/experiences/` (ExperiencePost.tsx, useFeedController.ts, useLoadMoreSentinel.ts)
  - backend (read for honesty mapping only): `packages/backend/src/routes/auth.ts`, `services/timetable.ts`, `services/importer.ts`, `db/database.ts`

## Round framing
This is ROUND 6 of an iterative audit. r1 16/30, r2 16/30, r3 16/30, r4 18/30, r5 19/30 (all REDESIGN by the <20 rule; r5 was one tie-break from REFINE). r5 audited `487c1c4`: #4 gained a point; #3 and #8 stayed at 1 on defects the r4 wave introduced (empty state under the nav, wrapped compose labels, deleted chip rules, pointer-invisible landing ring, fail-open composer, cancelled outside-click focus return). The r5 handoff has been executed and deployed as `03875ed`. R6 (a) verifies every r5 move on the live app, (b) hunts for NEW defects the fixes introduced (the in-flow empty state, the two-row compose actions, the landing ring on programmatic focus, the split live region, the dialog checkbox default, the orphan sweep — including the reverse sweep TSX-class→CSS-rule), (c) re-measures the standard metric tables (rendered spacing census, type table, contrast on stone AND a genuine dark boot, touch targets, modal containment, idle-animation count, bundle size, `tsc --noUnusedLocals`, request counts, duplicate-selector and consumer-less-class counts, SW seeded eviction). Scores are re-anchored from scratch against the same rubric — no credit for unverified fixes, no inflation for effort, tie-breaker lower; where an r5 blocking condition is verifiably gone, the anchor is re-read and the evidence scored as it stands.

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
- Dynamic behavior is first-class evidence: the live app was OPERATED in a real browser (playwright, authenticated via the audit harness at /root/claude-work/design-audit/, `lib.js` → `authedPage({viewport, desktop, reducedMotion})`), not just screenshotted. Viewports: 390×844 (primary), 320×568, 320×600, 390×620, 430×932, desktop 1280×800; `matrix.js` = 9-device regression. Probe scripts `r6-{struct,vis,copy,wf,a11y}-*.js` (+ `.log`) and screenshots `r6-*.png` retained in the harness directory; r5 probes were re-run or copied where the measurement is the same.
- Static code/CSS reading complements browser evidence.
- Five evidence subagents (Structural, Visual, Copy & Honesty, Weight & Friction, Accessibility), each run on `model: "opus"` per the owner's standing order; scoring and verdict by the orchestrator only.
- Hard limits honored: no publishing of experience posts (no moderation-preflight submission), no report submission, no state-changing Settings actions (Sync now / Reconnect / Save login / Disconnect / Delete / Sign out / Turn off not pressed — dialogs opened and cancelled only), no secrets read or reproduced (`/home/honey/.secrets/` never opened, `.session.json` never printed or copied); reactions only if reverted. Every browser launched is closed.

## Out of scope
- iOS app, admin pages (/admin, /dash internals), backend moderation logic, login portal internals.
