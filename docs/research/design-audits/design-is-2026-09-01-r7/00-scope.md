# 00 — Scope (design-is audit, HOney, 2026-09-01, r7 — verification round)

## Audited artifact
- The DEPLOYED web app at https://honey.gaelisus.com — branch `integration/product-v2`, commit `213707d` ("web: timetable canvas one more notch on SE-class screens (<=360x620)"), three commits on top of `03875ed` (r6's audited commit): `b52fe82` ("design-is r6 handoff: reverse the sweep regressions, bind the ring to the retry, small-screen landing"), `5c15385` ("web: shared in-flight requests, short save-login label, compact canvas notch"), `213707d`. Served bundle `index-CkJ_sIHn.js` / `index-CukErUfj.css` — matches `apps/web/dist` built from HEAD (confirmed by `curl` of `/` before fan-out; `DashPage-BY2xasr3.js` present in dist). Live `sw.js` byte-identical to r6 (4,828 B, `honey-v3`) and still served `cache-control: public, max-age=14400` (the r5/r6 relay asked for `no-cache`; not done). `git diff --stat 03875ed..213707d` touches 15 web source files (`Modal`, `ReconnectDialog`, `ExperiencePost`, `lib/useApi.ts`, `lib/useRetryFocus.ts`, `NotFoundPage`, `SettingsPage`, `TimetablePage`, `ComposePage`, `ExplorePage`, `FeedPage`, `MinePage`, `components.css`, `features.css`, `foundations.css`) — 149 insertions / 70 deletions in source; no backend file changed; no `sw.js` change. The commit messages claim to implement the full r6 handoff (moves 1–4) plus two follow-up notches on the compact timetable canvas.
- Source at `/home/honey/HOney-refreshed/apps/web`:
  - styles: `src/styles/` (tokens.css, foundations.css, components.css, features.css, admin.css)
  - pages: `src/pages/` (HomePage, TimetablePage, DashPage, HistoryPage, SettingsPage, LoginPage, NotFoundPage, experiences/{FeedPage, ExplorePage, ComposePage, EntityPage, MinePage, WhyPage, shared})
  - components: `src/components/` (AppLayout, Modal, PullToRefresh, ReconnectDialog, SchoolLoginForm, ThemeControls …); `src/lib/useRetryFocus.ts`, `src/lib/useApi.ts`
  - stream components: `src/features/experiences/` (ExperiencePost.tsx, useFeedController.ts, useLoadMoreSentinel.ts)
  - backend (read for honesty mapping only): `packages/backend/src/routes/auth.ts`, `routes/data.ts`, `services/timetable.ts`, `services/importer.ts`, `db/database.ts`

## Round framing
This is ROUND 7 of an iterative audit. r1 16/30, r2 16/30, r3 16/30, r4 18/30, r5 19/30, r6 18/30 (all REDESIGN by the <20 rule). r6 audited `03875ed`: #5 dropped to 1 on a tie over the tap-triggered landing ring; #3 and #8 stayed at 1 on defects the r5 wave's CSS sweep introduced (deleted 44 px touch floor, deleted pressed theme card, inert chip tones, duplicate selector, dangling comments) plus the 320×568 lesson-day and Save-dialog fold problems. The r6 handoff has been executed and deployed as `b52fe82`→`5c15385`→`213707d`. R7 (a) verifies every r6 move on the live app, (b) hunts for NEW defects the fixes introduced (the `data-landed` ring state, the always-mounted feed live region, the compact-height canvas notches 540/450, the SE-class landing scroll via `scroll-margin-top`, the restored pressed card, the `useApi` in-flight dedupe, the `aria-disabled` reactions, the `#main:focus` ring, the renamed `.timetable-note`, the shortened Save-login label), (c) re-measures the standard metric tables (rendered spacing census, type table, contrast on stone AND a genuine dark boot, touch targets in a `hasTouch` context at 390 and 320, modal containment, idle-animation count, bundle size, `tsc --noUnusedLocals`, request counts, duplicate-selector and consumer-less-class counts, TSX-class→CSS-rule reverse sweep, SW seeded eviction). Scores are re-anchored from scratch against the same rubric — no credit for unverified fixes, no inflation for effort, tie-breaker lower; where an r6 blocking condition is verifiably gone, the anchor is re-read and the evidence scored as it stands.

Owner's product decisions (standing, not up for re-litigation): (1) timetable import is part of the account — there is NO consent gate and no switch by design; it is disclosed (Settings "Timetable import" row + login footnote). The audit scores the *disclosure* (visible, true, complete?), not the absence of a toggle. (2) The 620 px timetable canvas density on normal-height screens stays; the compact-height notches (540 at ≤620 px height, 450 at ≤360 px width) are the deliberate degradation — the audit measures whether that degradation holds (hit-testing, legibility, overlaps), not whether it should exist.

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
- Dynamic behavior is first-class evidence: the live app was OPERATED in a real browser (playwright, authenticated via the audit harness at /root/claude-work/design-audit/, `lib.js` → `authedPage({viewport, desktop, reducedMotion})` returning `{browser, context, page}`), not just screenshotted. Viewports: 390×844 (primary), 320×568, 320×600, 360×620, 390×620, 430×932, desktop 1280×800; `matrix.js` = 9-device regression. The harness runs in UTC, where this account's lessons fall outside the 09:00–20:00 window — every measurement involving lesson blocks uses a hand-built context with `timezoneId: "Asia/Shanghai"` (pattern: `r6-struct-timetable-cst.js`, `r6-vis-tz3.js`, `r6-a11y-tz.js`). Probe scripts `r7-{struct,vis,copy,wf,a11y}-*.js` (+ `.log`) and screenshots `r7-*.png` retained in the harness directory; r6 probes re-run where the measurement is the same.
- Static code/CSS reading complements browser evidence.
- Five evidence subagents (Structural, Visual, Copy & Honesty, Weight & Friction, Accessibility), each run on `model: "opus"` per the owner's standing order (CLAUDE.md rule 4h); scoring and verdict by the orchestrator only.
- Hard limits honored: no publishing of experience posts (no "Share anonymously"/"Share as written"), no report submission, no state-changing Settings actions (Sync now / Reconnect / Save login / Disconnect / Delete / Sign out / Turn off not pressed — dialogs opened and cancelled only), no secrets read or reproduced (`/home/honey/.secrets/` never opened, `.session.json` never printed or copied); reactions only if reverted. Every browser launched is closed.

## Out of scope
- iOS app, admin pages (/admin, /dash internals), backend moderation logic, login portal internals.
