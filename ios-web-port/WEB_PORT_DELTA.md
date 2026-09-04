# Web → native port delta

Locked Web source: `integration/product-v2 @ 9cbedf68a0ecc1b12017942c1782099800024eed`
(fidelity spec v2 §0.2 moved it from 2d1b562). **Aligned to `integration/product-v2 @ cebb399`
on 2026-09-04** on top of Gary's `ios-web-port-mac` (native refresh, Access, tab icons kept). Every later Web change is
classified here before it may touch the native app; nothing is copied
because it is newer. **Visual policy lives in `WEB_VISUAL_FIDELITY.md`**
(default class `REQUIRED`); this file keeps the behavioural classification
and the history.

| Web commit | What changed | Class | Native action |
|---|---|---|---|
| `5c76376` refine(web): drop Settings helper copy; keep three labels English in zh; OASIS mark on the portal row | Settings › Appearance loses its helper sentences; "Written by students, for students." / "Your classes" / "Around school" stay English under 中文; the Portal row shows the OASIS mark | `REQUIRED` | Adopted: no helper copy on Appearance; L10n keeps the three strings English; PortalRow shows the OASIS mark |
| `9cbedf6` feat(web): accent schemes as their own appearance axis; Cobalt pairs blue with the teal | Background and Accent are independent axes; seven schemes with tint, on-accent and night lift; Cobalt's `--accent-2` companion | `REQUIRED` | Adopted in full: `HOneyAccent`, `ThemePalette.resolve`, Settings › Appearance › Accent, `theme.accent2` on the Home wash |
| `d6ee10b`…`782e566` `41ef5b7` `19be79a` `5edc5c9` notices: the school's own notices on Home and their own page; read in a sheet with two heights | `GET /api/notices`; Home "From school" zone (≤2 unread, newest otherwise); /notices list + Mark all read (green pill); a notice opens in a sheet (reading height → full), "Open as a page"; file links resolve against the portal origin; read/unread is device-local | `REQUIRED` | Adopted: `SchoolWire.swift`, `APIClient.notices`, `Preferences.readNotices/markNoticesRead`, `Features/Notices/NoticesView.swift` (list, `NoticeSheet` with `.fraction(0.58)`/`.large` detents, `NoticeDocView`), Home `noticesRegion`, routes `.notices`/`.notice(id)`, `honey://notices[/id]` |
| `782e566` `5edc5c9` `fa2283d` `3c32548` posts: resonance instead of a thumb, no thumbs-down, "Write your own", your own words marked, no self-resonance, options as a sheet, the footer one 32 pt line | `ResonanceIcon`; `myPosts` device set → "Yours ·" in the provenance line and Home captions; own post shows a static count; second action opens the composer on the same subject; ··· opens `PostOptionsSheet` (options → report categories → thanks) | `REQUIRED` | Adopted: `ExperiencePostRow` rewritten (`ResonanceGlyph` Canvas, `mine:`, `writeOwn:`, `PostOptionsSheet`), `Preferences.isMyPost/rememberMyPosts` (filled at publish), `FeedViewModel.isMine`; scope switch says "Related to you" |
| `68811a2` `62befc8` `200cbbd` `5f900ea` `48627fa` `f07425c` compose: About header outside the card, the card tinted with a lighter lift; History picks directly; the school's own feedback channel from the composer and from an out-of-scope check | `.compose-about` + `.compose-target`; "Doesn't belong here? · Send it to the school"; `SchoolFeedbackSheet` ("Sent from your school account — not anonymous."); out_of_scope adds "Send this to the school instead" | `REQUIRED` | Adopted: `ComposerView.aboutBlock/toSchoolLine`, `ComposerNotice.suggestSchoolReport`, `Features/Settings/SchoolFeedbackSheet.swift`; HistoryView rows lead to the composer with a chevron (no Select pill; the lesson sheet on a long press) |
| `fa02f75` `d48ae7a` `fb70c3e` timetable: sync speaks while it runs in one line; History in the top-right corner beside the pill; no experience before a lesson starts | `.sync-line` (busy → "Syncing with the school…", result → "Synced · N lessons" that clears itself); `.daynav__history` with the gesture hint; lesson dialog shows a note instead of Share before `startsAt`; Subject/Class rows | `REQUIRED` | Adopted: `TimetableRootView.syncLine` + corner link, `LessonDetailSheet` not-started note + Subject/Class details |
| `7504ff5` `026cfd3` week fills the screen | period rows share the region's height, 56–104 px, measured on the device | `REQUIRED` | Adopted: `WeekTimetableView.fit(_:)` from the GeometryReader height |
| `2ba12a2` `2c5ef8a` `352965d` `d88f0c6` `22c7bc9` `3993cba` `2c6de09` `5f900ea` Settings › At school: campus card (balance, spending, top-ups, top up → the school's Alipay page), weekend stay (open days as dated chips, apply, withdraw), school record, lesson feedback (the school's form); Dash switches `lessonFeedback` (off) / `schoolFeedback` (on) | `/api/school/*`, `/api/features`; every action the school offers is offered too; one line of copy at most ("Read live.", "Opens an Alipay link.") | `REQUIRED` | Adopted: `SchoolWire.swift` DTOs + `APIClient.school*`/`features`, `Features/Settings/SchoolRecordsViews.swift` (`CampusCardView` + `TopUpSheet` → `SFSafariViewController` for a pay URL / posted form in a WKWebView, `WeekendStayView`, `SchoolRecordView`, `LessonFeedbackView` + `FeedbackSheet`, `ChoiceOption`), Settings root "At school" group gated by `FeatureFlags` |
| `9b11e2e` `3c49272` `d6020a8` `d7cc290` `195d205` `fb1c986` `4065d22` home: the idle lesson card washes out from its top-left corner; the share prompt wears the palette's green, faint, fading left→right, with the card shadow; the portal entry is a small underlined link at the right ("Signed in" in the installed app); "Related to you" | tokens `--shadow-card`, `--shadow-field`; `.composer-prompt` gradient; `.portal-link` | `REQUIRED` | Adopted: `HomeView` (`HeroCard.ground` as gradients — also fixes the fill lagging the card's bounce on a pull, Gary 2026-09-04; `ComposerPromptRow`; `PortalLink`), `ThemePalette.shadowCard/shadowField/warn`, `View.fieldShadow/cardShadow` |
| `4b97b80` `b4c89dd` `59cb4ec` `d37afaa` `1c1ed9b` warnings are orange (`--warn`), never the accent; an unfilled pill carries a small edge shadow, a disabled one is flat, `.btn--pill-ok`; the Infinite-colour wordmark has its own night artwork | | `REQUIRED` | Adopted: `InlineStatusBanner.warning` → `theme.warn`, `WebButtonStyle` field shadow + `.pillOk`, `WordmarkView` picks `Wordmark`/`WordmarkNight` (original rendering, aspect from the asset) |
| `710c3f5` `52af750` `9f60abd` `2430e90` `5428b77` `bfeae87`… Dash (picker, System group, Web Access panel) | admin console | `NOT PORTED` | Dash stays a Web screen; the native Settings › Admin row opens it |
| `c9a68de` `2271847`…`8f28546` `026cfd3` `1c8e1cc` Web Access (isolated Access Service, tab, progress/ETA, permits fold) | | `INTENTIONAL DIFFERENCE` | Native Access talks to the school directly (see below); Gary's own refinements on `ios-web-port-mac` (2026-09-04) are the native Access |
| `346eeee` `f484ead` `5ae0e1a` `a2091e6` `30a566a` portal deep landing (attempted, reverted) | | `NOT APPLICABLE` | The native app holds the portal in its own WKWebView surface; the hand-over is unchanged |
| `cebb399` credential-image classifier route | a Community route for the sanitation prototype | `NOT APPLICABLE` | Lives in the standalone `SanitationLab` (branch `lab/credential-image-sanitation`) |

