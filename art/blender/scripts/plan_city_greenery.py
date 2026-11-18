"""Placement for the city greenery (plain Python; see build_city_greenery.py).

    python art/blender/scripts/build_city_greenery.py --place

Near city: street trees along the drawn kerbs found by the greenery survey. A tree
stands where the pavement is wide enough, the kerb runs straight (no corners or
crossings), no collision rises within its clear radius, no small fixture (post,
hydrant, box, sign) or lamp flame is near, and the Orison's door is well clear.

Mid-ground: street trees along build_city_midground.py's kerbs between its own
furniture, ailanthus, privet and weeds in some back yards, and the same in the vacant
lots behind its board fences. Nothing is planted in a lot, a street or a reserved datum.
"""
import gzip
import json
import math
import os
import random
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import build_city_greenery as G  # noqa: E402

CELL = 0.25
LIMIT = 220.0
SPACING_M = 8.5          # street trees, centre to centre
SKIP_SHARE = 0.22        # gaps in a row: missing trees, as on any real street
LAMP_CLEAR_M = 4.6       # crowns keep off the lamp heads
DOOR = (0.0, 1.5)        # the Orison's front door (the player's start)
DOOR_CLEAR_M = 9.0
VIEW_REACH_M = 330.0     # beyond this the mist and the blocks in front hide them
WALKABLE_M = 215.0       # trunk collision only where the player can reach
ROAD_OWNERS = ("CityShells/ContinuousStreetBlock", "StreetAndBodega", "Midground")


def _read(name):
    path = os.path.join(G.SURVEY, name)
    if os.path.exists(path + ".gz"):
        with gzip.open(path + ".gz", "rb") as f:
            return f.read()
    with open(path, "rb") as f:
        return f.read()


def raster(tris, n):
    """Upward triangles to a height raster (NaN where none), max height wins."""
    out = np.full((n, n), np.nan, np.float32)
    for t in tris:
        xs, ys, zs = t[0::3], t[1::3], t[2::3]
        i0 = int(math.floor((min(xs) + LIMIT) / CELL)); i1 = int(math.ceil((max(xs) + LIMIT) / CELL))
        j0 = int(math.floor((min(zs) + LIMIT) / CELL)); j1 = int(math.ceil((max(zs) + LIMIT) / CELL))
        i0, j0 = max(i0, 0), max(j0, 0)
        i1, j1 = min(i1, n - 1), min(j1, n - 1)
        if i1 < i0 or j1 < j0:
            continue
        jj, ii = np.mgrid[j0:j1 + 1, i0:i1 + 1]
        px = -LIMIT + (ii + .5) * CELL
        pz = -LIMIT + (jj + .5) * CELL
        (ax, bx, cx), (az, bz, cz) = xs, zs
        d = (bz - cz) * (ax - cx) + (cx - bx) * (az - cz)
        if abs(d) < 1e-9:
            continue
        w0 = ((bz - cz) * (px - cx) + (cx - bx) * (pz - cz)) / d
        w1 = ((cz - az) * (px - cx) + (ax - cx) * (pz - cz)) / d
        w2 = 1 - w0 - w1
        inside = (w0 >= -1e-4) & (w1 >= -1e-4) & (w2 >= -1e-4)
        h = (w0 * ys[0] + w1 * ys[1] + w2 * ys[2]).astype(np.float32)
        block = out[j0:j1 + 1, i0:i1 + 1]
        upd = inside & ~(block >= h)
        block[upd] = h[upd]
    return out


def dilate(mask, steps):
    m = mask.copy()
    for _ in range(steps):
        g = m.copy()
        g[1:] |= m[:-1]; g[:-1] |= m[1:]; g[:, 1:] |= m[:, :-1]; g[:, :-1] |= m[:, 1:]
        m = g
    return m


