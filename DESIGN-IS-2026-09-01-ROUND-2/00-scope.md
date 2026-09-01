# Design Is — Round 2 scope

## Audited artifact

- Live fixture surface: `https://honey.gaelis.cc/?demo=1`
- Exact deployed commit: `f84b6ef139fd` on branch `web-ionic`
- Repository surface: `apps/web-ionic/`, with read-only supporting product/design documents
- Representative routes: Home, Experiences feed, Explore, Compose, Timetable, lesson detail,
  Your notes & posts, Settings, Privacy, and the signed-out sign-in surface
- Viewport classes: compact phone (`375×667`), regular/tall phone (`390×844`), and desktop
  (`1440×900`)

## Primary user and task

The primary user is a HOney student. The primary task is to orient within the school day in about
three seconds, then directly reach timetable context or read/share anonymous-first-hand school
experiences without misleading identity, persistence, moderation, or privacy claims.

## Constraints

- Ionic React PWA; installed-PWA behavior and mobile browser behavior both matter.
- Reuse the existing serif wordmark/favicon assets and the current paper/ink/muted-blue grammar.
- `docs/design/shared-product-design-invariants.md` governs behavior and claims; Web visual choices
  remain an experimental platform hypothesis.
- The backend, API contract, iOS UI, and external school portal are out of scope and must not change.
- Fixture mode only for interactive audit evidence; no real-user authentication or external-data
  mutation.
- Accessibility floor: visible keyboard path, one main landmark, working skip link, WCAG AA text
  contrast, 44px repeated touch targets, reduced-motion support, and explicit user-facing states.

## Inputs and prior evidence

- `DESIGN-IS-2026-09-01-ROUND-1/04-handoff-prompt.md`
- `DESIGN-IS-2026-09-01-ROUND-1/05-refinement.md`
- `docs/design/shared-product-design-invariants.md`
- `docs/design/web-lab.md`
- Current source and emitted production assets under `apps/web-ionic/`

## Review boundary

This is a design audit, not an implementation pass. The audit scores only what is currently shipped
at the deployed commit. Repository code is used to explain observable behavior and edge states, not
as a substitute for browser evidence.
