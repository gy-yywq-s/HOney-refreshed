# Accessibility evidence — design-is r10 (evidence only; no scores, no verdicts)

Anchors `[A-R10-n]`. Harness `/root/claude-work/design-audit/`, probes `r10-a11y-*.js` with `.log`
files and `r10-a11y-*.png` screenshots. Every lesson-block / Timetable measurement in
`timezoneId:"Asia/Shanghai"`; in-page "today" 2026-09-02 (3 lessons: P1 09:00–10:30,
P3 13:30–15:00, P5 16:30–18:00), control day 2026-08-24, sparse day 2026-08-25 (one late
lesson), empty days 2026-08-22 / 2026-09-06. No post was published, no report submitted, no
Settings change persisted; every reaction POST was intercepted with `page.route` and fulfilled
locally (0 reached the server); `/api/sync` was intercepted and fulfilled locally on every
gesture run (1 sync-stage release, 0 requests to the school portal); every browser closed.

## 0a. BUILD ATTRIBUTION — the live site was redeployed five times during this pass

`journalctl` backend restarts on the droplet, and the bundle each serves:

| deployed at (UTC) | commit | served JS |
|---|---|---|
| 03:13:12 | **41a01fe** (the audited commit) | `index-CJ2b0Z4x.js` / `index-DOdf_Dgc.css` |
| 03:42:19 | 9c3b23f "a native-style top bar, no captions" | — |
| 03:46:50 | 60c8672 "the owner yields its top padding" | — |
| 03:50:55 | 979a42e "canvas fills the frame" | — |
| 03:58:02 | bd54519 "gestures replace History and Sync now" | — |
| 04:01:27 | **bc3b7c9** "pull labels read in order" (current) | `index-4oNbE07m.js` / `index-C9l5CGbD.css` |

Probe → build (by log mtime against that table):

| probe | finished (UTC) | build measured |
|---|---|---|
| `r10-a11y-landing` | 03:27:40 | **41a01fe** |
| `r10-a11y-compact` | 03:32:07 | **41a01fe** |
| `r10-a11y-dialogs` | 03:32:48 | **41a01fe** |
| `r10-a11y-find` | 03:33:42 | **41a01fe** |
| `r10-a11y-find2` | 03:35:10 | **41a01fe** |
| `r10-a11y-feedstatus` | 03:37:01 | **41a01fe** |
| `r10-a11y-misc` | 03:40:11 | **41a01fe** |
| `r10-a11y-reach` | 03:43:38 | 41a01fe for the first three Tab orders (≈03:40:40), 9c3b23f for the tail (theme picker, Reconnect/Save labels, 1280 Settings, Login) |
| `r10-a11y-contrast` / `-zoom` | 03:47:17 | 9c3b23f / 60c8672 |
| `r10-a11y-names` | 03:48:46 | 60c8672 |
| `r10-a11y-semantics` | 03:49:04 | 60c8672 |
| `r10-a11y-motion` | 03:49:43 | 60c8672 |
| `r10-a11y-disabled` | 04:00:15 | 979a42e / bd54519 |
| `r10-a11y-final` | 04:03:03 | bd54519 / bc3b7c9 |
| `r10-a11y-final2` / `-final3` | 04:04:49 / 04:06:28 | **bc3b7c9** |
| `r10-a11y-tt-current`, `-tt-current2`, `-gestures` | 04:2x | **bc3b7c9** (re-run on request) |
| `r10-a11y-contrast-bc3b7c9`, `-semantics-bc3b7c9`, `-disabled-bc3b7c9`, `-motion-bc3b7c9` | 04:3x | **bc3b7c9** (re-run) |

Everything below is labelled `[41a01fe]` or `[bc3b7c9]`. Nothing is carried across builds silently.

## 0b. r9-move verification table

Every row measured live, not read from the diff.

