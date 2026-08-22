"""Build the Dream Tentacle as a LAYERED DEFORMABLE CREATURE.

design/DREAM_TENTACLE_BLENDER_BUILD.md. The flesh is the load-bearing
deformation mesh; the eye, suckers, gold skeleton, crystals, cilia and
membrane are separate systems constrained to it.

The rule that governs everything here is the last line of the ruling:

    THE FINISHED MODEL MUST LOOK IMPRESSIVE IN FLAT GREY.

So this script builds ANATOMY, not a tube waiting for a shader. Every
cross-section along the limb is authored — an asymmetric muscular root, a
compressed neck, an ocular station that swells to carry the eye, a
flattened ribbon, a ribbed shaft, a narrowing, a tactile club — and the
orbit is cut into the flesh as a real concavity with a brow that overhangs
the globe.

    "/c/Program Files/Blender Foundation/Blender 5.2/blender" -b \
        -P art/blender/scripts/build_dream_tentacle.py

Writes `art/blender/dream_tentacle.blend` and exports
`game/assets/dream/tentacle/dream_tentacle.glb`.
"""

import bpy
import mathutils
import mathutils.kdtree
import bmesh
import math
import os
import random
from mathutils import Vector, Matrix

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
BLEND_OUT = os.path.join(REPO, "art", "blender", "dream_tentacle.blend")
GLB_DIR = os.path.join(REPO, "game", "assets", "dream", "tentacle")
GLB_OUT = os.path.join(GLB_DIR, "dream_tentacle.glb")

LENGTH = 1.60
RING_SEGMENTS = 28          # around the body on the cage
EYE_V = 0.42
GLOBE_R = 0.018

# ---------------------------------------------------------------------------
# THE PROFILE — §1. Authored cross-sections, not a taper. Each row is
#   v, radius (m), flatten (0 round .. 0.6 ribbon), dorsal bias, twist (rad)
# The silhouette has to be interesting here, before any subdivision.
PROFILE = [
    (0.000, 0.088, 0.10, 0.00, 0.00),   # root: broad, muscular
    (0.045, 0.096, 0.16, 0.06, 0.04),   # the root's asymmetric shoulder
    (0.100, 0.082, 0.22, 0.10, 0.09),
    (0.160, 0.052, 0.30, 0.04, 0.16),   # a real compressed NECK
    (0.230, 0.061, 0.18, 0.00, 0.24),
    (0.300, 0.070, 0.12, -0.05, 0.34),
    (0.355, 0.085, 0.08, -0.10, 0.44),  # the brow rising
    (0.420, 0.104, 0.10, -0.14, 0.52),  # THE OCULAR STATION
    (0.470, 0.092, 0.16, -0.10, 0.60),  # its shoulder falling away
    (0.520, 0.064, 0.30, -0.02, 0.70),
    (0.560, 0.038, 0.58, 0.02, 0.82),   # the flattened RIBBON: a real pinch
    # THE DISTAL THIRD, RE-AUTHORED. It used to run pinch/swell/pinch/swell
    # six times at even spacing and near-identical amplitude, which is a
    # regular corrugation -- the exact thing sculpt_forms() warns against two
    # hundred lines below -- and in the posed grey test it read as a STACK OF
    # BEADS rather than flesh. Same number of features, but the spacing and
    # the depth now vary a lot: one real narrow, one knuckle, and everything
    # else a modulation of the taper rather than another bead.
    (0.604, 0.059, 0.30, 0.05, 0.90),   # the swell after the ribbon
    (0.663, 0.047, 0.34, 0.02, 1.00),   # a shallow waist, not a bead
    (0.706, 0.055, 0.18, -0.02, 1.08),  # a broad, soft swelling
    (0.742, 0.031, 0.40, 0.03, 1.15),   # THE narrow: the one real pinch here
    (0.800, 0.046, 0.14, -0.02, 1.26),  # a long easy rise out of it
    (0.828, 0.049, 0.10, -0.04, 1.33),  # the knuckle, barely distinct from it
    (0.870, 0.027, 0.20, 0.02, 1.42),   # the narrowing: dexterous
    (0.910, 0.029, 0.08, 0.00, 1.50),
    (0.945, 0.023, 0.10, 0.00, 1.56),
    (0.962, 0.037, 0.04, -0.03, 1.60),  # the club begins
    (0.978, 0.047, 0.02, -0.05, 1.63),  # the sensory CLUB, flared
    (0.992, 0.033, 0.00, 0.00, 1.65),
    (1.000, 0.012, 0.00, 0.00, 1.66),
]


def smooth01(x):
    x = max(0.0, min(1.0, x))
    return x * x * (3.0 - 2.0 * x)


def log(msg):
    print("[tentacle] %s" % msg)


def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.unit_settings.system = "METRIC"
    scene.unit_settings.scale_length = 1.0


def collection(name, parent=None):
    col = bpy.data.collections.new(name)
    (parent or bpy.context.scene.collection).children.link(col)
    return col


def sample_profile(v):
    """Smooth interpolation of the authored sections."""
    v = min(max(v, 0.0), 1.0)
    for i in range(len(PROFILE) - 1):
        a, b = PROFILE[i], PROFILE[i + 1]
        if a[0] <= v <= b[0]:
            span = max(1e-6, b[0] - a[0])
            t = (v - a[0]) / span
            t = t * t * (3.0 - 2.0 * t)
            return tuple(a[k] + (b[k] - a[k]) * t for k in range(1, 5))
    return PROFILE[-1][1:]


# ---------------------------------------------------------------------------
# §4 THE ORBIT. A real concavity cut into the flesh, with a brow that
# overhangs the globe. This is a displacement of the cage's own vertices,
# so the socket is topology rather than an intersection.

ORBIT_U = 0.0           # which way the eye looks, around the body
# The socket HUGS the globe: a 36 mm eye wants a ~30 mm bowl with the brow
# and cushion beyond it, not a 110 mm crater the eye rattles around in.
ORBIT_R = 0.030         # the socket's radius on the surface, metres


def orbit_shape(u_ang, v):
    """(sink, brow) at a point on the surface.

    `sink` pulls the flesh in to make the bowl; `brow` pushes a heavy mass
    out above it and a cushion below, so from 45 degrees the globe is
    partly eaten by tissue.
    """
    du = (u_ang - ORBIT_U + math.pi) % (2.0 * math.pi) - math.pi
    prof = sample_profile(v)
    r_here = prof[0]
    # Distance on the surface, in metres, from the orbit's centre.
    dx = du * r_here
    dy = (v - EYE_V) * LENGTH
    d = math.hypot(dx / ORBIT_R, dy / (ORBIT_R * 1.15))
    ang = math.atan2(dy, dx)
    bowl = max(0.0, 1.0 - d * d) ** 1.4
    # The brow: heavy above and slightly to one side; the cushion below.
    brow = max(0.0, math.cos(ang - 1.15)) ** 2 * max(0.0, 1.0 - abs(d - 1.05) * 1.8)
    cushion = max(0.0, math.cos(ang + 1.85)) ** 2 * max(0.0, 1.0 - abs(d - 1.0) * 2.2)
    lateral = max(0.0, abs(math.sin(ang))) ** 3 * max(0.0, 1.0 - abs(d - 1.15) * 2.4)
    return bowl, brow * 0.9 + cushion * 0.55 + lateral * 0.35


# ---------------------------------------------------------------------------
# §3 THE SCULPT FORMS. Large anatomy first, then medium. These are the
# muscular bundles, compression folds, asymmetric bulges, ridges and tension
# that make the difference between an animal and a hose — and they must be
# in the GEOMETRY, because the grey test looks at geometry.

