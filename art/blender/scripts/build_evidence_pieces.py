"""The evidence pieces of the temporal loop, the newspaper bundle and the map pin.

Eleven leads in game/data/temporal/anchors.json each end in one piece of
evidence. Each is a small real object here: thin curled paper with thickness,
card, glass, leather, a turned button, drawn wire. Two general pieces serve
the case wall: a tied bundle of folded newspapers and a round-headed map pin.

Every piece is modelled lying face up (u right, v up the page, w out of the
face) and is exported so that in Godot its origin is the centre of its back
face, +Z is its face normal and +Y is up when it hangs on a wall. The pin is
the one exception: its origin is where the shaft enters the wall, and the
point lies behind it. Charts are metres divided by the catalogue material's
tile. No material or texture is exported: Godot binds catalogue materials by
key, tinted from the data file.

Deterministic: fixed seed, no clock, no randomness outside rng().

  blender -b --python-exit-code 1 -P art/blender/scripts/build_evidence_pieces.py -- <review_dir>

Writes game/assets/props/evidence_pieces.glb, art/blender/evidence_pieces.blend
and game/data/orison_v2/evidence_pieces.json; review renders go to <review_dir>.
"""
import bpy, bmesh, json, math, sys
from bisect import bisect_right
from mathutils import Vector, Matrix, Euler
from pathlib import Path

SEED = 1929
ROOT = next(p for p in Path(__file__).resolve().parents if (p / "game/project.godot").is_file())
OUT = Path(sys.argv[sys.argv.index("--") + 1]) if "--" in sys.argv else ROOT / "evidence_pieces_review"
OUT.mkdir(parents=True, exist_ok=True)
CATALOGUE = json.loads((ROOT / "game/data/runtime_material_sets.json").read_text(encoding="utf-8"))["materials"]
TEXTURES = ROOT / "game/assets/building/textures"
GLASS = "glassish"   # the house glazing route, bound at runtime; not a catalogue row
GLASS_TILE = 0.128
GRAIN_AXIS = {"wood_dark": 1}
TINTS = {
    "cream": (0.98, 0.96, 0.92), "slip": (1.0, 0.84, 0.82), "newsprint": (0.76, 0.76, 0.74),
    "manila": (0.86, 0.70, 0.46), "card": (0.50, 0.48, 0.46), "glassine": (0.90, 0.94, 0.98),
    "ink": (0.13, 0.15, 0.26), "kid": (0.98, 0.96, 0.90), "pearl": (0.97, 0.95, 0.92),
    "string": (0.72, 0.58, 0.38), "thread": (0.22, 0.20, 0.18), "red": (0.70, 0.07, 0.06),
}
ALPHA = {"glassine": 0.6}
# Drawn after the pane it wraps: two blended surfaces at one place need an order.
SORTING = {"glassine": 0.02}

PARTS = {}    # (piece, key, tint) -> bmesh, in model space (u, v, w)
ORDER = []
KEEP_W = set()
_current = [None]
_count = [0]


def rng(i, salt=0):
    return (math.sin(i * 12.9898 + salt * 78.233 + SEED) * 43758.5453) % 1.0


def begin(name, keep_w=False):
    _current[0] = name
    ORDER.append(name)
    if keep_w:
        KEEP_W.add(name)


def _bm(key):
    base, tint = key.split(":") if ":" in key else (key, "")
    assert base == GLASS or base in CATALOGUE, base
    assert tint == "" or tint in TINTS, tint
    slot = (_current[0], base, tint)
    if slot not in PARTS:
        bm = bmesh.new()
        bm.loops.layers.uv.new("UVMap")
        PARTS[slot] = bm
    tile = GLASS_TILE if base == GLASS else float(CATALOGUE[base]["meters_per_tile"])
    return PARTS[slot], tile, GRAIN_AXIS.get(base, 0)


def _xf(at, rot):
    return Matrix.Translation(Vector(at)) @ Euler([math.radians(a) for a in rot], "XYZ").to_matrix().to_4x4()


def _offset():
    _count[0] += 1
    return Vector((rng(_count[0], 1), rng(_count[0], 2)))


def _face(bm, m, pts, uvs, smooth):
    _poly(bm, [bm.verts.new(m @ Vector(p)) for p in pts], uvs, smooth)


def _poly(bm, verts, uvs, smooth):
    try:
        f = bm.faces.new(verts)
    except ValueError:
        return
    f.smooth = smooth
    layer = bm.loops.layers.uv.active
    for loop, uv in zip(f.loops, uvs):
        loop[layer].uv = uv


def box(key, size, at=(0, 0, 0), rot=(0, 0, 0)):
    """Sawn or pressed stock centred on `at`; grain along its longest side."""
    bm, tile, grain = _bm(key)
    m = _xf(at, rot)
    h = [s * 0.5 for s in size]
    long_axis = max(range(3), key=lambda i: size[i])
    off = _offset()
    for axis in range(3):
        a, b = [i for i in range(3) if i != axis]
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
            cyc = (axis + 1) % 3 == a
            if (sign > 0) != cyc:
                corners.reverse()
            uvs = [Vector((p[ua] / tile, p[va] / tile)) + off + Vector((0.37 * axis, 0.19 * sign)) for p in corners]
            _face(bm, m, corners, uvs, False)


def lathe(key, profile, at=(0, 0, 0), rot=(0, 0, 0), segs=12):
    """Turned stock about local Z. `profile` runs (r, z[, "s"]), outside on the
    right of travel; "s" keeps the joint at that point smooth."""
    bm, tile, _ = _bm(key)
    m = _xf(at, rot)
    off = _offset()
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
            return [bm.verts.new(m @ Vector((math.cos(math.tau * j / segs) * r, math.sin(math.tau * j / segs) * r, z)))
                    for j in range(cols)]
        bottom = prev_top if smooth_joint else ring(r0, z0)
        top = ring(r1, z1)
        for j in range(segs):
            a0 = math.tau * j / segs
            a1 = math.tau * (j + 1) / segs

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
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-7)


