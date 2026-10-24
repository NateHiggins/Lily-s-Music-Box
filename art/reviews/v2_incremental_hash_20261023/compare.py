"""INERT same-route comparison and untimed shader-cache control."""
import hashlib
import json
from pathlib import Path
PACKET=Path(__file__).resolve().parent
REPO=PACKET.parents[2]

def load(path):return json.loads(path.read_text())
def rows(folder):
    text=(folder.parent/(folder.name+".log")).read_text().split("[ORISON V2 RUNTIME] ready",1)[-1]
    timed,untimed=text.split("STREAMING_TIMED_ROUTE_END",1)
    parse=lambda value:[json.loads(line.split("NATIVE_FIT_DETAIL ",1)[1]) for line in value.splitlines() if "NATIVE_FIT_DETAIL " in line]
    return parse(timed),parse(untimed)

result={"evidence_class":"INERT","scope":"Observed signal intervals, not display latency or exclusive CPU/GPU partitions. Failed attempts and rejected material construction remain separate. Untimed cache release is excluded from distributions.","runs":[]}
folders=[REPO/"art/reviews/v2_native_fit_jobs_20261023/cooperative_final_v1"]+[PACKET/name for name in ["played_v1","material_played_v1","warm_shader_v1","warm_shader_v3"]]
for folder in folders:
    analysis=load(folder/"streaming_analysis.json");stream=load(folder/"streaming.json");state=stream["final_residency"]
    native,untimed=rows(folder);start=None;durations=[]
    for event in stream["events"]:
        if event["kind"]!="state":continue
        if event["state"]=="LOADING":start=event["usec"]
        elif event["state"]=="RESIDENT" and start is not None:durations.append((event["usec"]-start)/1000);start=None
    item={"path":folder.relative_to(REPO).as_posix(),"wall_ms":analysis["wall_ms"],"by_residency_ms":analysis["by_residency_ms"],"load_duration_ms":durations,"peak_stage_ms":state["peak_stage_ms"],"peak_activation_ms":state["peak_activation_ms"],"timed_waypoints":stream["timed_waypoints"],"checks":len(stream["checks"]),"failures":stream["failures"],"final_residency":state,"canopy_timed":[r for r in native if r["data"].endswith("/arcade_canopy.json")],"canopy_untimed":[r for r in untimed if r["data"].endswith("/arcade_canopy.json")],"peak_hash_slice_ms":max((r.get("hash_step_peak_ms",0) for r in native),default=0),"references":[{"path":path.relative_to(REPO).as_posix(),"sha256":hashlib.sha256(path.read_bytes()).hexdigest()} for path in [folder/"streaming.json",folder/"streaming_analysis.json",folder.parent/(folder.name+".log")]]}
    result["runs"].append(item)
    print(folder.name,"stage",item["peak_stage_ms"],"hash slice",item["peak_hash_slice_ms"],"load_ms",durations)
result["untimed_control"]=load(PACKET/"warm_shader_v3/untimed_shader_control.json")
(PACKET/"comparison.json").write_text(json.dumps(result,indent=2)+"\n")
