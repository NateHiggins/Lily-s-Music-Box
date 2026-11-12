"""Build a cast member whole: base body, face, hands, strand hair and a wardrobe.

blender -b --python build_cast_wardrobe.py -- <character id> <wardrobe json> <out dir>

Nothing of the old generated shells is used. The body is the MakeHuman base
(MPFB2, CC0 assets) on its Mixamo-named skeleton, the same for every cast
member. Clothes are separate pieces made here from the base's own clothing
helpers (a body-hugging shell and a skirt), cut to each garment's shape, set
off from the skin, and given the character's colours. The world is surreal and
the cast must read at a distance, so the palettes are bold.
"""
import bpy, bmesh, os, sys, glob, json, math, importlib, importlib.util, traceback, zlib
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


CLOTHS = {
    "cotton": {"rough": 0.85, "depth": 0.5, "shade": 0.05},
    "wool": {"rough": 0.92, "depth": 0.9, "shade": 0.09},
    "knit": {"rough": 0.96, "depth": 1.6, "shade": 0.14},
    "felt": {"rough": 0.95, "depth": 0.35, "shade": 0.06},
    "silk": {"rough": 0.6, "depth": 0.12, "shade": 0.03},
    "leather": {"rough": 0.32, "depth": 0.25, "shade": 0.05},
}


MUTE = float(TABLE.get("_mute", CFG.get("mute", 0.3)))
WEAR = float(TABLE.get("_wear", CFG.get("wear", 1.0)))


def worn_colour(colour):
    grey = 0.3 * colour[0] + 0.55 * colour[1] + 0.15 * colour[2]
    return [min(1.0, (c + (grey - c) * MUTE) * (0.94 + 0.1 * MUTE)) for c in colour]


def patterned(name, colour, pattern, rough, cloth="cotton"):
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


def piece(name, source, keep, offset, colour, rough=0.8, thicken=None, reshape=None, pattern=None, cloth="cotton", subdivide=0, made=None, weights=None):
    """A garment: the faces of a clothing helper whose corners all pass `keep`,
    set off from the skin by `offset` metres. Or, with `made`, a shape built
    outright (made fills the mesh; weights gives each point its bones)."""
    bm = bmesh.new()
    if made is not None:
        made(bm)
        bm.verts.ensure_lookup_table()
    else:
        bm.from_mesh(mesh)
        bm.verts.ensure_lookup_table()
        source_index = group_index[source]
        deform = bm.verts.layers.deform.verify()
        # `keep` gives each point a margin in metres: positive inside the garment, negative outside (True and
        # False count as far inside and far outside). The cloth is cut where the margin crosses zero, through
        # the faces. Cutting along the faces' own edges left teeth at every armhole, neckline and hem.
        # Margins are read before anything is deleted: deleting renumbers the points.
        margin = {}
        for v in bm.verts:
            if source_index not in v[deform]:
                continue
            value = keep(mesh.vertices[v.index])
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
    for _ in range(8 if made is None else 22):
        moved = {}
        for v in bm.verts:
            beside = [e.other_vert(v) for e in v.link_edges if e.is_boundary]
            if len(beside) == 2:
                moved[v] = v.co * 0.5 + (beside[0].co + beside[1].co) * 0.25
        for v, co in moved.items():
            v.co = co
    if subdivide:
        bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=subdivide, use_grid_fill=True, smooth=0.6)
    bm.normal_update()
    for v in bm.verts:
        push = offset + (thicken(v.co) if thicken else 0.0)
        if abs(v.co.x) > shoulder.x - 0.02 and v.co.z > hip and source == "helper-tights":
            # Sleeves and shoulder caps sit closer than the body of a garment, or arms read as padded.
            push = 0.004 + (push - 0.004) * 0.5
        elif source == "helper-tights" and v.co.z > neck - 0.13:
            # Room over the collarbones and round the base of the neck: skin came through close shirts there
            # as chips beside the placket and teeth along the neckline.
            push += 0.005 * min(1.0, (v.co.z - (neck - 0.13)) / 0.05)
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
    obj.data.materials.append(patterned("%s_%s_%s" % (STEM, CURRENT_PART or "x", name) if CURRENT_PART else "%s_%s" % (STEM, name), colour, pattern, rough, cloth))
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


def slim(obj, keep=0.005, floor=0.004, ceiling=0.008, whole=False, pull=True):
    """Bring a pack garment in to the body above the hips. The packs' jackets
    are cut with padded shoulders and wide sleeves; on a small figure that
    reads as bulk. What stands off the skin keeps its order, at a fraction of
    its distance: least of it over the shoulders and upper arms."""
    if not _skin_tree:
        _skin_tree.append(BVHTree.FromPolygons([tuple(v.co) for v in mesh.vertices], [tuple(q.vertices) for q in mesh.polygons]))
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
        if obj.data.uv_layers.active is not None:
            for corner in obj.data.uv_layers.active.data:
                corner.uv = (corner.uv[0] * float(made.get("scale", 9.0)), corner.uv[1] * float(made.get("scale", 9.0)))
        node = None
    elif image is not None:
        node.image = tinted_image(image, colour, "%s_%s_%s" % (STEM, CURRENT_PART or "x", name), deep_only=deep_only)
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


