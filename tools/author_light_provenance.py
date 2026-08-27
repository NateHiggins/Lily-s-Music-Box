"""Author stable characterful lighting cards for every practical source."""
from pathlib import Path
import hashlib
import json
import random

ROOT = Path(__file__).resolve().parents[1]
LAYOUT = json.loads((ROOT / "game/data/building_layout.json").read_text())
LIGHT_MAP = json.loads((ROOT / "game/data/fixture_light_map.json").read_text())
OUTS = (ROOT / "game/data/light_provenance.json",
        ROOT / "art/data/light_provenance.json")

# Installation years are deterministic flavour, not authored Orison history.
# Keep this classification in the generator payload: adding it to only the
# runtime mirror lets the next legitimate regeneration silently erase the
# release audit's authority boundary.
FIELD_SEMANTICS = {
    "fixtures.*.provenance": {
        "classification": "generated_flavor",
        "authored": False,
        "generator": "tools/author_light_provenance.py",
        "canonical_authority": None,
        "temporal_status": (
            "UNRULED: installation years are generated across 1928-1989 "
            "and are not building history"
        ),
        "player_surface": "debug_overlay_only",
    }
}

RESIDENT = {
    "1A": ("Evelyn Marsh", "carefully maintained teacher's-room warmth"),
    "1D": ("Teresa Vale", "low, sleep-protecting pools with hospital-green memory"),
    "2A": ("Mina Vale", "even captioning light with nervous peripheral flutter"),
    "2B": ("Lena Ortiz", "bright mending-table practicality"),
    "2C": ("Juno Kells", "amplifier amber and bruised violet shadow"),
    "3A": ("Malcolm Reed", "plant-room warmth fading toward the windows"),
    "3B": ("Omar Bell", "repair-bench clarity and oily reflected warmth"),
    "3D": ("Rhea Sato", "a single rehearsal pool surrounded by listening dark"),
    "4A": ("Peter Wren", "too much reassurance from too many steady bulbs"),
    "4B": ("the maintenance operator", "late-shift task light and monitor spill"),
    "4C": ("Cam Ortiz and Noel Price", "delivery-night practicality beside museum restraint"),
    "4D": ("Transient Guests", "a landlord bulb nobody feels entitled to replace"),
    "5A": ("Nadia Quell", "code-compliant task light with humane warm edges"),
    "5B": ("Cal Dwyer", "radio-dial darkness and one unreliable amber filament"),
    "5C": ("Iris Bell", "high-rendering studio light seeking impossible color"),
    "6A": ("Sacha Reed", "monitor-level pools that preserve the room beyond frame"),
    "6B": ("Jonah Price", "one writing lamp and the darkness where words should be"),
    "6C": ("Mae Kessler", "archive-safe low light with exact pools"),
}

FLOOR = {
    "B1": (2350, .82, "wartime utility wiring, repeatedly patched"),
    "F01": (2450, 1.05, "the building's public face, polished but voltage-tired"),
    "F02": (2750, .98, "domestic tungsten with a faint nursing-station pallor"),
    "F03": (2850, 1.02, "workrooms, plants, and practical hands"),
    "F04": (2350, .90, "the nocturnal working floor"),
    "F05": (3000, .94, "performance, radio, and painter's color judgment"),
    "F06": (2550, .86, "quiet top-floor pools contaminated by moonlight"),
    "ROOF": (2100, .76, "weathered exterior circuits under blue night"),
}

MAKER = {
    "flush_dome": ("Queens Electric Porcelain Works", "opal schoolhouse dome"),
    "pendant_shade": ("Ridgewood Fixture & Wire", "counterweighted pendant"),
    "sconce_globe": ("Astoria Gas & Electric", "converted gas-arm sconce"),
    "kitchen_linear": ("Bright-Day Products", "early fluorescent batten"),
    "cage_bulb": ("Consolidated Industrial", "guarded service lamp"),
    "chandelier": ("Orison & Sons Contract Furnishings", "five-arm lobby electrolier"),
    "eye_pendant": ("unknown custom fabricator", "light-court inspection pendant"),
    "street_lamp": ("New York Municipal Electric", "sodium cobra-head retrofit"),
    "lamp": ("Tensor Housewares", "weighted task lamp"),
    "ceiling_light": ("Queens Electric Porcelain Works", "shallow opal ceiling bowl"),
}

