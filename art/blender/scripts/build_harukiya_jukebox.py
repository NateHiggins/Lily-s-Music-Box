"""Rebuild the retained Harukiya music cabinet as a movable, UV-mapped prop.

Run in Blender background mode. The shell and button spacing come from the
original assembly. The selected key, coin return and illuminated title glass
export as distinct parts so their controls follow the visible stock.
"""
from pathlib import Path
import json
import sys

import bpy
from mathutils import Matrix

ROOT = next(p for p in Path(__file__).resolve().parents if (p / "game/project.godot").exists())
sys.path.insert(0, str(ROOT / "art/blender/scripts"))
from fabrication_native_batch import export, material, partition
from prepare_harukiya_destination import source

FAMILY = "harukiya_jukebox"
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.preferences.filepaths.save_version = 0
stock = bpy.data.collections.new("Workshop stock")
draws = bpy.data.collections.new("Finished cabinet")
for collection in (stock, draws):
    bpy.context.scene.collection.children.link(collection)
catalog = json.loads((ROOT / "game/data/runtime_material_sets.json").read_bytes())["materials"]
buffers = {}

def buffer(name):
    if name not in buffers:
        buffers[name] = source.MeshBuf(name, name)
    return buffers[name]

class CabinetFrame(source.Frame):
    def box(self, key, x0, y0, z0, x1, y1, z1):
        # One of the existing top-row keys is the master play/advance key.
        if key == "bakelite" and abs(x0 + .09) < .001 and abs(z0 - .80) < .001:
            key = "Selector"
            y0 -= .022
        super().box(key, x0, y0, z0, x1, y1, z1)

frame = CabinetFrame(buffer, lambda: buffer("hull"), 0, 0, 0, 0, 0)
source.asm_jukebox(frame, {})
buffers.pop("hull")
# The native cabinet casts its own shadow in the receiving room.
buffers.pop("fx_shadow")
# Dimensional fittings on the original cabinet, in metres.
frame.box("wood_dark", -.425, -.285, 0, .425, .285, .028)
frame.box("chrome", .19, -.335, .52, .405, -.306, .646)
frame.box("bakelite", .209, -.343, .54, .388, -.335, .625)
frame.box("CoinReturn", .23, -.372, .55, .37, -.342, .575)
frame.box("CoinReturn", .225, -.384, .546, .375, -.372, .58)
for x in (-.39, .39):
    frame.box("chrome", x - .01, -.335, .075, x + .01, -.31, 1.27)
for z in (.165, .23, .295, .36, .425):
    frame.box("brass_dull", -.359, -.329, z, .359, -.316, z + .008)
keys = {"glassish": "glass_reeded", "Selector": "bakelite", "CoinReturn": "brass_bright"}
for name, buf in buffers.items():
    key = keys.get(name, name)
    finish = {"catalog_key": key, "normal": .62, "roughness": .92, "pigment": .94,
              "tint": [1.0, 1.0, 1.0, 1.0]}
    mesh = bpy.data.meshes.new(name + " stock")
    mesh.from_pydata(buf.verts, [], buf.faces)
    mesh.update()
    original = bpy.data.objects.new(name + " stock", mesh)
    stock.objects.link(original)
    mat = material(ROOT, key + " cabinet", finish, catalog)
    partition(draws, name, [original], finish, mat, Matrix.Identity(4), catalog)
stock.hide_render = True
stock.hide_viewport = True
assert {x.name for x in draws.objects} >= {"Selector", "CoinReturn", "milk_glass"}
proof = export(ROOT, FAMILY, draws, material_names_only=True)
print("JUKEBOX EXPORT", json.dumps(proof, default=str))
