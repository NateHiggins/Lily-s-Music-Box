"""The airmail biplane, authored in Blender (v1r_period_layer_20261109: the
aircraft only).

V1's PeriodRealityLayer drew one "compressed-distance Pitcairn Mailwing read"
from six vertex-coloured boxes: a fabric biplane with a narrow body, upper and
lower planes, a conventional tail and a dark radial nose. V2 keeps that
aircraft and V1's pass rules, and builds it at its true size for distant
flight: a 10 m upper plane on a 6.7 m body, staggered lower plane, interplane
and cabane struts, a nine-cylinder radial, a split-axle undercarriage and a
tail skid. The propeller disc is its own part, origin on the shaft.

Runtime frame: nose toward -Z, +Y up, origin on the thrust line under the
upper plane; metres. No lettering or registration (RUL-008).

Deterministic: no randomness.

  blender -b --python-exit-code 1 -P art/blender/scripts/build_airmail_biplane.py -- <review_dir>
Writes game/assets/props/airmail_biplane.glb, art/blender/airmail_biplane.blend
and review renders under <review_dir>.
"""
import bpy, math, sys
from mathutils import Vector, Matrix
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import v1r_small_stock as kit

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(sys.argv[sys.argv.index("--") + 1]) if "--" in sys.argv else ROOT / "tmp/airmail_biplane"
(OUT / "review").mkdir(parents=True, exist_ok=True)
SHAFT_Z = -3.12


def section(w, h, y, z, n=8):
    """A rounded-box body section at station z."""
    ring = []
    for k in range(n):
        a = kit.TAU * (k + 0.5) / n
        c, s = math.cos(a), math.sin(a)
        ring.append((math.copysign(abs(c) ** 0.6, c) * w / 2, y + math.copysign(abs(s) ** 0.6, s) * h / 2, z))
    return ring


def plane(s, span, chord, thick, y, z_mid, tip=0.35):
    """A wing: a cambered section lofted across the span, tips tapered in chord."""
    def rib(x, scale):
        c = chord * scale
        t = thick * scale
        z0 = z_mid - chord / 2 + (chord - c) * 0.35
        return [(x, y, z0), (x, y + t * 0.75, z0 + c * 0.12), (x, y + t, z0 + c * 0.38),
                (x, y + t * 0.35, z0 + c), (x, y + t * 0.05, z0 + c * 0.55), (x, y - t * 0.05, z0 + c * 0.15)]
    half = span / 2
    ribs = [rib(-half, 0.55), rib(-half + tip, 1.0), rib(0.0, 1.0), rib(half - tip, 1.0), rib(half, 0.55)]
    s.emit(kit.loft_geo(ribs), grain=(1, 0, 0))


def strut(s, a, b, w=0.05, d=0.10):
    """A streamlined strut from a to b: a flat bar, long axis fore and aft."""
    a, b = Vector(a), Vector(b)
    axis = (b - a)
    length = axis.length
    rot = Vector((0, 1, 0)).rotation_difference(axis.normalized()).to_matrix().to_4x4()
    s.box((0, 0, 0), (w, length, d), grain=(0, 1, 0), m=Matrix.Translation((a + b) / 2) @ rot)


def fuselage():
    s = kit.Stock()
    s.emit(kit.loft_geo([section(0.80, 0.90, 0.00, -2.62), section(0.88, 1.06, 0.02, -1.20),
                         section(0.82, 1.00, 0.04, 0.50), section(0.50, 0.66, 0.10, 2.20),
                         section(0.10, 0.30, 0.16, 3.62)]), grain=(0, 0, 1))
    return s.finish("Mailwing__Fuselage_ON_linen", smooth=False)


def wings():
    s = kit.Stock()
    plane(s, 10.06, 1.45, 0.17, 1.02, -1.05)   # upper plane
    plane(s, 9.10, 1.22, 0.15, -0.44, -0.55)   # lower plane, staggered aft
    plane(s, 3.20, 0.98, 0.07, 0.18, 3.15, tip=0.3)  # tailplane and elevators
    # Fin and rudder: a thin slab with the rounded Pitcairn outline.
    outline = [(2.62, 0.42), (3.10, 0.95), (3.50, 1.42), (3.86, 1.46), (4.06, 1.10), (4.02, 0.20), (3.70, 0.06)]
    left = [(-0.03, y, z) for z, y in outline]
    right = [(0.03, y, z) for z, y in outline]
    s.emit(kit.loft_geo([left, right]), grain=(0, 0, 1))
    return s.finish("Mailwing__Wings_ON_linen", smooth=False)


