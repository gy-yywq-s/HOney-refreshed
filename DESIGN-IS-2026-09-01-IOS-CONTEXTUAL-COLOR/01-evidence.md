# Evidence

Two evidence subagents inspected the final working tree and the correct Web reference. They supplied facts only; the orchestrator performed all scoring. Findings without a file, line range, screenshot region, or explicit measurement method were excluded.

## Sources and evidence mode

- SwiftUI scope: `ios/HOney/Features/{Home,Timetable,History,Experiences,Access,Settings}`, `ios/HOney/DesignSystem`, `ios/HOney/App`, related services/models, and tests.
- Correct reference: `origin/integration/product-v2@4f0c4876a16b6ddedeccb7e28cf7f02021536caa`, `apps/web` only. `web-ionic` was not inspected.
- Observed Web screenshot: `/private/tmp/honey-gaelisus-home-2026-09-01.png`, 1496×850; Home content x315–1395/y38–560 and hero x315–1395/y121–322.
- No fresh signed-in iOS screenshot exists. Every iOS visual/compositional statement below is **INFERRED from source**. `/private/tmp/honey-ios-home-current.png` is Login and was explicitly rejected as Home evidence.

## Structural evidence

Counting method: controls are counted in the nominal loaded state; server-sized rows are variables. Static depth expands helper/custom-view bodies, counts the root and terminal leaf, and does not pretend to be a runtime SwiftUI graph.

| Surface | Interactive elements | Static max depth | Evidence |
|---|---:|---:|---|
| Home | 6 fixed, +1 conditional retry | 11 | Refresh/Settings at `ios/HOney/Features/Home/HomeView.swift:63-86`; See all at `:230-237`; Share/Access at `:265-293`; Portal at `:295-319`; retry at `:38-46`. |
| Timetable | 12 + one per lesson, +1 conditional retry | 12 | Header/date controls at `ios/HOney/Features/Timetable/TimetableView.swift:68-133`; lesson buttons/cards at `:139-152,372-467`; retry at `:44-52`. |
| Experiences | 8 + three row actions per visible post | 9 | Toolbar at `ios/HOney/Features/Experiences/ExperiencesView.swift:28-44`; feed selector/refresh at `:82-108`; Why at `:120-131`; mutually exclusive Share CTA at `:142-182`; row actions at `InteractiveExperienceRow.swift:21-79`. |
| Explore | 2 + one link per rendered target, +1 conditional retry | 8 | Complete grouped list/search at `ExperiencesView.swift:243-350`. |
| History | 4 + one per lesson; selection adds Cancel; filter failure adds retry | 13 | Toolbar, rows, search and complete menus at `ios/HOney/Features/History/HistoryView.swift:21-151`. |
| Access | 7 + approved permit Open controls; conditionals add retries/reconnect/show-all/doors | 12 | Header at `AccessView.swift:50-93`; draft at `:148-197`; permits at `:206-260,446-510`; access actions/gates at `:311-350,673-790`. |
| Settings | 11 disconnected / 12 connected | 7 | Done at `SettingsView.swift:44-50`; six palette buttons at `:84-127`; account/school controls at `:144-218`. |

### Required interaction checks

- Whole-screen pull-to-refresh count: **0**. Repo search found no `.refreshable`; each network surface uses a compact explicit button (`HomeView.swift:63-80`; `TimetableView.swift:85-94`; `ExperiencesView.swift:95-107`; `HistoryView.swift:36-48`; `AccessView.swift:59-71`).
- Broad Timetable day-swipe count: **0**. Repo search found no `DragGesture`. Day changes use arrows, a today shortcut and seven explicit dates (`TimetableView.swift:68-133,273-367`). Access's only scoped gesture is a tap that collapses its gate picker, not navigation (`AccessView.swift:91-94`).
- Every lesson is one bounded card and button (`TimetableView.swift:139-152,372-467`). The face and VoiceOver label contain subject, time, teacher or `Teacher not listed`, optional room and current state (`:385-460`).
- All six palettes are shown directly: six `CaseIterable` cases/titles (`ios/HOney/DesignSystem/AppTheme.swift:37-57`) feed an unfiltered `ForEach` (`SettingsView.swift:84-100`).
- Same-purpose repeated patterns: explicit refresh appears on six scoped surfaces; Experiences has two mutually exclusive Share placements; Access can expose header refresh plus permit and combined retry after partial failure (`AccessView.swift:59-71,225-233,280-284`).
- Latest static unused-property scan found one remaining dead presentation property: `TimetableViewModel.lastSyncedAt` is assigned but not read by the view (`TimetableViewModel.swift:19-24,147-153`; `TimetableView.swift:39-157`). No scoped unused import was found by lexical scan; this was not a compiler-warning run.

