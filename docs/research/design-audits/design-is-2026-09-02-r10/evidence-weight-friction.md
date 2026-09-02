# r10 — Weight & Friction / Performance evidence

Anchors `[W-R10-n]`. Evidence only: nothing here is scored, and no verdict is offered.
Harness `/root/claude-work/design-audit/`, probes `r10-wf-*.js` with `.log` files.
Lesson-dependent cells run in `Asia/Shanghai`; the test account's 2026-09-02 has three
lessons (09:00–10:30 IELTS-Speaking, 13:30–15:00 Edexcel Economics-U4, 16:30–18:00 Activity).
No post was published, no report submitted, one reaction tap with the POST intercepted
(`page.route` fulfil, 0 reached the server), no Settings change committed, every browser closed.

## ⚠︎ 0.0 The target moved during the pass — read this before using any number

The brief named **`41a01fe`** (`index-CJ2b0Z4x.js` / `index-DOdf_Dgc.css` / `DashPage-DVaHpjSJ.js`).
That build was live only until **03:41 UTC**. Five commits shipped to the deployed branch
while this pass ran:

| commit | UTC | served index JS | what it touched |
|---|---|---|---|
| `41a01fe` | 03:12 | `index-CJ2b0Z4x.js` | the r9 handoff (the audit target) |
| `9c3b23f` | 03:41 | `index-DpN8OXvu.js` | Timetable: native-style top bar, no captions |
| `60c8672` | 03:46 | — | Timetable bar padding, canvas fills the frame |
| `979a42e` | 03:50 | `index-Clv7bEs3.js` | canvas fills the frame, widens to early lessons |
| `bd54519` | 03:57 | — | phones: gestures replace History and Sync now |
| `bc3b7c9` | 04:00 | `index-4oNbE07m.js` | pull labels; constitution records the decisions |

Every finding below carries the **build it was measured on**. Measurements taken 03:20–03:41 UTC
are `41a01fe`; 03:50–04:00 are `979a42e`; after 04:01 are `bc3b7c9`.
`git diff 41a01fe..bc3b7c9 -- apps/web` = 542+/216− across `Modal.tsx`, `PullToHistory.tsx` (new),
`PullToRefresh.tsx`, `format.ts`, `refresh.ts`, `TimetablePage.tsx`, `components.css`,
`features.css`, `tokens.css`. On `bc3b7c9` the Timetable's `h1.schedule-header` and
`p.caption.timetable-note` **no longer exist** — the day name is now the `.daynav__date`
heading inside the bar, so every r9 geometry assertion phrased in those selectors is
untestable as written on the live app.

Two probe cells in `r10-wf-boot.log` (light/no-stored-choice, stored-garbage) landed on a
non-app document during a redeploy window and are reported as gaps, not results.

---

## 1. Verification of the r9 handoff moves — live

`✔` CONFIRMED · `◐` PARTIAL · `✘` REFUTED · `=` unchanged (relay item, no fix claimed)

