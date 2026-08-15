#!/usr/bin/env python3
"""Deterministic control assembler for the ruled Orison dream maze.

This is N2's substrate, not the runtime maze builder. It proves that the ten
source-authored modules still agree with waking layout data, that every door and
hazard socket is physically credible, and that the saved-seed permutations keep
the complete directed graph reachable and collision-free in the control pack.

Outputs:
    art/data/dream_maze_layout.json
    art/renders/dream_maze_n2/dream_maze_top_down.svg

Run from anywhere:
    python art/data/gen_dream_maze.py --seed 0 --audit-seeds 100
"""

from __future__ import annotations

import argparse
import copy
import hashlib
import html
import json
import math
import os
import random
import re
import sys
from typing import Any


HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
CATALOG_PATH = os.path.join(ROOT, "game", "data", "dream_module_catalog.json")
LAYOUT_PATH = os.path.join(HERE, "building_layout.json")
PLAYER_PATH = os.path.join(ROOT, "game", "scripts", "player", "player_controller.gd")
OUTPUT_JSON = os.path.join(HERE, "dream_maze_layout.json")
RENDER_DIR = os.path.join(ROOT, "art", "renders", "dream_maze_n2")
OUTPUT_SVG = os.path.join(RENDER_DIR, "dream_maze_top_down.svg")

MODULE_IDS = [
    "D00_4B_THRESHOLD",
    "D01_F04_LONG_HALL",
    "D02_DOGLEG_STAIR",
    "D03_LIFT_VOID",
    "D04_BATHROOM_PROCESSION",
    "D05_SERVICE_RISER",
    "D06_LAUNDRY_BOILER",
    "D07_LIGHT_COURT_WALK",
    "D08_CASE_ECHO",
    "D09_RETURN_HALL",
]

SHORT_NAMES = {
    "D00_4B_THRESHOLD": "4B THRESHOLD",
    "D01_F04_LONG_HALL": "F04 LONG HALL",
    "D02_DOGLEG_STAIR": "DOG-LEG STAIR",
    "D03_LIFT_VOID": "LIFT VOID",
    "D04_BATHROOM_PROCESSION": "BATHROOM RUN",
    "D05_SERVICE_RISER": "SERVICE RISER",
    "D06_LAUNDRY_BOILER": "PLANT ROOMS",
    "D07_LIGHT_COURT_WALK": "LIGHT-COURT WALK",
    "D08_CASE_ECHO": "CASE ECHO",
    "D09_RETURN_HALL": "RETURN HALL",
}

# Control-sheet packing coordinates only. They deliberately leave enough air to
# prove AABBs do not overlap for either seeded branch handedness. Runtime
# connection geometry is a later N4 consumer and must follow topology, not
# mistake this sheet packing for waking-world coordinates.
FIXED_POSITIONS = {
    "D00_4B_THRESHOLD": [0.0, 0.0],
    "D01_F04_LONG_HALL": [4.0, 0.0],
    "D04_BATHROOM_PROCESSION": [39.0, 0.0],
    "D05_SERVICE_RISER": [52.0, 0.0],
    "D08_CASE_ECHO": [84.0, 0.0],
    "D09_RETURN_HALL": [85.0, -14.0],
}

EARLY_SLOTS = {"upper": [28.0, 8.0], "lower": [28.0, -14.0]}
LATE_SLOTS = {"upper": [63.0, 8.0], "lower": [63.0, -18.0]}


class AuditError(RuntimeError):
    pass


def load_json(path: str) -> dict[str, Any]:
    with open(path, "r", encoding="utf-8") as handle:
        data = json.load(handle)
    if not isinstance(data, dict):
        raise AuditError(f"{path} must contain a JSON object")
    return data


def close(a: float, b: float, tolerance: float = 1e-6) -> bool:
    return math.isclose(float(a), float(b), abs_tol=tolerance)


def close_list(actual: list[Any], expected: list[Any]) -> bool:
    return len(actual) == len(expected) and all(
        close(float(a), float(b)) for a, b in zip(actual, expected)
    )


def room_record(layout: dict[str, Any], floor_id: str, room_id: str) -> dict[str, Any]:
    for floor in layout.get("floors", []):
        if floor.get("id") != floor_id:
            continue
        for room in floor.get("rooms", []):
            if room.get("id") == room_id:
                return room
    raise AuditError(f"source room missing: {floor_id}/{room_id}")


def floor_record(layout: dict[str, Any], floor_id: str) -> dict[str, Any]:
    for floor in layout.get("floors", []):
        if floor.get("id") == floor_id:
            return floor
    raise AuditError(f"source floor missing: {floor_id}")