def sculpt_forms(a, v, radius):
    """Multiplier on the radius at (angle, v). Returns (mult, fold)."""
    # PRIMARY — longitudinal muscular bundles. Three heavy cords running the
    # length, out of phase, so every cross-section is lobed rather than round.
    bundles = 0.0
    for k, (count, amp, twistk, phase) in enumerate((
            (3.0, 0.055, 1.9, 0.0), (5.0, 0.026, -1.2, 1.7), (2.0, 0.034, 0.7, 3.1))):
        bundles += amp * math.cos(count * (a + twistk * v) + phase)
    # PRIMARY — asymmetric bulges: a few big masses at authored places, never
    # mirrored, never evenly spaced.
    bulge = 0.0
    for (bv, ba, size, amp) in ((0.075, 0.9, 0.055, 0.10), (0.135, 3.9, 0.045, 0.07),
                                (0.285, 2.2, 0.05, 0.06), (0.615, 5.2, 0.04, 0.055),
                                (0.700, 1.1, 0.035, 0.045), (0.865, 4.0, 0.03, 0.04)):
        du = (a - ba + math.pi) % (2.0 * math.pi) - math.pi
        d = math.hypot(du * 0.5, (v - bv) / (size / LENGTH) * 0.5)
        bulge += amp * math.exp(-d * d * 2.4)
    # SECONDARY — compression folds where the body narrows, and tension
    # creases running along it. Folds are rings ONLY where anatomy compresses,
    # never a regular corrugation.
    fold = 0.0
    for (fv, width, depth) in ((0.155, 0.030, 0.055), (0.175, 0.022, 0.038),
                               (0.505, 0.026, 0.045), (0.545, 0.020, 0.032),
                               (0.795, 0.018, 0.030), (0.828, 0.015, 0.024)):
        fold += depth * math.exp(-((v - fv) / width) ** 2) * (0.6 + 0.4 * math.cos(a * 2.0 + fv * 30.0))
    # SECONDARY — longitudinal tension creases, strongest along the flanks.
    crease = 0.020 * math.sin(a * 7.0 + v * 3.0) * math.exp(-((v - 0.5) / 0.42) ** 2)         * abs(math.sin(a))
    # SECONDARY — a softer, flatter ventral field where the suckers will sit.
    ventral = max(0.0, -math.cos(a - math.pi))
    distal = max(0.0, (v - 0.60) / 0.40)
    soft = -0.045 * ventral * distal
    return 1.0 + bundles + bulge + crease + soft, fold


# ---------------------------------------------------------------------------
# §9 THE GOLD SKELETON, as data first. The sockets have to exist in the FLESH
# before the metal is placed, or the gold sits 1 mm above the body and reads
# as jewellery — the exact failure the ruling calls out. Each entry is
#   v, angle, kind, length (m), width (m), rise (m), roll, seed
# Twenty-eight pieces, none repeating, none evenly spaced, and a deliberate
# gap where the orbit's own gold belongs.
GOLD = [
    (0.030, 1.05, "plate",    0.106, 0.101, 0.020, 0.20, 0),
    (0.062, 4.30, "spur",     0.030, 0.024, 0.016, -0.5, 1),
    (0.098, 2.35, "crescent", 0.081, 0.050, 0.014, 0.14, 2),
    (0.128, 5.60, "branch",   0.050, 0.030, 0.013, 0.55, 3),
    (0.170, 0.62, "knuckle",  0.048, 0.038, 0.018, -0.28, 4),
    (0.205, 3.30, "rib",      0.101, 0.033, 0.011, 0.36, 5),
    (0.246, 1.55, "crescent", 0.072, 0.043, 0.014, -0.18, 6),
    (0.283, 4.85, "spur",     0.026, 0.020, 0.016, 0.42, 7),
    (0.318, 2.75, "plate",    0.088, 0.078, 0.020, 0.10, 8),
    (0.352, 0.35, "branch",   0.046, 0.028, 0.013, -0.60, 9),
    # --- the orbit's own skeleton (§10, separate movable pieces) ---
    (0.396, 5.90, "brow",     0.112, 0.065, 0.024, 0.15, 10),
    (0.404, 1.20, "support",  0.048, 0.024, 0.013, -0.35, 11),
    (0.438, 2.05, "support",  0.038, 0.020, 0.013, 0.28, 12),
    (0.452, 4.55, "support",  0.044, 0.022, 0.013, -0.12, 13),
    (0.412, 3.35, "knuckle",  0.034, 0.026, 0.018, 0.50, 14),
    # --- past the station ---
    (0.512, 0.85, "crescent", 0.065, 0.037, 0.014, 0.22, 15),
    (0.548, 3.90, "rib",      0.081, 0.025, 0.011, -0.40, 16),
    (0.596, 2.10, "plate",    0.073, 0.057, 0.020, 0.16, 17),
    (0.634, 5.15, "spur",     0.022, 0.017, 0.016, 0.34, 18),
    (0.668, 1.35, "knuckle",  0.038, 0.028, 0.018, -0.22, 19),
    (0.704, 3.55, "branch",   0.038, 0.022, 0.013, 0.46, 20),
    (0.742, 0.45, "crescent", 0.052, 0.030, 0.014, -0.30, 21),
    (0.776, 4.10, "rib",      0.062, 0.020, 0.011, 0.20, 22),
    (0.812, 2.45, "knuckle",  0.030, 0.022, 0.018, -0.15, 23),
    (0.846, 5.45, "spur",     0.018, 0.014, 0.016, 0.38, 24),
    (0.880, 1.75, "crescent", 0.039, 0.022, 0.014, -0.26, 25),
    (0.918, 3.05, "branch",   0.026, 0.015, 0.013, 0.30, 26),
    (0.952, 0.95, "spur",     0.015, 0.012, 0.016, -0.18, 27),
]


def gold_socket(a, v):
    """§9: what a gold root does to the flesh AROUND it — a pressed hollow
    under the footprint and a raised lip at its rim, so the metal visibly
    comes out from INSIDE. Returns (press, lip, near)."""
    press = lip = near = 0.0
    for (gv, ga, kind, length, width, rise, roll, seed) in GOLD:
        du = (a - ga + math.pi) % (2.0 * math.pi) - math.pi
        prof = sample_profile(gv)
        dx = du * prof[0]
        dy = (v - gv) * LENGTH
        d = math.hypot(dx / max(0.004, width * 0.85), dy / max(0.004, length * 0.55))
        press += max(0.0, 1.0 - d * d) * 0.85
        lip += max(0.0, 1.0 - abs(d - 1.25) * 2.2) * 0.7
        near = max(near, max(0.0, 1.0 - d * 0.5))
    return min(press, 1.2), min(lip, 1.0), min(near, 1.0)


# ---------------------------------------------------------------------------
# Helpers for building the separate systems.

def frame_at(v, a):
    """A point and its outward normal on the cage's surface, so every system
    can be seated ON the anatomy rather than near it."""
    radius, flatten, dorsal, twist = sample_profile(v)
    ca, sa = math.cos(a + twist), math.sin(a + twist)
    ex = ca * (1.0 + flatten)
    ez = sa * (1.0 - flatten)
    n = math.hypot(ex, ez)
    ex, ez = ex / n, ez / n
    r = radius
    bowl, mass = orbit_shape(a, v)
    r = r - bowl * ORBIT_R * 0.95 + mass * ORBIT_R * 0.42
    mult, fold = sculpt_forms(a, v, radius)
    r = r * mult - fold * radius
    press, lip, _ = gold_socket(a, v)
    r = r - press * radius * 0.10 + lip * radius * 0.07
    r *= 1.0 + dorsal * math.cos(a)
    pos = Vector((ex * r, v * LENGTH, ez * r))
    nrm = Vector((ex, 0.0, ez)).normalized()
    return pos, nrm


def mesh_from(name, verts, faces, col, flat=False):
    me = bpy.data.meshes.new(name)
    me.from_pydata([tuple(v) for v in verts], [], faces)
    me.validate()
    if not flat:
        for poly in me.polygons:
            poly.use_smooth = True
    obj = bpy.data.objects.new(name, me)
    col.objects.link(obj)
    return obj


def basis_from(nrm, along):
    z = nrm.normalized()
    y = (along - z * along.dot(z))
    if y.length < 1e-4:
        y = Vector((0.0, 1.0, 0.0))
    y.normalize()
    x = y.cross(z).normalized()
    return x, y, z


def place(verts, origin, x, y, z, scale):
    return [origin + x * (p[0] * scale[0]) + y * (p[1] * scale[1]) + z * (p[2] * scale[2])
            for p in verts]


def lathe(section, segments, close_top=True):
    """A surface of revolution from a (radius, height) profile."""
    verts, faces = [], []
    for (r, h) in section:
        for j in range(segments):
            a = j / float(segments) * 2.0 * math.pi
            verts.append((math.cos(a) * r, math.sin(a) * r, h))
    rows = len(section)
    for i in range(rows - 1):
        for j in range(segments):
            k = (j + 1) % segments
            faces.append((i * segments + j, i * segments + k,
                          (i + 1) * segments + k, (i + 1) * segments + j))
    if close_top:
        faces.append(tuple(range((rows - 1) * segments, rows * segments)))
    return verts, faces


