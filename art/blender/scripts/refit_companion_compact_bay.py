"""Refit the native companion body with a port-side arm bay and a date brow.

Run after refit_companion_keyboard_carriage.py:
  blender -b --python-exit-code 1 -P refit_companion_compact_bay.py
The port leather side is opened for a recessed drop-bed door (hinged low, as a
folding camera's bed is) and a lined bay behind it. A header housing above the
reading glass receives the amber date register and the capacitor, which stay
separate runtime owners. Untouched triangles keep their charts, tangent guides
and corner normals; cut triangles are clipped with exact affine attributes.
"""
from pathlib import Path
import hashlib, json, math, sys
import bpy, numpy as np
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(Path(__file__).parent))
from fabrication_native_batch import partition, export

native = ROOT / "art/blender/service_companion_v2.blend"
bpy.ops.wm.open_mainfile(filepath=str(native))
bpy.context.preferences.filepaths.save_version = 0
assert "CompanionArmDoor" not in bpy.data.objects, "Refit already applied"
exports = bpy.data.collections["ServiceRadiophoneV2"]
stocks = bpy.data.collections["EditableIndividualStock"]
data_path = ROOT / "game/data/device/service_companion_v2.json"
data = json.loads(data_path.read_text())
catalog = json.loads((ROOT / "game/data/runtime_material_sets.json").read_text())["materials"]

# Rig metres, Blender axes: -Y is the reading face, -X is port.
BAY = dict(x=(-.0950, -.0522), y=(-.0262, .0302), z=(-.0925, .0660))
HINGE = Vector((-.0827, 0, -.0892))
DOOR_LENGTH = .1548
DOOR_Y = (BAY["y"][0] + .0008, BAY["y"][1] - .0008)
STAY_LENGTH = .050
STAY_PIN_U = .024
STAY_SLOT_X = HINGE.x + .004
WALL = -.0864


def clip(polygon, axis, value, keep_low):
    out = []
    for i, a in enumerate(polygon):
        b = polygon[(i + 1) % len(polygon)]
        da = a[0][axis] - value
        db = b[0][axis] - value
        ia = da <= 0 if keep_low else da >= 0
        ib = db <= 0 if keep_low else db >= 0
        if ia:
            out.append(a)
        if ia != ib and da != db:
            t = da / (da - db)
            out.append(tuple(x + (y - x) * t for x, y in zip(a, b)))
    return out


