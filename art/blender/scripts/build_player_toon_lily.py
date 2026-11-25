"""The player as a 1930s rubber-hose cartoon of Lily, for Orison (Lily, 2026-11-25).

"apply the same style and animation to the entire player model, reimagine the head
as a cell shaded [1930s flapper cartoon] caricature of Lily, do the clothes as well,
all black and white. cute maid outfit, hyperfemme."

The figure matches the first-person rubber-hose arm (build_first_person_hose_arm.py):
flat black and white, ink-lined, jointless hose limbs ending in puffy white gloves
with bell cuffs. It is drawn in the Fleischer-era flapper idiom (a big round head,
huge lashed eyes, a cupid's-bow mouth) as Lily herself with her full black bob, not as
any existing cartoon character.

  Head    white face, a blond spiky anime bob (paper-white locks with ink strand lines:
          pointed bangs, jaw-length sides, face-framing front locks, an ahoge),
          big black eyes with white catch-lights and three lashes, brows, a button
          nose, a cupid's-bow mouth, and a frilled maid's headband.
  Dress   black hourglass bodice with a sweetheart neckline, puff sleeves with white
          cuffs, a black choker with a white bow, a bell skirt over a scalloped white
          petticoat, a frilled white apron with a heart bib, a white waistband and a
          big white bow at the back.
  Limbs   black hose arms (12 bones each) into white gloves; black stocking hose legs
          (12 bones each) with white frilled stocking tops and round black Mary Janes
          with white bows.

Rig: every limb bone, hand, foot, hips, chest, neck and head bone is unparented: the
runtime (game/scripts/player/toon_player_avatar.gd) sets each one's global pose and
stretches the limb bones along their length, so no bone may inherit a stretched
parent's shear. Only the finger and thumb bones are children (of their hand).
The figure is 1.524 m tall, the player's height.

Run:  blender -b -P art/blender/scripts/build_player_toon_lily.py -- [--review DIR]

Writes game/assets/characters/player_toon/player_toon_lily.glb. Coordinates are metres,
Z up, the figure faces -Y with her left hand at +X (glTF: +Z forward, +Y up).
"""
import math
import sys
from pathlib import Path

import bpy
import bmesh
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "game/assets/characters/player_toon/player_toon_lily.glb"

INK = (0.02, 0.02, 0.02, 1.0)
PAPER = (0.96, 0.96, 0.94, 1.0)
HEIGHT = 1.524

LIMB_BONES = 12
SIDES = 16
RINGS_PER_BONE = 3
ARM_ROOT = Vector((0.165, 0.0, 0.975))
ARM_END = Vector((0.300, -0.020, 0.600))   # hands clear of the bell skirt
ARM_RADIUS = 0.021
LEG_ROOT = Vector((0.072, 0.0, 0.640))
LEG_END = Vector((0.078, 0.0, 0.080))
LEG_RADIUS = 0.030
STOCKING_TOP_T = 0.44   # along the leg, where the white frill sits

HEAD_CENTRE = Vector((0.0, -0.005, 1.270))
HEAD_RADII = (0.190, 0.176, 0.182)   # x, y (depth), z
NECK = (Vector((0, 0, 1.030)), Vector((0, 0, 1.115)), 0.030)
HIPS = Vector((0, 0, 0.700))
CHEST = Vector((0, 0, 0.900))

# The glove from the first-person arm, at the figure's scale (built along +Y from the
# wrist, palm toward -Z), and its bell cuff, whose throat fits the arm hose.
FINGERS = [
    ("Index", 0.026, (0.030, 0.026), 0.0125),
    ("Middle", 0.0, (0.033, 0.028), 0.013),
    ("Ring", -0.026, (0.029, 0.025), 0.0122),
]
GLOVE_SCALE = 1.0
KNUCKLE = 0.078
THUMB_BASE = Vector((0.040, 0.030, -0.004))
THUMB_DIR = Vector((0.75, 0.55, -0.35)).normalized()
THUMB_SEGMENTS = (0.024, 0.022)
THUMB_RADIUS = 0.0128


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def material(name, rgba):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = rgba
    bsdf.inputs["Roughness"].default_value = 0.9
    mat.diffuse_color = rgba
    return mat


# ---------------------------------------------------------------- primitives
# Every builder appends (vertex, {group: weight}) through Part, and every part is a
# closed volume; new_object recalculates normals outward and the build checks it.

class Part:
    def __init__(self, bm):
        self.bm = bm
        self.weights = {}

    def vert(self, co, weights):
        v = self.bm.verts.new(co)
        self.weights[v] = weights
        return v

    def face(self, verts):
        self.bm.faces.new(verts)


