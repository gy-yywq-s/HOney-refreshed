# R3 consolidated evidence

R3 scores are independently synthesized from the current working tree. The deployed public origin is stale and does not contribute changed-surface evidence. The Structural/Weight worker stalled after a bounded stop; those lanes therefore use the current code/build evidence supplied with R3 and explicitly retain unavailable network/TTI fields as gaps instead of importing stale numbers.

## Structural lane

Sources: `apps/web-ionic/src/main.tsx:14-40`, `src/PublicApp.tsx:1-27`, `src/App.tsx:1-41`, `src/components/AppLayout.tsx:23-167`, `src/components/IonicRoutePage.tsx:38-102`, `src/components/navTabs.tsx:17-28`, core route sources, current scoped lint/typecheck/build results.

- Public/authenticated trees remain separated by dynamic imports; public Login does not import/render the Ionic shell, while authenticated routes use one `IonSplitPane`/tabs/router-outlet composition.
- Static interactive inventory remains **123 JSX template placements across 21 TSX files**. Mapped rows count once; mutually exclusive branches are not treated as one runtime screen.
- Representative runtime structure remains data/state-dependent:
  - public Login: two text inputs plus submit in the initial state;
  - desktop shell: brand, three destinations, Appearance, account, plus focus-only skip link;
  - mobile shell: four tab destinations plus focus-only skip link;
  - Feed, Compose, Explore and Timetable use formulas because posts, targets, directory entities, lessons and overlays vary.
- Maximum closed primary-route source path remains **30 nodes** through authenticated Explore; conditional report-modal path reaches 32. Router/Ionic internals, Shadow DOM and portals are excluded.
- Repeated same-purpose affordances remain **6 families / 27 static placements**: responsive primary navigation, contextual Compose entry points, mutually exclusive private-save actions, ThemeControls reuse, Settings entry points, and Back-to-Experiences links.
- Fresh R3 scoped ESLint passes with no errors/warnings apart from the existing root package typeless notice; typecheck passes. Syntactic dead-import/unused-variable count: **0**. One semantic dead-prop candidate remains: `IonicRoutePage.publicScreen`, now that public Login bypasses the wrapper.
- Skip link is the first declared `IonSplitPane` child before `IonMenu` and `#ionic-main`, and targets a programmatically focusable main container (`AppLayout.tsx:75-125`).
- R3 copy changes add no controls, routes, modal, navigation item, or wrapper; structural task paths are unchanged.

Known gaps: authenticated runtime DOM counts and Ionic internals were not captured; the semantic dead prop is source-observed rather than analyzer-produced.

## Visual lane

Sources: six R3 images in `docs/web/evidence/ionic-fidelity/r3-candidate/`; current `styles/tokens.css:13-143`, `foundations.css:15-390`, `features.css:78-802`, `ionic.css:125-415`; current Feed and Compose sources. Compose is a fresh R3 capture; the other five are unchanged-layout evidence because R3 changes only copy.

### Mandatory scale/color facts

- Declared spacing: **[4, 8, 12, 16, 20, 24, 32, 44]px**. Unchanged local Login computed spacing: **[6, 8, 10, 11, 13, 16, 18, 24, 32]px** (`tokens.css:60-70`).
- Declared type: **[12, 13, 15, 16, 17, 20, 22, 28]px**. Local Login rendered: **[13, 16, 17, 44]px** (`tokens.css:41-58`).
- Active referenced token colors: **27 unique hex values** after excluding a historical comment; no `oklch()` token. Idle Login renders six computed non-transparent colors.
- Lowest active text-token contrast: Mist `--ink-3 #636f77` on `#eef2f2` = **4.574:1**, above the 4.5:1 normal-text floor (`tokens.css:111-118`). Lowest checked primary-body pairing is 12.740:1.

### Current rendered findings

- Both Feed scopes and both selected states remain visible at 390px and 375px; Feed tools and segment controls remain at least 44px (`r3-candidate/experiences-*.png`, `FeedPage.tsx:51-105`, `ionic.css:137-210,336-415`).
- Fresh Compose shows the complete external-model/session/key/browser-storage disclosure as ordinary DOM text above the tab bar. The textarea retains its filled editor region, primary full-width action, two-column secondary actions, and no terminal overlap (`r3-candidate/compose-mobile-390x844.png`, `ComposePage.tsx:281-308`).
- Timetable terminal content remains clear of navigation; desktop Home remains an 820px centered column after the 216px rail (`r3-candidate/timetable-mobile-390x844-bottom.png`, `home-desktop-1440x900.png`, `ionic.css:125-135,279-335`).
- No horizontal clipping is visible. Unchanged local public geometry is `390=clientWidth=scrollWidth` and `844=clientHeight=scrollHeight`.
- Settled idle animation count remains **0**; Home wash and Timetable marker have no infinite animation declarations. Login's 500ms entrance is finite (`features.css:78-100,331-354`).
- One neutral sans, cool stone/white surfaces, restrained accent and hairlines remain consistent; no decorative image, video, gradient showpiece or ambient ornament appears.

