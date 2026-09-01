# 03 — Verdict

**REDESIGN.**

HOney's verified-honest trust architecture, quiet cool palette, and accessibility foundations deserve to survive intact, but at 16/30 the shipped presentation layer — typography and spacing with no system behind them, mislabeled and jargon-laden controls on primary paths, a broken modal containment plus a cluster of measured detail defects, and three-plus duplicated affordances — must be rebuilt from the tokens up rather than patched rule by rule.

## Why the verdict is mechanical and robust

Phase 3 rule: total < 20 → REDESIGN. The total is 16. Robustness check: four scores were settled downward by the tie-breaker (#1, #7, and the 1/2 boundaries on #2 framing and #10); even granting every tie-broken point upward the total reaches only 19 — still below the REFINE threshold. No principle scored 0, so this is a presentation-layer redesign, not a start-from-purpose teardown: the failures cluster in principles #3, #4, #8, #10, all of which are systemic (absent token system, naming drift, containment/detail defects, duplication), not one ugly screen.

Anti-pattern check: this is not sunk-cost REFINE (the codebase's size played no role) and not single-screen REDESIGN (defects were measured across Home, Feed, Compose, Timetable, Explore, and Settings).

## Highest-leverage moves

1. **#3 aesthetic — Introduce real type and spacing token scales, mobile-native.** Collapse the 19 ad-hoc font sizes (14 fractional uses) into a documented ramp aligned to native mobile norms (body 17, secondary 15, caption 13; nothing below 12) and replace the near-continuous 1–2 px spacing series with a discrete scale. Evidence: [V1][V2] — tokens.css:1-96 contains zero --space-*/type tokens; measured secondary/meta tiers sit 1–2 px below iOS equivalents; 5 of 19 sizes are sub-13 px.
2. **#8 thorough — Fix the modal containing-block defect and the detail-defect cluster.** `.view { animation: settle … both }` retains a transform, so fixed overlays are contained: lesson-modal overlay measures 358×734 on a 390×844 viewport and the mobile nav stays hit-testable under an open modal. Same pass fixes report-dialog focus returning to body, the pull-to-refresh double-added 650 ms spin, and the 144 px compose overflow at 320×568. Evidence: [V7][A2][W6][V8] — foundations.css:342-344, Modal.tsx:19,44, PullToRefresh.tsx:79-82.
3. **#4 understandable — Make every label mean what it does, in student language.** "Browse teachers, places & food" must link to /experiences/explore, not the feed (ComposePage.tsx:205-207); "Nothing else is scheduled today." must be a today-check or say what it means (HomePage.tsx:88 vs BE/services/timetable.ts:58-65); one name for the Explore surface; replace "Revoke/Verified retrospective/review slot/cooling-off pass" with plain phrasing. Evidence: [C5][C6].
4. **#2 useful — Humanize the countdown and give the feed a share entry.** "In 618 min" should render hours/day cues — formatRemaining already exists (lib/format.ts:242-248) but is used only in the cooldown panel; a next-day lesson needs a "tomorrow" marker (HomePage.tsx:74, live-observed). A non-empty feed currently has zero compose entry points (FeedPage.tsx:109,119,127-133). Evidence: [C1][W6].
5. **#10 as little design as possible + #9 — Remove duplication and honor system preferences.** Collapse Explore's double listing (same 10 entities twice, ExplorePage.tsx:44-60,85-98), redundant "Keep private" instances (ComposePage.tsx:249-257,288-293), and one of Home's three feed paths; honor prefers-color-scheme in the boot script (index.html:17-29 reads only localStorage); split the admin Dash out of the single 278 KB bundle (App.tsx:5-17). Evidence: [S3][V8][W1].

Also relay to the owner (data, not design, but user-visible): duplicate room registry ids, a Place named "Not selected", and Course entity names embedding student-roster surnames — the latter sits badly next to "students aren't public subjects here" ([S6][C6]).
