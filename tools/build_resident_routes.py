"""Draft resident route files from the V2 blockout (design/ORISON_RESIDENT_BODIES_2026-10-25.md).

For every resident without a route file in game/data/orison_v2/, writes
<resident>_routine.json in the shared route schema:

  - a point at the centre of every room of the resident's flat;
  - a pair of crossing points either side of every door and opening the flat
    uses, joined across it;
  - a walk through the floor's public spaces (doors and openings, breadth
    first) to the floor's stair head, then down the stacked primary stair to
    the network every route shares (Mina's: F02 stair head to the lobby, the
    mail bank, the laundry, the street and the bodega);
  - agenda places for the flat's rooms, the corridor outside the front door,
    and the shared ones; `away` is the floor's stair head.

Spaces are rectangles, so a straight edge between two points of one space
stays inside it. Points are a first cut: OrisonV2RouteProbe checks each file
in the production root and tools/apply_route_probe.py moves blocked points to
the clear spots it suggests. Existing files are never overwritten without
--force (Mina's and Lena's are hand-tuned).

    python tools/build_resident_routes.py [--force] [--only resident ...]
"""
from pathlib import Path
import argparse
import json

ROOT = Path(__file__).resolve().parents[1]
BLOCKOUT = ROOT / "game/data/orison_v2_blockout.json"
SCHEDULES = ROOT / "game/data/resident_schedules.json"
MINA = ROOT / "game/data/orison_v2/mina_routine.json"
OUT = ROOT / "game/data/orison_v2"
NAMES = {"evelyn_marsh": "Evelyn Marsh", "teresa_vale": "Teresa Vale", "juno_kells": "Juno Kells",
         "malcolm_reed": "Malcolm Reed", "omar_bell": "Omar Bell", "rhea_sato": "Rhea Sato",
         "peter_wren": "Peter Wren", "cam_ortiz": "Cam Ortiz", "noel_price": "Noel Price",
         "transient_guests": "The Guests", "nadia_quell": "Nadia Quell", "cal_dwyer": "Cal Dwyer",
         "iris_bell": "Iris Bell", "sacha_reed": "Sacha Reed", "jonah_price": "Jonah Price",
         "mae_kessler": "Mae Kessler"}
# Clearance either side of a door or opening, metres along its normal.
CROSS = 0.7
# The stacked primary stair (PRIMARY_Fn_Fn+1, origin [1.4, -3.1]), as Mina's
# route walks it: clear of the fire-line cabinet, head, half landing, foot.
STAIR_CLEAR, STAIR_TOP, HALF_EAST, HALF_WEST, STAIR_FOOT = (4.06, -3.2), (3.975, -2.4), (3.975, 1.3), (1.925, 1.3), (1.925, -3.5)
# The clear lane through the core west of the lift and stair, and its south
# end (Mina's upper_core / upper_approach on F02); doors east of x = 3 come in
# along the south wall directly, as Lena's does.
CORE_LANE = (-1.75, -3.4)
CORE_LANE_EAST_OF = 3.0


def rnd(value):
    return round(value, 3)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--force", action="store_true")
    parser.add_argument("--only", nargs="*")
    args = parser.parse_args()
    layout = json.loads(BLOCKOUT.read_text(encoding="utf-8"))
    residents = json.loads(SCHEDULES.read_text(encoding="utf-8"))["residents"]
    mina = json.loads(MINA.read_text(encoding="utf-8"))
    levels = {level["id"]: level["y"] for level in layout["levels"]}
    spaces = {space["id"]: space for space in layout["spaces"]}
    links = [dict(link, kind="door") for link in layout["doors"]] \
        + [dict(link, kind="opening") for link in layout["openings"] if len(link.get("connects", [])) == 2]
    shared_paths, shared_points = _shared(mina)
    written = []
    for resident, record in residents.items():
        if args.only and resident not in args.only:
            continue
        path = OUT / ("%s_routine.json" % resident)
        if resident in ("mina_vale", "lena_ortiz") or (path.exists() and not args.force):
            continue
        unit = str(record["unit"])
        route = _route(resident, unit, layout, levels, spaces, links, shared_paths, shared_points)
        path.write_text(_format(route), encoding="utf-8", newline="\n")
        written.append(path.relative_to(ROOT).as_posix())
    print("\n".join(written) if written else "nothing to write")


