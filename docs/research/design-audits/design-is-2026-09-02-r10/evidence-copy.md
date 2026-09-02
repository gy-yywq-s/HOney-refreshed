# evidence-copy — Copy & Honesty / Integrity (r10)

Anchor IDs `[C-R10-n]`. Target: deployed `41a01fe` on `integration/product-v2`, https://honey.gaelisus.com,
measured 2026-09-02, in-page today 2026-09-02. Harness `/root/claude-work/design-audit/`, probes
`r10-copy-*.js` / `.log` / `.png`. Every string below was read **as rendered** in the state named;
source `file:line` is `apps/web/src/…` unless prefixed `packages/`. **No verdicts, no scores.**
No post was published (every `POST /api/experiences/publish` was aborted at the route level, 0 attempts
logged), no report submitted, no Settings mutation confirmed, no reaction POST forwarded (fulfilled from
a mock), every browser closed.

---

## 0. r9-move verification table (live)

r9 move 3 = "one truth per channel"; the r9 Preserve list holds the honesty map. Verdicts are per
**rendered** evidence.

| # | r9 move / claim | Verdict | Rendered evidence |
|---|---|---|---|
| 0.1 | Reconnect dialog label follows the tick on **both** purposes | **CONFIRMED** | `r10-copy-dialogs.log`. save+ticked (default) `"Save login"`; save+unticked `"Sign in without saving"`; save+re-ticked `"Save login"`; reconnect+unticked (default, no stored cred) `"Reconnect only"`; reconnect+ticked `"Reconnect and save login"`. Source `components/ReconnectDialog.tsx:39-48`. |
| 0.2 | "Continue without saving" names the sign-in | **CONFIRMED** | Rendered submit is now `"Sign in without saving"` (`ReconnectDialog.tsx:44`); the string `"Continue without saving"` is gone from the source (census delta, removed). |
| 0.3 | "Delete account" row + confirm body say what stays / what is cleared | **PARTIAL** | Confirm body (rendered): `"This permanently removes your account and your imported lessons; shared teacher, course, room and lesson entries stay, and published experiences stay (they carry no author ID). The school login saved on this device is cleared. This cannot be undone."` (`SettingsPage.tsx:309`). The **row** still reads `"Removes your HOney account and your imported lessons (shared teacher, course, room and lesson entries stay). Published experiences stay — they carry no author ID and are controlled only by the keys on your devices."` (`SettingsPage.tsx:96-98`) — it does **not** mention the saved school login. |
| 0.4 | `SettingsPage`/`AuthContext` clear `portalCredentials` on delete | **CONFIRMED (code)**, with an ordering note | `SettingsPage.tsx:316` `portalCredentials.clear();` runs **before** `api.deleteAccount()` at `:317`. `AuthContext.tsx:54` clears on sign-out. Not exercised live (destructive). |
| 0.5 | Feed status per tab ("Nothing from your classes yet" on the class tab) | **CONFIRMED** | `r10-copy-feed.log`: class tab status `"Nothing from your classes yet"` beside the visible `"Nothing from your classes yet. A small honest note is enough. Share the first one"`; school tab status `"Nothing has been shared yet"` beside `"Nothing has been shared yet. A short thought is enough to begin. Share an experience"`. `FeedPage.tsx:44`. |
| 0.6 | "N more" on load-more | **CONFIRMED** | `r10-copy-loadmore.log`: page 1 status `"12 experiences"` → after the sentinel fired (18 posts) `"6 more"`. Poll trace shows exactly one transition. `FeedPage.tsx:46`. |
| 0.7 | No re-announcement on a tab change | **PARTIAL** | Equal counts: `r10-copy-feed2.log` EQUAL-COUNT trace — text never changes across two tab changes (3 items both tabs). Different counts: DIFFERENT-COUNT trace emits **`"4 more"` then `"7 experiences"`** for a single tab change (3→7) — a spurious extra announcement. See `[C-R10-12]`. |
| 0.8 | Home and Timetable use one date formatter | **CONFIRMED** | Same day, `r10-copy-sweep.log` + `r10-copy-misc.log`: Home `.home-head__date` `"Wednesday, 2 September 2026"`; Timetable `h1.schedule-header` `"Wednesday, 2 September 2026"`. `HomePage.tsx:47` now calls `formatDayHeading` (`format.ts:35`). |
| 0.9 | `formatTime` locked to en-GB | **CONFIRMED** | `lib/format.ts:27` `toLocaleTimeString("en-GB", …)`. Rendered under `locale:"en-GB"`, `"en-US"`, `"zh-CN"` (`r10-copy-misc.log`): hour rail `09:00 / 10:00 / 11:00`, block `"09:00–10:30"`, Home next `"13:30–15:00"` — byte-identical in all three. |
| 0.10 | One provenance map (Feed, Entity, Mine, `shared.tsx` = `ExperiencePost.tsx`) | **CONFIRMED**, with a dead-fallback residue | `shared.tsx:16-21` `PROVENANCE_LINE` is now the single map, re-exported and consumed by `ExperiencePost.tsx:19,151`. Rendered feed (`r10-copy-feed.log`): `"from a class you’ve taken"`, `"from someone who has taken this over time"`, `"from a student here"`. Rendered Mine (`r10-copy-mine.log`, seeded keys): the identical three. Residue: `shared.tsx:24` still returns the old register `"Verified school member"` as the unknown-provenance fallback. |
| 0.11 | One storage-caveat sentence | **REFUTED** | Five distinct rendered shapes remain (`r10-copy-dialogs.log`, `r10-copy-sweep.log`) — see `[C-R10-6]`. |
| 0.12 | One spelling of the load failure | **CONFIRMED** | Compose region `aria-label="Could not load"` (`ComposePage.tsx:230,257`) over the alert `"Could not reach the HOney server. Check your connection and try again."` (`api/client.ts:439`) — both "Could not …". The r9 `"Couldn’t load"` spelling is gone (census delta, removed). |
| 0.13 | `···` menu → a direct "Report" | **REFUTED** | `r10-copy-dialogs.log`: trigger `{"text":"···","ariaLabel":"More options","haspopup":"menu"}` → menu `aria-label="Post options"` → items `["Report"]`. Unchanged from r9. `ExperiencePost.tsx:249,258`. |
| 0.14 | Explore under an error shows the banner without "Nothing here yet." | **CONFIRMED** | `r10-copy-errors.log` EXPLORE entities-down / directory-down / both-down: `empties: []`, one alert, 0 section headings. `ExplorePage.tsx:124` `entities.error || directory.error ? null : …`. New residue: the "everything is listed below" helper still renders — `[C-R10-14]`. |
| 0.15 | Lesson dialog description = one sentence | **CONFIRMED** | `#lesson-dialog-body` textContent `"09:00 to 10:30, with 陈拯侃, in room 416."` (`r10-copy-dialogs.log`); visible `<dl>` repeats Time/Topic/Teacher/Course/Room. |
| 0.16 | 404 copy incl. nested paths and the signed-out wrong address | **PARTIAL / REFUTED** | Copy CONFIRMED: title = h1 `"Page not found"`, body `"That page doesn’t exist."`, button `"Go home"` (`NotFoundPage.tsx:13,16`). Nested paths **REFUTED for assistive tech**: `/experiences/new` and `/timetable/oops` render `aria-current="page"` on the rail *and* mobile nav while `is-active` is false — see `[C-R10-11]`. Signed-out wrong address **REFUTED (unchanged)**: `/nonsense` signed out is the login page, title `"Sign in · HOney"`, with no line saying why (`r10-copy-sweep.log` SIGNED-OUT /nonsense). |
| 0.17 | Timetable note on lesson and empty days | **CONFIRMED** | Lesson day: `"P1–P6 are the school’s six lesson periods. Last synced 9 h ago."`; empty day (2026-09-06 / 2026-08-22): `"Last synced 9 h ago."` — no leading space. `r10-copy-sweep.log`, `r10-copy-misc.log`. |
| 0.18 | "1 experience" / "N experiences" | **CONFIRMED** | Real feed `"1 experience"`; 12 mocked items `"12 experiences"`; 3 items `"3 experiences"` (`r10-copy-feed.log`, `r10-copy-feed2.log`). |
| 0.19 | Feed status silent on error | **PARTIAL** | Cold error: status `""` with exactly one `role=alert` (`r10-copy-feed.log` FEED ERROR). After a successful load then an error: status keeps **`"12 experiences"`** while the panel shows only the alert — `[C-R10-13]`. |
| 0.20 | WhyPage "strongly protected" (r9's one inflation) | **STILL PRESENT** | Rendered `r10-copy-sweep.log` /experiences/why: `"HOney narrows what the public space will carry before publication, so ordinary peer speech can be strongly protected."` `WhyPage.tsx:73`. |

---

## 1. Required fields

### 1a. User-facing string census

**968 distinct user-facing-ish strings across 41 files** (probe `r10-copy-census.js`, log
`r10-copy-census.log`); baseline `eede644` re-measured with the same extractor = **937** (matches
`[C-R9-21]` exactly), log `r10-copy-census-eede644.log`. Delta log: `r10-copy-delta.log`.

Per file (current / Δ since `eede644`; files with Δ=0 abbreviated):

| file | strings | Δ |
|---|---|---|
| `pages/DashPage.tsx` | 110 | 0 |
| `pages/experiences/ComposePage.tsx` | 93 | +2 |
| `pages/SettingsPage.tsx` | 88 | 0 |
| `api/client.ts` | 78 | +6 |
| `pages/TimetablePage.tsx` | 75 | +1 |
| `pages/experiences/shared.tsx` | 69 | +1 |
| `pages/experiences/MinePage.tsx` | 54 | 0 |
| `pages/experiences/WhyPage.tsx` | 44 | 0 |
| `features/experiences/ExperiencePost.tsx` | 40 | −1 |
| `pages/experiences/FeedPage.tsx` | 34 | +4 |
| `pages/experiences/EntityPage.tsx` | 34 | +6 |
| `pages/experiences/ExplorePage.tsx` | 31 | +6 |
| `pages/HomePage.tsx` | 30 | 0 |
| `components/ReconnectDialog.tsx` | 19 | +4 |
| `pages/LoginPage.tsx` | 18 | +2 |
| `lib/recentContexts.ts` | 2 | +2 (new file) |
| (25 other files) | 0 Δ | |

Raw delta 56 added / 25 removed. Filtering to genuinely user-facing strings: **27 added, 20 removed,
0 changed-in-place** (a changed sentence appears as one add + one remove).

**Added (user-facing), quoted:**

1. `"Sign in without saving"` — `ReconnectDialog.tsx:44`
2. `"Reconnect and save login"` — `:46`
3. `"Reconnect only"` — `:47`
4. `"Saving your reaction…"` — `ExperiencePost.tsx:158`
5. `"Your school day, without the portal friction."` — `LoginPage.tsx:37`
6. `"Use your school account. HOney creates no separate password."` — `LoginPage.tsx:38`
7. `"This permanently removes your account and your imported lessons; shared teacher, course, room and lesson entries stay, and published experiences stay (they carry no author ID). The school login saved on this device is cleared. This cannot be undone."` — `SettingsPage.tsx:309`
8. `"What was it like for you?"` — `ComposePage.tsx:26`
9. `"Specific details can help someone understand. A feeling can matter too."` — `:27`
10. `"Could not load"` (region name, ×2) — `:230`, `:257`
11. `"An experience is about one of your own lessons, or a teacher, course, place or dish."` — `:330`
12. `"Your recent lessons"` — `:334`
13. `"Keep this for yourself"` (×3) — `:439`, `:494`, `:533`
14. `"This can be shared as it is. Is there anything that would help someone understand what you mean?"` — `:476-477`
15. `"Add a little context"` — `:491`
16. `"Your words are saved. Come back after the pause if you still want to share them."` — `:523`
17. `"This is a pause, not a judgment about your experience."` — `:526`
18. `"N experiences" / "1 experience" / " across N courses" / " with N teachers"` — `EntityPage.tsx:143-148`
19. `"No one has shared an experience here yet."` — `EntityPage.tsx:180`
20. `"Recent"` (section + heading) — `ExplorePage.tsx:107-109`
21. `"Experiences that mention this"` (aria-label) / `"Experiences that mention “{q}”"` (heading) — `ExplorePage.tsx:136,137`
22. `"Nothing from your classes yet"` (status) / `"${n} experiences"` / `"${n − prev} more"` — `FeedPage.tsx:44,46`
23. `"What school feels like, from people who were there."` — `FeedPage.tsx:78`
24. `"Read what others experienced. Share what it was like for you."` — `FeedPage.tsx:80`
25. `"A small honest note is enough."` — `FeedPage.tsx:160`
26. `"We couldn’t understand part of this well enough to publish it. Say it more directly."` — `shared.tsx:52`
27. `"This wording can’t be shared here yet. Remove the insult or private detail, then say what happened or how it felt. Nothing was kept — your draft is still here."` — `useComposer.ts:44`; `"This sounds like something that needs real support or action, not a public post. HOney won’t publish it or send it to the school. You can keep it for yourself instead."` — `useComposer.ts:45`

**Removed (user-facing), quoted:** `"Continue without saving"`; `"Sign in with your school account."`;
the old delete-account confirm body; `"What do you want to share about this experience?"`;
`"Specific context can help, but it is okay if what you have is only a feeling."`; `"Couldn’t load"`;
`"An experience is about one of your own lessons, or a teacher, place or dish."`; `"Keep private"` (×2);
`"Would you like to add what led you to feel this way? A little context can help others understand. You can still share it as written."`;
`"Add context"`; `"This can still be your experience. Nothing was stored and your draft is safe — after the cooling period you can decide again, with the same words if you still mean them."`;
`"Keep private meanwhile"`; `"No experiences here yet — yours could be the first."`;
`"For students, between students — not a teacher feedback channel."`;
`"When someone shares an experience connected to a class you’ve taken, it will appear here."`;
`"Verified lesson experience"`; `"From someone who has taken this over time"` (as a *label*; the
sentence survives as a *line*); `"HOney could not confidently understand part of this wording. Say it more directly."`;
the old `EDIT_REQUIRED` and `OUT_OF_SCOPE`.

`document.title` per route (rendered, `r10-copy-sweep.log`): `/home` `"Home · HOney"`; `/timetable`
`"Timetable · HOney"`; `/history` `"History · HOney"`; `/settings` `"Settings · HOney"`;
`/experiences` `"Experiences · HOney"`; `/experiences/explore` `"Find someone or something · HOney"`;
`/experiences/why` `"Why this space exists · HOney"`; `/experiences/mine` `"Your notes & posts · HOney"`;
`/experiences/compose` `"Share an experience · HOney"`; teacher entity `"ChenJenny · HOney"`;
never-listed entity `"Not found · HOney"`; `/nonsense`, `/experiences/new`, `/timetable/oops`
`"Page not found · HOney"`; `/login` `"Sign in · HOney"`.

**All-caps small titles: 0.** The rendered census (`r10-copy-sweep.js` `allCapsTitles`, 12 routes)
returns only the course name `"TMUA"` (an `<option>`/`<span>`, `text-transform: none`).
`.eyebrow, .overline { … }` (`styles/foundations.css:105-115`) carries no `text-transform` and
`letter-spacing: 0.01em`.

### 1b. Flagged inflations — **1**

`[C-R10-1]` `WhyPage.tsx:73`, rendered: *"HOney narrows what the public space will carry **before**
publication, so ordinary peer speech can be **strongly protected**."* No mechanism in the code
supports "strongly": publication is identity-free at the row level (`packages/backend/src/db/database.ts:103-121`,
no author column) but there is no protocol unlinkability, and the constitution §2 records that
"Nothing stronger is claimed until genuine protocol unlinkability ships". Unchanged since r9
(`[C-R9-21]`). The same paragraph's honest half is intact: *"anonymity is a design boundary, not
magic."*

No new inflation found. Candidate strings checked and cleared: `"You’re all caught up."`
(`FeedPage.tsx:205`, a factual end-of-stream marker — `feed.end` is the server's `nextCursor === null`);
`"A small honest note is enough."` (an invitation, not a claim); the entity counts (see `[C-R10-20]`
for the one condition under which they are wrong).

### 1c. Flagged dark patterns — **0 / 7**

| category | finding | evidence |
|---|---|---|
| Forced continuity | none | no subscription, trial, or recurring commitment anywhere in the census |
| Hidden cost | none | no price, no charge |
| Fake scarcity / urgency | none | the only countdown is the cooling timer `"Check again in 1 h"` (`ComposePage.tsx:530`), driven by the server's `retryAt` (`useComposer.ts:135`); it disables the button rather than pressuring |
| Confirmshaming | none | every decline is neutral: `"Keep this for yourself"`, `"Sign in without saving"`, `"Reconnect only"`, `"Cancel"`, `"Turn off"`, `"Add a little context"` (`r10-copy-dialogs.log`, `r10-copy-compose.log`) |
| Pre-ticked consent | none, but noted | Login checkbox `stayConnected` defaults **false** (`LoginPage.tsx:22`), rendered unticked. The Save-login dialog opens **ticked** (`ReconnectDialog.tsx:24` `purpose === "save" ? true : portalCredentials.isAuthorized()`) — it is the affordance the student just pressed ("Save school login…"), the tick is the dialog's subject, and un-ticking changes the submit label to `"Sign in without saving"`. The reconnect purpose defaults to the stored state (rendered **unticked** with no stored credential, `r10-copy-dialogs.log`). |
| Nagging | bounded | `SHARE_PROMPT_EVERY = 8` (`FeedPage.tsx:18` (used at `:187`)). Measured: 12 posts → 1 aside; 18 posts → 2 asides, both `"Anything from school you want to put into words? Share an experience"` (`r10-copy-loadmore.log`, `r10-copy-feed.log`). The header Share is suppressed on a true-empty feed (`headerShare=false`, `r10-copy-feed.log`). |
| Misdirection / trick wording | none | no double negatives, no visually-de-emphasised decline; the report dialog offers 6 category buttons and a Close, no default selection (`r10-copy-dialogs.log`) |

### 1d. Flagged jargon / unclear labels — **8**, each with a proposed plain replacement

| # | rendered string (state) | file:line | why unclear | proposed replacement |
|---|---|---|---|---|
| `[C-R10-2]` | `"Your words are saved."` (cooling panel) | `ComposePage.tsx:523` | does not say **where**; on a screen whose whole subject is that nothing is stored server-side at check time, "saved" reads as server-side. It is a device-local draft (`useComposer.ts:110` saves before any network call). | `"Your draft is kept on this device."` |
| `[C-R10-3]` | `"Recent"` (Explore, above the complete listing) | `ExplorePage.tsx:107-109` | recent *what*? It is the last 5 entity pages this device opened (`lib/recentContexts.ts:2-4,17`), not recent experiences or recent lessons; the composer's neighbour list is called `"Your recent lessons"` and means something else. | `"Recently opened on this device"` |
| `[C-R10-4]` | region `aria-label="Experiences that mention this"` vs visible `"Experiences that mention “demo”"` | `ExplorePage.tsx:136` vs `:137` | two names for one region; screen-reader users hear "this" with no antecedent. | make the aria-label the heading (`aria-labelledby`) |
| `[C-R10-5]` | `"Clearing site data permanently removes your control over these posts."` | `MinePage.tsx:144-147` | "site data" is browser-chrome jargon a student will not map to any menu they know. | `"If you clear this browser’s stored data, you lose the only control you have over these posts."` |
| `[C-R10-6]` | five sentence shapes for one fact (the saved school login and its key share one store) | `LoginPage.tsx:59-63`; `SettingsPage.tsx:171`; `SettingsPage.tsx:255-259`; `ReconnectDialog.tsx:29-30` (save body); `ReconnectDialog.tsx:31` (reconnect body) | see `[C-R10-6]` full quotes below | one sentence, reused |
| `[C-R10-7]` | login footnote `"…and again whenever you press Sync now."` | `LoginPage.tsx:70-71` | names a control that does not exist on this screen and that the reader has never seen. | `"…and again whenever you ask HOney to sync (a button in Settings)."` |
| `[C-R10-8]` | trigger `aria-label="More options"` → menu `aria-label="Post options"` → 1 item `"Report"` | `ExperiencePost.tsx:249`, `:258` | three names for one one-item affordance. Unchanged since r9. | a single `"Report"` button |
| `[C-R10-9]` | `"18 experiences across 3 courses."` | `EntityPage.tsx:143-148` | "across 3 courses" does not say whose relation is counted (courses attached to the posts, not courses the teacher runs), and it sits in the same paragraph as `"No single Experience is the whole picture."` | `"18 experiences here, from 3 different courses."` |

`[C-R10-6]` the five rendered caveats, verbatim:
1. Login: *"Portal time-outs reconnect on their own. Your login is encrypted and kept only here, with the key that unlocks it (a browser is less protected than a phone's secure storage). Turn it off in Settings."*
2. Settings row, ON: *"On — routine portal time-outs reconnect on their own. Your login is encrypted and kept only on this device; the key that unlocks it is here too (a browser is less protected than a phone's secure storage)."*
3. Settings notes bullet: *"They are scrambled at rest, so a casual look at browser storage won't read them — but the key sits on this device too."*
4. Save dialog body: *"Enter your school login once; it stays encrypted on this device, with the key that unlocks it (a browser is less protected than a phone's secure storage), so routine portal time-outs reconnect on their own."*
5. Reconnect dialog body: *"If you keep the login on this device it stays encrypted here, with the key that unlocks it (a browser is less protected than a phone's secure storage)."*

All five are **accurate** against `lib/portalCredentials.ts:20-21` (`honey.portal.cred` /
`honey.portal.credKey` in the same `localStorage`) and the file's own honest threat model at
`portalCredentials.ts:10-17`. The defect is register, not truth. Count unchanged from r9 (5).

### 1e. Label → behaviour mismatches — **7** (file:line of BOTH the label and the behaviour)

`[C-R10-10]` **"Delete account" row omits the device clearance the confirm body promises.**
Label: `SettingsPage.tsx:96-98` (row caption, no mention of the saved school login).
Behaviour: `SettingsPage.tsx:316` `portalCredentials.clear()`. The confirm body `:309` states it.
Rendered both: `r10-copy-dialogs.log`. Ordering note: `:316` clears **before** `:317`
`await api.deleteAccount()`, so a failed delete leaves the account alive with the saved login already
gone — the body's sentence describes a completed deletion.

`[C-R10-11]` **A 404 on a nested path tells assistive tech it is the current page.**
Label: `components/AppLayout.tsx:105` passes `aria-current={undefined}` into `NavLink`'s `{...rest}`,
which react-router overwrites with its own `aria-current` afterwards; the mobile `NavLink`
(`AppLayout.tsx:148-157`) never attempts it at all.
Behaviour: `AppLayout.tsx:47-56` `isKnownRoute()` + `:75` `known`, which correctly drops `is-active`.
Rendered (`r10-copy-misc.log`): `/experiences/new` → h1 `"Page not found"`, rail
`Experiences|cur=page|active=false`, mobile `Experiences|cur=page|active=false`;
`/timetable/oops` → `Timetable|cur=page|active=false`; `/nonsense` → all `cur=null|active=false`.
The two channels now **disagree**: the visual says nothing is current, the accessibility tree says the
Page-not-found *is* the Experiences page.

`[C-R10-12]` **A tab change announces "N more".**
Label: `FeedPage.tsx:45-46` (`"${n - prev.count} more"` is meant for load-more).
Behaviour: `FeedPage.tsx:38-50` — the effect can run once with the new `feed.items.length` while
`announced.current.scope` still holds the previous scope, so the "more" branch wins before the
"scope changed" branch does.
Rendered (`r10-copy-feed2.log`, DIFFERENT-COUNT trace, my_classes=3 → school=7):
`"3 experiences"` → **`"4 more"`** → `"7 experiences"`.

`[C-R10-13]` **The feed status keeps a stale count under an error.**
Label: `FeedPage.tsx:179-180` renders `statusText` in the `role=status`.
Behaviour: `FeedPage.tsx:39` `if (feed.loading || feed.error) return;` — the effect returns without
clearing, so the last successful count survives.
Rendered (`r10-copy-feed.log`): after a successful 12-item load, a tab change whose request is aborted
leaves status `"12 experiences"` while the panel shows only
`"Could not reach the HOney server. Check your connection and try again. Try again"`.

`[C-R10-14]` **Explore claims everything is listed while nothing is.**
Label: `ExplorePage.tsx:75` *"Teachers, courses, places and food are all listed below — typing only
narrows the list."*
Behaviour: `ExplorePage.tsx:124` renders `null` for all four sections when
`entities.error || directory.error`.
Rendered (`r10-copy-errors.log`, EXPLORE entities-down): main =
`"Find someone or something Teachers, courses, places and food are all listed below — typing only narrows the list. Back to Experiences Could not reach the HOney server. Check your connection and try again. Try again"` — the promise with an empty page under it.

`[C-R10-15]` **The unclear-wording lane leads with the wrong instruction.**
Label: `useComposer.ts:44` `EDIT_REQUIRED` — *"…Remove the insult or private detail, then say what
happened or how it felt."* — is used for **every** `edit_required` lane.
Behaviour: the reason that actually fired is rendered underneath from `shared.tsx:52` — *"We couldn’t
understand part of this well enough to publish it. Say it more directly."*
Rendered (`r10-copy-compose.log`, LANE unclear, `check` fulfilled with
`{lane:"edit_required", reasons:["expression:uncertain"]}`): the banner reads
*"This wording can’t be shared here yet. Remove the insult or private detail, then say what happened
or how it felt. Nothing was kept — your draft is still here. We couldn’t understand part of this well
enough to publish it. Say it more directly."* — a student told to remove an insult they did not write.

`[C-R10-16]` **"Saving your reaction…" outlives the save.**
Label: `ExperiencePost.tsx:158` sets the note; `:277` renders it as a `role="status"`.
Behaviour: `:166` clears the note only at the **start of the next** `react()` call; the `finally`
block `:181-184` clears `busy` and `pendingValue` but not `note`.
Rendered (`r10-copy-react.log`, react POST fulfilled from a mock after a 3 s delay — never forwarded):
1st tap → `aria-disabled="true"`, no note; 2nd tap → note `"Saving your reaction…"`, focus stays on the
pill (`activeElement` = `"Matches my experience"`) ✓; **3.5 s after the response settled** the note is
still `"Saving your reaction…"` with `aria-disabled` cleared.

`[C-R10-17]` **The out-of-scope banner says the same thing twice, in two registers.**
Label: `useComposer.ts:45` ends *"…You can keep it for yourself instead."*; `ComposePage.tsx:402`
appends *"You can keep it as a private note instead."* whenever `notice.suggestKeepPrivate` is set
(`useComposer.ts:146`).
Rendered (`r10-copy-compose.log`, LANE out_of_scope): *"…HOney won’t publish it or send it to the
school. You can keep it for yourself instead. You can keep it as a private note instead."*

---

## 2. Constitution conformance (§5 canonical lines)

| canonical line (constitution §5) | rendered string (state, probe) | verdict |
|---|---|---|
| Product: **Your school day, made easier.** — *See what's next, open the gate, and learn the things students only learn from each other.* | **absent** — no product tagline renders anywhere in the app (`r10-copy-sweep.log`, 12 routes + signed-out). `/home` opens on `"Hi, 沈高远"`. | **absent** |
| Login: **Your school day, without the portal friction.** — *Use your school account. HOney creates no separate password.* | `/login` signed out: `"Your school day, without the portal friction."` / `"Use your school account. HOney creates no separate password."` (`LoginPage.tsx:37,38`) | **identical** |
| Experiences: **What school feels like, from people who were there.** — *Read what others experienced. Share what it was like for you.* | `/experiences`: `"What school feels like, from people who were there."` / `"Read what others experienced. Share what it was like for you."` + a trailing link `"Why this space exists"` (`FeedPage.tsx:78-81`) | **identical** (link appended) |
| Culture line: *People are more than one experience. Experiences still matter.* | rendered **only** on `/experiences/why` under the heading `"Partial, but still meaningful."`: *"People are more than one experience. Experiences still matter. Read each post as one situated account…"* (`WhyPage.tsx:39`). Not on the Experiences hero, where the constitution lists it. The entity page renders a different sentence: `"No single Experience is the whole picture."` (`EntityPage.tsx:139`). | **present, relocated** |
| Composer: **What was it like for you?** — *Specific details can help someone understand. A feeling can matter too.* Actions *Share anonymously* / *Keep this for yourself*. | editor with a lesson target: label `"What was it like for you?"`, hint `"Specific details can help someone understand. A feeling can matter too."`, buttons `"Share anonymously"` / `"Keep this for yourself"` / `"Cancel"` (`r10-copy-compose.log`; `ComposePage.tsx:26,27,432,439,442`) | **identical** |
| Nudge: *This can be shared as it is. Is there anything that would help someone understand what you mean?* — Share as written / Add a little context / Keep this for yourself. | `"Before you share"` (eyebrow) + `"This can be shared as it is. Is there anything that would help someone understand what you mean?"`; buttons `"Share as written"`, `"Add a little context"`, `"Keep this for yourself"` (`r10-copy-compose.log` LANE nudge) | **identical** (eyebrow added) |
| Cooling: *Your words are saved. Come back after the pause if you still want to share them.* — *This is a pause, not a judgment about your experience.* | `"Publishing can wait"` (eyebrow) + both sentences verbatim; buttons `"Check again in 1 h"` (disabled) / `"Keep this for yourself"` (`r10-copy-compose.log` LANE cooldown) | **identical** (eyebrow added; see `[C-R10-2]` on "saved") |
| Expression revision: *This wording can't be shared here yet. Remove the insult or private detail, then say what happened or how it felt.* | `"This wording can’t be shared here yet. Remove the insult or private detail, then say what happened or how it felt. Nothing was kept — your draft is still here."` + the reason bullet `"Part of the wording targets a person rather than describing the experience."` (`r10-copy-compose.log` LANE edit_required) | **paraphrased** (one sentence appended) |
| Unclear wording: *We couldn't understand part of this well enough to publish it. Say it more directly.* | rendered as a **reason bullet** under the expression-revision banner, never as the lead (`r10-copy-compose.log` LANE unclear; `shared.tsx:52`) | **identical text, wrong position** — see `[C-R10-15]` |
| Out of scope: *This sounds like something that needs real support or action, not a public post. HOney won't publish it or send it to the school.* | `"This sounds like something that needs real support or action, not a public post. HOney won’t publish it or send it to the school. You can keep it for yourself instead. You can keep it as a private note instead."` | **paraphrased** (two sentences appended, one redundant — `[C-R10-17]`) |
| Empty feed: *Nothing from your classes yet. A small honest note is enough.* | class tab, empty: `"Nothing from your classes yet."` / `"A small honest note is enough."` / `"Share the first one"` (`FeedPage.tsx:157-164`) | **identical** |
| — school tab, empty (not in the constitution) | `"Nothing has been shared yet."` / `"A short thought is enough to begin."` / `"Share an experience"` (`FeedPage.tsx:167-175`) | second sentence shape for the same act |
| Empty entity page: *No one has shared an experience here yet.* | listed entity, 0 posts: `"No one has shared an experience here yet."` (`EntityPage.tsx:180`); delisted/registry-down: `"No experiences here."` | **identical** on the listed path |
| Privacy: *Published posts are stored without an author ID. Eligibility and publication are handled separately.* | Settings: `"Published posts are stored without an author ID. The publish request carries no ordinary account identity, so the stored post has nothing that says who wrote it — HOney provides no normal author lookup, for anyone, including admins."` (`SettingsPage.tsx:225-231`). "Eligibility and publication are handled separately" is **not rendered in those words**; the composer footnote says `"A safety check runs first. Published posts carry no author ID; private notes never leave this device."` | **paraphrased** |
| Privacy: *What you write may still make you recognisable to someone who knows the situation.* | Settings: `"The words themselves can still make you recognisable to people who know the situation."`; WhyPage: `"What you write may still make you recognisable to people who know the situation"` (`WhyPage.tsx:73`) | **paraphrased** (WhyPage near-identical; "someone who knows" → "people who know") |

**Forbidden phrasings — 0 hits.** Searched the full 968-string census and the 12-route rendered
sweep for `rate teachers`, `the truth about teachers`, `expose bad teaching`, `student review
platform`, `completely anonymous`, `be kind`, `moderation lane`, `policy version`,
`verified provenance`: **none present on any student surface.** Cryptographic mechanics in primary
copy: the words `sha256` / `AES-GCM` / `hash` appear only in source comments and in `DashPage.tsx`
(admin), never on a student surface; the student-facing mechanics live in the Settings
"How privacy works" list, which is the disclosure surface, and say "one-time ownership key",
"the server keeps only a hash", "scrambled at rest" — plain language.

**Register flags (institutional / marketplace / growth-product):** the closest reading is
`"You’re all caught up."` (`FeedPage.tsx:205`) — a stream-app idiom rather than the app's usual
plainness. `"Share something"` on Home, `"Anything from school you want to put into words?"` and
`"Share the first one"` all read as invitations, not growth prompts. No leaderboard, streak, badge,
score, "trending", "popular", "recommended" or engagement noun appears in the census. Entity pages
render descriptive counts only, and `EntityPage.tsx:52` / `contract.ts:222` both carry the comment
"never a score".

---

## 3. Honesty map (claim → code) and the zero-drift statement

Drift bound, `git diff --stat eede644..41a01fe -- apps/web/src/api apps/web/src/lib/ownershipKeys.ts
apps/web/src/lib/portalCredentials.ts packages/backend/src packages/shared`:

```
 apps/web/src/api/client.ts                            | 12 ++++
 packages/backend/src/experiences/corpus/regression.json | 70 ++++++++++++
 packages/backend/src/experiences/service.ts            | 47 +++++++++
 packages/backend/src/routes/experiences.ts             | 18 ++++
 packages/shared/src/api/contract.ts                    | 15 ++++
 5 files changed, 162 insertions(+)
```

**All 162 lines are insertions; 0 deletions and 0 modifications.** `ownershipKeys.ts` and
`portalCredentials.ts` are byte-identical to `eede644`. The insertions are two new read-only GET
endpoints (`/api/experiences/search`, `/api/experiences/stats`), their client methods and types, and
8 new deterministic-engine regression cases. **No existing privacy claim's code changed.**

| claim (rendered) | code | status |
|---|---|---|
| *"Published posts are stored without an author ID."* (`SettingsPage.tsx:225`) | `api/client.ts:241` `publishExperience(… { auth: false })`; `packages/backend/src/db/database.ts:103-121` `CREATE TABLE experiences` has no author/honey_id column | **true, unchanged** |
| *"HOney provides no normal author lookup, for anyone, including admins."* | no `honey_id` column exists to look up; `DashPage.tsx` census unchanged (110 strings, Δ 0) | **true, unchanged** |
| *"Each publish returns a one-time ownership key stored only in this browser; the server keeps only a hash."* | `db/database.ts:116` `ownership_hash TEXT NOT NULL UNIQUE, -- sha256 of the client-held ownership key`; `lib/ownershipKeys.ts:30` `KEYS_STORAGE_KEY = "HOney.experiences.keys"` (byte-identical to `eede644`) | **true, unchanged** |
| *"Presenting the key is the only way to find or remove your post."* | `api/client.ts:245-251` `myExperiences(keys)` / `revokeExperience(ownershipKey)` | **true, unchanged** |
| *"Your ownership keys exist only in this browser."* (Mine banner, rendered `r10-copy-mine.log`) | same store; the key and the encrypted credential share `localStorage` (`portalCredentials.ts:20-21`), disclosed | **true, unchanged** |
| 6 report categories = backend | UI 6 (`ExperiencePost.tsx:293-299`, rendered as 6 buttons in `r10-copy-dialogs.log`) = shared type 6 (`packages/shared/src/api/contract.ts:381-387`) = backend allow-list 6 (`packages/backend/src/routes/experiences.ts:10`) | **6 = 6 = 6, unchanged** |
| *"no free text is collected"* (report dialog, rendered) | `packages/backend/src/routes/experiences.ts:226` `if (note !== undefined) return reply.code(400).send({ error: "free_text_not_accepted" })`; `ReportExperienceInput` has only `category` (`contract.ts:389-391`) | **true, unchanged** |
| *"Public dates are coarse. Posts show a calendar day only; exact timestamps are never published."* | `lib/format.ts:73-79` `formatDayBucket(day)` from a days-since-epoch integer; rendered `"1 Sept 2026"` | **true, unchanged** |
| Import disclosure names exactly the triggers that exist | rendered `SettingsPage.tsx:200-204`: *"…imported from the school portal when your account is created, and again whenever you press Sync now."*; login footnote `LoginPage.tsx:70-71`. `syncTimetable` has exactly two callers: `packages/backend/src/routes/auth.ts:32` (guarded by `if (result.created)`, comment at `:29-31` "Later sign-ins never import") and `packages/backend/src/routes/data.ts:17` ("Sync now"). Both data types named ("your timetable and history"). | **true, unchanged; verbatim** |
| Delete-flow row-level truth | `packages/backend/src/services/accounts.ts:191-193` `deleteAccount` = `DELETE FROM honey_users`; `:238-240` `deleteImportedData` = `DELETE FROM user_lesson_exposures`. Shared teacher/course/room/lesson rows survive both — matches both rendered captions and both confirm bodies. | **true, unchanged** |
| Delete account also clears the device credential | `SettingsPage.tsx:316` (new) — the confirm body's new sentence is backed. The **row** does not say it (`[C-R10-10]`). | **newly true; row incomplete** |
| External-LLM disclosure | rendered `SettingsPage.tsx:234-243`: *"…the draft text — the text only, never your identity — is sent once to an external moderation model (via OpenRouter) and judged transiently; HOney stores neither the text nor the verdict at check time. The external provider processes the text under its own retention policy…"* | **unchanged** |
| HOney ID line | rendered `"HOney ID: uvxdkj — your account name inside HOney; it is never shown on published experiences."` | **unchanged** |
| WhyPage claims incl. "strongly protected" | `WhyPage.tsx:73` | **still present — `[C-R10-1]`** |
| **NEW** entity counts `"N experiences across N courses"` ↔ `/api/experiences/stats` | UI `EntityPage.tsx:140-148`; backend `packages/backend/src/experiences/service.ts:936-956`. The count predicate (`e.entity_key = ? OR experience_associations(type,id)`) and the page's own stream predicate (`service.ts:639-641` `ctx_teacher_id = ? OR entity_key = ?`) are written from the **same** publish-time fields (`service.ts:474-487`), so they agree for every row published by this code. **One divergence:** `entityStats` carries **no** `HIDE_PUBLIC_EXPERIENCES` guard, while `feed()` (`service.ts:631`), `fromMyClasses()` (`:673`), `:782`, `:847` and `search()` (`:923`) all return empty under it. With that kill switch on, the entity page renders *"18 experiences across 3 courses."* above a stream that shows nothing. — `[C-R10-20]` | **drift: one unguarded surface** |
| **NEW** Find copy `"Experiences that mention “q”"` ↔ `/api/experiences/search` | backend `service.ts:924-931`: `SELECT * FROM experiences WHERE status = 'published' AND body LIKE ? ESCAPE '\'` (LIKE metacharacters escaped), `LIMIT 20`, `ORDER BY published_at DESC`. So the heading's claim — published experiences whose **body** contains the words — is accurate; it is a substring match, so "demo" also matches inside a longer word. Rendered (`r10-copy-errors.log`, q=`demo`): heading `"Experiences that mention “demo”"` over the one post whose body is `"Demo demo demo…"`. **Undisclosed half:** the same response also carries `entities` (`service.ts:921`, `contract.ts:214-219` "entities grouped by type, then matching published experiences"), which `ExplorePage.tsx` never renders — the four entity sections are filtered locally instead. No user-facing claim is false; the contract comment overstates what the web client uses. — `[C-R10-21]` | **claim accurate; contract comment ahead of the UI** |
| **NEW** chooser `"Your recent lessons"` (5 rows) | `ComposePage.tsx:100-104` `api.history({ limit: 5, order: "desc" })`, rendered `.slice(0, 5)` at `:337`. Rendered (`r10-copy-sweep.log` /experiences/compose): IELTS-Speaking Wed 2 Sept, Edexcel Economics-U3 Tue 1 Sept, Edexcel Economics-U3 Mon 31 Aug, CIE Chinese Language & Literature Mon 31 Aug, CIE Physics-A2 Mon 31 Aug — the five most recent lessons in `/history`. Note: this list is **not** `lib/recentContexts.ts`; that file backs Explore's `"Recent"` (`[C-R10-3]`), which is the last 5 **entity pages** opened on this device (`recentContexts.ts:4` `MAX = 5`, `:17` dedupe by path, `:20-22` `localStorage` only, comment `:2-3` "kept on this device only. A convenience, never a signal."). | **true; two different "recent"s under similar names** |
| *"search only filters"* (product decision) | Explore helper `ExplorePage.tsx:75` + `:120-131` renders all four sections whenever the registry loaded; typing filters locally (`r10-copy-errors.log` q=`demo`: `Teachers 0 / Courses 0 / Places 0 / Food 0` each with `"Nothing by that name."`, the sections themselves still present). **No string of the form "N more — search to find the rest" exists** anywhere in the 968-string census. | **honoured** |
| Four background surfaces stay | Settings + Appearance dialog render exactly `Stone / White / Mist / Night` (`r10-copy-sweep.log`, `r10-copy-misc.log`) | **unchanged** |
| No consent gate | `packages/backend/src/routes/auth.ts:26-27` comment + code: "The login payload never touches the consent row (consent-looking fields are ignored)"; no consent control in the 968-string census | **unchanged** |

**Zero-drift statement:** across the nine r9 privacy claims and the code they map to, the diff
`eede644..41a01fe` is **insert-only** and touches none of them; every r9 claim re-verifies as
rendered. Two **new** honesty surfaces shipped with the product-review pass: the entity counts and
Find mode. Of these, the Find copy is accurate; the entity count is accurate except under the
`HIDE_PUBLIC_EXPERIENCES` kill switch, where `entityStats` (`service.ts:936-956`) is the one read
path in `service.ts` that does not check it (`[C-R10-20]`).

---

## 4. Per-principle FACTS (no scores)

### #4 Understandable

- `[C-R10-22]` **Nouns for a post — 4 registers still in play, unchanged.** Rendered on one screen
  (`/experiences`): the page title `"Experiences"`, the status `"1 experience"`, the menu
  `"Post options"`, and the report dialog title `"Report this experience"`. `"post"` also appears in
  the Settings privacy list (*"Published posts are stored without an author ID"*, *"remove your own
  post"*), on Mine (*"finds and removes your posts"*, chip `"Removed"`, dialog `"Remove this post?"`
  / `"Remove post"`), and on WhyPage (*"Read each post as one situated account"*). The composer says
  `"Share an experience"`. Sources: `FeedPage.tsx:78`, `ExperiencePost.tsx:258`, `:324`,
  `SettingsPage.tsx:225-233`, `MinePage.tsx:161-171`, `WhyPage.tsx:39`.
- `[C-R10-23]` **Failure spellings — now one family.** Every error surface in the app renders exactly
  one sentence: `"Could not reach the HOney server. Check your connection and try again."`
  (`api/client.ts:439`, mirrored `shared.tsx:88`), with a `"Try again"` button beside it, on Feed,
  Explore (entities-down / directory-down / both-down), Entity, Mine, Compose (both branches),
  Timetable, History (`r10-copy-errors.log`, 10 surfaces). The two region names that frame it are now
  both "Could not …" (`[C-R10 0.12]`). `"Try again"` is offered on 10/10.
- `[C-R10-24]` **Date grammars across the app — 6 shapes, all en-GB, from 4 formatters.**
  Home heading and Timetable `h1` `"Wednesday, 2 September 2026"` (one formatter now, `format.ts:35`);
  stepper `"Mon 24 Aug"` / `"Wed 2 Sept"` (`TimetablePage.tsx:26`); empty day
  `"No lessons on Sun 6 Sept"` / `"No lessons on Sat 22 Aug"`; post day `"1 Sept 2026"`
  (`format.ts:73-79`); Mine card date `"1 Sept 2026"`; compose chooser row `"Wed 2 Sept"`;
  History month heading `"September 2026"`. Identical under `en-GB` / `en-US` / `zh-CN`
  (`r10-copy-misc.log`); 0 non-English date tokens (the single CJK hit on `/history` is inside a
  course name, `2026年秋活动课`).
- `[C-R10-25]` **Title ↔ h1 parity, 14 routes.** Match: `/experiences/explore`
  (`"Find someone or something"`), `/experiences/why`, `/experiences/mine`, `/experiences/compose`,
  `/history`, `/settings`, `/nonsense`, `/experiences/new`, `/timetable/oops`, teacher entity
  (`"ChenJenny"`). Deliberate difference: `/home` (`"Home"` vs `"Hi, 沈高远"`), `/timetable`
  (`"Timetable"` vs the day name), `/experiences` (`"Experiences"` = h1 ✓). **Mismatch, unchanged
  from r9:** never-listed entity — title `"Not found · HOney"`, h1
  `"Nothing is listed at this address."` (`EntityPage.tsx:81,87`). Signed-out `/login`: title
  `"Sign in · HOney"`, `h1` is the wordmark image with `alt="HOney"` (empty text).
- `[C-R10-26]` **Two "recent" lists with near-identical names** on adjacent screens — `[C-R10-3]`.
- The Timetable URL now stays bare on today (`/timetable` → no `?date=`, `r10-copy-sweep.log`) and
  writes `?date=` on a step; `TimetablePage.tsx:43-49` records the decision in the comment.

### #6 Honest

- `[C-R10-27]` **The publish flow's claims are the code's.** Identity-free publish
  (`api/client.ts:241`), no author column (`db/database.ts:103-121`), hash-only ownership
  (`:116`), coarse public day (`format.ts:73-79`), 6=6=6 report categories, `free_text_not_accepted`
  (`routes/experiences.ts:226`), the external-model disclosure and the import disclosure all verify
  verbatim against the code and re-render unchanged.
- `[C-R10-28]` **The delete story is now honest end-to-end in the dialog** (`SettingsPage.tsx:309`
  + `:316`), incomplete in the row (`[C-R10-10]`), and ordered so a failed delete leaves the device
  cleared anyway.
- `[C-R10-29]` **One overclaim survives** — `"strongly protected"` (`[C-R10-1]`), the same one r9
  found, in the same sentence, on the same page.
- `[C-R10-30]` **One new count can outrun what it counts** — `entityStats` under the
  `HIDE_PUBLIC_EXPERIENCES` kill switch (`[C-R10-20]`).
- `[C-R10-31]` **Three present-tense statements that are not true at the moment they are read:**
  `"Saving your reaction…"` after the save finished (`[C-R10-16]`); the feed's `"12 experiences"`
  over an error banner (`[C-R10-13]`); `"Teachers, courses, places and food are all listed below"`
  over an empty page (`[C-R10-14]`). All three are `role=status`/visible copy, not decoration.
- `[C-R10-32]` **The moderation copy tells the student what happened to their words in every lane**
  (`r10-copy-compose.log`, 7 lanes): nudge, cooling, expression revision, unclear, out of scope,
  blocked, failed-closed all name the outcome and say the draft is kept. Two lanes carry a redundant
  or mis-leading lead sentence (`[C-R10-15]`, `[C-R10-17]`).

### #7 Disabled / loading / error state copy

| screen | disabled | loading (what AT hears) | error | empty |
|---|---|---|---|---|
| Compose (empty body) | `"Share anonymously"` and `"Keep this for yourself"` both `disabled`, no explanation of why; `"Cancel"` enabled (`r10-copy-compose.log`) | `?entityKey=` → registry skeleton; `?lessonId=` → `Skeleton lines={4}` (5 skeleton nodes measured), `role=status` text `""` | region `"Could not load"` + the one alert + `"Try again"` (both branches) | chooser card: `"An experience is about one of your own lessons, or a teacher, course, place or dish."` |
| Compose (checking) | primary reads `"Checking…"`, all three actions disabled | — | banner per lane | — |
| Compose (cooling) | primary reads `"Check again in 1 h"`, disabled | — | — | — |
| Feed | — | `role=status` `""` while loading | `role=status` `""` on a cold error; **stale count on a warm error** (`[C-R10-13]`) | per tab (`[C-R10 0.5]`) |
| Explore | — | `Skeleton lines={6}`, `role=status` `""` | banner + `"Try again"`, sections hidden | per section `"Nothing here yet."`; while filtering `"Nothing by that name."` |
| Entity | — | `role=status` `""` | banner above a loaded stream + `"Try again"` | `"No one has shared an experience here yet."` / delisted `"No experiences here."` |
| Mine | `"Export"` disabled with 0 keys, **no text says why** (`r10-copy-misc.log`, `r10-copy-sweep.log`) | `Skeleton lines={3}` | banner + `"Try again"` | `"Nothing here yet"` + the ownership-key paragraph |
| Timetable | — | `Skeleton lines={4}` | banner + `"Try again"` inside the `"Day timeline"` region | `<p role="status">"No lessons on Sun 6 Sept"` |
| History | — | skeleton | banner + `"Try again"` (filters stay rendered) | — |
| Settings | `"Export"` disabled (also at 1280) | — | — | `"None yet — keys appear here when you publish an experience."` |
| Pull-to-refresh | — | `div.ptr__disc[role=status]` renders with `textContent === ""` in every state measured — the refresh is silent to AT | — | — |

`"Try again"` is offered identically (same label, same `btn--ghost btn--small`) on all 10 error
surfaces.

---

## 5. Known gaps

- The **Reconnect purpose with a stored credential** (dialog default ticked) was not reached: the
  test account has no saved school login, and seeding `honey.portal.cred` with a sentinel makes
  `isAuthorized()` true but leaves the row in the "ON" state, which hides the Reconnect button. The
  ticked reconnect label was measured by ticking the box instead (`"Reconnect and save login"`).
- **Delete account / Delete imported data / Disconnect / Sync now / revoke / report submit** were
  opened and cancelled only — no confirm was pressed, so the post-action feedback copy
  (`"Removed. The post is gone — you can write a new one about this any time."`, the sync result
  banner) is cited from source, not rendered.
- **Home error copy** was not reached: aborting `/api/timetable` still rendered a populated Home
  (`r10-copy-errors.log` HOME ERROR), so Home's own error branch and its `"Try again"` are unmeasured
  this round.
- **`entityStats` under `HIDE_PUBLIC_EXPERIENCES`** is a code-path finding; the kill switch was not
  toggled on the deployed instance (that would affect every student).
- The **stale-sync** copy (`isStale` > 60 min) renders on the live account as
  `" · last synced 9 h ago"`; a longer-stale variant could not be forced (the `/api/timetable`
  rewrite did not reach Home's data path).
- The **published-success panel** (ownership-key hand-off copy) is unreachable without publishing and
  was therefore not measured.
- The string census is a static extractor: it over-counts (comments, identifiers) and under-counts
  (interpolated fragments). The **rendered** sweep, not the census, is the authority for every
  quoted string above.

---

## 6. Probe inventory

All under `/root/claude-work/design-audit/`, all run from that directory, all browsers closed.

| probe | what it produced | log / screenshots |
|---|---|---|
| `r10-copy-census.js` | static census of `apps/web/src` (also run against a `git archive` of `eede644`) | `r10-copy-census.log`, `r10-copy-census-eede644.log`, `r10-copy-delta.log` |
| `r10-copy-sweep.js` | rendered strings, titles, h1/h2, aria-labels, placeholders, status/alert, disabled names, all-caps census on 12 routes + 2 signed-out | `r10-copy-sweep.log`, `r10-copy-login.png` |
| `r10-copy-dialogs.js` | 8 dialogs in every tick state; Settings rows OFF/ON; `···` menu; report categories; lesson description | `r10-copy-dialogs.log`, `r10-copy-dlg-{save,delete-account,delete-data,disconnect,reconnect,report,lesson}.png` |
| `r10-copy-feed.js` | feed status per tab (empty/1/12/error), warm-error residue, provenance lines, invites | `r10-copy-feed.log`, `r10-copy-feed-empty.png`, `r10-copy-feed-18.png` |
| `r10-copy-feed2.js` | polled `role=status` traces across equal-count and different-count tab changes | `r10-copy-feed2.log` |
| `r10-copy-loadmore.js` | load-more via the sentinel; `"6 more"`; end-of-stream; invite cadence at 18 | `r10-copy-loadmore.log`, `r10-copy-loadmore.png` |
| `r10-copy-errors.js` | Explore ×3 failure modes, Find mode (match / no match), Entity (real / never-listed / mocked stats / registry-down), Mine, Compose ×4 branches, Timetable / History / Home errors | `r10-copy-errors.log`, `r10-copy-{explore-*,find-*,entity-*,compose-*}.png` |
| `r10-copy-compose.js` | editor copy + all 7 moderation lanes via a fulfilled `/api/experiences/check`; publish aborted (0 attempts) | `r10-copy-compose.log`, `r10-copy-compose-{empty,nudge,cooldown,edit_required,out_of_scope,blocked_serious,failed_closed,unclear}.png` |
| `r10-copy-misc.js` | locale lock ×3, nav `aria-current` vs `is-active` on 7 paths, Explore "Recent", disabled census at 1280, Appearance dialog | `r10-copy-misc.log`, `r10-copy-explore-recent.png` |
| `r10-copy-mine.js` | Mine populated (seeded keys + fulfilled `/mine`): provenance register, status chips, remove dialog | `r10-copy-mine.log`, `r10-copy-mine-seeded.png` |
| `r10-copy-react.js` | reaction pending copy; second-activation response; post-settle residue (react POST fulfilled from a mock, never forwarded) | `r10-copy-react.log`, `r10-copy-react-2nd.png` |
| `r10-copy-states.js` | Home variants, PTR status node, compose delisted branch, Explore at 320, empty-day notes | `r10-copy-states.log` |

Safety accounting: 0 posts published (`grep -c "publish attempt ABORTED" r10-copy-compose.log` = 0 —
the flow never reached publish), 0 reports submitted, 0 Settings confirms pressed, 0 reaction POSTs
forwarded to the server, 0 reads of `/home/honey/.secrets/` or `.session.json` by any r10 probe, 0
credentials or tokens in any log or in this file.
