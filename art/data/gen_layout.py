#!/usr/bin/env python3
"""Deterministic layout author for Orison Apartments.

Produces the coordinate-driven data model shared by Blender (geometry),
Godot (assembly, props, navigation) and the audio system (acoustic graph):

    building_layout.json   semantic architecture: slabs, walls+openings,
                           stairs, elevator, rooms, functional-prop markers
    acoustic_graph.json    heating/electrical/water transmission graph
    prop_catalog.json      conductor profiles per functional prop type
    material_catalog.json  blockout materials (colors + Material Bible targets)

Everything is in meters, Blender axes (X east, Y north, Z up, street = -Y).
Origin = center of the ground-floor light court. Run: python3 gen_layout.py
"""
import json
import math
import os

OUT_DIR = os.path.dirname(os.path.abspath(__file__))

# ---------------------------------------------------------------- constants
EXT_T = 0.35        # exterior wall thickness
CORR_T = 0.18       # corridor wall thickness
PART_T = 0.12       # interior partition thickness
SLAB_T = 0.18
F2F = 3.20          # floor-to-floor
WALL_H = F2F - SLAB_T
X_IN = 13.65        # interior face of exterior walls (footprint 28 x 20)
Y_IN = 9.65
COURT = 3.25        # light court half-size (6.5 x 6.5)
CORE_Y0, CORE_Y1 = 3.25, 6.75   # cores flank the court north/south
XCI = COURT + CORR_T            # 3.43 corridor inner face (x)
XCO = XCI + 1.90                # 5.33 corridor outer face (x)
XAW = XCO + CORR_T              # 5.51 apartment inner face (x)
YCN = CORE_Y1 + CORR_T          # 6.93 corridor faces (y)
SPLIT = 0.06                    # half of A/B and C/D split partition

LEVELS = {"B1": -2.80, "F01": 0.0, "F02": 3.2, "F03": 6.4, "F04": 9.6,
          "F05": 12.8, "F06": 16.0, "ROOF": 19.2}

DOOR_ENTRY = {"w": 0.91, "h": 2.13}
DOOR_INT = {"w": 0.81, "h": 2.03}
DOOR_SERV = {"w": 0.96, "h": 2.10}
WIN = {"w": 1.35, "h": 1.70, "sill": 0.85}
WIN_COURT = {"w": 0.90, "h": 1.15, "sill": 1.00}

STACK_RECTS = {  # x0, y0, x1, y1  (interior faces)
    "A": (-X_IN, -Y_IN, -XAW, -SPLIT),   # southwest, street left
    "B": (-X_IN, SPLIT, -XAW, Y_IN),     # northwest, rear left
    "C": (XAW, SPLIT, X_IN, Y_IN),       # northeast, rear right
    "D": (XAW, -Y_IN, X_IN, -SPLIT),     # southeast, street right
}
RISER_XY = {"A": (-5.85, -0.45), "B": (-5.85, 0.45),
            "C": (5.85, 0.45), "D": (5.85, -0.45)}

RESIDENTS = {
    "2A": "Mina Vale", "3A": "supporting", "4A": "supporting",
    "5A": "Nadia Quell", "6A": "Sacha Reed",
    "2B": "supporting", "3B": "Omar Bell", "4B": "PLAYER",
    "5B": "supporting", "6B": "supporting",
    "2C": "Juno Kells", "3C": "vacant (damaged)",
    "4C": "Cam Ortiz & Noel Price", "5C": "supporting", "6C": "supporting",
    "2D": "sealed", "3D": "Rhea Sato", "4D": "short-term rental",
    "5D": "vacant (fire damage)", "6D": "landlord storage",
    "1A": "apartment", "1D": "apartment",
}

# Front stair (south core): 19 risers/floor, two flights + half landing.
FRONT = {"id": "front", "well": (-3.05, -6.65, 0.65, -3.35), "width": 1.35,
         "risers": 19, "rise": F2F / 19.0, "tread": 0.27,
         "levels": ["F01", "F02", "F03", "F04", "F05", "F06"]}
# Service stair (north core): 18 risers/floor, basement to roof.
SERVICE = {"id": "service", "well": (-2.40, 3.45, 1.30, 6.55), "width": 1.10,
           "risers": 18, "rise": F2F / 18.0, "tread": 0.27,
           "levels": ["B1", "F01", "F02", "F03", "F04", "F05", "F06", "ROOF"]}
ELEV = {"shaft": (0.85, -6.75, 3.00, -4.55),  # 2.15 x 2.20
        "cabin": (1.55, 1.70), "door_w": 0.91,
        "stops": ["B1", "F01", "F02", "F03", "F04", "F05", "F06"]}


def wall(a, b, t, h, z, openings=None, cat="walls", mat="plaster"):
    return {"a": list(a), "b": list(b), "t": t, "h": h, "z": z,
            "openings": openings or [], "cat": cat, "mat": mat}


