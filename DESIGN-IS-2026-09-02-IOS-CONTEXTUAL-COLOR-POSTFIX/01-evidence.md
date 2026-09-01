# Post-fix evidence

Two independent evidence subagents re-read the production diff and supplied facts only. The orchestrator performed all scoring and independently inspected final test/build artifacts. Final scoped diff hash: `06b3d42de973d4a51a204df6f77db901bab638b32d8814c2281b80854b00e768`, based on HEAD `5158ebcf559927b6f8832232fc34b7eca12a81f7`; the only change after the prior bounded hash was the successful-recovery regression test.

## Evidence boundaries

- Local scope: all signed-in SwiftUI surfaces, Root/Auth recovery, shared design system, services/state models and relevant tests under `ios/`.
- Correct Web reference: `origin/integration/product-v2@4f0c4876a16b6ddedeccb7e28cf7f02021536caa`, `apps/web` only. `web-ionic` was not inspected.
- Observed Web screenshot: `/private/tmp/honey-gaelisus-home-2026-09-01.png`, Home content approximately x315–1395/y38–560 and hero x315–1395/y121–322.
- No fresh signed-in iOS screenshot exists. Every iOS visual conclusion is **INFERRED from source**. Login was not substituted for Home.
- `/tmp/honey-ios-final-106.xcresult` was independently read with `xcresulttool`: result Passed, 106 passed, 0 failed, 0 skipped, arm64 iPhone 17 simulator. The final device product at `/tmp/honey-ios-device-final/Build/Products/Debug-iphoneos/HOney.app` was independently inspected as a signed thin arm64 Mach-O with `com.gaelisus.honey` and TeamIdentifier `ALQXG4KCRB`; root reports the generic iphoneos build command exited 0. These facts verify automated build/test output, not physical-device behavior, screenshots or accessibility.

## Structural evidence

Counting method: nominal loaded-state controls; server rows expressed as variables. Static depth expands helper view bodies but is not a runtime SwiftUI graph.

| Surface | Interactive elements | Static max depth | Evidence |
|---|---:|---:|---|
| Startup unavailable | 1 retry | 4 | `ios/HOney/App/RootView.swift:18-43` |
| Home | 6 fixed, +1 conditional retry | 11 | `ios/HOney/Features/Home/HomeView.swift:38-86,239-328` |
| Timetable | 12 + one per lesson, +1 conditional retry | 12 | `ios/HOney/Features/Timetable/TimetableView.swift:38-158,274-485` |
| Experiences | 8 + three row actions per post | 9 | `ios/HOney/Features/Experiences/ExperiencesView.swift:18-188`; `InteractiveExperienceRow.swift:21-79` |
| Explore | 2 + one link per target, +1 conditional retry | 8 | `ExperiencesView.swift:237-352` |
| History | 4 + one per lesson; selection adds Cancel | 13 | `ios/HOney/Features/History/HistoryView.swift:21-151` |
| Access | 7 + approved-permit Choose gate actions | 12 | `ios/HOney/Features/Access/AccessView.swift:50-198,205-330,442-508,732-788` |
| Settings | 11 disconnected / 12 connected | 7 | `ios/HOney/Features/Settings/SettingsView.swift:22-127,144-218` |

- Repo search found **0** `.refreshable`, **0** `DragGesture`, and **0** `.badge(` occurrences in current iOS source/tests.
- Timetable's seven date buttons live in a horizontal `ScrollView`, each with an explicit 44×44 frame and selected value (`TimetableView.swift:274-311`). Previous/next are 44×44 and Today has minimum height 44 (`:334-377`).
- Every lesson remains one bounded card with subject, time, teacher or `Teacher not listed`, optional room and combined accessibility summary (`TimetableView.swift:140-153,382-477`).
- Six palettes remain direct unfiltered choices (`ios/HOney/DesignSystem/AppTheme.swift:37-57`; `SettingsView.swift:84-100`).
- Access failure recovery has one contextual `Try Access again`; the permit-local retry was removed. Including normal header refresh, a failure state can show two refresh affordances, down from three (`AccessView.swift:59-72,225-287`).
- Dead stored/computed properties and unused imports in the scoped primary files: **0** by identifier/lexical scan. One dead function parameter remains: `AccessViewModel.handle(_:context:)` never reads `context` (`AccessViewModel.swift:109-131,155-181`).

