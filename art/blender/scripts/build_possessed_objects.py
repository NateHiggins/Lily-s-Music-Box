"""The possessed household objects V2 had no counterpart for, authored in Blender.

V1 drew these from BoxMesh/CylinderMesh stand-ins (possessed_domestic_prop.gd),
several of them objects 1929 did not have (an answering machine, a thermostat
with a lit readout, a digital scale). V2 keeps V1's rows, owners, tells and
inspection copy and replaces what is seen with period objects: a hall mirror on
its wire, a house telephone, a coat rail, a wall receptacle with a pilot jewel,
a candlestick telephone, a lever thermostat, a door chain, a brass spring
balance, a wooden spirit level, an upright typewriter and a key bowl. The part
each tell moves is its own mesh on its true pivot.

No numerals are modelled or textured (RUL-008): the builder writes where each
Label3D numeral goes and the runtime letters it.

Object frame (what the runtime sees, Godot axes): +X right, +Y up, +Z out of
the wall or toward the user. A wall object's origin is on the wall plane
(z = 0). A table object's origin is its footprint centre on the support
(y = 0). Blender is Z-up; the builder works in the object frame and converts
once. UVs are metres along the stock.

Deterministic: no randomness.

  blender -b --python-exit-code 1 -P art/blender/scripts/build_possessed_objects.py -- <review_dir>
Writes game/assets/props/possessed_objects.glb, art/blender/possessed_objects.blend,
game/data/orison_v2/possessed_object_stock.json and review renders under <review_dir>.
"""
import bpy, bmesh, json, math, sys
from mathutils import Vector, Matrix
from pathlib import Path

ROOT = next(p for p in Path(__file__).resolve().parents if (p / "game/project.godot").is_file())
OUT = Path(sys.argv[sys.argv.index("--") + 1]) if "--" in sys.argv else ROOT / "tmp/possessed_objects"
OUT.mkdir(parents=True, exist_ok=True)
TAU = math.tau
AXY = Matrix.Rotation(-math.pi / 2, 4, "X")  # a lathe's Z axis stood up along +Y
AXX = Matrix.Rotation(math.pi / 2, 4, "Y")   # a lathe's Z axis laid along +X
INK = "1a1612"
# Review-only colours for the catalogue keys (the runtime binds the real maps).
PREVIEW = {
    "oak_quartered": (0.42, 0.27, 0.13), "wood_dark": (0.17, 0.10, 0.055), "brass": (0.72, 0.55, 0.22),
    "brass_dull": (0.52, 0.42, 0.22), "nickel_plated": (0.70, 0.70, 0.67), "cast_iron": (0.10, 0.10, 0.10),
    "iron_blackened": (0.05, 0.05, 0.055), "enamel": (0.85, 0.85, 0.80), "bakelite_black": (0.03, 0.028, 0.026),
    "paper": (0.86, 0.82, 0.70), "porcelain": (0.92, 0.91, 0.87), "linen": (0.78, 0.74, 0.64),
    "milk_glass": (0.90, 0.88, 0.80), "rubber_aged": (0.06, 0.06, 0.06), "mirror_aged": (0.62, 0.68, 0.70),
}
TINTED_FLAT = ("enamel", "linen", "bakelite_black", "paper", "porcelain", "milk_glass")


def place(x=0.0, y=0.0, z=0.0, rz=0.0):
    return Matrix.Translation((x, y, z)) @ Matrix.Rotation(rz, 4, "Z")


def rot(axis, angle):
    return Matrix.Rotation(angle, 4, axis)


def box_geo(sx, sy, sz):
    x, y, z = sx / 2, sy / 2, sz / 2
    v = [(-x, -y, -z), (x, -y, -z), (x, y, -z), (-x, y, -z), (-x, -y, z), (x, -y, z), (x, y, z), (-x, y, z)]
    return v, [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]


def prism_geo(pts, z0, z1):
    n = len(pts)
    v = [(x, y, z0) for x, y in pts] + [(x, y, z1) for x, y in pts]
    f = [tuple(range(n - 1, -1, -1)), tuple(range(n, 2 * n))]
    return v, f + [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]


def lathe_geo(profile, segs=24, phase=0.0):
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
            if len(q) >= 3:
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


def rounded(w, h, r, n=3):
    """A rectangle with rounded corners, counter-clockwise."""
    x, y = w / 2 - r, h / 2 - r
    pts = []
    for cx, cy, a0 in ((x, y, 0.0), (-x, y, math.pi / 2), (-x, -y, math.pi), (x, -y, math.pi * 1.5)):
        pts += arc(cx, cy, r, a0, a0 + math.pi / 2, n)
    return pts


def torus_profile(big, small, n=6):
    return [(big + small * math.cos(TAU * i / n), small * math.sin(TAU * i / n)) for i in range(n)]


