"""Ablation: fixed document/label crops, not an automatic crop detector."""
import json
from pathlib import Path
import sys
import time
import numpy as np
import onnxruntime as ort
from PIL import Image, ImageDraw, ImageOps
from signature_benchmark import prepare, boxes_from_raw

root, output, inputs = map(Path, sys.argv[1:4])
output.mkdir(parents=True, exist_ok=True)
inputs.mkdir(parents=True, exist_ok=True)
passport = Image.open(root / "local/20260905-104235/before.jpg").convert("RGB")
display = ImageOps.exif_transpose(Image.open(root / "local/20260905-104235/before.jpg")).convert("RGB")
specimen = Image.open(root / "real/r22.jpg").convert("RGB")
cases = {
    "specimen": specimen,
    "passport-upright": passport,
    "passport-display": display,
    "passport-document": passport.crop((900, 620, 3800, 2550)),
    "passport-region": passport.crop((2600, 1730, 3650, 2180)),
}
automatic = output / "document-boxes.json"
if automatic.exists():
    for index, item in enumerate(json.loads(automatic.read_text())["boxes"]):
        cases[f"passport-automatic-{index}"] = passport.crop(tuple(round(v) for v in item["box"]))
for name, image in cases.items():
    image.save(output / (name + "-input.png"))
    image.resize((640, 640), Image.Resampling.BILINEAR).save(inputs / (name + ".png"))
rows = []
for model in ["/tmp/sanitation-signature.onnx", "/tmp/sanitation-signature-nano.onnx"]:
    options = ort.SessionOptions()
    options.intra_op_num_threads = 4
    session = ort.InferenceSession(model, sess_options=options, providers=["CPUExecutionProvider"])
    for name, image in cases.items():
        for letterbox in [False, True]:
            tensor, mapping = prepare(image, letterbox=letterbox)
            start = time.perf_counter()
            raw = session.run(None, {session.get_inputs()[0].name: tensor})[0]
            elapsed = (time.perf_counter()-start)*1000
            detections = boxes_from_raw(raw, mapping)
            row = {"model": Path(model).stem, "case": name, "letterbox": letterbox,
                   "inferenceMs": elapsed, "maxConfidence": float(raw[0, 4].max()), "boxes": detections}
            rows.append(row)
            preview = image.copy()
            draw = ImageDraw.Draw(preview)
            for d in detections:
                draw.rectangle(d["box"], outline="red", width=max(2, image.width//300))
            preview.thumbnail((1000, 1000))
            preview.save(output / f"{Path(model).stem}-{name}-{letterbox}.jpg")
(output / "results.json").write_text(json.dumps(rows, indent=2))
print(json.dumps([{k: v for k, v in r.items() if k != "boxes"} | {"count": len(r["boxes"])} for r in rows], indent=2))
