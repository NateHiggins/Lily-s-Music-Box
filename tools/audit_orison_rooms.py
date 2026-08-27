#!/usr/bin/env python3
"""Inventory Orison rooms and flag placement records needing human review.

This is deliberately read-only.  The layout JSON is generated; corrections belong
in art/data/gen_layout.py, followed by regeneration.  The audit is conservative:
it reports uncertainty rather than pretending that an assembly without a footprint
has precise collision geometry.
"""

from __future__ import annotations

import argparse
import json
import math
from collections import Counter, defaultdict
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_LAYOUT = ROOT / "game/data/building_layout.json"
PLAYER_RADIUS = 0.33
DOOR_MARGIN = 0.08


def inside(point, rect, pad=0.0):
    x, y = point
    return (rect[0] - pad <= x <= rect[2] + pad
            and rect[1] - pad <= y <= rect[3] + pad)


def centre(rect):
    return ((float(rect[0]) + float(rect[2])) * 0.5,
            (float(rect[1]) + float(rect[3])) * 0.5)


def overlaps(a, b):
    return a[0] < b[2] and b[0] < a[2] and a[1] < b[3] and b[1] < a[3]


def door_sweep(marker):
    """Return a conservative square enclosing a 90-degree door swing.

    Door positions are hinge jambs.  A square intentionally over-reports the
    quarter-circle corners; every result is a review candidate, not a verdict.
    """
    x, y, _ = marker["pos"]
    w = float(marker.get("w", 0.9)) + PLAYER_RADIUS + DOOR_MARGIN
    yaw = int(round(float(marker.get("yaw_deg", 0.0)))) % 360
    if yaw == 0:
        return [x - DOOR_MARGIN, y - w, x + w, y + w]
    if yaw == 180:
        return [x - w, y - w, x + DOOR_MARGIN, y + w]
    if yaw in (90, 270):
        return [x - w, y - DOOR_MARGIN, x + w, y + w]
    return [x - w, y - w, x + w, y + w]


def object_point(record):
    if "rect" in record:
        return centre(record["rect"])
    if "at" in record and len(record["at"]) >= 2:
        return float(record["at"][0]), float(record["at"][1])
    if "pos" in record and len(record["pos"]) >= 2:
        return float(record["pos"][0]), float(record["pos"][1])
    return None


def best_room(point, rooms):
    candidates = [room for room in rooms if inside(point, room["rect"], 0.001)]
    if not candidates:
        return None
    # MAIN envelopes intentionally overlap their internal rooms.  Prefer the
    # smallest region because it communicates the more precise purpose.
    return min(candidates, key=lambda room:
               (room["rect"][2] - room["rect"][0])
               * (room["rect"][3] - room["rect"][1]))


def wall_near_misses(walls):
    endpoints = []
    for index, wall in enumerate(walls):
        endpoints.extend([(index, tuple(map(float, wall["a"]))),
                          (index, tuple(map(float, wall["b"])))])
    found = []
    for i, (wa, pa) in enumerate(endpoints):
        nearest = None
        for wb, pb in endpoints[i + 1:]:
            if wa == wb:
                continue
            d = math.dist(pa, pb)
            if 0.012 < d <= 0.30 and (nearest is None or d < nearest[0]):
                nearest = (d, wb, pb)
        if nearest:
            found.append((wa, nearest[1], nearest[0], pa, nearest[2]))
    # Endpoint pairs appear from both directions in dense junctions.
    unique = {}
    for wa, wb, dist, pa, pb in found:
        key = tuple(sorted((wa, wb)))
        if key not in unique or dist < unique[key][0]:
            unique[key] = (dist, pa, pb)
    return [(key[0], key[1], *value) for key, value in sorted(unique.items())]


