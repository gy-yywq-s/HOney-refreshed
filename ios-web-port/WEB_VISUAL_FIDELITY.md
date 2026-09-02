# Web visual fidelity ledger

Governing rule (fidelity spec v2 §0.3): **reproduce the current Web first,
observe the actual iPhone result second, improve natively third.** Every
current Web visual or product behaviour defaults to `REQUIRED`; `WEB_ONLY`
is permitted only for intrinsically browser-specific behaviour.

```yaml
web_visual_source: 9cbedf68a0ecc1b12017942c1782099800024eed   # integration/product-v2
ios_visual_target: ios-web-port (this branch; the snapshot commit is named in the evidence README)
```

Parity classes: `REQUIRED` (not yet matched), `MATCHED`, `NATIVE_EQUIVALENT`
(same visual result through a platform primitive), `APPROVED_DELTA` (owner
approved), `MISSING`, `REGRESSION`.

Evidence: the macOS CI lane renders the fixtures at 390 × 844 through the
real shell (`HOneyNativeTests/VisualFixtureTests.swift`) and publishes the
PNGs on the `ios-web-port-evidence` branch (`snapshots/<name>.png` below
means `https://raw.githubusercontent.com/gy-yywq-s/HOney-refreshed/ios-web-port-evidence/<name>.png`).
Web references come from the audit harness at the same viewport. No screen
is declared visually ported from code inspection alone; every row below
stays `Owner decision: pending` until Gary approves the pair.

## Foundation

| Web source | Native destination | Class | Current difference | Platform constraint | Evidence | Owner decision |
|---|---|---|---|---|---|---|
| tokens.css: four Backgrounds (Stone/White/Mist/Night) | `HOneyCore/Domain/Appearance.swift`, `Core/Design/Theme.swift`, Settings › Appearance | MATCHED | none — same names, same hex, Night forces dark chrome | — | appearance-{stone,white,mist,night}.png; ThemeMappingTests parses tokens.css | pending |
| tokens.css: seven Accent schemes incl. Cobalt's `--accent-2` companion | same; `theme.accent` / `theme.accent2` / `theme.accentTint` / `theme.onAccent` | MATCHED | none — all 28 background × accent palettes checked against the stylesheet | — | home-white-cobalt-default-now.png (blue actions, teal wash) | pending |
| tokens.css `--text-scale` 0.92/1/1.1/1.22 | `HOneyTextSize`, `HTypeRamp`, Settings › Appearance › Text size | MATCHED | the HOney scale multiplies the base size, then Dynamic Type applies on top | — | home-mist-moss-large-next.png, home-stone-clay-larger-none.png | pending |
| fonts.css: Source Sans 3 Variable for UI/display/reading, CJK to the system face | `Resources/Fonts/SourceSans3VF-*.ttf` (OFL), `Core/Design/Typography.swift` (`wght` axis instances, UIFontMetrics) | MATCHED | none for Latin; CJK falls to PingFang as on iOS Safari | system chrome text (navigation bar) is set through the appearance proxy, also Source Sans | TypographyTests; every snapshot | pending |
| type ramp 12/13/15/16/17/20/22/30, greeting 24/500, subject 25/600, page title 30/650 | `TypeRole` | MATCHED | sizes taken at the 390 pt clamp values | — | snapshots | pending |
| foundations.css `.eyebrow`/`.overline`: sentence case, 13/600, 0.01em, muted | `sectionLabel()`; `scripts/check-text-case.sh` + TextCaseAuditTests | MATCHED | no uppercase transform remains (one allowance: Explore letter landmarks are content) | — | explore-stone-harbour.png | pending |
| spacing 4/8/12/16/20/24/32/44, radii 12/14/16/18/20, page inset 20 | `Tokens.swift` | MATCHED | — | — | — | pending |
| `.theme-anim` 400 ms crossfade, none under reduced motion | `ThemeTransition` | NATIVE_EQUIVALENT | SwiftUI animates the colour change; UIKit chrome switches at once | UINavigationBar appearance proxies do not crossfade | device check (RELEASE_CHECKLIST) | pending |

## Components

