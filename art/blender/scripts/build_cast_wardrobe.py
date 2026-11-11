"""Build a cast member whole: base body, face, hands, strand hair and a wardrobe.

blender -b --python build_cast_wardrobe.py -- <character id> <wardrobe json> <out dir>

Nothing of the old generated shells is used. The body is the MakeHuman base
(MPFB2, CC0 assets) on its Mixamo-named skeleton, the same for every cast
member. Clothes are separate pieces made here from the base's own clothing
helpers (a body-hugging shell and a skirt), cut to each garment's shape, set
off from the skin, and given the character's colours. The world is surreal and
the cast must read at a distance, so the palettes are bold.
"""
import bpy, bmesh, os, sys, glob, json, math, importlib, importlib.util, traceback
import numpy
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

CID, CONFIG, OUT = sys.argv[sys.argv.index("--") + 1:][:3]
TABLE = json.load(open(CONFIG, encoding="utf-8"))
CFG = TABLE[CID]
os.makedirs(OUT, exist_ok=True)
M = "bl_ext.blender_org.mpfb"
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.preferences.addon_enable(module=M)
svc = lambda n: importlib.import_module(M + ".services." + n)
HS = svc("humanservice").HumanService
TS = svc("targetservice").TargetService
FS = svc("faceservice").FaceService
USER = svc("locationservice").LocationService.get_user_data()
PREFIX = "mixamorig:"


def asset(kind, name, ext="mhclo"):
    hits = glob.glob(os.path.join(USER, kind, name, "*." + ext))
    if not hits:
        raise RuntimeError("no asset %s/%s" % (kind, name))
    return hits[0]


def plain(name, colour, rough=0.75, metal=0.0):
    material = bpy.data.materials.new(name)
    material.use_nodes = True
    shader = material.node_tree.nodes["Principled BSDF"]
    shader.inputs["Base Color"].default_value = (*colour, 1.0)
    shader.inputs["Roughness"].default_value = rough
    shader.inputs["Metallic"].default_value = metal
    return material


def base_image(obj):
    for slot in obj.material_slots:
        tree_ = slot.material.node_tree if slot.material and slot.material.use_nodes else None
        if tree_ is None:
            continue
        for node in tree_.nodes:
            if node.type == "TEX_IMAGE" and node.image:
                return node, node.image
    return None, None


# ---------------------------------------------------------------- body, face, rig
macro = TS.get_default_macro_info_dict()
macro.update(CFG["macro"])
macro["race"] = CFG.get("race", {"asian": 0.0, "caucasian": 1.0, "african": 0.0})
human = HS.create_human(macro_detail_dict=macro)
TS.bake_targets(human)
HS.set_character_skin(asset("skins", CFG["skin"], "mhmat"), human, skin_type="GAMEENGINE", material_instances=False)
rig = HS.add_builtin_rig(human, "mixamo")
parts = []
for kind, name, atype in [("eyes", "low-poly", "Eyes"), ("eyebrows", CFG.get("eyebrows", "eyebrow001"), "Eyebrows"),
                          ("eyelashes", "eyelashes01", "Eyelashes"), ("teeth", "teeth_base", "Teeth"), ("tongue", "tongue01", "Tongue")]:
    part = HS.add_mhclo_asset(asset(kind, name), human, asset_type=atype, subdiv_levels=0, material_type="GAMEENGINE")
    part.name = "Face_" + kind
    parts.append(part)
if CFG.get("shoes"):
    shoes = HS.add_mhclo_asset(asset("clothes", CFG["shoes"]["asset"]), human, asset_type="Clothes", subdiv_levels=0, material_type="GAMEENGINE")
    shoes.name = "Shoes"
    shoes.data.materials.clear()
    shoes.data.materials.append(plain(CID + "_shoes", CFG["shoes"].get("colour", [0.08, 0.05, 0.03]), 0.4))
    parts.append(shoes)
FS.load_targets(human, load_microsoft_visemes=False, load_meta_visemes=True, load_arkit_faceunits=True)
FS.interpolate_targets(human)
for modifier in [m for m in human.modifiers if m.type == "MASK"]:
    human.modifiers.remove(modifier)

bone = lambda name: rig.matrix_world @ rig.data.bones[PREFIX + name].head_local
names = {g.index: g.name for g in human.vertex_groups}
group_index = {n: i for i, n in names.items()}
mesh = human.data


def in_group(vertex, group):
    index = group_index[group]
    return any(g.group == index for g in vertex.groups)


def weight(vertex, fragments):
    return sum(g.weight for g in vertex.groups if any(f in names[g.group] for f in fragments))


ARM = ("Arm", "ForeArm", "Hand")
LEG = ("UpLeg", "Leg", "Foot", "Toe")
waist = bone("Spine").z + float(CFG.get("waist_lift", 0.0))
hip = bone("Hips").z
neck = bone("Neck").z
knee = bone("LeftLeg").z
ankle = bone("LeftFoot").z
elbow = bone("LeftForeArm")
wrist = bone("LeftHand")
shoulder = bone("LeftArm")
print("LANDMARKS waist %.3f hip %.3f neck %.3f knee %.3f ankle %.3f elbow %s wrist %s" % (waist, hip, neck, knee, ankle, tuple(round(c, 2) for c in elbow), tuple(round(c, 2) for c in wrist)))