## Focused post-fix verification

### Labels and behavior

- **Pass:** visible `Today` calls `goToToday`; VoiceOver label is `Go to today` and week range is a hint (`TimetableView.swift:110-122,351-377`; `TimetableViewModel.swift:81`).
- **Pass:** `Posts & notes` opens `MySubmissionsView`, which contains posts and private notes (`ExperiencesView.swift:41-42,61-63`; `MySubmissionsView.swift:39-105`).
- **Pass:** permit row says `Choose gate`; it begins gate selection, while the actual portal-named door is separately selected and confirmed (`AccessView.swift:94-123,471-494,732-788`).
- **Pass:** Settings `Update school sign-in` opens `SchoolReconnectView`; the form explicitly replaces and verifies the device-saved school credentials (`SettingsView.swift:78-80,197-199,287-370`).
- **Pass:** Access copy now says `No active permit`, `Apply with this draft`, `End time must be after the start time`, and `Add a short reason` (`AccessView.swift:124-130,641,657`). The earlier inflated `whole rule` sentence and mixed-language hint are gone.
- Remaining clarity details:
  - `Current week is …` is actually the selected/shown week and should be `Shown week is …` (`TimetableView.swift:375-376`).
  - Home's School Portal opens an in-app sheet but uses the external-context `arrow.up.right` symbol (`HomeView.swift:304-327`).
  - History inactive filters still say `Teacher`/`Course` instead of `Any teacher`/`Any course` (`HistoryView.swift:137,146`).
  - Access start hint begins `the date always stays on today`; clearer copy is `Start date is today` (`AccessView.swift:625`).

### Heading semantics

- Explicit `.isHeader` traits exist on startup unavailable, Login, import consent, Home greeting, Timetable date, Access title, Explore result title, Why page title, shared `AppSectionHeader`, and shared `sectionTitle` modifier (`RootView.swift:26`; `LoginView.swift:52`; `ImportConsentView.swift:22`; `HomeView.swift:134`; `TimetableView.swift:76`; `AccessView.swift:58`; `ExperiencesView.swift:373,494`; `AppComponents.swift:73,294`).
- The requested deeper hierarchy is also closed: Home empty `Your next lesson` (`HomeView.swift:218-223`), all eight generated Why subsection titles (`ExperiencesView.swift:476-484,499-505`), and Access `Apply Permit`, `Permits`, `School access`, and dynamic gate route title (`AccessView.swift:149-155,208-217,294-300,735-746`) all carry `.isHeader`.
- Literal `Choose gate` in the picker is supporting copy beneath the dynamic route heading; the permit-row `Choose gate` is an action, not a heading (`AccessView.swift:743-750,483-494`). Other visual card titles require hierarchy judgment rather than mechanical traits; actual Rotor usefulness remains a device-verification gap.

### Startup truthfulness

- Direct temporary `/me` failure retains the session, enters `startupUnavailable`, and presents inline Retry (`ios/HOney/App/AppModel.swift:48-77`; `RootView.swift:21-36`; test intent `ios/HOneyTests/AppModelLifecycleTests.swift:44-54`).
- Refresh rejection clears session only for 401/403 and leads to signed-out (`ios/HOney/Services/HOneyAPI.swift:288-304`; test intent `AppModelLifecycleTests.swift:56-66`).
- The audit initially found refresh 503 also cleared the session. The final code closes it: non-auth HTTP failures preserve the session and flow to `startupUnavailable`; the new me-401→refresh-503 test encodes this boundary (`HOneyAPI.swift:288-304`; `AppModel.swift:63-77`; `AppModelLifecycleTests.swift:68-78`).
- Successful bootstrap recovery clears `startupNotice` before entering `signedIn` (`AppModel.swift:63-66`). The dedicated regression now seeds the failure notice, retries successfully, asserts signed-in and asserts the notice is nil (`AppModelLifecycleTests.swift:80-100`). Lifecycle coverage also includes direct 503, refresh rejection and refresh 503 (`:44-78`).

