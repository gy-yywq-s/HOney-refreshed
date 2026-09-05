# Local signature models: effect and compute evaluation

## Decision

There is now a successful **signature-only** chain on the reported passport:
known-upright image → automatic Apple Vision page rectangle → YOLOv8s signature
box → existing rounded blur. The handwriting is hidden and the name stays
untouched. The focused production-blur XCTest passed, and the output was
visually inspected. Automatic orientation and full-document privacy remain
separate, unresolved gates; this does not certify the complete sanitation flow.

The larger of the two tested signature models is the better candidate. Its
extra storage/compute is modest on the measured Mac, while the nano model
misses the signature at page scale and has substantially more false detections.
Neither should simply be added as an unrestricted full-image detector.

**Do not relax the remote-cost or 4–5 second limit yet.** No additional remote
request is needed. Validate the larger model on automatically located, oriented
document regions; reuse a loaded model and benchmark the whole pipeline on the
iPhone before adoption. The iPhone disconnected before installation, so that
last device gate is still open.

## Experimental scope

- Mac: Apple M1 Pro, 32 GiB unified memory.
- 46 manifest fixtures plus the two privately saved phone photos, with an extra
  displayed-orientation passport variant: 49 views × two resize policies =
  98 inferences per model. This is not 98 independent annotated examples.
- Stretch resize follows the original larger model's GitHub inference example.
  Aspect-preserving letterbox is evaluated separately. Both produce 640×640 RGB.
- Confidence threshold 0.25 and NMS IoU 0.5. Threshold was not optimised on
  this dataset. Published model metrics are not used as our test accuracy.
- All inference is offline. Private images, OCR and previews remain under
  ignored `Fixtures/local`; no image was uploaded to a public demo.
- No production pipeline code or phone Lab installation was changed.

## What succeeded and failed

| Input/approach | YOLOv8n nano | YOLOv8s small |
|---|---|---|
| Original passport, both display and known-upright orientations | Signature missed | Signature missed |
| Known-upright passport, manually cropped to page | Missed | Found, confidence about 0.74–0.76 |
| Known-upright passport, automatically detected page crop | Missed | Found with both crop candidates and both resize policies, confidence 0.74–0.81 |
| Hand-selected signature-field crop, stretch | Found, 0.65 | Found, 0.53 |
| Same narrow field crop, letterbox | Missed | Missed |
| Dutch specimen `real/r22` | Found in both resize policies | Found with letterbox, missed with stretch |
| `real/r24` printed handwritten signature | Missed actual signature / extra graphic detection in stretch | Found with both policies |

The automatic rectangle probe found two overlapping page candidates. Its
single measured cold call was **145 ms on the Mac**. Both candidates led to
correct signature boxes in the larger model. This is only one positive private
passport, not a broad success-rate estimate. Orientation was supplied by known
upright stored pixels, not inferred by this experiment.

The larger model produced detections on 4 of 98 views: `r22` letterbox, `r24`
both variants, and an incorrect lanyard/background region in `r21` stretch
(confidence 0.285). The nano model produced detections on 27 of 98 views,
including clear false detections on the calculator and background-face image.
Prediction count is **not** recall: the collection lacks complete signature
ground truth. These inspected examples show why a low-threshold unrestricted
detector cannot be assumed to improve privacy without damaging preserved text
or scenery. The two datasets/checkpoints differ, so the accuracy difference
cannot be attributed to model size alone.

The successful automatically cropped larger-model box was passed through the
actual `Sanitizer.sanitize` code. A dedicated test checks independently marked
ink coverage and name separation, then saves a signature-only rounded-blur
result. **1/1 focused XCTest passed**; visual inspection confirmed the ink
is hidden. Other information intentionally remains visible in that diagnostic
image, which is not a shareable sanitation result.

## Model size and arithmetic workload