def audit_source_truth(catalog: dict[str, Any], layout: dict[str, Any]) -> list[str]:
    checks: list[str] = []
    modules = catalog["modules"]
    for module_id, module in modules.items():
        for source in module["source"]["records"]:
            kind = source["kind"]
            if kind == "room":
                record = room_record(layout, source["floor"], source["id"])
                actual = [float(value) for value in record.get("rect", [])]
                expected = [float(value) for value in source["rect_m"]]
                if not close_list(actual, expected):
                    raise AuditError(
                        f"{module_id}: source rect drift for {source['id']}: "
                        f"{actual} != {expected}"
                    )
                checks.append(f"{module_id}:{source['id']} rect")
            elif kind == "stairs":
                stairs = next(
                    (
                        item
                        for item in layout.get("stairs", [])
                        if item.get("id") == source["id"]
                    ),
                    None,
                )
                if stairs is None:
                    raise AuditError(f"{module_id}: stair source {source['id']} missing")
                if not close_list(stairs.get("well", []), source["well_m"]):
                    raise AuditError(f"{module_id}: atrium well drift")
                if not close(stairs.get("width", 0.0), source["width_m"]):
                    raise AuditError(f"{module_id}: atrium flight width drift")
                checks.append(f"{module_id}:atrium well/width")
            elif kind == "elevator":
                elevator = layout.get("elevator", {})
                if not close_list(elevator.get("shaft", []), source["shaft_m"]):
                    raise AuditError(f"{module_id}: elevator shaft drift")
                if not close(elevator.get("door_w", 0.0), source["door_width_m"]):
                    raise AuditError(f"{module_id}: elevator door drift")
                checks.append(f"{module_id}:elevator shaft/door")
            else:
                raise AuditError(f"{module_id}: unknown source kind {kind}")

    constants = catalog["constants"]
    f04 = floor_record(layout, "F04")
    ceiling_z = min(float(item["z"]) for item in f04.get("ceilings", []))
    clear_height = ceiling_z - float(f04["z"])
    if not close(clear_height, constants["clear_ceiling_m"]):
        raise AuditError(
            f"F04 clear ceiling drift: {clear_height} != {constants['clear_ceiling_m']}"
        )
    checks.append("F04 clear ceiling")

    with open(PLAYER_PATH, "r", encoding="utf-8") as handle:
        player_source = handle.read()
    match = re.search(r"const\s+BODY_RADIUS\s*:=\s*([0-9.]+)", player_source)
    if match is None:
        raise AuditError("PlayerController BODY_RADIUS source missing")
    capsule_diameter = float(match.group(1)) * 2.0
    if not close(capsule_diameter, constants["player_capsule_diameter_m"]):
        raise AuditError(
            f"player capsule drift: {capsule_diameter} != "
            f"{constants['player_capsule_diameter_m']}"
        )
    checks.append("PlayerController capsule diameter")

    stairs = next(
        (item for item in layout.get("stairs", []) if item.get("id") == "atrium"),
        None,
    )
    if stairs is None:
        raise AuditError("atrium stair source missing")
    maximum_rise = max(
        float(part.get("rise", 0.0))
        for part in stairs.get("parts", [])
        if part.get("kind") == "flight"
    )
    if maximum_rise > 0.30 + 1e-6:
        raise AuditError(f"authored stair rise {maximum_rise} exceeds player step proof")
    checks.append("atrium riser <= player step proof")
    return checks


def connector_span(module: dict[str, Any], connector: dict[str, Any]) -> float:
    width, height = [float(value) for value in module["footprint_m"]]
    return width if connector["side"] in ("north", "south") else height


