"""The reality-affected case props and the storage-room rule board, for V2.

V1 drew these 62 catalogue objects (game/data/reality_affected_props.json) and
the rule board as tinted BoxMesh/CylinderMesh placeholders. V2 binds its own
furnishing where a flat already holds the object; this library supplies the
kinds that have no V2 counterpart, plus the board. Each assembly is a small
object at true size, built from named stock, with metre UV charts already
divided by its catalogue material's tile, and with the few parts the
affected-state language moves kept as separate objects on their own pivots.

Deterministic: fixed seed, no clock, no randomness outside rng(). Blender is
Z-up metres with the object's front toward -Y; the glTF exporter converts to
Godot's Y-up once (front becomes +Z).

  blender -b --python-exit-code 1 -P art/blender/scripts/build_case_props.py -- <review_dir>

Writes game/assets/props/case_props.glb, art/blender/case_props.blend and
game/data/orison_v2/case_props.json; review renders go to <review_dir>.
No material or texture is exported: Godot binds catalogue materials by key.
"""
import bpy, bmesh, json, math, sys
from mathutils import Vector, Matrix, Euler
from pathlib import Path

SEED = 1928
ROOT = next(p for p in Path(__file__).resolve().parents if (p / "game/project.godot").is_file())
OUT = Path(sys.argv[sys.argv.index("--") + 1]) if "--" in sys.argv else ROOT / "case_props_review"
OUT.mkdir(parents=True, exist_ok=True)
CATALOGUE = json.loads((ROOT / "game/data/runtime_material_sets.json").read_text(encoding="utf-8"))["materials"]
TEXTURES = ROOT / "game/assets/building/textures"
# Which texture axis the grain of a wood map runs along (fabrication_grain.py).
GRAIN_AXIS = {"wood_dark": 1, "oak_quartered": 1}
TINTS = {
    "cream": (0.93, 0.87, 0.70), "manila": (0.80, 0.66, 0.42), "white": (1.0, 0.98, 0.94),
    "madder": (0.62, 0.13, 0.12), "indigo": (0.16, 0.22, 0.46), "ochre": (0.80, 0.58, 0.16),
    "viridian": (0.20, 0.50, 0.38), "sour": (0.62, 0.74, 0.20), "tape": (0.30, 0.17, 0.10),
    "canvas": (0.55, 0.50, 0.38), "ivory": (0.92, 0.88, 0.76), "black": (0.10, 0.10, 0.10),
    "oxblood": (0.42, 0.16, 0.12), "tan": (0.74, 0.52, 0.32), "grey": (0.45, 0.46, 0.46),
    "bone": (0.86, 0.80, 0.66),
}

PARTS = {}    # (assembly, component, key, tint) -> bmesh
PIVOTS = {}   # (assembly, component) -> Vector
MOTION = {}   # (assembly, component) -> {"motion": ..., "amount": ...}
ORDER = []    # assemblies in build order
INFO = {}     # assembly -> {"size": ..., "note": ...}
_current = [None]
_count = [0]


def rng(i, salt=0):
    return (math.sin(i * 12.9898 + salt * 78.233 + SEED) * 43758.5453) % 1.0


def begin(name, note=""):
    _current[0] = name
    ORDER.append(name)
    INFO[name] = {"note": note}


def pivot(component, at, motion, amount):
    """A separately exported part: its origin sits on `at`."""
    PIVOTS[(_current[0], component)] = Vector(at)
    MOTION[(_current[0], component)] = {"motion": motion, "amount": amount}


def _split(key):
    return key.split(":") if ":" in key else (key, "")


def _bm(key, comp):
    base, tint = _split(key)
    assert base in CATALOGUE, base
    assert tint == "" or tint in TINTS, tint
    slot = (_current[0], comp, base, tint)
    if slot not in PARTS:
        bm = bmesh.new()
        bm.loops.layers.uv.new("UVMap")
        PARTS[slot] = bm
    return PARTS[slot], float(CATALOGUE[base]["meters_per_tile"]), GRAIN_AXIS.get(base, 0)


def _xf(at, rot):
    return Matrix.Translation(Vector(at)) @ Euler([math.radians(a) for a in rot], "XYZ").to_matrix().to_4x4()


def _offset():
    """A whole-tile-free phase so neighbouring stock does not repeat a patch."""
    _count[0] += 1
    return Vector((rng(_count[0], 1), rng(_count[0], 2)))


def _face(bm, m, pts, uvs, smooth):
    verts = [bm.verts.new(m @ Vector(p)) for p in pts]
    _poly(bm, verts, uvs, smooth)


def _poly(bm, verts, uvs, smooth):
    try:
        f = bm.faces.new(verts)
    except ValueError:
        return
    f.smooth = smooth
    layer = bm.loops.layers.uv.active
    for loop, uv in zip(f.loops, uvs):
        loop[layer].uv = uv


def box(key, size, at=(0, 0, 0), rot=(0, 0, 0), comp="Body"):
    """A sawn or pressed stock, centred on `at`; grain along its longest side."""
    bm, tile, grain = _bm(key, comp)
    m = _xf(at, rot)
    h = [s * 0.5 for s in size]
    long_axis = max(range(3), key=lambda i: size[i])
    off = _offset()
    for axis in range(3):
        a, b = [i for i in range(3) if i != axis]
        # The stock's long side takes the texture's grain axis on this face.
        if (b == long_axis) != (grain == 1):
            ua, va = b, a
        else:
            ua, va = a, b
        for sign in (-1, 1):
            corners = []
            for sa, sb in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
                p = [0.0, 0.0, 0.0]
                p[axis] = sign * h[axis]
                p[a] = sa * h[a]
                p[b] = sb * h[b]
                corners.append(p)
            # Outward winding: a x b points along +axis only for cyclic (a, b).
            cyc = (axis + 1) % 3 == a
            if (sign > 0) != cyc:
                corners.reverse()
            uvs = [Vector((p[ua] / tile, p[va] / tile)) + off + Vector((0.37 * axis, 0.19 * sign)) for p in corners]
            _face(bm, m, corners, uvs, False)


def lathe(key, profile, at=(0, 0, 0), rot=(0, 0, 0), segs=12, comp="Body", squash=(1, 1), arc=360.0):
    """Turned or spun stock about local Z. `profile` runs (r, z[, "s"]) with
    the outside on the right of travel; "s" keeps the joint at that point smooth."""
    bm, tile, _ = _bm(key, comp)
    m = _xf(at, rot)
    off = _offset()
    full = arc >= 359.9
    cols = segs + 1
    rmax = max(p[0] for p in profile) or 0.001
    run = 0.0
    prev_top = None
    for i in range(len(profile) - 1):
        r0, z0 = profile[i][0], profile[i][1]
        r1, z1 = profile[i + 1][0], profile[i + 1][1]
        length = math.hypot(r1 - r0, z1 - z0)
        if length < 1e-9:
            continue
        flat = abs(z1 - z0) < abs(r1 - r0) * 0.6
        smooth_joint = len(profile[i]) > 2 and prev_top is not None

        def ring(r, z):
            out = []
            for j in range(cols):
                a = math.radians(arc) * j / segs
                out.append(bm.verts.new(m @ Vector((math.cos(a) * r * squash[0], math.sin(a) * r * squash[1], z))))
            return out
        bottom = prev_top if smooth_joint else ring(r0, z0)
        top = ring(r1, z1)
        for j in range(segs):
            a0 = math.radians(arc) * j / segs
            a1 = math.radians(arc) * (j + 1) / segs

            def uv(r, z, a, s):
                if flat:
                    return Vector((math.cos(a) * r / tile, math.sin(a) * r / tile)) + off
                return Vector((a * rmax / tile, s / tile)) + off
            quad = [(bottom[j], uv(r0, z0, a0, run)), (bottom[j + 1], uv(r0, z0, a1, run)),
                    (top[j + 1], uv(r1, z1, a1, run + length)), (top[j], uv(r1, z1, a0, run + length))]
            if r0 < 1e-7:
                quad = quad[1:]
            elif r1 < 1e-7:
                quad = quad[:3]
            _poly(bm, [q[0] for q in quad], [q[1] for q in quad], True)
        run += length
        prev_top = top
    if full:
        bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-7)


def tube(key, path, radius, segs=6, comp="Body", closed=False, at=(0, 0, 0), rot=(0, 0, 0)):
    """Drawn rod, wire, cord or piping swept along `path`."""
    bm, tile, _ = _bm(key, comp)
    m = _xf(at, rot)
    off = _offset()
    pts = [Vector(p) for p in path]
    n = len(pts)
    tangents = []
    for i in range(n):
        a = pts[(i - 1) % n] if (closed or i > 0) else pts[i]
        b = pts[(i + 1) % n] if (closed or i < n - 1) else pts[i]
        tangents.append((b - a).normalized())
    normal = tangents[0].orthogonal().normalized()
    rings, lengths, run = [], [], 0.0
    count = n + 1 if closed else n
    for k in range(count):
        i = k % n
        if k > 0:
            run += (pts[i] - pts[(k - 1) % n]).length
        t = tangents[i]
        normal = (normal - t * normal.dot(t)).normalized()
        binormal = t.cross(normal)
        rings.append([bm.verts.new(m @ (pts[i] + (normal * math.cos(math.tau * j / segs) + binormal * math.sin(math.tau * j / segs)) * radius))
                      for j in range(segs + 1)])
        lengths.append(run)
    for k in range(count - 1):
        for j in range(segs):
            u0, u1 = math.tau * radius * j / segs / tile, math.tau * radius * (j + 1) / segs / tile
            _poly(bm, [rings[k][j], rings[k][j + 1], rings[k + 1][j + 1], rings[k + 1][j]],
                  [Vector((u0, lengths[k] / tile)) + off, Vector((u1, lengths[k] / tile)) + off,
                   Vector((u1, lengths[k + 1] / tile)) + off, Vector((u0, lengths[k + 1] / tile)) + off], True)
    if not closed:
        for end, flip in ((0, True), (count - 1, False)):
            centre = bm.verts.new(m @ pts[end % n])
            for j in range(segs):
                tri = [centre, rings[end][j], rings[end][j + 1]]
                uvs = [Vector((0.5 * radius / tile, 0.5 * radius / tile)) + off,
                       Vector(((0.5 + 0.5 * math.cos(math.tau * j / segs)) * radius / tile, (0.5 + 0.5 * math.sin(math.tau * j / segs)) * radius / tile)) + off,
                       Vector(((0.5 + 0.5 * math.cos(math.tau * (j + 1) / segs)) * radius / tile, (0.5 + 0.5 * math.sin(math.tau * (j + 1) / segs)) * radius / tile)) + off]
                if flip:
                    tri.reverse()
                    uvs.reverse()
                _poly(bm, tri, uvs, False)
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-7)


