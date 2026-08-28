#!/usr/bin/env python3
"""Read-only per-room layout workbench for the Orison.

Converts the authoritative building-layout JSON into per-room visual plans
(self-contained HTML/SVG) and machine/human-readable room packets, so a room
can be inspected and designed granularly without opening Blender or Godot.

The tool never writes production data.  Every drawn or reported fact carries a
tier so an uncertain estimate is never presented as exact:

  exact      read directly from the layout JSON (rects, wall segments, door
             markers, marker positions, pipe axes).
  inferred   derived from assembly metadata or engine constants (ASM_FOOT
             half-extents mirrored from art/data/gen_layout.py, DoorProp's
             100-degree swing, fridge/stove stand bands).
  heuristic  workbench analysis (circulation paths, occupancy estimates,
             near-miss endpoints, detritus zones).  Questions, not verdicts.
  unknown    the source exposes no footprint or position; reported, not drawn
             as geometry.

2D limitations vs Blender/Godot truth are documented in
design/ROOM_LAYOUT_WORKBENCH_GUIDE.md.

Usage:
  python tools/room_layout_workbench.py --room F01_COMMON_B --output OUT_DIR
  python tools/room_layout_workbench.py --floor F01 --output OUT_DIR
  python tools/room_layout_workbench.py --list-rooms
  python tools/room_layout_workbench.py --room X --output D --json-only
  python tools/room_layout_workbench.py --compare other_layout.json --room X
  python tools/room_layout_workbench.py --room X --output D --detritus
"""

from __future__ import annotations

import argparse
import ast
import html
import json
import math
import sys
from collections import defaultdict
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audit_orison_rooms as audit  # noqa: E402  (shared read-only helpers)

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_LAYOUT = ROOT / "art/data/building_layout.json"
GEN_LAYOUT_PATH = ROOT / "art/data/gen_layout.py"
DESIGN_DIR = ROOT / "design"

PLAYER_RADIUS = audit.PLAYER_RADIUS          # 0.33 m capsule
BODY_DIAMETER = 0.66                         # local interaction envelope
ROUTE_WIDTH = 0.80                           # primary circulation gate
DOOR_OPEN_DEG = 100.0                        # door_prop.gd interactive swing
DOOR_PARKED_DEG = 168.0                      # door_prop.gd leaf_state "open"
GRID = 0.08                                  # analysis cell size, metres

EXACT, INFERRED, HEURISTIC, UNKNOWN = "exact", "inferred", "heuristic", "unknown"

DETRITUS_CATEGORIES = (
    "swept-clean", "ordinary lived-in", "active work surface",
    "neglected edge", "service residue", "resident-specific personal accumulation")

WORK_SURFACE_ASMS = ("desk", "table_rect", "table_round", "kitchen", "workbench",
                     "coffee", "bench")


def fnum(value):
    """Round for stable, non-false-precision output."""
    return round(float(value) + 0.0, 3)


def fpt(point):
    return [fnum(point[0]), fnum(point[1])]


def frect(rect):
    return [fnum(v) for v in rect]


# ---------------------------------------------------------------------------
# Assembly footprint metadata (mirrored from gen_layout.py without executing it)
# ---------------------------------------------------------------------------

_TABLE_NAMES = ("ASM_FOOT", "FRIDGE_FOOT", "STOVE_FOOT", "BATH_SINK_FOOT",
                "SHOWER_FOOT", "BOXFAN_FOOT")


def load_footprint_tables(gen_path=GEN_LAYOUT_PATH):
    """Extract the generator's footprint tables by parsing, never executing.

    Returns {"ok": bool, "note": str, <table name lowercased>: value}.
    On any failure the tables are simply absent and every assembly footprint
    degrades to `unknown` rather than being invented here.
    """
    tables = {"ok": False, "note": ""}
    try:
        tree = ast.parse(gen_path.read_text(encoding="utf-8"))
    except (OSError, SyntaxError) as exc:
        tables["note"] = f"could not parse {gen_path.name}: {exc}"
        return tables
    for node in ast.walk(tree):
        if not isinstance(node, ast.Assign) or len(node.targets) != 1:
            continue
        target = node.targets[0]
        if isinstance(target, ast.Name) and target.id in _TABLE_NAMES:
            try:
                tables[target.id.lower()] = ast.literal_eval(node.value)
            except ValueError:
                pass
    missing = [n for n in _TABLE_NAMES if n.lower() not in tables]
    tables["ok"] = not missing
    tables["note"] = ("mirrored from art/data/gen_layout.py"
                      if tables["ok"] else
                      f"tables missing from gen_layout.py: {missing}")
    return tables


def asm_aabb(record, tables):
    """Mirror of gen_layout._asm_aabb.  Returns (aabb, note) or (None, why)."""
    kind = record.get("asm")
    foot = tables.get("asm_foot") or {}
    if kind not in foot:
        return None, f"assembly kind '{kind}' has no footprint table entry"
    hx, hy = foot[kind]
    if kind == "table_rect":
        hx, hy = record.get("L", 1.2) / 2.0 + 0.05, record.get("W", 0.8) / 2.0 + 0.05
    elif kind == "sofa":
        hx = record.get("L", 1.95) / 2.0 + 0.18
    elif kind == "kitchen":
        hx = record.get("L", 2.5) / 2.0 - 0.375 + 0.03
    elif kind == "shelf":
        hx = record.get("W", 1.1) / 2.0 + 0.02
    elif kind == "bench":
        hx = record.get("L", 1.5) / 2.0 + 0.02
    note = "half-extents from ASM_FOOT"
    yaw = record.get("yaw", 0) % 180
    if yaw == 90:
        hx, hy = hy, hx
    elif yaw not in (0, 90):
        hx = hy = max(hx, hy)
        note += "; free-rotated, safe square"
    cx, cy = record["at"]
    return (cx - hx, cy - hy, cx + hx, cy + hy), note


def marker_aabb(marker, tables):
    """Mirror of gen_layout._obstacles for marker-built obstacles."""
    kind = marker.get("kind")
    if kind == "fridge" and "fridge_foot" in tables:
        hx, hy = tables["fridge_foot"][bool(marker.get("monitor", False))]
    elif kind == "stove" and "stove_foot" in tables:
        hx, hy = tables["stove_foot"]
    elif kind == "boxfan" and "boxfan_foot" in tables:
        hx, hy = tables["boxfan_foot"]
    elif marker.get("fixture") == "bath_sink" and "bath_sink_foot" in tables:
        hx, hy = tables["bath_sink_foot"]
    elif marker.get("fixture") == "shower" and "shower_foot" in tables:
        hx, hy = tables["shower_foot"]
    else:
        return None
    yaw = float(marker.get("yaw_deg", 0)) % 180
    if yaw == 90:
        hx, hy = hy, hx
    elif yaw not in (0, 90):
        hx = hy = max(hx, hy)
    cx, cy = marker["pos"][0], marker["pos"][1]
    return (cx - hx, cy - hy, cx + hx, cy + hy)


# ---------------------------------------------------------------------------
# Plain geometry
# ---------------------------------------------------------------------------

def rect_overlap_area(a, b):
    w = min(a[2], b[2]) - max(a[0], b[0])
    h = min(a[3], b[3]) - max(a[1], b[1])
    return w * h if w > 0 and h > 0 else 0.0


def rect_gap(a, b):
    """Smallest separation between two AABBs (0 when they touch/overlap)."""
    dx = max(a[0] - b[2], b[0] - a[2], 0.0)
    dy = max(a[1] - b[3], b[1] - a[3], 0.0)
    return math.hypot(dx, dy)


def point_rect_dist(px, py, rect):
    dx = max(rect[0] - px, 0.0, px - rect[2])
    dy = max(rect[1] - py, 0.0, py - rect[3])
    return math.hypot(dx, dy)


def point_seg_dist(px, py, ax, ay, bx, by):
    vx, vy = bx - ax, by - ay
    ln2 = vx * vx + vy * vy
    if ln2 <= 1e-12:
        return math.hypot(px - ax, py - ay)
    t = max(0.0, min(1.0, ((px - ax) * vx + (py - ay) * vy) / ln2))
    return math.hypot(px - (ax + vx * t), py - (ay + vy * t))


def plan_dir(yaw_deg):
    """Hinge-to-latch direction in plan for an authored yaw (gen_layout
    convention: Blender yaw is the opposite sign from Godot around Y)."""
    a = math.radians(yaw_deg)
    return math.cos(a), -math.sin(a)


def inflate(rect, pad):
    return (rect[0] - pad, rect[1] - pad, rect[2] + pad, rect[3] + pad)


# ---------------------------------------------------------------------------
# Record interpretation
# ---------------------------------------------------------------------------

def pipe_plan_segment(record):
    """Plan-space axis of a pipe record.  Returns ((x0,y0),(x1,y1), tier)."""
    p0, p1 = record["p0"], record["p1"]
    if record.get("local"):
        ax, ay = record.get("at", (0.0, 0.0))
        yaw = float(record.get("yaw", 0.0))
        if yaw:
            dx, dy = plan_dir(yaw)
            def rot(p):
                return (ax + p[0] * dx - p[1] * dy, ay + p[0] * dy + p[1] * dx)
            return rot(p0), rot(p1), INFERRED
        return (ax + p0[0], ay + p0[1]), (ax + p1[0], ay + p1[1]), EXACT
    return (p0[0], p0[1]), (p1[0], p1[1]), EXACT


