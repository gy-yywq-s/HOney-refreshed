# Credential sanitation: address and signature diagnosis

Date: 2026-09-05. Branch: `lab/credential-image-sanitation`.

## Finding and decision

The phone reports are correct. Both saved runs report `SANITIZED` and zero
readable values, despite visible sensitive content. The main defects are
field association, document orientation, and incomplete verification. They
do not demonstrate a need for a larger remote classifier.

Keep the existing remote cost ceiling and 4–5 second target. First repair
the fixed local pipeline. An independent signature detector is a candidate
for signatures without readable labels, but its benefit and iPhone latency
have **not** been validated in this evaluation. No production implementation,
server configuration, or phone installation was changed by this diagnosis.

## Evidence from the phone

The two most recent Lab runs were copied from the connected iPhone's Lab
Documents into the ignored `ios/SanitationLab/Fixtures/local/` directory.
Images and OCR remain local; none were sent to a model during this evaluation
or included in this report/commit. Values below are read from the original
phone records, not a fresh live benchmark.

| Case | Total | Classifier | Detection | Sanitation | Visible failure |
|---|---:|---:|---:|---:|---|
| Address, 10:42:12 | 2792 ms | 2574 ms | 525 ms | 172 ms | Only the second address line is blurred |
| Passport, 10:42:35 | 2754 ms | 2023 ms | 505 ms | 479 ms | Signature remains visible beside the large blur |

Classifier and detection overlap; columns must not be added together.
Two observations do not establish a latency distribution or an upper bound.

### Address: the first line can be skipped entirely

The phone record contains only the second line as the address region/value.
`nearestPersonalValueLine` compares Euclidean distances to the **centres** of
candidate boxes. A short continuation below the label can beat a long value
on the label's own row. `addressContinuationLines` then searches only below
the selected line; it never goes back to include the omitted first line.

A synthetic geometry counterexample reproduces this exact failure path. The
phone did not save its raw OCR lines, so this is a demonstrated mechanism
consistent with the phone result, not proof of its precise OCR segmentation.
The simulator reads the same image as one combined label/value line and does
not reproduce the phone's address miss with the baseline implementation.

Additional fragility: Chinese labels do not allow internal whitespace; line
grouping imposes fixed alignment/gap thresholds; field-boundary matching is
unanchored. These need explicit layout tests rather than more string examples
that assume ideal OCR segmentation.

### Signature: screen coordinates are not document coordinates

The passport's camera-oriented working bitmap is sideways (3024×4032).
Vision can read rotated text, but the finder discards text direction and
uses axis-aligned rectangles. `signatureFrame` always expands toward the
bottom of the displayed image, with dimensions derived from the label's
axis-aligned width and height. On rotated text this creates a huge rectangle
in the wrong direction. The phone did find a signature label; its resulting
1058×1655 pixel mask misses the actual ink.

The orientation ablation uses the same photo's known upright pixel storage
(4032×3024) and the unchanged detector/finder/blur. Visual inspection confirms
the signature is then hidden. This proves that orientation matters; simply
ignoring EXIF is **not** a general orientation solution. Document direction
must be inferred and coordinates mapped back to the displayed original.

There is still no independent signature-ink detector. Without a recognised
label, the current code has no general way to find a signature.

### Other defects exposed by the passport

- A bilingual label such as `出生地点/Place of birth` is parsed as a Chinese
  label with the English translation as its value. The translation is blurred
  while the actual birthplace below remains visible. A synthetic test confirms
  this error. OCR spelling errors add another source of missed labels.
- The pale secondary portrait remains visible in the upright experiment.
  Earlier success on the Dutch specimen does not generalise to this passport.
- The existing signature mask extends excessively; covering the signature in
  the orientation ablation does not make its geometry suitable for shipping.

### Why verification incorrectly passes

