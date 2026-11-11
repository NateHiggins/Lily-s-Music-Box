"""Give a cast member a real head and hands, keeping the body and clothes.

blender -b --python cast_graft.py -- <character id> <config json> <characters dir> <out dir>

The old generated shell keeps its clothes, proportions, skeleton and clips.
Its painted head skin and mitten hands are cut away, and a head and two hands
from the MakeHuman base (MPFB2, CC0 assets) are fitted in their place: a head
with eyes, lids, lashes, brows, teeth and tongue and 67 face shapes (15 mouth
shapes for speech, 52 face units), and hands with fifteen finger bones each.
Whatever sat outside the old skin (a hat, hair, spectacles) stays.
"""
import bpy, bmesh, os, sys, glob, json, math, importlib, traceback
import numpy
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

CID, CONFIG, CHARS, OUT = sys.argv[sys.argv.index("--") + 1:][:4]
CFG = json.load(open(CONFIG, encoding="utf-8"))[CID]
os.makedirs(OUT, exist_ok=True)
M = "bl_ext.blender_org.mpfb"
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.preferences.addon_enable(module=M)
svc = lambda n: importlib.import_module(M + ".services." + n)
HS = svc("humanservice").HumanService
TS = svc("targetservice").TargetService
FS = svc("faceservice").FaceService
USER = svc("locationservice").LocationService.get_user_data()
FINGERS = {"1": "Thumb", "2": "Index", "3": "Middle", "4": "Ring", "5": "Pinky"}


def asset(kind, name, ext="mhclo"):
    hits = glob.glob(os.path.join(USER, kind, name, "*." + ext))
    if not hits:
        raise RuntimeError("no asset %s/%s" % (kind, name))
    return hits[0]


def weights_by_name(obj):
    names = {g.index: g.name for g in obj.vertex_groups}
    return [{names[g.group]: g.weight for g in v.groups} for v in obj.data.vertices]


def keep_only(obj, keep):
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.verts.ensure_lookup_table()
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.index not in keep], context="VERTS")
    bm.to_mesh(obj.data)
    bm.free()


def copy_object(obj, name):
    twin = obj.copy()
    twin.data = obj.data.copy()
    twin.name = name
    bpy.context.scene.collection.objects.link(twin)
    return twin


def subtree(bone):
    out = {bone.name}
    for child in bone.children:
        out |= subtree(child)
    return out


# ---------------------------------------------------------------- the base
macro = TS.get_default_macro_info_dict()
macro.update(CFG["macro"])
macro["race"] = CFG.get("race", {"asian": 0.0, "caucasian": 1.0, "african": 0.0})
human = HS.create_human(macro_detail_dict=macro)
TS.bake_targets(human)
HS.set_character_skin(asset("skins", CFG["skin"], "mhmat"), human, skin_type="GAMEENGINE", material_instances=False)
rig = HS.add_builtin_rig(human, "default_no_toes")
parts = []
for kind, name, atype in [("eyes", "low-poly", "Eyes"), ("eyebrows", CFG.get("eyebrows", "eyebrow001"), "Eyebrows"),
                          ("eyelashes", "eyelashes01", "Eyelashes"), ("teeth", "teeth_base", "Teeth"), ("tongue", "tongue01", "Tongue")]:
    if name == "none":
        continue
    part = HS.add_mhclo_asset(asset(kind, name), human, asset_type=atype, subdiv_levels=0, material_type="GAMEENGINE")
    part.name = "Face_" + kind
    parts.append(part)
hair = None
if CFG.get("hair"):
    hair = HS.add_mhclo_asset(asset("hair", CFG["hair"]), human, asset_type="Hair", subdiv_levels=0, material_type="GAMEENGINE")
    hair.name = "Hair"
    parts.append(hair)
eye_at = {side: rig.matrix_world @ rig.data.bones["eye." + side].head_local for side in ("L", "R")}
FS.load_targets(human, load_microsoft_visemes=False, load_meta_visemes=True, load_arkit_faceunits=True)
FS.interpolate_targets(human)
for modifier in list(human.modifiers):
    human.modifiers.remove(modifier)

bones = rig.data.bones
world = rig.matrix_world
head_bones = subtree(bones["neck03"])
neck_bones = {"neck01", "neck02"}
weights = weights_by_name(human)
body_group = human.vertex_groups["body"].index
is_body = [any(g.group == body_group for g in v.groups) for v in human.data.vertices]
neck_base = (world @ bones["neck01"].head_local).z
head_keep = set()
for index, vertex in enumerate(human.data.vertices):
    if not is_body[index]:
        continue
    share = sum(w for n, w in weights[index].items() if n in head_bones or n in neck_bones)
    co = human.matrix_world @ vertex.co
    if share >= 0.5 or (co.z > neck_base - CFG.get("neck_stub", 0.075) and abs(co.x) < 0.08 and abs(co.y) < 0.095):
        head_keep.add(index)
hand_keep = {}
for side in ("L", "R"):
    hand_bones = subtree(bones["wrist." + side])
    wrist = world @ bones["wrist." + side].head_local
    keep = set()
    for index, vertex in enumerate(human.data.vertices):
        if not is_body[index]:
            continue
        share = sum(w for n, w in weights[index].items() if n in hand_bones)
        co = human.matrix_world @ vertex.co
        fore = sum(w for n, w in weights[index].items() if n.startswith("lowerarm") and n.endswith(side))
        if share >= 0.5 or (fore > 0.3 and (co - wrist).length < CFG.get("wrist_stub", 0.055)):
            keep.add(index)
    hand_keep[side] = keep

mouth_points = [human.matrix_world @ v.co for i, v in enumerate(human.data.vertices)
                if is_body[i] and sum(w for n, w in weights[i].items() if n.startswith("oris")) > 0.6]
mouth_new = sum(mouth_points, Vector()) / max(len(mouth_points), 1)
head = copy_object(human, "Face_skin")
keep_only(head, head_keep)
hands = {}
for side in ("L", "R"):
    hand = copy_object(human, "Hand_" + side)
    keep_only(hand, hand_keep[side])
    hand.shape_key_clear()
    hands[side] = hand
print("PIECES head", len(head.data.vertices), "hands", [len(h.data.vertices) for h in hands.values()],
      "keys", len(head.data.shape_keys.key_blocks))

# Landmarks on the base, before anything moves.
strip = [head.matrix_world @ v.co for v in head.data.vertices if abs(v.co.x) < 0.012]
nose_new = min(strip, key=lambda p: p.y)
finger_rest = {}
hand_frame_new = {}
for side in ("L", "R"):
    rows = []
    for name in sorted(subtree(bones["wrist." + side])):
        if not name.startswith("finger"):
            continue
        bone = bones[name]
        rows.append((name, bone.parent.name, world @ bone.head_local, world @ bone.tail_local, (world @ bone.matrix_local).to_3x3()))
    finger_rest[side] = rows
    wrist = world @ bones["wrist." + side].head_local
    along = ((world @ bones["finger3-1." + side].head_local) - wrist).normalized()
    across = ((world @ bones["finger2-1." + side].head_local) - (world @ bones["finger5-1." + side].head_local)).normalized()
    normal = along.cross(across).normalized()
    across = normal.cross(along).normalized()
    reach = max(((hands[side].matrix_world @ v.co) - wrist).dot(along) for v in hands[side].data.vertices)
    hand_frame_new[side] = (wrist, Matrix((along, normal, across)).transposed(), reach)

# ---------------------------------------------------------------- the old body
before = set(bpy.data.objects)
source = os.path.join(CHARS, CID, CID + ".gltf")
if not os.path.exists(source):
    source = os.path.join(CHARS, CID, CID + ".glb")
bpy.ops.import_scene.gltf(filepath=source)
fresh = [o for o in bpy.data.objects if o not in before]
old_rig = [o for o in fresh if o.type == "ARMATURE"][0]
old_meshes = [o for o in fresh if o.type == "MESH" and len(o.data.vertices) > 500]
for junk in [o for o in fresh if o.type == "MESH" and o not in old_meshes]:
    bpy.data.objects.remove(junk)
shell = old_meshes[0]
# Bodies whose skeleton uses other names are worked on under the common names
# and given their own names back before saving.
RENAMED = CFG.get("bones", {})
for common, own in RENAMED.items():
    old_rig.data.bones[own].name = common
    group = shell.vertex_groups.get(own)
    if group is not None:
        group.name = common
# Some skeletons hang the jaw and mouth on the neck bone. Give everything from
# the chin up to the head bone, so a face is one thing.
if "head_weights_from" in CFG:
    floor_z = (old_rig.matrix_world @ old_rig.data.bones["Head"].head_local).z + float(CFG["head_weights_from"])
    head_group = shell.vertex_groups["Head"]
    neck_group = shell.vertex_groups["neck"]
    moved = 0
    for vertex in shell.data.vertices:
        if (shell.matrix_world @ vertex.co).z < floor_z:
            continue
        share = {g.group: g.weight for g in vertex.groups}
        neck_share = share.get(neck_group.index, 0.0)
        if neck_share > 0.0:
            head_group.add([vertex.index], share.get(head_group.index, 0.0) + neck_share, "REPLACE")
            neck_group.remove([vertex.index])
            moved += 1
    print("HEAD WEIGHTS moved", moved)
# A body that takes its finish from the game's material library has no
# material of its own in the file.
if CFG.get("albedo") and not any(slot.material for slot in shell.material_slots):
    finish = bpy.data.materials.new(CID + "_finish")
    finish.use_nodes = True
    picture = finish.node_tree.nodes.new("ShaderNodeTexImage")
    picture.image = bpy.data.images.load(os.path.join(os.path.dirname(os.path.dirname(CHARS)), CFG["albedo"]))
    finish.node_tree.links.new(picture.outputs[0], finish.node_tree.nodes["Principled BSDF"].inputs["Base Color"])
    finish.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.8
    shell.data.materials.clear()
    shell.data.materials.append(finish)
# The importer splits points along every texture seam; weld them so a hat or a
# head of hair is one piece again and not a hundred.
bm = bmesh.new()
bm.from_mesh(shell.data)
bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.00002)
bm.to_mesh(shell.data)
bm.free()
old_world = old_rig.matrix_world
ob = old_rig.data.bones


def joint(name):
    return old_world @ ob[name].head_local


old_weights = weights_by_name(shell)
shell_world = shell.matrix_world
print("OLD", shell.name, len(shell.data.vertices), "materials", [s.material.name for s in shell.material_slots])

# ---------------------------------------------------------------- place the head
if CFG.get("nose", "auto") == "auto":
    # The tip of the nose: the foremost point of the old face on its midline.
    head_at = joint("Head")
    front = [shell_world @ v.co for i, v in enumerate(shell.data.vertices)
             if old_weights[i].get("Head", 0.0) > 0.5 and abs((shell_world @ v.co).x - head_at.x) < 0.012
             and head_at.z + float(CFG.get("nose_low", -0.03)) < (shell_world @ v.co).z < head_at.z + float(CFG.get("nose_high", 0.075))]
    nose_old = min(front, key=lambda point: point.y).copy()
    print("NOSE", [round(c, 4) for c in nose_old])