def ellipsoid(part, centre, radii, weights, rotation=Matrix.Identity(3), segments=16, rings=10):
    grid = []
    for r in range(1, rings):
        phi = math.pi * r / rings
        row = []
        for s in range(segments):
            theta = 2 * math.pi * s / segments
            local = Vector((math.sin(phi) * math.cos(theta) * radii[0],
                            math.sin(phi) * math.sin(theta) * radii[1],
                            math.cos(phi) * radii[2]))
            row.append(part.vert(centre + rotation @ local, weights))
        grid.append(row)
    top = part.vert(centre + rotation @ Vector((0, 0, radii[2])), weights)
    bottom = part.vert(centre + rotation @ Vector((0, 0, -radii[2])), weights)
    for r in range(len(grid) - 1):
        for s in range(segments):
            part.face((grid[r][s], grid[r][(s + 1) % segments], grid[r + 1][(s + 1) % segments], grid[r + 1][s]))
    for s in range(segments):
        part.face((top, grid[0][(s + 1) % segments], grid[0][s]))
        part.face((bottom, grid[-1][s], grid[-1][(s + 1) % segments]))


def lathe(part, profile, weights, sides=32, squash=1.0, centre=Vector((0, 0, 0)), wobble=None,
          start=0.0, sweep=2 * math.pi):
    """A closed solid of revolution about Z: profile is [(radius, z)], capped at both
    ends. squash scales depth (Y). wobble(theta, i) multiplies the radius (scallops).
    A partial sweep is closed by its two flat ends through the axis."""
    full = sweep >= 2 * math.pi - 1e-6
    count = sides if full else sides + 1
    rings = []
    for i, (radius, z) in enumerate(profile):
        ring = []
        for s in range(count):
            a = start + sweep * s / sides
            k = wobble(a, i) if wobble else 1.0
            ring.append(part.vert(centre + Vector((radius * k * math.sin(a), -radius * k * squash * math.cos(a), z)), weights))
        rings.append(ring)
    span = sides
    for r in range(len(rings) - 1):
        for s in range(span):
            part.face((rings[r][s], rings[r][(s + 1) % count], rings[r + 1][(s + 1) % count], rings[r + 1][s]))
    axis = [part.vert(centre + Vector((0, 0, z)), weights) for _r, z in profile] if not full else None
    bottom = axis[0] if axis else part.vert(centre + Vector((0, 0, profile[0][1])), weights)
    top = axis[-1] if axis else part.vert(centre + Vector((0, 0, profile[-1][1])), weights)
    for s in range(span):
        part.face((bottom, rings[0][(s + 1) % count], rings[0][s]))
        part.face((top, rings[-1][s], rings[-1][(s + 1) % count]))
    if axis:
        for r in range(len(rings) - 1):
            part.face((axis[r], axis[r + 1], rings[r + 1][0], rings[r][0]))
            part.face((axis[r], rings[r][-1], rings[r + 1][-1], axis[r + 1]))


def frame_along(direction, side_hint):
    """Rotation taking +Y to direction, with +Z toward side_hint."""
    y = direction.normalized()
    z = (side_hint - y * side_hint.dot(y)).normalized()
    x = y.cross(z)
    return Matrix((x, y, z)).transposed()


def hose(part, root, end, radius, bone_prefix, side_hint, frills=()):
    """A jointless tube from root to end weighted along LIMB_BONES bones, with
    optional white frill rings handled by the caller (positions only here)."""
    length = (end - root).length
    rot = frame_along(end - root, side_hint)
    step = length / LIMB_BONES
    rings = LIMB_BONES * RINGS_PER_BONE + 1
    grid = []
    for r in range(rings):
        y = length * r / (rings - 1)
        f = min(max(y / step - 0.5, 0.0), LIMB_BONES - 1.0)
        low = int(math.floor(f))
        high = min(low + 1, LIMB_BONES - 1)
        t = f - low
        weights = {"%s_%02d" % (bone_prefix, low): 1.0 - t}
        if high != low:
            weights["%s_%02d" % (bone_prefix, high)] = t
        row = []
        for s in range(SIDES):
            a = 2 * math.pi * s / SIDES
            row.append(part.vert(root + rot @ Vector((radius * math.cos(a), y, radius * math.sin(a))), weights))
        grid.append(row)
    for r in range(rings - 1):
        for s in range(SIDES):
            part.face((grid[r][s], grid[r][(s + 1) % SIDES], grid[r + 1][(s + 1) % SIDES], grid[r + 1][s]))
    for end_row, y, bone in ((grid[0], 0.0, 0), (grid[-1], length, LIMB_BONES - 1)):
        cap = part.vert(root + rot @ Vector((0, y, 0)), {"%s_%02d" % (bone_prefix, bone): 1.0})
        for s in range(SIDES):
            part.face((cap, end_row[(s + 1) % SIDES], end_row[s]))


def limb_weight(prefix, t):
    f = min(max(t * LIMB_BONES - 0.5, 0.0), LIMB_BONES - 1.0)
    low = int(math.floor(f))
    high = min(low + 1, LIMB_BONES - 1)
    w = {"%s_%02d" % (prefix, low): 1.0 - (f - low)}
    if high != low:
        w["%s_%02d" % (prefix, high)] = f - low
    return w


# ---------------------------------------------------------------- the figure

