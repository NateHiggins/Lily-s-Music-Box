"""Inspect an exported hose case without launching Godot.

Requires NumPy. Geometry-bound study only: no native collision, energy, skin,
runtime-contract or appearance acceptance is inferred from this calculation.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np


def analyze(path: Path, sweeps: int) -> dict:
    case = json.loads(path.read_text(encoding="utf-8"))
    points = np.asarray(case["result"], dtype=np.float32)
    lengths = np.asarray(case["lengths"], dtype=np.float64)
    spans = np.asarray(case["bend_spans"], dtype=np.float64)
    inverse = 1.0 / np.asarray(case["masses"], dtype=np.float64)
    inverse[-1] = 0.0
    planes = case["planes"]
    if points.shape != (lengths.size + 1, 3) or spans.size != lengths.size - 1:
        raise ValueError("Case does not contain a full final iterate")
    if not np.isfinite(points).all() or not np.isfinite(inverse).all():
        raise ValueError("Nonfinite case")

    def metrics() -> dict:
        errors = np.linalg.norm(np.diff(points, axis=0), axis=1).astype(float) - lengths
        bend = spans - np.linalg.norm(points[2:] - points[:-2], axis=1)
        penetration = max(
            (row["offset"] - np.dot(np.asarray(row["normal"], dtype=np.float32), points[row["ring"]])
             for row in planes), default=0.0,
        )
        result = {
            "maximum_interval_error_m": float(np.abs(errors).max()),
            "accumulated_length_error_m": float(errors.sum()),
            "bend_violation_m": float(max(0.0, bend.max())),
            "plane_violation_m": float(max(0.0, penetration)),
        }
        result["geometric_bounds_only"] = bool(
            result["maximum_interval_error_m"] <= 0.00002
            and abs(result["accumulated_length_error_m"]) <= 0.00002
            and result["bend_violation_m"] <= 0.00002
            and result["plane_violation_m"] <= 0.000001
        )
        return result

    before = metrics()
    rows = []
    for sweep in range(sweeps):
        for i in range(1, len(points) - 1):
            vector = points[i + 1] - points[i - 1]
            distance = float(np.linalg.norm(vector))
            if distance >= spans[i - 1]:
                continue
            if distance < 0.0000001:
                raise ValueError("Collapsed span needs the native material-direction hint")
            correction = vector / distance * (
                (spans[i - 1] - distance) / (inverse[i - 1] + inverse[i + 1])
            )
            points[i - 1] -= correction * inverse[i - 1]
            points[i + 1] += correction * inverse[i + 1]
        for row in planes:
            normal = np.asarray(row["normal"], dtype=np.float32)
            ring = row["ring"]
            depth = row["offset"] - np.dot(normal, points[ring])
            if depth > 0.0:
                points[ring] += normal * depth
        rows.append({"sweep": sweep + 1, **metrics()})
    return {
        "evidence_class": "INERT",
        "scope": "Float32 geometry replay; not Godot collision, energy or runtime acceptance.",
        "case": str(path), "before": before, "sweeps": rows,
    }


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("case", type=Path)
    parser.add_argument("--sweeps", type=int, default=4)
    args = parser.parse_args()
    if not 0 <= args.sweeps <= 16:
        parser.error("--sweeps must be between 0 and 16")
    print(json.dumps(analyze(args.case, args.sweeps), indent=2))
