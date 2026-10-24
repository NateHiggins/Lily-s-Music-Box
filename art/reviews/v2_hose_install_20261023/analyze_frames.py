"""INERT diagnostic: distributions, not FPS averages or runtime qualification."""
import hashlib
import json
import math
import sys
from collections import defaultdict
from pathlib import Path

root = Path(__file__).parent
run = root / (sys.argv[1] if len(sys.argv) > 1 else "world_v5")
frames = json.loads((run / "frames.json").read_text())
checks = json.loads((run / "hose_checks.json").read_text())


def percentile(values, fraction):
    values = sorted(values)
    if not values:
        return None
    at = (len(values) - 1) * fraction
    lower = math.floor(at)
    upper = math.ceil(at)
    return values[lower] * (upper - at) + values[upper] * (at - lower) if upper != lower else values[lower]


def distribution(values):
    return dict(n=len(values), p50=percentile(values, .5), p95=percentile(values, .95),
                p99=percentile(values, .99), maximum=max(values, default=None),
                over_50=sum(v > 50 for v in values), over_100=sum(v > 100 for v in values))


groups = defaultdict(list)
excluded = []
previous = None
for index, row in enumerate(frames["samples"]):
    # Capture stalls can appear in the first sample after phase restoration.
    if row[0].startswith("capture_excluded_") or (previous and previous.startswith("capture_excluded_")):
        excluded.append(index)
    else:
        groups[row[0]].append(row)
        groups["ALL_NONCAPTURE"].append(row)
    previous = row[0]

phases = {}
for name, rows in groups.items():
    phases[name] = {column: distribution([row[index] for row in rows])
                    for index, column in enumerate(frames["columns"][1:6], 1)}
samples = frames["samples"]
monitors = {name: samples[-1][7][name] - samples[0][7][name] for name in samples[0][7]}
output = dict(evidence_class="INERT", scope="One installed route. No matched before/after or acceptance claim.",
              resolution=frames["resolution"], vsync=frames["vsync"], phases=phases,
              excluded_capture_sample_indices=excluded, pipeline_counter_deltas=monitors,
              residency_states=sorted({str(row[6]) for row in samples}),
              motion_call_ms=distribution([row["total_usec"] / 1000 for row in checks["motion_calls"]]),
              aim_error_degrees=distribution(checks["aim_errors_degrees"]),
              player_physics_profile_samples=len(frames["player_physics"]),
              largest_non_capture_frames=sorted(groups["ALL_NONCAPTURE"], key=lambda row: row[1], reverse=True)[:15],
              input_sha256={name: hashlib.sha256((run / name).read_bytes()).hexdigest()
                            for name in ["frames.json", "hose_checks.json"]})
(run / "analysis.json").write_text(json.dumps(output, indent=2) + "\n")
for name, data in phases.items():
    print(name, json.dumps(data["wall_ms"]))
print("motion_call_ms", json.dumps(output["motion_call_ms"]))
print("pipeline_counter_deltas", json.dumps(monitors))