## Visual evidence

- Core spacing tokens are 4/8/12/16/20/24pt (`AppTheme.swift:227-234`); local values remain 2/3/5/6/7/9/10/13/14/17/18/22/28/32. Examples: Home 24 page rhythm, 20 hero padding, 22 internal gap and 14 feed rows (`HomeView.swift:26-57,159-213,239-270`); Timetable 14 list, 10 cards, 13/7 internal gaps (`TimetableView.swift:40-64,128-157,395-454`).
- Typography is semantic SwiftUI type, approximately 34/28/20/17/15/13/12/11pt (`AppTheme.swift:242-280`). Search found zero `.uppercased`, `.smallCaps`, or uppercase text-case transformation.
- Six palettes still share canvas/surface/ink structure while independently defining four detail accents in light/dark (`AppTheme.swift:21-162,214-224`). One appearance activates 15–16 base solid colors; Settings deliberately previews five swatches for each palette (`SettingsView.swift:103-135`).
- **INFERRED Home regression pass:** `PageBackground` remains a flat palette canvas and source contains no SwiftUI gradient. The hero remains surface@0.72 + line@0.72 + 3pt schedule marker (`AppComponents.swift:224-228`; `HomeView.swift:143-236`). It is not a pure-white card isolated on a colored gradient ground.
- **INFERRED hierarchy:** greeting → notices → single lesson hero → at most two class posts → quiet Share/Access → Portal (`HomeView.swift:20-57,239-328`).
- Correct Web reference remains structural only; its uppercase micro-labels and animated wash conflict with current user constraints and were not copied.

## Contrast

Method follows `ios/HOneyTests/SurfacePaletteTests.swift:77-89`: linearized sRGB luminance and `(Lmax+.05)/(Lmin+.05)`. Normal-text threshold 4.5:1, control boundary 3:1.

| Palette | Light: ink / secondary / minimum detail / on-accent / accent-soft | Dark: same order | Result |
|---|---|---|---|
| Porcelain | 14.23 / 6.47 / 5.91 / 6.95 / 5.62 | 15.70 / 9.65 / 7.43 / 7.37 / 5.12 | Pass |
| Clean White | 16.55 / 7.20 / 5.36 / 6.49 / 5.40 | 16.86 / 10.18 / 7.80 / 7.51 / 5.16 | Pass |
| Blue Mist | 13.17 / 5.92 / 4.97 / 6.37 / 4.98 | 15.52 / 9.89 / 7.72 / 7.97 / 5.41 | Pass |
| Sage Gray | 12.72 / 5.70 / 5.40 / 6.14 / 4.89 | 15.42 / 9.80 / 7.43 / 8.11 / 5.41 | Pass |
| Warm Paper | 16.27 / 7.25 / 5.52 / 6.08 / 4.91 | 15.85 / 9.04 / 7.76 / 8.03 / 5.09 | Pass |
| Original Blue | 12.05 / 6.46 / 4.77 / 6.40 / 5.10 | 15.74 / 9.63 / 7.83 / 8.40 / 5.68 | Pass |

- Lowest primary ink across canvas/surface/muted: 10.84:1. Lowest secondary: 5.20. Lowest detail: 4.77. Semantic foreground on 10% tint: success ≥6.41, warning ≥6.20, error ≥4.90.
- These are source-calculated token values and test assertions, not pixel measurements from a signed-in screenshot.

