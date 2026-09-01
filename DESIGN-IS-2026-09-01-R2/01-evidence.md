# R2 consolidated evidence

R2 was independently gathered from the current working-tree candidate. `https://ionic.gaelisus.com` is stale and contributes no changed authenticated-surface evidence.

## Structural lane

Sources: `apps/web-ionic/src/main.tsx:14-40`, `src/PublicApp.tsx:1-27`, `src/App.tsx:1-41`, `src/components/AppLayout.tsx:23-167`, `src/components/IonicRoutePage.tsx:38-102`, core route sources, current scoped lint/typecheck/build.

- Public/authenticated entry is now split: `main.tsx` checks local session state and dynamically imports either `PublicApp` or authenticated `App`; Ionic setup/CSS live only in `App`.
- Public Login has its own `<main>` and no Ionic shell. Authenticated content retains one split-pane/tabs shell and one router outlet.
- Static interactive inventory remains **123 source placements across 21 TSX files**. This is a template count; runtime rows and mutually exclusive branches are not falsely summed.
- Representative structural counts:
  - public Login: 6 declarations across Login and form states;
  - authenticated desktop shell: 6 normally visible controls plus the focus-only skip link;
  - authenticated mobile shell: 4 tabs plus the focus-only skip link;
  - Compose, Feed, and Timetable counts remain state/data formulas because target, post, lesson, and overlay cardinality varies.
- Maximum closed primary-route tree: **30 nodes**, through authenticated Explore. Conditional Feed report overlay reaches 32; Ionic Shadow DOM/portal internals are excluded.
- Repeated affordance families: **6 families / 27 static placements**: responsive primary navigation, direct Compose entry points, mutually exclusive Keep-private actions, ThemeControls reuse, Settings entry points, and Back-to-Experiences links.
- Current `eslint apps/web-ionic/src --max-warnings=0` and typecheck report **0 syntactic unused imports/variables/props**. Static callsite inspection identifies **1 semantic dead-prop candidate**, `IonicRoutePage.publicScreen`, because public Login now bypasses that wrapper.
- Skip link is now the first declared `IonSplitPane` child and targets focusable `#ionic-main` before navigation/content (`AppLayout.tsx:75-125`).
- Feed exposes exactly two accepted scopes, both simultaneously rendered; selection updates state and persisted scope (`pages/experiences/FeedPage.tsx:22-105`).

Known gaps: no authenticated runtime DOM cardinality; formulas remain data-dependent; Ionic internal nodes are excluded; the dead-prop candidate is source-observed rather than analyzer-produced.

## Visual lane

Sources: all six files under `docs/web/evidence/ionic-fidelity/r2-candidate/`; local public candidate `http://127.0.0.1:4175/login` at 390×844; `styles/tokens.css:13-143`, `foundations.css:15-390`, `features.css:78-802`, `ionic.css:15-415`, current Feed/Compose sources.

### Mandatory scales and color

- Declared spacing ladder: **[4, 8, 12, 16, 20, 24, 32, 44]px** (`tokens.css:60-70`). Local Login computed component spacing: **[6, 8, 10, 11, 13, 16, 18, 24, 32]px**.
- Declared type ramp: **[12, 13, 15, 16, 17, 20, 22, 28]px** (`tokens.css:41-58`). Local Login rendered: **[13, 16, 17, 44]px**, with 44px being the wordmark heading.
- Active token source contains **27 unique hex colors** after excluding a historical commented value; no `oklch()` token. Local idle Login renders six computed non-transparent color values.
- Lowest active text-role contrast: Mist `--ink-3 #636f77` on `#eef2f2` = **4.574:1**, passing the 4.5:1 normal-text AA floor (`tokens.css:111-118`). Stone tertiary text is 4.658:1; primary body ink is at least 12.740:1 on checked light surfaces.

### Rendered candidate findings

