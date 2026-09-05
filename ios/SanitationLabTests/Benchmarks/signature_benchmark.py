"""Offline signature-detector evaluation; never sends fixture images anywhere.

ONNX preprocessing matches tech4ai's published stretch/RGB/640 contract.
Optional letterboxing tests the usual aspect-preserving alternative separately.
Outputs containing private fixtures must be written under Fixtures/local.
"""
import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import resource
import time

import numpy as np
from PIL import Image, ImageDraw, ImageOps


def percentile(values, q):
    return sorted(values)[max(0, math.ceil(len(values) * q) - 1)]


def stats(values):
    return {"n": len(values), "p50": percentile(values, .5),
            "p90": percentile(values, .9), "max": max(values)}


def prepare(image, edge=640, letterbox=False):
    w, h = image.size
    if letterbox:
        scale = min(edge / w, edge / h)
        nw, nh = round(w * scale), round(h * scale)
        dx, dy = (edge - nw) // 2, (edge - nh) // 2
        canvas = Image.new("RGB", (edge, edge), (114, 114, 114))
        canvas.paste(image.resize((nw, nh), Image.Resampling.BILINEAR), (dx, dy))
        mapping = (scale, scale, dx, dy)
    else:
        canvas = image.resize((edge, edge), Image.Resampling.BILINEAR)
        mapping = (edge / w, edge / h, 0, 0)
    tensor = np.asarray(canvas, dtype=np.float32).transpose(2, 0, 1)[None] / 255
    return np.ascontiguousarray(tensor), mapping


def boxes_from_raw(raw, mapping, threshold=.25):
    pred = np.asarray(raw).squeeze().T
    sx, sy, dx, dy = mapping
    rows = pred[pred[:, 4] >= threshold]
    rows = rows[np.argsort(-rows[:, 4])]
    kept = []
    for x, y, w, h, score in rows:
        box = np.array([(x-w/2-dx)/sx, (y-h/2-dy)/sy,
                        (x+w/2-dx)/sx, (y+h/2-dy)/sy], dtype=float)
        if any(iou(box, k["box"]) > .5 for k in kept):
            continue
        kept.append({"box": box.tolist(), "score": float(score)})
    return kept


def iou(a, b):
    ix = max(0, min(a[2], b[2])-max(a[0], b[0]))
    iy = max(0, min(a[3], b[3])-max(a[1], b[1]))
    intersection = ix * iy
    union = max(0, a[2]-a[0])*max(0, a[3]-a[1]) + max(0, b[2]-b[0])*max(0, b[3]-b[1])-intersection
    return intersection / union if union else 0


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--model", type=Path, required=True)
    p.add_argument("--fixture-root", type=Path, required=True)
    p.add_argument("--output-dir", type=Path, required=True)
    p.add_argument("--threads", type=int, default=4)
    p.add_argument("--runs", type=int, default=30)
    p.add_argument("--edge", type=int, default=640)
    args = p.parse_args()
    args.output_dir.mkdir(parents=True, exist_ok=True)
    import onnxruntime as ort
    options = ort.SessionOptions()
    options.intra_op_num_threads = args.threads
    options.inter_op_num_threads = 1
    options.enable_mem_pattern = True
    rss_before = resource.getrusage(resource.RUSAGE_SELF).ru_maxrss
    load_start = time.perf_counter()
    session = ort.InferenceSession(str(args.model), sess_options=options, providers=["CPUExecutionProvider"])
    load_ms = (time.perf_counter()-load_start)*1000
    input_name = session.get_inputs()[0].name
    manifest = json.loads((args.fixture_root / "manifest.json").read_text())
    cases = [(item["id"], args.fixture_root / item["file"], False) for item in manifest["items"]]
    for folder in ["20260905-104212", "20260905-104235"]:
        path = args.fixture_root / "local" / folder / "before.jpg"
        if path.exists():
            cases.append(("private/" + folder + "-upright-storage", path, False))
            if folder.endswith("104235"):
                cases.append(("private/" + folder + "-display-oriented", path, True))
    results = []
    first_predict_ms = None
    for case, path, apply_exif in cases:
        image = Image.open(path)
        if apply_exif:
            image = ImageOps.exif_transpose(image)
        image = image.convert("RGB")
        for letterbox in [False, True]:
            start = time.perf_counter()
            tensor, mapping = prepare(image, args.edge, letterbox)
            prepared = time.perf_counter()
            raw = session.run(None, {input_name: tensor})[0]
            predicted = time.perf_counter()
            boxes = boxes_from_raw(raw, mapping)
            done = time.perf_counter()
            inference_ms = (predicted-prepared)*1000
            if first_predict_ms is None:
                first_predict_ms = inference_ms
            entry = {"case": case, "mode": "letterbox" if letterbox else "stretch",
                     "width": image.width, "height": image.height,
                     "inferenceMs": inference_ms, "preprocessMs": (prepared-start)*1000,
                     "totalMs": (done-start)*1000, "boxes": boxes,
                     "maxConfidence": float(np.asarray(raw).squeeze()[4].max())}
            results.append(entry)
            if boxes or case.startswith("private/") or case == "real/r22":
                preview = image.copy()
                draw = ImageDraw.Draw(preview)
                for det in boxes:
                    draw.rectangle(det["box"], outline=(255, 0, 0), width=max(2, image.width//300))
                preview.thumbnail((1000, 1000))
                preview.save(args.output_dir / (case.replace("/", "_") + "-" + entry["mode"] + ".jpg"))
    # Warm inference samples use a fixed tensor, excluding disk decode and blur.
    latencies, cpu_times = [], []
    for _ in range(args.runs):
        wall, cpu = time.perf_counter(), time.process_time()
        session.run(None, {input_name: tensor})
        latencies.append((time.perf_counter()-wall)*1000)
        cpu_times.append((time.process_time()-cpu)*1000)
    result = {"model": args.model.name, "sha256": hashlib.sha256(args.model.read_bytes()).hexdigest(),
              "modelBytes": args.model.stat().st_size, "runtime": ort.__version__,
              "providers": session.get_providers(), "threads": args.threads, "edge": args.edge,
              "loadMs": load_ms, "firstPredictMs": first_predict_ms,
              "warmInferenceMs": stats(latencies), "warmCPUTimeMs": stats(cpu_times),
              "peakRSSBytes": resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
              "preModelPeakRSSBytes": rss_before,
              "metadata": session.get_modelmeta().custom_metadata_map, "results": results}
    (args.output_dir / "results.json").write_text(json.dumps(result, indent=2))
    print(json.dumps({k: v for k, v in result.items() if k not in ("results", "metadata")}, indent=2))
    print("Images with predictions:", sum(bool(r["boxes"]) for r in results), "/", len(results))


if __name__ == "__main__":
    main()
