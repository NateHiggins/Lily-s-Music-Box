"""Distant districts beyond the composed V2 city: midtown Manhattan, Welfare Island,
north and south Long Island City, Sunnyside, Newtown Creek and Greenpoint.

    blender -b --python-exit-code 1 -P art/blender/scripts/build_city_far_districts.py

Writes game/assets/props/city_far_districts.glb. Coordinates are written in the
Godot frame of the V2 runtime root (x east, y up, z south, metres) and converted
to Blender's Z-up axes only when each vertex is emitted, so the glTF exporter's
+Y-up conversion returns them unchanged.

Every surface has metric UV0: vertical faces run U along the wall and V up it,
horizontal faces use world X/Z. COLOR_0 carries optical parameters for the
far-facade shader (R building seed, G kind/4, B storey height/6, A lit bias);
it is not paint. Material names are catalogue keys with a "far_" prefix for
the shader facades. Nothing here is gameplay, collision or a save owner.

Landmark positions are real 1929 midtown and Long Island City sites, measured
from the Queensboro Bridge's Manhattan anchorage and the composed Court Square
origin, then fitted to the game's straight north-south river. Reference
photographs informed form only (RUL-007); no lettering or signage (RUL-008).
"""
import math
import random

import bmesh
import bpy

ROOT = __file__.replace("\\", "/").split("/art/blender/")[0]
OUT = ROOT + "/game/assets/props/city_far_districts.glb"

# Existing composed ground, measured from the installed bridge and apron glTFs.
SHEET = (-1800.0, 880.0, -2200.0, 480.0)  # x0, x1, z0, z1 of the bridge's land and river sheet
APRON = 500.0
# The blockout ground (apron, horizon ring, Orison) is turned 180 degrees in the world
# and shifted north: world = (-local.x, local.y, -local.z - 11.65). Probed in the
# composed runtime (tests/V2FrameProbe.tscn); this file writes world coordinates.
BLOCKOUT_Z = -11.65
LIMIT = 3800.0  # inside the playable camera's 4000 m far plane
MANHATTAN_SHORE_X = -1180.0
GRID_YAW = math.radians(29.708333)  # Manhattan's grid angle off true north
# Crosstown streets run parallel to the bridge (west-north-west), so local east maps to
# (cos, +sin) in x/z: going west climbs north, as the Queensboro does.
YAW_M = -GRID_YAW
ANCHOR = (-1235.4, -1092.9)  # the bridge's Manhattan end in runtime coordinates
BRIDGE_Q = (-250.0, -529.8)
BRIDGE_DIR = (math.sin(math.radians(119.708333)), -(-math.cos(math.radians(119.708333))))
STEP = 20.0  # matches the bridge-sheet survey

KIND_TENEMENT, KIND_OFFICE, KIND_FACTORY, KIND_BLANK = 0, 1, 2, 3


class Part:
    def __init__(self):
        self.bm = bmesh.new()
        self.uv = self.bm.loops.layers.uv.new("UVMap")
        self.col = self.bm.loops.layers.color.new("Color")

    def face(self, points, uvs, color, centre=None):
        """centre: a point behind the face; the face is flipped so it looks away from it."""
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
        return f


PARTS = {}
STACKS = []  # chimney tops for the smoke owner: x, top y, z, radius


def part(district, material):
    key = (district, material)
    if key not in PARTS:
        PARTS[key] = Part()
    return PARTS[key]


def rot(lx, lz, yaw):
    c, s = math.cos(yaw), math.sin(yaw)
    return c * lx + s * lz, -s * lx + c * lz


def quad_wall(p, a, b, y0, y1, color, centre=None):
    """A vertical wall from a to b (x,z), facing outward to the right of a->b."""
    length = math.hypot(b[0] - a[0], b[1] - a[1])
    pts = [(a[0], y0, a[1]), (b[0], y0, b[1]), (b[0], y1, b[1]), (a[0], y1, a[1])]
    uvs = [(0, y0), (length, y0), (length, y1), (0, y1)]
    p.face(pts, uvs, color, centre)


