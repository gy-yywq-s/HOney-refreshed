# R4 consolidated evidence

R4 is a final one-defect confirmation against the current working tree. The live deployed origin is stale and excluded. No optional browser/build run was added; unavailable performance timings remain explicit gaps.

## Structural lane

Sources: `apps/web-ionic/src/main.tsx:14-40`, `src/PublicApp.tsx:1-27`, `src/App.tsx:1-41`, `src/components/AppLayout.tsx:23-167`, `src/components/IonicRoutePage.tsx:38-102`, core route sources, and fresh reported lint/typecheck results.

- Current static interactive inventory: **123 JSX template declarations across 21 TSX files**. Mapped controls count once; conditional branches are not summed as a simultaneous runtime state.
- Group totals: shell/shared 19; ExperiencePost/shared controls 10; Home/Timetable/Feed/Explore/Compose 48; remaining pages 46.
- Maximum closed primary path: **30 nodes** through authenticated Explore. Conditional Feed report path reaches 32. Router/Ionic internals, Shadow DOM, portals and closed overlays are excluded.
- Repeated same-purpose patterns: **6 families / 27 placements** — responsive primary destinations 6, Compose entries 9, mutually exclusive Keep-private actions 4, ThemeControls 2, Settings entries 2, Back-to-Experiences 4.
- Fresh scoped lint passes with only the existing root typeless notice; typecheck passes. Configured unused import/variable count: **0**. One semantic zero-caller prop candidate remains: `IonicRoutePage.publicScreen` (`IonicRoutePage.tsx:38-68`).
- Public Login and authenticated Ionic navigation remain separate root trees; R4 adds no route, control, wrapper or task step.
- Skip link precedes navigation and `#ionic-main` in source and targets a programmatically focusable container (`AppLayout.tsx:75-125`).

Known gaps: runtime data cardinality remains variable; authenticated DOM/Ionic internals and whole-program prop reachability were not freshly measured.

## Visual lane

Sources: six unchanged-layout regression images under `docs/web/evidence/ionic-fidelity/r3-candidate/`; current `styles/tokens.css:13-143`, `foundations.css:15-390`, `features.css:78-802`, `ionic.css:125-415`; Feed/Compose state sources. R4 changes only Settings copy.

- Spacing scale: **[4, 8, 12, 16, 20, 24, 32, 44]px**; unchanged Login computed spacing **[6, 8, 10, 11, 13, 16, 18, 24, 32]px**.
- Type scale: **[12, 13, 15, 16, 17, 20, 22, 28]px**; unchanged Login rendered sizes **[13, 16, 17, 44]px**.
- Active referenced color count: **27 unique hex tokens** after excluding a historical comment; no `oklch()`. Idle Login renders six computed non-transparent colors.
- Lowest active text contrast: Mist `#636f77` on `#eef2f2` = **4.574:1**, passing the 4.5:1 normal-text floor.
- Both Feed scopes/selected states remain visible at 390px and 375px; tools and segments remain at least 44px.
- Compose disclosure remains fully visible above navigation; Timetable terminal content remains clear; desktop Home remains an 820px centered column after the 216px rail.
- Unchanged public geometry has no root/horizontal overflow. Settled continuous idle animation count remains **0**.
- One neutral sans, cool palette, restrained accent, hairlines and content-led hierarchy remain consistent.

Mandatory state checklist: empty, loading and error remain source-present; success, focus and disabled are rendered; all six are considered. R4's Settings sentence was not separately screenshot-rendered because no style/layout changed.

Known gaps: no new authenticated DOM/computed-style run, non-default surface screenshot, physical safe-area/keyboard test, or rendered Settings wrapping check.

## Copy and honesty lane

Sources: `docs/web/evidence/ionic-fidelity/copy-inventory.json`; `apps/web-ionic/src/lib/copyIntegrity.test.ts:45-94`; current Settings/Compose/useComposer/Mine/Why/ExperiencePost/client sources; authenticated lookup/revoke route read only for label verification.

- Copy inventory contains **407 shipped surface strings**, each `{file,line,context,text}`, and an exhaustive **1,512 non-import literal superset**, each `{file,line,syntax,text}`.
- Fresh verification: `audit:copy` passes; Vitest passes **8 files / 42 tests**; integrity assertions require the exact session-plus-key sentence and reject `controlled only by the keys on your devices`, `key is the only way`, and `only control over the post` (`copyIntegrity.test.ts:64-78`).
- Corrected deletion summary now says: `A signed-in HOney session and a post-control key held on one of your devices are both required to find or revoke them` (`SettingsPage.tsx:83-87`).
- The summary now matches detailed Settings, Compose, Mine and authenticated find/revoke behavior.
- Browser autosave, HOney-server storage, publication and prior safety-check processing remain distinctly described.
- External moderation processing remains disclosed beside Share with fuller provider detail reachable in Settings.
- First-hand class/teacher/course/place context and food's school-membership limitation remain explicit; reactions remain resonance rather than truth votes.
- Confirmed shipped high-risk inflations: **0**. Confirmed high-risk label→behavior mismatches: **0**. Prohibited phrases occur only as negative test fixtures excluded from the 407 shipped strings.
- Dark patterns: **none found**. Publication is explicit; nudge requires another choice; private save remains available; cooldown does not publish.
- Ordinary-user technical terms receive adjacent explanations. Admin copy still uses `Moderation LLM`, `sealed at rest`, `entity key`, and `Reaction count threshold`, with plainer equivalents available.
- Visible brand spelling remains canonical `HOney`.

