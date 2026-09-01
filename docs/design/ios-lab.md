# iOS design lab

Status: **experimental — not approved. Owner-driven.** Gary is doing the iOS
UI optimization himself right now; Claude holds off on all iOS UI work until
Gary reopens it. This file only records the lab's inputs so nothing is lost.

## Evidence pool

- **Legacy app**: navy/ocean, translucent cards, rounded, utility feel —
  the live brand memory (icon + serif wordmark).
- **main iOS port** (`main@09c9562`): wholesale legacy port; familiar but not
  a product re-definition.
- **Codex branch** (`codex/ios-editorial-redesign@585e35c`, tagged): quiet
  editorial experiment. Its *visual/product* choices (four surfaces,
  placeholder wordmark, quick-action Home, filter-first Experiences) are
  hypotheses only. Its *behavior* work is a valuable engineering donor:
  - TimetableRepository actor cache (coalescing, generations, stale
    protection, prefetch)
  - Portal WebView state machine (warm reuse, attempt generation, deadline,
    recovery)
  - Access read/mutation state separation, outcome-unknown handling
  - draft/ownership-key/recovery-journal resilience (+ its `try?`-swallowed
    error honesty issues, which must be fixed during any port)
  - test assets (stale/A-B-A/prefetch, contrast, recovery states)

## Deferred (until Gary reopens iOS for Claude)

- Selective donor ports above (never a whole-branch merge — branch is 15
  commits behind build/v1).
- Earlier review findings: delete-account failure path, ReportSheet error
  surfacing, reaction optimism, publish cookie-jar isolation.
- Privacy copy truth (review v3 §13.5): ComposeExperienceView's publish
  success still says "nothing links the post back to you" — must become the
  honest ownership-key wording (web already changed); Settings "not even for
  you" line likewise. Also surface the external-LLM moderation disclosure
  (docs/architecture/moderation-external-processing.md) on iOS.
- Reaction UX parity: adopt myReaction restore + authoritative react echo
  (backend already serves both).
- Real-device runtime evidence pass (signed-in screenshots, VoiceOver,
  Dynamic Type, portal cold/warm timing, Release build).
