# Design Is — Round 2 /make-plan handoff

````
/make-plan Refine HOney Ionic Web/PWA based on a Dieter Rams audit (total 23/30).

Verdict paragraph (quoted from 03-verdict.md):
> REFINE — At 23/30 with no zero-scored principle, the deployed Ionic Web/PWA reaches Gary's current acceptance threshold: its direct task flow, product truth, and durable visual grammar are strong, while a narrow last-detail backlog remains in Explore alignment, timetable/control accessibility, and one duplicated post affordance.

Keep (already strong, do NOT touch in this pass):
- Principle #2 (useful) scored 3 — Evidence: `apps/web-ionic/src/pages/HomePage.tsx:33,67,71-82`. Regression check: at 375×667 and 390×844, confirm Home still shows Now/Next and reaches Timetable, Experiences, and Compose in one activation.
- Principle #6 (honest) scored 3 — Evidence: `apps/web-ionic/src/pages/ComposePage.tsx:75-89,124-153,200-207` and `apps/web-ionic/src/pages/PrivacyPage.tsx:3-4`. Regression check: rerun draft-save failure, ownership-key failure, cooldown resume, and fixture-disclosure browser tests; diff all publication/privacy claims against behavior.
- Principle #7 (long-lasting) scored 3 — Evidence: `apps/web-ionic/src/theme/variables.css:1-65` and `apps/web-ionic/src/theme/app.css:190-195,235-241`. Regression check: grep/render for no gradients, glass, large-radius card wall, ambient motion, or replacement of the approved wordmark.

Fix in priority order (top 3–5 moves from the audit, verbatim):
1. Principles #8/#3 — Thorough/aesthetic: Constrain the actual rendered Explore `ion-searchbar` host to the same 710px spine as its segment/results, and make the browser assertion target the searchbar rather than the first generic `.explore-control`. Evidence: `01-evidence.md#visual-evidence`.
2. Principle #8 — Thorough: Remove whole-row opacity from past timetable entries; apply semantic tokens per child so every muted/faint line remains ≥4.5:1 in both schemes, and raise segment plus fixture-only controls to 44px. Evidence: `01-evidence.md#accessibility-and-state-evidence`.
3. Principles #4/#10 — Understandable/minimal: Keep the visible per-post Add action and remove its duplicate from More, leaving More for reporting/cancel only. Evidence: `01-evidence.md#structural-and-flow-evidence`.
4. Principle #8 — Thorough: Add a bounded keyboard regression for overlay initial focus, Tab trap, Escape dismissal, trigger-focus restoration, and a visible keyboard alternative to refresh. Evidence: `01-evidence.md#accessibility-and-state-evidence`.
5. Principle #9 — Environmental: Audit the Workbox precache manifest and Ionic bootstrap; retain offline/update guarantees while excluding nonessential first-install assets and reducing the 288,943-byte encoded main bundle. Evidence: `01-evidence.md#performance-and-environmental-evidence`.

Out of scope for this refine pass: backend/API-contract changes; iOS; external school-portal probing; real-user publication/report/destructive operations; replacement of the approved wordmark or established paper/ink/blue grammar.

Deliverables for the plan:
- Per-fix: target files, exact change, verification step
- Token/spec changes consolidated in one place
- Regression checklist for every “Keep” item above

Anti-patterns to guard against (specific to REFINE):
- Adding new abstractions where a direct change suffices
- Restyling areas that already scored 3
- Scope creep into structural redesign (if structure must change, this should be REDESIGN, not REFINE)
- Letting fixes mutate principles outside the priority list
````
