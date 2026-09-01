# R1 Dieter Rams scorecard

Scoring uses the Design-Is anchors verbatim, integer 0–3, worst representative instance rather than the mean, and the lower score when evidence leaves a tie.

1. **Good design is innovative — Score: 1/3**
   Evidence: The privacy/raw-voice product behavior is distinctive, but the audited UI shell is a standard Ionic tabs/split-pane/segment/modal composition and no 5+ peer novelty evidence exists (`01-evidence.md#6-cross-principle-factual-summary`).
   Justification: This is a competent variation on established mobile/desktop patterns, not evidence of a clear pattern-level improvement or novel interaction.

2. **Good design makes a product useful — Score: 3/3**
   Evidence: Home puts Now/Next at the top and links directly to Timetable and Share; Feed is default and Explore exposes the complete directory (`apps/web-ionic/src/pages/HomePage.tsx:52-150`, `apps/web-ionic/src/pages/experiences/FeedPage.tsx:51-155`, `apps/web-ionic/src/pages/experiences/ExplorePage.tsx:31-167`).
   Justification: The locked primary task is completed immediately on Home with no decoy step, so the fewest-possible-steps anchor is met despite edge-quality defects elsewhere.

3. **Good design is aesthetic — Score: 1/3**
   Evidence: A coherent token system exists, but the audited matrix contains at least four representative inconsistencies: missing Feed segment state, Compose lower-copy overlap, Timetable lower-content overlap, and desktop Home imbalance (`01-evidence.md#rendered-findings`).
   Justification: The anchor assigns 1 when there are 3–5 inconsistencies or one jarring violation; the cross-viewport defects exceed the ≤2-minor-inconsistency ceiling for 2.

4. **Good design makes a product understandable — Score: 1/3**
   Evidence: All three rendered Feed states lose `Your classes` and a selected-state cue while retaining `Around school`, and mobile simultaneously reduces Share/Find/Mine to three icon-only title actions (`apps/web-ionic/src/pages/experiences/FeedPage.tsx:53-99`, `docs/web/evidence/ionic-fidelity/ionic/mobile-390x844-experiences.png`).
   Justification: More than one control or state is unclear to a first-time user, matching the 2–3-unclear-controls anchor rather than the single-tooltip level.

5. **Good design is unobtrusive — Score: 3/3**
   Evidence: Feed words remain the figure over hairline-separated rows, Home limits previews to two, new items never force-scroll, and no persistent promo/badge/tutorial layer appears (`apps/web-ionic/src/features/experiences/ExperiencePost.tsx:139-245`, `HomePage.tsx:50,111-130`, `FeedPage.tsx:102-105`).
   Justification: The chrome consistently recedes behind school-day and student-voice content, meeting the strongest anchor rather than merely being visible-but-quiet.

6. **Good design is honest — Score: 2/3**
   Evidence: Bounded high-risk claims map to unauthenticated publish payloads, local control keys, opt-in import, and disclosed external moderation, with no inflation/dark pattern found; however the mandatory all-string inventory is missing (`01-evidence.md#3-copy-and-honesty-evidence`).
   Justification: The audited claims are precise, but the tie-breaker requires the lower level because incomplete inventory prevents proving that every claim and label maps 1:1 across the whole surface.

7. **Good design is long-lasting — Score: 3/3**
   Evidence: One neutral humanist family, a restrained cool palette, hairlines, content-led hierarchy, and standard platform controls replace the superseded fad typography/motion vocabulary (`apps/web-ionic/src/styles/tokens.css:13-70`, `docs/design/web-lab.md:9-30`).
   Justification: No specific dated trend marker is present in the shipped matrix, so the three-year-current anchor is met.

8. **Good design is thorough down to the last detail — Score: 2/3**
   Evidence: Empty/loading/error/success/focus/disabled all exist, but signed-in Ionic focus behavior is not live-proven and the Mist `ink-3` pair, Feed tools, segment height, skip-link order, and bottom-bar edges are rough (`01-evidence.md#required-state-checklist`, `01-evidence.md#5-accessibility-evidence`).
   Justification: The six-state set is present, but focus and edge execution are rough enough to fit the one-state-missing-or-rough anchor rather than fully considered 3.

9. **Good design is environmentally friendly — Score: 1/3**
   Evidence: Initial JS is 1,152,054 raw bytes (267,509 Brotli), while current-lesson Home and current-time Timetable each run an infinite pulse unless reduced motion is enabled (`01-evidence.md#4-weight-and-friction-evidence`).
   Justification: Under the lower-score tie-breaker, the 500KB–2MB raw-JS and always-on motion signal matches the 1 anchor, not the compressed-only <500KB interpretation for 2.

10. **Good design is as little design as possible — Score: 3/3**
    Evidence: Four mobile destinations/three desktop destinations, a Home limited to Now/Next + at most two voices + direct actions, and direct contextual entry points avoid an extra dashboard layer (`apps/web-ionic/src/components/navTabs.tsx:17-28`, `apps/web-ionic/src/pages/HomePage.tsx:50-150`).
    Justification: On the representative core surfaces every persistent element serves navigation, orientation, voice, or an immediate task; removing one would break that task.

## Total

**20/30**

Verdict is determined mechanically: total ≥20 and no principle scored 0 → **REFINE**.
