"""City greenery: street trees, yard trees, shrubs and weeds, and where they stand.

    python art/blender/scripts/build_city_greenery.py --place       # placement only (plain Python)
    blender -b --python-exit-code 1 -P art/blender/scripts/build_city_greenery.py

Stock (Blender) is written to game/assets/props/city_greenery.glb. Placement is written
to game/data/orison_v2/exterior/city_greenery.json from two surveys of the running world:
- the greenery survey (tests/V2CityGreenerySurvey.tscn, copied to
  art/blender/data/city_greenery_survey/): the drawn pavement, kerb and road triangles,
  and a 1 m grid of first collision hits;
- the mid-ground layout (build_city_midground.py, rebuilt here in plain Python from its
  own survey), whose kerbs, lots and yards this batch plants beside without editing.

Additive: no installed owner, route, door, station or collision is moved. Every plant
keeps a clear radius from every collision the survey found that is not open ground, so
posts, stoops, doors, walls, lamps, hydrants and station stairs are left as they were.

Leaves are modelled, not cut out: each is a small folded blade of the catalogued `plant`
finish with metric UVs; stems use `wood_dark`, tree pits `soil` and the guards
`iron_blackened`, all existing catalogue keys (RUL-008, RUL-012). Vertex colour darkens
the inside of each crown so it reads as a volume; the runtime multiplies the season in.
"""
import json
import math
import os
import random
import sys

ROOT = __file__.replace("\\", "/").split("/art/blender/")[0]
OUT = os.environ.get("ORISON_GREENERY_OUT", ROOT + "/game/assets/props/city_greenery.glb")
DATA = os.environ.get("ORISON_GREENERY_DATA", ROOT + "/game/data/orison_v2/exterior/city_greenery.json")
SURVEY = os.environ.get("ORISON_GREENERY_SURVEY", ROOT + "/art/blender/data/city_greenery_survey/")
SEED = 19290601

# Stock names: (kind, near mesh, distant mesh). Leaves stay leaves at every range;
# the distant mesh has a quarter as many, each twice the size.
STOCK = {
    "plane_a": ("plane_a", "plane_a_lod1"),
    "plane_b": ("plane_b", "plane_b_lod1"),
    "ailanthus": ("ailanthus", "ailanthus_lod1"),
    "shrub": ("shrub", "shrub"),
    "weeds": ("weeds", "weeds"),
    "pit": ("pit", "pit"),
}
TREE_CLEARANCE_M = 1.1     # trunk centre to the nearest non-ground collision
SHRUB_CLEARANCE_M = 0.8
STEM_CLEAR_M = 3.4         # canopy starts above people, carts and the kerbside lane


# --- Geometry (plain lists, so the plan can be checked without Blender) ----------------

class Part:
    """One mesh: vertices, corner UVs, corner colours and faces, one material per face."""

    def __init__(self):
        self.verts = []
        self.faces = []   # (indices, uvs, colour, material)

    def add(self, points, uvs, colour, material):
        base = len(self.verts)
        self.verts.extend(points)
        return base

    def face(self, idx, uvs, colour, material):
        self.faces.append((idx, uvs, colour, material))


def _sub(a, b): return (a[0] - b[0], a[1] - b[1], a[2] - b[2])
def _add(a, b): return (a[0] + b[0], a[1] + b[1], a[2] + b[2])
def _mul(a, s): return (a[0] * s, a[1] * s, a[2] * s)
def _len(a): return math.sqrt(a[0] * a[0] + a[1] * a[1] + a[2] * a[2])
def _norm(a):
    n = _len(a) or 1.0
    return (a[0] / n, a[1] / n, a[2] / n)
def _cross(a, b): return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def _frame(d):
    d = _norm(d)
    up = (0, 0, 1) if abs(d[2]) < 0.95 else (1, 0, 0)
    s = _norm(_cross(d, up))
    t = _cross(s, d)
    return s, t


def limb(part, a, b, r0, r1, seg, colour=(0.62, 0.60, 0.58), material="wood_dark"):
    """A tapered stem from a to b, UV metric (U around, V along)."""
    d = _sub(b, a)
    length = _len(d)
    s, t = _frame(d)
    rings = []
    for k, (p, r) in enumerate(((a, r0), (b, r1))):
        ring = []
        for i in range(seg + 1):
            ang = math.tau * i / seg
            off = _add(_mul(s, math.cos(ang) * r), _mul(t, math.sin(ang) * r))
            ring.append(len(part.verts))
            part.verts.append(_add(p, off))
        rings.append(ring)
    for i in range(seg):
        u0 = math.tau * i / seg * r0
        u1 = math.tau * (i + 1) / seg * r0
        part.face([rings[0][i], rings[0][i + 1], rings[1][i + 1], rings[1][i]],
                  [(u0, 0), (u1, 0), (u1 * r1 / max(r0, 1e-4), length), (u0 * r1 / max(r0, 1e-4), length)],
                  colour, material)


