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

# Stack envelopes sized to the brief: A 72-76 m2 (1BR, street), B 52-58
# (studio, rear), C 80-86 (2BR, rear), D 68-74 (1BR + office, street).
# The west-side remainder between A and B is a locked "former suite"
# storage room — the 1927 subdivision left it belonging to nobody.
STACK_RECTS = {  # x0, y0, x1, y1  (interior faces)
    "A": (-X_IN, -Y_IN, -XAW, -0.45),    # southwest: 8.14 x 9.20 = 74.9
    "B": (-X_IN, 2.67, -XAW, Y_IN),      # northwest: 8.14 x 6.98 = 56.8
    "C": (XAW, -0.88, X_IN, Y_IN),       # northeast: 8.14 x 10.53 = 85.7
    "D": (XAW, -Y_IN, X_IN, -1.00),      # southeast: 8.14 x 8.65 = 70.4
}
WSTOR_RECT = (-X_IN, -0.33, -XAW, 2.55)  # former-suite storage (west)
CHIMNEY = (9.55, 9.10, 10.45, 9.65)      # coal-boiler flue, NE rear
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

# Stairs are code-shaped dog-legs rising off a STAIR HALL (the 1927
# parti): the corridor opens through an archway into the hall (x 0.55..
# 3.25 of each core); each flight departs from and arrives onto a hall,
# so every door/archway meets a full-depth floor landing (IBC 1011.6),
# risers are 177.8 mm (max 178), treads 285 mm, and the half-landing is
# as deep as the stair is wide. 18 equal risers per floor (the brief's
# 19 x 171 mm cannot pair into equal flights within the core - noted).
HALL_X = 0.55                    # hall / floor-landing west edge
FRONT = {"id": "front", "width": 1.35, "rise": F2F / 18.0, "tread": 0.285,
         "well": (-3.08, -6.70, HALL_X, -3.30),
         "hole": (-3.25, -6.75, HALL_X, -3.25),
         "strips": [(-6.70, -5.35), (-4.65, -3.30)],
         "levels": ["F01", "F02", "F03", "F04", "F05", "F06"]}
SERVICE = {"id": "service", "width": 1.10, "rise": F2F / 18.0, "tread": 0.27,
           "well": (-2.71, 3.30, HALL_X, 6.70),
           "hole": (-3.25, 3.25, HALL_X, 6.75),
           "strips": [(5.60, 6.70), (3.30, 4.40)],
           "levels": ["B1", "F01", "F02", "F03", "F04", "F05", "F06",
                      "ROOF"]}
# Elevator moved out of the stair run: the shaft stands at the light-court
# edge with its door opening onto the south stair hall - the visible cage.
ELEV = {"shaft": (0.35, -3.25, 2.50, -1.05),  # 2.15 x 2.20
        "cabin": (1.55, 1.70), "door_w": 0.91,
        "stops": ["B1", "F01", "F02", "F03", "F04", "F05", "F06"]}
ARCH = {"w": 1.35, "h": 2.20}


def wall(a, b, t, h, z, openings=None, cat="walls", mat="plaster"):
    return {"a": list(a), "b": list(b), "t": t, "h": h, "z": z,
            "openings": openings or [], "cat": cat, "mat": mat}


def door(at, spec=DOOR_INT, leaf="closed"):
    """leaf: "closed" | "open" | "locked" | "none" (opening only)."""
    return {"type": "door", "at": at, "w": spec["w"], "h": spec["h"],
            "sill": 0.0, "leaf": leaf}


def window(at, spec=WIN):
    return {"type": "window", "at": at, "w": spec["w"], "h": spec["h"],
            "sill": spec["sill"]}


def rect_area(r):
    return (r[2] - r[0]) * (r[3] - r[1])


# ---------------------------------------------------------------- apartments

