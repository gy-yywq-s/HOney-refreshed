# HOney iOS FINAL scorecard

1. Good design is innovative — Score: 2/3
   Evidence: Anonymous device-key control, bounded Portal behavior, actor caches, non-replayed physical mutations, and local non-gating filtering improve familiar native patterns (§E2, §E3, §E7).
   Justification: These are clear improvements beyond minor imitation, so not 1; no five-plus peer comparison proves a genuinely new pattern, so not 3.

2. Good design makes a product useful — Score: 3/3
   Evidence: Current/next lesson is immediate, every selectable source is uncapped and browsable without search, Timetable teacher context is guaranteed, and normal Access failures expose recovery (§E2, §E5, §E6).
   Justification: The primary orientation task completes in the fewest possible steps without a decoy, matching 3; feed continuation and one action-time repair edge are adjacent rather than detours in that primary task.

3. Good design is aesthetic — Score: 2/3
   Evidence: Four semantic palettes and status chips pass source-level contrast, while one-off spacing, placeholder identity, and absent current rendered evidence remain (§E4).
   Justification: A coherent visible system rules out 1; the unfinished spacing/identity/runtime-validation families prevent the orphan-free 3.

4. Good design makes a product understandable — Score: 2/3
   Evidence: Loading, refresh, partial, empty, deletion, reconnect, teacher, and Access recovery language is explicit; a few technical labels and action-time reconnect visibility remain (§E3, §E5, §E6).
   Justification: One recovery-control family still needs clarification/state propagation, so not 3; primary controls remain identifiable and smaller jargon does not create the two-to-three primary-control failure required for 1.

5. Good design is unobtrusive — Score: 2/3
   Evidence: Idle decoration is zero, Home color remains background-only, search is optional, and status color is restrained, while card/list/segmented chrome remains visible (§E4, §E7).
   Justification: Decoration does not compete with content, ruling out 1; chrome is visible though quiet, so not 3.

6. Good design is honest — Score: 2/3
   Evidence: Complete-list, teacher, deletion, palette, and sequential credential claims map to behavior; one in-flight Portal race can still resurrect or overwrite an old authenticated session (§E2, §E3, §E5).
   Justification: One bounded but load-bearing claim/behavior family prevents 3; multiple normal-flow mismatches and all deceptive/dark-pattern signals are absent, so the 1 or 0 anchors do not fit.

7. Good design is long-lasting — Score: 2/3
   Evidence: Native controls, semantic Apple typography, adaptive appearance, and restrained motion are durable; the raster placeholder identity remains the one explicit temporary marker (§E4, §E8).
   Justification: One temporary identity marker prevents 3; no second or third dated trend marker supports 1.

8. Good design is thorough down to the last detail — Score: 2/3
   Evidence: Generic and advanced states are substantially complete, but in-flight credential replacement/erase and action-time connection-state propagation remain one rough concurrency/recovery family (§E3, §E6).
   Justification: One representative state family remains rough, matching 2; the complete state vocabulary rules out 1 or 0.

9. Good design is environmentally friendly — Score: 3/3
   Evidence: Native initial JS and idle attention are zero, appearance/Reduce Motion are honored, and Timetable/Experience repositories cache, coalesce, and reject stale work (§E7).
   Justification: The native equivalents of every 3-level signal are met; bounded Access and first-page feed work do not match always-on motion or an excessive initial bundle.

10. Good design is as little design as possible — Score: 2/3
    Evidence: Lesson-first Home and complete local filtering are restrained; simultaneous permit/full Retry and technical helper copy remain removable (§E1, §E5, §E8).
    Justification: At most two removable elements appear together on a representative surface, matching 2; no surface is dominated by three-to-five decorative or duplicate affordances.

## Total

**22/30**

The lower-score tie-breaker and worst-instance rules were applied. No principle scores 0. The mechanical verdict is REFINE. The project numeric threshold is reached, but final release/owner acceptance remains incomplete because load-bearing P1 concurrency/state propagation and physical-device/accessibility evidence remain unresolved.