def door(at, spec=DOOR_INT):
    return {"type": "door", "at": at, "w": spec["w"], "h": spec["h"], "sill": 0.0}


def window(at, spec=WIN):
    return {"type": "window", "at": at, "w": spec["w"], "h": spec["h"],
            "sill": spec["sill"]}


def rect_area(r):
    return (r[2] - r[0]) * (r[3] - r[1])


# ---------------------------------------------------------------- apartments

def apartment(floor_id, stack, z, walls, rooms, markers, furniture):
    """Blockout archetype: bedroom partition + bathroom box near the entry.

    The corridor-side wall and entry door are emitted by the corridor
    builder; this adds interior partitions only. Mirrored for east stacks.
    Apartment 4B (the player's) uses its own detailed plan instead.
    """
    if floor_id == "F04" and stack == "B":
        apartment_4b(z, walls, rooms, markers, furniture)
        return
    unit = "%s%s" % (floor_id[-1].lstrip("0") or floor_id[-1], stack)
    x0, y0, x1, y1 = STACK_RECTS[stack]
    east = stack in ("C", "D")
    street = stack in ("A", "D")
    inner_x = x0 if east else x1              # face shared with corridor wall
    sign = -1 if east else 1                  # +1: interior extends toward -x? no: toward exterior
    # bedroom band against the street/rear end wall
    bed_depth = 3.35
    if street:
        by = y0 + bed_depth
        bed_rect = (x0, y0, x1, by)
    else:
        by = y1 - bed_depth
        bed_rect = (x0, by, x1, y1)
    door_x = inner_x + (0.75 if east else -0.75)
    walls.append(wall((x0, by), (x1, by), PART_T, WALL_H, z,
                      [door(abs(door_x - x0))], mat="plaster"))
    # bathroom 2.2 x 2.4 against the corridor wall, next to the bedroom wall
    bw, bd = 2.40, 2.20
    bx1 = inner_x if not east else inner_x + bd
    bx0 = bx1 - bd if not east else inner_x
    if street:
        by0 = by + PART_T / 2
        by1 = by0 + bw
    else:
        by1 = by - PART_T / 2
        by0 = by1 - bw
    xin = bx0 if not east else bx1            # bath wall away from corridor
    walls.append(wall((xin, by0), (xin, by1), PART_T, WALL_H, z,
                      [door(bw * 0.5)], mat="plaster"))
    walls.append(wall((bx0, by1 if street else by0),
                      (bx1, by1 if street else by0), PART_T, WALL_H, z, [],
                      mat="plaster"))
    rooms += [
        {"id": "%s_%s_MAIN" % (floor_id, stack), "unit": unit,
         "rect": [x0, min(by, y1 - bed_depth) if street else y0, x1,
                  y1 if street else by], "kind": "living"},
        {"id": "%s_%s_BED" % (floor_id, stack), "unit": unit,
         "rect": list(bed_rect), "kind": "bedroom"},
        {"id": "%s_%s_BATH" % (floor_id, stack), "unit": unit,
         "rect": [bx0, by0, bx1, by1], "kind": "bathroom"},
    ]
    # radiator under a window on the long exterior wall
    rx = (x0 + 0.30) if not east else (x1 - 0.30)
    ry = (y0 + y1) / 2.0
    markers.append({"kind": "radiator", "id": "%s_%s_RADIATOR_01" % (floor_id, stack),
                    "pos": [rx, ry, z], "yaw_deg": 90 if not east else -90,
                    "network": "heating", "riser": "H-%s" % stack, "unit": unit})