| # | r9 move / claim | result | numbers |
|---|---|---|---|
| 1 | Retry lands on **every** error surface, fail-again AND succeed, keyboard AND mouse | **CONFIRMED** `[41a01fe]` | **48/48** landings on 12 surfaces × 2 outcomes × 2 input modes. `activeElement` = the named region every time, `data-landed` present, ring 25.9–28.4 % of the band, scroll delta 0→0 on all 48. Zero `<body>` landings. [A-R10-1] |
| 1a | Mine "Try again" (r9: `<body>`) | **CONFIRMED** | 0 keys and seeded: `div[role=region][aria-label="Your notes & posts"]`, ring 27.29–27.59 %. `MinePage.tsx:59` now `mine.loading \|\| namesLoading`. |
| 1b | Explore directory-only retry (r9: `<body>`) | **CONFIRMED** | fail and succeed → `div[role=group][aria-label="Everything listed"]`, ring 26.46–28.42 %. `ExplorePage.tsx:42` arms on both flags; `useApi.ts` `forced` ref forces a miss on `reload()`. |
| 1c | Timetable retry that fails again (r9: no region) | **CONFIRMED** | `div[role=region][aria-label="Day timeline"]`, ring 27.23 %, scroll 0→0. Region now wraps loading/error/success. Re-verified on `[bc3b7c9]`: 4/4 land, ring 28.2–28.3 %. [A-R10-2] |
| 1d | Compose-`?lessonId=` error surface (new) | **CONFIRMED** | region "Could not load" lands on fail-again and the Editor region on success (`ComposePage.tsx:222-245`); a `Skeleton lines={4}` renders while `/api/history` is delayed 6 s (5 skeleton nodes at 1.5 s and 3.0 s) — r9's missing loading/error branch is filled. |
| 2 | 7/7 dialogs return focus to a **mounted** opener on Esc / × / Cancel / overlay | **CONFIRMED** `[41a01fe]` | **20/20 available exits at 390×844 and 23/23 at 1280×900** restore the opener (Save-login, Reconnect and Lesson have no Cancel button; Report has neither Cancel; Appearance is rail-only at ≤640). **Report dialog now restores to `button.react-btn--more "More options"` on Esc, × and overlay** — r9's `<body>` drop is gone (`ExperiencePost.tsx:266` focuses the persistent trigger before the menu item unmounts). Trap: 0 escapes over 30 Tab + 30 Shift+Tab on every dialog. `#root[inert]` set on open and removed on every close, `dialog.closest('[inert]')` false. Names = the h2 7/7; `aria-describedby` resolves 7/7. [A-R10-3] |
| 2a | Lesson dialog on the current build (Modal deps changed to `[]`) | **CONFIRMED** `[bc3b7c9]` | 3 exits × 2 viewports = 6/6 restore `button.lesson-block`; trap 0/0 escapes; `#root[inert]` on/off; sheet `20px 20px 0 0` + `sheet-up 0.42s` at 390, `20px` + `rise-in 0.3s` at 1280. [A-R10-4] |
| 3 | Pending pill: a second activation keeps focus on the pill and a status announces | **CONFIRMED, with residue** `[41a01fe]` | Keyboard and touch, POST delayed 2.5 s: `activeElement` is the pill before, during, after both activations (`pointer-events` now `auto`, `aria-disabled="true"`, `opacity .7`); 1 POST per pass. The second activation inserts `div.post__note[role=status]` reading **"Saving your reaction…"** (`ExperiencePost.tsx:158,277`). **Residue:** the note is never cleared — it still reads "Saving your reaction…" 3.2 s after the POST settled (`setNote(null)` runs only at the start of the *next* non-busy `react()`, `:166`); and the node is **created** at press time rather than being a pre-existing live region, which several screen readers do not announce. `aria-pressed` flips optimistically to `"true"` at press time, before the server echo. [A-R10-5] |
| 4 | Tab 1 after the compact landing = the skip link at 320×568 / 360×620 / 390×620, both clock states | **REFUTED** `[41a01fe]` and `[bc3b7c9]` | `[41a01fe]` Tab 1 = `button.daynav__arrow "Previous day"` on **12/12** compact rows (today after P1, today during P1 via a fixed 09:15 CST clock, Aug 24, Aug 25) — the skip link is **skipped**, not reached. `[bc3b7c9]` same: Tab 1 = "Previous day" on **9/9** compact rows where the landing runs. Cause: `TimetablePage.tsx:360-361` (41a01fe) / `:362-363` (current) `skip?.focus({preventScroll:true}); skip?.blur();` sets the sequential-focus start point **at** the skip link, so the next Tab goes to the element *after* it. r9's defect (Tab 1 = a lesson block) is gone; the stated success criterion is not met. At 390×844 and on an empty day (no landing) Tab 1 **is** the skip link. [A-R10-6] |
| 4a | h1 + note + daynav in view after the landing, block 1 ≥ y 0 | **PARTIAL** `[41a01fe]` | Today + Aug 24: h1 y = 3 / 5 / 6 / 13 / 22 (in view 6/6 compact rows), note y = 49–68 (in view), block 1 y = 86–97 (never < 0). **Sparse day (Aug 25, one late lesson): the landing still clamps to max scroll — `scrollTop 216/216` (320×568), `164/164` (360×620), `236/236` (390×620); h1 y = −70 / −18 / −90 (off-screen 3/3), note y = −24 / +28 / −44 (off 2/3).** The `.daynav` is off-screen on **12/12** compact rows (y −107 … −220). Both clock states behave identically now (the target is always `visible[0]`, `TimetablePage.tsx:352`), so the r9 clock dependence is gone; the day-with-a-late-first-lesson case is not. [A-R10-7] |
| 4b | Same on the current build | **REGRESSED** `[bc3b7c9]` | h1 in view on today (4/4 viewports) and the empty day, but **off-screen on the control day at all three compact heights** (h1 y = −11 / −15 / −11) and on the sparse day (−77 / −25 / −115). The `p.timetable-note` is gone from the DOM entirely ("no captions"). The daynav is no longer sticky: it scrolls off with the page (y = −scrollTop). [A-R10-8] |
| 5 | 404 on nested paths marks no nav tab current | **REFUTED for AT, CONFIRMED for sight** `[41a01fe]` | The `is-active` class is gone on all 7 tested 404 paths, but `aria-current="page"` **remains** on `/experiences/new` (rail + mobile), `/timetable/oops` (rail + mobile), `/settings/x` (mobile), `/experiences/teacher` (rail + mobile) and `/home/x` (rail + mobile). Only `/nonsense` and `/history/zzz` mark nothing. Cause: `AppLayout.tsx:103` changes only `className`, and `:104` `aria-current={undefined}` does not suppress `NavLink`'s own computed value (measured: `aria-current="page"` is present on `/home`, `/timetable`, `/experiences` too). Sighted and AT users now get **different** answers on a 404. [A-R10-9] |
| 5a | Skip link → `#main` on 12+ routes | **CONFIRMED** `[41a01fe]` | 13/13 routes (`/home`, `/timetable`, `/history`, `/history?select=1`, `/experiences`, `/experiences/explore`, `/experiences/mine`, `/experiences/compose`, `/experiences/compose?entityKey=…`, `/experiences/why`, `/experiences/teacher/…`, `/settings`, `/nonsense`): Tab 1 = `a.skip-link "Skip to content"` at `[12,12,134,48]`, Enter → `MAIN#main`. `/login` has its own "Skip to sign-in" → `#school-username` (resolves). |
| 6 | Feed status per tab, "N more" on load-more, no re-announcement on a tab change, `aria-atomic`, named `role=status` | **PARTIAL** `[41a01fe]` | Per-tab empty sentence CONFIRMED: n=0 on "Your classes" announces **"Nothing from your classes yet"** (29 chars), on "Around school" **"Nothing has been shared yet"**. Counts: "1 experience" / "12 experiences". Load-more CONFIRMED: **"12 more"** (one announcement, `FeedPage.tsx:36-51`). Error: silent status, one `role=alert`. **Not done:** a tab change still announces the *new* count each time ("24 experiences" on every switch to tab 2 in a 4-switch trace); `aria-atomic` is absent on every live node app-wide; the 2 `role=status` nodes are still unnamed (`div.ptr__disc`, `p.sr-only`); `main` is unnamed on every route. [A-R10-10] |
| 7 | Reconnect label per tick state, read as the button's accessible name | **CONFIRMED** | Reconnect purpose: unticked → **"Reconnect only"**, ticked → **"Reconnect and save login"**, unticked again → "Reconnect only" (accessible name = the visible text; no `aria-label`). Save purpose: ticked → **"Save login"**, unticked → **"Sign in without saving"**. `ReconnectDialog.tsx:40-47`. |
| 8 | History "Select" → composer focus landing (r9: `<body>`) | **REFUTED — unchanged** `[41a01fe]` | Enter on `button "Select"` navigates to `/experiences/compose?lessonId=1335340` with `activeElement = (body)`, h1 "Share an experience". No landing, no focus move. [A-R10-11] |
| 9 | Keyboard equivalents for pull-to-refresh and load-more | **REFUTED — still none** | `[41a01fe]` `div.ptr[aria-hidden="true"]`, 0 focusable descendants, on `/home`, `/timetable`, `/experiences`, `/history`; 0 controls named refresh/reload/update on any route. With 12 posts and a `nextCursor` there is **no "Load more" control** in the DOM — loading is IntersectionObserver-only. Unchanged on `[bc3b7c9]`, where the gesture layer grew (see §2, [A-R10-20]). |
| — | r9 Preserve: rest-state ring | **CONFIRMED** | 202 Tab stops across Feed/Timetable/Settings/Explore/Compose/Login/1280-Settings: **every stop ringed** except the last segment of the native date input (see [A-R10-19]); 0 controls ringed at rest. |
| — | r9 Preserve: two disabled fills → one | **CONFIRMED** | `[41a01fe]` and `[bc3b7c9]` identical: `.btn--primary:disabled` and `.btn--ghost:disabled` both `background rgba(0,0,0,0)`, `border rgba(35,43,49,.14) 1px`, `color rgb(92,103,112)`, `opacity 1`. One recipe. Ratios 5.34–5.66 stone / 7.26–8.07 night. |
| — | r9 Preserve: Explore error no longer shows four empty sections | **CONFIRMED** `[bc3b7c9]`, source-consistent at 41a01fe | `/api/entities` aborted and `/api/directory` aborted: `alerts=["Could not reach the HOney server…"]`, `empties=[]`, `h2=[]`, `rows=0` (r9: banner + 4 × "Nothing here yet."). `ExplorePage.tsx:121`. |
| — | r9 latent: `Modal`'s `[onClose]` effect re-running | **CONFIRMED fixed** `[bc3b7c9]` | `Modal.tsx:18-20,57` reads `onClose` through a ref and the effect deps are `[]`. |

