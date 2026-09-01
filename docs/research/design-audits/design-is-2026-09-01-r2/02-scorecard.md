# 02 — Scorecard (r2; orchestrator-scored per skill anchors; tie-breaker: lower; no credit for fixes that did not verify live)

1. Good design is innovative — Score: 2/3 (r1 2, Δ0)
   Evidence: [C1] identity-free publish, no-author-column storage, browser-held ownership keys, exposure-verified provenance and no-free-text reports re-verified with zero drift; UI patterns (feed/tabs/compose/chips) remain conventional.
   Justification: The trust architecture still "refreshes an existing pattern with a clear improvement"; nothing this round produced evidence of a pattern absent from 5+ peer products, so the tie-breaker keeps 2.

2. Good design makes a product useful — Score: 2/3 (r1 2, Δ0)
   Evidence: [C1] browse→Explore and "Tomorrow · 01:00" verified; [S1][W8] feed header Share verified, but feed→typing is still 4 screens / 3 taps with no autofocus; [C4] "How privacy works" still lands at Settings top with the section off-screen; [S2.3] delisted rooms render a Share CTA that leads nowhere.
   Justification: Every primary task completes without a wrong-screen detour now (rules out 1), but adjacent surfaces still add steps and one CTA dead-ends, so not "fewest possible steps; no decoy actions" (rules out 3).

3. Good design is aesthetic — Score: 1/3 (r1 1, Δ0)
   Evidence: [V1][V3] type ramp real and fully honored in render (9 sizes, floor 12 px); [V2][V4] spacing ladder exists but 39 `--sp` usages vs 159 raw-px declarations, 116 off-ladder literals, rendered rhythm still dominated by 2/10/6/14/9/18 px, Explore 50 px gap from 30+18 margins; [V6] `.nextlesson__state` hard-codes `#15181a` → 1.54:1 on a genuine dark boot, the focal chip nearly invisible.
   Justification: Type and color now obey one system, but spacing does not in what actually renders and the night focal card carries one jarring violation — that is anchor 1's "3–5 inconsistencies OR one jarring violation", well past anchor 2's "≤2 minor"; a visible system exists, so not 0.

4. Good design makes a product understandable — Score: 1/3 (r1 1, Δ0)
   Evidence: [C1] four "revoke" strings survive, incl. a button "Revoke…" (`MinePage.tsx:258`) that opens "Remove this post?"; [V7] raw key `teacher:t_23348879d1b4` shown as the compose target title during lookup; [S1] history chips look like filters but navigate away; [C1] "Browse teachers, places & food" / "Filter by name…" vs "Find someone or something"; [C4] privacy link lands off-target; [A5] invisible date-picker affordance unchanged.
   Justification: Jargon is present and 2–3+ controls remain unclear on the share/Mine paths (anchor 1); every primary action is still identifiable without help, so not 0.

5. Good design is unobtrusive — Score: 2/3 (r1 2, Δ0)
   Evidence: [V5][A4] overlays now own the full viewport and the nav is not hit-testable under a modal; [W5] 0 interrupts on load; [W4] one idle pulse on Timetable; [S1] the 460 ms settle still replays on every route change; [S1] a primary-styled Share button now sits in the feed header chrome.
   Justification: Chrome is quiet and functional (anchor 2); per-route entrance motion, an infinite now-dot pulse, and a primary button in the stream header keep the ground from fully receding (bars 3); nothing decorative competes (bars 1).

6. Good design is honest — Score: 2/3 (r1 2, Δ0)
   Evidence: [C1] all privacy claims re-verified 1:1 against unchanged code; [C2] new HOney ID and Remove copy map to behavior; [C3] one minor inflation ("actually") remains, 0 dark patterns; [C4] 3 label→behavior mismatches incl. the new Revoke→Remove disagreement; [S2.1] one course shows two names on one screen.
   Justification: Exactly one minor inflation and no dark pattern matches anchor 2; labels do not all map 1:1 (Revoke/Remove, privacy link, chip/row names), which bars 3.

7. Good design is long-lasting — Score: 2/3 (r1 2, Δ0)
   Evidence: [V12] cool palette, one accent, single humanist face, no gradients, no fad type; [S1][W4] staggered per-route entrance choreography and frosted translucent surfaces unchanged.
   Justification: No hard dated markers, but the entrance-stagger signature remains one plausible trend marker — uncertain between 2 and 3, tie-breaker lands 2.

8. Good design is thorough down to the last detail — Score: 1/3 (r1 1, Δ0)
   Evidence: Fixed and verified: [V5] containment, [A2] focus return, [W6] PTR, [A1] enabled-text AA, [A3] tabs/arrows/··· targets. Remaining: [V7] compose loading rough (raw key leaked); [V11] feed error with no Retry; [V6] night focal chip 1.54:1; [V8] 320×568 footnote behind the fixed nav; [S2.3] delisted rooms reachable with a Share CTA; [A3] chips 40 px, context link 65×18, checkbox 18×18; [A1] disabled plain 3.38 / react-btn 2.92 on stone; [S1] shared.tsx dead imports and the Keep-private banner change that the commit message claims but the diff does not contain.
   Justification: Two states are rough (loading on compose, error on feed) plus a measured detail cluster — past anchor 2's "1 state missing or rough"; the state framework exists and most r1 defects verified fixed, so not 0.

9. Good design is environmentally friendly — Score: 2/3 (r1 2, Δ0)
   Evidence: [W1] 84 KB br app JS with Dash split out (96 KB with the Cloudflare beacon); [V9][W9] prefers-color-scheme honored pre-paint; [W4] prefers-reduced-motion → 0 animations; but [W4] Timetable still runs one infinite 2.4 s pulse at idle.
   Justification: Three of anchor 3's four requirements now verify (<100 KB, dark mode, reduced-motion); the idle pulse alone fails "no idle animation", so anchor 2.

10. Good design is as little design as possible — Score: 1/3 (r1 1, Δ0)
    Evidence: [S1] Explore no longer lists rows twice, but 9 of 10 chip names repeat as rows on the same screen; [S1] the composer's banner Keep-private button was never removed (4 buttons still defined, 2 co-visible); [S2.4] unconditional header Share means an empty feed shows two compose CTAs; [S5] 13 repeated-affordance families unchanged; [S1] compose entries grew 8→9, still none in primary nav.
    Justification: Three clearly removable duplications remain on primary surfaces (anchor 1); the pages are not dominated by decoration, so not 0.

**Total: 16/30** (r1 16/30, Δ0)

Tie-break register (principles settled downward by the lower-tie-breaker rule): #1, #3, #5, #7, #8, #10. Principles scored with no tie: #2, #4, #6, #9.
