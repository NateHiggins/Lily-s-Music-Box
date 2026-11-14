"""Build a cast member whole: base body, face, hands, strand hair and a wardrobe.

blender -b --python build_cast_wardrobe.py -- <character id> <wardrobe json> <out dir>

Nothing of the old generated shells is used. The body is the MakeHuman base
(MPFB2, CC0 assets) on its Mixamo-named skeleton, the same for every cast
member. Clothes are separate pieces made here from the base's own clothing
helpers (a body-hugging shell and a skirt), cut to each garment's shape, set
off from the skin, and given the character's colours. The world is surreal and
the cast must read at a distance, so the palettes are bold.
"""
import bpy, bmesh, os, sys, glob, json, math, importlib, importlib.util, shutil, traceback, zlib
import numpy
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

ARGS = sys.argv[sys.argv.index("--") + 1:]
CID, CONFIG, OUT = ARGS[:3]
OUTFIT = ARGS[3] if len(ARGS) > 3 else ""
TABLE = json.load(open(CONFIG, encoding="utf-8"))
CFG = dict(TABLE[CID])
PARTS = {}
HATS = []
if OUTFIT == "parts":
    # Mix and match: each part (a top, a bottom, an outer layer, headwear,
    # footwear) is made and saved on its own. All are made in this one run.
    PARTS = TABLE[CID]["parts"]
    CFG["outfit"] = [dict(row, _part=name) for name, part in PARTS.items() for row in part.get("rows", [])]
    CFG["trim"] = [dict(row, _part=name) for name, part in PARTS.items() for row in part.get("trim", [])]
    HATS = [dict(part["hat"], _part=name) for name, part in PARTS.items() if part.get("hat")]
    CFG["bare_arm_from"] = 0.0
    CFG["bare_chest_vee"] = 0.14
elif OUTFIT:
    for key in ("outfit", "trim", "hat", "bare_arm_from", "bare_chest_vee"):
        CFG.pop(key, None)
    CFG.update(TABLE[CID]["outfits"][OUTFIT])
    CFG.setdefault("trim", [])
    HATS = [CFG["hat"]] if CFG.get("hat") else []
CURRENT_PART = ""
STEM = CID + ("__" + OUTFIT if OUTFIT else "")
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
    if metal < 0.5 and "skin" not in name:
        grey_ = 0.3 * colour[0] + 0.55 * colour[1] + 0.15 * colour[2]
        mute_ = float(TABLE.get("_mute", 0.3))
        colour = [c + (grey_ - c) * mute_ for c in colour]
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
SKIRT_CHAINS = 8
SKIRT_SEGMENTS = 3
SKIRT_SEGMENT = 0.2
SKIRT_AXIS_Y = 0.02
bpy.ops.object.select_all(action="DESELECT")
rig.select_set(True)
bpy.context.view_layer.objects.active = rig
bpy.ops.object.mode_set(mode="EDIT")
hips_bone = rig.data.edit_bones["mixamorig:Hips"]
skirt_top = hips_bone.head.z + 0.03
for chain in range(SKIRT_CHAINS):
    angle = math.tau * chain / SKIRT_CHAINS  # 0 is the front
    parent_bone = hips_bone
    for segment in range(SKIRT_SEGMENTS):
        made_bone = rig.data.edit_bones.new("mixamorig:Skirt%d_%d" % (chain, segment + 1))
        r0 = 0.15 + 0.045 * segment
        r1 = 0.15 + 0.045 * (segment + 1)
        made_bone.head = (math.sin(angle) * r0, SKIRT_AXIS_Y - math.cos(angle) * r0, skirt_top - segment * SKIRT_SEGMENT)
        made_bone.tail = (math.sin(angle) * r1, SKIRT_AXIS_Y - math.cos(angle) * r1, skirt_top - (segment + 1) * SKIRT_SEGMENT)
        made_bone.parent = parent_bone
        made_bone.use_connect = False
        parent_bone = made_bone
bpy.ops.object.mode_set(mode="OBJECT")
parts = []
for kind, name, atype in [] if OUTFIT else [("eyes", "low-poly", "Eyes"), ("eyebrows", CFG.get("eyebrows", "eyebrow001"), "Eyebrows"),
                          ("eyelashes", "eyelashes01", "Eyelashes"), ("teeth", "teeth_base", "Teeth"), ("tongue", "tongue01", "Tongue")]:
    part = HS.add_mhclo_asset(asset(kind, name), human, asset_type=atype, subdiv_levels=0, material_type="GAMEENGINE")
    part.name = "Face_" + kind
    parts.append(part)
# Card hair made for this head (art/blender/scripts/build_card_hair.py) replaces pack hair, the cap and the
# strands when CARD_HAIR_DIR holds <id>/<id>_hair_cards.blend.
CARD_HAIR = os.path.join(os.environ.get("CARD_HAIR_DIR", ""), CID, CID + "_hair_cards.blend")
CARD_HAIR = CARD_HAIR if (not OUTFIT and os.environ.get("CARD_HAIR_DIR") and os.path.exists(CARD_HAIR)) else ""
PACK_HAIR = CFG["hair"].get("asset") if not OUTFIT and not CARD_HAIR else None
pack_hair = None
if PACK_HAIR:
    # Hair from the packs: a modelled cut riding on the head. Fitted now, while the body is untouched; recoloured further down.
    pack_hair = HS.add_mhclo_asset(asset("hair", PACK_HAIR), human, asset_type="Hair", subdiv_levels=0, material_type="GAMEENGINE")
    pack_hair.name = "Hair"
    parts.append(pack_hair)
if OUTFIT and CFG.get("shoes") and not any(r["kind"] == "shoes" for r in CFG["outfit"]):
    shoes = HS.add_mhclo_asset(asset("clothes", CFG["shoes"]["asset"]), human, asset_type="Clothes", subdiv_levels=0, material_type="GAMEENGINE")
    shoes.name = "Shoes"
    shoes.data.materials.clear()
    shoes.data.materials.append(plain(CID + "_shoes", CFG["shoes"].get("colour", [0.08, 0.05, 0.03]), 0.4))
    parts.append(shoes)
if not OUTFIT:
    FS.load_targets(human, load_microsoft_visemes=False, load_meta_visemes=True, load_arkit_faceunits=True)
    FS.interpolate_targets(human)
for modifier in [m for m in human.modifiers if m.type == "MASK"]:
    human.modifiers.remove(modifier)

bone = lambda name: rig.matrix_world @ rig.data.bones[PREFIX + name].head_local
names = {g.index: g.name for g in human.vertex_groups}
group_index = {n: i for i, n in names.items()}
mesh = human.data
# The top of the eye, read now: the eye helpers are trimmed off the body further down.
_eye = group_index.get("helper-l-eye")
EYE_TOP_Z = max((v.co.z for v in mesh.vertices if any(g.group == _eye for g in v.groups)), default=None) if _eye is not None else None
print("EYE TOP", EYE_TOP_Z)


def in_group(vertex, group):
    index = group_index[group]
    return any(g.group == index for g in vertex.groups)


_bone_groups = set()


def weight(vertex, fragments):
    """The share of a vertex's bone weight on bones whose names carry one of
    the fragments. A share, because the base leaves palms and feet with only
    a fifth of a full weight in all."""
    if not _bone_groups:
        _bone_groups.update(i for i, n in names.items() if n in rig.data.bones)
    total = sum(g.weight for g in vertex.groups if g.group in _bone_groups)
    if total <= 1e-6:
        return 0.0
    return sum(g.weight for g in vertex.groups if g.group in _bone_groups and any(f in names[g.group] for f in fragments)) / total


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


# Silk that follows the body (a gown's `cling`): how many times the skin under it is smoothed, and how widely
# (in faces) the lift that clears what the smoothing took away is spread and then eased.
# Close garments made here (shirts, jumpers, waistcoats, cardigans) are cut from the body in the same way.
# On since cast_r13 (all twenty looked at in three sets, 2026-11-12). FIT_FROM_BODY=0 makes cast_r12's shapes.
FIT_FROM_BODY = os.environ.get("FIT_FROM_BODY", "1") != "0"
SKIRT_HEM_CUT = os.environ.get("SKIRT_HEM_CUT", "1") != "0"
CLING_SMOOTH = 30
CLING_SPREAD = 4
CLING_EASE = 4


CLOTHS = {
    "cotton": {"rough": 0.85, "depth": 0.5, "shade": 0.05},
    "wool": {"rough": 0.92, "depth": 0.9, "shade": 0.09},
    "knit": {"rough": 0.96, "depth": 1.6, "shade": 0.14},
    "felt": {"rough": 0.95, "depth": 0.35, "shade": 0.06},
    "silk": {"rough": 0.6, "depth": 0.12, "shade": 0.03},
    "satin": {"rough": 0.52, "depth": 0.03, "shade": 0.008},
    "leather": {"rough": 0.32, "depth": 0.25, "shade": 0.05},
    "fur": {"rough": 0.98, "depth": 1.6, "shade": 0.12},
}


MUTE = float(TABLE.get("_mute", CFG.get("mute", 0.3)))
WEAR = float(TABLE.get("_wear", CFG.get("wear", 1.0)))


def worn_colour(colour):
    grey = 0.3 * colour[0] + 0.55 * colour[1] + 0.15 * colour[2]
    return [min(1.0, (c + (grey - c) * MUTE) * (0.94 + 0.1 * MUTE)) for c in colour]


