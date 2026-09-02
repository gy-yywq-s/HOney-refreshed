# r10 FINAL CHECK — build `daff183` (evidence only, no scores, no verdicts)

Audit: design-is (Dieter Rams), round 10. This pass re-measures **only** what the
five commits after `bc3b7c9` touched. Everything else in r10 stands as measured on
`41a01fe` / `bc3b7c9`.

## 0. Build attribution

Served bundle confirmed by `curl -s https://honey.gaelisus.com/ | grep -o 'assets/index[^"]*'`
**before** every probe in this pass and once again after the last one — it never moved:

```
assets/index-C83Nv1o2.js
assets/index-Ba_y2FrG.css
```

No `page.route` document rewrite was needed; the site stayed on `daff183` for the whole pass.

| probe | build | viewports | evidence file |
| --- | --- | --- | --- |
| `r10-final-nav.js` | daff183 | 390×844, 1280×900 | `r10-final-nav.log` |
| `r10-final-back.js` | daff183 | 390×844 | `r10-final-back.log` |
| `r10-final-hist.js` | daff183 | 390×844, 1280×900 | `r10-final-hist.log` |
| `r10-final-gestures.js` | daff183 | 390×844, 320×568 (+dark) | `r10-final-gestures.log` |
| `r10-final-css.js` | daff183 | 390×844, 320×568 (light+dark) | `r10-final-css.log` |
| `r10-final-css2.js` | daff183 | 390×844, 320×568 | `r10-final-css2.log` |
| `r10-final-last.js` | daff183 | 390×844, 320×568 | `r10-final-last.log` |
| static (served CSS/JS, tsc, sweeps) | daff183 | — | inline below |

Commits in scope — **five**, not four (`a35dc89` also lands after `bc3b7c9`):

```
a35dc89 Phones: one readable pull pill; the skip ring only on keyboard focus
719c89e A clear hierarchy: back bar, root-tab marking, tabs replace, edge swipe up
b716aba Tabs light the root ancestor; hierarchy recorded in the constitution
5749183 Constitution: the app is a hierarchy (tree in lib/navigation.ts)
daff183 Tabs are plain links: the tree decides the lit tab and aria-current
```

Safety: no post was ever shared, no report submitted, no Settings change persisted
(the one Settings dialog opened was cancelled with Escape and re-checked gone), no
reaction pressed, `POST /api/sync` intercepted and fulfilled locally in every probe
that could reach it, no repository file edited, nothing written under `apps/web/src`.

---

## 1. Findings

### 1.1 Nav truth — the tree, the lit tab, `aria-current`

**The tree** (`apps/web/src/lib/navigation.ts:21-39`), owner decision recorded at
`apps/web/src/lib/navigation.ts:1-5`:

```
/home            parent null   "Home"
/timetable       parent null   "Timetable"
/history                → /timetable         "History"
/history/lesson/:id     → /history           "Lesson"
/experiences     parent null   "Experiences"
/experiences/explore    → /experiences       "Find someone or something"
/experiences/mine       → /experiences       "Your notes & posts"
/experiences/why        → /experiences       "Why this space exists"
/experiences/compose    → /experiences       "Share an experience"
/experiences/{teacher,course,room,dish,place,food}/:id → /experiences
/settings        parent null   "Settings"
/dash                   → /settings          "Dash"
```

`rootOf()` walks to the root (`navigation.ts:77-86`); `tabIndex()` in
`apps/web/src/components/AppLayout.tsx:21-24` selects the tab by that root; the tabs
are now plain `<Link replace>` that set `className`/`aria-current` from the index
(`AppLayout.tsx:146-157`, `AppLayout.tsx:213-224`).

**[F-R10-1] Every 404 marks no tab, at both viewports — the r10 defect is gone.**
Steps: `page.goto` each path, wait 1200 ms, count `[aria-current]` and `.is-active`.

| path (390×844 and 1280×900) | `[aria-current]` | `.is-active` | rail pill | mobile pill | `document.title` |
| --- | --- | --- | --- | --- | --- |
| `/nonsense` | **0** | **0** | `data-off=true`, opacity 0 | `data-off=true` | `Page not found · HOney` |
| `/experiences/new` | **0** | **0** | off | off | `Page not found · HOney` |
| `/timetable/oops` | **0** | **0** | off | off | `Page not found · HOney` |
| `/settings/x` | **0** | **0** | off | off | `Page not found · HOney` |
| `/home/x` | **0** | **0** | off | off | `Page not found · HOney` |
| `/experiences/teacher` | **0** | **0** | off | off | `Page not found · HOney` |