else:
    nose_old = Vector(CFG["nose"])
scale = float(CFG.get("head_scale", 1.0))
tilt = Matrix.Rotation(math.radians(float(CFG.get("head_pitch_degrees", 0.0))), 4, "X")
head_move = Matrix.Translation(nose_old) @ tilt @ Matrix.Scale(scale, 4) @ Matrix.Translation(-nose_new)
for obj in [head] + parts:
    obj.parent = None
    obj.matrix_world = Matrix.Identity(4)
    obj.data.transform(head_move, shape_keys=True)
    obj.data.update()

# ---------------------------------------------------------------- place the hands
hand_move = {}
for side, old_side in (("L", "Left"), ("R", "Right")):
    wrist_old = joint(old_side + "Hand")
    points = [shell_world @ v.co for i, v in enumerate(shell.data.vertices) if old_weights[i].get(old_side + "Hand", 0.0) > 0.5]
    centre = sum(points, Vector()) / len(points)
    along = (centre - wrist_old).normalized()
    # The flat of a mitten: the direction its points spread least in.
    best = None
    for step in range(180):
        angle = math.radians(step)
        seed = Vector((1, 0, 0)) if abs(along.x) < 0.9 else Vector((0, 1, 0))
        u = along.cross(seed).normalized()
        v = along.cross(u).normalized()
        normal = (u * math.cos(angle) + v * math.sin(angle)).normalized()
        spread = sum(((p - centre).dot(normal)) ** 2 for p in points)
        if best is None or spread < best[0]:
            best = (spread, normal)
    normal = best[1]
    wrist_new, frame_new, reach_new = hand_frame_new[side]
    reach_old = max((p - wrist_old).dot(along) for p in points)
    size = max(0.82, min(1.18, reach_old / reach_new)) * float(CFG.get("hand_scale", 1.0))
    # Two candidate flats (the palm may face either way); take the one that
    # keeps the thumb on the side it is on in the base's own pose.
    chosen = None
    for sign in (1.0, -1.0):
        n = normal * sign
        across = n.cross(along).normalized()
        frame_old = Matrix((along, n, across)).transposed()
        turn = frame_old @ frame_new.transposed()
        thumb_new = (world @ bones["finger1-2." + side].head_local) - wrist_new
        thumb_old = turn @ thumb_new
        score = thumb_old.dot(Vector((0, -1, 0)))
        if chosen is None or score > chosen[0]:
            chosen = (score, turn)
    if CFG.get("hand_flip", False):
        chosen = (0, chosen[1] @ Matrix.Rotation(math.pi, 3, frame_new.col[0]))
    turn = chosen[1].to_4x4()
    move = Matrix.Translation(wrist_old) @ turn @ Matrix.Scale(size, 4) @ Matrix.Translation(-wrist_new)
    hand_move[side] = move
    hand = hands[side]
    hand.parent = None
    hand.matrix_world = Matrix.Identity(4)
    hand.data.transform(move)
    print("HAND", side, "size %.2f reach old %.3f new %.3f" % (size, reach_old, reach_new))

# ---------------------------------------------------------------- cut the old skin away
def base_image(obj):
    for slot in obj.material_slots:
        tree_ = slot.material.node_tree if slot.material and slot.material.use_nodes else None
        if tree_ is None:
            continue
        for node in tree_.nodes:
            if node.type == "TEX_IMAGE" and node.image and any(l.to_socket.name == "Base Color" for l in node.outputs[0].links):
                return node, node.image
        for node in tree_.nodes:
            if node.type == "TEX_IMAGE" and node.image:
                return node, node.image
    return None, None


def vertex_colours(obj):
    node, image = base_image(obj)
    width, height = image.size
    pixels = numpy.array(image.pixels[:], dtype=numpy.float32).reshape(height, width, 4)
    uv = obj.data.uv_layers.active.data
    out = [None] * len(obj.data.vertices)
    for loop in obj.data.loops:
        if out[loop.vertex_index] is None:
            u, v = uv[loop.index].uv
            out[loop.vertex_index] = pixels[int((v % 1.0) * (height - 1)), int((u % 1.0) * (width - 1)), :3]
    return [c if c is not None else numpy.zeros(3, dtype=numpy.float32) for c in out]


old_colour = vertex_colours(shell)
near_nose = [old_colour[i] for i, v in enumerate(shell.data.vertices) if ((shell_world @ v.co) - nose_old).length < 0.028]
skin_ref = numpy.median(numpy.array(near_nose), axis=0)
print("SKIN old", [round(float(c), 3) for c in skin_ref], "from", len(near_nose))


def is_skin(colour, loose=False):
    total = float(colour.sum())
    ref_total = float(skin_ref.sum())
    if total < (0.14 if loose else 0.3):
        return False
    chroma = colour / total - skin_ref / ref_total
    reach = float(CFG.get("skin_chroma", 0.03)) * (1.6 if loose else 1.0)
    return float(numpy.abs(chroma).max()) < reach and (0.06 if loose else 0.5) < total / ref_total < 1.6


crown = [old_colour[i] for i, v in enumerate(shell.data.vertices)
         if old_weights[i].get("Head", 0.0) > 0.5 and (shell_world @ v.co).z > joint("Head").z + float(CFG.get("crown_above_head", 0.11))]
hair_ref = numpy.median(numpy.array(crown), axis=0) if len(crown) > 20 else None
feature_marks = None
turned_move = None
print("HAIR ref", [round(float(c), 3) for c in (hair_ref / float(hair_ref.sum()))] if hair_ref is not None else None, "skin", [round(float(c), 3) for c in (skin_ref / float(skin_ref.sum()))])


def is_hair(colour, reach=None):
    if hair_ref is None:
        return False
    total = float(colour.sum())
    if total < 0.03:
        return True
    chroma = colour / total
    if reach is not None and float(chroma[2]) > float(hair_ref[2] / hair_ref.sum()) + 0.075:
        return False
    return float(numpy.abs(chroma - hair_ref / float(hair_ref.sum())).max()) < (reach if reach is not None else float(CFG.get("hair_chroma", 0.035)))


# ---------------------------------------------------------------- set the head by the old face's features
# A head that was sculpted turned or tilted cannot be matched by its nose
# alone. Find the old face's painted eyes and mouth, and turn, size and place
# the new head so its eyes, nose and mouth sit on them.
if CFG.get("align") == "features":
    ref = skin_ref / float(skin_ref.sum())
    eye_points = {"L": [], "R": []}
    lip_points = []
    # The face has few points of its own, so read the painting itself: many
    # samples across each face of the old head's front.
    _, painting = base_image(shell)
    wide, high = painting.size
    paint = numpy.array(painting.pixels[:], dtype=numpy.float32).reshape(high, wide, 4)
    uv_data = shell.data.uv_layers.active.data
    grid = [(i / 8.0, j / 8.0) for i in range(9) for j in range(9 - i)]
    for polygon in shell.data.polygons:
        if any(old_weights[v].get("Head", 0.0) < 0.5 for v in polygon.vertices):
            continue
        corners = [shell_world @ shell.data.vertices[v].co for v in polygon.vertices]
        middle = sum(corners, Vector()) / len(corners)
        if middle.y > nose_old.y + 0.05 or abs(middle.x - nose_old.x) > 0.06 or abs(middle.z - nose_old.z) > 0.07:
            continue
        uvs = [uv_data[l].uv.copy() for l in polygon.loop_indices]
        for k in range(1, len(corners) - 1):
            for a_, b_ in grid:
                c_ = 1.0 - a_ - b_
                co = corners[0] * a_ + corners[k] * b_ + corners[k + 1] * c_
                uv = uvs[0] * a_ + uvs[k] * b_ + uvs[k + 1] * c_
                colour = paint[int((uv.y % 1.0) * (high - 1)), int((uv.x % 1.0) * (wide - 1)), :3]
                total = float(colour.sum())
                if total < 0.15:
                    continue
                chroma = colour / total
                rise = co.z - nose_old.z
                if 0.012 < rise < 0.06 and abs(co.x - nose_old.x) > 0.012 and float(chroma[2] - ref[2]) > float(CFG.get("eye_blue", 0.05)):
                    eye_points["L" if co.x > nose_old.x else "R"].append(co)
                if -0.05 < rise < -0.008 and abs(co.x - nose_old.x) < 0.035 and float(chroma[0] - ref[0]) > 0.03 and float(chroma[1]) < float(ref[1]) - 0.02:
                    lip_points.append(co)
    probe = [(shell_world @ v.co, old_colour[i]) for i, v in enumerate(shell.data.vertices) if old_weights[i].get("Head", 0.0) >= 0.5]
    probe = [(c, k) for c, k in probe if c.y < nose_old.y + 0.05 and abs(c.x - nose_old.x) < 0.06 and float(k.sum()) > 0.2]
    print("FEATURES probe", len(probe), "ref", [round(float(x), 3) for x in ref])
    for low, high in ((-0.05, -0.03), (-0.03, -0.008), (0.012, 0.03), (0.03, 0.045), (0.045, 0.06)):
        rows = [k / float(k.sum()) for c, k in probe if low < c.z - nose_old.z < high]
        if rows:
            arr = numpy.array(rows)
            print("FEATURES band %.3f..%.3f n=%d r %.3f..%.3f g %.3f..%.3f b %.3f..%.3f neutral_min %.3f" % (low, high, len(rows), arr[:,0].min(), arr[:,0].max(), arr[:,1].min(), arr[:,1].max(), arr[:,2].min(), arr[:,2].max(), float(numpy.abs(arr - 1/3).max(axis=1).min())))
    print("FEATURES eyes", len(eye_points["L"]), len(eye_points["R"]), "lips", len(lip_points))
    if min(len(eye_points["L"]), len(eye_points["R"]), len(lip_points)) >= 6:
        old_marks = [nose_old] + [sum(eye_points[side], Vector()) / len(eye_points[side]) for side in ("L", "R")] + [sum(lip_points, Vector()) / len(lip_points)]
        new_marks = [nose_new] + [eye_at[side] + Vector((0, -0.0125, 0)) for side in ("L", "R")] + [Vector((mouth_new.x, min(q.y for q in mouth_points), mouth_new.z))]
        src = numpy.array([list(q) for q in new_marks])
        dst = numpy.array([list(q) for q in old_marks])
        src_mid = src.mean(axis=0)
        dst_mid = dst.mean(axis=0)
        a_ = src - src_mid
        b_ = dst - dst_mid
        u, sing, vt = numpy.linalg.svd(b_.T @ a_)
        fix = numpy.diag([1.0, 1.0, numpy.sign(numpy.linalg.det(u @ vt))])
        turn = u @ fix @ vt
        size = float((sing * numpy.diag(fix)).sum() / (a_ ** 2).sum())
        size *= float(CFG.get("head_scale_trim", 1.0))
        new_move = Matrix.Translation(Vector(dst_mid)) @ Matrix([list(row) for row in turn]).to_4x4() @ Matrix.Scale(size, 4) @ Matrix.Translation(-Vector(src_mid))
        turned_move = new_move.copy()
        if CFG.get("upright"):
            anchor = Vector(dst_mid)
            new_move = Matrix.Translation(anchor) @ Matrix.Scale(size, 4) @ Matrix.Translation(-Vector(src_mid))
            # Keep the nose where the old nose is.
            new_move = Matrix.Translation(nose_old - (new_move @ nose_new)) @ new_move
        correction = new_move @ head_move.inverted()
        for obj in [head] + parts:
            obj.data.transform(correction, shape_keys=True)
            obj.data.update()
        head_move = new_move
        scale = size
        print("FEATURES size %.3f turn %s" % (size, [round(math.degrees(a), 1) for a in Matrix([list(row) for row in turn]).to_euler()]))
        feature_marks = old_marks
        print("FEATURES old marks", [[round(c, 3) for c in q] for q in old_marks])