def patterned(name, colour, pattern, rough, cloth="cotton", alpha=1.0):
    colour = worn_colour(colour)
    if pattern and "colour" in pattern:
        pattern = dict(pattern, colour=worn_colour(pattern["colour"]))
    """A cloth material: its colours (plain or a two-colour pattern), the grain
    of its weave or knit worked into the colour, and a normal map of the same
    grain so light catches it."""
    kind_of = CLOTHS.get(cloth, CLOTHS["cotton"])
    size = 256
    pattern = pattern or {}
    first = numpy.array(colour, dtype=numpy.float32)
    other = numpy.array(pattern.get("colour", [c * 0.5 for c in colour]), dtype=numpy.float32)
    ys, xs = numpy.mgrid[0:size, 0:size].astype(numpy.float32)
    unit = size / float(pattern.get("cells", 4))
    width = float(pattern.get("width", 6)) * size / 64.0 / float(pattern.get("cells", 4)) * 4.0
    kind = pattern.get("kind", "plain")
    if kind == "stripes":
        mask = (xs % unit) < width
    elif kind == "bands":
        mask = (ys % unit) < width
    elif kind == "checks":
        mask = ((xs % unit) < width) | ((ys % unit) < width)
    elif kind == "dots":
        mask = ((xs % unit - unit / 2) ** 2 + (ys % unit - unit / 2) ** 2) < width * width
    elif kind == "herringbone":
        mask = ((xs + numpy.abs((ys % unit) - unit / 2)) % (unit / 4)) < (unit / 10)
    elif kind == "net":
        # Fishnet: two sets of diagonal threads; between them the cloth is open.
        mask = (((xs + ys) % unit) < width) | (((xs - ys) % unit) < width)
    else:
        mask = numpy.zeros((size, size), dtype=bool)
    # Seeds come from a checksum of the name: hash() of a string changes from one run to the next, and a build
    # must come out the same twice. The weave's own grain is seeded by the cloth alone, so every garment of one
    # cloth carries the same normal map, byte for byte, and the game keeps it once.
    rng = numpy.random.default_rng(zlib.crc32(name.encode("utf-8")))
    fine = numpy.random.default_rng(zlib.crc32(("weave " + cloth).encode("utf-8"))).random((size, size)).astype(numpy.float32)
    tau = math.tau
    if cloth == "wool":
        height_map = 0.5 + 0.5 * numpy.sin((xs + ys) * tau / 6.0) * 0.6 + (fine - 0.5) * 0.5
    elif cloth == "knit":
        column = numpy.abs(numpy.sin(xs * tau / 16.0))
        height_map = column * (0.6 + 0.4 * numpy.sin((ys + numpy.abs((xs % 16) - 8)) * tau / 8.0)) + (fine - 0.5) * 0.15
    elif cloth == "fur":
        # Pile: short strands lying one way, clumped.
        strands = numpy.abs(numpy.sin((xs * 0.35 + ys) * tau / 5.0 + fine * 3.0))
        height_map = strands * 0.7 + fine * 0.3
    elif cloth in ("felt", "leather"):
        blur = fine
        for _ in range(3):
            blur = (blur + numpy.roll(blur, 1, 0) + numpy.roll(blur, -1, 0) + numpy.roll(blur, 1, 1) + numpy.roll(blur, -1, 1)) / 5.0
        height_map = blur
    else:
        height_map = 0.5 + 0.25 * numpy.sin(xs * tau / 4.0) + 0.25 * numpy.sin(ys * tau / 4.0) + (fine - 0.5) * 0.2
    height_map = (height_map - height_map.min()) / max(float(height_map.max() - height_map.min()), 1e-6)
    grid = numpy.zeros((size, size, 4), dtype=numpy.float32)
    grid[:, :, 3] = 1.0
    grid[:, :, :3] = numpy.where(mask[:, :, None], other[None, None, :], first[None, None, :])
    grid[:, :, :3] = numpy.clip(grid[:, :, :3] * (1.0 - kind_of["shade"] + 2.0 * kind_of["shade"] * height_map[:, :, None]), 0, 1)
    if WEAR > 0.0:
        # Uneven fading: broad soft patches, lighter and a little greyer.
        patch = rng.random((size // 16, size // 16)).astype(numpy.float32)
        patch = numpy.kron(patch, numpy.ones((16, 16), dtype=numpy.float32))
        for _ in range(10):
            patch = (patch + numpy.roll(patch, 3, 0) + numpy.roll(patch, -3, 0) + numpy.roll(patch, 3, 1) + numpy.roll(patch, -3, 1)) / 5.0
        patch = (patch - patch.min()) / max(float(patch.max() - patch.min()), 1e-6)
        fade = (patch[:, :, None] - 0.5) * 0.22 * WEAR
        luma = grid[:, :, :3].mean(axis=2, keepdims=True)
        grid[:, :, :3] = numpy.clip(grid[:, :, :3] * (1.0 + fade) + (luma - grid[:, :, :3]) * numpy.clip(fade * 1.5, 0, 1), 0, 1)
        # Pilling and lint: sparse pale flecks; a few darker threads.
        flecks = rng.random((size, size)) > (1.0 - 0.006 * WEAR)
        grid[:, :, :3] = numpy.where(flecks[:, :, None], numpy.clip(grid[:, :, :3] * 1.25 + 0.04, 0, 1), grid[:, :, :3])
        threads = rng.random((size, size)) > (1.0 - 0.004 * WEAR)
        grid[:, :, :3] = numpy.where(threads[:, :, None], grid[:, :, :3] * 0.72, grid[:, :, :3])
    dx = (numpy.roll(height_map, -1, 1) - numpy.roll(height_map, 1, 1)) * kind_of["depth"]
    dy = (numpy.roll(height_map, -1, 0) - numpy.roll(height_map, 1, 0)) * kind_of["depth"]
    normal = numpy.zeros((size, size, 4), dtype=numpy.float32)
    length = numpy.sqrt(dx * dx + dy * dy + 1.0)
    normal[:, :, 0] = (-dx / length) * 0.5 + 0.5
    normal[:, :, 1] = (-dy / length) * 0.5 + 0.5
    normal[:, :, 2] = (1.0 / length) * 0.5 + 0.5
    normal[:, :, 3] = 1.0
    if alpha < 1.0:
        # Sheer cloth: the whole picture lets this much light through.
        grid[:, :, 3] = alpha
    if kind == "net":
        # The holes of a net are open, not sheer: the thread is whole and the rest is clipped away.
        grid[:, :, :3] = numpy.where(mask[:, :, None], grid[:, :, :3], first[None, None, :])
        grid[:, :, 3] = numpy.where(mask, 1.0, 0.0)
    pictures = []
    for suffix, data, space in (("_cloth", grid, "sRGB"), ("_cloth_normal", normal, "Non-Color")):
        picture = bpy.data.images.new(name + suffix, size, size, alpha=True)
        picture.pixels = data.ravel()
        picture.filepath_raw = os.path.join(OUT, name + suffix + ".png")
        picture.file_format = "PNG"
        picture.save()
        picture.colorspace_settings.name = space
        pictures.append(picture)
    material = bpy.data.materials.new(name)
    material.use_nodes = True
    nodes = material.node_tree.nodes
    links = material.node_tree.links
    shader = nodes["Principled BSDF"]
    colour_node = nodes.new("ShaderNodeTexImage")
    colour_node.image = pictures[0]
    if WEAR > 0.0:
        wear_node = nodes.new("ShaderNodeVertexColor")
        wear_node.layer_name = "Wear"
        mix = nodes.new("ShaderNodeMix")
        mix.data_type = "RGBA"
        mix.blend_type = "MULTIPLY"
        mix.inputs[0].default_value = 1.0
        links.new(colour_node.outputs[0], mix.inputs[6])
        links.new(wear_node.outputs[0], mix.inputs[7])
        links.new(mix.outputs[2], shader.inputs["Base Color"])
    else:
        links.new(colour_node.outputs[0], shader.inputs["Base Color"])
    normal_picture = nodes.new("ShaderNodeTexImage")
    normal_picture.image = pictures[1]
    normal_node = nodes.new("ShaderNodeNormalMap")
    links.new(normal_picture.outputs[0], normal_node.inputs["Color"])
    links.new(normal_node.outputs[0], shader.inputs["Normal"])
    shader.inputs["Roughness"].default_value = kind_of["rough"]
    if kind == "net":
        links.new(colour_node.outputs["Alpha"], shader.inputs["Alpha"])
        for setting, value in (("blend_method", "CLIP"), ("alpha_threshold", 0.5)):
            try:
                setattr(material, setting, value)
            except (AttributeError, TypeError):
                pass
    elif alpha < 1.0:
        links.new(colour_node.outputs["Alpha"], shader.inputs["Alpha"])
        for setting, value in (("blend_method", "BLEND"), ("surface_render_method", "BLENDED")):
            try:
                setattr(material, setting, value)
            except Exception:
                pass
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


def hang_on_skirt_bones(obj):
    """Weights for cloth made from the skirt helper: the waistband to the hips,
    everything below shared between the two nearest chains and, down its
    length, between a segment and the one above."""
    obj.vertex_groups.clear()
    groups = {}

    def add(group_name, index, amount):
        if amount <= 0.0005:
            return
        if group_name not in groups:
            groups[group_name] = obj.vertex_groups.new(name=group_name)
        groups[group_name].add([index], amount, "ADD")

    for v in obj.data.vertices:
        depth = skirt_top - v.co.z
        if depth <= 0.0:
            add(PREFIX + "Hips", v.index, 1.0)
            continue
        around = (math.atan2(v.co.x, -(v.co.y - SKIRT_AXIS_Y)) % math.tau) / math.tau * SKIRT_CHAINS
        first = int(around) % SKIRT_CHAINS
        share = around - int(around)
        along = min(depth / SKIRT_SEGMENT, SKIRT_SEGMENTS - 0.001)
        segment = int(along)
        into = min(1.0, (along - segment) / 0.6)
        for chain, part in ((first, 1.0 - share), ((first + 1) % SKIRT_CHAINS, share)):
            add(PREFIX + "Skirt%d_%d" % (chain, segment + 1), v.index, part * into)
            above = PREFIX + "Hips" if segment == 0 else PREFIX + "Skirt%d_%d" % (chain, segment)
            add(above, v.index, part * (1.0 - into))


def smooth_weights(obj, passes=2):
    """Even out a pack garment's bone weights between neighbouring points. The packs fit each point to the
    nearest body faces, so neighbours along an edge can follow different bones; in a pose a robe's facing
    came apart from the chest in square teeth."""
    mesh_ = obj.data
    near = [[] for _ in mesh_.vertices]
    for edge in mesh_.edges:
        a, b = edge.vertices
        near[a].append(b)
        near[b].append(a)
    table = [{g.group: g.weight for g in v.groups} for v in mesh_.vertices]
    for _ in range(passes):
        fresh = []
        for index, own in enumerate(table):
            if not near[index]:
                fresh.append(own)
                continue
            mixed = {group: 0.5 * weight for group, weight in own.items()}
            share = 0.5 / len(near[index])
            for other in near[index]:
                for group, weight in table[other].items():
                    mixed[group] = mixed.get(group, 0.0) + share * weight
            fresh.append(mixed)
        table = fresh
    for index, weights_ in enumerate(table):
        # The engine takes four bones a point: keep the four strongest, made to sum to one.
        kept = sorted(weights_.items(), key=lambda item: -item[1])[:4]
        total = sum(weight for _, weight in kept) or 1.0
        for group in obj.vertex_groups:
            if group.index in weights_ and group.index not in dict(kept):
                group.remove([index])
        for group_index, weight in kept:
            obj.vertex_groups[group_index].add([index], weight / total, "REPLACE")


_FORMS = {}


def dressing_form(kind="close"):
    """The body as cloth lies on it. Made once for the person, in three weights; each returns where every point of
    the body lies on that form.
      close  for what is worn next the skin (shirts, blouses, trousers): the skin smoothed without shrinking, so
             small relief is gone and limbs keep their size, then lifted wherever that still sank below the skin.
      full   for what is worn over (jumpers, waistcoats, jackets, coats): the close form with the hollows of the
             chest filled, so heavier cloth spans from one fullness to the next. A coat cut from the close form
             printed the bust as sharply as a vest (cast_r13's first engine line-up). Never inside the close form.
      silk   for a gown's bodice, as Lily approved it on 2026-11-12: smoothed until the bust's cone is gone, and
             what that took away given back as a lift that is level over each fullness and falls away round it."""
    if kind in _FORMS:
        return _FORMS[kind]
    smooth_, spread_, ease_ = [int(n) for n in os.environ.get("CLING_TUNE", "%d,%d,%d" % (CLING_SMOOTH, CLING_SPREAD, CLING_EASE)).split(",")]
    aside = {index for index, group_name in names.items() if group_name.startswith(("helper-", "joint-"))}
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bm.verts.ensure_lookup_table()
    deform = bm.verts.layers.deform.verify()
    lose = [v for v in bm.verts if any(index in aside for index in v[deform].keys())]
    index_of = {v: v.index for v in bm.verts}
    bmesh.ops.delete(bm, geom=lose, context="VERTS")
    skin = {v: v.co.copy() for v in bm.verts}
    bm.verts.index_update()
    pairs_ = numpy.array([(e.verts[0].index, e.verts[1].index) for e in bm.edges], dtype=numpy.int64)
    count = numpy.zeros(len(bm.verts))
    numpy.add.at(count, pairs_[:, 0], 1.0)
    numpy.add.at(count, pairs_[:, 1], 1.0)
    count = numpy.maximum(count, 1.0)[:, None]

    def middle_of_neighbours(points):
        total = numpy.zeros_like(points)
        numpy.add.at(total, pairs_[:, 0], points[pairs_[:, 1]])
        numpy.add.at(total, pairs_[:, 1], points[pairs_[:, 0]])
        return total / count

    points = numpy.array([v.co[:] for v in bm.verts], dtype=numpy.float64)
    if kind == "silk":
        for _ in range(smooth_):
            points = points + (middle_of_neighbours(points) - points) * 0.5
        spread_, ease_ = 8, 6
    else:
        # Smoothed without shrinking (a pass that draws each point toward its neighbours, then one that pushes it
        # a little further back). Plain smoothing shrank arms and legs to sticks, and the lift that put them back
        # made every sleeve a wing and filled the armpits (all twenty, 2026-11-12).
        for _ in range(smooth_):
            for factor in (0.5, -0.53):
                points = points + (middle_of_neighbours(points) - points) * factor
    for v, co in zip(bm.verts, points):
        v.co = co
    bm.normal_update()
    beside = {v: [e.other_vert(v) for e in v.link_edges] for v in bm.verts}
    need = {v: max(0.0, (skin[v] - v.co).dot(v.normal)) for v in bm.verts}
    relief = max(need.values(), default=0.0)
    for _ in range(spread_):
        need = {v: max([need[v]] + [need[o] for o in beside[v]]) for v in bm.verts}
    for _ in range(ease_):
        need = {v: (need[v] + sum(need[o] for o in beside[v])) / (1 + len(beside[v])) for v in bm.verts}
    for v in bm.verts:
        v.co = v.co + v.normal * need[v]
    filled = 0.0
    if kind == "full":
        # Fill the hollows of the chest: each point there moves toward the middle of its neighbours only when
        # that is outward. Fullnesses stay; what lies between and under them comes up level with them. Only on
        # the front of the trunk between the armholes: filled at the armpit, the hollow under the arm is a wing.
        bm.normal_update()
        points = numpy.array([v.co[:] for v in bm.verts], dtype=numpy.float64)
        ways = numpy.array([v.normal[:] for v in bm.verts], dtype=numpy.float64)
        spine_y = bone("Spine2").y
        share = numpy.zeros(len(points))
        for v in bm.verts:
            at_ = skin[v]
            up = min(1.0, max(0.0, (at_.z - (waist - 0.02)) / 0.06)) * min(1.0, max(0.0, (neck - 0.07 - at_.z) / 0.05))
            across = min(1.0, max(0.0, (shoulder.x * 0.78 - abs(at_.x)) / 0.03))
            ahead = min(1.0, max(0.0, (spine_y - 0.01 - at_.y) / 0.03))
            share[v.index] = up * across * ahead
        start = points.copy()
        for _ in range(int(os.environ.get("CLING_FILL", "300"))):
            step = middle_of_neighbours(points) - points
            outward = numpy.maximum(0.0, (step * ways).sum(axis=1))
            points = points + ways * (outward * share * 0.6)[:, None]
        filled = float(numpy.abs(points - start).max())
        for v, co in zip(bm.verts, points):
            v.co = co
    _FORMS[kind] = {index_of[v]: v.co.copy() for v in bm.verts}
    bm.free()
    print("DRESSING FORM", kind, len(_FORMS[kind]), "points, smoothing took away up to", round(relief, 4), "hollows filled by up to", round(filled, 4))
    return _FORMS[kind]


CUT_ON_FORM = os.environ.get("CUT_ON_FORM", "1") != "0"
_FORM_TREES = {}


def form_tree(kind):
    """The dressing form as a surface to find the nearest point of."""
    if kind not in _FORM_TREES:
        form = dressing_form(kind)
        points = [tuple(form.get(v.index, v.co)) for v in mesh.vertices]
        _FORM_TREES[kind] = BVHTree.FromPolygons(points, [tuple(q.vertices) for q in mesh.polygons if all(i in form for i in q.vertices)])
    return _FORM_TREES[kind]


class _OnForm:
    """A point of the body where the dressing form puts it: its place from the form, everything else its own."""
    __slots__ = ("co", "groups", "index", "normal")

    def __init__(self, co, vertex):
        self.co = co.copy()
        self.groups = vertex.groups
        self.index = vertex.index
        self.normal = vertex.normal


def piece(name, source, keep, offset, colour, rough=0.8, thicken=None, reshape=None, pattern=None, cloth="cotton", subdivide=0, made=None, weights=None, alpha=1.0, fit=False, hug=False, way=None, relax=0):
    """A garment: the faces of a clothing helper whose corners all pass `keep`,
    set off from the skin by `offset` metres. Or, with `made`, a shape built
    outright (made fills the mesh; weights gives each point its bones).
    `way` gives the direction a point is set off in, where its own normal will not do: a flat piece with open
    sides (an apron, a bib) set off four centimetres along its points' normals had every edge point leaning its
    own way, and the sides came out torn."""
    bm = bmesh.new()
    skin_at = skin_way = None
    if FIT_FROM_BODY and source == "helper-tights" and "body" in group_index and made is None and not name.startswith(("Shoe", "Boot", "Stocking", "Bib", "ApronBib")):
        # Cut from the body's own surface, as the stage gowns are: the clothing helper is coarse and stands off
        # unevenly, which is where padded shirts and stepped necklines came from. Everything that lies on the
        # body is cut from the one dressing form, or a shirt cut from it would lie outside trousers that were not.
        # Footwear keeps the helper, which has a foot without toes; so do bibs, which hang flat from the chest
        # (cut from the form, an apron's bib clung to the bust like wet cloth).
        source = "body"
    if made is not None:
        made(bm)
        bm.verts.ensure_lookup_table()
    else:
        bm.from_mesh(mesh)
        bm.verts.ensure_lookup_table()
        source_index = group_index[source]
        deform = bm.verts.layers.deform.verify()
        if source == "body":
            # Every garment cut from the body is cut from the one dressing form, so what is worn over another
            # always lies outside it. Each point remembers the skin it stands over.
            form = dressing_form("silk" if hug else "full" if offset >= 0.012 else "close")
            skin_at = bm.verts.layers.float_vector.new("skin_at")
            skin_way = bm.verts.layers.float_vector.new("skin_way")
            for v in bm.verts:
                v[skin_at] = v.co
                v[skin_way] = mesh.vertices[v.index].normal
                if v.index in form:
                    v.co = form[v.index]
        # Cloth cut from the body takes all of the body: every point that is not a clothing helper or a joint
        # marker. (The group called "body" leaves out patches of it, the nipples among them, and cloth cut from
        # that group alone had holes there.)
        aside = {index for index, group_name in names.items() if group_name.startswith(("helper-", "joint-"))} if source == "body" else set()
        # `keep` gives each point a margin in metres: positive inside the garment, negative outside (True and
        # False count as far inside and far outside). The cloth is cut where the margin crosses zero, through
        # the faces. Cutting along the faces' own edges left teeth at every armhole, neckline and hem.
        # Margins are read before anything is deleted: deleting renumbers the points.
        margin = {}
        for v in bm.verts:
            if (source == "body" and any(index in aside for index in v[deform].keys())) or (source != "body" and source_index not in v[deform]):
                continue
            # A garment cut from the dressing form is measured on the form, where it will lie. Measured on the
            # body as it stands, a level hem or neckline was level there and not on the form (smoothing moves
            # each ring of points a little up or down), and came out in teeth.
            value = keep(_OnForm(v.co, mesh.vertices[v.index]) if source == "body" and CUT_ON_FORM else mesh.vertices[v.index])
            if source == "helper-skirt" and SKIRT_HEM_CUT:
                # The skirt helper turns in under itself below its hem. Shaped, that rim lay as a floor inside
                # the hem and the skirt read as a bubble. It is cut off just above the turn.
                below = mesh.vertices[v.index].co.z - 0.128
                value = below if value is True else min(float(value), below) if value is not False else value
            if value is True:
                value = 1.0
            elif value is False:
                value = -1.0
            margin[v] = float(value) if abs(float(value)) > 1e-7 else 1e-7
        lose = [f for f in bm.faces if not all(v in margin for v in f.verts)]
        bmesh.ops.delete(bm, geom=lose, context="FACES")
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
        crossed = [f for f in bm.faces if min(margin[v] for v in f.verts) < 0.0 < max(margin[v] for v in f.verts)]
        made_faces = bmesh.ops.triangulate(bm, faces=crossed)["faces"]
        cut_points = set()
        for edge in [e for e in bm.edges if margin[e.verts[0]] * margin[e.verts[1]] < 0.0]:
            a, b = edge.verts
            ma, mb = margin[a], margin[b]
            if abs(ma) >= 1.0 or abs(mb) >= 1.0:
                at = 0.5            # a yes-or-no edge has no slope to follow
            else:
                at = max(0.02, min(0.98, ma / (ma - mb)))
            _, new = bmesh.utils.edge_split(edge, a, at)
            if skin_at is not None:
                # The new point stands over its own patch of skin, between its two ends'. Left with one end's,
                # its clearance was measured against skin up to a face away, and it was lifted by a different
                # amount at every row: the teeth along every neckline, V and armhole.
                new[skin_at] = Vector(a[skin_at]).lerp(Vector(b[skin_at]), at)
                between = Vector(a[skin_way]).lerp(Vector(b[skin_way]), at)
                new[skin_way] = between.normalized() if between.length > 1e-9 else Vector(a[skin_way])
            margin[new] = 0.0
            cut_points.add(new)
        for face in [f for f in bm.faces if sum(1 for v in f.verts if v in cut_points) == 2]:
            pair = [v for v in face.verts if v in cut_points]
            if not any(e.other_vert(pair[0]) == pair[1] for e in pair[0].link_edges):
                bmesh.utils.face_split(face, pair[0], pair[1])
        lose = [f for f in bm.faces if any(margin.get(v, 0.0) < 0.0 for v in f.verts)]
        bmesh.ops.delete(bm, geom=lose, context="FACES")
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    if not bm.faces:
        bm.free()
        print("GARMENT", name, "is empty")
        return None
    # A little easing along every open edge takes out what the cut left.
    # (More easing on an apron's sides was tried for cast_r13 and took bites out of them; they keep eight.)
    eased = set()
    for _ in range(22 if made is not None or source == "body" else 8):
        moved = {}
        for v in bm.verts:
            beside = [e.other_vert(v) for e in v.link_edges if e.is_boundary]
            if len(beside) == 2:
                moved[v] = v.co * 0.5 + (beside[0].co + beside[1].co) * 0.25
        for v, co in moved.items():
            v.co = co
        eased.update(moved)
    if source == "body" and made is None and eased:
        # Easing draws a curved edge in toward its own middle, which is off the dressing form and under it:
        # round an armhole or a neck the edge of a waistcoat sank below the jumper it is worn over, and the
        # jumper showed through it in teeth. Each eased point is put back on the form, where it slid to.
        on_form = form_tree("silk" if hug else "full" if offset >= 0.012 else "close")
        for v in eased:
            hit = on_form.find_nearest(v.co)
            if hit[0] is not None:
                v.co = hit[0]
    if relax > 0:
        # `relax`: the cut edge and the two rows of points behind it are evened out together. On a full figure
        # the body's faces are large and stretched, and a gown's armholes and neckline, eased along the edge
        # alone, stayed in steps. (Easing the edge alone for longer folds it over the row behind.)
        rim = {v for v in bm.verts if v.is_boundary}
        band = set(rim)
        for _ in range(2):
            band |= {e.other_vert(v) for v in band for e in v.link_edges}
        for _ in range(relax):
            moved = {}
            for v in band:
                if v in rim:
                    beside = [e.other_vert(v) for e in v.link_edges if e.is_boundary]
                    if len(beside) == 2:
                        moved[v] = v.co * 0.5 + (beside[0].co + beside[1].co) * 0.25
                else:
                    around = [e.other_vert(v).co for e in v.link_edges]
                    moved[v] = v.co * 0.5 + sum(around, Vector()) * (0.5 / len(around))
            for v, co in moved.items():
                v.co = co
    if subdivide:
        bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=subdivide, use_grid_fill=True, smooth=0.6)
    edge_steps = {}
    if hug and skin_at is not None:
        reached = [v for v in bm.verts if v.is_boundary]
        for step in range(4):
            fresh = []
            for v in reached:
                if v not in edge_steps:
                    edge_steps[v] = step
                    fresh.extend(e.other_vert(v) for e in v.link_edges)
            reached = fresh
    bm.normal_update()
    close_ = 0
    for v in bm.verts:
        push = offset + (thicken(v.co) if thicken else 0.0)
        floor_ = max(push, 0.003)
        if abs(v.co.x) > shoulder.x - 0.02 and v.co.z > hip and source in ("helper-tights", "body"):
            # Sleeves and shoulder caps sit closer than the body of a garment, or arms read as padded.
            push = 0.004 + (push - 0.004) * 0.5
        elif source in ("helper-tights", "body") and v.co.z > neck - 0.13:
            # Room over the collarbones and round the base of the neck: skin came through close shirts there
            # as chips beside the placket and teeth along the neckline.
            push += 0.005 * min(1.0, (v.co.z - (neck - 0.13)) / 0.05)
        if skin_at is not None:
            # Cut from the dressing form. A garment that hugs (a gown's bodice, with nothing under it) comes back
            # to the skin over the last three faces before each cut edge; and no point of any garment is left
            # nearer its own patch of skin than its stand-off.
            at_, normal_ = Vector(v[skin_at]), Vector(v[skin_way])
            if hug:
                v.co = at_.lerp(v.co, min(1.0, edge_steps.get(v, 3) / 3.0) ** 0.8)
            v.co = v.co + v.normal * push
            off_ = (v.co - at_).dot(normal_)
            if off_ < min(floor_, push):
                v.co = v.co + normal_ * (min(floor_, push) - off_)
                close_ += 1
        else:
            v.co = v.co + (way(v.co) if way else v.normal) * push
        if reshape:
            v.co = reshape(v.co)
    if skin_at is not None:
        print("FIT", name, len(bm.verts), "points from the dressing form,", close_, "lifted clear of the skin")
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
    if weights is not None:
        for v in out.vertices:
            for bone_name, amount in weights(v.co).items():
                if amount > 0.001:
                    obj.vertex_groups[PREFIX + bone_name].add([v.index], amount, "REPLACE")
    if WEAR > 0.0:
        # Grime gathers at hems and cuffs, cloth fades and shines at elbows,
        # knees and seat. Carried as point colours, which multiply the cloth.
        lowest = min(v.co.z for v in out.vertices)
        highest = max(v.co.z for v in out.vertices)
        span = max(highest - lowest, 1e-4)
        layer = out.color_attributes.new(name="Wear", type="BYTE_COLOR", domain="CORNER")
        noise = numpy.random.default_rng(zlib.crc32((STEM + name).encode("utf-8")))
        jitter = noise.random(len(out.vertices))
        tint = []
        for v in out.vertices:
            co = v.co
            hem = max(0.0, 1.0 - (co.z - lowest) / (0.16 * span + 0.03))
            dark = 1.0 - (0.2 * hem ** 1.5 + 0.06 * jitter[v.index]) * WEAR
            light = 0.0
            for spot, radius in ((Vector((elbow.x, elbow.y, elbow.z)), 0.07), (Vector((-elbow.x, elbow.y, elbow.z)), 0.07),
                                 (Vector((0.09, -0.06, knee)), 0.08), (Vector((-0.09, -0.06, knee)), 0.08), (Vector((0.0, 0.11, hip - 0.04)), 0.13)):
                light = max(light, max(0.0, 1.0 - (co - spot).length / radius))
            if abs(co.x) > shoulder.x * 0.9 and along_arm(co) > 0.86:
                dark -= 0.1 * WEAR
            value = max(0.45, min(1.0, dark + 0.0)) * (1.0 + 0.0)
            warm = 1.0 - 0.05 * hem * WEAR
            tint.append((min(1.0, value + 0.14 * light * WEAR), min(1.0, value * warm + 0.14 * light * WEAR), min(1.0, value * warm * warm + 0.14 * light * WEAR), 1.0))
        for loop in out.loops:
            layer.data[loop.index].color = tint[loop.vertex_index]
    while out.uv_layers:
        out.uv_layers.remove(out.uv_layers[0])
    wrap_uv(out, float((pattern or {}).get("repeat", 6.0)))
    obj.data.materials.append(patterned("%s_%s_%s" % (STEM, CURRENT_PART or "x", name) if CURRENT_PART else "%s_%s" % (STEM, name), colour, pattern, rough, cloth, alpha))
    if source == "helper-skirt":
        hang_on_skirt_bones(obj)
    obj.parent = rig
    obj.modifiers.new("Armature", "ARMATURE").object = rig
    obj["part"] = CURRENT_PART
    garments.append(obj)
    print("GARMENT", name, len(out.polygons), "faces")
    return obj


def tinted_image(image, colour, name, size=512, hair=False, deep_only=False):
    """A pack garment's own picture, recoloured to a person's colour: its
    darks and mids take the colour, its lights go pale, its drawing stays."""
    small = image.copy()
    if small.size[0] > size:
        small.scale(size, max(1, int(size * small.size[1] / small.size[0])))
    width, height = small.size
    data = numpy.empty(width * height * 4, dtype=numpy.float32)
    small.pixels.foreach_get(data)
    data = data.reshape(height, width, 4)
    bpy.data.images.remove(small)
    light = data[..., 0] * 0.3 + data[..., 1] * 0.55 + data[..., 2] * 0.15
    seen = data[..., 3] > 0.05
    middle = float(numpy.median(light[seen])) if seen.any() else 0.5
    light = numpy.clip(light * min(4.0, 0.5 / max(middle, 0.05)), 0.0, 1.0)
    tone = numpy.array(colour if hair else worn_colour(colour), dtype=numpy.float32)
    hue = tone / max(float(tone.max()), 1e-3)
    deep = hue * max(0.32, min(0.8, float(tone.max()) * 1.25))
    pale = 0.5 + 0.5 * hue
    if not hair and float(tone.max()) < 0.26:
        # Review: black pack shoes rendered silver. Below this the floor of 0.32 lifted the tone itself.
        deep = hue * max(0.045, float(tone.max()) * 1.25)
        pale = numpy.clip(tone * 2.4 + 0.07, 0.0, 1.0)
    if hair:
        # Hair keeps its own darkness: black stays black, with a sheen no brighter than twice its tone.
        # Dark hair keeps a sheen; light hair needs shadow between the locks or it reads as a bathing cap.
        deep = tone * (1.15 if float(tone.max()) < 0.4 else 0.55)
        pale = numpy.clip(tone * (2.0 if float(tone.max()) < 0.4 else 1.1) + 0.04, 0.0, 1.0)
    rise = numpy.clip((light - (0.93 if deep_only else 0.62)) / (0.07 if deep_only else 0.3), 0.0, 1.0)[..., None]
    out = numpy.clip(light / 0.62, 0.0, 1.0)[..., None] * deep * (1.0 - rise) + pale * light[..., None] * rise
    result = numpy.concatenate([out, data[..., 3:4]], axis=2).astype(numpy.float32)
    picture = bpy.data.images.new(name, width, height, alpha=True)
    picture.pixels.foreach_set(result.ravel())
    picture.filepath_raw = os.path.join(OUT, name + ".png")
    picture.file_format = "PNG"
    picture.save()
    return picture


def shrink_pictures(obj, keep=None, size=512):
    """The packs' normal and other maps come large; a game part does not need them so."""
    for slot in obj.material_slots:
        tree_ = slot.material.node_tree if slot.material and slot.material.use_nodes else None
        for node in (tree_.nodes if tree_ else []):
            if node.type == "TEX_IMAGE" and node.image and node is not keep and node.image.size[0] > size:
                smaller = node.image.copy()
                smaller.scale(size, max(1, int(size * smaller.size[1] / smaller.size[0])))
                node.image = smaller


_skin_tree = []


def slim(obj, keep=0.005, floor=0.004, ceiling=0.008, whole=False, pull=True, even=6):
    """Bring a pack garment in to the body above the hips. The packs' jackets
    are cut with padded shoulders and wide sleeves; on a small figure that
    reads as bulk. What stands off the skin keeps its order, at a fraction of
    its distance: least of it over the shoulders and upper arms.

    Each point is moved toward the nearest skin, and neighbouring points do not always share one: across a
    lapel or down a shirt front the nearest skin jumps, and the cloth came out crumpled. `even` passes even out
    what each point was moved by among its neighbours, so a lapel moves as a lapel; then no point is left
    nearer the skin than half the floor."""
    if not _skin_tree:
        _skin_tree.append(BVHTree.FromPolygons([tuple(v.co) for v in mesh.vertices], [tuple(q.vertices) for q in mesh.polygons]))
    before = [v.co.copy() for v in obj.data.vertices]
    for v in obj.data.vertices:
        if v.co.z < hip - 0.02 and not whole:
            continue
        hit = _skin_tree[0].find_nearest(v.co)
        if hit[0] is None:
            continue
        gap = v.co - hit[0]
        signed = gap.dot(hit[1])
        outside = signed > 0.0005
        way = gap.normalized() if outside else hit[1]
        distance = gap.length if outside else signed
        if pull and distance > keep:
            upper = v.co.z > shoulder.z - 0.16 and abs(v.co.x) > shoulder.x - 0.08
            distance = keep + (distance - keep) * (0.28 if upper else 0.5)
        if distance < ceiling:
            # A floor of clearance. The packs expect the body hidden beneath them; here it is whole. A collar
            # lying on the neck let skin through in teeth, and so did any wide face lying close across a
            # curve. Everything from 4 mm under the skin to `ceiling` over it is spread, in its own order,
            # between `floor` and `ceiling`, so the garment's layers stay stacked as they were made.
            distance = floor + (max(distance, -0.004) + 0.004) * (ceiling - floor) / (ceiling + 0.004)
        v.co = hit[0] + way * distance
    if even > 0:
        near = [[] for _ in obj.data.vertices]
        for edge in obj.data.edges:
            a, b = edge.vertices
            near[a].append(b)
            near[b].append(a)
        moved = [v.co - before[v.index] for v in obj.data.vertices]
        for _ in range(even):
            moved = [m * 0.4 + sum((moved[k] for k in near[i]), Vector()) * (0.6 / len(near[i])) if near[i] else m for i, m in enumerate(moved)]
        for v in obj.data.vertices:
            if v.co.z < hip - 0.02 and not whole:
                continue
            v.co = before[v.index] + moved[v.index]
            hit = _skin_tree[0].find_nearest(v.co)
            if hit[0] is not None:
                off = (v.co - hit[0]).dot(hit[1])
                if off < floor * 0.5:
                    v.co = v.co + hit[1] * (floor * 0.5 - off)


def skirt_weights(co):
    """Bones for a point of cloth below the hips: the two nearest skirt chains."""
    out_ = {}
    depth = skirt_top - co.z
    around = (math.atan2(co.x, -(co.y - SKIRT_AXIS_Y)) % math.tau) / math.tau * SKIRT_CHAINS
    first = int(around) % SKIRT_CHAINS
    share = around - int(around)
    along = min(max(depth, 0.0) / SKIRT_SEGMENT, SKIRT_SEGMENTS - 0.001)
    segment = int(along)
    into = min(1.0, (along - segment) / 0.6)
    for chain, part in ((first, 1.0 - share), ((first + 1) % SKIRT_CHAINS, share)):
        out_["Skirt%d_%d" % (chain, segment + 1)] = out_.get("Skirt%d_%d" % (chain, segment + 1), 0.0) + part * into
        above = "Hips" if segment == 0 else "Skirt%d_%d" % (chain, segment)
        out_[above] = out_.get(above, 0.0) + part * (1.0 - into)
    return out_


def asset_piece(name, asset_name, colour, skirt=False, kind="clothes", atype="Clothes", deep_only=False, felt=False, made=None, hem_to_calf=False):
    """A garment from the MakeHuman community packs (CC0), fitted to this body,
    recoloured to the person's colour. `skirt` rehangs what falls below the
    hips on the skirt bones, so it does not split between the legs."""
    obj = HS.add_mhclo_asset(asset(kind, asset_name), human, asset_type=atype, subdiv_levels=0, material_type="GAMEENGINE")
    obj.name = name
    node, image = base_image(obj)
    if felt:
        # Review: a pack felt hat's picture, stretched for contrast, read as sacking. Plain felt in the person's colour.
        obj.data.materials.clear()
        obj.data.materials.append(patterned("%s_%s_%s" % (STEM, CURRENT_PART or "x", name), colour, None, 0.9, "wool"))
        node = None
    elif made:
        # Ruling cast_period_pass_20261112: a ready-made dress whose own picture tinted to tiger, zebra or camouflage
        # wears a plain period cloth, with a small pattern or none. Its unwrap is one sheet, so it is scaled for the weave.
        obj.data.materials.clear()
        obj.data.materials.append(patterned("%s_%s_%s" % (STEM, CURRENT_PART or "x", name), colour, made.get("pattern"), 0.85, made.get("cloth") or "cotton"))
        if made.get("wrap"):
            # Its own unwrap is no use for cloth (half of one pack boot sat on a single point of its picture).
            while obj.data.uv_layers:
                obj.data.uv_layers.remove(obj.data.uv_layers[0])
            wrap_uv(obj.data, float(made.get("repeat", 5.0)))
        elif obj.data.uv_layers.active is not None:
            for corner in obj.data.uv_layers.active.data:
                corner.uv = (corner.uv[0] * float(made.get("scale", 9.0)), corner.uv[1] * float(made.get("scale", 9.0)))
        node = None
    elif image is not None:
        node.image = tinted_image(image, colour, "%s_%s_%s" % (STEM, CURRENT_PART or "x", name), deep_only=deep_only)
        obj["uv_picture"] = True
    else:
        obj.data.materials.clear()
        obj.data.materials.append(plain("%s_%s" % (STEM, name), worn_colour(colour), 0.8))
    if atype == "Clothes" and name == "Robe":
        # A robe's facing lies flat down the chest; in a pose the chest came through it. It stands further off.
        slim(obj, floor=0.009, ceiling=0.016)
    elif atype == "Clothes" and "hoe" not in name and "oot" not in name:
        slim(obj)
    elif atype == "Hat":
        # A ready-made hat is cut close; it must clear the hair that lies flat under it.
        slim(obj, floor=0.007, ceiling=0.013, whole=True, pull=False)
    shrink_pictures(obj, node)
    # Both faces are drawn: a collar folded over shows its inside, and with one face culled the engine
    # showed the neck through it in square teeth.
    for slot in obj.material_slots:
        if slot.material:
            slot.material.use_backface_culling = False
    # Cloth, not lacquer: the packs' gloss maps made suits shine like oilskin.
    for slot in obj.material_slots:
        tree_ = slot.material.node_tree if slot.material and slot.material.use_nodes else None
        shader_ = tree_.nodes.get("Principled BSDF") if tree_ else None
        if shader_ is not None:
            for socket_name, value in (("Roughness", 0.5 if "hoe" in name or "oot" in name else 0.82), ("Metallic", 0.0)):
                socket = shader_.inputs.get(socket_name)
                if socket is not None:
                    for link in list(socket.links):
                        tree_.links.remove(link)
                    socket.default_value = value
    for modifier in [m for m in obj.modifiers if m.type in ("SUBSURF", "MASK")]:
        obj.modifiers.remove(modifier)
    if atype == "Clothes" and "hoe" not in name and "oot" not in name:
        smooth_weights(obj)
    if hem_to_calf:
        # Ruling cast_period_pass_20261112: a ready-made suit skirt ended above the knee. It is drawn down to the
        # calf: every point below the hips keeps its place in the skirt's length, and the length grows.
        lowest = min(v.co.z for v in obj.data.vertices)
        start = hip - 0.06
        target = knee - 0.13
        if lowest > target + 0.01 and start - lowest > 0.05:
            stretch = (start - target) / (start - lowest)
            for v in obj.data.vertices:
                if v.co.z < start:
                    v.co.z = start - (start - v.co.z) * stretch
    if skirt:
        line = skirt_top - 0.03
        for v in obj.data.vertices:
            if v.co.z >= line:
                continue
            blend = min(1.0, (line - v.co.z) / 0.08)
            for g in list(v.groups):
                obj.vertex_groups[g.group].add([v.index], g.weight * (1.0 - blend), "REPLACE")
            for bone_name, amount in skirt_weights(v.co).items():
                group_name = PREFIX + bone_name
                group = obj.vertex_groups.get(group_name) or obj.vertex_groups.new(name=group_name)
                group.add([v.index], amount * blend, "ADD")
    obj["part"] = CURRENT_PART
    garments.append(obj)
    print("GARMENT", name, "from pack", asset_name, len(obj.data.polygons), "faces")
    return obj


W = 0.15        # a bone-weight difference of one counts as this many metres of margin


def band(value, low, high):
    """Margin inside a band: how far the value is from the nearer end."""
    return min(value - low, high - value)


def round_min(p, q, r=0.02):
    """The lesser of two margins, with the corner where their edges meet rounded off. A square corner cut
    through the body's faces comes out in teeth; a rounded one comes out clean (as the armhole showed)."""
    if p >= r or q >= r:
        return min(p, q)
    return r - math.hypot(r - p, r - q)


def round_max(p, q, r=0.02):
    """The greater of two margins, with the inside corner where their edges meet filled in to a curve."""
    return max(p, q, math.hypot(max(p + r, 0.0), max(q + r, 0.0)) - r)


def out_arm(co):
    """Metres out along the arm from the shoulder joint, measured in the frontal plane. (The arm also points
    a little forward; measured along it, the cut let the back of the shoulder through as a pointed wing.)"""
    side = 1.0 if co.x >= 0 else -1.0
    across, down = wrist.x - shoulder.x, wrist.z - shoulder.z
    length = math.hypot(across, down)
    return ((co.x * side - shoulder.x) * across + (co.z - shoulder.z) * down) / length


def torso(v, low=None, high=None, sleeves=1.0, vee=0.0, inner=False, back=0.0, one_shoulder=0.0, strap=0.0, under=0.12, armpit=0.10):
    """The margin (metres, positive inside) of a body garment at a point of the tights."""
    # Nothing cut from the tights hangs below the fork of the legs: it came out as a tongue between them.
    low = max(hip - 0.075, waist - 0.05 if low is None else low)
    # A round neck is cut a little below the top of the tights: their own rim is a row of battlements.
    high = neck - 0.012 if high is None else high
    co = v.co
    arm = weight(v, ARM)
    if sleeves > 0.0 and arm > 0.45:
        if one_shoulder and co.x * (1.0 if one_shoulder > 0 else -1.0) < 0.0:
            return -0.05        # the bare arm of a one-shoulder gown has no sleeve
        return (sleeves - along_arm(co)) * 0.5
    inside = band(co.z, low, high)
    if sleeves <= 0.0:
        # An armhole: a clean cut at the point of the shoulder.
        # The arm comes off at the plane square to it through the shoulder joint, and only outboard of the
        # chest (that plane also passes through the hip). Both are plain planes, so the edge is plain.
        # The plane sits seven centimetres inboard of the joint: nearer, the cloth is on the part of the
        # body the arm carries, and when the arm came down it drew the shoulder of a waistcoat down the
        # sleeve as a wing. Below the armpit the side of the garment is whole. A sleeveless layer worn under
        # another is cut narrower, so it never shows at the armhole.
        narrow = 0.02 if inner else 0.0
        # What comes away is everything beyond three planes at once: past the plane across the arm, outboard
        # of the chest, and above the armpit. ("Above the armpit" is waived out on the arm itself: in this
        # pose the forearms hang below it, and kept, they stood out from a waistcoat as a pair of sleeves.)
        # Where the chest plane meets the armpit plane the corner is rounded, as an armhole is; left square,
        # the cut through the body's faces there came out in teeth.
        # Sized to the shoulders, and never nearer the middle than a strap's width beyond the open neck: on a
        # narrow body a fixed cut met the V and left the garment hanging from two scraps.
        strap_edge = max(shoulder.x * 0.56, vee * 0.42 + 0.04) - narrow
        if strap > 0.0:
            # An evening strap: this wide beyond the open neck, and no wider.
            strap_edge = (vee - 0.02) * 0.42 + strap
        past_arm = out_arm(co) + shoulder.x * 0.4 + narrow
        outboard = abs(co.x) - strap_edge
        # `armpit`: how far below the shoulder the armhole ends. On a high bust the usual depth runs under it.
        above_armpit = co.z - (shoulder.z - armpit)
        on_the_arm = abs(co.x) - (shoulder.x - 0.005)
        round_ = 0.035
        corner = round_ - math.hypot(max(round_ - outboard, 0.0), max(round_ - above_armpit, 0.0))
        away = min(past_arm, max(corner, min(outboard, on_the_arm)))
        inside = min(inside, -away)
    if vee > 0.0:
        # An open neck: a V from the collar down the chest. Behind the chest the margin grows, so the
        # V closes smoothly over the shoulder and leaves no chips at the collarbones.
        depth = (neck + 0.01) - co.z
        # Review of cast_r10: seven V necks were stepped or toothed. Two square corners made them: where the V
        # met the plane behind the chest (a crease across the shoulder), and where it met the level neck cut
        # (a point standing up beside the neck). Both are rounded.
        outside_vee = round_max(abs(co.x) - (vee - depth) * 0.42, (co.y - (bone("Spine2").y - 0.02)) * 2.0, 0.02)
        outside_vee = round_min(outside_vee, high - co.z, 0.018)
        inside = min(inside, outside_vee)
    if back > 0.0:
        # An evening back: open in a deep V from the nape, behind the plane of the chest only.
        # Its edges are the straps: at the shoulder the opening is as wide as the front's neck, and it closes
        # to a point `back` below. Over the shoulder, between the front's opening and this one, the width runs
        # from one to the other; left unsaid, the cloth closed over the shoulder and climbed the neck in wings.
        depth = (neck + 0.01) - co.z
        inner = max(0.03, (vee - 0.02) * 0.42) if vee > 0.0 else 0.07
        behind = inner * max(0.0, 1.0 - max(depth, 0.0) / back) ** 0.6 if depth < back else -1.0
        ahead = (vee - depth) * 0.42 if vee > 0.0 else -1.0
        turn_ = min(1.0, max(0.0, (co.y - (bone("Spine2").y - 0.02)) / 0.035))
        inside = min(inside, abs(co.x) - (ahead * (1.0 - turn_) + behind * turn_))
    if one_shoulder:
        # One shoulder: everything above a line from under the bare arm up to the other side of the neck comes
        # away, front and back alike. +1 keeps the wearer's left shoulder, -1 the right.
        side = 1.0 if one_shoulder > 0 else -1.0
        # `under`: how far below the shoulder the line starts under the bare arm. Too low, and it does not cover the bust.
        low_x, low_z = -side * shoulder.x * 0.8, shoulder.z - under
        high_x, high_z = side * shoulder.x * 0.4, neck + 0.012
        line_z = low_z + (high_z - low_z) * (co.x - low_x) / (high_x - low_x)
        inside = min(inside, (line_z - co.z) * abs(high_x - low_x) / math.hypot(high_x - low_x, high_z - low_z))
    # The hem is the level line at `low`, which never goes below the fork. Following the legs' bone weights
    # instead scalloped every cardigan and blouse hem.
    return inside


def legs(v, low, high):
    return min(band(v.co.z, low, high), (0.3 - weight(v, ARM)) * W)


def seat_room(co):
    """Extra clearance over the seat and hips, most of it behind: the review
    found the body showing through skirts there, and under-layers through coats."""
    return 0.02 * max(0.0, 1.0 - abs(co.z - (hip - 0.08)) / 0.16) * (1.0 if co.y > 0.0 else 0.3)


_FRONT = None


def hang_flat(co, over=0.0):
    """A bib hangs from the fullest part of the chest in a plane; it does not follow the bust. Each point is
    brought most of the way forward to that plane, less toward the waist, where the bib is tied in. `over`
    sets a bib worn over another bib that much further forward (in one plane the two tore through each other)."""
    global _FRONT
    if _FRONT is None:
        body_ = group_index.get("body")
        chest_ = [v.co.y for v in mesh.vertices if waist + 0.04 < v.co.z < neck - 0.12 and abs(v.co.x) < 0.11 and (body_ is None or any(g.group == body_ for g in v.groups))]
        _FRONT = min(chest_) if chest_ else co.y
    high = max(0.0, min(1.0, (co.z - waist) / 0.1))
    plane = _FRONT - 0.02 - over
    return Vector((co.x, co.y + (plane - co.y) * 0.8 * high * high * (3.0 - 2.0 * high), co.z)) if co.y > plane else co


def skirt_shape(hem, flare, pleats=0, kick=0.0, clear=0.009):
    """`clear`: once shaped, no point of a skirt is left nearer the body than this (zero leaves it be). A skirt
    shorter than the helper draws the helper's lower, closer rings up over the seat, and a pleat's fold can dip
    under the skin there: a short pleated skirt had the seat showing through it in two places."""
    top = hip + 0.07
    natural_hem = 0.12
    # Where the knee falls along the skirt: a gown cut close to the knee and let out below it "kicks" from there.
    knee_t = max(0.05, min(0.95, (top - knee) / (top - natural_hem)))

    def shape(co):
        t = max(0.0, min(1.0, (top - co.z) / (top - natural_hem)))
        z = top - t * (top - hem)
        spread = 1.0 + flare * t + kick * max(0.0, (t - knee_t) / (1.0 - knee_t)) ** 1.6
        if pleats:
            # Wide pleats are shallower than fine ones: seated, a long skirt's dozen deep folds stood up as ribs.
            spread *= 1.0 + (0.09 if pleats >= 16 else 0.055) * t * math.sin(math.atan2(co.x, -(co.y - 0.02)) * pleats)
        x, y = co.x * spread, (co.y - 0.02) * spread
        if clear > 0.0 and z > hip - 0.2:
            reach = math.hypot(x, y)
            need = skin_out(math.atan2(x, -y), z) + clear
            if 0.0 < reach < need:
                x, y = x * need / reach, y * need / reach
        return Vector((x, y + 0.02, z))
    return shape


_FALL_TREES = None


def fall_trees():
    """The skirt helper and the skin, each as a tree to cast rays at."""
    global _FALL_TREES
    if _FALL_TREES is None:
        helper = group_index["helper-skirt"]
        aside = {index for index, group_name in names.items() if group_name.startswith(("helper-", "joint-"))}
        in_helper = {v.index for v in mesh.vertices if any(g.group == helper for g in v.groups)}
        in_skin = {v.index for v in mesh.vertices if not any(g.group in aside for g in v.groups)}
        points = [tuple(v.co) for v in mesh.vertices]
        _FALL_TREES = (BVHTree.FromPolygons(points, [tuple(q.vertices) for q in mesh.polygons if all(i in in_helper for i in q.vertices)]),
                       BVHTree.FromPolygons(points, [tuple(q.vertices) for q in mesh.polygons if all(i in in_skin for i in q.vertices)]))
    return _FALL_TREES


_SKIN_OUT = {}


def skin_out(angle, z):
    """How far out from the skirt's axis the body reaches at this height, this way round: its outermost skin.
    Looked for from a third of a metre out, so an arm hanging beside the hips is not taken for them."""
    key = (round(angle * 40.0), round(z * 100.0))
    if key not in _SKIN_OUT:
        a, height = key[0] / 40.0, key[1] / 100.0
        out = Vector((math.sin(a), -math.cos(a), 0.0))
        hit = fall_trees()[1].ray_cast(Vector((0.0, SKIRT_AXIS_Y, height)) + out * 0.33, -out, 0.33)
        _SKIN_OUT[key] = 0.33 - hit[3] if hit[0] is not None else 0.0
    return _SKIN_OUT[key]


def coat_fall(hem, flare, clearance, top_clear):
    """The skirt of a coat. Shaped like any skirt from the skirt helper it began as a shelf standing out from the
    coat's body at the hip, swelled, and tucked in again at the hem: a bell. Here it starts on the coat's own
    body at the waist, eases out to clear the seat and hips, and from there falls in a straight line to a hem
    no narrower than the widest the helper ever is (what is worn under it is cut from the same helper)."""
    helper_tree, skin_tree = fall_trees()
    top = hip + 0.07
    natural_hem = 0.128
    full = hip - 0.07
    t_full = (top - full) / (top - natural_hem)
    rings = {}

    def ring(key):
        if key not in rings:
            angle = key / 40.0
            out = Vector((math.sin(angle), -math.cos(angle), 0.0))

            def reach(tree, z):
                hit = tree.ray_cast(Vector((0.0, SKIRT_AXIS_Y, z)), out, 1.5)
                return hit[3] if hit[0] is not None else None
            upper = [r for r in (reach(helper_tree, full + (top - full) * k / 6.0) for k in range(7)) if r]
            whole = [r for r in (reach(helper_tree, natural_hem + 0.01 + (top - natural_hem - 0.01) * k / 15.0) for k in range(16)) if r]
            skin = reach(skin_tree, top)
            r_full = (max(upper) if upper else 0.2) + clearance
            r_top = min(r_full, (skin if skin else r_full - top_clear) + top_clear)
            r_hem = max((max(whole) if whole else r_full) + clearance, r_full) * (1.0 + flare)
            # Room for the legs all the way down, as they stand at rest. (Room for wide trousers too was tried:
            # the rest pose stands with the feet apart, and a coat cut to clear trousers there was a tent on
            # anyone standing with their feet together, which is how they are seen.)
            for k in range(1, 13):
                t_leg = t_full + (1.0 - t_full) * k / 12.0
                z_leg = top - t_leg * (top - hem)
                need = skin_out(angle, z_leg) + 0.015
                if need > r_full + (r_hem - r_full) * k / 12.0:
                    r_hem = r_full + (need - r_full) * 12.0 / k
            rings[key] = (r_top, r_full, r_hem)
        return rings[key]

    helper_reach = {}

    def helper_out(key, z):
        place = (key, round(z * 100.0))
        if place not in helper_reach:
            a = key / 40.0
            hit = helper_tree.ray_cast(Vector((0.0, SKIRT_AXIS_Y, place[1] / 100.0)), Vector((math.sin(a), -math.cos(a), 0.0)), 1.5)
            helper_reach[place] = hit[3] if hit[0] is not None else 0.0
        return helper_reach[place]

    def shape(co):
        t = max(0.0, min(1.0, (top - co.z) / (top - natural_hem)))
        angle = math.atan2(co.x, -(co.y - SKIRT_AXIS_Y))
        low = math.floor(angle * 40.0)
        part = angle * 40.0 - low
        r_top, r_full, r_hem = (a + (b - a) * part for a, b in zip(ring(low), ring(low + 1)))
        if t < t_full:
            s = t / t_full
            r = r_top + (r_full - r_top) * s * s * (3.0 - 2.0 * s)
            # Over the seat the skirt worn under the coat stands out from the body before the coat has eased
            # out to clear it: it showed through there as a dark patch. The coat keeps outside the helper that
            # skirt is cut from, at any height a shorter skirt could have drawn it up to.
            z_here = top - t * (top - natural_hem)
            under = max(helper_out(low, z_here - 0.02 * k) for k in range(4))
            if under > 0.0:
                # What that skirt stands off its helper by: its own offset and its room over the seat.
                seat = 0.02 * max(0.0, 1.0 - abs(z_here - (hip - 0.08)) / 0.16) * (1.0 if math.cos(angle) < 0.0 else 0.3)
                r = max(r, under + 0.016 + seat)
        else:
            r = r_full + (r_hem - r_full) * (t - t_full) / (1.0 - t_full)
        return Vector((math.sin(angle) * r, SKIRT_AXIS_Y - math.cos(angle) * r, top - t * (top - hem)))
    return shape


def embroider(row):
    """Embroidery on a gown (Lily, 2026-11-12: detailed, with relief, elegant but bold). The design is a picture
    with its own normal map (art/tools/cast_embroidery.py makes both from a drawing on black). It is wrapped
    round the body like a label round a bottle, from `from` above the floor up to `below_neck` under the neck,
    centred `turn` degrees round from the front and `around` of a full turn wide. It lies a hair off the
    outermost cloth of its part and is cut from that cloth, so it moves exactly as the cloth does."""
    part = row.get("_part", "")
    cloths = [g for g in garments if g.get("part", "") == part and g.name.split(".")[0] in ("DressTop", "Veil")]
    if not any(g.name.startswith("Veil") for g in cloths):
        cloths += [g for g in garments if g.get("part", "") == part and g.name.split(".")[0] == "DressSkirt"]
    if not cloths:
        print("EMBROIDERY found no gown in", part)
        return
    low = float(row.get("from", 0.04))
    high = neck - float(row.get("below_neck", 0.1))
    centre = math.radians(float(row.get("turn", 0.0)))
    span = float(row.get("around", 0.95)) * math.tau
    name = "%s_%s_Embroidery" % (STEM, part or "x")
    pictures = []
    for key, suffix, space in (("picture", "_cloth", "sRGB"), ("normal", "_cloth_normal", "Non-Color")):
        target = os.path.join(OUT, name + suffix + ".png")
        shutil.copyfile(row[key], target)
        picture = bpy.data.images.load(target)
        picture.colorspace_settings.name = space
        pictures.append(picture)
    material = bpy.data.materials.new(name)
    material.use_nodes = True
    nodes, links = material.node_tree.nodes, material.node_tree.links
    shader = nodes["Principled BSDF"]
    colour_node = nodes.new("ShaderNodeTexImage")
    colour_node.image = pictures[0]
    links.new(colour_node.outputs[0], shader.inputs["Base Color"])
    # Stitches are there or not there: cut out, not blended, so they are drawn with the solid things and sort
    # rightly over sheer cloth.
    cut = nodes.new("ShaderNodeMath")
    cut.operation = "ROUND"
    links.new(colour_node.outputs["Alpha"], cut.inputs[0])
    links.new(cut.outputs[0], shader.inputs["Alpha"])
    normal_picture = nodes.new("ShaderNodeTexImage")
    normal_picture.image = pictures[1]
    normal_node = nodes.new("ShaderNodeNormalMap")
    normal_node.inputs["Strength"].default_value = float(row.get("relief", 1.0))
    links.new(normal_picture.outputs[0], normal_node.inputs["Color"])
    links.new(normal_node.outputs[0], shader.inputs["Normal"])
    shader.inputs["Roughness"].default_value = float(row.get("rough", 0.42))
    for setting, value in (("blend_method", "CLIP"), ("alpha_threshold", 0.5)):
        try:
            setattr(material, setting, value)
        except Exception:
            pass
    material.use_backface_culling = False
    # Stitches need more picture than plain cloth does: the exporter lets this one keep 1024.
    material["picture_limit"] = 1024
    for cloth_ in cloths:
        work = cloth_.copy()
        work.data = cloth_.data.copy()
        work.name = "Embroidery"
        bpy.context.scene.collection.objects.link(work)
        bm = bmesh.new()
        bm.from_mesh(work.data)
        bm.normal_update()
        layer = bm.loops.layers.uv.verify()
        for v in bm.verts:
            v.co = v.co + v.normal * float(row.get("lift", 0.0014))
        lose = []
        for face in bm.faces:
            middle = face.calc_center_median()
            middle_turn = math.atan2(middle.x, -(middle.y - 0.02))
            middle_from_centre = (middle_turn - centre + math.pi) % math.tau - math.pi
            inside = False
            for loop in face.loops:
                co = loop.vert.co
                turn_ = math.atan2(co.x, -(co.y - 0.02))
                step = (turn_ - middle_turn + math.pi) % math.tau - math.pi      # this corner, measured from the face's middle: no seam
                u = 0.5 + (middle_from_centre + step) / span
                v = (co.z - low) / (high - low)
                loop[layer].uv = (u, v)
                inside = inside or (0.0 < u < 1.0 and 0.0 < v < 1.0)
            if not inside:
                lose.append(face)
        bmesh.ops.delete(bm, geom=lose, context="FACES")
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
        kept = len(bm.faces)
        bm.to_mesh(work.data)
        bm.free()
        if not kept:
            bpy.data.objects.remove(work)
            continue
        work.data.materials.clear()
        work.data.materials.append(material)
        work["part"] = part
        garments.append(work)
        print("GARMENT Embroidery on", cloth_.name, kept, "faces")


def worn_with(row):
    """The other rows of the same set (a, b or c) as this one."""
    mark = row.get("_part", "")[:1]
    return [r for r in CFG.get("outfit", []) if r is not row and mark and r.get("_part", "")[:1] == mark]


# Garments that close over the chest below a V, and how deep the V is when the row does not say.
V_DEPTH = {"waistcoat": 0.2, "jacket": 0.3, "cardigan": 0.34, "coat": 0.2}


def v_foot(part):
    """The height of the foot of the V of the garment in this part, or None when nothing in it closes over the chest."""
    for other in CFG.get("outfit", []):
        if other.get("_part", "") == part and other["kind"] in V_DEPTH:
            return neck + 0.01 - float(other.get("vee", V_DEPTH[other["kind"]]))
    return None


def layer_off(part):
    """How far off the body the garment of this part that closes over the chest stands, or None."""
    for other in CFG.get("outfit", []):
        if other.get("_part", "") == part and other["kind"] in V_DEPTH:
            return {"waistcoat": 0.017, "cardigan": 0.018, "coat": 0.023}.get(other["kind"], max(0.02, float(other.get("ease", 0.02))))
    return None


def lapel_base(row):
    """How far off the body the layer stands that this row's lapels lie on."""
    for other in CFG.get("outfit", []):
        if other.get("_part", "") == row.get("_part", ""):
            if other["kind"] == "coat":
                return 0.023
            if other["kind"] == "jacket":
                return max(0.02, float(other.get("ease", 0.02)))
    return 0.02


def under_outer_layer(part):
    """For the trim of a top: a test of where the set's outer layer lies closed over it. Review: braces, pockets
    and shirt buttons showed on top of aprons, coats and closed jackets."""
    if not part.endswith("_top"):
        return lambda x, z: False
    outer = part[:1] + "_over"
    foot = v_foot(outer)
    if foot is not None:
        return lambda x, z, f=foot: abs(x) > (z - f) * 0.42 - 0.012
    if any(other.get("_part", "") == outer and other["kind"] in ("apron", "bib") for other in CFG.get("outfit", [])):
        return lambda x, z: z < neck - 0.12 or abs(x) > 0.03
    return lambda x, z: False


def skirt_under(row):
    """The skirt this row is worn with, if the set has one: a made one, or one from the packs."""
    for other in worn_with(row):
        if other["kind"] == "skirt" or (other["kind"] == "asset" and other.get("skirt")):
            return other
    return None


pending_collars = []
for row in (CFG.get("outfit", []) if OUTFIT else []):
    CURRENT_PART = row.get("_part", "")
    kind = row["kind"]
    # A top worn with a skirt is tucked: it ends just under the skirt's band. Left long, its hem and
    # ribbing came through the front of the skirt as a dark toothed patch.
    tucked_low = hip + 0.045 if skirt_under(row) is not None and row.get("_part", "").endswith("_top") else None
    # Worn over something from the packs (cut fuller than what is made here), an outer layer stands further off.
    over_pack = 0.012 if row.get("_part", "").endswith("_over") and any(o["kind"] == "asset" and not o.get("_part", "").endswith(("_feet", "_head")) for o in worn_with(row)) else 0.0
    colour = row.get("colour", (0.5, 0.5, 0.5))      # embroidery brings its own
    cloth = row.get("cloth")
    if kind == "asset":
        asset_piece(row.get("name", "Pack"), row["asset"], colour, skirt=bool(row.get("skirt")), atype=row.get("atype", "Clothes"), deep_only=bool(row.get("deep")), felt=bool(row.get("felt")), made=row.get("made"), hem_to_calf=bool(row.get("hem_to_calf")))
    elif kind == "shoes":
        # `open_toe`: the front of the shoe is cut away over the toes, a sandal's opening.
        open_toe = float(row.get("open_toe", 0.0))
        piece("Shoes", "helper-tights", lambda v, o=open_toe: min(ankle + 0.03 - v.co.z, (weight(v, ("Foot", "Toe")) - 0.2) * W,
                                                                 (0.5 - weight(v, ("Toe",))) * W if o > 0.0 else 1.0), 0.009, colour, 0.35, cloth=cloth or "leather")
        if float(row.get("heel", 0.0)) > 0.0:
            # A spike under the back of the heel, as long as `heel`. On a flat foot it stands into the floor; it is
            # right only on a foot posed up on its ball, which is the presentation's pose, not the shoe's.
            def heel_shape(bm, r=row):
                height = float(r.get("heel", 0.08))
                for side in (1.0, -1.0):
                    foot = bone(("Left" if side > 0 else "Right") + "Foot")
                    base = Vector((foot.x, foot.y + 0.035, max(0.0, foot.z - 0.075)))
                    made = bmesh.ops.create_cone(bm, cap_ends=True, segments=10, radius1=0.004, radius2=0.011, depth=height)
                    for v_ in made["verts"]:
                        v_.co = v_.co + base + Vector((0.0, 0.0, -height * 0.5 + 0.004))

            def heel_weights(co):
                return {("Left" if co.x > 0 else "Right") + "Foot": 1.0}
            piece("Heels", None, None, 0.0, colour, 0.3, cloth="leather", made=heel_shape, weights=heel_weights)
        if row.get("strap"):
            piece("ShoeStraps", "helper-tights", lambda v: min(band(v.co.z, ankle + 0.02, ankle + 0.06), (weight(v, LEG) - 0.3) * W), 0.006, colour, 0.35, cloth="leather")
    elif kind == "sandals":
        # A strappy sandal: a thin sole under the foot, a strap across the toes, one over the instep and one round
        # the ankle. Cut from the foot of the tights, so the straps follow it.
        def sandal_margin(v, r=row):
            co = v.co
            on_foot = (weight(v, ("Foot", "Toe")) - 0.2) * W
            side = "Left" if co.x >= 0.0 else "Right"
            heel = bone(side + "Foot")
            toe = bone(side + "ToeBase")
            reach = (toe - heel)
            along = (co - heel).dot(reach) / max(reach.length_squared, 1e-6)
            w = float(r.get("strap", 0.007))
            sole = 0.014 - co.z
            toes = w - abs(along - float(r.get("toe_at", 1.05))) * reach.length
            instep = w - abs(along - float(r.get("instep_at", 0.55))) * reach.length
            straps = max(sole, toes, instep)
            ankle_strap = min(w - abs(co.z - (ankle + float(r.get("ankle_up", 0.035)))), (weight(v, LEG) - 0.3) * W)
            return max(min(on_foot, straps), ankle_strap)
        piece("Sandals", "helper-tights", sandal_margin, 0.004, colour, 0.35, cloth=cloth or "leather")
    elif kind == "shirt":
        piece(row.get("name", "Shirt"), "helper-tights", lambda v, r=row, t=tucked_low: torso(v, inner=True, low=max(waist - float(r.get("length", 0.09)), t or -9.0), sleeves=float(r.get("sleeves", 1.0)), vee=float(r.get("vee", 0.0))), float(row.get("ease", 0.004)), colour, 0.85,
              pattern=row.get("pattern"), cloth=cloth or "cotton",
              thicken=lambda co, r=row: 0.5 * float(r.get("blouson", 0.0)) * max(0.0, 1.0 - abs(co.z - (waist + 0.06)) / 0.14), fit=True)
    elif kind == "jumper":
        piece("Jumper", "helper-tights", lambda v, r=row, t=tucked_low: torso(v, inner=True, low=max(hip - float(r.get("length", 0.01)), t or -9.0), sleeves=float(r.get("sleeves", 1.0)), vee=float(r.get("vee", 0.0))),
              float(row.get("ease", 0.017)), colour, 0.95, pattern=row.get("pattern"), cloth=cloth or "knit", fit=True)
    elif kind == "waistcoat":
        piece("Waistcoat", "helper-tights", lambda v, r=row: torso(v, low=waist - 0.04, sleeves=0.0, vee=float(r.get("vee", 0.2))), 0.017, colour, 0.7, pattern=row.get("pattern"), cloth=cloth or "wool", fit=True)
    elif kind == "jacket":
        piece("Jacket", "helper-tights", lambda v, r=row: torso(v, low=hip - float(r.get("length", 0.06)), sleeves=float(r.get("sleeves", 1.0)), vee=float(r.get("vee", 0.3))),
              max(0.02, float(row.get("ease", 0.02))) + over_pack, colour, 0.8, pattern=row.get("pattern"), cloth=cloth or "wool",
              thicken=lambda co, r=row: float(r.get("shoulders", 0.0)) * max(0.0, 1.0 - abs(co.z - shoulder.z) / 0.08) + float(r.get("skirted", 0.0)) * max(0.0, min(1.0, (waist - co.z) / 0.2)))
    elif kind == "dress":
        sleeves = float(row.get("sleeves", 0.5))
        # "cling": silk that follows the body like a web. The bodice is cut from the body's own surface, so it
        # keeps every contour and moves exactly as the skin does (nothing can come through it, however close it
        # lies); it is opaque, and it reaches down to the fork. The skirt lies close and may be sheer.
        cling = bool(row.get("cling")) and "body" in group_index
        piece("DressTop", "body" if cling else "helper-tights",
              lambda v, r=row, sl=sleeves, c=cling: torso(v, low=hip - (0.075 if c else 0.02), high=neck - float(r.get("top", 0.012)), sleeves=sl, vee=float(r.get("vee", 0.06)),
                                                         back=float(r.get("back", 0.0)), one_shoulder=float(r.get("one_shoulder", 0.0)), strap=float(r.get("strap", 0.0)),
                                                         under=float(r.get("under", 0.12)), armpit=float(r.get("armpit", 0.10))),
              float(row.get("ease", 0.003 if cling else 0.006)), colour, float(row.get("rough", 0.85)), pattern=row.get("pattern"), cloth=cloth or "cotton", hug=cling, relax=int(row.get("edge_relax", 0)))
        piece("DressSkirt", "helper-skirt", lambda v: True, 0.005 if cling else 0.01, colour, float(row.get("rough", 0.85)), thicken=(lambda co: seat_room(co) * 0.6) if cling else seat_room,
              reshape=skirt_shape(float(row.get("hem", 0.4)), float(row.get("flare", 0.2)), int(row.get("pleats", 0)), float(row.get("kick", 0.0)), clear=0.004 if cling else 0.009),
              pattern=row.get("pattern"), cloth=cloth or "cotton", subdivide=1, alpha=float(row.get("sheer", 1.0)))
    elif kind == "embroidery":
        embroider(row)
    elif kind == "veil":
        # Gossamer: a second, far sheerer skirt that floats over the first.
        piece("Veil", "helper-skirt", lambda v: True, float(row.get("off", 0.02)), colour, 0.5,
              reshape=skirt_shape(float(row.get("hem", 0.05)), float(row.get("flare", 0.3)), int(row.get("pleats", 12)), float(row.get("kick", 0.0))),
              cloth=cloth or "silk", subdivide=1, alpha=float(row.get("sheer", 0.3)))
    elif kind == "cardigan":
        piece("Cardigan", "helper-tights", lambda v, r=row: torso(v, low=hip + 0.012, sleeves=1.0, vee=float(r.get("vee", 0.34))), 0.018, colour, 0.95, pattern=row.get("pattern"), cloth=cloth or "knit", fit=True)
    elif kind == "coat":
        piece("CoatTop", "helper-tights", lambda v, r=row: torso(v, low=hip - 0.02, sleeves=1.0, vee=float(r.get("vee", 0.2))), 0.023 + over_pack, colour, 0.85, pattern=row.get("pattern"), cloth=cloth or "wool")
        piece("CoatSkirt", "helper-skirt", lambda v: True, 0.0, colour, 0.85, reshape=coat_fall(float(row.get("hem", 0.45)), float(row.get("flare", 0.12)), 0.04 + over_pack, 0.0265 + over_pack),
              pattern=row.get("pattern"), cloth=cloth or "wool", subdivide=1)
    elif kind == "bib":
        piece("Bib", "helper-tights", lambda v: min((0.3 - weight(v, ARM)) * W, bone("Spine2").y - 0.01 - v.co.y, band(v.co.z, waist - 0.02, neck - 0.13), 0.11 - abs(v.co.x)),
              0.018, colour, 0.85, pattern=row.get("pattern"), cloth=cloth or "cotton", reshape=hang_flat, way=lambda co: Vector((0.0, -1.0, 0.0)))
    elif kind == "apron":
        apron_skirt = skirt_under(row)
        apron_made = apron_skirt is not None and apron_skirt["kind"] == "skirt"
        apron_on_overalls = any(o["kind"] == "asset" and "worksuit" in str(o.get("asset", "")) for o in worn_with(row))

        def strap_shape(bm, lift=0.024):
            # Each strap is a ribbon found on the body itself: from the bib up over the shoulder and down to
            # the shoulder blade. Cut out of the body's own faces it came out as ragged flaps round the neck.
            body_tree = BVHTree.FromPolygons([tuple(v.co) for v in mesh.vertices if True], [tuple(q.vertices) for q in mesh.polygons])
            middle = Vector((0.0, bone("Spine2").y, neck - 0.10))
            for side in (1.0, -1.0):
                rows = []
                for k in range(15):
                    angle = math.radians(-58.0 + 160.0 * k / 14.0)        # from the chest, over the top, to the back
                    # The strap closes toward the neck as it climbs and opens again behind.
                    x_mid = side * (0.066 - 0.012 * math.sin(max(0.0, min(math.pi, angle + math.radians(30.0)))))
                    row = []
                    outward = Vector((0.0, -math.cos(angle), math.sin(angle)))
                    for across in (-0.017, 0.017):
                        # Cast from inside the chest outward: from outside, a ray coming down meets the head first.
                        hit = body_tree.ray_cast(Vector((x_mid + across, middle.y, middle.z)), outward, 0.3)
                        if hit[0] is None:
                            row = None
                            break
                        row.append(bm.verts.new(hit[0] + outward * lift))
                    if row:
                        rows.append(row)
                for upper, lower in zip(rows, rows[1:]):
                    bm.faces.new((upper[0], upper[1], lower[1], lower[0]))
            bmesh.ops.recalc_face_normals(bm, faces=bm.faces)

        if not apron_on_overalls:
            piece("ApronStraps", None, None, 0.0, colour, 0.85, cloth=cloth or "cotton", made=strap_shape, weights=lambda co: {"Spine2": 1.0})
        piece("Apron", "helper-skirt", lambda v: min(-v.co.y, (0.95 - abs(math.atan2(v.co.x, -(v.co.y - 0.02)))) * 0.12), 0.021 if apron_made else 0.046 + over_pack, colour, 0.85, thicken=seat_room if apron_made else None,
              way=lambda co: Vector((co.x, co.y - 0.02, 0.0)).normalized(),
              reshape=skirt_shape(max(float(row.get("hem", 0.5)), float(apron_skirt.get("hem", 0.38)) + 0.05) if apron_made else float(row.get("hem", 0.5)),
                                  float(apron_skirt.get("flare", 0.25)) if apron_made else float(row.get("flare", 0.11)),
                                  int(apron_skirt.get("pleats", 0)) if apron_made else 0), cloth=cloth or "cotton", subdivide=1)
        # Review of cast_r10: the bib's outline was ragged. Its edge followed the arm's weights, which are uneven,
        # and its top corners were square. Plain planes, rounded corners, a finer cut.
        piece("ApronBib", "helper-tights", lambda v: min(bone("Spine2").y - 0.01 - v.co.y, v.co.z - (waist - 0.02), round_min(neck - 0.12 - v.co.z, 0.1 - abs(v.co.x), 0.03)),
              0.02 + over_pack, colour, 0.85, cloth=cloth or "cotton", subdivide=1, reshape=lambda co: hang_flat(co, 0.009), way=lambda co: Vector((0.0, -1.0, 0.0)))
    elif kind == "sash":
        piece("Sash", "helper-tights", lambda v, r=row: min(0.045 - abs(v.co.z - (hip + float(r.get("up", 0.03)))), (0.3 - weight(v, ARM)) * W), float(row.get("off", 0.017)) + over_pack, colour, 0.5, cloth=cloth or "silk")
    elif kind == "scarf":
        piece("Scarf", "helper-tights", lambda v: min(band(v.co.z, neck - 0.05, neck + 0.03), (0.3 - weight(v, ARM)) * W, 0.078 - abs(v.co.x)), 0.014, colour, 0.8, pattern=row.get("pattern"), cloth=cloth or "silk")
    elif kind == "stole":
        # A stole, not a capelet: a long narrow wrap laid behind the neck and over the shoulders, its two tapered
        # ends falling forward over the chest, one a little longer. Built outright along a smooth path that keeps
        # `lift` off the body, so it frames the neckline instead of hiding it.
        tree_ = BVHTree.FromPolygons([tuple(v.co) for v in mesh.vertices], [tuple(q.vertices) for q in mesh.polygons])
        lift_ = float(row.get("lift", 0.022))

        def surface(point, toward):
            # The first body surface met travelling `toward`, from a metre before `point`; set off back along the ray.
            hit = tree_.ray_cast(point - toward * 1.0, toward, 2.0)
            return (hit[0] - toward * lift_) if hit[0] is not None else point

        neck_bone = bone("Neck")
        front = Vector((0, -1, 0))
        back = Vector((0, 1, 0))
        down = Vector((0, 0, -1))
        long_end = float(row.get("length", 0.36))
        path = []
        for side, extra in ((1.0, 0.0), (-1.0, float(row.get("uneven", 0.06)))):
            tip = surface(Vector((side * 0.085, 0, neck - 0.08 - long_end - extra)), back)
            low = surface(Vector((side * 0.095, 0, neck - 0.10 - (long_end + extra) * 0.5)), back)
            col = surface(Vector((side * 0.10, 0, neck - 0.07)), back)
            # Over the top of the shoulder, inboard of the joint: cast down from just above it, so the ray finds the
            # shoulder and not the head.
            above = Vector((side * shoulder.x * 0.55, neck_bone.y + 0.005, shoulder.z + 0.12))
            hit_ = tree_.ray_cast(above, down, 0.25)
            top = (hit_[0] + Vector((0, 0, lift_))) if hit_[0] is not None else above - Vector((0, 0, 0.07))
            half = [tip, low, col, top]
            path.append(half if side > 0 else list(reversed(half)))
        # Behind the neck: cast from behind, toward the front.
        nape = surface(Vector((0, neck_bone.y, neck - 0.025)), Vector((0, -1, 0)))
        points = path[0] + [nape] + path[1]

        def catmull(ps, steps=10):
            out = []
            ext = [ps[0]] + ps + [ps[-1]]
            for i in range(1, len(ext) - 2):
                p0, p1, p2, p3 = ext[i - 1], ext[i], ext[i + 1], ext[i + 2]
                for k in range(steps):
                    t = k / steps
                    out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t + (-p0 + 3 * p1 - 3 * p2 + p3) * t * t * t))
            out.append(ps[-1])
            return out
        curve = catmull(points)
        middle = len(curve) // 2

        def stole_shape(bm, curve=curve, middle=middle, r=row):
            rings = []
            n = 10
            for i, c in enumerate(curve):
                tangent = (curve[min(i + 1, len(curve) - 1)] - curve[max(i - 1, 0)]).normalized()
                axis_point = Vector((0.0, bone("Spine2").y, c.z))
                outward = c - axis_point
                outward.z = 0.0
                outward = outward.normalized() if outward.length > 1e-6 else Vector((0, -1, 0))
                outward = (outward - tangent * outward.dot(tangent)).normalized()
                across = tangent.cross(outward).normalized()
                # Widest behind the neck, tapering to the ends.
                f = 1.0 - abs(i - middle) / max(middle, 1)
                width = float(r.get("width", 0.05)) * (0.55 + 0.45 * f)
                thick = float(r.get("thick", 0.018)) * (0.6 + 0.4 * f)
                ring = []
                for k in range(n):
                    a_ = math.tau * k / n
                    ring.append(bm.verts.new(c + across * math.cos(a_) * width + outward * (math.sin(a_) * thick + thick * 0.4)))
                rings.append(ring)
            for ra, rb in zip(rings, rings[1:]):
                for k in range(n):
                    bm.faces.new((ra[k], ra[(k + 1) % n], rb[(k + 1) % n], rb[k]))
            for ring in (rings[0], rings[-1]):
                bm.faces.new(ring)

        def stole_weights(co):
            if co.z > neck - 0.04:
                return {"Neck": 0.3, "Spine2": 0.7}
            return {"Spine2": 1.0}
        piece("Stole", None, None, 0.0, colour, 0.95, pattern=row.get("pattern"), cloth=cloth or "fur", made=stole_shape, weights=stole_weights, subdivide=0)
    elif kind in ("cape", "shawl"):
        # Built outright, not cut from the body: a cone from the neck over
        # the shoulders that hangs clear of the arms. A shawl is the short
        # one, with a point down the back.
        length = float(row.get("length", 0.34 if kind == "cape" else 0.22))
        point = 0.0 if kind == "cape" else 0.12
        chest_y = bone("Spine2").y
        neck_y = bone("Neck").y

        def ease(x):
            x = max(0.0, min(1.0, x))
            return x * x * (3 - 2 * x)

        # Review of cast_r10: every cape left the shoulders bare. The cone starts 7 cm wide at the neck and
        # widens with depth, and the slope of the shoulders is wider than that for the first hand's breadth.
        # Each point is held clear of the trunk and the shoulder caps (not the arms: the cape hangs free of them).
        cape_tree = BVHTree.FromPolygons([tuple(v.co) for v in mesh.vertices], [tuple(q.vertices) for q in mesh.polygons])

        def clear_of_shoulders(point_, axis_y, room=0.024):
            axis = Vector((0.0, axis_y, point_.z))
            out_ = Vector((point_.x, point_.y - axis_y, 0.0))
            if out_.length < 1e-5:
                return point_
            way = out_.normalized()
            hit = cape_tree.ray_cast(axis + way * 0.7, -way, 0.7)
            if hit[0] is None or abs(hit[0].x) > shoulder.x + 0.03:
                return point_
            need = (Vector((hit[0].x, hit[0].y, point_.z)) - axis).length + room
            return axis + way * need if out_.length < need else point_

        def cape_shape(bm, L=length, P=point):
            rings = []
            steps = 72
            rows = 13
            for k in range(rows):
                t = k / (rows - 1.0)
                ring = []
                for j in range(steps):
                    a = math.tau * j / steps
                    back = max(0.0, math.sin(a))
                    front = max(0.0, -math.sin(a))
                    tails = ease((front - 0.5) / 0.4) if P > 0.0 else 0.0     # a shawl's two ends hang down the front
                    depth = t * (L * (0.6 + 0.5 * (0.5 + 0.5 * math.sin(a))) + P * back ** 3 + 0.9 * L * tails)
                    over = ease(depth / 0.12)
                    # Out to the point of the shoulder, then nearly straight down: flaring on as it fell, the
                    # cloth stood out round the body like a shelf. Folds deepen and the hem dips as it hangs.
                    hang = min(1.0, max(0.0, depth - 0.08) / 0.14)
                    rx = 0.068 + (shoulder.x + (0.085 if P == 0.0 else 0.06) - 0.068) * over + (0.2 if P == 0.0 else 0.14) * max(0.0, depth - 0.06)
                    swell = math.sin(a * 6.0 + 0.6 * math.sin(a * 2.0))
                    fold = 1.0 + (0.015 + 0.05 * hang) * swell
                    rx *= fold
                    ry = 0.07 + (0.165 if math.sin(a) < 0 else 0.14) * over - 0.07 * over + 0.05 * max(0.0, depth - 0.06)
                    cy = neck_y + (chest_y - neck_y) * over
                    dip = 0.014 * hang * t * (0.5 - 0.5 * swell)
                    # Room for what is worn under it: little at the neck, more over a dress's shoulders and sleeve heads.
                    ring.append(bm.verts.new(clear_of_shoulders(Vector((math.cos(a) * rx, cy + math.sin(a) * ry * fold, neck + 0.012 - depth - dip)), cy, 0.028 + 0.02 * ease(depth / 0.08))))
                rings.append(ring)
            def open_front(j):
                return P > 0.0 and -math.sin(math.tau * j / steps) > 0.94
            for upper, lower in zip(rings, rings[1:]):
                for j in range(steps):
                    if open_front(j) and open_front((j + 1) % steps):
                        continue        # a shawl is not joined down the front
                    bm.faces.new((upper[j], upper[(j + 1) % steps], lower[(j + 1) % steps], lower[j]))
            bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
            bmesh.ops.recalc_face_normals(bm, faces=bm.faces)

        def cape_weights(co):
            depth = neck + 0.012 - co.z
            side = max(0.0, min(1.0, (abs(co.x) - 0.1) / 0.1)) * max(0.0, min(1.0, depth / 0.12)) * 0.5
            out_ = {"Spine2": 1.0 - side}
            out_["LeftArm" if co.x > 0 else "RightArm"] = side
            return out_

        piece("Cape" if kind == "cape" else "Shawl", None, None, 0.0, colour, 0.85 if kind == "cape" else 0.9, pattern=row.get("pattern"), cloth=cloth or ("wool" if kind == "cape" else "knit"),
              made=cape_shape, weights=cape_weights)
    elif kind == "boots":
        piece("Boots", "helper-tights", lambda v, r=row: min(ankle + float(r.get("height", 0.16)) - v.co.z, (weight(v, LEG) - 0.3) * W), 0.011, colour, 0.35, cloth="leather")
    elif kind == "lapels":
        deep = float(row.get("vee", 0.3))
        piece("Lapels", "helper-tights", lambda v, d=deep: min((0.3 - weight(v, ARM)) * W, bone("Spine2").y - 0.02 - v.co.y, band((neck + 0.01) - v.co.z, 0.0, d),
                                 band(abs(v.co.x) - (d - ((neck + 0.01) - v.co.z)) * 0.42, 0.0, 0.05)), lapel_base(row) + 0.0045 + over_pack, colour, 0.8, cloth=cloth or "wool")
    elif kind == "trousers":
        ends = float(row.get("ends", 0.035))
        piece("Trousers", "helper-tights", lambda v, e=ends: legs(v, ankle + e - 0.02, waist + 0.02), 0.010, colour, 0.85,
              thicken=lambda co: float(row.get("width", 0.03)) * max(0.0, min(1.0, (hip - 0.08 - co.z) / (hip - 0.08 - knee))) ** 0.7, pattern=row.get("pattern"), cloth=cloth or "wool",
              reshape=lambda co, e=ends: Vector((co.x, co.y, max(co.z, ankle + e))))
        if row.get("turnups", True):
            piece("TurnUps", "helper-tights", lambda v: min(band(v.co.z, ankle + 0.035, ankle + 0.085), (0.3 - weight(v, ARM)) * W), 0.010 + float(row.get("width", 0.03)) + 0.005, colour, 0.85,
                  pattern=row.get("pattern"), cloth=cloth or "wool")
    elif kind == "brassiere":
        # A bandeau brassiere: a straight band round the whole chest, from under the bust to above it. (With an
        # armhole cut, the shoulder planes took the sides of the cups away and left a panel down the middle.)
        # `sleeves` 0 gives a cut armhole and straps instead, for a brassiere worn under something.
        under_bust = waist + (neck - waist) * float(row.get("from", 0.45))
        # Nothing of the arm: a sliver of sleeve stood on each shoulder.
        piece("Brassiere", "helper-tights", lambda v, r=row, u=under_bust: min(torso(v, low=u, high=neck - float(r.get("top", 0.13)), sleeves=float(r.get("sleeves", 0.001)),
                                                                                vee=float(r.get("vee", 0.16)), strap=float(r.get("strap", 0.012)), armpit=float(r.get("armpit", 0.09))),
                                                                                (0.3 - weight(v, ARM)) * W),
              float(row.get("ease", 0.004)), colour, 0.6, pattern=row.get("pattern"), cloth=cloth or "satin", hug=True)
    elif kind == "corset":
        # A corset from over the hips to under the bust, laced and boned: close and stiff. Or, with `top` (metres
        # below the neck) and `above_waist`, a short bustier over the bust that leaves the waist bare; `straps`
        # gives it shoulder straps.
        top = neck - float(row["top"]) if "top" in row else waist + (neck - waist) * float(row.get("to", 0.45))
        bottom = waist + float(row["above_waist"]) if "above_waist" in row else hip - float(row.get("below", 0.03))
        over_bust = "top" in row
        sx = shoulder.x * float(row.get("strap_at", 0.5))

        def corset_margin(v, r=row, t=top, lo=bottom, ob=over_bust, sx=sx):
            body = min(torso(v, low=lo, high=t, sleeves=0.001, inner=True), (0.3 - weight(v, ARM)) * W) if ob                 else torso(v, low=lo, high=t, sleeves=0.0, inner=True)
            if not r.get("straps"):
                return body
            w = float(r.get("strap_width", 0.008))
            strap = min(w - abs(abs(v.co.x) - sx), band(v.co.z, t - 0.01, neck + 0.06), (0.3 - weight(v, ARM)) * W)
            return max(body, strap)
        piece("Corset", "helper-tights", corset_margin,
              float(row.get("ease", 0.007)), colour, 0.55, pattern=row.get("pattern"), cloth=cloth or "satin", hug=True)
        if row.get("binding"):
            def binding_margin(v, r=row, t=top, lo=bottom, ob=over_bust):
                body = min(torso(v, low=lo, high=t, sleeves=0.001, inner=True), (0.3 - weight(v, ARM)) * W) if ob                     else torso(v, low=lo, high=t, sleeves=0.0, inner=True)
                return min(body, float(r.get("binding_width", 0.007)) - min(abs(v.co.z - t), abs(v.co.z - lo)))
            piece("CorsetBinding", "helper-tights", binding_margin, float(row.get("ease", 0.007)) + 0.0025, row["binding"], 0.5, cloth="satin", hug=True)
    elif kind == "briefs":
        # Step-ins or tap pants: from the waist to the top of the thigh, a little loose at the leg.
        # `cheeky`: how far the leg line rises behind, across the seat.
        # `side_cut`: how far the leg line rises over the hips at the sides (a bikini's high leg).
        def smooth01(t):
            t = max(0.0, min(1.0, t))
            return t * t * (3.0 - 2.0 * t)
        piece("Briefs", "helper-tights", lambda v, r=row: legs(v, hip - float(r.get("leg", 0.11)) + float(r.get("cheeky", 0.0)) * smooth01((v.co.y - bone("Hips").y) / 0.07)
                                                              + float(r.get("side_cut", 0.0)) * smooth01((abs(v.co.x) - 0.04) / 0.08),
                                                              waist - float(r.get("drop", 0.01))),
              float(row.get("ease", 0.005)), colour, 0.6,
              thicken=lambda co, r=row: float(r.get("width", 0.006)) * max(0.0, min(1.0, (hip - 0.04 - co.z) / 0.08)),
              pattern=row.get("pattern"), cloth=cloth or "satin")
    elif kind == "garters":
        thigh = bone("LeftUpLeg")
        tx, ty = abs(thigh.x), thigh.y
        width = float(row.get("width", 0.007))

        kx = abs(bone("LeftLeg").x)

        def strap(co, tx=tx, ty=ty, w=width, kx=kx):
            side = 1.0 if co.x >= 0.0 else -1.0
            # The thigh leans in toward the knee: the strap follows its middle down.
            tx = tx + (kx - tx) * max(0.0, min(1.0, (hip - co.z) / max(hip - knee, 1e-6)))
            # The whole front half of the thigh: stricter, the strap broke off above the stocking top.
            end = hip - float(row.get("to", 0.13)) - 0.012
            # A short tab at the clip end, a little wider than the strap.
            w = w * (1.7 if co.z < end + 0.016 else 1.0)
            front = w - abs(co.x - side * tx) if co.y < ty + 0.01 else -1.0
            rear = w - abs(co.x - side * (tx + 0.01)) if co.y > ty + 0.01 else -1.0
            return max(front, rear)
        # From a garter belt at the hip, or with `above_waist` from the hem of a short corset above the waist.
        garter_top = waist + float(row["above_waist"]) if "above_waist" in row else hip + float(row.get("from", 0.0))
        piece("Garters", "helper-tights", lambda v, r=row, g=garter_top: min(band(v.co.z, hip - float(r.get("to", 0.13)) - 0.012, g), strap(v.co),
                                                              (0.3 - weight(v, ARM)) * W),
              float(row.get("off", 0.008)), colour, 0.5, cloth=cloth or "satin")
    elif kind == "shrug":
        # A shrug: sleeves joined across the back and over the shoulders, open in front, ending above the bust.
        piece("Shrug", "helper-tights", lambda v, r=row: torso(v, low=neck - float(r.get("length", 0.2)), sleeves=float(r.get("sleeves", 0.5)),
                                                             vee=float(r.get("vee", 0.45))),
              float(row.get("ease", 0.012)), colour, 0.5, pattern=row.get("pattern"), cloth=cloth or "silk")
    elif kind == "stockings":
        piece("Stockings", "helper-tights", lambda v: legs(v, ankle - 0.08, hip - float(row.get("top", 0.1))), 0.002, colour, 0.5,
              pattern=row.get("pattern"), cloth=cloth or "silk")
        if row.get("cuff"):
            top_ = hip - float(row.get("top", 0.1))
            piece("StockingCuffs", "helper-tights", lambda v, t=top_: legs(v, t - float(row.get("cuff_depth", 0.035)), t), 0.0045, row["cuff"], 0.5, cloth="silk")
    elif kind == "skirt":
        piece(row.get("name", "Skirt"), "helper-skirt", lambda v: True, 0.009, colour, 0.85, thicken=seat_room, reshape=skirt_shape(float(row.get("hem", 0.38)), float(row.get("flare", 0.25)), int(row.get("pleats", 0))), pattern=row.get("pattern"), cloth=cloth or "wool", subdivide=1)
    elif kind == "belt":
        piece("Belt", "helper-tights", lambda v, r=row: min(0.04 - abs(v.co.z - (waist + float(r.get("drop", 0.0)))), (0.3 - weight(v, ARM)) * W), float(row.get("off", 0.0125)) + over_pack, colour, 0.4, cloth="leather")
    elif kind == "collar":
        pending_collars.append(row)
    elif kind == "cuffs":
        piece("Cuffs", "helper-tights", lambda v, r=row: min((weight(v, ARM) - 0.45) * W, (0.07 - abs(along_arm(v.co) - float(r.get("at", 0.9)))) * 0.5), float(row.get("off", 0.02)), colour, 0.8, cloth=cloth or "cotton")
    elif kind == "hem" and tucked_low is not None:
        pass        # the ribbing of a tucked jumper is inside the skirt
    elif kind == "hem":
        piece("Hem", "helper-tights", lambda v, r=row: min(0.04 - abs(v.co.z - (hip + float(r.get("drop", -0.02)))), (0.3 - weight(v, ARM)) * W), float(row.get("off", 0.021)), colour, 0.9, cloth=cloth or "knit")

