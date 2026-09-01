# HOney iOS independent team post-fix evidence

## E1 — Baseline and observed runtime

- Baseline is commit `be8369c9b7b02b9fd542246d2d3fe827bc25c829`; only local signing configuration is excluded.
- Login captures show identical light/dark hierarchy, flat canvas, no clipping, gradient, shadow, illustration, badge, modal, or idle decoration. Original-pixel regions: wordmark `(195-665,350-510)`, headline/support `(70-1110,615-930)`, fields `(70-1135,1025-1525)`, disabled CTA `(70-1135,1605-1775)`, disclosure `(70-1120,1810-1960)`.
- These captures predate current `controlBorder` and four Surface palettes; composition/type/wordmark are observed, while current outlines and non-Paper palettes are source-inferred.
- Earlier Portal freeze and Timetable pause were observed before the current state-machine/cache commits. Current HEAD contains corrective code but lacks fresh runtime confirmation.

## E2 — Structure and usefulness

- Interactive source-template count: **111** = 107 feature templates + 4 tab items. Method counts each declared `Button`, `NavigationLink`, `Menu`, `Picker`, `Toggle`, editable field, `Stepper`, `DatePicker`, search/refresh control, direct gesture, or tab item once. Representative evidence: `ios/HOney/Features/Auth/LoginView.swift:17-103`; `Home/HomeView.swift:52-296`; `Home/PortalWebView.swift:342-443`; `Experiences/ComposeExperienceView.swift:73-442`; `Access/AccessView.swift:49-746`; `Settings/SettingsView.swift:21-188`; `Main/MainTabView.swift:19-38`.
- Maximum expanded primary tree depth: **16**, along the Timetable timeline path ending at lesson text — `ios/HOney/Features/Timetable/TimetableView.swift:14-28,40-54,156-172,387-416,607-644`.
- Repeated-purpose families: **6** — dismiss/close, four target-bound Experience entry points, state-exclusive Keep-private actions, teacher/course filter pairs, destructive confirmation flows, and retry/recovery actions. Evidence: `LoginView.swift:34-38`; `PortalWebView.swift:342-443`; `HomeView.swift:183-200`; `ComposeExperienceView.swift:169-189,372-442`; `ExperiencesView.swift:121-150`; `SettingsView.swift:62-75,129-139`; `MySubmissionsView.swift:86-129,161-165`.
- Dead component/state props: **0**; unused imports: **0**, from lexical/manual review. Specialized UIKit/WebKit/Combine/os.signpost imports have committed use — `PortalWebView.swift:6-10,29-63`; `ComposeExperienceView.swift:13-14,169-176`; `SettingsView.swift:6-7,112-117`; `AppTheme.swift:9-12,125-165`.
- Home’s first signed-in object exposes current/next status, subject, de-duplicated topic, normalized teacher/room, time, and progress — `ios/HOney/Features/Home/HomeView.swift:110-180,298-349`.
- Portal now has one attempt generation, exact warm reuse, absolute 12-second deadline, retained recovery task, scoped navigation callbacks, process-failure state, retry/cancel, and account-reset wait — `ios/HOney/Features/Home/PortalWebView.swift:83-216,238-315,323-450`; reset trigger `ios/HOney/App/RootView.swift:34-38`.
- Timetable uses app-wide actor cache, same-date coalescing, UUID/scope generations, 10-minute freshness, capacity 45, request-generation guards, 60ms input debounce, and adjacent prefetch — `ios/HOney/Services/TimetableRepository.swift:19-122`; `ios/HOney/Features/Timetable/TimetableViewModel.swift:10-177`.
- Tests cover different-date stale response, view-model recreation cache, A-B-A, adjacent prefetch, and empty-day cache — `ios/HOneyTests/TimetableViewModelTests.swift:54-217`.
- Access now separates permit and door success/error, keeps read loading separate from mutation work, preserves permit submission outcome across list refresh, and retains exact-door/non-replay behavior — `ios/HOney/Features/Access/AccessViewModel.swift:16-116`; `ios/HOney/Features/Access/AccessView.swift:182-351,682-746`.
- Primary lesson understanding completes directly. Remaining usefulness edges: the focal lesson still lacks a direct action; stale approved permit rows can remain actionable after permit refresh failure; and Access physical mutation controls are not single-flight-disabled — `HomeView.swift:110-193`; `AccessViewModel.swift:46-54,98-116`; `AccessView.swift:182-210,269-340,402-452,628-744`.

## E3 — Visual system and palettes

