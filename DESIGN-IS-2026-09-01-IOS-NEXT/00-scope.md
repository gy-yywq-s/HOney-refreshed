# HOney iOS post-review design-is scope

## Audited artifact

- Repository: `/Users/GaryS/Documents/HOney-refreshed`
- Branch: `codex/ios-editorial-redesign`
- Audited commit: `d2a323847d966f338b866c0e3be92c6358af7f93`
- This audit happens **after** the review-driven iOS implementation. The supplied review inspected the older `585e35c`; its product findings are inputs, not current-code evidence.
- The only worktree delta at scope lock is the user's local `DEVELOPMENT_TEAM` setting in `ios/HOney.xcodeproj/project.pbxproj`; it is excluded.
- Production code was not edited. This directory is the only audit output.

## Surfaces and system behavior

- Login and import consent
- Home and current/next lesson hierarchy
- Experiences feed, complete Explore lists, entity/course results, composer, reports, community meaning, and Your notes & posts
- Timetable, teacher labels, day navigation, history, and lesson detail
- Access physical actions and School Portal recovery
- Settings, account/data operations, and all four Surface palettes
- Runtime scope: caches, request coalescing, invalidation, stale-response protection, navigation/refetch behavior, timeout/cancellation, persistence failures, and state truth

## Primary user and task

- Primary user: a student using an iPhone during the school day.
- Primary task: understand the current or next lesson immediately and accurately.
- Secondary load-bearing tasks: browse every selectable school target without search gating, read/share an Experience, inspect another timetable day, operate Access exactly once, recover Portal use, and understand local/server data consequences.

## Current hard constraints

- Home's first visual focus is current/next lesson; Experiences and Access may remain secondary.
- Search may filter a complete list but must never be the only way to reveal remaining selectable options.
- Every Timetable lesson card shows the teacher supplied by the backend; absence must be labelled honestly.
- Porcelain, Clean White, Blue Mist, and Sage Gray remain direct persisted choices. Each palette owns tuned light/dark accent roles.
- Large gradients and large opaque fills are high-risk; Home may use only a restrained, validated atmospheric gradient.
- Login does not restore the serif title or text-only `HO` mark. The current wordmark is still a placeholder.
- Whole-app design includes logic, caching, persistence, error recovery, perceived latency, and accessibility.

## Inputs and verification boundary

- Full design-is skill contract.
- Supplied repository review: `/Users/GaryS/Documents/Inbox/HOney_repo_review_main_build_codex_v3_2026-09-01.md`.
- Current SwiftUI, service, model, and test source at `d2a3238`.
- Implementation handoff reports a generic signed arm64 Debug device build and **94 tests / 0 failures** at this commit. The audit team did not independently repeat that run.
- No fresh signed-in physical-iPhone screenshots, palette captures, Portal cold/warm timings, full accessibility traversal, Release/App Store-thinned size, or measured app TTI were available.

## Approval status

- Product owner has approved continued experimentation, not a final iOS visual system.
- Current palette values and placeholder identity are not final brand approval.
- A design-is score of at least 22/30 plus runtime/accessibility evidence remains the project acceptance floor.