DECAL_CELLS = ["patch", "darn", "pocket", "button", "flower", "brooch", "stain", "lace", "stitch", "pin", "bow", "ticket", "diamond", "leaf", "stripe", "blank"]


def decal_sheet():
    """Sixteen small drawn details, white on clear, to be tinted where used."""
    cell = 128
    sheet = numpy.zeros((cell * 4, cell * 4, 4), dtype=numpy.float32)
    ys, xs = numpy.mgrid[0:cell, 0:cell].astype(numpy.float32)
    cx = xs - cell / 2
    cy = ys - cell / 2
    radius = numpy.sqrt(cx * cx + cy * cy)
    angle = numpy.arctan2(cy, cx)
    rng = numpy.random.default_rng(3)
    drawn = {}
    box = (numpy.abs(cx) < 46) & (numpy.abs(cy) < 46)
    edge = box & ~((numpy.abs(cx) < 40) & (numpy.abs(cy) < 40))
    stitches = edge & (((xs + ys) % 10) < 5)
    drawn["patch"] = (numpy.where(stitches, 1.0, 0.82), box.astype(numpy.float32))
    oval = (cx / 44) ** 2 + (cy / 30) ** 2 < 1
    hatch = ((xs % 7) < 2) | ((ys % 7) < 2)
    drawn["darn"] = (numpy.where(hatch, 1.0, 0.7), (oval & (hatch | (rng.random((cell, cell)) > 0.5))).astype(numpy.float32))
    outline = ((numpy.abs(cx) < 44) & (cy > -36) & (cy < 48)) & ~((numpy.abs(cx) < 40) & (cy > -32) & (cy < 44))
    flap = (numpy.abs(cx) < 44) & (numpy.abs(cy + 20 - numpy.abs(cx) * 0.25) < 2.5)
    drawn["pocket"] = (numpy.ones((cell, cell)), ((outline & (((xs + ys) % 8) < 5)) | flap).astype(numpy.float32))
    holes = numpy.zeros((cell, cell), dtype=bool)
    for hx, hy in ((-9, -9), (9, -9), (-9, 9), (9, 9)):
        holes |= (cx - hx) ** 2 + (cy - hy) ** 2 < 16
    drawn["button"] = (numpy.where(radius > 30, 0.75, 1.0), ((radius < 36) & ~holes).astype(numpy.float32))
    petals = radius < 20 + 22 * numpy.abs(numpy.cos(angle * 2.5))
    drawn["flower"] = (numpy.where(radius < 11, 0.5, 1.0), petals.astype(numpy.float32))
    ring = ((cx / 34) ** 2 + (cy / 44) ** 2 < 1)
    inner = ((cx / 24) ** 2 + (cy / 34) ** 2 < 1)
    drawn["brooch"] = (numpy.where(inner, 0.45, 1.0), ring.astype(numpy.float32))
    blot = radius < 30 + 14 * numpy.sin(angle * 3 + 1.0) + 8 * numpy.sin(angle * 7)
    drawn["stain"] = (numpy.ones((cell, cell)) * 0.9, blot.astype(numpy.float32) * numpy.clip(1.2 - radius / 50, 0, 1) * 0.75)
    scallop = (cy < 10) & (cy > -30 + 26 * numpy.abs(numpy.sin(xs * numpy.pi / 32)))
    eyelets = ((xs % 32 - 16) ** 2 + (cy + 2) ** 2) < 20
    drawn["lace"] = (numpy.ones((cell, cell)), (scallop & ~eyelets).astype(numpy.float32))
    drawn["stitch"] = (numpy.ones((cell, cell)), ((numpy.abs(cy) < 2.5) & ((xs % 16) < 10)).astype(numpy.float32))
    star = radius < 16 + 20 * numpy.abs(numpy.cos(angle * 2.5)) ** 3
    drawn["pin"] = (numpy.ones((cell, cell)), star.astype(numpy.float32))
    knot = (numpy.abs(cx) < 8) & (numpy.abs(cy) < 10)
    wings = (numpy.abs(cy) < 4 + numpy.abs(cx) * 0.45) & (numpy.abs(cx) < 46)
    drawn["bow"] = (numpy.where(knot, 0.7, 1.0), (knot | wings).astype(numpy.float32))
    stub = (numpy.abs(cx) < 26) & (numpy.abs(cy) < 44) & ~((radius < 9) & (cy < -30))
    drawn["ticket"] = (numpy.where((numpy.abs(cy - 20) < 2) & (numpy.abs(cx) < 20), 0.5, 1.0), stub.astype(numpy.float32))
    drawn["diamond"] = (numpy.ones((cell, cell)), ((numpy.abs(cx) / 30 + numpy.abs(cy) / 46) < 1).astype(numpy.float32))
    leaf = ((cx / 20) ** 2 + (cy / 46) ** 2 < 1)
    drawn["leaf"] = (numpy.where(numpy.abs(cx) < 2, 0.6, 1.0), leaf.astype(numpy.float32))
    drawn["stripe"] = (numpy.ones((cell, cell)), (numpy.abs(cx) < 9).astype(numpy.float32))
    drawn["blank"] = (numpy.ones((cell, cell)), numpy.zeros((cell, cell), dtype=numpy.float32))
    for index, name in enumerate(DECAL_CELLS):
        value, alpha = drawn[name]
        row, col = index // 4, index % 4
        sheet[row * cell:(row + 1) * cell, col * cell:(col + 1) * cell, :3] = value[:, :, None]
        sheet[row * cell:(row + 1) * cell, col * cell:(col + 1) * cell, 3] = alpha
    picture = bpy.data.images.new("cast_decals", cell * 4, cell * 4, alpha=True)
    picture.pixels = sheet.ravel()
    picture.filepath_raw = os.path.join(OUT, "cast_decals.png")
    picture.file_format = "PNG"
    picture.save()
    material = bpy.data.materials.new("cast_decals")
    material.use_nodes = True
    material.blend_method = "BLEND"
    nodes = material.node_tree.nodes
    links = material.node_tree.links
    shader = nodes["Principled BSDF"]
    node = nodes.new("ShaderNodeTexImage")
    node.image = picture
    tint = nodes.new("ShaderNodeVertexColor")
    tint.layer_name = "Tint"
    mix = nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    mix.blend_type = "MULTIPLY"
    mix.inputs[0].default_value = 1.0
    links.new(node.outputs[0], mix.inputs[6])
    links.new(tint.outputs[0], mix.inputs[7])
    links.new(mix.outputs[2], shader.inputs["Base Color"])
    links.new(node.outputs[1], shader.inputs["Alpha"])
    shader.inputs["Roughness"].default_value = 0.85
    return material