def open_bay(obj):
    """Remove the part of a triangulated native batch inside the bay volume."""
    mesh = obj.data
    assert obj.matrix_world.is_identity and all(len(p.vertices) == 3 for p in mesh.polygons), obj.name
    count = len(mesh.loops)
    position = np.array([v.co[:] for v in mesh.vertices])[[l.vertex_index for l in mesh.loops]]
    uv = np.empty(count * 2, np.float32)
    mesh.uv_layers["Metres"].data.foreach_get("uv", uv)
    uv = uv.reshape(-1, 2).astype(float)
    guide = np.empty(count * 3, np.float32)
    mesh.attributes["_tangent_guide"].data.foreach_get("vector", guide)
    guide = guide.reshape(-1, 3).astype(float)
    normal = np.array([n.vector[:] for n in mesh.corner_normals])
    low = np.array([BAY[k][0] for k in "xyz"])
    high = np.array([BAY[k][1] for k in "xyz"])
    triangles = position.reshape(-1, 3, 3)
    touched = np.all(triangles.max(axis=1) > low, axis=1) & np.all(triangles.min(axis=1) < high, axis=1)
    if not touched.any():
        return 0
    keep = []
    changed = 0
    for index in range(len(triangles)):
        corners = [(position[index * 3 + c], uv[index * 3 + c], guide[index * 3 + c], normal[index * 3 + c]) for c in range(3)]
        if not touched[index]:
            keep.append(corners)
            continue
        changed += 1
        rest = corners
        for axis in range(3):
            for value, keep_low in [(low[axis], True), (high[axis], False)]:
                outside = clip(rest, axis, value, keep_low)
                rest = clip(rest, axis, value, not keep_low)
                for i in range(1, len(outside) - 1):
                    piece = [outside[0], outside[i], outside[i + 1]]
                    if np.linalg.norm(np.cross(piece[1][0] - piece[0][0], piece[2][0] - piece[0][0])) > 1e-11:
                        keep.append(piece)
                if len(rest) < 3:
                    break
            if len(rest) < 3:
                break
    lookup = {}
    vertices = []
    faces = []
    for piece in keep:
        face = []
        for corner in piece:
            key = tuple(np.round(corner[0], 7))
            if key not in lookup:
                lookup[key] = len(vertices)
                vertices.append(tuple(corner[0]))
            face.append(lookup[key])
        if len(set(face)) == 3:
            faces.append((face, piece))
    material = mesh.materials[0]
    fresh = bpy.data.meshes.new(mesh.name)
    fresh.from_pydata(vertices, [], [f for f, _ in faces])
    fresh.update()
    fresh.materials.append(material)
    assert len(fresh.polygons) == len(faces)
    assert all(tuple(p.vertices) == tuple(f) for p, (f, _) in zip(fresh.polygons, faces))
    layer = fresh.uv_layers.new(name="Metres")
    layer.data.foreach_set("uv", np.array([c[1] for _, piece in faces for c in piece], np.float32).ravel())
    attribute = fresh.attributes.new(name="_tangent_guide", type="FLOAT_VECTOR", domain="CORNER")
    attribute.data.foreach_set("vector", np.array([c[2] for _, piece in faces for c in piece], np.float32).ravel())
    normals = np.array([c[3] for _, piece in faces for c in piece])
    normals /= np.linalg.norm(normals, axis=1)[:, None]
    fresh.normals_split_custom_set([tuple(n) for n in normals])
    obj.data = fresh
    return changed


report = {}
for obj in list(exports.all_objects):
    if obj.type != "MESH" or obj.parent is not None:
        continue
    corners = [obj.matrix_world @ Vector(c) for c in obj.bound_box]
    if any(min(c[i] for c in corners) >= BAY[k][1] or max(c[i] for c in corners) <= BAY[k][0] for i, k in enumerate("xyz")):
        continue
    if "_tangent_guide" not in obj.data.attributes:
        continue
    changed = open_bay(obj)
    if changed:
        report[obj.name] = changed
print("BAY CUT", json.dumps(report))
assert "ShellStudy__ShellLeather" in report

groups = {}


def stock(owner, surface, name, low, high):
    low = Vector(low)
    high = Vector(high)
    assert all(high[i] > low[i] for i in range(3)), name
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata([(x, y, z) for z in (low.z, high.z) for y in (low.y, high.y) for x in (low.x, high.x)], [],
                     [(0, 2, 3, 1), (4, 5, 7, 6), (0, 1, 5, 4), (2, 6, 7, 3), (0, 4, 6, 2), (1, 3, 7, 5)])
    mesh.update()
    obj = bpy.data.objects.new("Stock__" + name, mesh)
    stocks.objects.link(obj)
    obj.data.materials.append(bpy.data.materials[surface])
    groups.setdefault((owner, surface), []).append(obj)
    return obj


def turned(owner, surface, name, start, end, radius, sides=16):
    start = Vector(start)
    end = Vector(end)
    axis = (end - start).normalized()
    a = axis.orthogonal().normalized()
    b = axis.cross(a)
    ring = [a * math.cos(i * math.tau / sides) * radius + b * math.sin(i * math.tau / sides) * radius for i in range(sides)]
    points = [tuple(start + r) for r in ring] + [tuple(end + r) for r in ring]
    faces = [(i, (i + 1) % sides, sides + (i + 1) % sides, sides + i) for i in range(sides)]
    faces += [tuple(reversed(range(sides))), tuple(range(sides, 2 * sides))]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(points, [], faces)
    mesh.update()
    obj = bpy.data.objects.new("Stock__" + name, mesh)
    stocks.objects.link(obj)
    obj.data.materials.append(bpy.data.materials[surface])
    groups.setdefault((owner, surface), []).append(obj)
    return obj


