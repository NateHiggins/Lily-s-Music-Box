"""Per-space inventory census for the V2 environment dossier.

Reads the authoritative blockout layout (spaces, anchors, fixtures, doors,
openings, windows, slab openings) and the installed-data files under
game/data/orison_v2 (native variants, surface props, bath details, fittings,
accessories, radios, projectors, bookshelves, task lamps, heating, room
lighting, completion interiors, upper-floor programs) and writes census.json
keyed by space id. Support-relative records (a mug on a prep cabinet, a soap
dish on a sink) are attached to the space that owns their support anchor.

Read-only. Evidence class INERT: an inventory of what the data says is
installed, not a visual acceptance of anything.
"""
from pathlib import Path
import json, re, sys

ROOT = next(p for p in Path(__file__).resolve().parents if (p / "game/project.godot").is_file())
OUT = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).parent.parent / "census.json"
D = ROOT / "game/data/orison_v2"

RESIDENTS = {
    "1A": "Evelyn Marsh", "1D": "Teresa Vale", "2A": "Mina Vale", "2B": "Lena Ortiz",
    "2C": "Juno Kells", "3A": "Malcolm Reed", "3B": "Omar Bell", "3D": "Rhea Sato",
    "4A": "Peter Wren", "4B": "the player (night maintenance)", "4C": "Cam Ortiz and Noel Price",
    "4D": "Transient Guests", "5A": "Nadia Quell", "5B": "Cal Dwyer", "5C": "Iris Bell",
    "6A": "Sacha Reed", "6B": "Jonah Price", "6C": "Mae Kessler",
    "2D": "sealed (no resident)", "3C": "sealed (no resident)",
    "5D": "vacant, fire damaged", "6D": "landlord storage",
}

def load(name):
    return json.loads((D / name).read_text(encoding="utf-8"))

layout = json.loads((ROOT / "game/data/orison_v2_blockout.json").read_text(encoding="utf-8"))
levels = {l["id"]: float(l["y"]) for l in layout["levels"]}

def unit_of(space_id):
    m = re.match(r"F0(\d)_([A-D])_", space_id)
    return f"{m.group(1)}{m.group(2)}" if m else ""

def space_at(level, x, z):
    hits = []
    for s in layout["spaces"]:
        if s["level"] != level:
            continue
        r = s["rect"]
        if r[0] - 0.05 <= x <= r[2] + 0.05 and r[1] - 0.05 <= z <= r[3] + 0.05:
            hits.append(s["id"])
    return hits

spaces = {}
for s in layout["spaces"]:
    r = s["rect"]
    spaces[s["id"]] = {
        "id": s["id"], "level": s["level"], "class": s.get("class", ""), "purpose": s.get("purpose", ""),
        "rect": r, "size_m": [round(r[2] - r[0], 2), round(r[3] - r[1], 2)],
        "area_m2": round((r[2] - r[0]) * (r[3] - r[1]), 2),
        "exterior_sides": s.get("exterior_sides", []),
        "unit": unit_of(s["id"]), "resident": RESIDENTS.get(unit_of(s["id"]), ""),
        "anchors": [], "fixtures": [], "windows": [], "doors": [], "openings": [], "slab_openings": [],
        "placed": [], "room_lighting": [], "switches": [],
    }

# ---- native variants keyed by actor id
variants = {}
for name in ["domestic_objects", "domestic_seating", "domestic_tables", "domestic_storage",
             "household_wardrobes", "household_fridges", "medicine_cabinets", "fixed_lighting",
             "household_toasters", "prep_cabinets", "household_stoves", "household_radios"]:
    for inst in load(name + ".json").get("instances", []):
        variants[inst["id"]] = {"variant": inst.get("variant"), "source": name + ".json"}
for name in ["surface_stock", "reading_nook", "work_tables", "signal_terminal"]:
    for asm in load(name + ".json").get("assemblies", []):
        variants.setdefault(asm["id"], {"variant": "assembly", "source": name + ".json"})

