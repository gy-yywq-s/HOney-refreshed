# HOney iOS FINAL design-is scope

## Audited artifact

- Repository: `/Users/GaryS/Documents/HOney-refreshed`
- Branch: `codex/ios-editorial-redesign`
- Audited state: current working tree after the 21/30 POSTFIX follow-up.
- Excluded: personal `DEVELOPMENT_TEAM` lines in `ios/HOney.xcodeproj/project.pbxproj`.
- Production code was not edited by the design-is team. This directory is the only FINAL audit output.

## Final-fix questions

1. Are replacement credentials forced through a new Portal login instead of reusing a valid old session?
2. Does Explore label both initial loading and retained-content refreshing truthfully?
3. Are all choices browsable without search, with no silent backend truncation?
4. Does Access expose retry in initial, partial, and combined failures and open credential repair directly?
5. Do palette, deletion, Timetable teacher, cache, and physical-action truth remain intact?

## Primary user and task

- Primary user: a student using an iPhone during the school day.
- Primary task: identify the current or next lesson immediately.
- Secondary load-bearing tasks: browse every selectable target, repair school sign-in, recover Access safely, understand account/device deletion, and read/share Experiences without unnecessary request or state churn.

## Constraints retained

- Lesson-first Home; Experiences and Access remain secondary.
- Search may filter but never gate otherwise selectable choices.
- Every Timetable lesson shows a teacher or `Teacher not listed`.
- Porcelain, Clean White, Blue Mist, and Sage Gray remain direct choices with independently tuned accents.
- Large gradients and opaque color fields remain high-risk; the current wordmark remains a placeholder.
- Runtime, cache, stale responses, persistence, accessibility, and physical-action truth are part of design.

## Verification boundary

- Parent-confirmed iOS verification: **97/97 tests passed** and signed generic arm64 device **BUILD SUCCEEDED**.
- Parent-confirmed backend verification: **105/105 tests passed**, 23 skipped, and typecheck passed.
- No fresh signed-in physical-iPhone screenshots, Portal/Access physical timing, VoiceOver/Switch Control traversal, Dynamic Type captures, Reduce Motion capture, or measured device TTI were available.
- The 22/30 numeric line is not a substitute for unresolved load-bearing P1s or missing owner/runtime evidence.