`valuesStillReadable` considers only values already selected for redaction,
and only OCR lines intersecting their selected regions. It cannot discover
an omitted field or a signature with no text value. It also concatenates a
multi-line address into one region value, then tests whether **one** output
OCR line contains that entire concatenated value. A readable single line can
therefore escape verification. This is covered by a deterministic test.

The low review rate previously reported is not evidence of complete privacy
coverage: this mechanism can produce falsely reassuring `SANITIZED` results.

## Experiments and results

Final selected test run: **18/18 passed** (16 existing field tests, 2 diagnostic
tests). These diagnostic tests deliberately demonstrate baseline defects and
evaluate a limited hypothesis; they are not a claim that production is fixed.

| Experiment | Result | Limit |
|---|---|---|
| Separate address label + first row + shorter continuation | Baseline skips first row; evaluation helper covers both | Synthetic geometry, not recovered phone OCR |
| Real address with same-row-first grouping and bounded continuation | Both lines covered; name preserved; separate ID row not absorbed into address block | One real image, simulator OCR |
| Same passport with document upright | Signature hidden using existing blur | Other sensitive fields/secondary portrait still fail |
| Partial multi-line value left readable | Baseline verifier returns no leak | Confirms a verifier defect |
| Bilingual birthplace label | Baseline selects translated label, misses actual value | Confirms a field-parser defect |
| Rotated signature-label rectangle | Baseline expansion misses the side where the ink belongs | Confirms geometry dependence |

An initial address expansion experiment overgrew into the ID row. It was
rejected during visual inspection, its gap bound tightened, and an explicit
boundary assertion added. One initial counterexample used geometry that did
not trigger the suspected path; adjusting the continuation height to exercise
the actual selection condition reproduced it. These changes are test-only.

Evidence:

- Final bundle: `/tmp/sanitation-diagnosis-verified-20260905.xcresult`
- Final log: `/tmp/sanitation-diagnosis-verified-20260905.log`
- Private before/after, OCR, region JSON: `ios/SanitationLab/Fixtures/local/20260905-104212/`
  and `ios/SanitationLab/Fixtures/local/20260905-104235/`
- Private summary: `ios/SanitationLab/Fixtures/local/evaluation-summary.json`
- Test harness: `ios/SanitationLabTests/RegionFinderTests.swift`, class
  `LocalSanitationEvaluationTests`. The image experiment skips if private
  fixtures are absent. It uses no remote classifier.

## Cost and latency: what is and is not established

- **Remote inference cost:** proposed field/orientation fixes require no
  additional remote calls. Keeping the same derivative and classifier gives
  the same request workload, approximately **1× current remote cost**. The
  route/records expose no token usage or billed amount, so an absolute currency
  cost cannot be established from these records.
- **Address grouping:** measured incremental rule execution was about
  **0.57–1.19 ms on the Mac-hosted simulator** across the observed runs. This
  is only grouping time, not the cost of blur or new orientation detection.
- **Orientation:** correcting document direction improved signature coverage,
  but the experiment supplied the known upright orientation. Automatic
  direction detection and mapping overhead still require measurement.
- **Simulator limits:** passport local processing varied from roughly
  4.3–4.6 seconds in the initial run to 18–22 seconds in the final run. A
  separate run had a roughly 937-second wall-clock stall. The reason for the
  stall was not established. These are unsuitable as iPhone latency forecasts;
  none should be silently excluded to claim a hard gate passed.
- **Actual hard gate:** the existing 4.8-second checks are admission checks
  around some work, not cancellation of running Vision/render operations.
  The pipeline awaits local detection without an enforced deadline; task-group
  cancellation also waits for child tasks to finish. Current code therefore
  does not prove an unconditional ≤5-second bound. A bounded best-guess return
  path and a monotonic clock need explicit tests.
- **Dedicated local signature model:** adds model size, local compute and
  energy, not inherently another paid API request. This evaluation did not
  produce a usable on-device benchmark. Do not raise the latency/cost ceiling
  on the assumption that this model will solve the problem.