**[F-R10-2] Real routes light the root ancestor, exactly as the tree says.**
At 390×844 (rail is `display:none`, mobile nav `display:grid`, so exactly one
`aria-current="page"` is exposed to AT):

| route | lit tab | carries `aria-current="page"` | `document.title` | back bar |
| --- | --- | --- | --- | --- |
| `/home` | Home | Home | `Home · HOney` | — (root) |
| `/timetable` | Timetable | Timetable | `Timetable · HOney` | — (root) |
| `/history` | **Timetable** | Timetable | `History · HOney` | ‹ Timetable |
| `/history/lesson/1335340` | **Timetable** | Timetable | `Lesson · HOney` | ‹ History |
| `/experiences` | Experiences | Experiences | `Experiences · HOney` | — (root) |
| `/experiences/explore` | Experiences | Experiences | `Find someone or something · HOney` | ‹ Experiences |
| `/experiences/compose` | Experiences | Experiences | `Share an experience · HOney` | ‹ Experiences |
| `/experiences/why` | Experiences | Experiences | `Why this space exists · HOney` | ‹ Experiences |
| `/experiences/mine` | Experiences | Experiences | `Your notes & posts · HOney` | ‹ Experiences |
| `/experiences/course/1` (unknown id) | Experiences | Experiences | `Not found · HOney` | ‹ Experiences |
| `/settings` | Settings | Settings | `Settings · HOney` | — (root) |
| `/dash` | **Settings** | Settings | `Dash · HOney` | ‹ Settings |

Every rendered route matches `rootOf()`. No route disagrees with the tree.

**[F-R10-3] NEW — at ≥961 px the Settings subtree gets no lit tab and no
`aria-current` anywhere in the accessibility tree.** `DESKTOP_TABS` has three
entries (Home/Experiences/Timetable); Settings is not one of them, so on `/settings`
and `/dash` at 1280×900 `railIndex = -1` → `.rail-pill[data-off="true"]`,
`opacity: 0` (`apps/web/src/styles/components.css:442-444`), no `.nav-item.is-active`,
and the only `aria-current="page"` in the DOM is on the `.mobile-nav` item, which is
`display: none` at that width and therefore not exposed. Measured
(`r10-final-hist.log`): `desk /settings :: railDisplay=flex, mobileNavDisplay=none,
pillOff=true, pillOpacity=0`, `railFootMarks=["|cur=null|act=false","沈高远|cur=null|act=false"]`
— the rail foot (appearance + account) carries no `aria-current` or `is-active`
either. Same on `/dash`. The constitution's "the tab of the root ancestor is lit"
therefore holds on phones but has no desktop expression for the Settings root.
Cause: `apps/web/src/components/navTabs.tsx:17` (DESKTOP_TABS) vs
`navigation.ts:37-38` (Settings/Dash roots).

**[F-R10-4] NEW (minor) — a 404 shows a back bar reading "‹ Home".** `parentOf()`
returns `{to:"/home", title:"Home"}` for any unknown route
(`apps/web/src/lib/navigation.ts:56-57`), so `/nonsense` renders `nav[aria-label="Up
one level"]` with the link "Home" while no tab is lit. The screen therefore claims
Home is one level up from an address that is not in the tree. Measured at both 390
and 1280 (`r10-final-nav.log`, `r10-final-hist.log: desk /nonsense … name="Home"`).

**[F-R10-5] An entity page for an unknown id keeps its parent's tab lit and its own
title.** `/experiences/course/1` → `document.title = "Not found · HOney"`,
`h1 = "Nothing is listed at this address."`, Experiences lit, back bar "‹ Experiences".
Distinct from the route-level 404, which lights nothing.

---

### 1.2 The back bar

Rendered in `AppLayout.tsx:184-200` as
`<nav className="pagebar" aria-label="Up one level"><Link className="pagebar__back">` with an
`aria-hidden` chevron `<svg>` and a `<span>{parent.title}</span>`. Styles at
`apps/web/src/styles/components.css` (the `── Back bar ──` block, `.pagebar` /
`.pagebar__back` / the `@media (max-width: 960px)` sticky variant).

**[F-R10-6] Present on every non-root screen, absent on every root.** 390×844,
`r10-final-back.log`:

| screen | present | accessible name | `href` | hit rect (x,y,w,h) | position |
| --- | --- | --- | --- | --- | --- |
| Explore | yes | `Experiences` | `/experiences` | 4, 4, 122, **44** | sticky, top 0, z 12 |
| Compose (plain) | yes | `Experiences` | `/experiences` | 4, 4, 122, 44 | sticky |
| Compose `?entityKey=course:1` | yes | `Course` | `/experiences/course/1` | 4, 4, 88, 44 | sticky |
| Compose `?lessonId=1335340` | yes | `Lesson` | `/history/lesson/1335340` | 4, 4, 88, 44 | sticky |
| Why | yes | `Experiences` | `/experiences` | 4, 4, 122, 44 | sticky |
| Mine | yes | `Experiences` | `/experiences` | 4, 4, 122, 44 | sticky |
| Entity | yes | `Experiences` | `/experiences` | 4, 4, 122, 44 | sticky |
| History | yes | `Timetable` | `/timetable` | 4, 4, 109, 44 | sticky |
| Lesson | yes | `History` | `/history` | 4, 4, 91, 44 | sticky |
| Dash | yes | `Settings` | `/settings` | 4, 4, 97, 44 | sticky |
| Timetable / Settings / Home | **no** | — | — | — | — |

Bar itself is 390×52 at x=0,y=0; the control is 44 px tall, so the ≥44 target is met.
At 1280×900 the bar is `position: static` and sits inside the content column at
x=272, y=44, same 44 px height (`r10-final-hist.log`).

Colour `rgb(51,102,124)` (accent) on `rgb(244,246,247)` (surface) = **5.81 : 1**.
Font size 16 px, weight 600.

**[F-R10-7] The accessible name is the parent's title only — the word "back" or "up"
appears nowhere on the control.** A screen reader hears `link "Experiences"` inside
`navigation "Up one level"`. The chevron is `aria-hidden="true"`, the link has no
`aria-label`. The landmark carries the only "up" wording.

**[F-R10-8] Back goes where the tree says, and POPs vs REPLACEs exactly as the
constitution states.** From a cold deep link (no in-app history), 390×844:

| cold load | `history.length` before | landed | `history.length` after | forward entry |
| --- | --- | --- | --- | --- |
| `/experiences/explore` | 19 | `/experiences` | 19 (unchanged → REPLACE) | none |
| `/experiences/compose?entityKey=course:1` | 21 | `/experiences/course/1` | 21 | none |
| `/history/lesson/1335340` | 23 | `/history` | 23 | none |
| `/dash` | 25 | `/settings` | 25 | none |
| `/experiences/why` (fresh) | 5 | `/experiences` | — | forward stays `/experiences` → REPLACE |

In-app, `/experiences` → click Explore (`history.length` 2 → 3) → press back bar →
lands `/experiences`, and `page.goForward()` returns to
`/experiences/explore` → the parent was the previous entry, so it **POPped**
(`r10-final-hist.log: backbar-pop-or-replace … afterForward=/experiences/explore`).
No parent/child loop was produced in any case. It never left the app.

**[F-R10-9] Tab order: the back control is the second stop, right after the skip
link.** 390×844: `/experiences/explore` → `a.skip-link`, `a.pagebar__back`,
`input.search-box`, then rows. `/history` → `a.skip-link`, `a.pagebar__back`,
`input[aria-label="Search lessons"]`, the two filters, then the nav.
Note the skip link targets `#main` and the bar lives *inside* `main > .view`, so
skipping to content lands the user one Tab before the back control, not after it.

**[F-R10-10] The back bar never coexists with the Timetable daynav.** Timetable is a
root, so it has no bar; the probe found `daynav: false` on every screen that has a
bar. No stacking of two bars anywhere.

**[F-R10-11] No route lost its way back.** On Explore, Compose and Why the removed
"Back to Experiences" buttons are gone (`backToText: 0` on all three) and each screen
has exactly one in-page back affordance — the pagebar link (`pagebar: 1`). See §1.7.

---

### 1.3 "Tabs replace"

`AppLayout.tsx:146-157` and `:213-224` render each tab as `<Link … replace>`.

**[F-R10-12] Tab switching never grows history — and browser Back therefore leaves
the app from any tab.** Fresh context, `history.length = 2` on a cold `/home`
(entry 1 is `about:blank`):

| step | `history.length` | path |
| --- | --- | --- |
| cold `/home` | 2 | `/home` |
| tap Timetable | **2** | `/timetable` |
| tap Experiences | **2** | `/experiences` |
| browser Back | — | **`about:blank`** (out of the app) |

Same behaviour in the longer session: three tab taps from `/home`, `history.length`
stayed 27 throughout, and Back went to the entry that preceded the tab sequence.
This is what the constitution amendment says ("tab switches replace history",
`docs/product/product-and-style-constitution.md`, the 2026-09-02 hierarchy clause),
so behaviour and record agree. The measurable consequence in a normal mobile
**browser** (not standalone): after any number of tab switches, the hardware/browser
Back gesture exits HOney rather than returning to the previous tab.