def torso(v, low=None, high=None, sleeves=1.0, vee=0.0, inner=False):
    """The margin (metres, positive inside) of a body garment at a point of the tights."""
    # Nothing cut from the tights hangs below the fork of the legs: it came out as a tongue between them.
    low = max(hip - 0.075, waist - 0.05 if low is None else low)
    # A round neck is cut a little below the top of the tights: their own rim is a row of battlements.
    high = neck - 0.012 if high is None else high
    co = v.co
    arm = weight(v, ARM)
    if sleeves > 0.0 and arm > 0.45:
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
        past_arm = out_arm(co) + shoulder.x * 0.4 + narrow
        outboard = abs(co.x) - strap_edge
        above_armpit = co.z - (shoulder.z - 0.10)
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
    # The hem is the level line at `low`, which never goes below the fork. Following the legs' bone weights
    # instead scalloped every cardigan and blouse hem.
    return inside


def legs(v, low, high):
    return min(band(v.co.z, low, high), (0.3 - weight(v, ARM)) * W)


def seat_room(co):
    """Extra clearance over the seat and hips, most of it behind: the review
    found the body showing through skirts there, and under-layers through coats."""
    return 0.02 * max(0.0, 1.0 - abs(co.z - (hip - 0.08)) / 0.16) * (1.0 if co.y > 0.0 else 0.3)


