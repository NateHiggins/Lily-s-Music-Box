"""INERT repeatable summaries. Raw counts, no inferred exclusive CPU/GPU sum."""
from pathlib import Path
import hashlib
import json
from statistics import median

ROOT = Path(__file__).resolve().parent


def load(path):
    return json.loads(path.read_text(encoding="utf-8"))


def distribution(values):
    values = sorted(values)
    def percentile(p):
        at = (len(values)-1)*p
        lo = int(at)
        hi = min(lo+1, len(values)-1)
        return values[lo]+(values[hi]-values[lo])*(at-lo)
    return {"n":len(values),"p50":median(values),"p95":percentile(.95),
            "p99":percentile(.99),"max":max(values)}


def main():
    result = {"evidence_class":"INERT", "scope":"Component cache control is causal; whole-route pair is observational, ambient activity/frame counts differ. Root render timing lags; no exclusive CPU/GPU sum. Motion run overlaps tooling and supplies correctness counts only."}
    study = load(ROOT / "probe_v1/shadow_study.json")
    result["fixed_view"] = {}
    for phase in dict.fromkeys(r["phase"] for r in study["samples"]):
        rows = [r for r in study["samples"] if r["phase"]==phase]
        result["fixed_view"][phase] = {k:distribution([r[k] for r in rows]) for k in ["wall_ms","cpu_ms","gpu_ms","shadow_draws","visible_draws"]}
        result["fixed_view"][phase]["pipeline_deltas"] = {k:rows[-1]["monitors"][k]-rows[0]["monitors"][k] for k in rows[0]["monitors"]}
    result["setter"] = {}
    for folder in ["setter_v1","budget_before_v1","budget_after_v1"]:
        data = load(ROOT / folder / "setter_control.json")
        phases = {}
        for phase in dict.fromkeys(r["phase"] for r in data["samples"]):
            rows = [r for r in data["samples"] if r["phase"]==phase]
            phases[phase] = {k:distribution([r[k] for r in rows]) for k in ["wall_ms","cpu_ms","gpu_ms","shadow_draws"]}
            phases[phase]["all_shadow_flags_true"] = all(r["shadow"] for r in rows)
        result["setter"][folder] = {"checks":len(data.get("checks",[])),"failures":data.get("failures",[]),"phases":phases}
    result["motion_correctness"] = load(ROOT / "motion_after_v1/setter_control.json")["motion_updates"]
    result["routes"] = {}
    for name, folder in [("before",ROOT.parent/"v2_commit_causes_20261023/world_after_v1"),("guarded",ROOT/"world_after_v1")]:
        paths = [folder/"work_analysis.json",folder/"cause_analysis.json",folder/"hose_checks.json"]
        result["routes"][name] = {"references":[{"path":str(p.relative_to(ROOT.parent)).replace("\\","/"),"sha256":hashlib.sha256(p.read_bytes()).hexdigest()} for p in paths],
            "wall_ms":load(paths[0])["wall_ms"],"root_render_cpu_ms":load(paths[1])["root_render_cpu_ms"],"root_render_gpu_ms":load(paths[1])["root_render_gpu_ms"],
            "render_setup_cpu_ms":load(paths[1])["render_setup_cpu_ms"],"render_passes":load(paths[1])["render_passes"],"changed_commits":load(paths[1])["changed_commits"],
            "checks":len(load(paths[2])["checks"]),"failures":load(paths[2])["failures"]}
    (ROOT / "comparison.json").write_text(json.dumps(result,indent=2)+"\n",encoding="utf-8")
    print("Bound component summaries and both route references in comparison.json")


if __name__ == "__main__":
    main()
