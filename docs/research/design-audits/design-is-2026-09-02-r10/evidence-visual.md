# Visual evidence — design-is r10 (Opus visual subagent). Evidence only; nothing here is scored.

Anchor IDs `[V-R10-n]`. Probes and logs under `/root/claude-work/design-audit/`, named `r10-vis-*`
(the audited commit `41a01fe`) and `r10c-vis-*` (the build that replaced it mid-pass). Every
finding carries a viewport, a measured value, a probe file and, where there is a cause, a
`file:line`. No post was published, no report submitted, no reaction pressed, no Settings value
changed on the server; every theme swatch pressed was restored to Stone in a context that clears
`honey.theme.surface` on boot; every browser was closed.

## 0-A. BUILD ATTRIBUTION — the deployment changed five times during this pass

The audit target was `41a01fe` (`index-CJ2b0Z4x.js` / `index-DOdf_Dgc.css`). At 03:41:41 UTC —
22 minutes into this pass — `9c3b23f` landed, followed by `60c8672` (03:46:14), `979a42e`
(03:50:24), `bd54519` (03:57:36) and `bc3b7c9` (04:00:47). The live site now serves
`index-4oNbE07m.js` / `index-C9l5CGbD.css` (`bc3b7c9`). `git diff 41a01fe..bc3b7c9 -- apps/web`
touches `Modal.tsx`, `PullToHistory.tsx` (new), `PullToRefresh.tsx`, `format.ts`, `refresh.ts`,
`TimetablePage.tsx`, `components.css`, `features.css`, `tokens.css`.

The churn did not stop: by the time this file was written the live site had moved again to
`daff183` ("Tabs are plain links: the tree decides the lit tab and aria-current",
`index-C83Nv1o2.js` / `index-Ba_y2FrG.css`), which is **after** every `r10c-*` measurement below.
Every `bc3b7c9` figure here was taken against a pinned `index-4oNbE07m.js` / `index-C9l5CGbD.css`
and is therefore reproducible, but it is no longer what a visitor loads.

`/assets/*` is served immutable, so the audited bundle is still fetchable. From the moment the
churn was detected, every remaining measurement was taken against a **pinned** bundle: the
document response is rewritten in `page.route` to reference the wanted asset pair, with
`serviceWorkers: "block"` so the SW cannot serve a newer `index.html`
(`r10-pin.js` → `41a01fe`, `r10-pin-cur.js` → `bc3b7c9`). Each probe below logs the script
filename it actually loaded.

| probe | log | ran at (UTC) | build measured |
|---|---|---|---|
| `r10-vis-served.js` | `r10-vis-served.log` | 03:19 | 41a01fe (CSS downloaded 03:43, byte-identical hash) |
| `r10-vis-css.js` / `css2.js` / `dangling.js` | `.log` | 03:20 | source at 41a01fe (working tree still 41a01fe) |
| `r10-vis-moves.js` | `r10-vis-moves.log` | 03:22 | 41a01fe |
| `r10-vis-new.js` / `new2.js` / `new3.js` | `.log` | 03:25–03:27 | 41a01fe |
| `r10-vis-outline.js` | `r10-vis-outline.log` | 03:24–03:31 | 41a01fe |
| `r10-vis-typespace.js` ×4 | `r10-vis-typespace-*.log` | 03:39–03:41 | 41a01fe |
| `r10-vis-dialogs.js` + `dialogs2.js` | `.log` | 03:34–03:43 | 41a01fe |
| `r10-vis-compact.js` (+ `-late`) | `.log` | 03:44–03:47 | **mixed 9c3b23f/60c8672 — superseded, do not cite** |
| `r10-vis-contrast.js` / `edgeband.js` (first run) | — | 03:45–03:49 | **mixed — superseded** |
| `r10-vis-live.js` | `r10-vis-live.log` | 03:52–03:58 | 979a42e (unpinned live) |
| `r10-vis-pin.js` / `pin2.js` | `r10-vis-pin.log` / `pin2.log` | 04:0x | **41a01fe, pinned** |
| `r10-vis-contrast.js` / `states.js` / `edgeband.js` (re-run) | `.log` | 04:1x | 41a01fe, pinned |
| `r10c-vis-*` (all) | `r10c-vis-*.log` | 04:2x–05:0x | **bc3b7c9, pinned** |

Where a number differs between builds both are given. Rows in §0-B are marked **[41a01fe]** or
**[bc3b7c9]**.

## 0-B. Verification of the r9 visual moves

