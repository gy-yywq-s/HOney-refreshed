# HOney Project Instructions

This file contains the active instructions for work in the local repository at
`/Users/GaryS/Documents/HOney-refreshed`.

## Precedence and freshness

- The user's instructions in the current Codex conversation override this file.
- This file was distilled from `/home/honey/CLAUDE.md` on `codex-droplet`, but stale remote snapshots
  are not authoritative for current design, branch, build, deployment, or acceptance state.
- Verify time-sensitive state in the actual checkout before acting: branch, remote commits, signing,
  CI, deployed version, and device availability.

## Repository and naming

- The canonical product spelling is exactly `HOney`. Use lowercase `honey` only where capitals are
  impossible or inappropriate, such as package names, domains, database identifiers, and the Linux
  user. Do not introduce other casing variants.
- Keep the repository tidy: no stray build products, temporary files, credentials, generated
  experiments, or unrelated artifacts.
- Treat `ios/project.yml` as the Xcode project source of truth. Regenerate with XcodeGen when source
  membership changes, then verify the generated project. Personal Apple development-team settings
  are local configuration and must not be committed unless the user explicitly asks.
- Keep `README.md` and architecture/design documentation accurate when implementation milestones
  materially change the product.

## Current iOS redesign direction — supersedes remote legacy rules

- The current iOS interface and brand are a draft. The earlier rules to copy the legacy UI wholesale,
  preserve the legacy serif wordmark, or keep brand redesign on hold are superseded.
- Selected visual direction: quiet, modern, editorial, warm and intelligent without feeling childish.
- Selected brand direction: a new typographic `HOney` wordmark plus an independent small mark.
- Home's primary visual focus is the current class / next lesson. Access and Experiences may appear
  as secondary content, but must not compete with the school-day focal object.
- The current large-area gradients and large opaque color blocks must be redesigned. Large-area color
  is a high-risk compositional decision: specify its semantic role, area, direction, depth, layering,
  contrast, and relationship to content. Reusing the same token does not make different applications
  equivalent.
- A redesigned Home gradient is allowed only when it is newly composed, restrained, dimensional,
  and validated in simulator/device screenshots. Merely changing opacity is insufficient.
- Settings must offer a persisted Surface palette choice instead of locking the app to the current
  pale paper/brown canvas. Candidate surfaces include current paper, neutral white, cool mist, and
  soft gray; every choice must define coherent light/dark canvas, surface, muted-surface, line, and
  ink roles without becoming a large saturated-color skin.
- Surface choices remain part of the iOS product experiment. Present every available palette
  directly instead of hiding choices in a dropdown, and keep each palette's accent tuned to its own
  background rather than sharing an unchanged accent tuple.
- The blue-teal accent remains one semantic family, but each Surface palette must tune its own
  `accent`, `accentSoft`, and `accentForeground` values to harmonize with that surface and pass
  contrast in light/dark mode. Do not paste one unchanged accent RGB tuple onto every background.
- Replace the Login screen completely. Do not preserve the serif `HOney` title, text-only `HO` icon,
  or current layout.
- Never use small uppercase or small-caps text as a heading, eyebrow, section label, status label, or
  navigation aid anywhere in the app. Use natural title case or sentence case at a legible semantic
  size. Native list/form section headers must explicitly preserve their natural casing instead of
  inheriting an all-uppercase treatment.
- Judge color, fill, borders and cards as a composition, not as individually banned ingredients.
  White cards, repeated accents, borders and tonal fills are allowed when their contrast, proportion,
  repetition, surrounding ground and hierarchy make the whole screen coherent. The Home failure to
  avoid is one isolated high-contrast pure-white bordered hero floating on an otherwise colored or
  gradient screen; the problem is that relationship, not white or borders themselves.
- A Surface palette defines the page atmosphere, but its tokens may still be used in fills when that
  use belongs to the composition and semantic role. Porcelain and other background hues can be page
  ground, a quiet surface, or a small detail; decide from the whole screen instead of turning the
  token name into a universal rule. Reusing one accent is desirable when it expresses the same
  interaction or state. Add supporting colors only where they clarify distinct content or hierarchy,
  not to satisfy a color quota, and do not mechanically assign every icon a different color.
- Keep earlier approved color directions available as persisted Settings choices when exploring new
  palettes. Adding a candidate must not silently replace the user's ability to compare prior choices.
- Never tell users to use search to reveal selectable options that the product omitted. If an item is
  available to choose, provide a complete scrollable, grouped, paginated, or progressively disclosed
  list; search may filter that complete set but cannot be the only route to the remaining choices.
- Every Timetable lesson card must show the teacher name when the backend supplies it. When it is
  absent, show an honest unavailable label rather than silently omitting the field or inventing one.
- ImageGen may be used for bounded wordmark/mark exploration. Selected concepts must be translated
  into production-appropriate assets and verified at small size, monochrome, and accessible contrast;
  do not paste a raster wordmark throughout the UI.
- Current audit artifacts live under `DESIGN-IS-2026-09-01/`. The active verdict is REDESIGN (8/30),
  and `04-handoff-prompt.md` is the implementation-planning source.

## Design and review discipline