Known gaps: static inventory excludes CSS/static HTML/browser/Ionic/backend-generated runtime copy; dynamic variants and full provider/database behavior were not freshly audited; account deletion/revoke was not executed live.

## Weight and friction lane

Sources: fresh R4 build report; `main.tsx:1-40`, `PublicApp.tsx:1-27`, `App.tsx:1-41`; current theme/motion/service-worker sources.

- Shared entry: **153.58 KiB raw / 49.54 KiB gzip**.
- PublicApp: **3.02 / 1.36 KiB gzip**. ErrorBoundary: **25.63 / 9.49 KiB gzip**. SchoolLoginForm: **1.21 / 0.58 KiB gzip**.
- Public initial summed JS remains about **183.44 KiB raw / 60.97 KiB gzip**; authenticated App is excluded from the public branch.
- Authenticated App: **970.93 KiB raw / 214.70 KiB gzip** plus shared entry, approximately **1,124.51 KiB raw / 264.24 KiB gzip** before runtime Ionic element chunks. Vite's >500KB raw warning remains.
- Exact full request count and TTI are **unavailable** because R4 intentionally adds no network/browser trace; no stale timing is substituted.
- Settled continuous idle animation: **0**. Conditional refresh rotation and loading shimmer run only during active states; entrances are finite.
- Initial notification overlay, badge, modal/popover and autoplay media counts: **0**.
- Dark presentation exists through persisted theme selection; CSS and JS honor `prefers-reduced-motion`; no autoplay video/audio exists.

Known gaps: no current waterfall, TTI/LCP/INP/long-task trace, byte-exact filesystem counts, or low-end-device measurement.

## Accessibility lane

Sources: unchanged focus/core-state screenshots; `PublicApp.tsx:6-26`, `AppLayout.tsx:75-168`, core page/Modal sources; focus/target/status/reduced-motion CSS.

- All checked active text tokens pass normal-text AA across Stone, White, Mist and Night. Tertiary ratios: 4.658, 5.050, 4.574 and 5.832 respectively.
- Public Login exact focus order: username → password → submit. One main, one h1, no nav/aside/footer; visible 3px focus outline.
- Signed-in skip link is present **before** rail/navigation and targets focusable `#ionic-main` (`AppLayout.tsx:75-125`).
- Source-inferred core orders remain Home actions → tabs; Feed header/scopes/posts/report → tabs; Compose textarea/rating/actions/privacy → tabs; Timetable date/history/sync/lessons/modal → tabs.
- Native actions are keyboard reachable; disabled actions are unreachable until enabled. Ionic segment/tab/textarea/modal/popover remain framework/source-inferred.
- Signed-in source landmarks: primary nav, desktop aside and one Ionic main route region; core routes have one h1, modal h2.
- Reactions expose names/pressed state, overflow expanded state, report menu semantics, live Feed/status/loading/error semantics, and explicit report focus return.
- Feed tools/segments, tabs, date arrows, inputs/buttons, modal close and coarse-pointer reactions/ratings meet or exceed 44px.
- Native/Ionic focus rules and reduced-motion handling remain intact.

Known gaps: no authenticated screen-reader/keyboard/Shadow-DOM run, modal-trap/Escape operation, signed-in accessibility-tree count, non-text contrast audit or physical hit testing.

## Per-principle factual feed

1. Innovative: lightweight public root and full authenticated Ionic shell remain a clear technological refinement; no five-peer novelty study exists.
2. Useful: the one-sentence R4 correction changes no primary task path or control.
3. Aesthetic: unchanged regression evidence retains one visible type/color/spacing system.
4. Understandable: ordinary-user consequential copy is concrete and internally consistent; remaining jargon is concentrated in admin labels.
5. Unobtrusive: no new surface or interruption; content dominance and zero idle animation remain.
6. Honest: the last confirmed contradiction is closed; current high-risk inventory/behavior trace finds zero shipped mismatch or dark pattern.
7. Long-lasting: neutral type, cool palette, hairlines and standard controls remain free of dated effects.
8. Thorough: all six states and accessibility details remain represented; exact truth assertion is now tested.
9. Environmentally friendly: public path remains ~61 KiB gzip, authenticated path ~264 KiB gzip / 1.1 MiB raw, with no idle animation.
10. As little design as possible: R4 changes one sentence and one test assertion; no visible element or step is added.