## 1. Required fields

### 1.1 Contrast (WCAG 1.4.3 / 1.4.11), 25 surfaces × 2 boots = 50 measurements

`[bc3b7c9]` (`r10-a11y-contrast-bc3b7c9.log`; `[41a01fe]` numbers in `r10-a11y-contrast.log`).
Method: every visible text-bearing leaf, alpha-composited through the ancestor chain, opacity
folded in; the LOWEST enabled ratio per surface is reported.

**Enabled text below threshold: 0 of 50 surfaces, both boots, both builds.**

| token / surface | stone | night |
|---|---|---|
| **floor, whole app** | **4.87** `span` "Portal time-outs reconnect on their own…" 13px/400 (Login) | **6.11** `span` "Stay connected on this device." 13px/400 (dialogs) |
| `p.home-head__date` (Home floor) | 5.34 | 7.27 (`span.eyebrow "Next"`) |
| `.daynav__arrow` ‹ › (Timetable floor, new bar) | 5.63 | 7.27 |
| `.daynav__date-long` (the h1) | 13.98 | 13.75 |
| `.daynav__state` "Synced N ago" | 5.34 | 8.07 |
| `.ptr__label` (pull labels) | 5.34 | 8.07 |
| `.pullup__mark span` "Pull up for History" | 5.63 | 7.27 |
| `.lesson-block__subject` / `__teacher` | 13.26 | 13.75 |
| `.timeline__hour` | 5.34 | 8.07 |
| captions (`p.caption`, `h2.month-group__label`, `div.overline`, `span.eyebrow`) | 5.34–5.66 | 7.26–8.07 |
| error banner `span` "Could not reach…" | 5.36 | 7.17–7.96 |
| 404 `p.muted` | 5.34 | 8.07 |
| **disabled** text (`Export`, `Share anonymously`, `Keep this for yourself`) | 5.34–5.66 | 7.26–8.07 |
| **placeholders** (`#compose-body`, `input.search-box`) | 5.34–5.63 | 7.27–8.07 |
| reaction pill at rest | 5.34 | 8.07 |
| dialog text through the portal (`.modal` bg `rgb(251,252,252)` stone / `rgb(29,33,37)` night) | 5.14–13.26 | 6.11–15.27 |
| **focus ring vs the adjacent ground** `.focus-landing` | 5.81–6.13 | 8.36–9.28 |
| focus ring `#main > .view` (skip landing, radius now 17px) | 5.81 | 9.28 |
| focus ring `.daynav__date` | 13.98 | 13.75 |
| ring vs the **inside** of `.btn--primary` (the fill it sits over) | **2.28** | **1.65** |

Note on the last row: the ring has `outline-offset: 3px`, so it is painted on the page ground
(5.81 / 9.28 ✓), not on the button fill; the 2.28 / 1.65 figures are the ring against the fill it
is offset away from. Recorded as a measurement, not a claim.

### 1.2 Focus order per route — every stop's name, role, ring, on-screen state

`[41a01fe]` unless marked. Ringed = computed `outline-style !== none` and width > 0 while focused.

**Feed `/experiences` @390×844 — 15 stops, ringed 15/15, in view 14/15**
1 link "Skip to content" 134×48 (off-screen until focused) · 2 link "Share" 59×44 · 3 link "Find
someone or something" 183×44 · 4 link "Your notes & posts" 131×44 · 5 link "Why this space
exists" 111×44 · 6 tab "Your classes" 106×44 · 7 tab "Around school" 121×44 · 8 link "活动课老师"
65×44 · 9 button "Matches my experience" 49×44 · 10 button "Doesn't match my experience" 49×44 ·
11 button "More options" 44×44 · 12–15 the four mobile-nav links 85×46.

**Timetable @390×844 `[41a01fe]` — 13 stops, ringed 13/13, in view 12/13**
skip · Previous day 44×44 · **Pick a date (Wed 2 Sept) 268×44** · Next day 44×44 · link History
67×44 · button Sync now 79×44 · 3 lesson blocks 282×84 · 4 nav links.

**Timetable @390×844 `[bc3b7c9]` — 15 focusable stops (17 Tab presses), ringed 15, in view 15**
skip · Previous day 44×44 · **Pick a date (Wednesday, 2 September) 266×44 — four consecutive Tab
presses, the fourth with NO ring** · Next day 44×44 · **link History 72×32 (the sr-only link,
revealed on focus)** · 3 lesson blocks 282×95 · 4 nav links. **No "Sync now" stop.**

**Timetable @320×568 `[bc3b7c9]`** — same shape; lesson blocks 216×61; History sr-link 72×32.

**Timetable @1280×800 `[bc3b7c9]` — 18 stops**: …Previous day · picker (3 presses, last with no
ring) · Next day · link History 67×36 · button **Sync now 79×36** · 3 lesson blocks 854×89. On a
stepped day a "Back to today" 104×36 stop appears between Next day and History.

**Settings @390×844 — 17 stops, ringed 17/17, in view 10/17**
skip · Stone / White / Mist / Night 154×81 each · Sign out 94×44 · Open Dash 110×44 · Delete
account… 152×44 (off-screen) · Sync now 102×44 (off) · Disconnect 112×44 (off) · Save school
login… 166×44 (off) · Delete imported data… 193×44 (off) · Import… 100×44 (off) · 4 nav links.
**7 of 17 stops are off-screen when reached** (unchanged from r9).

**Settings @1280×800 — 19 stops, ringed 19/19, in view 15/19**; stop 2 is `a.brand` with an
**empty accessible name** (see [A-R10-13]).

**Compose editor (text typed) — 10 stops, ringed 10/10, in view 9/10**
skip · textarea 358×303 · Share anonymously 358×44 · Keep this for yourself 358×44 · Cancel
358×44 · link "How privacy works" 102×44 · 4 nav links.

**Compose chooser — 12 stops, ringed 12/12, in view 11/12**
skip · 5 recent-lesson links 316×48–73 · "Pick a lesson from History" 208×44 · "Find someone or
something" 220×44 · 4 nav links.

**Explore (no query) — 26 stops, ringed 26/26, in view 15/26**
skip · "Back to Experiences" 170×44 · **searchbox "Filter by name" 358×59** · 19 entity rows
358×48–73 (11 of them off-screen when reached) · 4 nav links.
**Explore with the query "ch" — 8 stops**: 4 matching entity rows then the nav (the search box
itself is no longer a stop because focus started inside it).

**Login (no session) — 5 stops, ringed 5/5, in view 4/5**
"Skip to sign-in" 128×48 · 2 textboxes 342×50 (no accessible name — see [A-R10-14]) · checkbox
"Stay connected on this device" **22×22** inside a 342×132 label · "Continue with school account"
342×44.

### 1.3 Keyboard reachability of every primary action

