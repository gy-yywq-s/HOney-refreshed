# HOney iOS independent team post-fix audit scope

## Audited artifact

- Repository: `/Users/GaryS/Documents/HOney-refreshed`
- Branch: `codex/ios-editorial-redesign`
- Baseline commit: `be8369c9b7b02b9fd542246d2d3fe827bc25c829`
- The only local delta at scope lock is personal `DEVELOPMENT_TEAM` configuration in `ios/HOney.xcodeproj/project.pbxproj`; it is excluded.
- Surfaces: Login, consent, Home, School Portal, Experiences/composer/recovery/My Posts, Timetable/history/lesson detail, Access, Settings/account deletion, and the shared design system.
- System scope includes business logic, state machines, persistence, cache/coalescing/prefetch, request generation/cancellation, stale-response protection, cold/warm behavior, timeout/retry, account reset, and physical-action concurrency.

## Primary user and task

- Primary user: a student using an iPhone during the school day.
- Primary task: understand the current or next lesson immediately and accurately.
- Secondary load-bearing tasks: inspect another timetable day, publish/recover an Experience safely, open the School Portal without apparent freeze, operate physical Access exactly once, and manage account/local data truthfully.

## Constraints

- Preserve SwiftUI/iOS 17+, API boundaries, privacy, fail-closed publication, device-local notes/drafts/post-control keys, and direct-to-school Access.
- Preserve the quiet editorial direction and lesson-first Home; do not restore legacy styling.
- Keep blue-teal as the accent family, with per-Surface tuned accent roles. Paper, Neutral White, Cool Mist, and Soft Gray must remain persisted choices with coherent light/dark contrast.
- Final wordmark and independent small mark remain user-owned production decisions.
- Runtime responsiveness, cancellation, stale data, storage failures, and data consistency are design acceptance concerns.
- No credentials, live portal probing, deployment, commit, or application-source edit is part of this audit.

## Evidence inputs

- Current committed SwiftUI/services/tests at `be8369c`.
- Runtime Login captures: `DESIGN-IS-2026-09-01-POST/evidence/login-light-placeholder-v2.png` and `login-dark-placeholder-v2.png`, 1206x2622 px (402x874 pt at 3x).
- Current signed thin-arm64 Debug product: `/private/tmp/HOney-Optimize-Device-DD/Build/Products/Debug-iphoneos/HOney.app`, timestamp 2026-09-01 17:49:25 +0800.
- Source inventory: 89 XCTest methods. This is not presented as an independently observed 89/89 passing run.
- Earlier user-observed Portal freeze and Timetable pause apply to pre-fix code; they are regression targets, not observations of current `be8369c` behavior.

## Known limits

- Runtime screenshots predate current field borders and alternate Surface palettes.
- No signed-in screenshots, physical-iPhone run, Portal cold/warm timing, app launch TTI, network/energy trace, or Release/App Store thinning report.
- No VoiceOver/Switch Control traversal, accessibility Dynamic Type, increased contrast, landscape, or small-iPhone runtime verification.
- Portal DOM accessibility remains outside native-source inspection.
