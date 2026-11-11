"""The eighteen witness clocks and the two honest clocks, authored in Blender.

V1 drew these from BoxMesh/CylinderMesh primitives and two printed dial atlases
(domestic_witness_clock.gd, clock_prop.gd). V2 keeps every behaviour of those
scripts and replaces only what is seen: one assembly per dial style, each a
period object with a case, a back that reaches the wall or feet that reach the
shelf, a bezel, hour marks in geometry, and separate parts on true pivots for
the hands, the pendulum, the tell and the one dial detail that goes wrong.

No numerals are modelled or textured (RUL-008): the builder writes where each
Label3D numeral and reading goes, and the runtime letters them.

Clock frame (what the runtime sees, Godot axes): +X right, +Y up, +Z out of the
dial. A wall clock's origin is the dial centre projected on the wall plane
(z = 0 is the wall). A table clock's origin is the centre of its footprint on
the supporting surface (y = 0), dial facing +Z. Blender is Z-up; the builder
works in the clock frame and converts once.

Deterministic: no randomness.

  blender -b --python-exit-code 1 -P art/blender/scripts/build_witness_clocks.py -- <review_dir>
Writes game/assets/props/witness_clocks.glb, art/blender/witness_clocks.blend,
game/data/orison_v2/witness_clocks.json and review renders under <review_dir>.
"""
import bpy, bmesh, json, math, sys
from mathutils import Vector, Matrix
from pathlib import Path

ROOT = next(p for p in Path(__file__).resolve().parents if (p / "game/project.godot").is_file())
OUT = Path(sys.argv[sys.argv.index("--") + 1]) if "--" in sys.argv else ROOT / "tmp/witness_clocks"
OUT.mkdir(parents=True, exist_ok=True)
TAU = math.tau
AXY = Matrix.Rotation(-math.pi / 2, 4, "X")  # a lathe's Z axis stood up along +Y
AXX = Matrix.Rotation(math.pi / 2, 4, "Y")   # a lathe's Z axis laid along +X
INK = "1a1612"
FONT_SERIF = "res://assets/fonts/oldstandardtt/OldStandard-Bold.ttf"
FONT_SANS = "res://assets/fonts/jost/Jost[wght].ttf"
FONT_MONO = "res://assets/fonts/courier_prime/CourierPrime-Bold.ttf"
FONT_TYPE = "res://assets/fonts/specialelite/SpecialElite-Regular.ttf"
# Review-only colours for the catalogue keys (the runtime binds the real maps).
PREVIEW = {
    "oak_quartered": (0.42, 0.27, 0.13), "wood_dark": (0.17, 0.10, 0.055), "brass": (0.72, 0.55, 0.22),
    "brass_dull": (0.52, 0.42, 0.22), "nickel_plated": (0.70, 0.70, 0.67), "chrome": (0.82, 0.83, 0.85),
    "cast_iron": (0.10, 0.10, 0.10), "iron_blackened": (0.05, 0.05, 0.055), "enamel": (0.85, 0.85, 0.80),
    "bakelite_black": (0.03, 0.028, 0.026), "paper": (0.86, 0.82, 0.70), "porcelain": (0.92, 0.91, 0.87),
    "linen": (0.78, 0.74, 0.64), "leather_worn": (0.20, 0.12, 0.07), "milk_glass": (0.90, 0.88, 0.80),
    "rubber_aged": (0.06, 0.06, 0.06), "mica_heater": (0.55, 0.28, 0.08), "glassish": (0.8, 0.9, 0.9),
    "plywood": (0.72, 0.58, 0.38),
}
MOVING = ["HourHand", "MinuteHand", "SecondHand", "Pendulum", "TellMark", "OddMark", "Cover"]
FACE_RIG = ["HourHand", "MinuteHand", "SecondHand", "OddMark"]


def place(x=0.0, y=0.0, z=0.0, rz=0.0):
    return Matrix.Translation((x, y, z)) @ Matrix.Rotation(rz, 4, "Z")


def hour_at(i, r, n=12):
    a = TAU * i / n
    return math.sin(a) * r, math.cos(a) * r, -a


def box_geo(sx, sy, sz):
    x, y, z = sx / 2, sy / 2, sz / 2
    v = [(-x, -y, -z), (x, -y, -z), (x, y, -z), (-x, y, -z), (-x, -y, z), (x, -y, z), (x, y, z), (-x, y, z)]
    return v, [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]


def prism_geo(pts, z0, z1):
    n = len(pts)
    v = [(x, y, z0) for x, y in pts] + [(x, y, z1) for x, y in pts]
    f = [tuple(range(n - 1, -1, -1)), tuple(range(n, 2 * n))]
    return v, f + [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]


def lathe_geo(profile, segs=48, phase=0.0, tangent=False):
    """Revolve a closed (r, z) loop about Z. Points on the axis become one vertex."""
    v, rows, f = [], [], []
    for r, z in profile:
        if r < 1e-9:
            v.append((0.0, 0.0, z))
            rows.append([len(v) - 1] * segs)
        else:
            row = []
            for k in range(segs):
                a = phase + TAU * k / segs
                v.append((r * math.cos(a), r * math.sin(a), z))
                row.append(len(v) - 1)
            rows.append(row)
    n = len(profile)
    for i in range(n):
        a, b = rows[i], rows[(i + 1) % n]
        for k in range(segs):
            k2 = (k + 1) % segs
            q = []
            for t in (a[k], a[k2], b[k2], b[k]):
                if t not in q:
                    q.append(t)
            if len(q) < 3:
                continue
            if tangent:
                am = phase + TAU * (k + 0.5) / segs
                f.append((tuple(q), (-math.sin(am), math.cos(am), 0.0)))
            else:
                f.append(tuple(q))
    return v, f


def tube_geo(points, r, segs=6):
    pts = [Vector(p) for p in points]
    v, rows, f = [], [], []
    a = None
    for i, p in enumerate(pts):
        t = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
        a = t.orthogonal().normalized() if a is None else (a - t * a.dot(t)).normalized()
        b = t.cross(a)
        row = []
        for k in range(segs):
            ang = TAU * k / segs
            v.append(tuple(p + (a * math.cos(ang) + b * math.sin(ang)) * r))
            row.append(len(v) - 1)
        rows.append(row)
    for i in range(len(rows) - 1):
        for k in range(segs):
            f.append((rows[i][k], rows[i][(k + 1) % segs], rows[i + 1][(k + 1) % segs], rows[i + 1][k]))
    f.append(tuple(reversed(rows[0])))
    f.append(tuple(rows[-1]))
    return v, f


def arc(cx, cy, r, a0, a1, n):
    return [(cx + r * math.cos(a0 + (a1 - a0) * i / n), cy + r * math.sin(a0 + (a1 - a0) * i / n)) for i in range(n + 1)]