class Asm:
    def __init__(self, kind, mounting):
        self.kind, self.mounting = kind, mounting
        self.buckets, self.order = {}, []
        self.pivots, self.tints, self.labels = {}, {}, []

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
        rm = m.to_3x3() if m is not None else None
        bv = [bm.verts.new(m @ Vector(v) if m is not None else Vector(v)) for v in verts]
        g = Vector(grain)
        if rm is not None:
            g = (rm @ g).normalized()
        for idx in faces:
            try:
                made = bm.faces.new([bv[i] for i in idx])
            except ValueError:
                continue
            made[layer] = g

    def box(self, comp, key, at, size, rz=0.0, grain=None, tint=None, m=None):
        if grain is None:
            grain = [(1, 0, 0), (0, 1, 0), (0, 0, 1)][max(range(3), key=lambda i: size[i])]
        mm = place(at[0], at[1], at[2], rz)
        self.emit(comp, key, box_geo(*size), (m @ mm) if m is not None else mm, grain, tint)

    def prism(self, comp, key, pts, z0, z1, m=None, grain=(1, 0, 0), tint=None):
        self.emit(comp, key, prism_geo(pts, z0, z1), m, grain, tint)

    def turn(self, comp, key, profile, at=(0.0, 0.0, 0.0), axis="z", segs=24, tint=None, m=None, grain=(1, 0, 0)):
        """A lathe whose profile heights run along `axis` from `at`."""
        mm = place(*at) @ {"z": Matrix.Identity(4), "y": AXY, "x": AXX}[axis]
        self.emit(comp, key, lathe_geo(profile, segs), (m @ mm) if m is not None else mm, grain, tint)

    def disc(self, comp, key, r, h0, h1, at=(0.0, 0.0, 0.0), axis="z", segs=16, tint=None, m=None):
        self.turn(comp, key, [(0, h0), (r, h0), (r, h1), (0, h1)], at, axis, segs, tint, m)

    def ring(self, comp, key, r0, r1, h0, h1, at=(0.0, 0.0, 0.0), axis="z", segs=24, tint=None, m=None):
        self.turn(comp, key, [(r0, h0), (r1, h0), (r1, h1), (r0, h1)], at, axis, segs, tint, m)

    def dome(self, comp, key, r, h, at=(0.0, 0.0, 0.0), axis="z", segs=10, tint=None, m=None):
        prof = [(0, 0)] + [(r * math.cos(t * math.pi / 6), h * math.sin(t * math.pi / 6)) for t in range(3)] + [(0, h)]
        self.turn(comp, key, prof, at, axis, segs, tint, m)

    def tube(self, comp, key, pts, r, segs=6, tint=None, m=None):
        self.emit(comp, key, tube_geo(pts, r, segs), m, (0, 1, 0), tint)

    def screw(self, comp, key, x, y, z, r=0.0035):
        self.dome(comp, key, r, r * 0.5, (x, y, z), "z", 8)

    def numeral(self, text, x, y, z, height, color=INK):
        self.labels.append({"text": text, "at": [round(x, 5), round(y, 5), round(z, 5)], "height": height,
                            "color": color})


# ---------------------------------------------------------------------------
def hall_mirror():
    """A framed looking-glass hung by its wire from one nail: it can hang crooked."""
    a = Asm("hall_mirror", "wall")
    nail = (0.0, 0.395, 0.0)
    a.disc("Body", "iron_blackened", 0.0022, 0.0, 0.014, nail, "z", 8)
    a.dome("Body", "iron_blackened", 0.0045, 0.002, (0.0, 0.395, 0.014), "z", 8)
    a.pivots["Mirror"] = (0.0, 0.395, 0.010)
    m = "Mirror"
    a.box(m, "wood_dark", (0, 0, 0.0075), (0.41, 0.61, 0.005), grain=(0, 1, 0))            # backing board
    for sy in (-1, 1):
        a.box(m, "wood_dark", (0, sy * 0.295, 0.019), (0.44, 0.05, 0.022))                # rails
        a.box(m, "wood_dark", (0, sy * 0.313, 0.033), (0.44, 0.014, 0.006))               # raised outer lip
        a.box(m, "brass_dull", (0, sy * 0.2675, 0.0225), (0.351, 0.005, 0.015))           # gilt sight edge
    for sx in (-1, 1):
        a.box(m, "wood_dark", (sx * 0.195, 0, 0.019), (0.05, 0.54, 0.022), grain=(0, 1, 0))  # stiles
        a.box(m, "wood_dark", (sx * 0.213, 0, 0.033), (0.014, 0.612, 0.006), grain=(0, 1, 0))
        a.box(m, "brass_dull", (sx * 0.173, 0, 0.0225), (0.005, 0.53, 0.015), grain=(0, 1, 0))
        a.disc(m, "rubber_aged", 0.008, 0.0005, 0.005, (sx * 0.17, -0.30, 0.0), "z", 8)   # bumpers on the wall
    a.box(m, "mirror_aged", (0, 0, 0.0125), (0.345, 0.535, 0.005), grain=(0, 1, 0))       # the glass
    a.tube(m, "brass_dull", [(-0.15, 0.296, 0.0035), (0.0, 0.3935, 0.0105), (0.15, 0.296, 0.0035)], 0.0011, 4)
    return a