def interpret_record(category, record, tables):
    """Classify one placement record into drawable, tiered plan geometry.

    Returns a dict:
      id, category, point, shape ('rect'|'aabb'|'segment'|'point'|None),
      geom, tier, blocking, note, raw metadata echoes.
    """
    rid = record.get("id", "?")
    out = {
        "id": rid, "category": category,
        "asm": record.get("asm"), "mat": record.get("mat"),
        "yaw": record.get("yaw", record.get("yaw_deg")),
        "z0": record.get("z0"), "h": record.get("h"),
        "point": None, "shape": None, "geom": None,
        "tier": UNKNOWN, "blocking": False, "note": "",
    }
    if record.get("asm") == "pipe" and "p0" in record and "p1" in record:
        a, b, tier = pipe_plan_segment(record)
        out.update(point=((a[0] + b[0]) / 2.0, (a[1] + b[1]) / 2.0),
                   shape="segment", geom=(a, b, float(record.get("r", 0.02))),
                   tier=tier, note="pipe axis; movement-exempt in the generator")
        return out
    if category == "furniture" and "rect" in record:
        r = [float(v) for v in record["rect"]]
        z0, h = float(record.get("z0", 0.0)), float(record.get("h", 1.0))
        blocking = not (z0 >= 1.9 or h <= 0.30) and not record.get("nocol")
        note = "rect part"
        if z0 >= 1.9:
            note += "; overhead (z0>=1.9), not a movement obstacle"
        elif h <= 0.30:
            note += "; floor-level trim/rug (h<=0.30), not a movement obstacle"
        if record.get("nocol"):
            note += "; nocol"
        out.update(point=audit.centre(r), shape="rect", geom=tuple(r),
                   tier=EXACT, blocking=blocking, note=note)
        return out
    if category == "furniture" and "asm" in record:
        if record["asm"] == "switch":
            out.update(point=tuple(record["at"]), shape="point",
                       geom=tuple(record["at"]), tier=EXACT,
                       note="wall switch; movement-exempt")
            return out
        bb, note = asm_aabb(record, tables)
        pt = audit.object_point(record)
        if bb is None:
            out.update(point=pt, shape="point" if pt else None,
                       geom=pt, tier=UNKNOWN, note=note)
            return out
        out.update(point=pt, shape="aabb", geom=bb, tier=INFERRED,
                   blocking=True, note=note)
        return out
    if category == "markers":
        bb = marker_aabb(record, tables)
        pt = audit.object_point(record)
        if bb is not None:
            out.update(point=pt, shape="aabb", geom=bb, tier=INFERRED,
                       blocking=True,
                       note="marker obstacle footprint (generator tables)")
            return out
        note = f"marker '{record.get('kind', '?')}'; no footprint in layout"
        if record.get("kind") == "radiator":
            note = (f"radiator, {record.get('sections', '?')} sections, riser "
                    f"{record.get('riser', '?')}; dimensions not in layout")
        out.update(point=pt, shape="point" if pt else None, geom=pt,
                   tier=EXACT if pt else UNKNOWN, note=note)
        return out
    pt = audit.object_point(record)
    if pt is None:
        out["note"] = "record exposes no position"
        return out
    out.update(point=pt, shape="point", geom=pt, tier=EXACT,
               note={"sockets": "authored socket anchor",
                     "vent_registers": "ventilation register",
                     "vantry_points": "vantry point",
                     "bookshelves": "gameplay bookshelf owner"}.get(category, ""))
    return out


# ---------------------------------------------------------------------------
# Doors
# ---------------------------------------------------------------------------

def door_view(marker, rooms):
    """Full plan geometry for one door marker.

    Hinge is the marker position (see gen_layout collect_door_markers).  The
    interactive leaf sweeps 100 degrees (door_prop.gd); 'swing: out' reverses
    it.  A parked-open leaf rests at 168 degrees.
    """
    hx, hy = float(marker["pos"][0]), float(marker["pos"][1])
    w = float(marker.get("w", 0.9))
    yaw = float(marker.get("yaw_deg", 0.0))
    out = str(marker.get("swing", "")) == "out"
    sign = 1.0 if not out else -1.0

    def leaf_point(sweep_deg):
        a = math.radians(yaw - sign * sweep_deg)
        return (hx + math.cos(a) * w, hy - math.sin(a) * w)

    arc = [leaf_point(DOOR_OPEN_DEG * i / 20.0) for i in range(21)]
    dx, dy = plan_dir(yaw)
    centre = (hx + dx * w * 0.5, hy + dy * w * 0.5)
    nx, ny = -dy, dx
    adjacent = []
    for side in (-1, 1):
        px, py = centre[0] + nx * 0.34 * side, centre[1] + ny * 0.34 * side
        hits = sorted((r for r in rooms
                       if r["rect"][0] <= px <= r["rect"][2]
                       and r["rect"][1] <= py <= r["rect"][3]),
                      key=lambda r: ((r["rect"][2] - r["rect"][0])
                                     * (r["rect"][3] - r["rect"][1])))
        adjacent.append(hits[0]["id"] if hits else None)
    latch = (hx + dx * w, hy + dy * w)
    service = (hx + dx * (w + 0.34), hy + dy * (w + 0.34))
    return {
        "id": marker.get("id", "?"),
        "hinge": (hx, hy), "latch": latch, "centre": centre,
        "width": w, "yaw_deg": yaw,
        "leaf": marker.get("leaf", "closed"),
        "swing": "out" if out else "default",
        "subtype": marker.get("subtype", ""),
        "unit": marker.get("unit", ""),
        "rooms_field": list(marker.get("rooms", [])),
        "adjacent_rooms": adjacent,        # [-normal side, +normal side]
        "normal": (nx, ny),
        "arc": arc,                        # inferred: DoorProp 100-degree swing
        "parked_open": leaf_point(DOOR_PARKED_DEG),
        "sweep_rect": audit.door_sweep(marker),   # heuristic envelope
        "service_point": service,          # resident_nav latch-side stand
    }


def door_touches_room(door, room):
    if room["id"] in door["rooms_field"] or room["id"] in door["adjacent_rooms"]:
        return True
    rect = inflate(room["rect"], 0.12)
    return (audit.inside(door["hinge"], rect) or audit.inside(door["centre"], rect)
            or audit.inside(door["latch"], rect))


# ---------------------------------------------------------------------------
# Room profile discovery (design/*.md, read-only)
# ---------------------------------------------------------------------------

def find_room_profiles(room_id, design_dir=DESIGN_DIR):
    """Design docs that mention this room; excerpt any '## Room profile'."""
    results = []
    if not design_dir.is_dir():
        return results
    for path in sorted(design_dir.rglob("*.md")):
        try:
            text = path.read_text(encoding="utf-8")
        except OSError:
            continue
        if room_id not in text:
            continue
        entry = {"path": str(path.relative_to(ROOT)).replace("\\", "/"),
                 "profile_excerpt": None}
        lines = text.splitlines()
        for i, line in enumerate(lines):
            if line.lower().startswith("##") and "room profile" in line.lower():
                j = i + 1
                while j < len(lines) and not lines[j].startswith("## "):
                    j += 1
                section = "\n".join(lines[i + 1:j]).strip()
                if room_id in section:
                    entry["profile_excerpt"] = section[:1600]
                    break
        results.append(entry)
    return results


# ---------------------------------------------------------------------------
# Room view assembly
# ---------------------------------------------------------------------------

def wall_in_scope(wall, rect):
    pad = float(wall.get("t", 0.18)) / 2.0 + 0.05
    r = inflate(rect, pad)
    ax, ay = wall["a"]
    bx, by = wall["b"]
    wr = (min(ax, bx), min(ay, by), max(ax, bx), max(ay, by))
    return audit.overlaps(inflate(wr, pad), r) or audit.inside((ax, ay), r) \
        or audit.inside((bx, by), r)


def wall_openings(wall, index):
    """Positioned openings of one wall (gen_layout: `at` measures the opening
    centre from the low endpoint along the wall axis)."""
    ax, ay = wall["a"]
    bx, by = wall["b"]
    horizontal = abs(by - ay) < 1e-6
    start = min(ax, bx) if horizontal else min(ay, by)
    cross = ay if horizontal else ax
    out = []
    for o in wall.get("openings", []):
        c = start + float(o["at"])
        half = float(o["w"]) / 2.0
        if horizontal:
            a, b = (c - half, cross), (c + half, cross)
        else:
            a, b = (cross, c - half), (cross, c + half)
        out.append({"wall": index, "type": o.get("type", "?"), "a": a, "b": b,
                    "w": float(o["w"]), "sill": o.get("sill"),
                    "h": o.get("h"), "leaf": o.get("leaf"),
                    "alcove": bool(o.get("decorative_alcove"))})
    return out


def ownership_of(point, geometry, room, rooms):
    """Ownership classification for a record relative to `room`."""
    containing = sorted(
        (r for r in rooms if audit.inside(point, r["rect"], 0.001)),
        key=lambda r: ((r["rect"][2] - r["rect"][0])
                       * (r["rect"][3] - r["rect"][1])))
    chosen = containing[0]["id"] if containing else None
    ambiguous = False
    if len(containing) >= 2:
        a0 = ((containing[0]["rect"][2] - containing[0]["rect"][0])
              * (containing[0]["rect"][3] - containing[0]["rect"][1]))
        a1 = ((containing[1]["rect"][2] - containing[1]["rect"][0])
              * (containing[1]["rect"][3] - containing[1]["rect"][1]))
        ambiguous = a1 < a0 * 1.25   # nearly-equal candidates, not envelope
    crosses = False
    if geometry and len(geometry) == 4 and isinstance(geometry, tuple):
        rr = room["rect"]
        crosses = (geometry[0] < rr[0] - 0.03 or geometry[1] < rr[1] - 0.03
                   or geometry[2] > rr[2] + 0.03 or geometry[3] > rr[3] + 0.03)
    return {
        "assigned_room": chosen,
        "containing_rooms": [r["id"] for r in containing],
        "ambiguous": ambiguous,
        "crosses_room_boundary": crosses,
    }