def near_city(rng):
    surfaces = json.loads(_read("surfaces.json"))
    meta = json.loads(_read("survey.json"))
    fixtures = json.loads(_read("fixtures.json"))
    n = int(round(2 * LIMIT / CELL))
    walk = raster([t for s in surfaces if s["class"] == "walk" for t in s["tris"]], n)
    kerb = raster([t for s in surfaces if s["class"] == "kerb" for t in s["tris"]], n)
    walk_m = ~np.isnan(walk)
    # The first-hit grid (1 m): anything standing proud of the pavement is an obstacle.
    gn = meta["n"]
    heights = np.frombuffer(_read("heights.f32"), "<f4").reshape(gn, gn)
    step = meta["step"]
    glim = meta["limit"]
    # The kerb is the pavement's edge where the ground beside it drops to the road
    # (kerb tops are named differently from street to street, so read the step, not
    # the name). The building side rises or meets a wall instead.
    # Only the streets' own carriageways count as road here: the blockout's ground
    # plane is also asphalt, and runs up to the far side of many pavements.
    road = raster([t for s in surfaces if s["class"] == "road" and s["path"].startswith(ROAD_OWNERS)
                   for t in s["tris"]], n)
    road_m = ~np.isnan(road) & ~walk_m
    edge = walk_m & ~(np.roll(walk_m, 1, 0) & np.roll(walk_m, -1, 0) & np.roll(walk_m, 1, 1) & np.roll(walk_m, -1, 1))
    kerb_m = (~np.isnan(kerb)) | (edge & dilate(road_m, 3))
    small = np.array([f[:5] for f in fixtures["small_colliders"]], float).reshape(-1, 5)
    lamps = np.array([f[:3] for f in fixtures["lamp_lights"]], float).reshape(-1, 3)
    # Pit centres sit 0.6-0.9 m in from the kerb face.
    near_kerb = dilate(kerb_m, 3) & ~dilate(kerb_m, 2) & walk_m & ~kerb_m
    jj, ii = np.nonzero(near_kerb)
    order = list(range(len(jj)))
    rng.shuffle(order)
    kj, ki = np.nonzero(kerb_m)
    kx = -LIMIT + (ki + .5) * CELL
    kz = -LIMIT + (kj + .5) * CELL
    placed = []
    rejected = {"narrow": 0, "corner": 0, "obstacle": 0, "fixture": 0, "lamp": 0, "door": 0, "spacing": 0, "skip": 0}
    for o in order:
        j, i = int(jj[o]), int(ii[o])
        x = -LIMIT + (i + .5) * CELL
        z = -LIMIT + (j + .5) * CELL
        if any(math.hypot(x - px, z - pz) < SPACING_M for px, pz, *_ in placed):
            rejected["spacing"] += 1
            continue
        if math.hypot(x - DOOR[0], z - DOOR[1]) < DOOR_CLEAR_M:
            rejected["door"] += 1
            continue
        near = (np.abs(kx - x) < 6) & (np.abs(kz - z) < 6)
        px, pz = kx[near], kz[near]
        close = np.hypot(px - x, pz - z) < 6
        px, pz = px[close], pz[close]
        if len(px) < 20:
            rejected["corner"] += 1
            continue
        # A straight kerb: its cells within 6 m lie on one line.
        cov = np.cov(np.vstack((px, pz)))
        evals, evecs = np.linalg.eigh(cov)
        if math.sqrt(max(evals[0], 0)) > 0.3:
            rejected["corner"] += 1
            continue
        tangent = evecs[:, 1]
        normal = np.array([-tangent[1], tangent[0]])
        # Toward the building line: away from the kerb's own mean.
        if np.dot(normal, np.array([x - px.mean(), z - pz.mean()])) < 0:
            normal = -normal
        ok = True
        for d in (1.0, 1.5):
            qx, qz = x + normal[0] * d, z + normal[1] * d
            qi, qj = int((qx + LIMIT) / CELL), int((qz + LIMIT) / CELL)
            if not (0 <= qi < n and 0 <= qj < n and walk_m[qj, qi]):
                ok = False
        if not ok:
            rejected["narrow"] += 1
            continue
        y = float(walk[j, i])
        # A pavement under 2.6 m takes the smaller pit and guard.
        qi, qj = int((x + normal[0] * 2.5 + LIMIT) / CELL), int((z + normal[1] * 2.5 + LIMIT) / CELL)
        pit_scale = 1.0 if (0 <= qi < n and 0 <= qj < n and walk_m[qj, qi]) else 0.8
        # Nothing standing proud of the pavement within the clear radius (1 m grid).
        gx = -glim + np.arange(gn) * step
        sel_i = np.nonzero(np.abs(gx - x) <= G.TREE_CLEARANCE_M)[0]
        sel_j = np.nonzero(np.abs(gx - z) <= G.TREE_CLEARANCE_M)[0]
        patch = heights[np.ix_(sel_j, sel_i)]
        within = np.hypot(*np.meshgrid(gx[sel_i] - x, gx[sel_j] - z)) <= G.TREE_CLEARANCE_M
        if np.any(np.isnan(patch[within])) or np.any(patch[within] > y + 0.35):
            rejected["obstacle"] += 1
            continue
        if len(small) and np.any(np.hypot(small[:, 0] - x, small[:, 2] - z) < small[:, 3] + G.TREE_CLEARANCE_M):
            rejected["fixture"] += 1
            continue
        if len(lamps) and np.any(np.hypot(lamps[:, 0] - x, lamps[:, 2] - z) < LAMP_CLEAR_M):
            rejected["lamp"] += 1
            continue
        if rng.random() < SKIP_SHARE:
            rejected["skip"] += 1
            placed.append((x, z, None, None, None))  # keeps the gap: no neighbour fills it
            continue
        placed.append((x, z, y, math.atan2(tangent[0], tangent[1]), pit_scale))
    trees = [(x, y, z, yaw, s) for x, z, y, yaw, s in placed if y is not None]
    return trees, rejected