def apartment_4b(z, walls, rooms, markers, furniture):
    """Player apartment to the brief's Section 4 plan: entry vestibule,
    bathroom, closet, galley kitchen, main room, sleeping alcove. The
    workstation faces the corridor utility wall; the radiator sits under
    the rear window; the impossible-door marker lives between them.
    """
    x0, y0, x1, y1 = STACK_RECTS["B"]      # -13.65, 0.06, -5.51, 9.65
    bx = -7.71                             # service band west face
    # entry vestibule (1.25 x 2.20) around the corridor door at y = 1.26
    walls.append(wall((bx, 0.66), (x1, 0.66), PART_T, WALL_H, z, []))
    walls.append(wall((bx, 0.66), (bx, 1.91), PART_T, WALL_H, z, [door(0.62)]))
    # bathroom (2.20 x 2.40) north of the vestibule
    walls.append(wall((bx, 1.91), (x1, 1.91), PART_T, WALL_H, z, [door(1.10)]))
    walls.append(wall((bx, 1.91), (bx, 4.31), PART_T, WALL_H, z, []))
    walls.append(wall((bx, 4.31), (x1, 4.31), PART_T, WALL_H, z, []))
    # closet (1.15 x 1.80) with sliding-door opening
    walls.append(wall((-6.66, 4.31), (-6.66, 6.11), PART_T, WALL_H, z,
                      [door(0.90)]))
    walls.append(wall((-6.66, 6.11), (x1, 6.11), PART_T, WALL_H, z, []))
    # sleeping alcove (2.75 x 3.15), open through a wide doorless gap
    walls.append(wall((-10.90, 6.50), (-10.90, y1), PART_T, WALL_H, z,
                      [{"type": "door", "at": 1.60, "w": 1.20, "h": 2.03,
                        "sill": 0.0}]))
    walls.append(wall((x0, 6.50), (-12.45, 6.50), PART_T, WALL_H, z, []))
    rooms += [
        {"id": "F04_B_VESTIBULE", "unit": "4B", "rect": [bx, 0.66, x1, 1.91],
         "kind": "vestibule"},
        {"id": "F04_B_BATH", "unit": "4B", "rect": [bx, 1.91, x1, 4.31],
         "kind": "bathroom"},
        {"id": "F04_B_CLOSET", "unit": "4B", "rect": [-6.66, 4.31, x1, 6.11],
         "kind": "closet"},
        {"id": "F04_B_KITCHEN", "unit": "4B", "rect": [-7.56, 6.11, x1, y1],
         "kind": "kitchen"},
        {"id": "F04_B_MAIN", "unit": "4B", "rect": [x0, y0, bx, 6.50],
         "kind": "living"},
        {"id": "F04_B_ALCOVE", "unit": "4B", "rect": [x0, 6.50, -10.90, y1],
         "kind": "alcove"},
    ]
    furniture += [
        {"id": "desk", "rect": [-8.35, 2.30, -7.77, 3.60], "z0": 0.72,
         "h": 0.04, "mat": "floor_oak"},
        {"id": "desk_legs", "rect": [-8.30, 2.35, -8.25, 3.55], "z0": 0.0,
         "h": 0.72, "mat": "metal"},
        {"id": "chair", "rect": [-8.95, 2.70, -8.50, 3.20], "z0": 0.42,
         "h": 0.06, "mat": "trim"},
        {"id": "bed", "rect": [-13.50, 6.75, -12.15, 9.45], "z0": 0.15,
         "h": 0.32, "mat": "trim"},
        {"id": "kitchen_counter", "rect": [-6.11, 6.35, -5.55, 8.85],
         "z0": 0.0, "h": 0.90, "mat": "trim"},
        {"id": "couch", "rect": [-12.95, 3.90, -11.45, 4.65], "z0": 0.12,
         "h": 0.42, "mat": "trim"},
    ]
    markers += [
        {"kind": "radiator", "id": "F04_B_RADIATOR_01", "unit": "4B",
         "pos": [-9.58, 9.35, z], "yaw_deg": 180, "network": "heating",
         "riser": "H-B"},
        {"kind": "lamp", "id": "F04_B_LAMP_01", "unit": "4B",
         "pos": [-8.05, 3.35, z + 0.76], "yaw_deg": 0,
         "network": "electrical"},
        {"kind": "monitor", "id": "F04_B_MONITOR_01", "unit": "4B",
         "pos": [-7.95, 2.85, z + 0.76], "yaw_deg": -90,
         "network": "electrical"},
        {"kind": "toaster", "id": "F04_B_TOASTER_01", "unit": "4B",
         "pos": [-5.85, 8.35, z + 0.90], "yaw_deg": 90,
         "network": "electrical"},
        {"kind": "fridge", "id": "F04_B_FRIDGE_01", "unit": "4B",
         "pos": [-6.05, 9.25, z], "yaw_deg": 90, "network": "electrical"},
        {"kind": "boxfan", "id": "F04_B_BOXFAN_01", "unit": "4B",
         "pos": [-12.95, 1.05, z + 0.25], "yaw_deg": 45,
         "network": "electrical"},
        {"kind": "door_anomaly", "id": "F04_B_DOOR_ANOMALY", "unit": "4B",
         "pos": [-7.20, 4.38, z], "yaw_deg": 0, "network": "structural"},
    ]


# ---------------------------------------------------------------- floors

