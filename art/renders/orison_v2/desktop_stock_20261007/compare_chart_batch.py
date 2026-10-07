"""Reproduce scalar/vector chart equivalence; run from the repository root."""
from pathlib import Path
import json, sys
import numpy as np

root = next(p for p in Path(__file__).resolve().parents if (p / 'game/project.godot').is_file())
sys.path.insert(0, str(root / 'art/blender/scripts'))
from fabrication_uvs import chart_for_triangle
from fabrication_chart_batch import triangle_charts

rng = np.random.default_rng(7719)
points = rng.normal(size=(2048, 3, 3)) * rng.uniform(.0001, 2, size=(2048, 1, 1))
origin = np.array([12.7, -8.4, 20.3])
grain = rng.random(2048) > .5
rotations = np.linalg.qr(rng.normal(size=(2048, 3, 3)))[0]
errors = []
for frames in [None, rotations]:
    ns, us, charts, fallback = triangle_charts(points, origin, .9, frames, grain)
    expected_fallback = 0
    maximum = 0.
    for i, triangle in enumerate(points):
        frame = np.eye(3) if frames is None else frames[i]
        n, u, uv, used_fallback = chart_for_triangle(triangle @ frame.T, origin @ frame.T, .9, grain[i])
        maximum = max(maximum, float(np.max(np.abs(charts[i] - uv))),
                      float(np.max(np.abs(ns[i] - frame.T @ n))),
                      float(np.max(np.abs(us[i] - frame.T @ u))))
        expected_fallback += used_fallback
    assert maximum < 1e-10, maximum
    assert fallback == expected_fallback
    errors.append({'rotated': frames is not None, 'triangles': len(points),
                   'maximum_absolute_error': maximum, 'fallbacks': fallback})
print(json.dumps({'evidence_class': 'INERT', 'passed': True, 'comparisons': errors}, indent=2))
