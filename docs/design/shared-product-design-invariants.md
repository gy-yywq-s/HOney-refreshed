# Shared product-design invariants

These are the truths BOTH platforms must respect. They control what each
platform *does* and *claims* — never what it *looks like*. Typography, palette,
surfaces, radius, nav shell, motion vocabulary, density, wordmark treatment and
per-page composition are lab-specific (see `web-lab.md`, `ios-lab.md`) until a
future Convergence Audit. Source: repo review v3 §5.1/§5.7; owner-directed.

## Product substrate

1. V1 IA: Home, Experiences, Timetable (one Day view + History), Access
   (iOS only, direct-to-school), School Portal as secondary doorway.
   V1 non-goals stand: no exams, no week view, no analytics/attendance, no
   leaderboards, no human scalar ratings (dish rating is the only scalar), no
   comments/DM/followers/trending, no AI teacher summaries.
2. **Home's primary job is school-day orientation** — Now/Next in ~3 seconds,
   plus a light sense that other students are speaking. Not a feature
   dashboard, not decorative statistics.
3. **Experiences is feed-first**: the default surface is a chronological,
   cursor-paged stream of raw student voices scoped to shared context
   (`Your classes` / `Around school`). Explore (entity lookup) is a deliberate,
   clearly-reachable second mode — it never displaces the feed as default.
4. Raw-first: the student's own words carry the largest visual weight; metadata
   stays quiet; no ranking by reactions/sentiment/"helpfulness"; a light
   adjacency-diversity rule at most (≤2 consecutive posts on one primary
   entity), never an opaque relevance score.
5. Reactions mean **experiential resonance** ("Matches my experience"), never
   truth votes; they never affect ordering, visibility, or moderation.
6. Community identity is **persistently visible**: a short student-to-student
   line near the Experiences title (e.g. "For students, between students — not
   a teacher feedback channel.") plus a real, readable "Why this space exists"
   entry. Teachers are an important subject, not the addressed audience; no
   promise teachers can never see posts.
7. Moderation semantics are ordered: **Standing → Expression → Scope → Timing**.
   Classification may be parallel; enforcement is ordered; the user sees only
   the frontmost unpassed boundary. Cooldown is timing, not wrongdoing.
   Composition help ("add context?") is optional, never a gate.
8. Private note is first-class, not a failed-moderation fallback.
9. Session independence: HOney account, portal API session, and portal WebView
   session are three states; portal expiry never logs out HOney. Physical
   mutations never auto-replay; timeouts are "outcome unknown".
10. Privacy copy states only what the implementation guarantees. Current
    honest level: *published posts are stored without an author field, and the
    final publish request carries no ordinary account identity* — never
    "nothing links this back to you" while ownership keys / authenticated
    check exist. External LLM processing must be disclosed in a reachable doc.
11. Quality floor everywhere: contrast, touch targets, keyboard/VoiceOver
    paths, reduced-motion respect, honest loading/empty/error/stale states.
12. **All selectable options are displayed** (owner rule 4f): finite option
    sets are always fully browsable via a proper organizing method; search
    only filters, it is never the sole path to an option.

## Shared tone guardrail (not a token spec)

calm · human · academically serious · socially warm but not cute ·
not gamified · not corporate · not advertising-like · not self-consciously
"editorial" · privacy language precise · content gets more attention than
interface authorship.
