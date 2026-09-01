```text
/make-plan Refine the HOney native iOS signed-in experience based on a Dieter Rams audit (total 22/30).

Verdict paragraph (quoted from 03-verdict.md):
> REFINE — 22/30, with no principle at 0: the current iOS bones are useful, restrained and honest enough to preserve, but label-to-behavior clarity, signed-in whole-screen visual validation and accessibility/runtime evidence still need a focused refinement pass.

Keep (already strong, do NOT touch in this pass):
- Principle #2 (useful) scored 3 — Evidence: Home exposes current/next lesson before secondary content at ios/HOney/Features/Home/HomeView.swift:27-53,142-235; Timetable uses explicit day controls and one card per lesson at ios/HOney/Features/Timetable/TimetableView.swift:68-155,372-467. Regression check: confirm Home still gives the school-day answer before feed/actions, every selectable option remains directly listable, every Timetable lesson keeps subject/teacher-or-fallback/time/room, and no broad day-swipe returns.
- Principle #7 (long-lasting) scored 3 — Evidence: semantic system type, native controls, natural case and tonal surfaces at ios/HOney/DesignSystem/AppTheme.swift:242-290 and ios/HOney/DesignSystem/AppComponents.swift:223-227. Regression check: grep for uppercased/smallCaps/text-transform equivalents, gradients and idle animation; confirm none are introduced.
- Principle #9 (environmentally friendly) scored 3 — Evidence: bounded/coalesced caches at ios/HOney/App/AppServices.swift:73-215,333-450 and ios/HOney/Services/TimetableRepository.swift:19-121; motion baseline at ios/HOney/App/AppConfig.swift:14-18. Regression check: rerun cache/coalescing/stale tests, confirm fresh revisits remain request-free, dark mode remains adaptive and Reduce Motion remains respected.

Fix in priority order (top 3–5 moves from the audit, verbatim):
1. P1 · Principle #4 — Understandable: Make every visible label describe the immediate next behavior: show `Today` on the Timetable shortcut (or make the range open a real chooser), rename `Yours` to `Your posts & notes`, rename permit-row `Open` to `Choose gate`, and rename Settings reconnect to `Update school sign-in`. Evidence: `ios/HOney/Features/Timetable/TimetableView.swift:114-116,347-367`; `ios/HOney/Features/Experiences/ExperiencesView.swift:41-42`; `ios/HOney/Features/Access/AccessView.swift:482-496`; `ios/HOney/Features/Settings/SettingsView.swift:197,318`.
2. P1 · Principles #3/#8 — Aesthetic and thorough: Capture fresh signed-in iOS screenshots for Home, Timetable, Experiences, History, Access and Settings in all six palettes/light-dark, then tune hero/surface/marker proportions only from whole-screen evidence; never infer final beauty from tokens or use Login as Home evidence. Evidence: `ios/HOney/DesignSystem/AppTheme.swift:37-162`; `ios/HOney/Features/Home/HomeView.swift:142-319`; audit known gap: no fresh signed-in iOS screenshot exists.
3. P1 · Principle #8 — Thorough: Add heading traits and verify VoiceOver order, Switch Control, accessibility Dynamic Type, Reduce Motion and 44pt targets on device; specifically stress Home's scaled title, Timetable's fixed header/seven-day strip and Access's one-line cards. Evidence: `ios/HOney/DesignSystem/AppComponents.swift:65-73`; `ios/HOney/Features/Home/HomeView.swift:178-183`; `ios/HOney/Features/Timetable/TimetableView.swift:68-75,273-367`; `ios/HOney/Features/Access/AccessView.swift:533-573,673-731`.
4. P2 · Principle #6 — Honest: Replace the permit-rule overclaim and implementation jargon, then live-verify the strongest authorlessness/report statements before treating them as closed: `End time must be after the start time`, plain recovery-key language, `One post is only part of the picture`, and `Apply with this draft`. Evidence: `ios/HOney/Features/Access/AccessView.swift:123-129,643,659`; `ios/HOney/Features/Experiences/ExperiencesView.swift:373`; `ios/HOney/Features/Experiences/ComposeExperienceView.swift:145-215`; `ios/HOney/Features/Experiences/ReportSheet.swift:29,60-62`.
5. P2 · Principles #8/#9 — Thorough and resource-conscious: Measure signed-in cold/warm Home and School Portal TTI plus physical Access, add delayed stale-response tests for Home/History/Experiences, and plan feed cursor append/scroll restoration without increasing repeat requests. Evidence: `ios/HOney/Features/Home/PortalWebView.swift:37-49,129-170`; `ios/HOney/Features/Home/HomeViewModel.swift:31-72`; `ios/HOney/Features/History/HistoryViewModel.swift:67-92`; `ios/HOney/Features/Experiences/ExperiencesViewModel.swift:69-89`; `ios/HOney/App/AppServices.swift:381-383`.

Out of scope for this refine pass: redesigning Login/wordmark again; replacing the six palette experiment with one forced palette; reintroducing a Home gradient, small uppercase labels, whole-screen pull-to-refresh or broad Timetable day-swipe; copying web-ionic; changing verified backend/domain privacy rules without separate evidence.

Deliverables for the plan:
- Per-fix: target files, exact change, verification step
- Token/spec changes consolidated in one place
- Regression checklist for every Keep item above

Anti-patterns to guard against (specific to REFINE):
- Adding new abstractions where a direct change suffices
- Restyling areas that already scored 3
- Scope creep into structural redesign (if structure must change, this should be REDESIGN, not REFINE)
- Letting fixes mutate principles outside the priority list
```