def apartment(floor_id, stack, z, walls, rooms, markers, furniture):
    """Per-stack archetypes to the brief: A one-bedroom (street), B studio
    with sleeping alcove (rear), C two-bedroom (rear), D one-bedroom plus
    office (street). Apartment 4B (the player's) uses its own detailed
    plan. Unit character (sealed / damaged / resident identity) is layered
    on by dress_unit().
    """
    if floor_id == "F04" and stack == "B":
        apartment_4b(z, walls, rooms, markers, furniture)
        return
    unit = "%s%s" % (floor_id[-1].lstrip("0") or floor_id[-1], stack)
    x0, y0, x1, y1 = STACK_RECTS[stack]
    east = stack in ("C", "D")
    street = stack in ("A", "D")
    inner_x = x1 if not east else x0          # face shared with corridor
    bx = inner_x - 2.30 if not east else inner_x + 2.30  # service band

    def band_x(depth):  # x-extent of a room hugging the corridor wall
        return (inner_x - depth, inner_x) if not east else (inner_x, inner_x + depth)

    prefix = "%s_%s" % (floor_id, stack)
    if stack in ("A", "D"):
        # bedroom band at the street end
        by = y0 + 3.40
        door_x = bx + (0.55 if east else -0.55)  # clear of the bath band
        walls.append(wall((x0, by), (x1, by), PART_T, WALL_H, z,
                          [door(abs(door_x - x0))]))
        rooms.append({"id": prefix + "_BED", "unit": unit,
                      "rect": [x0, y0, x1, by], "kind": "bedroom"})
        # bathroom against the corridor wall, north of the bedroom wall
        bth0, bth1 = band_x(2.20)
        walls.append(wall((bx if not east else bx, by + 0.06),
                          (bx, by + 2.46), PART_T, WALL_H, z, [door(1.2)]))
        walls.append(wall((bth0, by + 2.46), (bth1, by + 2.46), PART_T,
                          WALL_H, z, []))
        rooms.append({"id": prefix + "_BATH", "unit": unit,
                      "rect": [bth0, by + 0.06, bth1, by + 2.46],
                      "kind": "bathroom"})
        bath_fixtures(furniture, unit, [bth0, by + 0.06, bth1, by + 2.46],
                      "e" if not east else "w")
        wardrobe(furniture, unit, x0 + 0.40, by - 0.95)
        rooms.append({"id": prefix + "_MAIN", "unit": unit,
                      "rect": [x0, by, x1, y1], "kind": "living"})
        _furn_box(furniture, unit + "_bed", x0 + 0.4, y0 + 0.4, 1.45, 2.05,
                  0.15, 0.32, "trim", east)
        _furn_box(furniture, unit + "_counter",
                  bth1 - 0.6 if east else bth0,
                  y1 - 2.6, 0.6, 2.2, 0.0, 0.9, "trim", False)
        _furn_box(furniture, unit + "_table", (x0 + x1) / 2 - 0.5, by + 1.2,
                  1.0, 1.0, 0.72, 0.04, "floor_oak", False)
        if stack == "D":
            # small office in the corridor band, north of entry and bath
            oy0, oy1 = by + 3.41, y1
            walls.append(wall((bx, oy0), (bx, oy1), PART_T, WALL_H, z, []))
            walls.append(wall((bth0, oy0), (bth1, oy0), PART_T, WALL_H, z,
                              [door(1.1)]))
            rooms.append({"id": prefix + "_OFFICE", "unit": unit,
                          "rect": [bth0, oy0, bth1, oy1], "kind": "office"})
            _furn_box(furniture, unit + "_odesk", bth0 + 0.2, oy1 - 0.9,
                      1.3, 0.6, 0.72, 0.04, "floor_oak", False)
    elif stack == "B":
        # studio: sleeping alcove at the rear, bath near the entry
        ay = y1 - 3.15
        ax = x0 + 2.75
        walls.append(wall((ax, ay), (ax, y1), PART_T, WALL_H, z,
                          [{"type": "door", "at": 1.60, "w": 1.20,
                            "h": 2.03, "sill": 0.0}]))
        walls.append(wall((x0, ay), (x0 + 1.2, ay), PART_T, WALL_H, z, []))
        rooms.append({"id": prefix + "_ALCOVE", "unit": unit,
                      "rect": [x0, ay, ax, y1], "kind": "alcove"})
        bth0, bth1 = band_x(2.20)
        walls.append(wall((bth0, y0 + 0.30), (bth0, y0 + 2.70), PART_T,
                          WALL_H, z, []) if east else
                     wall((bth0, y0 + 0.30), (bth0, y0 + 2.70), PART_T,
                          WALL_H, z, []))
        walls.append(wall((bth0, y0 + 2.70), (bth1, y0 + 2.70), PART_T,
                          WALL_H, z, [door(1.1)]))
        walls.append(wall((bth0, y0 + 0.30), (bth1, y0 + 0.30), PART_T,
                          WALL_H, z, []))
        rooms.append({"id": prefix + "_BATH", "unit": unit,
                      "rect": [bth0, y0 + 0.30, bth1, y0 + 2.70],
                      "kind": "bathroom"})
        bath_fixtures(furniture, unit, [bth0, y0 + 0.30, bth1, y0 + 2.70],
                      "e" if not east else "w")
        wardrobe(furniture, unit, x0 + 0.35, ay + 0.25, False)
        rooms.append({"id": prefix + "_MAIN", "unit": unit,
                      "rect": [x0, y0, x1, ay], "kind": "living"})
        _furn_box(furniture, unit + "_bed", x0 + 0.35, y1 - 2.45,
                  1.2, 2.05, 0.15, 0.32, "trim", False)
        _furn_box(furniture, unit + "_counter",
                  bth1 - 0.6 if east else bth0, y1 - 2.4, 0.6, 2.0,
                  0.0, 0.9, "trim", False)
    else:  # C: two bedrooms across the rear
        by = y1 - 3.40
        xm = (x0 + x1) / 2.0
        walls.append(wall((x0, by), (x1, by), PART_T, WALL_H, z,
                          [door(1.6), door(x1 - x0 - 1.6)]))
        walls.append(wall((xm, by), (xm, y1), PART_T, WALL_H, z, []))
        rooms.append({"id": prefix + "_BED1", "unit": unit,
                      "rect": [x0, by, xm, y1], "kind": "bedroom"})
        rooms.append({"id": prefix + "_BED2", "unit": unit,
                      "rect": [xm, by, x1, y1], "kind": "bedroom"})
        bth0, bth1 = band_x(2.20)
        walls.append(wall((bx, by - 2.46), (bx, by - 0.06), PART_T, WALL_H,
                          z, [door(1.2)]))
        walls.append(wall((bth0, by - 2.46), (bth1, by - 2.46), PART_T,
                          WALL_H, z, []))
        rooms.append({"id": prefix + "_BATH", "unit": unit,
                      "rect": [bth0, by - 2.46, bth1, by - 0.06],
                      "kind": "bathroom"})
        bath_fixtures(furniture, unit, [bth0, by - 2.46, bth1, by - 0.06],
                      "e" if not east else "w")
        wardrobe(furniture, unit, xm - 0.75, by + 0.20, False)
        wardrobe(furniture, unit + "b", xm + 0.15, by + 0.20, False)
        rooms.append({"id": prefix + "_MAIN", "unit": unit,
                      "rect": [x0, y0, x1, by], "kind": "living"})
        _furn_box(furniture, unit + "_bed1", x0 + 0.4, y1 - 2.45, 1.45,
                  2.05, 0.15, 0.32, "trim", False)
        _furn_box(furniture, unit + "_bed2", xm + 0.95, y1 - 2.45, 1.45,
                  2.05, 0.15, 0.32, "trim", False)
        _furn_box(furniture, unit + "_counter",
                  bth1 - 0.6 if east else bth0, y0 + 0.5, 0.6, 2.2,
                  0.0, 0.9, "trim", False)
    rx = (x0 + 0.30) if not east else (x1 - 0.30)
    markers.append({"kind": "radiator",
                    "id": "%s_%s_RADIATOR_01" % (floor_id, stack),
                    "pos": [rx, (y0 + y1) / 2.0, z],
                    "yaw_deg": 90 if not east else -90,
                    "network": "heating", "riser": "H-%s" % stack,
                    "unit": unit})
    dress_unit(unit, stack, floor_id, z, furniture, markers)


def _furn_box(furniture, fid, x, y, w, d, z0, h, mat, _east):
    furniture.append({"id": fid, "rect": [x, y, x + w, y + d], "z0": z0,
                      "h": h, "mat": mat})




def bath_fixtures(furniture, unit, rect, edge):
    """Shower tray, toilet + tank, sink lined along one wall of the bath
    (the wall opposite the door). edge: "e" | "w" | "n"."""
    x0, y0, x1, y1 = rect

    def item(off, w, d, h, tag, z0=0.0):
        if edge == "e":
            _furn_box(furniture, "%s_%s" % (unit, tag), x1 - d - 0.06,
                      y0 + off, d, w, z0, h, "trim", False)
        elif edge == "w":
            _furn_box(furniture, "%s_%s" % (unit, tag), x0 + 0.06,
                      y0 + off, d, w, z0, h, "trim", False)
        else:  # "n"
            _furn_box(furniture, "%s_%s" % (unit, tag), x0 + off,
                      y1 - d - 0.06, w, d, z0, h, "trim", False)

    item(0.08, 0.80, 0.80, 0.14, "shower")
    item(0.98, 0.42, 0.66, 0.42, "toilet")
    item(0.98, 0.42, 0.16, 0.78, "tank")
    item(1.68, 0.45, 0.50, 0.85, "sink")


def wardrobe(furniture, unit, x, y, along_x=True):
    if along_x:
        _furn_box(furniture, unit + "_wardrobe", x, y, 1.30, 0.62, 0.0,
                  1.95, "trim", False)
    else:
        _furn_box(furniture, unit + "_wardrobe", x, y, 0.62, 1.30, 0.0,
                  1.95, "trim", False)