| action | reachable by keyboard | evidence |
|---|---|---|
| open a lesson | ✅ Tab 7 (390) / Tab 9 (`[bc3b7c9]`) | button, name includes course + room + period + time + teacher |
| step day back / forward | ✅ Tab 2 / Tab 4 (`[bc3b7c9]` Tab 7) | 44×44 each |
| date picker | ✅ | `input[type=date]` 266×44, `aria-label="Pick a date (…)"`; consumes 3–4 Tab presses; the last one has no focus ring |
| back to today | ✅ **only when the shown day ≠ today** | absent from the DOM on today; 104×44 @390, 104×36 @1280 |
| History (from the Timetable) | `[41a01fe]` ✅ visible button 67×44 · `[bc3b7c9]` @≤700 px ✅ **only via `a.daynav__history-sr`, 1×1 until focused then 72×32 — the one sub-44 control on the screen** | `features.css:170,283-296` |
| **Sync now** | `[41a01fe]` ✅ button 79×44 · **`[bc3b7c9]` @≤700 px ❌ NO CONTROL AT ALL** — `.daynav__row{display:none}` (`features.css:280-282`), the button is 0×0 and out of the Tab order; the only path is the two-stage touch pull | [A-R10-20] |
| "Synced N ago" state | `[bc3b7c9]` ❌ at ≤700 px (0×0, inside the hidden row) — not available to sight or AT on a phone | |
| react (👍 / 👎) | ✅ Tab 9 / 10 | 49×44, `aria-pressed` |
| report a post | ✅ ··· → Enter → menuitem "Report" 110×44 focused | menu keyboard contract intact |
| share / open the composer | ✅ Tab 2 "Share" | |
| chooser: pick a recent lesson | ✅ Tab 2–6 (5 links) | |
| chooser: Pick a lesson from History / Find someone or something | ✅ | |
| Find-mode search input | ✅ Tab 3 on Explore | |
| Find-mode result select (entity row) | ✅ Tab 4+ | all 19 rows are stops |
| Find-mode: select an experience result | ✅ (the results render as ordinary posts inside the landing group) | |
| **load more** | ❌ no control exists at any width | |
| **refresh (pull-to-refresh)** | ❌ no control, no focusable node, on any route | |
| **pull up for History (new)** | ❌ touch only; the sr link is the substitute | |
| sign out | ✅ Tab 6 on Settings | |
| every Settings row | ✅ except **Export** (disabled by design) | 12/13 rows reachable |
| theme picker @390 | ✅ 4 buttons 154×81, `aria-pressed` true/false | |
| theme picker @1280 | ✅ 4 buttons 218×81 on the Settings page, plus the rail "Appearance" dialog (rail is `display:none` at ≤ desktop, so the dialog is unreachable at 390/320 — unchanged from r9) | |

### 1.4 ARIA landmarks per route (390×844)

`[41a01fe]` and `[bc3b7c9]` identical (`diff` of the two semantics logs on landmark counts: empty).

| route | counts | names |
|---|---|---|
| Home | `{navigation:2, main:1, region:2}` | "Primary", "Primary, mobile", **main unnamed**, region "Now and next", region "From your classes" |
| Timetable | `{navigation:2, main:1, group:1, region:1}` | group "Choose a day", region "Day timeline" |
| Feed | `{navigation:2, main:1}` | — |
| Explore | `{navigation:2, main:1, group:1, region:4}` | group "Everything listed", regions "Teachers"/"Courses"/"Places"/"Food"; with a Recent list: +region "Recent" (5 regions) |
| History / History-select | `{navigation:2, main:1, region:1}` | region "Lessons" |
| Settings | `{navigation:2, main:1, region:5, group:1}` | Appearance / Account / School connection / Imported data / Experiences and privacy; group "Background surface" |
| Mine | `{navigation:2, main:1, region:1}` | region "Your notes & posts" |
| Compose chooser | `{navigation:2, main:1, region:1}` | region "Pick a target" |
| Compose editor | `{navigation:2, main:1, region:2}` | regions "What this is about", "Editor" |
| Entity | `{navigation:2, main:1, region:1}` | region "ChenJenny experiences" |
| Why / 404 | `{navigation:2, main:1}` | — |
| Login | `{main:1}` | main unnamed |

Every authenticated route also carries a hidden unnamed `complementary` (the rail at ≤640 px).
`banner` and `contentinfo` roles: **0 everywhere**. `main` is **unnamed on 16/16 routes**.
**The Explore search input is in no `search` landmark and has no `role="search"` ancestor**
(`ExplorePage.tsx:84-91`).

### 1.5 Skip link per route

Present and correct on 13/13 authenticated routes plus `/login`. Focused box `[12,12,134,48]`
(measured 400 ms after Tab, i.e. after the 0.2 s reveal transition); target resolves; Enter moves
`activeElement` to `MAIN#main` 13/13. `/login`: "Skip to sign-in" → `#school-username`, resolves.

## 2. Findings (steps, viewport, values, cause)

**[A-R10-1] Every error surface lands — 48/48.** `[41a01fe]`, `r10-a11y-landing.log`.
Steps: abort the named endpoint with `page.route`, load, focus "Try again", Enter (or click);
for the "succeed" arm, `unroute` before activating. 390×844, Asia/Shanghai, 0 and 1 seeded keys.
Surfaces and their landing regions: Home → `section[role=region]"Now and next"` (26.25–26.99 %);
Timetable → "Day timeline" (27.23–28.75 %); History → "Lessons" (25.89–26.48 %); Feed →
`div[role=tabpanel].feed-stream` (25.89–26.85 %); Explore-entities and Explore-directory-only →
`div[role=group]"Everything listed"` (26.46–28.42 %); Mine 0 keys and Mine seeded → "Your notes &
posts" (27.29–27.59 %); Entity-feed and Entity-registry → "ChenJenny experiences" (27.56–27.69 %);
Compose-`entityKey` and Compose-`lessonId` → "Could not load" on fail-again (25.89 %) and "Editor"
on success (27.66–27.71 %). Scroll delta 0 on all 48.

**[A-R10-2] Timetable retry re-verified on the current build.** `[bc3b7c9]`,
`r10-a11y-tt-current.log` §1: keyboard/fail-again, keyboard/succeed, mouse/fail-again,
mouse/succeed — 4/4 land on `div[role=region][aria-label="Day timeline"]`, ring 28.23–28.30 %,
scroll 0→0.

**[A-R10-3] 7/7 dialogs restore a mounted opener.** `[41a01fe]`, `r10-a11y-dialogs.log`.
Openers restored: Save-school-login → `button "Save school login…"` (Esc, ×, overlay);
Delete-imported-data and Delete-account → their row buttons (Esc, ×, **Cancel**, overlay);
Reconnect → `button "Reconnect"` (Esc, ×, overlay); Lesson → the `button.lesson-block` (Esc, ×,
overlay); **Report → `button.react-btn--more "More options"` (Esc, ×, overlay)**; Appearance
(1280 only) → `button.settings-trigger "Appearance"` (Esc, ×, overlay). `rootInert` false after
every close; `leftover {modal:false, rootInert:false}` on every dialog. Dialog buttons 44–410 × 44,
**0 sub-44**.

**[A-R10-4] Lesson dialog on the current build.** `[bc3b7c9]`, `r10-a11y-tt-current2.log`.
`role=dialog`, `aria-modal=true`, name "IELTS-Speaking" = h2, `aria-describedby=lesson-dialog-body`
resolving to "09:00 to 10:30, with ChenJenny, in room 213."; `#root[inert]` true while open;
30 Tab + 30 Shift+Tab → 0 escapes at 390 and 1280; Esc / × / overlay all restore
`button.lesson-block`.

