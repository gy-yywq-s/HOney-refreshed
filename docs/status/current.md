# Current status — single source of truth for "where are we"

Updated: 2026-09-01 (start of the product-v2 pass, driven by
`docs/research/design-audits/repo-review-v3-2026-09-01.md`).

```yaml
integration_base: build/v1@52b49d6          # tagged review/build-52b49d6
main: main@09c9562                          # tagged review/main-09c9562
ios_donor: codex/ios-editorial-redesign@585e35c   # tagged review/codex-ios-585e35c
working_branch: integration/product-v2      # all product-v2 work lands here
deploy_target: integration/product-v2       # honey.gaelisus.com tracks this (dev stage)
web_design_status: experimental_not_approved
ios_design_status: experimental_not_approved   # iOS UI is Gary's own track right now
cross_platform_convergence: deferred
preview/audit-p0: archived (tag archive/preview-audit-p0), historical only
```

## What "experimental_not_approved" means

Every currently-implemented UI — the main-iOS legacy port, the Codex quiet-editorial
iOS branch, and the Web editorial system on build/v1 — is **evidence, not a final
design**. Audit scores (e.g. the old "22/30 green") are quality evidence, never
product approval. Approval is a separate, owner-given state per platform
(`Web approved` and `iOS approved` are independent).

## Document hierarchy (which file wins)

0. `docs/product/product-and-style-constitution.md` — the single authority (2026-09-02).

1. `docs/product/*` — why / what the product is. Owner-approved product truth.
2. `docs/design/shared-product-design-invariants.md` — non-visual truths both
   platforms must respect.
3. `docs/design/web-lab.md`, `docs/design/ios-lab.md` — per-platform design
   hypotheses. Never binding on the other platform.
4. `docs/architecture/*` — implementation invariants.
5. `docs/status/*` — facts about a specific commit. Descriptive, not normative.
6. `docs/research/*` — audits and reviews: evidence + recommendation, with no
   automatic binding authority. Scope for new work comes from approved product
   docs, not from audit language.
7. `docs/superseded/*` — kept for history; each notes what superseded it.

Older docs that conflict with this hierarchy (`decisions-2026-09-01.md`,
`legacy-design-audit.md`, `design/legacy-port-map.md`, `design/web-style.md`)
are historical experiment records — see their headers.

## Web Access (2026-09-03)

Implemented per the 2026-09-03 spec Part II — `docs/architecture/web-access.md`. The Dash
switch is **OFF**; the failure-injection transcript is
`docs/status/web-access-failure-injection-2026-09-03.md` (11/11). The controlled real-gate
verification (§26.3: switch on → one confirmed open at a real gate → switch off, journal +
screenshot recorded here) is Gary's physical step and has **not** been done yet.

## iOS interop (2026-09-03)

`ios-web-port` @ `e2c889f` merges `integration/product-v2` (groups 1–4) and implements Anonymous
Control v2 + the canonical contract in Swift (`ios-web-port/HOneyCore/Sources/HOneyCore/CommunityV2/`;
`docs/architecture/anonymous-control-v2.md` § iOS). Interop evidence: the shared vectors,
`fixtures/blind-token-kat.json` (a Web-produced token the Swift verifier accepts) and the 43
contract fixtures pass in `swift test` on Linux (110 tests). The macOS lane compiles the app.
Deltas from the spec text for Gary: names are joined client-side (Community sends ids only);
reactions are gated by school membership, not exposure; pairing is by code (no QR); the iOS blind
client does its own modular arithmetic (swift-crypto cannot host the derived exponent); passkey
PRF wrappers cannot be created from iOS in this build.

## Recorded risk acceptances (dev stage)

- **Web HOney session tokens live in localStorage** (review v3 §12.15D wants
  HttpOnly cookies + CSRF). Accepted for the dev deployment — no real users,
  same-origin app. This is a PUBLIC-LAUNCH BLOCKER (acceptance §19 no.32):
  migrate to Secure/HttpOnly/SameSite cookies with refresh rotation before
  any public candidate, or re-record this acceptance with Gary's sign-off.
- **External moderation LLM without a verified no-retention tier** — see
  `docs/architecture/moderation-external-processing.md` (launch gate).