def collect_room_view(layout, room_id, tables):
    floor = room = None
    for fl in layout["floors"]:
        for r in fl.get("rooms", []):
            if r["id"] == room_id:
                floor, room = fl, r
                break
        if room:
            break
    if room is None:
        raise KeyError(f"room id not found in layout: {room_id}")
    rooms = floor.get("rooms", [])
    rect = [float(v) for v in room["rect"]]
    scope = inflate(rect, 0.60)

    walls, openings = [], []
    for i, w in enumerate(floor.get("walls", [])):
        if wall_in_scope(w, rect):
            walls.append({"index": i, "a": tuple(map(float, w["a"])),
                          "b": tuple(map(float, w["b"])),
                          "t": float(w.get("t", 0.18)),
                          "mat": w.get("mat", "")})
            openings.extend(wall_openings(w, i))

    near = [n for n in audit.wall_near_misses(floor.get("walls", []))
            if audit.inside(n[3], scope) or audit.inside(n[4], scope)]

    doors = []
    for m in floor.get("markers", []):
        if m.get("kind") != "door":
            continue
        d = door_view(m, rooms)
        if door_touches_room(d, room):
            doors.append(d)
    doors.sort(key=lambda d: d["id"])

    objects = []
    per_floor = [("furniture", floor.get("furniture", [])),
                 ("markers", [m for m in floor.get("markers", [])
                              if m.get("kind") != "door"]),
                 ("sockets", floor.get("sockets", [])),
                 ("vent_registers", floor.get("vent_registers", []))]
    top_level = [("vantry_points", layout.get("vantry_points", [])),
                 ("bookshelves", layout.get("bookshelves", []))]
    for category, records in per_floor + top_level:
        for record in records:
            if category in ("vantry_points",):
                if record.get("room") != room_id:
                    continue
            elif category == "bookshelves":
                if not str(record.get("id", "")).startswith(floor["id"] + "_"):
                    continue
            view = interpret_record(category, record, tables)
            if view["point"] is None:
                if category in ("vantry_points", "bookshelves"):
                    objects.append(dict(view, ownership={
                        "assigned_room": room_id, "containing_rooms": [room_id],
                        "ambiguous": False, "crosses_room_boundary": False}))
                continue
            own = ownership_of(view["point"], view["geom"]
                               if view["shape"] in ("rect", "aabb") else None,
                               room, rooms)
            in_room = own["assigned_room"] == room_id
            overlapping = False
            if not in_room and view["shape"] in ("rect", "aabb"):
                overlapping = rect_overlap_area(view["geom"], rect) > 0.001
            if not in_room and view["shape"] == "segment":
                a, b, _ = view["geom"]
                overlapping = (audit.inside(a, rect) or audit.inside(b, rect))
            if category == "vantry_points":
                in_room = True
            if not (in_room or overlapping):
                continue
            view["ownership"] = own
            view["relation"] = "assigned" if in_room else "overlapping"
            objects.append(view)
    objects.sort(key=lambda o: (o["category"], o["id"]))

    no_position = []
    for category, records in per_floor:
        for record in records:
            if audit.object_point(record) is None and "p0" not in record:
                no_position.append((category, record.get("id", "?")))

    stairs_overlap = [s["id"] for s in layout.get("stairs", [])
                      if audit.overlaps(tuple(map(float, s["well"])), tuple(rect))]
    elevator = layout.get("elevator") or {}
    elevator_overlap = bool(elevator.get("shaft")) and audit.overlaps(
        tuple(map(float, elevator["shaft"])), tuple(rect))
    holes = []
    for slab in floor.get("slabs", []):
        for h in slab.get("holes", []):
            if audit.overlaps(tuple(map(float, h)), tuple(rect)):
                holes.append([float(v) for v in h])

    art, frames = art_frame_pairs(objects)
    return {
        "layout_meta": layout.get("meta", {}),
        "floor": floor, "room": room, "rect": rect, "rooms": rooms,
        "walls": walls, "openings": openings, "near_misses": near,
        "doors": doors, "objects": objects, "no_position": sorted(no_position),
        "stairs_overlap": sorted(stairs_overlap),
        "elevator_overlap": elevator_overlap, "slab_holes": holes,
        "art": art, "frames": frames,
        "profiles": find_room_profiles(room_id),
        "tables_note": tables.get("note", ""),
    }


def art_frame_pairs(objects):
    """Heuristic id-stem pairing of art faces and frame parts (census rules)."""
    art, frames = {}, {}
    for o in objects:
        rid = o["id"]
        if o["category"] != "furniture":
            continue
        if "artf" in rid or "frame" in rid:
            stem = rid.split("artf")[0] if "artf" in rid else rid.split("frame")[0]
            frames.setdefault(stem.rstrip("_"), []).append(rid)
        elif o.get("mat") == "art" or "_art" in rid:
            stem = rid.split("_art")[0]
            art.setdefault(stem, []).append(rid)
    art_out = [{"stem": s, "faces": sorted(v),
                "frames": sorted(frames.get(s, [])),
                "status": "paired" if s in frames else "face without frame-like part"}
               for s, v in sorted(art.items())]
    frame_out = [{"stem": s, "frames": sorted(v),
                  "faces": sorted(art.get(s, [])),
                  "status": "paired" if s in art else "frame without traced art face"}
                 for s, v in sorted(frames.items())]
    return art_out, frame_out


# ---------------------------------------------------------------------------
# Grid analysis: occupancy, clearance, circulation
# ---------------------------------------------------------------------------

class RoomGrid:
    def __init__(self, view):
        rect = view["rect"]
        pad = 0.40
        self.x0, self.y0 = rect[0] - pad, rect[1] - pad
        self.x1, self.y1 = rect[2] + pad, rect[3] + pad
        self.nx = max(2, int(math.ceil((self.x1 - self.x0) / GRID)))
        self.ny = max(2, int(math.ceil((self.y1 - self.y0) / GRID)))
        self.rect = rect

    def cell_center(self, i, j):
        return (self.x0 + (i + 0.5) * GRID, self.y0 + (j + 0.5) * GRID)

    def index_of(self, x, y):
        i = int((x - self.x0) / GRID)
        j = int((y - self.y0) / GRID)
        if 0 <= i < self.nx and 0 <= j < self.ny:
            return i, j
        return None


def analyze_room(view):
    """Occupancy, clearance and circulation.  All results heuristic."""
    grid = RoomGrid(view)
    rect = view["rect"]
    blockers = [(o["id"], o["geom"]) for o in view["objects"]
                if o["blocking"] and o["shape"] in ("rect", "aabb")]
    hard_zones = [("stair_well", tuple(h)) for h in view["slab_holes"]]

    opening_spans = []
    for op in view["openings"]:
        if op["type"] == "door" or (op["type"] == "window" and not op["sill"]):
            opening_spans.append(op)

    def near_wall(x, y, pad):
        for w in view["walls"]:
            d = point_seg_dist(x, y, *w["a"], *w["b"])
            if d <= w["t"] / 2.0 + pad:
                clear = False
                for op in opening_spans:
                    if op["wall"] == w["index"] and \
                            point_seg_dist(x, y, *op["a"], *op["b"]) <= op["w"] / 2.0 + pad:
                        clear = True
                        break
                if not clear:
                    return True
        return False

    free = bytearray(grid.nx * grid.ny)
    occupied_cells = furnished_cells = room_cells = 0
    for j in range(grid.ny):
        for i in range(grid.nx):
            x, y = grid.cell_center(i, j)
            in_room = rect[0] <= x <= rect[2] and rect[1] <= y <= rect[3]
            if in_room:
                room_cells += 1
                hit_block = any(g[0] <= x <= g[2] and g[1] <= y <= g[3]
                                for _, g in blockers + hard_zones)
                if hit_block:
                    occupied_cells += 1
                    furnished_cells += 1
                else:
                    for o in view["objects"]:
                        if not o["blocking"] and o["shape"] == "rect":
                            g = o["geom"]
                            if g[0] <= x <= g[2] and g[1] <= y <= g[3]:
                                furnished_cells += 1
                                break
            walkable = not near_wall(x, y, PLAYER_RADIUS)
            if walkable:
                for _, g in blockers + hard_zones:
                    if point_rect_dist(x, y, g) < PLAYER_RADIUS:
                        walkable = False
                        break
            near = inflate(rect, 0.38)
            if walkable and (near[0] <= x <= near[2] and near[1] <= y <= near[3]):
                free[j * grid.nx + i] = 1

    clearance = {}
    for j in range(grid.ny):
        for i in range(grid.nx):
            if not free[j * grid.nx + i]:
                continue
            x, y = grid.cell_center(i, j)
            c = 2.0
            for _, g in blockers + hard_zones:
                c = min(c, point_rect_dist(x, y, g))
                if c <= 0.0:
                    break
            for w in view["walls"]:
                dw = point_seg_dist(x, y, *w["a"], *w["b"]) - w["t"] / 2.0
                spans = [op for op in opening_spans if op["wall"] == w["index"]]
                if dw < c and not any(
                        point_seg_dist(x, y, *op["a"], *op["b"]) <= op["w"] / 2.0
                        for op in spans):
                    c = max(0.0, min(c, dw))
            clearance[(i, j)] = c

    anchor = None
    for (i, j), c in sorted(clearance.items(), key=lambda kv: (-kv[1], kv[0][1], kv[0][0])):
        x, y = grid.cell_center(i, j)
        if rect[0] <= x <= rect[2] and rect[1] <= y <= rect[3]:
            anchor = (i, j)
            break

    def door_start(door):
        for side in (1, -1):
            nx_, ny_ = door["normal"]
            px = door["centre"][0] + nx_ * 0.45 * side
            py = door["centre"][1] + ny_ * 0.45 * side
            if rect[0] <= px <= rect[2] and rect[1] <= py <= rect[3]:
                cell = grid.index_of(px, py)
                if cell and free[cell[1] * grid.nx + cell[0]]:
                    return cell
                if cell:
                    best, bd = None, 1e9
                    for (ci, cj) in clearance:
                        d = abs(ci - cell[0]) + abs(cj - cell[1])
                        if d < bd:
                            best, bd = (ci, cj), d
                    if best and bd <= 6:
                        return best
        return None

    def bfs_path(src, dst):
        if src is None or dst is None:
            return None
        prev = {src: None}
        queue = [src]
        head = 0
        while head < len(queue):
            cur = queue[head]
            head += 1
            if cur == dst:
                break
            ci, cj = cur
            for di, dj in ((1, 0), (-1, 0), (0, 1), (0, -1),
                           (1, 1), (1, -1), (-1, 1), (-1, -1)):
                nxt = (ci + di, cj + dj)
                if nxt in prev or nxt not in clearance:
                    continue
                prev[nxt] = cur
                queue.append(nxt)
        if dst not in prev:
            return None
        path, cur = [], dst
        while cur is not None:
            path.append(cur)
            cur = prev[cur]
        path.reverse()
        return path

    def simplify(path):
        if not path:
            return None
        pts = [grid.cell_center(*c) for c in path]
        out = [pts[0]]
        for k in range(1, len(pts) - 1):
            ax, ay = out[-1]
            bx, by = pts[k]
            cx, cy = pts[k + 1]
            if abs((bx - ax) * (cy - ay) - (by - ay) * (cx - ax)) > 1e-9:
                out.append(pts[k])
        out.append(pts[-1])
        return out

    routes = []
    starts = {d["id"]: door_start(d) for d in view["doors"]}
    for d in view["doors"]:
        path = bfs_path(starts[d["id"]], anchor)
        entry = {"from": d["id"], "to": "room_anchor", "reachable": path is not None,
                 "min_passage_width": None, "polyline": None}
        if path:
            entry["min_passage_width"] = fnum(2.0 * min(clearance[c] for c in path))
            entry["polyline"] = [fpt(p) for p in simplify(path)]
        routes.append(entry)
    ids = sorted(starts)
    for a in range(len(ids)):
        for b in range(a + 1, len(ids)):
            path = bfs_path(starts[ids[a]], starts[ids[b]])
            entry = {"from": ids[a], "to": ids[b], "reachable": path is not None,
                     "min_passage_width": None, "polyline": None}
            if path:
                entry["min_passage_width"] = fnum(2.0 * min(clearance[c] for c in path))
                entry["polyline"] = [fpt(p) for p in simplify(path)]
            routes.append(entry)

    room_area = (rect[2] - rect[0]) * (rect[3] - rect[1])
    return {
        "grid": grid, "free": free, "clearance": clearance,
        "anchor": grid.cell_center(*anchor) if anchor else None,
        "routes": routes,
        "room_area_m2": fnum(room_area),
        "occupied_ratio": fnum(occupied_cells / room_cells) if room_cells else None,
        "furnished_ratio": fnum(furnished_cells / room_cells) if room_cells else None,
        "min_route_width": min((r["min_passage_width"] for r in routes
                                if r["min_passage_width"] is not None),
                               default=None),
        "grid_note": (f"grid analysis at {GRID:.2f} m cells with the 0.33 m "
                      "player radius; estimates, not collision truth"),
    }


