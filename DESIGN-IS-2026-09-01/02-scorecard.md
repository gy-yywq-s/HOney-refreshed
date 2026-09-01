# HOney iOS Dieter Rams scorecard

1. Good design is innovative — Score: 1/3
   Evidence: The current theme and components explicitly reproduce the legacy app verbatim, using native patterns without a new interaction improvement (§E9).
   Justification: It is a competent reuse of familiar SwiftUI patterns, but it primarily imitates its own previous visual grammar with minor product extensions rather than refreshing a pattern with a clear design advance.

2. Good design makes a product useful — Score: 1/3
   Evidence: Four primary task areas are directly exposed, but prominent Share actions open a guidance-only detour instead of the promised editor (§E4).
   Justification: Important timetable and gate tasks are supported, yet a core Experiences action requires an unnecessary detour and points to an entity path that is not wired.

3. Good design is aesthetic — Score: 1/3
   Evidence: A token system exists, but the app expands to 27 base colors, off-scale inline spacing, low-contrast text, and competing full-screen/card/mark treatments (§E1–§E2).
   Justification: The shared alignment and control sizing do not offset multiple systemic inconsistencies and the jarring large-area color treatment.

4. Good design makes a product understandable — Score: 1/3
   Evidence: Multiple controls and containers use jargon or incomplete labels, image-only controls lack context, and Share does not perform the action its label predicts (§E4–§E5).
   Justification: More than three primary or recurring controls require explanation or behave differently from their labels, so a first-time user cannot reliably predict the flow.

5. Good design is unobtrusive — Score: 1/3
   Evidence: Full-screen gradients, translucent bordered cards, a gradient/shadow mark, chips, bands, materials, and custom action surfaces repeatedly sit between content and task (§E1–§E3).
   Justification: Decoration and chrome frequently compete with school-day content instead of consistently receding behind it.

6. Good design is honest — Score: 0/3
   Evidence: Report/reaction/import states can imply success after suppressed failures; gate names can map to arbitrary doors; sign-out/disconnect/delete and password copy claim different scopes than their behavior (§E6).
   Justification: False-success states and an unverified physical-gate mapping are deceptive behavior-level failures, which meet the rubric’s zero-score condition.

7. Good design is long-lasting — Score: 1/3
   Evidence: The draft deliberately reproduces a legacy mix of pale gradient, translucent cards, rounded headings, capsules, and serif wordmark (§E9).
   Justification: Several dated trend markers appear together, even though system controls and fonts provide a stable technical base.

8. Good design is thorough down to the last detail — Score: 1/3
   Evidence: All six required state categories exist, but focus has no authored visual treatment, errors are often collapsed into empty states, and success can be shown after failure (§E7).
   Justification: Focus, error, and success are three materially rough representative states, so the worst-instance rule prevents a higher score.

9. Good design is environmentally friendly — Score: 0/3
   Evidence: The app has no third-party runtime packages, idle animation, badges, or notifications, but it explicitly forces light appearance and ignores system dark mode (§E8).
   Justification: The rubric assigns zero when dark mode is ignored; the efficient motion and dependency profile cannot override that explicit anchor.

10. Good design is as little design as possible — Score: 1/3
    Evidence: The source has five repeated-purpose affordance families, duplicated navigation, duplicated targetless Share actions, and repeated filters/private actions (§E3).
    Justification: At least three to five recurring affordances or entry points can be removed or consolidated without breaking the primary tasks.

## Total

**8/30**

The score applies the required tie-breaker and worst-instance rules. It does not treat the current draft status as a reason to soften the result.
