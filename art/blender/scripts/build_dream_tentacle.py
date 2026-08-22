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
    (0.570, 0.045, 0.52, 0.02, 0.82),   # the flattened RIBBON
    (0.625, 0.052, 0.34, 0.04, 0.94),
    (0.670, 0.044, 0.22, 0.02, 1.05),   # ribbed: swells and pinches
    (0.715, 0.050, 0.26, 0.00, 1.15),
    (0.760, 0.039, 0.18, 0.00, 1.25),
    (0.805, 0.045, 0.12, 0.00, 1.34),   # an articulated knuckle
    (0.850, 0.031, 0.14, 0.00, 1.42),   # the narrowing: dexterous
    (0.895, 0.027, 0.10, 0.00, 1.49),
    (0.935, 0.031, 0.06, 0.00, 1.55),
    (0.968, 0.038, 0.03, 0.00, 1.60),   # the sensory CLUB
    (0.990, 0.030, 0.00, 0.00, 1.63),
    (1.000, 0.012, 0.00, 0.00, 1.65),
]


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
ORBIT_R = 0.055         # the socket's radius on the surface, metres


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
            r *= 1.0 + dorsal * math.cos(a)
            row.append(bm.verts.new((ex * r, v * LENGTH, ez * r)))
        grid.append(row)
    bm.verts.ensure_lookup_table()
    for i in range(rings - 1):
        for j in range(RING_SEGMENTS):
            k = (j + 1) % RING_SEGMENTS
            bm.faces.new((grid[i][j], grid[i][k], grid[i + 1][k], grid[i + 1][j]))
    # Cap the tip; the root stays open for the membrane to close.
    bm.faces.new([grid[rings - 1][j] for j in range(RING_SEGMENTS)])
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
        _set(layers["gold_root"], i, 0.0)   # filled when the gold is placed
    log("vertex masks: %s" % ", ".join(names))


def _set(layer, index, value):
    layer.data[index].color = (value, value, value, 1.0)


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
    os.makedirs(os.path.dirname(BLEND_OUT), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=BLEND_OUT)
    log("saved %s" % BLEND_OUT)


if __name__ == "__main__":
    main()
