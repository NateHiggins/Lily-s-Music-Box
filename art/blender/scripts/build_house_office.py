"""The house office in common room B, for V2: the dead-letters sorting desk and
the maintenance headquarters (Lily, v1r_first_floor_layout_20261111).

V1 drew the post tray, the workbench, the gear wall and the trophy sockets as
tinted BoxMesh/CylinderMesh placeholders and played dead letters on a screen
panel. This library is the same furniture at true size, built from named
stock with metre UV charts already divided by each catalogue material's tile.
The parts the hand or the case count moves are separate objects on their own
origins: the tray, the rail carriage, one letter, each of the six tools and
one trophy token.

Deterministic: fixed seed, no clock, no randomness outside rng(). Blender is
Z-up metres with the wall behind at y = 0 and the room toward -Y; the glTF
exporter converts to Godot's Y-up once (the room becomes +Z).

  blender -b --python-exit-code 1 -P art/blender/scripts/build_house_office.py -- <review_dir>

Writes game/assets/props/house_office.glb, art/blender/house_office.blend and
game/data/orison_v2/house_office.json; review renders go to <review_dir>.
No material or texture is exported: Godot binds catalogue materials by key.
The construction helpers follow build_case_props.py.
"""
import bpy, bmesh, json, math, sys
from mathutils import Vector, Matrix, Euler
from pathlib import Path

SEED = 1928
ROOT = next(p for p in Path(__file__).resolve().parents if (p / "game/project.godot").is_file())
OUT = Path(sys.argv[sys.argv.index("--") + 1]) if "--" in sys.argv else ROOT / "house_office_review"
OUT.mkdir(parents=True, exist_ok=True)
CATALOGUE = json.loads((ROOT / "game/data/runtime_material_sets.json").read_text(encoding="utf-8"))["materials"]
TEXTURES = ROOT / "game/assets/building/textures"
# Which texture axis the grain of a wood map runs along (fabrication_grain.py).
GRAIN_AXIS = {"wood_dark": 1, "oak_quartered": 1, "oak_work_surface": 1}
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


def pivot(component, at):
    """A separately exported part: its origin sits on `at`."""
    PIVOTS[(_current[0], component)] = Vector(at)


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
# The house office. Dimensions are metres. Every assembly stands against a
# wall: the wall plane is y = 0, the room is toward -Y, the floor is z = 0.
# ---------------------------------------------------------------------------
MEASURES = {}

DESK_TOP = 0.76
RACK_BASE = DESK_TOP + 0.10
RACK_X0 = -0.575
COLUMN_PITCH = 0.265
ROW_PITCH = 0.13
RAIL_Y = -0.33
TRAY_X = -0.76
CARRIAGE_X = -0.585
DEAD_X = 0.73
LETTER = (0.23, 0.004, 0.13)


def godot(p):
    """Blender (x, y, z) to Godot (x, y, z): the exporter's own conversion."""
    return [round(p[0], 5), round(p[2], 5), round(-p[1], 5)]