# ---------------------------------------------------------------------------
# Findings
# ---------------------------------------------------------------------------

def find_intersections(view):
    """Pairwise footprint overlaps and near-intersections inside the room."""
    boxes = [o for o in view["objects"] if o["shape"] in ("rect", "aabb")]
    out = []
    for a in range(len(boxes)):
        for b in range(a + 1, len(boxes)):
            oa, ob = boxes[a], boxes[b]
            ga, gb = oa["geom"], ob["geom"]
            depth = rect_overlap_area(ga, gb)
            gap = rect_gap(ga, gb)
            if depth > 1e-4:
                kind = "intersection"
            elif gap < 0.05:
                kind = "near-intersection"
            else:
                continue
            tier = EXACT if oa["tier"] == EXACT and ob["tier"] == EXACT else HEURISTIC
            soft = not (oa["blocking"] and ob["blocking"])
            note = ""
            if soft:
                note = ("involves a non-blocking part (rug/trim/overhead); may be "
                        "intentional layering")
            elif "chair" in (oa.get("asm"), ob.get("asm")):
                note = ("chair-tuck overlap of worst-case ASM_FOOT extents; "
                        "often intentional seating")
            out.append({
                "kind": kind, "a": oa["id"], "b": ob["id"],
                "overlap_m2": fnum(depth), "gap_m": fnum(gap),
                "basis": ("both 2D AABBs exact" if tier == EXACT
                          else "at least one AABB inferred from assembly metadata"),
                "soft": soft,
                "note": note,
            })
    out.sort(key=lambda f: (f["kind"], f["a"], f["b"]))
    return out


def find_door_findings(view):
    out = []
    for d in view["doors"]:
        sweep = d["sweep_rect"]
        for o in view["objects"]:
            if not o["blocking"] or o["shape"] not in ("rect", "aabb"):
                continue
            if audit.overlaps(sweep, o["geom"]):
                out.append({"door": d["id"], "object": o["id"],
                            "kind": "conservative-sweep-candidate",
                            "basis": "audit door_sweep square; over-reports corners"})
    out.sort(key=lambda f: (f["door"], f["object"]))
    return out


# ---------------------------------------------------------------------------
# Detritus advisor (advisory only)
# ---------------------------------------------------------------------------

def detritus_zones(view, analysis):
    """Conservative candidate zones for environmental clutter.

    Never places objects.  Zones are eligible free floor after removing every
    protective exclusion; categories are gated on the room kind (exact) and,
    for resident-specific accumulation, on an actual room profile.
    """
    grid = analysis["grid"]
    rect = view["rect"]
    kind = view["room"].get("kind", "")
    unit = view["room"].get("unit")
    residents = view["layout_meta"].get("residents", {})
    resident = residents.get(unit) if unit else None
    has_profile = any(p["profile_excerpt"] for p in view["profiles"])

    exclusions = []
    for d in view["doors"]:
        exclusions.append(("door swing + approach of " + d["id"],
                           inflate(d["sweep_rect"], 0.05)))
        sp = d["service_point"]
        exclusions.append(("latch-side service stand of " + d["id"],
                           (sp[0] - 0.30, sp[1] - 0.30, sp[0] + 0.30, sp[1] + 0.30)))
    for r in analysis["routes"]:
        if not r["polyline"]:
            continue
        for k in range(len(r["polyline"]) - 1):
            (x0, y0), (x1, y1) = r["polyline"][k], r["polyline"][k + 1]
            hw = ROUTE_WIDTH / 2.0
            exclusions.append((f"circulation {r['from']}->{r['to']}",
                               (min(x0, x1) - hw, min(y0, y1) - hw,
                                max(x0, x1) + hw, max(y0, y1) + hw)))
    for o in view["objects"]:
        if o["category"] == "markers" and o["point"]:
            x, y = o["point"]
            kind_m = (o.get("note") or "")
            band = None
            if o["id"].endswith("_RADIATOR_01") or "radiator" in kind_m:
                band = 0.45
                why = "radiator service access"
            elif o["shape"] == "aabb":     # stove/fridge/sink/shower feet
                band = 0.72
                why = "appliance/fixture stand and leaf sweep"
            elif "sink" in kind_m or "switch" in kind_m:
                band = 0.40
                why = "fixture approach"
            if band:
                exclusions.append((f"{why} ({o['id']})",
                                   (x - band, y - band, x + band, y + band)))
        if o["category"] == "furniture" and o["shape"] in ("rect", "aabb") \
                and o["blocking"]:
            if o.get("asm") in WORK_SURFACE_ASMS + ("chair", "bed", "toilet",
                                                    "wardrobe", "sofa", "couch",
                                                    "nightstand"):
                exclusions.append((f"use position of {o['id']}",
                                   inflate(o["geom"], 0.40)))
    for op in view["openings"]:
        if op["type"] == "window":
            cx = (op["a"][0] + op["b"][0]) / 2.0
            cy = (op["a"][1] + op["b"][1]) / 2.0
            exclusions.append(("window approach / focal sightline",
                               (cx - 0.45, cy - 0.45, cx + 0.45, cy + 0.45)))

    # Eligibility is NOT walkability: clutter lives against skirting boards
    # where the player capsule cannot.  A cell is eligible when it is real
    # floor (not wall fabric, not inside a blocking footprint) and inside no
    # protective exclusion.
    blockers = [o["geom"] for o in view["objects"]
                if o["blocking"] and o["shape"] in ("rect", "aabb")]
    blockers += [tuple(h) for h in view["slab_holes"]]
    eligible = {}
    for j in range(grid.ny):
        for i in range(grid.nx):
            x, y = grid.cell_center(i, j)
            if not (rect[0] <= x <= rect[2] and rect[1] <= y <= rect[3]):
                continue
            if any(point_seg_dist(x, y, *w["a"], *w["b"]) <= w["t"] / 2.0 + 0.03
                   for w in view["walls"]):
                continue
            if any(point_rect_dist(x, y, g) < 0.03 for g in blockers):
                continue
            if any(g[0] <= x <= g[2] and g[1] <= y <= g[3] for _, g in exclusions):
                continue
            eligible[(i, j)] = True

    zones_cells = []
    seen = set()
    for cell in sorted(eligible):
        if cell in seen:
            continue
        comp, queue = [], [cell]
        seen.add(cell)
        while queue:
            cur = queue.pop()
            comp.append(cur)
            ci, cj = cur
            for di, dj in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nxt = (ci + di, cj + dj)
                if nxt in eligible and nxt not in seen:
                    seen.add(nxt)
                    queue.append(nxt)
        if len(comp) * GRID * GRID >= 0.15:
            zones_cells.append(comp)
    zones_cells.sort(key=lambda c: (-len(c), c[0]))

    def wall_edge_share(cells):
        edge = 0
        for (i, j) in cells:
            x, y = grid.cell_center(i, j)
            if any(point_seg_dist(x, y, *w["a"], *w["b"]) <= w["t"] / 2.0 + 0.35
                   for w in view["walls"]):
                edge += 1
        return edge / len(cells)

    named_resident = bool(resident) and resident not in (
        "supporting", "PLAYER") and not str(resident).startswith(("vacant", "sealed"))

    def categories_for(edge_share):
        cats = []
        if kind in ("lobby", "corridor", "hall", "atrium", "vestibule", "office"):
            cats.append(("swept-clean", "circulation-facing room kind "
                         f"'{kind}' (exact); zone clear of all protected areas"))
        if edge_share >= 0.6:
            cats.append(("neglected edge", "zone hugs the wall line "
                         f"({edge_share:.0%} of cells within 0.35 m of a wall)"))
        if kind in ("living", "common", "bedroom", "kitchen", "office", "alcove"):
            cats.append(("ordinary lived-in", f"domestic room kind '{kind}' (exact)"))
        if kind in ("utility", "boiler", "electrical", "laundry", "storage",
                    "storage_cages", "coal"):
            cats.append(("service residue", f"service room kind '{kind}' (exact)"))
        if named_resident:
            if has_profile:
                cats.append(("resident-specific personal accumulation",
                             f"unit {unit} resident '{resident}' (exact) and a "
                             "written room profile exists"))
            else:
                cats.append(("resident-specific personal accumulation",
                             "PURPOSE REQUIRED: named resident exists but no "
                             "room profile text found under design/"))
        return cats

    density = {
        "swept-clean": "0 items; the zone is valuable empty",
        "neglected edge": "1-3 small items (<=0.15 m tall) per metre of edge",
        "ordinary lived-in": "0.5-1.5 small items per m2, none on the route side",
        "service residue": "1-2 items clustered within 0.4 m of the service",
        "resident-specific personal accumulation":
            "profile-driven; do not author without the profile",
    }
    zones = []
    for n, cells in enumerate(zones_cells[:6]):
        xs = [grid.cell_center(i, j)[0] for i, j in cells]
        ys = [grid.cell_center(i, j)[1] for i, j in cells]
        bbox = (min(xs) - GRID / 2, min(ys) - GRID / 2,
                max(xs) + GRID / 2, max(ys) + GRID / 2)
        edge_share = wall_edge_share(cells)
        cats = categories_for(edge_share)
        zones.append({
            "zone": f"Z{n}",
            "bbox": frect(bbox),
            "area_m2": fnum(len(cells) * GRID * GRID),
            "wall_edge_share": fnum(edge_share),
            "categories": [{"category": c, "eligibility": why,
                            "density_envelope": density.get(c, "")}
                           for c, why in cats] or
                          [{"category": None,
                            "eligibility": "purpose required: room kind "
                            f"'{kind}' supports no detritus category without a "
                            "written profile", "density_envelope": ""}],
            "protecting_exclusions": sorted({name for name, g in exclusions
                                             if rect_gap(g, bbox) < 0.25}),
            "tier": HEURISTIC,
            "cells": cells,
        })

    surfaces = []
    for o in view["objects"]:
        if o.get("asm") in WORK_SURFACE_ASMS and o["shape"] in ("rect", "aabb"):
            if kind in ("kitchen", "office", "living", "common", "storage"):
                surfaces.append({
                    "object": o["id"], "category": "active work surface",
                    "eligibility": f"work surface assembly '{o['asm']}' in room "
                                   f"kind '{kind}' (exact)",
                    "density_envelope": "2-5 small items per m2 of surface top; "
                                        "keep the floor beneath untouched",
                    "tier": HEURISTIC})
    surfaces.sort(key=lambda s: s["object"])
    return {"zones": zones, "surfaces": surfaces,
            "exclusion_count": len(exclusions),
            "note": ("advisory only: categories and density envelopes, never "
                     "placed production objects; every zone already excludes "
                     "door swings, circulation, interaction approaches, "
                     "service access, furniture use positions and window "
                     "sightlines")}