def tube(key, path, radius, segs=5, closed=False, at=(0, 0, 0), rot=(0, 0, 0)):
    """Drawn wire, thread or string along `path`: straight lengths mitred at
    each bend, each unwrapped true to its own axis so its tangents are exact."""
    bm, tile, _ = _bm(key)
    m = _xf(at, rot)
    off = _offset()
    pts = [Vector(path[0])]
    for p in path[1:]:
        if (Vector(p) - pts[-1]).length > 1e-6:
            pts.append(Vector(p))
    n = len(pts)
    count = n if closed else n - 1
    dirs = [(pts[(i + 1) % n] - pts[i]).normalized() for i in range(count)]
    normal = dirs[0].orthogonal().normalized()
    frames = []
    for d in dirs:
        normal = (normal - d * normal.dot(d)).normalized()
        frames.append((normal.copy(), d.cross(normal)))

    def mitre(i):
        before = dirs[(i - 1) % count] if (closed or i > 0) else None
        after = dirs[i % count] if (closed or i < count) else None
        if before is None:
            return after
        if after is None:
            return before
        return (before + after).normalized()
    chord = 2 * radius * math.sin(math.pi / segs)
    run = 0.0
    ends = {}
    for i in range(count):
        a, d = pts[i], dirs[i]
        length = (pts[(i + 1) % n] - a).length
        across, up = frames[i]
        cut0, cut1 = mitre(i), mitre(i + 1)
        ring0, ring1, t0s, t1s = [], [], [], []
        for j in range(segs):
            out = (across * math.cos(math.tau * j / segs) + up * math.sin(math.tau * j / segs)) * radius
            t0 = -out.dot(cut0) / d.dot(cut0)
            t1 = length - out.dot(cut1) / d.dot(cut1)
            ring0.append(bm.verts.new(m @ (a + out + d * t0)))
            ring1.append(bm.verts.new(m @ (a + out + d * t1)))
            t0s.append(t0)
            t1s.append(t1)
        for j in range(segs):
            k = (j + 1) % segs
            u0, u1 = chord * j / tile, chord * (j + 1) / tile
            _poly(bm, [ring0[j], ring0[k], ring1[k], ring1[j]],
                  [Vector((u0, (run + t0s[j]) / tile)) + off, Vector((u1, (run + t0s[k]) / tile)) + off,
                   Vector((u1, (run + t1s[k]) / tile)) + off, Vector((u0, (run + t1s[j]) / tile)) + off], True)
        run += length
        if i == 0:
            ends[0] = (ring0, across, up, True)
        if i == count - 1:
            ends[1] = (ring1, across, up, False)
    if not closed:
        for ring, across, up, flip in ends.values():
            verts = list(ring)
            uvs = [Vector((0.5 + 0.5 * math.cos(math.tau * j / segs), 0.5 + 0.5 * math.sin(math.tau * j / segs))) * 2 * radius / tile + off
                   for j in range(segs)]
            if flip:
                verts.reverse()
                uvs.reverse()
            _poly(bm, verts, uvs, False)


def _area(loop):
    return 0.5 * sum(loop[i][0] * loop[(i + 1) % len(loop)][1] - loop[(i + 1) % len(loop)][0] * loop[i][1] for i in range(len(loop)))


def plate(key, outline, z0, z1, at=(0, 0, 0), rot=(0, 0, 0), holes=(), grain_along="x"):
    """Cut card, glass or sheet metal: a 2D outline (with holes) from z0 to z1."""
    bm, tile, grain = _bm(key)
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
    pts = []
    for cx, cy, start in ((w / 2 - r, d / 2 - r, 0), (-w / 2 + r, d / 2 - r, 90), (-w / 2 + r, -d / 2 + r, 180), (w / 2 - r, -d / 2 + r, 270)):
        for k in range(steps + 1):
            a = math.radians(start + 90 * k / steps)
            pts.append((cx + math.cos(a) * r, cy + math.sin(a) * r))
    return pts


def circle(r, n=10, at=(0, 0)):
    return [(at[0] + math.cos(math.tau * k / n) * r, at[1] + math.sin(math.tau * k / n) * r) for k in range(n)]


def smooth(path, steps=4):
    """Catmull-Rom points through `path`, for string that hangs."""
    pts = [Vector(p) for p in path]
    n = len(pts)
    out = []
    for i in range(n - 1):
        p0 = pts[i - 1] if i > 0 else pts[i]
        p1, p2 = pts[i], pts[i + 1]
        p3 = pts[i + 2] if i + 2 < n else pts[i + 1]
        for k in range(steps):
            t = k / steps
            out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t + (-p0 + 3 * p1 - 3 * p2 + p3) * t ** 3))
    out.append(pts[-1])
    return [tuple(p) for p in out]


def span(a, b, n):
    return [a + (b - a) * k / n for k in range(n + 1)]


class Flat:
    """A flat face at height `top` that ink can be laid on."""

    def __init__(self, top, at=(0, 0, 0), yaw=0.0):
        self.m = _xf(at, (0, 0, yaw))
        self.top = top

    def surface(self, u, v):
        return self.top

    def stroke(self, key, a, b, width=0.0007, lift=0.0003, step=0.01):
        """A ruled line or a run of writing from a to b, following the face."""
        bm, tile, _ = _bm(key)
        off = _offset()
        a, b = Vector(a), Vector(b)
        length = (b - a).length
        if length < 1e-6:
            return
        along = (b - a) / length
        side = Vector((-along.y, along.x)) * width * 0.5
        n = max(1, math.ceil(length / step))
        rows = []
        for k in range(n + 1):
            p = a + along * length * k / n
            pair = []
            for q in (p - side, p + side):
                pair.append((bm.verts.new(self.m @ Vector((q.x, q.y, self.surface(q.x, q.y) + lift))), Vector((q.x, q.y)) / tile + off))
            rows.append(pair)
        for k in range(n):
            quad = [rows[k][0], rows[k + 1][0], rows[k + 1][1], rows[k][1]]
            _poly(bm, [q[0] for q in quad], [q[1] for q in quad], not getattr(self, "facets", False))

    def writing(self, key, u0, u1, v, salt, width=0.0008, lift=0.0003, step=0.01, slant=0.0):
        """Words as strokes: runs of ink with gaps, no letters."""
        x, k = u0, 0
        while x < u1 - 0.004:
            word = 0.006 + 0.016 * rng(k, salt)
            end = min(u1, x + word)
            wob = (rng(k, salt + 5) - 0.5) * 0.0012
            self.stroke(key, (x, v + wob + (x - u0) * slant), (end, v + wob + (end - u0) * slant), width, lift, step)
            x = end + 0.0035 + 0.003 * rng(k, salt + 9)
            k += 1

    def blot(self, key, centre, radius, salt, lift=0.00035, n=11):
        """A smudge: an uneven patch lying on the face."""
        bm, tile, _ = _bm(key)
        off = _offset()

        def vert(u, v):
            return bm.verts.new(self.m @ Vector((u, v, self.surface(u, v) + lift))), Vector((u, v)) / tile + off
        mid = vert(*centre)
        ring = []
        for k in range(n):
            r = radius * (0.6 + 0.6 * rng(k, salt))
            ring.append(vert(centre[0] + math.cos(math.tau * k / n) * r * 1.3, centre[1] + math.sin(math.tau * k / n) * r))
        for k in range(n):
            tri = [mid, ring[k], ring[(k + 1) % n]]
            _poly(bm, [t[0] for t in tri], [t[1] for t in tri], True)