| r9 move (handoff move 4 + preserve list) | verdict | measurement | probe |
|---|---|---|---|
| One disabled treatment (`.btn--primary:disabled` == `.btn--ghost:disabled`) | **CONFIRMED** [41a01fe + bc3b7c9] | Both compute `background rgba(0,0,0,0)`, `border 1px solid rgba(35,43,49,.14)` (= `--line`), `color rgb(92,103,112)` (= `--muted`), `opacity 1` on stone; `rgba(233,237,239,.16)` / `rgb(166,175,181)` on a dark boot. Identical on 6/6 boot×width cells. r9: two fills (`color(srgb .891 .901 .907)` vs transparent+border). | `r10-vis-outline.log` (DISABLED lines), `r10-vis-new2.log`, `r10c-vis-extra.log` |
| `.react-btn:disabled` styled; `pointer-events:none` removed | **CONFIRMED** | Synthetic `.react-btn:disabled` → `opacity .7`, `cursor default`, **`pointer-events auto`**; `.react-btn[aria-disabled="true"]` the same. Served rule is now `.react-btn:disabled, .react-btn[aria-disabled="true"]{opacity:.7;cursor:default}` with no `pointer-events`. r9: no `:disabled` rule, `pointer-events:none` on the aria form. | `r10-vis-moves.log`, `r10c-vis-extra.log`, `components.css:248-256` |
| Skip ring radius = the card radius | **CONFIRMED** | `.main:focus > .view` and `.focus-landing[data-landed]:focus` both `border-radius: 17px`; `.card` renders `17px` (Settings, Mine, Compose, 404). r9: `12px`, matching no rendered radius. | `r10-vis-served.log`, `r10-vis-pin2.log` (PIN-SKIPRING 20/20 cells `radius 17px`) |
| Timetable bottom room so the ring never crosses "20:00" | **CONFIRMED on 41a01fe, REFUTED on bc3b7c9** | 41a01fe: `.timetable-screen{padding-bottom:var(--sp-2)}` puts the label inside `.view` — 390×844 `.view` bottom 846 vs label bottom 844; 320×568 557 vs 555; **0 crossings on 20/20 skip-ring cells**. bc3b7c9 (and 979a42e): the padding is gone — 390×844 `.view` bottom 764 vs label bottom 770 (**6 px outside, into the ring band**); 320×568 545 vs 551 (6 px). | `r10-vis-moves.log`, `r10-vis-pin2.log`, `r10-vis-live.log` (SKIPRING crossings) |
| Tap-highlight suppressed on `input, textarea` | **CONFIRMED** | `foundations.css:61-68` now lists `button, a, input, textarea`; computed `-webkit-tap-highlight-color: rgba(0,0,0,0)` on all four on Explore and Compose, both builds. r9: `rgba(51,181,229,.4)` on inputs/textareas. | `r10-vis-moves.log`, `r10c-vis-extra.log` |
| The two adjacent `@media (max-height:620px)` blocks merged | **CONFIRMED** [41a01fe] | `features.css:759,769` collapsed into one block (`git diff eede644..41a01fe -- apps/web/src/styles/features.css`); context-aware duplicate-selector groups in the served CSS = 0; source duplicate-in-context groups 1 (`textarea` at `foundations.css:59,66`, the same multi-line-list artefact r9 recorded for `a`). | `r10-vis-css2.log`, `r10-vis-served.log` |
| Empty-day gap 8 px under the note | **CONFIRMED** [41a01fe] | `.timeline__empty` margin `0px 0px 8px` (was `8px 0`); note margin `12px 0 8px`; **note→empty gap = 8 px** at 390×844 and on 320/360/390 compact. r9: 16 px. (On bc3b7c9 the note no longer exists on phones — see §3.) | `r10-vis-moves.log`, `r10-vis-pin.log` (`gapNoteEmpty=8`, 4/4 empty-day rows) |
| Compact landing keeps h1 + note + block 1 in view, both clock states | **PARTIAL** | **41a01fe, pinned, real clock (≈11:5x CST, after P1) and mocked 10:35 CST — identical, because `TimetablePage.tsx:340-345` now always targets `visible[0]`:** 3-lesson days (2026-09-02, 2026-08-24) at 320×568 / 360×620 / 390×620 → h1 in view **6/6** (y = 9, 3 / 5, 2 / 24, 23), note in view 6/6, block 1 y = 91–100, **never above 0**; scroll 122–146. **Sparse day 2026-08-25 (one 13:30 lesson) still clamps to max scroll: h1 y = −70 / −18 / −90 (in view 0/3), note off 2/3, block 1 y = 202–256.** So the clock-dependence is fixed; the sparse-day clamp is not. | `r10-vis-pin.log` (PIN-LANDING, 40 cells) |
| Tab 1 after the landing = the skip link | **PARTIAL / REFUTED** | 41a01fe: the `skip?.focus({preventScroll:true}); skip?.blur()` reset (`TimetablePage.tsx:357-360`) moves the start point past the skip link — **Tab 1 = `BUTTON.daynav__arrow "‹"` on 9/9 compact lesson-day cells** (r9: a lesson block). Tab 1 = skip link on 844/932 and on the empty day. bc3b7c9: same — Tab 1 = `‹` at 320×568/360×620/390×620 on lesson days, and **at 320×568 the skip link is absent from the Tab order entirely** (15 stops, none is the skip link). | `r10-vis-pin.log` (`firstTab`), `r10c-vis-tab.js` output |
| Reconnect sheet scroll at 320×568 | **CONFIRMED** | 42/42 dialog opens on 41a01fe and 42/42 on bc3b7c9 report `scrolls: false`, `scrollHeight − clientHeight = 0`. r9: Reconnect 1 px. | `r10-vis-dialogs.log`, `r10-vis-dialogs2.js`, `r10c-vis-dialogs.log` |
| `.nextlesson__wash` idle animation removed | **CONFIRMED** | `features.css:78-84` no longer declares a transition; computed `transition: all` (i.e. 0 s) on `no-preference`, `1e-06s` on `reduce`. With `/api/next-lesson` fulfilled as `temporalState:"now"` (a lesson genuinely in progress), `document.getAnimations()` at 2.6 s and 4.8 s = **0** on both builds. r9: a running 1 s `width` transition restarted every tick. | `r10-vis-pin2.log` (PIN-WASH), `r10-vis-live.log` (WASH), `r10c-vis-extra.log` |
| `home-foot` / `home-voices` min-heights reserved | **CONFIRMED** | `.home-foot{min-height:44px}` renders h=110; `.home-voices{min-height:132px}` renders h=132 (i.e. the reserve is exactly the rendered height, so nothing resolves late). Same at 320×568, 390×844, both builds. | `r10-vis-moves.log`, `r10-vis-pin2.log`, `r10c-vis-extra.log` |
| Dangling trailing comments 10 → ≤6 | **REFUTED** | The r9 detector (`r9-struct-css.js` §2, re-run verbatim as `r10-vis-dangling.js`) counts **12** at 41a01fe, up from r9's 10. Removed: `components.css:252`, `features.css:80`. Added: `features.css:83-84` (the comment that replaced the deleted `transition`, now followed only by `}`), `features.css:1317`, `:1337` (`border-radius:17px …`), `:1343` (`min-height:132px …`). The second detector (`r10-vis-css2.js`, "next non-blank line is not a rule") reads **8**, up from r9's 7 by the same `features.css:83-84`. | `r10-vis-dangling.log`, `r10-vis-css2.log` |
| Rest-state outline census stays 0 | **CONFIRMED** | 41a01fe: 0 ringed of 117 visible controls on 10 routes × {320×568, 390×844} × {stone, genuine dark boot} and 0 of 137 at 1280×800 — 60 loads, `activeElement=BODY` on all. Rest ≠ focused on **140/140** Tab stops (Settings 17 / Timetable 13–15 / Feed 15 at three widths). Whole-frame accent-pixel counts unchanged from r9 to the pixel (Settings 0/0/102, Timetable 126/145/415 stone; 0/0/176, 126/143/295 dark). bc3b7c9: 0 of 115 / 0 of 136, 60 loads; 0/114 Tab stops equal. | `r10-vis-outline.log`, `r10c-vis-outline.log` |
| Mobile sheet grammar (7 dialogs × 3 heights × 2 boots) | **CONFIRMED** | 42/42 on each build: `border-radius 20px 20px 0px 0px`, borders `solid/none/none/none`, `padding 20px 16px 24px`, `animation sheet-up 0.42s`, bottom == `innerHeight` 42/42, `max-height` 568 / 620 / 776.48 px, `#root[inert]` 42/42, 0 controls ringed inside a dialog, dark-boot palette `rgb(29,33,37)` on `rgb(233,237,239)` 21/42. `sheet-up` consumers exactly `.modal` and `.nudge`. | `r10-vis-dialogs.log` + `dialogs2.js`, `r10c-vis-dialogs.log` |
| Served CSS parses clean | **CONFIRMED** | 41a01fe: 41,080 B, 377 selector blocks, 13 at-rules, **0 orphan declarations, 0 dead bytes, 0 duplicate-in-context groups, 0 bare-element-in-state lists**, 226 classes, 6 `@keyframes`. bc3b7c9: 43,020 B, 397 blocks, same zeros, 233 classes. | `r10-vis-served.log`, `r10-vis-served3.log` |
| Palette / tokens unchanged | **CONFIRMED** | `tokens.css` blob at 41a01fe = `1d70d963a91a5bfbeb17928b599185286ad8f836`, byte-identical to r8/r9. At `bc3b7c9` = `1ca81afb29cec1025a8eea9ed77a5db46ab69f6b`, and the whole diff is two new non-colour tokens (`--inset-top`, `--inset-bottom`). 43 colour literals in the four non-admin stylesheets on both. | `git rev-parse`, `r10-vis-css.log` |