def head_parts(skin, ink, paper):
    head = {"Head": 1.0}
    c = HEAD_CENTRE
    # The face: one big round white head, a touch fuller at the cheeks.
    ellipsoid(skin, c, HEAD_RADII, head, segments=32, rings=20)
    # Blond, spiky anime bob (Lily, 2026-11-25), drawn blond the black-and-white way:
    # paper-white locks with ink strand lines. A white cap covers the skull under
    # chunky pointed locks: bangs over the brow, jaw-length sides with longer locks
    # framing the face, the back flicking out at the nape, and one ahoge on top.
    hair_cap(paper, c, head)
    for root, mid, tip, width in hair_locks(c):
        lock(paper, ink, root, mid, tip, width, c, head)

    def on_face(x, z, lift=0.0):
        """A point on the face surface (front, -Y), lifted out along the normal."""
        u = Vector((x / HEAD_RADII[0], 0.0, (z - c.z) / HEAD_RADII[2]))
        y2 = max(0.0, 1.0 - u.x * u.x - u.z * u.z)
        p = Vector((x, c.y - HEAD_RADII[1] * math.sqrt(y2), z))
        n = Vector(((p.x - c.x) / HEAD_RADII[0] ** 2, (p.y - c.y) / HEAD_RADII[1] ** 2, (p.z - c.z) / HEAD_RADII[2] ** 2)).normalized()
        return p + n * lift, n

    for side in (1, -1):
        # Big oval eyes, pupils filling them, a white catch-light, three lashes.
        eye, n = on_face(0.068 * side, c.z + 0.004, 0.002)
        hug = Matrix.Rotation(math.atan2(n.x, -n.y), 3, "Z")
        ellipsoid(ink, eye, (0.034, 0.012, 0.052), head, rotation=hug, segments=20, rings=12)
        shine, _n = on_face(0.068 * side + 0.010 * side, c.z + 0.026, 0.011)
        ellipsoid(paper, shine, (0.0085, 0.004, 0.011), head, segments=10, rings=6)
        for k, (dx, dz, angle) in enumerate(((0.018, 0.050, 35), (0.030, 0.040, 55), (0.037, 0.024, 75))):
            base, n2 = on_face(0.068 * side + dx * side, c.z + dz, 0.003)
            out = Vector((math.sin(math.radians(angle)) * side, -0.25, math.cos(math.radians(angle)))).normalized()
            ellipsoid(ink, base + out * 0.012, (0.0035, 0.0035, 0.015), head, rotation=rotation_to(out), segments=8, rings=6)
        # No brows: the bangs cover them.
        # A soft round cheek line is left to the outline; the cheeks stay white.
    nose, _n = on_face(0.0, c.z - 0.050, 0.004)
    ellipsoid(ink, nose, (0.009, 0.006, 0.006), head, segments=10, rings=6)
    # Cupid's-bow mouth: two upper lobes over a fuller lower lip.
    for side in (1, -1):
        p, _n = on_face(0.011 * side, c.z - 0.098, 0.004)
        ellipsoid(ink, p, (0.013, 0.006, 0.0085), head, rotation=Matrix.Rotation(math.radians(-14 * side), 3, "Y"), segments=10, rings=6)
    p, _n = on_face(0.0, c.z - 0.112, 0.004)
    ellipsoid(ink, p, (0.017, 0.006, 0.009), head, segments=10, rings=6)
    # The maid's frilled headband: puffs along an arc over the crown, ear to ear.
    for k in range(17):
        a = math.radians(-80 + 10 * k)
        d = Vector((math.sin(a), -0.42, math.cos(a))).normalized()
        p = c + Vector((d.x * HEAD_RADII[0] * 1.22, d.y * HEAD_RADII[1] * 1.22, d.z * HEAD_RADII[2] * 1.19 + 0.012))
        ellipsoid(paper, p, (0.024, 0.016, 0.021), head, rotation=rotation_to(d), segments=10, rings=6)



def hair_cap(part, c, weights):
    """The skull under the locks: a white shell round the top, back and sides, open
    over the face below the hairline."""
    cap = bmesh.new()
    bmesh.ops.create_uvsphere(cap, u_segments=48, v_segments=32, radius=1.0)
    drop = []
    for f in cap.faces:
        m = f.calc_center_median()
        face = m.y < -0.25 and m.z < 0.45 and abs(m.x) < 0.80
        if face or m.z < (-0.55 - 0.30 * max(0.0, m.y)):
            drop.append(f)
    bmesh.ops.delete(cap, geom=drop, context="FACES")
    bmesh.ops.solidify(cap, geom=cap.faces[:], thickness=-0.06)
    for v in cap.verts:
        q = v.co
        v.co = c + Vector((q.x * HEAD_RADII[0] * 1.06, q.y * HEAD_RADII[1] * 1.06 + 0.003, q.z * HEAD_RADII[2] * 1.05 + 0.008))
    mapping = {v: part.vert(v.co, weights) for v in cap.verts}
    for f in cap.faces:
        part.face([mapping[v] for v in f.verts])
    cap.free()