**[A-R10-5] The pending-reaction note never clears.** `[41a01fe]`, `r10-a11y-misc.log` §6.
Steps: 390×844 hasTouch, `/experiences`, `page.route` the react POST with a 2.5 s delay and a
local fulfil; press Enter (or tap) on 👍, then again 350 ms later; wait 3.2 s.
During: `activeElement` = the pill, `aria-disabled="true"`, `pointer-events: auto`, `opacity 0.7`,
`aria-pressed` already `"true"`. After the second activation: `div.post__note[role=status]` =
"Saving your reaction…". **After the POST settles: `aria-disabled` is removed but the note still
reads "Saving your reaction…"** (keyboard and touch, 2/2). Cause `ExperiencePost.tsx:156-159`
(sets the note and returns) and `:166` (`setNote(null)` runs only inside a *fresh* non-busy
`react()`), rendered at `:277`. Secondary: the node is inserted, not pre-mounted, so the status
role may not fire in some AT; `aria-live`/`aria-atomic` absent.

**[A-R10-6] Tab 1 after the compact landing is "Previous day", not the skip link.**
`[41a01fe]` `r10-a11y-compact.log` (12/12 compact rows) and `[bc3b7c9]`
`r10-a11y-tt-current.log` §2 (9/9). Steps: 320×568 / 360×620 / 390×620, Asia/Shanghai, load
`/timetable`, wait 2.6 s, press Tab once and read `document.activeElement`. Result
`button.daynav__arrow "Previous day"` every time; Tab 2 is the date picker. Contrast: at
390×844 (landing gated out by `innerHeight > 620`) and on the empty day (no lessons → the
effect returns early) Tab 1 **is** `a.skip-link`. Cause `TimetablePage.tsx:360-361` (41a01fe) /
`:362-363` (current): focusing then blurring the skip link sets the sequential-navigation start
point at the skip link itself, so Tab advances past it.

**[A-R10-7] The compact landing still clamps on a day whose first lesson is late.**
`[41a01fe]` `r10-a11y-compact.log`. 2026-08-25 (single lesson, late): `scrollTop == maxScroll`
216/216 · 164/164 · 236/236 at 320×568 / 360×620 / 390×620; `h1.schedule-header` y = −70 / −18 /
−90; `p.timetable-note` y = −24 / +28 / −44; `.daynav` y = −200 / −148 / −220; block 1 y = 204 /
256 / 202 (never above 0). On today and 2026-08-24 the heading and note stay in view (h1 y 3–22).
The `.daynav` is off-screen on **12/12** compact rows. Cause: `.lesson-block { scroll-margin-top:
calc(var(--sp-8)*2 + var(--sp-3)) }` = 100 px (`features.css:360`) requests a position past the
scroll owner's maximum whenever the first lesson sits low on the canvas; the canvas is not padded
to make the request honourable.

**[A-R10-8] The heading leaves the viewport on the control day too, on the current build.**
`[bc3b7c9]` `r10-a11y-tt-current.log` §2. 2026-08-24: `scrollTop/max` 20/86 · 24/34 · 20/124;
h1 y = −11 / −15 / −11 (off-screen 3/3). 2026-08-25: 86/86 · 34/34 · 124/124; h1 y = −77 / −25 /
−115. Today and the empty day: `scrollTop` 0, h1 y = 9. The `p.timetable-note` no longer exists
(removed with the "no captions" bar), so the "note in view" contract has no subject. The daynav
is no longer sticky and scrolls off with the heading (y = −scrollTop on every clamped row).

**[A-R10-9] A 404 on a nested path still tells assistive technology a tab is current.**
`[41a01fe]` `r10-a11y-misc.log` §1. Steps: load `/experiences/new`, `/timetable/oops`,
`/settings/x`, `/experiences/teacher`, `/home/x`; read `[aria-current]` and `.is-active`.
All five render h1 "Page not found" with `.is-active` **absent** and `aria-current="page"`
**present** on the matching rail and mobile nav items. `/nonsense` and `/history/zzz` mark
nothing. Cause `AppLayout.tsx:103` (className only) and `:104` `aria-current={undefined}`, which
`NavLink` ignores — verified by the same attribute being present on real routes (`/home`,
`/timetable`, `/experiences`, `/settings`).

**[A-R10-10] Live-region inventory and gaps.** `[41a01fe]` `r10-a11y-feedstatus.log`.
Every authenticated route mounts exactly one always-present `div.ptr__disc[role=status]` with
**empty text and no accessible name**; `/experiences` adds `p.sr-only[role=status]`.
`aria-live` attributes: **0 app-wide**. `aria-atomic`: **0 app-wide**. `role=alert`: only the
error banners, speaking once. What is announced, by event:
· feed load n=1 → "1 experience" (+433 ms) · n=0 on "Your classes" → "Nothing from your classes
yet" · n=0 on "Around school" → "Nothing has been shared yet" · n=12 → "12 experiences" ·
load-more (sentinel) → "12 more" · tab change → the new tab's count, **re-announced on every
switch** (4-switch trace: "24 experiences" on each switch to tab 2) · feed error → status silent,
one alert · reaction → nothing until the second activation (see [A-R10-5]) ·
**date step → nothing**: a 4-sample trace over Next-day then Previous-day shows the h1 text
changing "Wednesday, 2 September" → "Thursday, 3 September" → back, with the concatenated text of
every `role=status` / `aria-live` / `role=alert` node staying `""` throughout (`[bc3b7c9]`,
`r10-a11y-final3.log`). The day change is silent to AT; focus stays on the arrow.
· Find-mode results → **nothing** (see [A-R10-15]).

**[A-R10-11] History "Select" drops focus to `<body>`.** `[41a01fe]` `r10-a11y-misc.log` §5.
390×844, `/history?select=1`, focus the `button "Select"`, Enter → `/experiences/compose?lessonId=
1335340`, `activeElement = (body)`. Same as r9 [A-R9-20]; nothing in the r9 wave addressed it.

### New surfaces audited for the first time (Find mode, chooser, counts) — `[41a01fe]`

**[A-R10-12] Find mode: the search input has no search semantics and results are silent.**
`r10-a11y-find.log`, `r10-a11y-find2.log`. `input.search-box`, `type="search"`,
`aria-label="Filter by name"`, placeholder "Filter by name…", 358×59.
`role`: none · `aria-controls`: none · `aria-expanded`: none · `aria-autocomplete`: none ·
`aria-describedby`: none · **inside a `role="search"` landmark: false**.
Typing "che" filters the four section headings from "Teachers 6 / Courses 8 / Places 5 / Food 0"
to "Teachers 1 / Courses 2 / Places 0 / Food 0" and the visible row count from 19 to 3, with
**0 changes in any live region** (a `MutationObserver` over every `[aria-live]`/`[role=status]`/
`[role=alert]` recorded none; the only live node present is the empty `div.ptr__disc`). Cause
`ExplorePage.tsx:84-91` (the input) and the absence of any status node on the page.

**Rule 4f (every finite option set fully displayed): CONFIRMED.** With no query, Explore renders
**19 entity rows** = `GET /api/entities` `{total:19, byType:{course:8, room:5, teacher:6}}` —
every listed entity, in four named sections; the search box only filters.