def along_arm(co):
    """0 at the shoulder, 1 at the wrist, for a point out on either arm."""
    side = 1.0 if co.x >= 0 else -1.0
    a = Vector((shoulder.x * side, shoulder.y, shoulder.z))
    b = Vector((wrist.x * side, wrist.y, wrist.z))
    return (co - a).dot(b - a) / (b - a).length_squared


# ---------------------------------------------------------------- garments
garments = []


def patterned(name, colour, pattern, rough):
    """A cloth material: plain, or a small tiling picture in two colours."""
    if not pattern:
        return plain(name, colour, rough)
    size = 64
    other = numpy.array(pattern.get("colour", [c * 0.5 for c in colour]), dtype=numpy.float32)
    first = numpy.array(colour, dtype=numpy.float32)
    grid = numpy.zeros((size, size, 4), dtype=numpy.float32)
    grid[:, :, 3] = 1.0
    ys, xs = numpy.mgrid[0:size, 0:size]
    kind = pattern.get("kind", "stripes")
    width = int(pattern.get("width", 6))
    if kind == "stripes":
        mask = (xs % size) < width
    elif kind == "bands":
        mask = (ys % size) < width
    elif kind == "checks":
        mask = ((xs % size) < width) | ((ys % size) < width)
    elif kind == "dots":
        mask = ((xs - size // 2) ** 2 + (ys - size // 2) ** 2) < width * width
    elif kind == "knit":
        mask = ((ys + (xs // 4) % 2 * 4) % 8) < 2
    else:
        mask = numpy.zeros((size, size), dtype=bool)
    grid[:, :, :3] = numpy.where(mask[:, :, None], other[None, None, :], first[None, None, :])
    picture = bpy.data.images.new(name + "_cloth", size, size, alpha=True)
    picture.pixels = grid.ravel()
    picture.filepath_raw = os.path.join(OUT, name + "_cloth.png")
    picture.file_format = "PNG"
    picture.save()
    material = bpy.data.materials.new(name)
    material.use_nodes = True
    node = material.node_tree.nodes.new("ShaderNodeTexImage")
    node.image = picture
    shader = material.node_tree.nodes["Principled BSDF"]
    material.node_tree.links.new(node.outputs[0], shader.inputs["Base Color"])
    shader.inputs["Roughness"].default_value = rough
    return material


def wrap_uv(out_mesh, repeat):
    """Round the body and up it: stripes run true on a torso, a leg or a skirt."""
    layer = out_mesh.uv_layers.new(name="Cloth") if not out_mesh.uv_layers else out_mesh.uv_layers[0]
    for polygon in out_mesh.polygons:
        middle = sum((out_mesh.vertices[v].co for v in polygon.vertices), Vector()) / len(polygon.vertices)
        side = 0.09 if middle.x > 0 else -0.09
        axis_x = side if (middle.z < hip - 0.06 and abs(middle.x) > 0.04) else 0.0
        for loop_index in polygon.loop_indices:
            co = out_mesh.vertices[out_mesh.loops[loop_index].vertex_index].co
            around = math.atan2(co.x - axis_x, -(co.y - 0.02))
            layer.data[loop_index].uv = (around / math.tau * repeat, co.z * repeat / 0.9)


def piece(name, source, keep, offset, colour, rough=0.8, thicken=None, reshape=None, pattern=None):
    """A garment: the faces of a clothing helper whose corners all pass `keep`,
    set off from the skin by `offset` metres."""
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bm.verts.ensure_lookup_table()
    source_index = group_index[source]
    deform = bm.verts.layers.deform.verify()
    wanted = set()
    for v in bm.verts:
        if source_index in v[deform] and keep(mesh.vertices[v.index]):
            wanted.add(v.index)
    lose = [f for f in bm.faces if not all(v.index in wanted for v in f.verts)]
    bmesh.ops.delete(bm, geom=lose, context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    if not bm.faces:
        bm.free()
        print("GARMENT", name, "is empty")
        return None
    bm.normal_update()
    for v in bm.verts:
        push = offset + (thicken(v.co) if thicken else 0.0)
        v.co = v.co + v.normal * push
        if reshape:
            v.co = reshape(v.co)
    for f in bm.faces:
        f.smooth = True
    out = bpy.data.meshes.new(name)
    bm.to_mesh(out)
    bm.free()
    # Shape keys do not belong on cloth.
    obj = bpy.data.objects.new(name, out)
    bpy.context.scene.collection.objects.link(obj)
    for index, group_name in names.items():
        obj.vertex_groups.new(name=group_name)
    while out.uv_layers:
        out.uv_layers.remove(out.uv_layers[0])
    wrap_uv(out, float((pattern or {}).get("repeat", 10.0)))
    obj.data.materials.append(patterned("%s_%s" % (CID, name), colour, pattern, rough))
    obj.parent = rig
    obj.modifiers.new("Armature", "ARMATURE").object = rig
    garments.append(obj)
    print("GARMENT", name, len(out.polygons), "faces")
    return obj


def torso(v, low=None, high=None, sleeves=1.0, vee=0.0):
    low = waist - 0.05 if low is None else low
    high = neck + 0.02 if high is None else high
    co = v.co
    arm = weight(v, ARM)
    if arm > 0.45:
        return along_arm(co) < sleeves
    if not (low < co.z < high):
        return False
    if vee > 0.0 and co.y < bone("Spine2").y - 0.02:
        # An open neck: a V from the collar down the chest.
        depth = (neck + 0.01) - co.z
        if depth < vee and abs(co.x) < (vee - depth) * 0.42:
            return False
    return weight(v, LEG) < 0.5 or co.z > hip - 0.02


def legs(v, low, high):
    return low < v.co.z < high and weight(v, ARM) < 0.3


def skirt_shape(hem, flare, pleats=0):
    top = hip + 0.07
    natural_hem = 0.12

    def shape(co):
        t = max(0.0, min(1.0, (top - co.z) / (top - natural_hem)))
        z = top - t * (top - hem)
        spread = 1.0 + flare * t
        if pleats:
            spread *= 1.0 + 0.05 * t * math.sin(math.atan2(co.x, -(co.y - 0.02)) * pleats)
        return Vector((co.x * spread, (co.y - 0.02) * spread + 0.02, z))
    return shape


pending_collars = []
for row in CFG["outfit"]:
    kind = row["kind"]
    colour = row["colour"]
    if kind == "shirt":
        piece(row.get("name", "Shirt"), "helper-tights", lambda v, r=row: torso(v, low=waist - 0.09, sleeves=float(r.get("sleeves", 1.0)), vee=float(r.get("vee", 0.0))), 0.004, colour, 0.85, pattern=row.get("pattern"))
    elif kind == "jumper":
        piece("Jumper", "helper-tights", lambda v, r=row: torso(v, low=hip - 0.01, sleeves=1.0, vee=float(r.get("vee", 0.0))), 0.017, colour, 0.95, pattern=row.get("pattern"))
    elif kind == "waistcoat":
        piece("Waistcoat", "helper-tights", lambda v, r=row: torso(v, low=waist - 0.04, sleeves=0.0, vee=float(r.get("vee", 0.2))) and weight(v, ARM) < 0.3, 0.011, colour, 0.7, pattern=row.get("pattern"))
    elif kind == "jacket":
        piece("Jacket", "helper-tights", lambda v, r=row: torso(v, low=hip - 0.06, sleeves=1.0, vee=float(r.get("vee", 0.3))), 0.016, colour, 0.8, pattern=row.get("pattern"))
    elif kind == "trousers":
        piece("Trousers", "helper-tights", lambda v: legs(v, ankle + 0.015, waist + 0.02), 0.014, colour, 0.85,
              thicken=lambda co: float(row.get("width", 0.03)) * max(0.0, min(1.0, (hip - 0.08 - co.z) / (hip - 0.08 - knee))) ** 0.7, pattern=row.get("pattern"))
    elif kind == "stockings":
        piece("Stockings", "helper-tights", lambda v: legs(v, ankle - 0.08, hip - 0.1), 0.002, colour, 0.5)
    elif kind == "skirt":
        piece(row.get("name", "Skirt"), "helper-skirt", lambda v: True, 0.004, colour, 0.85, reshape=skirt_shape(float(row.get("hem", 0.38)), float(row.get("flare", 0.25)), int(row.get("pleats", 0))), pattern=row.get("pattern"))
    elif kind == "belt":
        piece("Belt", "helper-tights", lambda v, r=row: abs(v.co.z - (waist + float(r.get("drop", 0.0)))) < 0.04 and weight(v, ARM) < 0.3, float(row.get("off", 0.014)), colour, 0.4)
    elif kind == "collar":
        pending_collars.append(row)
    elif kind == "cuffs":
        piece("Cuffs", "helper-tights", lambda v, r=row: weight(v, ARM) > 0.45 and abs(along_arm(v.co) - float(r.get("at", 0.9))) < 0.07, float(row.get("off", 0.02)), colour, 0.8)
    elif kind == "hem":
        piece("Hem", "helper-tights", lambda v, r=row: abs(v.co.z - (hip + float(r.get("drop", -0.02)))) < 0.04 and weight(v, ARM) < 0.3, float(row.get("off", 0.021)), colour, 0.9)

# Buttons and a tie are small made things on the chest's front.
body_tree = BVHTree.FromPolygons([tuple(v.co) for v in mesh.vertices], [tuple(q.vertices) for q in mesh.polygons])

# A turned-down collar, open at the front, with points.
for row in pending_collars:
    bm = bmesh.new()
    axis = Vector((0.0, bone("Neck").y + 0.012, 0.0))
    steps = 44
    gap = math.radians(float(row.get("gap_degrees", 16.0)))
    rings = []
    for k in range(steps + 1):
        angle = gap + (math.tau - 2 * gap) * k / steps  # 0 is the front
        direction = Vector((math.sin(angle), -math.cos(angle), 0.0))
        stand = float(row.get("stand", 0.012))
        hit = body_tree.ray_cast(axis + Vector((0, 0, neck + stand)), direction, 0.3)
        if hit[0] is None:
            continue
        reach = (hit[0] - axis).length - (neck + stand) * 0.0
        front = max(0.0, math.cos(angle)) ** 4
        fall = float(row.get("fall", 0.03)) + float(row.get("point", 0.035)) * front
        inner = axis + direction * (Vector((hit[0].x, hit[0].y, 0)) - Vector((axis.x, axis.y, 0))).length
        base = Vector((inner.x, inner.y, neck + stand))
        rings.append((bm.verts.new(base + direction * 0.005 + Vector((0, 0, 0.012))),
                      bm.verts.new(base + direction * 0.016 + Vector((0, 0, 0.008))),
                      bm.verts.new(base + direction * (0.03 + 0.012 * front) + Vector((0, 0, -fall)))))
    for a, b in zip(rings, rings[1:]):
        for j in range(2):
            face = bm.faces.new((a[j], b[j], b[j + 1], a[j + 1]))
            face.smooth = True
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    collar_mesh = bpy.data.meshes.new("Collar")
    bm.to_mesh(collar_mesh)
    bm.free()
    collar = bpy.data.objects.new("Collar", collar_mesh)
    bpy.context.scene.collection.objects.link(collar)
    collar_material = plain(CID + "_collar", row["colour"], 0.8)
    collar_material.use_backface_culling = False
    collar.data.materials.append(collar_material)
    collar.vertex_groups.new(name=PREFIX + "Neck").add(list(range(len(collar_mesh.vertices))), 0.5, "REPLACE")
    collar.vertex_groups.new(name=PREFIX + "Spine2").add(list(range(len(collar_mesh.vertices))), 0.5, "REPLACE")
    collar.parent = rig
    collar.modifiers.new("Armature", "ARMATURE").object = rig
    garments.append(collar)


def chest_front(z, x=0.0, lift=0.02):
    hit = body_tree.ray_cast(Vector((x, -1.0, z)), Vector((0, 1, 0)), 2.0)
    return hit[0] + Vector((0, -lift, 0)) if hit[0] is not None else None


small = bmesh.new()
small_material_rows = []
for row in CFG.get("trim", []):
    if row["kind"] == "buttons":
        z = neck - 0.06
        while z > waist - 0.02 - float(row.get("below", 0.0)):
            at = chest_front(z, lift=float(row.get("lift", 0.016)))
            if at is not None:
                made = bmesh.ops.create_uvsphere(small, u_segments=10, v_segments=6, radius=float(row.get("size", 0.008)))
                for v in made["verts"]:
                    v.co = Vector((v.co.x, v.co.y * 0.45, v.co.z)) + at
            z -= float(row.get("step", 0.07))
        small_material_rows.append(("Buttons", row["colour"]))
    elif row["kind"] == "tie":
        top = neck - 0.035
        length = float(row.get("length", 0.3))
        rings = []
        for k in range(9):
            t = k / 8.0
            z = top - t * length
            at = chest_front(z, lift=0.021)
            half = 0.014 + 0.02 * math.sin(min(t * 1.25, 1.0) * math.pi * 0.5) if t < 0.86 else 0.03 * (1.0 - t) / 0.14
            rings.append((small.verts.new(at + Vector((-half, 0, 0))), small.verts.new(at + Vector((half, 0, 0)))))
        for a, b in zip(rings, rings[1:]):
            small.faces.new((a[0], a[1], b[1], b[0]))
        small_material_rows.append(("Tie", row["colour"]))
if small.verts:
    small_mesh = bpy.data.meshes.new("Trim")
    bmesh.ops.recalc_face_normals(small, faces=small.faces)
    small.to_mesh(small_mesh)
    trim = bpy.data.objects.new("Trim", small_mesh)
    bpy.context.scene.collection.objects.link(trim)
    trim.data.materials.append(plain(CID + "_trim", small_material_rows[0][1], 0.35))
    trim.vertex_groups.new(name=PREFIX + "Spine2").add(list(range(len(small_mesh.vertices))), 1.0, "REPLACE")
    trim.parent = rig
    trim.modifiers.new("Armature", "ARMATURE").object = rig
    garments.append(trim)
small.free()

# ---------------------------------------------------------------- the body itself
# Only what shows is kept: head, neck, hands, and whatever the outfit bares.
bare_to = float(CFG.get("bare_arm_from", 1.0))
body_index = group_index["body"]
bm = bmesh.new()
bm.from_mesh(mesh)
bm.verts.ensure_lookup_table()
deform = bm.verts.layers.deform.verify()
neck_line = neck - float(CFG.get("neck_bare", 0.03))
keep_verts = set()
for v in bm.verts:
    if body_index not in v[deform]:
        continue
    source = mesh.vertices[v.index]
    co = v.co
    hand = weight(source, ("Hand",))
    arm = weight(source, ARM)
    if co.z > neck_line and arm < 0.5:
        keep_verts.add(v.index)
    elif hand > 0.25 or (arm > 0.45 and along_arm(co) > min(bare_to, 0.78) - 0.04):
        keep_verts.add(v.index)
    elif CFG.get("bare_chest_vee", 0.0) > 0.0 and co.y < bone("Spine2").y and neck - CFG["bare_chest_vee"] - 0.03 < co.z and abs(co.x) < 0.09 and arm < 0.3:
        keep_verts.add(v.index)
bmesh.ops.delete(bm, geom=[f for f in bm.faces if not all(v.index in keep_verts for v in f.verts)], context="FACES")
bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
bm.to_mesh(mesh)
bm.free()
human.name = "Skin"

# Skin tone.
node, image = base_image(human)
if image is not None and "skin_tone" in CFG:
    width, height = image.size
    pixels = numpy.array(image.pixels[:], dtype=numpy.float32).reshape(height, width, 4)
    pixels[:, :, :3] = numpy.clip(pixels[:, :, :3] * numpy.array(CFG["skin_tone"], dtype=numpy.float32), 0, 1)
    toned = bpy.data.images.new(CID + "_skin", width, height, alpha=True)
    toned.pixels = pixels.ravel()
    toned.filepath_raw = os.path.join(OUT, CID + "_skin.png")
    toned.file_format = "PNG"
    toned.save()
    node.image = toned
eye_file = os.path.join(USER, "eyes", "materials", CFG.get("eyes", "brown") + "_eye.png")
eye_node, _ = base_image(parts[0])
if eye_node is not None and os.path.exists(eye_file):
    eye_node.image = bpy.data.images.load(eye_file)

# ---------------------------------------------------------------- hair
head_at = bone("Head")
front = [v.co for v in mesh.vertices if abs(v.co.x) < 0.012 and head_at.z - 0.02 < v.co.z < head_at.z + 0.12]
nose = min(front, key=lambda p: p.y).copy()
hair_tone = numpy.array(CFG["hair"]["colour"], dtype=numpy.float32)
mid_y = nose.y + 0.1
skull_mid = Vector((0.0, mid_y, nose.z + 0.055))
hairline = nose.z + float(CFG["hair"].get("hairline_above_nose", 0.086))
extras = []


def scalp(q):
    if q.y < mid_y - 0.015:
        return q.z > hairline - max(0.0, abs(q.x) - 0.035) * 0.55
    if q.y < mid_y + 0.02:
        return q.z > nose.z + 0.04
    return q.z > nose.z - 0.04


# A close cap in the hair's colour under the strands, so no scalp shows through.
bm = bmesh.new()
bm.from_mesh(mesh)
bm.verts.ensure_lookup_table()
keep_faces = [f for f in bm.faces if all(scalp(v.co) for v in f.verts)]
bmesh.ops.delete(bm, geom=[f for f in bm.faces if f not in set(keep_faces)], context="FACES")
bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
bm.normal_update()
for v in bm.verts:
    v.co = v.co + v.normal * 0.0025
cap_mesh = bpy.data.meshes.new("HairCap")
bm.to_mesh(cap_mesh)
bm.free()
while cap_mesh.shape_keys:
    break
cap = bpy.data.objects.new("HairCap", cap_mesh)
bpy.context.scene.collection.objects.link(cap)
cap.data.materials.clear()
cap.data.materials.append(plain(CID + "_hair_cap", [float(c) * 0.8 for c in hair_tone], 0.6))
cap.vertex_groups.new(name=PREFIX + "Head").add(list(range(len(cap_mesh.vertices))), 1.0, "REPLACE")
cap.parent = rig
cap.modifiers.new("Armature", "ARMATURE").object = rig
extras.append(cap)

STYLES = {
    "ringlets": {"points": 32, "lying": 10, "length": [0.25, 0.31], "radius": [0.011, 0.015], "turns": [1.5, 2.1], "first_angle": 62.0, "per_side": 20,
                 "guides": 2300, "follow": 3, "follow_radius": 0.0028, "local_stiffness": 0.985, "global_stiffness": 0.5, "global_range": 0.34},
    "bob": {"points": 16, "lying": 7, "length": [0.075, 0.105], "radius": [0.003, 0.005], "turns": [0.45, 0.7], "first_angle": 48.0, "per_side": 16,
            "guides": 1400, "follow": 4, "follow_radius": 0.005, "local_stiffness": 0.98, "global_stiffness": 0.7, "global_range": 0.5},
    "short": {"points": 16, "lying": 16, "length": [0.05, 0.085], "radius": [0.0, 0.0], "turns": [0.0, 0.0], "first_angle": 30.0, "per_side": 14,
              "guides": 2600, "follow": 4, "follow_radius": 0.004, "local_stiffness": 0.995, "global_stiffness": 0.97, "global_range": 1.0},
}
STYLE = dict(STYLES[CFG["hair"].get("style", "bob")])
STYLE.update({k: v for k, v in CFG["hair"].items() if k in STYLE})
head_tree = BVHTree.FromPolygons([tuple(v.co) for v in mesh.vertices], [tuple(q.vertices) for q in mesh.polygons])
cloth_points = [tuple(g.matrix_world @ v.co) for g in garments for v in g.data.vertices]
cloth_polys = []
start = 0
for g in garments:
    cloth_polys += [tuple(i + start for i in q.vertices) for q in g.data.polygons]
    start += len(g.data.vertices)
cloth_tree = BVHTree.FromPolygons(cloth_points, cloth_polys) if cloth_polys else None
root_pool = [v.co.copy() for v in mesh.vertices if scalp(v.co)]
if "root_max_above_nose" in CFG["hair"]:
    root_pool = [q for q in root_pool if q.z < nose.z + float(CFG["hair"]["root_max_above_nose"])]
rng = numpy.random.default_rng(23)
ringlets = []
for side in (1.0, -1.0):
    for k in range(int(STYLE["per_side"])):
        angle = math.radians(STYLE["first_angle"] + (180.0 - STYLE["first_angle"]) * (k + 0.5) / STYLE["per_side"])
        ringlets.append({"side": side, "angle": angle, "drop": Vector((side * math.sin(angle) * 0.083, mid_y - math.cos(angle) * 0.09, nose.z + float(rng.uniform(-0.01, 0.02)))),
                         "length": float(rng.uniform(*STYLE["length"])), "phase": float(rng.uniform(0, math.tau)),
                         "turns": float(rng.uniform(*STYLE["turns"])) * (1 if k % 2 else -1), "radius": float(rng.uniform(*STYLE["radius"]))})
points_per = int(STYLE["points"])
lying = int(STYLE["lying"])
short_cut = CFG["hair"].get("style") == "short"
rows = []
for number in range(int(STYLE["guides"]) * 3):
    if len(rows) >= int(STYLE["guides"]):
        break
    root = root_pool[int(rng.integers(len(root_pool)))]
    side = 1.0 if root.x >= 0 else -1.0
    angle = math.atan2(abs(root.x), -(root.y - mid_y))
    mine = min((r for r in ringlets if r["side"] == side), key=lambda r: abs(r["angle"] - angle) + float(rng.uniform(0, 0.25)))
    d0 = (root - skull_mid).normalized()
    d1 = (mine["drop"] - skull_mid).normalized()
    reach = 1.0
    if short_cut:
        d1 = (Vector((side * 0.02, mid_y + 0.09, nose.z - 0.03)) - skull_mid).normalized()
        reach = min(1.0, mine["length"] / max(d0.angle(d1) * 0.095, 0.001))
    own_offset = Vector((float(rng.normal(0, 0.0028)), float(rng.normal(0, 0.0028)), 0.0))
    strand = []
    for i in range(lying):
        t = i / (lying - 1.0)
        direction = d0.slerp(d1, t * reach).normalized()
        hit = head_tree.ray_cast(skull_mid, direction, 0.4)
        if hit[0] is None:
            strand = []
            break
        strand.append(hit[0] + direction * ((0.004 + 0.007 * math.sin(t * math.pi * 0.9)) if short_cut else (0.005 + 0.012 * t)))
    if not strand:
        continue
    begin = strand[-1]
    down = Vector((0, 0, -1))
    away = Vector((begin.x - skull_mid.x, begin.y - skull_mid.y, 0.0))
    away = away.normalized() if away.length > 1e-6 else Vector((side, 0, 0))
    for i in range(1, points_per - lying + 1):
        sdown = i / float(max(points_per - lying, 1))
        grow = min(1.0, sdown * 3.0)
        turn_ = mine["phase"] + sdown * mine["turns"] * math.tau
        across = away.cross(down).normalized()
        where = begin + down * mine["length"] * sdown + away * (0.012 * sdown) + (away * math.cos(turn_) + across * math.sin(turn_)) * mine["radius"] * grow + own_offset * grow
        if cloth_tree is not None:
            for _ in range(3):
                near = cloth_tree.find_nearest(where, 0.08)
                if near[0] is None:
                    break
                if (where - near[0]).dot(near[1]) < 0.014:
                    where = near[0] + near[1] * 0.016
        strand.append(where)
    for _ in range(2):
        eased = list(strand)
        for i in range(max(lying, 1), len(strand) - 1):
            eased[i] = (strand[i - 1] + strand[i] * 2.0 + strand[i + 1]) / 4.0
        strand = eased
    rows.append(strand)
hair_curves = bpy.data.hair_curves.new(CID + "_hair")
hair_curves.add_curves([points_per] * len(rows))
hair_curves.position_data.foreach_set("vector", numpy.array([[c for c in p] for strand in rows for p in strand], dtype=numpy.float32).ravel())
hair_object = bpy.data.objects.new(CID + "_hair", hair_curves)
bpy.context.scene.collection.objects.link(hair_object)
hair_curves.surface = human
hair_curves.surface_uv_map = human.data.uv_layers.active.name


def hull(name, points, bone_name, shrink):
    bm = bmesh.new()
    for point in points:
        bm.verts.new(point)
    made = bmesh.ops.convex_hull(bm, input=bm.verts[:])
    bmesh.ops.delete(bm, geom=list({g for g in made.get("geom_interior", []) + made.get("geom_unused", []) if isinstance(g, bmesh.types.BMVert)}), context="VERTS")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    middle = sum((v.co for v in bm.verts), Vector()) / max(len(bm.verts), 1)
    for v in bm.verts:
        v.co = middle + (v.co - middle) * shrink
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    out = bpy.data.meshes.new(name)
    bm.to_mesh(out)
    bm.free()
    obj = bpy.data.objects.new(name, out)
    bpy.context.scene.collection.objects.link(obj)
    obj.vertex_groups.new(name=bone_name).add(list(range(len(out.vertices))), 1.0, "REPLACE")
    obj.parent = rig
    obj.modifiers.new("Armature", "ARMATURE").object = rig
    obj.hide_render = True
    return obj


head_collider = hull(CID + "_head_collider", [v.co.copy() for v in mesh.vertices if v.co.z > nose.z - 0.08][::3], PREFIX + "Head", 0.955)
torso_points = [Vector(p) for p in cloth_points if waist - 0.2 < p[2] < neck + 0.03 and abs(p[0]) < 0.24][::3]
body_collider = hull(CID + "_body_collider", torso_points, PREFIX + "Spine2", 0.97)

def on_head(obj):
    obj.vertex_groups.new(name=PREFIX + "Head").add(list(range(len(obj.data.vertices))), 1.0, "REPLACE")
    obj.parent = rig
    obj.modifiers.new("Armature", "ARMATURE").object = rig
    extras.append(obj)


skull = [v.co.copy() for v in mesh.vertices if v.co.z > nose.z + 0.066]
if CFG.get("hat") and skull:
    top_z = max(q.z for q in skull)
    brow_z = nose.z + 0.066
    centre = Vector(((max(q.x for q in skull) + min(q.x for q in skull)) / 2, (max(q.y for q in skull) + min(q.y for q in skull)) / 2, 0))
    half_w = (max(q.x for q in skull) - min(q.x for q in skull)) / 2 + 0.008
    half_d = (max(q.y for q in skull) - min(q.y for q in skull)) / 2 + 0.008
    crown_top = top_z + 0.014
    crown_foot = brow_z + 0.034
    hat_rows = []
    for k in range(13):
        t = k / 12.0
        angle = t * math.pi / 2
        hat_rows.append((math.sin(angle) ** 0.8 * 1.085, crown_top - (1 - math.cos(angle)) ** 1.25 * (crown_top - crown_foot), t * 0.55))
    brim = float(CFG["hat"].get("brim", 1.0))
    hat_rows += [(1.1, brow_z + 0.022, 0.7), (1.1 + 0.06 * brim, brow_z + 0.012, 0.85), (1.1 + 0.15 * brim, brow_z + 0.0, 1.0), (1.1 + 0.22 * brim, brow_z - 0.013, 1.0),
                 (1.1 + 0.2 * brim, brow_z - 0.016, 1.0), (1.1 + 0.12 * brim, brow_z - 0.003, 1.0), (1.1, brow_z + 0.012, 0.85), (1.05, brow_z + 0.03, 0.6)]
    bm = bmesh.new()
    rings = []
    steps = 56
    for r, z, low in hat_rows:
        ring = []
        for k in range(steps):
            a = math.tau * k / steps
            dip = 0.024 * (1 + math.sin(a)) * 0.5 * low
            ring.append(bm.verts.new((centre.x + math.cos(a) * r * half_w, centre.y + math.sin(a) * r * half_d, z - dip)))
        rings.append(ring)
    for index, (a, b) in enumerate(zip(rings, rings[1:])):
        for k in range(steps):
            face = bm.faces.new((a[k], a[(k + 1) % steps], b[(k + 1) % steps], b[k]))
            face.material_index = 1 if index in (12, 13) else 0
            face.smooth = True
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    hat_mesh = bpy.data.meshes.new("Hat")
    bm.to_mesh(hat_mesh)
    bm.free()
    hat = bpy.data.objects.new("Hat", hat_mesh)
    bpy.context.scene.collection.objects.link(hat)
    hat.data.materials.append(plain(CID + "_hat", CFG["hat"]["colour"], 0.9))
    hat.data.materials.append(plain(CID + "_hat_band", CFG["hat"].get("band", [c * 0.35 for c in CFG["hat"]["colour"]]), 0.5))
    on_head(hat)
if CFG.get("spectacles"):
    bm = bmesh.new()

    def tube(a, b, radius=0.0012):
        a = Vector(a)
        b = Vector(b)
        axis_ = b - a
        made = bmesh.ops.create_cone(bm, cap_ends=True, segments=8, radius1=radius, radius2=radius, depth=axis_.length)
        turn = Vector((0, 0, 1)).rotation_difference(axis_.normalized()).to_matrix().to_4x4()
        bmesh.ops.transform(bm, matrix=Matrix.Translation((a + b) / 2) @ turn, verts=made["verts"])

    eyes_at = [rig.matrix_world @ Vector((side * 0.03, nose.y + 0.06, nose.z + 0.036)) for side in (1, -1)]
    lens_r = 0.021
    front_y = nose.y + 0.014
    centres = [Vector((e.x * 1.06, front_y, e.z)) for e in eyes_at]
    for c in centres:
        ring = [c + Vector((math.cos(math.tau * k / 24) * lens_r, 0, math.sin(math.tau * k / 24) * lens_r)) for k in range(24)]
        for k in range(24):
            tube(ring[k], ring[(k + 1) % 24])
        out = 1 if c.x > 0 else -1
        hinge = c + Vector((out * lens_r, 0, 0.004))
        tube(hinge, hinge + Vector((out * 0.012, 0.03, 0)))
        tube(hinge + Vector((out * 0.012, 0.03, 0)), hinge + Vector((out * 0.014, 0.115, -0.004)))
    tube(centres[1] + Vector((lens_r, 0, 0.004)), centres[0] + Vector((-lens_r, 0, 0.004)))
    glasses_mesh = bpy.data.meshes.new("Spectacles")
    bm.to_mesh(glasses_mesh)
    bm.free()
    glasses = bpy.data.objects.new("Spectacles", glasses_mesh)
    bpy.context.scene.collection.objects.link(glasses)
    glasses.data.materials.append(plain(CID + "_wire", [0.6, 0.45, 0.12], 0.3, 1.0))
    on_head(glasses)

# One skeleton for the whole cast, under plain names.
for b in rig.data.bones:
    if b.name.startswith(PREFIX):
        b.name = b.name[len(PREFIX):]
bpy.context.view_layer.update()
exporter = CFG.get("tressfx_exporter", TABLE.get("_tressfx_exporter", "C:/ov/tools/tressfx_godot/addons/tressfx/tools/tressfx_blender_export.py"))
spec = importlib.util.spec_from_file_location("tressfx_blender_export", exporter)
tfx = importlib.util.module_from_spec(spec)
spec.loader.exec_module(tfx)
for label, result in (("hair", tfx.export_hair(bpy.context, hair_object, os.path.join(OUT, CID + "_hair.tfx"), points_per, True)),
                      ("head collider", tfx.export_collider(bpy.context, head_collider, os.path.join(OUT, CID + "_head.tfxmesh"), True)),
                      ("body collider", tfx.export_collider(bpy.context, body_collider, os.path.join(OUT, CID + "_body.tfxmesh"), True))):
    print("TRESSFX", label, result)
hair_object.hide_render = True
recipe = {"schema_version": 1, "rig_scale_baked": 1.0, "hair": CID + "_hair.tfx", "bones": CID + "_hair.tfxbone",
          "colliders": [] if short_cut else [{"file": CID + "_head.tfxmesh", "bone": "Head"}, {"file": CID + "_body.tfxmesh", "bone": "Spine2"}],
          "follow": int(STYLE["follow"]), "follow_radius": float(STYLE["follow_radius"]), "local_stiffness": float(STYLE["local_stiffness"]),
          "global_stiffness": float(STYLE["global_stiffness"]), "global_range": float(STYLE["global_range"]),
          "base_colour": [round(float(c), 4) for c in numpy.clip(hair_tone * 0.95, 0, 1)], "tip_colour": [round(float(c), 4) for c in numpy.clip(hair_tone * 1.3, 0, 1)],
          "fibre_radius": float(CFG["hair"].get("fibre_radius", 0.001))}
json.dump(recipe, open(os.path.join(OUT, CID + "_hair.json"), "w", encoding="utf-8"), indent=1)

bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, CID + ".blend"))

# ---------------------------------------------------------------- look at it, export
scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x = 620
scene.render.resolution_y = 900
scene.view_settings.view_transform = "Standard"
scene.world = bpy.data.worlds.new("W")
scene.world.use_nodes = True
scene.world.node_tree.nodes["Background"].inputs[0].default_value = (0.22, 0.22, 0.24, 1)
scene.world.node_tree.nodes["Background"].inputs[1].default_value = 0.45
cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
scene.collection.objects.link(cam)
scene.camera = cam
for loc, energy in [((1.4, -2.4, 2.3), 110), ((-1.8, -1.6, 1.5), 40), ((0.0, 2.0, 2.0), 40)]:
    light = bpy.data.objects.new("L", bpy.data.lights.new("L", "AREA"))
    light.data.energy = energy
    light.data.size = 2.0
    light.location = loc
    light.rotation_euler = (Vector((0, 0, 1.0)) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    scene.collection.objects.link(light)
for name, yaw in (("front", 0.0), ("three_quarter", 35.0)):
    at = Vector((0, 0, 0.86))
    cam.location = at + Matrix.Rotation(math.radians(yaw), 3, "Z") @ Vector((0, -3.5, 0))
    cam.rotation_euler = (at - cam.location).to_track_quat("-Z", "Y").to_euler()
    cam.data.lens = 55
    scene.render.filepath = os.path.join(OUT, "%s_%s.png" % (CID, name))
    try:
        bpy.ops.render.render(write_still=True)
    except Exception:
        traceback.print_exc()
bpy.ops.object.select_all(action="DESELECT")
for obj in [rig, human] + parts + garments + extras:
    obj.select_set(True)
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, CID + ".glb"), use_selection=True, export_format="GLB",
                          export_morph=True, export_morph_normal=False, export_animations=False, export_yup=True)
print("EXPORTED", os.path.getsize(os.path.join(OUT, CID + ".glb")))
print("DONE")
