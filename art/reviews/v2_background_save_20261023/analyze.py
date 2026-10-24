"""INERT source-bound route comparison. No CPU/GPU sum or human acceptance."""
import hashlib
import json
from pathlib import Path
from statistics import median

ROOT = Path(__file__).resolve().parent


def load(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def distribution(values):
    values = sorted(values)
    if not values:
        return {}
    def percentile(p):
        at = (len(values)-1)*p
        lo = int(at)
        hi = min(lo+1, len(values)-1)
        return values[lo]+(values[hi]-values[lo])*(at-lo)
    return {"n":len(values), "p50":median(values), "p95":percentile(.95),
            "p99":percentile(.99), "max":max(values),
            "above_100":sum(value > 100 for value in values)}


def analyze(folder):
    trace = load(folder/"work_trace.json")
    frames = trace["frames"]
    intervals = []
    for first, last in zip(frames,frames[1:]):
        if first["phase"].startswith("capture_excluded_") or last["phase"].startswith("capture_excluded_"):
            continue
        intervals.append({"start_usec":first["usec"],"end_usec":last["usec"],
                          "phase":last["phase"],"ms":(last["usec"]-first["usec"])/1000})
    route_end = trace["timeline"][-1][0]
    household = [row for row in trace["household"] if row["start_usec"]<=route_end]
    result = {"evidence_class":"INERT", "wall_ms":distribution([row["ms"] for row in intervals]),
              "residency":sorted({row["residency"] for row in frames}),
              "main_household_ms":{stage:distribution([(r["end_usec"]-r["start_usec"])/1000 for r in household if r["stage"]==stage])
                                   for stage in sorted({r["stage"] for r in household})},
              "compilation_deltas":{key:frames[-1]["counters"][key]-frames[0]["counters"][key] for key in frames[0]["counters"] if key.startswith("PIPELINE_COMPILATIONS_")}}
    root_frames = [row for row in load(folder/"frames.json")["samples"] if not row[0].startswith("capture_excluded") and row[4]>0]
    result["root_render_cpu_ms"] = distribution([row[4] for row in root_frames])
    result["root_render_gpu_ms"] = distribution([row[5] for row in root_frames])
    if (folder/"background_jobs.json").exists():
        data = load(folder/"background_jobs.json")
        workers = [row["result"] for row in data["route_jobs"] if row["stage"]=="completed"]
        result["enqueue_main_ms"] = distribution([row["main_usec"]/1000 for row in data["route_jobs"] if row["stage"]=="enqueue"])
        result["worker_ms"] = distribution([row["worker_usec"]/1000 for row in workers])
        result["route_status"] = data["route_status"]
        result["overlap_control"] = data["untimed_overlap"]
        for row in intervals:
            row["intersecting_workers"] = sum(r["worker_started_usec"]<row["end_usec"] and r["worker_finished_usec"]>row["start_usec"] for r in workers)
    result["largest_intervals"] = sorted(intervals,key=lambda row:row["ms"],reverse=True)[:20]
    checks = load(folder/"hose_checks.json")
    result["checks"] = len(checks["checks"])
    result["failures"] = checks["failures"]
    result["sources"] = [{"path":str(path.relative_to(ROOT.parent)).replace("\\","/"),"sha256":hashlib.sha256(path.read_bytes()).hexdigest()}
                         for path in [folder/"work_trace.json",folder/"frames.json",folder/"hose_checks.json"]]
    return result


def main():
    result = {"evidence_class":"INERT", "scope":"Warm controls share the route and settings. Unfrozen ambient activity/frame counts differ. Rendering counters lag; workers and main overlap. Initial failed rebuild remains failed. Main household summaries exclude untimed post-route stress records.", "routes":{}}
    for name, folder in [("preceding",ROOT.parent/"v2_far_shadows_20261023/world_after_v1")]+[(name,ROOT/name) for name in ["world_after_v1","sync_warm_v1","async_warm_v1","world_after_v2"]]:
        if not (folder/"automatic_persistence.json").exists():
            continue
        result["routes"][name] = analyze(folder)
    (ROOT/"comparison.json").write_text(json.dumps(result,indent=2)+"\n",encoding="utf-8")
    for name,row in result["routes"].items():
        print(name,row["wall_ms"],"commit",row["main_household_ms"].get("commit_change"),"failures",row["failures"])


if __name__ == "__main__":
    main()