class Sheet(Flat):
    """A leaf of paper or leather with real thickness, curled by `height`."""

    def __init__(self, key, us, vs, height=None, thick=0.0002, at=(0, 0, 0), yaw=0.0, edge=None, facets=False):
        self.m = _xf(at, (0, 0, yaw))
        self.us, self.vs, self.thick = us, vs, thick
        self.facets = facets
        height = height or (lambda u, v: 0.0)
        ni, nj = len(us), len(vs)
        self.h = [[height(us[i], vs[j]) for j in range(nj)] for i in range(ni)]
        bm, tile, _ = _bm(key)
        off = _offset()
        pos = [[None] * nj for _ in range(ni)]
        for i in range(ni):
            for j in range(nj):
                du, dv = edge(i, j, ni, nj) if edge and (i in (0, ni - 1) or j in (0, nj - 1)) else (0.0, 0.0)
                pos[i][j] = (us[i] + du, vs[j] + dv)
        front = [[bm.verts.new(self.m @ Vector((*pos[i][j], self.h[i][j] + thick))) for j in range(nj)] for i in range(ni)]
        back = [[bm.verts.new(self.m @ Vector((*pos[i][j], self.h[i][j]))) for j in range(nj)] for i in range(ni)]

        def uv(i, j, shift=(0, 0)):
            return Vector(pos[i][j]) / tile + off + Vector(shift)
        for i in range(ni - 1):
            for j in range(nj - 1):
                for tri in (((i, j), (i + 1, j), (i + 1, j + 1)), ((i, j), (i + 1, j + 1), (i, j + 1))):
                    _poly(bm, [front[a][b] for a, b in tri], [uv(a, b) for a, b in tri], not facets)
                    rev = tri[::-1]
                    _poly(bm, [back[a][b] for a, b in rev], [uv(a, b, (0.41, 0.23)) for a, b in rev], not facets)
        rim = [(i, 0) for i in range(ni)] + [(ni - 1, j) for j in range(1, nj)] + \
              [(i, nj - 1) for i in range(ni - 2, -1, -1)] + [(0, j) for j in range(nj - 2, 0, -1)]
        run = 0.0
        for k in range(len(rim)):
            (i0, j0), (i1, j1) = rim[k], rim[(k + 1) % len(rim)]
            p, q = pos[i0][j0], pos[i1][j1]
            d = math.hypot(q[0] - p[0], q[1] - p[1])
            pts = [(*p, self.h[i0][j0]), (*q, self.h[i1][j1]), (*q, self.h[i1][j1] + thick), (*p, self.h[i0][j0] + thick)]
            uvs = [Vector((run, 0)) / tile, Vector((run + d, 0)) / tile, Vector((run + d, thick)) / tile, Vector((run, thick)) / tile]
            _face(bm, self.m, pts, [w + off + Vector((0.57, 0.31)) for w in uvs], False)
            run += d

    def base(self, u, v):
        """The top of the leaf at (u, v), on the triangles it is built from."""
        us, vs, h = self.us, self.vs, self.h
        i = min(max(bisect_right(us, u) - 1, 0), len(us) - 2)
        j = min(max(bisect_right(vs, v) - 1, 0), len(vs) - 2)
        fu = min(max((u - us[i]) / (us[i + 1] - us[i]), 0.0), 1.0)
        fv = min(max((v - vs[j]) / (vs[j + 1] - vs[j]), 0.0), 1.0)
        if fu >= fv:
            return h[i][j] + fu * (h[i + 1][j] - h[i][j]) + fv * (h[i + 1][j + 1] - h[i + 1][j])
        return h[i][j] + fv * (h[i][j + 1] - h[i][j]) + fu * (h[i + 1][j + 1] - h[i][j + 1])

    def surface(self, u, v):
        return self.base(u, v) + self.thick


def curl(w, h, side=0.0015, foot=0.003):
    """A leaf that has lain in a pocket: sides lifting, the foot lifting more."""
    return lambda u, v: side * (2 * u / w) ** 2 + foot * max(0.0, -2 * v / h) ** 2


def torn(depth, salt, sides=("left",)):
    def edge(i, j, ni, nj):
        du = dv = 0.0
        if "left" in sides and i == 0:
            du = depth * rng(j, salt)
        if "right" in sides and i == ni - 1:
            du = -depth * rng(j, salt + 1)
        if "bottom" in sides and j == 0:
            dv = depth * rng(i, salt + 2)
        if "top" in sides and j == nj - 1:
            dv = -depth * rng(i, salt + 3)
        return du, dv
    return edge


def gem_clip(key, at, top_w, back_w, yaw=0.0, radius=0.00045):
    """A wire paper clip gripping a top edge that lies at local y = 0.012."""
    def arc(cx, cy, r, a0, a1, n=5):
        return [(cx + r * math.cos(math.radians(a0 + (a1 - a0) * k / n)), cy + r * math.sin(math.radians(a0 + (a1 - a0) * k / n))) for k in range(n + 1)]
    flat = [(0.002, -0.005), (0.002, 0.008)] + arc(-0.0005, 0.008, 0.0025, 0, 180)[1:] + [(-0.003, -0.012)] + \
        arc(0.0005, -0.012, 0.0035, 180, 360)[1:] + [(0.004, 0.011)]
    over = arc(-0.00025, 0.011, 0.00425, 0, 180)[1:]
    path = [(x, y, top_w) for x, y in flat]
    for k, (x, y) in enumerate(over):
        path.append((x, y, top_w + (back_w - top_w) * (k + 1) / len(over)))
    path.append((-0.0045, -0.004, back_w))
    tube(key, path, radius, segs=5, at=at, rot=(0, 0, yaw))


# ---------------------------------------------------------------------------
# The pieces. Metres; each lies on w = 0 with its face toward +w.
# ---------------------------------------------------------------------------
INK = "paper:ink"