def cap(p, corners, y, color, up=True):
    pts = [(c[0], y, c[1]) for c in corners]
    mx, mz = sum(c[0] for c in corners) / len(corners), sum(c[1] for c in corners) / len(corners)
    p.face(pts, [(q[0], q[2]) for q in pts], color, (mx, y - 1 if up else y + 1, mz))


def box(district, wall, roof, x, z, w, d, y0, h, yaw=0.0, color=(0.5, 0, 0.6, 0.5), top=True):
    hw, hd = w / 2, d / 2
    local = [(-hw, -hd), (hw, -hd), (hw, hd), (-hw, hd)]
    corners = [(x + rot(lx, lz, yaw)[0], z + rot(lx, lz, yaw)[1]) for lx, lz in local]
    p = part(district, wall)
    # Counter-clockwise seen from above in Godot (x east, z south) means outward walls
    # run corner i -> i+1 when listed north-west, north-east, south-east, south-west.
    for i in range(4):
        quad_wall(p, corners[i], corners[(i + 1) % 4], y0, y0 + h, color, (x, y0 + h / 2, z))
    if top:
        cap(part(district, roof), corners, y0 + h, color)
    return corners


def prism_roof(district, mat, corners, y, rise, color):
    """A gabled or sawtooth-like ridge along the long side of a box top."""
    a, b, c, d = corners
    if math.dist(a, b) < math.dist(b, c):
        a, b, c, d = b, c, d, a
    m1 = ((a[0] + d[0]) / 2, (a[1] + d[1]) / 2)
    m2 = ((b[0] + c[0]) / 2, (b[1] + c[1]) / 2)
    p = part(district, mat)
    cx, cz = sum(q[0] for q in corners) / 4, sum(q[1] for q in corners) / 4
    run = math.dist(a, d) / 2
    slope = math.hypot(run, rise)
    length = math.dist(a, b)
    for lo1, lo2, hi1, hi2 in ((a, b, m1, m2), (c, d, m2, m1)):
        pts = [(lo1[0], y, lo1[1]), (lo2[0], y, lo2[1]), (hi2[0], y + rise, hi2[1]), (hi1[0], y + rise, hi1[1])]
        p.face(pts, [(0, 0), (length, 0), (length, slope), (0, slope)], color, (cx, y - 1, cz))
    for lo1, lo2, hi in ((b, c, m2), (d, a, m1)):
        pts = [(lo1[0], y, lo1[1]), (lo2[0], y, lo2[1]), (hi[0], y + rise, hi[1])]
        p.face(pts, [(0, 0), (math.dist(lo1, lo2), 0), (math.dist(lo1, lo2) / 2, rise)], color, (cx, y, cz))


def cylinder(district, wall, roof, x, z, r, y0, h, segments=12, color=(0.5, 0.75, 0.6, 0), top=True, taper=1.0):
    p = part(district, wall)
    ring0 = [(x + r * math.cos(2 * math.pi * i / segments), z + r * math.sin(2 * math.pi * i / segments)) for i in range(segments)]
    rt = r * taper
    ring1 = [(x + rt * math.cos(2 * math.pi * i / segments), z + rt * math.sin(2 * math.pi * i / segments)) for i in range(segments)]
    arc = 2 * math.pi * r / segments
    for i in range(segments):
        j = (i + 1) % segments
        # Reverse winding so the outward face is front-facing for a ring listed clockwise in x/z.
        pts = [(ring0[j][0], y0, ring0[j][1]), (ring0[i][0], y0, ring0[i][1]),
               (ring1[i][0], y0 + h, ring1[i][1]), (ring1[j][0], y0 + h, ring1[j][1])]
        p.face(pts, [(arc * (i + 1), y0), (arc * i, y0), (arc * i, y0 + h), (arc * (i + 1), y0 + h)], color, (x, y0 + h / 2, z))
    if top:
        cap(part(district, roof), list(reversed(ring1)), y0 + h, color)


def lattice(district, mat, corners, y0, y1, bay, member=0.6, color=(0.5, 0.75, 0.0, 0)):
    """Open steel framing: corner columns, floor girders every bay, on a rectangle."""
    for cx, cz in corners:
        box(district, mat, mat, cx, cz, member, member, y0, y1 - y0, color=color)
    y = y0 + bay
    while y < y1:
        for i in range(4):
            a, b = corners[i], corners[(i + 1) % 4]
            mx, mz = (a[0] + b[0]) / 2, (a[1] + b[1]) / 2
            length = math.dist(a, b)
            yaw = -math.atan2(b[1] - a[1], b[0] - a[0])
            box(district, mat, mat, mx, mz, length, member * 0.7, y, member * 0.7, yaw=yaw, color=color)
        y += bay


