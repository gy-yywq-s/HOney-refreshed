# HOney — Product & Style Constitution

**Status:** binding. This file is the single authority for what HOney is and how it looks and
speaks. Where any other document conflicts, this one wins.

> Supersedes the design sections of `docs/decisions-2026-09-01.md` and the editorial
> direction in `docs/legacy-design-audit.md` / the Codex `AGENTS.md`. Legacy is a **reference**,
> not pixel parity. The Codex editorial UI is **exploratory**, not approved. The default decision
> for every screen is **Refine** — keep the bones, finish the details, never restyle for its own
> sake. Backend and state improvements merge independently of presentation.
>
> Hierarchy of record: this file → `docs/design/shared-product-design-invariants.md` →
> `docs/design/web-lab.md` / `docs/design/ios-lab.md` → `docs/architecture/*` → `docs/status/*`
> → `docs/research/*` (evidence only) → `docs/superseded/*`.

## 1. What HOney is

A calm school utility whose social layer feels like useful, honest context circulating among
students who share the same place. Three values, nothing more:

1. **Immediate utility** — what is next and how to get in (Timetable, Access on iOS).
2. **Persistent utility** — timetable and history, and the official portal without re-signing-in.
3. **Social knowledge** — what school is like, from people who were there (Experiences).

Do not broaden the product before these three are excellent.

## 2. Product decisions that are settled (not up for re-litigation)

- **Timetable import is part of the account.** Signing in with the school account is the
  decision to bring the timetable and history along. There is no consent gate and no switch;
  the fact is disclosed on the login screen and in Settings, and the disclosure names exactly
  the triggers that exist (account creation, "Sync now"). Import runs once on creation and on
  "Sync now"; later sign-ins never import.
- **Experiences is stream-first.** Opening Experiences shows a chronological stream (Your
  classes / Around school). Find (teachers, courses, places, food, search) is one action away
  and never above the stream. No engagement ranking, ever.
- **Course is a first-class entity** alongside teacher, room and dish.
- **Moderation is ordered enforcement, policy v7:** Standing → Expression → Scope → Timing.
  Classification is one LLM call that never decides; the deterministic engine decides. The
  student sees only the frontmost unpassed boundary. Source of truth for the logic is
  `packages/backend/src/experiences/policy.ts` and its versioned corpus.
- **Reports re-evaluate tri-state:** confident violation hides; confident allowed keeps;
  unavailable/uncertain keeps and retries. A classifier outage never unpublishes.
- **Reactions are authoritative** (server echo, viewer value restored) and gated on exposure.
- **Privacy claims are exactly what the code does:** posts are stored without an author field
  and there is no normal author lookup; the words may still make a student recognisable;
  candidate text is sent to an external model provider (disclosed). Nothing stronger is claimed
  until genuine protocol unlinkability ships (recorded launch blocker).
- **Four background surfaces (Stone / White / Mist / Night) stay** — the owner's choice.
  The system dark preference is honoured before first paint when nothing is stored.
- **The timetable canvas fills the phone's frame and never compresses below 560 px** (desktop
  656 px). Every notched iPhone in standalone mode fits with zero page scroll; taller phones
  get a taller canvas. Compact heights degrade by documented notches (540 px, 450 px on
  SE-class widths), never by silent compression. The day range widens to the hour for a lesson
  outside 09:00–20:00 — a clipped block is not an option.
- **On phones the timetable is a native-style screen with no captions and no utility buttons**
  (Gary, 2026-09-02). The date bar sits flush under the status bar and *is* the heading; the
  native date input lies invisibly over it, so a tap opens the platform calendar. Pull-to-
  refresh never moves the content by hand on iOS: the region's own rubber band *is* the pull
  and the pill reads it (one motion, the Ionic way); the content rests a little way down while
  the work runs, then eases home. It has two stages — release to refresh; the sync stage is a
  far pull that must also be HELD until a fill crosses the pill (the pill turns accent only
  then), so it cannot fire by accident. At the end of the canvas a deliberate pull-up opens History; it needs
  the owner already at its end, a long damped drag, more time than a flick, and shows the
  release point first. Desktop keeps History and Sync now as buttons.
- **The app is a hierarchy, like a native app** (Gary, 2026-09-02). Four roots are the tabs;
  every other screen hangs under one (`apps/web/src/lib/navigation.ts` is the single tree:
  History under Timetable, Lesson under History, Find / Mine / Why / entities under
  Experiences, the composer under what it is about, Dash under Settings). Every non-root
  screen shows "‹ Parent" top-left; the tab of the root ancestor is lit; the arrow pops when
  the parent is the previous entry and otherwise replaces — never a parent/child loop; tab
  switches replace history; on phones a left-edge swipe is the same "up".
- **Review v1.1 (2026-09-02) is implemented as the composition baseline.** Home's Now/Next is
  one lesson object (state + relative time on one row, subject, time · teacher · room, whole
  card a link). Experiences opens with the title, three toolbar icons and one culture line
  ("Written by students, for students." + Why); provenance sits on its own line before the
  words. Explore is a framed finder: a real search field and four category chips, one
  category listed in full at a time (rule 4f), typing filters every category and finds
  experiences. Raw portal course strings are split once for display into title +
  "2026 Autumn · 备考班 · teacher" (`apps/web/src/lib/displayNames.ts`). The composer's picker
  is rows; "Continue to share" / "Keep private". Notes & Posts is the user's words first,
  the device-key note one quiet row. Settings is concise rows with one detail screen each
  under `/settings/:section`. Geometry: page inset 20, cards 16 / controls 14 / fields 12,
  pills only for genuine choice pills, a 54px bottom nav with a soft selected block.
