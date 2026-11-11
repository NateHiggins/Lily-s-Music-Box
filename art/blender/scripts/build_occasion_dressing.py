"""The house dressed for the year's occasions, authored in Blender (2026-11-10).

Small tenant-made and janitor-hung things for a Queens apartment house in
1928-29, built once and shown by date:

  Flag        a forty-eight-star flag on a short staff in an iron wall bracket
  Bunting     a pleated three-colour fan about 1.6 m wide
  Wreath      an evergreen wreath with a ribbon bow, about 0.47 m
  Tree        a table tree in a pot with a paper chain and glass balls
  Poppies     paper remembrance poppies in a jar
  PoppyPin    one poppy pinned up
  Pumpkin     a carved jack-o'-lantern with a candle stub inside
  Cutouts     cut-paper pumpkins, hearts, shamrocks, eggs and turkeys on strings
  Lilies      a pot of Easter lilies
  Carnations  a small vase of carnations
  Crepe       two twisted crepe-paper streamers hung in a swag

Wall pieces are authored in the prop's own Godot frame (x along the wall, y up,
z out of the wall, metres; wall face at z = 0); standing pieces have their
origin at the middle of the base. UVs are in metres; the runtime multiplies by
the catalogue tile. No lettering and no picture is modelled or textured: the
flag's stripes, canton and stars are separate coloured cloth (RUL-008).
Deterministic: one seed.

  blender -b --python-exit-code 1 -P art/blender/scripts/build_occasion_dressing.py -- <review_dir>
Writes game/assets/props/occasion_dressing.glb, art/blender/occasion_dressing.blend,
the `props` table of game/data/orison_v2/occasion_dressing.json (placements and
occasions in that file are kept) and review renders under <review_dir>.
"""
import bpy, bmesh, json, math, random, sys
import numpy as np
from mathutils import Vector, Matrix
from pathlib import Path

SEED = 1929
ROOT = next(p for p in Path(__file__).resolve().parents if (p / "game/project.godot").is_file())
OUT = Path(sys.argv[sys.argv.index("--") + 1]) if "--" in sys.argv else ROOT / "tmp/occasion_dressing_review"
OUT.mkdir(parents=True, exist_ok=True)
CATALOG = json.loads((ROOT / "game/data/runtime_material_sets.json").read_text(encoding="utf-8"))["materials"]
TEXTURES = ROOT / "game/assets/building/textures"
DATA = ROOT / "game/data/orison_v2/occasion_dressing.json"
RNG = random.Random(SEED)
TAU = math.tau

PARTS = []
PROPS = []  # {"id", "assembly", "shadow", "range", "tints": {part name: tint}, "candle"}

RED, WHITE, BLUE = [0.74, 0.13, 0.12], [0.96, 0.94, 0.88], [0.16, 0.20, 0.44]
GREEN = [0.30, 0.50, 0.26]


def conv(p):
    """Prop frame (x, y up, z out of wall) to Blender (x, -z, y)."""
    return Vector((p[0], -p[2], p[1]))


class MB:
    """Faces with explicit per-corner UVs in metres."""

    def __init__(self):
        self.v, self.f, self.uv = [], [], []
        self.m = Matrix.Identity(4)

    def face(self, pts, uvs):
        base = len(self.v)
        self.v += [tuple(self.m @ Vector(p)) for p in pts]
        self.f.append(tuple(range(base, base + len(pts))))
        self.uv.append([tuple(u) for u in uvs])

    def poly(self, pts, udir=None, back=False):
        """A planar polygon (counter-clockwise seen from outside) with an
        isometric metre chart; back adds the same sheet seen from behind."""
        p = [Vector(q) for q in pts]
        n = Vector((0, 0, 0))
        for i in range(len(p)):
            n += p[i].cross(p[(i + 1) % len(p)])
        n.normalize()
        u = Vector(udir) if udir is not None else (p[1] - p[0])
        u = (u - n * u.dot(n)).normalized()
        w = n.cross(u)
        uvs = [((q - p[0]).dot(u), (q - p[0]).dot(w)) for q in p]
        self.face(p, uvs)
        if back:
            self.face(p[::-1], uvs[::-1])

    def tri_out(self, a, b, c, inside):
        """A triangle wound to face away from the point `inside`."""
        a, b, c = Vector(a), Vector(b), Vector(c)
        if (b - a).cross(c - a).dot((a + b + c) / 3 - Vector(inside)) < 0:
            b, c = c, b
        self.poly([a, b, c])

    def box(self, lo, hi):
        for a in range(3):
            b, c = (a + 1) % 3, (a + 2) % 3
            for side, val in ((1, hi[a]), (-1, lo[a])):
                quad = [(lo[b], lo[c]), (hi[b], lo[c]), (hi[b], hi[c]), (lo[b], hi[c])]
                if side < 0:
                    quad.reverse()
                pts, uvs = [], []
                for qb, qc in quad:
                    p = [0.0, 0.0, 0.0]
                    p[a], p[b], p[c] = val, qb, qc
                    pts.append(p)
                    uvs.append((qb, qc))
                self.face(pts, uvs)

    def prism(self, pts2d, lo, hi):
        """Extrude a counter-clockwise polygon in xy along z."""
        n = len(pts2d)
        self.poly([(a, b, hi) for a, b in pts2d])
        self.poly([(a, b, lo) for a, b in reversed(pts2d)])
        for i in range(n):
            (a0, b0), (a1, b1) = pts2d[i], pts2d[(i + 1) % n]
            self.poly([(a0, b0, lo), (a1, b1, lo), (a1, b1, hi), (a0, b0, hi)])

    def lathe(self, profile, origin=(0, 0, 0), axis="y", seg=16):
        """Revolve (radius, height) pairs about an axis through origin. Walk the
        profile from the base outward, up the side and then in across the top."""
        basis = {"z": (Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))),
                 "y": (Vector((0, 0, 1)), Vector((1, 0, 0)), Vector((0, 1, 0))),
                 "x": (Vector((0, 1, 0)), Vector((0, 0, 1)), Vector((1, 0, 0)))}[axis]
        o = Vector(origin)
        def pt(r, hgt, t):
            return o + basis[0] * (r * math.cos(t)) + basis[1] * (r * math.sin(t)) + basis[2] * hgt
        run = 0.0
        for i in range(len(profile) - 1):
            (r0, h0), (r1, h1) = profile[i], profile[i + 1]
            step = math.hypot(r1 - r0, h1 - h0)
            for j in range(seg):
                t0, t1 = j / seg * TAU, (j + 1) / seg * TAU
                mid, half, mean = (t0 + t1) / 2, (t1 - t0) / 2, max((r0 + r1) / 2, 0.002)
                corners = [(r0, h0, t0, -1, run), (r0, h0, t1, 1, run), (r1, h1, t1, 1, run + step), (r1, h1, t0, -1, run + step)]
                if r0 < 1e-7:
                    corners = [corners[0], corners[2], corners[3]]
                elif r1 < 1e-7:
                    corners = [corners[0], corners[1], corners[2]]
                self.face([pt(r, hgt, t) for r, hgt, t, _, _ in corners],
                          [(mid * mean + sgn * half * max(r, 0.0), v) for r, _, _, sgn, v in corners])
            run += step

    def grid(self, fn, nu, nv, ulen, vlen, thick=0.0, back=True, u_range=(0.0, 1.0), v_range=(0.0, 1.0)):
        """A surface fn(u, v) -> point; the chart is ulen x vlen metres over the
        whole unit square. back adds the reverse side, set off by thick."""
        def at(i, j):
            return (u_range[0] + (u_range[1] - u_range[0]) * i / nu, v_range[0] + (v_range[1] - v_range[0]) * j / nv)
        def normal(u, v, e=1e-3):
            a = Vector(fn(u + e, v)) - Vector(fn(u - e, v))
            b = Vector(fn(u, v + e)) - Vector(fn(u, v - e))
            n = a.cross(b)
            return n.normalized() if n.length > 1e-14 else Vector((0, 0, 1))
        for i in range(nu):
            for j in range(nv):
                q = [at(i, j), at(i + 1, j), at(i + 1, j + 1), at(i, j + 1)]
                uv = [(u * ulen, v * vlen) for u, v in q]
                self.face([Vector(fn(u, v)) for u, v in q], uv)
                if back:
                    self.face([Vector(fn(u, v)) - normal(u, v) * thick for u, v in reversed(q)], uv[::-1])

    def tube(self, path, r, seg=6, caps=True):
        """A round section swept along a polyline; r is one radius or one per point."""
        pts = [Vector(p) for p in path]
        rad = list(r) if isinstance(r, (list, tuple)) else [r] * len(pts)
        t = (pts[1] - pts[0]).normalized()
        ref = Vector((0, 1, 0)) if abs(t.y) < 0.9 else Vector((1, 0, 0))
        n = (ref - t * ref.dot(t)).normalized()
        rings, run = [], [0.0]
        for i, p in enumerate(pts):
            if 0 < i < len(pts) - 1:
                t = (pts[i + 1] - pts[i - 1]).normalized()
            elif i:
                t = (pts[i] - pts[i - 1]).normalized()
            n = (n - t * n.dot(t)).normalized()
            b = t.cross(n)
            rings.append([p + (n * math.cos(k / seg * TAU) + b * math.sin(k / seg * TAU)) * rad[i] for k in range(seg)])
            if i:
                run.append(run[-1] + (p - pts[i - 1]).length)
        girth = TAU * max(sum(rad) / len(rad), 0.001)
        for i in range(len(pts) - 1):
            for k in range(seg):
                k1 = (k + 1) % seg
                self.face([rings[i][k], rings[i][k1], rings[i + 1][k1], rings[i + 1][k]],
                          [(k / seg * girth, run[i]), ((k + 1) / seg * girth, run[i]), ((k + 1) / seg * girth, run[i + 1]), (k / seg * girth, run[i + 1])])
        if caps:
            if rad[0] > 1e-5:
                self.poly(rings[0][::-1])
            if rad[-1] > 1e-5:
                self.poly(rings[-1])

    def blade(self, base, tip, width, facing, mid=0.4):
        """A flat lance leaf or needle spray, both faces."""
        base, tip = Vector(base), Vector(tip)
        d = tip - base
        w = d.cross(Vector(facing))
        if w.length < 1e-7:
            w = d.orthogonal()
        w = w.normalized() * (width / 2)
        m = base + d * mid
        self.poly([base, m + w, tip, m - w], back=True)

    def bead(self, c, r):
        c = Vector(c)
        ax = [Vector((r, 0, 0)), Vector((0, r, 0)), Vector((0, 0, r))]
        for sx in (1, -1):
            for sy in (1, -1):
                for sz in (1, -1):
                    tri = [c + ax[0] * sx, c + ax[1] * sy, c + ax[2] * sz]
                    if sx * sy * sz < 0:
                        tri.reverse()
                    self.poly(tri)

    def ball(self, c, r, seg=8, rings=6):
        prof = [(r * math.sin(math.pi * i / rings), -r * math.cos(math.pi * i / rings)) for i in range(rings + 1)]
        prof[0], prof[-1] = (0.0, -r), (0.0, r)
        self.lathe(prof, c, "y", seg)


