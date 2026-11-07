"""Mid-ground streets and blocks: walkable city fabric between the composed near
city and the 450 m exterior limit.

    python art/blender/scripts/build_city_midground.py --plan      # layout + plan map only
    blender -b --python-exit-code 1 -P art/blender/scripts/build_city_midground.py

Writes game/assets/props/city_midground.glb (near tiles, far tiles and furniture
stock) and game/data/orison_v2/exterior/city_midground.json (collision boxes, glass
panes, furniture instances and barricades). Coordinates are the WORLD frame of the
V2 runtime root (x east, y up, z south, metres), converted to Blender's Z-up axes
only when each vertex is emitted.

Everything is additive. The layout reads a collision survey of the running world
(tests/V2MidgroundOccupancyProbe.tscn, copied to art/blender/data/city_midground_survey)
and builds only on cells whose first hit is bare apron, so no installed street,
shell, horizon building, station, bulkhead, cut or the Orison is touched. Stations
and ground datums used by other tests are reserved.

UV0 is metric on every surface (walls U along, V up; ground world X/Z). Near
materials are catalogue keys. Far tiles use "far_*" keys for the distant-facade
shader with COLOR_0 traits (R seed, G kind/4, B storey/6, A lit bias), as in
build_city_far_districts.py. Glass is not meshed: each pane is a record the runtime
draws as a MultiMesh with the background-window optics. No lettering (RUL-008).
"""
import json
import math
import random
import sys

import numpy as np

try:
    import bmesh
    import bpy
except ImportError:  # --plan runs in plain Python
    bpy = None

ROOT = __file__.replace("\\", "/").split("/art/blender/")[0]
OUT = __import__("os").environ.get("ORISON_MIDGROUND_OUT", ROOT + "/game/assets/props/city_midground.glb")
DATA = __import__("os").environ.get("ORISON_MIDGROUND_DATA", ROOT + "/game/data/orison_v2/exterior/city_midground.json")
SURVEY = ROOT + "/art/blender/data/city_far_survey/"
OCC = __import__("os").environ.get("ORISON_MIDGROUND_OCC", ROOT + "/art/blender/data/city_midground_survey/")
PLAN_PNG = ROOT + "/art/blender/data/city_midground_survey/plan.png"

BLOCKOUT_Z = -11.65  # world = (-local.x, local.y, -local.z - 11.65)
RING = 450.0  # the old TemporaryExteriorLimit radius; the fabric still reaches it for the view
# Lily 2026-11-07 (ruling barrier_distance): she passes out at 200 m from the front door,
# mist gathering over 150-200 m. Only the fabric inside WALKABLE gets collision.
WALKABLE = 215.0
APRON = 500.0
SEED = 19291107

# Street grid, continuing the installed avenue (road at world z 4.955..14.1) and the
# installed cross streets at x = +-142.9.
AVENUE_Z = 9.5275
BLOCK_D = 92.0  # centre to centre of parallel streets
BLOCK_W = 142.868  # centre to centre of cross streets
ROAD = 9.144  # 30 ft carriageway, as installed
WALK = 3.6
HALF = ROAD / 2 + WALK
CURB = 0.16
LOT_DEPTH = 26.0
TILE = 200.0
FREE_FRACTION = 0.9

# Stations and datums other tests stand on (world x, z, radius).
RESERVED_POINTS = [
    (-450, -11.65, 6), (400, -11.65, 6), (0, 348.35, 6), (-112, -11.65, 6), (-140, -71.65, 6),
    (-180, -71.65, 6), (-280, -71.65, 6), (108, -11.65, 6),  # horizon bench datums
    (280, -10, 8), (-280, -10, 8), (-280, -1.65, 8), (469, 28, 8), (430, -31.65, 8),  # stations
]
# The composed near city (Codex's): everything inside the near horizon ring, which stands at
# blockout |coord| 150-170, i.e. world x -170..170 and z -181.65..158.35, plus a margin. New
# fabric starts in the corridor between the near and far rings.
NEAR_CITY = (-178.0, -190.0, 178.0, 166.0)
# Codex's eastern radius route: (280,-10) -> (296,-10) -> (296,-31.65) -> east along z -31.65.
RESERVED_RECTS = [(266, -40, 304, 2), (290, -40, 480, -23)]


def walkable(x0, z0, x1, z1):
    """Any part of the rectangle inside the walkable radius."""
    cx, cz = min(max(0.0, x0), x1), min(max(0.0, z0), z1)
    return math.hypot(cx, cz) < WALKABLE


def reserved(x0, z0, x1, z1):
    nx0, nz0, nx1, nz1 = NEAR_CITY
    if x0 < nx1 and x1 > nx0 and z0 < nz1 and z1 > nz0:
        return True
    for rx0, rz0, rx1, rz1 in RESERVED_RECTS:
        if x0 < rx1 and x1 > rx0 and z0 < rz1 and z1 > rz0:
            return True
    for px, pz, r in RESERVED_POINTS:
        cx, cz = min(max(px, x0), x1), min(max(pz, z0), z1)
        if math.hypot(px - cx, pz - cz) < r:
            return True
    return False


# --- Surveys ---------------------------------------------------------------------------

H_NEAR = np.load(SURVEY + "h_near.npy")  # blockout frame, 4 m, +-520


def _bilinear(grid, lim, step, x, z):
    fx, fz = (x + lim) / step, (z + lim) / step
    i, j = int(math.floor(fx)), int(math.floor(fz))
    tx, tz = fx - i, fz - j
    vals = []
    for dj, di in ((0, 0), (0, 1), (1, 0), (1, 1)):
        jj, ii = min(max(j + dj, 0), grid.shape[0] - 1), min(max(i + di, 0), grid.shape[1] - 1)
        vals.append(grid[jj, ii])
    good = [v for v in vals if not np.isnan(v)]
    if len(good) < 4:
        return float(sum(good) / len(good)) if good else 0.0
    top = vals[0] * (1 - tx) + vals[1] * tx
    bottom = vals[2] * (1 - tx) + vals[3] * tx
    return float(top * (1 - tz) + bottom * tz)


def ground(x, z):
    """Installed ground and apron top, no buildings (world frame in, blockout survey)."""
    return _bilinear(H_NEAR, 520, 4, -x, -z + BLOCKOUT_Z)


def land(x, z):
    """Buildable ground: not the river or canal beds, and not the rail cut's floor."""
    g = ground(x, z)
    if g < -5.0:
        return False
    return not (x > 300 and g < -3.0)


class Occupancy:
    """First hits of the running world's collision on a 2 m world grid."""

    def __init__(self):
        meta = json.load(open(OCC + "occupancy.json", encoding="utf8"))
        self.limit, self.step, self.n = meta["limit"], meta["step"], meta["n"]
        self.owners = meta["owners"]
        owners = np.fromfile(OCC + "occupancy_owners.i32", dtype="<i4").reshape(self.n, self.n)
        free_ids = [i for i, key in enumerate(self.owners) if self.is_free_owner(key)]
        self.free = np.isin(owners, free_ids)
        self.owner = owners

    @staticmethod
    def is_free_owner(key):
        # Bare installed ground: the blockout ground and the distant apron.
        if key.startswith("Midground"):
            return True  # this batch's own earlier output
        # Bare installed ground and apron (the survey keeps three path segments).
        return key == "OrisonV2Blockout/Ground/orison_ground"

    def cell(self, x, z):
        i = int(round((x + self.limit) / self.step))
        j = int(round((z + self.limit) / self.step))
        return j, i

    def fraction_free(self, x0, z0, x1, z1):
        """Free fraction over a rectangle; beyond the survey, apron above -1.5 m counts as free."""
        total = good = 0
        x = x0 + 1.0
        while x < x1:
            z = z0 + 1.0
            while z < z1:
                total += 1
                j, i = self.cell(x, z)
                if 0 <= i < self.n and 0 <= j < self.n:
                    good += bool(self.free[j, i]) and land(x, z)
                else:
                    good += abs(x) < APRON - 5 and abs(z - BLOCKOUT_Z) < APRON - 5 and land(x, z)
                z += 2.0
            x += 2.0
        return good / total if total else 0.0


