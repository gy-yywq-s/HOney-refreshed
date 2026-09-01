```text
/make-plan Refine HOney Ionic Web/PWA based on a Dieter Rams audit (total 20/30).

Verdict paragraph (quoted from 03-verdict.md):
> REFINE: At 20/30 with no zero-scored principle, the Ionic Web/PWA keeps its strong task structure, honest product semantics, and quiet content-first shell, but must fix the broken-looking Feed scope control, mobile edge-detail failures, and heavyweight continuously animated shared entry before the next evidence round.

Keep (already strong, do NOT touch in this pass):
- Principle #2 (useful) scored 3 — Evidence: `apps/web-ionic/src/pages/HomePage.tsx:52-150`, `apps/web-ionic/src/pages/experiences/FeedPage.tsx:51-155`, and `apps/web-ionic/src/pages/experiences/ExplorePage.tsx:31-167`. Regression check: re-run the signed-in screenshot matrix and confirm Home still exposes Now/Next immediately, Feed remains the default Experiences surface, direct Timetable/Share paths remain, and Explore still renders every finite entity without requiring search.
- Principle #5 (unobtrusive) scored 3 — Evidence: `apps/web-ionic/src/features/experiences/ExperiencePost.tsx:139-245`, `apps/web-ionic/src/pages/HomePage.tsx:50,111-130`, and `apps/web-ionic/src/pages/experiences/FeedPage.tsx:102-105`. Regression check: inspect screenshots/CSS to confirm raw student words remain dominant, Home still shows at most two voices, new posts never force-scroll, and no promo/badge/tutorial chrome is introduced.
- Principle #7 (long-lasting) scored 3 — Evidence: `apps/web-ionic/src/styles/tokens.css:13-70` and `docs/design/web-lab.md:9-30`. Regression check: grep and render to confirm one neutral humanist type family, narrow cool palette, hairlines, no ambient decorative layer, and no new trend font/gradient/glass effect.
- Principle #10 (as little design as possible) scored 3 — Evidence: `apps/web-ionic/src/components/navTabs.tsx:17-28` and `apps/web-ionic/src/pages/HomePage.tsx:50-150`. Regression check: count persistent core controls at mobile/desktop breakpoints and confirm no new destination, dashboard layer, duplicate affordance, or decorative element was added.

Fix in priority order (top 3–5 moves from the audit, verbatim):
1. Principle #4 — Understandable: Restore both Feed scope labels and an unmistakable selected state at every audited breakpoint, then verify the rendered DOM/accessibility tree instead of accepting source presence alone. Evidence: `apps/web-ionic/src/pages/experiences/FeedPage.tsx:84-99` versus `docs/web/evidence/ionic-fidelity/ionic/mobile-390x844-experiences.png` and the corresponding compact/desktop screenshots.
2. Principles #3 and #8 — Aesthetic + Thorough: Repair the mobile composition contract: keep Compose privacy/actions and Timetable terminal content clear of the tab bar, make the editor use its available frame, raise Feed tools and scope controls to the 44px touch floor, move Skip to content before rail controls, and make Mist tertiary text pass 4.5:1. Evidence: `docs/web/evidence/ionic-fidelity/ionic/mobile-390x844-compose.png`, `mobile-390x844-timetable.png`, `apps/web-ionic/src/styles/ionic.css:137-200,324-403`, `apps/web-ionic/src/components/AppLayout.tsx:76-168`, `apps/web-ionic/src/styles/tokens.css:103-117`.
3. Principle #9 — Environmentally friendly: Split the public Login doorway from the authenticated Ionic shell so the cold unauthenticated route does not parse the 1,152,054-byte shared entry, and remove the Home/Timetable infinite idle pulses while preserving reduced-motion behavior and state clarity. Evidence: `apps/web-ionic/src/App.tsx:1-32`, `apps/web-ionic/src/components/AppLayout.tsx:1-38`, `apps/web-ionic/src/styles/features.css:78-92,332-355`.
4. Principle #3 — Aesthetic: Rebalance responsive composition without adding decoration: eliminate the purposeless Compose gap, keep desktop Home's current/remaining-time meaning while reducing the empty hero/right-canvas imbalance, and preserve the existing one-font/cool-palette/feed-hairline system. Evidence: `docs/web/evidence/ionic-fidelity/ionic/mobile-390x844-compose.png`, `desktop-1440x900-home.png`, `apps/web-ionic/src/styles/ionic.css:122-127`, `apps/web-ionic/src/styles/tokens.css:13-70`.
5. Principle #6 — Honest: Complete a deterministic user-facing string inventory and label→behavior regression check for all Ionic routes (including Dash) so R2 can prove, rather than infer, the current high-risk copy integrity. Evidence: `DESIGN-IS-2026-09-01-R1/01-evidence.md#coverage-and-inventory-gap`.

Out of scope for this refine pass: the preserved `apps/web`; iOS; backend; shared API contracts; database/migrations; product/privacy/reaction/moderation semantics; external school portal behavior or probing; brand replacement; deployment topology; adding new features, destinations, or visual convergence with iOS.

Deliverables for the plan:
- Per-fix: target files, exact change, verification step
- Token/spec changes consolidated in one place
- Regression checklist for every "Keep" item above

Phase 0 documentation discovery must use the repository's actual Ionic React 9, React Router 6, Vite 5, and current component/CSS patterns; cite exact local docs/types/source signatures before proposing APIs. Each implementation phase must be self-contained with target files, existing pattern references, verification commands, and anti-pattern guards. Final verification must include scoped lint/typecheck/tests/build, a fresh deterministic signed-in screenshot matrix at 375×667, 390×844, and 1440×900, live unauthenticated Login weight/focus checks, and an entirely new Design-Is R2 evidence pass. R2 must score independently; do not tune scoring to the ≥24 target.

Anti-patterns to guard against (specific to REFINE):
- Adding new abstractions where a direct change suffices
- Restyling areas that already scored 3
- Scope creep into structural redesign (if structure must change, this should be REDESIGN, not REFINE)
- Letting fixes mutate principles outside the priority list
- Treating source presence as proof when rendered screenshots/DOM contradict it
- Fixing bundle weight by removing core product behavior or weakening the existing isolated-PWA architecture
```
