# HOney iOS design audit evidence

This file consolidates source and runtime evidence gathered by the structural/accessibility, visual/runtime, and copy/weight subagents. The orchestrator assigns scores separately in `02-scorecard.md`.

## Evidence limits

- Runtime evidence covers the stable signed-out Login screen on an iPhone 17 Pro simulator at 402×874 points. Authenticated screens are source-inferred because private credentials were deliberately excluded from tools and artifacts.
- Physical-iPhone interaction, production data, numeric TTI, Release/App Store size, full VoiceOver traversal, extreme Dynamic Type, localization expansion, landscape, and small-device layouts were not measured.
- The current UI is a draft. Existing brand, legacy grammar, and large-area color treatments are not preservation constraints.

## E1 — Runtime visual surface

- Stable Login screenshot: `evidence/02-login-settled.png`; focus: `evidence/03-login-username-focus.png`; locally enabled, never submitted: `evidence/04-login-enabled-dummy.png`.
- Login uses a 48-point gradient `HO` mark with stroke/shadow, a 38-point serif `HOney` title, two 48-point fields, a 48-point CTA, and two explanatory copy blocks. The authored content shares 28-point horizontal alignment. Evidence: `ios/HOney/Features/Auth/LoginView.swift:20-112`, `ios/HOney/DesignSystem/AppComponents.swift:169-193`.
- The page has a full-screen pale diagonal gradient plus a second teal mark gradient. Focus changes the caret and keyboard accessory but not the field fill or border. Evidence: `ios/HOney/Features/Auth/LoginView.swift:37-57,105-112`, `ios/HOney/DesignSystem/AppComponents.swift:169-191,227-236`.
- The user explicitly requires the current Login composition, serif title, and text-only `HO` mark to be replaced. The current large-area gradients and opaque fills must be redesigned; a future Home gradient is allowed only as a deliberate, restrained, dimensional composition rather than token spread.

## E2 — Visual system measurements

- Declared spacing tokens are `[4, 8, 12, 16, 18, 24, 28]` points; the source also uses numerous inline values outside that scale. Evidence: `ios/HOney/DesignSystem/AppTheme.swift:35-44`, representative inline values at `ios/HOney/Features/Home/HomeView.swift:64-80`, `ios/HOney/Features/Timetable/TimetableView.swift:575-610`, `ios/HOney/Features/Access/AccessView.swift:200-240`.
- Referenced type sizes span `[11, 12, 13, 15, 17, 20, 22, 23, 24, 28, 34, 38]` points across rounded, default system, and serif designs. Evidence: `ios/HOney/DesignSystem/AppTheme.swift:53-110`.
- The app references 27 visible base colors before opacity variants. The signed-in source combines the shared background gradient with translucent cards, chips, timetable band colors, a red now-line, ocean lesson bars, and an ultra-thin-material gate picker. Evidence: `ios/HOney/DesignSystem/AppTheme.swift:11-32`, `ios/HOney/DesignSystem/AppComponents.swift:95-115,169-191`, `ios/HOney/Features/Timetable/TimetableView.swift:236-246,575-610`, `ios/HOney/Features/Access/AccessView.swift:679-724`.
- Login caption text `navy.opacity(0.48)` computes to 2.80:1 against white; enabled source text at `navy.opacity(0.42)` computes to 2.40:1. Evidence: `ios/HOney/Features/Auth/LoginView.swift:96-99`, `ios/HOney/Features/Access/AccessView.swift:263-266`, `ios/HOney/Features/Timetable/TimetableView.swift:484-487`.

## E3 — Structure and friction

