"""Layered clump-card hair, built on a head mesh. CPU modelling and export only.

A solid under-cap in the darkest tone, then tiers of cupped, tapering strips
whose roots are scattered over the scalp and whose directions follow a flow
field (a whorl at the back of the crown, gravity, a per-style sweep). The
feathering is in the texture: each strip shows a whole clump of strands that
splits into separate points over its last third.

    blender -b --python art/blender/scripts/build_card_hair.py -- <source.blend> <style.json> <out_dir>

Styles come from art/tools/card_hair_styles.py. The look file written beside the
model carries the shader settings; art/blender/cast/card_hair/README.md has the contract.

The source file is opened and never saved. Nothing is read from any picture.
"""
import bpy, bmesh, json, math, random, sys
import numpy as np
from pathlib import Path
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree

ARGS = sys.argv[sys.argv.index("--") + 1:]
SOURCE, STYLE_PATH, OUT = ARGS[0], Path(ARGS[1]).resolve(), Path(ARGS[2]).resolve()    # absolute: Blender saves images relative to the file it has open
STYLE = json.loads(STYLE_PATH.read_text())
OUT.mkdir(parents=True, exist_ok=True)
rng = random.Random(int(STYLE.get("seed", 1929)))

bpy.ops.wm.open_mainfile(filepath=SOURCE)
head = bpy.data.objects[STYLE.get("head_object", "Skin_head")]
depsgraph = bpy.context.evaluated_depsgraph_get()
bm = bmesh.new()
bm.from_object(head, depsgraph)
bm.transform(head.matrix_world)
# Styles are written for one size of head (the pilot's). With "fit": "head_bone" the head is measured from
# its Head bone and brought to that size here; the finished hair is taken back to the real head at the end.
CANON_C = Vector((0.0, -0.040, 1.345))
FIT = Matrix.Identity(4)
if STYLE.get("fit") == "head_bone":
    rig = next(o for o in bpy.data.objects if o.type == "ARMATURE" and "Head" in o.data.bones)
    bone = rig.data.bones["Head"]
    foot = rig.matrix_world @ bone.head_local
    size = ((rig.matrix_world @ bone.tail_local) - foot).length / 0.18
    centre = foot + Vector((0.0007, -0.0233, 0.0737)) * size
    FIT = Matrix.Translation(centre) @ Matrix.Scale(size, 4) @ Matrix.Translation(-CANON_C)
    bm.transform(FIT.inverted())
    C = CANON_C.copy()
else:
    C = Vector(STYLE["skull_centre"])
tree = BVHTree.FromBMesh(bm)
BALD = math.radians(float(STYLE.get("bald_within_degrees", 0.0)))   # a bare crown, for a man who has lost his


def direction(az, phi):
    """az 0 is the face (-Y), +90 the +X side, 180 the back; phi from straight up."""
    return Vector((math.sin(phi) * math.sin(az), -math.sin(phi) * math.cos(az), math.cos(phi)))


def angles(d):
    d = d.normalized()
    return math.atan2(d.x, -d.y), math.acos(max(-1.0, min(1.0, d.z)))


def scalp(d):
    hit = tree.ray_cast(C, d.normalized(), 0.4)
    return hit[0] if hit[0] is not None else C + d.normalized() * 0.1


def hairline(az):
    """How far down from the crown the hair grows, by bearing."""
    line = STYLE["hairline_degrees"]
    a = abs(math.degrees(az))
    if a <= 90.0:
        k = a / 90.0
        k = k * k * (3 - 2 * k)
        return math.radians(line["front"] + (line["side"] - line["front"]) * k)
    k = (a - 90.0) / 90.0
    k = k * k * (3 - 2 * k)
    return math.radians(line["side"] + (line["back"] - line["side"]) * k)


# ---------------------------------------------------------------- the clump pictures
CELLS, CW, CH = 8, 256, 512
COLUMNS = 4                     # the sheet is 4 x 2 clump pictures, 1024 x 1024
root_tone = np.array(STYLE["colour"]["root"], np.float32)
tip_tone = np.array(STYLE["colour"]["tip"], np.float32)
ROWS_OF_CELLS = CELLS // COLUMNS
albedo = np.zeros((CH * ROWS_OF_CELLS, CW * COLUMNS, 4), np.float32)
normal = np.zeros((CH * ROWS_OF_CELLS, CW * COLUMNS, 3), np.float32)
rough = np.zeros((CH * ROWS_OF_CELLS, CW * COLUMNS, 3), np.float32)
# A margin inside every cell stays clear, so neighbours never bleed in the far mips.
GUTTER = 6.0 / CW


