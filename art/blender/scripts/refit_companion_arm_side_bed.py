"""Move the phone-scale typing arm from its underside cassette to the port bed.

Run once on the combined source, then publish with export_companion_typing_arm.py:
  blender -b --python-exit-code 1 -P refit_companion_arm_side_bed.py
The body now owns the bay, the drop-bed door and its fixed rails
(refit_companion_compact_bay.py). This file keeps the jointed arm, mirrors it to
the port hand, and gives it two telescoping rail sections in place of the
cassette, hatch, roof and lift column. Key targets, joint limits, link lengths
and the timeline marks used by the runtime (16, 118, 320, 416, 432) are kept.
"""
from pathlib import Path
import json, math, sys
import bpy, numpy as np
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(Path(__file__).parent))
from fabrication_chart_batch import triangle_charts

source = ROOT / "art/blender/companion_typing_arm.blend"
bpy.ops.wm.open_mainfile(filepath=str(source))
bpy.context.preferences.filepaths.save_version = 0
objects = bpy.data.objects
assembly = objects["TypingArmAssembly"]
assert not assembly.get("side_bed_revision"), "Refit already applied"
exports = bpy.data.collections["02_ARM_ONLY_EXPORT"]
S = float(assembly["baked_reference_scale"])
assert S == .42

# Rig metres, matching refit_companion_compact_bay.py.
HINGE = Vector((-.0827, 0, -.0892))
SHOULDER_STOW = Vector((-.117, .002, -.0783))
STAGE = .036            # each rail section's travel; the shoulder works 72 mm forward
MIRROR = Matrix.Diagonal((-1, 1, 1, 1))
TAU = math.tau


def local(obj):
    return obj.matrix_parent_inverse @ obj.matrix_basis


def subtree(root):
    found = [root]
    for obj in found:
        found.extend(child for child in objects if child.parent == obj)
    return found


def keys(obj, path, index):
    out = {}
    action = obj.animation_data.action if obj.animation_data else None
    if action is None:
        return out
    for layer in action.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                if bag.slot != obj.animation_data.action_slot:
                    continue
                for curve in bag.fcurves:
                    if curve.data_path == path and curve.array_index == index:
                        out.update({round(k.co.x): k.co.y for k in curve.keyframe_points})
    return out


shoulder = objects["Arm_ShoulderYaw"]
elbow = objects["Arm_ElbowYaw"]
wrist = objects["Arm_Wrist"]
original = {obj.name: keys(obj, "rotation_euler", 2) for obj in [shoulder, elbow, wrist]}
rocker = keys(objects["Arm_TapRocker"], "rotation_euler", 1)
assert abs(original["Arm_ShoulderYaw"][348] - 1.5 * math.pi) < 1e-4 and abs(original["Arm_ElbowYaw"][82] + 3.0543) < 1e-3

# Retire the cassette, hatch, roof and lift column with their editable stock.
register = objects["DoorRegisterMount"]
world = Matrix.Identity(4)
chain = []
parent = register
while parent is not None:
    chain.append(parent)
    parent = parent.parent
for obj in reversed(chain):
    world = world @ local(obj)
register.parent = objects["TemporalAccessoryMount"]
register.matrix_parent_inverse = Matrix.Identity(4)
register.matrix_basis = local(objects["TemporalAccessoryMount"]).inverted() @ world
kept = set(subtree(shoulder)) | set(subtree(register)) | {assembly, objects["Arm_GuideTelescope"], objects["Arm_ReachSlide"]}
retired = [obj for obj in subtree(assembly) if obj not in kept]
retired += [objects[name] for name in ["ArmAttachmentDatum", "ArmHatchDatum", "KeyboardStayReliefDatum"] if name in objects]
names = sorted(obj.name for obj in retired)
for obj in retired:
    objects.remove(obj, do_unlink=True)
print("RETIRED", len(names))

# Mirror the jointed arm to the port hand. U is negated with X so every chart
# keeps its handedness; the catalogue maps carry no lettering.
seen = set()
arm = subtree(shoulder)
for obj in arm:
    if obj is not shoulder:
        if obj.animation_data and obj.animation_data.action:
            assert obj.matrix_parent_inverse.is_identity, obj.name
        matrix = MIRROR @ local(obj) @ MIRROR
        obj.matrix_parent_inverse = Matrix.Identity(4)
        obj.matrix_basis = matrix
    if obj.type != "MESH" or obj.data.name in seen:
        continue
    seen.add(obj.data.name)
    mesh = obj.data
    for vertex in mesh.vertices:
        vertex.co.x = -vertex.co.x
    mesh.flip_normals()
    for name, size, signs in [("Metres", 2, (-1, 1)), ("_METRE_UV", 3, (-1, 1, 1)), ("_TANGENT_GUIDE", 3, (1, -1, -1))]:
        attribute = mesh.attributes.get(name)
        if attribute is None:
            continue
        field = "vector"
        values = np.empty(len(attribute.data) * size, np.float32)
        attribute.data.foreach_get(field, values)
        values = values.reshape(-1, size) * np.array(signs, np.float32)
        attribute.data.foreach_set(field, values.ravel())
    mesh.update()

