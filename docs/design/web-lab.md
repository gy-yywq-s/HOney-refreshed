# Web design lab

Status: **experimental — not approved.** The Web lab explores a direction that
works on desktop, mobile browser and installed PWA. It shares
`shared-product-design-invariants.md` with iOS and nothing visual.

## History

- **Round 1 (superseded): editorial system** — Space Grotesk display + Fraunces
  accents, 42–96px heroes, petrol/glacier accents, dot-grid drift, pointer
  glow, hero sweep, parallax, count-ups, numbered rail/cards, four surfaces ×
  three UI fonts. Recorded in `web-style.md` (now a historical record). The v3
  review's judgment, accepted: it reads as design-agency showcase, not a
  student utility; the interface performs its own authorship.

## Round 2 (current): candidate A — quiet humanist

Hypotheses under test (per review §5.5; these are hypotheses, not brand spec):

- **Type**: one humanist sans for UI, headings and feed body (Source Sans 3
  or an equivalent neutral stack). Scale: page titles 28–36px, section titles
  20–24px, body 16.5–18px, meta 12.5–14px. Fraunces retires from hero/body;
  the wordmark PNG remains the serif brand presence.
- **Palette**: narrow, cool, quiet — cool off-white canvas, white surface,
  deep blue-gray ink, cool gray secondary, pale gray-blue hairlines, ONE
  muted blue/blue-teal accent; semantic colors only for real states.
  (Owner constraint: cool tones only — rule 4d, no guessed warmth.)
- **Motion**: keep only state-explaining motion (route/sheet transitions,
  skeletons, feed append, accurate lesson progress, save/publish outcomes).
  Ambient loops, pointer glow, sweeps, parallax, count-ups: off.
- **Composition**: mobile screen-composition model per review §16.14 — every
  core route declares a scroll model (FIT / COMPACT_OVERFLOW / FRAMED_SCROLL /
  FRAMED_EDITOR / DOCUMENT), height classes compact/regular/tall with an
  explicit degradation order; the app shell owns the viewport.
- **Copy**: facts and actions on signed-in surfaces; positioning lines only on
  unauthenticated/marketing surfaces. No numbered showcase language.

Approval state moves here only when Gary approves a running build.

## Screen composition status (2026-09-01)

Implemented: the app shell owns the viewport (`body { overflow: hidden }`,
`#root` full-height); `<main data-scroll-owner>` is the single business
scroll region (`overscroll-behavior-y: contain` — no shell drag leak, local
elasticity kept); Login owns its keyboard overflow; Timetable's date nav is
a sticky frame element; compact-height (≤700px) degrades spacing → metadata
→ Home preview count before any overflow; tall (≥851px) adds breathing room
only. Static pins in `apps/web/src/lib/composition.test.ts`. REMAINING owner
evidence: the real installed-PWA matrix (320×568 / 375×667 / 390×844 /
430×932 + short-landscape) and the §16.14.11-22 feel check.

## Scroll models (declared per §16.14.2)

| Route | Model |
|---|---|
| Login, Import consent | FIT |
| Home | COMPACT_OVERFLOW |
| Experiences feed | FRAMED_SCROLL |
| Explore | FRAMED_EDITOR/FRAMED_SCROLL hybrid |
| Entity pages | FRAMED_SCROLL |
| Compose | FRAMED_EDITOR |
| Timetable, History | FRAMED_SCROLL |
| Your notes & posts | FRAMED_SCROLL |
| Why this space exists, privacy/moderation docs | DOCUMENT |
| Settings | FRAMED_SCROLL |