def receiver(a, comp, at, key="bakelite_black"):
    """A long-pole receiver hanging cap upward by its shoulder; `at` is the fork."""
    a.turn(comp, key, [(0, -0.115), (0.009, -0.115), (0.011, -0.100), (0.0135, 0.0), (0.016, 0.008), (0.028, 0.012),
                       (0.029, 0.028), (0.024, 0.034), (0, 0.034)], at, "y", 14)


def house_telephone():
    """The flat's house telephone (V1's 'intercom'): call button, transmitter, receiver on its hook."""
    a = Asm("house_telephone", "wall")
    c = 0.012
    w, h = 0.17, 0.30
    board = [(-w / 2 + c, -h / 2), (w / 2 - c, -h / 2), (w / 2, -h / 2 + c), (w / 2, h / 2 - c), (w / 2 - c, h / 2),
             (-w / 2 + c, h / 2), (-w / 2, h / 2 - c), (-w / 2, -h / 2 + c)]
    a.prism("Body", "oak_quartered", board, 0.0, 0.018, grain=(0, 1, 0))
    a.box("Body", "oak_quartered", (0, 0, 0.0205), (w - 0.03, h - 0.03, 0.005), grain=(0, 1, 0))
    for sx, sy in ((-1, -1), (1, -1), (-1, 1), (1, 1)):
        a.screw("Body", "brass", sx * 0.072, sy * 0.137, 0.018)
    # call button
    a.ring("Body", "brass", 0.008, 0.015, 0.023, 0.028, (0, 0.105, 0), "z", 16)
    a.dome("Body", "porcelain", 0.0075, 0.004, (0, 0.105, 0.027), "z", 10)
    # transmitter on its arm
    a.box("Body", "iron_blackened", (0, 0.0, 0.05), (0.032, 0.032, 0.056))
    a.turn("Body", "bakelite_black", [(0, 0.074), (0.030, 0.074), (0.037, 0.080), (0.037, 0.090), (0.033, 0.094),
                                      (0.016, 0.094), (0.027, 0.124), (0.0245, 0.124), (0.011, 0.098), (0, 0.098)],
           (0, 0, 0), "z", 20)
    a.ring("Body", "brass", 0.037, 0.040, 0.082, 0.089, (0, 0, 0), "z", 20)
    # switch hook: a boss on the board, an arm and a fork holding the receiver's neck
    fx, fy, fz = -0.130, 0.045, 0.046
    a.box("Body", "brass", (-0.079, fy, 0.027), (0.02, 0.034, 0.012))
    a.box("Body", "brass", (-0.099, fy, 0.036), (0.034, 0.005, 0.008))
    a.box("Body", "brass", (-0.1135, fy, fz), (0.005, 0.005, 0.036))
    for sz in (-1, 1):
        a.box("Body", "brass", (fx, fy, fz + sz * 0.0155), (0.034, 0.005, 0.005))
    a.pivots["Receiver"] = (fx, fy, fz)
    receiver(a, "Receiver", (fx, fy, fz))
    loop = [(fx, fy - 0.112, fz), (fx - 0.002, fy - 0.150, fz - 0.002), (fx + 0.001, fy - 0.185, fz - 0.007),
            (fx + 0.010, fy - 0.205, fz - 0.012), (fx + 0.021, fy - 0.207, fz - 0.017), (fx + 0.031, fy - 0.190, fz - 0.022),
            (fx + 0.038, fy - 0.150, fz - 0.027), (fx + 0.042, fy - 0.090, fz - 0.031), (-0.087, 0.02, 0.011)]
    a.tube("Receiver", "linen", loop, 0.0026, 5, tint="3a2a1c")
    a.disc("Body", "brass", 0.006, 0.0, 0.004, (-0.089, 0.02, 0.009), "x", 8)                 # cord grommet
    return a


def coat_hooks():
    """A coat rail of three cast hooks, with the screw holes of a fourth."""
    a = Asm("coat_hooks", "wall")
    a.prism("Body", "oak_quartered", rounded(0.48, 0.085, 0.012), 0.0, 0.020)
    a.box("Body", "oak_quartered", (0, 0, 0.0225), (0.452, 0.06, 0.005))
    for sx in (-1, 1):
        a.screw("Body", "brass", sx * 0.228, 0.0, 0.020, 0.004)

    def hook(comp, x):
        a.prism(comp, "brass", [(x + px, py) for px, py in rounded(0.022, 0.066, 0.008, 2)], 0.025, 0.029, grain=(0, 1, 0))
        a.tube(comp, "brass", [(x, -0.012, 0.028), (x, -0.030, 0.050), (x, -0.030, 0.078), (x, -0.012, 0.096),
                               (x, 0.004, 0.100)], 0.005, 6)
        a.dome(comp, "brass", 0.0075, 0.007, (x, 0.004, 0.097), "y", 8)
        a.tube(comp, "brass", [(x, 0.012, 0.028), (x, 0.026, 0.046), (x, 0.046, 0.056)], 0.0045, 6)
        a.dome(comp, "brass", 0.007, 0.006, (x, 0.044, 0.056), "y", 8)
        for sy in (-1, 1):
            a.screw(comp, "brass", x, sy * 0.025, 0.029, 0.0028)

    for x in (-0.165, -0.055, 0.055):
        hook("Body", x)
    for sy in (-1, 1):                                                                   # the vacant place
        a.disc("Body", "iron_blackened", 0.0018, 0.0245, 0.0253, (0.165, sy * 0.025, 0), "z", 6)
    a.pivots["ExtraHook"] = (0.165, 0.0, 0.025)
    hook("ExtraHook", 0.165)
    return a