def scalp(c, direction, out=1.06):
    """A point on the hair surface in a direction from the head's centre."""
    d = direction.normalized()
    return c + Vector((d.x * HEAD_RADII[0] * out, d.y * HEAD_RADII[1] * out, d.z * HEAD_RADII[2] * out + 0.008))


def hair_locks(c):
    """(root, mid, tip, width) for every lock. Roots sit on the crown; mids bow out
    from the head; tips end in points."""
    locks = []
    rx, ry, rz = HEAD_RADII
    # Bangs: seven pointed locks over the brow, tips just above the eyes, alternating.
    for k in range(7):
        x = (k - 3) / 3.0
        root = scalp(c, Vector((x * 0.55, -0.55, 0.85)))
        tip_z = c.z + (0.072 if k % 2 == 0 else 0.092) - 0.012 * (1 - abs(x))
        tip = Vector((c.x + x * rx * 0.86, c.y - ry * 1.04, tip_z))
        mid = scalp(c, Vector((x * 0.75, -0.95, 0.55)), 1.20)
        locks.append((root, mid, tip, 0.074 if k % 2 == 0 else 0.062))
    for side in (1, -1):
        # The long front locks that frame the face, past the jaw.
        root = scalp(c, Vector((0.55 * side, -0.55, 0.65)))
        mid = scalp(c, Vector((0.98 * side, -0.55, -0.05)), 1.14)
        tip = Vector((c.x + rx * 0.80 * side, c.y - ry * 0.62, c.z - 0.185))
        locks.append((root, mid, tip, 0.070))
        # Jaw-length side locks, flaring out to points.
        for k, (fy, tz) in enumerate(((-0.25, -0.120), (0.10, -0.135), (0.45, -0.125))):
            root = scalp(c, Vector((0.55 * side, fy * 0.6, 0.80)))
            mid = scalp(c, Vector((1.00 * side, fy, 0.15)), 1.16)
            tip = Vector((c.x + rx * (1.16 + 0.04 * k) * side, c.y + ry * fy * 1.05, c.z + tz))
            locks.append((root, mid, tip, 0.088))
    # The back: eight locks from the crown to the nape, flicking out.
    for k in range(8):
        a = math.radians(-112 + 32 * k)
        d = Vector((math.sin(a), math.cos(a), 0.0))
        root = scalp(c, Vector((d.x * 0.35, d.y * 0.35 + 0.05, 0.94)))
        mid = scalp(c, Vector((d.x, d.y, 0.05)), 1.15)
        tip = c + Vector((d.x * rx * 1.20, d.y * ry * 1.22, -0.170 + 0.012 * (k % 2)))
        locks.append((root, mid, tip, 0.098))
    # Crown spikes to break the silhouette, and the ahoge.
    for k, a in enumerate((-60, -20, 20, 60)):
        d = Vector((math.sin(math.radians(a)), 0.35, 1.0))
        root = scalp(c, d, 0.95)
        locks.append((root, scalp(c, d, 1.12), scalp(c, d + Vector((d.x * 0.4, 0.15, -0.15)), 1.22), 0.075))
    top = scalp(c, Vector((0.05, -0.15, 1.0)), 1.0)
    locks.append((top, top + Vector((0.01, -0.02, 0.07)), top + Vector((0.045, -0.05, 0.085)), 0.022))
    return locks


def lock(paper, ink, root, mid, tip, width, c, weights, rings=12, sides=10):
    """One pointed lock: a flattened, tapering tube along a quadratic curve, closed
    at the root and ending in a point, with an ink strand line down its outer face."""
    def at(u):
        return root * (1 - u) ** 2 + mid * 2 * u * (1 - u) + tip * u * u

    def tangent(u):
        return ((mid - root) * 2 * (1 - u) + (tip - mid) * 2 * u).normalized()

    grid = []
    frames = []
    for r in range(rings):
        u = r / rings
        p = at(u)
        t = tangent(u)
        n = (p - c)
        n = (n - t * n.dot(t)).normalized()
        b = t.cross(n).normalized()
        w = width * 0.5 * (1.0 - u) ** 0.75 * (0.75 + 0.25 * math.sin(math.pi * min(1.0, u * 2.2)))
        d = 0.017 * (1.0 - u) ** 0.6 + 0.003
        row = [paper.vert(p + b * math.cos(2 * math.pi * s / sides) * w + n * math.sin(2 * math.pi * s / sides) * d, weights)
               for s in range(sides)]
        grid.append(row)
        frames.append((p, n, b, w, d))
    point = paper.vert(tip, weights)
    base = paper.vert(root, weights)
    for r in range(rings - 1):
        for s in range(sides):
            paper.face((grid[r][s], grid[r][(s + 1) % sides], grid[r + 1][(s + 1) % sides], grid[r + 1][s]))
    for s in range(sides):
        paper.face((point, grid[-1][s], grid[-1][(s + 1) % sides]))
        paper.face((base, grid[0][(s + 1) % sides], grid[0][s]))
    # Ink strand: a fine tapering line along the outer face, off the lock's centre.
    if width > 0.03:  # the ahoge is too fine for a strand
        offset = 0.22 if (int(root.x * 1000) % 2) else -0.22
        strand = []
        for r in range(2, rings - 2):
            p, n, b, w, d = frames[r]
            strand.append(p + n * (d + 0.0012) + b * w * offset)
        for a, bpt in zip(strand, strand[1:]):
            m = (a + bpt) * 0.5
            v = bpt - a
            ellipsoid(ink, m, (0.0016, 0.0016, v.length * 0.62), weights, rotation=rotation_to(v), segments=6, rings=4)