## Visual evidence

### Type and spacing

- Core spacing tokens are 4/8/12/16/20/24pt (`AppTheme.swift:227-234`). Local compositions also use 2/3/5/6/7/9/10/13/14/17/18/22/28/32; examples are Home's 24pt page rhythm, 20pt hero padding, 22pt hero internal gap and 14pt feed row (`HomeView.swift:26-57,157-203,239-250`) and Timetable's 14/10/13/7 values (`TimetableView.swift:40-64,127-154,385-440`). A core system exists, but local values are not fully consolidated.
- Typography is almost entirely SwiftUI semantic type: approximately 34/28/20/17/15/13/12/11pt for largeTitle/title/title3/headline/subheadline/footnote/caption/caption2 (`AppTheme.swift:242-280`). Home's subject is semantic largeTitle (`HomeView.swift:178-183`).
- No small-uppercase implementation exists: source search found zero `.uppercased`, `.smallCaps`, or uppercase transform. `.textCase(nil)` explicitly suppresses native uppercase in Compose, Explore, Report and Settings (`ComposeExperienceView.swift:367`; `ExperiencesView.swift:276`; `ReportSheet.swift:67`; `SettingsView.swift:39,328`).

### Color and Home composition

- Six palettes each define canvas, surface, muted, ink, secondary ink, primary/soft/foreground accent, three supporting accents, line and control border for light and dark (`AppTheme.swift:21-35,64-162`). Source contains 156 unique RGB tuples; one active appearance uses 15–16 base solids, while Settings previews five swatches for each palette (`SettingsView.swift:103-135`).
- Supporting color mapping is explicit: interaction=primary, community=secondary, Access=tertiary, Portal=quaternary; schedule color is stable by course/subject key (`AppTheme.swift:214-224`). Home applies community/Access/Portal markers to their corresponding actions (`HomeView.swift:265-300`), and Timetable reuses the stable course marker (`TimetableView.swift:372-438`). The schedule hash is a stable category marker, not a business-state color.
- **INFERRED Home:** `PageBackground` is only `Palette.canvas`, with no gradient (`ios/HOney/DesignSystem/AppComponents.swift:223-227`). The hero uses the same palette's surface at 72% alpha, a 72% hairline and a narrow 3pt course marker (`HomeView.swift:142-227`). It is not the former pure-white bordered card isolated on a gradient ground.
- **INFERRED Home:** screen order is greeting → truthful notices → lesson hero → at most two class experiences → two quiet actions → Portal (`HomeView.swift:20-57,230-319`). The hero remains the sole dominant object; the feed is hairline-separated and secondary actions have no large opaque fill.
- **OBSERVED Web reference:** the hero is the largest card, but its ground and surrounding page are both near-white; the feed is unboxed and the CTA/Portal are lighter. Therefore the hero is focal without appearing as an isolated white patch. Evidence: screenshot regions above; source at `HomePage.tsx:44-148` and `components.css:25-35` at the fixed ref.
- The Web reference is not literal guidance: it still contains 11px uppercase eyebrows and an infinite progress-wash animation (`foundations.css:103-113`; `features.css:83-108`; `components.css:217-245` at the fixed ref), which current iOS correctly does not copy.

### Contrast measurements

Method matches `ios/HOneyTests/SurfacePaletteTests.swift:77-89`: linearized sRGB relative luminance, `(Lmax+0.05)/(Lmin+0.05)`. Normal text threshold is 4.5:1; control boundary threshold is 3:1.

Each row is light/dark for ink on canvas, secondary ink on canvas, minimum detail accent on canvas, accent foreground on accent, and accent on accentSoft:

