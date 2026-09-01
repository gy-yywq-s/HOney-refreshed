# Legacy Design Audit & Preserve / Refine / Replace

> **HISTORICAL (2026-09-01, product-v2 freeze).** This document records an experiment round or a
> superseded decision. It is evidence, not binding direction. The source-of-truth hierarchy is
> defined in `docs/status/current.md`; current design direction lives in
> `docs/design/web-lab.md` / `docs/design/ios-lab.md` under `docs/design/shared-product-design-invariants.md`.

Required by master spec §1.4 and acceptance §20.35–§20.36. Audits the supplied legacy HOney iOS
app (`reference/legacy-ios/`, a SwiftUI build) before final UI implementation and classifies every
major legacy pattern. Binding direction from Gary (2026-08-31): **no legacy code is copied**; the
Access screen and the Timetable Day-view may carry their *product/design whole* forward
(Refine); every other finished legacy surface is treated as a crude prototype (Replace); the
legacy serif brand mark is not carried forward.

## Method

Read the legacy sources: `App/` (entry, `AppConfig`), `DesignSystem/` (`AppTheme`,
`AppComponents`), `Features/ContentView.swift` (a 6,899-line monolith) + `MusicViews`,
`MoreFeatureLabView`, `AmbientPresenceView`, and `Services/` (`PortalAPI` + several
`*CloudService`). Each pattern below is judged on Dieter-Rams-style usefulness for the V1 product
and against the spec's non-goals.

## Classification

| # | Legacy pattern (where) | Verdict | Rationale |
|---|---|---|---|
| 1 | **Cool navy/ocean/sky palette** (`AppTheme.Colors`) | **Refine** | The recognisable HOney "feel" is the cool-blue family; carried forward but re-derived to fresh, WCAG-AA token values (`design/tokens/tokens.json`), not the legacy RGBs. |
| 2 | **Serif "HOney" wordmark + login mark** (`AppTheme.brandDesign = .serif`) | **Replace** | Gary's call — the serif identity is dropped. New wordmark/marks generated via codex→imagegen; internal UI stays minimal. |
| 3 | **Translucent white rounded cards on a pale gradient** (`AppCard`) | **Refine** | Good, legible surface treatment; kept as the card idiom with refreshed radius/elevation tokens. |
| 4 | **`AppComponents` primitives** (Card/SectionHeader/Loading/Empty/Banner/ListRow) | **Refine** | The right component set; re-implemented cleanly as the new design system rather than copied. |
| 5 | **Animations disabled in checked-in config** (`AppConfig.enableAnimations=false`) | **Replace** | V1 uses real motion tokens (fast/standard) — a legacy weakness (§20.39) not retained. |
| 6 | **Access module** — apply-permit card + open-gate (commuter/permit route, Front/Back gate, confirmation overlay) (`AccessScreen`, `PortalStore`) | **Refine (parity target)** | Strongest product behavior in the legacy app; the *whole* is carried and modernised. Re-implemented fresh on the `PortalSessionCoordinator` actor (single-flight re-login, GET-only replay, non-idempotent openDoor) — behavior preserved, architecture new. |
| 7 | **Timetable Day-view** — day selector, vertical lesson timeline, current-time line, lesson cards (`ScheduleScreen`, `DayTimelineView`) | **Refine** | The Day-view information architecture is sound and is the V1 timetable; carried and modernised. The legacy **Week view is Replaced (removed)** per §8.1. |
| 8 | **Login screen** (`LoginScreen`, `HOneyLoginMark`) | **Replace** | Redesigned as "Continue with school account" (school-login-is-signup, consent toggle). Legacy prototype only. |
| 9 | **Home screen** (`HomeScreen` + Info/Lesson/Gate/Exam/Feedback cards) | **Replace** | Rebuilt to the spec's deliberately-small Home (Welcome, Next Lesson, small Experiences area, secondary School-Portal entry). Legacy exam/feedback cards dropped. |
| 10 | **Exams tab** (`ExamsScreen`, `NextExamCard`, …) | **Replace → remove** | V1 has no Exams module (§0/§18). Deleted entirely, incl. backend model/consent. |
| 11 | **Music tab + AVQueuePlayer** (`MusicViews`, `MusicPlayerStore`, `MusicCloudService`) | **Replace → remove** | Out of scope; a cloud-experiment surface. |
| 12 | **Ambient presence** (`AmbientPresenceView`, `AmbientCloudService`) | **Replace → remove** | Speculative "campus atmosphere"; out of scope. |
| 13 | **Feature Lab / Demos tab** (`MoreFeatureLabView` + `CommunityCloudService`) | **Replace → remove** | Experimental community demos; the real community layer is the spec's Experiences, rebuilt from scratch. |
| 14 | **In-app Feedback** (`AppFeedbackScreen`, `FeedbackCloudService`) | **Replace → remove** | Not a V1 feature. |
| 15 | **Cloud Admin + welcome-banner** (`CloudAdminScreen`, banner methods) | **Replace** | The only admin surface in V1 is the Experiences ops dash (studentId 0088), rebuilt with no author-lookup. |
| 16 | **Resources library** (`ResourcesScreen`, cloud resource service) | **Replace → defer** | Student-facing but cloud-experiment; not in the V1 nav. Deferred, not ported. |
| 17 | **`PortalAPI` raw-token networking + tolerant login parsing** | **Refine (behavior reference)** | The endpoint contract/quirks are honored (raw `Authorization`, door-list `status==1` in `message`, commuter `record_id=-2`), but the legacy auth gaps (403-only expiry check, sign-out-on-any-error, biometric-bound creds, non-single-flight reauth) are **corrected** — see the connector's failure matrix. |
| 18 | **Monolithic `ContentView.swift`** (6,899 lines: views + models + services) | **Replace** | Violates the four-band separation; V1 splits DesignSystem/Features(View+ViewModel)/Services/Models. |
| 19 | **Light-mode-only** (`preferredColorScheme(.light)`) | **Replace** | V1 tokens define light+dark (auto). |

## Continuity (§20.38) & retained-weakness check (§20.39)

- **Recognisably continuous:** cool-blue palette family, translucent-card surface idiom, rounded
  friendly forms, the Access mental model and the Day-view timetable all carry forward — so the
  rebuild reads as the same product (Refine rows 1,3,4,6,7).
- **Not pixel-parity:** brand mark, navigation shape, Home content, motion and architecture are
  all new (Replace rows).
- **Known legacy weaknesses explicitly NOT retained** (§20.39): animations-off, light-only,
  the monolith, the broken 403-only expiry detection, sign-out-on-any-error, biometric-bound
  silent recovery, and the exam/music/ambient/feedback feature sprawl. Each is Replaced or
  corrected above, not kept for familiarity.