def rotation_to(direction):
    """Rotation taking +Z to direction."""
    return Vector((0, 0, 1)).rotation_difference(direction.normalized()).to_matrix()


def body_parts(skin, ink, paper):
    chest = {"Chest": 1.0}
    hips = {"Hips": 1.0}
    neck = {"Neck": 1.0}
    # Neck.
    lathe(skin, [(NECK[2], NECK[0].z), (NECK[2], NECK[1].z)], neck, sides=16)
    # Bare shoulders and the sweetheart neckline: a white yoke above the bodice.
    lathe(skin, [(0.035, 1.060), (0.090, 1.030), (0.135, 1.000), (0.150, 0.975), (0.120, 0.955)], chest, sides=32, squash=0.70)
    # Black choker with a small white bow.
    lathe(ink, [(NECK[2] + 0.004, 1.060), (NECK[2] + 0.004, 1.076)], neck, sides=16)
    for side in (1, -1):
        ellipsoid(paper, Vector((0.012 * side, -0.034, 1.068)), (0.012, 0.006, 0.008), neck, segments=10, rings=6)
    ellipsoid(paper, Vector((0, -0.036, 1.068)), (0.005, 0.006, 0.006), neck, segments=8, rings=5)
    # Hourglass bodice, black: hips, a narrow waist, a full bust, cut in a sweetheart
    # line (two lobes) under the yoke.
    bodice = [(0.105, 0.770), (0.085, 0.800), (0.092, 0.840), (0.118, 0.890), (0.138, 0.930), (0.140, 0.960), (0.128, 0.982)]
    lathe(ink, bodice, chest, sides=32, squash=0.72)
    for side in (1, -1):
        ellipsoid(ink, Vector((0.055 * side, -0.068, 0.935)), (0.062, 0.050, 0.055), chest, segments=16, rings=10)
    # Puff sleeves with white cuffs, at the shoulders.
    for side in (1, -1):
        s = Vector((ARM_ROOT.x * side, 0, ARM_ROOT.z))
        ellipsoid(ink, s + Vector((0.010 * side, 0, -0.010)), (0.060, 0.055, 0.058), chest, segments=16, rings=10)
        ellipsoid(paper, s + Vector((0.018 * side, 0, -0.058)), (0.040, 0.038, 0.012), chest, segments=16, rings=6)
    # White waistband.
    lathe(paper, [(0.088, 0.790), (0.090, 0.808)], hips, sides=32, squash=0.72)
    # Bell skirt, black, flaring from the waist.
    skirt = [(0.270, 0.505), (0.285, 0.520), (0.262, 0.580), (0.215, 0.650), (0.160, 0.720), (0.110, 0.775), (0.090, 0.795)]
    lathe(ink, skirt, hips, sides=40, squash=0.78)
    # Scalloped white petticoat peeking under the hem.
    scallop = lambda a, i: 1.0 + 0.045 * abs(math.cos(a * 9.0)) * (1 if i == 0 else 0.4)
    lathe(paper, [(0.255, 0.470), (0.282, 0.482), (0.270, 0.515)], hips, sides=72, squash=0.78, wobble=scallop)
    # The apron: a frilled white panel over the front of the skirt, a thin shell of
    # revolution swept across the front only, with a scalloped hem.
    def apron_r(z):
        for (r0, z0), (r1, z1) in zip(skirt, skirt[1:]):
            lo, hi = sorted((z0, z1))
            if lo <= z <= hi and hi > lo:
                return (r0 + (r1 - r0) * (z - z0) / (z1 - z0))
        return skirt[0][0]
    apron = [(apron_r(z) + 0.012, z) for z in (0.560, 0.600, 0.650, 0.700, 0.750, 0.790)]
    lathe(paper, apron, hips, sides=24, squash=0.80, start=-0.95, sweep=1.90,
          wobble=lambda a, i: 1.0 + (0.035 * abs(math.cos(a * 12.0)) if i == 0 else 0.0))
    # Heart bib on the bodice front.
    heart = []
    for k in range(48):
        t = 2 * math.pi * k / 48
        hx = 16 * math.sin(t) ** 3
        hz = 13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t)
        heart.append((hx * 0.0042, hz * 0.0042))
    heart_solid(paper, Vector((0, -0.100, 0.862)), heart, chest)
    # Big white bow at the back of the waist: two loops, a knot and two tails.
    knot = Vector((0, 0.080, 0.800))
    for side in (1, -1):
        ellipsoid(paper, knot + Vector((0.060 * side, 0.010, 0.012)), (0.058, 0.020, 0.036), hips, rotation=Matrix.Rotation(math.radians(18 * side), 3, "Y"), segments=14, rings=8)
        ellipsoid(paper, knot + Vector((0.030 * side, 0.016, -0.075)), (0.020, 0.008, 0.070), hips, rotation=Matrix.Rotation(math.radians(-14 * side), 3, "Y"), segments=10, rings=8)
    ellipsoid(paper, knot + Vector((0, 0.012, 0)), (0.020, 0.018, 0.022), hips, segments=12, rings=8)