**New surfaces from `e5aec3e`, audited here for the first time:** Explore Find mode, the Explore
"Recent" list, the composer chooser, entity counts, the feed headline — §2 items [V-R10-11]…[V-R10-16].

## 1. Required fields

### Spacing scale observed (rendered px, all screens per viewport)

| viewport | histogram | on-ladder % (4/8/12/16/20/24/32/44) |
|---|---|---|
| 320×568 [41a01fe] | 1(1) 4(194) 8(181) 12(292) 13(8) 16(120) 20(68) 24(11) 90(10) | **97.85 %** (866/885) |
| 390×844 [41a01fe] | 1(1) 4(192) 8(173) 12(301) 13(8) 16(119) 20(70) 24(11) 84(1) 96(10) 130(1) | **97.63 %** (866/887) |
| 430×932 [41a01fe] | 1(1) 4(192) 8(173) 12(301) 13(8) 16(109) 20(70) 24(11) 44(10) 96(10) 124(1) 170(1) | **97.63 %** (866/887) |
| 1280×800 [41a01fe] | 4(102) 8(177) 12(269) 13(8) 16(219) 20(72) 24(31) 32(30) 64(20) 110(10) 216(10) 249(20) 656(1) 702(1) | **92.69 %** (900/971) |
| 320×568 [bc3b7c9] | 4(215) 8(179) 12(288) 13(8) 16(122) 20(68) 24(11) 90(10) | **98.00 %** (883/901) |
| 390×844 [bc3b7c9] | 4(213) 8(171) 12(297) 13(8) 16(121) 20(70) 24(11) 80(10) 84(1) 130(1) | **97.78 %** (883/903) |
| 430×932 [bc3b7c9] | 4(213) 8(171) 12(297) 13(8) 16(112) 20(70) 24(11) 44(9) 80(10) 124(1) 170(1) | **97.78 %** (883/903) |
| 1280×800 [bc3b7c9] | 4(120) 8(177) 12(271) 13(8) 16(219) 20(72) 24(31) 32(30) 64(20) 110(10) 216(10) 249(20) 656(1) 702(1) | **92.93 %** (920/990) |

Every off-ladder value is attributed: `90/96/80/110 px` = the shell's documented nav clearance
(`components.css:669`, `features.css:1211`); `13 px` = `padding-block: calc(var(--sp-3) + 1px)` on
inline text links (`features.css:1249-1253`, 8 declarations); `64/216/249/656/702 px` = `clamp()`,
`margin:auto` and `--rail`. Off-ladder **literal** spacing declarations in source: **2** at both
builds (`foundations.css:96 margin:-1px`, `features.css:1211 padding-bottom:90px`); r9 counted 3 —
`features.css:355 scroll-margin-top:100px` is now `calc(var(--sp-8) * 2 + var(--sp-3))`
(`features.css:360`), the same 100 px composed from ladder tokens.
Note margins `12/8` and note→canvas `8 px` re-verified on 41a01fe (4/4 dates, 5 viewports).

### Type scale observed (rendered px)

| viewport | set | floor |
|---|---|---|
| 320×568 | 12, 13, 15, 16, **17**, 20, 24, 26, 28 | 12 |
| 390×844 | 12, 13, 15, 16, **17**, 20, 22, 24, 26, 28 | 12 |
| 430×932 | 12, 13, 15, 16, **17**, 20, 22, 24, 27.95, 28 | 12 |
| 1280×800 [41a01fe] | 12, 13, 15, 16, **17**, 20, 28, 30, 32, 34, 36 | 12 |
| 1280×800 [bc3b7c9] | 12, 13, 15, 16, **17**, 20, 30, 32, 34, 36 | 12 |

17 px is new this round and is on the constitution's ramp — it is the feed headline
(`p.feed-headline`, `features.css:869-874`). Nothing below 12 px anywhere. No small all-caps: the
only `.overline` / `.eyebrow` render `text-transform: none`, `letter-spacing 0.13px`, 13 px/600 —
including the four new ones (Recent, Your recent lessons, Experiences that mention…, section
counts). Off-ramp `font-size` declarations: **11** including `admin.css` (10 excluding) —
unchanged from r9; all are `clamp()` display sizes. `28 px` disappears from the desktop set on
`bc3b7c9` because `h1.schedule-header` was removed (§3).

### Colour

- Source colour literals in `tokens/foundations/components/features.css`: **43** at both builds
  (r9: 43).
- `tokens.css` blob: identical to r8/r9 at 41a01fe; at bc3b7c9 the only change is two inset tokens.
- Colour-ish literals in the served CSS: **48** on both builds.
- Rendered unique colours over 10 routes at 390×844 [bc3b7c9]: **18 stone / 20 night** (r9: 17/19).
- Warm hues outside danger/ok: **0**. Exactly one warm value renders per boot —
  `rgb(181,56,68)` stone / `rgb(242,145,154)` night — and it is `--danger`, used by
  `.timeline__now` and `.banner--danger`. `r10c-vis-colours.log`.
- One accent per surface: `--accent` `#33667c` stone / `#8fc2d4` night on all four surfaces;
  Stone/White/Mist keep `#33667c`, Night switches to `#8fc2d4` (`r10c-vis-extra.log`).
- Four background surfaces all reachable and all render correctly from the Settings 2×2 grid at
  390×844: Stone `rgb(244,246,247)`, White `rgb(255,255,255)`, Mist `rgb(238,242,242)`, Night
  `rgb(20,23,26)`; `--surface-solid` `#fbfcfc / #ffffff / #f7faf9 / #1d2125`; `theme-color`
  rewritten to match 4/4; `aria-pressed` exactly one true 4/4. Grid `154px 154px`, gap 8, cells
  154×81. The **Appearance dialog opener is still rail-only** (`button.settings-trigger`
  `display:grid` but zero-width at 390) — unchanged from r9 `[A-R9-23]`; the 2×2 grid on Settings
  is the only phone-reachable picker.

### Lowest contrast ratio across primary text [bc3b7c9, alpha-composited, 9 routes × 2 boots]