## Resident-specific environmental identity (Section 16) and unit states,
## expressed through furniture clusters and functional-prop markers so the
## conductor can reach each hero apartment through its own objects.
def dress_unit(unit, stack, floor_id, z, furniture, markers):
    x0, y0, x1, y1 = STACK_RECTS[stack]
    cx, cy = (x0 + x1) / 2.0, (y0 + y1) / 2.0

    def mk(kind, idx, px, py, pz=0.0, yaw=0):
        markers.append({"kind": kind,
                        "id": "%s_%s_%s_%02d" % (floor_id, stack,
                                                 kind.upper(), idx),
                        "unit": unit, "pos": [px, py, z + pz],
                        "yaw_deg": yaw, "network": "electrical"})

    if unit == "2A":    # Mina: ordered caption station, quiet
        _furn_box(furniture, "2A_desk", x0 + 0.5, cy - 0.7, 1.5, 0.7, 0.72,
                  0.04, "floor_oak", False)
        for i in range(3):
            _furn_box(furniture, "2A_shelf%d" % i, x0 + 0.4 + i * 1.15,
                      y0 + 3.6, 0.9, 0.32, 0.0, 1.6, "trim", False)
        mk("monitor", 1, x0 + 1.1, cy - 0.5, 0.76, -90)
        mk("lamp", 1, x0 + 0.8, cy - 0.4, 0.76)
    elif unit == "2C":  # Juno: improvised studio, speakers everywhere
        _furn_box(furniture, "2C_bench", cx - 1.2, cy - 0.5, 2.4, 0.7, 0.72,
                  0.05, "metal", False)
        mk("speaker", 1, x1 - 0.6, cy + 1.6, 0.0, -90)
        mk("speaker", 2, x1 - 0.6, cy - 2.2, 0.0, -90)
        mk("monitor", 1, cx - 0.4, cy - 0.3, 0.76, -90)
    elif unit == "3B":  # Omar: repair shop by category
        _furn_box(furniture, "3B_workbench", x0 + 0.4, y0 + 3.8, 2.2, 0.8,
                  0.85, 0.06, "metal", False)
        for i in range(2):
            _furn_box(furniture, "3B_tools%d" % i, x0 + 0.4 + i * 1.3,
                      y0 + 0.35, 1.0, 0.4, 0.0, 1.8, "metal", False)
        mk("lamp", 1, x0 + 1.0, y0 + 4.0, 0.9)
    elif unit == "3D":  # Rhea: vocal booth and aligned playback
        _furn_box(furniture, "3D_booth_w", cx + 0.5, cy - 1.0, 0.1, 2.0,
                  0.0, 2.2, "trim", False)
        _furn_box(furniture, "3D_booth_n", cx + 0.5, cy + 1.0, 2.0, 0.1,
                  0.0, 2.2, "trim", False)
        _furn_box(furniture, "3D_mirror", x1 - 2.6 if stack in ("C", "D")
                  else x0 + 2.5, y0 + 1.0, 0.05, 1.2, 0.2, 1.8, "glassish",
                  False)
        mk("speaker", 1, cx + 1.8, cy + 1.2, 0.0, 180)
        mk("speaker", 2, cx + 1.8, cy - 1.2, 0.0, 180)
    elif unit == "5A":  # Nadia: plans over contradictory plans
        _furn_box(furniture, "5A_plantable", cx - 1.35, cy - 0.6, 2.0, 1.2,
                  0.78, 0.05, "floor_oak", False)
        _furn_box(furniture, "5A_planshelf", x0 + 0.4, y0 + 3.6, 1.6, 0.4,
                  0.0, 1.4, "trim", False)
        mk("lamp", 1, cx + 0.6, cy, 0.83)
    elif unit == "6A":  # Sacha: capture wall, framed for camera
        _furn_box(furniture, "6A_deskwall", x0 + 0.4, cy - 1.4, 0.8, 2.8,
                  0.72, 0.05, "trim", False)
        for i in range(3):
            mk("monitor", i + 1, x0 + 0.8, cy - 1.0 + i * 1.0, 0.78, -90)
        mk("boxfan", 1, x1 - 1.2, y0 + 1.0, 0.25, 135)
    elif unit == "3C":  # vacant, water-damaged: exposed framing, debris
        for i, sx in enumerate([5.95, 8.00, 9.10, 10.20, 11.00, 13.00]):
            _furn_box(furniture, "3C_stud%d" % i, sx, y1 - 3.42,
                      0.08, 0.08, 0.0, WALL_H, "trim", False)
        _furn_box(furniture, "3C_debris", cx - 0.8, cy - 1.5, 1.6, 1.0,
                  0.0, 0.25, "slab", False)
    elif unit == "5D":  # fire-damaged: charred remnants
        _furn_box(furniture, "5D_char1", cx - 0.2, cy, 1.2, 0.8, 0.0, 0.4,
                  "slab", False)
        _furn_box(furniture, "5D_char2", x1 - 2.0, y0 + 1.2, 0.9, 0.6, 0.0,
                  0.3, "slab", False)
    elif unit == "6D":  # landlord storage: crate grid
        for i in range(8):
            _furn_box(furniture, "6D_crate%d" % i,
                      x0 + 3.7 + (i % 3) * 1.5, y0 + 1.0 + (i // 3) * 1.6,
                      1.0, 1.0, 0.0, 0.9 + 0.4 * ((i * 7) % 3), "trim",
                      False)


def apartment_4b(z, walls, rooms, markers, furniture):
    """Player apartment to the brief's Section 4 plan, fitted to the B
    stack envelope: entry vestibule, bathroom, closet, galley kitchen,
    main room, sleeping alcove. The workstation faces the corridor
    utility wall; the radiator sits under the rear window; the
    impossible-door marker lives between them.
    """
    x0, y0, x1, y1 = STACK_RECTS["B"]      # -13.65, 2.67, -5.51, 9.65
    bx = -7.71                             # service band west face
    # entry vestibule around the corridor door at y0 + 1.2
    walls.append(wall((bx, y0 + 0.60), (x1, y0 + 0.60), PART_T, WALL_H, z, []))
    walls.append(wall((bx, y0 + 0.60), (bx, y0 + 1.85), PART_T, WALL_H, z,
                      [door(0.62)]))
    # bathroom (2.20 x 2.40) north of the vestibule
    walls.append(wall((bx, y0 + 1.85), (x1, y0 + 1.85), PART_T, WALL_H, z,
                      [door(1.10)]))
    walls.append(wall((bx, y0 + 1.85), (bx, y0 + 4.25), PART_T, WALL_H, z, []))
    walls.append(wall((bx, y0 + 4.25), (x1, y0 + 4.25), PART_T, WALL_H, z, []))
    # closet with sliding-door opening
    walls.append(wall((-6.66, y0 + 4.25), (-6.66, y0 + 6.05), PART_T,
                      WALL_H, z, [door(0.90)]))
    walls.append(wall((-6.66, y0 + 6.05), (x1, y0 + 6.05), PART_T, WALL_H,
                      z, []))
    # sleeping alcove at the NW corner, galley kitchen beside it
    ax = x0 + 2.75
    ay = y1 - 3.15
    walls.append(wall((ax, ay), (ax, y1), PART_T, WALL_H, z,
                      [{"type": "door", "at": 1.60, "w": 1.20, "h": 2.03,
                        "sill": 0.0}]))
    walls.append(wall((x0, ay), (x0 + 1.2, ay), PART_T, WALL_H, z, []))
    rooms += [
        {"id": "F04_B_VESTIBULE", "unit": "4B",
         "rect": [bx, y0 + 0.60, x1, y0 + 1.85], "kind": "vestibule"},
        {"id": "F04_B_BATH", "unit": "4B",
         "rect": [bx, y0 + 1.85, x1, y0 + 4.25], "kind": "bathroom"},
        {"id": "F04_B_CLOSET", "unit": "4B",
         "rect": [-6.66, y0 + 4.25, x1, y0 + 6.05], "kind": "closet"},
        {"id": "F04_B_KITCHEN", "unit": "4B",
         "rect": [ax, ay, -7.71, y1], "kind": "kitchen"},
        {"id": "F04_B_MAIN", "unit": "4B",
         "rect": [x0, y0, bx, ay], "kind": "living"},
        {"id": "F04_B_ALCOVE", "unit": "4B",
         "rect": [x0, ay, ax, y1], "kind": "alcove"},
    ]
    bath_fixtures(furniture, "4B", [bx, y0 + 1.85, x1, y0 + 4.25], "n")
    furniture += [
        {"id": "desk", "rect": [-8.45, 4.95, -7.87, 6.25], "z0": 0.72,
         "h": 0.04, "mat": "floor_oak"},
        {"id": "desk_legs", "rect": [-8.40, 5.00, -8.35, 6.20], "z0": 0.0,
         "h": 0.72, "mat": "metal"},
        {"id": "chair", "rect": [-9.05, 5.35, -8.60, 5.85], "z0": 0.42,
         "h": 0.06, "mat": "trim"},
        {"id": "bed", "rect": [-13.40, 6.90, -12.15, 9.50], "z0": 0.15,
         "h": 0.32, "mat": "trim"},
        {"id": "kitchen_counter", "rect": [-10.70, 9.05, -8.85, 9.55],
         "z0": 0.0, "h": 0.90, "mat": "trim"},
        {"id": "couch", "rect": [-12.80, 3.60, -11.30, 4.35], "z0": 0.12,
         "h": 0.42, "mat": "trim"},
    ]
    markers += [
        {"kind": "radiator", "id": "F04_B_RADIATOR_01", "unit": "4B",
         "pos": [-8.55, y1 - 0.30, z], "yaw_deg": 180, "network": "heating",
         "riser": "H-B"},
        {"kind": "lamp", "id": "F04_B_LAMP_01", "unit": "4B",
         "pos": [-8.15, 6.00, z + 0.76], "yaw_deg": 0,
         "network": "electrical"},
        {"kind": "monitor", "id": "F04_B_MONITOR_01", "unit": "4B",
         "pos": [-8.05, 5.50, z + 0.76], "yaw_deg": -90,
         "network": "electrical"},
        {"kind": "toaster", "id": "F04_B_TOASTER_01", "unit": "4B",
         "pos": [-9.70, 9.30, z + 0.90], "yaw_deg": 90,
         "network": "electrical"},
        {"kind": "fridge", "id": "F04_B_FRIDGE_01", "unit": "4B",
         "pos": [-8.30, 9.20, z], "yaw_deg": 90, "network": "electrical"},
        {"kind": "boxfan", "id": "F04_B_BOXFAN_01", "unit": "4B",
         "pos": [-13.20, 3.40, z + 0.25], "yaw_deg": 45,
         "network": "electrical"},
        {"kind": "door_anomaly", "id": "F04_B_DOOR_ANOMALY", "unit": "4B",
         "pos": [-7.20, y0 + 4.32, z], "yaw_deg": 0,
         "network": "structural"},
        {"kind": "desk_zone", "id": "F04_B_DESK_ZONE", "unit": "4B",
         "pos": [-8.80, 5.60, z], "yaw_deg": 0},
        {"kind": "kettle", "id": "F04_B_KETTLE_01", "unit": "4B",
         "pos": [-10.50, 9.30, z + 0.92], "yaw_deg": 0,
         "network": "electrical"},
        {"kind": "wall_clock", "id": "F04_B_CLOCK_01", "unit": "4B",
         "pos": [-7.78, 4.60, z + 1.70], "yaw_deg": -90,
         "network": "electrical"},
        {"kind": "smoke_detector", "id": "F04_B_SMOKEDET_01", "unit": "4B",
         "pos": [-9.50, 5.50, z + 2.62], "yaw_deg": 0,
         "network": "electrical"},
        {"kind": "exhaust_fan", "id": "F04_B_EXHFAN_01", "unit": "4B",
         "pos": [-6.60, y0 + 3.00, z + 2.55], "yaw_deg": 0,
         "network": "electrical"},
        {"kind": "ceiling_light", "id": "F04_B_CEILLIGHT_01", "unit": "4B",
         "pos": [-10.60, 4.60, z + 2.60], "yaw_deg": 0,
         "network": "electrical"},
    ]
    furnish_4b_detail(furniture, y0, y1, x0)


## Section 4 "highest detail": the lived-in texture of the player's rooms.
def furnish_4b_detail(furniture, y0, y1, x0):
    def fb(fid, rect, z0, h, mat="trim"):
        furniture.append({"id": "4B_" + fid, "rect": list(rect), "z0": z0,
                          "h": h, "mat": mat})

    # kitchen: uppers, sink rim + faucet, crockery
    fb("uppers", (-10.70, 9.40, -8.85, 9.64), 1.50, 0.72)
    fb("sink_rim", (-10.18, 9.12, -9.68, 9.50), 0.88, 0.05, "metal")
    fb("faucet_riser", (-9.96, 9.46, -9.90, 9.52), 0.90, 0.28, "metal")
    fb("faucet_spout", (-9.96, 9.30, -9.90, 9.50), 1.14, 0.04, "metal")
    fb("mugs", (-9.62, 9.15, -9.40, 9.32), 0.90, 0.11)
    fb("plates", (-9.30, 9.16, -9.06, 9.36), 0.90, 0.07)
    # venetian blinds: two west windows + the rear window
    for wi, wc in enumerate((y0 + (y1 - y0) * 0.30, y0 + (y1 - y0) * 0.70)):
        for k in range(8):
            fb("blindw%d_%d" % (wi, k),
               (-13.58, wc - 0.65, -13.53, wc + 0.65),
               0.92 + k * 0.11, 0.03)
    for k in range(8):
        fb("blindr_%d" % k, (-10.24, 9.52, -8.92, 9.57),
           0.92 + k * 0.11, 0.03)
    # main room: rug, bookshelf with rows, desk clutter, power strip
    fb("rug", (-12.40, 3.40, -8.70, 6.00), 0.0, 0.015, "face_brick")
    fb("bookshelf", (-11.20, 2.75, -9.70, 3.07), 0.0, 1.55)
    for r, zr in enumerate((0.30, 0.76, 1.22)):
        fb("books%d" % r, (-11.12, 2.79, -9.80, 3.03), zr, 0.26, "timber")
    fb("keyboard", (-8.30, 5.35, -8.05, 5.75), 0.762, 0.02, "metal")
    fb("mouse", (-8.02, 5.50, -7.96, 5.58), 0.762, 0.025, "metal")
    fb("microphone", (-8.38, 5.95, -8.32, 6.01), 0.762, 0.16, "metal")
    fb("headset_stand", (-8.40, 5.02, -8.30, 5.12), 0.762, 0.20)
    fb("power_strip", (-7.92, 4.70, -7.78, 5.05), 0.0, 0.05, "metal")
    # alcove: bed frame posts, headboard, nightstand
    for px, py in ((-13.40, 6.92), (-12.21, 6.92), (-13.40, 9.42),
                   (-12.21, 9.42)):
        fb("bedpost_%d_%d" % (int(px * 10), int(py * 10)),
           (px, py, px + 0.06, py + 0.06), 0.0, 0.52, "timber")
    fb("headboard", (-13.40, 9.44, -12.15, 9.50), 0.15, 0.78, "timber")
    fb("nightstand", (-12.05, 9.10, -11.68, 9.48), 0.0, 0.55)
    # bathroom: shower riser + head, mirror over the sink
    fb("shower_riser", (-7.52, y0 + 4.12, -7.46, y0 + 4.18), 0.14, 1.90,
       "metal")
    fb("shower_head", (-7.62, y0 + 3.98, -7.42, y0 + 4.18), 2.00, 0.05,
       "metal")
    fb("mirror", (-6.05, y0 + 4.17, -5.60, y0 + 4.21), 1.35, 0.60,
       "glassish")


# ---------------------------------------------------------------- floors

def ring_and_cores(floor_id, z, walls, entry_doors=True):
    """Corridor ring, court walls, core walls, shaft walls for one level."""
    h = WALL_H
    # court walls (light shaft) with small court windows on E/W
    walls.append(wall((-COURT, -COURT), (-COURT, COURT), CORR_T, F2F, z,
                      [window(COURT, WIN_COURT)], mat="common_brick"))
    walls.append(wall((COURT, -COURT), (COURT, COURT), CORR_T, F2F, z,
                      [window(COURT, WIN_COURT)], mat="common_brick"))
    # corridor inner walls (x) run past court and cores
    walls.append(wall((-XCI, -YCN), (-XCI, YCN), CORR_T, h, z, [], mat="plaster"))
    walls.append(wall((XCI, -YCN), (XCI, YCN), CORR_T, h, z, [], mat="plaster"))
    # core side walls close the court band between court and corridor walls
    for cy0, cy1 in ((-CORE_Y1, -CORE_Y0), (CORE_Y0, CORE_Y1)):
        walls.append(wall((-COURT, cy0), (-COURT, cy1), CORR_T, h, z, []))
        walls.append(wall((COURT, cy0), (COURT, cy1), CORR_T, h, z, []))
    # core south wall: archway from the corridor into the stair hall
    south_openings = []
    if floor_id in FRONT["levels"]:
        south_openings.append({"type": "door", "at": abs(1.90 - (-COURT)),
                               "w": ARCH["w"], "h": ARCH["h"], "sill": 0.0,
                               "leaf": "none"})
    walls.append(wall((-COURT, -CORE_Y1), (COURT, -CORE_Y1), CORR_T, h, z,
                      south_openings))
    walls.append(wall((-COURT, -CORE_Y0), (COURT, -CORE_Y0), CORR_T, h, z, []))
    # core north wall: archway into the service stair hall
    north_openings = []
    if floor_id in SERVICE["levels"]:
        north_openings.append({"type": "door", "at": abs(1.90 - (-COURT)),
                               "w": ARCH["w"], "h": ARCH["h"], "sill": 0.0,
                               "leaf": "none"})
    walls.append(wall((-COURT, CORE_Y1), (COURT, CORE_Y1), CORR_T, h, z,
                      north_openings))
    court_south = [door(COURT, DOOR_INT, "open")] if floor_id == "F01" else []
    # court south wall carries the elevator door onto the south hall
    css = []
    if floor_id in ELEV["stops"]:
        css.append({"type": "door", "at": abs(1.425 - (-COURT)),
                    "w": ELEV["door_w"], "h": 2.10, "sill": 0.0,
                    "leaf": "none"})
    walls.append(wall((-COURT, CORE_Y0), (COURT, CORE_Y0), CORR_T, h, z, []))
    walls.append(wall((-COURT, -COURT), (COURT, -COURT), CORR_T, h, z, css))
    walls.append(wall((-COURT, COURT), (COURT, COURT), CORR_T, h, z, court_south))
    # corridor outer walls with apartment entry doors
    for sx, stacks in ((-1, ("A", "B")), (1, ("D", "C"))):
        openings = []
        if entry_doors:
            for stack in stacks:
                if floor_id == "F02" and stack == "D":
                    continue  # 2D is sealed: no doorway at all
                x0, y0, x1, y1 = STACK_RECTS[stack]
                # entries thread between each archetype's bath/office blocks
                if stack == "A":
                    ey = y1 - 1.2
                elif stack == "D":
                    ey = y0 + 3.40 + 2.94
                elif stack == "B" and floor_id != "F04":
                    ey = y0 + 3.30  # clear of the generic-B bath block
                else:
                    ey = y0 + 1.2
                leaf = "locked" if (floor_id == "F06" and stack == "D") \
                        else "closed"
                openings.append(door(abs(ey - (-Y_IN)), DOOR_ENTRY, leaf))
        if sx < 0 and floor_id in ("F02", "F03", "F04", "F05", "F06"):
            # locked former-suite storage between A and B
            openings.append(door(abs(1.11 - (-Y_IN)), DOOR_SERV, "locked"))
        walls.append(wall((sx * XCO, -Y_IN), (sx * XCO, Y_IN), CORR_T, h, z,
                          openings))
    # elevator shaft walls at the court edge (south face = court wall,
    # which carries the hall door)
    ex0, ey0, ex1, ey1 = ELEV["shaft"]
    walls.append(wall((ex0, ey0), (ex0, ey1), CORR_T, h, z, [], mat="concrete"))
    walls.append(wall((ex1, ey0), (ex1, ey1), CORR_T, h, z, [], mat="concrete"))
    walls.append(wall((ex0, ey1), (ex1, ey1), CORR_T, h, z, [], mat="concrete"))


# Empirical masonry rule (1920s codes): ~12 in walls for the upper
# stories, 16 in below; the outer face stays flush at the property plane
# and the step happens inside.
def ext_t(floor_id):
    return {"B1": 0.41, "F01": 0.41, "F02": 0.35, "F03": 0.35}.get(floor_id, 0.30)


def exterior(floor_id, z, walls):
    h = F2F  # bearing walls run continuously past the joist/slab zone
    t = ext_t(floor_id)
    off = t / 2.0
    for stack, rect in STACK_RECTS.items():
        x0, y0, x1, y1 = rect
        west = stack in ("A", "B")
        wx = -(14.0 - off) if west else (14.0 - off)
        ln = y1 - y0
        wo = [window(ln * 0.30), window(ln * 0.70)]
        walls.append(wall((wx, y0), (wx, y1), t, h, z, wo,
                          mat="common_brick"))
        street = stack in ("A", "D")
        eyl = -(10.0 - off) if street else (10.0 - off)
        end_openings = [window((x1 - x0) * 0.5)]
        if stack == "B" and floor_id in ("F02", "F03", "F04", "F05", "F06"):
            # kitchen door onto the rear wooden porch (the Midwest second
            # egress since the 1906 two-exit rule)
            end_openings.append(door(abs(-8.30 - x0), DOOR_INT))
        walls.append(wall((x0, eyl), (x1, eyl), t, h, z, end_openings,
                          mat="face_brick" if street else "common_brick"))
    # street / rear walls across the middle band (corridor ends)
    s_open = [window(X_IN - 2.5), window(X_IN + 2.5)]
    if floor_id == "F01":
        s_open.append(door(X_IN, DOOR_ENTRY))  # street entrance at x = 0
    walls.append(wall((-X_IN, -(10.0 - off)), (X_IN, -(10.0 - off)), t, h, z,
                      s_open, mat="face_brick"))
    walls.append(wall((-X_IN, 10.0 - off), (X_IN, 10.0 - off), t, h, z,
                      [window(X_IN - 2.5), window(X_IN + 2.5)],
                      mat="common_brick"))


def split_walls(z, walls):
    # west: A | former-suite storage | B ; east: D | C
    walls.append(wall((-X_IN, -0.39), (-XAW, -0.39), PART_T, WALL_H, z, []))
    walls.append(wall((-X_IN, 2.61), (-XAW, 2.61), PART_T, WALL_H, z, []))
    walls.append(wall((XAW, -0.94), (X_IN, -0.94), PART_T, WALL_H, z, []))


def slab(floor_id, z, holes):
    return {"rect": [-14.0, -10.0, 14.0, 10.0], "z_top": z, "t": SLAB_T,
            "holes": [list(h) for h in holes]}


def chimney_block(floor_id, z, walls, h=None):
    cx0, cy0, cx1, cy1 = CHIMNEY
    walls.append(wall((cx0, (cy0 + cy1) / 2.0), (cx1, (cy0 + cy1) / 2.0),
                      cy1 - cy0, h if h else WALL_H, z, [],
                      mat="common_brick"))


def stair_holes(floor_id):
    holes = []
    if floor_id != "B1":
        holes.append(CHIMNEY)
    if floor_id in FRONT["levels"][1:]:
        holes.append(FRONT["hole"])
    if floor_id in SERVICE["levels"][1:]:
        holes.append(SERVICE["hole"])
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
                          [door(abs(1.35 - hx0), DOOR_SERV, "open")]))
        ex0, ey0, ex1, ey1 = ELEV["shaft"]
        m = 0.45
        walls.append(wall((ex0 - m, ey0 - m), (ex0 - m, ey1 + m), CORR_T, 2.4, z,
                          [], mat="concrete"))
        walls.append(wall((ex1 + m, ey0 - m), (ex1 + m, ey1 + m), CORR_T, 2.4, z,
                          [], mat="concrete"))
        walls.append(wall((ex0 - m, ey1 + m), (ex1 + m, ey1 + m), CORR_T, 2.4, z,
                          [], mat="concrete"))
        walls.append(wall((ex0 - m, ey0 - m), (ex1 + m, ey0 - m), CORR_T, 2.4, z,
                          [door(1.0, DOOR_SERV, "open")], mat="concrete"))
        chimney_block(floor_id, z, walls, 2.2)
        furniture.append({"id": "chimney_cap", "rect": [9.45, 9.00, 10.55,
                          9.75], "z0": 2.2, "h": 0.15, "mat": "limestone"})
        for rid, rect in (("s", (-14.10, -10.10, 14.10, -9.90)),
                          ("n", (-14.10, 9.90, 14.10, 10.10)),
                          ("w", (-14.10, -10.10, -13.90, 10.10)),
                          ("e", (13.90, -10.10, 14.10, 10.10))):
            furniture.append({"id": "coping_%s" % rid, "rect": list(rect),
                              "z0": 1.10, "h": 0.08, "mat": "limestone"})
        for i in range(3):  # corbelled cornice under the street parapet
            furniture.append({"id": "cornice_%d" % i,
                              "rect": [-14.04 - i * 0.03, -10.04 - i * 0.03,
                                       14.04 + i * 0.03, -9.96],
                              "z0": -0.55 + i * 0.15, "h": 0.13,
                              "mat": "limestone" if i == 2 else "face_brick"})
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
                openings.append(door(abs((y0 + y1) / 2 - (-Y_IN)), DOOR_SERV, "open"))
            walls.append(wall((sx * XCO, -Y_IN), (sx * XCO, Y_IN), CORR_T,
                              WALL_H, z, openings))
        for stack, name in names.items():
            rooms.append({"id": "B1_%s" % name, "rect": list(STACK_RECTS[stack]),
                          "kind": name.lower()})
        # visible structure: timber beam lines on brick piers carry F01
        for sx in (-1, 1):
            for by_ in (-4.8, 4.8):
                bx0, bx1 = (5.71, 13.45) if sx > 0 else (-13.45, -5.71)
                furniture.append({"id": "beam_%d_%d" % (sx, int(by_)),
                                  "rect": [bx0, by_ - 0.15, bx1, by_ + 0.15],
                                  "z0": 2.27, "h": 0.35, "mat": "timber"})
                px = bx0 + 1.25
                while px < bx1 - 0.3:
                    furniture.append({"id": "pier_%d_%d_%d" % (sx, int(by_),
                                      int(px * 10)),
                                      "rect": [px, by_ - 0.19, px + 0.38,
                                               by_ + 0.19],
                                      "z0": 0.0, "h": 2.27,
                                      "mat": "common_brick"})
                    px += 2.7
        # coal bin with alley chute, feeding the boiler
        walls.append(wall((11.30, 0.30), (11.30, 2.70), PART_T, WALL_H, z,
                          [door(1.2, DOOR_SERV, "open")]))
        walls.append(wall((11.30, 0.30), (X_IN, 0.30), PART_T, WALL_H, z, []))
        walls.append(wall((11.30, 2.70), (X_IN, 2.70), PART_T, WALL_H, z, []))
        rooms.append({"id": "B1_COAL", "rect": [11.30, 0.30, X_IN, 2.70],
                      "kind": "coal"})
        furniture.append({"id": "coal_pile", "rect": [12.4, 0.6, 13.4, 2.4],
                          "z0": 0.0, "h": 0.75, "mat": "slab"})
        chimney_block(floor_id, z, walls)
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
        for rid, rect in (("s1", (-14.10, -10.10, -0.70, -9.96)),
                          ("s2", (0.70, -10.10, 14.10, -9.96)),
                          ("w", (-14.10, -10.10, -13.96, 10.10)),
                          ("e", (13.96, -10.10, 14.10, 10.10))):
            furniture.append({"id": "water_table_%s" % rid, "rect": list(rect),
                              "z0": 0.0, "h": 0.45, "mat": "limestone"})
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
    chimney_block(floor_id, z, walls)
    porch(floor_id, z, furniture)
    if floor_id == "F02":
        # limestone belt course at the second-floor line, street facade
        furniture.append({"id": "belt_course", "rect": [-14.08, -10.08,
                          14.08, -9.97], "z0": -0.06, "h": 0.24,
                          "mat": "limestone"})
    rooms.append({"id": "%s_WSTOR" % floor_id, "rect": list(WSTOR_RECT),
                  "kind": "storage"})
    _furn_box(furniture, "%s_stor_crates" % floor_id, -12.9, 0.2, 2.2, 1.4,
              0.0, 1.1, "trim", False)
    rooms.append({"id": "%s_CORRIDOR" % floor_id,
                  "rect": [-XCO, -Y_IN, XCO, Y_IN], "kind": "corridor"})
    markers.append({"kind": "flue_breast", "id": "%s_FLUE_BREAST" % floor_id,
                    "unit": floor_id + "C",
                    "pos": [10.0, 8.95, z], "yaw_deg": 180, "network": "flue"})
    markers.append({"kind": "porch_deck", "id": "%s_PORCH_DECK" % floor_id,
                    "pos": [-9.15, 10.70, z], "yaw_deg": 0,
                    "network": "structural"})
    markers.append({"kind": "corridor_light", "id": "%s_CORRLIGHT_S" % floor_id,
                    "pos": [0.0, -8.3, z], "yaw_deg": 0, "network": "electrical"})
    markers.append({"kind": "corridor_light", "id": "%s_CORRLIGHT_N" % floor_id,
                    "pos": [0.0, 8.3, z], "yaw_deg": 0, "network": "electrical"})
    return floor




