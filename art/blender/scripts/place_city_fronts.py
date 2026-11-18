"""Place building-front dressing on the near city (Lily's ruling city_next_batch_20261117).

Reads the elevations construction record (art/blender/city_elevations_construction.json: buildings, window_rows,
portals), each building's assembly translation (game/data/orison_v2/exterior/city_elevations.json), the near city's
kerb runs (art/blender/data/city_near_furniture/kerbs.json) and the existing roof tanks
(art/blender/city_tanks_construction.json). Writes art/blender/data/city_fronts/candidates.json in the Godot world
frame: shop awnings and lit signboards over wide ground-floor windows on street-facing sides, painted wall adverts on
windowless street-facing walls, billboards on roofs facing the avenue, fire escapes on walk-up street fronts and roof
tanks on near-city roofs that have none. Every item is a candidate until the running-world probe accepts it.

Lettering is authored first-draft copy (FRONTS_COPY below) for Lily to rewrite; it is drawn in Label3D, never in a
texture (RUL-008). No real brand, company or person is named.

    python art/blender/scripts/place_city_fronts.py
"""
import json
import math
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
ELEV = ROOT / "art" / "blender" / "city_elevations_construction.json"
ELEV_DATA = ROOT / "game" / "data" / "orison_v2" / "exterior" / "city_elevations.json"
KERBS = ROOT / "art" / "blender" / "data" / "city_near_furniture" / "kerbs.json"
TANKS = ROOT / "art" / "blender" / "city_tanks_construction.json"
OUT = ROOT / "art" / "blender" / "data" / "city_fronts" / "candidates.json"
FRAME_Z = 9.795          # the city shells sit at z = -source_threshold_z

SHOP_WINDOW_M = 1.6      # a ground-floor window this wide reads as a shop window
STREET_REACH_M = 22.0    # a side faces a street when a kerb lies within this, in front of it
AWNING_PROJECT_M = 1.25
FIRE_ESCAPE_FLOORS = 4   # walk-ups of this many floors or more get one on a street front without one

# First-draft copy, invented and period (1928-29 Long Island City). Shop names go on signboards over shopfronts,
# advert lines on painted walls, billboard lines on rooftop boards. Satire aims at fads, credit and patent cures,
# never at a party, women or trans people (her strip rules).
FRONTS_COPY = {
    "shops": ["KESSLER BROS. HARDWARE", "SUNSWICK BAKERY", "VAN ALST PHARMACY", "M. ROSEN, TAILOR", "PLAZA LUNCH",
              "O'HARA CIGARS & STATIONERY", "STAR HAND LAUNDRY", "ELY AVE. DELICATESSEN", "PAYNTAR SHOE REPAIR",
              "WILLIAM ST. RADIO & ELECTRIC", "HARRIS FLORIST", "NOTT AVE. FISH MARKET"],
    "walls": [["DR. HARLOW'S NERVE TONIC", "FOR THE MODERN PACE"], ["KEYSTONE COAL", "WARM ALL WINTER, ASK THE MAN"],
              ["PALISADE GINGER ALE", "PALE, DRY AND STRICTLY LEGAL"], ["BLUE RIBBON BREAD", "BAKED IN QUEENS EVERY NIGHT"],
              ["PERFECTO RADIO SETS", "A DOLLAR DOWN, A DOLLAR A WEEK, FOREVER"], ["NORTH STAR MOTOR OIL", "IT GOES WHERE YOU GO"]],
    "boards": [["THE BIJOU", "NOW TALKING. NO, REALLY."], ["SEE QUEENS BY TROLLEY", "FIVE CENTS, ANY DIRECTION THAT GOES"],
               ["BUY SOUND STOCKS", "ASK YOUR BARBER WHICH"]],
}


def b2g(p):
    return [p[0], p[2], -p[1]]