- **Stone floor 4.77:1** — the error-banner sentence "Could not reach the HOney server…"
  (16 px/400). Next: 5.34 `.home-head__date`. r9's floor element `.home-head__stale` (4.66) did
  not render this session (the sync was fresh).
- **Night floor 7.03:1** — same banner sentence. Next: 7.13 `.lesson-block__teacher` 12 px/600.
- Enabled text below 4.5:1: **0 genuine failures**. Ten 1.00 readings are the documented
  ancestor-walk artefact: the `.mobile-nav__item` labels (transparent over a `backdrop-filter`
  bar) plus, new this round, `.pullup` "Pull up for History", whose ancestor carries
  `opacity: 0` at rest so the probe's effective foreground equals its background.
- Disabled text (WCAG-exempt): 7.26–8.07 night, 5.34–5.66 stone.
- Portaled dialog on a genuine dark boot: `rgb(29,33,37)` on `rgb(233,237,239)`, 42/42.
- `r10c-vis-contrast.log`.

### States checklist — 390×844, endpoint named, `r10c-vis-states.log` + `r10c-vis-states2.log`

| screen | empty | loading | error | success | focus | disabled |
|---|---|---|---|---|---|---|
| Home (`/api/next-lesson`) | n/a | ✓ 2 blocks / 4 rows, `role=status aria-label="Loading"` | ✓ banner + Try again, 316×130 | ✓ | ✓ | n/a |
| Timetable (`/api/timetable`) | ✓ "No lessons on Sun 6 Sept" | ✓ 1 block / 4 rows | ✓ banner + Try again | ✓ | ✓ | n/a |
| Feed (`/api/experiences/feed`) | ✓ | ✓ 1 block / 6 rows | ✓ banner | ✓ | ✓ | n/a |
| Explore (`/api/entities`) | ✓ "Nothing here yet." | ✓ 1 block / 6 rows | ✓ banner, **and the four "Nothing here yet." are now suppressed** (r9 showed both) | ✓ | ✓ | n/a |
| Explore (`/api/directory`) | — | ✓ full listing renders while directory loads | **ROUGH — banner shown, but the complete entity listing disappears** (`ExplorePage.tsx:120` `entities.error \|\| directory.error ? null`) although `/api/entities` succeeded | ✓ | ✓ | n/a |
| Mine (`/api/entities`) | ✓ "Nothing here yet" | **MISSING** — 0 skeletons (the empty branch wins with 0 keys; explained, as in r9) | ✓ banner above the empty block | ✓ | ✓ | n/a |
| History (`/api/history`) | ✓ | ✓ 1 block / 4 rows | ✓ banner | ✓ | ✓ | n/a |
| Entity — feed | ✓ "No one has shared an experience here yet." | ✓ 1 block / 4 rows | ✓ banner under the intro | ✓ | ✓ | n/a |
| Entity — `/api/entities` | ✓ "No experiences here." | ✓ (registry-unknown branch, no CTA) | ✓ banner above, no Share CTA, no intro | ✓ | ✓ | n/a |
| Entity — `/api/experiences/stats` | ✓ | ✓ (silent) | **ROUGH — silent**: the count sentence simply never appears; nothing says a number is missing | ✓ | ✓ | n/a |
| Compose — `?lessonId=` (`/api/history`) | n/a | **✓ NEW: 1 skeleton block / 4 rows** (r9: none) | **✓ NEW: banner + region "Could not load" + Try again** (r9: none) | ✓ | ✓ | ✓ |
| Compose — `?entityKey=` (`/api/entities`) | n/a | ✓ 1 block / 4 rows | ✓ banner + region "Could not load" | ✓ | ✓ | ✓ two identical fills |
| Compose — chooser (0 recent lessons) | ✓ card collapses to two buttons, no empty heading | ✓ | — | ✓ | ✓ | n/a |
| **Find mode** (`/api/experiences/search`) | **MISSING** — a search with 0 experiences renders nothing at all | **MISSING** — 0 skeletons after 2.5 s of an 9 s delay, no `role=status` text | **MISSING** — aborted: no banner, no alert, no text; identical to a successful empty search | ✓ section "Experiences that mention “physics”" + posts | ✓ | n/a |

Counts: **states missing 4** (Find-mode loading, error and empty; Mine loading — the last
explained by the empty branch, as in r9), **states rough 2** (Explore under a directory-only
failure; entity-stats failure silent). Selected ✓ (scope pills), pending ✓ (tapped pill only).

## 2. Concrete findings

### [V-R10-1] The last hour label sits 6 px outside `.view`, back inside the skip ring — bc3b7c9 only
**Repro:** 390×844 and 320×568, `hasTouch`, `Asia/Shanghai`, `/timetable?date=2026-09-02`; focus
`.main` (Tab 1 → Enter on "Skip to content", or `main.focus()`). **Measured:** 390×844 `.view`
box `[16,0,374,764]`, `span.timeline__hour "20:00"` box `[33,758,60,770]` — 6 px below the ring's
outer edge (outline 3 px at offset 3). 320×568: `.view` bottom 545, label bottom 551. Also
`.view` top = 0 at 390×844, so the **ring's top band (−6…0) is off-screen**.
**On 41a01fe this was fixed** (`.view` bottom 846 vs label 844; 557 vs 555; 0 crossings on 20/20
cells). **Cause:** `features.css` at 41a01fe carried `.timetable-screen { padding-bottom: var(--sp-2) }`
(added in `41a01fe`); the Timetable restyle removed it and the canvas now runs to the frame edge.
`r10-vis-pin2.log`, `r10-vis-live.log`, `r10c-vis-overlap.log`.

### [V-R10-2] The floating nav covers the foot of the day canvas on 3 of 7 phone sizes — bc3b7c9
**Repro:** `/timetable?date=2026-09-02`, `hasTouch`, `Asia/Shanghai`, scrollTop 0 (the landing
position). **Measured** (`nav.mobile-nav` box vs `.timeline` and the hour labels):

| viewport | canvas below the nav's top | hour labels covered |
|---|---|---|
| 320×568 | **22 px** | `"20:00"` 27×12 fully |
| 375×667 | **33 px** | `"20:00"` 27×12 fully |
| 390×620 | **60 px** | `"19:00"` 27×12 and `"20:00"` 27×10 |
| 320×600 | −10 px (clear) | none |
| 360×620 | −16 px (clear) | none |
| 390×844 | −6 px (clear) | none |
| 430×932 | −6 px (clear) | none |

No lesson block is covered on any size (0/7). `r10c-vis-overlap.log`.

### [V-R10-3] The clock-driven now-line crosses canvas labels — bc3b7c9
**Repro:** `/timetable?date=2026-09-02`, `Asia/Shanghai`, `Date` mocked in an init script.
**Measured** overlaps of `div.timeline__now` (7 px tall, `--danger`) against text boxes:

