# Web source → native traceability (port spec §31)

Every native file names the Web source it was ported from. Reverse map:

| Web source (at 9cbedf6) | Native destination | Action |
|---|---|---|
| `packages/shared/src/api/contract.ts` | `HOneyCore/Sources/HOneyCore/API/DTO/Wire.swift`; fixtures `packages/shared/fixtures/api/*.json` ⇄ `packages/shared/src/api/fixtures.ts` (TS `satisfies`) ⇄ `FixtureDecodingTests` | mandatory parity |
| `apps/web/src/api/client.ts` | `API/APIClient.swift` (bearer, single-flight refresh, session lost), `API/PublicationAPIClient.swift` (identity-free publish), `API/APIError.swift`, `Experiences/Copy.swift` (`APIErrorCopy`) | same API, native transport |
| `apps/web/src/auth/AuthContext.tsx` | `HOneyNative/App/AppEnvironment.swift` (`bootstrap`, `refreshMe`, `signOut`, `sessionLost`) | preserve semantics |
| `apps/web/src/lib/portalCredentials.ts` | `Portal/PortalSessionCoordinator.swift` (`SchoolCredentialVault` on the Keychain), `Storage/LocalStores.swift` (`Preferences.stayConnectedWanted`, default on) | Keychain replaces browser encryption |
| `apps/web/src/lib/portalEntry.ts` + `/api/portal/entry` | `HOneyNative/Features/Portal/PortalController.swift`, `PortalView.swift` (new WKWebView surface) | preserve protocol |
| `apps/web/src/lib/ownershipKeys.ts` | `Storage/OwnershipKeyStore.swift` (Keychain, same export file), `Storage/PrivateNoteStore.swift` (protected file, per account), `Storage/LocalStores.swift` (`TransferBundle`) | Keychain / file protection |
| `apps/web/src/lib/composerDraft.ts` | `Storage/LocalStores.swift` (`ComposerDraftStore`) | preserve |
| `apps/web/src/lib/recentContexts.ts` | `Storage/LocalStores.swift` (`Preferences.recentContexts`) | preserve |
| `apps/web/src/lib/format.ts` | `Domain/Formatters.swift` (en-GB output spelled out, tested) | preserve output |
| `apps/web/src/lib/displayNames.ts` (+ test) | `Domain/CourseDisplay.swift` (+ `DisplayNamesTests`) | preserve rules |
| `apps/web/src/lib/periodCatalog.ts` | `Domain/PeriodCatalog.swift` | one catalog for Day and Week |
| `apps/web/src/lib/i18n.ts` | `Localization/L10n.swift` | preserve dictionary; System/English/中文 |
| `apps/web/src/lib/navigation.ts`, `App.tsx`, `AppLayout.tsx`, `navTabs.tsx` | `HOneyNative/App/Navigator.swift` (`AppRoute`, deep links), `RootTabView.swift` (TabView + five NavigationStacks) | replace implementation |
| `apps/web/src/pages/HomePage.tsx` | `Features/Home/HomeView.swift`, `HomeViewModel.swift`; `Domain/HomeLesson.swift` (`HomeLessonPresentation`) | preserve hierarchy |
| `apps/web/src/pages/LoginPage.tsx`, `SchoolLoginForm.tsx`, `ReconnectDialog.tsx` | `Features/Login/LoginView.swift`; `Features/Settings/SettingsViews.swift` (`SchoolLoginSheet`) | condensed footer |
| `apps/web/src/pages/experiences/FeedPage.tsx`, `features/experiences/useFeedController.ts` | `Features/Experiences/Feed/ExperiencesFeedView.swift`, `FeedViewModel.swift`; `Experiences/FeedStore.swift` | preserve |
| `apps/web/src/features/experiences/ExperiencePost.tsx` | `Features/Experiences/Feed/ExperiencePostRow.swift`; `Domain/ExperienceDisplay.swift`; `Experiences/FeedStore.swift` (`ReactionState`) | preserve anatomy |
| `apps/web/src/pages/experiences/shared.tsx` | `Experiences/Copy.swift`, `Domain/ExperienceDisplay.swift`, `HOneyNative/Features/Experiences/Names.swift` | preserve copy |
| `apps/web/src/pages/experiences/ExplorePage.tsx` | `Features/Experiences/Explore/ExploreView.swift` | Web frame (field + chips), complete listing |
| `apps/web/src/pages/experiences/EntityPage.tsx` | `Features/Experiences/Entity/EntityExperiencesView.swift` | preserve |
| `apps/web/src/pages/experiences/ComposePage.tsx`, `useComposer.ts` | `Features/Experiences/Compose/TargetPickerView.swift`, `ComposerView.swift`, `ComposerViewModel.swift`; `Experiences/ComposerController.swift` (+ tests) | reimplement cleanly, same API |
| `apps/web/src/pages/experiences/MinePage.tsx` | `Features/Experiences/Mine/NotesAndPostsView.swift` | Keychain / file wording |
| `apps/web/src/pages/experiences/WhyPage.tsx` | `Features/Experiences/Why/WhyView.swift` | content parity |
| `apps/web/src/pages/SettingsPage.tsx` (privacy section, key management) | `Features/Experiences/Privacy/HowAnonymityWorksView.swift` | native storage claims |
| `apps/web/src/pages/TimetablePage.tsx` | `Features/Timetable/TimetableRootView.swift`, `TimetableViewModel.swift`, `Day/DayTimelineView.swift`, `LessonDetail/LessonDetailSheet.swift`; `Domain/DayGeometry.swift` | preserve product, native interaction |
| `apps/web/src/features/timetable/WeekView.tsx` | `Features/Timetable/Week/WeekTimetableView.swift`; `Domain/WeekMatrix.swift` | native Grid |
| `apps/web/src/pages/HistoryPage.tsx` | `Features/Timetable/History/HistoryView.swift`; `Domain/HistoryGrouping.swift` | whole-row native interaction |
| `apps/web/src/pages/SettingsPage.tsx` | `Features/Settings/SettingsViews.swift` | open row groups; Background · Accent · Text size · Language |
| `apps/web/src/styles/tokens.css`, `lib/theme.ts`, `lib/textSize.ts` | `HOneyCore/Domain/Appearance.swift` (`ThemePalette`, tested against tokens.css), `HOneyNative/Core/Design/Theme.swift`, `ThemeEnvironment.swift`, `Tokens.swift` | exact colours, spacing, radii |
| `apps/web/src/styles/fonts.css`, `foundations.css` (type grammar) | `Resources/Fonts/SourceSans3VF-*.ttf`, `Core/Design/Typography.swift` (`TypeRole`, `sectionLabel()`) | same family and ramp |
| `apps/web/src/styles/components.css`, `features.css` (buttons, controls, rows, banners, modal, tab bar) | `Core/Design/ButtonStyles.swift`, `ControlStyles.swift`, `RowStyles.swift`, `Components.swift`, `Sheets.swift`, `App/TabBarView.swift` | same geometry and colours |
| `apps/web/src/components/ThemeControls.tsx` | `Features/Settings/SettingsViews.swift` (`AppearanceView`) | every option |
| `packages/shared/src/portal/contract.ts`, `packages/portal-connector/src/api.ts` (server-side policy) | `Portal/PortalWire.swift`, `Portal/PortalAPI.swift`, `Portal/PortalSessionCoordinator.swift`, `Portal/AccessRules.swift`; `HOneyNative/Features/Access/*` | Access: direct-to-school, consumed-permit fix |
| `Modal.tsx` | `Core/Design/Sheets.swift` (`WebSheet`, `ConfirmSheet`) | Web content in a native sheet |
| `PullToRefresh.tsx`, `PullToHistory.tsx`, service worker, viewport code | — | not ported (port spec §2.3) |
| `apps/web/src/pages/NoticesPage.tsx`, `components/NoticeSheet.tsx`, `lib/noticesRead.ts` | `Features/Notices/NoticesView.swift` (`NoticesView`, `NoticeSheet`, `NoticeDocView`, `NoticeBody`); `Storage/LocalStores.swift` (`Preferences.readNotices`) | preserve; the two sheet heights are the native detents |
| `apps/web/src/pages/settings/SchoolRecordsPages.tsx`, `components/SchoolFeedbackSheet.tsx`, `lib/useFeatures.ts` | `Features/Settings/SchoolRecordsViews.swift`, `Features/Settings/SchoolFeedbackSheet.swift`; `API/DTO/SchoolWire.swift`; `API/APIClient.swift` (`school*`, `features`, `notices`) | preserve; the pay page is `SFSafariViewController` |
| `packages/shared/src/api/contract.ts` (2026-09-03/04 additions) | `API/DTO/SchoolWire.swift` | mandatory parity |