def audit(layout):
    result = []
    for floor in layout["floors"]:
        rooms = floor.get("rooms", [])
        assigned = defaultdict(list)
        unassigned = []
        for category in ("furniture", "markers", "sockets", "vent_registers"):
            for record in floor.get(category, []):
                point = object_point(record)
                if point is None:
                    unassigned.append((category, record.get("id", "?"), "no-position"))
                    continue
                room = best_room(point, rooms)
                item = (category, record)
                if room:
                    assigned[room["id"]].append(item)
                else:
                    unassigned.append((category, record.get("id", "?"), point))

        door_hits = []
        doors = [m for m in floor.get("markers", []) if m.get("kind") == "door"]
        rect_furniture = [f for f in floor.get("furniture", []) if "rect" in f]
        for door in doors:
            sweep = door_sweep(door)
            for furniture in rect_furniture:
                if overlaps(sweep, furniture["rect"]):
                    door_hits.append((door.get("id", "?"), furniture.get("id", "?")))

        art = [f for f in floor.get("furniture", [])
               if f.get("mat") == "art" or "_art" in f.get("id", "")]
        frames = [f for f in floor.get("furniture", [])
                  if "artf" in f.get("id", "") or "frame" in f.get("id", "")]
        result.append({
            "id": floor["id"], "rooms": rooms, "assigned": assigned,
            "unassigned": unassigned, "doors": doors, "door_hits": door_hits,
            "near_misses": wall_near_misses(floor.get("walls", [])),
            "art_count": len(art), "frame_count": len(frames),
        })
    return result


def render(results):
    lines = [
        "# Orison object-level spatial census",
        "",
        "Generated read-only from `game/data/building_layout.json`. Candidates are",
        "questions for visual inspection, not automatic deletion or relocation orders.",
        "Door sweeps use deliberately conservative envelopes.", "",
    ]
    for floor in results:
        lines += [f"## {floor['id']}", "",
                  f"- Rooms: {len(floor['rooms'])}; doors: {len(floor['doors'])}; "
                  f"unassigned records: {len(floor['unassigned'])}",
                  f"- Art faces: {floor['art_count']}; frame-like records: "
                  f"{floor['frame_count']}",
                  f"- Conservative door-sweep candidates: {len(floor['door_hits'])}",
                  f"- Wall endpoint near-misses (12–300 mm): "
                  f"{len(floor['near_misses'])}", "",
                  "| Room | Kind | Unit | Records | Assemblies | Rect parts | Purpose status |",
                  "|---|---|---:|---:|---:|---:|---|" ]
        for room in floor["rooms"]:
            items = floor["assigned"].get(room["id"], [])
            furniture = [r for cat, r in items if cat == "furniture"]
            assemblies = sum("asm" in r for r in furniture)
            rects = sum("rect" in r for r in furniture)
            purpose = "NEEDS PROFILE" if room.get("kind", "") in ("", "unknown") else "kind only"
            lines.append("| {id} | {kind} | {unit} | {count} | {asm} | {rects} | {purpose} |".format(
                id=room["id"], kind=room.get("kind", "?"), unit=room.get("unit", "—"),
                count=len(items), asm=assemblies, rects=rects, purpose=purpose))
        lines.append("")
        if floor["near_misses"]:
            lines += ["### Wall endpoint candidates", ""]
            for wa, wb, dist, pa, pb in floor["near_misses"][:40]:
                lines.append(f"- walls {wa}/{wb}: {dist:.3f} m between {pa} and {pb}")
            lines.append("")
        if floor["door_hits"]:
            lines += ["### Door-sweep candidates", ""]
            for door, obj in floor["door_hits"][:80]:
                lines.append(f"- `{door}` ↔ `{obj}`")
            lines.append("")
        kinds = Counter(reason for _, _, reason in floor["unassigned"] if isinstance(reason, str))
        if floor["unassigned"]:
            lines += ["### Outside every declared room / unresolved", ""]
            for category, object_id, reason in floor["unassigned"][:80]:
                lines.append(f"- `{category}` `{object_id}`: {reason}")
            if kinds:
                lines.append(f"- no-position summary: {dict(kinds)}")
            lines.append("")
    return "\n".join(lines) + "\n"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--layout", type=Path, default=DEFAULT_LAYOUT)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    layout = json.loads(args.layout.read_text(encoding="utf-8"))
    report = render(audit(layout))
    if args.output:
        args.output.write_text(report, encoding="utf-8")
        print(args.output)
    else:
        print(report, end="")


if __name__ == "__main__":
    main()
