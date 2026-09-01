```text
/make-plan Refine the HOney native iOS post-fix experience based on a Dieter Rams audit (total 24/30).

Verdict paragraph (quoted from 03-verdict.md):
> REFINE — 24/30, with no principle at 0: the final verified post-fix closes the requested label, retry, date-control, temporary-session, stale-notice, heading and regression defects, while signed-in visual proof and physical-device accessibility/runtime evidence still prevent final closure.

Keep (already strong, do NOT touch in this pass):
- Principle #2 (useful) scored 3 — Evidence: Home remains lesson-first at ios/HOney/Features/Home/HomeView.swift:26-53; Today/date/card controls are direct at ios/HOney/Features/Timetable/TimetableView.swift:110-158,274-485; Posts & notes, Choose gate and Update school sign-in match their destinations. Regression check: confirm each named control still performs its immediate named behavior, all options remain directly listable, and teacher/time/room lesson cards remain intact.
- Principle #6 (honest) scored 3 — Evidence: temporary refresh failure preserves session at ios/HOney/Services/HOneyAPI.swift:288-304; successful bootstrap clears startupNotice at ios/HOney/App/AppModel.swift:63-66; lifecycle coverage at ios/HOneyTests/AppModelLifecycleTests.swift:44-100; expired lesson and physical uncertainty remain explicit. Regression check: exercise direct 503, refresh 401/403, refresh 503, successful recovery and mutation-unknown states without collapsing any into false sign-out/success.
- Principle #7 (long-lasting) scored 3 — Evidence: semantic type/native controls/natural case/flat canvas at ios/HOney/DesignSystem/AppTheme.swift:242-290 and ios/HOney/DesignSystem/AppComponents.swift:224-228. Regression check: grep for uppercased/smallCaps/gradient/idle animation and confirm none return.
- Principle #9 (environmentally friendly) scored 3 — Evidence: bounded/coalesced caches at ios/HOney/App/AppServices.swift:73-215,333-450 and ios/HOney/Services/TimetableRepository.swift:19-121; motion baseline at ios/HOney/App/AppConfig.swift:14-18. Regression check: rerun cache/coalescing/stale tests and confirm fresh revisits remain request-free, dark mode adaptive and Reduce Motion respected.

Fix in priority order (top moves from the audit, verbatim):
1. P1 · Principles #3/#8 — Aesthetic and thorough: Capture fresh signed-in screenshots for Home, Timetable, Experiences, History, Access and Settings across all six palettes/light-dark; evaluate hero/surface/marker/spacing only as whole-screen composition and never substitute Login. Evidence: `ios/HOney/DesignSystem/AppTheme.swift:37-162`; `ios/HOney/Features/Home/HomeView.swift:143-328`; audit evidence boundary: no fresh signed-in iOS screenshot exists.
2. P1 · Principles #4/#8 — Understandable and thorough: Verify VoiceOver Rotor/Switch order and accessibility-size layout on device; change `Current week` to `Shown week`, stress the fixed 44pt date labels/header/Access cards at AX sizes, replace the in-app Portal's external-arrow affordance, and decide any additional card-title headings from actual Rotor usefulness rather than font alone. Evidence: `ios/HOney/Features/Home/HomeView.swift:304-327`; `ios/HOney/Features/Timetable/TimetableView.swift:71-76,274-311,360-376`; `ios/HOney/Features/Access/AccessView.swift:537-570,697-742`; requested heading closure at `HomeView.swift:218-223`, `ExperiencesView.swift:491-505`, and `AccessView.swift:149-217,294-300,735-746`.
3. P2 · Principles #8/#9 — Thorough and resource-conscious: Measure signed-in cold/warm Home, School Portal TTI, scrolling smoothness and physical Access without inferring device behavior from the independently verified 106/106 simulator suite or signed arm64 product. Evidence: `ios/HOney/Features/Home/PortalWebView.swift:37-49,129-170`; audit runtime evidence has no defensible millisecond TTI.
4. P2 · Principles #9/#10 — Resource-conscious and minimal: Add cursor append/scroll restoration and delayed stale-response tests for History/Experiences without increasing repeat requests; remove the unused Access `context` parameter during that cleanup. Evidence: `ios/HOney/App/AppServices.swift:379-383`; `ios/HOney/Features/History/HistoryViewModel.swift:67-92`; `ios/HOney/Features/Experiences/ExperiencesViewModel.swift:69-89`; `ios/HOney/Features/Access/AccessViewModel.swift:109-131,155-181`.

Out of scope for this refine pass: redesigning Login/wordmark; replacing the six palette experiment with one forced palette; reintroducing Home gradients, small uppercase labels, whole-screen pull-to-refresh or broad Timetable swipe; copying web-ionic; changing backend privacy/domain behavior without separate evidence.

Deliverables for the plan:
- Per-fix: target files, exact change, verification step
- Token/spec changes consolidated in one place
- Regression checklist for every Keep item above

Anti-patterns to guard against (specific to REFINE):
- Adding new abstractions where a direct change suffices
- Restyling areas that already scored 3
- Scope creep into structural redesign
- Letting fixes mutate principles outside the priority list
```
