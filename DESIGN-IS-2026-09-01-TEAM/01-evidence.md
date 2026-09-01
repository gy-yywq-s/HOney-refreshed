# HOney iOS team design audit evidence

## E1 — Baseline and runtime

- Baseline is commit `a3c3a966d129ecd2e1f462a79ed7dbeb6cd83b32` on `codex/ios-editorial-redesign`; the local signing-team delta is excluded.
- Runtime Login evidence is `DESIGN-IS-2026-09-01-POST/evidence/login-light-placeholder-v2.png` and `login-dark-placeholder-v2.png`, both 402x874 pt. Original-pixel regions: wordmark `(195-665,350-510)`, headline/support `(70-1110,615-930)`, fields `(70-1135,1025-1525)`, disabled CTA `(70-1135,1605-1775)`, disclosure `(70-1120,1810-1960)`.
- The screenshots show identical light/dark hierarchy, no clipping, and no Login gradient, shadow, illustration, badge, modal, or idle decoration.
- Direct user runtime observation: first School Portal tap hangs for a long time and appears frozen/dead. This is accepted as P0 evidence of the shipped interaction, independent of whether the eventual root cause is blank uncommunicative loading or an actual main-thread/WebKit stall.
- Direct user runtime observation: rapid Timetable next-next navigation pauses before responding.

## E2 — Structural and usefulness evidence

- Source-template interactive count is **102**: 98 feature controls plus 4 tab items. Counting includes each declared `Button`, `NavigationLink`, `Menu`, `Picker`, `Toggle`, editable field, `Stepper`, `DatePicker`, searchable/refreshable control, direct gesture, and tab item once; data-expanded runtime instances are not multiplied. Representative citations: `ios/HOney/Features/Auth/LoginView.swift:17-39,61-103`; `ios/HOney/Features/Home/HomeView.swift:52-87,183-295`; `ios/HOney/Features/Experiences/ExperiencesView.swift:27-56,114-150`; `ios/HOney/Features/Access/AccessView.swift:48-118,123-345,394-737`; `ios/HOney/Features/Main/MainTabView.swift:19-38`.
- Maximum expanded primary tree depth is **16**: `NavigationStack > GeometryReader > Group > content VStack > daySchedule VStack > DayTimelineView > HStack > GeometryReader > ZStack > ForEach > Button > TimelineLessonBlock > HStack > VStack > HStack > Text`. Evidence: `ios/HOney/Features/Timetable/TimetableView.swift:14-28,40-53,139-156,372-410,592-630`.
- Five repeated-purpose families remain: dismiss/close controls; target-bound Experience entry points; mutually exclusive Keep-private actions; teacher/course filter pairs; destructive action plus confirmation. Evidence: `ios/HOney/Features/Auth/LoginView.swift:34-38`; `ios/HOney/Features/Home/HomeView.swift:183-200`; `ios/HOney/Features/Experiences/ComposeExperienceView.swift:290-363`; `ios/HOney/Features/Experiences/ExperiencesView.swift:121-150`; `ios/HOney/Features/Settings/SettingsView.swift:47-60,75-85`; `ios/HOney/Features/Experiences/MySubmissionsView.swift:105-126,217-264`.
- Dead component-input/state props: **0**. Unused imports: **0**, from lexical/manual source review. Representative declaration/use pairs: `ExperienceRow.showsReactions` at `ios/HOney/Features/Experiences/ExperienceRow.swift:12-40`; `FilterChip.isActive` at `ExperiencesView.swift:169-185`; `HistoryView.onSelect/selecting` at `ios/HOney/Features/History/HistoryView.swift:10-19,68-78,126-150`; `EditablePermitField.badge` at `ios/HOney/Features/Access/AccessView.swift:479-521`.
- Four standard tabs use the existing selection instead of nesting duplicate tab content — `ios/HOney/Features/Main/MainTabView.swift:15-39`.
- Home makes the current/next lesson the first and largest signed-in object, with time, room, topic, temporal state, and progress — `ios/HOney/Features/Home/HomeView.swift:20-49,105-180`.
- Sharing is target-bound: Home and Experiences select a real past `Lesson` before presenting the composer; targetless standalone composition was removed — `ios/HOney/Features/Home/HomeView.swift:76-87,183-193,304-308`; `ios/HOney/Features/Experiences/ExperiencesView.swift:27-53,162-166`; `ios/HOney/Features/Experiences/ComposeExperienceView.swift:15-59`.
- Worst usefulness edge: the displayed current/next lesson card has no direct action; `Share a lesson` opens Past lessons, so acting on the focal lesson requires another route — `ios/HOney/Features/Home/HomeView.swift:105-193`; model separation at `ios/HOney/Models/HOneyModels.swift:62-74,96-109`.
- School Portal is reachable in one tap but the observed cold path appears frozen for a long time; its screen provides only the raw WebView plus Done/Reload, not an immediately legible loading state — `ios/HOney/Features/Home/HomeView.swift:271-295`; `ios/HOney/Features/Home/PortalWebView.swift:99-134`.
- Timetable day/week controls update `selectedDate` then launch a fresh unretained `Task { await load() }` for every swipe/tap; there is no per-date cache, adjacent prefetch, cancellation, request identity, or selected-date snapshot before the request — `ios/HOney/Features/Timetable/TimetableViewModel.swift:14-63`; `ios/HOney/Features/Timetable/TimetableView.swift:60-63,96-108,132-148,324-352`.
- Because `load()` builds its query from mutable `selectedDate` and unconditionally writes `lessons` on completion, rapid requests can race and an older response can overwrite the currently selected day. This is source-derived risk consistent with the observed next-next pause — `ios/HOney/Features/Timetable/TimetableViewModel.swift:32-49,52-63`.
- Access names server-returned doors, confirms the selected name, and refuses unnamed physical actions — `ios/HOney/Features/Access/AccessView.swift:72-108,266-345,682-737`; `ios/HOney/Models/PortalModels.swift:179-200`.