# ---------------------------------------------------------------------------
# §5 THE EYE, in four objects.

def build_eye(col):
    made = []
    origin, nrm = frame_at(EYE_V, ORBIT_U)
    # `frame_at` already returns the SOCKET FLOOR — the orbit sank the
    # cage by nearly its own radius there. Sinking the globe a second time
    # buried it completely and the crater came back empty. It sits ON the
    # floor, raised just enough that a cap clears the rim while the brow
    # still eats it from 45 degrees (§4's test).
    centre = origin + nrm * (GLOBE_R * 0.30)
    x, y, z = basis_from(nrm, Vector((0.0, 1.0, 0.0)))
    # GLOBE — slightly irregular, not a mathematical sphere.
    verts, faces = [], []
    rings, segs = 26, 34
    for i in range(rings + 1):
        phi = i / float(rings) * math.pi
        for j in range(segs):
            th = j / float(segs) * 2.0 * math.pi
            wob = 1.0 + 0.035 * math.sin(phi * 3.0 + th * 2.0) + 0.02 * math.cos(th * 5.0)
            verts.append((math.sin(phi) * math.cos(th) * wob,
                          math.sin(phi) * math.sin(th) * wob,
                          math.cos(phi) * wob))
    for i in range(rings):
        for j in range(segs):
            k = (j + 1) % segs
            faces.append((i * segs + j, i * segs + k, (i + 1) * segs + k, (i + 1) * segs + j))
    made.append(mesh_from("EYE_GLOBE", place(verts, centre, x, y, z,
                          (GLOBE_R, GLOBE_R, GLOBE_R)), faces, col))
    # IRIS — physically recessed, with radial fibres and channels.
    verts, faces = [], []
    rings, segs = 10, 40
    for i in range(rings + 1):
        t = i / float(rings)
        r = 0.14 + 0.58 * t
        depth = 0.94 - 0.16 * (1.0 - t) - 0.03 * math.sin(t * 9.0)
        for j in range(segs):
            th = j / float(segs) * 2.0 * math.pi
            fib = 1.0 + 0.05 * math.sin(th * 18.0) * (1.0 - t) + 0.03 * math.sin(th * 7.0)
            verts.append((math.cos(th) * r * fib, math.sin(th) * r * fib, depth))
    for i in range(rings):
        for j in range(segs):
            k = (j + 1) % segs
            faces.append((i * segs + j, i * segs + k, (i + 1) * segs + k, (i + 1) * segs + j))
    made.append(mesh_from("EYE_IRIS", place(verts, centre, x, y, z,
                          (GLOBE_R, GLOBE_R, GLOBE_R)), faces, col))
    # PUPIL INTERIOR — a real funnel, so it catches no direct light.
    sec = [(0.14, 0.94), (0.12, 0.70), (0.08, 0.30), (0.04, -0.10), (0.01, -0.55)]
    verts, faces = lathe(sec, 24)
    made.append(mesh_from("EYE_PUPIL_INTERIOR", place(verts, centre, x, y, z,
                          (GLOBE_R, GLOBE_R, GLOBE_R)), faces, col))
    # CORNEA — a separate convex cap over the recessed iris.
    verts, faces = [], []
    rings, segs = 14, 36
    for i in range(rings + 1):
        phi = i / float(rings) * (math.pi * 0.42)
        for j in range(segs):
            th = j / float(segs) * 2.0 * math.pi
            verts.append((math.sin(phi) * math.cos(th) * 0.80,
                          math.sin(phi) * math.sin(th) * 0.80,
                          0.86 + math.cos(phi) * 0.30))
    for i in range(rings):
        for j in range(segs):
            k = (j + 1) % segs
            faces.append((i * segs + j, i * segs + k, (i + 1) * segs + k, (i + 1) * segs + j))
    made.append(mesh_from("EYE_CORNEA", place(verts, centre, x, y, z,
                          (GLOBE_R, GLOBE_R, GLOBE_R)), faces, col))
    return made, centre, (x, y, z)


# §6 THREE LIDS, each on its own vector, each visible at full open.
# name, sweep axis, arc, reach, RESTING closure, thickness, scale.
# Each lid is a real mass around the orbit, oversized relative to the globe
# so that at full open it still overhangs — the ruling's requirement that a
# still frame contain evidence of three closure systems.
LIDS = [
    ("LID_DORSAL",        1.15, 2.75, 1.05, 0.34, 0.26, 1.34),
    ("LID_VENTROLATERAL", -1.75, 2.35, 0.92, 0.28, 0.20, 1.26),
    ("LID_NICTITATING",   -0.20, 2.95, 0.80, 0.13, 0.060, 1.18),
]


def build_lids(col, centre, axes):
    x, y, z = axes
    made = []
    for (name, sweep, arc, reach, rest, thick, lid_scale) in LIDS:
        verts, faces = [], []
        rows, cols = 9, 26
        # A shell swept about the socket axis, bowed off the globe.
        for i in range(rows):
            t = i / float(rows - 1)
            polar = 1.32 - reach * t
            for j in range(cols):
                aa = (j / float(cols - 1) - 0.5) * arc + sweep
                sp, cp = math.sin(max(0.0, polar)), math.cos(max(0.0, polar))
                # The resting closure leaves real geometry over the globe.
                lean = rest * (0.35 + 0.65 * t)
                verts.append((math.cos(aa) * sp * 1.30, math.sin(aa) * sp * 1.30,
                              cp * 1.24 + lean))
        for i in range(rows - 1):
            for j in range(cols - 1):
                a0 = i * cols + j
                faces.append((a0, a0 + cols, a0 + cols + 1, a0 + 1))
        base = len(verts)
        for (vx, vy, vz) in list(verts):
            n = math.sqrt(vx * vx + vy * vy + vz * vz)
            verts.append((vx - vx / n * thick, vy - vy / n * thick, vz - vz / n * thick))
        for i in range(rows - 1):
            for j in range(cols - 1):
                a0 = base + i * cols + j
                faces.append((a0, a0 + 1, a0 + cols + 1, a0 + cols))
        # The free margin, which is what the player sees when it closes.
        last = (rows - 1) * cols
        for j in range(cols - 1):
            faces.append((last + j, last + j + 1, base + last + j + 1, base + last + j))
        sc = GLOBE_R * lid_scale
        made.append(mesh_from(name, place(verts, centre, x, y, z, (sc, sc, sc)),
                              faces, col))
    return made


# §7 CILIA — 18 hero filaments in three classes, from modelled follicles.

def build_cilia(cols):
    made = []
    rng = random.Random(7717)
    for i in range(18):
        if i % 5 == 2:
            kind, col = "gold", cols[1]
        elif i in (4, 13):
            kind, col = "crystal", cols[2]
        else:
            kind, col = "flesh", cols[0]
        # Asymmetric: a dense arc above the orbit, a sparse one below, a gap.
        if i < 11:
            a = ORBIT_U + -1.30 + 2.55 * (i / 10.0) + rng.uniform(-0.10, 0.10)
        else:
            a = ORBIT_U + 2.10 + 2.40 * ((i - 11) / 6.0) + rng.uniform(-0.16, 0.16)
        v = EYE_V + rng.uniform(-0.045, 0.045)
        origin, nrm = frame_at(v, a)
        length = GLOBE_R * rng.uniform(1.1, 2.6) * (1.15 if kind == "flesh" else 0.85)
        thick = GLOBE_R * rng.uniform(0.055, 0.115)
        # Two or three bends, never a straight spine.
        # Swept curves, clustered directions: they lean hard along the
        # surface before rising, so the orbit gets a whisker halo rather
        # than a thistle.
        bend_a = rng.uniform(0.9, 2.1) * (1 if i % 2 else -1)
        bend_b = rng.uniform(-1.4, 1.4)
        x, y, z = basis_from(nrm, Vector((0.0, 1.0, 0.0)))
        rings, segs = 11, 6
        verts, faces = [], []
        for r in range(rings):
            t = r / float(rings - 1)
            # A modelled follicle: a flare at the base sunk into the flesh.
            rad = thick * (1.9 * math.exp(-t * 18.0) + (1.0 - t) ** 1.6 + 0.06)
            if kind == "crystal" and t > 0.86:
                rad = thick * 1.5           # the terminal lens bulb
            off = (x * (bend_a * t) + y * (bend_b * t * 0.8)) * length * 0.9
            # Rise slowly, sweep quickly.
            centre_p = origin + nrm * (length * (t ** 1.9) - thick * 0.9) + off
            for j in range(segs):
                th = j / float(segs) * 2.0 * math.pi
                verts.append(centre_p + x * (math.cos(th) * rad) + y * (math.sin(th) * rad))
        for r in range(rings - 1):
            for j in range(segs):
                k = (j + 1) % segs
                faces.append((r * segs + j, r * segs + k, (r + 1) * segs + k, (r + 1) * segs + j))
        made.append(mesh_from("CILIUM_%s_%02d" % (kind.upper(), i), verts, faces, col,
                              flat=(kind == "crystal")))
    return made


