"""Generate an isolated bodega frontage and circulation fit from installed source."""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
EXTERIOR = ROOT / "game/data/orison_v2/exterior"
PLAN = ROOT / "art/data/bodega_frontage/circulation_plan.json"
DOOR = ROOT / "game/scripts/props/door_prop.gd"
PLAYER = ROOT / "game/scripts/player/player_controller.gd"
RESIDENT = ROOT / 'game/scripts/characters/orison_v2_resident_route.gd'


def read(path):
    return json.loads(path.read_text(encoding="utf-8"))


def by_id(rows, name):
    found = [row for row in rows if row["id"] == name]
    if len(found) != 1:
        raise ValueError(f"Expected one source row for {name}")
    return found[0]


def rect(row):
    x, _, z = row["position_m"]
    width, _, depth = row["size_m"]
    if row["yaw_degrees"]:
        raise ValueError(f"Non-axis-aligned bodega source {row['id']}")
    return x - width / 2, z - depth / 2, x + width / 2, z + depth / 2


def distance(point, box):
    x, z = point
    return math.hypot(max(box[0] - x, x - box[2], 0), max(box[1] - z, z - box[3], 0))


def gap(a, b):
    return math.hypot(max(a[0] - b[2], b[0] - a[2], 0), max(a[1] - b[3], b[1] - a[3], 0))


def span(row, low, high):
    row["position_m"][0] = round((low + high) / 2, 8)
    row["size_m"][0] = round(high - low, 8)


def source_number(path, field, assignment):
    match = re.search(re.escape(field) + r"\s*" + assignment + r"\s*([.0-9]+)", path.read_text(encoding="utf-8"))
    if not match:
        raise ValueError(f"Cannot resolve {field} in {path}")
    return float(match[1])


def apply(plan, geometry, regions):
    if plan.get("schema") != "orison.bodega-circulation.v1":
        raise ValueError("Unsupported bodega circulation plan")
    template = by_id(geometry["templates"], plan["template"])
    region = by_id(regions["surface_templates"], plan["template"])
    rows = {row["id"]: row for row in template["boxes"]}
    entrance = plan["entrance"]
    half = entrance["leaf_width_m"]
    door = next(row for row in template["doors"] if row["surface_id"] == "threshold")
    if door["swing_out"] or not math.isclose(door["offset_uvn_m"][0], -door["width_m"] / 2):
        raise ValueError("Expected a centred inward bodega entrance")
    door["width_m"] = round(half * 2, 6)
    door["offset_uvn_m"][0] = -half

    outer = rect(rows["facade_right_pier"])[0]
    if not half < entrance["jamb_inner_x_m"] < entrance["display_inner_x_m"] < outer:
        raise ValueError("Expanded frontage must fit between the original piers")
    for side, direction in (("left", -1), ("right", 1)):
        for stock in ("bulkhead", "store_glass"):
            limits = sorted((direction * entrance["display_inner_x_m"], direction * outer))
            span(rows[f"{side}_{stock}"], *limits)
        limits = sorted((direction * entrance["jamb_inner_x_m"], direction * entrance["display_inner_x_m"]))
        span(rows[f"{side}_window_bar"], *limits)
    span(rows["threshold_sill"], -half - 0.08, half + 0.08)
    span(rows["front_transom"], -entrance["display_inner_x_m"], entrance["display_inner_x_m"])
    for side, stock in ((-1, "stock_left_window_crates"), (1, "stock_right_window_baskets")):
        rows[stock]["position_m"][0] = side * plan["display_stock_x_m"]
        rows[stock]["size_m"][0] = plan["display_stock_width_m"]

    for index, target in enumerate(plan["rack_centres_x_m"], 1):
        group = "a" if index == 1 else "b"
        offset = target - rows[f"aisle_{group}_body"]["position_m"][0]
        prefixes = (f"aisle_{group}_", f"aisle_{index}_", f"stock_aisle_{index}_")
        for name, row in rows.items():
            if name.startswith(prefixes):
                row["position_m"][0] = round(row["position_m"][0] + offset, 8)

    threshold = by_id(region["surfaces"], "threshold")
    threshold["size_m"][0] = round(half * 2 + 0.20, 6)
    floor = by_id(region["surfaces"], "floor")
    for name, (x, z) in plan["placements_xz_m"].items():
        row = by_id(region["placements"], name)
        if row["surface_id"] != "floor":
            raise ValueError(f"{name} no longer belongs to the trading floor")
        row["offset_uvn_m"][:2] = [x, round(z - floor["point_m"][2], 8)]

    return rows, door


