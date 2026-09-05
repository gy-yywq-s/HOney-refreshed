# Offline signature and compute evaluation

These are evaluation tools, not production sanitation components. Never put
personal input images, derived previews, model weights or result bundles in
git. The `.swift.template` files are copied into standalone temporary projects
so their entry points cannot enter the SanitationLab test target.

## Models and runtime

- Small: `tech4ai/t4ai-signature-detect-server`, revision
  `c3b2b10baf2d8663e691cc8bd7de7fdc00d8b10b`,
  `signature-detection/models/yolov8s/1/model.onnx`.
  SHA-256: `f4c3e51b5aecfda1be1de12cb9b0960495029006a85e2b05334fb4d2a572403c`.
- Nano: `Thunderhead-exe/Hand-Signature-Extraction`,
  `app/model/yolo_v8n_finetuned_hand_signatures.pt`.
  Exported ONNX SHA-256 for this run:
  `e369a6289770bddfc3ca97d1096f65c285e7a1810837a9c94821ae2150a0dfd2`.
- Isolated runtime used: `/tmp/sanitation-signature-venv`; Python 3.13,
  ONNX Runtime 1.29.0, PyTorch 2.14.0, Core ML Tools 9.0.
- Nano exporter: Ultralytics 8.4.140. The older checkpoint also needs `dill`.
- Small model reconstruction **requires Ultralytics 8.3.58**, matching its
  original ONNX metadata. Newer code failed the numerical parity assertion
  despite accepting all parameter names and shapes. A separate target install
  at `/tmp/sanitation-ultralytics-8358` was selected with `PYTHONPATH`.
- Core ML Tools warns that PyTorch 2.14 is newer than its tested versions.
  Treat conversion checks as necessary, not proof of universal compatibility.

## Tools

- `signature_benchmark.py`: entire manifest plus optional private cases,
  stretch and letterbox variants, ONNX CPU timing, process CPU time and peak
  RSS. Default threshold 0.25, NMS IoU 0.5. Warm timings use a fixed input;
  no disk decode or blur is included. `resource.ru_maxrss` is interpreted as
  bytes on macOS; adjust the unit before using this script on Linux.
- `signature_crops.py`: explicit known-upright orientation and crop ablations.
  The hand-chosen document/field crops are not an automatic detector. If
  `document-boxes.json` exists, adds crops from the automatic rectangle probe.
- `document_probe.swift.template`: Apple Vision page rectangle detection.
  Copy to `.swift`, compile, then pass input image and output JSON paths.
- `convert_signature_small.py`: rebuilds fused PyTorch weights from ONNX,
  requires output parity, then exports a fixed 640×640 FP16 Core ML model.
- `coreml_benchmark.py`: separate-process Core ML CPU/CPU+NE/ALL runs; stores
  60 warm samples, first-prediction and load/compile time, process RSS, plus
  ONNX confidence comparison on the signature-field crop. These modes specify
  permitted compute units, not measured hardware utilisation percentages.
- `ComputeBenchApp.swift.template`: standalone offline iPhone benchmark for
  both compiled models. Records 60 warm predictions per mode, first prediction,
  load time, sampled physical footprint, thermal state and low-power mode.
  The app's `Documents/compute-results.json` is the output. It does not run
  the remote classifier or change the Lab app.

## Observed local paths

Private outputs are under `ios/SanitationLab/Fixtures/local/`:

- `signature-bench-small-4t`, `signature-bench-small-1t`, `signature-bench-nano-4t`
- `signature-crops`, `coreml-bench`

Standalone device build:

- Project: `/tmp/sanitation-compute-device/SanitationComputeBench.xcodeproj`
- App: `/tmp/sanitation-compute-build/Build/Products/Release-iphoneos/SanitationComputeBench.app`
- Bundle ID: `com.gaelisus.honey.sanitationcomputebench`

At the end of this evaluation the device app builds successfully, but the
iPhone is disconnected; there are no iPhone compute measurements yet.

The optional XCTest
`LocalSanitationEvaluationTests/testAutomaticPageCropSignatureBoxUsesProductionBlur`
loads locally generated boxes, asserts signature coverage/name separation,
and runs the actual rounded blur. It skips without private artifacts. This is
a signature-only test output, not a fully sanitized publishable passport.
