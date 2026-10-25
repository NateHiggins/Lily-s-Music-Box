"""Review sheet for the V2 entry vestibule stock (Blender, before Godot).

    blender -b art/blender/v2_entry_vestibule.blend -P art/blender/scripts/review_v2_entry_vestibule.py
"""
from pathlib import Path
import math
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "art/reviews/v2_entry_vestibule_20261024"
OUT.mkdir(parents=True, exist_ok=True)
SLOTS = {"directory_board": (0.0, 1.4), "notice_frame": (0.75, 1.5), "bronze_plaque": (1.6, 1.5),
         "signal_point": (2.35, 0.9), "coat_hooks": (2.95, 1.7), "gas_bracket": (2.75, 1.3), "gas_lantern": (3.3, 1.3), "gas_cock_key": (2.75, 1.4), "gas_pilot": (2.75, 1.1),
         "radiator": (3.9, 0.0), "door_mat": (5.0, 0.0)}
scene = bpy.context.scene
for obj in list(scene.objects):
    stock = obj.name.split("__")[0]
    if stock in SLOTS and obj.type == "MESH":
        x, z = SLOTS[stock]
        obj.location = (x, 0, z)
        obj.hide_render = False
wall = bpy.data.meshes.new("wall")
wall.from_pydata([(-0.6, 0.001, -0.1), (5.7, 0.001, -0.1), (5.7, 0.001, 2.4), (-0.6, 0.001, 2.4)], [], [(0, 1, 2, 3)])
w = bpy.data.objects.new("ReviewWall", wall); scene.collection.objects.link(w)
floor = bpy.data.meshes.new("floor")
floor.from_pydata([(-0.6, 0.0, 0), (5.7, 0.0, 0), (5.7, -1.5, 0), (-0.6, -1.5, 0)], [], [(0, 1, 2, 3)])
f = bpy.data.objects.new("ReviewFloor", floor); scene.collection.objects.link(f)
grey = bpy.data.materials.new("grey"); grey.use_nodes = True
grey.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.42, 0.40, 0.36, 1)
w.data.materials.append(grey); f.data.materials.append(grey)
sun = bpy.data.objects.new("Key", bpy.data.lights.new("Key", "AREA")); sun.data.energy = 900; sun.data.size = 4
sun.location = (2.5, -3.5, 3.5); scene.collection.objects.link(sun)
sun.rotation_euler = (math.radians(50), 0, 0)
cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam")); scene.collection.objects.link(cam)
scene.camera = cam
scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x, scene.render.resolution_y = 1800, 900
world = bpy.data.worlds.new("w"); scene.world = world; world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.25
def shot(name, location, target, lens=35):
    cam.location = location; cam.data.lens = lens
    direction = Vector(target) - Vector(location)
    cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = str(OUT / name)
    bpy.ops.render.render(write_still=True)
shot("blender_sheet.png", (2.55, -4.6, 1.3), (2.55, 0, 0.9), 30)
shot("blender_gas_fittings.png", (3.0, -0.95, 1.2), (3.0, 0, 1.15), 45)
shot("blender_lamp_hooks.png", (3.3, -0.9, 1.5), (2.95, 0, 1.4), 50)
shot("blender_radiator_point.png", (3.3, -1.2, 0.8), (3.3, 0, 0.45), 40)
shot("blender_directory.png", (0.4, -1.4, 1.5), (0.4, 0, 1.45), 45)

# The gas run in place: the frame stock at the blockout origin and the
# bracket where the placement data seats it on the vestibule's north wall.
import json
place = json.loads((ROOT / "game/data/orison_v2/entry_vestibule.json").read_text(encoding="utf-8"))
row = next(r for r in place["lamps"]["fittings"] if r.get("wall") == "north")
for obj in scene.objects:
    stock = obj.name.split("__")[0]
    if obj.type != "MESH" or obj.name.startswith("Review"):
        continue
    obj.hide_render = stock not in ("gas_pipe_vestibule", "gas_bracket", "gas_cock_key", "gas_pilot")
    at = Vector((row["along"], -place["wall_faces"]["north"], row["height"]))
    if stock == "gas_pipe_vestibule":
        obj.location = (0, 0, 0)
    elif stock == "gas_bracket":
        obj.location = at
        obj.rotation_euler = (0, 0, math.pi)
    elif stock == "gas_cock_key":
        # Shown half open, so the review reads the turn.
        obj.location = at + Vector((0, 0.11, 0))
        obj.rotation_euler = (0, 0, math.pi + math.pi / 4)
    elif stock == "gas_pilot":
        obj.location = at + Vector((0, 0.21, -0.155))
w.hide_render = True; f.hide_render = True
north = bpy.data.meshes.new("north")
y = -place["wall_faces"]["north"]
north.from_pydata([(-2.4, y - 0.001, 0), (2.4, y - 0.001, 0), (2.4, y - 0.001, 3.0), (-2.4, y - 0.001, 3.0)], [], [(0, 1, 2, 3)])
n = bpy.data.objects.new("ReviewNorth", north); scene.collection.objects.link(n); n.data.materials.append(grey)
sun.location = (0.5, y + 3.0, 2.5); sun.rotation_euler = (math.radians(-50), 0, 0)
shot("blender_gas_run.png", (0.9, y + 3.6, 1.5), (1.1, y, 1.5), 28)
shot("blender_gas_rosette.png", (0.45, y + 0.8, 2.25), (0.0, y, 2.45), 45)

