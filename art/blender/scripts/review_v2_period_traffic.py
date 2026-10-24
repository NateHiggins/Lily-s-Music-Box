"""Review sheet for the V2 period traffic stock (Blender, before any Godot run).

Opens art/blender/v2_period_traffic.blend, assembles each kind from the
runtime table (wheels, horse, legs, figures) exactly as the runtime does, and
renders a lit sheet plus close-ups into the review directory given as the
first argument after `--`:

    blender -b -P art/blender/scripts/review_v2_period_traffic.py -- <out_dir>
"""
from pathlib import Path
import sys, json, math
import bpy
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(sys.argv[sys.argv.index("--") + 1]) if "--" in sys.argv else ROOT / "art/reviews/v2_period_traffic_20261024"
OUT.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(ROOT / "art/blender/v2_period_traffic.blend"))
table = json.loads((ROOT / "game/data/orison_v2/exterior/street_traffic.json").read_text())
scene = bpy.context.scene
source = {o.name: o for o in bpy.data.collections["PeriodTrafficExport"].objects}
for o in source.values():
    o.hide_render = True
sheet = bpy.data.collections.new("ReviewSheet")
scene.collection.children.link(sheet)


def b(v):
    """Runtime vehicle-local (Godot axes) to Blender axes."""
    return Vector((v[0], -v[2], v[1]))


def place(stock, matrix, colour=None):
    for name, obj in source.items():
        if name.split("__")[0] != stock:
            continue
        copy = obj.copy()
        copy.hide_render = False
        copy.matrix_world = matrix
        if colour is not None and table["finishes"][name.split("__")[1]].get("paint"):
            copy.data = obj.data.copy()
            mat = obj.data.materials[0].copy()
            tint = [n for n in mat.node_tree.nodes if n.type == "MIX_RGB" and n.blend_type == "MULTIPLY"][0]
            tint.inputs[2].default_value = [c ** 2.2 for c in colour] + [1]
            copy.data.materials[0] = mat
        sheet.objects.link(copy)


def assemble(kind, at, paint, hide):
    base = Matrix.Translation(at)
    place(kind.get("stock", kind["id"]), base, paint)
    for w in kind["wheels"]:
        s = w["radius"] / 0.5
        place(w["stock"], base @ Matrix.Translation(b(w["at"])) @ Matrix.Diagonal((s, s * w["width"], s, 1)))
    horse = kind.get("horse")
    if horse:
        hm = base @ Matrix.Translation(b(horse["at"])) @ Matrix.Scale(horse["scale"], 4)
        place("horse_body", hm, hide)
        for i, leg in enumerate(horse["legs"]):
            swing = math.radians(18) * math.sin(i * 1.7)
            place("horse_leg", hm @ Matrix.Translation(b(leg)) @ Matrix.Rotation(swing, 4, "Y"), hide)
    for f in kind["figures"]:
        place("figure", base @ Matrix.Translation(b(f)))


kinds = table["kinds"] + [dict(p, id=p["stock"], figures=[]) for p in table["parked"]]
cols = 5
for i, kind in enumerate(kinds):
    x = (i % cols) * 14.0
    y = -(i // cols) * 11.0
    paint = kind["paint"][0] if "paint" in kind else None
    assemble(kind, Vector((x, y, 0)), paint, [0.42, 0.26, 0.15])

world = bpy.data.worlds.new("review") if scene.world is None else scene.world
scene.world = world
world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (0.05, 0.055, 0.07, 1)
world.node_tree.nodes["Background"].inputs[1].default_value = 1.0
sun = bpy.data.objects.new("key", bpy.data.lights.new("key", "SUN"))
sun.data.energy = 3.2
sun.rotation_euler = (math.radians(52), 0, math.radians(-38))
scene.collection.objects.link(sun)
fill = bpy.data.objects.new("fill", bpy.data.lights.new("fill", "SUN"))
fill.data.energy = 0.8
fill.rotation_euler = (math.radians(70), 0, math.radians(150))
scene.collection.objects.link(fill)
bpy.ops.mesh.primitive_plane_add(size=300, location=(28, -16, 0))
ground = bpy.context.object
gm = bpy.data.materials.new("ground")
gm.diffuse_color = (0.08, 0.08, 0.085, 1)
ground.data.materials.append(gm)

cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
scene.collection.objects.link(cam)
scene.camera = cam
scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x, scene.render.resolution_y = 2400, 1350
scene.view_settings.view_transform = "AgX"


def shoot(name, loc, target, lens=35, ortho=None):
    cam.location = loc
    direction = Vector(target) - Vector(loc)
    cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    cam.data.lens = lens
    if ortho:
        cam.data.type = "ORTHO"
        cam.data.ortho_scale = ortho
    else:
        cam.data.type = "PERSP"
    scene.render.filepath = str(OUT / name)
    bpy.ops.render.render(write_still=True)


shoot("sheet.png", (28, -75, 38), (28, -16, 0.5), ortho=72)
scene.render.resolution_x, scene.render.resolution_y = 1200, 700
rows = math.ceil(len(kinds) / cols)
for i, kind in enumerate(kinds):
    x = (i % cols) * 14.0
    y = -(i // cols) * 11.0
    mid = (kind["extent"][0] + kind["extent"][1]) / 2
    span = kind["extent"][1] - kind["extent"][0]
    shoot(f"{kind['id']}.png", (x + mid + span * 0.75 + 2.0, y - span * 1.05 - 2.5, 2.4), (x + mid, y, 1.1), lens=40)
print("review written", OUT)