# §8 SUCKERS — hero geometry with a base mound, raised rim, concave centre.

def sucker_section(variant):
    base = [(0.00, -0.30), (0.55, -0.28), (0.88, -0.10), (1.00, 0.16),
            (0.97, 0.34), (0.80, 0.40), (0.70, 0.24), (0.62, 0.02),
            (0.30, -0.06), (0.00, -0.02)]
    if variant == 1:
        base = [(r * 1.08, h * 0.86) for (r, h) in base]
    elif variant == 2:
        base = [(r * 0.88, h * 1.18) for (r, h) in base]
    elif variant == 3:
        base = [(r * 1.0, h * 1.0) for (r, h) in base]
        base[3] = (1.06, 0.14)
    elif variant == 4:
        base = [(r * 0.94, h * 0.94) for (r, h) in base]
        base[4] = (0.84, 0.26)
    return base


def build_suckers(col):
    made = []
    rng = random.Random(4242)
    rows = 2
    for row in range(rows):
        n = 13
        for i in range(n):
            t = i / float(n - 1)
            v = 0.60 + 0.375 * t
            # Two staggered rows on the ventral side, density rising toward
            # the club.
            a = math.pi + (0.20 if row == 0 else -0.20) * (1.0 - 0.4 * t)
            a += rng.uniform(-0.03, 0.03)
            origin, nrm = frame_at(v, a)
            prof = sample_profile(v)
            size = prof[0] * (0.38 + 0.30 * t) * rng.uniform(0.88, 1.12)
            x, y, z = basis_from(nrm, Vector((0.0, 1.0, 0.0)))
            sec = sucker_section(rng.randrange(5))
            # Slightly irregular circle.
            verts, faces = [], []
            segs = 16
            for (r, h) in sec:
                for j in range(segs):
                    th = j / float(segs) * 2.0 * math.pi
                    jag = 1.0 + 0.06 * math.sin(th * 3.0 + i)
                    verts.append((math.cos(th) * r * jag, math.sin(th) * r * jag, h))
            for k in range(len(sec) - 1):
                for j in range(segs):
                    kk = (j + 1) % segs
                    faces.append((k * segs + j, k * segs + kk,
                                  (k + 1) * segs + kk, (k + 1) * segs + j))
            made.append(mesh_from("SUCKER_%d_%02d" % (row, i),
                                  place(verts, origin, x, y, nrm, (size, size, size)),
                                  faces, col))
    return made


# §9–§10 THE GOLD SKELETON: individual pieces, rooted, with joints.

def gold_piece_geometry(kind, seed):
    rng = random.Random(1000 + seed)
    rings, segs = 9, 11
    width, lift, shift = [], [], []
    for r in range(rings):
        t = r / float(rings - 1)
        if kind == "crescent":
            w = math.sin(t * math.pi) ** 0.6 * rng.uniform(0.6, 1.0)
            l = 0.55 + 0.8 * math.sin(t * math.pi)
            sx = math.sin(t * math.pi) * 0.30
        elif kind in ("plate", "brow"):
            w = (0.35 + 0.95 * math.sin(min(1.0, t * 1.15) * math.pi)) * rng.uniform(0.75, 1.0)
            l = 0.75 + 0.65 * math.sin(t * math.pi * 0.9)
            sx = (t - 0.4) * 0.45
        elif kind == "knuckle":
            lobe = abs(math.sin(t * math.pi * 2.0))
            w = 0.32 + 0.9 * lobe
            l = 0.45 + 0.95 * lobe
            sx = math.cos(t * math.pi * 2.0) * 0.2
        elif kind == "branch":
            if t < 0.5:
                w, l, sx = 0.8 + 0.4 * t, 0.8 + 0.4 * t, 0.0
            else:
                w, l, sx = max(0.06, 1.25 - 1.7 * (t - 0.5)), 1.0 - 1.4 * (t - 0.5), (t - 0.5) * 1.2
        elif kind == "rib":
            w = 0.35 + 0.25 * math.sin(t * math.pi)
            l = 0.5 + 0.7 * math.sin(t * math.pi) - 0.5 * max(0.0, t - 0.75) * 4.0
            sx = t * 0.35
        elif kind == "support":
            w = 0.5 + 0.5 * math.sin(t * math.pi)
            l = 0.6 + 0.7 * math.sin(t * math.pi)
            sx = (t - 0.5) * 0.3
        else:   # spur
            w = 0.35 + 0.6 * (1.0 - t)
            l = -0.4 + 2.1 * t
            sx = t * 0.45
        width.append(max(0.04, w * rng.uniform(0.85, 1.0)))
        lift.append(l)
        shift.append(sx)
    # SEATED PIECES SINK BACK INTO THE FLESH AT BOTH ENDS. Without this the
    # piece terminates in a full-height cut face, and in the grey test the
    # gold read as torn card lying on the body rather than as bone coming out
    # of it. A spur is exempt: it is meant to project.
    if kind in ("plate", "brow", "crescent", "rib", "support", "knuckle"):
        for r in range(rings):
            t = r / float(rings - 1)
            env = math.sin(math.pi * t) ** 0.30
            width[r] *= 0.30 + 0.70 * env
            lift[r] *= 0.12 + 0.88 * env
    verts, faces = [], []
    for r in range(rings):
        t = r / float(rings - 1)
        z = t * 2.0 - 1.0
        for j in range(segs):
            u = j / float(segs - 1)
            xx = (u * 2.0 - 1.0) * width[r] + shift[r]
            # A rounder crown that carries mass across the whole width,
            # rather than a knife-edge that reads as a fin.
            crown = max(0.0, 1.0 - abs(u * 2.0 - 1.0) ** 2.6)
            # A raised ridge along the piece's spine: bone has a section.
            ridge = 0.14 * max(0.0, 1.0 - abs(u * 2.0 - 1.0) * 3.2)
            verts.append((xx, (crown + ridge) * lift[r] - 0.45, z))
    for r in range(rings - 1):
        for j in range(segs - 1):
            a0 = r * segs + j
            faces.append((a0, a0 + segs, a0 + segs + 1, a0 + 1))
    base = len(verts)
    for (vx, vy, vz) in list(verts):
        # A thick underside, so the piece has a visible section where it
        # leaves the flesh instead of being a shell.
        verts.append((vx, vy - 0.55 - 0.25 * (1.0 - abs(vx)), vz))
    for r in range(rings - 1):
        for j in range(segs - 1):
            a0 = base + r * segs + j
            faces.append((a0, a0 + 1, a0 + segs + 1, a0 + segs))
    for r in range(rings - 1):
        for e in (0, segs - 1):
            a0 = r * segs + e
            faces.append((a0, base + a0, base + a0 + segs, a0 + segs))
    # CAP THE TWO ENDS. They were never closed, so every gold piece was an
    # open shell: from three-quarters you looked straight into the inside of
    # a plate, which is precisely why they read as flakes of paper.
    for end in (0, rings - 1):
        for j in range(segs - 1):
            a0 = end * segs + j
            b0 = base + a0
            if end == 0:
                faces.append((a0, a0 + 1, b0 + 1, b0))
            else:
                faces.append((a0 + 1, a0, b0, b0 + 1))
    return verts, faces