DECAL_ANCHORS = {
    "chest_l": lambda: (Vector((0.075, -1.0, neck - 0.13)), Vector((0, 1, 0))),
    "chest_r": lambda: (Vector((-0.075, -1.0, neck - 0.13)), Vector((0, 1, 0))),
    "lapel_l": lambda: (Vector((0.06, -1.0, neck - 0.08)), Vector((0, 1, 0))),
    "throat": lambda: (Vector((0.0, -1.0, neck - 0.045)), Vector((0, 1, 0))),
    "belly": lambda: (Vector((0.03, -1.0, waist + 0.02)), Vector((0, 1, 0))),
    "hip_l": lambda: (Vector((0.1, -1.0, hip + 0.03)), Vector((0, 1, 0))),
    "hip_r": lambda: (Vector((-0.1, -1.0, hip + 0.03)), Vector((0, 1, 0))),
    "knee_l": lambda: (Vector((0.09, -1.0, knee + 0.01)), Vector((0, 1, 0))),
    "knee_r": lambda: (Vector((-0.09, -1.0, knee + 0.01)), Vector((0, 1, 0))),
    "thigh_l": lambda: (Vector((0.1, -1.0, hip - 0.16)), Vector((0, 1, 0))),
    "shin_r": lambda: (Vector((-0.09, -1.0, knee - 0.14)), Vector((0, 1, 0))),
    "elbow_l": lambda: (Vector((elbow.x, 1.0, elbow.z)), Vector((0, -1, 0))),
    "elbow_r": lambda: (Vector((-elbow.x, 1.0, elbow.z)), Vector((0, -1, 0))),
    "seat": lambda: (Vector((0.07, 1.0, hip - 0.05)), Vector((0, -1, 0))),
    "back": lambda: (Vector((0.0, 1.0, neck - 0.16)), Vector((0, -1, 0))),
}
decal_material = None
decal_rows = [dict(row) for row in (CFG.get("trim", []) if OUTFIT else []) if row.get("kind") == "decal"]
by_part = {}
for row in decal_rows:
    by_part.setdefault(row.get("_part", ""), []).append(row)
