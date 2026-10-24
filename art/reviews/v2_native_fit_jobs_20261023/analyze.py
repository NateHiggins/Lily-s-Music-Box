"""INERT played streaming attribution. Nested timings are not additive."""
import hashlib
import json
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent


def load(path):
    return json.loads(path.read_text(encoding="utf-8"))


def distribution(values):
    values = sorted(values)
    if not values:
        return {}
    def percentile(p):
        at = (len(values)-1)*p
        lo = int(at)
        hi = min(lo+1,len(values)-1)
        return values[lo]+(values[hi]-values[lo])*(at-lo)
    return {"n":len(values),"p50":percentile(.5),"p95":percentile(.95),
            "p99":percentile(.99),"max":max(values),
            "above100":sum(value>100 for value in values)}


def analyze(name):
    folder = ROOT/name
    stream = load(folder/"streaming.json")
    trace = load(folder/"work_trace.json")
    frames = trace["frames"]
    intervals = []
    by_state = defaultdict(list)
    by_cycle = defaultdict(list)
    for a,b in zip(frames,frames[1:]):
        if a["phase"].startswith("capture_excluded_") or b["phase"].startswith("capture_excluded_"):
            continue
        ms = (b["usec"]-a["usec"])/1000
        intervals.append(ms)
        by_state[b["residency"]].append(ms)
        for cycle in range(2):
            if b["phase"].startswith(f"cycle_{cycle}_"):
                by_cycle[str(cycle)].append(ms)
    text = (ROOT/f"{name}.log").read_text(encoding="utf-8")
    after_ready = text.split("[ORISON V2 RUNTIME] ready",1)[-1]
    after_ready = after_ready.split("STREAMING_TIMED_ROUTE_END",1)[0]
    native = [json.loads(line.split("NATIVE_FIT_DETAIL ",1)[1])
              for line in after_ready.splitlines() if "NATIVE_FIT_DETAIL " in line]
    retired = [json.loads(line.split("PASSAGE_RETIRE_DETAIL ",1)[1])
               for line in after_ready.splitlines() if "PASSAGE_RETIRE_DETAIL " in line]
    peaks = {}
    for row in native:
        key = row["cell"]+" | "+row["data"]
        if key not in peaks or row["model_and_collision_ms"]>peaks[key]["model_and_collision_ms"]:
            peaks[key] = row
    result = {"evidence_class":"INERT",
              "scope":"Post-render signal intervals, not display latency. State assigned from interval endpoint; transition intervals can straddle states. Detailed native fields nest inside model/collision time. Startup native timings excluded. No causal optimization claim from this baseline.",
              "wall_ms":distribution(intervals),
              "by_residency_ms":{key:distribution(values) for key,values in by_state.items()},
              "by_cycle_ms":{key:distribution(values) for key,values in by_cycle.items()},
              "checks":len(stream["checks"]),"failures":stream["failures"],
              "completed_cycles":len(stream["cycles"]),"waypoints":stream["timed_waypoints"] if "timed_waypoints" in stream else len(load(folder/"route.json")["trace"]),
              "trace_truncated":trace["truncated"],
              "residency":stream["final_residency"],
              "native_reload_rows":native,"retirement_detail":retired,
              "largest_model_work":sorted(peaks.values(),key=lambda row:row["model_and_collision_ms"],reverse=True),
              "references":[{"path":str(path.relative_to(ROOT)).replace("\\","/"),"sha256":hashlib.sha256(path.read_bytes()).hexdigest()}
                            for path in [folder/"streaming.json",folder/"work_trace.json",ROOT/f"{name}.log"]]}
    (folder/"streaming_analysis.json").write_text(json.dumps(result,indent=2)+"\n",encoding="utf-8")
    print(name,"whole",result["wall_ms"],"states",result["by_residency_ms"])
    print("cycles",result["completed_cycles"],"checks",result["checks"],"native rows",len(native))


if __name__=="__main__":
    for name in ["played_v1","played_v2","sync_control_v1","cooperative_final_v1"]:
        if (ROOT/name/"streaming.json").exists():analyze(name)