# The house gas service in the front workroom, with index hands on the dials.
service = json.loads((ROOT / "game/data/orison_v2/gas_service.json").read_text(encoding="utf-8"))
m = service["meter"]
wall_y = -m["wall_face_z"]
hand = next(o for o in scene.objects if o.name.startswith("gas_meter_hand__iron"))
boss = next(o for o in scene.objects if o.name.startswith("gas_meter_hand__brass"))
for obj in scene.objects:
    if obj.type == "MESH" and not obj.name.startswith("Review"):
        obj.hide_render = obj.name.split("__")[0] != "gas_service_workroom"
n.hide_render = True
south = bpy.data.meshes.new("south")
south.from_pydata([(7.2, wall_y + 0.001, 0), (8.6, wall_y + 0.001, 0), (8.6, wall_y + 0.001, 2.6), (7.2, wall_y + 0.001, 2.6)], [], [(0, 1, 2, 3)])
sw = bpy.data.objects.new("ReviewSouth", south); scene.collection.objects.link(sw); sw.data.materials.append(grey)
for i, dial in enumerate(m["dials"]):
    dx, dy = dial["offset"]
    for part in (hand, boss):
        copy = part.copy(); scene.collection.objects.link(copy); copy.hide_render = False
        copy.location = (m["centre_x"] + dx, wall_y - 0.23 - 0.0085, m["shelf_y"] + dy)
        copy.rotation_euler = (0, math.radians(37 + 71 * i), 0)
sun.location = (7.6, wall_y - 3.0, 2.4); sun.rotation_euler = (math.radians(55), 0, 0)
shot("blender_gas_meter.png", (7.45, wall_y - 1.25, 1.45), (7.95, wall_y - 0.1, 1.05), 38)
shot("blender_gas_index.png", (7.92, wall_y - 0.62, 1.2), (7.92, wall_y - 0.23, 1.2), 50)

# Mantles, shade, lantern door and carton (renewal stock), assembled.
from mathutils import Matrix as _M
for obj in scene.objects:
    if obj.type == "MESH" and not obj.name.startswith("Review"):
        obj.hide_render = True
sw.hide_render = True
bench = bpy.data.meshes.new("bench")
bench.from_pydata([(-1, 0.4, 0), (3, 0.4, 0), (3, 0.4, 2.6), (-1, 0.4, 2.6)], [], [(0, 1, 2, 3)])
bw = bpy.data.objects.new("ReviewBench", bench); scene.collection.objects.link(bw); bw.data.materials.append(grey)
def show(stock, at, rot=None):
    for obj in list(scene.objects):
        if obj.type == "MESH" and obj.name.split("__")[0] == stock and not obj.name.startswith("Review"):
            copy = obj.copy(); scene.collection.objects.link(copy); copy.hide_render = False
            copy.matrix_world = _M.Translation(at) @ (rot if rot is not None else _M.Identity(4))
# Bracket with its shade lowered 8 cm and a fresh mantle on the burner.
show("gas_bracket", (0, 0.4, 1.4)); show("gas_cock_key", (0, 0.4 - 0.11, 1.4))
show("gas_bracket_shade", (0, 0.4 - 0.21, 1.4 - 0.068 - 0.08)); show("gas_mantle", (0, 0.4 - 0.21, 1.4 - 0.132))
# The three mantle states side by side.
show("gas_mantle", (0.5, 0.2, 1.3)); show("gas_mantle_broken", (0.6, 0.2, 1.3)); show("gas_naked_flame", (0.7, 0.2, 1.3))
# Lantern with its door swung 60 degrees about the hinge post.
lc = (1.4, 0.4, 1.6)
show("gas_lantern", lc)
ht, hb, cy, top, bottom = 0.081, 0.060, -0.33, -0.05, -0.35
hinge = Vector((-ht, cy - ht, top)); axis = (Vector((-hb, cy - hb, bottom)) - hinge).normalized()
show("gas_lantern_door", Vector(lc) + hinge, _M.Rotation(math.radians(-60), 4, axis))
show("gas_mantle", Vector(lc) + Vector((0, cy, -0.185)))
# Carton with lid open and a dozen packets less one.
cc = Vector((2.3, 0.2, 1.2))
show("mantle_carton", cc); show("mantle_carton_lid", cc + Vector((0, 0.08, 0.07)), _M.Rotation(math.radians(-100), 4, "X"))
for i in range(11):
    show("mantle_packet", cc + Vector((-0.084 + 0.056 * (i % 4), -0.045 + 0.045 * (i // 4), 0.003)))
sun.location = (1.2, -2.5, 2.6); sun.rotation_euler = (math.radians(55), 0, 0)
shot("blender_renewal_sheet.png", (1.15, -1.9, 1.5), (1.15, 0.3, 1.35), 32)
shot("blender_lantern_door.png", (1.0, -0.55, 1.45), (1.4, 0.07, 1.45), 45)
shot("blender_mantles.png", (0.6, -0.25, 1.3), (0.6, 0.2, 1.29), 60)
shot("blender_carton.png", (2.3, -0.5, 1.6), (2.3, 0.2, 1.23), 45)
