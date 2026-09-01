# R1 consolidated evidence

Evidence roles were separated from scoring. Structural, Visual, Weight/Friction, and Accessibility reports met the Design-Is reporting contract. The Copy/Honesty role was stopped after repeated bounded-finish instructions because it did not return a final report; the orchestrator therefore performed one narrow, read-only high-risk claim check and records the missing full string inventory below rather than pretending it exists.

## 1. Structural evidence

Method: static JSX template placements are counted once; mapped rows and mutually exclusive states are represented as formulas rather than falsely summed as one screen. Sources include `apps/web-ionic/src/App.tsx:1-33`, `components/AppLayout.tsx:23-222`, `components/IonicRoutePage.tsx:13-102`, the five core page modules, and supporting route modules.

- Total interactive templates: **123 placements across 21 TSX files**. Shell/shared: 19; Experiences shared/post: 10; Home/Timetable/Feed/Explore/Compose: 48; supporting routes including Settings/Dash/History/Login/Mine: 46.
- Representative runtime counts are data- and breakpoint-dependent:
  - Mobile shell: 4 tab controls (`components/navTabs.tsx:23-28`, `components/AppLayout.tsx:154-160`).
  - Desktop shell: 6 closed-state controls: brand, three destinations, Appearance, account (`components/AppLayout.tsx:80-114,177-188`).
  - Settled Home: mobile `7+P`, desktop `9+P`, where `P=0..2` voice previews (`pages/HomePage.tsx:50,73-149`).
  - Empty Feed: mobile 11, desktop 13 (`pages/experiences/FeedPage.tsx:53-100,113-133`).
  - Loaded Feed: mobile `10 + sum(3+C_i+R_i) + I + N`; desktop adds 2, with contexts/read-more/invites/new-content all conditional (`features/experiences/ExperiencePost.tsx:139-208`, `pages/experiences/FeedPage.tsx:102-147`).
  - Explore: mobile `6+H+E`, desktop `8+H+E`; `H=0..10` history shortcuts and `E` is the complete entity directory (`pages/experiences/ExplorePage.tsx:31-60,85-167`).
- Maximum source-inferred primary-route depth: **29 nodes**, from `IonApp` through authenticated shell, `IonicRoutePage`, Explore grouping, and row link (`App.tsx:10-31`, `components/AppLayout.tsx:36-152`, `components/IonicRoutePage.tsx:46-102`, `pages/experiences/ExplorePage.tsx:101-167`). Conditional Feed report overlay depth: **32** (`features/experiences/ExperiencePost.tsx:234-315`, `components/Modal.tsx:11-29`). React/Ionic internals, portals, and Shadow DOM are excluded.
- Repeated same-purpose placements:
  - Home/Experiences/Timetable appear in both responsive navs: 3 destinations, 6 source entries (`components/navTabs.tsx:17-28`).
  - Start/share an experience: 9 route/state placements (`pages/HomePage.tsx:134-137`, `pages/experiences/FeedPage.tsx:57-60,121-143`, `pages/experiences/MinePage.tsx:129-159`, `pages/TimetablePage.tsx:424-426`, `pages/experiences/EntityPage.tsx:73-85`).
  - Keep-private action: 4 mutually exclusive Compose placements (`pages/experiences/ComposePage.tsx:250-295,342-388`).
  - Appearance: same component in rail modal and Settings (`components/ThemeControls.tsx:19-49`, `pages/SettingsPage.tsx:51-54`).
- Dead props / unused imports: **0 detected**. `pnpm exec eslint apps/web-ionic/src --max-warnings=0` and `pnpm --filter @honey/web-ionic typecheck` both exited 0. This proves syntactic use, not that every consumed prop changes visible behavior.

## 2. Visual evidence

Sources: all ten Ionic and ten matching reference screenshots under `docs/web/evidence/ionic-fidelity/`; live unauthenticated Chromium at `https://ionic.gaelisus.com/login` at 390×844; `styles/tokens.css:13-143`, `foundations.css:68-385`, `components.css:24-954`, `ionic.css:5-403`, and the corresponding page sources.

### Scales and color

- Referenced spacing ladder: **[4, 8, 12, 16, 20, 24, 32, 44]px** (`styles/tokens.css:60-70`). Live Login additionally renders local **[6, 8, 10, 11, 13, 16, 18, 24, 32]px** gaps/padding.
- Signed-in token type ramp: **[12, 13, 15, 16, 17, 20, 22, 28]px**; live Login measured **[13, 16, 17, 44]px**; bounded headings use additional clamps (`styles/tokens.css:41-58`, `styles/foundations.css:101-180`).
- Token source contains **26 distinct normalized hex values** across four surfaces and semantic/Ionic variants. Live Stone Login produced **7 distinct non-transparent serialized colors** after exact-string deduplication.
- Lowest default Stone primary/meta contrast: `--ink-3 #667079` on `--surface #f4f6f7` = **4.658:1**, passing the 4.5:1 normal-text floor (`styles/tokens.css:17-25`).

