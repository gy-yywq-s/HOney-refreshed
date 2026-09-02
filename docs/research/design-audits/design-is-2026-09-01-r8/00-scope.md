# 00 — Scope (design-is audit, HOney, 2026-09-02, r8 — verification round)

## Audited artifact
- The DEPLOYED web app at https://honey.gaelisus.com — branch `integration/product-v2`, commit `13cbcee` ("web: cold-landing only (a retry never scrolls the timetable); compact sheets use the full height"), four commits on top of `213707d` (r7's audited commit): `5c0cec9` ("design-is r7 handoff: half-done states finished, quiet compact landing, AT says what changed"), `6dd9c04` ("css: one stay-connected rule (label is the 44px tap target)"), `0ce266d` ("backend: explicit cache-control per static file class (sw.js no-cache, assets immutable)"), `13cbcee`. Served bundle `index-KkxCm-lK.js` / `index-Ddv96bIG.css` / `DashPage-C0aWmNAs.js` — matches `apps/web/dist/assets` built from HEAD (confirmed by `curl` of `/` before fan-out). `git diff --stat 213707d..13cbcee` touches 16 web source files (`ReconnectDialog`, `ThemeControls`, `lib/motion.tsx`, `lib/useApi.ts`, `LoginPage`, `NotFoundPage`, `SettingsPage`, `TimetablePage`, `ComposePage`, `EntityPage`, `FeedPage`, `WhyPage`, `shared.tsx`, `components.css`, `features.css`, `foundations.css`) plus `packages/backend/src/app.ts` (static cache-control per file class) — 452 insertions / 159 deletions including the r7 audit artifacts; no `sw.js` change. Public-edge headers at fan-out: `sw.js` `cache-control: max-age=14400` (edge rewrite of the origin's `no-cache`; the edge is outside this repo), `/assets/*` `public, max-age=31536000, immutable`, `/` `public, max-age=0, must-revalidate`. The commit messages claim to implement the full r7 handoff (moves 1–4).
- Source at `/home/honey/HOney-refreshed/apps/web`:
  - styles: `src/styles/` (tokens.css, foundations.css, components.css, features.css, admin.css)
  - pages: `src/pages/` (HomePage, TimetablePage, DashPage, HistoryPage, SettingsPage, LoginPage, NotFoundPage, experiences/{FeedPage, ExplorePage, ComposePage, EntityPage, MinePage, WhyPage, shared})
  - components: `src/components/` (AppLayout, Modal, PullToRefresh, ReconnectDialog, SchoolLoginForm, ThemeControls …); `src/lib/useRetryFocus.ts`, `src/lib/useApi.ts`, `src/lib/motion.tsx`
  - stream components: `src/features/experiences/` (ExperiencePost.tsx, useFeedController.ts, useLoadMoreSentinel.ts)
  - backend (read for honesty mapping and header intent only): `packages/backend/src/app.ts`, `routes/auth.ts`, `routes/data.ts`, `services/accounts.ts`, `services/timetable.ts`, `services/importer.ts`, `db/database.ts`

## Round framing
This is ROUND 8 of an iterative audit. r1 16/30, r2 16/30, r3 16/30, r4 18/30, r5 19/30, r6 18/30, r7 19/30 (all REDESIGN by the <20 rule). r7 audited `213707d`: #3 and #8 stayed at 1 on defects the r6 wave introduced (inert `.timetable-note` margin, animated/misplaced compact landing, two-grammar `ReconnectDialog`, visually silent pending reaction, whole-feed polite region, compose landing absent from its error branch, refresh-blind in-flight map) plus pre-existing ones (bare `/why` link, 22 px login checkbox, `inert` on no dialog, 404 without skip link, `useNames` swallowing registry errors, unterminated comment); #4 held at 2 on a tie settled downward. The r7 handoff has been executed and deployed as `5c0cec9`→`6dd9c04`→`0ce266d`→`13cbcee`. R8 (a) verifies every r7 move on the live app, (b) hunts for NEW defects the fixes introduced (the static compact daynav, the cold-landing gate, the sr-only feed status, the `useNames(enabled)` split, the `[aria-disabled]` pending style, the one-treatment disabled buttons, `100dvh` sheets, the invalid-`?date=` URL replace, the single locale, the conditional P1–P6 clause, the 404 skip link, the `Reveal` removal), (c) re-measures the standard metric tables (rendered spacing census, type table, contrast on stone AND a genuine dark boot, touch targets in a `hasTouch` context at 390 and 320 incl. bare links and checkboxes, modal containment, idle-animation count, bundle size, `tsc --noUnusedLocals`, request counts, duplicate-selector and consumer-less-class counts, TSX-class→CSS-rule reverse sweep, SW seeded eviction, compact-height scroll sampling + overlap census at 320×568 / 360×620 / 390×620 in Asia/Shanghai). Scores are re-anchored from scratch against the same rubric — no credit for unverified fixes, no inflation for effort, tie-breaker lower; where an r7 blocking condition is verifiably gone, the anchor is re-read and the evidence scored as it stands.

Owner's product decisions (standing, not up for re-litigation): (1) timetable import is part of the account — there is NO consent gate and no switch by design; it is disclosed (Settings "Timetable import" row + login footnote). The audit scores the *disclosure* (visible, true, complete?), not the absence of a toggle. (2) The 620 px timetable canvas density on normal-height screens stays; the compact-height notches (540 at ≤620 px height, 450 at ≤360 px width) and the static-daynav compact landing are the deliberate degradation — the audit measures whether that degradation holds (hit-testing, legibility, overlaps, motion), not whether it should exist.

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
- Dynamic behavior is first-class evidence: the live app was OPERATED in a real browser (playwright, authenticated via the audit harness at /root/claude-work/design-audit/, `lib.js` → `authedPage({viewport, desktop, reducedMotion})` returning `{browser, context, page}`), not just screenshotted. Viewports: 390×844 (primary), 320×568, 320×600, 360×620, 390×620, 430×932, desktop 1280×800; `matrix.js` = 9-device regression. The harness runs in UTC, where this account's lessons fall outside the 09:00–20:00 window — every measurement involving lesson blocks uses a hand-built context with `timezoneId: "Asia/Shanghai"` (2026-09-02 and 2026-08-24 are 3-lesson days; 2026-08-22 and 2026-09-06 are empty). Probe scripts `r8-{struct,vis,copy,wf,a11y}-*.js` (+ `.log`) and screenshots `r8-*.png` retained in the harness directory; r7 probes re-run where the measurement is the same.
- Static code/CSS reading complements browser evidence.
- Five evidence subagents (Structural, Visual, Copy & Honesty, Weight & Friction, Accessibility), each run on `model: "opus"` per the owner's standing order (CLAUDE.md rule 4h); scoring and verdict by the orchestrator only.
- Hard limits honored: no publishing of experience posts (no "Share anonymously"/"Share as written"), no report submission, no state-changing Settings actions (Sync now / Reconnect / Save login / Disconnect / Delete / Sign out / Turn off not pressed — dialogs opened and cancelled only), no secrets read or reproduced (`/home/honey/.secrets/` never opened, `.session.json` never printed or copied); reactions only if reverted in the same script. Every browser launched is closed.

## Out of scope
- iOS app, admin pages (/admin, /dash internals), backend moderation logic, login portal internals, the public edge (hostd gateway / Cloudflare) header rewrite — recorded as a relay only.
