# HOney iOS post-review evidence

All visual findings without a current screenshot are marked source-inferred. Subagents gathered facts; the orchestrator alone scores them.

## E1 — Structure and primary hierarchy

- Home's scroll order is greeting/notices, then the current/next lesson, Experiences preview, two quiet secondary actions, and Portal. The first substantive block is therefore lesson orientation: `ios/HOney/Features/Home/HomeView.swift:27-46,115-184`.
- Home exposes five static actions: Settings, See all, Share something, Open Access, and School Portal: `HomeView.swift:58-63,191-194,223-275`.
- The signed-in shell has four task tabs: Home, Experiences, Timetable, Access: `ios/HOney/Features/Main/MainTabView.swift:19-37`.
- Experiences has seven controls before row multiplication: Explore, Share, Yours, two feed scopes, About, and Share. Each loaded row adds like, dislike, and more: `ios/HOney/Features/Experiences/ExperiencesView.swift:29-43,91-120,146-171`; `InteractiveExperienceRow.swift:24-38,56-79`.
- Explore's count is `1 + N`: Done plus every loaded teacher/course/place/food row: `ExperiencesView.swift:233-305`.
- Timetable has `12 + n` controls: five header/week controls, seven days, and one button per visible lesson: `ios/HOney/Features/Timetable/TimetableView.swift:87-125,339-367,404-416`.
- Maximum observed primary tree depth is 14 levels including the leaf, through the Timetable timeline lesson block: `TimetableView.swift:15-25,41-54,156-172,393-416,617-645`.
- Three same-purpose pairs remain: Experiences' two lesson-share entries, Portal's two retry actions in failure state, and Access' two permit-application entries: `ExperiencesView.swift:36-39,164-167`; `PortalWebView.swift:354-357,446-447`; `AccessView.swift:103-105,159-165`.
- Two confirmed dead Home view-model members remain: `nextLessonSummary` and `isLoading`: `ios/HOney/Features/Home/HomeViewModel.swift:15,28,44`. No confirmed unused import was found manually.

## E2 — User constraints and usefulness

- Every loaded Explore choice is rendered in four complete sections; no `.searchable` gate exists: `ExperiencesView.swift:187-305`.
- Every Surface palette is rendered directly from `SurfacePalette.allCases`: `ios/HOney/Features/Settings/SettingsView.swift:79-95`; the four cases are declared at `ios/HOney/DesignSystem/AppTheme.swift:34-50`.
- Every Timetable lesson block renders a teacher label. Nil or whitespace becomes `Teacher not listed`; VoiceOver receives `teacher not listed`: `TimetableView.swift:558-563,624-683`.
- Long subject and teacher strings share one line with scale/truncation, so source guarantees presence but not full-name visibility: `TimetableView.swift:625-642`.
- Experiences now opens feed-first, keeps `Your classes / Around school`, exposes the student-to-student identity line, and moves intentional lookup to Explore: `ExperiencesView.swift:82-178,187-305`.
- Course is directly browseable, but it cannot start composition from its results because `.course` returns no `composeEntity`: `ExperiencesView.swift:217-223,307-376`.
- Switch/keyboard-equivalent controls exist for major actions. Home and Access error copy still relies on pull-to-refresh without a direct retry control: `HomeView.swift:123,179,212`; `AccessView.swift:53-63,322-333,713-715`.

## E3 — Visual system and palette evidence (source-inferred)

- Declared spacing scale is `[4, 8, 12, 16, 20, 24]` pt: `AppTheme.swift:168-175`. Actual views also introduce 7, 10, 14, 18, 22, 28, 30, 32, 38, 40, and 42 pt values: `HomeView.swift:27,127,141,163`; `LoginView.swift:19,26-27,43`; `AccessView.swift:52,125,167,186,226`.
- Semantic Apple type styles imply approximately `[11, 12, 13, 15, 17, 20, 28, 34]` pt: `AppTheme.swift:183-220`; the focal lesson uses semantic large title at `HomeView.swift:142-146`.
- The four palettes reference 82 unique adaptive RGB endpoints including status colors. Each active palette exposes canvas, surface, muted, ink, secondaryInk, accent, accentForeground, accentSoft, line, controlBorder, plus shared success/warning/error: `AppTheme.swift:21-152`.
- Accent tuples are independently tuned per palette rather than copied: `AppTheme.swift:59-110`.
- Home atmosphere is the only large gradient: `accentSoft.opacity(0.56)` toward nearly transparent canvas, top-right into the upper content field: `AppTheme.swift:160-165`; `ios/HOney/DesignSystem/AppComponents.swift:223-235`; `HomeView.swift:23-25`.
- Login uses a replaceable template-tinted image, not serif text or a text-only `HO`: `ios/HOney/Features/Auth/LoginView.swift:42-58`; `AppComponents.swift:237-249`. It remains a raster placeholder and no independent production small mark is wired.

### Contrast

