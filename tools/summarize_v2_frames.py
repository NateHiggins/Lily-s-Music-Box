"""Summarize diagnostic raw frame samples without treating averages as proof."""
import argparse
import json
import math
from pathlib import Path


def distribution(values):
    ordered = sorted(values)
    if not ordered:
        return {}
    return {**{f"p{q}_ms": round(ordered[min(len(ordered)-1, math.ceil(q/100*len(ordered))-1)], 3)
               for q in (50, 90, 95, 99)},
            "max_ms": round(ordered[-1], 3), "frames": len(ordered),
            "over_33ms": sum(v > 33.333 for v in values),
            "over_50ms": sum(v > 50 for v in values),
            "over_100ms": sum(v > 100 for v in values)}


def summarize(path):
    data = json.loads(Path(path).read_text(encoding="utf-8"))
    columns = data["columns"]
    phases = {}
    for sample in data["samples"]:
        phases.setdefault(sample[0], []).append(sample)
    return {"source": str(path), "kind": "performance_diagnostic", "evidence_class": "INERT",
            "settings": {k: data[k] for k in ("resolution", "vsync")},
            "startup_ms": data["startup_ms"], "failures": data["failures"],
            "phases": {phase: {column: distribution([row[index] for row in rows])
                                for index, column in enumerate(columns) if column.endswith("_ms")}
                       for phase, rows in phases.items()},
            "worst_frames": sorted(data["samples"], key=lambda row: row[1], reverse=True)[:20],
            "streaming": data["streaming"]}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("frames", type=Path)
    parser.add_argument("--out", type=Path)
    args = parser.parse_args()
    output = json.dumps(summarize(args.frames), indent=2) + "\n"
    if args.out:
        args.out.write_text(output, encoding="utf-8", newline="\n")
    else:
        print(output, end="")
