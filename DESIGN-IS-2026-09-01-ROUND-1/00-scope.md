# Design Is — Round 1 Scope

## Audited artifact

- Product: HOney Ionic Web/PWA implementation on branch `web-ionic`
- Final audited commit: `ed829f8`
- Moving-target note: evidence began at `f126190`; the final synthesis rechecked the
  limited `f126190..ed829f8` delta and the reconciled live assets. The wordmark,
  password-manager autofill submission, and consent-decline redirect were fixed
  before scoring and are not open findings.
- Live development URL: `https://honey.gaelis.cc/?demo=1`
- Data mode: fixture data, explicitly not live-backend evidence
- Repository: `/home/honey/worktrees/web-ionic`
- Primary implementation: `apps/web-ionic`
- Existing browser evidence: `docs/web/evidence/ionic-browser-2026-09-01/`

## Representative surfaces and viewport matrix

- Mobile: 390 x 844 and 375 x 667
- Desktop: 1440 x 900
- Routes: Home, Experiences, Explore, Composer, Timetable, History, Mine, Privacy, Access, and representative entity / lesson detail where reachable
- Runtime checks: console, network, overflow, scroll ownership, keyboard focus, PWA manifest/service worker evidence

## Primary user and task

The primary user is a student using HOney to orient around current school context and move into an identity-free experience stream. The primary task is to understand the current lesson/context, browse useful peer experience, and publish a privacy-preserving experience or private note without misrepresenting backend or platform capability.

## Constraints

- Ionic React Web/PWA; no Capacitor and no backend changes
- Existing HOney web remains separate; this implementation deploys at `honey.gaelis.cc`
- Preserve approved product semantics, especially identity-free public storage and honest fixture / unsupported-state communication
- Follow the quiet editorial design language in `/root/.codex/skills/gary-design-language/references/DESIGN.md`
- Reuse the existing approved `apps/web` wordmark implementation/artwork and directly reuse other existing brand assets where applicable
- Acceptance reference: `docs/research/design-audits/repo-review-v3-2026-09-01.md`
- Accessibility floor: keyboard-operable primary flows, visible focus, semantic landmarks, readable contrast, reduced-motion support

## Non-goals

- Installed-PWA behavior is not inferred from ordinary browser rendering
- Live backend correctness is not inferred from fixture mode
- iOS UI and backend implementation are out of scope
- Review artifacts may be written; product implementation must not be modified in this phase