- Lowest ordinary tested semantic text pairing is 4.889:1, Sage Gray light accent on accentSoft; it passes AA. Core text/accent pairs pass 4.5:1 and borders pass 3:1: `ios/HOneyTests/SurfacePaletteTests.swift:27-46`.
- A gap exists outside those tests. My Posts status chips render tint-colored caption2 text over the same tint at 15%: `ios/HOney/Features/Experiences/MySubmissionsView.swift:14-35,275-282`.
- Static sRGB calculation finds the error chip at 4.359:1 in Blue Mist dark and 4.261:1 in Sage Gray dark. Both fail the 4.5:1 requirement for this small text.
- No current-commit signed-in screenshots exist, so composition, clipping, and whether each palette actually looks coherent on-device remain unverified.

## E4 — Copy and honesty

- A reproducible inventory finds 226 direct UI construction sites with:
  `rg -n '(Text|Button|Label|Section|Picker|Toggle|TextField|SecureField|DatePicker|navigationTitle|accessibility(Label|Hint|Value)|confirmationDialog|alert|AppLoadingState|AppEmptyState)\([^\n]*"' ios/HOney/Features ios/HOney/App ios/HOney/DesignSystem --glob '*.swift'`.
- No marketing superlative, fake scarcity, hidden cost, forced continuity, confirmshaming, or engagement-rank claim was found.
- Import remains an active separate choice: `ios/HOney/Features/Auth/ImportConsentView.swift:18-57`; `ios/HOney/App/AppModel.swift:77-135`.
- Public/private publishing remains deliberate and recovery copy discloses device-key control: `ios/HOney/Features/Experiences/ComposeExperienceView.swift:136-269,435-447`.
- Private notes/drafts use protected local atomic storage; public models have no author field; sign-out preserves local notes/drafts/keys: `ios/HOney/Services/PrivateNoteStore.swift:33-100`; `ComposerDraftStore.swift:24-92`; `ios/HOney/Models/HOneyModels.swift:198-238`; `AppModel.swift:202-213`.

### Label-to-behavior mismatches

1. Explore claims every option is listed and uses honest-looking empty-section copy, but directory/entity failures are converted into partial or empty metadata with no loading/error state: `ExperiencesView.swift:233-279`; `ios/HOney/App/AppServices.swift:97-106`; `ios/HOney/Features/Experiences/ExperiencesViewModel.swift:35-43`.
2. Access tells users to `Reconnect in Settings`, but Settings offers import consent and disconnect, not credential re-entry or reconnect: `ios/HOney/Features/Access/AccessViewModel.swift:152-157,171-174`; `SettingsView.swift:166-205`.
3. `Delete account and local HOney data` clears session, post-control keys, notes, drafts, and recovery journal, but leaves the saved school credential vault: `SettingsView.swift:61-75`; `AppModel.swift:220-250`.
4. The palette footer promises a tuned `blue accent`, although Sage Gray is green-teal. `accent tuned for its surface` is the accurate wording: `SettingsView.swift:91-94`; `AppTheme.swift:98-109`.
5. `Open OASIS in the app` assumes acronym knowledge; `Open the school portal in the app` is clearer: `HomeView.swift:250-265`.
6. Settings speaks of local `drafts` plural, while `ComposerDraftStore` is one overwriteable target-keyed slot: `SettingsView.swift:161`; `ComposerDraftStore.swift:3-11,44-52`.

## E5 — State and accessibility evidence

- Empty, loading, error, success, focus, and disabled states all exist in the shared system and representative flows: `AppComponents.swift:76-157,186-220`; `ExperiencesView.swift:123-177,342-361`; `PortalWebView.swift:382-448`; `AccessViewModel.swift:85-116`; `LoginView.swift:92-136`.
- Explore target metadata is the rough state family: loading, failure, partial success, and genuine empty are not distinguished before rendering the complete list: `ExperiencesView.swift:233-279`; `AppServices.swift:97-106`; `ExperiencesViewModel.swift:35-43`.
- Login's inferred VoiceOver order is wordmark, introduction, username, password, Sign in, credential disclosure: `LoginView.swift:42-114`.
- Experiences' inferred order is Explore, Share, Yours, community meaning, feed scope, then rows/actions: `ExperiencesView.swift:28-43,86-177`; `InteractiveExperienceRow.swift:21-79`.
- Timetable's inferred order is header, Refresh, Past lessons, week controls, seven days, then lesson buttons: `TimetableView.swift:69-125,334-367,387-416`.
- Palette rows are each one named accessibility element with Selected/Not selected value: `SettingsView.swift:98-128`.
- `Why this space exists` has a 32pt minimum height rather than the project 44pt target: `ExperiencesView.swift:109-120`.
- Timetable lesson buttons can have a 20pt frame and attempt only a 12pt content-shape expansion; actual hit target requires device verification: `TimetableView.swift:404-415,541-545`.
- Portal hides inaccessible WebView content during recovery, announces authentication, and moves focus to failure/timeout: `PortalWebView.swift:337-372,400-448`. External OASIS DOM accessibility remains unverified.
- ARIA landmarks and skip links are not applicable to native SwiftUI. Native equivalents are the TabView, NavigationStacks, List/Form sections, sheets, alerts, and confirmation dialogs.