def receptacle():
    """A brass flush plate with a porcelain two-point receptacle and a pilot jewel."""
    a = Asm("receptacle", "wall")
    a.prism("Body", "brass", rounded(0.072, 0.115, 0.006, 2), 0.0, 0.004, grain=(0, 1, 0))
    a.prism("Body", "brass", rounded(0.060, 0.103, 0.004, 2), 0.004, 0.0058, grain=(0, 1, 0))
    for sy in (-1, 1):
        a.screw("Body", "brass", 0.0, sy * 0.0465, 0.0058, 0.003)
    a.disc("Body", "porcelain", 0.020, 0.0058, 0.0095, (0, -0.012, 0), "z", 20)
    for sx in (-1, 1):
        a.box("Body", "bakelite_black", (sx * 0.0065, -0.012, 0.0096), (0.0022, 0.0095, 0.0006))
    a.ring("Body", "brass", 0.0055, 0.009, 0.0058, 0.0095, (0, 0.028, 0), "z", 14)
    a.pivots["Indicator"] = (0.0, 0.028, 0.008)
    a.dome("Indicator", "milk_glass", 0.0058, 0.0042, (0, 0.028, 0.008), "z", 10, tint="7a1414")
    return a


def telephone():
    """A candlestick desk stand: receiver on its switch hook, cord to the base."""
    a = Asm("telephone", "table")
    a.turn("Body", "bakelite_black", [(0, 0), (0.068, 0), (0.070, 0.004), (0.066, 0.012), (0.040, 0.022), (0.022, 0.030),
                                      (0.017, 0.036), (0.017, 0.222), (0, 0.222)], (0, 0, 0), "y", 24)
    a.ring("Body", "brass", 0.0165, 0.0205, 0.036, 0.043, (0, 0, 0), "y", 16)
    a.ring("Body", "brass", 0.0165, 0.0205, 0.212, 0.222, (0, 0, 0), "y", 16)
    a.box("Body", "brass", (0, 0.232, 0.0), (0.024, 0.024, 0.02))                          # yoke
    head = place(0, 0.258, 0.004) @ rot("X", math.radians(-15))
    a.turn("Body", "bakelite_black", [(0, -0.022), (0.030, -0.022), (0.037, -0.010), (0.037, 0.010), (0.033, 0.014),
                                      (0.016, 0.014), (0.027, 0.044), (0.0245, 0.044), (0.011, 0.018), (0, 0.018)],
           (0, 0, 0), "z", 20, m=head)
    a.ring("Body", "brass", 0.037, 0.040, 0.002, 0.009, (0, 0, 0), "z", 20, m=head)
    # switch hook
    hx, hy = -0.085, 0.185
    a.pivots["Hook"] = (-0.017, hy, 0.0)
    a.box("Hook", "brass", (-0.044, hy, 0.0), (0.054, 0.005, 0.008))
    a.box("Hook", "brass", (-0.0685, hy, 0.0), (0.005, 0.005, 0.036))
    for sz in (-1, 1):
        a.box("Hook", "brass", (hx, hy, sz * 0.0155), (0.034, 0.005, 0.005))
    a.pivots["Receiver"] = (hx, hy, 0.0)
    receiver(a, "Receiver", (hx, hy, 0.0))
    # cord: a short run on the table into the base, and the drop the runtime stretches when the receiver lifts
    a.tube("Body", "linen", [(hx, 0.013, 0.0), (hx + 0.003, 0.005, 0.0), (-0.064, 0.005, 0.0)], 0.0026, 5, tint="3a2a1c")
    a.pivots["CordDrop"] = (hx, 0.012, 0.0)
    a.tube("CordDrop", "linen", [(hx, 0.012, 0.0), (hx, 0.045, 0.0), (hx, 0.075, 0.0)], 0.0026, 5, tint="3a2a1c")
    return a