def _area(loop):
    return 0.5 * sum(loop[i][0] * loop[(i + 1) % len(loop)][1] - loop[(i + 1) % len(loop)][0] * loop[i][1] for i in range(len(loop)))


def plate(key, outline, z0, z1, at=(0, 0, 0), rot=(0, 0, 0), comp="Body", holes=(), grain_along="x"):
    """Cut sheet or sawn board: a 2D outline (with holes) of thickness z0..z1."""
    bm, tile, grain = _bm(key, comp)
    m = _xf(at, rot)
    off = _offset()
    outer = list(outline) if _area(outline) > 0 else list(reversed(outline))
    inner = [list(h) if _area(h) < 0 else list(reversed(h)) for h in holes]
    tmp = bmesh.new()
    for loop in [outer] + inner:
        vs = [tmp.verts.new((p[0], p[1], 0)) for p in loop]
        for i in range(len(vs)):
            tmp.edges.new((vs[i], vs[(i + 1) % len(vs)]))
    bmesh.ops.triangle_fill(tmp, use_beauty=True, use_dissolve=False, edges=tmp.edges[:])
    swap = (grain_along == "x") == (grain == 1)

    def planar(p):
        return (Vector((p[1], p[0])) if swap else Vector((p[0], p[1]))) / tile + off
    for f in tmp.faces:
        tri = [v.co.copy() for v in f.verts]
        if (tri[1] - tri[0]).cross(tri[2] - tri[0]).z < 0:
            tri.reverse()
        _face(bm, m, [(p.x, p.y, z1) for p in tri], [planar(p) for p in tri], False)
        tri.reverse()
        _face(bm, m, [(p.x, p.y, z0) for p in tri], [planar(p) + Vector((0.31, 0.17)) for p in tri], False)
    tmp.free()
    for loop in [outer] + inner:
        run = 0.0
        for i in range(len(loop)):
            p, q = loop[i], loop[(i + 1) % len(loop)]
            d = math.hypot(q[0] - p[0], q[1] - p[1])
            uv = [Vector((run / tile, z0 / tile)), Vector(((run + d) / tile, z0 / tile)),
                  Vector(((run + d) / tile, z1 / tile)), Vector((run / tile, z1 / tile))]
            if swap:
                uv = [Vector((v.y, v.x)) for v in uv]
            _face(bm, m, [(p[0], p[1], z0), (q[0], q[1], z0), (q[0], q[1], z1), (p[0], p[1], z1)],
                  [v + off + Vector((0.53, 0.29)) for v in uv], False)
            run += d


def rounded(w, d, r, steps=3):
    """A rounded rectangle outline, counter-clockwise."""
    pts = []
    for cx, cy, start in ((w / 2 - r, d / 2 - r, 0), (-w / 2 + r, d / 2 - r, 90), (-w / 2 + r, -d / 2 + r, 180), (w / 2 - r, -d / 2 + r, 270)):
        for k in range(steps + 1):
            a = math.radians(start + 90 * k / steps)
            pts.append((cx + math.cos(a) * r, cy + math.sin(a) * r))
    return pts


def circle(r, n=10, at=(0, 0)):
    return [(at[0] + math.cos(math.tau * k / n) * r, at[1] + math.sin(math.tau * k / n) * r) for k in range(n)]


def dome(r, h, z=0.0, steps=4, r_inner=0.0):
    """Profile points of a quarter-ellipse rising from radius r at z to the axis."""
    pts = []
    for k in range(steps + 1):
        a = math.pi / 2 * k / steps
        pts.append((max(r_inner, r * math.cos(a)) if k < steps else r_inner, z + h * math.sin(a), "s"))
    return pts


def smooth(path, steps=4, closed=False):
    """Catmull-Rom points through `path`, for cords and straps that hang."""
    pts = [Vector(p) for p in path]
    n = len(pts)
    out = []
    for i in range(n if closed else n - 1):
        p0 = pts[(i - 1) % n] if (closed or i > 0) else pts[i]
        p1, p2 = pts[i], pts[(i + 1) % n]
        p3 = pts[(i + 2) % n] if (closed or i + 2 < n) else pts[i + 1]
        for k in range(steps):
            t = k / steps
            out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t + (-p0 + 3 * p1 - 3 * p2 + p3) * t ** 3))
    if not closed:
        out.append(pts[-1])
    return [tuple(p) for p in out]


def loop_path(rx, ry, z, n=14, wobble=0.0, salt=0):
    return [(math.cos(math.tau * k / n) * rx * (1 + wobble * (rng(k, salt) - 0.5)),
             math.sin(math.tau * k / n) * ry * (1 + wobble * (rng(k, salt + 1) - 0.5)), z) for k in range(n)]


# ---------------------------------------------------------------------------
# The library. Dimensions are metres; every assembly rests on z = 0.
# ---------------------------------------------------------------------------

def bell():
    begin("bell", "desk call bell: cast foot, spun brass gong, nickel plunger")
    lathe("cast_iron", [(0, 0), (0.050, 0), (0.050, 0.008), (0.040, 0.014), (0.012, 0.016), (0.012, 0.030), (0, 0.030)])
    lathe("brass", [(0.046, 0.018), (0.047, 0.022)] + [(0.047 * math.cos(a), 0.022 + 0.034 * math.sin(a), "s") for a in
                                                         [math.pi / 2 * k / 5 for k in range(1, 5)]] + [(0.006, 0.056, "s"), (0.006, 0.060), (0, 0.060)], segs=16)
    lathe("brass", [(0.044, 0.019), (0.012, 0.019)], segs=16)
    pivot("Plunger", (0, 0, 0.060), "bob", 0.006)
    lathe("nickel_plated", [(0.0035, 0.0), (0.0035, 0.012), (0.009, 0.012), (0.010, 0.016, "s"), (0.006, 0.020, "s"), (0, 0.020)], comp="Plunger", at=(0, 0, 0.060), segs=10)


def pager():
    begin("pager", "Vantry pocket call receiver: signal apparatus, forty years early")
    plate("bakelite_black", rounded(0.058, 0.094, 0.008), 0.0, 0.018)
    box("nickel_plated", (0.040, 0.030, 0.0012), at=(0, -0.022, 0.0186))
    for k in range(5):
        box("bakelite_black", (0.036, 0.0022, 0.0010), at=(0, -0.033 + k * 0.0055, 0.0196))
    lathe("milk_glass", [(0.007, 0.018), (0.007, 0.020), (0.004, 0.0225, "s"), (0, 0.0225)], at=(0.014, 0.030, 0), segs=10)
    lathe("brass", [(0.009, 0.018), (0.009, 0.0195), (0.007, 0.0195)], at=(0.014, 0.030, 0), segs=10)
    box("brass", (0.010, 0.060, 0.0015), at=(-0.016, 0.006, 0.0188))
    box("brass", (0.010, 0.006, 0.004), at=(-0.016, 0.036, 0.020))
    lathe("bakelite_black", [(0.005, 0), (0.005, 0.006), (0, 0.006)], at=(0.031, 0.020, 0.009), rot=(0, 90, 0), segs=8)


def notebook():
    begin("notebook", "cloth-bound manuscript book with a ribbon")
    box("book_green", (0.150, 0.210, 0.0025), at=(0, 0, 0.00125))
    box("paper", (0.142, 0.202, 0.015), at=(0.003, 0, 0.010))
    box("book_green", (0.150, 0.210, 0.0025), at=(0, 0, 0.01875))
    box("book_green", (0.0025, 0.210, 0.020), at=(-0.0762, 0, 0.010))
    box("linen:madder", (0.006, 0.050, 0.0006), at=(0.020, -0.125, 0.0006), rot=(0, 0, 8))


def pencil():
    begin("pencil", "hexagonal lacquered pencil, ferrule and rubber")
    r = 0.0037
    z = r * math.cos(math.radians(30))
    rot = (0, 90, 0)
    lathe("book_burgundy", [(r, 0.0), (r, 0.140)], at=(-0.075, 0, z), rot=rot, segs=6)
    lathe("timber", [(r, 0.0), (0.0012, 0.016)], at=(0.065, 0, z), rot=rot, segs=6)
    lathe("soot", [(0.0012, 0.0), (0, 0.005)], at=(0.081, 0, z), rot=rot, segs=6)
    lathe("brass", [(0, 0), (0.0039, 0), (0.0039, 0.012)], at=(-0.087, 0, z), rot=rot, segs=8)
    lathe("rubber_aged", [(0, 0), (0.0035, 0), (0.0035, 0.008)], at=(-0.095, 0, z), rot=rot, segs=8)


def _spool(key, at, rot=(0, 0, 0)):
    lathe("timber", [(0, 0), (0.016, 0), (0.016, 0.004), (0.007, 0.006), (0.007, 0.034), (0.016, 0.036), (0.016, 0.040), (0.004, 0.040), (0.004, 0.036)], at=at, rot=rot, segs=10)
    lathe(key, [(0.008, 0.006), (0.0135, 0.008, "s"), (0.0135, 0.032, "s"), (0.008, 0.034, "s")], at=at, rot=rot, segs=10)


def spools():
    begin("spools", "three wooden cotton reels, two standing and one rolled over")
    _spool("linen:madder", (-0.040, 0.010, 0))
    _spool("linen:indigo", (0.004, -0.014, 0))
    _spool("linen:cream", (0.050, 0.022, 0.016), rot=(90, 0, 25))
    tube("linen:cream", [(0.046, 0.004, 0.003), (0.030, -0.020, 0.001), (0.050, -0.040, 0.001), (0.075, -0.030, 0.001)], 0.0007, segs=4)