def heart_solid(part, centre, outline, weights, depth=0.010):
    front = [part.vert(centre + Vector((x, -depth, z)), weights) for x, z in outline]
    back = [part.vert(centre + Vector((x, depth, z)), weights) for x, z in outline]
    fc = part.vert(centre + Vector((0, -depth, 0)), weights)
    bc = part.vert(centre + Vector((0, depth, 0)), weights)
    n = len(outline)
    for k in range(n):
        a, b = k, (k + 1) % n
        part.face((front[a], front[b], back[b], back[a]))
        part.face((fc, front[b], front[a]))
        part.face((bc, back[a], back[b]))


def glove_parts(part, wrist, direction, side, prefix):
    """The arm's glove and bell cuff at the figure's scale, placed at the wrist, palm
    toward the body and thumb forward. Built for the left hand (+X); the right hand is
    the same built at the mirrored wrist and reflected in X (normals are recalculated)."""
    s = GLOVE_SCALE
    left_wrist = Vector((wrist.x * side, wrist.y, wrist.z))
    left_dir = Vector((direction.x * side, direction.y, direction.z))
    rot = frame_along(left_dir, Vector((1.0, 0, 0)))

    def place(v):
        p = left_wrist + rot @ (v * s)
        return Vector((p.x * side, p.y, p.z))

    hand = {prefix + "Hand": 1.0}
    throat = ARM_RADIUS / s * 1.06
    profile = [(throat, -0.014), (throat * 1.02, -0.006), (throat * 1.12, 0.000), (0.023, 0.006),
               (0.029, 0.011), (0.034, 0.015), (0.037, 0.019), (0.0375, 0.023), (0.035, 0.026),
               (0.030, 0.027), (0.024, 0.026)]
    # Cuff (a lathe about the glove's +Y axis), palm, fingers and thumb, built in glove
    # space and then placed; weights go to the hand and finger bones.
    rings = []
    for radius, y in profile:
        ring = []
        for k in range(24):
            a = 2 * math.pi * k / 24
            ring.append(part.vert(place(Vector((radius * math.cos(a), y, radius * 0.92 * math.sin(a)))), hand))
        rings.append(ring)
    for r in range(len(rings) - 1):
        for k in range(24):
            part.face((rings[r][k], rings[r + 1][k], rings[r + 1][(k + 1) % 24], rings[r][(k + 1) % 24]))
    a_cap = part.vert(place(Vector((0, profile[0][1], 0))), hand)
    b_cap = part.vert(place(Vector((0, profile[-1][1], 0))), hand)
    for k in range(24):
        part.face((a_cap, rings[0][k], rings[0][(k + 1) % 24]))
        part.face((b_cap, rings[-1][(k + 1) % 24], rings[-1][k]))

    def blob(centre, radii, group, rotation=Matrix.Identity(3)):
        g = {group: 1.0}
        tmp = Part(part.bm)
        ellipsoid(tmp, Vector((0, 0, 0)), (radii[0], radii[2], radii[1]), g, rotation=rotation @ Matrix.Rotation(math.radians(-90), 3, "X"), segments=14, rings=8)
        for v, w in tmp.weights.items():
            v.co = place(centre + v.co)
            part.weights[v] = w

    blob(Vector((0, 0.048, -0.002)), (0.046, 0.040, 0.026), prefix + "Hand")
    for name, x, lengths, radius in FINGERS:
        blob(Vector((x, KNUCKLE + lengths[0] * 0.5, 0)), (radius, lengths[0] * 0.80, radius), prefix + name + "_1")
        y1 = KNUCKLE + lengths[0]
        blob(Vector((x, y1 + lengths[1] * 0.5, 0)), (radius * 1.08, lengths[1] * 0.78, radius * 1.08), prefix + name + "_2")
    align = Vector((0, 1, 0)).rotation_difference(THUMB_DIR).to_matrix()
    blob(THUMB_BASE + THUMB_DIR * THUMB_SEGMENTS[0] * 0.5, (THUMB_RADIUS, THUMB_SEGMENTS[0] * 0.80, THUMB_RADIUS), prefix + "Thumb_1", align)
    tip = THUMB_BASE + THUMB_DIR * THUMB_SEGMENTS[0]
    blob(tip + THUMB_DIR * THUMB_SEGMENTS[1] * 0.5, (THUMB_RADIUS * 1.06, THUMB_SEGMENTS[1] * 0.78, THUMB_RADIUS * 1.06), prefix + "Thumb_2", align)
    return place