| clock (CST) | 320×568 | 390×844 |
|---|---|---|
| 12:05 | `"12:00"` hour label, **6 px** | `"12:00"` 4 px; `"Lunch Break"` 1 px |
| 12:30 | `"Lunch Break"` **3 px** | none |
| 18:05 | `"18:00"` **7 px** | `"18:00"` 5 px; `"Dinner Break"` 1 px |
| 10:35 | none | `"P2"` 1 px; `"Free"` 1 px |

7 of 8 cells collide. The screenshot `r10c-vis-tt-320x568.png` (captured at ≈12:0x CST, real
clock) shows the red line bisecting the "Lunch Break" glyphs. `r10c-vis-nowline.log`.

### [V-R10-4] The day heading leaves the viewport on every non-today date at compact heights — bc3b7c9
**Repro:** 320×568 / 360×620 / 390×620, `hasTouch`, `Asia/Shanghai`, cold load of
`/timetable?date=2026-08-24` and `?date=2026-08-25`; real clock and mocked 10:35 CST both.
**Measured:** `h1.daynav__date` y = **−13 / −13 / −13** (Aug 24) and **−77 / −25 / −115**
(Aug 25); in view **0/6** compact lesson-day cells per clock state. Today and the empty day keep
it at y = 9. **Cause:** on any non-today date the bar grows a second row ("Back to today"), from
`header.daynav` h=58 → **h=106**; block 1 therefore starts 48 px lower, so the landing
`scrollIntoView` no longer clamps to 0 and scrolls 22–124 px, taking the heading — which now
*is* inside the scrolling bar — off screen. Measured at 390×620:
`2026-09-02 → daynav h=58, .focus-landing top 66, scrollTop 0`;
`2026-08-24 → daynav h=106, .focus-landing top 114, scrollTop 24`.
On 41a01fe the heading was a separate `h1.schedule-header` above the bar and stayed in view on
6/6 three-lesson compact rows. `r10c-vis-timetable.log`, scratch comparison run.

### [V-R10-5] The sparse day still clamps the landing to maximum scroll — both builds
**Repro:** `/timetable?date=2026-08-25` (one lesson, 13:30–15:00) at 320×568 / 360×620 / 390×620.
**Measured [41a01fe]:** `scrollTop == maxScroll` 3/3 (216/216, 164/164, 236/236); `h1.schedule-header`
y = −70 / −18 / −90; note off 2/3; block 1 y = 204 / 256 / 202. **[bc3b7c9]:** 86/86, 34/34,
124/124; h1 y = −77 / −25 / −115. Unchanged from r9 `[A-R9-19]` for this day.
`r10-vis-pin.log`, `r10c-vis-timetable.log`.

### [V-R10-6] The programmatic landing still moves the keyboard's starting point — both builds
**Repro:** cold load `/timetable?date=2026-09-02` at 320×568, press Tab once.
**Measured [41a01fe]:** Tab 1 = `BUTTON.daynav__arrow "‹"` on 9/9 compact lesson-day cells (r9:
a lesson block). **[bc3b7c9]:** the full sweep at 320×568 yields 15 stops and **no skip-link stop
at all** — 1. `‹`, 2–5. `input.daynav__picker` (four presses), 6. `›`, 7. `A.daynav__history-sr`,
8–10. lesson blocks, 11–14. nav, 15. body. At 390×844 the skip link is stop 1.
Cause: `TimetablePage.tsx:352-360` — `el.scrollIntoView` then `skip?.focus({preventScroll:true});
skip?.blur()`, which lands the sequential start point *after* the skip link.
`r10-vis-pin.log`, `r10c-vis-tab.js`.

### [V-R10-7] The native date input takes four Tab presses and the fourth loses the ring — bc3b7c9
**Repro:** phone Timetable, Tab through the bar. **Measured:** `INPUT.daynav__picker`
(`type=date`, `opacity 0`, box 266×44 at 390 / 196×44 at 320, laid exactly over the h1) is the
active element for **four consecutive Tab presses** at both widths; presses 1–3 compute
`outline-style: solid` (via `.daynav__date:has(.daynav__picker:focus-visible)`, offset **−3px**),
the fourth computes `outline-style: none` — one keyboard stop with no visible focus.
`r10c-vis-tab.js`.

### [V-R10-8] A 32 px focusable "History" link below the 44 px floor — bc3b7c9
**Repro:** phone Timetable, Tab. **Measured:** `A.daynav__history-sr "History"` is a real Tab stop
with box **72×32** at 390×844 and 320×568 — below the 44 px floor the rest of the app holds
(r9 census: 257/259 ≥44, the two exceptions being an `aria-hidden` 5×4 input and a nested 22×22
checkbox). It sits at y=58, immediately under the bar, and is invisible until focused.
`r10c-vis-tab.js`.

### [V-R10-9] History and Sync now have no visible affordance on phones — bc3b7c9
**Repro:** `/timetable?date=2026-09-02` at 390×844, `hasTouch`, at rest.
**Measured:** visible controls inside `.view` = **5** — `‹` 44×44, `›` 44×44 and three
`button.lesson-block`. `A.btn--ghost "History"` and `BUTTON.btn--primary "Sync now"` are in the
DOM with `display: inline-flex` and box **0×0**; `div.pullup "Pull up for History"` occupies 41 px
of layout at y=724 but computes `opacity: 0`. Nothing on screen names either action until the
user performs a gesture. Desktop (1280×800) keeps both as 67×36 / 79×36 buttons plus a
"Synced 3 min ago" caption. `r10c-vis-pull.log`, `r10c-vis-timetable.log`.

### [V-R10-10] Explore blanks the complete entity listing when only the directory fails — bc3b7c9
**Repro:** `/experiences/explore`, abort `/api/directory` only (`/api/entities` succeeds).
**Measured:** one `role=alert` banner and **zero** entity rows, zero section headings — the
rendered text is just the page title, the sub-line and "Back to Experiences". Delaying the same
endpoint 6 s renders the full listing (6 teachers / 8 courses / 5 places) while it loads.
**Cause:** `ExplorePage.tsx:120` `entities.loading ? <Skeleton/> : entities.error || directory.error ? null : SECTIONS.map(...)`.
The constitution §4 requires every finite option set to be fully displayed. `r10c-vis-states2.log`.

### [V-R10-11] Find mode has no loading, no error and no empty state — both builds
**Repro:** `/experiences/explore`, type "physics", then (a) delay `/api/experiences/search` 9 s,
(b) abort it, (c) fulfil it with `experiences: []`. **Measured:** all three render **identically**
to each other and to the pre-search page — 0 skeleton rows, 0 `role=alert`, 0 status text, no
"Experiences that mention…" heading. Only a successful non-empty response renders the section
(verified: 1 post, heading `Experiences that mention “physics”`, `r10c-vis-find-results.png`).
**Cause:** `ExplorePage.tsx:135` gates the whole section on
`searchQ && !search.loading && search.data && search.data.experiences.length > 0`; the hook's
`loading` and `error` are never consumed. A student cannot tell a failed search from an empty one.
`r10c-vis-states2.log`, `r10-vis-new3.log`.