class Asm:
    def __init__(self, style, mounting, dial=(0.0, 0.0, 0.0)):
        self.style, self.mounting = style, mounting
        self.dial = dial            # dial centre and dial-plate height (x, y, z)
        self.buckets, self.order = {}, []
        self.pivots, self.tints, self.rigs = {}, {}, {}
        self.labels, self.display, self.possessed, self.extra = [], None, None, {}

    def bucket(self, comp, key, tint=None):
        k = (comp, key)
        if k not in self.buckets:
            bm = bmesh.new()
            bm.faces.layers.float_vector.new("grain")
            self.buckets[k] = bm
            self.order.append(k)
        if tint is not None:
            self.tints[k] = tint
        return self.buckets[k]

    def emit(self, comp, key, geo, m=None, grain=(1, 0, 0), tint=None):
        bm = self.bucket(comp, key, tint)
        layer = bm.faces.layers.float_vector["grain"]
        verts, faces = geo
        rot = m.to_3x3() if m is not None else None
        bv = [bm.verts.new(m @ Vector(v) if m is not None else Vector(v)) for v in verts]
        for face in faces:
            idx, g = (face if isinstance(face[1], tuple) else (face, grain))
            g = Vector(g)
            if rot is not None:
                g = (rot @ g).normalized()
            try:
                made = bm.faces.new([bv[i] for i in idx])
            except ValueError:
                continue
            made[layer] = g

    # -- stock ------------------------------------------------------------
    def box(self, comp, key, at, size, rz=0.0, grain=None, tint=None, m=None):
        if grain is None:
            grain = [(1, 0, 0), (0, 1, 0), (0, 0, 1)][max(range(3), key=lambda i: size[i])]
        mm = place(at[0], at[1], at[2], rz)
        self.emit(comp, key, box_geo(*size), (m @ mm) if m is not None else mm, grain, tint)

    def prism(self, comp, key, pts, z0, z1, m=None, grain=(1, 0, 0), tint=None):
        self.emit(comp, key, prism_geo(pts, z0, z1), m, grain, tint)

    def lathe(self, comp, key, profile, cx=0.0, cy=0.0, segs=48, phase=0.0, m=None, tangent=False,
              grain=(1, 0, 0), tint=None):
        mm = place(cx, cy)
        self.emit(comp, key, lathe_geo(profile, segs, phase, tangent), (m @ mm) if m is not None else mm, grain, tint)

    def disc(self, comp, key, r, z0, z1, cx=0.0, cy=0.0, segs=40, tint=None, m=None, phase=0.0):
        self.lathe(comp, key, [(0, z0), (r, z0), (r, z1), (0, z1)], cx, cy, segs, phase, m, tint=tint)

    def ring(self, comp, key, r0, r1, z0, z1, cx=0.0, cy=0.0, segs=48, tint=None, m=None, phase=0.0, tangent=False):
        self.lathe(comp, key, [(r0, z0), (r1, z0), (r1, z1), (r0, z1)], cx, cy, segs, phase, m, tangent, tint=tint)

    def tube(self, comp, key, pts, r, segs=6, tint=None, m=None):
        self.emit(comp, key, tube_geo(pts, r, segs), m, (0, 1, 0), tint)

    def dome(self, comp, key, r, h, z, cx=0.0, cy=0.0, segs=12, tint=None, m=None):
        prof = [(0, z)] + [(r * math.cos(t * math.pi / 8), z + h * math.sin(t * math.pi / 8)) for t in range(4)] + [(0, z + h)]
        self.lathe(comp, key, prof, cx, cy, segs, 0.0, m, tint=tint)

    # -- clock furniture ---------------------------------------------------
    def can(self, comp, key, r, depth, lip=0.006, tint=None, segs=48, cy=0.0, z0=0.0):
        """A closed drum whose back rim is the wall contact."""
        self.lathe(comp, key, [(0, z0), (r, z0), (r, depth - lip), (r - lip * 0.35, depth - lip * 0.3),
                               (r - lip, depth), (0, depth)], 0.0, cy, segs, tint=tint)

    def bezel(self, comp, key, r0, width, z, height, tint=None, segs=48, cy=0.0):
        r1 = r0 + width
        self.lathe(comp, key, [(r0, z), (r1, z), (r1, z + height * 0.55), (r1 - width * 0.35, z + height),
                               (r0 + width * 0.25, z + height), (r0, z + height * 0.72)], 0.0, cy, segs, tint=tint)

    def marks(self, comp, key, r, long, short, skip=(), n=12, tint=None, th=0.0012, every=3):
        cx, cy, z = self.dial
        for i in range(n):
            if i in skip:
                continue
            w, l = long if i % every == 0 else short
            x, y, rz = hour_at(i, r, n)
            self.box(comp, key, (cx + x, cy + y, z + th / 2 - 0.0003), (w, l, th), rz, tint=tint)

    def odd_mark(self, key, i, r, size, tint=None, th=0.0012, geo=None, n=12):
        """The one hour mark that moves when the dial is possessed."""
        cx, cy, z = self.dial
        x, y, rz = hour_at(i, r, n)
        self.pivots["OddMark"] = (cx + x, cy + y, z + th / 2 - 0.0003)
        self.emit("OddMark", key, geo if geo is not None else box_geo(size[0], size[1], th),
                  place(cx + x, cy + y, z + th / 2 - 0.0003, rz), (0, 1, 0), tint)

    def hand(self, comp, key, kind, length, width, dz, tint=None, th=0.001, hub=0.0075, tail=None):
        cx, cy, z = self.dial
        tail = length * 0.16 if tail is None else tail
        w, L = width, length
        if kind == "baton":
            pts = [(-w / 2, -tail), (w / 2, -tail), (w * 0.4, L), (-w * 0.4, L)]
        elif kind == "lance":
            pts = [(-w * 0.3, -tail), (w * 0.3, -tail), (w / 2, L * 0.3), (0, L), (-w / 2, L * 0.3)]
        elif kind == "spade":
            s = w * 0.2
            pts = [(-s, -tail), (s, -tail), (s, L * 0.56), (w * 0.85, L * 0.70), (w * 0.5, L * 0.84), (0, L),
                   (-w * 0.5, L * 0.84), (-w * 0.85, L * 0.70), (-s, L * 0.56)]
        elif kind == "lozenge":
            pts = [(-w * 0.25, -tail), (w * 0.25, -tail), (w * 0.25, L * 0.25), (w / 2, L * 0.55), (0, L),
                   (-w / 2, L * 0.55), (-w * 0.25, L * 0.25)]
        else:  # sweep: a thin seconds hand with a counterpoise
            pts = [(-w / 2, -tail), (w / 2, -tail), (w * 0.3, L), (-w * 0.3, L)]
            self.disc(comp, key, w * 1.9, z + dz, z + dz + th, cx, cy - tail * 0.72, 12, tint)
        self.pivots[comp] = (cx, cy, 0.0)
        self.prism(comp, key, [(cx + x, cy + y) for x, y in pts], z + dz, z + dz + th, grain=(0, 1, 0), tint=tint)
        self.disc(comp, key, hub, z + dz - 0.0004, z + dz + th + 0.0006, cx, cy, 14, tint)

    def hands(self, key, kinds, lengths, widths, second_key="enamel", second_tint="accent", tint=None):
        self.hand("HourHand", key, kinds[0], lengths[0], widths[0], 0.0030, tint)
        self.hand("MinuteHand", key, kinds[1], lengths[1], widths[1], 0.0052, tint, hub=0.006)
        self.hand("SecondHand", second_key, "sweep", lengths[2], widths[2], 0.0074, second_tint, hub=0.0045)

    def tell(self, x, y, z, r=0.006, key="enamel"):
        self.pivots["TellMark"] = (x, y, z)
        self.dome("TellMark", key, r, r * 0.45, z, x, y, 12, "accent")
        self.ring("TellMark", key, r, r * 1.35, z, z + r * 0.2, x, y, 12, "accent")

    def glass(self, r, z, th=0.0015, cy=None, segs=40):
        self.disc("Glass", "glassish", r, z, z + th, self.dial[0], self.dial[1] if cy is None else cy, segs)

    def numeral(self, text, i, r, height, font=FONT_SERIF, color=INK, n=12):
        cx, cy, z = self.dial
        x, y, _rz = hour_at(i, r, n)
        self.labels.append({"text": text, "at": [round(cx + x, 5), round(cy + y, 5), round(z + 0.0012, 5)],
                            "height": height, "font": font, "color": color})

    def reading(self, x, y, z, height, font=FONT_MONO):
        self.display = {"at": [x, y, z], "height": height, "font": font}


def std_dial(a, r_dial, glass_z=None, glass=True, tell_at=None):
    """Tell stud low on the dial, reading above the glass, as V1 placed them."""
    cx, cy, z = a.dial
    if tell_at is None:
        a.tell(cx, cy - r_dial * 0.58, z)
    else:
        a.tell(*tell_at)
    gz = z + 0.0105 if glass_z is None else glass_z
    if glass:
        a.glass(r_dial, gz)
    a.reading(cx, cy - r_dial * 0.03, gz + 0.003, min(0.028, r_dial * 0.24), FONT_MONO)


# ---------------------------------------------------------------------------
# The eighteen witness styles. Sizes follow V1's _build_housing: round cases of
# 0.19 m radius, boxed instruments 0.42 x 0.22 m, unless the object V1 names is
# really another size (a tambour, a travelling alarm).
# ---------------------------------------------------------------------------
def octagon_case(a, r_flat, depth, key, r_open, tint=None):
    """Eight mitred rails with a moulded face, grain along each rail."""
    r = r_flat / math.cos(math.pi / 8)
    ri = r_open / math.cos(math.pi / 8)
    a.lathe("Case", key, [(ri, 0.0), (r, 0.0), (r, depth * 0.72), (r - 0.012, depth), (ri + 0.012, depth),
                          (ri, depth - 0.008)], segs=8, phase=math.pi / 8, tangent=True, tint=tint)


def drop_case(a, key, back_key, w, top, bottom, depth, window, pointed, tint=None):
    """The pendulum box under a drop dial: back board, cheeks, base, glazed door."""
    h = top - bottom
    cy = (top + bottom) / 2
    a.box("Case", back_key, (0, cy, 0.004), (w, h, 0.008), grain=(0, 1, 0))
    for sx in (-1, 1):
        a.box("Case", key, (sx * (w / 2 - 0.007), cy, depth / 2), (0.014, h, depth), grain=(0, 1, 0), tint=tint)
    if pointed:
        a.prism("Case", key, [(-w / 2, bottom), (0, bottom - w * 0.30), (w / 2, bottom), (w / 2, bottom + 0.016),
                              (-w / 2, bottom + 0.016)], 0.0, depth, tint=tint)
    else:
        a.box("Case", key, (0, bottom + 0.008, (depth + 0.008) / 2), (w + 0.02, 0.016, depth + 0.008), tint=tint)
    ww, wh = window
    rail = (w - ww) / 2
    stile = (h - wh) / 2
    for sx in (-1, 1):
        a.box("Case", key, (sx * (w / 2 - rail / 2), cy, depth - 0.006), (rail, h, 0.012), grain=(0, 1, 0), tint=tint)
    for sy in (-1, 1):
        a.box("Case", key, (0, cy + sy * (h / 2 - stile / 2), depth - 0.006), (ww, stile, 0.012), tint=tint)
    a.box("Glass", "glassish", (0, cy, depth - 0.007), (ww, wh, 0.0015))


