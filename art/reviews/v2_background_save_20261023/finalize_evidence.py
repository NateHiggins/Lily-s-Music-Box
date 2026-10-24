"""INERT checks and explicit gate combination; retains original failed results."""
import hashlib
import importlib.util
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent
REPO = ROOT.parents[2]


def load(path):
    return json.loads(path.read_text(encoding="utf-8"))


def write(path, data):
    path.write_text(json.dumps(data,indent=2)+"\n",encoding="utf-8")


def main():
    previous = ROOT.parent/"v2_far_shadows_20261023"
    protected = load(previous/"protected.json")
    for row in protected["files"]:
        path = REPO/row["path"]
        raw = path.read_bytes()
        if path.suffix != ".bin":
            raw = raw.replace(b"\r\n",b"\n")
        assert hashlib.sha256(raw).hexdigest()==row["sha256"], row["path"]
    write(ROOT/"protected.json",protected)
    full = load(ROOT/"gates/board.json")
    focused = load(ROOT/"gates_focused_final/board.json")
    updates = {gate["id"]:gate for gate in focused["gates"]}
    full["gates"] = [updates.get(gate["id"],gate) for gate in full["gates"]]
    full["created_utc"] = focused["created_utc"]
    full["dirty_paths"] = focused["dirty_paths"]
    full["derivation"] = {"evidence_class":"INERT","full":"gates/board.json",
                          "focused":"gates_focused_final/board.json",
                          "reason":"Final profiler formatting and comparator fixture; all other full tools results retained. Original regression boards retained."}
    spec = importlib.util.spec_from_file_location("board",REPO/"tools/gate_board.py")
    board = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(board)
    full["comparison"] = board.compare(load(previous/"gates_final.json"),full)
    assert not full["comparison"]["regressions"], full["comparison"]["regressions"]
    write(ROOT/"gates_final.json",full)
    manifest = []
    for path in sorted(ROOT.rglob("*")):
        if not path.is_file() or path.name=="artifact_manifest.json" or "__pycache__" in path.parts:
            continue
        raw = path.read_bytes()
        manifest.append({"path":path.relative_to(ROOT).as_posix(),"bytes":len(raw),
                         "sha256":hashlib.sha256(raw).hexdigest()})
    write(ROOT/"artifact_manifest.json",{"evidence_class":"INERT",
          "scope":"Raw diagnostics, original failures and source variants. Manifest excludes itself and Python caches. No runtime_contract or human acceptance.","files":manifest})
    print("Protected",len(protected["files"]),"regressions",len(full["comparison"]["regressions"]),"files",len(manifest))


if __name__=="__main__":
    main()