def collect_door_markers(fl):
    """Every door opening with a leaf becomes a spawnable hinged door."""
    n = 0
    for w in fl["walls"]:
        for o in w["openings"]:
            if o.get("type") != "door" or o.get("leaf", "closed") == "none":
                continue
            ax, ay = w["a"]
            bx_, by_ = w["b"]
            horizontal = abs(by_ - ay) < 1e-6
            start = min(ax, bx_) if horizontal else min(ay, by_)
            cross = ay if horizontal else ax
            hinge = start + o["at"] - o["w"] / 2.0
            pos = [hinge, cross, w["z"]] if horizontal \
                    else [cross, hinge, w["z"]]
            n += 1
            fl["markers"].append({
                "kind": "door", "id": "%s_DOOR_%02d" % (fl["id"], n),
                "pos": pos, "yaw_deg": 0 if horizontal else -90,
                "w": o["w"], "h": o["h"],
                "leaf": o.get("leaf", "closed")})

# ---------------------------------------------------------------- stairs

# Rear wooden porch stack (the Midwest second egress): posts, decks with
# railings at each floor, and steep period-accurate runs between decks.
# The runs are physical but too steep for the step-up - as in life, you
# take them seriously or not at all.
def porch(floor_id, z, furniture):
    if floor_id not in ("F02", "F03", "F04", "F05", "F06"):
        return

    def fb(fid, rect, z0, h, mat="timber"):
        furniture.append({"id": fid, "rect": list(rect), "z0": z0, "h": h,
                          "mat": mat})

    fb("porch_deck", (-10.60, 10.05, -7.70, 11.35), -0.10, 0.14)
    for rid, rect in (("n", (-10.60, 11.27, -7.70, 11.35)),
                      ("w", (-10.60, 10.05, -10.52, 11.35)),
                      ("e", (-7.78, 10.05, -7.70, 11.35))):
        fb("porch_rail_%s_top" % rid, rect, 0.99, 0.08)
        fb("porch_rail_%s_mid" % rid, rect, 0.50, 0.06)
    for i in range(8):  # steep run down the facade to the deck below
        fb("porch_step%d" % i, (-7.62 + i * 0.29, 10.15,
                                -7.36 + i * 0.29, 11.15),
           -0.10 - (i + 1) * 0.40, 0.12)
    if floor_id == "F02":
        for px in (-10.62, -7.72):
            for py in (10.08, 11.24):
                fb("porch_post_%d_%d" % (int(px * 10), int(py * 10)),
                   (px, py, px + 0.12, py + 0.12), -3.30, 16.20)