def schoolhouse():
    a = Asm("schoolhouse", "wall", (0, 0, 0.052))
    octagon_case(a, 0.208, 0.060, "oak_quartered", 0.150)
    a.disc("Case", "wood_dark", 0.152 / math.cos(math.pi / 8), 0.0, 0.050, segs=8, phase=math.pi / 8)
    drop_case(a, "oak_quartered", "wood_dark", 0.19, -0.195, -0.455, 0.055, (0.11, 0.15), True)
    a.box("Case", "brass", (0, 0.222, 0.0015), (0.034, 0.05, 0.003))       # hanger plate on the wall
    a.box("Case", "brass", (0, -0.21, 0.040), (0.006, 0.03, 0.003))        # pendulum suspension
    a.box("Case", "brass", (0, -0.30, 0.030), (0.005, 0.17, 0.003), grain=(0, 1, 0))
    a.lathe("Case", "brass", [(0, 0.026), (0.036, 0.028), (0.040, 0.031), (0.036, 0.034), (0, 0.036)], 0, -0.385, 24)
    a.disc("Dial", "paper", 0.150, 0.050, 0.052)
    a.ring("DialMarks", "bakelite_black", 0.139, 0.1405, 0.0518, 0.0526, tint=INK)
    a.marks("DialMarks", "bakelite_black", 0.128, (0.006, 0.016), (0.004, 0.014), skip=(0, 3, 6, 9), tint=INK)
    a.bezel("Case", "brass", 0.150, 0.014, 0.050, 0.018)
    for i, t in ((0, "12"), (3, "3"), (6, "6"), (9, "9")):
        a.numeral(t, i, 0.118, 0.030)
    a.hands("bakelite_black", ("spade", "spade"), (0.080, 0.118, 0.132), (0.020, 0.014, 0.004), tint=INK)
    std_dial(a, 0.150)
    a.possessed = {"kind": "label", "index": 2, "text": "9",
                   "note": "the 6 at the foot of the dial reads 9"}
    return a


def hospital():
    a = Asm("hospital", "wall", (0, 0, 0.050))
    body = "c2c9bf"
    a.can("Case", "enamel", 0.190, 0.048, 0.010, tint=body)
    a.ring("Case", "enamel", 0.186, 0.198, 0.0, 0.010, tint=body)           # wall flange
    for sx in (-1, 1):                                                      # screwed lugs
        a.box("Case", "enamel", (sx * 0.205, 0, 0.003), (0.036, 0.034, 0.006), tint=body)
        a.dome("Trim", "nickel_plated", 0.006, 0.003, 0.006, sx * 0.210, 0, 10)
    a.disc("Dial", "porcelain", 0.160, 0.048, 0.050)
    a.bezel("Trim", "nickel_plated", 0.160, 0.016, 0.048, 0.019)
    a.marks("DialMarks", "bakelite_black", 0.137, (0.009, 0.024), (0.006, 0.020), skip=(0, 3, 6, 9), tint=INK)
    a.ring("DialMarks", "bakelite_black", 0.152, 0.1535, 0.0498, 0.0506, tint=INK)
    for i, t in ((0, "12"), (3, "3"), (6, "6"), (9, "9")):
        a.numeral(t, i, 0.125, 0.032, FONT_SANS)
    a.hands("bakelite_black", ("baton", "baton"), (0.080, 0.118, 0.132), (0.013, 0.009, 0.004), tint=INK)
    std_dial(a, 0.160)
    a.possessed = {"kind": "label", "index": 0, "text": "13",
                   "note": "the 12 at the head of the dial reads 13"}
    return a


def bauhaus():
    a = Asm("bauhaus", "wall", (0, 0, 0.040))
    a.can("Case", "enamel", 0.188, 0.038, 0.005, tint="e6e6e0")
    a.disc("Dial", "porcelain", 0.166, 0.038, 0.040)
    a.lathe("Trim", "chrome", [(0.166, 0.038), (0.205, 0.038), (0.205, 0.050), (0.198, 0.056), (0.172, 0.056),
                               (0.166, 0.052)], segs=56)
    a.marks("DialMarks", "bakelite_black", 0.140, (0.008, 0.034), (0.005, 0.026), skip=(2,), tint=INK)
    a.odd_mark("bakelite_black", 2, 0.140, (0.005, 0.026), INK)
    a.hands("bakelite_black", ("baton", "baton"), (0.080, 0.118, 0.132), (0.011, 0.007, 0.0035), tint=INK)
    std_dial(a, 0.166)
    a.possessed = {"kind": "part", "angle_deg": 60.0, "radius": 0.112, "spin_deg": 0.0,
                   "note": "the bar at 2 has slid inward off the ring of marks"}
    return a


def stitch():
    a = Asm("stitch", "wall", (0, 0, 0.022))
    beech = "ead9bd"
    a.box("Case", "bakelite_black", (0, 0, 0.009), (0.076, 0.076, 0.018))            # movement, on the wall
    a.ring("Case", "oak_quartered", 0.176, 0.190, 0.008, 0.030, segs=56, tint=beech, tangent=True)   # outer hoop
    a.ring("Case", "oak_quartered", 0.166, 0.176, 0.011, 0.026, segs=56, tint=beech, tangent=True)   # inner hoop
    a.box("Trim", "brass", (0, 0.203, 0.019), (0.030, 0.030, 0.016))                 # the tightening block
    a.disc("Trim", "brass", 0.004, -0.030, 0.030, m=place(0, 0.207, 0.019) @ AXX, segs=10)
    a.disc("Trim", "brass", 0.009, 0.030, 0.038, m=place(0, 0.207, 0.019) @ AXX, segs=10)
    a.box("Case", "brass", (0, 0.150, 0.0015), (0.024, 0.11, 0.003), grain=(0, 1, 0))    # strap from hoop to wall
    a.box("Case", "brass", (0, 0.197, 0.006), (0.024, 0.012, 0.012))
    a.disc("Dial", "linen", 0.176, 0.020, 0.022, segs=56)
    thread = "accent"
    for i in range(12):
        if i == 7:
            continue
        x, y, rz = hour_at(i, 0.132)
        for tilt in ((0.6, -0.6) if i % 3 == 0 else (0.0,)):
            a.box("DialMarks", "linen", (x, y, 0.0226), (0.004, 0.022 if i % 3 == 0 else 0.016, 0.0016), rz + tilt, tint=thread)
    x, y, rz = hour_at(7, 0.132)
    a.pivots["OddMark"] = (x, y, 0.0226)
    a.emit("OddMark", "linen", box_geo(0.004, 0.016, 0.0016), place(x, y, 0.0226, rz), (0, 1, 0), thread)
    for i in range(8):                                                       # V1's running stitch at the foot
        a.box("DialMarks", "linen", (-0.07 + i * 0.02, -0.148, 0.0226), (0.014, 0.004, 0.0016), 0.18, tint=thread)
    a.hands("brass", ("lance", "lance"), (0.080, 0.118, 0.132), (0.012, 0.008, 0.0035))
    std_dial(a, 0.150, glass=False, glass_z=0.022 + 0.011)
    a.possessed = {"kind": "part", "angle_deg": 210.0, "radius": 0.132, "spin_deg": 90.0,
                   "note": "the stitch at 7 lies across the dial instead of along it"}
    return a


def instrument_case(a, key, w, h, depth, tint=None, chamfer=0.012):
    c = chamfer
    pts = [(-w / 2 + c, -h / 2), (w / 2 - c, -h / 2), (w / 2, -h / 2 + c), (w / 2, h / 2 - c), (w / 2 - c, h / 2),
           (-w / 2 + c, h / 2), (-w / 2, h / 2 - c), (-w / 2, -h / 2 + c)]
    a.prism("Case", key, pts, 0.0, depth, tint=tint)


def conduit(a, x, y0, y1, z=0.011, key="brass_dull"):
    """A line conduit from the case to a wall rose: these faces are wired."""
    a.disc("Trim", key, 0.007, 0.0, abs(y1 - y0), m=place(x, min(y0, y1), z) @ AXY, segs=10)
    a.disc("Trim", key, 0.019, 0.0, 0.006, cx=x, cy=y1, segs=14)
    a.disc("Trim", key, 0.010, 0.006, 0.022, cx=x, cy=y1, segs=12)


def vantry_modular():
    a = Asm("vantry_modular", "wall", (0, 0, 0.060))
    body = "2a3040"
    instrument_case(a, "bakelite_black", 0.42, 0.22, 0.055, body)
    a.box("Case", "bakelite_black", (0, 0, 0.0565), (0.396, 0.196, 0.003), tint="1c2029")      # front panel
    for x in (-0.07, 0.07):                                                                    # module joints
        a.box("Trim", "nickel_plated", (x * 1.52, 0, 0.0585), (0.003, 0.196, 0.002), grain=(0, 1, 0))
    a.disc("Dial", "porcelain", 0.090, 0.058, 0.060)
    a.bezel("Trim", "nickel_plated", 0.090, 0.010, 0.058, 0.017)
    for i in range(12):
        if i == 3:
            continue
        x, y, rz = hour_at(i, 0.074)
        a.box("DialMarks", "bakelite_black", (x, y, 0.0604), (0.010 if i % 3 == 0 else 0.006, 0.012, 0.0012), rz, tint=INK)
    a.odd_mark("bakelite_black", 3, 0.074, (0.010, 0.012), INK)
    for j in range(3):                                                       # three signal lenses
        y = 0.058 - j * 0.058
        a.ring("Trim", "nickel_plated", 0.012, 0.017, 0.058, 0.063, -0.158, y, 16)
        a.dome("Lens", "milk_glass", 0.012, 0.005, 0.058, -0.158, y, 12)
    for j in range(6):                                                       # sounder grille
        a.box("Trim", "nickel_plated", (0.158, 0.060 - j * 0.024, 0.0590), (0.070, 0.006, 0.002))
    a.box("Trim", "enamel", (0, -0.094, 0.0590), (0.30, 0.008, 0.002), tint="accent")
    conduit(a, 0.0, -0.11, -0.20)
    a.hands("bakelite_black", ("baton", "baton"), (0.046, 0.068, 0.078), (0.009, 0.006, 0.003), tint=INK)
    std_dial(a, 0.090)
    a.possessed = {"kind": "part", "angle_deg": 105.0, "radius": 0.074, "spin_deg": -15.0,
                   "note": "the block at 3 sits half an hour late, between 3 and 4"}
    return a