def setback(district, wall, roof, x, z, w, d, tiers, yaw, color, crown=None):
    """tiers: list of (height to top of tier, fraction of base footprint)."""
    y = 0.0
    corners = None
    for top, frac in tiers:
        corners = box(district, wall, roof, x, z, w * frac, d * frac, y, top - y, yaw, color)
        y = top
    if crown == "pyramid":
        p = part(district, "city_slate")
        apex = (x, y + w * 0.32, z)
        for i in range(4):
            a, b = corners[i], corners[(i + 1) % 4]
            pts = [(a[0], y, a[1]), (b[0], y, b[1]), apex]
            p.face(pts, [(0, 0), (math.dist(a, b), 0), (math.dist(a, b) / 2, w * 0.32)], color, (x, y, z))
    elif crown == "spire":
        cylinder(district, "copper_aged", "copper_aged", x, z, w * 0.06, y, w * 0.55, 8, color, taper=0.05)
    return y


# --- Ground, river and creek outside the existing sheets -------------------------------
# Heights of the installed ground, raycast from the bridge sheet (20 m grid over +-2600 m)
# and the apron (4 m grid over +-520 m). New ground extends their edges outward so no
# seam or cliff appears where the installed sheets stop.
import numpy as np

SURVEY = ROOT + "/art/blender/data/city_far_survey/"  # survey_city_far_ground.py
H_FAR = np.load(SURVEY + "h_far.npy")
H_NEAR = np.load(SURVEY + "h_near.npy")


def _bilinear(grid, lim, step, x, z):
    fx, fz = (x + lim) / step, (z + lim) / step
    i, j = int(math.floor(fx)), int(math.floor(fz))
    tx, tz = fx - i, fz - j
    vals = []
    for dj, di in ((0, 0), (0, 1), (1, 0), (1, 1)):
        jj, ii = min(max(j + dj, 0), grid.shape[0] - 1), min(max(i + di, 0), grid.shape[1] - 1)
        vals.append(grid[jj, ii])
    if any(np.isnan(v) for v in vals):
        good = [v for v in vals if not np.isnan(v)]
        return float(sum(good) / len(good)) if good else 0.0
    top = vals[0] * (1 - tx) + vals[1] * tx
    bottom = vals[2] * (1 - tx) + vals[3] * tx
    return float(top * (1 - tz) + bottom * tz)


def in_sheet(x, z):
    return SHEET[0] <= x <= SHEET[1] and SHEET[2] <= z <= SHEET[3]


def in_apron(x, z):
    return abs(x) <= APRON and abs(z - BLOCKOUT_Z) <= APRON


def near_local(x, z):
    return -x, -(z - BLOCKOUT_Z)


def installed_height(x, z):
    """Nearest installed edge height: clamp into the sheet or apron, 2 m inside."""
    cands = []
    for x0, x1, z0, z1, src in ((SHEET[0], SHEET[1], SHEET[2], SHEET[3], "far"),
                                (-APRON, APRON, BLOCKOUT_Z - APRON, BLOCKOUT_Z + APRON, "near")):
        cx, cz = min(max(x, x0 + 2), x1 - 2), min(max(z, z0 + 2), z1 - 2)
        cands.append((math.hypot(x - cx, z - cz), cx, cz, src))
    _, cx, cz, src = min(cands)
    if src == "near":
        return _bilinear(H_NEAR, 520, 4, *near_local(cx, cz))
    return _bilinear(H_FAR, 2600, 20, cx, cz)


def ground_height(x, z):
    if in_sheet(x, z) or in_apron(x, z):
        return installed_height(x, z)
    h = installed_height(x, z)
    if -810 < x < -590 and (z > 700 or z < -3400):
        h = -6.0  # Welfare Island's tips
    if 1080 < z < 1180 and x > -390:
        h = -6.0  # Newtown Creek
    return h


