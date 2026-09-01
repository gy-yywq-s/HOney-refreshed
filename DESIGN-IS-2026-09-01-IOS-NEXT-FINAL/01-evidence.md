# HOney iOS FINAL evidence

Evidence subagents inspected the current worktree without modifying code or assigning scores.

## E1 — Structure

- Explore success has `N + 2` controls: search, Done, and one NavigationLink per choice. Complete failure has three; partial failure has `M + 3`: `ios/HOney/Features/Experiences/ExperiencesView.swift:228-301`.
- Settings has nine base controls and a tenth Disconnect when connected: `ios/HOney/Features/Settings/SettingsView.swift:43-49,83-99,141-215`.
- School reconnect has four controls: account, password, Save/check, Cancel: `SettingsView.swift:296-331`.
- Maximum observed component depth remains 13 through Access permit editing: `ios/HOney/Features/Access/AccessView.swift:33-70,111-123,559-641`.
- The clearest redundant pair is simultaneous `Try permits again` plus `Try Access again`, both calling full refresh: `AccessView.swift:208-212,260-264`.
- One dead parameter remains in changed priority code: `context` is passed to but unused by `AccessViewModel.handle`: `ios/HOney/Features/Access/AccessViewModel.swift:95,116,140-163`. No unused import was confirmed.

## E2 — Complete non-search-gated options

- Initial metadata load always shows `Loading every available choice`: `ExperiencesView.swift:231-239`.
- Refresh with retained choices shows `Refreshing available choices` and explicitly says the old choices remain visible while the complete list refreshes; complete-list copy is hidden until loading ends: `ExperiencesView.swift:231-251`.
- Full failure, partial failure, unavailable sections, filtered no-match, genuine empty, and Retry are distinct: `ExperiencesView.swift:241-301`; `ios/HOney/Features/Experiences/ExperiencesViewModel.swift:39-62`.
- Search filters the already-loaded local arrays. Empty query returns every fetched target and typing makes no alternate request: `ExperiencesView.swift:256-267,307-335`.
- The unfiltered backend entity query no longer has a cap: `packages/backend/src/experiences/entities.ts:81-104`.
- A backend regression test imports 510 entities and requires at least 510 in the unfiltered response: `packages/backend/src/experiences/experiences.test.ts:363-378`.
- User-directory teachers/courses/rooms are also returned without a limit: `packages/backend/src/services/timetable.ts:116-142`.
- The prior silent-500 and stale-as-complete defects are therefore closed in the audited normal/retry flows.

## E3 — Credential replacement, deletion, and direct recovery

- `authorizeCredentials` cancels and clears the current task reference, saves replacement credentials, clears in-memory and persisted old session, and sets `.restoring`: `ios/HOney/Services/PortalSessionCoordinator.swift:85-91`.
- Reconnect then calls `restore()` and dismisses only after `.authenticated`: `SettingsView.swift:342-361`.
- A sequential regression test proves a clock-valid old session is not reused and the replacement triggers one login: `ios/HOneyTests/PortalSessionCoordinatorTests.swift:145-160`.
- Erase-device-data clears Portal session and credentials through `clearSavedCredentials`: `ios/HOney/App/AppModel.swift:220-252`; `PortalSessionCoordinator.swift:93-100`.
- Access initial empty permit failure has Retry; combined permit/door failures have `Try Access again`; `.noCredentials` and `.userActionRequired` expose `Update school sign-in` and present the reconnect sheet directly: `AccessView.swift:121-123,205-223,245-269`.

### Residual in-flight race

- Cancellation is not awaited, and the old login task has no cancellation check or generation guard before login, identity, `vault.saveSession`, or the outer assignment to actor `session/state`: `PortalSessionCoordinator.swift:177-197`.
- If underlying auth ignores cooperative cancellation, an old in-flight task can finish after replacement or erase, write an old session back, and set `.authenticated`.
- The sequential replacement test does not exercise replacement/erasure during an active old login. The mock itself can ignore sleep cancellation: `ios/HOneyTests/TestDoubles.swift:32-35`.

### Residual action-time propagation

- Mutation failure handling changes the banner but does not refresh `AccessViewModel.connectionState`: `AccessViewModel.swift:140-162`.
- The direct reconnect button depends on that possibly stale local state: `AccessView.swift:265-269`.
- A credential rejection while applying/opening can therefore show Settings guidance but omit the direct repair button until a refresh.

## E4 — Visual system and contrast (source-inferred)

- Named spacing scale is `[4, 8, 12, 16, 20, 24]` pt, while targeted surfaces still use several one-off values: `ios/HOney/DesignSystem/AppTheme.swift:168-175`.
- Semantic Dynamic Type base sizes are approximately `[11, 12, 13, 15, 17, 20, 28, 34]` pt: `AppTheme.swift:183-220`; `ios/HOney/Features/Home/HomeView.swift:149-153`.
- Each of four palettes defines ten adaptive roles; three shared status colors bring one active palette to 13 semantic roles: `AppTheme.swift:21-152`.
- All four palettes remain directly selectable with swatches and Selected/Not selected accessibility values: `SettingsView.swift:83-124`.
- My Posts status chips use high-contrast ink on muted surface; core tests cover all palettes/appearances. Source-derived lowest inspected text pairing is approximately 4.85:1: `ios/HOney/Features/Experiences/MySubmissionsView.swift:275-288`; `ios/HOneyTests/SurfacePaletteTests.swift:27-61`.
- Home atmosphere remains shallow and background-only: `AppTheme.swift:160-165`; `HomeView.swift:20-25`.
- No current rendered device capture exists; palette beauty, exact compositing, truncation, and rhythm remain inferred.

