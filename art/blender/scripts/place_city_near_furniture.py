"""Place street furniture along the near city's kerbs (Lily's ruling city_complete_next_20261117).

Reads art/blender/data/city_near_furniture/kerbs.json (survey_city_near_kerbs.py) and writes candidates.json:
hydrants, mailboxes, call boxes and ash cans by the mid-ground's own rules (build_city_midground.py, kerbside), and
telegraph poles along the side streets. Everything is a candidate until the running-world probe accepts it.

Kept clear (Codex, 2026-11-17): the street region in front of the Orison, bodega and arcade (REGION_STREET plus a
margin), the tram supports, and every run's ends, where the curb ramps and crossings are.

    python art/blender/scripts/place_city_near_furniture.py
"""
import json
import math
import random
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
DATA = ROOT / "art" / "blender" / "data" / "city_near_furniture"
TRAMS = ROOT / "game" / "data" / "orison_v2" / "exterior" / "street_trams.json"
REGIONS = ROOT / "game" / "data" / "orison_v2" / "exterior" / "regions.json"

END_CLEAR_M = 3.0       # curb ramps and crossings stay open at every run end
CORNER_AT_M = 3.6       # the corner item, just past the ramp
POLE_PITCH_M = 36.0     # telegraph poles along a side street
POLE_INSET_M = -0.25    # poles stand nearer the curb than the furniture line
MARGIN_M = 3.5          # around the street region and tram supports
SEED = 1929
# Lily's rulings midground_sign_mapping and near_street_names_20261117: the avenue in front of the Orison is 41st Ave
# (old name disputed, so the small line is blank); its cross streets west to east are 24th St (William St), 25th St,
# 26th St and 27th St. Centre x of each crossing street and its half-width, from the installed streets.
AVENUE = ("41ST AVE", "")
AVENUE_Z, AVENUE_HALF = 9.5275, 4.572
CROSSINGS = [(-142.87, 4.6, ("24TH ST", "William St")), (-69.6, 4.6, ("25TH ST", "")),
             (69.3, 4.1, ("26TH ST", "")), (142.87, 4.6, ("27TH ST", ""))]
# The post stands on the corner's north-east walk, back from the corner along the avenue so the curb ramp stays open.
SIGN_BACK_M = 1.6
# The el runs up the first cross street east of the station (ruling el_viaduct_route, x 142.9): no telegraph line
# under its deck, where the poles would read as more el columns and the wires thread its girders.
EL_STREET_X = (134.0, 152.0)


def merge(runs):
    """Join collinear pieces of one kerb (same outward direction, ends within 1.5 m, on the same line)."""
    runs = [dict(r, points=list(r["points"])) for r in runs]
    merged = True
    while merged:
        merged = False
        for a in runs:
            for b in runs:
                if a is b or a["out"] != b["out"]:
                    continue
                if math.dist(a["points"][-1][::2], b["points"][0][::2]) < 1.5:
                    a["points"].extend(b["points"])
                    runs.remove(b)
                    merged = True
                    break
            if merged:
                break
    return runs


def length(points):
    return sum(math.dist(points[i][::2], points[i + 1][::2]) for i in range(len(points) - 1))


def at_distance(points, d):
    """The point d metres along a polyline, and its index."""
    run = 0.0
    for i in range(len(points) - 1):
        step = math.dist(points[i][::2], points[i + 1][::2])
        if run + step >= d:
            t = (d - run) / step if step > 0 else 0.0
            p = [points[i][k] + (points[i + 1][k] - points[i][k]) * t for k in range(3)]
            return p
        run += step
    return list(points[-1])