x0, x1 = WALL, BAY["x"][1]
y0, y1 = BAY["y"]
z0, z1 = BAY["z"]
t = .0012
# Lined bay: five closed slabs behind the leather wall, then a brass throat.
stock("bay", "StudyVelvet", "Arm bay floor lining", (x1, y0 - t, z0 - t), (x1 + t, y1 + t, z1 + t))
stock("bay", "StudyVelvet", "Arm bay fore lining", (x0, y0 - t, z0 - t), (x1, y0, z1 + t))
stock("bay", "StudyVelvet", "Arm bay aft lining", (x0, y1, z0 - t), (x1, y1 + t, z1 + t))
stock("bay", "StudyVelvet", "Arm bay sill lining", (x0, y0, z0 - t), (x1, y1, z0))
stock("bay", "StudyVelvet", "Arm bay head lining", (x0, y0, z1), (x1, y1, z1 + t))
f = .0026
proud = WALL - .0010
seat = WALL + .0016
stock("bay", "ShellBrass", "Arm bay head rail", (proud, y0 - f, z1), (seat, y1 + f, z1 + f))
stock("bay", "ShellBrass", "Arm bay fore jamb", (proud, y0 - f, z0), (seat, y0, z1))
stock("bay", "ShellBrass", "Arm bay aft jamb", (proud, y1, z0), (seat, y1 + f, z1))
stock("bay", "ShellBrass", "Arm bay sill rail", (proud, y0 - f, z0 - f), (seat, y1 + f, z0))
for label, y in [("fore", y0), ("aft", y1 - .0006)]:
    # Slotted guides for the two bed stays; each stay shoe rides its strip.
    stock("bay", "ShellBrass", "Arm bay stay guide " + label,
          (STAY_SLOT_X - .0011, y, HINGE.z + .040), (STAY_SLOT_X + .0011, y + .0006, HINGE.z + .078))


# Door stock is authored open: +u runs outboard (-X), w is up, origin on the pin.
def bed(u0, v0, w0, u1, v1, w1):
    return (-u1, v0, w0), (-u0, v1, w1)


v0, v1 = DOOR_Y
stock("door", "ShellSteel", "Arm bed plate", *bed(.0, v0, -.0015, DOOR_LENGTH, v1, .0005))
stock("door", "ShellLeather", "Arm bed leather", *bed(.0045, v0 + .0022, -.0025, DOOR_LENGTH - .0022, v1 - .0022, -.0015))
for name, a, b in [("fore", (.0025, v0, -.0028), (DOOR_LENGTH, v0 + .0022, -.0015)),
                   ("aft", (.0025, v1 - .0022, -.0028), (DOOR_LENGTH, v1, -.0015)),
                   ("head", (DOOR_LENGTH - .0022, v0 + .0022, -.0028), (DOOR_LENGTH, v1 - .0022, -.0015)),
                   ("heel", (.0025, v0 + .0022, -.0028), (.0045, v1 - .0022, -.0015))]:
    stock("door", "ShellBrass", "Arm bed binding " + name, *bed(*a, *b))
# The stowed links rest on a lined pad, clear of the folded finger by the rails.
stock("door", "StudyVelvet", "Arm bed lining pad", *bed(.0480, v0 + .0030, .0005, DOOR_LENGTH - .0040, v1 - .0030, .0011))
turned("door", "ShellBrass", "Arm bed hinge barrel", (0, v0, 0), (0, v1, 0), .0022)
for u in [.0293, .0368]:
    stock("door", "ShellBrass", "Arm bed fixed rail", *bed(u, v0 + .002, .0005, u + .0025, v1 - .002, .0035))