def thermostat():
    """A lever thermostat: thermometer above, a setting pointer on a graduated arc below."""
    a = Asm("thermostat", "wall")
    a.box("Body", "bakelite_black", (0, -0.004, 0.003), (0.064, 0.142, 0.006))
    cover = [(-0.028, -0.066), (0.028, -0.066)] + arc(0.0, 0.040, 0.028, 0.0, math.pi, 8)
    a.prism("Body", "brass", cover, 0.006, 0.024, grain=(0, 1, 0))
    for sx in (-1, 1):
        a.screw("Body", "brass", sx * 0.021, -0.058, 0.024, 0.0025)
    # thermometer
    a.box("Body", "porcelain", (0, 0.028, 0.0245), (0.016, 0.056, 0.001), grain=(0, 1, 0))
    a.box("Mercury", "enamel", (0, 0.018, 0.0253), (0.0018, 0.03, 0.0006), tint="9a1616")
    a.disc("Mercury", "enamel", 0.0024, 0.025, 0.0258, (0, 0.003, 0), "z", 8, tint="9a1616")
    for i in range(7):
        a.box("Body", "bakelite_black", (0.0048, 0.008 + i * 0.007, 0.0252), (0.0034 if i % 3 == 0 else 0.0022, 0.0007, 0.0005))
    # setting scale: 55 on the left stop, 85 on the right
    px, py = 0.0, -0.054
    a.box("Body", "porcelain", (0, -0.034, 0.0245), (0.052, 0.038, 0.001))
    for i in range(13):
        ang = math.radians(-45 + i * 7.5)
        ln = 0.005 if i % 2 == 0 else 0.003
        r = 0.0225 + ln / 2
        a.box("Body", "bakelite_black", (px + math.sin(ang) * r, py + math.cos(ang) * r, 0.0252), (0.0007, ln, 0.0005), -ang)
    for text, deg in (("55", -45), ("70", 0), ("85", 45)):
        ang = math.radians(deg)
        a.numeral(text, px + math.sin(ang) * 0.0325, py + math.cos(ang) * 0.0325 - (0.002 if deg == 0 else 0.0), 0.0252, 0.0042)
    rest = math.radians(-45 + (72 - 55) / 30 * 90)                                          # V1's reading: 72
    a.pivots["Pointer"] = (px, py, 0.0262)
    a.prism("Pointer", "iron_blackened", [(-0.0016, -0.004), (0.0016, -0.004), (0.0006, 0.026), (-0.0006, 0.026)],
            0.0258, 0.0266, m=place(px, py) @ rot("Z", -rest) , grain=(0, 1, 0))
    a.disc("Pointer", "iron_blackened", 0.004, 0.0256, 0.0276, (px, py, 0), "z", 10)
    return a


def door_chain():
    """The jamb plate of a chain door fastening, its chain hanging free from the staple."""
    a = Asm("door_chain", "wall")
    a.prism("Body", "brass", rounded(0.028, 0.085, 0.006, 2), 0.0, 0.004, grain=(0, 1, 0))
    for sy in (-1, 1):
        a.screw("Body", "brass", 0.0, sy * 0.032, 0.004, 0.003)
    a.tube("Body", "brass", [(0, 0.014, 0.003), (0, 0.014, 0.014), (0, 0.006, 0.0195), (0, -0.002, 0.014), (0, -0.002, 0.003)],
           0.0022, 6)
    pivot = (0.0, 0.006, 0.0155)
    a.pivots["Chain"] = pivot
    links = 9
    for i in range(links):
        cy = pivot[1] - 0.0105 - i * 0.0165
        m = place(0, cy, pivot[2]) @ Matrix.Diagonal((1.0, 1.55, 1.0, 1.0))
        if i % 2 == 1:
            m = m @ AXX
        a.turn("Chain", "brass", torus_profile(0.0058, 0.0016, 5), (0, 0, 0), "z", 8, m=m)
    end = pivot[1] - 0.0105 - links * 0.0165 + 0.004
    a.turn("Chain", "brass", [(0, -0.004), (0.003, -0.004), (0.003, 0.004), (0.008, 0.004), (0.008, 0.008), (0, 0.008)],
           (0, end - 0.004, pivot[2]), "z", 10)
    return a


def luggage_scale():
    """A brass spring balance hung on an iron hook: graduated chart, index pointer, load hook."""
    a = Asm("luggage_scale", "wall")
    a.box("Body", "cast_iron", (0, 0.0, 0.002), (0.022, 0.052, 0.004))
    a.tube("Body", "cast_iron", [(0, 0.0, 0.003), (0, -0.004, 0.018), (0, -0.007, 0.030), (0, 0.002, 0.040), (0, 0.010, 0.043)],
           0.0032, 6)
    for sy in (-1, 1):
        a.screw("Body", "cast_iron", 0.0, sy * 0.019, 0.004, 0.003)
    z = 0.030
    a.turn("Body", "brass", torus_profile(0.011, 0.0023, 6), (0, -0.0125, z), "z", 14)        # hanging ring, on the hook
    a.box("Body", "brass", (0, -0.034, z), (0.008, 0.018, 0.004))
    top, bottom = -0.042, -0.242
    a.prism("Body", "brass", [(px, (top + bottom) / 2 + py) for px, py in rounded(0.042, top - bottom, 0.006, 2)],
            z - 0.005, z + 0.005, grain=(0, 1, 0))
    a.box("Body", "bakelite_black", (0, -0.139, z + 0.0052), (0.0065, 0.172, 0.0006), grain=(0, 1, 0))  # the slot
    zero, step = -0.062, 0.0076
    for i in range(21):
        ln = 0.0085 if i % 5 == 0 else 0.0045
        for sx in (-1, 1):
            if sx == 1 and i % 10 == 0:
                continue                                                               # a numeral stands here
            a.box("Body", "bakelite_black", (sx * (0.0048 + ln / 2), zero - i * step, z + 0.0052), (ln, 0.0008, 0.0005))
    for text, i in (("0", 0), ("25", 10), ("50", 20)):
        a.numeral(text, 0.0125, zero - i * step, z + 0.0056, 0.0055)
    a.pivots["Pointer"] = (0.0, zero, z)
    a.box("Pointer", "iron_blackened", (0, zero, z + 0.0062), (0.021, 0.0026, 0.0012))
    a.disc("Pointer", "brass", 0.0028, bottom - 0.035, bottom + 0.165, (0, 0, z), "y", 8)      # drawbar, long inside the case
    a.tube("Pointer", "brass", [(0, bottom - 0.034, z), (0, bottom - 0.048, z), (0.012, bottom - 0.062, z),
                                (0.004, bottom - 0.080, z), (-0.012, bottom - 0.070, z)], 0.0026, 6)
    return a