def build_ground():
    n = int(2 * LIMIT / STEP)
    for j in range(n):
        z0, z1 = -LIMIT + j * STEP, -LIMIT + (j + 1) * STEP
        run = None  # merge flat cells along each row
        def flush():
            if run is None:
                return
            mat, x0, x1, h = run
            district = "ground_" + ("w" if x1 <= MANHATTAN_SHORE_X else "e")
            pts = [(x0, h, z0), (x1, h, z0), (x1, h, z1), (x0, h, z1)]
            part(district, mat).face(pts, [(q[0], q[2]) for q in pts], (0, 0, 0, 0), ((x0 + x1) / 2, h - 1, (z0 + z1) / 2))
        for i in range(n):
            x0, x1 = -LIMIT + i * STEP, -LIMIT + (i + 1) * STEP
            cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
            if in_sheet(cx, cz) or in_apron(cx, cz):
                flush(); run = None
                continue
            hs = [ground_height(x, z) for x, z in ((x0, z0), (x1, z0), (x1, z1), (x0, z1))]
            water = max(hs) <= -5.5
            mat = "water_clear" if water else ("soil" if min(hs) < -0.4 else "asphalt")
            if water:
                hs = [-6.0] * 4
            flat = max(hs) - min(hs) < 0.02
            if flat and run is not None and run[0] == mat and abs(run[3] - hs[0]) < 0.02 and abs(run[2] - x0) < 1e-6:
                run = (mat, run[1], x1, run[3])
                continue
            flush(); run = None
            if flat:
                run = (mat, x0, x1, hs[0])
                continue
            district = "ground_" + ("w" if cx < MANHATTAN_SHORE_X else "e")
            pts = [(x0, hs[0], z0), (x1, hs[1], z0), (x1, hs[2], z1), (x0, hs[3], z1)]
            part(district, mat).face(pts, [(q[0], q[2]) for q in pts], (0, 0, 0, 0), (cx, min(hs) - 5, cz))
        flush()


# --- Placement guards ------------------------------------------------------------------

def near_bridge(x, z, pad=45.0):
    # The main span from Manhattan to Queens Plaza, and the elevated approach east.
    for (ax, az), (bx, bz) in (((ANCHOR[0], ANCHOR[1]), BRIDGE_Q), (BRIDGE_Q, (150.0, -350.0)), ((150.0, -350.0), (620.0, -350.0))):
        vx, vz = bx - ax, bz - az
        t = max(0.0, min(1.0, ((x - ax) * vx + (z - az) * vz) / (vx * vx + vz * vz)))
        if math.hypot(x - (ax + vx * t), z - (az + vz * t)) < pad:
            return True
    return False


def occupied(x, z, half=0.0):
    if abs(x) < APRON + half and abs(z - BLOCKOUT_Z) < APRON + half:
        return True
    if ground_height(x, z) < -0.5 or ground_height(x + 25, z) < -0.5 or ground_height(x - 25, z) < -0.5:
        return True
    if near_bridge(x, z):
        return True
    # The installed upper-east-side rows (orison_v2_city_far_shore.gd).
    if -1760 < x < -1240 and -2010 < z < -760:
        return True
    return False


# --- Manhattan --------------------------------------------------------------------------

def manhattan_real(dx_west, dz_south):
    """Real metres west/south of the 59th Street anchorage to the game frame.

    The real East River shore runs south-south-west (about 29 degrees off north);
    the installed river runs due south. Keep each site's distance from its own shore."""
    shore_real = 150.0 - math.tan(GRID_YAW) * dz_south
    from_shore = shore_real + dx_west
    return MANHATTAN_SHORE_X - max(from_shore, 15.0), ANCHOR[1] + dz_south