def midground(rng):
    import build_city_midground as M
    layout = M.Layout(M.Occupancy()).run()
    data = json.load(open(G.ROOT + "/game/data/orison_v2/exterior/city_midground.json", encoding="utf8"))
    furniture = []
    for group in data["furniture"]:
        for item in group["items"]:
            furniture.append((item[0], item[2], group["kind"]))
    lamps = [(x, z) for x, z, k in furniture if k == "lamp"]
    others = [(x, z) for x, z, k in furniture if k != "lamp"]
    out = {"street": [], "ailanthus": [], "shrub": [], "weeds": []}

    def in_band(x, z, pad):
        for axis, c, a, b in layout.streets:
            r = layout._rect(axis, c, a, b, M.HALF)
            if r[0] - pad <= x <= r[2] + pad and r[1] - pad <= z <= r[3] + pad:
                yield (axis, c)

    def in_lot(x, z, pad=0.6):
        for lot in layout.lots:
            x0, z0, x1, z1 = lot["rect"]
            if x0 - pad <= x <= x1 + pad and z0 - pad <= z <= z1 + pad:
                return True
        return False

    def clear_of(x, z, pts, r):
        return all(math.hypot(x - px, z - pz) >= r for px, pz in pts)

    def free(x, z, r=1.0):
        return (not M.reserved(x - r, z - r, x + r, z + r) and not M.in_near_city(x - r, z - r, x + r, z + r)
                and layout.occ.fraction_free(x - r, z - r, x + r, z + r) >= 0.99 and M.land(x, z))

    # Kerb trees between the mid-ground's own lamps and furniture.
    for axis, c, a, b in layout.streets:
        for side in (-1, 1):
            kerb = c + side * (M.ROAD / 2 + 0.85)
            t = a + 7 + rng.uniform(0, 4)
            while t < b - 7:
                x, z = (t, kerb) if axis == "x" else (kerb, t)
                t += rng.uniform(8.5, 11)
                if math.hypot(x, z) > VIEW_REACH_M or rng.random() < SKIP_SHARE:
                    continue
                crossing = [s for s in in_band(x, z, 6.0) if s != (axis, c)]
                if crossing or not clear_of(x, z, lamps, LAMP_CLEAR_M) or not clear_of(x, z, others, 1.8):
                    continue
                if not free(x, z, 0.7):
                    continue
                out["street"].append((x, M.ground(x, z) + 0.17, z, 0.0 if axis == "x" else math.pi / 2, 1.0))

    def scatter(x0, z0, x1, z1, kind, per_m2):
        area = max(x1 - x0, 0) * max(z1 - z0, 0)
        for _ in range(int(area * per_m2 + rng.random())):
            x, z = rng.uniform(x0, x1), rng.uniform(z0, z1)
            if math.hypot(x, z) > VIEW_REACH_M or in_lot(x, z) or any(True for _ in in_band(x, z, 1.0)):
                continue
            if not free(x, z, 0.8 if kind != "ailanthus" else 1.4):
                continue
            out[kind].append((x, M.ground(x, z), z, rng.uniform(0, math.tau)))

    # Back yards: the strip behind each walk-up, where the ailanthus seeds itself.
    for lot in layout.lots:
        if lot["kind"] != "walkup" or rng.random() > 0.3:
            continue
        x0, z0, x1, z1 = lot["rect"]
        side = lot["side"]
        if lot["axis"] == "x":
            rear = z1 if side > 0 else z0
            rect = (x0, rear + .8, x1, rear + 7) if side > 0 else (x0, rear - 7, x1, rear - .8)
        else:
            rear = x1 if side > 0 else x0
            rect = (rear + .8, z0, rear + 7, z1) if side > 0 else (rear - 7, z0, rear - .8, z1)
        scatter(*rect, "ailanthus", 1 / 70)
        scatter(*rect, "shrub", 1 / 60)
        scatter(*rect, "weeds", 1 / 25)

    # Vacant lots: the gaps the mid-ground closes with board fences.
    for axis, c, a, b in layout.streets:
        for side in (-1, 1):
            line = c + side * M.HALF + side * 0.15
            covered = []
            for lot in layout.lots:
                lx0, lz0, lx1, lz1 = lot["rect"]
                if axis == "x" and lz0 - .5 <= line <= lz1 + .5:
                    covered.append((lx0, lx1))
                if axis == "z" and lx0 - .5 <= line <= lx1 + .5:
                    covered.append((lz0, lz1))
            covered.sort()
            t, gaps = a, []
            for u0, u1 in covered:
                if u0 - t > 2.0:
                    gaps.append((t, u0))
                t = max(t, u1)
            if b - t > 2.0:
                gaps.append((t, b))
            for g0, g1 in gaps:
                d0, d1 = sorted((line + side * .6, line + side * 18))
                rect = (g0, d0, g1, d1) if axis == "x" else (d0, g0, d1, g1)
                scatter(*rect, "weeds", 1 / 30)
                scatter(*rect, "shrub", 1 / 140)
                scatter(*rect, "ailanthus", 1 / 450)
    return out