stock("door", "ShellBrass", "Arm bed finger pull", *bed(DOOR_LENGTH - .012, -.006, -.0036, DOOR_LENGTH - .008, .010, -.0025))
for v in [v0 + .0016, v1 - .0016]:
    turned("door", "ShellBrass", "Arm bed stay pin", (-STAY_PIN_U, v - .0012, .002), (-STAY_PIN_U, v + .0012, .002), .0011, 10)

door = bpy.data.objects.new("CompanionArmDoor", None)
exports.objects.link(door)
door.location = HINGE
door.rotation_euler = (0, math.pi / 2, 0)


def pose_stay(stay, angle):
    pin = HINGE + Matrix.Rotation(angle, 3, "Y") @ Vector((-STAY_PIN_U, 0, .002))
    stay.location = (pin.x, stay.location.y, pin.z)
    reach = math.sqrt(STAY_LENGTH ** 2 - (STAY_SLOT_X - pin.x) ** 2)
    stay.rotation_euler = Vector((STAY_SLOT_X - pin.x, 0, reach)).to_track_quat("Z", "Y").to_euler()


stays = []
for label, v in [("Fore", v0 + .0016), ("Aft", v1 - .0016)]:
    stay = bpy.data.objects.new("CompanionArmDoorStay" + label, None)
    exports.objects.link(stay)
    stay.location.y = v
    pose_stay(stay, math.pi / 2)
    stock("stay" + label, "ShellBrass", "Arm bed stay bar " + label, (-.0014, -.0005, -.0014), (.0014, .0005, STAY_LENGTH + .0014))
    turned("stay" + label, "ShellBrass", "Arm bed stay shoe " + label, (0, -.0011, STAY_LENGTH), (0, .0011, STAY_LENGTH), .0016, 10)
    stays.append((stay, "stay" + label))

owners = {"bay": None, "door": door, "brow": None}
owners.update({key: stay for stay, key in stays})
names = {"bay": "CompanionArmBay", "door": "ArmDoor", "stayFore": "ArmDoorStayFore", "stayAft": "ArmDoorStayAft", "brow": "CompanionBrow"}

# Header housing above the reading glass. Two pockets face the reader: the
# date register to starboard and, deeper, the capacitor cell to port.
BROW = dict(x=(-.0880, .0880), y=(-.0790, -.0520), z=(.0825, .1160))
DATE = dict(x=(-.0160, .0745), z=(.0850, .1140), depth=.0075)
CELL = dict(x=(-.0712, -.0388), z=(.0850, .1140), depth=.0165)
bx0, bx1 = BROW["x"]
by0, by1 = BROW["y"]
bz0, bz1 = BROW["z"]
front = by0 + DATE["depth"]
deep = by0 + CELL["depth"]
stock("brow", "ShellSteel", "Brow back plate", (bx0, deep, bz0), (bx1, by1, bz1))
stock("brow", "ShellSteel", "Brow sill", (bx0, by0, bz0), (bx1, deep, DATE["z"][0]))
stock("brow", "ShellSteel", "Brow cap", (bx0, by0, DATE["z"][1]), (bx1, deep, bz1))
stock("brow", "ShellSteel", "Brow port cheek", (bx0, by0, DATE["z"][0]), (CELL["x"][0], deep, DATE["z"][1]))
stock("brow", "ShellSteel", "Brow mullion", (CELL["x"][1], by0, DATE["z"][0]), (DATE["x"][0], deep, DATE["z"][1]))
stock("brow", "ShellSteel", "Brow starboard cheek", (DATE["x"][1], by0, DATE["z"][0]), (bx1, deep, DATE["z"][1]))
stock("brow", "ShellSteel", "Brow date seat", (DATE["x"][0], front, DATE["z"][0]), (DATE["x"][1], deep, DATE["z"][1]))
stock("brow", "ShellLeather", "Brow crown leather", (bx0 + .003, by0 + .003, bz1), (bx1 - .003, by1 - .002, bz1 + .0008))
for pocket, label in [(DATE, "date"), (CELL, "cell")]:
    px0, px1 = pocket["x"]
    pz0, pz1 = pocket["z"]
    r = .0016
    for name, a, b in [("sill", (px0 - r, pz0 - r), (px1 + r, pz0)), ("head", (px0 - r, pz1), (px1 + r, pz1 + r)),
                       ("port", (px0 - r, pz0), (px0, pz1)), ("starboard", (px1, pz0), (px1 + r, pz1))]:
        stock("brow", "ShellBrass", "Brow %s bezel %s" % (label, name), (a[0], by0 - .0010, a[1]), (b[0], by0 + .0012, b[1]))