### [V-R10-12] The empty filter repeats one sentence four times
**Repro:** `/experiences/explore`, type a string that matches nothing (e.g. "zzzqqqx").
**Measured:** four `p.empty` "Nothing by that name." under "Teachers 0 / Courses 0 / Places 0 /
Food 0". `r10-vis-new.log`, `r10c-vis-state-find-empty.png`.

### [V-R10-13] The entity count is appended to the intro as a second sentence
**Repro:** `/experiences/teacher/t_23348879d1b4` with `/api/experiences/stats` fulfilled
`{experiences:18, courses:3, teachers:2}`. **Measured:** one `p.muted.entity-intro`, 16 px,
`rgb(92,103,112)`, margin `16px 0`, reading
"What students have experienced in classes with ChenJenny. No single Experience is the whole
picture. 18 experiences across 3 courses." — the count has no typographic identity of its own.
Course variant: "… 18 experiences with 2 teachers." The real endpoint returns
`{experiences:0,...}` for this account, so nothing renders in normal use.
`r10-vis-new3.log`, `r10-vis-entity-count-*.png`.

### [V-R10-14] The composer chooser
**Repro:** `/experiences/compose` with no query. **Measured:** `section.card[aria-label="Pick a target"]`
→ `p.text-3` (16 px), `h2.overline "Your recent lessons"` (13 px/600, `text-transform: none`,
`letter-spacing 0.13px`, margin `0 0 8px`), `ul.entity-list` with 5 `a.entity-row`
(padding `12px 0`), then `.card-actions` with two 44 px buttons. Row heights **48 / 49 / 49 / 73 /
49** — the 73 px row is "CIE Chinese Language & Literature", whose name wraps. With 0 recent
lessons the list and its heading disappear cleanly, leaving the sentence and the two buttons.
`r10-vis-new.log`, `r10-vis-chooser-390.png`, `r10c-vis-state-chooser-empty.png`.

### [V-R10-15] The Explore "Recent" list
**Repro:** seed `honey.exp.recent`, load `/experiences/explore`. **Measured:**
`section[aria-label="Recent"]` → `h2.overline "Recent"` (13 px, same recipe as the four section
headings) + `ul.entity-list` rows 48 px. It is hidden while a filter is typed. It sits above the
`.focus-landing` group "Everything listed", i.e. above the complete listing —
consistent with §4's "search only filters" but it does put a device-local convenience above the
canonical set. `r10-vis-new.log`.

### [V-R10-16] The feed headline
**Repro:** `/experiences` at 390×844. **Measured:** `p.feed-headline` 17 px/400
`rgb(35,43,49)`, box `[16,167,358,24]`, margin 0; `p.feed-identity` 13 px/400 muted
`[16,203,358,39]`. Two lines, no hero. 17 px is the only new size in the rendered ramp and is on
the constitution's ramp. `r10-vis-new.log`.

### [V-R10-17] The provenance line still truncates in the stream
**Repro:** `/experiences` at 320×568 and 390×844. **Measured:**
`.post__provenance "from someone who has taken this over time"` `scrollWidth 305` vs
`clientWidth 122` (320) / `192` (390) — ellipsised. Pre-existing (identical numbers in
`r9-vis-typespace-*.log`), carried into r10 by the unified provenance register. `r10-vis-typespace-*.log`.

### [V-R10-18] Dangling comments went up, not down
See §0-B. 12 by the r9 detector (r9: 10), 8 by the second (r9: 7). Four of the new ones are the
r9 fixes' own explanatory comments placed after the last declaration of their block
(`features.css:83-84`, `:1317`, `:1337`, `:1343`). `r10-vis-dangling.log`.

## 3. The NEW Timetable surface (bc3b7c9) — what the browser shows

**Top bar.** `header.daynav`, full-bleed `[0,0,W,58]` at `scrollTop 0`, `padding 8px 16px 4px`,
`z-index 12`, background `rgb(244,246,247)` (stone) / `rgb(20,23,26)` (night) — the page surface,
not a card. Contents: `button.daynav__arrow "‹"` 44×44, `h1.daynav__date` (20 px/650, 268×44 at
390) rendered as a rounded control with a chevron, `button.daynav__arrow "›"` 44×44. The heading
**is** the h1 — `h1.schedule-header` and `p.caption.timetable-note` no longer exist on any width.
`position: sticky` at innerHeight ≥ 620 except 620 itself (sticky at 375×667, 360×780, 390×844,
428×926, 430×932; **static** at 320×568, 320×600, 360×620, 390×620). On any non-today date the bar
grows to **106 px** with a second row carrying "Back to today" — see [V-R10-4].

**Native date input.** `input.daynav__picker[type=date]`, `opacity 0`, `pointer-events auto`,
box `[62,9,266,44]` at 390 / `[62,9,196,44]` at 320 — lying exactly over the h1 `[61,9,268,44]`.
It is no longer `aria-hidden` (r9: an `aria-hidden` 5×4 box out of the Tab order), so the 44 px
floor is met by area, at the cost of [V-R10-7].

**Canvas fit — 9 devices, today, cold, `Asia/Shanghai`** (`r10c-vis-timetable.log`):

| device | viewport | canvas `min-height` | canvas rendered h | page scroll | h1 in view | block×block | block×nav |
|---|---|---|---|---|---|---|---|
| iPhone SE | 320×568 | 450 | 450 | 38 px | ✓ | 0 | 0 |
| iPhone SE3 | 375×667 | 560 | 560 | 49 px | ✓ | 0 | 0 |
| iPhone 12 mini | 360×780 | 560 | 634 | **0** | ✓ | 0 | 0 |
| iPhone 13/14 | 390×844 | 560 | 698 | **0** | ✓ | 0 | 0 |
| iPhone 14 Plus | 428×926 | 560 | 780 | **0** | ✓ | 0 | 0 |
| iPhone 15 Pro Max | 430×932 | 560 | 786 | **0** | ✓ | 0 | 0 |
| compact | 320×600 | 450 | 450 | 6 px | ✓ | 0 | 0 |
| compact | 360×620 | 450 | 464 | **0** | ✓ | 0 | 0 |
| compact | 390×620 | 540 | 540 | 76 px | ✓ | 0 | 0 |