def part(name, assembly, key, mb, tint=None, smooth=False, cutters=None):
    """smooth: weld and shade round, keeping every edge over 38 degrees sharp."""
    PARTS.append({"name": "%s__%s_ON_%s" % (assembly, name, key), "assembly": assembly, "key": key,
                  "tint": tint if tint is not None else [1.0, 1.0, 1.0], "mb": mb, "smooth": smooth, "cutters": cutters or []})


def prop(pid, assembly, shadow=True, reach=12.0, only=None, tints=None, candle=None):
    PROPS.append({"id": pid, "assembly": assembly, "shadow": shadow, "range": reach, "only": only, "tints": tints or {}, "candle": candle})


def aim(origin, direction):
    """A frame whose local z runs along `direction` from `origin`."""
    return Matrix.Translation(Vector(origin)) @ Vector(direction).to_track_quat("Z", "Y").to_matrix().to_4x4()


def screw(mb, at, r=0.0045, proud=0.0018):
    mb.lathe([(r, 0.0), (r * 0.82, proud * 0.7), (r * 0.4, proud), (0.0, proud)], at, "z", 8)


# --------------------------------------------------------------------------
# The flag
# --------------------------------------------------------------------------
STAFF_RISE = math.radians(50)
STAFF_DIR = Vector((0.0, math.sin(STAFF_RISE), math.cos(STAFF_RISE)))
STAFF_FOOT = Vector((0.0, 0.0, 0.032))
HOIST, FLY = 0.60, 0.95
HOIST_TOP = 1.20


def flag_point(h, f):
    """h runs down the hoist from the head of the staff, f out along the fly.
    The cloth hangs from the staff in still air, leaning a little along the wall."""
    s = HOIST_TOP - h * HOIST
    p = STAFF_FOOT + STAFF_DIR * s
    drop = f * FLY
    fold = 0.034 * f * math.sin(TAU * (1.7 * h + 0.85 * f)) + 0.012 * f * f * math.sin(TAU * (3.1 * h + 0.2))
    return Vector((p.x + drop * 0.24 + fold, p.y - drop * 0.965 + 0.02 * f * math.sin(TAU * 0.5 * h),
                   p.z + 0.03 * f * math.sin(TAU * (0.9 * h + 0.15)) - 0.05 * f * f))


def build_flag():
    iron = MB()
    iron.box((-0.035, -0.075, 0.0), (0.035, 0.075, 0.008))
    iron.box((-0.020, -0.045, 0.008), (0.020, 0.012, 0.030))
    for sy in (-1, 1):
        screw(iron, (0.0, sy * 0.060, 0.008))
    iron.m = aim(STAFF_FOOT, STAFF_DIR)
    iron.lathe([(0.0, -0.030), (0.018, -0.030), (0.018, 0.150), (0.0115, 0.150)], (0, 0, 0), "z", 10)
    part("Bracket", "Flag", "cast_iron", iron, tint=[0.30, 0.30, 0.29], smooth=True)

    staff = MB()
    staff.m = aim(STAFF_FOOT, STAFF_DIR)
    staff.lathe([(0.011, 0.0), (0.011, 1.215), (0.008, 1.222), (0.016, 1.236), (0.021, 1.256), (0.016, 1.276), (0.0, 1.288)], (0, 0, 0), "z", 8)
    part("Staff", "Flag", "oak_quartered", staff, tint=[0.62, 0.48, 0.34], smooth=True)

    thick = 0.0008
    red, white, blue = MB(), MB(), MB()
    canton_h, canton_f = 7 / 13, 0.4
    for k in range(13):
        f0 = canton_f if k < 7 else 0.0
        (red if k % 2 == 0 else white).grid(flag_point, 2, int(round((1 - f0) * 20)), HOIST, FLY, thick,
                                             u_range=(k / 13, (k + 1) / 13), v_range=(f0, 1.0))
    blue.grid(flag_point, 14, 8, HOIST, FLY, thick, u_range=(0.0, canton_h), v_range=(0.0, canton_f))
    # Forty-eight stars, six rows of eight, standing a hair proud of both faces.
    for row in range(6):
        for col in range(8):
            h, f = canton_h * (row + 0.5) / 6, canton_f * (col + 0.5) / 8
            c = flag_point(h, f)
            along = (flag_point(h - 0.01, f) - flag_point(h + 0.01, f)).normalized()   # up the hoist
            across = (flag_point(h, f + 0.01) - flag_point(h, f - 0.01))
            n = (flag_point(h + 0.01, f) - flag_point(h - 0.01, f)).cross(across).normalized()
            across = n.cross(along).normalized()
            ring = []
            for i in range(10):
                r = 0.0165 if i % 2 == 0 else 0.0066
                a = TAU * i / 10
                ring.append((math.sin(a) * r, math.cos(a) * r))
            for side, lift in ((1, 0.0012), (-1, -(thick + 0.0012))):
                pts = [c + n * lift + across * x * side + along * y for x, y in ring]
                white.poly(pts[::-1])
    part("Stripes", "Flag", "linen", red, tint=RED, smooth=True)
    part("Field", "Flag", "linen", white, tint=WHITE, smooth=True)
    part("Canton", "Flag", "linen", blue, tint=BLUE, smooth=True)
    prop("flag", "Flag", reach=40.0)