def skirt_shape(hem, flare, pleats=0):
    top = hip + 0.07
    natural_hem = 0.12

    def shape(co):
        t = max(0.0, min(1.0, (top - co.z) / (top - natural_hem)))
        z = top - t * (top - hem)
        spread = 1.0 + flare * t
        if pleats:
            spread *= 1.0 + 0.09 * t * math.sin(math.atan2(co.x, -(co.y - 0.02)) * pleats)
        return Vector((co.x * spread, (co.y - 0.02) * spread + 0.02, z))
    return shape


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
    colour = row["colour"]
    cloth = row.get("cloth")
    if kind == "asset":
        asset_piece(row.get("name", "Pack"), row["asset"], colour, skirt=bool(row.get("skirt")), atype=row.get("atype", "Clothes"), deep_only=bool(row.get("deep")), felt=bool(row.get("felt")), made=row.get("made"), hem_to_calf=bool(row.get("hem_to_calf")))
    elif kind == "shoes":
        piece("Shoes", "helper-tights", lambda v: min(ankle + 0.03 - v.co.z, (weight(v, ("Foot", "Toe")) - 0.2) * W), 0.009, colour, 0.35, cloth="leather")
        if row.get("strap"):
            piece("ShoeStraps", "helper-tights", lambda v: min(band(v.co.z, ankle + 0.02, ankle + 0.06), (weight(v, LEG) - 0.3) * W), 0.006, colour, 0.35, cloth="leather")
    elif kind == "shirt":
        piece(row.get("name", "Shirt"), "helper-tights", lambda v, r=row, t=tucked_low: torso(v, inner=True, low=max(waist - float(r.get("length", 0.09)), t or -9.0), sleeves=float(r.get("sleeves", 1.0)), vee=float(r.get("vee", 0.0))), float(row.get("ease", 0.004)), colour, 0.85,
              pattern=row.get("pattern"), cloth=cloth or "cotton",
              thicken=lambda co, r=row: 0.5 * float(r.get("blouson", 0.0)) * max(0.0, 1.0 - abs(co.z - (waist + 0.06)) / 0.14))
    elif kind == "jumper":
        piece("Jumper", "helper-tights", lambda v, r=row, t=tucked_low: torso(v, inner=True, low=max(hip - float(r.get("length", 0.01)), t or -9.0), sleeves=float(r.get("sleeves", 1.0)), vee=float(r.get("vee", 0.0))),
              float(row.get("ease", 0.017)), colour, 0.95, pattern=row.get("pattern"), cloth=cloth or "knit")
    elif kind == "waistcoat":
        piece("Waistcoat", "helper-tights", lambda v, r=row: torso(v, low=waist - 0.04, sleeves=0.0, vee=float(r.get("vee", 0.2))), 0.017, colour, 0.7, pattern=row.get("pattern"), cloth=cloth or "wool")
    elif kind == "jacket":
        piece("Jacket", "helper-tights", lambda v, r=row: torso(v, low=hip - float(r.get("length", 0.06)), sleeves=float(r.get("sleeves", 1.0)), vee=float(r.get("vee", 0.3))),
              max(0.02, float(row.get("ease", 0.02))) + over_pack, colour, 0.8, pattern=row.get("pattern"), cloth=cloth or "wool",
              thicken=lambda co, r=row: float(r.get("shoulders", 0.0)) * max(0.0, 1.0 - abs(co.z - shoulder.z) / 0.08) + float(r.get("skirted", 0.0)) * max(0.0, min(1.0, (waist - co.z) / 0.2)))
    elif kind == "dress":
        sleeves = float(row.get("sleeves", 0.5))
        piece("DressTop", "helper-tights", lambda v, r=row, sl=sleeves: torso(v, low=hip - 0.02, sleeves=sl, vee=float(r.get("vee", 0.06))), 0.006, colour, 0.85,
              pattern=row.get("pattern"), cloth=cloth or "cotton")
        piece("DressSkirt", "helper-skirt", lambda v: True, 0.01, colour, 0.85, thicken=seat_room,
              reshape=skirt_shape(float(row.get("hem", 0.4)), float(row.get("flare", 0.2)), int(row.get("pleats", 0))), pattern=row.get("pattern"), cloth=cloth or "cotton", subdivide=1)
    elif kind == "cardigan":
        piece("Cardigan", "helper-tights", lambda v, r=row: torso(v, low=hip + 0.012, sleeves=1.0, vee=float(r.get("vee", 0.34))), 0.018, colour, 0.95, pattern=row.get("pattern"), cloth=cloth or "knit")
    elif kind == "coat":
        piece("CoatTop", "helper-tights", lambda v, r=row: torso(v, low=hip - 0.02, sleeves=1.0, vee=float(r.get("vee", 0.2))), 0.023 + over_pack, colour, 0.85, pattern=row.get("pattern"), cloth=cloth or "wool")
        piece("CoatSkirt", "helper-skirt", lambda v: True, 0.034 + over_pack, colour, 0.85, thicken=seat_room, reshape=skirt_shape(float(row.get("hem", 0.45)), float(row.get("flare", 0.12))), pattern=row.get("pattern"), cloth=cloth or "wool", subdivide=1)
    elif kind == "bib":
        piece("Bib", "helper-tights", lambda v: min((0.3 - weight(v, ARM)) * W, bone("Spine2").y - 0.01 - v.co.y, band(v.co.z, waist - 0.02, neck - 0.13), 0.11 - abs(v.co.x)),
              0.018, colour, 0.85, pattern=row.get("pattern"), cloth=cloth or "cotton")
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
              reshape=skirt_shape(max(float(row.get("hem", 0.5)), float(apron_skirt.get("hem", 0.38)) + 0.05) if apron_made else float(row.get("hem", 0.5)),
                                  float(apron_skirt.get("flare", 0.25)) if apron_made else float(row.get("flare", 0.11)),
                                  int(apron_skirt.get("pleats", 0)) if apron_made else 0), cloth=cloth or "cotton", subdivide=1)
        # Review of cast_r10: the bib's outline was ragged. Its edge followed the arm's weights, which are uneven,
        # and its top corners were square. Plain planes, rounded corners, a finer cut.
        piece("ApronBib", "helper-tights", lambda v: min(bone("Spine2").y - 0.01 - v.co.y, v.co.z - (waist - 0.02), round_min(neck - 0.12 - v.co.z, 0.1 - abs(v.co.x), 0.03)),
              0.02 + over_pack, colour, 0.85, cloth=cloth or "cotton", subdivide=1)
    elif kind == "sash":
        piece("Sash", "helper-tights", lambda v, r=row: min(0.045 - abs(v.co.z - (hip + float(r.get("up", 0.03)))), (0.3 - weight(v, ARM)) * W), float(row.get("off", 0.017)) + over_pack, colour, 0.5, cloth=cloth or "silk")
    elif kind == "scarf":
        piece("Scarf", "helper-tights", lambda v: min(band(v.co.z, neck - 0.05, neck + 0.03), (0.3 - weight(v, ARM)) * W, 0.078 - abs(v.co.x)), 0.014, colour, 0.8, pattern=row.get("pattern"), cloth=cloth or "silk")
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
    elif kind == "stockings":
        piece("Stockings", "helper-tights", lambda v: legs(v, ankle - 0.08, hip - 0.1), 0.002, colour, 0.5, cloth="silk")
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
skull = [v.co.copy() for v in mesh.vertices if v.co.z > nose.z + 0.066]
for HAT in (HATS if skull else []):
    top_z = max(q.z for q in skull)
    brow_z = BROW_Z
    centre = Vector(((max(q.x for q in skull) + min(q.x for q in skull)) / 2, (max(q.y for q in skull) + min(q.y for q in skull)) / 2, 0))
    half_w = (max(q.x for q in skull) - min(q.x for q in skull)) / 2 + 0.02
    half_d = (max(q.y for q in skull) - min(q.y for q in skull)) / 2 + 0.02
    # Each kind of hat has its own crown and its own brim.
    hat_kind = HAT.get("kind", "cloche")
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