def limb_parts(skin, ink, paper):
    for side, prefix in ((1, "Left"), (-1, "Right")):
        arm_root = Vector((ARM_ROOT.x * side, ARM_ROOT.y, ARM_ROOT.z))
        arm_end = Vector((ARM_END.x * side, ARM_END.y, ARM_END.z))
        hose(ink, arm_root, arm_end, ARM_RADIUS, prefix + "Arm", Vector((0, -1, 0)))
        glove_parts(paper, arm_end, (arm_end - arm_root).normalized(), side, prefix)
        leg_root = Vector((LEG_ROOT.x * side, LEG_ROOT.y, LEG_ROOT.z))
        leg_end = Vector((LEG_END.x * side, LEG_END.y, LEG_END.z))
        hose(ink, leg_root, leg_end, LEG_RADIUS, prefix + "Leg", Vector((0, -1, 0)))
        # White frilled stocking top: a scalloped ring round the hose.
        top = leg_root.lerp(leg_end, STOCKING_TOP_T)
        w = limb_weight(prefix + "Leg", STOCKING_TOP_T)
        lathe(paper, [(LEG_RADIUS + 0.004, -0.012), (LEG_RADIUS + 0.013, 0.0), (LEG_RADIUS + 0.004, 0.012)], w,
              sides=36, centre=top, wobble=lambda a, i: 1.0 + (0.18 * abs(math.cos(a * 6.0)) if i == 1 else 0.0))
        # Round black Mary Jane and a white bow over the instep.
        foot = {prefix + "Foot": 1.0}
        ellipsoid(ink, leg_end + Vector((0, -0.045, -0.040)), (0.048, 0.092, 0.042), foot, segments=18, rings=10)
        for k in (1, -1):
            ellipsoid(paper, leg_end + Vector((0.013 * k, -0.075, -0.002)), (0.013, 0.007, 0.009), foot, segments=10, rings=6)
        ellipsoid(paper, leg_end + Vector((0, -0.076, -0.002)), (0.006, 0.007, 0.007), foot, segments=8, rings=5)


# ---------------------------------------------------------------- rig and objects

def limb_chain(data, prefix, root, end):
    step = (end - root) / LIMB_BONES
    for i in range(LIMB_BONES):
        bone = data.edit_bones.new("%s_%02d" % (prefix, i))
        bone.head = root + step * i
        bone.tail = root + step * (i + 1)
        bone.roll = 0.0


def build_armature():
    data = bpy.data.armatures.new("ToonLilyRig")
    rig = bpy.data.objects.new("ToonLilyRig", data)
    bpy.context.collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="EDIT")
    for name, head, tail in (("Hips", HIPS, HIPS + Vector((0, 0, 0.10))),
                             ("Chest", CHEST, CHEST + Vector((0, 0, 0.12))),
                             ("Neck", NECK[0], NECK[1]),
                             ("Head", HEAD_CENTRE, HEAD_CENTRE + Vector((0, 0, 0.20))),
                             ("HeadFront", HEAD_CENTRE + Vector((0, -0.20, 0)), HEAD_CENTRE + Vector((0, -0.24, 0)))):
        bone = data.edit_bones.new(name)
        bone.head, bone.tail = head, tail
    for side, prefix in ((1, "Left"), (-1, "Right")):
        arm_root = Vector((ARM_ROOT.x * side, ARM_ROOT.y, ARM_ROOT.z))
        arm_end = Vector((ARM_END.x * side, ARM_END.y, ARM_END.z))
        limb_chain(data, prefix + "Arm", arm_root, arm_end)
        direction = (arm_end - arm_root).normalized()
        hand = data.edit_bones.new(prefix + "Hand")
        hand.head = arm_end
        hand.tail = arm_end + direction * KNUCKLE * GLOVE_SCALE
        for name in ("Index", "Middle", "Ring", "Thumb"):
            for k in (1, 2):
                finger = data.edit_bones.new("%s%s_%d" % (prefix, name, k))
                finger.head = hand.tail + direction * 0.02 * (k - 1)
                finger.tail = finger.head + direction * 0.02
                finger.parent = hand if k == 1 else data.edit_bones["%s%s_1" % (prefix, name)]
        leg_root = Vector((LEG_ROOT.x * side, LEG_ROOT.y, LEG_ROOT.z))
        leg_end = Vector((LEG_END.x * side, LEG_END.y, LEG_END.z))
        limb_chain(data, prefix + "Leg", leg_root, leg_end)
        foot = data.edit_bones.new(prefix + "Foot")
        foot.head = leg_end
        foot.tail = leg_end + Vector((0, -0.10, 0))
    bpy.ops.object.mode_set(mode="OBJECT")
    return rig