def build_gold(cols):
    orbital, structural, joints = cols
    made = []
    for (v, a, kind, length, width, rise, roll, seed) in GOLD:
        origin, nrm = frame_at(v, a)
        along = Vector((0.0, 1.0, 0.0))
        x, y, z = basis_from(nrm, along)
        # Roll the piece about the surface normal so nothing lines up.
        cr, sr = math.cos(roll), math.sin(roll)
        xr = x * cr + y * sr
        yr = y * cr - x * sr
        verts, faces = gold_piece_geometry(kind, seed)
        # Seated AT the flesh, not above it: the mesh's own form takes its
        # ends under the skin.
        # Seated INTO the flesh: only the crown stands proud, and the
        # piece's own underside is below the skin.
        pos = origin - nrm * (rise * 0.28)
        col = orbital if kind in ("brow", "support") else (
            joints if kind == "knuckle" else structural)
        made.append(mesh_from("GOLD_%s_%02d" % (kind.upper(), seed),
                              place(verts, pos, xr, nrm, yr, (width, rise, length)),
                              faces, col, flat=False))
    return made


# §11 DENDRITES: connective detail around the roots, never the silhouette.

def build_dendrites(col):
    made = []
    rng = random.Random(3131)
    verts_all, faces_all = [], []
    for (v, a, kind, length, width, rise, roll, seed) in GOLD:
        if kind in ("spur",):
            continue
        for k in range(2):
            kf = (k + 0.5) / 2.0
            ea = a + (kf - 0.5) * 3.4 * (1 if k % 2 == 0 else -1) * (width / 0.05)
            ev = min(0.99, max(0.0, v + (kf - 0.5) * length * 1.6))
            origin, nrm = frame_at(ev, ea)
            # Millimetres, not centimetres: a root creeping out of the
            # skin beside its plate, never a thorn.
            ln = rise * rng.uniform(0.35, 0.85)
            th = rise * rng.uniform(0.16, 0.30)
            x, y, z = basis_from(nrm, Vector((0.0, 1.0, 0.0)))
            # They lie ALONG the body, barely lifting off it.
            lean = (nrm * 0.35 + y * (kf - 0.5) * 1.4 + x * 0.5).normalized()
            rings, segs = 6, 5
            base_i = len(verts_all)
            for r in range(rings):
                t = r / float(rings - 1)
                rad = th * ((1.0 - t) ** 2 + 0.05)
                bend = x * math.sin(t * 3.0) * ln * 0.18
                c = origin + lean * (ln * t - th) + bend
                for j in range(segs):
                    ang = j / float(segs) * 2.0 * math.pi
                    verts_all.append(c + x * (math.cos(ang) * rad) + y * (math.sin(ang) * rad))
            for r in range(rings - 1):
                for j in range(segs):
                    kk = (j + 1) % segs
                    faces_all.append((base_i + r * segs + j, base_i + r * segs + kk,
                                      base_i + (r + 1) * segs + kk, base_i + (r + 1) * segs + j))
    made.append(mesh_from("GOLD_DENDRITES", verts_all, faces_all, col))
    return made


# §12 CRYSTALS: faceted, flat-shaded, rooted in gold, with an inner core.

CRYSTALS = [
    # The orbital pair sit on the RIM, in the gold, never across the socket.
    (0.375, 1.85, 0.022, 0),
    (0.462, 5.35, 0.017, 1),
    (0.200, 3.30, 0.024, 2),
    (0.560, 1.10, 0.019, 3),
    (0.690, 4.40, 0.016, 4),
    (0.822, 2.30, 0.013, 5),
    (0.912, 5.70, 0.011, 6),
]


def crystal_geometry(seed):
    rng = random.Random(500 + seed)
    sides, levels = 7, 5
    verts, faces = [], []
    for l in range(levels):
        t = l / float(levels - 1)
        r = (1.0 - 0.62 * t) * (1.0 - 0.2 * t * t)
        lean = Vector((t * t * 0.34, 0.0, t * 0.14))
        for sdx in range(sides):
            ang = sdx / float(sides) * 2.0 * math.pi
            jag = rng.uniform(0.7, 1.15)
            verts.append((math.cos(ang) * r * jag + lean.x, t * 2.0 - 0.55,
                          math.sin(ang) * r * jag + lean.z))
    for l in range(levels - 1):
        for sdx in range(sides):
            a0 = l * sides + sdx
            b = l * sides + (sdx + 1) % sides
            c = (l + 1) * sides + sdx
            d = (l + 1) * sides + (sdx + 1) % sides
            faces.append((a0, c, d, b))
    tip = len(verts)
    verts.append((0.30, 1.72, 0.12))
    for sdx in range(sides):
        faces.append(((levels - 1) * sides + sdx, tip,
                      (levels - 1) * sides + (sdx + 1) % sides))
    return verts, faces


def build_crystals(col):
    made = []
    for (v, a, size, seed) in CRYSTALS:
        origin, nrm = frame_at(v, a)
        x, y, z = basis_from(nrm, Vector((0.0, 1.0, 0.0)))
        verts, faces = crystal_geometry(seed)
        pos = origin - nrm * (size * 0.35)
        made.append(mesh_from("CRYSTAL_%02d" % seed,
                              place(verts, pos, x, nrm, y, (size, size, size)),
                              faces, col, flat=True))
        # The inner core, for the fake volumetric interior.
        made.append(mesh_from("CRYSTAL_%02d_CORE" % seed,
                              place(verts, pos, x, nrm, y,
                                    (size * 0.55, size * 0.55, size * 0.55)),
                              faces, col, flat=True))
    return made


# §13 THE ROOT MEMBRANE: its own radial mesh, able to bulge and cling.

# The membrane's surface, as ONE function. The sheet, its gold anchors and
# its crystal nodules are all placed from this, so an anchor can never drift
# off a sheet that was rebuilt without it.
MEMBRANE_PHASE = [4.117, 1.902, 5.640, 0.771]


def membrane_point(t, a, root_r):
    """§13's sheet at (radial t, angle a). Mirrors build_membrane exactly."""
    ph = MEMBRANE_PHASE
    border = (1.0
              + 0.13 * math.sin(a * 2.0 + ph[0])
              + 0.085 * math.sin(a * 5.0 + ph[1])
              + 0.045 * math.sin(a * 11.0 + ph[2]))
    r = root_r * (0.78 + 2.62 * (t ** 0.85))
    jag = 1.0 + (border - 1.0) * (t ** 1.5)
    gather = 0.34 * root_r * math.sin(a * 9.0 + ph[3]) * (1.0 - t) ** 1.4
    wrinkle = 0.16 * root_r * math.sin(a * 17.0) * t * (1.0 - t)
    lift = (1.0 - t) ** 2 * root_r * 1.55 - (t ** 1.3) * root_r * 0.62
    lift += gather + wrinkle
    lift += 0.22 * root_r * smooth01((t - 0.72) / 0.28) * (0.6 + 0.4 * math.sin(a * 4.0))
    rr = r * jag * (1.0 + 0.10 * math.sin(a * 9.0 + ph[3]) * t * (1.0 - t) ** 0.8)
    return Vector((math.cos(a) * rr, lift, math.sin(a) * rr))


def membrane_frame(t, a, root_r):
    """A point on the sheet and its outward normal, by finite difference."""
    p = membrane_point(t, a, root_r)
    dt = membrane_point(min(1.0, t + 0.02), a, root_r) - p
    da = membrane_point(t, a + 0.03, root_r) - p
    n = da.cross(dt)
    if n.length < 1e-9:
        n = Vector((0.0, 1.0, 0.0))
    n.normalize()
    if n.y < 0.0:
        n = -n
    return p, n


## §13 — "several gold anchors, crystal nodules". Authored, irregular, and
## placed toward the outer sheet where a real anchor would pin it down.
##   t, angle, kind, length, width, rise, seed
MEMBRANE_GOLD = [
    (0.74, 0.42, "plate",    0.070, 0.055, 0.013, 60),
    (0.62, 2.05, "rib",      0.090, 0.030, 0.010, 61),
    (0.81, 3.31, "crescent", 0.062, 0.041, 0.011, 62),
    (0.55, 4.60, "plate",    0.058, 0.049, 0.012, 63),
    (0.78, 5.44, "spur",     0.034, 0.024, 0.014, 64),
    (0.44, 1.28, "rib",      0.072, 0.026, 0.009, 65),
]
##   t, angle, size, seed
MEMBRANE_CRYSTALS = [
    (0.36, 0.95, 0.020, 70), (0.52, 2.71, 0.015, 71),
    (0.29, 4.02, 0.024, 72), (0.67, 5.90, 0.017, 73),
    (0.47, 3.55, 0.013, 74), (0.71, 1.72, 0.019, 75),
    (0.24, 5.10, 0.016, 76),
]