def order_slip():
    begin("order_slip")
    w, h = 0.100, 0.152
    us, vs = span(-w / 2, w / 2, 26), span(-h / 2, h / 2, 8)

    def perforated(i, j, ni, nj):
        return (0.0, 0.0009 if i % 2 else -0.0005) if j == nj - 1 else (0.0, 0.0)
    leaf = Sheet("paper:slip", us, vs, curl(w, h), edge=perforated)
    leaf.stroke(INK, (-0.042, 0.052), (0.042, 0.052), 0.0016)
    leaf.stroke(INK, (-0.042, 0.060), (0.010, 0.060), 0.0030)
    for k in range(8):
        leaf.stroke(INK, (-0.042, 0.036 - 0.012 * k), (0.042, 0.036 - 0.012 * k), 0.0004)
    leaf.stroke(INK, (0.026, 0.048), (0.026, -0.060), 0.0004)
    for k in range(4):
        leaf.writing(INK, -0.039, 0.020, 0.040 - 0.012 * k, 10 + k)
        leaf.stroke(INK, (0.030, 0.040 - 0.012 * k), (0.030 + 0.004 + 0.006 * rng(k, 3), 0.040 - 0.012 * k), 0.0008)
    # The other hand, written across the printed form.
    leaf.writing(INK, -0.034, 0.036, -0.030, 31, width=0.0018, slant=0.34)
    leaf.blot("soot", (0.022, -0.052), 0.011, 41)
    leaf.blot("soot", (-0.030, -0.060), 0.006, 47)


def route_leaf():
    begin("route_leaf")
    w, h, d = 0.078, 0.165, 0.016
    us = span(-w / 2, w / 2 - d, 5) + [w / 2]
    vs = span(-h / 2, h / 2 - d, 18) + [h / 2]
    rag = torn(0.0032, 3)

    def edge(i, j, ni, nj):
        if i == ni - 1 and j == nj - 1:
            return (-0.51 * d, -0.51 * d)   # the corner is folded over
        return rag(i, j, ni, nj)
    lift = curl(w, h, 0.0012, 0.0035)
    leaf = Sheet("paper:cream", us, vs, lift, edge=edge)
    top = max(leaf.surface(w / 2 - d, h / 2 - d), leaf.surface(w / 2 - 0.001, h / 2 - d), leaf.surface(w / 2 - d, h / 2 - 0.001))
    plate("paper:cream", [(w / 2 - d, h / 2 - d), (w / 2, h / 2 - d), (w / 2 - d, h / 2)], top + 0.0003, top + 0.0005)
    for k in range(19):
        leaf.stroke(INK, (-w / 2 + 0.006, 0.064 - 0.0072 * k), (w / 2 - 0.004, 0.064 - 0.0072 * k), 0.0003)
    leaf.stroke(INK, (-w / 2 + 0.016, 0.070), (-w / 2 + 0.016, -0.072), 0.0003)
    for k in range(6):
        leaf.writing(INK, -w / 2 + 0.019, w / 2 - 0.008, 0.0655 - 0.0072 * (k * 2), 20 + k, width=0.0009)
    # Marked across in pencil.
    leaf.stroke(INK, (-0.024, -0.040), (0.026, -0.006), 0.0014)
    leaf.stroke(INK, (-0.022, -0.048), (0.028, -0.016), 0.0011)


def nurse_note():
    begin("nurse_note")
    w, h = 0.127, 0.203
    us, vs = span(-w / 2, 0, 3) + span(0, w / 2, 3)[1:], span(-h / 2, 0, 4) + span(0, h / 2, 4)[1:]
    # Folded in four and opened again: it will not lie flat along either crease.
    leaf = Sheet("paper:cream", us, vs, lambda u, v: 0.0045 * abs(2 * u / w) + 0.0035 * abs(2 * v / h))
    for k in range(21):
        y = 0.084 - 0.0082 * k
        leaf.stroke(INK, (-w / 2 + 0.004, y), (w / 2 - 0.004, y), 0.0003, step=0.0106)
    leaf.stroke(INK, (-w / 2 + 0.022, h / 2 - 0.004), (-w / 2 + 0.022, -h / 2 + 0.004), 0.0004, step=0.0127)
    for k in range(6):
        leaf.writing(INK, -w / 2 + 0.026, w / 2 - 0.010 - 0.02 * rng(k, 8), 0.0855 - 0.0082 * (k + 1), 60 + k, width=0.001, step=0.005)
    leaf.writing(INK, 0.030, 0.050, 0.0855 - 0.0082 * 9, 71, width=0.0011, step=0.005)


def jonah_page():
    begin("jonah_page")
    w, h = 0.170, 0.210
    us, vs = span(-w / 2, w / 2, 10), span(-h / 2, h / 2, 12)
    table = {}

    def crumple(u, v):
        i, j = round((u + w / 2) / w * 10), round((v + h / 2) / h * 12)
        # Smoothed flat by a hand from the left; the right side keeps its ball.
        amount = 0.0012 + 0.0042 * (i / 10) ** 1.5
        return table.setdefault((i, j), amount * rng(i * 13 + j, 7))
    leaf = Sheet("paper:cream", us, vs, crumple, edge=torn(0.0016, 9, ("left", "right", "top", "bottom")), facets=True)
    for k in range(8):
        y = 0.078 - 0.018 * k
        leaf.writing(INK, -0.068, 0.058 - 0.03 * rng(k, 2), y, 80 + k, width=0.0011, lift=0.0007, step=0.003)
    # Struck through.
    leaf.stroke(INK, (-0.070, 0.0425), (0.050, 0.0445), 0.0013, lift=0.0008, step=0.003)
    leaf.stroke(INK, (-0.070, 0.0245), (0.036, 0.0260), 0.0013, lift=0.0008, step=0.003)
    # Beside it.
    for k in range(3):
        leaf.writing(INK, 0.040, 0.078, -0.070 - 0.008 * k, 95 + k, width=0.0009, lift=0.0007, step=0.003, slant=0.12)


def _pearl(at, r, shank):
    """A pearl button: a dished face on a turned back, standing on its shank."""
    z = shank
    lathe("billiard_resin:pearl", [(0, 0), (r * 0.22, 0), (r * 0.22, z), (r * 0.80, z, "s"), (r, z + r * 0.18, "s"),
                                    (r, z + r * 0.30, "s"), (r * 0.84, z + r * 0.42, "s"), (r * 0.45, z + r * 0.34, "s"),
                                    (0, z + r * 0.30, "s")], at=at, segs=14)