# --- Layout ----------------------------------------------------------------------------

class Layout:
    def __init__(self, occ):
        self.occ = occ
        self.rng = random.Random(SEED)
        self.streets = []  # (axis, centre, a, b): axis "x" runs along x at z=centre
        self.claimed = []  # rectangles taken by new streets and lots
        self.lots = []
        self.fences = []
        self.barricades = []

    def clear(self, rect, pad=1.5):
        x0, z0, x1, z1 = rect
        if reserved(x0 - pad, z0 - pad, x1 + pad, z1 + pad):
            return False
        for c in self.claimed:
            if x0 < c[2] and x1 > c[0] and z0 < c[3] and z1 > c[1]:
                return False
        return self.occ.fraction_free(x0 - pad, z0 - pad, x1 + pad, z1 + pad) >= FREE_FRACTION

    def lines(self):
        zs = [AVENUE_Z + k * BLOCK_D for k in range(-6, 7)]
        xs = [k * BLOCK_W for k in range(-4, 5)]
        return xs, zs

    def build_streets(self):
        xs, zs = self.lines()
        reach = RING + 30
        # Long streets (along x), cut into segments between cross streets.
        for z in zs:
            for a, b in zip(xs[:-1], xs[1:]):
                self._segment("x", z, a, b, reach)
        for x in xs:
            for a, b in zip(zs[:-1], zs[1:]):
                self._segment("z", x, a, b, reach)

    def _rect(self, axis, centre, a, b, half):
        return (a, centre - half, b, centre + half) if axis == "x" else (centre - half, a, centre + half, b)

    def _segment(self, axis, centre, a, b, reach):
        # Trim to the reach disc along the centreline.
        if abs(centre) >= reach:
            return
        span = math.sqrt(reach ** 2 - centre ** 2)
        a, b = max(a, -span), min(b, span)
        if b - a < 20:
            return
        # Walk the segment in 6 m steps and keep the longest free runs.
        run = None
        t = a
        while t <= b:
            piece = self._rect(axis, centre, t, min(t + 6, b), HALF)
            ok = self.clear(piece, pad=0.5)
            if ok and run is None:
                run = t
            if (not ok or t + 6 >= b) and run is not None:
                end = min(t + 6, b) if ok else t
                if end - run >= 18:
                    self.streets.append((axis, centre, run, end))
                    self.claimed.append(self._rect(axis, centre, run, end, HALF))
                run = None
            t += 6

    def district(self, x, z):
        if x > 250:
            return "works"  # toward the rail cut and Sunnyside
        if x < -250:
            return "waterfront"
        if abs(z - AVENUE_Z) < 1.0 or x > 150:
            return "loft"
        return "walkup"

    def build_lots(self):
        for axis, centre, a, b in self.streets:
            for side in (-1, 1):
                self._frontage(axis, centre, a, b, side)

    def street_at(self, x, z):
        """A new street's band, or an installed street's collision, at this point."""
        for axis, c, a, b in self.streets:
            r = self._rect(axis, c, a, b, HALF)
            if r[0] - 0.5 <= x <= r[2] + 0.5 and r[1] - 0.5 <= z <= r[3] + 0.5:
                return True
        j, i = self.occ.cell(x, z)
        if 0 <= i < self.occ.n and 0 <= j < self.occ.n and self.occ.owner[j, i] >= 0:
            return "Street" in self.occ.owners[self.occ.owner[j, i]]
        return False

    def _frontage(self, axis, centre, a, b, side):
        front = centre + side * HALF  # building line
        t = a + 0.3
        while t < b - 4:
            kind = self.district(*((t, front) if axis == "x" else (front, t)))
            width = {"walkup": self.rng.choice([7.62, 7.62, 6.1, 9.1]),
                     "loft": self.rng.uniform(15, 26), "works": self.rng.uniform(24, 46),
                     "waterfront": self.rng.uniform(20, 40)}[kind]
            width = min(width, b - 0.3 - t)
            if width < 5.5:
                break
            depth = LOT_DEPTH if kind in ("walkup", "loft") else self.rng.uniform(26, 40)
            d0, d1 = (front, front + side * depth)
            lo, hi = min(d0, d1), max(d0, d1)
            rect = (t, lo, t + width, hi) if axis == "x" else (lo, t, hi, t + width)
            if not self.clear(rect, pad=1.2):
                t += 2.0  # creep up to the obstacle's far side rather than skip a lot
                continue
            self.claimed.append(rect)
            mid = front + side * min(depth, 8.0) / 2
            ends = []
            for k, u in ((0, t - 2.5), (1, t + width + 2.5)):
                if self.street_at(*((u, mid) if axis == "x" else (mid, u))):
                    ends.append(k)
            self.lots.append({"rect": rect, "axis": axis, "side": side, "kind": kind, "corner_ends": ends,
                              "street_z": centre if axis == "x" else None, "seed": self.rng.random()})
            t += width

    def build_edges(self):
        """Where a new street crosses the exterior limit, close it with street works."""
        for axis, centre, a, b in self.streets:
            for end in (a, b):
                x, z = (end, centre) if axis == "x" else (centre, end)
                r = math.hypot(x, z)
                if r > RING - 25:
                    # The point on the centreline just inside the ring.
                    t = math.sqrt(max((RING - 6) ** 2 - centre ** 2, 0)) * (1 if end > 0 else -1)
                    bx, bz = (t, centre) if axis == "x" else (centre, t)
                    self.barricades.append({"x": round(bx, 2), "z": round(bz, 2), "axis": axis,
                                            "width": round(2 * HALF, 2)})

    def run(self):
        # Street ends stay open (ruling midground_street_ends); the mist is the limit,
        # so build_edges' street works are not placed.
        self.build_streets()
        self.build_lots()
        return self


def plan_png(layout, path):
    from PIL import Image, ImageDraw
    occ = layout.occ
    scale = 1.0  # px per metre
    size = int(2 * 500 * scale)
    img = Image.new("RGB", (size, size), (20, 20, 24))
    px = lambda x, z: ((x + 500) * scale, (z + 500) * scale)
    owners = occ.owner
    palette = {}
    for j in range(occ.n):
        for i in range(occ.n):
            o = owners[j, i]
            if o < 0:
                continue
            if occ.free[j, i]:
                col = (52, 52, 56)
            else:
                key = occ.owners[o].split("/")[0]
                if key not in palette:
                    h = abs(hash(key)) % 360
                    palette[key] = tuple(int(90 + 80 * math.sin(math.radians(h + k * 120))) for k in range(3))
                col = palette[key]
            x, z = -occ.limit + i * occ.step, -occ.limit + j * occ.step
            img.putpixel((int(px(x, z)[0]), int(px(x, z)[1])), col)
    d = ImageDraw.Draw(img)
    for axis, c, a, b in layout.streets:
        r = layout._rect(axis, c, a, b, HALF)
        d.rectangle([*px(r[0], r[1]), *px(r[2], r[3])], outline=(230, 230, 230))
    colours = {"walkup": (200, 90, 60), "loft": (210, 170, 80), "works": (110, 150, 200), "waterfront": (120, 200, 160)}
    for lot in layout.lots:
        r = lot["rect"]
        d.rectangle([*px(r[0], r[1]), *px(r[2], r[3])], fill=colours[lot["kind"]])
    for bar in layout.barricades:
        x, z = px(bar["x"], bar["z"])
        d.ellipse([x - 4, z - 4, x + 4, z + 4], fill=(255, 40, 40))
    d.ellipse([*px(-RING, -RING), *px(RING, RING)], outline=(255, 80, 80))
    d.ellipse([*px(-200, -200), *px(200, 200)], outline=(255, 200, 60))
    d.rectangle([*px(NEAR_CITY[0], NEAR_CITY[1]), *px(NEAR_CITY[2], NEAR_CITY[3])], outline=(120, 120, 255))
    for rx0, rz0, rx1, rz1 in RESERVED_RECTS:
        d.rectangle([*px(rx0, rz0), *px(rx1, rz1)], outline=(80, 255, 80))
    for x, z, r in RESERVED_POINTS:
        d.ellipse([*px(x - r, z - r), *px(x + r, z + r)], outline=(80, 255, 80))
    img.save(path)
    print("PLAN", path, "streets", len(layout.streets), "lots", len(layout.lots),
          "barricades", len(layout.barricades), "palette", sorted(palette))