def cassette():
    begin("cassette", "sealed twin-hub signal cartridge: a cassette, forty years early")
    plate("bakelite_black", rounded(0.102, 0.064, 0.004), 0.0, 0.011, holes=[circle(0.0105, 10, (-0.021, 0.004)), circle(0.0105, 10, (0.021, 0.004))])
    box("bakelite_black", (0.070, 0.012, 0.002), at=(0, -0.025, 0.012))
    box("milk_glass", (0.030, 0.014, 0.0008), at=(0, 0.004, 0.0114))
    for sx in (-1, 1):
        for sy in (-1, 1):
            lathe("brass", [(0.0018, 0.011), (0.0018, 0.0118), (0, 0.0118)], at=(sx * 0.045, sy * 0.026, 0), segs=6)
    for name, x in (("HubA", -0.021), ("HubB", 0.021)):
        pivot(name, (x, 0.004, 0.0055), "spin", 2.4 if name == "HubA" else -2.4)
        lathe("nickel_plated", [(0, -0.005), (0.0098, -0.005), (0.0098, 0.0055), (0.0050, 0.0055), (0.0050, 0.0035), (0, 0.0035)], at=(x, 0.004, 0.0055), comp=name, segs=10)
        for k in range(3):
            a = math.radians(120 * k)
            box("nickel_plated", (0.0030, 0.0016, 0.0020), at=(x + math.cos(a) * 0.0040, 0.004 + math.sin(a) * 0.0040, 0.0100), rot=(0, 0, 120 * k), comp=name)


def tool_case():
    begin("tool_case", "japanned steel hip-roof tool box with tote tray handle")
    w, d, h = 0.46, 0.20, 0.13
    box("iron_blackened", (w, d, h), at=(0, 0, h / 2))
    # Hip lid: a trapezoid section run the length of the box.
    plate("iron_blackened", [(-d / 2, 0), (d / 2, 0), (0.045, 0.060), (-0.045, 0.060)], -w / 2, w / 2, at=(0, 0, h + 0.002), rot=(90, 0, 90))
    box("iron_blackened", (w + 0.006, d + 0.006, 0.006), at=(0, 0, h + 0.001))
    for sx in (-0.15, 0.15):
        box("brass", (0.030, 0.004, 0.036), at=(sx, -d / 2 - 0.002, h - 0.012))
        box("brass", (0.018, 0.007, 0.010), at=(sx, -d / 2 - 0.004, h + 0.002))
    for sx in (-0.085, 0.085):
        box("iron_blackened", (0.012, 0.030, 0.022), at=(sx, 0, h + 0.070))
    tube("nickel_plated", [(-0.085, 0, h + 0.078), (-0.080, 0, h + 0.104), (0.080, 0, h + 0.104), (0.085, 0, h + 0.078)], 0.006, segs=8)
    for sx in (-1, 1):
        box("iron_blackened", (0.004, d * 0.7, 0.020), at=(sx * (w / 2 + 0.002), 0, h * 0.55))
    for sx in (-0.21, 0.21):
        for sy in (-0.085, 0.085):
            lathe("iron_blackened", [(0, 0), (0.008, 0), (0.008, 0.003)], at=(sx, sy, -0.0), segs=6)


def _tag(key, at, yaw, eyelet="brass"):
    outline = [(-0.050, -0.025), (0.038, -0.025), (0.050, -0.013), (0.050, 0.013), (0.038, 0.025), (-0.050, 0.025)]
    plate(key, outline, 0.0, 0.0009, at=at, rot=(0, 0, yaw), holes=[circle(0.0028, 6, (0.040, 0))])
    m = _xf(at, (0, 0, yaw))
    c = m @ Vector((0.040, 0, 0))
    lathe(eyelet, [(0.0028, 0.0), (0.0048, 0.0), (0.0048, 0.0013), (0.0028, 0.0013)], at=(c.x, c.y, at[2]), segs=8)
    return c


def tags():
    begin("tags", "six manila string tags, tied in a loose bundle")
    ends = []
    for k in range(6):
        c = _tag("paper:manila", ((rng(k, 5) - 0.5) * 0.030, (rng(k, 6) - 0.5) * 0.030, k * 0.0011), -40 + k * 17 + rng(k, 7) * 8)
        ends.append(c)
    for k, c in enumerate(ends):
        tube("linen:cream", [(c.x, c.y, c.z + 0.001), (c.x + 0.020, c.y + 0.004 * (k - 2.5), 0.004), (0.085, 0.010 * (k - 2.5) * 0.2, 0.0012)], 0.0006, segs=4)
    tube("linen:cream", loop_path(0.006, 0.004, 0.0015, 8), 0.0008, segs=4, closed=True, at=(0.088, 0, 0))


def tape_reel():
    begin("tape_reel", "open reel of signal tape lying on its plain card box")
    box("paper:manila", (0.190, 0.190, 0.022), at=(0, 0, 0.011), rot=(0, 0, 4))
    box("paper:cream", (0.070, 0.040, 0.0006), at=(0.045, -0.060, 0.0223), rot=(0, 0, 4))
    pivot("Reel", (0, 0, 0.022), "spin", 1.6)
    z = 0.022
    for z0 in (0.0, 0.0115):
        plate("nickel_plated", circle(0.088, 20), z0, z0 + 0.0015, at=(0, 0, z), comp="Reel",
              holes=[[(math.cos(math.radians(a0 + s * 40)) * rr, math.sin(math.radians(a0 + s * 40)) * rr) for s, rr in ((0, 0.030), (1, 0.030), (1, 0.074), (0, 0.074))] for a0 in (10, 130, 250)])
    lathe("bakelite:tape", [(0.024, 0.0015), (0.064, 0.0015), (0.064, 0.0115), (0.024, 0.0115)], at=(0, 0, z), comp="Reel", segs=20)
    lathe("nickel_plated", [(0.004, 0.0015), (0.024, 0.0015), (0.024, 0.0115), (0.004, 0.0115)], at=(0, 0, z), comp="Reel", segs=12)
    tube("bakelite:tape", [(0.064, 0.0, 0.0065), (0.070, 0.030, 0.0065), (0.060, 0.072, 0.004), (0.085, 0.100, 0.0235 - z)], 0.0030, segs=4, comp="Reel", at=(0, 0, z))


def microphone():
    begin("microphone", "floor stand, ring-and-spring transmitter, cracked gauze screen")
    lathe("cast_iron", [(0, 0), (0.140, 0), (0.140, 0.012), (0.110, 0.028, "s"), (0.040, 0.040, "s"), (0.022, 0.060, "s"), (0.022, 0.080), (0, 0.080)], segs=16)
    lathe("nickel_plated", [(0.011, 0.080), (0.011, 0.860), (0.016, 0.860), (0.016, 0.900), (0.008, 0.900), (0.008, 1.300), (0, 1.300)], segs=8)
    lathe("brass", [(0.016, 0.840), (0.020, 0.848), (0.020, 0.872), (0.016, 0.880)], segs=8)
    tube("brass", [(0.020, 0, 0.860), (0.042, 0, 0.860)], 0.004, segs=6)
    zc = 1.385
    # Suspension ring, in the X-Z plane, facing the singer at -Y.
    tube("nickel_plated", [(math.cos(math.tau * k / 16) * 0.078, 0, zc + math.sin(math.tau * k / 16) * 0.078) for k in range(16)], 0.0045, segs=6, closed=True)
    tube("nickel_plated", [(0, 0, 1.300), (0, 0, zc - 0.078)], 0.006, segs=6)
    lathe("bakelite_black", [(0, -0.022), (0.036, -0.022), (0.040, -0.016, "s"), (0.040, 0.016, "s"), (0.036, 0.022, "s"), (0, 0.022)], at=(0, 0, zc), rot=(90, 0, 0), segs=12)
    lathe("brass_mesh", [(0.034, 0.0225), (0, 0.0225)], at=(0, 0, zc), rot=(90, 0, 0), segs=12)
    for k in range(4):
        a = math.radians(45 + 90 * k)
        tube("nickel_plated", [(math.cos(a) * 0.040, 0, zc + math.sin(a) * 0.040), (math.cos(a) * 0.074, 0, zc + math.sin(a) * 0.074)], 0.0022, segs=5)
    # The screen: a hoop of gauze on a bent arm, split across its lower third.
    yh = -0.105
    tube("wood_dark", [(math.cos(math.tau * k / 18) * 0.082, yh, zc + math.sin(math.tau * k / 18) * 0.082) for k in range(18)], 0.005, segs=6, closed=True)
    gauze = [(math.cos(math.tau * k / 18) * 0.080, math.sin(math.tau * k / 18) * 0.080) for k in range(18)]
    upper = [p for p in gauze if p[1] > -0.030] + []
    plate("linen:black", upper, 0.0, 0.0012, at=(0, yh + 0.0006, zc), rot=(90, 0, 0))
    lower = [(-0.071, -0.036), (0.020, -0.034), (0.071, -0.040)] + [p for p in gauze if p[1] < -0.042][::1]
    plate("linen:black", sorted(lower, key=lambda p: math.atan2(p[1] + 0.060, p[0])), 0.0, 0.0012, at=(0.004, yh + 0.004, zc - 0.004), rot=(86, 0, 3))
    tube("nickel_plated", [(0, yh, zc - 0.082), (0, yh, zc - 0.150), (0, -0.040, zc - 0.200), (0, -0.008, 1.200)], 0.0035, segs=6)
    lathe("brass", [(0.008, 1.190), (0.012, 1.194), (0.012, 1.210), (0.008, 1.214)], segs=8)