## State, accessibility and runtime evidence

- Root/Auth now distinguish loading, retryable startup unavailable, signed out, consent pending and signed in (`RootView.swift:18-43`). Main network screens represent empty/loading/error/success/disabled states; Home additionally represents retained/expired stale content and Access separates permit/door failure (`HomeView.swift:38-80,143-270`; `AccessView.swift:207-307`; related view models).
- Static focus order follows native declaration order. Primary actions are native Button/NavigationLink/Picker/Toggle/TextField/DatePicker; custom cards use button wrappers/content shapes. Full Keyboard Access and Switch Control were not run.
- 44pt evidence: date buttons/prev-next 44, Today min44; chips 44; shared primary/secondary 52/50; Home quiet actions 48; Timetable cards 104; reactions 44; palette rows 44; Access refresh 44, route cards 82 and gates 52 (citations in structural/focused evidence above and `AppComponents.swift:11-29,187-221`).
- Dynamic Type risks remain: Home title two-line scale .78 (`HomeView.swift:179-184`); Timetable header fixed 36/one line, Today range one line/scale .82 and date buttons fixed 44 (`TimetableView.swift:71-76,274-311,360-369`); Access fields/cards scale one-line text (`AccessView.swift:537-570,697-720`). Horizontal scrolling prevents seven dates from being squeezed but does not prove AX-size text will not clip.
- Dark mode is adaptive (`AppTheme.swift:166-206`). Root and Access gate custom animation with Reduce Motion; global animations remain off (`RootView.swift:9-10,45-46`; `AccessView.swift:243-245,309-393`; `AppConfig.swift:14-18`). Idle animation count: 0.
- Request counts: valid bootstrap 1; expired token path up to 3 sequential auth requests; cold Home 4, Experiences 3, Timetable 1 visible + up to 2 delayed prefetch, History 3, Access 2 concurrent safe reads, Settings 1. Fresh Home/Experiences/History/Timetable revisit can be 0 within cache windows (`HOneyAPI.swift:261-308`; `AppServices.swift:73-215,237-306,336-450`; `TimetableRepository.swift:54-105`).
- Measured TTI: unavailable. First signed-in UI waits for `/me` and potentially refresh+retry; Home shell then renders while its data tasks run (`RootView.swift:18-50`; `HOneyAPI.swift:261-308`; `HomeView.swift:20-105`).
- Initial signed-in Home: zero notifications, badges and presented modals in nominal state. Startup unavailable is an inline state, not a modal.

## Copy inventory and honesty

Complete inventory method: every scoped `Text`, `Button`, `Label`, navigation title, accessibility label/value/hint, dialog/banner/error assignment and computed display string was inspected; dynamic profile/directory/date/portal server strings were traced to display sites instead of invented.

- Root/Auth/Main: `RootView.swift:19-36`; `LoginView.swift:35-107`; `ImportConsentView.swift:19-57`; `MainTabView.swift:24-37`; AppModel notices/errors at `AppModel.swift:75,111,120-122,138,150,193,284`.
- Home: `HomeView.swift:41-85,130-236,242-328,340,392-412`; HomeVM errors `HomeViewModel.swift:63-67`.
- Timetable/Lesson detail: `TimetableView.swift:47-100,137,162,236-241,305-376,426-480`; `LessonDetailView.swift:24-84,128-155`.
- History: `HistoryView.swift:26-47,70-83,122-169`; VM errors `HistoryViewModel.swift:60,87-89`.
- Experiences hub/Explore/results/About: `ExperiencesView.swift:25-178,220-305,366-516`; VM errors `ExperiencesViewModel.swift:54-56,84-86`; row/reaction/provenance at `ExperienceRow.swift:26-67`, `InteractiveExperienceRow.swift:28-78`, `HOneyModels.swift:188-195,281-294`.
- Compose/My Posts/Report: `ComposeExperienceView.swift:34-448`; `ComposeExperienceViewModel.swift:72-419`; `ExperienceSubmitCopy.swift:13-32`; `MySubmissionsView.swift:19-363`; `ReportSheet.swift:27-95`; report categories `HOneyModels.swift:475-495`.
- Access: `AccessView.swift:39-130,152-202,213-300,323-506,519-657,740-775`; `AccessViewModel.swift:68-195`.
- Settings/Reconnect: `SettingsView.swift:42-243,256-281,299-369`; six palette names `AppTheme.swift:49-57`.

