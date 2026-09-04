# Credential image sanitation run — 2026-09-04

Build: Xcode 26.4.1 (17E202), XcodeGen 2.45.4; iOS deployment target 17.0. `SanitationLab` built for an iPhone 16 simulator running iOS 26.4.1 and for a physical iPhone 16 Pro Max running iOS 26.5.2. Fixes needed: none; the Swift sources compiled on the first build. The regenerated `HOney.xcodeproj` is commit `4ef8b79`.

Unit/fixture tests: simulator 13 passed, 1 failed, 1 skipped (15 test methods total). The failed synthetic-credential method produced 24 assertion failures. The skipped method was the intentionally gated live test. Attachments reviewed: all nine synthetic before/after images and records, `synthetic-credentials.txt`, `edge-and-real.txt`, and focused before/after review of `real/r06`, `real/r14`, and `real/r22`.

Live classifier: valid 46/46, right 35/37, p50 1331 ms, p90 1963 ms, max 2846 ms. The two definite errors were false positives on `real/r09` and `real/r19`; no definite credential was classified clean. The live test passed all three assertions.

Phone (iPhone 16 Pro Max, iOS 26.5.2): device build, automatic signing, installation, and launch succeeded. A device XCTest run recorded 12 passed, 2 failed, and 1 skipped. Synthetic fixtures took 73–328 ms to detect and 147–444 ms to hide; edge/real fixtures took 64–365 ms to detect and up to 595 ms to hide. Clean photo and personal-card timings were not recorded because the phone owner took over the manual photo-picker/UI checks. After XCTest had repeatedly relaunched the test host, the clean non-test app was reinstalled and launched successfully. No personal card was added to the repository.

## Attachment review

The simulator run returned `SANITIZED` for every synthetic credential, but Vision reported zero faces and zero codes for all nine. In the resulting images only the recognised number was masked: portraits, QR codes, and barcodes remained visible. `credential/student_card_angled` also left the number visible because its detected number rectangle did not overlap the rotated ground-truth box. Names and school text remained readable in the simulator outputs, but some number masks intruded into the adjacent label boxes; the rotated card also changed a must-keep context box.

| Fixture | Simulator finding |
|---|---|
| `credential/student_card_qr` | Portrait and QR left visible. |
| `credential/student_card_barcode` | Portrait and barcode left visible; label region changed. |
| `credential/student_id_label_only` | Portrait left visible; label region changed. |
| `credential/student_card_zh` | Portrait and QR left visible; label region changed. |
| `credential/student_card_angled` | Portrait, number, and QR left visible; context region changed. |
| `credential/student_card_in_scene` | Portrait and QR left visible; label region changed. |
| `credential/library_card` | Barcode left visible; label region changed. |
| `credential/access_card` | QR left visible; label region changed. |
| `credential/staff_card` | Portrait and QR left visible; label region changed. |

For the real-card focus cases, `real/r06` masked the standalone number but added no new portrait blur; its uploaded portrait was already pixelated. `real/r14` masked the short labelled number but left the barcode visible in the simulator. `real/r22` masked `SPECI2014`; the simulator kept the name row but left both portraits visible. The bundled `real/r22` image is the front of the Dutch specimen and contains no MRZ lines, so the HANDOFF request to check its MRZ cannot be performed on this fixture.

No fixture whose manifest expectation was `SANITIZED` returned `CLEAN` in the stubbed offline test. The following expected credentials failed closed as `COULD_NOT_SANITIZE` instead of producing usable sanitized output: `real/r01`, `real/r04`, `real/r07`, `real/r13`, and `real/r25`. Several intentionally uncertain edge/real fixtures also failed closed.

The physical iPhone detected faces and codes that the simulator missed. It found a face and code on the full-size synthetic student cards and correctly made those regions non-readable, but the generated portrait frames covered only 30–45% of the declared portrait boxes. The small in-scene portrait was not detected. The rotated number still had 0% ground-truth coverage, and its code had only 45%. On `real/r22`, the phone detected both faces, but the main portrait frame expanded to 437 × 655 px and visibly intruded into the surname row, violating the requirement that the name survive.

## Failures / surprises

- The simulator/device detector discrepancy is large: simulator synthetic records contain `faces=0 codes=0`, while the phone usually detects the same full-size faces/codes. Simulator `SANITIZED` therefore does not mean the required sensitive regions were hidden.
- Portrait framing is not reliable on the phone: it under-covers synthetic portrait boxes, but over-expands on `real/r22` and obscures name text.
- Rotated OCR coordinates on `credential/student_card_angled` do not cover the actual number.
- The first shell-prefixed `SANITATION_LIVE=1 xcodebuild test` was still skipped by the Xcode 26 test host. Injecting `SANITATION_LIVE=1` into the booted simulator environment and rerunning only `LiveClassifierTests` produced the valid passing live result above.
- The device test runner exited with code 0 before completing `testCleanImagesAreReturnedUnchanged`, then restarted and completed the remaining tests. This is a test-runner failure, not evidence that the clean installed app crashes. The non-test app was reinstalled after testing and its launch was verified.

## Evidence

Local evidence directory: `/Users/GaryS/Documents/HOney-labs/credential-sanitation-artifacts-2026-09-04/`

- `simulator-attachments.zip`: exported before/after images, records, and simulator summaries.
- `device-attachments.zip`: exported physical-device before/after images, records, and summaries.
- `live-classifier.xcresult.zip` and `live-classifier.txt`: passing live test bundle and human-readable verdict/latency report.
- `synthetic-credentials.txt`, `edge-and-real.txt`, `device-synthetic-credentials.txt`, and `device-edge-and-real.txt`: compact per-fixture outcomes and timings.
- `final-regression.xcresult.zip`: updated 23/23 stable regression result.
- `dual-portrait-after.png`: visually reviewed output with both the main and pale secondary portraits blurred.

## Follow-up implementation

The prototype was updated after the first run from direct phone feedback:

- Face privacy no longer depends on credential classification. Every locally detected face is blurred; classifier-clean images with no face still return their original bytes.
- Face detection now combines original, contrast-enhanced, overlapping-crop and small-feature detector passes, then deduplicates overlaps. `real/r22` now detects and blurs both the main portrait and the pale secondary portrait without covering the name.
- Labelled address and continuation lines, birth date/place, sex/gender, nationality/citizenship, phone, email, guardian/parent/emergency contact, blood type, signature and MRZ are privacy regions. Names, school, class and validity remain visible.
- All region kinds now use the same strong Gaussian blur with adaptive rounded corners. Opaque grey number/code masks were removed.
- Post-blur OCR verification is region-aware, so the same word elsewhere on a card does not create a false leak. The short Chinese `出生：` label is covered.

Focused verification: 16/16 unconditional-face and region tests passed; 17/17 personal-detail/real-card regression tests passed; the dedicated main-plus-secondary portrait fixture passed and its output was visually reviewed. The final stable regression suite passed 23/23 tests, excluding only the live network test and the documented legacy synthetic aggregate. The old aggregate still reports legacy failures because its portrait ground truth expects 60% of the entire photo frame while the updated policy intentionally blurs the face, and the simulator still misses fixture barcodes that the physical phone detects. `credential/student_card_angled` also retains its pre-existing rotated number-coordinate failure.