def metal():
    s = kit.Stock()
    # Crankcase and nose plate.
    s.emit(kit.spindle_geo([(0, -3.06), (0.16, -3.06), (0.30, -2.92), (0.30, -2.62), (0, -2.62)], 9), grain=(0, 0, 1))
    for i in range(9):  # nine finned cylinders round the case
        a = kit.TAU * i / 9
        m = Matrix.Rotation(a, 4, "Z") @ Matrix.Translation((0, 0.47, -2.78))
        s.box((0, 0, 0), (0.15, 0.36, 0.17), grain=(0, 1, 0), m=m)
    for sx in (-1, 1):
        # Interplane struts, front and rear, with their incidence brace.
        strut(s, (sx * 3.25, -0.36, -0.95), (sx * 3.30, 1.06, -1.42))
        strut(s, (sx * 3.25, -0.36, -0.22), (sx * 3.30, 1.06, -0.62))
        strut(s, (sx * 3.25, -0.36, -0.22), (sx * 3.30, 1.06, -1.42), w=0.025, d=0.04)
        # Cabane struts from the upper longerons to the centre section.
        strut(s, (sx * 0.40, 0.50, -1.50), (sx * 0.52, 1.05, -1.48), w=0.04, d=0.08)
        strut(s, (sx * 0.40, 0.50, -0.55), (sx * 0.52, 1.05, -0.62), w=0.04, d=0.08)
        # Undercarriage: a vee to each wheel and the half axle.
        strut(s, (sx * 0.38, -0.44, -1.95), (sx * 0.98, -1.46, -1.78), w=0.05, d=0.10)
        strut(s, (sx * 0.38, -0.44, -1.05), (sx * 0.98, -1.46, -1.78), w=0.05, d=0.10)
        strut(s, (0.0, -1.02, -1.70), (sx * 0.98, -1.46, -1.78), w=0.04, d=0.06)
        wheel = kit.spindle_geo([(0, -0.07), (0.20, -0.07), (0.36, -0.045), (0.36, 0.045), (0.20, 0.07), (0, 0.07)], 10)
        s.emit(wheel, grain=(0, 1, 0), m=Matrix.Translation((sx * 1.04, -1.46, -1.78)) @ Matrix.Rotation(math.pi / 2, 4, "Y"))
    strut(s, (0.0, 0.02, 3.20), (0.0, -0.46, 3.60), w=0.04, d=0.05)   # tail skid
    s.emit(kit.spindle_geo([(0, SHAFT_Z - 0.10), (0.07, SHAFT_Z - 0.04), (0.08, -3.04), (0, -3.04)], 8), grain=(0, 0, 1))  # hub
    return s.finish("Mailwing__Metal_ON_iron_blackened", smooth=False)


def propeller_disc():
    """The turning propeller as the eye has it: a thin disc, 2.6 m across."""
    s = kit.Stock()
    s.emit(kit.spindle_geo([(0, -0.012), (0.10, -0.012), (1.30, -0.004), (1.30, 0.004), (0.10, 0.012), (0, 0.012)], 20),
           grain=(1, 0, 0), m=Matrix.Translation((0, 0, SHAFT_Z)))
    return s.finish("Mailwing__PropellerDisc_ON_wood_dark", pivot=(0, 0, SHAFT_Z), smooth=False)


kit.reset()
objs = [fuselage(), wings(), metal(), propeller_disc()]
kit.preview_material(objs[0], "linen_dark", (0.07, 0.05, 0.04))
kit.preview_material(objs[1], "linen_yellow", (0.72, 0.55, 0.14))
kit.preview_material(objs[2], "iron_blackened", (0.05, 0.05, 0.055))
kit.preview_material(objs[3], "wood_dark", (0.25, 0.16, 0.09), alpha=0.35)
for o in objs:
    print("[AIRMAIL BIPLANE] %s: %d triangles" % (o.name, kit.tri_count(o)))
(ROOT / "game/assets/props").mkdir(parents=True, exist_ok=True)
kit.review(OUT / "review" / "biplane_three_quarter.png", objs, (-9.0, 11.0, 4.5), (0, 0, 0.1), lens=50)
kit.review(OUT / "review" / "biplane_side.png", objs, (-16.0, -0.5, 0.2), (0, -0.5, 0.0), lens=60)
kit.review(OUT / "review" / "biplane_below.png", objs, (2.0, 3.0, -14.0), (0, -0.4, 0.0), lens=50)
kit.export(objs, ROOT / "game/assets/props/airmail_biplane.glb", ROOT / "art/blender/airmail_biplane.blend")
print("[AIRMAIL BIPLANE] %d triangles in all" % sum(kit.tri_count(o) for o in objs))
