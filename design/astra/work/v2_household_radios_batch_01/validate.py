"""Radio batch source preservation/repeatability. Does not run Godot."""
import hashlib
import importlib.util
import json
import math
from pathlib import Path
import subprocess

ROOT=Path(__file__).resolve().parents[4]
OUT=Path(__file__).resolve().parent
BASE="1c80053"


def load(path):return json.loads((ROOT/path).read_text(encoding="utf-8"))
def old(path):return json.loads(subprocess.check_output(["git","show",BASE+":"+path],cwd=ROOT))
def sha(path):return hashlib.sha256((ROOT/path).read_bytes()).hexdigest()


def main():
    spec=importlib.util.spec_from_file_location("radio_batch",OUT/"build.py")
    builder=importlib.util.module_from_spec(spec);spec.loader.exec_module(builder)
    ids={p[0] for p in builder.PLACEMENTS}
    furniture_path="game/data/orison_v2/domestic_furniture.json"
    furniture=load(furniture_path);original=old(furniture_path)
    assert [r for r in furniture["furniture"] if r["id"] not in ids]==original["furniture"]
    assert len(furniture["furniture"])==len(original["furniture"])+4
    materials=load("game/data/runtime_material_sets.json")["materials"]
    for r in furniture["furniture"]:
        if r["id"] not in ids:continue
        for s in r["surfaces"]:
            assert s["material"] in materials
            assert len(s["vertices"])==len(s["normals"]) and len(s["vertices"])%9==0
            assert all(math.isfinite(v) for v in s["vertices"]+s["normals"])
    layout_path="game/data/orison_v2_blockout.json"
    layout=load(layout_path);original_layout=old(layout_path)
    assert len(layout["anchors"])==len(original_layout["anchors"])+8
    added=ids | {"DomesticRadio_"+unit+"_STANCE" for unit in builder.STANCES}
    layout["anchors"]=[a for a in layout["anchors"] if a["id"] not in added]
    assert layout==original_layout
    protected=["game/data/domestic_radios.json","game/data/runtime_material_sets.json",
               "game/data/orison_v2/domestic_fittings.json","game/data/orison_v2/domestic_surface_props.json",
               "game/data/orison_v2/room_lighting.json","game/data/orison_v2/case_one_placement.json",
               "game/data/orison_v2/mina_routine.json"]
    for path in protected:assert load(path)==old(path),path
    shared=["game/scripts/props/domestic_radio_prop.gd","game/scripts/props/functional_prop.gd",
            "game/scripts/audio/prop_audio.gd","game/scripts/audio/audio_policy.gd","game/project.godot",
            "game/scripts/building/broadcast_director.gd"]
    for path in shared:
        assert (ROOT/path).read_bytes().replace(b'\r\n',b'\n')==subprocess.check_output(["git","show",BASE+":"+path],cwd=ROOT).replace(b'\r\n',b'\n'),path
    assert (ROOT/"game/assets/audio/freesound/processed/mechanical/line_murmur_loop.ogg").is_file()
    generated=[furniture_path,layout_path,"game/data/orison_v2/domestic_radios.json",
               "design/astra/work/v2_household_radios_batch_01/receipt.json"]
    before={p:sha(p) for p in generated}
    builder.build(apply=True)
    assert before=={p:sha(p) for p in generated},"regeneration changed bytes"
    result=dict(status="SOURCE_PASS_RUNTIME_PENDING",godot="NOT_RUN",base_head=BASE,
                old_furniture_preserved=57,anchors_added=8,protected_json=protected,
                shared_owners_unchanged=shared,programme_asset_exists=True,regeneration_sha256=before,
                limits="Source proof only; prepared engine targeting/audio/lifetime tests have not run.")
    (OUT/"source_validation.json").write_text(json.dumps(result,indent=2)+"\n",encoding="utf-8")
    print("PASS: source preservation, programme asset and byte-identical regeneration")


if __name__=="__main__":main()