---

### 1.4 The left-edge swipe

`AppLayout.tsx:34-35` `EDGE_PX = 28`, `SWIPE_PX = 72`; handler at `AppLayout.tsx:57-95`
(document-level `touchstart`/`touchmove`/`touchend`/`touchcancel`, all `passive: true`).
Armed only when `clientX <= 28`, a parent exists, and the touch did not start inside
`.modal-overlay`. Fires on `touchmove` when `dx >= 72 && dx > dy * 1.5`; disarms if
`dy > 48 && dy > dx`. Calls the same `goUp()` as the back bar.

**[F-R10-13] The gesture exists on every non-root route and fires mid-drag at
dx ≈ 77 px, without release.** 390×844, CDP touch drag from x=8 → x=140 at y=500:

| route | result | fired at x |
| --- | --- | --- |
| `/experiences/explore` | → `/experiences` | 85 (dx 77) |
| `/experiences/why` | → `/experiences` | 85 |
| `/history` | → `/timetable` | 85 |
| `/home` (root) | stays `/home` — no parent, never arms | — |
| `/nonsense` (404) | → `/home` | 85 |

Thresholds confirmed by negatives (all stayed on `/experiences/explore`): start at
x=40 (outside the 28 px edge) → nothing; edge start but only 60 px travel → nothing;
edge start, diagonal to dy 200 → nothing. Edge start with exactly 72 px travel →
fires. Because it fires on `touchmove`, there is no release point, no preview and no
way to abandon the gesture once the threshold is crossed.

**[F-R10-14] There is no affordance for it at rest and no keyboard or AT
equivalent naming the gesture.** At rest on every gesture route the probe found
`0` elements matching `[class*=edge]` or `[class*=swipe]`, and `0` elements with
`aria-keyshortcuts` anywhere in the document. The visible/AT path to the same action
is the back bar link, which is present on exactly the routes where the gesture is
armed — so nothing is gesture-only, but the gesture itself is undiscoverable from
the screen.

---

### 1.5 `PullToRefresh.tsx` — the one-pill indicator

Diff (`bc3b7c9..daff183`, 43 changed lines): `.ptr__group` + `.ptr__disc` +
`.ptr__disc--spin` replaced by a single `.ptr__pill` carrying `role="status"`, the
`aria-label`, `data-stage` and the label span; the spinning `<svg>` became
`.ptr__icon` / `.ptr__icon--spin`; CSS rewrote the disc block into a pill
(`border-radius: 99px`, `--surface-solid` ground, 1 px `--line` border,
`box-shadow: 0 6px 18px rgb(0 0 0 / .12)`, `--ink-2`, `--fs-secondary`, weight 600,
`white-space: nowrap`) and added `align-items: flex-start` on `.ptr`.

**[F-R10-15] The label ladder is intact and the sync stage is still Timetable-only.**
Sampled every `touchmove` of a 320 px vertical drag from the top of the scroll owner,
released with `touchCancel` so nothing ever fired; `POST /api/sync` intercepted and
fulfilled locally (the probe log records the interception, and no request left):

| route / viewport | stages seen, in order |
| --- | --- |
| `/timetable` 390×844 | `idle` "" → `pull` "Pull to refresh" → `refresh` "Release to refresh · pull further to sync" → `sync` "Release to sync with school" |
| `/timetable` 320×568 | identical, same four |
| `/experiences` 390×844 | `idle` "" → `pull` "Pull to refresh" → `refresh` "**Release to refresh**" — stops there |
| `/experiences` 320×568 | identical, three stages |

**[F-R10-16] Pill geometry and colour.**

| stage | 390×844 rect (x,y,w,h) | 320×568 rect | opacity | ground | text | contrast |
| --- | --- | --- | --- | --- | --- | --- |
| idle | 166, 8, 58, 34 | 131, 8, 58, 34 | 0 | `rgb(251,252,252)` | `rgb(92,103,112)` | — |
| pull | 121, 22, 149, 41 | 86, 22, 149, 41 | 0.225 | same | same | 5.63 : 1 |
| refresh | 43, 73, **305**, 41 | **8**, 73, **305**, 41 | 1 | same | same | **5.63 : 1** |
| sync | 80, 141, 231, 41 | 45, 141, 231, 41 | 1 | `rgb(51,102,124)` accent | `rgb(251,252,252)` | **6.13 : 1** |