- Experiences at 390×844 shows `Your classes` selected and `Around school` visible; at 375×667 the reverse selected state is rendered. Both labels and the dark selected state survive both breakpoints (`r2-candidate/experiences-*.png`, `FeedPage.tsx:84-105`, `ionic.css:176-210`).
- All three mobile Feed tools are 44×44px; both segment controls are at least 44px, including sub-375 rules (`ionic.css:137-170,176-210,336-415`).
- Compose textarea occupies about 321px height; helper/actions follow without the R1 empty interval. Privacy content ends above the tab bar with a measured 5px terminal gap (`r2-candidate/compose-mobile-390x844.png`, `features.css:650-700,790-802`, `ionic.css:279-287`).
- Timetable terminal content ends 16.8px above the tab bar when maximally scrolled; no terminal label is occluded (`r2-candidate/timetable-mobile-390x844-bottom.png`).
- Desktop rail is 216px; remaining main region is 1224px; Home is an 820px centered column with roughly 202px equal gutters (`r2-candidate/home-desktop-1440x900.png`, `ionic.css:15-27,125-135`).
- Local public Login has `clientWidth=scrollWidth=390`, `clientHeight=scrollHeight=844`, zero settled running animations, and one finished 500ms entrance.
- Home wash and Timetable now marker retain state meaning without infinite animation (`features.css:78-100,331-354`).
- The six images retain one neutral sans, cool stone/white surfaces, narrow accent use, hairlines, and content-led hierarchy; no photo, illustration, decorative gradient, or ambient ornament appears.

### Required state checklist

| State | Result | Evidence |
|---|---|---|
| Empty | Present, source-verified | Scope-specific Feed empty branches, `FeedPage.tsx:119-139`. |
| Loading | Present, source-verified | Feed skeleton `FeedPage.tsx:114-117`; accessible skeleton `lib/motion.tsx:94-102`. |
| Error | Present, source-verified | Feed alert `FeedPage.tsx:117-118`; Compose error branches. |
| Success/populated | Present, rendered | Both Feed screenshots, Home, Compose and Timetable R2 images. |
| Focus | Present, rendered | `login-mobile-390x844-focus.png`; native/Ionic focus rules `foundations.css:73-88`. |
| Disabled | Present, rendered | Disabled Share/Keep-private in Compose; source conditions `ComposePage.tsx:281-297`. |

Known gaps: changed authenticated surfaces were not operated in a live DOM; terminal gaps derive from supplied candidate measurements/screenshots; empty/loading/error are not freshly rendered; non-default surfaces are source-calculated rather than rendered.

## Copy and honesty lane

Sources: `docs/web/evidence/ionic-fidelity/copy-inventory.json`; `apps/web-ionic/scripts/audit-copy.mjs`; `src/lib/copyIntegrity.test.ts:1-53`; Compose/useComposer/Settings/Why/ExperiencePost/client sources; supporting shared/backend behavior was consulted only to validate labels and was not changed.

### Mandatory inventory

- `pnpm --filter @honey/web-ionic audit:copy` exits 0 and produces **407 direct surface strings**, each with `{file,line,context,text}`.
- The same artifact contains an exhaustive **1,512 non-import string-literal superset**, each with `{file,line,syntax,text}`.
- Focused integrity tests pass 5/5 and assert Feed routes/labels, both scope labels, primary navigation, skip-link label/target/order, and deterministic inventory coverage (`copyIntegrity.test.ts:10-52`).
- Canonical visible brand spelling is `HOney`; no user-facing lowercase or title-case brand drift was found.

### Matched claims and behaviors

- `Share anonymously` maps to a publish request carrying eligibility token, pass, body, optional rating, and `{auth:false}`; no ordinary account-identity field is sent (`useComposer.ts:90-104`, `api/client.ts:217-234`).
- Nudge requires a later explicit `Share as written`; it never auto-publishes (`useComposer.ts:106-178`, `ComposePage.tsx:320-354`).
- External text processing through OpenRouter and provider retention responsibility are disclosed in Settings (`SettingsPage.tsx:222-228`); Compose links to `How privacy works` beside the safety-check copy (`ComposePage.tsx:302-305`).
- Reactions are explained as experiential resonance, not truth votes; reports are category-only rule flags rather than disagreement (`features/experiences/ExperiencePost.tsx:169-296`, `WhyPage.tsx:63-96`).
- Timetable import and credential persistence are separate explicit opt-ins (`LoginPage.tsx:93-143`, `SchoolLoginForm.tsx:7-24`).
- No forced continuity, fake scarcity, confirmshaming, hidden cost, or automatic publication was found.

