"""The commensals' bodies, authored in Blender (v1r_commensals_20261109).

V1's CommensalDirector drew its moths as three vertex-coloured triangles and
its roaches as a SurfaceTool fan. V2 keeps V1's census, schedule and rules and
replaces only the bodies:

  Moth   a spindle body with feelers, and a fore-and-hind wing pair for each
         side as its own mesh, origin on the wing root, so the runtime can
         beat them. V1's size: 86 mm across the spread wings.
  Roach  a domed body with six splayed legs and two long feelers, at V1's
         size (58 mm long before the director's 0.55 scale).

Runtime frame: +Y up, the animal's head toward -Z (moth) or +Z (roach, as V1
drew it), metres. Each animal is a few dozen triangles: they are drawn many
at a time by MultiMesh.

Deterministic: no randomness.

  blender -b --python-exit-code 1 -P art/blender/scripts/build_commensals.py -- <review_dir>
Writes game/assets/props/commensals.glb, art/blender/commensals.blend and
review renders under <review_dir>.
"""
import bpy, math, sys
from mathutils import Vector, Matrix
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import v1r_small_stock as kit

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(sys.argv[sys.argv.index("--") + 1]) if "--" in sys.argv else ROOT / "tmp/commensals"
OUT.mkdir(parents=True, exist_ok=True)
ROOT_X = 0.004  # V1's wing root, off the body's centre line


def moth_body():
    s = kit.Stock()
    # Head, thorax, abdomen along Z (head at -Z); five sides is enough at 20 mm.
    s.emit(kit.spindle_geo([(0, -0.0115), (0.0030, -0.0085), (0.0046, -0.0020), (0.0030, 0.0075), (0, 0.0205)], 5),
           grain=(0, 0, 1))
    for sx in (-1, 1):  # feelers: a thin blade each, swept forward and out
        s.poly([(sx * 0.0012, 0.0022, -0.0100), (sx * 0.0090, 0.0060, -0.0205), (sx * 0.0100, 0.0052, -0.0190)],
               grain=(0, 0, 1))
    return s.finish("Moth__Body_ON_velour", smooth=True)


def moth_wings(side):
    """Fore and hind wing of one side, flat in the wing plane, root at the origin."""
    sx = -1.0 if side == "Left" else 1.0
    fore = [(0, -0.0045), (0.0200, -0.0172), (0.0390, -0.0190), (0.0372, -0.0040), (0.0245, 0.0042), (0, 0.0030)]
    hind = [(0, 0.0020), (0.0225, 0.0034), (0.0300, 0.0118), (0.0205, 0.0178), (0.0045, 0.0125)]
    s = kit.Stock()
    for pts, y in ((fore, 0.0006), (hind, 0.0)):
        ring = [(sx * (ROOT_X + x), y, z) for x, z in pts]
        if sx > 0:
            ring.reverse()  # keep the top face up on both sides
        s.poly(ring, grain=(1, 0, 0))
    return s.finish("Moth__Wings%s_ON_paper" % side, pivot=(sx * ROOT_X, 0.0, 0.0), outward=False)


def roach():
    s = kit.Stock()
    low, high = [], []
    for i in range(8):
        a = kit.TAU * i / 8
        low.append((math.sin(a) * 0.0140, 0.0022, math.cos(a) * 0.0290))
        high.append((math.sin(a) * 0.0105, 0.0078, math.cos(a) * 0.0225 - 0.0015))
    for i in range(8):
        j = (i + 1) % 8
        s.poly([low[i], low[j], high[j], high[i]], grain=(0, 0, 1))
        s.poly([high[i], high[j], (0.0, 0.0120, -0.0015)], grain=(0, 0, 1))
    # Six splayed legs, each a thin blade from under the shell to the floor.
    for z in (-0.018, 0.0, 0.018):
        for sx in (-1, 1):
            leg = [(sx * 0.010, 0.0060, z + 0.0016), (sx * 0.010, 0.0060, z - 0.0016),
                   (sx * 0.037, 0.0006, z - 0.0090), (sx * 0.035, 0.0006, z - 0.0056)]
            s.poly(leg if sx > 0 else list(reversed(leg)), grain=(1, 0, 0))
    for sx in (-1, 1):  # the long feelers
        feeler = [(sx * 0.0052, 0.0075, 0.0255), (sx * 0.0068, 0.0075, 0.0262),
                  (sx * 0.0262, 0.0040, 0.0700), (sx * 0.0236, 0.0040, 0.0692)]
        s.poly(feeler if sx < 0 else list(reversed(feeler)), grain=(0, 0, 1))
    return s.finish("Roach__Body_ON_bakelite", smooth=False)


kit.reset()
objs = [moth_body(), moth_wings("Left"), moth_wings("Right"), roach()]
kit.preview_material(objs[0], "velour", (0.10, 0.06, 0.03))
kit.preview_material(objs[1], "paper", (0.34, 0.22, 0.08))
kit.preview_material(objs[2], "paper", (0.34, 0.22, 0.08))
kit.preview_material(objs[3], "bakelite", (0.18, 0.06, 0.014))
for o in objs:
    print("[COMMENSALS] %s: %d triangles" % (o.name, kit.tri_count(o)))

# Review: the moth with its wings raised a little, the roach beside it.
rest = [o.matrix_world.copy() for o in objs]
objs[1].rotation_euler = (0, math.radians(25), 0)
objs[2].rotation_euler = (0, math.radians(-25), 0)
objs[3].location.x += 0.12
(OUT / "review").mkdir(exist_ok=True)
(ROOT / "game/assets/props").mkdir(parents=True, exist_ok=True)
kit.review(OUT / "review" / "commensals_three_quarter.png", objs, (0.16, -0.20, 0.16), (0.06, 0, 0.0), lens=70, floor_z=-0.012)
kit.review(OUT / "review" / "commensals_top.png", objs, (0.06, 0.0, 0.30), (0.06, 0.0005, 0.0), lens=70, floor_z=-0.012)
for o, m in zip(objs, rest):
    o.matrix_world = m
bpy.context.view_layer.update()
kit.export(objs, ROOT / "game/assets/props/commensals.glb", ROOT / "art/blender/commensals.blend")
print("[COMMENSALS] %d triangles in all" % sum(kit.tri_count(o) for o in objs))