- The audited SwiftUI source declares 101 interactive templates: Main tab shell 4, Login 5, Import consent 2, Home 5, Portal wrapper 2, Experiences hub 11, feed row 2, entity page 1, report 3, composer 13, submissions 8, Timetable 6, lesson detail 4, History 9, Access 18, Settings 8. Evidence: representative entry points `ios/HOney/Features/Main/MainTabView.swift:11-23`, `ios/HOney/Features/Experiences/ComposeExperienceView.swift:74-385`, `ios/HOney/Features/Access/AccessView.swift:51-713`; full source inventory was inspected across the files listed in `00-scope.md`.
- Maximum expanded primary component-tree depth is 16 nodes in the timetable timeline path from `NavigationStack` through `TimelineLessonBlock` to its title `Text`. Evidence: `ios/HOney/Features/Timetable/TimetableView.swift:16-30,42-55,141-158,374-415,592-630`.
- Five repeated-purpose affordance families were found: dismiss/close declarations, Share entry points, Keep-private actions, teacher/course filter pairs, and destructive action plus confirmation flows. Evidence: `ios/HOney/Features/Experiences/ComposeExperienceView.swift:310-385`, `ios/HOney/Features/Experiences/ExperiencesView.swift:100-130`, `ios/HOney/Features/History/HistoryView.swift:99-124`, `ios/HOney/Features/Settings/SettingsView.swift:46-55`.
- Home duplicates navigation to Experiences despite Experiences already being a primary tab. Two standalone Share entry points reach the same guidance-only state. Evidence: `ios/HOney/Features/Main/MainTabView.swift:11-23`, `ios/HOney/Features/Home/HomeView.swift:146-175`, `ios/HOney/Features/Experiences/ExperiencesView.swift:27-49`, `ios/HOney/Features/Experiences/ComposeExperienceView.swift:105-115,187-205`.
- No dead input props or unused Swift imports were found by lexical/manual inspection.

## E4 — Usefulness and primary flows

- Four top-level areas directly expose Home, Experiences, Timetable, and Access. Timetable offers day/week navigation and direct lesson opening. Access fixes two gate routes outside the scroll view and requires a physical-action confirmation. Evidence: `ios/HOney/Features/Main/MainTabView.swift:11-23`, `ios/HOney/Features/Timetable/TimetableView.swift:42-158,322-401`, `ios/HOney/Features/Access/AccessView.swift:51-93,256-312`.
- Home and Experiences both label actions `Share`/`Share an experience`, but both open a targetless composer that displays guidance rather than an editor. The guidance asks users to open teacher/place/dish pages, while `EntityPageView` has no call site under `ios/HOney`. Evidence: `ios/HOney/Features/Home/HomeView.swift:55-58,146-160`, `ios/HOney/Features/Experiences/ExperiencesView.swift:27-49`, `ios/HOney/Features/Experiences/ComposeExperienceView.swift:15-26,105-115,187-205`, `ios/HOney/Features/Experiences/EntityPageView.swift:9-72`.
- Composer primary actions live after target, editor, notices, and state-dependent sections inside a scrollable Form. Evidence: `ios/HOney/Features/Experiences/ComposeExperienceView.swift:209-385`.

## E5 — Understandability and copy

- Product/internal terms appear without sufficient explanation: `Experiences`, `Verified retrospective`, `ownership key`, `one-review slot`, `target`, `HOney ID`, `Commuter`, `Direct access`, and `direct to the school portal`. Evidence: `ios/HOney/Models/HOneyModels.swift:175-195`, `ios/HOney/Features/Experiences/ComposeExperienceView.swift:128-133`, `ios/HOney/Features/Access/AccessView.swift:256-337`, `ios/HOney/Features/Settings/SettingsView.swift:66-72`.
- Ambiguous container names include `History` for past lessons and `My submissions` for both published posts and local private notes. One error directs users to `My contributions`, which is not the UI label. Evidence: `ios/HOney/Features/History/HistoryView.swift:22-32`, `ios/HOney/Features/Experiences/MySubmissionsView.swift:39-76`, `ios/HOney/Features/Experiences/ExperienceSubmitCopy.swift:27-28`.
- Image-only Settings, overflow, Portal reload, and week-arrow controls lack explicit contextual accessibility labels. Evidence: `ios/HOney/Features/Home/HomeView.swift:35-41`, `ios/HOney/Features/Experiences/ExperiencesView.swift:27-40`, `ios/HOney/Features/Home/PortalWebView.swift:121-127`, `ios/HOney/Features/Timetable/TimetableView.swift:639-657`.
- The Login fields expose focus only via caret/accessory, with no authored focus treatment. Evidence: `ios/HOney/Features/Auth/LoginView.swift:38-57`, `ios/HOney/DesignSystem/AppComponents.swift:227-236`, screenshot `evidence/03-login-username-focus.png`.