**Server search:** `api.search(q)` fires on every keystroke from 2 characters
(`/api/experiences/search?q=ch` then `?q=che` — no debounce), 200 both times. With the live
corpus the response carries no `experiences`, so the results section never renders. Fulfilled
with one synthetic experience it renders as
`section[aria-label="Experiences that mention this"]` containing `h2.overline` reading
**`Experiences that mention "chem"`** — the accessible name and the visible heading say different
things (`ExplorePage.tsx:136-137`). The section is nested **inside** the `role=group "Everything
listed"` landing region, at y = 772 (below all four entity sections), and its arrival is
announced by nothing. Its posts carry the full reaction UI ("Matches my experience" 42×44,
"Doesn't match my experience" 42×44, "More options" 44×44 — the two pills are **42 px wide**
inside that section, below the 44 px floor, vs 49×44 on the feed).
**When `/api/experiences/search` fails (aborted), Find mode shows no alert, no banner and no
state at all** — `alerts: []`, section absent (`ExplorePage.tsx:36-40` has no error branch).

**Recent:** `section[aria-label="Recent"]` with `h2.overline "Recent"` and one 358×48 link per
remembered entity; written by `recentContexts.remember` on an entity page that resolved to a real
name. Storage key `honey.exp.recent`, max 5. Reachable, named, ≥44.

**[A-R10-13] The composer chooser.** `r10-a11y-find.log` §4. `section.card[aria-label="Pick a
target"]`, `role`: none. Contents: `h2.overline "Your recent lessons"`, a plain `<ul>` (no
`role`) of 5 `<li>` each holding `a.entity-row` → `/experiences/compose?lessonId=…`, then two
`.btn` links. It is a **navigation list, not a listbox/radiogroup**: no `role`, no
`aria-selected`, no `aria-pressed`, no selected state anywhere (nothing is selected until you
navigate). Sizes 316×48–73, all ≥44. `GET /api/history?limit=5&order=desc` returns 5 lessons and
5 rows render — the counts agree. Accessible names concatenate without a separator:
`"IELTS-SpeakingWed 2 Sept · ChenJenny"`, `"CIE Chinese Language & LiteratureMon 31 Aug · 赵流畅"`
(the subject runs into the date because the caption is a sibling `<span>` with no separating text,
`ComposePage.tsx:336-348`). Rule 4f: the chooser deliberately shows only the **last 5** lessons,
with "Pick a lesson from History" (208×44) as the complete set — recorded, not judged.

**[A-R10-14] Entity counts.** `EntityPage.tsx:53,140-149`. The count sentence is appended to the
existing `p.muted.entity-intro`, which has **no `role` and no `aria-live`**: when
`/api/experiences/stats` resolves after first paint the paragraph's text changes silently. With
the live corpus the endpoint returns `{experiences:0, courses:0, teachers:0}` so the sentence
never renders; fulfilled with `{18,3,2}` the paragraph reads *"What students have experienced in
classes with ChenJenny. No single Experience is the whole picture. 18 experiences across
3 courses."*

### Names, roles, states

**[A-R10-15] Empty accessible name: the desktop rail's brand link.** `[41a01fe]`
`r10-a11y-names.log`. At 1280×800 the rail's first control is
`<a class="brand" href="/home">` with no text, no `aria-label`, no `<img alt>` and no
`<svg><title>` — accessible name `""`. It is Tab stop 2 on every desktop route.
(At ≤640 px the rail is `display:none`, so the empty name is desktop-only.)

**[A-R10-16] Login's two text inputs have no accessible name.** `[bc3b7c9]`
`r10-a11y-final3.log`: `input 342×50` ×2, name `""` in the reach census and the login census
(the visible "School username" / "Password" text is not wired with `for`/`id` or `aria-label`).
The login `h1` has empty text but a real name — it contains `<img class="wordmark" alt="HOney">`.
The checkbox is named "Stay connected on this device", `aria-describedby="stay-connected-note"`
resolving; the checkbox itself is **22×22** inside a 342×132 label (the only sub-44 hit target on
`/login`, unchanged from r9).

**Names census, 14 routes, `[41a01fe]` (`r10-a11y-names.log`):** 6–39 controls per route;
**empty accessible names 0/14 routes at 390×844**; duplicates are only the intended
rail-plus-mobile-nav pairs ("Home" ×2, "Experiences" ×2, "Timetable" ×2) plus **"Select" ×25** on
`/history?select=1` (25 identically-named buttons for 25 different lessons — the lesson each one
selects is not in its name). Label ≠ visible label: `button.react-btn--more`
`aria-label="More options"` over the visible "···" (intended), and the two History filter
`<select>`s labelled "Filter by teacher"/"Filter by course" over their option text (intended).

**Reaction pills:** name "Matches my experience" / "Doesn't match my experience",
`aria-pressed="false"` → `"true"` optimistically at press. The **visible label is the count**
("0"), and the count is **not** in the accessible name — an AT user hears the pill's purpose and
its pressed state but never the tally.

**Theme cards:** 4 buttons with `aria-pressed` "true"/"false" (154×81 @390, 218×81 @1280); the
4 nested 23×23 `i.swatch` elements are `aria-hidden="true"` decorations.