| Model | Parameters | Arithmetic at 640×640 | ONNX FP32 | Core ML FP16 package on disk |
|---|---:|---:|---:|---:|
| YOLOv8n signature checkpoint | 3,005,843 | 8.1 GFLOPs | 12.24 MB | about 6.2 MB |
| YOLOv8s signature checkpoint | 11,125,971 | 28.4 GFLOPs | 44.62 MB | about 22.4 MB |

GFLOPs are the exporter's conventional model estimate, not measured hardware
operations or a required TOPS rating. One multiply-add convention and input
size matter when comparing these numbers. Peak activations, preprocessing,
shared system services and the existing Vision/blur work must be budgeted in
addition to weight size. A 22 MB model does not mean a 22 MB running process.

## Mac latency measurements

ONNX Runtime 1.29.0, CPU only; 30 sequential warm inferences on a fixed tensor:

| Model / CPU threads | Load | First inference | Warm p50 | Warm p90 | Warm max |
|---|---:|---:|---:|---:|---:|
| Nano / 4 | 37 ms | 56 ms | 38 ms | 40 ms | 42 ms |
| Small / 4 | 61 ms | 117 ms | 110 ms | 113 ms | 118 ms |
| Small / 1 | 59 ms | 371 ms | 349 ms | 360 ms | 372 ms |

Four CPU threads lower elapsed time but consume more summed CPU time: larger
model p50 was about 439 CPU-ms at 4 threads versus 348 CPU-ms at 1 thread.
Faster wall time is not automatically less battery/compute consumption.

Core ML FP16, 60 sequential predictions per configuration:

| Model / allowed compute | Load + compile | First prediction | Warm p50 | Warm p90 | Warm max |
|---|---:|---:|---:|---:|---:|
| Nano / CPU | 195 ms | 44 ms | 14.2 ms | 14.5 ms | 14.9 ms |
| Nano / CPU + Neural Engine | 932 ms | 12 ms | 4.3 ms | 4.4 ms | 4.6 ms |
| Nano / all | 768 ms | 32 ms | 4.0 ms | 4.3 ms | 4.4 ms |
| Small / CPU | 224 ms | 56 ms | 26.5 ms | 28.1 ms | 29.3 ms |
| Small / CPU + Neural Engine | 905 ms | 18 ms | 6.4 ms | 6.6 ms | 6.6 ms |
| Small / all | 830 ms | 37 ms | 6.2 ms | 6.6 ms | 6.6 ms |