def main():
    elev = json.loads(ELEV.read_text())
    offsets = {b["id"]: b2g(b.get("assembly_translation_m", [0, 0, 0])) for b in json.loads(ELEV_DATA.read_text())["buildings"]}
    kerbs = [p for r in json.loads(KERBS.read_text())["runs"] for p in r["points"]]
    tanks = json.loads(TANKS.read_text())["tanks"]
    tanked = {t["assembly"].split("__")[0] for t in tanks}

    def world(building, p):
        o = offsets.get(building, [0, 0, 0])
        g = b2g(p)
        return [g[0] + o[0], g[1] + o[1], g[2] + o[2] - FRAME_Z]

    buildings = {b["id"]: b for b in elev["buildings"]}
    sides = defaultdict(list)
    for w in elev["window_rows"]:
        sides[(w["building"], w["side"])].append(w)

    def centre_of(building):
        r = buildings[building]["main_rect"]
        return world(building, [(r[0] + r[2]) / 2, (r[1] + r[3]) / 2, 0.0])

    def faces_street(at, normal):
        for k in kerbs:
            dx, dz = k[0] - at[0], k[2] - at[2]
            ahead = dx * normal[0] + dz * normal[1]
            lateral = abs(-dx * normal[1] + dz * normal[0])
            if 0.5 < ahead < STREET_REACH_M and lateral < 6.0:
                return True
        return False

    items = {"awning": [], "signboard": [], "wall_advert": [], "billboard": [], "fire_escape": [], "roof_tank": []}
    shop_i = wall_i = 0
    for (building, side), rows in sorted(sides.items()):
        c = centre_of(building)
        pts = [world(building, w["center"]) for w in rows]
        mx = sum(p[0] for p in pts) / len(pts)
        mz = sum(p[2] for p in pts) / len(pts)
        n = [mx - c[0], mz - c[2]]
        # Snap to the side's axis: the elevations are rectilinear.
        n = [1.0 if n[0] > 0 else -1.0, 0.0] if abs(n[0]) >= abs(n[1]) else [0.0, 1.0 if n[1] > 0 else -1.0]
        yaw = round(math.atan2(n[0], n[1]), 4)
        if not faces_street([mx, 0, mz], n):
            continue
        floors = max(w["floor"] for w in rows) + 1
        ground = [(w, world(building, w["center"])) for w in rows if w["floor"] == 0 and w["width"] >= SHOP_WINDOW_M]
        if ground:
            name = FRONTS_COPY["shops"][shop_i % len(FRONTS_COPY["shops"])]
            shop_i += 1
            for w, p in ground:
                top = p[1] + w["height"] / 2
                items["awning"].append({"at": [round(p[0] + n[0] * 0.05, 3), round(top + 0.12, 3), round(p[2] + n[1] * 0.05, 3)],
                                        "yaw": yaw, "width": round(w["width"] + 0.5, 3), "project": AWNING_PROJECT_M,
                                        "building": building})
            # One signboard over the run of shop windows, centred on them, above the awnings.
            gx = sum(p[0] for _, p in ground) / len(ground)
            gz = sum(p[2] for _, p in ground) / len(ground)
            span = max(abs((p[0] - gx) * n[1] - (p[2] - gz) * n[0]) for _, p in ground) * 2 + max(w["width"] for w, _ in ground)
            top = max(p[1] + w["height"] / 2 for w, p in ground)
            items["signboard"].append({"at": [round(gx + n[0] * 0.06, 3), round(top + 0.95, 3), round(gz + n[1] * 0.06, 3)],
                                       "yaw": yaw, "width": round(min(max(span, 2.8), 9.0), 3), "height": 0.62, "text": name,
                                       "building": building})
        if floors >= FIRE_ESCAPE_FLOORS:
            # The centre bay's windows from the second floor up carry the platforms.
            bays = sorted({w["bay"] for w in rows})
            mid = bays[len(bays) // 2]
            levels = sorted({round(world(building, w["center"])[1] - w["height"] / 2, 3) for w in rows if w["bay"] == mid and w["floor"] >= 1})
            col = [world(building, w["center"]) for w in rows if w["bay"] == mid]
            if levels and col:
                items["fire_escape"].append({"at": [round(col[0][0], 3), 0.0, round(col[0][2], 3)], "yaw": yaw,
                                             "levels": levels, "width": 3.2, "depth": 1.05, "building": building})
    # Windowless street-facing walls: the main rect's edges with no window rows on them, high enough to read.
    for building, b in sorted(buildings.items()):
        r = b["main_rect"]
        height = float(b.get("roof_height", 10.0))
        if height < 9.0:
            continue
        have = {s for (bb, s) in sides if bb == building}
        edges = [([r[0], (r[1] + r[3]) / 2], [-1, 0], r[3] - r[1]), ([r[2], (r[1] + r[3]) / 2], [1, 0], r[3] - r[1]),
                 ([(r[0] + r[2]) / 2, r[1]], [0, -1], r[2] - r[0]), ([(r[0] + r[2]) / 2, r[3]], [0, 1], r[2] - r[0])]
        for (ex, ey), (nbx, nby), length in edges:
            p = world(building, [ex, ey, 0.0])
            n = [nbx, -nby]  # Blender y flips to Godot -z
            pts_on = [world(building, w["center"]) for (bb, s), rows in sides.items() if bb == building for w in rows]
            on_wall = [q for q in pts_on if abs((q[0] - p[0]) * n[0] + (q[2] - p[2]) * n[1]) < 0.6]
            if on_wall or length < 8.0 or not faces_street(p, n):
                continue
            w_m = min(length - 2.0, 11.0)
            h_m = min(height - 5.0, 5.5)
            copy = FRONTS_COPY["walls"][wall_i % len(FRONTS_COPY["walls"])]
            wall_i += 1
            items["wall_advert"].append({"at": [round(p[0] + n[0] * 0.03, 3), round(height - 1.2 - h_m / 2, 3), round(p[2] + n[1] * 0.03, 3)],
                                         "yaw": round(math.atan2(n[0], n[1]), 4), "width": round(w_m, 2), "height": round(h_m, 2),
                                         "text": copy, "building": building})
        # Roof tanks where the near city lacks them: four floors or more and no tank group.
        floors = len(b.get("floor_heights", []))
        if building not in tanked and floors >= 4:
            c = world(building, [(r[0] + r[2]) / 2, (r[1] + r[3]) / 2, height])
            items["roof_tank"].append({"at": [round(c[0], 3), round(c[1], 3), round(c[2], 3)], "yaw": 0.0, "building": building})
    # Billboards: on the two roofs nearest the avenue that face it, one each, facing the street.
    roofs = sorted({(f["building"]) for f in items["wall_advert"]})
    board_i = 0
    for building in roofs[:3]:
        b = buildings[building]
        r = b["main_rect"]
        height = float(b.get("roof_height", 10.0))
        c = world(building, [(r[0] + r[2]) / 2, (r[1] + r[3]) / 2, height])
        ad = next(a for a in items["wall_advert"] if a["building"] == building)
        items["billboard"].append({"at": [round(c[0], 3), round(c[1], 3), round(c[2], 3)], "yaw": ad["yaw"], "width": 7.3, "height": 3.0,
                                   "text": FRONTS_COPY["boards"][board_i % len(FRONTS_COPY["boards"])], "building": building})
        board_i += 1
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps({"evidence_class": "INERT", "frame": "WORLD", "copy": FRONTS_COPY, "items": items}, indent=1))
    print("FRONTS candidates", {k: len(v) for k, v in items.items()})


main()