LANDMARKS = [
    # name, metres west, metres south of the anchorage, footprint w, d, tiers, crown, material
    ("chanin", 1332, 900, 58, 40, [(105, 1.0), (150, .72), (180, .5), (197, .34)], None, "far_brick"),
    ("chrysler_steel", 1306, 960, 62, 58, [(120, 1.0), (152, .78)], "steel", "far_grey"),
    ("new_york_central", 1374, 644, 70, 42, [(95, 1.0), (140, .72), (160, .55)], "pyramid", "far_stone"),
    ("graybar", 1340, 811, 80, 60, [(78, 1.0), (107, .7)], None, "far_brick"),
    ("ritz_tower", -910, -300, 32, 32, [(70, 1.0), (130, .78), (165, .5)], "pyramid", "far_brick"),
    ("sherry_netherland", -1087, -544, 34, 30, [(110, 1.0), (150, .7), (172, .42)], "spire", "far_stone"),
    ("fred_french", 1576, 489, 54, 38, [(90, 1.0), (118, .7), (130, .5)], None, "far_brick"),
    ("beekman_tower", 590, 644, 26, 24, [(80, 1.0), (100, .7)], None, "far_brick"),
    ("paramount", 2234, 300, 60, 50, [(70, 1.0), (100, .7), (119, .45)], "pyramid", "far_terracotta"),
    ("tudor_city_a", 927, 1189, 70, 22, [(84, 1.0)], None, "far_brick"),
    ("tudor_city_b", 960, 1250, 70, 22, [(75, 1.0)], None, "far_brick"),
    ("lefcourt_colonial", 1250, 1050, 48, 40, [(90, 1.0), (115, .65)], None, "far_brick"),
    ("lincoln_hotel", 2050, 520, 58, 40, [(85, 1.0)], None, "far_brick"),
]
# The ritz and sherry rows are north of the anchorage; their "west" values are signed
# as west, so flip the sign convention once here.
LANDMARKS = [(n, abs(w), s, *rest) for n, w, s, *rest in LANDMARKS]


def build_manhattan(rng):
    placed = []
    for name, west, south, w, d, tiers, crown, mat in LANDMARKS:
        x, z = manhattan_real(west, south)
        seed = rng.random()
        color = (seed, KIND_OFFICE / 4, 3.6 / 6, 0.7)
        if crown == "steel":
            top = setback("midtown", mat, "roof_bitumen", x, z, w, d, tiers, YAW_M, color)
            # 1929: the Chrysler's steel climbs past its masonry. Open framing, a derrick.
            corners = [(x + rot(lx, lz, YAW_M)[0], z + rot(lx, lz, YAW_M)[1])
                       for lx, lz in ((-w * .3, -d * .3), (w * .3, -d * .3), (w * .3, d * .3), (-w * .3, d * .3))]
            lattice("midtown", "iron_neutral", corners, top, top + 46, 4.2, 0.7)
            box("midtown", "iron_neutral", "iron_neutral", x, z, 0.8, 0.8, top + 46, 22)
            box("midtown", "iron_neutral", "iron_neutral", x + 6, z, 18, 0.5, top + 64, 0.5, yaw=0.6)
        else:
            setback("midtown", mat, "roof_bitumen", x, z, w, d, tiers, YAW_M, color, crown)
        placed.append((x, z, max(w, d) * 0.75))

    # Waterside Station: the power plant on the river at 38th-40th Street, its stacks
    # the strongest silhouette on the Manhattan shore south of the bridge.
    wx, wz = manhattan_real(-200, 1467)
    wx = MANHATTAN_SHORE_X - 75
    color = (rng.random(), KIND_FACTORY / 4, 6.0 / 6, 0.4)
    for k in range(2):
        box("midtown", "far_brick", "roof_bitumen", wx - 30 * k, wz + 70 * k, 60, 110, 0, 38, YAW_M, color)
        for s in range(3):
            sx, sz = rot(-10 + 10 * s, -40 + 40 * s, YAW_M)
            cylinder("midtown", "brick", "soot", wx - 30 * k + sx, wz + 70 * k + sz, 3.2, 38, 52, 10, (0.5, .75, 0, 0), taper=0.8)
            STACKS.append((wx - 30 * k + sx, 90.0, wz + 70 * k + sz, 2.6))
    placed.append((wx, wz, 120))

    # Ordinary blocks: an avenue grid of 240 x 60 m blocks rotated with the island.
    av, st = 240.0, 80.0
    origin = (MANHATTAN_SHORE_X - 60, ANCHOR[1])
    park = lambda x, z: (-3570 < x < -2770) and z < ANCHOR[1] + 20  # Central Park, open ground
    for a in range(-2, 24):
        for s in range(-75, 75):
            lx, lz = -a * av - av / 2, s * st
            bx, bz = rot(lx, lz, YAW_M)
            x, z = origin[0] + bx, origin[1] + bz
            if x > MANHATTAN_SHORE_X - 20 or x < -LIMIT + 40 or abs(z) > LIMIT - 40 or park(x, z):
                continue
            if occupied(x, z):
                continue
            core = math.hypot(x + 2250, z + 250)  # the midtown cluster
            lots = rng.randint(3, 6)
            for k in range(lots):
                lw = (av - 30) / lots
                ox, oz = rot(-av / 2 + 15 + lw * (k + .5), 0, YAW_M)
                cx, cz = x + ox, z + oz
                if any(math.hypot(cx - px, cz - pz) < pr for px, pz, pr in placed):
                    continue
                if core < 900 and rng.random() < 0.55:
                    h = rng.uniform(40, 125) * (1 - core / 1400)
                    h = max(h, 30)
                    kind = KIND_OFFICE
                elif rng.random() < 0.12:
                    h = rng.uniform(30, 48)  # an avenue apartment house
                    kind = KIND_TENEMENT
                else:
                    h = rng.uniform(14, 24)  # walk-ups
                    kind = KIND_TENEMENT
                mat = rng.choice(["far_brick", "far_brick", "far_grey", "far_stone"] if kind == KIND_OFFICE else ["far_brick", "far_brick", "far_grey"])
                color = (rng.random(), kind / 4, (3.6 if kind == KIND_OFFICE else 3.2) / 6, rng.uniform(.3, .8))
                depth = st - 22
                if h > 60:
                    setback("midtown", mat, "roof_bitumen", cx, cz, lw - 2, depth, [(h * .65, 1), (h * .88, .74), (h, .5)], YAW_M, color)
                else:
                    box("midtown", mat, "roof_bitumen", cx, cz, lw - 2, depth, 0, h, YAW_M, color)
                    if rng.random() < 0.35:
                        tx, tz = rot(rng.uniform(-lw / 4, lw / 4), rng.uniform(-8, 8), YAW_M)
                        cylinder("midtown", "tank_staves", "tank_staves", cx + tx, cz + tz, 2.6, h + 3, 4.5, 8, (0, .75, 0, 0))