- **Timetable is Day first with a Week overview one tap away** (addendum v1.1, 2026-09-02).
  Week is a school-period matrix — Mon–Fri columns, P1–P6 rows from the one period catalog
  (`apps/web/src/lib/periodCatalog.ts`), Lunch/Dinner as spanning separators, cells = compact
  subject + room, today's column tinted, the current lesson the strongest cell, never a time
  line, never horizontal scroll at ≥320. A cell opens the lesson sheet ("Open this day"); a
  weekday header opens Day for that date. The mode persists for the session only; Day is
  every cold entry. One request per week (`GET /api/timetable/range`).
- **The cooling-off period is a Dash setting** (whole hours, default 24; wheel of presets). A
  cooling outcome keeps the words as a private note at once, carrying the remaining time and
  the server's ticket; Your notes & posts says "Cooling · can be shared in …" / "Pause over ·
  ready to share again", and the re-check reuses the ticket for unchanged text.

## 3. Personality

HOney feels **quiet, warm but not cute, academically credible but not institutional, frank,
small-scale and trusted, restrained, alive** — the life comes from students' words, never from
ambient motion. It must not feel like the portal, a review marketplace, a complaint platform, a
productivity dashboard, an editorial portfolio, a growth product, or a design-system showcase.

**Content carries the warmth; the interface carries the calm.**

## 4. Visual system (binding tokens live in `apps/web/src/styles/tokens.css`)

- One humanist sans (Source Sans 3), one type ramp (12 / 13 / 15 / 16 / 17 / 20 / 22 / 28,
  display clamps up to 36), nothing below 12 px, no small all-caps titles.
- One cool palette, one accent SCHEME at a time (Settings › Accent, Gary 2026-09-02): the
  default is the muted blue-teal Harbour (`#33667c`, night `#8fc2d4`); the other schemes are
  Harbour rotated in OKLCH hue with lightness and chroma untouched, so weight and contrast never
  change, and Cobalt pairs a true blue with the Harbour teal as companion for the wide soft
  areas (`--accent-2`). A scheme is accent + tint + companion + night lift — never one colour.
  Warm hues only for semantic danger/ok.
- One spacing ladder (4 / 8 / 12 / 16 / 20 / 24 / 32 / 44); shell clearances are the only
  documented literal exceptions.
- Cards only for genuinely self-contained objects; separators, whitespace and typographic
  rhythm do the work in streams and lists. Modest radius, rare shadows.
- Motion only explains state: route settle, skeleton shimmer, pull-to-refresh, sheet entrance,
  lesson progress. Zero idle animation. `prefers-reduced-motion` collapses everything.
- The app shell owns the viewport; one scroll owner; every route declares its scroll model
  (`docs/design/web-lab.md` §16.14).
- Every finite option set is fully displayed; search only filters.

## 5. Voice

Direct, short, humane, non-judgmental, precise about privacy and serious matters, lightly
conversational, never chirpy. No institutional terms on student surfaces (no "moderation lane",
"policy version", "verified provenance"), no moralising ("be kind"), no inflated claims
("completely anonymous"), no self-conscious slogans, no cryptographic mechanics in primary task
copy.

Canonical lines (product review §5):

- Product: **Your school day, made easier.** — *See what's next, open the gate, and learn the
  things students only learn from each other.*
- Login: **Your school day, without the portal friction.** — *Use your school account. HOney
  creates no separate password.*
- Experiences: **What school feels like, from people who were there.** — *Read what others
  experienced. Share what it was like for you.* Culture line: *People are more than one
  experience. Experiences still matter.*
- Composer: **What was it like for you?** — *Specific details can help someone understand. A
  feeling can matter too.* Actions: *Share anonymously* / *Keep this for yourself*.
- Nudge: *This can be shared as it is. Is there anything that would help someone understand
  what you mean?* — Share as written / Add a little context / Keep this for yourself.
- Cooling period: *Your words are saved. Come back after the pause if you still want to share
  them.* — *This is a pause, not a judgment about your experience.*
- Expression revision: *This wording can't be shared here yet. Remove the insult or private
  detail, then say what happened or how it felt.*
- Unclear wording: *We couldn't understand part of this well enough to publish it. Say it more
  directly.*
- Out of scope: *This sounds like something that needs real support or action, not a public
  post. HOney won't publish it or send it to the school.*
- Empty feed: *Nothing from your classes yet. A small honest note is enough.* Empty entity
  page: *No one has shared an experience here yet.*
- Privacy: *Published posts are stored without an author ID. Eligibility and publication are
  handled separately.* / *What you write may still make you recognisable to someone who knows
  the situation.*

Never advertise "rate teachers", "the truth about teachers", "expose bad teaching", or
"the student review platform".

## 6. Quality process

- Presentation quality is measured by the design-is audit (Rams' ten principles, browser-driven
  evidence, `docs/research/design-audits/`). The loop is: orchestrator (Fable) → five evidence
  subagents (Opus) → scorecard → handoff → implement → re-audit, until ≥ 24/30.
- After **any** stylesheet edit: parse the served CSS (`apps/web/scripts/check-css.mjs`, wired
  into the build), run the TSX→CSS reverse sweep, and diff computed styles on the deployed app.
  Delete selectors, not rules; modifiers after their base rule.
- Every fix is verified on the deployed app in every state, never from the diff.
- Dev stage: the live site always runs the latest green commit of the working branch.
