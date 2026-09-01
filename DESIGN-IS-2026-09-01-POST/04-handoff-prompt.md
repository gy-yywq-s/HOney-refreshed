```text
/make-plan Refine the redesigned HOney iPhone application based on a Dieter Rams audit (total 23/30).

Verdict paragraph (quoted from 03-verdict.md):
> REFINE — At 23/30 with no zero-scored principle, the redesigned iOS foundation is coherent and task-correct; the remaining work is bounded brand replacement and authenticated on-device validation, not another structural redesign.

Keep (already strong, do NOT touch in this pass):
- Principle #2 (useful) scored 3 — Evidence: lesson-first Home, target-bound sharing, reused cross-tab shell, and verified-door Access in `ios/HOney/Features/Home/HomeView.swift:102-295`, `ExperiencesView.swift:27-55`, and `AccessView.swift:72-351`. Regression check: re-run the targeted composer flow, cross-tab callbacks, permit load gate, and actual-door confirmation tests.
- Principle #6 (honest) scored 3 — Evidence: failures remain failures, partial Home states do not become empty, initial sync retry is real, and delete/disconnect/credential scopes are explicit in `ios/HOney/App/AppModel.swift:90-185` and `SettingsView.swift:47-199`. Regression check: grep for `try?` in user-visible mutations and test every failure path before keeping success copy.
- Principle #9 (environmentally friendly) scored 3 — Evidence: no idle animation/attention load, adaptive appearance, gated motion, and no third-party runtime packages in §E5. Regression check: confirm no forced color scheme, autoplay, badge, notification, or ungated animation is introduced.

Fix in priority order (top moves from the audit, verbatim):
1. Principles #3 and #7 — Aesthetic and long-lasting: Replace `BrandWordmarkPlaceholder` with the user’s final production wordmark and independent small mark, including proper asset scales, monochrome behavior, small-size validation, and light/dark contrast. Evidence: §E1; `ios/HOney/DesignSystem/AppComponents.swift:217-229`.
2. Principle #8 — Thorough: Exercise every authenticated surface on an iPhone with VoiceOver, accessibility Dynamic Type, Reduce Motion, light/dark appearance, loading/empty/error/success data, and short overlapping timeline lessons. Evidence: §E4.
3. Principles #3 and #5 — Aesthetic and unobtrusive: Review signed-in screenshots as one sequence, especially the Home atmosphere, timetable density, Access dock, and composer Form, then remove only confirmed visual noise rather than introducing a new style direction. Evidence: §E1–§E2.
4. Principle #9 — Environmentally friendly: Produce a Release archive/App Store thinning report and launch signposts; inspect the large `Assets.car` and remove obsolete asset weight after the final brand lands. Evidence: §E5.

Out of scope for this refine pass: another information-architecture redesign, backend/domain changes, Web restyling, external school-portal probing, deployment, and inventing the final brand while the user is producing it.

Deliverables for the plan:
- Per-fix target files, exact change, and verification step.
- Final wordmark/mark asset swap checklist with no Login layout rewrite.
- Authenticated device screenshot matrix covering Home, Experiences, composer, Timetable, Access, Settings, sheets, and dialogs in light/dark and accessibility text.
- VoiceOver/focus/44-point/Reduce Motion regression checklist.
- Release archive, thinning, launch-signpost, and asset-weight report.
- Regression checks for all three Keep principles.

Anti-patterns to guard against:
- Adding a new visual system on top of the redesigned one.
- Reworking lesson-first Home or verified-door Access while refining brand assets.
- Treating the temporary wordmark as final.
- Using source inference as a substitute for authenticated device validation.
- Letting asset optimization remove the privacy, state, or physical-action clarity already achieved.
```