| Web source | Native destination | Class | Current difference | Platform constraint | Evidence | Owner decision |
|---|---|---|---|---|---|---|
| `.btn`, `--primary` (ink fill), `--ghost`, `--danger`, `--danger-outline`, `--small`, `--block` | `ButtonStyles.swift` `WebButtonStyle` | MATCHED | pressed = scale 0.98 as on the Web; no `.borderedProminent` anywhere | — | compose-picker, mine, connection snapshots | pending |
| `.iconbtn`, `.iconbtn--primary` 44 × 44 | `WebIconButtonStyle` | MATCHED | glyphs are SF Symbols (magnifyingglass, bookmark, pencil.line) drawn at 20 pt regular, in place of the Web's 1.8-stroke line glyphs | icon assets: SF Symbols per spec §3.6 | experiences-*.png | pending |
| `.scope-switch` | `ScopeSwitch` | MATCHED | — | — | experiences-*.png | pending |
| `.chip-tab` | `ChipTab` + `FlowLayout` | MATCHED | — | — | explore-*.png, appearance-*.png | pending |
| `.daynav__modes` | `ModePill` | MATCHED | — | — | timetable-day-*.png | pending |
| `.react-btn` in `.post__actions`: no border, accent tint + accent when on | `ReactionPill(.streamFooter)` | MATCHED | **spec §4.4 asks for an ink-filled on-state; the current Web stream footer overrides `.react-btn--on` to accent tint (features.css `.post__actions .react-btn--on`). The Web wins; the standalone variant is ink-filled.** | — | experiences-*.png | pending — flagged for Gary |
| `.input`, `.search-box`, `.field__label` | `WebFieldStyle`, `SearchField`, `FieldLabel` | MATCHED | — | — | explore, history, login snapshots | pending |
| `.rowlist`, `.row`, `.entity-row`, `.disclosure` | `RowStyles.swift` | MATCHED | open rows, rule above each group after the first, hairlines between entity rows | — | settings-*.png, explore-*.png | pending |
| `.banner*` | `InlineStatusBanner` | MATCHED | the Web's rise-in entrance is not animated | — | timetable sync banners | pending |
| `.modal` (sheet ≤640) + `ConfirmDialog` | `WebSheet`, `ConfirmSheet` | NATIVE_EQUIVALENT | native detents/drag; content order, copy and button hierarchy are the Web's (Cancel ghost + confirm in a row) | sheet mechanics are the approved adaptation (spec §4.8) | device check | pending |
| `.switch` 46 × 28 | `WebSwitchStyle` | MATCHED | — | — | settings-*.png | pending |
| `.option-grid` cards, `.swatch` | `OptionCard` | MATCHED | Background 2 columns (≤640), Accent 3 | — | appearance-*.png | pending |

## Shell

| Web source | Native destination | Class | Current difference | Platform constraint | Evidence | Owner decision |
|---|---|---|---|---|---|---|
| `.mobile-nav`: 12 pt inset, 10 pt up, 54 tall, 22 radius, 4 inner, accent-tint pill, labels, blur | `App/TabBarView.swift` (path B over a native TabView) | MATCHED | five slots (Access added); pill slides on the Web curve | — | every snapshot | pending |
| `.pagebar` "‹ Parent" | system navigation bar, back label = parent title, no inline title (`webScreen`) | NATIVE_EQUIVALENT | the system back chevron/label replace the Web's 20 px glyph + 600 label | interactive back gesture | pushed-screen snapshots | pending |
| desktop rail | — | WEB_ONLY | ≥961 px only | phones never show it | — | n/a |
| pull-to-refresh two-stage, pull-up for History | `.refreshable`; History in the Timetable overflow | APPROVED_DELTA (port spec v1 §24) | — | — | — | approved (Gary, port spec) |

## Screens

