```text
/make-plan Refine HOney iOS based on a FINAL Dieter Rams audit (total 22/30).

Verdict paragraph (quoted from 03-verdict.md):
> REFINE — At 22/30 with no zero-scored principle, the FINAL worktree reaches the project numeric design threshold by closing complete-option, refresh-truth, direct-recovery, palette-contrast, deletion, and sequential credential-verification gaps, but two Portal/Access concurrency-state P1s and missing physical-device/accessibility evidence prevent final release acceptance.

Keep (already strong, do NOT touch in this pass):
- Principle #2 (useful) scored 3 — Evidence: Home remains lesson-first at `ios/HOney/Features/Home/HomeView.swift:26-52,121-191`; unfiltered backend choices are uncapped and locally filterable at `packages/backend/src/experiences/entities.ts:81-104`, `packages/backend/src/experiences/experiences.test.ts:363-378`, and `ios/HOney/Features/Experiences/ExperiencesView.swift:228-335`; every Timetable lesson has teacher context at `ios/HOney/Features/Timetable/TimetableView.swift:558-563,624-683`. Regression check: Home still answers Now/Next first, search never becomes a gate, all choices remain browsable, and teacher fallback remains visible/accessibility-labelled.
- Principle #9 (environmentally friendly) scored 3 — Evidence: initial JS/idle attention are zero and Timetable/Experience caches coalesce work at `ios/HOney/Services/TimetableRepository.swift:44-120`, `ios/HOney/Features/Timetable/TimetableViewModel.swift:46-169`, and `ios/HOney/App/AppServices.swift:68-204`. Regression check: no idle animation, forced appearance, request-per-keystroke search, uncancelled fan-out, or stale cache write is introduced.

Fix in priority order (top 3–5 moves from the audit, verbatim):
1. **Principles #6 and #8 — Make Portal credential replacement/erase generation-safe:** Add an attempt generation, check cancellation/generation before saving any session and before assigning actor state, prevent an old caller's `defer` from clearing a newer task, await/retire obsolete work safely, and test replacement plus erase during a cancellation-ignoring in-flight login. Evidence: `ios/HOney/Services/PortalSessionCoordinator.swift:85-100,177-197`; `ios/HOneyTests/PortalSessionCoordinatorTests.swift:145-160`; §E3.
2. **Principles #2, #4, and #8 — Propagate Access credential state immediately:** After mutation/auth failure, refresh `connectionState` from the coordinator or return typed state with the failure so `Update school sign-in` appears in the same frame; add direct Portal recovery for interactive challenge and tests for permit/open credentialsRejected, challenge, and retry. Evidence: `ios/HOney/Features/Access/AccessViewModel.swift:140-162`; `ios/HOney/Features/Access/AccessView.swift:245-269`; §E3, §E6.
3. **Principles #8 and #9 — Make Access reads race-safe:** Coalesce equivalent refreshes, cancel/ignore obsolete permits and doors responses, keep each source's cached content while refreshing, and remove the duplicate permit/full Retry pair or give them genuinely separate scopes. Evidence: `AccessView.swift:43-46,63,208-212,260-264`; `AccessViewModel.swift:35-70`; §E1, §E7.
4. **Principles #2, #8, and #9 — Finish feed continuity:** Replace fixed first-page feeds with cursor/append, preserve scroll position across tab and entity navigation, keep loaded content during refresh, and test new-item/append/error/stale response behavior. Evidence: `ios/HOney/App/AppServices.swift:208-220`; `ios/HOney/Models/HOneyModels.swift:240-242`; `ios/HOney/Features/Experiences/ExperiencesView.swift:119-174`; §E7.
5. **Principles #3 and #8 — Close the evidence gap without redesigning passing surfaces:** Preserve lesson-first Home, four direct palettes, passing status chips, complete local filtering, and Timetable teacher fallback; capture signed-in light/dark physical-iPhone surfaces and run VoiceOver, Switch Control, Dynamic Type, Reduce Motion, Portal cold/warm, Access physical action, and device TTI verification. Evidence: §E4–E7.

Out of scope for this refine pass: Web visual redesign or cross-platform convergence, external school-portal probing beyond existing integration tests, final production wordmark/small-mark creation, unrelated moderation-policy redesign, deployment, merging, and committing personal `DEVELOPMENT_TEAM` configuration.

Deliverables for the plan:
- Per fix: exact state owner, target files, concurrency/cache contract, failure/race test, and user-visible verification.
- Generation-safe Portal replacement/erase with cancellation-ignoring in-flight tests.
- Immediate Access connection-state propagation and direct repair/Portal routes for action-time auth failures.
- Coalesced/generation-guarded Access reads with one clear retry per scope.
- Cursor/append/scroll-restoration feed contract and client states.
- Current signed-in four-palette screenshots, VoiceOver/Switch Control/Dynamic Type/Reduce Motion evidence, Portal cold/warm verification, Access physical-state verification, and device TTI.
- Regression proof that the score remains at least 22/30 with no unresolved load-bearing honesty/usefulness/understandability failure before final release acceptance.

Anti-patterns to guard against (specific to REFINE):
- Treating Task.cancel() as proof an external auth call stopped.
- Allowing an obsolete task to save or publish session state after replacement/erase.
- Showing repair copy without synchronizing the state that reveals its action.
- Starting overlapping Access refreshes without coalescing or a generation guard.
- Letting search become the only route to a target or reintroducing a silent result cap.
- Reusing one accent tuple across palettes or regressing the passing status-chip contrast.
- Treating 97 iOS tests, 105 backend tests, or source inference as signed-in physical-device visual/accessibility evidence.
```