def new_object(name, builder, mat, bones):
    mesh = bpy.data.meshes.new(name)
    bm = bmesh.new()
    part = Part(bm)
    builder(part)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    order = list(bm.verts)
    weights = [part.weights.get(v, {}) for v in order]
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat)
    for bone in bones:
        obj.vertex_groups.new(name=bone)
    for index, weight_map in enumerate(weights):
        for group, weight in weight_map.items():
            if weight > 0.0:
                obj.vertex_groups[group].add([index], weight, "REPLACE")
    for poly in obj.data.polygons:
        poly.use_smooth = True
    return obj


def uv_unwrap(obj):
    bpy.context.view_layer.objects.active = obj
    for other in bpy.context.selected_objects:
        other.select_set(False)
    obj.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.02)
    bpy.ops.object.mode_set(mode="OBJECT")


def bind(obj, rig):
    obj.parent = rig
    modifier = obj.modifiers.new("Rig", "ARMATURE")
    modifier.object = rig


def outward_check(objects):
    """Every closed component must face out (positive signed volume)."""
    bad = []
    for obj in objects:
        bm = bmesh.new()
        bm.from_mesh(obj.data)
        bm.faces.ensure_lookup_table()
        seen = set()
        for f0 in bm.faces:
            if f0.index in seen:
                continue
            stack, comp = [f0], []
            while stack:
                f = stack.pop()
                if f.index in seen:
                    continue
                seen.add(f.index)
                comp.append(f)
                for e in f.edges:
                    stack.extend(g for g in e.link_faces if g.index not in seen)
            vol = 0.0
            for f in comp:
                vs = [v.co for v in f.verts]
                for i in range(1, len(vs) - 1):
                    vol += vs[0].dot(vs[i].cross(vs[i + 1])) / 6.0
            if vol <= 0.0:
                bad.append((obj.name, len(comp), vol))
        bm.free()
    return bad


def review(directory, rig):
    directory = Path(directory)
    directory.mkdir(parents=True, exist_ok=True)
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "FLAT"
    scene.display.shading.color_type = "MATERIAL"
    scene.display.shading.show_object_outline = True
    scene.display.shading.object_outline_color = (0, 0, 0)
    scene.render.resolution_x = 800
    scene.render.resolution_y = 1000
    world = bpy.data.worlds.new("Review")
    world.color = (0.62, 0.60, 0.56)
    scene.world = world
    cam_data = bpy.data.cameras.new("ReviewCam")
    cam_data.lens = 50
    cam = bpy.data.objects.new("ReviewCam", cam_data)
    bpy.context.collection.objects.link(cam)
    scene.camera = cam
    for label, eye, target in (("front", Vector((0.0, -3.4, 0.85)), Vector((0, 0, 0.78))),
                               ("three_quarter", Vector((1.9, -2.7, 1.0)), Vector((0, 0, 0.78))),
                               ("back", Vector((0.4, 3.3, 0.9)), Vector((0, 0, 0.78))),
                               ("face", Vector((0.25, -1.15, 1.30)), HEAD_CENTRE)):
        cam.location = eye
        cam.rotation_euler = (target - eye).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = str(directory / ("toon_lily_%s.png" % label))
        bpy.ops.render.render(write_still=True)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    review_dir = argv[argv.index("--review") + 1] if "--review" in argv else ""
    reset()
    rig = build_armature()
    bones = [b.name for b in rig.data.bones]
    ink_mat = material("ToonInk", INK)
    paper_mat = material("ToonPaper", PAPER)
    skin_mat = material("ToonSkin", PAPER)

    def build_all(kind):
        def run(part):
            parts = {"skin": None, "ink": None, "paper": None}
            parts[kind] = part
            dummy = _Sink()
            skin = parts["skin"] or dummy
            ink = parts["ink"] or dummy
            paper = parts["paper"] or dummy
            head_parts(skin, ink, paper)
            body_parts(skin, ink, paper)
            limb_parts(skin, ink, paper)
            dummy.free()
        return run

    objects = [new_object("ToonLilyInk", build_all("ink"), ink_mat, bones),
               new_object("ToonLilyPaper", build_all("paper"), paper_mat, bones),
               new_object("ToonLilySkin", build_all("skin"), skin_mat, bones)]
    for obj in objects:
        uv_unwrap(obj)
        bind(obj, rig)
    bad = outward_check(objects)
    triangles = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in objects)
    print("TOON LILY: bones=%d triangles=%d inward_components=%d %s" % (len(rig.data.bones), triangles, len(bad), bad[:6]))
    if review_dir:
        review(review_dir, rig)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=str(OUT), export_format="GLB", use_selection=False,
                              export_yup=True, export_skins=True, export_animations=False,
                              export_apply=False, export_materials="EXPORT")
    print("TOON LILY: wrote", OUT)


class _Sink(Part):
    """Swallows the geometry of the other materials while one material is built."""
    def __init__(self):
        self._bm = bmesh.new()
        super().__init__(self._bm)

    def free(self):
        self._bm.free()


main()