# ---------------------------------------------------------------------------
# Packet emission
# ---------------------------------------------------------------------------

def build_packet(view, analysis, detritus=None):
    room = view["room"]
    doors = []
    for d in view["doors"]:
        doors.append({
            "id": d["id"], "hinge": fpt(d["hinge"]), "latch": fpt(d["latch"]),
            "width_m": fnum(d["width"]), "yaw_deg": fnum(d["yaw_deg"]),
            "leaf": d["leaf"], "swing": d["swing"], "subtype": d["subtype"],
            "unit": d["unit"] or None,
            "connects": d["rooms_field"] or [r for r in d["adjacent_rooms"] if r],
            "swing_arc": {"tier": INFERRED,
                          "basis": "DoorProp 100-degree interactive swing"},
            "clearance_envelope": {"rect": frect(d["sweep_rect"]),
                                   "tier": HEURISTIC,
                                   "basis": "conservative audit square"},
        })
    objects = []
    for o in view["objects"]:
        geom = None
        if o["shape"] in ("rect", "aabb"):
            geom = frect(o["geom"])
        elif o["shape"] == "segment":
            a, b, r = o["geom"]
            geom = {"a": fpt(a), "b": fpt(b), "radius_m": fnum(r)}
        elif o["shape"] == "point":
            geom = fpt(o["geom"])
        entry = {
            "id": o["id"], "category": o["category"],
            "assembly": o.get("asm"), "material": o.get("mat"),
            "position": fpt(o["point"]) if o["point"] else None,
            "yaw_deg": fnum(o["yaw"]) if o.get("yaw") is not None else None,
            "footprint": {"shape": o["shape"], "geometry": geom,
                          "tier": o["tier"], "note": o["note"]},
            "blocking": o["blocking"],
            "ownership": o.get("ownership"),
            "relation": o.get("relation", "assigned"),
            "verdict": None,
        }
        objects.append(entry)
    findings = {
        "wall_endpoint_near_misses": [
            {"walls": [wa, wb], "distance_m": fnum(dist),
             "a": fpt(pa), "b": fpt(pb), "tier": HEURISTIC}
            for wa, wb, dist, pa, pb in view["near_misses"]],
        "door_sweep_candidates": find_door_findings(view),
        "intersections": find_intersections(view),
        "boundary_crossers": sorted(o["id"] for o in view["objects"]
                                    if o.get("ownership", {}).get(
                                        "crosses_room_boundary")),
        "ambiguous_ownership": sorted(o["id"] for o in view["objects"]
                                      if o.get("ownership", {}).get("ambiguous")),
    }
    unresolved = []
    for o in view["objects"]:
        if o["tier"] == UNKNOWN:
            unresolved.append(f"{o['id']}: {o['note']} - needs visual inspection")
    for cat, rid in view["no_position"]:
        unresolved.append(f"{cat} {rid}: record exposes no position")
    for o in view["objects"]:
        if o["category"] == "markers" and o["shape"] == "point" \
                and "radiator" in (o["note"] or ""):
            unresolved.append(f"{o['id']}: radiator footprint depth/width not in "
                              "layout; check against the built prop")
    if view["near_misses"]:
        unresolved.append("wall endpoint near-misses require checking the "
                          "generator and a camera angle before being called gaps")
    unresolved.sort()

    packet = {
        "workbench": {
            "source_layout": "building_layout.json (read-only)",
            "assembly_tables": view["tables_note"],
            "fact_tiers": {"exact": "read from layout JSON",
                           "inferred": "assembly metadata / engine constants",
                           "heuristic": "workbench analysis; questions not verdicts",
                           "unknown": "not derivable from the layout"},
            "limitations": "2D plan inference; see design/ROOM_LAYOUT_WORKBENCH_GUIDE.md",
        },
        "room": {
            "id": room["id"], "floor": view["floor"]["id"],
            "kind": room.get("kind"), "unit": room.get("unit"),
            "resident": view["layout_meta"].get("residents", {}).get(
                room.get("unit", "")),
            "rect": frect(view["rect"]),
            "dimensions_m": [fnum(view["rect"][2] - view["rect"][0]),
                             fnum(view["rect"][3] - view["rect"][1])],
            "area_m2": analysis["room_area_m2"],
            "profiles": view["profiles"],
            "profile_status": ("profile text found" if any(
                p["profile_excerpt"] for p in view["profiles"])
                else "kind only - purpose required"),
        },
        "entrances": doors,
        "windows": [{"wall": op["wall"], "a": fpt(op["a"]), "b": fpt(op["b"]),
                     "w": fnum(op["w"]), "sill": op["sill"],
                     "alcove": op["alcove"], "tier": EXACT}
                    for op in view["openings"] if op["type"] == "window"],
        "objects": objects,
        "art_faces": view["art"],
        "frames": view["frames"],
        "measures": {
            "occupied_area_ratio": analysis["occupied_ratio"],
            "furnished_area_ratio": analysis["furnished_ratio"],
            "min_route_width_m": analysis["min_route_width"],
            "routes": analysis["routes"],
            "basis": analysis["grid_note"],
            "tier": HEURISTIC,
        },
        "findings": findings,
        "unresolved": unresolved,
        "verdict_schema": {
            "allowed": ["KEEP", "MOVE", "REPAIR", "REPLACE", "REMOVE"],
            "note": "fill per object above; ADD proposals belong here",
            "additions": [],
        },
        "structure": {
            "stairs_overlap": view["stairs_overlap"],
            "elevator_overlap": view["elevator_overlap"],
            "slab_holes": [frect(h) for h in view["slab_holes"]],
        },
    }
    if detritus is not None:
        packet["detritus_advisory"] = {
            "note": detritus["note"],
            "zones": [{k: v for k, v in z.items() if k != "cells"}
                      for z in detritus["zones"]],
            "surfaces": detritus["surfaces"],
        }
    return packet