def audit_catalog(catalog: dict[str, Any], layout: dict[str, Any]) -> dict[str, Any]:
    if catalog.get("meta", {}).get("version") != 1:
        raise AuditError("dream module catalog version must be 1")
    modules = catalog.get("modules", {})
    if list(modules.keys()) != MODULE_IDS:
        raise AuditError("dream module ids/order do not match the ruled D00-D09 set")
    constants = catalog.get("constants", {})
    capsule = float(constants["player_capsule_diameter_m"])
    connector_margin = float(constants["minimum_connector_margin_m"])
    run_speed = float(constants["player_run_speed_mps"])
    minimum_warning = float(constants["minimum_warning_s"])
    connector_endpoints: set[tuple[str, str]] = set()
    hazard_ids: set[str] = set()
    hazard_count = 0

    for module_id, module in modules.items():
        footprint = [float(value) for value in module.get("footprint_m", [])]
        if len(footprint) != 2 or min(footprint) <= 0.0:
            raise AuditError(f"{module_id}: invalid footprint")
        if int(module.get("unlock_slot", 0)) not in range(1, 7):
            raise AuditError(f"{module_id}: invalid campaign unlock slot")
        connector_ids: set[str] = set()
        spans_by_side: dict[str, list[tuple[float, float, str]]] = {}
        for connector in module.get("connectors", []):
            connector_id = str(connector.get("id", ""))
            if not connector_id or connector_id in connector_ids:
                raise AuditError(f"{module_id}: duplicate/empty connector id")
            connector_ids.add(connector_id)
            side = str(connector.get("side", ""))
            if side not in ("north", "south", "east", "west"):
                raise AuditError(f"{module_id}/{connector_id}: invalid side")
            width = float(connector.get("width_m", 0.0))
            if width + 1e-6 < capsule + connector_margin:
                raise AuditError(
                    f"{module_id}/{connector_id}: {width:.3f} m opening cannot pass "
                    f"{capsule:.3f} m capsule + {connector_margin:.3f} m margin"
                )
            if float(connector.get("height_m", 0.0)) > float(constants["clear_ceiling_m"]):
                raise AuditError(f"{module_id}/{connector_id}: connector exceeds ceiling")
            side_span = connector_span(module, connector)
            offset = float(connector.get("offset_m", -1.0))
            low, high = offset - width * 0.5, offset + width * 0.5
            if low < -1e-6 or high > side_span + 1e-6:
                raise AuditError(f"{module_id}/{connector_id}: opening escapes wall span")
            spans_by_side.setdefault(side, []).append((low, high, connector_id))
            if connector.get("swing", "none") != "none":
                depth = float(connector.get("swing_depth_m", 0.0))
                normal_span = footprint[1] if side in ("north", "south") else footprint[0]
                if depth <= 0.0 or depth > normal_span + 1e-6:
                    raise AuditError(f"{module_id}/{connector_id}: invalid swing depth")
            connector_endpoints.add((module_id, connector_id))
        for side, spans in spans_by_side.items():
            spans.sort()
            for first, second in zip(spans, spans[1:]):
                if first[1] > second[0] + 1e-6:
                    raise AuditError(
                        f"{module_id}: {side} openings {first[2]} and {second[2]} overlap"
                    )

        hazards = module.get("hazard_sockets", [])
        for hazard in hazards:
            hazard_id = str(hazard.get("id", ""))
            if not hazard_id or hazard_id in hazard_ids:
                raise AuditError(f"duplicate/empty hazard id: {hazard_id}")
            hazard_ids.add(hazard_id)
            hazard_count += 1
            x, y = [float(value) for value in hazard.get("position_m", [])]
            radius = float(hazard.get("clearance_radius_m", 0.0))
            if radius <= 0.0 or not (
                radius <= x <= footprint[0] - radius
                and radius <= y <= footprint[1] - radius
            ):
                raise AuditError(f"{module_id}/{hazard_id}: clearance escapes footprint")
            warning = float(hazard.get("minimum_warning_s", 0.0))
            if warning + 1e-6 < minimum_warning:
                raise AuditError(f"{module_id}/{hazard_id}: warning below ruled minimum")
            if float(hazard.get("tell_radius_m", 0.0)) + 1e-6 < warning * run_speed:
                raise AuditError(
                    f"{module_id}/{hazard_id}: tell radius cannot provide its warning at run speed"
                )
        for index, first in enumerate(hazards):
            ax, ay = [float(value) for value in first["position_m"]]
            ar = float(first["clearance_radius_m"])
            for second in hazards[index + 1 :]:
                bx, by = [float(value) for value in second["position_m"]]
                br = float(second["clearance_radius_m"])
                if math.hypot(ax - bx, ay - by) + 1e-6 < ar + br:
                    raise AuditError(
                        f"{module_id}: hazard sockets {first['id']} and {second['id']} overlap"
                    )

    if hazard_count != 8:
        raise AuditError(f"ruled hazard count is 8, catalog contains {hazard_count}")

    used_endpoints: set[tuple[str, str]] = set()
    edge_ids: set[str] = set()
    for edge in catalog.get("topology", []):
        edge_id = str(edge.get("id", ""))
        if not edge_id or edge_id in edge_ids:
            raise AuditError(f"duplicate/empty topology edge: {edge_id}")
        edge_ids.add(edge_id)
        for endpoint in (edge.get("from", []), edge.get("to", [])):
            pair = tuple(endpoint)
            if len(pair) != 2 or pair not in connector_endpoints:
                raise AuditError(f"{edge_id}: unknown connector endpoint {endpoint}")
            if pair in used_endpoints:
                raise AuditError(f"{edge_id}: connector endpoint reused {endpoint}")
            used_endpoints.add(pair)
        expected_unlock = max(
            int(modules[edge["from"][0]]["unlock_slot"]),
            int(modules[edge["to"][0]]["unlock_slot"]),
        )
        if int(edge.get("unlock_slot", 0)) != expected_unlock:
            raise AuditError(
                f"{edge_id}: unlock {edge.get('unlock_slot')} != endpoint gate {expected_unlock}"
            )

    for slot in range(1, 7):
        unlocked = {
            module_id
            for module_id, module in modules.items()
            if int(module["unlock_slot"]) <= slot
        }
        adjacency: dict[str, list[str]] = {module_id: [] for module_id in unlocked}
        for edge in catalog["topology"]:
            if int(edge["unlock_slot"]) <= slot:
                adjacency[edge["from"][0]].append(edge["to"][0])
        reached = {"D00_4B_THRESHOLD"}
        frontier = ["D00_4B_THRESHOLD"]
        while frontier:
            current = frontier.pop(0)
            for neighbor in adjacency.get(current, []):
                if neighbor not in reached:
                    reached.add(neighbor)
                    frontier.append(neighbor)
        if reached != unlocked:
            raise AuditError(
                f"campaign slot {slot}: unreachable modules {sorted(unlocked - reached)}"
            )

    fold = next((edge for edge in catalog["topology"] if edge["id"] == "E09_FOLD"), None)
    if fold is None or fold["to"][0] != "D01_F04_LONG_HALL":
        raise AuditError("terminal fold must return D09 to D01")

    source_checks = audit_source_truth(catalog, layout)
    return {
        "module_count": len(modules),
        "edge_count": len(catalog["topology"]),
        "hazard_count": hazard_count,
        "source_check_count": len(source_checks),
        "source_checks": source_checks,
    }