# --------------------------------------------------------------------------
# Pleated bunting
# --------------------------------------------------------------------------
BUNT_W, BUNT_DROP, PLEATS = 1.60, 0.56, 22


def build_bunting():
    bands = [("Inner", 0.10, 0.40, BLUE), ("Middle", 0.40, 0.70, WHITE), ("Outer", 0.70, 1.00, RED)]
    def at(i, r):
        t = math.pi * i / (2 * PLEATS)
        ridge = i % 2 == 0
        return Vector((-BUNT_W / 2 * math.cos(t) * r, -0.030 - BUNT_DROP * math.sin(t) * r, 0.006 + (0.030 if ridge else 0.0) * (0.25 + 0.75 * r)))
    for name, r0, r1, tint in bands:
        mb = MB()
        for i in range(2 * PLEATS):
            quad = [at(i, r0), at(i, r1), at(i + 1, r1), at(i + 1, r0)]
            t0, t1 = math.pi * i / (2 * PLEATS), math.pi * (i + 1) / (2 * PLEATS)
            uv = [(t0 * 0.4, r0 * 0.6), (t0 * 0.4, r1 * 0.6), (t1 * 0.4, r1 * 0.6), (t1 * 0.4, r0 * 0.6)]
            mb.face(quad, uv)
            mb.face(quad[::-1], uv[::-1])
        if name == "Inner":
            hub = Vector((0.0, -0.030, 0.012))
            for i in range(2 * PLEATS):   # the gathered centre
                mb.poly([hub, at(i, r0), at(i + 1, r0)], back=True)
        if name == "Middle":
            mb.box((-BUNT_W / 2, -0.034, 0.0), (BUNT_W / 2, 0.0, 0.007))   # the heading tape, tacked to the wall
            for x in (-0.78, -0.39, 0.0, 0.39, 0.78):
                screw(mb, (x, -0.017, 0.007), 0.004, 0.0015)
        part(name, "Bunting", "linen", mb, tint=tint)
    prop("bunting", "Bunting", reach=30.0)
    prop("bunting_autumn", "Bunting", reach=30.0, tints={"Inner": [0.42, 0.24, 0.12], "Middle": [0.90, 0.78, 0.48], "Outer": [0.80, 0.40, 0.10]})


# --------------------------------------------------------------------------
# The wreath
# --------------------------------------------------------------------------
def build_wreath():
    ring_r, tube_r, zc = 0.185, 0.036, 0.044
    green = MB()
    def torus(u, v):
        a, b = TAU * u, TAU * v
        r = ring_r + tube_r * math.cos(b) * (1.0 + 0.10 * math.sin(7 * a))
        return (r * math.cos(a), r * math.sin(a), zc + tube_r * math.sin(b) * (1.0 + 0.08 * math.cos(5 * a)))
    green.grid(lambda u, v: torus(v, u), 8, 26, TAU * tube_r, TAU * ring_r, back=False)
    for i in range(620):
        a = TAU * RNG.random()
        b = math.radians(RNG.uniform(-80, 260))   # all round the bough but not into the wall
        if 200 < math.degrees(b) < 340:
            continue
        radial = Vector((math.cos(a), math.sin(a), 0.0))
        tangent = Vector((-math.sin(a), math.cos(a), 0.0))
        out = radial * math.cos(b) + Vector((0, 0, 1)) * math.sin(b)
        base = radial * ring_r + Vector((0, 0, zc)) + out * tube_r * 0.8
        lean = RNG.choice((-1, 1)) * RNG.uniform(0.5, 1.1)
        tip = base + (out + tangent * lean).normalized() * RNG.uniform(0.050, 0.090)
        if tip.z < 0.004:
            tip.z = 0.004
        green.blade(base, tip, RNG.uniform(0.016, 0.026), out.cross(tangent) + out * 0.4)
    part("Boughs", "Wreath", "plant", green, tint=[0.34, 0.50, 0.30])

    bow = MB()
    top = Vector((0.0, ring_r + 0.006, zc + tube_r + 0.008))
    thick = 0.0007
    for side in (-1, 1):
        def loop(u, v, side=side):
            p = TAU * u
            reach = 0.052 * (1 - math.cos(p))
            width = 0.020 + 0.034 * (1 - math.cos(p)) / 2
            return (top.x + side * reach, top.y + reach * 0.22 + (v - 0.5) * width, top.z + 0.024 * math.sin(p) + 0.004)
        bow.grid(loop if side > 0 else (lambda u, v: loop(1 - u, v)), 12, 1, 0.24, 0.05, thick)
        def tail(u, v, side=side):
            run = 0.17 * u
            return (top.x + side * (0.012 + run * 0.42) + (v - 0.5) * 0.040, top.y - run * 0.92 - (v - 0.5) * 0.040 * 0.42 * side - 0.012 * u * (v if side > 0 else 1 - v),
                    top.z + 0.004 - 0.030 * u + 0.008 * math.sin(TAU * 0.8 * u))
        bow.grid(tail if side > 0 else (lambda u, v: tail(u, 1 - v)), 6, 1, 0.17, 0.04, thick)
    bow.box((top.x - 0.013, top.y - 0.014, top.z - 0.004), (top.x + 0.013, top.y + 0.014, top.z + 0.016))
    # The loop of ribbon it hangs by, up to its nail.
    bow.grid(lambda u, v: (top.x + (v - 0.5) * 0.022, top.y + 0.10 * u, top.z * (1 - u) ** 2 + 0.002), 5, 1, 0.10, 0.022, thick)
    screw(bow, (top.x, top.y + 0.092, 0.0025), 0.005, 0.003)
    part("Bow", "Wreath", "linen", bow, tint=RED, smooth=True)
    prop("wreath", "Wreath", reach=30.0)


# --------------------------------------------------------------------------
# Pots, jars and what stands in them
# --------------------------------------------------------------------------
def pot(mb, s=1.0):
    mb.lathe([(0.0, 0.0), (0.075 * s, 0.0), (0.094 * s, 0.128 * s), (0.103 * s, 0.128 * s), (0.103 * s, 0.156 * s), (0.089 * s, 0.156 * s),
              (0.087 * s, 0.134 * s)], (0, 0, 0), "y", 16)
    return 0.136 * s, 0.087 * s   # soil height and radius