### Six mandatory states

| State | Result | Evidence |
|---|---|---|
| Empty | Present, source-verified | Two Feed empty branches. |
| Loading | Present, source-verified | Accessible Skeleton branches. |
| Error | Present, source-verified | `role=alert` branches. |
| Success | Present, rendered | Feed/Home/Compose/Timetable images. |
| Focus | Present, rendered | R3 focused Login plus native/Ionic focus CSS. |
| Disabled | Present, rendered | Compose disabled Share/private actions. |

Known gaps: authenticated DOM/computed style not operated; five screenshots are unchanged-layout evidence; empty/loading/error are source-only; non-default surfaces and physical-device safe areas are not rendered.

## Copy and honesty lane

Sources: `docs/web/evidence/ionic-fidelity/copy-inventory.json`; `apps/web-ionic/scripts/audit-copy.mjs`; `src/lib/copyIntegrity.test.ts:1-101`; current Compose/useComposer/Settings/Mine/Why/ExperiencePost/client sources; backend route behavior read only to verify current labels.

### Mandatory inventory and assertions

- `audit:copy` passes and reports **407 surface strings**, each `{file,line,context,text}`, plus an exhaustive **1,512 non-import string-literal superset**, each `{file,line,syntax,text}`.
- Fresh Vitest passes **8 files / 42 tests**; Copy Integrity passes 8/8. Assertions cover routes/labels, both Feed scopes, skip-link order, prohibited over-absolute phrases, session-plus-key wording, first-hand/food wording and inventory determinism (`copyIntegrity.test.ts:9-101`).
- Prohibited phrases such as `never sent anywhere`, `Nothing was stored`, and `key is the only way` remain only as negative test fixtures; tests are excluded from the shipped-copy inventory.
- Visible brand casing remains canonical `HOney`.

### Corrected label→behavior mappings

- Compose now distinguishes browser autosave, no HOney-server publication/storage, and any earlier safety-check transmission (`ComposePage.tsx:160-168,302-308,380-389`; `useComposer.ts:44-49,65-81,111-151`).
- External moderation processing is disclosed immediately below Share, while Settings retains provider/retention detail (`ComposePage.tsx:281-308`; `SettingsPage.tsx:223-229`).
- Compose result/action copy, detailed Settings and Mine all say management/revocation requires a signed-in HOney session plus a browser-held post-control key (`ComposePage.tsx:137-143,302-306`; `SettingsPage.tsx:201-216`; `MinePage.tsx:137-154`).
- Why and the reaction explainer replace `relevant exposure` with exact school-history/teacher/course/place checks and explicitly state that food may establish school membership only (`WhyPage.tsx:60-68`; `features/experiences/ExperiencePost.tsx:23-27`).
- Publication remains explicit after safety checking; nudge never auto-publishes. Consent and credential persistence remain opt-in. No dark pattern was found.

### Remaining inflation/mismatch

One shipped over-absolute claim remains:

- Settings account-deletion summary says published experiences are `controlled only by the keys on your devices` (`SettingsPage.tsx:83-86`).
- The same page's detailed section says a signed-in session plus post-control key are required and neither is sufficient alone (`SettingsPage.tsx:201-216`); current lookup/revoke behavior is authenticated.
- This is one concise label→behavior mismatch and contradicts the more precise explanation on the same page.

### Jargon

- Ordinary-user `post-control key`, `stored hash`, `author ID`, `moderation model` and `OpenRouter` are accompanied by explanatory sentences.
- Admin surface still uses `Moderation LLM`, `LLM`, `sealed at rest`, `entity key`, and `Reaction count threshold`; plain equivalents are `automated moderation model`, `language model`, `encrypted while stored`, `item identifier`, and `minimum reactions before counts are shown`.
- `relevant exposure` is no longer shipped on the inspected ordinary-user surfaces.

Known gaps: TS/TSX inventory excludes CSS/static HTML/browser-generated/backend-returned strings; high-risk changed copy was behaviorally traced, not every low-risk string; database storage and full external-provider logging/retention were not freshly audited.

## Weight and friction lane

Sources: fresh R3 build report; `main.tsx:14-40`, `PublicApp.tsx:1-27`, `App.tsx:1-41`; current motion/theme/service-worker source.

- Public cold-path chunks:
  - entry **153.58 KiB raw / 49.54 KiB gzip**;
  - PublicApp **3.02 / 1.36 KiB gzip**;
  - ErrorBoundary **25.63 / 9.49 KiB gzip**;
  - SchoolLoginForm **1.21 / 0.58 KiB gzip**.