def ring_and_cores(floor_id, z, walls, entry_doors=True):
    """Corridor ring, court walls, core walls, shaft walls for one level."""
    h = WALL_H
    # court walls (light shaft) with small court windows on E/W
    walls.append(wall((-COURT, -COURT), (-COURT, COURT), CORR_T, h, z,
                      [window(COURT, WIN_COURT)], mat="brick"))
    walls.append(wall((COURT, -COURT), (COURT, COURT), CORR_T, h, z,
                      [window(COURT, WIN_COURT)], mat="brick"))
    # corridor inner walls (x) run past court and cores
    walls.append(wall((-XCI, -YCN), (-XCI, YCN), CORR_T, h, z, [], mat="plaster"))
    walls.append(wall((XCI, -YCN), (XCI, YCN), CORR_T, h, z, [], mat="plaster"))
    # core side walls close the court band between court and corridor walls
    for cy0, cy1 in ((-CORE_Y1, -CORE_Y0), (CORE_Y0, CORE_Y1)):
        walls.append(wall((-COURT, cy0), (-COURT, cy1), CORR_T, h, z, []))
        walls.append(wall((COURT, cy0), (COURT, cy1), CORR_T, h, z, []))
    # core south wall: front stair door + elevator opening
    south_openings = []
    if floor_id in FRONT["levels"]:
        south_openings.append(door(abs(-0.05 - (-COURT)), DOOR_ENTRY))  # stair
    if floor_id in ELEV["stops"]:
        south_openings.append({"type": "door", "at": abs(1.925 - (-COURT)),
                               "w": ELEV["door_w"], "h": 2.10, "sill": 0.0})
    walls.append(wall((-COURT, -CORE_Y1), (COURT, -CORE_Y1), CORR_T, h, z,
                      south_openings))
    walls.append(wall((-COURT, -CORE_Y0), (COURT, -CORE_Y0), CORR_T, h, z, []))
    # core north wall: service stair door; court access door on F01
    north_openings = [door(abs(-0.55 - (-COURT)), DOOR_SERV)]
    walls.append(wall((-COURT, CORE_Y1), (COURT, CORE_Y1), CORR_T, h, z,
                      north_openings))
    court_south = [door(COURT)] if floor_id == "F01" else []
    walls.append(wall((-COURT, CORE_Y0), (COURT, CORE_Y0), CORR_T, h, z, []))
    walls.append(wall((-COURT, -COURT), (COURT, -COURT), CORR_T, h, z, []))
    walls.append(wall((-COURT, COURT), (COURT, COURT), CORR_T, h, z, court_south))
    # corridor outer walls with apartment entry doors
    for sx, stacks in ((-1, ("A", "B")), (1, ("D", "C"))):
        openings = []
        if entry_doors:
            for stack in stacks:
                x0, y0, x1, y1 = STACK_RECTS[stack]
                # entries sit near the A/B (C/D) split so the bathroom block
                # and bedroom partition never obstruct the doorway
                ey = y1 - 1.2 if stack in ("A", "D") else y0 + 1.2
                openings.append(door(abs(ey - (-Y_IN)), DOOR_ENTRY))
        walls.append(wall((sx * XCO, -Y_IN), (sx * XCO, Y_IN), CORR_T, h, z,
                          openings))
    # elevator shaft walls (west face + splits; south face is core wall)
    ex0, ey0, ex1, ey1 = ELEV["shaft"]
    walls.append(wall((ex0, ey0), (ex0, ey1), CORR_T, h, z, [], mat="concrete"))
    walls.append(wall((ex1, ey0), (ex1, ey1), CORR_T, h, z, [], mat="concrete"))
    walls.append(wall((ex0, ey1), (ex1, ey1), CORR_T, h, z, [], mat="concrete"))


def exterior(floor_id, z, walls):
    h = WALL_H
    for stack, rect in STACK_RECTS.items():
        x0, y0, x1, y1 = rect
        west = stack in ("A", "B")
        wx = -X_IN if west else X_IN
        ln = y1 - y0
        walls_openings = [window(ln * 0.30), window(ln * 0.70)]
        walls.append(wall((wx, y0), (wx, y1), EXT_T, h, z, walls_openings,
                          mat="brick"))
        ey = y0 if stack in ("A", "D") else y1
        walls.append(wall((x0, ey), (x1, ey), EXT_T, h, z,
                          [window((x1 - x0) * 0.5)], mat="brick"))
    # street / rear walls across the middle band (corridor ends)
    s_open = [window(X_IN - 2.5), window(X_IN + 2.5)]
    if floor_id == "F01":
        s_open.append(door(X_IN, DOOR_ENTRY))  # street entrance at x = 0
    walls.append(wall((-X_IN, -Y_IN), (X_IN, -Y_IN), EXT_T, h, z, s_open,
                      mat="brick"))
    walls.append(wall((-X_IN, Y_IN), (X_IN, Y_IN), EXT_T, h, z,
                      [window(X_IN - 2.5), window(X_IN + 2.5)], mat="brick"))


def split_walls(z, walls):
    for x0, x1 in ((-X_IN, -XAW), (XAW, X_IN)):
        walls.append(wall((x0, 0.0), (x1, 0.0), 2 * SPLIT, WALL_H, z, []))


def slab(floor_id, z, holes):
    return {"rect": [-14.0, -10.0, 14.0, 10.0], "z_top": z, "t": SLAB_T,
            "holes": [list(h) for h in holes]}


def stair_holes(floor_id):
    holes = []
    if floor_id in FRONT["levels"][1:]:
        holes.append(FRONT["well"])
    idx = SERVICE["levels"]
    if floor_id in idx[1:]:
        holes.append(SERVICE["well"])
    if floor_id in ELEV["stops"][1:] or floor_id == "ROOF":
        holes.append(ELEV["shaft"])
    return holes