These Core ML prediction measurements include passing an already decoded
640×640 PIL image into the prediction API; they exclude document localisation,
orientation, full-size decoding, blur and verification. ONNX warm times exclude
preprocessing too, so the runtime table is not a strictly identical workload
comparison. Core ML compute modes permit devices; they do not prove a measured
ANE/GPU utilisation percentage. See [Apple's compute-unit documentation](https://apple.github.io/coremltools/docs-guides/source/load-and-convert-model.html).

Load/compile measurements are per-process observations, not an OS-cache-cleared
cold-boot distribution. In particular, the roughly 0.8–0.9 second accelerator
setup is real work that must not be omitted from a cold user interaction.
Preloading on entry to photo selection and reusing the model is worth testing.

## Memory, power and device limits

- In Core ML `ALL` runs, measured Python process RSS rose by about **24 MB for
  nano / 44 MB for small after loading**; observed process peak above starting
  RSS was about **40 MB / 66 MB**. In CPU-only runs, peak increase was about
  **55 MB / 89 MB**. These are process observations, not isolated tensor memory.
- Baseline Python process RSS was already about 335–337 MB. The whole process
  peaked around 376 MB (nano ALL) / 402 MB (small ALL). Do not quote those as
  required iPhone app RAM. Shared Core ML service/accelerator memory is not
  fully accounted for by Python process RSS.
- The full-resolution ONNX fixture sweep reached about 380 MB (nano) / 522 MB
  (small) process peak. This includes image decoding/preview generation and
  retained allocator memory, not only the model.
- No dedicated GPU was required for the CPU tests. Hardware acceleration
  reduced measured warm latency substantially on the M1 Pro.
- **iPhone latency, physical footprint, energy, sustained thermal behaviour,
  low-power-mode behaviour and oldest acceptable device are unmeasured.**
  Mac results cannot establish an A-series performance guarantee or minimum
  RAM requirement. No joules-per-image or battery percentage is inferred.

The separate iPhone benchmark is built in Release mode and records model load,
first prediction, 60 warm predictions, sampled physical footprint, thermal
state and low-power mode for CPU/CPU+NE/ALL. It has its own bundle ID and does
not overwrite the Lab. Installation failed because the iPhone disconnected;
the final device check still reported it unavailable.

## Conversion integrity and reuse

Sources: [larger model and ONNX reference](https://github.com/tech4ai/t4ai-signature-detect-server),
[nano checkpoint](https://github.com/Thunderhead-exe/Hand-Signature-Extraction).

The original larger ONNX export declares Ultralytics 8.3.58. Reconstructing
its network with the newer library loaded all weights but **failed numerical
equivalence**, so that export was rejected. Repeating with 8.3.58 passed:
maximum ONNX/PyTorch absolute output difference on the fixed test tensor was
0.000519. This is why matching parameter names alone is insufficient.

FP16 Core ML conversion retained the useful detections on the tested crops.
On the field crop, maximum confidence-element differences versus ONNX were
0.0131 for nano ALL and 0.0063 for small ALL; threshold-near decisions still
need broader validation. The larger Core ML model reports 0.740 on the manual
page crop and 0.533 on the field crop. Conversion tooling warned that PyTorch
2.14 is newer than its tested range; successful limited checks are not a full
conversion qualification.

The larger downloaded model's embedded metadata and its
[published model card](https://huggingface.co/tech4humans/yolov8s-signature-detector)
declare AGPL-3.0. Repository wrapper licences are not a substitute for checking
weight/dependency terms. The nano repository states MIT, while the current
exporter stamps AGPL metadata on the generated model; do not treat that stamp
alone as a legal determination of the original checkpoint's terms. Reuse is
an evaluation candidate, not an approved product dependency.

## Budget recommendation

1. Keep the remote classifier at its existing one simple call. Local signature
   inference introduces no additional billed API request: remote workload can
   remain **approximately 1× baseline**, below the 3× ceiling. There is no
   token/billing data here to calculate an absolute per-image price.
2. Prefer the larger model on a correctly oriented page crop over unrestricted
   nano detection. On this Mac, the added warm compute versus nano is only a
   few milliseconds with Core ML, while its page-scale result is better.
3. Budget the larger FP16 package (~22 MB), load-time work and activation memory.
   Reuse a loaded instance; do not initialise it independently for each region.
4. Add no default four-way OCR/model loop. Automatic direction, document bounds,
   row/column grouping and field obligations should determine where a small
   number of local passes run. The address/parser/verifier defects described
   in the previous report still need their fixed-flow repairs.
5. Gate adoption on the connected iPhone's end-to-end cold and warm tests,
   including concurrent Vision work. Neither the current code nor these Mac
   tests prove the required whole-image ≤5-second bound.

The only demonstrated trade-off now is **package size and local resources for
better signature detection**, not a need to triple remote spend or raise the
latency limit. Evidence is sufficient to test this direction on the phone,
not to ship it or promise its full privacy coverage.

## Reproduction and artifacts

- Scripts and native templates: `ios/SanitationLabTests/Benchmarks/README.md`.
- Private measurements: `ios/SanitationLab/Fixtures/local/signature-bench-*`,
  `signature-crops`, `coreml-bench`.
- Blur test: `/tmp/sanitation-model-blur-20260906.xcresult` (1/1 passed).
- Device app: `/tmp/sanitation-compute-build/Build/Products/Release-iphoneos/SanitationComputeBench.app`.
- Build log: `/tmp/sanitation-compute-build-final.log` (`BUILD SUCCEEDED`).

The earlier failed downloads are resolved. New outstanding blocker: reconnect
and unlock the iPhone to collect actual device measurements.
