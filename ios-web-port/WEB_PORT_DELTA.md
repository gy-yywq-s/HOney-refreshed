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