def control_positions(seed: int) -> tuple[dict[str, list[float]], dict[str, Any]]:
    rng = random.Random(seed)
    early_swap = bool(rng.getrandbits(1))
    late_swap = bool(rng.getrandbits(1))
    positions = copy.deepcopy(FIXED_POSITIONS)
    early_assignment = (
        {"D02_DOGLEG_STAIR": "lower", "D03_LIFT_VOID": "upper"}
        if early_swap
        else {"D02_DOGLEG_STAIR": "upper", "D03_LIFT_VOID": "lower"}
    )
    late_assignment = (
        {"D06_LAUNDRY_BOILER": "lower", "D07_LIGHT_COURT_WALK": "upper"}
        if late_swap
        else {"D06_LAUNDRY_BOILER": "upper", "D07_LIGHT_COURT_WALK": "lower"}
    )
    for module_id, lane in early_assignment.items():
        positions[module_id] = list(EARLY_SLOTS[lane])
    for module_id, lane in late_assignment.items():
        positions[module_id] = list(LATE_SLOTS[lane])
    return positions, {
        "early_branch_handedness": early_assignment,
        "late_branch_handedness": late_assignment,
        "material_phase": rng.randrange(4),
    }


def canonical_bytes(value: Any) -> bytes:
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode("utf-8")


def structural_bytes(assembly: dict[str, Any]) -> bytes:
    """Return seed-independent assembly content for diversity measurement."""
    structure = copy.deepcopy(assembly)
    structure["meta"].pop("seed", None)
    structure["meta"].pop("assembly_sha256", None)
    return canonical_bytes(structure)


def assemble(catalog: dict[str, Any], seed: int) -> dict[str, Any]:
    positions, variants = control_positions(seed)
    rng = random.Random(seed ^ 0x4F5249534F4E)
    modules: list[dict[str, Any]] = []
    hazards: list[dict[str, Any]] = []
    for module_id in MODULE_IDS:
        source = catalog["modules"][module_id]
        width, height = [float(value) for value in source["footprint_m"]]
        x, y = positions[module_id]
        module = {
            "id": module_id,
            "unlock_slot": int(source["unlock_slot"]),
            "control_rect_m": [x, y, x + width, y + height],
            "footprint_m": [width, height],
            "connectors": copy.deepcopy(source["connectors"]),
        }
        if "detail_repeat_range" in source:
            low, high = [int(value) for value in source["detail_repeat_range"]]
            module["detail_repeat_count"] = rng.randint(low, high)
        mirror_hazards = bool(rng.getrandbits(1))
        module["hazards_mirrored"] = mirror_hazards
        for hazard in source.get("hazard_sockets", []):
            local_x, local_y = [float(value) for value in hazard["position_m"]]
            if mirror_hazards:
                local_x = width - local_x
            resolved = copy.deepcopy(hazard)
            resolved["module_id"] = module_id
            resolved["local_position_m"] = [round(local_x, 6), round(local_y, 6)]
            resolved["control_position_m"] = [round(x + local_x, 6), round(y + local_y, 6)]
            resolved.pop("position_m", None)
            hazards.append(resolved)
        modules.append(module)
    assembly = {
        "meta": {
            "title": "Generated Orison dream maze control assembly",
            "version": 1,
            "seed": seed,
            "units": "metres",
            "source_catalog": "game/data/dream_module_catalog.json",
            "control_positions_are_runtime_coordinates": False,
        },
        "constants": copy.deepcopy(catalog["constants"]),
        "variants": variants,
        "modules": modules,
        "topology": copy.deepcopy(catalog["topology"]),
        "hazards": hazards,
    }
    assembly["meta"]["assembly_sha256"] = hashlib.sha256(canonical_bytes(assembly)).hexdigest()
    return assembly


def rects_overlap(first: list[float], second: list[float]) -> bool:
    return (
        first[0] < second[2] - 1e-6
        and second[0] < first[2] - 1e-6
        and first[1] < second[3] - 1e-6
        and second[1] < first[3] - 1e-6
    )