- Declared spacing tokens: `[4,8,12,16,20,24]` pt — `ios/HOney/DesignSystem/AppTheme.swift:168-175`. Login-authored values: `[7,8,14,15,18,24,32,40,42]` plus 52pt controls — `ios/HOney/Features/Auth/LoginView.swift:17-27,42-137`.
- Runtime Login type: `[12,13,15,17,28]` pt plus bitmap wordmark. App-wide referenced scale is approximately `[11,12,13,15,17,19,20,22,28,34]` pt — `AppTheme.swift:183-220`; `HomeView.swift:123-147,211-224`; `PortalWebView.swift:424-449`.
- Each of four Surface palettes defines ten adaptive roles: canvas, surface, muted, ink, secondaryInk, accent, accentForeground, accentSoft, line, controlBorder. Shared success/warning/error make **13 semantic roles per palette** — `ios/HOney/DesignSystem/AppTheme.swift:21-31,34-165`.
- Settings persists Paper, Neutral White, Cool Mist, or Soft Gray only when Done is selected; preview copy and accessibility label state this — `ios/HOney/Features/Settings/SettingsView.swift:18-109`.
- Lowest audited enabled semantic-text contrast: Paper 4.85:1, Neutral White 5.04:1, Cool Mist 5.05:1, Soft Gray 4.97:1. Non-text border minima are 4.43 or better. Token tests cover core text/accent/border/status pairs — `ios/HOneyTests/SurfacePaletteTests.swift:27-83`.
- Timetable `P#` remains direct `Palette.accent`; no opacity-based text foreground exists — `ios/HOney/Features/Timetable/TimetableView.swift:495-506`.
- One shallow Home-only atmosphere remains behind content — `AppTheme.swift:160-165`; `ios/HOney/DesignSystem/AppComponents.swift:269-280`; `HomeView.swift:20-49`.
- Wordmark is template-tinted and accessible but remains a placeholder PNG in only the universal 1x slot; independent small mark remains absent — `AppComponents.swift:283-295`; `ios/HOney/Resources/Assets.xcassets/BrandWordmarkPlaceholder.imageset/Contents.json:1-24`.

## E4 — Copy and honesty

### Screen copy inventory

- Root/tabs: app loading and four destinations — `ios/HOney/App/RootView.swift:13-38`; `ios/HOney/Features/Main/MainTabView.swift:19-38`.
- Login/consent: brand introduction, account/password labels, Sign-in states, credential disclosure/errors, separate import choice and consequences — `ios/HOney/Features/Auth/LoginView.swift:34-114`; `ImportConsentView.swift:18-86`; `ios/HOney/App/AppModel.swift:63-125`.
- Home/Portal: greeting/date, lesson states/metadata, Share/Open Access, class Experiences, Portal row, preparing/loading/authenticating/content/failure/timeout/retry/close copy — `ios/HOney/Features/Home/HomeView.swift:20-379`; `PortalWebView.swift:323-450`.
- Experiences/composer/recovery: feed/filter/empty/errors, provenance/reactions/report, target/editor/moderation/cooldown, publish/private/recovery key/copy/retry/close states — `ios/HOney/Features/Experiences/ExperiencesView.swift:26-160`; `InteractiveExperienceRow.swift:20-76`; `ReportSheet.swift:24-97`; `ComposeExperienceView.swift:73-442`; error mapping `ExperienceSubmitCopy.swift:10-42`.
- My Posts: loading/read/server error with retry, genuine empty, key warning, status, revoke/delete confirmations, private-note actions — `ios/HOney/Features/Experiences/MySubmissionsView.swift:80-178,183-337`.
- Timetable/history/lesson: date/week/day/cache-refresh/error/empty/period/break/free/lesson/action copy — `ios/HOney/Features/Timetable/TimetableView.swift:40-713`; `TimetableViewModel.swift:84-145`; `History/HistoryView.swift:21-152`; `LessonDetailView.swift:15-158`.
- Access: separate permit/door loading and errors, draft/permit list, route/gate names, confirmations, success/unknown outcome/recovery copy — `ios/HOney/Features/Access/AccessView.swift:49-746`; `AccessViewModel.swift:35-175`.
- Settings: Surface picker/preview/application rule, account/delete outcomes, import/disconnect, privacy, About — `ios/HOney/Features/Settings/SettingsView.swift:21-255`; account result model `ios/HOney/App/AppModel.swift:18-22,197-223`.

### Positive mappings