def stamp():
    begin("stamp", "hand stamp with turned handle, resting by its inking tin")
    lathe("zinc_quiet", [(0, 0), (0.046, 0), (0.046, 0.012), (0.043, 0.012), (0.043, 0.004), (0, 0.004)], at=(0.045, 0.010, 0), segs=16)
    lathe("linen:indigo", [(0.042, 0.009), (0, 0.009)], at=(0.045, 0.010, 0), segs=16)
    lathe("zinc_quiet", [(0, 0), (0.048, 0), (0.048, 0.010), (0.046, 0.012, "s"), (0, 0.012)], at=(0.110, -0.060, 0), segs=16)
    pivot("Stamp", (-0.045, -0.010, 0.0), "bob", 0.010)
    at = (-0.045, -0.010, 0.0)
    box("rubber_aged", (0.052, 0.024, 0.004), at=(at[0], at[1], 0.002), comp="Stamp")
    box("wood_dark", (0.058, 0.030, 0.012), at=(at[0], at[1], 0.010), comp="Stamp")
    lathe("brass", [(0.010, 0.016), (0.012, 0.018), (0.012, 0.024), (0.009, 0.026)], at=at, comp="Stamp", segs=10)
    lathe("wood_dark", [(0.008, 0.024), (0.007, 0.040, "s"), (0.013, 0.058, "s"), (0.016, 0.072, "s"), (0.013, 0.084, "s"), (0.006, 0.090, "s"), (0, 0.091, "s")], at=at, comp="Stamp", segs=10)


def briefcase():
    begin("briefcase", "leather document case with flap, straps and lock")
    w, d, h = 0.40, 0.085, 0.28
    plate("leather_worn", rounded(w, h, 0.020), -d / 2, d / 2, at=(0, 0, h / 2), rot=(90, 0, 0))
    plate("leather_worn:oxblood", rounded(w + 0.006, 0.150, 0.018), 0, 0.004, at=(0, -d / 2 - 0.004, h - 0.072), rot=(90, 0, 0))
    box("leather_worn:oxblood", (w + 0.006, d + 0.008, 0.004), at=(0, -0.002, h + 0.002))
    for sx in (-0.115, 0.115):
        box("leather_worn", (0.024, 0.003, 0.190), at=(sx, -d / 2 - 0.0095, h - 0.098))
        box("brass", (0.030, 0.004, 0.022), at=(sx, -d / 2 - 0.0115, h - 0.150))
    box("brass", (0.036, 0.005, 0.028), at=(0, -d / 2 - 0.0085, h - 0.128))
    lathe("brass", [(0.004, 0), (0.004, 0.003), (0, 0.003)], at=(0, -d / 2 - 0.011, h - 0.128), rot=(90, 0, 0), segs=8)
    tube("leather_worn:oxblood", [(-0.060, 0, h + 0.004), (-0.055, 0, h + 0.034), (-0.030, 0, h + 0.046), (0.030, 0, h + 0.046), (0.055, 0, h + 0.034), (0.060, 0, h + 0.004)], 0.007, segs=6)
    for sx in (-0.060, 0.060):
        lathe("brass", [(0.010, 0.004), (0.010, 0.008), (0, 0.008)], at=(sx, 0, h), segs=8)


def helmet():
    begin("helmet", "dispatch rider's padded leather crash helmet, scuffed crown down one side")
    sq = (1.0, 1.18)
    lathe("leather_worn", [(0.098, 0.0), (0.100, 0.030, "s")] + [(0.100 * math.cos(a), 0.030 + 0.095 * math.sin(a), "s") for a in [math.pi / 2 * k / 6 for k in range(1, 6)]] + [(0, 0.125, "s")], segs=16, squash=sq)
    lathe("leather_worn", [(0.092, 0.002), (0.098, 0.0)], segs=16, squash=sq)
    lathe("linen:black", [(0.092, 0.002), (0, 0.004)], segs=16, squash=sq)
    # Padded ribs fore-and-aft over the crown.
    for x in (-0.045, 0.0, 0.045):
        r = math.sqrt(max(0.0, 1 - (x / 0.100) ** 2))
        path = [(x, math.cos(math.pi * t) * 0.102 * 1.18 * r, 0.032 + math.sin(math.pi * t) * 0.098 * r) for t in [k / 10 for k in range(11)]]
        tube("leather_worn:oxblood", path, 0.009, segs=6)
    tube("leather_worn:oxblood", [(math.cos(math.tau * k / 16) * 0.101, math.sin(math.tau * k / 16) * 0.119, 0.022) for k in range(16)], 0.006, segs=6, closed=True)
    for sx in (-1, 1):
        plate("leather_worn", rounded(0.075, 0.060, 0.022), 0, 0.004, at=(sx * 0.102, 0.010, 0.014), rot=(90, 0, 90 + sx * 14))
    tube("leather_worn", [(-0.108, 0.012, 0.004), (-0.130, -0.030, 0.003), (-0.100, -0.110, 0.003), (-0.030, -0.150, 0.003)], 0.004, segs=5)
    lathe("brass", [(0.006, 0), (0.008, 0), (0.008, 0.002), (0.006, 0.002)], at=(-0.030, -0.150, 0.002), segs=8)
    # The crash mark: a pale abraded patch standing just proud of the crown.
    lathe("leather_worn:bone", [(0.030, 0.0), (0.020, 0.004, "s"), (0, 0.005, "s")], at=(0.058, -0.046, 0.090), rot=(26, 34, 0), segs=8, squash=(1.0, 1.6))


def wedges():
    begin("wedges", "four rubber furniture wedges, kicked into a loose row")
    tri = [(-0.075, 0), (0.075, 0), (-0.075, 0.048)]
    poses = [((-0.200, 0.030, 0), 12), ((-0.030, -0.050, 0), -8), ((0.060, 0.075, 0), 172), ((0.215, -0.040, 0), 24)]
    for (x, y, z), yaw in poses:
        plate("rubber_aged", tri, -0.040, 0.040, at=(x, y, z), rot=(90, 0, yaw))


def bag():
    begin("bag", "overloaded canvas courier satchel, strap spilled on the floor")
    w, d, h = 0.38, 0.15, 0.27
    plate("monks_cloth:canvas", rounded(w, h, 0.030), -d / 2, d / 2, at=(0, 0, h / 2), rot=(90, 0, 0))
    plate("leather_worn", rounded(w + 0.008, 0.170, 0.026), 0, 0.005, at=(0, -d / 2 - 0.005, h - 0.050), rot=(96, 0, 0))
    box("leather_worn", (w + 0.008, d * 0.55, 0.005), at=(0, -d * 0.22, h + 0.018), rot=(-18, 0, 0))
    for sx in (-0.11, 0.11):
        box("leather_worn", (0.026, 0.004, 0.120), at=(sx, -d / 2 - 0.016, h - 0.105), rot=(6, 0, 0))
        box("brass", (0.032, 0.005, 0.024), at=(sx, -d / 2 - 0.022, h - 0.155), rot=(6, 0, 0))
    # What will not fit: parcels standing out of the mouth.
    box("paper:manila", (0.150, 0.070, 0.120), at=(-0.090, 0.020, h + 0.020), rot=(0, 6, 4))
    box("paper:cream", (0.110, 0.050, 0.150), at=(0.060, 0.030, h + 0.030), rot=(4, -8, -6))
    tube("paper:manila", [(0.130, 0.020, h - 0.02), (0.130, 0.020, h + 0.150)], 0.022, segs=8)
    tube("linen:cream", [(-0.165, 0.019, h + 0.040), (-0.015, 0.019, h + 0.040)], 0.0012, segs=4)
    for sx in (-1, 1):
        lathe("brass", [(0.010, 0), (0.014, 0), (0.014, 0.004), (0.010, 0.004)], at=(sx * (w / 2 + 0.001), 0, h - 0.040), rot=(0, 90 * sx, 0), segs=8)
    strap = [(-w / 2 - 0.004, 0, h - 0.045), (-w / 2 - 0.060, -0.020, 0.120), (-w / 2 - 0.110, -0.090, 0.006), (-0.120, -0.240, 0.006),
             (0.080, -0.270, 0.006), (0.260, -0.180, 0.006), (w / 2 + 0.100, -0.060, 0.008), (w / 2 + 0.050, -0.010, 0.130), (w / 2 + 0.004, 0, h - 0.045)]
    tube("leather_worn", smooth(strap, 4), 0.006, segs=5)


def _casket(name, note, body, band, w, d, h, lid_h, feet):
    begin(name, note)
    z0 = 0.012 if feet else 0.0
    box(body, (w, d, h), at=(0, 0, z0 + h / 2))
    box(body, (w + 0.008, d + 0.008, lid_h), at=(0, 0, z0 + h + 0.002 + lid_h / 2))
    return z0


def artifact_box():
    w, d, h = 0.30, 0.20, 0.110
    z0 = _casket("artifact_box", "plain deal archive box, lid tied down with tape", "site_softwood", "", w, d, h, 0.022, False)
    for sx in (-0.085, 0.085):
        box("linen:cream", (0.014, d + 0.012, 0.0012), at=(sx, 0, h + 0.0252))
        for sy in (-1, 1):
            box("linen:cream", (0.014, 0.0012, h + 0.024), at=(sx, sy * (d / 2 + 0.0052), (h + 0.024) / 2))
    tube("linen:cream", loop_path(0.016, 0.008, h + 0.0275, 8), 0.0016, segs=4, closed=True, at=(-0.085, 0, 0))
    box("paper:cream", (0.085, 0.0008, 0.045), at=(0.030, -d / 2 - 0.0005, 0.060))
    for sx in (-1, 1):
        tube("linen:canvas", [(sx * (w / 2), -0.040, 0.075), (sx * (w / 2 + 0.022), -0.030, 0.060), (sx * (w / 2 + 0.022), 0.030, 0.060), (sx * (w / 2), 0.040, 0.075)], 0.004, segs=5)