def leaf(part, rng, centre, normal, size, colour, material="plant", narrow=0.55):
    """A folded leaf blade: base, two shoulders, tip and a raised midrib, four faces."""
    n = _norm(normal)
    s, t = _frame(n)
    spin = rng.uniform(0, math.tau)
    ax = _add(_mul(s, math.cos(spin)), _mul(t, math.sin(spin)))
    side = _cross(n, ax)
    L, W = size, size * narrow
    p = [_add(centre, _mul(ax, -L * .5)),
         _add(centre, _add(_mul(side, -W * .5), _mul(ax, -L * .05))),
         _add(centre, _mul(ax, L * .5)),
         _add(centre, _add(_mul(side, W * .5), _mul(ax, -L * .05))),
         _add(centre, _mul(n, size * .08))]
    base = len(part.verts)
    part.verts.extend(p)
    ou, ov = rng.uniform(0, 2), rng.uniform(0, 2)
    uv = [(ou, ov - L * .5), (ou - W * .5, ov), (ou, ov + L * .5), (ou + W * .5, ov), (ou, ov)]
    for a, b in ((0, 1), (1, 2), (2, 3), (3, 0)):
        part.face([base + a, base + b, base + 4], [uv[a], uv[b], uv[4]], colour, material)


def crown(part, rng, centre, radius, count, size, light_dir_centre, crown_radius, narrow=0.55):
    """Leaves filling a clump, denser toward its surface, lit from outside and above."""
    for _ in range(count):
        while True:
            v = (rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-1, 1))
            if _len(v) <= 1:
                break
        depth = _len(v) ** 0.45
        pos = _add(centre, _mul(_norm(v), radius * depth))
        out = _norm(_sub(pos, light_dir_centre))
        reach = _len(_sub(pos, light_dir_centre)) / max(crown_radius, 0.1)
        shade = 0.62 + 0.36 * min(reach, 1.0) + 0.16 * max(out[2], 0.0)
        shade *= rng.uniform(0.88, 1.08)
        normal = _norm(_add(out, (rng.uniform(-.6, .6), rng.uniform(-.6, .6), rng.uniform(-.2, .8))))
        leaf(part, rng, pos, normal, size * rng.uniform(.8, 1.2), (shade, shade, shade), narrow=narrow)


def plane_tree(seed, lod):
    """A London plane (or a planted maple): clear stem, five scaffold limbs, a round crown."""
    rng = random.Random(seed)
    part = Part()
    seg = 10 if lod == 0 else 6
    lean = (rng.uniform(-.12, .12), rng.uniform(-.12, .12))
    top = (lean[0], lean[1], STEM_CLEAR_M + rng.uniform(0, .5))
    limb(part, (0, 0, -0.05), top, 0.17, 0.14, seg)
    height = rng.uniform(8.5, 10.5)
    crown_c = (top[0], top[1], top[2] + (height - top[2]) * .5)
    crown_r = rng.uniform(3.0, 3.8)
    limbs = 5 if lod == 0 else 4
    tips = []
    for k in range(limbs):
        ang = math.tau * k / limbs + rng.uniform(-.4, .4)
        tilt = rng.uniform(.45, .8)
        length = rng.uniform(3.0, 4.2)
        d = (math.cos(ang) * math.sin(tilt), math.sin(ang) * math.sin(tilt), math.cos(tilt))
        start = (top[0], top[1], top[2] - rng.uniform(0, .5))
        end = _add(start, _mul(d, length))
        limb(part, start, end, 0.10, 0.05, max(5, seg - 4))
        for _ in range(3 if lod == 0 else 1):
            f = rng.uniform(.4, .85)
            fork = _add(start, _mul(d, length * f))
            a2 = ang + rng.uniform(-.9, .9)
            d2 = (math.cos(a2) * .7, math.sin(a2) * .7, rng.uniform(.4, .9))
            twig = _add(fork, _mul(_norm(d2), rng.uniform(1.4, 2.2)))
            limb(part, fork, twig, 0.05, 0.025, 5 if lod == 0 else 4)
            tips.append(twig)
            if lod == 0:
                # Winter shows the fine twigs; summer hides them in the crown.
                for _ in range(3):
                    g = rng.uniform(.3, .9)
                    at = _add(fork, _mul(_sub(twig, fork), g))
                    spray = _add(at, (rng.uniform(-.9, .9), rng.uniform(-.9, .9), rng.uniform(.2, .9)))
                    limb(part, at, spray, 0.018, 0.007, 4)
        tips.append(end)
    tips.append((top[0], top[1], height - 1.2))
    per = 125 if lod == 0 else 34
    size = 0.42 if lod == 0 else 0.8
    for tip in tips:
        crown(part, rng, tip, rng.uniform(1.15, 1.45), per, size, crown_c, crown_r)
    return part