- Portal copy maps to explicit phases; content is hidden/noninteractive until ready, timeout says the attempt was stopped, and account data is reset before a new open — `PortalWebView.swift:83-216,323-450`.
- Timetable distinguishes cold loading, updating cached content, no-cache failure, and saved-cache refresh failure; generation/date guards prevent committed stale results — `TimetableView.swift:40-96`; `TimetableViewModel.swift:84-153`.
- Publication journals multiple unresolved keys, keeps only the matching record, uses local-only five-minute clipboard, serializes retry, and exposes safe/unsafe close copy based on journal persistence — `ios/HOney/Services/PublishedKeyRecoveryStore.swift:17-60`; `ComposeExperienceViewModel.swift:150-165,244-264,324-364`; `ComposeExperienceView.swift:136-200`.
- Account deletion separates server failure from partial local cleanup and signs out after successful server deletion — `AppModel.swift:197-223`; `SettingsView.swift:246-254`.
- My Posts does not convert key-read failure into empty and provides retry — `MySubmissionsView.swift:80-105,287-314`.
- No marketing superlative, fake scarcity, hidden cost, forced continuity, or confirmshaming was found.

### Remaining P1 honesty/state mismatches

1. Composer draft save/write still suppresses encoding/filesystem failure, while `runCheck` proceeds after claiming persistence-before-network and user copy says the draft is safe — `ios/HOney/Services/ComposerDraftStore.swift:50-79`; `ios/HOney/Features/Experiences/ComposeExperienceViewModel.swift:73-76,268-273`.
2. Recovery journal read errors are swallowed with `try?`, allowing ordinary editing/publishing while unresolved-key status is unknown — `ComposeExperienceViewModel.swift:150-176`; `PublishedKeyRecoveryStore.swift:25-44`.
3. Key verification and draft/journal cleanup share one error path. A verified key plus draft-clear failure still says the key could not be saved; initial success ignores journal-clear failure and may resurrect stale recovery — `ComposeExperienceViewModel.swift:244-263,341-364`.
4. Session removal still suppresses Keychain failure and is not included in `AccountDeletionResult`, so `.complete` does not verify all local HOney session data was erased — `ios/HOney/Services/SessionStore.swift:24-32`; `ios/HOney/App/AppModel.swift:197-223`.
5. Login says portal credentials are saved for automatic reauthentication, but credential persistence remains `try?` and login proceeds after failure — `ios/HOney/Features/Auth/LoginView.swift:90-114`; `ios/HOney/App/AppModel.swift:63-87`.
6. `startupNotice` is not cleared on login/sign-out/account deletion/disable-import and can cross session state — `AppModel.swift:26-35,63-98,127-149,183-223`; Home renders it unconditionally at `HomeView.swift:26-36`.
7. Successful publish still says `nothing links the post back to you`, while the device key proves ownership and an authenticated mine endpoint retrieves owned posts — `ComposeExperienceView.swift:202-219`; `MySubmissionsView.swift:287-314`.
8. Permit refresh failure leaves old permit rows in place; their row Open action checks door readiness but not permit freshness, while the bottom Exit-permit action correctly blocks — `AccessViewModel.swift:46-54`; `AccessView.swift:182-210,317-340,402-452`.

### P2 copy/detail friction

- `Share a lesson` actually shares an Experience about a past lesson — `HomeView.swift:183-193`.
- Account-delete confirmation names keys/notes/drafts but omits the protected published-key recovery record that erase-everything also clears — `SettingsView.swift:62-76`; `AppModel.swift:207-216`.
- Failed entity-name resolution can expose raw `entityKey` — `MySubmissionsView.swift:316-337`.

## E5 — Accessibility and states

- Explicit accessibility-label templates: **15**, covering wordmark, Home Settings/progress, Portal reload/failure focus, Timetable update/refresh/lesson/week arrows, Access dismissal, Surface preview, recovery key, rating, Experiences toolbar pair, and reactions — representative citations `AppComponents.swift:283-295`; `HomeView.swift:52-58,153-156`; `PortalWebView.swift:323-443`; `TimetableView.swift:69-110,404-416,657-673`; `SettingsView.swift:88-104`; `ComposeExperienceView.swift:149-164`.
- Login focus order is account > password > Sign in, with keyboard Done and visible 2pt focus stroke — `ios/HOney/Features/Auth/LoginView.swift:11-15,34-38,61-103,117-137`.
- Portal hides and disables WebView content until `.content`; overlays are modal, combined, announce authentication, and focus failure/timeout headings — `PortalWebView.swift:323-443`.
- Shared primary/secondary actions are 52/50pt, and representative Timetable, filter, reaction, My Posts, Home, Access, Login, and consent actions meet 44pt/platform semantics — `ios/HOney/DesignSystem/AppComponents.swift:232-267`; `TimetableView.swift:87-110,339-366,657-713`; `InteractiveExperienceRow.swift:20-76`; `MySubmissionsView.swift:223-269`; `AccessView.swift:213-243,439-452,704-731`.
- Six generic states are present: empty `AppComponents.swift:72-82`; loading `AppComponents.swift:56-69`; error `AppComponents.swift:85-137`; success `AccessViewModel.swift:72-116`; focus `LoginView.swift:117-136`; disabled `AppComponents.swift:232-247`.
- Additional advanced states exist for Portal timeout/process termination/retry, Timetable load-vs-refresh/cache fallback, recovery key, partial account cleanup, and independent Access reads.
- Remaining rough states: Portal account-reset wait has `.idle`/empty overlay until reset completes — `PortalWebView.swift:83-96,109-127,373-394`; Timetable shows the new header with old lessons during its 60ms cache-miss debounce — `TimetableViewModel.swift:56-63,93-114`; Access physical mutation controls remain enabled during `isWorking` — `AccessView.swift:269-340,628-744`; draft/journal/session/credential failures in E4 are not modeled precisely.
- Root and Access custom motion honor Reduce Motion; custom animations remain globally disabled — `ios/HOney/App/RootView.swift:9-30`; `AccessView.swift:9-12,213-353`; `ios/HOney/App/AppConfig.swift:14-17`.