def sunray_1920():
    a = Asm("sunray_1920", "wall", (0, 0, 0.046))
    a.can("Case", "wood_dark", 0.128, 0.044, 0.006)
    for i in range(24):                                                      # gilt rays, long and short
        ang = TAU * i / 24
        L = 0.31 if i % 2 == 0 else 0.235
        w0, w1 = (0.030, 0.006) if i % 2 == 0 else (0.022, 0.004)
        pts = [(-w0 / 2, 0.118), (w0 / 2, 0.118), (w1 / 2, L), (-w1 / 2, L)]
        a.prism("Rays", "brass_dull", pts, 0.0, 0.012 if i % 2 == 0 else 0.009, place(0, 0, 0, -ang), (0, 1, 0))
    a.disc("Dial", "paper", 0.104, 0.044, 0.046, tint="f1e6c8")
    a.bezel("Trim", "brass", 0.104, 0.014, 0.044, 0.018)
    a.marks("DialMarks", "bakelite_black", 0.088, (0.006, 0.020), (0.004, 0.014), skip=(11,), tint=INK)
    a.odd_mark("bakelite_black", 11, 0.088, (0.004, 0.014), INK)
    a.ring("DialMarks", "brass", 0.030, 0.034, 0.0458, 0.0466)
    a.hands("bakelite_black", ("spade", "lance"), (0.056, 0.082, 0.092), (0.016, 0.009, 0.003), tint=INK)
    std_dial(a, 0.104)
    a.possessed = {"kind": "part", "angle_deg": 348.0, "radius": 0.088, "spin_deg": 18.0,
                   "note": "the mark at 11 has crept up against 12"}
    return a


def industrial():
    a = Asm("industrial", "wall", (0, 0, 0.066))
    body = "5d6466"
    a.can("Case", "enamel", 0.186, 0.064, 0.008, tint=body)
    a.ring("Case", "enamel", 0.180, 0.208, 0.0, 0.008, tint=body)            # bolting flange on the wall
    for i in range(6):
        x, y, _ = hour_at(i + 0.5, 0.197, 6)
        a.dome("Trim", "iron_blackened", 0.007, 0.004, 0.008, x, y, 6)
    a.disc("Dial", "enamel", 0.158, 0.064, 0.066, tint="e2dfd2")
    a.bezel("Case", "enamel", 0.158, 0.022, 0.064, 0.020, tint=body)
    a.marks("DialMarks", "bakelite_black", 0.134, (0.012, 0.030), (0.008, 0.024), skip=(0, 3, 4, 6, 9), tint=INK)
    a.odd_mark("bakelite_black", 4, 0.134, (0.008, 0.024), INK)
    for i, t in ((0, "12"), (3, "3"), (6, "6"), (9, "9")):
        a.numeral(t, i, 0.122, 0.036, FONT_SANS)
    for i in range(3):                                                       # the wire guard
        ang = math.pi * i / 3
        pts = []
        for s in range(13):
            t = -1 + 2 * s / 12
            r = 0.186 * t
            pts.append((math.sin(ang) * r, math.cos(ang) * r, 0.078 + 0.030 * (1 - t * t)))
        pts = [(pts[0][0], pts[0][1], 0.060)] + pts + [(pts[-1][0], pts[-1][1], 0.060)]
        a.tube("Guard", "iron_blackened", pts, 0.0028, 6)
    a.tube("Guard", "iron_blackened", [(math.sin(TAU * s / 24) * 0.108, math.cos(TAU * s / 24) * 0.108, 0.078 + 0.030 * (1 - (0.108 / 0.186) ** 2))
                                       for s in range(25)], 0.0024, 6)
    a.hands("bakelite_black", ("baton", "baton"), (0.080, 0.118, 0.132), (0.016, 0.011, 0.004), tint=INK)
    std_dial(a, 0.158)
    a.possessed = {"kind": "part", "angle_deg": 120.0, "radius": 0.106, "spin_deg": 0.0,
                   "note": "the bar at 4 has dropped inward toward the arbor"}
    return a


def studio():
    a = Asm("studio", "wall", (0, 0, 0.060))
    body = "2b2b2d"
    instrument_case(a, "enamel", 0.42, 0.22, 0.055, body, 0.008)
    a.box("Case", "bakelite_black", (0, 0, 0.0565), (0.40, 0.20, 0.003))
    a.disc("Dial", "paper", 0.088, 0.058, 0.060)
    a.bezel("Trim", "nickel_plated", 0.088, 0.009, 0.058, 0.017)
    a.marks("DialMarks", "bakelite_black", 0.072, (0.006, 0.016), (0.003, 0.010), tint=INK)
    for sx in (-1, 1):                                                       # the two level meters
        mx = sx * 0.150
        a.box("Dial2", "paper", (mx, 0.012, 0.0585), (0.082, 0.070, 0.001))
        for j in range(9):
            ang = math.radians(-48 + j * 12)
            a.box("DialMarks", "bakelite_black", (mx + math.sin(ang) * 0.052, -0.030 + math.cos(ang) * 0.052, 0.0594),
                  (0.0022, 0.010 if j % 4 == 0 else 0.006, 0.0008), -ang, tint=INK if j < 6 else "8e2f2f")
        needle = math.radians(-22 * sx)
        a.box("DialMarks", "bakelite_black", (mx + math.sin(needle) * 0.026, -0.030 + math.cos(needle) * 0.026, 0.0600),
              (0.0018, 0.050, 0.0008), -needle, tint=INK)
        a.box("Trim", "nickel_plated", (mx, 0.012 + 0.039, 0.0595), (0.090, 0.006, 0.003))
        a.box("Trim", "nickel_plated", (mx, 0.012 - 0.039, 0.0595), (0.090, 0.006, 0.003))
        for ex in (-1, 1):
            a.box("Trim", "nickel_plated", (mx + ex * 0.044, 0.012, 0.0595), (0.006, 0.084, 0.003), grain=(0, 1, 0))
        a.box("Glass", "glassish", (mx, 0.012, 0.0612), (0.082, 0.072, 0.0012))
        a.disc("Trim", "brass", 0.008, 0.058, 0.070, mx - 0.022, -0.078, 10)   # binding posts
        a.disc("Trim", "brass", 0.008, 0.058, 0.070, mx + 0.022, -0.078, 10)
    a.disc("Trim", "bakelite_black", 0.016, 0.058, 0.072, 0, -0.098, 16)        # set knob
    a.hands("bakelite_black", ("baton", "baton"), (0.046, 0.068, 0.078), (0.008, 0.005, 0.003), tint=INK)
    std_dial(a, 0.088)
    return a


def railway():
    a = Asm("railway", "wall", (0, 0, 0.050))
    body = "17171a"
    a.can("Case", "enamel", 0.196, 0.046, 0.008, tint=body)
    a.box("Case", "enamel", (0, -0.222, 0.025), (0.064, 0.09, 0.050), tint=body)      # the movement box below
    a.dome("Trim", "brass", 0.007, 0.004, 0.050, 0, -0.232, 10)
    a.disc("Dial", "porcelain", 0.168, 0.048, 0.050)
    a.lathe("Case", "enamel", [(0.168, 0.046), (0.212, 0.046), (0.212, 0.060), (0.202, 0.072), (0.178, 0.072),
                               (0.168, 0.064)], segs=56, tint=body)
    a.ring("DialMarks", "bakelite_black", 0.156, 0.158, 0.0498, 0.0506, tint=INK)
    a.ring("DialMarks", "bakelite_black", 0.139, 0.1405, 0.0498, 0.0506, tint=INK)
    for i in range(60):
        if i % 5:
            x, y, rz = hour_at(i, 0.1485, 60)
            a.box("DialMarks", "bakelite_black", (x, y, 0.0502), (0.0022, 0.015, 0.0008), rz, tint=INK)
    a.marks("DialMarks", "bakelite_black", 0.1485, (0.010, 0.017), (0.007, 0.017), tint=INK)
    for i, t in ((0, "12"), (3, "3"), (6, "6"), (9, "9")):
        a.numeral(t, i, 0.112, 0.040)
    a.hands("bakelite_black", ("spade", "spade"), (0.084, 0.126, 0.140), (0.024, 0.016, 0.0045), tint=INK)
    std_dial(a, 0.168, glass_z=0.050 + 0.0115)
    a.possessed = {"kind": "label", "index": 0, "text": "21",
                   "note": "the 12 at the head of the dial reads 21"}
    return a