# ---------------------------------------------------------------- her own face
# For a body whose face was sculpted and painted with care: the new face is
# drawn onto the old one's surface, so it keeps that face's own shape, and the
# old face's painted skin is carried across onto it. Eyes, lids, lips and the
# inside of the mouth stay the new head's, so they can move.
def ramp(low, high, value):
    t = max(0.0, min(1.0, (value - low) / (high - low)))
    return t * t * (3.0 - 2.0 * t)


own_face = None
if CFG.get("own_face"):
    twin = shell.copy()
    twin.data = shell.data.copy()
    twin.name = "OldFaceSkin"
    bpy.context.scene.collection.objects.link(twin)
    bm = bmesh.new()
    bm.from_mesh(twin.data)
    bm.verts.ensure_lookup_table()
    def of_the_face(f):
        if any(old_weights[v.index].get("Head", 0.0) + old_weights[v.index].get("neck", 0.0) <= 0.5 for v in f.verts):
            return False
        if any(is_hair(old_colour[v.index]) for v in f.verts):
            return False
        middle = twin.matrix_world @ f.calc_center_median()
        return middle.y < nose_old.y + 0.1 * scale and middle.z > nose_old.z - 0.1 * scale
    zone = [f for f in bm.faces if (twin.matrix_world @ f.calc_center_median()).y < nose_old.y + 0.1 * scale and abs((twin.matrix_world @ f.calc_center_median()).z - nose_old.z) < 0.1 * scale]
    print("OWN FACE zone faces", len(zone), "weight-fail", sum(1 for f in zone if any(old_weights[v.index].get("Head", 0.0) + old_weights[v.index].get("neck", 0.0) <= 0.5 for v in f.verts)),
          "hair-fail", sum(1 for f in zone if any(is_hair(old_colour[v.index]) for v in f.verts)), "verts", len(bm.verts), "weights", len(old_weights), "colours", len(old_colour))
    if os.environ.get("CAST_PROBE"):
        sys.exit(0)
    lose = [f for f in bm.faces if not of_the_face(f)]
    bmesh.ops.delete(bm, geom=lose, context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    bm.to_mesh(twin.data)
    bm.free()
    face_tree = BVHTree.FromPolygons([tuple(twin.matrix_world @ v.co) for v in twin.data.vertices], [tuple(q.vertices) for q in twin.data.polygons])
    eyes_now = [head_move @ eye_at[side] for side in ("L", "R")]
    mesh = head.data
    shifts = {}
    for vertex in mesh.vertices:
        co = vertex.co
        depth = co.y - nose_old.y
        if depth > 0.085 * scale or co.z < nose_old.z - 0.09 * scale or co.z > nose_old.z + 0.12 * scale:
            continue
        weight = 1.0 - ramp(0.05 * scale, 0.085 * scale, depth)
        weight *= ramp(0.022 * scale, 0.04 * scale, min((co - eye).length for eye in eyes_now))
        # The mouth's own line and inside are left alone.
        weight *= ramp(0.0, 0.006, vertex.normal.dot(Vector((0, -1, 0))) + 0.25)
        hit = face_tree.find_nearest(co, float(CFG.get("own_face_reach", 0.02)))
        if hit[0] is None or weight <= 0.0:
            continue
        # A hair's breadth proud of the old surface, so nothing old shows through.
        shifts[vertex.index] = (hit[0] + hit[1] * 0.0009 - co) * weight * float(CFG.get("own_face_shape", 1.0))
    # Even the pull out over neighbours, so the surface does not crumple.
    near = {v.index: set() for v in mesh.vertices}
    for edge in mesh.edges:
        a, b = edge.vertices
        near[a].add(b)
        near[b].add(a)
    for _ in range(4):
        evened = {}
        for index in shifts:
            total = shifts[index].copy()
            count = 1
            for other in near[index]:
                total += shifts.get(other, Vector())
                count += 1
            evened[index] = total / count
        shifts = evened
    blocks = mesh.shape_keys.key_blocks if mesh.shape_keys else None
    for index, shift in shifts.items():
        if blocks:
            for block in blocks:
                block.data[index].co = block.data[index].co + shift
        mesh.vertices[index].co = mesh.vertices[index].co + shift
    mesh.update()
    print("OWN FACE drew", len(shifts), "points onto the old face")
    # Carry the painted skin across: for every point of the new face's own
    # picture, find the place on the old face it now lies on and take the
    # colour painted there.
    bm = bmesh.new()
    bm.from_mesh(twin.data)
    bmesh.ops.triangulate(bm, faces=bm.faces)
    bm.to_mesh(twin.data)
    bm.free()
    old_corner = [[twin.matrix_world @ twin.data.vertices[v].co for v in q.vertices] for q in twin.data.polygons]
    old_uv = [[twin.data.uv_layers.active.data[l].uv.copy() for l in q.loop_indices] for q in twin.data.polygons]
    paint_tree = BVHTree.FromPolygons([tuple(twin.matrix_world @ v.co) for v in twin.data.vertices], [tuple(q.vertices) for q in twin.data.polygons])
    _, painting = base_image(shell)
    wide, high = painting.size
    paint = numpy.array(painting.pixels[:], dtype=numpy.float32).reshape(high, wide, 4)
    node, image = base_image(head)
    size = image.size[0]
    carried = numpy.zeros((size, size, 4), dtype=numpy.float32)
    new_uv = head.data.uv_layers.active.data
    eye_marks = feature_marks[1:3] if feature_marks is not None else []
    eye_radius = float(CFG.get("eye_paint_radius", 0.019))
    touched = set(shifts)
    if float(CFG.get("own_face_shape", 1.0)) < 0.99 or CFG.get("upright"):
        touched = {v.index for v in head.data.vertices if v.co.y < nose_old.y + 0.09 * scale and abs(v.co.z - nose_old.z) < 0.11 * scale}
    to_turned = (turned_move @ head_move.inverted()) if (CFG.get("upright") and turned_move is not None) else None
    mouth_mark = feature_marks[3] if (feature_marks is not None and CFG.get("own_face_skip_mouth")) else None
    mouth_radius = float(CFG.get("mouth_paint_radius", 0.024))
    filled = 0
    for polygon in head.data.polygons:
        if not any(v in touched for v in polygon.vertices):
            continue
        corners = [head.data.vertices[v].co for v in polygon.vertices]
        uvs = [new_uv[l].uv for l in polygon.loop_indices]
        for k in range(1, len(corners) - 1):
            tri = (corners[0], corners[k], corners[k + 1])
            tuv = (uvs[0], uvs[k], uvs[k + 1])
            xs = [u.x * (size - 1) for u in tuv]
            ys = [u.y * (size - 1) for u in tuv]
            area = (xs[1] - xs[0]) * (ys[2] - ys[0]) - (xs[2] - xs[0]) * (ys[1] - ys[0])
            if abs(area) < 1e-9:
                continue
            for py in range(max(int(min(ys)), 0), min(int(max(ys)) + 2, size)):
                for px in range(max(int(min(xs)), 0), min(int(max(xs)) + 2, size)):
                    w1 = ((px - xs[0]) * (ys[2] - ys[0]) - (xs[2] - xs[0]) * (py - ys[0])) / area
                    w2 = ((xs[1] - xs[0]) * (py - ys[0]) - (px - xs[0]) * (ys[1] - ys[0])) / area
                    w0 = 1.0 - w1 - w2
                    if w0 < -0.02 or w1 < -0.02 or w2 < -0.02:
                        continue
                    at = tri[0] * w0 + tri[1] * w1 + tri[2] * w2
                    if to_turned is not None:
                        at = to_turned @ at
                    if any((at - mark).length < eye_radius for mark in eye_marks):
                        continue
                    if mouth_mark is not None and (at - mouth_mark).length < mouth_radius:
                        continue
                    hit = paint_tree.find_nearest(at, float(CFG.get("own_face_paint_reach", 0.006)))
                    if hit[0] is None:
                        continue
                    a_, b_, c_ = old_corner[hit[2]]
                    v0 = b_ - a_
                    v1 = c_ - a_
                    v2 = hit[0] - a_
                    d00 = v0.dot(v0)
                    d01 = v0.dot(v1)
                    d11 = v1.dot(v1)
                    d20 = v2.dot(v0)
                    d21 = v2.dot(v1)
                    denom = d00 * d11 - d01 * d01
                    if abs(denom) < 1e-14:
                        continue
                    bv = (d11 * d20 - d01 * d21) / denom
                    bw = (d00 * d21 - d01 * d20) / denom
                    uv = old_uv[hit[2]][0] * (1.0 - bv - bw) + old_uv[hit[2]][1] * bv + old_uv[hit[2]][2] * bw
                    taken = paint[int((uv.y % 1.0) * (high - 1)), int((uv.x % 1.0) * (wide - 1)), :3]
                    if is_hair(taken, 0.08):
                        continue
                    carried[py, px, :3] = taken
                    carried[py, px, 3] = 1.0
                    filled += 1
    print("OWN FACE picture points carried", filled)
    own_face = bpy.data.images.new(CID + "_own_face", size, size, alpha=True)
    own_face.pixels = carried.ravel()
    own_face.filepath_raw = os.path.join(OUT, CID + "_own_face_bake.png")
    own_face.file_format = "PNG"
    own_face.save()
    bpy.data.objects.remove(twin)

depsgraph = bpy.context.evaluated_depsgraph_get()
tree = BVHTree.FromObject(head, depsgraph)
margin = float(CFG.get("skin_margin", 0.006))
keep_above = float(CFG.get("keep_above", 99.0))
neck_z = joint("neck").z
REBUILD = CFG.get("head", "rebuild") == "rebuild"
doomed = set()
# Loose locks are their own pieces of the old shell: find the pieces that are
# mostly hair, so they can go whole and the clothes under them stay whole.
hair_pieces = set()
body_piece = set()
if CFG.get("old_hair") == "remove":
    probe = bmesh.new()
    probe.from_mesh(shell.data)
    probe.verts.ensure_lookup_table()
    unseen = set(range(len(probe.verts)))
    pieces = []
    while unseen:
        first = unseen.pop()
        piece = [first]
        stack = [first]
        while stack:
            for edge in probe.verts[stack.pop()].link_edges:
                for other in edge.verts:
                    if other.index in unseen:
                        unseen.discard(other.index)
                        piece.append(other.index)
                        stack.append(other.index)
        pieces.append(piece)
    probe.free()
    pieces.sort(key=len, reverse=True)
    body_piece = set(pieces[0])
    for piece in pieces[1:]:
        hairy = sum(1 for i in piece if is_hair(old_colour[i], 0.09))
        if hairy > 0.45 * len(piece):
            hair_pieces.update(piece)
    print("HAIR pieces", len(pieces), "body", len(body_piece), "hair points in loose pieces", len(hair_pieces))
face_top = float(CFG.get("face_top", keep_above))
stub_floor = min(v.co.z for v in head.data.vertices) + 0.012
hand_axis = {}
for side in ("Left", "Right"):
    wrist_at = joint(side + "Hand")
    points = [shell_world @ v.co for i, v in enumerate(shell.data.vertices) if old_weights[i].get(side + "Hand", 0.0) > 0.5]
    hand_axis[side] = (wrist_at, ((sum(points, Vector()) / len(points)) - wrist_at).normalized())
for index, vertex in enumerate(shell.data.vertices):
    w = old_weights[index]
    co = shell_world @ vertex.co
    for side in ("Left", "Right"):
        wrist_at, along = hand_axis[side]
        past_wrist = (co - wrist_at).dot(along)
        if (co - wrist_at).length < 0.24 and w.get(side + "Hand", 0.0) + w.get(side + "ForeArm", 0.0) > 0.5:
            # Everything past the wrist is the old mitten; skin above it is old wrist.
            if past_wrist > float(CFG.get("wrist_cut", 0.0)) or (is_skin(old_colour[index], True) and past_wrist > -0.1):
                doomed.add(index)
    upper = w.get("Head", 0.0) + w.get("neck", 0.0)
    if own_face is not None and CFG.get("old_hair") == "remove":
        # A new style is being built: every lock of the old hair goes, wherever
        # it lies, and the whole old head with it.
        if index in hair_pieces or w.get("Head", 0.0) > 0.5:
            doomed.add(index)
        elif co.z > joint("Spine").z - 0.3 and is_hair(old_colour[index], 0.045 if index in body_piece else 0.09):
            doomed.add(index)
        continue
    if own_face is not None and not REBUILD:
        if is_hair(old_colour[index]):
            continue
        if w.get("Head", 0.0) > 0.5 and co.y < nose_old.y + 0.1 * scale and co.z > nose_old.z - 0.1 * scale:
            doomed.add(index)
        continue
    if REBUILD:
        # The whole old head goes: face, hair, hat and all. A new one is built.
        # The old neck and collar stay; the new neck comes down over them.
        if w.get("Head", 0.0) > 0.4 or (upper > 0.5 and co.z > nose_old.z - 0.082 * scale and is_skin(old_colour[index], True)):
            doomed.add(index)
        continue
    if co.z > stub_floor and (upper > 0.3 or (upper + w.get("Spine", 0.0) > 0.3 and abs(co.x) < 0.13)):
        if is_skin(old_colour[index], upper > 0.5 and co.z < nose_old.z - 0.03):
            doomed.add(index)
        elif w.get("Head", 0.0) > 0.5 and co.z < face_top and co.y < nose_old.y + 0.13 * scale:
            # The old face itself, painted eyes, brows and lips included:
            # whatever lies on the new face or just off it.
            hit = tree.find_nearest(co)
            if hit[0] is not None and (co - hit[0]).dot(hit[1]) < float(CFG.get("face_margin", 0.012)):
                doomed.add(index)
bm = bmesh.new()
bm.from_mesh(shell.data)
bm.verts.ensure_lookup_table()
if REBUILD or own_face is not None:
    # Only faces wholly in the cut go, so a collar's own edge is never nibbled.
    # (With her own face kept, a face mostly in the cut goes: chips of old skin
    # along the hairline are worse than a hair's edge trimmed.)
    gone = [f for f in bm.faces if all(v.index in doomed for v in f.verts)]
    if own_face is not None and not REBUILD:
        # A face half in the cut goes too when what is painted on its middle is skin.
        uv_layer = bm.loops.layers.uv.active
        taken = set(gone)
        for f in bm.faces:
            if f in taken or sum(1 for v in f.verts if v.index in doomed) < 1:
                continue
            u = sum((loop[uv_layer].uv for loop in f.loops), Vector((0.0, 0.0))) / len(f.loops)
            middle = paint[int((u.y % 1.0) * (high - 1)), int((u.x % 1.0) * (wide - 1)), :3]
            if (is_hair(middle, 0.05) if CFG.get("old_hair") == "remove" else not is_hair(middle)):
                gone.append(f)
    if CFG.get("old_hair") == "remove":
        # Below the chin, a face any corner of which was hair goes: no flaps.
        taken = set(gone)
        gone += [f for f in bm.faces if f not in taken and any(v.index in doomed for v in f.verts)
                 and (shell_world @ f.calc_center_median()).z < nose_old.z - 0.09]
    bmesh.ops.delete(bm, geom=gone, context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
else:
    bmesh.ops.delete(bm, geom=[bm.verts[i] for i in doomed], context="VERTS")
# Crumbs: small loose pieces left where the old face met the new one.
bm.verts.ensure_lookup_table()
deform = bm.verts.layers.deform.verify()
head_index = shell.vertex_groups["Head"].index
seen = set()
crumbs = []
for start in bm.verts:
    if start.index in seen:
        continue
    island = []
    stack = [start]
    seen.add(start.index)
    while stack:
        vert = stack.pop()
        island.append(vert)
        for edge in vert.link_edges:
            other = edge.other_vert(vert)
            if other.index not in seen:
                seen.add(other.index)
                stack.append(other)
    if len(island) < int(CFG.get("crumb_size", 160)) and sum(v[deform].get(head_index, 0.0) for v in island) / len(island) > 0.3:
        crumbs.extend(island)
bmesh.ops.delete(bm, geom=crumbs, context="VERTS")
if CFG.get("old_hair") == "remove":
    bm.verts.ensure_lookup_table()
    seen_ = set()
    scraps = []
    for start_ in bm.verts:
        if start_.index in seen_:
            continue
        island_ = [start_]
        stack_ = [start_]
        seen_.add(start_.index)
        while stack_:
            for edge in stack_.pop().link_edges:
                for other in edge.verts:
                    if other.index not in seen_:
                        seen_.add(other.index)
                        island_.append(other)
                        stack_.append(other)
        if len(island_) < int(CFG.get("scrap_size", 500)):
            scraps.extend(island_)
    bmesh.ops.delete(bm, geom=scraps, context="VERTS")
    uv_layer = bm.loops.layers.uv.active
    before_faces = set(bm.faces)
    rim = [e for e in bm.edges if e.is_boundary and all((shell_world @ v.co).z < nose_old.z - 0.1 for v in e.verts)]
    if CFG.get("mend"):
        bmesh.ops.holes_fill(bm, edges=rim, sides=int(CFG.get("mend_sides", 0)))
    mended = [f for f in bm.faces if f not in before_faces]
    # Mended faces take one plain point of the blouse's own cloth.
    deform_ = bm.verts.layers.deform.verify()
    spine_index = shell.vertex_groups["Spine"].index
    spine_at = joint("Spine")
    cloth = [v for v in bm.verts if v[deform_].get(spine_index, 0.0) > 0.4 and spine_at.z - 0.2 < (shell_world @ v.co).z < spine_at.z - 0.08
             and (shell_world @ v.co).y < spine_at.y and v.link_loops]
    cloth_uv = None
    if cloth:
        tones = numpy.array([paint[int((v.link_loops[0][uv_layer].uv.y % 1.0) * (high - 1)), int((v.link_loops[0][uv_layer].uv.x % 1.0) * (wide - 1)), :3] for v in cloth])
        middle_tone = numpy.median(tones, axis=0)
        pick = int(numpy.abs(tones - middle_tone).sum(axis=1).argmin())
        cloth_uv = cloth[pick].link_loops[0][uv_layer].uv.copy()
    for f in mended:
        for loop in f.loops:
            if cloth_uv is not None:
                loop[uv_layer].uv = cloth_uv
        f.smooth = True
    print("MENDED", len(mended), "faces; scraps", len(scraps))
bm.to_mesh(shell.data)
bm.free()
print("CUT", len(doomed), "old skin points and", len(crumbs), "crumbs; shell now", len(shell.data.vertices))

# Where the new skin would show through what was kept (a hat, hair, a collar),
# tuck it just under the old surface.
depsgraph = bpy.context.evaluated_depsgraph_get()
old_colour_welded = vertex_colours(shell)
kept = BVHTree.FromPolygons([tuple(shell.matrix_world @ v.co) for v in shell.data.vertices], [tuple(p.vertices) for p in shell.data.polygons])
chin_z = nose_old.z - 0.075 * scale
# A rebuilt head's neck is drawn out to just cover the old neck's skin, and
# its lowest edge is drawn in under it, so the join is where one neck meets
# the other, in matched skin, and not a cut edge.
if REBUILD or own_face is not None:
    neck_floor = min(v.co.z for v in head.data.vertices)
    polygons = shell.data.polygons
    blocks = head.data.shape_keys.key_blocks if head.data.shape_keys else None
    covered_neck = 0
    for vertex in head.data.vertices:
        co = vertex.co.copy()
        if co.z > chin_z - 0.012:
            continue
        hit = kept.find_nearest(co, 0.04)
        if hit[0] is None:
            continue
        on_skin = is_skin(old_colour_welded[polygons[hit[2]].vertices[0]], True)
        signed = (co - hit[0]).dot(hit[1])
        want = None
        if co.z < neck_floor + 0.014:
            if signed > -0.004:
                want = hit[0] - hit[1] * 0.006
        elif on_skin and signed < 0.0035:
            want = hit[0] + hit[1] * 0.0035
        if want is None:
            continue
        shift = want - co
        covered_neck += 1
        if blocks:
            for block in blocks:
                block.data[vertex.index].co = block.data[vertex.index].co + shift
        vertex.co = co + shift
    head.data.update()
    print("NECK", covered_neck)

tucked = 0
dropped = 0
skull_centre = nose_old + Vector((0.0, 0.1 * scale, 0.035 * scale))
for piece in ([] if (REBUILD or CFG.get("old_hair") == "remove") else [head]):
    blocks = piece.data.shape_keys.key_blocks if piece.data.shape_keys else None
    side = "Left" if piece is hands["L"] else "Right"
    drop = set()
    for vertex in piece.data.vertices:
        co = vertex.co.copy()
        if piece is not head:
            continue
        scalp = co.z >= keep_above or (co.y > nose_old.y + 0.085 * scale and co.z > chin_z + 0.02)
        if not scalp:
            continue
        if scalp:
            # Along the line from the middle of the head: the first kept
            # surface out there (the inside of a hat, the under-side of hair)
            # is as far as the scalp may reach.
            out = co - skull_centre
            reach = out.length
            hit = kept.ray_cast(skull_centre, out.normalized(), reach + 0.12)
            if hit[0] is not None and hit[3] < reach + 0.005:
                shift = skull_centre + out.normalized() * max(hit[3] - 0.007, 0.02) - co
                tucked += 1
                if blocks:
                    for block in blocks:
                        block.data[vertex.index].co = block.data[vertex.index].co + shift
                vertex.co = co + shift
            continue
        hit = kept.find_nearest(co, 0.05)
        if hit[0] is None:
            continue
        signed = (co - hit[0]).dot(hit[1])
        if signed > -0.004 and signed < 0.03:
            drop.add(vertex.index)
    if drop:
        dropped += len(drop)
        keep_only(piece, set(range(len(piece.data.vertices))) - drop)
    piece.data.update()
print("DROPPED", dropped)
print("TUCKED", tucked)

# The new skin takes the old skin's colour, and the eyes theirs.
node, image = base_image(head)
if image is not None:
    width, height = image.size
    pixels = numpy.array(image.pixels[:], dtype=numpy.float32).reshape(height, width, 4)
    new_colour = vertex_colours(head)
    face = [new_colour[v.index] for v in head.data.vertices if (v.co - nose_old).length < 0.03]
    new_ref = numpy.median(numpy.array(face), axis=0)
    ratio = numpy.clip(skin_ref / numpy.maximum(new_ref, 0.01), 0.55, 1.35) * float(CFG.get("skin_gain", 1.0))
    pixels[:, :, :3] = numpy.clip(pixels[:, :, :3] * ratio, 0.0, 1.0)
    if own_face is not None and hair_ref is not None:
        uv_new = head.data.uv_layers.active.data
        scalp_colour = numpy.clip(hair_ref * float(CFG.get("scalp_shade", 0.8)), 0, 1)
        for polygon in head.data.polygons:
            cos = [head.data.vertices[v].co for v in polygon.vertices]
            if not all((c.z > nose_old.z + 0.085 * scale and c.y > nose_old.y + 0.02 * scale) or c.y > nose_old.y + 0.12 * scale for c in cos):
                continue
            if any(c.z < nose_old.z - 0.02 * scale for c in cos):
                continue
            us = [uv_new[l].uv for l in polygon.loop_indices]
            x0 = max(int(min(u.x for u in us) * (width - 1)) - 1, 0)
            x1 = min(int(max(u.x for u in us) * (width - 1)) + 2, width)
            y0 = max(int(min(u.y for u in us) * (height - 1)) - 1, 0)
            y1 = min(int(max(u.y for u in us) * (height - 1)) + 2, height)
            pixels[y0:y1, x0:x1, :3] = scalp_colour
    if own_face is not None:
        carried = numpy.array(own_face.pixels[:], dtype=numpy.float32).reshape(height, width, 4)
        cover = carried[:, :, 3].copy()
        # Feather the edge of what was carried across.
        for _ in range(int(CFG.get("own_face_feather", 10))):
            cover = (cover + numpy.roll(cover, 1, 0) + numpy.roll(cover, -1, 0) + numpy.roll(cover, 1, 1) + numpy.roll(cover, -1, 1)) / 5.0
        cover = numpy.minimum(cover, carried[:, :, 3])[:, :, None] * float(CFG.get("own_face_strength", 1.0))
        pixels[:, :, :3] = pixels[:, :, :3] * (1.0 - cover) + carried[:, :, :3] * cover
        print("OWN FACE carried %.1f%% of the skin picture" % (100.0 * float(cover.mean())))
    toned = bpy.data.images.new(CID + "_skin", width, height, alpha=True)
    toned.pixels = pixels.ravel()
    toned.filepath_raw = os.path.join(OUT, CID + "_skin.png")
    toned.file_format = "PNG"
    toned.save()
    node.image = toned
    print("TONE new", [round(float(c), 3) for c in new_ref], "ratio", [round(float(c), 2) for c in ratio])
eye_file = os.path.join(USER, "eyes", "materials", CFG.get("eyes", "brown") + "_eye.png")
eye_node, eye_image = base_image(parts[0])
print("EYES", eye_file, os.path.exists(eye_file), eye_node, eye_image.filepath if eye_image else None)
if eye_node is not None and os.path.exists(eye_file):
    eye_picture = bpy.data.images.load(eye_file)
    if "eye_tone" in CFG:
        ew, eh = eye_picture.size
        ep = numpy.array(eye_picture.pixels[:], dtype=numpy.float32).reshape(eh, ew, 4)
        grey = ep[:, :, :3].mean(axis=2, keepdims=True)
        keep = float(CFG["eye_tone"].get("colour", 1.0))
        ep[:, :, :3] = numpy.clip((grey + (ep[:, :, :3] - grey) * keep) * numpy.array(CFG["eye_tone"].get("tint", [1, 1, 1]), dtype=numpy.float32), 0, 1)
        toned_eye = bpy.data.images.new(CID + "_eye", ew, eh, alpha=True)
        toned_eye.pixels = ep.ravel()
        toned_eye.filepath_raw = os.path.join(OUT, CID + "_eye.png")
        toned_eye.file_format = "PNG"
        toned_eye.save()
        eye_picture = toned_eye
    eye_node.image = eye_picture

# ---------------------------------------------------------------- finger bones on the old skeleton
bpy.context.view_layer.objects.active = old_rig
bpy.ops.object.mode_set(mode="EDIT")
to_local = old_world.inverted()
finger_names = {}
for side, old_side in (("L", "Left"), ("R", "Right")):
    move = hand_move[side]
    for name, parent, head_at, tail_at, basis in finger_rest[side]:
        digit, joint_number = name.split(".")[0][6:].split("-")
        new_name = "%sHand%s%s" % (old_side, FINGERS[digit], joint_number)
        finger_names[name] = new_name
    for name, parent, head_at, tail_at, basis in finger_rest[side]:
        bone = old_rig.data.edit_bones.new(finger_names[name])
        bone.head = to_local @ (move @ head_at)
        bone.tail = to_local @ (move @ tail_at)
        z_axis = (to_local.to_3x3() @ move.to_3x3() @ basis).col[2]
        bone.align_roll(z_axis)
        bone.parent = old_rig.data.edit_bones[finger_names.get(parent, old_side + "Hand")]
        bone.use_connect = False
bpy.ops.object.mode_set(mode="OBJECT")

# ---------------------------------------------------------------- weights on the old skeleton's names
def reweigh(obj, mapper):
    rows = weights_by_name(obj)
    obj.vertex_groups.clear()
    for index, row in enumerate(rows):
        out = {}
        for name, weight in row.items():
            target = mapper(name)
            if target:
                out[target] = out.get(target, 0.0) + weight
        total = sum(out.values())
        if total <= 0.0:
            out = {mapper(None): 1.0}
            total = 1.0
        for target, weight in out.items():
            group = obj.vertex_groups.get(target) or obj.vertex_groups.new(name=target)
            group.add([index], weight / total, "REPLACE")
    for modifier in list(obj.modifiers):
        obj.modifiers.remove(modifier)
    obj.parent = old_rig
    obj.matrix_parent_inverse = old_world.inverted()
    modifier = obj.modifiers.new("Armature", "ARMATURE")
    modifier.object = old_rig


def head_map(name):
    if name is None or name in head_bones:
        return "Head"
    if name in neck_bones:
        return "neck"
    return "Spine" if name in bones else None


reweigh(head, head_map)
for part in parts:
    reweigh(part, lambda name: "Head")
for side, old_side in (("L", "Left"), ("R", "Right")):
    def hand_map(name, old_side=old_side):
        if name in finger_names:
            return finger_names[name]
        if name is not None and name.startswith("lowerarm"):
            return old_side + "ForeArm"
        return old_side + "Hand" if (name is None or name in bones) else None
    reweigh(hands[side], hand_map)

# ---------------------------------------------------------------- hair, hat, spectacles
def plain(name, colour, rough, metal=0.0):
    material = bpy.data.materials.new(name)
    material.use_nodes = True
    shader = material.node_tree.nodes["Principled BSDF"]
    shader.inputs["Base Color"].default_value = (*colour, 1.0)
    shader.inputs["Roughness"].default_value = rough
    shader.inputs["Metallic"].default_value = metal
    return material


def to_head(obj):
    obj.vertex_groups.clear()
    obj.vertex_groups.new(name="Head").add(list(range(len(obj.data.vertices))), 1.0, "REPLACE")
    obj.parent = old_rig
    obj.matrix_parent_inverse = old_world.inverted()
    obj.modifiers.new("Armature", "ARMATURE").object = old_rig


extras = []
skull = [v.co.copy() for v in head.data.vertices]
top_z = max(p.z for p in skull)
brow_z = nose_old.z + float(CFG.get('brow_above_nose', 0.066)) * scale
band = [p for p in skull if p.z > brow_z]
centre = Vector(((max(p.x for p in band) + min(p.x for p in band)) / 2, (max(p.y for p in band) + min(p.y for p in band)) / 2, 0))
half_w = (max(p.x for p in band) - min(p.x for p in band)) / 2
half_d = (max(p.y for p in band) - min(p.y for p in band)) / 2
if hair is not None and CFG.get("hair_colour"):
    node, image = base_image(hair)
    if image is not None:
        width, height = image.size
        pixels = numpy.array(image.pixels[:], dtype=numpy.float32).reshape(height, width, 4)
        grey = pixels[:, :, :3].mean(axis=2, keepdims=True)
        solid = pixels[:, :, 3] > 0.5
        grey = grey / max(float(grey[solid].mean()) if solid.any() else 0.5, 0.05)
        pixels[:, :, :3] = numpy.clip(grey * numpy.array(CFG["hair_colour"], dtype=numpy.float32), 0, 1)
        dyed = bpy.data.images.new(CID + "_hair", width, height, alpha=True)
        dyed.pixels = pixels.ravel()
        dyed.filepath_raw = os.path.join(OUT, CID + "_hair.png")
        dyed.file_format = "PNG"
        dyed.save()
        node.image = dyed
if CFG.get("hat") == "cloche":
    lift = 0.012
    crown_top = top_z + lift
    crown_foot = brow_z + 0.034
    rows = []
    for k in range(13):
        t = k / 12.0
        angle = t * math.pi / 2
        rows.append((math.sin(angle) ** 0.8 * 1.085, crown_top - (1 - math.cos(angle)) ** 1.25 * (crown_top - crown_foot), t * 0.55))
    rows += [(1.1, brow_z + 0.022, 0.7), (1.16, brow_z + 0.012, 0.85), (1.25, brow_z + 0.0, 1.0), (1.32, brow_z - 0.013, 1.0), (1.33, brow_z - 0.018, 1.0),
             (1.3, brow_z - 0.016, 1.0), (1.22, brow_z - 0.003, 1.0), (1.1, brow_z + 0.012, 0.85), (1.05, brow_z + 0.03, 0.6)]
    bm = bmesh.new()
    rings = []
    steps = 56
    for r, z, low in rows:
        ring = []
        for k in range(steps):
            a = math.tau * k / steps
            # A cloche sits lower at the back than over the brow.
            dip = 0.024 * (1 + math.sin(a)) * 0.5 * low
            ring.append(bm.verts.new((centre.x + math.cos(a) * r * (half_w + 0.006), centre.y + math.sin(a) * r * (half_d + 0.006), z - dip)))
        rings.append(ring)
    band_rows = {12, 13}
    for index, (a, b) in enumerate(zip(rings, rings[1:])):
        for k in range(steps):
            face = bm.faces.new((a[k], a[(k + 1) % steps], b[(k + 1) % steps], b[k]))
            face.material_index = 1 if index in band_rows else 0
            face.smooth = True
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    mesh = bpy.data.meshes.new("Hat")
    bm.to_mesh(mesh)
    bm.free()
    hat = bpy.data.objects.new("Hat", mesh)
    bpy.context.scene.collection.objects.link(hat)
    felt = CFG.get("hat_colour", [0.16, 0.16, 0.17])
    hat.data.materials.append(plain(CID + "_felt", felt, 0.95))
    hat.data.materials.append(plain(CID + "_hat_band", [c * 0.35 for c in felt], 0.55))
    to_head(hat)
    extras.append(hat)
    if hair is not None:
        # Hair the hat covers is not there, nor a fringe across the face.
        covered = {v.index for v in hair.data.vertices if v.co.z > brow_z + 0.03 or v.co.y < nose_old.y + 0.05 * scale}
        keep_only(hair, set(range(len(hair.data.vertices))) - covered)
if CFG.get("hair_style") == "updo":
    # Hair dressed up off the neck: a soft full cap swept back from a centre
    # parting, waved, gathered into a low coil at the back of the head. Built
    # on the new head in its own untilted frame, then set where the head is.
    to_own = head_move.inverted()
    tone = hair_ref if hair_ref is not None else numpy.array(CFG.get("hair_colour", [0.5, 0.25, 0.1]), dtype=numpy.float32)
    strands = numpy.zeros((256, 512, 4), dtype=numpy.float32)
    rng = numpy.random.default_rng(7)
    streak = rng.random(512)
    for width_ in (3, 9, 27):
        streak = streak + numpy.convolve(rng.random(512), numpy.ones(width_) / width_, mode="same")
    streak = (streak - streak.min()) / (streak.max() - streak.min())
    shade = 0.7 + 0.5 * streak
    strands[:, :, :3] = numpy.clip(tone[None, None, :] * shade[None, :, None], 0, 1)
    strands[:, :, 3] = 1.0
    hair_picture = bpy.data.images.new(CID + "_updo", 512, 256, alpha=True)
    hair_picture.pixels = strands.ravel()
    hair_picture.filepath_raw = os.path.join(OUT, CID + "_updo.png")
    hair_picture.file_format = "PNG"
    hair_picture.save()
    hair_material = bpy.data.materials.new(CID + "_updo")
    hair_material.use_nodes = True
    hair_node = hair_material.node_tree.nodes.new("ShaderNodeTexImage")
    hair_node.image = hair_picture
    hair_shader = hair_material.node_tree.nodes["Principled BSDF"]
    hair_material.node_tree.links.new(hair_node.outputs[0], hair_shader.inputs["Base Color"])
    hair_shader.inputs["Roughness"].default_value = 0.55

    nose_own = to_own @ nose_old
    k = 1.0  # the base's own size; the head's scale comes back with head_move
    hairline = nose_own.z + float(CFG.get("hairline_above_nose", 0.086))
    ear_y = nose_own.y + 0.105
    nape = nose_own.z - 0.055

    def under_hair(q):
        # q in the head's own frame. Front: above the hairline, which dips at
        # the temples; behind the ears: down to the nape.
        if q.y < ear_y - 0.02:
            temple = max(0.0, abs(q.x) - 0.035) * 0.55
            return q.z > hairline - temple + max(0.0, (ear_y - 0.02 - q.y) - 0.1) * 0.0
        if q.y < ear_y + 0.02:
            return q.z > nose_own.z - 0.012 - max(0.0, (ear_y - 0.02) - q.y) * 2.5 if q.y > ear_y - 0.045 else q.z > hairline
        return q.z > nape

    bm = bmesh.new()
    bm.from_mesh(head.data)
    bm.verts.ensure_lookup_table()
    own = {v.index: to_own @ v.co for v in bm.verts}
    keep_faces = [f for f in bm.faces if all(under_hair(own[v.index]) for v in f.verts)]
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if f not in set(keep_faces)], context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    # Even out the cap's edge, so a hairline is a line and not a saw.
    for _ in range(int(CFG.get("hairline_smoothing", 8))):
        moved = {}
        for v in bm.verts:
            rim = [e.other_vert(v) for e in v.link_edges if e.is_boundary]
            if len(rim) == 2:
                moved[v] = (v.co * 2.0 + rim[0].co + rim[1].co) / 4.0
        for v, where in moved.items():
            v.co = where
    bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=1, use_grid_fill=True)
    bm.verts.ensure_lookup_table()
    bm.normal_update()
    # How far each point is from the cap's edge, along the surface.
    import heapq
    far = {v: 1e9 for v in bm.verts}
    queue = []
    for edge in bm.edges:
        if edge.is_boundary:
            for v in edge.verts:
                if far[v] > 0.0:
                    far[v] = 0.0
                    heapq.heappush(queue, (0.0, v.index))
    while queue:
        dist, index = heapq.heappop(queue)
        v = bm.verts[index]
        if dist > far[v]:
            continue
        for edge in v.link_edges:
            other = edge.other_vert(v)
            step = dist + edge.calc_length()
            if step < far[other]:
                far[other] = step
                heapq.heappush(queue, (step, other.index))
    uv_layer = bm.loops.layers.uv.verify()
    skull_mid = Vector((0.0, nose_own.y + 0.1, nose_own.z + 0.055))
    placed = {}
    for v in bm.verts:
        q = to_own @ v.co
        out = (q - skull_mid)
        height = math.atan2(out.z, math.hypot(out.x, out.y))
        around = math.atan2(out.y, abs(out.x) + 1e-6)
        # Finger waves running back from the face, deeper at the sides.
        wave = math.sin(around * 6.5 + height * 2.6) * 0.5 + 0.5
        side = min(1.0, abs(q.x) / 0.05)
        thick = 0.012 + 0.012 * side + 0.0085 * wave * (0.35 + 0.65 * side)
        thick -= 0.004 * math.exp(-(q.x / 0.006) ** 2)  # the parting
        thick += 0.008 * max(0.0, min(1.0, (q.y - ear_y) / 0.05)) * max(0.0, 1.0 - abs(height))  # fuller toward the back
        if q.z < nose_own.z + 0.02 and q.y > ear_y + 0.03:
            thick *= 0.6  # drawn in at the nape, under the curls
        thick *= ramp(0.0, 0.014, far[v]) * float(CFG.get("hair_fullness", 1.0))
        thick += 0.0012
        normal_own = (to_own.to_3x3() @ v.normal).normalized()
        q2 = q + normal_own * (thick / scale)
        placed[v] = (head_move @ q2, height, around, q.x)
    for v, (where, height, around, side_x) in placed.items():
        v.co = where
    for f in bm.faces:
        f.smooth = True
        for loop in f.loops:
            where, height, around, side_x = placed[loop.vert]
            loop[uv_layer].uv = (0.5 + (0.08 + height * 0.42) * (1.0 if side_x >= 0 else -1.0), around * 0.3 + 0.5)
    mesh = bpy.data.meshes.new("HairUpdo")
    bm.to_mesh(mesh)
    bm.free()
    updo = bpy.data.objects.new("HairUpdo", mesh)
    bpy.context.scene.collection.objects.link(updo)
    updo.data.materials.append(hair_material)
    to_head(updo)
    extras.append(updo)

    # The mass of curls at the nape: several rolled curls, low and full.
    curl_mid = Vector((0.0, nose_own.y + float(CFG.get("coil_back", 0.185)), nose_own.z + float(CFG.get("coil_height", -0.03))))
    curl_rows = [(-0.04, 0.0, 0.03, 0.034), (0.04, 0.0, 0.03, 0.034), (0.0, 0.022, 0.036, 0.036), (-0.06, -0.022, 0.0, 0.032), (0.06, -0.022, 0.0, 0.032),
                 (-0.026, 0.026, -0.004, 0.036), (0.026, 0.026, -0.004, 0.036), (-0.045, -0.004, -0.034, 0.03), (0.045, -0.004, -0.034, 0.03), (0.0, 0.018, -0.04, 0.032)]
    bm = bmesh.new()
    uv_layer = bm.loops.layers.uv.verify()
    for number, (cx, cy, cz, radius) in enumerate(curl_rows):
        made = bmesh.ops.create_uvsphere(bm, u_segments=20, v_segments=12, radius=1.0)
        middle = curl_mid + Vector((cx, cy, cz))
        spin = 1.0 if number % 2 == 0 else -1.0
        for v in made["verts"]:
            unit = v.co.normalized()
            turn_ = math.atan2(unit.z, unit.x)
            ring = math.acos(max(-1.0, min(1.0, unit.y)))
            ridge = math.sin(spin * turn_ + ring * 7.0) * 0.09 * math.sin(ring) ** 0.5
            v.co = head_move @ (middle + Vector((unit.x, unit.y * 0.8, unit.z)) * radius * (1.0 + ridge))
            for loop in v.link_loops:
                loop[uv_layer].uv = (0.5 + (ring / math.pi - 0.5) * 0.8, turn_ / math.tau + 0.5)
    for f in bm.faces:
        f.smooth = True
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    mesh = bpy.data.meshes.new("HairCurls")
    bm.to_mesh(mesh)
    bm.free()
    coil = bpy.data.objects.new("HairCurls", mesh)
    bpy.context.scene.collection.objects.link(coil)
    coil.data.materials.append(hair_material)
    to_head(coil)
    extras.append(coil)
    # Modelled strands: thousands of fine ribbons laid over the shape, each
    # running back from its root to where the hair is gathered, following the
    # waves, so the hair has strands at its edges and across its surface and
    # is not a painted shell.
    cap_tree = BVHTree.FromPolygons([tuple(v.co) for v in updo.data.vertices], [tuple(q.vertices) for q in updo.data.polygons])
    rng = numpy.random.default_rng(11)
    skull_world = head_move @ skull_mid
    gather_own = curl_mid + Vector((0.0, -0.035, 0.03))
    roots = [to_own @ v.co for v in updo.data.vertices]
    count = int(CFG.get("strand_count", 3600))
    width = float(CFG.get("strand_width", 0.0016))
    steps_ = 14
    bm = bmesh.new()
    uv_layer = bm.loops.layers.uv.verify()
    laid = 0
    for number in range(count):
        root = roots[int(rng.integers(len(roots)))] + Vector(tuple(rng.normal(0, 0.003, 3)))
        end_ = gather_own + Vector((float(rng.normal(0, 0.03)), float(rng.normal(0, 0.008)), float(rng.normal(0, 0.02))))
        d0 = (root - skull_mid).normalized()
        d1 = (end_ - skull_mid).normalized()
        if d0.angle(d1) < 0.25:
            continue
        lift = 0.0006 + abs(float(rng.normal(0, 0.0012)))
        phase = float(rng.uniform(0, math.tau))
        sway = float(rng.uniform(0.001, 0.0035))
        column = float(rng.random())
        points = []
        for step in range(steps_):
            t = step / (steps_ - 1.0)
            d = d0.slerp(d1, t * float(rng.uniform(0.82, 0.97)) if step == steps_ - 1 else t * 0.9)
            hit = cap_tree.ray_cast(skull_world, (head_move.to_3x3() @ d).normalized(), 0.4)
            if hit[0] is None:
                points = []
                break
            side_dir = d.cross(d1 - d0).normalized() if (d1 - d0).length > 1e-6 else Vector((1, 0, 0))
            outward = (hit[0] - skull_world).normalized()
            wobble = math.sin(t * 9.0 + phase) * sway
            points.append((hit[0] + outward * lift * scale + (head_move.to_3x3() @ side_dir).normalized() * wobble * scale, outward))
        if len(points) < steps_:
            continue
        ring = []
        for index, (where, outward) in enumerate(points):
            ahead = points[min(index + 1, steps_ - 1)][0] - points[max(index - 1, 0)][0]
            across = ahead.cross(outward)
            if across.length < 1e-9:
                across = Vector((1, 0, 0))
            across = across.normalized() * (width * scale * 0.5 * (0.35 if index in (0, steps_ - 1) else 1.0))
            ring.append((bm.verts.new(where - across), bm.verts.new(where + across)))
        for index in range(steps_ - 1):
            face = bm.faces.new((ring[index][0], ring[index][1], ring[index + 1][1], ring[index + 1][0]))
            face.smooth = True
            vs = (index / (steps_ - 1.0), (index + 1) / (steps_ - 1.0))
            for loop, (du, v_) in zip(face.loops, ((0.0, vs[0]), (0.004, vs[0]), (0.004, vs[1]), (0.0, vs[1]))):
                loop[uv_layer].uv = (column * 0.99 + du, v_)
        laid += 1
    # And round each curl.
    for number, (cx, cy, cz, radius) in enumerate(curl_rows):
        middle = curl_mid + Vector((cx, cy, cz))
        spin = 1.0 if number % 2 == 0 else -1.0
        for strand in range(int(CFG.get("curl_strands", 70))):
            start_turn = float(rng.uniform(0, math.tau))
            start_ring = float(rng.uniform(0.25, 0.8))
            column = float(rng.random())
            ring = []
            for index in range(16):
                t = index / 15.0
                turn_ = start_turn + spin * t * 4.2
                ring_ = (start_ring + t * 0.9) * math.pi * 0.62
                unit = Vector((math.sin(ring_) * math.cos(turn_), math.cos(ring_) * 0.8, math.sin(ring_) * math.sin(turn_)))
                where = head_move @ (middle + unit * radius * 1.035)
                outward = (head_move.to_3x3() @ unit).normalized()
                ring.append((where, outward))
            made = []
            for index, (where, outward) in enumerate(ring):
                ahead = ring[min(index + 1, 15)][0] - ring[max(index - 1, 0)][0]
                across = ahead.cross(outward)
                across = (across.normalized() if across.length > 1e-9 else Vector((1, 0, 0))) * (width * scale * 0.5)
                made.append((bm.verts.new(where - across), bm.verts.new(where + across)))
            for index in range(15):
                face = bm.faces.new((made[index][0], made[index][1], made[index + 1][1], made[index + 1][0]))
                face.smooth = True
                for loop, (du, v_) in zip(face.loops, ((0.0, index / 15.0), (0.004, index / 15.0), (0.004, (index + 1) / 15.0), (0.0, (index + 1) / 15.0))):
                    loop[uv_layer].uv = (column * 0.99 + du, v_)
    mesh = bpy.data.meshes.new("HairStrands")
    bm.to_mesh(mesh)
    bm.free()
    strands_object = bpy.data.objects.new("HairStrands", mesh)
    bpy.context.scene.collection.objects.link(strands_object)
    strand_material = hair_material.copy()
    strand_material.name = CID + "_strands"
    strand_material.use_backface_culling = False
    strands_object.data.materials.append(strand_material)
    to_head(strands_object)
    extras.append(strands_object)
    print("STRANDS laid", laid, "faces", len(mesh.polygons))

    # The clip.
    bm = bmesh.new()
    made = bmesh.ops.create_cube(bm, size=1.0)
    clip_at = Vector((float(CFG.get("clip_side", 0.052)), nose_own.y + 0.168, nose_own.z + 0.07))
    clip_turn = Matrix.Rotation(math.radians(35), 4, "X") @ Matrix.Rotation(math.radians(-38), 4, "Z")
    for v in made["verts"]:
        v.co = head_move @ (clip_at + (clip_turn @ Vector((v.co.x * 0.008, v.co.y * 0.05, v.co.z * 0.012))) + Vector((0.016, 0.0, 0.0)))
    mesh = bpy.data.meshes.new("HairClip")
    bm.to_mesh(mesh)
    bm.free()
    clip = bpy.data.objects.new("HairClip", mesh)
    bpy.context.scene.collection.objects.link(clip)
    clip.data.materials.append(plain(CID + "_clip", [0.5, 0.36, 0.14], 0.3, 1.0))
    to_head(clip)
    extras.append(clip)