def cell_uv(cell, across, along):
    """across 0..1 over the clump, along 0 at the root to 1 at the tip -> sheet UV (v up)."""
    column, row = cell % COLUMNS, cell // COLUMNS
    u = (column + GUTTER + across * (1.0 - 2.0 * GUTTER)) / COLUMNS
    top = 1.0 - row / ROWS_OF_CELLS
    return (u, top - (0.004 + along * 0.992) / ROWS_OF_CELLS)


V, X = np.mgrid[:CH, :CW].astype(np.float32)
v = V / (CH - 1)          # 0 at the root (top row), 1 at the tip
x = X / (CW - 1)
for cell in range(CELLS):
    crng = np.random.default_rng(1000 + cell + int(STYLE.get("seed", 0)))
    strands = int(crng.integers(46, 64))
    points = int(crng.integers(3, 8))                  # how many tips the clump ends in
    targets = np.sort(crng.uniform(0.14, 0.86, points))
    reach = crng.uniform(float(STYLE.get("shortest_tip", 0.70)), 1.0, points)            # each tip ends at its own length
    reach[int(crng.integers(0, points))] = 1.0
    cover = np.zeros((CH, CW), np.float32)
    shade = np.ones((CH, CW), np.float32)
    lean = np.zeros((CH, CW), np.float32)
    gather_from = float(STYLE.get("tips_from", 0.40))      # where along a clump the strands begin to part
    ragged = float(STYLE.get("ragged_roots", 0.0))
    gather = np.clip((v - gather_from) / (1.0 - gather_from), 0.0, 1.0)
    gather = gather * gather * (3 - 2 * gather)
    for index in range(strands):
        start = (index + crng.uniform(0.15, 0.85)) / strands * 0.94 + 0.03
        group = int(np.argmin(np.abs(targets - start)))
        own = targets[group] + crng.normal(0.0, 0.012)
        ends = reach[group] * crng.uniform(0.88, 1.0)
        wave = 0.012 * np.sin(v * crng.uniform(5.0, 11.0) + crng.uniform(0, 6.28))
        centre = start + (own - start) * gather ** 1.25 + wave * (0.3 + 0.7 * v)
        half = (0.5 / strands * 1.7) * (1.0 - 0.78 * np.clip(v / ends, 0, 1) ** 1.6) + 0.5 / CW
        distance = np.abs(x - centre)
        alive = np.clip((ends - v) * 90.0, 0.0, 1.0)
        # Where hair begins at a hairline, each strand starts at its own place: no card begins with a straight edge.
        alive *= np.clip((v - crng.uniform(0.0, 1.0) * ragged) * 70.0, 0.0, 1.0)
        mine = np.clip((half - distance) * CW * 0.9, 0.0, 1.0) * alive
        # Strands take their tone in small bunches, with a little of their own.
        if index % 5 == 0:
            bunch = crng.uniform(0.93, 1.04) * (1.07 if crng.random() < float(STYLE["colour"].get("streak_share", 0.15)) else 1.0)
        tone = bunch * crng.uniform(0.98, 1.02)
        wins = mine > cover
        shade = np.where(wins, tone, shade)
        lean = np.where(wins, np.clip((x - centre) / np.maximum(half, 1e-4), -1, 1), lean)
        cover = np.maximum(cover, mine)
    if STYLE.get("texture") == "coils":
        # Tightly curled hair: a dense mass of small rings, bumpy at its edge, with light on each curl.
        cover = np.zeros((CH, CW), np.float32)
        shade = np.full((CH, CW), 0.72, np.float32)
        lean = np.zeros((CH, CW), np.float32)
        for index in range(420):
            cx, cy = crng.uniform(0.07, 0.93), crng.uniform(0.02, 0.98)
            size = crng.uniform(7.0, 12.0)
            dx, dy = (x - cx) * CW, (v - cy) * CH
            away = np.sqrt(dx * dx + dy * dy)
            mine = np.clip((0.42 * size - np.abs(away - size)) * 0.9, 0.0, 1.0)
            tone = crng.uniform(0.86, 1.14)
            wins = mine > cover
            shade = np.where(wins, tone, shade)
            lean = np.where(wins, np.clip(dx / size, -1, 1), lean)
            cover = np.maximum(cover, mine)
        core = np.clip((0.40 - np.abs(x - 0.5)) * 30.0, 0, 1) * np.clip((v - 0.03) * 40.0, 0, 1) * np.clip((0.93 - v) * 30.0, 0, 1)
        cover = np.maximum(cover, core)
    # The root end is a solid mass; the roots themselves fade so no strip starts with a hard edge.
    body = np.clip((v - ragged) * 40.0, 0, 1) * np.clip((0.985 - np.abs(x - 0.5) * 2.0) * 40.0, 0, 1) * (1.0 - np.clip((v - (float(STYLE.get("tips_from", 0.40)) - 0.1)) / 0.22, 0, 1))
    alpha = np.maximum(cover, body) * np.clip((v - 0.01) * 9.0, 0, 1)   # roots fade in: no strip starts with an edge
    if STYLE.get("texture") == "coils":
        alpha = cover
    ramp = v[..., None] ** 0.85
    colour = root_tone * (1 - ramp) + tip_tone * ramp
    fine = 0.97 + 0.03 * np.sin(x * 400.0 + np.sin(v * 9.0) * 3.0)
    block = np.clip(colour * (shade * fine)[..., None], 0, 1)
    alpha *= np.clip((np.minimum(x, 1.0 - x) - 3.0 / CW) * CW / 2.0, 0, 1)
    rows = slice((cell // COLUMNS) * CH, (cell // COLUMNS + 1) * CH)
    cols = slice((cell % COLUMNS) * CW, (cell % COLUMNS + 1) * CW)
    albedo[rows, cols, :3] = block
    albedo[rows, cols, 3] = alpha
    normal[rows, cols, 0] = 0.5 + 0.12 * lean
    normal[rows, cols, 1] = 0.5
    normal[rows, cols, 2] = 1.0
    rough[rows, cols, :] = (0.58 + 0.10 * (1.0 - shade.clip(0.8, 1.1)) + 0.06 * v)[..., None]


def picture(name, data, colour_space, alpha=None):
    height, width = data.shape[:2]
    image = bpy.data.images.new(name, width, height, alpha=True)
    image.colorspace_settings.name = colour_space
    full = np.ones((height, width, 4), np.float32)
    full[:, :, :3] = data[:, :, :3]
    if alpha is not None:
        full[:, :, 3] = alpha
    image.pixels.foreach_set(full[::-1].ravel())
    image.filepath_raw = str(OUT / (name + ".png"))
    image.file_format = "PNG"
    image.save()
    image.pack()
    return image


NAME = STYLE["name"]
albedo_image = picture(NAME + "_hair_albedo", albedo, "sRGB", albedo[:, :, 3])
normal_image = picture(NAME + "_hair_normal", normal, "Non-Color")
rough_image = picture(NAME + "_hair_roughness", rough, "Non-Color")


def material(name, cutout):
    made = bpy.data.materials.new(name)
    made.use_nodes = True
    nodes, links = made.node_tree.nodes, made.node_tree.links
    shader = nodes["Principled BSDF"]
    colour = nodes.new("ShaderNodeTexImage")
    colour.image = albedo_image
    links.new(colour.outputs["Color"], shader.inputs["Base Color"])
    if cutout:
        # A hard threshold on the alpha is what the exporter writes as MASK.
        clip = nodes.new("ShaderNodeMath")
        clip.operation = "GREATER_THAN"
        clip.inputs[1].default_value = 0.45
        links.new(colour.outputs["Alpha"], clip.inputs[0])
        links.new(clip.outputs[0], shader.inputs["Alpha"])
    roughness = nodes.new("ShaderNodeTexImage")
    roughness.image = rough_image
    links.new(roughness.outputs["Color"], shader.inputs["Roughness"])
    bump = nodes.new("ShaderNodeTexImage")
    bump.image = normal_image
    bend = nodes.new("ShaderNodeNormalMap")
    bend.inputs["Strength"].default_value = 0.6
    links.new(bump.outputs["Color"], bend.inputs["Color"])
    links.new(bend.outputs["Normal"], shader.inputs["Normal"])
    made.use_backface_culling = False
    made.surface_render_method = "DITHERED"
    return made


# ---------------------------------------------------------------- the under-cap
verts, faces, uvs = [], [], []
AZ, PH = 48, 18
grid = {}
for i in range(AZ):
    az = -math.pi + math.tau * i / AZ
    limit = hairline(az) + math.radians(float(STYLE.get("cap_past_hairline_degrees", -3.0)))
    for j in range(PH + 1):
        phi = BALD + (limit - BALD) * j / PH
        d = direction(az, max(phi, 0.001))
        at = scalp(d)
        grid[(i, j)] = len(verts)
        verts.append(at + (at - C).normalized() * float(STYLE.get("cap_lift_m", 0.0035)))
        # The cap samples the solid root of the first clump picture.
        uvs.append(cell_uv(0, 0.3 + 0.4 * (i % 2), 0.03 + 0.2 * j / PH))
for i in range(AZ):
    for j in range(PH):
        a, b, c, d_ = grid[(i, j)], grid[((i + 1) % AZ, j)], grid[((i + 1) % AZ, j + 1)], grid[(i, j + 1)]
        faces.append((a, d_, c, b))
cap_mesh = bpy.data.meshes.new("HairUnderCap")
cap_mesh.from_pydata([tuple(p) for p in verts], [], faces)
layer = cap_mesh.uv_layers.new(name="UVMap")
for loop in cap_mesh.loops:
    layer.data[loop.index].uv = uvs[loop.vertex_index]
around = cap_mesh.uv_layers.new(name="Along")
for loop in cap_mesh.loops:
    i, j = divmod(loop.vertex_index, PH + 1)
    around.data[loop.index].uv = (i / AZ, 1.0 - j / PH)
cap_mesh.uv_layers.active = cap_mesh.uv_layers["UVMap"]
cap_mesh.uv_layers["UVMap"].active_render = True
for polygon in cap_mesh.polygons:
    polygon.use_smooth = True
cap = bpy.data.objects.new("HairUnderCap", cap_mesh)
cap.data.materials.append(material(NAME + "_hair_cap", False))

# ---------------------------------------------------------------- the clump cards
whorl = direction(math.radians(STYLE["whorl"]["bearing_degrees"]), math.radians(STYLE["whorl"]["down_degrees"]))
UP = Vector((0, 0, 1))
ROWS, COLS = int(STYLE.get("rows", 10)), int(STYLE.get("columns", 5))
card_verts, card_faces, card_uvs, card_along = [], [], [], []
cards = []
spacing = float(STYLE["root_spacing_m"])
phi_step = spacing / 0.10
phi = math.radians(5.0)
while phi < math.radians(140.0):
    ring = max(3, int(round(math.tau * 0.10 * math.sin(phi) / (spacing * (0.8 if phi < math.radians(40.0) else 1.0)))))
    offset = rng.random()
    for k in range(ring):
        az = -math.pi + math.tau * (k + offset + rng.uniform(-0.25, 0.25)) / ring
        p = phi + rng.uniform(-0.35, 0.35) * phi_step
        if p < max(math.radians(3.0), BALD + math.radians(2.0)) or p > hairline(az) - math.radians(float(STYLE.get("root_margin_degrees", 3.0))):
            continue
        cards.append((az, p))
    phi += phi_step
whorl_direction = direction(math.radians(STYLE["whorl"]["bearing_degrees"]), math.radians(STYLE["whorl"]["down_degrees"]))
whorl_east = whorl_direction.cross(Vector((0, 0, 1))).normalized()
whorl_north = whorl_east.cross(whorl_direction).normalized()
# The top layer of a parted head: cards rooted along the part itself, combed to either side.
part = STYLE["part"]
cards = [(az, phi, 0.0) for az, phi in cards]
for index in range(int(part.get("cards", 0))):
    # Part cards stop where the combing stops: behind that the hair falls away from the whorl.
    last_y = float(part.get("cards_back_y_m", part["back_y_m"]))
    y = part["front_y_m"] + (last_y - part["front_y_m"]) * (index + rng.uniform(0.2, 0.8)) / int(part["cards"])
    side = 1.0 if index % 2 == 0 else -1.0
    flat = Vector((float(part["x_m"]) - side * float(part.get("interleave_m", 0.010)), y - C.y, 0.0))
    up = math.sqrt(max(0.1 * 0.1 - flat.length_squared, 1e-6))
    az, phi = angles(Vector((flat.x, flat.y, up)))
    if phi < hairline(az) - math.radians(4.0):
        cards.append((az, phi, side))
for index in range(int(STYLE["fringe"].get("hairline_cards", 0))):
    span = float(STYLE["fringe"].get("hairline_span_degrees", float(STYLE["fringe"]["exit_half_width_degrees"]) - 4.0))
    az = math.radians(-span + 2.0 * span * (index + rng.uniform(0.2, 0.8)) / int(STYLE["fringe"]["hairline_cards"]))
    phi = hairline(az) - math.radians(rng.uniform(7.0, 16.0))
    # On the part's own side the hairline is combed away into the side of the bob; only the other side is fringe.
    own_side = scalp(direction(az, phi)).x > float(part["x_m"]) + 0.003
    cards.append((az, phi, (3.0 if bool(STYLE["fringe"].get("both_sides", False)) else 4.0) if own_side else -3.0))
# The whorl: a rosette of top cards radiating from it, so the crown is covered by hair lying one way.
for index in range(int(STYLE["whorl"].get("cards", 0))):
    turn = math.tau * (index + rng.uniform(0.2, 0.8)) / int(STYLE["whorl"]["cards"])
    spot = (whorl_direction + (whorl_east * math.cos(turn) + whorl_north * math.sin(turn)) * float(STYLE["whorl"].get("ring", 0.16))).normalized()
    az, phi = angles(spot)
    if phi < hairline(az) - math.radians(6.0):
        cards.append((az, phi, 2.0))
# Lowest first, so each layer lies over the one beneath it.
cards.sort(key=lambda card: -card[1] / hairline(card[0]))
tiers = STYLE["tiers"]
zones = STYLE["zones"]
report = {"cards": 0, "tiers": {}}


def zone_at(az):
    bearing = abs(math.degrees(az))
    if bearing < float(STYLE["fringe"]["exit_half_width_degrees"]):
        return "fringe"
    if bearing < float(STYLE["fringe"]["exit_half_width_degrees"]) + float(STYLE.get("temple_width_degrees", 0.0)):
        return "temple"
    return "nape" if bearing > 125.0 else "sides"


for az, phi, forced in cards:
    depth = phi / hairline(az)                       # 0 at the crown, 1 at the hairline
    d = direction(az, phi)
    side_of_part = (1.0 if forced > 0 else -1.0) if abs(forced) in (1.0, 3.0, 4.0) else (1.0 if scalp(d).x > float(part["x_m"]) else -1.0)
    tier = "fringe" if abs(forced) == 3.0 else "part" if forced != 0.0 else ("crown" if depth < 0.5 else ("nape" if abs(math.degrees(az)) > 125 else "sides"))
    spec = tiers[tier]
    report["tiers"][tier] = report["tiers"].get(tier, 0) + 1
    # Round the whorl the hair lies low and narrow: nothing stands up there with a square end.
    near_whorl = min(1.0, (scalp(d) - scalp(whorl)).length / float(STYLE["whorl"].get("low_within_m", 0.05)))
    lift = spec["lift_m"] * rng.uniform(0.9, 1.1) * (0.3 + 0.7 * near_whorl)
    width = spec["width_m"] * rng.uniform(0.85, 1.15) * (0.6 + 0.4 * near_whorl)
    sweep = math.radians(rng.uniform(-1, 1) * spec.get("sweep_jitter_degrees", 6.0))
    # Walk the path in small steps: over the scalp, combed away from the part
    # and down, all the way to the hairline; then out to the bell of the bob
    # and under at the hem.
    step = 0.004
    path = []
    here = d.copy()
    walked = 0.0
    fallen = 0.0
    hang = 1.0
    point = None
    left = None
    heading = Vector((0, -1, 0))
    carried = Vector((0, 0, 0))
    wave_phase = float(STYLE.get("wave_phase", 0.0)) + (0.0 if side_of_part > 0 else math.pi)
    while fallen < hang and len(path) < 260:
        walk_limit = float(spec.get("walk_m", 0.30))
        if left is None and "walk_m" in spec and walked >= walk_limit:
            break       # short hair: the card ends where it lies
        if left is None and angles(here)[1] < hairline(angles(here)[0]) + math.radians(2.0) and walked < 0.30:
            away = here * here.dot(whorl) - whorl
            flow = away.normalized() if away.length > 1e-4 else Vector((0, -1, 0))
            down = here * here.dot(UP) - UP
            down = down.normalized() if down.length > 1e-4 else flow
            surface = scalp(here)
            combed = (float(part["back_y_m"]) - surface.y) / float(part.get("blend_m", 0.035))
            combed = max(0.0, min(1.0, combed))
            combed = combed * combed * (3 - 2 * combed)
            comb_to = str(spec.get("comb_to", "side"))
            if comb_to in ("back", "front"):
                # Combed one way all over: straight back off the face, or straight forward into a fringe.
                aside = Vector((0, 1 if comb_to == "back" else -1, 0))
                aside = aside - here * aside.dot(here)
                weight = float(spec["comb"])
                flow = (flow * (1.0 - weight) + aside * weight * 1.8)
                flow = flow.normalized() if flow.length > 1e-4 else down
            elif combed > 0.0:
                # In front of the whorl the hair is combed straight off the part.
                # Low on the side of the head, sideways has already become down.
                aside = Vector((side_of_part, 0, 0))
                if side_of_part > 0.0:
                    # On the part's own side the front corner is brushed back over the temple,
                    # so it leaves the scalp above the ear and never hangs in front of the face.
                    frontal = max(0.0, min(1.0, (-0.02 - (surface.y - C.y)) / 0.05))
                    aside = Vector((1.0, float(part.get("brush_back", 0.0)) * frontal, 0.0)).normalized()
                aside = aside - here * aside.dot(here)
                weight = float(spec["comb"]) * combed
                flow = (flow * (1.0 - weight) + aside * weight * 1.8)
                flow = flow.normalized() if flow.length > 1e-4 else down
            flow = (flow * (1.0 - spec.get("gravity", 0.3)) + down * spec.get("gravity", 0.3)).normalized()
            flow = (Matrix.Rotation(sweep, 3, here) @ flow).normalized()
            if "wave_degrees" in spec:
                # A set wave: the hair swings from side to side as it goes.
                flow = (Matrix.Rotation(math.radians(float(spec["wave_degrees"])) * math.sin(math.tau * walked / float(spec["wave_length_m"]) + wave_phase), 3, here) @ flow).normalized()
            rise = lift * min(1.0, walked / float(STYLE["rise_over_m"])) ** 0.7
            if "walk_m" in spec:
                rise *= 1.0 - 0.75 * min(1.0, walked / walk_limit) ** 3     # short hair lies down at its end
            if "wave_ridge_m" in spec:
                rise += float(spec["wave_ridge_m"]) * (0.5 + 0.5 * math.cos(math.tau * walked / float(spec["wave_length_m"]) + wave_phase))
            point = surface + (surface - C).normalized() * (float(STYLE.get("root_clear_m", 0.007)) + rise)
            here = (here + flow * (step / 0.10)).normalized()
            heading = flow
            walked += step
        else:
            if left is None:
                flat = Vector((point.x - C.x, point.y - C.y, 0.0))
                zone_name = zone_at(angles(point - C)[0])
                # Hair on the part's own side never becomes fringe: it joins the side of the bob.
                if forced == 4.0 or (zone_name == "fringe" and side_of_part > 0.0 and point.x > float(part["x_m"])
                        and not bool(STYLE["fringe"].get("both_sides", False))):
                    zone_name = "part_side" if "part_side" in zones else "temple"
                if zone_name == "part_side" and bool(part.get("drop_front_corner", False)):
                    # A lock that would hang in front of the eye on the part's side is not grown at all:
                    # the brushed-back hair above it covers that corner.
                    path = []
                    break
                zone = zones[zone_name]
                hem = float(zone.get("hem_z", C.z)) + float(zone.get("hem_slope", 0.0)) * (point.x - C.x)
                hang = max(0.02, point.z - hem) * rng.uniform(0.95, 1.05)
                if "hang_m" in zone:
                    hang = float(zone["hang_m"]) * rng.uniform(0.85, 1.15)
                left = {"out": flat.normalized() if flat.length > 1e-4 else Vector((0, -1, 0)), "radius": flat.length, "z": point.z,
                        "stood": (point - scalp(point - C)).length,
                        "bulge": float(zone["bulge_m"]) * rng.uniform(0.92, 1.08) * (float(zone.get("under_share", 1.0))
                                + (1.0 - float(zone.get("under_share", 1.0))) * min(1.0, walked / float(STYLE["rise_over_m"]))),
                        "forward": float(zone.get("forward_part_side_m", zone.get("forward_m", 0.0)) if side_of_part > 0.0 and point.x > 0.0
                                else zone.get("forward_m", 0.0)) * rng.uniform(0.7, 1.3),
                        "aside": float(zone.get("aside_m", 0.0)) * side_of_part,
                        "wave": float(zone.get("wave_m", 0.0)), "waves": float(zone.get("wave_count", 2.0)),
                        # neighbouring locks wave together, so the waves read as bands round the head
                        "wave_at": float(zone.get("wave_phase", 0.0)) + rng.uniform(-0.35, 0.35),
                        "curl": float(zone["curl_m"]) * rng.uniform(0.85, 1.15),
                        "swept": float(zone.get("sweep_m", 0.0)) * rng.uniform(0.8, 1.2) * (1.0 if side_of_part < 0.0 else 0.0)}
            fallen += step
            k = min(1.0, fallen / hang)
            ease = min(1.0, k / 0.55)
            ease = ease * ease * (3 - 2 * ease)
            under = max(0.0, (k - 0.55) / 0.45) ** 1.5
            stand = left["stood"] + (left["bulge"] - left["stood"]) * ease     # how far off the head the hair stands here
            radius = left["radius"] + (left["bulge"] - left["stood"]) * ease - left["curl"] * under
            radius += left["wave"] * math.sin(math.tau * left["waves"] * k + left["wave_at"]) * min(1.0, k * 3.0)
            radius = max(radius, min(left["radius"], 0.06))      # turning under never carries the hair in through the neck
            # The hair keeps the way it was going for a little, so it turns over the edge and does not kink.
            carried += Vector((heading.x, heading.y, 0.0)) * step * 0.6 * max(0.0, 1.0 - k * 2.2) ** 2
            point = Vector((C.x + left["out"].x * radius, C.y + left["out"].y * radius, left["z"] - k * hang)) + carried
            point.x -= left["swept"] * k
            # Beside the face the hair comes forward onto the cheek and softens its edge.
            point.y -= left["forward"] * (k * k * (3 - 2 * k))
            point.x += left["aside"] * (k * k * (3 - 2 * k))
            # Hair lies on the hair beneath it: never closer to the head than it stands.
            inward = point - C
            struck = tree.ray_cast(C, inward.normalized(), 0.4)[0]
            keep = max(0.008, stand - left["curl"] * under)
            # Only where there is head or neck behind the hair: below the jaw there is nothing to lie on,
            # and the hair must not be thrown out to an imagined surface.
            if struck is not None and (struck - C).length < 0.16 and inward.length < (struck - C).length + keep:
                point = struck + (struck - C).normalized() * keep
        path.append(point.copy())
    for index in range(2, len(path)):
        if (path[index] - path[index - 1]).dot(path[index - 1] - path[index - 2]) <= 0.0:
            path = path[:index]
            break
    if len(path) < 6:
        continue
    previous_side = None
    report.setdefault("paths", []).append({"tier": tier, "forced": forced, "zone": zone_name if left is not None else "", "root_bearing": round(math.degrees(az), 1),
            "root_depth": round(depth, 2), "exit_bearing": round(math.degrees(angles(Vector((left["out"].x, left["out"].y, 0.0001)))[0]), 1) if left is not None else None,
            "face_side": [[round(q.x, 3), round(q.y, 3), round(q.z, 3)] for q in path if q.x > 0.045 and q.y < -0.075 and 1.27 < q.z < 1.38][:3]})
    cell = rng.randrange(CELLS)
    mirror = False   # a mirrored chart flips the tangent's hand; eight pictures are variety enough
    twist = math.radians(spec.get("twist_degrees", 14.0)) * rng.uniform(-1, 1)
    cup = spec.get("cup", 0.2) * rng.uniform(0.7, 1.3)
    base = len(card_verts)
    # A card gets as many rows as its length needs: about one every two centimetres, so a long card
    # follows the head and a short hang still has shape. "rows" in the style is the fewest.
    length = sum((path[i + 1] - path[i]).length for i in range(len(path) - 1))
    rows_here = ROWS if "row_every_m" not in STYLE else max(4, min(int(STYLE.get("max_rows", 18)), int(math.ceil(length / float(STYLE["row_every_m"]))) + 1))
    for row in range(rows_here):
        t = row / (rows_here - 1)
        f = t * (len(path) - 1)
        lo = int(math.floor(f))
        hi = min(lo + 1, len(path) - 1)
        centre = path[lo].lerp(path[hi], f - lo)
        tangent = (path[min(lo + 2, len(path) - 1)] - path[max(lo - 2, 0)]).normalized()
        outward = (centre - C).normalized()
        side = outward.cross(tangent)
        side = side.normalized() if side.length > 1e-4 else (previous_side or Vector((1, 0, 0)))
        if previous_side is not None:
            if side.dot(previous_side) < 0.0:
                side = -side
            # (No easing from row to row: with a row every two centimetres the easing lagged behind the
            # surface and turned whole cards to show their undersides.)
        previous_side = side.copy()
        outward = tangent.cross(side).normalized()
        side = (Matrix.Rotation(twist * t, 3, tangent) @ side).normalized()
        w = width * (1.0 - 0.42 * t)
        for col in range(COLS):
            s = col / (COLS - 1) * 2.0 - 1.0
            card_verts.append(centre + side * (s * w * 0.5) - outward * (cup * w * s * s))
            card_uvs.append(cell_uv(cell, 0.5 + s * 0.5, t))   # this way round the chart is right-handed in the export
            # A second chart the shader reads for motion: across, and 0 at the root to 1 at the tip.
            card_along.append((col / (COLS - 1), 1.0 - t))
    for row in range(rows_here - 1):
        for col in range(COLS - 1):
            a = base + row * COLS + col
            card_faces.append((a, a + 1, a + COLS + 1, a + COLS))
    report["cards"] += 1
if "bun" in STYLE:
    knot = STYLE["bun"]
    seat = scalp(direction(math.radians(float(knot["bearing_degrees"])), math.radians(float(knot["down_degrees"]))))
    out = (seat - C).normalized()
    east = out.cross(Vector((0, 0, 1))).normalized()
    north = east.cross(out).normalized()
    radius = float(knot["radius_m"])
    middle = seat + out * radius * float(knot.get("stand", 0.55))
    base = len(card_verts)
    LAT, LON = 8, 14
    for i in range(LAT + 1):
        a = math.pi * i / LAT
        for j in range(LON):
            b = math.tau * j / LON
            card_verts.append(middle + (east * math.sin(a) * math.cos(b) + north * math.sin(a) * math.sin(b)) * radius
                    + out * math.cos(a) * radius * float(knot.get("depth", 0.7)))
            # The knot is wound hair: the strands run round it.
            card_uvs.append(cell_uv(1, (j % 2) * 0.8 + 0.1, 0.16 + 0.3 * i / LAT))
            card_along.append((j / LON, 1.0))
    for i in range(LAT):
        for j in range(LON):
            a, b = base + i * LON + j, base + i * LON + (j + 1) % LON
            card_faces.append((a, b, b + LON, a + LON))
card_mesh = bpy.data.meshes.new("HairCards")
card_mesh.from_pydata([tuple(p) for p in card_verts], [], card_faces)
layer = card_mesh.uv_layers.new(name="UVMap")
for loop in card_mesh.loops:
    layer.data[loop.index].uv = card_uvs[loop.vertex_index]
for polygon in card_mesh.polygons:
    polygon.use_smooth = True
import os
if os.environ.get("HAIR_NO_ALONG") != "1":
    second = card_mesh.uv_layers.new(name="Along")
    for loop in card_mesh.loops:
        second.data[loop.index].uv = card_along[loop.vertex_index]
# The picture chart, not the motion chart, is the one tangents are made from.
card_mesh.uv_layers.active = card_mesh.uv_layers["UVMap"]
card_mesh.uv_layers["UVMap"].active_render = True
if bool(STYLE.get("mirror", False)):
    for made_mesh in (card_mesh, cap_mesh):
        for vertex in made_mesh.vertices:
            vertex.co.x = 2.0 * C.x - vertex.co.x
        made_mesh.flip_normals()
        made_mesh.update()
roundness = float(STYLE.get("round_normals", 0.0))    # off: the shader rounds the shading instead
if roundness > 0.0:
    for made_mesh in (card_mesh, cap_mesh):
        rounded = []
        for vertex in made_mesh.vertices:
            # Below the skull the centre follows the hair down, so hanging hair is lit from its outside.
            out_from = Vector((C.x, C.y, min(C.z, vertex.co.z + 0.02)))
            radial = (vertex.co - out_from)
            radial = radial.normalized() if radial.length > 1e-5 else Vector((0, 0, 1))
            rounded.append(tuple((vertex.normal * (1.0 - roundness) + radial * roundness).normalized()))
        made_mesh.normals_split_custom_set_from_vertices(rounded)
card_mesh.transform(FIT)
cap_mesh.transform(FIT)
card_object = bpy.data.objects.new("HairCards", card_mesh)
card_object.data.materials.append(material(NAME + "_hair_cards", True))

# ---------------------------------------------------------------- export: hair only, in place
# Everything of the source is dropped from memory (the file on disk is never
# written), so the export and the saved scene hold the hair and nothing else.
for other in list(bpy.data.objects):
    bpy.data.objects.remove(other, do_unlink=True) if other not in (cap, card_object) else None
scene = bpy.context.scene
scene.collection.objects.link(cap)
scene.collection.objects.link(card_object)
bpy.ops.object.select_all(action="DESELECT")
for made in (cap, card_object):
    made.select_set(True)
bpy.context.view_layer.objects.active = card_object
bpy.ops.export_scene.gltf(filepath=str(OUT / (NAME + "_hair_cards.glb")), export_format="GLB", use_selection=True,
        export_yup=True, export_tangents=True, export_materials="EXPORT", export_apply=True)
bpy.ops.outliner.orphans_purge(do_local_ids=True, do_linked_ids=True, do_recursive=True)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT / (NAME + "_hair_cards.blend")), copy=True)
report["triangles"] = len(card_faces) * 2 + len(faces) * 2
report["style"] = STYLE_PATH.name
look = STYLE.get("cap", {})
real_centre = FIT @ C
(OUT / (NAME + "_hair_look.json")).write_text(json.dumps({"cap_shade": float(look.get("shade", 0.55)), "cap_feather": float(look.get("feather", 0.0)),
        "cap_bald": 1.0 if BALD > 0.0 else 0.0, "underside": float(STYLE.get("underside", 0.62)),
        "roundness": float(STYLE.get("shade_roundness", 0.6)),
        # dark hair is seen by its shine, not its colour
        "gloss": float(STYLE.get("gloss", 0.15)),
        # the skull's centre in the engine's axes (Y up), for the rounded shading
        "hair_centre": [real_centre.x, real_centre.z, -real_centre.y]}, indent=1))
(OUT / "BUILD.json").write_text(json.dumps(report, indent=1))
print("HAIR CARDS", json.dumps(report))