## E6 — Weight, requests, and runtime friction

- Native initial JavaScript is N/A; there is no app JS bundle. Portal injects only a navigation-time expiry probe: `ios/HOney/Services/PortalWebSessionBridge.swift:78-102`.
- Initial notifications, badges, and modals are 0. Root starts with an inline loading state; Home/Experiences/Access modal state begins false or nil: `ios/HOney/App/RootView.swift:18-33`; `HomeView.swift:14-18`; `ExperiencesView.swift:11-16`; `AccessView.swift:15-27`.
- Continuous decorative idle animations are 0. Home's 60-second timeline and composer's cooldown timer update functional state. Explicit Access motion is action-triggered and Reduce Motion gated: `HomeView.swift:22`; `ComposeExperienceView.swift:420-427`; `AccessView.swift:11,216-219,303-310`.
- Home cold path is four reads: next lesson, class feed, directory, entities. Warm recreation within TTL is one next-lesson request: `HomeViewModel.swift:30-59`; `AppServices.swift:79-107,175-213`.
- Experiences is three cold requests, zero warm after Home, and one request on first switch to the uncached school scope: `ExperiencesView.swift:45-50`; `ExperiencesViewModel.swift:35-57`; `AppServices.swift:175-213`.
- Timetable is one primary request plus up to two adjacent prefetches cold, zero on a fresh cache hit: `ios/HOney/Features/Timetable/TimetableViewModel.swift:93-128,155-169`; `ios/HOney/Services/TimetableRepository.swift:19-105`.
- Access always performs two safe reads on open/refresh; expired/no session can add login and identity, for up to four: `AccessViewModel.swift:35-69,122-135`; `ios/HOney/Services/PortalSessionCoordinator.swift:153-176`.
- Settings performs one profile request each open; History performs two each open; each Explore result performs one per open/refresh/composer dismissal without a repository cache: `SettingsView.swift:56-60`; `HistoryView.swift:37-41`; `HistoryViewModel.swift:53-74`; `ExperiencesView.swift:370-395`.
- The school feed still loads up to 100 items and has no cursor/append/scroll-restoration contract: `AppServices.swift:191-204`; `ios/HOney/Models/HOneyModels.swift:116-165`.
- Numeric app TTI, cold/warm Portal timing, scroll jank, energy trace, Release size, and current installed size were not measured.

## E7 — Verification evidence and gaps

- Supplied implementation verification: generic signed arm64 Debug device build succeeded; XCTest reported 94 tests and 0 failures. This audit did not independently reproduce the run.
- No fresh signed-in physical-iPhone screenshots, alternate-palette captures, VoiceOver/Switch Control traversal, accessibility Dynamic Type, Reduce Motion run, or small-device capture exists.
- No dedicated UI/unit test covers the Timetable teacher fallback.
- `ExperienceTargetRepository` has no direct TTL/coalescing/invalidation test. Timetable and Experience feed caches do: `ios/HOneyTests/TimetableViewModelTests.swift:56-143`; `ios/HOneyTests/ExperienceContractDecodingTests.swift:351-391`.
- Dynamic completeness and cardinality of backend teacher/course/entity collections cannot be established because current iOS response models expose no pagination metadata: `HOneyModels.swift:116-165`.

## E8 — Per-principle factual map

1. Innovative: conventional native shell plus anonymous device-key control, bounded Portal recovery, actor caches, and complete non-search-gated target browsing.
2. Useful: current/next lesson is the first substantive Home object; all target categories and teacher labels are directly represented. Course composition and direct error retry remain adjacent friction.
3. Aesthetic: one semantic type/color system and independently tuned palettes exist; spacing one-offs, two dark-chip contrast failures, placeholder identity, and missing current visuals remain.
4. Understandable: teacher/access outcomes are named; Explore completeness, reconnect routing, delete scope, `blue` palette wording, and `OASIS` create clarity gaps.
5. Unobtrusive: no idle decoration or startup modal/badge; the only atmospheric gradient stays behind Home content.
6. Honest: import/publication/privacy flows are explicit; several label-to-behavior mismatches remain in E4.
7. Long-lasting: semantic Apple styles and native controls dominate; the raster placeholder identity is the explicit temporary marker.
8. Thorough: all six generic states exist; Explore metadata truth, dark-chip contrast, gesture-only retry, touch-target verification, and physical-device evidence remain rough.
9. Environmentally friendly: native JS is N/A, no idle attention, adaptive appearance and Reduce Motion are honored, and major feeds/timetable are cached and coalesced.
10. As little design as possible: four direct tabs and lesson-first hierarchy are restrained; two visible explanatory/meta lines and two simultaneous duplicate-action pairs can be removed after their behavior is made self-evident.