**Feed tabs:** `role=tab` "Your classes" (`id=tab-my-classes`, `aria-selected=true`) and
"Around school" (`id=tab-school`); the single `role=tabpanel` is renamed on switch via
`aria-labelledby` (resolves to the selected tab's text).

**`···` menu:** trigger `aria-label="More options"`, `aria-haspopup="menu"`, `aria-expanded`,
`aria-controls=post-menu-<uuid>`; menu `role=menu` `aria-label="Post options"` with exactly one
`role=menuitem` "Report" 110×44; Enter focuses it, ArrowDown/ArrowUp hold on it, Escape returns
to the trigger. Two names for a one-item affordance (r9 [C-R9-7]) — unchanged.

**Lesson blocks:** `<button>` named e.g. "IELTS-Speaking 213 P1 · 09:00–10:30 · ChenJenny" —
course, room, period, time and teacher all in the name; 0 `aria-hidden` children inside.

**Stepper:** "Previous day" / "Next day" / `input[type=date]` "Pick a date (Wed 2 Sept)"
`[41a01fe]` → "Pick a date (Wednesday, 2 September)" `[bc3b7c9]`; "Back to today" only when the
shown day ≠ today.

**`document.title` per route** (14 routes, `[41a01fe]`): "Home · HOney" (h1 "Hi, 沈高远" — title ≠
h1), "Timetable · HOney" (h1 the day — ≠), "Experiences", "Find someone or something", "History",
"Settings", "Your notes & posts", "Share an experience", "ChenJenny", "Why this space exists",
"Page not found", "Sign in", "Dash". **titleMatchesH1 on 12/14**; the two exceptions are Home and
Timetable, both deliberate.

### Screen-reader text and decoration

**[A-R10-17]** `sr-only` content, whole app: exactly one node — `p.sr-only[role=status]` on the
Feed. `aria-hidden="true"` decorations: the rail/mobile nav pills, every nav `<svg>`, `div.ptr`,
the appearance `i.swatch` chips, `span.daynav__date-short` ("Wed 2 Sept" — the long form is
exposed), the `div.timeline__hours` container (so all 12 hour labels "09:00…20:00" are hidden
from AT — the times are already inside each lesson block's name), the post `span.post__dot`
separator, and the two gesture layers (`.ptr`, `.pullup`). **Nothing meaningful is hidden except
the pull labels** ([A-R10-20]). The lesson dialog's description
`p.sr-only#lesson-dialog-body` reads "09:00 to 10:30, with ChenJenny, in room 213." and the
visible `<dl>` then repeats it ("Time 09:00–10:30 · Topic … · Teacher ChenJenny · Course … ·
Room 213") — one duplicated sentence per dialog open, unchanged from r9. Provenance line
"from someone who has taken this over time" and published day "1 Sept 2026" are plain text inside
the post, both exposed. Entity counts: plain text, no live region ([A-R10-14]).

### Zoom and text scaling `[9c3b23f/60c8672]`

**[A-R10-18]** `r10-a11y-zoom.log`. (a) Layout viewport 195×422 (the CSS viewport a 200 % browser
zoom produces from 390×844), 8 routes: **`document.documentElement.scrollWidth − clientWidth =
125 px on 8/8 routes`** — the page requires horizontal document scrolling at that width; the
scroll owner itself does not overflow (`ownerScrollX = 0`) and no element crosses the right edge,
so the 125 px comes from a floor on the shell's width. One clipped element:
`span.post__provenance` `overflow-x: hidden` with `scrollWidth 305` vs `clientWidth 122` on the
Feed — the provenance line is visually truncated with no way to read the rest. Controls stay
operable (4–20 per route, none below 24 px); a dialog opened at that size is 320 wide × 285 tall,
does not overflow the viewport bottom and needs no internal scroll.
(b) Text scaling: setting the root font-size to 32 px changes **nothing** — `body` stays 16 px,
`h1` 24/28 px, `p` 13–17 px on `/home`, `/experiences`, `/settings` (`FOLLOWS=false` 3/3). The
served CSS has **64 `font-size` declarations: 11 literal px, 53 `var(--fs-*)`, and 0 `rem`**; the
eight `--fs-*` tokens are all absolute px (12/13/15/16/17/20/22/28). A user's browser text-size
preference has no effect on the app.

### Touch targets (`hasTouch`)

`[41a01fe]`/`[60c8672]` `r10-a11y-semantics.log`: **290/290 ≥ 44 px in both dimensions at
390×844 and at 320×568**, across 16 routes (Home, Timetable, Timetable-empty, Feed, Explore,
Explore-with-Recent, History, History-select, Settings, Mine, Compose-chooser, Compose-editor,
Entity, Why, Dash, 404) — **0 sub-44**. Dialogs: `r10-a11y-dialogs.log`, every dialog button
44–410 × 44, **0 sub-44** across 7 dialogs × 2 viewports. Find mode and the chooser are inside
that census (Explore 26–27 controls, Compose-chooser 12) — all ≥44.
`[bc3b7c9]` `r10-a11y-semantics-bc3b7c9.log`: **286/288**, the 2 sub-44 being
`a.daynav__history-sr "History"` at 1×1 (Timetable and Timetable-empty) — **72×32 when focused**
([A-R10-20]). Timetable-only census `[bc3b7c9]`: 11/11 visible controls ≥44 at both widths.
Off-census: the login checkbox 22×22 inside its 342×132 label; the two 42×44 reaction pills
inside a Find-mode results section.

### Reduced motion

**[A-R10-19]** `[60c8672]` `r10-a11y-motion.log` and `[bc3b7c9]` `r10-a11y-gestures.log` /
`r10-a11y-motion-bc3b7c9.log`. Under `reducedMotion: "reduce"`:
`.modal` `sheet-up` **1e-06 s**, overlay `fade-in` **1e-06 s**, `.view` `settle` **1e-06 s**,
skip-link transition **1e-06 s**, `.ptr__disc` transition **1e-06 s** and animation `none`,
`.pullup` transition **1e-06 s**; scroll owner `scroll-behavior: auto` (vs `smooth`).
The skip-link jump is **1 discrete scroll sample** under reduce vs **8** under no-preference
(samples 12 → 82 → 230 → 327 → 358 → 384 → 394 → 400). The compact landing is **one step** under
both. `document.getAnimations()` after a pull release: **0 under reduce, 1 under no-preference**
(the refresh spinner — state, not idle). Non-collapsed durations under reduce, enumerated over
every element on `/home`, `/timetable`, `/experiences`, `/experiences/explore`, `/settings`,
`/history`: **0 on 6/6 routes** (`r10-a11y-final.log`; under no-preference 14 / 20 / 19 / 33 / 26 /
38 respectively, all interaction transitions plus `.view settle 0.46s` and `li.history-row
rise-in 0.5s`). One focus-visibility gap unrelated to motion: the **final Tab segment of the
native `input[type=date]` computes `outline-style: none`** — one keyboard stop per Timetable load
with no visible focus indicator (both builds, 390 and 1280).

### The new phone gestures `[bc3b7c9]`

**[A-R10-20]** `r10-a11y-gestures.log`, `r10-a11y-tt-current2.log`. On phones (`max-width: 700px`,
`features.css:280-296`) `.daynav__row` is `display: none`, which removes **three** things from
both the visual and the accessibility tree: the "Synced N ago" caption, the History button and the
**Sync now** button (all measured at 0×0, `parentDisplay: none`, absent from the Tab order).
Their replacements:

*Pull down.* Synthetic touch drags on `[data-scroll-owner]` produce, in order:
`""` → **"Pull to refresh"** (stage `pull`) → **"Release to refresh · pull further to sync"**
(stage `refresh`) → **"Release to sync with school"** (stage `sync`). Every one of those labels
lives inside `div.ptr` which carries **`aria-hidden="true"` for the whole duration of the pull**
(`PullToRefresh.tsx:136` `aria-hidden={!busy}`), and the `role="status"` disc inside it is
therefore in a hidden subtree (`inHiddenSubtree: true`) with no `aria-label` until release.
Only at release does `aria-hidden` flip to `"false"` and the disc gain
`aria-label="Refreshing"` / `"Syncing with school"`. The sync **outcome** is announced properly:
`div[role=status].banner--success` "Synced 0 lessons from the school portal."
(1 intercepted `/api/sync`, 0 sent to the portal).

*Pull up.* `""` → **"Pull up for History"** → **"Release to open History"**, all inside
`div.pullup[aria-hidden="true"]` (`PullToHistory.tsx:95`) — **never announced**; release
navigates to `/history`.

*Keyboard / AT equivalents.* History: yes — `a.daynav__history-sr` (`TimetablePage.tsx:181`),
1×1 clipped until focused, then `72×32` (**sub-44**, the only sub-44 target on the screen); it is
Tab stop 8 at 390×844. **Sync now: none.** No control, no Tab stop, no keyboard or AT path to a
school sync at ≤700 px; the two-stage touch pull is the only way. "Synced N ago" is likewise
unavailable to any phone user.

*Contrast on the new bar and labels* (both boots, [§1.1](#11-contrast-wcag-143--1411)):
`.daynav__date-long` 13.98 / 13.75, `.daynav__arrow` 5.63 / 7.27, `.daynav__state` 5.34 / 8.07,
`.ptr__label` 5.34 / 8.07, `.pullup__mark` 5.63 / 7.27 — 0 failures. Timetable surface floor
5.63 stone / 7.13 night, 0 enabled text below 4.5:1.

*Touch targets on the new bar:* Previous day 44×44, the `h1.daynav__date` picker 266×44 (the h1
is 268×44), Next day 44×44, lesson blocks 282×95 @390 / 216×61 @320, "Back to today" 104×44 @390
and 104×36 @1280 — **0 sub-44 among visible controls**; the sr History link is the exception above.

*Structure note:* the day heading and the date control are now **one element** —
`<h1 class="daynav__date">` containing `span.daynav__date-long` (exposed),
`span.daynav__date-short` (`aria-hidden`), an `aria-hidden` caret and the `input[type=date]`.
The heading's accessible name is "Wednesday, 2 September" (no year; `formatDayTitle`,
`format.ts:35-40`), against `[41a01fe]`'s separate `h1.schedule-header` "Wednesday, 2 September
2026" (`TimetablePage.tsx:184` at 41a01fe). An interactive `input` now sits inside the `h1`.

## 3. Per-principle FACTS (not scores)

**#2 useful (does the interface do the job for a keyboard / AT user)**
- 48/48 error-surface retries land on a named, ringed region `[41a01fe]`; 4/4 on the Timetable
  `[bc3b7c9]`.
- A keyboard user still lands on `<body>` after one control in the app: History "Select"
  ([A-R10-11]).
- No keyboard path to load-more, to pull-to-refresh, or — on the current build at ≤700 px — to
  **Sync now** ([A-R10-20]); Settings still carries its own "Sync now" (102×44, Tab 9).
- Every other primary action is reachable and ringed (§1.3); Export is disabled by design.
- Find-mode filtering and the Find-mode results section produce no announcement ([A-R10-12]).
- A date step produces no announcement ([A-R10-10]).

**#4 understandable**
- Feed status now matches the visible sentence on the selected tab and says "12 more" on
  load-more; it re-announces an unchanged tab's count on every tab switch; no `aria-atomic`.
- The 404 tells sight and AT different things about which tab is current ([A-R10-9]).
- "Reconnect only" / "Reconnect and save login" and "Save login" / "Sign in without saving" now
  change with the tick.
- One provenance register everywhere ("from a class you've taken" / "from someone who has taken
  this over time" / "from a student here"); the error region is now "Could not load" beside a
  "Could not reach the HOney server…" alert (two spellings of one failure remain).
- `section[aria-label="Experiences that mention this"]` vs the visible heading
  `Experiences that mention "chem"` ([A-R10-12]).
- 25 identically-named "Select" buttons on `/history?select=1` ([A-R10-15] census).
- `main` unnamed on 16/16 routes; the search input in no `search` landmark.

**#8 thorough (focus / pending / disabled / error states)**
- Focus: 202 Tab stops ringed, 0 rest-state rings, ring vs adjacent ground 5.81–6.13 stone /
  8.36–9.28 night. One unringed stop: the last segment of the native date input ([A-R10-19]).
- 20/20 dialog exits at 390 and 23/23 at 1280 restore a mounted opener; traps hold 0/0 over 60
  presses each ([A-R10-3], [A-R10-4]).
- Pending: focus is kept, `aria-disabled` is set, one POST per pass, and a `role=status` says
  "Saving your reaction…" — which is then never cleared ([A-R10-5]).
- Disabled: one recipe, one text colour, 5.34–5.66 / 7.26–8.07, `opacity: 1`.
- Error: every error surface has a banner, a retry and a landing; Compose-`?lessonId=` gained both
  a skeleton and a banner; Explore no longer shows four "Nothing here yet." under its banner;
  **Find mode's server search has no error state at all** ([A-R10-12]).
- Loading: 5 skeleton nodes on Compose-`?lessonId=` while `/api/history` is delayed.

**#9 (reduced motion)**
- Under `reduce`: 0 non-collapsed animations or transitions on 6/6 routes; every named animation
  1e-06 s (sheet-up, fade-in, settle, rise-in, the skip-link transition, both gesture layers);
  `scroll-behavior: auto`; the skip-link jump collapses from 8 scroll samples to 1; the compact
  landing is one discrete step under both preferences; `getAnimations()` 0 after a pull release
  ([A-R10-19]).

## 4. Known gaps in this pass

- **Build churn.** 41a01fe was live for 29 minutes of this pass. `r10-a11y-reach` straddles the
  first redeploy; `-contrast`, `-zoom`, `-names`, `-semantics`, `-motion`, `-disabled` ran on
  intermediate commits (9c3b23f / 60c8672 / bd54519). Contrast, disabled, landmarks and motion
  were re-run on bc3b7c9 and agree (landmark diff empty, disabled diff empty; the only contrast
  movements are on elements the Timetable rewrite removed). The name census, the zoom census and
  the touch census were **not** re-run route-by-route on 41a01fe and are reported at their
  measured build.
- Mine's own feed error branch stays unreachable: with a seeded sentinel ownership key the page
  issues `/api/me`, `/api/directory`, `/api/entities` and never `/api/experiences/mine`, so the
  branch renders "Nothing here yet" instead of a banner (both builds).
- The report dialog's `done` branch description is still source-only; only the form branch was
  exercised (no report was ever submitted).
- The Appearance dialog opener is rail-only and unreachable at ≤640 px; its dialog was exercised
  at 1280 only.
- The two-stage pull was driven with synthetic `TouchEvent`s dispatched on the scroll owner, not
  with a real finger; the label sequence, the stage attributes and the resulting `/api/sync` call
  were all observed, but momentum/scroll-chaining behaviour on a real device was not.
- 200 % zoom was emulated by halving the layout viewport, not by the browser's own zoom.
- No live screen reader was attached; every announcement claim is derived from the DOM
  (`role`, `aria-live`, `aria-hidden` ancestry, and observed text mutations over time).

## 5. Probe inventory

`r10-a11y-landing.js`/`.log` (+ `r10-a11y-land-*.png`) · `r10-a11y-compact.js`/`.log` ·
`r10-a11y-dialogs.js`/`.log` (+ `r10-a11y-dialog-*.png`) · `r10-a11y-find.js`/`.log` ·
`r10-a11y-find2.js`/`.log` · `r10-a11y-feedstatus.js`/`.log` · `r10-a11y-misc.js`/`.log` ·
`r10-a11y-reach.js`/`.log` · `r10-a11y-contrast.js`/`.log` (+ `-bc3b7c9.log`) ·
`r10-a11y-disabled.js`/`.log` (+ `-bc3b7c9.log`) · `r10-a11y-semantics.js`/`.log`
(+ `-bc3b7c9.log`) · `r10-a11y-motion.js`/`.log` (+ `-bc3b7c9.log`) · `r10-a11y-names.js`/`.log` ·
`r10-a11y-zoom.js`/`.log` · `r10-a11y-final.js`/`.log` · `r10-a11y-final2.js`/`.log` ·
`r10-a11y-final3.js`/`.log` · `r10-a11y-tt-current.js`/`.log` · `r10-a11y-tt-current2.js`/`.log` ·
`r10-a11y-gestures.js`/`.log`. Shared helper `r7-px.js` (ring-pixel measurement), harness
`lib.js`. r9 probes were copied, never overwritten.