# --- Welfare Island ---------------------------------------------------------------------

def build_welfare(rng):
    stone = (0.31, KIND_TENEMENT / 4, 4.0 / 6, 0.25)
    x = -700.0
    # Penitentiary (south of the bridge), workhouse, city hospital, smallpox hospital ruin,
    # the octagon asylum to the north and the lighthouse on the north tip.
    box("welfare", "far_stone", "city_slate", x, -640, 38, 180, -1, 18, 0, stone)
    box("welfare", "far_stone", "city_slate", x, -640, 90, 22, -1, 20, 0, stone)
    box("welfare", "far_stone", "city_slate", x + 10, -1330, 34, 140, -1, 16, 0, stone)
    box("welfare", "far_stone", "city_slate", x - 5, -230, 40, 120, -1, 17, 0, stone)
    box("welfare", "far_stone", "city_slate", x + 15, -150, 70, 18, -1, 15, 0, stone)
    box("welfare", "far_stone", "roof_bitumen", x, 540, 26, 50, -1, 13, 0, (0.7, KIND_BLANK / 4, 4.0 / 6, 0))
    cylinder("welfare", "far_stone", "city_slate", x, -2250, 16, -1, 30, 8, stone)
    box("welfare", "far_stone", "city_slate", x, -2330, 26, 120, -1, 16, 0, stone)
    box("welfare", "far_stone", "city_slate", x, -2170, 26, 120, -1, 16, 0, stone)
    cylinder("welfare", "limestone", "city_slate", x, -3370, 2.4, -1, 15, 8, (0, .75, 0, 0), taper=0.75)


# --- Queens -----------------------------------------------------------------------------

