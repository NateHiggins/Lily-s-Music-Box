"""Thin future execution wrapper. No source installation or cleanup actions."""
from pathlib import Path
import argparse
import hashlib
import json
import os
import subprocess
import sys
import time

HERE=Path(__file__).resolve().parent
ROOT=next(p for p in HERE.parents if (p/"game/project.godot").is_file())


def sha(path):
    h=hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda:stream.read(1048576),b""):h.update(chunk)
    return h.hexdigest()


def dump(path,value):
    path.write_text(json.dumps(value,indent=2)+"\n")


def git(*args):
    return subprocess.check_output(["git","-C",str(ROOT),*args],stderr=subprocess.PIPE).decode().strip()


def process_census():
    command=["powershell.exe","-NoProfile","-NonInteractive","-Command",
        "$ErrorActionPreference='Stop'; @((Get-CimInstance Win32_Process | Where-Object { $_.Name -match '^(Godot.*|blender)\\.exe$' } | Select-Object ProcessId,Name,ExecutablePath)) | ConvertTo-Json -Compress"]
    result=subprocess.run(command,capture_output=True,check=False)
    assert result.returncode==0,result.stderr.decode(errors="replace")
    decoded=result.stdout.decode("utf-8-sig").strip()
    rows=json.loads(decoded) if decoded else []
    if isinstance(rows,dict):rows=[rows]
    return {"command":command,"exit_code":result.returncode,"processes":rows,"empty":not rows}


def snapshot(paths,protected):
    files={}
    for relative in paths:
        p=(ROOT/relative).resolve()
        assert p.is_relative_to(ROOT.resolve())
        files[relative]={"exists":p.is_file(),"sha256":sha(p) if p.is_file() else None,
            "bytes":p.stat().st_size if p.is_file() else None}
    blobs={}
    for relative in protected:
        row={}
        for key,arguments in {"head":("rev-parse","HEAD:"+relative),"index":("rev-parse",":"+relative),
                "working_clean":("hash-object","--path="+relative,relative)}.items():
            try:row[key]=git(*arguments)
            except subprocess.CalledProcessError as error:
                row[key]=None;row[key+"_error"]={"exit":error.returncode,"stderr":error.stderr.decode(errors="replace")}
        blobs[relative]=row
    return {"head":git("rev-parse","HEAD"),"files":files,"protected_blobs":blobs}