def build_floor(floor_id):
    z = LEVELS[floor_id]
    walls, rooms, markers, furniture = [], [], [], []
    holes = stair_holes(floor_id)
    if floor_id not in ("B1", "F01"):
        holes.append((-COURT - CORR_T, -COURT - CORR_T,
                      COURT + CORR_T, COURT + CORR_T))
    floor = {"id": floor_id, "z": z,
             "slabs": [slab(floor_id, z, holes)],
             "walls": walls, "rooms": rooms, "markers": markers,
             "furniture": furniture}

    if floor_id == "ROOF":
        # parapets + headhouse + elevator machine room
        for a, b in (((-14, -10), (-14, 10)), ((14, -10), (14, 10)),
                     ((-14, -10), (14, -10)), ((-14, 10), (14, 10))):
            walls.append(wall(a, b, EXT_T, 1.10, z, [], mat="brick"))
        c = COURT + CORR_T
        for a, b in (((-c, -c), (-c, c)), ((c, -c), (c, c)),
                     ((-c, -c), (c, -c)), ((-c, c), (c, c))):
            walls.append(wall(a, b, CORR_T, 1.10, z, [], mat="brick"))
        hx0, hy0, hx1, hy1 = (-2.9, 3.2, 2.0, 6.8)  # stair headhouse
        walls.append(wall((hx0, hy0), (hx0, hy1), CORR_T, 2.4, z, []))
        walls.append(wall((hx1, hy0), (hx1, hy1), CORR_T, 2.4, z, []))
        walls.append(wall((hx0, hy1), (hx1, hy1), CORR_T, 2.4, z, []))
        walls.append(wall((hx0, hy0), (hx1, hy0), CORR_T, 2.4, z,
                          [door(abs(-0.55 - hx0), DOOR_SERV)]))
        ex0, ey0, ex1, ey1 = ELEV["shaft"]
        m = 0.45
        walls.append(wall((ex0 - m, ey0 - m), (ex0 - m, ey1 + m), CORR_T, 2.4, z,
                          [], mat="concrete"))
        walls.append(wall((ex1 + m, ey0 - m), (ex1 + m, ey1 + m), CORR_T, 2.4, z,
                          [], mat="concrete"))
        walls.append(wall((ex0 - m, ey1 + m), (ex1 + m, ey1 + m), CORR_T, 2.4, z,
                          [], mat="concrete"))
        walls.append(wall((ex0 - m, ey0 - m), (ex1 + m, ey0 - m), CORR_T, 2.4, z,
                          [door(1.0, DOOR_SERV)], mat="concrete"))
        rooms.append({"id": "ROOF_OPEN", "rect": [-13.65, -9.65, 13.65, 9.65],
                      "kind": "roof"})
        markers.append({"kind": "watertank", "id": "ROOF_TANK",
                        "pos": [-8.0, 6.0, z], "yaw_deg": 0})
        return floor

    ring_and_cores(floor_id, z, walls, entry_doors=(floor_id != "B1"))
    exterior(floor_id, z, walls)
    split_walls(z, walls)

    if floor_id == "B1":
        names = {"A": "STORAGE_CAGES", "B": "LAUNDRY", "C": "BOILER",
                 "D": "ELECTRICAL"}
        for sx, stacks in ((-1, ("A", "B")), (1, ("D", "C"))):
            openings = []
            for stack in stacks:
                x0, y0, x1, y1 = STACK_RECTS[stack]
                openings.append(door(abs((y0 + y1) / 2 - (-Y_IN)), DOOR_SERV))
            walls.append(wall((sx * XCO, -Y_IN), (sx * XCO, Y_IN), CORR_T,
                              WALL_H, z, openings))
        for stack, name in names.items():
            rooms.append({"id": "B1_%s" % name, "rect": list(STACK_RECTS[stack]),
                          "kind": name.lower()})
        markers += [
            {"kind": "boiler", "id": "B1_BOILER_01", "pos": [10.0, 5.0, z],
             "yaw_deg": 0, "network": "heating"},
            {"kind": "washer", "id": "B1_WASHER_01", "pos": [-11.5, 4.0, z],
             "yaw_deg": 90, "network": "water"},
            {"kind": "washer", "id": "B1_WASHER_02", "pos": [-11.5, 5.2, z],
             "yaw_deg": 90, "network": "water"},
            {"kind": "dryer", "id": "B1_DRYER_01", "pos": [-11.5, 7.0, z],
             "yaw_deg": 90, "network": "electrical"},
            {"kind": "room0_threshold", "id": "B1_ROOM0_DOOR",
             "pos": [0.0, 6.9, z], "yaw_deg": 180, "network": "structural"},
        ]
        return floor

    if floor_id == "F01":
        rooms += [
            {"id": "F01_LOBBY", "rect": [-5.33, -9.65, 5.33, -6.93],
             "kind": "lobby"},
            {"id": "F01_COMMON_B", "rect": list(STACK_RECTS["B"]),
             "kind": "common"},
            {"id": "F01_STORAGE_C", "rect": list(STACK_RECTS["C"]),
             "kind": "storage"},
            {"id": "F01_COURTYARD", "rect": [-COURT, -COURT, COURT, COURT],
             "kind": "courtyard"},
        ]
        markers += [
            {"kind": "radiator", "id": "F01_LOBBY_RADIATOR_01",
             "pos": [-4.6, -9.3, z], "yaw_deg": 0, "network": "heating",
             "riser": "H-A", "unit": "LOBBY"},
            {"kind": "mailboxes", "id": "F01_MAILWALL", "pos": [4.4, -9.3, z],
             "yaw_deg": 0},
        ]
        for stack in ("A", "D"):
            apartment(floor_id, stack, z, walls, rooms, markers, furniture)
        return floor

    for stack in ("A", "B", "C", "D"):
        apartment(floor_id, stack, z, walls, rooms, markers, furniture)
    rooms.append({"id": "%s_CORRIDOR" % floor_id,
                  "rect": [-XCO, -Y_IN, XCO, Y_IN], "kind": "corridor"})
    markers.append({"kind": "corridor_light", "id": "%s_CORRLIGHT_S" % floor_id,
                    "pos": [0.0, -8.3, z], "yaw_deg": 0, "network": "electrical"})
    markers.append({"kind": "corridor_light", "id": "%s_CORRLIGHT_N" % floor_id,
                    "pos": [0.0, 8.3, z], "yaw_deg": 0, "network": "electrical"})
    return floor


