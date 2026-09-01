# Ionic Web/PWA fidelity implementation

## Scope and repository state

- Branch: `web/ionic-fidelity`.
- Exact base: `integration/product-v2` at `3d91cb3f3981f282268dbd598f1106c2fd53732c`.
- Previous-agent commits found on this branch: none. The branch pointed directly at the base SHA.
- Previous-agent files preserved: the 10 reference screenshots under `docs/web/evidence/ionic-fidelity/reference/`.
- Implementation commit deployed locally: `f87fe75` (`web: add isolated Ionic fidelity PWA`).
- Gary's explicit follow-up requires the existing Web to remain. Therefore the Ionic implementation is isolated at `apps/web-ionic`; `apps/web` is unchanged.
- Backend, shared source, database, iOS, and the deployed `/home/honey/app` checkout are unchanged.

## Versions and dependencies

- Ionic React: `@ionic/react@9.0.1`.
- Ionic React Router: `@ionic/react-router@9.0.1`.
- Ionicons: `ionicons@8.1.0`.
- Existing React 18, React Router 6, Vite 5, TypeScript, shared API client logic, design tokens, behavior tests, manifest, icons, and service-worker strategy are retained.

## Architecture mapping

The implementation is a separate Ionic shell around the current product logic, rather than a rewrite of tested behaviors.

- App root: `IonApp` and `IonReactRouter`.
- Responsive shell: one `IonSplitPane`; desktop uses `IonMenu` as the existing quiet rail, while mobile uses `IonTabs`, `IonRouterOutlet`, `IonTabBar`, and `IonTabButton`.
- Route boundary: every route is wrapped by `IonicRoutePage`, which provides one `IonPage` and one `IonContent`.
- Refresh: eligible routes use `IonRefresher`; it emits the existing refresh event and clears the frontend cache. There is no document-level touch interception or custom scroll physics.
- Overlays: shared dialogs use `IonModal`; post/account actions use `IonPopover`.
- Experiences scope: `IonSegment` and `IonSegmentButton`.
- Compose: `IonTextarea`.
- Icons: Ionicons in mobile navigation and compact Experiences actions.
- Page code is route-split behind stable Ionic route boundaries.
- Leaf presentation remains custom: HOney typography, tokens, lesson timeline, cards, feed posts, reactions, provenance, composer actions, Explore lists, privacy copy, timetable geometry, and admin surfaces.

## Routes and scroll ownership

Converted routes:

- `/login`
- `/home`
- `/timetable`
- `/history` and `/history/lesson/:id`
- `/experiences`
- `/experiences/explore`
- `/experiences/why`
- `/experiences/mine`
- `/experiences/compose`
- all teacher/course/room/dish/place/food entity routes
- `/settings`
- `/dash`
- not-found route

Scroll models:

- `FIT`: Login and account-loading states.
- `COMPACT_OVERFLOW`: Home. It fits normal phone heights and degrades before allowing small overflow.
- `FRAMED_SCROLL`: feed, entity, Timetable, History, Settings, and Dash.
- `FRAMED_EDITOR`: Explore and Compose.
- `DOCUMENT`: explanatory and not-found pages.

The document and body are not business scrollers. Browser measurements at 320×568, 375×667, 390×844, 430×932, 844×390, and 1440×900 showed root height equal to viewport height, no horizontal overflow, and exactly one active `data-scroll-owner`. Long content scrolls inside the active `IonContent`.

Feed snapshots now read and restore the active Ionic scroll owner rather than `window.scrollY`. A real-browser route-away/return check restored 720 px to 720 px.

## Presentation changes and reasons

These changes are intentionally not pixel copies:

- Mobile Experiences actions use three compact icon controls. Reason: the previous controls wrapped and consumed too much of the first viewport.
- Desktop Home is capped at 940 px. Reason: preserve the progress wash's now/remaining meaning while reducing wide-screen dead area.
- Desktop feed is capped at 760 px. Reason: retain readable post line length and the existing feed rhythm.
- Scope switching uses a quiet themed `IonSegment`; it keeps every finite option visible.
- The mobile tab bar participates in Ionic safe-area/viewport geometry and uses HOney colors rather than stock Ionic blue.
- Modal and popover chrome follows Ionic lifecycle/placement while retaining HOney leaf content.
- Compact-height Home hides the second preview before overflowing, matching the documented content priority.

No product meaning, privacy statement, feed scope, provenance, reaction rule, report category, composer behavior, or navigation destination was intentionally changed.

## PWA and standalone serving

