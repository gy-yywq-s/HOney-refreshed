# Design-Is R2 scope lock — Ionic Web/PWA candidate

Date: 2026-09-01
Repository: `/home/honey/worktrees/web-ionic-fidelity`
Branch baseline: `web/ionic-fidelity@cbb0717de3051e6ae9114f0f02362c84b5605ed0`
Audited candidate: the current uncommitted working tree on that baseline, including the R1 implementation refinements visible in `git diff`.

## What is being audited

- Current local candidate implementation: `apps/web-ionic/`.
- R2 rendered evidence: `docs/web/evidence/ionic-fidelity/r2-candidate/`:
  - focused public Login at 390×844;
  - Experiences at 390×844 and 375×667;
  - Compose at 390×844;
  - Timetable scrolled to terminal content at 390×844;
  - Home at 1440×900.
- Current local production build and its chunk graph.
- Deterministic copy inventory and label→behavior assertions: `docs/web/evidence/ionic-fidelity/copy-inventory.json` and `apps/web-ionic/src/lib/copyIntegrity.test.ts`.
- Current code for core and supporting states, including public/authenticated bundle boundary, shell, Home, Feed, Explore, Compose, Timetable, History, Settings, modal/popover behavior, empty/loading/error/success/focus/disabled states.

`https://ionic.gaelisus.com` still serves the prior revision and is **STALE for R2**. It must not be used to score changed authenticated surfaces. Any public URL fact is historical context only. Local candidate browser evidence, current screenshots, source, and build are controlling.

## Primary user and primary task

Primary user: a HOney student using a phone browser, installed PWA, or desktop browser during the school day.

Primary task: orient to the current and next lesson in about three seconds, then reach the relevant timetable or student-experience action without losing context (`docs/design/shared-product-design-invariants.md:11-22`). The audit also checks raw student voice priority, privacy honesty, and complete finite-option discovery (`docs/design/shared-product-design-invariants.md:23-51`).

## Constraints

- Product truth: `docs/design/shared-product-design-invariants.md`; no `docs/product/` directory exists on this branch.
- Web and iOS remain independent design labs; Web is experimental/not owner-approved (`docs/status/current.md:12-24`, `docs/design/web-lab.md:1-38`).
- Current Web hypothesis remains quiet humanist: one neutral sans, narrow cool palette, one muted accent, state-explaining motion only, explicit scroll models, factual signed-in copy (`docs/design/web-lab.md:16-36`).
- Accessibility floor: contrast, 44px touch targets, keyboard paths, reduced motion, and honest empty/loading/error/stale states (`docs/design/shared-product-design-invariants.md:47-48`).
- All finite selectable options must be fully browsable; search is only an aid (`docs/design/shared-product-design-invariants.md:49-51`).
- Stack: Ionic React 9, React 18, React Router 6, Vite 5, TypeScript, custom HOney leaf presentation.
- Preserve `apps/web` intact. iOS, backend, shared API, database, product semantics, deployment, and external school portal are out of scope.
- No real credentials, authentication, secrets, portal access, implementation edits, commit, push, or deployment during R2.

## References and scoring boundary

- R1 artifacts under `DESIGN-IS-2026-09-01-R1/` are historical only and are not evidence for R2 scores.
- R2 is independently scored from current candidate evidence using the exact Design-Is anchors, worst-instance rule, and lower-score tie-breaker.
- The ≥24 target is an acceptance threshold, not a reason to alter scores.
- If any requested measurement cannot be reproduced, it is labeled measured/inferred/estimated with method and gap; no stale-live substitution is allowed.
