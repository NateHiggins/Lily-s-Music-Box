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
    markers.append({"kind": "radiator",
                    "id": "%s_%s_RADIATOR_01" % (floor_id, stack),
                    "pos": [rx, (y0 + y1) / 2.0, z],
                    "yaw_deg": 90 if not east else -90,
                    "network": "heating", "riser": "H-%s" % stack,
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
        _asm(f, unit + "_shower", "shower", x1 - 0.46, y0 + 0.50, 90)
        _bath_marker(markers, unit, "shower", x1 - 0.46, y0 + 0.50, 90, z)
        _asm(f, unit + "_wc", "toilet", x1 - 0.41, y0 + 1.22, 90)
        _asm(f, unit + "_sink", "sink_ped", x1 - 0.30, _run(y0 + 1.92, y0, y1), 90)
        _bath_marker(markers, unit, "sink", x1 - 0.30, _run(y0 + 1.92, y0, y1), 90, z)
        _bath_marker(markers, unit, "mirror", x1 - 0.30, _run(y0 + 1.92, y0, y1), 90, z)
        spos, syaw = [x1 - 0.08, y0 + 1.92], -90
    elif edge == "w":
        _asm(f, unit + "_shower", "shower", x0 + 0.46, y0 + 0.50, -90,
             mirror=True)
        _bath_marker(markers, unit, "shower", x0 + 0.46, y0 + 0.50, -90, z)
        _asm(f, unit + "_wc", "toilet", x0 + 0.41, y0 + 1.22, -90)
        _asm(f, unit + "_sink", "sink_ped", x0 + 0.30, _run(y0 + 1.92, y0, y1), -90)
        _bath_marker(markers, unit, "sink", x0 + 0.30, _run(y0 + 1.92, y0, y1), -90, z)
        _bath_marker(markers, unit, "mirror", x0 + 0.30, _run(y0 + 1.92, y0, y1), -90, z)
        spos, syaw = [x0 + 0.08, y0 + 1.92], 90
    else:  # "n"
        _asm(f, unit + "_shower", "shower", x0 + 0.50, y1 - 0.46, 180,
             mirror=True)
        _bath_marker(markers, unit, "shower", x0 + 0.50, y1 - 0.46, 180, z)
        _asm(f, unit + "_wc", "toilet", x0 + 1.22, y1 - 0.41, 180)
        _asm(f, unit + "_sink", "sink_ped", _run(x0 + 1.92, x0, x1), y1 - 0.30, 180)
        _bath_marker(markers, unit, "sink", _run(x0 + 1.92, x0, x1), y1 - 0.30, 180, z)
        _bath_marker(markers, unit, "mirror", _run(x0 + 1.92, x0, x1), y1 - 0.30, 180, z)
        spos, syaw = [x0 + 1.92, y1 - 0.08], 0
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
## The stove body still ships - it is what they put things ON.
RANGE_AS_SHELF = {"2C", "5B"}


def unit_of_uid(uid):
    """`4B_k` / `2C_k_stove` -> `4B`. Placement needs the flat, and the
    ids already carry it."""
    return str(uid).split("_")[0]


def _fridge_for(uid):
    return ("fridge_monitor" if unit_of_uid(uid) in MONITOR_TOP_UNITS
            else "fridge50")


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
    """The cabinet needs a prop as well as a body: its door swings, its
    lamp comes on when the seal breaks, and it holds somebody's food.
    None of that can happen inside a merged floor mesh.

    Seventeen of the eighteen flats had the assembly and no marker, so
    seventeen refrigerators were furniture. The marker sits exactly where
    the assembly does, so the prop's door lands on the mouth the cabinet
    left open for it - the same contract the range has used all along."""
    if markers is None:
        return
    unit = unit_of_uid(uid)
    markers.append({
        "kind": "fridge",
        "id": "%s_%s_FRIDGE_01" % (floor_id or "FXX", unit),
        "unit": unit, "pos": [round(fx, 4), round(fy, 4), round(z, 4)],
        "yaw_deg": yaw, "network": "electrical",
        "monitor": unit in MONITOR_TOP_UNITS})


def _bath_marker(markers, unit, kind, bx, by, yaw, z):
    """A tap is not a shape, it is a thing that turns.

    Twenty-three showers and twenty-three sinks were assemblies with no
    marker - the same fault the refrigerators had and the range never
    did. The porcelain, the cross taps and the valve plate are all
    modelled; what was missing was anything to spawn a prop that turns
    them and runs water.

    The marker sits exactly where the assembly does, so the prop's
    handles land on the spindles the assembly already built."""
    if markers is None:
        return
    # bath_fixtures is handed a level, not a floor name, so name the
    # marker from whichever level this z belongs to.
    floor_id = "FXX"
    for name, level in LEVELS.items():
        if abs(level - z) < 0.01:
            floor_id = name
            break
    markers.append({
        "kind": kind,
        "id": "%s_%s_%s_01" % (floor_id, unit, kind.upper()),
        "unit": unit, "pos": [round(bx, 4), round(by, 4), round(z, 4)],
        "yaw_deg": yaw, "network": "water"})


def _stove_marker(markers, uid, sx, sy, z, yaw, floor_id):
    """The range needs a prop as well as a body: its oven door swings and
    its rings light, and neither can happen inside a merged floor mesh.
    The marker sits exactly where the assembly does, so the prop's door
    lands on the mouth the assembly left open for it."""
    if markers is None:
        return
    unit = unit_of_uid(uid)
    markers.append({
        "kind": "stove",
        "id": "%s_%s_STOVE_01" % (floor_id or "FXX", unit),
        "unit": unit, "pos": [round(sx, 4), round(sy, 4), round(z, 4)],
        "yaw_deg": yaw, "network": "gas",
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
        # kept clear of the sink basin, which owns the counter's left
        # third (cutout at carcass x = 0.30*cw-cw/2 +- 0.22)
        items = (((cw * 0.06, 0.16), 0.22, 0.17, 0.11, "porcelain",
                  "mugs"),
                 ((cw * 0.08, -0.15), 0.24, 0.20, 0.07, "porcelain",
                  "plates"),
                 ((cw * 0.36, 0.02), 0.28, 0.20, 0.02, "timber", "board"))
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
        _stove_marker(markers, uid, x + cw + 0.33, cy, z, yaw, floor_id)
        _asm(f, uid + "_fr", _fridge_for(uid), x + cw + 0.66 + 0.36, cy,
             yaw)
        _fridge_marker(markers, uid, x + cw + 0.66 + 0.36, cy, z, yaw,
                       floor_id)
        clutter(x + cw / 2, cy)
        _hob_load(f, uid, x + cw + 0.33, cy)
        _lino_field(f, uid, x, y, cw, True, side)
    else:
        yaw = FACE_YAW["e" if side == "w" else "w"]
        cx = x + 0.32
        _asm(f, uid, "kitchen", cx, y + cw / 2, yaw, L=cw + 0.75)
        _asm(f, uid + "_stove", "stove", cx, y + cw + 0.33, yaw)
        _stove_marker(markers, uid, cx, y + cw + 0.33, z, yaw, floor_id)
        _asm(f, uid + "_fr", _fridge_for(uid), cx, y + cw + 0.66 + 0.36,
             yaw)
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
        _asm(f, unit + "_story_patterns", "pinboard", wall_x, pier_y,
             wall_yaw, z0=1.18, W=1.10, H=0.78, cards=18, neat=False)
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
        kitchen_run(f, unit + "_k", kx, ky, kL, kax, kside,
                    markers=markers, z=z, floor_id=floor_id)
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
    lived_in_surface_detail(f, unit, rooms, skip, ux, lcy)
    if unit in RESIDENT_STORIES:
        resident_story_detail(f, unit, RESIDENT_STORIES[unit][1],
                              rooms, ux, lcy, wface)

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
        # the captioner's order: everything squared to the desk edge
        _asm(f, "2A_pinboard", "pinboard", wface + 0.005, cy - 0.45, -90,
             z0=1.05, W=0.95, cards=15, neat=True)
        _asm(f, "2A_phones", "headphones", x0 + 2.32, cy - 0.35, -90,
             z0=1.05)
        _asm(f, "2A_papers", "papers", x0 + 0.62, cy - 0.30, 0,
             z0=0.735, n=5)
        _asm(f, "2A_mug", "mug", x0 + 1.32, cy - 0.60, 40, z0=0.735)
        _asm(f, "2A_deck", "reeldeck", x0 + 1.72, cy - 0.42, 0, z0=0.735)
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
        _asm(f, "3B_workbench", "workbench", x0 + 1.5, y0 + 3.37, 180)
        for i in range(2):
            shelf_unit(f, "3B_tools%d" % i, x0 + 2.85 + i * 1.10,
                       y1 - 0.45, 1.0, True, d=0.4, books=False, face="s")
        for i in range(4):
            _furn_box(f, "3B_bin%d" % i, x0 + 2.95 + i * 0.5, y1 - 0.40,
                      0.4, 0.28, 0.5 + (i % 2) * 0.46, 0.24,
                      ("metal", "fabric_cool")[i % 2], False)
        chair_box(f, "3B_stool", x0 + 1.3, y0 + 2.6, "s")
        mk("lamp", 1, x0 + 1.0, y0 + 3.5, 0.95)
        # the bench itself, sorted by category like the man sorts his life
        _asm(f, "3B_radio", "radio", x0 + 1.35, y0 + 3.22, 180, z0=0.91)
        _asm(f, "3B_toolboard", "toolboard", wface + 0.005, y0 + 3.27,
             -90, z0=1.15, W=0.9, H=0.65)
        _asm(f, "3B_tray1", "partstray", x0 + 2.0, y0 + 3.29, -8,
             z0=0.91, chassis=True)
        _asm(f, "3B_tray2", "partstray", x0 + 0.78, y0 + 3.37, 94,
             z0=0.91)
        _asm(f, "3B_jars", "jarrow", x0 + 1.62, y0 + 3.62, 0, z0=0.91,
             n=5)
        _asm(f, "3B_manuals", "bookpile", x0 + 0.58, y0 + 3.17, 25,
             z0=0.91, n=4)
        _asm(f, "3B_mug", "mug", x0 + 1.0, y0 + 3.39, 0, z0=0.91,
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
                   h=1.4, face="n")
        chair_box(f, "5A_stool", cx + 0.7, cy + 1.55, "n")
        mk("lamp", 1, cx + 0.6, cy + 0.75, 0.83)
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
        _furn_box(f, "6A_dwlegs", x0 + 0.5, cy - 1.1, 0.6, 2.4, 0.0, 0.72,
                  "metal", False)
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
        {"id": "bed", "rect": [-13.40, 6.90, -12.05, 9.50], "z0": 0.15,
         "h": 0.32, "mat": "trim"},
        {"id": "kitchen_counter", "rect": [-10.70, 9.05, -8.85, 9.55],
         "z0": 0.0, "h": 0.86, "mat": "trim"},
    ]
    # countertop laid as four boards around the sink cutout, so the basin
    # below is a real hole rather than a dark rectangle painted on
    sb = (-10.18, 9.12, -9.68, 9.50)          # basin opening
    for seg, rect in (
            ("w", [-10.74, 9.01, sb[0], 9.59]),
            ("e", [sb[2], 9.01, -8.81, 9.59]),
            ("s", [sb[0], 9.01, sb[2], sb[1]]),
            ("n", [sb[0], sb[3], sb[2], 9.59])):
        # 4B-prefixed on purpose: the life audit checks the player flat by
        # semantic id, and an anonymous counter is invisible to it.
        furniture.append({"id": "4B_kitchen_countertop_" + seg,
                          "rect": rect,
                          "z0": 0.86, "h": 0.045, "mat": "countertop"})
    _asm(furniture, "4B_ksink", "sink_basin",
         (sb[0] + sb[2]) / 2.0, (sb[1] + sb[3]) / 2.0, 180, z0=0.905,
         W=sb[2] - sb[0], D=sb[3] - sb[1])
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
    # the sink is a real basin assembly now (4B_ksink); the flat plate and
    # its stick faucet that used to stand in for it are gone
    fb("mugs", (-9.62, 9.15, -9.40, 9.32), 0.905, 0.11)
    fb("plates", (-9.30, 9.16, -9.06, 9.36), 0.905, 0.07)
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
        # The plant room tells the building's heating history in one
        # look: the 1926 coal boiler dead where it stood, the oil boiler
        # that replaced it piped into the same chimney beside it, and
        # what is left of the last coal delivery in the bunker.
        #
        # The heap used to be a rectangular block of SLAB - grey
        # concrete in the shape of a crate, which is what read as a
        # white blob in the corner of the coal room.
        _asm(furniture, "b1_coal_furnace", "coal_furnace", 9.05, 1.55, 0)
        _asm(furniture, "b1_modern_boiler", "modern_boiler", 7.35, 1.62, 0)
        _asm(furniture, "b1_coal_heap", "coal_heap", 12.85, 1.50, 0,
             W=0.95, D=1.70, H=0.58)
        markers += [
            {"kind": "boiler", "id": "B1_BOILER_01", "pos": [10.0, 5.0, z],
             "yaw_deg": 0, "network": "heating"},
            # Against the west party wall in a row, plumbed off one
            # stack. They used to stand up to 2.3 m out in open floor,
            # which reads as machines abandoned mid-delivery rather
            # than a laundry room.
            {"kind": "washer", "id": "B1_WASHER_01",
             "pos": [-13.28, 3.55, z],
             "yaw_deg": -90, "network": "water"},
            {"kind": "washer", "id": "B1_WASHER_02",
             "pos": [-13.28, 4.35, z],
             "yaw_deg": -90, "network": "water"},
            {"kind": "dryer", "id": "B1_DRYER_01",
             "pos": [-13.28, 5.15, z],
             "yaw_deg": -90, "network": "electrical"},
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
    west_storage(floor_id, z, furniture)
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


EXTERIOR_SWITCHES_DROPPED = []


COVERAGE_SWITCHES_ADDED = []

LIGHT_KINDS_FOR_SWITCH = ("flush_dome", "pendant_shade", "sconce_globe",
                          "kitchen_linear", "cage_bulb", "chandelier",
                          "eye_pendant", "ceiling_light", "corridor_light")


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
    """Continue every heating riser from slab to ceiling."""
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
                "p0": [0.44, 0.0, 0.0], "p1": [0.44, 0.0, clear_h]})


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
CITY_BLOCKS = [
    # north side (our side), running west from the Orison
    ("nbr_w", (-19.6, -12.0, -15.2, 12.0), 12.8),
    ("nw1", (-27.4, -14.2, -20.2, 11.0), 16.4),
    ("nw2", (-36.0, -14.2, -28.0, 9.5), 10.9),
    ("nw3", (-47.5, -14.2, -36.6, 12.0), 19.2),
    ("nw4", (-58.0, -14.2, -48.1, 10.0), 13.6),
    # north side, running east
    ("nbr_e", (15.2, -12.0, 19.6, 12.0), 12.8),
    ("ne1", (20.2, -14.2, 28.8, 11.5), 14.7),
    ("ne2", (29.4, -14.2, 37.0, 9.0), 21.5),
    ("ne3", (37.6, -14.2, 48.4, 12.0), 11.2),
    ("ne4", (49.0, -14.2, 58.0, 10.5), 17.8),
    # south side of the street, opposite
    # South side. Faces all sit on BLDG_S; depths vary because a real
    # block is not one slab, and these are deep enough now to read as
    # buildings from the roof rather than as a row of flats.
    ("nbr_s1", (-20.0, -39.0, -7.0, -28.32), 10.4),
    ("nbr_s2", (-5.6, -38.2, 6.4, -28.32), 15.8),
    ("nbr_s3", (7.8, -37.6, 20.0, -28.32), 8.6),
    ("sw1", (-33.0, -39.4, -20.6, -28.32), 14.2),
    ("sw2", (-46.0, -38.0, -33.6, -28.32), 9.8),
    ("sw3", (-58.0, -40.4, -46.6, -28.32), 18.5),
    ("se1", (20.6, -38.6, 32.0, -28.32), 12.6),
    ("se2", (32.6, -39.8, 44.5, -28.32), 20.4),
    ("se3", (45.1, -37.4, 58.0, -28.32), 10.2),
    # the vista stops: masses across both ends of the street, as if the
    # road bends behind them. Without these you see sky down the pavement.
    ("end_w", (-62.0, -40.4, -58.6, 14.0), 24.6),
    ("end_e", (58.6, -40.4, 62.0, 14.0), 22.3),
    # behind the alley
    ("back_w", (-30.0, 18.1, -12.0, 24.5), 15.4),
    ("back_e", (12.0, 18.1, 31.0, 24.5), 18.9),
]

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
    for bid, rect, hgt in CITY_BLOCKS:
        gz = HOLLOW.get(bid, 0.0)
        fb(bid, rect, gz, hgt - gz, "common_brick")
        # a parapet lip catches the moon and stops every roof reading as a
        # clean extrusion
        x0, y0, x1, y1 = rect
        fb(bid + "_cap", (x0 - 0.12, y0 - 0.12, x1 + 0.12, y1 + 0.12),
           hgt, 0.34, "limestone")
        _city_windows(fb, lights, rng, bid, rect, hgt,
                      min_z=HOLLOW.get(bid, 0.0))

    for bid, rect, hgt in FAR_SKYLINE:
        fb(bid, rect, 0.0, hgt, "common_brick")
        fb(bid + "_cap", (rect[0] - 0.3, rect[1] - 0.3, rect[2] + 0.3,
           rect[3] + 0.3), hgt, 0.7, "limestone")
        _city_windows(fb, lights, rng, bid, rect, hgt, storey=3.8)

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

    def fb(bid, rect, z0, h, mat):
        furn.append({"id": "storm_" + bid, "rect": list(rect), "z0": z0,
                     "h": h, "mat": mat})

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
    fb("bin_down", (18.6, -13.4, 19.7, -12.35), 0.0, 0.62, "metal")
    fb("bin_lid", (20.3, -12.9, 20.95, -12.3), 0.008, 0.05, "metal")
    fb("umbrella_canopy", (-16.8, -14.9, -15.7, -14.35), 0.01, 0.16,
       "fabric_cool")
    fb("umbrella_shaft", (-15.75, -14.66, -14.9, -14.6), 0.02, 0.03,
       "metal")
    # Wet still coming off the building: a dark run below each downpipe
    for i, dx in enumerate((-13.4, 13.2)):
        fb("downrun%d" % i, (dx, -10.5, dx + 0.5, -10.05), 0.005, 0.002,
           "wet_asphalt")


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
        "yaw_deg": 30, "network": "electrical"})


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
    "fridge50": [("FRIDGE_FACE", 0.0, 0.45)],
    "sink_ped": [("SINK_EDGE", 0.3, 0.0)],
    "shower": [("SHOWER_EDGE", 0.55, 0.0)],
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
                    "shower": "washing", "stove": "cooking",
                    "fridge50": "cold storage", "kitchen": "kitchen run"}
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
                continue
            # Cold storage is a FUNCTION, not one assembly name: four
            # flats never replaced their 1927 monitor-top, and an icebox
            # that keeps milk cold satisfies the same need as a 1950s
            # cabinet. Any equivalent set is satisfied by any member.
            equivalents = {"fridge50": ("fridge50", "fridge_monitor")}
            for asm, label in need.items():
                if sum(kinds.get(a, 0)
                       for a in equivalents.get(asm, (asm,))) == 0:
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
    # counter by the door
    fb("bod_counter", (17.05, -11.0, 18.35, -10.35), 0.0, 0.95,
       "wood_dark")
    fb("bod_counter_top", (17.0, -11.05, 18.40, -10.30), 0.95, 0.05,
       "countertop")
    fb("bod_register", (17.25, -10.9, 17.75, -10.45), 1.00, 0.30,
       "bakelite")
    asm("bod_papers", "papers", 18.05, -10.6, 0)
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
    mk.append({"kind": "door", "id": "F01_BODEGA_DOOR",
               "pos": [18.67, -11.92, 0.0], "yaw_deg": 0, "w": 0.90,
               "h": 2.10, "leaf": "closed", "exterior": True})
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
    KX0, KX1 = -5.6, 6.4
    FACE = -28.32
    RX0, RX1 = -5.10, 4.00           # room clear span, east-west
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
    fb("bar_fill_w", (KX0, -38.2, RX1, FACE), 0.0, 3.55, "common_brick")
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
    # litter on the way down
    asm("bar_lit_paper", "papers", 4.70, -31.35, 35, z0=-0.95)
    asm("bar_lit_bott", "bottles", 5.15, -32.85, 0, z0=-1.93)
    asm("bar_lit_crate", "crate", 4.55, -29.30, 55, z0=0.0)

    # the room shell
    fb("bar_floor", (RX0 - 0.30, RY0 - 0.30, RX1, RY1 + 0.05), -2.87,
       0.07, "quarry_tile")
    fb("bar_ceil", (RX0 - 0.30, RY0 - 0.30, RX1, RY1 + 0.05), -0.15,
       0.43, "soot")
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
    fb("bar_deck", (LD_X0, LD_Y0, RX1, LD_Y1), FLR, 0.18, "quarry_tile")
    fb("bar_deck_nose", (LD_X0 - 0.06, LD_Y0, LD_X0, LD_Y1), FLR,
       0.18, "wood_dark")
    # two steps down into the table floor, opposite the door
    for si, sy in enumerate((-34.30, -33.70)):
        fb("bar_step%d" % si, (LD_X0 - 0.34, sy, LD_X0, sy + 0.58),
           FLR, 0.09, "wood_dark")
    # the railing: newels, turned balusters, moulded rail. Split either
    # side of the step opening so the way down is actually a way down.
    for seg, (ry0, ry1) in enumerate(((LD_Y0 + 0.10, -34.40),
                                      (-33.60, LD_Y1 - 0.10))):
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
    for i, (by, ln) in enumerate(((-37.10, 1.60), (-35.30, 1.50),
                                  (-33.40, 1.40))):
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
    TABLES = [(-2.55, -35.60, 3), (-0.75, -35.95, 2), (0.85, -34.60, 3),
              (-2.35, -33.40, 2), (-0.55, -32.85, 3), (0.95, -31.85, 2),
              (-2.75, -31.55, 3)]
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

    # -- POOL TABLE, west aisle, out of the walking line
    fb("bar_pool_body", (-4.70, -34.60, -2.70, -33.30), FLR, 0.78,
       "wood_dark")
    fb("bar_pool_felt", (-4.58, -34.48, -2.82, -33.42), FLR + 0.78,
       0.04, "felt_violet")
    for i, (bx, by, mat) in enumerate((
            (-3.95, -34.10, "enamel"), (-3.60, -33.80, "terracotta"),
            (-3.30, -34.15, "brass"), (-3.00, -33.70, "fabric_green"),
            (-3.75, -33.55, "bakelite"))):
        fb("bar_ball%d" % i, (bx, by, bx + 0.06, by + 0.06),
           FLR + 0.82, 0.055, mat)
    pipe("bar_cue", (-2.55, -33.15, FLR + 0.05),
         (-2.30, -33.35, FLR + 1.50), 0.012, "timber")

    # -- PLANTS. Canon: tall indoor palms, improbably alive.
    asm("bar_palm0", "plant", -4.55, -31.90, 0, z0=FLR)
    asm("bar_palm1", "plant", 1.35, -37.20, 0, z0=DECK)
    asm("bar_palm2", "plant", 3.70, -32.45, 0, z0=DECK)

    # -- RESTROOM, far SW corner
    fb("bar_wc_wall_e", (-3.40, RY0, -3.25, -36.10), FLR, 2.60,
       "bar_wall_red")
    fb("bar_wc_wall_n_w", (RX0, -36.25, -4.45, -36.10), FLR, 2.60,
       "bar_wall_red")
    fb("bar_wc_wall_n_e", (-3.75, -36.25, -3.25, -36.10), FLR, 2.60,
       "bar_wall_red")
    fb("bar_wc_lintel", (-4.45, -36.25, -3.75, -36.10), FLR + 2.05,
       0.55, "bar_wall_red")
    asm("bar_wc_toilet", "toilet", -4.75, -37.45, 0, z0=FLR)
    asm("bar_wc_sink", "sink_basin", -3.70, -37.50, 0, z0=FLR)
    mk.append({"kind": "door", "id": "F01_BAR_WC_DOOR",
               "pos": [-4.10, -36.17, FLR], "yaw_deg": 0, "w": 0.70,
               "h": 2.00, "leaf": "closed", "exterior": True})

    # -- doors, signs, lights
    mk.append({"kind": "door", "id": "F01_BAR_DOOR",
               "pos": [4.875, FACE - 0.10, 0.0], "yaw_deg": 180,
               "w": 0.90, "h": 2.10, "leaf": "closed", "exterior": True})
    mk.append({"kind": "door", "id": "F01_BAR_RED_DOOR",
               "pos": [4.15, -34.42, FLR], "yaw_deg": 90, "w": 0.90,
               "h": 2.05, "leaf": "closed", "exterior": True})
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
    mk.append({"kind": "cage_bulb", "id": "F01_BAR_LT_LOBBY",
               "unit": "SITE", "pos": [4.875, -29.30, 2.30],
               "yaw_deg": 0, "network": "electrical", "range": 3.5,
               "energy": 0.4, "navigation": True, "standby": 0.35,
               "exterior": True})
    mk.append({"kind": "cage_bulb", "id": "F01_BAR_LT_STAIR",
               "unit": "SITE", "pos": [5.30, -32.60, 0.55],
               "yaw_deg": 0, "network": "electrical", "range": 3.5,
               "energy": 0.4, "navigation": True, "standby": 0.35,
               "exterior": True})
    for i, lx in enumerate((-3.2, -0.9)):
        mk.append({"kind": "kitchen_linear", "id": "F01_BAR_LT_CAN%d" % i,
                   "unit": "SITE", "pos": [lx, -29.70, -1.06],
                   "yaw_deg": 90, "network": "electrical", "range": 5.0,
                   "energy": 0.55, "navigation": True, "standby": 0.4,
                   "exterior": True})
    mk.append({"kind": "pendant_shade", "id": "F01_BAR_LT_POOL",
               "unit": "SITE", "pos": [-3.70, -33.95, -0.75],
               "yaw_deg": 0, "network": "electrical", "range": 4.0,
               "energy": 0.45, "navigation": True, "standby": 0.4,
               "exterior": True})
    # a low pendant over every other table: the study is lit almost
    # entirely by small warm sources hung close over people
    for i, (tx, ty, _s) in enumerate(TABLES):
        if i % 2:
            continue
        mk.append({"kind": "pendant_shade",
                   "id": "F01_BAR_LT_TAB%d" % i, "unit": "SITE",
                   "pos": [tx, ty, -0.82], "yaw_deg": 0,
                   "network": "electrical", "range": 3.2,
                   "energy": 0.38, "navigation": True, "standby": 0.35,
                   "exterior": True})
    for i, sx in enumerate((-1.90, 0.50)):
        mk.append({"kind": "cage_bulb", "id": "F01_BAR_LT_STAGE%d" % i,
                   "unit": "SITE", "pos": [sx, -36.55, -0.95],
                   "yaw_deg": 0, "network": "electrical", "range": 3.6,
                   "energy": 0.5, "navigation": True, "standby": 0.3,
                   "exterior": True})
    mk.append({"kind": "sconce_globe", "id": "F01_BAR_LT_DECK",
               "unit": "SITE", "pos": [3.92, -34.90, -1.30],
               "yaw_deg": 270, "network": "electrical", "range": 3.4,
               "energy": 0.42, "navigation": True, "standby": 0.35,
               "exterior": True})
    mk.append({"kind": "cage_bulb", "id": "F01_BAR_LT_WC",
               "unit": "SITE", "pos": [-4.30, -37.10, FLR + 2.35],
               "yaw_deg": 0, "network": "electrical", "range": 2.5,
               "energy": 0.4, "navigation": True, "standby": 0.35,
               "exterior": True})

    # =================== THE WALLS OF THE WORLD =======================
    for bay in range(3):
        sx = -20.2 - bay * 1.8
        for py in (-10.1, -12.3, -14.4):
            pipe("scaf_w%d_%d" % (bay, int(-py * 10)),
                 (sx, py, 0.0), (sx, py, 4.6), 0.038)
        pipe("scaf_wl%d" % bay, (sx, -10.1, 2.55), (sx, -14.4, 2.55),
             0.030)
    fb("scaf_w_deck", (-25.6, -14.6, -19.9, -9.9), 2.60, 0.06, "plywood")
    fb("scaf_w_hoard", (-20.35, -14.70, -20.15, -9.85), 0.0, 2.55,
       "hoarding")
    fb("scaf_w_hoard2", (-25.6, -10.05, -20.2, -9.85), 0.0, 2.55,
       "hoarding")
    fb("scaf_e_hoard", (20.05, -14.70, 20.25, -9.85), 0.0, 2.55,
       "hoarding")
    fb("scaf_e_deck", (20.0, -14.6, 24.4, -9.9), 2.60, 0.06, "plywood")
    for bay in range(2):
        sx = 20.5 + bay * 1.9
        for py in (-10.1, -14.4):
            pipe("scaf_e%d_%d" % (bay, int(-py * 10)),
                 (sx, py, 0.0), (sx, py, 4.6), 0.038)
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
    fb("hoard_s_w", (-20.35, -28.30, -20.15, -23.95), 0.0, 2.55,
       "plywood")
    fb("hoard_s_e", (20.15, -28.30, 20.35, -23.95), 0.0, 2.55, "plywood")
    fb("alley_fence_w", (-16.35, 10.0, -16.20, 14.9), 0.0, 2.4, "metal")
    fb("alley_fence_e", (16.20, 10.0, 16.35, 14.9), 0.0, 2.4, "metal")
    fb("dumpster", (13.8, 11.0, 16.0, 12.6), 0.0, 1.35, "metal")
    fb("dumpster_lid", (13.75, 11.0, 16.05, 12.65), 1.35, 0.09, "soot")
    for i, (px, py) in enumerate(((16.3, -14.35), (17.6, -14.35),
                                  (18.9, -14.35), (-16.3, -14.35),
                                  (-17.6, -14.35), (-18.9, -14.35),
                                  (16.6, -12.35), (20.4, -12.35))):
        pipe("bollard%d" % i, (px, py, 0.0), (px, py, 0.95), 0.085)
    # ---- ROUTE DISCIPLINE: the walkable world is three paths --------
    # (1) the Orison's circumference: front walk between the gangways,
    #     the gangways themselves, the alley behind between the fences;
    # (2) the crossing to the Harukiya, inside the trench corridor;
    # (3) the walk east to the bodega.
    # Everything else ends diegetically. Two more utility trenches cut
    # the roadway so the only crossing is the one in front of the door,
    # and the far pavement is hoarded beyond the bar's own block.
    fb("walk_w_hoard", (-15.55, -14.70, -15.35, -9.85), 0.0, 2.55,
       "plywood")
    for tag, dx0, dx1, bxx in (("mw", -8.4, -6.4, -6.15),
                               ("me", 10.6, 12.6, 12.85)):
        fb("dig_%s_pit" % tag, (dx0, -23.7, dx1, -14.9), -0.55, 0.53,
           "soot")
        fb("dig_%s_spoil" % tag, (dx0 + 0.3, -19.6, dx1 - 0.3, -17.6),
           0.0, 0.75, "soil")
        for i in range(4):
            asm("dig_%s_bar%d" % (tag, i), "safety_barrier", bxx,
                -15.9 - i * 2.1, 90 if tag == "mw" else -90)
    fb("swalk_hoard_w", (-6.6, -28.30, -6.4, -23.95), 0.0, 2.55,
       "plywood")
    fb("swalk_hoard_e", (10.4, -28.30, 10.6, -23.95), 0.0, 2.55,
       "plywood")
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

    # ============== BAND 1: relief on the facing facades ==============
    for tag, fx0, fx1, awn in (("s1a", -18.6, -14.4, "fabric_green"),
                               ("s1b", -13.2, -8.4, "fabric_cool"),
                               ("s3a", 9.0, 13.6, "fabric_warm"),
                               ("s3b", 14.6, 18.8, "fabric_green")):
        fy = -28.32
        fb("shop_%s_riser" % tag, (fx0, fy - 0.05, fx1, fy + 0.08), 0.0,
           0.60, "wood_dark")
        fb("shop_%s_glass" % tag, (fx0 + 0.1, fy, fx1 - 0.1, fy + 0.06),
           0.60, 1.90, "glassish")
        fb("shop_%s_gate" % tag, (fx0 + 0.05, fy + 0.02, fx1 - 0.05,
           fy + 0.10), 0.05, 2.45, "chrome")
        fb("shop_%s_fascia" % tag, (fx0, fy - 0.08, fx1, fy + 0.14),
           2.50, 0.55, "soot")
        fb("shop_%s_awn" % tag, (fx0, fy - 1.05, fx1, fy + 0.05), 2.45,
           0.09, awn)
    fb("shop_w_riser", (-19.5, -11.95, -15.3, -11.82), 0.0, 0.6,
       "wood_dark")
    fb("shop_w_gate", (-19.45, -11.92, -15.35, -11.84), 0.6, 1.95,
       "chrome")
    fb("shop_w_fascia", (-19.6, -12.0, -15.2, -11.78), 2.55, 0.55,
       "enamel")


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
    fb("bench_seat", (10.4, -13.5, 12.6, -12.9), 0.44, 0.07, "timber")
    for bx in (10.5, 12.4):
        fb("bench_leg%d" % int(bx), (bx, -13.45, bx + 0.1, -12.95), 0.0,
           0.44, "metal")
    fb("booth", (-12.4, -13.7, -11.5, -12.8), 0.0, 2.3, "metal")
    fb("booth_glass", (-12.3, -13.6, -11.6, -12.9), 0.7, 1.35, "glassish")
    # Bus shelter, on the SOUTH pavement and well west of the door.
    # It used to stand at x 2.0..6.4, y -18.0 - which is the middle of
    # the carriageway, and directly between the Orison's front door and
    # the bar's. It was authored before the street was widened to a true
    # 60 ft and never moved with it, so the one crossing a resident
    # actually needs was blocked by a bus shelter nobody could reach.
    SH_X, SH_Y = -12.6, -25.55        # south walk, -23.894..-28.316
    fb("shelter_roof", (SH_X, SH_Y - 1.40, SH_X + 4.4, SH_Y), 2.45, 0.12,
       "metal")
    for so in (0.05, 4.25):
        fb("shelter_post%d" % int(so * 10),
           (SH_X + so, SH_Y - 1.32, SH_X + so + 0.1, SH_Y - 0.02),
           0.0, 2.45, "metal")
    fb("shelter_back", (SH_X + 0.15, SH_Y - 1.35, SH_X + 4.25,
                        SH_Y - 1.30), 0.45, 1.85, "glassish")
    fb("shelter_mullion", (SH_X + 2.1, SH_Y - 1.36, SH_X + 2.2,
                           SH_Y - 1.29), 0.45, 1.85, "metal")
    fb("shelter_sill", (SH_X + 0.05, SH_Y - 1.37, SH_X + 4.35,
                        SH_Y - 1.28), 0.36, 0.09, "metal")
    fb("shelter_head", (SH_X + 0.05, SH_Y - 1.37, SH_X + 4.35,
                        SH_Y - 1.28), 2.30, 0.11, "metal")
    fb("shelter_bench", (SH_X + 0.4, SH_Y - 1.22, SH_X + 4.0,
                         SH_Y - 0.78), 0.42, 0.08, "timber")
    # parked cars down both kerbs, with gaps where hydrants and the stoop are
    for i in range(9):
        cx = -26.0 + i * 6.6
        if abs(cx + 2.2) < 5.5:
            continue
        fb("car%d" % i, (cx, -16.9, cx + 4.4, -15.1), 0.28, 0.95, "metal")
        fb("cartop%d" % i, (cx + 1.1, -16.7, cx + 3.3, -15.3), 1.23, 0.45,
           "metal")
        fb("carglass%d" % i, (cx + 1.15, -16.65, cx + 3.25, -15.35), 1.26,
           0.38, "glassish")
    for i in range(7):
        cx = -21.0 + i * 7.4
        # This row was parked at y -18.9..-17.4, which after the street
        # was widened is the middle of the road rather than the south
        # kerb it is named for - and one of them sat squarely across the
        # walk to the bar. It parks at the kerb now, and leaves the same
        # gap at the crossing that the north row already leaves.
        if abs(cx + 0.6) < 6.2:
            continue
        # y0 < y1: an inverted rect makes a degenerate box, and the first
        # version of this row silently produced nothing at all
        fb("scar%d" % i, (cx, -23.75, cx + 4.3, -22.25), 0.28, 0.95,
           "metal")
        fb("scartop%d" % i, (cx + 1.1, -23.55, cx + 3.2, -22.45), 1.23,
           0.45, "metal")
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
    problems += life_pass(layout["floors"])
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
            if m.get("exterior"):
                # Retail markers live at street furniture heights and,
                # for the basement bar, at NEGATIVE z relative to their
                # floor. Their placement is authored against their own
                # interior, not against a storey the validator knows.
                continue
            kind = m["kind"]
            px, py, pz = m["pos"]
            if kind == "corridor_light":
                problems.append("%s: legacy floor-level corridor light %s"
                                % (fl["id"], m["id"]))
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
                    "switch", "pipe", "sink_ped", "mailbank",
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
    "kitchen": (0.90, 0.33), "stove": (0.32, 0.34), "fridge50": (0.34, 0.41),
    "desk": (0.71, 0.34), "plantable": (1.01, 0.61),
    "workbench": (1.11, 0.49), "toilet": (0.21, 0.36),
    "sink_ped": (0.25, 0.25), "shower": (0.41, 0.42), "bench": (0.76, 0.25),
    "mailbank": (0.81, 0.10),
    # floor-standing personality clutter (tabletop pieces are absent on
    # purpose: they never block a route)
    "amp": (0.31, 0.17), "guitar": (0.20, 0.17),
    "pedalboard": (0.32, 0.18), "micstand": (0.15, 0.15),
    "tripod": (0.32, 0.32), "softbox": (0.28, 0.28), "crate": (0.23, 0.20),
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
            if m.get("exterior"):
                # A shop door's swing sweeps over its own storefront -
                # stall riser, mullions, the shop's own walls. The
                # validator cannot tell a storefront's fabric from an
                # obstruction, and the street fittings around it are
                # equally its own. Interior doors keep the full check.
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
    unit_asm, unit_yaw, unit_rad, unit_detail, unit_story = {}, {}, set(), {}, {}
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
            if fu["id"].endswith(("_k", "_k_stove", "_k_fr")):
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
        if unit_detail.get(unit, 0) < 4:
            problems.append("%s lacks close surface detail (%d < 4)"
                            % (unit, unit_detail.get(unit, 0)))
        # Same equivalence as the life audit: a monitor-top IS the flat's
        # refrigerator, it is simply forty years older than its neighbours'.
        fridge_kinds = ("fridge50", "fridge_monitor")
        for k, n in need.items():
            have = (sum(a.get(f, 0) for f in fridge_kinds)
                    if k == "fridge50" else a.get(k, 0))
            if have < n:
                problems.append("%s missing %s (%d < %d)"
                                % (unit, k, have, n))
        if a.get("table_round", 0) + a.get("table_rect", 0) < 1:
            problems.append("%s has no dining table" % unit)
        yaws = unit_yaw.get(unit, set())
        if len(yaws) > 1:
            problems.append("%s kitchen trio facing disagrees %s"
                            % (unit, sorted(yaws)))
    for unit in RESIDENT_STORIES:
        if unit_story.get(unit, 0) < 2:
            problems.append("%s lacks resident story props (%d < 2)"
                            % (unit, unit_story.get(unit, 0)))
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
                               "eye_pendant", "neon_sign"):
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
    # appliance & hardware finishes for the parametric asset library
    "chrome": {"base_color": [0.80, 0.82, 0.85, 1.0], "roughness": 0.12,
               "metallic": 1.0},
    "enamel": {"base_color": [0.91, 0.89, 0.83, 1.0], "roughness": 0.18},
    "bakelite": {"base_color": [0.16, 0.12, 0.10, 1.0], "roughness": 0.30},
    "porcelain": {"base_color": [0.92, 0.93, 0.92, 1.0], "roughness": 0.14},
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
    seated = seat_walls_under_the_floor_above(floors)
    if seated:
        print("seated %d wall(s) under the floor above" % seated)
    normalize_wall_construction(floors)
    resolve_wainscot_sides(floors)
    radiator_pipe_pass(floors)
    aging_pass(floors)
    # The old global renovation treatment deliberately placed exposed-brick
    # panels over multiple storeys. Construction is now encoded by wall type:
    # only exterior masonry receives a damaged room-side finish in Blender.
    site_pass(floors[1])  # the block lives with F01
    retail_pass(floors[1])
    storm_pass(floors[1])
    street_lamp_markers(floors[1])
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