def near_open_ground(rng):
    """The near city's open lots: weeds, privet and a few ailanthus on the graded soil,
    weeds along the walls of the asphalt courts. Never on a street or pavement, never
    near a post, lamp, reserved datum or the Orison."""
    import build_city_midground as M
    meta = json.loads(_read("survey.json"))
    fixtures = json.loads(_read("fixtures.json"))
    gn, step, glim = meta["n"], meta["step"], meta["limit"]
    heights = np.frombuffer(_read("heights.f32"), "<f4").reshape(gn, gn)
    owners = np.frombuffer(_read("owners.i32"), "<i4").reshape(gn, gn)
    keys = meta["owners"]
    soil = np.isin(owners, [i for i, k in enumerate(keys) if "GradeCut_soil" in k])
    court = np.isin(owners, [i for i, k in enumerate(keys) if "Court_asphalt" in k])
    apron = np.isin(owners, [i for i, k in enumerate(keys) if "DistantApron" in k])
    # Streets and pavements, drawn without collision, from the surface survey.
    surfaces = json.loads(_read("surfaces.json"))
    n = int(round(2 * LIMIT / CELL))
    drawn = ~np.isnan(raster([t for s in surfaces if s["class"] in ("walk", "kerb") or
                              (s["class"] == "road" and s["path"].startswith(ROAD_OWNERS)) for t in s["tris"]], n))
    street = np.zeros((gn, gn), bool)
    jj, ii = np.nonzero(drawn)
    street[np.clip(np.rint((-LIMIT + (jj + .5) * CELL + glim) / step).astype(int), 0, gn - 1),
           np.clip(np.rint((-LIMIT + (ii + .5) * CELL + glim) / step).astype(int), 0, gn - 1)] = True
    street = dilate(street, 3)
    open_ground = (soil | court | apron) & ~street
    blocked = ~open_ground
    # Distance in metres to anything that is not open ground, out to 4 m.
    clear = np.zeros((gn, gn), np.int8)
    reach = blocked.copy()
    for d in range(1, 5):
        reach = dilate(reach, 1)
        clear[~reach & (clear == 0)] = 0
        clear[reach & (clear == 0) & ~blocked] = d
    clear[~reach] = 5
    small = np.array([f[:4] for f in fixtures["small_colliders"]], float).reshape(-1, 4)
    lamps = np.array([f[:3] for f in fixtures["lamp_lights"]], float).reshape(-1, 3)
    out = {"ailanthus": [], "shrub": [], "weeds": []}
    trees = []
    cells = list(zip(*np.nonzero((soil | court) & ~street)))
    rng.shuffle(cells)
    for j, i in cells:
        x, z = -glim + i * step + rng.uniform(-.45, .45), -glim + j * step + rng.uniform(-.45, .45)
        if math.hypot(x, z) > WALKABLE_M - 5 or math.hypot(x - DOOR[0], z - DOOR[1]) < 25.0:
            continue
        if M.reserved(x - 1.5, z - 1.5, x + 1.5, z + 1.5):
            continue
        if len(small) and np.any(np.hypot(small[:, 0] - x, small[:, 2] - z) < small[:, 3] + 1.0):
            continue
        if len(lamps) and np.any(np.hypot(lamps[:, 0] - x, lamps[:, 2] - z) < 3.0):
            continue
        y = float(heights[j, i])
        room = int(clear[j, i])
        if soil[j, i]:
            roll = rng.random()
            if room >= 4 and roll < 1 / 120 and all(math.hypot(x - a, z - b) > 9 for a, b in trees):
                trees.append((x, z))
                out["ailanthus"].append((x, y, z, rng.uniform(0, math.tau)))
            elif room >= 2 and roll < 1 / 45:
                out["shrub"].append((x, y, z, rng.uniform(0, math.tau)))
            elif room >= 1 and roll < (1 / 6 if room <= 2 else 1 / 14):
                out["weeds"].append((x, y, z, rng.uniform(0, math.tau)))
        elif room == 1 and rng.random() < 1 / 8:
            # Weeds in the cracks at the foot of a court's walls.
            out["weeds"].append((x, y, z, rng.uniform(0, math.tau)))
    return out


