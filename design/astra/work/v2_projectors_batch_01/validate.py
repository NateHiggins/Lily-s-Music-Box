"""Projector batch preservation, bounded meshes, assets and repeatability."""
import hashlib
import importlib.util
import json
import math
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[4]
OUT = Path(__file__).resolve().parent
BASE = "55d2137"
IDS = {unit + "_projector_stand" for unit in ["2A", "3B", "4B"]}


def load(path):
    return json.loads((ROOT / path).read_text(encoding="utf-8"))


def old(path):
    return subprocess.check_output(["git", "show", BASE + ":" + path], cwd=ROOT)


def sha(path):
    return hashlib.sha256((ROOT / path).read_bytes()).hexdigest()


def main():
    furniture_path = "game/data/orison_v2/domestic_furniture.json"
    layout_path = "game/data/orison_v2_blockout.json"
    furniture = load(furniture_path)
    assert len(furniture["furniture"]) == 70
    assert [r for r in furniture["furniture"] if r["id"] not in IDS] == json.loads(old(furniture_path))["furniture"]
    materials = load("game/data/runtime_material_sets.json")["materials"]
    triangles = 0
    for record in furniture["furniture"]:
        if record["id"] not in IDS: continue
        for surface in record["surfaces"]:
            assert surface["material"] in materials
            values, normals = surface["vertices"], surface["normals"]
            assert len(values) == len(normals) and len(values) % 9 == 0
            assert all(math.isfinite(v) for v in values + normals)
            for i, value in enumerate(values):
                assert record["bounds"][0][i % 3] - 1e-6 <= value <= record["bounds"][1][i % 3] + 1e-6
            triangles += len(values) // 9
    layout = load(layout_path)
    original_layout = json.loads(old(layout_path))
    assert len(layout["anchors"]) == len(original_layout["anchors"]) + 6
    additions = IDS | {unit + "_tv_STANCE" for unit in ["2A", "3B", "4B"]}
    layout["anchors"] = [a for a in layout["anchors"] if a["id"] not in additions]
    assert layout == original_layout
    media = load("game/data/orison_v2/domestic_projectors.json")["projectors"]
    original = load("game/data/building_layout.json")
    markers = {r["id"] for floor in original["floors"] for r in floor.get("furniture", [])
               if r.get("asm") == "tv" and r["id"].split("_")[0] in ["2A", "2B", "3B", "4B"]}
    assert {r["id"] for r in media} == markers == {"2A_tv", "3B_tv", "4B_tv"}
    clip_paths = ["game/assets/video/clips/" + r["reel"] + ".ogv" for r in media]
    for path in clip_paths: assert (ROOT / path).is_file()
    protected = [
        "game/data/domestic_radios.json", "game/data/runtime_material_sets.json",
        "game/data/orison_v2/domestic_radios.json", "game/data/orison_v2/domestic_fittings.json",
        "game/data/orison_v2/domestic_surface_props.json", "game/data/orison_v2/room_lighting.json",
        "game/data/orison_v2/case_one_placement.json", "game/data/orison_v2/mina_routine.json",
        "game/scripts/props/projector_prop.gd", "game/scripts/props/tv_prop.gd",
        "game/scripts/audio/prop_audio.gd", "game/scripts/building/broadcast_director.gd",
        "game/project.godot", "game/assets/video/clips/clips.json", "game/shaders/projected_film.gdshader",
    ]
    for path in protected:
        assert (ROOT / path).read_bytes().replace(b"\r\n", b"\n") == old(path).replace(b"\r\n", b"\n"), path
    generated = [furniture_path, layout_path, "game/data/orison_v2/domestic_projectors.json",
                 "design/astra/work/v2_projectors_batch_01/receipt.json"]
    before = {p: sha(p) for p in generated}
    spec = importlib.util.spec_from_file_location("projectors", OUT / "build.py")
    builder = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(builder)
    builder.build(apply=True)
    assert before == {p: sha(p) for p in generated}, "regeneration changed bytes"
    result = dict(status="SOURCE_PASS_RUNTIME_PENDING", godot="NOT_RUN", base_head=BASE,
                  old_furniture_preserved=67, stands_added=3, projectors_added=3, anchors_added=6,
                  stand_triangles=triangles, protected_owners=protected,
                  clip_sha256={p: sha(p) for p in clip_paths}, regeneration_sha256=before,
                  limits="Source-only proof; prepared targeting, playback, ray misses, reconstruction and teardown checks not run. No renderer/performance/visual acceptance.")
    (OUT / "source_validation.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print("PASS: old furniture and shared media preserved; three authored markers covered; assets and regeneration verified")


if __name__ == "__main__":
    main()
