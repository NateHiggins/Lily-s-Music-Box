"""INERT nine-control distributions; no runtime or human qualification."""
import json
import sys
from collections import defaultdict
from pathlib import Path

run = Path(__file__).parent / sys.argv[1]
raw = json.loads((run / "render_attribution.json").read_text())
groups = defaultdict(list)
for row in raw["records"]:
    groups[row["phase"]].append(row)


def percentile(values, fraction):
    values = sorted(values)
    at = (len(values) - 1) * fraction
    low = int(at)
    high = min(low + 1, len(values) - 1)
    return values[low] + (values[high] - values[low]) * (at - low)


phases = {}
for name, rows in groups.items():
    phases[name] = {key: {"p50": percentile([row[key] for row in rows], .5),
                         "p95": percentile([row[key] for row in rows], .95),
                         "p99": percentile([row[key] for row in rows], .99),
                         "max": max(row[key] for row in rows)}
                    for key in ["wall_ms", "render_cpu_ms", "render_gpu_ms", "draw_calls", "primitives"]}
    phases[name]["pipeline_delta"] = {key: rows[-1]["monitors"][key] - rows[0]["monitors"][key]
                                       for key in rows[0]["monitors"]}
    print(name, " ".join(f"{key}={phases[name][key]['p50']:.3f}" for key in ["wall_ms", "render_cpu_ms", "render_gpu_ms", "draw_calls"]))
(run / "analysis.json").write_text(json.dumps({"evidence_class": "INERT", "phases": phases}, indent=2) + "\n")
