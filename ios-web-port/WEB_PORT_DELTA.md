# Web → native port delta

Locked Web snapshot: `integration/product-v2 @ 2d1b56297a5b8b4bd613d022b05cafdb709cd67e`
(port spec §1.1). Every later Web change is classified here before it may
touch the native app (spec §1.2). Nothing is copied because it is newer.

| Web commit | What changed | Class | Native action |
|---|---|---|---|
| `5c76376` refine(web): drop Settings helper copy; keep three labels English in zh; OASIS mark on the portal row | Settings › Appearance loses its helper sentences; "Written by students, for students." / "Your classes" / "Around school" stay English under 中文; the Portal row shows the OASIS mark | `COPY_SYNC_OPTIONAL` (helper copy — native Appearance never had it), `BEHAVIOR_SYNC_REQUIRED` (English labels — Gary's decision applies to both clients), `COPY_SYNC_OPTIONAL` (OASIS mark) | Adopted: L10n keeps the three strings English; PortalRow shows the OASIS mark |
| `9cbedf6` feat(web): accent schemes as their own appearance axis; Cobalt pairs blue with the teal | Web gains a selectable accent-scheme axis (Harbour, Cobalt, Moss, Clay, Plum, Iris, Amber) | `WEB_ONLY` | Not ported: spec §7.2 / §20.5 — one canonical accent (Harbour) + system dark; a native scheme picker is a `DEFERRED_PRODUCT_DECISION` |

## Intentional native differences (spec-approved)

- Access is a fifth tab (Gary, 2026-09-02: 「access要有」). The Web has no Access; the native
  screen talks to the school portal directly with the Keychain school login. Spec §32's
  "no Access" is overridden by the owner's instruction.
- Pull-to-refresh is `.refreshable`; school sync is the explicit **Sync with school** action
  (Timetable menu, Settings › School connection) — the Web's deep-pull-and-hold stage is not
  ported (spec §24).
- Appearance: System / Light / Dark + language; no surface or text-size selector (spec §20.5).
- Composer outcomes are native sheets; publish uses the dedicated identity-free client
  (spec §15–16).

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
   composer belongs to the Experiences tab; sentence-case section labels;
   preview count from the container; Home preview errors shown as errors;
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

Per-post control keys (review §5.2) stay behind `OwnershipKeyStoring`
(versioned export); a master-secret model waits for a server protocol.