anchor_space = {}
for a in layout["anchors"]:
    sid = a.get("space")
    if sid not in spaces:
        continue
    anchor_space[a["id"]] = sid
    row = {"id": a["id"], "kind": a.get("kind"), "position": a.get("position"), "yaw": a.get("yaw", 0)}
    if a["id"] in variants:
        row.update(variants[a["id"]])
    spaces[sid]["anchors"].append(row)

for f in layout["fixtures"]:
    p = f.get("position")
    if not p:
        continue
    for sid in space_at(f["level"], p[0], p[2]):
        anchor_space.setdefault(f["id"], sid)
        spaces[sid]["fixtures"].append({"id": f["id"], "class": f.get("class"), "size": f.get("size"), "position": p, "purpose": f.get("purpose", "")})

for w in layout["windows"]:
    if w.get("space") in spaces:
        spaces[w["space"]]["windows"].append({"id": w["id"], "center": w["center"], "axis": w["axis"], "sill": w.get("sill"), "height": w.get("height"), "width": w.get("width")})
for d in layout["doors"]:
    for sid in d["connects"]:
        if sid in spaces:
            spaces[sid]["doors"].append({"id": d["id"], "center": d["center"], "width": d.get("width"), "to": [x for x in d["connects"] if x != sid], "swing": d.get("swing"), "hinge": d.get("hinge")})
for o in layout["openings"]:
    for sid in o["connects"]:
        if sid in spaces:
            spaces[sid]["openings"].append({"id": o["id"], "center": o["center"], "width": o.get("width"), "to": [x for x in o["connects"] if x != sid]})
for so in layout.get("slab_openings", []):
    if so.get("space") in spaces:
        spaces[so["space"]]["slab_openings"].append({"id": so["id"], "surface": so.get("surface")})

# ---- support-relative installed records
units = {}
unplaced = []

def attach(rec_id, kind, source, unit, support=None, extra=None):
    row = {"id": rec_id, "kind": kind, "source": source, "unit": unit}
    if support:
        row["support"] = support
    if extra:
        row.update(extra)
    sid = anchor_space.get(support) if support else None
    if sid is None and support:
        # a support that is itself a placed record (e.g. nook_table) or an anchor
        # without a space: fall back to any anchor whose id ends with the support
        for key, value in anchor_space.items():
            if key.endswith(support):
                sid = value
                break
    if sid:
        spaces[sid]["placed"].append(row)
    else:
        row["note"] = "support not resolved to a space; listed under the unit"
        units.setdefault(unit or "?", {}).setdefault("unresolved_items", []).append(row)
        unplaced.append(row)

for r in load("domestic_surface_props.json")["props"]:
    attach(r["id"], r["kind"], "domestic_surface_props.json", r.get("unit", ""), r.get("support"))
for r in load("bath_details.json")["props"]:
    attach(r["id"], r["kind"], "bath_details.json", r.get("unit", ""), r.get("support"))
for r in load("household_accessories.json")["accessories"]:
    attach(r["id"], r["kind"], "household_accessories.json", r.get("unit", ""), r.get("support"))
for r in load("domestic_radios.json")["receivers"]:
    attach(r["id"], "domestic_radio", "domestic_radios.json", r.get("unit", ""), r.get("support"))
for r in load("domestic_projectors.json")["projectors"]:
    attach(r["id"], "projector", "domestic_projectors.json", r.get("unit", ""), r.get("support"), {"reel": r.get("reel")})
for r in load("task_lamp_installations.json")["lamps"]:
    attach(r["id"], "task_lamp:" + str(r.get("variant")), "task_lamp_installations.json", r.get("unit", ""), r.get("support"))
for r in load("bookshelves.json")["shelves"]:
    sid = anchor_space.get(r["id"])
    row = {"id": r["id"], "kind": "bookshelf:" + str(r.get("style")), "source": "bookshelves.json", "unit": r.get("unit"), "owner": r.get("owner"), "canonical_book": r.get("canonical_book")}
    (spaces[sid]["placed"] if sid else units.setdefault(r.get("unit", "?"), {}).setdefault("unresolved_items", [])).append(row)
