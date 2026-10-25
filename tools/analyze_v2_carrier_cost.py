"""Summarize INERT carrier probes without discarding phase-boundary spikes.

Usage: python tools/analyze_v2_carrier_cost.py path/to/carrier_cost.json
Construction-overlapping intervals are excluded from playable distributions.
Render spans are CPU-observed boundaries, not GPU completion/display latency.
"""
import argparse
import json
from pathlib import Path


def distribution(values):
    ordered = sorted(values)
    if not ordered:
        return {"count": 0}

    def percentile(fraction):
        position = (len(ordered) - 1) * fraction
        lo = int(position)
        hi = min(lo + 1, len(ordered) - 1)
        return ordered[lo] + (ordered[hi] - ordered[lo]) * (position - lo)

    return {"count": len(ordered), "p50_ms": percentile(.50),
            "p95_ms": percentile(.95), "p99_ms": percentile(.99),
            "max_ms": ordered[-1], "over_100_ms": sum(x > 100 for x in ordered)}


def analyze(data):
    end = data["world_construct_end_usec"]
    playable = [row for row in data["samples"]
                if row.get("wall_ms") is not None
                and row["start_usec"] - row["wall_ms"] * 1000 >= end]
    phases = {}
    for name in dict.fromkeys(row["phase"] for row in playable):
        rows = [r for r in playable if r["phase"] == name and r["full_interval"]]
        phases[name] = distribution([r["wall_ms"] for r in rows])
    spike = max(playable, key=lambda r: r["wall_ms"], default=None)
    overlap = {}
    if spike:
        lo = spike["start_usec"] - spike["wall_ms"] * 1000
        hi = spike["start_usec"]
        for key in ("carrier_callbacks", "motion_callbacks", "mechanism_callbacks"):
            spans = [r for r in data.get(key, [])
                     if r["start_usec"] < hi and r["end_usec"] > lo]
            overlap[key] = {
                "count": len(spans),
                # Inclusive wall overlap; do not sum with nested subspans.
                "inclusive_overlap_usec": sum(min(r["end_usec"], hi)
                                              - max(r["start_usec"], lo) for r in spans),
                "max_callback_usec": max((r["end_usec"] - r["start_usec"]
                                          for r in spans), default=None)}
    return {
        "evidence_class": "INERT", "companion": data["companion"],
        "failures": data["failures"],
        "construction_wall_ms": (end-data["world_construct_start_usec"])/1000,
        "playable_all_intervals": distribution([r["wall_ms"] for r in playable]),
        "phases_full_intervals_only": phases, "largest_playable_interval": spike,
        "largest_interval_callback_overlap": overlap,
        "render_boundary_spans": distribution([(r["post_usec"]-r["pre_usec"])/1000
                                                for r in data["draws"] if r["pre_usec"] >= end]),
        "observer_query_max_usec": max((r["observer_query_usec"] for r in playable), default=None),
        "callback_max_usec": {key: max((r["end_usec"]-r["start_usec"]
                                       for r in data.get(key, [])), default=None)
                              for key in ("carrier_callbacks", "motion_callbacks", "mechanism_callbacks")},
        "limitations": "Phase boundaries retained in all-interval distribution. Callback spans are inclusive and must not be summed with nested query/move/pose timing. Renderer/physics/process monitors overlap and lag. No GPU completion, driver attribution, human input latency or runtime qualification."}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("probe", type=Path)
    parser.add_argument("--out", type=Path)
    args = parser.parse_args()
    output = json.dumps(analyze(json.loads(args.probe.read_text(encoding="utf-8"))), indent=2) + "\n"
    if args.out:
        args.out.write_text(output, encoding="utf-8")
    else:
        print(output, end="")
