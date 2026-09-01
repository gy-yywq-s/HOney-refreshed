# Design Is — Round 1 Evidence

## Evidence method and provenance

Five independent evidence subagents were assigned: structural, visual,
copy/honesty, weight/friction, and accessibility. The first accessibility
attempt was blocked by the collaboration thread cap; after completed workers
released slots, a fifth dedicated subagent was created. That final subagent
returned within the root timebox but did not complete defensible live-browser
measurements. The accessibility section therefore consolidates exact facts
already captured by the structural and visual subagents with the orchestrator's
current-head Chromium/source verification. It does not claim an automated WCAG
audit, and the uncompleted checks remain explicit below.

The final target was `web-ionic@ed829f8`. Real Chromium checks covered
`390x844`, `375x667`, and `1440x900`; durable screenshots are in
`docs/web/evidence/ionic-browser-2026-09-01/` and the three additional state
captures in `DESIGN-IS-2026-09-01-ROUND-1/screenshots/`.

## Structural evidence

- Primary navigation is Home / Experiences / Timetable, with Settings separate:
  `apps/web-ionic/src/App.tsx:54-95`.
- Experiences is feed-first, with Explore secondary and the persistent
  student-to-student identity line: `apps/web-ionic/src/pages/ExperiencesPage.tsx:68-95`.
- Explore exposes complete teacher/course/place/food sections and does not make
  search the only discovery path:
  `apps/web-ionic/src/pages/ExplorePage.tsx:25-72`.
- Root viewport ownership and shell breakpoints are explicit:
  `apps/web-ionic/src/theme/app.css:3-15,205-229,334-356`.
- Chromium measurements:
  - `390x844` Home: body `390x844`; visible Ionic content
    `390x733`, scroll height `733`; no horizontal or business overflow.
  - `375x667` Home: content client/scroll height `562px`; the compact
    composition keeps its primary actions and bottom tabs in-frame.
  - `390x844` Experiences: root fixed at `390x844`; the only business
    scroll owner is Ionic content, `637px` client / `2662px` scroll.
  - `1440x900` Experiences: bottom tabs hidden, rail visible, and feed
    internally scrolls at `767px` client / `2339px` scroll.
  - `375x667` Composer: the underlying framed editor is `375x562`, with
    target, editor, status, and both primary actions inside its frame.
- Audited Experiences surface interactive count: **96** at `390x844`:
  38 anchors, 53 Ionic buttons, 2 segment buttons, 3 tab buttons. Thirty-three
  are in the first viewport; the rest belong to the intentional 12-post stream.
  Sources: `ExperiencesPage.tsx:43-45,71-92`,
  `ExperiencePost.tsx:89-128`, `App.tsx:90-92`.
- Primary rendered light-DOM maximum nesting depth: **14** below `IonApp`,
  excluding Ionic Shadow DOM. Deepest sampled path:
  `App.tsx:38-95` → `ExperiencesPage.tsx:68-95` →
  `ExperiencePost.tsx:89-95`.
- Same-purpose repeated affordance families: **5**:
  responsive primary navigation, entity-context links, reactions, add/share,
  and more-options. The add/share family appears 14 times per loaded feed
  page: `ExperiencePost.tsx:108-110`,
  `ExperiencesPage.tsx:72-74,88-92`.
- Dead props / unused imports: **0** under current TypeScript and ESLint checks;
  the repo enables unused-variable errors at `eslint.config.js:4-10`.

## Visual evidence

- Observed spacing values across sampled rendered routes:
  `[1,2,3,4,5,5.27,5.67,5.88,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,22,24,28,32,34,48,55]`.
  Authored rhythm is concentrated around 4/8/10/12/14/16/18/20/24/32, while
  rem and Ionic internals add orphan values. Sources:
  `apps/web-ionic/src/theme/app.css:138-180,232-305`.
- Observed type sizes:
  `[10,10.88,11.2,11.52,11.84,12,12.48,12.8,13,13.12,13.44,14,14.08,14.4,14.72,15.36,16,16.32,16.64,17.28,18.56,22.08,23.2,24.32,28.8]`.
  The hierarchy is visually coherent but much broader than its apparent
  authored scale: `app.css:37-70,80-83,232-247`.
- Sampled rendered/referenced non-transparent colors: **19**. The authored
  light semantic palette has 13 named tokens:
  `apps/web-ionic/src/theme/variables.css:2-14`.
- Primary ink contrast is strong: `#2d2d2b` on white is `13.80:1`,
  on canvas `12.74:1`, and on blue wash `12.23:1`.
- The flat paper/ink/blue palette, 2px geometry, rules instead of card stacks,
  and sparse serif use match the quiet editorial reference:
  `app.css:184-203,232-305`.