def audit_assembly(assembly: dict[str, Any]) -> None:
    modules = assembly["modules"]
    for index, first in enumerate(modules):
        for second in modules[index + 1 :]:
            if rects_overlap(first["control_rect_m"], second["control_rect_m"]):
                raise AuditError(f"control footprint overlap: {first['id']} / {second['id']}")
    by_id = {module["id"]: module for module in modules}
    for hazard in assembly["hazards"]:
        module = by_id[hazard["module_id"]]
        width, height = module["footprint_m"]
        x, y = hazard["local_position_m"]
        radius = float(hazard["clearance_radius_m"])
        if not (radius <= x <= width - radius and radius <= y <= height - radius):
            raise AuditError(f"seeded hazard escaped module: {hazard['id']}")


def audit_seeds(catalog: dict[str, Any], count: int) -> dict[str, Any]:
    if count <= 0:
        raise AuditError("audit seed count must be positive")
    hashes: set[str] = set()
    for seed in range(count):
        first = assemble(catalog, seed)
        second = assemble(catalog, seed)
        if canonical_bytes(first) != canonical_bytes(second):
            raise AuditError(f"seed {seed}: assembly is not deterministic")
        audit_assembly(first)
        hashes.add(hashlib.sha256(structural_bytes(first)).hexdigest())
    return {
        "seeds_checked": count,
        "stable_rebuilds": count,
        "unique_structures": len(hashes),
        "first_seed": 0,
        "last_seed": count - 1,
    }


def module_lookup(assembly: dict[str, Any]) -> dict[str, dict[str, Any]]:
    return {module["id"]: module for module in assembly["modules"]}


def topology_node_positions(assembly: dict[str, Any]) -> dict[str, tuple[float, float]]:
    variants = assembly["variants"]
    early = variants["early_branch_handedness"]
    late = variants["late_branch_handedness"]
    positions = {
        "D00_4B_THRESHOLD": (95, 215),
        "D01_F04_LONG_HALL": (260, 215),
        "D04_BATHROOM_PROCESSION": (610, 215),
        "D05_SERVICE_RISER": (785, 215),
        "D08_CASE_ECHO": (1135, 215),
        "D09_RETURN_HALL": (1300, 215),
    }
    early_y = {"upper": 135, "lower": 295}
    late_y = {"upper": 135, "lower": 295}
    for module_id, lane in early.items():
        positions[module_id] = (435, early_y[lane])
    for module_id, lane in late.items():
        positions[module_id] = (960, late_y[lane])
    return positions


def connector_world(module: dict[str, Any], connector: dict[str, Any]) -> tuple[float, float]:
    x0, y0, x1, y1 = [float(value) for value in module["control_rect_m"]]
    offset = float(connector["offset_m"])
    side = connector["side"]
    if side == "west":
        return x0, y0 + offset
    if side == "east":
        return x1, y0 + offset
    if side == "south":
        return x0 + offset, y0
    return x0 + offset, y1