telescope = objects["Arm_GuideTelescope"]
reach = objects["Arm_ReachSlide"]
for obj in [telescope, reach, shoulder, elbow, wrist]:
    obj.animation_data_clear()
for obj, parent in [(telescope, assembly), (reach, telescope), (shoulder, reach)]:
    obj.parent = parent
    obj.matrix_parent_inverse = Matrix.Identity(4)
    obj.matrix_basis = Matrix.Identity(4)
shoulder.location = SHOULDER_STOW * S
telescope["joint_limits_json"] = json.dumps({"axis": "Y", "metres": [-STAGE * S, 0]})
reach["joint_limits_json"] = json.dumps({"axis": "Y", "metres": [-STAGE * S, 0]})
assembly["side_bed_revision"] = 1
assembly["handedness"] = -1
assembly["bed_hinge_rig_m"] = list(HINGE)

# Two rail sections ride the body's fixed bed rails; the shoulder sits on the
# upper one. Local bed frame: u outboard, v along the rails, w up.
materials = [bpy.data.materials["TypingArm_steel"], bpy.data.materials["TypingArm_brass"]]


def box(u0, v0, w0, u1, v1, w1):
    x0, x1 = HINGE.x - u1, HINGE.x - u0
    z0, z1 = HINGE.z + w0, HINGE.z + w1
    points = [Vector((x, y, z)) * S for z in (z0, z1) for y in (v0, v1) for x in (x0, x1)]
    faces = [(0, 2, 3, 1), (4, 5, 7, 6), (0, 1, 5, 4), (2, 6, 7, 3), (0, 4, 6, 2), (1, 3, 7, 5)]
    return points, faces


def barrel(start, end, radius, sides=14):
    def rig(u, v, w):
        return Vector((HINGE.x - u, v, HINGE.z + w)) * S
    a = rig(*start)
    b = rig(*end)
    axis = (b - a).normalized()
    p = axis.orthogonal().normalized()
    q = axis.cross(p)
    ring = [(p * math.cos(i * TAU / sides) + q * math.sin(i * TAU / sides)) * radius * S for i in range(sides)]
    points = [a + r for r in ring] + [b + r for r in ring]
    faces = [(i, (i + 1) % sides, sides + (i + 1) % sides, sides + i) for i in range(sides)]
    faces += [tuple(reversed(range(sides))), tuple(range(sides, 2 * sides))]
    return points, faces


def build(owner, parts, stock_name):
    points = []
    triangles = []
    slots = []
    for (part_points, part_faces), slot in parts:
        offset = len(points)
        points.extend(part_points)
        for face in part_faces:
            for i in range(1, len(face) - 1):
                triangles.append((offset + face[0], offset + face[i], offset + face[i + 1]))
                slots.append(slot)
    mesh = bpy.data.meshes.new("TypingArmMesh__" + owner.name)
    mesh.from_pydata([tuple(p) for p in points], [], triangles)
    mesh.update()
    for material in materials:
        mesh.materials.append(material)
    mesh.polygons.foreach_set("material_index", slots)
    coords = np.array([v.co[:] for v in mesh.vertices])
    corner = np.array([l.vertex_index for l in mesh.loops]).reshape(-1, 3)
    _, us, charts, _ = triangle_charts(coords[corner], np.zeros(3), 1.)
    flat = charts.reshape(-1, 2).astype(np.float32)
    mesh.uv_layers.new(name="Metres").data.foreach_set("uv", flat.ravel())
    metre = mesh.attributes.new(name="_METRE_UV", type="FLOAT_VECTOR", domain="CORNER")
    metre.data.foreach_set("vector", np.column_stack((flat, np.zeros(len(flat), np.float32))).ravel())
    guide = np.repeat(us[:, [0, 2, 1]], 3, axis=0)
    guide[:, 2] *= -1
    mesh.attributes.new(name="_TANGENT_GUIDE", type="FLOAT_VECTOR", domain="CORNER").data.foreach_set("vector", guide.astype(np.float32).ravel())
    draw = objects.new(mesh.name, mesh)
    exports.objects.link(draw)
    draw.parent = owner
    draw["stock"] = stock_name
    draw["export_partition"] = owner.name
    draw["branch"] = owner.name
    return draw