def courier():
    a = Asm("courier", "wall", (0, 0, 0.016))
    steel = "nickel_plated"
    a.box("Case", "bakelite_black", (0, 0, 0.005), (0.070, 0.070, 0.010))                 # movement on the wall
    a.ring("Case", steel, 0.152, 0.196, 0.010, 0.014, segs=64)                            # chainring
    for i in range(32):
        ang = TAU * i / 32
        a.prism("Case", steel, [(-0.0075, 0.194), (0.0075, 0.194), (0.0030, 0.211), (-0.0030, 0.211)], 0.0105, 0.0135,
                place(0, 0, 0, ang), (0, 1, 0))
    a.disc("Case", steel, 0.040, 0.010, 0.016, segs=24)                                   # spider boss
    for i in range(5):
        ang = TAU * i / 5 + 0.2
        a.prism("Case", steel, [(-0.014, 0.030), (0.014, 0.030), (0.009, 0.158), (-0.009, 0.158)], 0.010, 0.0145,
                place(0, 0, 0, ang), (0, 1, 0))
        a.dome("Trim", "brass", 0.006, 0.003, 0.0145, -math.sin(ang) * 0.150, math.cos(ang) * 0.150, 8)
    for i in range(12):                                                                   # rivets for the hours
        if i == 10:
            continue
        x, y, _ = hour_at(i, 0.174)
        a.dome("DialMarks", "brass", 0.008 if i % 3 == 0 else 0.005, 0.003, 0.014, x, y, 10)
    x, y, _ = hour_at(10, 0.174)
    a.pivots["OddMark"] = (x, y, 0.014)
    a.dome("OddMark", "brass", 0.005, 0.003, 0.014, x, y, 10)
    a.box("Case", "enamel", (0, -0.232, 0.006), (0.30, 0.025, 0.012), tint="accent")      # V1's accent bar, on the wall
    for sx in (-1, 1):
        a.box("Case", steel, (sx * 0.10, -0.208, 0.004), (0.008, 0.030, 0.004), grain=(0, 1, 0))
    a.hands(steel, ("lance", "lance"), (0.080, 0.118, 0.132), (0.014, 0.009, 0.004))
    std_dial(a, 0.150, glass=False, tell_at=(0.120, -0.232, 0.012))
    a.possessed = {"kind": "part", "angle_deg": 300.0, "radius": 0.222, "spin_deg": 0.0,
                   "note": "the rivet at 10 stands outside the ring, past the teeth"}
    return a


def mantel():
    hd = 0.128                                                                # dial centre above the shelf
    a = Asm("mantel", "table", (0, hd, 0.058))
    outline = [(-0.235, 0.030)] + [(x / 100.0, 0.070 + 0.150 * math.exp(-((x / 100.0) / 0.108) ** 2))
                                   for x in range(-23, 24)] + [(0.235, 0.030)]
    outline = [(-0.235, 0.030)] + [(max(-0.235, min(0.235, x)), y) for x, y in outline[1:-1]] + [(0.235, 0.030)]
    a.prism("Case", "wood_dark", list(reversed(outline)), -0.055, 0.055, grain=(1, 0, 0))
    a.box("Case", "wood_dark", (0, 0.021, 0), (0.50, 0.018, 0.130), tint="b9a48f")       # plinth
    for sx in (-1, 1):
        for sz in (-1, 1):
            a.lathe("Trim", "brass", [(0, 0.0), (0.012, 0.0), (0.016, 0.005), (0.013, 0.012), (0, 0.012)],
                    m=place(sx * 0.215, 0, sz * 0.045) @ AXY, segs=12)
    a.disc("Case", "iron_blackened", 0.070, 0.0548, 0.0562, cy=hd)                        # the socket behind the dial
    a.disc("Dial", "porcelain", 0.068, 0.0562, 0.058, cy=hd, tint="f0e8d2")
    a.bezel("Trim", "brass", 0.070, 0.011, 0.055, 0.016, cy=hd)
    a.marks("DialMarks", "bakelite_black", 0.057, (0.004, 0.010), (0.003, 0.009), skip=(0, 3, 6, 9), tint=INK)
    for i, t in ((0, "XII"), (3, "III"), (6, "VI"), (9, "IX")):
        a.numeral(t, i, 0.054, 0.014)
    a.hands("bakelite_black", ("spade", "lance"), (0.034, 0.052, 0.058), (0.010, 0.006, 0.002), tint=INK)
    a.tell(0, hd - 0.046, 0.058, 0.004)
    a.glass(0.070, 0.058 + 0.0105, cy=hd)
    a.reading(0, hd - 0.002, 0.058 + 0.0135, 0.016)
    a.possessed = {"kind": "label", "index": 3, "text": "XI",
                   "note": "the IX reads XI"}
    return a


def travel_alarm():
    a = Asm("travel_alarm", "table", (0, 0.068, 0.0165))
    w, h = 0.150, 0.118
    a.box("Case", "leather_worn", (0, 0.006 + h / 2, 0.0), (w + 0.012, h + 0.012, 0.022))             # the case half it sits in
    a.box("Trim", "nickel_plated", (0, 0.006 + h / 2, 0.0125), (w, h, 0.005))                         # nickel front
    a.box("Dial", "bakelite_black", (0, 0.068, 0.0155), (w - 0.022, h - 0.040, 0.002))                # black dial plate
    a.box("Trim", "nickel_plated", (0, 0.068 + (h - 0.040) / 2 + 0.003, 0.0160), (w - 0.016, 0.006, 0.003))
    a.box("Trim", "nickel_plated", (0, 0.068 - (h - 0.040) / 2 - 0.003, 0.0160), (w - 0.016, 0.006, 0.003))
    for sx in (-1, 1):
        a.box("Trim", "nickel_plated", (sx * ((w - 0.022) / 2 + 0.003), 0.068, 0.0160), (0.006, h - 0.028, 0.003), grain=(0, 1, 0))
    for sx in (-1, 1):                                                                                # alarm and time set
        a.disc("Trim", "nickel_plated", 0.007, 0.0, 0.010, m=place(sx * 0.045, 0.006 + h + 0.006, 0.0) @ AXY, segs=12)
    a.box("Case", "leather_worn", (0, 0.004, -0.062), (w + 0.012, 0.008, 0.112))                       # lid lying open behind
    a.disc("Trim", "nickel_plated", 0.005, -(w / 2), w / 2, m=place(0, 0.006, -0.011) @ AXX, segs=10)   # hinge barrel
    a.prism("Trim", "nickel_plated", [(-0.004, 0.0), (0.004, 0.0), (0.004, 0.125), (-0.004, 0.125)], -0.0015, 0.0015,
            place(0, 0.008, -0.105) @ Matrix.Rotation(math.radians(48.8), 4, "X"), (0, 1, 0))           # prop stay, lid to back
    a.tell(0.052, 0.036, 0.0165, 0.004)
    a.reading(0, 0.068, 0.0180, 0.026, FONT_SANS)
    return a


def architect():
    a = Asm("architect", "wall", (0, 0, 0.058))
    for sx in (-1, 1):
        for sy in (-1, 1):
            x, y = sx * 0.135, sy * 0.135
            a.disc("Posts", "brass", 0.008, 0.0, 0.060, x, y, 12)                          # standoffs to the wall
            a.disc("Posts", "brass", 0.015, 0.0, 0.003, x, y, 14)
            a.dome("Posts", "brass", 0.010, 0.004, 0.060, x, y, 10)
    plate = "nickel_plated"
    a.ring("Case", plate, 0.108, 0.166, 0.055, 0.058, segs=64)                             # chapter ring
    for i in range(4):
        ang = TAU * i / 4 + TAU / 8
        a.prism("Case", plate, [(-0.011, 0.160), (0.011, 0.160), (0.011, 0.202), (-0.011, 0.202)], 0.055, 0.058,
                place(0, 0, 0, ang), (0, 1, 0))
    for z0, z1 in ((0.012, 0.015), (0.040, 0.043)):                                        # movement plates
        a.box("Works", "brass", (0, 0, (z0 + z1) / 2), (0.092, 0.110, z1 - z0), grain=(0, 1, 0))
    for sx in (-1, 1):
        for sy in (-1, 1):
            a.disc("Works", "brass", 0.004, 0.0, 0.043, sx * 0.038, sy * 0.046, 8)        # pillars, to the wall
    for cx, cy, r, teeth, z in ((0.0, 0.0, 0.034, 30, 0.024), (0.030, 0.036, 0.022, 20, 0.028), (-0.028, 0.030, 0.026, 24, 0.032),
                                (0.0, -0.048, 0.030, 28, 0.020)):
        prof = []
        for t in range(teeth * 2):
            ang = TAU * t / (teeth * 2)
            rr = r if t % 2 == 0 else r * 0.90
            prof.append((cx + math.cos(ang) * rr, cy + math.sin(ang) * rr))
        a.prism("Works", "brass", prof, z, z + 0.002)
    a.disc("Works", "brass", 0.004, 0.012, 0.058, 0, 0, 10)                                # centre arbor
    for i in range(12):
        x, y, rz = hour_at(i, 0.137)
        if i == 3:
            continue
        if i % 3 == 0:                                                                     # drafting-triangle markers
            a.prism("DialMarks", "enamel", [(-0.011, 0.012), (0.011, 0.012), (0.0, -0.016)], 0.058, 0.0596,
                    place(x, y, 0, rz), (0, 1, 0), "accent")
        else:
            a.box("DialMarks", "bakelite_black", (x, y, 0.0586), (0.004, 0.016, 0.0012), rz, tint=INK)
    x, y, rz = hour_at(3, 0.137)
    a.pivots["OddMark"] = (x, y, 0.058)
    a.prism("OddMark", "enamel", [(-0.011, 0.012), (0.011, 0.012), (0.0, -0.016)], 0.058, 0.0596, place(x, y, 0, rz),
            (0, 1, 0), "accent")
    # A set square, hung from the lower right standoff (V1's one accent bar).
    sq = [(0.0, 0.0), (0.110, 0.0), (0.0, 0.064)]
    inner = [(0.012, 0.010), (0.082, 0.010), (0.012, 0.050)]
    for (p0, p1), (q0, q1) in zip(zip(sq, sq[1:] + sq[:1]), zip(inner, inner[1:] + inner[:1])):
        a.prism("Trim", "enamel", [p0, p1, q1, q0], 0.046, 0.048, place(0.1032, -0.1905, 0, -0.52), (1, 0, 0), "accent")
    a.hands(plate, ("lance", "lance"), (0.080, 0.118, 0.132), (0.010, 0.007, 0.0035))
    std_dial(a, 0.150, glass=False, tell_at=(0.0, -0.118, 0.058))
    a.possessed = {"kind": "part", "angle_deg": 90.0, "radius": 0.137, "spin_deg": 180.0,
                   "note": "the triangle at 3 points outward, away from the arbor"}
    return a