## E6 — Honesty and behavior alignment

- Report success is always shown because the network error is swallowed with `try?`; reaction selection also remains highlighted after a failed request. Evidence: `ios/HOney/Features/Experiences/ReportSheet.swift:26-31,69-78`, `ios/HOney/Features/Experiences/InteractiveExperienceRow.swift:36-50`.
- `Front`/`Back` may map to arbitrary first/second portal doors when labels do not match known keywords, yet the UI confirms a physical gate by the friendly name. Evidence: `ios/HOney/Features/Access/AccessView.swift:75-92,695-713`, `ios/HOney/Models/PortalModels.swift:179-202`, `ios/HOney/Features/Access/AccessViewModel.swift:78-98`.
- Quick Apply says it uses the current draft but discards edited start/end times and submits now plus two hours. `No active permit` can appear while permit data is loading or failed. Evidence: `ios/HOney/Features/Access/AccessView.swift:25-29,104-110,140-159,295-301`, `ios/HOney/Features/Access/AccessViewModel.swift:16-22,31-50`.
- Import and Settings toggles can visually imply success after failed updates. Error suppression also converts load failures into `No experiences yet`/`Nothing here yet`. Evidence: `ios/HOney/Features/Settings/SettingsView.swift:138-148`, `ios/HOney/App/AppModel.swift:113-121`, `ios/HOney/Features/Experiences/EntityPageView.swift:44-71`, `ios/HOney/Features/Experiences/MySubmissionsView.swift:79-89,126-140,271-284`.
- Sign out, disconnect, and delete labels claim broader state removal than their behavior: portal credentials and persistent WebView state remain. Evidence: `ios/HOney/Features/Settings/SettingsView.swift:42-55,78-127`, `ios/HOney/App/AppModel.swift:135-155`, `ios/HOney/Services/KeychainCredentialVault.swift:15-43`, `ios/HOney/Features/Home/PortalWebView.swift:25-31`.
- Login copy says the password is used only for the school portal, while it is first sent to the HOney backend and then stored in Keychain for direct portal reauthentication. Evidence: `ios/HOney/Features/Auth/LoginView.swift:96-99`, `ios/HOney/App/AppConfig.swift:19-22`, `ios/HOney/Services/HOneyAPI.swift:51-57`, `ios/HOney/App/AppModel.swift:68-72`.
- Positive honesty evidence: import is not preselected; destructive flows provide Cancel and consequences; private notes stay device-local; physical gate operation requires explicit confirmation. Evidence: `ios/HOney/Features/Auth/ImportConsentView.swift:14-16,42-76`, `ios/HOney/Features/Experiences/ComposeExperienceViewModel.swift:199-223`, `ios/HOney/Features/Access/AccessView.swift:75-93`.

## E7 — Accessibility and state coverage

