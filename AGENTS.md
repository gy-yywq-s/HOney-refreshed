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
- Replace the Login screen completely. Do not preserve the serif `HOney` title, text-only `HO` icon,
  or current layout.
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

- Prefer the strongest feasible solution without unnecessary cost or complexity. Use standard-library
  capabilities before adding dependencies when they meet the requirement.
- Keep changes cohesive, testable, and reviewable. Do not call a partial visual pass a completed
  redesign.