Every notched device in the matrix reaches zero page scroll, as the amended constitution claims;
the four sizes that still scroll are the two non-notched SE-class phones and the two synthetic
compact heights. The 620/540/450 notch decision therefore still holds in the CSS
(`min-height: 450px` at ≤ SE widths, `540px` at 390×620, `560px` otherwise, desktop 656 px), and
the amended constitution (`bc3b7c9`, §2) records both the new floor and the notches.

**Removed captions.** `p.caption.timetable-note` — which carried "P1–P6 are the school's six
lesson periods." and "Last synced N h ago." — renders `null` on all 9 phone sizes and on all four
dates. On desktop the sync line survives as `span.caption.daynav__state "Synced 3 min ago"`
(13 px) inside the bar. So on phones the last-sync fact is no longer stated anywhere on this
screen.

**Pull gestures** (`r10c-vis-pull.log`; no drag was ever released past a threshold, so no refresh
and no school sync was committed):

- Pull down, `div.ptr__group` (`data-stage`, translated + faded, `--ptr-spin` on a 16 px SVG):
  finger +30 px → `stage="pull"`, translateY 13.5, opacity 0.21, label **"Pull to refresh"**;
  +70 → 31.5 / 0.49; +130 → 58.5 / 0.91, still "Pull to refresh"; +200 → `stage="refresh"`,
  translateY 90, opacity 1, label **"Release to refresh · pull further to sync"**; +280 → 126;
  +360 → `stage="sync"`, translateY 156 (`MAX_PULL`), label **"Release to sync with school"**.
  Damping ≈0.45; thresholds `REFRESH_AT 64` / `SYNC_AT 132` damped px
  (`PullToRefresh.tsx:16-18`). Label 13 px `rgb(92,103,112)`. Returning to 0 before release
  resets `stage="idle"` and clears the label.
- Pull up at the end of the canvas, `div.pullup`: finger −40 → opacity 0, translateY −18;
  −100 → opacity 0.525, −45; −180 → opacity 1, −81, label "Pull up for History"; −260 →
  `data-ready`, −117, label **"Release to open History"**; −340 → −128 (`MAX_LIFT`).
  `.pullup__mark` is a 99 px pill, `--surface-solid` on `--line` with `box-shadow 0 6px 18px #0000001f`,
  `--ink-2`, 15 px/600; at `[data-ready]` it flips to `--accent` fill with `--surface-solid` text.
  Returning to 0 restores "Pull up for History" and `opacity 0`; the URL stays `/timetable`.
- At rest neither affordance is visible: `.ptr__group` opacity 0 with an empty label,
  `.pullup` `opacity: 0` — see [V-R10-9].

**States on the new surface** (`r10c-vis-timetable.log`): `/api/timetable` delayed 6 s → the bar
renders complete with 4 skeleton rows and **no canvas**; aborted → the bar plus the standard
danger banner and "Try again", still no canvas. The bar and the "Pull up for History" text render
in both, so the gesture label is present on a screen that has nothing to pull.

**Desktop 1280×800** keeps the card grammar: bar `[280,32,936,62]` sticky, `‹` 44×44,
`input.daynav__picker` 256×44 over `h1.daynav__date` 258×44, `›` 44×44,
`span.caption.daynav__state "Synced 3 min ago"`, `a.btn--ghost "History"` 67×36,
`button.btn--primary "Sync now"` 79×36.

**Dark boot** (`colorScheme:"dark"`, nothing stored): bar `rgb(20,23,26)`, identical geometry,
`--ink #e9edef`, `--accent #8fc2d4`; `r10c-vis-tt-dark-390x844.png`.

## 4. Per-principle FACTS (not scores)

### #3 aesthetic — rendered inconsistencies counted
1. `span.timeline__hour "20:00"` 6 px outside `.view` at 390 and 320, inside the skip-ring band [V-R10-1] *(bc3b7c9; fixed on 41a01fe)*.
2. `nav.mobile-nav` covering 22–60 px of the day canvas and the last hour label on 3 of 7 phone sizes [V-R10-2].
3. The now-line crossing hour and ghost labels by 1–7 px on 7 of 8 clock×viewport cells [V-R10-3].
4. The day heading off-screen on every non-today compact load [V-R10-4].
5. The sparse-day landing clamped to max scroll [V-R10-5].
6. `.daynav__date:has(.daynav__picker:focus-visible)` uses `outline-offset: -3px` where every other focus ring in the sheet uses `+3px`.
7. Four identical "Nothing by that name." sentences under an empty filter [V-R10-12].
8. The entity count run on to the end of the intro paragraph with no distinct treatment [V-R10-13].
9. `a.daynav__history-sr` 72×32 — the only visible focusable control below 44 px [V-R10-8].
10. Chooser row heights 48/49/49/**73**/49 from one wrapping name [V-R10-14].
11. `.post__provenance` ellipsised at 320 and 390 [V-R10-17].
12. Dangling comments 12 (r9 10) [V-R10-18].

Resolved since r9: the two disabled fills (one now), the unstyled `.react-btn:disabled`, the
12 px skip-ring radius, the 16 px empty-day gap, the missing tap-highlight suppression on
inputs/textareas, the duplicate `@media (max-height:620px)` blocks, the 1 px Reconnect scroll.
**Net: 7 of r9's 8 counted inconsistencies closed; 12 counted now, 8 of them created by the
post-`41a01fe` Timetable restyle.**

Systemic facts that hold: one font (`font-family` resolves to `"Source Sans 3 Variable"` and three
tokens, no other family anywhere in the served CSS on either build); 1 gradient (the skeleton);
10 `box-shadow` declarations across 4 recipes; 6 `backdrop-filter` rules (4 × `blur(12px)`,
2 × `blur(8px)`); 17 `color-mix()`; 14 numeric radius families + 3 asymmetric; largest mobile
type 28 px.

### #5 unobtrusive
- `document.getAnimations()` at 2.5 s idle: **0 on 44/44 cells** (11 screens × {no-preference,
  reduce} × {clock mocked to 09:30 CST *during* a lesson, real clock}) on `bc3b7c9`, and 0 on
  44/44 on `41a01fe` pinned. The single non-zero entry in one run is a **finished** `rise-in` on
  an error banner, i.e. a state animation that has already completed.
- The `/home` next-lesson wash with `temporalState:"now"` forced: `transition` computes to `all`
  (0 s) and `getAnimations()` is 0 at 2.6 s and 4.8 s. r9's 1/22 running idle animation is gone.
- `home-foot` / `home-voices` reserve 44 px / 132 px and render at 110 px / 132 px — nothing
  resolves late.
- At rest the phone Timetable exposes 5 visible controls; the two pull affordances are invisible
  until touched [V-R10-9] — quiet to the point of being unannounced.