def antique_box():
    w, d, h = 0.26, 0.17, 0.090
    z0 = _casket("antique_box", "walnut casket with brass corners, escutcheon and ball feet", "wood_dark", "brass", w, d, h, 0.030, True)
    box("wood_dark", (w - 0.030, d - 0.030, 0.008), at=(0, 0, z0 + h + 0.036))
    for sx in (-1, 1):
        for sy in (-1, 1):
            lathe("brass", [(0, 0), (0.007, 0.002, "s"), (0.009, 0.007, "s"), (0.006, 0.012, "s")], at=(sx * (w / 2 - 0.016), sy * (d / 2 - 0.016), 0), segs=8)
            for zc, hh in ((z0 + 0.012, 0.024), (z0 + h + 0.020, 0.024)):
                box("brass", (0.024, 0.0015, hh), at=(sx * (w / 2 - 0.008), sy * (d / 2 + (0.0048 if zc > z0 + h else 0.0008)), zc))
                box("brass", (0.0015, 0.024, hh), at=(sx * (w / 2 + (0.0048 if zc > z0 + h else 0.0008)), sy * (d / 2 - 0.008), zc))
    plate("brass", [(-0.011, -0.016), (0.011, -0.016), (0.011, 0.008), (0, 0.018), (-0.011, 0.008)], 0, 0.0015, at=(0, -d / 2 - 0.0015, z0 + h - 0.016), rot=(90, 0, 0))
    box("brass", (0.030, 0.004, 0.010), at=(0, -d / 2 - 0.006, z0 + h + 0.008))
    box("brass", (w * 0.6, 0.006, 0.003), at=(0, d / 2 + 0.001, z0 + h + 0.001))


def keycards():
    begin("keycards", "five punched room-key cards on a ring: signal stores, forty years early")
    card = [(-0.043, -0.027), (0.035, -0.027), (0.043, -0.019), (0.043, 0.027), (-0.043, 0.027)]
    for k in range(5):
        punched = [circle(0.0026, 4, (-0.028 + 0.013 * c, -0.012 + 0.011 * r)) for c in range(5) for r in range(3) if rng(k * 18 + c * 3 + r, 9) > 0.62]
        punched.append(circle(0.0030, 5, (-0.036, 0.020)))
        plate("paper:ivory", card, 0, 0.0009, at=(0.004 * k, 0.002 * k, 0.0010 * k), rot=(0, 0, -28 + 14 * k), holes=punched)
        if k == 2:
            box("brass", (0.086, 0.004, 0.0004), at=(0.008, 0.004, 0.0010 * k + 0.0011), rot=(0, 0, 0))
    m = [_xf((0.004 * k, 0.002 * k, 0), (0, 0, -28 + 14 * k)) @ Vector((-0.036, 0.020, 0)) for k in range(5)]
    c = sum(m, Vector()) / 5
    tube("brass", [(c.x - 0.006 + math.cos(math.tau * k / 12) * 0.011, c.y + 0.008 + math.sin(math.tau * k / 12) * 0.011, 0.0030 + 0.0020 * math.sin(math.tau * k / 12)) for k in range(12)], 0.0009, segs=5, closed=True)


def folded_cloth():
    begin("folded_cloth", "hotel hand towel folded in three, woven band at one end")
    w, d = 0.300, 0.200
    for k in range(3):
        t = 0.016
        z = k * t
        box("linen:white", (w - k * 0.004, d - t, t), at=(k * 0.002, t / 2, z + t / 2))
        tube("linen:white", [(-(w - k * 0.004) / 2 + k * 0.002, -d / 2 + t, z + t / 2), ((w - k * 0.004) / 2 + k * 0.002, -d / 2 + t, z + t / 2)], t / 2, segs=8)
    box("linen:madder", (0.022, d - 0.014, 0.0008), at=(-w / 2 + 0.040, 0.008, 0.0484))
    box("linen:madder", (0.006, d - 0.014, 0.0008), at=(-w / 2 + 0.062, 0.008, 0.0484))


def antenna():
    begin("antenna", "frame aerial: square walnut loop wound with copper on a turned foot")
    lathe("wood_dark", [(0, 0), (0.115, 0), (0.115, 0.014), (0.090, 0.026, "s"), (0.030, 0.034, "s"), (0.020, 0.060, "s"), (0.020, 0.150), (0, 0.150)], segs=16)
    zc, half = 0.530, 0.270
    # Cross arms of the diamond frame, in the X-Z plane.
    box("wood_dark", (0.022, 0.030, 2 * half + 0.230), at=(0, 0, zc - 0.115 + 0.0))
    box("wood_dark", (2 * half, 0.030, 0.022), at=(0, 0, zc))
    corners = [(half, zc), (0, zc + half), (-half, zc), (0, zc - half)]
    for x, z in corners:
        box("wood_dark", (0.034, 0.090, 0.034), at=(x, 0, z), rot=(0, 45, 0))
    for k in range(6):
        y = -0.036 + k * 0.0144
        tube("copper_aged", [(x * 1.02, y, zc + (z - zc) * 1.02) for x, z in corners], 0.0016, segs=4, closed=True)
    for sx in (-0.030, 0.030):
        lathe("brass", [(0.006, 0.150), (0.006, 0.158), (0.009, 0.158), (0.009, 0.163), (0, 0.163)], at=(sx, -0.0, 0), segs=8)
    box("bakelite_black", (0.090, 0.040, 0.008), at=(0, 0, 0.154))
    tube("copper_aged", [(0.030, 0, 0.160), (0.030, -0.030, 0.240), (0.006, -0.036, zc - half * 1.02 + 0.010)], 0.0016, segs=4)
    tube("copper_aged", [(-0.030, 0, 0.160), (-0.030, 0.030, 0.240), (-0.006, 0.036, zc - half * 1.02 + 0.010)], 0.0016, segs=4)


def palette():
    begin("palette", "walnut hand palette with thumb hole and the day's colours")
    outline = [(math.cos(math.tau * k / 22) * 0.165 * (1 + 0.10 * math.cos(math.tau * k / 22 * 2 + 0.6)),
                math.sin(math.tau * k / 22) * 0.110 * (1 + 0.08 * math.sin(math.tau * k / 22 * 3))) for k in range(22)]
    plate("wood_dark", outline, 0.0, 0.005, holes=[circle(0.014, 10, (0.095, -0.040))])
    dabs = ["enamel:madder", "enamel:ochre", "enamel:viridian", "enamel:madder", "enamel:ochre", "enamel:sour"]
    for k, key in enumerate(dabs):
        a = math.radians(70 + k * 38)
        r = 0.012 + 0.004 * rng(k, 11)
        lathe(key, [(r, 0.0), (r * 0.8, 0.003, "s"), (r * 0.3, 0.0055, "s"), (0, 0.006, "s")], at=(math.cos(a) * 0.115, math.sin(a) * 0.070, 0.005), segs=8, squash=(1.0, 0.8 + 0.4 * rng(k, 12)))
    lathe("enamel:sour", [(0.030, 0.0), (0.020, 0.0015, "s"), (0, 0.002, "s")], at=(-0.010, -0.020, 0.005), segs=10, squash=(1.3, 0.8))
    # A hog brush laid across it.
    lathe("timber", [(0, 0), (0.004, 0), (0.0045, 0.150, "s"), (0.003, 0.200, "s")], at=(-0.120, -0.085, 0.0095), rot=(0, 90, 22), segs=6)
    lathe("enamel:sour", [(0.0050, 0), (0.0040, 0.030, "s"), (0, 0.040, "s")], at=(0.065, -0.010, 0.0095), rot=(0, 90, 22), segs=6, squash=(1, 0.5))


def _can(at, open_key=None):
    r, h = 0.055, 0.120
    prof = [(0, 0), (r, 0), (r + 0.002, 0.004), (r, 0.008), (r, h - 0.008), (r + 0.002, h - 0.004), (r, h)]
    if open_key:
        prof += [(r - 0.006, h), (r - 0.006, h - 0.012), (r - 0.003, h - 0.012), (r - 0.003, h - 0.030)]
        lathe("zinc_quiet", prof, at=at, segs=14)
        lathe(open_key, [(r - 0.003, h - 0.030), (0, h - 0.030)], at=at, segs=14)
    else:
        prof += [(r - 0.006, h), (r - 0.006, h - 0.004), (0, h - 0.004)]
        lathe("zinc_quiet", prof, at=at, segs=14)
    for s in (-1, 1):
        lathe("zinc_quiet", [(0.005, 0), (0.005, 0.004), (0, 0.004)], at=(at[0] + s * (r + 0.001), at[1], h - 0.030), rot=(0, s * 90, 0), segs=6)
    return r, h


def paint_cans():
    begin("paint_cans", "two tinned paint cans, one opened on a colour that is plainly wrong")
    r, h = _can((-0.070, 0.010, 0), "enamel:sour")
    _can((0.075, 0.030, 0))
    # Bail of the shut can stands; the open one's bail has fallen forward.
    tube("iron_blackened", [(0.075 + math.cos(math.pi * t) * (r + 0.004), 0.030, h - 0.030 + math.sin(math.pi * t) * 0.075) for t in [k / 10 for k in range(11)]], 0.0016, segs=4)
    tube("iron_blackened", [(-0.070 + math.cos(math.pi * t) * (r + 0.004), 0.010 - math.sin(math.pi * t) * 0.070, h - 0.030 - math.sin(math.pi * t) * 0.030) for t in [k / 10 for k in range(11)]], 0.0016, segs=4)
    # The prised lid, paint side up, and what ran down the side.
    lathe("zinc_quiet", [(0, 0), (0.050, 0), (0.050, 0.004), (0.046, 0.004)], at=(-0.050, -0.105, 0), segs=14)
    lathe("enamel:sour", [(0.046, 0.0035), (0, 0.0045, "s")], at=(-0.050, -0.105, 0), segs=14)
    tube("enamel:sour", [(-0.070 + 0.0555, 0.010 - 0.012, h + 0.001), (-0.070 + 0.0575, 0.010 - 0.013, h - 0.030), (-0.070 + 0.0575, 0.010 - 0.016, h - 0.075)], 0.0035, segs=5)
    lathe("enamel:sour", [(0.016, 0), (0.008, 0.0012, "s"), (0, 0.0016, "s")], at=(0.004, -0.050, 0), segs=8, squash=(1.5, 1.0))
    # Stirring stick.
    box("timber", (0.200, 0.018, 0.004), at=(0.020, -0.100, 0.008), rot=(0, -3, 12))


