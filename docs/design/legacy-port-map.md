# Legacy HOney — design port reference

> **HISTORICAL (2026-09-01, product-v2 freeze).** This document records an experiment round or a
> superseded decision. It is evidence, not binding direction. The source-of-truth hierarchy is
> defined in `docs/status/current.md`; current design direction lives in
> `docs/design/web-lab.md` / `docs/design/ios-lab.md` under `docs/design/shared-product-design-invariants.md`.

The V1 **iOS** UI reproduces the legacy design (Gary, 2026-09-01) — this file is the
token/grammar source of truth for the SwiftUI port. **Scope change (2026-09-01, late): the Web
app no longer mirrors this** — it has its own experimental design system, documented in
[`web-style.md`](web-style.md). Legacy source lives at `reference/legacy-ios/`
(`DesignSystem/AppTheme.swift` is the original "edit first" file).

## Colors (sRGB → hex)
- navy `#12305C` — the ONLY text color; hierarchy is opacity, not hue
- ocean `#3BB0D1` — single accent (one primary button/screen, eyebrows, chips@10%, tints)
- sky `#B8E0FF` · mist `#EDF7FF` · line `#CCE0F2` (every 1px border) · page `#FFFFFF`
- success `#2B8F4D` · warning `#DB6B24` · error `#DB2E38`
- App background: fixed diagonal gradient `#F2FAFF → #D6EDFF`, never hidden; cards are translucent white over it.
- Login background: `#FFFFFF → mist@0.62` (top→bottom).
- Navy text opacity ladder (the whole hierarchy): 1.0 title · 0.82 secondary emphasis · 0.62/0.58 subtitle · 0.48/0.42 caption · 0.34/0.28 chevrons.
- White translucency ladder for surfaces: 0.98 overlay · 0.92 canvas · 0.88 default card (`AppCard`) · 0.86 headers · 0.72 nested · fully white = "on top" (LessonCard, login field).
- Dark exceptions (deliberate): music card `#1A2E26 → navy@0.95`; "candle" evening banner `mist_dark #17171C`.

## Type (SF system, no custom fonts) — design is the personality lever
- Rounded (`.rounded`): ALL headings/titles (largeTitle≈title/bold, sectionTitle 20/bold, cardTitle=headline/bold, scheduleHeader 23/bold).
- Default (`.default`): all body/caption.
- Serif (`.serif`, New York): WORDMARK ONLY — login "HOney" 38/semibold/navy and the "HO" mark 24/semibold/white. Serif appears nowhere else.

## Spacing / radii / elevation
- pageHorizontal 18 (login 28); section gap 14; sibling gap 10; row gap 8. Card padding 16/14/12/10.
- Radius: 8 default (cards/buttons/fields), 12 heroes (greeting, next-exam, music, alerts), Capsule for all chips/pills/status.
- Flat: 1px `line` stroke, essentially NO shadow (3 shadows in whole app). Elevation is drawn, not lit.
- Only one real material (`.ultraThinMaterial`): the gate picker. Everything else fakes translucency with white@opacity over the gradient. Web mirror: use `rgba(255,255,255,α)` fills, NOT backdrop-filter (except gate picker).
- Motion: legacy ships `enableAnimations=false` → near motionless, immediate, paper-like. Keep transition shapes, expect ~0 duration.
- Color scheme LOCKED to `.light` (no dark mode).

## Component grammar (port `AppTheme.swift` + `AppComponents.swift` verbatim)
- `AppCard(padding:16, bg:white@0.88, border:line, radius:8)` — the atom.
- `AppSectionHeader` (20/bold/rounded navy), `AppLoadingState` (ProgressView.tint(ocean)+text@0.62), `AppEmptyState` (Label@0.58), `AppBanner(.error/.success)`, `AppListRow`.
- Buttons (inline, no shared style, `.buttonStyle(.plain)`): Primary = subheadlineSemibold, maxWidth, vpad 11–12, ocean fill radius 8, white text (disabled → navy@0.16). Secondary = mist@0.88. Ghost = ocean@0.14, ocean text. Pill CTA = captionBold white on ocean Capsule.
- Chips: caption2Bold ocean on ocean@0.10 capsule; tags caption2Medium navy@0.54 on mist@0.72.
- Field styles: `loginFieldStyle` (48pt, opaque white, black@0.12 hairline — login deliberately off the navy system), `formFieldStyle` (mist fill, line stroke).

## Nav shell & screens
- Shell: `ContentView` ZStack(gradient + Login | Home). Home = flat `TabView` (.tint ocean), each tab its own NavigationStack. Tabs: Home/Schedule/Exams/Access/Feedback/Music/[Resources]/Prefs/[Admin]/[Demos].
- Screen focal objects: Home = greeting header card (accent@0.18→mist gradient, radius 12) + Current/Next class cards (Current class has an ocean@0.67 left-to-right progress wash — memorable). Timetable Day view = the signature: horizontal pastel period bands (blue alternating, green Lunch/Dinner break with leaf glyph), 38pt sky exam strip on top, "P3 · Free" ghost labels, red `#FF3847` now-line, 09:00–20:00 canvas. Exams = NextExamCard hero + decorative 5-bar chart empty state. Access = fixed bottom action dock + Apply/All permits cards + gate picker (the one material). Settings = 10 identical stacked preferenceCards.
- Legacy has NO Experiences feature: build it in this grammar using `DemoScreenShell` + `AppCard` + ghost/primary buttons + FeedbackThreadCard patterns as scaffolding.

## Voice
Quiet, second-person, lowercase-friendly, occasionally bilingual and self-deprecating; server-provided greetings with `"Hi, {name}"` fallback. Never exclamatory, gamified, or emoji.

## Portability
- Port verbatim: `AppTheme.swift`, `AppComponents.swift`, `LoginScreen` + the legacy login wordmark view (rename the ported symbol to `HOneyLoginMark`), the view-modifier block, and all pure presentational cards/timeline views (they take plain `let` inputs).
- Rewrite data layer only (keep visuals): screens bound to `PortalStore`/`CloudServicing`/`MusicPlayerStore` — swap to the new HOney service layer.
- Not web-portable (UIKit): SafariView, QuickLook preview, Keychain, security-scoped bookmarks — Web uses its own equivalents.