def packet_markdown(packet):
    r = packet["room"]
    lines = [f"# Room packet: {r['id']} ({packet['room']['floor']})", ""]
    lines += [f"- Kind: `{r['kind']}`; unit: `{r['unit'] or '-'}`; resident: "
              f"{r['resident'] or '-'}",
              f"- Rect: {r['rect']}  ({r['dimensions_m'][0]} x "
              f"{r['dimensions_m'][1]} m, {r['area_m2']} m2)",
              f"- Profile status: {r['profile_status']}", ""]
    for p in r["profiles"]:
        lines.append(f"- Mentioned in `{p['path']}`"
                     + (" (profile excerpt below)" if p["profile_excerpt"] else ""))
    for p in r["profiles"]:
        if p["profile_excerpt"]:
            lines += ["", "## Room profile (quoted, read-only)", "",
                      "> " + p["profile_excerpt"].replace("\n", "\n> "), ""]
    lines += ["", "## Entrances", ""]
    for d in packet["entrances"]:
        lines.append(f"- `{d['id']}` {d['subtype']}; w={d['width_m']} m; "
                     f"leaf={d['leaf']}; swing={d['swing']}; connects "
                     f"{', '.join(d['connects']) or '?'}")
    lines += ["", "## Measures (heuristic)", "",
              f"- Occupied-area ratio (blocking footprints): "
              f"{packet['measures']['occupied_area_ratio']}",
              f"- Furnished-area ratio (incl. rugs/trim): "
              f"{packet['measures']['furnished_area_ratio']}",
              f"- Minimum apparent passage width on computed routes: "
              f"{packet['measures']['min_route_width_m']} m "
              f"(gate: {ROUTE_WIDTH} m primary, {BODY_DIAMETER} m local)",
              f"- Basis: {packet['measures']['basis']}", ""]
    lines += ["## Objects", "",
              "| ID | Cat | Asm/Mat | Pos | Yaw | Footprint | Tier | Relation "
              "| Verdict |", "|---|---|---|---|---|---|---|---|---|"]
    for o in packet["objects"]:
        fp = o["footprint"]
        if fp["shape"] in ("rect", "aabb"):
            g = fp["geometry"]
            size = f"{fnum(g[2] - g[0])} x {fnum(g[3] - g[1])} m"
        elif fp["shape"] == "segment":
            size = "pipe axis"
        elif fp["shape"] == "point":
            size = "point"
        else:
            size = "UNKNOWN"
        own = o["ownership"] or {}
        rel = o["relation"]
        if own.get("ambiguous"):
            rel += " AMBIGUOUS"
        if own.get("crosses_room_boundary"):
            rel += " CROSSES-BOUNDARY"
        lines.append(
            f"| `{o['id']}` | {o['category']} | "
            f"{o['assembly'] or o['material'] or '-'} | "
            f"{o['position']} | {o['yaw_deg'] if o['yaw_deg'] is not None else '-'} "
            f"| {size} | {fp['tier']} | {rel} | _ |")
    lines += ["", "## Findings", ""]
    f = packet["findings"]
    lines.append(f"- Wall endpoint near-misses: {len(f['wall_endpoint_near_misses'])}")
    for n in f["wall_endpoint_near_misses"]:
        lines.append(f"  - walls {n['walls'][0]}/{n['walls'][1]}: "
                     f"{n['distance_m']} m between {n['a']} and {n['b']}")
    lines.append(f"- Conservative door-sweep candidates: "
                 f"{len(f['door_sweep_candidates'])}")
    for c in f["door_sweep_candidates"]:
        lines.append(f"  - `{c['door']}` <-> `{c['object']}`")
    lines.append(f"- Footprint intersections/near-intersections: "
                 f"{len(f['intersections'])}")
    for c in f["intersections"]:
        soft = " (soft)" if c["soft"] else ""
        lines.append(f"  - {c['kind']}{soft}: `{c['a']}` / `{c['b']}` "
                     f"overlap {c['overlap_m2']} m2, gap {c['gap_m']} m "
                     f"[{c['basis']}]")
    lines.append(f"- Boundary crossers: {', '.join(f['boundary_crossers']) or 'none'}")
    lines.append(f"- Ambiguous ownership: "
                 f"{', '.join(f['ambiguous_ownership']) or 'none'}")
    lines += ["", "## Art and frames (heuristic id pairing)", ""]
    for a in packet["art_faces"]:
        lines.append(f"- face `{a['stem']}`: {a['status']}")
    for a in packet["frames"]:
        lines.append(f"- frame `{a['stem']}`: {a['status']}")
    if not packet["art_faces"] and not packet["frames"]:
        lines.append("- none traced in this room")
    lines += ["", "## Unresolved facts (need visual inspection)", ""]
    for u in packet["unresolved"]:
        lines.append(f"- {u}")
    if not packet["unresolved"]:
        lines.append("- none recorded")
    if "detritus_advisory" in packet:
        det = packet["detritus_advisory"]
        lines += ["", "## Detritus advisory (categories only, never placements)",
                  "", f"> {det['note']}", ""]
        for z in det["zones"]:
            lines.append(f"- **{z['zone']}** bbox {z['bbox']}, {z['area_m2']} m2, "
                         f"edge share {z['wall_edge_share']}")
            for c in z["categories"]:
                cat = c["category"] or "(none)"
                lines.append(f"  - {cat}: {c['eligibility']}")
                if c["density_envelope"]:
                    lines.append(f"    - density: {c['density_envelope']}")
            if z["protecting_exclusions"]:
                lines.append("  - protected by: "
                             + "; ".join(z["protecting_exclusions"][:6]))
        for s in det["surfaces"]:
            lines.append(f"- surface `{s['object']}`: {s['category']} - "
                         f"{s['density_envelope']}")
    lines += ["", "## Verdict placeholders", "",
              "Allowed: KEEP / MOVE / REPAIR / REPLACE / REMOVE per object; "
              "ADD via `verdict_schema.additions`.  This packet never alters "
              "production data.", ""]
    return "\n".join(lines)


# ---------------------------------------------------------------------------
# SVG / HTML rendering
# ---------------------------------------------------------------------------

SVG_CSS = """
body{font:14px/1.45 system-ui,sans-serif;margin:16px;background:#fafafa;color:#222}
h1{font-size:20px}.meta{color:#555;max-width:72em}
.controls{margin:10px 0}.controls label{margin-right:14px;user-select:none}
svg{background:#fff;border:1px solid #ccc}
.legend{display:flex;flex-wrap:wrap;gap:14px;margin:10px 0;font-size:13px}
.legend span{display:inline-flex;align-items:center;gap:6px}
.key{display:inline-block;width:26px;height:12px;border:2px solid}
table{border-collapse:collapse;font-size:12px;margin-top:14px}
td,th{border:1px solid #ccc;padding:2px 7px;text-align:left}
.plan{overflow:auto;max-width:100%}
"""

SVG_SCRIPT = """
document.querySelectorAll('.controls input').forEach(function (cb) {
  function apply() {
    document.querySelectorAll('.layer-' + cb.dataset.layer).forEach(
      function (g) { g.style.display = cb.checked ? '' : 'none'; });
  }
  cb.addEventListener('change', apply);
  apply();
});
"""

LAYERS = [("arch", "architecture", True), ("exact", "exact footprints", True),
          ("inferred", "inferred footprints", True),
          ("unknown", "unknown-footprint markers", True),
          ("services", "services/anchors", True),
          ("clear", "clearance envelopes", True),
          ("routes", "circulation (heuristic)", True),
          ("findings", "findings", True), ("labels", "labels", False),
          ("detritus", "detritus zones (advisory)", False)]


