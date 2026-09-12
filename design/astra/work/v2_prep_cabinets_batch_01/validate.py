"""Source-only preservation and regeneration for cabinets and specialist devices."""
import hashlib
import importlib.util
import json
import math
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[4]
OUT = Path(__file__).resolve().parent
BASE = "2973f02"
IDS = {u + "_prep_cabinet" for u in ["2A", "2B", "3B", "4B"]} | {"2A_deck", "3B_radio"}


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
    original = json.loads(old(furniture_path))
    assert len(furniture["furniture"]) == 67
    assert [r for r in furniture["furniture"] if r["id"] not in IDS] == original["furniture"]
    assert {r["id"] for r in furniture["furniture"] if r["id"] in IDS} == IDS
    materials = load("game/data/runtime_material_sets.json")["materials"]
    triangles = 0
    for record in furniture["furniture"]:
        if record["id"] not in IDS:
            continue
        for surface in record["surfaces"]:
            assert surface["material"] in materials
            values, normals = surface["vertices"], surface["normals"]
            assert len(values) == len(normals) and len(values) % 9 == 0
            assert all(math.isfinite(v) for v in values + normals)
            for i, value in enumerate(values):
                assert record["bounds"][0][i % 3] - 1e-6 <= value <= record["bounds"][1][i % 3] + 1e-6
            triangles += len(values) // 9
    assert triangles == 756
    layout = load(layout_path)
    original_layout = json.loads(old(layout_path))
    assert len(layout["anchors"]) == len(original_layout["anchors"]) + 10
    additions = IDS | {u + "_prep_cabinet_STANCE" for u in ["2A", "2B", "3B", "4B"]}
    layout["anchors"] = [a for a in layout["anchors"] if a["id"] not in additions]
    assert layout == original_layout
    protected = [
        "game/data/domestic_radios.json", "game/data/runtime_material_sets.json",
        "game/data/orison_v2/domestic_radios.json", "game/data/orison_v2/domestic_fittings.json",
        "game/data/orison_v2/domestic_surface_props.json", "game/data/orison_v2/room_lighting.json",
        "game/data/orison_v2/case_one_placement.json", "game/data/orison_v2/mina_routine.json",
        "game/scripts/props/baked_furniture_interaction.gd", "game/scripts/props/domestic_radio_prop.gd",
        "game/scripts/props/functional_prop.gd", "game/scripts/audio/prop_audio.gd",
        "game/scripts/audio/audio_policy.gd", "game/scripts/building/broadcast_director.gd",
        "game/project.godot",
    ]
    for path in protected:
        assert (ROOT / path).read_bytes().replace(b"\r\n", b"\n") == old(path).replace(b"\r\n", b"\n"), path
    generated = [furniture_path, layout_path] + [
        "design/astra/work/" + batch + "/receipt.json"
        for batch in ["v2_prep_cabinets_batch_01", "v2_specialist_devices_batch_01"]
    ]
    before = {p: sha(p) for p in generated}
    for batch in ["v2_prep_cabinets_batch_01", "v2_specialist_devices_batch_01"]:
        spec = importlib.util.spec_from_file_location(batch, ROOT / "design/astra/work" / batch / "build.py")
        builder = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(builder)
        builder.build(apply=True)
    assert before == {p: sha(p) for p in generated}, "regeneration changed bytes"
    result = dict(status="SOURCE_PASS_RUNTIME_PENDING", godot="NOT_RUN", base_head=BASE,
                  old_furniture_preserved=61, furniture_added=6, anchors_added=10,
                  source_triangles_added=756, runtime_cabinet_triangles=192,
                  protected_owners=protected, regeneration_sha256=before,
                  limits="Source-only proof. Prepared physics, audio, material, teardown and malformed-input checks require Godot; visual/performance acceptance pending.")
    (OUT / "source_validation.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print("PASS: 61 old furniture preserved, 6 additions, 10 anchors, bounded material geometry and repeatable generation")


if __name__ == "__main__":
    main()
