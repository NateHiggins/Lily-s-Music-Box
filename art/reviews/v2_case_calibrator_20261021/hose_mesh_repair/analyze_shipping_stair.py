"""INERT distribution analysis; never writes a runtime qualification receipt."""
from pathlib import Path
import json
import math
import gzip

ROOT = Path(__file__).resolve().parent
RUN = ROOT / "shipping_stair"


def distribution(values):
    ordered = sorted(values)
    if not ordered:
        return {"n": 0}
    def quantile(q):
        # Nearest-rank quantiles, retaining individual original frame samples.
        return ordered[max(0, math.ceil(q * len(ordered)) - 1)]
    return {"n": len(ordered), "p50_ms": quantile(.5),
            "p95_ms": quantile(.95), "p99_ms": quantile(.99),
            "max_ms": ordered[-1],
            "over_100_ms": sum(v > 100 for v in values),
            "over_250_ms": sum(v > 250 for v in values)}


def analyze(directory):
    def read(name):
        path = directory / name
        return json.loads(path.read_bytes() if path.exists() else gzip.decompress(path.with_name(name + ".gz").read_bytes()))
    frames = read("frames.json")
    ticks = read("inspection_observations.json")
    result = {"resolution": frames["resolution"], "vsync": frames["vsync"],
              "capture_control": frames["capture_control"], "failures": frames["failures"], "cycles": {}}
    for prefix in ("original_a_", "lower_cap_b_", "restored_a_"):
        movement = [row for row in frames["samples"] if row[0].startswith(prefix)
                    and ("walk_" in row[0] or row[0].endswith("upper_turn"))]
        inspection = [row for row in frames["samples"] if row[0].startswith(prefix + "inspection_")
                      and "approach" not in row[0] and "walk_" not in row[0]
                      and "excluded" not in row[0]]
        physical = [row for row in ticks["physics_ticks"] if row["phase"].startswith(prefix)
                    and "excluded" not in row["phase"]]
        result["cycles"][prefix] = {
            "movement": distribution([row[1] for row in movement]),
            "inspection": distribution([row[1] for row in inspection]),
            "physics_ticks": len(physical),
            "step": distribution([row["step_ms"] for row in physical if "step_ms" in row]),
            "slide": distribution([row["slide_ms"] for row in physical if "slide_ms" in row]),
            "prompt": distribution([row["ms"] for row in ticks.get("prompt_costs", [])
                                      if row["phase"].startswith(prefix) and "excluded" not in row["phase"]])}
    return result


if __name__ == "__main__":
    result = {"evidence_class": "INERT", "kind": "paired_performance_diagnostic",
              "scope": "Same-run A/B/A on shipping lower-cap query with simplified native hose meshes in every leg. Does not isolate mesh savings, measure hardware input latency, or renew runtime qualifications.",
              "current": analyze(RUN)}
    (RUN / "comparison.json").write_bytes((json.dumps(result, indent=2) + "\n").encode())
    print(json.dumps(result, indent=2))