def button_leaf():
    begin("button_leaf")
    w, h = 0.092, 0.145
    us, vs = span(-w / 2, w / 2, 6), span(-h / 2, h / 2, 16)
    leaf = Sheet("paper:cream", us, vs, curl(w, h, 0.0014, 0.0026), edge=torn(0.0028, 5))
    for k in range(15):
        leaf.stroke(INK, (-w / 2 + 0.006, 0.058 - 0.0085 * k), (w / 2 - 0.003, 0.058 - 0.0085 * k), 0.0003)
    for x in (-0.026, 0.024, 0.027):
        leaf.stroke(INK, (x, h / 2 - 0.004), (x, -h / 2 + 0.004), 0.0004)
    leaf.writing(INK, -0.040, -0.029, 0.0507, 110, width=0.0009)
    leaf.writing(INK, -0.022, 0.020, 0.0507, 111, width=0.0009)
    leaf.writing(INK, -0.022, 0.012, 0.0422, 112, width=0.0009)
    at = (0.004, -0.012)
    top = leaf.surface(*at)
    _pearl((at[0], at[1], top), 0.0075, 0.0006)
    # The loop of thread that holds it: over the face and down through the leaf.
    crown = top + 0.0006 + 0.0075 * 0.36
    tube("linen:thread", [(at[0] - 0.0022, at[1], top - 0.0004), (at[0] - 0.0020, at[1], crown), (at[0], at[1], crown + 0.0005),
                          (at[0] + 0.0020, at[1], crown), (at[0] + 0.0022, at[1], top - 0.0004)], 0.0004, segs=4)
    tail = smooth([(at[0] + 0.0080, at[1] - 0.001, top + 0.0005), (at[0] + 0.014, at[1] - 0.006, top + 0.0006),
                   (at[0] + 0.011, at[1] - 0.013, top + 0.0006), (at[0] + 0.004, at[1] - 0.012, top + 0.0006),
                   (at[0] + 0.007, at[1] - 0.019, top + 0.0006)], 3)
    tube("linen:thread", [(p[0], p[1], leaf.surface(p[0], p[1]) + 0.0004) for p in tail], 0.0004, segs=4)


def glove_scrap():
    begin("glove_scrap")
    w, h = 0.078, 0.056
    us, vs = span(-w / 2, w / 2, 9), span(-h / 2, h / 2, 6)

    def rip(i, j, ni, nj):
        # The hemmed edge of the cuff is the one straight side left.
        if j == 0:
            return (0.0, 0.0)
        return ((rng(i * 7 + j, 1) - 0.5) * 0.009, (rng(i * 7 + j, 2) - 0.5) * 0.012 - (0.006 if j == nj - 1 else 0.0))
    scrap = Sheet("door_paint:kid", us, vs, lambda u, v: 0.0035 * (2 * u / w) ** 2 + 0.0025 * max(0.0, 2 * v / h) ** 2,
                  thick=0.0009, edge=rip)
    for k in range(9):
        x = -0.034 + 0.0078 * k
        scrap.stroke("linen:thread", (x, -h / 2 + 0.0035), (x + 0.0048, -h / 2 + 0.0035), 0.0007, lift=0.0002, step=0.003)
    at = (0.006, -0.004)
    _pearl((at[0], at[1], scrap.surface(*at)), 0.0058, 0.0022)


def disc_label():
    begin("disc_label")
    w, h, t = 0.127, 0.076, 0.0007
    plate("paper:manila", rounded(w, h, 0.004), 0.0, t, holes=[circle(0.0032, 10, (-0.052, 0.016)), circle(0.0032, 10, (-0.052, -0.016))])
    face = Flat(t)
    for k in range(5):
        face.stroke(INK, (-0.040, 0.024 - 0.012 * k), (0.058, 0.024 - 0.012 * k), 0.0004, step=0.2)
    for x in (-0.040, -0.012, 0.016, 0.058):
        face.stroke(INK, (x, 0.024), (x, -0.024), 0.0004, step=0.2)
    face.stroke(INK, (-0.040, 0.030), (0.020, 0.030), 0.0022, step=0.2)
    for k in range(4):
        face.writing(INK, -0.037, -0.016, 0.018 - 0.012 * k, 130 + k, step=0.2)
        face.writing(INK, -0.009, 0.013, 0.018 - 0.012 * k, 140 + k, step=0.2)
        face.writing(INK, 0.019, 0.054, 0.018 - 0.012 * k, 150 + k, step=0.2)
    gem_clip("nickel_plated", (0.036, h / 2 - 0.012, 0), t + 0.0005, -0.0005)


def dark_slide():
    begin("dark_slide")
    w, h, t = 0.118, 0.165, 0.011
    rail = 0.012
    box("wood_dark", (rail, h, t), (-w / 2 + rail / 2, 0, t / 2))
    box("wood_dark", (rail, h, t), (w / 2 - rail / 2, 0, t / 2))
    box("wood_dark", (w - 2 * rail, 0.020, t + 0.002), (0, h / 2 - 0.010, t / 2 + 0.001))
    box("wood_dark", (w - 2 * rail, rail, t), (0, -h / 2 + rail / 2, t / 2))
    # The back of the holder, and the sheath drawn a little way out of its slot.
    box("iron_blackened", (w - 2 * rail, h - 0.032, 0.0012), (0, -0.004, 0.0020))
    box("iron_blackened", (w - 2 * rail - 0.002, h - 0.014, 0.0012), (0, 0.020, 0.0084))
    box("iron_blackened", (w - 2 * rail + 0.004, 0.009, 0.0045), (0, h / 2 + 0.0215, 0.0084))
    for x in (-0.050, 0.050):
        lathe("iron_blackened", [(0, 0), (0.0022, 0), (0.0022, 0.0008), (0.0012, 0.0014, "s"), (0, 0.0015, "s")], at=(x, 0.030, t), segs=8)
    # Scorched at the foot: char over the rails and the sheath, ragged above.
    top = [(-w / 2 - 0.0005, -h / 2 - 0.0005), (w / 2 + 0.0005, -h / 2 - 0.0005)]
    n = 12
    for k in range(n + 1):
        x = w / 2 + 0.0005 - (w + 0.001) * k / n
        top.append((x, -h / 2 + 0.030 + 0.022 * rng(k, 17)))
    plate("soot", top, t + 0.0002, t + 0.0006)
    plate("soot", [(-w / 2 + rail, -h / 2 + rail), (w / 2 - rail, -h / 2 + rail)] +
          [(w / 2 - rail - (w - 2 * rail) * k / 8, -h / 2 + 0.034 + 0.018 * rng(k, 19)) for k in range(9)], 0.0090, 0.0093)
    box("soot", (w + 0.001, 0.0006, t + 0.0006), (0, -h / 2 - 0.0003, t / 2))
    for sx in (-1, 1):
        box("soot", (0.0006, 0.034, t + 0.0006), (sx * (w / 2 + 0.0003), -h / 2 + 0.017, t / 2))
    # Omar's bench tag, tied to the pull by a loop of string.
    tag_at, yaw = (0.020, 0.012, 0.0092), -24.0
    tag = [(-0.026, -0.013), (0.020, -0.013), (0.026, -0.007), (0.026, 0.007), (0.020, 0.013), (-0.026, 0.013)]
    plate("paper:manila", tag, 0.0, 0.0006, at=tag_at, rot=(0, 0, yaw), holes=[circle(0.0022, 8, (0.019, 0.0))])
    face = Flat(0.0006, at=tag_at, yaw=yaw)
    for k in range(3):
        face.writing(INK, -0.022, 0.010, 0.006 - 0.006 * k, 170 + k, step=0.2)
    eye = Matrix.Rotation(math.radians(yaw), 4, "Z") @ Vector((0.019, 0.0, 0.0)) + Vector(tag_at)
    pull = h / 2 + 0.0215
    string = smooth([(eye.x, eye.y, 0.0085), (eye.x, eye.y, 0.0106), (eye.x + 0.006, eye.y + 0.016, 0.0104),
                     (0.030, 0.050, 0.0100), (0.024, h / 2 - 0.012, 0.0142), (0.021, pull - 0.0062, 0.0116),
                     (0.020, pull, 0.0120), (0.019, pull + 0.0062, 0.0090), (0.018, pull, 0.0052),
                     (0.019, pull - 0.0064, 0.0100), (0.028, h / 2 - 0.010, 0.0142), (0.040, 0.052, 0.0100),
                     (eye.x + 0.012, eye.y + 0.010, 0.0104), (eye.x + 0.002, eye.y - 0.001, 0.0108), (eye.x, eye.y, 0.0085)], 3)
    tube("linen:string", string, 0.0006, segs=5)