- Do not invent aesthetic rationale from the product name or generic associations. Every visual
  decision must trace to an explicit user direction, a user-selected reference, or an approved design
  source. When a material taste decision remains open, ask the user rather than disguising a guess as
  a decision.
- Use the available `design-is` skill for Rams design audits and the `imagegen` skill for new raster
  brand exploration.
- When the user requests subagents or the current environment explicitly permits them, use subagents
  for bounded evidence gathering and review tasks. The main agent owns whole-system design,
  decomposition, synthesis, and cross-screen coherence; do not delegate the holistic direction.
- Build all requested surfaces coherently, then run the full design optimization pass. Do not polish
  one isolated screen while leaving the rest in an incompatible system.
- Final UI acceptance requires a design review across all relevant surfaces and a `design-is` score
  of at least 22/30, with no unresolved load-bearing honesty, usefulness, or understandability failure.
- Design scope includes runtime experience, not appearance alone: cold launch, first interaction,
  navigation latency, main-thread stalls, scrolling smoothness, network-bound loading feedback,
  cancellation, timeout behavior, repeated-open behavior, and perceived responsiveness are all
  reviewable product-design concerns.
- The scope is the whole app, including business logic, state machines, caching, request
  coordination, cancellation, stale-response protection, data consistency, persistence, and error
  recovery. Do not classify a logic or runtime defect as out of scope merely because it is not visual.
- A visually correct screen is not acceptable if opening it freezes, blocks interaction, or leaves
  the user without truthful progress. Runtime regressions are prioritized before cosmetic refinement.
- Do not attach standard whole-screen pull-to-refresh behavior to app pages. Pulling a long fixed
  viewport down is a disproportionate gesture and can conflict with navigation and reading. Refresh
  through a compact, explicit control near the relevant data or in the toolbar, preserve existing
  content while refreshing, and expose failures next to the affected content.
- Timetable day changes must use explicit controls. Do not bind a broad full-screen horizontal drag
  gesture to day navigation; it is too easy to trigger accidentally and competes with scrolling and
  card interaction. Every lesson must be presented as its own clearly bounded card with subject,
  teacher (or an honest unavailable label), time, and room context.

## Product and honesty constraints

- Preserve the product responsibility boundaries: SwiftUI presentation, view models/services,
  HTTP API contracts, and backend/domain rules remain separated.
- The school portal is an external identity/data source. Do not re-probe, crawl, scrape, or
  authenticate against it merely to redesign or review local UI; the existing connector analysis is
  the reference unless the user explicitly requests a fresh live verification.
- Experiences privacy is load-bearing: no public author identity, device-held ownership controls,
  device-local private notes, deliberate publication, and fail-closed moderation.
- Access is a physical action. Gate labels, permit state, confirmations, failures, and routing must
  match verified behavior. Never substitute a friendly Front/Back label for an unknown door mapping.
- Never swallow a failed request into a success or empty state. Visible loading, empty, error,
  success, focus, disabled, offline, destructive, and permission states must be behaviorally true.
- Labels such as sign out, disconnect, delete, import, and password handling must describe their
  actual scope precisely.

## Accessibility, performance, and verification

- Use native SwiftUI behavior where it helps, while explicitly verifying VoiceOver labels/order,
  Dynamic Type through accessibility sizes, 44-point minimum targets, contrast, Reduce Motion, and
  system appearance.
- Honor the user's system appearance instead of forcing light mode unless the user explicitly chooses
  a locked appearance.
- Retain the low-attention baseline: no idle animation, badges, or notifications without a concrete
  product need. Motion must respect Reduce Motion.
- Measure and inspect high-risk runtime paths, especially first-open WebViews and physical Access:
  expensive setup must stay off the main actor, loading must be visible and cancellable where
  practical, timeouts must become actionable states, and a second open must not inherit a wedged
  first-open state.
- Treat a long unresponsive first tap or apparent freeze as a P0 defect. Reproduce it with timestamps
  and logs, locate the blocking work, fix the cause, and verify both cold and warm paths.
- Navigation over network-backed data must be responsive and race-safe: use appropriate in-memory
  caching/prefetch, cancel obsolete work, prevent stale responses from overwriting current state,
  preserve previously loaded content during refresh, and distinguish cached, loading, empty, error,
  and refreshed states truthfully.
- For iOS changes, regenerate the project if needed, compile a signed arm64 Debug device build, run
  the full unit-test suite, and inspect representative simulator/device screenshots before claiming
  completion.
- Acceptance is implementation-based, not merely conflict-based: verify the applicable master-spec
  requirements and launch gates line by line for final delivery.

## Security and external changes

- Never write passwords, tokens, API keys, private session data, or user credentials into the repo,
  `AGENTS.md`, audit artifacts, shell commands, logs, commits, or subagent messages.
- Do not commit, push, merge, deploy, or mutate the external school portal unless the user explicitly
  authorizes that action in the current conversation.
- Preserve unrelated local changes. Inspect before switching branches, regenerating projects, or
  applying broad mechanical edits.

## Engineering standard

- Prefer the strongest feasible solution without unnecessary cost, complexity should not be a consideration in most circumstances.
- Use standard-library
  capabilities before adding dependencies when they meet the requirement.
- Keep changes cohesive, testable, and reviewable. Do not call a partial visual pass a completed
  redesign.