# ---------------------------------------------------------------- stairs

def stair_geometry(st):
    """Explicit flights: two runs + half landing per level-to-level climb."""
    flights = []
    wx0, wy0, wx1, wy1 = st["well"]
    lvls = st["levels"]
    for i in range(len(lvls) - 1):
        z0, z1 = LEVELS[lvls[i]], LEVELS[lvls[i + 1]]
        risers = int(round((z1 - z0) / st["rise"]))
        n1 = risers // 2 + risers % 2
        n2 = risers - n1
        land_w = st["width"]
        run1 = (n1 - 1) * st["tread"]
        # flight 1: south side, climbing west from the east end of the well
        flights.append({"kind": "flight", "z0": z0, "rise": st["rise"],
                       "tread": st["tread"], "n": n1, "dir": -1,
                        "x_start": wx1 - 0.02, "y0": wy0, "y1": wy0 + st["width"]})
        lz = z0 + n1 * st["rise"]
        flights.append({"kind": "landing", "z": lz,
                        "rect": [wx1 - 0.02 - run1 - st["tread"] - land_w, wy0,
                                 wx1 - 0.02 - run1 - st["tread"], wy1]})
        flights.append({"kind": "flight", "z0": lz, "rise": st["rise"],
                        "tread": st["tread"], "n": n2, "dir": 1,
                        "x_start": wx1 - 0.02 - run1 - st["tread"],
                        "y0": wy1 - st["width"], "y1": wy1})
    return {"id": st["id"], "well": list(st["well"]), "width": st["width"],
            "parts": flights}


# ---------------------------------------------------------------- validation

def validate(layout):
    problems = []
    for fl in layout["floors"]:
        rects = [(r["id"], r["rect"]) for r in fl["rooms"]
                 if r["kind"] not in ("corridor", "roof", "courtyard")]
        for i in range(len(rects)):
            for j in range(i + 1, len(rects)):
                a, b = rects[i][1], rects[j][1]
                if (a[0] < b[2] - 0.01 and b[0] < a[2] - 0.01 and
                        a[1] < b[3] - 0.01 and b[1] < a[3] - 0.01):
                    if rects[i][0].rsplit("_", 1)[0] == rects[j][0].rsplit("_", 1)[0]:
                        continue  # rooms nested inside their unit envelope
                    problems.append("overlap %s / %s" % (rects[i][0], rects[j][0]))
        for r in fl["rooms"]:
            x0, y0, x1, y1 = r["rect"]
            if x0 < -14 or x1 > 14 or y0 < -10 or y1 > 10:
                problems.append("%s escapes footprint" % r["id"])
        for w in fl["walls"]:
            for o in w["openings"]:
                if o["type"] == "door" and o["w"] < 0.72:
                    problems.append("narrow door on %s" % fl["id"])
    return problems


# ---------------------------------------------------------------- graphs