def build_tree():
    clay = MB()
    soil_y, soil_r = pot(clay)
    part("Pot", "Tree", "terracotta", clay, smooth=True)
    earth = MB()
    earth.lathe([(soil_r, soil_y), (0.0, soil_y)], (0, 0, 0), "y", 16)
    earth.lathe([(0.013, soil_y), (0.010, 0.30)], (0, 0, 0), "y", 6)
    part("Soil", "Tree", "soil", earth, tint=[0.55, 0.42, 0.32])

    green = MB()
    tiers = [(0.205, 0.39, 0.190), (0.300, 0.47, 0.160), (0.390, 0.55, 0.130), (0.475, 0.63, 0.100), (0.555, 0.705, 0.068)]
    boughs = 8
    tips = []
    for k, (y0, y1, radius) in enumerate(tiers):
        turn = k * 0.41
        ring = []
        for j in range(2 * boughs):
            a = turn + TAU * j / (2 * boughs)
            r = radius if j % 2 == 0 else radius * 0.60
            y = y0 - 0.016 if j % 2 == 0 else y0 + 0.022
            ring.append(Vector((r * math.cos(a), y, r * math.sin(a))))
            if j % 2 == 0:
                tips.append(ring[-1])
        apex, under, core = Vector((0, y1, 0)), Vector((0, y0 + 0.055, 0)), Vector((0, (y0 + y1) / 2, 0))
        for j in range(2 * boughs):
            a, b = ring[j], ring[(j + 1) % len(ring)]
            green.tri_out(apex, a, b, core)
            green.tri_out(under, a, b, core)
    def envelope(y):
        return max(0.012, 0.215 * (0.72 - y) / 0.52)
    for i in range(170):
        y = RNG.uniform(0.22, 0.66)
        a = TAU * RNG.random()
        out = Vector((math.cos(a), 0.0, math.sin(a)))
        base = out * envelope(y) * 0.55 + Vector((0, y, 0))
        tip = out * envelope(y) * RNG.uniform(0.95, 1.12) + Vector((0, y - RNG.uniform(0.02, 0.06), 0))
        green.blade(base, tip, RNG.uniform(0.016, 0.028), Vector((0, 1, 0)) + out * 0.3)
    part("Boughs", "Tree", "plant", green, tint=[0.30, 0.46, 0.28])

    # The paper chain: flat links, each through the last, wound down the tree.
    chain = MB()
    turns, y_hi, y_lo = 2.6, 0.63, 0.25
    path, steps = [], 900
    for i in range(steps + 1):
        u = i / steps
        y = y_hi + (y_lo - y_hi) * u
        a = TAU * turns * u
        sag = 0.012 * math.sin(TAU * boughs * turns * u) ** 2
        r = envelope(y) + 0.014
        path.append(Vector((r * math.cos(a), y - sag, r * math.sin(a))))
    pitch, link_r, link_w = 0.027, 0.0165, 0.010
    walked, index, k = 0.0, 0, 0
    for i in range(1, len(path)):
        walked += (path[i] - path[i - 1]).length
        if walked < pitch:
            continue
        walked = 0.0
        t = (path[i] - path[i - 1]).normalized()
        out = Vector((path[i].x, 0, path[i].z)).normalized()
        side = t.cross(out).normalized()
        e1, e2 = (t, out) if k % 2 == 0 else (t, side)
        width = e1.cross(e2).normalized() * (link_w / 2)
        seg = 6
        for j in range(seg):
            a0, a1 = TAU * j / seg, TAU * (j + 1) / seg
            p0 = path[i] + (e1 * math.cos(a0) + e2 * math.sin(a0)) * link_r
            p1 = path[i] + (e1 * math.cos(a1) + e2 * math.sin(a1)) * link_r
            chain.poly([p0 - width, p1 - width, p1 + width, p0 + width], back=True)
        k += 1
    part("Chain", "Tree", "paper", chain, tint=[0.86, 0.26, 0.20])

    balls = MB()
    for i in (1, 4, 6, 9, 11, 14, 17, 20, 23, 26, 30, 33):
        tip = tips[i]
        c = tip + Vector((0, -0.036, 0))
        balls.ball(c, 0.021)
        balls.lathe([(0.005, 0.018), (0.005, 0.028), (0.0, 0.028)], c, "y", 6)
        balls.tube([c + Vector((0, 0.028, 0)), tip + Vector((0, 0.002, 0))], 0.0012, 4, caps=False)
    part("Balls", "Tree", "mirror_aged", balls, tint=[0.95, 0.42, 0.30], smooth=True)
    prop("tree", "Tree", reach=30.0)


def jar(mb, height=0.112, radius=0.036):
    neck = radius * 0.83
    mb.lathe([(0.0, 0.0), (radius * 0.9, 0.0), (radius, 0.010), (radius, height * 0.76), (neck, height * 0.85), (neck, height * 0.96),
              (neck * 1.10, height), (neck * 0.90, height), (neck * 0.88, height * 0.80)], (0, 0, 0), "y", 12)


def flower_stems(mb, count, foot_y, head_y, spread, radius=0.0022):
    """Stems rising out of a jar's mouth; returns each head position and direction."""
    heads = []
    for i in range(count):
        a = TAU * (i + RNG.uniform(-0.25, 0.25)) / count
        out = Vector((math.cos(a), 0.0, math.sin(a)))
        lean = spread * RNG.uniform(0.45, 1.0) if i else spread * 0.12
        top_y = head_y * RNG.uniform(0.84, 1.0)
        p0 = out * 0.006 + Vector((0, foot_y, 0))
        p3 = out * lean + Vector((0, top_y, 0))
        p1 = p0.lerp(p3, 0.4) - out * lean * 0.22
        p2 = p0.lerp(p3, 0.8) - out * lean * 0.06
        mb.tube([p0, p1, p2, p3], radius, 4, caps=False)
        heads.append((p3, (p3 - p2).normalized() + out * 0.5 + Vector((0, 0.15, 0))))
    return heads


def petals(mb, centre, facing, radius, lobes, cup, ruffle=0.0, layers=1, seg=12):
    for layer in range(layers):
        scale = 1.0 - 0.22 * layer
        mb.m = aim(centre, facing) @ Matrix.Rotation(0.6 * layer, 4, "Z")
        def disc(u, v, scale=scale, layer=layer):
            r = radius * scale * (0.14 + 0.86 * v) * (1.0 + 0.10 * math.cos(TAU * lobes * u))
            lift = cup * radius * v * v + 0.004 * layer + ruffle * v * math.sin(TAU * (lobes * 2.5) * u + layer)
            return (r * math.cos(TAU * u), r * math.sin(TAU * u), lift)
        mb.grid(disc, seg, 2, TAU * radius, radius, 0.0)
    mb.m = Matrix.Identity(4)


def build_poppies():
    glass = MB()
    jar(glass)
    part("Jar", "Poppies", "milk_glass", glass, tint=[0.86, 0.90, 0.88], smooth=True)
    stems, heads = MB(), MB()
    for at, facing in flower_stems(stems, 6, 0.06, 0.27, 0.085):
        petals(heads, at, facing, 0.036, 4, 0.22, 0.0035)
        stems.bead(at + facing.normalized() * 0.004, 0.0075)
    part("Stems", "Poppies", "plant", stems, tint=[0.22, 0.30, 0.16])
    part("Petals", "Poppies", "paper", heads, tint=[0.86, 0.14, 0.10])
    prop("poppies", "Poppies", reach=16.0)

    # One poppy pinned flat: a wall piece, its wire stem under the pin.
    one, mid = MB(), MB()
    petals(one, (0.0, 0.0, 0.006), (0.0, 0.05, 1.0), 0.040, 4, 0.16, 0.003)
    mid.bead((0.0, 0.0, 0.012), 0.008)
    mid.tube([(0.0, 0.0, 0.006), (0.004, -0.03, 0.003), (0.002, -0.07, 0.002)], 0.0016, 4)
    mid.blade((0.003, -0.035, 0.003), (0.034, -0.062, 0.006), 0.016, (0, 0, 1))
    part("Petals", "PoppyPin", "paper", one, tint=[0.86, 0.14, 0.10])
    part("Stem", "PoppyPin", "plant", mid, tint=[0.22, 0.30, 0.16])
    prop("poppy_pin", "PoppyPin", shadow=False, reach=10.0)


