# Structural evidence — design-is r10 (2026-09-02)

Anchor IDs `[S-R10-n]`. Evidence only; nothing scored. Every claim carries a probe log, a
measured value and, where a cause was identified, a `file:line`. Harness
`/root/claude-work/design-audit/`, probes `r10-struct-*.js` / `.log` / `.png`. All lesson
measurements in `Asia/Shanghai`; in-page today = 2026-09-02, wall clock during the run
11:36–11:59 CST (P1 09:00–10:30 had **ended** — the clock state r9 could not reach).
No post published, no report submitted, no persistent Setting changed. Every reaction POST was
intercepted and fulfilled locally by the probe, so **no reaction ever reached the server**;
every browser was closed.

---

## ⚠️ Build changed under the audit — read this before using any number

The scope pins r10 to commit **`41a01fe`** (`index-CJ2b0Z4x.js` / `index-DOdf_Dgc.css`),
confirmed by `curl` at 03:16 UTC and again at 03:19 UTC. **The live site was redeployed three
times during this pass:**

| UTC | commit | bundle | note |
|---|---|---|---|
| — | `41a01fe` | `index-CJ2b0Z4x.js` / `index-DOdf_Dgc.css` | the audited commit |
| 03:41:40 | `9c3b23f` | `index-BR8OO2yk.js` / `index-DsWpJrTw.css` | "Timetable: a native-style top bar, no captions, the canvas fits each phone" |
| ~03:50 | `60c8672`, `979a42e` | — | further Timetable work |
| 03:57:35 | `bd54519` | `index-JQdFZBZJ.js` / `index-C9l5CGbD.css` | "Phones: gestures replace the timetable's History and Sync now buttons" |

`git diff --stat 41a01fe..bd54519 -- apps/web/src apps/web/scripts` touches exactly nine files:
`Modal.tsx`, `PullToHistory.tsx` (new), `PullToRefresh.tsx`, `lib/format.ts`, `lib/refresh.ts`,
`pages/TimetablePage.tsx`, `styles/{components,features,tokens}.css`. **Everything else —
Home, History, Settings, Feed, Explore, Mine, Compose, Entity, Why, 404, Login, `useApi.ts`,
`useRetryFocus.ts`, `AppLayout.tsx`, `ExperiencePost.tsx`, `shared.tsx`, `check-css.mjs` — is
byte-identical to `41a01fe`.**

Build attribution of every measurement below (probe log mtimes, UTC):

- **On `41a01fe` (the scoped commit):** `retry` 03:22, `dialogs` 03:30, `react2` 03:33,
  `react` 03:34, `react3` 03:34, `date` 03:36, `landing` 03:37, `extra` 03:40,
  `extra2` (re-entry + cached-step sections) 03:40–03:41, and the served-CSS analysis
  (`r10-served.css`, verified byte-identity to `41a01fe`: it contains `.schedule-header` and no
  `.daynav__caret`; the immutable asset was still served at 03:43 with HTTP 200 / 41,080 B).
- **On `9c3b23f` or later (TSX unchanged since `41a01fe` outside the Timetable/PTR/Modal):**
  `static` 03:47 (source read from a `git archive 41a01fe` snapshot in the scratchpad — source
  numbers are `41a01fe`; `tsc` ran on the working tree), `census` 03:49, `new` 03:50,
  `new2` 03:51, `matrix` 03:55, `ptr` 03:57, `live9c` 03:59, `gaps`/`mine`/`mine2` 04:0x.
- Only the **Timetable rows** of `census`/`matrix`, the **PTR** probe and the whole `live9c`
  probe describe a build later than `41a01fe`. Those are labelled inline.

The Timetable — the surface carrying r9's two hardest moves — therefore has **two columns**:
`[S-R10-8]`…`[S-R10-11]` on `41a01fe`, `[S-R10-12]` on the current live build. Both are reported.

---

## 0. Verification of the r9 handoff moves — live

