```text
/make-plan Refine HOney iOS based on an independent Dieter Rams post-fix audit (total 20/30).

Verdict paragraph (quoted from 03-verdict.md):
> REFINE — At 20/30 with no zero-scored principle, the post-fix architecture has restored a viable lesson-first, bounded-runtime foundation, but persistence truth, Access mutation safety, transient data-state accuracy, and current runtime verification must be completed before release acceptance.

Keep (already strong, do NOT touch in this pass):
- Principle #2 (useful) scored 3 — Evidence: current/next lesson remains the first complete Home object at `ios/HOney/Features/Home/HomeView.swift:110-180`, with bounded Portal and cached Timetable routes at `PortalWebView.swift:83-216` and `TimetableViewModel.swift:46-177`. Regression check: preserve immediate lesson understanding, target-bound publication, one-attempt Portal behavior, and date/generation guards.
- Principle #9 (environmentally friendly) scored 3 — Evidence: `ios/HOney/App/AppConfig.swift:14-17`, `App/RootView.swift:9-30`, `Features/Access/AccessView.swift:9-12,213-353`, `Services/TimetableRepository.swift:19-122`. Regression check: verify no forced appearance, idle animation, notification/badge, uncancelled request fan-out, or custom motion outside Reduce Motion.

Fix in priority order (top moves from the audit, verbatim):
1. **Principles #6 and #8 — Finish persistence truth:** Make draft writes and session/credential clears verifiable; surface recovery-journal read errors; separate verified-key success from draft/journal cleanup failure; clear stale recovery safely; and scope sync notices to account/session. Evidence: §E4 P1; `ios/HOney/Services/ComposerDraftStore.swift:50-79`; `ios/HOney/Features/Experiences/ComposeExperienceViewModel.swift:150-176,244-264,341-364`; `ios/HOney/App/AppModel.swift:63-98,183-223`.
2. **Principles #2, #6, and #8 — Close safety/state races:** Disable stale permit-row actions after permit failure, make physical Access mutation single-flight, cover Timetable content during the 60ms date debounce, and show Portal account-reset preparation before awaiting data removal. Evidence: §E2, §E5; `ios/HOney/Features/Access/AccessViewModel.swift:46-54,98-116`; `AccessView.swift:182-210,269-340`; `TimetableViewModel.swift:56-63,93-114`; `PortalWebView.swift:83-127`.
3. **Principle #8 — Prove the new runtime:** Add credential-free Portal attempt/reset, Access partial-state/single-mutation, Timetable invalidate/TTL/debounce, recovery failure, and local-cleanup tests; capture current light/dark signed-in states and measure Portal cold/warm plus app TTI. Evidence: §E1, §E5, §E6, Known gaps.
4. **Principles #2 and #4 — Clarify direct actions:** Add a restrained focal-lesson action, replace icon-only My Posts with visible `My posts & notes`, rename `Share a lesson` to `Share an experience`, and name the recovery journal in erase-everything copy. Evidence: §E2, §E4; `ios/HOney/Features/Home/HomeView.swift:110-193`; `ExperiencesView.swift:27-38`; `SettingsView.swift:62-76`.
5. **Principles #3 and #7 — Finish production identity:** Replace the placeholder wordmark, add the independent small mark, and visually validate current Paper plus contrast-extreme alternate Surface palettes across Login and signed-in states. Evidence: §E3; `ios/HOney/DesignSystem/AppComponents.swift:283-295`; `ios/HOney/DesignSystem/AppTheme.swift:21-165`.

Out of scope for this refine pass: a new information architecture, legacy visual restoration, backend/domain-contract redesign, live school-portal probing, deployment, and committing personal DEVELOPMENT_TEAM configuration.

Deliverables for the plan:
- Per fix: exact state owner, target files, behavioral/copy change, injected failure/race test, and runtime verification.
- Throwing/read-back-verified draft, session, credential, and cleanup contracts with precise partial-success UI.
- One physical Access mutation task/state; stale permit rows visibly disabled or removed.
- Portal reset-preparation state and credential-free attempt/reset harness.
- Timetable immediate header/content consistency plus invalidate/TTL/prefetch tests.
- Current Paper and alternate-Surface light/dark screenshots, final wordmark/small-mark packaging, VoiceOver/Dynamic Type/Reduce Motion checks, Portal cold/warm timings, and app TTI.
- Regression checklist for every Keep item and proof that the score reaches at least 22/30 with no load-bearing honesty/usefulness/understandability failure.

Anti-patterns to guard against:
- Treating source presence as runtime proof.
- Hiding storage or cleanup failure behind generic success/empty copy.
- Allowing a second physical Access mutation while one outcome is pending.
- Showing one date header with another date’s content, even briefly.
- Rebuilding working architecture or semantic palettes instead of closing bounded gaps.
- Polishing the placeholder brand before runtime and persistence acceptance pass.
```