## E3 — Visual system

- Declared spacing tokens are `[4,8,12,16,20,24,28]` pt — `ios/HOney/DesignSystem/AppTheme.swift:62-71`. Login additionally uses 7/14/15/18/32/40/42 pt — `ios/HOney/Features/Auth/LoginView.swift:17-27,42-58,90-137`.
- Runtime Login type is `[12,13,15,17,28]` pt plus bitmap wordmark; app-wide system styles span approximately `[11,12,13,15,17,20,22,28,34]` pt — `ios/HOney/DesignSystem/AppTheme.swift:80-129`.
- Twelve adaptive semantic color roles are declared — `ios/HOney/DesignSystem/AppTheme.swift:35-46`. Login visibly uses canvas, surface, surfaceMuted, ink, inkSecondary, accent, and line.
- Audited contrast: inkSecondary/canvas 7.25:1 light and 9.04:1 dark; accentForeground/accent 6.08:1 light and 8.03:1 dark; warning banner 6.42:1 or better; direct accent/surface 5.98:1 light and 7.19:1 dark. Lowest audited enabled semantic foreground is 5.98:1.
- Corrected Timetable evidence: `P#` uses direct `Palette.accent`, not an opacity foreground — `ios/HOney/Features/Timetable/TimetableView.swift:475-486`. No opacity-based text foreground remains in the committed source.
- The sole gradient is a shallow Home-only atmosphere behind content — `ios/HOney/DesignSystem/AppTheme.swift:54-59`; `ios/HOney/DesignSystem/AppComponents.swift:203-214`; `ios/HOney/Features/Home/HomeView.swift:20-48`.
- Wordmark is transparent, template-tinted, and labeled `HOney`, but remains explicitly temporary; its asset catalog populates only universal 1x, with 2x/3x empty — `ios/HOney/DesignSystem/AppComponents.swift:217-229`; `ios/HOney/Resources/Assets.xcassets/BrandWordmarkPlaceholder.imageset/Contents.json:1-24`.
- Current committed surface roles are one fixed adaptive paper/brown family; Settings exposes no persisted surface-palette choice and no `AppStorage`/palette state — `ios/HOney/DesignSystem/AppTheme.swift:35-46`; `ios/HOney/Features/Settings/SettingsView.swift:94-160`. New product requirement: provide coherent light/dark paper, neutral-white, cool-mist, and soft-gray Surface alternatives. The accent stays in the blue-teal semantic family, but every Surface palette defines its own harmonized `accent`, `accentSoft`, and `accentForeground` values and verifies their light/dark contrast; identical accent RGB across palettes is not required. Large saturated color skins remain out of scope.

