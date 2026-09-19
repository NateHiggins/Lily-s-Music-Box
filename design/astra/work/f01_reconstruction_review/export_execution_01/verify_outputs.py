"""Independent data/byte checks after two exports; imports no C1/generator code."""
from pathlib import Path, PurePosixPath
from collections import defaultdict
import hashlib
import json
import sys

HERE=Path(__file__).resolve().parent
ROOT=next(p for p in HERE.parents if (p/"game/project.godot").is_file())


def sha(path):
    h=hashlib.sha256()
    with path.open("rb") as f:
        for data in iter(lambda:f.read(1048576),b""):h.update(data)
    return h.hexdigest()


def read(path):return json.loads(path.read_text(encoding="utf-8-sig"))


def inside(base,relative):
    p=Path(relative)
    if not p.is_absolute():p=base/p
    p=p.resolve()
    assert p.is_relative_to(base.resolve()) and p.is_file(),str(p)
    return p


def check_output(output,expected_catalog,protected):
    transaction_path=output/"receipts/floor01_owner_first_transaction.json"
    transaction=read(transaction_path)
    assert transaction["status"]=="PASS" and transaction["disposable_root"]==str(output)
    bound_json=set()
    for relative,row in transaction["artifacts"].items():
        assert row["relative_path"]==relative
        p=inside(output,relative);assert sha(p)==row["sha256"]
        value=read(p)
        assert value["schema"]==row["schema"] and value["status"]==row["status"]=="PASS"
        assert value["run_id"]==transaction["run_id"] and value["disposable_root"]==str(output)
        bound_json.add(p)
    candidate=transaction["candidate"]
    for key in ("descriptor","binary","generated_lineage"):
        p=inside(output,candidate[key+"_path"]);assert sha(p)==candidate[key+"_sha256"]
    generated_lineage=inside(output,candidate["generated_lineage_path"])
    assert {p.resolve() for p in output.rglob("*.json")}==bound_json|{generated_lineage,transaction_path.resolve()}
    lineage=read(output/"receipts/floor01_owner_first_lineage.json")
    assert not lineage["unresolved_lineage_records"] and lineage["spatial_inference_used"] is False
    expected_rows={r["source_locator"]:r for r in expected_catalog["records"]}
    actual_rows={r["source_locator"]:r for r in lineage["source_records"]}
    assert len(lineage["source_records"])==len(actual_rows)==len(expected_rows)==5286
    for locator,expected in expected_rows.items():
        assert all(actual_rows[locator][key]==expected[key] for key in
            ("source_id","owner_cell","source_record_sha256","collection")),locator
    owners=expected_catalog["owner_cells"]
    cells=transaction["cells"]
    assert len(cells)==17 and {x["id"] for x in cells}==set(owners) and "CELL_LEGACY_MIXED" not in owners
    documents={};deterministic={}
    for cell in cells:
        for suffix in ("gltf","bin"):
            p=inside(output,cell[suffix+"_path"]);assert sha(p)==cell[suffix+"_sha256"]
            deterministic[cell[suffix+"_path"]]=sha(p)
        documents[cell["id"]]=read(output/cell["gltf_path"])
        assert documents[cell["id"]]["asset"]["extras"]["orison_m11c1_owner_first"]["cell"]==cell["id"]
    for key in ("descriptor","binary"):
        p=inside(output,candidate[key+"_path"])
        deterministic[p.relative_to(output).as_posix()]=sha(p)
    assert len(deterministic)==36
    source_owner={r["source_id"]:r["owner_cell"] for r in lineage["source_records"]}
    supplements={"F01_GENERATED_STAIR_ATRIUM":"CELL_ORISON_F01_INTERIOR",
        "F01_GENERATED_FACADE_RAINWATER":"CELL_ORISON_FACADE_SHELL",
        "F01_GENERATED_TRAFFIC_WEAR":"CELL_ORISON_F01_INTERIOR"}
    assert {r["source_id"]:r["owner_cell"] for r in lineage["generated_sources"]}==supplements
    source_owner.update(supplements)
    derived_aliases=defaultdict(set)
    for contribution in lineage["contributions"]:
        target=contribution["output"];owner=target["cell_id"]
        assert source_owner[contribution["source_id"]]==owner
        document=documents[owner];node=int(target["node_index"]);mesh=int(target["mesh_index"])
        assert document["nodes"][node]["mesh"]==mesh
        primitive=document["meshes"][mesh]["primitives"][int(target["primitive_index"])]
        index_count=int(document["accessors"][primitive["indices"]]["count"])
        assert index_count%3==0 and 0<=target["triangle_start"]<=target["triangle_start"]+target["triangle_count"]<=index_count//3
        derived_aliases[contribution["legacy_compatibility_identity"]].add((owner,node,mesh))
    aliases={k:{(r["cell_id"],r["node_index"],r["mesh_index"]) for r in rows} for k,rows in lineage["legacy_aliases"].items()}
    assert aliases==dict(derived_aliases)
    legacy_names={n["name"] for n in protected["nodes"] if "mesh" in n}
    assert set(aliases)==legacy_names and len(aliases)==531
    assert sum(len(v)>1 for v in aliases.values())==47
    semantics=lineage["semantic_owners"]
    assert len(semantics)==len({x["identity"] for x in semantics})==189
    semantic_map={x["identity"]:x for x in semantics}
    marker_ids={r["source_id"] for r in expected_rows.values() if r["collection"]=="markers"}
    assert set(semantic_map)==marker_ids|{"THRESHOLD_SHOP_BODEGA_FRONT"}
    for identity in marker_ids:assert semantic_map[identity]["owner_cell"]==source_owner[identity]
    assert semantic_map["THRESHOLD_SHOP_BODEGA_FRONT"]["owner_cell"]=="CELL_SHOP_BODEGA"
    assert semantic_map["F01_BODEGA_DOOR"]["source_id"]!=semantic_map["THRESHOLD_SHOP_BODEGA_FRONT"]["source_id"]
    primitives=triangles=vertices=0
    for document in documents.values():
        for mesh in document["meshes"]:
            for primitive in mesh["primitives"]:
                assert primitive.get("mode",4)==4
                primitives+=1;count=document["accessors"][primitive["indices"]]["count"]
                assert count%3==0;triangles+=count//3
                vertices+=document["accessors"][primitive["attributes"]["POSITION"]]["count"]
    assert (primitives,triangles,vertices)==(609,183726,345536),(primitives,triangles,vertices)
    # Recompute bytes and addressability independently. Canonical geometry,
    # transforms, collision/material payload equivalence remains the separately
    # bound C1 implementation's proof, not falsely advertised as a new parser.
    equivalence=read(output/"receipts/floor01_owner_first_equivalence.json")
    assert equivalence["all_checks_passed"] and all(equivalence["checks"].values())
    for p in output.rglob("*.gltf"):
        document=read(p)
        for item in document.get("buffers",[])+document.get("images",[]):
            uri=item.get("uri")
            if uri and not uri.startswith("data:"):inside(output,str((p.parent/uri).resolve()))
    return {"deterministic_36":deterministic,"lineage_identity":{k:lineage[k] for k in
        ("source_records","generated_sources","contributions","legacy_aliases","semantic_owners")},
        "recomputed_counts":{"cells":17,"sources":5286,"primitives":primitives,"triangles":triangles,"vertices":vertices,"aliases":531,"multi_target_aliases":47,"semantics":189},
        "transaction_sha256":sha(transaction_path),"all_output_hashes":{p.relative_to(output).as_posix():sha(p) for p in output.rglob("*") if p.is_file()}}