def render_room_html(view, analysis, detritus=None):
    rect = view["rect"]
    margin = 1.0
    x0, y0 = rect[0] - margin, rect[1] - margin
    x1, y1 = rect[2] + margin, rect[3] + margin
    span_x, span_y = x1 - x0, y1 - y0
    scale = max(60.0, min(150.0, 1250.0 / span_x, 900.0 / span_y))
    pad = 34
    W, H = span_x * scale + 2 * pad, span_y * scale + 2 * pad

    def X(x):
        return round(pad + (x - x0) * scale, 1)

    def Y(y):
        return round(pad + (y1 - y) * scale, 1)

    def R(r):
        return (f'x="{X(r[0])}" y="{Y(r[3])}" '
                f'width="{round((r[2] - r[0]) * scale, 1)}" '
                f'height="{round((r[3] - r[1]) * scale, 1)}"')

    def esc(s):
        return html.escape(str(s), quote=True)

    parts = []
    # grid + axes
    parts.append('<g class="layer-arch" stroke="#eee" stroke-width="1">')
    gx = math.ceil(x0)
    while gx <= x1:
        parts.append(f'<line x1="{X(gx)}" y1="{Y(y0)}" x2="{X(gx)}" y2="{Y(y1)}"/>')
        parts.append(f'<text x="{X(gx)}" y="{Y(y0) + 14}" fill="#999" '
                     f'stroke="none" font-size="9" text-anchor="middle">{gx}</text>')
        gx += 1
    gy = math.ceil(y0)
    while gy <= y1:
        parts.append(f'<line x1="{X(x0)}" y1="{Y(gy)}" x2="{X(x1)}" y2="{Y(gy)}"/>')
        parts.append(f'<text x="{X(x0) - 4}" y="{Y(gy) + 3}" fill="#999" '
                     f'stroke="none" font-size="9" text-anchor="end">{gy}</text>')
        gy += 1
    parts.append('</g>')

    # room boundary + slab holes + stairs/elevator
    parts.append('<g class="layer-arch">')
    parts.append(f'<rect {R(rect)} fill="none" stroke="#7a99b8" '
                 'stroke-width="1.5" stroke-dasharray="10,4">'
                 f'<title>room rect {frect(rect)} (exact)</title></rect>')
    for h in view["slab_holes"]:
        parts.append(f'<rect {R(h)} fill="url(#hatch)" stroke="#888" '
                     f'stroke-width="1"><title>slab hole (stair/shaft) '
                     f'{frect(h)} (exact)</title></rect>')
    # walls
    for w in view["walls"]:
        sw = max(1.5, w["t"] * scale)
        parts.append(f'<line x1="{X(w["a"][0])}" y1="{Y(w["a"][1])}" '
                     f'x2="{X(w["b"][0])}" y2="{Y(w["b"][1])}" stroke="#3a3a3a" '
                     f'stroke-width="{sw:.1f}" stroke-linecap="butt">'
                     f'<title>wall {w["index"]} t={w["t"]} mat={esc(w["mat"])} '
                     f'(exact)</title></line>')
    # openings drawn over walls
    for op in view["openings"]:
        color = "#4a7bd0" if op["type"] == "window" else "#fff"
        parts.append(f'<line x1="{X(op["a"][0])}" y1="{Y(op["a"][1])}" '
                     f'x2="{X(op["b"][0])}" y2="{Y(op["b"][1])}" '
                     f'stroke="{color}" stroke-width="5">'
                     f'<title>{op["type"]} on wall {op["wall"]} w={op["w"]}'
                     f'{" sill=" + str(op["sill"]) if op["sill"] is not None else ""}'
                     f'{" decorative alcove" if op["alcove"] else ""} (exact)'
                     f'</title></line>')
    parts.append('</g>')

    # doors: leaf, arc, hinge
    parts.append('<g class="layer-arch">')
    for d in view["doors"]:
        hx, hy = d["hinge"]
        lx, ly = d["latch"]
        arc = d["arc"]
        arc_pts = " ".join(f"{X(px)},{Y(py)}" for px, py in arc)
        parts.append(f'<polyline points="{arc_pts}" fill="rgba(90,160,90,0.12)" '
                     'stroke="#5aa05a" stroke-width="1" stroke-dasharray="5,3">'
                     f'<title>{d["id"]} swing arc {DOOR_OPEN_DEG:.0f} deg '
                     f'({d["swing"]}) - inferred from DoorProp</title></polyline>')
        parts.append(f'<line x1="{X(hx)}" y1="{Y(hy)}" x2="{X(lx)}" y2="{Y(ly)}" '
                     'stroke="#2c7a2c" stroke-width="3">'
                     f'<title>{d["id"]} closed leaf w={d["width"]} leaf='
                     f'{d["leaf"]} subtype={d["subtype"]} (exact)</title></line>')
        parts.append(f'<circle cx="{X(hx)}" cy="{Y(hy)}" r="3.5" fill="#2c7a2c">'
                     f'<title>{d["id"]} hinge (exact)</title></circle>')
        if d["leaf"] == "open":
            px, py = d["parked_open"]
            parts.append(f'<line x1="{X(hx)}" y1="{Y(hy)}" x2="{X(px)}" '
                         f'y2="{Y(py)}" stroke="#2c7a2c" stroke-width="2" '
                         f'stroke-dasharray="3,3"><title>{d["id"]} parked open '
                         f'at {DOOR_PARKED_DEG:.0f} deg (inferred)</title></line>')
    parts.append('</g>')

    # clearance envelopes
    parts.append('<g class="layer-clear">')
    for d in view["doors"]:
        parts.append(f'<rect {R(d["sweep_rect"])} fill="none" stroke="#b3823c" '
                     'stroke-width="1" stroke-dasharray="2,4">'
                     f'<title>{d["id"]} conservative clearance envelope '
                     '(heuristic; over-reports corners)</title></rect>')
        sp = d["service_point"]
        parts.append(f'<path d="M {X(sp[0]) - 4} {Y(sp[1])} h 8 M {X(sp[0])} '
                     f'{Y(sp[1]) - 4} v 8" stroke="#b3823c" stroke-width="1.2" '
                     f'fill="none"><title>{d["id"]} latch-side service stand '
                     '(inferred from resident_nav)</title></path>')
    parts.append('</g>')

    # object footprints
    tier_style = {
        EXACT: ('rgba(43,74,111,0.16)', '#2b4a6f', 'none'),
        INFERRED: ('rgba(214,138,0,0.14)', '#b06a00', '6,3'),
    }
    lab = []
    for o in view["objects"]:
        title = (f"{o['id']} [{o['category']}"
                 + (f"/{o['asm']}" if o.get("asm") else "")
                 + (f" mat={o['mat']}" if o.get("mat") else "")
                 + f"] tier={o['tier']}"
                 + (" BLOCKING" if o["blocking"] else "")
                 + (f" - {o['note']}" if o["note"] else ""))
        own = o.get("ownership") or {}
        if own.get("crosses_room_boundary"):
            title += " | CROSSES ROOM BOUNDARY"
        if own.get("ambiguous"):
            title += f" | AMBIGUOUS OWNERSHIP {own['containing_rooms']}"
        if o["shape"] in ("rect", "aabb"):
            fill, stroke, dash = tier_style[EXACT if o["shape"] == "rect"
                                            else INFERRED]
            if not o["blocking"]:
                fill = 'rgba(43,74,111,0.06)'
            layer = "exact" if o["shape"] == "rect" else "inferred"
            dashattr = f' stroke-dasharray="{dash}"' if dash != 'none' else ""
            extra = ""
            if own.get("crosses_room_boundary") or own.get("ambiguous"):
                extra = ' style="outline:1px dotted #b3003c"'
            parts.append(f'<g class="layer-{layer}"><rect {R(o["geom"])} '
                         f'fill="{fill}" stroke="{stroke}" stroke-width="1.2"'
                         f'{dashattr}{extra}><title>{esc(title)}</title></rect></g>')
            cx, cy = audit.centre(o["geom"])
            lab.append((cx, cy, o["id"]))
        elif o["shape"] == "segment":
            a, b, r = o["geom"]
            swr = max(1.0, 2 * r * scale)
            parts.append(f'<g class="layer-services"><line x1="{X(a[0])}" '
                         f'y1="{Y(a[1])}" x2="{X(b[0])}" y2="{Y(b[1])}" '
                         f'stroke="#7d7d7d" stroke-width="{swr:.1f}" '
                         f'stroke-linecap="round" opacity="0.7">'
                         f'<title>{esc(title)}</title></line></g>')
        elif o["shape"] == "point" and o["tier"] != UNKNOWN:
            x, y = o["geom"]
            glyph_color = "#6a5acd" if o["category"] != "furniture" else "#2b4a6f"
            parts.append(f'<g class="layer-services"><circle cx="{X(x)}" '
                         f'cy="{Y(y)}" r="3" fill="none" stroke="{glyph_color}" '
                         f'stroke-width="1.4"><title>{esc(title)}</title>'
                         '</circle></g>')
            lab.append((x, y, o["id"]))
        else:
            pt = o["point"]
            if pt:
                parts.append(f'<g class="layer-unknown"><circle cx="{X(pt[0])}" '
                             f'cy="{Y(pt[1])}" r="6" fill="none" stroke="#c22" '
                             f'stroke-width="1.5"/><text x="{X(pt[0])}" '
                             f'y="{Y(pt[1]) + 3.5}" font-size="9" fill="#c22" '
                             f'text-anchor="middle">?<title>{esc(title)}</title>'
                             '</text></g>')
                lab.append((pt[0], pt[1], o["id"]))

    # findings overlays (intersections are listed in the packet table;
    # drawing every pair would bury the plan)
    parts.append('<g class="layer-findings">')
    for wa, wb, dist, pa, pb in view["near_misses"]:
        parts.append(f'<circle cx="{X((pa[0] + pb[0]) / 2)}" '
                     f'cy="{Y((pa[1] + pb[1]) / 2)}" r="7" fill="none" '
                     'stroke="#b3003c" stroke-width="1.4" stroke-dasharray="2,2">'
                     f'<title>walls {wa}/{wb} endpoints {dist:.3f} m apart '
                     '(heuristic near-miss)</title></circle>')
    parts.append('</g>')

    # routes
    parts.append('<g class="layer-routes">')
    if analysis["anchor"]:
        ax, ay = analysis["anchor"]
        parts.append(f'<circle cx="{X(ax)}" cy="{Y(ay)}" r="4" fill="#3b6fd4" '
                     'opacity="0.8"><title>room anchor (widest clearance cell, '
                     'heuristic)</title></circle>')
    for r in analysis["routes"]:
        if not r["polyline"]:
            continue
        pts = " ".join(f"{X(px)},{Y(py)}" for px, py in r["polyline"])
        parts.append(f'<polyline points="{pts}" fill="none" stroke="#3b6fd4" '
                     'stroke-width="2" stroke-dasharray="1,5" '
                     'stroke-linecap="round" opacity="0.8">'
                     f'<title>route {r["from"]} to {r["to"]}; min width '
                     f'{r["min_passage_width"]} m (heuristic)</title></polyline>')
    parts.append('</g>')

    # detritus zones
    if detritus:
        parts.append('<g class="layer-detritus">')
        for z in detritus["zones"]:
            cats = ", ".join(c["category"] or "purpose required"
                             for c in z["categories"])
            parts.append(f'<rect {R(z["bbox"])} fill="rgba(70,140,70,0.10)" '
                         'stroke="#4a8c4a" stroke-width="1" '
                         'stroke-dasharray="2,3">'
                         f'<title>{z["zone"]} detritus candidate '
                         f'({z["area_m2"]} m2): {esc(cats)} - ADVISORY</title>'
                         '</rect>')
            bx = (z["bbox"][0] + z["bbox"][2]) / 2
            by = (z["bbox"][1] + z["bbox"][3]) / 2
            parts.append(f'<text x="{X(bx)}" y="{Y(by)}" font-size="10" '
                         f'fill="#2e6b2e" text-anchor="middle">{z["zone"]}</text>')
        parts.append('</g>')

    # labels
    parts.append('<g class="layer-labels" font-size="8.5" fill="#333">')
    for x, y, text in sorted(lab, key=lambda t: (t[1], t[0], t[2])):
        parts.append(f'<text x="{X(x)}" y="{Y(y)}" text-anchor="middle">'
                     f'{esc(text)}</text>')
    parts.append('</g>')

    # scale bar
    parts.append(f'<g><line x1="{pad}" y1="{H - 10}" x2="{pad + scale}" '
                 f'y2="{H - 10}" stroke="#222" stroke-width="3"/>'
                 f'<text x="{pad + scale / 2}" y="{H - 15}" font-size="10" '
                 'text-anchor="middle">1 m</text></g>')

    room = view["room"]
    controls = "\n".join(
        f'<input type="checkbox" id="L-{k}" data-layer="{k}"'
        f'{" checked" if on else ""}><label for="L-{k}">{name}</label>'
        for k, name, on in LAYERS)
    legend = """
<div class="legend">
<span><i class="key" style="border-color:#2b4a6f;background:rgba(43,74,111,.16)"></i>exact rect footprint</span>
<span><i class="key" style="border-color:#b06a00;border-style:dashed;background:rgba(214,138,0,.14)"></i>inferred assembly AABB</span>
<span><i class="key" style="border-color:#c22;border-style:dotted"></i>unknown footprint (?)</span>
<span><i class="key" style="border-color:#3a3a3a;background:#3a3a3a"></i>wall</span>
<span><i class="key" style="border-color:#4a7bd0;background:#4a7bd0"></i>window</span>
<span><i class="key" style="border-color:#2c7a2c"></i>door leaf + 100&deg; swing (inferred)</span>
<span><i class="key" style="border-color:#b3823c;border-style:dashed"></i>clearance envelope (heuristic)</span>
<span><i class="key" style="border-color:#3b6fd4;border-style:dotted"></i>circulation route (heuristic)</span>
<span><i class="key" style="border-color:#b3003c;border-style:dotted"></i>finding marker (heuristic)</span>
<span><i class="key" style="border-color:#4a8c4a;border-style:dashed;background:rgba(70,140,70,.10)"></i>detritus candidate (advisory)</span>
</div>"""
    rows = []
    for o in view["objects"]:
        fp_geom = o["geom"]
        if o["shape"] in ("rect", "aabb"):
            size = (f"{fnum(fp_geom[2] - fp_geom[0])} x "
                    f"{fnum(fp_geom[3] - fp_geom[1])}")
        elif o["shape"] == "segment":
            size = "pipe"
        else:
            size = "-" if o["shape"] == "point" else "UNKNOWN"
        rows.append(f"<tr><td>{esc(o['id'])}</td><td>{esc(o['category'])}</td>"
                    f"<td>{esc(o.get('asm') or o.get('mat') or '-')}</td>"
                    f"<td>{fpt(o['point']) if o['point'] else '-'}</td>"
                    f"<td>{esc(o.get('yaw') if o.get('yaw') is not None else '-')}"
                    f"</td><td>{size}</td><td>{o['tier']}</td>"
                    f"<td>{'yes' if o['blocking'] else 'no'}</td>"
                    f"<td>{esc(o['note'] or '')}</td></tr>")
    resident = view["layout_meta"].get("residents", {}).get(room.get("unit", ""))
    return f"""<!doctype html>
<html><head><meta charset="utf-8">
<title>{esc(room['id'])} - room layout workbench</title>
<style>{SVG_CSS}</style></head><body>
<h1>{esc(room['id'])} &mdash; {esc(room.get('kind', '?'))}
{('unit ' + esc(room['unit'])) if room.get('unit') else ''}</h1>
<p class="meta">Floor {esc(view['floor']['id'])} of
{esc(view['layout_meta'].get('name', '?'))}; room rect {frect(rect)} (building
metres, +x east / +y north in plan, y-up on screen).
{('Resident: ' + esc(resident) + '.') if resident else ''}
Read-only workbench output; solid = exact source fact, dashed = inferred from
assembly metadata, dotted = heuristic, red ? = unknown footprint.  Assembly
tables: {esc(view['tables_note'])}.</p>
<div class="controls">{controls}</div>
{legend}
<div class="plan">
<svg xmlns="http://www.w3.org/2000/svg" width="{W:.0f}" height="{H:.0f}"
 viewBox="0 0 {W:.0f} {H:.0f}">
<defs><pattern id="hatch" width="6" height="6" patternUnits="userSpaceOnUse">
<path d="M0,6 L6,0" stroke="#999" stroke-width="1"/></pattern></defs>
{chr(10).join(parts)}
</svg></div>
<table><tr><th>ID</th><th>Category</th><th>Asm/Mat</th><th>Pos</th><th>Yaw</th>
<th>Size (m)</th><th>Tier</th><th>Blocking</th><th>Note</th></tr>
{chr(10).join(rows)}</table>
<script>{SVG_SCRIPT}</script>
</body></html>
"""