def ailanthus(seed, lod):
    """Tree of heaven, the back-yard tree: leaning stems, a sparse crown of drooping leaflets."""
    rng = random.Random(seed)
    part = Part()
    seg = 8 if lod == 0 else 5
    centre = (0, 0, 5.0)
    for k in range(3):
        ang = math.tau * k / 3 + rng.uniform(-.5, .5)
        lean = rng.uniform(.18, .35)
        base = (math.cos(ang) * .15, math.sin(ang) * .15, -0.05)
        top = (math.cos(ang) * lean * 5, math.sin(ang) * lean * 5, rng.uniform(4.5, 6.0))
        limb(part, base, top, 0.11, 0.05, seg)
        for _ in range(4 if lod == 0 else 2):
            f = rng.uniform(.5, .95)
            at = _add(base, _mul(_sub(top, base), f))
            a2 = rng.uniform(0, math.tau)
            stalk_end = _add(at, (math.cos(a2) * 1.6, math.sin(a2) * 1.6, rng.uniform(-.2, .6)))
            limb(part, at, stalk_end, 0.035, 0.015, 4)
            # Pinnate stalks drooping from the twig ends.
            for j in range(8 if lod == 0 else 3):
                b2 = rng.uniform(0, math.tau)
                droop = _add(stalk_end, (math.cos(b2) * 1.1, math.sin(b2) * 1.1, rng.uniform(-.7, .1)))
                n = 12 if lod == 0 else 5
                for i in range(n):
                    t = (i + .5) / n
                    p = _add(stalk_end, _mul(_sub(droop, stalk_end), t))
                    for sgn in (-1, 1):
                        off = _mul(_norm(_cross(_sub(droop, stalk_end), (0, 0, 1))), sgn * .1)
                        reach = _len(_sub(p, centre)) / 3.5
                        shade = (0.5 + 0.4 * min(reach, 1)) * rng.uniform(.9, 1.08)
                        leaf(part, rng, _add(p, off), (rng.uniform(-.4, .4), rng.uniform(-.4, .4), 1),
                             (0.3 if lod == 0 else 0.6) * rng.uniform(.85, 1.15), (shade, shade, shade), narrow=0.38)
    return part


def shrub(seed):
    """A privet clump, as kept in front-yard strips and left to grow in vacant lots."""
    rng = random.Random(seed)
    part = Part()
    for k in range(5):
        a = rng.uniform(0, math.tau)
        limb(part, (0, 0, -0.02), (math.cos(a) * .3, math.sin(a) * .3, .7), 0.025, 0.012, 4)
    centre = (0, 0, .55)
    for k in range(5):
        a = math.tau * k / 5
        c = (math.cos(a) * .32, math.sin(a) * .32, .55 + rng.uniform(-.1, .25))
        crown(part, rng, c, .45, 120, .13, (0, 0, .2), .9)
    crown(part, rng, (0, 0, .9), .45, 100, .13, (0, 0, .2), .9)
    return part