| Palette | Light ratios | Dark ratios | Result |
|---|---|---|---|
| Porcelain | 14.23 / 6.47 / 5.91 / 6.95 / 5.62 | 15.70 / 9.65 / 7.43 / 7.37 / 5.12 | Pass |
| Clean White | 16.55 / 7.20 / 5.36 / 6.49 / 5.40 | 16.86 / 10.18 / 7.80 / 7.51 / 5.16 | Pass |
| Blue Mist | 13.17 / 5.92 / 4.97 / 6.37 / 4.98 | 15.52 / 9.89 / 7.72 / 7.97 / 5.41 | Pass |
| Sage Gray | 12.72 / 5.70 / 5.40 / 6.14 / 4.89 | 15.42 / 9.80 / 7.43 / 8.11 / 5.41 | Pass |
| Warm Paper | 16.27 / 7.25 / 5.52 / 6.08 / 4.91 | 15.85 / 9.04 / 7.76 / 8.03 / 5.09 | Pass |
| Original Blue | 12.05 / 6.46 / 4.77 / 6.40 / 5.10 | 15.74 / 9.63 / 7.83 / 8.40 / 5.68 | Pass |

- Lowest primary ink across canvas/surface/muted is 10.84:1; lowest secondary text is 5.20:1; lowest detail color is 4.77:1.
- Semantic text on its 10% tint: success ≥6.41, warning ≥6.20, error ≥4.90. Test assertions cover all palettes/light-dark/core text/control borders/status/detail accents (`SurfacePaletteTests.swift:27-65`). Tests were inspected, not executed by the audit team.

## State, cache and runtime evidence

- Startup distinguishes a genuinely rejected/missing session from a temporary `/me` failure. Only authentication rejection enters signed-out; temporary failure retains the device session and presents `HOney is temporarily unavailable` with `Try again` (`ios/HOney/App/AppModel.swift:46-86`; `ios/HOney/App/RootView.swift:18-42`). Tests cover both temporary 503 retention and rejected-session sign-out (`ios/HOneyTests/AppModelLifecycleTests.swift:44-67`).
- Home shows initial loading, full/partial error, loaded, genuine empty and disabled refresh. It retains successful lesson/feed values during failed refresh, generation-checks late results, shows teacher fallback, refreshes at lesson end, and represents an expired retained lesson as `Last known lesson` / `Ended · refresh unavailable` (`HomeView.swift:38-49,63-100,142-235,327-347`; `HomeViewModel.swift:31-72`). A regression test exercises retained content on refresh failure (`ios/HOneyTests/NextLessonFormattingTests.swift:55-109`).
- Timetable shows loading/refresh/error+retry/empty/loaded; it caches 45 days for 10 minutes, coalesces per day, rejects stale responses, debounces a cold miss 60ms, preserves cached content during refresh and prefetches adjacent days after 180ms (`TimetableViewModel.swift:46-169`; `ios/HOney/Services/TimetableRepository.swift:19-121`). Tests cover stale response, view recreation, ABA, adjacent prefetch and empty-day caching (`TimetableViewModelTests.swift:54-144`).
- Experiences shows loading/full failure/genuine empty/loaded-with-refresh-failure, and Explore distinguishes complete, partial, failed and filtered-no-match states (`ExperiencesView.swift:95-188,243-321`; `ExperiencesViewModel.swift:40-89`). Its feed repository has a five-minute per-scope cache and coalescing (`ios/HOney/App/AppServices.swift:333-450`).
- History uses a ten-minute cache keyed by query/teacher/course/order, coalesces same-key requests, generation-checks late responses, and retains lessons on refresh failure (`AppServices.swift:132-215`; `HistoryViewModel.swift:67-92`).
- Access has explicit local refresh, coalesces simultaneous attempts, fetches permits/doors concurrently, retains arrays but marks each stale source unusable after failure, confirms the portal-provided door name, and treats mutation timeout as unknown outcome (`AccessViewModel.swift:36-85,87-195`; `AccessView.swift:94-143,225-289,359-388`).
- Cold request counts inferred from source: signed-in bootstrap 1 `/me`; Home 4 endpoints (lesson, feed, directory, entities); Experiences 3; Timetable 1 visible day plus up to 2 delayed prefetches; History 3; Access 2 safe reads plus conditional auth; Settings 1 profile. Fresh Home/Experiences/History/Timetable revisits can be zero within freshness windows. Citations: `AppModel.swift:45-68`; `HomeViewModel.swift:31-72`; `ExperiencesView.swift:45-50`; `HistoryView.swift:50-54`; `AccessViewModel.swift:50-59`; repository ranges above.
- iOS initial JS bytes: not applicable. Web reference JS bytes were not measured because the exact ref has no committed production bundle (`apps/web/package.json:6-11` at the fixed ref).
- Measured iOS TTI: unavailable. Home renders its shell while `.task` loads data; School Portal has an `os_signpost` and a 12-second hard deadline but no captured timing (`HomeView.swift:20-105`; `PortalWebView.swift:37-49,129-170`).
- Idle animation count on loaded iOS screens: 0. `enableAnimations=false`; Access additionally gates custom transitions with Reduce Motion (`ios/HOney/App/AppConfig.swift:14-18`; `AccessView.swift:247,349,365,393`). Initial Home has zero badges, notifications or modals in the nominal state (`HomeView.swift:13-18,106-124`; `MainTabView.swift:18-40`).