## E4 — Copy and honesty

### Screen copy inventory

- Shell/tabs: loading and four tab labels — `ios/HOney/App/RootView.swift:17-25`; `ios/HOney/Features/Main/MainTabView.swift:19-38`.
- Login: brand introduction, labeled account/password fields, Sign in states, credential disclosure, and login errors — `ios/HOney/Features/Auth/LoginView.swift:34-114`; `ios/HOney/App/AppModel.swift:56-84`.
- Consent: separate-choice explanation, timetable/past-lessons/choice rows, Import/Not now states, and error — `ios/HOney/Features/Auth/ImportConsentView.swift:18-86`; `ios/HOney/App/AppModel.swift:87-116`.
- Home/Portal: greeting/date, lesson loading/error/now/next/empty states, Share/Open Access, class Experiences, Portal, and retry notices — `ios/HOney/Features/Home/HomeView.swift:26-325`; `ios/HOney/App/AppModel.swift:102-139`; `ios/HOney/Features/Home/PortalWebView.swift:106-134`.
- Experiences/entity/report: feed headings, empty/error/filter/search copy, provenance/reactions, entity state, report categories/confirmation/errors — `ios/HOney/Features/Experiences/ExperiencesView.swift:26-160`; `EntityPageView.swift:18-76`; `ExperienceRow.swift:16-62`; `InteractiveExperienceRow.swift:20-76`; `ReportSheet.swift:24-97`; category labels at `ios/HOney/Models/HOneyModels.swift:414-437`.
- Composer: target, terminal publish/private states, editor/rating, Six Checks, moderation/nudge/cooldown/actions/errors — `ios/HOney/Features/Experiences/ComposeExperienceView.swift:71-363`; `ComposeExperienceViewModel.swift:68-75,199-280`; `ExperienceSubmitCopy.swift:10-42`; `SixChecks.swift:15-23`.
- My posts/notes: loading/error/empty, revoke/delete confirmations, status chips, key/private-note copy, row actions and feedback — `ios/HOney/Features/Experiences/MySubmissionsView.swift:14-173,177-347`.
- Past lessons/Timetable/Lesson: loading/error/empty/filter/date/period/break/free/lesson/action copy — `ios/HOney/Features/History/HistoryView.swift:21-152`; `HistoryViewModel.swift:60-74`; `ios/HOney/Features/Timetable/TimetableView.swift:69-133,245-302,316-698`; `TimetableViewModel.swift:38-49`; `LessonDetailView.swift:15-158`.
- Access: permit draft/list/load states, direct-school/gate actions and confirmation, result/error banners, server-supplied permit/door text — `ios/HOney/Features/Access/AccessView.swift:32-369,394-737`; `AccessViewModel.swift:32-125`.
- Settings: account/school/privacy/about labels, precise sign-out/disconnect/delete scopes, destructive choices, and update errors — `ios/HOney/Features/Settings/SettingsView.swift:18-199`.

### Positive mappings

- Report and reaction success appear only after successful requests — `ios/HOney/Features/Experiences/ReportSheet.swift:76-95`; `InteractiveExperienceRow.swift:53-76`.
- Home pull retries a failed initial sync before read refresh, and partial Home failures do not become false empty states — `ios/HOney/App/AppModel.swift:131-139`; `ios/HOney/Features/Home/HomeView.swift:61-68,105-180,239-268`.
- Import-toggle failure reverts; server account-deletion failure preserves local data — `ios/HOney/Features/Settings/SettingsView.swift:178-199`.
- Physical Access uses actual returned door names and never guesses an opaque mapping — `ios/HOney/Features/Access/AccessView.swift:73-90,682-737`; `ios/HOney/Models/PortalModels.swift:179-200`.
- No marketing superlative, fake scarcity, hidden cost, forced continuity, or confirmshaming was found.