# --- Meshing ---------------------------------------------------------------------------

KIND_CODE = {"walkup": 0, "loft": 1, "works": 2, "waterfront": 2}
WALLS = {"walkup": ["brick", "brick", "city_grey_brick"], "loft": ["brick", "city_grey_brick", "limestone"],
         "works": ["brick", "city_grey_brick"], "waterfront": ["brick", "city_grey_brick"]}
# Pane classes drawn by the runtime as MultiMeshes: size (w, h) and room kind for
# v2_background_window_interior.gdshader (0 walk-up, 1 office, 2 workshop, 3 shop).
PANES = {"sash": ((1.0, 1.75), 0), "loft": ((2.2, 2.3), 1), "works": ((3.4, 3.0), 2),
         "ware": ((1.4, 1.8), 2), "store": ((2.6, 2.5), 3)}
STOREY = {"walkup": 3.2, "loft": 4.0, "works": 5.2, "waterfront": 4.0}
BAY = {"walkup": 2.55, "loft": 3.7, "works": 5.2, "waterfront": 3.1}
WINDOW = {"walkup": ("sash", 0.9), "loft": ("loft", 0.85), "works": ("works", 1.1), "waterfront": ("ware", 1.0)}
REVEAL = 0.2
GLASS_SET = 0.13


class Part:
    def __init__(self):
        self.bm = bmesh.new() if bpy else None
        self.uv = self.bm.loops.layers.uv.new("UVMap") if bpy else None
        self.col = self.bm.loops.layers.color.new("Color") if bpy else None
        self.faces = 0

    def face(self, points, uvs, color=(0.5, 0, 0.5, 0.5), centre=None):
        """centre: a point behind the face; the face is flipped to look away from it."""
        self.faces += 1
        if self.bm is None:
            return
        if centre is not None:
            a, b, c = points[0], points[1], points[2]
            u = (b[0] - a[0], b[1] - a[1], b[2] - a[2])
            v = (c[0] - a[0], c[1] - a[1], c[2] - a[2])
            n = (u[1] * v[2] - u[2] * v[1], u[2] * v[0] - u[0] * v[2], u[0] * v[1] - u[1] * v[0])
            m = [sum(q[k] for q in points) / len(points) for k in range(3)]
            if sum(n[k] * (m[k] - centre[k]) for k in range(3)) < 0:
                points, uvs = list(reversed(points)), list(reversed(uvs))
        verts = [self.bm.verts.new((p[0], -p[2], p[1])) for p in points]
        f = self.bm.faces.new(verts)
        for loop, uv in zip(f.loops, uvs):
            loop[self.uv].uv = uv
            loop[self.col] = color


PARTS = {}


def tile_of(x, z):
    return f"t{int((x + 500) // TILE)}{int((z + 500) // TILE)}"


def part(group, material):
    key = (group, material)
    if key not in PARTS:
        PARTS[key] = Part()
    return PARTS[key]


class Frame:
    """A wall line from a (x, z) along +u, with outward normal n; P(u, v, d) is world."""

    def __init__(self, a, along, out):
        self.a, self.t, self.n = a, along, out

    def P(self, u, v, d=0.0):
        return (self.a[0] + self.t[0] * u + self.n[0] * d, v, self.a[1] + self.t[1] * u + self.n[1] * d)

    def behind(self, u, v):
        return self.P(u, v, -1.0)


def quad(p, f, u0, u1, v0, v1, d=0.0, color=(0.5, 0, 0.5, 0.5), outward=True):
    pts = [f.P(u0, v0, d), f.P(u1, v0, d), f.P(u1, v1, d), f.P(u0, v1, d)]
    uvs = [(u0, v0), (u1, v0), (u1, v1), (u0, v1)]
    centre = f.P((u0 + u1) / 2, (v0 + v1) / 2, d - 1 if outward else d + 1)
    p.face(pts, uvs, color, centre)


def slab(p, f, u0, u1, v0, v1, d0, d1, color=(0.5, 0, 0.5, 0.5), bottom=True):
    """A box proud of (or set into) a wall: u along, v up, d out."""
    c = f.P((u0 + u1) / 2, (v0 + v1) / 2, (d0 + d1) / 2)
    faces = [
        ([f.P(u0, v0, d1), f.P(u1, v0, d1), f.P(u1, v1, d1), f.P(u0, v1, d1)], [(u0, v0), (u1, v0), (u1, v1), (u0, v1)]),
        ([f.P(u0, v1, d0), f.P(u1, v1, d0), f.P(u1, v1, d1), f.P(u0, v1, d1)], [(u0, d0), (u1, d0), (u1, d1), (u0, d1)]),
        ([f.P(u0, v0, d0), f.P(u0, v0, d1), f.P(u0, v1, d1), f.P(u0, v1, d0)], [(d0, v0), (d1, v0), (d1, v1), (d0, v1)]),
        ([f.P(u1, v0, d0), f.P(u1, v0, d1), f.P(u1, v1, d1), f.P(u1, v1, d0)], [(d0, v0), (d1, v0), (d1, v1), (d0, v1)]),
    ]
    if bottom:
        faces.append(([f.P(u0, v0, d0), f.P(u1, v0, d0), f.P(u1, v0, d1), f.P(u0, v0, d1)], [(u0, d0), (u1, d0), (u1, d1), (u0, d1)]))
    for pts, uvs in faces:
        p.face(pts, uvs, color, c)