## Copy and honesty evidence

### Complete static-copy inventory by surface

The copy subagent searched every scoped `Text`, `Button`, `Label`, navigation title, accessibility label/value/hint, dialog message, banner/error assignment and display-string computed property. Dynamic profile, date, directory, entity and server-response strings are identified as dynamic rather than guessed.

- Startup/Home: startup loading/unavailable/retry copy at `RootView.swift:19-35` and saved-session notice at `AppModel.swift:72-76`; Home retry/refresh/settings/greeting/loading/Now/Next/progress/errors/empty/feed/share/Access/Portal/teacher/time strings at `HomeView.swift:41-85,130-235,253-319,327-347,388-430`; refresh errors at `HomeViewModel.swift:63-67`; account/sync notices at `AppModel.swift:111,120-122,138,150,193,284-285`.
- Timetable and lesson detail: retry/updating/refresh/history/empty/date selection/day movement/current/teacher/period/detail/loading strings at `TimetableView.swift:47-99,136-167,233-240,303-366,416-480`; lesson-detail strings at `LessonDetailView.swift:24-84,128-155`. Subject/topic/teacher/room/date are dynamic.
- History: title/cancel/refresh/filter retry/loading/empty/search/all/filter strings at `HistoryView.swift:26-47,70-83,122-147`; dynamic month/lesson/directory copy at `:85-109,132-169`; errors at `HistoryViewModel.swift:60,87-89`.
- Experiences hub/Explore/results/About: toolbar/feed/identity/empty/share/choice completeness/search/result and all About sections at `ExperiencesView.swift:25-178,220-225,247-305,366-514`; metadata/feed errors at `ExperiencesViewModel.swift:53-57,84-86`.
- Experience rows, compose, reporting and My Posts: provenance/rating/reaction strings at `ExperienceRow.swift:26-67` and `InteractiveExperienceRow.swift:28-79`; compose/recovery/privacy/nudge/cooldown/action strings at `ComposeExperienceView.swift:34-448` and `ComposeExperienceViewModel.swift:72-419`; submit mappings at `ExperienceSubmitCopy.swift:13-32`; reporting at `ReportSheet.swift:27-95`; My Posts status/dialog/action/security copy at `MySubmissionsView.swift:19-363`; report-category/provenance/target fallbacks at `HOneyModels.swift:188-195,281-294,475-495`.
- Access: refresh/gate/permit dialogs, draft fields, permit/status/recovery/action/gate/editor strings at `AccessView.swift:39-129,151-201,212-289,297-509,521-529,597-667,739-778`; response/error mappings at `AccessViewModel.swift:68-82,101-195`. Portal `displayMessage` is dynamic.
- Settings: settings/delete/appearance/six palette/account/school/privacy/about/reconnect strings at `SettingsView.swift:42-243,256-270,281,299-369` plus palette titles at `AppTheme.swift:49-57`. Profile/id/date/version are dynamic.
- Main navigation/brand: four tabs at `MainTabView.swift:24-37`; wordmark accessibility label at `AppComponents.swift:229-241`.