### Rendered findings

- The screenshots consistently use one humanist sans, cool surfaces, hairlines, one muted accent, and content-dominant feed typography. No decorative illustration, photo, texture loop, or ornamental image appears.
- The responsive shell is stable: four mobile tabs and a 216px desktop rail; feeds remain hairline-separated rather than individually shadow-carded.
- **Source/render discrepancy:** `Your classes` and `Around school` both exist in source (`pages/experiences/FeedPage.tsx:84-99`), but all three Ionic Experiences screenshots show only `Around school`, with no visible `Your classes` label or selected segment. The matching reference screenshots show both labels and a selected state.
- Compose at 390×844 renders a 120px textarea, a large unused vertical interval, and privacy copy beginning behind the bottom tab bar; the matching reference keeps the privacy paragraph readable above the bar (`ionic/mobile-390x844-compose.png`, editor/action/lower viewport regions).
- Timetable at 390×844 begins its lowest legend/content fragment behind the tab bar (`ionic/mobile-390x844-timetable.png`, lower viewport region).
- Desktop Home caps the main column at 940px and leaves a large right-side field; the lesson-progress wash also occupies roughly half the hero without content on that side (`styles/ionic.css:122-127`, `ionic/desktop-1440x900-home.png`).
- Live Login has no horizontal or document overflow; one `main`; a centered 44px wordmark; 17px action/tagline; 13px labels; 44px-minimum fields; and visible focus after one Tab.
- No confirmed orphan selector was found. Shared legacy presentation classes are actively reused or bridged by Ionic selectors.

### Required state checklist

| State | Result | Evidence |
|---|---|---|
| Empty | Present, source-verified | Feed scope-specific empty states `FeedPage.tsx:113-133`; History `HistoryPage.tsx:109-110`. |
| Loading | Present, source-verified | Accessible skeleton `lib/motion.tsx:94-102`; Feed `FeedPage.tsx:108-112`; History `HistoryPage.tsx:105-108`. |
| Error | Present, source-verified | Feed alert `FeedPage.tsx:111-112`; History `HistoryPage.tsx:107-108`; Login consent `LoginPage.tsx:127`. |
| Success/populated | Present, rendered + source | Ten populated screenshots; explicit History status `HistoryPage.tsx:62-65`. |
| Focus | Present, live-rendered | Live Login username, 390×844; shared rule `styles/foundations.css:68-77`. |
| Disabled | Present, rendered + source | Compose screenshot; conditions `ComposePage.tsx:281-297`; style `styles/components.css:97-104`. |

Gaps: authenticated states were not operated live; empty/loading/error/modal/popover/nudge/cooldown were source-verified but not freshly rendered; physical-device and installed-PWA behavior were not measured.

## 3. Copy and honesty evidence

### Coverage and inventory gap

- **Mandatory full string inventory: not completed.** The assigned evidence role failed to return after repeated bounded-finish instructions and was interrupted. The audit therefore does not assert that every literal across all 21 TSX files and the admin Dash was inventoried.
- The orchestrator's bounded check covered the highest-risk user-visible claim areas: `pages/experiences/ComposePage.tsx:120-392`, `pages/experiences/useComposer.ts:1-205`, `features/experiences/ExperiencePost.tsx:15-315`, `pages/experiences/WhyPage.tsx:1-105`, `pages/SettingsPage.tsx:44-238`, `pages/LoginPage.tsx:70-146`, `api/client.ts:94-251`, and `public/manifest.webmanifest:1-16`.

### Concrete high-risk claim findings

- Publication success says the post is stored without an author field and the final publish request carries no ordinary account identity; client publish is explicitly unauthenticated and sends eligibility token, pass, body, and optional rating (`ComposePage.tsx:130-141`, `useComposer.ts:90-103`, `api/client.ts:231-234`).
- The composer labels publication `Share anonymously`, then immediately supplies the narrower guarantee: no author ID, browser-held control key, and private notes remaining local (`ComposePage.tsx:281-305`). The Settings explanation adds recognisability, key-hash, external-model, and local-encryption limitations (`SettingsPage.tsx:198-235`).
- External processing is reachable under `How privacy works`: text-only external moderation via OpenRouter and the provider's own retention policy are disclosed (`SettingsPage.tsx:222-228`).
- Community identity and verification limits are explicit: not a teacher feedback inbox, no post is a final judgment, exposure verification is not fact verification, and reactions are resonance rather than truth votes (`WhyPage.tsx:15-23,60-66,89-97`; `ExperiencePost.tsx:247-297`).
- Consent is opt-in and separate from account login; Stay Connected is also opt-in and describes browser/device limitations (`LoginPage.tsx:83-123`).
- Composer branches preserve the draft and require explicit publish after a nudge; blocked/out-of-scope/failed checks state that nothing published and distinguish local draft preservation (`useComposer.ts:1-7,44-47,106-178`).
- Manifest naming is canonical `HOney`; its description is factual rather than superlative (`public/manifest.webmanifest:1-10`).