if CFG.get("spectacles"):
    bm = bmesh.new()

    def tube(a, b, radius=0.0011):
        a = Vector(a)
        b = Vector(b)
        axis = (b - a)
        made = bmesh.ops.create_cone(bm, cap_ends=True, segments=8, radius1=radius, radius2=radius, depth=axis.length)
        turn = Vector((0, 0, 1)).rotation_difference(axis.normalized()).to_matrix().to_4x4()
        bmesh.ops.transform(bm, matrix=Matrix.Translation((a + b) / 2) @ turn, verts=made["verts"])

    lens_r = 0.021 * scale
    eyes_now = {side: head_move @ eye_at[side] for side in ("L", "R")}
    front_y = min(e.y for e in eyes_now.values()) - 0.026 * scale
    centres = {}
    for side in ("L", "R"):
        c = Vector((eyes_now[side].x * 1.06 - nose_old.x * 0.06, front_y, eyes_now[side].z - 0.002))
        centres[side] = c
        ring = [c + Vector((math.cos(math.tau * k / 24) * lens_r, 0, math.sin(math.tau * k / 24) * lens_r)) for k in range(24)]
        for k in range(24):
            tube(ring[k], ring[(k + 1) % 24])
    inner = sorted(centres.values(), key=lambda c: c.x)
    tube(inner[0] + Vector((lens_r, 0, 0.004)), inner[1] + Vector((-lens_r, 0, 0.004)))
    for c in centres.values():
        out = 1 if c.x > nose_old.x else -1
        hinge = c + Vector((out * lens_r, 0, 0.004))
        tube(hinge, hinge + Vector((out * 0.012 * scale, 0.03 * scale, 0)))
        tube(hinge + Vector((out * 0.012 * scale, 0.03 * scale, 0)), hinge + Vector((out * 0.014 * scale, 0.115 * scale, -0.004)))
    mesh = bpy.data.meshes.new("Spectacles")
    bm.to_mesh(mesh)
    bm.free()
    glasses = bpy.data.objects.new("Spectacles", mesh)
    bpy.context.scene.collection.objects.link(glasses)
    glasses.data.materials.append(plain(CID + "_wire", [0.55, 0.45, 0.2], 0.35, 1.0))
    to_head(glasses)
    extras.append(glasses)

