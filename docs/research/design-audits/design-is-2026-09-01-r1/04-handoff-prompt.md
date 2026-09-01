# 04 — /make-plan handoff (verdict: REDESIGN)

````
/make-plan Redesign the HOney web app's presentation layer (mobile PWA surface: Home, Timetable, Experiences feed/Explore/Compose, Settings). Current design failed a Dieter Rams audit at 16/30 with critical gaps in principles #3 aesthetic, #4 understandable, #8 thorough, #10 as little design as possible (each scored 1/3).

Verdict paragraph (quoted from 03-verdict.md):
> HOney's verified-honest trust architecture, quiet cool palette, and accessibility foundations deserve to survive intact, but at 16/30 the shipped presentation layer — typography and spacing with no system behind them, mislabeled and jargon-laden controls on primary paths, a broken modal containment plus a cluster of measured detail defects, and three-plus duplicated affordances — must be rebuilt from the tokens up rather than patched rule by rule.

Why redesign and not refine: total 16/30 is below the REFINE threshold of 20, and the failures are systemic (no type/spacing token system exists; naming drift and detail defects span every primary screen), not local to one screen. No principle scored 0, so this is a presentation-layer redesign — the trust architecture and copy survive wholesale.

Primary user: a high-school student on their phone (installed PWA, 390×844 typical, down to 320×568).
Primary tasks: (1) check today's timetable / next lesson, (2) read the Experiences stream, (3) share an experience.
Constraints: quiet-humanist language — single Source Sans 3 font, narrow cool palette, ONE muted blue-teal accent #33667c, no warm tones; no small ALL-CAPS titles; every finite option set fully displayed (search only filters); honest privacy copy (never overclaim anonymity); iOS wire compatibility — propose NO API changes.

Preserve from current design (verified strong in the audit — do not regress):
- The entire privacy/trust mechanics and copy: identity-free publish (apps/web/src/api/client.ts:232-234 auth:false + credentials:"omit"; no author column, packages/backend/src/db/database.ts:90-121), ownership keys, no-free-text reports, and the WhyPage/compose/settings honesty copy incl. "anonymity is a design boundary, not magic" (apps/web/src/pages/experiences/WhyPage.tsx:72-76). Scored the app's strongest suit.
- Color and font tokens: one accent #33667c (+ night #8fc2d4), cool-only palette, four user surfaces incl. Night, single Source Sans 3 (apps/web/src/styles/tokens.css:1-96) — zero warm tones and zero visible ALL-CAPS titles measured live.
- Accessibility foundations: skip link (src/components/AppLayout.tsx:57-59), 3px accent focus ring (src/styles/foundations.css:68-77), modal focus trap/Escape/restore (src/components/Modal.tsx:18-46), full keyboard reachability of every primary action, prefers-reduced-motion kill rule (foundations.css:367-380).
- The fixed non-wobbling frame and feed state machine: single scroll owner, nav shift 0.0px measured, CLS 0.000, snapshot-restored feed returns with zero refetch (src/features/experiences/useFeedController.ts:137-187), working pull-to-refresh, 0 interrupts on load, ~97.5KB br initial JS.

Discard (structural patterns causing the failures):
- Token-less per-rule sizing: 19 ad-hoc font sizes (14 fractional uses) and a near-continuous 1-2px spacing series with zero --space-*/type tokens. Evidence: tokens.css:1-96; measured type table (nav labels 11px, lesson meta 12px, meta tiers 1-2px below iOS norms). Caused failure on principle #3.
- The route-settle animation as an accidental containing block: `.view { animation: settle … both }` retains a transform so position:fixed overlays are contained — lesson-modal overlay 358×734 on a 390×844 viewport, mobile nav hit-testable under the open modal. Evidence: foundations.css:342-344 (measured live). Caused failure on principle #8.
- System-register labels on student-facing controls: "Browse teachers, places & food"→feed (ComposePage.tsx:205-207), "Nothing else is scheduled today." fires only when no future lesson exists (HomePage.tsx:88 vs packages/backend/src/services/timetable.ts:58-65), "Revoke/Verified retrospective/review slot/cooling-off pass" (MinePage.tsx:199-201, shared.tsx:165,225-226), three names for the Explore surface. Caused failure on principle #4.
- Duplicated affordances: Explore renders the same 10 entities twice on one page (ExplorePage.tsx:44-60,85-98), "Keep private" ×4 in one composer (ComposePage.tsx:249-257,288-293,348,385), three Home→feed paths on one screen (HomePage.tsx:99,114 + nav tab). Caused failure on principle #10.
- Registry data hygiene (user-visible, not an API change): duplicate room ids ("213" twice), a Place named "Not selected", Course names embedding student-roster surnames — clashes with "students aren't public subjects here".