def box_world(p, x0, z0, x1, z1, y0, y1, color=(0.5, 0, 0.5, 0.5), top=True, bottom=False):
    f = Frame((x0, z0), (1, 0), (0, -1))
    c = ((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2)
    w, d = x1 - x0, z1 - z0
    sides = [((x0, z0), (x1, z0)), ((x1, z0), (x1, z1)), ((x1, z1), (x0, z1)), ((x0, z1), (x0, z0))]
    for (ax, az), (bx, bz) in sides:
        length = math.hypot(bx - ax, bz - az)
        pts = [(ax, y0, az), (bx, y0, bz), (bx, y1, bz), (ax, y1, az)]
        p.face(pts, [(0, y0), (length, y0), (length, y1), (0, y1)], color, c)
    if top:
        p.face([(x0, y1, z0), (x1, y1, z0), (x1, y1, z1), (x0, y1, z1)], [(x0, z0), (x1, z0), (x1, z1), (x0, z1)], color, (c[0], y1 - 1, c[2]))
    if bottom:
        p.face([(x0, y0, z0), (x1, y0, z0), (x1, y0, z1), (x0, y0, z1)], [(x0, z0), (x1, z0), (x1, z1), (x0, z1)], color, (c[0], y0 + 1, c[2]))
    del f, w, d


def cylinder_world(p, x, z, r, y0, y1, seg=10, top=True, color=(0.5, 0, 0.5, 0.5)):
    c = (x, (y0 + y1) / 2, z)
    ring = [(x + r * math.cos(2 * math.pi * k / seg), z + r * math.sin(2 * math.pi * k / seg)) for k in range(seg)]
    circ = 2 * math.pi * r
    for k in range(seg):
        a, b = ring[k], ring[(k + 1) % seg]
        u0, u1 = circ * k / seg, circ * (k + 1) / seg
        p.face([(a[0], y0, a[1]), (b[0], y0, b[1]), (b[0], y1, b[1]), (a[0], y1, a[1])],
               [(u0, y0), (u1, y0), (u1, y1), (u0, y1)], color, c)
    if top:
        p.face([(q[0], y1, q[1]) for q in ring], [(q[0], q[1]) for q in ring], color, (x, y1 - 1, z))


class Builder:
    def __init__(self, layout):
        self.layout = layout
        self.rng = random.Random(SEED + 1)
        self.panes = {k: [] for k in PANES}
        self.colliders = []
        self.furniture = {}
        self.lots_out = []

    # Facades ----------------------------------------------------------------------
    def wall_with_openings(self, p, f, length, y0, y1, openings, color):
        """Wall plane from u 0..length, v y0..y1, with rectangular holes and reveals."""
        us = sorted({0.0, length, *[o[0] for o in openings], *[o[1] for o in openings]})
        vs = sorted({y0, y1, *[o[2] for o in openings], *[o[3] for o in openings]})
        for v0, v1 in zip(vs[:-1], vs[1:]):
            run = None
            for u0, u1 in zip(us[:-1], us[1:]):
                um, vm = (u0 + u1) / 2, (v0 + v1) / 2
                hole = any(o[0] < um < o[1] and o[2] < vm < o[3] for o in openings)
                if not hole and run is None:
                    run = u0
                if hole and run is not None:
                    quad(p, f, run, u0, v0, v1, 0, color)
                    run = None
            if run is not None:
                quad(p, f, run, us[-1], v0, v1, 0, color)
        for u0, u1, v0, v1, _ in openings:
            depth = -REVEAL
            # Reveals face into the opening.
            p.face([f.P(u0, v0, 0), f.P(u0, v1, 0), f.P(u0, v1, depth), f.P(u0, v0, depth)],
                   [(0, v0), (0, v1), (REVEAL, v1), (REVEAL, v0)], color, f.P(u0 - 1, (v0 + v1) / 2, depth / 2))
            p.face([f.P(u1, v0, 0), f.P(u1, v1, 0), f.P(u1, v1, depth), f.P(u1, v0, depth)],
                   [(0, v0), (0, v1), (REVEAL, v1), (REVEAL, v0)], color, f.P(u1 + 1, (v0 + v1) / 2, depth / 2))
            p.face([f.P(u0, v1, 0), f.P(u1, v1, 0), f.P(u1, v1, depth), f.P(u0, v1, depth)],
                   [(u0, 0), (u1, 0), (u1, REVEAL), (u0, REVEAL)], color, f.P((u0 + u1) / 2, v1 + 1, depth / 2))
            p.face([f.P(u0, v0, 0), f.P(u1, v0, 0), f.P(u1, v0, depth), f.P(u0, v0, depth)],
                   [(u0, 0), (u1, 0), (u1, REVEAL), (u0, REVEAL)], color, f.P((u0 + u1) / 2, v0 - 1, depth / 2))

    def pane(self, cls, f, u0, u1, v0, v1, seed):
        (w, h), _ = PANES[cls]
        c = f.P((u0 + u1) / 2, (v0 + v1) / 2, -GLASS_SET)
        self.panes[cls].append([round(c[0], 3), round(c[1], 3), round(c[2], 3), round(f.n[0], 3), round(f.n[1], 3),
                                round((u1 - u0) / w, 3), round((v1 - v0) / h, 3), round(seed, 4)])

    def facade(self, lot, f, length, base, top, front, end=False):
        """Street, rear or corner-end face of one building."""
        kind, tile = lot["kind"], lot["tile"]
        wall, trim = part(tile, lot["wall"]), part(tile, "limestone")
        paint = part(tile, "door_paint")
        cls, sill_h = WINDOW[kind]
        (pw, ph), _ = PANES[cls]
        bay = BAY[kind]
        bays = max(1, int(length // bay))
        margin = (length - bays * bay) / 2
        openings = []
        ground_top = lot["ground_top"]
        storey = STOREY[kind]
        seed = lot["seed"] * 997.0 + (0.5 if end else 0.0) + (0.25 if not front else 0.0)
        # Upper floors.
        floor = ground_top
        level = 1
        while floor + storey <= top - 0.6:
            for k in range(bays):
                uc = margin + (k + 0.5) * bay
                u0, u1 = uc - pw / 2, uc + pw / 2
                v0, v1 = floor + sill_h, floor + sill_h + ph
                if v1 > top - 0.8:
                    continue
                openings.append((u0, u1, v0, v1, "w"))
                self.pane(cls, f, u0, u1, v0, v1, seed + level * 31 + k)
                slab(trim, f, u0 - 0.08, u1 + 0.08, v0 - 0.1, v0, -0.02, 0.07)
                if kind == "walkup":
                    slab(trim, f, u0 - 0.1, u1 + 0.1, v1, v1 + 0.22, -0.02, 0.03, bottom=True)
            floor += storey
            level += 1
        # Ground floor.
        if front and lot["shop"]:
            # Shopfront: piers, display windows, recessed door, fascia.
            door = lot["door_u"] if lot["door_u"] is not None else length / 2
            door = min(max(door, 1.4), length - 1.4)
            d0, d1 = door - 0.6, door + 0.6
            sill, head = base + 0.55, min(ground_top - 0.9, base + 3.0)
            for u0, u1 in ((0.5, d0 - 0.3), (d1 + 0.3, length - 0.5)):
                if u1 - u0 < 0.8:
                    continue
                openings.append((u0, u1, sill, head, "s"))
                self.pane("store", f, u0, u1, sill, head, seed + 7 + u0)
                slab(paint, f, u0, u1, base, sill, -0.02, 0.04)
            openings.append((d0, d1, base, head, "d"))
            quad(paint, f, d0, d1, base, head, -0.9)  # recessed door
            for u in (d0, d1):
                p = paint
                p.face([f.P(u, base, 0), f.P(u, head, 0), f.P(u, head, -0.9), f.P(u, base, -0.9)],
                       [(0, base), (0, head), (0.9, head), (0.9, base)], centre=f.P(u + (-1 if u == d0 else 1), (base + head) / 2, -0.45))
            quad(paint, f, d0, d1, head, head + 0.001, -0.9)
            slab(paint, f, 0.3, length - 0.3, head + 0.05, ground_top - 0.1, -0.02, 0.09)  # fascia
            if lot["awning"]:
                self.awning(lot, f, 0.4, length - 0.4, head)
        elif front and kind == "walkup":
            # Stoop entry: raised parlour floor and a recessed door at the stoop's head.
            door = lot["door_u"] if lot["door_u"] is not None else length / 2
            door = min(max(door, 1.0), length - 1.0)
            d0, d1 = door - 0.55, door + 0.55
            rise = lot["stoop_rise"]
            openings.append((d0, d1, base + rise, base + rise + 2.5, "d"))
            quad(paint, f, d0, d1, base + rise, base + rise + 2.5, -0.5)
            for k in range(bays):
                uc = margin + (k + 0.5) * bay
                if abs(uc - door) < 1.3:
                    continue
                u0, u1, v0, v1 = uc - pw / 2, uc + pw / 2, base + rise + 0.8, base + rise + 0.8 + ph
                if v1 < ground_top - 0.2:
                    openings.append((u0, u1, v0, v1, "w"))
                    self.pane("sash", f, u0, u1, v0, v1, seed + 3 + k)
                    slab(trim, f, u0 - 0.08, u1 + 0.08, v0 - 0.1, v0, -0.02, 0.07)
            self.stoop(lot, f, door, base, rise)
        elif front:
            # Loft and works: one loading door and display or shop windows.
            door = lot["door_u"] if lot["door_u"] is not None else length * 0.3
            dw = 3.0 if kind != "walkup" else 1.2
            door = min(max(door, dw / 2 + 0.6), length - dw / 2 - 0.6)
            d0, d1 = door - dw / 2, door + dw / 2
            head = min(base + 3.4, ground_top - 0.5)
            openings.append((d0, d1, base, head, "d"))
            quad(paint, f, d0, d1, base, head, -0.35)
            for k in range(bays):
                uc = margin + (k + 0.5) * bay
                if abs(uc - door) < dw / 2 + pw / 2 + 0.4:
                    continue
                u0, u1, v0, v1 = uc - pw / 2, uc + pw / 2, base + 1.0, min(base + 1.0 + ph, ground_top - 0.4)
                if v1 - v0 > 0.8:
                    openings.append((u0, u1, v0, v1, "w"))
                    self.pane(cls, f, u0, u1, v0, v1, seed + 5 + k)
        self.wall_with_openings(wall, f, length, lot["y0"], top, openings, lot["colour"])
        # Cornice or coping.
        if front or end:
            if kind in ("walkup", "loft"):
                mat = "galvanized_roof" if kind == "walkup" else "terracotta"
                slab(part(tile, mat), f, -0.25, length + 0.25, top - 0.75, top - 0.15, -0.05, 0.55)
            slab(trim, f, -0.05, length + 0.05, top - 0.12, top, -0.3, 0.06)

    def awning(self, lot, f, u0, u1, head):
        p = part(lot["tile"], "fabric_warm")
        y_hi, y_lo, out = head + 0.35, head - 0.25, 1.5
        pts = [f.P(u0, y_hi, 0.05), f.P(u1, y_hi, 0.05), f.P(u1, y_lo, out), f.P(u0, y_lo, out)]
        slope = math.hypot(out, y_hi - y_lo)
        p.face(pts, [(u0, slope), (u1, slope), (u1, 0), (u0, 0)], centre=f.P((u0 + u1) / 2, y_lo - 1, 0))
        p.face(pts, [(u0, slope), (u1, slope), (u1, 0), (u0, 0)], centre=f.P((u0 + u1) / 2, y_hi + 2, out + 2))
        quad(p, f, u0, u1, y_lo - 0.3, y_lo, out, outward=True)  # valance
        for u in (u0, u1):
            pts = [f.P(u, y_hi, 0.05), f.P(u, y_lo, out), f.P(u, y_lo - 0.3, out)]
            p.face(pts, [(0, 0.6), (1.5, 0), (1.5, 0.3)], centre=f.P(u + (-1 if u == u0 else 1), y_lo, 0.7))
            p.face(pts, [(0, 0.6), (1.5, 0), (1.5, 0.3)], centre=f.P(u + (1 if u == u0 else -1), y_lo, 0.7))

    def stoop(self, lot, f, door, base, rise):
        p = part(lot["tile"], "limestone")
        steps = max(3, int(round(rise / 0.18)))
        tread = 0.3
        for k in range(steps):
            top = base + rise * (k + 1) / steps
            out = (steps - k) * tread + 0.2
            slab(p, f, door - 0.9, door + 0.9, base, top, -0.01, out, bottom=False)
        # Cheek walls stepping down with the treads, and an iron rail along them.
        iron = part(lot["tile"], "iron_blackened")
        for u in (door - 1.05, door + 0.9):
            for k in range(steps):
                top = base + rise * (k + 1) / steps
                slab(p, f, u, u + 0.15, base, top + 0.12, (steps - k - 1) * tread + 0.2, (steps - k) * tread + 0.2, bottom=False)
            a = f.P(u + 0.05, base + rise / steps + 0.95, steps * tread + 0.1)
            b = f.P(u + 0.05, base + rise + 0.95, 0.15)
            run = math.dist(a, b)
            for d in (0.0, 0.05):
                pts = [a, b, (b[0], b[1] + 0.05, b[2]), (a[0], a[1] + 0.05, a[2])]
                iron.face(pts, [(0, 0), (run, 0), (run, 0.05), (0, 0.05)], centre=f.P(u + (-1 if d == 0 else 1), base + rise, 0.8))
        a = f.P(door - 1.05, 0, -0.01)
        b = f.P(door + 1.05, 0, steps * tread + 0.2)
        self.colliders.append(self._box_from(a, b, base, base + rise))

    @staticmethod
    def _box_from(a, b, y0, y1):
        x0, x1 = sorted((a[0], b[0]))
        z0, z1 = sorted((a[2], b[2]))
        return [round((x0 + x1) / 2, 3), round((y0 + y1) / 2, 3), round((z0 + z1) / 2, 3),
                round(x1 - x0, 3), round(y1 - y0, 3), round(z1 - z0, 3)]

    def fire_escape(self, lot, f, u0, levels):
        p = part(lot["tile"], "iron_blackened")
        width, depth = 2 * BAY["walkup"] - 0.2, 1.05
        for k, y in enumerate(levels):
            slab(p, f, u0, u0 + width, y - 0.05, y, 0.0, depth)
            slab(p, f, u0, u0 + width, y + 0.95, y + 1.0, depth - 0.04, depth)
            slab(p, f, u0, u0 + width, y + 0.45, y + 0.48, depth - 0.04, depth, bottom=False)
            for u in (u0, u0 + width / 2, u0 + width - 0.04):
                slab(p, f, u, u + 0.04, y, y + 1.0, depth - 0.04, depth, bottom=False)
            for u in (u0, u0 + width - 0.04):
                slab(p, f, u, u + 0.04, y + 0.95, y + 1.0, 0.0, depth, bottom=False)
            if k + 1 < len(levels):
                # Stair between platforms, as a stringer pair.
                y1 = levels[k + 1]
                for d in (0.15, 0.6):
                    a = f.P(u0 + 0.3, y, d)
                    b = f.P(u0 + width - 0.6, y1, d)
                    c = (f.t[0] * 0, 0, 0)
                    del c
                    pts = [a, (b[0], b[1], b[2]), (b[0], b[1] + 0.12, b[2]), (a[0], a[1] + 0.12, a[2])]
                    run = math.dist(a, b)
                    p.face(pts, [(0, 0), (run, 0), (run, 0.12), (0, 0.12)], centre=f.P(u0, y, -1))
                    p.face(pts, [(0, 0), (run, 0), (run, 0.12), (0, 0.12)], centre=f.P(u0, y, 3))

    def roof(self, lot, x0, z0, x1, z1, top):
        tile = lot["tile"]
        roof = part(tile, "roof_bitumen")
        deck = top - 0.9
        roof.face([(x0, deck, z0), (x1, deck, z0), (x1, deck, z1), (x0, deck, z1)],
                  [(x0, z0), (x1, z0), (x1, z1), (x0, z1)], centre=((x0 + x1) / 2, deck - 1, (z0 + z1) / 2))
        wall = part(tile, lot["wall"])
        t = 0.3
        inner = [((x0 + t, z0 + t), (x1 - t, z0 + t)), ((x1 - t, z0 + t), (x1 - t, z1 - t)),
                 ((x1 - t, z1 - t), (x0 + t, z1 - t)), ((x0 + t, z1 - t), (x0 + t, z0 + t))]
        cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
        for (ax, az), (bx, bz) in inner:
            length = math.hypot(bx - ax, bz - az)
            mx, mz = (ax + bx) / 2, (az + bz) / 2
            away = (mx + (mx - cx) * 0.01 + (mx - cx) / max(abs(mx - cx), 1e-6) * 0 if False else mx, deck, mz)
            del away
            wall.face([(ax, deck, az), (bx, deck, bz), (bx, top, bz), (ax, top, az)],
                      [(0, deck), (length, deck), (length, top), (0, top)], lot["colour"],
                      (mx + (mx - cx) * 0.2, (deck + top) / 2, mz + (mz - cz) * 0.2))
        coping = part(tile, "limestone")
        for (ax, az, bx, bz) in ((x0, z0, x1, z0 + t), (x0, z1 - t, x1, z1), (x0, z0 + t, x0 + t, z1 - t), (x1 - t, z0 + t, x1, z1 - t)):
            coping.face([(ax, top, az), (bx, top, az), (bx, top, bz), (ax, top, bz)], [(ax, az), (bx, az), (bx, bz), (ax, bz)],
                        centre=((ax + bx) / 2, top - 1, (az + bz) / 2))
        # Roof furniture.
        rng = random.Random(lot["seed"] * 1e6)
        brick = part(tile, lot["wall"])
        w, d = x1 - x0, z1 - z0
        if lot["kind"] in ("walkup", "loft"):
            for k in range(rng.randint(1, 2)):
                cx_ = x0 + 0.6 + rng.random() * (w - 1.8)
                cz_ = z0 + 0.6 + rng.random() * (d - 1.8)
                box_world(brick, cx_, cz_, cx_ + 0.9, cz_ + 0.6, deck, top + 1.4, lot["colour"])
            if w > 6 and d > 8:
                bx_ = x0 + w * 0.5 - 1.2
                bz_ = z0 + d * 0.55
                box_world(brick, bx_, bz_, bx_ + 2.4, bz_ + 3.0, deck, deck + 2.7, lot["colour"])
            if lot["floors"] >= 5 and rng.random() < 0.35 and w > 6:
                tx, tz = x0 + w * rng.uniform(0.3, 0.7), z0 + d * rng.uniform(0.25, 0.4)
                staves = part(tile, "tank_staves")
                iron = part(tile, "iron_blackened")
                for lx, lz in ((-1.2, -1.2), (1.2, -1.2), (1.2, 1.2), (-1.2, 1.2)):
                    box_world(iron, tx + lx - 0.08, tz + lz - 0.08, tx + lx + 0.08, tz + lz + 0.08, deck, deck + 3.2)
                box_world(iron, tx - 1.5, tz - 1.5, tx + 1.5, tz + 1.5, deck + 3.2, deck + 3.4)
                cylinder_world(staves, tx, tz, 1.55, deck + 3.4, deck + 6.6, 12, top=False)
                roofc = part(tile, "roof_bitumen")
                ring = [(tx + 1.6 * math.cos(2 * math.pi * k / 12), tz + 1.6 * math.sin(2 * math.pi * k / 12)) for k in range(12)]
                for k in range(12):
                    a, b = ring[k], ring[(k + 1) % 12]
                    roofc.face([(a[0], deck + 6.6, a[1]), (b[0], deck + 6.6, b[1]), (tx, deck + 7.6, tz)],
                               [(0, 0), (1, 0), (0.5, 1)], centre=(tx, deck + 6.0, tz))

    # Buildings --------------------------------------------------------------------
    def building(self, lot):
        x0, z0, x1, z1 = lot["rect"]
        axis, side, kind = lot["axis"], lot["side"], lot["kind"]
        rng = random.Random(lot["seed"] * 1e7)
        lot["tile"] = tile_of((x0 + x1) / 2, (z0 + z1) / 2)
        lot["wall"] = rng.choice(WALLS[kind])
        tint = rng.uniform(-0.5, 0.5)
        lot["colour"] = (lot["seed"], KIND_CODE[kind] / 4, STOREY[kind] / 6, 0.5 + tint * 0.4)
        front_y = max(ground((x0 + x1) / 2, z0 if (axis == "x" and side > 0) else z1), ground(x0, z0)) + 0.17
        lows = [ground(x, z) for x in (x0, x1) for z in (z0, z1)]
        lot["y0"] = min(lows + [front_y - 0.17]) - 0.6
        base = front_y
        floors = {"walkup": rng.randint(4, 6), "loft": rng.randint(5, 8), "works": rng.randint(2, 4),
                  "waterfront": rng.randint(3, 6)}[kind]
        lot["floors"] = floors
        on_avenue = lot["street_z"] is not None and abs(lot["street_z"] - AVENUE_Z) < 1
        shop = kind == "walkup" and (lot["corner"] or rng.random() < 0.3 or on_avenue)
        shop = shop or (kind == "loft" and rng.random() < 0.45)
        lot["shop"] = shop
        lot["awning"] = shop and rng.random() < 0.6
        lot["stoop_rise"] = 1.2
        ground_storey = 4.2 if shop else (STOREY[kind] + (lot["stoop_rise"] if kind == "walkup" else 0.6))
        lot["ground_top"] = base + ground_storey
        top = lot["ground_top"] + (floors - 1) * STOREY[kind] + 1.2
        lot["door_u"] = None
        # Frames: front, rear, ends. Outward normals point away from the lot.
        if axis == "x":
            front = Frame((x0, z0), (1, 0), (0, -1)) if side > 0 else Frame((x1, z1), (-1, 0), (0, 1))
            rear = Frame((x1, z1), (-1, 0), (0, 1)) if side > 0 else Frame((x0, z0), (1, 0), (0, -1))
            flen, elen = x1 - x0, z1 - z0
            ends = [Frame((x0, z1), (0, -1), (-1, 0)), Frame((x1, z0), (0, 1), (1, 0))]
        else:
            front = Frame((x0, z1), (0, -1), (-1, 0)) if side > 0 else Frame((x1, z0), (0, 1), (1, 0))
            rear = Frame((x1, z0), (0, 1), (1, 0)) if side > 0 else Frame((x0, z1), (0, -1), (-1, 0))
            flen, elen = z1 - z0, x1 - x0
            ends = [Frame((x0, z0), (1, 0), (0, -1)), Frame((x1, z1), (-1, 0), (0, 1))]
        self.facade(lot, front, flen, base, top, True)
        self.facade(lot, rear, flen, base, top, False)
        for k, f in enumerate(ends):
            exposed = k in lot["corner_ends"]
            if exposed:
                self.facade(lot, f, elen, base, top, False, end=True)
            else:
                quad(part(lot["tile"], lot["wall"]), f, 0, elen, lot["y0"], top, 0, lot["colour"])
        if kind == "walkup" and floors >= 4 and flen >= 2 * BAY["walkup"] + 0.6:
            bays = int(flen // BAY["walkup"])
            margin = (flen - bays * BAY["walkup"]) / 2
            u0 = margin + max(0, bays // 2 - 1) * BAY["walkup"] + 0.1
            levels = [lot["ground_top"] + k * STOREY[kind] + 0.0 for k in range(floors - 1)]
            self.fire_escape(lot, front, u0, levels)
        self.roof(lot, x0, z0, x1, z1, top)
        self.colliders.append([round((x0 + x1) / 2, 3), round((lot["y0"] + top) / 2, 3), round((z0 + z1) / 2, 3),
                               round(x1 - x0, 3), round(top - lot["y0"], 3), round(z1 - z0, 3)])
        far = part("far" + lot["tile"][1:], "far_" + lot["wall"])
        box_world(far, x0, z0, x1, z1, lot["y0"], top, lot["colour"], top=False)
        part("far" + lot["tile"][1:], "roof_bitumen").face(
            [(x0, top, z0), (x1, top, z0), (x1, top, z1), (x0, top, z1)], [(x0, z0), (x1, z0), (x1, z1), (x0, z1)],
            centre=((x0 + x1) / 2, top - 1, (z0 + z1) / 2))
        self.lots_out.append({"rect": [round(v, 2) for v in lot["rect"]], "kind": kind, "floors": floors,
                              "top": round(top, 2), "shop": shop})
        lot["front_frame"], lot["front_len"], lot["base"] = front, flen, base

    # Streets ----------------------------------------------------------------------
    def strip(self, mat, x0, z0, x1, z1, lift, step=8.0):
        """A ground strip following the installed grade, subdivided for the slope."""
        tile = tile_of((x0 + x1) / 2, (z0 + z1) / 2)
        p = part(("g" if walkable(x0, z0, x1, z1) else "v") + tile[1:], mat)
        nx = max(1, int(math.ceil((x1 - x0) / step)))
        nz = max(1, int(math.ceil((z1 - z0) / step)))
        for i in range(nx):
            for j in range(nz):
                a0, a1 = x0 + (x1 - x0) * i / nx, x0 + (x1 - x0) * (i + 1) / nx
                b0, b1 = z0 + (z1 - z0) * j / nz, z0 + (z1 - z0) * (j + 1) / nz
                pts = [(a0, ground(a0, b0) + lift, b0), (a1, ground(a1, b0) + lift, b0),
                       (a1, ground(a1, b1) + lift, b1), (a0, ground(a0, b1) + lift, b1)]
                p.face(pts, [(a0, b0), (a1, b0), (a1, b1), (a0, b1)], centre=((a0 + a1) / 2, pts[0][1] - 1, (b0 + b1) / 2))

    def curb_face(self, ax, az, bx, bz, facing, step=8.0):
        """Vertical limestone face from road top to walk top, looking toward `facing` (x, z)."""
        tile = tile_of((ax + bx) / 2, (az + bz) / 2)
        p = part(("g" if walkable(min(ax, bx), min(az, bz), max(ax, bx), max(az, bz)) else "v") + tile[1:], "limestone")
        length = math.hypot(bx - ax, bz - az)
        n = max(1, int(math.ceil(length / step)))
        for k in range(n):
            x0_, z0_ = ax + (bx - ax) * k / n, az + (bz - az) * k / n
            x1_, z1_ = ax + (bx - ax) * (k + 1) / n, az + (bz - az) * (k + 1) / n
            g0, g1 = ground(x0_, z0_), ground(x1_, z1_)
            pts = [(x0_, g0 - 0.05, z0_), (x1_, g1 - 0.05, z1_), (x1_, g1 + 0.17, z1_), (x0_, g0 + 0.17, z0_)]
            u0, u1 = length * k / n, length * (k + 1) / n
            mx, mz = (x0_ + x1_) / 2, (z0_ + z1_) / 2
            p.face(pts, [(u0, 0), (u1, 0), (u1, 0.22), (u0, 0.22)], centre=(mx - facing[0], g0, mz - facing[1]))

    def streets(self):
        L = self.layout
        rects = {i: L._rect(*s, HALF) for i, s in enumerate(L.streets)}
        for i, (axis, c, a, b) in enumerate(L.streets):
            if axis == "x":
                self.strip("asphalt", a, c - ROAD / 2, b, c + ROAD / 2, 0.02)
            else:
                self.strip("asphalt", c - ROAD / 2, a, c + ROAD / 2, b, 0.02)
            # Crossings: perpendicular streets whose ends touch this street's band.
            cuts = {-1: [], 1: []}
            for j, (axis2, c2, a2, b2) in enumerate(L.streets):
                if axis2 == axis or not (a - 1 <= c2 <= b + 1):
                    continue
                for end in (a2, b2):
                    if abs(end - (c - HALF)) < 2.0:
                        cuts[-1].append(c2)
                        self._road_ext(axis2, c2, c - HALF, c - ROAD / 2)
                    if abs(end - (c + HALF)) < 2.0:
                        cuts[1].append(c2)
                        self._road_ext(axis2, c2, c + ROAD / 2, c + HALF)
            for side in (-1, 1):
                spans = [(a, b)]
                for c2 in sorted(cuts[side]):
                    nxt = []
                    for s0, s1 in spans:
                        g0, g1 = c2 - ROAD / 2, c2 + ROAD / 2
                        if g1 <= s0 or g0 >= s1:
                            nxt.append((s0, s1))
                            continue
                        if g0 - s0 > 0.5:
                            nxt.append((s0, g0))
                        if s1 - g1 > 0.5:
                            nxt.append((g1, s1))
                    spans = nxt
                w0, w1 = sorted((c + side * ROAD / 2, c + side * HALF))
                for s0, s1 in spans:
                    if axis == "x":
                        self.strip("concrete", s0, w0, s1, w1, 0.17, 6.0)
                        edge = c + side * ROAD / 2
                        self.curb_face(s0, edge, s1, edge, (0, -side))
                        for e, fx in ((s0, -1), (s1, 1)):
                            if any(abs(e - (c2 - ROAD / 2)) < 0.6 or abs(e - (c2 + ROAD / 2)) < 0.6 for c2 in cuts[side]):
                                self.curb_face(e, w0, e, w1, (fx, 0))
                    else:
                        self.strip("concrete", w0, s0, w1, s1, 0.17, 6.0)
                        edge = c + side * ROAD / 2
                        self.curb_face(edge, s0, edge, s1, (-side, 0))
                        for e, fz in ((s0, -1), (s1, 1)):
                            if any(abs(e - (c2 - ROAD / 2)) < 0.6 or abs(e - (c2 + ROAD / 2)) < 0.6 for c2 in cuts[side]):
                                self.curb_face(w0, e, w1, e, (0, fz))
                self.furnish(axis, c, side, spans)
        del rects

    def _road_ext(self, axis, c, t0, t1):
        t0, t1 = sorted((t0, t1))
        if axis == "x":
            self.strip("asphalt", t0, c - ROAD / 2, t1, c + ROAD / 2, 0.02)
        else:
            self.strip("asphalt", c - ROAD / 2, t0, c + ROAD / 2, t1, 0.02)

    # Furniture --------------------------------------------------------------------
    def place(self, kind, x, z, yaw, collide=None):
        y = ground(x, z) + 0.17
        self.furniture.setdefault(kind, []).append([round(x, 3), round(y, 3), round(z, 3), round(yaw, 4)])
        if collide:
            sx, sy, sz = collide
            self.colliders.append([round(x, 3), round(y + sy / 2, 3), round(z, 3), sx, sy, sz])

    def furnish(self, axis, c, side, spans):
        rng = random.Random(int(c * 100) + side * 7 + (1 if axis == "x" else 2))
        kerb = c + side * (ROAD / 2 + 0.55)
        yaw = (0.0 if side > 0 else math.pi) if axis == "x" else (math.pi / 2 if side > 0 else -math.pi / 2)
        for s0, s1 in spans:
            length = s1 - s0
            if length < 4:
                continue
            offset = 14.0 if side > 0 else 30.0
            t = s0 + offset
            while t < s1 - 3:
                x, z = (t, kerb) if axis == "x" else (kerb, t)
                if math.hypot(x, z) < RING - 4:
                    self.place("lamp", x, z, yaw, (0.35, 4.2, 0.35))
                t += 32.0
            # Corners: a hydrant at one end, a mailbox or call box at the other.
            for e, sgn in ((s0, 1), (s1, -1)):
                tt = e + sgn * 2.2
                x, z = (tt, kerb) if axis == "x" else (kerb, tt)
                if math.hypot(x, z) > RING - 4:
                    continue
                roll = rng.random()
                if roll < 0.45:
                    self.place("hydrant", x, z, yaw + rng.uniform(-0.4, 0.4), (0.4, 0.8, 0.4))
                elif roll < 0.6:
                    self.place("mailbox", x, z, yaw, (0.5, 1.5, 0.5))
                elif roll < 0.72:
                    self.place("callbox", x, z, yaw, (0.4, 1.7, 0.4))
            t = s0 + rng.uniform(8, 20)
            while t < s1 - 5:
                if rng.random() < 0.4:
                    x, z = (t, kerb) if axis == "x" else (kerb, t)
                    if math.hypot(x, z) < RING - 4:
                        self.place("ashcan", x, z, rng.uniform(0, math.tau), (0.6, 0.8, 0.6))
                t += rng.uniform(12, 26)

    def fences(self):
        """Board fences along every building line not filled by a building."""
        L = self.layout
        lots = L.lots
        for axis, c, a, b in L.streets:
            for side in (-1, 1):
                line = c + side * HALF + side * 0.15
                covered = []
                for lot in lots:
                    x0, z0, x1, z1 = lot["rect"]
                    if axis == "x" and z0 - 0.5 <= line <= z1 + 0.5 and lot["axis"] == "x":
                        covered.append((x0, x1))
                    if axis == "z" and x0 - 0.5 <= line <= x1 + 0.5 and lot["axis"] == "z":
                        covered.append((z0, z1))
                    # Corner lots of the other axis also cover the line where they meet it.
                    if axis == "x" and lot["axis"] == "z" and z0 - 0.5 <= line <= z1 + 0.5:
                        covered.append((x0, x1))
                    if axis == "z" and lot["axis"] == "x" and x0 - 0.5 <= line <= x1 + 0.5:
                        covered.append((z0, z1))
                covered.sort()
                t = a
                gaps = []
                for u0, u1 in covered:
                    if u0 - t > 2.0:
                        gaps.append((t, u0))
                    t = max(t, u1)
                if b - t > 2.0:
                    gaps.append((t, b))
                for g0, g1 in gaps:
                    self.fence(axis, line, g0, g1)

    def fence(self, axis, line, g0, g1):
        L = self.layout
        rect = (g0, line - 0.1, g1, line + 0.1) if axis == "x" else (line - 0.1, g0, line + 0.1, g1)
        if reserved(*rect) or L.occ.fraction_free(*rect) < 0.7:
            return
        if any(math.hypot(x, z) > RING + 25 for x, z in ((rect[0], rect[1]), (rect[2], rect[3]))):
            return
        tile = tile_of((rect[0] + rect[2]) / 2, (rect[1] + rect[3]) / 2)
        p = part(tile, "site_softwood")
        h = 2.4
        f = Frame((g0, line), (1, 0), (0, 1)) if axis == "x" else Frame((line, g0), (0, 1), (1, 0))
        n = max(1, int(math.ceil((g1 - g0) / 6)))
        for k in range(n):
            u0, u1 = (g1 - g0) * k / n, (g1 - g0) * (k + 1) / n
            gx = f.P((u0 + u1) / 2, 0)
            y0 = ground(gx[0], gx[2]) - 0.3
            quad(p, f, u0, u1, y0, y0 + h + 0.3, 0.04)
            quad(p, Frame(f.P(u1, 0), (-f.t[0], -f.t[1]), (-f.n[0], -f.n[1])), 0, u1 - u0, y0, y0 + h + 0.3, 0.04)
        x0, z0, x1, z1 = rect
        y = ground((x0 + x1) / 2, (z0 + z1) / 2)
        self.colliders.append([round((x0 + x1) / 2, 3), round(y + 1.2, 3), round((z0 + z1) / 2, 3),
                               round(x1 - x0, 3), 2.8, round(z1 - z0, 3)])

    def barricades(self):
        for bar in self.layout.barricades:
            x, z, axis, width = bar["x"], bar["z"], bar["axis"], bar["width"]
            yaw = math.pi / 2 if axis == "x" else 0.0
            for k in range(-2, 3):
                dx, dz = (0, k * width / 5) if axis == "x" else (k * width / 5, 0)
                self.place("sawhorse", x + dx, z + dz, yaw)
            self.place("lantern", x, z, yaw)
            sx, sz = (0.6, width) if axis == "x" else (width, 0.6)
            y = ground(x, z)
            self.colliders.append([round(x, 3), round(y + 0.7, 3), round(z, 3), sx, 1.6, sz])

    def run(self):
        L = self.layout
        for lot in L.lots:
            x0, z0, x1, z1 = lot["rect"]
            lot["corner"] = bool(lot["corner_ends"])
        for lot in L.lots:
            self.building(lot)
        self.streets()
        self.fences()
        self.barricades()
        return self


# --- Furniture stock -------------------------------------------------------------------

def furniture_stock():
    """Unit props at the origin, x east, y up, z south; the runtime instances them."""
    def p(kind, mat):
        return part("furn_" + kind, mat)
    # Lamp post: cast-iron base and shaft, a lantern of frosted glass.
    iron = p("lamp", "cast_iron")
    cylinder_world(iron, 0, 0, 0.22, 0.0, 0.9, 8)
    cylinder_world(iron, 0, 0, 0.09, 0.9, 3.7, 8)
    cylinder_world(iron, 0, 0, 0.16, 3.7, 3.8, 8)
    lamp = p("lamp", "glass_frosted")
    box_world(lamp, -0.2, -0.2, 0.2, 0.2, 3.8, 4.35)
    box_world(iron, -0.26, -0.26, 0.26, 0.26, 4.35, 4.45)
    # Hydrant.
    red = p("hydrant", "fire_cabinet_enamel")
    cylinder_world(red, 0, 0, 0.15, 0.0, 0.12, 10)
    cylinder_world(red, 0, 0, 0.12, 0.12, 0.7, 10)
    cylinder_world(red, 0, 0, 0.14, 0.7, 0.78, 10)
    box_world(red, -0.24, -0.05, 0.24, 0.05, 0.42, 0.52)
    # Mailbox: a pillar box on a post.
    green = p("mailbox", "door_paint")
    box_world(green, -0.05, -0.05, 0.05, 0.05, 0.0, 0.9)
    box_world(green, -0.25, -0.2, 0.25, 0.2, 0.9, 1.45)
    # Police call box.
    box_world(p("callbox", "cast_iron"), -0.12, -0.12, 0.12, 0.12, 0.0, 1.2)
    box_world(p("callbox", "door_paint"), -0.2, -0.16, 0.2, 0.16, 1.2, 1.7)
    # Ash can.
    cylinder_world(p("ashcan", "zinc_liner"), 0, 0, 0.28, 0.0, 0.72, 12)
    # Sawhorse barrier and a red lantern.
    wood = p("sawhorse", "site_softwood")
    box_world(wood, -1.0, -0.05, 1.0, 0.05, 0.8, 1.0)
    box_world(wood, -1.0, -0.05, 1.0, 0.05, 0.45, 0.6)
    for x in (-0.85, 0.85):
        box_world(wood, x - 0.05, -0.35, x + 0.05, 0.35, 0.0, 0.08)
        box_world(wood, x - 0.04, -0.04, x + 0.04, 0.04, 0.0, 1.0)
    box_world(p("lantern", "iron_blackened"), -0.08, -0.08, 0.08, 0.08, 1.0, 1.05)
    box_world(p("lantern", "glass_cut"), -0.07, -0.07, 0.07, 0.07, 1.05, 1.25)


# --- Export ----------------------------------------------------------------------------

def export(builder):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    materials = {}
    tris = 0
    for (group, mat), p in sorted(PARTS.items()):
        name = f"{group}__{mat}"
        mesh = bpy.data.meshes.new(name)
        bmesh.ops.remove_doubles(p.bm, verts=p.bm.verts, dist=0.0005)
        if not group.startswith("far"):
            # Only the far-facade shader reads COLOR_0; elsewhere it is dead weight.
            p.bm.loops.layers.color.remove(p.col)
        # Tiles get their origin at their centre: visibility ranges measure from it.
        origin = (0.0, 0.0, 0.0)
        if not group.startswith("furn_") and p.bm.verts:
            xs = [v.co.x for v in p.bm.verts]
            ys = [v.co.y for v in p.bm.verts]
            origin = ((min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2, 0.0)
            for v in p.bm.verts:
                v.co.x -= origin[0]
                v.co.y -= origin[1]
        p.bm.to_mesh(mesh)
        p.bm.free()
        if mat not in materials:
            materials[mat] = bpy.data.materials.new(mat)
        mesh.materials.append(materials[mat])
        obj = bpy.data.objects.new(name, mesh)
        obj.location = origin
        bpy.context.scene.collection.objects.link(obj)
        tris += sum(len(poly.vertices) - 2 for poly in mesh.polygons)
    print("MIDGROUND objects", len(bpy.context.scene.objects), "triangles", tris)
    bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", export_yup=True, export_apply=True,
                              export_vertex_color="ACTIVE", export_normals=True, export_texcoords=True,
                              export_materials="PLACEHOLDER")
    print("MIDGROUND wrote", OUT)


def write_data(builder):
    # Only what the runtime composer reads, by name (the reader gate). Pane items are
    # [x, y, z, normal_x, normal_z, scale_w, scale_h, seed]; furniture items [x, y, z, yaw];
    # colliders [cx, cy, cz, sx, sy, sz], walkable ones only.
    data = {"schema": 1, "frame": "WORLD", "tile_m": TILE,
            "panes": [{"class": k, "size": list(PANES[k][0]), "room_kind": PANES[k][1], "items": v}
                      for k, v in builder.panes.items()],
            "furniture": [{"kind": k, "items": v} for k, v in builder.furniture.items()],
            "colliders": [c for c in builder.colliders
                          if walkable(c[0] - c[3] / 2, c[2] - c[5] / 2, c[0] + c[3] / 2, c[2] + c[5] / 2)]}
    with open(DATA, "w", encoding="utf8", newline="\n") as handle:
        handle.write(json.dumps(data, separators=(",", ":")) + "\n")
    # The layout record is authoring evidence, not runtime data.
    layout = {"walkable_m": WALKABLE, "lots": builder.lots_out,
              "streets": [[s[0], round(s[1], 3), round(s[2], 2), round(s[3], 2)] for s in builder.layout.streets]}
    with open(OCC + "layout.json", "w", encoding="utf8", newline="\n") as handle:
        handle.write(json.dumps(layout, separators=(",", ":")) + "\n")
    print("MIDGROUND data", DATA, {k: len(v) for k, v in builder.panes.items()},
          {k: len(v) for k, v in builder.furniture.items()}, "colliders", len(builder.colliders))


if __name__ == "__main__":
    layout = Layout(Occupancy()).run()
    if "--plan" in sys.argv:
        plan_png(layout, PLAN_PNG)
    else:
        builder = Builder(layout).run()
        furniture_stock()
        export(builder)
        write_data(builder)