### Required flags

- Inflations: **none found in the bounded high-risk claim set**. No marketing superlative was found there.
- Dark patterns: **none found in the bounded high-risk claim set**. Import and credential retention have explicit skip/off paths; nudge does not auto-publish (`LoginPage.tsx:83-143`, `useComposer.ts:162-192`).
- Jargon/unclear labels in the bounded set:
  - `HOney ID` is defined inline as the account name inside HOney (`SettingsPage.tsx:60-64`); plain replacement if needed: `Your HOney account ID`.
  - `Dash` is defined as the operational console for admins (`SettingsPage.tsx:70-78`); plain replacement: `Admin console`.
  - `private-on-this-device` is qualified in the same paragraph (`SettingsPage.tsx:231-235`); plain replacement: `stored only in this browser, with device-level limits`.
- Label→behavior mismatches: **none found in the bounded high-risk claim set**. The visible Feed scope is a render discrepancy, not a source label/handler mismatch.

Known gap: because the mandatory all-string list is absent, the audit cannot promote the honesty result as an exhaustive every-label proof; this uncertainty is handled by the score tie-breaker, not concealed.

## 4. Weight and friction evidence

Sources: production `dist` artifacts, public Login `PerformanceNavigationTiming`/`PerformanceResourceTiming`, package/build config, `App.tsx`, `AppLayout.tsx`, theme/motion sources, CSS animations, and `public/sw.js`.

- Public Login initial entry:
  - Raw/decoded JS: **1,152,054 bytes**.
  - Brotli encoded body: **267,509 bytes**; transferred: **267,809 bytes**.
  - Gzip-9 artifact: **271,846 bytes**.
  - An observed Ionic lazy chunk adds 1,615 raw bytes but was cache-resolved.
- Signed-in Home static lower bound: **1,162,583 raw bytes / 276,501 summed gzip-9 bytes**; incremental Home-specific chunks after shared entry are 10,529 raw / 4,655 gzip bytes. Runtime Ionic custom-element chunks are excluded.
- Fresh public Login navigation: **8 request/resource entries**, 6 non-zero transfers, **329,437 transferred bytes** total. No API request occurred unauthenticated.
- TTI proxy: **590.3ms ESTIMATED**, one run, using `loadEventEnd`; DOM interactive 211.3ms, `DOMContentLoaded` 589.1ms. Wordmark ended 932.5ms and font 1,221.6ms. This is not Lighthouse TTI/INP/TBT.
- Idle animation:
  - Live Login: 0 active continuous; one finished 500ms entrance retained.
  - Current-lesson Home: 1 source-inferred infinite 5.5s pulse (`styles/features.css:78-92`).
  - Current-time Timetable: 1 source-inferred infinite 2.4s pulse (`styles/features.css:332-355`).
  - Experiences: 0 continuous; skeleton shimmer exists only while loading.
- Initial overlays: 0 notifications, badges, modals, or popovers on live Login and the ten screenshot initial states.
- Dark presentation exists as an explicit persisted Night surface, but it does not follow OS `prefers-color-scheme` automatically (`lib/theme.ts:1-84`, `styles/tokens.css:118-143`).
- `prefers-reduced-motion` is respected in both CSS and JS and collapses the two pulses (`styles/foundations.css:370-385`, `lib/motion.tsx:10-91`, `lib/theme.ts:59-75`).
- No video/autoplay media exists. Hashed assets/fonts are cache-first; navigations are network-first; APIs are excluded (`public/sw.js:1-66`).

Gaps: signed-in network/TTI were not live-measured; Home size is an import-graph lower bound; one cold timing run is not a performance study.

## 5. Accessibility evidence

Sources: live unauthenticated Login at 390×844, all ten signed-in screenshots, tokens and responsive styles, AppLayout/Modal/nav/page source, and reduced-motion implementation.

### Contrast by active text token

WCAG 2.x sRGB method; 4.5:1 normal-text threshold. All values are source-calculated; only Stone Login was live-rendered.

| Surface | `ink` | `ink-2`/`muted` | `ink-3` | `accent` | `danger` | `ok` | Result |
|---|---:|---:|---:|---:|---:|---:|---|
| Stone | 13.256 | 5.338 | 4.658 | 5.813 | 5.360 | 5.255 | All pass |
| White | 14.370 | 5.787 | 5.050 | 6.302 | 5.811 | 5.697 | All pass |
| Mist | 12.740 | 5.130 | **4.477** | 5.587 | 5.152 | 5.051 | `ink-3` fails on main surface; passes 4.808 on solid |
| Night | 15.271 | 8.071 | 5.832 | 9.283 | 7.961 | 9.326 | All pass |

