"""INERT origins and renderer counters, not exclusive CPU/GPU accounting."""
from collections import Counter
import json
from pathlib import Path
from statistics import median
import sys

ROOT = Path(__file__).resolve().parent


def summary(values):
    values = sorted(values)
    if not values:
        return {}
    def percentile(p):
        at = (len(values)-1)*p
        lo = int(at)
        hi = min(lo+1, len(values)-1)
        return values[lo]+(values[hi]-values[lo])*(at-lo)
    return {"n":len(values), "p50":median(values), "p95":percentile(.95),
            "p99":percentile(.99), "max":max(values)}


def analyze(directory):
    causes = json.loads((directory / "commit_causes.json").read_text(encoding="utf-8"))["causes"]
    trace = json.loads((directory / "work_trace.json").read_text(encoding="utf-8"))
    commits = {r["start_usec"]:r for r in trace["household"] if r["stage"]=="commit_change"}
    origins = []
    for cause in causes:
        row = commits[cause["start_usec"]]
        origins.append({**cause, "inclusive_ms":(row["end_usec"]-row["start_usec"])/1000})
    frames = json.loads((directory / "frames.json").read_text(encoding="utf-8"))["samples"]
    frames = [r for r in frames if not r[0].startswith("capture_excluded") and r[4]>0]
    result = {"evidence_class":"INERT", "scope":"Diagnostic origins; stack and ID comparison overhead is included in commit costs. Root viewport CPU/GPU counters lag rendering and are not additive to each other or callback wall intervals.",
        "changed_commits":len(causes), "same_frame_commits":{
            str(k):v for k,v in Counter(r["process_frame"] for r in causes).items() if v>1},
        "cause_probe_usec":summary([r["probe_usec"] for r in causes]),
        "commit_ms":summary([r["inclusive_ms"] for r in origins]),
        "root_render_cpu_ms":summary([r[4] for r in frames]),
        "root_render_gpu_ms":summary([r[5] for r in frames]),
        "origins":origins}
    physics = [r for r in origins if any(s["function"]=="_physics_process" and s["source"].endswith("fire_unracked_hose.gd") for s in r["stack"])]
    begin = None
    for event in trace["timeline"]:
        if event[4]=="physics_begin":
            begin=event
        elif event[4]=="physics_end" and begin is not None:
            for row in physics:
                commit=commits[row["start_usec"]]
                if begin[0]<=row["start_usec"] and commit["end_usec"]<=event[0]:
                    row["physics_callback_ms"]=(event[0]-begin[0])/1000
                    row["callback_outside_commit_ms"]=row["physics_callback_ms"]-row["inclusive_ms"]
            begin=None
    result["water_completion_commits"] = physics
    path = directory / "render_passes.json"
    if path.exists():
        data = json.loads(path.read_text(encoding="utf-8"))
        samples = [r for r in data["samples"] if not r["phase"].startswith("capture_excluded")]
        result["render_passes"] = {kind:{field:summary([r["passes"][kind][i] for r in samples]) for i,field in enumerate(["objects","primitives","draw_calls"])} for kind in ["0","1"]}
        result["render_probe_usec"] = summary([r["probe_usec"] for r in samples])
        result["render_setup_cpu_ms"] = summary([r["setup_cpu_ms"] for r in samples])
        result["light_inventory"] = {"total":len(data["lights"]),"visible_shadow":sum(r["visible"] and r["shadow"] for r in data["lights"]),"visible":sum(r["visible"] for r in data["lights"])}
    (directory / "cause_analysis.json").write_text(json.dumps(result, indent=2)+"\n", encoding="utf-8")
    print(json.dumps({k:v for k,v in result.items() if k not in ["origins","water_completion_commits"]}, indent=2))


if __name__ == "__main__":
    analyze(ROOT / sys.argv[1])
