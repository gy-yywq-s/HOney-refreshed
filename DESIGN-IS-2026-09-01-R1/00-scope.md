# Design-Is scope lock — Ionic Web/PWA

Date: 2026-09-01
Audit target commit: `web/ionic-fidelity@cbb0717de3051e6ae9114f0f02362c84b5605ed0`
Exact comparison base: `integration/product-v2@3d91cb3f3981f282268dbd598f1106c2fd53732c`

## What is being audited

- The already-implemented, already-deployed Ionic Web/PWA at `https://ionic.gaelisus.com`.
- Implementation path: `apps/web-ionic/`.
- Core signed-in surfaces represented by the existing ten-state evidence matrix: Home, Experiences feed, Explore, Compose, and Timetable at 390×844; Home and Experiences at 375×667; Home, Experiences, and Explore at 1440×900.
- Supporting flows and states in code: Login, History, entity pages, private/public history, Why, Settings, admin Dash, modal/popover interactions, empty/loading/error/success/focus/disabled behavior.
- User-visible evidence: `docs/web/evidence/ionic-fidelity/ionic/`, with `docs/web/evidence/ionic-fidelity/reference/` used only as a like-for-like reference set, never as a visual convergence mandate.
- Deployment and prior measurement facts: `docs/web/ionic-fidelity.md:1-171`.

## Primary user and primary task

Primary user: a HOney student using a phone browser, installed PWA, or desktop browser during the school day.

Primary task: orient to the current and next lesson in about three seconds, then reach the relevant timetable or student-experience action without losing context. This is grounded in `docs/design/shared-product-design-invariants.md:11-22`; the audit also checks that raw student voices, privacy semantics, and complete option discovery remain intact (`docs/design/shared-product-design-invariants.md:23-51`).

## Product and design constraints

- Product truth and claim semantics come from `docs/design/shared-product-design-invariants.md:1-58`; there is no `docs/product/` directory at this commit.
- The Web lab is independent from iOS and remains experimental/not approved (`docs/status/current.md:12-24`, `docs/design/web-lab.md:1-5`). No cross-platform visual convergence is assumed.
- Current Web hypothesis: quiet humanist typography, a narrow cool palette with one muted accent, state-explaining motion only, explicit scroll models, and factual signed-in copy (`docs/design/web-lab.md:16-36`).
- Accessibility floor: contrast, touch targets, keyboard/VoiceOver paths, reduced-motion, and honest loading/empty/error/stale states (`docs/design/shared-product-design-invariants.md:47-48`).
- All finite selectable options must remain completely browsable; search may filter but cannot be the only discovery path (`docs/design/shared-product-design-invariants.md:49-51`).
- Stack is Ionic React 9 + React 18 + React Router 6 + Vite 5 + TypeScript, with a custom HOney leaf presentation (`docs/web/ionic-fidelity.md:13-33`).
- Existing `apps/web` must remain intact. This audit does not review or change `apps/web`, iOS, backend, shared API, database, deployment configuration, or external school portal behavior.
- No implementation, commit, push, deployment, credential access, real login, or portal probing occurs during Design-Is.

## Reference designs and inputs

- The existing Web screenshots in `docs/web/evidence/ionic-fidelity/reference/` are a fidelity comparator for the same ten states, not an approved final design.
- The live Ionic surface and deterministic/mock signed-in screenshots are the shipped-design evidence.
- The quiet-humanist Web lab in `docs/design/web-lab.md` is an explicit design hypothesis, not owner approval.
- The legacy brand wordmark/icon remain the current brand assets; the audit does not invent new brand rationale.

## Evidence rules and known pre-audit gaps

- Evidence must combine source-code inspection with rendered/user-visible inspection; screenshots alone are insufficient.
- Any value not directly measurable must be labeled `INFERRED` or `ESTIMATED` with method.
- The public live surface is unauthenticated; signed-in inspection therefore relies on the existing deterministic screenshot matrix and source behavior. No real credentials will be used.
- Physical iOS Safari/Android Chrome install behavior is not available; Chromium evidence and source inspection are used, and this remains an explicit gap (`docs/web/ionic-fidelity.md:162-166`).