## Intentional native differences (spec-approved)

- Access is a fifth tab (Gary, 2026-09-02: 「access要有」). The Web has no Access; the native
  screen talks to the school portal directly with the Keychain school login, in the Web's
  token and component grammar.
- Settings stays a primary tab (fidelity spec v2 §0.1).
- Pull-to-refresh is `.refreshable`; school sync is the explicit **Sync with school** action
  (Timetable overflow, Settings › School connection) — the Web's deep-pull-and-hold stage is not
  ported (port spec v1 §24).
- Composer outcomes: Shared / Kept private replace the screen as on the Web; the nudge and the
  cooling panel rise as sheets in the `.nudge` surface; publish uses the dedicated identity-free client.
- The first-share disclosure sheet is a native addition (port spec v1 §22.3).

## Review 11d42e3 (2026-09-02) — what changed on the branch afterwards

Everything in the review was applied except one item Gary struck: Settings
stays a fifth tab (review §3.6 / §6.7 not applied; the Settings screens
themselves were kept as reviewed). Applied, in order:

1. account scope — every account-scoped store bound before the signed-in
   shell, unbound before Login; per-account drafts, preferences, journal;
   repository generations cancel late writes;
2. portal account binding — vault namespaced by account, school identity
   verified against the HOney display name and the first student id seen;
   WebView page/history/website data reset on account change;
