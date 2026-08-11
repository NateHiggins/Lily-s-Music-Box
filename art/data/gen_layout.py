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

from shop_interiors import (SHOPS, SHOPS_N, SHOP_CLEAR, SHOP_H,
                            SHOP_PLAN, SHOP_FLOOR, SHOP_CEIL,
                            build_shop_interiors)

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
        # ROOF is a real stop. The bulkhead, its door and the shaft
        # opening in the roof slab were all already modelled - the car
        # simply never came, so the top landing was a hole in the roof
        # with a concrete hut around it and no way to arrive.
        "stops": ["B1", "F01", "F02", "F03", "F04", "F05", "F06",
                  "ROOF"]}


def wall(a, b, t, h, z, openings=None, cat="walls", mat="plaster",
         wainscot=False, details=True):
    return {"a": list(a), "b": list(b), "t": t, "h": h, "z": z,
            "openings": openings or [], "cat": cat, "mat": mat,
            "wainscot": wainscot, "details": details}


def seat_walls_under_the_floor_above(floors):
    """A wall may not rise through the floor above it.

    Wall heights come from WALL_H and F2F, both derived from the standard
    3.20 m residential floor-to-floor. The basement does not have one: it
    runs -2.80 to 0.0, a floor-to-floor of 2.80. Its walls were still
    built 3.02 m and 3.20 m tall, so they finished 220 mm and 400 mm
    ABOVE the ground floor.

    Where F01 has a wall of its own that overshoot is buried inside it and
    nobody sees a thing. Where F01 has a door or an archway it is not
    buried, and the basement wall surfaces as a kerb straight across the
    opening - which is the hump at the bottom of every threshold and open
    section on the ground floor, and why it appeared at archways that have
    no door prop to blame.

    Partitions stop at the underside of the slab above. Full-height
    masonry runs up to the top of it, so the facade stays continuous.
    """
    order = ["B1", "F01", "F02", "F03", "F04", "F05", "F06", "ROOF"]
    seated = 0
    for fl in floors:
        fid = fl["id"]
        if fid not in order or order.index(fid) + 1 >= len(order):
            continue
        above = LEVELS[order[order.index(fid) + 1]]
        for w in fl["walls"]:
            limit = above if w["h"] >= F2F - 1e-6 else above - SLAB_T
            if w["z"] + w["h"] > limit + 1e-6:
                w["h"] = limit - w["z"]
                seated += 1
    return seated


def normalize_wall_construction(floors):
    """Enforce construction truth before any finish or export pass.

    Only the thick perimeter envelope is masonry. Every thinner architectural
    partition inside that envelope is plaster/drywall, including the atrium,
    corridor ring and apartment demising walls. Exterior masonry records its
    room-facing side so the exporter may add a damaged finish there without
    ever turning an interior partition into brick.
    """
    converted = 0
    exterior = 0
    masonry = {"brick", "brick_patched", "common_brick", "face_brick"}
    for fl in floors:
        finish_index = 0
        for w in fl["walls"]:
            if w.get("cat", "walls") != "walls":
                continue
            # Upper exterior bearing walls are 0.30 m; every interior wall is
            # 0.18 m or thinner. Thickness is a safer invariant than location
            # because the envelope is split around four apartment stacks.
            is_envelope = float(w.get("t", 0.0)) >= 0.29
            if not is_envelope and w.get("mat") in masonry:
                w["mat"] = "plaster"
                w.pop("in_side", None)
                w.pop("finish_texture", None)
                converted += 1
            elif is_envelope and w.get("mat") in masonry:
                ax, ay = w["a"]
                bx, by = w["b"]
                if abs(by - ay) < 1e-6:  # south faces inward +Y; north -Y
                    w["in_side"] = 1 if (ay + by) * 0.5 < 0 else -1
                else:                    # west faces inward +X; east -X
                    w["in_side"] = 1 if (ax + bx) * 0.5 < 0 else -1
                # Second look, ruled 2026-08-04: finishes composited
                # from the AI-generated source library (wall_sources/)
                # by build_wall_finish_textures.py, one unique id per
                # room-facing masonry wall.
                w["finish_texture"] = "%s_w%02d" % (
                    str(fl["id"]).lower(), finish_index)
                finish_index += 1
                exterior += 1
    print("wall construction audit: %d interior masonry walls -> plaster; "
          "%d exterior masonry walls retained" % (converted, exterior))


def resolve_wainscot_sides(floors):
    """Give every dado one face, and the right one.

    A wainscot is a finish, and a finish belongs to the room that
    installed it - not to the flat on the other side of the same
    partition. Two jobs, one geometric probe (the same technique the
    door/unit resolution uses):

    - bathroom walls earn a glazed subway-tile dado on the wet face;
    - existing corridor dados, which used to draw on both faces and so
      hung corridor beadboard inside every apartment, get pinned to the
      circulation face.
    """
    tiled = pinned = marbled = 0
    for fl in floors:
        baths = [r["rect"] for r in fl["rooms"]
                 if r.get("kind") == "bathroom"]
        commons = [r["rect"] for r in fl["rooms"]
                   if r.get("kind") in ("corridor", "hall", "lobby",
                                        "atrium", "common")]
        # The lobby is the one room a visitor is asked to form an opinion
        # in, and a house of this class spent its money where that
        # happened: marble to the dado downstairs, painted beadboard
        # everywhere else. Splitting the lobby out of `commons` is what
        # makes that distinction, so it is read separately.
        lobbies = [r["rect"] for r in fl["rooms"]
                   if r.get("kind") == "lobby"]

        def side_facing(w, rects, reach=0.14):
            """+1 / -1 for the face standing in one of these rooms.

            `reach` is how far off the wall centreline to probe. 0.14 m
            finds a room whose rect runs up to the wall, but a rect is
            the CLEAR floor area and does not always do that: the lobby
            stops 18 cm short of its own north wall, so the default probe
            landed inside the wall and reported no lobby at all.
            """
            (ax, ay), (bx, by) = w["a"], w["b"]
            mx, my = (ax + bx) * 0.5, (ay + by) * 0.5
            horizontal = abs(by - ay) < 1e-6
            for off in (reach, -reach):
                px = mx if horizontal else mx + off
                py = my + off if horizontal else my
                for r in rects:
                    if r[0] < px < r[2] and r[1] < py < r[3]:
                        return 1 if off > 0 else -1
            return 0

        for w in fl["walls"]:
            if w.get("cat", "walls") != "walls":
                continue
            if w.get("wainscot"):
                # Lobby first: where a wall serves both the lobby and the
                # hall behind it, the dado belongs to the lobby face. It
                # was being pinned to whichever common room the probe hit
                # first, which is the hall, so the one room that was
                # supposed to be dressed in marble faced raw plaster.
                lside = side_facing(w, lobbies, 0.34) if lobbies else 0
                if lside:
                    w["wains_side"] = lside
                    w["wains_mat"] = "marble_lobby"
                    marbled += 1
                    pinned += 1
                    continue
                side = side_facing(w, commons)
                if side:
                    w["wains_side"] = side
                    pinned += 1
                continue
            if not baths:
                continue
            side = side_facing(w, baths)
            if side:
                w["wainscot"] = True
                w["wains_mat"] = "subway_tile"
                w["wains_side"] = side
                tiled += 1
    print("wainscot audit: %d bathroom walls tiled, %d corridor dados "
          "pinned to the circulation face, %d lobby dados in marble"
          % (tiled, pinned, marbled))


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
    radiator_y = (y0 + y1) / 2.0
    markers.append({"kind": "radiator",
                    "id": "%s_%s_RADIATOR_01" % (floor_id, stack),
                    "pos": [rx, radiator_y, z],
                    "yaw_deg": 90 if not east else -90,
                    "network": "heating", "riser": "H-%s" % stack,
                    # Seven-to-nine section bodies vary by household but
                    # never exceed the old 810 mm clearance envelope.
                    "sections": 7 + sum(ord(ch) for ch in unit) % 3,
                    "unit": unit})
    dress_unit(unit, stack, floor_id, z, furniture, markers, walls)


def _furn_box(furniture, fid, x, y, w, d, z0, h, mat, _east):
    furniture.append({"id": fid, "rect": [x, y, x + w, y + d], "z0": z0,
                      "h": h, "mat": mat})




def bath_fixtures(furniture, unit, rect, edge, markers=None, z=0.0):
    """Shower, close-coupled toilet and pedestal sink with mirror, lined
    along one wall of the bath, plus a milk-glass sconce over the mirror
    when a markers list is supplied. edge: "e" | "w" | "n"."""
    x0, y0, x1, y1 = rect
    f = furniture
    # The standard run wants 1.92 m from the corner to the sink. The
    # ground-floor public restroom is 1.90 m deep, so the sink landed two
    # centimetres inside its own far wall - invisible while the fixture
    # was inert furniture, and caught the moment it became a prop the
    # placement validator looks at. Clamp the run to the room instead of
    # assuming every bath is full size.
    def _run(v, lo, hi):
        return min(max(v, lo + 0.32), hi - 0.32)
    # Every fixture mounts with its back (local -Y) to the run wall. The
    # shower also meets a second wall: `mirror` tells it which of its own
    # X sides that corner is on, so tile and glass never swap places.
    if edge == "e":
        sink_run = _run(y0 + 1.92, y0, y1)
        _bath_marker(markers, unit, "shower", x1 - 0.46, y0 + 0.50, 90, z)
        _asm(f, unit + "_wc", "toilet", x1 - 0.41, y0 + 1.22, 90)
        _bath_marker(markers, unit, "sink", x1 - 0.30, sink_run, 90, z)
        # The cabinet is close to the far return wall. Hinge on the roomward
        # side so its leaf opens into free air instead of through that return.
        _bath_marker(markers, unit, "mirror", x1 - 0.30,
                     sink_run, 90, z, "right")
        spos, syaw = [x1 - 0.08, sink_run - 0.50], -90
    elif edge == "w":
        sink_run = _run(y0 + 1.92, y0, y1)
        _bath_marker(markers, unit, "shower", x0 + 0.46, y0 + 0.50, -90, z)
        _asm(f, unit + "_wc", "toilet", x0 + 0.41, y0 + 1.22, -90)
        _bath_marker(markers, unit, "sink", x0 + 0.30, sink_run, -90, z)
        _bath_marker(markers, unit, "mirror", x0 + 0.30,
                     sink_run, -90, z, "left")
        spos, syaw = [x0 + 0.08, sink_run - 0.50], 90
    else:  # "n"
        sink_run = _run(x0 + 1.92, x0, x1)
        _bath_marker(markers, unit, "shower", x0 + 0.50, y1 - 0.46, 180, z)
        _asm(f, unit + "_wc", "toilet", x0 + 1.22, y1 - 0.41, 180)
        _bath_marker(markers, unit, "sink", sink_run, y1 - 0.30, 180, z)
        _bath_marker(markers, unit, "mirror",
                     sink_run, y1 - 0.30, 180, z, "left")
        spos, syaw = [sink_run - 0.50, y1 - 0.08], 0
    # Towels live on the wall opposite the wet fixtures. The former rail
    # shared the shower/toilet wall and visibly passed through both.
    # The C bathroom carries a second door on the same wall the rail
    # hung from, so on five floors the rail crossed its trim. Sliding
    # along that wall cannot help - the fix is the opposite wall. Other
    # stacks keep their position, where the validator confirms the rail
    # is clear of every swing.
    tr = {"e": (x0 + 0.10, y0 + 1.60), "w": (x1 - 0.10, y0 + 1.60),
          "n": (x0 + 1.60, y0 + 0.10)}[edge]
    if str(unit).endswith("C") and edge in ("e", "w"):
        tr = ((x1 - 0.10) if edge == "e" else (x0 + 0.10), y0 + 1.60)
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
                        # A lamp above the raised cabinet was crowded against
                        # the ceiling. One roomward side light is the cheaper
                        # 1928 composition. Its centre is half a metre along
                        # the wall from the basin: 390 mm left the opal globe
                        # pinching the cabinet edge once bloom was visible.
                        "unit": unit, "pos": [spos[0], spos[1], z + 1.62],
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
    yaw = (FACE_YAW[face] + 180) % 360
    if along_x:
        _asm(f, uid, "tv", x + 0.625, y + 0.21, yaw)
    else:
        _asm(f, uid, "tv", x + 0.21, y + 0.625, yaw)


def plant_box(f, uid, x, y, big=False, species=None):
    """A pot with somebody's plant in it. Species comes from the unit
    prefix unless the caller names one - the lobby and the halls are not
    anybody's flat, so they say what they want."""
    s = 0.36 if big else 0.28
    kind = species or UNIT_PLANT.get(str(uid)[:2], "sansevieria")
    _asm(f, uid, "plant", x + s / 2, y + s / 2,
         (sum(ord(c) for c in uid) * 53) % 360, big=big, species=kind)


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


# Which cold-box a flat has, and what stands where its range should.
# Four tenants never replaced the 1927 monitor-top, and that is a fact
# about them, not about the landlord: Evelyn keeps hers immaculate,
# Malcolm's holds jars, Cal has not bought anything since the reels
# arrived, and Mae owns nothing made after 1935. See
# design/ORISON_APPLIANCE_BIBLE.md for the argument per flat.
MONITOR_TOP_UNITS = {"1A", "3A", "5B", "6C"}
## Flats whose range is not a range. Juno records instead of cooking and
## the deck lives on the hob; Cal's stove carries three console radios.
## The complete range prop still ships - it is what they put things ON.
RANGE_AS_SHELF = {"2C", "5B"}
## WHO DOES NOT HAVE A TOASTER (ruled 2026-08-08 at the owner's
## direction: "I want toasters in the majority of apartments"). Fourteen
## of the eighteen do — the appliance bible had named only three, and
## that reads as a building where nobody eats breakfast.
##
## The four without each have a reason, because a majority is only
## characterful if the minority is a choice:
##   2C  Juno records instead of cooking; the hob carries tape boxes
##   5B  Cal's range carries three console radios
##   4D  a short-term let, furnished to the landlord's minimum
##   5C  the spare room is becoming a painting studio and she eats out
NO_TOASTER_UNITS = {"2C", "5B", "4D", "5C"}
# One third of the flats own kettles, each for a character reason rather
# than because the kitchen generator had an empty socket to fill.
KETTLE_UNITS = {"1A", "1D", "3D", "4B", "4C", "6C"}
# Three residents were always named in the appliance bible; 4B is the
# standing player-flat ruling in the same form as its range, toaster and
# kettle.  Count the whole built layout because 4B is bespoke while the
# other three are authored by dress_unit().
BOXFAN_UNITS = {"2C", "4B", "5C", "6A"}
# One retained domestic hazard, authored rather than rolled per boot. Lena's
# big borrowed-family pots make a low unattended ring in 2B findable; 35% of
# seventeen ranges made the whole building behave like an active gas leak.
AMBIENT_LIT_STOVE_UNIT = "2B"


def unit_of_uid(uid):
    """`4B_k` / `2C_k_stove` -> `4B`. Placement needs the flat, and the
    ids already carry it."""
    return str(uid).split("_")[0]


def _hob_load(f, uid, sx, sy):
    """What stands on a range nobody cooks on.

    An unused appliance does not read as unused; it reads as clean. So
    the tenants who do not cook put things on the hob, and the hob says
    what the kitchen_set field says: Juno's tape boxes, Cal's radios.
    """
    unit = unit_of_uid(uid)
    if unit not in RANGE_AS_SHELF:
        return
    if unit == "2C":
        for i, (dx, dy) in enumerate(((-0.10, -0.06), (0.09, 0.02),
                                      (-0.02, 0.10))):
            f.append({"id": "%s_hob_tape%d" % (uid, i),
                      "rect": [sx + dx - 0.11, sy + dy - 0.08,
                               sx + dx + 0.11, sy + dy + 0.08],
                      "z0": 0.90 + i * 0.055, "h": 0.055,
                      "mat": "bakelite"})
    else:
        for i, (dx, dy) in enumerate(((-0.12, 0.0), (0.11, -0.04))):
            _asm(f, "%s_hob_radio%d" % (uid, i), "radio",
                 sx + dx, sy + dy, 180, z0=0.90)


def _fridge_marker(markers, uid, fx, fy, z, yaw, floor_id):
    """One marker owns the complete cold box, including its cabinet.

    Splitting the shell into Blender and the moving parts into Godot made
    the warehouse display a floating door and left 4B with no shell at all.
    More importantly, an oak icebox is furniture, not an electrical node.
    The four monitor-tops opt into electricity here; the other fourteen
    travel through the structural fabric when reality needs a route."""
    if markers is None:
        return
    unit = unit_of_uid(uid)
    markers.append({
        "kind": "fridge",
        "id": "%s_%s_FRIDGE_01" % (floor_id or "FXX", unit),
        "unit": unit, "pos": [round(fx, 4), round(fy, 4), round(z, 4)],
        "yaw_deg": yaw,
        "network": "electrical" if unit in MONITOR_TOP_UNITS else "structural",
        "monitor": unit in MONITOR_TOP_UNITS})


def _toaster_marker(markers, uid, tx, ty, z, yaw, floor_id):
    """A toaster on the counter, for the flats that eat breakfast at home.

    It sits at -0.38 of the run from centre: the far end from the range,
    west of the sink at -0.20 and clear of the mug at +0.30 and the
    drainer at +0.40. Those four offsets are the whole worktop, and a
    fifth thing on it would be standing on one of them.
    """
    if markers is None:
        return
    unit = unit_of_uid(uid)
    if unit in NO_TOASTER_UNITS:
        return
    markers.append({
        "kind": "toaster",
        "id": "%s_%s_TOASTER_01" % (floor_id or "FXX", unit),
        "unit": unit,
        "pos": [round(tx, 4), round(ty, 4), round(z + 0.90, 4)],
        "yaw_deg": yaw, "network": "electrical"})


def _kettle_marker(markers, uid, kx, ky, z, yaw, floor_id):
    """Put a kettle in the rear mug socket, never on top of a fifth item."""
    if markers is None:
        return
    unit = unit_of_uid(uid)
    if unit not in KETTLE_UNITS or unit == "4B":
        return  # the player's bespoke galley owns its exact marker below
    markers.append({
        "kind": "kettle",
        "id": "%s_%s_KETTLE_01" % (floor_id or "FXX", unit),
        "unit": unit,
        "pos": [round(kx, 4), round(ky, 4), round(z + 0.905, 4)],
        "yaw_deg": yaw, "network": "electrical",
        "case_id": "4519" if unit == "4C" else ""})


def _bath_marker(markers, unit, kind, bx, by, yaw, z, hinge_side="left"):
    """One marker owns one complete period bathroom fixture.

    The former assembly/prop split was the plumbing version of the old
    refrigerator fault: Blender owned a generic shell and Godot owned two
    floating handles. `fixture` is deliberately more specific than `kind`;
    the latter stays sink/shower so the graph and prop catalog keep their
    stable public vocabulary."""
    if markers is None:
        return
    # bath_fixtures is handed a level, not a floor name, so name the
    # marker from whichever level this z belongs to.
    floor_id = "FXX"
    for name, level in LEVELS.items():
        if abs(level - z) < 0.01:
            floor_id = name
            break
    marker = {
        "kind": kind,
        "id": "%s_%s_%s_01" % (floor_id, unit, kind.upper()),
        "unit": unit, "pos": [round(bx, 4), round(by, 4), round(z, 4)],
        # A mirror door is screwed to the wall, not coupled to the water
        # main. Nothing reads this field for mirrors today; structural is
        # honest metadata rather than a promise of acoustic propagation.
        "yaw_deg": yaw,
        "network": "structural" if kind == "mirror" else "water"}
    if kind in ("sink", "shower"):
        marker["fixture"] = "shower" if kind == "shower" else "bath_sink"
    elif kind == "mirror":
        marker["hinge_side"] = hinge_side
    markers.append(marker)


def _kitchen_sink_marker(markers, uid, sx, sy, z, yaw, floor_id,
                         compact=False, drainboard=True):
    """The basin cutout and the fixture marker are one coordinate contract.

    `kitchen` still owns cabinetry and its dirty-counter/trash sockets. The
    sink owns only the iron bowl, drainboard and plumbing, so replacing a
    cupboard run cannot duplicate or strand the interactive water object."""
    if markers is None:
        return
    unit = unit_of_uid(uid)
    markers.append({
        "kind": "sink", "fixture": "kitchen_sink",
        "id": "%s_%s_KITCHEN_SINK_01" % (floor_id or "FXX", unit),
        "unit": unit, "pos": [round(sx, 4), round(sy, 4), round(z, 4)],
        "yaw_deg": yaw, "network": "water", "drain_side": 1,
        "compact": bool(compact), "drainboard": bool(drainboard)})


def _stove_marker(markers, uid, sx, sy, z, yaw, floor_id):
    """One marker owns the complete range, including shell and service parts.

    A stove carries no signal: under VIII.2 it remains a 1920s gas appliance
    on a pipe, not a wire. `network: gas` already expressed that correctly
    before the visual rebuild and stays deliberately unchanged."""
    if markers is None:
        return
    unit = unit_of_uid(uid)
    markers.append({
        "kind": "stove",
        "id": "%s_%s_STOVE_01" % (floor_id or "FXX", unit),
        "unit": unit, "pos": [round(sx, 4), round(sy, 4), round(z, 4)],
        "yaw_deg": yaw, "network": "gas",
        "ambient_lit": unit == AMBIENT_LIT_STOVE_UNIT,
    })


def _lino_field(f, uid, x, y, cw, along_x, side):
    """The square of linoleum the kitchen actually stands on.

    Most of these runs are a kitchenette in the corner of a living room,
    not a separate room, so flooring the whole space in lino was wrong
    twice over: it lino'd bedrooms-adjacent living space, and it threw
    away the thing that makes a period kitchenette read - a defined
    working field laid over the boards.

    So: a square, sized off the run itself (counter + range + icebox is
    cw + 1.38 long) and never less than 1.9 m so there is somewhere to
    stand, pushed up against the wall the run is on.

    The edge is bound in brass. A sheet of linoleum has to be held down
    where it stops, and the binding bar is the detail that says this was
    laid rather than painted on. It runs on the three exposed edges
    only - the wall side gets a skirting board, not a threshold strip,
    and putting one there is the sort of mistake that reads instantly.
    """
    run = cw + 1.38
    sq = max(run, 1.90)
    bar = 0.05          # brass binding bar, 50 mm
    if along_x:
        fx0 = x + run / 2.0 - sq / 2.0
        fy1 = y + 0.66 if side == "n" else y + sq
        fy0 = fy1 - sq
        open_edges = (("s" if side == "n" else "n"), "e", "w")
    else:
        fy0 = y + run / 2.0 - sq / 2.0
        fx1 = x + 0.66 if side == "e" else x + sq
        fx0 = fx1 - sq
        open_edges = (("w" if side == "e" else "e"), "n", "s")
    _furn_box(f, "%s_lino" % uid, fx0, fy0, sq, sq, 0.013, 0.004,
              "linoleum", False)
    for e in open_edges:
        if e == "n":
            _furn_box(f, "%s_linobar_n" % uid, fx0, fy0 + sq - bar,
                      sq, bar, 0.013, 0.008, "brass_dull", False)
        elif e == "s":
            _furn_box(f, "%s_linobar_s" % uid, fx0, fy0,
                      sq, bar, 0.013, 0.008, "brass_dull", False)
        elif e == "e":
            _furn_box(f, "%s_linobar_e" % uid, fx0 + sq - bar, fy0,
                      bar, sq, 0.013, 0.008, "brass_dull", False)
        else:
            _furn_box(f, "%s_linobar_w" % uid, fx0, fy0,
                      bar, sq, 0.013, 0.008, "brass_dull", False)


def kitchen_run(f, uid, x, y, L, along_x=True, side="n", markers=None,
                z=0.0, floor_id=""):
    """Cabinetry run + range + fridge along the wall on `side` of the
    0.66-deep footprint whose min corner is (x, y)."""
    cw = max(0.95, L - 1.40)

    def clutter(cx_, cy_, swap=False):
        # The basin owns the left third and the raised board stands to its
        # right. Three anonymous furniture boxes used to stand for mugs,
        # plates and a board; in the render they were simply three blocks
        # laid over the sink. Use the real assembly silhouettes instead.
        items = []
        if unit_of_uid(uid) not in KETTLE_UNITS:
            items.append(((cw * 0.30, 0.13), "mug", "mug", {}))
        items.append(((cw * 0.40, -0.12), "dishrack", "dishrack",
                      {"W": 0.12, "D": 0.26, "n": 4}))
        for (ox, oy), asm, tag, extra in items:
            if swap:
                ox, oy = oy, ox
            _asm(f, "%s_k%s" % (uid, tag), asm, cx_ + ox, cy_ + oy,
                 90 if swap else 0, z0=0.905, **extra)
    if along_x:
        yaw = FACE_YAW["s" if side == "n" else "n"]
        cy = y + 0.32
        _asm(f, uid, "kitchen", x + cw / 2, cy, yaw, L=cw + 0.75)
        # asm_kitchen's local cutout is x = -0.20*cw. Rotate that exact
        # anchor into the layout so bowl and hole cannot drift separately.
        sx = x + cw / 2 + (-0.20 * cw) * math.cos(math.radians(yaw))
        sy = cy + (-0.20 * cw) * math.sin(math.radians(yaw))
        _kitchen_sink_marker(markers, uid, sx, sy, z, yaw, floor_id)
        _toaster_marker(markers, uid,
                        x + cw / 2 + (-0.38 * cw) * math.cos(math.radians(yaw)),
                        cy + (-0.38 * cw) * math.sin(math.radians(yaw)),
                        z, yaw, floor_id)
        _kettle_marker(markers, uid,
                       x + cw / 2 + 0.30 * cw, cy + 0.13,
                       z, yaw, floor_id)
        _stove_marker(markers, uid, x + cw + 0.33, cy, z, yaw, floor_id)
        _fridge_marker(markers, uid, x + cw + 0.66 + 0.36, cy, z, yaw,
                       floor_id)
        clutter(x + cw / 2, cy)
        _hob_load(f, uid, x + cw + 0.33, cy)
        _lino_field(f, uid, x, y, cw, True, side)
    else:
        yaw = FACE_YAW["e" if side == "w" else "w"]
        cx = x + 0.32
        _asm(f, uid, "kitchen", cx, y + cw / 2, yaw, L=cw + 0.75)
        sx = cx + (-0.20 * cw) * math.cos(math.radians(yaw))
        sy = y + cw / 2 + (-0.20 * cw) * math.sin(math.radians(yaw))
        _kitchen_sink_marker(markers, uid, sx, sy, z, yaw, floor_id)
        _toaster_marker(markers, uid,
                        cx + (-0.38 * cw) * math.cos(math.radians(yaw)),
                        y + cw / 2 + (-0.38 * cw) * math.sin(math.radians(yaw)),
                        z, yaw, floor_id)
        _kettle_marker(markers, uid,
                       cx + 0.13, y + cw / 2 + 0.30 * cw,
                       z, yaw, floor_id)
        _stove_marker(markers, uid, cx, y + cw + 0.33, z, yaw, floor_id)
        _fridge_marker(markers, uid, cx, y + cw + 0.66 + 0.36, z, yaw,
                       floor_id)
        clutter(cx, y + cw / 2, True)
        _hob_load(f, uid, cx, y + cw + 0.33)
        _lino_field(f, uid, x, y, cw, False, side)


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


def lived_in_surface_detail(f, unit, rooms, skip, ux, lcy):
    """Small, placement-safe evidence of daily life on existing surfaces.

    These props deliberately sit above dining, coffee and desk assemblies,
    so they increase close-view density without narrowing circulation.
    Their mix and rotation are deterministic per household.
    """
    seed = sum((i + 1) * ord(c) for i, c in enumerate(unit))
    dx, dy, _ = rooms["dining_spot"]
    _asm(f, unit + "_detail_dining_mug", "mug",
         dx + (-0.16 if seed % 2 else 0.16), dy + 0.08,
         (seed * 29) % 360, z0=0.75,
         mat=("porcelain", "ceramic")[seed % 2])
    _asm(f, unit + "_detail_dining_papers", "papers",
         dx - 0.12, dy - 0.10, (seed * 17) % 18 - 9, z0=0.75,
         n=3 + seed % 4, mess=0.15 + (seed % 5) * 0.12)

    if "sofa" not in skip:
        # coffee_table() receives the min corner of its footprint.
        cx, cy = ux(1.55, 0.95) + 0.475, lcy - 0.55 + 0.275
        _asm(f, unit + "_detail_coffee_books", "bookpile",
             cx - 0.18, cy + 0.02, (seed * 11) % 24 - 12,
             z0=0.37, n=2 + seed % 3)
        _asm(f, unit + "_detail_coffee_mug", "mug",
             cx + 0.20, cy - 0.06, (seed * 41) % 360, z0=0.37,
             mat=("porcelain", "ceramic")[(seed // 2) % 2])

    if "office" in rooms:
        ox0, oy0, ox1, oy1 = rooms["office"]
        # The standard office desk is vertical, centered at this point.
        dcx, dcy = ox1 - 0.365, oy0 + 1.0
        _asm(f, unit + "_detail_desk_papers", "papers",
             dcx, dcy - 0.16, -90 + ((seed % 7) - 3), z0=0.74,
             n=5 + seed % 4, mess=0.25 + (seed % 4) * 0.18)
        _asm(f, unit + "_detail_desk_mug", "mug",
             dcx - 0.16, dcy + 0.17, (seed * 31) % 360, z0=0.74,
             mat=("porcelain", "ceramic")[(seed // 3) % 2])


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
    # A blind is fixed to the window, not to the room's idea of gravity.
    # Nine stacks could descend through the 1.00 m court sill and through
    # the counter/range beneath it. Cap the shared generator at the sill;
    # trimming 4B alone would leave the same physical fault in eight flats.
    n = min(n, int((WIN_TOP - 0.06 - WIN_COURT["sill"]) / pitch))
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


def unit_windows(walls, x0, y0, x1, y1, z):
    """Every window opening whose glass stands on this unit's envelope.

    Walls carry their openings; the dressing pass used to ignore them and
    guess. Returns (cx, cy, width, along_x) in plan coordinates.
    """
    found = []
    if not walls:
        return found
    for w in walls:
        if w.get("cat", "walls") != "walls" or abs(float(w["z"]) - z) > 0.01:
            continue
        (ax, ay), (bx, by) = w["a"], w["b"]
        horizontal = abs(by - ay) < 1e-6
        start = min(ax, bx) if horizontal else min(ay, by)
        cross = ay if horizontal else ax
        for o in w.get("openings", []):
            if o.get("type", "") != "window":
                continue
            along = start + float(o["at"])
            cx = along if horizontal else cross
            cy = cross if horizontal else along
            # a window belongs to the unit whose envelope it pierces; the
            # margin catches walls sitting exactly on the boundary line
            if not (x0 - 0.35 <= cx <= x1 + 0.35
                    and y0 - 0.35 <= cy <= y1 + 0.35):
                continue
            found.append((cx, cy, float(o["w"]), horizontal))
    return found


def unit_name(floor_id, stack):
    """`F02` + `A` -> `2A`, the same rule apartment() uses inline."""
    return "%s%s" % (floor_id[-1].lstrip("0") or floor_id[-1], stack)


def west_storage(floor_id, z, f):
    """Dress the former west suite that became storage.

    It used to be one 2.2 x 1.4 x 1.1 box labelled "crates" - a
    placeholder standing in for a whole room. What belongs here is what
    a landlord does with a flat nobody rents: the tenants' overflow
    stacked against the party wall, a shelf run for the small things,
    and the furniture that came with the suite still under dust sheets.
    Deterministic per storey, so F02 and F06 are not the same room.
    """
    h = sum(ord(c) * 17 for c in floor_id)
    x0, y0, x1, y1 = WSTOR_RECT

    # Crate stacks against the west party wall, two or three high.
    cx = x0 + 0.55
    for i in range(4):
        cy = y0 + 0.45 + i * 0.62
        if cy > y1 - 0.4:
            break
        levels = 2 + ((h >> i) & 1)
        for lv in range(levels):
            w = 0.44 - lv * 0.03
            d = 0.38 - lv * 0.02
            jitter = ((h >> (i + lv)) % 7 - 3) * 0.012
            _asm(f, "%s_wstor_cr%d_%d" % (floor_id, i, lv), "crate",
                 cx + jitter, cy, (h + i * 37 + lv * 11) % 24 - 12,
                 z0=lv * 0.34, W=w, D=d, H=0.33)

    # A shelf run on the north wall for the small overflow.
    _asm(f, "%s_wstor_shelf" % floor_id, "shelf",
         x0 + 2.35, y1 - 0.30, 180, W=1.7, books=False)

    # Suite furniture still under sheets: linen-draped masses, which is
    # what a covered armchair and a covered table read as at distance.
    _furn_box(f, "%s_wstor_sheet_a" % floor_id, x0 + 3.55, y0 + 0.55,
              0.95, 0.92, 0.0, 0.86, "linen", False)
    _furn_box(f, "%s_wstor_sheet_b" % floor_id, x0 + 4.95, y0 + 1.35,
              1.35, 0.80, 0.0, 0.74, "linen", False)
    # a rolled rug on its end in the corner
    _furn_box(f, "%s_wstor_roll" % floor_id, x1 - 0.55, y1 - 0.62,
              0.28, 0.28, 0.0, 1.55, "rug_warm", False)
    # the landlord's own stack of spare radiator sections, never fitted
    _furn_box(f, "%s_wstor_sections" % floor_id, x1 - 1.45, y0 + 0.35,
              0.72, 0.34, 0.0, 0.62, "cast_iron", False)


def blinds_for_unit(f, unit, stack, walls=None, z=0.0):
    """Hang a blind INSIDE each real window.

    Blinds used to be placed at fixed fractions of the apartment
    rectangle - 30% and 70% along its length - which is only ever
    accidentally where a window is. Every unit therefore had venetian
    blinds floating on blank plaster while its actual windows stood
    bare. Now the openings decide, and the blind is inset a hand's
    width into the room the way a mounted head rail is.
    """
    x0, y0, x1, y1 = STACK_RECTS[stack]
    windows = unit_windows(walls, x0, y0, x1, y1, z)
    if not windows:
        return 0
    for wi, (cx, cy, ww, horizontal) in enumerate(windows):
        # inward is toward the apartment's middle
        mx, my = (x0 + x1) * 0.5, (y0 + y1) * 0.5
        # blind_stack takes a MIN corner and the blind is 1.34 wide, so
        # the centring offset is half the blind, not half the window
        if horizontal:
            bx = cx - 0.67
            by = cy + (0.10 if my > cy else -0.10)
        else:
            bx = cx + (0.10 if mx > cx else -0.10)
            by = cy - 0.67
        blind_stack(f, "%s_bl%d" % (unit, wi), bx, by, horizontal,
                    unit + str(wi))
    return len(windows)


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


## WHO OWNS A SOFA, A TELEVISION, A DESK OR A BOOKSHELF.
##
## These four used to be standard issue - every apartment got all of them, so
## twenty-two households owned identical furniture and the rooms could only be
## told apart by what was scattered on top. That is backwards. In a 1928
## working-class block the big pieces ARE the biography: a sofa means you have
## somewhere to seat a visitor, a set means you spent a year's savings on one,
## a desk means your work follows you home.
##
## So they are opt-in now, and the reason is written next to each. An apartment
## not on a list simply does not have that thing, which is the ordinary case and
## reads as poverty rather than as an oversight. Bed, wardrobe, table, chairs,
## kitchen and bathroom stay universal - those are not choices.
SOFA_UNITS = {
    "1A": "Evelyn receives former pupils",
    "2A": "Mina's front room is where the work is shown",
    "4C": "the Bell family, four of them",
    "6C": "Mae's, inherited with everything else",
}
## PROJECTORS, and there are only four (ruled 2026-08-11). Not televisions - see
## design/ORISON_PROJECTOR_BRIEF.md - and not one per household.
##
## Nine was a television number. A set is furniture; a 16 mm projector in a
## 1928 tenement is a middle-class machine in a working-class flat, and every
## one of them has to be explicable. Four are, and all four belong to CASE
## residents, which is the rule: **the machine is only in the flat of someone
## the building is currently about.** That makes it an instrument rather than
## an appliance, and it means finding one running is always a sentence.
##
## They are fixed. They do not move between rooms, no two share a room, and the
## throw is authored by where the machine points - so the wall each one uses is
## a layout decision, not a runtime negotiation.
TV_UNITS = {
    "2A": "Mina captions what a picture says for a living",
    "3B": "Omar's, and he cannot repair it - which is the wound, exactly",
    "5B": "Cal, who would not let a thing end",
    "6C": "Mae's, inherited with everything else and never moved",
}
DESK_UNITS = {
    "2A": "Mina's caption station",
    "4A": "Peter is a legal clerk and over-prepares",
    "5A": "Nadia drafts at home",
    "6B": "Jonah writes at night",
}
SHELF_UNITS = {
    "1A": "a teacher's books",
    "6B": "a writer's",
    "6C": "Mae's archive, which is the whole wound",
    "3A": "Malcolm's propagation trays",
}


## Standard pieces each hero's signature cluster replaces (so the two
## dressing layers never fight over the same floor).
HERO_SKIP = {
    "2A": {"shelf"},
    "2C": {"rug"},
    "3D": {"tv"},
    "5A": {"shelf"},
    "6A": {"sofa", "rug", "tv", "plant"},
}

# Supporting residents. Hero units below already have bespoke full-room
# installations; these identities give every other occupied apartment a
# readable life through a compact signature cluster.
RESIDENT_STORIES = {
    "1A": ("Evelyn Marsh", "retired_teacher"),
    "1D": ("Teresa Vale", "night_nurse"),
    "2B": ("Lena Ortiz", "seamstress"),
    "3A": ("Malcolm Reed", "horticulturist"),
    "4A": ("Peter Wren", "legal_clerk"),
    "4C": ("The Bell Family", "young_family"),
    "4D": ("Transient Guests", "short_term_rental"),
    "5B": ("Cal Dwyer", "radio_collector"),
    "5C": ("Iris Bell", "painter"),
    "6B": ("Jonah Price", "insomniac_writer"),
    "6C": ("Mae Kessler", "estate_collector"),
}


def resident_story_detail(f, unit, story, rooms, ux, lcy, wface):
    """A small, collision-safe narrative cluster on the dining surface and
    exterior wall. Large furniture remains standardized; these are the
    objects that explain who lives among it."""
    dx, dy, _sides = rooms["dining_spot"]
    tabletop = 0.77
    east = unit[-1] in ("C", "D")
    # Boards mount flush on the storey's true wall face (wall-hung
    # flatware is exempt from the embedded-center audit, like the
    # mail bank before it), centered on the pier BETWEEN the two side
    # windows — the only stretch of that wall that is actually wall.
    wall_x = wface + (-0.005 if east else 0.005)
    wall_yaw = 90 if east else -90
    sy0, sy1 = STACK_RECTS[unit[-1]][1], STACK_RECTS[unit[-1]][3]
    pier_y = (sy0 + sy1) / 2.0

    def prop(suffix, asm, ox, oy, yaw=0, z0=tabletop, **params):
        _asm(f, "%s_story_%s" % (unit, suffix), asm,
             dx + ox, dy + oy, yaw, z0=z0, **params)

    if story == "retired_teacher":
        prop("marked_books", "bookpile", -0.20, 0.02, n=7)
        prop("lesson_notes", "papers", 0.16, -0.04, -7, n=10, mess=0.18)
        prop("tea", "mug", 0.34, 0.14, 20, mat="porcelain")
        _asm(f, unit + "_story_classboard", "pinboard", wall_x, pier_y,
             wall_yaw, z0=1.20, W=1.05, H=0.72, cards=15, neat=True)
    elif story == "night_nurse":
        prop("meds", "bottles", -0.18, 0.04, n=7)
        prop("rota", "papers", 0.15, -0.02, 4, n=6, mess=0.10)
        prop("coffee", "mug", 0.35, 0.15, -15, mat="ceramic")
    elif story == "seamstress":
        prop("notions", "jarrow", -0.16, 0.04, n=5)
        prop("patterns", "papers", 0.18, -0.03, 12, n=9, mess=0.48)
        # Lena works at the dining table.  The runtime story collage used the
        # living rectangle's east edge as though it were a wall; in 2B that
        # edge is the bathroom and the quad landed on the shower glass.  Give
        # the collage one real, dry backing on the west-wall pier between the
        # side windows.  The south wall is already Lena's three-piece memory
        # composition, and its apparent open end is behind the bath partition.
        # It owns no loose cards: the atlas collage is the paper layer.  A
        # distinct id also stops it colliding with the patterns on the table.
        _asm(f, unit + "_story_pattern_board", "pinboard", wall_x,
             pier_y, wall_yaw, z0=1.01, W=0.66, H=0.66, cards=0,
             neat=False)
    elif story == "horticulturist":
        prop("cuttings", "bottles", -0.18, 0.03, n=6)
        prop("seed_jars", "jarrow", 0.20, -0.02, n=4)
        plant_box(f, unit + "_story_specimen", ux(0.75, 0.60),
                  lcy + 1.35, big=True)
    elif story == "legal_clerk":
        prop("casebooks", "bookpile", -0.21, 0.02, n=8)
        prop("briefs", "papers", 0.17, -0.03, -3, n=12, mess=0.12)
        _asm(f, unit + "_story_deadlines", "pinboard", wall_x, pier_y,
             wall_yaw, z0=1.18, W=1.0, H=0.70, cards=16, neat=True)
    elif story == "young_family":
        prop("schoolbooks", "bookpile", -0.20, 0.04, n=5)
        prop("drawings", "papers", 0.15, -0.05, 18, n=10, mess=0.70)
        prop("breakfast_mug", "mug", 0.36, 0.13, mat="ceramic")
        _asm(f, unit + "_story_familyboard", "pinboard", wall_x, pier_y,
             wall_yaw, z0=1.12, W=1.15, H=0.82, cards=20, neat=False)
    elif story == "short_term_rental":
        prop("city_guides", "bookpile", -0.17, 0.02, n=3)
        prop("empties", "bottles", 0.20, -0.02, n=4, cans=True)
    elif story == "radio_collector":
        prop("radio", "radio", -0.18, 0.0, 180)
        prop("headphones", "headphones", 0.20, -0.01, 12)
        prop("lead", "cablecoil", 0.37, 0.10, r=0.09)
    elif story == "painter":
        prop("solvents", "bottles", -0.19, 0.03, n=7)
        prop("studies", "papers", 0.17, -0.04, -12, n=11, mess=0.78)
        _asm(f, unit + "_story_colorboard", "pinboard", wall_x, pier_y,
             wall_yaw, z0=1.16, W=1.10, H=0.80, cards=22, neat=False)
    elif story == "insomniac_writer":
        prop("draft", "papers", -0.14, -0.02, 8, n=14, mess=0.62)
        prop("references", "bookpile", 0.22, 0.05, n=6)
        prop("cold_coffee", "mug", 0.38, -0.12, mat="ceramic")
    elif story == "estate_collector":
        prop("oddments", "jarrow", -0.19, 0.03, n=5)
        prop("catalogues", "bookpile", 0.15, -0.02, n=5)
        prop("old_radio", "radio", 0.36, 0.10, -165)


## Resident-specific environmental identity (Section 16) and unit states.
## Every occupied unit now carries a full lived-in furniture set; heroes
## get their signature clusters (and conductor markers) layered on top.
def dress_unit(unit, stack, floor_id, z, furniture, markers,
               walls=None):
    x0, y0, x1, y1 = STACK_RECTS[stack]
    cx, cy = (x0 + x1) / 2.0, (y0 + y1) / 2.0
    east = stack in ("C", "D")
    W = abs(x1 - x0)
    f = furniture
    pal = _pal(unit)
    # true interior face of the exterior side wall on THIS storey (the
    # masonry steps thinner above F03, so the face drifts off the stack
    # rect edge) — wall-hung dressing mounts flush against it
    wface = (14.0 - ext_t(floor_id)) * (1 if east else -1)

    def ux(u, w=0.0):
        """x of a box of width w placed u meters off the exterior side wall."""
        return x0 + u if not east else x1 - u - w

    def mk(kind, idx, px, py, pz=0.0, yaw=0, **facts):
        marker = {"kind": kind,
                  "id": "%s_%s_%s_%02d" % (floor_id, stack,
                                               kind.upper(), idx),
                  "unit": unit, "pos": [px, py, z + pz],
                  "yaw_deg": yaw, "network": "electrical"}
        marker.update(facts)
        markers.append(marker)

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
            art_panel(f, "%s_bart%d" % (unit, i), bcx + 0.95, by0 + 0.06,
                      0.7, True)
        elif not east:    # A: bed heads against the west exterior wall
            bed_set(f, "%s_bed%d" % (unit, i), bx0 + 0.35, bcy - 0.75,
                    True, mat_blanket=pal["sofa"])
            wardrobe(f, "%s_w%d" % (unit, i), bx0 + 1.6, by1 - 0.80,
                     face="s")
            art_panel(f, "%s_bart%d" % (unit, i), bx0 + 2.0, by1 - 0.075,
                      0.7, True)
        else:             # D: bed heads against the bedroom partition
            bed_set(f, "%s_bed%d" % (unit, i), bx1 - 2.0, by1 - 2.15,
                    False, mat_blanket=pal["sofa"])
            wardrobe(f, "%s_w%d" % (unit, i), bx1 - 4.5, by0 + 0.18,
                     face="n")
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
        kitchen_run(f, unit + "_k", kx, ky, kL, kax, kside,
                    markers=markers, z=z, floor_id=floor_id)
    # sofa cluster against the exterior side wall, tv on the rug's far edge
    if "sofa" not in skip and unit in SOFA_UNITS:
        sofa_set(f, unit + "_sofa", ux(0.35, 0.85), lcy - 1.0, 1.95,
                 along_x=False, back_far=east, mat=pal["sofa"])
        coffee_table(f, unit + "_cof", ux(1.55, 0.95), lcy - 0.55)
    # No rugs. A tenement floor in 1928 is boards, and the boards are doing
    # more for the room than a rug laid over them - the grain, the wear and the
    # colour of the wood are the warmest thing in an unlit apartment. Covering
    # three square metres of it per unit was subtracting, not adding.
    if "tv" not in skip and unit in TV_UNITS:
        tv_set(f, unit + "_tv", ux(3.10, 0.40), lcy - 0.85, False,
               face="w" if not east else "e")
    dx, dy, dsides = rooms["dining_spot"]
    dining_set(f, unit + "_din", dx, dy, dsides, pal["wood"])
    if "shelf" not in skip and unit in SHELF_UNITS:
        shelf_unit(f, unit + "_shelf", ux(1.2 if stack in ("A", "B")
                   else 2.9, 1.1),
                   ly1 - 0.42 if stack == "C" else ly0 + 0.12, 1.1, True,
                   face="s" if stack == "C" else "n")
    # No standard houseplants. Fifty-four of them made the horticulturist's
    # apartment indistinguishable from everybody else's. 3A keeps its specimens
    # through resident_story_detail(), and now they say something about Malcolm
    # instead of being decor that happens to be green.
    art_panel(f, unit + "_lart", ux(1.8, 0.9),
              ly1 - 0.075 if stack in ("A", "B") else ly0 + 0.04, 0.9, True)
    # lived_in_surface_detail() USED TO RUN HERE, and it is deliberately gone.
    #
    # It put the same mug, the same papers and the same bookpile on the dining
    # table, the coffee table and the desk of all twenty-two apartments. Six
    # clusters a unit, seeded per household so the rotations differed - which is
    # not the same as the homes differing. Every apartment read as the same
    # apartment with the furniture moved, and it was most of what made a room
    # look cluttered without making it look like anyone's.
    #
    # resident_story_detail() below does that job with a name attached. With the
    # generic layer gone, the ONLY loose objects on any surface in this building
    # belong to the person who lives there, so the apartments are unique by
    # construction instead of by seed.
    if unit in RESIDENT_STORIES:
        resident_story_detail(f, unit, RESIDENT_STORIES[unit][1],
                              rooms, ux, lcy, wface)

    # ---- hero overlays: each resident's signature cluster + conductor bodies
    if unit == "2A":    # Mina: ordered caption station, quiet
        # The first desk layout put its west cheek and the first shelf across
        # the H-A supply wheel. Keep Mina's exact squared arrangement, shifted
        # 700 mm into the room as one composition so the service end remains
        # a fitting rather than scenery behind furniture.
        service_dx = 0.70
        desk_set(f, "2A_desk", x0 + 0.5 + service_dx, cy - 0.7, 1.5, True, 1)
        for i in range(3):
            shelf_unit(f, "2A_shelf%d" % i,
                       x0 + 0.4 + service_dx + i * 1.15, y0 + 3.55,
                       0.95, True, h=1.6, books=False, face="n")
        _furn_box(f, "2A_filing", x0 + 2.1 + service_dx, cy - 0.65,
                  0.45, 0.6, 0.0,
                  1.05, "metal", False)
        mk("monitor", 1, x0 + 1.1 + service_dx, cy - 0.5, 0.76, -90)
        # Small, squared to the desk edge like everything else she owns.
        mk("lamp", 1, x0 + 0.8 + service_dx, cy - 0.4, 0.76,
           variant="office_green")
        # the captioner's order: everything squared to the desk edge
        _asm(f, "2A_pinboard", "pinboard", wface + 0.005, cy - 0.45, -90,
             z0=1.05, W=0.95, cards=15, neat=True)
        _asm(f, "2A_phones", "headphones", x0 + 2.32 + service_dx,
             cy - 0.35, -90,
             z0=1.05)
        _asm(f, "2A_papers", "papers", x0 + 0.62 + service_dx,
             cy - 0.30, 0,
             z0=0.735, n=5)
        _asm(f, "2A_mug", "mug", x0 + 1.32 + service_dx,
             cy - 0.60, 40, z0=0.735)
        _asm(f, "2A_deck", "reeldeck", x0 + 1.72 + service_dx,
             cy - 0.42, 0, z0=0.735)
    elif unit == "2C":  # Juno: improvised studio, speakers everywhere
        _furn_box(f, "2C_bench", cx - 1.2, cy - 0.5, 2.4, 0.7, 0.72, 0.05,
                  "metal", False)
        _furn_box(f, "2C_cablerug", cx - 1.8, cy - 1.6, 3.4, 2.4, 0.013,
                  0.012, "soot", False)
        # the rig: stacked combos, leaned guitars, pedals mid-cable-sprawl
        _asm(f, "2C_amp1", "amp", x1 - 0.55, cy + 1.0, 90, W=0.62, H=0.54)
        _asm(f, "2C_amp2", "amp", x1 - 0.55, cy + 1.0, 90, z0=0.57,
             W=0.48, H=0.38)
        _asm(f, "2C_guitar1", "guitar", x1 - 0.28, cy + 0.15, 100)
        _asm(f, "2C_guitar2", "guitar", cx + 0.04, cy + 0.34, 8,
             acoustic=True)
        _asm(f, "2C_pedals", "pedalboard", x1 - 1.35, cy + 0.20, 90)
        _asm(f, "2C_mic", "micstand", cx + 0.75, cy - 0.75, 160)
        _asm(f, "2C_coil1", "cablecoil", x1 - 1.55, cy - 0.15, 40)
        _asm(f, "2C_coil2", "cablecoil", cx - 0.5, cy - 2.0, 200, r=0.14)
        # the record crates that used to be one trim box
        _asm(f, "2C_crate1", "crate", x1 - 0.62, y0 + 0.55, 0,
             records=True)
        _asm(f, "2C_crate2", "crate", x1 - 0.60, y0 + 1.18, 12,
             records=True)
        _asm(f, "2C_crate3", "crate", x1 - 0.62, y0 + 0.55, 0, z0=0.34,
             fill="soot")
        _asm(f, "2C_bottles", "bottles", cx - 0.62, cy - 0.22, 0, z0=0.77)
        _furn_box(f, "2C_pizza", cx + 0.45, cy - 0.42, 0.40, 0.40, 0.77,
                  0.085, "trim", False)
        art_panel(f, "2C_poster1", wface - 0.041, cy + 0.35, 0.7, False,
                  z0=1.35, h=0.95, mat="paper")
        art_panel(f, "2C_poster2", wface - 0.041, cy - 3.75, 0.55, False,
                  z0=0.95, h=0.75, mat="paper")
        art_panel(f, "2C_poster3", x1 - 0.10, y0 + 1.95, 0.6, False,
                  z0=0.05, h=0.85, mat="paper")
        mk("speaker", 1, x1 - 0.6, cy + 1.6, 0.0, -90)
        mk("speaker", 2, x1 - 0.6, cy - 2.2, 0.0, -90)
        chair_box(f, "2C_benchstool", cx - 0.35, cy - 1.35, "s")
        mk("monitor", 1, cx - 0.4, cy - 0.3, 0.76, 180)
    elif unit == "3B":  # Omar: repair shop by category
        # bench cluster sits south of the alcove privacy stub at y1-3.15
        # It used to sit directly over both radiator fittings. The whole
        # working cluster moves 900 mm into the room; the wall toolboard stays
        # on the wall because it is thin enough for a hand to work beneath.
        bench_dx = 0.90
        _asm(f, "3B_workbench", "workbench", x0 + 1.5 + bench_dx,
             y0 + 3.37, 180)
        for i in range(2):
            shelf_unit(f, "3B_tools%d" % i, x0 + 2.85 + i * 1.10,
                       y1 - 0.45, 1.0, True, d=0.4, books=False, face="s")
        for i in range(4):
            _furn_box(f, "3B_bin%d" % i, x0 + 2.95 + i * 0.5, y1 - 0.40,
                      0.4, 0.28, 0.5 + (i % 2) * 0.46, 0.24,
                      ("metal", "fabric_cool")[i % 2], False)
        chair_box(f, "3B_stool", x0 + 1.3 + bench_dx, y0 + 2.6, "s")
        # Rear right corner of the bench top, clear of the mug at 1.00,
        # the radio at 1.35, the jars at 1.62 and the parts tray at 2.00.
        # It used to stand at 1.00/3.50 - directly over its own mug - and
        # 40 mm above a 0.91 top, so it floated. The friction-joint arm
        # reaches the work from the corner, which is what that lamp is for.
        mk("lamp", 1, x0 + 2.35 + bench_dx, y0 + 3.62, 0.91,
           variant="bench_friction")
        # the bench itself, sorted by category like the man sorts his life
        _asm(f, "3B_radio", "radio", x0 + 1.35 + bench_dx,
             y0 + 3.22, 180, z0=0.91)
        _asm(f, "3B_toolboard", "toolboard", wface + 0.005, y0 + 3.27,
             -90, z0=1.15, W=0.9, H=0.65)
        _asm(f, "3B_tray1", "partstray", x0 + 2.0 + bench_dx,
             y0 + 3.29, -8,
             z0=0.91, chassis=True)
        _asm(f, "3B_tray2", "partstray", x0 + 0.78 + bench_dx,
             y0 + 3.37, 94,
             z0=0.91)
        _asm(f, "3B_jars", "jarrow", x0 + 1.62 + bench_dx,
             y0 + 3.62, 0, z0=0.91,
             n=5)
        _asm(f, "3B_manuals", "bookpile", x0 + 0.58 + bench_dx,
             y0 + 3.17, 25,
             z0=0.91, n=4)
        _asm(f, "3B_mug", "mug", x0 + 1.0 + bench_dx,
             y0 + 3.39, 0, z0=0.91,
             mat="enamel")
        _asm(f, "3B_partscrate", "crate", x0 + 0.38, y0 + 0.30, 8,
             fill="metal")
        _asm(f, "3B_coil", "cablecoil", x0 + 2.72, y0 + 2.85, 70)
    elif unit == "3D":  # Rhea: vocal booth and aligned playback
        _furn_box(f, "3D_booth_w", cx + 0.4, cy - 1.0, 0.1, 2.0, 0.0, 2.2,
                  "fabric_cool", False)
        _furn_box(f, "3D_booth_n", cx + 0.4, cy + 1.0, 2.0, 0.1, 0.0, 2.2,
                  "fabric_cool", False)
        _furn_box(f, "3D_boothfoam", cx + 0.5, cy - 0.9, 0.06, 1.8, 0.3,
                  1.6, "soot", False)
        _furn_box(f, "3D_mirror", x1 - 2.6, cy + 0.4, 0.05, 1.2, 0.2, 1.8,
                  "glassish", False)
        shelf_unit(f, "3D_tapes", x1 - 0.42, -2.25, 1.2, False,
                   books=True, face="w")
        mk("speaker", 1, cx + 1.8, cy + 1.2, 0.0, 180)
        mk("speaker", 2, cx + 1.8, cy - 1.2, 0.0, 180)
        # a real stand in the booth, playback console dead-center between
        # the aligned pair, wedge foam checkering the booth's north panel
        _asm(f, "3D_mic", "micstand", cx + 0.95, cy + 0.13, 180)
        _asm(f, "3D_console", "table_rect", cx + 1.8, cy, 90, L=1.15,
             W=0.5, mat="wood_dark")
        _asm(f, "3D_deck", "reeldeck", cx + 1.8, cy + 0.08, -90,
             z0=0.745)
        _asm(f, "3D_phones", "headphones", cx + 1.82, cy - 0.42, -90,
             z0=0.745)
        _asm(f, "3D_mug", "mug", cx + 1.68, cy + 0.42, 0, z0=0.745)
        _asm(f, "3D_lyrics", "papers", cx + 0.62, cy - 0.55, 24, n=8,
             mess=0.5)
        _asm(f, "3D_tapepile", "bookpile", cx + 1.8, cy - 0.82, 12, n=5)
        for i in range(10):
            _furn_box(f, "3D_foam%d" % i, cx + 0.52 + (i % 5) * 0.36,
                      cy + 0.94 - 0.028 * ((i // 5) % 2), 0.30,
                      0.05 + 0.028 * ((i // 5) % 2),
                      0.62 + 0.34 * (i // 5), 0.30, "soot", False)
    elif unit == "5A":  # Nadia: plans over contradictory plans
        _asm(f, "5A_plantable", "plantable", cx, cy + 0.75)
        _furn_box(f, "5A_tuberack", x0 + 2.3, y0 + 3.65, 0.4, 0.4, 0.0,
                  1.1, "ceramic", False)
        shelf_unit(f, "5A_planshelf", x0 + 0.4, y0 + 3.55, 1.6, True,
                   h=1.4, books=False, face="n")
        chair_box(f, "5A_stool", cx + 0.7, cy + 1.55, "n")
        # Buquet-pattern, nickel-plated brass on a weighted wooden base -
        # NOT the aluminium version, which VIII.4 forbids outright. Patented
        # in Paris in February 1927, so hers is weeks old and came through
        # the practice; per Accord 9 it is already scarred where the arm has
        # swung into the drafting board a thousand times.
        mk("lamp", 1, cx + 0.6, cy + 0.75, 0.83,
           variant="architect_counterweight")
        # plans over contradictory plans: two drifted boards, loose sheets
        # taped between them, and a massing model of this very building
        _asm(f, "5A_pins1", "pinboard", wface + 0.005, y0 + 4.45, -90,
             z0=1.0, W=1.25, H=0.85, cards=18, neat=False)
        _asm(f, "5A_pins2", "pinboard", wface + 0.005, y0 + 7.95, -90,
             z0=1.15, W=1.05, H=0.70, cards=14, neat=False)
        for i in range(4):
            _furn_box(f, "5A_sheet%d" % i, wface + 0.006 + 0.004 * i,
                      y0 + 5.00 + 0.10 * i, 0.004, 0.50 - 0.05 * i,
                      1.00 + 0.06 * i, 0.72, "paper", False)
        _asm(f, "5A_modtable", "table_rect", x0 + 1.60, y1 - 0.85, 0,
             L=0.85, W=0.55, mat="wood_dark")
        _asm(f, "5A_model", "sitemodel", x0 + 1.60, y1 - 0.85, -90,
             z0=0.745)
        _asm(f, "5A_papers1", "papers", cx - 0.5, cy + 0.55, 15,
             z0=0.83, n=7, mess=0.8)
        _asm(f, "5A_papers2", "papers", cx + 0.45, cy + 1.0, 170,
             z0=0.83, n=5, mess=0.6)
        _asm(f, "5A_mug1", "mug", cx + 0.78, cy + 0.48, 0, z0=0.83)
        _asm(f, "5A_mug2", "mug", x0 + 2.50, y0 + 3.85, 0, z0=1.10,
             mat="enamel")
        _asm(f, "5A_floorstack", "bookpile", x0 + 2.35, y1 - 0.62, 5,
             n=6)
        for i, off in enumerate((0.30, 0.44, 0.23)):
            _asm(f, "5A_roll%d" % i, "pipe", 0, 0,
                 p0=[x0 + off, y1 - 0.32 - 0.06 * i, z + 0.02],
                 p1=[x0 + 0.10, y1 - 0.16, z + 1.10 + 0.06 * i],
                 r=0.032, mat="paper")
    elif unit == "6A":  # Sacha: capture wall, framed for camera
        _furn_box(f, "6A_deskwall", x0 + 0.4, cy - 1.2, 0.8, 2.6, 0.72,
                  0.05, "trim", False)
        # This used to be one solid 2.4 m steel slab called "legs", hiding
        # both fittings under the desk. Two honest end frames carry the same
        # top and leave the radiator service bay open between them.
        _furn_box(f, "6A_dwleg_s", x0 + 0.5, cy - 1.1, 0.6, 0.12, 0.0,
                  0.72, "metal", False)
        _furn_box(f, "6A_dwleg_n", x0 + 0.5, cy + 1.18, 0.6, 0.12, 0.0,
                  0.72, "metal", False)
        _furn_box(f, "6A_cablerun", x0 + 0.4, cy - 1.5, 2.0, 0.12, 0.013,
                  0.02, "soot", False)
        _furn_box(f, "6A_cot", x0 + 0.4, y1 - 2.5, 0.9, 2.0, 0.0, 0.35,
                  "fabric_cool", False)
        # the capture kit: real camera on sticks, lights flanking the
        # frame, wedge foam behind the desk, life squeezed to the edges
        _asm(f, "6A_tripod", "tripod", x0 + 2.35, cy, 90)
        _asm(f, "6A_soft1", "softbox", x0 + 2.0, cy - 0.85, 50)
        _asm(f, "6A_soft2", "softbox", x0 + 2.0, cy + 1.05, 130)
        _asm(f, "6A_phones", "headphones", x0 + 0.62, cy - 0.55, -90,
             z0=0.77)
        _asm(f, "6A_cans", "bottles", x0 + 0.60, cy + 0.85, 0, z0=0.77,
             n=4, cans=True)
        _asm(f, "6A_gearcrate", "crate", x0 + 0.45, cy + 1.85, 355,
             fill="soot", W=0.50, D=0.40, H=0.36)
        _asm(f, "6A_coil1", "cablecoil", x0 + 1.5, cy + 0.7, 30)
        _asm(f, "6A_coil2", "cablecoil", x0 + 2.6, cy - 0.55, 240,
             r=0.09)
        for r_ in range(3):
            for c_ in range(4):
                _furn_box(f, "6A_foam%d" % (r_ * 4 + c_), wface + 0.008,
                          cy - 1.15 + c_ * 0.60,
                          0.045 + 0.025 * ((r_ + c_) % 2), 0.50,
                          1.05 + 0.36 * r_, 0.30, "soot", False)
        _furn_box(f, "6A_laundry1", x0 + 0.55, y1 - 2.30, 0.50, 0.60,
                  0.35, 0.16, "fabric_cool", False)
        _furn_box(f, "6A_laundry2", x0 + 0.72, y1 - 1.55, 0.35, 0.45,
                  0.35, 0.10, "linen", False)
        _furn_box(f, "6A_pillow", x0 + 0.48, y1 - 0.95, 0.66, 0.40,
                  0.35, 0.12, "linen", False)
        for i in range(3):
            mk("monitor", i + 1, x0 + 0.8, cy - 1.0 + i * 1.0, 0.78, 0)
        _asm(f, "6A_detail_capture_papers", "papers",
             x0 + 0.78, cy + 0.55, 84, z0=0.78, n=8, mess=0.65)
        _asm(f, "6A_detail_capture_mug", "mug",
             x0 + 0.77, cy - 1.02, 210, z0=0.78, mat="ceramic")
        chair_box(f, "6A_deskchair", x0 + 1.55, cy - 0.25, "w")
        # The fan stands on the bedroom floor, not 250 mm above it.  Its
        # Tomorrow File beat names this room, and the room id is also the
        # deterministic cut used to move the attachment plug unseen.
        mk("boxfan", 1, x1 - 1.2, y0 + 1.0, 0.0, 135,
           room="F06_A_BED", variant="sacha_nickel")
    elif unit == "4D":  # short-term rental: nobody actually lives here
        # strip the lived-in warmth back out: it stays, but reads staged
        pass

    # The two bible-owned fans missing from the built layout.  These are
    # chosen floor positions, not runtime searches: Juno's clears the record
    # shelf and amplifier stack; Iris's clears the sofa and the south-wall
    # bookshelf while still sending air across the paint room.
    if unit == "2C":
        mk("boxfan", 1, 11.75, 5.10, 0.0, 180,
           room="F02_C_MAIN", variant="juno_black")
    elif unit == "5C":
        mk("boxfan", 1, 12.85, 0.15, 0.0, -135,
           room="F05_C_MAIN", variant="iris_green")


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
    sb = (-10.18, 9.12, -9.68, 9.50)          # basin opening
    CTR_W = -10.86                            # run's west end
    ST_X0, ST_X1 = -9.55, -8.91               # the range, in the run
    furniture += [
        {"id": "desk", "rect": [-8.45, 4.95, -7.87, 6.25], "z0": 0.72,
         "h": 0.04, "mat": "floor_oak"},
        {"id": "desk_legs", "rect": [-8.40, 5.00, -8.35, 6.20], "z0": 0.0,
         "h": 0.72, "mat": "metal"},
        {"id": "bed", "rect": [-13.40, 6.90, -12.05, 9.50], "z0": 0.15,
         "h": 0.32, "mat": "trim"},
    ]
    # The base AND countertop are four boards around the opening. Segmenting
    # only the 45 mm worktop left the solid cabinet's top face immediately
    # beneath it, so hiding the sink revealed a convincing rectangular lid
    # instead of a hole. These four carcass pieces retain the cupboard run
    # while leaving the basin somewhere physical to descend.
    for seg, rect in (
            ("w", [CTR_W, 9.05, sb[0], 9.55]),
            ("e", [sb[2], 9.05, ST_X0, 9.55]),
            ("s", [sb[0], 9.05, sb[2], sb[1]]),
            ("n", [sb[0], sb[3], sb[2], 9.55])):
        furniture.append({"id": "kitchen_counter_" + seg, "rect": rect,
                          "z0": 0.0, "h": 0.86, "mat": "trim"})
    # Countertop laid as the same four boards around the sink cutout.
    # THE PLAYER'S FLAT GETS A RANGE (ruled 2026-08-08, at the owner's
    # direction: "the players apartment to have all the amenities").
    # 4B was the only flat in the building without one, and that was not
    # an oversight — its kitchen is a 1.85 m galley with the sink in the
    # middle and nowhere a 0.64 m range could stand.
    #
    # Both obvious places are taken. The north wall east of the counter
    # is inside F04_DOOR_07's swing, which is the fault the marker audit
    # caught in the fridge and the reason the fridge moved to the east
    # wall. The east wall now carries that fridge at y 8.60 and the
    # radiator at y 7.48, leaving 0.47 m between them.
    #
    # So the galley is re-planned the way a real one of this length is:
    # RANGE AT THE EAST END OF THE RUN, sink where it already was, run
    # extended to the wall. Working surface goes WEST of the sink, where
    # there is 0.68 m of it and nothing else wants to be — an earlier
    # attempt slid the basin west to make an east worktop instead and
    # put the toaster, mugs and plates on the hob or on each other.
    for seg, rect in (
            ("w", [CTR_W - 0.04, 9.01, sb[0], 9.59]),
            ("e", [sb[2], 9.01, ST_X0, 9.59]),
            ("s", [sb[0], 9.01, sb[2], sb[1]]),
            ("n", [sb[0], sb[3], sb[2], 9.59])):
        # 4B-prefixed on purpose: the life audit checks the player flat by
        # semantic id, and an anonymous counter is invisible to it.
        furniture.append({"id": "4B_kitchen_countertop_" + seg,
                          "rect": rect,
                          "z0": 0.86, "h": 0.045, "mat": "countertop"})
    _kitchen_sink_marker(markers, "4B", (sb[0] + sb[2]) / 2.0,
                         (sb[1] + sb[3]) / 2.0, z + 0.005, 180, "F04",
                         compact=True, drainboard=False)
    # ONLY A MARKER. stove_prop.gd owns the whole range now — the baked
    # assembly the other seventeen carried was deleted in the stove pass,
    # so authoring geometry here would be authoring the thing that was
    # just removed. Yaw 180 faces it south out of the north wall, the
    # same way the run it stands in faces.
    #
    # This is the building's eighteenth range. Anything that counted
    # seventeen counts eighteen, and 4B stops being the flat the cooking
    # audit had to be told to forgive.
    markers.append({
        "kind": "stove", "id": "F04_B_STOVE_01", "unit": "4B",
        "pos": [round((ST_X0 + ST_X1) / 2.0, 4), 9.30, z],
        "yaw_deg": 180, "network": "gas"})
    # The run's plinth under it and the splashback a gas range needs at
    # its back. No wall cupboard over it — see the uppers below.
    furniture.append({"id": "4B_stove_plinth",
                      "rect": [ST_X0, 9.05, ST_X1, 9.62],
                      "z0": 0.0, "h": 0.10, "mat": "trim"})
    furniture.append({"id": "4B_splashback",
                      "rect": [ST_X0 - 0.04, 9.60, ST_X1 + 0.04, 9.64],
                      "z0": 0.86, "h": 0.52, "mat": "subway_tile"})
    # The player's decompression zone is composed as a real room, not a sofa
    # dropped into spare floor: a generous two-seat couch faces the south-wall
    # television across a battered coffee table. The work desk stays visible
    # over the couch arm, so calls can invade leisure without another hallway.
    sofa_set(furniture, "4B_couch", -13.15, 4.12, 2.10, True, True,
             "fabric_cool")
    coffee_table(furniture, "4B_coffee", -12.58, 3.35)
    tv_set(furniture, "4B_tv", -11.20, y0 + 0.06, True, face="n")
    chair_box(furniture, "4B_desk_chair", -9.05, 5.35, "w")
    # Clear of 4B's main rug, which runs to x -8.70. The desk mat used to
    # start at -9.35 and lie half on top of it - two rugs occupying the
    # same 0.65 x 1.15 m of floor, which reads as one rug with a colour
    # fault rather than as two.
    rug_box(furniture, "4B_deskrug", -8.55, 4.85, 1.15, 1.5, "rug_cool")
    shelf_unit(furniture, "4B_shelf", -9.25, y0 + 0.08, 1.1, True,
               books=True, face="n")
    _furn_box(furniture, "4B_mattress", -13.33, 6.97, 1.21, 2.46, 0.32,
              0.16, "linen", False)
    _furn_box(furniture, "4B_blanket", -13.36, 6.94, 1.27, 1.35, 0.46,
              0.05, "fabric_cool", False)
    _furn_box(furniture, "4B_pillow", -13.25, 8.85, 0.65, 0.5, 0.48, 0.10,
              "paper", False)
    markers += [
        # The north-wall position occupied the refrigerator's rear 29 cm:
        # both objects rendered, so the collision looked like a radiator
        # growing through the icebox instead of a failed plan. The east wall
        # keeps it on H-B, clear of the galley run and the refrigerator door.
        {"kind": "radiator", "id": "F04_B_RADIATOR_01", "unit": "4B",
         "pos": [-7.96, 7.48, z], "yaw_deg": -90, "network": "heating",
         "riser": "H-B", "sections": 8},
        # Whatever the last superintendent left. Stamped enamel, one joint,
        # and a shade that has been repainted at least once.
        {"kind": "lamp", "id": "F04_B_LAMP_01", "unit": "4B",
         "pos": [-8.15, 6.00, z + 0.76], "yaw_deg": 0,
         "network": "electrical", "variant": "landlord_enamel"},
        # Keep the historical id: cases and graph routes address it. The kind
        # is intentionally unique so rebuilding this maintenance instrument
        # can never repaint the five domestic picture receivers again.
        {"kind": "signal_terminal", "id": "F04_B_MONITOR_01", "unit": "4B",
         "pos": [-8.05, 5.50, z + 0.76], "yaw_deg": 180,
         "network": "electrical"},
        # West of the sink with the mugs. At -9.70 it was 150 mm from the
        # range's cheek and on top of the plates.
        {"kind": "toaster", "id": "F04_B_TOASTER_01", "unit": "4B",
         "pos": [-10.70, 9.30, z + 0.90], "yaw_deg": 90,
         # The body runs across this short bespoke counter. Its Orison
         # retrofit therefore pulls from the open west end, not through the
         # backsplash like the standard room-facing trays.
         "tray_axis": "-x", "network": "electrical"},
        {"kind": "fridge", "id": "F04_B_FRIDGE_01", "unit": "4B",
         # The old north-wall position sat inside F04_DOOR_07's sweep — a
         # latent fault the marker audit can finally see. On the east wall
         # the front faces west, the left hinge falls south (away from the
         # entry), and the radiator retains 32 cm of air below it.
         "pos": [-8.03, 8.60, z], "yaw_deg": 90,
         "network": "structural", "monitor": False},
        {"kind": "boxfan", "id": "F04_B_BOXFAN_01", "unit": "4B",
         # The old marker floated 250 mm above the floor and hid between the
         # coffee table and west wall.  This floor datum clears the couch and
         # makes the selector legible from the main-room route.
         "pos": [-13.05, 6.10, z], "yaw_deg": 135,
         "room": "F04_B_MAIN", "variant": "landlord_plain",
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
         "pos": [-10.84, 9.40, 9.6 + 1.50], "yaw_deg": 0, "w": 0.48,
         "h": 0.70, "leaf": "closed", "cabinet": True},
        {"kind": "kettle", "id": "F04_B_KETTLE_01", "unit": "4B",
         "pos": [-10.50, 9.30, z + 0.92], "yaw_deg": 180,
         "network": "electrical"},
        # An eight-day spring movement has no wire.  The old marker was
        # electrically coupled to the corridor light — the same category
        # error that left fourteen oak iceboxes on the power network — and
        # it occupied F04_DOOR_09's leaf.  This south-wall request is resolved
        # through WallArtLaw at runtime and stays below the five-foot worker's
        # comfortable reading limit.
        {"kind": "wall_clock", "id": "F04_B_CLOCK_01", "unit": "4B",
         "room": "F04_B_MAIN", "variant": "drop_octagon",
         "mount_wall": "south", "mount_along": 0.72,
         "pos": [-9.373, 2.775, z + 1.58], "yaw_deg": 180,
         "network": "structural"},
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

    # STOPS SHORT OF THE RANGE. It ran to -8.85, which is a wall cupboard
    # hanging directly over four gas burners.
    # One cupboard stops before the real window at x=-10.25. The former
    # second leaf occupied the glazing and the blind passed through it.
    fb("uppers", (-10.86, 9.40, -10.31, 9.64), 1.50, 0.72)
    # The marker-built basin owns the opening; the rack remains the player's
    # draining surface because an attached board would occupy the range.
    # West of the sink, on the working stretch. At -9.62 and -9.30 they
    # would now be standing on the hob.
    _asm(furniture, "4B_mug", "mug", -10.35, 9.235, 0,
         z0=0.905, mat="porcelain")
    # Plates on edge in an actual draining rack beside the basin, narrow
    # enough to stop before the range cheek at -9.55.
    _asm(furniture, "4B_dishrack", "dishrack", -9.605, 9.285, 0,
         z0=0.905, W=0.07, D=0.25, n=4)
    for wi, wc in enumerate((y0 + (y1 - y0) * 0.30,
                             y0 + (y1 - y0) * 0.70)):
        blind_stack(furniture, "4B_blw%d" % wi, -13.58, wc - 0.67, False,
                    "4B" + str(wi))
    blind_stack(furniture, "4B_blr", -10.25, 9.52, True, "4Br")
    fb("rug", (-12.40, 3.40, -8.70, 6.00), 0.0, 0.015, "rug_warm")
    # Coffee-table residue: one mug, a folded work order and the remote. Their
    # asymmetry gives the director tiny objects the player can doubt moved.
    fb("coffee_mug", (-12.36, 3.50, -12.22, 3.64), 0.43, 0.11, "ceramic")
    fb("coffee_workorder", (-12.05, 3.47, -11.77, 3.67), 0.432, 0.012,
       "paper")
    fb("tv_remote", (-12.47, 3.76, -12.27, 3.83), 0.432, 0.035, "metal")
    # The Vantry signal desk owns its complete working surface. The old
    # keyboard, mouse, USB-style microphone, headset stand and power strip
    # were five modern silhouettes baked underneath its runtime prop; leaving
    # them here would make a radio console into a skin over a computer desk.
    for px, py in ((-13.40, 6.92), (-12.21, 6.92), (-13.40, 9.42),
                   (-12.21, 9.42)):
        fb("bedpost_%d_%d" % (int(px * 10), int(py * 10)),
           (px, py, px + 0.06, py + 0.06), 0.0, 0.52, "timber")
    fb("headboard", (-13.40, 9.44, -12.15, 9.50), 0.15, 0.78, "timber")
    fb("nightstand", (-12.05, 9.10, -11.68, 9.48), 0.0, 0.55)
    # the bath's shower riser/head and mirror are part of the real shower
    # and pedestal-sink assemblies bath_fixtures() places; the old stand-in
    # boxes stood inside them


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

def ring_and_cores(floor_id, z, walls, furniture, entry_doors=True,
                   outer_walls=True):
    """Corridor ring, court walls, core walls, shaft walls for one level."""
    h = WALL_H
    # Open decorative alcoves between the stair and corridor ring. Cut both
    # back-to-back wall leaves so the recess reads from either side, but tag
    # it as an alcove: it gets a finished reveal and sill, never glazing,
    # sash, condensation decals, or the visual language of an exterior
    # window. The paired walls are the court wall at
    # x = +-COURT and the corridor inner wall at x = +-XCI stand back to
    # back with no gap, so an opening has to pass through the two of them
    # to reach the hallway.
    #
    # Placed between the flight edges (the eye spans y +-1.46) at chest
    # height, clear of the raked balustrade, so from the stair you look
    # across into the corridor and from the corridor you see the stair.
    SILL, WINH, WINW = 1.05, 1.15, 1.20
    borrow_y = (-0.85, 0.85)

    def _cuts(origin):
        return [{"type": "window", "at": by - origin, "w": WINW,
                 "h": WINH, "sill": SILL, "decorative_alcove": True}
                for by in borrow_y]

    for sx in (-1, 1):
        walls.append(wall((sx * COURT, -COURT), (sx * COURT, COURT),
                          CORR_T, h, z, _cuts(-COURT), mat="brick"))
    # corridor inner walls (x) run past court and cores
    for sx in (-1, 1):
        walls.append(wall((sx * XCI, -YCN), (sx * XCI, YCN), CORR_T, h, z,
                          _cuts(-YCN), mat="plaster", wainscot=True))
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
    # Corridor outer walls with apartment entry doors. B1 supplies its own
    # room-specific versions below; emitting solid generic walls here as
    # well placed an invisible duplicate directly behind every basement
    # doorway.
    for sx, stacks in (((-1, ("A", "B")), (1, ("D", "C")))
                       if outer_walls else ()):
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
    # The B1 street wall must stop under the F01 slab or its above-grade
    # continuation curbs the entrance shut (the water table dresses the
    # exposed base instead). Kept as a hint; seat_walls_under_the_floor_
    # above() is what actually guarantees it, for every wall down here.
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


CEILING_MATERIAL = {
    "corridor": "tin_ceiling", "hall": "tin_ceiling",
    "lobby": "tin_ceiling", "atrium": "tin_ceiling",
}


def _ceiling_material(fid, room):
    """Finish condition follows water and exposure, never generic grunge.

    Corridors and the lobby retain their pressed tin.  Plaster darkens where
    the roof, baths and kitchens can actually feed it; a small deterministic
    minority of ordinary rooms records a century of patched leaks.  The
    structure stays whole.  The approved stair-soffit scan is a separate,
    unique finish and is never tiled over apartment ceilings.
    """
    base = CEILING_MATERIAL.get(room.get("kind"), "plaster")
    if base != "plaster":
        return base
    kind = room.get("kind", "")
    if (kind in ("bathroom", "kitchen", "laundry", "boiler")
            or room.get("id") == "F04_B_MAIN"):
        return "plaster_stained"
    rng = random.Random("ceiling-condition:%s:%s" % (fid, room["id"]))
    # The roof makes failures common on six, not universal.  A whole floor of
    # one stain condition looked authored and also erased the plain-plaster
    # buffer used to prove that floor streaming culls ceilings with their owner.
    threshold = 45 if fid == "F06" else 18
    return "plaster_stained" if rng.randrange(100) < threshold else "plaster"


def ceiling_pass(floors):
    """Give each storey the underside that belongs to the rooms below it.

    The slab at F05 is F05's floor, so floor streaming quite correctly hides
    it when the player is in F04. It was also, accidentally, F04's only
    ceiling. Keeping F05 alive would undo the streaming win; these downward
    faces instead live in F04 and merge into one plaster buffer there.

    Room records overlap deliberately: MAIN is the apartment envelope and a
    BATH or OFFICE may sit inside it. Deal the smaller rooms first and subtract
    every claimed rectangle from the broader one. Besides avoiding coplanar
    faces, this lets a later room-specific finish replace plaster honestly.
    """
    order = ["B1", "F01", "F02", "F03", "F04", "F05", "F06", "ROOF"]
    total = 0
    for fl in floors:
        fl["ceilings"] = []
        fid = fl["id"]
        if fid == "ROOF":
            continue
        above = LEVELS[order[order.index(fid) + 1]]
        ztop = round(above - SLAB_T - 0.005, 3)
        claimed = []
        rooms = sorted((r for r in fl.get("rooms", [])
                        if r.get("kind") != "roof"),
                       key=lambda r: rect_area(r["rect"]))
        for room in rooms:
            rects = [tuple(room["rect"])]
            for prior in claimed:
                rects = subtract_rect(rects, prior)
            for hole in fl["slabs"][0].get("holes", []):
                rects = subtract_rect(rects, tuple(hole))
            mat = _ceiling_material(fid, room)
            for i, rect in enumerate(rects):
                if rect_area(rect) < 0.001:
                    continue
                fl["ceilings"].append({
                    "id": "%s_CEILING_%s_%02d" %
                          (fid, str(room["id"]).upper(), i),
                    "room": room["id"], "rect": list(rect),
                    "z": ztop, "mat": mat,
                })
                total += 1
            claimed.append(tuple(room["rect"]))
    print("ceilings: %d current-floor-owned faces" % total)


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



# Which houseplant is on whose windowsill, and whether it is still alive.
#
# A plant is a statement about its owner, so these are cast rather than
# scattered: the shut-ins keep something that forgives them, the ones who
# are never home keep something that does not care, and two of them keep
# a dead crown in a good pot because nobody throws the pot away.
UNIT_PLANT = {
    "1A": "aspidistra",   # Evelyn: a proofreader's plant, outlives everyone
    "1D": "fern",         # Teresa: fusses over it, mists it, it still sulks
    "2A": "pothos",       # Mina: cuttings in jars along the sill
    "2B": "spider",       # Lena: gives the pups away to the whole floor
    "2C": "sansevieria",  # Juno: out at all hours, needs a plant that copes
    "3A": "rubber",       # Malcolm: bought it as furniture
    "3B": "sansevieria",  # Omar: same reason, different life
    "3D": "pothos",       # Rhea: trails it along the shelf above the desk
    "4A": "dead",         # Peter: pending, like everything else of his
    "4C": "spider",       # Cam and Noel: it came with one of them
    "4D": "dead",         # transient guests water nothing
    "5A": "dracaena",     # Nadia: office plant that followed her home
    "5B": "sansevieria",  # Cal: broadcast hours, no gardening
    "5C": "fern",         # Iris: the studio window is the only humid room
    "6A": "rubber",       # Sacha: matches the sofa
    "6B": "aspidistra",   # Jonah: unfinished, but the plant is fine
    "6C": "dracaena",     # Mae: two histories, one cane
}


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
        # 2.4 m was shorter than the car it is supposed to contain: the
        # cab stands 2.36 m, so at the top landing its roof came within
        # 4 cm of a bulkhead that had no lid on it anyway, and you could
        # see sky down the hoistway. A machine-room bulkhead carries the
        # overhead sheave above the car's overtravel, so it is tall, and
        # it is roofed.
        bh = 3.30
        walls.append(wall((ex0 - m, ey0 - m), (ex0 - m, ey1 + m), CORR_T, bh, z,
                          [], mat="concrete"))
        walls.append(wall((ex1 + m, ey0 - m), (ex1 + m, ey1 + m), CORR_T, bh, z,
                          [], mat="concrete"))
        walls.append(wall((ex0 - m, ey1 + m), (ex1 + m, ey1 + m), CORR_T, bh, z,
                          [], mat="concrete"))
        walls.append(wall((ex0 - m, ey0 - m), (ex1 + m, ey0 - m), CORR_T, bh, z,
                          [door(1.0, DOOR_SERV, "open")], mat="concrete"))
        floor["slabs"].append(
            {"rect": [ex0 - m - CORR_T, ey0 - m - CORR_T,
                      ex1 + m + CORR_T, ey1 + m + CORR_T],
             "z_top": z + bh + 0.16, "t": 0.16, "holes": []})
        rooms.append({"id": "ROOF_OPEN", "rect": [-13.65, -9.65, 13.65, 9.65],
                      "kind": "roof"})
        # 1927 roofscape: chimney stack + cap, limestone coping, the
        # corbelled street cornice, timber water tank, vents, clothesline.
        #
        # The tank is furniture below, baked at -9.45/4.95. It used to also
        # carry a `watertank` marker at -8.00/6.00 which owned nothing: the
        # kind was never registered, no graph node used it, and it sat a metre
        # and a half from the object it appeared to name (AUDIT 2, U7).
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
        # The four anonymous boxes were the right infrastructure count and
        # the wrong ownership.  They are the 1928 reopening's central ILG-
        # pattern roof ventilators: one real motor per bathroom riser, not a
        # private domestic extractor hidden in the player's ceiling.
        for i, (vx, vy, riser, variant) in enumerate((
                (-11.5, -6.0, "V-A", "west_weathered"),
                (-4.0, 8.2, "V-B", "north_belt"),
                (6.5, -7.5, "V-C", "south_repainted"),
                (12.0, 3.0, "V-D", "east_oxidised"))):
            markers.append({
                "kind": "exhaust_fan", "id": "ROOF_VENT_FAN_%s" % riser[-1],
                "pos": [vx, vy, z], "yaw_deg": i * 90,
                "room": "ROOF_OPEN", "riser": riser, "variant": variant,
                "network": "ventilation",
            })
        for px_ in (-12.5, -7.5):
            _furn_box(furniture, "clothespost_%d" % int(px_), px_, -8.6,
                      0.1, 0.1, 0.0, 2.1, "metal", False)
        _furn_box(furniture, "clothesline", -12.45, -8.58, 5.0, 0.03,
                  1.95, 0.02, "metal", False)
        # The skylight itself. The monitor was open-topped, so the "light
        # from the skylight" had no skylight to come from: a steel-ribbed
        # glazed cap closes it and gives the shaft something to start at.
        sk = COURT + CORR_T / 2.0
        _furn_box(furniture, "sky_glass", -sk, -sk, sk * 2, sk * 2, 2.55,
                  0.05, "glassish", False)
        for i in range(7):
            rx = -sk + 0.12 + i * (sk * 2 - 0.24) / 6.0
            _furn_box(furniture, "sky_rib_x%d" % i, rx - 0.035, -sk,
                      0.07, sk * 2, 2.52, 0.11, "metal", False)
        for i in range(7):
            ry = -sk + 0.12 + i * (sk * 2 - 0.24) / 6.0
            _furn_box(furniture, "sky_rib_y%d" % i, -sk, ry - 0.035,
                      sk * 2, 0.07, 2.52, 0.11, "metal", False)
        for rid, rect in (("s", (-sk, -sk, sk, -sk + 0.10)),
                          ("n", (-sk, sk - 0.10, sk, sk)),
                          ("w", (-sk, -sk, -sk + 0.10, sk)),
                          ("e", (sk - 0.10, -sk, sk, sk))):
            _furn_box(furniture, "sky_kerb_%s" % rid, rect[0], rect[1],
                      rect[2] - rect[0], rect[3] - rect[1], 2.50, 0.16,
                      "limestone", False)
        # ---- the roof is a place now, not just a surface you can reach
        _roof_programme(furniture, markers, z)
        stair_top_guard(floor)
        atrium_tree(floor)
        return floor

    ring_and_cores(floor_id, z, walls, furniture,
                   entry_doors=(floor_id != "B1"),
                   outer_walls=(floor_id != "B1"))
    exterior(floor_id, z, walls)
    split_walls(z, walls)

    if floor_id == "B1":
        # Somewhere to wait out a wash. Plain plank, against the wall,
        # clear of the machines.
        _asm(furniture, "b1_laundry_bench", "bench", -9.60, 2.95, 0,
             style="slat", L=1.4)
        # AND SOMETHING TO DO WHILE YOU WAIT. Same argument as the hand
        # laundry across the street: the machine goes where the people
        # already are and already have forty minutes to kill. This one is
        # the building's, which means it is the superintendent's problem
        # when it stops taking coins — see the job creep throughline in
        # PROP_ACTIVITIES. Against the east wall of the laundry (stack B
        # runs to x -5.51), clear of the bench and the machines.
        _asm(furniture, "b1_laundry_cab", "arcade_cab", -5.95, 4.60, 270,
             variant=0)
        names = {"A": "STORAGE_CAGES", "B": "LAUNDRY", "C": "BOILER",
                 "D": "ELECTRICAL"}
        for sx, stacks in ((-1, ("A", "B")), (1, ("D", "C"))):
            openings = []
            for stack in stacks:
                x0, y0, x1, y1 = STACK_RECTS[stack]
                openings.append(door(abs((y0 + y1) / 2 - (-Y_IN)), DOOR_SERV, "open"))
            walls.append(wall((sx * XCO, -Y_IN), (sx * XCO, Y_IN), CORR_T,
                              WALL_H, z, openings, wainscot=True))
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
        # The plant room tells the building's heating history in one look:
        # the original 1912 coal boiler is still where the fitters set it,
        # patched rather than replaced, while every generation of caretaker
        # has added another valve, clamp and inspection tag around it. The
        # bleakness is not an abandoned relic beside a modern answer; it is
        # that the Orison never received the answer. The interactive marker
        # is the sole owner of that working plant, so no baked duplicate sits
        # behind it pretending to be history.
        #
        # The heap used to be a rectangular block of SLAB - grey
        # concrete in the shape of a crate, which is what read as a
        # white blob in the corner of the coal room.
        _asm(furniture, "b1_coal_heap", "coal_heap", 12.85, 1.50, 0,
             W=0.95, D=1.70, H=0.58)
        markers += [
            # Faces the open service aisle; its rear breeching runs north to
            # the masonry chimney. The old marker was 3.58 m from the boiler
            # it purported to operate and spawned a third plant mid-room.
            {"kind": "boiler", "id": "B1_BOILER_01",
             "pos": [9.05, 1.55, z], "yaw_deg": 180,
             "network": "heating"},
            # North of the pier, where the pair reads from the doorway as a
            # pair. At their old 3.55/4.35 positions the masonry never hit a
            # footprint, so every clearance audit passed, but it hid the
            # second machine in every honest room view. The 1.15 m centres
            # also leave room for each wringer head to swing.
            {"kind": "washer", "id": "B1_WASHER_01",
             "pos": [-13.28, 5.45, z],
             "yaw_deg": -90, "network": "water"},
            {"kind": "washer", "id": "B1_WASHER_02",
             "pos": [-13.28, 6.60, z],
             "yaw_deg": -90, "network": "water"},
            # A domestic tumble dryer is a 1938 answer in a 1927 room.
            # Two rinse tubs and the ceiling pulley rack are one interactive
            # ensemble: the wet garment's actual path after the wringer.
            {"kind": "laundry_airer", "id": "B1_LAUNDRY_AIRER_01",
             "pos": [-12.95, 8.05, z],
             "yaw_deg": -90, "network": "structural"},
            {"kind": "room0_threshold", "id": "B1_ROOM0_DOOR",
             "pos": [0.0, 6.9, z], "yaw_deg": 180, "network": "structural"},
        ]
        # ceiling pipe runs: heating headers, corridor mains, riser stubs
        _asm(furniture, "b1_header", "pipe", 0, 0,
             p0=[-5.85, 0.0, z + 2.38], p1=[9.05, 0.0, z + 2.38], r=0.075)
        _asm(furniture, "b1_spur", "pipe", 0, 0,
             p0=[9.05, 0.0, z + 2.38], p1=[9.05, 1.55, z + 2.38], r=0.075)
        _asm(furniture, "b1_boilerriser", "pipe", 0, 0,
             p0=[9.05, 1.55, z + 1.84], p1=[9.05, 1.55, z + 2.38], r=0.11)
        # Boiler-owned smoke hood ends above its rear cheek; this building-
        # owned breeching completes the visible trip to the chimney thimble.
        _asm(furniture, "b1_boiler_breeching", "pipe", 0, 0,
             p0=[9.05, 2.08, z + 1.88], p1=[9.90, 9.18, z + 1.88], r=0.17)
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
        # Cold supply dedicated to the laundry. The graph used to hang these
        # water appliances on the steam header; this visible main is also the
        # physical reason the corrected graph has somewhere honest to go.
        _asm(furniture, "b1_laundry_water_main", "pipe", 0, 0,
             p0=[-13.48, 4.95, z + 0.95], p1=[-13.48, 8.55, z + 0.95],
             r=0.035, mat="metal")
        for i, wy in enumerate((5.45, 6.60, 8.05)):
            _asm(furniture, "b1_laundry_water_branch%d" % i, "pipe", 0, 0,
                 p0=[-13.48, wy, z + 0.95],
                 p1=[-13.24, wy, z + 0.95], r=0.018, mat="brass_dull")
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
             "riser": "H-A", "unit": "LOBBY", "sections": 9},
            # The Handbook's reference clock finally exists.  It is not a
            # windable domestic movement: it receives Vantry's house time
            # signal and is therefore licensed by VIII.2 to be uncannily
            # advanced.  Its small, stable error is why every obedient clock
            # in the building is wrong for a reason rather than decoration.
            {"kind": "wall_clock", "id": "F01_LOBBY_CLOCK_01",
             "unit": "LOBBY", "room": "F01_LOBBY",
             # The wall centre is later occupied by the original Orison
             # advertisement board, a Godot pass the layout audit cannot see.
             # The master belongs toward the entrance end, not behind sales.
             "variant": "vantry_master", "mount_wall": "east",
             "mount_along": 0.25,
             "pos": [5.225, -8.970, z + 1.95], "yaw_deg": -90,
             "network": "signal"},
            # (The old generated mail wall is gone: the functional brass
            # MailBankProp on the east lobby wall is the real one now.)
            # The street-door sconce is gone (2026-08-05). It hung at
            # z 2.62 directly under a marquee whose glazed tray is now a
            # lit ceiling over the same doorway - two fixtures lighting
            # one square metre, the older one from inside the newer one's
            # shadow. The marquee is the light you arrive by.
            # Neon on the street elevation. The blade projects at right
            # angles to the wall so it is legible coming DOWN the pavement
            # rather than only from across the road, which is the whole
            # point of a blade sign. It hangs off the pier east of the
            # entrance, clear of the doorway and the water table.
            # yaw 0 turns the lit face toward the street; 180 would read
            # the lettering backwards through the lobby wall.
            {"kind": "neon_sign", "id": "F01_NEON_BLADE",
             # Origin ON the facade face (y -10.00): the blade is built
             # projecting south from there, standing 1.19 m off the wall
             # so it reads from either end of the block instead of only
             # from square in front of it. Centred at z 6.60 it spans
             # 3.77 to 9.43 - clear of the marquee (tops at 3.66) and of
             # the F02 window that ends at x 3.17, with the bracket
             # landing in solid brick.
             "pos": [3.35, -10.00, z + 6.60], "yaw_deg": 0,
             "text": "ORISON", "vertical": True, "network": "electrical",
             "tint": [1.0, 0.32, 0.44]},
            # ...and the ground-floor tenant's own sign, flat on the wall
            # west of the door: a druggist's, because every block had one.
            {"kind": "neon_sign", "id": "F01_NEON_TENANT",
             "pos": [-6.4, -10.12, z + 3.15], "yaw_deg": 0,
             "text": "DRUGS", "vertical": False, "network": "electrical",
             "tint": [0.34, 0.86, 1.0]},
        ]
        # The marquee: hung off the facade above the stone surround, not
        # resting on it, because it was bolted up a decade after the
        # building went in. Origin on the outer face of the south wall
        # (y -10.00) at the door centreline; the assembly projects south
        # 1.80 m and its tie rods anchor at z 5.08, in the solid brick
        # pier between the two F02 windows (which stop at x +/-1.82).
        _asm(furniture, "entry_marquee", "entrance_marquee", 0.0, -10.00,
             0, exterior=True)
        # Prismatic glass over the door is only a centrepiece if it is
        # lit from inside the tray. Two flush fittings in the soffit.
        for mi, mx in enumerate((-0.78, 0.78)):
            markers.append({"kind": "flush_dome",
                            "id": "F01_MARQUEE_LT_%02d" % (mi + 1),
                            "pos": [mx, -10.86, z + 3.24], "yaw_deg": 0,
                            "exterior": True,
                            "network": "electrical", "unit": "LOBBY"})
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
        # lobby: hall settle west of the street door (the east side belongs
        # to the runtime brass mail bank corner), runner to the atrium
        # Two settles flanking the street door, clear of the pilasters
        # at x +/-1.35 and pulled out to -9.26 so their backs stop
        # cutting into the window sill - at -9.38 a 0.48 m deep bench
        # put its back rail 35 mm inside the wall face.
        _asm(furniture, "lobby_bench_w", "bench", -2.20, -9.26, 0, L=1.4)
        _asm(furniture, "lobby_bench_e", "bench", 2.20, -9.26, 0, L=1.4)
        # The common room keeps a settle to match the lobby; everywhere a
        # bench gets rained on, splashed or sat on in work clothes gets
        # the plain plank kind instead.
        _asm(furniture, "common_bench", "bench", -8.70, 5.62, 0, L=1.5)
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
        # The notice board used to hang at x=5.2 on the east lobby wall -
        # the same wall, at the same height, as the brass mail bank, so
        # the two occupied one another. It belongs on the route people
        # actually walk: leaving the street door for the stairs you pass
        # up the hall, and this is the wall on your left, centred on the
        # run and under the hall fixture.
        # The lobby board is a real object now (LobbyBulletinBoard), with
        # printed notices pinned to cork rather than a flat paper-material
        # panel in a frame. Placed from building_root at the same spot on
        # the walk from the street door to the stairs.
        # The cast-iron plant, in the lobby it was invented for: it will
        # outlive the boiler, the residents and probably the building.
        plant_box(furniture, "lobby_plant", -2.35, -9.20, big=True,
                  species="aspidistra")
        # community room (B stack) and building storage (C stack)
        _asm(furniture, "common_table", "table_rect", -9.2, 6.6, 0,
             L=2.6, W=1.0)
        # THE COMMON ROOM'S MACHINE. A residents' room with a table, a
        # settle and three chairs is a room nobody uses; the cabinet is
        # what makes it somewhere people are found. Against the west wall
        # (stack B starts at x -13.65), facing back into the room.
        _asm(furniture, "common_cab", "arcade_cab", -13.10, 7.85, 90,
             variant=1)
        # And one in the lobby — where a building puts the thing it was
        # talked into taking and now cannot get rid of. It is the first
        # cabinet a player ever sees, thirty seconds from the desk they
        # were hired to sit at, which states the job-creep joke before
        # the game has said a word.
        #
        # WEST of the street door, not east: the east lobby wall is the
        # brass mail bank's corner and Dead Letters is played standing in
        # front of it. Back to the south wall (yaw 180 faces the leaf's
        # back at -y), clear of the settle at -2.20 and the pilaster
        # at -1.35.
        _asm(furniture, "lobby_cab", "arcade_cab", -4.60, -9.05, 180,
             variant=3)
        for i in range(3):
            chair_box(furniture, "common_ch%d" % i, -10.4 + i * 1.0, 5.60, "s")
            chair_box(furniture, "common_chn%d" % i, -10.4 + i * 1.0, 7.35, "n")
        _furn_box(furniture, "common_stack1", -13.3, 8.8, 0.55, 0.55,
                  0.0, 1.35, "metal", False)
        art_panel(furniture, "common_notice", -9.5, 2.745, 1.2, True,
                  z0=1.1, h=0.9, mat="paper")
        kitchen_run(furniture, "common_k", -6.15, 7.0, 2.2, False, "e")
        # The common room has the nineteenth kitchen basin but intentionally
        # no domestic range/fridge pair. Add only the cutout-owned sink; passing
        # markers through kitchen_run would invent two appliances here.
        common_cw = 0.95
        common_yaw = FACE_YAW["w"]
        common_cx, common_cy = -6.15 + 0.32, 7.0 + common_cw / 2.0
        _kitchen_sink_marker(
            markers, "common_k",
            common_cx + (-0.20 * common_cw) * math.cos(math.radians(common_yaw)),
            common_cy + (-0.20 * common_cw) * math.sin(math.radians(common_yaw)),
            z, common_yaw, floor_id)
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
    west_storage(floor_id, z, furniture)
    rooms.append({"id": "%s_CORRIDOR" % floor_id,
                  "rect": [-XCO, -Y_IN, XCO, Y_IN], "kind": "corridor"})
    core_rooms(floor_id, z, rooms, furniture)
    chimney_block(floor_id, z, walls)
    porch(floor_id, z, furniture)
    # The masonry is CHIMNEY; this marker is only the sealed room-side
    # thimble.  The old y=8.95 floated its 30 mm plate 150 mm in front of the
    # breast's south face at CHIMNEY[1].  Keep the marker ID unchanged — it is
    # the runtime acoustic binding key — while correcting the household and
    # room metadata that used to be the nonexistent hybrid "F02C".
    markers.append({"kind": "flue_breast", "id": "%s_FLUE_BREAST" % floor_id,
                    "unit": unit_name(floor_id, "C"),
                    "room": "%s_C_BED2" % floor_id,
                    "pos": [10.0, CHIMNEY[1], z], "yaw_deg": 180,
                    "network": "flue"})
    if floor_id in ("F02", "F03", "F04", "F05", "F06"):
        markers.append({"kind": "porch_deck",
                        "id": "%s_PORCH_DECK" % floor_id,
                        "pos": [-9.15, 10.70, z], "yaw_deg": 0,
                        "network": "structural"})
    # Semantic junctions anchor the electrical/acoustic graph. They deliberately
    # spawn no prop: the floor-level corridor-light markers they replaced created
    # duplicate fixtures underneath the ceiling-mounted dome family. That whole
    # family was removed in 2026-08-10 (AUDIT 2), script and profile included.
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


# The mood inversion: circulation is DIM and the homes are WARM. A corridor
# at night in a 1927 block is pools of light with dark between them — the
# walk is moody, and every apartment door is an oasis by contrast. So
# circulation kinds sit well below 1.0 and dwelling kinds well above, and
# the gap between them IS the design. Raising a corridor value here should
# feel like breaking something.
ROOM_LIGHT = {
    "living": 1.35, "bedroom": 1.1, "alcove": 1.0, "hall": 0.68,
    "kitchen": 1.35, "office": 1.3, "common": 1.25, "lobby": 1.05,
    "vestibule": 0.7, "atrium": 0.9, "utility": 0.6, "storage": 0.55,
    "laundry": 0.8, "boiler": 0.65, "electrical": 0.7,
    "storage_cages": 0.55, "coal": 0.5,
}
# Resident temperament, the full cast — each home is an oasis to ITS OWN
# taste, which for some residents is barely an oasis at all. Heroes:
# Mina bright and even, Juno amp-glow, Omar floods the bench, Rhea
# playback light, Nadia task lighting, Sacha monitor level. Supporting:
# Evelyn keeps a teacher's good lamp; Teresa sleeps days and rests dim;
# Lena's workroom is lit like a shop; Malcolm lives half by grow-light;
# Peter over-lights against uncertainty; Noel's cases get museum halogen;
# the transients never touch the dimmer; Cal tunes in the dark; Iris
# needs daylight wattage; Jonah writes by one lamp; Mae protects her
# archive from bright light.
UNIT_LIGHT = {"2A": 1.15, "2C": 0.68, "3B": 1.25, "3D": 0.65,
              "5A": 1.20, "6A": 0.55, "4D": 1.0,
              "1A": 1.2, "1D": 0.8, "2B": 1.15, "3A": 1.05,
              "4A": 1.25, "4C": 1.15, "5B": 0.6, "5C": 1.3,
              "6B": 0.72, "6C": 0.9}


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
                # Domes sit 5.1 m apart and the throw deliberately does NOT
                # reach the neighbour: the dark third between pools is the
                # corridor's mood, and the emissive fixture bodies keep the
                # rhythm legible through it. (This reverses the old
                # even-wash tuning, which read as an office.)
                "range": 4.6, "energy": 0.55,
                "navigation": True, "standby": 0.22,
                "yaw_deg": 0, "network": "electrical"})
    for r in fl["rooms"]:
        fix = ROOM_FIXTURE.get(r["kind"])
        if fix is None:
            continue
        unit = r.get("unit", "")
        if unit == "2D" or unit == "5D":
            continue
        if r["id"] in ("F04_B_MAIN",):
            continue
        x0, y0, x1, y1 = r["rect"]
        cx, cy = (x0 + x1) / 2.0, (y0 + y1) / 2.0
        # Per-room mount height. This MUST be a fresh local: assigning to
        # `ceil` inside the atrium branch leaked the court's height into
        # every room the loop visited afterwards, and dropped the
        # basement's cage bulbs to head height.
        mount = ceil
        if r["kind"] == "atrium":
            # The court lights itself: atrium_tree() hangs fruit off the
            # branches at the heights they actually reach. A fixture
            # placed here would float in the middle of the eye with
            # nothing holding it.
            continue
        if r["kind"] == "lobby" and r["id"] != "F01_LOBBY":
            continue  # one chandelier, in the lobby proper
        marker = {
            "kind": fix, "id": "%s_LT_%s" % (r["id"], fix.upper()),
            "unit": unit or fl["id"],
            "pos": [round(cx, 3), round(cy, 3), z + mount],
            "yaw_deg": 0, "network": "electrical"}
        if r["kind"] in ("hall", "corridor", "atrium", "lobby",
                         "vestibule", "utility"):
            marker["navigation"] = True
            # circulation standby: the atrium drops and the lobby
            # chandelier spill hardest (they are the building's vertical
            # and social hearts); halls and utility stay dimmer
            marker["standby"] = {"atrium": 0.50, "lobby": 0.45,
                                 "vestibule": 0.45}.get(r["kind"], 0.30)
        if r["kind"] != "atrium":   # the eye is meant to throw far
            rw, rd = x1 - x0, y1 - y0
            # Reach the far FLOOR corner, not the far corner of the plan. The
            # fitting hangs at `mount` above the floor, so the distance it
            # actually has to cover is the 3D diagonal; using the 2D one left
            # every corner of every room sitting just outside the falloff,
            # which is most of a room's visible surface.
            marker["range"] = round(((rw * 0.5) ** 2 + (rd * 0.5) ** 2
                                     + mount * mount) ** 0.5 + 0.9, 2)
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
                # A switch pair straddles the wall, one plate per face.
                # On an EXTERIOR wall that means one of them lands on the
                # street, which is how a light switch ended up screwed to
                # the brick beside the front door. Nobody wires a switch
                # outdoors on a 1926 apartment house; the outboard plate
                # is dropped wherever it falls beyond the interior face.
                if abs(sx_) > X_IN + 0.01 or abs(sy_) > Y_IN + 0.01:
                    EXTERIOR_SWITCHES_DROPPED.append(
                        "%s_SW_%02d_%d" % (fl["id"], n, yaw % 360))
                    continue
                fl["furniture"].append({
                    "id": "%s_SW_%02d_%d" % (fl["id"], n, yaw % 360),
                    "asm": "switch", "at": [round(sx_, 4), round(sy_, 4)],
                    "yaw": yaw, "z0": 1.12})


def classify_door_markers(floors):
    """Give every leaf the semantic facts its prop needs.

    Width used to stand in for class and lock state for finish.  Both are
    accidents.  Probe the rooms on the two faces of the opening once, in the
    generator, and emit the decision so runtime, Blender audits and the door
    actor all read the same versioned fact.
    """
    import math
    counts = {}
    for fl in floors:
        rooms = fl.get("rooms", [])
        for marker in fl.get("markers", []):
            if marker.get("kind") != "door":
                continue
            did = marker.get("id", "")
            if marker.get("cabinet"):
                kind = "cabinet"
                adjacent = []
            elif did == "F01_DOOR_06":
                kind = "landmark_entry"
                adjacent = []
            elif did.startswith("SITE_SHOP_DOOR_") or did in (
                    "F01_BODEGA_DOOR", "F01_BAR_DOOR"):
                kind = "storefront"
                adjacent = []
            elif marker.get("exterior"):
                kind = "exterior_service"
                adjacent = []
            else:
                angle = math.radians(marker.get("yaw_deg", 0))
                # DoorProp's local +X runs from hinge to latch. Blender yaw
                # uses the opposite sign from Godot around Y.
                dx, dy = math.cos(angle), -math.sin(angle)
                cx = marker["pos"][0] + dx * marker["w"] * 0.5
                cy = marker["pos"][1] + dy * marker["w"] * 0.5
                nx, ny = -dy, dx
                adjacent = []
                for side in (-1, 1):
                    px, py = cx + nx * 0.34 * side, cy + ny * 0.34 * side
                    hits = [r for r in rooms
                            if r["rect"][0] <= px <= r["rect"][2]
                            and r["rect"][1] <= py <= r["rect"][3]]
                    if hits:
                        adjacent.append(min(hits, key=lambda r:
                                            (r["rect"][2]-r["rect"][0]) *
                                            (r["rect"][3]-r["rect"][1])))
                units = sorted(set(r.get("unit") for r in adjacent
                                   if r.get("unit")))
                common = any(not r.get("unit") for r in adjacent)
                if len(units) == 1 and common:
                    kind = "apartment_entry"
                    marker["unit"] = units[0]
                elif len(units) == 1:
                    kind = "apartment_interior"
                    marker["unit"] = units[0]
                else:
                    kind = "service"
            # F01's B/C rooms are common and landlord storage now, but their
            # 1928 openings are still apartment-address entries. The four
            # reopening leaves form one bank and keep their original unit
            # identity even where the tenancy later disappeared.
            first_floor_entries = {"F01_DOOR_02": "1A",
                                   "F01_DOOR_03": "1B",
                                   "F01_DOOR_04": "1D",
                                   "F01_DOOR_05": "1C"}
            if did in first_floor_entries:
                kind = "apartment_entry"
                marker["unit"] = first_floor_entries[did]
            if adjacent:
                marker["rooms"] = [r["id"] for r in adjacent]
                if "unit" not in marker:
                    units = sorted(set(r.get("unit") for r in adjacent
                                       if r.get("unit")))
                    if len(units) == 1:
                        marker["unit"] = units[0]
            marker["subtype"] = kind
            marker["finish_variant"] = sum(ord(c) for c in did) % 3
            counts[kind] = counts.get(kind, 0) + 1
    print("door classifier: " + ", ".join("%s=%d" % item
          for item in sorted(counts.items())))


EXTERIOR_SWITCHES_DROPPED = []


COVERAGE_SWITCHES_ADDED = []

LIGHT_KINDS_FOR_SWITCH = ("flush_dome", "pendant_shade", "sconce_globe",
                          "kitchen_linear", "cage_bulb", "chandelier",
                          "eye_pendant", "ceiling_light")


def switch_coverage_pass(floors):
    """Every room with a light gets something to switch it with.

    The original pass hangs a plate pair on each side of every DOOR. That
    is correct as far as it goes, and it leaves out every room you reach
    through an archway - the halls, the atria, the alcoves open to their
    main room - plus any room whose door belongs to a neighbour. Twenty-two
    rooms had a fixture and no plate anywhere, one of them the player's own
    kitchen.

    Placement follows normal practice rather than convenience: the plate
    goes on the LATCH side of the room's principal opening, inside the
    room, about 200 mm clear of the reveal, at 1.12 m to centre. Latch
    side matters - a switch behind a door that opens onto it is a switch
    you cannot reach without closing the door first.
    """
    for fl in floors:
        rooms = fl.get("rooms", [])
        furn = fl["furniture"]
        existing = [f["at"] for f in furn if f.get("asm") == "switch"]
        for r in rooms:
            x0, y0, x1, y1 = r["rect"]
            lit = any(m.get("kind") in LIGHT_KINDS_FOR_SWITCH
                      and m.get("pos")
                      and x0 <= m["pos"][0] <= x1
                      and y0 <= m["pos"][1] <= y1
                      for m in fl.get("markers", []))
            if not lit:
                continue
            if any(x0 - 0.4 <= a[0] <= x1 + 0.4
                   and y0 - 0.4 <= a[1] <= y1 + 0.4 for a in existing):
                continue
            spot = _plate_beside_opening(fl, r)
            if spot is None:
                continue
            sx, sy, yaw = spot
            sid = "%s_SWX_%s" % (fl["id"], r["id"])
            furn.append({"id": sid, "asm": "switch",
                         "at": [round(sx, 4), round(sy, 4)],
                         "yaw": yaw, "z0": 1.12})
            existing.append([sx, sy])
            COVERAGE_SWITCHES_ADDED.append(sid)


def _switch_served_room(fl, switch):
    """The generator-side twin of SwitchSystem._room_served().

    Bathroom circuits are authored here rather than rediscovered at runtime.
    Keeping the old inference as a fallback protects ordinary plates while the
    wet-room assertion below makes the important twenty-three explicit.
    """
    angle = math.radians(switch.get("yaw", 0))
    px = switch["at"][0] + math.sin(angle) * 0.45
    py = switch["at"][1] + math.cos(angle) * 0.45
    hits = []
    for room in fl.get("rooms", []):
        x0, y0, x1, y1 = room["rect"]
        if x0 <= px <= x1 and y0 <= py <= y1:
            hits.append(((x1 - x0) * (y1 - y0), room["id"]))
    return min(hits)[1] if hits else ""


def bathroom_switch_pass(floors):
    """Name one safe, reachable circuit owner for every bathroom.

    A plate beside a door was already able to find a room by probing through
    its wall face, but that made bathroom power depend on a runtime geometric
    guess.  The primary plate is now versioned in the layout.  Prefer the dry
    face outside the room where one exists; otherwise use the latch-side plate
    farthest from the shower. The safety distance is measured from the shower
    centre less its 460 mm half-envelope, not from the basin: a hand basin is
    not itself a wet zone, while the curtained shower emphatically is.
    """
    count = 0
    for fl in floors:
        for room in (r for r in fl.get("rooms", [])
                     if r.get("kind") == "bathroom"):
            x0, y0, x1, y1 = room["rect"]
            showers = [m for m in fl.get("markers", [])
                       if m.get("kind") == "shower" and m.get("pos")
                       and x0 - 0.2 <= m["pos"][0] <= x1 + 0.2
                       and y0 - 0.2 <= m["pos"][1] <= y1 + 0.2]
            candidates = []
            for switch in fl.get("furniture", []):
                if switch.get("asm") != "switch" \
                        or _switch_served_room(fl, switch) != room["id"]:
                    continue
                sx, sy = switch["at"]
                inside = x0 <= sx <= x1 and y0 <= sy <= y1
                centre_clear = min((math.hypot(sx - m["pos"][0],
                                                sy - m["pos"][1])
                                    for m in showers), default=99.0)
                wet_clear = centre_clear - 0.46
                candidates.append((inside, -wet_clear, switch, wet_clear))
            if not candidates:
                raise SystemExit("bathroom %s has no reachable light switch"
                                 % room["id"])
            # False sorts before True: a corridor/bedroom-side plate wins.
            inside, _, primary, clearance = sorted(
                candidates, key=lambda c: (c[0], c[1]))[0]
            if inside:
                # Five B-plan doors put the inferred bathroom control on the
                # wet-room face, where the open leaf covers the hand reaching
                # for it. The paired plate is already on the dry face. Swap
                # their circuit ownership rather than adding a third plate or
                # stealing the adjoining room's only control.
                stem = primary["id"].rsplit("_", 1)[0]
                mates = []
                for switch in fl.get("furniture", []):
                    sx, sy = switch.get("at", [999.0, 999.0])
                    if switch.get("asm") != "switch" \
                            or not switch.get("id", "").startswith(stem + "_") \
                            or switch is primary \
                            or (x0 <= sx <= x1 and y0 <= sy <= y1):
                        continue
                    mates.append(switch)
                if not mates:
                    raise SystemExit("bathroom %s switch is trapped by its "
                                     "door and has no dry-face mate" % room["id"])
                mate = min(mates, key=lambda s: math.hypot(
                    s["at"][0] - primary["at"][0],
                    s["at"][1] - primary["at"][1]))
                mate_room = _switch_served_room(fl, mate)
                if mate_room:
                    primary["serves_room"] = mate_room
                primary = mate
                sx, sy = primary["at"]
                centre_clear = min((math.hypot(sx - m["pos"][0],
                                                sy - m["pos"][1])
                                    for m in showers), default=99.0)
                clearance = centre_clear - 0.46
            if clearance < 0.75:
                raise SystemExit("bathroom %s switch enters wet zone (%.2fm)"
                                 % (room["id"], clearance))
            primary["serves_room"] = room["id"]
            primary["bathroom_switch"] = True
            primary["wet_clearance"] = round(clearance, 3)
            count += 1
    if count != 23:
        raise SystemExit("bathroom switch count %d != 23" % count)
    print("bathroom switches: 23 explicit circuits, all clear of wet zones")


def _plate_beside_opening(fl, r):
    """Inside the room, beside its widest opening, clear of the swing."""
    x0, y0, x1, y1 = r["rect"]
    best = None
    for w in fl.get("walls", []):
        ax, ay = w["a"]
        bx, by = w["b"]
        horizontal = abs(by - ay) < 1e-6
        cross = ay if horizontal else ax
        # the wall has to lie on one of this room's four edges
        edges = (y0, y1) if horizontal else (x0, x1)
        side = None
        for e in edges:
            if abs(cross - e) < 0.30:
                side = e
                break
        if side is None:
            continue
        start = min(ax, bx) if horizontal else min(ay, by)
        lo, hi = (x0, x1) if horizontal else (y0, y1)
        for o in w.get("openings", []):
            if o.get("type") != "door":
                continue
            c = start + o["at"]
            if not (lo - 0.1 <= c <= hi + 0.1):
                continue
            if best is None or o["w"] > best[0]["w"]:
                best = (o, w, c, horizontal, cross, lo, hi)
    if best is None:
        return None
    o, w, c, horizontal, cross, lo, hi = best
    t = float(w["t"])
    # 200 mm clear of the reveal, on whichever side has room for a hand
    off = o["w"] * 0.5 + 0.20
    along = c + off if (c + off + 0.12) <= hi else c - off
    if along < lo + 0.12:
        along = c + off
    # inside the room, just off the wall face
    inward = t * 0.5 + 0.002
    if horizontal:
        into = inward if cross < (y0 + y1) * 0.5 else -inward
        return along, cross + into, 0 if into > 0 else 180
    into = inward if cross < (x0 + x1) * 0.5 else -inward
    return cross + into, along, -90 if into > 0 else 90


def radiator_pipe_pass(floors):
    """Continue every heating riser from slab to ceiling.

    The prop owns its tee, union and valve; this is the building-owned pipe
    they visibly terminate at. Generator furniture and the legacy radiator
    marker use opposite yaw signs at runtime. The installed render, not either
    source transform, rules the end: generator local -x and the prop's marked
    supply end meet on the same side. Writing the opposite sign put the riser
    at the air vent even though both source coordinates looked reasonable.
    """
    for fl in floors:
        if fl["id"] == "ROOF":
            continue
        clear_h = 2.56 if fl["id"] == "B1" else 2.96
        for m in fl["markers"]:
            if m["kind"] != "radiator":
                continue
            fl["furniture"].append({
                "id": m["id"] + "_continuous_supply",
                "asm": "pipe", "at": [m["pos"][0], m["pos"][1]],
                "yaw": m["yaw_deg"], "mat": "metal", "r": 0.022,
                "local": True,
                "p0": [-0.52, 0.0, 0.0], "p1": [-0.52, 0.0, clear_h]})


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


def failed_renovation_pass(floors):
    """A contractor opened the building and then stopped answering.

    Each work wall is three actual layers: brick substrate, broken plaster
    islands proud of it, and wallpaper fragments proud of the plaster. The
    stepped relief catches grazing light; it is not a damage image pasted on
    an otherwise perfect plane. Work zones stay against corridor walls so the
    audited 1.9 m circulation lane remains open.
    """
    by_id = {fl["id"]: fl for fl in floors}
    zones = [
        # floor, wall x, corridor-facing sign, y0, y1
        ("F02", -X_IN, 1, 6.48, 9.18),
        # Major work zones live inside vacant 3C and fire-damaged 5D, where
        # equipment can remain without narrowing an occupied corridor.
        ("F03", X_IN, -1, 1.05, 5.70),
        ("F04", -X_IN, 1, -6.05, -3.00),
        ("F05", X_IN, -1, -6.05, -2.35),
        ("F06", -X_IN, 1, -6.05, -3.00),
    ]
    for zi, (fid, wall_x, face, y0, y1) in enumerate(zones):
        fl = by_id[fid]
        f = fl["furniture"]

        def layer(bid, xa, xb, ya, yb, z0, h, mat):
            f.append({"id": "reno_%s_%s" % (fid, bid),
                      "rect": [xa, ya, xb, yb], "z0": z0,
                      "h": h, "mat": mat})

        brick0 = wall_x + face * 0.094
        brick1 = wall_x + face * 0.112
        layer("brick", min(brick0, brick1), max(brick0, brick1),
              y0, y1, 0.13, 2.72, "brick_patched")
        # Jagged plaster remnants: offset rectangles overlap like irregular
        # surviving islands while leaving most of the brick exposed.
        plaster0 = wall_x + face * 0.114
        plaster1 = wall_x + face * 0.132
        islands = [
            (0.00, 0.20, 0.10, 1.00), (0.13, 0.38, 1.90, 0.82),
            (0.43, 0.61, 0.12, 0.64), (0.57, 0.79, 1.28, 1.48),
            (0.78, 1.00, 0.08, 0.92), (0.84, 1.00, 2.04, 0.74),
        ]
        span = y1 - y0
        for i, (a, b, pz, ph) in enumerate(islands):
            layer("plaster%d" % i, min(plaster0, plaster1),
                  max(plaster0, plaster1), y0 + span * a, y0 + span * b,
                  pz, ph, "plaster_stained")
        # Wallpaper clings only where plaster survived. Narrow loose tails
        # stand progressively farther off the wall like curled paper.
        paper0 = wall_x + face * 0.134
        strips = [
            (0.14, 0.245, 1.98, 0.76, 0.006),
            (0.58, 0.665, 1.34, 1.34, 0.010),
            (0.86, 0.955, 2.07, 0.67, 0.014),
        ]
        for i, (a, b, pz, ph, curl) in enumerate(strips):
            p1 = paper0 + face * curl
            layer("paper%d" % i, min(paper0, p1), max(paper0, p1),
                  y0 + span * a, y0 + span * b, pz, ph,
                  "wallpaper_old")
        # Dust and fallen plaster directly beneath each opened wall.
        floor_x0 = wall_x + face * 0.12
        floor_x1 = wall_x + face * 0.48
        layer("debris", min(floor_x0, floor_x1), max(floor_x0, floor_x1),
              y0 + 0.15, y1 - 0.15, 0.012, 0.025, "plaster_stained")

        # Only two zones still pretend work might resume. Elsewhere the wall
        # was simply opened and abandoned.
        if fid in ("F03", "F05"):
            gear_y = y0 + 0.88
            f.append({"id": "reno_%s_barrier" % fid,
                      "asm": "safety_barrier",
                      "at": [wall_x + face * 0.56, gear_y],
                      "yaw": 90, "z0": 0.02, "W": 1.35})
            f.append({"id": "reno_%s_gear" % fid, "asm": "reno_gear",
                      "at": [wall_x + face * 0.47, y1 - 0.72],
                      "yaw": 90 if face > 0 else -90, "z0": 0.02})
            f.append({"id": "reno_%s_crate" % fid, "asm": "crate",
                      "at": [wall_x + face * 0.40, y1 - 1.58],
                      "yaw": 8, "z0": 0.02, "fill": "paper"})

    # Organic whole-building grime: base damp follows masonry, traffic wear
    # follows circulation, and ceiling blooms follow old wet services.
    for fl in floors:
        if fl["id"] == "ROOF":
            continue
        f = fl["furniture"]
        fid = fl["id"]
        zseed = sum(ord(c) for c in fid)
        for side in (-1, 1):
            x = side * (XCI + 0.012)
            y0 = -5.8 + (zseed % 5) * 0.31
            f.append({"id": "grime_%s_base_%d" % (fid, side),
                      "rect": [x - 0.012, y0, x + 0.012, y0 + 2.1],
                      "z0": 0.08, "h": 0.52, "mat": "fx_damp"})
            f.append({"id": "grime_%s_rub_%d" % (fid, side),
                      "rect": [x - 0.014, y0 + 2.6, x + 0.014, y0 + 4.0],
                      "z0": 0.72, "h": 1.05, "mat": "fx_patch"})
        f.append({"id": "grime_%s_lane" % fid,
                  "rect": [-4.92, -8.85, 4.92, -7.72],
                  "z0": 0.016, "h": 0.002, "mat": "fx_traffic"})
        f.append({"id": "grime_%s_ceiling" % fid,
                  "rect": [-2.1, 4.15, 1.2, 5.55],
                  "z0": 2.985, "h": 0.005, "mat": "fx_damp"})


def building_operations_pass(floors):
    """The unglamorous systems that make a century-old building credible."""
    by_id = {fl["id"]: fl for fl in floors}
    b1, f01 = by_id["B1"], by_id["F01"]

    # A real cellar has its own exterior route. Cut the center of the rear
    # B1 wall before door markers are collected, then build the sunken
    # areaway and stairs up to alley grade.
    rear_y = 10.0 - ext_t("B1") / 2.0
    for w in b1["walls"]:
        if (w["mat"] == "common_brick" and
                abs(w["a"][1] - rear_y) < 0.01 and
                abs(w["b"][1] - rear_y) < 0.01 and
                abs(w["a"][0] + X_IN) < 0.01 and
                abs(w["b"][0] - X_IN) < 0.01):
            w["openings"].append(door(X_IN, DOOR_SERV, "closed", "out"))
            break

    def box(fl, bid, rect, z0, h, mat="concrete"):
        fl["furniture"].append({"id": "ops_%s" % bid,
                                "rect": list(rect), "z0": z0, "h": h,
                                "mat": mat})

    # Areaway cheeks, treads and drain; deliberately offset east so the rear
    # refuse route does not collide with the porch stack.
    box(b1, "areaway_w", (-1.45, 9.82, -1.28, 12.55), 0.0, 2.95)
    box(b1, "areaway_e", (1.28, 9.82, 1.45, 12.55), 0.0, 2.95)
    for i in range(12):
        y0 = 10.12 + i * 0.19
        box(b1, "areaway_step%02d" % i,
            (-1.20, y0, 1.20, y0 + 0.24), i * 0.235, 0.12)
    box(b1, "areaway_drain", (-0.24, 10.02, 0.24, 10.34), 0.015, 0.025,
        "metal")
    box(b1, "areaway_rail_l", (-1.34, 10.0, -1.29, 12.45), 2.82, 0.08,
        "metal")
    box(b1, "areaway_rail_r", (1.29, 10.0, 1.34, 12.45), 2.82, 0.08,
        "metal")

    # Rear and side egress towers. The western rear apartments already have
    # wooden porches, so iron towers serve the east rear and both street
    # apartment stacks without duplicating that silhouette.
    for bid, at, yaw in (
            ("rear_e", [9.2, 10.30], 0),
            ("side_w", [-14.25, -5.15], 90),
            ("side_e", [14.25, -5.15], -90)):
        f01["furniture"].append({"id": "ops_fire_escape_%s" % bid,
                                 "asm": "fire_escape", "at": at,
                                 "yaw": yaw, "z0": 0.0, "levels": 5,
                                 "floor_h": F2F})

    # Lobby paperwork: WITHDRAWN 2026-08-06.
    #
    # Five blank cream slabs of "paper" hung off the lobby wall with
    # nothing printed on them - from the floor they read as four boxes
    # floating in space, which is what they were. The idea is right (a
    # century of required notices layered over each other) and the
    # execution was a placeholder that never got its content.
    #
    # The work-order board in the hall now shows what these should be:
    # aged slips at differing yellows, pinned crooked, on a real ground.
    # They come back when they have something written on them, and not
    # before. See task "Fix the bulletin board texture and reposition it".
    # Entry intercom is a conspicuous later retrofit: metal directory,
    # speaker grille, call buttons and exposed conduit to the ceiling.
    box(f01, "intercom", (3.95, -9.665, 4.43, -9.59), 1.10, 0.74, "metal")
    for i in range(8):
        box(f01, "intercom_button_%d" % i,
            (4.01 + (i % 2) * 0.20, -9.59, 4.06 + (i % 2) * 0.20, -9.57),
            1.18 + (i // 2) * 0.12, 0.045, "brass")
    box(f01, "intercom_conduit", (4.17, -9.65, 4.21, -9.61), 1.84, 1.12,
        "metal")

    # Boiler inspection life: feed tank, gauge bank, tagged valves, chemical
    # bucket and a mineral-ringed floor drain.
    box(b1, "feed_tank", (7.35, 6.55, 8.35, 7.25), 0.10, 1.25, "metal")
    box(b1, "boiler_gauge_board", (8.48, 7.18, 9.52, 7.26), 1.12, 0.72,
        "trim")
    for i in range(3):
        box(b1, "boiler_tag_%d" % i,
            (8.58 + i * 0.28, 7.16, 8.76 + i * 0.28, 7.18),
            1.28, 0.25, "paper")
    box(b1, "chemical_bucket", (7.05, 5.72, 7.42, 6.09), 0.02, 0.42,
        "safety_orange")
    box(b1, "boiler_drain", (8.50, 4.35, 9.08, 4.82), 0.015, 0.025,
        "metal")
    # Chute endpoint and the trip garbage takes to the new cellar door.
    box(b1, "compactor", (1.55, 7.10, 2.85, 8.25), 0.02, 1.35, "metal")
    for i in range(3):
        box(b1, "refuse_bin_%d" % i,
            (-2.85 + i * 0.82, 8.18, -2.18 + i * 0.82, 8.90),
            0.02, 0.92, "metal")

    # Drainage tells the truth about the court: downspouts terminate at a
    # grated sump rather than vanishing into the wall.
    box(b1, "court_sump", (-0.42, 0.70, 0.42, 1.42), 0.012, 0.025, "metal")
    for i, (x, y) in enumerate(((-3.12, -3.0), (3.02, -3.0),
                                (-3.12, 3.0), (3.02, 3.0))):
        b1["furniture"].append({"id": "ops_downspout_%d" % i,
                                "asm": "pipe", "at": [0, 0], "yaw": 0,
                                "z0": 0.0, "p0": [x, y, b1["z"]],
                                "p1": [x, y, LEVELS["ROOF"] + 1.0],
                                "r": 0.055})


## The building's block: a crowded 2027 street on limited land. Sidewalk
## and stoop out front, service alley behind serving the porches and coal
## chute, tight gangways between the neighbors' party walls.
## Extent of the built block. The street used to stop at x = +-20 and the
## vista ran straight out to open sky with the sky dome's distant city
## sitting at the wrong elevation — the single loudest tell that this was a
## set and not a city. The block now runs far enough that the sightline
## dies in masonry long before it reaches the edge.
SITE_X = 62.0
SITE_S = -42.0     # behind the south street wall
SITE_N = 26.0      # back of the alley blocks, north

## THE STREET SECTION, taken from the real thing.
##
## A historic New York rowhouse block is a 60 ft right-of-way: 15 ft of
## sidewalk, 30 ft of roadway, 15 ft of sidewalk. Ours had the north walk
## exactly right at 4.57 m and then lost its nerve completely - the
## roadway measured 2.65 m and the far pavement 0.80 m, so building line
## to building line came to 8.40 m against a real 18.29 m. Less than half
## a street.
##
## Those numbers are not a stylisation, they are impossible: a car is
## 1.8 m wide, so nothing could ever have driven down it, and the far
## pavement was narrower than a doorway. It also quietly broke three
## other things - the lamps are commented "down both pavements" but are
## all on ours because the far one had no room, the traffic signal's
## "mast arm over the road" stops at the kerb, and the potholes are
## crowded into a strip narrower than one car.
##
## Everything south of the kerb now derives from these three figures.
WALK_W = 4.572     # 15 ft, and what the north walk already was
ROAD_W = 9.144     # 30 ft kerb to kerb
KERB_N = -14.75    # north kerb face: the roadway starts here
KERB_S = KERB_N - ROAD_W           # -23.894
WALK_S = KERB_S + 0.15             # south kerb is 150 mm, like the north
BLDG_S = WALK_S - WALK_W           # -28.316, the south building line
ROAD_MID = (KERB_N + KERB_S) * 0.5

## Street-wall blocks: (id, rect, height). Heights step irregularly, since
## a row of equal parapets reads as one extruded shape rather than as
## separate buildings put up in different decades.
## Buildings, not blocks. Every entry now carries a STYLE as well, which
## picks its base stone, its brick and its cornice metal — a street where
## every mass is the same red brick reads as one extrusion however well
## it is stepped.
##
## The south side is not listed here: it is GENERATED, one building per
## shop, by _south_street_wall(). sw1/nbr_s1/nbr_s3/se1 are gone with the
## placeholder they were.
CITY_BLOCKS = [
    # north side (our side), running west from the Orison
    ("nbr_w", (-19.6, -12.0, -15.2, 12.0), 12.8, "brick"),
    ("nw1", (-27.4, -14.2, -20.2, 11.0), 16.4, "limestone"),
    ("nw2", (-36.0, -14.2, -28.0, 9.5), 10.9, "buff"),
    ("nw3", (-47.5, -14.2, -36.6, 12.0), 19.2, "brick"),
    ("nw4", (-58.0, -14.2, -48.1, 10.0), 13.6, "sooted"),
    # north side, running east
    ("nbr_e", (15.2, -12.0, 19.6, 12.0), 12.8, "brick"),
    ("ne1", (20.2, -14.2, 28.8, 11.5), 14.7, "buff"),
    ("ne2", (29.4, -14.2, 37.0, 9.0), 21.5, "limestone"),
    ("ne3", (37.6, -14.2, 48.4, 12.0), 11.2, "sooted"),
    ("ne4", (49.0, -14.2, 58.0, 10.5), 17.8, "brick"),
    # The Harukiya's block keeps its id: retail_pass owns its ground
    # floor and the bar's stair is cut through it.
    ("nbr_s2", (-12.0, -38.2, 6.4, -28.32), 15.8, "sooted"),
    # The far ends of the parade, past the last shop either way.
    ("sw2", (-46.0, -38.0, -33.6, -28.32), 9.8, "buff"),
    ("sw3", (-58.0, -40.4, -46.6, -28.32), 18.5, "limestone"),
    ("se2", (32.6, -39.8, 44.5, -28.32), 20.4, "brick"),
    ("se3", (45.1, -37.4, 58.0, -28.32), 10.2, "sooted"),
    # the vista stops: masses across both ends of the street, as if the
    # road bends behind them. Without these you see sky down the pavement.
    ("end_w", (-62.0, -40.4, -58.6, 14.0), 24.6, "limestone"),
    ("end_e", (58.6, -40.4, 62.0, 14.0), 22.3, "limestone"),
    # behind the alley
    ("back_w", (-30.0, 18.1, -12.0, 24.5), 15.4, "sooted"),
    ("back_e", (12.0, 18.1, 31.0, 24.5), 18.9, "buff"),
]


def _south_street_wall():
    """The parade, as separate buildings — one per shop, plus fillers.

    Tiled west to east so there is no gap for the eye to fall through,
    with each shop's host getting its own depth, storey count and stone.
    A terrace is a row of buildings pretending to be one; this is where
    the pretending stops being a lie.

    Seeded, and the seed is fixed: a regeneration must not reshuffle a
    skyline somebody has learned to navigate by.
    """
    rs = random.Random(19270)
    hosts = []
    for x0, x1, name, trade, _a, _b, _u in SHOPS:
        tag = "".join(c if c.isalnum() else "_"
                      for c in name.lower()).strip("_")
        if SHOP_BLOCK.get(trade) != "shop_%s" % tag:
            continue          # the diner is inside the Harukiya's mass
        hosts.append([x0, x1, "shop_%s" % tag, trade])
    hosts.sort()
    # Close the small joints by growing the neighbour rather than by
    # emitting a 200 mm sliver: a party wall IS the joint.
    for i in range(len(hosts) - 1):
        gap = hosts[i + 1][0] - hosts[i][1]
        if 0.0 < gap < 1.0:
            hosts[i][1] += gap * 0.5
            hosts[i + 1][0] -= gap * 0.5
    out = []
    for x0, x1, bid, trade in hosts:
        sales = SHOP_PLAN.get(trade, (6.0, 0))[0]
        # Back-of-house behind the sales floor: the yard, the stair to
        # the flat above, the WC nobody models. It only has to be deeper
        # than the shop so the shop is never the whole building.
        depth = sales + rs.uniform(2.6, 5.4)
        storeys = rs.choice((2, 3, 3, 4, 4, 5, 6))
        hgt = 6.4 + storeys * 3.35 + rs.uniform(-0.5, 0.9)
        style = rs.choice(("brick", "brick", "buff", "sooted", "limestone"))
        out.append((bid, (x0, SHOP_FACE - depth, x1, SHOP_FACE),
                    round(hgt, 2), style))
    # Fillers for the two real gaps in the row: between the last shop and
    # the Harukiya's block either side. Without them you see straight
    # through the terrace into the site's black.
    for i in range(len(hosts) - 1):
        gap0, gap1 = hosts[i][1], hosts[i + 1][0]
        if gap1 - gap0 < 1.0:
            continue
        # nbr_s2 occupies -12.0..6.4 inside the one large gap in the shop
        # host list.  The old filler bridged straight across that retained
        # block and rebuilt a concrete wall behind the luncheonette door.
        spans = [(gap0, gap1)]
        if gap0 < 6.4 and gap1 > -12.0:
            spans = [(gap0, -12.0), (6.4, gap1)]
        for si, (sx0, sx1) in enumerate(spans):
            if sx1 - sx0 < 0.30:
                continue
            out.append(("fill_%d_%d" % (i, si),
                        (sx0, SHOP_FACE - rs.uniform(7.5, 11.0), sx1,
                         SHOP_FACE), round(9.0 + rs.uniform(0, 9.5), 2),
                        rs.choice(("sooted", "buff", "brick"))))
    return out



## A second ring, further out and much taller. The street-wall row above
## closes the view at pavement level, but the roof is walkable and the
## upper floors have windows — from either you look straight over it into
## the band of black between the block's edge and the sky dome's distant
## city. These fill that band. They are never approached, so they are
## single boxes with lit windows and nothing else.
FAR_SKYLINE = [
    ("far_nw", (-96.0, 30.0, -64.0, 58.0), 38.0),
    ("far_n", (-26.0, 34.0, 14.0, 62.0), 44.0),
    ("far_ne", (44.0, 28.0, 78.0, 56.0), 33.5),
    ("far_e", (74.0, -18.0, 104.0, 16.0), 41.0),
    ("far_se", (52.0, -68.0, 86.0, -40.0), 29.5),
    ("far_s", (-18.0, -78.0, 22.0, -46.0), 46.5),
    ("far_sw", (-88.0, -62.0, -54.0, -38.0), 31.0),
    ("far_w", (-108.0, -20.0, -78.0, 18.0), 36.5),
]


## ===================== THE CITY, BUILT PROPERLY ====================
##
## What was here before was placeholder and said so: one extruded box per
## block, a parapet lip, and a scatter of lit rectangles. It closed the
## sightlines and did nothing else. This is the replacement, and every
## rule in it is a real 1920s New York fact before it is a stylistic one.
##
## THE 1916 ZONING RESOLUTION is the single most important of them and
## the reason a New York skyline of this decade cannot be drawn with
## rectangles. Passed after the Equitable Building threw a seven-acre
## shadow across lower Manhattan in 1915, it defined a SKY EXPOSURE
## PLANE: a building could rise sheer at the street line only to a height
## set by the width of the street it faced, and above that it had to step
## back inside an inclined plane, over and over, as it climbed. A tower
## could go up unrestricted only on a quarter of its lot. That one law
## produced the wedding-cake silhouette that IS New York between the wars
## — every ziggurat setback, every terrace, every stepped crown. A 1927
## street of flat-topped extrusions is not a stylised New York; it is a
## different city.
##
## Under it, the classical tripartite block: a BASE of two or three
## storeys in limestone or cast stone (the part a person touches), a
## plain brick SHAFT, and an ornamented CROWN. Sheet-metal cornices at
## the base line and at every setback. And on the roof, the two things
## every photograph of this city has in it and no render ever remembers:
## a timber water tank on a steel frame (street pressure will not lift
## water past about six storeys) and the brick BULKHEAD over the stair.
##
## AND THEN THE DIVERGENCE. Bible VIII.2: signal technology ran forty to
## sixty years ahead and nothing else moved at all. Forty years past 1927
## is the microwave relay era — so the roofs of this city carry parabolic
## reflectors, horn feeds, guyed lattice masts and beacon lamps, built in
## the only materials this world has (VIII.4: no aluminium, no stainless
## — riveted steel, copper, brass, ceramic and glass). The skyline is
## 1927 masonry wearing 1967 antennas.
##
## The street is strung with it too. Where our cities run power overhead,
## this one runs SIGNAL: trunk catenaries on insulator racks, crossing
## from parapet to parapet, sagging over the roadway. Vantry & Co. built
## the Orison as a demonstration (VIII.3) and they built the network it
## demonstrates; you can see it from every window in the game.
CITY_STYLES = {
    #            base ht  base stone     shaft brick     cornice
    "limestone": (7.4, "limestone", "limestone", "bronze"),
    "brick":     (6.8, "limestone", "common_brick", "bronze"),
    "buff":      (6.2, "concrete", "face_brick", "metal"),
    "sooted":    (5.6, "concrete", "brick_patched", "soot"),
    "plain":     (4.8, "concrete", "common_brick", "metal"),
}
## How much height a building gets before it must step back, and how far
## in each step goes. Real sky-exposure geometry is an inclined plane
## against a lot line; this is that law's SHAPE at the fidelity a scenery
## block needs — step in, carry a cornice at every step, and let the
## stages shorten as they climb, which is what the plane actually does.
SETBACK_RISE, SETBACK_IN = 9.5, 1.15


def _roof_rig(fb, pipe, rng, bid, rect, top, tall):
    """The signal farm on one roof. Bible VIII.2, in steel and copper.

    Not decoration: this is the network the whole game runs on made
    visible. A player who never reads a word of the bible should be able
    to look out of any window and see that this city listens.
    """
    x0, y0, x1, y1 = rect
    cx, cy = (x0 + x1) * 0.5, (y0 + y1) * 0.5
    w, d = x1 - x0, y1 - y0
    # THE MAST. Riveted lattice, guyed to the parapet on three sides —
    # a free-standing tube this slender would not stand, and the guys
    # are most of what reads at distance anyway.
    mh = rng.uniform(6.0, 11.0) if tall else rng.uniform(3.4, 5.6)
    mx = cx + rng.uniform(-w * 0.22, w * 0.22)
    my = cy + rng.uniform(-d * 0.22, d * 0.22)
    pipe("%s_mast" % bid, (mx, my, top), (mx, my, top + mh), 0.055)
    for gi in range(3):
        ga = rng.uniform(0, 6.28) + gi * 2.094
        gx = mx + math.cos(ga) * min(w, d) * 0.40
        gy = my + math.sin(ga) * min(w, d) * 0.40
        pipe("%s_guy%d" % (bid, gi), (mx, my, top + mh * 0.82),
             (gx, gy, top + 0.25), 0.012)
    # THE BEACON. Red, at the top of anything tall enough to be flown
    # into. It is also the only warm point on a dark roof, which is what
    # makes a skyline read as inhabited rather than as a cut-out.
    if tall:
        fb("%s_beacon" % bid, (mx - 0.13, my - 0.13, mx + 0.13, my + 0.13),
           top + mh, 0.22, "lacquer_red")
    # THE T-AERIAL. Two spreaders and a flat top wire with a downlead —
    # the classic long-wave antenna, and the oldest-looking thing up
    # here. Strung the long way across the roof.
    if w > 5.0:
        ay = cy + rng.uniform(-d * 0.3, d * 0.3)
        sx0, sx1 = x0 + 0.8, x1 - 0.8
        for si, sx in ((0, sx0), (1, sx1)):
            pipe("%s_spread%d" % (bid, si), (sx, ay, top),
                 (sx, ay, top + 2.6), 0.032)
        pipe("%s_flattop" % bid, (sx0, ay, top + 2.55),
             (sx1, ay, top + 2.55), 0.014)
        pipe("%s_downlead" % bid, ((sx0 + sx1) * 0.5, ay, top + 2.55),
             ((sx0 + sx1) * 0.5, ay, top + 0.3), 0.012)
    # THE DISH. A parabolic reflector on a steel yoke, aimed at another
    # roof. This is the anachronism doing the heavy lifting — a 1960s
    # object, in 1927, made of spun copper because there is no aluminium
    # to make it out of.
    if tall and rng.random() < 0.72:
        da = rng.uniform(0, 6.28)
        dx = cx + math.cos(da) * w * 0.30
        dy = cy + math.sin(da) * d * 0.30
        dz = top + rng.uniform(1.5, 3.0)
        pipe("%s_dishpost" % bid, (dx, dy, top), (dx, dy, dz), 0.048)
        r = rng.uniform(0.55, 0.95)
        pipe("%s_dish" % bid, (dx, dy, dz), (dx + math.cos(da) * 0.22,
             dy + math.sin(da) * 0.22, dz), r, "bronze")
        # the feed on its tripod arm, out at the focus
        pipe("%s_feed" % bid, (dx, dy, dz),
             (dx + math.cos(da) * (0.22 + r * 0.55),
              dy + math.sin(da) * (0.22 + r * 0.55), dz), 0.05, "brass_dull")
    # THE RELAY HUT. Vantry & Co. plant: a brick shed with a louvre and
    # a cable gland, on about a third of the roofs. The firm stopped
    # existing in 1924 and the huts are all still humming.
    if rng.random() < 0.34 and w > 4.0 and d > 4.0:
        hx = x0 + rng.uniform(0.9, max(1.0, w - 2.4))
        hy = y0 + rng.uniform(0.9, max(1.0, d - 2.4))
        fb("%s_hut" % bid, (hx, hy, hx + 1.5, hy + 1.3), top, 1.9,
           "common_brick")
        fb("%s_hut_lv" % bid, (hx + 0.25, hy - 0.04, hx + 1.25, hy + 0.02),
           top + 1.05, 0.55, "brass_mesh")
        fb("%s_hut_cap" % bid, (hx - 0.1, hy - 0.1, hx + 1.6, hy + 1.4),
           top + 1.9, 0.09, "metal")


def _city_building(fb, pipe, lights, rng, wins, bid, rect, hgt,
                   style="brick", min_z=0.0, holes=()):
    """One New York building: base, setback shaft, crown, roof, aerials.

    `holes` are ground-floor voids (a shop's sales floor) subtracted from
    the base band only — the mass above sits on the brick between them,
    which is how a real terrace of shops carries the storeys over it.
    """
    x0, y0, x1, y1 = rect
    base_h, base_mat, shaft_mat, corn_mat = CITY_STYLES.get(
        style, CITY_STYLES["brick"])
    base_h = min(base_h, hgt - 0.6) if hgt > 2.0 else hgt
    # ---- the base, minus whatever trades out of its ground floor
    band = [rect]
    for hole in holes:
        nxt = []
        for r in band:
            nxt += subtract_rect([r], hole)
        band = nxt
    for i, r in enumerate(band):
        fb("%s_base%d" % (bid, i), r, min_z, base_h - min_z, base_mat)
    if min_z > 0.0:
        # a hollowed ground floor still needs its own soffit to stand on
        fb("%s_soffit" % bid, rect, min_z - 0.22, 0.22, base_mat)
    fb("%s_bcorn" % bid, (x0 - 0.20, y0 - 0.20, x1 + 0.20, y1 + 0.20),
       base_h, 0.34, corn_mat)
    # ---- the shaft, stepping back under the sky exposure plane
    z = base_h + 0.34
    inset = 0.0
    rise = SETBACK_RISE
    stage = 0
    while z < hgt - 0.3 and stage < 5:
        top = min(hgt, z + rise)
        lim = min(x1 - x0, y1 - y0) * 0.5 - 1.2
        inset = min(inset, max(0.0, lim))
        sx0, sy0 = x0 + inset, y0 + inset
        sx1, sy1 = x1 - inset, y1 - inset
        if sx1 - sx0 < 2.4 or sy1 - sy0 < 2.4:
            break
        fb("%s_s%d" % (bid, stage), (sx0, sy0, sx1, sy1), z, top - z,
           shaft_mat)
        # A cornice at every setback, which is what makes the steps read
        # as architecture rather than as a stack of boxes.
        fb("%s_c%d" % (bid, stage),
           (sx0 - 0.16, sy0 - 0.16, sx1 + 0.16, sy1 + 0.16), top, 0.26,
           corn_mat)
        wins.append(((sx0, sy0, sx1, sy1), z, top))
        z = top + 0.26
        inset += SETBACK_IN
        rise *= 0.86
        stage += 1
    # ---- the crown: parapet, stair bulkhead, and the water tank
    lim = min(x1 - x0, y1 - y0) * 0.5 - 1.2
    fin = min(max(0.0, inset - SETBACK_IN), max(0.0, lim))
    tx0, ty0, tx1, ty1 = x0 + fin, y0 + fin, x1 - fin, y1 - fin
    top = max(z, base_h + 0.34)
    for tag, pr in (("n", (tx0 - 0.1, ty1 - 0.18, tx1 + 0.1, ty1 + 0.1)),
                    ("s", (tx0 - 0.1, ty0 - 0.1, tx1 + 0.1, ty0 + 0.18)),
                    ("w", (tx0 - 0.1, ty0, tx0 + 0.18, ty1)),
                    ("e", (tx1 - 0.18, ty0, tx1 + 0.1, ty1))):
        fb("%s_par_%s" % (bid, tag), pr, top, 0.62, corn_mat)
    tw, td = tx1 - tx0, ty1 - ty0
    if tw > 3.4 and td > 3.4:
        bx = tx0 + tw * rng.uniform(0.18, 0.55)
        by = ty0 + td * rng.uniform(0.18, 0.55)
        fb("%s_bulk" % bid, (bx, by, bx + 2.1, by + 1.7), top, 2.5,
           shaft_mat)
        fb("%s_bulk_c" % bid, (bx - 0.12, by - 0.12, bx + 2.22, by + 1.82),
           top + 2.5, 0.16, corn_mat)
    # THE WATER TANK, and it is not optional in this city. Street mains
    # will not lift water past about six storeys, so every building over
    # roughly that height keeps a timber stave tank on a steel frame, and
    # its silhouette is the most recognisable object on any New York
    # roof. A skyline without them is a skyline of somewhere else.
    if hgt > 17.0 and tw > 3.0 and td > 3.0:
        wx = tx1 - tw * rng.uniform(0.22, 0.40)
        wy = ty0 + td * rng.uniform(0.22, 0.55)
        legs, tr = 3.0, rng.uniform(1.15, 1.55)
        for lx, ly in ((-1, -1), (-1, 1), (1, -1), (1, 1)):
            pipe("%s_wleg%d%d" % (bid, lx, ly),
                 (wx + lx * tr * 0.64, wy + ly * tr * 0.64, top),
                 (wx + lx * tr * 0.64, wy + ly * tr * 0.64, top + legs),
                 0.055)
        pipe("%s_wtank" % bid, (wx, wy, top + legs),
             (wx, wy, top + legs + tr * 1.75), tr, "timber")
        pipe("%s_wband" % bid, (wx, wy, top + legs + tr * 0.55),
             (wx, wy, top + legs + tr * 0.70), tr + 0.03, "metal")
        pipe("%s_wcone" % bid, (wx, wy, top + legs + tr * 1.75),
             (wx, wy, top + legs + tr * 2.05), tr * 0.72, "metal")
    _roof_rig(fb, pipe, rng, bid, (tx0, ty0, tx1, ty1), top + 0.62,
              hgt > 15.0)
    return (tx0, ty0, tx1, ty1), top


def subtract_rect(rects, hole):
    """Axis-aligned rect subtraction: rects minus hole, as rect pieces."""
    hx0, hy0, hx1, hy1 = hole
    out = []
    for (x0, y0, x1, y1) in rects:
        if hx1 <= x0 or hx0 >= x1 or hy1 <= y0 or hy0 >= y1:
            out.append((x0, y0, x1, y1))
            continue
        cx0, cx1 = max(x0, hx0), min(x1, hx1)
        if y0 < hy0:
            out.append((x0, y0, x1, hy0))
        if hy1 < y1:
            out.append((x0, hy1, x1, y1))
        if x0 < cx0:
            out.append((x0, max(y0, hy0), cx0, min(y1, hy1)))
        if cx1 < x1:
            out.append((cx1, max(y0, hy0), x1, min(y1, hy1)))
    return out


## THE STREET'S SHOPS.
##
## A New York block does not have one shop on it. It has a continuous
## run of them, five to eight metres of frontage each, sharing party
## walls and arguing about awnings — and the mix is always the same
## because it is what a neighbourhood needs within walking distance:
## somewhere to wash, somewhere to eat standing up, somewhere to get a
## key cut, somewhere to pawn a watch, and somewhere to be buried from.
##
## These run along the SOUTH side, facing the Orison, because that is
## the elevation every resident sees out of every front window — and
## because the Harukiya is already down there, so the bar stops being an
## outpost and becomes the middle of a parade.
##
## Each one is a real 1920s shopfront in section: a stall riser you
## could kick, plate glass, a transom over it, a sign band above that,
## and a door set back far enough to stand in out of the rain. Every one
## gets a gameplay function; nothing here is a painted flat.
## Faces of the shopfronts, in the order a walker meets them going up.
SHOP_FACE = BLDG_S               # the south building line
## THE NORTH SIDE, which is one shop and could never have been more.
## The near pavement runs from nw1's corner at x -20.2 to ne1's at
## +20.2 — both blocks front on y -14.2 and leave 0.40 m of walk, which
## is what ends the world now the scaffolding has gone. The Orison's own
## footprint takes x -14..14 of that, and the bodega has 15.2..19.6. The
## only frontage left on the whole north side is nbr_w's 4.4 m, directly
## west of the Orison's door, and this is it.
BLDG_N = -12.0                   # nbr_w's face; the walk is SOUTH of it
## Clear height inside a shop, and the slab over it. A 1920s retail
## ground floor is TALL — the transom light at 2.45 only makes sense if
## there is ceiling above it to throw light at — and the block above
## these starts at 3.55, so the slab fills 3.30..3.55 exactly.
## How deep each trade's sales floor runs back from the face, and how
## many arcade cabinets it keeps. Depths are the trade's, not a number:
## a news kiosk is a slot you stand in the mouth of, a funeral parlour
## needs a front room you can hold a service in, and a laundry needs the
## length to put the machines down one side and still walk past them.
##
## The block behind each shop is deeper than the depth given, and the
## remainder stays solid brick — that is the back-of-house, the yard and
## the stair to the flat above, and none of it is modelled because none
## of it is enterable.
## Which street block each shop's void is cut out of. Everything on the
## south side sits on one of five masses; only nbr_s2 was already hollow
## at ground level (the Harukiya's street door is in it).
## THE SECOND LINE ON THE BOARD, which is where the period actually
## lives: nobody in 1927 painted SHOE REBUILDING on a fascia without
## also promising it while you wait, and nobody wrote PAWNBROKER when
## they could write LOANS ON EVERYTHING OF VALUE.
SHOP_SUB = {
    "laundry": "HAND WORK  ·  SHIRTS  ·  SAME DAY",
    "cobbler": "REBUILT WHILE YOU WAIT",
    "locksmith": "KEYS  ·  LOCKS  ·  SAFES OPENED",
    "radio": "SETS ALIGNED  ·  TUBES TESTED",
    "diner": "COFFEE  ·  SANDWICHES  ·  PIE",
    "news": "PAPERS  ·  CIGARS  ·  FORM",
    "pawn": "LOANS ON EVERYTHING OF VALUE",
    "funeral": "FUNERAL DIRECTORS  ·  CHAPEL",
    "hardware": "PAINTS  ·  TOOLS  ·  HOUSEHOLD",
    "photo": "FILM  ·  PLATES  ·  DEVELOPING",
    "druggist": "PRESCRIPTIONS  ·  SODA  ·  SUNDRIES",
}
## One word on the blade, because a blade is read at an angle from up
## the street and a sentence on one is a smear.
SHOP_BLADE = {"cobbler": "SHOES", "locksmith": "KEYS", "news": "NEWS",
              "pawn": "LOANS", "hardware": "PAINT"}
## Letter colour. Painted signwriting, so these are pigments a signwriter
## actually had: bone white, a cheap chrome yellow, oxblood, and the one
## green that everybody who could afford it used.
SHOP_LETTER = {
    "laundry": [0.90, 0.91, 0.86], "cobbler": [0.88, 0.72, 0.24],
    "locksmith": [0.86, 0.70, 0.28], "radio": [0.72, 0.86, 0.88],
    "diner": [0.92, 0.90, 0.84], "news": [0.90, 0.62, 0.20],
    "pawn": [0.88, 0.74, 0.30], "funeral": [0.84, 0.84, 0.82],
    "hardware": [0.62, 0.80, 0.58], "photo": [0.82, 0.78, 0.90],
    "druggist": [0.74, 0.90, 0.88],
}
## EVERY SHOP IS ITS OWN BUILDING NOW. It used to be that four long
## scenery slabs (sw1, nbr_s1, nbr_s3, se1) each carried two or three
## shops, and a shop's interior was a hole subtracted out of a shared
## mass — which is why the diner needed a second hole cut in the
## Harukiya's infill and why every shop on a slab had to share one
## height, one depth and one brick. A terrace of shops is a row of
## separate buildings pretending to be one; the pretending is done at
## the cornice line, not in the plan. So the south street wall is
## generated one building per shop (see _south_street_wall), each with
## its own footprint, storey count and stone, and a shop's void is now
## simply its own building's ground floor.
##
## The two that keep their old block are the ones whose ground floor
## belongs to somebody else already: the diner sits in the Harukiya's
## mass and the druggist in nbr_w beside the Orison.
SHOP_BLOCK = {
    "diner": "nbr_s2",
    "druggist": "nbr_w",
}
for _x0, _x1, _nm, _tr, _a, _b, _u in SHOPS:
    SHOP_BLOCK.setdefault(_tr, "shop_%s" % "".join(
        c if c.isalnum() else "_" for c in _nm.lower()).strip("_"))

## Appended here rather than at the table, because the generator reads
## SHOPS, SHOP_PLAN and SHOP_BLOCK and all three are defined below it.
CITY_BLOCKS += _south_street_wall()


def shop_voids():
    """(block id, rect) for every shop's interior, as holes to cut.

    Inset 100 mm each side of the authored bay so neighbours keep
    200 mm of brick between them: a row of shops is a row of separate
    buildings pretending to be one, and the party wall is the only thing
    that says so from inside.
    """
    out = []
    for shops, face, sgn in ((SHOPS, SHOP_FACE, 1), (SHOPS_N, BLDG_N, -1)):
        for x0, x1, _n, trade, _a, _b, _u in shops:
            depth = SHOP_PLAN.get(trade, (6.0, 0))[0]
            # Away from the street either way: the south row's interior
            # runs to -y and the north row's to +y, so the pair comes out
            # of order for one of them and has to be sorted.
            # Storefront trim grows toward the pavement; the sales floor
            # runs the other way.  This sign was once `+`, which cut eleven
            # immaculate voids into the street while leaving the host base
            # solid behind every real door.
            ya, yb = face, face - sgn * depth
            out.append((SHOP_BLOCK[trade],
                        (x0 + 0.10, min(ya, yb), x1 - 0.10, max(ya, yb))))
    return out
SHOP_TRIM = {
    "laundry":  ("plaster_stained", "book_teal"),
    "cobbler":  ("wood_dark", "lacquer_red"),
    "locksmith": ("common_brick", "brass"),
    "radio":    ("wood_dark", "stairwell_teal"),
    "diner":    ("chrome", "lacquer_red"),
    "news":     ("wood_dark", "safety_orange"),
    "pawn":     ("common_brick", "brass_bright"),
    "funeral":  ("limestone", "soot"),
    "hardware": ("wood_dark", "fabric_green"),
    "photo":    ("plaster_stained", "felt_violet"),
    "druggist": ("limestone", "book_teal"),
}


def _storefronts(fb, mk, shops=None, face=None, S=1):
    """One 1920s shopfront per entry, in section.

    Heights are the ones these were actually built to: a 550 mm stall
    riser (kick it and nothing breaks), glass to 2.05, a transom to
    2.45 for light and ventilation, and the sign band above that where
    the whole street competes for attention.
    """
    SILL, GLASS, TRANS, SIGN = 0.55, 2.05, 2.45, 3.10
    # S is which way this row FACES: +1 for the parade on the south side
    # of the street (its walk is to the north, so every offset from the
    # face is +y), -1 for the north side, whose walk is to the south. A
    # rect built from a negative offset comes out with its y pair the
    # wrong way round, so fbn orders it; nothing else in here has to know.
    F = SHOP_FACE if face is None else face
    shops = SHOPS if shops is None else shops

    def fbn(bid, rect, z0, h, mat):
        x0, y0, x1, y1 = rect
        if y0 > y1:
            y0, y1 = y1, y0
        fb(bid, (x0, y0, x1, y1), z0, h, mat)

    for x0, x1, name, trade, awning, blade, _use in shops:
        # Node names carry this straight through to Godot, and a
        # NodePath with punctuation in it is a lookup that fails
        # somewhere unhelpful later. Display name keeps its "&";
        # the id is alphanumerics only.
        tag = "".join(c if c.isalnum() else "_"
                      for c in name.lower()).strip("_")
        body, accent = SHOP_TRIM.get(trade, ("wood_dark", "brass"))
        w = x1 - x0
        # The party walls between neighbours: every shop on a block is a
        # different building pretending to be one.
        for px in (x0, x1 - 0.14):
            fbn("sf_%s_pier%d" % (tag, int(px * 10)),
               (px, F, px + 0.14, F + S * 0.26), 0.0, 4.20, body)
        # Entry, recessed. Set to one side, the way a shop puts its door
        # where it loses the least window.
        dx0 = x0 + (0.55 if trade in ("diner", "news", "photo")
                    else w - 1.45)
        dx1 = dx0 + 0.95
        # THE REVEAL WAS A WALL. It was authored as one box spanning
        # dx0-0.10 .. dx1+0.10 at full height — the entire doorway, filled
        # in solid, which nobody caught because there was nothing behind
        # it to walk into. It is now what it was always meant to be: a
        # jamb each side and a head over, with the opening left open.
        # Fifth door in this file to be authored shut, and the first one
        # that was shut across its whole width.
        for jx0, jname in ((dx0 - 0.10, "w"), (dx1, "e")):
            fbn("sf_%s_jamb_%s" % (tag, jname),
               (jx0, F + S * 0.26, jx0 + 0.10, F + S * 0.42), 0.0, 2.55, body)
        fbn("sf_%s_doorhead" % tag, (dx0, F + S * 0.26, dx1, F + S * 0.42),
           2.10, 0.45, body)
        # HINGE AT THE WEST JAMB, so the marker is dx0 and not the middle
        # of the opening. At yaw 0 the leaf runs from the marker toward
        # +x, which is across the hole rather than into the shop.
        mk.append({"kind": "door", "id": "SITE_SHOP_DOOR_%s" % tag.upper(),
                   "pos": [dx0 if S > 0 else dx1, F + S * 0.34, 0.0], "yaw_deg": 0 if S > 0 else 180, "w": 0.95,
                   "h": 2.10,
                   # The trades that keep the light on keep the door open
                   # with it. The rest you have to push.
                   # The news booth serves through its pavement hatch; this
                   # narrow leaf is the proprietor's door, not a public route.
                   "leaf": ("locked" if trade == "news" else
                            ("open" if trade in ("laundry", "diner")
                             else "closed")),
                   "exterior": True})
        # Stall riser and glass, either side of the door.
        for si, (gx0, gx1) in enumerate(((x0 + 0.14, dx0 - 0.10),
                                         (dx1 + 0.10, x1 - 0.14))):
            if gx1 - gx0 < 0.35:
                continue
            fbn("sf_%s_stall%d" % (tag, si), (gx0, F, gx1, F + S * 0.20),
               0.0, SILL, body)
            fbn("sf_%s_glass%d" % (tag, si), (gx0 + 0.04, F + S * 0.06,
                                             gx1 - 0.04, F + S * 0.12),
               SILL, GLASS - SILL, "glassish")
            # Mullions every 900, because plate glass came in sheets.
            n = max(1, int((gx1 - gx0) / 0.90))
            for m in range(1, n):
                mx = gx0 + (gx1 - gx0) * m / n
                fbn("sf_%s_mull%d_%d" % (tag, si, m),
                   (mx - 0.03, F + S * 0.02, mx + 0.03, F + S * 0.16),
                   SILL, GLASS - SILL, body)
        # Transom over the whole front, then the sign band.
        fbn("sf_%s_transom" % tag, (x0 + 0.14, F + S * 0.02, x1 - 0.14,
                                   F + S * 0.14), GLASS, TRANS - GLASS,
           "glassish")
        fbn("sf_%s_band" % tag, (x0, F - S * 0.04, x1, F + S * 0.22), TRANS,
           SIGN - TRANS, body)
        fbn("sf_%s_sign" % tag, (x0 + 0.22, F + S * 0.20, x1 - 0.22,
                                F + S * 0.26), TRANS + 0.10, 0.46, accent)
        # THE LETTERING, which is a prop rather than geometry because the
        # texture rules forbid words in a generated plate — the most
        # broken rule in the brief, and the reason the fascia boards have
        # been blank since they were built. ShopSignProp hangs real type
        # on this board and on the blade. Facing north at yaw 180, like
        # every other sign on this face.
        # ON THE VALANCE IF THERE IS AN AWNING, on the fascia if not.
        # The first version put every name on the fascia board and the
        # render came back with MODEL LAUNDRY sliced in half — the awning
        # projects 1.3 m over the walk with a valance hanging to 2.36,
        # and from the pavement below that is exactly what it hides. Not
        # a bug in the sign: it is what an awning DOES, and it is the
        # reason real shops with awnings paint the name on the valance
        # and hang a blade for the long view. So do we. (The bodega prop
        # already worked this out for itself; this generalises it.)
        # F + S * 1.60, not 1.50. The valance box spans F+1.52..F+1.58 and
        # the street is to the NORTH, so its outward face is the 1.58
        # one — 1.50 put the lettering behind its own board, where it
        # rendered as nothing at all. Same class of mistake as the phone
        # screen behind its own casing, and caught the same way.
        sign_pos = ([(x0 + x1) * 0.5, F + S * 1.60, 2.50] if awning
                    else [(x0 + x1) * 0.5, F + S * 0.27, TRANS + 0.31])
        mk.append({"kind": "shop_sign",
                   "id": "SITE_SHOP_SIGN_%s" % tag.upper(),
                   "unit": "SITE",
                   "pos": sign_pos, "compact": awning,
                   "yaw_deg": 180 if S > 0 else 0, "text": name,
                   "sub": SHOP_SUB.get(trade, ""),
                   "tint": SHOP_LETTER.get(trade, [0.9, 0.86, 0.74]),
                   "blade_text": SHOP_BLADE.get(trade, "") if blade else "",
                   # Where the blade hangs, in the sign's own local x —
                   # the yaw flips the axis, so this is measured from the
                   # bay centre back toward the pier the bracket is on.
                   "blade_dx": (x0 + x1) * 0.5 - (x0 + 0.46),
                   "half_width": (x1 - x0) * 0.5,
                   "exterior": True})
        # The cornice every one of these has, and the upper wall above.
        fbn("sf_%s_cornice" % tag, (x0 - 0.06, F - S * 0.08, x1 + 0.06,
                                   F + S * 0.30), SIGN, 0.22, body)
        if awning:
            # Canvas, out over the walk, sloping down toward the kerb.
            fbn("sf_%s_awning" % tag, (x0 + 0.16, F + S * 1.55, x1 - 0.16,
                                      F + S * 0.26), 2.62, 0.09,
               "awning_vinyl")
            fbn("sf_%s_awn_val" % tag, (x0 + 0.16, F + S * 1.52, x1 - 0.16,
                                       F + S * 1.58), 2.36, 0.28,
               "awning_vinyl")
            for ax in (x0 + 0.20, x1 - 0.26):
                fbn("sf_%s_awn_arm%d" % (tag, int(ax * 10)),
                   (ax, F + S * 0.26, ax + 0.05, F + S * 1.56), 2.58, 0.05,
                   "metal")
        if blade:
            # A sign hung square to the wall, read from up the street —
            # which is the only way anybody finds a locksmith.
            fbn("sf_%s_blade" % tag, (x0 + 0.42, F + S * 0.28, x0 + 0.50,
                                     F + S * 1.30), 2.70, 0.72, accent)
            fbn("sf_%s_bracket" % tag, (x0 + 0.40, F + S * 0.26, x0 + 0.52,
                                       F + S * 1.32), 3.42, 0.05, "metal")
        # A cellar hatch in the pavement outside every second one: this
        # is how a shop on this street takes a delivery.
        if int(x0) % 2 == 0:
            # Flush iron set into the paving, not a 55 mm trip ledge across
            # the exit path. sidewalk_s finishes at z=0.01.
            fbn("sf_%s_hatch" % tag, (x0 + 0.60, F + S * 0.70, x0 + 1.90,
                                     F + S * 1.60), 0.006, 0.004, "metal")
        # A LAMP OVER EVERY DOOR. A shopfront with no light of its own
        # is a dark wall at night, and this street is only ever seen at
        # night — the first render of the parade was a row of shapes you
        # could not read a sign on.
        mk.append({"kind": "cage_bulb", "id": "SITE_SHOP_LT_%s"
                   % tag.upper(), "unit": "SITE",
                   "pos": [(dx0 + dx1) * 0.5, F + S * 0.46, 2.66],
                   "yaw_deg": 0, "network": "electrical", "range": 4.2,
                   "energy": 0.55, "navigation": False,
                   "standby": 0.30, "exterior": True})
        # And the window is lit from within. The LINEN PANEL IS GONE: it
        # was a lit rectangle standing in the glass line faking a room,
        # and now that there is a room it was standing in the middle of
        # it — across the doorway, in front of the fittings, exactly the
        # sort of scenery that becomes a wall the moment somewhere gets
        # built behind it. The light survives, moved back inside where it
        # is now lighting an actual interior; a laundry at three in the
        # morning is still the warmest thing on the block, but it is warm
        # because you can see into it.
        depth = SHOP_PLAN.get(trade, (6.0, 0))[0]
        # A RUN OF THEM DOWN THE SHOP, not one at the window. The first
        # attempt hung two — front and back — at the energies the street
        # lamps use, and the renders came back navy: a 5 x 7 m room with
        # a 3.3 m ceiling swallows a 0.6 lamp, and what you saw from the
        # pavement was a lit mouth and a black throat with a glowing bulb
        # floating in it. One every 2.4 m, and brighter, because these
        # rooms are the only warm thing on a street the player only ever
        # sees at night — and because a shop you can see into is the
        # entire reason the interiors were built.
        #
        # The trades that keep the light on burn brighter than the ones
        # shut for the night, which is the whole difference between the
        # laundry at 3 a.m. and the funeral parlour at any hour.
        openish = trade in ("laundry", "diner", "news", "pawn")
        runs = max(2, int(round(depth / 2.4)))
        for li in range(runs):
            ly = F - S * 0.95 - li * (depth - 1.9) / max(1, runs - 1)
            mk.append({"kind": "cage_bulb",
                       "id": "SITE_SHOP_IN%d_%s" % (li, tag.upper()),
                       "unit": "SITE",
                       "pos": [(x0 + x1) * 0.5, ly, 2.92],
                       "yaw_deg": 0, "network": "electrical",
                       "range": 5.2,
                       # The window lamp leads, so the front of the shop
                       # is what reads from across the road.
                       "energy": (0.98 if openish else 0.74) if li == 0
                                 else (0.80 if openish else 0.58),
                       "navigation": False,
                       "standby": 0.40 if openish else 0.22,
                       "exterior": True})


## What is underfoot and overhead in each trade. Pressed tin went into
## anything that wanted to look like a going concern in 1927; the ones
## that get plaster are the ones nobody has spent money on since the war.




def site_pass(fl):
    """The block the Orison stands in. Everything here is scenery — it
    exists to close sightlines and to make the building feel surrounded,
    so it is deliberately cheap: boxes, and lit window rectangles that are
    data rather than lights."""
    furn = fl["furniture"]
    rng = random.Random(1927)
    lights = []

    def fb(bid, rect, z0, h, mat):
        furn.append({"id": "site_" + bid, "rect": list(rect), "z0": z0,
                     "h": h, "mat": mat})

    def asm(bid, kind, x, y, yaw=0, **kw):
        # exterior: True keeps these off the storey gate the same way the
        # street furniture and the retail assemblies are — the site floor
        # is not a storey and a shop fitting has no business being
        # switched off by one.
        e = {"id": "site_" + bid, "asm": kind, "at": [x, y], "yaw": yaw,
             "exterior": True}
        e.update(kw)
        furn.append(e)

    def pipe(bid, p0, p1, r, mat="metal"):
        # Masts, guys, water-tank legs and the trunk cables. Everything
        # on a roof that is a line rather than a box.
        furn.append({"id": "site_" + bid, "asm": "pipe",
                     "at": [p0[0], p0[1]], "yaw": 0, "mat": mat,
                     "p0": list(p0), "p1": list(p1), "r": r})

    ## Where each finished stage wants its lit windows. Collected as the
    ## masses are built and drawn afterwards, because a setback's windows
    ## belong to the stage's OWN rect — painted on the base footprint they
    ## hang in the air beside a building that has stepped away from them.
    wins = []

    # The road surface is laid AROUND the building, never under it. As one
    # slab it ran clean through the footprint 20 mm below the lobby floor,
    # which put a 220 x 148 m lid over the atrium well and the whole
    # basement: from the lobby you looked down the eye and hit tarmac
    # instead of B1, and the light court's bottom two storeys were sealed
    # off. The building brings its own ground — the B1 slab — so the four
    # bands below tile the site with the footprint left out.
    gx0, gy0, gx1, gy1 = -112.0, -82.0, 108.0, 66.0
    bx0, by0, bx1, by1 = -14.0, -10.0, 14.0, 10.0
    # TWO holes now, not one. The bands were authored around a single
    # footprint (the Orison brings its own ground), and when the Harukiya
    # dug its stairwell through the south block nobody told the ground:
    # a flat asphalt lid ran straight across the open shaft at grade, the
    # descent descended into the underside of the street, and the whole
    # basement was sealed under a plane nobody could see the top of.
    # Ground is subtracted per hole like the road around the building -
    # anything that opens the earth must register here.
    GROUND_HOLES = [(bx0, by0, bx1, by1),
                    (4.30, -35.80, 5.45, -28.32)]     # Harukiya shaft
    ground = [(gx0, gy0, gx1, gy1)]
    for hole in GROUND_HOLES:
        nxt = []
        for r in ground:
            nxt += subtract_rect([r], hole)
        ground = nxt
    for gi, rect in enumerate(ground):
        fb("ground_%d" % gi, rect, -0.30, 0.28, "asphalt")
    # The distant pavement can stay cheap, but the playable frontage is
    # individually poured slabs with settlement, missing corners and open
    # joints. Their top heights vary by centimetres, not a noisy normal map.
    fb("sidewalk_w", (-SITE_X, -14.6, -16.0, -10.0), -0.02, 0.03,
       "concrete")
    fb("sidewalk_e", (16.0, -14.6, SITE_X, -10.0), -0.02, 0.03,
       "concrete")
    slab_rng = random.Random(192703)
    slab_i = 0
    # One continuous recessed joint bed sits below the individual pieces.
    # It is visible only through their authored gaps and missing corners,
    # so texture and geometry can never disagree about where a joint is.
    fb("sidewalk_joint_bed", (-16.0, -14.60, 16.0, -9.98),
       -0.036, 0.022, "sidewalk_grout")
    # The real module. New York sidewalk flags are scored in 5-foot
    # squares, and this walk is 4.57 m from building line to curb -
    # which is three of them, near enough exactly. It was previously two
    # rows of 2.25 m, a size no city ever poured, and the slabs read as
    # oblong panels rather than as pavement.
    FLAG = 1.524                       # 5 ft
    rows = [(-14.58 + i * FLAG, -14.58 + (i + 1) * FLAG) for i in range(3)]
    # Sidewalks are laid with a cross-fall to the gutter, about 1.5%, so
    # water leaves rather than stands against the building. Over three
    # flags that is a couple of centimetres a row - invisible as a slope,
    # readable as the reason the near row is the one that puddles.
    row_fall = (-0.021, -0.010, 0.0)
    for row, (sy0, sy1) in enumerate(rows):
        base = row_fall[row]
        x = -16.0
        while x < 16.0:
            # Flags are cut to a module; the variation in a real walk
            # comes from replacement pieces and settlement, not from
            # every slab being a different size. Hence a tight jitter.
            w = FLAG + slab_rng.uniform(-0.035, 0.035)
            gap = slab_rng.uniform(0.020, 0.052)
            lift = base + slab_rng.uniform(-0.016, 0.032)
            if abs(x + w * 0.5) < 2.2:  # usable route to the front door
                lift = min(lift, base + 0.012)
            # Every seventh slab has a missing corner represented by two
            # physical pieces and a dark socket down to the old base.
            if slab_i % 7 == 3:
                notch = min(0.40, w * 0.28)
                fb("sidewalk_%d_a" % slab_i,
                   (x + gap, sy0 + gap, x + w - notch, sy1 - gap),
                   -0.025 + lift, 0.055, "sidewalk_haunted")
                fb("sidewalk_%d_b" % slab_i,
                   (x + w - notch, sy0 + gap, x + w - gap,
                    sy1 - FLAG * 0.30), -0.025 + lift + 0.008, 0.047,
                   "sidewalk_haunted")
            else:
                fb("sidewalk_%d" % slab_i,
                   (x + gap, sy0 + gap, x + w - gap, sy1 - gap),
                   -0.025 + lift, 0.055, "sidewalk_haunted")
            x += w
            slab_i += 1
    # The ironwork a 1926 pavement over a coal vault actually carried.
    # All of it sits in the row nearest the building line, because that
    # is where the vault is: the cellar reaches out under the walk, and
    # everything here is a hole into it that somebody had to be able to
    # open.
    # z0 sits these AT the walking surface, not at the slab datum. The
    # flags are 55 mm pieces laid at -0.025 plus their own settlement, so
    # their top face lands around +0.03 to +0.06; ironwork built at the
    # datum finished BELOW the pavement and was simply buried by it.
    WALK_TOP = 0.052
    _asm(furn, "walk_vault_lights", "vault_lights", -2.60, -10.72,
         0, z0=WALK_TOP, exterior=True, W=2.60, D=1.15)
    _asm(furn, "walk_vault_lights_e", "vault_lights", 4.10, -10.72,
         0, z0=WALK_TOP, exterior=True, W=1.85, D=1.15)
    _asm(furn, "walk_coal_chute", "coal_chute", 1.35, -10.62, 0,
         z0=WALK_TOP, exterior=True, R=0.235)
    _asm(furn, "walk_valve_water", "utility_cover", -6.55, -11.30, 0,
         z0=WALK_TOP, exterior=True, S=0.15)
    _asm(furn, "walk_valve_gas", "utility_cover", 6.90, -12.05, 0,
         z0=WALK_TOP, exterior=True, S=0.12)
    fb("sidewalk_s", (-SITE_X, BLDG_S, SITE_X, WALK_S), -0.02, 0.03,
       "concrete")
    fb("curb_w", (-SITE_X, -14.75, -16.0, -14.60), -0.02, 0.14,
       "concrete")
    fb("curb_e", (16.0, -14.75, SITE_X, -14.60), -0.02, 0.14,
       "concrete")
    for i in range(16):
        cx0 = -16.0 + i * 2.0 + 0.025
        cz = (-0.018, -0.006, 0.012, -0.011)[i % 4]
        fb("curb%d" % i, (cx0, -14.75, cx0 + 1.94, -14.60),
           cz, 0.14, "concrete")
    fb("curb_s", (-SITE_X, KERB_S, SITE_X, WALK_S), -0.02, 0.14,
       "concrete")
    # 3.4 m was under 11 ft - too tight for the delivery truck the
    # coal chute and the porches imply. 4.9 m is 16 ft, a real
    # service alley.
    fb("alley", (-20.0, 10.0, 20.0, 14.9), -0.02, 0.015, "concrete")
    fb("garages", (-16.0, 14.9, 16.0, 17.5), 0.0, 3.0, "common_brick")
    # centre line, so the road reads as a road
    for i in range(int(SITE_X * 2 / 3.0)):
        cx = -SITE_X + i * 3.0
        fb("centreline%d" % i, (cx, ROAD_MID - 0.05, cx + 1.6,
                                ROAD_MID + 0.05), 0.0, 0.006, "linen")

    # Two blocks carry playable retail in their ground floor, so their
    # mass starts above it; retail_pass() supplies the shell below.
    HOLLOW = {"nbr_e": 3.55, "nbr_s2": 3.55}
    # Each shop's sales floor is a hole in its host building's ground
    # floor. On the south side the host IS the shop's own building now,
    # so the hole is simply that building's ground storey; the two that
    # share a mass with somebody else (the diner in the Harukiya, the
    # druggist in nbr_w) are the only ones still genuinely subtracting.
    voids = {}
    for block_id, rect in shop_voids():
        voids.setdefault(block_id, []).append(rect)
    # Every roof's finished top, kept so the trunk cables can be strung
    # between real parapets rather than at a guessed height.
    roofs = {}
    for bid, rect, hgt, style in CITY_BLOCKS:
        top_rect, top_z = _city_building(
            fb, pipe, lights, rng, wins, bid, rect, hgt, style,
            min_z=HOLLOW.get(bid, 0.0), holes=voids.get(bid, ()))
        roofs[bid] = (top_rect, top_z)
    for rect, z0, z1 in wins:
        _city_windows(fb, lights, rng, "st", rect, z1, min_z=z0)
    wins.clear()

    # ---- THE TRUNK ROUTE, and this is the thing that makes it a radio
    # punk city rather than a 1927 one. Where our streets are strung with
    # power, this one is strung with SIGNAL: Vantry & Co. trunk cable on
    # insulator racks, parapet to parapet, sagging over the roadway. It
    # is the network the whole game runs on, drawn where a player cannot
    # help seeing it. Bible VIII.3 — the firm stopped existing in 1924
    # and none of this has been touched since.
    #
    # Sagged as three chords rather than a curve, because at this
    # distance a catenary and a three-segment polyline are the same
    # picture and one of them is nine vertices.
    for i, (nb, sb) in enumerate((("nw1", "shop_shoe_rebuilding"),
                                  ("nbr_w", "shop_keys_cut"),
                                  ("nbr_e", "shop_pawnbroker"),
                                  ("ne1", "shop_hardware_paint"))):
        if nb not in roofs or sb not in roofs:
            continue
        (nr, nz), (sr, sz) = roofs[nb], roofs[sb]
        nx = (nr[0] + nr[2]) * 0.5
        sx = (sr[0] + sr[2]) * 0.5
        n_y, s_y = nr[1] - 0.2, sr[3] + 0.2
        for k in range(3):
            # A rack of three cables, spaced on the insulator crossarm.
            off = (k - 1) * 0.34
            ax, ay, az = nx + off, n_y, nz + 1.15
            bx_, by_, bz = sx + off, s_y, sz + 1.15
            sag = 2.4 + k * 0.12
            mid = ((ax + bx_) * 0.5, (ay + by_) * 0.5,
                   (az + bz) * 0.5 - sag)
            q1 = ((ax + mid[0]) * 0.5, (ay + mid[1]) * 0.5,
                  (az + mid[2]) * 0.5 - sag * 0.28)
            q3 = ((bx_ + mid[0]) * 0.5, (by_ + mid[1]) * 0.5,
                  (bz + mid[2]) * 0.5 - sag * 0.28)
            for j, (p, q) in enumerate((((ax, ay, az), q1), (q1, mid),
                                        (mid, q3), (q3, (bx_, by_, bz)))):
                pipe("trunk%d_%d_%d" % (i, k, j), p, q, 0.020)
        # The rack itself, both ends: a crossarm on a post with three
        # insulators, which is what a cable of this weight terminates on.
        for tag, (rx, ry, rz) in (("n", (nx, n_y, nz)), ("s", (sx, s_y, sz))):
            pipe("trunkpost%d_%s" % (i, tag), (rx, ry, rz),
                 (rx, ry, rz + 1.30), 0.06)
            pipe("trunkarm%d_%s" % (i, tag), (rx - 0.52, ry, rz + 1.15),
                 (rx + 0.52, ry, rz + 1.15), 0.045)
            for k in range(3):
                ix = rx + (k - 1) * 0.34
                pipe("trunkins%d_%s%d" % (i, tag, k), (ix, ry, rz + 1.15),
                     (ix, ry, rz + 1.30), 0.075, "milk_glass")

    # THE FAR RING gets the same law. These are never approached, so they
    # were single boxes with a cap — which is exactly the silhouette the
    # 1916 resolution makes impossible, and the silhouette is the ONLY
    # thing they contribute. Stepped, crowned and masted, they are the
    # skyline; flat, they are a wall with windows painted on it.
    for bid, rect, hgt in FAR_SKYLINE:
        _city_building(fb, pipe, lights, rng, wins, bid, rect, hgt,
                       "limestone" if hgt > 40.0 else "brick")
    for rect, z0, z1 in wins:
        _city_windows(fb, lights, rng, "far", rect, z1, storey=3.8,
                      min_z=z0)
    wins.clear()

    _street_furniture(fb, rng)

    # Modeled asphalt repairs and potholes in the playable street. The old
    # road remains below as substrate; these shallow pieces create edges that
    # catch rain and headlights. A repeating heave subtly aims at the Orison.
    # Spread across the WHOLE carriageway now. These were bunched into
    # y -15.8..-17.3, which was the entire road when the road was 2.65 m
    # wide; on a real 9 m street that reads as damage confined to a
    # single stripe down the middle.
    for i, (px, py, pw, pd) in enumerate((
            (-12.4, -17.4, 3.7, 1.3), (-6.1, -21.2, 2.4, 0.9),
            (3.4, -16.2, 4.2, 1.5), (9.8, -22.0, 2.8, 1.1),
            (-1.8, -19.4, 3.1, 1.2), (14.6, -18.1, 2.2, 0.9))):
        fb("road_patch%d" % i, (px, py, px + pw, py + pd),
           0.001 + (i % 2) * 0.006, 0.018, "wet_asphalt")
    for i, (px, py) in enumerate(((-8.3, -16.4), (6.6, -21.6),
                                   (13.2, -18.9), (-3.9, -22.4))):
        # Four broken rim pieces around a depressed, water-holding center.
        fb("pothole%d_n" % i, (px - 0.62, py + 0.30, px + 0.62, py + 0.48),
           0.004, 0.026, "asphalt")
        fb("pothole%d_s" % i, (px - 0.62, py - 0.48, px + 0.62, py - 0.30),
           0.002, 0.021, "asphalt")
        fb("pothole%d_w" % i, (px - 0.65, py - 0.30, px - 0.43, py + 0.30),
           0.003, 0.025, "asphalt")
        fb("pothole%d_e" % i, (px + 0.43, py - 0.30, px + 0.65, py + 0.30),
           0.006, 0.028, "asphalt")
        fb("pothole%d_water" % i,
           (px - 0.44, py - 0.31, px + 0.44, py + 0.31),
           0.001, 0.003, "puddle")
    # water tower on a tall neighbour: the silhouette that says American
    # city more economically than any amount of facade detail
    for tid, (tx, ty), base in (("wt_e", (33.2, -21.4), 20.4),
                                ("wt_w", (-41.5, 4.2), 19.2)):
        for lx in (tx, tx + 2.6):
            for ly in (ty, ty + 2.6):
                fb("%s_leg_%d_%d" % (tid, int(lx * 10), int(ly * 10)),
                   (lx, ly, lx + 0.18, ly + 0.18), base, 3.2, "timber")
        fb(tid + "_tank", (tx - 0.5, ty - 0.5, tx + 3.3, ty + 3.3),
           base + 3.2, 4.1, "timber")
        fb(tid + "_roof", (tx - 0.8, ty - 0.8, tx + 3.6, ty + 3.6),
           base + 7.3, 0.5, "metal")
    fl["site_lights"] = lights


## Lit windows on the neighbours, as DATA. Godot turns each into one
## unshaded quad — the same trick the Orison's own windows use. Real lights
## here would be dozens of omnis competing for the per-object cap the
## LightRig exists to ration, to light rooms nobody can enter.
def _city_windows(fb, lights, rng, bid, rect, hgt, storey=3.4,
                  min_z=0.0):
    x0, y0, x1, y1 = rect
    # yaw turns the lit face OUT of its own wall. Godot applies
    # rotation.y = -yaw, and a quad's face is +Z: south wall keeps 0, north
    # needs 180. Having these two swapped pointed every street-facing
    # window on the far pavement back into its own brickwork, which is
    # exactly as dark as having placed none at all.
    off = 0.06
    for face, along0, along1, cross, yaw in (
            ("s", x0, x1, y0 - off, 0), ("n", x0, x1, y1 + off, 180),
            ("w", y0, y1, x0 - off, 90), ("e", y0, y1, x1 + off, -90)):
        span = along1 - along0
        n = int(span / 3.1)
        if n < 1:
            continue
        for row in range(max(1, int((hgt - 2.2) / storey))):
            z = 2.0 + row * storey
            if z + 1.5 > hgt:
                break
            if z < min_z:
                # Retail hollowed this block's ground floor; painting the
                # fake lit-window quads over a real storefront hung two
                # glowing phantom windows in front of the bar's actual
                # glass. The fakes start above the real thing.
                continue
            for i in range(n):
                a = along0 + (i + 0.5) * span / n
                horiz = face in ("s", "n")
                px, py = (a, cross) if horiz else (cross, a)
                # a facade is not a switchboard: most windows are dark, and
                # the lit ones cluster because people share a floor
                on = rng.random() < (0.46 if row % 2 == 0 else 0.30)
                if not on:
                    continue
                lights.append({
                    "pos": [round(px, 3), round(py, 3), round(z, 3)],
                    # a touch under a real sash, since a flat lit rectangle
                    # with no frame reads larger than the opening it stands for
                    "size": [1.05, 1.35], "yaw": yaw,
                    "warm": rng.random() < 0.78,
                    "energy": round(rng.uniform(0.55, 1.5), 2)})


## The storm has passed; the street is still wet and still covered in what
## the wind took down. Everything here is flat geometry on the ground —
## the moving part (drizzle, gusts, falling leaves) is particles in Godot,
## because those have to follow the camera and these have to stay put.
def storm_pass(fl):
    furn = fl["furniture"]
    rng = random.Random(1931)

    def fb(bid, rect, z0, h, mat, batch=None, **meta):
        entry = {"id": "storm_" + bid, "rect": list(rect), "z0": z0,
                 "h": h, "mat": mat}
        # Static shop ownership survives into Blender explicitly.  Parsing
        # `storm_shop_*` fails as soon as a trade name contains an underscore,
        # and `site_shop_*` is host-building geometry rather than an interior.
        if batch:
            entry["batch"] = batch
        entry.update(meta)
        furn.append(entry)

    def asm(bid, kind, x, y, yaw=0, **kw):
        # The shopfronts and their interiors are built here rather than in
        # site_pass, which is where the blocks they are cut into are
        # built. That split is historical and slightly silly, but the two
        # passes write to the SAME floor, so a fitting authored here lands
        # in the void carved there. exterior: True keeps these off the
        # storey gate, like every other site assembly.
        e = {"id": "storm_" + bid, "asm": kind, "at": [x, y], "yaw": yaw,
             "exterior": True}
        e.update(kw)
        furn.append(e)

    # Sheets of wet across the road and pavement, at slightly different
    # heights so they never z-fight each other. Broken up rather than one
    # even coat: water pools where the camber and the kerb put it.
    for i in range(26):
        wx = rng.uniform(-58.0, 58.0)
        ww = rng.uniform(4.0, 13.0)
        band = rng.choice([(-18.1, -14.7), (-14.55, -10.1),
                           (-18.1, -14.7)])
        wy0 = rng.uniform(band[0], band[1] - 1.2)
        fb("wet%d" % i, (wx, wy0, wx + ww, wy0 + rng.uniform(1.0, 3.0)),
           0.004, 0.002, "wet_asphalt")
    # Puddles proper: the gutter line holds most of them, because that is
    # where a crowned road sends its water.
    for i in range(34):
        gutter = rng.random() < 0.62
        px = rng.uniform(-58.0, 58.0)
        if gutter:
            py = rng.uniform(-14.95, -14.45)
            pw, pd = rng.uniform(1.4, 4.6), rng.uniform(0.5, 1.1)
        else:
            py = rng.uniform(-17.9, -10.4)
            pw, pd = rng.uniform(0.8, 2.8), rng.uniform(0.5, 1.6)
        if abs(px) < 2.6 and py > -13.6:
            continue          # the stoop approach stays walkable and dry
        fb("pud%d" % i, (px, py, px + pw, py + pd), 0.006, 0.002, "puddle")
    # Leaf litter, heaviest against the kerb and the building line where
    # the wind stacked it.
    for i in range(150):
        against_wall = rng.random() < 0.45
        lx = rng.uniform(-58.0, 58.0)
        ly = rng.uniform(-10.55, -10.05) if against_wall \
            else rng.uniform(-17.8, -10.2)
        s = rng.uniform(0.10, 0.22)
        fb("leaf%d" % i, (lx, ly, lx + s, ly + s * rng.uniform(0.6, 1.0)),
           0.010, 0.003, "leaf_fall")
    # Drifts: where litter has actually piled, a leaf is a lump not a decal
    for i in range(12):
        dx = rng.uniform(-52.0, 52.0)
        dy = rng.choice([-14.5, -10.35])
        fb("drift%d" % i, (dx, dy, dx + rng.uniform(0.9, 2.4),
           dy + rng.uniform(0.25, 0.5)), 0.008, rng.uniform(0.03, 0.07),
           "leaf_fall")
    # What the wind took down: a branch across the pavement, a bin over on
    # its side with its lid away from it, and a folded-out umbrella in the
    # gutter. Storm damage is specific or it reads as set dressing.
    fb("branch", (-9.4, -12.9, -6.2, -12.66), 0.012, 0.10, "timber")
    fb("branch_fork", (-7.6, -12.85, -6.9, -12.2), 0.012, 0.07, "timber")
    fb("twig1", (11.2, -11.6, 12.1, -11.5), 0.010, 0.05, "timber")
    fb("twig2", (-21.4, -13.2, -20.5, -13.05), 0.010, 0.05, "timber")
    # Blown against the kerb, NOT across the bodega's door. It used to
    # lie at x 18.6-19.7, which is squarely in front of the only way into
    # a shop that trades 24 hours and takes a third of the night
    # schedule's traffic. Storm damage should cost the street some
    # charm, not close a business.
    fb("bin_down", (16.05, -14.15, 17.15, -13.10), 0.0, 0.62, "metal")
    fb("bin_lid", (20.3, -12.9, 20.95, -12.3), 0.008, 0.05, "metal")
    fb("umbrella_canopy", (-16.8, -14.9, -15.7, -14.35), 0.01, 0.16,
       "fabric_cool")
    fb("umbrella_shaft", (-15.75, -14.66, -14.9, -14.6), 0.02, 0.03,
       "metal")
    # Wet still coming off the building: a dark run below each downpipe
    for i, dx in enumerate((-13.4, 13.2)):
        fb("downrun%d" % i, (dx, -10.5, dx + 0.5, -10.05), 0.005, 0.002,
           "wet_asphalt")

    _storefronts(fb, fl["markers"])
    # Street geography is explicit; the extracted module never imports us.
    build_shop_interiors(fb, fl["markers"], asm, SHOPS, SHOP_FACE, 1)
    # The near side, facing the other way (S = -1). One shop, because
    # one is all the north side has room for — see SHOPS_N.
    _storefronts(fb, fl["markers"], SHOPS_N, BLDG_N, -1)
    build_shop_interiors(fb, fl["markers"], asm, SHOPS_N, BLDG_N, -1)


## The light court's centrepiece. The stair used to be lit by seven
## separate globes on long drops down the eye, which read as seven
## unrelated fittings rather than as one idea. This is a single fluted
## column standing the full height of the court, from the basement floor to
## the skylight, with the light built INTO it: a continuous glazed slot up
## each face, and a brighter luminous band at every landing level. From the
## lobby you look up one lit object; from any deck you are beside it.
##
## It is emitted per floor slice so the floor-visibility streaming still
## works — a single 24 m prop filed under one storey would vanish with it.


## Tenants' roof: a sheltered lounge deck on the lee side of the monitor
## and a planted garden along the parapet. Deliberately modest and a bit
## improvised — this is a 1927 block whose residents colonised the roof,
## not a developer's amenity terrace.
def _roof_programme(furniture, markers, z):
    def fb(bid, rect, z0, h, mat):
        furniture.append({"id": "roof_" + bid, "rect": list(rect),
                          "z0": z0, "h": h, "mat": mat})

    # decking east of the monitor, out of the prevailing wind
    fb("deck", (4.6, -6.4, 12.6, 2.2), 0.0, 0.06, "timber")
    for i in range(17):     # board joints, so it is not one flat plane
        fb("deck_joint%d" % i, (4.6 + i * 0.5, -6.4, 4.64 + i * 0.5, 2.2),
           0.06, 0.004, "wood_dark")
    # pergola over half of it: four posts, beams, and slats casting a
    # ladder of shadow that tells you the moon is up
    for px, py in ((5.0, -6.0), (11.9, -6.0), (5.0, 0.9), (11.9, 0.9)):
        fb("perg_post_%d_%d" % (int(px * 10), int(py * 10)),
           (px, py, px + 0.12, py + 0.12), 0.06, 2.42, "timber")
    for py in (-6.0, 0.9):
        fb("perg_beam_%d" % int(py * 10), (4.94, py, 12.08, py + 0.12),
           2.48, 0.14, "timber")
    for i in range(13):
        sy = -5.9 + i * 0.58
        fb("perg_slat%d" % i, (5.0, sy, 12.0, sy + 0.07), 2.62, 0.05,
           "timber")
    # seating: a bench along the parapet, two chairs and a low table
    _asm(furniture, "roof_bench", "bench", 8.6, 1.55, 180, z0=0.06, L=2.2)
    chair_box(furniture, "roof_chair1", 6.0, -4.3, "n")
    chair_box(furniture, "roof_chair2", 7.3, -4.3, "n")
    _asm(furniture, "roof_table", "coffee", 6.75, -3.35, 0, z0=0.06)
    _asm(furniture, "roof_crate", "crate", 11.6, -5.4, 12, z0=0.06,
         fill="soot")
    # string lights along the pergola, drooping between the beams
    for i in range(9):
        lx = 5.2 + i * 0.85
        fb("string%d" % i, (lx, -3.0, lx + 0.55, -2.97),
           2.44 - (0.06 if i % 2 else 0.0), 0.02, "metal")
    # ---- the garden: raised beds along the north and west parapets,
    # tomatoes and beans on canes, a water butt off the tank overflow
    for i, (bx, by, bw, bd) in enumerate((
            (-12.4, 7.4, 6.4, 1.5), (-4.6, 7.4, 5.2, 1.5),
            (-13.0, -2.2, 1.5, 6.6))):
        fb("bed%d" % i, (bx, by, bx + bw, by + bd), 0.0, 0.42, "timber")
        fb("bed%d_soil" % i, (bx + 0.08, by + 0.08, bx + bw - 0.08,
           by + bd - 0.08), 0.40, 0.05, "soil")
    for i in range(9):
        px = -12.0 + i * 0.72
        # north bed: tomatoes, with a sunflower at each end because
        # somebody always puts one in
        plant_box(furniture, "roof_veg%d" % i, px, 7.75,
                  big=(i % 3 == 0),
                  species="sunflower" if i in (0, 8) else "tomato")
    for i in range(6):
        px = -4.2 + i * 0.8
        # east bed, by the stair door: herbs and a geranium, the things
        # you step out for without putting a coat on
        plant_box(furniture, "roof_veg_e%d" % i, px, 7.8,
                  big=(i % 2 == 0),
                  species="geranium" if i % 3 == 1 else "herb")
    for i in range(7):
        py = -1.8 + i * 0.85
        # west bed: the beans that already have canes over them, and a
        # fig in the corner that somebody is determined to overwinter
        plant_box(furniture, "roof_veg_w%d" % i, -12.6, py,
                  big=(i % 3 == 1),
                  species="fig" if i == 6 else "beans")
    # The kit that says somebody tends it. There is no tap on this roof;
    # everything in these beds was carried up the stair in that can.
    _asm(furniture, "roof_can", "watering_can", -11.55, 6.95, 20)
    _asm(furniture, "roof_can2", "watering_can", -4.95, 6.90, -35)
    # bean canes: a tripod of poles over the west bed
    for i in range(5):
        cx = -12.5 + (i % 2) * 0.5
        cy = -1.6 + i * 0.8
        fb("cane%d" % i, (cx, cy, cx + 0.035, cy + 0.035), 0.42, 1.75,
           "timber")
    fb("waterbutt", (-10.2, 4.1, -9.4, 4.9), 0.0, 1.05, "timber")
    fb("waterbutt_lid", (-10.25, 4.05, -9.35, 4.95), 1.05, 0.05, "metal")
    fb("hose", (-9.6, 4.9, -9.5, 6.9), 0.02, 0.06, "soot")
    fb("wateringcan", (-8.6, 6.4, -8.28, 6.75), 0.0, 0.28, "metal")
    # A light so the roof is usable and the door does not open onto a void.
    markers.append({
        "kind": "cage_bulb", "id": "ROOF_LT_DECK", "unit": "ROOF",
        "pos": [8.6, -2.6, z + 2.52], "yaw_deg": 0,
        "network": "electrical", "range": 9.5, "energy": 0.95,
        "navigation": True, "standby": 0.45})
    markers.append({
        "kind": "cage_bulb", "id": "ROOF_LT_GARDEN", "unit": "ROOF",
        "pos": [-9.0, 6.2, z + 2.30], "yaw_deg": 0,
        "network": "electrical", "range": 8.0, "energy": 0.7,
        "navigation": True, "standby": 0.35})


TREE_BASE = -2.8          # B1 floor, where the trunk is rooted
TREE_TOP = 21.0           # crown, just under the skylight glazing


def _tree_at(h):
    """Where the trunk is at height h. Two slow leans of different period,
    so it wanders and doubles back the way a trained bonsai does rather
    than spiralling like a helix — a regular twist reads as a machine
    part, and this is meant to look grown. Amplitudes keep it inside
    0.62 m of centre; the stair flights begin 1.46 m out."""
    x = 0.40 * math.sin(h * 0.55) + 0.19 * math.sin(h * 1.31 + 1.1)
    y = 0.36 * math.cos(h * 0.47 + 0.6) + 0.15 * math.sin(h * 1.07)
    return x, y


def _tree_nook(fl, rx, ry):
    """A reading nook built around the roots. The bottom of the light
    court is the one place in the building where you can sit under the
    whole height of it and still be lit — the fruit hangs overhead all
    the way up, and the skylight is directly above.

    A built-in bench in three runs, open toward the deck you arrive from,
    because a ring you have to climb into is a planter, not a seat."""
    z = fl["z"]
    f = fl["furniture"]

    def fb(bid, rect, z0, h, mat):
        f.append({"id": "nook_%s" % bid, "rect": [round(v, 3) for v in rect],
                  "z0": z0, "h": h, "mat": mat})

    r = 0.82                    # half-width of the bench square
    # Stay clear of the west flight, which begins at x = -1.46.
    rx = max(rx, -1.46 + r + 0.16)
    fb("rug", (rx - 1.24, ry - 1.24, rx + 1.24, ry + 1.24), 0.014, 0.008,
       "rug_warm")
    # N, E and W runs; the south side stays open to the deck
    for bid, rect in (("n", (rx - r, ry + 0.44, rx + r, ry + r)),
                      ("w", (rx - r, ry - 0.44, rx - 0.44, ry + 0.44)),
                      ("e", (rx + 0.44, ry - 0.44, rx + r, ry + 0.44))):
        fb("seat_" + bid, rect, 0.40, 0.065, "floor_oak")
        fb("apron_" + bid, (rect[0] + 0.05, rect[1] + 0.05, rect[2] - 0.05,
                            rect[3] - 0.05), 0.0, 0.40, "wood_dark")
    # cushions, thrown where someone actually sits rather than centred
    fb("cush1", (rx - 0.74, ry + 0.50, rx - 0.16, ry + 0.86), 0.465, 0.085,
       "fabric_warm")
    fb("cush2", (rx + 0.50, ry - 0.30, rx + 0.80, ry + 0.26), 0.465, 0.075,
       "fabric_green")
    fb("throw", (rx - 0.80, ry - 0.34, rx - 0.48, ry + 0.30), 0.465, 0.055,
       "linen")
    # a low shelf of communal paperbacks against the north run's back
    shelf_unit(f, "nook_books", rx - 0.62, ry + 0.86, 1.25, True, d=0.26,
               h=0.92, books=True, face="s")
    # side table with what someone left on it
    _asm(f, "nook_table", "coffee", rx + 0.02, ry - 0.86, 0)
    _asm(f, "nook_mug", "mug", rx + 0.20, ry - 0.80, 35, z0=0.37,
         mat="ceramic")
    _asm(f, "nook_pile", "bookpile", rx - 0.20, ry - 0.92, 12, z0=0.37,
         n=3)
    _asm(f, "nook_plant", "plant", rx + 0.94, ry + 0.92, 0, big=False)
    # a reading lamp on the table, and the nook is somewhere you can read
    fl["markers"].append({
        "kind": "lamp", "id": "B1_NOOK_LAMP",
        "unit": "ATRIUM", "pos": [round(rx - 0.46, 3), round(ry - 0.90, 3),
                                  round(z + 0.37, 3)],
        "yaw_deg": 30, "network": "electrical",
        # House property, and the best lamp in the building: cased green
        # glass on brass. Somebody carried it down here on purpose.
        "variant": "emeralite"})


def atrium_tree(fl):
    """A brass bonsai wound up the light court, carrying the stair's
    lighting as fruit hanging in the eye.

    Replaces the fluted column: same job — one object the full height of
    the well — but it reads as a commissioned piece in a 1927 lobby
    rather than as structure, and the light becomes something suspended
    in the void instead of bands on a shaft.

    Emitted per floor slice so floor streaming still works. Trunk and
    branches are tubes in WORLD coordinates (asm_pipe without `local`),
    the only primitive in this pipeline that can follow a curve.
    """
    z = fl["z"]
    fid = fl["id"]
    lo = max(z, TREE_BASE)
    hi = TREE_TOP if fid == "ROOF" else min(z + F2F, TREE_TOP)
    if hi <= lo + 0.01:
        return
    f = fl["furniture"]
    rng = random.Random(1927 + int(z * 10))

    def tube(bid, p0, p1, r, mat="brass"):
        f.append({"id": "tree_%s_%s" % (fid, bid), "asm": "pipe",
                  "at": [0.0, 0.0], "yaw": 0, "mat": mat, "r": r,
                  "p0": [round(v, 4) for v in p0],
                  "p1": [round(v, 4) for v in p1]})

    # ---- trunk: short tubes chained along the path, tapering with height
    steps = max(2, int((hi - lo) / 0.34))
    prev = None
    for i in range(steps + 1):
        h = lo + (hi - lo) * i / steps
        x, y = _tree_at(h)
        if prev is not None:
            t = (h - TREE_BASE) / (TREE_TOP - TREE_BASE)
            tube("trunk%d" % i, prev, [x, y, h], 0.115 * (1.0 - t) + 0.035)
        prev = [x, y, h]
    # root flare where it meets the basement floor
    if lo <= TREE_BASE + 0.01:
        bx, by = _tree_at(TREE_BASE)
        for a in range(5):
            ang = math.tau * a / 5.0 + 0.4
            tube("root%d" % a, [bx, by, TREE_BASE + 0.42],
                 [bx + math.cos(ang) * 0.55, by + math.sin(ang) * 0.55,
                  TREE_BASE + 0.02], 0.055)
        _tree_nook(fl, bx, by)

    # ---- branches and their fruit. Two per storey, thrown to opposite
    # sides so the crown stays balanced over the well.
    for k in range(2):
        h = lo + (hi - lo) * (0.34 + 0.42 * k)
        if h > TREE_TOP - 0.4:
            continue
        tx, ty = _tree_at(h)
        ang = rng.uniform(0, math.tau) + k * math.pi
        reach = rng.uniform(0.62, 1.00)
        # elbow partway out, so the branch bends instead of spiking
        ex = tx + math.cos(ang) * reach * 0.55
        ey = ty + math.sin(ang) * reach * 0.55
        ez = h + rng.uniform(0.10, 0.30)
        px = tx + math.cos(ang) * reach
        py = ty + math.sin(ang) * reach
        pz = ez + rng.uniform(-0.05, 0.18)
        tube("br%d_a" % k, [tx, ty, h], [ex, ey, ez], 0.045)
        tube("br%d_b" % k, [ex, ey, ez], [px, py, pz], 0.028)
        for j in range(2):      # twigs, for silhouette
            ja = ang + rng.uniform(-1.1, 1.1)
            jr = rng.uniform(0.18, 0.34)
            tube("br%d_tw%d" % (k, j), [ex, ey, ez],
                 [ex + math.cos(ja) * jr, ey + math.sin(ja) * jr,
                  ez + rng.uniform(0.10, 0.28)], 0.016)
        # Foliage as bonsai pads — but in brass, like the rest of it. A
        # green pad made the piece read as half sculpture and half
        # houseplant; beaten metal leaves keep it one commissioned object,
        # and let the only colour in the court come from the fruit.
        # Three small overlapping pads per branch, because one flat card
        # reads as a card and a cluster reads as a canopy.
        for q in range(3):
            qx = px + rng.uniform(-0.20, 0.20)
            qy = py + rng.uniform(-0.18, 0.18)
            qw = rng.uniform(0.16, 0.27)
            qd = rng.uniform(0.14, 0.23)
            f.append({"id": "tree_%s_pad%d_%d" % (fid, k, q),
                      "rect": [round(qx - qw, 3), round(qy - qd, 3),
                               round(qx + qw, 3), round(qy + qd, 3)],
                      "z0": round(pz + 0.04 + q * 0.035 - z, 3),
                      "h": 0.035, "mat": "brass"})
        # the fruit: a stem off the branch tip, then the light itself
        tube("br%d_stem" % k, [px, py, pz], [px, py, pz - 0.20], 0.011)
        fl["markers"].append({
            "kind": "eye_pendant",
            "id": "%s_ATRIUM_FRUIT_%d" % (fid, k + 1),
            "unit": fid, "pos": [round(px, 3), round(py, 3),
                                 round(pz - 0.34, 3)],
            "yaw_deg": 0, "network": "electrical", "energy": 0.48,
            "navigation": True, "standby": 0.32})


## Wayfinding. You could climb seven identical storeys with nothing
## telling you which one you were on, and stand at a door with nothing
## saying whose it was. Both are plates on the wall: a big floor numeral
## facing you as you arrive off the stair and out of the lift, and a small
## number beside every apartment door on the latch side.
def signage_pass(fl):
    fid = fl["id"]
    if fid == "ROOF":
        return
    z = fl["z"]
    f = fl["furniture"]
    label = "B" if fid == "B1" else fid[-1]

    # NB: furniture z0 is measured from the floor it belongs to, not from
    # the world origin — the builder adds fl["z"] itself. Passing absolute
    # heights here put the basement's plates below its own slab.
    def plate(bid, x, y, w, d, z0, h, mat):
        f.append({"id": "sign_%s_%s" % (fid, bid),
                  "rect": [x, y, x + w, y + d], "z0": z0, "h": h,
                  "mat": mat})

    # Storey plate on the court wall facing the arriving stair deck, and
    # a second in the lift hall opposite the doors.
    for bid, px, py, horiz in (("stair", -0.62, -COURT + CORR_T / 2.0
                                + 0.012, True),
                               ("hall", -0.62, -CORE_Y1 + CORR_T / 2.0
                                + 0.012, True)):
        # Mounted above head height, which is both where a storey numeral
        # belongs and what keeps it out of the circulation audit — a
        # wall plate at eye level counts as an obstruction in a hall.
        plate(bid + "_ground", px, py, 1.24, 0.03, 2.02, 0.46, "trim")
        plate(bid + "_face", px + 0.06, py + 0.006, 1.12, 0.03,
              2.07, 0.36, "art")
        # the numeral itself, as a plain proud block: readable as a mark
        # at a distance without needing a font in the geometry pipeline
        plate(bid + "_num", px + 0.50, py + 0.012, 0.24, 0.03, 2.15,
              0.22, "brass")
    # Apartment plates: beside each unit's corridor door, latch side.
    for stack in ("A", "B", "C", "D"):
        unit = "%s%s" % (fid[-1].lstrip("0") or fid[-1], stack)
        if fid in ("B1", "F01") or unit not in RESIDENTS:
            continue
        if unit == "2D":
            continue          # sealed since 1927: never had a plate
        sx0, sy0, sx1, sy1 = STACK_RECTS[stack]
        east = stack in ("C", "D")
        ey = {"A": sy1 - 1.2, "B": sy0 + 3.30, "C": sy0 + 1.2,
              "D": sy0 + 6.34}[stack]
        # on the corridor face of the apartment wall, beside the opening
        px = (sx0 - CORR_T / 2.0 - 0.012) if east \
            else (sx1 + CORR_T / 2.0 - 0.018)
        plate("apt_%s_back" % unit, px, ey + 0.62, 0.03, 0.30,
              1.42, 0.20, "brass")
        plate("apt_%s_face" % unit, px + (0.006 if east else -0.006),
              ey + 0.65, 0.03, 0.24, 1.45, 0.14, "art")


## ---------------------------------------------------------------- lived-in
## Step 2 of the lived-in pass (design/lived_in_pass.md): semantic sockets
## and life audits, no visual change. Sockets are named anchor points
## derived from the furniture the generator already placed — dressing kits
## land on sockets, never on hand-typed coordinates, so they survive layout
## changes and can be clearance-audited. The audit walks every occupied
## unit against its life profile: a home must let its resident sleep, wash,
## eat, store clothes and leave.

def _load_life_profiles():
    path = os.path.join(OUT_DIR, "apartment_life_profiles.json")
    with open(path) as handle:
        return {p["unit"]: p for p in json.load(handle)["profiles"]}


## asm kind -> socket name(s) hung off it, with a local offset in the
## assembly's own frame (dressing sits ON or BESIDE the anchor furniture).
SOCKET_RULES = {
    "bed": [("BEDSIDE", 0.95, 0.0)],
    "nightstand": [("BEDSIDE_TOP", 0.0, 0.0)],
    "table_round": [("DINING_SURFACE", 0.0, 0.0)],
    "table_rect": [("DINING_SURFACE", 0.0, 0.0)],
    "desk": [("WORK_PRIMARY", 0.0, 0.0)],
    "workbench": [("WORK_PRIMARY", 0.0, 0.0)],
    "kitchen": [("COUNTER_DIRTY", 0.7, 0.0), ("TRASH_ZONE", -0.9, 0.15)],
    "toilet": [("TOILET_SIDE", 0.4, 0.0)],
    "wardrobe": [("WARDROBE_TOP", 0.0, 0.0)],
    "sofa": [("REST_PRIMARY", 0.0, 0.4)],
    "shelf": [("WORK_ARCHIVE", 0.0, 0.25)],
}


def life_pass(floors):
    """Emit fl["sockets"] and audit every occupied unit's life functions."""
    profiles = _load_life_profiles()
    problems = []
    total = 0
    for fl in floors:
        fl["sockets"] = []
        by_unit = {}
        marker_kinds = {}
        for m in fl.get("markers", []):
            unit = str(m.get("unit", ""))
            if unit:
                marker_kinds.setdefault(unit, {})
                # A `sink` marker can be a lavatory or a kitchen bowl.
                # Count the semantic fixture while retaining kind for the
                # water network's stable public vocabulary.
                kind = str(m.get("fixture", m.get("kind", "")))
                marker_kinds[unit][kind] = marker_kinds[unit].get(kind, 0) + 1
        for fu in fl.get("furniture", []):
            fid = str(fu.get("id", ""))
            unit = fid.split("_")[0]
            if unit in profiles:
                by_unit.setdefault(unit, []).append(fu)
        for unit, pieces in by_unit.items():
            for fu in pieces:
                asm = fu.get("asm")
                if asm not in SOCKET_RULES or "at" not in fu:
                    continue
                yaw = math.radians(float(fu.get("yaw", 0)))
                for name, dx, dy in SOCKET_RULES[asm]:
                    # local offset rotated into the assembly's facing
                    ox = dx * math.cos(yaw) - dy * math.sin(yaw)
                    oy = dx * math.sin(yaw) + dy * math.cos(yaw)
                    fl["sockets"].append({
                        "id": "%s_%s" % (unit, name), "unit": unit,
                        "socket": name,
                        "at": [round(fu["at"][0] + ox, 3),
                               round(fu["at"][1] + oy, 3)],
                        "z": fl["z"]})
                    total += 1
        # Complete marker-built fixtures carry their dressing anchors with
        # them. Otherwise removing the obsolete shells silently removes the
        # mineral/rust activity edge even though the fixture still renders.
        for m in fl.get("markers", []):
            semantic = str(m.get("fixture", m.get("kind", "")))
            marker_socket = {
                "fridge": ("FRIDGE_FACE", 0.0, 0.45),
                "bath_sink": ("SINK_EDGE", 0.30, 0.0),
                "kitchen_sink": ("KITCHEN_SINK_EDGE", 0.42, 0.0),
                "shower": ("SHOWER_EDGE", 0.55, 0.0),
            }.get(semantic)
            if marker_socket is None:
                continue
            yaw = math.radians(float(m.get("yaw_deg", 0)))
            socket, dx, dy = marker_socket
            ox = dx * math.cos(yaw) - dy * math.sin(yaw)
            oy = dx * math.sin(yaw) + dy * math.cos(yaw)
            fl["sockets"].append({
                "id": "%s_%s" % (m.get("unit", ""), socket),
                "unit": m.get("unit", ""), "socket": socket,
                "at": [round(m["pos"][0] + ox, 3),
                       round(m["pos"][1] + oy, 3)], "z": fl["z"]})
            total += 1
        # --- the audit: structural life functions per occupied unit
        for unit, prof in profiles.items():
            if unit not in by_unit:
                continue
            pieces = by_unit[unit]
            kinds = {}
            for fu in pieces:
                kinds[fu.get("asm", "")] = kinds.get(fu.get("asm", ""), 0) + 1
            sleepers = 2 if len(prof.get("resident_ids", [])) > 1 else 1
            beds = kinds.get("bed", 0)
            conversions = prof.get("room_conversions", {})
            pending = [k for k in conversions if k.startswith("bedroom")]
            if beds < sleepers and unit != "4B":   # 4B sleeps on its
                problems.append("%s: %d bed(s) for %d sleeper(s)"   # mattress
                                % (unit, beds, sleepers))
            if beds > sleepers and not pending:
                problems.append("%s: %d beds, one sleeper, no declared "
                                "conversion" % (unit, beds))
            elif beds > sleepers and pending:
                # The three spare-bedroom contradictions (2C/5C/6C) are
                # DECLARED in the profiles and resolve in step 3; a warn
                # keeps them visible without blocking every build until
                # then.
                print("life audit: %s spare bed pending conversion to %s"
                      % (unit, list(conversions.values())[0]))
            need = {"wardrobe": "clothing storage", "toilet": "toilet",
                    "bath_sink": "bathroom basin", "shower": "washing",
                    "kitchen_sink": "kitchen sink", "stove": "cooking",
                    "fridge": "cold storage", "kitchen": "kitchen run"}
            # 4B is box-built rather than assembled, which is exactly why
            # the brief demands SEMANTIC checks for it: its mattress,
            # counter run and desk are raw geometry with meaningful ids,
            # and losing one must fail the build like losing any bed.
            ids = " ".join(str(fu.get("id", "")) for fu in pieces)
            if unit == "4B":
                for token, label in (("mattress", "mattress"),
                                     ("kitchen_countertop", "kitchen run"),
                                     ("desk", "desk")):
                    if token not in ids:
                        problems.append("4B: bespoke %s missing" % label)
                if beds == 0 and "mattress" in ids:
                    pass          # the mattress IS the bed
                for semantic, label in (("fridge", "cold storage"),
                                        ("stove", "cooking"),
                                        ("bath_sink", "bathroom basin"),
                                        ("kitchen_sink", "kitchen sink"),
                                        ("shower", "washing")):
                    if marker_kinds.get(unit, {}).get(semantic, 0) == 0:
                        problems.append("4B: no %s" % label)
                if kinds.get("toilet", 0) == 0:
                    problems.append("4B: no toilet")
                continue
            for asm, label in need.items():
                have = (marker_kinds.get(unit, {}).get(asm, 0)
                        if asm in ("fridge", "stove", "bath_sink",
                                   "kitchen_sink", "shower")
                        else kinds.get(asm, 0))
                if have == 0:
                    problems.append("%s: no %s" % (unit, label))
            if kinds.get("table_round", 0) + kinds.get("table_rect", 0) \
                    + kinds.get("desk", 0) == 0:
                problems.append("%s: nowhere to eat or work" % unit)
    print("life pass: %d sockets across %d profiled units"
          % (total, len(profiles)))
    return problems


## Doors the Case Network leaves behind. They are authored here like every
## other coordinate in the building — including the ones that are not
## supposed to exist — but they spawn hidden and only appear when their case
## closes. Case 02's route through the third-floor heating riser ends here.
def case_doors(fl):
    if fl["id"] != "F03":
        return
    # West corridor face, in the clear run between 3B's door (y=5.52) and
    # the storage door (y=0.63). The room behind it is the west storage
    # room, which already HAS a door: this is a second way into a utility
    # space, which is both the sort of thing that never appears on a set of
    # plans and the sort of thing a superintendent refuses to open. It sits
    # on the plaster rather than in a cut opening on purpose — there is no
    # hole behind it, and it does not open.
    fl["markers"].append({
        "kind": "case_door", "id": "F03_UTILITY_ANOMALY", "unit": "3B",
        "pos": [-5.33, 2.00, fl["z"]], "yaw_deg": -90,
        "network": "structural"})


def stair_top_guard(fl):
    """The topmost landing had no balustrade along its open eye edge: the
    guard loop stops at the level BELOW the last one, because it is driven
    by the climbs and the last climb has no floor above it. At roof level
    that leaves a 3 m drop down the light court with nothing across it."""
    if fl["id"] != "ROOF":
        return
    z = fl["z"]
    gx0, gx1 = -COURT + 1.79, COURT - 1.79
    for yc, bid in ((-1.515, "s"), (1.515, "n")):
        fl["furniture"].append({
            "id": "ROOF_EYEGUARD_%s_rail" % bid,
            "rect": [gx0 - 0.06, yc - 0.045, gx1 + 0.06, yc + 0.045],
            "z0": 0.86, "h": 0.10, "mat": "handrail_wood"})
        for j in range(int((gx1 - gx0) / 0.16)):
            xj = gx0 + (j + 0.5) * 0.16
            fl["furniture"].append({
                "id": "ROOF_EYEGUARD_%s_bal%d" % (bid, j),
                "rect": [xj - 0.018, yc - 0.018, xj + 0.018, yc + 0.018],
                "z0": 0.0, "h": 0.86, "mat": "baluster"})


def retail_pass(fl):
    """Two lit rooms in the night, and the walls of the world.

    THE BODEGA is the Half Baked corner store: one tunnel of cheap red
    steel shelving, stocked thin enough that every item is an event,
    fluorescent tubes humming down the aisle, drink coolers at the back,
    and a glass door whose whole job is the view OUT - the street, the
    stoop, the Orison waiting.

    THE BAR is the Harukiya. It is a BASEMENT: a street door beside a
    roll gate, then a littered stairwell going down - cans on the
    treads, a red mat at the bottom - into one low room. A huge red
    canopy hangs over the counter with its light strip under the rim,
    barrels and crowded pictures on the wall behind the bottles, a
    violet-felt pool table under its own pendant, round tables, booths,
    and the karaoke corner where the screen never quite syncs. The
    descent is the point: the street does not know the room exists.

    THE WALLS. No invisible barriers. Scaffolding hoarding closes the
    west pavement, an excavation eats the road at each end, fences and
    a dumpster end the alley. Everything that stops the player is a
    thing a city put there - and the two road closures answer the
    question the empty street would otherwise keep asking.
    """
    furn = fl["furniture"]
    mk = fl["markers"]

    def fb(bid, rect, z0, h, mat):
        furn.append({"id": "retail_" + bid, "rect": list(rect), "z0": z0,
                     "h": h, "mat": mat})

    def pipe(bid, p0, p1, r, mat="metal"):
        furn.append({"id": "retail_" + bid, "asm": "pipe", "at": [p0[0],
                     p0[1]], "yaw": 0, "mat": mat, "p0": list(p0),
                     "p1": list(p1), "r": r})

    def asm(bid, kind, x, y, yaw=0, **kw):
        e = {"id": "retail_" + bid, "asm": kind, "at": [x, y], "yaw": yaw,
             "exterior": True}
        e.update(kw)
        furn.append(e)

    import random as _r
    rs = _r.Random(1931)
    W_T = 0.30

    # ============ BODEGA (nbr_e ground, Half Baked) ===================
    bx0, bx1 = 15.2, 19.6
    ix0, ix1 = bx0 + W_T, bx1 - W_T          # 15.50 .. 19.30
    iy1 = -1.60
    fb("bod_floor", (bx0, -12.0, bx1, iy1 + W_T), 0.0, 0.05, "linoleum")
    fb("bod_ceil", (bx0, -12.0, bx1, iy1 + W_T), 3.20, 0.35, "plaster")
    fb("bod_wall_w", (bx0, -12.0, ix0, iy1 + W_T), 0.0, 3.20,
       "plaster_stained")
    fb("bod_wall_e", (ix1, -12.0, bx1, iy1 + W_T), 0.0, 3.20,
       "plaster_stained")
    fb("bod_wall_n", (bx0, iy1, bx1, iy1 + W_T), 0.0, 3.20,
       "plaster_stained")
    # shopfront: stall riser, glazing, door gap at east
    DOOR_X0, DOOR_X1 = 18.20, 19.15
    fb("bod_stall", (bx0, -12.0, DOOR_X0, -11.82), 0.0, 0.55, "wood_dark")
    fb("bod_glass", (bx0 + 0.10, -11.96, DOOR_X0, -11.90), 0.55, 2.05,
       "glassish")
    fb("bod_fascia", (bx0, -12.02, bx1, -11.78), 2.60, 0.60, "wood_dark")
    for mx in (bx0 + 0.10, 16.55, 17.55, DOOR_X0):
        fb("bod_mull%d" % int(mx * 10), (mx - 0.05, -11.98, mx + 0.05,
           -11.86), 0.0, 2.60, "wood_dark")
    fb("bod_head", (DOOR_X0, -11.98, DOOR_X1, -11.86), 2.10, 0.50,
       "wood_dark")
    fb("bod_gate_box", (bx0, -12.10, bx1, -11.80), 2.62, 0.34, "metal")
    fb("bod_gate", (bx0 + 0.05, -12.02, bx1 - 0.05, -11.94), 2.20, 0.42,
       "chrome")
    fb("bod_awning", (bx0, -13.10, bx1, -11.95), 2.55, 0.10,
       "awning_vinyl")
    # ONE central double-sided gondola run in cheap red steel - three
    # units up the tunnel, aisle both sides
    for gi, (gy0, gy1) in enumerate(((-10.6, -8.6), (-7.8, -5.8),
                                     (-5.0, -3.0))):
        fb("bod_g%d_base" % gi, (17.15, gy0, 17.95, gy1), 0.05, 0.12,
           "safety_orange")
        fb("bod_g%d_spine" % gi, (17.50, gy0, 17.60, gy1), 0.17, 1.58,
           "safety_orange")
        for si, sz in enumerate((0.45, 0.85, 1.25, 1.60)):
            fb("bod_g%d_s%d" % (gi, si), (17.15, gy0, 17.95, gy1), sz,
               0.035, "safety_orange")
        for cap_y in (gy0, gy1 - 0.03):
            fb("bod_g%d_cap%d" % (gi, int(cap_y * 10)),
               (17.15, cap_y, 17.95, cap_y + 0.03), 0.17, 1.58,
               "safety_orange")
    # red wall shelving, both long walls
    for si, sz in enumerate((0.55, 1.00, 1.45)):
        fb("bod_ws_w%d" % si, (ix0, -10.9, ix0 + 0.33, -3.4), sz, 0.035,
           "safety_orange")
        fb("bod_ws_e%d" % si, (ix1 - 0.33, -10.9, ix1, -5.8), sz, 0.035,
           "safety_orange")
    # drink coolers at the back east, glass doors
    fb("bod_cooler", (ix1 - 0.75, -5.4, ix1, iy1), 0.0, 2.30, "metal")
    fb("bod_cooler_glass", (ix1 - 0.78, -5.3, ix1 - 0.72, iy1 - 0.1),
       0.60, 1.55, "glassish")
    # Counter by the door, held WEST of the door opening. Its top used
    # to overhang to 18.40, which put 6 cm of countertop inside the lane
    # a body walks through the door — enough to stop one dead, and
    # invisible unless something measures it.
    fb("bod_counter", (16.85, -11.0, 18.00, -10.35), 0.0, 0.95,
       "wood_dark")
    fb("bod_counter_top", (16.80, -11.05, 18.05, -10.30), 0.95, 0.05,
       "countertop")
    fb("bod_register", (17.25, -10.9, 17.75, -10.45), 1.00, 0.30,
       "bakelite")
    asm("bod_papers", "papers", 17.80, -10.6, 0)
    asm("bod_crate0", "crate", 15.95, -11.3, 12)
    asm("bod_bottles", "bottles", 15.85, -2.3, 0)
    # SPARSE stock: gaps are the point. Whole stretches stay empty.
    def sparse(gy0, gy1, shelf_zs, x_lo, x_hi):
        for sz in shelf_zs:
            if rs.random() < 0.30:
                continue                     # a shelf with nothing on it
            y = gy0 + 0.15
            while y < gy1 - 0.25:
                if rs.random() < 0.42:
                    y += rs.uniform(0.30, 0.65)   # the sad gap
                    continue
                d = rs.uniform(0.09, 0.16)
                tint = rs.choice(("enamel", "terracotta", "brass",
                                  "fabric_green", "bakelite", "paper"))
                fb("bod_stk%d" % rs.randrange(1 << 30),
                   (x_lo + rs.uniform(0, 0.05), y,
                    x_lo + rs.uniform(0.10, x_hi - x_lo), y + d),
                   sz + 0.035, rs.uniform(0.10, 0.24), tint)
                y += d + rs.uniform(0.04, 0.12)
    for gy0, gy1 in ((-10.6, -8.6), (-7.8, -5.8), (-5.0, -3.0)):
        sparse(gy0, gy1, (0.45, 0.85, 1.25, 1.60), 17.17, 17.48)
        sparse(gy0, gy1, (0.45, 0.85, 1.25, 1.60), 17.62, 17.93)
    sparse(-10.9, -3.4, (0.55, 1.00, 1.45), ix0 + 0.02, ix0 + 0.31)
    sparse(-10.9, -5.8, (0.55, 1.00, 1.45), ix1 - 0.31, ix1 - 0.02)
    # markers: door, fluorescents, radio, neon
    # STANDS OPEN. The bodega trades 24 hours and the schedules send
    # residents through this door all night; a closed leaf is a solid
    # body across the only way in, and it read to the player as a grey
    # block rather than as a door they had not tried.
    # HINGE, not centre. Every other door marker in this file is the
    # hinge jamb (see the wall-opening loop: hinge = start + at - w/2),
    # because DoorProp builds its leaf from local x 0 to width and pivots
    # on the node origin. This one was authored at the opening's centre,
    # which hinged the leaf in the middle of its own doorway — so setting
    # it "open" swung it across the other half instead of clearing it,
    # and no amount of opening the door ever opened the door.
    mk.append({"kind": "door", "id": "F01_BODEGA_DOOR",
               "pos": [DOOR_X0, -11.92, 0.0], "yaw_deg": 0, "w": 0.90,
               "h": 2.10, "leaf": "open", "exterior": True})
    for i, ly in enumerate((-10.2, -7.2, -4.2)):
        mk.append({"kind": "kitchen_linear", "id": "F01_BODEGA_LT_%d" % i,
                   "unit": "SITE", "pos": [17.55, ly, 3.05], "yaw_deg": 90,
                   "network": "electrical", "range": 5.5, "energy": 0.55,
                   "navigation": True, "standby": 0.35, "exterior": True})
    mk.append({"kind": "speaker", "id": "F01_BODEGA_RADIO", "unit": "SITE",
               "pos": [16.55, -10.55, 0.0], "yaw_deg": 90,
               "network": "electrical", "exterior": True,
               "bed": "murmur_loop"})
    # Signage redesign (2026-08-07): the bodega dropped its neon for the
    # NYC vocabulary - backlit yellow awning valance + projecting blade
    # lightbox on the west corner, angled to read from the Orison. The
    # prop builds everything; this marker only places and aims it.
    mk.append({"kind": "bodega_signage", "id": "F01_BODEGA_SIGNAGE",
               "pos": [17.4, -12.05, 2.62], "yaw_deg": 0,
               "unit": "SITE", "network": "electrical",
               "exterior": True})

    # ============ THE HARUKIYA (Belchi Lorente layout, brief P2) ======
    # Rebuilt 2026-08-07 from the owner's layout doc and the Belchi
    # Lorente interior study - the same artist docs/harukiya_reference_
    # notes.md already cites, now with the whole plan and his own note
    # that he imagined it "a bite more friendly than in the manga".
    #
    # The old room was one 9.1 x 6.8 m box holding a counter, a pool
    # table and almost nowhere to sit. This one runs 9.2 m deep - the
    # block overhead is hollow to 3.55 and the basement had been using
    # two thirds of its footprint - and reads as the study's three
    # zones: a raised lounge of banquettes behind a turned-baluster
    # railing where you come in, a checkerboard table floor in the
    # middle, and a curtained stage at the far end under a lit sign.
    #
    # What did NOT move, because it is what makes this the Harukiya and
    # not a generic tavern: the teal descent, the red steel door, two
    # arcade cabinets immediately left of the entrance, the deep canopy
    # over the counter, the barrels and crowded pictures behind the
    # backbar, the violet felt, the low ceiling, and light that only
    # ever comes from something you can point at.
    KX0, KX1 = -12.0, 6.4
    FACE = -28.32
    # WIDENED WEST, 2026-08-08. Was -5.10: a 9.1 x 9.2 m room carrying a
    # stage, a raised deck, a nine-metre counter, a WC and seven tables,
    # which left tables 1.8 m apart centre to centre when a table with
    # chairs at 0.78 m radius needs 2.5 m before anybody can walk
    # between two of them. You could not cross the room, and the
    # schedules send residents in here.
    RX0, RX1 = -11.50, 4.00          # room clear span, east-west
    RY0, RY1 = -37.90, -28.70        # 9.2 m deep now, was 6.8
    FLR = -2.80                       # basement floor top
    DECK = FLR + 0.18                 # the raised lounge
    STAGE_Z = FLR + 0.22
    SH_W, SH_E = 4.30, 5.45           # stair shaft, 1.15 clear

    # ground storey: infill everywhere but the lobby/shaft slot
    # The fills stop at the shaft LINING. The first cut ran them to the
    # shaft's clear face, which buried the plaster stairwell walls inside
    # brick - and the teal descent is canonical, so the stairwell must
    # own its skin.
    # THE LUNCHEONETTE IS IN THIS BLOCK TOO. nbr_s2's ground floor is
    # brick everywhere the Harukiya's stair is not, and that fill ran
    # straight through the diner's new sales floor — a shopfront with a
    # solid block behind it, which is the whole fault this pass exists to
    # fix, reappearing one function away. Cut the same void out of the
    # fill that site_pass cuts out of the block above it.
    fill_w = [(KX0, -38.2, RX1, FACE)]
    for _blk, hole in shop_voids():
        if _blk == "nbr_s2":
            nxt = []
            for r in fill_w:
                nxt += subtract_rect([r], hole)
            fill_w = nxt
    for _i, _r in enumerate(fill_w):
        fb("bar_fill_w%d" % _i, _r, 0.0, 3.55, "common_brick")
    fb("bar_fill_e", (SH_E + 0.30, -38.2, KX1, FACE), 0.0, 3.55,
       "common_brick")
    fb("bar_fill_s", (SH_W, -38.2, SH_E, -35.80), 0.0, 3.55,
       "common_brick")
    fb("bar_lintel", (SH_W, -35.80, SH_E, FACE), 2.55, 1.00,
       "common_brick")

    # the slot: lobby at street, 15 treads down, vestibule at bottom
    fb("bar_lob_floor", (SH_W, -30.00, SH_E, FACE), -0.02, 0.04,
       "quarry_tile")
    RUN = 0.27
    for t in range(15):
        ty1 = -30.00 - t * RUN
        top = -0.175 * (t + 1)
        fb("bar_tread%d" % t, (SH_W, ty1 - RUN, SH_E, ty1), -2.90,
           2.90 + top, "quarry_tile")
    fb("bar_vest_floor", (SH_W, -35.50, SH_E, -34.05), -2.87, 0.07,
       "quarry_tile")
    fb("bar_mat", (SH_W + 0.10, -34.60, SH_E - 0.10, -34.10), FLR,
       0.012, "rug_warm")
    # THE THRESHOLD HAD NO FLOOR. The room's slab stops at x 4.00 and
    # the vestibule's starts at 4.30, so the 30 cm of doorway between
    # them was a hole — and a body that will not walk over a hole stops
    # dead in the opening, which reads exactly like a blocked door and
    # is why this survived the hinge fix and the swing fix both.
    fb("bar_threshold", (RX1, -34.90, SH_W, -33.95), -2.87, 0.07,
       "quarry_tile")
    # shaft walls, full height street to basement
    fb("bar_shaft_e", (SH_E, -35.80, SH_E + 0.30, FACE), -2.90,
       5.45, "stairwell_teal")
    fb("bar_shaft_s", (SH_W, -35.80, SH_E, -35.50), -2.90, 5.45,
       "stairwell_teal")
    # west shaft wall doubles as the room's east wall; pierced at the
    # bottom for the red door (opening y -34.90..-33.95)
    fb("bar_wall_e_n", (RX1, -33.95, SH_W, FACE), -2.90, 5.45,
       "stairwell_teal")
    fb("bar_wall_e_s", (RX1, -35.80, SH_W, -34.90), -2.90, 5.45,
       "stairwell_teal")
    fb("bar_wall_e_lint", (RX1, -34.90, SH_W, -33.95), -0.77, 2.32,
       "stairwell_teal")
    # the room's own east wall south of the shaft, now that the room
    # runs deeper than the stair does
    fb("bar_wall_e_deep", (RX1, RY0 - 0.30, RX1 + 0.30, -35.50), -2.87,
       2.72, "bar_wall")
    # Litter, moved OUT of the stair run. The shaft is 1.15 m clear and
    # a body is 0.66 wide, so anything standing mid-flight leaves less
    # than a shoulder either side — and these two were at x 4.70 and
    # 5.15, which is the middle of the only way into the bar. They read
    # exactly as well tucked against the walls at the top and bottom,
    # where somebody would actually have kicked them, and the descent is
    # now clear the whole way down.
    asm("bar_lit_paper", "papers", 5.22, -29.25, 35, z0=-0.02)
    asm("bar_lit_bott", "bottles", 5.24, -35.15, 0, z0=-2.87)
    asm("bar_lit_crate", "crate", 4.55, -29.30, 55, z0=0.0)

    # the room shell
    fb("bar_floor", (RX0 - 0.30, RY0 - 0.30, RX1, RY1 + 0.05), -2.87,
       0.07, "quarry_tile")
    # The luncheonette occupies the ground floor above the bar's west end.
    # Its floor cannot also be the old 430 mm basement lid: that lid rose
    # 270 mm above the pavement and formed a step-wall across the shop door.
    bar_ceil = [(RX0 - 0.30, RY0 - 0.30, RX1, RY1 + 0.05)]
    for _blk, hole in shop_voids():
        if _blk == "nbr_s2":
            nxt = []
            for r in bar_ceil:
                nxt += subtract_rect([r], hole)
            bar_ceil = nxt
    for _i, _r in enumerate(bar_ceil):
        fb("bar_ceil%d" % _i, _r, -0.15, 0.43, "soot")
    fb("bar_wall_w", (RX0 - 0.30, RY0 - 0.30, RX0, RY1 + 0.05), -2.87,
       2.72, "bar_wall")
    fb("bar_wall_s", (RX0, RY0 - 0.30, RX1, RY0), -2.87, 2.72,
       "bar_wall")
    fb("bar_wall_n", (RX0, RY1, RX1, RY1 + 0.38), -2.87, 2.72,
       "bar_wall")
    # Rubble dado, straight from the study: coursed stone to just above
    # table height, plaster above it. It is the single detail that stops
    # the walls reading as painted cardboard.
    for tag, rect in (("w", (RX0, RY0, RX0 + 0.06, RY1)),
                      ("s", (RX0, RY0, RX1, RY0 + 0.06)),
                      ("n", (RX0, RY1 - 0.06, RX1, RY1))):
        fb("bar_dado_%s" % tag, rect, FLR, 1.05, "concrete")

    # -- THE CHECKERBOARD, the middle zone the tables stand on.
    # Laid as pale inlays over the quarry floor rather than as two
    # interleaved grids: half the boxes for the same picture.
    CB_X0, CB_Y0, CB_N, CB_M, CB = -3.20, -36.60, 8, 9, 0.60
    for cx in range(CB_N):
        for cy in range(CB_M):
            if (cx + cy) % 2:
                continue
            x0 = CB_X0 + cx * CB
            y0 = CB_Y0 + cy * CB
            fb("bar_cb%d_%d" % (cx, cy), (x0, y0, x0 + CB, y0 + CB),
               FLR + 0.005, 0.012, "limestone")

    # -- THE RAISED LOUNGE, east side, where you arrive.
    # A step up, a railing of turned balusters, and banquettes round
    # low tables: the study's "friendlier" half, and the reason the bar
    # now has somewhere to sit that is not a stool.
    LD_X0, LD_Y0, LD_Y1 = 1.80, -37.60, -32.00
    # NOTCHED AT THE DOOR. The deck used to run unbroken past the red
    # door, so you came in off the stair straight into a vertical 180 mm
    # lip across the whole width of the opening — and the controller has
    # no step-up, so the bar simply could not be entered. Three separate
    # fixes went into that doorway (hinge, swing, threshold floor) before
    # anything measured what was actually in front of it, which was a
    # kerb.
    #
    # So the deck stops short either side of the door and you arrive on
    # the table floor, which is also the better room: you walk IN, and
    # the lounge is a step up to your left and right rather than
    # something you trip over on the way through.
    ND0, ND1 = -34.95, -33.90          # the notch, on the door's centre
    fb("bar_deck_s", (LD_X0, LD_Y0, RX1, ND0), FLR, 0.18, "quarry_tile")
    fb("bar_deck_n", (LD_X0, ND1, RX1, LD_Y1), FLR, 0.18, "quarry_tile")
    for tag, (ny0, ny1) in (("s", (LD_Y0, ND0)), ("n", (ND1, LD_Y1))):
        fb("bar_deck_nose_%s" % tag, (LD_X0 - 0.06, ny0, LD_X0, ny1),
           FLR, 0.18, "wood_dark")
    # A 90 mm tread along each notch edge, so the deck is climbable from
    # the way in rather than being a shelf you can only look at.
    fb("bar_step_s", (LD_X0, ND0 - 0.09, RX1, ND0), FLR, 0.09,
       "wood_dark")
    fb("bar_step_n", (LD_X0, ND1, RX1, ND1 + 0.09), FLR, 0.09,
       "wood_dark")
    # the railing: newels, turned balusters, moulded rail. Split either
    # side of the step opening so the way down is actually a way down.
    # The gap in the railing has to be the gap in the DECK. It was cut
    # at -34.40..-33.60 when the deck was solid; the notch is at
    # ND0..ND1, so the railing was closed across the way in and open
    # over a piece of deck that is no longer there.
    for seg, (ry0, ry1) in enumerate(((LD_Y0 + 0.10, ND0),
                                      (ND1, LD_Y1 - 0.10))):
        pipe("bar_rail%d" % seg, (LD_X0 - 0.03, ry0, DECK + 0.92),
             (LD_X0 - 0.03, ry1, DECK + 0.92), 0.035, "handrail_wood")
        n_bal = max(2, int((ry1 - ry0) / 0.16))
        for b in range(n_bal + 1):
            by = ry0 + (ry1 - ry0) * b / n_bal
            pipe("bar_bal%d_%d" % (seg, b), (LD_X0 - 0.03, by, DECK),
                 (LD_X0 - 0.03, by, DECK + 0.90), 0.019,
                 "handrail_wood")
        for e, ey in enumerate((ry0, ry1)):
            pipe("bar_newel%d_%d" % (seg, e), (LD_X0 - 0.03, ey, DECK),
                 (LD_X0 - 0.03, ey, DECK + 1.02), 0.045, "handrail_wood")
    # banquettes along the east wall, and the low tables they face
    # Pulled clear of the door. A banquette centred at -35.30 is 1.50
    # long, so it reached -34.55 — over the notch edge and squarely
    # across the lane you walk in on, which is how the way into the bar
    # stayed blocked through a hinge fix, a swing fix, a threshold slab
    # and a notched deck. Furniture was the last thing anyone suspected
    # and the first thing standing there.
    for i, (by, ln) in enumerate(((-37.20, 1.50), (-35.85, 1.40),
                                  (-32.85, 1.30))):
        asm("bar_banq%d" % i, "couch", RX1 - 0.42, by, 270, z0=DECK,
            variant=i, L=ln)
        fb("bar_btab%d" % i, (2.30, by - 0.42, 3.10, by + 0.42),
           DECK + 0.38, 0.05, "wood_dark")
        asm("bar_bmug%d" % i, "mug", 2.70, by + 0.10, 0, z0=DECK + 0.43)

    # -- ARCADE CORNER, immediately left of the red door (canonical).
    # Still the first thing on your left, now standing on the deck.
    asm("bar_cab01", "arcade_cab", 3.55, -35.35, 270, z0=DECK, variant=0)
    asm("bar_cab02", "arcade_cab", 3.55, -36.30, 270, z0=DECK, variant=1)
    asm("bar_jukebox", "jukebox", 2.35, -37.35, 180, z0=DECK)

    # -- BAR, north long wall: backbar / aisle / counter with red trim
    for bi, bz in enumerate((-1.60, -1.10, -0.65)):
        fb("bar_bshelf%d" % bi, (-4.30, RY1 - 0.24, 0.90, RY1 - 0.02),
           bz, 0.04, "timber")
    for i, bx in enumerate((-3.9, -2.4, -0.9, 0.3)):
        asm("bar_bott%d" % i, "bottles", bx, RY1 - 0.14, 180, z0=-1.56)
    for i, (b0, b1) in enumerate(((-3.40, -2.50), (-1.20, -0.30))):
        pipe("bar_barrel%d" % i, (b0, RY1 - 0.16, -0.72),
             (b1, RY1 - 0.16, -0.72), 0.36, "timber")
    fb("bar_counter", (-4.30, -30.28, 0.90, -29.60), FLR, 1.02,
       "wood_dark")
    fb("bar_counter_top", (-4.36, -30.34, 0.96, -29.54), -1.78, 0.06,
       "countertop")
    # the aggressive red trim, canonical
    fb("bar_trim_front", (-4.36, -30.36, 0.96, -30.28), -1.92, 0.20,
       "lacquer_red")
    fb("bar_trim_ends_w", (-4.36, -30.36, -4.28, -29.54), -1.92, 0.20,
       "lacquer_red")
    pipe("bar_footrail", (-4.1, -30.55, -2.42), (0.7, -30.55, -2.42),
         0.024, "brass")
    fb("bar_canopy", (-4.45, -30.45, 1.05, -29.45), -0.98, 0.40,
       "fabric_warm")
    for eid, rect in (("f", (-4.45, -30.51, 1.05, -30.45)),
                      ("w", (-4.51, -30.51, -4.45, -29.45)),
                      ("e", (1.05, -30.51, 1.11, -29.45))):
        fb("bar_can_rim_%s" % eid, rect, -1.04, 0.10, "lacquer_red")
    for i, sx in enumerate((-3.8, -2.75, -1.7, -0.65, 0.4)):
        pipe("bar_stool%d_post" % i, (sx, -30.85, FLR),
             (sx, -30.85, FLR + 0.70), 0.04, "chrome")
        pipe("bar_stool%d_seat" % i, (sx, -30.85, FLR + 0.70),
             (sx, -30.85, FLR + 0.76), 0.19, "vinyl_oxblood")

    # -- THE GALLERY WALL. The study's crowded, mismatched frames: the
    # bar has been collecting them longer than anyone working here has
    # been alive. Deterministic scatter so a regen does not reshuffle
    # somebody's memory of the room.
    gal = 0
    for wall, (ax, ay, span, horiz) in {
            "n": (-4.30, RY1 - 0.045, 8.10, True),
            "w": (RX0 + 0.02, -36.40, 5.60, False)}.items():
        for k in range(11):
            t = (k * 0.61803) % 1.0
            w = 0.34 + ((k * 7) % 4) * 0.13
            h = 0.28 + ((k * 5) % 3) * 0.16
            z = -1.55 + ((k * 3) % 5) * 0.20
            if horiz:
                x0 = ax + t * (span - w)
                fb("bar_gal%d_art" % gal, (x0, ay, x0 + w, ay + 0.045),
                   z, h, "art")
            else:
                y0 = ay + t * (span - w)
                fb("bar_gal%d_art" % gal, (ax, y0, ax + 0.045, y0 + w),
                   z, h, "art")
            gal += 1

    # -- CEILING SERVICES. Exposed runs across a low dark ceiling, the
    # study's most-repeated detail after the frames. They also give the
    # eye something to read the height against.
    for i, py in enumerate((-36.20, -34.10, -31.60, -29.90)):
        pipe("bar_pipe%d" % i, (RX0 + 0.10, py, -0.34),
             (RX1 - 0.10, py, -0.34), 0.055, "metal")
    for i, px in enumerate((-2.60, 0.80)):
        pipe("bar_condu%d" % i, (px, RY0 + 0.20, -0.28),
             (px, RY1 - 0.20, -0.28), 0.028, "metal")

    # -- TABLES. Round tops, bentwood chairs, a candle on each: the
    # single biggest change, and the reason the room now reads as a
    # place people sit in rather than a corridor with a counter.
    # RE-SPACED on the widened floor. The old set sat 1.8 m apart centre
    # to centre; chairs hang at 0.78 m radius, so two tables need 2.5 m
    # before a person fits between them and about 2.9 m before it is a
    # route rather than a squeeze. Every pair below is at least 2.9 m
    # apart, and the run down the middle of the room is left clear so
    # there is a way from the door to the stage that does not go through
    # anybody's chair.
    #
    # Eight tables now rather than seven, because the room grew by more
    # than it lost to spacing.
    # A CHAIR REACHES 1.23 m FROM ITS TABLE, not 0.78: the seat sits at
    # 0.78 radius and carries its own 0.45 hull. Every spacing sum here
    # was originally done against 0.78, which is why the first re-space
    # still left chairs inside the west riser pipes and across the
    # middle of the room.
    #
    # Three tables, not eight. The room also holds a pool table, five
    # stools, three banquettes and a stage, and the brief was that you
    # could not move — so the floor is mostly floor now, which is what a
    # bar with a stage in it should be.
    TABLES = [(-8.20, -35.30, 3), (-5.20, -35.30, 2), (-1.20, -34.90, 3)]
    for i, (tx, ty, seats) in enumerate(TABLES):
        asm("bar_tab%d" % i, "table_round", tx, ty, 0, z0=FLR)
        fb("bar_candle%d" % i, (tx - 0.03, ty - 0.03, tx + 0.03,
                                ty + 0.03), FLR + 0.74, 0.16, "linen")
        for s in range(seats):
            a = (i * 41 + s * (360 // seats)) % 360
            rad = 0.78
            cx = tx + rad * math.cos(math.radians(a))
            cy = ty + rad * math.sin(math.radians(a))
            asm("bar_ch%d_%d" % (i, s), "chair", cx, cy,
                (a + 180) % 360, z0=FLR)

    # -- THE STAGE, far end, curtained, under a lit sign. In the study
    # it is a small raised platform with a piano at one side and heavy
    # red drapes behind - not a performance space so much as a corner
    # somebody stands in.
    ST_X0, ST_X1, ST_Y0, ST_Y1 = -2.60, 1.20, -37.60, -36.20
    fb("bar_stage", (ST_X0, ST_Y0, ST_X1, ST_Y1), FLR, 0.22, "timber")
    fb("bar_stage_lip", (ST_X0, ST_Y1 - 0.05, ST_X1, ST_Y1), FLR,
       0.22, "lacquer_red")
    # the drapes: pleats as alternating depths so they read as cloth.
    # Wearing the restroom's oxblood until a velvet gen lands
    # (prompt 14 in RETAIL_TEXTURE_PROMPTS); a catalog key with no
    # ingested mapping fails the build, so the stand-in is a real
    # material and not a placeholder colour.
    for i in range(16):
        dx = ST_X0 + i * (ST_X1 - ST_X0) / 16.0
        dep = 0.10 if i % 2 else 0.17
        fb("bar_drape%d" % i, (dx, ST_Y0 - 0.02, dx + 0.24,
                               ST_Y0 - 0.02 + dep), FLR, 2.35,
           "bar_wall_red")
    fb("bar_pelmet", (ST_X0 - 0.10, ST_Y0 - 0.04, ST_X1 + 0.10,
                      ST_Y0 + 0.20), FLR + 2.30, 0.26, "bar_wall_red")
    asm("bar_mic", "micstand", -0.70, -36.75, 180, z0=STAGE_Z)
    asm("bar_tv", "tv", 0.90, -37.30, 200, z0=STAGE_Z)
    # the piano, upright against the stage's west end
    fb("bar_piano_body", (-2.45, -37.45, -1.35, -36.85), STAGE_Z, 1.18,
       "wood_dark")
    fb("bar_piano_lid", (-2.50, -37.50, -1.30, -36.80), STAGE_Z + 1.18,
       0.06, "wood_dark")
    fb("bar_piano_keys", (-2.40, -36.85, -1.40, -36.63), STAGE_Z + 0.62,
       0.05, "linen")
    for i in range(2):
        pipe("bar_pastack%d" % i, (ST_X0 - 0.35 + i * 4.4, -37.30,
                                   FLR + 0.90),
             (ST_X0 - 0.35 + i * 4.4, -37.30, FLR + 2.05), 0.16, "soot")
        mk.append({"kind": "speaker", "id": "F01_KARAOKE_SPK_%d" % i,
                   "unit": "SITE",
                   "pos": [ST_X0 - 0.35 + i * 4.4, -37.30, FLR + 0.90],
                   "yaw_deg": 180, "network": "electrical",
                   "exterior": True})
    # the sign over the stage - the study hangs a big lit word up there
    # and it is the room's one piece of legible text
    mk.append({"kind": "neon_sign", "id": "F01_BAR_STAGE_SIGN",
               "pos": [-0.70, ST_Y0 + 0.05, FLR + 2.42],
               "yaw_deg": 180, "text": "HARUKIYA", "vertical": False,
               "tint": [1.0, 0.86, 0.52], "network": "electrical"})

    # -- POOL TABLE, north-west, WITH ROOM TO PLAY IT.
    #
    # It used to sit at x -4.70..-2.70, y -34.60..-33.30, which is the
    # middle of the room — the obvious east-west lane ran straight
    # through the baize, and the re-spaced tables put a set of chairs on
    # top of it. A cue is 1.45 m long, so a table needs about 1.4 m
    # clear off every rail before a shot is possible at all; nothing
    # like that existed anywhere near it.
    #
    # Here it has 1.55 m to the west riser pipes, 2.89 m to the counter,
    # 1.95 m to the north wall and 2.87 m to the nearest chair. The one
    # tight side is west, where a short cue does the job — which is what
    # every bar table in a real room asks of you.
    fb("bar_pool_body", (-8.40, -31.90, -6.40, -30.60), FLR, 0.78,
       "wood_dark")
    fb("bar_pool_felt", (-8.28, -31.78, -6.52, -30.72), FLR + 0.78,
       0.04, "felt_violet")
    for i, (bx, by, mat) in enumerate((
            (-7.65, -31.40, "enamel"),
            (-7.30, -31.10, "terracotta"),
            (-7.00, -31.45, "brass"),
            (-6.70, -31.00, "fabric_green"),
            (-7.45, -30.85, "bakelite"))):
        fb("bar_ball%d" % i, (bx, by, bx + 0.06, by + 0.06),
           FLR + 0.82, 0.055, mat)
    pipe("bar_cue", (-6.25, -30.45, FLR + 0.05),
         (-6.00, -30.65, FLR + 1.50), 0.012, "timber")
    # The chalk on the rail: the handle on the game, because the table
    # is two metres long and an interactable on it would be a two-metre
    # button.
    mk.append({"kind": "point_ball", "id": "F01_BAR_POOL", "unit": "SITE",
               "pos": [-6.52, -30.70, FLR + 0.78], "yaw_deg": 0,
               "exterior": True})

    # -- DARTS, in the west bay, TO REGULATION.
    #
    # The numbers are not decoration: a board's bull sits 1.73 m off the
    # floor and the oche is 2.37 m from the FACE of the board, and if
    # either is wrong every player who has ever thrown a dart will feel
    # it before they can say why. The west bay is the only stretch of
    # this room with 2.4 m of clear wall and nothing behind the thrower,
    # which is the other half of the requirement — you do not put a
    # dartboard where people walk past your elbow.
    DB_Y = -33.00                      # the lane, between the tables
    DB_X = -11.42                      # board face, on the west wall
    DB_Z = FLR + 1.73                  # bull height, off the finished floor
    OCHE = DB_X + 2.37                 # where the feet go
    # The cabinet: a plywood box with doors, the way every pub keeps a
    # board from warping. Doors folded open against the wall.
    fb("bar_darts_case", (-11.50, DB_Y - 0.55, -11.43, DB_Y + 0.55),
       DB_Z - 0.62, 1.24, "wood_dark")
    for sgn in (-1.0, 1.0):
        fb("bar_darts_door%d" % int(sgn), (-11.49, DB_Y + sgn * 0.56,
                                           -11.44, DB_Y + sgn * 1.08),
           DB_Z - 0.60, 1.20, "wood_dark")
    # The board itself: sisal face, wire ring, a dark surround.
    pipe("bar_darts_back", (DB_X - 0.02, DB_Y, DB_Z),
         (DB_X, DB_Y, DB_Z), 0.245, "soot")
    pipe("bar_darts_face", (DB_X, DB_Y, DB_Z),
         (DB_X + 0.012, DB_Y, DB_Z), 0.2255, "linen")
    # THE RAINBOW. Seven slices, because the game played on this board
    # is not 301 — it is the Rainbow Round, where the answer to every
    # question is a colour and you throw at the one you believe.
    #
    # fb() is axis-aligned and pipe() is a cylinder, so there is no way
    # to author a true wedge here. Seven radial bars in the seven
    # colours read as the slices they mark, which is what the board
    # needs to do from four feet away in a dark bar — the panel is
    # where the geometry is exact.
    RAINBOW = ["lacquer_red", "safety_orange", "brass_bright",
               "fabric_green", "book_teal", "stairwell_teal",
               "felt_violet"]
    for si, smat in enumerate(RAINBOW):
        sa = math.radians(si * 360.0 / len(RAINBOW))
        for rr in (0.062, 0.118, 0.174):
            pipe("bar_darts_slice%d_%d" % (si, int(rr * 1000)),
                 (DB_X + 0.013, DB_Y + math.sin(sa) * (rr - 0.026),
                  DB_Z + math.cos(sa) * (rr - 0.026)),
                 (DB_X + 0.013, DB_Y + math.sin(sa) * (rr + 0.026),
                  DB_Z + math.cos(sa) * (rr + 0.026)), 0.021, smat)
    pipe("bar_darts_treble", (DB_X + 0.012, DB_Y, DB_Z),
         (DB_X + 0.015, DB_Y, DB_Z), 0.107, "brass")
    pipe("bar_darts_double", (DB_X + 0.012, DB_Y, DB_Z),
         (DB_X + 0.015, DB_Y, DB_Z), 0.170, "brass")
    pipe("bar_darts_bull", (DB_X + 0.014, DB_Y, DB_Z),
         (DB_X + 0.018, DB_Y, DB_Z), 0.0159, "lacquer_red")
    # THE OCHE. A brass strip let into the floor, because a chalk line
    # gets walked off and this one has been argued over.
    fb("bar_oche", (OCHE - 0.02, DB_Y - 0.38, OCHE + 0.02, DB_Y + 0.38),
       FLR, 0.006, "brass")
    # The chalk scoreboard, hung where the thrower can see it without
    # turning round.
    fb("bar_darts_score", (-11.49, DB_Y + 1.22, -11.44, DB_Y + 2.10),
       DB_Z - 0.30, 0.86, "soot")
    fb("bar_darts_score_rim", (-11.50, DB_Y + 1.18, -11.42, DB_Y + 2.14),
       DB_Z - 0.34, 0.05, "wood_dark")
    # The ledge the darts live on, beside the oche. This is the thing
    # the player actually presses E on — the board is 2.37 m away by
    # definition, which is well past anybody's reach.
    fb("bar_darts_ledge", (OCHE - 0.18, DB_Y - 1.02, OCHE + 0.22,
                           DB_Y - 0.72), FLR + 0.92, 0.05, "wood_dark")
    pipe("bar_darts_ledge_leg", (OCHE + 0.02, DB_Y - 0.87, FLR),
         (OCHE + 0.02, DB_Y - 0.87, FLR + 0.92), 0.030, "metal")
    mk.append({"kind": "darts", "id": "F01_BAR_DARTS", "unit": "SITE",
               "pos": [OCHE + 0.02, DB_Y - 0.87, FLR + 0.97],
               "yaw_deg": 0, "exterior": True})
    # A board unlit is a board nobody uses.
    mk.append({"kind": "cage_bulb", "id": "F01_BAR_LT_DARTS",
               "unit": "SITE", "pos": [DB_X + 0.34, DB_Y, DB_Z + 0.78],
               "yaw_deg": 0, "network": "electrical", "range": 2.6,
               "energy": 0.55, "navigation": False, "standby": 0.2,
               "exterior": True})

    # -- PLANTS. Canon: tall indoor palms, improbably alive.
    asm("bar_palm0", "plant", -10.20, -29.60, 0, z0=FLR)
    asm("bar_palm1", "plant", 1.35, -37.20, 0, z0=DECK)
    asm("bar_palm2", "plant", 3.70, -32.45, 0, z0=DECK)

    # -- RESTROOM, far SW corner
    fb("bar_wc_wall_e", (-9.80, RY0, -9.65, -36.10), FLR, 2.60,
       "bar_wall_red")
    fb("bar_wc_wall_n_w", (RX0, -36.25, -10.85, -36.10), FLR, 2.60,
       "bar_wall_red")
    fb("bar_wc_wall_n_e", (-10.15, -36.25, -9.65, -36.10), FLR, 2.60,
       "bar_wall_red")
    fb("bar_wc_lintel", (-10.85, -36.25, -10.15, -36.10), FLR + 2.05,
       0.55, "bar_wall_red")
    asm("bar_wc_toilet", "toilet", -11.15, -37.45, 0, z0=FLR)
    mk.append({"kind": "sink", "fixture": "bath_sink",
               "id": "F01_BAR_WC_SINK_01", "unit": "BAR",
               "pos": [-10.10, -37.50, FLR], "yaw_deg": 0,
               "network": "water"})
    # HINGE at the west jamb. Was -4.10, the dead centre of its own
    # -4.45..-3.75 opening — the fourth door in this file authored that
    # way, and the same consequence every time: the closed leaf covers
    # half the hole and buries the other half in the wall.
    mk.append({"kind": "door", "id": "F01_BAR_WC_DOOR",
               "pos": [-10.85, -36.17, FLR], "yaw_deg": 0, "w": 0.70,
               "h": 2.00, "leaf": "closed", "exterior": True})

    # -- doors, signs, lights
    # The street door to the stair stands open too - it is the mouth of
    # the descent, and the teal shaft below is the whole invitation.
    # HINGE, not centre — the same fault the bodega door had, and for
    # the same reason: 4.875 is dead centre of the 4.30..5.45 shaft, so
    # the leaf was hung in the middle of its own doorway and "open"
    # swung it across the half it had been leaving clear. At yaw 180 the
    # leaf runs from the marker toward -x, so the hinge is the EAST
    # jamb.
    mk.append({"kind": "door", "id": "F01_BAR_DOOR",
               "pos": [SH_E, FACE - 0.10, 0.0], "yaw_deg": 180,
               "w": 0.90, "h": 2.10, "leaf": "open", "exterior": True})
    # HINGE at the north jamb. Was -34.42 — dead centre of the
    # -34.90..-33.95 opening pierced for it — so the leaf hung in the
    # middle of the only way from the foot of the stair into the room,
    # and the bar could not be entered even after the street door was
    # fixed. At yaw 90 the leaf runs from the marker toward -y.
    # SWINGS INTO THE ROOM, not into the stair. With the default hinge
    # it opened backwards into a shaft 1.15 m wide and lay diagonally
    # across its own doorway — the hinge was right and the leaf still
    # blocked the way in. "swing": "out" is DoorProp's reversed hinge,
    # written for precisely this: a door that must not sweep whoever is
    # standing in the vestibule. It now parks along the room's east wall
    # and the shaft stays clear.
    mk.append({"kind": "door", "id": "F01_BAR_RED_DOOR",
               "pos": [4.15, -33.95, FLR], "yaw_deg": 90, "w": 0.90,
               "h": 2.05, "leaf": "closed", "swing": "out",
               "exterior": True})
    # THE SONGBOOK TERMINAL. Wall-hung on the west side within sight of
    # the stage, chest height, facing back into the room — a rented
    # karaoke box, which is how every bar of this kind has one without
    # any of them owning one. This marker is what makes the whole
    # Songbook reachable: everything under scripts/songbook was built
    # and left inert because nothing in the world referenced it.
    mk.append({"kind": "songbook_terminal", "id": "F01_BAR_SONGBOOK",
               "unit": "SITE", "pos": [RX0 + 0.16, -35.20, FLR + 0.92],
               "yaw_deg": -90, "network": "electrical",
               "exterior": True})
    fb("bar_face_gate", (-5.30, FACE - 0.10, 3.90, FACE - 0.02), 0.55,
       1.95, "chrome")
    fb("bar_face_stall", (-5.30, FACE - 0.13, 3.90, FACE), 0.0, 0.55,
       "wood_dark")
    fb("bar_face_fascia", (KX0, FACE - 0.16, KX1, FACE + 0.02), 2.50,
       0.60, "soot")
    # Signage redesign (2026-08-07): the bar's two neons are replaced by
    # one izakaya ensemble the prop builds - the painted board under
    # gooseneck trough lights, the red chochin lantern (lit when open,
    # taken in when closed), and a marquee bulb arrow pointing down the
    # stair. Faces the street and the Orison beyond it.
    mk.append({"kind": "bar_signage", "id": "F01_BAR_SIGNAGE",
               "pos": [4.875, FACE + 0.06, 2.80], "yaw_deg": 180,
               "unit": "SITE", "network": "electrical",
               "exterior": True})
    # ================= THE HARUKIYA'S LIGHTING ========================
    # RELIT (2026-08-08) on the brief "the bar needs actual lighting".
    # It had fourteen fixtures and still read as an unlit room, for three
    # reasons that had nothing to do with how many there were:
    #
    # 1. THREE OF THEM WERE OVER THE WRONG THING. The room was widened
    #    from 9.1 x 6.8 to 15.5 x 9.2 and the furniture moved with it;
    #    the lights did not. LT_POOL hung at x -3.70 while the pool
    #    table went to -7.40, so the pendant NAMED for the table was
    #    lighting four metres of empty floor beside it. LT_WC sat at
    #    -4.30 with the restroom out at -10.65 — a different corner of
    #    a different part of the room. A fixture named for the thing it
    #    is over is a promise that regeneration does not keep, and
    #    nothing checked.
    # 2. THE WEST HALF HAD NOTHING AT ALL. Everything except one table
    #    pendant and the darts bulb lived east of x -4.30. The gallery
    #    wall, the songbook terminal, the pool table and the whole
    #    approach to the restroom were lit by spill and by the torch.
    # 3. TWO OF THEM DID NOT EXIST. The pendant loop ran over TABLES
    #    taking even indices, which was four pendants when there were
    #    eight tables and is two now there are three. The state director
    #    still asked for TAB4 and TAB6 by name every time the bar
    #    changed hours, found nothing, and warned into a log nobody
    #    reads. See harukiya_state_director, which no longer keeps a
    #    hand-written list for exactly this reason.
    #
    # The plan is the Belchi Lorente study's, which is the plan the room
    # was rebuilt to: SMALL WARM SOURCES HUNG CLOSE OVER PEOPLE, and
    # nothing lighting the room in general. One over each table, one
    # over the pool, two under the counter canopy, one at each end of
    # each long wall, two on the stage. You read the room by the pools,
    # and the dark between them is the point.
    #
    # Sixteen fixtures against LightRig's budget of fourteen: standing
    # anywhere in the room the two that lose are the street lobby and
    # the stair bulb, which are up the shaft behind you and correct to
    # drop. That is the intended margin and not an accident.
    mk.append({"kind": "cage_bulb", "id": "F01_BAR_LT_LOBBY",
               "unit": "SITE", "pos": [4.875, -29.30, 2.30],
               "yaw_deg": 0, "network": "electrical", "range": 3.5,
               "energy": 0.46, "navigation": True, "standby": 0.35,
               "exterior": True})
    mk.append({"kind": "cage_bulb", "id": "F01_BAR_LT_STAIR",
               "unit": "SITE", "pos": [5.30, -32.60, 0.55],
               "yaw_deg": 0, "network": "electrical", "range": 3.5,
               "energy": 0.46, "navigation": True, "standby": 0.35,
               "exterior": True})
    # Under the canopy, over the counter's 5.2 m run. Re-spaced: the old
    # pair sat at -3.2 and -0.9, both west of the counter's midpoint,
    # leaving its east end and the last two stools in shadow.
    for i, lx in enumerate((-3.20, -0.25)):
        mk.append({"kind": "kitchen_linear", "id": "F01_BAR_LT_CAN%d" % i,
                   "unit": "SITE", "pos": [lx, -29.70, -1.06],
                   "yaw_deg": 90, "network": "electrical", "range": 5.0,
                   "energy": 0.70, "navigation": True, "standby": 0.4,
                   "exterior": True})
    # OVER THE POOL TABLE, which is at (-8.40..-6.40, -31.90..-30.60).
    # Reaching wide: a pool pendant's whole job is to light the felt hard
    # and leave the room around it alone, which is also the best thing
    # that happens to this room visually.
    #
    # THE Z IS A CEILING ANCHOR, NOT THE LAMP. pendant_shade hangs a
    # 0.55 m cord and its diffuser sits 0.755 m below the marker, so the
    # first attempt at "hung low, like a pool light" put the marker at
    # -1.05 and landed the shade 21 cm off the felt — a lamp standing on
    # the table. It renders as exactly that, which is how it was caught.
    # -0.60 puts the diffuser 0.665 m over the slate, which is where a
    # pool light goes, and 1.445 m off the floor — just clear of the
    # 1.41 m eye line, so it lights the table without being in the face
    # of whoever is walking round it to take the shot.
    mk.append({"kind": "pendant_shade", "id": "F01_BAR_LT_POOL",
               "unit": "SITE", "pos": [-7.40, -31.25, -0.60],
               "yaw_deg": 0, "network": "electrical", "range": 4.2,
               "energy": 0.66, "navigation": True, "standby": 0.4,
               "exterior": True})
    # A low pendant over EVERY table. The old loop lit every other one,
    # which was defensible at eight tables and leaves a third of the
    # room's seating dark at three. Ids come off the enumeration, so a
    # table added or removed can no longer strand a fixture id.
    #
    # RAISED from -0.82, which hung the drum from -1.33 to -1.57 — with
    # the eye line at -1.39, dead centre of it. You could not get your
    # head there (the table is in the way) so it was not a collision, but
    # every shot across the room had a lampshade the size of a doorway
    # sitting in the middle of it, which is how it was noticed. -0.62
    # puts the diffuser 0.685 m over the table — where a pendant hung
    # over people actually goes — and just above the eye line.
    for i, (tx, ty, _s) in enumerate(TABLES):
        mk.append({"kind": "pendant_shade",
                   "id": "F01_BAR_LT_TAB%d" % i, "unit": "SITE",
                   "pos": [tx, ty, -0.62], "yaw_deg": 0,
                   "network": "electrical", "range": 3.6,
                   "energy": 0.52, "navigation": True, "standby": 0.35,
                   "exterior": True})
    for i, sx in enumerate((-1.90, 0.50)):
        mk.append({"kind": "cage_bulb", "id": "F01_BAR_LT_STAGE%d" % i,
                   "unit": "SITE", "pos": [sx, -36.55, -0.95],
                   "yaw_deg": 0, "network": "electrical", "range": 3.6,
                   "energy": 0.60, "navigation": True, "standby": 0.3,
                   "exterior": True})
    # EAST WALL, over the deck. One globe was centred on the middle
    # banquette and left the other two and the arcade corner dark; two
    # put a light over each end of the lounge instead of over its
    # midpoint. Facing back into the room (yaw 270) off the wall at
    # RX1 = 4.00.
    for i, dy in enumerate((-36.60, -33.20)):
        mk.append({"kind": "sconce_globe", "id": "F01_BAR_LT_DECK%d" % i,
                   "unit": "SITE", "pos": [3.92, dy, -1.30],
                   "yaw_deg": 270, "network": "electrical", "range": 3.4,
                   "energy": 0.55, "navigation": True, "standby": 0.35,
                   "exterior": True})
    # WEST WALL, and this is the half of the room that had nothing. Two
    # globes on the gallery wall at RX0 = -11.50, facing east: they light
    # the eleven frames (which are the wall's entire reason to exist and
    # were invisible), the songbook terminal at -11.34, and the way down
    # to the restroom. Placed BETWEEN the frames' run and the corners
    # rather than at the wall's midpoint, so the pool table's approach
    # and the darts oche each get one.
    for i, wy in enumerate((-35.40, -31.30)):
        mk.append({"kind": "sconce_globe", "id": "F01_BAR_LT_WEST%d" % i,
                   "unit": "SITE", "pos": [-11.34, wy, -1.30],
                   "yaw_deg": 90, "network": "electrical", "range": 3.6,
                   "energy": 0.55, "navigation": True, "standby": 0.35,
                   "exterior": True})
    # IN THE RESTROOM, not five metres outside it. The cubicle is
    # x -11.50..-9.80, y -37.90..-36.25 with its door at -10.85..-10.15;
    # this hangs over the middle of that, between the toilet at -11.15
    # and the basin at -10.10.
    mk.append({"kind": "cage_bulb", "id": "F01_BAR_LT_WC",
               "unit": "SITE", "pos": [-10.62, -37.10, FLR + 2.35],
               "yaw_deg": 0, "network": "electrical", "range": 2.5,
               "energy": 0.48, "navigation": True, "standby": 0.35,
               "exterior": True})

    # =================== THE WALLS OF THE WORLD =======================
    # THE SCAFFOLDING IS GONE (2026-08-08, on request). Three bays of
    # poles, two boarded decks and four hoardings used to close both ends
    # of the near pavement, and the whole set piece turned out to be
    # doing nothing a building was not already doing: nw1's corner sits
    # at x -20.2 with its face on y -14.2, which leaves 0.40 m of walk —
    # a gap no 0.60 m capsule fits through — and ne1 does exactly the
    # same at +20.2. The world ended twice, once by architecture and
    # once by plywood in front of it.
    #
    # So the plywood goes and the architecture keeps the job, which is
    # the better version of the same rule: you stop because the block
    # ends, not because somebody boarded it. What it opens is the 4.4 m
    # of nbr_w frontage immediately west of the Orison's own door — the
    # north side's only reachable shopfront, and now the druggist.
    for tag, dx0, dx1, bxx in (("w", -22.6, -19.9, -19.55),
                               ("e", 19.9, 22.6, 19.55)):
        fb("dig_%s_pit" % tag, (dx0, -23.7, dx1, -14.9), -0.55, 0.53,
           "soot")
        fb("dig_%s_spoil" % tag, (dx0 + 0.4, -18.6, dx1 - 0.4, -16.4),
           0.0, 0.85, "soil")
        fb("dig_%s_plank" % tag, (dx0 + 0.8, -21.9, dx1 - 0.8, -21.3),
           0.02, 0.06, "plywood")
        for i in range(4):
            asm("dig_%s_bar%d" % (tag, i), "safety_barrier", bxx,
                -15.9 - i * 2.1, 90 if tag == "w" else -90)
    # THE PARADE IS OPEN NOW, and this moves a line that was drawn on
    # purpose, so it is worth saying why. Route discipline (below) closed
    # the far pavement "beyond the bar's own block" when the far pavement
    # was a facade — ten sectioned shopfronts with solid brick behind the
    # glass and nothing to walk to. It is not that any more: there are
    # ten sales floors, seven arcade cabinets and ten working doors down
    # there, and a hoarding at x -6.6 put every one of them out of reach.
    #
    # The DISCIPLINE is untouched, only its extent. The roadway still has
    # four trenches across it and the zebra in front of the Orison's door
    # is still the only way over; you still cannot wander off the block.
    # The walkable world simply has a fourth path now — the parade — and
    # it ends at the two ends of the row rather than in the middle of it.
    fb("hoard_s_w", (-33.20, -28.30, -33.00, -23.95), 0.0, 2.55,
       "plywood")
    fb("hoard_s_e", (32.00, -28.30, 32.20, -23.95), 0.0, 2.55, "plywood")
    fb("alley_fence_w", (-16.35, 10.0, -16.20, 14.9), 0.0, 2.4, "metal")
    fb("alley_fence_e", (16.20, 10.0, 16.35, 14.9), 0.0, 2.4, "metal")
    fb("dumpster", (13.8, 11.0, 16.0, 12.6), 0.0, 1.35, "metal")
    fb("dumpster_lid", (13.75, 11.0, 16.05, 12.65), 1.35, 0.09, "soot")
    for i, (px, py) in enumerate(((16.3, -14.35), (17.6, -14.35),
                                  (18.9, -14.35), (-16.3, -14.35),
                                  (-17.6, -14.35), (-18.9, -14.35),
                                  (16.6, -12.35), (20.4, -12.35))):
        pipe("bollard%d" % i, (px, py, 0.0), (px, py, 0.95), 0.085)
    # ---- ROUTE DISCIPLINE: the walkable world is four paths ---------
    # (1) the Orison's circumference: front walk between the gangways,
    #     the gangways themselves, the alley behind between the fences;
    # (2) the crossing to the Harukiya, inside the trench corridor;
    # (3) the walk east to the bodega;
    # (4) THE PARADE — the far pavement, the full length of the ten
    #     shopfronts, added when they stopped being a facade.
    # Everything else ends diegetically. Two more utility trenches cut
    # the roadway so the only crossing is STILL the one in front of the
    # door: opening the far pavement does not open the road, and you
    # reach the parade by walking over the zebra like anybody else.
    # walk_w_hoard is gone with the scaffolding it belonged to. It stood
    # at x -15.55, which is 350 mm west of the Orison's own west wall —
    # so the near pavement ended the instant you left the building, and
    # the 4.4 m of shopfront next door had never been reachable at all.
    for tag, dx0, dx1, bxx in (("mw", -8.4, -6.4, -6.15),
                               ("me", 10.6, 12.6, 12.85)):
        fb("dig_%s_pit" % tag, (dx0, -23.7, dx1, -14.9), -0.55, 0.53,
           "soot")
        fb("dig_%s_spoil" % tag, (dx0 + 0.3, -19.6, dx1 - 0.3, -17.6),
           0.0, 0.75, "soil")
        for i in range(4):
            asm("dig_%s_bar%d" % (tag, i), "safety_barrier", bxx,
                -15.9 - i * 2.1, 90 if tag == "mw" else -90)
    # The inner pair that used to stand at x -6.6 and 10.4 is GONE. They
    # narrowed the far pavement to the 17 m in front of the bar's own
    # block, which was right when there was nothing either side of it and
    # is the single thing that made ten new interiors unreachable. The
    # outer pair above still ends the world; it just ends it at the ends
    # of the parade.
    # THE CROSSING. The route discipline above says the only way over
    # the road is in front of the door; until now nothing on the ground
    # said so. Ladder markings from kerb to kerb, aligned on the Orison
    # entrance and wide enough for two people to pass.
    for i in range(9):
        zx = 0.55 + i * 0.72
        fb("zebra%d" % i, (zx, KERB_S + 0.10, zx + 0.42, KERB_N - 0.10),
           0.002, 0.006, "linen")
    for tag, zy in (("n", KERB_N - 0.12), ("s", KERB_S + 0.06)):
        fb("zebra_bar_%s" % tag, (0.35, zy, 6.85, zy + 0.06), 0.002,
           0.006, "linen")
    asm("street_crate0", "crate", -13.3, -13.9, 25)
    asm("street_crate1", "crate", -12.9, -13.3, 70)
    asm("street_bottles", "bottles", 12.3, -13.6, 0)
    asm("street_papers", "papers", 5.2, -24.1, 15)
    # Bin bags pushed back against the building line. They were sitting
    # at y -13.3, which is the middle of the only walk east to the
    # bodega, and a resident's route should not be an obstacle course.
    fb("binbags", (8.9, -10.85, 10.1, -10.25), 0.0, 0.55, "soot")
    fb("binbags2", (9.3, -11.10, 10.0, -10.80), 0.0, 0.38, "soot")

    # The old BAND 1 scenery relief ended here.  Four solid glass/riser/gate
    # strips on the south facade and one on nbr_w once suggested shops that
    # did not exist.  _storefronts now owns those exact elevations, including
    # real openings, so retaining the flats put a second locked facade across
    # five of the eleven doors.


def street_lamp_markers(fl):
    """The lamps were geometry with nothing inside them, so the pavement
    they stand on was as black as the road. Sodium heads at 2000 K, which
    is the warmest thing in the exterior palette and reads instantly as
    street rather than interior."""
    for i in range(int(SITE_X * 2 / 11.0)):
        lx = -SITE_X + 5.0 + i * 11.0
        if abs(lx) < 3.0 or abs(lx) > 34.0:
            continue      # clear of the stoop; distant ones stay scenery
        fl["markers"].append({
            "kind": "street_lamp", "id": "F01_STREETLAMP_%02d" % i,
            "unit": "SITE", "pos": [lx + 0.06, -14.49, 4.55],
            "yaw_deg": 0, "network": "electrical",
            "range": 8.5, "energy": 0.42,
            "navigation": True, "standby": 0.25})


def _street_furniture(fb, rng):
    # lamps down both pavements, spaced like real ones rather than
    # bracketing the doorway
    # Both pavements, at last. The comment always claimed both; the far
    # one was 0.80 m wide and had nowhere to stand a pole. The south row
    # is offset half a bay so the two sides alternate down the street
    # instead of standing in facing pairs, which is how they are actually
    # set out.
    for i in range(int(SITE_X * 2 / 11.0)):
        lx = -SITE_X + 5.0 + i * 11.0
        if abs(lx) >= 3.0:          # keep the stoop approach clear
            fb("lamp_pole%d" % i, (lx, -14.55, lx + 0.12, -14.43), 0.0,
               4.6, "metal")
            fb("lamp_head%d" % i, (lx - 0.15, -14.7, lx + 0.27, -14.28),
               4.6, 0.25, "metal")
        sx = lx + 5.5
        if -SITE_X < sx < SITE_X:
            fb("lamp_s_pole%d" % i, (sx, WALK_S + 0.12, sx + 0.12,
               WALK_S + 0.24), 0.0, 4.6, "metal")
            fb("lamp_s_head%d" % i, (sx - 0.15, WALK_S - 0.03, sx + 0.27,
               WALK_S + 0.39), 4.6, 0.25, "metal")
    fb("hydrant", (-3.4, -10.85, -3.05, -10.5), 0.0, 0.75, "metal")
    fb("hydrant_cap", (-3.45, -10.9, -3.0, -10.45), 0.75, 0.12, "metal")
    # traffic signal on the corner, mast arm over the road
    # A mast arm reaches OUT OVER the carriageway and hangs the head above
    # the lane it governs. This one ran along the kerb line and stopped
    # there, because there was no carriageway to reach over.
    fb("signal_pole", (17.4, -14.5, 17.62, -14.28), 0.0, 5.6, "metal")
    fb("signal_arm", (17.4, ROAD_MID, 17.52, -14.33), 5.3, 0.12, "metal")
    fb("signal_head", (17.28, ROAD_MID - 0.22, 17.64, ROAD_MID + 0.22),
       4.6, 0.85, "soot")
    # mailbox, papers, a bench, a phone booth: the small municipal clutter
    fb("mailbox", (7.6, -13.6, 8.35, -12.85), 0.0, 1.15, "metal")
    for i in range(3):
        fb("newsbox%d" % i, (-8.6 + i * 0.62, -13.5, -8.1 + i * 0.62,
           -12.95), 0.0, 1.05, "metal")
    # Pulled 25 cm back toward the kerb. Where it stood it left exactly
    # 1.0 m of pavement between its back and the shopfronts, and a body
    # is 0.66 m wide — so the walk east to the bodega threaded a gap
    # with 17 cm to spare on each side and caught the bench instead.
    fb("bench_seat", (10.4, -13.75, 12.6, -13.15), 0.44, 0.07, "timber")
    for bx in (10.5, 12.4):
        fb("bench_leg%d" % int(bx), (bx, -13.70, bx + 0.1, -13.20), 0.0,
           0.44, "metal")
    fb("booth", (-12.4, -13.7, -11.5, -12.8), 0.0, 2.3, "metal")
    fb("booth_glass", (-12.3, -13.6, -11.6, -12.9), 0.7, 1.35, "glassish")
    # THE KERBS ARE EMPTY ON PURPOSE (2026-08-11).
    #
    # Sixteen parked cars used to line both sides, plus a bus shelter on the
    # south walk. All of it is gone, because the carriageway stops being scenery
    # and becomes the thing you cross: a live stream of traffic entering and
    # leaving the block at either end. Parked cars would fight that in three
    # separate ways - they hide oncoming traffic from a player judging a gap,
    # they cost submissions on the worst-performing station in the game
    # (street elevation, 33.3 ms against a 16.6 target), and a street where
    # every vehicle is switched off reads as a diorama no matter what drives
    # through it.
    #
    # THE SHELTER IS NOT CANCELLED, only unplaced. It was 4.4 x 1.4 m with a
    # 2.45 m roof, a glazed back with a centre mullion and a timber bench, and
    # it wants to come back at a stop the new traffic actually serves - which
    # is a decision for the street brief, not for whatever coordinate it
    # happened to sit on. Its last position was the south walk at
    # (-12.6, -25.55). See design/ORISON_STREET_BRIEF.md.
    fb("bin1", (12.6, 10.3, 13.6, 11.1), 0.0, 1.1, "metal")
    fb("bin2", (-13.9, 10.3, -12.9, 11.2), 0.0, 1.15, "metal")
    fb("dumpster", (5.4, 10.4, 8.2, 11.9), 0.0, 1.35, "metal")
    # power poles and spans, west to east behind the block
    fb("power_pole", (16.2, 11.0, 16.5, 11.3), 0.0, 8.5, "timber")
    fb("power_line", (10.5, 11.05, 16.2, 11.12), 7.6, 0.05, "metal")
    for i, px in enumerate((-24.0, -2.0, 22.0, 44.0)):
        fb("pole%d" % i, (px, -14.9, px + 0.28, -14.62), 0.0, 9.2,
           "timber")
        fb("crossarm%d" % i, (px - 1.1, -14.85, px + 1.4, -14.7), 8.2,
           0.12, "timber")
        if i:
            fb("span%d" % i, (px - 22.0, -14.82, px, -14.76), 7.9, 0.05,
               "metal")
    # fire escapes on the two immediate neighbours, street side
    for eid, ex in (("fe_w", -17.9), ("fe_e", 16.4)):
        for lvl in range(4):
            z = 3.2 + lvl * 3.2
            fb("%s_deck%d" % (eid, lvl), (ex, -12.35, ex + 1.5, -11.05),
               z, 0.08, "metal")
            fb("%s_rail%d" % (eid, lvl), (ex, -11.15, ex + 1.5, -11.05),
               z, 0.95, "metal")
            fb("%s_stair%d" % (eid, lvl), (ex + 0.2, -12.3, ex + 1.0,
               -11.2), z - 1.6, 1.6, "metal")


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
        landing = {"kind": "landing", "z": lz,
                   "rect": [wx0, land_edge, wx1, wy1],
                   # Approved on F04 before promotion.  A 180-degree flip on
                   # alternate storeys keeps adjacent soffits from presenting
                   # the same water bloom in the same direction.
                   "soffit_finish": "fx_ceiling_soffit_failed",
                   "soffit_flip": i % 2 == 1,
                   "guard_edge": "s", "guard_span": [wx0 + w, wx1 - w]}
        parts.append(landing)
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
    problems += _validate_vantry_points(layout)
    problems += _validate_kettles(layout)
    problems += _validate_boxfans(layout)
    problems += _validate_ventilation(layout)
    problems += _validate_flue_fittings(layout)
    problems += _validate_ceilings(layout)
    problems += _validate_shop_interiors(layout)
    problems += life_pass(layout["floors"])
    return problems


def _validate_ceilings(layout):
    """Every enclosed room remains covered when the storey above is hidden."""
    problems = []
    floors = layout["floors"]
    for floor_i, fl in enumerate(floors):
        if fl["id"] == "ROOF":
            continue
        ceilings = fl.get("ceilings", [])
        if not ceilings:
            problems.append("%s owns no ceiling faces" % fl["id"])
            continue
        # B1 is taller than the repeated residential storeys.  The lawful
        # soffit is always the underside of the next slab, not an assumed
        # WALL_H above this floor's datum.
        expected_z = (float(floors[floor_i + 1]["z"])
                      - SLAB_T - 0.005)
        for face in ceilings:
            if abs(float(face["z"]) - expected_z) > 0.011:
                problems.append("%s ceiling escaped its soffit" % face["id"])
            if face.get("mat") not in ("plaster", "plaster_stained",
                                        "tin_ceiling"):
                problems.append("%s names unsupported finish %s" %
                                (face["id"], face.get("mat")))
        # Subtract the faces from each room. Slab holes are lawful absences;
        # anything left after both operations is a patch of open sky.
        holes = [tuple(h) for h in fl["slabs"][0].get("holes", [])]
        for room in fl.get("rooms", []):
            if room.get("kind") == "roof":
                continue
            remainder = [tuple(room["rect"])]
            for hole in holes:
                remainder = subtract_rect(remainder, hole)
            for face in ceilings:
                remainder = subtract_rect(remainder, tuple(face["rect"]))
            leaked = sum(rect_area(r) for r in remainder)
            if leaked > 0.002:
                problems.append("%s has %.3f m2 open ceiling" %
                                (room["id"], leaked))
    return problems


def _validate_ventilation(layout):
    """The shared system replaces one private fan; neither half may drift."""
    problems = []
    baths = [r for fl in layout["floors"] for r in fl.get("rooms", [])
             if r.get("kind") == "bathroom"]
    registers = layout.get("ventilation_registers", [])
    fans = [m for fl in layout["floors"] for m in fl.get("markers", [])
            if m.get("kind") == "exhaust_fan"]
    if len(baths) != 23 or len(registers) != len(baths):
        problems.append("ventilation expected 23 baths/registers, got %d/%d" %
                        (len(baths), len(registers)))
    if len({r.get("room") for r in registers}) != len(baths):
        problems.append("bathroom ventilation registers are not one-per-room")
    if len(fans) != 4 or {m.get("riser") for m in fans} != {
            "V-A", "V-B", "V-C", "V-D"}:
        problems.append("roof ventilation expected four distinct riser owners")
    if any(m.get("unit") or m.get("network") != "ventilation" for m in fans):
        problems.append("central roof ventilator regressed to a private/electrical fan")
    if any(r.get("network") != "ventilation" for r in registers):
        problems.append("bathroom register escaped the ventilation network")
    points = {p.get("room"): p for p in layout.get("vantry_points", [])}
    for reg in registers:
        point = points.get(reg.get("room"))
        if point and math.hypot(float(reg["pos"][0]) - float(point["pos"][0]),
                                float(reg["pos"][1]) - float(point["pos"][1])) < 0.24:
            problems.append("%s crowds its Vantry point" % reg["id"])
    return problems


def _validate_flue_fittings(layout):
    """Five sealed thimbles stay seated, named and clear at head height.

    Marker ID is deliberately NOT derived from the corrected room/unit.  It is
    the runtime graph binding key, and renaming it would leave a beautiful
    fitting that never answers the flue.
    """
    problems = []
    floors = {fl["id"]: fl for fl in layout["floors"]}
    expected = {fid: (unit_name(fid, "C"), "%s_C_BED2" % fid)
                for fid in ("F02", "F03", "F04", "F05", "F06")}
    found = []
    for fl in layout["floors"]:
        found.extend((fl, m) for m in fl.get("markers", [])
                     if m.get("kind") == "flue_breast")
    if len(found) != 5:
        problems.append("flue fittings expected five owners, got %d" % len(found))
    for fid, (unit, room_id) in expected.items():
        fl = floors.get(fid, {})
        marker = next((m for m in fl.get("markers", [])
                       if m.get("kind") == "flue_breast"), None)
        if marker is None:
            problems.append("%s has no sealed flue fitting" % fid)
            continue
        expected_id = "%s_FLUE_BREAST" % fid
        if marker.get("id") != expected_id:
            problems.append("%s binding id changed to %s" %
                            (expected_id, marker.get("id")))
        if marker.get("unit") != unit or marker.get("room") != room_id:
            problems.append("%s has unit/room %s/%s, expected %s/%s" %
                            (expected_id, marker.get("unit"), marker.get("room"),
                             unit, room_id))
        if not any(r.get("id") == room_id for r in fl.get("rooms", [])):
            problems.append("%s names missing bedroom %s" % (expected_id, room_id))
        pos = marker.get("pos", [])
        if (len(pos) < 3 or abs(float(pos[0]) - 10.0) > 0.001 or
                abs(float(pos[1]) - float(CHIMNEY[1])) > 0.001 or
                abs(float(pos[2]) - float(fl.get("z", 0.0))) > 0.001):
            problems.append("%s is not seated on the chimney face" % expected_id)
            continue
        # 310 mm plate plus tolerance; 50 mm projection toward the bedroom.
        fitting = (9.825, float(CHIMNEY[1]) - 0.055,
                   10.175, float(CHIMNEY[1]) + 0.005)
        for item in fl.get("furniture", []):
            rect = item.get("rect")
            if not rect or len(rect) < 4:
                continue
            z0 = float(item.get("z0", 0.0))
            z1 = z0 + float(item.get("h", 0.0))
            # The plate spans 1.275..1.605 m. Floor rugs and low bed frames
            # are harmless; a headboard, tall case or wall picture is not.
            if z1 < 1.265 or z0 > 1.615:
                continue
            overlap = (float(rect[0]) < fitting[2] and fitting[0] < float(rect[2])
                       and float(rect[1]) < fitting[3]
                       and fitting[1] < float(rect[3]))
            if overlap:
                name = str(item.get("id", "furniture"))
                role = "bed/headboard" if ("bed" in name.lower()
                        or "head" in name.lower()) else "furniture/art"
                problems.append("%s intersects %s %s" %
                                (expected_id, role, name))
    return problems


def _validate_flue_graph(layout, graph):
    """Generated graph must carry corrected metadata without rebinding IDs."""
    problems = []
    nodes = {n.get("id"): n for n in graph.get("nodes", [])}
    for fid in ("F02", "F03", "F04", "F05", "F06"):
        marker_id = "%s_FLUE_BREAST" % fid
        unit = unit_name(fid, "C")
        node = nodes.get(marker_id)
        if node is None:
            problems.append("%s missing from generated acoustic graph" % marker_id)
            continue
        if node.get("room") != unit:
            problems.append("%s graph room is %s, expected %s" %
                            (marker_id, node.get("room"), unit))
        if node.get("network") != "flue":
            problems.append("%s escaped the flue network" % marker_id)
        if "%s_FLUE" % fid not in node.get("connections", []):
            problems.append("%s no longer reaches its floor trunk" % marker_id)
    return problems


def _validate_shop_interiors(layout):
    """The second pass stays complete, owned and cheap enough to remain static.

    Box count is a content-growth alarm, not a draw-call claim.  Blender owns
    the stronger local-buffer assertion; windowed Perf owns rendered calls.
    """
    problems = []
    f01 = next((fl for fl in layout["floors"] if fl["id"] == "F01"), {})
    furniture = f01.get("furniture", [])
    boxes = [fu for fu in furniture
             if str(fu.get("batch", "")).startswith("shop_")]
    expected = {"shop_%s" % "".join(
        c if c.isalnum() else "_" for c in name.lower()).strip("_")
        for _x0, _x1, name, _trade, _a, _b, _use in SHOPS + SHOPS_N}
    actual = {fu.get("batch") for fu in boxes}
    if actual != expected:
        problems.append("shop batch ownership expected %s, got %s" %
                        (sorted(expected), sorted(actual)))
    if len(boxes) > 1080:
        problems.append("shop static boxes %d exceed second-pass cap 1080"
                        % len(boxes))
    if any(not fu.get("batch") for fu in furniture
           if str(fu.get("id", "")).startswith("storm_shop_")):
        problems.append("unowned storm shop box escaped local batching")
    heroes = {fu.get("hero") for fu in boxes if fu.get("hero")}
    expected_heroes = {trade for _x0, _x1, _name, trade, _a, _b, _use
                       in SHOPS + SHOPS_N} - {"funeral"}
    if heroes != expected_heroes:
        problems.append("isolated shop heroes expected %s, got %s" %
                        (sorted(expected_heroes), sorted(heroes)))
    ledgers = [fu for fu in boxes if str(fu.get("id", "")).endswith(
               ("_ledger", "_book"))]
    if len(ledgers) != 11:
        problems.append("every shop needs one account book; found %d"
                        % len(ledgers))
    laundry = [fu for fu in boxes if fu.get("batch") == "shop_model_laundry"]
    obsolete = [fu["id"] for fu in laundry
                if "_wash" in fu["id"] or "_dry" in fu["id"]]
    if obsolete:
        problems.append("hand laundry still contains automatic machines: %s"
                        % obsolete)
    news_door = next((m for m in f01.get("markers", [])
                      if m.get("id") == "SITE_SHOP_DOOR_NEWS_CIGARS"), {})
    if news_door.get("leaf") != "locked":
        problems.append("news booth proprietor door must stay locked")
    return problems


def _validate_kettles(layout):
    """Six authored households, including the 4C evidence object."""
    problems = []
    kettles = [m for fl in layout["floors"] for m in fl.get("markers", [])
               if m.get("kind") == "kettle"]
    units = {m.get("unit") for m in kettles}
    if len(kettles) != 6 or units != KETTLE_UNITS:
        problems.append("kettles must be exactly %s, got %s" %
                        (sorted(KETTLE_UNITS), sorted(units)))
    four_c = [m for m in kettles if m.get("unit") == "4C"]
    if len(four_c) != 1 or four_c[0].get("case_id") != "4519":
        problems.append("4C kettle lost case 4519 evidence binding")
    four_b = [m for m in kettles if m.get("unit") == "4B"]
    if len(four_b) == 1:
        # 200 mm centre spacing - 90 mm kettle radius - 60.5 mm of the
        # crosswise toaster leaves 49.5 mm. That is the whole margin.
        clearance = abs(float(four_b[0]["pos"][0]) - (-10.70)) - 0.09 - 0.0605
        if clearance < 0.048:
            problems.append("4B kettle/toaster clearance fell below 48 mm")
    return problems


def _validate_boxfans(layout):
    """Four households, grounded, room-owned and clear of fixed furniture.

    The family has two authoring paths: three dress_unit markers and 4B's
    bespoke marker.  This deliberately counts the finished layout so neither
    path can disappear behind a locally green assertion.
    """
    problems = []
    fans = [(fl, m) for fl in layout["floors"]
            for m in fl.get("markers", []) if m.get("kind") == "boxfan"]
    units = {m.get("unit") for _fl, m in fans}
    if len(fans) != 4 or units != BOXFAN_UNITS:
        problems.append("boxfans must be exactly %s, got %s" %
                        (sorted(BOXFAN_UNITS), sorted(units)))
    for fl, fan in fans:
        if fan.get("network") != "electrical":
            problems.append("%s escaped its electrical circuit" % fan["id"])
        if abs(float(fan["pos"][2]) - float(fl["z"])) > 0.011:
            problems.append("%s is not seated on the floor" % fan["id"])
        room_id = fan.get("room", "")
        room = next((r for r in fl["rooms"] if r.get("id") == room_id), None)
        px, py = fan["pos"][:2]
        if room is None or not (room["rect"][0] <= px <= room["rect"][2]
                                and room["rect"][1] <= py <= room["rect"][3]):
            problems.append("%s escaped authored room %s" %
                            (fan["id"], room_id))
            continue
        # A 500 mm square is conservative for the 310 x 230 mm base at an
        # arbitrary yaw and leaves a hand-width service halo around the cage.
        body = (px - 0.25, py - 0.25, px + 0.25, py + 0.25)
        for oid, obstacle in _obstacles(fl):
            if oid == fan["id"]:
                continue
            if _hit(obstacle, *body):
                problems.append("%s overlaps %s" % (fan["id"], oid))
    return problems


def _validate_vantry_points(layout):
    """The ceiling network is complete, separate, and physically installed.

    Counting the room source rather than freezing ``119`` here lets the
    assertion survive a legitimate room addition while still failing the
    moment a room silently loses its listening head.
    """
    problems = []
    rooms = {r["id"]: (fl, r) for fl in layout["floors"]
             for r in fl["rooms"] if r.get("kind") not in ("roof", "atrium")}
    points = layout.get("vantry_points", [])
    ids = [p.get("id", "") for p in points]
    if len(points) != len(rooms):
        problems.append("Vantry coverage %d points for %d enclosed rooms"
                        % (len(points), len(rooms)))
    if len(ids) != len(set(ids)):
        problems.append("duplicate Vantry point id")
    for point in points:
        room_id = point.get("room", "")
        if room_id not in rooms:
            problems.append("%s names missing room %s"
                            % (point.get("id", "Vantry point"), room_id))
            continue
        fl, room = rooms[room_id]
        x0, y0, x1, y1 = room["rect"]
        px, py, pz = point["pos"]
        if not min(x0, x1) <= px <= max(x0, x1) or \
                not min(y0, y1) <= py <= max(y0, y1):
            problems.append("%s falls outside %s" % (point["id"], room_id))
        expected_z = float(fl["z"]) + WALL_H
        if abs(float(pz) - expected_z) > 0.011:
            problems.append("%s is not seated on its ceiling" % point["id"])
        if point.get("network") != "signal":
            problems.append("%s escaped the Vantry signal circuit"
                            % point["id"])
    if any(m.get("kind") == "smoke_detector" for fl in layout["floors"]
           for m in fl.get("markers", [])):
        problems.append("legacy smoke-detector marker survived Vantry ruling")
    return problems


def _validate_placement(layout):
    """Catch prop-height and wall-center regressions before export."""
    problems = []
    # eye_pendant is no longer one: the court's light is a collar built
    # into the central pillar at head height, not a fitting hanging from a
    # ceiling the light court does not have.
    ceiling_kinds = {"pendant_shade", "flush_dome", "kitchen_linear",
                     "cage_bulb", "chandelier"}
    wall_kinds = {"door", "radiator", "sconce_globe", "exhaust_fan",
                  "wall_clock", "flue_breast", "door_anomaly", "case_door",
                  "neon_sign"}   # bolted to the facade, by definition
    floor_kinds = {"washer", "laundry_airer", "boiler", "fridge", "stove", "boxfan",
                   "speaker", "toaster", "kettle"}

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
            if m.get("exterior"):
                # Retail markers live at street furniture heights and,
                # for the basement bar, at NEGATIVE z relative to their
                # floor. Their placement is authored against their own
                # interior, not against a storey the validator knows.
                continue
            kind = m["kind"]
            px, py, pz = m["pos"]
            # B1 is a 2.8 m storey: its ceiling sits at +2.62, so its
            # fixtures mount ~0.4 lower than the 3.2 m floors above
            clo, chi = (2.40, 2.60) if fl["id"] == "B1" else (2.70, 3.08)
            # The roof has no ceiling. Its lights hang off a pergola beam
            # and a garden post, so a ceiling height is not a thing they
            # can be measured against.
            if fl["id"] == "ROOF":
                clo, chi = 0.0, 4.0
            # Same reasoning as the roof: a fitting hung under an
            # exterior canopy is not mounted to a storey ceiling, so a
            # storey ceiling height is not a thing it can be wrong about.
            if kind in ceiling_kinds and not m.get("exterior")                     and not z + clo <= pz <= z + chi:
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
            # wall-hung flatware (boards, like the mail bank and pedestal
            # backsplash mirrors before them) is *meant* to hug the wall
            # Facade assemblies (marquee, fire escape) are anchored ON
            # the outer face of a wall - being at the wall line is the
            # whole point of them, not a placement mistake.
            if fu.get("exterior"):
                continue
            if "asm" not in fu or fu["asm"] in (
                    "switch", "pipe", "mailbank",
                    "pinboard", "toolboard"):
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
    "kitchen": (0.90, 0.33),
    "desk": (0.71, 0.34), "plantable": (1.01, 0.61),
    "workbench": (1.11, 0.49), "toilet": (0.21, 0.36),
    "bench": (0.76, 0.25),
    "mailbank": (0.81, 0.10),
    # floor-standing personality clutter (tabletop pieces are absent on
    # purpose: they never block a route)
    "amp": (0.31, 0.17), "guitar": (0.20, 0.17),
    "pedalboard": (0.32, 0.18), "micstand": (0.15, 0.15),
    "tripod": (0.32, 0.32), "softbox": (0.28, 0.28), "crate": (0.23, 0.20),
}

# Marker-built obstacles need footprints too. The refrigerator body moved
# out of `furniture`, but it did not stop occupying floor. These are closed
# bounds including the handle, measured from fridge_prop.gd rather than a
# stale baked shell.
FRIDGE_FOOT = {
    False: (0.35, 0.31),       # compact oak apartment icebox
    True: (0.36, 0.34),        # 1927 GE monitor-top
}
# Complete marker-built range: 0.64 m wide, 0.60 m deep. The obsolete
# assembly row was 0.64 x 0.68; keeping it in ASM_FOOT after removing the
# assembly would make a stale table look authoritative to future audits.
STOVE_FOOT = (0.32, 0.30)
BATH_SINK_FOOT = (0.305, 0.28)
SHOWER_FOOT = (0.36, 0.36)
BOXFAN_FOOT = (0.25, 0.25)


# Eight shelves are gameplay owners, not repetitions of the generic steel
# ladder assembly.  Their coordinates are resolved here, beside the walls and
# furniture that constrain them, then written into the layout.  The runtime
# prop is allowed to build a bookcase; it is not allowed to decide where the
# Orison has a solid wall.
BOOKSHELF_OWNERS = (
    ("2A", "Mina Vale", "repaired"),
    ("3A", "Malcolm Reed", "repaired"),
    ("4A", "Peter Wren", "sectional"),
    ("5A", "Nadia Quell", "plain"),
    ("5C", "Iris Bell", "plain"),
    ("6A", "Sacha Reed", "repaired"),
    ("6B", "Jonah Price", "plain"),
    ("6C", "Mae Kessler", "sectional"),
)
BOOKSHELF_SIZE = {
    "repaired": (0.68, 0.25),
    "plain": (0.72, 0.28),
    "sectional": (0.78, 0.30),
}


def bookshelf_pass(floors):
    """Replace eight duplicated dressing shelves with authored hero markers.

    Candidate centres live on solid room-boundary wall runs.  Both the body
    and the 550 mm standing/reach strip in front must stay clear.  Sampling at
    100 mm makes this deterministic and reviewable without pretending the
    prop can renegotiate a furnished room when it loads.
    """
    made = []
    hero_units = {row[0] for row in BOOKSHELF_OWNERS}
    for fl in floors:
        # The generic shelf was the old visual owner.  Leaving it behind makes
        # the rebuild look like two bookcases occupying the same biography.
        fl["furniture"] = [fu for fu in fl.get("furniture", [])
                           if not (fu.get("id") == "%s_shelf" %
                                   str(fu.get("id", ""))[:2]
                                   and str(fu.get("id", ""))[:2]
                                   in hero_units)]
    for unit, owner, style in BOOKSHELF_OWNERS:
        fid = "F%02d" % int(unit[0])
        fl = next(f for f in floors if f["id"] == fid)
        room = next(r for r in fl["rooms"]
                    if r.get("unit") == unit and r.get("kind") == "living")
        x0, y0, x1, y1 = room["rect"]
        width, depth = BOOKSHELF_SIZE[style]
        candidates = []
        for wi, wall in enumerate(fl["walls"]):
            ax, ay = wall["a"]
            bx, by = wall["b"]
            # A door or window anywhere in this short wall run makes it a
            # worse owner than the intact partition opposite it.  The old
            # runtime pass ignored this and put five cases through windows.
            if wall.get("openings"):
                continue
            vertical = abs(ax - bx) < 0.01
            horizontal = abs(ay - by) < 0.01
            if horizontal and (abs(ay - y0) < 0.15 or
                               abs(ay - y1) < 0.15):
                lo, hi = max(min(ax, bx), x0), min(max(ax, bx), x1)
                inward = 1.0 if abs(ay - y0) < abs(ay - y1) else -1.0
                for n in range(int(max(0.0, hi - lo - width) / 0.10) + 1):
                    x = lo + width / 2.0 + n * 0.10
                    y = ay + inward * (depth / 2.0 + 0.025)
                    candidates.append((x, y, 180 if inward > 0 else 0,
                                       wi, "h", inward))
            elif vertical and (abs(ax - x0) < 0.15 or
                               abs(ax - x1) < 0.15):
                lo, hi = max(min(ay, by), y0), min(max(ay, by), y1)
                inward = 1.0 if abs(ax - x0) < abs(ax - x1) else -1.0
                for n in range(int(max(0.0, hi - lo - width) / 0.10) + 1):
                    y = lo + width / 2.0 + n * 0.10
                    x = ax + inward * (depth / 2.0 + 0.025)
                    candidates.append((x, y, -90 if inward > 0 else 90,
                                       wi, "v", inward))
        obstacles = [a for a in (_asm_aabb(fu)
                                  for fu in fl.get("furniture", [])) if a]

        def clear(c):
            x, y, _yaw, _wi, axis, inward = c
            if axis == "h":
                body = (x - width / 2.0, y - depth / 2.0,
                        x + width / 2.0, y + depth / 2.0)
                reach = (body[0], min(body[1], y + inward * 0.70),
                         body[2], max(body[3], y + inward * 0.70))
            else:
                body = (x - depth / 2.0, y - width / 2.0,
                        x + depth / 2.0, y + width / 2.0)
                reach = (min(body[0], x + inward * 0.70), body[1],
                         max(body[2], x + inward * 0.70), body[3])
            for box in obstacles:
                if not (reach[2] <= box[0] or reach[0] >= box[2] or
                        reach[3] <= box[1] or reach[1] >= box[3]):
                    return False
            return True

        legal = [c for c in candidates if clear(c)]
        if not legal:
            raise SystemExit("bookshelf %s has no solid reachable wall" % unit)
        # Prefer the centre of an intact run.  It reads as furniture placed by
        # a resident, not a collision audit that happened to stop at a corner.
        legal.sort(key=lambda c: abs(c[0] - (x0 + x1) / 2.0) +
                   abs(c[1] - (y0 + y1) / 2.0))
        x, y, yaw, wall_i, _axis, _inward = legal[0]
        marker = {
            "kind": "bookshelf", "id": "%s_%s_BOOKSHELF_01" % (fid, unit),
            "unit": unit, "owner": owner, "variant": style,
            "pos": [round(x, 4), round(y, 4), fl["z"]],
            "yaw_deg": yaw, "network": "structural", "wall_index": wall_i,
        }
        if unit == "6C":
            marker["canonical_book"] = "prospectus"
        fl["markers"].append(marker)
        made.append(marker)
    return made


def validate_bookshelves(layout):
    """Build-time cover for facts a runtime prop cannot repair honestly."""
    problems = []
    markers = [(fl, m) for fl in layout["floors"]
               for m in fl.get("markers", []) if m.get("kind") == "bookshelf"]
    if len(markers) != len(BOOKSHELF_OWNERS):
        problems.append("bookshelves: expected 8 markers, found %d" % len(markers))
    if len({m["unit"] for _fl, m in markers}) != len(markers):
        problems.append("bookshelves: duplicate unit ownership")
    for fl, marker in markers:
        wall_i = int(marker.get("wall_index", -1))
        if wall_i < 0 or wall_i >= len(fl["walls"]):
            problems.append("%s: missing authored backing wall" % marker["id"])
            continue
        if fl["walls"][wall_i].get("openings"):
            problems.append("%s: backing wall contains an opening" % marker["id"])
        room = next((r for r in fl["rooms"]
                     if r.get("unit") == marker["unit"] and
                     r.get("kind") == "living"), None)
        px, py = marker["pos"][:2]
        inside = room is not None and room["rect"][0] <= px <= room["rect"][2] \
            and room["rect"][1] <= py <= room["rect"][3]
        if not inside:
            problems.append("%s: authored outside resident living room" %
                            marker["id"])
        if marker["unit"] == "6C" and marker.get("canonical_book") != "prospectus":
            problems.append("6C bookshelf lost the covenant prospectus")
    return problems


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
    for m in fl.get("markers", []):
        kind = m.get("kind")
        if kind == "fridge":
            hx, hy = FRIDGE_FOOT[bool(m.get("monitor", False))]
        elif kind == "stove":
            hx, hy = STOVE_FOOT
        elif kind == "boxfan":
            hx, hy = BOXFAN_FOOT
        elif m.get("fixture") == "bath_sink":
            hx, hy = BATH_SINK_FOOT
        elif m.get("fixture") == "shower":
            hx, hy = SHOWER_FOOT
        else:
            # A kitchen sink is cut into an obstacle already represented by
            # the kitchen run or 4B's raw counter slabs; counting it again
            # invents a second blocker at the same coordinate.
            continue
        yaw = float(m.get("yaw_deg", 0)) % 180
        if yaw == 90:
            hx, hy = hy, hx
        elif yaw not in (0, 90):
            hx = hy = max(hx, hy)
        cx, cy = m["pos"][0], m["pos"][1]
        obs.append((m["id"], (cx - hx, cy - hy, cx + hx, cy + hy)))
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
                if m.get("exterior"):
                    # Exterior leaves are finally audited, but their own
                    # jamb, stall and host-building fabric are not furniture.
                    # Ignore only named architectural ownership; displays,
                    # counters and loose fittings remain blockers.
                    did = m.get("id", "")
                    tag = did.removeprefix("SITE_SHOP_DOOR_").lower()
                    own = ((did.startswith("SITE_SHOP_DOOR_") and
                            (oid.startswith("storm_sf_%s_" % tag) or
                             oid.startswith("sf_%s_" % tag) or
                             oid.startswith("storm_shop_%s_de" % tag))) or
                           (did.startswith("F01_BAR_") and
                            oid.startswith("retail_bar_")) or
                           (did == "SITE_SHOP_DOOR_LUNCHEONETTE" and
                            oid.startswith("retail_bar_")) or
                           (did == "SITE_SHOP_DOOR_OTIS___SON" and
                            oid.startswith("site_nbr_w_")))
                    if own:
                        continue
                if _hit(bb, sw[0] + tol, sw[1] + tol, sw[2] - tol,
                        sw[3] - tol):
                    problems.append("%s: door %s swing blocked by %s"
                                    % (fl["id"], m["id"], oid))
        # Every refrigerator door needs standing room and an honest sweep.
        # This deliberately follows the marker: the old assembly loop skipped
        # all four monitor-tops and vanished entirely when the shell moved to
        # GDScript.
        for m in fl.get("markers", []):
            if m.get("kind") != "fridge":
                continue
            import math as _m
            a = _m.radians(m.get("yaw_deg", 0))
            fx_, fy_ = -_m.sin(a), _m.cos(a)   # local +y (door) in world
            bx0_ = m["pos"][0] + fx_ * 0.82 - 0.36
            by0_ = m["pos"][1] + fy_ * 0.82 - 0.36
            band = (bx0_, by0_, bx0_ + 0.72, by0_ + 0.72)
            for oid, bb in obs:
                if oid == m["id"]:
                    continue
                if _hit(bb, band[0] + 0.06, band[1] + 0.06,
                        band[2] - 0.06, band[3] - 0.06):
                    problems.append("%s: fridge %s door blocked by %s"
                                    % (fl["id"], m["id"], oid))
            # Closed leaf runs from the left hinge across the face; opening
            # carries its free corner forward. The triangle's AABB is a
            # conservative quarter-sweep and catches counters or radiators
            # that a standing-room square can miss.
            width = 0.72 if m.get("monitor", False) else 0.70
            depth = 0.64 if m.get("monitor", False) else 0.58
            rx_, ry_ = _m.cos(a), _m.sin(a)     # local +x in world
            hx_ = m["pos"][0] - rx_ * width * 0.5 + fx_ * depth * 0.5
            hy_ = m["pos"][1] - ry_ * width * 0.5 + fy_ * depth * 0.5
            corners = ((hx_, hy_),
                       (hx_ + rx_ * width, hy_ + ry_ * width),
                       (hx_ + fx_ * width, hy_ + fy_ * width))
            sweep = (min(p[0] for p in corners), min(p[1] for p in corners),
                     max(p[0] for p in corners), max(p[1] for p in corners))
            for oid, bb in obs:
                if oid == m["id"]:
                    continue
                if _hit(bb, sweep[0] + 0.04, sweep[1] + 0.04,
                        sweep[2] - 0.04, sweep[3] - 0.04):
                    problems.append("%s: fridge %s sweep blocked by %s"
                                    % (fl["id"], m["id"], oid))
        # A range needs the same two proofs: a person can stand at its
        # valves, and the bottom-hinged oven leaf can fall through its real
        # 34 cm travel without entering a counter, radiator or refrigerator.
        for m in fl.get("markers", []):
            if m.get("kind") != "stove":
                continue
            import math as _m
            a = _m.radians(m.get("yaw_deg", 0))
            fx_, fy_ = -_m.sin(a), _m.cos(a)   # local +y/front in plan
            rx_, ry_ = _m.cos(a), _m.sin(a)    # local +x/right in plan
            stand_cx = m["pos"][0] + fx_ * 0.72
            stand_cy = m["pos"][1] + fy_ * 0.72
            band = (stand_cx - 0.36, stand_cy - 0.36,
                    stand_cx + 0.36, stand_cy + 0.36)
            for oid, bb in obs:
                if oid == m["id"]:
                    continue
                if _hit(bb, band[0] + 0.06, band[1] + 0.06,
                        band[2] - 0.06, band[3] - 0.06):
                    problems.append("%s: stove %s standing room blocked by %s"
                                    % (fl["id"], m["id"], oid))
            front_x = m["pos"][0] + fx_ * STOVE_FOOT[1]
            front_y = m["pos"][1] + fy_ * STOVE_FOOT[1]
            half_w, reach = 0.22, 0.34
            corners = ((front_x - rx_ * half_w, front_y - ry_ * half_w),
                       (front_x + rx_ * half_w, front_y + ry_ * half_w),
                       (front_x - rx_ * half_w + fx_ * reach,
                        front_y - ry_ * half_w + fy_ * reach),
                       (front_x + rx_ * half_w + fx_ * reach,
                        front_y + ry_ * half_w + fy_ * reach))
            sweep = (min(p[0] for p in corners), min(p[1] for p in corners),
                     max(p[0] for p in corners), max(p[1] for p in corners))
            for oid, bb in obs:
                if oid == m["id"]:
                    continue
                if _hit(bb, sweep[0] + 0.035, sweep[1] + 0.035,
                        sweep[2] - 0.035, sweep[3] - 0.035):
                    problems.append("%s: stove %s oven sweep blocked by %s"
                                    % (fl["id"], m["id"], oid))
        # A radiator body pressed neatly against the wall is not proof that
        # it can be serviced. Check a kneeling person's 48 cm square at BOTH
        # end fittings: the low supply handwheel and the far air vent. The
        # body never enters this obstacle list, so there is no self-hit; its
        # building-owned continuous riser is an asm pipe and is skipped too.
        for m in fl.get("markers", []):
            if m.get("kind") != "radiator":
                continue
            import math as _m
            a = _m.radians(m.get("yaw_deg", 0))
            rx_, ry_ = _m.cos(a), _m.sin(a)     # local +x / fitting ends
            # Radiators still use the legacy marker convention: yaw 90 is
            # the west wall facing east, -90 the east wall facing west, and
            # zero the lobby's south wall facing north.
            fx_, fy_ = _m.sin(a), _m.cos(a)     # room-facing service side
            half = (int(m.get("sections", 9)) - 1) * 0.085 * 0.5
            fittings = (("handwheel", -0.44), ("air vent", half + 0.045))
            for label, lx in fittings:
                fitting_x = m["pos"][0] + rx_ * lx
                fitting_y = m["pos"][1] + ry_ * lx
                # A fitter can kneel square-on or offset a knee to either
                # side. Requiring one exact 48 cm square called a sofa 30 cm
                # from the wheel "unreachable" even though the wheel was in
                # open air at arm's length. All three approaches must fail
                # before the build rejects the placement.
                clear = False
                blockers = set()
                for side in (0.0, -0.28, 0.28, -0.55, 0.55):
                    cx = fitting_x + fx_ * 0.48 + rx_ * side
                    cy = fitting_y + fy_ * 0.48 + ry_ * side
                    band = (cx - 0.20, cy - 0.20, cx + 0.20, cy + 0.20)
                    blocked = False
                    for oid, bb in obs:
                        if oid == m["id"]:
                            continue
                        # Paint, paper and a 140 mm masonry water table can
                        # sit behind a hand. They are surfaces at the fitting,
                        # not floor objects occupying the kneeling square.
                        if ("_art" in oid or "_poster" in oid or
                                "_sheet" in oid or "_soot" in oid or
                                oid.startswith("water_table_")):
                            continue
                        if _hit(bb, band[0] + 0.03, band[1] + 0.03,
                                band[2] - 0.03, band[3] - 0.03):
                            blocked = True
                            blockers.add(oid)
                    if not blocked:
                        clear = True
                        break
                if not clear:
                    problems.append("%s: radiator %s %s unreachable by %s"
                                    % (fl["id"], m["id"], label,
                                       ", ".join(sorted(blockers))))
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
    unit_asm, unit_marker, unit_yaw = {}, {}, {}
    unit_rad, unit_detail, unit_story = set(), {}, {}
    doors, switches, kinds = 0, 0, {}
    for fl in layout["floors"]:
        for m in fl["markers"]:
            kinds[m["kind"]] = kinds.get(m["kind"], 0) + 1
            if m["kind"] == "door" and not m.get("cabinet")                     and not m.get("exterior"):
                doors += 1  # cabinet leaves are joinery, not doorways;
                # exterior shop doors have no switch plates by the same
                # rule that dropped every other exterior switch
            if m["kind"] == "radiator" and m.get("unit"):
                unit_rad.add(m["unit"])
            if m.get("unit"):
                unit = m["unit"]
                unit_marker.setdefault(unit, {})
                semantic = m.get("fixture", m["kind"])
                unit_marker[unit][semantic] = (
                    unit_marker[unit].get(semantic, 0) + 1)
                if semantic in ("fridge", "stove", "kitchen_sink"):
                    unit_yaw.setdefault(unit, set()).add(m.get("yaw_deg"))
        for fu in fl.get("furniture", []):
            unit = str(fu["id"]).split("_")[0]
            if "_detail_" in str(fu["id"]):
                unit_detail[unit] = unit_detail.get(unit, 0) + 1
            if "_story_" in str(fu["id"]):
                unit_story[unit] = unit_story.get(unit, 0) + 1
            if "asm" not in fu:
                continue
            if fu["asm"] == "switch":
                switches += 1
                continue
            unit_asm.setdefault(unit, {})
            unit_asm[unit][fu["asm"]] = unit_asm[unit].get(fu["asm"], 0) + 1
            if fu["id"].endswith("_k"):
                unit_yaw.setdefault(unit, set()).add(fu.get("yaw"))
    # Every door still gets a plate on each face it actually has. Doors in
    # exterior walls only have one interior face, so their outboard plate
    # is dropped on purpose - counted, not silently lost, so the invariant
    # stays an invariant.
    # Two rugs on the same patch of floor read as one rug with a colour
    # fault. Cheap to check, and it caught 4B's desk mat lying half on
    # top of the room's main rug.
    for fl_ in layout["floors"]:
        rugs = [m for m in fl_.get("furniture", [])
                if str(m.get("id", "")).endswith("_rug")]
        for a in range(len(rugs)):
            for b in range(a + 1, len(rugs)):
                ra, rb = rugs[a]["rect"], rugs[b]["rect"]
                if ra[0] < rb[2] and ra[2] > rb[0]                         and ra[1] < rb[3] and ra[3] > rb[1]:
                    problems.append("%s: rugs %s and %s overlap"
                                    % (fl_["id"], rugs[a]["id"],
                                       rugs[b]["id"]))
    dropped = len(EXTERIOR_SWITCHES_DROPPED)
    coverage = len(COVERAGE_SWITCHES_ADDED)
    if switches + dropped - coverage != 2 * doors:
        problems.append("switches %d + %d dropped - %d coverage != 2 x doors %d"
                        % (switches, dropped, coverage, doors))
    skip_states = ("sealed", "vacant (damaged)", "vacant (fire damage)",
                   "landlord storage")
    need = {"bed": 1, "kitchen": 1, "stove": 1, "fridge": 1,
            "toilet": 1, "bath_sink": 1, "kitchen_sink": 1,
            "shower": 1, "wardrobe": 1, "chair": 2}
    for unit, res in RESIDENTS.items():
        if res in skip_states:
            continue
        if unit not in unit_rad:
            problems.append("%s has no radiator" % unit)
        a = unit_asm.get(unit, {})
        if res == "PLAYER":  # 4B is bespoke; the bath suite is shared code
            if a.get("toilet", 0) < 1:
                problems.append("4B missing toilet")
            for k in ("bath_sink", "kitchen_sink", "shower", "fridge", "stove"):
                if unit_marker.get(unit, {}).get(k, 0) < 1:
                    problems.append("4B missing %s" % k)
            continue
        # The old rule here demanded four "_detail_" objects per apartment, and
        # only lived_in_surface_detail() ever produced that name - so it was a
        # rule that counted the generic dressing and nothing else. Mina's
        # bespoke caption station scored zero against it.
        #
        # What a room actually has to prove is that somebody lives in it, and
        # the evidence for that is their OWN possessions. That is the
        # "_story_" count below, which every occupied unit must satisfy.
        # A near-empty room with two things in it that could only be this
        # person's is the target; four identical mugs never were.
        for k, n in need.items():
            have = (unit_marker.get(unit, {}).get(k, 0)
                    if k in ("fridge", "stove", "bath_sink",
                             "kitchen_sink", "shower") else a.get(k, 0))
            if have < n:
                problems.append("%s missing %s (%d < %d)"
                                % (unit, k, have, n))
        if a.get("table_round", 0) + a.get("table_rect", 0) < 1:
            problems.append("%s has no dining table" % unit)
        yaws = unit_yaw.get(unit, set())
        if len(yaws) > 1:
            problems.append("%s kitchen trio facing disagrees %s"
                            % (unit, sorted(yaws)))
    # Every OCCUPIED unit, not just the ones with a RESIDENT_STORIES entry -
    # the heroes carry their own bespoke clusters and must clear the same bar.
    # This is the only remaining guard against an apartment that is furniture
    # and nobody, and it matters more now that the generic layer is gone.
    # The six case residents build their signature clusters inline in
    # dress_unit() with plain ids - "2A_pinboard", "2C_amp1" - rather than
    # through resident_story_detail()'s "_story_" naming. Their evidence is a
    # whole installation, not a named prefix, so counting prefixes scores the
    # most bespoke apartments in the building at zero. Renaming them is a
    # separate, safe change (nothing outside this file references those ids);
    # until then they are listed, not silently skipped.
    hero_inline = {"2A": "Mina's caption station",
                   "2C": "Juno's amps and guitars",
                   "3B": "Omar's repair bench",
                   "3D": "Rhea's playback corner",
                   "5A": "Nadia's drafting setup"}
    for unit, res in RESIDENTS.items():
        if res in skip_states or res == "PLAYER" or unit in hero_inline:
            continue
        if unit_story.get(unit, 0) + unit_detail.get(unit, 0) < 2:
            problems.append("%s has nothing personal in it (%d < 2)"
                            % (unit, unit_story.get(unit, 0)))
    n_asm = sum(sum(v.values()) for v in unit_asm.values()) + switches
    print("furnishing OK: %d assemblies (%d switches), %d door leaves, "
          "%d radiators" % (n_asm, switches, doors, kinds.get("radiator", 0)))
    print("marker counts:", dict(sorted(kinds.items())))
    return problems


# ---------------------------------------------------------------- graphs

def ventilation_register_pass(floors):
    """One passive ceiling register per windowless bathroom.

    A private electric fan in 4B made the player's flat more modern than its
    neighbours and left twenty-two bathrooms with nowhere for damp air to go.
    The 1928 reopening instead cut four shared risers through the 1912 fabric.
    These records are static Blender geometry; the four roof motors remain the
    only scripted owners, so twenty-three grilles do not become twenty-three
    timers and draw-call islands.
    """
    registers = []
    for fl in floors:
        if fl["id"] in ("B1", "ROOF"):
            fl["vent_registers"] = []
            continue
        owned = []
        for room in fl.get("rooms", []):
            if room.get("kind") != "bathroom":
                continue
            x0, y0, x1, y1 = map(float, room["rect"])
            unit = str(room.get("unit") or "")
            # The public lavatory is west of the lobby and joins the A riser
            # through a first-floor branch; it must not invent a fifth stack.
            letter = unit[-1] if unit and unit[-1] in "ABCD" else "A"
            # The register is deliberately off-centre. A grille centred like
            # a lamp reads as a replaced fixture, while a riser takeoff hugs
            # the wet wall and leaves the basin standing position readable.
            px = x0 + (0.43 if letter in "AB" else (x1 - x0) - 0.43)
            py = y0 + (y1 - y0) * 0.52
            rid = "%s_VENT_REGISTER" % room["id"]
            rec = {
                "id": rid, "floor": fl["id"], "room": room["id"],
                "unit": unit, "riser": "V-%s" % letter,
                "pos": [round(px, 3), round(py, 3),
                        round(float(fl["z"]) + WALL_H - 0.022, 3)],
                "yaw_deg": 90 if letter in "BC" else 0,
                "network": "ventilation",
            }
            owned.append(rec)
            registers.append(rec)
        fl["vent_registers"] = owned
    print("ventilation: %d passive bathroom registers on four risers" %
          len(registers))
    return registers


def vantry_point_pass(floors):
    """One 1912 listening head in every enclosed room, cheaply rendered.

    These do not enter ``markers``: that path constructs one FunctionalProp
    per marker, which would turn 119 quiet ceiling fittings into 119 scripts,
    timers and material-owning draw submissions.  The runtime batches these
    records per floor and promotes exactly one record to the movable owner of
    the current chirp.

    A room-centre fixture is normally where the electric lamp already is.
    Choose among restrained off-centre positions and maximise distance from
    authored ceiling hardware; this is why the pass runs after light markers.
    """
    points = []
    ceiling_kinds = {"ceiling_light", "pendant_shade", "flush_dome",
                     "kitchen_linear", "cage_bulb", "chandelier",
                     "eye_pendant", "exhaust_fan", "smoke_detector"}
    for fl in floors:
        for room in fl.get("rooms", []):
            if room.get("kind") in ("roof", "atrium"):
                continue
            x0, y0, x1, y1 = room["rect"]
            x0, x1 = sorted((float(x0), float(x1)))
            y0, y1 = sorted((float(y0), float(y1)))
            cx, cy = (x0 + x1) * 0.5, (y0 + y1) * 0.5
            margin = min(0.42, max(0.18, min(x1 - x0, y1 - y0) * 0.22))
            offsets = ((0.38, 0.31), (-0.38, 0.31), (0.38, -0.31),
                       (-0.38, -0.31), (0.0, 0.36), (0.36, 0.0))
            blockers = [m for m in fl.get("markers", [])
                        if m.get("kind") in ceiling_kinds]
            # Passive ventilation grilles are Blender-owned rather than
            # marker-spawned, but they occupy the same ceiling plane. Let the
            # listening head see them before it chooses its own position.
            blockers += fl.get("vent_registers", [])
            candidates = []
            for ox, oy in offsets:
                px = max(x0 + margin, min(x1 - margin, cx + ox))
                py = max(y0 + margin, min(y1 - margin, cy + oy))
                nearest = min((math.hypot(px - float(m["pos"][0]),
                                          py - float(m["pos"][1]))
                               for m in blockers), default=9.0)
                candidates.append((nearest, px, py))
            _, px, py = max(candidates)
            rid = str(room["id"])
            points.append({
                "id": "%s_VANTRY_POINT" % rid,
                "floor": fl["id"], "room": rid,
                "room_kind": room.get("kind", ""),
                "unit": room.get("unit", ""),
                "pos": [round(px, 3), round(py, 3),
                        round(float(fl["z"]) + WALL_H, 3)],
                "network": "signal",
                # Tiny deterministic rotation keeps a century of service
                # screws from forming a conspicuous building-wide grid.
                "yaw_deg": sum((i + 1) * ord(ch)
                               for i, ch in enumerate(rid)) % 4 * 90,
            })
    return points


def acoustic_graph(layout):
    nodes, edges = [], []

    def add(nid, pos, network, room="", recv=0.7, band=(55, 850), delay=30):
        nodes.append({"id": nid, "pos": [round(p, 3) for p in pos],
                      "room": room, "network": network,
                      "frequency_band": list(band), "delay_ms": delay,
                      "damping": 0.22, "infection_receptivity": recv,
                      "connections": []})

    # The boiler used to be repeated here as a magic coordinate. It then
    # stayed in the middle of the room after the actual plant moved. Graph
    # truth follows the same marker that spawns the functional prop.
    boiler_marker = next(
        (m for fl in layout["floors"] for m in fl["markers"]
         if m.get("id") == "B1_BOILER_01"), None)
    boiler_pos = boiler_marker["pos"] if boiler_marker else [9.05, 1.55, -2.8]

    add("BASEMENT_HEADER_WEST", [-5.85, 0.0, -2.3], "heating",
        "B1_LAUNDRY", 0.6, (30, 400), 12)
    add("BASEMENT_HEADER_EAST", [5.85, 0.0, -2.3], "heating",
        "B1_BOILER", 0.6, (30, 400), 12)
    add("B1_BOILER_01", boiler_pos, "heating", "B1_BOILER", 0.5,
        (25, 300), 5)
    add("B1_WATER_MAIN", [-13.48, 7.0, -1.85], "water",
        "B1_LAUNDRY", 0.62, (35, 1800), 14)
    add("B1_LAUNDRY_JOIST", [-11.8, 7.8, -0.35], "structural",
        "B1_LAUNDRY", 0.48, (20, 900), 28)
    edges += [("B1_BOILER_01", "BASEMENT_HEADER_EAST"),
              ("BASEMENT_HEADER_EAST", "BASEMENT_HEADER_WEST")]
    by_riser = {}
    vent_fans = {}

    def electrical_target(floor_id):
        """The real carrier a powered object reaches on this storey.

        B1 and the reopening lobby terminate at the basement switchgear;
        residential floors reach the south corridor junction; the roof
        continues that same chase through a dedicated riser head. The old
        string-format shortcut invented ROOF_CORRLIGHT_S (and B1/F01
        equivalents) that were never nodes, so valid fixtures became silent
        graph islands when invalid edges were discarded below.
        """
        if floor_id == "ROOF":
            return "ROOF_ELECTRICAL_RISER"
        if floor_id in ("B1", "F01"):
            return "B1_ELECTRICAL_HUB"
        return "%s_CORRLIGHT_S" % floor_id

    for fl in layout["floors"]:
        radiator_by_unit = {
            m.get("unit", ""): m["id"] for m in fl["markers"]
            if m.get("kind") == "radiator" and m.get("unit")
        }
        for m in fl["markers"]:
            if m["kind"] == "radiator":
                add(m["id"], [m["pos"][0], m["pos"][1], m["pos"][2] + 0.35],
                    "heating", room=m.get("unit", ""), recv=0.84, delay=38)
                by_riser.setdefault(m.get("riser", "H-X"), []).append(m)
            elif m["kind"] == "washer":
                add(m["id"], m["pos"], "water", "B1_LAUNDRY", 0.6,
                    (40, 2000), 20)
                edges.append((m["id"], "B1_WATER_MAIN"))
                # A powered wringer bridges its wet plumbing and the basement
                # motor circuit. Neither route is the steam header.
                edges.append((m["id"], "B1_ELECTRICAL_HUB"))
            elif m["kind"] == "laundry_airer":
                add(m["id"], m["pos"], "structural", "B1_LAUNDRY", 0.52,
                    (20, 900), 32)
                edges.append((m["id"], "B1_LAUNDRY_JOIST"))
                edges.append(("B1_LAUNDRY_JOIST", "B1_WATER_MAIN"))
            elif m["kind"] == "wall_clock":
                network = m.get("network", "structural")
                add(m["id"], m["pos"], network, m.get("unit", ""), 0.75,
                    (60, 8000), 4 if network == "signal" else 28)
                if network == "signal":
                    edges.append((m["id"], "%s_VANTRY_TRUNK" % fl["id"]))
                else:
                    # A spring clock reaches the building through its hanging
                    # screw and plaster, not through a convenient light wire.
                    target = radiator_by_unit.get(m.get("unit", ""))
                    if target:
                        edges.append((m["id"], target))
            elif m["kind"] == "exhaust_fan":
                # Powered at the roof, heard through the duct.  The old 4B
                # ceiling fan was an electrical node; central plant gets its
                # own physical carrier so a bathroom whir cannot teleport
                # through corridor lights.
                add(m["id"], [m["pos"][0], m["pos"][1], m["pos"][2] + 0.55],
                    "ventilation", "ROOF_OPEN", 0.82, (35, 1800), 9)
                nodes[-1]["riser"] = m.get("riser", "V-X")
                vent_fans[m.get("riser", "V-X")] = m
            elif m["kind"] in ("lamp", "monitor", "signal_terminal", "toaster",
                               "boxfan", "speaker", "kettle",
                               "ceiling_light", "pendant_shade",
                               "flush_dome", "sconce_globe",
                               "kitchen_linear", "cage_bulb", "chandelier",
                               "eye_pendant", "neon_sign"):
                add(m["id"], m["pos"], "electrical", m.get("unit", ""), 0.75,
                    (60, 8000), 4)
                edges.append((m["id"], electrical_target(fl["id"])))
            elif m["kind"] == "fridge":
                if m.get("network") == "electrical":
                    # Only the four monitor-tops have a wire and relay.
                    add(m["id"], m["pos"], "electrical", m.get("unit", ""),
                        0.75, (60, 8000), 4)
                    edges.append((m["id"], electrical_target(fl["id"])))
                else:
                    # Oak, zinc and meltwater: the icebox hears the room
                    # through floorboards and pipe brackets, never a wire.
                    add(m["id"], m["pos"], "structural", m.get("unit", ""),
                        0.68, (25, 900), 34)
                    target = radiator_by_unit.get(m.get("unit", ""))
                    if target:
                        edges.append((m["id"], target))
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
            elif m["kind"] == "case_door":
                # On the structural network, hung off the same radiator the
                # case's route travels: the door is where that route ends,
                # so it has to be somewhere the route can actually reach.
                add(m["id"], [m["pos"][0], m["pos"][1], m["pos"][2] + 1.0],
                    "structural", m.get("unit", ""), 0.90, (20, 240), 55)
                edges.append((m["id"], "%s_B_RADIATOR_01" % fl["id"]))
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
    # The 1928 roof circuit rises through the same south chase as the sixth
    # floor, then terminates in a weatherproof junction below the parapet.
    # This is graph plant rather than a fifth visible roof fitting: the four
    # lamps remain the things the player sees and possesses.
    add("ROOF_ELECTRICAL_RISER", [0.0, -8.3, LEVELS["ROOF"] + 0.30],
        "electrical", "ROOF_OPEN", 0.55, (100, 9000), 6)
    edges.append(("ROOF_ELECTRICAL_RISER", "F06_CORRLIGHT_S"))
    # Vantry's house circuit is a signal network, never an electrical-light
    # shortcut.  Cache-friendly stars per floor keep every listening head one
    # hop from its trunk while the seven trunks describe the vertical riser.
    previous_vantry = None
    for fid in ("B1", "F01", "F02", "F03", "F04", "F05", "F06"):
        floor_z = LEVELS[fid]
        trunk = "%s_VANTRY_TRUNK" % fid
        add(trunk, [-0.72, -1.85, floor_z + 2.28], "signal", fid,
            0.82, (180, 6200), 6)
        if previous_vantry:
            edges.append((previous_vantry, trunk))
        previous_vantry = trunk
    for point in layout.get("vantry_points", []):
        add(point["id"], point["pos"], "signal", point["room"],
            0.92, (240, 5600), 5)
        edges.append((point["id"], "%s_VANTRY_TRUNK" % point["floor"]))
    # Four reopening-era sheet-metal risers. Registers are quiet static
    # geometry, but graph nodes let the director route a motor pulse to the
    # exact bathroom where the player hears it rather than playing a global
    # roof loop. The public WC takes a short first-floor branch into V-A.
    registers_by_riser = {}
    for register in layout.get("ventilation_registers", []):
        riser = register.get("riser", "V-X")
        registers_by_riser.setdefault(riser, []).append(register)
        add(register["id"], register["pos"], "ventilation",
            register.get("room", ""), 0.86, (35, 1800), 16)
        nodes[-1]["riser"] = riser
    for riser, registers in sorted(registers_by_riser.items()):
        upper = [r for r in registers if r.get("unit")]
        source = upper if upper else registers
        rx = sum(float(r["pos"][0]) for r in source) / len(source)
        ry = sum(float(r["pos"][1]) for r in source) / len(source)
        previous = None
        for fid in ("F01", "F02", "F03", "F04", "F05", "F06"):
            trunk = "%s_%s_RISER" % (fid, riser.replace("-", "_"))
            add(trunk, [rx, ry, LEVELS[fid] + WALL_H - 0.08],
                "ventilation", fid, 0.74, (35, 1800), 11)
            nodes[-1]["riser"] = riser
            if previous:
                edges.append((previous, trunk))
            previous = trunk
            for register in registers:
                if register["floor"] == fid:
                    edges.append((register["id"], trunk))
        if riser in vent_fans and previous:
            edges.append((vent_fans[riser]["id"], previous))
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
    # A marker-backed node is a live prop contract: BuildingRoot binds the
    # owner by marker id and directors expect propagation to leave it. Bad
    # target names used to be dropped silently here, producing a valid JSON
    # node that could react locally but never transmit. Architectural trunk
    # nodes are checked by their own topology audits; every spawned marker
    # that enters this graph must have a carrier, with no anonymous allow-list.
    marker_ids = {
        m["id"] for fl in layout["floors"] for m in fl["markers"]
    }
    isolated_markers = sorted(
        node_id for node_id in marker_ids
        if node_id in index and not index[node_id]["connections"]
    )
    if isolated_markers:
        raise SystemExit("acoustic graph has isolated marker nodes: %s" %
                         ", ".join(isolated_markers))
    return {"nodes": nodes}


def fixture_light_map(layout):
    """Fixture-to-room coverage manifest for lighting QA and tuning."""
    # Exactly the kinds that spawn a LightFixtureProp, because that is what
    # the lighting audit counts this manifest against. "ceiling_light" is
    # deliberately absent: 4B's bowl is a CeilingLightProp, which extends
    # FunctionalProp directly and is not managed by the LightRig, so
    # listing it here made the manifest claim one fixture more than the
    # rig has ever had.
    light_kinds = {"pendant_shade", "flush_dome",
                   "sconce_globe", "kitchen_linear", "cage_bulb",
                   "chandelier", "eye_pendant", "street_lamp"}
    fixtures = []
    for fl in layout["floors"]:
        for m in fl["markers"]:
            if m["kind"] not in light_kinds:
                continue
            px, py, pz = m["pos"]
            candidates = []
            for r in fl["rooms"]:
                x0, y0, x1, y1 = r["rect"]
                if x0 - 0.08 <= px <= x1 + 0.08 and \
                        y0 - 0.08 <= py <= y1 + 0.08:
                    candidates.append(((x1 - x0) * (y1 - y0),
                                       r["id"], r["kind"]))
            candidates.sort()
            room_id, room_kind = ("UNASSIGNED", "unknown") if not candidates \
                    else (candidates[0][1], candidates[0][2])
            if room_id == "UNASSIGNED" and m.get("navigation", False):
                room_id, room_kind = fl["id"] + "_NAVIGATION", "corridor"
            fixtures.append({
                "id": m["id"], "floor": fl["id"], "kind": m["kind"],
                "room": room_id, "room_kind": room_kind,
                "position": [px, py, pz],
                "range": m.get("range", 5.0),
                "energy": m.get("energy", 1.0),
                "navigation": bool(m.get("navigation", False)),
                "standby": m.get("standby", 0.04)})
    return {"fixture_count": len(fixtures), "fixtures": fixtures}


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
    "washer": {"minimum_action_interval": 0.45, "maximum_action_rate": 2,
               "available_mechanical_events": ["agitate", "thump", "drain"],
               "preferred_subdivision": 0.5, "timing_drift": 0.05,
               "response_latency": 0.20, "normal_function_priority": 1.0,
               "infection_receptivity": 0.6},
    "laundry_airer": {
               "minimum_action_interval": 1.8, "maximum_action_rate": 1,
               "available_mechanical_events": ["rope_settle", "pulley_tick"],
               "preferred_subdivision": 0.25, "timing_drift": 0.12,
               "response_latency": 0.35, "normal_function_priority": 0.0,
               "infection_receptivity": 0.52},
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
    "signal_terminal": {
                "minimum_action_interval": 0.06, "maximum_action_rate": 12,
                "available_mechanical_events": ["scope_flare", "meter_kick",
                                                "line_annunciate"],
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
    "vantry_point": {"minimum_action_interval": 4.0,
                     "maximum_action_rate": 1,
                     "available_mechanical_events": ["line_chirp",
                                                       "telltale_close"],
                     "preferred_subdivision": 0.25, "timing_drift": 0.0,
                     "response_latency": 0.02,
                     "normal_function_priority": 1.0,
                     "infection_receptivity": 0.72},
    # Save/data compatibility only. New layout and code say what it is.
    "smoke_detector": {"minimum_action_interval": 4.0,
                       "maximum_action_rate": 1,
                       "available_mechanical_events": ["line_chirp"],
                       "preferred_subdivision": 0.25, "timing_drift": 0.0,
                       "response_latency": 0.02,
                       "normal_function_priority": 1.0,
                       "infection_receptivity": 0.72},
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
    # A neon transformer is slow to strike and slow to let go, so the sign
    # lags the beat rather than snapping to it — and it is the most
    # receptive thing on the building, because a tube that already
    # flickers on its own is where a fault hides best.
    "neon_sign": {"minimum_action_interval": 0.14,
                  "maximum_action_rate": 7,
                  "available_mechanical_events": ["tube_surge",
                                                  "letter_dropout"],
                  "preferred_subdivision": 1, "timing_drift": 0.04,
                  "response_latency": 0.06,
                  "normal_function_priority": 1.0,
                  "infection_receptivity": 0.92},
    "door_anomaly": {"minimum_action_interval": 0.10, "maximum_action_rate": 8,
                     "available_mechanical_events": ["seam_glow"],
                     "preferred_subdivision": 1, "timing_drift": 0.0,
                     "response_latency": 0.0, "normal_function_priority": 0.0,
                     "infection_receptivity": 1.0},
    # Ordinary joinery, which is the unsettling part: it behaves like a
    # door that has always been there, because as far as it knows it has.
    "case_door": {"minimum_action_interval": 0.50, "maximum_action_rate": 2,
                  "available_mechanical_events": ["latch_settle"],
                  "preferred_subdivision": 1, "timing_drift": 0.02,
                  "response_latency": 0.08, "normal_function_priority": 0.0,
                  "infection_receptivity": 0.85},
}

MATERIAL_CATALOG = {
    "plaster": {"base_color": [0.62, 0.64, 0.58, 1.0], "roughness": 0.80},
    "wallpaper_old": {"base_color": [0.56, 0.52, 0.37, 1.0],
                      "roughness": 0.90},
    "brick": {"base_color": [0.42, 0.27, 0.22, 1.0], "roughness": 0.85},
    "concrete": {"base_color": [0.48, 0.48, 0.47, 1.0], "roughness": 0.75},
    "sidewalk_haunted": {"base_color": [0.31, 0.30, 0.28, 1.0],
                           "roughness": 0.82},
    "sidewalk_grout": {"base_color": [0.075, 0.065, 0.055, 1.0],
                         "roughness": 0.93},
    "trim": {"base_color": [0.85, 0.83, 0.77, 1.0], "roughness": 0.45},
    "floor_oak": {"base_color": [0.45, 0.33, 0.22, 1.0], "roughness": 0.55},
    "terrazzo": {"base_color": [0.72, 0.70, 0.66, 1.0], "roughness": 0.40},
    # Sourced from the AI material library (ai_materials/), placed by
    # their own passes: bathroom wainscot, radiator bodies, corridor
    # ceilings, lobby dado.
    "subway_tile": {"base_color": [0.88, 0.87, 0.83, 1.0],
                    "roughness": 0.28},
    # Stair landings: laid terrazzo rather than the dished marble of the
    # treads, so the two wear apart and can be textured apart.
    "landing": {"base_color": [0.70, 0.68, 0.63, 1.0], "roughness": 0.42},
    "cast_iron": {"base_color": [0.52, 0.50, 0.48, 1.0], "roughness": 0.60,
                  "metallic": 0.35},
    "tin_ceiling": {"base_color": [0.82, 0.79, 0.72, 1.0],
                    "roughness": 0.45, "metallic": 0.08},
    "marble_lobby": {"base_color": [0.86, 0.85, 0.82, 1.0],
                     "roughness": 0.30},
    # The six-tread sheet. Sampled a band per tread by explicit UVs, so
    # it never world-projects and its coverage figure is decorative.
    "stair_treads": {"base_color": [0.82, 0.81, 0.79, 1.0],
                     "roughness": 0.42},
    # Tarnished brass, for things lying flat on a floor.
    #
    # Polished brass (metallic 0.85) lying flat under a torch held above
    # it reflects the light AWAY from the eye, so the linoleum binding
    # bars measured DARKER than both the lino and the boards they
    # separate - a shadow line where there should be a gleam. A binding
    # bar in a 1926 kitchen has decades of oxide on it anyway, and an
    # oxide layer genuinely behaves far less like a metal, so dropping
    # metallic is the physical answer rather than a cheat.
    "brass_dull": {"base_color": [0.62, 0.48, 0.22, 1.0],
                   "roughness": 0.52, "metallic": 0.30},
    # Nickel-plated brass, not chromium. A warm silver with cloudy wear is
    # the 1908 catalog finish; enough metallic response to read as plated
    # work, but not enough to turn a horizontal spout black under the torch.
    "nickel_plated": {"base_color": [0.72, 0.70, 0.66, 1.0],
                      "roughness": 0.38, "metallic": 0.70},
    # Back-silvered glass is not generic architectural glazing. Compatibility
    # has no planar reflection, so damp clouding and pinprick silver loss have
    # to carry the read without baking a reflected room into the surface.
    "mirror_aged": {"base_color": [0.68, 0.69, 0.67, 1.0],
                    "roughness": 0.18, "metallic": 0.78},
    # Natural mica sheet carrying the 1-A-1's resistance wire. It is a
    # mineral insulator, not ceramic and not a glowing surface by itself;
    # the GDScript wire geometry owns the mutable emission.
    "mica_heater": {"base_color": [0.58, 0.36, 0.12, 1.0],
                    "roughness": 0.78, "metallic": 0.0},
    # Close-read refrigerator metals. Zinc oxide and forty years of wet
    # wiping make the liner read mostly diffuse. At 0.38 metallic its shelves
    # still reflected the practical away and sampled nearly black in 4B.
    "zinc_liner": {"base_color": [0.66, 0.67, 0.67, 1.0],
                    "roughness": 0.82, "metallic": 0.12},
    "copper_aged": {"base_color": [0.55, 0.33, 0.21, 1.0],
                    "roughness": 0.58, "metallic": 0.72},
    # The elevator sheet. These belong HERE, not hand-added to
    # material_catalog.json: gen_layout writes that file, so anything
    # edited into it directly is silently discarded the next time the
    # layout is regenerated - which is how the Blender build went from
    # clean to "not in material_catalog" for all nine at once.
    "brass_bright": {"base_color": [0.541, 0.416, 0.200, 1.0],
                     "roughness": 0.34, "metallic": 0.85},
    "bronze": {"base_color": [0.275, 0.251, 0.184, 1.0],
               "roughness": 0.62, "metallic": 0.75},
    "car_paint": {"base_color": [0.369, 0.361, 0.259, 1.0],
                  "roughness": 0.55},
    "oak_quartered": {"base_color": [0.522, 0.345, 0.196, 1.0],
                      "roughness": 0.45},
    "milk_glass": {"base_color": [0.894, 0.882, 0.847, 1.0],
                   "roughness": 0.22},
    "bakelite_black": {"base_color": [0.141, 0.125, 0.114, 1.0],
                       "roughness": 0.28},
    "terrazzo_dark": {"base_color": [0.290, 0.267, 0.235, 1.0],
                      "roughness": 0.40},
    "brass_mesh": {"base_color": [0.416, 0.322, 0.157, 1.0],
                   "roughness": 0.52, "metallic": 0.80},
    "indicator_enamel": {"base_color": [0.878, 0.835, 0.745, 1.0],
                         "roughness": 0.24},
    # Natural rubber rollers are the wringer's contact surface. Bakelite is
    # too hard and glossy, and generic metal turns the silhouette into two
    # more shafts instead of the part that can take a hand.
    "rubber_aged": {"base_color": [0.10, 0.09, 0.08, 1.0],
                    "roughness": 0.82, "metallic": 0.0},
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
    # Rubberized cotton duck on the 1928 shower curtains. It shares the
    # approved linen weave source, but is staged as a distinct finish because
    # its waxed face is darker, less absorbent and visibly less matte.
    "shower_duck": {"base_color": [0.73, 0.68, 0.54, 1.0],
                    "roughness": 0.62, "metallic": 0.0},
    "paper": {"base_color": [0.90, 0.88, 0.82, 1.0], "roughness": 0.85},
    "countertop": {"base_color": [0.78, 0.75, 0.64, 1.0],
                   "roughness": 0.62},
    "book_burgundy": {"base_color": [0.34, 0.10, 0.10, 1.0],
                      "roughness": 0.72},
    "book_green": {"base_color": [0.12, 0.24, 0.16, 1.0],
                   "roughness": 0.72},
    "book_navy": {"base_color": [0.10, 0.15, 0.25, 1.0],
                  "roughness": 0.72},
    "book_ochre": {"base_color": [0.58, 0.34, 0.08, 1.0],
                   "roughness": 0.72},
    "book_teal": {"base_color": [0.13, 0.31, 0.31, 1.0],
                  "roughness": 0.72},
    "book_brown": {"base_color": [0.28, 0.17, 0.10, 1.0],
                   "roughness": 0.72},
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
    # Approved full-surface landing soffit. It terminates at the real slab
    # edge, so it is neither a floating decal nor a tiled room material.
    "fx_ceiling_soffit_failed": {"base_color": [1.0, 1.0, 1.0, 1.0],
                                  "roughness": 1.0},
    # appliance & hardware finishes for the parametric asset library
    "chrome": {"base_color": [0.80, 0.82, 0.85, 1.0], "roughness": 0.12,
               "metallic": 1.0},
    "enamel": {"base_color": [0.91, 0.89, 0.83, 1.0], "roughness": 0.18},
    # A fired-glass appliance skin with restrained damage. It begins on 4B's
    # range as an approval specimen; the ambiguous legacy enamel key stays
    # intact until a warehouse and room render earn family promotion.
    "enamel_appliance": {"base_color": [0.91, 0.89, 0.83, 1.0],
                          "roughness": 0.20},
    "bakelite": {"base_color": [0.16, 0.12, 0.10, 1.0], "roughness": 0.30},
    "porcelain": {"base_color": [0.92, 0.93, 0.92, 1.0], "roughness": 0.14},
    # Calm fired lavatory glaze. The legacy porcelain plate remains available
    # until the one-fixture render gate proves this does not read as plaster.
    "porcelain_fixture": {"base_color": [0.92, 0.91, 0.84, 1.0],
                           "roughness": 0.16},
    # planter clay and potting soil (plant realism pass)
    "terracotta": {"base_color": [0.66, 0.38, 0.26, 1.0], "roughness": 0.72},
    "soil": {"base_color": [0.20, 0.15, 0.11, 1.0], "roughness": 0.95},
    # after the storm: standing water is darker AND smoother than what it
    # lies on, which is the whole reason a wet street reads as wet — it
    # stops scattering and starts reflecting the lamps and the neon
    "wet_asphalt": {"base_color": [0.09, 0.09, 0.10, 1.0],
                    "roughness": 0.22},
    "puddle": {"base_color": [0.04, 0.045, 0.055, 1.0], "roughness": 0.05,
               "metallic": 0.35},
    "leaf_fall": {"base_color": [0.42, 0.28, 0.13, 1.0], "roughness": 0.65},
    "safety_orange": {"base_color": [0.88, 0.22, 0.035, 1.0],
                      "roughness": 0.62},
    # ---- the retail and bar batch (2026-08-07) -----------------------
    # Ten surfaces that stood on flat colour until the textures landed.
    # Base colours here are the fallback the build uses if a material
    # set is ever missing, so they are set close to the ingested anchor
    # rather than left at a placeholder: a missing map should read as a
    # duller version of the right surface, never as a different one.
    "quarry_tile": {"base_color": [0.42, 0.20, 0.13, 1.0],
                    "roughness": 0.72},
    "felt_violet": {"base_color": [0.17, 0.12, 0.32, 1.0],
                    "roughness": 0.94},
    "stairwell_teal": {"base_color": [0.20, 0.36, 0.30, 1.0],
                       "roughness": 0.55},
    # The Harukiya's two wall colours. Green is the main room and the
    # colour the place is remembered by; the oxblood is the restroom
    # cell, where the palette's bruised red goes.
    "bar_wall": {"base_color": [0.30, 0.31, 0.16, 1.0], "roughness": 0.60},
    "bar_wall_red": {"base_color": [0.25, 0.10, 0.09, 1.0],
                     "roughness": 0.62},
    "lacquer_red": {"base_color": [0.52, 0.14, 0.11, 1.0],
                    "roughness": 0.35},
    "vinyl_oxblood": {"base_color": [0.26, 0.12, 0.11, 1.0],
                      "roughness": 0.55},
    "hoarding": {"base_color": [0.40, 0.37, 0.34, 1.0], "roughness": 0.82},
    "awning_vinyl": {"base_color": [0.61, 0.51, 0.09, 1.0],
                     "roughness": 0.42},
    # Signage surfaces used only by GDScript props; catalogued so the
    # audit can see them and GODOT_STAGE has a key to stage.
    "sign_board": {"base_color": [0.60, 0.56, 0.50, 1.0],
                   "roughness": 0.72},
    "chochin": {"base_color": [0.54, 0.15, 0.12, 1.0], "roughness": 0.88},
}


def main():
    floors = [build_floor(f) for f in
              ("B1", "F01", "F02", "F03", "F04", "F05", "F06", "ROOF")]
    removed_windows = sum(remove_partition_crossing_windows(fl)
                          for fl in floors)
    # Blinds hang LAST, after the facade audit. Windows are still being
    # deleted at this point - eighteen of them cross partitions and get
    # pulled - and a blind authored earlier would be left covering a
    # window that no longer exists.
    hung = 0
    for fl in floors:
        if fl["id"] in ("B1", "ROOF"):
            continue
        stacks = ("A", "D") if fl["id"] == "F01" else ("A", "B", "C", "D")
        for stack in stacks:
            hung += blinds_for_unit(fl["furniture"],
                                    unit_name(fl["id"], stack), stack,
                                    fl["walls"], float(fl["z"]))
    print("blinds: %d hung on real windows" % hung)
    print("facade audit: removed %d partition-crossing windows"
          % removed_windows)
    building_operations_pass(floors)
    for fl in floors:
        collect_door_markers(fl)
        light_fixture_markers(fl)
        signage_pass(fl)
        case_doors(fl)
        if fl["id"] != "ROOF":      # ROOF builds its own inside build_floor
            atrium_tree(fl)
    # Run after every architectural contributor, including atrium_tree,
    # otherwise the stairwell can reintroduce thin brick walls after audit.
    switch_coverage_pass(floors)
    if COVERAGE_SWITCHES_ADDED:
        print("added %d switch plates for rooms reached through archways"
              % len(COVERAGE_SWITCHES_ADDED))
    bathroom_switch_pass(floors)
    seated = seat_walls_under_the_floor_above(floors)
    if seated:
        print("seated %d wall(s) under the floor above" % seated)
    normalize_wall_construction(floors)
    resolve_wainscot_sides(floors)
    ceiling_pass(floors)
    radiator_pipe_pass(floors)
    aging_pass(floors)
    # The old global renovation treatment deliberately placed exposed-brick
    # panels over multiple storeys. Construction is now encoded by wall type:
    # only exterior masonry receives a damaged room-side finish in Blender.
    site_pass(floors[1])  # the block lives with F01
    retail_pass(floors[1])
    storm_pass(floors[1])
    street_lamp_markers(floors[1])
    classify_door_markers(floors)
    bookshelves = bookshelf_pass(floors)
    ventilation_registers = ventilation_register_pass(floors)
    vantry_points = vantry_point_pass(floors)
    layout = {
        "meta": {"name": "Orison Apartments", "footprint": [28.0, 20.0],
                 "levels": LEVELS, "floor_to_floor": F2F,
                 "wall_height": WALL_H, "slab_t": SLAB_T,
                 # The maintenance worker is canonically 5'0". Architecture
                 # stays at real scale so doors, residents, counters and
                 # switches communicate that stature without a UI label.
                 "player": {"height": 1.524, "eye": 1.41, "radius": 0.33,
                            "crouch": 0.96, "crouch_eye": 0.84,
                            "step_max": 0.28},
                 "residents": RESIDENTS},
        "floors": floors,
        "vantry_points": vantry_points,
        "ventilation_registers": ventilation_registers,
        "bookshelves": bookshelves,
        "stairs": [stair_geometry(ATRIUM)],
        "elevator": {"shaft": list(ELEV["shaft"]),
                     "cabin": list(ELEV["cabin"]),
                     "stops": {l: LEVELS[l] for l in ELEV["stops"]},
                     "door_w": ELEV["door_w"]},
    }
    problems = validate(layout)
    problems += validate_bookshelves(layout)
    if problems:
        for p in problems:
            print("VALIDATION:", p)
        raise SystemExit("layout validation failed (%d problems)" % len(problems))

    graph = acoustic_graph(layout)
    graph_problems = _validate_flue_graph(layout, graph)
    if graph_problems:
        for p in graph_problems:
            print("VALIDATION:", p)
        raise SystemExit("flue graph validation failed (%d problems)" %
                         len(graph_problems))
    print("flue fittings: 5 sealed thimbles on unchanged graph ids")

    with open(os.path.join(OUT_DIR, "building_layout.json"), "w") as f:
        json.dump(layout, f, indent=1)
    with open(os.path.join(OUT_DIR, "acoustic_graph.json"), "w") as f:
        json.dump(graph, f, indent=1)
    with open(os.path.join(OUT_DIR, "prop_catalog.json"), "w") as f:
        json.dump(PROP_CATALOG, f, indent=1)
    with open(os.path.join(OUT_DIR, "material_catalog.json"), "w") as f:
        json.dump(MATERIAL_CATALOG, f, indent=1)
    with open(os.path.join(OUT_DIR, "fixture_light_map.json"), "w") as f:
        json.dump(fixture_light_map(layout), f, indent=1)

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
