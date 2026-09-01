# HOney iOS design audit scope

## Audited artifact

- Repository: `/Users/GaryS/Documents/HOney-refreshed`
- Branch and revision: `ios-build-v1` at `b3f30437e8a15dc297dc6e09be808e5eae3b9eda`
- Surface: the current SwiftUI iPhone application under `ios/HOney`, including authentication and import consent, Home, Experiences and composition/history flows, Timetable and lesson detail, Access, and Settings.
- Runtime baseline: iOS 17+, evaluated from the compiled current checkout and representative simulator screens where reachable.

## Primary user and task

- Primary user: a HOney student using an iPhone during daily school life.
- Primary task: quickly understand the current school-day state, then complete a high-frequency action such as checking the next lesson, reading or composing an Experience, or operating campus Access without ambiguity.

## Constraints

- Preserve the exact `HOney` casing and current product behavior/API boundaries.
- Preserve SwiftUI and iOS 17+ compatibility.
- Treat the current interface as a draft. The large blue gradients, existing brand treatment, and legacy visual grammar are not preservation requirements.
- Use `docs/design/legacy-port-map.md` only to explain the current implementation, not to limit a REFINE or REDESIGN verdict.
- The current large-area gradients and large opaque color fills are mandatory redesign targets. Large-area color is a high-risk device, not a default token application: its area, direction, depth, layering, contrast, and relationship to content must each be justified and visually verified.
- A redesigned Home gradient is not categorically forbidden. It may survive only as a newly composed, more restrained and dimensional treatment that passes visual review; reusing the same token or merely changing opacity is insufficient.
- Existing color tokens may remain candidates only when reassigned according to semantic role, hierarchy, and appropriate visual area; token reuse alone is not visual parity.
- The login screen is a mandatory full replacement. Do not preserve the serif `HOney` title, the text-only `HO` icon, or the current composition.
- A later design plan may include ImageGen exploration for a new typographic brand treatment or mark, but this audit does not generate or implement that brand.
- Respect the privacy, anonymity, fail-closed moderation, and direct-to-school Access constraints documented in `README.md` and `docs/decisions-2026-08-31.md`.
- This audit produces evidence, scores, a verdict, and a `/make-plan` handoff only. It does not implement UI changes.

## Reference set

- `docs/design/legacy-port-map.md`
- `README.md`
- `docs/decisions-2026-08-31.md`
- Current SwiftUI source under `ios/HOney`
- Current unit tests under `ios/HOneyTests`

The reference set documents what exists; it is not a visual preservation list. A redesign may replace the gradient, palette, brand treatment, component grammar, and screen composition while keeping the product constraints above.

## Known limits at scope lock

- The paired physical iPhone is currently unavailable to CoreDevice, so physical-device interaction is not part of the initial evidence set.
- Network-backed signed-in states depend on school and HOney services; when they cannot be reached safely, evidence must be marked source-inferred rather than presented as observed runtime behavior.
- Private login credentials are excluded from all artifacts, source changes, commits, command arguments, and subagent messages. They are not required to complete this source-and-runtime audit.
