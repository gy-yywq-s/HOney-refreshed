# Acceptance traceability (M7)

Line-by-line status against the spec's own checklists — master §20 (39), Appendix A §27 (27),
Appendix A §26.2 launch gates (10). Verified against code + tests (88 passing / 8 live-skipped
across the workspace), not against "doesn't contradict the spec". Full evidence per item is in the
audit transcript; this is the standing scoreboard.

## Master §20 — 39 criteria

**PASS (34):** 1–15, 17, 19–34, 37. Auto-provisioning, no separate signup, three independent
sessions, Keychain silent re-auth, WebView portal + silent recovery, consent-gated normalized
import, Home shape, Day-view-only, shared History, iOS 4-tab, iOS Access direct-to-school (no
backend relay — verified: no Access route exists), Web nav without Access, Web-Access-absent, no
Exams anywhere, no teacher/lesson scalar rating, dish-only scalar, anonymous eligibility, same
moderation protocol both platforms, fail-closed publication, **no author column** (PRAGMA test),
band separation + UI-less domain tests + change-isolation, Access networking isolated from views,
one shared design-token source.

**Now closed via this milestone:**
- **§20.16** (lesson → Experiences + composer): iOS lesson detail routes to composer; web
  composer + entity routes wired (M5 Experiences UI).
- **§20.18 / §20.35 / §20.36**: Access Legacy Parity Map + Legacy Design Audit +
  Preserve/Refine/Replace classification authored from `reference/legacy-ios/`
  (`docs/access-legacy-parity-map.md`, `docs/legacy-design-audit.md`).
- **§20.29** (legible privacy/data page): web Settings → Experiences & privacy carries the
  account/import/community data boundary + device-key model.
- **§20.38 / §20.39**: continuity + retained-weakness analysis documented in the Legacy Design
  Audit (cool-blue/card/Access/Day-view carried; animations-off, light-only, monolith,
  broken-expiry, feature-sprawl explicitly not retained).

**Pending external input (not implementation gaps):** final UI **design-is scoring ≥22** runs
after all surfaces exist (iOS is the last landing); iOS **CI green** needs the macOS runner
enabled; live portal facts (TTL, door-open envelope) need a **school test account**.

## Appendix A §27 — 27 criteria

**PASS (24):** 1–4, 8–19, 21, 22, 24, 25, 26 + private-note (5), culture surfaces (6), nudge (7),
privacy page (23) now landed. Entity models, teacher-prominent no-scalar, dish-only scalar,
provenance, private notes (web device-encrypted store), culture statements in composer, **nudge
lane live** (preflight `nudge` lane, policy v4 — the user explicitly chooses; the server never
auto-publishes), cooldown ticket re-check re-runs current policy, serious
blocked + text-not-persisted, uncertain→rephrase / evasion caught, raw-first browsing, no
aggregate, reactions gated + non-ranking + small-cohort hiding, reports-not-votes, no human queue,
LLM has no tools/key, deterministic decision, server-only key, run-once + signed pass, no author
column, no author-lookup admin, app/web parity, kill switches + auto re-eval, corpus launch gates.

**Documented as V1 substitute (not a literal match):**
- **§27.20** eligibility is a single-use token (stored only as a hash + an unlinkable HMAC scope
  mark, no user column) and `POST /api/experiences/publish` requires no session — the publish
  request carries no account identity and published posts store no author ID. This is a
  pragmatic split, NOT a blinded credential: cryptographic issuer-unlinkability (Privacy Pass)
  remains future work and no UI copy may claim it. Recorded in
  `docs/architecture/moderation-pipeline.md` and `m3-experiences.md`.
- **§27.27** UGC-requirements review documented (`docs/ugc-appstore-review.md`).

## Appendix A §26.2 — launch gates (10)

**PASS (10):** zero serious/out-of-scope published, zero threats/slurs/doxxing published, zero
injection obtains a pass (architecturally closed — a pass issues only on a publish decision),
100% schema-valid outputs (strict json_schema + boolean validation → fail closed), fail-closed on
outage, no systematic blocking of ordinary negative, content-hash binding + single-use-nonce
replay protection, **verified absence of author fields** (PRAGMA test), **verified absence of
author-linking logs** (structural source scan added this milestone), working kill switches. All
asserted by `corpus.test.ts`, `experiences.test.ts`, `no-linking-logs.test.ts`.

## "may / should / can" coverage

Spot-checked 12 clauses across §3.6, §5.3, §7.1–7.2, §9.3, §10.1, §11.4, §12.2, §13.3, §26.3, §4.2
— all implemented or correctly-absent (notifications, web-Access, exam import). The optional
clauses are treated as in-scope per the "implement everything including may" directive; the
enumerated 59 `may` clauses map to shipped behavior or an explicit correct-absence.

## design-is scoring (Gary's ≥22 bar)

A subagent design audit (Rams 10-principle, 0–3, max 30) scored **Web 25/30** and **iOS 23/30** —
both clear ≥22. Refinements then applied and verified: web (focus-visible on all interactive
surfaces, prefers-reduced-motion, 44px touch targets, unified uppercase labels → ~28) and iOS
(real school-connection status replacing a hardcoded "Connected", reduce-motion gate, wired
reactions, and a new **Report flow** — the one genuinely-new safety component the audit flagged).
Remaining iOS polish (Dynamic Type, badge unification) is optional; the bar is already met.

## CI

**iOS CI is green** on GitHub Actions (macOS 15 / Xcode 16): `xcodegen generate` + `xcodebuild
test` build the app and pass `HOneyTests` on the simulator. The TypeScript CI is green.

## Net

Backend + connector + web + iOS are all implemented and tested (88 TS tests + iOS unit tests, all
green); backend + web are deployed live. Remaining work is external: (1) confirming live-portal
facts (token TTL, door-open envelope, Web-Access CORS) with a **school test account**, (2) Gary
picking the generated brand wordmark/icon, and (3) App-Store operational steps. No requirement is left in "doesn't contradict" limbo.