## GitHub projects worth borrowing from

These are implementation candidates, not certified replacements for the Lab.

| Project | Useful part | Fit and validation status |
|---|---|---|
| [Presidio image redactor](https://github.com/data-privacy-stack/presidio/tree/main/presidio-image-redactor) | OCR → sensitive text → source bounding boxes; custom recognisers; independent source-box matching | Borrow text-to-box contracts and test methods. Its Python text-redaction pipeline is not a general signature detector or a drop-in Swift component. [Box utilities](https://github.com/data-privacy-stack/presidio/blob/main/presidio-image-redactor/presidio_image_redactor/bbox.py) |
| [PaddleOCR document orientation](https://github.com/PaddlePaddle/PaddleOCR/blob/main/docs/version3.x/module_usage/doc_img_orientation_classification.en.md) | Separate 0°/90°/180°/270° document classifier, PP-LCNet, documented 7 MB model | Strong match for a simple model task preceding a richer fixed pipeline. Apache-2.0 repository. Published timings are from server hardware, not an iPhone; conversion/device tests remain open. |
| [tech4ai signature detector](https://github.com/tech4ai/t4ai-signature-detect-server) | Dedicated signature boxes, ONNX inference/preprocessing, benchmarking | More relevant than asking the credential classifier for detailed fields. Repository wrapper is Apache-2.0, but the [published model](https://huggingface.co/tech4humans/yolov8s-signature-detector) is labelled AGPL-3.0; do not infer model terms from wrapper terms. |
| [Hand-Signature-Extraction](https://github.com/Thunderhead-exe/Hand-Signature-Extraction) | Small YOLOv8n signature detector with downloadable weights | Retrieved the approximately 12.4 MB checkpoint, but could not run it because the temporary PyTorch dependency download repeatedly failed. Repository states MIT; underlying model/dependency terms still need checking before reuse. |
| [mdefrance signature-detection](https://github.com/mdefrance/signature-detection) | Signature detector comparisons and YOLOS alternative | Its [YOLOS model card](https://huggingface.co/onnx-community/yolos-base-signature-detection-ONNX) states Apache-2.0. Worth comparing if terms of the YOLO candidate are unsuitable; not benchmarked here. |

Model test attempts were local-only. Hugging Face model downloads returned
401; the alternative public GitHub ONNX download stopped at approximately
10.8 of 44.6 MB. PyTorch installation failed with partial-download/proxy
errors, including on a direct-network retry. Thus **no open-source signature
model success rate or latency was measured**. No private image was uploaded
to a demo site. The temporary incomplete model/runtime files remain in `/tmp`.

## Proposed fixed pipeline

1. Establish document coordinates, preserving a transform back to the original.
   Use OCR direction or a small dedicated orientation classifier; avoid four
   full-resolution OCR passes as the default.
2. Run the existing coarse remote credential question concurrently with bounded
   local face/code/text detection. Preserve the unconditional face policy.
3. Build rows and columns. Parse bilingual label spans as labels, associate all
   same-row value fragments first, then group continuation rows until the next
   field in that column. Track every fragment independently.
4. Locate signatures as graphical objects with a separately validated local
   detector. A label-based fallback must follow document direction and stop at
   real field boundaries. A missing label must not imply no signature exists.
5. Apply the same rounded blur to every sensitive region, with coverage margins
   that account for the rounded corners.
6. Verify against independent field/ink coverage obligations and per-line
   residual text, not just concatenated values from the selected masks. Keep
   best-guess output plus explicit review for unresolved obligations.
7. Measure on the iPhone with both saved cases and negative/rotated/unlabelled
   controls before adoption. Report omission and over-blur separately; require
   complete target-field coverage as well as latency and remote-cost gates.

Recommendation: **do not trade away the current budget yet**. There is verified
evidence for fixing the local logic first. Whether a dedicated signature model
earns any additional latency budget remains an unanswered empirical question.