### #7 long-lasting — trend markers rendered
Searched for and **not found**: no second type family; no gradient other than the skeleton
shimmer; no neon or saturated accent (one accent per surface, `#33667c` / `#8fc2d4`); no warm
hue outside `--danger` (1 rendered value per boot); no drop-shadow inflation (4 recipes, the
largest `0 6px 18px #0000001f`); no oversized display type on mobile (max 28 px); no icon-only
primary actions; no skeleton "shimmer" outside loading; no infinite keyframes outside the two
loading ones.
**Present, and each is an owner-recorded decision rather than a drift:** (1) glass/blur chrome —
`backdrop-filter: blur(12px)` on the rail and the mobile nav, `blur(8px)` on the modal overlay,
6 rules; (2) the floating pill nav (`border-radius 99px`, shadow, translucent) — which is what
covers the canvas in [V-R10-2]; (3) the new pill-shaped date bar with a chevron, reading as a
native iOS control; (4) gesture-only primary affordances on the Timetable [V-R10-9]. (3) and (4)
arrived in `bc3b7c9` and are recorded in the constitution's settled list in the same commit, so
they are decisions, not unattributed style.

### #8 thorough
- 42/42 mobile dialog opens conform on each build (radius, borders, padding, animation,
  flush bottom, `max-height`, `#root[inert]`, dark palette, 0 rings inside).
- 0/117 and 0/115 controls ringed at rest over 60 loads per build; 140/140 and 114/114 Tab stops
  differ from rest.
- Served CSS: 0 orphan declarations, 0 dead bytes, 0 duplicate-in-context groups, 0
  bare-element-in-state lists on both builds.
- States: 4 missing, 2 rough (§1). Compose-with-`lessonId` and Explore-under-registry-failure —
  both r9 gaps — are closed; Find mode arrived with all three of its states absent.
- Off-ladder literal spacing declarations: 2. Off-ramp `font-size` declarations: 11 (10 excluding
  admin). Both unchanged.
- The counted inconsistencies list in #3 above: 12.

### #9 environment / dark mode / reduced motion
- Idle animation running count: **0/44** on each build (see #5).
- Genuine dark boot (`colorScheme:"dark"`, nothing stored) on 6 contexts (`/home`, `/timetable`,
  `/experiences`, `/settings`, `/login`, `/nonsense`): `data-surface="night"` set at
  **86–155 ms**, FCP 192–272 ms, so the surface is correct before first paint 6/6; `theme-color`
  rewritten to `#14171a` 6/6; `--ink #e9edef`, `--accent #8fc2d4`, body `rgb(20,23,26)` 6/6;
  `localStorage` untouched 6/6. `r10c-vis-extra.log`.
- Portaled dialogs on a dark boot: `rgb(29,33,37)` / `rgb(233,237,239)` 21/21.
- `prefers-reduced-motion: reduce` at 390×844 on `/experiences`: 106 elements carry an animation
  or transition, **0 of them non-collapsed** — every duration is `1e-06s` or `0s`; scroll owner
  `scroll-behavior: auto`. `sheet-up`, `fade-in`, `settle`, `rise-in`, the skip-link transition
  and the wash all collapse.
- 6 `@keyframes` (`settle`, `rise-in`, `fade-in`, `sheet-up`, `ptr-rot`, `skeleton-shimmer`);
  the two infinite ones (`ptr-rot`, `skeleton-shimmer`) have loading-only consumers
  (`.ptr__disc--spin svg`, `.skeleton__row`); `settle .46s` has exactly 2 consumers
  (`.view`, `.login__doorway`); `sheet-up` exactly 2 (`.modal`, `.nudge`).

## 5. Known gaps

- **The audit target moved.** Five deployments landed during this pass; the compact-landing,
  contrast and edge-band runs at 03:44–03:49 hit intermediate builds and are marked superseded in
  §0-A. They were re-run pinned. No probe result cited above is from an unpinned mixed run except
  `r10-vis-live.log`, which is labelled `979a42e`.
- The `.timeline__now` × label collisions [V-R10-3] were measured with a mocked `Date`; the
  now-line's position is server-independent (client clock), but the finding is inherently
  time-of-day dependent and will read differently at other hours.
- The pull gestures were driven with CDP `Input.dispatchTouchEvent`. Every drag was returned to
  the origin before `touchEnd`, so **no release past a threshold was ever performed** — the
  committed behaviour of "Release to refresh", "Release to sync with school" and "Release to open
  History" is not measured here, only the labels, geometry and stage transitions up to the
  release point.
- Entity counts only render when `/api/experiences/stats` returns a non-zero count; the live
  account returns `{experiences:0}`, so [V-R10-13] was measured with the response fulfilled.
- The Find-mode results section was measured with `/api/experiences/search` fulfilled; the live
  corpus has one post and returns `experiences: []` for every query tried.
- Rendered-colour and dark-boot censuses were run on `bc3b7c9` only; source colour literals and
  the `tokens.css` blob were checked on both.
- Whole-frame accent-pixel counts are reported instead of an isolated edge-band figure; the
  numbers are identical to r9's on 41a01fe, so no drift is hidden by the substitution.

## 6. Probe inventory

**41a01fe (target):** `r10-vis-served.js`, `r10-vis-css.js`, `r10-vis-css2.js`,
`r10-vis-dangling.js`, `r10-vis-moves.js`, `r10-vis-new.js`, `r10-vis-new2.js`,
`r10-vis-new3.js`, `r10-vis-outline.js`, `r10-vis-dialogs.js`, `r10-vis-dialogs2.js`,
`r10-vis-typespace.js` (×4 viewports), `r10-vis-pin.js` (+ `SKIP_LANDING` re-run → `pin2.log`),
`r10-vis-contrast.js`, `r10-vis-states.js`, `r10-vis-edgeband.js`, `r10-pin.js` (pinning helper).

**bc3b7c9 (current):** `r10-pin-cur.js`, `r10-vis-served3.js`, `r10c-vis-outline.js`,
`r10c-vis-dialogs.js`, `r10c-vis-typespace.js` (×4), `r10c-vis-contrast.js`,
`r10c-vis-states.js`, `r10c-vis-states2.js`, `r10c-vis-timetable.js`, `r10c-vis-pull.js`,
`r10c-vis-overlap.js`, `r10c-vis-nowline.js`, `r10c-vis-tab.js`, `r10c-vis-extra.js`,
`r10c-vis-colours.js`.

**Intermediate (979a42e, labelled):** `r10-vis-live.js`.

Screenshots: `r10-vis-*.png` (41a01fe) and `r10c-vis-*.png` (bc3b7c9) — the device matrix
`r10c-vis-tt-<W>x<H>.png`, the pull stages `r10c-vis-ptr-*.png` / `r10c-vis-pullup-*.png`, the
now-line collisions `r10c-vis-nowline-*.png`, the four surfaces `r10c-vis-surface-*.png`, the
dark boots `r10c-vis-darkboot-*.png`, the state matrix `r10c-vis-state-*.png`.
