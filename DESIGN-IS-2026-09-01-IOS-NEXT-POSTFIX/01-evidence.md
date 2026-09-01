# HOney iOS POSTFIX evidence

Subagents gathered source and measured-build evidence without scoring. The orchestrator alone applies the Rams rubric.

## E1 — Structure and interaction counts

- Explore success state has `N + 2` controls: local search, Done, and one NavigationLink per rendered target. Partial/full-failure adds Retry, producing `N + 3`: `ios/HOney/Features/Experiences/ExperiencesView.swift:228-295`.
- Settings has nine base controls: Done, four palettes, Sign out, Delete, import toggle, and Update school sign-in; connected state adds Disconnect: `ios/HOney/Features/Settings/SettingsView.swift:43-49,83-99,141-215`.
- The school-sign-in sheet has four controls: username, password, Save/check, and Cancel: `SettingsView.swift:296-331`.
- Home has five baseline actions plus pull-to-refresh; error adds a direct retry: `ios/HOney/Features/Home/HomeView.swift:38-47,63-84,194-282`.
- Maximum observed primary component-tree depth is 13 nodes through the Access permit editor: `ios/HOney/Features/Access/AccessView.swift:32-70,124-157,502-545`.
- Three purposeful repeated-action groups remain: Access full refresh in three locations, Home reload via pull/direct retry, and Experience composition in toolbar/empty/feed-end states: `AccessView.swift:62,206-210,251-257`; `HomeView.swift:38-47,81-84`; `ExperiencesView.swift:36-39,127-140,156-164`.
- Three dead observable members remain: `HomeViewModel.nextLessonSummary`, `HomeViewModel.isLoading`, and `AccessViewModel.connectionState`: `ios/HOney/Features/Home/HomeViewModel.swift:15,28,44`; `ios/HOney/Features/Access/AccessViewModel.swift:18,40,69`. No unused import was confirmed manually.

## E2 — Complete options and Explore states

- Search is local-only. Empty query returns the entire fetched teacher/course/place/food arrays; nonempty query filters by title without making another search request: `ExperiencesView.swift:249-258,300-328`.
- Initial loading, full failure, partial failure, unavailable section, filtered no-match, genuine empty, successful list, and retry actions are separately represented: `ExperiencesView.swift:228-295`; `ios/HOney/Features/Experiences/ExperiencesViewModel.swift:39-62`.
- Partial behavior has a test: directory success plus entity failure keeps the teacher and marks the result incomplete: `ios/HOneyTests/ExperienceContractDecodingTests.swift:394-422`.
- The service records directory/entity success independently and gives complete results a 15-minute cache versus 30 seconds for partial results: `ios/HOney/App/AppServices.swift:50-139`.

### Remaining completeness defects

- The backend entity source silently caps an unfiltered list at 500 and returns a bare array with no continuation or completeness metadata: `packages/backend/src/experiences/entities.ts:81-102`; `packages/backend/src/routes/experiences.ts:52-58`.
- Therefore `Every available option is listed below` is not protocol-provable above 500 active entities, even though iOS renders every item it receives.
- During Retry with old data, `loadFilters()` clears the message but retains old arrays/availability. Because the loading branch requires all arrays to be empty, Explore temporarily labels stale pre-retry content as a complete current list: `ExperiencesViewModel.swift:39-62`; `ExperiencesView.swift:231-245`.

## E3 — Settings, credentials, and deletion truth

- Access copy now tells users to update the school sign-in in Settings: `ios/HOney/Features/Access/AccessViewModel.swift:150-175`.
- Settings exposes `Update school sign-in for Access` and a credential sheet with account/password fields, local-device explanation, disabled checking state, and outcome-specific feedback: `SettingsView.swift:170-215,284-367`.
- Deletion now distinguishes keeping all device data from erasing device data: `SettingsView.swift:62-76`.
- Erase-device-data calls `clearSavedCredentials`; the coordinator cancels login, clears memory, deletes stored Portal session and credentials, and enters `.noCredentials`: `ios/HOney/App/AppModel.swift:220-252`; `ios/HOney/Services/PortalSessionCoordinator.swift:92-99`.
- Coordinator clearing has a direct unit test: `ios/HOneyTests/PortalSessionCoordinatorTests.swift:130-143`.