- No marketing superlative and no dark pattern was found. Destructive and physical actions retain explicit consequences and confirmation.
- All four requested visible label-to-behavior mismatches are closed. Remaining microcopy/icon issues are listed under Focused verification.
- Strong authorlessness/report claims are consistent with client contract but not live-datastore verified in this audit (`ReportSheet.swift:29,60-62`; `SettingsView.swift:222-228`; `ComposeExperienceView.swift:210-215`).
- No remaining load-bearing state-to-copy mismatch was observed in the final bounded hash; remaining copy/icon items are minor clarity refinements.

## Per-principle evidence

### #1 Innovative

- The native lesson-first surface combines app-scoped stale-safe repositories, explicit day controls and palette-specific semantic markers. It refreshes established patterns; no evidence establishes uniqueness across five peer products (`HomeView.swift:143-328`; `AppServices.swift:56-215,333-450`; `AppTheme.swift:64-224`).

### #2 Useful

- Primary answer remains first; Today/date/card controls and corrected destination labels now route directly to their named tasks. Complete selectable lists remain visible without search-gating.

### #3 Aesthetic

- Source shows a coherent semantic system and repaired same-palette hero relationship, but many local spacing values and no signed-in screenshot prevent observed whole-screen aesthetic closure.

### #4 Understandable

- Four audit-blocking labels now align with behavior. Remaining issues are one inaccurate accessibility hint, one external-looking in-app icon, two filter placeholders and a minor Access hint.

### #5 Unobtrusive

- Home chrome recedes into same-palette tonal surfaces and secondary rows. Timetable cards replace the dense fixed timeline. Access remains necessarily more explicit due to physical action and permit safety.

### #6 Honest

- Auth refresh 503 no longer destroys the saved session; successful recovery clears its failure notice; expired Home data and physical-action uncertainty are named. No deceptive flow or observed claim-to-behavior mismatch remains in scoped source.

### #7 Long-lasting

- Semantic system type, native controls, natural case, flat tonal surfaces and zero idle animation avoid obvious dated markers.

### #8 Thorough

- Core state families and the requested screen/subsection heading semantics are represented. AX-size layout, actual Rotor/Switch traversal, live announcements and current complete-run evidence remain incomplete.

### #9 Environmentally friendly

- Native UI has no JS, no idle animation, adaptive dark mode/Reduce Motion and bounded/coalesced caches with request-free fresh revisits.

### #10 As little design as possible

- Home remains reduced; Access duplicate failure retry was removed; all three Timetable navigation layers have distinct functions. One dead Access function parameter and small copy/icon cleanups remain.

## Known gaps

- No signed-in iOS screenshots; visual findings remain inferred.
- No physical iPhone VoiceOver/Switch/Dynamic Type/dark/palette traversal and no physical Access action.
- No measured TTI, frame hitch, energy, memory, Portal cold/warm or scrolling trace.
- Final automated suite and signed arm64 product are independently evidenced as described above; root-reported build exit 0 is consistent with the inspected product.
- Live authorlessness/report behavior was not revalidated.
- My Classes still requests the first 100; no cursor append/scroll restoration (`AppServices.swift:379-383`).
- Delayed-response view-model tests remain thinner for History/Experiences than Timetable.
- Requested semantic headings are present, but broader Rotor usefulness and optional card-title hierarchy still need device-level judgment rather than mechanical trait assignment.