def split_flap():
    a = Asm("split_flap", "wall", (0, 0, 0.060))
    body = "d6ccb0"
    instrument_case(a, "enamel", 0.42, 0.22, 0.066, body, 0.016)
    a.box("Case", "bakelite_black", (0, 0.004, 0.0665), (0.34, 0.136, 0.003))             # window surround
    a.box("Dial", "bakelite_black", (0, 0.034, 0.0690), (0.320, 0.058, 0.004), tint="26241f")   # upper leaves
    a.box("Dial", "bakelite_black", (0, -0.026, 0.0685), (0.320, 0.058, 0.004), tint="26241f")  # lower leaves
    for j in range(4):                                                                    # the pack of waiting leaves
        a.box("Dial", "bakelite_black", (0, 0.065 + j * 0.0012, 0.0680 - j * 0.0008), (0.318, 0.0010, 0.004), tint="3a362e")
    a.box("Trim", "nickel_plated", (0, 0.004, 0.0705), (0.330, 0.0025, 0.004))            # the split
    for sx in (-1, 1):
        a.disc("Trim", "nickel_plated", 0.034, 0.0, 0.006, m=place(sx * 0.166, 0.004, 0.058) @ AXX, segs=20)   # drum cheeks
        a.box("Trim", "nickel_plated", (sx * 0.187, 0.004, 0.0672), (0.020, 0.150, 0.0025), grain=(0, 1, 0))
    a.box("Case", "enamel", (0, -0.096, 0.040), (0.30, 0.020, 0.068), tint="968f7b")      # V1's base bar, as a sill
    conduit(a, 0.150, -0.11, -0.20)
    a.tell(-0.186, -0.084, 0.066, 0.005)
    a.reading(0, 0.003, 0.0735, 0.052)
    return a


def palette():
    a = Asm("palette", "wall", (0, 0, 0.030))
    a.box("Case", "bakelite_black", (0, 0, 0.011), (0.080, 0.080, 0.022))                  # movement, on the wall
    out = []
    for i in range(72):                                                                   # the kidney outline
        t = TAU * i / 72
        r = 1.0 - 0.16 * math.exp(-((t - 5.55) / 0.33) ** 2)
        out.append((0.232 * r * math.cos(t) + 0.012, 0.188 * r * math.sin(t)))
    hole = [(0.128 + 0.021 * math.cos(-TAU * i / 16 + 0.9), -0.086 + 0.016 * math.sin(-TAU * i / 16 + 0.9)) for i in range(17)]
    # Cut the thumb hole with a slit from the rim so the board stays one outline.
    k = min(range(72), key=lambda i: (out[i][0] - hole[0][0]) ** 2 + (out[i][1] - hole[0][1]) ** 2)
    board = out[:k + 1] + hole + out[k:]
    a.prism("Case", "plywood", board, 0.022, 0.030, tint="e8c9a0")
    for i in range(12):                                                                   # paint for the hours
        if i == 8:
            continue
        x, y, _ = hour_at(i, 0.140)
        a.lathe("DialMarks", "enamel", [(0, 0.030), (0.013 if i % 3 == 0 else 0.009, 0.030), (0.008 if i % 3 == 0 else 0.005, 0.0335),
                                        (0, 0.0345)], x, y, 10, tint="accent")
    x, y, _ = hour_at(8, 0.140)
    a.pivots["OddMark"] = (x, y, 0.030)
    a.lathe("OddMark", "enamel", [(0, 0.030), (0.009, 0.030), (0.005, 0.0335), (0, 0.0345)], x, y, 10, tint="accent")
    a.lathe("Trim", "enamel", [(0, 0.030), (0.030, 0.030), (0.022, 0.033), (0, 0.034)], -0.165, 0.030, 14, tint="ecebe4")  # mixed white
    a.hands("brass_dull", ("lance", "lance"), (0.080, 0.118, 0.132), (0.012, 0.008, 0.0035))
    std_dial(a, 0.150, glass=False)
    a.possessed = {"kind": "part", "angle_deg": 255.0, "radius": 0.118, "spin_deg": 0.0,
                   "note": "the paint for 8 has run to half past, in toward the middle"}
    return a


def nixie():
    a = Asm("nixie", "wall", (0, 0, 0.060))
    body = "17191b"
    instrument_case(a, "bakelite_black", 0.42, 0.22, 0.012, body, 0.014)                   # back
    for sy in (-1, 1):                                                                    # top and bottom walls
        a.box("Case", "bakelite_black", (0, sy * 0.090, 0.040), (0.40, 0.040, 0.060), tint=body)
    for sx in (-1, 1):
        a.box("Case", "bakelite_black", (sx * 0.190, 0, 0.040), (0.040, 0.21, 0.060), tint=body, grain=(0, 1, 0))
    a.box("Trim", "nickel_plated", (0, 0.072, 0.0705), (0.345, 0.004, 0.003))             # aperture frame
    a.box("Trim", "nickel_plated", (0, -0.072, 0.0705), (0.345, 0.004, 0.003))
    for sx in (-1, 1):
        a.box("Trim", "nickel_plated", (sx * 0.1725, 0, 0.0705), (0.004, 0.148, 0.003), grain=(0, 1, 0))
    for nx in (-0.115, -0.038, 0.038, 0.115):                                             # four cathode tubes
        prof = [(0, 0.0), (0.024, 0.0), (0.026, 0.010), (0.026, 0.092), (0.020, 0.106), (0.008, 0.112), (0, 0.118)]
        a.lathe("Dial", "mica_heater", prof, m=place(nx, -0.062, 0.038) @ AXY, segs=16, tint="7a3d1c")
        a.disc("Trim", "nickel_plated", 0.027, 0.0, 0.008, m=place(nx, -0.070, 0.038) @ AXY, segs=16)
    for j in range(7):                                                                    # ventilation slots
        a.box("Trim", "iron_blackened", (-0.09 + j * 0.03, 0.1101, 0.040), (0.016, 0.001, 0.036))
    conduit(a, 0.0, -0.11, -0.20)
    a.box("Glass", "glassish", (0, 0, 0.0698), (0.341, 0.140, 0.0015))                    # smoked aperture
    a.tell(0.186, -0.092, 0.070, 0.005)
    a.reading(0, -0.002, 0.0672, 0.060)
    return a


def writer():
    a = Asm("writer", "wall", (0, 0, 0.060))
    body = "1c1c1e"
    instrument_case(a, "enamel", 0.42, 0.22, 0.030, body, 0.014)
    a.box("Case", "enamel", (0, -0.070, 0.048), (0.40, 0.070, 0.040), tint=body)          # key bank
    a.disc("Platen", "rubber_aged", 0.030, -0.180, 0.180, m=place(0, 0.030, 0.058) @ AXX, segs=24)
    for sx in (-1, 1):                                                                    # platen knobs
        a.disc("Trim", "bakelite_black", 0.032, 0.0, 0.026, m=place(sx * 0.199 if sx > 0 else -0.225, 0.030, 0.058) @ AXX, segs=20)
        a.box("Case", "enamel", (sx * 0.186, 0.030, 0.045), (0.010, 0.080, 0.036), tint=body, grain=(0, 1, 0))
    a.box("Dial", "paper", (0, 0.062, 0.0885), (0.300, 0.118, 0.0012))                    # the sheet in the machine
    a.disc("Trim", "nickel_plated", 0.004, -0.170, 0.170, m=place(0, 0.022, 0.0915) @ AXX, segs=8)   # paper bail
    for sx in (-0.10, 0.10):
        a.disc("Trim", "rubber_aged", 0.008, -0.010, 0.010, m=place(sx, 0.022, 0.0915) @ AXX, segs=12)
    for j in range(9):                                                                    # a row of key tops
        x = -0.160 + j * 0.040
        a.disc("Trim", "nickel_plated", 0.013, 0.068, 0.074, x, -0.070, 14)
        a.disc("Keys", "bakelite_black", 0.0105, 0.074, 0.0755, x, -0.070, 14)
    a.tell(0.176, -0.070, 0.068, 0.005)
    a.reading(0, 0.066, 0.0902, 0.052, FONT_TYPE)
    return a