Radius 99 px, font-size 15 px at both widths. The widest label ("Release to refresh ·
pull further to sync", 305 px, `white-space: nowrap`) leaves **7 px of clearance on
each side at 320 px** — it fits, but with nothing to spare; any longer string clips.
Dark boot over the lesson cards at 390: ground `rgb(29,33,37)`, text
`rgb(166,175,181)`, border `rgba(233,237,239,0.16)` = **7.27 : 1**. The old
`.ptr__disc` / `.ptr__group` elements are gone from the DOM (count 0 at every stage).

**[F-R10-17] The pull labels are still hidden from assistive tech for the whole
gesture.** `AppLayout`'s child renders `<div className="ptr" aria-hidden={!busy}>`
(`apps/web/src/components/PullToRefresh.tsx:136`). `busy` is null while pulling, so
`aria-hidden="true"` was measured at **every** sampled stage — idle, pull, refresh and
sync — on both routes and both viewports. `role="status"` sits inside that hidden
wrapper and its `aria-label` is `null` until `busy` is set. The three-step ladder is
therefore visual-only; only the post-release "Refreshing" / "Syncing with school"
state is ever announced.

**[F-R10-18] A pull still clears the whole `apiCache`.** `apiCache.clear()` at
`apps/web/src/components/PullToRefresh.tsx:114` is untouched by this diff. Observed
effect of one released stage-1 pull on `/experiences`: a single refetch of
`/api/experiences/feed` (only the mounted hook refetches immediately); the global
clear itself is unchanged in source.

---

### 1.6 Regression spot-checks (things `components.css` +89 / `features.css` +8 could touch)

**[F-R10-19] Rest-state outline census: zero ringed elements at rest AND zero after a
plain touch — the r10 "every tap paints the spotlight" is gone.** Feed
(`/experiences`), Timetable and Settings × {390×844, 320×568} × {light, dark} = 12
combinations. Every one: `atRest = 0`, `afterTap = 0`. Cause of the fix:
`apps/web/src/styles/features.css` `.main:focus > .view` → `.main:focus-visible >
.view` and `.section-title[id]:focus` → `:focus-visible` (commit `a35dc89`).

**[F-R10-20] The skip-link ring still paints on the keyboard path, and nothing
crosses its band.** Tab → Enter on "Skip to content":

| viewport / route | first Tab | after Enter | `.view` ring | `.view` rect | intruders in the ring band |
| --- | --- | --- | --- | --- | --- |
| 390×844 `/timetable` | `a.skip-link` | `main#main.main` | `rgb(51,102,124) solid 3px`, offset 3, radius **17px** | 16, 0, 358, 764 | **none** |
| 390×844 `/experiences` | `a.skip-link` | `main#main.main` | same | 16, 16, 358, 748 | **none** |
| 320×568 `/experiences` | `a.skip-link` | `main#main.main` | same | 16, 16, 288, 570 | `nav.mobile-nav` (the fixed nav overlaps the bottom band) |

At 390×844 on `/timetable` the r10 `[V-R10-1]` intruder (the "20:00" hour label
sitting 6 px outside `.view`) no longer appears in the band: the census returned an
empty intruder list. The only remaining band overlap is the fixed `.mobile-nav` at
320×568, which sits over the ring's bottom edge by construction.

**[F-R10-21] Section anchors could not be exercised** — neither `/timetable` nor
`/experiences` renders a `.section-title[id]` at these viewports, so the
`:focus` → `:focus-visible` change on that selector is verified in source
(`features.css:1390`) but not on screen. See §3.

**[F-R10-22] NEW (reproducible 3/3) — at 320×568 on `/timetable`, the first Tab does
not reach "Skip to content".** It lands on `button.daynav__arrow[aria-label="Previous
day"]`. At 390×844 on the same route the first Tab is `a.skip-link`. The element is
not the problem: at both widths `.skip-link` is `display:block`, `visibility:visible`,
`position:fixed`, `opacity:1`, `tabIndex 0`, not `hidden`, not inside `[inert]`, rect
`[12,-80,134,48]`, and it **is** `document`'s first tabbable in DOM order; focusing it
explicitly works at both widths. At 320×568 on `/experiences` the first Tab *does*
hit it. So the miss is specific to 320 × Timetable (the one route with a
horizontally-scrolled canvas). Nothing in this build's diff touches `.skip-link`;
recorded here because it was measured on `daff183`, not attributed to it.

**[F-R10-23] The mobile sheet grammar is intact.** `[role="dialog"]/.modal`:

| dialog | viewport | `border-radius` | `animation-name` | rect | px below the sheet |
| --- | --- | --- | --- | --- | --- |
| lesson | 320×568 | `20px 20px 0px 0px` | `sheet-up` | 0, 127, 320, 441 | **0** (flush) |
| lesson | 390×844 | `20px 20px 0px 0px` | `sheet-up` | 0, 403, 390, 441 | **0** |
| Settings "Save school login" | 320×568 | `20px 20px 0px 0px` | `sheet-up` | 0, 28, 320, 540 | **0** |
| Settings "Save school login" | 390×844 | `20px 20px 0px 0px` | `sheet-up` | 0, 328, 390, 516 | **0** |

Both Settings dialogs were opened and **cancelled with Escape**; the probe re-checked
that no dialog remained and nothing was saved.

**[F-R10-24] Served-asset and toolchain checks.**

| check | result |
| --- | --- |
| `node apps/web/scripts/check-css.mjs` on the served CSS | `1 stylesheet(s) clean`, exit 0 |
| served CSS bytes | **43,506** |
| served CSS rule blocks (`{` count) | **439** |
| distinct classes in served CSS | **234** |
| served JS, brotli (`accept-encoding: br`) | **88,932 B** — under 100 KB |
| served JS, uncompressed | 285,100 B |
| `tsc --noEmit --noUnusedLocals --noUnusedParameters` (as `honey`, in `apps/web`) | exit **0**, no output |
| dangling trailing comments (r9 detector, **source** CSS) | **9** — unchanged |

The r9 detector run against the *served* file returns 0 only because the bundle is
minified to a single line; the meaningful count is the source one. The nine are all
end-of-block trailing comments: `components.css:527, 759, 918, 967`,
`features.css:84, 1282, 1388, 1410, 1416`.

**[F-R10-25] Reverse sweep — the new classes are wired, but the change left two new
orphans in opposite directions.**

| class | emitted in TSX | rule in served CSS |
| --- | --- | --- |
| `pagebar` | yes | yes |
| `pagebar__back` | yes | yes |
| `ptr__pill` | yes | yes |
| `ptr__icon` | yes | yes |
| `ptr__icon--spin` | yes | yes |
| `ptr` | yes | yes |
| `ptr__label` | **yes** | **NO** |
| `doc__footer` | **NO** | **yes** (`features.css:1190`) |
| `ptr__group`, `ptr__disc`, `ptr__disc--spin` | no | no (cleanly removed) |

- `ptr__label` — `PullToRefresh.tsx` still renders `<span className="ptr__label">`,
  but the CSS diff deleted `.ptr__label { margin:0; white-space:nowrap }` and
  `.ptr__label:empty { display:none }` without replacing them. `grep -rn ptr__label
  apps/web/src/styles/` returns nothing and the served CSS contains the string zero
  times. The pill's own `white-space: nowrap` covers the wrapping; the `:empty`
  hide is simply gone (harmless while the pill is `opacity: 0` at idle).
- `doc__footer` — `WhyPage.tsx` was the only consumer and the diff removed it, so
  `.doc__footer` at `features.css:1190` is now dead.

Full list of served classes with no `className` consumer (10):
`chip--danger chip--muted chip--ok doc__footer placeholder swatch--mist swatch--night
swatch--stone swatch--white woff2`. Of these, `chip--*` and `swatch--*` are composed
dynamically (`ThemeControls.tsx:31` `` `swatch swatch--${option.value}` ``;
`MinePage.tsx:254` `` `chip chip--${meta.tone}` ``) and `woff2` is a `src: url()`
artifact, so they are sweep false positives. The genuinely consumer-less ones are
`doc__footer` (new this build) and `placeholder` (`features.css:65`, pre-existing).

---

### 1.7 Compose / Explore / Why after the link removal

**[F-R10-26] Interactive census (390×844, counted the way r10 counted it — every
match of `a[href], button, input, select, textarea, [tabindex]:not([tabindex="-1"])`
including the display-none rail):**

| screen | r10 (`bc3b7c9`) | daff183 | delta | of which: rail / mobile nav / skip / pagebar | "Back to …" buttons |
| --- | --- | --- | --- | --- | --- |
| Compose (plain) | 18 | **19** | **+1** | 6 / 4 / 1 / 1 | **0** |
| Explore | 32 | **32** | **0** | 6 / 4 / 1 / 1 | **0** |
| Why | 12 | **12** | **0** | 6 / 4 / 1 / 1 | **0** |

Explore and Why traded their in-page "Back to Experiences" button for the pagebar
link one-for-one. Compose gained one: its two "Back to Experiences" buttons lived on
the *success* screens (`ComposePage.tsx:163-165` and `:186-188` before the diff), not
on the screen a cold `/experiences/compose` renders, so the pagebar link is a net
addition there. Every one of the three still has exactly one in-page way back.

**[F-R10-27] `[S-R10-21]` is NOT fixed — "How privacy works" is still 7 px *under*
the fixed nav, and the screen cannot be scrolled to clear it.** Compose editor at
390×844 (`/experiences/compose?entityKey=teacher:t_23348879d1b4`, a real entity;
link source `ComposePage.tsx:443`):

```
"How privacy works" rect  = [215, 733, 102, 44]   → bottom edge y = 777
.mobile-nav top           = 770
gap                       = -7 px   (coveredByNav: true)
scrollTop 0, scrollHeight 844, clientHeight 844   → the view does not scroll
```

The lower 7 px of the link's 44 px tap target sit behind the fixed nav, and scrolling
to the bottom changes nothing because there is nothing to scroll. Identical before
and after the scroll attempt. The back bar is present on this screen (`‹ Teacher`).

---

### 1.8 The stray committed log

**[F-R10-28]** `apps/web/src/r10-struct-narrowdesk.log` (780 B, 18 lines) is tracked
in the repository. `git log --oneline -- apps/web/src/r10-struct-narrowdesk.log`
returns a single commit: **`a35dc89` "Phones: one readable pull pill; the skip ring
only on keyboard focus"** — *not* `719c89e`. It is an audit probe log accidentally
staged with that commit. Left untouched by this pass.

---

## 2. r10 findings this build resolves / leaves / worsens

| r10 finding | on `daff183` | evidence |
| --- | --- | --- |
| **404 `aria-current`** — `[S-R10-5]` / `[A-R10-9]` / `[C-R10-11]`: a 404 lit a tab and marked it `aria-current` | **RESOLVED** | 0 `[aria-current]`, 0 `.is-active`, both pills `data-off="true"` on all six 404 paths at 390 and 1280 — [F-R10-1] |
| **Compose "How privacy works" under the nav** — `[S-R10-21]` | **LEAVES** (unchanged, −7 px) | link bottom 777 vs nav top 770; page does not scroll — [F-R10-27] |
| **Pull labels hidden from AT** — `[A-R10-20]` / `[C-R10-39]` | **LEAVES** | `.ptr` is `aria-hidden="true"` at every sampled stage on both routes and both viewports — [F-R10-17] |
| **Pull label ladder** — `[S-R10-27]` | **RESOLVED / holds** | full 4-stage ladder on `/timetable`, 3-stage on `/experiences`, sync stage still Timetable-only — [F-R10-15] |
| **A pull clears the whole `apiCache`** — `[W-R10-15]` | **LEAVES** | `apiCache.clear()` at `PullToRefresh.tsx:114` untouched — [F-R10-18] |
| **Dangling trailing comments (9)** | **LEAVES** (still 9) | same nine lines in `components.css` / `features.css` — [F-R10-24] |
| **Reverse sweep (4 real orphans)** | **WORSENS** (+1 dead rule, +1 unstyled class) | `.doc__footer` lost its only consumer; `ptr__label` lost its only rule — [F-R10-25] |
| **Skip ring painted on every touch** — `[V-R10-1]` family / `a35dc89` target | **RESOLVED** | 0 ringed elements at rest and after a plain tap, 12/12 combinations light+dark, 390+320 — [F-R10-19] |
| **`[V-R10-1]` hour label inside the ring band** (6 px outside `.view` on `bc3b7c9`) | **RESOLVED** | skip-ring intruder census on `/timetable` 390×844 is empty; ring radius 17 px, offset 3 px, in the gutter — [F-R10-20] |
| **Pull pill legibility on dark** (`a35dc89` target) | **RESOLVED** | one pill, label always present; 7.27 : 1 on dark, 5.63 : 1 on stone, 6.13 : 1 on the sync accent; no squashed ellipse, `.ptr__disc` gone — [F-R10-16] |

New defects this build introduces or first exposes (none of them regress a prior
r10 finding):

| new | severity of evidence | anchor |
| --- | --- | --- |
| Settings/Dash have no lit tab and no exposed `aria-current` at ≥961 px | structural / a11y | [F-R10-3] |
| A 404 renders a back bar claiming "‹ Home" | structural, minor | [F-R10-4] |
| `.doc__footer` is now a dead rule; `ptr__label` is now a rule-less class | hygiene | [F-R10-25] |
| At 320×568 on `/timetable` the first Tab misses "Skip to content" (3/3) — cause not in this diff | a11y | [F-R10-22] |
| The edge swipe fires on `touchmove` with no release point, no preview, no rest affordance | interaction | [F-R10-13], [F-R10-14] |
| Widest pull label leaves 7 px of side clearance at 320 px | visual, marginal | [F-R10-16] |

---

## 3. Known gaps in this pass

- **Section anchors.** `.section-title[id]:focus-visible` (`features.css:1390`) could
  not be exercised: neither `/timetable` nor `/experiences` renders a
  `.section-title[id]` at 390 or 320. Verified in source only — [F-R10-21].
- **Standalone-PWA insets.** All measurements were taken in a browser context with
  `--inset-top: 0`. `.pagebar`'s phone padding is
  `calc(var(--inset-top) + var(--sp-1))` and `.ptr__pill`'s margin is
  `calc(var(--inset-top) + var(--sp-2))`, so both shift down under a real status-bar
  inset; the sticky bar's interaction with a 44–59 px inset is unmeasured.
- **The busy (post-release) pull state** was measured only as network effect
  ([F-R10-18]); the `aria-hidden` flip and the `aria-label` values at `busy ===
  "sync"` are read from source (`PullToRefresh.tsx:136-141`), not observed, because
  releasing past the sync threshold would contact the school portal.
- **`history.length` cannot shrink**, so POP vs REPLACE was distinguished by whether
  a forward entry survived (`page.goForward()`), not by the counter.
- **Real touch vs CDP touch.** The edge swipe was driven by
  `Input.dispatchTouchEvent`; a real iOS Safari edge swipe is consumed by the OS
  before the page sees it, which is exactly what the code comment at
  `AppLayout.tsx:57-58` says. Standalone-mode behaviour is unverified.
- **`/experiences/course/1`** is not a real entity; the entity-page row in
  [F-R10-2] therefore describes the "unknown id" state. A real entity
  (`teacher/t_23348879d1b4`) was used for the compose-editor measurement.
- **Not re-measured** (untouched by these five commits, r10 numbers stand): copy,
  contrast outside the pill and the back link, feed/loading states, dialog focus
  traps, timetable canvas geometry, weight/friction timings.

---

## 4. Probe inventory

All scripts live in `/root/claude-work/design-audit/`, run from that directory, and
log next to themselves. All close their browsers; all intercept `POST /api/sync`
where a gesture could reach it.

| script | what it measures | log | artefacts |
| --- | --- | --- | --- |
| `r10-final-nav.js` | 404 + real-route `aria-current`/`.is-active`/pill/title, rail 1280 + mobile 390 | `r10-final-nav.log` | — |
| `r10-final-back.js` | back-bar DOM/name/geometry/position per route, tab order, cold-load back targets, in-app back, first tabs-replace pass | `r10-final-back.log` | — |
| `r10-final-hist.js` | clean `history.length` on a fresh context, POP-vs-REPLACE via `goForward`, desktop bar + rail marking, 390 nav visibility | `r10-final-hist.log` | — |
| `r10-final-gestures.js` | edge swipe on 5 routes + 4 negatives + AT equivalents; pull ladder/geometry/contrast/`aria-hidden` at 390 and 320, dark boot, post-release GETs | `r10-final-gestures.log` | `r10-final-pull-{timetable,experiences}-{390,320}.png`, `r10-final-pull-dark-390.png` |
| `r10-final-css.js` | rest-outline census (3 routes × 2 widths × 2 schemes), skip-ring keyboard path + intruder band, sheet grammar, first census pass | `r10-final-css.log` | `r10-final-skipring-*.png`, `r10-final-*-390-bottom.png` |
| `r10-final-css2.js` | r10-comparable census, Settings sheet (opened + cancelled), 320 vs 390 Timetable tab order | `r10-final-css2.log` | `r10-final-sheet-settings-{320,390}.png` |
| `r10-final-last.js` | `.skip-link` computed state at both widths, real-entity compose editor + privacy link vs nav | `r10-final-last.log` | `r10-final-compose-editor-390.png` |
| — (inline `node -e`) | 320 tab-order retest ×3 | `r10-final-taborder320.log` | — |
| — (inline `curl`/`node`) | served CSS bytes/rules/classes, `check-css.mjs`, dangling-comment detector, reverse class sweep, `tsc`, brotli JS size | — | — |

Reused from earlier r10 passes without modification: `lib.js` (credential handling —
never read, printed or copied by this pass) and `r10-struct-lib.js` (`cstPage`,
`ACTIVE`, `BASE`).