def build_carnations():
    glass = MB()
    jar(glass, 0.150, 0.030)
    part("Vase", "Carnations", "milk_glass", glass, smooth=True)
    stems, heads = MB(), MB()
    for at, facing in flower_stems(stems, 5, 0.08, 0.33, 0.075):
        petals(heads, at + facing.normalized() * 0.012, facing, 0.027, 7, 0.55, 0.006, layers=3, seg=14)
        stems.m = aim(at, facing)
        stems.lathe([(0.004, -0.004), (0.0075, 0.006), (0.006, 0.016)], (0, 0, 0), "z", 6)
        stems.m = Matrix.Identity(4)
        stems.blade(at * 0.55, at * 0.55 + Vector((facing.x, 0.3, facing.z)).normalized() * 0.07, 0.008, (0, 0, 1) if abs(facing.z) < 0.7 else (1, 0, 0))
    part("Stems", "Carnations", "plant", stems, tint=[0.36, 0.52, 0.36])
    part("Heads", "Carnations", "paper", heads, tint=[0.94, 0.60, 0.66])
    prop("carnations", "Carnations", reach=16.0)


def build_lilies():
    clay = MB()
    soil_y, soil_r = pot(clay, 0.85)
    part("Pot", "Lilies", "terracotta", clay, smooth=True)
    earth = MB()
    earth.lathe([(soil_r, soil_y), (0.0, soil_y)], (0, 0, 0), "y", 16)
    part("Soil", "Lilies", "soil", earth, tint=[0.55, 0.42, 0.32])
    green, white = MB(), MB()
    for i in range(3):
        a = TAU * i / 3 + 0.4
        out = Vector((math.cos(a), 0.0, math.sin(a)))
        foot = out * 0.022 + Vector((0, soil_y, 0))
        height = (0.50, 0.44, 0.39)[i]
        top = foot + out * 0.045 + Vector((0, height - soil_y, 0))
        stalk = [foot, foot.lerp(top, 0.35) - out * 0.006, foot.lerp(top, 0.7) - out * 0.004, top]
        green.tube(stalk, [0.0055, 0.0050, 0.0042, 0.0035], 5, caps=False)
        for j in range(9):
            u = 0.10 + 0.085 * j
            base = foot.lerp(top, u)
            b = a + 2.4 * j
            way = Vector((math.cos(b), 0.0, math.sin(b)))
            tip = base + way * RNG.uniform(0.075, 0.105) + Vector((0, RNG.uniform(0.015, 0.05), 0))
            green.blade(base, tip, 0.022, Vector((0, 1, 0)) + way * 0.2, mid=0.35)
        for j in range(2 if i < 2 else 1):
            b = a + (0.9 if j else -0.7)
            way = (Vector((math.cos(b), 0.0, math.sin(b))) + Vector((0, 0.18 - 0.30 * j, 0))).normalized()
            base = top - Vector((0, 0.012 * j, 0))
            green.tube([base, base + way * 0.02], 0.003, 4, caps=False)
            white.m = aim(base + way * 0.018, way)
            def trumpet(u, v):
                r = 0.006 + 0.005 * v + 0.036 * v ** 3
                flare = max(0.0, v - 0.75) / 0.25
                r += 0.014 * flare * math.cos(TAU * 6 * u)
                return (r * math.cos(TAU * u), r * math.sin(TAU * u), 0.115 * v - 0.020 * flare * flare * (1 - math.cos(TAU * 6 * u)) / 2)
            white.grid(trumpet, 18, 4, 0.14, 0.12, 0.0007)
            white.m = Matrix.Identity(4)
    part("Greens", "Lilies", "plant", green, tint=[0.34, 0.52, 0.30])
    part("Blooms", "Lilies", "paper", white, tint=[1.0, 0.99, 0.95], smooth=True)
    prop("lilies", "Lilies", reach=20.0)


# --------------------------------------------------------------------------
# The jack-o'-lantern
# --------------------------------------------------------------------------
PUMPKIN_R, PUMPKIN_HALF = 0.150, 0.118
CANDLE_FLAME = [0.0, 0.085, 0.0]


def build_pumpkin():
    shell = MB()
    seg, rings = 40, 10
    def skin(u, v, scale):
        a = TAU * u
        phi = math.pi * (0.03 + 0.94 * v)
        rib = 1.0 - 0.075 * (1.0 - abs(math.sin(5 * a))) ** 2
        r = PUMPKIN_R * scale * rib * math.sin(phi)
        y = PUMPKIN_HALF + 0.004 - PUMPKIN_HALF * scale * math.cos(phi) * (1.0 - 0.10 * math.cos(phi) ** 6)
        return Vector((r * math.cos(a), y, r * math.sin(a)))
    for scale, outward in ((1.0, True), (0.86, False)):
        middle = Vector((0, PUMPKIN_HALF, 0))
        for i in range(seg):
            for j in range(rings):
                q = [(i / seg, j / rings), ((i + 1) / seg, j / rings), ((i + 1) / seg, (j + 1) / rings), (i / seg, (j + 1) / rings)]
                pts = [skin(u, v, scale) for u, v in q]
                uv = [(u * 0.9, v * 0.42) for u, v in q]
                if (pts[1] - pts[0]).cross(pts[3] - pts[0]).dot(pts[0] - middle) < 0:
                    pts.reverse()
                    uv.reverse()
                if not outward:
                    pts.reverse()
                    uv.reverse()
                shell.face(pts, uv)
            for v, y_sign in ((0.0, -1), (1.0, 1)):   # close the crown and the base
                a, b = skin(i / seg, v, scale), skin((i + 1) / seg, v, scale)
                pole = Vector((0, a.y, 0))
                tri = [pole, a, b]
                if (a - pole).cross(b - pole).y * y_sign < 0:
                    tri.reverse()
                if not outward:
                    tri.reverse()
                shell.poly(tri)
    # The face is cut right through the front wall.
    cuts = []
    def cut(pts):
        area = sum(pts[i][0] * pts[(i + 1) % len(pts)][1] - pts[(i + 1) % len(pts)][0] * pts[i][1] for i in range(len(pts)))
        mb = MB()
        mb.prism(pts if area > 0 else pts[::-1], 0.045, 0.26)
        cuts.append(mb)
    for sx in (-1, 1):
        cut([(sx * 0.030, 0.150), (sx * 0.082, 0.158), (sx * 0.052, 0.196)])
    cut([(-0.014, 0.112), (0.014, 0.112), (0.0, 0.140)])
    mouth = [(-0.085, 0.098), (-0.060, 0.082), (-0.046, 0.094), (-0.030, 0.074), (-0.014, 0.088), (0.0, 0.070), (0.014, 0.088), (0.030, 0.074),
             (0.046, 0.094), (0.060, 0.082), (0.085, 0.098), (0.064, 0.058), (0.044, 0.046), (0.030, 0.060), (0.012, 0.040), (0.0, 0.054),
             (-0.012, 0.040), (-0.030, 0.060), (-0.044, 0.046), (-0.064, 0.058)]
    cut(mouth)
    part("Shell", "Pumpkin", "terracotta", shell, tint=[1.0, 0.78, 0.24], smooth=True, cutters=cuts)

    stalk = MB()
    crown = PUMPKIN_HALF * 2 - 0.010
    stalk.tube([(0, crown - 0.004, 0), (0.004, crown + 0.022, 0.002), (0.014, crown + 0.040, 0.004), (0.030, crown + 0.050, 0.006)],
               [0.020, 0.014, 0.012, 0.013], 7)
    part("Stalk", "Pumpkin", "plant", stalk, tint=[0.52, 0.50, 0.30])
    wax = MB()
    floor_y = PUMPKIN_HALF + 0.004 - PUMPKIN_HALF * 0.86 * 0.9
    wax.lathe([(0.0, floor_y - 0.004), (0.016, floor_y - 0.004), (0.016, floor_y + 0.040), (0.013, floor_y + 0.046), (0.0, floor_y + 0.043)], (0, 0, 0), "y", 8)
    wax.tube([(0, floor_y + 0.043, 0), (0.001, floor_y + 0.052, 0)], 0.0012, 4)
    part("Candle", "Pumpkin", "milk_glass", wax, tint=[0.96, 0.90, 0.72], smooth=True)
    prop("pumpkin", "Pumpkin", reach=30.0, candle=CANDLE_FLAME)