def gas_holder(district, x, z, r, h, color):
    cylinder(district, "iron_neutral", "galvanized_roof", x, z, r, 0, h * 0.82, 20, color)
    ring = [(x + (r + 2) * math.cos(2 * math.pi * i / 10), z + (r + 2) * math.sin(2 * math.pi * i / 10)) for i in range(10)]
    for cx, cz in ring:
        box(district, "iron_neutral", "iron_neutral", cx, cz, 0.9, 0.9, 0, h, color=color)
    for y in (h * .33, h * .66, h):
        for i in range(10):
            a, b = ring[i], ring[(i + 1) % 10]
            yaw = -math.atan2(b[1] - a[1], b[0] - a[0])
            box(district, "iron_neutral", "iron_neutral", (a[0] + b[0]) / 2, (a[1] + b[1]) / 2, math.dist(a, b), 0.6, y - .6, .6, yaw, color)


def factory(district, rng, x, z, yaw):
    w, d = rng.uniform(40, 110), rng.uniform(30, 70)
    h = rng.choice([9, 12, 16, 20, 26])
    mat = rng.choice(["far_brick", "far_brick", "far_grey"])
    color = (rng.random(), KIND_FACTORY / 4, 4.4 / 6, rng.uniform(.1, .5))
    corners = box(district, mat, "roof_bitumen", x, z, w, d, 0, h, yaw, color, top=h > 14)
    if h <= 14:
        prism_roof(district, "galvanized_roof", corners, h, 3.5, color)
    if rng.random() < 0.35:
        sx, sz = rot(w * 0.3, 0, yaw)
        tall = rng.uniform(18, 34)
        cylinder(district, "brick", "soot", x + sx, z + sz, 1.8, h, tall, 8, (0, .75, 0, 0), taper=0.75)
        if rng.random() < 0.25:
            STACKS.append((x + sx, h + tall, z + sz, 1.35))
    elif rng.random() < 0.3:
        cylinder(district, "tank_staves", "tank_staves", x, z, 3, h + 4, 5, 8, (0, .75, 0, 0))
    return max(w, d)


def row_houses(district, rng, x, z, yaw, length, height):
    color = (rng.random(), KIND_TENEMENT / 4, 3.1 / 6, rng.uniform(.4, .9))
    corners = box(district, rng.choice(["far_brick", "far_grey"]), "roof_bitumen", x, z, length, 12, 0, height, yaw, color)
    return corners


