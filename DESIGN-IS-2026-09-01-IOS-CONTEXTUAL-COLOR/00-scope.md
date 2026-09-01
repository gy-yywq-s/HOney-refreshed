# Scope lock

## Artifact audited

- Current uncommitted SwiftUI implementation in `/Users/GaryS/Documents/HOney-refreshed/ios/HOney` on branch `codex/ios-editorial-redesign`, based at commit `5158ebcf559927b6f8832232fc34b7eca12a81f7`.
- Final production/test working-tree snapshot used for synthesis: SHA-256 of `git diff -- ios/HOney ios/HOneyTests` = `1f4d2a18c7f808d2365a43f74bb0ba006a13ed494c31578afe311e8e116c2e23`. Audit artifacts themselves are excluded from that digest.
- Whole-app surfaces relevant to the current change: Home, Timetable, Experiences, History, Access, Settings, shared theme/components, app-scoped repositories and refresh state.
- Required detailed checks:
  - Home whole-screen composition, especially the relationship between the page ground and the current/next-lesson hero.
  - Six directly selectable Surface palettes, palette-specific accents, supporting-color semantics, and retention of earlier choices.
  - No small uppercase or small-caps labels.
  - No standard whole-screen pull-to-refresh.
  - Timetable lessons as bounded cards with explicit day controls and no broad swipe-to-change-day gesture.
  - History, Home and Experiences caching, request coordination and truthful loading/refresh/error/empty states.
  - Access explicit local refresh and truthful action states.

## Primary user and task

- Primary user: a signed-in student using HOney during the school day, usually one-handed and under time pressure.
- Primary task: immediately understand the current or next lesson and move among timetable, school experiences, history, and physical access without accidental navigation, unnecessary reloads, freezes, or misleading state.

## Constraints

- Stack: native SwiftUI iOS app; existing presentation/service/domain separation remains intact.
- Visual direction: quiet, modern, editorial, warm and intelligent; Home's current/next lesson remains the primary visual focus.
- Color judgment is contextual: white, borders, repeated accents and fills are not banned. Their proportion, contrast, repetition, semantic role and relationship to the whole screen determine quality. The known Home failure is one isolated high-contrast pure-white bordered hero floating on a different colored/gradient ground.
- All six Surface palettes must remain directly selectable and persisted; an accent may repeat for the same meaning, while supporting colors should appear only where they clarify a distinct meaning or hierarchy.
- Accessibility floor: system appearance, Dynamic Type, VoiceOver, 44-point targets, sufficient contrast and Reduce Motion.
- Runtime and logic are in scope: caching, cancellation, stale-response protection, persistence, truthful states and perceived responsiveness.
- Audit only: no production-code or test edits.

## Reference

- Correct web reference: `origin/integration/product-v2` at `4f0c4876a16b6ddedeccb7e28cf7f02021536caa`, specifically `apps/web` and the deployed Home at `https://honey.gaelisus.com/home`.
- Explicitly excluded reference: `web-ionic` and any Ionic branch.
- The web reference is evidence of pitfalls already addressed and useful compositional relationships, not a requirement to copy the web UI into SwiftUI.

## Evidence limits known at scope lock

- No fresh signed-in iOS Home screenshot is available. Code-level visual findings are therefore marked inferred; Login screenshots must not be substituted as Home evidence.
- No physical-device runtime trace is part of this audit. Cache and refresh behavior can be inspected in code and tests, but cold/warm latency and physical Access behavior remain unverified unless concrete measurements are found.
