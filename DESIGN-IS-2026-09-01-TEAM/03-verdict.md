# Verdict

**REDESIGN** — At 16/30 with principle #8 at 0, HOney’s visual foundation contains valuable work, but its cross-screen runtime state architecture does not yet make Portal, Timetable, persistence, and destructive actions predictably responsive, cancellable, or behaviorally true.

## Why redesign rather than refine

The total is below 20 and a shipped School Portal flow lacks four or more fundamental states while appearing frozen in direct user observation; these gaps span WebView lifecycle, request coordination, persistence contracts, and multiple screens, so isolated visual refinement cannot resolve them.

## Highest-leverage moves

1. **Principles #2, #4, and #8 — Responsive School Portal:** Replace the raw-WebView sheet with an explicit cold/warm state machine, immediate visible loading, progress/error/timeout/retry/cancel behavior, retained cancellable tasks, bounded recovery, wired login-route detection, and credential-free latency instrumentation. Evidence: §E7; `ios/HOney/Features/Home/PortalWebView.swift:15-136`; `ios/HOney/Services/PortalWebSessionBridge.swift:23-169`.
2. **Principles #2, #6, #8, and #9 — Deterministic Timetable:** Own and cancel date requests, key them by immutable requested date, add per-date cache and adjacent prefetch, coalesce duplicates, guard stale completions, preserve prior content during nonblocking load, and test rapid out-of-order navigation. Evidence: §E2, §E7; `ios/HOney/Features/Timetable/TimetableViewModel.swift:14-63`; `ios/HOney/Features/Timetable/TimetableView.swift:60-63,96-148`.
3. **Principles #6 and #8 — Honest persistence:** Make ownership-key writes/reads and destructive local clears verifiable; never clear a draft or show Published/Deleted/Empty until device operations succeed, and provide post-publish key recovery. Evidence: §E4 P0; `ios/HOney/Services/OwnershipKeyStore.swift:36-64`; `ios/HOney/Features/Experiences/ComposeExperienceViewModel.swift:283-298`.
4. **Principles #6 and #8 — Truthful session and Access state:** Scope sync notices to account/session, handle credential persistence, separate permit/door/mutation/refresh states, and preserve mutation outcomes across refresh. Evidence: §E4 P1; `ios/HOney/App/AppModel.swift:20-30,56-79,90-169`; `ios/HOney/Features/Access/AccessViewModel.swift:32-76`.
5. **Principles #3, #4, #7, and #8 — Finish and verify the surface:** After runtime architecture is stable, add the direct focal-lesson action and visible My Posts label, package the approved wordmark/small mark, add a persisted independent Surface palette selector for paper/neutral white/cool mist/soft gray, and run state/accessibility/cold-warm/race/device verification. Evidence: §E3, §E5, §E7.