### Remaining credential defect

- `Save and check connection` stores credentials, calls `restore()`, and dismisses on `.authenticated`: `SettingsView.swift:319-322,342-351`.
- `authorizeCredentials` does not invalidate the current or persisted Portal session. `restore()` reloads it, and `ensureFreshSession()` reuses it while still valid: `PortalSessionCoordinator.swift:83-90,101-109,162-167`.
- A valid old session can therefore make incorrect replacement credentials appear successfully checked. No replacement-while-valid-session test exists.
- The repair sheet is reachable from Settings, but Access has no Settings/reconnect route; with its navigation bar hidden, the user must leave Access, return Home, then open Settings: `AccessView.swift:32-45`; `HomeView.swift:63-91`; `SettingsView.swift:194-196`.

## E4 — Visual and contrast evidence (source-inferred)

- Named spacing scale remains `[4, 8, 12, 16, 20, 24]` pt: `ios/HOney/DesignSystem/AppTheme.swift:168-175`. Audited surfaces still add 2, 3, 5, 6, 7, 9, 10, 13, 14, 17, 18, 22, 28, and 32 pt values.
- Inferred semantic Dynamic Type base sizes remain `[11, 12, 13, 15, 17, 20, 28, 34]` pt: `AppTheme.swift:183-220`; `HomeView.swift:149-153`.
- The four palettes define 82 unique adaptive RGB triples including status colors; one active palette exposes 13 semantic roles: `AppTheme.swift:21-152`.
- Settings still renders all four choices directly with canvas/surface/accent swatches and selection state: `SettingsView.swift:83-124`.
- My Posts status chips now use `Palette.ink` on `Palette.surfaceMuted`, plus a small semantic dot and outline: `ios/HOney/Features/Experiences/MySubmissionsView.swift:275-288`.
- Calculated chip text/background contrast ranges from 11.62:1 to 15.41:1 across all palettes and appearances. Tests now assert ink-on-muted status-chip contrast for every palette: `ios/HOneyTests/SurfacePaletteTests.swift:27-49`.
- The semantic outline's `tint.opacity(0.72)` composite is not tested, but status is still communicated by passing text rather than outline alone.
- No rendered current-commit screenshot was available; palette beauty, spacing rhythm, truncation, and real compositing remain source-inferred.

## E5 — Copy and honesty

- Palette copy now says each accent is tuned for its surface; Home says `Open the school portal in the app`; Settings consistently says `the saved draft`: `SettingsView.swift:94-98,162-165,217-225`; `HomeView.swift:266-273`.
- Timetable still renders a teacher or honest fallback, including VoiceOver: `ios/HOney/Features/Timetable/TimetableView.swift:558-563,624-683`.
- Deletion labels map to keep/erase branches and credential cleanup (§E3).
- No marketing inflation, superlative, scarcity, forced continuity, hidden cost, or confirmshaming was found.
- Remaining jargon: `surface` and `accent` in Appearance, `direct Access reauthentication` in School data, and visible `Yours` rather than `Your posts`: `SettingsView.swift:97,212`; `ExperiencesView.swift:41-42`.
- Remaining claim-to-behavior mismatches are the credential check, the silent 500-item server cap, and stale-as-complete retry state (§E2–E3).

## E6 — State, retry, and accessibility evidence

- Loading/error/partial/genuine-empty/filtered-empty/success/focus/disabled/retry states exist across Explore, Settings reconnect, Home, and Access: `ExperiencesView.swift:228-295`; `SettingsView.swift:284-367`; `HomeView.swift:38-47,125-131,218-220`; `AccessView.swift:201-217,239-258`.
- `Why this space exists` now has a 44pt target: `ExperiencesView.swift:109-116`.
- Home direct retry forces a reload: `HomeView.swift:38-47`.
- Access direct retry remains incomplete:
  - permits retry is nested in the nonempty permits branch, so first-load failure with no rows shows no button: `AccessView.swift:201-217`;
  - a combined permits+doors error suppresses the gate retry: `AccessViewModel.swift:66-68`; `AccessView.swift:239-258`.