for part_name, rows_ in by_part.items():
    mine = [g for g in garments if g.get("part", "") == part_name and g.type == "MESH" and len(g.data.polygons)]
    if not mine:
        continue
    points_, polys_, start_ = [], [], 0
    for g in mine:
        points_ += [tuple(v.co) for v in g.data.vertices]
        polys_ += [tuple(i + start_ for i in q.vertices) for q in g.data.polygons]
        start_ += len(g.data.vertices)
    cloth_here = BVHTree.FromPolygons(points_, polys_)
    bm = bmesh.new()
    uv_layer = bm.loops.layers.uv.verify()
    tint_layer = bm.loops.layers.color.new("Tint")
    for row in rows_:
        origin, direction = DECAL_ANCHORS[row["at"]]()
        origin = origin + Vector((float(row.get("dx", 0.0)), 0.0, float(row.get("dz", 0.0))))
        hit = cloth_here.ray_cast(origin, direction, 3.0)
        if hit[0] is None:
            continue
        normal = hit[1].normalized()
        if normal.dot(direction) > 0:
            normal = -normal
        up = Vector((0, 0, 1)) - normal * normal.z
        up = up.normalized() if up.length > 1e-5 else Vector((0, 1, 0))
        right = up.cross(normal).normalized()
        turn = math.radians(float(row.get("turn", 0.0)))
        up, right = up * math.cos(turn) + right * math.sin(turn), right * math.cos(turn) - up * math.sin(turn)
        half = float(row.get("size", 0.05)) * 0.5
        wide = half * float(row.get("wide", 1.0))
        centre = hit[0] + normal * 0.0025
        index = DECAL_CELLS.index(row["cell"])
        u0, v0 = (index % 4) / 4.0, (index // 4) / 4.0  # the sheet's first row is the picture's bottom row
        corners = [(-wide, -half, u0, v0), (wide, -half, u0 + 0.25, v0), (wide, half, u0 + 0.25, v0 + 0.25), (-wide, half, u0, v0 + 0.25)]
        face = bm.faces.new([bm.verts.new(centre + right * a + up * b) for a, b, _, _ in corners])
        colour = worn_colour(row.get("colour", [0.9, 0.88, 0.8]))
        for loop, (_, _, u, v) in zip(face.loops, corners):
            loop[uv_layer].uv = (u, v)
            loop[tint_layer] = (colour[0], colour[1], colour[2], 1.0)
    if not bm.faces:
        bm.free()
        continue
    if decal_material is None:
        decal_material = decal_sheet()
    decal_mesh = bpy.data.meshes.new("Decals")
    bm.to_mesh(decal_mesh)
    bm.free()
    decals = bpy.data.objects.new("Decals_" + part_name, decal_mesh)
    bpy.context.scene.collection.objects.link(decals)
    decals.data.materials.append(decal_material)
    # A detail rides on the cloth it lies on: weighted as the nearest point of that cloth.
    decals.parent = rig
    decals.modifiers.new("Armature", "ARMATURE").object = rig
    transfer = decals.modifiers.new("Weights", "DATA_TRANSFER")
    transfer.object = mine[0]
    transfer.use_vert_data = True
    transfer.data_types_verts = {"VGROUP_WEIGHTS"}
    transfer.vert_mapping = "NEAREST"
    bpy.context.view_layer.objects.active = decals
    for group_name in [g.name for g in mine[0].vertex_groups]:
        decals.vertex_groups.new(name=group_name)
    bpy.ops.object.modifier_move_to_index(modifier="Weights", index=0)
    bpy.ops.object.modifier_apply(modifier="Weights")
    decals["part"] = part_name
    garments.append(decals)
    print("DECALS", part_name, len(decal_mesh.polygons))

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
        out_ = float(row.get("out", 0.0))
        rings.append((bm.verts.new(base + direction * 0.005 + Vector((0, 0, 0.014))),
                      bm.verts.new(base + direction * (0.016 + out_) + Vector((0, 0, 0.01))),
                      bm.verts.new(base + direction * (0.03 + out_ + 0.012 * front) + Vector((0, 0, -fall)))))
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
    collar["part"] = row.get("_part", "")
    garments.append(collar)


def chest_front(z, x=0.0, lift=0.02):
    hit = body_tree.ray_cast(Vector((x, -1.0, z)), Vector((0, 1, 0)), 2.0)
    return hit[0] + Vector((0, -lift, 0)) if hit[0] is not None else None


small = bmesh.new()
small_material_rows = []
trim_face_slot = {}
for row in (CFG.get("trim", []) if OUTFIT else []):
    if row.get("kind") == "decal":
        continue
    faces_before = len(small.faces)
    trim_part = row.get("_part", "")
    covered = under_outer_layer(trim_part)
    # What trims an outer layer that stands off a pack garment stands off with it (lapels, buttons, pockets).
    trim_off = 0.012 if trim_part.endswith("_over") and any(o["kind"] == "asset" and not o.get("_part", "").endswith(("_feet", "_head")) and o.get("_part", "")[:1] == trim_part[:1] for o in CFG.get("outfit", [])) else 0.0
    if row["kind"] == "buttons":
        z = neck - 0.06
        own_foot = v_foot(trim_part)
        if own_foot is not None:
            # Review: buttons floated on the jersey inside the open V. They begin where the garment closes.
            z = min(z, own_foot - 0.028)
        while z > waist - 0.02 - float(row.get("below", 0.0)):
            # A button sits on the cloth it fastens: the layer's own stand-off, not a fixed figure.
            at = chest_front(z, lift=max(float(row.get("lift", 0.016)), (layer_off(trim_part) or 0.0) + 0.001) + trim_off) if not covered(0.0, z) else None
            if at is not None:
                made = bmesh.ops.create_uvsphere(small, u_segments=10, v_segments=6, radius=float(row.get("size", 0.008)))
                for v in made["verts"]:
                    v.co = Vector((v.co.x, v.co.y * 0.45, v.co.z)) + at
            z -= float(row.get("step", 0.07))
        small_material_rows.append(("Buttons", row["colour"], row.get("_part", "")))
    elif row["kind"] == "braces":
        for side in (1.0, -1.0):
            strip = []
            for k in range(9):
                z = waist + (neck - 0.07 - waist) * k / 8.0
                x = side * (0.075 - 0.02 * k / 8.0)
                at = chest_front(z, x=x, lift=float(row.get("lift", 0.012))) if not covered(x, z) else None
                strip.append((small.verts.new(at + Vector((-0.011, 0, 0))), small.verts.new(at + Vector((0.011, 0, 0)))) if at is not None else None)
            for a, b in zip(strip, strip[1:]):
                if a is not None and b is not None:
                    small.faces.new((a[0], a[1], b[1], b[0]))
        small_material_rows.append(("Braces", row["colour"], row.get("_part", "")))
    elif row["kind"] == "pearls":
        # A long rope of pearls: down from either side of the neck to a point at the waist.
        drop = float(row.get("drop", 0.3))
        bead = float(row.get("size", 0.0042))
        count = int((0.11 + 2.0 * drop) / (bead * 2.3))
        for k in range(count + 1):
            s = -1.0 + 2.0 * k / count
            x = 0.058 * s * (1.0 - 0.25 * (1.0 - abs(s)))
            z = neck - 0.018 - drop * (1.0 - abs(s) ** 1.5)
            at = chest_front(z, x=x, lift=float(row.get("lift", 0.012)) + trim_off)
            if at is not None:
                made = bmesh.ops.create_uvsphere(small, u_segments=8, v_segments=5, radius=bead)
                for v in made["verts"]:
                    v.co = v.co + at
        small_material_rows.append(("Pearls", row["colour"], row.get("_part", "")))
    elif row["kind"] == "corsage":
        # A rose pinned at the shoulder: a heart and a ring of petals.
        side = float(row.get("side", 1.0))
        at = chest_front(shoulder.z - float(row.get("down", 0.05)), x=side * shoulder.x * float(row.get("out", 0.5)), lift=float(row.get("lift", 0.016)) + trim_off)
        if at is not None:
            size = float(row.get("size", 0.013))
            if row.get("flower") == "lily":
                # A lily: six long pointed petals opening outward from a narrow throat, their tips curling back.
                for k in range(6):
                    turn = math.tau * k / 6.0 + 0.2
                    way_ = Vector((math.cos(turn), 0.0, math.sin(turn)))
                    across_ = Vector((-math.sin(turn), 0.0, math.cos(turn)))
                    made = bmesh.ops.create_uvsphere(small, u_segments=10, v_segments=6, radius=1.0)
                    for v in made["verts"]:
                        along_ = v.co.x * 0.5 + 0.5
                        wide_ = v.co.z * size * 0.42 * math.sin(math.pi * min(1.0, along_ * 0.9 + 0.1)) ** 0.8
                        v.co = at + way_ * (0.003 + along_ * size * 2.6) + across_ * wide_ + Vector((0.0, -0.012 * math.sin(math.pi * along_ * 0.85) + v.co.y * 0.002, 0.0))
                made = bmesh.ops.create_uvsphere(small, u_segments=8, v_segments=5, radius=size * 0.3)
                for v in made["verts"]:
                    v.co = v.co + at + Vector((0.0, -0.008, 0.0))
            else:
                for k in range(8):
                    turn = math.tau * k / 7.0
                    reach = 0.0 if k == 7 else size * 1.05
                    made = bmesh.ops.create_uvsphere(small, u_segments=8, v_segments=5, radius=size * (0.8 if k == 7 else 1.0))
                    for v in made["verts"]:
                        v.co = Vector((v.co.x, v.co.y * 0.55, v.co.z)) + at + Vector((math.cos(turn) * reach, -0.004 if k == 7 else 0.0, math.sin(turn) * reach))
        small_material_rows.append(("Corsage", row["colour"], row.get("_part", "")))
    elif row["kind"] == "bow":
        at = chest_front(neck - 0.045, lift=float(row.get("lift", 0.022)))
        if at is not None:
            for side in (1.0, -1.0):
                small.faces.new([small.verts.new(at + Vector((dx * side, 0, dz))) for dx, dz in ((0.0, 0.006), (0.04, 0.018), (0.04, -0.018), (0.0, -0.006))])
        small_material_rows.append(("Bow", row["colour"], row.get("_part", "")))
    elif row["kind"] == "pockets":
        for side in (1.0, -1.0):
            at = chest_front(hip + float(row.get("up", 0.05)), x=side * 0.09, lift=float(row.get("lift", 0.027)) + trim_off) if not covered(side * 0.09, hip + float(row.get("up", 0.05))) else None
            if at is None:
                continue
            w_, h_ = 0.04, 0.014
            quad = [small.verts.new(at + Vector((dx, 0, dz))) for dx, dz in ((-w_, h_), (w_, h_), (w_, -h_), (-w_, -h_))]
            small.faces.new(quad)
        small_material_rows.append(("Pockets", row["colour"], row.get("_part", "")))
    elif row["kind"] == "tie":
        top = neck - 0.035
        length = float(row.get("length", 0.3))
        rings = []
        for k in range(9):
            t = k / 8.0
            z = top - t * length
            at = chest_front(z, lift=0.021) if not covered(0.0, z) else None
            half = 0.014 + 0.02 * math.sin(min(t * 1.25, 1.0) * math.pi * 0.5) if t < 0.86 else 0.03 * (1.0 - t) / 0.14
            rings.append((small.verts.new(at + Vector((-half, 0, 0))), small.verts.new(at + Vector((half, 0, 0)))) if at is not None else None)
        for a, b in zip(rings, rings[1:]):
            if a is not None and b is not None:
                small.faces.new((a[0], a[1], b[1], b[0]))
        small_material_rows.append(("Tie", row["colour"], row.get("_part", "")))
    small.faces.ensure_lookup_table()
    for index_ in range(faces_before, len(small.faces)):
        trim_face_slot[index_] = len(small_material_rows) - 1
if small.verts:
    small.faces.ensure_lookup_table()
    small_mesh = bpy.data.meshes.new("Trim")
    bmesh.ops.recalc_face_normals(small, faces=small.faces)
    small.to_mesh(small_mesh)
    trim = bpy.data.objects.new("Trim", small_mesh)
    bpy.context.scene.collection.objects.link(trim)
    for label_, colour_, part_name in small_material_rows:
        trim.data.materials.append(plain("%s_%s_%d" % (CID, label_.lower(), len(trim.data.materials)), colour_, 0.35))
    for polygon in small_mesh.polygons:
        polygon.material_index = min(trim_face_slot.get(polygon.index, 0), len(small_material_rows) - 1)
    trim.vertex_groups.new(name=PREFIX + "Spine2").add(list(range(len(small_mesh.vertices))), 1.0, "REPLACE")
    trim.parent = rig
    trim.modifiers.new("Armature", "ARMATURE").object = rig
    # One object per kind of trim, so each goes with the part it trims.
    for slot_index, (label_, colour_, part_name) in enumerate(small_material_rows):
        twin = trim.copy()
        twin.data = trim.data.copy()
        twin.name = "Trim_%s_%d" % (label_, slot_index)
        bpy.context.scene.collection.objects.link(twin)
        bm_ = bmesh.new()
        bm_.from_mesh(twin.data)
        bmesh.ops.delete(bm_, geom=[f for f in bm_.faces if f.material_index != slot_index], context="FACES")
        bmesh.ops.delete(bm_, geom=[v for v in bm_.verts if not v.link_faces], context="VERTS")
        bm_.to_mesh(twin.data)
        bm_.free()
        twin["part"] = part_name
        if len(twin.data.polygons):
            garments.append(twin)
    bpy.data.objects.remove(trim)
small.free()

# ---------------------------------------------------------------- the body itself
torso_seed = [v.co.copy() for v in mesh.vertices if in_group(v, "body") and waist - 0.2 < v.co.z < neck + 0.03 and abs(v.co.x) < 0.2 and weight(v, ARM) < 0.35][::3]
skin_parts = []
if not OUTFIT:
    neck_cut = neck - 0.03
    # The whole body, in parts with no gaps between them: every face of the
    # body belongs to exactly one part. A part is hidden in the game only
    # under a garment that fits closely over it; under a skirt, a gown or an
    # open coat the body is there.
    # Shares, not raw weights: the base's palm and the back of its hand carry
    # only a fifth of a full weight in all, and by raw weight they fell out of
    # the hand and were hidden with the trunk.
    bone_names = {b.name for b in rig.data.bones}

    def share(v, fragments):
        total = sum(g.weight for g in v.groups if names[g.group] in bone_names)
        return weight(v, fragments) / total if total > 1e-6 else 0.0

    rules = [
        ("hands", lambda v: share(v, ("Hand",)) > 0.25),
        ("arms", lambda v: share(v, ARM) > 0.45),
        ("head", lambda v: v.co.z > neck_cut),
        ("feet", lambda v: share(v, ("Foot", "Toe")) > 0.5 and v.co.z < ankle + 0.02),
        ("legs", lambda v: share(v, LEG) > 0.5 and v.co.z < hip - 0.1),
        ("chest", lambda v: v.co.z <= neck_cut + 0.012 and v.co.y < bone("Spine2").y - 0.01 and weight(v, ARM) < 0.3
            and abs(v.co.x) < (0.2 - ((neck + 0.01) - v.co.z)) * 0.42 + 0.006),
        ("hips", lambda v: v.co.z < waist - 0.12),
        ("trunk", lambda v: True),
    ]
    label_of = {}
    for v in human.data.vertices:
        if not in_group(v, "body"):
            continue
        for label, rule in rules:
            if rule(v):
                label_of[v.index] = label
                break
    face_label = {}
    for poly in human.data.polygons:
        labels = [label_of.get(i) for i in poly.vertices]
        if None in labels:
            continue
        face_label[poly.index] = max(labels, key=lambda l: (labels.count(l), -labels.index(l)))
    # The body is one surface cut into parts. Each part keeps the whole body's normals, or every cut
    # shows as a row of flat facets (it did, round the base of the neck).
    whole_normals = [tuple(v.normal) for v in human.data.vertices]
    for label, rule in rules:
        twin = human.copy()
        twin.data = human.data.copy()
        twin.name = "Skin_" + label
        bpy.context.scene.collection.objects.link(twin)
        if label != "head":
            twin.shape_key_clear()
        bm = bmesh.new()
        bm.from_mesh(twin.data)
        bm.faces.ensure_lookup_table()
        came_from = bm.verts.layers.int.new("came_from")
        for v in bm.verts:
            v[came_from] = v.index
        bmesh.ops.delete(bm, geom=[f for f in bm.faces if face_label.get(f.index) != label], context="FACES")
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
        bm.to_mesh(twin.data)
        bm.free()
        kept = [0] * len(twin.data.vertices)
        twin.data.attributes["came_from"].data.foreach_get("value", kept)
        twin.data.attributes.remove(twin.data.attributes["came_from"])
        twin.data.normals_split_custom_set_from_vertices([whole_normals[i] for i in kept])
        skin_parts.append(twin)
        print("SKIN part", label, len(twin.data.polygons))

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
eye_node, _ = base_image(parts[0]) if parts else (None, None)
if eye_node is not None and os.path.exists(eye_file):
    eye_node.image = bpy.data.images.load(eye_file)
    if CFG.get("eyes", "brown") == "brown":
        # The pack's brown iris is maroon: in the engine brown eyes read as red. See art/tools/cast_eye_colour.py.
        sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "tools"))
        from cast_eye_colour import true_brown
        wide, tall = eye_node.image.size
        eye_data = numpy.empty(wide * tall * 4, dtype=numpy.float32)
        eye_node.image.pixels.foreach_get(eye_data)
        eye_data = eye_data.reshape(tall, wide, 4)
        eye_data[..., :3] = true_brown(eye_data[..., :3])
        brown_eye = bpy.data.images.new("brown_eye", wide, tall, alpha=True)
        brown_eye.pixels.foreach_set(eye_data.ravel())
        brown_eye.filepath_raw = os.path.join(OUT, "brown_eye.png")
        brown_eye.file_format = "PNG"
        brown_eye.save()
        eye_node.image = brown_eye