def main():
    plan=read(HERE/"plan.json");evidence=ROOT/plan["evidence_root"]
    assert not (evidence/"comparison.json").exists()
    binding=read(evidence/"binding.json")
    assert binding["plan_sha256"]==sha(HERE/"plan.json")
    assert binding["verifier_sha256"]==sha(Path(__file__))
    for key,name in (("bridge_sha256","child_capture_bridge.py"),("outer_sha256","outer.py")):
        assert binding[key]==sha(HERE/name)
    for relative,row in binding["inputs"]["files"].items():
        p=ROOT/relative
        assert p.is_file()==row["exists"] and (not row["exists"] or sha(p)==row["sha256"]),relative
    catalog=read(ROOT/"art/data/m11c1/floor01_source_ownership.json")
    protected=read(ROOT/"game/assets/building/floor_01.gltf")
    result=[]
    for mode in ("a","b"):
        process=read(evidence/mode/"outer_result.json")
        assert process["outer_contract_exit"]==0 and process["empty_process_census_after"]
        required={"before.json","after.json","before_process_census.json","after_process_census.json",
            "config.json","command.json","environment.json","controller.stdout.raw","controller.stderr.raw",
            "blender.stdout.raw","blender.stderr.raw","blender_child.json","controller_bridge.json"}
        assert required<=set(process["artifacts"]),"required raw/source evidence omitted"
        for rel,expected in process["artifacts"].items():assert sha(evidence/mode/rel)==expected
        assert read(evidence/mode/"before.json")==read(evidence/mode/"after.json")==binding["inputs"]
        for name in ("before_process_census.json","after_process_census.json"):
            assert read(evidence/mode/name)["empty"]
        output=Path(plan["outputs"][mode]).resolve()
        child=read(evidence/mode/"blender_child.json")
        raw=(evidence/mode/"blender.stdout.raw").read_bytes()
        marker="M11C1_OWNER_FIRST_GENERATION="
        summaries=[line[len(marker):] for line in raw.decode("utf-8",errors="replace").splitlines() if line.startswith(marker)]
        assert len(summaries)==1 and child["actual_blender_exit"]==0
        summary=json.loads(summaries[0])
        inside(output,summary["candidate_gltf"]);inside(output,summary["generated_lineage"])
        original_process=read(output/"candidate/blender_generation_process.json")
        assert original_process["exit_code"]==0 and original_process["command"]==child["command"]
        assert original_process["stdout_sha256"]==child["stdout_decoded_utf8_sha256"]
        assert original_process["stderr_sha256"]==child["stderr_decoded_utf8_sha256"]
        checked=check_output(output,catalog,protected)
        checked["raw_child_process"]={"marker_count":1,"actual_blender_exit":0,
            "raw_stdout_sha256":sha(evidence/mode/"blender.stdout.raw"),
            "raw_stderr_sha256":sha(evidence/mode/"blender.stderr.raw"),
            "raw_stderr_bytes":(evidence/mode/"blender.stderr.raw").stat().st_size,
            "diagnostic_review":"Raw streams preserved; this structural verifier is not a general Blender diagnostic classifier."}
        result.append(checked)
    assert result[0]["deterministic_36"]==result[1]["deterministic_36"],"preserve non-deterministic output; do not normalize glTF/bin differences"
    assert result[0]["lineage_identity"]==result[1]["lineage_identity"],"ownership/alias lineage drift"
    receipt={"status":"TWO_EXPORT_BYTE_OWNERSHIP_ALIAS_CHECKS_PASS_HUMAN_PENDING","runs":result,
        "plan_sha256":sha(HERE/"plan.json"),"verifier_sha256":sha(Path(__file__)),"binding_sha256":sha(evidence/"binding.json"),
        "scope":"Independent file hashes, catalog ownership, actual cell addressability, alias completeness and count checks. Existing exact C1 core still supplies canonical collision/material/transform equivalence; no provider, selector, traversal, residency or human acceptance claim."}
    (evidence/"comparison.json").write_text(json.dumps(receipt,indent=2)+"\n")
    print(json.dumps({"status":receipt["status"],"counts":result[0]["recomputed_counts"]},indent=2));return 0


if __name__=="__main__":raise SystemExit(main())
