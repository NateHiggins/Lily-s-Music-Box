"""Export the entrance threshold independently of the qualified arcade shell."""

import argparse
import json
from pathlib import Path
import shutil
import sys

import bmesh
import bpy
from mathutils import Matrix

sys.path.insert(0,str(Path(__file__).resolve().parent))
from arcade_entry_threshold import build
from build_arcade_plaza import ROOT, digest
from fabrication_native_batch import export, material, partition


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args(sys.argv[sys.argv.index("--")+1:])
    output = args.out.resolve()
    if output.is_relative_to(ROOT) or (output.exists() and any(output.iterdir())):
        raise ValueError("Use a fresh private output directory")
    for folder in ("art/blender", "game/assets/props", "game/assets/building/textures"):
        (output/folder).mkdir(parents=True)
    sources = [ROOT/name for name in (
        "game/data/building_layout.json", "art/data/arcade_plaza/source_plan.json",
        "game/data/orison_v2/exterior/street_frame.json", "game/data/runtime_material_sets.json")]
    layout, plan, street, catalog = [json.loads(p.read_text(encoding="utf-8")) for p in sources]
    stock = build(layout,plan,street)
    key = "public_floor"
    finish = plan["materials"][key]
    catalog = catalog["materials"]

    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.preferences.filepaths.save_version = 0
    scene = bpy.context.scene
    scene.unit_settings.system = "METRIC"
    editable = bpy.data.collections.new("Closed threshold stock")
    draws = bpy.data.collections.new("Gateway threshold export")
    scene.collection.children.link(editable)
    scene.collection.children.link(draws)
    mat = material(ROOT, "ArcadeThresholdTerrazzo", finish, catalog)
    mesh = bpy.data.meshes.new(stock["name"])
    mesh.from_pydata([(x,-z,y) for x,y,z in stock["godot_vertices"]],[],stock["faces"])
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    assert all(e.is_manifold for e in bm.edges) and bm.calc_volume(signed=True)>0
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new("EditableGatewayThreshold",mesh)
    editable.objects.link(obj)
    draw = partition(draws,stock["name"],[obj],finish,mat,Matrix.Identity(4),catalog)
    for image in bpy.data.images:
        if image.source == "FILE":
            target = output/"game/assets/building/textures"/Path(image.filepath).name
            shutil.copyfile(bpy.path.abspath(image.filepath),target)
            image.filepath = str(target)
    editable.hide_render = True
    editable.hide_viewport = True
    scene.view_layers[0].update()
    stamp = "arcade_entry_threshold"
    derivative = export(output,stamp,draws,material_names_only=True)
    assert derivative["status"] == "PASS" and derivative["triangles"] == len(draw.data.polygons) == 12
    asset = output/"game/assets/props"/(stamp+".glb")
    master = output/"art/blender"/(stamp+".blend")
    sources += [Path(__file__).resolve().with_name(name) for name in (
        "arcade_entry_threshold.py", "build_arcade_entry_threshold.py", "build_arcade_plaza.py",
        "fabrication_native_batch.py", "fabrication_chart_batch.py", "fabrication_normals.py",
        "fabrication_uvs.py", "fabrication_grain.py", "check_exported_tangents.py")]
    sources += [ROOT/"game/assets/building/textures"/name for name in catalog[finish["catalog_key"]]["files"]]
    result = dict(evidence_class="INERT", stock=stock, material=finish, derivatives=derivative,
                  glb_sha256=digest(asset), blend_sha256=digest(master),
                  source_bindings={p.relative_to(ROOT).as_posix():digest(p) for p in sources})
    (output/"THRESHOLD_NATIVE.json").write_text(json.dumps(result,indent=2)+"\n",encoding="utf-8",newline="\n")
    print("ARCADE ENTRY THRESHOLD EXPORT PASS")


if __name__ == "__main__":
    main()