Top 5 moves from the audit (verbatim):
1. #3 aesthetic — Introduce real type and spacing token scales, mobile-native. Collapse the 19 ad-hoc font sizes (14 fractional uses) into a documented ramp aligned to native mobile norms (body 17, secondary 15, caption 13; nothing below 12) and replace the near-continuous 1-2px spacing series with a discrete scale. Evidence: [V1][V2] — tokens.css:1-96 contains zero --space-*/type tokens; measured secondary/meta tiers sit 1-2px below iOS equivalents; 5 of 19 sizes are sub-13px.
2. #8 thorough — Fix the modal containing-block defect and the detail-defect cluster. `.view` retains a transform after the settle animation, so fixed overlays are contained: lesson-modal overlay measures 358×734 on a 390×844 viewport and the mobile nav stays hit-testable under an open modal. Same pass fixes report-dialog focus returning to body, the pull-to-refresh double-added 650ms spin, and the 144px compose overflow at 320×568. Evidence: [V7][A2][W6][V8] — foundations.css:342-344, Modal.tsx:19,44, PullToRefresh.tsx:79-82.
3. #4 understandable — Make every label mean what it does, in student language. "Browse teachers, places & food" must link to /experiences/explore, not the feed (ComposePage.tsx:205-207); "Nothing else is scheduled today." must be a today-check or say what it means (HomePage.tsx:88 vs BE/services/timetable.ts:58-65); one name for the Explore surface; replace "Revoke/Verified retrospective/review slot/cooling-off pass" with plain phrasing. Evidence: [C5][C6].
4. #2 useful — Humanize the countdown and give the feed a share entry. "In 618 min" should render hours/day cues — formatRemaining already exists (lib/format.ts:242-248) but is used only in the cooldown panel; a next-day lesson needs a "tomorrow" marker (HomePage.tsx:74, live-observed). A non-empty feed currently has zero compose entry points (FeedPage.tsx:109,119,127-133). Evidence: [C1][W6].
5. #10 as little design as possible + #9 — Remove duplication and honor system preferences. Collapse Explore's double listing, redundant "Keep private" instances, and one of Home's three feed paths; honor prefers-color-scheme in the boot script (index.html:17-29 reads only localStorage); split the admin Dash out of the single 278KB bundle (App.tsx:5-17). Evidence: [S3][V8][W1].

Redesign principles in priority order:
1. #3 aesthetic — every rendered size and gap traces to a named token; the type ramp reads mobile-native at 390×844 and holds at 320×568.
2. #8 thorough — all six states on every surface; modals dock and dim correctly at every viewport; no sub-AA text (fix disabled 2.19:1, placeholders 2.92-3.72:1, --ink-3 3.41:1) and no sub-44px targets (scope tabs 32px, daynav arrows 42px, "···" 30px, inline links 18-19px).
3. #4 understandable — a first-time student names every control correctly; zero system jargon on student surfaces.
4. #10 as little design as possible — each affordance appears once per screen; removing any remaining element breaks a task.

Deliverables for the plan:
- New information architecture (not derived from old): screen map for Home / Timetable / Experiences (feed-explore-compose-mine) / Settings with one entry point per task per screen
- New primary flow (low-fi, labeled, compared side-by-side to current): share-an-experience from feed and from Home, incl. target picking
- Token spec: full type + spacing + color scale in tokens.css, with a migration table old-value→token
- States checklist (empty, loading, error, success, focus, disabled) per surface
- Migration path for users currently on the old design (PWA cache/service-worker rollout, theme persistence preserved)
- Cutover criteria (when the old presentation layer is retired)

Anti-patterns to guard against (specific to REDESIGN):
- Porting old structure under new styling (the token pass must actually replace per-rule sizes, not alias them)
- Keeping both designs behind a flag indefinitely
- Redesigning to follow a trend rather than the principles above (quiet-humanist stays; no new accent, no warm tones, no ALL-CAPS)
- Treating the Preserve list as optional — the trust architecture, honesty copy, a11y foundations, and performance envelope must survive verbatim
- Proposing any API change (iOS wire compatibility is a hard constraint)
````