def validate(plan, rows, door):
    radius = source_number(PLAYER, "const BODY_RADIUS", ":=")
    standing_radius = source_number(RESIDENT, "_capsule.radius", "=")
    setback = source_number(DOOR, "const HINGE_SETBACK", ":=")
    half = plan["entrance"]["leaf_width_m"]
    depth = plan["entrance"]["hardware_half_depth_m"]
    clear = 2 * (half - setback - depth)
    if clear < plan["entrance"]["required_open_clearance_m"]:
        raise ValueError(f"Open leaves leave only {clear:.3f} m")
    obstacles = {
        name: rect(row)
        for name, row in rows.items()
        if name.startswith(("counter_", "aisle_", "cooler_", "stock_", "delivery_crate", "delivery_handcart"))
        or name.endswith(("_party_wall", "_wall_wainscot", "_bulkhead", "_pier"))
    }
    fit_margin = math.inf
    for step in range(361):
        angle = math.radians(step / 4)
        for sign in (-1, 1):
            corners = [
                (sign * (half - along * math.cos(angle) - across * math.sin(angle)),
                 door["offset_uvn_m"][2] - setback - along * math.sin(angle) + across * math.cos(angle))
                for along in (0, half) for across in (setback-depth, setback+depth)
            ]
            xs, zs = zip(*corners)
            swept = (min(xs), min(zs), max(xs), max(zs))
            for name, box in obstacles.items():
                margin = gap(swept, box)
                if margin < 0.006:
                    raise ValueError(f"Proposed swing meets {name} at {step / 4:.2f} degrees")
                fit_margin = min(fit_margin, margin)

    queue = [(0.35, -2.72)] + [
        plan["placements_xz_m"][name] for name in ("resident_wait_front", "resident_wait_rear")
    ]
    projection = setback + depth
    open_depth = door["offset_uvn_m"][2] - setback
    for side in (-1, 1):
        left, right = sorted((side * (half - projection), side * (half + depth)))
        obstacles[f"open_leaf_{side}"] = (left, open_depth - half, right, open_depth)
    route_margin = math.inf
    route = plan["circulation_xz_m"]
    for start, end in zip(route, route[1:]):
        intervals = max(1, math.ceil(math.dist(start, end) / 0.01))
        for index in range(intervals + 1):
            fraction = index / intervals
            point = tuple(a + (b - a) * fraction for a, b in zip(start, end))
            for name, box in obstacles.items():
                remaining = distance(point, box) - radius
                if remaining < 0.015:
                    raise ValueError(f"Proposed path at {point!r} lacks clearance from {name}")
                route_margin = min(route_margin, remaining)
            for standing in queue:
                if math.dist(point, standing) < radius + standing_radius + 0.04:
                    raise ValueError(f"Proposed path at {point!r} enters the service queue")
    return {
        "open_clearance_m": round(clear, 4),
        "minimum_swing_margin_m": round(fit_margin, 4),
        "minimum_circulation_margin_m": round(route_margin, 4),
        "clear_between_racks_m": round(rect(rows["aisle_2_shelf_low"])[0] - rect(rows["aisle_1_shelf_low"])[2], 4),
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", required=True, type=Path)
    args = parser.parse_args()
    if args.out.resolve().is_relative_to(ROOT):
        raise ValueError("Write the uninstalled preview outside the production checkout")
    geometry_path = EXTERIOR / "exterior_geometry.json"
    region_path = EXTERIOR / "regions.json"
    plan, geometry, regions = map(read, (PLAN, geometry_path, region_path))
    rows, door = apply(plan, geometry, regions)
    result = validate(plan, rows, door)
    result["inputs_sha256"] = {
        path.relative_to(ROOT).as_posix(): hashlib.sha256(path.read_bytes().replace(b"\r\n", b"\n")).hexdigest()
        for path in (PLAN, geometry_path, region_path, DOOR, PLAYER, RESIDENT)
    }
    args.out.mkdir(parents=True, exist_ok=False)
    for name, payload in (("exterior_geometry.json", geometry), ("regions.json", regions), ("clearance.json", result)):
        (args.out / name).write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
