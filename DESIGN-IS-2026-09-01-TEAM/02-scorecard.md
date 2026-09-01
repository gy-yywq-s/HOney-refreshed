# HOney iOS team design audit scorecard

1. Good design is innovative — Score: 2/3
   Evidence: Lesson-first Home, target-bound publishing, chronological feed, and exact-door confirmation improve familiar native patterns (§E2).
   Justification: This is more than minor imitation, so not 1; no comparison demonstrates a pattern absent from five or more peers, so not 3.

2. Good design makes a product useful — Score: 2/3
   Evidence: Current/next lesson remains immediate, but first Portal open is user-observed to appear frozen for a long time and rapid Timetable navigation pauses under an uncancelled request pipeline (§E2, §E7).
   Justification: The primary lesson task completes, so not 1; adjacent Portal and Timetable tasks are not promptly usable, so the fewest-steps/no-friction requirement for 3 is not met.

3. Good design is aesthetic — Score: 2/3
   Evidence: Runtime Login and signed-in source use one adaptive semantic system with audited contrast, but the production wordmark/small mark and required persisted multi-Surface palette are unfinished (§E1, §E3).
   Justification: One coherent system rules out 1; the placeholder asset and fixed-only paper surface prevent the complete approved system required for 3.

4. Good design makes a product understandable — Score: 1/3
   Evidence: School Portal provides no visible loading/progress/error/timeout/cancellation state and appears dead on cold open; the icon-only My Posts control and `Share a lesson` wording add further ambiguities (§E2, §E4, §E5, §E7).
   Justification: Two to three representative controls/states are unclear, matching 1; Portal’s entry action is identifiable, so the primary action is not wholly unidentifiable and 0 is not met.

5. Good design is unobtrusive — Score: 2/3
   Evidence: Login is flat and quiet, Home uses only a shallow background atmosphere, and content remains focal, though outlined cards/action groups remain visibly present (§E1, §E3).
   Justification: Decoration does not compete with content, so not 1; chrome is quiet but does not fully disappear behind content, so not 3.

6. Good design is honest — Score: 1/3
   Evidence: Publication can claim its only key was saved after a suppressed Keychain failure; local deletion can claim completion after suppressed clear failures; key reads can become false empty state; and stale Timetable responses can overwrite the currently labeled date (§E4, §E7).
   Justification: Multiple load-bearing claim-to-behavior mismatches rule out 2 or 3; no forced continuity, hidden cost, fake scarcity, confirmshaming, or intentional deceptive flow was found, so the exact 0 anchor is not met.

7. Good design is long-lasting — Score: 2/3
   Evidence: Native system typography/controls, adaptive appearance, restrained color, and flat surfaces are durable; temporary brand assets and the fixed-only surface palette remain incomplete (§E3).
   Justification: The incomplete brand/surface layer prevents 3; the underlying visual language does not contain two or three dated trend markers, so not 1.

8. Good design is thorough down to the last detail — Score: 0/3
   Evidence: Beyond persistence failures, School Portal lacks visible loading, progress, error, timeout, retry, and cancellation states, while Timetable lacks cancellation, cache, coalescing, prefetch, and stale-response protection (§E4, §E5, §E7).
   Justification: Four or more representative states are missing, meeting the exact 0 anchor; the user-observed frozen Portal and paused Timetable show these are shipped interaction gaps rather than test-only omissions.

9. Good design is environmentally friendly — Score: 2/3
   Evidence: Dark mode, Reduce Motion, zero decorative idle animation, and native initial JS remain strong, but Portal cold recovery can perform two navigations plus sequential auth without cancellation and rapid Timetable input emits redundant requests (§E6, §E7).
   Justification: Motion and initial native weight remain gated, ruling out the always-on-motion 1 anchor; observed attention/resource friction and uncancelled work prevent the conservation required for 3.

10. Good design is as little design as possible — Score: 2/3
    Evidence: Targetless sharing and nested duplicate tabs are removed; two permanent-tab destination affordances are still duplicated on Home and repeated families remain bounded (§E2).
    Justification: At least two elements can be removed or consolidated, so not 3; the representative surface does not contain the three-to-five removable elements required for 1.

## Total

**16/30**

The score applies the lower-score tie-breaker and worst-instance rules. Principle #8 scores 0.