| r9 item | build | result | measurement |
|---|---|---|---|
| **M5a** `.nextlesson__wash` steps without a transition; `getAnimations()` 0 during a lesson | 41a01fe | **✔** | `transition-duration: 0s` on the wash; `document.getAnimations()` = **0 in 16/16 samples over 9.6 s** with a lesson in progress; inline width steps 33.4 % → 33.5 % → 33.6 %. Under `reduce` the duration is `1e-06s`. `r10-wf-wash2.log` |
| **M5a** idle-animation census | 41a01fe | **✔** | 12 routes × 2 viewports × 2 motion prefs = **48 cells, 0 with a running animation**; 4 cells carry one *finished* `rise-in` on `/history?select=1`. `r10-wf-anim.log` |
| **M5b** reserve `home-foot` / `home-voices` so `/home` stops shifting | 41a01fe + bc3b7c9 | **◐** | CLS **0 on 60/60** clean cold cells (4 viewports × 3 routes × 5). But the reservation is on the wrong boxes — see `[W-R10-6]`: with `/api/next-lesson` delayed 2.5 s, `/home` at 320×568 scores **0.18518**, sources `SECTION.card` (the hero) + `SECTION.home-voices` + `DIV.home-foot`. Under 5-way contention `/home` 320×568 still scores 0.086 (41a01fe, 3/5 pages) and 0.064 (bc3b7c9, 1/5). On Slow 3G, `/home` 0.04574. |
| **M5c** widen `check-css.mjs` to the *class* of bug | 41a01fe→bc3b7c9 | **◐** | Now rejects all four r9 misses and both brace shapes; still misses the duplicate selector across identical `@media` blocks; introduces two false positives; one added check is dead code. `[W-R10-11]` |
| **M5d** cap the SWR map | 41a01fe | **✔** | `CACHE_MAX = 40` (`useApi.ts:11`). Behavioural proof: after **20** forward date steps (21 keys) "Back to today" renders with **0 skeleton mutations**; after **45** steps (46 keys) the same button shows **1 skeleton mutation** — the mount key was evicted. `r10-wf-swr.log` |
| **M1** Explore's directory-only retry lands | 41a01fe | **✔** | `Try again` that **fails again** and one that **succeeds** both leave `activeElement` = `DIV.focus-landing`, `data-landed` present, scroll 0 → 0 px, 2 requests each. `r10-wf-inp2.log`, `r10-wf-forced.log` |
| **M1** `reload()` is a forced cache miss (`loading=true` on a cached key) | 41a01fe | **✔** | On the successful retry the skeleton reappears: **7 skeleton nodes for ~44 ms** (frames sampled at 30 ms), then 19 rows. `r10-wf-forced.log` |
| **M2** `?date=` matches the day shown after *every* transition | 41a01fe | **✔** | 5 forward + 5 back returns to `?date=2026-09-02` with h1 "Wednesday, 2 September 2026"; mount `?date=2026-08-24`, +1, −1 → `?date=2026-08-24`; reload of the stepped URL shows the right day. (r9: frozen at the mount value.) `r10-wf-ttstep.log` |
| **M2** bare `/timetable` stays bare while showing today | 41a01fe | **✔** | mount URL `""`, +1 → `?date=2026-09-03`, −1 → `?date=2026-09-02` (not bare again). |
| **M2** the day name stays in view after a date step at compact heights | 41a01fe / bc3b7c9 | **✘** | 41a01fe: step at 360×620 scrolls to max (144→0→164) leaving `h1` at **y = −18**; 320×568 → max 216, `h1` **y = −70** (r9 was −10 / −62). bc3b7c9: `.daynav__date` at **y = −25** (360×620) and **y = −77** (320×568). The canvas is still not padded, so `scrollIntoView` clamps at max scroll. `r10-wf-ttstep.log`, `r10-wf-tt2.log` |
| **M2** a *cached* date step lands | 41a01fe / bc3b7c9 | **✘** | Stepping back to an already-seen date puts the owner at `scrollTop 0` and the block 1 at 236–420 px — no landing, both builds. The once-per-date contract is now documented in `TimetablePage.tsx:65-69`, so this is a documented exception rather than a silent one. |
| **M2** Tab 1 after a landing is the skip link | 41a01fe / bc3b7c9 | **✘** | 41a01fe 360×620 and 320×568: first Tab = `BUTTON.btn.btn--ghost.btn--small "Back to today"`. bc3b7c9 320×568: first Tab = `BUTTON.daynav__arrow "Previous day"` — the skip link is **skipped entirely** (it is Tab 1 at 390×844, where the landing does not run). `TimetablePage.tsx` focuses then blurs `.skip-link`, which moves the sequential start point *past* it. `r10-wf-ttstep.log`, `r10-wf-tabs.log` |
| **M2** `scroll-margin-top` derived from a token | 41a01fe | **✔** | `calc(var(--sp-8) * 2 + var(--sp-3))` = 44×2+12 = **100 px** — the same rendered value as the r9 literal. |
| **Relay** 1 GET per date step, cached days included | both | **=** | 41a01fe: 13 steps over 6 dates = **14 GETs**; 45 steps = **46 GETs**; 5 back-steps fire 5 more. bc3b7c9: every `+1` and every cached `−1` fires exactly 1 `/api/timetable`. |
| **Relay** discarded body re-fetched on an abandoned view | 41a01fe | **=** | Leaving 700 ms into a 2,500 ms `/api/entities` → on return **7 skeletons** and both `/api/entities` + `/api/directory` re-fired. Leaving *after* the body arrived (3,000 ms) → 0 skeletons. `r10-wf-abandon.log` |
| **Relay** 123,968 B unrequested font subsets + 1,201 B admin CSS | bc3b7c9 | **=** | 7 `@font-face`, **152,708 B** of woff2 shipped, only `latin` (28,740 B) ever requested on 15/15 routes → **123,968 B never fetched**; 11 `.admin*` rules = **1,201 B** in the student stylesheet. |
| **Relay** the SW eviction walk fetches the Dash chunk | 979a42e | **not reproduced** | With the *current* assets seeded with real bodies, install+activate issues **3 requests** (`/sw.js`, `/`, `/`) and no asset fetch; the Dash chunk survives. The r9 observation is reproduced only when the seeded Dash hash is stale. `r10-wf-sw1b.log`, `r10-wf-sw4b.log` |
| **Relay** edge rewrites `sw.js` `no-cache` → `max-age=14400` | bc3b7c9 | **=** | Origin `app.ts:107` sets `no-cache`; the edge returns `cache-control: max-age=14400`, `cf-cache-status: REVALIDATED`. |
| **Relay** PTR clears the SWR cache for every screen | bc3b7c9 | **=** | `PullToRefresh.tsx:118` `apiCache.clear()`. Behaviourally: stepping to a cached date **before** a pull = 0 skeleton mutations; **after** a pull = 1. `r10-wf-gestures.log` |
| **Preserve** SW battery green | 979a42e | **✔** | 10/10 current assets kept, 5/5 stale evicted, `honey-v2` deleted, signature restored, 0 B refetched after `stopWorker` ×3, JS-only and CSS-only mismatch evict, exact match does no work, 5 entries / **354,227 B** after 10 hard loads, `/api/` 0 entries, HTML-under-`/assets/` refused. `sw.js` md5 **`f7513f02194664efa4e96d50773ec83d`**, 4,828 B, disk = wire, cache `honey-v3` — all identical to r9. |
| **Preserve** bundle under 100 KB wire (br and zstd) | bc3b7c9 | **✔** | 89,077 br / 91,247 zstd. `[W-R10-1]` |
| **Preserve** boot theme pre-FCP | bc3b7c9 | **✔ (4/6 cells)** | 4 valid cells set `data-surface` before FCP (surface at 85.5–152.2 ms, FCP 508–892), 0 `<html>` mutations afterwards, `theme-color` rewritten. 2 cells unusable (see §0.0). |
| **Preserve** reduced motion collapses everything | 41a01fe + bc3b7c9 | **✔** | 91/91 animated elements at `1e-06s` on `/home`; `.view { animation: settle }` = `1e-06s`; `scroll-behavior` `auto` on html/body/`.main`. On bc3b7c9 all 11 new-bar and gesture elements (`daynav`, `daynav__date`, `daynav__arrow`, `ptr`, `ptr__group`, `ptr__disc`, `ptr__label`, `pullup`, `pullup__mark`, `timeline`, `lesson-block`) = `1e-06s`. |
| **Preserve** served CSS parses clean | 979a42e + bc3b7c9 | **✔** | `node scripts/check-css.mjs` exit 0 on `dist/assets` and on a curl of the served file (md5 identical both times). |

