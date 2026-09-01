```text
/make-plan Refine HOney iOS based on a POSTFIX Dieter Rams audit (total 21/30).

Verdict paragraph (quoted from 03-verdict.md):
> REFINE — At 21/30 with no zero-scored principle, the POSTFIX has made Explore states, deletion scope, direct recovery, palette contrast, and copy materially more coherent, but credential verification, provable option completeness, retry freshness, and Access recovery still prevent the design from reaching the 22/30 acceptance threshold.

Keep (already strong, do NOT touch in this pass):
- Principle #2 (useful) scored 3 — Evidence: Home remains lesson-first at `ios/HOney/Features/Home/HomeView.swift:27-52,121-191`; search returns the full fetched list when empty at `ios/HOney/Features/Experiences/ExperiencesView.swift:249-328`; Timetable always renders teacher or fallback at `ios/HOney/Features/Timetable/TimetableView.swift:558-563,624-683`. Regression check: Home still answers Now/Next first, search never becomes a gate, all completed pages remain directly browsable, and every lesson retains teacher context.
- Principle #9 (environmentally friendly) scored 3 — Evidence: initial JS/idle attention are zero and Timetable/Experience caches coalesce work at `ios/HOney/Services/TimetableRepository.swift:44-120`, `ios/HOney/Features/Timetable/TimetableViewModel.swift:84-169`, and `ios/HOney/App/AppServices.swift:70-139,165-242`. Regression check: no idle animation, forced appearance, request-per-keystroke search, uncancelled fan-out, or stale cache write is introduced.

Fix in priority order (top 3–5 moves from the audit, verbatim):
1. **Principles #4 and #6 — Force-check replacement credentials:** Invalidate the old Portal session when credentials change, authenticate with the new pair before dismissing, preserve precise offline/manual-challenge outcomes, expose the repair action directly from Access, and add a valid-old-session/wrong-new-password regression test. Evidence: `ios/HOney/Features/Settings/SettingsView.swift:319-365`; `ios/HOney/Services/PortalSessionCoordinator.swift:83-109,162-167`; §E3.
2. **Principles #2, #4, and #6 — Make “every option” protocol-verifiable:** Replace the silent 500-entity cap with explicit pagination/completeness metadata, render every page through a complete grouped/progressively disclosed list, and keep search as a local convenience rather than a discovery gate. Evidence: `packages/backend/src/experiences/entities.ts:81-102`; `packages/backend/src/routes/experiences.ts:52-58`; `ios/HOney/Features/Experiences/ExperiencesView.swift:249-328`; §E2.
3. **Principles #6 and #8 — Represent retry freshness truthfully:** Preserve old choices during retry if desired, but show a visible refreshing/stale state and never claim the list is complete until the new complete response arrives; add full, partial, filtered-empty, genuine-empty, retry-in-flight, and retry-recovery tests. Evidence: `ios/HOney/Features/Experiences/ExperiencesViewModel.swift:39-62`; `ios/HOney/Features/Experiences/ExperiencesView.swift:231-245`; §E2, §E6.
4. **Principles #2 and #8 — Complete direct Access recovery:** Put retry outside the nonempty permits branch, preserve a reachable retry when both sources fail, route credential failures directly to the repair sheet, and verify first-load, partial, combined, and repeated-retry states. Evidence: `ios/HOney/Features/Access/AccessView.swift:201-258`; `ios/HOney/Features/Access/AccessViewModel.swift:66-68,150-175`; §E6.
5. **Principles #3, #8, and #9 — Finish evidence and continuity:** Preserve the passing four-palette chip treatment, then capture signed-in light/dark iPhone surfaces and accessibility states; add cursor feed/append/scroll restoration and only safe, scoped caches for repeated Access, Settings, and target-result reads. Evidence: `ios/HOney/Features/Experiences/MySubmissionsView.swift:275-288`; `ios/HOneyTests/SurfacePaletteTests.swift:27-49`; `ios/HOney/App/AppServices.swift:165-242`; §E4, §E7.

Out of scope for this refine pass: Web visual redesign or cross-platform convergence, external school-portal probing, final production wordmark/small-mark creation, unrelated moderation-policy redesign, deployment, merging, and committing personal `DEVELOPMENT_TEAM` configuration.

Deliverables for the plan:
- Per fix: exact state owner, target files, contract or behavior change, failure/race test, and user-visible verification.
- A credential-replacement state machine that cannot reuse an old session to validate a new password, plus a direct Access repair route.
- A paginated/completeness-aware entity contract whose entire selectable set remains browsable without search.
- Explicit stale/refreshing Explore state and complete state-matrix tests.
- Direct Access retry in first, partial, and combined failures.
- Cursor/append/scroll-restoration and a scoped request/cache table for remaining repeated reads.
- Current signed-in four-palette screenshots, VoiceOver/Switch Control/Dynamic Type/Reduce Motion evidence, Portal cold/warm verification, Access physical-state verification, and device TTI.
- Regression proof that the design reaches at least 22/30 with no load-bearing honesty/usefulness/understandability failure.

Anti-patterns to guard against (specific to REFINE):
- Calling the first 500 entities “every option.”
- Letting search become the only route to a target.
- Saving credentials and treating an unrelated old session as proof they work.
- Clearing stale content without need, or preserving it while falsely calling it current/complete.
- Adding retry copy without placing a reachable retry in every failure branch.
- Reusing one unchanged accent tuple across palettes or regressing the passing chip contrast.
- Adding caches without scope invalidation, coalescing, stale-response protection, and truthful refresh state.
- Treating 96 passing tests or source inference as signed-in physical-device visual/accessibility evidence.
```
