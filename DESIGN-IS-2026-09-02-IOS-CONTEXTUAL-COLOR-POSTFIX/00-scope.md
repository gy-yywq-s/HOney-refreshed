# Scope lock

## Artifact audited

- Current post-fix uncommitted SwiftUI implementation in `/Users/GaryS/Documents/HOney-refreshed/ios/HOney` on branch `codex/ios-editorial-redesign`, based at commit `5158ebcf559927b6f8832232fc34b7eca12a81f7`.
- Production/test diff snapshot at initial scope lock was `c7ef7a8255e3372c2faa29575087499b609a324cd274d0832e323a9a9d58f404`. Auth/session, heading and regression-coverage defects found during audit were fixed before final verification. Final SHA-256 of `git diff -- ios/HOney ios/HOneyTests` used for scoring = `06b3d42de973d4a51a204df6f77db901bab638b32d8814c2281b80854b00e768`.
- Post-fix checks requested:
  - Timetable's visible `Today` action and horizontally scrollable 44pt date strip.
  - `Posts & notes`, permit-row `Choose gate`, and Settings `Update school sign-in` label-to-behavior alignment.
  - Access copy tightening and consolidation of duplicate retry affordances.
  - Heading traits on custom and screen headings.
  - `startupUnavailable`: temporary session-check failure must not masquerade as sign-out.
  - Regression check of all earlier contextual-color requirements: whole-screen Home composition, six palettes, no small uppercase, no whole-screen pull-to-refresh, lesson cards/teacher fallback, caching and truthful states.

## Primary user and task

- Primary user: a signed-in student using HOney one-handed during the school day.
- Primary task: identify the current/next lesson immediately and move among timetable, student experiences, history and physical access without ambiguous labels, accidental navigation, needless reloads or false state.

## Constraints

- Native SwiftUI; no production-code/test changes by the audit team.
- Judge color/cards/fills contextually as whole-screen composition, never as mechanically banned ingredients.
- Preserve all six directly selectable palettes and their palette-specific detail colors.
- No small-uppercase headings, whole-screen pull-to-refresh, or broad Timetable swipe-to-change-day.
- Accessibility floor: natural heading semantics, Dynamic Type, VoiceOver/Switch Control reachability, 44pt targets, contrast, dark mode and Reduce Motion.
- Runtime/logic remain design scope: caching, request coordination, stale-response rejection, truthful errors and physical-action safety.

## Reference and evidence boundaries

- Correct Web reference remains `origin/integration/product-v2@4f0c4876a16b6ddedeccb7e28cf7f02021536caa`, `apps/web`; `web-ionic` remains excluded.
- The prior audit is contextual input only: `DESIGN-IS-2026-09-01-IOS-CONTEXTUAL-COLOR/`.
- No fresh signed-in iOS screenshot is available at scope lock. Code-level visual findings are inferred; Login cannot substitute for signed-in Home.
- Final automated evidence independently inspected: `/tmp/honey-ios-final-106.xcresult` reports 106 passed, 0 failed, 0 skipped on arm64 iPhone 17 simulator. `/tmp/honey-ios-device-final/Build/Products/Debug-iphoneos/HOney.app` contains a signed thin arm64 Mach-O with bundle identifier `com.gaelisus.honey` and TeamIdentifier `ALQXG4KCRB`; root reports the generic iphoneos build command exited 0. No physical Access or device accessibility result is inferred from compilation/tests.
