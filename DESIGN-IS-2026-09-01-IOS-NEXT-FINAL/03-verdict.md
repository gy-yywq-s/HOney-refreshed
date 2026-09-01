# Verdict

**REFINE** — At 22/30 with no zero-scored principle, the FINAL worktree reaches the project numeric design threshold by closing complete-option, refresh-truth, direct-recovery, palette-contrast, deletion, and sequential credential-verification gaps, but two Portal/Access concurrency-state P1s and missing physical-device/accessibility evidence prevent final release acceptance.

## Threshold and severity

- Numeric 22/30 line: **reached**.
- Final release/owner acceptance: **not yet complete**.
- P0: **none found** in source inspection.
- P1: a cancelled old in-flight Portal login can still write/activate an old session after replacement or device-data erase because no generation/cancellation guard protects completion.
- P1: an action-time credential failure updates Access banner but can leave local `connectionState` stale, so direct `Update school sign-in` may not appear until refresh.
- P1: overlapping Access refresh/retry tasks lack generation/coalescing and can apply results out of order.
- P1: Experiences still lacks cursor append and scroll restoration; My Classes remains a fixed first 100.

## Highest-leverage moves

1. **Principles #6 and #8 — Make Portal credential replacement/erase generation-safe:** Add an attempt generation, check cancellation/generation before saving any session and before assigning actor state, prevent an old caller's `defer` from clearing a newer task, await/retire obsolete work safely, and test replacement plus erase during a cancellation-ignoring in-flight login. Evidence: `ios/HOney/Services/PortalSessionCoordinator.swift:85-100,177-197`; `ios/HOneyTests/PortalSessionCoordinatorTests.swift:145-160`; §E3.
2. **Principles #2, #4, and #8 — Propagate Access credential state immediately:** After mutation/auth failure, refresh `connectionState` from the coordinator or return typed state with the failure so `Update school sign-in` appears in the same frame; add direct Portal recovery for interactive challenge and tests for permit/open credentialsRejected, challenge, and retry. Evidence: `ios/HOney/Features/Access/AccessViewModel.swift:140-162`; `ios/HOney/Features/Access/AccessView.swift:245-269`; §E3, §E6.
3. **Principles #8 and #9 — Make Access reads race-safe:** Coalesce equivalent refreshes, cancel/ignore obsolete permits and doors responses, keep each source's cached content while refreshing, and remove the duplicate permit/full Retry pair or give them genuinely separate scopes. Evidence: `AccessView.swift:43-46,63,208-212,260-264`; `AccessViewModel.swift:35-70`; §E1, §E7.
4. **Principles #2, #8, and #9 — Finish feed continuity:** Replace fixed first-page feeds with cursor/append, preserve scroll position across tab and entity navigation, keep loaded content during refresh, and test new-item/append/error/stale response behavior. Evidence: `ios/HOney/App/AppServices.swift:208-220`; `ios/HOney/Models/HOneyModels.swift:240-242`; `ios/HOney/Features/Experiences/ExperiencesView.swift:119-174`; §E7.
5. **Principles #3 and #8 — Close the evidence gap without redesigning passing surfaces:** Preserve lesson-first Home, four direct palettes, passing status chips, complete local filtering, and Timetable teacher fallback; capture signed-in light/dark physical-iPhone surfaces and run VoiceOver, Switch Control, Dynamic Type, Reduce Motion, Portal cold/warm, Access physical action, and device TTI verification. Evidence: §E4–E7.