### Flags and label-to-behavior mismatches

- No marketing superlative and no forced continuity, hidden cost, fake scarcity or confirmshaming was found. Destructive and physical actions use confirmation and explicit consequence copy (`SettingsView.swift:63-77`; `MySubmissionsView.swift:109-130`; `AccessView.swift:94-129`).
- `ends after it starts — that is the whole rule.` overstates known school rules (`AccessView.swift:643`). Plain replacement: `End time must be after the start time.`
- Visible Timetable week range invokes `goToToday()`; only VoiceOver says this (`TimetableView.swift:114-116,347-367`). Either show `Today` visibly or make the range open a real chooser.
- `Yours` opens posts and private notes (`ExperiencesView.swift:41-42`). Plain replacement: `Your posts & notes`.
- Permit row `Open` first chooses a gate (`AccessView.swift:482-496`). Plain replacement: `Choose gate`.
- `Update school sign-in for Access` opens a flow whose copy says it also affects School Portal (`SettingsView.swift:197,318`). Plain replacement: `Update school sign-in`.
- Additional jargon: explain `post-control key` once as a private recovery key; use `One post is only part of the picture` instead of capitalized `Experience`; use `Apply with this draft` instead of `Quick Apply`; remove the mixed-language Access hint; replace the implementation-like Appearance footer. Citations: `ComposeExperienceView.swift:145-215`; `ExperiencesView.swift:373`; `AccessView.swift:123-129,659`; `SettingsView.swift:98`.
- Strong statements about no stored author identity/no human report queue are consistent with client contracts but were not live-datastore verified in this audit (`ReportSheet.swift:29,60-62`; `SettingsView.swift:222-228`; `ComposeExperienceView.swift:210-215`).

## Accessibility evidence

- Static focus order follows native declaration order. Key sequences are Home toolbar then lesson/feed/actions; Timetable header/date strip/cards; Experiences toolbar/identity/scope/posts; History toolbar/filters/rows; Access refresh/draft/permits/recovery/actions/gates; Settings Done/palettes/account/school/privacy/about (`HomeView.swift:20-125`; `TimetableView.swift:38-157,273-367`; `ExperiencesView.swift:18-189`; `HistoryView.swift:21-151`; `AccessView.swift:33-396,734-789`; `SettingsView.swift:22-244`).
- Primary controls are native `Button`, `NavigationLink`, `Picker`, `Toggle`, `TextField` or `DatePicker`; custom card content is inside buttons. Static Switch Control/Full Keyboard Access reachability is therefore present, but was not run on device.
- Key icon buttons have accessibility labels. Timetable dates expose full date and selected value; cards combine subject/teacher/time/room/current and hint; palette rows combine label/value; rating/reactions have semantic labels (`TimetableView.swift:278-305,441-460`; `SettingsView.swift:124-134`; `ExperienceRow.swift:56-67`; `InteractiveExperienceRow.swift:72-79`).
- 44pt evidence: chips 44, primary/secondary buttons 52/50, Home See all 44 and quiet actions 48, Timetable date controls 44 and cards 104, reactions 44, palette rows 44, Access refresh 44/actions 82/gates 52 (`AppComponents.swift:11-29,186-221`; `HomeView.swift:230-319`; `TimetableView.swift:68-124,273-440`; `InteractiveExperienceRow.swift:54-79`; `SettingsView.swift:103-127`; `AccessView.swift:50-72,673-789`).
- Dynamic Type uses semantic fonts. Risk points remain Home's two-line scaled title, Timetable's fixed 36pt header, seven equal-width dates and scaled week range, and Access one-line scaled cards (`HomeView.swift:178-183`; `TimetableView.swift:68-75,273-305,347-367`; `AccessView.swift:533-573,673-731`).
- ARIA/HTML landmarks and skip link are not applicable to SwiftUI. Native NavigationStack/TabView semantics exist, but custom `AppSectionHeader` lacks `.accessibilityAddTraits(.isHeader)`, so VoiceOver rotor heading navigation is not established (`AppComponents.swift:65-73`).
- Dark mode is adaptive and not forced (`AppTheme.swift:166-206`). Access explicitly respects Reduce Motion; global custom motion is presently disabled (`AccessView.swift:9-12,245-247,311-395`; `AppConfig.swift:14-18`).