def build_membrane(col):
    """§13 — a THICK, IRREGULAR FLOWER/SOCKET, not a paper collar.

    The posed grey test showed the old one for what it was: a single-sided
    sheet with a three-fold star border, which reads as folded card. §13 asks
    for a thick flesh sheet with folds stretching toward the root, an
    irregular attachment border and tension wrinkles -- the thing that makes
    the creature appear to extrude through reality rather than through a hole.
    """
    rings, segs = 16, 56
    verts, faces = [], []
    root_r = sample_profile(0.0)[0]
    for i in range(rings):
        t = i / float(rings - 1)
        for j in range(segs):
            a = j / float(segs) * 2.0 * math.pi
            verts.append(tuple(membrane_point(t, a, root_r)))
    for i in range(rings - 1):
        for j in range(segs):
            k = (j + 1) % segs
            faces.append((i * segs + j, i * segs + k, (i + 1) * segs + k, (i + 1) * segs + j))
    obj = mesh_from("MEMBRANE_ROOT", verts, faces, col)
    # THICKNESS. §13 says "thick"; it had none, and a zero-thickness sheet is
    # the single loudest tell that a thing is not made of meat.
    solid = obj.modifiers.new("Solidify", "SOLIDIFY")
    solid.thickness = root_r * 0.10
    solid.offset = 0.0
    solid.use_rim = True
    smooth = obj.modifiers.new("Subdivision", "SUBSURF")
    smooth.levels = 1
    smooth.render_levels = 1
    made = [obj]
    # §13's gold anchors: the metal that pins the sheet to the world.
    for (t, a, kind, length, width, rise, seed) in MEMBRANE_GOLD:
        origin, nrm = membrane_frame(t, a, root_r)
        # ALONG THE SHEET, NOT ALONG THE WORLD. The membrane's normal is
        # close to +Y across most of its area, so orienting these off world
        # up put the "along" vector nearly parallel to the normal and the
        # basis degenerated -- the anchors came out as rectangular tabs
        # standing off the rim sideways. A piece lying on a sheet runs
        # RADIALLY, out from the limb toward the border.
        x, y, z = basis_from(nrm, Vector((math.cos(a), 0.0, math.sin(a))))
        gverts, gfaces = gold_piece_geometry(kind, seed)
        pos = origin - nrm * (rise * 0.28)
        made.append(mesh_from("GOLD_ANCHOR_%02d" % seed,
                              place(gverts, pos, x, nrm, y, (width, rise, length)),
                              gfaces, col, flat=False))
    # §13's crystal nodules: mineral growing out of the sheet, not on it.
    for (t, a, size, seed) in MEMBRANE_CRYSTALS:
        origin, nrm = membrane_frame(t, a, root_r)
        x, y, z = basis_from(nrm, Vector((math.cos(a), 0.0, math.sin(a))))
        cverts, cfaces = crystal_geometry(seed)
        pos = origin - nrm * (size * 0.40)
        made.append(mesh_from("CRYSTAL_NODULE_%02d" % seed,
                              place(cverts, pos, x, nrm, y, (size, size, size)),
                              cfaces, col, flat=True))
    return made


def build_cage():
    """§1–§2, §4: the deformation cage, with the orbit cut into it."""
    rings = 150                     # longitudinal sections after refinement
    bm = bmesh.new()
    grid = []
    for i in range(rings):
        v = i / (rings - 1.0)
        radius, flatten, dorsal, twist = sample_profile(v)
        row = []
        for j in range(RING_SEGMENTS):
            u = j / float(RING_SEGMENTS)
            a = u * 2.0 * math.pi
            # The cross-section: an ellipse that flattens and rotates.
            ca, sa = math.cos(a + twist), math.sin(a + twist)
            ex = ca * (1.0 + flatten)
            ez = sa * (1.0 - flatten)
            n = math.hypot(ex, ez)
            ex, ez = ex / n, ez / n
            r = radius
            # §4: the orbit.
            bowl, mass = orbit_shape(a, v)
            r = r - bowl * ORBIT_R * 0.95 + mass * ORBIT_R * 0.42
            # §3: the sculpt forms — muscular bundles, asymmetric bulges,
            # compression folds, tension creases, the soft ventral field.
            mult, fold = sculpt_forms(a, v, radius)
            r = r * mult - fold * radius
            # §9: every gold root presses the flesh in and raises a lip
            # around its entry, so the metal comes out from INSIDE.
            press, lip, _ = gold_socket(a, v)
            r = r - press * radius * 0.10 + lip * radius * 0.07
            r *= 1.0 + dorsal * math.cos(a)
            row.append(bm.verts.new((ex * r, v * LENGTH, ez * r)))
        grid.append(row)
    bm.verts.ensure_lookup_table()
    for i in range(rings - 1):
        for j in range(RING_SEGMENTS):
            k = (j + 1) % RING_SEGMENTS
            bm.faces.new((grid[i][j], grid[i][k], grid[i + 1][k], grid[i + 1][j]))
    # Cap the tip.
    bm.faces.new([grid[rings - 1][j] for j in range(RING_SEGMENTS)])
    # AND CAP THE ROOT. It was left open "for the membrane to close", and the
    # membrane does not close it: photographed from under the socket you look
    # straight up a hollow pipe and see the inside of the creature's own
    # tube. §13's point is that the root must not simply end at the wall, and
    # an open hole ends worse than anything. A shallow dome pushed UP into
    # the limb reads as flesh continuing into the wall, and is hidden by the
    # membrane from every angle that is not inside the socket.
    root_r0 = sample_profile(0.0)[0]
    plug = bm.verts.new((0.0, root_r0 * 0.55, 0.0))
    bm.verts.ensure_lookup_table()
    for j in range(RING_SEGMENTS):
        k = (j + 1) % RING_SEGMENTS
        bm.faces.new((grid[0][k], grid[0][j], plug))
    # THE WINDING WAS INSIDE OUT. Every ring quad was wound so the cage's
    # normals pointed at its own axis: signed volume negative, and the
    # outermost +X vertex carrying normal.x = -0.99. Blender never showed it
    # because EEVEE shades both sides, but Godot culls back faces, so the
    # hero creature's body would have rendered inside-out in the engine --
    # and the clearance check read every seated piece as buried in flesh and
    # every buried piece as clear, which is how it was found.
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bm.normal_update()
    me = bpy.data.meshes.new("TENTACLE_BODY_CAGE")
    bm.to_mesh(me)
    bm.free()
    obj = bpy.data.objects.new("TENTACLE_BODY_CAGE", me)
    return obj


def add_vertex_masks(obj):
    """§22: the anatomy Blender already knows, so Godot need not guess."""
    me = obj.data
    names = ["flesh_thickness", "wetness", "vascular", "papilla", "gold_root",
             "contact_sensitive", "sucker_region", "phase_sensitive",
             "ocular_region", "distal_region"]
    layers = {}
    for n in names:
        layers[n] = me.color_attributes.new(name=n, type="FLOAT_COLOR", domain="POINT")
    for i, vert in enumerate(me.vertices):
        p = vert.co
        v = min(max(p.y / LENGTH, 0.0), 1.0)
        ang = math.atan2(p.z, p.x)
        prof = sample_profile(v)
        bowl, mass = orbit_shape(ang, v)
        # Thickness: the root and the station are thick; the ribbon, the
        # club's rim and the socket's lids are membranes.
        thick = min(1.0, prof[0] / 0.09) * (1.0 - 0.55 * bowl)
        thick *= 1.0 - 0.45 * max(0.0, (v - 0.9) / 0.1)
        ventral = max(0.0, -math.cos(ang - math.pi))
        distal = max(0.0, (v - 0.62) / 0.38)
        sucker = ventral * distal
        _set(layers["flesh_thickness"], i, thick)
        _set(layers["ocular_region"], i, min(1.0, bowl + mass))
        _set(layers["distal_region"], i, distal)
        _set(layers["sucker_region"], i, sucker)
        _set(layers["contact_sensitive"], i, sucker * 0.8 + (1.0 if v > 0.95 else 0.0) * 0.6)
        _set(layers["wetness"], i, 0.25 + 0.55 * bowl + 0.4 * sucker)
        _set(layers["vascular"], i, 0.4 + 0.4 * math.sin(v * 11.0 + ang * 2.0) * 0.5)
        _set(layers["papilla"], i, max(0.0, math.sin(v * 23.0) * math.cos(ang * 3.0)) * 0.7)
        _set(layers["phase_sensitive"], i, max(0.0, math.sin(v * 6.0 + 1.2)) * 0.6)
        _press, _lip, near = gold_socket(ang, v)
        _set(layers["gold_root"], i, near)
    log("vertex masks: %s" % ", ".join(names))