def check_external_outputs(plan):
    outputs=[Path(p).resolve() for p in plan["outputs"].values()]
    assert len(outputs)==2 and outputs[0]!=outputs[1]
    for output in outputs:
        assert output!=ROOT and not output.is_relative_to(ROOT) and not ROOT.is_relative_to(output)
    assert not outputs[0].is_relative_to(outputs[1]) and not outputs[1].is_relative_to(outputs[0])


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("action",choices=["plan","bind","export_a","export_b"])
    args=parser.parse_args()
    plan=json.loads((HERE/"plan.json").read_text())
    check_external_outputs(plan)
    evidence=ROOT/plan["evidence_root"]
    if args.action=="plan":
        print(json.dumps({"status":plan["status"],"input_paths":len(plan["input_paths"]),
            "protected_paths":len(plan["protected_paths"]),"source_files":len(plan["exact_source_hashes"]),
            "plan_sha256":sha(HERE/"plan.json")},indent=2));return 0
    if args.action=="bind":
        assert not evidence.exists(),"fresh evidence root required"
        assert all(not Path(p).exists() for p in plan["outputs"].values()),"both exports must start nonexistent"
        assert plan["dependency_closure_reviewed"],"review concrete material input closure before binding"
        for rel,expected in plan["exact_source_hashes"].items():assert sha(ROOT/rel)==expected,rel
        for rel,expected in plan["reviewed_input_hashes"].items():assert sha(ROOT/rel)==expected,"reviewed closure source drift: "+rel
        evidence.mkdir(parents=True)
        census=process_census();dump(evidence/"bind_process_census.json",census)
        assert census["empty"],"another Godot/Blender process is active; no binding/export performed"
        current=snapshot(plan["input_paths"],plan["protected_paths"])
        dump(evidence/"bind_snapshot.json",current)
        assert all(set(row)=={"head","index","working_clean"} and row["head"] and
            row["head"]==row["index"]==row["working_clean"] for row in current["protected_blobs"].values())
        binding={"status":"BOUND_NO_EXPORT_RUN","inputs":current,"blender_sha256":sha(Path(plan["blender"])),
            "plan_sha256":sha(HERE/"plan.json"),"bridge_sha256":sha(HERE/"child_capture_bridge.py"),"outer_sha256":sha(Path(__file__)),
            "verifier_sha256":sha(HERE/"verify_outputs.py"),"python_executable":sys.executable,"python_sha256":sha(Path(sys.executable)),
            "bind_census_sha256":sha(evidence/"bind_process_census.json"),"exact_source_hashes":plan["exact_source_hashes"]}
        dump(evidence/"binding.json",binding)
        print(json.dumps({"status":binding["status"],"binding_sha256":sha(evidence/"binding.json"),
            "input_count":len(current["files"]),"protected_count":len(current["protected_blobs"]),"blender_sha256":binding["blender_sha256"]}));return 0
    binding=json.loads((evidence/"binding.json").read_text())
    assert binding["plan_sha256"]==sha(HERE/"plan.json") and binding["bridge_sha256"]==sha(HERE/"child_capture_bridge.py")
    assert binding["outer_sha256"]==sha(Path(__file__))
    assert binding["verifier_sha256"]==sha(HERE/"verify_outputs.py")
    assert binding["python_executable"]==sys.executable and binding["python_sha256"]==sha(Path(sys.executable))
    mode=args.action.removeprefix("export_")
    if mode=="b":
        prior=json.loads((evidence/"a/outer_result.json").read_text())
        assert prior["outer_contract_exit"]==0,"preserve and investigate failed first export before second"
    output=Path(plan["outputs"][mode]).resolve()
    assert not output.exists(),"never reuse/clean a prior output"
    out=evidence/mode;out.mkdir(exist_ok=False)
    census=process_census();dump(out/"before_process_census.json",census)
    assert census["empty"],"another Godot/Blender process is active; export refused"
    before=snapshot(plan["input_paths"],plan["protected_paths"])
    dump(out/"before.json",before)
    assert before==binding["inputs"],"bound input drift before child; no export launched"
    config={"root":str(ROOT),"output":str(output),"evidence":str(out),"blender":plan["blender"],
        "blender_sha256":binding["blender_sha256"],"exact_source_hashes":binding["exact_source_hashes"],
        "blender_timeout_seconds":plan["blender_timeout_seconds"]}
    dump(out/"config.json",config)
    command=[sys.executable,"-B",str(HERE/"child_capture_bridge.py"),"--config",str(out/"config.json")]
    dump(out/"command.json",command)
    env=dict(os.environ);env["PYTHONDONTWRITEBYTECODE"]="1"
    # Factory startup already isolates Blender settings. Record inherited values
    # that could redirect the generator; the adapter remains the real authority.
    dump(out/"environment.json",{k:env.get(k) for k in ("ORISON_BLEND_OUT","PYTHONPATH","BLENDER_USER_CONFIG","BLENDER_USER_SCRIPTS")})
    started=time.monotonic();bridge_exit=None;failure=None;after=None;after_census=None
    try:
        with (out/"controller.stdout.raw").open("xb") as stdout,(out/"controller.stderr.raw").open("xb") as stderr:
            process=subprocess.run(command,cwd=ROOT,env=env,stdout=stdout,stderr=stderr,check=False)
            bridge_exit=process.returncode
    except BaseException as error:
        failure=repr(error)
    finally:
        try:
            after_census=process_census();dump(out/"after_process_census.json",after_census)
            after=snapshot(plan["input_paths"],plan["protected_paths"]);dump(out/"after.json",after)
        except BaseException as error:
            failure=(failure or "")+"; after verification failed: "+repr(error)
        child=json.loads((out/"blender_child.json").read_text()) if (out/"blender_child.json").exists() else None
        controller=json.loads((out/"controller_bridge.json").read_text()) if (out/"controller_bridge.json").exists() else None
        okay=(failure is None and bridge_exit==0 and before==after and after_census is not None and after_census["empty"]
            and child is not None and controller is not None and child.get("actual_blender_exit")==0
            and not child.get("forced_timeout_termination",True) and controller.get("actual_controller_exit")==0
            and controller.get("intercepted_blender_calls")==1)
        record={"status":"PROCESS_AND_PROTECTION_PASS_PENDING_INDEPENDENT_OUTPUT_CHECKS" if okay else "REFUSED_OR_FAILED_PRESERVED",
            "outer_contract_exit":0 if okay else 1,"actual_bridge_exit":bridge_exit,
            "actual_blender_exit":child.get("actual_blender_exit") if child else None,
            "actual_controller_exit":controller.get("actual_controller_exit") if controller else None,
            "inputs_unchanged":before==after,"empty_process_census_after":bool(after_census and after_census["empty"]),
            "failure":failure,"elapsed_seconds":time.monotonic()-started,
            "artifacts":{p.name:sha(p) for p in out.iterdir() if p.is_file()},
            "output":str(output),"independent_output_acceptance":False}
        dump(out/"outer_result.json",record)
    print(json.dumps({k:record[k] for k in ("status","outer_contract_exit","actual_bridge_exit","actual_blender_exit",
        "actual_controller_exit","inputs_unchanged","empty_process_census_after","elapsed_seconds")}));return record["outer_contract_exit"]


if __name__=="__main__":raise SystemExit(main())
