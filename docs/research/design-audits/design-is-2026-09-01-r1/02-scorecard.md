# 02 — Scorecard (orchestrator-scored per skill anchors; tie-breaker: lower)

1. Good design is innovative — Score: 2/3
   Evidence: [C2] identity-free publish verified to the DB schema, browser-held ownership keys, exposure-verified reactions, no-free-text reports, nudge/cooldown lanes — a real advance shipped with restraint; UI patterns themselves (feed/tabs/compose) are conventional.
   Justification: The trust architecture clearly "refreshes an existing pattern with a clear improvement"; whether it is "not seen in 5+ peer products" could not be empirically surveyed in this audit, so the tie-breaker rules out 3.

2. Good design makes a product useful — Score: 2/3
   Evidence: [S5][W3] all three primary tasks complete in 1–3 taps with snapshot-restored returns; but [W6] zero compose entries on a non-empty feed, [C6] "Browse teachers, places & food" lands on the feed, [C1] "In 618 min" with no tomorrow cue.
   Justification: Every primary task completes quickly (rules out 1) but adjacent surfaces add steps and one mislabeled entry sends the sharer to the wrong screen (rules out 3).

3. Good design is aesthetic — Score: 1/3
   Evidence: [V1] no spacing tokens, near-continuous 1–2 px spacing series; [V2] no type tokens, 19 ad-hoc sizes with 14 fractional uses; [V3] 44 color literals, stray hexes outside tokens — against genuinely strong palette/font discipline (one accent, no warm tones, single family [V6]).
   Justification: The rendered result is quiet and coherent, but "spacing/type/color obey a single visible system" is measurably false — well past the ≤2 minor inconsistencies that anchor 2 allows, with no active visual noise that would force 0.

4. Good design makes a product understandable — Score: 1/3
   Evidence: [C6] "Browse teachers, places & food"→feed; "Nothing else is scheduled today." not a today-check; three names for Explore; [C5] "Revoke", "Verified retrospective", "review slot", "cooling-off pass", unexplained "HOney ID"; [S1] invisible date-picker affordance over the date label.
   Justification: 2–3+ controls are unclear and jargon is present on primary paths (anchor 1); primary actions remain identifiable, so not 0.

5. Good design is unobtrusive — Score: 2/3
   Evidence: [V8] short-post chrome occupies ~1.8× the body's area, but font/color hierarchy favors the student's text ~1.6×; [W4] idle screens 0–1 animations; quiet muted chrome; 460 ms settle replays on every route ([S5]).
   Justification: Chrome is visible but quiet and functional rather than decorative (anchor 2); it neither recedes fully (the area ratio and per-route motion bar 3) nor competes as decoration (bars 1).

6. Good design is honest — Score: 2/3
   Evidence: [C2] privacy claims verified 1:1 against client and backend code, report categories map exactly, "anonymity is a design boundary, not magic"; [C4] zero dark patterns; [C3] one minor puff ("actually"), dropped hedge variants.
   Justification: Exactly one minor inflation with no dark patterns matches anchor 2; the label→behavior mismatches in [C6] mean not every label maps 1:1, which bars 3.

7. Good design is long-lasting — Score: 2/3
   Evidence: [V3][V6] cool school-paper palette, one accent, single humanist face, no gradients/fad typography; [S5][W4] staggered per-index entrance choreography and frosted translucent card/backdrop-blur surfaces read as current-decade convention.
   Justification: No hard dated markers (skeuomorph residue, fad gradients), but the entrance-stagger motion signature is one plausible trend marker — uncertain between 2 and 3, so the tie-breaker lands 2.

8. Good design is thorough down to the last detail — Score: 1/3
   Evidence: [V5] compose loading state missing; [V7] measured modal containment bug (nav hit-testable under an open modal, sheet floats mid-screen); [A2] report-dialog focus returns to body; [W6] pull-to-refresh spinner double-adds 650 ms; [V8] compose overflows 144 px at 320×568 (privacy footnote below fold); [A1] seven sub-AA text pairs; [A7] eight sub-44 px targets.
   Justification: One missing state plus a cluster of measured detail defects is well past anchor 2's "1 state missing or rough"; the full state framework exists and works ([V5] elsewhere), so not 0.

9. Good design is environmentally friendly — Score: 2/3
   Evidence: [W1] ~97.5 KB br initial JS; [W4] prefers-reduced-motion fully respected and motion gated; but 1 infinite idle animation on Timetable and [V8] `prefers-color-scheme: dark` ignored (manual Night only); [W1] no code splitting, admin ships to every student.
   Justification: Comfortably under anchor 2's 500 KB with gated motion; the idle pulse and unhonored dark-mode media query each break anchor 3's requirements.

10. Good design is as little design as possible — Score: 1/3
    Evidence: [S3] 13 repeated affordances, incl. Explore rendering the same 10 entities twice on one page, "Keep private" ×4 in one composer, three Home→feed paths on one screen; [S6] duplicate registry rows user-visible.
    Justification: At least three clearly removable duplications sit on primary surfaces (anchor 1); the page is not dominated by decoration, so not 0.

**Total: 16/30**
