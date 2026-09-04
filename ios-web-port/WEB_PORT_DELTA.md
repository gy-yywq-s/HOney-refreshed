# Web → native port delta

Locked Web source: `integration/product-v2 @ 9cbedf68a0ecc1b12017942c1782099800024eed`
(fidelity spec v2 §0.2 moved it from 2d1b562). Every later Web change is
classified here before it may touch the native app; nothing is copied
because it is newer. **Visual policy lives in `WEB_VISUAL_FIDELITY.md`**
(default class `REQUIRED`); this file keeps the behavioural classification
and the history.

| Web commit | What changed | Class | Native action |
|---|---|---|---|
| `5c76376` refine(web): drop Settings helper copy; keep three labels English in zh; OASIS mark on the portal row | Settings › Appearance loses its helper sentences; "Written by students, for students." / "Your classes" / "Around school" stay English under 中文; the Portal row shows the OASIS mark | `REQUIRED` | Adopted: no helper copy on Appearance; L10n keeps the three strings English; PortalRow shows the OASIS mark |
| `9cbedf6` feat(web): accent schemes as their own appearance axis; Cobalt pairs blue with the teal | Background and Accent are independent axes; seven schemes with tint, on-accent and night lift; Cobalt's `--accent-2` companion | `REQUIRED` | Adopted in full: `HOneyAccent`, `ThemePalette.resolve`, Settings › Appearance › Accent, `theme.accent2` on the Home wash |

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