## E6 — Weight and friction

- Native initial JavaScript: **0 bytes**. Portal injects only an on-navigation expiry probe — `ios/HOney/Services/PortalWebSessionBridge.swift:78-102`.
- Signed thin-arm64 Debug app: **25,192 KiB allocated**, 25,767,621 logical bytes. Largest files: `Assets.car` 15,898,584 bytes; `HOney.debug.dylib` 9,689,344 bytes. Identifier `com.gaelisus.honey`, Team ID `ALQXG4KCRB`. Not Release/App Store-thinned size.
- Installed simulator Debug app measured 34,956 KiB and includes XCTest/injection support; not comparable to store download weight.
- Request counts from source: signed-out/no session Login 0 blocking requests; valid-session launch `/api/me` 1 plus background portal restore 0 or 2 auth calls; Home 2 parallel reads — `AppModel.swift:44-60`; `HomeViewModel.swift:26-48`; `PortalSessionCoordinator.swift:153-177`.
- Timetable cache hit 0; cold selected day 1 foreground plus up to 2 sequential prefetch requests — `TimetableViewModel.swift:155-169`. Access refresh 2 parallel reads plus 0 or 2 auth calls — `AccessViewModel.swift:35-69`. Portal cold 1 WebKit navigation; expiry can add login+identity and one reload, bounded by one 12-second UI attempt — `PortalWebView.swift:156-216`.
- Numeric app TTI was not measured. Correct method is process-launch signpost to first enabled control, with separate content-ready signposts; Portal/Timetable signposts do not establish app TTI.
- Initial Login and signed-in Home notifications/badges/modals: 0/0/0; conditional banners are inline and sheets user-triggered.
- Decorative idle animation: 0. Home 60-second and cooldown 30-second timers are functional. Dark mode and Reduce Motion are honored — `AppConfig.swift:14-17`; `HomeView.swift:20-24`; `ComposeExperienceView.swift:420-426`; `RootView.swift:9-30`; `AccessView.swift:9-12,213-353`.

## E7 — Per-principle factual map

- #1: conventional native shell plus target-bound fail-closed publication/recovery, exact-door physical Access, multi-Surface adaptive tokens, bounded Portal attempts, and coalesced Timetable cache; no 5+ peer comparison.
- #2: primary lesson state is immediate; Portal/Timetable/recovery workflows are directly supported. Stale permit-row and reentrant physical-action edges remain.
- #3: coherent native type/spacing and 13-role four-palette system with passing contrast; placeholder wordmark and missing current screenshots remain.
- #4: Portal, recovery, palette, deletion, Timetable, and Access states are named; one icon-only My Posts control, `Share a lesson`, and omitted recovery-journal deletion detail remain.
- #5: flat quiet Login, shallow Home-only atmosphere, state chrome only when needed; content remains focal.
- #6: positive state mapping coexists with multiple storage/session/copy mismatches in E4.
- #7: adaptive native system is durable; placeholder brand asset is the explicit temporary marker.
- #8: six generic and many advanced states exist; several edge states and fresh signed-in runtime verification remain rough.
- #9: zero native JS/idle attention, dark/Reduce Motion, bounded Portal attempt, and Timetable cache/coalescing; cold prefetch intentionally uses up to two extra requests.
- #10: targetless composer removed and new recovery controls are state-bearing; Home still duplicates permanent Access/Experiences tab destinations.

## Known gaps

- No current signed-in/alternate-palette screenshots or physical-device run.
- No Portal controller/account-reset test, Access partial-state/single-mutation test, app TTI, Release size, energy/network trace, or WebView DOM audit.
- Timetable lacks invalidate-during-flight, TTL/bounded-prefetch, and immediate pre-debounce UI tests.
- Recovery lacks journal-read/clear failure and stale-journal-with-verified-key tests; deletion lacks notes/drafts/recovery/session failure tests.
- Test inventory is 89 methods, not an independently executed pass result.