- Current head correctly reuses the approved `/wordmark.png`:
  `apps/web-ionic/src/components/Wordmark.tsx:1-3`. Fresh live Chromium
  measured the displayed image at `77.58x26` with natural dimensions
  `570x191`. Favicon and PWA icons also match the existing Web assets.
- Open visual defects:
  - At `375x667`, the fixed fixture strip overlaps the Experiences title by
    approximately `123.7x5.5px`:
    `docs/web/evidence/ionic-browser-2026-09-01/compact-375x667-experiences.png`;
    implementation `app.css:149-162`.
  - Repeated post actions render at `38px` high; add/more can be
    `32x38px`, below the 44px target floor:
    `app.css:263-266`.
  - The intended desktop rail token is `222px`, but Chromium rendered the
    rail at `270px`: `variables.css:17`, `app.css:205-208`.
  - Desktop Home repeats the wordmark in rail and toolbar; Explore stretches
    search/segment controls across the full `1170px` pane while results use a
    `710px` reading spine.

## State evidence

- Empty: `apps/web-ionic/src/components/States.tsx:23-24`;
  feed use `ExperiencesPage.tsx:87`.
- Loading: skeleton with `role="status"` at `States.tsx:4-9`.
- Error: alert, explanation, and optional retry at `States.tsx:12-20`.
- Success/selected: reaction selection uses `aria-pressed` and a rendered
  blue wash; screenshot
  `DESIGN-IS-2026-09-01-ROUND-1/screenshots/design-is-r1-390x844-success-reaction.png`;
  source `ExperiencePost.tsx:63-79,102-107`.
- Focus: 2px deep-blue ring with 3px offset; screenshot
  `DESIGN-IS-2026-09-01-ROUND-1/screenshots/design-is-r1-390x844-focus-home.png`;
  source `app.css:19-23`.
- Disabled: empty Composer disables both 44px primary actions; screenshot
  `DESIGN-IS-2026-09-01-ROUND-1/screenshots/design-is-r1-390x844-disabled-compose.png`;
  source `ComposePage.tsx:133-134`.
- Reduced motion is globally gated:
  `app.css:223-229`.

## Copy, privacy, and honesty evidence

### Strong, aligned claims

- Fixture mode is persistently and accurately labeled “Fixture data · not
  live”: `apps/web-ionic/src/App.tsx:50`.
- Experiences says “For students, between students — not a teacher feedback
  channel,” with a direct Why link:
  `ExperiencesPage.tsx:71-80`.
- Public-storage copy states no author field, distinguishes ownership key from
  identity, and admits connection metadata and social identifiability:
  `apps/web-ionic/src/pages/PrivacyPage.tsx:3-4`.
- Reporting is category-only; disagreement is a reaction and no report free
  text is collected:
  `apps/web-ionic/src/components/ExperiencePost.tsx:20-27,82-86,113-128`.
- Access honestly closes an unsupported Web capability and points to iOS
  without pretending fixture behavior is live:
  `apps/web-ionic/src/pages/AccessPage.tsx:4-5`.
- Current head removed the false-consent redirect loop and hardened
  password-manager autofill submission. These are verified fixes, not findings:
  `apps/web-ionic/src/App.tsx:46-51`,
  `apps/web-ionic/src/pages/LoginPage.tsx:7-35`.

### Open label/behavior and state-truth gaps

- The picker promises a lesson, teacher, course, place, or food, but its list
  maps only entity results. History/timetable are fetched only to resolve an
  already-selected lesson label:
  `apps/web-ionic/src/pages/ComposePage.tsx:49-65,125-141`.
- “Draft saved on this device” appears whenever body text is non-empty, before
  the 500ms write and even when no target makes saving return early:
  `ComposePage.tsx:68-77,130`.
- Cooldown says the user can decide again later, but the saved note drops the
  moderation ticket/retry time and Mine has no resume/recheck action:
  `ComposePage.tsx:84-91,157`;
  `apps/web-ionic/src/pages/MinePage.tsx:71-78`.
- Publish completes before the ownership key is written. If local storage
  fails, the catch reports the operation as failed although the post may
  already be public, contradicting “This device keeps a private control key”:
  `ComposePage.tsx:108-116,159`.
- Privacy says only “configured external language-model processor”; it does
  not disclose current OpenRouter routing, verbatim text transfer, fallback
  processor possibility, unverified no-retention contract, or unpinned region:
  `PrivacyPage.tsx:4`;
  `docs/architecture/moderation-external-processing.md:12-18,26-40`.
- Lower-impact terminology:
  - “Access on Web” is a route to an unavailable explanation:
    `apps/web-ionic/src/pages/SettingsPage.tsx:20`.
  - “Find a context” is internal language:
    `ComposePage.tsx:140`.
  - reaction counts replace visible Match/Different labels:
    `ExperiencePost.tsx:102-106`.