- Only two explicit `.accessibilityLabel` declarations exist, for rating and reactions. No explicit hints, added traits, accessibility grouping/sort priority, or hidden-state declarations were found. Evidence: `ios/HOney/Features/Experiences/ExperienceRow.swift:51-62`, `ios/HOney/Features/Experiences/InteractiveExperienceRow.swift:45-57`.
- Tap gestures used for permit expansion and banner dismissal lack explicit button traits or labels. Several caption-sized buttons and 30/34/38-point controls have no verified 44-point hit region. Evidence: `ios/HOney/Features/Access/AccessView.swift:190-254`, `ios/HOney/Features/Timetable/TimetableView.swift:97-109,639-698`, `ios/HOney/Features/Experiences/InteractiveExperienceRow.swift:18-57`.
- Most body fonts use semantic styles, but Login, section titles, timetable header, several fixed-height controls, one-line timetable blocks, and 124-point Access dock cards create Dynamic Type risks. Evidence: `ios/HOney/DesignSystem/AppTheme.swift:53-110`, `ios/HOney/Features/Timetable/TimetableView.swift:71-117,521-698`, `ios/HOney/Features/Access/AccessView.swift:617-668`.
- Empty, loading, error, success, focus, and disabled states exist in source. Runtime observed focus and disabled/enabled Login. However focus styling is weak, several errors collapse into empty states, and several success states ignore failed requests. Evidence: `ios/HOney/DesignSystem/AppComponents.swift:57-140`, `ios/HOney/Features/Experiences/ExperiencesView.swift:56-79`, `ios/HOney/Features/Experiences/ReportSheet.swift:23-31`, screenshots `evidence/03-login-username-focus.png` and `evidence/04-login-enabled-dummy.png`.
- Root honors Reduce Motion; Access transitions do not independently read it if global animations are later enabled. Evidence: `ios/HOney/App/RootView.swift:9-28`, `ios/HOney/Features/Access/AccessView.swift:235-344`.

## E8 — Weight and attention load

- A current signed thin-arm64 Debug device product measured 13,802,821 logical bytes; `HOney.debug.dylib` is 8,117,904 bytes and `Assets.car` 5,505,224 bytes. This is not an App Store/Release size.
- No third-party Swift Package products or embedded runtime frameworks are declared; runtime dependencies are Apple system frameworks. Evidence: `ios/HOney.xcodeproj/project.pbxproj:348-380`.
- Signed-out cold launch performs zero network requests before Login. Signed-in cold Home uses `/api/me` plus two concurrent Home calls; background portal restore can add two portal calls. Evidence: `ios/HOney/App/AppModel.swift:37-52`, `ios/HOney/Features/Home/HomeView.swift:43-46`, `ios/HOney/Features/Home/HomeViewModel.swift:23-36`, `ios/HOney/Services/PortalSessionCoordinator.swift:153-176`.
- Initial Login/Home present zero notifications, zero badges, zero modals, and zero idle animations. Motion helpers return nil because the global flag is false. Evidence: `ios/HOney/App/AppConfig.swift:14-17`, `ios/HOney/DesignSystem/AppTheme.swift:119-126`, `ios/HOney/Features/Home/HomeView.swift:12-16,48-58`.
- Home wakes once per 60 seconds; composer cooldown wakes every 30 seconds while visible. Evidence: `ios/HOney/Features/Home/HomeView.swift:17-24`, `ios/HOney/Features/Experiences/ComposeExperienceView.swift:352-365`.
- The app forces `.light` and does not honor system dark mode. Evidence: `ios/HOney/App/HOneyApp.swift:13-18`.

## E9 — Innovation and longevity context

- The theme and component sources state they were ported verbatim from the legacy design system. Evidence: `ios/HOney/DesignSystem/AppTheme.swift:5-7`, `ios/HOney/DesignSystem/AppComponents.swift:5-7`.
- The current grammar combines a fixed pale-blue gradient, translucent white cards, rounded headings, capsule chips, and a serif wordmark. Evidence: `docs/design/legacy-port-map.md:7-44`.
- System fonts and native SwiftUI controls reduce custom technology burden, while the visual composition deliberately reproduces a prior app rather than introducing a new interaction pattern. Evidence: `ios/HOney/DesignSystem/AppTheme.swift:62-110`, `ios/HOney/Features/Auth/LoginView.swift:20-112`.
