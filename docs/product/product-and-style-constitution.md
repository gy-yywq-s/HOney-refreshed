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
- **The 620 px timetable canvas density on normal heights stays.** Compact heights degrade by
  documented notches (540 px, 450 px on SE-class widths), never by silent compression.

## 3. Personality

HOney feels **quiet, warm but not cute, academically credible but not institutional, frank,
small-scale and trusted, restrained, alive** — the life comes from students' words, never from
ambient motion. It must not feel like the portal, a review marketplace, a complaint platform, a
productivity dashboard, an editorial portfolio, a growth product, or a design-system showcase.

**Content carries the warmth; the interface carries the calm.**

## 4. Visual system (binding tokens live in `apps/web/src/styles/tokens.css`)

- One humanist sans (Source Sans 3), one type ramp (12 / 13 / 15 / 16 / 17 / 20 / 22 / 28,
  display clamps up to 36), nothing below 12 px, no small all-caps titles.
- One cool palette, one muted blue-teal accent (`#33667c`, night `#8fc2d4`); warm hues only
  for semantic danger/ok.
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
