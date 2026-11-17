"""Generate game/data/dream_module_catalog.json from the V2 building (order wc0265c4a2ba0, Lily's ruling
dream_v2_direction_20261116: "1 now", The Remembered Orison).

The dream's rooms are the fractal Orison's vocabulary (dream_atlas.gd): every room in the endless dream building is
a real Orison space. They were cut from V1's floor plan, which was removed on 2026-11-11. Here each module names the
V2 blockout spaces it is made from and how they are put together; every footprint is computed from the blockout's
own rectangles, never typed. The module ids, the topology and the hazard grammar are unchanged, so the atlas, the
room builder, the furnisher and the interior keep working on the same vocabulary.

    python tools/generate_dream_module_catalog.py            write the catalog
    python tools/generate_dream_module_catalog.py --check    fail if the committed catalog differs

Run it again whenever the V2 blockout changes; never edit the catalog by hand.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BLOCKOUT = ROOT / "game/data/orison_v2_blockout.json"
CATALOG = ROOT / "game/data/dream_module_catalog.json"
SCHEDULES = ROOT / "game/data/resident_schedules.json"
PROFILES = ROOT / "game/data/dream_profiles.json"

CONNECTOR_W = 0.91
CONNECTOR_H = 2.13
MARGIN = 0.10

# How each module is made. `spaces` are blockout space ids (or platform/envelope ids where noted); `along` is the
# blockout axis that becomes the module's length ("x" east-west, "z" north-south); `join` is how several spaces make
# one room: "exact" (one space), "end_to_end" (lengths summed, depth the shallowest, so they share one wall), or
# "remembered" (one space's section run on to `times` its length: the hall that goes on longer than it can).
# Connector offsets and hazard positions are fractions of the side or footprint, so they follow the real rooms.
MODULES = {
    "D00_4B_THRESHOLD": {
        "unlock_slot": 1, "spaces": ["F04_B_VESTIBULE"], "along": "x", "join": "exact",
        "derivation": "exact 4B vestibule footprint",
        "connectors": [("entry", "west", 0.5, "none"), ("out", "east", 0.5, "in")],
        "hazards": [],
    },
    "D01_F04_LONG_HALL": {
        "unlock_slot": 1, "spaces": ["F04_FRONT_HALL"], "along": "x", "join": "remembered", "times": 2.0,
        "detail_repeat_range": [3, 5],
        "derivation": "the F04 front hall's exact 3.45 m section and finishes, run on to twice its 10.50 m length",
        "connectors": [("in", "west", 0.5, "none"), ("stair_branch", "north", 0.85, "out"),
                       ("lift_branch", "south", 0.85, "out"), ("return", "south", 0.06, "in")],
        "hazards": [("hollow_runner", "conditional", (0.57, 0.5), 0.35, 4.6, 0.75)],
    },
    "D02_DOGLEG_STAIR": {
        "unlock_slot": 2, "spaces": ["F04_PUBLIC_CORE"], "along": "x", "join": "exact", "vertical_rise_m": 3.2,
        "derivation": "exact F04 public core: the primary U stair (1.05 m flights, 1.0 m gap) and its landing",
        "connectors": [("in", "south", 0.5, "none"), ("out", "east", 0.5, "none")],
        "hazards": [],
    },
    "D03_LIFT_VOID": {
        "unlock_slot": 1, "spaces": ["F04_PUBLIC_LANDING_W_SHAFT_1"], "along": "z", "join": "exact",
        "platforms": True,
        "derivation": "exact F04 passenger-lift landing beside the 2.40 x 2.50 m lift reservation and its 0.91 m door",
        "connectors": [("in", "north", 0.5, "in"), ("out", "east", 0.5, "none")],
        "hazards": [("open_lift_void", "positional", (0.38, 0.5), 0.45, 5.5, 0.9),
                    ("counterweight_passage", "rhythmic", (0.77, 0.5), 0.40, 4.6, 0.75)],
    },
    "D04_BATHROOM_PROCESSION": {
        "unlock_slot": 1, "spaces": ["F04_A_BATH", "F04_B_BATH", "F04_C_BATH", "F04_D_BATH"], "along": "x",
        "join": "end_to_end",
        "derivation": "the four F04 bathrooms at their exact widths, end to end along one impossible wet wall, "
                      "cut to the shallowest so they share it",
        "connectors": [("stair_in", "west", 0.76, "in"), ("lift_in", "west", 0.24, "in"), ("out", "east", 0.5, "out")],
        "hazards": [],
    },
    "D05_SERVICE_RISER": {
        "unlock_slot": 1, "spaces": ["F04_SERVICE_HALL"], "along": "z", "join": "exact",
        "derivation": "exact F04 service hall, the maintenance run behind the flats' heat, water and signal",
        "connectors": [("in", "west", 0.5, "none"), ("plant_branch", "north", 0.83, "out"),
                       ("court_branch", "south", 0.83, "out")],
        "hazards": [("vantry_signal_trunk", "conditional", (0.27, 0.5), 0.35, 5.5, 0.9)],
    },
    "D06_LAUNDRY_BOILER": {
        "unlock_slot": 3, "spaces": ["B1_LAUNDRY", "B1_BOILER_ROOM"], "along": "x", "join": "end_to_end",
        "derivation": "exact B1 laundry and boiler room joined end to end at the laundry's depth",
        "connectors": [("in", "south", 0.5, "in"), ("out", "west", 0.5, "out")],
        "hazards": [("laundry_mangle_belt", "triggered", (0.29, 0.5), 0.45, 5.5, 0.9),
                    ("boiler_relief_sweep", "rhythmic", (0.82, 0.5), 0.45, 6.0, 1.0)],
    },
    "D07_LIGHT_COURT_WALK": {
        "unlock_slot": 4, "spaces": ["F04_PUBLIC_CORE"], "along": "z", "join": "exact",
        "derivation": "exact F04 public core walked round the skylit light court that falls through it to F01",
        "connectors": [("in", "north", 0.5, "none"), ("out", "west", 0.5, "none")],
        "hazards": [("breathing_partition", "positional_rhythmic", (0.5, 0.5), 0.45, 5.5, 0.9)],
    },
    "D08_CASE_ECHO": {
        "unlock_slot": 5, "spaces": ["F02_A_MAIN"], "along": "x", "join": "exact",
        "derivation": "exact 2A main room; each case substitutes only its ruled grammar",
        "connectors": [("plant_in", "east", 0.7, "in"), ("court_in", "east", 0.22, "in"), ("out", "south", 0.5, "out")],
        "hazards": [],
    },
    "D09_RETURN_HALL": {
        "unlock_slot": 6, "spaces": ["F04_SOUTHWEST_HALL"], "along": "z", "join": "exact",
        "derivation": "exact F04 southwest hall, returning behind the long hall",
        "connectors": [("in", "north", 0.5, "in"), ("return", "west", 0.5, "out")],
        "hazards": [("fire_door_return", "triggered", (0.8, 0.5), 0.35, 4.6, 0.75)],
    },
}

TOPOLOGY = [
    ("E00", "D00_4B_THRESHOLD", "out", "D01_F04_LONG_HALL", "in", 1),
    ("E01_STAIR", "D01_F04_LONG_HALL", "stair_branch", "D02_DOGLEG_STAIR", "in", 2),
    ("E01_LIFT", "D01_F04_LONG_HALL", "lift_branch", "D03_LIFT_VOID", "in", 1),
    ("E02", "D02_DOGLEG_STAIR", "out", "D04_BATHROOM_PROCESSION", "stair_in", 2),
    ("E03", "D03_LIFT_VOID", "out", "D04_BATHROOM_PROCESSION", "lift_in", 1),
    ("E04", "D04_BATHROOM_PROCESSION", "out", "D05_SERVICE_RISER", "in", 1),
    ("E05_PLANT", "D05_SERVICE_RISER", "plant_branch", "D06_LAUNDRY_BOILER", "in", 3),
    ("E05_COURT", "D05_SERVICE_RISER", "court_branch", "D07_LIGHT_COURT_WALK", "in", 4),
    ("E06", "D06_LAUNDRY_BOILER", "out", "D08_CASE_ECHO", "plant_in", 5),
    ("E07", "D07_LIGHT_COURT_WALK", "out", "D08_CASE_ECHO", "court_in", 5),
    ("E08", "D08_CASE_ECHO", "out", "D09_RETURN_HALL", "in", 6),
    ("E09_FOLD", "D09_RETURN_HALL", "return", "D01_F04_LONG_HALL", "return", 6),
]


def lf_sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes().replace(b"\r\n", b"\n")).hexdigest()


def r3(v: float) -> float:
    return round(float(v) + 0.0, 3)


# Her Day, Folded (step 2): each release print's subject also lends the dream the rooms of their own day, in
# timetable order. A schedule place names a room of their flat or a shared room of the building; places outside the
# building (bodega, luncheonette, bar, the street) wait for Past the Mist. Each day room furnishes like the base
# module it most resembles.
UNIT_ROOM = {
    "bedroom": ("BED", "BED1", "ALCOVE"),
    "bathroom": ("BATH",),
    "kitchen": ("KITCHEN",),
    "studio": ("STUDIO", "MAIN"),
    "workshop": ("STUDIO", "MAIN"),
    "workbench": ("STUDIO", "MAIN"),
    "drafting": ("STUDIO", "MAIN"),
    "workroom": ("STUDIO", "MAIN"),
}
SHARED = {"mail_bank": "F01_MAIL_TELEPHONE", "lobby": "F01_LOBBY", "laundry": "B1_LAUNDRY", "roof": "ROOF_DECK_MIDDLE"}
FURNISH = {"MAIN": "D08_CASE_ECHO", "STUDIO": "D08_CASE_ECHO", "KITCHEN": "D08_CASE_ECHO", "BATH": "D04_BATHROOM_PROCESSION",
           "BED": "D00_4B_THRESHOLD", "BED1": "D00_4B_THRESHOLD", "ALCOVE": "D00_4B_THRESHOLD",
           "F01_MAIL_TELEPHONE": "D03_LIFT_VOID", "F01_LOBBY": "D03_LIFT_VOID", "B1_LAUNDRY": "D06_LAUNDRY_BOILER",
           "ROOF_DECK_MIDDLE": "D07_LIGHT_COURT_WALK", "LANDING": "D01_F04_LONG_HALL"}


def unit_prefix(unit: str) -> str:
    return "F0%s_%s_" % (unit[0], unit[1])


def day_space(place: str, unit: str, ids: set) -> tuple[str, str] | None:
    """The blockout space a schedule place stands for, and the base module it furnishes like."""
    if place in SHARED:
        return SHARED[place], FURNISH[SHARED[place]]
    if place == "corridor":
        space = "F0%s_LANDING" % unit[0]
        return (space, FURNISH["LANDING"]) if space in ids else None
    if place.startswith("visit:"):
        other = place.split(":", 1)[1][:2]
        space = unit_prefix(other) + "MAIN"
        return (space, FURNISH["MAIN"]) if space in ids else None
    if place == "unit" or place.startswith("unit:"):
        want = UNIT_ROOM.get(place.split(":", 1)[1] if ":" in place else "", ("MAIN",))
        for suffix in want:
            if unit_prefix(unit) + suffix in ids:
                return unit_prefix(unit) + suffix, FURNISH[suffix]
        return unit_prefix(unit) + "MAIN", FURNISH["MAIN"]
    return None


def day_modules(blockout: dict, schedules: dict, profiles: dict) -> dict:
    ids = {row["id"] for row in blockout["spaces"]}
    subjects = sorted({str(p.get("pursuit", {}).get("silhouette_resident", "")) for p in profiles["profiles"].values()} - {""})
    out = {}
    for resident in subjects:
        row = schedules["residents"][resident]
        stops = []
        for block in sorted(row["blocks"], key=lambda b: b["start_min"]):
            found = day_space(str(block["place"]), str(row["unit"]), ids)
            if found and (not stops or stops[-1][0] != found[0]):
                stops.append(found)
        if len(stops) > 1 and stops[0][0] == stops[-1][0]:
            stops.pop()  # the evening folds back onto the morning
        for order, (space, furnish) in enumerate(stops):
            level, rect = rect_of(blockout, space)
            length, depth = r3(rect[2] - rect[0]), r3(rect[3] - rect[1])
            out["DAY_%s_%02d" % (resident, order)] = {
                "id": "DAY_%s_%02d" % (resident, order),
                "unlock_slot": 1, "footprint_m": [length, depth],
                "source": {"derivation": "%s's day, stop %d: exact %s" % (resident, order, space),
                           "records": [{"kind": "room", "floor": level, "id": space, "rect_m": [r3(v) for v in rect]}]},
                "day_of": resident, "day_order": order, "furnish_as": furnish,
                "connectors": [
                    {"id": "entry", "side": "west", "offset_m": r3(depth * 0.5), "width_m": CONNECTOR_W, "height_m": CONNECTOR_H, "swing": "none"},
                    {"id": "out", "side": "east", "offset_m": r3(depth * 0.5), "width_m": CONNECTOR_W, "height_m": CONNECTOR_H, "swing": "none"}],
            }
    return out


def rect_of(blockout: dict, ident: str) -> tuple[str, list[float]]:
    for key in ("spaces", "platforms", "envelopes"):
        for row in blockout.get(key, []):
            if row.get("id") == ident:
                return str(row.get("level", "")), [float(v) for v in row["rect"]]
    raise SystemExit(f"blockout has no space, platform or envelope {ident}")


def dims(rect: list[float], along: str) -> tuple[float, float]:
    w, d = rect[2] - rect[0], rect[3] - rect[1]
    return (w, d) if along == "x" else (d, w)


def build(blockout: dict, schedules: dict | None = None, profiles: dict | None = None) -> dict:
    clear = float(blockout["dimensions"]["clear_height"])
    modules = {}
    for mid, spec in MODULES.items():
        records = []
        sizes = []
        for ident in spec["spaces"]:
            level, rect = rect_of(blockout, ident)
            records.append({"kind": "room", "floor": level, "id": ident, "rect_m": [r3(v) for v in rect]})
            sizes.append(dims(rect, spec["along"]))
        if spec["join"] == "exact":
            length, depth = sizes[0]
        elif spec["join"] == "end_to_end":
            length, depth = sum(s[0] for s in sizes), min(s[1] for s in sizes)
        elif spec["join"] == "remembered":
            length, depth = sizes[0][0] * float(spec["times"]), sizes[0][1]
        else:
            raise SystemExit(f"{mid}: unknown join {spec['join']}")
        length, depth = r3(length), r3(depth)
        side_len = {"north": length, "south": length, "east": depth, "west": depth}
        connectors = []
        for cid, side, frac, swing in spec["connectors"]:
            span = side_len[side]
            low, high = CONNECTOR_W * 0.5 + MARGIN, span - CONNECTOR_W * 0.5 - MARGIN
            offset = r3(min(high, max(low, span * frac)))
            if high < low:
                raise SystemExit(f"{mid}.{cid}: the {side} side ({span} m) cannot hold a {CONNECTOR_W} m door")
            row = {"id": cid, "side": side, "offset_m": offset, "width_m": CONNECTOR_W, "height_m": CONNECTOR_H,
                   "swing": swing}
            if swing in ("in", "out"):
                row["swing_depth_m"] = CONNECTOR_W
            connectors.append(row)
        for side in ("north", "south", "east", "west"):
            on = sorted(c["offset_m"] for c in connectors if c["side"] == side)
            for a, b in zip(on, on[1:]):
                if b - a < CONNECTOR_W + MARGIN:
                    raise SystemExit(f"{mid}: two {side} doors overlap ({a}, {b})")
        hazards = []
        for hid, kind, (fx, fz), clearance, tell, warning in spec["hazards"]:
            pos = [r3(length * fx), r3(depth * fz)]
            if not (clearance <= pos[0] <= length - clearance and clearance <= pos[1] <= depth - clearance):
                raise SystemExit(f"{mid}.{hid}: socket {pos} does not keep its {clearance} m clearance inside {length} x {depth}")
            hazards.append({"id": hid, "kind": kind, "position_m": pos, "clearance_radius_m": clearance,
                            "tell_radius_m": tell, "minimum_warning_s": warning})
        module = {"unlock_slot": spec["unlock_slot"], "footprint_m": [length, depth]}
        if "detail_repeat_range" in spec:
            module["detail_repeat_range"] = spec["detail_repeat_range"]
        module["source"] = {"derivation": spec["derivation"], "records": records}
        if "vertical_rise_m" in spec:
            module["vertical_rise_m"] = spec["vertical_rise_m"]
        module["connectors"] = connectors
        if hazards:
            module["hazard_sockets"] = hazards
        modules[mid] = module
    days = list(day_modules(blockout, schedules, profiles).values()) if schedules is not None and profiles is not None else []
    return {
        "meta": {
            "title": "Orison dream maze module catalog",
            "version": 3,
            "compatible_saved_revisions": [1, 2, 3],
            "units": "metres",
            "ruled": "2026-08-15; V2 rooms by ruling dream_v2_direction_20261116",
            "authority": "design/ORISON_MAZE_BRIEF.md",
            "source_layout": "game/data/orison_v2_blockout.json",
            "note": "Generated from the V2 blockout by tools/generate_dream_module_catalog.py; never edit by hand. "
                    "Run the generator after any blockout change (tools/tests/test_dream_module_catalog.py checks it).",
        },
        "constants": {
            "clear_ceiling_m": clear,
            "connector_width_m": CONNECTOR_W,
            "connector_height_m": CONNECTOR_H,
            "player_capsule_diameter_m": 0.66,
            "player_run_speed_mps": 4.6,
            "minimum_connector_margin_m": MARGIN,
            "minimum_warning_s": 0.5,
            "campaign_run_ceilings_s": [28, 38, 50, 62, 76, 90],
        },
        "modules": modules,
        "days": days,
        "topology": [{"id": e, "from": [a, ac], "to": [b, bc], "unlock_slot": s} for e, a, ac, b, bc, s in TOPOLOGY],
    }


def build_all() -> dict:
    return build(json.loads(BLOCKOUT.read_text(encoding="utf-8")), json.loads(SCHEDULES.read_text(encoding="utf-8")),
                 json.loads(PROFILES.read_text(encoding="utf-8")))


def render(doc: dict) -> str:
    return json.dumps(doc, indent=1) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    text = render(build_all())
    if args.check:
        current = CATALOG.read_text(encoding="utf-8").replace("\r\n", "\n") if CATALOG.exists() else ""
        if current != text:
            print("DREAM CATALOG STALE: run python tools/generate_dream_module_catalog.py")
            return 1
        print("DREAM CATALOG OK")
        return 0
    CATALOG.write_text(text, encoding="utf-8", newline="\n")
    print(f"wrote {CATALOG.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
