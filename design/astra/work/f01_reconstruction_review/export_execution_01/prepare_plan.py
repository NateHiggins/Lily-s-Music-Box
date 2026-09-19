"""Enumerate the reviewed input closure without importing or running Blender code.

Only local small source/JSON inputs are read here; texture and binary content
hashes belong to the later, exclusive-lane bind action. No output is created.
"""
from pathlib import Path
import ast
import hashlib
import json
import shutil
import subprocess

HERE=Path(__file__).resolve().parent
ROOT=next(p for p in HERE.parents if (p/"game/project.godot").is_file())


def read(path):return json.loads(path.read_text(encoding="utf-8-sig"))
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    assert not (HERE/"plan.json").exists(),"preserve a sealed plan; make a new revision"
    inventory=read(HERE.parent/"source_inventory.json")
    manifest=read(HERE.parent/"source_replay_01/source_manifest.json")
    protected=[r["path"] for r in inventory["protected_17"]]
    sources={r["path"]:r["sha256"] for r in manifest["files"]}
    groups={"protected_17":protected,"clean_c1_source_10":sorted(sources),
        "generator_and_authored_inputs":["art/blender/scripts/build_orison.py","art/data/gen_layout.py",
            "art/data/material_catalog.json","art/textures/catalog_mapping.json",
            "game/data/orison_v2/exterior/regions.json"],
        "additional_readonly_assets":["game/assets/building/roof.gltf","game/assets/building/roof.bin",
            "art/blender/orison_master.blend"],
        "protected_f01_image_dependencies":[r["path"] for r in inventory["protected_floor01_image_dependencies"]],
        "catalog_base_and_metadata_choices":[],"overlay_presence_choices":[],
        "glass_presence_choices":["art/textures/generated/glass/roughness.png","art/textures/generated/glass/normal.png"],
        "fx_albedo_and_companion_choices":[],"f01_authored_wallfinish_choices":[],"f01_wallfinish_fallbacks":[]}
    mapping=read(ROOT/"art/textures/catalog_mapping.json")
    for key,relative in sorted(mapping.items()):
        if relative is None:continue
        base=Path("art/textures")/relative
        for name in ("albedo.png","roughness.png","normal.png","material.json","asset.json"):
            groups["catalog_base_and_metadata_choices"].append((base/name).as_posix())
        for name in ("albedo.png","roughness.png"):
            groups["overlay_presence_choices"].append((Path("art/textures/generated/_overlaid")/key/name).as_posix())
    tree=ast.parse((ROOT/"art/blender/scripts/build_orison.py").read_text(encoding="utf-8-sig"))
    definitions=[n for n in tree.body if isinstance(n,ast.Assign) and any(isinstance(t,ast.Name) and t.id=="FX_TEX" for t in n.targets)]
    assert len(definitions)==1
    fx=ast.literal_eval(definitions[0].value)
    for relative in fx.values():
        groups["fx_albedo_and_companion_choices"].append((Path("art/textures")/relative).as_posix())
        for suffix in ("_rough.png","_normal.png"):
            groups["fx_albedo_and_companion_choices"].append("art/textures/generated/fx/"+Path(relative).stem+suffix)
    for index in range(10):
        for kind in ("albedo","roughness","normal"):
            groups["f01_authored_wallfinish_choices"].append(f"art/textures/wall_finishes/f01_w{index:02}/{kind}.png")
            groups["f01_wallfinish_fallbacks"].append(f"game/assets/building/textures/T_wallfinish_f01_w{index:02}_{kind}.png")
    paths=sorted({p for values in groups.values() for p in values})
    for relative in paths:assert (ROOT/relative).resolve().is_relative_to(ROOT)
    blender=Path(shutil.which("blender") or "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe").resolve()
    assert blender.is_file()
    outputs={"a":"C:/OrisonF01Reconstruction/astra_77dc_export_a_01","b":"C:/OrisonF01Reconstruction/astra_77dc_export_b_01"}
    assert all(not Path(p).exists() for p in outputs.values())
    plan={"schema":"astra.f01.clean-c1-export-plan.v1","status":"PREPARED_UNRUN_REQUIRES_REVIEW_AND_EXCLUSIVE_LANE",
        "source_reference":manifest["source_reference"],"preparation_head":subprocess.check_output(["git","-C",str(ROOT),"rev-parse","HEAD"]).decode().strip(),
        "source_manifest_sha256":sha(HERE.parent/"source_replay_01/source_manifest.json"),
        "source_inventory_sha256":sha(HERE.parent/"source_inventory.json"),
        "exact_source_hashes":sources,"protected_paths":protected,"input_paths":paths,"input_groups":groups,
        "reviewed_input_hashes":{p:sha(ROOT/p) for p in groups["generator_and_authored_inputs"]+protected[:2]},
        "dependency_closure_reviewed":True,
        "dependency_closure_review":{"reviewer":"/root","scope":"Read-only source review of generator dynamic reads and every _image call family; no unlisted local module dependency found beyond exact C1/C0 files. Optional existence branches retained.",
            "generator_sha256":sha(ROOT/"art/blender/scripts/build_orison.py"),
            "adapter_sha256":sources["tools/m11c1_floor01_owner_first/generate_owner_first_candidate.py"]},
        "input_census_preparation_only":{"paths":len(paths),"existing_files":sum((ROOT/p).is_file() for p in paths),
            "absent_choices":sum(not (ROOT/p).is_file() for p in paths),"content_hashes":"Fresh content hashes deferred to exclusive-lane bind."},
        "blender":str(blender),"blender_preparation_stat":{"bytes":blender.stat().st_size,"mtime_ns":blender.stat().st_mtime_ns,
            "earlier_inventory_sha256":"e27fbfea8564aa645d4463cb0949695fd85562b9de6df9561b06859a1074adf7",
            "version_source":"Installed path label only; executable has not been launched by this preparation. Actual run stdout and freshly bound binary establish execution."},
        "blender_timeout_seconds":1200,"outputs":outputs,
        "evidence_root":"design/astra/evidence/f01_source_export/export_01",
        "authority":"Human-pending clean C1 reconstruction replay only; no production asset/provider/selector adoption.",
        "closure_scope":"All current catalog base candidates and both metadata choices, overlay presence choices, glass and FX optional pairs, exact F01 wallfinish authored/fallback choices and protected image dependencies. Existence and bytes are both bound; generator and adapter bytes define the branch set. gen_layout, roof and master blend are read-only protection additions, not executed inputs."}
    (HERE/"plan.json").write_text(json.dumps(plan,indent=2)+"\n")
    print(json.dumps({"status":plan["status"],"source_files":len(sources),"protected":len(protected),"input_census":plan["input_census_preparation_only"]}))


if __name__=="__main__":main()
