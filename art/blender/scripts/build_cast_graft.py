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
    if share >= 0.5 or (co.z > neck_base - CFG.get("neck_stub", 0.045) and abs(co.x) < 0.075 and abs(co.y) < 0.09):
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


depsgraph = bpy.context.evaluated_depsgraph_get()
tree = BVHTree.FromObject(head, depsgraph)
margin = float(CFG.get("skin_margin", 0.006))
keep_above = float(CFG.get("keep_above", 99.0))
neck_z = joint("neck").z
REBUILD = CFG.get("head", "rebuild") == "rebuild"
doomed = set()
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
    if REBUILD and (w.get("Head", 0.0) > 0.4 or (upper > 0.5 and co.z > nose_old.z - 0.075 * scale)):
        # The whole old head goes: face, hair, hat and all. A new one is built.
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
bm.to_mesh(shell.data)
bm.free()
print("CUT", len(doomed), "old skin points and", len(crumbs), "crumbs; shell now", len(shell.data.vertices))

# Where the new skin would show through what was kept (a hat, hair, a collar),
# tuck it just under the old surface.
depsgraph = bpy.context.evaluated_depsgraph_get()
kept = BVHTree.FromPolygons([tuple(shell.matrix_world @ v.co) for v in shell.data.vertices], [tuple(p.vertices) for p in shell.data.polygons])
chin_z = nose_old.z - 0.075 * scale
tucked = 0
dropped = 0
skull_centre = nose_old + Vector((0.0, 0.1 * scale, 0.035 * scale))
for piece in ([] if REBUILD else [head]):
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
    eye_node.image = bpy.data.images.load(eye_file)

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
    rows = [(0.0, top_z + lift + 0.004), (0.45, top_z + lift + 0.002), (0.8, top_z + lift - 0.014), (1.0, top_z + lift - 0.045),
            (1.07, top_z - 0.08), (1.09, brow_z + 0.046), (1.11, brow_z + 0.03), (1.2, brow_z + 0.016), (1.3, brow_z + 0.0), (1.34, brow_z - 0.012), (1.32, brow_z - 0.016),
            (1.06, brow_z + 0.02), (1.05, brow_z + 0.04)]
    bm = bmesh.new()
    rings = []
    steps = 40
    for r, z in rows:
        ring = []
        for k in range(steps):
            a = math.tau * k / steps
            # A cloche sits lower at the back than over the brow.
            dip = 0.022 * (1 + math.sin(a)) if r > 1.0 else 0.0
            ring.append(bm.verts.new((centre.x + math.cos(a) * r * (half_w + 0.006), centre.y + math.sin(a) * r * (half_d + 0.006), z - dip)))
        rings.append(ring)
    for a, b in zip(rings, rings[1:]):
        for k in range(steps):
            bm.faces.new((a[k], a[(k + 1) % steps], b[(k + 1) % steps], b[k]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    mesh = bpy.data.meshes.new("Hat")
    bm.to_mesh(mesh)
    bm.free()
    for poly in mesh.polygons:
        poly.use_smooth = True
    hat = bpy.data.objects.new("Hat", mesh)
    bpy.context.scene.collection.objects.link(hat)
    hat.data.materials.append(plain(CID + "_felt", CFG.get("hat_colour", [0.16, 0.16, 0.17]), 0.92))
    to_head(hat)
    extras.append(hat)
    if hair is not None:
        # Hair the hat covers is not there.
        covered = {v.index for v in hair.data.vertices if v.co.z > brow_z + 0.03 or v.co.y < nose_old.y + 0.05 * scale}
        keep_only(hair, set(range(len(hair.data.vertices))) - covered)
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

for leftover in [human, rig]:
    bpy.data.objects.remove(leftover)
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
    look("hand_left", joint("LeftHand") + Vector((0.02, 0, -0.06)), 0.7, 70, yaw=60)
    look("hand_right", joint("RightHand") + Vector((-0.02, 0, -0.06)), 0.7, 70, yaw=-60)
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