def stair_geometry(st):
    """Dog-leg off the hall: flight 1 departs the hall edge climbing west,
    half-landing (full depth, width >= stair width), flight 2 returns east
    and arrives flush onto the next floor's hall slab."""
    flights = []
    lvls = st["levels"]
    s1, s2 = st["strips"]
    inner1 = s1[1] if s1[1] <= s2[0] else s1[0]
    inner2 = s2[0] if s1[1] <= s2[0] else s2[1]
    for i in range(len(lvls) - 1):
        z0, z1 = LEVELS[lvls[i]], LEVELS[lvls[i + 1]]
        risers = int(round((z1 - z0) / st["rise"]))
        n1 = risers // 2 + risers % 2
        n2 = risers - n1
        lx1 = HALL_X - n1 * st["tread"]
        lx0 = lx1 - st["width"]
        flights.append({"kind": "flight", "z0": z0, "rise": st["rise"],
                        "tread": st["tread"], "n": n1, "dir": -1,
                        "x_start": HALL_X, "y0": s1[0], "y1": s1[1],
                        "rail_y": inner1})
        lz = z0 + n1 * st["rise"]
        flights.append({"kind": "landing", "z": lz,
                        "rect": [lx0, min(s1[0], s2[0]), lx1,
                                 max(s1[1], s2[1])]})
        flights.append({"kind": "flight", "z0": lz, "rise": st["rise"],
                        "tread": st["tread"], "n": n2, "dir": 1,
                        "x_start": lx1, "y0": s2[0], "y1": s2[1],
                        "rail_y": inner2})
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
        damping = 0.08 if network == "flue" else 0.22
        nodes.append({"id": nid, "pos": [round(p, 3) for p in pos],
                      "room": room, "network": network,
                      "frequency_band": list(band), "delay_ms": delay,
                      "damping": damping, "infection_receptivity": recv,
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
            elif m["kind"] in ("lamp", "monitor", "toaster", "fridge",
                               "boxfan", "speaker", "kettle", "wall_clock",
                               "smoke_detector", "exhaust_fan",
                               "ceiling_light"):
                add(m["id"], m["pos"], "electrical", m.get("unit", ""), 0.75,
                    (60, 8000), 4)
                edges.append((m["id"], "%s_CORRLIGHT_S" % fl["id"]))
                if fl["id"] in ("B1", "F01"):
                    edges.append((m["id"], "B1_ELECTRICAL_HUB"))
            elif m["kind"] == "flue_breast":
                # chimney breast: the room-side face of the flue
                add(m["id"], m["pos"], "flue", m.get("unit", ""), 0.9,
                    (40, 1200), 15)
                edges.append((m["id"], "%s_FLUE" % fl["id"]))
            elif m["kind"] == "porch_deck":
                # wood deck bolted to the rear wall: lossy, creaky path
                add(m["id"], m["pos"], "structural", fl["id"], 0.7,
                    (30, 900), 22)
                edges.append((m["id"], "%s_B_RADIATOR_01" % fl["id"]))
            elif m["kind"] == "corridor_light":
                add(m["id"], [m["pos"][0], m["pos"][1], m["pos"][2] + 2.5],
                    "electrical", fl["id"], 0.55, (100, 9000), 4)
            elif m["kind"] == "door_anomaly":
                add(m["id"], [m["pos"][0], m["pos"][1], m["pos"][2] + 1.0],
                    "structural", m.get("unit", ""), 0.95, (20, 200), 60)
                edges.append((m["id"], "F04_B_RADIATOR_01"))
    # chimney flue: a masonry speaking tube from the boiler to the sky —
    # fast, barely damped, six stories in ~70 ms
    add("B1_FLUE_BASE", [9.9, 9.375, -1.9], "flue", "B1_BOILER", 0.6,
        (30, 1500), 6)
    add("ROOF_FLUE_TOP", [10.0, 9.375, 21.3], "flue", "ROOF", 0.8,
        (30, 1500), 12)
    edges.append(("B1_BOILER_01", "B1_FLUE_BASE"))
    prev_f = "B1_FLUE_BASE"
    for fid in ("F01", "F02", "F03", "F04", "F05", "F06"):
        add("%s_FLUE" % fid, [10.0, 9.375, LEVELS[fid] + 1.5], "flue", fid,
            0.5, (30, 1500), 12)
        edges.append(("%s_FLUE" % fid, prev_f))
        prev_f = "%s_FLUE" % fid
    edges.append(("ROOF_FLUE_TOP", prev_f))
    # porch structure: ground post base up the deck chain
    add("PORCH_BASE", [-9.15, 10.70, 0.2], "structural", "F01", 0.5,
        (30, 900), 15)
    prev_p = "PORCH_BASE"
    for fid in ("F02", "F03", "F04", "F05", "F06"):
        edges.append(("%s_PORCH_DECK" % fid, prev_p))
        prev_p = "%s_PORCH_DECK" % fid
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
    "speaker": {"minimum_action_interval": 0.12, "maximum_action_rate": 8,
                "available_mechanical_events": ["thump", "loop_pulse"],
                "preferred_subdivision": 1, "timing_drift": 0.01,
                "response_latency": 0.03, "normal_function_priority": 1.0,
                "infection_receptivity": 0.8},
    "kettle": {"minimum_action_interval": 0.4, "maximum_action_rate": 2,
               "available_mechanical_events": ["element_tick", "whistle_on"],
               "preferred_subdivision": 1, "timing_drift": 0.02,
               "response_latency": 0.10, "normal_function_priority": 1.0,
               "infection_receptivity": 0.65},
    "wall_clock": {"minimum_action_interval": 0.45, "maximum_action_rate": 2,
                   "available_mechanical_events": ["tick", "tempo_drift"],
                   "preferred_subdivision": 1, "timing_drift": 0.0,
                   "response_latency": 0.01, "normal_function_priority": 1.0,
                   "infection_receptivity": 0.8},
    "smoke_detector": {"minimum_action_interval": 4.0,
                       "maximum_action_rate": 1,
                       "available_mechanical_events": ["chirp"],
                       "preferred_subdivision": 0.25, "timing_drift": 0.0,
                       "response_latency": 0.02,
                       "normal_function_priority": 1.0,
                       "infection_receptivity": 0.45},
    "exhaust_fan": {"minimum_action_interval": 0.4, "maximum_action_rate": 3,
                    "available_mechanical_events": ["whir_waver"],
                    "preferred_subdivision": 0.5, "timing_drift": 0.05,
                    "response_latency": 0.15,
                    "normal_function_priority": 1.0,
                    "infection_receptivity": 0.5},
    "ceiling_light": {"minimum_action_interval": 0.06,
                      "maximum_action_rate": 12,
                      "available_mechanical_events": ["filament_surge"],
                      "preferred_subdivision": 2, "timing_drift": 0.0,
                      "response_latency": 0.01,
                      "normal_function_priority": 1.0,
                      "infection_receptivity": 0.7},
    "flue_breast": {"minimum_action_interval": 0.14, "maximum_action_rate": 7,
                    "available_mechanical_events": ["flue_knock", "draft"],
                    "preferred_subdivision": 1, "timing_drift": 0.008,
                    "response_latency": 0.02, "normal_function_priority": 1.0,
                    "infection_receptivity": 0.9},
    "porch_deck": {"minimum_action_interval": 0.22, "maximum_action_rate": 4,
                   "available_mechanical_events": ["creak", "board_knock"],
                   "preferred_subdivision": 1, "timing_drift": 0.035,
                   "response_latency": 0.06, "normal_function_priority": 1.0,
                   "infection_receptivity": 0.7},
    "door_anomaly": {"minimum_action_interval": 0.10, "maximum_action_rate": 8,
                     "available_mechanical_events": ["seam_glow"],
                     "preferred_subdivision": 1, "timing_drift": 0.0,
                     "response_latency": 0.0, "normal_function_priority": 0.0,
                     "infection_receptivity": 1.0},
}

MATERIAL_CATALOG = {
    "face_brick": {"base_color": [0.38, 0.16, 0.12, 1.0], "roughness": 0.82},
    "common_brick": {"base_color": [0.62, 0.42, 0.31, 1.0], "roughness": 0.88},
    "limestone": {"base_color": [0.78, 0.75, 0.67, 1.0], "roughness": 0.6},
    "timber": {"base_color": [0.43, 0.32, 0.22, 1.0], "roughness": 0.75},
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
    for fl in floors:
        collect_door_markers(fl)
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
    for fl in layout["floors"]:
        # only furniture in the door's vertical zone obstructs a swing:
        # walkable surfaces (top <= 0.25, e.g. porch decks/thresholds) and
        # overhead pieces (bottom >= 2.0) do not block
        furn = [f["rect"] for f in fl.get("furniture", [])
                if f.get("z0", 0.0) < 2.0
                and f.get("z0", 0.0) + f.get("h", 0.0) > 0.25]
        for m in fl["markers"]:
            if m["kind"] != "door" or m.get("leaf") == "none":
                continue
            w = m["w"]
            px, py = m["pos"][0], m["pos"][1]
            if m["yaw_deg"] == 0:      # door in a horizontal wall
                squares = [(px, py, px + w, py + w),
                           (px, py - w, px + w, py)]
            else:                       # vertical wall
                squares = [(px, py, px + w, py + w),
                           (px - w, py, px, py + w)]
            for fr in furn:
                for s in squares:
                    if (s[0] < fr[2] - 0.02 and fr[0] < s[2] - 0.02 and
                            s[1] < fr[3] - 0.02 and fr[1] < s[3] - 0.02):
                        problems.append("door %s swing blocked by furniture %s"
                                        % (m["id"], fr))
                        break
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