def _set(layer, index, value):
    layer.data[index].color = (value, value, value, 1.0)


# ---------------------------------------------------------------------------
# §14–§15 THE RIG. Twenty-eight deform bones along the limb — heavy and few
# at the root, dense and light at the tip — so the flesh can bend sharply,
# twist, compress and curl its distal third without the cage collapsing.
# Secondary bones for the eye, the three lids, the ocular gold, the cilia,
# the hero suckers and the membrane, because every one of those has to move
# on its own (§24 is only worth having if the systems are independent).

BONE_PLAN = [
    # (count, from v, to v, label) — the ruling's own hierarchy.
    (5, 0.00, 0.20, "root"),      # heavy proximal
    (6, 0.20, 0.50, "ocular"),    # ocular / midsection
    (9, 0.50, 0.80, "mid"),       # flexible mid/distal
    (8, 0.80, 1.00, "tip"),       # highly flexible tip
]


def build_rig(col, cage, extras):
    arm_data = bpy.data.armatures.new("TENTACLE_RIG")
    arm = bpy.data.objects.new("TENTACLE_RIG", arm_data)
    col.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    edit = arm_data.edit_bones
    spine = []
    prev = None
    for (count, v0, v1, label) in BONE_PLAN:
        for i in range(count):
            a = v0 + (v1 - v0) * (i / float(count))
            b = v0 + (v1 - v0) * ((i + 1) / float(count))
            bone = edit.new("DEF_%s_%02d" % (label, i))
            bone.head = (0.0, a * LENGTH, 0.0)
            bone.tail = (0.0, b * LENGTH, 0.0)
            # B-Bones: the flesh bends smoothly between few controls (§14).
            bone.bbone_segments = 4
            if prev is not None:
                bone.parent = prev
                bone.use_connect = True
            prev = bone
            spine.append((bone.name, a, b))
    # The secondary rigs. Each is parented to whichever spine bone actually
    # covers its place on the body, so it rides the flesh.
    def bone_for(v):
        for (name, a, b) in spine:
            if a <= v <= b:
                return name
        return spine[-1][0]

    for (name, v, a_ang, length) in extras:
        bone = edit.new(name)
        pos, nrm = frame_at(v, a_ang)
        bone.head = pos
        bone.tail = pos + nrm * max(0.008, length)
        bone.parent = edit[bone_for(v)]
        bone.use_connect = False
    bpy.ops.object.mode_set(mode="OBJECT")
    # Twist controls (§15): the roll is distributed root 10 / mid 30 /
    # distal 60, recorded on the bones so the animator does not dump a whole
    # rotation into one joint.
    for (name, a, b) in spine:
        pb = arm.pose.bones.get(name)
        if pb is None:
            continue
        t = (a + b) * 0.5
        share = 0.10 if t < 0.25 else (0.30 if t < 0.62 else 0.60)
        pb["twist_share"] = share
        # THE COLLAR HOLDS THE ROOT (§13, §14). The membrane is what the
        # creature is coming THROUGH, so the first few centimetres of limb
        # are gripped by it and cannot swing freely. Without a limit here the
        # clearance check measured 112 mm of shaft driven straight through
        # the collar in every pose that bends the root -- §23's "membrane
        # collapse" -- and no amount of re-binding the membrane fixes that,
        # because the fault is the pose, not the skin.
        #
        # A real limit on the rig, not a rule in a document: any animator who
        # over-rotates the root now gets clamped instead of a collapsed
        # membrane.
        if t < 0.09:
            limit = pb.constraints.new("LIMIT_ROTATION")
            limit.use_limit_x = limit.use_limit_y = limit.use_limit_z = True
            grip = math.radians(7.0)
            limit.min_x, limit.max_x = -grip, grip
            limit.min_y, limit.max_y = -grip * 1.4, grip * 1.4
            limit.min_z, limit.max_z = -grip, grip
            limit.owner_space = "LOCAL"
    return arm, spine


def nearest_bone(arm, point, spine):
    """The deform bone whose middle is closest to a point, in armature space."""
    names = [e[0] if isinstance(e, (tuple, list)) else e for e in spine]
    best, best_d = names[0], 1e9
    for name in names:
        bone = arm.data.bones.get(name)
        if bone is None:
            continue
        mid = (bone.head_local + bone.tail_local) * 0.5
        d = (mid - point).length
        if d < best_d:
            best_d, best = d, name
    return best


def cage_weight_table(cage):
    """Every cage vertex's bone weights, and a KD-tree to find them by
    position. This is what the riders inherit."""
    names = [g.name for g in cage.vertex_groups]
    table = []
    for v in cage.data.vertices:
        table.append([(names[g.group], g.weight) for g in v.groups
                      if g.group < len(names)])
    kd = mathutils.kdtree.KDTree(len(cage.data.vertices))
    for i, v in enumerate(cage.data.vertices):
        kd.insert(cage.matrix_world @ v.co, i)
    kd.balance()
    return kd, table


def bind_inherit(obj, arm, kd, table):
    """DEFORM EXACTLY AS THE FLESH UNDER YOU DOES.

    Binding each hard piece to its single nearest bone was wrong, and the
    bind check measured how wrong: twelve of ninety-five riders drifted up to
    15.5 mm when the limb bent, which is a gold spur hanging in mid-air.
    The reason is that the flesh at a joint takes a BLEND of two bones'
    transforms while a single-bone rider takes one of them pure, so the two
    diverge exactly where the creature bends most.

    So each rider vertex copies the weights of the nearest cage vertex. The
    piece still reads as rigid -- its whole footprint sits on nearly the same
    weights -- but it is now welded to the flesh by construction rather than
    by hoping one bone is close enough.
    """
    buckets = {}
    for vi, vert in enumerate(obj.data.vertices):
        _co, idx, _d = kd.find(obj.matrix_world @ vert.co)
        if idx is None or idx >= len(table):
            continue
        for gname, w in table[idx]:
            key = (gname, round(w, 2))
            buckets.setdefault(key, []).append(vi)
    for (gname, w), indices in buckets.items():
        group = obj.vertex_groups.get(gname) or obj.vertex_groups.new(name=gname)
        group.add(indices, w, "REPLACE")
    obj.parent = arm
    obj.matrix_parent_inverse = arm.matrix_world.inverted()
    mod = obj.modifiers.new("Armature", "ARMATURE")
    mod.object = arm
    return len(buckets) > 0


def bind_membrane(obj, arm, kd, table, root_bone, span_from=None):
    """§13 — a collar that STRETCHES between the limb and the wall.

    Neither extreme works. Bound to the flesh it swings with the shaft and is
    no longer an aperture; bound rigidly to the wall the shaft sweeps clean
    through it -- the clearance check measured 112 mm of limb passing through
    the collar in every pose that bends the root, which is §23's "membrane
    collapse" exactly.

    So it is graded by radius: the inner edge inherits the flesh's own
    weights and travels with the limb, the outer rim is anchored to the root
    bone and stays with the wall, and the sheet in between takes the blend.
    That is the "bulge, thin, stretch, cling" §13 asks for, and it is what an
    aperture physically does.
    """
    radii = [math.hypot(v.co.x, v.co.z) for v in obj.data.vertices]
    if not radii:
        return False
    # The grading must come from the SHEET's radial range, not the piece's
    # own. A 60 mm gold anchor spans almost no radius, so measured against
    # itself its near edge would follow the flesh while its far edge stayed
    # with the wall -- the piece torn in half across 60 mm.
    if span_from is not None:
        r_in, r_out = span_from
    else:
        r_in, r_out = min(radii), max(radii)
    span = max(1e-6, r_out - r_in)
    buckets = {}
    for vi, vert in enumerate(obj.data.vertices):
        # 0 at the limb, 1 at the rim.
        mix = min(1.0, max(0.0, (radii[vi] - r_in) / span)) ** 0.75
        if mix < 0.999:
            _co, idx, _d = kd.find(obj.matrix_world @ vert.co)
            if idx is not None and idx < len(table):
                for gname, w in table[idx]:
                    key = (gname, round(w * (1.0 - mix), 2))
                    if key[1] > 0.0:
                        buckets.setdefault(key, []).append(vi)
        if mix > 0.001:
            buckets.setdefault((root_bone, round(mix, 2)), []).append(vi)
    for (gname, w), indices in buckets.items():
        group = obj.vertex_groups.get(gname) or obj.vertex_groups.new(name=gname)
        group.add(indices, w, "ADD" if gname == root_bone else "REPLACE")
    obj.parent = arm
    obj.matrix_parent_inverse = arm.matrix_world.inverted()
    mod = obj.modifiers.new("Armature", "ARMATURE")
    mod.object = arm
    return True


