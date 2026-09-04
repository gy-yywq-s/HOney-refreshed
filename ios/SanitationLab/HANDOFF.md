# Sanitation Lab — test handoff (for the Mac)

Branch: `lab/credential-image-sanitation`. Spec: *HOney Credential Image
Sanitation Prototype — Test Spec* (2026-09-04). Design note:
`docs/architecture/credential-image-sanitation.md`.

Everything under `ios/SanitationLab` and `ios/SanitationLabTests` is new; no
file of the HOney app was touched. The one server piece (the classifier route)
is already deployed on `integration/product-v2` and live at
`https://honey.gaelisus.com/community/v2/image/classify`.

This branch was written on Linux and has NOT been compiled. The first job is to
build it; expect small Swift fixes.

## 1. Build

```sh
git fetch && git switch lab/credential-image-sanitation
cd ios
brew install xcodegen            # once
xcodegen generate                # adds the SanitationLab + SanitationLabTests targets
open HOney.xcodeproj             # scheme: SanitationLab
```

Commit the regenerated `HOney.xcodeproj` on this branch. If Xcode complains
about a Swift line, fix it in place and commit — the fix is part of the test
result.

## 2. Unit + fixture tests (simulator, no network)

Scheme **SanitationLab**, ⌘U, or:

```sh
xcodebuild test -project HOney.xcodeproj -scheme SanitationLab \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -resultBundlePath /tmp/sanitation-lab.xcresult
```

What runs:

| test | what it proves | spec criterion |
|---|---|---|
| `RegionFinderTests` | label → value masking, label-adjacent value, label-without-value, names/dates never masked, long ids only on credentials, faces only on credentials, codes as a strong signal | §5, §9.4 |
| `FixturePipelineTests.testCleanImagesAreReturnedUnchanged` | CLEAN = original bytes | §9.1 |
| `…testSyntheticCredentialsAreSanitizedWithTheRightRegions` | every must-hide box ≥60 % covered, every must-keep box pixel-identical (JPEG noise allowed), no code decodes on the output, values don't read back, new encoding | §9.3, §9.7–9.9 |
| `…testEdgeAndRealCredentialsAreNeverReturnedClean` | the 4 edge + 28 real cards: outcome recorded; an expected credential never comes back CLEAN | §9.6 |
| `…testClassifierDownFallsBackToLocalSignals` | classifier unavailable → QR decides; nothing local → CLEAN, recorded | fail-closed |
| `…testDerivativeFitsTheEdgeBudget` | ≤768 px, ≤200 KB for all 46 | §6 |
| `LiveClassifierTests` | skipped unless `SANITATION_LIVE=1` (see §3) | §6, §9.2 |

The classifier is **stubbed from the manifest** here, so these measure Vision
+ masking only. Every credential run attaches `<id>-before`, `<id>-after` and
`<id>-record.json` to the xcresult (Report navigator → the test → Attachments),
plus `synthetic-credentials.txt` / `edge-and-real.txt` summaries with
detect/hide latencies per fixture.

Likely places a real run differs from what I could reason about on Linux — look
at these attachments first:

- `credential/student_card_angled` — Vision's per-range boxes on tilted text.
- `credential/student_card_zh`, `real/r06`, `real/r14` — 學號/学号 OCR; if the
  label and number come back as ONE line the labelled path is used, if as two
  lines the label-adjacent path is used. Either is fine; a `numberNotLocated`
  is the finding to report.
- Portraits that Wikimedia uploaders had already pixelated (`r03`–`r07`, `r13`,
  `r25`) — face detection may not fire; that is expected and recorded, not a
  failure (the pre-pixelated face is not readable anyway).
- `real/r22` (Dutch ID specimen): the MRZ lines should be masked as standalone
  long ids; check the name row survived.

## 3. Live classifier (network)

Same scheme, with the environment variable `SANITATION_LIVE=1` (Edit Scheme →
Test → Arguments → Environment Variables, or export it and run `xcodebuild
test` from a shell that has it). `LiveClassifierTests` sends all 46 derivatives
to the deployed route and asserts: ≤2 unavailable, ≥90 % right on the 37
definite fixtures, p90 ≤ 3 s. It attaches `live-classifier.txt` with every
verdict and latency. Server-side bench for comparison: 46/46 valid, 35/37,
p50 0.23–0.29 s, p90 0.6 s (Qwen3-VL 8B).

## 4. On the phone (spec §10 — the part only a phone can answer)

Run the **SanitationLab** app on an iPhone (automatic signing, personal team).

1. Home screen → *Choose a photo* → pick an ordinary photo → **Share**. Expect
   `Checking…` then `Ready.` — should feel like a normal 2–3 s submit or
   faster (the timing line under *Continue* says check/detect/hide ms).
2. Pick a photo of a real card (your own student card is the best test —
   it never leaves the phone except as the 768 px derivative for the one
   question, and nothing is stored server-side). Expect `Checking…` →
   `Processing your image… / Hiding sensitive parts.` with the dimmed
   preview → the sanitized preview + *Sensitive parts were hidden before
   sharing.* Check: portrait blurred, number and code masked, name and
   school still readable.
3. Something the pipeline cannot do (a card where the number is not labelled
   and is short, or a booklet cover): expect *We couldn't safely hide the
   sensitive parts in this image.* with **Try another photo** / **Remove
   image** — and never the original shown as ready.
4. ⋯ menu → **Run the test set** with *Use the live classifier* ON: all 46
   fixtures through the real route on the phone. The header shows
   `right/judged` and check p50/p90; each row shows outcome and
   check/detect/hide ms; tap a row for before/after and the record.
5. ⋯ menu → **Past runs**: every run's before/after/record is also written to
   the app's Documents (`sanitation-lab/<stamp>-<outcome>/`), reachable via
   Finder → iPhone → Files, or Xcode → Devices → download container.

Personal photos you want to keep as fixtures go in
`ios/SanitationLab/Fixtures/local/` — gitignored; never commit a real card.

## 5. What to send back

A short file `docs/status/credential-sanitation-run-<date>.md` on this branch:

```
Build: <Xcode version>, fixes needed: <list or none>
Unit/fixture tests: <pass/fail counts>; attachments reviewed: <which ones looked wrong>
Live classifier: valid n/46, right n/37, p50/p90/max ms
Phone (<model, iOS>): clean photo <ms>, card photo <ms> check + <ms> hide, what was
  hidden, what survived, any wrong outcome (attach screenshots)
Failures / surprises: <fixture id → what happened>
```

Plus the `.xcresult` (or its exported attachments) somewhere I can read.

## 6. Out of scope here (spec §12)

No Lost & Found, no publication wiring, no name removal, no manual blur
editor, no storage beyond the lab's own Documents folder. The route stores
nothing and refuses cookies/bearers; the model sees the derivative only.
