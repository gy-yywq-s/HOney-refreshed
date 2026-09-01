# Design Is — Round 2 evidence

Evidence is anchored to deployed commit `f84b6ef139fd`. Structural, visual, performance, and
accessibility evidence subagents returned contract-compliant reports; the copy/honesty pass was
timeboxed before a usable report and its claims below were re-checked directly by the orchestrator.

## Structural and flow evidence

- Home exposes 11 visible semantic controls at `390×844`; its primary routes are one activation to
  Timetable, Experiences, Compose, Settings, or School Portal
  (`apps/web-ionic/src/pages/HomePage.tsx:33,67,71-82`).
- Compose's initial complete picker exposes 44 controls: Cancel, search, 28 recent lessons, and 14
  school-directory entities (`apps/web-ionic/src/pages/ComposePage.tsx:174-182`). The primary private
  or share flow is choose context → enter text → choose action.
- The deepest measured visible light-DOM chain was seven levels in the Compose picker. ESLint found
  zero unused imports/variables in the audited App/pages/components.
- Five same-purpose repetitions were identified. Three are mutually exclusive desktop/mobile nav
  renderings. One is simultaneously removable: each post exposes “Add your experience” both as a
  direct action and inside More (`apps/web-ionic/src/components/ExperiencePost.tsx:108-120`).

## Visual evidence

- Screenshots in `screenshots/` cover Home and Experiences at `375×667`, Timetable at `390×844`, and
  Home/Explore at `1440×900`. No audited viewport produced body-level horizontal overflow.
- The desktop rail measures 222px and Home/Explore results use the 710px reading spine. The Explore
  segment aligns to that spine, but the live Ionic searchbar spans the full 1218px post-rail content
  width (`apps/web-ionic/src/theme/variables.css:15-18`; `apps/web-ionic/src/theme/app.css:284-287`;
  `screenshots/explore-1440x900.png`, top search region).
- Mobile Home preserves greeting, current lesson, one student voice, Share, portal, and three tabs in
  the compact viewport (`screenshots/home-375x667.png`). Desktop renders one visible wordmark and
  hides the mobile tabbar (`apps/web-ionic/src/theme/app.css:211-220`).
- Authored default-light tokens reference 17 opaque colors. Lowest observed primary-text contrast is
  `4.521:1` for `#347da8` on white. The authored spacing and type values are broad, but the rendered
  surfaces retain one rule-based paper/ink/blue system (`apps/web-ionic/src/theme/variables.css:1-37`).
- One orphan treatment remains: the Composer question switches to Georgia while the rest of the UI
  uses the system sans (`apps/web-ionic/src/theme/variables.css:19`;
  `apps/web-ionic/src/theme/app.css:301`).

## Copy and honesty evidence

- Fixture data is continuously labelled “Fixture data · not live” (`apps/web-ionic/src/App.tsx:48-52`).
- Draft copy derives from actual local persistence: Saving, Saved, and Failed states are separate
  (`apps/web-ionic/src/pages/ComposePage.tsx:75-89,165`).
- Public publish success is distinct from device control-key failure, with a truthful recovery action
  (`apps/web-ionic/src/pages/ComposePage.tsx:124-153,200-207`).
- Cooldown keeps a private note and exposes “Continue draft”
  (`apps/web-ionic/src/pages/MinePage.tsx:59-67,84-86`).
- Privacy copy names external model routing, verbatim candidate-text transfer, unverified provider
  retention, unpinned region, connection metadata, and the social identifiability limit
  (`apps/web-ionic/src/pages/PrivacyPage.tsx:3-4`).
- No marketing superlative, fake scarcity, hidden cost, forced continuity, confirmshaming, or
  label-to-behavior mismatch was found in the audited primary flow. “Share anonymously” is bounded by
  the same product's precise publication/network disclosure, and the outcome text claims only that
  school identity is not shown with the public Experience
  (`apps/web-ionic/src/pages/ComposePage.tsx:169,200-203`).

## Performance and environmental evidence

- Cold Home requested 1,310,331 bytes decoded JS / 295,219 bytes encoded JS across eight scripts and
  13 successful responses. The main bundle contributes 1,297,312 bytes raw / 288,943 bytes encoded.
- Fresh-browser primary content became visible after 679ms wall-clock; Navigation Timing reported
  `domInteractive=131.2ms` and `loadEventEnd=303.9ms`. This is not a Lighthouse TTI.
- Idle screen: zero running animations, dialogs/modals, badges, or assertive notifications.
- Authenticated pages are route-lazy (`apps/web-ionic/src/App.tsx:25-45`). Dark mode uses explicit
  tokens (`apps/web-ionic/src/theme/variables.css:42-65`), and reduced-motion collapses motion
  (`apps/web-ionic/src/theme/app.css:235-241`).
- Live HTML is `no-cache, no-transform`; `sw.js` is `no-store`/CDN bypass; fingerprinted assets are
  immutable (`apps/web-ionic/server.mjs:28-35`). Workbox still precaches every built JS/image asset,
  moving additional transfer to first service-worker installation
  (`apps/web-ionic/vite.config.ts:25-30`).

## Accessibility and state evidence

- The active app exposes exactly one main landmark. The skip link reaches the unique focusable
  `#main-view`; committed browser assertions cover both
  (`apps/web-ionic/src/App.tsx:40-45`; `apps/web-ionic/tests/e2e/core.spec.ts:140-157`).
- Primary buttons/links are keyboard-addressable and icon-only actions carry accessible names.
  Reactions expose visible labels and `aria-pressed`
  (`apps/web-ionic/src/components/ExperiencePost.tsx:102-111`).
- Empty, loading, error/retry, success/outcome, focus, and disabled states all exist
  (`apps/web-ionic/src/components/States.tsx:4-24`;
  `apps/web-ionic/src/pages/ComposePage.tsx:155-208`; `apps/web-ionic/src/theme/app.css:28-44`).
- Repeated feed actions measure at least 44×44px, but segment buttons are authored at 42px and
  fixture-only moderation buttons at 34px (`apps/web-ionic/src/theme/app.css:119-128,275-279,306-308`).
- Applying `opacity:0.73` to whole past timetable rows drops muted/faint metadata below 4.5:1 in
  light mode (`2.94:1` / `2.83:1`) and faint metadata to `3.53:1` in dark mode
  (`apps/web-ionic/src/theme/app.css:319-325`).
- Pull-to-refresh has no explicit keyboard-equivalent control; overlay focus trap, Escape dismissal,
  and focus restoration were not runtime-verified.

## Known gaps

- No real authentication, publication, reaction, report, portal, destructive Settings action, or
  backend/external mutation was exercised.
- Dark mode, landscape, 320×568, 430×932, forced colors, browser zoom, screen readers, throttled
  Lighthouse/Web Vitals, and warm-cache behavior remain unverified in this round.
- Exact dynamic interactive totals for Experiences and Timetable were not recovered; no number was
  fabricated. The copy subagent did not return a contract-compliant report inside the hard timebox.