# ---------------------------------------------------------------- hair
head_at = bone("Head")
front = [v.co for v in mesh.vertices if abs(v.co.x) < 0.012 and head_at.z - 0.02 < v.co.z < head_at.z + 0.12]
nose = min(front, key=lambda p: p.y).copy()
# The brow is measured up from the eyes, not the nose: on the men's longer faces a brow guessed from the
# nose sat at the eye, and their hats came down over their eyes.
BROW_Z = (EYE_TOP_Z if EYE_TOP_Z is not None else nose.z + 0.044) + 0.022
print("BROW", round(BROW_Z - nose.z, 4), "above the nose")
hair_tone = numpy.array(CFG["hair"]["colour"], dtype=numpy.float32)
mid_y = nose.y + 0.1
skull_mid = Vector((0.0, mid_y, nose.z + 0.055))
hairline = nose.z + float(CFG["hair"].get("hairline_above_nose", 0.086))
extras = []


def scalp(q):
    if PACK_HAIR:
        # Under modelled hair only the crown and back are capped: a cap down to the hairline showed as a band on the forehead.
        return q.z > nose.z + 0.135 or (q.y > mid_y + 0.035 and q.z > nose.z + 0.03)
    if q.y < mid_y - 0.015:
        return q.z > hairline - max(0.0, abs(q.x) - 0.035) * 0.55
    if q.y < mid_y + 0.02:
        return q.z > nose.z + 0.04
    return q.z > nose.z - 0.04


# A close cap in the hair's colour under the strands, so no scalp shows through.
bm = bmesh.new()
bm.from_mesh(mesh)
bm.verts.ensure_lookup_table()
# Any corner inside keeps the face: asking for all of them left teeth along the parting.
keep_faces = [f for f in bm.faces if (all if PACK_HAIR else any)(scalp(v.co) for v in f.verts)]
bmesh.ops.delete(bm, geom=[f for f in bm.faces if f not in set(keep_faces)], context="FACES")
bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
bm.normal_update()
for v in bm.verts:
    v.co = v.co + v.normal * 0.0045
cap_mesh = bpy.data.meshes.new("HairCap")
bm.to_mesh(cap_mesh)
bm.free()
while cap_mesh.shape_keys:
    break
cap = bpy.data.objects.new("HairCap", cap_mesh)
bpy.context.scene.collection.objects.link(cap)
cap.data.materials.clear()
cap_material = bpy.data.materials.new(CID + "_hair_cap")
cap_material.use_nodes = True
cap_material.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (*[float(c) * (0.95 if PACK_HAIR else 0.42) for c in hair_tone], 1.0)
cap_material.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.7
cap.data.materials.append(cap_material)
cap.vertex_groups.new(name=PREFIX + "Head").add(list(range(len(cap_mesh.vertices))), 1.0, "REPLACE")
cap.parent = rig
cap.modifiers.new("Armature", "ARMATURE").object = rig
if PACK_HAIR:
    for modifier in [m for m in pack_hair.modifiers if m.type in ("SUBSURF", "MASK")]:
        pack_hair.modifiers.remove(modifier)
    hair_node, hair_image = base_image(pack_hair)
    if hair_image is not None:
        hair_node.image = tinted_image(hair_image, [float(c) for c in hair_tone], CID + "_hair_picture", 1024, hair=True)
    shrink_pictures(pack_hair, hair_node)
    if CFG["hair"].get("clip"):
        # A pin in the gathered hair, above the right ear.
        side_points = [v.co for v in pack_hair.data.vertices if nose.z + 0.045 < v.co.z < nose.z + 0.085 and mid_y - 0.05 < v.co.y < mid_y + 0.0 and v.co.x < 0]
        if side_points:
            at = min(side_points, key=lambda q: q.x)
            bm_clip = bmesh.new()
            bmesh.ops.create_cube(bm_clip, size=1.0)
            for v in bm_clip.verts:
                v.co = Vector((at.x - 0.001 + v.co.x * 0.004, at.y + v.co.y * 0.032, at.z + v.co.z * 0.009 - v.co.y * 0.012))
            clip_mesh = bpy.data.meshes.new("HairClip")
            bm_clip.to_mesh(clip_mesh)
            bm_clip.free()
            clip = bpy.data.objects.new("HairClip", clip_mesh)
            bpy.context.scene.collection.objects.link(clip)
            clip.data.materials.append(plain(CID + "_hair_clip", CFG["hair"].get("clip_colour", [0.75, 0.62, 0.3]), 0.3, 1.0))
            clip.vertex_groups.new(name=PREFIX + "Head").add(list(range(len(clip_mesh.vertices))), 1.0, "REPLACE")
            clip.parent = rig
            clip.modifiers.new("Armature", "ARMATURE").object = rig
            extras.append(clip)
    skull_tree = BVHTree.FromPolygons([tuple(v.co) for v in mesh.vertices], [tuple(q.vertices) for q in mesh.polygons])
    under_hat = pack_hair.copy()
    under_hat.data = pack_hair.data.copy()
    under_hat.name = "HatHair"
    bpy.context.scene.collection.objects.link(under_hat)
    hat_line = nose.z + 0.045
    for v in under_hat.data.vertices:
        press = max(0.0, min(1.0, (v.co.z - hat_line) / 0.03))
        if press <= 0.0:
            continue
        hit = skull_tree.find_nearest(v.co)
        if hit[0] is not None:
            v.co = v.co.lerp(hit[0] + hit[1] * 0.004, press)
    parts.append(under_hat)
    CFG["hair"]["style"] = "short"
if CARD_HAIR:
    bpy.data.objects.remove(cap, do_unlink=True)
    with bpy.data.libraries.load(CARD_HAIR) as (found, wanted):
        wanted.objects = [n for n in found.objects if n in ("HairCards", "HairUnderCap")]
    skull_tree = BVHTree.FromPolygons([tuple(v.co) for v in mesh.vertices], [tuple(q.vertices) for q in mesh.polygons])
    band_z = BROW_Z + 0.014        # inside the crown of every kind of hat built below, low beret or high derby
    worn_hair = [(o, {"HairCards": "Hair", "HairUnderCap": "HairCap"}[o.name.split(".")[0]]) for o in wanted.objects]
    for made, worn_name in list(worn_hair):
        if worn_name == "HairCap":
            # Close to the head above the band, so a low hat's crown clears it.
            for v in made.data.vertices:
                press = max(0.0, min(1.0, (v.co.z - band_z) / 0.02))
                hit = skull_tree.find_nearest(v.co) if press > 0.0 else (None,)
                if hit[0] is not None:
                    v.co = v.co.lerp(hit[0] + hit[1] * 0.0015, press)
            continue
        # The same hair as worn under a hat. Nothing inside the crown is seen, so it is cut away at the band;
        # just below the band the hair is drawn in to the head, so it comes out from under the hat.
        under = made.copy()
        under.data = made.data.copy()
        bm_hat = bmesh.new()
        bm_hat.from_mesh(under.data)
        gone = [f for f in bm_hat.faces if all(v.co.z > band_z + 0.006 for v in f.verts)]
        bmesh.ops.delete(bm_hat, geom=gone, context="FACES")
        bmesh.ops.delete(bm_hat, geom=[v for v in bm_hat.verts if not v.link_faces], context="VERTS")
        for v in bm_hat.verts:
            press = max(0.0, min(1.0, (v.co.z - (band_z - 0.03)) / 0.03))
            hit = skull_tree.find_nearest(v.co) if press > 0.0 else (None,)
            if hit[0] is not None:
                v.co = v.co.lerp(hit[0] + hit[1] * 0.002, press)
        bm_hat.to_mesh(under.data)
        bm_hat.free()
        worn_hair.append((under, "HatHair"))
    for made, worn_name in sorted(worn_hair, key=lambda pair: pair[1]):
        made.name = worn_name
        bpy.context.scene.collection.objects.link(made)
        made.vertex_groups.new(name=PREFIX + "Head").add(list(range(len(made.data.vertices))), 1.0, "REPLACE")
        made.parent = rig
        made.modifiers.new("Armature", "ARMATURE").object = rig
        parts.append(made)
    # The settings this head of hair was reviewed under go with the body, for the game to set on its shader.
    look_file = os.path.join(os.path.dirname(CARD_HAIR), CID + "_hair_look.json")
    if os.path.exists(look_file):
        import shutil
        shutil.copyfile(look_file, os.path.join(OUT, CID + "_hair_look.json"))
    print("CARD HAIR", CARD_HAIR)
elif OUTFIT or CFG["hair"].get("set") != "pinned":
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
PINNED = (not OUTFIT) and CFG["hair"].get("set") == "pinned" and not CARD_HAIR      # card hair replaces the modelled set
if OUTFIT or PACK_HAIR or PINNED or CARD_HAIR:
    STYLE["guides"] = 8  # an outfit's file carries no hair; do not spend time on it
head_tree = BVHTree.FromPolygons([tuple(v.co) for v in mesh.vertices], [tuple(q.vertices) for q in mesh.polygons])
cloth_points = [tuple(g.matrix_world @ v.co) for g in garments for v in g.data.vertices]
cloth_polys = []
start = 0
for g in garments:
    cloth_polys += [tuple(i + start for i in q.vertices) for q in g.data.polygons]
    start += len(g.data.vertices)
cloth_tree = BVHTree.FromPolygons(cloth_points, cloth_polys) if cloth_polys else body_tree
cloth_margin = 0.014 if cloth_polys else 0.034
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
        strand.append(hit[0] + direction * ((0.004 + 0.007 * math.sin(t * math.pi * 0.9)) if short_cut else (0.005 + 0.012 * t + float(CFG["hair"].get("lift", 0.0)) * (1.0 - (1.0 - t) ** 3))))
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
                if (where - near[0]).dot(near[1]) < cloth_margin:
                    where = near[0] + near[1] * (cloth_margin + 0.002)
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
torso_points = [Vector(p) for p in cloth_points if waist - 0.2 < p[2] < neck + 0.03 and abs(p[0]) < 0.24][::3] if cloth_points else torso_seed
body_collider = hull(CID + "_body_collider", torso_points, PREFIX + "Spine2", 0.97 if cloth_points else 1.12)

def on_head(obj):
    obj.vertex_groups.new(name=PREFIX + "Head").add(list(range(len(obj.data.vertices))), 1.0, "REPLACE")
    obj.parent = rig
    obj.modifiers.new("Armature", "ARMATURE").object = rig
    extras.append(obj)