### P0 mismatches

1. `OwnershipKeyStore.add` suppresses Keychain failure; the composer then clears the draft, enters Published, and says the only post-control key was saved — `ios/HOney/Services/OwnershipKeyStore.swift:17-25,50-54`; `ios/HOney/Features/Experiences/ComposeExperienceViewModel.swift:283-298`; `ComposeExperienceView.swift:118-143`.
2. `Delete account and local HOney data` can dismiss successfully while key/note/draft clear operations suppress failure — `ios/HOney/Features/Settings/SettingsView.swift:47-60,192-199`; `ios/HOney/App/AppModel.swift:183-198`; `ios/HOney/Services/OwnershipKeyStore.swift:62-64`; `PrivateNoteStore.swift:82-85`; `ComposerDraftStore.swift:61-64`.
3. Ownership-key read failure becomes an empty dictionary, causing My Posts to render `Nothing here yet` and hide existing post control — `ios/HOney/Services/OwnershipKeyStore.swift:36-39`; `ios/HOney/Features/Experiences/MySubmissionsView.swift:80-90,130-145,281-292`.
4. First School Portal tap is user-observed to hang for a long time and appear frozen/dead. The screen has no loading/progress/error/timeout state; provisional-navigation failure is ignored; bridge recovery errors are swallowed; and dismissal does not cancel loading/recovery — `ios/HOney/Features/Home/PortalWebView.swift:68-78,99-134`; `ios/HOney/Services/PortalWebSessionBridge.swift:80-95`; task/cancellation evidence at `PortalWebView.swift:91-93,130-133` and `PortalWebSessionBridge.swift:100-106`.
5. Rapid Timetable next-next navigation is user-observed to pause. Every navigation creates another load without cancellation, cache, prefetch, coalescing, or stale-response guard, allowing redundant work and wrong-day overwrite — `ios/HOney/Features/Timetable/TimetableViewModel.swift:14-63`; `ios/HOney/Features/Timetable/TimetableView.swift:60-63,96-108,132-148`.

### P1 mismatches

1. Login says credentials are saved in Keychain, but credential persistence is `try?` and login continues after failure — `ios/HOney/Features/Auth/LoginView.swift:90-114`; `ios/HOney/App/AppModel.swift:56-79`; `ios/HOney/Services/KeychainCredentialVault.swift:34-40`.
2. `startupNotice` is global to `AppModel` and is not cleared by login, sign-out, account deletion, or disabling import, so a stale `Import is on` notice can cross session/account state — `ios/HOney/App/AppModel.swift:20-30,56-85,90-139,171-198`; `ios/HOney/Features/Home/HomeView.swift:26-36`.
3. Successful permit submission is immediately followed by refresh, which clears the success banner or replaces it with a refresh error — `ios/HOney/Features/Access/AccessViewModel.swift:32-53,56-76`.
4. Permit and door reads share one `didLoadPermits` flag; a door failure can leave permit rows visible while the action says `Permits unavailable` — `ios/HOney/Features/Access/AccessViewModel.swift:32-52`; `ios/HOney/Features/Access/AccessView.swift:182-228,321-340`.
5. `nothing links the post back to you` / `no way to see who wrote it` overstate unlinkability while the device key proves ownership and an authenticated mine endpoint retrieves owned posts — `ios/HOney/Features/Experiences/ComposeExperienceView.swift:123-131`; `ReportSheet.swift:24-33`; `MySubmissionsView.swift:281-299`.

### P2 copy friction

- `Share a lesson` actually shares an Experience about a lesson — `ios/HOney/Features/Home/HomeView.swift:183-200`; composer path at `HomeView.swift:76-87`.
- `Quick Apply` only submits the permit draft and does not approve or continue gate opening — `ios/HOney/Features/Access/AccessView.swift:102-108`; `AccessViewModel.swift:56-76`.
- Settings silently shows cached connection state after initial profile-refresh failure — `ios/HOney/App/AppModel.swift:141-150`; `ios/HOney/Features/Settings/SettingsView.swift:41-46,94-105`.
- Failed name resolution can expose raw `entityKey` — `ios/HOney/Features/Experiences/MySubmissionsView.swift:302-324`.

