"""Render the static shop heroes in isolation without shipping duplicates.

Run with Blender after gen_layout.py:

    SHOP_HERO_SHOT_DIR=C:/shots/orison_shop_pass/heroes \
      blender --background --python art/blender/scripts/render_shop_heroes.py

The installed furniture entry is the sole definition.  `hero` metadata selects
those same boxes from building_layout.json, translates a temporary copy onto a
one-metre judging grid, renders it, and destroys the copy with the process.
Nothing is written beneath game/ and no warehouse geometry enters an export.
"""

import json
import math
import os
from pathlib import Path

import bpy
from mathutils import Vector


ROOT = Path(__file__).resolve().parents[3]
LAYOUT = json.loads((ROOT / "art/data/building_layout.json").read_text())
CATALOG = json.loads((ROOT / "art/data/material_catalog.json").read_text())
OUT = Path(os.environ.get(
    "SHOP_HERO_SHOT_DIR", "C:/shots/orison_shop_pass/heroes"))
OUT.mkdir(parents=True, exist_ok=True)


def material(key):
    name = "HERO_%s" % key
    cached = bpy.data.materials.get(name)
    if cached:
        return cached
    mat = bpy.data.materials.new(name)
    spec = CATALOG.get(key, {})
    rgba = spec.get("base_color", [0.36, 0.34, 0.31, 1.0])
    mat.diffuse_color = tuple(rgba)
    mat.metallic = float(spec.get("metallic", 0.0))
    mat.roughness = float(spec.get("roughness", 0.72))
    return mat


def cube(name, size, at, mat):
    bpy.ops.mesh.primitive_cube_add(location=at)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = size
    obj.data.materials.append(mat)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return obj


def point(obj, target):
    obj.rotation_euler = (Vector(target) - obj.location).to_track_quat(
        "-Z", "Y").to_euler()


def clear_objects():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)


def shell():
    floor = material("concrete")
    cube("judging_floor", (8.0, 8.0, 0.10), (0, 0, -0.05), floor)
    line = bpy.data.materials.get("GRID") or bpy.data.materials.new("GRID")
    line.diffuse_color = (0.55, 0.57, 0.60, 1.0)
    line.roughness = 0.9
    for i in range(-4, 5):
        cube("grid_x_%d" % i, (0.018, 8.0, 0.008),
             (float(i), 0, 0.006), line)
        cube("grid_y_%d" % i, (8.0, 0.018, 0.008),
             (0, float(i), 0.006), line)


def render_trade(trade, entries):
    clear_objects()
    shell()
    x0 = min(e["rect"][0] for e in entries)
    x1 = max(e["rect"][2] for e in entries)
    y0 = min(e["rect"][1] for e in entries)
    y1 = max(e["rect"][3] for e in entries)
    cx, cy = (x0 + x1) * 0.5, (y0 + y1) * 0.5
    for e in entries:
        r = e["rect"]
        size = (r[2] - r[0], r[3] - r[1], e["h"])
        at = ((r[0] + r[2]) * 0.5 - cx,
              (r[1] + r[3]) * 0.5 - cy,
              e.get("z0", 0.0) + e["h"] * 0.5)
        cube(e["id"], size, at, material(e.get("mat", "trim")))

    world = bpy.context.scene.world or bpy.data.worlds.new("HeroWorld")
    bpy.context.scene.world = world
    world.color = (0.075, 0.078, 0.085)
    for i, at in enumerate(((-3.2, 4.0, 5.8), (3.2, 3.0, 4.4))):
        data = bpy.data.lights.new("flat_%d" % i, "AREA")
        # Flat judging light, not a product-photo whiteout.  The first pass
        # used 900 W and compressed oak, paper, iron and enamel into the same
        # white silhouette, defeating the material comparison entirely.
        data.energy = 260.0
        data.shape = "DISK"
        data.size = 5.0
        lamp = bpy.data.objects.new("flat_%d" % i, data)
        bpy.context.collection.objects.link(lamp)
        lamp.location = at
        point(lamp, (0, 0, 1.1))

    cam_data = bpy.data.cameras.new("HeroCamera")
    cam = bpy.data.objects.new("HeroCamera", cam_data)
    bpy.context.collection.objects.link(cam)
    front = -1.0 if trade == "druggist" else 1.0
    span = max(x1 - x0, y1 - y0, 2.0)
    cam.location = (span * 0.78, front * span * 1.55,
                    max(3.1, span * 0.72))
    point(cam, (0, 0, min(1.4, span * 0.25)))
    cam_data.lens = 52
    bpy.context.scene.camera = cam

    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 1024
    scene.render.resolution_y = 1024
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.film_transparent = False
    scene.render.filepath = str(OUT / (trade + ".png"))
    bpy.ops.render.render(write_still=True)
    print("rendered", scene.render.filepath, len(entries), "source boxes")


f01 = next(fl for fl in LAYOUT["floors"] if fl["id"] == "F01")
groups = {}
for entry in f01.get("furniture", []):
    if entry.get("hero"):
        groups.setdefault(entry["hero"], []).append(entry)

expected = {"laundry", "cobbler", "locksmith", "radio", "diner", "news",
            "pawn", "hardware", "photo", "druggist"}
if set(groups) != expected:
    raise RuntimeError("hero coverage mismatch: %s" % sorted(groups))
for trade in sorted(groups):
    render_trade(trade, groups[trade])