def recorder():
    begin("recorder", "portable capture deck: twin reels, head block, three keys and a pilot lens")
    w, d, h = 0.320, 0.240, 0.095
    plate("bakelite_black", rounded(w, d, 0.014), 0, h)
    plate("enamel_appliance:grey", rounded(w - 0.020, d - 0.020, 0.008), h, h + 0.003)
    for name, x, spin in (("ReelA", -0.078, 1.6), ("ReelB", 0.078, 1.1)):
        zc = h + 0.006
        lathe("nickel_plated", [(0.006, h + 0.003), (0.006, zc + 0.016), (0, zc + 0.016)], at=(x, 0.040, 0), segs=8)
        pivot(name, (x, 0.040, zc), "spin", spin)
        for z0 in (0.0, 0.0095):
            plate("nickel_plated", circle(0.066, 18), z0, z0 + 0.0012, at=(x, 0.040, zc), comp=name,
                  holes=[[(math.cos(math.radians(a0 + s * 44)) * rr, math.sin(math.radians(a0 + s * 44)) * rr) for s, rr in ((0, 0.024), (1, 0.024), (1, 0.056), (0, 0.056))] for a0 in (20, 140, 260)])
        full = 0.052 if name == "ReelA" else 0.034
        lathe("bakelite:tape", [(0.018, 0.0012), (full, 0.0012), (full, 0.0095), (0.018, 0.0095)], at=(x, 0.040, zc), comp=name, segs=18)
        lathe("nickel_plated", [(0.007, 0.0012), (0.018, 0.0012), (0.018, 0.0095), (0.007, 0.0095)], at=(x, 0.040, zc), comp=name, segs=10)
    box("nickel_plated", (0.070, 0.026, 0.016), at=(0, -0.048, h + 0.011))
    for sx in (-0.052, 0.052):
        lathe("nickel_plated", [(0.005, h + 0.003), (0.005, h + 0.020), (0, h + 0.020)], at=(sx, -0.040, 0), segs=8)
    tube("bakelite:tape", [(-0.078 - 0.052, 0.040, h + 0.011), (-0.057, -0.040, h + 0.011), (0, -0.034, h + 0.011), (0.057, -0.040, h + 0.011), (0.078 + 0.034, 0.040, h + 0.011)], 0.0030, segs=4)
    for k in range(3):
        box("bakelite:ivory", (0.026, 0.030, 0.010), at=(-0.036 + k * 0.036, -0.094, h + 0.008), rot=(8, 0, 0))
    lathe("milk_glass", [(0.008, h + 0.003), (0.008, h + 0.006), (0.004, h + 0.009, "s"), (0, h + 0.009)], at=(0.124, -0.090, 0), segs=10)
    lathe("nickel_plated", [(0.011, h + 0.003), (0.011, h + 0.005), (0.008, h + 0.005)], at=(0.124, -0.090, 0), segs=10)
    lathe("bakelite_black", [(0.012, h + 0.003), (0.011, h + 0.016), (0, h + 0.016)], at=(-0.124, -0.090, 0), segs=10)
    tube("bakelite_black", [(-0.090, -d / 2 - 0.001, h * 0.6), (-0.070, -d / 2 - 0.026, h * 0.6), (0.070, -d / 2 - 0.026, h * 0.6), (0.090, -d / 2 - 0.001, h * 0.6)], 0.006, segs=6)


def word_tiles():
    begin("word_tiles", "a spilled set of blank boxwood anagram tiles")
    for k in range(16):
        x = (rng(k, 20) - 0.5) * 0.36
        y = (rng(k, 21) - 0.5) * 0.24
        yaw = rng(k, 22) * 360
        if k % 5 == 4:
            # Leaning on its neighbour.
            box("timber:bone", (0.019, 0.019, 0.005), at=(x, y, 0.0085), rot=(38, 0, yaw))
        elif k % 7 == 6:
            box("timber:bone", (0.019, 0.019, 0.005), at=(x, y, 0.0025))
            box("timber:bone", (0.019, 0.019, 0.005), at=(x + 0.003, y + 0.002, 0.0075), rot=(0, 0, yaw + 30))
        else:
            box("timber:bone", (0.019, 0.019, 0.005), at=(x, y, 0.0025), rot=(0, 0, yaw))
    # The drawstring pouch they came out of, slumped empty.
    lathe("linen:indigo", [(0, 0), (0.060, 0), (0.064, 0.006, "s"), (0.050, 0.016, "s"), (0.020, 0.022, "s"), (0, 0.022, "s")], at=(-0.150, 0.100, 0), rot=(0, 0, 20), segs=10, squash=(1.0, 0.7))
    tube("linen:cream", smooth([(-0.100, 0.118, 0.012), (-0.070, 0.140, 0.003), (-0.030, 0.130, 0.002), (-0.020, 0.100, 0.002)], 3), 0.0012, segs=4)


def _glove(at, yaw, mirror):
    m = lambda x, y: (at[0] + (x * mirror) * math.cos(math.radians(yaw)) - y * math.sin(math.radians(yaw)),
                      at[1] + (x * mirror) * math.sin(math.radians(yaw)) + y * math.cos(math.radians(yaw)))
    px, py = m(0, 0)
    plate("linen:white", rounded(0.086, 0.100, 0.020), 0.0, 0.007, at=(px, py, 0), rot=(0, 0, yaw))
    cx, cy = m(0, -0.072)
    plate("linen:white", rounded(0.076, 0.050, 0.008), 0.0, 0.006, at=(cx, cy, 0), rot=(0, 0, yaw))
    bx, by = m(0, -0.050)
    box("linen:white", (0.080, 0.004, 0.0075), at=(bx, by, 0.00375), rot=(0, 0, yaw))
    for k, (fx, length, lean) in enumerate(((-0.031, 0.060, 6), (-0.010, 0.074, 2), (0.011, 0.070, -2), (0.031, 0.054, -7))):
        a = m(fx, 0.046)
        tip = m(fx - math.sin(math.radians(lean)) * length * 0.0 + math.radians(lean) * -length, 0.046 + length)
        tube("linen:white", [(a[0], a[1], 0.0038), (tip[0], tip[1], 0.0038)], 0.0080, segs=6, rot=(0, 0, 0))
    a = m(-0.040, -0.010)
    tip = m(-0.082, 0.030)
    tube("linen:white", [(a[0], a[1], 0.0040), (tip[0], tip[1], 0.0040)], 0.0085, segs=6)
    for k in range(3):
        s = m(-0.014 + 0.014 * k, -0.030)
        e = m(-0.014 + 0.014 * k, 0.030)
        tube("linen:white", [(s[0], s[1], 0.0070), (e[0], e[1], 0.0070)], 0.0009, segs=4)


def gloves():
    begin("gloves", "a pair of white cotton handling gloves laid side by side")
    _glove((-0.062, 0.0, 0), 10, 1)
    _glove((0.066, -0.008, 0), -14, -1)


def service_cart():
    begin("service_cart", "two-shelf maintenance trolley on rubber castors")
    w, d, top = 0.78, 0.42, 0.800
    for sx in (-1, 1):
        for sy in (-1, 1):
            x, y = sx * (w / 2 - 0.015), sy * (d / 2 - 0.015)
            box("iron_blackened", (0.030, 0.030, top - 0.120), at=(x, y, 0.105 + (top - 0.120) / 2))
            box("iron_blackened", (0.044, 0.006, 0.034), at=(x, y - 0.019, 0.090))
            box("iron_blackened", (0.044, 0.006, 0.034), at=(x, y + 0.019, 0.090))
            box("iron_blackened", (0.044, 0.044, 0.006), at=(x, y, 0.104))
            lathe("rubber_aged", [(0.012, -0.014), (0.045, -0.014), (0.045, 0.014), (0.012, 0.014)], at=(x, y, 0.045), rot=(90, 0, 0), segs=14)
            lathe("iron_blackened", [(0, -0.020), (0.012, -0.020), (0.012, 0.020), (0, 0.020)], at=(x, y, 0.045), rot=(90, 0, 0), segs=8)
    for z in (0.260, top - 0.018):
        box("oak_work_surface", (w, d, 0.018), at=(0, 0, z + 0.009))
        box("iron_blackened", (w - 0.060, 0.022, 0.030), at=(0, -(d / 2 - 0.011), z - 0.015))
        box("iron_blackened", (w - 0.060, 0.022, 0.030), at=(0, (d / 2 - 0.011), z - 0.015))
        for sx in (-1, 1):
            box("iron_blackened", (0.022, d - 0.060, 0.030), at=(sx * (w / 2 - 0.011), 0, z - 0.015))
    # Lip round the lower shelf, and the push handle.
    box("iron_blackened", (w - 0.060, 0.004, 0.040), at=(0, -(d / 2 - 0.002), 0.298))
    box("iron_blackened", (w - 0.060, 0.004, 0.040), at=(0, (d / 2 - 0.002), 0.298))
    tube("nickel_plated", [(w / 2 - 0.015, -(d / 2 - 0.015), top - 0.030), (w / 2 + 0.090, -(d / 2 - 0.015), top + 0.070), (w / 2 + 0.090, (d / 2 - 0.015), top + 0.070), (w / 2 - 0.015, (d / 2 - 0.015), top - 0.030)], 0.011, segs=8)
    # What lives on the lower shelf.
    lathe("zinc_quiet", [(0, 0), (0.105, 0), (0.125, 0.200), (0.130, 0.200), (0.130, 0.206), (0.120, 0.206), (0.101, 0.008), (0, 0.008)], at=(-0.200, 0, 0.278), segs=14)
    tube("iron_blackened", [(-0.200 + math.cos(math.pi * t) * 0.128, 0.040 * math.sin(math.pi * t), 0.278 + 0.190 + math.sin(math.pi * t) * 0.050) for t in [k / 8 for k in range(9)]], 0.003, segs=4)
    box("linen:canvas", (0.220, 0.160, 0.050), at=(0.170, 0.020, 0.303), rot=(0, 0, -8))
    box("linen:cream", (0.200, 0.150, 0.030), at=(0.176, 0.016, 0.343), rot=(0, 0, 5))