## E5 — Accessibility and states

- Source-inferred Login focus order is School account > Password > Sign in; keyboard Done is available while editing, with explicit `FocusState` and a 2-point focused border — `ios/HOney/Features/Auth/LoginView.swift:11-15,34-38,61-103,117-137`.
- Representative focus orders: Home Settings > Share a lesson > Open Access > See all > School Portal — `ios/HOney/Features/Home/HomeView.swift:52-87,183-295`; Experiences toolbar pair > search > order > teacher > course > repeated reaction/report — `ExperiencesView.swift:27-56,114-150`; Timetable Past lessons > week controls > seven day buttons > lesson blocks — `TimetableView.swift:69-108,318-400,640-698`; Access draft > apply > permits > dismissal > route > returned door > confirmation — `AccessView.swift:123-345,394-737`.
- Primary reachability: current/next lesson YES; exact focal-lesson action NO; past-lesson share YES; browse/filter Experiences YES; other timetable day/lesson YES; day-student Access YES; exit-permit Access YES when state permits; School Portal YES. Evidence: `ios/HOney/Features/Home/HomeView.swift:105-200`; `ExperiencesView.swift:27-166`; `TimetableView.swift:69-166,318-400`; `AccessView.swift:266-345,682-737`; `PortalWebView.swift:106-134`.
- Native ARIA/skip-link analogs: not applicable. `TabView`, `NavigationStack`, titles, `List`/`Form` sections supply native hierarchy — `ios/HOney/Features/Main/MainTabView.swift:19-38`; `ExperiencesView.swift:16-39`; `SettingsView.swift:18-160`; `ReportSheet.swift:24-95`.
- Eleven explicit accessibility-label templates cover wordmark, Settings, progress, Experience toolbar pair, rating, reaction, lesson block, week arrows, Portal reload, and Access dismissal — `ios/HOney/DesignSystem/AppComponents.swift:217-229`; `ios/HOney/Features/Home/HomeView.swift:52-58,153-156`; `ExperiencesView.swift:27-38`; `ExperienceRow.swift:51-62`; `InteractiveExperienceRow.swift:54-76`; `TimetableView.swift:389-400,640-658`; `PortalWebView.swift:121-128`; `AccessView.swift:232-242`.
- Required generic state checklist: empty, loading, error, success, focus, and disabled all exist — `ios/HOney/DesignSystem/AppComponents.swift:56-137,166-180`; `ios/HOney/Features/Home/HomeView.swift:109-175,248-267`; `ios/HOney/Features/Access/AccessViewModel.swift:68-94`.
- Worst-detail gap: error states are absent for ownership-key persistence, local destructive clear, and portal-credential persistence; these operations suppress failure while success copy proceeds — citations in E4.
- School Portal lacks visible cold-loading, progress, did-commit/did-finish state, offline/provisional-failure feedback, recovery failure, timeout, retry orchestration, and cancellation state. `didFailProvisionalNavigation` is empty and SwiftUI receives no observable WebView state — `ios/HOney/Features/Home/PortalWebView.swift:68-78,99-134`; `ios/HOney/Services/PortalWebSessionBridge.swift:80-95`.
- The WebView’s Done control may dismiss the sheet, but no `onDisappear`, `stopLoading()`, or retained Task cancellation exists; the shared persistent WebView can continue invisible work — `ios/HOney/Features/Home/PortalWebView.swift:15-31,106-136`.
- Root and Access honor Reduce Motion — `ios/HOney/App/RootView.swift:9-28`; `ios/HOney/Features/Access/AccessView.swift:9-12,213-216,303-345`.

## E6 — Weight and attention