def duplicate_negative():
    begin("duplicate_negative")
    pw, ph = 0.083, 0.108
    sw, s0, s1 = 0.091, -0.058, 0.034
    us, vs = span(-sw / 2, sw / 2, 8), span(s0, s1, 5)
    Sheet("paper:glassine", us, vs, None, thick=0.00012)
    rect = [(-pw / 2, -ph / 2), (pw / 2, -ph / 2), (pw / 2, ph / 2), (-pw / 2, ph / 2)]
    plate("soot", rect, 0.0003, 0.0005)
    plate(GLASS, rect, 0.0005, 0.0020)

    def thumb(i, j, ni, nj):
        # The cut the thumb finds at the mouth of the sleeve.
        return (0.0, -0.009 * max(0.0, 1.0 - abs(i - (ni - 1) / 2) / 2.2)) if j == nj - 1 else (0.0, 0.0)
    Sheet("paper:glassine", us, vs, lambda u, v: 0.0024 + 0.0006 * (1 - (2 * u / sw) ** 2), thick=0.00012, edge=thumb)
    # The gummed seams down both sides and across the foot.
    for sx in (-1, 1):
        box("paper:glassine", (0.0002, s1 - s0, 0.0026), (sx * sw / 2, (s0 + s1) / 2, 0.0013))
    box("paper:glassine", (sw, 0.0002, 0.0026), (0, s0, 0.0013))


def plate_half():
    begin("plate_half")
    mw, mh = 0.146, 0.172
    a, b = 0.049, 0.0615
    plate("paper:card", rounded(mw, mh, 0.002, 2), 0.0, 0.0010)
    plate("paper:card", rounded(mw, mh, 0.002, 2), 0.0010, 0.0036, holes=[[(-a, -b), (a, -b), (a, b), (-a, b)]])
    g = 0.0004
    half = [(-a + g, -b + g), (a - g, -b + g), (a - g, -0.36 * b), (-0.22 * a, b - g), (-a + g, b - g)]
    plate("soot", half, 0.0010, 0.0012)
    plate(GLASS, half, 0.0012, 0.0028)


def kept_papers():
    begin("kept_papers")
    # The rent receipt underneath.
    rw, rh = 0.086, 0.132
    receipt = Sheet("paper:cream", span(-rw / 2, rw / 2, 4), span(-rh / 2, rh / 2, 6), curl(rw, rh, 0.0008, 0.0022),
                    at=(0.014, -0.010, 0.0), yaw=-7.0)
    for k in range(5):
        receipt.stroke(INK, (-0.036, -0.012 - 0.010 * k), (0.036, -0.012 - 0.010 * k), 0.0003)
    for k in range(3):
        receipt.writing(INK, -0.030, 0.030, -0.0105 - 0.010 * (k + 1), 200 + k)
    # The cutting from the Record, folded once, one item marked.
    cw, ch = 0.064, 0.150
    cutting = Sheet("paper:newsprint", span(-cw / 2, cw / 2, 3), span(-ch / 2, ch / 2, 7),
                    lambda u, v: 0.0006 + 0.0016 * max(0.0, -2 * v / ch) ** 2, at=(-0.016, -0.014, 0.0006), yaw=5.0)
    for k in range(22):
        y = 0.066 - 0.0062 * k
        if k in (0, 1):
            continue
        cutting.writing(INK, -0.028, 0.028, y, 220 + k, width=0.0011, step=0.012)
    cutting.stroke(INK, (-0.028, 0.068), (0.028, 0.068), 0.0034)
    for p, q in (((-0.030, 0.010), (0.030, 0.010)), ((0.030, 0.010), (0.030, -0.024)), ((0.030, -0.024), (-0.030, -0.024)), ((-0.030, -0.024), (-0.030, 0.010))):
        cutting.stroke(INK, p, q, 0.0013, lift=0.0004)
    # Adela's note on top, folded in half, its upper leaf not lying down.
    nw, nh = 0.094, 0.066
    Sheet("paper:cream", span(-nw / 2, nw / 2, 4), span(-nh / 2, nh / 2, 3), None, at=(0.004, 0.030, 0.0016), yaw=-2.0)
    note = Sheet("paper:cream", span(-nw / 2, nw / 2, 4), span(-nh / 2, nh / 2, 4),
                 lambda u, v: 0.0003 + 0.0034 * max(0.0, (nh / 2 - v) / nh) ** 1.5, at=(0.004, 0.030, 0.0018), yaw=-2.0)
    for k in range(4):
        note.writing(INK, -0.038, 0.036 - 0.02 * rng(k, 4), 0.016 - 0.011 * k, 240 + k, width=0.001, step=0.006)
    gem_clip("brass", (-0.018, 0.063 - 0.012, 0.0), 0.0030, -0.0006, yaw=4.0, radius=0.0005)