- Summed public initial JS: **183.44 KiB raw / 60.97 KiB gzip** (about 62 KiB transferred in unchanged local cold-path evidence). Authenticated `App` is not loaded on this path.
- Authenticated App remains **970.93 KiB raw / 214.71 KiB gzip**, plus the shared entry. Total authenticated initial path is therefore about **1,124.51 KiB raw / 264.25 KiB gzip** before runtime Ionic element chunks.
- Initial public hashed-JS request count: **4 inferred from the build chunk set**. Complete document/CSS/font/image request count is unavailable.
- TTI: **not freshly measured**; no stale timing is substituted.
- Active continuous animation: **0** in current settled states. Loading shimmer is conditional; entrances are finite.
- Initial notification/badge/modal/popover count: **0** in the six R3 initial screenshots.
- Explicit persisted Night surface honors dark presentation; it remains user-selected rather than OS-auto-selected.
- CSS and JS honor `prefers-reduced-motion`; no autoplay video exists.

Known gaps: no R3 full waterfall, TTI/INP/TBT, or authenticated runtime lazy-chunk measurement. Performance is build-derived.

## Accessibility lane

Sources: R3 focus/Compose/Feed/Timetable/Home screenshots; `PublicApp.tsx:6-26`, `AppLayout.tsx:75-168`, `Modal.tsx:1-68`, current core route sources; focus/target/reduced-motion CSS.

### Text contrast

All active text-token pairs pass WCAG 2.x normal-text AA:

| Surface | Ink | Secondary | Tertiary | Accent |
|---|---:|---:|---:|---:|
| Stone | 13.256 | 5.338 | 4.658 | 5.813 |
| White | 14.370 | 5.787 | 5.050 | 6.302 |
| Mist | 12.740 | 5.130 | 4.574 | 5.587 |
| Night | 15.271 | 8.071 | 5.832 | 9.283 |

Danger/ok/on-accent pairs also pass; non-default surfaces are source-calculated.

### Focus, keyboard, landmarks and names

- Public Login order: username → password → submit. All are reachable; first focus has a visible 3px accent outline. Public structure: one main, one h1, no navigation/aside/footer, no skip link needed for the three-control doorway.
- Signed-in skip link is present **before** rail/navigation in source and targets focusable `#ionic-main` (`AppLayout.tsx:75-125`).
- Source-inferred core orders:
  - Home: Timetable → previews → Share → Portal → mobile tabs.
  - Feed: Share/Find/Mine → two scopes → conditional update → post links/reactions/more/report → tabs.
  - Compose: textarea → optional rating → enabled actions → privacy link → tabs.
  - Timetable: previous/date/next → today/History/Sync → lesson buttons → modal → tabs.
- Native primary actions are keyboard reachable; disabled Compose actions are unreachable until actionable. Ionic segment/tab/textarea/modal/popover reachability is framework/source-inferred.
- Signed-in source landmarks: one primary nav, one rail aside on desktop, one Ionic main route region; core routes each have one h1, modal title h2.
- Reactions expose name/pressed state; overflow exposes expanded state; report uses menu/menuitem; errors/status/loading/live-feed semantics remain present; report close restores focus.
- Feed tools/segments, tabs, date arrows, base fields/buttons, modal close and coarse-pointer reactions/ratings meet or exceed 44px.
- Native and Ionic focus-visible rules and reduced-motion rules remain intact.

Known gaps: no authenticated keyboard/screen-reader/Shadow-DOM run, modal-trap/Escape operation, signed-in accessibility-tree count, non-text contrast audit, or physical-device hit testing.

## Per-principle factual feed

1. Innovative: public/auth delivery uses a lightweight non-Ionic doorway with a full authenticated Ionic shell; no five-peer novelty study exists.
2. Useful: R3 changes no task path; Home/Feed/Explore/Timetable functions and complete option discovery remain direct.
3. Aesthetic: one visual system persists; fresh longer Compose copy remains readable without changing composition.
4. Understandable: concrete first-hand/food, server/browser, external-model and session-plus-key explanations replace abstract or ambiguous wording; one Settings summary and some admin jargon remain.
5. Unobtrusive: disclosure stays inline, chrome/content hierarchy and zero idle motion are preserved.
6. Honest: all targeted R2 mismatch families are corrected except one key-only deletion-summary sentence.
7. Long-lasting: neutral type, cool palette, hairlines and standard controls remain free of dated ornament.
8. Thorough: all six mandatory states remain; R3 adds fresh Compose disclosure visibility and integrity assertions.
9. Environmentally friendly: public initial JS is ~61 KiB gzip with no idle animation; authenticated initial is ~264 KiB gzip / 1.1 MiB raw.
10. As little design as possible: copy changes add no surface, control or step; one semantic dead prop remains outside visible design.