def sorting_desk():
    begin("sorting_desk", "dead letters: desk, pigeonhole rack, dead-letter box, tray, rail, carriage and one letter")
    oak = "oak_quartered"
    d = DESK_TOP
    # The desk: a plain oak table with a foot rail.
    box(oak, (1.90, 0.66, 0.035), (0, -0.33, d - 0.0175))
    for x in (-0.90, 0.90):
        for y in (-0.05, -0.61):
            box(oak, (0.06, 0.06, d - 0.035), (x, y, (d - 0.035) / 2))
        box(oak, (0.022, 0.50, 0.10), (x, -0.33, d - 0.085))
        box(oak, (0.04, 0.50, 0.04), (x, -0.33, 0.15))
    for y in (-0.05, -0.61):
        box(oak, (1.74, 0.022, 0.10), (0, y, d - 0.085))
    box(oak, (1.76, 0.04, 0.04), (0, -0.33, 0.15))
    # The rack: a plinth, four stacks of six holes, a cap. Floor six is the top row.
    width = 4 * COLUMN_PITCH + 0.015
    cx = RACK_X0 + width / 2
    height = 6 * ROW_PITCH
    box(oak, (width, 0.21, 0.10), (cx, -0.105, d + 0.05))
    box(oak, (width + 0.02, 0.012, 0.014), (cx, -0.216, d + 0.093))
    box(oak, (width, 0.010, height), (cx, -0.005, RACK_BASE + height / 2))
    for i in range(5):
        box(oak, (0.015, 0.21, height), (RACK_X0 + 0.0075 + i * COLUMN_PITCH, -0.115, RACK_BASE + height / 2))
    for j in range(6):
        box(oak, (width - 0.004, 0.204, 0.012), (cx, -0.112, RACK_BASE + 0.006 + j * ROW_PITCH))
    box(oak, (width + 0.02, 0.235, 0.015), (cx, -0.1125, RACK_BASE + height + 0.0075))
    rows, stops, labels = [], [], []
    for r in range(6):
        fascia_z = RACK_BASE + r * ROW_PITCH + 0.118
        box(oak, (width, 0.006, 0.024), (cx, -0.2215, fascia_z))
        rows.append(round(RACK_BASE + 0.012 + r * ROW_PITCH + 0.002 - (d + 0.016), 5))
        row_labels = []
        for c in range(4):
            hole_x = RACK_X0 + 0.015 + 0.125 + c * COLUMN_PITCH
            box("paper:cream", (0.21, 0.001, 0.018), (hole_x, -0.2250, fascia_z))
            row_labels.append(godot((hole_x, -0.2262, fascia_z)))
            if r == 0:
                stops.append(round(hole_x, 5))
        labels.append(row_labels)
    # The dead-letter box: a slot and nothing behind it.
    box(oak, (0.015, 0.24, 0.30), (DEAD_X - 0.1525, -0.12, d + 0.15))
    box(oak, (0.015, 0.24, 0.30), (DEAD_X + 0.1525, -0.12, d + 0.15))
    box(oak, (0.29, 0.010, 0.30), (DEAD_X, -0.005, d + 0.15))
    box(oak, (0.34, 0.25, 0.015), (DEAD_X, -0.125, d + 0.3075))
    box(oak, (0.29, 0.012, 0.15), (DEAD_X, -0.232, d + 0.075))
    box(oak, (0.29, 0.012, 0.115), (DEAD_X, -0.232, d + 0.2425))
    box(oak, (0.29, 0.20, 0.006), (DEAD_X, -0.12, d + 0.14))
    for z in (d + 0.146, d + 0.189):
        box("brass", (0.27, 0.004, 0.008), (DEAD_X, -0.240, z))
    box("paper:cream", (0.22, 0.001, 0.032), (DEAD_X, -0.2385, d + 0.245))
    # The rail along the foot of the rack, with a stop at each end.
    box("brass", (1.42, 0.012, 0.006), (0.095, RAIL_Y, d + 0.003))
    for x in (-0.615, 0.805):
        box("brass", (0.012, 0.022, 0.016), (x, RAIL_Y, d + 0.008))
    # The tally slip, lying at the right of the desk.
    box("paper:cream", (0.34, 0.24, 0.002), (0.72, -0.525, d + 0.001))
    # The tray: blackened sheet iron, high at the back, low where the post leaves it.
    iron = "iron_blackened"
    box(iron, (0.27, 0.19, 0.004), (TRAY_X, RAIL_Y, d + 0.002), comp="Tray")
    box(iron, (0.27, 0.006, 0.07), (TRAY_X, RAIL_Y + 0.092, d + 0.035), comp="Tray")
    box(iron, (0.27, 0.006, 0.022), (TRAY_X, RAIL_Y - 0.092, d + 0.011), comp="Tray")
    box(iron, (0.006, 0.178, 0.035), (TRAY_X - 0.132, RAIL_Y, d + 0.0175), comp="Tray")
    box(iron, (0.006, 0.178, 0.012), (TRAY_X + 0.132, RAIL_Y, d + 0.006), comp="Tray")
    tube("brass", [(TRAY_X - 0.04, RAIL_Y - 0.094, d + 0.012), (TRAY_X - 0.04, RAIL_Y - 0.122, d + 0.012),
                   (TRAY_X + 0.04, RAIL_Y - 0.122, d + 0.012), (TRAY_X + 0.04, RAIL_Y - 0.094, d + 0.012)], 0.0035, comp="Tray")
    pivot("Tray", (TRAY_X, RAIL_Y, d))
    # The carriage: a brass clip that rides the rail and holds one letter on edge.
    box("brass", (0.06, 0.030, 0.010), (CARRIAGE_X, RAIL_Y, d + 0.011), comp="Carriage")
    box("brass", (0.06, 0.003, 0.030), (CARRIAGE_X, RAIL_Y + 0.0045, d + 0.031), comp="Carriage")
    box("brass", (0.06, 0.003, 0.012), (CARRIAGE_X, RAIL_Y - 0.0045, d + 0.022), comp="Carriage")
    pivot("Carriage", (CARRIAGE_X, RAIL_Y, d + 0.006))
    # One letter, standing in the carriage: its origin is the middle of its lower edge.
    foot = (CARRIAGE_X, RAIL_Y, d + 0.016)
    box("paper", LETTER, (foot[0], foot[1], foot[2] + LETTER[2] / 2), comp="Letter")
    plate("paper", [(-0.115, 0.13), (0.115, 0.13), (0, 0.058)], -0.0028, -0.002, at=foot, rot=(90, 0, 0), comp="Letter")
    pivot("Letter", foot)
    MEASURES["sorting"] = {
        "tray": godot((TRAY_X, RAIL_Y - LETTER[2] / 2, d + 0.004)),
        "rail": godot((TRAY_X, RAIL_Y, d + 0.016)),
        "carriage_home": round(CARRIAGE_X - TRAY_X, 5),
        "stops": [round(x - TRAY_X, 5) for x in stops],
        "dead_stop": round(DEAD_X - TRAY_X, 5),
        "dead_lift": round(d + 0.152 - (d + 0.016), 5),
        "rows": rows,
        "hole_front": -0.09,
        "dead_front": -0.075,
        "sheet": LETTER[1],
        "astray": godot((TRAY_X, RAIL_Y + 0.078, d + 0.006)),
        "row_labels": labels,
        "dead_label": godot((DEAD_X, -0.2395, d + 0.245)),
        "tally": godot((0.72, -0.525, d + 0.0026)),
        "tally_width": 0.31,
    }