- `manifest.webmanifest` remains `display: standalone` with `start_url: /home` and three install icons.
- Manual service-worker registration is retained.
- Cache namespace is isolated as `honey-ionic-v1`.
- The service worker never intercepts `/api`, uses network-first navigation, and excludes non-GET requests.
- `server.mjs` serves hashed assets with immutable caching; index, manifest, and service worker have update-safe cache headers.
- The server uses a hash-scoped CSP allowance for the existing pre-paint theme bootstrap.
- Client-side routes fall back to `index.html`.
- `/api` is a same-origin reverse proxy to the existing local HOney backend. This deploys no backend code and changes no backend service.

A clean production-browser check confirmed the theme bootstrap, manifest link, activated service worker, root scope, and no root overflow.

## Deployment

Target: `https://ionic.gaelisus.com`.

Process completed on the droplet:

1. Pushed `web/ionic-fidelity`.
2. Created the separate checkout `/home/honey/ionic-app` at `f87fe75`.
3. Ran locked install, shared type build, and `@honey/web-ionic` production build.
4. Installed the reviewable `docs/deploy/honey-ionic-fidelity.service`.
5. Started and enabled `honey-ionic-fidelity.service` on `127.0.0.1:8902`.
6. Added only the `ionic.gaelisus.com` ingress to `/etc/cloudflared/config.base.yml` and regenerated the tunnel config. No DNS record was changed.

Local deployment verification:

- `/healthz`: 200.
- `/experiences/explore`: 200 SPA shell.
- `/manifest.webmanifest`: 200, correct manifest content type and no-store update policy.
- `/sw.js`: 200, no-store plus `Service-Worker-Allowed: /`.
- `/api/health`: 200 from the existing `honey-backend`.

Public deployment status: blocked at DNS. Every HTTPS probe to `ionic.gaelisus.com` returns Cloudflare 403 Error 1000, “DNS points to prohibited IP.” The request does not reach the tunnel or Ionic service. Correcting the existing DNS record is required, but the task explicitly says not to change DNS. Public page boot, client-side routing, manifest, and service-worker verification therefore remain untested at the target host. The exact service and ingress are ready once that separate authorization is given.

The existing `honey.gaelisus.com` service, checkout, backend, and tunnel rule were not changed. The older `honey.gaelis.cc` hostd Ionic experiment was also not overwritten.

## Verification

Current focused results:

- `pnpm exec eslint apps/web-ionic`: pass.
- `pnpm --filter @honey/web-ionic typecheck`: pass.
- `pnpm --filter @honey/web-ionic test`: 7 files, 32 tests passed.
- `pnpm --filter @honey/web-ionic build`: pass.
- Clean deployment checkout install/build: pass.
- Production browser against the built local server: booted with an activated service worker and no boot error.
- Browser console in the final development sweep: zero runtime errors; only React Router future-flag warnings.
- Modal lifecycle: lesson modal opened with Ionic focus ownership and closed by Escape without route change.
- Report lifecycle: post popover closed before report modal opened; Escape dismissed the modal.
- Compact composer: at 375×500, after focusing and typing, all three actions scrolled fully above the tab bar.
- Responsive sweep: 320×568, 375×667, 390×844, 430×932, 844×390, and 1440×900; no root or horizontal overflow.
- Root `pnpm lint` is not green because the base branch already contains invalid `react-hooks/exhaustive-deps` disable directives and unused imports in the preserved `apps/web` and backend. Those unrelated files were not changed. The new Ionic package passes its scoped lint gate.

Build note: route splitting produces separate page chunks, but Ionic's shared shell chunk remains about 1,152 kB (273 kB gzip), so Vite still emits its 500 kB chunk-size advisory.

## Screenshot evidence

Reference set:

- `docs/web/evidence/ionic-fidelity/reference/`

Final Ionic set:

- `docs/web/evidence/ionic-fidelity/ionic/`

Both directories contain the same 10-state matrix:

- mobile 390×844: Home, Experiences, Explore, Compose, Timetable
- compact 375×667: Home, Experiences
- desktop 1440×900: Home, Experiences, Explore

## Remaining limitations and untested items

- Public HTTPS verification is blocked by the existing DNS record as described above.
- No physical iOS Safari/Android Chrome install test was run; Chromium validated responsive and standalone PWA behavior.
- The current service proxies to the development backend, so its availability depends on the existing `honey.service`.
- Vite's shared Ionic chunk-size advisory remains.
- This document records implementation facts only and does not decide whether Ionic should replace the current Web.

## Backend and shared changes

No backend changes. No shared source changes. No database, migration, backend configuration, backend service, or backend deployment changes.
