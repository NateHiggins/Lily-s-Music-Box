"""Export the expanded arcade's source-owned storefront trim to a private folder."""
import argparse
import collections
import json
from pathlib import Path
import shutil
import sys

import bmesh
import bpy
from mathutils import Matrix

sys.path.insert(0, str(Path(__file__).resolve().parent))
from build_arcade_plaza import ROOT, digest
from arcade_storefront_geometry import build
from fabrication_native_batch import export, material, partition


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", required=True, type=Path)
    args = parser.parse_args(sys.argv[sys.argv.index("--")+1:])
    output = args.out.resolve()
    if output.is_relative_to(ROOT) or (output.exists() and any(output.iterdir())):
        raise ValueError("Use an empty private output directory")
    for name in ("art/blender", "game/assets/props", "game/assets/building/textures"):
        (output / name).mkdir(parents=True, exist_ok=True)

    layout_path = ROOT / "game/data/building_layout.json"
    plan_path = ROOT / "art/data/arcade_plaza/source_plan.json"
    catalog_path = ROOT / "game/data/runtime_material_sets.json"
    layout, plan, catalog = [json.loads(p.read_text(encoding="utf-8"))
                             for p in (layout_path, plan_path, catalog_path)]
    catalog = catalog["materials"]
    origin = plan["source_origin_blender_m"]
    stocks = build(layout, plan)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.preferences.filepaths.save_version = 0
    scene = bpy.context.scene
    scene.unit_settings.system = "METRIC"
    editable = bpy.data.collections.new("Original storefront identities")
    draws = bpy.data.collections.new("Storefront material partitions")
    scene.collection.children.link(editable)
    scene.collection.children.link(draws)

    finishes, materials = {}, {}
    groups = collections.defaultdict(list)
    for stock in stocks:
        key = stock["source"]["mat"]
        catalog_key = stock["catalog_key"]
        if key not in finishes:
            recipe = dict(catalog_key=catalog_key, tint=stock["tint"], normal=.18, pigment=1.,
                          roughness=catalog[catalog_key].get("roughness_multiplier", 1.))
            finishes[key] = recipe
            materials[key] = material(ROOT, "ArcadeStorefront_"+key, recipe, catalog)
        points = [(origin[0]+u, origin[1]-v, origin[2]+h) for u,v,h in stock["vertices"]]
        mesh = bpy.data.meshes.new(stock["name"])
        mesh.from_pydata(points, [], stock["faces"])
        mesh.update()
        bm = bmesh.new()
        bm.from_mesh(mesh)
        bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
        assert all(edge.is_manifold for edge in bm.edges) and bm.calc_volume(signed=True)>0, stock["name"]
        bm.to_mesh(mesh)
        bm.free()
        obj = bpy.data.objects.new(stock["name"], mesh)
        editable.objects.link(obj)
        groups[stock["owner"], key].append(obj)

    parts = []
    for (owner, key), objects in sorted(groups.items()):
        name = "ArcadeStorefront_"+owner+"_"+key
        obj = partition(draws, name, objects, finishes[key], materials[key], Matrix.Identity(4), catalog)
        parts.append(dict(name=name, owner=owner, material=key, triangles=len(obj.data.polygons)))
    for image in bpy.data.images:
        if image.source == "FILE":
            target = output / "game/assets/building/textures" / Path(image.filepath).name
            shutil.copyfile(bpy.path.abspath(image.filepath), target)
            image.filepath = str(target)
    editable.hide_render = True
    editable.hide_viewport = True
    scene.view_layers[0].update()
    stamp = "arcade_storefront_identity"
    derivative = export(output, stamp, draws, material_names_only=True)
    assert derivative["status"] == "PASS" and derivative["triangles"] == sum(p["triangles"] for p in parts)
    bindings = [layout_path, plan_path, catalog_path]
    bindings += [Path(__file__).with_name(name) for name in (
        "build_arcade_storefront_identity.py", "arcade_storefront_geometry.py", "build_arcade_plaza.py",
        "fabrication_native_batch.py", "fabrication_chart_batch.py", "fabrication_grain.py",
        "fabrication_uvs.py", "fabrication_normals.py", "check_exported_tangents.py")]
    bindings += [ROOT / "game/assets/building/textures" / name for key in finishes
                 for name in catalog[finishes[key]["catalog_key"]]["files"]]
    report = dict(evidence_class="INERT", stocks=stocks, parts=parts, materials=finishes,
                  source_bindings={p.relative_to(ROOT).as_posix(): digest(p) for p in bindings},
                  glb_sha256=digest(output / f"game/assets/props/{stamp}.glb"),
                  blend_sha256=digest(output / f"art/blender/{stamp}.blend"), derivatives=derivative)
    (output / "STOREFRONT_NATIVE.json").write_text(json.dumps(report, indent=2)+"\n", encoding="utf-8", newline="\n")
    print("ARCADE STOREFRONT EXPORT PASS", len(stocks), "closed stocks;", derivative["triangles"], "triangles")


if __name__ == "__main__":
    main()
