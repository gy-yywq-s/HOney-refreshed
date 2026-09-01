```text
/make-plan Refine HOney iOS based on a post-review Dieter Rams audit (total 20/30).

Verdict paragraph (quoted from 03-verdict.md):
> REFINE — At 20/30 with no zero-scored principle, the review-driven iOS rebuild now has a viable lesson-first, feed-first and cache-aware foundation, but option-list truth, recovery/deletion routing, dark-palette accessibility, bounded request behavior, and current physical-device evidence must be resolved before acceptance.

Keep (already strong, do NOT touch in this pass):
- Principle #2 (useful) scored 3 — Evidence: current/next lesson is Home's first substantive object at `ios/HOney/Features/Home/HomeView.swift:27-46,115-184`; all Explore categories and Timetable teacher states are directly represented at `ios/HOney/Features/Experiences/ExperiencesView.swift:233-305` and `ios/HOney/Features/Timetable/TimetableView.swift:624-683`. Regression check: verify Home still answers Now/Next first, every selectable option remains reachable without search, and every lesson card retains a teacher or `Teacher not listed`.
- Principle #9 (environmentally friendly) scored 3 — Evidence: no idle attention, adaptive appearance/Reduce Motion, and cached/coalesced Timetable and Experience repositories at `ios/HOney/DesignSystem/AppTheme.swift:115-165,223-231`, `ios/HOney/Features/Access/AccessView.swift:11,216-219,303-310`, `ios/HOney/Services/TimetableRepository.swift:19-121`, and `ios/HOney/App/AppServices.swift:59-225`. Regression check: confirm no idle animation, forced appearance, uncancelled request fan-out, or cache-invalidated stale write is introduced.

Fix in priority order (top 3–5 moves from the audit, verbatim):
1. **Principles #4, #6, and #8 — Make complete choice lists behaviorally true:** Preserve direct grouped access to every selectable teacher, course, place, food item, and Surface palette; add an optional non-gating search/filter for long lists; and distinguish metadata loading, failure, partial results, and genuine empty with retry. Evidence: `ios/HOney/Features/Experiences/ExperiencesView.swift:233-305`; `ios/HOney/App/AppServices.swift:97-106`; `ios/HOney/Features/Experiences/ExperiencesViewModel.swift:35-43`.
2. **Principles #4 and #6 — Align recovery and deletion words with reachable behavior:** Either add a real school-credential reconnect route in Settings or point to a reachable Login/Portal action; make account/local-data deletion explicitly include or exclude saved school credentials; replace `blue accent` and `OASIS` with behaviorally accurate plain language; and use singular draft wording while storage remains one slot. Evidence: `ios/HOney/Features/Access/AccessViewModel.swift:152-157,171-174`; `ios/HOney/Features/Settings/SettingsView.swift:61-75,91-94,161,166-205`; `ios/HOney/App/AppModel.swift:220-250`; `ios/HOney/Features/Home/HomeView.swift:250-265`; `ios/HOney/Services/ComposerDraftStore.swift:3-11,44-52`.
3. **Principles #3 and #8 — Make all four Surface choices visually and accessibly real:** Repair the Blue Mist/Sage Gray dark error-chip contrast, retain independently tuned accents, then capture signed-in light/dark Home, Experiences, Timetable, Access, Settings, Login, and destructive/recovery states on a real iPhone before further aesthetic claims. Evidence: `ios/HOney/DesignSystem/AppTheme.swift:59-110`; `ios/HOney/Features/Experiences/MySubmissionsView.swift:14-35,275-282`; `ios/HOneyTests/SurfacePaletteTests.swift:27-59`; §E7.
4. **Principles #2, #8, and #9 — Finish navigation and request continuity:** Keep previously loaded content during refresh; add safe app-scoped caching where repeated Settings, History, target-result, Access-read, or next-lesson requests are unnecessary; replace the 100-item feed with cursor append and scroll restoration; and make course sharing plus direct error retry reachable without a gesture-only detour. Evidence: `ios/HOney/App/AppServices.swift:145-225`; `ios/HOney/Features/Home/HomeViewModel.swift:30-59`; `ios/HOney/Features/Experiences/ExperiencesView.swift:217-223,370-395`; `ios/HOney/Features/Timetable/TimetableViewModel.swift:93-169`; §E2, §E6.
5. **Principle #8 — Close the runtime evidence gap:** On the current commit, measure app TTI and Portal cold/warm recovery, exercise Access once-only/unknown-outcome paths, run VoiceOver/Switch Control/Dynamic Type/Reduce Motion and small-device passes, verify teacher fallback/hit targets, and capture all four palettes; source presence and 94 passing tests do not replace this evidence. Evidence: §E5, §E7; `ios/HOney/Features/Timetable/TimetableView.swift:404-415,541-545`; `ios/HOney/Features/Home/PortalWebView.swift:129-216,337-448`.

Out of scope for this refine pass: Web redesign or cross-platform visual convergence, external school-portal probing, final owner-supplied production wordmark/small-mark creation, backend social-policy redesign unrelated to the cited iOS behavior, deployment, merging, and committing personal `DEVELOPMENT_TEAM` configuration.

Deliverables for the plan:
- Per fix: target files, exact behavioral/copy change, state owner, failure/race test, and runtime verification.
- A complete grouped Explore list with optional non-gating filter, explicit metadata loading/error/partial/empty states, and retry.
- Reachable credential-recovery behavior plus exact account/local/credential deletion semantics.
- Passing contrast tests for every palette/status-chip pairing and real signed-in palette screenshots.
- Request/cache policy table for Home, History, Access, Settings, Experience targets and feeds; cursor/append/scroll-restoration design where contract work is required.
- VoiceOver, Switch Control, Dynamic Type, Reduce Motion, small-device, Timetable teacher fallback/hit-target, Portal timing, Access mutation, and TTI evidence.
- Regression checklist for every Keep item and proof that the design reaches at least 22/30 without a load-bearing honesty/usefulness/understandability failure.

Anti-patterns to guard against (specific to REFINE):
- Hiding options behind search; search may only filter a complete reachable set.
- Treating a metadata request failure as a genuine empty list.
- Reusing one unchanged accent tuple across Surface palettes or removing the palette choices.
- Changing copy without making the referenced recovery/deletion action reachable.
- Adding new caches without scope invalidation, coalescing, stale-response protection, or truthful refresh state.
- Restyling lesson-first Home or rebuilding working Portal/Timetable architecture instead of closing the bounded gaps.
- Treating source checks, simulator-only output, or the reported 94 tests as physical-device visual/accessibility proof.
```