for common, own in RENAMED.items():
    old_rig.data.bones[common].name = own
    for obj in bpy.data.objects:
        if obj.type == "MESH" and obj.vertex_groups.get(common) is not None:
            obj.vertex_groups[common].name = own

for leftover in [human, rig]:
    bpy.data.objects.remove(leftover)
# ---------------------------------------------------------------- long loose curls as simulated strands
# An attempt at her original hair with TressFX for Godot: guide strands are
# authored here as Blender hair curves (a centre parting, hair lying over the
# skull to the sides and back, then falling in ringlets), and written with
# that addon's own exporter, with closed colliders for the head and the body.
STRANDS = CFG.get("strands")
if STRANDS:
    import importlib.util
    STYLES = {
        "ringlets": {"points": 32, "lying": 10, "length": [0.27, 0.36], "radius": [0.011, 0.016], "turns": [3.8, 5.2], "first_angle": 52.0, "per_side": 20,
                     "guides": 1500, "follow": 5, "follow_radius": 0.006, "local_stiffness": 0.97, "global_stiffness": 0.5, "global_range": 0.34},
        "bob": {"points": 16, "lying": 7, "length": [0.075, 0.105], "radius": [0.003, 0.005], "turns": [0.45, 0.7], "first_angle": 48.0, "per_side": 16,
                "guides": 1400, "follow": 4, "follow_radius": 0.005, "local_stiffness": 0.98, "global_stiffness": 0.7, "global_range": 0.5},
        "short": {"points": 8, "lying": 8, "length": [0.05, 0.085], "radius": [0.0, 0.0], "turns": [0.0, 0.0], "first_angle": 30.0, "per_side": 14,
                  "guides": 2200, "follow": 4, "follow_radius": 0.004, "local_stiffness": 0.99, "global_stiffness": 0.92, "global_range": 0.9},
    }
    STYLE = dict(STYLES[STRANDS.get("style", "ringlets")])
    STYLE.update({k: v for k, v in STRANDS.items() if k != "style"})
    exporter_path = CFG.get("tressfx_exporter", "C:/ov/tools/tressfx_godot/addons/tressfx/tools/tressfx_blender_export.py")
    spec = importlib.util.spec_from_file_location("tressfx_blender_export", exporter_path)
    tfx = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(tfx)
    own_name = lambda common: RENAMED.get(common, common)
    to_own = head_move.inverted()
    nose_own = to_own @ nose_old
    hairline = nose_own.z + float(CFG.get("hairline_above_nose", 0.086))
    mid_y = nose_own.y + 0.1
    skull_mid = Vector((0.0, mid_y, nose_own.z + 0.055))
    skull_world = head_move @ skull_mid
    head_tree = BVHTree.FromPolygons([tuple(v.co) for v in head.data.vertices], [tuple(q.vertices) for q in head.data.polygons])
    body_tree = BVHTree.FromPolygons([tuple(shell.matrix_world @ v.co) for v in shell.data.vertices], [tuple(q.vertices) for q in shell.data.polygons])

    def scalp(q):
        if q.y < mid_y - 0.015:
            return q.z > hairline - max(0.0, abs(q.x) - 0.035) * 0.55
        if q.y < mid_y + 0.02:
            return q.z > nose_own.z + 0.04
        return q.z > nose_own.z - 0.04

    root_pool = [to_own @ v.co for v in head.data.vertices if scalp(to_own @ v.co)]
    rng = numpy.random.default_rng(23)
    ringlets = []
    per_side = int(STYLE["per_side"])
    first_angle = float(STYLE["first_angle"])
    for side in (1.0, -1.0):
        for k in range(per_side):
            angle = math.radians(first_angle + (180.0 - first_angle) * (k + 0.5) / per_side)
            ringlets.append({"side": side, "angle": angle,
                             "drop": Vector((side * math.sin(angle) * 0.083, mid_y - math.cos(angle) * 0.09, nose_own.z + float(rng.uniform(-0.01, 0.02)))),
                             "length": float(rng.uniform(*STYLE["length"])), "phase": float(rng.uniform(0, math.tau)), "turns": float(rng.uniform(*STYLE["turns"])) * (1 if k % 2 else -1),
                             "radius": float(rng.uniform(*STYLE["radius"]))})
    points_per = int(STYLE["points"])
    lying = int(STYLE["lying"])
    guides = int(STYLE["guides"])
    short_cut = STRANDS.get("style") == "short"
    root_ceiling = nose_own.z + float(STRANDS["root_max_above_nose"]) if "root_max_above_nose" in STRANDS else None
    if root_ceiling is not None:
        root_pool = [q for q in root_pool if q.z < root_ceiling]
    rows = []
    for number in range(guides * 3):
        if len(rows) >= guides:
            break
        root = root_pool[int(rng.integers(len(root_pool)))]
        side = 1.0 if root.x >= 0 else -1.0
        angle = math.atan2(abs(root.x), -(root.y - mid_y))
        mine = min((r for r in ringlets if r["side"] == side), key=lambda r: abs(r["angle"] - angle) + float(rng.uniform(0, 0.25)))
        d0 = (root - skull_mid).normalized()
        d1 = (mine["drop"] - skull_mid).normalized()
        reach = 1.0
        if short_cut:
            d1 = (Vector((side * 0.02, mid_y + 0.09, nose_own.z - 0.03)) - skull_mid).normalized()
            reach = min(1.0, mine["length"] / max(d0.angle(d1) * 0.095, 0.001))
        own_offset = Vector((float(rng.normal(0, 0.0028)), float(rng.normal(0, 0.0028)), 0.0))
        strand = []
        ok = True
        for i in range(lying):
            t = i / (lying - 1.0)
            direction = (head_move.to_3x3() @ d0.slerp(d1, t * reach)).normalized()
            hit = head_tree.ray_cast(skull_world, direction, 0.4)
            if hit[0] is None:
                ok = False
                break
            strand.append(hit[0] + direction * ((0.003 + 0.007 * math.sin(t * math.pi * 0.9)) if short_cut else (0.004 + 0.012 * t)) * scale)
        if not ok:
            continue
        start = strand[-1]
        down = Vector((0, 0, -1))
        away = Vector((start.x - skull_world.x, start.y - skull_world.y, 0.0))
        away = away.normalized() if away.length > 1e-6 else Vector((side, 0, 0))
        for i in range(1, points_per - lying + 1):
            sdown = i / float(max(points_per - lying, 1))
            grow = min(1.0, sdown * 3.0)
            turn_ = mine["phase"] + sdown * mine["turns"] * math.tau
            across = away.cross(down).normalized()
            where = start + down * mine["length"] * sdown + away * (0.012 * sdown) \
                + (away * math.cos(turn_) + across * math.sin(turn_)) * mine["radius"] * grow + own_offset * grow
            # Keep the resting hair off the body: lift any point that would lie in it.
            for _ in range(3):
                near = body_tree.find_nearest(where, 0.08)
                if near[0] is None:
                    break
                gap = (where - near[0]).dot(near[1])
                if gap < 0.014:
                    where = near[0] + near[1] * 0.016
            strand.append(where)
        rows.append(strand)
    hair_curves = bpy.data.hair_curves.new(CID + "_hair")
    hair_curves.add_curves([points_per] * len(rows))
    flat = numpy.array([[c for c in point] for strand in rows for point in strand], dtype=numpy.float32)
    hair_curves.position_data.foreach_set("vector", flat.ravel())
    hair_object = bpy.data.objects.new(CID + "_hair", hair_curves)
    bpy.context.scene.collection.objects.link(hair_object)
    hair_curves.surface = head
    hair_curves.surface_uv_map = head.data.uv_layers.active.name

    def hull(name, points, bone, shrink):
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
        mesh = bpy.data.meshes.new(name)
        bm.to_mesh(mesh)
        bm.free()
        obj = bpy.data.objects.new(name, mesh)
        bpy.context.scene.collection.objects.link(obj)
        obj.vertex_groups.new(name=bone).add(list(range(len(mesh.vertices))), 1.0, "REPLACE")
        obj.parent = old_rig
        obj.matrix_parent_inverse = old_world.inverted()
        obj.modifiers.new("Armature", "ARMATURE").object = old_rig
        obj.hide_render = True
        return obj

    chin_floor = nose_old.z - 0.08 * scale
    head_points = [v.co.copy() for v in head.data.vertices if v.co.z > chin_floor][::3]
    spine_z = joint(own_name("Spine")).z
    arm_groups = [g.index for g in shell.vertex_groups if "arm" in g.name.lower() or "hand" in g.name.lower()]
    body_points = []
    for vertex in list(shell.data.vertices)[::4]:
        where = shell.matrix_world @ vertex.co
        if spine_z - 0.3 < where.z < spine_z + 0.09 and sum(g.weight for g in vertex.groups if g.group in arm_groups) < 0.35:
            body_points.append(where)
    head_collider = hull(CID + "_head_collider", head_points, own_name("Head"), 0.955)
    body_collider = hull(CID + "_body_collider", body_points, own_name("Spine"), 0.965)
    bpy.context.view_layer.update()
    for label, result in (("hair", tfx.export_hair(bpy.context, hair_object, os.path.join(OUT, CID + "_hair.tfx"), points_per, True)),
                          ("head collider", tfx.export_collider(bpy.context, head_collider, os.path.join(OUT, CID + "_head.tfxmesh"), True)),
                          ("body collider", tfx.export_collider(bpy.context, body_collider, os.path.join(OUT, CID + "_body.tfxmesh"), True))):
        print("TRESSFX", label, result)
    hair_object.hide_render = True
    tone = hair_ref if hair_ref is not None else numpy.array([0.4, 0.3, 0.2], dtype=numpy.float32)
    tone = numpy.array(STRANDS["colour"], dtype=numpy.float32) if "colour" in STRANDS else tone
    recipe = {"schema_version": 1, "hair": CID + "_hair.tfx", "bones": CID + "_hair.tfxbone",
              "colliders": [{"file": CID + "_head.tfxmesh", "bone": own_name("Head")}, {"file": CID + "_body.tfxmesh", "bone": own_name("Spine")}],
              "follow": int(STYLE["follow"]), "follow_radius": float(STYLE["follow_radius"]), "local_stiffness": float(STYLE["local_stiffness"]),
              "global_stiffness": float(STYLE["global_stiffness"]), "global_range": float(STYLE["global_range"]),
              "base_colour": [round(float(c), 4) for c in numpy.clip(tone * float(STRANDS.get("root_shade", 0.85)), 0, 1)],
              "tip_colour": [round(float(c), 4) for c in numpy.clip(tone * float(STRANDS.get("tip_shade", 1.1)), 0, 1)],
              "fibre_radius": float(STRANDS.get("fibre_radius", 0.0011))}
    json.dump(recipe, open(os.path.join(OUT, CID + "_hair.json"), "w", encoding="utf-8"), indent=1)