def main():
    rng = random.Random(G.SEED)
    near, rejected = near_city(rng)
    mid = midground(rng)
    lots = near_open_ground(rng)
    for kind in lots:
        mid[kind] += lots[kind]
    kinds = {k: [] for k in G.STOCK}
    colliders = []
    for x, y, z, yaw, pit_scale in near + mid["street"]:
        variant = "plane_a" if rng.random() < .5 else "plane_b"
        scale = round(rng.uniform(.85, 1.12), 3)
        spin = rng.uniform(0, math.tau)
        kinds[variant].append([round(x, 3), round(y, 3), round(z, 3), round(spin, 4), scale])
        kinds["pit"].append([round(x, 3), round(y, 3), round(z, 3), round(yaw, 4), pit_scale])
        if rng.random() < .35:
            kinds["weeds"].append([round(x + rng.uniform(-.35, .35), 3), round(y + .012, 3),
                                   round(z + rng.uniform(-.35, .35), 3), round(rng.uniform(0, math.tau), 4), .7])
        if math.hypot(x, z) < WALKABLE_M:
            colliders.append([round(x, 3), round(y, 3), round(z, 3), round(0.58 * pit_scale, 3), 1.2, round(yaw, 4)])
    for kind in ("ailanthus", "shrub", "weeds"):
        for x, y, z, yaw in mid[kind]:
            scale = rng.uniform(.8, 1.2) if kind != "weeds" else rng.uniform(.7, 1.4)
            kinds[kind].append([round(x, 3), round(y, 3), round(z, 3), round(yaw, 4), round(scale, 3)])
            if kind == "ailanthus" and math.hypot(x, z) < WALKABLE_M:
                colliders.append([round(x, 3), round(y, 3), round(z, 3), 0.3, 3.0, 0.0])
    table = {
        "schema": "orison.v2.city-greenery.v1",
        "frame": "WORLD",
        "stock": "res://assets/props/city_greenery.glb",
        "stock_names": {k: list(v) for k, v in G.STOCK.items()},
        "tile_m": 60.0,
        "near_end_m": 75.0,
        "far_begin_m": 65.0,
        "fade_m": 10.0,
        "small_end_m": 45.0,
        "kinds": kinds,
        # [x, y, z, radius, height, yaw]: a cylinder for a trunk, a box for a pit and its guard.
        "colliders": colliders,
    }
    os.makedirs(os.path.dirname(G.DATA), exist_ok=True)
    with open(G.DATA, "w", encoding="utf8", newline="\n") as f:
        json.dump(table, f, separators=(",", ":"))
        f.write("\n")
    print("NEAR CITY OPEN GROUND", json.dumps({k: len(v) for k, v in lots.items()}))
    print("CITY GREENERY PLACEMENT", json.dumps({"counts": {k: len(v) for k, v in kinds.items()}, "colliders": len(colliders),
                                                  "near_city_trees": len(near), "near_city_rejections": rejected}))


if __name__ == "__main__":
    main()