### Inflations and label→behavior mismatches

1. `The note stays only on this device — it was never sent anywhere` and `Private notes never leave this device` are over-absolute for the nudge→Keep-private path: entering nudge already sent the text through `checkExperience` (`ComposePage.tsx:160-168,303-304,329-351`; `useComposer.ts:117-132`).
2. `Nothing was stored` / `Nothing was kept` conflicts literally with local draft autosave and the explicit pre-check save. The narrower behavior is “nothing was published or server-stored” (`useComposer.ts:44-47,65-81,111-112`; `ComposePage.tsx:379-380`).
3. `Presenting the key is the only way to find or revoke your post` / `your only control is a key` omits the authenticated-session requirement in current lookup/revoke behavior (`SettingsPage.tsx:213-216`, `ComposePage.tsx:303-304`; behavior citation recorded in the copy report).

### Jargon

- Ordinary-user terms needing plain wording: `ownership key` → `post-control key`; `relevant exposure` → `first-hand experience with this class, teacher, place, or dish`.
- Admin-only jargon includes `Moderation LLM`, `sealed at rest`, `entity key`, and `fails closed`; suggested equivalents are `automated moderation model`, `encrypted while stored`, `item identifier`, and `blocks publishing when the check is unavailable`.

Known gaps: inventory covers TS/TSX, not CSS content/static HTML/browser-generated/dynamic service strings; behavior was deeply traced for high-risk copy, not every low-risk label; storage-schema and full external-provider request/logging details were not freshly audited.

## Weight and friction lane

Sources: current production build report supplied with the candidate; `src/main.tsx:14-40`, `src/PublicApp.tsx:1-27`, `src/App.tsx:1-41`, build chunks, current theme/motion/CSS source, local public Login settled state.

- Public cold-path chunks:
  - shared entry: **153.58 KiB raw / 49.54 KiB gzip**;
  - PublicApp: **3.02 / 1.36 KiB gzip**;
  - ErrorBoundary: **25.63 / 9.49 KiB gzip**;
  - SchoolLoginForm: **1.21 / 0.58 KiB gzip**.
- Summed public initial JS from those hashed chunks: **183.44 KiB raw / 60.97 KiB gzip** (about **62,433 bytes gzip**). Browser evidence supplied for R2 reports approximately 62 KiB transferred and confirms authenticated `App-CbaASB99.js` is not loaded on the public cold route.
- Authenticated App chunk: **970.93 KiB raw / 214.71 KiB gzip**, plus the shared entry; it still triggers Vite's >500KB raw warning. Route-specific pages remain separately chunked.
- Public initial hashed-JS request count: **4 inferred from the current initial chunk set**. A complete document/CSS/font/image request count was not returned by the bounded performance worker and is recorded as a gap.
- TTI: **not freshly measured in R2**. No stale R1 timing is substituted; this is an explicit evidence gap.
- Idle continuous animations: **0** on settled local Login and **0 source-defined infinite animations** on current Home/Timetable. Route/Login entrances are finite; skeleton shimmer exists only during loading.
- Initial notifications/badges/modals/popovers: **0** in all six R2 initial screenshots and local Login.
- Explicit persisted Night surface honors dark presentation; it remains user-selected rather than OS-auto-selected (`lib/theme.ts:1-84`, `tokens.css:118-143`).
- `prefers-reduced-motion` is respected in CSS and JS (`foundations.css:367-390`, `lib/motion.tsx:10-91`, `lib/theme.ts:59-75`).
- No video/autoplay media exists.

Known gaps: no complete local network waterfall or R2 TTI/INP/TBT trace; signed-in network cost is build-derived; browser `~62 KiB` is rounded; authenticated Ionic runtime lazy-element requests are not enumerated.

## Accessibility lane

Sources: R2 Login focus screenshot/local public browser facts; Feed/Compose/Timetable/Home screenshots; `foundations.css:73-88`, `components.css:1-15,60-104,407-420,924-936`, `ionic.css:137-210,279-415`, current AppLayout and core page sources.

### Contrast