def _shared(mina):
    """Mina's public network: the F02 stair head down to the street, the mail
    branch and the laundry branch, by point name."""
    main = mina["paths"][0]
    start = [row[0] for row in main].index("stair_top_clear")
    paths = [main[start:]] + [path for path in mina["paths"] if path[0][0] == "stair_bottom"]
    points = {row[0]: row for path in paths for row in path}
    return paths, points


def _unit_spaces(unit, spaces):
    level = "F0" + unit[0]
    return {sid: s for sid, s in spaces.items()
            if s.get("unit") == unit or (sid.startswith(level + "_" + unit[1] + "_"))}


def _contains(space, x, z):
    x0, z0, x1, z1 = space["rect"]
    return min(x0, x1) - 1e-6 <= x <= max(x0, x1) + 1e-6 and min(z0, z1) - 1e-6 <= z <= max(z0, z1) + 1e-6


def _centre(space):
    x0, z0, x1, z1 = space["rect"]
    return (x0 + x1) / 2.0, (z0 + z1) / 2.0


def _crossing(link, inside_space):
    """The two points either side of a door or opening: the one in
    `inside_space` first."""
    cx, cz = link["center"]
    vertical = abs(abs(float(link.get("yaw", 0.0))) - 1.5707963) < 0.1
    # Openings carry no yaw: infer the wall from which side the spaces lie.
    if link["kind"] == "opening":
        x0, z0, x1, z1 = inside_space["rect"]
        vertical = abs(cx - x0) < 1e-3 or abs(cx - x1) < 1e-3
    nx, nz = (1.0, 0.0) if vertical else (0.0, 1.0)
    a = (cx + nx * CROSS, cz + nz * CROSS)
    b = (cx - nx * CROSS, cz - nz * CROSS)
    return (a, b) if _contains(inside_space, *a) else (b, a)


