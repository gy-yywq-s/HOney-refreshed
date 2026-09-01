# R2 Dieter Rams scorecard

Scores use the exact 0–3 anchors, worst representative instance, and lower-score tie-breaker. R1 scores were not inputs.

1. **Good design is innovative — Score: 2/3**
   Evidence: The candidate refreshes the conventional authenticated Ionic shell with a separate non-Ionic public doorway that cuts public cold JS to about 61 KiB gzip while preserving the installed-app experience (`01-evidence.md#weight-and-friction-lane`).
   Justification: This is a clear technological improvement to an established pattern, but there is no evidence of a pattern unseen in five or more peer products, so 3 is unavailable.

2. **Good design makes a product useful — Score: 3/3**
   Evidence: Home retains immediate Now/Next orientation and direct Timetable/Share paths; Feed is default, both scopes are visible, and Explore remains complete (`01-evidence.md#per-principle-factual-feed`).
   Justification: The primary task still completes in the fewest possible steps with no decoy action, matching the strongest anchor.

3. **Good design is aesthetic — Score: 3/3**
   Evidence: The six R2 screens follow one visible type, spacing, cool-color and alignment system; both scope states, Compose fill, terminal clearances and centered desktop Home are coherent (`01-evidence.md#visual-lane`).
   Justification: No current orphan style or representative visual inconsistency is evidenced, so the single-system anchor applies.

4. **Good design makes a product understandable — Score: 2/3**
   Evidence: Both Feed scopes and selection states are now explicit and integrity-tested, but mobile tools remain icon-led and ordinary-user copy still uses `ownership key` and `relevant exposure` (`01-evidence.md#copy-and-honesty-lane`).
   Justification: Primary structure is clear, but at least one compact action/term still benefits from an inline explanation or tooltip, so the lower 2 anchor applies rather than 3.

5. **Good design is unobtrusive — Score: 3/3**
   Evidence: Feed words remain the figure, chrome and terminal spacing stay quiet, no initial overlay/badge appears, and Home/Timetable idle pulses are gone (`01-evidence.md#visual-lane`).
   Justification: The UI consistently acts as ground for school-day and student content, satisfying the strongest anchor.

6. **Good design is honest — Score: 1/3**
   Evidence: The complete inventory and behavior trace find three over-absolute families: `never sent` after a prior safety check, `nothing stored` despite local draft storage, and key-only control copy despite authenticated-session requirements (`01-evidence.md#inflations-and-labelbehavior-mismatches`).
   Justification: The anchor assigns 1 for two or more inflations; these are concrete label→behavior mismatches even though no dark pattern or deceptive publication flow was found.

7. **Good design is long-lasting — Score: 3/3**
   Evidence: One neutral humanist family, restrained cool palette, hairlines, platform controls and absence of decorative trend effects persist (`01-evidence.md#per-principle-factual-feed`).
   Justification: No dated trend marker is present, meeting the three-year-current anchor.

8. **Good design is thorough down to the last detail — Score: 3/3**
   Evidence: Empty, loading, error, success, focus and disabled states all exist; R2 additionally proves both scope states, 44px controls, AA text tokens, terminal geometry and desktop centering (`01-evidence.md#required-state-checklist`, `01-evidence.md#accessibility-lane`).
   Justification: All six mandatory states are present and considered in current source/rendered evidence, so the strongest anchor applies despite remaining device-test gaps.

9. **Good design is environmentally friendly — Score: 2/3**
   Evidence: Public initial JS is ~61 KiB gzip with zero idle animation, but the authenticated initial entry plus App is ~264 KiB gzip and over 1.1 MiB raw; dark presentation and reduced motion are supported (`01-evidence.md#weight-and-friction-lane`).
   Justification: The worst representative initial path is below 500 KiB compressed with motion gated, matching 2; it is not below 100 KiB across the audited product, so 3 is unavailable.

10. **Good design is as little design as possible — Score: 3/3**
    Evidence: The task-bound navigation/content set is unchanged, the public doorway omits the entire authenticated shell, and persistent elements remain directly tied to orientation, voice or action (`01-evidence.md#structural-lane`).
    Justification: No removable persistent element is evidenced on the representative surfaces, so every element earns its place under the 3 anchor.

## Total

**25/30**

Mechanical result: total ≥20 and no principle scored 0 → **REFINE**.

R2 clears the requested numeric gate of 24/30, but principle #6 remains at 1 because current privacy/storage copy does not map 1:1 to alternate behavior paths.