No marketing superlatives, fake scarcity, hidden cost, confirmshaming, ratings
of people, or anonymous-trust badges were found.

## Weight, PWA, and runtime evidence

- Current reconciled entry bundle: **1,334,582 bytes raw / 305,258 bytes gzip**.
- CSS: **56,613 bytes raw / 10,015 bytes gzip**.
- Cold initial lifecycle: **approximately 13 requests**. Method: document,
  entry JS, CSS, manifest, favicon, Ionic runtime chunks, Workbox registration,
  service worker, and Workbox runtime. This is an estimate with about ±3
  request uncertainty, not a trace.
- TTI: **approximately 1,200ms**, estimated from ~315KB gzip critical JS/CSS,
  1.33MB parse/compile, and Ionic/React hydration on an unthrottled modern
  desktop. No field or throttled lab trace was obtained.
- Idle animation count: **0 explicit animations**.
- Initial notification/badge/modal count: **0**. Fixture mode adds one factual
  non-interactive strip.
- The entry is monolithic; generated `p-*` files are small Ionic runtime
  chunks rather than route-level page splitting.
- PWA manifest declares standalone mode and 192/512 icons:
  `apps/web-ionic/vite.config.ts:8-29`. This proves browser-delivered PWA
  metadata, not an installed PWA.
- API paths are denied from navigation fallback and no runtime API cache exists:
  `vite.config.ts:25-30`.
- Fresh checks after deployment reconciliation confirmed live HTML, local dist,
  and live `sw.js` all reference `index-SUH4tAt7.js` and
  `index-DbkU3pfX.css`. The moving-deploy hash mismatch is withdrawn.
- Open runtime details:
  - Cloudflare serves `sw.js` with `Cache-Control: max-age=14400` despite
    origin intent `no-cache`: `apps/web-ionic/server.mjs:21-24`.
  - Cloudflare injects an inline loader and analytics script that the strict
    `script-src 'self'` policy blocks. Fresh Chromium recorded two CSP errors.
    The application rendered, but the console is not clean:
    `server.mjs:21-28`.

## Accessibility evidence

- Token contrast on the light paper surface:
  - ink `#2d2d2b`: **13.80:1 pass**;
  - muted `#6f706c`: **4.99:1 pass** for normal text;
  - faint `#9a9b96`: **2.80:1 fail** for normal text;
  - deep blue `#347da8`: **4.52:1 pass** for normal text;
  - white on fixture warm `#8c6b4c`: **4.86:1 pass**;
  - red `#a6574e`: **5.13:1 pass**;
  - success `#497861`: **5.07:1 pass**.
  Dark-mode ink/muted/faint/blue/warm/red/success all measured at **5.48:1
  or higher** on `#181917`. Token source:
  `apps/web-ionic/src/theme/variables.css:2-14,42-65`.
- The failing faint token is used for 0.74–0.78rem metadata and composer status:
  `app.css:69-70,260,289,303-304`.
- Home keyboard order observed: skip link → account/settings → timetable →
  See all → two experience previews → Share → School Portal → bottom tabs.
  All are native anchors/Ionic buttons and keyboard reachable.
- Experiences primary actions have accessible names in source:
  `ExperiencePost.tsx:102-111`; reaction selection uses `aria-pressed`.
- Modal controls are Ionic buttons/search/list items and the current source uses
  `IonModal`, which supplies a dialog role; a full focus-trap cycle was not
  completed under the timebox:
  `ComposePage.tsx:139-143`.
- Landmark count on mobile Home: **3 landmark elements** — banner plus two
  main landmarks. Desktop adds the navigation rail. Ionic `IonContent`
  exposes a main role while each page nests a literal `<main>`, producing
  duplicate main landmarks:
  `App.tsx:62-95`, `HomePage.tsx:29-83`.
- Skip link: **present**, `App.tsx:39`, styled at `app.css:25-35`.
  Its target is not focusable, and every retained route reuses
  `id="main-view"`; after Ionic retains a hidden route, the first ID may point
  to hidden content. The link therefore does not reliably move focus past
  navigation.
- Primary mobile post action hit areas are not all keyboard-inaccessible, but
  several fail the 44px pointer target floor at 32–87px wide by 38px high:
  `app.css:263-266`.

## Known gaps

- Browser evidence is Chromium Web, not installed PWA, iOS standalone, or
  WebKit safe-area evidence.
- Empty/loading/error were source-confirmed but not frozen in a visual run.
- No real virtual-keyboard test, installed/offline reload, throttled performance
  trace, or complete modal focus-trap cycle was completed.
- iOS edge-drag overscroll remains unproven; no explicit
  `overscroll-behavior` is present.
- Live fixture evidence is not evidence of live backend correctness.