---

## 2. Required fields

### [W-R10-1] Initial JS / CSS bytes

| asset | build | raw | br (wire) | zstd (wire) | gzip (wire) |
|---|---|---|---|---|---|
| `index-CJ2b0Z4x.js` | 41a01fe | 281,214 | **87,904** | 90,236 | 86,623 |
| `index-DOdf_Dgc.css` | 41a01fe | 41,080 | 9,389 | 10,068 | 8,621 |
| `DashPage-DVaHpjSJ.js` | 41a01fe | 13,413 | 4,406 | 4,613 | 4,337 |
| `index-Clv7bEs3.js` | 979a42e | 281,500 | 88,194 | 90,201 | 86,683 |
| `index-C7z4vzMK.css` | 979a42e | 41,722 | 9,491 | 10,178 | 8,716 |
| **`index-4oNbE07m.js`** | **bc3b7c9** | **284,454** | **89,077** | **91,247** | 87,707 |
| **`index-C9l5CGbD.css`** | **bc3b7c9** | 43,020 | **9,722** | 10,460 | 8,920 |
| `DashPage-DdJ98F33.js` | bc3b7c9 | 13,413 | 4,405 | 4,611 | 4,335 |

`dist/` 671,488 B (41a01fe) → 676,668 B (bc3b7c9), 18 files. `sw.js` 4,828 B, md5 unchanged.
Growth from r9 (`eede644`, br 86,624): **+1,280 B** at 41a01fe, **+2,453 B (+2.8 %)** at bc3b7c9.
The Dash chunk is fetched on **0 of 15** student loads including the 404.

### [W-R10-2] Requests for the primary view (cold, 390×844)

41a01fe, `r10-wf-net.log` — *total / same-origin / data / wire bytes*:

| route | total | same-origin | data | wire B | data endpoints |
|---|---|---|---|---|---|
| `/home` (UTC) | 10 | 9 | 3 | 156,415 | me, next-lesson, from-my-classes |
| `/home` (Asia/Shanghai) | 12 | 11 | 3 | 157,343 | " |
| `/timetable` | 12 | 10 | 2 | 156,778 | me, timetable |
| `/experiences` | 11 | 10 | 2 | 156,610 | me, feed |
| `/experiences/explore` | 12 | 11 | 3 | 158,044 | me, entities, directory |
| entity page | **14** | 13 | **5** | 159,046 | me, directory, entities, feed, **stats** |
| `/experiences/mine` | 10 | 9 | 3 | 157,110 | me, directory, entities |
| `/experiences/compose` (plain) | **11** | 10 | **2** | 156,823 | me, **history** |
| `compose?entityKey=` | 12 | 11 | 3 | 157,944 | me, entities, directory |
| `compose?lessonId=` | 11 | 10 | 2 | 157,401 | me, history |
| `/history` | 10 | 9 | 3 | 157,526 | me, directory, history |
| `/settings` | 8 | 7 | 1 | 154,946 | me |
| `/experiences/why` | 10 | 9 | 1 | 155,772 | me |
| `/nonsense` (404) | 10 | 9 | 1 | 155,873 | me |
| **warm SPA** `/home → /experiences` | **3** | 3 | 1 | **1,796** | feed |

