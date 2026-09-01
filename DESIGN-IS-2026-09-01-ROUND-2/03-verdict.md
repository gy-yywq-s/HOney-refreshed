# Design Is — Round 2 verdict

**REFINE — At 23/30 with no zero-scored principle, the deployed Ionic Web/PWA reaches Gary's current acceptance threshold: its direct task flow, product truth, and durable visual grammar are strong, while a narrow last-detail backlog remains in Explore alignment, timetable/control accessibility, and one duplicated post affordance.**

Highest-leverage moves:

1. **Principles #8/#3 — Thorough/aesthetic:** Constrain the actual rendered Explore `ion-searchbar`
   host to the same 710px spine as its segment/results, and make the browser assertion target the
   searchbar rather than the first generic `.explore-control`. Evidence: `01-evidence.md#visual-evidence`.
2. **Principle #8 — Thorough:** Remove whole-row opacity from past timetable entries; apply semantic
   tokens per child so every muted/faint line remains ≥4.5:1 in both schemes, and raise segment plus
   fixture-only controls to 44px. Evidence: `01-evidence.md#accessibility-and-state-evidence`.
3. **Principles #4/#10 — Understandable/minimal:** Keep the visible per-post Add action and remove its
   duplicate from More, leaving More for reporting/cancel only. Evidence:
   `01-evidence.md#structural-and-flow-evidence`.
4. **Principle #8 — Thorough:** Add a bounded keyboard regression for overlay initial focus, Tab trap,
   Escape dismissal, trigger-focus restoration, and a visible keyboard alternative to refresh.
   Evidence: `01-evidence.md#accessibility-and-state-evidence`.
5. **Principle #9 — Environmental:** Audit the Workbox precache manifest and Ionic bootstrap; retain
   offline/update guarantees while excluding nonessential first-install assets and reducing the
   288,943-byte encoded main bundle. Evidence: `01-evidence.md#performance-and-environmental-evidence`.