def hq_bench():
    begin("hq_bench", "maintenance headquarters: workbench, tool board, shelves and the six issued tools")
    top = 0.89
    box("oak_work_surface", (2.30, 0.66, 0.05), (0, -0.33, top - 0.025))
    iron = "cast_iron"
    for x in (-1.05, 1.05):
        for y in (-0.07, -0.59):
            box(iron, (0.05, 0.05, top - 0.05), (x, y, (top - 0.05) / 2))
        box(iron, (0.064, 0.64, 0.035), (x, -0.33, 0.0175))
        box(iron, (0.04, 0.47, 0.04), (x, -0.33, top - 0.07))
    box(iron, (2.05, 0.03, 0.03), (0, -0.33, 0.22))
    box("wood_dark", (2.04, 0.02, 0.09), (0, -0.60, top - 0.095))
    # A bench vice at the right-hand corner.
    box(iron, (0.09, 0.15, 0.06), (0.86, -0.56, top + 0.03))
    box(iron, (0.12, 0.022, 0.055), (0.86, -0.642, top + 0.0825))
    box(iron, (0.12, 0.022, 0.055), (0.86, -0.60, top + 0.0825))
    tube("nickel_plated", [(0.86, -0.60, top + 0.04), (0.86, -0.72, top + 0.04)], 0.008)
    tube("nickel_plated", [(0.80, -0.715, top + 0.04), (0.92, -0.715, top + 0.04)], 0.004)
    # The painted board, the shelf at its foot and the shelf over it.
    box("trim", (2.36, 0.02, 1.10), (0, -0.01, 1.50))
    box("wood_dark", (2.36, 0.14, 0.022), (0, -0.09, 1.04))
    box("wood_dark", (2.44, 0.24, 0.025), (0, -0.12, 2.0625))
    for x in (-0.95, 0.95):
        box(iron, (0.02, 0.012, 0.18), (x, -0.026, 1.955))
        box(iron, (0.02, 0.18, 0.012), (x, -0.11, 2.044))
    columns = (-0.76, 0.0, 0.76)
    row_z = (1.36, 1.78)
    face = -0.02
    cards = []
    for index in range(6):
        x, z = columns[index % 3], row_z[index // 3]
        card_z = z - 0.165
        box("paper:cream", (0.30, 0.001, 0.034), (x, face - 0.0005, card_z))
        cards.append(godot((x, face - 0.0018, card_z)))

    def peg(x, z, reach=0.07):
        tube("brass", [(x, face, z), (x, face - reach, z), (x, face - reach - 0.006, z + 0.012)], 0.003)
    # 0. Inspection light: a nickel hand torch hung head-up on two pegs.
    x, z = columns[0], row_z[0]
    peg(x - 0.022, z + 0.04)
    peg(x + 0.022, z + 0.04)
    lathe("nickel_plated", [(0, -0.115), (0.014, -0.115), (0.016, -0.108), (0.016, 0.046), (0.027, 0.074), (0.028, 0.086), (0.024, 0.086)],
          at=(x, face - 0.045, z), comp="Gear_light")
    lathe("brass", [(0.0165, -0.03), (0.019, -0.03), (0.019, -0.01), (0.0165, -0.01)], at=(x, face - 0.045, z), comp="Gear_light")
    lathe("milk_glass", [(0.024, 0.084), (0.012, 0.089, "s"), (0, 0.090, "s")], at=(x, face - 0.045, z), comp="Gear_light")
    pivot("Gear_light", (x, face, z))
    # 1. Ontological tape: a roll of cloth tape on a peg.
    x, z = columns[1], row_z[0]
    peg(x, z)
    lathe("linen:tape", [(0.028, -0.014), (0.058, -0.014), (0.058, 0.014), (0.028, 0.014), (0.028, -0.014)],
          at=(x, face - 0.045, z - 0.025), rot=(90, 0, 0), segs=20, comp="Gear_tape")
    pivot("Gear_tape", (x, face, z))
    # 2. Resonance fork: a steel fork hung by its crotch.
    x, z = columns[2], row_z[0]
    peg(x, z + 0.004, 0.05)
    crotch = (x, face - 0.035, z)
    tube("nickel_plated", smooth([(crotch[0] - 0.012, crotch[1], crotch[2] + 0.13), (crotch[0] - 0.012, crotch[1], crotch[2] + 0.02),
                                  (crotch[0] - 0.008, crotch[1], crotch[2] + 0.005), (crotch[0], crotch[1], crotch[2] - 0.002),
                                  (crotch[0] + 0.008, crotch[1], crotch[2] + 0.005), (crotch[0] + 0.012, crotch[1], crotch[2] + 0.02),
                                  (crotch[0] + 0.012, crotch[1], crotch[2] + 0.13)], steps=3), 0.0038, comp="Gear_fork")
    tube("nickel_plated", [(crotch[0], crotch[1], crotch[2] - 0.002), (crotch[0], crotch[1], crotch[2] - 0.085)], 0.0042, comp="Gear_fork")
    lathe("nickel_plated", [(0, -0.008), (0.007, -0.004, "s"), (0.007, 0.004, "s"), (0, 0.008, "s")],
          at=(crotch[0], crotch[1], crotch[2] - 0.09), segs=8, comp="Gear_fork")
    pivot("Gear_fork", (x, face, z))
    # 3. Seam stapler: a heavy desk stapler on a bracket shelf.
    x, z = columns[0], row_z[1]
    box("wood_dark", (0.26, 0.11, 0.014), (x, face - 0.055, z - 0.007))
    black = "iron_blackened"
    box(black, (0.18, 0.05, 0.012), (x, face - 0.055, z + 0.006), comp="Gear_stapler")
    box(black, (0.03, 0.044, 0.05), (x - 0.072, face - 0.055, z + 0.03), comp="Gear_stapler")
    box(black, (0.17, 0.036, 0.024), (x + 0.004, face - 0.055, z + 0.052), rot=(0, 7, 0), comp="Gear_stapler")
    lathe("nickel_plated", [(0, 0), (0.014, 0), (0.016, 0.008), (0.010, 0.016, "s"), (0, 0.018, "s")],
          at=(x + 0.068, face - 0.055, z + 0.054), comp="Gear_stapler")
    pivot("Gear_stapler", (x, face, z))
    # 4. Survey prism: a glass prism in a brass cradle on a bracket shelf.
    x, z = columns[1], row_z[1]
    box("wood_dark", (0.26, 0.11, 0.014), (x, face - 0.055, z - 0.007))
    box("brass", (0.10, 0.09, 0.006), (x, face - 0.055, z + 0.003), comp="Gear_prism")
    for y in (face - 0.092, face - 0.018):
        box("brass", (0.012, 0.008, 0.022), (x - 0.036, y, z + 0.016), comp="Gear_prism")
        box("brass", (0.012, 0.008, 0.022), (x + 0.036, y, z + 0.016), comp="Gear_prism")
    plate("glass_cut", [(-0.036, 0.0), (0.036, 0.0), (0.0, 0.062)], -0.035, 0.035, at=(x, face - 0.055, z + 0.007), rot=(90, 0, 0), comp="Gear_prism")
    pivot("Gear_prism", (x, face, z))
    # 5. Orison master key: a long brass key hung by its bow.
    x, z = columns[2], row_z[1]
    peg(x, z, 0.04)
    hang = face - 0.03
    tube("brass", [(x + 0.017 * math.cos(math.tau * k / 12), hang, z - 0.014 + 0.017 * math.sin(math.tau * k / 12)) for k in range(12)],
         0.0032, closed=True, comp="Gear_key")
    tube("brass", [(x, hang, z - 0.031), (x, hang, z - 0.15)], 0.0036, comp="Gear_key")
    lathe("brass", [(0.0036, -0.004), (0.006, -0.004), (0.006, 0.004), (0.0036, 0.004)], at=(x, hang, z - 0.045), segs=8, comp="Gear_key")
    box("brass", (0.020, 0.003, 0.024), (x + 0.012, hang, z - 0.136), comp="Gear_key")
    box("brass", (0.008, 0.003, 0.008), (x + 0.018, hang, z - 0.120), comp="Gear_key")
    pivot("Gear_key", (x, face, z))
    MEASURES["bench"] = {"cards": cards}


def plaque():
    begin("plaque", "brass plaque: a black field between two screws; the words are lettered at runtime")
    plate("brass", rounded(0.92, 0.15, 0.03), 0.0, 0.008, rot=(90, 0, 0))
    box("bakelite_black", (0.80, 0.002, 0.10), (0, -0.009, 0))
    for z in (-0.053, 0.053):
        box("brass", (0.812, 0.004, 0.006), (0, -0.010, z))
    for x in (-0.403, 0.403):
        box("brass", (0.006, 0.004, 0.112), (x, -0.010, 0))
    for x in (-0.432, 0.432):
        lathe("brass", [(0, 0), (0.009, 0)] + dome(0.009, 0.004), at=(x, -0.008, 0), rot=(90, 0, 0), segs=10)
    MEASURES["plaque"] = {"words": godot((0, -0.0105, 0)), "width": 0.76}


def trophy_wall():
    begin("trophy_wall", "trophy wall: a walnut board of eighteen brass sockets and one porcelain token")
    box("wood_dark", (2.30, 0.022, 1.30), (0, -0.011, 1.45))
    for z in (0.78, 2.12):
        box("oak_quartered", (2.38, 0.035, 0.04), (0, -0.0175, z))
    for x in (-1.17, 1.17):
        box("oak_quartered", (0.04, 0.034, 1.30), (x, -0.017, 1.45))
    pitch = (0.36, 0.38)
    first = (-2.5 * pitch[0], 1.07)
    for row in range(3):
        for col in range(6):
            lathe("brass", [(0.108, 0.0), (0.104, 0.014), (0.090, 0.014), (0.086, 0.004), (0, 0.004)],
                  at=(first[0] + col * pitch[0], -0.022, first[1] + row * pitch[1]), rot=(90, 0, 0), segs=16)
    seat = (first[0], -0.026, first[1])
    lathe("porcelain", [(0, 0), (0.082, 0), (0.082, 0.010), (0.070, 0.018, "s"), (0, 0.022, "s")], at=seat, rot=(90, 0, 0), segs=16, comp="Token")
    pivot("Token", seat)
    MEASURES["trophies"] = {"columns": 6, "rows": 3, "pitch": [pitch[0], pitch[1]], "status": godot((0, -0.0235, 2.03))}


BUILDERS = [sorting_desk, hq_bench, plaque, trophy_wall]

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
    scene.cycles.samples = 32
    scene.cycles.use_denoising = True
    scene.render.resolution_x, scene.render.resolution_y = 1400, 1000
    world = bpy.data.worlds.new("review")
    scene.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.30, 0.29, 0.27, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.8
    extras = []
    for rotation, at in (((0, 0, 0), (0, 0, 0)), ((math.radians(90), 0, 0), (0, 0.001, 5))):
        bpy.ops.mesh.primitive_plane_add(size=20, location=at, rotation=rotation)
        plane = bpy.context.object
        finish = bpy.data.materials.new("review_room")
        finish.use_nodes = True
        finish.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.52, 0.50, 0.45, 1)
        plane.data.materials.append(finish)
        extras.append(plane)
    bpy.ops.object.light_add(type="SUN")
    sun = bpy.context.object
    sun.data.energy = 3.0
    sun.data.angle = math.radians(14)
    sun.rotation_euler = (math.radians(52), math.radians(6), math.radians(24))
    extras.append(sun)
    bpy.ops.object.camera_add()
    camera = bpy.context.object
    camera.data.lens = 40
    camera.data.clip_start = 0.01
    scene.camera = camera
    extras.append(camera)
    # (sheet, assemblies, eye, target)
    sheets = [
        ("desk_standing", ["sorting_desk"], (0.5, -2.1, 1.62), (0.0, -0.15, 1.05)),
        ("desk_close", ["sorting_desk"], (-0.55, -1.05, 1.45), (-0.35, -0.25, 0.86)),
        ("desk_side", ["sorting_desk"], (1.9, -1.2, 1.3), (0.2, -0.25, 0.95)),
        ("bench_standing", ["hq_bench", "plaque"], (0.6, -2.7, 1.62), (0.0, 0.0, 1.35)),
        ("bench_tools", ["hq_bench"], (0.2, -1.25, 1.6), (0.0, 0.0, 1.55)),
        ("trophy_standing", ["trophy_wall"], (0.7, -2.6, 1.62), (0.0, 0.0, 1.45)),
        ("trophy_close", ["trophy_wall", "plaque"], (-0.5, -0.7, 1.2), (-0.8, 0.0, 1.1)),
    ]
    lifts = {"plaque": Vector((0, 0, 2.30))}
    for sheet, names, eye, target in sheets:
        for asm, objs in objects.items():
            for o in objs:
                o.hide_render = asm not in names
                if asm in lifts:
                    o.location += lifts[asm]
        bpy.context.view_layer.update()
        camera.location = eye
        camera.rotation_euler = (Vector(target) - Vector(eye)).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = str(OUT / (sheet + ".png"))
        bpy.ops.render.render(write_still=True)
        for asm, objs in objects.items():
            for o in objs:
                if asm in lifts:
                    o.location -= lifts[asm]
    for objs in objects.values():
        for o in objs:
            o.hide_render = False
    for o in extras:
        bpy.data.objects.remove(o)
    bpy.context.view_layer.update()


def export(objects, rows):
    blend = ROOT / "art/blender/house_office.blend"
    glb = ROOT / "game/assets/props/house_office.glb"
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
        parts = []
        for r in rows[asm]:
            total += r["triangles"]
            part = {"name": r["name"], "component": r["component"], "material": r["material"]}
            if "tint" in r:
                part["tint"] = r["tint"]
            parts.append(part)
        low, high = bounds(objects[asm])
        print("  %-14s %5d tris  %2d parts  size %s" % (asm, sum(r["triangles"] for r in rows[asm]), len(parts),
                                                      [round(high[i] - low[i], 3) for i in range(3)]))
        assemblies.append({"id": asm, "parts": parts})
    data = {"schema_version": 1, "asset": "res://assets/props/house_office.glb", "assemblies": assemblies}
    data.update(MEASURES)
    (ROOT / "game/data/orison_v2/house_office.json").write_text(json.dumps(data, indent=1) + "\n", encoding="utf-8", newline="\n")
    print("[HOUSE OFFICE] %d assemblies, %d mesh parts, %d triangles" % (len(assemblies), sum(len(r) for r in rows.values()), total))


objects, rows = realise()
if "--no-review" not in sys.argv:
    review(objects)
export(objects, rows)