0 duplicate API paths on 15/15 routes; `/api/entities` ≤ 1 anywhere; exactly one font
subset requested on 15/15.
**Two counts moved against r9:** plain `/experiences/compose` **1 → 2 data requests**
(the chooser's `/api/history`, `ComposePage.tsx:100-105`), entity page **4 → 5**
(`/api/experiences/stats`, `EntityPage.tsx:53`). `/timetable` improved 14 → 12 total.

bc3b7c9 warm SPA (`r10-wf-final.log`): every route change costs **3 requests / 1 data**
(`/home → /timetable`, `/timetable → /experiences`, and warm returns), except
`→ /home` which is 4 / 2.

### [W-R10-3] Time to interactive

**Method:** TTI = the end of the last long task (≥ 50 ms) that finishes after the floor,
requiring a 5 s quiet window; the floor is `max(FCP, first primary content node in the DOM)`
(`.nextlesson` on `/home`, `.lesson-block` on `/timetable`). 6 cold loads each, 390×844,
`Asia/Shanghai`, one context per load.

| build | route | FCP med | content med | TTI med | TTI range | boots with a long task |
|---|---|---|---|---|---|---|
| bc3b7c9, host load 2.9→4.6 | `/home` | 264 ms | 359 ms | **369 ms** | 350–462 | 6/6 (10 tasks, 50–68 ms) |
| bc3b7c9, host load 2.9→4.6 | `/timetable` | 244 ms | 511 ms | **511 ms** | 371–912 | 5/6 (12 tasks, 50–161 ms) |
| 979a42e, **host load 8.1→6.0** | `/home` | 256 ms | 365 ms | 449 ms | 246–781 | 4/6 |
| 979a42e, **host load 8.1→6.0** | `/timetable` | 444 ms | 1,023 ms | 1,152 ms | 427–1,587 | 6/6 (25 tasks) |

The 4-vCPU host carried other audit browsers throughout; the 8.1-load run is reported
only to show the sensitivity. r9's figures (339 / 347 ms at load 2.4–2.7) are the closest
comparison to the bc3b7c9 row. Idle long tasks in the 20 s after settle: **0 on 12/12 boots**.

### [W-R10-4] Idle animation count

`document.getAnimations()` at 2.5 s, `Asia/Shanghai`, `/api/next-lesson` rewritten so a
lesson is in progress on `/home`:

- 41a01fe: **48 cells** (12 routes × {320×568, 390×844} × {no-preference, reduce}) →
  **0 running animations**, 4 cells with one *finished* `rise-in` on the
  `/history?select=1` success banner.
- bc3b7c9: 6 cells (`/timetable`, `/home`, `/experiences` × 2 prefs) → **0 animations at all**.
- 6 `@keyframes` total (`settle`, `rise-in`, `fade-in`, `sheet-up`, `ptr-rot`,
  `skeleton-shimmer`); the two infinite ones are loading-only. `.view` carries
  `settle .46s` / 1 iteration.

### [W-R10-5] Notifications, badges, modals, alerts, live regions on initial load

Same 48 cells (12 routes × 2 viewports × 2 prefs), 41a01fe:

- dialogs / `role=alertdialog` / `.modal`: **0/48**
- `role="alert"`: **0/48** · toasts: **0/48** · badges: **0/48** · `[aria-live]`: **0/48**
- `role="status"`: `div.ptr__disc` (empty) **48/48**; the feed's `p.sr-only` count
  ("1 experience") **4/48**; the `/history?select=1` success banner **4/48**
- `body { overflow: hidden }` on 48/48 (the shell's permanent state).

---

## 3. Findings

### [W-R10-6] `/home`'s CLS reservation is on the wrong boxes — 0.185 as soon as `/api/next-lesson` is slow
**Build** 41a01fe (the `/home` rules are byte-identical on bc3b7c9). **Viewport** 320×568 and 390×844,
`Asia/Shanghai`. **Steps** `page.route("**/api/next-lesson", delay 2500 ms)`, cold `/home`,
`PerformanceObserver({type:"layout-shift"})` with per-source attribution (`r10-wf-cls2.js`).

| box | reserved | before data | after data |
|---|---|---|---|
| `.home-head` | `min-height: auto` | 63 px | **85 px** |
| `.nextlesson` (hero) | `min-height: auto` | 110 px | **209 px** |
| `.home-voices` | `min-height: 132px` (`features.css:1341`) | 132 px | 132 px |
| `.home-foot` | `min-height: 44px` (`features.css:1177`) | 110 px | 110 px |

Measured CLS **0.18517993** in a single shift at t = 3,026 ms, sources
`["SECTION.card","SECTION.home-voices","DIV.home-foot"]`. Delaying
`/api/experiences/from-my-classes` instead gives **CLS 0** — the reserved box is the one
that never moved. The two elements the r9 move reserved are *consequences*; the causes are
the greeting line wrapping when `lastSyncedAt` arrives (`HomePage.tsx:56-58`) and the hero
card growing from a 2-line skeleton to the settled lesson (`HomePage.tsx:71-95`).
`.home-foot`'s `min-height: 44px` is a no-op — the box renders at 110 px.
Corroboration without any route interception: 5-way contention gives 0.08615 on 3/5 pages
(41a01fe) and 0.06385 on 1/5 (bc3b7c9), sources `SECTION.home-voices`; Slow 3G gives 0.04574.

### [W-R10-7] Find mode fires one server search per keystroke, uncached and undebounced
**Build** 41a01fe. **Viewport** 390×844. **Steps** `/experiences/explore`, click the filter box,
type `physics` one character at a time 120 ms apart (`r10-wf-find.js`).

- `GET /api/experiences/search?q=…` fired **6 times** — `ph, phy, phys, physi, physic, physics`.
- Clearing the box and typing the same word again fires **6 more** — no cache, no dedupe.
- Pasting the whole value in one change fires 1.
- Total response bytes for the 6 requests: 1,227 B; CLS during typing 0; 19 → 1 entity rows.

**Cause** `ExplorePage.tsx:36-40`:
```ts
const search = useApi(
  () => (searchQ ? api.search(searchQ) : Promise.resolve(null)),
  [searchQ],
);
```
No third argument, so `useApi` (`lib/useApi.ts:59-100`) takes the keyless path: no cache
entry, no `inflight` de-duplication, and no `AbortController` — superseded responses are
discarded by the `cancelled` flag but the request still completes. `searchQ` changes on
every keystroke from the second character (`:35`). Every other `useApi` call site in the
app passes a key.

### [W-R10-8] Offline, the app has no shell — the whole PWA is one error card
**Build** bc3b7c9 (mechanism present since before r9). **Viewport** 390×844. **Steps** warm the
SW (`/home`, wait, reload), then CDP `Network.emulateNetworkConditions {offline:true}`,
navigate to `/timetable`, `/experiences`, `/home` (`r10-wf-offline.js`).

The service worker does its job — the document, JS and CSS come from `honey-v3` and
`document.title` is route-correct ("Timetable · HOney"). Then:

```
{"title":"Timetable · HOney","nav":false,"rootKids":1,"html":197,
 "alerts":[],"banners":[],
 "text":"Could not reach the HOney server. Check your connection and try again. | Retry"}
```

3/3 routes: no `.mobile-nav`, no rail, no skip link, no `h1`, no landmark, no cached
timetable, `#root` innerHTML 197 characters. A pull-to-refresh offline fires 0 requests and
produces no banner and no `role=status` text.

**Cause** `components/AppLayout.tsx:62-73` — the entire shell is gated on `me`, so any
`/api/me` failure replaces the application with a `div.fullscreen-note`. The error is a
plain `p.muted`, not a `role="alert"`.
This makes r9's `[W-R9-23]` "offline shell /timetable 117 ms" true only about the document:
the shell itself never paints. (The 165 ms / 144 ms document-serve times reproduce:
`r10-wf-sw5.log`.)

### [W-R10-9] A date step still scrolls to maximum and takes the day name off screen
**Build** 41a01fe and bc3b7c9. **Viewports** 360×620, 320×568. **Steps** cold `/timetable`
(`Asia/Shanghai`), press "Next day", sample `scrollTop` every 16 ms (`r10-wf-ttstep.js`,
`r10-wf-tt2.js`).

| build | viewport | cold | after +1 step | day name after the step |
|---|---|---|---|---|
| 41a01fe | 360×620 | y 144, h1 +2 | 144→0→**164 (= max)** in 128 ms | `h1` **y = −18** |
| 41a01fe | 320×568 | y 140, h1 +6 | 140→0→**216 (= max)** in 149 ms | `h1` **y = −70** |
| bc3b7c9 | 360×620 | y 0, label +9 | y **34 (= max)** | `.daynav__date` **y = −25** |
| bc3b7c9 | 320×568 | y 0, label +9 | y **86 (= max)** | `.daynav__date` **y = −77** |
| bc3b7c9 | 390×844 / 430×932 | y 0, max 0 | no scroll possible | label +9 ✔ |

CLS 0 on every one of these steps. The landing now always targets the **first** lesson of
the day (`TimetablePage.tsx`, `visible[0]`), so the clock state no longer changes the
outcome — but on a day whose first lesson is late the block sits below the frame and
`scrollIntoView({block:"start"})` clamps at max scroll, carrying the heading out with it.
The move-2 remedy (padding the canvas by `scroll-margin-top + viewport − block height`)
is not in the CSS: the only padding added was `.timetable-screen { padding-bottom: var(--sp-2) }`
on 41a01fe, and that was removed again on 979a42e.

### [W-R10-10] The landing's skip-link reset skips the skip link
**Build** 41a01fe and bc3b7c9. **Steps** cold `/timetable`, wait for the landing, press Tab
(`r10-wf-tabs.js`, `r10-wf-ttstep.js`).

- 390×844 (no landing runs): Tab 1 = `A.skip-link "Skip to content"` ✔
- 320×568 (landing runs): Tab 1 = `BUTTON.daynav__arrow "Previous day"` — the skip link
  is never offered.
- 41a01fe at 360×620 / 320×568: Tab 1 = `BUTTON "Back to today"`.

**Cause** `TimetablePage.tsx` (landing effect): `skip?.focus({preventScroll:true}); skip?.blur();`
moves the document's sequential-focus start point *to* the skip link, so the next Tab goes
to the element after it. r9's `[A-R9-18]` (Tab 1 landing on a lesson block) is improved but
the stated success condition — "Tab 1 after the landing is the skip link" — is not met.

Also visible in the same census: the native `<input type="date">` that covers the heading
(`.daynav__picker`, `features.css:213-231`) consumes **four consecutive Tab stops** (its
day/month/year segments) at both viewports, so a keyboard user passes 4 stops on one control
before reaching the lessons.

### [W-R10-11] The widened CSS gate: four fixes, one still-open miss, two false positives, one dead check
**Build** 41a01fe → bc3b7c9 (`apps/web/scripts/check-css.mjs`). Fixtures written to
`/root/claude-work/design-audit/r10-css-fix/`, each run alone through
`node scripts/check-css.mjs <dir>`.

| fixture | r9 | r10 |
|---|---|---|
| `.card,\na:focus-visible{}` | missed | **rejected** ✔ |
| `BUTTON,\na:focus-visible{}` | missed | **rejected** ✔ |
| `input[type=text],\na:focus-visible{}` | missed | **rejected** ✔ |
| `:where(button),\na:focus-visible{}` | missed | **rejected** ✔ |
| `.a{color:red}}` (stray `}`) | missed | **rejected** (as "unbalanced braces: 1 `{` vs 2 `}`") ✔ |
| unterminated `{` at EOF | missed | **rejected** ("2 `{` vs 1 `}`") ✔ |
| same selector in two identical `@media` blocks | missed | **still missed** ✘ |
| `button,a:focus-visible{}` | rejected | rejected ✔ |
| `.btn,.btn:hover{color:red}` | **passed correctly** | **rejected — false positive** ✘ |
| `.nav a:hover,.nav a[aria-current="page"]{}` | (untested) | **rejected — false positive** ✘ |
| `.a:hover,.b:hover{} .c{}` | pass | pass ✔ |

- The duplicate-across-at-rules miss is `check-css.mjs:33`: `parse(body, f, head, new Map())`
  hands every at-rule block a **fresh** `seen` map, so two identical `@media` heads never
  compare.
- The false positives are `check-css.mjs:44-47`: *any* list member without a state
  pseudo-class beside one that has it is reported, which condemns the ordinary
  `base, base:hover` and `:hover, [aria-current]` pairs.
- `check-css.mjs:56` is dead code:
  `if (/\}\s*\}/.test(css.replace(…)) && false) report(f, "stray '}'");` — the `&& false`
  means the dedicated stray-brace check never runs. The stray brace is caught only
  incidentally by the brace-balance count on `:54-55`.
- The gate is wired into the build (`package.json:8`) and is green on `dist/assets` and on a
  curl of the served CSS (md5 identical) for both `979a42e` and `bc3b7c9`.

### [W-R10-12] The SWR cap bites only past 40 dates; a student's realistic walk is unchanged
**Build** 41a01fe. `r10-wf-swr.log`.

| walk | GETs | keys | heap Δ | per step |
|---|---|---|---|---|
| 20 forward steps | 21 | 21 | **+2,455,397 B** | 122,770 B |
| 45 forward steps | 46 | 46 | +1,375,271 B | 30,562 B |
| 60 forward steps | 61 | 61 | +1,723,037 B | 28,717 B |

The 20-step figure is r9's number to the byte (+2.46 MB), because 21 keys are under the
cap. Eviction is **insertion-ordered with refresh on write** (`useApi.ts:12-20`
deletes-then-sets, and every render revalidates and rewrites), so in practice it behaves
as least-recently-*used*; the mount date is the first evicted, confirmed by the skeleton
returning on "Back to today" after 45 steps and not after 20.

### [W-R10-13] The edge injects a third-party analytics script into every load
**Build** bc3b7c9. **Steps** cold `/home` at 390×844, every request captured by CDP
`Network` (`r10-wf-rum.js`).

```
   1732 B  GET /home
  91657 B  GET /assets/index-4oNbE07m.js
  10822 B  GET /assets/index-C9l5CGbD.css
   9718 B  GET https://static.cloudflareinsights.com/beacon.min.js/v3d52b479…
  29293 B  GET /assets/source-sans-3-latin-wght-normal-BqRLTx4X.woff2
    627 B  GET /api/me
    457 B  POST /cdn-cgi/rum?
  12087 B  GET /wordmark.png
    745 B  GET /api/next-lesson
    730 B  GET /api/experiences/from-my-classes?limit=10
  total 10 requests, 157,868 B
```

`document.scripts` shows the beacon injected as a third `<script>` after the app bundle —
it is not in the repo's `index.html`. Cost: **2 requests / 10,175 B on a cold load** (6.4 %
of the wire), plus **2 more `/cdn-cgi/rum` beacons on every SPA route change**
(`r10-wf-final.log`: every warm navigation is 3 requests, 2 of them RUM).
`/wordmark.png` (12,087 B) is fetched on a 390-wide phone although the rail that shows it
is hidden below 960 px.

### [W-R10-14] Slow 3G: the shell paints late and `/home` and `/experiences` shift
**Build** bc3b7c9 (network via CDP `Network.emulateNetworkConditions`, 400 kbps / 400 ms RTT).
`r10-wf-throttle.log`, 390×844, cold contexts with no SW.

| route | FCP | shell painted | skeletons visible | content | CLS |
|---|---|---|---|---|---|
| `/timetable` | 3,224 ms | 3,867 ms | 3,867 ms (5) | 4,355 ms | 0.00016 |
| `/experiences` | 3,152 ms | 3,684 ms | 3,684 ms (7) | 3,684 ms | **0.03194** (`DIV.feed-stream`, `P.feed-identity`, `DIV.scope-switch`, `A.btn`) |
| `/home` | 3,316 ms | 3,932 ms | 3,932 ms (6) | 4,528 ms | **0.04574** (`SECTION.home-voices`, `DIV.home-foot`) |

The shell paints before the data on 3/3 and the skeletons carry the wait. Nothing blocks on
the font (the woff2 finishes after FCP in all three). The "CLS 0" property does not survive
a slow network.

### [W-R10-15] The phone gestures (bc3b7c9): measured cost and thresholds
`r10-wf-gestures.log`, 390×844 unless stated. Touch synthesised through CDP
`Input.dispatchTouchEvent`; every pull travelled **200 px of finger = 90 damped px**,
i.e. past `REFRESH_AT` (64) and far below `SYNC_AT` (132).

- **Pull-to-refresh**: label at the release point is `"Release to refresh"` on `/home`
  and `/experiences`, `"Release to refresh · pull further to sync"` on `/timetable`.
  Requests: `/home` 2 GET, `/experiences` 1 GET, `/timetable` 1 GET. **0 POSTs on 3/3.**
  Settle 3.5 s (`MIN_SPIN_MS` 650 plus the fetch). CLS **0.00038 / 0.00038 / 0.00230**.
- **`apiCache.clear()` is global** (`PullToRefresh.tsx:118`): stepping to an already-cached
  date shows 0 skeleton mutations before a pull and 1 after it — one pull on the Timetable
  discards every screen's cached body.
- **Pull-up-for-History**: 260 px of finger (117 damped, `OPEN_AT` 110) held 500 ms opens
  `/history` in **865 ms** (320×568) and **791 ms** (390×844); CLS 0; 2 requests
  (`/api/directory`, `/api/history`); the mark reads "Release to open History" before the
  release. A short fast pull (120 px / 120 ms) correctly does **not** navigate.
  Note: at 390×844 and 430×932 the day canvas fits the frame (`scrollHeight − clientHeight = 0`),
  so `atEnd()` is true from the top and any deliberate 260 px upward drag anywhere on the
  Timetable navigates away.
- **The sync stage was reached but never released.** At 320 px of finger (144 damped) the
  label reads `"Release to sync with school"` and `data-stage="sync"`; the gesture was then
  cancelled and reset to `idle`. **No school sync was triggered by this pass.**
  From source: `SYNC_AT = 132` damped px = **293 px of finger travel**, and only on a screen
  that registered a sync handler (`syncAvailable()`).
- The desktop keeps the `History` and `Sync now` buttons; on phones `.daynav__row` computes
  `display: none`, and the Tab census confirms neither is in the tab order. The keyboard
  substitute `A.daynav__history-sr` is a Tab stop at **72 × 32 px** — below the 44 px floor,
  though it is keyboard-only.

### [W-R10-16] Interaction latency (click → the next two frames)
**Build** bc3b7c9, 390×844, `r10-wf-inp.log` / `r10-wf-inp2.log`. CLS 0 on every row.

| interaction | click → 2 frames | long tasks | focus after |
|---|---|---|---|
| nav tap `/timetable` | 257 ms | 1 (51 ms) | the tapped tab |
| nav tap `/experiences` | 256 ms | 1 (110 ms) | the tapped tab |
| nav tap `/home` | 168 ms | 0 | the tapped tab |
| date step +1 | 227 / 105 / 164 ms | 0 | `BUTTON.daynav__arrow` |
| date step −1 (cached) | 100 ms | 0 | `BUTTON.daynav__arrow` |
| lesson dialog open | 330 ms | 1 (72 ms) | `DIV.modal` |
| lesson dialog close (Esc) | 52 ms | 0 | the `BUTTON.lesson-block` opener |
| Settings "Save school login…" open / close | 165 / 42 ms | 0 | dialog / opener |
| Settings "Delete account…" open / close | 154 / 47 ms | 0 | dialog / opener |
| reaction pill (POST intercepted) | 112 ms | 0 | the pill |
| feed tab change | 95 ms | 0 | the tapped tab |
| filter box focus / type `ph` / type `ysics` / clear | 137 / 140 / 318 / 70 ms | 0 | the input |
| chooser option tap | 121 ms | 0 | `<body>` (route change) |
| "Try again" (fails again) | 183 ms | 0 | `DIV.focus-landing` |
| "Try again" (succeeds) | 83 ms | 0 | `DIV.focus-landing` |

Lesson dialog on bc3b7c9: `border-radius 20px/0`, `max-height 776.48px` (= 92 dvh),
`animation sheet-up .42s`, `#root[inert]` set on open and removed on close, `aria-modal`,
`aria-describedby="lesson-dialog-body"`, overlay `position: fixed`, CLS 0.

### [W-R10-17] Idle cost over 20 s
**Build** 41a01fe, 390×844, CDP `Performance.getMetrics` deltas (`r10-wf-idle.log`).

| screen | mutations | requests | long tasks | RecalcStyle | Layout | ScriptDuration |
|---|---|---|---|---|---|---|
| `/home` (between lessons) | 0 | 0 | 0 | 0 | 0 | 0.056 s |
| `/timetable` | 0 | 0 | 0 | 0 | 0 | 0.000 s |
| `/experiences` | 0 | 0 | 0 | 0 | 0 | 0.000 s |
| `/home` (**lesson in progress**) | **3** (all `attributes` on `.nextlesson__wash`) | 0 | 0 | **3** | **3** | 0.131 s |

`useNowTick(1000)` (`HomePage.tsx:21`, `lib/motion.tsx`) still ticks at 1 Hz — 20 React
renders in the window — but only 3 of them change the rounded wash width enough to write
the DOM, so the whole per-second machinery costs 3 style recalcs, 3 layouts and 131 ms of
script over 20 s (6.5 ms/s).

### [W-R10-18] Headers, origin vs edge
**Build** bc3b7c9.

| path | origin (`app.ts:104-109`) | edge (measured) |
|---|---|---|
| `/sw.js` | `no-cache` | **`max-age=14400`**, `cf-cache-status: REVALIDATED` |
| `/assets/*` | `public, max-age=31536000, immutable` | same, `cf-cache-status: HIT` |
| `/` | `public, max-age=0, must-revalidate` | same, `cf-cache-status: DYNAMIC`, **ETag stripped** |
| `/manifest.webmanifest` | must-revalidate | same, weak ETag kept |
| `/icon-192.png` | must-revalidate | `max-age=14400, must-revalidate` |

`If-Modified-Since` on `/` returns **304**. The `sw.js` rewrite means a worker update can be
up to 4 hours stale at the edge; the origin comment already records the rewrite.

---

## 4. Per-principle FACTS (no scores)

**#9 environmentally friendly**
- App JS **89,077 B br / 91,247 zstd / 284,454 raw** (bc3b7c9) — under 100 KB on the wire,
  +2.8 % since r9. CSS 9,722 br. Dash chunk 4,405 br, loaded on 0/15 student routes.
- Cold `/home` = **10 requests / 157,868 B**; warm SPA navigation = 3 requests / ~1,800 B.
- **123,968 B of woff2 (6 subsets) ship and are never requested**; 1,201 B of admin CSS
  ships to students.
- **10,175 B / 2 requests per cold load and 2 per SPA navigation go to a third-party
  Cloudflare RUM beacon** injected at the edge `[W-R10-13]`.
- Idle animation count **0 running on 48 + 6 cells**, including during a lesson `[W-R10-4]`.
- Idle cost over 20 s: 0 mutations / 0 requests / 0 long tasks between lessons; 3 mutations,
  3 recalcs, 3 layouts during a lesson `[W-R10-17]`.
- Dark mode honoured before FCP in 4/4 valid contexts, 0 `<html>` mutations afterwards.
- `prefers-reduced-motion` collapses **91/91** animated elements to `1e-06s`, including all
  11 new bar and gesture elements; `scroll-behavior: auto`.
- One `/api/timetable` GET per date step even when the day is cached: 46 GETs for 45 steps.
- One pull-to-refresh discards the entire SWR map for every screen.
- One `/api/experiences/search` per keystroke, repeated verbatim on a retype `[W-R10-7]`.

**#5 unobtrusive**
- 0 dialogs, 0 alerts, 0 toasts, 0 badges, 0 `aria-live` regions on initial load across
  48 cells; the only `role="status"` on a resting screen is the empty PTR disc.
- CLS 0 on 60/60 clean cold cells and 0 on every date step, dialog open, tab change and
  Find-mode toggle measured.
- CLS is **not** 0 when the network or the CPU is slow: 0.18518 with `/api/next-lesson`
  delayed, 0.086/0.064 under contention, 0.04574 on Slow 3G `[W-R10-6]`, `[W-R10-14]`.
- Every interaction measured settles within 42–330 ms of the click, with at most one
  long task `[W-R10-16]`.

**#2 useful (friction)**
- Offline the app shows **no shell and no cached data** on 3/3 routes — one error card
  `[W-R10-8]`.
- A date step at ≤ 620 px height scrolls to maximum and takes the day name off screen
  (−25 px / −77 px on bc3b7c9) `[W-R10-9]`.
- After that landing the skip link is skipped and the date input eats four Tab stops
  `[W-R10-10]`.
- Leaving a view mid-flight costs a wasted round trip and a second skeleton `[W-R10-6 relay]`.
- Plain `/experiences/compose` now costs 2 data requests instead of 1, and an entity page 5
  instead of 4 `[W-R10-2]`.
- The pull-up-for-History gesture is armed from the top of the screen whenever the day
  canvas fits the frame (390×844, 430×932) `[W-R10-15]`.
- Retries now land: both outcomes on Explore leave focus on the named region with 0 px of
  scroll `[§1]`.

**#8 thorough (SW / gate durability)**
- `sw.js` byte-identical to r9 (md5 `f7513f02194664efa4e96d50773ec83d`, 4,828 B, `honey-v3`);
  seeded battery green on every axis, 5 entries / 354,227 B after 10 hard loads, `/api/`
  never cached, HTML-under-`/assets/` refused, 0 B refetched after `stopWorker` ×3.
- The SW still trusts cache **bodies**: with 1-byte bodies seeded, 8 of 10 current assets are
  wrongly evicted (`sw.js:33-34`, unchanged since r8).
- The build gate is wired and green on dist and on the served file, but has one open miss,
  two false positives and one line of dead code `[W-R10-11]`.
- The edge still rewrites `sw.js` to `max-age=14400` `[W-R10-18]`.

---

## 5. Known gaps

1. **The audit target moved five times.** Only §1's "41a01fe" rows and §2's 41a01fe tables
   describe the build this round was commissioned against; §2's byte table, §3's
   `[W-R10-9/13/14/15/16/18]` and the TTI table describe `bc3b7c9`. Nothing here was
   measured on `9c3b23f`, `60c8672` or `bd54519`.
2. **The Timetable geometry contracts cannot be re-tested as written.** `h1.schedule-header`
   and `p.caption.timetable-note` no longer exist on the live app; the bc3b7c9 rows use
   `.daynav__date` as the day name.
3. **Boot-theme census incomplete**: 2 of 6 contexts in `r10-wf-boot.log`
   (light/no-stored-choice, stored-garbage) loaded a non-app document during a redeploy
   window and were discarded.
4. **TTI is host-load sensitive** and the 4-vCPU box carried other audit browsers
   throughout (load 2.8–8.1). Both a loaded and a quieter run are reported; neither is as
   quiet as r9's 2.4–2.7.
5. **The school-sync gesture was never released**, so its request shape and duration are
   read from `PullToRefresh.tsx` and from the label at 144 damped px, not from a fired sync.
6. **The 7-dialog sweep is partial.** Only the lesson, "Save school login" and
   "Delete account" dialogs were opened and cancelled this round; the report dialog, the
   appearance dialog and the compose nudge were not re-measured (no post or report was ever
   submitted). A "Sign out" button in Settings has no dialog and signs the session out
   immediately — pressing it once ended the harness session, which was then re-established
   from the credentials file; that is recorded here because it is a one-tap, unconfirmed,
   destructive-looking action, not because it was intended as a test.
7. **`prefers-color-scheme` × stored-surface matrix** was measured on bc3b7c9 only.
8. **Find mode's server cost** is measured as request count and response bytes, not as
   backend query time; `/api/experiences/search` latency was not isolated.

---

## 6. Probe inventory

All under `/root/claude-work/design-audit/`, each with a matching `.log`:

`r10-wf-recon.js` (served assets, lesson times, wash presence) ·
`r10-wf-wash.js` (clock-offset attempt — records that the wash is driven by the **server's**
`temporalState`, not the client clock) · `r10-wf-wash2.js` (wash census with
`/api/next-lesson` rewritten to a lesson in progress) · `r10-wf-anim.js` (48-cell idle
animation + interrupt census, reduced-motion durations, keyframe inventory) ·
`r10-wf-net.js` (15-route request inventory, warm SPA, navigation chains) ·
`r10-wf-tti.js` (TTI, two runs: `r10-wf-tti.log` at load 8.1, `r10-wf-tti2.log` at 2.9) ·
`r10-wf-cls.js` (cold CLS 4 viewports × 3 routes × 5 + contention) ·
`r10-wf-cls2.js` (CLS attribution with delayed endpoints) ·
`r10-wf-swr.js` (SWR cap, 20/45/60 steps, heap) ·
`r10-wf-ttstep.js` (Timetable URL, history, landing, cached-date step, bare `/timetable`) ·
`r10-wf-tt2.js` (bc3b7c9 Timetable: cold CLS ×3 viewports ×5, requests per step, geometry,
idle animations, reduced motion, Modal) ·
`r10-wf-find.js` (Find-mode request cost) · `r10-wf-forced.js` (`reload()` forced miss,
retry landing) · `r10-wf-abandon.js` (discarded body / re-fetch) ·
`r10-wf-inp.js` / `r10-wf-inp2.js` (interaction latency, dialogs, retry landings) ·
`r10-wf-throttle.js` (Slow 3G + offline) · `r10-wf-offline.js` (offline shell) ·
`r10-wf-gestures.js` (pull-to-refresh, `apiCache.clear` reach, pull-up-for-History, sync
stage without release) · `r10-wf-tabs.js` (Tab order on the new bar) ·
`r10-wf-idle.js` (20 s idle + `Performance.getMetrics`) · `r10-wf-boot.js` (boot theme) ·
`r10-wf-rum.js` (full wire inventory incl. the edge beacon) ·
`r10-wf-final.js` (warm SPA, `/home` CLS on bc3b7c9) ·
`r10-wf-sw1.js` / `r10-wf-sw3.js` / `r10-wf-sw4.js` / `r10-wf-sw5.js` (SW battery;
`r10-wf-sw1b.log` and `r10-wf-sw4b.log` are the valid runs, re-seeded with the current
asset hashes after the redeploy) ·
CSS-gate fixtures in `r10-css-fix/` (`f1`–`f11`), served CSS copy in `r10-served/`.