def spirit_level():
    """A brass-bound wooden level standing on its edge, vial uppermost."""
    a = Asm("spirit_level", "table")
    a.box("Body", "wood_dark", (0, 0.0275, 0), (0.50, 0.055, 0.030))
    for sx in (-1, 1):
        a.box("Body", "brass", (sx * 0.2512, 0.0275, 0), (0.0024, 0.056, 0.031))
    a.box("Body", "brass", (0, 0.0557, 0), (0.13, 0.0016, 0.022))
    for sx in (-1, 1):
        a.dome("Body", "brass", 0.0025, 0.0012, (sx * 0.055, 0.0565, 0), "y", 8)
    liquid = "b9c860"
    a.turn("Body", "milk_glass", [(0, -0.026), (0.004, -0.026), (0.0052, -0.021), (0.0052, 0.021), (0.004, 0.026), (0, 0.026)],
           (0, 0.0545, 0), "x", 10, tint=liquid)
    for sx in (-1, 1):
        a.ring("Marks", "bakelite_black", 0.0050, 0.0056, -0.0004, 0.0004, (sx * 0.0085, 0.0545, 0), "x", 10, tint=INK)
    a.ring("Body", "brass", 0.009, 0.013, 0.015, 0.0165, (0.17, 0.0275, 0), "z", 16)           # plumb porthole
    a.disc("Body", "milk_glass", 0.009, 0.0148, 0.0156, (0.17, 0.0275, 0), "z", 12, tint=liquid)
    a.pivots["Bubble"] = (0.0, 0.0584, 0.0)
    a.turn("Bubble", "porcelain", [(0, -0.0065), (0.0018, -0.0065), (0.003, -0.004), (0.003, 0.004), (0.0018, 0.0065),
                                   (0, 0.0065)], (0, 0.0580, 0), "x", 8, tint="f4f7e4")
    return a