def bind_rigid(obj, arm, spine):
    """Ride one bone, rigidly.

    A gold plate, a crystal, a sucker and an eyelid are HARD PIECES SITTING ON
    FLESH. They must travel with the limb and must not stretch when it bends,
    which is exactly one bone at weight one -- not automatic weights, which
    would shear a mineral plate across a joint.
    """
    centre = mathutils.Vector((0.0, 0.0, 0.0))
    for v in obj.data.vertices:
        centre += v.co
    if len(obj.data.vertices):
        centre /= len(obj.data.vertices)
    centre = obj.matrix_world @ centre
    name = nearest_bone(arm, arm.matrix_world.inverted() @ centre, spine)
    group = obj.vertex_groups.new(name=name)
    group.add(list(range(len(obj.data.vertices))), 1.0, "REPLACE")
    obj.parent = arm
    obj.matrix_parent_inverse = arm.matrix_world.inverted()
    mod = obj.modifiers.new("Armature", "ARMATURE")
    mod.object = arm
    return name


def skin(cage, arm, others, spine, soft=()):
    """Bind the cage and every system to the rig.

    THIS USED TO NOT WORK AT ALL. It added an ARMATURE modifier to each
    system object and stopped -- but a modifier with no vertex groups deforms
    nothing, so every eye, lid, cilium, sucker, gold plate, crystal and
    membrane was unbound: bend the limb and they stay behind in space. The
    glTF exporter had been saying so on every run, once per object ("has no
    skin, skipping"), for as long as the script has existed.

    The cage takes automatic weights. Everything else inherits the flesh's
    own weights at its contact point. The one exception is the membrane,
    which is an APERTURE rather than a garment: it belongs to the wall the
    creature is coming through, so it rides the root bone rigidly and the
    limb bends through it.
    """
    bpy.ops.object.select_all(action="DESELECT")
    cage.select_set(True)
    arm.select_set(True)
    bpy.context.view_layer.objects.active = arm
    try:
        bpy.ops.object.parent_set(type="ARMATURE_AUTO")
    except RuntimeError:
        mod = cage.modifiers.new("Armature", "ARMATURE")
        mod.object = arm
    # The cage now carries automatic weights; the riders inherit them.
    kd, table = cage_weight_table(cage)
    # THE MEMBRANE IS AN APERTURE, NOT A SLEEVE (§13, and §23's "membrane
    # collapse"). Bound softly to the nearby flesh it swung with the shaft,
    # and the clearance check measured the consequence: 112 mm of membrane
    # driven through the limb's own body in every pose that bends the root.
    # It is attached to the wall the creature is coming through, so it rides
    # the ROOT bone rigidly and the limb bends through it.
    root_bone = spine[0][0] if isinstance(spine[0], (tuple, list)) else spine[0]
    soft_set = set(soft)
    # The sheet's own radial range, shared by everything riding it.
    sheet_span = None
    for obj in soft:
        if obj.name == "MEMBRANE_ROOT":
            rr = [math.hypot(v.co.x, v.co.z) for v in obj.data.vertices]
            if rr:
                sheet_span = (min(rr), max(rr))
            break
    rigid = 0
    fallback = 0
    for obj in others:
        if obj in soft_set:
            bind_membrane(obj, arm, kd, table, root_bone, sheet_span)
            continue
        if not bind_inherit(obj, arm, kd, table):
            # Nothing under it to inherit from: fall back to one bone.
            bind_rigid(obj, arm, spine)
            fallback += 1
        rigid += 1
    log("bound %d riders by inherited flesh weights (%d fell back to one bone)"
        % (rigid, fallback))


def main():
    clear_scene()
    random.seed(20260822)
    root_col = collection("DREAM_TENTACLE")
    body_col = collection("BODY", root_col)
    cage = build_cage()
    body_col.objects.link(cage)
    add_vertex_masks(cage)
    # A subdivision for the render-time cage; the game mesh comes from the
    # bake, not from this.
    mod = cage.modifiers.new("Subdivision", "SUBSURF")
    mod.levels = 1
    mod.render_levels = 2
    log("cage: %d verts, %d faces" % (len(cage.data.vertices), len(cage.data.polygons)))
    # §24: modular collections, so Godot can treat each system differently.
    eye_col = collection("EYE", root_col)
    cilia_cols = [collection("CILIA_FLESH", root_col), collection("CILIA_GOLD", root_col),
                  collection("CILIA_CRYSTAL", root_col)]
    gold_cols = [collection("GOLD_ORBITAL", root_col), collection("GOLD_STRUCTURAL", root_col),
                 collection("GOLD_JOINTS", root_col)]
    dend_col = collection("GOLD_DENDRITES", root_col)
    crystal_col = collection("CRYSTALS", root_col)
    sucker_col = collection("SUCKERS", root_col)
    membrane_col = collection("MEMBRANE", root_col)
    eyes, centre, axes = build_eye(eye_col)
    lids = build_lids(eye_col, centre, axes)
    cilia = build_cilia(cilia_cols)
    suckers = build_suckers(sucker_col)
    gold = build_gold(gold_cols)
    dendrites = build_dendrites(dend_col)
    crystals = build_crystals(crystal_col)
    membrane = build_membrane(membrane_col)
    # §14: the rig, and everything bound to it.
    rig_col = collection("RIG", root_col)
    extras = [("CTL_EYE", EYE_V, ORBIT_U, GLOBE_R * 1.4),
              ("CTL_LID_DORSAL", EYE_V, ORBIT_U + 1.15, GLOBE_R),
              ("CTL_LID_VENTRO", EYE_V, ORBIT_U - 1.75, GLOBE_R),
              ("CTL_LID_NICT", EYE_V, ORBIT_U - 0.20, GLOBE_R),
              ("CTL_MEMBRANE", 0.02, 0.0, 0.05)]
    for idx, (gv, ga, kind, _l, _w, _r, _ro, seed) in enumerate(GOLD):
        if kind in ("brow", "support"):
            extras.append(("CTL_GOLD_%02d" % seed, gv, ga, 0.02))
    arm, spine = build_rig(rig_col, cage, extras)
    movable = eyes + lids + cilia + suckers + gold + dendrites + crystals + membrane
    skin(cage, arm, movable, spine, soft=membrane)
    log("rig: %d deform bones, %d secondary, %d bound objects"
        % (len(spine), len(extras), len(movable)))
    log("eye %d + lids %d, cilia %d, suckers %d, gold %d, dendrites %d, crystals %d, membrane %d"
        % (len(eyes), len(lids), len(cilia), len(suckers), len(gold), len(dendrites),
           len(crystals), len(membrane)))
    os.makedirs(os.path.dirname(BLEND_OUT), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=BLEND_OUT)
    log("saved %s" % BLEND_OUT)
    export_glb()


def export_glb():
    """Hand the layered creature to Godot. Every system stays a separate
    object so the engine can drive them independently (§24) — the whole
    point of modelling it in layers rather than as one sculpt."""
    os.makedirs(GLB_DIR, exist_ok=True)
    for obj in bpy.data.objects:
        obj.select_set(obj.type in {"MESH", "ARMATURE"})
    try:
        bpy.ops.export_scene.gltf(
            filepath=GLB_OUT,
            export_format="GLB",
            use_selection=True,
            export_apply=True,
            export_yup=True,
            export_normals=True,
            export_colors=True,
            export_materials="NONE",
        )
    except TypeError:
        # Older/newer exporter signatures differ; fall back to the minimum.
        bpy.ops.export_scene.gltf(filepath=GLB_OUT, export_format="GLB",
                                  use_selection=True)
    size = os.path.getsize(GLB_OUT) / 1024.0
    tris = sum(len(o.data.loop_triangles) if o.type == "MESH" else 0
               for o in bpy.data.objects)
    log("exported %s (%.0f kB)" % (GLB_OUT, size))


if __name__ == "__main__":
    main()