- Native initial JavaScript: **0 bytes**.
- No third-party Swift package products are declared — `ios/HOney.xcodeproj/project.pbxproj:348-380` at the committed baseline.
- Signed-out Login makes **0** network requests when no stored session/portal credential exists; valid-session launch uses `/api/me` plus two concurrent Home reads — `ios/HOney/App/AppModel.swift:39-49`; `ios/HOney/Features/Home/HomeViewModel.swift:26-48`.
- Portal cold open can perform initial WebKit navigation, then native portal login and identity sequentially, token injection, and a second WebKit navigation. Login/identity use 20-second request and 30-second resource timeouts, while WebKit loads have no app-defined deadline — `ios/HOney/Features/Home/PortalWebView.swift:49-54,80-93`; `ios/HOney/Services/PortalWebSessionBridge.swift:80-90,110-129`; `PortalSessionCoordinator.swift:143-177`; `PortalAPI.swift:26-32,37-75`.
- Portal cold/warm behavior differs: the first open lazily constructs/configures the singleton WebView and starts navigation; warm reopen returns early whenever `webView.url != nil` and retains page/storage/scroll — `ios/HOney/Features/Home/PortalWebView.swift:15-31,36-54,99-133`.
- Recovery can be signaled only after 401/419 or injected SPA hooks. URL-based login-route detection exists but is not wired into the controller, and the document-start probe does not inspect the current URL immediately — `ios/HOney/Services/PortalWebSessionBridge.swift:64-72,142-167`; `ios/HOney/Features/Home/PortalWebView.swift:80-95`.
- Rapid Timetable navigation launches one network request per interaction with no cancellation/coalescing/cache/prefetch, creating avoidable radio/CPU work and stale-result risk — `ios/HOney/Features/Timetable/TimetableViewModel.swift:38-63`; `ios/HOney/Features/Timetable/TimetableView.swift:60-63,132-148`.
- No numeric TTI was measured. Signed-out shell is gated by local Keychain lookup; signed-in shell is gated by `/api/me` — `ios/HOney/App/AppModel.swift:39-54`.
- Login idle animations, notifications, badges, and initial modals: **0**. Custom motion is globally disabled; system appearance is honored; Root and Access gate custom motion with Reduce Motion — `ios/HOney/App/AppConfig.swift:14-17`; `ios/HOney/DesignSystem/AppTheme.swift:138-148`; `ios/HOney/App/HOneyApp.swift:8-17`; `RootView.swift:9-28`; `AccessView.swift:9-12,213-345`.
- Functional periodic updates are Home every 60 seconds and cooldown every 30 seconds — `ios/HOney/Features/Home/HomeView.swift:20-24`; `ios/HOney/Features/Experiences/ComposeExperienceView.swift:330-343`.
- Installed simulator Debug app measured 33,552 KB and includes test/debug support; it is not a Release/App Store size. No Release archive, energy trace, or thinning report exists.

## E7 — P0 runtime responsiveness diagnosis and verification contract

### School Portal source-backed facts

- `PortalWebController.shared` owns one persistent `WKWebView`. Cold open constructs/hosts it and dispatches configure/load from `onAppear`; warm reopen skips `loadInitial` once a URL exists — `ios/HOney/Features/Home/PortalWebView.swift:15-54,99-133`.
- The SwiftUI screen has Done and Reload only. It has no observable loading, progress, elapsed, error, offline, retry, timeout, or cancellation state — `PortalWebView.swift:106-134`.
- `didFinish` only saves a safe URL; `didFailProvisionalNavigation` is empty — `PortalWebView.swift:68-78`.
- Expiry recovery can require fresh token, sequential login/identity, JavaScript injection, and another load; every error is swallowed into `false` — `ios/HOney/Services/PortalWebSessionBridge.swift:76-95,108-129`; `PortalSessionCoordinator.swift:143-177`.
- Recovery tasks are unretained, duplicate signals are dropped while recovering, and dismiss has no stop/cancel path — `PortalWebSessionBridge.swift:38-40,80-85,100-106`; `PortalWebView.swift:91-93,106-136`.
- Source contains no synchronous URLSession/semaphore wait; long main-thread blocking is not proven. Highest-confidence inference is perceived freeze from blank uncommunicative cold navigation plus possible two-navigation auth recovery. First-time WebKit construction as the cause of a long true main-thread stall remains unproven.

### Timetable source-backed facts