def main():
    kerbs = json.loads((DATA / "kerbs.json").read_text())
    trams = json.loads(TRAMS.read_text())
    regions = json.loads(REGIONS.read_text())
    blocked = []
    for r in regions["regions"]:
        xs = [p[0] for p in r["boundary"]]
        zs = [p[1] for p in r["boundary"]]
        blocked.append((min(xs) - MARGIN_M, min(zs) - MARGIN_M, max(xs) + MARGIN_M, max(zs) + MARGIN_M))
    supports = [float(s["x"]) for s in trams["supports"]]
    near_kerb_z = float(trams["near_kerb_z"])
    far_kerb_z = float(trams["far_kerb_z"])

    def clear(x, z):
        if any(x0 <= x <= x1 and z0 <= z <= z1 for x0, z0, x1, z1 in blocked):
            return False
        # Tram supports stand at the avenue kerbs.
        for sx in supports:
            for kz in (near_kerb_z, far_kerb_z):
                if math.hypot(x - sx, z - kz) < MARGIN_M:
                    return False
        return True

    rng = random.Random(SEED)
    items = {"hydrant": [], "mailbox": [], "callbox": [], "ashcan": [], "telegraph_pole": [], "signpost": []}
    signs = []
    runs = merge(kerbs["runs"])
    for r in runs:
        pts = r["points"]
        L = length(pts)
        if L < 2 * END_CLEAR_M + 1.0:
            continue
        ox, oz = r["out"]
        # Furniture faces the road: yaw turns its front (+Z in the stock) toward the outward direction.
        yaw = round(math.atan2(ox, oz), 4)
        # Corners: a hydrant at one end, a mailbox or call box at the other, as the mid-ground does.
        # A short stub gets one corner item, not two crowded together.
        for d in ((CORNER_AT_M, L - CORNER_AT_M) if L >= 12.0 else (CORNER_AT_M,)):
            p = at_distance(pts, d)
            if not clear(p[0], p[2]):
                continue
            roll = rng.random()
            kind = "hydrant" if roll < 0.45 else ("mailbox" if roll < 0.6 else ("callbox" if roll < 0.72 else ""))
            if kind:
                items[kind].append([round(p[0], 3), round(p[1], 3), round(p[2], 3), round(yaw + (rng.uniform(-0.4, 0.4) if kind == "hydrant" else 0.0), 4)])
        d = rng.uniform(8.0, 20.0)
        while d < L - END_CLEAR_M - 2.0:
            if rng.random() < 0.4:
                p = at_distance(pts, d)
                if clear(p[0], p[2]):
                    items["ashcan"].append([round(p[0], 3), round(p[1], 3), round(p[2], 3), round(rng.uniform(0, math.tau), 4)])
            d += rng.uniform(12.0, 26.0)
        # Telegraph poles: side streets only (runs along z; the avenue carries the trolley wire), on the side facing
        # +x, so one line of poles per street.
        along_z = abs(ox) > 0.5
        under_el = EL_STREET_X[0] <= pts[0][0] <= EL_STREET_X[1]
        if along_z and ox > 0 and not under_el:
            d = END_CLEAR_M + 4.0
            while d < L - END_CLEAR_M:
                p = at_distance(pts, d)
                q = [p[0] - ox * POLE_INSET_M, p[1], p[2] - oz * POLE_INSET_M]
                if clear(q[0], q[2]):
                    items["telegraph_pole"].append([round(q[0], 3), round(q[1], 3), round(q[2], 3), yaw])
                d += POLE_PITCH_M
    walk = [p for r in kerbs["runs"] for p in r["points"]]
    # Each crossing offers its four corners in order (north-east first, as the mid-ground does); the build keeps the
    # first the running world accepts.
    for cx, half, street in CROSSINGS:
        for sx, sz in ((1, -1), (-1, -1), (1, 1), (-1, 1)):
            x = cx + sx * (half + 0.7 + SIGN_BACK_M)
            z = AVENUE_Z + sz * (AVENUE_HALF + 0.7)
            near = min(walk, key=lambda p: (p[0] - x) ** 2 + (p[2] - z) ** 2)
            items["signpost"].append([round(x, 3), near[1], round(z, 3), 0.0])
            signs.append({"x": round(x, 3), "y": near[1], "z": round(z, 3), "avenue": list(AVENUE), "street": list(street)})
    out = {"evidence_class": "INERT", "frame": "WORLD", "status": "candidates; the running-world probe accepts or refuses each",
           "rules": {"end_clear_m": END_CLEAR_M, "corner_at_m": CORNER_AT_M, "pole_pitch_m": POLE_PITCH_M, "margin_m": MARGIN_M, "seed": SEED},
           "runs": len(runs), "items": items, "signs": signs}
    (DATA / "candidates.json").write_text(json.dumps(out, separators=(",", ":")))
    print("NEAR FURNITURE candidates", {k: len(v) for k, v in items.items()}, "from", len(runs), "runs")


main()