| # | r9 move | Verdict | Measurement | Probe |
|---|---|---|---|---|
| 1a | Every retry lands, fail-again **and** succeed, on all error surfaces | **CONFIRMED** | 12 surfaces × 2 outcomes = **24/24** land on the named `.focus-landing` region with `data-landed`, `outline: rgb(51,102,124) solid 3px`, scrollTop 0→0 | `r10-struct-retry.log` |
| 1a′ | …by pointer as well as keyboard | **CONFIRMED** | mouse click 3/3 (History, Explore-directory, Mine) land ringed | `r10-struct-gaps.log` |
| 1a″ | …on **all** error surfaces | **PARTIAL** | an **11th** surface exists and is not armed: `/api/me` failure → `activeElement=body`, `data-landed`=0, on fail **and** on success | `r10-struct-gaps.log`, `[S-R10-2]` |
| 1b | 7/7 dialogs return focus to a mounted opener on Esc / × / Cancel / overlay | **CONFIRMED** | 7 dialogs × 3 real exits = **21/21** restore the opener; the 4th exit ("Cancel") exists on only 2 of 7 dialogs (2/2 restore). Report dialog now returns to `button.react-btn--more "More options"` (r9: `<body>`) | `r10-struct-dialogs.log`, `[S-R10-3]` |
| 1c | Pending pill: second activation keeps focus + gets a response; 1 POST | **CONFIRMED (with residue)** | keyboard and real touch: **1 POST**, focus stays on the pill, `role="status"` reads "Saving your reaction…" within 150–400 ms; `pointer-events: auto`; only the tapped pill dims. Residue: the note is **never cleared** — still on screen 3.1 s and 5.8 s after the response | `r10-struct-react2/3.log`, `[S-R10-4]` |
| 1d | `?date=` names the day shown after **every** transition; bare `/timetable` stays bare | **CONFIRMED** | 15/15 transitions correct incl. Prev-back-to-mount and "Back to today"; bare `/timetable` search `""`; invalid `?date=` (4 shapes) → today; reload of 3 URLs shows the same day; `history.length` 3→3 over 5 steps. Re-verified on the current build 6/6 | `r10-struct-date.log`, `r10-struct-live9c.log`, `[S-R10-7]` |
| 1e-i | Compact landing keeps the heading in view in **both** clock states | **CONFIRMED on lesson days** | today (P1 ended) + Aug 24 × 320×568/360×620/390×620 = **6/6** h1 in view (y 2–25), note in view 6/6, block 1 y 93–98, exactly 1 `scrollIntoView` | `r10-struct-landing.log`, `[S-R10-8]` |
| 1e-ii | …and on a sparse day | **REFUTED** | 2026-08-25 (one late lesson): scrollTop == maxScroll on **3/3** compact viewports; h1 y = **−70 / −18 / −90**, note off 2/3, daynav off 3/3 | `r10-struct-landing.log`, `[S-R10-9]` |
| 1e-iii | Tab 1 after the landing is the skip link | **REFUTED** | 9/9 compact cells Tab 1 = `button.daynav__arrow "Previous day"`; the **skip link is skipped entirely**. 3/3 normal-height cells (no landing) Tab 1 = skip link | `r10-struct-landing.log`, `[S-R10-10]` |
| 1e-iv | A cached-date step lands once, like a cold load | **REFUTED** | a step onto an already-settled date fires **0** `scrollIntoView`; the owner is reset to scrollTop 0 first, so block 1 arrives at y 236/236/218 (cold: 94–99). The code comment claims "cold load, re-entry or a date step, **cached or not** — lands once" | `r10-struct-landing.log`, `r10-struct-extra2.log`, `[S-R10-11]` |
| 1e-v | A refresh never re-lands | **CONFIRMED** | `honey:refresh` on a landed day: `scrollIntoView` count unchanged, scrollTop stays 0 | `r10-struct-landing.log` |
| 1f | 404 marks no nav tab current on any path | **PARTIAL** | `is-active` 0/4 and both pills `data-off="true"` on 4/4 paths ✅, but `aria-current="page"` is still **2** on `/experiences/new`, `/timetable/oops`, `/experiences/teacher` (0 on `/nonsense`) | `r10-struct-extra.log`, `[S-R10-5]` |
| 1g-i | Explore hides its sections under a banner | **CONFIRMED** | `/api/entities` aborted **and** `/api/directory` aborted: 1 alert, 0 sections, 0 "Nothing here yet." | `r10-struct-extra.log` |
| 1g-ii | Compose `?lessonId=` has a skeleton and an error branch | **CONFIRMED** | 5 s `/api/history` delay → 5 skeleton blocks, 0 editors; abort → 1 `role=alert` inside `section.focus-landing[aria-label="Could not load"]` with a landing retry | `r10-struct-extra.log`, `r10-struct-retry.log` |
| 1h-i | `useApi.reload()` forces a miss so a cached key shows `loading` | **CONFIRMED** | Explore directory-only retry: 7 skeleton blocks appear at t+0 ms, 19 rows return at t+160 ms | `r10-struct-extra.log`, `[S-R10-6]` |
| 1h-ii | SWR cache capped at 40 | **CONFIRMED** | after 45 forward date steps, a jump back to the date visited 45 steps ago shows **5 skeleton blocks** (evicted); a date within the last 40 shows **0** | `r10-struct-gaps.log` |
| 1i | Home reserves `home-foot` / `home-voices` height (r9 CLS 0.095) | **CONFIRMED (mechanism partly wrong)** | `/home` CLS **0.00000 on 9/9 runs** (320×568, 360×620, 390×844 × 3). But `.home-foot { min-height: 44px }` vs a rendered height of **110 px** — the reservation is 66 px short; `.home-voices` 132 px == 132 px | `r10-struct-extra2.log`, `r10-struct-extra.log`, `[S-R10-16]` |
| 5 | Widened `check-css.mjs` rejects the class, not the instance | **PARTIAL + a new false positive** | rejects 6/6 required shapes (class-, uppercase-, attribute-, `:where()`-spelled dangling member; stray `}`; unterminated `{`) but still **passes a duplicate selector across two identical `@media` blocks**; and now **rejects the legal idiom `.btn,.btn:hover{}`** (r9 recorded it as correctly passing) | `r10-struct-css.log`, `[S-R10-14]` |
| — | `tsc --noEmit --noUnusedLocals --noUnusedParameters` | **CONFIRMED** | exit 0, 0 lines | `r10-struct-static.log` |
| — | Skip ring on a system radius | **CONFIRMED (source + served)** | `border-radius: 17px` in the served sheet at both ring sites (was 12px) | `r10-served.css`, `features.css:1317,1337` |
| — | `pointer-events:none` removed from the pending pill | **CONFIRMED** | computed `pointer-events: auto` on the pending pill | `r10-struct-react.log` |
| — | `scroll-margin-top` literal replaced by a token expression | **CONFIRMED, value unchanged** | `calc(var(--sp-8) * 2 + var(--sp-3))` = 44·2+12 = **100 px**, identical to the r9 literal | `features.css:360` |
| — | Two adjacent identical `@media (max-height:620px)` merged | **CONFIRMED** | one block at `features.css:767` | source |
| — | `-webkit-tap-highlight-color` extended to `input, textarea` | **CONFIRMED** | `foundations.css:63-68` `button, a, input, textarea` | source |
| — | Dangling trailing comments 10 → ≤ 6 | **REFUTED** | **9** by the before-close detector on `41a01fe` (one of them, `features.css:84`, is *new* — the comment left behind when `.nextlesson__wash`'s `transition` was deleted) | `r10-struct-static.log`, `[S-R10-15]` |

---

## 1. Required fields

### 1.1 Interactive-element census

390×844 and 320×568, `hasTouch`, Asia/Shanghai, `visible/total`. **"visible" here means
in-viewport** (`0 < top < innerHeight` and non-zero box) — a stricter rule than r9's, so only the
`total` column is comparable across rounds. Timetable rows are on the current build; every other
row's TSX is byte-identical to `41a01fe`.

| Surface | 390×844 | 320×568 | total Δ vs r9 | `activeElement` on arrival | `aria-live` | `role=status` |
|---|---|---|---|---|---|---|
| Home | 8/15 | 8/15 | = | body | 0 | 1 |
| Timetable today | 12/19 | 12/19 | −1 | body | 0 | 1 |
| Timetable 2026-08-24 | 13/20 | 13/20 | −1 | body | 0 | 1 |
| Timetable empty (08-22) | 10/17 | 10/17 | −1 | body | 0 | 2 |
| History | 7/14 | 7/14 | = | body | 0 | 1 |
| History `?select=1` | 15/39 | 10/39 | +1 | body | 0 | 2 |
| Settings | 11/25 | 8/25 | = | body | 0 | 1 |
| Feed | 14/21 | 14/21 | = | body | 0 | 2 |
| Explore | 16/32 | 11/32 | = | body | 0 | 1 |
| Explore, Find mode (`chen`) | 9/16 | — | new | `input.search-box` | 0 | 1 |
| Mine, 0 keys | 5/12 | 5/12 | = | body | 0 | 1 |
| Mine, 1 seeded key | 6/13 | — | = | body | 0 | 2 |
| Compose plain (chooser) | **11/18** | 10/18 | **+5** | body | 0 | 1 |
| Compose `?entityKey=` | 9/16 | 9/16 | = | body | 0 | 1 |
| Compose `?lessonId=` | 9/16 | — | new | body | 0 | 1 |
| Entity | 5/12 | 5/12 | = | body | 0 | 1 |
| Why | 4/12 | 4/12 | = | body | 0 | 1 |
| Login | 4/5 | — | = | body | 0 | 0 |
| 404 `/nonsense` | 5/12 | 5/12 | = | body | 0 | 1 |

`activeElement` = `body` on **18/19** arrivals (the exception is the Find-mode row, where the
probe itself focused the box). `aria-live` = **0** on every surface (r9 = 0).
Probe `r10-struct-census.log`, `r10-struct-mine.log`.
The +5 on plain Compose is the new chooser's five recent-lesson rows (`[S-R10-19]`).

### 1.2 Nesting depth

From `main#main`: first `.lesson-block` **7** (r9 6), first `article.post` **6** (=),
editor `textarea` **5** (=). Max document depth: Feed **14**, Timetable **14**, Explore 12,
Settings 12, Home 10, Compose plain 11, Entity/Mine/Why/Compose-key **9**, 404 **8**.
Exactly **1** `[data-scroll-owner]` on 19/19 surfaces × 2 widths and on 78/78 device-matrix cells.
Probe `r10-struct-census.log:1-33`, `r10-struct-matrix.log`.

### 1.3 Repeated-pattern families (source at `41a01fe`)

`"Try again"` **11** buttons + 1 `"Retry"` (`AppLayout.tsx:70`) = **12** retry controls;
`landing.arm()` call sites **11** — every "Try again" is armed, the shell "Retry" is not
(`[S-R10-2]`). `useRetryFocus<…>` call sites **8** (r9 8): `TimetablePage.tsx:58`,
`EntityPage.tsx:51`, `HistoryPage.tsx:57`, `HomePage.tsx:19`, `MinePage.tsx:60`,
`ComposePage.tsx:109`, `ExplorePage.tsx:43`, `FeedPage.tsx:32` — **8/8 now arm on the union of
every loading flag their handler reloads** (r9: 5/8). `.focus-landing` **10** (r9 9);
`<Skeleton>` **12** (r9 11); `role="alert"` **17** (r9 16); `role="status"` **9**;
`<Modal>`+`<ConfirmDialog>` **11** (r9 5 `<Modal>`); `className="page-title"` **18** (r9 16);
compose entry points **17** (r9 13). Probe `r10-struct-static.log`, `r10-struct-gaps.log`.

### 1.4 Dead props / unused imports / dead CSS

- `npx tsc --noEmit --noUnusedLocals --noUnusedParameters -p tsconfig.json` → **exit 0, 0
  lines**. Unused imports / unused locals / unused parameters = **0** (`r10-struct-static.log`).
- Served CSS (`41a01fe`, `r10-served.css`): **41,080 B**, **390 rules**, **28 at-rules**,
  **6 `@keyframes`**, **7 `@font-face`**, **225 distinct classes**, **0 orphan declarations**
  (r9: 40,932 B / 374 / 13 / 223 / 0).
- Duplicate selectors **within one context: 0** (the only hit is the 7 `@font-face` heads, which
  are legitimately repeated and which the gate skips). Duplicate whole heads across *different*
  at-rule contexts: 34 — all legitimate media-query overrides.
- Consumer-less served classes **7 raw / 0 adjusted** (r9 14/0): all 7 are composed at runtime —
  `chip--{ok,danger,muted}` (`MinePage.tsx:254`), `swatch--{stone,white,mist,night}`
  (`ThemeControls.tsx`).
- TSX→CSS reverse sweep: **7 raw / 4 real** (r9 12/5) — `login__card`, `post__dot`, `home`,
  `home-head` emit with no served rule; `swatch--`, `banner--`, `chip--` are template prefixes.
  `home-voices` left the list this round (it gained a rule).

---

## 2. Findings

### [S-R10-1] Every retry lands — 24/24, in both outcomes, by keyboard and by mouse ✅
390×844, Asia/Shanghai. For each surface the endpoint was aborted forever ("fail") or for the
cold load only ("succeed"), then "Try again" was activated with Enter.

| Surface | endpoint aborted | fail-again | succeed |
|---|---|---|---|
| Home | `/api/next-lesson` | `section.focus-landing[aria-label="Now and next"][data-landed]` | same |
| Timetable | `/api/timetable` | `div.focus-landing[aria-label="Day timeline"][data-landed]` | same |
| History | `/api/history` | `div.focus-landing[aria-label="Lessons"][data-landed]` | same |
| Feed | `/api/experiences/feed` | `div#feed-panel.feed-stream.focus-landing[data-landed]` | same |
| Explore (entities) | `/api/entities` | `div.focus-landing[aria-label="Everything listed"][data-landed]` | same |
| Explore (directory only) | `/api/directory` | **lands** (r9: `<body>`) | **lands** (r9: `<body>`) |
| Mine, 0 keys | `/api/entities` | **lands** (r9: `<body>`) | **lands** |
| Mine, 1 seeded key | `/api/entities` | **lands** | **lands** |
| Entity feed | `/api/experiences/feed` | `div.stack.focus-landing[aria-label="ChenJenny experiences"][data-landed]` | same |
| Entity registry | `/api/entities` | same region | same |
| Compose `?entityKey=` | `/api/entities` | `section.focus-landing[aria-label="Could not load"][data-landed]` | `section.compose-editor.focus-landing[aria-label="Editor"][data-landed]` |
| Compose `?lessonId=` | `/api/history` | `…[aria-label="Could not load"][data-landed]` | `…[aria-label="Editor"][data-landed]` |

All 24 cells: `outline: rgb(51,102,124) solid 3px`, exactly 1 `[data-landed]` in the document,
scrollTop 0 → 0, exactly 1 `role="alert"`. The Timetable's landing region now wraps **both**
branches (`TimetablePage.tsx:213-238` on `41a01fe`), Mine arms on `mine.loading || namesLoading`
(`MinePage.tsx:60`), Explore on `entities.loading || directory.loading` (`ExplorePage.tsx:43`),
and `reload()` forces a cache miss (`useApi.ts:62-69,107-111`). The three r9 `<body>` landings
are gone. Probes `r10-struct-retry.log`, `r10-struct-gaps.log`, `r10-struct-mine2.log`.

### [S-R10-2] NEW — an 11th error surface with no shell, no landmarks and an unarmed retry
Abort `/api/me` and every authenticated route renders `AppLayout.tsx:63-74`'s
`div.fullscreen-note`:

```
shell(.app-frame) false · skip link false · <nav> 0 · #main false · [data-scroll-owner] 0
<h1> null · role="alert" 0 · controls 1 ("Retry") · document.title "Home · HOney"
```

The retry is not wrapped in `useRetryFocus`: after a retry that **fails again** and after one
that **succeeds**, `activeElement = body` and `[data-landed]` = 0 — the exact defect r9's move 1
was written to eliminate, on the one surface the "10 error surfaces" list never enumerated.
A keyboard user who recovers here lands on `<body>` and must Tab from the top of a page whose
title still claims to be Home. Probe `r10-struct-gaps.log:1-2`; screenshots
`r10-struct-me-{fail,succeed}.png`. Cause `AppLayout.tsx:63-74`.

### [S-R10-3] Dialog focus return — 21/21 real exits restore a mounted opener ✅
7 dialogs × {Esc, ×, overlay click} at 390×844 (Appearance at 1280×800), plus Cancel on the two
`ConfirmDialog`s. Every exit leaves `activeElement` on the opener and `#root` no longer `inert`:

| Dialog | opener after Esc / × / overlay |
|---|---|
| Lesson detail | `button.lesson-block "IELTS-Speaking…"` |
| **Report** | `button.react-btn.react-btn--more "More options"` (r9: `<body>` on all four exits) |
| Save school login | `button.btn--ghost "Save school login…"` |
| Delete imported data | `button.btn--danger "Delete imported data…"` (+ Cancel) |
| Delete account | `button.btn--danger "Delete account…"` (+ Cancel) |
| Reconnect | `button.btn--ghost "Reconnect"` |
| Appearance | `button.settings-trigger "Appearance"` |

Cause of the fix: `ExperiencePost.tsx:264` focuses `moreBtnRef` **before** `setMenuOpen(false)`,
so `Modal.tsx:22` captures a live node. Only **2 of 7** dialogs offer a Cancel button; the other
five are exited by Esc, × or overlay only. Probe `r10-struct-dialogs.log` (28 cells).

### [S-R10-4] Pending pill — 1 POST, focus kept, a spoken response; the response is never withdrawn
`/api/experiences/*/react` intercepted and fulfilled locally after 3–4 s. Keyboard (Enter) and a
real CDP touch tap give the same timeline:

```
t+0     ENTER/tap 1 -> POST {"value":1}
t+128   aria-disabled="true", aria-pressed="true", opacity .7, pointer-events auto, focus = pill
t+646   ENTER/tap 2 -> NO second POST
t+800   div.post__note[role="status"] = "Saving your reaction…", focus still = pill
t+1454  ENTER/tap 3 -> still no POST
t+3000  response -> aria-disabled null, aria-pressed "false"
t+8800  div.post__note STILL reads "Saving your reaction…"
```

Only the tapped pill dims (👎 and `···` keep `opacity 1`, `aria-disabled` null). One POST for
three activations. **Residue:** nothing clears the note — `ExperiencePost.tsx:157-160` sets it and
the `finally` at `:183-186` resets `busy`/`pendingValue` but not `note`, so a stale "Saving your
reaction…" sits under a settled reaction until the next `react()` call. Probes
`r10-struct-react2.log` (keyboard), `r10-struct-react3.log` (touch), `r10-struct-react.log`.

### [S-R10-5] PARTIAL — the 404 still marks two nav tabs current for assistive technology
390×844, `41a01fe`:

| path | `aria-current` | where | `is-active` | rail pill `data-off` | mobile pill `data-off` |
|---|---|---|---|---|---|
| `/nonsense` | **0** | — | 0 | true | true |
| `/experiences/new` | **2** | `nav-item:Experiences`, `mobile-nav__item:Experiences` | 0 | true | true |
| `/timetable/oops` | **2** | `nav-item:Timetable`, `mobile-nav__item:Timetable` | 0 | true | true |
| `/experiences/teacher` | **2** | `nav-item:Experiences`, `mobile-nav__item:Experiences` | 0 | true | true |

The visual half of the fix works (`matchPath` gates `is-active` and the pill, `AppLayout.tsx:28-34,
103,152-154`), the semantic half does not: the mobile `NavLink` (`AppLayout.tsx:851-861`) passes no
`aria-current`, so React Router's default `"page"` applies whenever `isActive`; the rail's
`aria-current={undefined}` (`:806`) does not remove it either. On all four paths the h1 reads
"Page not found", the title is "Page not found · HOney", 4 landmarks, and the skip link resolves
to `#main`. Probe `r10-struct-extra.log:1-4`; screenshots `r10-struct-404_*.png`.

### [S-R10-6] `reload()` forces a miss — confirmed, and it blanks the complete listing
Explore with `/api/directory` failing on the cold load only. Pressing "Try again":

```
t+0    7 skeleton blocks, 0 entity rows   <- loading true on a cached key (the arming flag)
t+160  0 skeletons, 19 entity rows
```

This is the mechanism that fixed the Explore/Mine landings (`useApi.ts:62-69`
`forced` ref, `:68` `!forced.current`). Its cost: every retry replaces the whole 19-row listing
with a skeleton for ~160 ms, including when only the *other* endpoint failed.
Probe `r10-struct-extra.log`.

### [S-R10-7] `?date=` names the day shown after every transition ✅
390×844. `41a01fe`:

```
bare /timetable      search ""                h1 "Wednesday, 2 September 2026"   history.length 2
mount ?date=08-24    ?date=2026-08-24         h1 "Monday, 24 August 2026"        3
  Next               ?date=2026-08-25         "Tuesday, 25 August 2026"          3
  Next               ?date=2026-08-26         "Wednesday, 26 August 2026"        3
  Prev               ?date=2026-08-25         "Tuesday, 25 August 2026"          3
  Prev  (mount date) ?date=2026-08-24         "Monday, 24 August 2026"           3   <- r9 failed here
  Back to today      ?date=2026-09-02         "Wednesday, 2 September 2026"      3   <- r9 failed here
today +3             ?date=2026-09-05         "Saturday, 5 September 2026"       4
  Back to today      ?date=2026-09-02         "Wednesday, 2 September 2026"      4   <- r9 failed here
```

Reload of `?date=2026-08-24 / 08-25 / 09-06` shows that day 3/3. Invalid `?date=` —
`2026-13-45`, `banana`, `2026-02-30`, empty — all replaced by today 4/4. `history.length`
unchanged over 5 forward + 5 back steps. Cause of the fix: `TimetablePage.tsx:47`
compares against `window.location.search`. Re-verified 6/6 on the current build.
Probes `r10-struct-date.log`, `r10-struct-live9c.log:16-22`.

### [S-R10-8] Compact landing on a lesson day — CONFIRMED in the post-P1 clock state ✅
`41a01fe`, Asia/Shanghai 11:36–11:37 CST (P1 09:00–10:30 ended). Cold load, one
`scrollIntoView` per date, target = `visible[0]` (`TimetablePage.tsx:351-353`):

| viewport | date | scrollTop / max | h1 y | note y | daynav y | block 1 y | `scrollIntoView` |
|---|---|---|---|---|---|---|---|
| 320×568 | today | 144 / 216 | **+2** | +48 | −128 | **+93** | 1 |
| 320×568 | 08-24 | 141 / 216 | **+5** | +51 | −125 | **+96** | 1 |
| 360×620 | today | 140 / 164 | **+6** | +52 | −124 | **+97** | 1 |
| 360×620 | 08-24 | 141 / 164 | **+5** | +51 | −125 | **+96** | 1 |
| 390×620 | today | 121 / 236 | **+25** | +71 | −105 | **+98** | 1 |
| 390×620 | 08-24 | 124 / 236 | **+22** | +68 | −108 | **+95** | 1 |
| 390×844 | any | 0 / 98 | +146 | +192 | +16 | +219 | **0** (gated out) |

h1 in view **6/6**, note in view **6/6**, block 1 never above y = 0 **6/6**. This is r9's
[A-R9-19] clamp resolved for lesson days, by making the target always the first lesson rather
than by padding the canvas. The daynav is still parked 105–128 px above the viewport on arrival.
Probe `r10-struct-landing.log`; screenshots `r10-struct-landing-*.png`.

### [S-R10-9] REFUTED — the sparse day still clamps to maximum scroll and loses the heading
`41a01fe`, 2026-08-25 (one late lesson). The first lesson **is** the last lesson, so the request
still exceeds the owner's maximum and `scrollIntoView` clamps:

| viewport | scrollTop / max | h1 y | h1 bottom | note y | daynav y | block 1 y |
|---|---|---|---|---|---|---|
| 320×568 | **216 / 216** | **−70** | −48 (fully off) | −24 (12 px visible) | −200 | 204 |
| 360×620 | **164 / 164** | **−18** | +4 (4 px visible) | +28 | −148 | 256 |
| 390×620 | **236 / 236** | **−90** | −68 (fully off) | −44 (fully off) | −220 | 202 |

A student who opens a day with a single late lesson arrives with no day name, no note and no
stepper — the r9 defect verbatim, on the state the fix did not cover. Reproduced on the current
build (`[S-R10-12]`): h1 y = −77 / −25 / −115. Cause `TimetablePage.tsx:349-365` — the effect
scrolls to `visible[0]` unconditionally; nothing pads the canvas so the 100 px
`scroll-margin-top` (`features.css:360`) can be honoured. Probe `r10-struct-landing.log`;
screenshots `r10-struct-landing-*-20260825sparse.png`.

### [S-R10-10] REFUTED — the skip link is now *skipped*, not reached, after a compact landing
The fix at `TimetablePage.tsx:358-362` focuses `.skip-link` with `preventScroll` and blurs it, to
move Chrome's sequential-focus starting point. It works — the start point is the skip link — but
Tab then moves to the element **after** it:

| viewport | date | Tab 1 |
|---|---|---|
| 320×568 / 360×620 / 390×620 | today, 08-24, 08-25 (9 cells) | `button.daynav__arrow "‹"` (Previous day) |
| 390×844 | today, 08-24, 08-25 (3 cells) | `a.skip-link "Skip to content"` |

r9's defect (Tab 1 = a lesson block) is gone; the stated contract ("Tab 1 after the landing is
the skip link at 320×568 as at 390×844") is not met on 9/9 compact cells — the skip link is
unreachable by the first Tab on every compact-height Timetable. Reproduced 9/9 on the current
build. Probes `r10-struct-landing.log`, `r10-struct-live9c.log`.

### [S-R10-11] REFUTED — a step onto an already-seen date does not land, and the owner is reset to 0
360×620, mount `?date=2026-08-24`, `Element.prototype.scrollIntoView` monkey-patched, a scroll
listener on the owner:

```
[ 804, "scrollIntoView"]                 <- cold landing, 08-24
[2767, "MARK before step, scrollTop=141"]
[2983, "scroll -> 0"]                    <- every date change resets the owner
[3053, "scrollIntoView"]                 <- 08-25 is new: it lands
[3074, "scroll -> 164"]
[4496, "scroll -> 0"]                    <- back to 08-24 (already settled): reset, NO landing
```

Resulting geometry after the cached step (3 compact viewports): scrollTop **0**, h1 y +146,
block 1 y **236 / 236 / 218** — versus 94–99 on the cold landing of the same date. So the same
day renders in two different positions depending on whether it is the first visit.
Cause `TimetablePage.tsx:74-77`: `coldLanding` requires `!settledDates.current.has(date)`, while
the comment at `:65-69` states the landing fires on "a date step, cached or not". SPA re-entry
(leave the route and come back) **does** land (fresh `settledDates`): scrollTop 151, one extra
`scrollIntoView` — but 13 px lower than the cold load, putting **h1 at y = −5** at 360×620.
Probes `r10-struct-landing.log`, `r10-struct-extra2.log`.

### [S-R10-12] The Timetable on the build now live (`bd54519`) — same two defects
`index-JQdFZBZJ.js`, 11:58 CST. The heading is now inside the day nav (`h1` y = +9, daynav
y = 0) and the landing is gated out on more phones:

| viewport | today | 2026-08-24 | 2026-08-25 sparse | Tab 1 |
|---|---|---|---|---|
| 320×568 | st 0/38, h1 **+9** | st 16/86, h1 **−7** | st 86/86, h1 **−77** | daynav arrow |
| 360×620 | st 0/0, h1 **+9** | st 20/34, h1 **−11** | st 34/34, h1 **−25** | daynav arrow |
| 390×620 | st 0/76, h1 **+9** | st 16/124, h1 **−7** | st 124/124, h1 **−115** | daynav arrow |
| 375×667 | st 0/49, h1 +9 | st 0/97, h1 +9 | st 0/97, h1 +9 | skip link (no landing) |
| 390×844 | st 0/0, h1 +9 | st 0/0, h1 +9 | st 0/0, h1 +9 | skip link (no landing) |

The sparse-day clamp (`[S-R10-9]`) and the Tab-1 miss (`[S-R10-10]`) survive the rewrite, and
**the heading is now clipped on an ordinary 3-lesson day too** (h1 y = −7 / −11 / −7 on
2026-08-24, 3/3 compact viewports). `?date=` stays correct 6/6. Probe `r10-struct-live9c.log`;
screenshots `r10-struct-live9c-tt-*.png`.

### [S-R10-13] Device matrix — 78 cells, 13 viewports × 6 routes (current build)
Invariants, all cells: exactly **1** `[data-scroll-owner]` (78/78); `body { overflow: hidden }`
(78/78); the document itself never scrolls (`scrollHeight − clientHeight = 0`, 78/78);
**0 horizontal overflow** on both the owner and the document (78/78); `nav.mobile-nav`
`position: fixed` on every mobile cell (`static` at 1280).

Timetable vertical scroll and blank space below the canvas:

| device | vScroll | timeline h | blank below | nav top |
|---|---|---|---|---|
| iPhone SE1 320×568 | 86 | 450 | 23 | 494 |
| **iPhone SE2/8 375×667** | **97** | 560 | **−7** | 593 |
| Android narrow 360×800 | 0 | 606 | 80 | 726 |
| Pixel 412×915 | 0 | 721 | 80 | 841 |
| iPhone 13/14 Pro 390×844 | 0 | 650 | 80 | 770 |
| iPhone 15/16 Pro 393×852 | 0 | 658 | 80 | 778 |
| iPhone 17 Pro 402×874 | 0 | 680 | 80 | 800 |
| 13–16 Pro Max 430×932 | 0 | 738 | 80 | 858 |
| 16/17 Pro Max 440×956 | 0 | 762 | 80 | 882 |
| compact 320×600 | 54 | 450 | 54 | 526 |
| compact 360×620 | 34 | 450 | 72 | 546 |
| **compact 390×620** | **124** | 540 | **−16** | 546 |
| desktop 1280×800 | 76 | 656 | 34 | — |

Seven notched phones now fit with zero page scroll and 80 px of clearance below the canvas; six
viewports still scroll, and on two (375×667, 390×620) the canvas bottom is **below** the viewport
bottom. Other routes' scroll ranges: Home 0–122, Feed 0–108, Compose 0–5, Explore 636–1110,
Settings 1935–3051. Probe `r10-struct-matrix.log`.

### [S-R10-14] The widened CSS gate rejects six of the seven named shapes — and one legal idiom
`node apps/web/scripts/check-css.mjs <dir>` on synthetic files in the scratchpad (never the repo):

| shape | result |
|---|---|
| `.card,\na:focus-visible{}` (class-spelled dangling member) | **REJECTS** ✅ |
| `BUTTON,\na:focus-visible{}` | **REJECTS** ✅ |
| `input[type=text],\na:focus-visible{}` | **REJECTS** ✅ |
| `:where(button),\na:focus-visible{}` | **REJECTS** ✅ |
| `.a{color:red}}` (stray `}`) | **REJECTS** (via the brace count at `check-css.mjs:54-55`) ✅ |
| unterminated `{` at EOF | **REJECTS** ✅ |
| the same selector in two identical `@media` blocks | **PASSES — not rejected** ❌ |
| orphan declaration (control) | REJECTS ✅ |
| **`.btn,.btn:hover{}` (control that must PASS)** | **REJECTS — false positive** ❌ |

The duplicate-across-contexts miss is unchanged from r9: `check-css.mjs:33` hands every at-rule
body a fresh `Map`. The stray-`}` line at `:56` is dead code (`&& false`); the catch comes from
the global brace count instead. The new false positive means the codebase can no longer write
`.a, .a:hover { … }`, the ordinary way to group a base with its hover — the gate flags any
list member without a state pseudo beside one that has it. The gate is green on both
`dist/assets` and a curl of the served sheet. Probe `r10-struct-css.log`.

### [S-R10-15] Dangling trailing comments 9 (target was ≤ 6), one of them new
`components.css:527, 669, 828, 877`; `features.css:84, 1211, 1317, 1337, 1343` (line numbers at
`41a01fe`). `features.css:84` is new this wave: deleting `.nextlesson__wash { transition: width 1s }`
left its explanatory comment as the last thing in the block. Detector: a `*/` whose next
non-blank line is `}` or EOF. Probe `r10-struct-static.log`.

### [S-R10-16] Home's reserved heights fix the shift, but one reservation is 66 px short
`/home` CLS = **0.00000 on 9/9 cold loads** (320×568, 360×620, 390×844 × 3 runs, 3.5 s window) —
r9 measured 0.09508 at 320×568. `.home-voices { min-height: 132px }` matches its rendered
height exactly (132 px). `.home-foot { min-height: 44px }` (`features.css:1177`) is measured at a
rendered height of **110 px** at both 320×568 and 390×844, so that reservation cannot be what
holds the layout — the fix rests on `.home-voices` alone. Probes `r10-struct-extra2.log`,
`r10-struct-extra.log`.

### [S-R10-17] NEW — Find mode issues one request per keystroke, uncached, under a "filter" label
Explore, 390×844. The registry lists 19 entities and Explore renders **19/19** with no "N more"
control (rule 4f satisfied for the registry: Teachers 6/6, Courses 8/8, Places 5/5, Food 0).
Typing then behaves as follows:

```
type "chen"        -> GET /api/experiences/search?q=ch, ?q=che, ?q=chen      (3 requests)
type "mathematics" -> 10 requests: ma, mat, math, mathe, mathem, mathema,
                      mathemat, mathemati, mathematic, mathematics
```

One GET per keystroke from the second character, no debounce and **no cache key** —
`ExplorePage.tsx:37-40` calls `useApi(…, [searchQ])` with the third argument omitted, so nothing
is cached and every keystroke is a fresh round trip. The same control is named
`aria-label="Filter by name"` with placeholder "Filter by name…" and the page says "typing only
narrows the list", while it also runs a server-side search over the words of published
experiences and renders a new "Experiences that mention …" section. Probes
`r10-struct-new.log`, `r10-struct-new2.log`.

### [S-R10-18] NEW — Find-mode structure: name mismatch, Recent outside the landing
With `/api/experiences/search` fulfilled with three posts, the section renders **inside** the
landing region, after the four entity sections:

```
.focus-landing children: [Teachers, Courses, Places, Food, "Experiences that mention this"]
visible heading:  Experiences that mention “chen”
section aria-label: "Experiences that mention this"      <- accessible name ≠ visible heading
posts: 3
```

The "Recent" list (`ExplorePage.tsx:107-120`) renders **outside** `div.focus-landing`
(`:121`), so a retry landing never reaches it, and it disappears the moment a character is typed
(`!q && recent.length > 0`). Section headings carry the **filtered** count, not the total —
"Teachers 6" with no query, "Teachers 1" while filtering "chen", "Teachers 0" for "zzzzz"; with
a non-matching query all four sections read "Nothing by that name." The search box sits in no
`search` landmark. Probes `r10-struct-new.log`, `r10-struct-new2.log`; screenshots
`r10-struct-explore-{full,find,mention,recent}.png`.

### [S-R10-19] NEW — the composer chooser has no loading and no error state
Plain `/experiences/compose` renders `section[aria-label="Pick a target"]` with **5** recent
lessons (`ComposePage.tsx:102-106,332-352`), then "Pick a lesson from History" and "Find someone
or something". Requests: `/api/me` + `/api/history?limit=5&order=desc` (2). One tap on a recent
lesson reaches the editor:
`/experiences/compose?lessonId=1335340`, target "IELTS-Speaking", `textarea` present — 1 tap
instead of r9's 3 (Compose → History → Select). **But `activeElement = BODY` after that
navigation** — the same drop r9 recorded for History "Select" ([S-R9-29]), reproduced on the new
path. And the branch has no states:

| `/api/history` | card | "Your recent lessons" | rows | skeletons | alerts |
|---|---|---|---|---|---|
| healthy | ✓ | ✓ | 5 | 0 | 0 |
| delayed 5 s | ✓ | **absent** | 0 | **0** | 0 |
| aborted | ✓ | **absent** | 0 | **0** | **0** |

The five-lessons affordance simply vanishes with no skeleton, no banner and no retry — the
defect class r9 fixed on Compose-with-`?lessonId=` reproduced on the sibling the same wave added.
Probes `r10-struct-new.log`, `r10-struct-new2.log`; screenshots `r10-struct-compose-chooser.png`,
`r10-struct-chooser-historyfail.png`.

### [S-R10-20] NEW — entity descriptive counts render correctly (seeded)
`/api/experiences/stats` fulfilled; the sentence is appended to the intro paragraph
(`EntityPage.tsx:137-151`), inside no live region:

```
{experiences:18, courses:3} -> "… No single Experience is the whole picture. 18 experiences across 3 courses."
{experiences:1,  courses:1} -> "… 1 experience across 1 course."
{experiences:18, courses:0} -> "… 18 experiences."
```

Singular/plural correct 3/3; descriptive only, no ranking. On live data the test teacher has 0
experiences so the clause is correctly absent, and the empty state reads "No one has shared an
experience here yet." Opening the page writes `honey.exp.recent`
(`[{"name":"ChenJenny","path":"/experiences/teacher/t_23348879d1b4"}]`) and the entry then shows
in Explore's Recent list. Probe `r10-struct-new2.log`; screenshots `r10-struct-entity-stats-*.png`.

### [S-R10-21] NEW — a Compose link sits under the fixed nav on 7 of 13 devices
Scrolled to the bottom of `/experiences/compose?entityKey=…`, one element intersects the fixed
nav band:

```
390×844: nav [10,770,380,834]  ·  A "How privacy works" [215,733,317,777]  -> 7 px under the nav
430×932: nav [10,858,420,922]  ·  A "How privacy works" [142,821,244,865]  -> 7 px under the nav
320×568: no overlap (the page scrolls there)
```

Affected: 360×800, 390×844, 393×852, 402×874, 412×915, 430×932, 440×956 (7/13); not affected:
320×568, 375×667, 320×600, 360×620, 390×620, 1280×800. The link's 44 px tap target loses its
bottom 7 px to the nav; `elementFromPoint` at the link's top still returns the anchor, so the
control is reachable but not fully. Probes `r10-struct-matrix.log`, `r10-struct-ptr.log`;
screenshots `r10-struct-compose-nav-*.png`.

### [S-R10-22] Scroll ownership and fixed feel ✅
- **A dialog never scrolls the background.** Settings scrolled to 804 px, "Delete imported data"
  opened, then `window.scrollBy(0,300)` plus wheel events dispatched on both the owner and the
  overlay: owner `scrollTop` **804 → 804**; overlay `position: fixed`, `z-index: 50`;
  `#root[inert]` true; after Esc the owner is still at 804. Probe `r10-struct-matrix.log`.
- **One scroll owner, locked body, no double scrollbars**: 78/78 matrix cells.
- **Pull-to-refresh** (real CDP touch events, Feed): a pull starting at `scrollTop = 200` runs a
  refresh (feed GETs 1 → 2) — the gesture reaches the top mid-drag, which is what the guard
  allows (`PullToRefresh.tsx:79` `if (busyRef.current || owner.scrollTop > 0) return;` and `:90`
  `if (owner.scrollTop > 0) { reset(); return; }`); a pull from the top runs one refresh
  (2 → 3). Measured on the current build, where `PullToRefresh.tsx` has changed since `41a01fe`.
  Probe `r10-struct-ptr.log`.

---

## 3. Per-principle FACTS (no scores)

**#2 useful.**
24/24 retry landings in both outcomes across 12 error surfaces, by keyboard and by pointer
`[S-R10-1]`. 21/21 dialog exits return a mounted opener `[S-R10-3]`. A second reaction press
keeps focus and produces one POST `[S-R10-4]`. The address bar names the day shown after 15/15
transitions `[S-R10-7]`. Sharing an experience from the composer is now **1 tap** to the editor
instead of 3 `[S-R10-19]`. Against that: the `/api/me` error surface drops a keyboard user on
`<body>` in both outcomes and offers no shell to navigate from `[S-R10-2]`; the composer's new
chooser reaches `<body>` after its own navigation `[S-R10-19]`; the skip link cannot be reached
by the first Tab on any compact-height Timetable `[S-R10-10]`; and a student opening a
single-lesson day arrives with no day name, note or stepper `[S-R10-9]`.

**#4 understandable.**
`?date=` and the heading agree at every step `[S-R10-7]`. Explore hides its four sections under
its banner; Compose-with-`?lessonId=` has a skeleton and a named error region; entity counts read
"18 experiences across 3 courses" with correct singulars `[S-R10-20]`. Against that: the 404
still tells assistive technology that Experiences or Timetable is the current page on nested
paths `[S-R10-5]`; the Explore control is named "Filter by name" and also runs a server search
`[S-R10-17]`; its results section's accessible name ("Experiences that mention this") differs
from its visible heading ("Experiences that mention “chen”") `[S-R10-18]`; section counts show
the filtered number, not the total `[S-R10-18]`; the same date renders in two positions
depending on whether it is the first visit, while the source comment states the opposite
`[S-R10-11]`; and "Saving your reaction…" stays on screen after the reaction has saved
`[S-R10-4]`.

**#5 unobtrusive.**
`/home` CLS 0.00000 on 9/9 loads `[S-R10-16]`. A dialog cannot move the page behind it; one
scroll owner and a locked body on 78/78 cells; no horizontal overflow anywhere `[S-R10-22]`,
`[S-R10-13]`. A retry never scrolls (0 px on 24/24) `[S-R10-1]`. Against that: every date step
resets the scroll owner to 0 before deciding whether to land, so a cached step visibly jumps
`[S-R10-11]`; every "Try again" on Explore replaces the whole 19-row listing with a skeleton for
160 ms even when that endpoint succeeded `[S-R10-6]`; typing an 11-character query issues 10
uncached network requests `[S-R10-17]`; and on 6 of 13 devices the timetable still scrolls, on
two of them past the viewport bottom `[S-R10-13]`.

**#10 as little design as possible.**
0 orphan declarations, 0 within-context duplicate selectors, 0 consumer-less classes after
adjustment, 4 reverse-sweep classes (r9 5), `tsc` clean, 8/8 `useRetryFocus` consumers on one
arming contract, one `Modal` opener contract, one provenance map, one "Could not load" spelling.
Served CSS 41,080 B / 390 rules / 225 classes / 6 keyframes. Against that: 9 dangling comments
where ≤ 6 was asked, one of them newly created by this wave `[S-R10-15]`; two reservations added
to Home of which one is 66 px short of the box it reserves `[S-R10-16]`; a build gate that now
rejects `.btn,.btn:hover{}` `[S-R10-14]`; the Recent list rendered outside the landing region it
belongs to `[S-R10-18]`; a fifth Compose entry point added (17 total) with no loading or error
state `[S-R10-19]`.

---

## 4. Known gaps

1. **The audited build moved three times mid-round.** Every measurement is attributed above.
   The Timetable and pull-to-refresh cannot be re-measured on `41a01fe` — the live app no longer
   serves it. `[S-R10-12]` gives the current-build column for the Timetable; PTR
   `[S-R10-22]` is current-build only.
2. **`tsc`** ran against the working tree (now `bd54519`), not a `41a01fe` checkout — a clean
   node_modules build of the snapshot was out of scope. `41a01fe`'s parent `eebf055` exists
   precisely to fix a type error, so a clean result at `41a01fe` is likely but unverified.
3. **"Experiences that mention"** could only be exercised with a fulfilled
   `/api/experiences/search` body; the real corpus holds one post and returned zero matches for
   every query tried. Post ordering and load-more inside that section are unmeasured.
4. **Mine's populated feed** (`api.myExperiences`) could not be reached: the seeded sentinel key
   matches no server row, so the page renders the orphan-key line rather than experience cards.
   The `mine.error` retry branch (`MinePage.tsx:176-182`) is therefore unexercised; the
   `namesError` branch was exercised in both key states.
5. **PTR "only from the top"** could not be isolated: a downward drag that begins at
   `scrollTop = 200` reaches the top during the gesture, which the guard permits. Distinguishing
   that from a guard failure needs a synthetic gesture that never reaches the top.
6. **The `?date=` empty-value case** (`/timetable?date=`) is rewritten to `?date=<today>` while a
   bare `/timetable` stays bare — recorded, not judged.
7. Report-dialog **submit** paths, revoke/delete confirmations and any publish path were never
   exercised (hard limits). The `done` branch of the report dialog is unreachable without
   submitting.
8. The r9 **`visible`** census used a looser visibility rule than this round's in-viewport rule,
   so only the `total` column is compared across rounds `[§1.1]`.

---

## 5. Probe inventory

Scripts and logs in `/root/claude-work/design-audit/` (helper `r10-struct-lib.js`):

| probe | what it measures |
|---|---|
| `r10-struct-retry.js` / `.log` | 12 error surfaces × fail-again / succeed retry landings |
| `r10-struct-dialogs.js` / `.log` | 7 dialogs × 4 exits, focus return, `#root[inert]` |
| `r10-struct-react.js` / `.log`, `react2`, `react3` | pending pill: POST count, focus, `role=status`, keyboard + CDP touch |
| `r10-struct-date.js` / `.log` | `?date=` at every transition, invalid values, `history.length` |
| `r10-struct-landing.js` / `.log` | compact landing, 4 viewports × 3 dates, `scrollIntoView` count, Tab 1, cached steps, refresh |
| `r10-struct-extra.js` / `.log` | 404 nav truth, Explore under failure, Compose `?lessonId=` states, forced-miss reload, Home min-heights |
| `r10-struct-extra2.js` / `.log` | SPA re-entry, cached-step scroll log, SWR cap, `/home` CLS ×9 |
| `r10-struct-census.js` / `.log` | interactive census, depth, `activeElement`, live regions, 19 surfaces × 2 widths |
| `r10-struct-static.js` / `.log` | served-CSS parse, duplicates, dangling comments, class sweeps, `tsc`, families |
| `r10-struct-css.js` / `.log` | `check-css.mjs` on dist + served + 9 synthetic shapes |
| `r10-struct-new.js` / `.log`, `new2` | Find mode, Recent, entity counts, composer chooser, chooser states |
| `r10-struct-matrix.js` / `.log` | 13 viewports × 6 routes; dialog background scroll; scroll-ownership invariants |
| `r10-struct-ptr.js` / `.log` | pull-to-refresh with real touch; Compose control under the fixed nav |
| `r10-struct-gaps.js` / `.log` | `/api/me` error surface, pointer-driven retries, SWR cap A/B |
| `r10-struct-mine.js` / `.log`, `mine2` | Mine empty vs seeded branch; seeded retry landing |
| `r10-struct-live9c.js` / `.log` | Timetable landing + `?date=` on the build now live |
| `r10-served.css` | the `41a01fe` served stylesheet (41,080 B) |

Screenshots (53): `r10-struct-404_*.png`, `r10-struct-landing-{320x568,360x620,390x620,390x844}-{today,20260824,20260825sparse}.png`,
`r10-struct-live9c-tt-*.png`, `r10-struct-explore-{full,find,mention,recent,fail-entities,fail-directory}.png`,
`r10-struct-compose-{chooser,lesson-delay,lesson-abort,nav-320x568,nav-390x844,nav-430x932}.png`,
`r10-struct-chooser-historyfail.png`, `r10-struct-entity-{counts,stats-18-3,stats-1-1,stats-18-0}.png`,
`r10-struct-me-{fail,succeed}.png`, `r10-struct-mine-{empty,seeded}.png`, `r10-struct-ptr.png`.

---

## 7. Timetable on `bc3b7c9` (appended after the orchestrator's follow-up)

Served bundle `index-4oNbE07m.js` / `index-C9l5CGbD.css`, confirmed by `curl` before each probe.
`git diff --stat 41a01fe..bc3b7c9 -- apps/web/src` touches `Modal.tsx`, `PullToHistory.tsx`
(new), `PullToRefresh.tsx`, `lib/format.ts`, `lib/refresh.ts`, `pages/TimetablePage.tsx`,
`styles/{components,features,tokens}.css` — everything else is still byte-identical to
`41a01fe`, so §0–§6 stand unchanged for every non-Timetable surface. Asia/Shanghai, wall clock
12:10–12:30 CST (P1 ended). **Safety: `POST /api/sync` was intercepted and fulfilled locally by
the probe, so the school portal was never contacted; exactly one sync release was performed.**
Amended constitution read from `git show bc3b7c9 -- docs/product/product-and-style-constitution.md`.

### (a) The top bar

### [S-R10-23] Structure and geometry
`header.daynav` (was a `div`), `background rgb(244,246,247)` (opaque), `z-index 12`,
`padding-top 8px` + `var(--inset-top)`, **height 58 px on every phone** (62 px at 1280).

| viewport | `position` | bar top | bar height | h1 y |
|---|---|---|---|---|
| 320×568 | **static** | 0 | 58 | +9 |
| 360×620 | **static** | 0 | 58 | +9 |
| 390×620 | **static** | 0 | 58 | +9 |
| 375×667 | sticky | 0 | 58 | +9 |
| 390×844 | sticky | 0 | 58 | +9 |
| 430×932 | sticky | 0 | 58 | +9 |
| 1280×800 | sticky | 32 | 62 | +41 |

The date **is** the `h1`: `h1.daynav__date` holds `span.daynav__date-long`,
`span.daynav__date-short[aria-hidden]`, an `svg.daynav__caret` and
`input.daynav__picker[type=date]`. The input is `position:absolute`, `opacity:0`, and its box
covers the h1 exactly (`coversH1: true` on 7/7 viewports); `elementFromPoint` at the h1's centre
returns `INPUT.daynav__picker` on 7/7 — a tap on the heading opens the platform calendar, as the
constitution states. At ≤359 px the long span becomes sr-only
(`position:absolute; clip:rect(0,0,0,0)`, `features.css:301-306`) and the short span shows, so
the accessible name stays "Wednesday, 2 September" while the sighted label reads "Wed 2 Sept" —
no duplication (`r10-struct-h1.log`). Probe `r10-struct-bar.log`, screenshots
`r10-struct-bar-*.png`, `r10-struct-h1-*.png`.

### [S-R10-24] What the bar holds, what was removed, and what is now unreachable by sight
Six controls exist in the bar; on phones **three are visible**:

| control | 320–430 phones | 1280 desktop |
|---|---|---|
| `button "Previous day"` | visible 44×44 | visible 44×44 |
| `input.daynav__picker "Pick a date (…)"` | invisible (opacity 0) but hit-testable, 196–306×44 | same |
| `button "Next day"` | visible 44×44 | visible 44×44 |
| `a "History"` (in `.daynav__row`) | **`display:none`** (0×0) | visible 67×36 |
| `button "Sync now"` (in `.daynav__row`) | **`display:none`** (0×0) | visible 79×36 |
| `a.daynav__history-sr "History"` | 1×1, `clip:rect(0,0,0,0)` — **revealed only on `:focus-visible`** (72×32) | `display:none` |

Removed from the phone screen (all confirmed absent from the DOM/text):
`p.timetable-note` (**gone**), the "P1–P6 are the school's six lesson periods." clause
(**absent**), the "Last synced …" caption (**absent**), and every visible `.caption`
(`captions: []` on 6/6 phone cells). `span.daynav__state` still holds "Synced 11 min ago" but
lives inside the hidden `.daynav__row`, so **on phones there is no visible indication of how
fresh the timetable is** — the only surviving sync signal is the pull gesture's own label.

Reachability on phones (all visible interactive elements on `/timetable`, 6/6 phone cells):
`Previous day`, `Next day`, `Pick a date` (invisible but hit-testable), and the three
`.lesson-block`s. **No visible control reaches History; no control of any kind reaches Sync now.**
History has a keyboard path (the focus-revealed sr link, Tab stop 8 at 390×844 —
`r10-struct-taborder.log`); **Sync now has no keyboard path at all** — the two gesture handlers
are `touchstart/touchmove/touchend` only (`PullToRefresh.tsx:123-126`,
`PullToHistory.tsx:82-85`). Probe `r10-struct-bar.log`, `r10-struct-taborder.log`.

### [S-R10-25] NEW — a no-touch window narrower than 700 px loses both actions completely
`.daynav__row { display: none }` sits in `@media (max-width: 700px)`
(`features.css:253,280-281`) — a **width** query, not a pointer query — while both gestures are
touch-only. In a desktop context with `hasTouch:false`:

| window | `.daynav__row` | History visible | Sync now visible | sr link |
|---|---|---|---|---|
| 600×800 | **none** | **false** | **false** | not focused → invisible |
| 699×800 | **none** | **false** | **false** | — |
| 701×800 | flex | true | true | `display:none` |
| 900/960/1280×800 | flex | true | true | `display:none` |

A mouse user in a window ≤700 px wide (a resized browser, a split-screen tablet, a small
Chromebook) has **no way to sync the timetable** and reaches History only by tabbing to a
1×1 clipped link or by typing the URL. Probe `r10-struct-narrowdesk.log`.

### [S-R10-26] NEW — the native date input costs four consecutive Tab stops
Tab order on `/timetable`, 390×844 (and identically at 320×568, offset by the skip link):

```
1. a.skip-link "Skip to content" [134x48]
2. button.daynav__arrow "Previous day" [44x44]
3. input.daynav__picker "Pick a date (Wednesday, 2 …)" [266x44]
4. input.daynav__picker  (same element)
5. input.daynav__picker  (same element)
6. input.daynav__picker  (same element)
7. button.daynav__arrow "Next day" [44x44]
8. a.daynav__history-sr "History" [72x32]        <- revealed by focus
9-11. button.lesson-block ×3
12. a.mobile-nav__item "Home"
```

`<input type="date">` exposes its day / month / year segments as separate sequential-focus
positions, so crossing the heading takes **four** presses. The r8/r9 daynav comment
("One visible affordance, one Tab stop") no longer describes the built screen. The
focus-revealed History link measures **72×32** — below the app's 44 px control floor, though it
is keyboard-only. Probe `r10-struct-taborder.log`.

### (b) The two gestures

### [S-R10-27] Pull-to-refresh — the labels do read in order
Thresholds `REFRESH_AT = 64`, `SYNC_AT = 132` damped px, damping **0.45**
(`PullToRefresh.tsx:15-16,95`), so a finger must travel **142 px** to reach "refresh" and
**293 px** to reach "sync". Measured with real CDP touch events at 390×844, sampling the label
every 20 px of finger travel:

| finger px | damped px | label |
|---|---|---|
| 0–20 | 0–9 | `""` |
| 40–140 | 18–63 | **"Pull to refresh"** |
| 160–280 | 72–126 | **"Release to refresh · pull further to sync"** |
| 300–340 | 135–153 | **"Release to sync with school"** |

`ownerScrollTop` stayed **0 at every sample** — the pull never scrolls the owner. Releases:

| release at | label after release | network |
|---|---|---|
| 27 damped (cancel) | none ever shown | **0 requests** |
| 72 damped (refresh) | "Refreshing…" | `GET /api/timetable?date=2026-09-02` — **no `POST /api/sync`** |
| 153 damped (sync) | "Syncing with school…" | **exactly one** `POST /api/sync` (intercepted) + `GET /api/timetable` |

The indicator resets to `opacity 0` / empty label after `MIN_SPIN_MS = 650`. The second stage
appears only when a sync handler is registered (`syncAvailable()`, `refresh.ts:27`), which the
Timetable does via `useSyncHandler` (`TimetablePage.tsx:103-106`). Probe
`r10-struct-gestures.log`; screenshot `r10-struct-ptr-sync.png`.

### [S-R10-28] Pull-up for History — the three guards all hold
`SHOW_AT 24`, `OPEN_AT 110` damped, `MIN_MS 220`, damping 0.45
(`PullToHistory.tsx:13-17`) → **244 px of finger** and a gesture longer than a flick.

| case | measured | result |
|---|---|---|
| finger 160 px (72 damped), slow | label stays "Pull up for History", `data-ready` absent, `opacity 0` | **no navigation**, path `/timetable` |
| finger 260 px (117 damped), >220 ms | label flips to **"Release to open History"**, `data-ready` set, mark lifted `translateY(-117px)`, `opacity 1` | **navigates to `/history`** |
| finger 260 px as a **flick** (<220 ms) | label reached "Release to open History" | **no navigation** — path stays `/timetable` |
| owner **not** at its end (scrollTop 0 of max 86) | the drag scrolls the owner to 86 normally | **no navigation** |

`ownerScrollTop` unchanged (0) throughout the armed cases; the mark is `aria-hidden="true"` and
carries no focusable node, so the gesture has no keyboard or AT equivalent. Note that on the
phones where the canvas fits (`vScroll = 0`, 7/13 devices) `atEnd()` is true **at scrollTop 0**,
so at rest the same finger position arms pull-down-to-refresh and pull-up-for-History with no
visible affordance for either. Desktop keeps both buttons and mounts `.ptr` / `.pullup` inertly
(touch-only listeners). Probe `r10-struct-gestures.log`; screenshots `r10-struct-pullup-*.png`.

### (c) Canvas fit vs the amended constitution

### [S-R10-29] The floor and the fit hold as amended; six viewports still scroll
Amended decision (`bc3b7c9`, constitution §2): "the canvas fills the phone's frame and never
compresses below 560 px (desktop 656 px). Every notched iPhone in standalone mode fits with zero
page scroll; taller phones get a taller canvas. Compact heights degrade by documented notches
(540 px, 450 px on SE-class widths)."

| device | computed `min-height` | rendered height | blank below | gap to nav | page scroll |
|---|---|---|---|---|---|
| iPhone SE1 320×568 | 450 (documented notch) | 450 | 52 | **−22** | 38 |
| iPhone SE2/8 375×667 | 560 | 560 | 41 | **−33** | 49 |
| Android narrow 360×800 | 560 | 654 | 80 | +6 | **0** |
| Pixel 412×915 | 560 | 769 | 80 | +6 | **0** |
| iPhone 13/14 Pro 390×844 | 560 | 698 | 80 | +6 | **0** |
| iPhone 15/16 Pro 393×852 | 560 | 706 | 80 | +6 | **0** |
| iPhone 17 Pro 402×874 | 560 | 728 | 80 | +6 | **0** |
| 13–16 Pro Max 430×932 | 560 | 786 | 80 | +6 | **0** |
| 16/17 Pro Max 440×956 | 560 | 810 | 80 | +6 | **0** |
| compact 320×600 | 450 (notch) | 450 | 84 | +10 | 6 |
| compact 360×620 | 450 (notch) | 464 | 90 | +16 | **0** |
| compact 390×620 | 540 (notch) | 540 | 14 | **−60** | 76 |
| desktop 1280×800 | 656 | 656 | 34 | n/a | 76 |

**Standalone emulation** (`--inset-top` / `--inset-bottom` injected as the real safe areas):

| notched iPhone | insets | rendered canvas | page scroll |
|---|---|---|---|
| 390×844 | 47/34 | 617 | **0** ✅ |
| 393×852 | 59/34 | 613 | **0** ✅ |
| 402×874 | 59/34 | 635 | **0** ✅ |
| 430×932 | 59/34 | 693 | **0** ✅ |
| 440×956 | 59/34 | 717 | **0** ✅ |
| Pixel 412×915 | 24/24 | 721 | **0** ✅ |
| SE2/8 375×667 (not notched) | 20/0 | 560 | **69** |
| SE1 320×568 (not notched) | 20/0 | 450 | **58** |

So the amended claim is **CONFIRMED exactly as worded**: every *notched* iPhone fits with zero
page scroll in standalone mode, the canvas never renders below its documented floor, and taller
phones get a taller canvas (654 → 810 px). The 560/540/450/656 notches are all honoured. The
residue the wording leaves open: **6 of 13 viewports still scroll** (320×568 38 px, 375×667
49 px, 320×600 6 px, 390×620 76 px, desktop 76 px, and 375×667 rises to 69 px in standalone),
and on 3 of them the canvas bottom sits **below the fixed nav's top** (−22, −33, −60 px), i.e.
the last hour of the day is under the nav until the student scrolls. Horizontal overflow **0 on
21/21 cells**; 0 lesson blocks clipped out of the canvas on 21/21. Probe
`r10-struct-canvas.log`; screenshots `r10-struct-canvas-standalone-*.png`.

### [S-R10-30] The day range widens to the hour — confirmed
`rangeFor()` (`TimetablePage.tsx:283-292`) expands the default 09:00–20:00 to the floor/ceil hour
of the earliest/latest lesson. With `/api/timetable` fulfilled with a 07:20–08:10 lesson and a
20:30–21:40 lesson at 390×844:

```
hour marks: 07:00 08:00 09:00 10:00 11:00 12:00 13:00 14:00 15:00 16:00 17:00 18:00 19:00 20:00 21:00 22:00
blocks:     "Early Study 07:20–08:10"  top 16px,  h 39px
            "Evening Study 20:30–…"    top 627px, h 54px      canvas 698px
clipped out of the canvas: 0
```

Both out-of-range lessons render fully inside the canvas — "a clipped block is not an option"
holds. Probe `r10-struct-canvas.log`; screenshot `r10-struct-canvas-widened.png`.

### (d) Landing, Tab 1 and h1-in-view on `bc3b7c9`

### [S-R10-31] The lesson-day heading is now clipped too; the sparse day still clamps; Tab 1 still misses the skip link
Cold loads, `scrollIntoView` monkey-patched. The bar is `static` at ≤620 heights, so it scrolls
away with the landing.

| viewport | date | scrollTop / max | h1 y / bottom | bar y | block 1 y | `scrollIntoView` | Tab 1 | Tab 2 |
|---|---|---|---|---|---|---|---|---|
| 320×568 | today | 0 / 38 | **+9** / 53 | 0 | 67 | 1 | daynav arrow | date input |
| 320×568 | 08-24 | 17 / 86 | **−8** / 36 | −17 | 98 | 1 | daynav arrow | date input |
| 320×568 | 08-25 sparse | **86 / 86** | **−77** / −33 | −86 | 211 | 1 | daynav arrow | date input |
| 360×620 | today | 0 / 0 | **+9** / 53 | 0 | 67 | 1 | daynav arrow | date input |
| 360×620 | 08-24 | 20 / 34 | **−11** / 33 | −20 | 95 | 1 | daynav arrow | date input |
| 360×620 | 08-25 sparse | **34 / 34** | **−25** / 19 | −34 | 263 | 1 | daynav arrow | date input |
| 390×620 | today | 0 / 76 | **+9** / 53 | 0 | 67 | 1 | daynav arrow | date input |
| 390×620 | 08-24 | 19 / 124 | **−10** / 34 | −19 | 96 | 1 | daynav arrow | date input |
| 390×620 | 08-25 sparse | **124 / 124** | **−115** / −71 | −124 | 210 | 1 | daynav arrow | date input |
| 375×667 | all three | 0 / 49–97 | **+9** / 53 | 0 | 67–343 | **0** | **skip link** | daynav arrow |
| 390×844 | all three | 0 / 0 | **+9** / 53 | 0 | 67–380 | **0** | **skip link** | daynav arrow |

Facts: (i) **today's landing is now a no-op** at compact heights — scrollTop 0 with the heading
at +9, because today's first lesson already sits at y 67; (ii) on an ordinary 3-lesson day
(2026-08-24) the landing scrolls 17–20 px and the h1's **top edge leaves the viewport on 3/3
compact viewports** (27–36 px of a 44 px heading remain); (iii) the **sparse day still clamps to
maximum scroll** on 3/3 compact viewports with the heading fully or nearly gone (−77 / −25 /
−115) — `[S-R10-9]` unchanged across three rewrites; (iv) **Tab 1 is the daynav arrow on 9/9
compact cells**, the skip link is still stepped over (`[S-R10-10]` unchanged), and Tab 2 is now
the date input rather than a second daynav control; (v) at 375×667 and 390×844 the landing is
gated out entirely, `scrollIntoView` = 0, and Tab 1 is the skip link 6/6.
Probe `r10-struct-bar.log` (LANDING rows).

### (e) Retry landing on `bc3b7c9`

### [S-R10-32] CONFIRMED, both outcomes
`/api/timetable` aborted forever, then once; "Try again" activated with Enter at 390×844:

```
fail-again : scrollTop 0 -> 0 · activeElement div.focus-landing[aria-label="Day timeline"][data-landed] · outline rgb(51,102,124) solid 3px
succeed    : scrollTop 0 -> 0 · activeElement div.focus-landing[aria-label="Day timeline"][data-landed] · outline rgb(51,102,124) solid 3px
```

The landing region still wraps both branches (`TimetablePage.tsx:205-215`). Probe
`r10-struct-bar.log` (RETRY rows).

### (f) The `Modal.tsx` change

### [S-R10-33] Dialog exits still restore the opener 21/21
`Modal.tsx` now reads `onClose` through a ref and its effect deps are `[]`
(`Modal.tsx:18-20,31,57`). Re-running the full dialog sweep on `bc3b7c9` — 7 dialogs ×
{Esc, ×, overlay} plus Cancel on the two `ConfirmDialog`s — reproduces §[S-R10-3] exactly:
**21/21** exits leave `activeElement` on the opener with `#root` no longer `inert`; the two
Cancel cells also restore; the five dialogs without a Cancel are unchanged. The Report dialog
still returns to `button.react-btn--more "More options"`. Probe
`r10-struct-dialogs-bc3b7c9.log` (28 cells).

### (g) Census delta for `/timetable`

### [S-R10-34] Back to the `41a01fe` totals, one node shallower
`visible/total`, in-viewport rule as in §1.1:

| surface | r9 `eede644` | `41a01fe` | `9c3b23f` | **`bc3b7c9`** |
|---|---|---|---|---|
| Timetable today (390×844) | –/20 | –/20 | 12/19 | **11/20** |
| Timetable 2026-08-24 | –/21 | –/21 | 13/20 | **12/21** |
| Timetable empty (08-22) | –/18 | –/18 | 10/17 | **9/18** |

The control that returned is `a.daynav__history-sr` (added in `bd54519`); the one that left in
`9c3b23f` was the old "Pick a date" button, replaced by the input. Depth from `main#main` to the
first `.lesson-block` **6** (r9 6, `9c3b23f` 7); max document depth **13** (r9 14);
`[data-scroll-owner]` **1**; `activeElement` on arrival **body** 6/6;
`aria-live` **0**; `role="status"` 1 (2 on the empty day). Identical at 320×568.
Probe `r10-struct-bar.log` (CENSUS rows).

### (h) Served CSS, dangling comments, reverse sweep on `bc3b7c9`

### [S-R10-35] `tokens.css` grew two tokens; nothing dead was added
Served sheet `index-C9l5CGbD.css`, **43,020 B** (`41a01fe` 41,080), **410 rules** (390),
**30 at-rules** (28), **232 distinct classes** (225), **6 `@keyframes`**, **7 `@font-face`**,
**0 orphan declarations**, **0 within-context duplicate selectors** (the 7 `@font-face` heads
aside). `check-css.mjs` **exit 0** on the served sheet and on `dist/assets`.

- **Dangling trailing comments: 9** — unchanged in count and identity, only renumbered:
  `components.css:527, 728, 887, 936`; `features.css:84, 1282, 1388, 1408, 1414`.
  `features.css:84` (the orphaned `.nextlesson__wash` transition comment) is still there.
- **Consumer-less served classes: 7 raw / 0 adjusted** — the same runtime-composed
  `chip--{ok,danger,muted}` and `swatch--{stone,white,mist,night}`.
- **TSX→CSS reverse sweep: 7 raw / 4 real** — `login__card`, `post__dot`, `home`, `home-head`;
  every new class (`daynav__date-long`, `daynav__date-short`, `daynav__caret`, `daynav__row`,
  `daynav__state`, `daynav__history-sr`, `daynav__today`, `pullup`, `pullup__mark`) has a served
  rule, and `schedule-header` / `timetable-note` left both source and sheet cleanly.
- `tsc --noEmit --noUnusedLocals --noUnusedParameters` → **exit 0, 0 lines**.
- Repeated families unchanged: 11 armed "Try again" + 1 unarmed shell "Retry";
  `useRetryFocus` 8 call sites; `.focus-landing` 10; `role="alert"` 17; `<Skeleton>` 12.

Probes `r10-struct-static-bc3b7c9.log`, `r10-struct-css.log`; sheet `r10-served-bc3b7c9.css`.

### Probe inventory for §7

`r10-struct-bar.js` / `.log` (bar geometry, landing, retry, census) · `r10-struct-h1.js` / `.log`
(the two date spans) · `r10-struct-gestures.js` / `.log` (PTR ladder + pull-up, sync intercepted)
· `r10-struct-canvas.js` / `.log` (13-device canvas fit, standalone insets, widened day range) ·
`r10-struct-taborder.js` / `.log` · `r10-struct-narrowdesk.js` / `.log` ·
`r10-struct-dialogs-bc3b7c9.log` · `r10-struct-static-bc3b7c9.log` · `r10-served-bc3b7c9.css`.
Screenshots: `r10-struct-bar-{320x568,360x620,390x620,375x667,390x844,430x932,1280x800}.png`,
`r10-struct-h1-*.png`, `r10-struct-ptr-sync.png`, `r10-struct-pullup-{below,above,above}.png`,
`r10-struct-canvas-standalone-*.png`, `r10-struct-canvas-widened.png`.