def typewriter():
    """A front-strike upright: frame, four banks of keys, type basket, and the carriage on its rail."""
    a = Asm("typewriter", "table")
    black = "0e0e0e"
    foot = 0.006
    side = [(-0.15, foot), (0.15, foot), (0.15, 0.036), (0.03, 0.086), (0.03, 0.126), (-0.15, 0.126)]   # (z, y)
    mside = Matrix(((0, 0, 1, 0), (0, 1, 0, 0), (1, 0, 0, 0), (0, 0, 0, 1)))                # prism x->z, z->x
    a.prism("Body", "enamel", side, -0.14, 0.14, m=mside, tint=black)
    for sx in (-1, 1):
        for sz in (-1, 1):
            a.disc("Body", "bakelite_black", 0.012, 0.0, foot, (sx * 0.12, 0, sz * 0.125), "y", 8)
    # keys: four banks on the sloped deck
    for row in range(4):
        t = 0.14 + row * 0.24
        kz = 0.15 - t * 0.12
        ky = 0.036 + t * 0.05 + 0.011
        for i in range(10):
            kx = -0.1125 + i * 0.025 + (row % 2) * 0.008 - 0.004
            a.box("Body", "nickel_plated", (kx, ky - 0.006, kz), (0.003, 0.012, 0.003), grain=(0, 1, 0))
            a.disc("Body", "nickel_plated", 0.0088, 0.0, 0.004, (kx, ky, kz), "y", 6)
            a.disc("Body", "bakelite_black", 0.0066, 0.004, 0.0048, (kx, ky, kz), "y", 6)
    a.box("Body", "bakelite_black", (0, 0.047, 0.146), (0.19, 0.006, 0.013))                 # space bar
    for sx in (-1, 1):
        a.box("Body", "nickel_plated", (sx * 0.08, 0.040, 0.146), (0.004, 0.012, 0.004))
    # type basket: a nickel segment and the resting type bars
    seg = arc(0.0, 0.0, 0.078, 0.0, math.pi, 12) + list(reversed(arc(0.0, 0.0, 0.062, 0.0, math.pi, 12)))
    flat = place(0, 0.126, -0.058) @ rot("X", math.pi / 2)                                    # prism (x, y) -> (x, z), z -> up
    a.prism("Body", "nickel_plated", seg, -0.007, 0.0, m=flat)
    for i in range(15):
        ang = math.pi * (i + 0.5) / 15
        a.box("Body", "bakelite_black", (0.040, 0, 0), (0.040, 0.003, 0.0025),
              m=place(0, 0.1285, -0.058) @ rot("Y", -ang))
    for sx in (-1, 1):                                                                      # ribbon spools
        a.disc("Body", "nickel_plated", 0.029, 0.126, 0.129, (sx * 0.112, 0, -0.035), "y", 14)
        a.disc("Body", "bakelite_black", 0.024, 0.129, 0.138, (sx * 0.112, 0, -0.035), "y", 14)
        a.disc("Body", "nickel_plated", 0.029, 0.138, 0.140, (sx * 0.112, 0, -0.035), "y", 14)
    # the carriage
    c = "Carriage"
    cy, cz = 0.172, -0.095
    a.pivots[c] = (0.0, 0.136, cz)
    a.box(c, "enamel", (0, 0.136, cz), (0.33, 0.02, 0.075), tint=black)
    for sx in (-1, 1):
        a.box(c, "enamel", (sx * 0.150, 0.166, cz), (0.006, 0.062, 0.062), tint=black)
        a.disc(c, "rubber_aged", 0.023, 0.153, 0.166, (0, cy, cz), "x", 14, m=Matrix.Diagonal((sx, 1, 1, 1)))
    a.disc(c, "rubber_aged", 0.021, -0.147, 0.147, (0, cy, cz), "x", 16)                      # platen
    a.disc(c, "nickel_plated", 0.0025, -0.135, 0.135, (0, cy + 0.022, cz + 0.02), "x", 6)     # paper bail
    for sx in (-1, 1):
        a.box(c, "nickel_plated", (sx * 0.135, cy + 0.011, cz + 0.02), (0.003, 0.024, 0.004))
    sheet = place(0, cy, cz) @ rot("X", math.radians(-12))
    a.box(c, "paper", (0, 0.112, -0.021), (0.215, 0.18, 0.0008), grain=(0, 1, 0), m=sheet)    # the page in the machine
    a.box(c, "enamel", (0, 0.062, -0.026), (0.25, 0.085, 0.002), grain=(1, 0, 0), m=sheet, tint=black)   # paper table
    a.tube(c, "nickel_plated", [(-0.153, cy + 0.01, cz + 0.02), (-0.185, cy + 0.02, cz + 0.05), (-0.195, cy + 0.02, cz + 0.085)],
           0.003, 6)
    a.dome(c, "nickel_plated", 0.006, 0.005, (-0.195, cy + 0.02, cz + 0.083), "z", 8)
    return a


def key_bowl():
    """A turned bowl for the household keys; one more key than there should be."""
    a = Asm("key_bowl", "table")
    a.turn("Body", "wood_dark", [(0, 0), (0.05, 0), (0.056, 0.004), (0.096, 0.030), (0.110, 0.046), (0.106, 0.048),
                                 (0.090, 0.036), (0.05, 0.012), (0, 0.009)], (0, 0, 0), "y", 24)

    def key(comp, mat, m, long=0.058, bow=0.0085):
        a.turn(comp, mat, torus_profile(bow, 0.0019, 5), (0, 0, 0), "y", 10, m=m)
        a.box(comp, mat, (bow + long / 2 - 0.001, 0, 0), (long, 0.0032, 0.0032), m=m)
        a.box(comp, mat, (bow + long - 0.006, 0, 0.0055), (0.009, 0.002, 0.009), m=m)
        a.box(comp, mat, (bow + 0.004, 0, 0), (0.003, 0.005, 0.005), m=m)

    tilt = math.radians(17)
    for ang, lift in ((0.5, 0.0), (2.5, 0.004), (4.3, 0.008)):
        key("Body", "brass", rot("Y", ang) @ place(0.014, 0.0145 + lift, 0) @ rot("Z", tilt))
    a.pivots["ExtraKey"] = (0.0, 0.03, 0.0)
    key("ExtraKey", "nickel_plated", rot("Y", 5.55) @ place(0.012, 0.0175, 0) @ rot("Z", math.radians(19)), 0.068, 0.0105)
    return a


BUILDERS = [hall_mirror, house_telephone, coat_hooks, receptacle, telephone, thermostat, door_chain, luggage_scale,
            spirit_level, typewriter, key_bowl]


# ---------------------------------------------------------------------------
def to_blender(v):
    return Vector((v[0], -v[2], v[1]))


_preview = {}


