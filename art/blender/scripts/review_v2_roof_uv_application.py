"""Read-only neutral review of existing roof models using their authored UVs.

No scene, asset or texture is exported or overwritten. Installed illumination,
controls, collision and world routes require the separate Godot capture.
"""
import argparse
import hashlib
import json
import sys
from pathlib import Path
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(Path(__file__).parent))
from fabrication_native_batch import material

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
parser = argparse.ArgumentParser()
parser.add_argument("--out", type=Path, required=True)
out = parser.parse_args(args).out.resolve()
out.mkdir(parents=True, exist_ok=True)
catalog = json.loads((ROOT / "game/data/runtime_material_sets.json").read_text(encoding="utf-8"))["materials"]
sources = ["game/assets/props/house_tank.glb", "game/assets/building/v2_lift_drive.glb"]
hashes = {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in sources}
observations = []
for index, source in enumerate(sources):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(ROOT / source))
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    assert meshes and all(o.data.uv_layers.active is not None for o in meshes)
    mapped = {}
    for obj in meshes:
        for slot in obj.material_slots:
            name = slot.material.name.split(".")[0]
            key = "tank_staves" if index == 0 and name == "timber" else name
            if key=="cast_iron": key="iron_blackened"
            elif key=="metal": key="iron_neutral"
            assert key in catalog, (source, key)
            if key not in mapped:
                mapped[key] = material(ROOT, key, dict(catalog_key=key, tint=[1,1,1,1],
                    pigment=1, normal=.08, roughness=catalog[key]["roughness_multiplier"]), catalog)
            slot.material = mapped[key]
    # Roof-drive ropes extend down the shaft. Framing is the service apparatus;
    # the native asset and shaft geometry remain untouched.
    points = [obj.matrix_world @ v.co for obj in meshes for v in obj.data.vertices]
    minimum = Vector(tuple(min(p[i] for p in points) for i in range(3)))
    maximum = Vector(tuple(max(p[i] for p in points) for i in range(3)))
    center = (minimum + maximum) / 2 if index == 0 else Vector((0,0,1))
    distance = max((maximum-minimum).length, 4) if index == 0 else 4.8
    bpy.ops.object.camera_add(location=center + Vector((.8,-1,.55))*distance)
    camera = bpy.context.object
    camera.rotation_euler = (center-camera.location).to_track_quat("-Z","Y").to_euler()
    camera.data.lens = 48
    scene = bpy.context.scene; scene.camera = camera
    scene.world = bpy.data.worlds.new("Neutral UV review"); scene.world.use_nodes = True
    scene.world.node_tree.nodes["Background"].inputs[1].default_value = .55
    bpy.ops.object.light_add(type="AREA", location=center+Vector((0,-3,6)))
    light = bpy.context.object; light.data.energy = 1200; light.data.size = 5
    light.rotation_euler = (center-light.location).to_track_quat("-Z","Y").to_euler()
    scene.render.engine = "CYCLES"; scene.cycles.samples = 24; scene.cycles.use_denoising = True
    scene.render.resolution_x = 1100; scene.render.resolution_y = 800
    scene.render.resolution_percentage = 100
    name = "tank_uv" if index == 0 else "drive_uv"
    scene.render.filepath = str(out / (name + ".png")); bpy.ops.render.render(write_still=True)
    observations.append({"asset":source,"mesh_count":len(meshes),"keys":sorted(mapped),
                         "bounds":[list(minimum),list(maximum)],"image":name+".png"})
assert hashes == {p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in sources}
(out/"review.json").write_text(json.dumps({"evidence_class":"INERT", "native_assets_unchanged":hashes,
    "observations":observations, "scope":"Read-only neutral base PBR map/UV review. No production finish calibration, route or human acceptance claim."},indent=2)+"\n",encoding="utf-8",newline="\n")