- Palette choices are 44pt native buttons with selected/not-selected accessibility values: `SettingsView.swift:83-124`.
- Reconnect has explicit username/password focus state and native disabled Save behavior: `SettingsView.swift:288-323,339`.
- Actual VoiceOver order, focus return, Full Keyboard Access, Switch Control, Dynamic Type extremes, Timetable compact lesson hit area, and Portal Web DOM remain unverified.

## E7 — Weight and runtime friction

- Native initial JavaScript is 0 bytes. Measured signed Debug artifact: arm64 Mach-O executable 91,968 bytes; `.app` directory 15,232 KiB.
- Cold signed-in Home performs five HOney-backend requests including `/me`, next lesson, class feed, directory, and entities; Portal restore adds zero with a reusable session or up to two auth calls: `ios/HOney/App/AppModel.swift:47-66`; `HomeViewModel.swift:30-60`; `AppServices.swift:94-130`.
- Cold direct Experiences performs three requests and warm-after-Home normally zero due repository reuse: `ExperiencesView.swift:45-50`; `AppServices.swift:94-130,192-235`.
- Access performs permits+doors again on each task/refresh, plus zero-to-two auth requests; Settings refreshes `/me` per presentation; target-result pages remain directly uncached: `AccessView.swift:42-45`; `AccessViewModel.swift:35-69,122-135`; `SettingsView.swift:57-61`; `ExperiencesView.swift:394-419`.
- Timetable retains 10-minute/45-day app cache, date coalescing, invalidation, 60ms rapid-input debounce, and adjacent prefetch: `ios/HOney/Services/TimetableRepository.swift:44-120`; `ios/HOney/Features/Timetable/TimetableViewModel.swift:84-169`.
- Experience metadata and feed caches/coalescing remain app-scoped: `AppServices.swift:70-139,165-242`.
- Feed still takes a fixed first 100 for `fromMyClasses`; no client cursor/append/scroll-restoration path exists: `AppServices.swift:206-220`.
- Idle animation, initial notification, badge, and modal counts remain 0. Numeric device TTI was not measured.
- Parent verification: signed arm64 **BUILD SUCCEEDED** and simulator **96 tests / 0 failures / TEST SUCCEEDED**.

## E8 — Per-principle facts

1. Innovative: anonymous device-key control, bounded Portal behavior, actor caches, and local non-gating filter improve familiar native patterns; no five-plus peer comparison exists.
2. Useful: current/next lesson remains direct; search does not gate fetched choices; Timetable teacher context is guaranteed. Access repair still adds a Home/Settings detour.
3. Aesthetic: semantic palettes and contrast-tested chips are coherent; broad one-off spacing, placeholder identity, and absent rendered evidence remain.
4. Understandable: Explore state wording and deletion scope improved; technical Appearance copy, `Yours`, indirect repair routing, and `Save and check` behavior leave bounded clarity gaps.
5. Unobtrusive: no idle decoration; optional search and quiet chips do not compete with content.
6. Honest: delete/palette/Portal/draft copy now maps well; credential verification, entity completeness, and retry freshness remain mismatched.
7. Long-lasting: semantic Apple styles and native controls dominate; placeholder brand remains temporary.
8. Thorough: the generic state family is substantially complete; credential replacement, retry-in-flight truth, and Access recovery branches remain rough.
9. Environmentally friendly: no initial JS/idle attention, adaptive appearance/Reduce Motion, and major caches/coalescing; several screen-level reads still repeat.
10. As little design as possible: lesson-first shell and complete local lists are restrained; technical helper copy and simultaneous redundant recovery instructions remain removable.

## Known gaps

- No P0 was found in source inspection.
- No fresh signed-in physical-iPhone screenshots, device TTI, Portal cold/warm timing, physical Access run, VoiceOver/Switch Control traversal, Dynamic Type captures, focus-return test, or live entity cardinality.
- No end-to-end account-deletion test seeds and verifies Portal cleanup; only coordinator clearing is directly tested.
- No UI test covers Explore full/partial/filter/empty/retry states.
- No test covers Timetable teacher fallback or the semantic chip outline composite.