def render_svg(
    catalog: dict[str, Any], assembly: dict[str, Any], catalog_audit: dict[str, Any], seed_audit: dict[str, Any]
) -> str:
    nodes = topology_node_positions(assembly)
    modules = module_lookup(assembly)
    colors = {
        1: "#cfdce2",
        2: "#d9d3e7",
        3: "#d8dfc4",
        4: "#ead8b7",
        5: "#dfc9c6",
        6: "#c9c5bd",
    }
    out: list[str] = [
        '<svg xmlns="http://www.w3.org/2000/svg" width="1800" height="1400" viewBox="0 0 1800 1400">',
        "  <title>N2 dimensioned control drawing for the ruled Orison dream maze</title>",
        "  <desc>Topology and source-faithful module footprints in metres for canonical seed %d. Control packing is non-overlapping but is not runtime world placement.</desc>" % assembly["meta"]["seed"],
        "  <defs>",
        '    <pattern id="grid10" width="108" height="108" patternUnits="userSpaceOnUse"><path d="M108 0H0V108" fill="none" stroke="#ddd7ca" stroke-width="1"/></pattern>',
        '    <marker id="arrow" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="6" markerHeight="6" orient="auto-start-reverse"><path d="M0 0L10 5L0 10z" fill="#272b2d"/></marker>',
        "    <style>",
        "      .paper{fill:#f7f3e9}.ink{fill:#272b2d}.muted{fill:#66645f}.title{font:600 27px 'Segoe UI',Arial,sans-serif;letter-spacing:1px}.label{font:600 15px 'Segoe UI',Arial,sans-serif}.note{font:14px 'Segoe UI',Arial,sans-serif}.small{font:12px 'Segoe UI',Arial,sans-serif}.mono{font:13px Consolas,'Courier New',monospace}.edge{fill:none;stroke:#42555e;stroke-width:2;marker-end:url(#arrow)}.fold{fill:none;stroke:#8b3e34;stroke-width:2.5;stroke-dasharray:8 6;marker-end:url(#arrow)}.module{stroke:#35434a;stroke-width:1.6}.connector{fill:#f7f3e9;stroke:#315e73;stroke-width:2}.hazard{stroke:#a43e34;stroke-width:2}.dim{stroke:#272b2d;stroke-width:1.2;fill:none;marker-start:url(#arrow);marker-end:url(#arrow)}.ext{stroke:#77736b;stroke-width:1}.panel{fill:none;stroke:#aaa397;stroke-width:1.2}",
        "    </style>",
        "  </defs>",
        '  <rect class="paper" width="1800" height="1400"/>',
        '  <text x="55" y="48" class="title ink">N2 — ORISON DREAM MAZE / DIMENSIONED MODULE CONTROL</text>',
        '  <text x="55" y="74" class="note muted">metres · source-faithful footprints · deterministic topology · canonical seed %d · construction control, not concept art</text>' % assembly["meta"]["seed"],
        '  <rect x="45" y="95" width="1350" height="390" class="panel"/>',
        '  <text x="65" y="122" class="label ink">DIRECTED CAMPAIGN TOPOLOGY</text>',
    ]

    for edge in catalog["topology"]:
        start_id, end_id = edge["from"][0], edge["to"][0]
        x1, y1 = nodes[start_id]
        x2, y2 = nodes[end_id]
        if edge["id"] == "E09_FOLD":
            path = f"M{x1} {y1 + 37}V430H{x2}V{y2 + 38}"
            out.append(f'  <path d="{path}" class="fold"/>')
            out.append('  <text x="780" y="452" text-anchor="middle" class="small" fill="#8b3e34">D09 RETURNS BEHIND D01 — UNLOCK SLOT 6</text>')
        else:
            bend = (x1 + x2) * 0.5
            path = f"M{x1 + 66} {y1}C{bend} {y1} {bend} {y2} {x2 - 66} {y2}"
            out.append(f'  <path d="{path}" class="edge"/>')

    for module_id in MODULE_IDS:
        x, y = nodes[module_id]
        module = catalog["modules"][module_id]
        width, height = [float(value) for value in module["footprint_m"]]
        slot = int(module["unlock_slot"])
        out.extend([
            f'  <g transform="translate({x - 66} {y - 38})">',
            f'    <rect width="132" height="76" rx="7" fill="{colors[slot]}" class="module"/>',
            f'    <text x="66" y="23" text-anchor="middle" class="label ink">{html.escape(module_id.split("_")[0])}</text>',
            f'    <text x="66" y="43" text-anchor="middle" class="small ink">{html.escape(SHORT_NAMES[module_id])}</text>',
            f'    <text x="66" y="62" text-anchor="middle" class="mono ink">{width:.2f} × {height:.2f} m · S{slot}</text>',
            "  </g>",
        ])

    out.extend([
        '  <rect x="45" y="515" width="1120" height="760" fill="url(#grid10)" class="panel"/>',
        '  <text x="65" y="545" class="label ink">SOURCE-FOOTPRINT CONTROL PACKING — 10.8 px/m · X east · Y north</text>',
        '  <text x="65" y="566" class="small muted">Every rectangle is to scale. Packing proves non-overlap for both seeded branch handings; topology above governs connections.</text>',
    ])

    scale = 10.8
    origin_x = 76.0
    baseline_y = 1215.0
    min_y = -18.0

    def map_x(value: float) -> float:
        return origin_x + value * scale

    def map_y(value: float) -> float:
        return baseline_y - (value - min_y) * scale

    for module_id in MODULE_IDS:
        module = modules[module_id]
        x0, y0, x1, y1 = [float(value) for value in module["control_rect_m"]]
        width, height = x1 - x0, y1 - y0
        px, py = map_x(x0), map_y(y1)
        pw, ph = width * scale, height * scale
        slot = int(module["unlock_slot"])
        out.append(
            f'  <rect x="{px:.2f}" y="{py:.2f}" width="{pw:.2f}" height="{ph:.2f}" fill="{colors[slot]}" class="module"/>'
        )
        label_x, label_y = px + pw * 0.5, py + ph * 0.5
        if ph >= 42.0 and pw >= 60.0:
            out.append(f'  <text x="{label_x:.2f}" y="{label_y - 2:.2f}" text-anchor="middle" class="label ink">{module_id.split("_")[0]}</text>')
            out.append(f'  <text x="{label_x:.2f}" y="{label_y + 15:.2f}" text-anchor="middle" class="small ink">{width:.2f} × {height:.2f}</text>')
        else:
            below = module_id == "D00_4B_THRESHOLD"
            callout_y = py + ph + 17.0 if below else py - 19.0
            dimension_y = callout_y + 14.0
            leader_edge_y = py + ph if below else py
            leader_text_y = callout_y - 10.0 if below else dimension_y + 4.0
            out.append(f'  <line x1="{label_x:.2f}" y1="{leader_edge_y:.2f}" x2="{label_x:.2f}" y2="{leader_text_y:.2f}" class="ext"/>')
            out.append(f'  <text x="{label_x:.2f}" y="{callout_y:.2f}" text-anchor="middle" class="label ink">{module_id.split("_")[0]}</text>')
            out.append(f'  <text x="{label_x:.2f}" y="{dimension_y:.2f}" text-anchor="middle" class="small ink">{width:.2f} × {height:.2f}</text>')
        source_module = catalog["modules"][module_id]
        by_connector = {item["id"]: item for item in source_module["connectors"]}
        for connector in module["connectors"]:
            wx, wy = connector_world(module, by_connector[connector["id"]])
            out.append(f'  <circle cx="{map_x(wx):.2f}" cy="{map_y(wy):.2f}" r="4" class="connector"/>')
    hazard_label_offsets = {
        "open_lift_void": (-19.0, -8.0),
        "counterweight_passage": (8.0, 15.0),
        "vantry_signal_trunk": (8.0, 16.0),
    }
    for index, hazard in enumerate(assembly["hazards"], start=1):
        hx, hy = [float(value) for value in hazard["control_position_m"]]
        px, py = map_x(hx), map_y(hy)
        label_dx, label_dy = hazard_label_offsets.get(hazard["id"], (8.0, -7.0))
        out.append(f'  <path d="M{px - 5:.2f} {py - 5:.2f}L{px + 5:.2f} {py + 5:.2f}M{px + 5:.2f} {py - 5:.2f}L{px - 5:.2f} {py + 5:.2f}" class="hazard"/>')
        out.append(f'  <text x="{px + label_dx:.2f}" y="{py + label_dy:.2f}" class="small" fill="#8b3e34">H{index}</text>')

    # Overall packed control extents and scale bar.
    all_rects = [module["control_rect_m"] for module in assembly["modules"]]
    min_x = min(rect[0] for rect in all_rects)
    max_x = max(rect[2] for rect in all_rects)
    max_y = max(rect[3] for rect in all_rects)
    min_control_y = min(rect[1] for rect in all_rects)
    dim_y = map_y(min_control_y) + 45
    out.extend([
        f'  <line x1="{map_x(min_x):.2f}" y1="{dim_y:.2f}" x2="{map_x(max_x):.2f}" y2="{dim_y:.2f}" class="dim"/>',
        f'  <text x="{(map_x(min_x) + map_x(max_x)) * 0.5:.2f}" y="{dim_y + 20:.2f}" text-anchor="middle" class="mono ink">CONTROL PACK {max_x - min_x:.2f} m</text>',
        f'  <line x1="{map_x(max_x) + 34:.2f}" y1="{map_y(max_y):.2f}" x2="{map_x(max_x) + 34:.2f}" y2="{map_y(min_control_y):.2f}" class="dim"/>',
        f'  <text x="{map_x(max_x) + 48:.2f}" y="{(map_y(max_y) + map_y(min_control_y)) * 0.5:.2f}" class="mono ink">{max_y - min_control_y:.2f} m</text>',
        '  <line x1="75" y1="1248" x2="183" y2="1248" stroke="#272b2d" stroke-width="6"/>',
        '  <text x="75" y="1267" text-anchor="middle" class="small ink">0</text>',
        '  <text x="183" y="1267" text-anchor="middle" class="small ink">10 m</text>',
        '  <circle cx="255" cy="1248" r="4" class="connector"/><text x="267" y="1253" class="small ink">0.91 m connector</text>',
        '  <path d="M400 1243l10 10m0-10l-10 10" class="hazard"/><text x="418" y="1253" class="small ink">hazard socket</text>',
    ])

    out.extend([
        '  <g transform="translate(1190 515)">',
        '    <rect width="565" height="760" fill="#f0ebdf" stroke="#aaa397" stroke-width="1.2"/>',
        '    <text x="22" y="34" class="label ink">CONTROL SCHEDULE</text>',
        f'    <text x="22" y="62" class="mono ink">seed {assembly["meta"]["seed"]} · SHA-256 {assembly["meta"]["assembly_sha256"][:20]}…</text>',
        f'    <text x="22" y="85" class="note ink">{seed_audit["seeds_checked"]}/{seed_audit["seeds_checked"]} seeds · {seed_audit["stable_rebuilds"]} stable · {seed_audit["unique_structures"]} structures</text>',
        f'    <text x="22" y="108" class="note ink">{catalog_audit["module_count"]} modules · {catalog_audit["edge_count"]} directed edges · {catalog_audit["hazard_count"]} hazards</text>',
        f'    <text x="22" y="131" class="note ink">{catalog_audit["source_check_count"]} source-provenance checks · 0 unresolved</text>',
        '    <line x1="22" y1="148" x2="543" y2="148" stroke="#aaa397"/>',
        '    <text x="22" y="176" class="label ink">RULED CLEARANCES</text>',
        f'    <text x="22" y="200" class="mono ink">door       {catalog["constants"]["connector_width_m"]:.3f} m</text>',
        f'    <text x="22" y="222" class="mono ink">capsule    {catalog["constants"]["player_capsule_diameter_m"]:.3f} m</text>',
        f'    <text x="22" y="244" class="mono ink">clearance  {catalog["constants"]["connector_width_m"] - catalog["constants"]["player_capsule_diameter_m"]:.3f} m total</text>',
        f'    <text x="22" y="266" class="mono ink">ceiling    {catalog["constants"]["clear_ceiling_m"]:.3f} m</text>',
        f'    <text x="22" y="288" class="mono ink">run caps   {" / ".join(str(value) for value in catalog["constants"]["campaign_run_ceilings_s"])} s</text>',
        '    <line x1="22" y1="306" x2="543" y2="306" stroke="#aaa397"/>',
        '    <text x="22" y="334" class="label ink">HAZARD SOCKETS</text>',
    ])
    y = 358
    for index, hazard in enumerate(assembly["hazards"], start=1):
        out.append(f'    <text x="22" y="{y}" class="mono ink">H{index}  {html.escape(hazard["id"])} / {html.escape(hazard["module_id"].split("_")[0])}</text>')
        y += 22
    out.extend([
        f'    <line x1="22" y1="{y + 2}" x2="543" y2="{y + 2}" stroke="#aaa397"/>',
        f'    <text x="22" y="{y + 30}" class="label ink">PROVENANCE</text>',
        f'    <text x="22" y="{y + 54}" class="small ink">building_layout.json owns rooms, stair, shaft and ceilings.</text>',
        f'    <text x="22" y="{y + 75}" class="small ink">PlayerController owns the 0.66 m capsule.</text>',
        f'    <text x="22" y="{y + 96}" class="small ink">This sheet owns no waking coordinates.</text>',
        f'    <text x="22" y="{y + 117}" class="small ink">Control packing is not runtime placement.</text>',
        "  </g>",
        '  <text x="55" y="1335" class="note muted">AUDIT: source rects / atrium / elevator / clear ceiling / capsule · connector span / margin / swing · hazard clearance / warning · graph reachability by slot · stable seed hash</text>',
        '  <text x="55" y="1362" class="note muted">Generated by art/data/gen_dream_maze.py. Edit game/data/dream_module_catalog.json or the waking source; never hand-edit generated JSON/SVG/PNG.</text>',
        "</svg>",
    ])
    return "\n".join(out) + "\n"