# --------------------------------------------------------------------------
# Cut paper on strings
# --------------------------------------------------------------------------
def wind_ccw(pts):
    area = sum(pts[i][0] * pts[(i + 1) % len(pts)][1] - pts[(i + 1) % len(pts)][0] * pts[i][1] for i in range(len(pts)))
    return pts if area > 0 else pts[::-1]


def heart(scale=0.0032, n=28):
    pts = []
    for i in range(n):
        t = TAU * i / n
        pts.append((16 * math.sin(t) ** 3 * scale, (13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t)) * scale))
    return pts


def turned(pts, angle, shift=(0.0, 0.0)):
    c, s = math.cos(angle), math.sin(angle)
    return [(x * c - y * s + shift[0], x * s + y * c + shift[1]) for x, y in pts]


def shape_heart():
    return [heart()]


def shape_egg():
    return [[(0.040 * math.sin(TAU * i / 24) * (1 - 0.20 * math.cos(TAU * i / 24)), 0.056 * math.cos(TAU * i / 24)) for i in range(24)]]


def shape_pumpkin():
    body = []
    for i in range(32):
        t = TAU * i / 32
        r = 1.0 + 0.06 * abs(math.cos(2.5 * t)) - 0.05
        body.append((0.062 * r * math.sin(t), 0.046 * r * math.cos(t)))
    stem = [(-0.008, 0.040), (0.008, 0.040), (0.011, 0.062), (0.022, 0.066), (0.020, 0.074), (-0.004, 0.070)]
    return [body, stem]


def shape_shamrock():
    leaf = [(x, y + 17 * 0.0019) for x, y in heart(0.0019, 22)]   # the heart's point at the origin
    polys = [turned(leaf, a) for a in (0.0, TAU / 3, -TAU / 3)]
    polys.append([(-0.004, 0.004), (0.004, 0.004), (0.010, -0.058), (0.002, -0.060)])
    return polys


def shape_turkey():
    fan = [(-0.012, -0.004)]
    for i in range(29):
        t = math.radians(15 + 190 * i / 28)
        r = 0.058 + 0.007 * abs(math.sin(7 * math.radians(190 * i / 28)))
        fan.append((-0.012 + r * math.cos(t), -0.004 + r * math.sin(t)))
    body = [(0.012 + 0.042 * math.cos(TAU * i / 20), -0.016 + 0.031 * math.sin(TAU * i / 20)) for i in range(20)]
    neck = [(0.034, -0.012), (0.052, -0.004), (0.062, 0.030), (0.048, 0.034)]
    head = [(0.056 + 0.013 * math.cos(TAU * i / 12), 0.038 + 0.013 * math.sin(TAU * i / 12)) for i in range(12)]
    beak = [(0.066, 0.044), (0.066, 0.034), (0.084, 0.036)]
    wattle = [(0.064, 0.032), (0.070, 0.014), (0.060, 0.018)]
    legs = [[(0.002, -0.040), (0.008, -0.040), (0.006, -0.066), (-0.006, -0.066), (-0.006, -0.062), (0.001, -0.062)],
            [(0.022, -0.042), (0.028, -0.042), (0.027, -0.066), (0.015, -0.066), (0.015, -0.062), (0.022, -0.062)]]
    return [fan, body, neck, head, beak, wattle] + legs


def build_cutouts():
    kinds = [("Pumpkins", shape_pumpkin, [0.92, 0.48, 0.12]), ("Hearts", shape_heart, [0.84, 0.12, 0.16]), ("Shamrocks", shape_shamrock, [0.20, 0.52, 0.22]),
             ("Eggs", shape_egg, [0.66, 0.80, 0.90]), ("Turkeys", shape_turkey, [0.50, 0.30, 0.16])]
    span, sag, count = 0.90, 0.045, 5
    def line(u):
        x = -span / 2 + span * u
        edge = min(u, 1 - u)
        return Vector((x, -sag * (1 - (2 * u - 1) ** 2), 0.002 + 0.013 * min(1.0, edge / 0.08)))
    for name, maker, tint in kinds:
        mb = MB()
        mb.tube([line(i / 16) for i in range(17)], 0.0013, 4)
        for end in (0.0, 1.0):   # a tack at each end
            p = line(end)
            screw(mb, (p.x, p.y, 0.0), 0.0045, 0.0030)
        for i in range(count):
            u = (i + 0.5) / count
            hang = line(u)
            polys = maker()
            top = max(y for poly in polys for _, y in poly)
            top_x = [x for poly in polys for x, y in poly if y == top][0]
            roll, yaw = RNG.uniform(-0.10, 0.10), RNG.uniform(-0.10, 0.10)
            for layer, poly in enumerate(polys):
                pts = []
                for x, y in wind_ccw(turned([(px - top_x, py - top) for px, py in poly], roll)):
                    pts.append((hang.x + x * math.cos(yaw), hang.y + y + 0.002, hang.z - 0.0020 + x * math.sin(yaw) + 0.0008 * layer))
                mb.poly(pts, udir=(1, 0, 0), back=True)
        part(name, "Cutouts", "paper", mb, tint=tint)
        prop("cutout_" + name.lower(), "Cutouts", shadow=False, reach=14.0, only=name)


# --------------------------------------------------------------------------
# Crepe streamers
# --------------------------------------------------------------------------
def build_crepe():
    half = 0.90
    for name, sag, twists, phase, tint in (("First", 0.27, 5.5, 0.0, RED), ("Second", 0.33, 6.5, 0.9, [0.24, 0.52, 0.26])):
        def strip(u, v, sag=sag, twists=twists, phase=phase):
            x = -half + 2 * half * u
            y = -sag * (1 - (x / half) ** 2)
            slope = 2 * sag * x / half ** 2
            t = Vector((1.0, slope, 0.0)).normalized()
            up = Vector((-t.y, t.x, 0.0))
            a = TAU * twists * u + phase
            width = 0.046 * (0.35 + 0.65 * min(1.0, min(u, 1 - u) / 0.04))
            z = 0.004 + 0.024 * min(1.0, min(u, 1 - u) / 0.06)
            across = up * math.cos(a) + Vector((0, 0, 1)) * math.sin(a) * 0.9
            return Vector((x, y, z)) + across * (v - 0.5) * width
        mb = MB()
        mb.grid(strip, 80, 1, 2.0, 0.046, 0.0)
        for sx in (-1, 1):
            screw(mb, (sx * half, 0.0, 0.0), 0.0045, 0.0030)
        part(name, "Crepe", "paper", mb, tint=tint)
    prop("crepe", "Crepe", shadow=False, reach=24.0)


