# Acceptance status — multi-axis (truth reset 2026-09-01)

Per-item status against the spec's own checklists — master §20 (39), Appendix A §27 (27),
Appendix A §26.2 launch gates (10) — reported on independent axes instead of one binary PASS.
"Doesn't contradict the spec" counts for nothing on any axis.

**Axes**

| Axis | Meaning | Current baseline |
|------|---------|------------------|
| **Code** | implemented on `build/v1` | @ `c2f03b8` (main/prod pinned at `8158966` until A6) |
| **Tests** | asserted by green automated tests | TS 127 pass / 23 live-skipped (backend 97, connector 17, web 10, shared 3) + iOS `HOneyTests` in CI |
| **Live** | verified against the real portal or production | portal facts confirmed 2026-09-01 with the school test account |
| **UI** | surface exists in the approved (legacy) design and passed design-is ≥22 | **RED — in flight**: legacy wholesale port not landed; prior scores were for the rejected UI |

## Honest framing of the moderation claims

The launch gates are properties of the **versioned critical regression suite**, not of the world.
What is asserted and tested: **zero misses in the versioned regression corpus (75 balanced
bilingual rows, policy v4)** — no serious/out-of-scope or threat/slur/doxxing row publishes, no
injection row obtains a pass, outputs are 100% schema-valid or the pipeline fails closed — plus
structural tests: no author column (PRAGMA), no author-linking logs (source scan),
content-hash + single-use-nonce pass binding, working kill switches.

**No claim is made that zero serious content can ever publish.** A phrasing outside the corpus
can be missed by the classifier. The residual-risk posture is: fail-closed defaults, the
report → automatic re-evaluation path (outage hides reported posts), admin kill switches, and
growing the corpus with every observed miss (each miss becomes a permanent regression row).

Known open moderation bug: **Task #15** — the lexicon squeezed-token pattern lacks word
boundaries, hard-blocking a few benign words (false positives). Fix + must-not-false-positive
corpus rows are in flight on `build/v1`.

## Master §20 — 39 criteria

- **Code+Tests green (39/39):** all items implemented and test-asserted, including
  auto-provisioning without separate signup, three independent sessions, Keychain silent
  re-auth, WebView portal with silent session recovery (`ce602b3`), consent-gated normalized
  import, Home shape, Day-view-only timetable, shared History, iOS 4-tab, iOS Access
  direct-to-school (no backend relay), Web nav without Access, no Exams, no teacher/lesson
  scalar rating, dish-only scalar, anonymous eligibility, same moderation protocol on both
  platforms, fail-closed publication, no author column, band separation with UI-less domain
  tests, Access networking isolated from views, one shared design-token source, lesson→composer
  routing, legacy parity/design continuity docs, legible privacy page, continuity +
  retained-weakness analysis.
- **Live green:** login `schema/{token}`, session TTL ≈ 24 h, timetable import normalized
  (126 lessons, 4 requests), empty-body sync fixed, admin binding at provisioning — all
  verified against the real portal 2026-09-01. Web-Access CORS probe **failed** → Web Access
  stays capability-gated OFF (correct absence per §20).
- **UI red:** §20.18/.35/.36 (legacy continuity) are now governed by the 2026-09-01 decision —
  the UI reproduces the legacy design wholesale (iOS port + full Web parity incl. mobile
  optimization). Until that lands and is re-scored, the UI axis is not accepted.

## Appendix A §27 — 27 criteria

- **Code+Tests green (27/27)** after the P0 rework: three-call
  `eligibility → check → publish`; **check persists nothing** (no draft stored before
  moderation; rejected/uncertain/failed-closed text never touches disk); the **nudge is a real
  user choice** (server never auto-publishes); first-class private notes (web; iOS in flight —
  see below); category-only reports (never free text, never votes); stateless HMAC cooldown;
  entity models, provenance, raw-first browsing, no aggregates, gated non-ranking reactions,
  no human queue, tool-less LLM, deterministic decision layer, server-only key, run-once +
  signed pass, no author column, no author-lookup admin, kill switches + auto re-eval.
- **§27.20 — documented V1 substitute, not a literal match:** the publish request carries **no
  account identity** and the eligibility token is stored only as a hash + an unlinkable
  HMAC scope mark (no user column). This is a pragmatic split, **not a blinded credential**:
  cryptographic issuer-unlinkability (Privacy Pass style) remains future work and no UI copy
  may claim it. Recorded in `docs/architecture/moderation-pipeline.md`.
- **iOS pending (in flight):** first-class private notes, draft-preserved-before-check,
  two-step default-unselected consent, ownership keys surviving ordinary sign-out — the iOS P0
  batch. Until it lands, §27.5 and the consent/draft clauses are **web-only green**.
- **§27.27** UGC-requirements review documented (`docs/ugc-appstore-review.md`).

## Appendix A §26.2 — launch gates (10)

**Suite-green (10/10)** under the honest framing above: every gate is asserted by
`corpus.test.ts`, `experiences.test.ts`, and `no-linking-logs.test.ts` against the versioned
corpus and the structural properties. These are regression-suite guarantees + architectural
closures (a pass issues only on a publish decision; publication verifies signature, expiry,
single-use nonce, content-hash binding), **not** a claim of perfect future classification.

## "may / should / can" coverage

Spot-checked 12 clauses across §3.6, §5.3, §7.1–7.2, §9.3, §10.1, §11.4, §12.2, §13.3, §26.3,
§4.2 — implemented or correctly absent (notifications, web-Access, exam import). The optional
clauses are treated as in-scope per the "implement everything including may" directive; the
enumerated 59 `may` clauses map to shipped behavior or an explicit correct absence. Re-walk
scheduled as part of A6 line-by-line finish.

## design-is scoring (Gary's ≥22 bar)

The previous scores (Web 25→~28, iOS 23→~26) applied to the **rejected** new UI and are void.
After the legacy wholesale port (iOS) + full legacy parity incl. mobile optimization (Web)
land, every surface is re-audited via the design-is skill; the ≥22 bar and the
build-all-then-score sequence (project rule 8) still apply.

## CI

TypeScript CI green; iOS CI green on GitHub Actions (macOS 15 / Xcode 16: `xcodegen generate` +
`xcodebuild test`, `HOneyTests` on simulator); HOney-casing grep gate green (0 occurrences of
the forbidden mixed-case form).

## Net — what remains before acceptance

1. iOS P0 batch (consent two-step, draft preservation, private notes, ownership-key lifecycle)
   + legacy UI wholesale port.
2. Web full legacy parity + mobile-first optimization pass.
3. Task #15 lexicon false-positive fix + corpus rows.
4. design-is re-scoring of all surfaces (≥22), subagent code review, full monorepo tests,
   iOS CI, casing gate.
5. A6 line-by-line spec walk; then — only on Gary's go — fast-forward `main` and deploy.

Production (`honey.gaelisus.com`) still runs `8158966`; nothing above is deployed yet.
