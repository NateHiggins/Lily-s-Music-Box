"""INERT stage summary: inclusive nested timings, never additive totals."""
import json
from pathlib import Path
from statistics import median

ROOT = Path(__file__).resolve().parent


def distribution(values):
    values = sorted(v / 1000 for v in values)
    def percentile(p):
        at = (len(values) - 1) * p
        low = int(at)
        high = min(low + 1, len(values) - 1)
        return values[low] + (values[high] - values[low]) * (at - low)
    return {"n": len(values), "p50": median(values), "p95": percentile(.95),
            "p99": percentile(.99), "max": max(values)} if values else {}


def summarize(directory):
    source = directory / "storage_stages.json"
    data = json.loads(source.read_text(encoding="utf-8"))
    result = {"evidence_class": "INERT", "bytes": data["bytes"],
              "scope": "Nested stage costs are inclusive, not additive. "
                       "Component writes follow timed playable input; no claim "
                       "they are whole-frame or player-input timings.", "phases": []}
    for phase in data["phases"]:
        stages = {}
        for row in phase["rows"]:
            for stage in row["stages"]:
                stages.setdefault(stage["stage"], []).append(stage["usec"])
        result["phases"].append({"fast_utf8": phase["fast_utf8"],
            "storage_ms": distribution([r["usec"] for r in phase["rows"]]),
            "stage_ms": {k: distribution(v) for k, v in stages.items()}})
    result["serialization"] = [{"pretty": r["pretty"], "bytes": r["bytes"],
        "ms": distribution(r["times_usec"])} for r in data["serialization"]]
    (directory / "storage_analysis.json").write_text(
        json.dumps(result, indent=2) + "\n", encoding="utf-8")
    return result


if __name__ == "__main__":
    import sys
    result = summarize(ROOT / sys.argv[1])
    print(json.dumps({"bytes": result["bytes"], "phases": [
        {"fast": p["fast_utf8"], "storage": p["storage_ms"],
         "utf8": p["stage_ms"].get("utf8"),
         "decode": p["stage_ms"].get("decode")} for p in result["phases"]],
        "serialization": result["serialization"]}, indent=2))
