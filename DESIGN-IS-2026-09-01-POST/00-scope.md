# HOney iOS post-redesign audit scope

## Artifact

- Current uncommitted iOS redesign on local branch `ios-build-v1`.
- SwiftUI surfaces: Login, import consent, Home, Experiences, composer/entity/history/submissions, Timetable/lesson detail, Access, and Settings.
- Runtime evidence: `evidence/login-light.png` and `evidence/login-dark.png` on an iPhone 17 Pro simulator.
- Verification evidence: 77 unit tests passing and signed generic-iPhone arm64 Debug build succeeding.

## Primary user and task

- A student using an iPhone during the school day.
- The first priority is understanding the current or next lesson. Secondary tasks are targeted Experience creation/browsing and verified school Access.

## Current constraints

- Quiet, modern, editorial, warm, and intelligent without feeling childish.
- Home is lesson-first; Access and Experiences remain secondary.
- The user owns final wordmark/mark work. `BrandWordmarkPlaceholder` is a temporary thin-wordmark slot only.
- No legacy preservation requirement. Large-area color must be justified by role, area, depth, layering, contrast, and content relationship.
- A restrained Home atmosphere is allowed; the Login has no large gradient or opaque accent block.
- Preserve privacy, local drafts/notes/keys, fail-closed publication, and direct-to-school physical Access.
- No credentials or live school login are used in the audit; signed-in runtime surfaces are source-inferred.

## Acceptance

- Evidence-only subagent reports; the orchestrator scores.
- Apply the design-is worst-instance and tie-breaker rules.
- Project target: at least 22/30 and no unresolved load-bearing honesty, usefulness, or understandability failure.