def deco():
    a = Asm("deco", "wall", (0, 0, 0.046))
    body = "1e3330"

    def stepped(w, h, step):
        return [(-w / 2, -h / 2), (w / 2, -h / 2), (w / 2, h / 2 - 2 * step), (w / 2 - step, h / 2 - 2 * step),
                (w / 2 - step, h / 2 - step), (w / 2 - 2 * step, h / 2 - step), (w / 2 - 2 * step, h / 2),
                (-w / 2 + 2 * step, h / 2), (-w / 2 + 2 * step, h / 2 - step), (-w / 2 + step, h / 2 - step),
                (-w / 2 + step, h / 2 - 2 * step), (-w / 2, h / 2 - 2 * step)]
    a.prism("Case", "enamel", stepped(0.44, 0.34, 0.035), 0.0, 0.014, tint=body)
    a.prism("Case", "enamel", stepped(0.37, 0.39, 0.030), 0.014, 0.028, tint=body)
    a.can("Case", "enamel", 0.150, 0.044, 0.004, tint=body, z0=0.028)
    for sx in (-1, 1):                                                                    # V1's two fins
        for j, hgt in enumerate((0.28, 0.22, 0.16)):
            top = 0.046 - j * 0.008
            a.box("Trim", "enamel", (sx * (0.172 + j * 0.016), -0.015 - j * 0.012, (0.014 + top) / 2),
                  (0.012, hgt, top - 0.014), grain=(0, 1, 0), tint="accent")
    a.disc("Dial", "porcelain", 0.128, 0.044, 0.046, tint="efe7d0")
    a.lathe("Trim", "chrome", [(0.128, 0.044), (0.146, 0.044), (0.146, 0.054), (0.140, 0.054), (0.140, 0.060),
                               (0.134, 0.060), (0.134, 0.064), (0.128, 0.064)], segs=56)
    for i in range(12):
        x, y, rz = hour_at(i, 0.106)
        if i % 3 == 0:
            a.prism("DialMarks", "bakelite_black", [(-0.009, -0.014), (0.009, -0.014), (0.009, 0.0), (0.005, 0.0), (0.005, 0.014),
                                                    (-0.005, 0.014), (-0.005, 0.0), (-0.009, 0.0)], 0.0457, 0.0469,
                    place(x, y, 0, rz), (0, 1, 0), INK)
        else:
            a.box("DialMarks", "bakelite_black", (x, y, 0.0463), (0.005, 0.014, 0.0012), rz, tint=INK)
    a.hands("bakelite_black", ("lozenge", "lozenge"), (0.066, 0.098, 0.110), (0.016, 0.011, 0.0035), tint=INK)
    std_dial(a, 0.128)
    return a


# ---------------------------------------------------------------------------
# The two honest clocks (clock_prop.gd): sizes are V1's.
# ---------------------------------------------------------------------------
def drop_octagon():
    a = Asm("drop_octagon", "wall", (0, 0, 0.070))
    octagon_case(a, 0.224, 0.082, "oak_quartered", 0.160, "c29e75")
    a.disc("Case", "wood_dark", 0.162 / math.cos(math.pi / 8), 0.0, 0.068, segs=8, phase=math.pi / 8)
    drop_case(a, "oak_quartered", "wood_dark", 0.225, -0.205, -0.520, 0.082, (0.150, 0.230), False, "c29e75")
    a.box("Case", "brass", (0, 0.240, 0.0015), (0.036, 0.06, 0.003))                       # hanger plate on the wall
    a.disc("Dial", "paper", 0.158, 0.068, 0.070)
    a.bezel("Trim", "brass", 0.158, 0.014, 0.068, 0.020)
    a.ring("DialMarks", "bakelite_black", 0.148, 0.1495, 0.0698, 0.0706, tint=INK)
    a.ring("DialMarks", "bakelite_black", 0.134, 0.1352, 0.0698, 0.0706, tint=INK)
    for i in range(60):
        x, y, rz = hour_at(i, 0.1415, 60)
        a.box("DialMarks", "bakelite_black", (x, y, 0.0702), (0.004 if i % 5 == 0 else 0.0016, 0.012, 0.0008), rz, tint=INK)
    for kx in (-0.046, 0.046):                                                            # time and strike arbors
        a.ring("Trim", "brass", 0.006, 0.011, 0.070, 0.0715, kx, -0.040, 14)
        a.disc("DialMarks", "bakelite_black", 0.006, 0.0698, 0.0704, kx, -0.040, 10, tint=INK)
    roman = ["XII", "I", "II", "III", "IIII", "V", "VI", "VII", "VIII", "IX", "X", "XI"]
    for i, t in enumerate(roman):
        a.numeral(t, i, 0.112, 0.024)
    a.pivots["Pendulum"] = (0, -0.205, 0.045)
    a.box("Pendulum", "brass", (0, -0.205 - 0.112, 0.045), (0.009, 0.255, 0.004), grain=(0, 1, 0))
    a.lathe("Pendulum", "brass", [(0, 0.040), (0.046, 0.042), (0.051, 0.046), (0.046, 0.050), (0, 0.052)], 0, -0.205 - 0.225, 28)
    a.hands("bakelite_black", ("spade", "spade"), (0.083, 0.122, 0.136), (0.022, 0.014, 0.004), second_tint="611310", tint=INK)
    a.glass(0.158, 0.070 + 0.0115)
    a.extra = {"winding_reach": [-0.046, -0.040, 0.10]}
    return a


def vantry_master():
    a = Asm("vantry_master", "wall", (0, 0, 0.072))
    a.can("Case", "bakelite_black", 0.235, 0.070, 0.014, tint="6e6152", segs=56)
    a.ring("Case", "bakelite_black", 0.225, 0.246, 0.0, 0.012, tint="6e6152", segs=56)      # wall flange
    a.disc("Dial", "enamel", 0.202, 0.070, 0.072, tint="e4e4da", segs=56)
    a.bezel("Trim", "brass", 0.202, 0.016, 0.070, 0.021, segs=56)
    for i in range(4):                                                                    # bezel screws
        x, y, _ = hour_at(i + 0.5, 0.2105, 4)
        a.dome("Trim2", "nickel_plated", 0.006, 0.003, 0.0908, x, y, 8)
    a.ring("DialMarks", "bakelite_black", 0.190, 0.192, 0.0718, 0.0726, tint=INK, segs=56)
    for i in range(60):
        x, y, rz = hour_at(i, 0.181, 60)
        a.box("DialMarks", "bakelite_black", (x, y, 0.0722), (0.007 if i % 5 == 0 else 0.002, 0.018 if i % 5 == 0 else 0.012, 0.0008), rz, tint=INK)
    for i in range(12):
        a.numeral(str(12 if i == 0 else i), i, 0.145, 0.036, FONT_SANS)
    # The sealed setting cover, on a boss under the drum; the line comes in above.
    a.box("Case", "bakelite_black", (0, -0.250, 0.030), (0.090, 0.050, 0.060), tint="6e6152")
    a.pivots["Cover"] = (0, -0.250, 0.0625)
    a.box("Cover", "brass", (0, -0.250, 0.0625), (0.064, 0.030, 0.005))
    for sx in (-1, 1):
        a.dome("Cover", "brass", 0.004, 0.002, 0.065, sx * 0.024, -0.250, 8)
    conduit(a, 0.0, 0.230, 0.345)
    a.hands("bakelite_black", ("baton", "baton"), (0.108, 0.154, 0.172), (0.016, 0.011, 0.004), second_tint="611310", tint=INK)
    a.glass(0.202, 0.072 + 0.0115, segs=56)
    return a


BUILDERS = [schoolhouse, hospital, bauhaus, stitch, vantry_modular, sunray_1920, industrial, studio, railway, courier,
            mantel, travel_alarm, architect, split_flap, palette, nixie, writer, deco, drop_octagon, vantry_master]


# ---------------------------------------------------------------------------
def to_blender(v):
    return Vector((v[0], -v[2], v[1]))


_preview = {}