def clipboard():
    begin("clipboard", "inspection board: ply back, sprung brass clip, ruled sheets")
    box("plywood", (0.230, 0.320, 0.004), at=(0, 0, 0.002))
    box("paper:cream", (0.208, 0.290, 0.0012), at=(0.002, -0.010, 0.0046), rot=(0, 0, 1.5))
    box("paper", (0.208, 0.290, 0.0010), at=(0, -0.008, 0.0057), rot=(0, 0, -1.0))
    box("brass", (0.110, 0.034, 0.003), at=(0, 0.138, 0.0080))
    lathe("brass", [(0, -0.055), (0.006, -0.055), (0.006, 0.055), (0, 0.055)], at=(0, 0.150, 0.0100), rot=(0, 90, 0), segs=8)
    box("brass", (0.090, 0.012, 0.0025), at=(0, 0.116, 0.0075), rot=(-14, 0, 0))
    tube("linen:cream", [(0.100, 0.150, 0.006), (0.150, 0.100, 0.002), (0.140, 0.000, 0.002), (0.128, -0.070, 0.004)], 0.0008, segs=4)
    lathe("book_burgundy", [(0.0035, 0.0), (0.0035, 0.085)], at=(0.128, -0.160, 0.0035), rot=(-90, 0, 0), segs=6)
    lathe("timber", [(0.0035, 0.0), (0.001, 0.012), (0, 0.012)], at=(0.128, -0.160, 0.0035), rot=(90, 0, 0), segs=6)


def tape_measure():
    begin("tape_measure", "leather-cased winding tape with folding brass crank")
    lathe("leather_worn", [(0, 0), (0.044, 0), (0.047, 0.003, "s"), (0.047, 0.017, "s"), (0.044, 0.020, "s"), (0, 0.020)], segs=16)
    lathe("brass", [(0.014, 0.020), (0.014, 0.0215), (0, 0.0215)], segs=10)
    pivot("Crank", (0, 0, 0.0215), "spin", -3.0)
    box("brass", (0.034, 0.007, 0.002), at=(0.012, 0, 0.0225), comp="Crank")
    lathe("brass", [(0.0035, 0.0235), (0.0035, 0.031), (0, 0.031)], at=(0.026, 0, 0), comp="Crank", segs=6)
    lathe("brass", [(0.004, 0.0215), (0.004, 0.0245), (0, 0.0245)], comp="Crank", segs=8)
    box("brass", (0.012, 0.004, 0.012), at=(0, -0.047, 0.010))
    # The tongue: more tape out than the case could hold.
    path = [(0, -0.048, 0.010), (0.010, -0.075, 0.004), (0.045, -0.100, 0.0012), (0.100, -0.095, 0.0012), (0.130, -0.060, 0.0012)]
    for a, b in zip(path, path[1:]):
        mid = [(a[i] + b[i]) / 2 for i in range(3)]
        length = math.dist(a, b)
        yaw = math.degrees(math.atan2(b[1] - a[1], b[0] - a[0]))
        pitch = -math.degrees(math.asin((b[2] - a[2]) / length))
        box("linen:ochre", (length + 0.012, 0.013, 0.0005), at=mid, rot=(0, pitch, yaw))
    tube("brass", loop_path(0.007, 0.007, 0.0015, 8), 0.0011, segs=4, closed=True, at=(0.138, -0.054, 0))


def portal_tags():
    begin("portal_tags", "five stamped brass tally tags on a split iron ring")
    outline = rounded(0.100, 0.045, 0.010)
    for k in range(5):
        yaw = -50 + k * 25
        m = _xf((0, 0, 0), (0, 0, yaw))
        c = m @ Vector((0.060, 0, 0))
        plate("brass_dull", outline, 0, 0.0016, at=(c.x - 0.004, c.y, 0.0018 * k), rot=(0, 0, yaw), holes=[circle(0.0035, 6, (-0.038, 0))])
        # Stamped marks stand as plain raised bars: no lettering in geometry.
        for j in range(3):
            p = m @ Vector((0.050 + j * 0.016, 0.0, 0))
            box("brass_dull", (0.008, 0.022 - j * 0.004, 0.0005), at=(p.x - 0.004, p.y, 0.0018 * k + 0.0018), rot=(0, 0, yaw))
    tube("iron_blackened", [(0.008 + math.cos(math.tau * k / 14) * 0.026, math.sin(math.tau * k / 14) * 0.026, 0.0050 + 0.0030 * math.cos(math.tau * k / 14)) for k in range(14)], 0.0016, segs=5, closed=True)


def storage_crate():
    begin("storage_crate", "slatted softwood packing crate with nailed lid and rope beckets")
    w, d, h = 0.72, 0.50, 0.48
    t = 0.018
    box("site_softwood", (w - 2 * t - 0.004, d - 2 * t - 0.004, h - 2 * t), at=(0, 0, h / 2))
    for sx in (-1, 1):
        for sy in (-1, 1):
            box("site_softwood", (0.045, 0.045, h - t), at=(sx * (w / 2 - 0.0225), sy * (d / 2 - 0.0225), (h - t) / 2))
    for k in range(4):
        z = 0.062 + k * 0.118
        for sy in (-1, 1):
            box("site_softwood", (w - 0.004, t, 0.095), at=(0.002 * (k % 2), sy * (d / 2 - t / 2 + 0.006), z))
        for sx in (-1, 1):
            box("site_softwood", (t, d - 0.012, 0.095), at=(sx * (w / 2 - t / 2 + 0.006), 0, z))
    for k in range(4):
        box("site_softwood", (w + 0.016, 0.118, t), at=(0, -d / 2 + 0.065 + k * 0.1235, h - t / 2 + 0.001 * (k % 2)), rot=(0, 0, 0.4 * (k % 2)))
    for sx in (-0.25, 0.25):
        box("site_softwood", (0.060, d + 0.016, 0.014), at=(sx, 0, h + 0.007))
    for sx in (-1, 1):
        x = sx * (w / 2 + 0.006)
        tube("linen:canvas", [(x, -0.090, 0.330), (x + sx * 0.030, -0.070, 0.290), (x + sx * 0.036, 0, 0.270), (x + sx * 0.030, 0.070, 0.290), (x, 0.090, 0.330)], 0.008, segs=6)
    for sx in (-0.30, -0.10, 0.10, 0.30):
        for k in range(4):
            lathe("iron_blackened", [(0.004, 0), (0.004, 0.0012), (0, 0.0012)], at=(sx, -d / 2 + 0.065 + k * 0.1235, h + 0.0145 if abs(sx) == 0.25 else h + 0.0015), segs=6)


def cable_bundle():
    begin("cable_bundle", "braided patch cords coiled on the floor, plugs loose")
    for k in range(3):
        r = 0.120 + k * 0.022
        tube("linen:black" if k != 1 else "linen:oxblood", [(math.cos(math.tau * j / 20) * r * (1 + 0.05 * math.sin(j * 1.7 + k)), math.sin(math.tau * j / 20) * r * (1 + 0.05 * math.cos(j * 1.3 + k)), 0.006 + k * 0.009 + 0.003 * math.sin(j * 0.9 + k)) for j in range(20)],
             0.0055, segs=6, closed=True)
    for k, (x, y, yaw) in enumerate(((0.215, -0.060, -16), (-0.070, 0.225, 107), (-0.215, -0.100, 205), (0.090, -0.225, -68))):
        a = math.radians(yaw)
        n = math.hypot(x, y)
        sx, sy = x / n * 0.136, y / n * 0.136
        tube("linen:black", smooth([(sx - sy * 0.5, sy + sx * 0.5, 0.012), (sx, sy, 0.008), ((sx + x) / 2 + sy * 0.12, (sy + y) / 2 - sx * 0.12, 0.006), (x, y, 0.008)], 3), 0.0050, segs=5)
        lathe("bakelite_black", [(0, 0), (0.007, 0), (0.009, 0.030, "s"), (0.006, 0.034)], at=(x, y, 0.009), rot=(0, 90, yaw), segs=8)
        lathe("brass", [(0.0032, 0.034), (0.0032, 0.058), (0.0045, 0.060, "s"), (0.003, 0.066, "s"), (0, 0.067)], at=(x, y, 0.009), rot=(0, 90, yaw), segs=6)


def rule_board():
    begin("rule_board", "storage-room rule board: walnut ground in a mitred oak frame, hung on iron straps")
    # Origin at the board's centre, as V1's; front toward -Y. The wall plane is
    # at y = +WALL: the hanger straps and the two lower blocks bear on it.
    W, H, wall = 1.55, 1.05, 0.040
    fw, fd = 0.060, 0.050
    box("wood_dark", (W - 2 * fw + 0.020, 0.020, H - 2 * fw + 0.020), at=(0, 0.010 - 0.0275 + 0.0, 0))
    # Panel face sits at y = -0.0275, where V1's slab face was, so V1's own
    # label offsets land just proud of it.
    yf = -0.0275 - 0.014
    # Mitred members, drawn in the board's own X-Z plane and cut fd deep.
    for sz in (-1, 1):
        plate("oak_quartered", [(-W / 2, sz * H / 2), (W / 2, sz * H / 2), (W / 2 - fw, sz * (H / 2 - fw)), (-W / 2 + fw, sz * (H / 2 - fw))],
              -(yf + fd), -yf, rot=(90, 0, 0), grain_along="x")
    for sx in (-1, 1):
        plate("oak_quartered", [(sx * W / 2, -H / 2), (sx * W / 2, H / 2), (sx * (W / 2 - fw), H / 2 - fw), (sx * (W / 2 - fw), -H / 2 + fw)],
              -(yf + fd), -yf, rot=(90, 0, 0), grain_along="y")
    # Chalk ledge along the foot.
    box("oak_quartered", (W - 0.200, 0.045, 0.014), at=(0, yf - 0.020, -H / 2 + 0.020))
    # Back battens, standing the board off the wall.
    for sx in (-0.50, 0.50):
        box("site_softwood", (0.060, wall - 0.0075 + 0.0275 - 0.020 + 0.0, H - 0.160), at=(sx, (0.0025 + wall) / 2 - 0.006, 0))
    for sx in (-0.50, 0.50):
        box("iron_blackened", (0.036, 0.004, 0.200), at=(sx, wall - 0.002, H / 2 + 0.050))
        box("iron_blackened", (0.036, wall + 0.006, 0.004), at=(sx, (wall - 0.006) / 2 - 0.003, H / 2 + 0.002))
        for z in (H / 2 + 0.085, H / 2 + 0.130):
            lathe("brass", [(0.006, 0), (0.006, 0.002), (0.003, 0.004, "s"), (0, 0.004)], at=(sx, wall - 0.004, z), rot=(90, 0, 0), segs=8)
    for sx in (-1, 1):
        for sz in (-1, 1):
            lathe("brass", [(0.005, 0), (0.005, 0.0015), (0.002, 0.003, "s"), (0, 0.003)], at=(sx * (W / 2 - 0.030), yf, sz * (H / 2 - 0.030)), rot=(90, 0, 0), segs=8)


