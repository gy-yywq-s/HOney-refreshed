# UGC / App-Store requirements review

Required by Appendix A §21 (Apple review guideline 1.2 / Google Play UGC). Maps each store
requirement for user-generated content to the implemented mechanism. Reviewed against the code on
2026-08-31.

| Store requirement | Implemented mechanism | Where |
|---|---|---|
| **A method for filtering objectionable content** | Deterministic lexicon + constrained LLM extractor + deterministic policy engine, fail-closed; serious/slur/doxxing/threat content cannot publish | `experiences/{normalize,lexicon,llm,policy}.ts`; tests `corpus.test.ts` launch gates |
| **A mechanism for users to flag objectionable content** | `POST /api/experiences/:id/report` with rule-based categories; iOS + web report UI | `routes/experiences.ts`; web report modal; iOS report action |
| **A mechanism for users to block abusive users** | Not a person-to-person social graph (no DMs/follows/profiles); "blocking" is not applicable — students are never entities and there is no user-to-user contact surface. Abuse is handled by content removal + author-side restriction instead. | design (§6.3 human-entity boundary) |
| **Timely removal / response to flagged content** | Reports trigger **automatic** re-evaluation under the current policy (no human queue); any non-publishable outcome (incl. LLM outage) hides the post immediately | `service.ts` `report()` |
| **Restrict/expel abusive contributors** | `abuse_counters` (§21): high-confidence prohibited attempts are counted per account (no text, no post link) and trigger a temporary publication suspension | `service.ts` `recordProhibitedAttempt`/`isSuspended`; test §21 |
| **Published contact / operator ability to act** | Operator kill switches (disable publications/reactions, hide all, freeze entity, private-notes-only) + entity deactivation | `routes/admin.ts`; `settings.ts` |
| **No mechanism to encourage abuse** | No leaderboards, no scalar human ratings, no popularity/engagement ranking, no trending — by design | `policy.ts` (dish-only scalar); `service.ts` `feed()` (published_at ordering only) |

### Anonymity vs accountability

The community stores **no author field**, yet the store requirements are still met: filtering is
pre-publication and fail-closed; flagging + automatic re-evaluation remove bad content; and
author-side restriction works on the account (via unlinkable attempt counters) **without** ever
linking a published post to an identity. This is the intended reconciliation of App A §17
(anonymity) with §21 (abuse restriction) — accountability is applied to *publication attempts*,
not to *published posts*.

### Outstanding before submission

- Age rating / content descriptors set in App Store Connect and Play Console (operational, not code).
- A published moderation/EULA statement in-app (Settings → Experiences & privacy carries the data
  boundary; a short "community rules + how to report" screen should be linked there for the
  submission).
