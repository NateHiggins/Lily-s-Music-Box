"""Reproducibility and source-preservation checks for this fixed batch."""
import hashlib
import importlib.util
import json
from pathlib import Path
import subprocess
import sys

ROOT=Path(__file__).resolve().parents[4]
OUT=Path(__file__).resolve().parent
BASE="0a92e59"


def load(path):return json.loads((ROOT/path).read_text(encoding="utf-8"))
def old(path):return json.loads(subprocess.check_output(["git","show",BASE+":"+path],cwd=ROOT))
def sha(path):return hashlib.sha256((ROOT/path).read_bytes()).hexdigest()


def main():
    spec=importlib.util.spec_from_file_location("category_build",OUT/"build.py")
    build=importlib.util.module_from_spec(spec);spec.loader.exec_module(build)
    ids={p[0] for p in build.PLACEMENTS}
    furniture_path="game/data/orison_v2/domestic_furniture.json"
    furniture=load(furniture_path); original=old(furniture_path)
    assert [r for r in furniture["furniture"] if r["id"] not in ids]==original["furniture"]
    assert len(furniture["furniture"])==len(original["furniture"])+10
    layout_path="game/data/orison_v2_blockout.json"
    layout=load(layout_path); original_layout=old(layout_path)
    assert len(layout["anchors"])==len(original_layout["anchors"])+10
    layout["anchors"]=[a for a in layout["anchors"] if a["id"] not in ids]
    assert layout==original_layout,"unrelated layout/anchor changes"
    for path in ["art/data/runtime_material_sets.json","game/data/runtime_material_sets.json"]:
        contract=load(path);previous=old(path)
        assert set(contract["materials"])-set(previous["materials"])=={"timber","plywood"}
        for key in previous["materials"]: assert contract["materials"][key]==previous["materials"][key],key
        assert contract["visual_locks"]==previous["visual_locks"]
    protected=["game/data/orison_v2/domestic_fittings.json","game/data/orison_v2/domestic_surface_props.json",
               "game/data/orison_v2/room_lighting.json","game/data/orison_v2/case_one_placement.json",
               "game/data/orison_v2/mina_routine.json"]
    for path in protected: assert load(path)==old(path),path
    # All new surfaces fit their source bounds after the coffee-table floor
    # correction. No phantom zero-height box can enter the runtime loader.
    for r in furniture["furniture"]:
        if r["id"] not in ids:continue
        assert all(r["bounds"][0][i]<r["bounds"][1][i] for i in range(3))
        for s in r["surfaces"]:
            for i,v in enumerate(s["vertices"]):assert r["bounds"][0][i%3]-1e-9<=v<=r["bounds"][1][i%3]+1e-9
        if r["kind"]=="coffee":assert r["bounds"][0][1]==0
    generated=[furniture_path,layout_path,"art/data/runtime_material_sets.json","game/data/runtime_material_sets.json",
               "game/scripts/generated/material_sets.gd","design/astra/work/v2_storage_tables_boards_batch_01/receipt.json"]
    before={p:sha(p) for p in generated}
    build.build(apply=True)
    subprocess.run([sys.executable,"art/tools/generate_runtime_materials.py"],cwd=ROOT,check=True)
    assert before=={p:sha(p) for p in generated},"regeneration changed bytes"
    result=dict(status="SOURCE_PASS_RUNTIME_PENDING",godot="NOT_RUN",base_head=BASE,old_furniture_preserved=47,
                anchors_added=10,old_materials_preserved=49,new_material_keys=["timber","plywood"],
                protected_json_unchanged=protected,regeneration_sha256=before,
                limits="Source preservation, bounds and reproducibility only; no engine or visual acceptance.")
    (OUT/"source_validation.json").write_text(json.dumps(result,indent=2)+"\n",encoding="utf-8")
    print("PASS: furniture/layout/material preservation, visual bounds and byte-identical regeneration")


if __name__=="__main__":main()
