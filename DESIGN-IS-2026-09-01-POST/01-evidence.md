# HOney iOS post-redesign evidence

## E1 — Runtime and visual system

- Final Login captures are `evidence/login-light-placeholder-v2.png` and `evidence/login-dark-placeholder-v2.png`, both 402×874 points on an iPhone 17 Pro simulator. They show the same hierarchy in adaptive light/dark appearance with no clipping or large-area Login gradient.
- Login contains one temporary template-tinted wordmark, one headline/support block, two labeled fields, one CTA, and one credential disclosure. Evidence: `ios/HOney/Features/Auth/LoginView.swift:17-137`, `ios/HOney/DesignSystem/AppComponents.swift:203-229`.
- The semantic system uses adaptive canvas, surface, muted surface, ink, secondary ink, accent/foreground/soft, line, success, warning, and error roles. Evidence: `ios/HOney/DesignSystem/AppTheme.swift:14-58`.
- Declared spacing is `[4, 8, 12, 16, 20, 24, 28]` points; rendered Login typography is 12/13/15/17/28 points plus the temporary wordmark image. Evidence: `ios/HOney/DesignSystem/AppTheme.swift:62-126`, `ios/HOney/Features/Auth/LoginView.swift:42-137`.
- Lowest enabled primary-action contrast is 6.08:1 in light mode and 8.03:1 in dark mode after introducing adaptive `accentForeground`. Warning text was darkened for light mode, and low-opacity navy text was migrated to explicit ink roles. Evidence: `ios/HOney/DesignSystem/AppTheme.swift:35-46`, `ios/HOney/DesignSystem/AppComponents.swift:85-180`.
- The only large-area gradient is a shallow Home atmosphere, opt-in on Home only; Login and other ordinary page backgrounds are flat semantic canvases. Evidence: `ios/HOney/DesignSystem/AppTheme.swift:54-59`, `ios/HOney/DesignSystem/AppComponents.swift:203-214`, `ios/HOney/Features/Home/HomeView.swift:20-44`.

## E2 — Usefulness and structure

- Four primary tabs remain: Home, Experiences, Timetable, Access. Home cross-tab actions change the existing selection instead of nesting duplicate tab content. Evidence: `ios/HOney/Features/Main/MainTabView.swift:8-40`.
- Home puts current/next lesson before all secondary actions; it then exposes targeted lesson sharing, Access, class Experiences, and School Portal. Evidence: `ios/HOney/Features/Home/HomeView.swift:20-44,102-295`.
- Home and Experiences open Past lessons selection and then a target-bound composer; the targetless `.standalone` route was removed. Evidence: `ios/HOney/Features/Home/HomeView.swift:69-80,177-194`, `ios/HOney/Features/Experiences/ExperiencesView.swift:27-55`, `ios/HOney/Features/Experiences/ComposeExperienceView.swift:15-58,102-113`.
- Access lists returned `PortalDoor` names, confirms the exact selected name, never guesses an opaque Front/Back mapping, blocks permit actions until loading resolves, and applies the displayed draft times. Evidence: `ios/HOney/Features/Access/AccessView.swift:72-118,265-351,680-735`, `ios/HOney/Features/Access/AccessViewModel.swift:32-105`, `ios/HOney/Models/PortalModels.swift:170-200`.
- The source contains 102 interactive templates across all data-dependent states; the maximum expanded tree depth remains 16 in the timetable timeline. Five repeated-purpose families remain across the entire multi-screen product, but state-exclusive alternatives are not simultaneously visible. Evidence: `ios/HOney/Features/Timetable/TimetableView.swift:14-53,370-410,588-626` and the per-screen source inventory in `00-scope.md`.

## E3 — Honesty and copy

