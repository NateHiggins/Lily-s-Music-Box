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
import random

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
WIN_B1 = {"w": 0.80, "h": 0.50, "sill": 1.90}  # small areaway lights
CHIMNEY = (9.55, 9.10, 10.45, 9.65)      # coal-boiler flue, NE rear

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

# THE ATRIUM STAIR: one grand open switchback filling the light court,
# basement to roof, wrapped around a square open eye. Per floor climb:
# a wide west flight rises off the floor-level south deck to a full-width
# north landing at the half level, then the east flight returns south,
# arriving on the next floor's deck — a squared helix you can look up (or
# down) through the eye of, all the way from the lobby to the skylight.
# 20 risers/floor (0.160 rise, 0.324 going, 2R+G = 64.4 cm — grand-stair
# proportions). Flight and landing depth 1.70 m; the eye is 2.92 m square.
# Every deck opens south through the court wall into the elevator hall.
ATRIUM = {"id": "atrium",
          "well": (-COURT + 0.09, -COURT + 0.09,
                   COURT - 0.09, COURT - 0.09),   # flush with wall faces
          "width": 1.70, "risers": 20, "rise": F2F / 20.0,
          "levels": ["B1", "F01", "F02", "F03", "F04", "F05", "F06",
                     "ROOF"]}
ELEV = {"shaft": (0.85, -6.75, 3.00, -4.55),  # 2.15 x 2.20
        "cabin": (1.55, 1.70), "door_w": 0.91,
        "stops": ["B1", "F01", "F02", "F03", "F04", "F05", "F06"]}


def wall(a, b, t, h, z, openings=None, cat="walls", mat="plaster",
         wainscot=False, details=True):
    return {"a": list(a), "b": list(b), "t": t, "h": h, "z": z,
            "openings": openings or [], "cat": cat, "mat": mat,
            "wainscot": wainscot, "details": details}


def arch(at, w, h=2.85):
    """Full-width archway: an opening with no leaf (grand stair passages)."""
    return {"type": "door", "at": at, "w": w, "h": h, "sill": 0.0,
            "leaf": "none"}


def door(at, spec=DOOR_INT, leaf="closed", swing=None):
    """leaf: "closed" | "open" | "locked" | "none" (opening only).
    swing "out" reverses the hinge (egress doors swing with travel)."""
    o = {"type": "door", "at": at, "w": spec["w"], "h": spec["h"],
         "sill": 0.0, "leaf": leaf}
    if swing:
        o["swing"] = swing
    return o


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
        door_x = bx + (1.0 if east else -1.0)  # clear of the bath block
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
                      "e" if not east else "w", markers, z)
        rooms.append({"id": prefix + "_MAIN", "unit": unit,
                      "rect": [x0, by, x1, y1], "kind": "living"})
        if stack == "D":
            # small office in the corridor band, north of entry and bath
            oy0, oy1 = by + 3.41, y1
            walls.append(wall((bx, oy0), (bx, oy1), PART_T, WALL_H, z, []))
            walls.append(wall((bth0, oy0), (bth1, oy0), PART_T, WALL_H, z,
                              [door(1.1)]))
            rooms.append({"id": prefix + "_OFFICE", "unit": unit,
                          "rect": [bth0, oy0, bth1, oy1], "kind": "office"})
    elif stack == "B":
        # studio: sleeping alcove at the rear, bath near the entry
        ay = y1 - 3.15
        ax = x0 + 2.75
        walls.append(wall((ax, ay), (ax, y1), PART_T, WALL_H, z,
                          [{"type": "door", "at": 1.60, "w": 1.20,
                            "h": 2.03, "sill": 0.0, "leaf": "none"}]))
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
                      "e" if not east else "w", markers, z)
        rooms.append({"id": prefix + "_KITCHEN", "unit": unit,
                      "rect": [ax, ay, x1, y1], "kind": "kitchen"})
        rooms.append({"id": prefix + "_MAIN", "unit": unit,
                      "rect": [x0, y0, x1, ay], "kind": "living"})
    else:  # C: two bedrooms across the rear
        by = y1 - 3.40
        xm = (x0 + x1) / 2.0
        pd = "none" if unit == "3C" else "closed"
        walls.append(wall((x0, by), (x1, by), PART_T, WALL_H, z,
                          [door(1.6, DOOR_INT, pd),
                           door(x1 - x0 - 1.6, DOOR_INT, pd)]))
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
                      "e" if not east else "w", markers, z)
        rooms.append({"id": prefix + "_MAIN", "unit": unit,
                      "rect": [x0, y0, x1, by], "kind": "living"})
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




def bath_fixtures(furniture, unit, rect, edge, markers=None, z=0.0):
    """Shower, close-coupled toilet and pedestal sink with mirror, lined
    along one wall of the bath, plus a milk-glass sconce over the mirror
    when a markers list is supplied. edge: "e" | "w" | "n"."""
    x0, y0, x1, y1 = rect
    f = furniture
    if edge == "e":
        _asm(f, unit + "_shower", "shower", x1 - 0.46, y0 + 0.50, 90)
        _asm(f, unit + "_wc", "toilet", x1 - 0.41, y0 + 1.22, 90)
        _asm(f, unit + "_sink", "sink_ped", x1 - 0.30, y0 + 1.92, 90)
        spos, syaw = [x1 - 0.08, y0 + 1.92], -90
    elif edge == "w":
        _asm(f, unit + "_shower", "shower", x0 + 0.46, y0 + 0.50, -90)
        _asm(f, unit + "_wc", "toilet", x0 + 0.41, y0 + 1.22, -90)
        _asm(f, unit + "_sink", "sink_ped", x0 + 0.30, y0 + 1.92, -90)
        spos, syaw = [x0 + 0.08, y0 + 1.92], 90
    else:  # "n"
        _asm(f, unit + "_shower", "shower", x0 + 0.50, y1 - 0.46, 180)
        _asm(f, unit + "_wc", "toilet", x0 + 1.22, y1 - 0.41, 180)
        _asm(f, unit + "_sink", "sink_ped", x0 + 1.92, y1 - 0.30, 180)
        spos, syaw = [x0 + 1.92, y1 - 0.08], 0
    tr = {"e": (x1 - 0.10, y0 + 0.62), "w": (x0 + 0.10, y0 + 0.62),
          "n": (x0 + 0.62, y1 - 0.10)}[edge]
    if edge in ("e", "w"):
        _furn_box(f, unit + "_trail", tr[0] - 0.012, tr[1], 0.024, 0.62,
                  1.05, 0.02, "chrome", False)
        _furn_box(f, unit + "_towel", tr[0] - 0.03, tr[1] + 0.10, 0.05,
                  0.38, 0.60, 0.44, "linen", False)
    else:
        _furn_box(f, unit + "_trail", tr[0], tr[1] - 0.012, 0.62, 0.024,
                  1.05, 0.02, "chrome", False)
        _furn_box(f, unit + "_towel", tr[0] + 0.10, tr[1] - 0.03, 0.38,
                  0.05, 0.60, 0.44, "linen", False)
    if markers is not None:
        markers.append({"kind": "sconce_globe",
                        "id": "%s_LT_SCONCE" % unit,
                        "unit": unit, "pos": [spos[0], spos[1], z + 1.92],
                        "yaw_deg": syaw, "network": "electrical",
                        "energy": 1.05})


def wardrobe(furniture, unit, x, y, along_x=True, face="n"):
    if along_x:
        _asm(furniture, unit + "_wardrobe", "wardrobe", x + 0.65, y + 0.31,
             FACE_YAW[face], W=1.30)
    else:
        _asm(furniture, unit + "_wardrobe", "wardrobe", x + 0.31, y + 0.65,
             FACE_YAW[face], W=1.30)


# ------------------------------------------------- furniture assemblies
# Everything stays in the single-box furniture schema the Blender builder
# already understands; assemblies just emit coherent clusters of boxes.