for r in load("case_one_placement.json")["objects"]:
    sid = anchor_space.get(r.get("anchor"))
    row = {"id": r["id"], "kind": "case_one_object", "source": "case_one_placement.json", "anchor": r.get("anchor"), "offset": r.get("offset")}
    (spaces[sid]["placed"] if sid else units.setdefault("2A", {}).setdefault("unresolved_items", [])).append(row)
for r in load("heating.json")["network"]:
    units.setdefault(r.get("unit", "?"), {}).setdefault("heating", []).append({"id": r["id"], "kind": r["kind"], "riser": r.get("riser"), "sections": r.get("sections")})

programs = load("upper_floor_programs.json")
for p in programs["programs"]:
    units.setdefault(p["unit"], {})["program"] = {"resident": p.get("resident"), "disposition": p.get("disposition"), "entry": p.get("entry"), "rooms": p.get("rooms")}
for r in load("domestic_fittings.json")["fittings"]:
    units.setdefault(r.get("unit", "?"), {}).setdefault("fittings", []).append({"id": r["id"], "kind": r["kind"], "properties": r.get("properties")})
rl = load("room_lighting.json")
for r in rl["fixtures"]:
    if r["room"] in spaces:
        spaces[r["room"]]["room_lighting"].append({"id": r["id"], "kind": r["kind"], "properties": r.get("properties")})
for r in rl["switches"]:
    if r["room"] in spaces:
        spaces[r["room"]]["switches"].append(r["id"])
ci = load("completion_interiors.json")
for r in ci.get("furniture", []):
    units.setdefault(r.get("unit", "?"), {}).setdefault("completion_furniture", []).append({"id": r["id"], "template": r.get("template")})
for r in ci.get("fittings", []):
    units.setdefault(r.get("unit", "?"), {}).setdefault("completion_fittings", []).append({"id": r["id"], "kind": r.get("kind"), "properties": r.get("properties")})
for r in ci.get("doors", []):
    units.setdefault(r.get("unit", "?"), {}).setdefault("completion_doors", []).append({"id": r["id"], "kind": r.get("kind"), "leaf_state": r.get("leaf_state"), "swing_out": r.get("swing_out")})
for r in ci.get("lighting", {}).get("fixtures", []):
    if r.get("room") in spaces:
        spaces[r["room"]]["room_lighting"].append({"id": r["id"], "kind": r["kind"], "properties": r.get("properties"), "source": "completion_interiors.json"})
for r in ci.get("lighting", {}).get("switches", []):
    if r.get("room") in spaces:
        spaces[r["room"]]["switches"].append(r["id"])
for r in ci.get("ventilation", {}).get("registers", []):
    room = r.get("room") or r.get("space")
    if room in spaces:
        spaces[room]["placed"].append({"id": r.get("id"), "kind": "vent_register", "source": "completion_interiors.json", "stack": r.get("stack")})
for r in load("domestic_furniture.json")["furniture"]:
    u = r["id"].split("_")[1] if r["id"].startswith("F0") else r["id"].split("_")[0]
    units.setdefault(u, {}).setdefault("furniture_variants", []).append({"id": r["id"], "kind": r["kind"], "bounds": r.get("bounds")})
for u, name in RESIDENTS.items():
    units.setdefault(u, {})["resident"] = name
    units[u]["rooms"] = sorted(s for s in spaces if unit_of(s) == u)

census = {
    "evidence_class": "INERT",
    "schema": "orison.environment-dossier-census.v1",
    "layout_id": layout.get("layout_id"),
    "levels": levels,
    "spaces": spaces,
    "units": units,
    "unplaced": unplaced,
}
OUT.write_text(json.dumps(census, indent=1), encoding="utf-8")
print(json.dumps({"spaces": len(spaces), "anchors": sum(len(s["anchors"]) for s in spaces.values()), "placed": sum(len(s["placed"]) for s in spaces.values()), "unplaced": len(unplaced), "out": str(OUT)}))
