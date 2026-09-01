# Design-Is R3 scope lock — Ionic Web/PWA candidate

Date: 2026-09-01
Repository: `/home/honey/worktrees/web-ionic-fidelity`
Branch baseline: `web/ionic-fidelity@cbb0717de3051e6ae9114f0f02362c84b5605ed0`
Audited candidate: current uncommitted working tree, including the focused honesty/understandability changes made after R2.

## Audit target

- Implementation: `apps/web-ionic/`.
- R3 screenshots: `docs/web/evidence/ionic-fidelity/r3-candidate/` — Login focus, two Feed scope states, Compose, Timetable terminal state, desktop Home.
- Fresh copy evidence: `docs/web/evidence/ionic-fidelity/copy-inventory.json`, `apps/web-ionic/src/lib/copyIntegrity.test.ts`, and changed Compose/useComposer/Settings/Mine/Why/ExperiencePost copy plus actual behavior boundaries.
- Current production build and public/authenticated chunk graph.
- Current structural, visual, performance, and accessibility source for regression evidence.

`https://ionic.gaelisus.com` remains **STALE** and does not score changed surfaces. Browser evidence is local-only; no real credentials, portal access, backend traffic, or real identity are used.

## Primary user and task

Primary user: a HOney student using a phone browser, installed PWA, or desktop browser during the school day.

Primary task: identify Now/Next in about three seconds, then reach the relevant timetable or student-experience action without losing context (`docs/design/shared-product-design-invariants.md:11-22`). Truth constraints include raw student-voice priority, exact privacy claims, resonance-not-truth reactions, and complete finite-option discovery (`docs/design/shared-product-design-invariants.md:23-51`).

## Constraints

- Product truth comes from `docs/design/shared-product-design-invariants.md`; no `docs/product/` directory exists on this branch.
- Web and iOS are independent experimental labs (`docs/status/current.md:12-24`, `docs/design/web-lab.md:1-38`).
- Preserve quiet-humanist Web direction: one neutral sans, narrow cool palette, one muted accent, no ambient motion, explicit scroll models, factual copy (`docs/design/web-lab.md:16-36`).
- Accessibility floor: AA text, 44px touch targets, keyboard/focus paths, reduced motion, and honest empty/loading/error/stale states.
- Preserve complete finite option discovery.
- Preserve `apps/web`. Backend/shared API/database/iOS/product behavior/deployment/portal are out of scope and unchanged.
- Design-Is creates only R3 audit artifacts; no implementation edit, commit, push, or deploy.

## Evidence boundary

- R1/R2 artifacts and scores are historical only and cannot be reused as R3 scores.
- Five fresh bounded lanes cover structure, visual, copy/honesty, weight/friction, and accessibility.
- Unchanged layout screenshots may be reused only because the affected R3 diff is copy-only; changed Compose receives a fresh render/accessibility snapshot.
- Existing R2 measured geometry may support unchanged CSS/layout only and must be labeled as unchanged-candidate evidence, never fresh live deployment evidence.
- Scoring uses exact Design-Is anchors, worst representative instance, and lower-score tie-breaker. The ≥24 gate cannot inflate a score.