for x in [bx0 + .0065, bx1 - .0065]:
    turned("brow", "ShellBrass", "Brow cheek screw", (x, by0 - .0006, (bz0 + bz1) / 2), (x, by0 + .001, (bz0 + bz1) / 2), .0022, 12)

for (owner, surface), objects in groups.items():
    draw = partition(exports, names[owner] + "__" + surface, objects, data["finishes"][surface],
                     bpy.data.materials[surface], Matrix.Identity(4), catalog)
    if owners[owner] is not None:
        draw.parent = owners[owner]

proof = export(ROOT, "service_companion_v2", exports, material_names_only=True, staged_output=True)
proof["asset"] = "res://assets/props/service_companion_v2.glb"
data["asset_sha256"] = hashlib.sha256((ROOT / "game/assets/props/service_companion_v2.glb").read_bytes()).hexdigest()
# Runtime records are in Godot axes: x, up, toward the reader.
data["arm_bay"] = dict(door="CompanionArmDoor", stays=["CompanionArmDoorStayFore", "CompanionArmDoorStayAft"],
                       stay_pin=[-STAY_PIN_U, .002, 0], stay_slot_x=STAY_SLOT_X, stay_length_m=STAY_LENGTH)
data["brow"] = dict(face_z=-by0, pockets={
    label: dict(center_x=(p["x"][0] + p["x"][1]) / 2, bottom=p["z"][0], width=p["x"][1] - p["x"][0],
                height=p["z"][1] - p["z"][0], floor_z=-(by0 + p["depth"]))
    for label, p in [("date", DATE), ("cell", CELL)]})
data_path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8", newline="\n")
construction_path = ROOT / "art/blender/service_companion_v2_construction.json"
construction = json.loads(construction_path.read_text())
construction["compact_bay"] = dict(
    cut_triangles=report, export=proof, bay=BAY, hinge=list(HINGE), door_length_m=DOOR_LENGTH,
    sequence="Bed drops on its sill hinge and paired stays; the arm rides out on the bed rails; reverse to stow",
    brow="Header housing with date and capacitor pockets; the register and capacitor remain runtime accessories")
construction_path.write_text(json.dumps(construction, indent=2) + "\n", encoding="utf-8", newline="\n")
print("COMPACT BAY", json.dumps(proof))

if "--review" in sys.argv:
    # Native geometry review only; the camera and lights are never saved or exported.
    sys.path.insert(0, sys.argv[sys.argv.index("--review") + 1])
    from review_render import render
    out = sys.argv[sys.argv.index("--review") + 2]
    views = [("port", (-1, 0, 0), (0, 0, 0), .32), ("port34", (-.8, -.7, .3), (0, 0, .03), .42), ("front", (.15, -1, .15), (0, 0, .02), .36)]
    render(exports.all_objects, out, [(n + "_closed", *rest) for n, *rest in views])
    door.rotation_euler = (0, 0, 0)
    for stay, _ in stays:
        pose_stay(stay, 0)
    render(exports.all_objects, out, [(n + "_open", *rest) for n, *rest in views])