- Report and reaction success now appear only after successful requests; failures remain visible. Evidence: `ios/HOney/Features/Experiences/ReportSheet.swift:76-95`, `ios/HOney/Features/Experiences/InteractiveExperienceRow.swift:53-76`.
- Import-setting failure reverts the toggle; delete failure preserves session/local data; disconnect updates local state even if refresh fails. Evidence: `ios/HOney/Features/Settings/SettingsView.swift:94-135,178-199`, `ios/HOney/App/AppModel.swift:113-185`.
- Initial sync failure creates a visible Home notice, and pull-to-refresh now actually retries `/api/sync` before reloading Home reads. Evidence: `ios/HOney/App/AppModel.swift:90-125`, `ios/HOney/Features/Home/HomeView.swift:30-37,61-68`.
- Home tracks next-lesson and Experiences availability independently, so partial failure cannot become a false empty state. Evidence: `ios/HOney/Features/Home/HomeViewModel.swift:14-48`, `ios/HOney/Features/Home/HomeView.swift:102-174,236-268`.
- Credential transmission/storage, sign-out scope, disconnect scope, account deletion, local notes/drafts, and post-control keys are described explicitly. Evidence: `ios/HOney/Features/Auth/LoginView.swift:90-115`, `ios/HOney/Features/Settings/SettingsView.swift:47-160`, `ios/HOney/Features/Experiences/MySubmissionsView.swift:130-173`.
- Product/domain terms were reduced: `Verified retrospective` became `Based on a past lesson`; user copy uses `post-control key`; registry/review-slot/target language was removed from visible errors and statuses. Evidence: `ios/HOney/Models/HOneyModels.swift:175-195`, `ios/HOney/Features/Experiences/ExperienceSubmitCopy.swift:10-42`, `ios/HOney/Features/Experiences/MySubmissionsView.swift:19-34`.
- No marketing inflation, hidden cost, forced continuity, fake scarcity, confirmshaming, or unresolved load-bearing label/behavior mismatch was found in the final delta review.

## E4 — States and accessibility

- Empty, loading, error, success, focus, disabled, enabled, offline, destructive-confirmation, and physical-action uncertainty states are represented. Evidence: shared states `ios/HOney/DesignSystem/AppComponents.swift:56-137`; representative screens `ExperiencesView.swift:64-110`, `ReportSheet.swift:16-97`, `AccessView.swift:179-351`, `SettingsView.swift:18-199`.
- Login uses a visible 2-point accent focus stroke and 52-point controls. Shared primary/secondary actions are at least 52/50 points. Evidence: `ios/HOney/Features/Auth/LoginView.swift:61-137`, `ios/HOney/DesignSystem/AppComponents.swift:166-201`.
- Wordmark, Settings, lesson progress, Experience toolbar actions, ratings/reactions, Access banner dismissal, Portal reload, and week navigation have explicit labels. Evidence: `ios/HOney/DesignSystem/AppComponents.swift:217-229`, `ios/HOney/Features/Home/HomeView.swift:48-55,143-147`, `ios/HOney/Features/Home/PortalWebView.swift:117-130`, `ios/HOney/Features/Timetable/TimetableView.swift:635-660`.
- Filter chips, Past lessons, day selectors, reactions/Report, permit actions, Home See all, and short timeline blocks declare at least a 44-point target or expanded hit shape. Evidence: `ExperiencesView.swift:169-186`, `InteractiveExperienceRow.swift:20-76`, `TimetableView.swift:81-93,329-345,389-400`, `AccessView.swift:213-220,432-444`.
- Root and Access independently honor Reduce Motion; custom motion is globally off by default. Evidence: `ios/HOney/App/RootView.swift:9-28`, `ios/HOney/Features/Access/AccessView.swift:9-12,213-345`, `ios/HOney/App/AppConfig.swift:14-17`.
- Remaining verification gap: authenticated screens, extreme Dynamic Type, VoiceOver traversal, and overlapping short timeline hit regions were not exercised on-device.

## E5 — Weight and attention

- Fresh signed thin-arm64 Debug app allocation is 24,104 KiB; the largest files are `Assets.car` (15.9 MB) and the Debug dylib (8.6 MB). This is not an App Store-thinned size.
- No third-party Swift package products are declared. Initial signed-out Login makes zero requests; valid-session Home uses `/api/me` plus two Home reads. Evidence: `ios/HOney.xcodeproj/project.pbxproj:348-380`, `ios/HOney/App/AppModel.swift:39-49`, `ios/HOney/Features/Home/HomeViewModel.swift:26-48`.
- Login/Home have zero idle animations, notifications, badges, autoplay media, or initial modals. Home’s 60-second update and cooldown’s 30-second update are functional timers, not decorative animation. Evidence: `ios/HOney/App/AppConfig.swift:14-17`, `ios/HOney/Features/Home/HomeView.swift:20-24`, `ios/HOney/Features/Experiences/ComposeExperienceView.swift:340-365`.
- System appearance is honored and all core roles are adaptive. No numeric TTI, Release archive, energy trace, physical-device screenshot, or App Store thinning report was collected.