def acoustic_graph(layout):
    nodes, edges = [], []

    def add(nid, pos, network, room="", recv=0.7, band=(55, 850), delay=30):
        nodes.append({"id": nid, "pos": [round(p, 3) for p in pos],
                      "room": room, "network": network,
                      "frequency_band": list(band), "delay_ms": delay,
                      "damping": 0.22, "infection_receptivity": recv,
                      "connections": []})

    add("BASEMENT_HEADER_WEST", [-5.85, 0.0, -2.3], "heating",
        "B1_LAUNDRY", 0.6, (30, 400), 12)
    add("BASEMENT_HEADER_EAST", [5.85, 0.0, -2.3], "heating",
        "B1_BOILER", 0.6, (30, 400), 12)
    add("B1_BOILER_01", [10.0, 5.0, -2.8], "heating", "B1_BOILER", 0.5,
        (25, 300), 5)
    edges += [("B1_BOILER_01", "BASEMENT_HEADER_EAST"),
              ("BASEMENT_HEADER_EAST", "BASEMENT_HEADER_WEST")]
    by_riser = {}
    for fl in layout["floors"]:
        for m in fl["markers"]:
            if m["kind"] == "radiator":
                add(m["id"], [m["pos"][0], m["pos"][1], m["pos"][2] + 0.35],
                    "heating", room=m.get("unit", ""), recv=0.84, delay=38)
                by_riser.setdefault(m.get("riser", "H-X"), []).append(m)
            elif m["kind"] in ("washer", "dryer"):
                add(m["id"], m["pos"], "water", "B1_LAUNDRY", 0.6,
                    (40, 2000), 20)
                edges.append((m["id"], "BASEMENT_HEADER_WEST"))
            elif m["kind"] in ("lamp", "monitor", "toaster", "fridge", "boxfan"):
                add(m["id"], m["pos"], "electrical", m.get("unit", ""), 0.75,
                    (60, 8000), 4)
                edges.append((m["id"], "F04_CORRLIGHT_S"))
            elif m["kind"] == "corridor_light":
                add(m["id"], [m["pos"][0], m["pos"][1], m["pos"][2] + 2.5],
                    "electrical", fl["id"], 0.55, (100, 9000), 4)
            elif m["kind"] == "door_anomaly":
                add(m["id"], [m["pos"][0], m["pos"][1], m["pos"][2] + 1.0],
                    "structural", m.get("unit", ""), 0.95, (20, 200), 60)
                edges.append((m["id"], "F04_B_RADIATOR_01"))
    # electrical spine: hub in the basement switchgear room, corridor
    # fixtures chained per floor and down the riser
    add("B1_ELECTRICAL_HUB", [10.0, -5.0, -2.4], "electrical",
        "B1_ELECTRICAL", 0.5, (60, 8000), 8)
    prev_s = "B1_ELECTRICAL_HUB"
    for fid in ("F02", "F03", "F04", "F05", "F06"):
        s = "%s_CORRLIGHT_S" % fid
        edges.append((s, prev_s))
        edges.append((s, "%s_CORRLIGHT_N" % fid))
        prev_s = s
    for riser, rads in by_riser.items():
        rads.sort(key=lambda m: m["pos"][2])
        header = ("BASEMENT_HEADER_WEST" if riser in ("H-A", "H-B")
                  else "BASEMENT_HEADER_EAST")
        edges.append((rads[0]["id"], header))
        for lo, hi in zip(rads, rads[1:]):
            edges.append((lo["id"], hi["id"]))
    index = {n["id"]: n for n in nodes}
    for a, b in edges:
        if a in index and b in index:
            index[a]["connections"].append(b)
            index[b]["connections"].append(a)
    return {"nodes": nodes}


PROP_CATALOG = {
    "radiator": {"minimum_action_interval": 0.11, "maximum_action_rate": 8,
                 "available_mechanical_events": ["knock", "tick", "shudder"],
                 "preferred_subdivision": 1, "timing_drift": 0.012,
                 "response_latency": 0.04, "normal_function_priority": 1.0,
                 "infection_receptivity": 0.84},
    "lamp": {"minimum_action_interval": 0.05, "maximum_action_rate": 14,
             "available_mechanical_events": ["flicker", "switch", "filament"],
             "preferred_subdivision": 2, "timing_drift": 0.0,
             "response_latency": 0.01, "normal_function_priority": 1.0,
             "infection_receptivity": 0.75},
    "corridor_light": {"minimum_action_interval": 0.08, "maximum_action_rate": 10,
                       "available_mechanical_events": ["flicker", "starter_buzz"],
                       "preferred_subdivision": 2, "timing_drift": 0.02,
                       "response_latency": 0.02, "normal_function_priority": 1.0,
                       "infection_receptivity": 0.55},
    "washer": {"minimum_action_interval": 0.45, "maximum_action_rate": 2,
               "available_mechanical_events": ["agitate", "thump", "drain"],
               "preferred_subdivision": 0.5, "timing_drift": 0.05,
               "response_latency": 0.20, "normal_function_priority": 1.0,
               "infection_receptivity": 0.6},
    "boiler": {"minimum_action_interval": 0.9, "maximum_action_rate": 1,
               "available_mechanical_events": ["thud", "pressure_hiss"],
               "preferred_subdivision": 0.25, "timing_drift": 0.08,
               "response_latency": 0.35, "normal_function_priority": 1.0,
               "infection_receptivity": 0.5},
    "toaster": {"minimum_action_interval": 0.35, "maximum_action_rate": 3,
                "available_mechanical_events": ["latch", "relay", "pop",
                                                "coil_pulse"],
                "preferred_subdivision": 1, "timing_drift": 0.0,
                "response_latency": 0.08, "normal_function_priority": 1.0,
                "infection_receptivity": 0.7},
    "fridge": {"minimum_action_interval": 1.2, "maximum_action_rate": 1,
               "available_mechanical_events": ["compressor_click", "hum_shift"],
               "preferred_subdivision": 0.25, "timing_drift": 0.06,
               "response_latency": 0.30, "normal_function_priority": 1.0,
               "infection_receptivity": 0.55},
    "monitor": {"minimum_action_interval": 0.06, "maximum_action_rate": 12,
                "available_mechanical_events": ["flicker", "scan_glitch"],
                "preferred_subdivision": 2, "timing_drift": 0.0,
                "response_latency": 0.01, "normal_function_priority": 1.0,
                "infection_receptivity": 0.8},
    "boxfan": {"minimum_action_interval": 0.5, "maximum_action_rate": 2,
               "available_mechanical_events": ["speed_waver", "cage_rattle"],
               "preferred_subdivision": 0.5, "timing_drift": 0.08,
               "response_latency": 0.25, "normal_function_priority": 1.0,
               "infection_receptivity": 0.5},
    "door_anomaly": {"minimum_action_interval": 0.10, "maximum_action_rate": 8,
                     "available_mechanical_events": ["seam_glow"],
                     "preferred_subdivision": 1, "timing_drift": 0.0,
                     "response_latency": 0.0, "normal_function_priority": 0.0,
                     "infection_receptivity": 1.0},
}

