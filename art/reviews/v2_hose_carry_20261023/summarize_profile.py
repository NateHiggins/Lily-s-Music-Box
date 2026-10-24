"""Summarize diagnostic call scopes and presented frames; scopes overlap."""
import collections
import json
import math
import pathlib
import sys


def distribution(values):
    values = sorted(values)
    if not values:
        return {"n": 0}
    return {"n": len(values), **{
        name: values[min(len(values)-1, math.ceil(p*len(values))-1)]
        for name, p in [("p50", .5), ("p95", .95), ("p99", .99), ("max", 1)]
    }}


root = pathlib.Path(sys.argv[1])
calls = json.loads((root / "fps_calls.json").read_text())
frames = json.loads((root / "frames.json").read_text())
summary = {}
for cycle in dict.fromkeys(row["cycle"] for row in calls["samples"]):
    samples = [row for row in calls["samples"] if row["cycle"] == cycle]
    rows = [row for row in calls["calls"] if row["cycle"] == cycle]
    wall = [row[1] for row in frames["samples"]
            if row[0] in (f"fps_hose_{cycle}_held", f"fps_hose_{cycle}_turning")]
    summary[cycle] = {
        "calls": len(rows),
        "progress_m": sum(row["progress_m"] for row in samples),
        "aim_degrees": distribution([row["aim_error_degrees"] for row in samples]),
        "errors": dict(collections.Counter(row["error"] for row in samples)),
        "wall_ms": distribution(wall),
        "over_100ms": sum(t > 100 for t in wall),
        "over_250ms": sum(t > 250 for t in wall),
        "call_ms": distribution([row["total_usec"]/1000 for row in rows]),
        "stages_ms": {
            stage: distribution([row["tether"].get(stage, 0)/1000 for row in rows])
            for stage in sorted(set().union(*(row["tether"].keys() for row in rows)))
        },
    }
result = {"evidence_class": "INERT", "nested_scopes_overlap": True,
          "settings": {key: frames[key] for key in ("resolution", "vsync")},
          "failures": {"calls": calls["failures"], "frames": frames["failures"]},
          "summary": summary}
destination = root.parent / (root.name + "_summary.json")
destination.write_text(json.dumps(result, indent=2) + "\n")
print(json.dumps(result, indent=2))