shell.name = "Clothes"
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, CID + ".blend"))

# ---------------------------------------------------------------- look at it
scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x = 760
scene.render.resolution_y = 760
scene.world = bpy.data.worlds.new("W")
scene.world.use_nodes = True
scene.world.node_tree.nodes["Background"].inputs[0].default_value = (0.22, 0.22, 0.24, 1)
scene.world.node_tree.nodes["Background"].inputs[1].default_value = 0.6
scene.view_settings.view_transform = "Standard"
cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
scene.collection.objects.link(cam)
scene.camera = cam
for loc, energy in [((1.4, -2.0, 2.3), 150), ((-1.8, -1.4, 1.5), 60), ((0.0, 2.0, 2.0), 60)]:
    light = bpy.data.objects.new("L", bpy.data.lights.new("L", "AREA"))
    light.data.energy = energy
    light.data.size = 1.5
    light.location = loc
    light.rotation_euler = (Vector((0, 0, 1.3)) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    scene.collection.objects.link(light)


def look(name, at, distance, lens, yaw=0.0, values=None):
    values = values or {}
    for obj in [head] + parts:
        if obj.data.shape_keys:
            for key in obj.data.shape_keys.key_blocks[1:]:
                key.value = values.get(key.name, 0.0)
    at = Vector(at)
    offset = Matrix.Rotation(math.radians(yaw), 3, "Z") @ Vector((0, -distance, 0))
    cam.location = at + offset
    cam.rotation_euler = (at - cam.location).to_track_quat("-Z", "Y").to_euler()
    cam.data.lens = lens
    scene.render.filepath = os.path.join(OUT, "%s_%s.png" % (CID, name))
    bpy.ops.render.render(write_still=True)
    print("SHOT", name)


face_at = nose_old + Vector((0, 0.06, 0.02))
try:
    look("face", face_at, 0.9, 85)
    look("face_side", face_at, 0.9, 85, yaw=55)
    look("face_speaking_smile", face_at, 0.9, 85, yaw=-20, values={"viseme_aa": 0.8, "mouthSmileLeft": 0.6, "mouthSmileRight": 0.5, "browInnerUp": 0.4})
    look("face_blink_concern", face_at, 0.9, 85, values={"eyeBlinkLeft": 1.0, "eyeBlinkRight": 1.0, "browDownLeft": 0.6, "browDownRight": 0.5, "mouthFrownLeft": 0.5, "mouthFrownRight": 0.5})
    look("body", (0, 0, 0.88), 4.6, 50)
    for hidden in [head] + parts + extras:
        hidden.hide_render = True
    look("chest_shell_only", nose_old + Vector((0, 0.08, -0.2)), 1.3, 60, yaw=25)
    for hidden in [head] + parts + extras:
        hidden.hide_render = False
    look("hand_left", joint(RENAMED.get("LeftHand", "LeftHand")) + Vector((0.02, 0, -0.06)), 0.7, 70, yaw=60)
    look("hand_right", joint(RENAMED.get("RightHand", "RightHand")) + Vector((-0.02, 0, -0.06)), 0.7, 70, yaw=-60)
except Exception:
    traceback.print_exc()

# ---------------------------------------------------------------- export
for obj in [head] + parts:
    if obj.data.shape_keys:
        for key in obj.data.shape_keys.key_blocks[1:]:
            key.value = 0.0
bpy.ops.object.select_all(action="DESELECT")
for obj in [old_rig, shell, head] + parts + extras + list(hands.values()):
    obj.select_set(True)
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, CID + ".glb"), use_selection=True, export_format="GLB",
                          export_morph=True, export_morph_normal=False, export_animations=False, export_yup=True)
print("EXPORTED", os.path.getsize(os.path.join(OUT, CID + ".glb")))
print("DONE")