## E5 — Copy, honesty, and teacher truth

- Explore loading/refresh/partial/empty/search copy maps to the states in §E2.
- Deletion labels distinguish keeping versus erasing device data and map to cleanup behavior: `SettingsView.swift:62-76`; §E3.
- Appearance, saved-draft, and Portal wording remain corrected: `SettingsView.swift:94-98,151-165,217-225`; `HomeView.swift:257-282`.
- Every Timetable lesson card includes a teacher or `Teacher not listed`; VoiceOver receives the same fallback: `ios/HOney/Features/Timetable/TimetableView.swift:558-563,624-683`.
- No marketing superlative, scarcity, hidden cost, confirmshaming, forced continuity, or unsupported value claim was found.
- Bounded jargon remains: `accent tuned for its surface`, `direct Access reauthentication`, and visible `Yours` instead of `Your posts`: `SettingsView.swift:97,212`; `ExperiencesView.swift:41-42`.
- The in-flight credential race remains the single load-bearing claim/behavior family that can violate `Save and check` or `erase data on this iPhone` (§E3).

## E6 — States and accessibility

- Empty, loading, refreshing, partial, error, success, focus, disabled, filtered empty, genuine empty, and retry states are represented across Explore, reconnect, Home, and Access: `ExperiencesView.swift:228-301`; `SettingsView.swift:296-365`; `HomeView.swift:38-47`; `AccessView.swift:205-269`.
- Palette buttons are 44pt native controls with explicit selected values: `SettingsView.swift:83-124`.
- Reconnect uses username/password FocusState and disabled Save/check: `SettingsView.swift:288-323`.
- Access confirmation names the actual server-provided door and identifies the physical action: `AccessView.swift:74-109`.
- Timetable cards expose composed subject/teacher/time/room labels: `TimetableView.swift:404-415,558-563`.
- Actual VoiceOver order, focus return, Full Keyboard Access, Switch Control, accessibility Dynamic Type, compact Timetable hit areas, and Portal Web DOM remain unverified.

## E7 — Weight and runtime friction

- Native initial JavaScript, idle animations, initial notifications, badges, and auto-presented modals are all zero.
- Cold Experiences performs three parallel logical reads—feed, directory, entities; warm within repository TTL normally performs zero: `ExperiencesView.swift:45-50`; `ios/HOney/App/AppServices.swift:68-139,141-204`.
- Access refresh performs permits and doors plus zero-to-two auth calls: `AccessViewModel.swift:35-69,122-135`.
- Access has no request coalescing/generation guard; overlapping task, pull, permits Retry, and full Retry can overwrite state out of order: `AccessView.swift:43-46,63,208-212,260-264`; `AccessViewModel.swift:35-70`.
- Timetable retains cache-first display, cancellation, generation guard, 60ms rapid-input debounce, and adjacent prefetch: `ios/HOney/Features/Timetable/TimetableViewModel.swift:46-169`.
- Feed response still has no continuation cursor; My Classes takes a fixed first 100 and the UI has no append/scroll-restoration path: `AppServices.swift:208-220`; `ios/HOney/Models/HOneyModels.swift:240-242`; `ExperiencesView.swift:119-174`.
- Numeric device TTI was not measured. Parent-confirmed verification is recorded in scope.

## E8 — Per-principle facts

1. Innovative: anonymous device-key control, bounded Portal behavior, actor caches, non-replayed mutations, and local non-gating filters improve familiar native patterns; no peer-comparison proof establishes novelty.
2. Useful: current/next lesson is direct, choices are complete without search gating, Timetable teacher context is guaranteed, and normal Access failures have direct recovery. Feed continuation and one action-time recovery edge remain.
3. Aesthetic: semantic palettes and passing chips are coherent; broad one-off spacing, placeholder identity, and absent rendered evidence remain.
4. Understandable: loading/refresh/partial/empty/deletion/reconnect language is explicit; a few technical labels and action-time reconnect visibility remain bounded clarity issues.
5. Unobtrusive: no idle decoration; Home color stays behind content; optional search and status colors are restrained.
6. Honest: complete-list, teacher, palette, deletion, and normal sequential credential behavior map correctly; the in-flight session race remains one load-bearing mismatch family.
7. Long-lasting: native controls, semantic tokens, and system typography dominate; placeholder identity remains temporary.
8. Thorough: generic and advanced states are substantially complete; in-flight credential replacement/erase and action-time connection-state propagation remain rough.
9. Environmentally friendly: no initial JS/idle attention; major data paths cache/coalesce; Access and first-page feed continuity remain unfinished.
10. As little design as possible: lesson-first Home and complete local filtering are restrained; duplicate permit/full Retry and technical helper copy remain removable.

## Known gaps

- No P0 was found in source inspection.
- No fresh signed-in physical-iPhone screenshots, device TTI, physical Portal cold/warm timing, Access physical-action run, VoiceOver/Switch Control/Full Keyboard Access traversal, Dynamic Type captures, or focus-return evidence.
- No test replaces or clears credentials during an actually in-flight, cancellation-ignoring login.
- No UI test covers all Explore state combinations or direct reconnect after an action-time credential failure.
- No UI test covers Timetable's teacher fallback or 510-option rendering.