# --------------------------------------------------------------------------
# Scene, review and export
# --------------------------------------------------------------------------
def material(key, tint):
    name = "%s_%02x%02x%02x" % (key, *[int(255 * c) for c in tint])
    if name in bpy.data.materials:
        return bpy.data.materials[name]
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    node = mat.node_tree.nodes["Principled BSDF"]
    spec = CATALOG[key]
    node.inputs["Metallic"].default_value = spec["metallic"]
    coord = mat.node_tree.nodes.new("ShaderNodeTexCoord")
    scale = mat.node_tree.nodes.new("ShaderNodeVectorMath")
    scale.operation = "SCALE"
    scale.inputs["Scale"].default_value = 1 / spec["meters_per_tile"]
    mat.node_tree.links.new(coord.outputs["UV"], scale.inputs[0])
    for index, target in ((0, "Base Color"), (1, "Roughness"), (2, "Normal")):
        image = bpy.data.images.load(str(TEXTURES / spec["files"][index]), check_existing=True)
        if index:
            image.colorspace_settings.name = "Non-Color"
        tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
        tex.image = image
        mat.node_tree.links.new(scale.outputs["Vector"], tex.inputs["Vector"])
        if index == 2:
            normal = mat.node_tree.nodes.new("ShaderNodeNormalMap")
            normal.inputs["Strength"].default_value = 0.35
            mat.node_tree.links.new(tex.outputs["Color"], normal.inputs["Color"])
            mat.node_tree.links.new(normal.outputs[0], node.inputs[target])
        elif index == 0:
            mix = mat.node_tree.nodes.new("ShaderNodeMixRGB")
            mix.blend_type = "MULTIPLY"
            mix.inputs[0].default_value = 1.0
            mix.inputs[2].default_value = (*[c ** 2.2 for c in tint], 1)
            mat.node_tree.links.new(tex.outputs["Color"], mix.inputs[1])
            mat.node_tree.links.new(mix.outputs[0], node.inputs[target])
        else:
            mat.node_tree.links.new(tex.outputs["Color"], node.inputs[target])
    return mat


# Where each assembly stands for review: wall pieces on the wall, the rest on the floor.
REVIEW_AT = {"Flag": (-4.5, 1.9, 0.0), "Bunting": (-2.6, 2.2, 0.0), "Wreath": (-1.2, 1.6, 0.0), "Crepe": (0.6, 2.3, 0.0),
             "Cutouts": (2.6, 1.6, 0.0), "PoppyPin": (3.6, 1.5, 0.0),
             "Tree": (-2.4, 0.0, 1.2), "Lilies": (-1.4, 0.0, 1.2), "Pumpkin": (-0.5, 0.0, 1.2), "Poppies": (0.3, 0.0, 1.2), "Carnations": (0.9, 0.0, 1.2)}


def mesh_from(name, mb, weld):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata([conv(v) for v in mb.v], [], mb.f)
    layer = mesh.uv_layers.new(name="UVMap")
    k = 0
    for uvs in mb.uv:
        for uv in uvs:
            layer.data[k].uv = uv
            k += 1
    mesh.validate()
    if weld:
        bm = bmesh.new()
        bm.from_mesh(mesh)
        bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-6)
        bm.to_mesh(mesh)
        bm.free()
    return mesh


def assemble():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.preferences.filepaths.save_version = 0
    roots, objs = {}, []
    for name, at in REVIEW_AT.items():
        empty = bpy.data.objects.new(name, None)
        empty.location = conv(at)
        bpy.context.collection.objects.link(empty)
        roots[name] = empty
    for row in PARTS:
        mesh = mesh_from(row["name"], row["mb"], row["smooth"])
        obj = bpy.data.objects.new(row["name"], mesh)
        bpy.context.collection.objects.link(obj)
        for index, cutter in enumerate(row["cutters"]):
            tool = bpy.data.objects.new("cutter", mesh_from("cutter", cutter, True))
            bpy.context.collection.objects.link(tool)
            mod = obj.modifiers.new("cut%d" % index, "BOOLEAN")
            mod.operation = "DIFFERENCE"
            mod.solver = "EXACT"
            mod.object = tool
            bpy.context.view_layer.objects.active = obj
            with bpy.context.temp_override(object=obj, active_object=obj, selected_objects=[obj]):
                bpy.ops.object.modifier_apply(modifier=mod.name)
            bpy.data.objects.remove(tool)
            mesh = obj.data
        # Triangles only: the exporter cannot compute tangents on an n-gon.
        bm = bmesh.new()
        bm.from_mesh(mesh)
        bmesh.ops.triangulate(bm, faces=bm.faces[:])
        if row["cutters"]:
            thin = [f for f in bm.faces if f.calc_area() < 1e-9]
            if thin:
                bmesh.ops.delete(bm, geom=thin, context="FACES")
        # Every chart is right-handed on its outward face (dP/du x dP/dv along
        # the normal), so one tangent sign serves the whole asset. A chart that
        # arrives mirrored (the back of a sheet) is turned over in v.
        layer = bm.loops.layers.uv.verify()
        for face in bm.faces:
            corners = [loop[layer].uv.copy() for loop in face.loops]
            e1, e2 = corners[1] - corners[0], corners[2] - corners[0]
            if e1.x * e2.y - e1.y * e2.x < 0:
                for loop, uv in zip(face.loops, corners):
                    loop[layer].uv = (uv.x, -uv.y)
        bm.to_mesh(mesh)
        bm.free()
        if row["smooth"]:
            for polygon in mesh.polygons:
                polygon.use_smooth = True
            mesh.set_sharp_from_angle(angle=math.radians(38))
        mesh.update()
        # The exact direction of increasing u on every triangle, already in
        # glTF's axes: the exporter hook turns it into the tangent.
        guides = mesh.attributes.new(name="_tangent_guide", type="FLOAT_VECTOR", domain="CORNER")
        charts = mesh.uv_layers["UVMap"].data
        for poly in mesh.polygons:
            loops = list(poly.loop_indices)
            p = [mesh.vertices[mesh.loops[i].vertex_index].co for i in loops]
            t = [Vector(charts[i].uv) for i in loops]
            e1, e2, d1, d2 = p[1] - p[0], p[2] - p[0], t[1] - t[0], t[2] - t[0]
            det = d1.x * d2.y - d2.x * d1.y
            if abs(det) < 1e-14:
                raise RuntimeError("%s: collapsed UV triangle" % row["name"])
            du = ((e1 * d2.y - e2 * d1.y) / det).normalized()
            for i in loops:
                guides.data[i].vector = (du.x, du.z, -du.y)
        obj.parent = roots[row["assembly"]]
        mesh.materials.clear()   # a boolean leaves an empty slot behind
        mesh.materials.append(material(row["key"], row["tint"]))
        row["object"] = obj
        row["triangles"] = len(mesh.polygons)
        objs.append(obj)
    return roots, objs