def bundle():
    begin("bundle")
    w, d, n = 0.380, 0.280, 9
    t = 0.0128
    key = "paper:newsprint"
    for k in range(n):
        last = k == n - 1
        dx = 0.0 if last else (rng(k, 61) - 0.5) * 0.008
        dy = 0.0 if last else (rng(k, 62) - 0.5) * 0.006
        yaw = 0.0 if last else (rng(k, 63) - 0.5) * 1.6
        pw, pd = w - 0.012 - 0.004 * rng(k, 64), d - 0.010 - 0.004 * rng(k, 65)
        # One folded paper: a slab whose near side is the rounded fold.
        r = t / 2
        prof = [(pd / 2, 0.0), (-pd / 2 + r, 0.0)]
        for s in range(1, 4):
            ang = math.radians(-90 - 45 * s)
            prof.append((-pd / 2 + r + r * math.cos(ang), r + r * math.sin(ang)))
        prof += [(-pd / 2 + r, t), (pd / 2, t)]
        bm, tile, _ = _bm(key)
        m = _xf((dx, dy, k * t), (0, 0, yaw))
        off = _offset()
        run = 0.0
        for s in range(len(prof)):
            p, q = prof[s], prof[(s + 1) % len(prof)]
            seg = math.hypot(q[0] - p[0], q[1] - p[1])
            # Outward: travel is clockwise seen from +u, so the face runs q to p along +u.
            pts = [(-pw / 2, q[0], q[1]), (-pw / 2, p[0], p[1]), (pw / 2, p[0], p[1]), (pw / 2, q[0], q[1])]
            uvs = [Vector((0, run + seg)), Vector((0, run)), Vector((pw, run)), Vector((pw, run + seg))]
            _face(bm, m, pts, [u / tile + off for u in uvs], 1 <= s <= 4)
            run += seg
        for sx in (-1, 1):
            cap = [(sx * pw / 2, p[0], p[1]) for p in prof]
            uvs = [Vector((p[0], p[1])) / tile + off + Vector((0.3, 0.6)) for p in prof]
            if sx > 0:
                cap.reverse()
                uvs.reverse()
            _face(bm, m, cap, uvs, False)
    top = n * t
    face = Flat(top)
    face.stroke(INK, (-0.168, 0.104), (0.168, 0.104), 0.016, step=0.5)
    face.stroke(INK, (-0.172, 0.088), (0.172, 0.088), 0.0012, step=0.5)
    face.stroke(INK, (-0.172, 0.084), (0.172, 0.084), 0.0005, step=0.5)
    face.stroke(INK, (-0.168, 0.068), (0.030, 0.068), 0.010, step=0.5)
    face.stroke(INK, (-0.168, 0.052), (0.020, 0.052), 0.006, step=0.5)
    for c in range(5):
        x0 = -0.168 + 0.069 * c
        for k in range(12 if c > 2 else 9):
            y = (0.070 if c > 2 else 0.036) - 0.013 * k
            face.writing(INK, x0, x0 + 0.060, y, 300 + c * 20 + k, width=0.0022, step=0.5)
    # String round it both ways, biting at the corners, knotted on top.
    sr = 0.0019

    def band(half, height, bite=0.004):
        pts = []
        for cx, cz, start in ((half - bite, height - bite, 0), (-half + bite, height - bite, 90), (-half + bite, bite, 180), (half - bite, bite, 270)):
            for s in range(4):
                ang = math.radians(start + 30 * s)
                pts.append((cx + math.cos(ang) * (bite + sr * 0.4), cz + math.sin(ang) * (bite + sr * 0.4)))
        return pts
    tube("linen:string", [(0.018, y, z) for y, z in band(d / 2 - 0.004, top)], sr, segs=6, closed=True)
    tube("linen:string", [(x, -0.012, z) for x, z in band(w / 2 - 0.005, top + sr * 0.8)], sr, segs=6, closed=True)
    knot = (0.018, -0.012, top + sr * 1.6)
    lathe("linen:string", [(0, -0.003, "s"), (0.004, -0.0015, "s"), (0.0052, 0.0012, "s"), (0.0036, 0.0036, "s"), (0, 0.0046, "s")], at=knot, segs=8)
    tube("linen:string", smooth([knot, (0.040, -0.030, top + 0.004), (0.058, -0.052, top + sr)], 3), sr * 0.9, segs=5)
    tube("linen:string", smooth([knot, (-0.006, -0.036, top + 0.004), (-0.030, -0.050, top + sr)], 3), sr * 0.9, segs=5)


def pin():
    begin("pin", keep_w=True)
    r = 0.0023
    prof = [(0, -0.004), (0.00045, -0.0022), (0.00045, 0.0036)]
    for k in range(7):
        ang = math.radians(-70 + 160 * k / 6)
        prof.append((r * math.cos(ang), 0.0057 + r * math.sin(ang), "s"))
    prof.append((0, 0.008, "s"))
    lathe("billiard_resin:red", prof, segs=10)


BUILDERS = [order_slip, route_leaf, nurse_note, jonah_page, button_leaf, glove_scrap, disc_label, dark_slide,
            duplicate_negative, plate_half, kept_papers, bundle, pin]


# ---------------------------------------------------------------------------

def review_material(base, tint):
    name = "review_%s_%s" % (base, tint)
    if name in bpy.data.materials:
        return bpy.data.materials[name]
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    if base == GLASS:
        bsdf.inputs["Base Color"].default_value = (0.82, 0.90, 0.88, 1)
        bsdf.inputs["Roughness"].default_value = 0.05
        bsdf.inputs["Transmission Weight"].default_value = 1.0
        return mat
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
    bsdf.inputs["Alpha"].default_value = ALPHA.get(tint, 1.0)
    return mat


