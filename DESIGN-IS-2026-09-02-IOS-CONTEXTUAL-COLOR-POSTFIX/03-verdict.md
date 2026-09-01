# Post-fix verdict

**REFINE — 24/30, with no principle at 0: the final verified post-fix closes the requested label, retry, date-control, temporary-session, stale-notice, heading and regression defects, while signed-in visual proof and physical-device accessibility/runtime evidence still prevent final closure.**

## Highest-leverage moves

1. **P1 · Principles #3/#8 — Aesthetic and thorough:** Capture fresh signed-in screenshots for Home, Timetable, Experiences, History, Access and Settings across all six palettes/light-dark; evaluate hero/surface/marker/spacing only as whole-screen composition and never substitute Login. Evidence: `ios/HOney/DesignSystem/AppTheme.swift:37-162`; `ios/HOney/Features/Home/HomeView.swift:143-328`; `01-evidence.md#evidence-boundaries`.
2. **P1 · Principles #4/#8 — Understandable and thorough:** Verify VoiceOver Rotor/Switch order and accessibility-size layout on device; change `Current week` to `Shown week`, stress the fixed 44pt date labels/header/Access cards at AX sizes, replace the in-app Portal's external-arrow affordance, and decide any additional card-title headings from actual Rotor usefulness rather than font alone. Evidence: `ios/HOney/Features/Home/HomeView.swift:304-327`; `ios/HOney/Features/Timetable/TimetableView.swift:71-76,274-311,360-376`; `ios/HOney/Features/Access/AccessView.swift:537-570,697-742`; requested heading closure at `HomeView.swift:218-223`, `ExperiencesView.swift:491-505`, and `AccessView.swift:149-217,294-300,735-746`.
3. **P2 · Principles #8/#9 — Thorough and resource-conscious:** Measure signed-in cold/warm Home, School Portal TTI, scrolling smoothness and physical Access without inferring device behavior from the independently verified 106/106 simulator suite or signed arm64 product. Evidence: `ios/HOney/Features/Home/PortalWebView.swift:37-49,129-170`; `01-evidence.md#state-accessibility-and-runtime-evidence`.
4. **P2 · Principles #9/#10 — Resource-conscious and minimal:** Add cursor append/scroll restoration and delayed stale-response tests for History/Experiences without increasing repeat requests; remove the unused Access `context` parameter during that cleanup. Evidence: `ios/HOney/App/AppServices.swift:379-383`; `ios/HOney/Features/History/HistoryViewModel.swift:67-92`; `ios/HOney/Features/Experiences/ExperiencesViewModel.swift:69-89`; `ios/HOney/Features/Access/AccessViewModel.swift:109-131,155-181`.

## Priority interpretation

- **P0:** none. Auth/session recovery and its successful-retry notice clearing have automated regression coverage; the final suite is 106/106.
- **P1:** moves 1–2; they block observed aesthetic closure and inclusive device use.
- **P2:** moves 3–4; they close physical runtime evidence and remaining performance/cleanup debt.