if PINNED:
    # A set of the late twenties, modelled outright: hair waved close over the
    # head and ears, gathered low at the nape into a cluster of pin curls, and
    # a clip above one ear.
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bm.verts.ensure_lookup_table()
    ear = lambda q: q.z < nose.z + 0.05 and abs(q.x) > 0.067 and abs(q.y - mid_y) < 0.04
    wanted = [f for f in bm.faces if any(scalp(v.co) for v in f.verts) and not any(ear(v.co) for v in f.verts)]
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if f not in set(wanted)], context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    for _ in range(14):
        moved = {}
        for v in bm.verts:
            beside = [e.other_vert(v) for e in v.link_edges if e.is_boundary]
            if len(beside) == 2:
                moved[v] = v.co * 0.5 + (beside[0].co + beside[1].co) * 0.25
        for v, co in moved.items():
            v.co = co
    bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=1, use_grid_fill=True, smooth=1.0)
    bm.normal_update()
    # How far each point is from the hairline, in rings: the edge lies on the skin, the rest stands off it.
    ring = {v: 0 for v in bm.verts if v.is_boundary}
    edge_front = list(ring)
    for step_ in range(1, 4):
        following = []
        for v in edge_front:
            for e in v.link_edges:
                other = e.other_vert(v)
                if other not in ring:
                    ring[other] = step_
                    following.append(other)
        edge_front = following
    crown_z = max(v.co.z for v in bm.verts)
    for v in bm.verts:
        rise = (0.12, 0.5, 0.82, 0.95)[ring[v]] if v in ring else 1.0
        side = max(0.0, min(1.0, (abs(v.co.x) - 0.025) / 0.03)) * max(0.0, min(1.0, (crown_z - 0.012 - v.co.z) / 0.03))
        wave = math.sin(v.co.z * 105.0 + 2.2 * math.sin(v.co.y * 40.0))
        top = max(0.0, min(1.0, (v.co.z - (nose.z + 0.095)) / 0.05))
        v.co = v.co + v.normal * rise * (0.010 + 0.006 * top + 0.0042 * wave * side)
    hair_faces = len(bm.faces)

    def ring_of(centre, axis, major, minor, around=16, across=8):
        axis = axis.normalized()
        first = axis.cross(Vector((0, 0, 1)))
        first = first.normalized() if first.length > 1e-4 else Vector((1, 0, 0))
        second = axis.cross(first).normalized()
        loops_ = []
        for i in range(around):
            a = math.tau * i / around
            out_ = first * math.cos(a) + second * math.sin(a)
            loops_.append([bm.verts.new(centre + out_ * (major + minor * math.cos(math.tau * j / across)) + axis * (minor * math.sin(math.tau * j / across))) for j in range(across)])
        for i in range(around):
            for j in range(across):
                bm.faces.new((loops_[i][j], loops_[(i + 1) % around][j], loops_[(i + 1) % around][(j + 1) % across], loops_[i][(j + 1) % across]))

    back_way = Vector((0.0, 1.0, -0.6)).normalized()
    nape = head_tree.ray_cast(skull_mid, back_way, 0.4)[0]
    if nape is not None:
        right_ = Vector((1, 0, 0))
        up_ = back_way.cross(right_).normalized()
        if up_.z < 0:
            up_ = -up_
        # The gathered mass, then the pin curls lying on it.
        made_ = bmesh.ops.create_uvsphere(bm, u_segments=18, v_segments=10, radius=1.0)
        for v in made_["verts"]:
            v.co = nape + back_way * 0.014 + right_ * v.co.x * 0.06 + up_ * v.co.y * 0.034 + back_way * v.co.z * 0.028
        for dx, dz in ((-0.043, 0.006), (-0.022, 0.02), (0.0, 0.024), (0.022, 0.02), (0.043, 0.006), (-0.03, -0.014), (0.0, -0.012), (0.03, -0.014), (-0.011, 0.004), (0.012, 0.003)):
            lift_ = 0.036 - (dx * dx) * 9.0 - (dz * dz) * 10.0
            lean = (back_way + right_ * dx * 6.0 + up_ * dz * 6.0).normalized()
            ring_of(nape + back_way * lift_ + right_ * dx + up_ * dz, lean, 0.0125, 0.0062)
    for f in bm.faces:
        f.smooth = True
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    set_mesh = bpy.data.meshes.new("HairSet")
    bm.to_mesh(set_mesh)
    bm.free()
    hair_set = bpy.data.objects.new("HairSet", set_mesh)
    bpy.context.scene.collection.objects.link(hair_set)
    # Combed strands as a picture: fine streaks running with the hair.
    streaks = numpy.random.default_rng(7).random(256).astype(numpy.float32)
    for _ in range(3):
        streaks = (numpy.roll(streaks, 1) + streaks * 2.0 + numpy.roll(streaks, -1)) / 4.0
    streaks = 0.38 + 0.5 * (streaks - streaks.min()) / max(float(streaks.max() - streaks.min()), 1e-4)
    grid_ = numpy.ones((32, 256, 4), dtype=numpy.float32)
    grid_[:, :, :3] = numpy.clip(streaks[None, :, None] * hair_tone[None, None, :], 0.0, 1.0)
    picture_ = bpy.data.images.new(CID + "_hair_set", 256, 32, alpha=True)
    picture_.pixels.foreach_set(grid_.ravel())
    picture_.filepath_raw = os.path.join(OUT, CID + "_hair_set.png")
    picture_.file_format = "PNG"
    picture_.save()
    set_material = bpy.data.materials.new(CID + "_hair_set")
    set_material.use_nodes = True
    shader_ = set_material.node_tree.nodes["Principled BSDF"]
    image_node = set_material.node_tree.nodes.new("ShaderNodeTexImage")
    image_node.image = picture_
    set_material.node_tree.links.new(image_node.outputs["Color"], shader_.inputs["Base Color"])
    shader_.inputs["Roughness"].default_value = 0.5
    hair_set.data.materials.append(set_material)
    set_uv = set_mesh.uv_layers.new(name="Hair")
    for polygon in set_mesh.polygons:
        for loop_index in polygon.loop_indices:
            co = set_mesh.vertices[set_mesh.loops[loop_index].vertex_index].co
            if polygon.index < hair_faces:
                set_uv.data[loop_index].uv = (math.atan2(co.x, -(co.y - mid_y)) / math.tau * 13.0 + 0.09 * math.sin(co.z * 105.0 + 2.2 * math.sin(co.y * 40.0)), co.z * 4.0)
            else:
                set_uv.data[loop_index].uv = ((co.x + co.z) * 28.0, co.y * 9.0)
    on_head(hair_set)
    # The clip, above the right ear.
    clip_way = Vector((-1.0, -0.12, 0.42)).normalized()
    clip_at = head_tree.ray_cast(skull_mid, clip_way, 0.4)[0]
    if clip_at is not None:
        bm = bmesh.new()
        made_ = bmesh.ops.create_uvsphere(bm, u_segments=12, v_segments=8, radius=1.0)
        slant = Vector((0.0, 1.0, -0.35)).normalized()
        across_ = clip_way.cross(slant).normalized()
        for v in made_["verts"]:
            v.co = clip_at + clip_way * 0.017 + slant * v.co.x * 0.03 + across_ * v.co.y * 0.008 + clip_way * v.co.z * 0.004
        for f in bm.faces:
            f.smooth = True
        clip_mesh = bpy.data.meshes.new("HairClip")
        bm.to_mesh(clip_mesh)
        bm.free()
        hair_clip = bpy.data.objects.new("HairClip", clip_mesh)
        bpy.context.scene.collection.objects.link(hair_clip)
        hair_clip.data.materials.append(plain(CID + "_hair_clip", CFG["hair"].get("clip_colour", [0.93, 0.9, 0.8]), 0.28, 0.0))
        on_head(hair_clip)

def wisp_material(name, colour, HAT):
    """Loose strands for the edge of dressed hair: a picture of separate hairs, thick with them at the top (where
    it meets the hair) and each running out to its own point below. Cut out, not blended."""
    size = 512
    rng = numpy.random.default_rng(zlib.crc32(name.encode("utf-8")))
    u = (numpy.arange(size, dtype=numpy.float32) + 0.5) / size
    v = (numpy.arange(size, dtype=numpy.float32) + 0.5) / size
    U, V = numpy.meshgrid(u, v)
    down = 1.0 - V                                    # 0 at the root, 1 at the longest tip
    cover = numpy.zeros((size, size), dtype=numpy.float32)
    tone = numpy.zeros((size, size), dtype=numpy.float32)
    # Round r16: single hairs a third of a millimetre wide were lost at any distance (a cut-out picture seen small
    # averages to nothing). These are fine locks, one to three millimetres at the root.
    for _ in range(int(HAT.get("wisp_strands", 46))):
        at, reach = rng.random(), 0.35 + 0.65 * rng.random() ** 0.7
        thick, bend, light = 0.012 + 0.022 * rng.random(), (rng.random() - 0.5) * 0.2, 0.55 + 0.45 * rng.random()
        along = numpy.clip(down / reach, 0.0, 1.0)
        middle = at + bend * along * along
        half = thick * (1.0 - along) ** 0.75
        away_ = numpy.abs((U - middle + 0.5) % 1.0 - 0.5)
        strand = numpy.clip((half - away_) * size * 0.4 + 0.5, 0.0, 1.0) * (down < reach)
        tone = numpy.where(strand > cover, light, tone)
        cover = numpy.maximum(cover, strand)
    # Where it meets the hair it is whole.
    cover = numpy.maximum(cover, numpy.clip((V - 0.86) / 0.05, 0.0, 1.0))
    tone = numpy.where(tone > 0.0, tone, 0.7)
    base = numpy.array(colour[:3], dtype=numpy.float32)
    shine = base + (1.0 - base) * 0.45
    lit = numpy.clip((tone - 0.86) / 0.14, 0.0, 1.0)
    grid = numpy.ones((size, size, 4), dtype=numpy.float32)
    grid[:, :, :3] = base[None, None, :] * (0.55 + 0.4 * tone * (1.0 - 0.25 * down))[:, :, None] + shine[None, None, :] * (lit * 0.3)[:, :, None]
    grid[:, :, :3] = numpy.clip(grid[:, :, :3], 0.0, 1.0)
    grid[:, :, 3] = cover
    flat = numpy.ones((size, size, 4), dtype=numpy.float32)
    flat[:, :, 0] = 0.5
    flat[:, :, 1] = 0.5
    pictures = []
    for suffix, data, space in (("_cloth", grid, "sRGB"), ("_cloth_normal", flat, "Non-Color")):
        picture = bpy.data.images.new(name + suffix, size, size, alpha=True)
        picture.pixels = data.ravel()
        picture.filepath_raw = os.path.join(OUT, name + suffix + ".png")
        picture.file_format = "PNG"
        picture.save()
        picture.colorspace_settings.name = space
        pictures.append(picture)
    material = bpy.data.materials.new(name)
    material.use_nodes = True
    nodes, links = material.node_tree.nodes, material.node_tree.links
    shader = nodes["Principled BSDF"]
    colour_node = nodes.new("ShaderNodeTexImage")
    colour_node.image = pictures[0]
    links.new(colour_node.outputs[0], shader.inputs["Base Color"])
    cut = nodes.new("ShaderNodeMath")
    cut.operation = "ROUND"
    links.new(colour_node.outputs["Alpha"], cut.inputs[0])
    links.new(cut.outputs[0], shader.inputs["Alpha"])
    normal_picture = nodes.new("ShaderNodeTexImage")
    normal_picture.image = pictures[1]
    normal_node = nodes.new("ShaderNodeNormalMap")
    links.new(normal_picture.outputs[0], normal_node.inputs["Color"])
    links.new(normal_node.outputs[0], shader.inputs["Normal"])
    shader.inputs["Roughness"].default_value = float(HAT.get("gloss_rough", 0.42)) + 0.1
    for setting, value in (("blend_method", "CLIP"), ("alpha_threshold", 0.5)):
        try:
            setattr(material, setting, value)
        except Exception:
            pass
    material["picture_limit"] = 512
    return material


def dressed_hair_material(name, colour, HAT, phase_at, part_angle):
    """The picture for sculpted stage hair, painted to the shape it lies on. Across the picture is once round the
    head; from the top down to a fifth from the bottom is crown to ends; the bottom strip is for coils and knots
    (round the coil across, base to top upward). Light is painted where a comb and a lamp would put it."""
    size = 1024
    rng = numpy.random.default_rng(zlib.crc32(name.encode("utf-8")))
    u = (numpy.arange(size, dtype=numpy.float32) + 0.5) / size
    v = (numpy.arange(size, dtype=numpy.float32) + 0.5) / size
    U, V = numpy.meshgrid(u, v)
    A = U * math.tau
    T = numpy.clip((1.0 - V) / 0.8, 0.0, 1.06)
    phase = phase_at(A, T, numpy.sin)
    swing = numpy.sin(math.tau * phase)                      # +1 on a crest, -1 in a trough
    settle = numpy.clip(T / 0.2, 0.0, 1.0)                    # the waves begin a little way from the crown

    def strands(count, soften):
        line = rng.random(count).astype(numpy.float32)
        for _ in range(soften):
            line = (numpy.roll(line, 1) + line * 2.0 + numpy.roll(line, -1)) / 4.0
        line = (line - line.min()) / max(float(line.max() - line.min()), 1e-6)
        return line

    fine, clumps = strands(size, 1), strands(48, 1)
    # Strands lie crown to ends and swing sideways with each wave, which is what makes a wave read as a wave.
    across = U + 0.011 * swing * settle + 0.004 * numpy.sin(T * 23.0 + A * 2.0)
    fine_at = fine[(numpy.floor(across * size).astype(numpy.int64)) % size]
    clump_at = numpy.interp((across * 48.0) % 48.0, numpy.arange(49, dtype=numpy.float32), numpy.append(clumps, clumps[0]))
    strand = 0.6 * fine_at + 0.4 * clump_at
    crest = 0.5 + 0.5 * swing
    # Hair brushed flat has no waves to light and shade: "wave_tone" under one evens the crests and troughs out.
    wave_tone = float(HAT.get("wave_tone", 1.0))
    tone = 0.56 + 0.4 * (wave_tone * crest ** 1.2 + (1.0 - wave_tone) * 0.5) * settle + 0.2 * (1.0 - settle)
    # The band of light sits just on the lamp's side of each crest, and is broken by the strands it crosses.
    along = (phase - 0.21) % 1.0
    band = numpy.exp(-((numpy.minimum(along, 1.0 - along)) / 0.075) ** 2) * settle * (0.5 + 0.5 * fine_at)
    gap = (A - part_angle + math.pi) % math.tau - math.pi
    root = numpy.exp(-(gap / 0.055) ** 2) * numpy.clip(T / 0.08, 0.0, 1.0) * numpy.clip((0.85 - T) / 0.15, 0.0, 1.0)
    ends = numpy.clip((T - 0.9) / 0.1, 0.0, 1.0)
    tone = tone * (0.84 + 0.16 * strand) * (1.0 - 0.4 * root) * (1.0 - 0.32 * ends)
    base = numpy.array(colour[:3], dtype=numpy.float32)
    shine = base + (1.0 - base) * float(HAT.get("shine", 0.55))
    grid = numpy.ones((size, size, 4), dtype=numpy.float32)
    grid[:, :, :3] = base[None, None, :] * tone[:, :, None] + shine[None, None, :] * (band * float(HAT.get("highlight", 0.5)))[:, :, None]
    height = strand * 0.6 + 0.4 * fine_at
    # The coil strip: strands wind round the coil, light along its upper turn, shade at its foot.
    strip = V < 0.16
    up = numpy.clip(V / 0.15, 0.0, 1.0)
    rows = strands(size, 2)
    wound = rows[(numpy.floor(V * 6.0 * size + U * 20.0).astype(numpy.int64)) % size]
    coil_tone = (0.5 + 0.48 * up ** 0.8) * (0.82 + 0.18 * wound)
    coil_band = numpy.exp(-((up - 0.7) / 0.12) ** 2) * (0.45 + 0.55 * wound)
    coil = base[None, None, :] * coil_tone[:, :, None] + shine[None, None, :] * (coil_band * float(HAT.get("highlight", 0.5)))[:, :, None]
    grid[:, :, :3] = numpy.where(strip[:, :, None], coil, grid[:, :, :3])
    height = numpy.where(strip, wound, height)
    grid[:, :, :3] = numpy.clip(grid[:, :, :3], 0.0, 1.0)
    depth = float(HAT.get("strand_depth", 1.6))
    dx = (numpy.roll(height, -1, 1) - numpy.roll(height, 1, 1)) * depth
    dy = (numpy.roll(height, -1, 0) - numpy.roll(height, 1, 0)) * depth
    length = numpy.sqrt(dx * dx + dy * dy + 1.0)
    normal = numpy.ones((size, size, 4), dtype=numpy.float32)
    normal[:, :, 0] = (-dx / length) * 0.5 + 0.5
    normal[:, :, 1] = (-dy / length) * 0.5 + 0.5
    normal[:, :, 2] = (1.0 / length) * 0.5 + 0.5
    pictures = []
    for suffix, data, space in (("_cloth", grid, "sRGB"), ("_cloth_normal", normal, "Non-Color")):
        picture = bpy.data.images.new(name + suffix, size, size, alpha=True)
        picture.pixels = data.ravel()
        picture.filepath_raw = os.path.join(OUT, name + suffix + ".png")
        picture.file_format = "PNG"
        picture.save()
        picture.colorspace_settings.name = space
        pictures.append(picture)
    material = bpy.data.materials.new(name)
    material.use_nodes = True
    nodes, links = material.node_tree.nodes, material.node_tree.links
    shader = nodes["Principled BSDF"]
    colour_node = nodes.new("ShaderNodeTexImage")
    colour_node.image = pictures[0]
    links.new(colour_node.outputs[0], shader.inputs["Base Color"])
    normal_picture = nodes.new("ShaderNodeTexImage")
    normal_picture.image = pictures[1]
    normal_node = nodes.new("ShaderNodeNormalMap")
    links.new(normal_picture.outputs[0], normal_node.inputs["Color"])
    links.new(normal_node.outputs[0], shader.inputs["Normal"])
    shader.inputs["Roughness"].default_value = float(HAT.get("gloss_rough", 0.42))
    # Painted to its shape, so it is not a repeating cloth: the exporter lets it keep its size.
    material["picture_limit"] = 1024
    return material


def wave_hair(HAT, top_z, brow_z, centre):
    """Dressed hair for the stage, 1929: finger waves set close to the head, modelled outright as one glossy
    shell that follows the skull (ridges running round the head in S-curves, a parting, the ends either
    curled under as a bob or gathered into a knot at the nape), with its ornament: a bandeau, a jewel, a feather.
    Worn as headwear whose note says it dresses the hair, so the everyday hair steps aside for it."""
    tree = BVHTree.FromPolygons([tuple(v.co) for v in mesh.vertices], [tuple(q.vertices) for q in mesh.polygons])
    middle = Vector((centre.x, centre.y, brow_z + 0.03))
    steps, rows = 80, 30
    length = float(HAT.get("length", 0.09))        # how far below the brow the hair ends at the back
    waves = float(HAT.get("waves", 3.5))
    lift = float(HAT.get("lift", 0.011))
    ridge = float(HAT.get("ridge", 0.0055))
    curl = float(HAT.get("curl", 0.0))             # a bob's ends, curled under
    part_side = float(HAT.get("part", 1.0))        # +1 parts the hair on the wearer's left, -1 on the right
    side_fall = float(HAT.get("side", 0.058))      # how far below the brow the hair ends at the sides (over the ears)
    front_rise = float(HAT.get("front", 0.05))     # how far above the brow the hairline sits at the front
    swoop = float(HAT.get("swoop", 0.03))          # how low the wave over one temple comes
    curly = float(HAT.get("curly", 0.0))           # curls worked into the surface, as well as the waves
    sideburn = float(HAT.get("sideburn", 0.0))     # how far the hair comes down in front of each ear
    fade = float(HAT.get("fade", 0.0))             # the share of the hair's length, at its edge, over which it thins to the skin
    part_angle = -math.pi / 2 + part_side * 0.5
    swoop_angle = -math.pi / 2 - part_side * 0.75   # the wave that comes low over the other temple

    def toward(a, polar):
        return Vector((math.cos(a) * math.sin(polar), math.sin(a) * math.sin(polar), math.cos(polar)))

    def skin(a, polar):
        way = toward(a, polar)
        # Looked for from just outside the head. From further off, a ray toward the jaw met the shoulder first,
        # and the hair came down to the chest in sheets.
        hit = tree.ray_cast(middle + way * 0.17, -way, 0.17)
        return (hit[0], way) if hit[0] is not None else (middle + way * 0.09, way)

    def edge_height(a):
        front = max(0.0, -math.sin(a))
        back = max(0.0, math.sin(a))
        z = brow_z - side_fall + (front_rise + side_fall) * front ** 1.5 - (length - side_fall) * back ** 1.2
        if sideburn > 0.0:
            for ear in (-float(HAT.get("sideburn_at", 0.4)), math.pi + float(HAT.get("sideburn_at", 0.4))):
                z -= sideburn * math.exp(-(((a - ear + math.pi) % math.tau - math.pi) / 0.17) ** 2)
        return z - swoop * math.exp(-(((a - swoop_angle + math.pi) % math.tau - math.pi) / float(HAT.get("swoop_width", 0.45))) ** 2)

    def polar_at(a, height):
        low, high = math.radians(35.0), math.radians(160.0)
        for _ in range(16):
            mid = (low + high) / 2
            if skin(a, mid)[0].z > height:
                low = mid
            else:
                high = mid
        return (low + high) / 2

    def phase_at(a, t, sin=math.sin):
        """Where in its wave the hair is at this place (whole numbers one wave apart). The picture reads it too."""
        return waves * t + 0.16 * sin(3.0 * a + 1.0) + 0.1 * sin(a - part_angle)

    def away(a, t):
        """How far off the skin the hair stands at this place: its body, its waves, its parting, its ends."""
        phase = phase_at(a, t)
        body = lift * min(1.0, t / 0.12 + 0.35) * (1.0 - 0.45 * max(0.0, (t - 0.86) / 0.14))
        if fade > 0.0:
            # Cut short at the sides and the nape: the hair thins to the skin, where set hair ends in a rolled edge.
            body *= 1.0 - 0.85 * max(0.0, (t - (1.0 - fade)) / fade) ** 1.5
        wave = ridge * math.sin(math.tau * phase) * min(1.0, t / 0.2)
        gap = (a - part_angle + math.pi) % math.tau - math.pi
        parting = 0.007 * math.exp(-(gap / 0.06) ** 2) * min(1.0, t / 0.08) * (1.0 if t < 0.7 else max(0.0, (0.85 - t) / 0.15))
        # The ends curl under at the sides and back. Over the forehead they lie flat, or the front reads as a brim.
        under = curl * math.sin(math.pi * min(1.0, max(0.0, (t - 0.72) / 0.28))) * (1.0 - 0.8 * max(0.0, -math.sin(a)) ** 1.5) if curl > 0.0 else 0.0
        ringlets = curly * math.sin(9.0 * a + 2.5 * math.sin(math.tau * 2.2 * t)) * math.sin(math.tau * 3.1 * t + 2.0 * a) * min(1.0, t / 0.15)
        return max(0.0025, body + wave - parting + under + ringlets)

    bm = bmesh.new()
    uv_of = {}
    edge_polar = [polar_at(math.tau * j / steps, edge_height(math.tau * j / steps)) for j in range(steps)]
    crown = bm.verts.new(skin(0.0, 0.0)[0] + Vector((0, 0, away(0.0, 0.0))))
    uv_of[crown] = (0.0, 1.0)
    rings = []
    for k in range(1, rows + 1):
        t = k / rows
        ring = []
        for j in range(steps):
            a = math.tau * j / steps
            at, way = skin(a, edge_polar[j] * t)
            v = bm.verts.new(at + way * away(a, t))
            uv_of[v] = (j / steps, 1.0 - 0.8 * t)
            ring.append(v)
        rings.append(ring)
    # The ends turn in to the head, so nobody sees up inside the hair.
    tuck = []
    for j in range(steps):
        a = math.tau * j / steps
        at, way = skin(a, edge_polar[j] * 1.02)
        v = bm.verts.new(at + way * 0.0015)
        uv_of[v] = (j / steps, 1.0 - 0.8 * 1.02)
        tuck.append(v)
    rings.append(tuck)
    for j in range(steps):
        bm.faces.new((crown, rings[0][j], rings[0][(j + 1) % steps]))
    for upper, lower in zip(rings, rings[1:]):
        for j in range(steps):
            bm.faces.new((upper[j], lower[j], lower[(j + 1) % steps], upper[(j + 1) % steps]))
    hair_faces = len(bm.faces)
    if HAT.get("updo"):
        # Swept up and pinned: a mass of curls over the back of the crown.
        count = int(HAT.get("updo", 11))
        for k in range(count):
            row_ = k % 3
            a = math.pi / 2 + (k / (count - 1.0) - 0.5) * 1.9 + 0.13 * row_
            polar = math.radians(48.0 + 21.0 * row_ + 7.0 * math.sin(k * 2.3))
            at, way = skin(a, polar)
            size = 0.026 + 0.006 * math.sin(k * 1.7)
            made = bmesh.ops.create_uvsphere(bm, u_segments=14, v_segments=9, radius=1.0)
            around_ = Vector((-way.y, way.x, 0.0)).normalized() if abs(way.z) < 0.98 else Vector((1.0, 0.0, 0.0))
            up_ = way.cross(around_).normalized()
            for v in made["verts"]:
                turn = math.atan2(v.co.z, v.co.x)
                coil = 1.0 + 0.1 * math.sin(2.0 * turn + 5.0 * v.co.y + k)
                uv_of[v] = (turn / math.tau + k * 0.37, 0.012 + 0.136 * (v.co.y * 0.5 + 0.5))
                v.co = at + way * (lift + 0.008 + v.co.y * size * 0.62) + around_ * v.co.x * size * coil + up_ * v.co.z * size * coil
        hair_faces = len(bm.faces)
    if HAT.get("knot"):
        # Gathered low at the nape into a coil.
        at, way = skin(math.pi / 2, polar_at(math.pi / 2, brow_z - length + 0.035))
        made = bmesh.ops.create_uvsphere(bm, u_segments=20, v_segments=12, radius=1.0)
        for v in made["verts"]:
            turn = math.atan2(v.co.z, v.co.x)
            swell = 1.0 + 0.07 * math.sin(3.0 * turn + 6.0 * v.co.y)
            uv_of[v] = (turn / math.tau, 0.012 + 0.136 * (v.co.y * 0.5 + 0.5))
            v.co = at + way * 0.022 + Vector((v.co.x * 0.05 * swell, v.co.y * 0.034, v.co.z * 0.04 * swell))
        hair_faces = len(bm.faces)
    ornament = HAT.get("ornament", "")
    if ornament in ("bandeau", "bandeau_star"):
        # A jewelled band low across the forehead and round the head, over the hair.
        band_z = brow_z + float(HAT.get("band_height", 0.03))
        lower_ring, upper_ring = [], []
        for j in range(steps):
            a = math.tau * j / steps
            band_half = float(HAT.get("band_half", 0.007))
            for ring, dz in ((lower_ring, -band_half), (upper_ring, band_half)):
                polar = polar_at(a, band_z + dz)
                at, way = skin(a, polar)
                # The band lies on whatever is under it: the hair with its waves, or the forehead. Stood off by
                # one height all round, it was a hoop that the head sat inside.
                along_hair = polar / edge_polar[j]
                stand = (away(a, along_hair) + 0.002) if along_hair < 1.0 else 0.003
                v = bm.verts.new(at + way * stand)
                uv_of[v] = (j / steps * 8.0, 0.5 + dz * 30.0)
                ring.append(v)
        for j in range(steps):
            bm.faces.new((upper_ring[j], lower_ring[j], lower_ring[(j + 1) % steps], upper_ring[(j + 1) % steps]))
    if ornament in ("bandeau_star", "clip", "feather"):
        # A jewel above the ear on the side away from the parting.
        jewel_angle = math.pi if part_side > 0 else 0.0
        jewel_angle += -0.55 if part_side > 0 else 0.55
        at, way = skin(jewel_angle, polar_at(jewel_angle, brow_z + 0.03))
        made = bmesh.ops.create_uvsphere(bm, u_segments=10, v_segments=6, radius=1.0)
        side_ = Vector((-way.y, way.x, 0.0)).normalized()
        for v in made["verts"]:
            spike = 1.0 + (0.9 * abs(math.cos(2.5 * math.atan2(v.co.z, v.co.x))) ** 6 if ornament == "bandeau_star" else 0.0)
            v.co = at + way * (lift + ridge + 0.004 + v.co.y * 0.004) + side_ * v.co.x * 0.017 * spike + Vector((0, 0, v.co.z * 0.017 * spike))
            uv_of[v] = (0.5 + v.co.x, 0.5 + v.co.z)
    jewel_faces = len(bm.faces)
    if ornament == "feather":
        # A feather sweeping back from the jewel.
        jewel_angle = (math.pi - 0.55) if part_side > 0 else 0.55
        at, way = skin(jewel_angle, polar_at(jewel_angle, brow_z + 0.03))
        root = at + way * (lift + ridge + 0.006)
        back_ = Vector((0.0, 1.0, 0.0))
        spine = []
        for k in range(9):
            s = k / 8.0
            mid_ = root + back_ * 0.15 * s + Vector((0, 0, 0.11 * math.sin(s * math.pi * 0.62))) + way * 0.03 * s * s
            half = 0.03 * math.sin(math.pi * min(1.0, s * 1.15)) ** 0.7 + 0.002
            spine.append((bm.verts.new(mid_ + Vector((0, 0, half))), bm.verts.new(mid_ - Vector((0, 0, half)))))
            uv_of[spine[-1][0]] = (s * 2.0, 1.0)
            uv_of[spine[-1][1]] = (s * 2.0, 0.0)
        for a_, b_ in zip(spine, spine[1:]):
            bm.faces.new((a_[0], a_[1], b_[1], b_[0]))
    feather_faces = len(bm.faces)
    wisps = float(HAT.get("wisps", 1.0))
    if wisps > 0.0:
        # Loose hair all round the edge: where sculpted hair simply stopped, it read as the rim of a cap. A fringe
        # of fine strands starts just under the edge and runs out along the skin, each to its own point: short
        # over the forehead and the ears, longest down the nape.
        wisp_side, wisp_nape, wisp_front = float(HAT.get("wisp_side", 0.018)), float(HAT.get("wisp_nape", 0.045)), float(HAT.get("wisp_front", 0.008))
        deep = 4
        columns = []
        for j in range(steps + 1):
            a = math.tau * (j % steps) / steps
            front, back = max(0.0, -math.sin(a)), max(0.0, math.sin(a))
            reach = wisps * (wisp_side + (wisp_nape - wisp_side) * back ** 1.5 + (wisp_front - wisp_side) * front ** 1.5)
            begin = away(a, 1.0) + 0.0012
            column = []
            for k in range(deep + 1):
                s_ = k / deep
                at, way = skin(a, edge_polar[j % steps] * 0.965 + reach * s_ / 0.09)
                v = bm.verts.new(at + way * (0.0035 + (begin - 0.0035) * (1.0 - s_) ** 1.6))
                uv_of[v] = (j / steps * float(HAT.get("wisp_repeats", 5.0)), 1.0 - s_)
                column.append(v)
            columns.append(column)
        for left, right in zip(columns, columns[1:]):
            for k in range(deep):
                bm.faces.new((left[k], left[k + 1], right[k + 1], right[k]))
    bm.faces.ensure_lookup_table()
    for index, face in enumerate(bm.faces):
        face.smooth = True
        face.material_index = 0 if index < hair_faces else 1 if index < jewel_faces else 2 if index < feather_faces else 3
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    layer = bm.loops.layers.uv.new("Cloth")
    for index, face in enumerate(bm.faces):
        corners = [uv_of.get(loop.vert, (0.0, 0.0)) for loop in face.loops]
        if index < hair_faces:
            # The picture goes once round: a face that spans the join reads on from the far side of it, and the
            # crown, which has no place round the head of its own, takes the middle of its face's.
            others = [c[0] for loop, c in zip(face.loops, corners) if loop.vert is not crown]
            if max(others) - min(others) > 0.5:
                corners = [(c[0] + 1.0 if c[0] < 0.5 else c[0], c[1]) for c in corners]
                others = [c + 1.0 if c < 0.5 else c for c in others]
            corners = [(sum(others) / len(others), c[1]) if loop.vert is crown else c for loop, c in zip(face.loops, corners)]
        for loop, corner in zip(face.loops, corners):
            loop[layer].uv = corner
    hair_mesh = bpy.data.meshes.new("StageHair")
    bm.to_mesh(hair_mesh)
    bm.free()
    # Named as headwear, so the part is saved with the hats.
    stage = bpy.data.objects.new("HatStage", hair_mesh)
    bpy.context.scene.collection.objects.link(stage)
    part_name = HAT.get("_part", "x")
    stage.data.materials.append(dressed_hair_material("%s_stage_hair_%s" % (CID, part_name), HAT["colour"], HAT, phase_at, part_angle))
    stage.data.materials.append(plain("%s_stage_jewel_%s" % (CID, part_name), HAT.get("band", [0.83, 0.68, 0.3]), 0.28, 1.0))
    stage.data.materials.append(plain("%s_stage_feather_%s" % (CID, part_name), HAT.get("feather", [0.05, 0.35, 0.32]), 0.55))
    stage.data.materials.append(wisp_material("%s_stage_wisps_%s" % (CID, part_name), HAT["colour"], HAT))
    for slot in stage.material_slots:
        slot.material.use_backface_culling = False
    stage["part"] = part_name
    on_head(stage)
    print("GARMENT StageHair", len(hair_mesh.polygons), "faces")


