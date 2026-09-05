"""Core ML compute modes and conversion parity. All inference is local."""
from pathlib import Path
import argparse
import json
import resource
import time
import numpy as np
from PIL import Image
import psutil
import onnxruntime as ort
import coremltools as ct
from signature_benchmark import stats

p = argparse.ArgumentParser()
p.add_argument("--model", type=Path, required=True)
p.add_argument("--onnx", type=Path, required=True)
p.add_argument("--inputs", type=Path, required=True)
p.add_argument("--output", type=Path, required=True)
p.add_argument("--units", choices=["CPU_ONLY", "CPU_AND_NE", "ALL"], required=True)
args = p.parse_args()
process = psutil.Process()
baseline_rss = process.memory_info().rss
start = time.perf_counter()
model = ct.models.MLModel(str(args.model), compute_units=getattr(ct.ComputeUnit, args.units))
load_ms = (time.perf_counter()-start)*1000
load_rss = process.memory_info().rss
samples = []
for name in ["specimen", "passport-upright", "passport-display", "passport-document", "passport-region"]:
    image = Image.open(args.inputs / (name + ".png")).convert("RGB")
    start = time.perf_counter()
    prediction = model.predict({"image": image})["var_910"]
    elapsed = (time.perf_counter()-start)*1000
    samples.append({"name": name, "predictMs": elapsed, "maxConfidence": float(prediction[0, 4].max()),
                    "bestXYWH": prediction[0, :4, int(prediction[0, 4].argmax())].tolist()})
warm, cpu = [], []
for _ in range(60):
    start, cpu_start = time.perf_counter(), time.process_time()
    prediction = model.predict({"image": image})["var_910"]
    warm.append((time.perf_counter()-start)*1000)
    cpu.append((time.process_time()-cpu_start)*1000)
before_parity_peak = resource.getrusage(resource.RUSAGE_SELF).ru_maxrss
# Parity runtime allocated only after memory and timing measurements.
session = ort.InferenceSession(str(args.onnx), providers=["CPUExecutionProvider"])
reference = session.run(None, {session.get_inputs()[0].name: np.asarray(image, dtype=np.float32).transpose(2, 0, 1)[None]/255})[0]
result = {"model": args.model.name, "units": args.units, "loadAndCompileMs": load_ms,
          "firstPredictMs": samples[0]["predictMs"], "samples": samples,
          "warmPredictionMs": stats(warm), "warmPythonProcessCPUTimeMs": stats(cpu),
          "baselineRSSBytes": baseline_rss, "afterLoadRSSBytes": load_rss,
          "peakRSSBeforeParityBytes": before_parity_peak,
          "coremlOnnxConfidenceMaxAbsDiff": float(np.abs(prediction[0, 4]-reference[0, 4]).max()),
          "coremlOnnxBestConfidenceDiff": float(prediction[0, 4].max()-reference[0, 4].max())}
args.output.parent.mkdir(parents=True, exist_ok=True)
args.output.write_text(json.dumps(result, indent=2))
print(json.dumps({k: v for k, v in result.items() if k != "samples"}, indent=2))
