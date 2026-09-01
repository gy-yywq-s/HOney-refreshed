# Web design system — the style lab (2026-09-01)

The web app is a deliberately **independent, experimental design surface** (Gary, 2026-09-01):
iOS carries the legacy design; web explores its own language and the two are expected to
diverge. Structural grammar follows an editorial reference chosen by Gary; fonts and palette
were selected for this tone (recorded decisions — not derivable, do not "fix" them back).

## Type
- **Space Grotesk** (variable, self-hosted via `@fontsource-variable`) — UI + display. Display
  sizes use tight negative tracking (`clamp(42–82px)` section heads, hero larger).
- **Fraunces** (variable, optical sizing, + italic) — the wordmark, hero italic accents, and
  Experiences reading bodies (~19px, generous leading). The only serif.
- User-selectable `data-ui-font`: `grotesk` (default) · `neutral` (system sans) · `editorial`
  (Fraunces-flavored headings).

## Color — cool system (no warm tones, by directive)
- ink `#15181a` · muted `#646b70` · hairline = ink @ ~.16 alpha (every 1px divider)
- accent (interactive/focus): petrol teal `#136c66` (night `#7fd4c8`)
- highlight (primary CTA pill, marks — always ink text): glacier `#9fe8dc`
- danger `#b53844` (night `#f2919a`) · success `#2b7355` — all AA-measured per surface
- **Surfaces, user-selectable** (`data-surface`, persisted, applied pre-paint): `stone`
  `#edf0f1` (default; slow-drifting dot-grid texture) · `white` · `mist` `#e7eeec` ·
  `night` `#14171a` (true dark). Ink fills (buttons, active nav) are the primary grammar;
  teal/glacier are temperature, used sparingly.

## Shell & grammar
Desktop: fixed 216px rail (Fraunces wordmark, numbered nav, blur, hairline) + fixed 78px
blurred topbar (route context + appearance trigger). Mobile ≤960px: floating pill nav
(4 slots, blur, safe-area). Pills (radius 99) for buttons/filters/chips; hairline-topped list
rows; padded cards (radius 10–20) with hover lift; dialogs as shells with blurred backdrop —
bottom sheets on mobile. Editorial section heads with uppercase eyebrows.

## Motion — "the area is alive"
All 250–500ms, `cubic-bezier(.16,1,.3,1)`, fully collapsed under `prefers-reduced-motion`:
route settle · staggered + scroll-armed entrances · sliding active-nav pills · hover lift +
pressed scale · slide-up sheets · animated progress wash · count-up numbers + live countdown
ticks · ambient 90s dot-grid drift + 64s hero light sweep · pointer-following card glow ·
~400ms whole-surface theme crossfade. Performance rule: transform/opacity only; one passive
scroll listener; verified ~2 vsync frames under 4× CPU throttle.

## Theme mechanism
`localStorage` `honey.theme.surface` / `honey.theme.uiFont` → `data-*` attributes set by an
inline head script before first paint (no flash), normalized against unknown/legacy values;
runtime in `apps/web/src/lib/theme.ts`; controls in the topbar gear dialog and Settings →
Appearance (shared `ThemeControls`); contract pinned by `theme.test.ts`.

## Invariants that survive any future restyle
Mobile bar: ≥44px targets, ≥16px form fonts, zero horizontal overflow at 320–430px, safe-area
insets. Flow semantics and safety/privacy copy are never restyled into different meaning; the
P0 notice strings stay byte-identical to the recorded copy. Focus-visible 3px accent outlines.