skull = [v.co.copy() for v in mesh.vertices if v.co.z > nose.z + 0.066]
for HAT in (HATS if skull else []):
    top_z = max(q.z for q in skull)
    brow_z = BROW_Z
    centre = Vector(((max(q.x for q in skull) + min(q.x for q in skull)) / 2, (max(q.y for q in skull) + min(q.y for q in skull)) / 2, 0))
    half_w = (max(q.x for q in skull) - min(q.x for q in skull)) / 2 + 0.02
    half_d = (max(q.y for q in skull) - min(q.y for q in skull)) / 2 + 0.02
    # Each kind of hat has its own crown and its own brim.
    hat_kind = HAT.get("kind", "cloche")
    if hat_kind == "waves":
        wave_hair(HAT, top_z, brow_z, centre)
        continue
    brim = float(HAT.get("brim", 1.0))
    # A brim that turns down hangs 16 mm below the band; it must clear the top of the eye.
    bz = brow_z + 0.002 if hat_kind in ("cloche", "derby", "fedora", "cap") else brow_z - 0.014
    crown_foot = bz + 0.034
    #            crown: lift, width, roundness of the side, flatness of the top, how far the back dips
    # Review of cast_r10: the toque read as a fez (tall drum), the beret as a plate under the hair, the cap as a
    # pillbox, the fedora as a bucket hat (a cylinder with a brim turned down all round), the derby as a helmet.
    crowns = {"cloche": (0.014, 1.085, 0.8, 1.25, 0.55), "toque": (0.016, 1.07, 0.6, 1.5, 0.3), "wide": (0.004, 1.06, 0.8, 1.1, 0.3),
              "cap": (0.0, 1.1, 0.6, 2.2, 0.3), "derby": (0.032, 1.06, 0.8, 1.35, 0.2), "fedora": (0.04, 1.04, 0.7, 1.7, 0.2),
              "boater": (0.022, 1.06, 0.22, 7.0, 0.1), "beret": (0.013, 1.4, 0.5, 1.5, 0.7), "headscarf": (0.008, 1.045, 0.8, 1.25, 0.9)}
    lift, wide_, side_, flat_, dip_ = crowns.get(hat_kind, crowns["cloche"])
    crown_top = top_z + lift + float(HAT.get("tall", 0.0))
    hat_rows = []
    for k in range(13):
        t = k / 12.0
        angle = t * math.pi / 2
        hat_rows.append((math.sin(angle) ** side_ * wide_, crown_top - (1 - math.cos(angle)) ** flat_ * (crown_top - crown_foot), t * dip_))
    if hat_kind == "cloche":
        # A bell: the brim turns down close round the face.
        hat_rows += [(1.1, bz + 0.03, 0.7), (1.13, bz + 0.02, 0.85), (1.18, bz + 0.004, 1.0), (1.2, bz - 0.01, 1.0),
                     (1.18, bz - 0.012, 1.0), (1.14, bz + 0.002, 1.0), (1.1, bz + 0.016, 0.85), (1.05, bz + 0.032, 0.6)]
    elif hat_kind in ("boater", "wide"):
        # A flat, level brim.
        hat_rows += [(1.08, bz + 0.024, 0.2), (1.1, bz + 0.015, 0.2), (1.1 + 0.2 * brim, bz + 0.012, 0.2), (1.1 + 0.27 * brim, bz + 0.011, 0.2),
                     (1.1 + 0.27 * brim, bz + 0.005, 0.2), (1.1 + 0.2 * brim, bz + 0.006, 0.2), (1.1, bz + 0.009, 0.2), (1.05, bz + 0.03, 0.2)]
    elif hat_kind == "beret":
        # Wide and soft, gathered in to a band.
        hat_rows += [(1.3, crown_foot - 0.008, 0.4), (1.24, crown_foot - 0.016, 0.4), (1.15, crown_foot - 0.02, 0.4), (1.08, crown_foot - 0.02, 0.4),
                     (1.06, crown_foot - 0.026, 0.4), (1.05, crown_foot - 0.03, 0.4), (1.04, crown_foot - 0.026, 0.4), (1.03, crown_foot - 0.01, 0.4)]
    elif hat_kind in ("toque", "headscarf"):
        hat_rows += [(wide_, bz + 0.03, dip_), (wide_ - 0.01, bz + 0.022, dip_), (wide_ - 0.02, bz + 0.016, dip_), (wide_ - 0.03, bz + 0.012, dip_),
                     (wide_ - 0.04, bz + 0.012, dip_), (wide_ - 0.05, bz + 0.016, dip_), (wide_ - 0.06, bz + 0.022, dip_), (wide_ - 0.07, bz + 0.03, dip_)]
    elif hat_kind == "derby":
        # A short brim that curls up at its edge, most at the sides.
        hat_rows += [(1.08, bz + 0.022, 0.3), (1.1 + 0.05 * brim, bz + 0.015, 0.3), (1.1 + 0.11 * brim, bz + 0.012, 0.3), (1.1 + 0.15 * brim, bz + 0.016, 0.3),
                     (1.1 + 0.155 * brim, bz + 0.022, 0.3), (1.1 + 0.13 * brim, bz + 0.018, 0.3), (1.1 + 0.05 * brim, bz + 0.011, 0.3), (1.05, bz + 0.03, 0.3)]
    elif hat_kind == "fedora":
        # A wider, nearly level brim: snapped down at the front and up at the back, in the ring loop below.
        hat_rows += [(1.1, bz + 0.022, 0.5), (1.1 + 0.07 * brim, bz + 0.015, 0.5), (1.1 + 0.16 * brim, bz + 0.01, 0.5), (1.1 + 0.24 * brim, bz + 0.007, 0.5),
                     (1.1 + 0.245 * brim, bz + 0.003, 0.5), (1.1 + 0.16 * brim, bz + 0.004, 0.5), (1.1, bz + 0.012, 0.5), (1.05, bz + 0.03, 0.5)]
    else:
        # The cap's peak: flat, at the front only.
        hat_rows += [(1.1, bz + 0.02, 0.3), (1.1 + 0.1 * brim, bz + 0.013, 0.3), (1.1 + 0.2 * brim, bz + 0.008, 0.3), (1.1 + 0.24 * brim, bz + 0.005, 0.3),
                     (1.1 + 0.24 * brim, bz + 0.001, 0.3), (1.1 + 0.12 * brim, bz + 0.005, 0.3), (1.1, bz + 0.012, 0.3), (1.05, bz + 0.03, 0.3)]
    bm = bmesh.new()
    rings = []
    steps = 56
    for row_index, (r, z, low) in enumerate(hat_rows):
        ring = []
        for k in range(steps):
            a = math.tau * k / steps
            dip = 0.024 * (1 + math.sin(a)) * 0.5 * low
            reach_ = r
            if HAT.get("kind") == "cap" and r > 1.1:
                # The peak: only at the front.
                reach_ = 1.1 + (r - 1.1) * 1.6 * max(0.0, -math.sin(a)) ** 2
            shape_ = 0.0
            if hat_kind == "derby" and r > 1.1:
                # The curl stands highest at the sides.
                shape_ = 0.06 * (r - 1.1) * math.cos(a) ** 2
            elif hat_kind == "fedora":
                if r > 1.1:
                    # Up at the back, down over the eyes.
                    shape_ = (r - 1.1) * (0.075 * max(0.0, math.sin(a)) - 0.05 * max(0.0, -math.sin(a)) ** 2)
                elif row_index < 13:
                    # The crease along the top of the crown, front to back.
                    across = abs(math.cos(a) * reach_ * half_w)
                    shape_ = -0.014 * max(0.0, 1.0 - across / 0.03) * max(0.0, 1.0 - row_index / 7.0)
            elif hat_kind == "cap" and row_index < 13:
                # The crown slopes forward to the peak.
                shape_ = 0.014 * math.sin(a) * min(1.0, reach_)
            ring.append(bm.verts.new((centre.x + math.cos(a) * reach_ * half_w, centre.y + math.sin(a) * reach_ * half_d, z - dip + shape_)))
        rings.append(ring)
    for index, (a, b) in enumerate(zip(rings, rings[1:])):
        for k in range(steps):
            face = bm.faces.new((a[k], a[(k + 1) % steps], b[(k + 1) % steps], b[k]))
            # A cap and a headscarf have no hat band.
            face.material_index = 1 if index in (12, 13) and hat_kind not in ("cap", "headscarf") else 0
            face.smooth = True
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    hat_mesh = bpy.data.meshes.new("Hat")
    bm.to_mesh(hat_mesh)
    bm.free()
    hat = bpy.data.objects.new("Hat", hat_mesh)
    bpy.context.scene.collection.objects.link(hat)
    hat_uv = hat_mesh.uv_layers.new(name="Cloth")
    for polygon in hat_mesh.polygons:
        for loop_index in polygon.loop_indices:
            co = hat_mesh.vertices[hat_mesh.loops[loop_index].vertex_index].co
            hat_uv.data[loop_index].uv = (math.atan2(co.x - centre.x, -(co.y - centre.y)) / math.tau * 3.0, co.z * 6.0)
    hat.data.materials.append(patterned("%s_hat_%s" % (CID, HAT.get("_part", "x")), HAT["colour"], None, 0.9, "felt"))
    hat.data.materials.append(plain("%s_hat_band_%s" % (CID, HAT.get("_part", "x")), HAT.get("band", [c * 0.35 for c in HAT["colour"]]), 0.5))
    hat["part"] = HAT.get("_part", "")
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
for label, result in () if OUTFIT else (("hair", tfx.export_hair(bpy.context, hair_object, os.path.join(OUT, CID + "_hair.tfx"), points_per, True)),
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
if not OUTFIT and not PACK_HAIR and not PINNED and not CARD_HAIR:
    json.dump(recipe, open(os.path.join(OUT, CID + "_hair.json"), "w", encoding="utf-8"), indent=1)
else:
    show = ["head", "hands"] + (["arms"] if float(CFG.get("bare_arm_from", 1.0)) < 1.0 else []) + (["chest"] if float(CFG.get("bare_chest_vee", 0.0)) > 0.0 else []) + (["legs"] if CFG.get("bare_legs") else [])
    json.dump({"schema_version": 1, "person": CID, "outfit": OUTFIT, "show": show, "garments": [g.name for g in garments]},
              open(os.path.join(OUT, STEM + ".json"), "w", encoding="utf-8"), indent=1)



def repair_flat_uv(obj):
    """RUL-012: every triangle with real area has UV area. Codex's review of cast_r11 found faces that had none:
    level faces of cloth unwrapped round the body and up it (a waistband's top, a brim's flat), and faces of pack
    garments drawn on a single point of their picture. Each such face is laid flat in its own plane. On cloth it
    takes the density of the faces round it, so the weave carries on; on a pack garment that keeps its picture it
    stays within a texel or two of where it was, so it keeps its colour."""
    mesh_ = obj.data
    layer = mesh_.uv_layers.active
    if layer is None or not mesh_.polygons:
        return 0
    mesh_.calc_loop_triangles()
    at = [v.co.copy() for v in mesh_.vertices]
    flat_faces = set()
    densities = []
    for triangle in mesh_.loop_triangles:
        p0, p1, p2 = (at[i] for i in triangle.vertices)
        area = (p1 - p0).cross(p2 - p0).length * 0.5
        if area <= 1e-10:
            continue
        u0, u1, u2 = (layer.data[i].uv for i in triangle.loops)
        det = (u1.x - u0.x) * (u2.y - u0.y) - (u1.y - u0.y) * (u2.x - u0.x)
        if abs(det) <= 1e-9:
            flat_faces.add(triangle.polygon_index)
        else:
            densities.append(abs(det) * 0.5 / area)
    # A four-cornered face can be cut along either diagonal, and the exporter need not cut it as this does: both
    # ways are read. (Stacy's hair under a hat had two faces whose other diagonal left a triangle with no UV area.)
    for polygon in mesh_.polygons:
        if polygon.loop_total != 4 or polygon.index in flat_faces:
            continue
        loops = list(polygon.loop_indices)
        for trio in ((0, 1, 3), (1, 2, 3), (0, 1, 2), (0, 2, 3)):
            p0, p1, p2 = (at[mesh_.loops[loops[k]].vertex_index] for k in trio)
            if (p1 - p0).cross(p2 - p0).length * 0.5 <= 1e-10:
                continue
            u0, u1, u2 = (layer.data[loops[k]].uv for k in trio)
            if abs((u1.x - u0.x) * (u2.y - u0.y) - (u1.y - u0.y) * (u2.x - u0.x)) <= 1e-9:
                flat_faces.add(polygon.index)
                break
    if not flat_faces:
        return 0
    densities.sort()
    per_metre = math.sqrt(densities[len(densities) // 2]) if densities else 6.0
    keeps_picture = bool(obj.get("uv_picture"))
    for index in flat_faces:
        polygon = mesh_.polygons[index]
        normal = polygon.normal
        if normal.length < 1e-6:
            continue
        along = normal.cross(Vector((0.0, 0.0, 1.0)))
        if along.length < 1e-4:
            along = Vector((1.0, 0.0, 0.0))
        along.normalize()
        across = normal.cross(along).normalized()
        origin = at[polygon.vertices[0]]
        anchor = layer.data[polygon.loop_indices[0]].uv.copy()
        scale = per_metre
        if keeps_picture:
            longest = max((at[a] - at[b]).length for a, b in polygon.edge_keys)
            scale = 0.0015 / max(longest, 1e-5)
        for loop_index in polygon.loop_indices:
            offset = at[mesh_.loops[loop_index].vertex_index] - origin
            layer.data[loop_index].uv = (anchor.x + offset.dot(along) * scale, anchor.y + offset.dot(across) * scale)
    return len(flat_faces)


for candidate in list(bpy.data.objects):
    if candidate.type == "MESH" and candidate.data.uv_layers:
        repaired = repair_flat_uv(candidate)
        if repaired:
            print("UV REPAIR", candidate.name, repaired, "faces")
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, STEM + ".blend"))

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
for part_ in skin_parts:
    part_.hide_render = True
for name, yaw in (() if not OUTFIT else (("three_quarter", 35.0),)):
    at = Vector((0, 0, 0.86))
    cam.location = at + Matrix.Rotation(math.radians(yaw), 3, "Z") @ Vector((0, -3.5, 0))
    cam.rotation_euler = (at - cam.location).to_track_quat("-Z", "Y").to_euler()
    cam.data.lens = 55
    scene.render.filepath = os.path.join(OUT, "%s_%s.png" % (STEM, name))
    try:
        bpy.ops.render.render(write_still=True)
    except Exception:
        traceback.print_exc()
bpy.ops.object.select_all(action="DESELECT")
hats = [o for o in extras if o.name.startswith("Hat")]
if OUTFIT == "parts":
    wearable = garments + hats
    # Pictures: each designed set, then two mixes across sets.
    looks = [(name, pick) for name, pick in TABLE[CID].get("looks", {}).items()]
    for part_ in skin_parts:
        part_.hide_render = True
    for look_name, pick in looks:
        for obj in wearable:
            obj.hide_render = obj.get("part", "") not in pick
        at = Vector((0, 0, 0.86))
        cam.location = at + Matrix.Rotation(math.radians(35.0), 3, "Z") @ Vector((0, -3.5, 0))
        cam.rotation_euler = (at - cam.location).to_track_quat("-Z", "Y").to_euler()
        cam.data.lens = 55
        scene.render.filepath = os.path.join(OUT, "%s__look_%s.png" % (CID, look_name))
        try:
            bpy.ops.render.render(write_still=True)
        except Exception:
            traceback.print_exc()
    for obj in wearable:
        obj.hide_render = False
    for part_name, part in PARTS.items():
        mine = [o for o in wearable if o.get("part", "") == part_name]
        if not mine:
            print("PART", part_name, "made nothing")
            continue
        bpy.ops.object.select_all(action="DESELECT")
        for obj in [rig] + mine:
            obj.select_set(True)
        target = os.path.join(OUT, "%s__%s.glb" % (CID, part_name))
        bpy.ops.export_scene.gltf(filepath=target, use_selection=True, export_format="GLB", export_morph=False, export_animations=False, export_yup=True, export_vertex_color="ACTIVE")
        note = {"schema_version": 1, "person": CID, "part": part_name, "slot": part["slot"], "set": part.get("set", ""), "tags": part.get("tags", []), "covers": part.get("covers", []), "replaces": part.get("replaces", [])}
        if part.get("hair"):
            # "replace": this headwear is the hair, dressed; neither the everyday hair nor the hair for under a hat shows.
            note["hair"] = part["hair"]
        json.dump(note, open(os.path.join(OUT, "%s__%s.json" % (CID, part_name)), "w", encoding="utf-8"), indent=1)
        print("PART", part_name, part["slot"], os.path.getsize(target))
    print("DONE")
    sys.exit(0)
if OUTFIT:
    chosen = [rig] + garments + hats + [p_ for p_ in parts if p_.name == "Shoes"]
else:
    chosen = [rig] + skin_parts + parts + [o for o in extras if o.name != "Hat"]
for obj in chosen:
    obj.select_set(True)
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, STEM + ".glb"), use_selection=True, export_format="GLB",
                          export_morph=True, export_morph_normal=False, export_animations=False, export_yup=True, export_vertex_color="ACTIVE")
print("EXPORTED", os.path.getsize(os.path.join(OUT, STEM + ".glb")))
print("DONE")
