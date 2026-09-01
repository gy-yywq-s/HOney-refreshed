```text
/make-plan Redesign HOney iOS runtime state architecture. Current design failed audit at 16/30 with critical gaps in principles #2 useful, #4 understandable, #6 honest, #8 thorough, and #9 environmentally friendly.

Verdict paragraph (quoted from 03-verdict.md):
> REDESIGN — At 16/30 with principle #8 at 0, HOney’s visual foundation contains valuable work, but its cross-screen runtime state architecture does not yet make Portal, Timetable, persistence, and destructive actions predictably responsive, cancellable, or behaviorally true.

Why redesign and not refine: The total is below 20 and a shipped School Portal flow lacks four or more fundamental states while appearing frozen in direct user observation; these gaps span WebView lifecycle, request coordination, persistence contracts, and multiple screens, so isolated visual refinement cannot resolve them.

Preserve from current design:
- Lesson-first Home hierarchy and direct tab shell. Evidence: `ios/HOney/Features/Home/HomeView.swift:20-49,105-180`; `ios/HOney/Features/Main/MainTabView.swift:15-39`.
- Adaptive semantic color/type system, audited contrast, exact returned-door confirmation, target-bound publishing, and device-local privacy model. Evidence: `ios/HOney/DesignSystem/AppTheme.swift:35-129`; `ios/HOney/Features/Access/AccessView.swift:72-108,682-737`; `ios/HOney/Features/Experiences/ComposeExperienceView.swift:15-59`.
- Blue-teal accent as a distinct functional semantic role. Each user-selected Surface palette may tune its own `accent`, `accentSoft`, and `accentForeground` values within that family for harmony and verified contrast; palettes need not share one accent RGB, and accent must not become a saturated large-area skin. Evidence: `ios/HOney/DesignSystem/AppTheme.swift:35-46`.

Discard:
- Raw `WKWebView` presentation with invisible lifecycle, swallowed failure, unbounded navigation, and no cancellation. Evidence: `ios/HOney/Features/Home/PortalWebView.swift:68-78,99-136`; `ios/HOney/Services/PortalWebSessionBridge.swift:80-95`. Caused failures on principles #2, #4, and #8.
- Fire-and-forget mutable-date Timetable loads without cache, cancellation, coalescing, prefetch, or stale-response guard. Evidence: `ios/HOney/Features/Timetable/TimetableViewModel.swift:14-63`; `ios/HOney/Features/Timetable/TimetableView.swift:60-63,96-148`. Caused failures on principles #2, #6, #8, and #9.
- Success/empty/destructive flows built on storage operations that suppress failure. Evidence: `ios/HOney/Services/OwnershipKeyStore.swift:36-64`; `ios/HOney/Services/PrivateNoteStore.swift:78-85`; `ios/HOney/Services/ComposerDraftStore.swift:51-77`. Caused failures on principles #6 and #8.

Top 3–5 moves from the audit (verbatim):
1. **Principles #2, #4, and #8 — Responsive School Portal:** Replace the raw-WebView sheet with an explicit cold/warm state machine, immediate visible loading, progress/error/timeout/retry/cancel behavior, retained cancellable tasks, bounded recovery, wired login-route detection, and credential-free latency instrumentation. Evidence: §E7; `ios/HOney/Features/Home/PortalWebView.swift:15-136`; `ios/HOney/Services/PortalWebSessionBridge.swift:23-169`.
2. **Principles #2, #6, #8, and #9 — Deterministic Timetable:** Own and cancel date requests, key them by immutable requested date, add per-date cache and adjacent prefetch, coalesce duplicates, guard stale completions, preserve prior content during nonblocking load, and test rapid out-of-order navigation. Evidence: §E2, §E7; `ios/HOney/Features/Timetable/TimetableViewModel.swift:14-63`; `ios/HOney/Features/Timetable/TimetableView.swift:60-63,96-148`.
3. **Principles #6 and #8 — Honest persistence:** Make ownership-key writes/reads and destructive local clears verifiable; never clear a draft or show Published/Deleted/Empty until device operations succeed, and provide post-publish key recovery. Evidence: §E4 P0; `ios/HOney/Services/OwnershipKeyStore.swift:36-64`; `ios/HOney/Features/Experiences/ComposeExperienceViewModel.swift:283-298`.
4. **Principles #6 and #8 — Truthful session and Access state:** Scope sync notices to account/session, handle credential persistence, separate permit/door/mutation/refresh states, and preserve mutation outcomes across refresh. Evidence: §E4 P1; `ios/HOney/App/AppModel.swift:20-30,56-79,90-169`; `ios/HOney/Features/Access/AccessViewModel.swift:32-76`.
5. **Principles #3, #4, #7, and #8 — Finish and verify the surface:** After runtime architecture is stable, add the direct focal-lesson action and visible My Posts label, package the approved wordmark/small mark, add a persisted independent Surface palette selector for paper/neutral white/cool mist/soft gray, and run state/accessibility/cold-warm/race/device verification. Evidence: §E3, §E5, §E7.

Redesign principles in priority order:
1. Principle #8 — Thorough: every network, persistence, and physical-action flow has explicit idle/loading/progress/success/empty/error/timeout/retry/cancel states and stale-response protection.
2. Principle #2 — Useful: first feedback is immediate, cold/warm latency is bounded, navigation stays responsive, and the selected date/screen always matches displayed data.
3. Principle #6 — Honest: success, empty, deletion, anonymity, and connection claims appear only after the underlying operation is verified.

Deliverables for the plan:
- New runtime information architecture showing ownership of Portal, Timetable, persistence, Access, and account state machines.
- New primary flows for Portal cold/warm open and rapid Timetable date navigation, shown side-by-side with current behavior.
- Explicit state checklist: idle, creating, loading, progress, content, empty, success, error, offline, timeout, retry, cancelled, stale-suppressed, and destructive partial failure.
- Cancellation/deadline/cache/coalescing/stale-response contracts and instrumentation points.
- Credential-free local Web fixtures and delayed/out-of-order API doubles covering cold/warm, dismiss/reopen, never-finishing, 401/419/login-route, rapid next-next/week-week, cache, prefetch, offline, and race cases.
- A persisted `SurfacePalette` preference in Settings with at least current paper, neutral white, cool mist, and soft gray. Each option must define coherent light/dark canvas/surface/surfaceMuted/line/ink/inkSecondary plus its own harmonized blue-teal `accent`/`accentSoft`/`accentForeground` roles. Verify text/control contrast separately for every option; do not force one accent RGB across palettes, and do not allow saturated large-area color skins.
- Production wordmark/small-mark packaging after user approval, validated against every Surface palette in light/dark and monochrome.
- Migration path that preserves the semantic visual system and API boundaries while replacing screen-owned fire-and-forget work.
- Cutover criteria: no user-observed frozen or paused input; defined latency budgets pass; stale results cannot overwrite current state; persistence failure cannot produce success/empty copy; palette survives relaunch and all options pass contrast; VoiceOver/Dynamic Type/Reduce Motion and physical-device checks pass.

Anti-patterns to guard against:
- Porting old request behavior under a spinner without cancellation or deadlines.
- Treating eventual correctness as responsiveness.
- Using a global `isLoading` Boolean where independent state machines are required.
- Prewarming or retrying without measuring energy/network cost and cancellation.
- Hiding persistence or recovery failure behind generic success, empty, or dismissal.
- Reusing one accent RGB without checking palette harmony, drifting outside the blue-teal semantic family, or using saturated full-screen skins.
- Restyling the coherent semantic foundation instead of repairing runtime architecture.
```