def preview_material(key, tint, accent):
    name = "%s|%s" % (key, tint or "")
    if name not in _preview:
        m = bpy.data.materials.new(name)
        m.use_nodes = True
        b = m.node_tree.nodes["Principled BSDF"]
        col = PREVIEW[key]
        if tint:
            hexv = accent if tint == "accent" else tint
            t = [int(hexv[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
            col = tuple((c ** 2.2) for c in t) if key in ("enamel", "linen", "bakelite_black", "paper", "porcelain", "plywood") \
                else tuple(a * (c ** 2.2) * 2.0 for a, c in zip(col, t))
        b.inputs["Base Color"].default_value = (*col, 1)
        b.inputs["Roughness"].default_value = 0.35 if key in ("brass", "chrome", "nickel_plated", "enamel", "porcelain") else 0.6
        b.inputs["Metallic"].default_value = 1.0 if key in ("brass", "brass_dull", "chrome", "nickel_plated") else 0.0
        if key == "glassish":
            b.inputs["Transmission Weight"].default_value = 1.0
            b.inputs["Roughness"].default_value = 0.02
        _preview[name] = m
    return _preview[name]


ACCENTS = {"schoolhouse": "8e2f38", "hospital": "a9d5c9", "bauhaus": "d6a62e", "stitch": "a43d5d", "vantry_modular": "7656a8",
           "sunray_1920": "78935a", "industrial": "b5533c", "studio": "a75a91", "railway": "d0b777", "courier": "d16b39",
           "mantel": "806a52", "travel_alarm": "d4a742", "architect": "d4b92c", "split_flap": "d48631", "palette": "e05f61",
           "nixie": "d84b3f", "writer": "786b59", "deco": "6b8b79", "drop_octagon": "611310", "vantry_master": "611310"}


def finalize(asm, origin):
    empty = bpy.data.objects.new("WC_" + asm.style, None)
    empty.location = origin
    bpy.context.collection.objects.link(empty)
    rows, objs, lo, hi, tris_total = [], [], Vector((1e9,) * 3), Vector((-1e9,) * 3), 0
    for comp, key in asm.order:
        bm = asm.buckets[(comp, key)]
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        grain = bm.faces.layers.float_vector["grain"]
        uv = bm.loops.layers.uv.new("UVMap")
        for f in bm.faces:
            n = f.normal
            g = Vector(f[grain])
            if g.length < 0.5 or abs(n.dot(g)) > 0.92:
                g = min((Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))), key=lambda ax: abs(n.dot(ax)))
            u = (g - n * n.dot(g)).normalized()
            v = n.cross(u)
            for loop in f.loops:
                loop[uv].uv = (loop.vert.co.dot(u), loop.vert.co.dot(v))
            f.smooth = True
        for e in bm.edges:
            e.smooth = len(e.link_faces) == 2 and e.calc_face_angle(0.0) < math.radians(38)
        bmesh.ops.triangulate(bm, faces=bm.faces)
        dead = [f for f in bm.faces if f.calc_area() < 1e-11]
        if dead:
            bmesh.ops.delete(bm, geom=dead, context="FACES_ONLY")
        pivot = Vector(asm.pivots.get(comp, (0, 0, 0))) if comp in MOVING else Vector((0, 0, 0))
        for v in bm.verts:
            lo = Vector([min(lo[i], v.co[i]) for i in range(3)])
            hi = Vector([max(hi[i], v.co[i]) for i in range(3)])
            v.co = to_blender(v.co - pivot)
        name = "WC_%s__%s_ON_%s" % (asm.style, comp, key)
        mesh = bpy.data.meshes.new(name)
        bm.to_mesh(mesh)
        tris = len(bm.faces)
        bm.free()
        obj = bpy.data.objects.new(name, mesh)
        obj.parent = empty
        obj.location = to_blender(pivot)
        tint = asm.tints.get((comp, key))
        mesh.materials.append(preview_material(key, tint, ACCENTS[asm.style]))
        bpy.context.collection.objects.link(obj)
        objs.append(obj)
        tris_total += tris
        row = {"name": name, "component": comp, "material": key, "triangles": tris,
               "rig": "face" if (comp in FACE_RIG or comp.startswith("Dial")) else "case", "moving": comp in MOVING}
        if tint:
            row["tint"] = tint
        rows.append(row)
    spec = {"root": empty.name, "mounting": asm.mounting, "dial_center": [round(c, 5) for c in asm.dial],
            "bounds": [[round(c, 4) for c in lo], [round(c, 4) for c in hi]], "triangles": tris_total, "parts": rows,
            "labels": asm.labels, "display": asm.display}
    if asm.possessed:
        spec["possessed"] = asm.possessed
    spec.update(asm.extra)
    return empty, objs, spec


def review_text(empty, spec, accent):
    """Review-only stand-ins for the runtime's Label3D numerals (never exported)."""
    out = []
    for lab in spec["labels"]:
        curve = bpy.data.curves.new("txt", "FONT")
        curve.font = bpy.data.fonts.load(str(ROOT / "game" / lab["font"].replace("res://", "")), check_existing=True)
        curve.body = lab["text"]
        curve.align_x, curve.align_y = "CENTER", "CENTER"
        curve.size = lab["height"] * 1.25
        o = bpy.data.objects.new("ReviewText", curve)
        o.parent = empty
        o.location = to_blender(lab["at"])
        o.rotation_euler = (math.pi / 2, 0, 0)
        m = bpy.data.materials.get("review_ink") or bpy.data.materials.new("review_ink")
        m.diffuse_color = (0.02, 0.02, 0.02, 1)
        curve.materials.append(m)
        bpy.context.collection.objects.link(o)
        out.append(o)
    return out


def render_reviews(empties, specs, extras):
    scene = bpy.context.scene
    try:
        scene.render.engine = "CYCLES"
        scene.cycles.samples = 24
        scene.cycles.use_denoising = True
    except Exception:
        scene.render.engine = "BLENDER_EEVEE"
    world = bpy.data.worlds.new("w")
    scene.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.55, 0.52, 0.48, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.6
    wall_mat = bpy.data.materials.new("review_wall")
    wall_mat.use_nodes = True
    wall_mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.62, 0.56, 0.46, 1)
    made = []
    bpy.ops.mesh.primitive_plane_add(size=1)
    wall = bpy.context.object
    wall.scale = (6.0, 5.0, 1)
    wall.rotation_euler = (math.pi / 2, 0, 0)
    wall.location = (1.6, 0.001, -1.2)
    wall.data.materials.append(wall_mat)
    made.append(wall)
    for e, s in zip(empties, specs):
        if s["mounting"] == "table":                                         # a review shelf
            bpy.ops.mesh.primitive_cube_add(size=1)
            shelf = bpy.context.object
            shelf.scale = (0.62, 0.24, 0.02)
            shelf.location = (e.location.x, e.location.y - 0.0, e.location.z - 0.0101)
            shelf.data.materials.append(wall_mat)
            made.append(shelf)
    bpy.ops.object.light_add(type="SUN", location=(0, -3, 3))
    sun = bpy.context.object
    sun.data.energy = 3.0
    sun.rotation_euler = (math.radians(58), 0, math.radians(-28))
    made.append(sun)
    bpy.ops.object.camera_add()
    cam = bpy.context.object
    scene.camera = cam
    made.append(cam)
    (OUT / "review").mkdir(exist_ok=True)
    scene.render.resolution_x, scene.render.resolution_y = 2400, 620
    cam.data.type = "ORTHO"
    for row in range(4):
        cam.data.ortho_scale = 4.1
        cam.location = (1.64, -3.0, -row * 0.9 - 0.06)
        cam.rotation_euler = (math.pi / 2, 0, 0)
        scene.render.filepath = str(OUT / "review" / ("sheet_row%d.png" % row))
        bpy.ops.render.render(write_still=True)
    # Raking three-quarter views, to read depth, backs and wall contact.
    cam.data.type = "PERSP"
    cam.data.lens = 50
    scene.render.resolution_x, scene.render.resolution_y = 2400, 700
    for row in range(4):
        cam.location = (1.64 + 2.4, -3.3, -row * 0.9 + 0.5)
        cam.rotation_euler = (math.radians(80), 0, math.radians(36))
        scene.render.filepath = str(OUT / "review" / ("rake_row%d.png" % row))
        bpy.ops.render.render(write_still=True)
    for o in made + extras:
        bpy.data.objects.remove(o)


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.preferences.filepaths.save_version = 0
    empties, parts, specs, styles, extras = [], [], [], {}, []
    for i, build in enumerate(BUILDERS):
        asm = build()
        table = asm.mounting == "table"
        origin = Vector(((i % 5) * 0.82, 0.0 if not table else -0.10, -(i // 5) * 0.9 - (0.18 if table else 0.0)))
        empty, objs, spec = finalize(asm, origin)
        empties.append(empty)
        parts += objs
        specs.append(spec)
        styles[asm.style] = spec
        extras += review_text(empty, spec, ACCENTS[asm.style])
    bpy.context.view_layer.update()
    render_reviews(empties, specs, extras)
    blend = ROOT / "art/blender/witness_clocks.blend"
    bpy.ops.wm.save_as_mainfile(filepath=str(blend), check_existing=False)
    bpy.ops.object.select_all(action="DESELECT")
    for o in empties + parts:
        o.select_set(True)
    asset = ROOT / "game/assets/props/witness_clocks.glb"
    bpy.ops.export_scene.gltf(filepath=str(asset), export_format="GLB", use_selection=True, export_yup=True,
                              export_apply=True, export_normals=True, export_tangents=True, export_texcoords=True,
                              export_materials="EXPORT", export_animations=False, export_cameras=False,
                              export_lights=False)
    data = {"schema_version": 1, "asset": "res://assets/props/witness_clocks.glb",
            "frame": "x right, y up, z out of the dial; wall clocks: origin is the dial centre on the wall plane; "
                     "table clocks: origin is the footprint centre on the surface",
            "uv": "metres; the runtime keeps each catalogue material's own metres-per-tile",
            "styles": styles}
    (ROOT / "game/data/orison_v2/witness_clocks.json").write_text(json.dumps(data, indent=1) + "\n", encoding="utf-8", newline="\n")
    total = sum(s["triangles"] for s in specs)
    draws = sum(len(s["parts"]) for s in specs)
    print("[WITNESS CLOCKS] %d assemblies, %d mesh parts, %d triangles" % (len(specs), draws, total))
    for s in specs:
        print("  %-16s %2d parts %5d tris bounds %s" % (s["root"], len(s["parts"]), s["triangles"], s["bounds"]))


main()
