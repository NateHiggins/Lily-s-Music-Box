"""Independent read-only landing selection review. Never stages or edits inputs."""
from pathlib import Path
import hashlib
import json
import re
import subprocess

HERE = Path(__file__).resolve().parent
ROOT = next(p for p in HERE.parents if (p / "game/project.godot").is_file())
LANDING = HERE.parent / "landing_01"
SELECTION_SHA = "4a7c1c923f3076343ee5fe29069ae6d60f808b67b927c26cc7b68d248f3f5cce"
FINAL = ROOT / "design/astra/evidence/vulkan_composed/runs/candidate_v1_material_final_01/result.json"


def sha(path):
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1048576), b""): h.update(chunk)
    return h.hexdigest()


def git(*args):
    return subprocess.check_output(["git", "-C", str(ROOT), *args], stderr=subprocess.PIPE).decode().strip()


def main():
    assert sha(LANDING / "selection.json") == SELECTION_SHA
    selection = json.loads((LANDING / "selection.json").read_text())
    paths = selection["selected_paths"]
    assert len(paths) == len(set(paths)) == selection["selected_count"] == 3784
    assert set(paths) == set(selection["selected_sha256"])
    pathspec = [x for x in (LANDING / "paths.nul").read_bytes().decode().split("\0") if x]
    extras = [p.relative_to(ROOT).as_posix() for p in [LANDING / "selection.json", LANDING / "paths.nul"]]
    assert len(pathspec) == len(set(pathspec)) == 3786 and set(pathspec) == set(paths + extras)
    verified = {}; failures = []; total_bytes = 0
    for relative in paths:
        path = (ROOT / relative).resolve()
        if not path.is_relative_to(ROOT.resolve()) or not path.is_file():
            failures.append({"path":relative,"reason":"missing_or_outside_root"}); continue
        actual = sha(path); total_bytes += path.stat().st_size
        verified[relative] = actual
        if actual != selection["selected_sha256"][relative]:
            failures.append({"path":relative,"reason":"raw_hash_mismatch","actual":actual,"expected":selection["selected_sha256"][relative]})
    head = git("rev-parse", "HEAD")
    assert head == selection["head"]
    final = json.loads(FINAL.read_text())
    assert sha(FINAL) == selection["final_v1_result_sha256"]
    game = selection["game_paths"]
    assert len(game) == 16 and sorted(p for p in paths if p.startswith("game/")) == sorted(game)
    game_rows = []
    for path in game:
        row={"path":path,"live_sha256":verified[path],"final_before":final["before"]["files"][path],"final_after":final["after"]["files"][path]}
        row["matches_final"] = row["live_sha256"] == row["final_before"] == row["final_after"]
        game_rows.append(row)
    protected=[]
    assert len(selection["protected"]) == 17
    for expected in selection["protected"]:
        path=expected["path"]
        row={"path":path,"head_blob":git("rev-parse","HEAD:"+path),"index_blob":git("rev-parse",":"+path),
            "working_clean_blob":git("hash-object","--path="+path,path),"raw_sha256":sha(ROOT/path)}
        row["matches_selection"] = all(row[k] == expected[k] for k in ("head_blob","index_blob","working_clean_blob","raw_sha256"))
        row["three_blobs_equal"] = len({row[k] for k in ("head_blob","index_blob","working_clean_blob")}) == 1
        row["excluded_from_landing"] = path not in paths and path not in pathspec
        protected.append(row)
    excluded_overlap = sorted(set(selection["excluded_paths"]) & set(pathspec))
    banned = {
        "new_v2_operator_revision": "design/astra/work/vulkan_composed/revisions/terminal_operator_view_01/",
        "rgb8_proposal": "design/astra/work/rgb8",
        "harukiya_coverage_proposal": "design/astra/work/harukiya_coverage/",
        "f01_reconstruction_proposal": "design/astra/work/f01_reconstruction_review/",
    }
    banned_hits = {name:[p for p in pathspec if p.lower().startswith(prefix.lower())] for name,prefix in banned.items()}
    sensitive_names = [p for p in pathspec if any(t in p.lower() for t in ("c34ad283", "46d40", "m11c1", "m11c2", "rgb8", "harukiya_coverage", "terminal_operator_view"))]
    profiles = [p for p in paths if any(part.lower() in ("appdata","__pycache__","runtime_userdata") for part in Path(p).parts)]

    # Bounded result-map interpretation only: direct SHA256 artifact maps on
    # top-level JSON objects whose filename names a result. Other nested/custom
    # schemas are listed as outside this review, never silently certified.
    tracked = set(subprocess.check_output(["git","-C",str(ROOT),"ls-files","-z"]).decode().split("\0"))
    maps=[]; issues=[]; parse_issues=[]; missing_maps=[]
    for relative in paths:
        p = ROOT / relative
        if p.suffix != ".json" or "result" not in p.stem.lower(): continue
        try: value=json.loads(p.read_text(encoding="utf-8-sig"))
        except (ValueError,UnicodeError) as error:
            parse_issues.append({"path":relative,"error":str(error)});continue
        if not isinstance(value,dict): continue
        artifacts=value.get("artifacts")
        declared_sizes={}
        artifact_format="direct_sha256_map"
        if isinstance(artifacts,list) and artifacts and all(isinstance(x,dict)
                and isinstance(x.get("path"),str) and isinstance(x.get("sha256"),str)
                and re.fullmatch(r"[0-9a-f]{64}",x["sha256"]) for x in artifacts):
            assert len({x["path"] for x in artifacts}) == len(artifacts), relative
            declared_sizes={x["path"]:x["bytes"] for x in artifacts if type(x.get("bytes")) is int}
            artifacts={x["path"]:x["sha256"] for x in artifacts}
            artifact_format="named_path_sha256_rows"
        if not isinstance(artifacts,dict) or not artifacts:
            missing_maps.append({"path":relative,"schema":value.get("schema"),"reason":"no_nonempty_direct_artifact_map"});continue
        if not all(isinstance(k,str) and isinstance(v,str) and re.fullmatch(r"[0-9a-f]{64}",v) for k,v in artifacts.items()):
            missing_maps.append({"path":relative,"schema":value.get("schema"),"reason":"custom_non_direct_sha256_artifact_schema"});continue
        rows=[]
        for key,expected in artifacts.items():
            target=Path(key)
            if not target.is_absolute(): target=p.parent/target
            target=target.resolve()
            row={"artifact":key,"expected":expected}
            if not target.is_relative_to(ROOT.resolve()):
                row.update(status="outside_canonical_root_unresolved",resolved=str(target))
            elif not target.is_file():
                row.update(status="missing",resolved=target.relative_to(ROOT).as_posix())
            else:
                rel=target.relative_to(ROOT).as_posix()
                actual=verified.get(rel) or sha(target)
                row.update(resolved=rel,actual=actual,selected=rel in paths,already_tracked=rel in tracked)
                row["status"] = "hash_mismatch" if actual != expected else "verified_selected" if rel in paths else "verified_already_tracked" if rel in tracked else "verified_bytes_but_unselected_untracked"
                if key in declared_sizes:
                    row.update(declared_bytes=declared_sizes[key],actual_bytes=target.stat().st_size)
                    if row["actual_bytes"] != row["declared_bytes"]: row["status"]="byte_size_mismatch"
            if row["status"] not in ("verified_selected","verified_already_tracked"):
                issues.append({"result":relative,**row})
            rows.append(row)
        maps.append({"path":relative,"schema":value.get("schema"),"artifact_format":artifact_format,"artifact_count":len(rows),"entries":rows})
    report={"schema":"astra.independent.renderer-material-selection-review.v1","head":head,
        "selection_sha256":SELECTION_SHA,"pathspec_sha256":sha(LANDING/"paths.nul"),
        "selected_count":len(paths),"pathspec_count":len(pathspec),"verified_raw_count":len(verified),"raw_bytes_hashed":total_bytes,
        "raw_hash_failures":failures,"game_source_checks":game_rows,"protected_checks":protected,
        "excluded_overlap":excluded_overlap,"excluded_proposal_prefix_hits":banned_hits,
        "sensitive_name_hits_for_manual_review":sensitive_names,"profile_or_bytecode_hits":profiles,
        "index_staged_paths_observed":git("diff","--cached","--name-only").splitlines(),
        "result_artifact_maps":maps,"result_artifact_reference_issues":issues,
        "result_json_parse_issues":parse_issues,"other_result_schemas_not_certified":missing_maps,
        "scope_limit":"No generic schema completeness, recursive reference closure, acceptance promotion, or future-state evidence claim. Artifact keys are interpreted relative to their named result file unless absolute; uncertain custom resolution is reported for review.",
        "selection_unchanged_after_verification":sha(LANDING/"selection.json")==SELECTION_SHA}
    (HERE/"review.json").write_text(json.dumps(report,indent=2)+"\n")
    print(json.dumps({k:v for k,v in report.items() if k not in ("result_artifact_maps","game_source_checks","protected_checks")}
        | {"game_all_match":all(x["matches_final"] for x in game_rows),"protected_all_match":all(x["matches_selection"] and x["three_blobs_equal"] and x["excluded_from_landing"] for x in protected),
           "result_maps":len(maps),"artifact_references":sum(len(x["entries"]) for x in maps)},indent=2))


if __name__ == "__main__": main()