def weeds(seed):
    """A tuft of grass and dock: bent blades of plant finish from a common root."""
    rng = random.Random(seed)
    part = Part()
    for _ in range(36):
        a = rng.uniform(0, math.tau)
        h = rng.uniform(.25, .65)
        lean = rng.uniform(.1, .45)
        w = rng.uniform(.012, .025)
        side = (-math.sin(a), math.cos(a), 0)
        root = (math.cos(a) * rng.uniform(0, .12), math.sin(a) * rng.uniform(0, .12), -0.01)
        prev = None
        for i in range(4):
            t = i / 3
            centre = _add(root, (math.cos(a) * lean * h * t * t, math.sin(a) * lean * h * t * t, h * t))
            half = w * (1 - t) + .002
            l, r = _add(centre, _mul(side, -half)), _add(centre, _mul(side, half))
            base = len(part.verts)
            part.verts.extend([l, r])
            shade = (.45 + .5 * t) * rng.uniform(.85, 1.1)
            if prev is not None:
                part.face([prev, prev + 1, base + 1, base], [(0, (i - 1) / 3 * h), (w, (i - 1) / 3 * h), (w, t * h), (0, t * h)],
                          (shade, shade, shade), "plant")
            prev = base
    for _ in range(4):
        a = rng.uniform(0, math.tau)
        p = (math.cos(a) * .12, math.sin(a) * .12, .06)
        leaf(part, rng, p, (math.cos(a) * .6, math.sin(a) * .6, 1), .22, (.6, .6, .6), narrow=.45)
    return part


def pit():
    """A tree pit: a square of soil set in the flags, with a low iron guard."""
    part = Part()
    h = .6
    q = [(-h, -h, .012), (h, -h, .012), (h, h, .012), (-h, h, .012)]
    base = len(part.verts)
    part.verts.extend(q)
    part.face([base, base + 1, base + 2, base + 3], [(-h, -h), (h, -h), (h, h), (-h, h)], (1, 1, 1), "soil")
    g = .52
    corners = [(-g, -g), (g, -g), (g, g), (-g, g)]
    for x, y in corners:
        limb(part, (x, y, 0), (x, y, .55), .016, .014, 6, (1, 1, 1), "iron_blackened")
    for k in range(4):
        (x0, y0), (x1, y1) = corners[k], corners[(k + 1) % 4]
        for z in (.18, .5):
            limb(part, (x0, y0, z), (x1, y1, z), .009, .009, 5, (1, 1, 1), "iron_blackened")
    return part


def build_stock():
    return {
        "plane_a": plane_tree(SEED + 1, 0), "plane_a_lod1": plane_tree(SEED + 1, 1),
        "plane_b": plane_tree(SEED + 2, 0), "plane_b_lod1": plane_tree(SEED + 2, 1),
        "ailanthus": ailanthus(SEED + 3, 0), "ailanthus_lod1": ailanthus(SEED + 3, 1),
        "shrub": shrub(SEED + 4), "weeds": weeds(SEED + 5), "pit": pit(),
    }


# --- Blender export ---------------------------------------------------------------------

def export(stock):
    import bpy
    bpy.ops.wm.read_factory_settings(use_empty=True)
    materials = {}
    for name in ("plant", "wood_dark", "soil", "iron_blackened"):
        materials[name] = bpy.data.materials.new(name)
    for name, part in stock.items():
        mesh = bpy.data.meshes.new(name)
        # Blender is Z-up; the glTF exporter turns it to Godot's Y-up.
        mesh.from_pydata(part.verts, [], [f[0] for f in part.faces])
        mesh.update()
        order = sorted({f[3] for f in part.faces})
        for mat in order:
            mesh.materials.append(materials[mat])
        uv = mesh.uv_layers.new(name="UVMap")
        col = mesh.color_attributes.new(name="Col", type="BYTE_COLOR", domain="CORNER")
        for poly, (idx, uvs, colour, mat) in zip(mesh.polygons, part.faces):
            poly.material_index = order.index(mat)
            poly.use_smooth = mat != "plant"
            for k, loop in enumerate(poly.loop_indices):
                uv.data[loop].uv = uvs[k]
                col.data[loop].color = (colour[0], colour[1], colour[2], 1.0)
        obj = bpy.data.objects.new(name, mesh)
        bpy.context.scene.collection.objects.link(obj)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    staged = OUT + ".tmp.glb"
    bpy.ops.export_scene.gltf(filepath=staged, export_format="GLB", export_yup=True, export_tangents=True,
                              export_attributes=True, export_materials="EXPORT", export_vertex_color="ACTIVE")
    os.replace(staged, OUT)
    counts = {name: len(part.faces) for name, part in stock.items()}
    print("CITY GREENERY STOCK", json.dumps(counts))


if __name__ == "__main__":
    if "--place" in sys.argv:
        sys.path.insert(0, os.path.dirname(__file__))
        import plan_city_greenery
        plan_city_greenery.main()
    else:
        export(build_stock())