def _pal(unit):
    """Deterministic per-unit palette so supporting units read as different
    households without hand-authoring each one."""
    h = sum(ord(c) * 7 for c in unit)
    return {"sofa": ["fabric_warm", "fabric_cool", "fabric_green"][h % 3],
            "rug": ["rug_warm", "rug_cool", "rug_green"][(h // 3) % 3],
            "wood": ["floor_oak", "wood_dark"][(h // 9) % 2]}


FACE_YAW = {"n": 0, "s": 180, "w": 90, "e": -90}


def _asm(f, uid, asm, cx, cy, yaw=0, z0=0.0, **params):
    d = {"id": uid, "asm": asm, "at": [round(cx, 4), round(cy, 4)],
         "yaw": yaw}
    if z0:
        d["z0"] = z0
    d.update(params)
    f.append(d)


def rug_box(f, uid, x, y, w, d, mat):
    _furn_box(f, uid + "_rug", x, y, w, d, 0.014, 0.008, mat, False)


def bed_set(f, uid, x, y, along_x=True, w=1.50, l=2.05,
            mat_blanket="fabric_warm"):
    """Spool bed; (x, y) is the min corner, head at -x (along_x) or +y."""
    if along_x:
        _asm(f, uid, "bed", x + l / 2, y + w / 2, -90, W=w, L=l,
             blanket=mat_blanket)
        _asm(f, uid + "_ns", "nightstand", x + 0.33, y + w + 0.31, 180)
    else:
        _asm(f, uid, "bed", x + w / 2, y + l / 2, 180, W=w, L=l,
             blanket=mat_blanket)
        _asm(f, uid + "_ns", "nightstand", x + w + 0.31, y + l - 0.33, -90)


def sofa_set(f, uid, x, y, L=1.95, along_x=True, back_far=True,
             mat="fabric_warm"):
    """(x, y) = min corner of the seat body; back on the far/near side."""
    d = 0.85
    pal_leg = "chrome" if sum(ord(c) for c in uid) % 3 == 0 else "wood_dark"
    if along_x:
        yaw = 180 if back_far else 0
        _asm(f, uid, "sofa", x + L / 2, y + d / 2, yaw, L=L, mat=mat,
             leg_mat=pal_leg)
    else:
        yaw = 90 if back_far else -90
        _asm(f, uid, "sofa", x + d / 2, y + L / 2, yaw, L=L, mat=mat,
             leg_mat=pal_leg)


def coffee_table(f, uid, x, y):
    _asm(f, uid, "coffee", x + 0.475, y + 0.275,
         (sum(ord(c) for c in uid) * 37) % 360)


def chair_box(f, uid, x, y, back_side="s"):
    _asm(f, uid, "chair", x + 0.22, y + 0.22, FACE_YAW[
        {"s": "n", "n": "s", "w": "e", "e": "w"}[back_side]])


def dining_set(f, uid, x, y, sides=("s", "n"), mat="floor_oak"):
    """Table centered at (x, y); cafe chairs only on the given sides, so
    seating stays out of the room's walking lines."""
    if sum(ord(c) for c in uid) % 2:
        _asm(f, uid + "_t", "table_round", x, y, 0, mat=mat)
    else:
        _asm(f, uid + "_t", "table_rect", x, y, 0, L=1.2, W=0.8, mat=mat)
    spots = {"s": (x - 0.55, y - 1.00), "n": (x + 0.11, y + 0.56),
             "w": (x - 1.10, y - 0.22), "e": (x + 0.66, y - 0.22)}
    for i, side in enumerate(sides):
        sx_, sy_ = spots[side]
        chair_box(f, "%s_dc%d" % (uid, i + 1), sx_, sy_, side)


def shelf_unit(f, uid, x, y, w=1.1, along_x=True, d=0.30, h=1.85,
               books=True, face="n"):
    """Steel-ladder wall shelf; face = side the leaning book shows."""
    if along_x:
        _asm(f, uid, "shelf", x + w / 2, y + d / 2, FACE_YAW[face], W=w,
             H=h, books=books)
    else:
        _asm(f, uid, "shelf", x + d / 2, y + w / 2, FACE_YAW[face], W=w,
             H=h, books=books)


def tv_set(f, uid, x, y, along_x=True, face="n"):
    """Media unit + panel on splayed dowels; (x, y) = min corner."""
    if along_x:
        _asm(f, uid, "tv", x + 0.625, y + 0.21, FACE_YAW[face])
    else:
        _asm(f, uid, "tv", x + 0.21, y + 0.625, FACE_YAW[face])


def plant_box(f, uid, x, y, big=False):
    s = 0.36 if big else 0.28
    _asm(f, uid, "plant", x + s / 2, y + s / 2,
         (sum(ord(c) for c in uid) * 53) % 360, big=big)


def art_panel(f, uid, x, y, w=0.7, along_x=True, z0=1.30, h=0.85, mat="art"):
    if along_x:
        _furn_box(f, uid + "_art", x, y, w, 0.035, z0, h, mat, False)
        _furn_box(f, uid + "_artf", x - 0.02, y, w + 0.04, 0.045, z0 - 0.03,
                  0.03, "wood_dark", False)
        _furn_box(f, uid + "_artf2", x - 0.02, y, w + 0.04, 0.045, z0 + h,
                  0.03, "wood_dark", False)
        _furn_box(f, uid + "_artfl", x - 0.02, y, 0.03, 0.045, z0, h,
                  "wood_dark", False)
        _furn_box(f, uid + "_artfr", x + w - 0.01, y, 0.03, 0.045, z0, h,
                  "wood_dark", False)
    else:
        _furn_box(f, uid + "_art", x, y, 0.035, w, z0, h, mat, False)
        _furn_box(f, uid + "_artf", x, y - 0.02, 0.045, w + 0.04, z0 - 0.03,
                  0.03, "wood_dark", False)
        _furn_box(f, uid + "_artf2", x, y - 0.02, 0.045, w + 0.04, z0 + h,
                  0.03, "wood_dark", False)
        _furn_box(f, uid + "_artfl", x, y - 0.02, 0.045, 0.03, z0, h,
                  "wood_dark", False)
        _furn_box(f, uid + "_artfr", x, y + w - 0.01, 0.045, 0.03, z0, h,
                  "wood_dark", False)


def kitchen_run(f, uid, x, y, L, along_x=True, side="n"):
    """Cabinetry run + range + fridge along the wall on `side` of the
    0.66-deep footprint whose min corner is (x, y)."""
    cw = max(0.95, L - 1.40)

    def clutter(cx_, cy_, swap=False):
        items = (((-cw * 0.32, 0.05), 0.22, 0.17, 0.11, "porcelain",
                  "mugs"),
                 ((-cw * 0.18, -0.10), 0.24, 0.20, 0.07, "porcelain",
                  "plates"),
                 ((cw * 0.34, 0.02), 0.32, 0.22, 0.02, "timber", "board"))
        for (ox, oy), iw, id_, ih, mat_, tag in items:
            if swap:
                ox, oy = oy, ox
                iw, id_ = id_, iw
            f.append({"id": "%s_k%s" % (uid, tag),
                      "rect": [cx_ + ox - iw / 2, cy_ + oy - id_ / 2,
                               cx_ + ox + iw / 2, cy_ + oy + id_ / 2],
                      "z0": 0.90, "h": ih, "mat": mat_})
    if along_x:
        yaw = FACE_YAW["s" if side == "n" else "n"]
        cy = y + 0.32
        _asm(f, uid, "kitchen", x + cw / 2, cy, yaw, L=cw + 0.75)
        _asm(f, uid + "_stove", "stove", x + cw + 0.33, cy, yaw)
        _asm(f, uid + "_fr", "fridge50", x + cw + 0.66 + 0.36, cy, yaw)
        clutter(x + cw / 2, cy)
    else:
        yaw = FACE_YAW["e" if side == "w" else "w"]
        cx = x + 0.32
        _asm(f, uid, "kitchen", cx, y + cw / 2, yaw, L=cw + 0.75)
        _asm(f, uid + "_stove", "stove", cx, y + cw + 0.33, yaw)
        _asm(f, uid + "_fr", "fridge50", cx, y + cw + 0.66 + 0.36, yaw)
        clutter(cx, y + cw / 2, True)


def desk_set(f, uid, x, y, L=1.4, along_x=True, chair_side=1):
    if along_x:
        _asm(f, uid, "desk", x + L / 2, y + 0.325,
             0 if chair_side > 0 else 180, L=L)
        chair_box(f, uid + "_dkch", x + L / 2 - 0.22,
                  y + (0.80 if chair_side > 0 else -0.55),
                  "n" if chair_side > 0 else "s")
    else:
        _asm(f, uid, "desk", x + 0.325, y + L / 2,
             -90 if chair_side > 0 else 90, L=L)
        chair_box(f, uid + "_dkch",
                  x + (0.80 if chair_side > 0 else -0.55),
                  y + L / 2 - 0.22, "e" if chair_side > 0 else "w")


WIN_TOP = 2.55   # window head (sill 0.85 + h 1.70)


def blind_stack(f, uid, x, y, along_x, seed):
    """One venetian blind: head rail at the window top, slats descending
    to a per-window drop (someone half-raised theirs), each blind tilted
    more or less open — thick slats at tight pitch read shut, thin slats
    at open pitch let the night through."""
    h = sum(ord(c) * 13 for c in seed)
    drop = 0.35 + (h % 7) / 6.0 * 0.60          # 0.35..0.95 of the window
    tilt = ((h // 7) % 5) / 4.0                 # 0 open .. 1 closed
    pitch = 0.055 + 0.02 * tilt
    slat_h = 0.010 + 0.024 * tilt
    depth = 0.05 - 0.022 * tilt
    n = int(1.70 * drop / pitch)
    if along_x:
        _furn_box(f, uid + "_head", x, y, 1.34, 0.06, WIN_TOP, 0.05,
                  "trim", False)
        for k in range(n):
            _furn_box(f, "%s_s%d" % (uid, k), x + 0.02, y + 0.005, 1.30,
                      depth, WIN_TOP - 0.06 - k * pitch, slat_h, "trim",
                      False)
        _furn_box(f, uid + "_rail", x + 0.02, y, 1.30, 0.05,
                  WIN_TOP - 0.06 - n * pitch, 0.03, "trim", False)
    else:
        _furn_box(f, uid + "_head", x, y, 0.06, 1.34, WIN_TOP, 0.05,
                  "trim", False)
        for k in range(n):
            _furn_box(f, "%s_s%d" % (uid, k), x + 0.005, y + 0.02, depth,
                      1.30, WIN_TOP - 0.06 - k * pitch, slat_h, "trim",
                      False)
        _furn_box(f, uid + "_rail", x, y + 0.02, 0.05, 1.30,
                  WIN_TOP - 0.06 - n * pitch, 0.03, "trim", False)


def blinds_for_unit(f, unit, stack):
    x0, y0, x1, y1 = STACK_RECTS[stack]
    west = stack in ("A", "B")
    wx = (x0 + 0.10) if west else (x1 - 0.15)
    ln = y1 - y0
    for wi, wc in enumerate((y0 + ln * 0.30, y0 + ln * 0.70)):
        blind_stack(f, "%s_blw%d" % (unit, wi), wx, wc - 0.67, False,
                    unit + str(wi))
    street = stack in ("A", "D")
    wy = (y0 + 0.10) if street else (y1 - 0.15)
    blind_stack(f, unit + "_blr", (x0 + x1) / 2.0 - 0.67, wy, True,
                unit + "r")


## Room geometry per stack archetype, mirrored from apartment(): the
## dressing pass reads the same envelope numbers the walls are built from.
def _unit_rooms(stack):
    x0, y0, x1, y1 = STACK_RECTS[stack]
    if stack == "A":
        by = y0 + 3.40
        return {"bedrooms": [[x0, y0, x1, by]],
                "living": [x0, by, x1, y1],
                "kitchen_spot": (x1 - 3.4, y1 - 0.64, 2.5, True, "n"),
                "dining_spot": (x0 + 5.1, (by + y1) / 2 + 0.25, ("s", "e"))}
    if stack == "B":
        ay = y1 - 3.15
        return {"alcove": [x0, ay, x0 + 2.75, y1],
                "living": [x0, y0, x1, ay],
                "kitchen_spot": (x1 - 0.64, y1 - 2.60, 2.5, False, "e"),
                "dining_spot": (x0 + 5.4, y0 + 1.15, ("s", "n"))}
    if stack == "C":
        by = y1 - 3.40
        xm = (x0 + x1) / 2.0
        return {"bedrooms": [[x0, by, xm, y1], [xm, by, x1, y1]],
                "living": [x0, y0, x1, by],
                "kitchen_spot": (x0 + 0.04, y0 + 1.98, 2.55, False, "w"),
                "dining_spot": (x0 + 3.0, y0 + 3.1, ("s", "w"))}
    by = y0 + 3.40  # D
    return {"bedrooms": [[x0, y0, x1, by]],
            "living": [x0, by, x1, -1.00],
            "office": [x0, by + 3.41, x0 + 2.2, y1],
            "kitchen_spot": (x0 + 2.6, -1.64, 2.5, True, "n"),
            "dining_spot": (x0 + 6.0, -2.35, ("n", "e"))}


## Standard pieces each hero's signature cluster replaces (so the two
## dressing layers never fight over the same floor).
HERO_SKIP = {
    "2A": {"shelf"},
    "2C": {"rug"},
    "3D": {"tv"},
    "5A": {"shelf"},
    "6A": {"sofa", "rug", "tv", "plant"},
}


## Resident-specific environmental identity (Section 16) and unit states.
## Every occupied unit now carries a full lived-in furniture set; heroes
## get their signature clusters (and conductor markers) layered on top.
def dress_unit(unit, stack, floor_id, z, furniture, markers):
    x0, y0, x1, y1 = STACK_RECTS[stack]
    cx, cy = (x0 + x1) / 2.0, (y0 + y1) / 2.0
    east = stack in ("C", "D")
    W = abs(x1 - x0)
    f = furniture
    pal = _pal(unit)

    def ux(u, w=0.0):
        """x of a box of width w placed u meters off the exterior side wall."""
        return x0 + u if not east else x1 - u - w

    def mk(kind, idx, px, py, pz=0.0, yaw=0):
        markers.append({"kind": kind,
                        "id": "%s_%s_%s_%02d" % (floor_id, stack,
                                                 kind.upper(), idx),
                        "unit": unit, "pos": [px, py, z + pz],
                        "yaw_deg": yaw, "network": "electrical"})

    # ---- unit states first: these rooms are NOT ordinary households
    if unit == "2D":      # sealed since 1927: nobody dresses a tomb
        return
    if unit == "3C":      # vacant, water-damaged: exposed framing, debris
        for i in range(6):
            _furn_box(f, "3C_stud%d" % i, x0 + 1.2 + i * 1.1, y1 - 3.35,
                      0.08, 0.08, 0.0, WALL_H, "trim", False)
        _furn_box(f, "3C_debris", cx - 0.8, cy - 1.5, 1.6, 1.0, 0.0, 0.25,
                  "slab", False)
        _furn_box(f, "3C_tarp", cx - 1.6, cy - 0.2, 2.6, 1.8, 0.012, 0.01,
                  "linen", False)
        for i in range(3):
            _furn_box(f, "3C_bucket%d" % i, x0 + 1.0 + i * 0.5, y0 + 1.0,
                      0.3, 0.3, 0.0, 0.38, "ceramic", False)
        _furn_box(f, "3C_sawhorse1", cx + 1.0, cy + 1.2, 0.9, 0.25, 0.0,
                  0.75, "metal", False)
        _furn_box(f, "3C_sawhorse2", cx + 1.0, cy + 2.2, 0.9, 0.25, 0.0,
                  0.75, "metal", False)
        _furn_box(f, "3C_plank", cx + 0.9, cy + 1.15, 1.1, 1.45, 0.75,
                  0.05, "floor_oak", False)
        return
    if unit == "5D":      # fire-damaged: char, soot shadows on the walls
        _furn_box(f, "5D_char1", cx - 1.0, cy, 1.2, 0.8, 0.0, 0.4, "slab", False)
        _furn_box(f, "5D_char2", x1 - 2.0, y0 + 1.2, 0.9, 0.6, 0.0, 0.3,
                  "slab", False)
        _furn_box(f, "5D_bedburn", ux(0.5, 2.0), y0 + 0.6, 2.0, 1.4, 0.0,
                  0.22, "soot", False)
        for i in range(3):
            _furn_box(f, "5D_soot%d" % i, ux(0.02, 0.03),
                      y0 + 1.0 + i * 2.4, 0.03, 1.6, 0.6 + 0.3 * i, 1.7,
                      "soot", False)
        _furn_box(f, "5D_shelffall", cx + 0.4, cy - 2.0, 1.6, 0.35, 0.0,
                  0.5, "soot", False)
        return
    if unit == "6D":      # landlord storage: crate grid + racking
        spots_6d = ((0.35, 0.6), (1.55, 0.6), (2.75, 0.6), (3.95, 0.6),
                    (0.35, 2.2), (1.55, 2.2), (4.35, 2.2), (5.55, 2.2))
        for i, (ox, oy) in enumerate(spots_6d):
            _furn_box(f, "6D_crate%d" % i, x0 + ox, y0 + oy, 1.0, 1.0,
                      0.0, 0.9 + 0.4 * ((i * 7) % 3), "trim", False)
        shelf_unit(f, "6D_rack1", x0 + 0.5, y1 - 1.0, 1.6, True,
                   books=False, face="s")
        shelf_unit(f, "6D_rack2", x0 + 2.4, y1 - 1.0, 1.6, True,
                   books=False, face="s")
        _furn_box(f, "6D_rolledrug", x0 + 0.5, y0 + 4.2, 2.2, 0.3, 0.0,
                  0.3, "rug_warm", False)
        return

    # ---- standard lived-in set, from the unit's real room geometry.
    # Heroes suppress the standard pieces their signature clusters replace.
    skip = HERO_SKIP.get(unit, set())
    rooms = _unit_rooms(stack)
    for i, br in enumerate(rooms.get("bedrooms", [])):
        bx0, by0, bx1, by1 = br
        bcy = (by0 + by1) / 2.0
        bcx = (bx0 + bx1) / 2.0
        if stack == "C":  # C beds head against the rear (north) wall
            bed_set(f, "%s_bed%d" % (unit, i), bcx - 0.75, by1 - 2.15,
                    False, mat_blanket=pal["sofa"])
            wardrobe(f, "%s_w%d" % (unit, i),
                     bcx + (0.35 if i == 0 else -1.75), by0 + 0.15,
                     face="n")
            rug_box(f, "%s_brg%d" % (unit, i), bcx - 1.0, by0 + 0.9, 2.0,
                    1.1, pal["rug"])
            art_panel(f, "%s_bart%d" % (unit, i), bcx + 0.95, by0 + 0.06,
                      0.7, True)
        elif not east:    # A: bed heads against the west exterior wall
            bed_set(f, "%s_bed%d" % (unit, i), bx0 + 0.35, bcy - 0.75,
                    True, mat_blanket=pal["sofa"])
            wardrobe(f, "%s_w%d" % (unit, i), bx0 + 1.6, by1 - 0.80,
                     face="s")
            rug_box(f, "%s_brg%d" % (unit, i), bx0 + 0.6, bcy + 0.80, 2.4,
                    0.80, pal["rug"])
            art_panel(f, "%s_bart%d" % (unit, i), bx0 + 2.0, by1 - 0.075,
                      0.7, True)
        else:             # D: bed heads against the bedroom partition
            bed_set(f, "%s_bed%d" % (unit, i), bx1 - 2.0, by1 - 2.15,
                    False, mat_blanket=pal["sofa"])
            wardrobe(f, "%s_w%d" % (unit, i), bx1 - 4.5, by0 + 0.18,
                     face="n")
            rug_box(f, "%s_brg%d" % (unit, i), bx1 - 4.2, by1 - 2.0, 1.9,
                    1.3, pal["rug"])
            art_panel(f, "%s_bart%d" % (unit, i), bx0 + 1.4, by1 - 0.075,
                      0.7, True)
    if "alcove" in rooms and "alcove" not in skip:
        ax0, ay0, ax1, ay1 = rooms["alcove"]
        bed_set(f, unit + "_abed", ax0 + 0.35, ay1 - 2.45, False,
                w=1.40, mat_blanket=pal["sofa"])
        wardrobe(f, unit + "_aw", ax1 - 0.80, ay1 - 1.55, False, face="w")
    if "office" in rooms:
        ox0, oy0, ox1, oy1 = rooms["office"]
        desk_set(f, unit + "_odesk", ox1 - 0.69, oy0 + 0.30, 1.4, False, -1)
        shelf_unit(f, unit + "_oshelf", ox0 + 0.12, oy1 - 0.42, 1.0, True,
                   face="s")
    lx0, ly0, lx1, ly1 = rooms["living"]
    lcy = (ly0 + ly1) / 2.0
    # kitchen run against a wall clear of the entry swing and the bath
    kx, ky, kL, kax, kside = rooms["kitchen_spot"]
    if "kitchen" not in skip:
        kitchen_run(f, unit + "_k", kx, ky, kL, kax, kside)
    # sofa cluster against the exterior side wall, tv on the rug's far edge
    if "sofa" not in skip:
        sofa_set(f, unit + "_sofa", ux(0.35, 0.85), lcy - 1.0, 1.95,
                 along_x=False, back_far=east, mat=pal["sofa"])
        coffee_table(f, unit + "_cof", ux(1.55, 0.95), lcy - 0.55)
    if "rug" not in skip:
        rug_box(f, unit + "_lrug", ux(0.30, 3.1), lcy - 1.35, 3.1, 2.7,
                pal["rug"])
    if "tv" not in skip:
        tv_set(f, unit + "_tv", ux(3.10, 0.40), lcy - 0.85, False,
               face="w" if not east else "e")
    dx, dy, dsides = rooms["dining_spot"]
    dining_set(f, unit + "_din", dx, dy, dsides, pal["wood"])
    if "shelf" not in skip:
        shelf_unit(f, unit + "_shelf", ux(1.2 if stack in ("A", "B")
                   else 2.9, 1.1),
                   ly1 - 0.42 if stack == "C" else ly0 + 0.12, 1.1, True,
                   face="s" if stack == "C" else "n")
    if "plant" not in skip:
        plant_box(f, unit + "_plant1", ux(0.35, 0.60),
                  ly1 - 0.95 if stack != "B" else ly0 + 0.20, big=True)
    if sum(ord(c) for c in unit) % 2:
        plant_box(f, unit + "_plant2",
                  ux(W - 1.7 if stack == "A" else W - 3.0, 0.42),
                  ly0 + 0.45 if stack != "B" else ly1 - 1.55)
    art_panel(f, unit + "_lart", ux(1.8, 0.9),
              ly1 - 0.075 if stack in ("A", "B") else ly0 + 0.04, 0.9, True)
    blinds_for_unit(f, unit, stack)

    # ---- hero overlays: each resident's signature cluster + conductor bodies
    if unit == "2A":    # Mina: ordered caption station, quiet
        desk_set(f, "2A_desk", x0 + 0.5, cy - 0.7, 1.5, True, 1)
        for i in range(3):
            shelf_unit(f, "2A_shelf%d" % i, x0 + 0.4 + i * 1.15, y0 + 3.55,
                       0.95, True, h=1.6, face="n")
        _furn_box(f, "2A_filing", x0 + 2.1, cy - 0.65, 0.45, 0.6, 0.0,
                  1.05, "metal", False)
        mk("monitor", 1, x0 + 1.1, cy - 0.5, 0.76, -90)
        mk("lamp", 1, x0 + 0.8, cy - 0.4, 0.76)
    elif unit == "2C":  # Juno: improvised studio, speakers everywhere
        _furn_box(f, "2C_bench", cx - 1.2, cy - 0.5, 2.4, 0.7, 0.72, 0.05,
                  "metal", False)
        _furn_box(f, "2C_amp1", x1 - 1.1, cy + 0.6, 0.55, 0.45, 0.0, 0.55,
                  "screen", False)
        _furn_box(f, "2C_amp2", x1 - 1.1, cy + 0.6, 0.5, 0.4, 0.55, 0.45,
                  "soot", False)
        _furn_box(f, "2C_cablerug", cx - 1.8, cy - 1.6, 3.4, 2.4, 0.013,
                  0.012, "soot", False)
        _furn_box(f, "2C_crates", x1 - 1.3, y0 + 0.4, 0.9, 0.9, 0.0, 1.15,
                  "trim", False)
        mk("speaker", 1, x1 - 0.6, cy + 1.6, 0.0, -90)
        mk("speaker", 2, x1 - 0.6, cy - 2.2, 0.0, -90)
        chair_box(f, "2C_benchstool", cx - 0.35, cy - 1.35, "s")
        mk("monitor", 1, cx - 0.4, cy - 0.3, 0.76, 180)
    elif unit == "3B":  # Omar: repair shop by category
        _asm(f, "3B_workbench", "workbench", x0 + 1.5, y0 + 3.7, 180)
        for i in range(2):
            shelf_unit(f, "3B_tools%d" % i, x0 + 2.85 + i * 1.10,
                       y1 - 0.45, 1.0, True, d=0.4, books=False, face="s")
        for i in range(4):
            _furn_box(f, "3B_bin%d" % i, x0 + 2.95 + i * 0.5, y1 - 0.40,
                      0.4, 0.28, 0.5 + (i % 2) * 0.46, 0.24,
                      ("metal", "fabric_cool")[i % 2], False)
        _furn_box(f, "3B_radio", x0 + 1.1, y0 + 3.45, 0.5, 0.35, 0.91,
                  0.22, "wood_dark", False)
        chair_box(f, "3B_stool", x0 + 1.3, y0 + 2.6, "s")
        mk("lamp", 1, x0 + 1.0, y0 + 3.5, 0.95)
    elif unit == "3D":  # Rhea: vocal booth and aligned playback
        _furn_box(f, "3D_booth_w", cx + 0.4, cy - 1.0, 0.1, 2.0, 0.0, 2.2,
                  "fabric_cool", False)
        _furn_box(f, "3D_booth_n", cx + 0.4, cy + 1.0, 2.0, 0.1, 0.0, 2.2,
                  "fabric_cool", False)
        _furn_box(f, "3D_boothfoam", cx + 0.5, cy - 0.9, 0.06, 1.8, 0.3,
                  1.6, "soot", False)
        _furn_box(f, "3D_mirror", x1 - 2.6, cy + 0.4, 0.05, 1.2, 0.2, 1.8,
                  "glassish", False)
        _furn_box(f, "3D_micstand", cx + 0.9, cy + 0.1, 0.06, 0.06, 0.0,
                  1.55, "metal", False)
        shelf_unit(f, "3D_tapes", x1 - 0.42, -2.25, 1.2, False,
                   books=True, face="w")
        mk("speaker", 1, cx + 1.8, cy + 1.2, 0.0, 180)
        mk("speaker", 2, cx + 1.8, cy - 1.2, 0.0, 180)
    elif unit == "5A":  # Nadia: plans over contradictory plans
        _asm(f, "5A_plantable", "plantable", cx, cy + 0.75)
        _furn_box(f, "5A_tuberack", x0 + 2.3, y0 + 3.65, 0.4, 0.4, 0.0,
                  1.1, "ceramic", False)
        for i in range(3):
            _furn_box(f, "5A_pin%d" % i, x0 + 0.02, y0 + 3.8 + i * 1.5,
                      0.03, 1.2, 1.1, 1.0, "paper", False)
        shelf_unit(f, "5A_planshelf", x0 + 0.4, y0 + 3.55, 1.6, True,
                   h=1.4, face="n")
        chair_box(f, "5A_stool", cx + 0.7, cy + 1.55, "n")
        mk("lamp", 1, cx + 0.6, cy + 0.75, 0.83)
    elif unit == "6A":  # Sacha: capture wall, framed for camera
        _furn_box(f, "6A_deskwall", x0 + 0.4, cy - 1.2, 0.8, 2.6, 0.72,
                  0.05, "trim", False)
        _furn_box(f, "6A_dwlegs", x0 + 0.5, cy - 1.1, 0.6, 2.4, 0.0, 0.72,
                  "metal", False)
        _furn_box(f, "6A_tripod", x0 + 2.3, cy, 0.12, 0.12, 0.0, 1.45,
                  "metal", False)
        _furn_box(f, "6A_rig", x0 + 2.24, cy - 0.06, 0.24, 0.24, 1.45,
                  0.18, "screen", False)
        _furn_box(f, "6A_cablerun", x0 + 0.4, cy - 1.5, 2.0, 0.12, 0.013,
                  0.02, "soot", False)
        _furn_box(f, "6A_cot", x0 + 0.4, y1 - 2.5, 0.9, 2.0, 0.0, 0.35,
                  "fabric_cool", False)
        for i in range(3):
            mk("monitor", i + 1, x0 + 0.8, cy - 1.0 + i * 1.0, 0.78, 0)
        chair_box(f, "6A_deskchair", x0 + 1.55, cy - 0.25, "w")
        mk("boxfan", 1, x1 - 1.2, y0 + 1.0, 0.25, 135)
    elif unit == "4D":  # short-term rental: nobody actually lives here
        # strip the lived-in warmth back out: it stays, but reads staged
        pass


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
                        "sill": 0.0, "leaf": "none"}]))
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
    bath_fixtures(furniture, "4B", [bx, y0 + 1.85, x1, y0 + 4.25], "n",
                  markers, z)
    furniture += [
        {"id": "desk", "rect": [-8.45, 4.95, -7.87, 6.25], "z0": 0.72,
         "h": 0.04, "mat": "floor_oak"},
        {"id": "desk_legs", "rect": [-8.40, 5.00, -8.35, 6.20], "z0": 0.0,
         "h": 0.72, "mat": "metal"},
        {"id": "chair", "rect": [-9.05, 5.35, -8.60, 5.85], "z0": 0.42,
         "h": 0.06, "mat": "trim"},
        {"id": "bed", "rect": [-13.40, 6.90, -12.05, 9.50], "z0": 0.15,
         "h": 0.32, "mat": "trim"},
        {"id": "kitchen_counter", "rect": [-10.70, 9.05, -8.85, 9.55],
         "z0": 0.0, "h": 0.90, "mat": "trim"},
        {"id": "couch", "rect": [-12.80, 3.60, -11.30, 4.35], "z0": 0.12,
         "h": 0.42, "mat": "fabric_cool"},
    ]
    # lived-in touches: the player's own residue
    rug_box(furniture, "4B_deskrug", -9.35, 4.85, 1.15, 1.5, "rug_cool")
    shelf_unit(furniture, "4B_shelf", -13.40, 4.55, 1.1, False)
    art_panel(furniture, "4B_art", -12.55, 2.71, 0.7, True)
    _furn_box(furniture, "4B_mattress", -13.33, 6.97, 1.21, 2.46, 0.32,
              0.16, "linen", False)
    _furn_box(furniture, "4B_blanket", -13.36, 6.94, 1.27, 1.35, 0.46,
              0.05, "fabric_cool", False)
    _furn_box(furniture, "4B_pillow", -13.25, 8.85, 0.65, 0.5, 0.48, 0.10,
              "paper", False)
    markers += [
        {"kind": "radiator", "id": "F04_B_RADIATOR_01", "unit": "4B",
         "pos": [-8.55, y1 - 0.30, z], "yaw_deg": 180, "network": "heating",
         "riser": "H-B"},
        {"kind": "lamp", "id": "F04_B_LAMP_01", "unit": "4B",
         "pos": [-8.15, 6.00, z + 0.76], "yaw_deg": 0,
         "network": "electrical"},
        {"kind": "monitor", "id": "F04_B_MONITOR_01", "unit": "4B",
         "pos": [-8.05, 5.50, z + 0.76], "yaw_deg": 180,
         "network": "electrical"},
        {"kind": "toaster", "id": "F04_B_TOASTER_01", "unit": "4B",
         "pos": [-9.70, 9.30, z + 0.90], "yaw_deg": 90,
         "network": "electrical"},
        {"kind": "fridge", "id": "F04_B_FRIDGE_01", "unit": "4B",
         "pos": [-8.30, 9.20, z], "yaw_deg": 0, "network": "electrical"},
        {"kind": "boxfan", "id": "F04_B_BOXFAN_01", "unit": "4B",
         "pos": [-13.20, 3.40, z + 0.25], "yaw_deg": 45,
         "network": "electrical"},
        {"kind": "door_anomaly", "id": "F04_B_DOOR_ANOMALY", "unit": "4B",
         "pos": [-7.20, y0 + 4.32, z], "yaw_deg": 0,
         "network": "structural"},
        {"kind": "desk_zone", "id": "F04_B_DESK_ZONE", "unit": "4B",
         "pos": [-8.80, 5.60, z], "yaw_deg": 0},
        {"kind": "door", "id": "F04_CAB_LOWER_1", "pos": [-10.55, 9.05, 9.6],
         "yaw_deg": 0, "w": 0.55, "h": 0.72, "leaf": "closed",
         "cabinet": True},
        {"kind": "door", "id": "F04_CAB_LOWER_2", "pos": [-9.95, 9.05, 9.6],
         "yaw_deg": 0, "w": 0.55, "h": 0.72, "leaf": "closed",
         "cabinet": True},
        {"kind": "door", "id": "F04_CAB_UPPER_1",
         "pos": [-10.55, 9.40, 9.6 + 1.50], "yaw_deg": 0, "w": 0.45,
         "h": 0.70, "leaf": "closed", "cabinet": True},
        {"kind": "door", "id": "F04_CAB_UPPER_2",
         "pos": [-10.00, 9.40, 9.6 + 1.50], "yaw_deg": 0, "w": 0.45,
         "h": 0.70, "leaf": "closed", "cabinet": True},
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


## Section 4 "highest detail": the lived-in texture of the player's rooms
## (ported from the accuracy-audit pass; blinds, crockery, desk clutter).
def furnish_4b_detail(furniture, y0, y1, x0):
    def fb(fid, rect, z0, h, mat="trim"):
        furniture.append({"id": "4B_" + fid, "rect": list(rect), "z0": z0,
                          "h": h, "mat": mat})

    fb("uppers", (-10.70, 9.40, -8.85, 9.64), 1.50, 0.72)
    fb("sink_rim", (-10.18, 9.12, -9.68, 9.50), 0.88, 0.05, "metal")
    fb("faucet_riser", (-9.96, 9.46, -9.90, 9.52), 0.90, 0.28, "metal")
    fb("faucet_spout", (-9.96, 9.30, -9.90, 9.50), 1.14, 0.04, "metal")
    fb("mugs", (-9.62, 9.15, -9.40, 9.32), 0.90, 0.11)
    fb("plates", (-9.30, 9.16, -9.06, 9.36), 0.90, 0.07)
    for wi, wc in enumerate((y0 + (y1 - y0) * 0.30,
                             y0 + (y1 - y0) * 0.70)):
        blind_stack(furniture, "4B_blw%d" % wi, -13.58, wc - 0.67, False,
                    "4B" + str(wi))
    blind_stack(furniture, "4B_blr", -10.25, 9.52, True, "4Br")
    fb("rug", (-12.40, 3.40, -8.70, 6.00), 0.0, 0.015, "rug_warm")
    fb("bookshelf", (-11.20, 2.75, -9.70, 3.07), 0.0, 1.55)
    for r, zr in enumerate((0.30, 0.76, 1.22)):
        fb("books%d" % r, (-11.12, 2.79, -9.80, 3.03), zr, 0.26, "timber")
    fb("keyboard", (-8.30, 5.35, -8.05, 5.75), 0.762, 0.02, "metal")
    fb("mouse", (-8.02, 5.50, -7.96, 5.58), 0.762, 0.025, "metal")
    fb("microphone", (-8.38, 5.95, -8.32, 6.01), 0.762, 0.16, "metal")
    fb("headset_stand", (-8.40, 5.02, -8.30, 5.12), 0.762, 0.20)
    fb("power_strip", (-7.92, 4.70, -7.78, 5.05), 0.0, 0.05, "metal")
    for px, py in ((-13.40, 6.92), (-12.21, 6.92), (-13.40, 9.42),
                   (-12.21, 9.42)):
        fb("bedpost_%d_%d" % (int(px * 10), int(py * 10)),
           (px, py, px + 0.06, py + 0.06), 0.0, 0.52, "timber")
    fb("headboard", (-13.40, 9.44, -12.15, 9.50), 0.15, 0.78, "timber")
    fb("nightstand", (-12.05, 9.10, -11.68, 9.48), 0.0, 0.55)
    fb("shower_riser", (-7.52, y0 + 4.12, -7.46, y0 + 4.18), 0.14, 1.90,
       "metal")
    fb("shower_head", (-7.62, y0 + 3.98, -7.42, y0 + 4.18), 2.00, 0.05,
       "metal")
    fb("mirror", (-6.05, y0 + 4.17, -5.60, y0 + 4.21), 1.35, 0.60,
       "glassish")


## Rear wooden porch stack (the Midwest second egress): posts, decks with
## railings at each floor, steep period runs between decks.
def porch(floor_id, z, furniture):
    if floor_id not in ("F02", "F03", "F04", "F05", "F06"):
        return

    def fb(fid, rect, z0, h, mat="timber"):
        furniture.append({"id": "%s_%s" % (floor_id, fid),
                          "rect": list(rect), "z0": z0, "h": h, "mat": mat})

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


# ---------------------------------------------------------------- floors

def ring_and_cores(floor_id, z, walls, furniture, entry_doors=True):
    """Corridor ring, court walls, core walls, shaft walls for one level."""
    h = WALL_H
    # The E/W stairwell walls are internal structure, not exterior light-shaft
    # facades. The former "windows" opened into adjacent core construction and
    # could overlap stair rails. Keep both walls solid and hang large framed
    # building-history panels on the atrium faces instead.
    walls.append(wall((-COURT, -COURT), (-COURT, COURT), CORR_T, h, z, [],
                      mat="brick"))
    walls.append(wall((COURT, -COURT), (COURT, COURT), CORR_T, h, z, [],
                      mat="brick"))
    art_panel(furniture, "%s_stair_history_w" % floor_id,
              -COURT + CORR_T / 2.0 + 0.012, -0.62, 1.24, False,
              z0=1.02, h=1.08, mat="paper")
    art_panel(furniture, "%s_stair_history_e" % floor_id,
              COURT - CORR_T / 2.0 - 0.047, -0.62, 1.24, False,
              z0=1.02, h=1.08, mat="paper")
    # corridor inner walls (x) run past court and cores
    walls.append(wall((-XCI, -YCN), (-XCI, YCN), CORR_T, h, z, [],
                      mat="plaster", wainscot=True))
    walls.append(wall((XCI, -YCN), (XCI, YCN), CORR_T, h, z, [],
                      mat="plaster", wainscot=True))
    # core side walls close the court band between court and corridor walls
    for cy0, cy1 in ((-CORE_Y1, -CORE_Y0), (CORE_Y0, CORE_Y1)):
        walls.append(wall((-COURT, cy0), (-COURT, cy1), CORR_T, h, z, [],
                          wainscot=True))
        walls.append(wall((COURT, cy0), (COURT, cy1), CORR_T, h, z, [],
                          wainscot=True))
    # core south wall: grand archway into the elevator hall + lift door
    south_openings = [arch(abs(-1.20 - (-COURT)), 3.70)]
    if floor_id in ELEV["stops"]:
        south_openings.append({"type": "door", "at": abs(1.925 - (-COURT)),
                               "w": ELEV["door_w"], "h": 2.10, "sill": 0.0,
                               "leaf": "none"})
    walls.append(wall((-COURT, -CORE_Y1), (COURT, -CORE_Y1), CORR_T, h, z,
                      south_openings, wainscot=True))
    # hall -> atrium deck: wide archway through the court south wall
    walls.append(wall((-COURT, -CORE_Y0), (COURT, -CORE_Y0), CORR_T, h, z,
                      [arch(COURT, 3.20)], wainscot=True))
    # north core = utility room (chute, meters), door off the corridor
    walls.append(wall((-COURT, CORE_Y1), (COURT, CORE_Y1), CORR_T, h, z,
                      [door(abs(-1.94 - (-COURT)), DOOR_SERV, "closed")],
                      wainscot=True))
    # court north wall (utility-room side of the atrium): solid
    walls.append(wall((-COURT, CORE_Y0), (COURT, CORE_Y0), CORR_T, h, z, []))
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
                          openings, wainscot=True))
    # elevator shaft walls (west face + splits; south face is core wall)
    ex0, ey0, ex1, ey1 = ELEV["shaft"]
    walls.append(wall((ex0, ey0), (ex0, ey1), CORR_T, h, z, [],
                      mat="concrete", details=False))
    walls.append(wall((ex1, ey0), (ex1, ey1), CORR_T, h, z, [],
                      mat="concrete", details=False))
    walls.append(wall((ex0, ey1), (ex1, ey1), CORR_T, h, z, [],
                      mat="concrete", details=False))


# Empirical masonry rule (1920s codes): ~12 in walls for the upper
# stories, 16 in below; the outer face stays flush at the property plane
# and the step happens inside.
def ext_t(floor_id):
    return {"B1": 0.41, "F01": 0.41, "F02": 0.35,
            "F03": 0.35}.get(floor_id, 0.30)


def chimney_block(floor_id, z, walls, h=None):
    cx0, cy0, cx1, cy1 = CHIMNEY
    walls.append(wall((cx0, (cy0 + cy1) / 2.0), (cx1, (cy0 + cy1) / 2.0),
                      cy1 - cy0, h if h else WALL_H, z, [],
                      mat="common_brick", details=False))


def exterior(floor_id, z, walls):
    h = F2F  # bearing walls run continuously past the joist/slab zone
    t = ext_t(floor_id)
    off = t / 2.0
    for stack, rect in STACK_RECTS.items():
        x0, y0, x1, y1 = rect
        west = stack in ("A", "B")
        wx = -(14.0 - off) if west else (14.0 - off)
        ln = y1 - y0
        spec = WIN_B1 if floor_id == "B1" else WIN
        wo = [window(ln * 0.30, spec), window(ln * 0.70, spec)]
        walls.append(wall((wx, y0), (wx, y1), t, h, z, wo,
                          mat="common_brick"))
        street = stack in ("A", "D")
        eyl = -(10.0 - off) if street else (10.0 - off)
        end_openings = [window((x1 - x0) * 0.5,
                               WIN_B1 if floor_id == "B1" else WIN)]
        if stack == "B" and floor_id in ("F02", "F03", "F04", "F05", "F06"):
            # kitchen door onto the rear wooden porch (the Midwest second
            # egress since the 1906 two-exit rule)
            end_openings.append(door(abs(-8.30 - x0), DOOR_INT))
        walls.append(wall((x0, eyl), (x1, eyl), t, h, z, end_openings,
                          mat="face_brick" if street else "common_brick"))
    # street / rear walls across the middle band (corridor ends)
    mid_spec = WIN_B1 if floor_id == "B1" else WIN
    s_open = [window(X_IN - 2.5, mid_spec), window(X_IN + 2.5, mid_spec)]
    if floor_id == "F01":
        s_open.append(door(X_IN, DOOR_ENTRY, swing="out"))  # street egress
    # the B1 street wall stops flush under the F01 slab: its 0.4 m
    # above-grade continuation would curb the entrance shut (the water
    # table dresses the exposed base instead)
    hs = 2.78 if floor_id == "B1" else h
    walls.append(wall((-X_IN, -(10.0 - off)), (X_IN, -(10.0 - off)), t, hs,
                      z, s_open, mat="face_brick"))
    walls.append(wall((-X_IN, 10.0 - off), (X_IN, 10.0 - off), t, h, z,
                      [window(X_IN - 2.5, mid_spec),
                       window(X_IN + 2.5, mid_spec)],
                      mat="common_brick"))


def split_walls(z, walls):
    # west: A | former-suite storage | B ; east: D | C
    walls.append(wall((-X_IN, -0.39), (-XAW, -0.39), PART_T, WALL_H, z, []))
    walls.append(wall((-X_IN, 2.61), (-XAW, 2.61), PART_T, WALL_H, z, []))
    walls.append(wall((XAW, -0.94), (X_IN, -0.94), PART_T, WALL_H, z, []))


def core_rooms(floor_id, z, rooms, furniture):
    """Hall (elevator lobby), atrium stairwell and utility room exist on
    every level the ring exists on — connected, purposeful interiors."""
    rooms += [
        {"id": "%s_HALL" % floor_id, "rect": [-3.25, -6.75, 0.85, -3.25],
         "kind": "hall"},
        {"id": "%s_ATRIUM" % floor_id, "rect": [-3.25, -3.25, 3.25, 3.25],
         "kind": "atrium"},
        {"id": "%s_UTILITY" % floor_id, "rect": [-3.25, 3.25, 3.25, 6.75],
         "kind": "utility"},
    ]
    # utility room: trash chute run, hopper, meter bank, mop bucket
    _asm(furniture, "%s_chute" % floor_id, "pipe", 0, 0,
         p0=[2.45, 6.05, z], p1=[2.45, 6.05, z + WALL_H], r=0.24)
    _furn_box(furniture, "%s_hopper" % floor_id, 2.18, 5.55, 0.54, 0.30,
              0.75, 0.45, "metal", False)
    for i in range(3):
        _furn_box(furniture, "%s_meter%d" % (floor_id, i),
                  -3.12, 3.6 + i * 0.95, 0.14, 0.75, 1.0, 0.85, "metal",
                  False)
    _furn_box(furniture, "%s_mop" % floor_id, -3.08, 6.30, 0.32, 0.32,
              0.0, 0.4, "ceramic", False)


def slab(floor_id, z, holes):
    return {"rect": [-14.0, -10.0, 14.0, 10.0], "z_top": z, "t": SLAB_T,
            "holes": [list(h) for h in holes]}


def stair_holes(floor_id):
    """Slab openings: the atrium well (flush with the court wall faces —
    no more slivers showing gaps between floors) and the elevator shaft.
    The old core stair wells are gone; those slabs are solid again."""
    holes = []
    if floor_id in ATRIUM["levels"][1:]:
        holes.append(ATRIUM["well"])
    if floor_id in ELEV["stops"][1:] or floor_id == "ROOF":
        holes.append(ELEV["shaft"])
    if floor_id != "B1":
        holes.append(CHIMNEY)
    return holes


def build_floor(floor_id):
    z = LEVELS[floor_id]
    walls, rooms, markers, furniture = [], [], [], []
    holes = stair_holes(floor_id)
    floor = {"id": floor_id, "z": z,
             "slabs": [slab(floor_id, z, holes)],
             "walls": walls, "rooms": rooms, "markers": markers,
             "furniture": furniture}

    if floor_id == "ROOF":
        # perimeter parapets + the glazed atrium monitor + machine room
        for a, b in (((-14, -10), (-14, 10)), ((14, -10), (14, 10)),
                     ((-14, -10), (14, -10)), ((-14, 10), (14, 10))):
            walls.append(wall(a, b, EXT_T, 1.10, z, [], mat="brick"))
        # atrium monitor: the stair arrives on its roof-level deck inside;
        # a door in the south wall opens onto the roof. High glazing bands
        # let the skylight pour down the eye of the stair.
        gl = {"type": "window", "at": COURT, "w": 5.4, "h": 1.05,
              "sill": 1.30}
        walls.append(wall((-COURT, -COURT), (COURT, -COURT), CORR_T, 2.55,
                          z, [door(abs(-0.85 - (-COURT)), DOOR_SERV,
                                   "closed"), dict(gl, w=3.0, at=4.7)]))
        walls.append(wall((-COURT, COURT), (COURT, COURT), CORR_T, 2.55,
                          z, [dict(gl)]))
        walls.append(wall((-COURT, -COURT), (-COURT, COURT), CORR_T, 2.55,
                          z, [dict(gl)]))
        walls.append(wall((COURT, -COURT), (COURT, COURT), CORR_T, 2.55,
                          z, [dict(gl)]))
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
        rooms.append({"id": "ROOF_OPEN", "rect": [-13.65, -9.65, 13.65, 9.65],
                      "kind": "roof"})
        markers.append({"kind": "watertank", "id": "ROOF_TANK",
                        "pos": [-8.0, 6.0, z], "yaw_deg": 0})
        # 1927 roofscape: chimney stack + cap, limestone coping, the
        # corbelled street cornice, timber water tank, vents, clothesline
        chimney_block(floor_id, z, walls, 2.2)
        _furn_box(furniture, "chimney_cap", 9.45, 9.00, 1.10, 0.75, 2.2,
                  0.15, "limestone", False)
        for rid, rect in (("s", (-14.10, -10.10, 14.10, -9.90)),
                          ("n", (-14.10, 9.90, 14.10, 10.10)),
                          ("w", (-14.10, -10.10, -13.90, 10.10)),
                          ("e", (13.90, -10.10, 14.10, 10.10))):
            _furn_box(furniture, "coping_%s" % rid, rect[0], rect[1],
                      rect[2] - rect[0], rect[3] - rect[1], 1.10, 0.08,
                      "limestone", False)
        for i in range(3):  # corbelled cornice under the street parapet
            _furn_box(furniture, "cornice_%d" % i, -14.04 - i * 0.03,
                      -10.04 - i * 0.03, 28.08 + i * 0.06,
                      0.08 + i * 0.03, -0.55 + i * 0.15, 0.13,
                      "limestone" if i == 2 else "face_brick", False)
        for lx, ly in ((-9.2, 5.2), (-6.9, 5.2), (-9.2, 6.9), (-6.9, 6.9)):
            _furn_box(furniture, "tankleg_%d_%d" % (int(lx * 10),
                      int(ly * 10)), lx, ly, 0.22, 0.22, 0.0, 1.6, "metal",
                      False)
        _furn_box(furniture, "watertank", -9.45, 4.95, 2.80, 2.20, 1.6,
                  2.3, "timber", False)
        for i, (vx, vy) in enumerate(((-11.5, -6.0), (-4.0, 8.2),
                                      (6.5, -7.5), (12.0, 3.0))):
            _furn_box(furniture, "vent%d" % i, vx, vy, 0.4, 0.4, 0.0, 0.9,
                      "metal", False)
        for px_ in (-12.5, -7.5):
            _furn_box(furniture, "clothespost_%d" % int(px_), px_, -8.6,
                      0.1, 0.1, 0.0, 2.1, "metal", False)
        _furn_box(furniture, "clothesline", -12.45, -8.58, 5.0, 0.03,
                  1.95, 0.02, "metal", False)
        return floor

    ring_and_cores(floor_id, z, walls, furniture,
                   entry_doors=(floor_id != "B1"))
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
        core_rooms(floor_id, z, rooms, furniture)
        chimney_block(floor_id, z, walls)
        # visible structure: timber beam lines on brick piers carry F01
        for sx in (-1, 1):
            for by_ in (-4.8, 4.8):
                bx0, bx1 = (5.71, 13.45) if sx > 0 else (-13.45, -5.71)
                _furn_box(furniture, "beam_%d_%d" % (sx, int(by_)),
                          bx0, by_ - 0.15, bx1 - bx0, 0.30, 2.27, 0.35,
                          "timber", False)
                px = bx0 + 1.25
                while px < bx1 - 0.3:
                    _furn_box(furniture, "pier_%d_%d_%d" % (sx, int(by_),
                              int(px * 10)), px, by_ - 0.19, 0.38, 0.38,
                              0.0, 2.27, "common_brick", False)
                    px += 2.7
        # coal bin with alley chute, feeding the boiler
        walls.append(wall((11.30, 0.30), (11.30, 2.70), PART_T, WALL_H, z,
                          [door(1.2, DOOR_SERV, "open")]))
        walls.append(wall((11.30, 0.30), (X_IN, 0.30), PART_T, WALL_H, z, []))
        walls.append(wall((11.30, 2.70), (X_IN, 2.70), PART_T, WALL_H, z, []))
        rooms.append({"id": "B1_COAL", "rect": [11.30, 0.30, X_IN, 2.70],
                      "kind": "coal"})
        _furn_box(furniture, "coal_pile", 12.4, 0.6, 1.0, 1.8, 0.0, 0.75,
                  "slab", False)
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
        # ceiling pipe runs: heating headers, corridor mains, riser stubs
        _asm(furniture, "b1_header", "pipe", 0, 0,
             p0=[-5.85, 0.0, z + 2.38], p1=[10.0, 0.0, z + 2.38], r=0.075)
        _asm(furniture, "b1_spur", "pipe", 0, 0,
             p0=[10.0, 0.0, z + 2.38], p1=[10.0, 4.7, z + 2.38], r=0.075)
        _asm(furniture, "b1_boilerriser", "pipe", 0, 0,
             p0=[10.0, 4.7, z + 0.85], p1=[10.0, 4.7, z + 2.38], r=0.11)
        for px in (-5.02, 4.88):
            _asm(furniture, "b1_main_%d" % int(px), "pipe", 0, 0,
                 p0=[px, -8.5, z + 2.42], p1=[px, 8.5, z + 2.42], r=0.07)
            _asm(furniture, "b1_cond_%d" % int(px), "pipe", 0, 0,
                 p0=[px + (0.24 if px > 0 else -0.24), -8.5, z + 2.24],
                 p1=[px + (0.24 if px > 0 else -0.24), 8.5, z + 2.24],
                 r=0.028)
        for rx, ry in RISER_XY.values():
            _asm(furniture, "b1_riser_%d_%d" % (int(rx * 10), int(ry * 10)),
                 "pipe", 0, 0, p0=[rx, ry, z], p1=[rx, ry, z + 2.62],
                 r=0.06)
        # laundry: folding table, baskets, bench under the small windows
        _furn_box(furniture, "b1_foldtable", -10.3, 5.1, 1.6, 0.8, 0.82,
                  0.05, "trim", False)
        _furn_box(furniture, "b1_foldlegs", -10.15, 5.2, 1.3, 0.6, 0.0,
                  0.82, "metal", False)
        _furn_box(furniture, "b1_basket1", -10.6, 3.6, 0.5, 0.5, 0.0,
                  0.55, "linen", False)
        _furn_box(furniture, "b1_basket2", -9.9, 3.7, 0.5, 0.5, 0.0, 0.55,
                  "fabric_cool", False)
        _furn_box(furniture, "b1_bench", -8.2, 8.9, 1.8, 0.4, 0.0, 0.45,
                  "wood_dark", False)
        # storage cages along the west wall of the cage room
        for i in range(4):
            cy0 = -9.0 + i * 2.15
            _furn_box(furniture, "b1_cagediv%d" % i, -13.65, cy0, 2.0,
                      0.05, 0.0, 2.0, "metal", False)
            _furn_box(furniture, "b1_crate%d" % i, -13.2, cy0 + 0.5,
                      0.9, 0.9, 0.0, 0.7 + 0.35 * (i % 2), "trim", False)
        _furn_box(furniture, "b1_cagefront", -11.65, -9.0, 0.05, 8.6, 0.0,
                  2.0, "metal", False)
        # electrical room: panel bank + wall conduit
        for i in range(3):
            _furn_box(furniture, "b1_panel%d" % i, 13.30, -7.2 + i * 1.1,
                      0.14, 0.8, 0.9, 1.0, "metal", False)
        _asm(furniture, "b1_econduit", "pipe", 0, 0,
             p0=[13.40, -8.6, z + 2.18], p1=[13.40, -1.2, z + 2.18],
             r=0.03)
        return floor

    if floor_id == "F01":
        rooms += [
            {"id": "F01_LOBBY", "rect": [-5.33, -9.65, 5.33, -6.93],
             "kind": "lobby"},
            {"id": "F01_COMMON_B", "rect": [-11.90, 5.40, -5.51, Y_IN],
             "kind": "common"},
            {"id": "F01_STORAGE_C", "rect": list(STACK_RECTS["C"]),
             "kind": "storage"},
        ]
        core_rooms(floor_id, z, rooms, furniture)
        markers += [
            {"kind": "radiator", "id": "F01_LOBBY_RADIATOR_01",
             "pos": [-4.6, -9.3, z], "yaw_deg": 0, "network": "heating",
             "riser": "H-A", "unit": "LOBBY"},
            {"kind": "mailboxes", "id": "F01_MAILWALL", "pos": [4.4, -9.3, z],
             "yaw_deg": 0},
        ]
        # draft vestibule inside the street door
        walls.append(wall((-1.40, -8.35), (1.40, -8.35), PART_T, WALL_H, z,
                          [{"type": "door", "at": 1.40, "w": 1.35,
                            "h": 2.20, "sill": 0.0, "leaf": "none"}]))
        walls.append(wall((-1.40, -9.65), (-1.40, -8.35), PART_T, WALL_H,
                          z, []))
        walls.append(wall((1.40, -9.65), (1.40, -8.35), PART_T, WALL_H,
                          z, []))
        rooms.append({"id": "F01_VESTIBULE", "rect": [-1.40, -9.65, 1.40,
                      -8.35], "kind": "lobby"})
        # limestone entrance surround + step, street side
        for fid_, rect, z0_, hh in (
                ("pilaster_w", (-1.35, -10.14, -1.05, -9.96), 0.0, 2.60),
                ("pilaster_e", (1.05, -10.14, 1.35, -9.96), 0.0, 2.60),
                ("entablature", (-1.50, -10.16, 1.50, -9.94), 2.60, 0.50),
                ("door_step", (-1.20, -10.38, 1.20, -10.00), 0.0, 0.09)):
            _furn_box(furniture, "entry_" + fid_, rect[0], rect[1],
                      rect[2] - rect[0], rect[3] - rect[1], z0_, hh,
                      "limestone", False)
        for rid, rect in (("s1", (-14.10, -10.10, -0.70, -9.96)),
                          ("s2", (0.70, -10.10, 14.10, -9.96)),
                          ("w", (-14.10, -10.10, -13.96, 10.10)),
                          ("e", (13.96, -10.10, 14.10, 10.10))):
            _furn_box(furniture, "water_table_%s" % rid, rect[0], rect[1],
                      rect[2] - rect[0], rect[3] - rect[1], 0.0, 0.45,
                      "limestone", False)
        # lobby: brass mail bank, hall settle, runner to the atrium
        _asm(furniture, "lobby_mailbank", "mailbank", 4.38, -9.62, 0)
        _asm(furniture, "lobby_bench", "bench", 2.45, -9.38, 0, L=1.5)
        rug_box(furniture, "lobby_runner", -0.65, -9.35, 1.3, 1.75,
                "rug_warm")
        # management office, package room, public restroom in the B wing
        walls.append(wall((-13.65, 5.40), (-5.51, 5.40), PART_T, WALL_H, z,
                          [door(2.2), door(6.4)]))
        walls.append(wall((-9.88, 2.67), (-9.88, 5.40), PART_T, WALL_H,
                          z, []))
        walls.append(wall((-11.90, 5.40), (-11.90, 7.30), PART_T, WALL_H, z,
                          [door(1.0)]))
        walls.append(wall((-13.65, 7.30), (-11.90, 7.30), PART_T, WALL_H,
                          z, []))
        rooms += [
            {"id": "F01_OFFICE", "rect": [-13.65, 2.67, -9.88, 5.40],
             "kind": "office"},
            {"id": "F01_PACKAGE", "rect": [-9.88, 2.67, -5.51, 5.40],
             "kind": "storage"},
            {"id": "F01_RESTROOM", "rect": [-13.65, 5.40, -11.90, 7.30],
             "kind": "bathroom"},
        ]
        bath_fixtures(furniture, "F01WC", [-13.65, 5.40, -11.90, 7.30], "w",
                      markers, z)
        desk_set(furniture, "F01_office", -13.2, 3.2, 1.3, True, 1)
        for i in range(2):
            shelf_unit(furniture, "f01_pkg%d" % i, -9.4 + i * 1.9, 2.85,
                       1.6, True, d=0.45, books=False, face="n")
        art_panel(furniture, "lobby_notice", 5.205, -8.85, 0.9, False,
                  z0=1.15, h=0.75, mat="paper")
        plant_box(furniture, "lobby_plant", -1.75, -9.35, big=True)
        # community room (B stack) and building storage (C stack)
        _asm(furniture, "common_table", "table_rect", -9.2, 6.6, 0,
             L=2.6, W=1.0)
        for i in range(3):
            chair_box(furniture, "common_ch%d" % i, -10.4 + i * 1.0, 5.60, "s")
            chair_box(furniture, "common_chn%d" % i, -10.4 + i * 1.0, 7.35, "n")
        _furn_box(furniture, "common_stack1", -13.3, 8.8, 0.55, 0.55,
                  0.0, 1.35, "metal", False)
        art_panel(furniture, "common_notice", -9.5, 2.745, 1.2, True,
                  z0=1.1, h=0.9, mat="paper")
        kitchen_run(furniture, "common_k", -6.15, 7.0, 2.2, False, "e")
        for i in range(3):
            shelf_unit(furniture, "f01_store%d" % i, 6.2, 1.4 + i * 2.6,
                       1.6, True, d=0.45, books=False, face="n")
            _furn_box(furniture, "f01_stcrate%d" % i, 8.4, 1.5 + i * 2.6,
                      0.8, 0.8, 0.0, 0.6, "trim", False)
        porch(floor_id, z, furniture)
        for stack in ("A", "D"):
            apartment(floor_id, stack, z, walls, rooms, markers, furniture)
        return floor

    for stack in ("A", "B", "C", "D"):
        apartment(floor_id, stack, z, walls, rooms, markers, furniture)
    rooms.append({"id": "%s_WSTOR" % floor_id, "rect": list(WSTOR_RECT),
                  "kind": "storage"})
    _furn_box(furniture, "%s_stor_crates" % floor_id, -12.9, 0.2, 2.2, 1.4,
              0.0, 1.1, "trim", False)
    rooms.append({"id": "%s_CORRIDOR" % floor_id,
                  "rect": [-XCO, -Y_IN, XCO, Y_IN], "kind": "corridor"})
    core_rooms(floor_id, z, rooms, furniture)
    chimney_block(floor_id, z, walls)
    porch(floor_id, z, furniture)
    markers.append({"kind": "flue_breast", "id": "%s_FLUE_BREAST" % floor_id,
                    "unit": floor_id + "C",
                    "pos": [10.0, 8.95, z], "yaw_deg": 180, "network": "flue"})
    if floor_id in ("F02", "F03", "F04", "F05", "F06"):
        markers.append({"kind": "porch_deck",
                        "id": "%s_PORCH_DECK" % floor_id,
                        "pos": [-9.15, 10.70, z], "yaw_deg": 0,
                        "network": "structural"})
    # Semantic junctions anchor the electrical/acoustic graph. They deliberately
    # spawn no prop: the old corridor_light markers created duplicate fixtures
    # at floor level underneath the ceiling-mounted dome family.
    markers.append({"kind": "electrical_junction",
                    "id": "%s_CORRLIGHT_S" % floor_id,
                    "pos": [0.0, -8.3, z + 2.75], "yaw_deg": 0,
                    "network": "electrical"})
    markers.append({"kind": "electrical_junction",
                    "id": "%s_CORRLIGHT_N" % floor_id,
                    "pos": [0.0, 8.3, z + 2.75], "yaw_deg": 0,
                    "network": "electrical"})
    return floor




# room kind -> ceiling/pendant fixture type. Bathrooms get their sconce
# from bath_fixtures; corridors keep their batten fluorescents; closets,
# vestibules and the sealed 2D go dark on purpose.
ROOM_FIXTURE = {
    "living": "pendant_shade", "common": "pendant_shade",
    "office": "pendant_shade",
    "bedroom": "flush_dome", "alcove": "flush_dome", "hall": "flush_dome",
    "kitchen": "kitchen_linear",
    "storage": "cage_bulb", "utility": "cage_bulb", "laundry": "cage_bulb",
    "boiler": "cage_bulb", "electrical": "cage_bulb",
    "storage_cages": "cage_bulb", "coal": "cage_bulb",
    "lobby": "chandelier",
    "atrium": "eye_pendant",
}


ROOM_LIGHT = {
    "living": 1.0, "bedroom": 0.85, "alcove": 0.78, "hall": 1.0,
    "kitchen": 1.12, "office": 1.15, "common": 1.05, "lobby": 1.25,
    "atrium": 1.0, "utility": 0.78, "storage": 0.7, "laundry": 0.85,
    "boiler": 0.7, "electrical": 0.75, "storage_cages": 0.65,
    "coal": 0.55,
}
# resident temperament: Mina keeps it bright and even, Juno lives in
# amp-glow, Omar floods the bench, Rhea works by playback light, Nadia
# burns task lighting, Sacha lives at monitor level
UNIT_LIGHT = {"2A": 1.15, "2C": 0.68, "3B": 1.25, "3D": 0.65,
              "5A": 1.20, "6A": 0.55, "4D": 1.0}


def light_fixture_markers(fl):
    """Every room earns a period fixture at its ceiling. 4B's main room
    keeps its bespoke ceiling_light; fire-gutted 5D hangs nothing.
    The basement storey is 2.8 m floor-to-floor (2.62 clear), so its
    fixtures mount 0.4 m lower — at ITS ceiling, not inside the F01
    slab (they used to poke through and stand on the hallway floors)."""
    z = fl["z"]
    ceil = 2.56 if fl["id"] == "B1" else 2.96
    # Corridors need a legible pool at every turn, stair/elevator approach,
    # and long run.  The LightRig budgets nearby omnis while emissive fixture
    # bodies keep the complete rhythm visible at distance.
    if fl["id"] not in ("ROOF",):
        for i, (cx, cy) in enumerate((
                (-4.35, -5.1), (-4.35, 0.0), (-4.35, 5.1),
                (4.35, -5.1), (4.35, 0.0), (4.35, 5.1),
                (0.0, -8.25), (0.0, 8.25))):
            fl["markers"].append({
                "kind": "flush_dome",
                "id": "%s_CORRIDOR_DOME_%02d" % (fl["id"], i + 1),
                "unit": fl["id"], "pos": [cx, cy, z + ceil - 0.02],
                "range": 4.2, "energy": 0.9,
                "yaw_deg": 0, "network": "electrical"})
    for r in fl["rooms"]:
        fix = ROOM_FIXTURE.get(r["kind"])
        if fix is None:
            continue
        unit = r.get("unit", "")
        if unit == "2D" or unit == "5D":
            continue
        if r["id"] in ("F04_B_MAIN", "F01_VESTIBULE"):
            continue
        x0, y0, x1, y1 = r["rect"]
        cx, cy = (x0 + x1) / 2.0, (y0 + y1) / 2.0
        if r["kind"] == "atrium":
            cx, cy = 0.0, 0.0   # the drop hangs dead-center in the eye
        if r["kind"] == "lobby" and r["id"] != "F01_LOBBY":
            continue
        marker = {
            "kind": fix, "id": "%s_LT_%s" % (r["id"], fix.upper()),
            "unit": unit or fl["id"],
            "pos": [round(cx, 3), round(cy, 3), z + ceil],
            "yaw_deg": 0, "network": "electrical"}
        if r["kind"] != "atrium":   # the eye is meant to throw far
            rw, rd = x1 - x0, y1 - y0
            marker["range"] = round((rw * rw + rd * rd) ** 0.5 / 2.0
                                    + 0.9, 2)
        e_mult = UNIT_LIGHT.get(unit, 0.85 + (sum(ord(c) for c in unit)
                                              % 6) * 0.05) if unit else 1.0
        marker["energy"] = round(ROOM_LIGHT.get(r["kind"], 1.0) * e_mult, 2)
        fl["markers"].append(marker)


def collect_door_markers(fl):
    """Every door opening with a leaf becomes a spawnable hinged door,
    and every doorway earns a molded toggle switch on each wall face at
    the latch side — identity down to the light switch."""
    n = 0
    for w in fl["walls"]:
        length = abs((w["b"][0] - w["a"][0]) or (w["b"][1] - w["a"][1]))
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
            if o.get("swing"):
                fl["markers"][-1]["swing"] = o["swing"]
            latch = start + o["at"] + o["w"] / 2.0 + 0.17
            if latch > length + start - 0.10:
                latch = hinge - 0.17
            off = w["t"] / 2.0 + 0.002
            for side, yaw in (((0, -off), 180), ((0, off), 0)) \
                    if horizontal else (((-off, 0), 90), ((off, 0), -90)):
                sx_, sy_ = (latch + side[0], cross + side[1]) if horizontal \
                        else (cross + side[0], latch + side[1])
                if horizontal:
                    sx_, sy_ = latch, cross + side[1]
                else:
                    sx_, sy_ = cross + side[0], latch
                fl["furniture"].append({
                    "id": "%s_SW_%02d_%d" % (fl["id"], n, yaw % 360),
                    "asm": "switch", "at": [round(sx_, 4), round(sy_, 4)],
                    "yaw": yaw, "z0": 1.12})

def aging_pass(floors):
    rng = random.Random(1927)
    for fl in floors:
        fid = fl["id"]
        furn = fl["furniture"]

        def fb(bid, rect, z0, h, mat):
            furn.append({"id": "age_" + bid, "rect": list(rect), "z0": z0,
                         "h": h, "mat": mat})

        if fid in ("F02", "F03", "F04", "F05", "F06"):
            for i in range(3):
                side = rng.choice(("w", "e", "n"))
                c = rng.uniform(-8.0, 8.0)
                w_ = rng.uniform(0.6, 1.6)
                z0 = rng.uniform(0.3, 2.2)
                if side == "w":
                    fb("patch%s%d" % (fid, i), (-14.005, c, -13.995, c + w_),
                       z0, rng.uniform(0.5, 1.2), "fx_patch")
                elif side == "e":
                    fb("patch%s%d" % (fid, i), (13.995, c, 14.005, c + w_),
                       z0, rng.uniform(0.5, 1.2), "fx_patch")
                else:
                    fb("patch%s%d" % (fid, i), (c, 9.995, c + w_, 10.005),
                       z0, rng.uniform(0.5, 1.2), "fx_patch")
            fb("lane_s%s" % fid, (-4.9, -9.1, 4.9, -7.5), 0.013, 0.002,
               "plaster_stained")
            fb("lane_w%s" % fid, (-5.1, -6.9, -3.7, 6.9), 0.013, 0.002,
               "plaster_stained")
            px = rng.uniform(-4.0, 3.0)
            fb("lino%s" % fid, (px, 7.1, px + 1.2, 8.9), 0.012, 0.003,
               "linoleum")
        if fid == "F05":
            for k, wc in enumerate((-9.65 + 8.65 * 0.30, -9.65 + 8.65 * 0.70)):
                fb("soot%d" % k, (14.0, wc - 0.8, 14.05, wc + 0.8),
                   2.55, 0.75, "char")
                fb("board%d" % k, (14.0, wc - 0.70, 14.06, wc + 0.70),
                   0.80, 1.80, "plywood")
            fb("char_ceiling", (9.0, -6.0, 12.0, -3.5), 2.95, 0.06, "char")
        if fid == "F03":
            wc = -0.88 + 10.53 * 0.70
            fb("board3c", (14.0, wc - 0.70, 14.06, wc + 0.70), 0.80, 1.80,
               "plywood")
        if fid == "F04":
            for j, (wx, wy) in enumerate(((-14.3, 4.76), (14.0, 2.28))):
                fb("ac%d" % j, (wx, wy - 0.30, wx + 0.30, wy + 0.30), 0.95,
                   0.42, "metal")
                fb("acdrip%d" % j, (wx + (0.28 if wx < 0 else 0.0),
                   wy - 0.05, wx + (0.30 if wx < 0 else 0.02), wy + 0.05),
                   0.0, 0.95, "plaster_stained")
        if fid == "ROOF":
            for i in range(5):
                px, py = rng.uniform(-12, 12), rng.uniform(-8, 8)
                fb("tar%d" % i, (px, py, px + rng.uniform(0.8, 2.2),
                   py + rng.uniform(0.6, 1.5)), 0.012, 0.004, "char")
            fb("coping_repair", (2.0, -10.08, 4.6, -9.92), 1.10, 0.09,
               "concrete")
            fb("dish", (11.6, -8.8, 12.5, -8.7), 1.0, 0.9, "metal")
            fb("dishpole", (12.0, -8.79, 12.08, -8.71), 0.0, 1.0, "metal")
            for a in range(2):
                fb("mast%d" % a, (-3.0 + a * 1.4, 8.9, -2.94 + a * 1.4,
                   8.96), 0.0, 3.2 + a * 0.8, "metal")
        if fid == "F01":
            fb("damp_s1", (-13.9, -10.06, -1.55, -9.965), 0.45, 0.28,
               "fx_damp")
            fb("damp_s2", (1.55, -10.06, 13.9, -9.965), 0.45, 0.28,
               "fx_damp")
            for i, sx in enumerate((-11.0, 6.5)):
                fb("streak%d" % i, (sx, -10.055, sx + 0.25, -9.97), 0.7,
                   2.3, "fx_drip")


## The building's block: a crowded 2027 street on limited land. Sidewalk
## and stoop out front, service alley behind serving the porches and coal
## chute, tight gangways between the neighbors' party walls.
def site_pass(fl):
    furn = fl["furniture"]

    def fb(bid, rect, z0, h, mat):
        furn.append({"id": "site_" + bid, "rect": list(rect), "z0": z0,
                     "h": h, "mat": mat})

    fb("ground", (-20.0, -24.0, 20.0, 16.0), -0.30, 0.28, "asphalt")
    fb("sidewalk", (-20.0, -14.6, 20.0, -10.0), -0.02, 0.03, "concrete")
    fb("curb", (-20.0, -14.75, 20.0, -14.60), -0.02, 0.14, "concrete")
    fb("alley", (-20.0, 10.0, 20.0, 13.4), -0.02, 0.015, "concrete")
    for bid, rect, hgt in (("nbr_w", (-19.6, -12.0, -15.2, 12.0), 12.8),
                           ("nbr_e", (15.2, -12.0, 19.6, 12.0), 12.8),
                           ("nbr_s1", (-20.0, -24.0, -7.0, -18.2), 10.4),
                           ("nbr_s2", (-5.6, -24.0, 6.4, -18.2), 15.8),
                           ("nbr_s3", (7.8, -24.0, 20.0, -18.2), 8.6),
                           ("garages", (-16.0, 13.4, 16.0, 16.0), 3.0)):
        fb(bid, rect, 0.0, hgt, "common_brick")
    for i in range(10):
        x = -18.6 + (i % 5) * 1.9
        fb("nwin_w%d" % i, (-15.19, -9.0 + (i % 5) * 3.7, -15.15,
           -8.0 + (i % 5) * 3.7), 1.2 + (i // 5) * 3.4, 1.3, "glassish")
        fb("nwin_e%d" % i, (15.15, -9.0 + (i % 5) * 3.7, 15.19,
           -8.0 + (i % 5) * 3.7), 1.2 + (i // 5) * 3.4, 1.3, "glassish")
        fb("nwin_s%d" % i, (x, -18.19, x + 0.9, -18.15),
           1.5 + (i // 5) * 4.0, 1.4, "glassish")
    for i, lx in enumerate((-9.0, 6.0)):
        fb("lamp_pole%d" % i, (lx, -14.55, lx + 0.12, -14.43), 0.0, 4.6,
           "metal")
        fb("lamp_head%d" % i, (lx - 0.15, -14.7, lx + 0.27, -14.28), 4.6,
           0.25, "metal")
    fb("hydrant", (-3.4, -10.85, -3.05, -10.5), 0.0, 0.75, "metal")
    fb("power_pole", (16.2, 11.0, 16.5, 11.3), 0.0, 8.5, "timber")
    fb("power_line", (10.5, 11.05, 16.2, 11.12), 7.6, 0.05, "metal")
    for i in range(3):
        cx = -12.0 + i * 6.5
        fb("car%d" % i, (cx, -16.9, cx + 4.4, -15.1), 0.28, 0.95, "metal")
        fb("cartop%d" % i, (cx + 1.1, -16.7, cx + 3.3, -15.3), 1.23, 0.45,
           "metal")
    fb("bin1", (12.6, 10.3, 13.6, 11.1), 0.0, 1.1, "metal")
    fb("bin2", (-13.9, 10.3, -12.9, 11.2), 0.0, 1.15, "metal")


# ---------------------------------------------------------------- stairs

def stair_geometry(st):
    """Atrium switchback around the open eye. Per climb, three parts stay
    in [flight, landing, flight] order (the walkthrough indexes on that):
    west flight up off the south deck, full-width north landing at the
    half level, east flight back down to the next deck. Floor-level south
    decks are emitted after the climbs, one per landing level, plus the
    eye-edge guard data the builder turns into balustrades."""
    parts = []
    wx0, wy0, wx1, wy1 = st["well"]
    w = st["width"]
    deck_edge = wy0 + w          # decks span wy0..deck_edge (south strip)
    land_edge = wy1 - w          # north landing spans land_edge..wy1
    run = land_edge - deck_edge  # flight run between them
    lvls = st["levels"]
    for i in range(len(lvls) - 1):
        z0, z1 = LEVELS[lvls[i]], LEVELS[lvls[i + 1]]
        risers = int(round((z1 - z0) / st["rise"]))
        n1 = risers // 2 + risers % 2
        n2 = risers - n1
        rise = (z1 - z0) / risers
        lz = z0 + n1 * rise
        # west flight: south deck edge up to the north half landing
        parts.append({"kind": "flight", "z0": z0, "rise": rise,
                      "tread": run / (n1 - 1), "n": n1, "axis": "y",
                      "dir": 1, "start": deck_edge, "b0": wx0,
                      "b1": wx0 + w, "rail_side": "hi"})
        parts.append({"kind": "landing", "z": lz,
                      "rect": [wx0, land_edge, wx1, wy1],
                      "guard_edge": "s", "guard_span": [wx0 + w, wx1 - w]})
        # east flight: north landing back south, one level up
        parts.append({"kind": "flight", "z0": lz, "rise": rise,
                      "tread": run / (n2 - 1), "n": n2, "axis": "y",
                      "dir": -1, "start": land_edge, "b0": wx1 - w,
                      "b1": wx1, "rail_side": "lo", "exit": True})
    for name in lvls[1:]:        # floor-level south decks (arrivals)
        parts.append({"kind": "landing", "z": LEVELS[name],
                      "rect": [wx0, wy0, wx1, deck_edge]})
    return {"id": st["id"], "well": list(st["well"]), "width": st["width"],
            "gap": wx1 - wx0 - 2 * w, "entry_side": "s",
            "entry_y": deck_edge, "gap_span": [wx0 + w, wx1 - w],
            "levels": [[l, LEVELS[l]] for l in lvls], "parts": parts}


# ---------------------------------------------------------------- validation

def remove_partition_crossing_windows(fl):
    """Remove facade windows whose opening is cut through by a perpendicular
    interior partition.

    Exterior openings are established before apartment room walls, so a
    purely local facade rule cannot know where bedrooms, baths and offices
    eventually meet the shell. This post-layout pass compares every exterior
    window span with every perpendicular wall that actually reaches that
    facade. A small trim clearance prevents jambs from grazing partitions.
    """
    if fl["id"] in ("B1", "ROOF"):
        return 0
    removed = 0
    walls = fl["walls"]
    for ew in walls:
        ax, ay = ew["a"]
        bx, by = ew["b"]
        vertical = abs(bx - ax) < 1e-6
        exterior_wall = (vertical and abs(ax) > 13.5) or \
                        (not vertical and abs(ay) > 9.5)
        if not exterior_wall:
            continue
        start = min(ay, by) if vertical else min(ax, bx)
        kept = []
        for opening in ew["openings"]:
            if opening["type"] != "window":
                kept.append(opening)
                continue
            lo = start + opening["at"] - opening["w"] / 2.0 - 0.10
            hi = start + opening["at"] + opening["w"] / 2.0 + 0.10
            crossed = False
            for iw in walls:
                if iw is ew:
                    continue
                ix0, iy0 = iw["a"]
                ix1, iy1 = iw["b"]
                i_vertical = abs(ix1 - ix0) < 1e-6
                if vertical == i_vertical:
                    continue
                if vertical:
                    reaches = min(ix0, ix1) - 0.35 <= ax <= \
                              max(ix0, ix1) + 0.35
                    partition_at = iy0
                else:
                    reaches = min(iy0, iy1) - 0.35 <= ay <= \
                              max(iy0, iy1) + 0.35
                    partition_at = ix0
                if reaches and lo < partition_at < hi:
                    crossed = True
                    break
            if crossed:
                removed += 1
            else:
                kept.append(opening)
        ew["openings"] = kept
    return removed


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
    problems += _validate_furnishing(layout)
    problems += _validate_movement(layout)
    problems += _validate_placement(layout)
    return problems


def _validate_placement(layout):
    """Catch prop-height and wall-center regressions before export."""
    problems = []
    ceiling_kinds = {"pendant_shade", "flush_dome", "kitchen_linear",
                     "cage_bulb", "chandelier", "eye_pendant"}
    wall_kinds = {"door", "radiator", "sconce_globe", "exhaust_fan",
                  "wall_clock", "flue_breast", "door_anomaly"}
    floor_kinds = {"washer", "dryer", "boiler", "fridge", "boxfan",
                   "speaker", "toaster"}

    def point_in_wall(px, py, w):
        ax, ay = w["a"]
        bx, by = w["b"]
        pad = w["t"] / 2.0 + 0.025
        if abs(by - ay) < 1e-6:
            return min(ax, bx) - pad <= px <= max(ax, bx) + pad and \
                   abs(py - ay) <= pad
        return min(ay, by) - pad <= py <= max(ay, by) + pad and \
               abs(px - ax) <= pad

    for fl in layout["floors"]:
        z = fl["z"]
        for m in fl["markers"]:
            kind = m["kind"]
            px, py, pz = m["pos"]
            if kind == "corridor_light":
                problems.append("%s: legacy floor-level corridor light %s"
                                % (fl["id"], m["id"]))
            # B1 is a 2.8 m storey: its ceiling sits at +2.62, so its
            # fixtures mount ~0.4 lower than the 3.2 m floors above
            clo, chi = (2.40, 2.60) if fl["id"] == "B1" else (2.70, 3.08)
            if kind in ceiling_kinds and not z + clo <= pz <= z + chi:
                problems.append("%s: ceiling fixture %s at bad height %.2f"
                                % (fl["id"], m["id"], pz - z))
            if kind == "electrical_junction" and pz < z + 2.6:
                problems.append("%s: electrical junction %s below ceiling"
                                % (fl["id"], m["id"]))
            if kind in floor_kinds and not z - 0.03 <= pz <= z + 1.2:
                problems.append("%s: floor prop %s at bad height %.2f"
                                % (fl["id"], m["id"], pz - z))
            if kind not in wall_kinds and kind not in ceiling_kinds and \
                    kind != "electrical_junction":
                if any(point_in_wall(px, py, w) for w in fl["walls"]):
                    problems.append("%s: prop %s centered inside wall"
                                    % (fl["id"], m["id"]))
        for fu in fl.get("furniture", []):
            if "asm" not in fu or fu["asm"] in (
                    "switch", "pipe", "sink_ped", "mailbank"):
                continue
            px, py = fu["at"]
            if any(point_in_wall(px, py, w) for w in fl["walls"]):
                problems.append("%s: assembly %s centered inside wall"
                                % (fl["id"], fu["id"]))
    return sorted(set(problems))


# approximate footprint half-extents per assembly kind (worst-case with
# arms/overhangs), used by the movement audit. Rugs and ceiling work are
# not obstacles; hulls under 0.3 m tall don't stop a capsule either.
ASM_FOOT = {
    "sofa": (1.14, 0.44), "chair": (0.24, 0.25), "table_round": (0.57, 0.57),
    "table_rect": (0.62, 0.42), "coffee": (0.56, 0.36),
    "nightstand": (0.24, 0.24), "bed": (0.76, 1.03), "wardrobe": (0.68, 0.33),
    "shelf": (0.57, 0.16), "tv": (0.64, 0.22), "plant": (0.25, 0.25),
    "kitchen": (0.90, 0.33), "stove": (0.32, 0.34), "fridge50": (0.34, 0.41),
    "desk": (0.71, 0.34), "plantable": (1.01, 0.61),
    "workbench": (1.11, 0.49), "toilet": (0.21, 0.36),
    "sink_ped": (0.25, 0.25), "shower": (0.41, 0.42), "bench": (0.76, 0.25),
    "mailbank": (0.81, 0.10),
}


def _asm_aabb(fu):
    kind = fu.get("asm")
    if kind not in ASM_FOOT:
        return None
    hx, hy = ASM_FOOT[kind]
    if kind == "table_rect":
        hx, hy = fu.get("L", 1.2) / 2.0 + 0.05, fu.get("W", 0.8) / 2.0 + 0.05
    elif kind == "sofa":
        hx = fu.get("L", 1.95) / 2.0 + 0.18
    elif kind == "kitchen":
        hx = fu.get("L", 2.5) / 2.0 - 0.375 + 0.03
    elif kind == "shelf":
        hx = fu.get("W", 1.1) / 2.0 + 0.02
    elif kind == "bench":
        hx = fu.get("L", 1.5) / 2.0 + 0.02
    yaw = fu.get("yaw", 0) % 180
    if yaw == 90:
        hx, hy = hy, hx
    elif yaw not in (0, 90):          # free-rotated: safe square
        hx = hy = max(hx, hy)
    cx, cy = fu["at"]
    return (cx - hx, cy - hy, cx + hx, cy + hy)


def _obstacles(fl):
    obs = []
    for fu in fl.get("furniture", []):
        if "asm" in fu:
            if fu["asm"] in ("switch", "pipe"):
                continue
            bb = _asm_aabb(fu)
            if bb:
                obs.append((fu["id"], bb))
        else:
            if fu.get("z0", 0.0) >= 1.9 or fu.get("h", 1.0) <= 0.30:
                continue  # ceiling work / floor-level trim, not obstacles
            r = fu["rect"]
            obs.append((fu["id"], (r[0], r[1], r[2], r[3])))
    return obs


def _hit(bb, x0, y0, x1, y1):
    return bb[0] < x1 and x0 < bb[2] and bb[1] < y1 and y0 < bb[3]


## "NPCs and the PC must be able to freely move": every hinged door's
## swing quarter must be clear, and a 0.8 m band from each apartment door
## to its room center must be passable. Fails the build on regression.
def _validate_movement(layout):
    problems = []
    for fl in layout["floors"]:
        obs = _obstacles(fl)
        rooms = {r["id"]: r for r in fl["rooms"]}
        for m in fl["markers"]:
            if m["kind"] != "door" or m.get("leaf") == "none"                     or m.get("cabinet"):
                continue
            w = m["w"]
            px, py = m["pos"][0], m["pos"][1]
            if m["yaw_deg"] == 0:      # wall runs along x; swings +-y
                sw = (px, py - w, px + w, py + w)
            else:                      # wall along y
                sw = (px - w, py, px + w, py + w)
            tol = 0.08   # leaves may pass within a hand's width
            for oid, bb in obs:
                if _hit(bb, sw[0] + tol, sw[1] + tol, sw[2] - tol,
                        sw[3] - tol):
                    problems.append("%s: door %s swing blocked by %s"
                                    % (fl["id"], m["id"], oid))
        # every refrigerator door needs standing room in front of it
        for fu in fl.get("furniture", []):
            if fu.get("asm") != "fridge50":
                continue
            import math as _m
            a = _m.radians(fu.get("yaw", 0))
            fx_, fy_ = -_m.sin(a), _m.cos(a)   # local +y (door) in world
            bx0_ = fu["at"][0] + fx_ * 0.85 - 0.42
            by0_ = fu["at"][1] + fy_ * 0.85 - 0.42
            band = (bx0_, by0_, bx0_ + 0.84, by0_ + 0.84)
            for oid, bb in obs:
                if oid == fu["id"] or oid.startswith(fu["id"][:-3]):
                    continue
                if _hit(bb, band[0] + 0.06, band[1] + 0.06,
                        band[2] - 0.06, band[3] - 0.06):
                    problems.append("%s: fridge %s door blocked by %s"
                                    % (fl["id"], fu["id"], oid))
        # path: unit entry -> living center, an L in either order must
        # be passable at capsule width (a person routes around a chair;
        # they should never have to climb the furniture)
        ENTRY_Y = {"A": lambda rc: rc[3] - 1.2 + 0.0,
                   "B": lambda rc: rc[1] + 0.63,
                   "C": lambda rc: rc[1] + 2.08,
                   "D": lambda rc: rc[3] + 0.0 - (-2.31 - rc[3])}
        nested = {}
        for r in fl["rooms"]:
            if r["kind"] in ("bathroom", "office", "closet"):
                nested.setdefault(r.get("unit", ""), []).append(
                    ("wall:" + r["id"], tuple(r["rect"])))
        for r in fl["rooms"]:
            if r["kind"] != "living" or r.get("unit") in ("2D",):
                continue
            unit = r.get("unit", "")
            stack = unit[-1] if unit else "A"
            sx0, sy0, sx1, sy1 = STACK_RECTS.get(stack, r["rect"])
            east = stack in ("C", "D")
            ey = {"A": sy1 - 1.2, "B": sy0 + 3.30, "C": sy0 + 1.2,
                  "D": sy0 + 6.34}.get(stack, (sy0 + sy1) / 2)
            if unit == "4B":
                ey = sy0 + 1.2
            x0, y0, x1, y1 = r["rect"]
            cx, cy = (x0 + x1) / 2.0, (y0 + y1) / 2.0
            door_x = sx0 + 0.55 if east else sx1 - 0.55
            entry = (door_x, ey)

            route_obs = obs + nested.get(unit, [])

            def leg_clear(ax, ay, bx, by):
                for i in range(15):
                    t = i / 14.0
                    px_, py_ = ax + (bx - ax) * t, ay + (by - ay) * t
                    band = (px_ - 0.35, py_ - 0.35, px_ + 0.35, py_ + 0.35)
                    for _oid, bb in route_obs:
                        if _hit(bb, *band):
                            return _oid
                return None

            # a person needs to reach the living AREA, not one exact
            # point a table may rightly occupy: five targets, L-routes
            # in both leg orders, any success passes
            blockers = []
            ok = False
            for tx, ty in ((cx, cy), (cx - 0.95, cy), (cx + 0.95, cy),
                           (cx, cy - 0.95), (cx, cy + 0.95)):
                b1 = leg_clear(entry[0], entry[1], tx, entry[1])                         or leg_clear(tx, entry[1], tx, ty)
                b2 = leg_clear(entry[0], entry[1], entry[0], ty)                         or leg_clear(entry[0], ty, tx, ty)
                if not b1 or not b2:
                    ok = True
                    break
                blockers.append(b1)
            if not ok:
                problems.append("%s: no clear route into %s (%s)"
                                % (fl["id"], r["id"], blockers[0]))
        # circulation rooms must hold nothing but rugs and ceiling work
        for r in fl["rooms"]:
            if r["kind"] not in ("corridor", "hall"):
                continue
            x0, y0, x1, y1 = r["rect"]
            for oid, bb in obs:
                if oid.startswith(("lobby_", "common_", "entry_",
                                   "water_table")):
                    continue  # lobby program is placed intentionally
                if r["kind"] == "corridor" and abs(bb[0] + bb[2]) / 2 < 3.5                         and abs(bb[1] + bb[3]) / 2 < 6.93:
                    continue  # core column: hall/utility/atrium territory
                if _hit(bb, x0 + 0.05, y0 + 0.05, x1 - 0.05, y1 - 0.05):
                    problems.append("%s: %s obstructs %s"
                                    % (fl["id"], oid, r["id"]))
    return sorted(set(problems))


## "Everything the residents need": every occupied unit must hold a bed,
## a full kitchen trio, a complete bath suite, wardrobe and dining; every
## unit (occupied or not) keeps its radiator; switch count = 2 x doors;
## the kitchen trio must share one facing. Prop counts print as a report.
def _validate_furnishing(layout):
    problems = []
    unit_asm, unit_yaw, unit_rad = {}, {}, set()
    doors, switches, kinds = 0, 0, {}
    for fl in layout["floors"]:
        for m in fl["markers"]:
            kinds[m["kind"]] = kinds.get(m["kind"], 0) + 1
            if m["kind"] == "door" and not m.get("cabinet"):
                doors += 1  # cabinet leaves are joinery, not doorways
            if m["kind"] == "radiator" and m.get("unit"):
                unit_rad.add(m["unit"])
        for fu in fl.get("furniture", []):
            if "asm" not in fu:
                continue
            if fu["asm"] == "switch":
                switches += 1
                continue
            unit = str(fu["id"]).split("_")[0]
            unit_asm.setdefault(unit, {})
            unit_asm[unit][fu["asm"]] = unit_asm[unit].get(fu["asm"], 0) + 1
            if fu["id"].endswith(("_k", "_k_stove", "_k_fr")):
                unit_yaw.setdefault(unit, set()).add(fu.get("yaw"))
    if switches != 2 * doors:
        problems.append("switches %d != 2 x doors %d" % (switches, doors))
    skip_states = ("sealed", "vacant (damaged)", "vacant (fire damage)",
                   "landlord storage")
    need = {"bed": 1, "kitchen": 1, "stove": 1, "fridge50": 1,
            "toilet": 1, "sink_ped": 1, "shower": 1, "wardrobe": 1,
            "chair": 2}
    for unit, res in RESIDENTS.items():
        if res in skip_states:
            continue
        if unit not in unit_rad:
            problems.append("%s has no radiator" % unit)
        a = unit_asm.get(unit, {})
        if res == "PLAYER":  # 4B is bespoke; the bath suite is shared code
            for k in ("toilet", "sink_ped", "shower"):
                if a.get(k, 0) < 1:
                    problems.append("4B missing %s" % k)
            continue
        for k, n in need.items():
            if a.get(k, 0) < n:
                problems.append("%s missing %s (%d < %d)"
                                % (unit, k, a.get(k, 0), n))
        if a.get("table_round", 0) + a.get("table_rect", 0) < 1:
            problems.append("%s has no dining table" % unit)
        yaws = unit_yaw.get(unit, set())
        if len(yaws) > 1:
            problems.append("%s kitchen trio facing disagrees %s"
                            % (unit, sorted(yaws)))
    n_asm = sum(sum(v.values()) for v in unit_asm.values()) + switches
    print("furnishing OK: %d assemblies (%d switches), %d door leaves, "
          "%d radiators" % (n_asm, switches, doors, kinds.get("radiator", 0)))
    print("marker counts:", dict(sorted(kinds.items())))
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
            elif m["kind"] in ("lamp", "monitor", "toaster", "fridge",
                               "boxfan", "speaker", "kettle", "wall_clock",
                               "smoke_detector", "exhaust_fan",
                               "ceiling_light", "pendant_shade",
                               "flush_dome", "sconce_globe",
                               "kitchen_linear", "cage_bulb", "chandelier",
                               "eye_pendant"):
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
            elif m["kind"] == "electrical_junction":
                add(m["id"], m["pos"],
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
    # chimney flue: a masonry speaking tube from the boiler to the sky
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
    "pendant_shade": {"minimum_action_interval": 0.07,
                      "maximum_action_rate": 10,
                      "available_mechanical_events": ["filament_surge"],
                      "preferred_subdivision": 2, "timing_drift": 0.0,
                      "response_latency": 0.01,
                      "normal_function_priority": 1.0,
                      "infection_receptivity": 0.7},
    "flush_dome": {"minimum_action_interval": 0.07,
                   "maximum_action_rate": 10,
                   "available_mechanical_events": ["filament_surge"],
                   "preferred_subdivision": 2, "timing_drift": 0.0,
                   "response_latency": 0.01,
                   "normal_function_priority": 1.0,
                   "infection_receptivity": 0.65},
    "sconce_globe": {"minimum_action_interval": 0.07,
                     "maximum_action_rate": 10,
                     "available_mechanical_events": ["filament_surge"],
                     "preferred_subdivision": 2, "timing_drift": 0.0,
                     "response_latency": 0.01,
                     "normal_function_priority": 1.0,
                     "infection_receptivity": 0.6},
    "kitchen_linear": {"minimum_action_interval": 0.08,
                       "maximum_action_rate": 9,
                       "available_mechanical_events": ["starter_buzz",
                                                       "flicker"],
                       "preferred_subdivision": 2, "timing_drift": 0.015,
                       "response_latency": 0.02,
                       "normal_function_priority": 1.0,
                       "infection_receptivity": 0.6},
    "cage_bulb": {"minimum_action_interval": 0.07,
                  "maximum_action_rate": 12,
                  "available_mechanical_events": ["filament_surge",
                                                  "swing"],
                  "preferred_subdivision": 2, "timing_drift": 0.02,
                  "response_latency": 0.01,
                  "normal_function_priority": 1.0,
                  "infection_receptivity": 0.75},
    "chandelier": {"minimum_action_interval": 0.10,
                   "maximum_action_rate": 8,
                   "available_mechanical_events": ["filament_surge",
                                                   "crystal_tick"],
                   "preferred_subdivision": 1, "timing_drift": 0.0,
                   "response_latency": 0.02,
                   "normal_function_priority": 1.0,
                   "infection_receptivity": 0.8},
    "eye_pendant": {"minimum_action_interval": 0.08,
                    "maximum_action_rate": 10,
                    "available_mechanical_events": ["filament_surge",
                                                    "sway"],
                    "preferred_subdivision": 1, "timing_drift": 0.01,
                    "response_latency": 0.01,
                    "normal_function_priority": 1.0,
                    "infection_receptivity": 0.85},
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
    # stairwell + surface-detail palette (reference: worn Altbau stairwell)
    "wainscot": {"base_color": [0.30, 0.40, 0.34, 1.0], "roughness": 0.55},
    "handrail_wood": {"base_color": [0.24, 0.16, 0.11, 1.0], "roughness": 0.35},
    "baluster": {"base_color": [0.82, 0.80, 0.74, 1.0], "roughness": 0.50},
    "ceramic": {"base_color": [0.79, 0.81, 0.80, 1.0], "roughness": 0.22},
    # lived-in furnishing palette
    "wood_dark": {"base_color": [0.28, 0.20, 0.14, 1.0], "roughness": 0.50},
    "linen": {"base_color": [0.86, 0.85, 0.81, 1.0], "roughness": 0.85},
    "paper": {"base_color": [0.90, 0.88, 0.82, 1.0], "roughness": 0.85},
    "fabric_warm": {"base_color": [0.56, 0.35, 0.27, 1.0], "roughness": 0.92},
    "fabric_cool": {"base_color": [0.36, 0.42, 0.51, 1.0], "roughness": 0.92},
    "fabric_green": {"base_color": [0.38, 0.46, 0.36, 1.0], "roughness": 0.92},
    "rug_warm": {"base_color": [0.47, 0.26, 0.21, 1.0], "roughness": 0.95},
    "rug_cool": {"base_color": [0.26, 0.31, 0.39, 1.0], "roughness": 0.95},
    "rug_green": {"base_color": [0.31, 0.38, 0.30, 1.0], "roughness": 0.95},
    "plant": {"base_color": [0.25, 0.39, 0.22, 1.0], "roughness": 0.80},
    "screen": {"base_color": [0.07, 0.08, 0.09, 1.0], "roughness": 0.25},
    "appliance": {"base_color": [0.87, 0.88, 0.86, 1.0], "roughness": 0.30},
    "soot": {"base_color": [0.09, 0.09, 0.09, 1.0], "roughness": 0.90},
    "brass": {"base_color": [0.55, 0.46, 0.26, 1.0], "roughness": 0.30,
              "metallic": 0.85},
    "art": {"base_color": [0.52, 0.44, 0.34, 1.0], "roughness": 0.60},
    # 1927 masonry & structure palette (accuracy-audit pass)
    "face_brick": {"base_color": [0.38, 0.16, 0.12, 1.0], "roughness": 0.82},
    "common_brick": {"base_color": [0.62, 0.42, 0.31, 1.0],
                     "roughness": 0.88},
    "limestone": {"base_color": [0.78, 0.75, 0.67, 1.0], "roughness": 0.6},
    "timber": {"base_color": [0.43, 0.32, 0.22, 1.0], "roughness": 0.75},
    # fake-GI decal quads: baked contact shadows and wall-base occlusion
    "fx_shadow": {"base_color": [1.0, 1.0, 1.0, 1.0], "roughness": 1.0},
    "fx_ao": {"base_color": [1.0, 1.0, 1.0, 1.0], "roughness": 1.0},
    # century-of-aging + site palette (parallel session)
    "asphalt": {"base_color": [0.16, 0.16, 0.17, 1.0], "roughness": 0.9},
    "linoleum": {"base_color": [0.55, 0.50, 0.40, 1.0], "roughness": 0.5},
    "plywood": {"base_color": [0.64, 0.54, 0.38, 1.0], "roughness": 0.8},
    "char": {"base_color": [0.06, 0.055, 0.05, 1.0], "roughness": 0.95},
    "brick_patched": {"base_color": [0.55, 0.35, 0.28, 1.0],
                      "roughness": 0.85},
    "plaster_stained": {"base_color": [0.46, 0.44, 0.39, 1.0],
                        "roughness": 0.75},
    "fx_traffic": {"base_color": [1.0, 1.0, 1.0, 1.0], "roughness": 1.0},
    "fx_scuff": {"base_color": [1.0, 1.0, 1.0, 1.0], "roughness": 1.0},
    "fx_drip": {"base_color": [1.0, 1.0, 1.0, 1.0], "roughness": 1.0},
    "fx_grease": {"base_color": [1.0, 1.0, 1.0, 1.0], "roughness": 1.0},
    "fx_burn": {"base_color": [1.0, 1.0, 1.0, 1.0], "roughness": 1.0},
    "fx_patch": {"base_color": [1.0, 1.0, 1.0, 1.0], "roughness": 1.0},
    "fx_damp": {"base_color": [1.0, 1.0, 1.0, 1.0], "roughness": 1.0},
    # appliance & hardware finishes for the parametric asset library
    "chrome": {"base_color": [0.80, 0.82, 0.85, 1.0], "roughness": 0.12,
               "metallic": 1.0},
    "enamel": {"base_color": [0.91, 0.89, 0.83, 1.0], "roughness": 0.18},
    "bakelite": {"base_color": [0.16, 0.12, 0.10, 1.0], "roughness": 0.30},
    "porcelain": {"base_color": [0.92, 0.93, 0.92, 1.0], "roughness": 0.14},
}


def main():
    floors = [build_floor(f) for f in
              ("B1", "F01", "F02", "F03", "F04", "F05", "F06", "ROOF")]
    removed_windows = sum(remove_partition_crossing_windows(fl)
                          for fl in floors)
    print("facade audit: removed %d partition-crossing windows"
          % removed_windows)
    for fl in floors:
        collect_door_markers(fl)
        light_fixture_markers(fl)
    aging_pass(floors)
    site_pass(floors[1])  # the block lives with F01
    layout = {
        "meta": {"name": "Orison Apartments", "footprint": [28.0, 20.0],
                 "levels": LEVELS, "floor_to_floor": F2F,
                 "wall_height": WALL_H, "slab_t": SLAB_T,
                 "player": {"height": 1.75, "eye": 1.62, "radius": 0.38,
                            "crouch": 1.05, "step_max": 0.28},
                 "residents": RESIDENTS},
        "floors": floors,
        "stairs": [stair_geometry(ATRIUM)],
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