# ---------------------------------------------------------------------------
# Compare mode
# ---------------------------------------------------------------------------

def room_object_index(layout, room_id, tables):
    view = collect_room_view(layout, room_id, tables)
    return {o["id"]: o for o in view["objects"]}, view


def compare_room(layout_a, layout_b, room_id, tables):
    lines = [f"## {room_id}"]
    try:
        ia, va = room_object_index(layout_a, room_id, tables)
    except KeyError:
        lines.append("- absent from layout A")
        ia, va = {}, None
    try:
        ib, vb = room_object_index(layout_b, room_id, tables)
    except KeyError:
        lines.append("- absent from layout B")
        ib, vb = {}, None
    added = sorted(set(ib) - set(ia))
    removed = sorted(set(ia) - set(ib))
    for rid in added:
        lines.append(f"- ADDED   `{rid}` at {fpt(ib[rid]['point']) if ib[rid]['point'] else '?'}")
    for rid in removed:
        lines.append(f"- REMOVED `{rid}` was at {fpt(ia[rid]['point']) if ia[rid]['point'] else '?'}")
    for rid in sorted(set(ia) & set(ib)):
        oa, ob = ia[rid], ib[rid]
        if oa["point"] and ob["point"]:
            d = math.dist(oa["point"], ob["point"])
            if d > 0.005:
                lines.append(f"- MOVED   `{rid}` {fpt(oa['point'])} -> "
                             f"{fpt(ob['point'])} ({d:.3f} m)")
        ya, yb = oa.get("yaw"), ob.get("yaw")
        if ya is not None and yb is not None and abs(float(ya) - float(yb)) > 0.5:
            lines.append(f"- ROTATED `{rid}` yaw {ya} -> {yb}")
        if oa["shape"] == "rect" and ob["shape"] == "rect":
            sa = (fnum(oa["geom"][2] - oa["geom"][0]),
                  fnum(oa["geom"][3] - oa["geom"][1]))
            sb = (fnum(ob["geom"][2] - ob["geom"][0]),
                  fnum(ob["geom"][3] - ob["geom"][1]))
            if sa != sb:
                lines.append(f"- RESIZED `{rid}` {sa} -> {sb}")
    if va and vb:
        if len(va["walls"]) != len(vb["walls"]):
            lines.append(f"- walls in scope: {len(va['walls'])} -> {len(vb['walls'])}")
        da = {d["id"] for d in va["doors"]}
        db = {d["id"] for d in vb["doors"]}
        for rid in sorted(db - da):
            lines.append(f"- DOOR ADDED `{rid}`")
        for rid in sorted(da - db):
            lines.append(f"- DOOR REMOVED `{rid}`")
    if len(lines) == 1:
        lines.append("- no per-room differences detected at workbench resolution")
    return "\n".join(lines)


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def list_rooms(layout):
    rows = []
    for fl in layout["floors"]:
        for r in fl.get("rooms", []):
            rect = r["rect"]
            rows.append((fl["id"], r["id"], r.get("kind", "?"),
                         r.get("unit", "-") or "-",
                         f"{rect[2] - rect[0]:.2f} x {rect[3] - rect[1]:.2f}"))
    width = max(len(r[1]) for r in rows)
    out = [f"{'FLOOR':6} {'ROOM':{width}} {'KIND':14} {'UNIT':5} SIZE (m)"]
    for row in rows:
        out.append(f"{row[0]:6} {row[1]:{width}} {row[2]:14} {row[3]:5} {row[4]}")
    return "\n".join(out)


def room_targets(room_id, out_dir, json_only=False, visual_only=False):
    """The exact files one room report would write, in emission order."""
    targets = []
    if not visual_only:
        targets += [out_dir / f"{room_id}.packet.json",
                    out_dir / f"{room_id}.packet.md"]
    if not json_only:
        targets.append(out_dir / f"{room_id}.plan.html")
    return targets


def preflight_overwrite(targets, force=False):
    """Refuse to touch existing generated files unless forced.

    Raises FileExistsError BEFORE anything is written, so a packet is never
    partially emitted over older files.
    """
    existing = [p for p in targets if p.exists()]
    if existing and not force:
        raise FileExistsError(
            "refusing to overwrite existing generated file(s): "
            + ", ".join(str(p) for p in existing)
            + " (pass --force to overwrite)")


def emit_room(layout, room_id, out_dir, tables, json_only=False,
              visual_only=False, detritus_on=False, force=False):
    preflight_overwrite(room_targets(room_id, out_dir, json_only, visual_only),
                        force)
    view = collect_room_view(layout, room_id, tables)
    analysis = analyze_room(view)
    det = detritus_zones(view, analysis) if detritus_on else None
    written = []
    if not visual_only:
        packet = build_packet(view, analysis, det)
        p_json = out_dir / f"{room_id}.packet.json"
        p_json.write_text(json.dumps(packet, indent=1, sort_keys=True) + "\n",
                          encoding="utf-8")
        written.append(p_json)
        p_md = out_dir / f"{room_id}.packet.md"
        p_md.write_text(packet_markdown(packet) + "\n", encoding="utf-8")
        written.append(p_md)
    if not json_only:
        p_html = out_dir / f"{room_id}.plan.html"
        p_html.write_text(render_room_html(view, analysis, det),
                          encoding="utf-8")
        written.append(p_html)
    return written


def main(argv=None):
    parser = argparse.ArgumentParser(
        description="Read-only Orison room layout workbench")
    parser.add_argument("--layout", type=Path, default=DEFAULT_LAYOUT,
                        help="building layout JSON (default art/data copy)")
    parser.add_argument("--room", help="room id, e.g. F01_COMMON_B")
    parser.add_argument("--floor", help="emit every room of one floor")
    parser.add_argument("--list-rooms", action="store_true")
    parser.add_argument("--output", type=Path,
                        help="explicit output directory (required for reports; "
                             "never defaults into tracked directories)")
    parser.add_argument("--json-only", action="store_true")
    parser.add_argument("--visual-only", action="store_true")
    parser.add_argument("--detritus", action="store_true",
                        help="add the advisory detritus overlay/packet section")
    parser.add_argument("--force", action="store_true",
                        help="overwrite existing generated files (otherwise "
                             "the run refuses before writing anything)")
    parser.add_argument("--compare", type=Path, metavar="OTHER_LAYOUT",
                        help="compare --layout against another layout file")
    args = parser.parse_args(argv)

    layout = json.loads(Path(args.layout).read_text(encoding="utf-8"))
    if args.list_rooms:
        print(list_rooms(layout))
        return 0
    tables = load_footprint_tables()
    if not tables["ok"]:
        print(f"note: {tables['note']}; assembly footprints degrade to unknown",
              file=sys.stderr)

    room_ids = []
    if args.room:
        room_ids = [args.room]
    elif args.floor:
        for fl in layout["floors"]:
            if fl["id"] == args.floor:
                room_ids = [r["id"] for r in fl.get("rooms", [])]
        if not room_ids:
            parser.error(f"floor id not found: {args.floor}")
    elif not args.compare:
        parser.error("choose --room, --floor, --list-rooms or --compare")

    if args.compare:
        other = json.loads(Path(args.compare).read_text(encoding="utf-8"))
        scope = room_ids or [r["id"] for fl in layout["floors"]
                             for r in fl.get("rooms", [])]
        report = ["# Layout comparison (A = --layout, B = --compare)", ""]
        for rid in scope:
            report.append(compare_room(layout, other, rid, tables))
            report.append("")
        text = "\n".join(report)
        if args.output:
            args.output.mkdir(parents=True, exist_ok=True)
            path = args.output / "layout_comparison.md"
            try:
                preflight_overwrite([path], args.force)
            except FileExistsError as exc:
                print(f"error: {exc}", file=sys.stderr)
                return 3
            path.write_text(text + "\n", encoding="utf-8")
            print(path)
        else:
            print(text)
        return 0

    if not args.output:
        parser.error("--output is required for report generation; refuse to "
                     "write into tracked directories by default")
    args.output.mkdir(parents=True, exist_ok=True)
    # Batch preflight: a --floor run either writes every room or nothing.
    all_targets = [t for rid in room_ids
                   for t in room_targets(rid, args.output,
                                         args.json_only, args.visual_only)]
    try:
        preflight_overwrite(all_targets, args.force)
        for rid in room_ids:
            for path in emit_room(layout, rid, args.output, tables,
                                  json_only=args.json_only,
                                  visual_only=args.visual_only,
                                  detritus_on=args.detritus,
                                  force=args.force):
                print(path)
    except FileExistsError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 3
    return 0


if __name__ == "__main__":
    sys.exit(main())
