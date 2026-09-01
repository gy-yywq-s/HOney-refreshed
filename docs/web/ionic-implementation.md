# HOney Ionic Web implementation

## Implementation identity

- Branch: `web-ionic`
- Base: `integration/product-v2` at `4ef5974`
- Ionic: `@ionic/react` and `@ionic/react-router` 9.0.1
- Runtime: React 18, React Router 6, Vite 5, Node 22+
- Public development host: `https://honey.gaelis.cc`

This is the maintained Ionic Web/PWA implementation under `apps/web-ionic`. The existing `apps/web` implementation remains independently runnable and is not embedded into this app.

## Commands

From the repository root:

```bash
pnpm dev:web:ionic
pnpm build:web:ionic
pnpm --filter @honey/web-ionic typecheck
pnpm --filter @honey/web-ionic test
pnpm --filter @honey/web-ionic test:e2e
```

The existing Web remains available through:

```bash
pnpm dev:web
pnpm build:web
```

## Application structure

- `src/App.tsx`: authentication boundary, responsive split-pane shell, mobile tabs, route graph.
- `src/api/client.ts`: same-origin live API adapter, token refresh, typed error mapping, fixture selection.
- `src/api/fixtures.ts`: isolated development data and moderation lanes; enabled only by `VITE_DEMO_FIXTURES=1` or `?demo=1` and always disclosed in the UI.
- `src/pages`: Home, Experiences, Explore, entity streams, Compose, Mine, Timetable, History, lesson detail, login/consent, Settings, Access, privacy, and rationale routes.
- `src/components/ExperiencePost.tsx`: raw-post stream presentation, context links, reactions, and category-only reporting.
- `src/lib/localRecords.ts`: device-local drafts, private notes, and publication ownership keys.
- `server.mjs`: static PWA host with SPA fallback and a narrow same-origin `/api` proxy to the existing backend.

## Mobile and desktop composition

Ionic owns the viewport; the document is not a business-content scroll owner. Mobile uses a bottom `IonTabBar`. At 1024 px and above, `IonSplitPane` exposes persistent navigation and removes the bottom bar.

Core route mappings:

| Route | Composition model | Scroll owner |
| --- | --- | --- |
| `/home` | `COMPACT_OVERFLOW` | Home `IonContent` only when compact degradation is exhausted |
| `/experiences` | `FRAMED_SCROLL` | Continuous feed `IonContent` |
| `/experiences/explore` | `FRAMED_EDITOR` | Results below fixed search/category controls |
| `/experiences/compose` | `FRAMED_EDITOR` | Fixed editor frame; keyboard behavior remains inside Ionic content |
| `/timetable` | `FRAMED_SCROLL` | Day timeline |
| `/history` | `FRAMED_SCROLL` | Grouped lesson history |
| `/login`, `/consent`, `/access` | `FIT` | No ordinary business scroll at regular height |
| `/privacy`, `/experiences/why` | `DOCUMENT` | Long-form `IonContent` |

Compact-height CSS degrades secondary Home material before requiring overflow. Safe-area values use `env(safe-area-inset-top)` and `env(safe-area-inset-bottom)` through Ionic variables.

## Experiences product behavior

Experiences opens as a continuous student-to-student stream. It keeps the community identity line visible in the frame, separates `Your classes` from `Around school`, treats Course as a first-class context, and does not display human ratings. Ratings appear only for food.

Compose preserves the ordered server contract: eligibility, moderation check, then anonymous publish using a short-lived token and pass. Expression intervention precedes scope and timing outcomes. Candidate text is not presented as already published during checks. Private notes remain on the device. Reports accept only fixed categories and explicitly separate disagreement from reporting.

## API and backend boundary

The implementation reuses `@honey/shared/api` and the existing `/api` endpoints. No backend, database, portal connector, or shared-contract behavior was changed. The deployed Node host proxies only `/api` to the existing local backend so browser requests remain same-origin; it does not add a new backend capability.

School Access is intentionally unsupported on Web because the current school endpoint does not provide a safe direct browser flow. The app points to iOS instead of simulating success or relaying gate actions through the backend.

## PWA setup

`vite-plugin-pwa` generates the manifest and service worker with auto-update registration. The build includes 192 px and 512 px install icons. API responses are excluded from navigation fallback and have no runtime cache rule. The static server sends a no-cache policy for `index.html` and `sw.js`, immutable caching for hashed assets, CSP, referrer policy, and MIME hardening.

## Fixture mode

Fixture mode supports layout, navigation, reactions, publishing, ownership, and the ordered moderation outcomes without using production data. It is isolated from live behavior and displays the persistent `Fixture data · not live` strip. It is not a substitute for Web Access or live-backend acceptance.

## Current acceptance results

| Criterion | Status | Evidence |
| --- | --- | --- |
| App boot and primary navigation | PASS | Playwright Chromium core suite |
| Home 390×844 root fit and no horizontal overflow | PASS | Automated dimension assertion and screenshot |
| Experiences framed scroll ownership | PASS | Automated document/owner assertion |
| Experiences scroll restoration through Explore | PASS | Automated offset restoration assertion |
| Explore directory search | PASS | Automated behavior test |
| Compose ordered moderation outcome | PASS | Automated fixture behavior test |
| Timetable → lesson → lesson-bound Compose | PASS | Automated route-transition test |
| Shared contract target/query mapping | PASS | Vitest contract adapter tests |
| Manifest and service-worker generation | PASS | Production build output contains manifest, `sw.js`, and Workbox runtime |
| Existing `apps/web` production build | PASS | Verified on this branch |
| Mobile regular, compact, and desktop browser layouts | PASS | Browser-mode screenshots listed below |
| Real backend authentication and imported school data | NOT TESTED | Fixture evidence does not establish live school behavior |
| Installed standalone PWA launch/update behavior | NOT TESTED | Browser screenshots are not standalone-PWA evidence |
| Offline behavior after installation | NOT TESTED | No installed-PWA runtime pass yet |
| Real mobile keyboard open/close behavior | NOT TESTED | Requires device/visual-viewport evidence |
| Physical-device safe-area behavior | NOT TESTED | CSS is present; no notched-device runtime pass |
| Web school Access | NOT APPLICABLE | Deliberately unsupported and disclosed |

## Browser-mode evidence

All files below are ordinary Chromium browser screenshots using isolated fixture data. They do not claim installed-PWA validation.

- `docs/web/evidence/ionic-browser-2026-09-01/mobile-390x844-home.png`
- `docs/web/evidence/ionic-browser-2026-09-01/mobile-390x844-experiences.png`
- `docs/web/evidence/ionic-browser-2026-09-01/mobile-390x844-explore.png`
- `docs/web/evidence/ionic-browser-2026-09-01/mobile-390x844-compose.png`
- `docs/web/evidence/ionic-browser-2026-09-01/mobile-390x844-timetable.png`
- `docs/web/evidence/ionic-browser-2026-09-01/compact-375x667-home.png`
- `docs/web/evidence/ionic-browser-2026-09-01/compact-375x667-experiences.png`
- `docs/web/evidence/ionic-browser-2026-09-01/desktop-1440x900-home.png`
- `docs/web/evidence/ionic-browser-2026-09-01/desktop-1440x900-experiences.png`
- `docs/web/evidence/ionic-browser-2026-09-01/desktop-1440x900-explore.png`

## Current limitations

- The initial Ionic bundle includes a large main JavaScript chunk; it builds successfully but remains a performance optimization target.
- Live school sign-in, portal availability states, and real imported data need a separate credentialed runtime pass.
- Installed-PWA, offline, real keyboard, and physical-device safe-area evidence remain explicitly unclaimed.
