# HOney brand — Infinite colour (v1, 2026-09-04)

The identity in use. Gary supplied the pack (`HOney infinite colour assets v1`); the masters
live here, the built outputs live where the apps read them. The M4 concepts this replaced
(wordmark/icon a·b·c, 2026-08-31) are in git history.

The mark is an asymmetric Möbius loop with outward-facing open ends, rounded plum/amber
endpoints and a separate yellow/green in-progress gesture; the wordmark is a single-weight
rounded stroke with coloured joints. `preview.png` shows the set at size.

## Masters

`infinite-colour-v1/source/` — `icon-master.png`, `icon-dark-master.png`, `icon-tinted-master.png`
(1254 px), `web-icon-master.png` (the Web companion, globe composited in), `wordmark.png`,
`wordmark-dark.png`, `wordmark-monochrome.png` (1060×470) and the SVG traces.

## Where the outputs are used

| Output | Path |
|---|---|
| Web app icons (PWA install, Apple touch) | `apps/web/public/icon-{180,192,512}.png` |
| Web favicon | `apps/web/public/favicon-32.png` |
| Web wordmark (light / night) | `apps/web/public/wordmark.png`, `wordmark-dark.png` |
| iOS app icon (default · dark · tinted) | `ios*/…/Assets.xcassets/AppIcon.appiconset/` |
| iOS wordmark (1x/2x/3x) | `ios-web-port/…/Assets.xcassets/Wordmark.imageset/` |

The night wordmark is its own artwork, never the light one inverted: the coloured joints must
keep their hues.