def preview_material(key, tint):
    name = "%s|%s" % (key, tint or "")
    if name not in _preview:
        m = bpy.data.materials.new(name)
        m.use_nodes = True
        b = m.node_tree.nodes["Principled BSDF"]
        col = PREVIEW[key]
        if tint:
            t = [int(tint[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
            col = tuple((c ** 2.2) for c in t) if key in TINTED_FLAT else tuple(a * (c ** 2.2) * 2.0 for a, c in zip(col, t))
        b.inputs["Base Color"].default_value = (*col, 1)
        b.inputs["Roughness"].default_value = 0.3 if key in ("brass", "nickel_plated", "enamel", "porcelain", "mirror_aged",
                                                             "bakelite_black") else 0.6
        b.inputs["Metallic"].default_value = 1.0 if key in ("brass", "brass_dull", "nickel_plated", "mirror_aged") else 0.0
        _preview[name] = m
    return _preview[name]


def finalize(asm, origin):
    empty = bpy.data.objects.new("PO_" + asm.kind, None)
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
        moving = comp in asm.pivots
        pivot = Vector(asm.pivots[comp]) if moving else Vector((0, 0, 0))
        for v in bm.verts:
            lo = Vector([min(lo[i], v.co[i]) for i in range(3)])
            hi = Vector([max(hi[i], v.co[i]) for i in range(3)])
            v.co = to_blender(v.co - pivot)
        name = "PO_%s__%s_ON_%s" % (asm.kind, comp, key)
        mesh = bpy.data.meshes.new(name)
        bm.to_mesh(mesh)
        tris = len(bm.faces)
        bm.free()
        obj = bpy.data.objects.new(name, mesh)
        obj.parent = empty
        obj.location = to_blender(pivot)
        tint = asm.tints.get((comp, key), "")
        mesh.materials.append(preview_material(key, tint))
        bpy.context.collection.objects.link(obj)
        objs.append(obj)
        tris_total += tris
        rows.append({"name": name, "component": comp, "material": key, "tint": tint, "moving": moving})
    spec = {"id": asm.kind, "root": empty.name, "mounting": asm.mounting,
            "bounds": [[round(c, 4) for c in lo], [round(c, 4) for c in hi]], "parts": rows, "labels": asm.labels}
    return empty, objs, spec, tris_total


def render_reviews(empties, specs):
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
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.7
    wall_mat = bpy.data.materials.new("review_wall")
    wall_mat.use_nodes = True
    wall_mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.62, 0.56, 0.46, 1)
    made = []
    bpy.ops.mesh.primitive_plane_add(size=1)
    wall = bpy.context.object
    wall.scale = (12.0, 4.0, 1)
    wall.rotation_euler = (math.pi / 2, 0, 0)
    wall.location = (3.0, 0.001, 0.0)
    wall.data.materials.append(wall_mat)
    made.append(wall)
    for e, s in zip(empties, specs):
        if s["mounting"] == "table":                                         # a review shelf
            bpy.ops.mesh.primitive_cube_add(size=1)
            shelf = bpy.context.object
            shelf.scale = (0.56, 0.50, 0.02)
            shelf.location = (e.location.x, e.location.y + 0.02, e.location.z - 0.0101)
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
    scene.render.resolution_x, scene.render.resolution_y = 1100, 1100
    cam.data.type = "PERSP"
    cam.data.lens = 70
    for e, s in zip(empties, specs):
        lo, hi = Vector(s["bounds"][0]), Vector(s["bounds"][1])
        centre = (lo + hi) / 2
        size = max((hi - lo).length, 0.12)
        target = Vector(e.location) + to_blender(centre)
        for tag, offset in (("front", Vector((0.0, -1.0, 0.18))), ("rake", Vector((0.75, -0.8, 0.45)))):
            cam.location = target + offset.normalized() * size * 2.6
            cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
            scene.render.filepath = str(OUT / "review" / ("%s_%s.png" % (s["id"], tag)))
            bpy.ops.render.render(write_still=True)
    for o in made:
        bpy.data.objects.remove(o)


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.preferences.filepaths.save_version = 0
    empties, parts, specs, total = [], [], [], 0
    for i, build in enumerate(BUILDERS):
        asm = build()
        table = asm.mounting == "table"
        origin = Vector((i * 0.9, -0.25 if table else 0.0, -0.3 if table else 0.0))
        empty, objs, spec, tris = finalize(asm, origin)
        empties.append(empty)
        parts += objs
        specs.append(spec)
        total += tris
        print("  %-20s %2d parts %5d tris bounds %s" % (spec["root"], len(spec["parts"]), tris, spec["bounds"]))
    bpy.context.view_layer.update()
    if "--no-render" not in sys.argv:
        render_reviews(empties, specs)
    blend = ROOT / "art/blender/possessed_objects.blend"
    bpy.ops.wm.save_as_mainfile(filepath=str(blend), check_existing=False)
    bpy.ops.object.select_all(action="DESELECT")
    for o in empties + parts:
        o.select_set(True)
    asset = ROOT / "game/assets/props/possessed_objects.glb"
    bpy.ops.export_scene.gltf(filepath=str(asset), export_format="GLB", use_selection=True, export_yup=True,
                              export_apply=True, export_normals=True, export_tangents=True, export_texcoords=True,
                              export_materials="EXPORT", export_animations=False, export_cameras=False,
                              export_lights=False)
    data = {"schema_version": 1, "asset": "res://assets/props/possessed_objects.glb", "kinds": specs}
    (ROOT / "game/data/orison_v2/possessed_object_stock.json").write_text(json.dumps(data, indent=1) + "\n",
                                                                           encoding="utf-8", newline="\n")
    print("[POSSESSED OBJECTS] %d assemblies, %d mesh parts, %d triangles" % (len(specs), len(parts), total))


main()