- Stone: ink 13.256, secondary 5.338, tertiary 4.658, accent 5.813 — all normal-text AA pass.
- White: ink 14.370, secondary 5.787, tertiary 5.050, accent 6.302 — all pass.
- Mist: ink 12.740, secondary 5.130, tertiary **4.574**, accent 5.587 — all pass after the R2 token correction.
- Night: ink 15.271, secondary 8.071, tertiary 5.832, accent 9.283 — all pass.
- Method: WCAG 2.x sRGB relative luminance; 4.5:1 normal-text threshold. Only Stone Login is rendered; other surfaces are source-calculated.

### Focus, keyboard and landmarks

- Live local public Login exact order: School username → Password → Continue with school account. First Tab focuses username with a visible 3px accent outline. Public landmark count: **1 main**, 1 h1, no nav/aside/footer, no skip link needed for the three-control doorway.
- Signed-in source order begins with `Skip to content`, then desktop rail controls or route content/mobile tabs. Skip target `#ionic-main` is programmatically focusable (`AppLayout.tsx:75-125`).
- Source-inferred Home order: Timetable → up to two post previews → Share → School Portal → mobile tabs.
- Feed: Share → Find → Mine → two scope options → conditional update → post links/read-more/reactions/more/report → tabs.
- Compose: textarea → optional rating → enabled Share/Keep-private/Cancel → privacy link → tabs. Disabled actions are correctly unreachable until enabled.
- Timetable: previous → date input → next → optional today → History → Sync → lesson buttons → modal controls → tabs.
- Native actions are source-inferred keyboard reachable. Ionic segment/tab/textarea/modal/popover are framework/source-inferred rather than authenticated-live verified.
- Signed-in landmark structure is source-inferred as one primary nav, one rail aside on desktop, and one Ionic main route region. Each core route has one h1; modal title is h2.
- Reactions expose `aria-pressed`; overflow exposes `aria-expanded`; report uses menu/menuitem; modal is labelled; Feed uses `aria-live=polite`; skeleton is status; errors are alerts; report close returns focus to More Options.
- Feed tools, segments, tabs, timetable arrows, base inputs/buttons, modal close and coarse-pointer reactions/ratings now meet or exceed **44px**.
- Explicit focus styling covers native controls and Ionic segment/tab native parts (`foundations.css:73-88`).

Known gaps: no authenticated keyboard/assistive-technology run, Shadow DOM inspection, modal focus-trap/Escape test, rendered non-default surfaces, screen-reader announcement test, axe/Lighthouse run, or physical-device hit-test trace.

## Per-principle factual feed

1. Innovative: public/authenticated delivery now uses a lighter non-Ionic doorway while retaining a full Ionic installed-app shell; no five-peer novelty study exists.
2. Useful: Home still exposes Now/Next and direct Timetable/Share paths; Feed remains default; both Feed scopes and complete Explore discovery remain directly available.
3. Aesthetic: one type/palette/spacing system is visible across the six R2 screens; prior scope, overlap, Compose-gap and desktop-balance inconsistencies are corrected in current evidence.
4. Understandable: both scope labels/selection states and primary navigation labels are explicit; mobile header icons remain compact, while two ordinary-user explanatory terms still require interpretation.
5. Unobtrusive: content dominates, terminal padding does not create a visible card/layer, idle pulses are removed, and initial overlays/badges remain absent.
6. Honest: core anonymous publish, consent, reaction/report, and external-processing claims are supported, but three families of over-absolute storage/control copy conflict with alternate runtime paths.
7. Long-lasting: neutral humanist type, cool narrow palette, hairlines and standard controls remain free of dated ornament.
8. Thorough: all six mandatory states exist; current evidence adds both scope states, terminal geometry, 44px targets, focus, contrast, and desktop centering, with authenticated runtime accessibility still inferred.
9. Environmentally friendly: public cold JS is ~61 KiB gzip and idle animation is zero, but the authenticated initial path remains ~264 KiB gzip / >1.1 MiB raw including entry and App.
10. As little design as possible: the core shell/route structure and element set remain task-bound; the public split removes the entire authenticated shell from the signed-out doorway, with one semantic dead prop left behind.