def build_queens(rng):
    # Long Island Rail Road powerhouse, Hunters Point: four stacks on the waterfront.
    px, pz = -330.0, 600.0
    color = (0.42, KIND_FACTORY / 4, 6.0 / 6, 0.5)
    box("queens_south", "far_brick", "roof_bitumen", px, pz, 60, 120, 0, 34, 0, color)
    for s in range(4):
        cylinder("queens_south", "brick", "soot", px, pz - 45 + 30 * s, 3.4, 34, 50, 12, (0, .75, 0, 0), taper=0.82)
        STACKS.append((px, 84.0, pz - 45 + 30 * s, 2.8))

    # Greenpoint gas holders across Newtown Creek, and the creek's oil tanks.
    gas_holder("greenpoint", 260, 1460, 32, 62, (0, .75, 0, 0))
    gas_holder("greenpoint", 360, 1560, 28, 54, (0, .75, 0, 0))
    gas_holder("queens_north", -170, -2650, 30, 58, (0, .75, 0, 0))  # Astoria works
    for k in range(22):
        tx = rng.uniform(700, 2600)
        tz = rng.choice([rng.uniform(1000, 1070), rng.uniform(1190, 1300)])
        if not occupied(tx, tz, 10):
            cylinder("greenpoint", "iron_neutral", "iron_neutral", tx, tz, rng.uniform(9, 16), 0, rng.uniform(8, 14), 14, (0, .75, 0, 0))

    # Sunnyside Yard: east of Queens Plaza, between Thomson Avenue and Skillman.
    yard_z0, yard_z1, yard_x0, yard_x1 = -760.0, -420.0, 540.0, 2600.0
    cars = part("sunnyside", "iron_neutral")
    for t in range(18):
        z = yard_z0 + 18 + t * 17.5
        x = yard_x0 + rng.uniform(0, 300)
        while x < yard_x1 - 30:
            n = rng.randint(4, 12)
            length = n * 24.0
            if rng.random() < 0.7 and x + length < yard_x1:
                box("sunnyside", "car_paint", "roof_bitumen", x + length / 2, z, length, 3.1, 0.9, 3.4, 0, (0, .75, 0, 0))
            x += length + rng.uniform(20, 120)
    # Catenary portals across the yard every 60 m.
    x = yard_x0 + 20
    while x < yard_x1:
        for zz in (yard_z0 + 4, yard_z1 - 4):
            box("sunnyside", "iron_neutral", "iron_neutral", x, zz, 0.7, 0.7, 0, 11)
        box("sunnyside", "iron_neutral", "iron_neutral", x, (yard_z0 + yard_z1) / 2, 0.6, yard_z1 - yard_z0, 10.4, 0.6)
        x += 60.0
    box("sunnyside", "far_brick", "galvanized_roof", 1500, yard_z1 + 30, 380, 36, 0, 14, 0, (0.66, KIND_FACTORY / 4, 7.0 / 6, 0.3))

    # Industrial and residential fill outside the apron, avoiding the yard.
    for district, x0, x1, z0, z1, mix in (
            ("queens_north", -380, 3600, -3700, -560, 0.7),
            ("queens_east", 520, 3600, -400, 1060, 0.35),
            ("queens_south", -380, 520, 520, 1060, 0.8),
            ("greenpoint", -380, 3600, 1200, 3700, 0.3)):
        z = z0
        while z < z1:
            x = x0
            while x < x1:
                jx, jz = x + rng.uniform(-8, 8), z + rng.uniform(-8, 8)
                in_yard = yard_x0 - 20 < jx < yard_x1 + 20 and yard_z0 - 60 < jz < yard_z1 + 60
                if not in_yard and not occupied(jx, jz, 40) and rng.random() < 0.82:
                    if rng.random() < mix:
                        factory(district, rng, jx, jz, rng.choice([0.0, 0.0, 0.08]))
                    else:
                        for r in range(3):
                            row_houses(district, rng, jx, jz - 30 + 30 * r, 0.0, rng.uniform(50, 90),
                                       rng.choice([9, 11, 13, 13, 18, 22]))
                x += rng.uniform(95, 140)
            z += rng.uniform(95, 130)
    # Greenpoint's church spire as the one tall mark south of the creek.
    cylinder("greenpoint", "far_stone", "city_slate", 120, 1900, 7, 0, 30, 8, (0.2, KIND_BLANK / 4, 1, 0))
    cylinder("greenpoint", "city_slate", "city_slate", 120, 1900, 7, 30, 38, 8, (0, .75, 0, 0), top=False, taper=0.02)


# --- Export -----------------------------------------------------------------------------

def export():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    materials = {}
    for (district, mat), p in sorted(PARTS.items()):
        mesh = bpy.data.meshes.new(f"{district}__{mat}")
        bmesh.ops.remove_doubles(p.bm, verts=p.bm.verts, dist=0.001)
        p.bm.to_mesh(mesh)
        p.bm.free()
        if mat not in materials:
            materials[mat] = bpy.data.materials.new(mat)
        mesh.materials.append(materials[mat])
        obj = bpy.data.objects.new(f"{district}__{mat}", mesh)
        bpy.context.scene.collection.objects.link(obj)
    tris = sum(len(o.data.polygons) * 2 for o in bpy.context.scene.objects)
    print("FAR_DISTRICTS objects", len(bpy.context.scene.objects), "approx triangles", tris)
    bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", export_yup=True, export_apply=True,
                              export_vertex_color="ACTIVE", export_normals=True, export_texcoords=True,
                              export_materials="PLACEHOLDER")
    print("FAR_DISTRICTS wrote", OUT)


def write_data():
    import json
    data = {"schema": 1, "frame": "ORISON_V2_BUILDING_FRAME",
            "stacks": [[round(v, 2) for v in st] for st in STACKS]}
    path = ROOT + "/game/data/orison_v2/exterior/city_far_districts.json"
    with open(path, "w", encoding="utf8", newline="\n") as handle:
        handle.write(json.dumps(data, indent=1) + "\n")
    print("FAR_DISTRICTS stacks", len(STACKS))


def main():
    rng = random.Random(19291029)
    build_ground()
    build_manhattan(rng)
    build_welfare(rng)
    build_queens(rng)
    export()
    write_data()


main()
