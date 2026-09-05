"""Reconstruct the published fused YOLOv8s ONNX weights for Core ML export.

Use ultralytics==8.3.58, matching the ONNX metadata. A newer version failed
parity despite matching parameter names/shapes and is not acceptable here.
Conversion is accepted only after ONNX/PyTorch output parity. This does not
train, tune, or change model weights. Model artifacts belong outside git.
"""
from pathlib import Path
import json
import sys
import numpy as np
import onnx
from onnx import numpy_helper
import onnxruntime as ort
import torch
from ultralytics.nn.tasks import DetectionModel
import coremltools as ct

source, destination = map(Path, sys.argv[1:3])
torch.set_num_threads(4)
net = DetectionModel("yolov8s.yaml", nc=1, verbose=False).eval().fuse(verbose=False)
graph = onnx.load(str(source))
weights = {p.name: numpy_helper.to_array(p).copy() for p in graph.graph.initializer}
state = net.state_dict()
missing = [k for k in state if k not in weights]
if missing:
    raise RuntimeError(f"Missing weights: {missing}")
net.load_state_dict({k: torch.from_numpy(weights[k]) for k in state}, strict=True)

class OutputOnly(torch.nn.Module):
    def __init__(self, model):
        super().__init__()
        self.model = model
    def forward(self, x):
        return self.model(x)[0]

wrapped = OutputOnly(net).eval()
x = np.random.default_rng(42).random((1, 3, 640, 640), dtype=np.float32)
session = ort.InferenceSession(str(source), providers=["CPUExecutionProvider"])
reference = session.run(None, {"images": x})[0]
with torch.no_grad():
    actual = wrapped(torch.from_numpy(x)).numpy()
error = float(np.abs(reference-actual).max())
np.testing.assert_allclose(actual, reference, rtol=2e-3, atol=2e-3)
net.info()
trace = torch.jit.trace(wrapped, torch.from_numpy(x))
converted = ct.convert(trace, inputs=[ct.ImageType(name="image", shape=x.shape, scale=1/255)],
                       outputs=[ct.TensorType(name="var_910")],
                       minimum_deployment_target=ct.target.iOS17,
                       compute_precision=ct.precision.FLOAT16)
converted.save(str(destination))
result = {"weightParameterCount": sum(p.numel() for p in net.parameters()),
          "onnxPytorchMaxAbsoluteError": error, "source": str(source), "destination": str(destination)}
destination.with_suffix(".conversion.json").write_text(json.dumps(result, indent=2))
print(json.dumps(result))
