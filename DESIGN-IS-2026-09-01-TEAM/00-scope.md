# HOney iOS team design audit scope

## Audited artifact

- Repository: `/Users/GaryS/Documents/HOney-refreshed`
- Branch: `codex/ios-editorial-redesign`
- Baseline commit: `a3c3a966d129ecd2e1f462a79ed7dbeb6cd83b32`
- Surfaces: Login, import consent, Home, School Portal, Experiences, composer/entity/history/submissions, Timetable/lesson detail, Access, Settings, and the shared SwiftUI design system.
- Runtime/system scope includes business logic, state machines, caching, request coordination and cancellation, stale-response protection, persistence, data consistency, loading feedback, deadlines/timeouts, and cold/warm responsiveness—not only rendered appearance.
- Runtime evidence: `DESIGN-IS-2026-09-01-POST/evidence/login-light-placeholder-v2.png` and `login-dark-placeholder-v2.png`, each 1206x2622 px (402x874 pt at 3x).
- User-observed P0 runtime evidence: the first tap of School Portal hangs for a long time and the app appears frozen/dead.
- User-observed runtime evidence: rapid Timetable next-next navigation pauses before responding.
- The only local worktree delta at scope lock is the personal `DEVELOPMENT_TEAM` value in `ios/HOney.xcodeproj/project.pbxproj`; it is excluded from design evidence.

## Primary user and task

- Primary user: a student using an iPhone during the school day.
- Primary task: understand the current or next lesson immediately.
- Secondary tasks: share or browse a lesson-bound Experience, inspect another timetable day, operate direct-to-school Access, and manage privacy/account state without ambiguous consequences.
- Every task must acknowledge input promptly, expose loading/progress/failure truthfully, remain cancellable where work is nonessential, prevent stale responses from overwriting current state, and distinguish cold from warm behavior.

## Constraints

- Preserve SwiftUI and iOS 17+ compatibility, HTTP/API boundaries, privacy, device-local notes/drafts/post-control keys, fail-closed publication, and direct-to-school physical Access.
- Keep the selected direction quiet, modern, editorial, warm, and intelligent; Home remains lesson-first.
- Do not restore the legacy visual grammar. The wordmark is still a temporary asset slot owned by the user’s final brand decision.
- The accent remains in the blue-teal semantic family, while Surface is a persisted user choice. Settings must offer multiple coherent light/dark Surface options—current paper, neutral white, cool mist, and soft gray are acceptable candidates. Each option may and should tune its own `accent`, `accentSoft`, and `accentForeground` values for harmony and verified contrast; themes are not required to share one accent RGB. Accent remains a functional semantic role rather than a saturated large-color skin.
- Honor system appearance, Reduce Motion, Dynamic Type, VoiceOver, and 44-point targets.
- No credentials, live school login, backend mutation, or application-source edit is part of this audit.
- The two user observations above are direct runtime evidence even though credential-free reproduction and instrumentation remain required for root-cause isolation.

## Reference set

- Current committed SwiftUI source under `ios/HOney` at `a3c3a96`.
- Current committed tests under `ios/HOneyTests`.
- Committed Portal WebView/session/coordinator and Timetable request-state code.
- The two final Login light/dark captures named above.
- `AGENTS.md` product, honesty, accessibility, and acceptance constraints.

## Known limits

- Only default disabled Login was captured by the audit team; signed-in source is otherwise inferred, except for the user-observed Portal cold-open hang and rapid Timetable navigation pause.
- No physical-iPhone, VoiceOver, accessibility Dynamic Type, external-keyboard, energy, Release archive, or App Store thinning run was available.
- Backend claims were checked against the existing client contract, not re-probed against the school portal.