def realise():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    for build in BUILDERS:
        build()
    objects, rows, sizes = {}, {}, {}
    for piece in ORDER:
        slots = [slot for slot in PARTS if slot[0] == piece]
        low, high = Vector((1e9,) * 3), Vector((-1e9,) * 3)
        for slot in slots:
            for v in PARTS[slot].verts:
                low = Vector(map(min, low, v.co))
                high = Vector(map(max, high, v.co))
        # Origin: the centre of the back face. Then stand it up: face to -Y, v to +Z.
        shift = Vector((-(low.x + high.x) / 2, -(low.y + high.y) / 2, 0.0 if piece in KEEP_W else -low.z))
        sizes[piece] = [round(high.x - low.x, 4), round(high.y - low.y, 4), round(high.z - low.z, 4)]
        for base, tint in [(s[1], s[2]) for s in slots]:
            bm = PARTS[(piece, base, tint)]
            for v in bm.verts:
                p = v.co + shift
                v.co = Vector((p.x, -p.z, p.y))
            bmesh.ops.triangulate(bm, faces=bm.faces[:])
            layer = bm.loops.layers.uv.active
            bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.calc_area() < 1e-12], context="FACES")
            for f in bm.faces:
                a, b, c = [l[layer].uv for l in f.loops]
                assert abs((b - a).cross(c - a)) > 1e-13, ("collapsed UV chart", piece, base, f.calc_area())
            name = "%s__ON_%s%s" % (piece, base, "__" + tint if tint else "")
            mesh = bpy.data.meshes.new(name)
            bm.to_mesh(mesh)
            tris = len(bm.faces)
            bm.free()
            obj = bpy.data.objects.new(name, mesh)
            bpy.context.scene.collection.objects.link(obj)
            mesh.materials.append(review_material(base, tint))
            objects.setdefault(piece, []).append(obj)
            row = {"name": name, "material": base}
            if tint:
                row["tint"] = [round(c, 3) for c in TINTS[tint]]
            if tint in ALPHA:
                row["alpha"] = ALPHA[tint]
            if tint in SORTING:
                row["sorting_offset"] = SORTING[tint]
            rows.setdefault(piece, []).append((row, tris))
    bpy.context.view_layer.update()
    return objects, rows, sizes


def review(objects, sizes):
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 48
    scene.cycles.use_denoising = True
    scene.render.resolution_x, scene.render.resolution_y = 1800, 1000
    world = bpy.data.worlds.new("review")
    scene.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.22, 0.21, 0.20, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.7
    extras = []
    bpy.ops.mesh.primitive_plane_add(size=40, rotation=(math.radians(90), 0, 0), location=(0, 0.0002, 0))
    wall = bpy.context.object
    wm = bpy.data.materials.new("review_wall")
    wm.use_nodes = True
    wm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.36, 0.40, 0.36, 1)
    wall.data.materials.append(wm)
    extras.append(wall)
    bpy.ops.object.light_add(type="SUN")
    sun = bpy.context.object
    sun.data.energy = 3.2
    sun.data.angle = math.radians(8)
    sun.rotation_euler = (math.radians(62), 0, math.radians(-28))
    extras.append(sun)
    bpy.ops.object.camera_add()
    camera = bpy.context.object
    scene.camera = camera
    camera.data.clip_start = 0.005
    extras.append(camera)
    sheets = {
        "sheet_1_leaves": ["order_slip", "route_leaf", "nurse_note", "jonah_page", "button_leaf"],
        "sheet_2_things": ["glove_scrap", "disc_label", "dark_slide", "duplicate_negative", "plate_half", "kept_papers"],
        "sheet_3_bundle": ["bundle"],
        "sheet_4_small": ["glove_scrap", "button_leaf", "pin"],
    }
    for sheet, names in sheets.items():
        for objs in objects.values():
            for o in objs:
                o.hide_render = True
        x = 0.0
        moved = []
        height = max(sizes[n][1] for n in names)
        depth = max(sizes[n][2] for n in names)
        for name in names:
            shift = Vector((x + sizes[name][0] / 2, 0, 0))
            for o in objects[name]:
                o.location += shift
                o.hide_render = False
                moved.append((o, shift))
            x += sizes[name][0] + max(0.012, sizes[name][0] * 0.12)
        width = x
        bpy.context.view_layer.update()
        centre = Vector((width / 2, -depth / 2, 0))
        camera.data.lens = 70
        fov_h = 2 * math.atan(36.0 / (2 * 70))
        fov_v = 2 * math.atan(36.0 * 1000 / 1800 / (2 * 70))
        dist = max(width / 2 / math.tan(fov_h / 2), height / 2 / math.tan(fov_v / 2)) * 1.12
        for label, aim in (("front", Vector((0.0, -1.0, 0.0))), ("raked", Vector((0.55, -0.62, 0.45)).normalized())):
            camera.location = centre + aim * dist * (1.0 if label == "front" else 1.15)
            camera.rotation_euler = (centre - camera.location).to_track_quat("-Z", "Y").to_euler()
            scene.render.filepath = str(OUT / ("%s_%s.png" % (sheet, label)))
            bpy.ops.render.render(write_still=True)
        for o, shift in moved:
            o.location -= shift
    for objs in objects.values():
        for o in objs:
            o.hide_render = False
    for o in extras:
        bpy.data.objects.remove(o)
    bpy.context.view_layer.update()


def export(objects, rows, sizes):
    blend = ROOT / "art/blender/evidence_pieces.blend"
    glb = ROOT / "game/assets/props/evidence_pieces.glb"
    bpy.ops.wm.save_as_mainfile(filepath=str(blend), check_existing=False, compress=True)
    bpy.ops.object.select_all(action="DESELECT")
    for objs in objects.values():
        for o in objs:
            o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(glb), export_format="GLB", use_selection=True, export_yup=True,
                              export_apply=True, export_normals=True, export_tangents=True, export_texcoords=True,
                              export_materials="NONE", export_animations=False)
    pieces, total = [], 0
    print("[EVIDENCE PIECES]")
    for piece in ORDER:
        tris = sum(t for _, t in rows[piece])
        total += tris
        pieces.append({"id": piece, "size": sizes[piece], "face_axis": "z", "up_axis": "y", "parts": [r for r, _ in rows[piece]]})
        print("  %-20s %5d tris  %d parts  size %s" % (piece, tris, len(rows[piece]), sizes[piece]))
    data = {"schema_version": 1, "asset": "res://assets/props/evidence_pieces.glb", "pieces": pieces}
    (ROOT / "game/data/orison_v2/evidence_pieces.json").write_text(json.dumps(data, indent=1) + "\n", encoding="utf-8", newline="\n")
    print("[EVIDENCE PIECES] %d pieces, %d mesh parts, %d triangles" % (len(pieces), sum(len(r) for r in rows.values()), total))


objects, rows, sizes = realise()
if "--no-review" not in sys.argv:
    review(objects, sizes)
export(objects, rows, sizes)