V = SHOULDER_STOW.y
U = HINGE.x - SHOULDER_STOW.x
STEEL, BRASS = 0, 1
build(telescope, [
    (box(U - .0050, V - .0250, .0035, U + .0050, V + .0250, .0055), STEEL),
    (box(U - .0058, V + .0236, .0035, U + .0058, V + .0250, .0062), BRASS),
    (box(U - .0058, V - .0250, .0035, U + .0058, V - .0236, .0048), BRASS),
], "Lower telescoping rail section with end stops")
build(reach, [
    (box(U - .0040, V - .0250, .0055, U + .0040, V + .0250, .0068), BRASS),
    (box(U - .0062, V - .0072, .0055, U + .0052, V + .0072, .0089), STEEL),
    (barrel((U - .0092, V, .0072), (U - .0062, V, .0072), .0027), BRASS),
], "Upper rail section, shoulder standard and inboard focusing knob")

d = STAGE * S


def key(obj, path, index, pairs):
    for frame, value in pairs:
        current = getattr(obj, path)
        current[index] = value
        obj.keyframe_insert(path, index=index, frame=frame)


key(telescope, "location", 1, [(1, 0), (16, 0), (36, -d), (395, -d), (416, 0), (432, 0)])
key(reach, "location", 1, [(1, 0), (36, 0), (58, -d), (374, -d), (395, 0), (432, 0)])
held = [102, 118, 136, 154, 164, 182, 192, 210, 220, 238, 248, 266, 276, 294, 304, 322, 348]
stow = {"Arm_ShoulderYaw": TAU, "Arm_ElbowYaw": original["Arm_ElbowYaw"][1], "Arm_Wrist": original["Arm_Wrist"][1]}
ready = {"Arm_ShoulderYaw": original["Arm_ShoulderYaw"][82], "Arm_ElbowYaw": original["Arm_ElbowYaw"][82], "Arm_Wrist": original["Arm_Wrist"][82]}
for obj in [shoulder, elbow, wrist]:
    name = obj.name
    pairs = [(1, stow[name]), (58, stow[name]), (82, ready[name])]
    pairs += [(frame, original[name][frame]) for frame in held]
    pairs += [(374, stow[name]), (432, stow[name])]
    # Mirrored hand: every yaw is the negative of its starboard value.
    key(obj, "rotation_euler", 2, [(frame, -value) for frame, value in pairs])
tap = objects["Arm_TapRocker"]
tap.animation_data_clear()
key(tap, "rotation_euler", 1, [(frame, -value) for frame, value in sorted(rocker.items())])

scene = bpy.context.scene
scene.frame_set(1)
bpy.context.view_layer.update()
hidden = [(c, c.hide_viewport) for c in bpy.data.collections]
for collection, _ in hidden:
    collection.hide_viewport = False
bpy.context.view_layer.update()
report = {}
for frame in [1, 16, 58, 82, 118]:
    scene.frame_set(frame)
    bpy.context.view_layer.update()
    low = Vector((9, 9, 9))
    high = Vector((-9, -9, -9))
    for obj in exports.all_objects:
        if obj.type != "MESH":
            continue
        for vertex in obj.data.vertices:
            p = (obj.matrix_world @ vertex.co) / S
            bed = Vector((HINGE.x - p.x, p.y, p.z - HINGE.z))
            low = Vector(map(min, low, bed))
            high = Vector(map(max, high, bed))
    report[frame] = [[round(v, 4) for v in low], [round(v, 4) for v in high]]
    if frame == 1:
        finger = objects["TypingArmMesh__Arm_TypingFinger"]
        points = [(finger.matrix_world @ v.co) / S for v in finger.data.vertices]
        report["finger_bed_uvw"] = [[round(min(HINGE.x - p.x for p in points), 4), round(min(p.y for p in points), 4), round(min(p.z - HINGE.z for p in points), 4)],
                                    [round(max(HINGE.x - p.x for p in points), 4), round(max(p.y for p in points), 4), round(max(p.z - HINGE.z for p in points), 4)]]
print("BED ENVELOPE u,v,w", json.dumps(report))
scene.frame_set(1)
for collection, state in hidden:
    collection.hide_viewport = state
assert all(obj.name.startswith("TypingArmMesh__") for obj in exports.all_objects if obj.type == "MESH")
bpy.ops.wm.save_as_mainfile(filepath=str(source), relative_remap=False)
print("SIDE BED", json.dumps({"retired": names[:8], "retired_count": len(names)}))