def _route(resident, unit, layout, levels, spaces, links, shared_paths, shared_points):
    level = "F0" + unit[0]
    y = levels[level]
    flat = _unit_spaces(unit, spaces)
    points = {}
    paths = []

    def point(name, x, z, height=y):
        points[name] = [name, rnd(x), rnd(height), rnd(z)]
        return points[name]

    def key(space_id):
        return space_id.split("_", 2)[2].lower() if space_id.count("_") >= 2 else space_id.lower()

    for sid, space in flat.items():
        point(key(sid), *_centre(space))
    doors, entry = [], None
    for link in links:
        a, b = link["connects"]
        if a not in flat and b not in flat:
            continue
        if link["kind"] == "door":
            doors.append(link["id"])
        if a in flat and b in flat:
            pa, pb = _crossing(link, spaces[a])
            na, nb = point(link["id"].lower() + "_a", *pa), point(link["id"].lower() + "_b", *pb)
            paths.append([points[key(a)], na, nb, points[key(b)]])
        elif entry is None:
            inside, outside = (a, b) if a in flat else (b, a)
            entry = (link, inside, outside)
    if entry is None:
        raise SystemExit("%s: no way out of %s" % (resident, unit))
    link, inside, outside = entry
    pin, pout = _crossing(link, spaces[inside])
    door_in = point("entry_in", *pin)
    door_out = point("entry_out", *pout)
    paths.append([points[key(inside)], door_in, door_out])
    # Through the floor's public spaces to the stair head (or, on F01, the lobby).
    if level == "F01":
        goal = shared_points["lobby"]
    elif level == "F02":
        goal = shared_points["stair_top_clear"]
    else:
        goal = point("%s_stair_clear" % level.lower(), *STAIR_CLEAR)
    # A landing and its core can share one rectangle: any space holding the goal will do.
    goal_spaces = {sid for sid, s in spaces.items() if s.get("level") == level
                   and sid not in flat and _contains(s, goal[1], goal[3])}
    walk = _public_walk(outside, goal_spaces, level, flat, spaces, links)
    chain = [door_out]
    here = outside
    for step, nxt in walk:
        pa, pb = _crossing(step, spaces[here])
        chain += [point(step["id"].lower() + "_a", *pa), point(step["id"].lower() + "_b", *pb)]
        here = nxt
    # In the stair core the lift and the stairwell stand between a west or
    # north door and the stair head: keep to the clear lane Mina's route
    # proved on F02 (x = -1.75) and the core's south wall.
    last = chain[-1]
    if level != "F01" and last[1] < CORE_LANE_EAST_OF:
        chain.append(point("%s_core_lane" % level.lower(), CORE_LANE[0], last[3]))
        chain.append(point("%s_core_south" % level.lower(), *CORE_LANE))
    chain.append(goal)
    paths.append(chain)
    # Down the stacked stair to F02's head, where the shared network begins.
    floor = int(unit[0])
    while floor > 2:
        top, below = "F0%d" % floor, "F0%d" % (floor - 1)
        yt, yb = levels[top], levels[below]
        down = [points.get("%s_stair_clear" % top.lower()) or point("%s_stair_clear" % top.lower(), *STAIR_CLEAR, yt),
                point("%s_stair_top" % top.lower(), *STAIR_TOP, yt),
                point("%s_half_east" % top.lower(), *HALF_EAST, yt - 1.6),
                point("%s_half_west" % top.lower(), *HALF_WEST, yt - 1.6),
                point("%s_stair_foot" % below.lower(), *STAIR_FOOT, yb)]
        down.append(shared_points["stair_top_clear"] if floor - 1 == 2
                    else point("%s_stair_clear" % below.lower(), *STAIR_CLEAR, yb))
        paths.append(down)
        floor -= 1
    paths += [list(path) for path in shared_paths]
    rooms = {key(sid): sid for sid in flat}
    main_room = next((k for k in ("main", "living", "studio") if k in rooms), key(inside))
    places = {"unit": main_room}
    for room in rooms:
        places["unit:" + room] = room
    for alias, candidates in (("unit:bedroom", ("bed", "bed1", "abed")), ("unit:bathroom", ("bath",)),
                              ("unit:kitchen", ("kitchen",))):
        for candidate in candidates:
            if candidate in rooms:
                places[alias] = candidate
                break
    places.update({"corridor": "entry_out", "lobby": "lobby", "mail_bank": "mail", "laundry": "laundry",
                   "bodega": "bodega", "out": "street"})
    away = "stair_bottom" if level == "F01" else ("stair_top" if level == "F02" else "%s_stair_top" % level.lower())
    return {"schema_version": 1, "resident": resident, "name": NAMES.get(resident, resident.replace("_", " ").title()),
            "unit": unit, "frame": "orison_v2_blockout", "doors": sorted(set(doors)), "away": away,
            "paths": paths, "places": places}


def _public_walk(start, goals, level, flat, spaces, links):
    """Breadth first through the floor's public spaces: [(link, next_space), ...]."""
    frontier = [(start, [])]
    seen = {start}
    while frontier:
        here, steps = frontier.pop(0)
        if here in goals:
            return steps
        for link in links:
            if here not in link["connects"]:
                continue
            nxt = link["connects"][1] if link["connects"][0] == here else link["connects"][0]
            if nxt in seen or nxt in flat or spaces.get(nxt, {}).get("level") != level \
                    or spaces[nxt].get("class") == "private":
                continue
            seen.add(nxt)
            frontier.append((nxt, steps + [(link, nxt)]))
    raise SystemExit("no public walk from %s to %s" % (start, goal))


def _format(route):
    lines = ["{"]
    for field in ("schema_version", "resident", "name", "unit", "frame", "doors", "away"):
        lines.append("  %s: %s," % (json.dumps(field), json.dumps(route[field])))
    lines.append('  "paths": [')
    lines.append(",\n".join("    [" + ",".join(json.dumps(row, separators=(",", ":")) for row in path) + "]"
                            for path in route["paths"]))
    lines.append("  ],")
    lines.append('  "places": ' + json.dumps(route["places"], separators=(",", ":")))
    lines.append("}")
    return "\n".join(lines) + "\n"


if __name__ == "__main__":
    main()