- `selectedDate`, `lessons`, `isLoading`, and error are global mutable state; no request token/date snapshot/cache/task handle exists — `ios/HOney/Features/Timetable/TimetableViewModel.swift:14-22,38-63`.
- Swipe, day, Today, and week navigation mutate date and spawn a new Task/load — `ios/HOney/Features/Timetable/TimetableView.swift:60-63,96-108,132-148,324-352`; `TimetableViewModel.swift:52-63`.
- Every completion writes `lessons` and `lastSyncedAt` without confirming the response still matches current `selectedDate` — `TimetableViewModel.swift:38-49`.
- No committed test references `TimetableViewModel`; cold/warm, rapid-tap, cancellation, caching, and stale-response races are uncovered.

### Required diagnostic/fix/verification

1. Add signposts for Portal tap/sheet/WebView/navigation/auth/reload/cancel and Timetable input/request/cache/completion/apply. Separate blank-but-responsive from actual main-thread stall using Time Profiler/Main Thread Checker.
2. Give Portal an observable state machine: idle, creating, loading, authenticating, content, failed, timedOut, cancelled. Render immediate feedback; keep Done responsive; expose Retry/Close and recovery failure.
3. Retain Portal navigation/recovery tasks, impose an overall deadline, wire login-route detection, cancel/`stopLoading()` on dismissal, and prevent Reload/recovery races. Decide deliberately whether to prewarm WebKit after app idle or only after tap.
4. Use credential-free local Web fixtures for immediate/delayed/never-ending 200, 200 login route, 401/419, fetch 401, offline failure, duplicate signals, dismiss/reopen, and warm retained state.
5. Give Timetable one owned cancellable pipeline keyed by immutable requested date, a per-date cache, adjacent-day prefetch, duplicate coalescing, and a generation/date guard before applying results. Preserve prior content during nonblocking load.
6. Add deterministic delayed/out-of-order Timetable tests for next-next, week-week, tap storms, cancellation, cache hit/miss, prefetch, offline fallback, and proof that stale responses never replace the selected date.
7. Record cold/warm wall-clock timings and interaction-to-feedback latency. Define release budgets; user-observed frozen or paused input fails acceptance even if eventual data is correct.

## Per-principle factual map

- #1: standard SwiftUI shell plus lesson-first Home, target-bound publishing, chronological feed, and exact-door confirmation; no 5+ peer-product comparison — E2.
- #2: primary lesson state is immediate, but School Portal cold open appears dead and rapid Timetable navigation pauses — E2, E7.
- #3: one adaptive type/color/surface system; temporary wordmark and required persisted multi-surface palette remain — E1, E3.
- #4: most controls are explicit; School Portal exposes no legible working/failure state, alongside an unfamiliar icon-only My Posts control and `Share a lesson` wording — E2, E4, E5, E7.
- #5: content-first flat Login and shallow Home-only atmosphere; outlined chrome remains visible — E1, E3.
- #6: positive mappings coexist with storage/copy mismatches and a Timetable stale-response path that can display the wrong selected date — E4, E7.
- #7: native adaptive system is durable; placeholder wordmark and fixed-only surface choice remain incomplete — E3.
- #8: Portal lacks loading/error/timeout/cancellation/retry state and Timetable lacks cancellation/cache/stale-response state, in addition to persistence failures — E4, E5, E7.
- #9: dark mode/Reduce Motion and idle attention remain strong, but Portal has unbounded WebKit work/cold recovery and Timetable emits redundant uncancelled requests — E6, E7.
- #10: targetless sharing is removed; two permanent-tab destinations are duplicated on Home and repeated families remain bounded — E2.

## Known gaps

- Signed-in runtime, VoiceOver/Switch Control/external keyboard, accessibility Dynamic Type, increased contrast, landscape, and small-iPhone behavior were not exercised.
- Keychain/disk-full/protected-data failure paths were source-reviewed but not failure-injected.
- Portal cold/warm timings, main-thread stall duration, WebKit progress, and Timetable race timing were not instrumented; user observations establish failure impact, not a single proven root cause.
- No 5+ peer-product comparison, physical-device capture, Release/App Store size, launch signpost, or energy trace.
- Embedded School Portal DOM accessibility is outside this native-source audit.