3. one reauthentication path — Portal entry and sync renew through the
   device coordinator and hand the token to HOney; no routine HOney login;
4. composer truth — verified drafts, journal before clear, cooldown/kept
   copy that matches what happened, ModerationDecision adapter;
5. timetable keyed snapshots — never another day's lessons under a new
   header; single load path; landing recorded after the scroll;
6. Access freshness authority — stale permits visible, never actionable;
   authority withdrawn after every open until a fresh read;
7. navigation/product — Home previews open the Stream at that post; the
   composer belongs to the Experiences tab; preview count from the
   container; Home preview errors shown as errors;
8. feed/portal hardening — top-visible anchor via scrollPosition, FeedStore
   task identity + empty-feed restore, probe only on the Stream, haptics on
   deliberate taps, Latin-only letter groups, cancellation ≠ network error,
   timeouts named, strict concurrency `complete`, per-configuration servers;
9. signed runtime proof — `RELEASE_CHECKLIST.md`; CI publishes warning
   counts with the errors;
10. (found by that warning count on `0fb6a8e`) the portal's navigation-policy
    delegate was spelled in a form WebKit never bound, so the HTTPS-only
    allowlist was inert; the async form is bound and `responds(to:)` is
    tested, so the unsigned CI lane catches a regression.

## Fidelity pass v2 (2026-09-02)

The visual direction of the review (uppercase section labels, System /
Light / Dark, one fixed accent, system typography, `.insetGrouped`,
`.borderedProminent`) was superseded by the fidelity spec: the Web's font,
casing, four Backgrounds, seven Accent schemes, four Text sizes, component
weight and page grammar were reproduced. See `WEB_VISUAL_FIDELITY.md`.

Per-post control keys (review §5.2) stay behind `OwnershipKeyStoring`
(versioned export); a master-secret model waits for a server protocol.

## Anonymous Control v2 + canonical school data (2026-09-03)

- Wire: `Lesson` carries `subjectId/classSectionId/classSectionName`; `courseName` is the canonical
  course ("AL ECON U4") or nil when unresolved; every title is `lesson.title` (course ?? subject) and
  Week cells use `DisplayNames.compactLessonTitle` — `parseCourseName/entityTitle/entityMeta` deleted.
- Experiences read from Community (`CommunityAPIClient`, identity-free transport, `/community/v2/*`);
  names are joined on the device (`NameMaps.name(_:)`) because the wire carries ids only; the
  viewer's own reactions are remembered in `Preferences` (`ReactionMemory`).
- Publication: `ComposerController` → `PublishClient.preparePost` (post controls + blind eligibility
  + signed envelope) → check → publish. No per-post key to store: `.publishedKeyUnsaved` and the
  recovery journal are gone; a server vault not restored on this iPhone yields
  `.postControlsRestoreNeeded` (draft kept).
- Settings › Post controls (`PostControlsViews.swift`): create · recovery words (show, 2-word check,
  restore) · another device (code, poll, deliver) · replace root · remove from this iPhone.
  Passkey wrappers made on the Web are listed; adding one from iOS is not offered yet.
- Delete account = delete public content by proof first (`AccountDeletion`), then the account;
  a locked vault or an unrevoked post stops the whole thing and says why.
- `VisualFixtureTests` answer `/community/v2/*`, `/api/community/issuer|scope` from the new
  fixtures; `/api/vault` answers 404 (post controls are created locally at the first share).