MATERIAL_CATALOG = {
    "plaster": {"base_color": [0.62, 0.64, 0.58, 1.0], "roughness": 0.80},
    "brick": {"base_color": [0.42, 0.27, 0.22, 1.0], "roughness": 0.85},
    "concrete": {"base_color": [0.48, 0.48, 0.47, 1.0], "roughness": 0.75},
    "trim": {"base_color": [0.85, 0.83, 0.77, 1.0], "roughness": 0.45},
    "floor_oak": {"base_color": [0.45, 0.33, 0.22, 1.0], "roughness": 0.55},
    "terrazzo": {"base_color": [0.72, 0.70, 0.66, 1.0], "roughness": 0.40},
    "metal": {"base_color": [0.55, 0.56, 0.58, 1.0], "roughness": 0.35,
              "metallic": 0.9},
    "slab": {"base_color": [0.35, 0.34, 0.33, 1.0], "roughness": 0.7},
    "stair": {"base_color": [0.58, 0.56, 0.52, 1.0], "roughness": 0.5},
    "glassish": {"base_color": [0.35, 0.45, 0.50, 1.0], "roughness": 0.12},
}


def main():
    floors = [build_floor(f) for f in
              ("B1", "F01", "F02", "F03", "F04", "F05", "F06", "ROOF")]
    layout = {
        "meta": {"name": "Orison Apartments", "footprint": [28.0, 20.0],
                 "levels": LEVELS, "floor_to_floor": F2F,
                 "wall_height": WALL_H, "slab_t": SLAB_T,
                 "player": {"height": 1.75, "eye": 1.62, "radius": 0.38,
                            "crouch": 1.05, "step_max": 0.28},
                 "residents": RESIDENTS},
        "floors": floors,
        "stairs": [stair_geometry(FRONT), stair_geometry(SERVICE)],
        "elevator": {"shaft": list(ELEV["shaft"]),
                     "cabin": list(ELEV["cabin"]),
                     "stops": {l: LEVELS[l] for l in ELEV["stops"]},
                     "door_w": ELEV["door_w"]},
    }
    problems = validate(layout)
    if problems:
        for p in problems:
            print("VALIDATION:", p)
        raise SystemExit("layout validation failed (%d problems)" % len(problems))

    with open(os.path.join(OUT_DIR, "building_layout.json"), "w") as f:
        json.dump(layout, f, indent=1)
    with open(os.path.join(OUT_DIR, "acoustic_graph.json"), "w") as f:
        json.dump(acoustic_graph(layout), f, indent=1)
    with open(os.path.join(OUT_DIR, "prop_catalog.json"), "w") as f:
        json.dump(PROP_CATALOG, f, indent=1)
    with open(os.path.join(OUT_DIR, "material_catalog.json"), "w") as f:
        json.dump(MATERIAL_CATALOG, f, indent=1)

    n_walls = sum(len(fl["walls"]) for fl in floors)
    n_marks = sum(len(fl["markers"]) for fl in floors)
    rads = sum(1 for fl in floors for m in fl["markers"]
               if m["kind"] == "radiator")
    apt_areas = {s: round(rect_area(r), 1) for s, r in STACK_RECTS.items()}
    print("layout OK: %d walls, %d markers, %d radiators" %
          (n_walls, n_marks, rads))
    print("stack areas (m^2):", apt_areas)


if __name__ == "__main__":
    main()