QUIRK = {
    "flush_dome": ["mica in the pull socket ticks as it warms", "the dome brightens a breath after the switch", "one ballast harmonic produces a nearly subliminal pulse"],
    "pendant_shade": ["its cloth cord twists a few degrees between visits", "the shade holds a warm thumbprint no cleaner removes", "the filament dips when the elevator relay closes"],
    "sconce_globe": ["the repaired arm transmits footsteps as a tiny tremor", "its globe is mismatched and throws one greener edge", "the switch contact sometimes remembers the previous brightness"],
    "kitchen_linear": ["the starter blinks twice before committing", "a tired tube drifts slightly cool at one end", "the ballast hum and light pulse disagree by half a beat"],
    "cage_bulb": ["the guard throws bars that seem one rung too numerous", "coal dust dims the upper hemisphere", "the filament trembles when a riser knocks"],
    "chandelier": ["only four arms share the same color temperature", "the central stem breathes with old mains voltage", "one crystal answers movement after the room is still"],
    "eye_pendant": ["its reflection appears to blink before the lamp does", "the long cable carries boiler vibration upward", "its pool subtly favors whichever landing is occupied"],
    "street_lamp": ["a failed photocell grants brief, ugly intervals of normal light", "the stained cover splits the sodium pool into two colors", "rain makes the ballast restart without warning"],
    "lamp": ["the knuckle settles a millimeter lower each night", "its Bakelite switch clicks before the filament responds", "the shade makes a private pool and refuses the rest of the room"],
    "ceiling_light": ["the opal bowl retains one dead moth silhouette", "the pull inside the socket chatters at low voltage", "its warm-up drift resembles slow breathing"],
}


def seed_for(value):
    return int.from_bytes(hashlib.sha256(value.encode()).digest()[:8], "little")


def room_for(floor, pos):
    candidates = []
    x, y = pos[:2]
    for room in floor["rooms"]:
        x0, y0, x1, y1 = room["rect"]
        if x0 - .08 <= x <= x1 + .08 and y0 - .08 <= y <= y1 + .08:
            candidates.append(((x1-x0)*(y1-y0), room))
    return min(candidates)[1] if candidates else {}


def main():
    records = {f["id"]: f for f in LAYOUT["floors"]}
    fixtures = list(LIGHT_MAP["fixtures"])
    for floor in LAYOUT["floors"]:
        for marker in floor["markers"]:
            if marker["kind"] not in ("lamp", "ceiling_light"):
                continue
            room = room_for(floor, marker["pos"])
            fixtures.append({"id": marker["id"], "floor": floor["id"],
                "kind": marker["kind"], "room": room.get("id", "UNASSIGNED"),
                "room_kind": room.get("kind", "task"), "position": marker["pos"],
                "range": 4.5 if marker["kind"] == "lamp" else 6.5,
                "energy": 1.0, "navigation": False, "standby": 0.0})
    result = {}
    for item in fixtures:
        fid, kind = item["floor"], item["kind"]
        rng = random.Random(seed_for(item["id"]))
        floor_temp, floor_gain, floor_feel = FLOOR[fid]
        room = room_for(records[fid], item["position"])
        unit = room.get("unit", "")
        resident, personal = RESIDENT.get(unit, ("the superintendent", floor_feel))
        maker, model = MAKER[kind]
        year = rng.randint(1928, 1989)
        serial = f"{rng.choice('ABCDEFGH')}{rng.randint(1000,9999)}"
        quirk = rng.choice(QUIRK[kind])
        room_kind = item.get("room_kind", "unknown")
        nav = bool(item.get("navigation", False))
        temperature = floor_temp + rng.randint(-180, 180)
        gain = floor_gain * rng.uniform(.90, 1.10)
        if nav:
            gain *= .83
        practical_gain = {
            "bathroom": 1.32, "kitchen": 1.16, "utility": 1.42,
            "laundry": 1.55, "boiler": 1.62, "electrical": 1.58,
            "storage": 1.28, "storage_cages": 1.48, "coal": 1.45,
            "closet": 1.22, "common": 1.12,
        }.get(room_kind, 1.0)
        gain *= practical_gain
        if fid == "B1" and room_kind != "corridor":
            gain *= 1.28
        gain = min(2.0, gain)
        if kind in ("kitchen_linear", "ceiling_light"):
            temperature += 350
        flicker = rng.uniform(.006, .026)
        if kind in ("cage_bulb", "street_lamp"):
            flicker = rng.uniform(.035, .105)
        if kind == "chandelier":
            flicker = .11
        rate = rng.uniform(.42, 2.2)
        result[item["id"]] = {
            "display": f"{item['room'].replace('_', ' ').title()} — {model}",
            "floor": fid, "room": item["room"], "room_kind": room_kind,
            "resident": resident,
            "provenance": f"{maker}, installed {year}, service card {serial}. {personal.capitalize()}.",
            "quirk": quirk,
            "tuning": {
                "energy_multiplier": round(gain, 3),
                "temperature": int(max(1800, min(6500, temperature))),
                "range": max(item.get("range", 5.0),
                             5.2 if room_kind in ("bathroom", "utility",
                                "laundry", "boiler", "electrical",
                                "storage_cages", "coal") else 1.5),
                "attenuation": round(rng.uniform(1.25, 1.75) if nav else rng.uniform(1.75, 2.45), 3),
                "source_size": round(rng.uniform(.08, .19), 3),
                "shadow_opacity": round(rng.uniform(.86, 1.0), 3),
                "flicker_depth": round(flicker, 4),
                "flicker_rate": round(rate, 3),
            }
        }
    payload = {
        "fixture_count": len(result),
        "field_semantics": FIELD_SEMANTICS,
        "fixtures": result,
    }
    for path in OUTS:
        path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
    print(f"authored {len(result)} unique light provenance cards")


if __name__ == "__main__":
    main()