def write_text(path: str, text: str) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="\n") as handle:
        handle.write(text)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--seed", type=int, default=0, help="canonical saved dream seed")
    parser.add_argument("--audit-seeds", type=int, default=100, help="number of sequential seeds to prove")
    parser.add_argument("--check-only", action="store_true", help="audit without writing generated outputs")
    args = parser.parse_args()
    try:
        catalog = load_json(CATALOG_PATH)
        layout = load_json(LAYOUT_PATH)
        catalog_audit = audit_catalog(catalog, layout)
        seed_audit = audit_seeds(catalog, args.audit_seeds)
        assembly = assemble(catalog, args.seed)
        audit_assembly(assembly)
        assembly["audit"] = {
            "catalog": catalog_audit,
            "seeds": seed_audit,
            "unresolved": 0,
        }
        if not args.check_only:
            write_text(OUTPUT_JSON, json.dumps(assembly, indent=2, ensure_ascii=False) + "\n")
            write_text(OUTPUT_SVG, render_svg(catalog, assembly, catalog_audit, seed_audit))
        print(
            "[DREAM-MAZE] PASS: "
            f"{catalog_audit['module_count']} modules, "
            f"{catalog_audit['edge_count']} edges, "
            f"{catalog_audit['hazard_count']} hazards, "
            f"{catalog_audit['source_check_count']} source checks"
        )
        print(
            "[DREAM-MAZE] SEEDS: "
            f"{seed_audit['seeds_checked']}/{seed_audit['seeds_checked']} deterministic, "
            f"{seed_audit['unique_structures']} seed-independent structures, 0 unresolved"
        )
        print(f"[DREAM-MAZE] CANONICAL: seed {args.seed} {assembly['meta']['assembly_sha256']}")
        if args.check_only:
            print("[DREAM-MAZE] check-only: no outputs written")
        else:
            print(f"[DREAM-MAZE] wrote {os.path.relpath(OUTPUT_JSON, ROOT)}")
            print(f"[DREAM-MAZE] wrote {os.path.relpath(OUTPUT_SVG, ROOT)}")
        return 0
    except (AuditError, KeyError, TypeError, ValueError, OSError, json.JSONDecodeError) as error:
        print(f"[DREAM-MAZE] FAIL: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
