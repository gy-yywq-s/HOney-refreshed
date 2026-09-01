# Verdict

**REFINE** — At 21/30 with no zero-scored principle, the POSTFIX has made Explore states, deletion scope, direct recovery, palette contrast, and copy materially more coherent, but credential verification, provable option completeness, retry freshness, and Access recovery still prevent the design from reaching the 22/30 acceptance threshold.

## Residual severity

- **P0:** none found in source inspection.
- **P1:** replacement credentials can be “checked” through an old valid Portal session.
- **P1:** `Every available option` is not protocol-provable because the entity source silently caps at 500 without continuation/completeness metadata.
- **P1:** Explore Retry can temporarily label stale pre-retry choices as a complete current list.
- **P1:** Access direct retry is absent for first-load empty-permit failure and suppressed for combined permit/door failure; credential repair also requires a Home→Settings detour.
- **P1:** feed cursor/append/scroll restoration and several safe screen-level caches remain unfinished.

## Highest-leverage moves

1. **Principles #4 and #6 — Force-check replacement credentials:** Invalidate the old Portal session when credentials change, authenticate with the new pair before dismissing, preserve precise offline/manual-challenge outcomes, expose the repair action directly from Access, and add a valid-old-session/wrong-new-password regression test. Evidence: `ios/HOney/Features/Settings/SettingsView.swift:319-365`; `ios/HOney/Services/PortalSessionCoordinator.swift:83-109,162-167`; §E3.
2. **Principles #2, #4, and #6 — Make “every option” protocol-verifiable:** Replace the silent 500-entity cap with explicit pagination/completeness metadata, render every page through a complete grouped/progressively disclosed list, and keep search as a local convenience rather than a discovery gate. Evidence: `packages/backend/src/experiences/entities.ts:81-102`; `packages/backend/src/routes/experiences.ts:52-58`; `ios/HOney/Features/Experiences/ExperiencesView.swift:249-328`; §E2.
3. **Principles #6 and #8 — Represent retry freshness truthfully:** Preserve old choices during retry if desired, but show a visible refreshing/stale state and never claim the list is complete until the new complete response arrives; add full, partial, filtered-empty, genuine-empty, retry-in-flight, and retry-recovery tests. Evidence: `ios/HOney/Features/Experiences/ExperiencesViewModel.swift:39-62`; `ios/HOney/Features/Experiences/ExperiencesView.swift:231-245`; §E2, §E6.
4. **Principles #2 and #8 — Complete direct Access recovery:** Put retry outside the nonempty permits branch, preserve a reachable retry when both sources fail, route credential failures directly to the repair sheet, and verify first-load, partial, combined, and repeated-retry states. Evidence: `ios/HOney/Features/Access/AccessView.swift:201-258`; `ios/HOney/Features/Access/AccessViewModel.swift:66-68,150-175`; §E6.
5. **Principles #3, #8, and #9 — Finish evidence and continuity:** Preserve the passing four-palette chip treatment, then capture signed-in light/dark iPhone surfaces and accessibility states; add cursor feed/append/scroll restoration and only safe, scoped caches for repeated Access, Settings, and target-result reads. Evidence: `ios/HOney/Features/Experiences/MySubmissionsView.swift:275-288`; `ios/HOneyTests/SurfacePaletteTests.swift:27-49`; `ios/HOney/App/AppServices.swift:165-242`; §E4, §E7.