def review(roots):
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 32
    scene.render.threads_mode = "FIXED"     # leave cores for whoever holds the Godot lane
    scene.render.threads = 8
    scene.render.resolution_x, scene.render.resolution_y = 1100, 825
    temp = []
    world = bpy.data.worlds.new("review")
    scene.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.20, 0.19, 0.18, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.7
    def plane(name, loc, rot, size, color):
        bpy.ops.mesh.primitive_plane_add(size=1, location=loc, rotation=rot)
        o = bpy.context.object
        o.name = name
        o.scale = size
        m = bpy.data.materials.new(name)
        m.use_nodes = True
        m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (*color, 1)
        m.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.9
        o.data.materials.append(m)
        temp.append(o)
    plane("review_wall", (0, 0.0005, 1.5), (math.radians(90), 0, 0), (12, 3.4, 1), (0.50, 0.46, 0.38))
    plane("review_floor", (0, -3, 0), (0, 0, 0), (12, 6, 1), (0.22, 0.16, 0.11))
    for at, energy in (((-3.6, 2.4, 2.9), 260), ((0.0, 2.6, 2.9), 300), ((3.2, 2.4, 2.8), 220)):
        bpy.ops.object.light_add(type="AREA", location=conv(at))
        lamp = bpy.context.object
        lamp.data.energy = energy
        lamp.data.size = 0.8
        lamp.data.color = (1.0, 0.90, 0.74)
        lamp.rotation_euler = (math.radians(40), 0, 0)
        temp.append(lamp)
    bpy.ops.object.light_add(type="POINT", location=conv(Vector(REVIEW_AT["Pumpkin"]) + Vector(CANDLE_FLAME)))
    candle = bpy.context.object
    candle.data.energy = 1.2
    candle.data.color = (1.0, 0.62, 0.28)
    temp.append(candle)
    bpy.ops.object.camera_add()
    camera = bpy.context.object
    scene.camera = camera
    temp.append(camera)
    (OUT / "review").mkdir(exist_ok=True)
    def shot(name, eye, target, lens=35):
        camera.location = conv(eye)
        camera.data.lens = lens
        direction = conv(target) - conv(eye)
        camera.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = str(OUT / "review" / (name + ".png"))
        bpy.ops.render.render(write_still=True)
    def look(name, assembly, offset, aim_at=(0, 0, 0), lens=35):
        base = Vector(REVIEW_AT[assembly])
        shot(name, base + Vector(offset), base + Vector(aim_at), lens)
    shot("set_overview", (-0.4, 1.6, 6.4), (-0.4, 1.3, 0.0), 24)
    look("flag_side", "Flag", (2.3, 0.4, 1.6), (0.1, 0.25, 0.45))
    look("flag_front", "Flag", (0.4, 0.2, 3.0), (0.1, 0.3, 0.4))
    look("flag_canton", "Flag", (0.75, 0.75, 0.95), (0.03, 0.62, 0.62), 50)
    look("bunting", "Bunting", (0.3, -0.5, 2.1), (0.0, -0.3, 0.0))
    look("bunting_raking", "Bunting", (1.3, -0.3, 0.7), (0.0, -0.3, 0.0))
    look("wreath", "Wreath", (0.15, 0.0, 0.95), (0.0, 0.02, 0.05))
    look("wreath_raking", "Wreath", (0.6, 0.1, 0.5), (0.0, 0.05, 0.05))
    look("crepe", "Crepe", (0.0, -0.2, 2.4), (0.0, -0.15, 0.0))
    look("cutouts", "Cutouts", (0.0, -0.05, 1.15), (0.0, -0.08, 0.0))
    look("poppy_pin", "PoppyPin", (0.08, 0.0, 0.30), (0.0, -0.02, 0.0))
    look("tree", "Tree", (0.25, 0.55, 1.25), (0.0, 0.36, 0.0))
    look("tree_close", "Tree", (0.3, 0.50, 0.55), (0.0, 0.42, 0.0))
    look("lilies", "Lilies", (0.2, 0.55, 1.0), (0.0, 0.28, 0.0))
    look("pumpkin", "Pumpkin", (0.12, 0.30, 0.85), (0.0, 0.13, 0.0))
    look("pumpkin_side", "Pumpkin", (0.6, 0.35, 0.5), (0.0, 0.13, 0.0))
    look("poppies", "Poppies", (0.1, 0.30, 0.60), (0.0, 0.16, 0.0))
    look("carnations", "Carnations", (0.1, 0.34, 0.62), (0.0, 0.20, 0.0))
    # Each cut-paper kind in turn (they share a string position).
    by_name = {row["name"]: row["object"] for row in PARTS}
    cut = [n for n in by_name if n.startswith("Cutouts__")]
    for n in cut:
        for m in cut:
            by_name[m].hide_render = m != n
        look("cutouts_" + n.split("__")[1].split("_ON_")[0].lower(), "Cutouts", (0.0, -0.05, 0.95), (0.0, -0.07, 0.0))
    for m in cut:
        by_name[m].hide_render = False
    for o in temp:
        bpy.data.objects.remove(o)
    scene.camera = None


def export(roots, objs):
    blend = ROOT / "art/blender/occasion_dressing.blend"
    for image in bpy.data.images:   # the editable source refers to the catalogue maps relatively
        if image.source == "FILE":
            image.filepath = bpy.path.relpath(image.filepath, start=str(ROOT / "art/blender"))
    # The review stand is not part of the asset: every assembly exports at its own origin.
    for empty in roots.values():
        empty.location = (0, 0, 0)
    bpy.ops.wm.save_as_mainfile(filepath=str(blend), check_existing=False)
    bpy.ops.object.select_all(action="DESELECT")
    for o in list(roots.values()) + objs:
        o.select_set(True)
    glb = ROOT / "game/assets/props/occasion_dressing.glb"

    class ExportChartTangents:
        """Write each corner's tangent from its own chart (the project's
        exporter convention, as in build_pawn_clocks.py and
        build_fire_apparatus.py): the u direction, made square to the exported
        normal, with the one handedness."""
        corrected = 0

        def gather_mesh_hook(self, mesh, blender_data, blender_object, vertex_groups, modifiers, materials, export_settings):
            from io_scene_gltf2.io.exp.binary_data import BinaryData
            from io_scene_gltf2.io.com.constants import BufferViewTarget
            for primitive in mesh.primitives:
                def vectors(key):
                    accessor = primitive.attributes[key]
                    assert accessor.component_type == 5126 and accessor.type == "VEC3"
                    return np.frombuffer(accessor.buffer_view.data, dtype="<f4").reshape((-1, 3)).astype(np.float64)
                n = vectors("NORMAL")
                n /= np.linalg.norm(n, axis=1)[:, None]
                guide = vectors("_TANGENT_GUIDE")
                tangent = guide - n * np.sum(guide * n, axis=1)[:, None]
                tangent /= np.linalg.norm(tangent, axis=1)[:, None]
                assert np.isfinite(tangent).all()
                packed = np.column_stack((tangent, -np.ones(len(n)))).astype(np.float32)
                primitive.attributes["TANGENT"].buffer_view = BinaryData(packed.tobytes(), BufferViewTarget.ARRAY_BUFFER)
                type(self).corrected += 1
                for key in list(primitive.attributes):
                    if key.upper() == "_TANGENT_GUIDE":
                        del primitive.attributes[key]

    import io_scene_gltf2
    io_scene_gltf2.glTF2ExportUserExtension = ExportChartTangents
    bpy.ops.export_scene.gltf(filepath=str(glb), export_format="GLB", use_selection=True, export_yup=True, export_apply=True,
                              export_normals=True, export_tangents=True, export_texcoords=True, export_attributes=True,
                              export_materials="PLACEHOLDER", export_vertex_color="NONE", export_animations=False)
    assert ExportChartTangents.corrected == len(objs), (ExportChartTangents.corrected, len(objs))
    rows = []
    for spec in PROPS:
        parts = []
        for row in PARTS:
            short = row["name"].split("__")[1].split("_ON_")[0]
            if row["assembly"] != spec["assembly"] or (spec["only"] is not None and short != spec["only"]):
                continue
            parts.append({"mesh": row["name"], "material": row["key"], "tint": [round(c, 3) for c in spec["tints"].get(short, row["tint"])]})
        entry = {"id": spec["id"], "shadow": spec["shadow"], "reach": spec["range"], "candle": spec["candle"] or [], "parts": parts}
        rows.append(entry)
    data = json.loads(DATA.read_text(encoding="utf-8")) if DATA.is_file() else {"schema_version": 1, "placements": [], "occasions": []}
    data = {"schema_version": 1, "asset": "res://assets/props/occasion_dressing.glb", "props": rows,
            "placements": data.get("placements", []), "occasions": data.get("occasions", [])}
    DATA.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8", newline="\n")
    manifest = {"seed": SEED, "triangles_total": sum(row["triangles"] for row in PARTS),
                "objects": [{"name": row["name"], "triangles": row["triangles"]} for row in PARTS]}
    (OUT / "occasion_dressing_manifest.json").write_text(json.dumps(manifest, indent=1), encoding="utf-8")
    for assembly in REVIEW_AT:
        print("[OCCASION DRESSING] %s: %d objects, %d triangles" % (assembly, sum(1 for r in PARTS if r["assembly"] == assembly),
                                                                    sum(r["triangles"] for r in PARTS if r["assembly"] == assembly)))
    print("[OCCASION DRESSING] %d objects, %d triangles" % (len(PARTS), manifest["triangles_total"]))


build_flag()
build_bunting()
build_wreath()
build_tree()
build_poppies()
build_carnations()
build_lilies()
build_pumpkin()
build_cutouts()
build_crepe()
roots, objs = assemble()
if "--no-review" not in sys.argv:
    review(roots)
export(roots, objs)