BUILDERS = [bell, pager, notebook, pencil, spools, cassette, tool_case, tags, tape_reel, microphone, stamp,
            briefcase, helmet, wedges, bag, artifact_box, antique_box, keycards, folded_cloth, antenna, palette,
            paint_cans, recorder, word_tiles, gloves, service_cart, clipboard, tape_measure, portal_tags,
            storage_crate, cable_bundle, rule_board]


# ---------------------------------------------------------------------------

def review_material(base, tint):
    name = "review_%s_%s" % (base, tint)
    if name in bpy.data.materials:
        return bpy.data.materials[name]
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    spec = CATALOGUE[base]
    image = bpy.data.images.load(str(TEXTURES / spec["files"][0]), check_existing=True)
    tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
    tex.image = image
    mix = mat.node_tree.nodes.new("ShaderNodeMixRGB")
    mix.blend_type = "MULTIPLY"
    mix.inputs[0].default_value = 1.0
    mix.inputs[2].default_value = (*TINTS.get(tint, (1, 1, 1)), 1)
    mat.node_tree.links.new(tex.outputs["Color"], mix.inputs[1])
    mat.node_tree.links.new(mix.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Metallic"].default_value = float(spec["metallic"])
    bsdf.inputs["Roughness"].default_value = 0.55
    return mat


def realise():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    for build in BUILDERS:
        build()
    objects, rows = {}, {}
    for (asm, comp, base, tint), bm in PARTS.items():
        origin = PIVOTS.get((asm, comp), Vector((0, 0, 0)))
        for v in bm.verts:
            v.co -= origin
        bmesh.ops.triangulate(bm, faces=bm.faces[:])
        layer = bm.loops.layers.uv.active
        for f in bm.faces:
            area = f.calc_area()
            if area < 1e-12:
                continue
            a, b, c = [l[layer].uv for l in f.loops]
            assert abs((b - a).cross(c - a)) > 1e-12, ("collapsed UV chart", asm, comp, base)
        bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.calc_area() < 1e-12], context="FACES")
        name = "%s__%s_ON_%s%s" % (asm, comp, base, "__" + tint if tint else "")
        mesh = bpy.data.meshes.new(name)
        bm.to_mesh(mesh)
        tris = len(bm.faces)
        bm.free()
        obj = bpy.data.objects.new(name, mesh)
        obj.location = origin
        bpy.context.scene.collection.objects.link(obj)
        mesh.materials.append(review_material(base, tint))
        objects.setdefault(asm, []).append(obj)
        row = {"name": name, "component": comp, "material": base, "triangles": tris}
        if tint:
            row["tint"] = [round(c, 3) for c in TINTS[tint]]
        if (asm, comp) in MOTION:
            row.update(MOTION[(asm, comp)])
            row["pivot_blender"] = [round(c, 5) for c in origin]
        rows.setdefault(asm, []).append(row)
    bpy.context.view_layer.update()
    return objects, rows


def bounds(objs):
    low, high = Vector((1e9,) * 3), Vector((-1e9,) * 3)
    for o in objs:
        for v in o.data.vertices:
            p = o.matrix_world @ v.co
            low = Vector(map(min, low, p))
            high = Vector(map(max, high, p))
    return low, high


def review(objects):
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 40
    scene.cycles.use_denoising = True
    scene.render.resolution_x, scene.render.resolution_y = 1600, 1000
    world = bpy.data.worlds.new("review")
    scene.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.20, 0.19, 0.18, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.6
    extras = []
    bpy.ops.mesh.primitive_plane_add(size=40)
    floor = bpy.context.object
    fm = bpy.data.materials.new("review_floor")
    fm.use_nodes = True
    fm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.42, 0.40, 0.37, 1)
    floor.data.materials.append(fm)
    extras.append(floor)
    bpy.ops.object.light_add(type="SUN")
    sun = bpy.context.object
    sun.data.energy = 3.0
    sun.data.angle = math.radians(12)
    sun.rotation_euler = (math.radians(48), math.radians(8), math.radians(-32))
    extras.append(sun)
    bpy.ops.object.camera_add()
    camera = bpy.context.object
    scene.camera = camera
    extras.append(camera)
    sheets = {
        "sheet_1_desk": ["bell", "pager", "notebook", "pencil", "spools", "cassette", "tags", "keycards"],
        "sheet_2_table": ["tape_reel", "stamp", "palette", "gloves", "folded_cloth", "clipboard", "tape_measure", "portal_tags"],
        "sheet_3_boxes": ["artifact_box", "antique_box", "recorder", "helmet", "paint_cans", "word_tiles", "wedges", "cable_bundle"],
        "sheet_4_floor": ["tool_case", "briefcase", "bag", "storage_crate"],
        "sheet_6_tall": ["service_cart", "antenna", "microphone"],
        "sheet_5_board": ["rule_board"],
    }
    seen = set()
    for sheet, names in sheets.items():
        for objs in objects.values():
            for o in objs:
                o.hide_render = True
        x, y, row_depth = 0.0, 0.0, 0.0
        low_all, high_all = Vector((1e9,) * 3), Vector((-1e9,) * 3)
        moved = []
        per_row = 4 if len(names) > 4 else len(names)
        for index, name in enumerate(names):
            seen.add(name)
            objs = objects[name]
            if index and index % per_row == 0:
                x, y, row_depth = 0.0, y - row_depth - 0.06, 0.0
            low, high = bounds(objs)
            lift = -low.z if name == "rule_board" else 0.0
            shift = Vector((x - low.x, y - high.y, lift))
            for o in objs:
                o.location += shift
                o.hide_render = False
                moved.append((o, shift))
            bpy.context.view_layer.update()
            low, high = bounds(objs)
            low_all = Vector(map(min, low_all, low))
            high_all = Vector(map(max, high_all, high))
            x = high.x + max(0.05, (high.x - low.x) * 0.2)
            row_depth = max(row_depth, high.y - low.y)
        centre = (low_all + high_all) / 2
        radius = (high_all - low_all).length / 2
        camera.data.lens = 60
        fov = 2 * math.atan(min(36.0, 36.0 * 1000 / 1600) / (2 * 60))
        dist = radius / math.tan(fov / 2) * 0.66
        aim = Vector((0.22, -0.78, 0.58)).normalized()
        camera.location = centre + aim * dist
        camera.rotation_euler = (centre - camera.location).to_track_quat("-Z", "Y").to_euler()
        camera.data.clip_start = 0.01
        scene.render.filepath = str(OUT / (sheet + ".png"))
        bpy.ops.render.render(write_still=True)
        # The same sheet from above, so plan outlines and holes can be read.
        aim = Vector((0.0, -0.12, 1.0)).normalized()
        camera.location = centre + aim * dist
        camera.rotation_euler = (centre - camera.location).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = str(OUT / (sheet + "_top.png"))
        bpy.ops.render.render(write_still=True)
        for o, shift in moved:
            o.location -= shift
    assert seen == set(objects), set(objects) - seen
    for objs in objects.values():
        for o in objs:
            o.hide_render = False
    for o in extras:
        bpy.data.objects.remove(o)
    bpy.context.view_layer.update()


def export(objects, rows):
    blend = ROOT / "art/blender/case_props.blend"
    glb = ROOT / "game/assets/props/case_props.glb"
    bpy.ops.wm.save_as_mainfile(filepath=str(blend), check_existing=False, compress=True)
    bpy.ops.object.select_all(action="DESELECT")
    for objs in objects.values():
        for o in objs:
            o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(glb), export_format="GLB", use_selection=True, export_yup=True,
                              export_apply=True, export_normals=True, export_tangents=True, export_texcoords=True,
                              export_materials="NONE", export_animations=False)
    assemblies, total = [], 0
    for asm in ORDER:
        low, high = bounds(objects[asm])
        tris = sum(r["triangles"] for r in rows[asm])
        total += tris
        # Godot frame: x = x, y = z, z = -y.
        for r in rows[asm]:
            if "pivot_blender" in r:
                p = r.pop("pivot_blender")
                r["pivot"] = [p[0], p[2], -p[1]]
        assemblies.append({"id": asm, "note": INFO[asm]["note"], "triangles": tris,
                           "bounds": [[round(low.x, 4), round(low.z, 4), round(-high.y, 4)], [round(high.x, 4), round(high.z, 4), round(-low.y, 4)]],
                           "parts": rows[asm]})
    data = {"schema_version": 1, "asset": "res://assets/props/case_props.glb",
            "source": "art/blender/scripts/build_case_props.py", "seed": SEED,
            "uv": "metres divided by the catalogue material's meters_per_tile; uv1_scale stays 1",
            "triangles_total": total, "assemblies": assemblies}
    (ROOT / "game/data/orison_v2/case_props.json").write_text(json.dumps(data, indent=1) + "\n", encoding="utf-8", newline="\n")
    print("[CASE PROPS] %d assemblies, %d mesh parts, %d triangles" % (len(assemblies), sum(len(r) for r in rows.values()), total))
    for a in assemblies:
        size = [round(a["bounds"][1][i] - a["bounds"][0][i], 3) for i in range(3)]
        print("  %-14s %5d tris  %2d parts  size %s" % (a["id"], a["triangles"], len(a["parts"]), size))


objects, rows = realise()
if "--no-review" not in sys.argv:
    review(objects)
export(objects, rows)
