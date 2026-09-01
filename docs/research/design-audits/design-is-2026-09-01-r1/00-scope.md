# 00 — Scope (design-is audit, HOney, 2026-09-01, r1)

## Audited artifact
- The DEPLOYED web app at https://honey.gaelisus.com — branch `integration/product-v2`, commit `c80ead4` ("web: post footer stays one line"; a deploy landed mid-audit — early probes ran on `5289dbb`, bundle sizes within 0.1%).
- Source at `/home/honey/HOney-refreshed/apps/web`:
  - styles: `src/styles/` (tokens.css, foundations.css, components.css, features.css, admin.css)
  - pages: `src/pages/` (HomePage, TimetablePage, DashPage, HistoryPage, SettingsPage, LoginPage, NotFoundPage, experiences/{FeedPage, ExplorePage, ComposePage, EntityPage, MinePage, WhyPage})
  - stream components: `src/features/experiences/` (ExperiencePost.tsx, useFeedController.ts)

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
- Dynamic behavior is first-class evidence: the live app was OPERATED in a real browser (playwright, authenticated via the audit harness at /root/claude-work/design-audit/), not just screenshotted. Viewports: 390×844 (primary), 320×568, desktop.
- Static code/CSS reading complements browser evidence.
- Hard limits honored: no publishing of experience posts (no moderation-preflight submission), no report submission, no secrets read or reproduced; reactions only if reverted.

## Out of scope
- iOS app, admin pages (/admin), backend moderation logic, login portal internals.

## Owner-flagged areas to verify (not assume)
- Type sizes possibly "web-dashboard-ish" rather than mobile-native — measure rendered px.
- Very short feed post bodies: is the student's text unmistakably the subject?
- Timetable control bar arrangement; fixed non-wobbling frame on every screen; compose fits one screen; pull-to-refresh works.
- Home "Next lesson" countdown copy (e.g. "In 626 min").
