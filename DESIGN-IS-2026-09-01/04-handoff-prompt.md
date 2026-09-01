```text
/make-plan Redesign the complete HOney iPhone application: Login and import consent, Home, Experiences and composition/history, Timetable and lesson detail, Access, and Settings. Current design failed audit at 8/30 with critical gaps in principles #2 useful, #4 understandable, #6 honest, #8 thorough, and #9 environmentally friendly.

Verdict paragraph (quoted from 03-verdict.md):
> REDESIGN — At 8/30, the draft requires a purpose-led redesign because load-bearing honesty and understandability failures cannot be repaired by restyling the existing legacy composition.

Why redesign and not refine: Load-bearing honesty scored 0, the total is below 20, and prominent task labels, state feedback, credential claims, and physical-gate mapping do not reliably match behavior.

Preserve from current design:
- The four product responsibilities and SwiftUI/service boundary: Home, Experiences, Timetable, and direct-to-school Access. Source: `ios/HOney/Features/Main/MainTabView.swift:11-23` and `README.md:84-129`.
- Explicit physical-gate confirmation before the gate-opening call. Source: `ios/HOney/Features/Access/AccessView.swift:75-93`.
- Separate public Share and device-local Keep private outcomes, including draft preservation and ownership-key behavior. Source: `ios/HOney/Features/Experiences/ComposeExperienceView.swift:120-185,298-385`.
- Native SwiftUI controls and semantic body typography where they already provide platform behavior; a new brand treatment may be custom, but core controls should remain native unless evidence justifies otherwise. Source: `ios/HOney/DesignSystem/AppTheme.swift:73-110`.

Discard:
- The legacy full-screen gradient, translucent-card-everywhere grammar, current serif `HOney` Login title, text-only gradient `HO` icon, and current Login composition. Evidence: `ios/HOney/Features/Auth/LoginView.swift:20-112`, `ios/HOney/DesignSystem/AppComponents.swift:15-43,169-193`. Caused failures on principles #3, #5, #7, and #10.
- Targetless Share entry points and duplicated navigation that promise composition but open guidance or repeat an existing tab. Evidence: `ios/HOney/Features/Home/HomeView.swift:146-175`, `ios/HOney/Features/Experiences/ExperiencesView.swift:27-49`, `ios/HOney/Features/Experiences/ComposeExperienceView.swift:105-205`. Caused failures on principles #2, #4, and #10.
- False-success, error-as-empty, and broad labels that conceal narrower behavior, including unverified Front/Back gate mapping. Evidence: `ios/HOney/Features/Experiences/InteractiveExperienceRow.swift:36-50`, `ios/HOney/Models/PortalModels.swift:179-202`, `ios/HOney/Features/Settings/SettingsView.swift:42-148`. Caused failure on principle #6.

Top 3–5 moves from the audit (verbatim):
1. Principle #6 — Honest: Make every success, error, destructive label, credential statement, permit state, and physical-gate name reflect verified behavior; never swallow a failure into success or empty state. Evidence: §E6; `ios/HOney/Features/Experiences/InteractiveExperienceRow.swift:36-50`, `ios/HOney/Models/PortalModels.swift:179-202`, `ios/HOney/Features/Settings/SettingsView.swift:42-148`.
2. Principles #2 and #4 — Useful and understandable: Rebuild the task architecture around direct next-lesson, targeted Experience creation, and verified Access actions; remove targetless Share entry points and replace jargon with labels that predict the next state. Evidence: §E4–§E5; `ios/HOney/Features/Home/HomeView.swift:146-175`, `ios/HOney/Features/Experiences/ComposeExperienceView.swift:105-205`, `ios/HOney/Features/Access/AccessView.swift:256-337`.
3. Principles #3, #5, and #10 — Aesthetic, unobtrusive, and minimal: Replace the current Login and large-area color grammar with a new hierarchy in which token role, area, depth, and content relationship are designed separately; a Home gradient may return only as a restrained, dimensional composition verified in screenshots. Remove the serif title and text-only `HO` mark, and include ImageGen exploration for a new typographic brand/mark. Evidence: §E1–§E3 and the user-updated scope; `ios/HOney/Features/Auth/LoginView.swift:20-112`, `ios/HOney/DesignSystem/AppTheme.swift:11-110`.
4. Principles #4 and #8 — Understandable and thorough: Establish one accessible state system with visible focus, truthful loading/error/empty/success separation, 44-point targets, contextual accessibility labels, Dynamic Type layouts, and Reduce Motion coverage. Evidence: §E5 and §E7; `ios/HOney/DesignSystem/AppComponents.swift:57-140,227-236`, `ios/HOney/Features/Timetable/TimetableView.swift:521-698`.
5. Principle #9 — Environmentally friendly: Honor system appearance, retain the zero-idle-animation and no-notification baseline, and validate a Release footprint plus startup request/energy budget rather than relying on Debug size. Evidence: §E8; `ios/HOney/App/HOneyApp.swift:13-18`, `ios/HOney/App/AppConfig.swift:14-17`.

Redesign principles in priority order:
1. Principle #6 — Honest — every visible state and label must be backed by verified behavior, especially credentials, deletion/disconnect, reports/reactions, permits, and physical gates.
2. Principles #2 and #4 — Useful and understandable — a student must reach the next lesson, create a targeted Experience, and perform a verified Access action without a dead end, hidden target requirement, or unexplained implementation term.
3. Principles #3, #5, and #10 — Aesthetic, unobtrusive, and minimal — color area must be intentional; content is the figure and color/chrome the ground; large gradients or opaque fills require composition-level justification and screenshot approval.
4. Principle #8 — Thorough — all states, accessibility modes, target sizes, and Dynamic Type layouts must be designed and tested, not inherited accidentally.
5. Principle #9 — Environmentally friendly — respect system appearance and motion preferences while preserving the low-attention, no-idle-animation baseline.

Visual constraints from the user:
- Treat the current UI and brand as a draft; there is no requirement to preserve existing brand treatment.
- The current large gradients and large opaque color blocks must be replaced. A redesigned Home gradient is allowed only if its direction, depth, area, layering, contrast, and relationship to content are deliberately composed and visually reviewed.
- Do not preserve the serif Login title, text-only `HO` icon, or current Login layout.
- Include a bounded ImageGen exploration for a new typographic brand/mark, then translate the selected result into an appropriate production asset; do not paste a raster wordmark into every UI surface.
- Reusing the same token does not make two uses equivalent. Specify semantic role, area, background, contrast, and hierarchy for every color application.

Deliverables for the plan:
- New information architecture, not derived mechanically from the old screen stack.
- New primary flows for Login/import, next lesson, targeted Experience creation, browsing/history, and verified Access, compared side-by-side with current behavior.
- Low-fidelity labeled wireframes followed by a token/area specification and high-fidelity SwiftUI implementation sequence.
- Login brand exploration brief for ImageGen, selection criteria, and production-asset handoff.
- States checklist: empty, loading, error, success, focus, disabled, offline, permission unavailable, and destructive confirmation.
- Accessibility checklist: VoiceOver names/order, Dynamic Type through accessibility sizes, 44-point targets, Reduce Motion, contrast, and system appearance.
- Migration path that preserves user data, sessions, local notes/drafts, and ownership keys while replacing the presentation layer.
- Cutover criteria: no false-success path, no unverified gate label, no targetless Share dead end, all required screenshots approved on representative iPhone sizes, and signed-device Debug build plus unit/UI tests passing.

Anti-patterns to guard against:
- Porting the old structure under new styling.
- Keeping old and new visual systems behind a flag indefinitely.
- Treating gradients, glass, opacity, or accent tokens as automatically tasteful because they are tokens.
- Using a trendy brand image without small-size, monochrome, contrast, and accessibility verification.
- Preserving broad or comforting copy when the underlying behavior is narrower.
```