## Principle-fed evidence

### Principle 1 — innovative

- App-scoped, coalesced, stale-safe data repositories are integrated with a lesson-first native composition and palette-specific semantic markers (`AppServices.swift:56-215,333-450`; `HomeView.swift:142-319`; `AppTheme.swift:64-224`). These refresh established mobile patterns; they do not establish a pattern proven absent in five peer products.

### Principle 2 — useful

- The primary answer appears directly after greeting and before all secondary content (`HomeView.swift:27-53,142-235`). Secondary feed work does not block applying the lesson result (`HomeViewModel.swift:38-72`).
- Timetable is explicit and each lesson is a card; all choices are directly listed; physical Access is confirmation-gated with real door names. Evidence is in the required checks above.

### Principle 3 — aesthetic

- A coherent semantic type/color system, contextual surface relationship and restrained Home hierarchy are present in source. Six palettes pass static contrast. However, without a signed-in screenshot, beauty and final whole-screen balance are not directly observed.

### Principle 4 — understandable

- Natural case, direct refresh labels, teacher fallback and named physical actions support clarity. Four visible label/behavior mismatches or ambiguous labels remain: week-range/today, Yours/posts+notes, Open/choose gate, and Access-only reconnect wording. Evidence is in Copy flags above.

### Principle 5 — unobtrusive

- Home's chrome recedes into same-palette tonal surfaces; secondary content is rows/hairlines, and idle animation is absent. Access necessarily carries more card/action chrome (`HomeView.swift:142-319`; `AccessView.swift:148-350`).

### Principle 6 — honest

- Temporary startup failure is not misreported as sign-out; empty/error/success are not collapsed, stale Access data cannot trigger a physical action, mutation uncertainty is explicit, and destructive scope is enumerated. One Access rule sentence overstates certainty; strong privacy/report claims remain live-unverified.

### Principle 7 — long-lasting

- Semantic system type, native controls, flat tonal surfaces, natural case and no idle animation avoid obvious dated markers (`AppTheme.swift:242-290`; `AppComponents.swift:223-227`). Schedule color hashing remains an unvalidated experiment, not a dated marker by itself.

### Principle 8 — thorough

- All requested state families are represented, including a retryable startup-unavailable state; the latest Home retains content safely while explicitly naming an expired retained lesson. Gaps remain in custom heading semantics, Dynamic Type risk layouts, current device traversal and delayed-response tests outside Timetable.

### Principle 9 — environmentally friendly

- App-scoped caches/coalescing reduce repeat requests to zero within freshness windows, Timetable cache is bounded, prefetch is delayed/cancellable, dark mode is honored and idle animation is zero. Physical energy/TTI measurements remain absent.

### Principle 10 — as little design as possible

- Home is reduced to the required focal lesson, two previews and secondary actions. Six palette choices are explicitly required, not decoration. Remaining removable/redundant material is limited to overlapping Access retry placements and one dead Timetable property; Timetable's range control needs relabeling rather than another control.

## Known gaps

- No fresh signed-in iOS screenshot for any audited signed-in surface or any of the six palettes; all iOS visual conclusions are inferred.
- No physical iPhone VoiceOver, Switch Control, Full Keyboard Access, accessibility Dynamic Type, Reduce Motion, light/dark palette or exact hit-region traversal.
- No fresh signed-in TTI, Home/Portal cold-warm timing, frame-hitch, energy or memory capture.
- No physical Access permit/gate action.
- No live datastore verification of authorlessness/report handling claims.
- Tests were inspected but not executed by the audit team.
- No Web production-bundle JS measurement.
- No feed cursor append or scroll restoration; My Classes still requests a fixed first 100 (`AppServices.swift:381-383`).
- Timetable has delayed-response regression tests; equivalent History/Experiences view-model tests were not found. Home now has refresh-retention coverage, but not a delayed ABA test.