| Web source | Native destination | Class | Current difference | Platform constraint | Evidence | Owner decision |
|---|---|---|---|---|---|---|
| HomePage.tsx: brand bar, greeting, Now/Next hero, From your classes, composer prompt, Portal row | `Features/Home/HomeView.swift` | MATCHED | 1–2 previews (1 on ≤700 pt); progress wash = `accent2` at 22 %; **no "See all" — the Web at 9cbedf6 has none (spec §6.5 mentions one)** | — | home-*.png (5) | pending |
| FeedPage.tsx + ExperiencePost.tsx | `Feed/ExperiencesFeedView.swift`, `Feed/ExperiencePostRow.swift` | MATCHED | context names inherit ink-2 (features.css `.post__context a { color: inherit }`), **not the accent spec §7.5 describes**; the ··· opens a native menu; the report sheet keeps the Web copy | — | experiences-*.png | pending — flagged |
| ExplorePage.tsx | `Explore/ExploreView.swift` | MATCHED | the frame (field + chips) pins while results scroll | — | explore-*.png | pending |
| EntityPage.tsx | `Entity/EntityExperiencesView.swift` | MATCHED | — | — | (entity pages need a fixture id; device check) | pending |
| ComposePage.tsx picker + editor + outcomes + nudge/cooldown | `Compose/TargetPickerView.swift`, `ComposerView.swift` | MATCHED | outcomes replace the screen as on the Web; nudge/cooling rise as sheets in the `.nudge` surface; the first-share disclosure is a native addition (port spec v1 §22.3) | — | compose-picker-*.png | pending |
| MinePage.tsx | `Mine/NotesAndPostsView.swift` | MATCHED | — | — | mine-*.png | pending |
| TimetablePage.tsx daynav + DayTimeline + LessonDetail | `Timetable/TimetableRootView.swift`, `Day/DayTimelineView.swift`, `LessonDetail/LessonDetailSheet.swift` | MATCHED | History / Sync with school in one 44 pt outlined ··· control (phone Web uses gestures); the date picker is the platform calendar in a Web sheet | — | timetable-day-*.png | pending |
| WeekView.tsx | `Week/WeekTimetableView.swift` | MATCHED | — | — | timetable-week-*.png | pending |
| HistoryPage.tsx | `History/HistoryView.swift` | MATCHED | the two selects are native menus in the input frame | — | history-*.png | pending |
| SettingsPage.tsx root/account/connection/appearance | `Settings/SettingsViews.swift` | MATCHED | Settings stays the fifth tab; About shows the build + server host (the Web's self-reload line does not apply); Language offers English / 中文 | — | settings-*.png, appearance-*.png, connection-*.png | pending |
| SettingsPage.tsx privacy | `Privacy/HowAnonymityWorksView.swift` | MATCHED | storage claims say Keychain / protected storage | — | privacy-*.png | pending |
| WhyPage.tsx | `Why/WhyView.swift` | MATCHED | — | — | why-*.png | pending |
| LoginPage.tsx + SchoolLoginForm.tsx | `Login/LoginView.swift`, `SchoolLoginFields` | MATCHED | the footnote names the iPhone's Keychain and the Timetable menu | — | login-*.png | pending |
| ReconnectDialog.tsx | `SchoolLoginSheet` | MATCHED | — | — | device check | pending |
| — (no Web page) | `Access/AccessView.swift` | NATIVE_EQUIVALENT | built only from the token/component grammar above | Access is the one native-only surface | access-*.png | pending |

## First parity round — `557a6f9` (2026-09-02)

Web references: `design-audit/fixture-server.js` + `fixture-shots.js` (the built
Web at 9cbedf6 answering `/api/*` from the same contract fixtures, Playwright at
390 × 844 @2x, Asia/Shanghai, standalone insets). Native: the evidence branch at
`557a6f9`. Compared side by side: home (5 fixtures), experiences, explore,
compose picker, mine, timetable day/week, history, settings, appearance (4
backgrounds), login, night/cobalt set.

What the pairs showed and what changed before this commit:

- Home hero on White/Cobalt: blue "45 min left" over the teal wash on both —
  `accent` and `accent2` are distinct (§6.7 mandatory case).
- The stream's context line broke one name per line on the iPhone; it now
  flows and wraps like the Web's inline run (`FlowLayout`).
- The Day canvas clipped its first hour label; 8 pt of air above the canvas.
- Pushed screens repeated the page title in the navigation bar; the bar now
  carries only "‹ Parent" like `.pagebar`, the title lives in content.
- Harness: whole-millisecond fixture times (a fractional `startsAt` failed to
  decode and showed the error banner), one shell per environment.

Remaining visible differences, all listed above as platform adaptations: the
system back chevron/label instead of the Web's glyph, the ··· overflow on the
Timetable frame (History · Sync with school), the native menu behind a post's
···, and the status-bar/home-indicator zones. Owner review of the pairs is the
next step; every row stays `pending` until then.

## Discrepancies between the spec and the current Web (resolved to the Web)

1. Stream reactions' on-state is accent tint, not ink (features.css, line
   `.post__actions .react-btn--on`).
2. Post context names inherit the line's ink-2 rather than the accent.
3. Home has no "See all" beside "From your classes".
4. `ConfirmDialog` lays its actions in a row, Cancel first.

## Stage B candidates (after the baseline is approved, one A/B at a time)

System tab bar vs the Web bar; `.searchable` on Explore; a system
segmented control for the scope switch; the system large title on roots.
