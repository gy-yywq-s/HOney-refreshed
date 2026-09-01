# HOney iOS POSTFIX design-is scope

## Audited artifact

- Repository: `/Users/GaryS/Documents/HOney-refreshed`
- Branch: `codex/ios-editorial-redesign`
- Base commit: `d2a323847d966f338b866c0e3be92c6358af7f93`
- Audited state: base commit plus the current uncommitted POSTFIX production and test changes.
- Excluded worktree item: personal `DEVELOPMENT_TEAM` lines in `ios/HOney.xcodeproj/project.pbxproj`.
- Production code was not edited by the design-is team. This audit directory is the only team output.

## POSTFIX questions

1. Does Explore preserve direct access to every choice while search only filters, and does it distinguish loading, full failure, partial failure, filtered empty, genuine empty, and retry?
2. Is school-sign-in repair reachable and does it actually verify the newly entered credentials?
3. Do account deletion labels match server/device cleanup, including Portal session and credentials?
4. Are palette, Portal, and saved-draft terms now plain and accurate?
5. Do My Posts status chips pass text contrast in every palette and mode?
6. Are Home and Access errors directly recoverable?
7. Did runtime/cache/logic truth remain in scope?

## Primary user and task

- Primary user: a student using an iPhone during the school day.
- Primary task: identify the current or next lesson immediately.
- Secondary load-bearing tasks: browse every selectable target without a search gate, repair school sign-in, understand deletion consequences, read/share Experiences, and safely recover network/Portal/Access failure.

## Hard constraints retained

- Home remains lesson-first.
- Search may filter but never hide otherwise selectable items.
- Timetable always shows the backend teacher or `Teacher not listed`.
- Porcelain, Clean White, Blue Mist, and Sage Gray remain directly selectable with independently tuned accents.
- Large gradients and large opaque fills remain high-risk.
- The current raster wordmark remains a placeholder, not a final brand decision.
- Design includes runtime, caches, logic, persistence, accessibility, and truthful edge states.

## Verification boundary

- Parent implementation verification: generic signed arm64 device build **BUILD SUCCEEDED**; complete simulator suite **96 tests / 0 failures / TEST SUCCEEDED**.
- No fresh signed-in physical-iPhone screenshots, physical Portal/Access timing, VoiceOver/Switch Control traversal, Dynamic Type captures, Reduce Motion capture, or measured device TTI were available.
- The numeric score cannot substitute for those release/owner evidence gates.
