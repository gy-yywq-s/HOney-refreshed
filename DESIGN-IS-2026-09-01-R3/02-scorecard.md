# R3 Dieter Rams scorecard

R3 uses the fixed anchors, worst representative instance, and lower-score tie-breaker. Earlier-round scores are not inputs.

1. **Good design is innovative — Score: 2/3**
   Evidence: The lightweight public doorway plus authenticated Ionic shell remains a clear technological refinement, while no five-peer novelty study exists (`01-evidence.md#weight-and-friction-lane`).
   Justification: It improves an established pattern rather than establishing a new one, matching 2 rather than 3.

2. **Good design makes a product useful — Score: 3/3**
   Evidence: R3 adds no step or control; Now/Next, direct Timetable/Share, feed-first Experiences and complete Explore remain intact (`01-evidence.md#structural-lane`).
   Justification: The primary task still completes in the fewest possible steps without decoy actions.

3. **Good design is aesthetic — Score: 3/3**
   Evidence: The six R3 images retain one type/color/spacing/alignment system, and the longer Compose disclosure remains composed above navigation (`01-evidence.md#visual-lane`).
   Justification: No current orphan style or representative inconsistency is evidenced, satisfying the single-visible-system anchor.

4. **Good design makes a product understandable — Score: 2/3**
   Evidence: Ordinary-user truth is now concrete and action-adjacent, but one Settings summary contradicts its detailed explanation and admin copy retains several technical labels (`01-evidence.md#copy-and-honesty-lane`).
   Justification: The primary flow is clear, but at least one concise label still needs correction/explanation, so the lower 2 anchor applies rather than 3.

5. **Good design is unobtrusive — Score: 3/3**
   Evidence: The fuller disclosure remains inline and readable; content stays the figure, initial overlays remain absent and continuous idle animation is zero (`01-evidence.md#visual-lane`).
   Justification: Chrome continues to recede behind school-day and student content, matching 3.

6. **Good design is honest — Score: 2/3**
   Evidence: The complete inventory and behavior trace confirm the targeted claims now match, with one remaining key-only overstatement in the Settings deletion summary (`01-evidence.md#remaining-inflationmismatch`).
   Justification: Exactly one current minor inflation/mismatch fits the ≤1-minor-inflation anchor for 2; multiple inflations or a dark pattern were not found.

7. **Good design is long-lasting — Score: 3/3**
   Evidence: Neutral humanist type, restrained cool palette, hairlines and standard controls remain free of trend effects (`01-evidence.md#per-principle-factual-feed`).
   Justification: No dated marker is present, satisfying the three-year-current anchor.

8. **Good design is thorough down to the last detail — Score: 3/3**
   Evidence: Empty/loading/error/success/focus/disabled remain present; R3 adds fresh disclosure rendering and integrity assertions while preserving AA/44px/terminal details (`01-evidence.md#visual-lane`, `01-evidence.md#accessibility-lane`).
   Justification: All six mandatory states are present and considered, so 3 applies despite device-test gaps.

9. **Good design is environmentally friendly — Score: 2/3**
   Evidence: Public initial JS is ~61 KiB gzip and motion is gated/idle-free, but the worst authenticated initial path is ~264 KiB gzip and over 1.1 MiB raw (`01-evidence.md#weight-and-friction-lane`).
   Justification: The worst representative path is below 500 KiB compressed with motion gated, matching 2; it is not below 100 KiB across the product.

10. **Good design is as little design as possible — Score: 3/3**
    Evidence: R3 adds no route, control, modal, step or decorative layer; existing persistent elements remain task-bound (`01-evidence.md#structural-lane`).
    Justification: No removable visible element is evidenced, so every element earns its place.

## Total

**26/30**

Mechanical result: total ≥20 and no principle scored 0 → **REFINE**.

The numeric ≥24 gate is met. The remaining Settings sentence is a material privacy/operational-truth defect and should be corrected before deployment even though it no longer drives the audit below the gate.