White/on-accent passes 6.302:1; Night on-accent passes 9.265:1 (`styles/tokens.css:13-37,103-143`).

### Focus, keyboard, landmarks

- Live Login exact order: School username → Password → Continue with school account. All three are reachable and named; one `main`, one `h1`, zero nav/footer/aside, and zero skip links/alerts/status/live regions initially.
- Signed-in desktop source order: brand → Home/Experiences/Timetable → Appearance → account → **Skip to content** → route controls. The skip link exists but is not first (`components/AppLayout.tsx:76-168`).
- Signed-in mobile source: route controls precede four `IonTabButton`s. Home's primary links; Feed's links/reactions/report controls; Compose's textarea/actions; and Timetable's date/history/sync/lesson controls are native or Ionic controls with names (`pages/HomePage.tsx:52-150`, `pages/experiences/FeedPage.tsx:51-155`, `features/experiences/ExperiencePost.tsx:139-315`, `pages/experiences/ComposePage.tsx:186-310`, `pages/TimetablePage.tsx:59-410`).
- Keyboard reachability: native controls are source-inferred yes; Login is live-confirmed. Ionic segment/tab/textarea/popover/modal are framework-inferred, not authenticated-live verified. Disabled Compose actions are correctly unreachable until enabled. Report close explicitly restores focus to More Options (`ExperiencePost.tsx:234-241`).
- Source-inferred signed-in landmarks: desktop aside + named primary nav + one Ionic main route region; each representative route has one `h1`; modal titles use `h2`.
- Accessible semantics: reactions use `aria-pressed`; overflow uses `aria-expanded`; report has menu/menuitem; modal has label/title/Close; feed is `aria-live=polite`; skeleton is `role=status`; errors are alerts.

### Pointer and focus details

- Base buttons/inputs, modal close, timetable arrows, rating stars under coarse pointers, and mobile tabs meet or exceed 44px (`styles/components.css:60-85,407-420,924-936`, `styles/features.css:190-233`, `styles/ionic.css:264-322`).
- Mobile Feed header tools are **38×38px**, falling to **36×36px below 375px**, without a coarse-pointer 44px override (`styles/ionic.css:324-403`).
- Ionic segment buttons are **42px** minimum without a 44px override (`styles/ionic.css:137-200`).
- Shared native focus is a 3px accent outline + 3px offset and is live-visible; explicit shared rules do not target Ionic hosts, whose Shadow DOM focus treatment was not live checked (`styles/foundations.css:68-77`).

Gaps: no authenticated keyboard/assistive-tech run; Ionic Shadow DOM, focus trap/Escape, signed-in landmark tree, announcements, and physical-device hit testing are inferred from source/framework; no axe/Lighthouse run.

## 6. Cross-principle factual summary

1. Innovative: the product-specific raw-voice/privacy flow is custom, while the shell patterns are standard Ionic tabs/split pane/segment/modal/popover (`components/AppLayout.tsx:76-220`, `docs/web/ionic-fidelity.md:20-33`). No five-peer novelty study exists.
2. Useful: Home exposes Now/Next and direct Timetable/Share paths; Feed is feed-first; Explore keeps the complete finite directory (`HomePage.tsx:52-150`, `FeedPage.tsx:51-155`, `ExplorePage.tsx:31-167`).
3. Aesthetic: one visible type/color system exists, but the missing segment state, two bottom-bar overlaps, and desktop Home imbalance are representative inconsistencies.
4. Understandable: literal navigation and accessible names exist, but the rendered scope control loses one option/selection state and mobile Feed exposes three icon-only title actions.
5. Unobtrusive: content dominates the feed, chrome is quiet, Home caps voice previews at two, and new posts never force-scroll (`ExperiencePost.tsx:139-245`, `HomePage.tsx:50,111-130`, `FeedPage.tsx:102-105`).
6. Honest: all bounded high-risk claims map to client behavior/product truth; full all-string proof is a declared gap.
7. Long-lasting: the surface uses one neutral humanist family, restrained cool palette, hairlines, and standard platform controls rather than a dated decorative theme (`styles/tokens.css:13-70`).
8. Thorough: all six required states exist, but signed-in Ionic focus behavior is unverified and multiple edge details fail the project floor.
9. Environmentally friendly: compressed initial JS is below 500KB but raw decoded JS is 1.15MB; Home/Timetable each have a continuous pulse unless reduced motion is selected.
10. As little design as possible: the primary shell is four mobile destinations/three desktop destinations, Home is Now/Next + at most two voices + two actions, and repeated entry points are direct rather than dashboard layers (`navTabs.tsx:17-28`, `HomePage.tsx:50-150`).
