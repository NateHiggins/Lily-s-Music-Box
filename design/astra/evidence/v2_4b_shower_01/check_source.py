"""Repeatable source-only checks; never starts Godot or Blender."""
import hashlib
import json
import math
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[4]
BASE = "2d3377e"


def read(name):
    return json.loads((ROOT / name).read_text(encoding="utf-8"))


def old(name):
    return json.loads(subprocess.check_output(["git", "show", f"{BASE}:{name}"], cwd=ROOT))


layout_path = "game/data/orison_v2_blockout.json"
fittings_path = "game/data/orison_v2/domestic_fittings.json"
layout, before = read(layout_path), old(layout_path)
added_ids = {"F04_4B_SHOWER_01", "F04_4B_SHOWER_01_STANCE"}
assert [r for r in layout["anchors"] if r["id"] not in added_ids] == before["anchors"]
assert {r["id"] for r in layout["anchors"]} - {r["id"] for r in before["anchors"]} == added_ids
assert all(layout[k] == v for k, v in before.items() if k != "anchors")
fittings, previous = read(fittings_path)["fittings"], old(fittings_path)["fittings"]
assert [r for r in fittings if r["id"] != "F04_4B_SHOWER_01"] == previous
assert len(fittings) == len(previous) + 1
water = [r["id"] for r in fittings if r["kind"] in ("sink", "shower")]
assert len(water) == len(set(water)) == 6
anchors = {r["id"]: r for r in layout["anchors"]}
shower = anchors["F04_4B_SHOWER_01"]
stance = anchors["F04_4B_SHOWER_01_STANCE"]
assert shower["yaw"] == 0 and shower["position"] == [-8.45, 0, 5.58]
assert shower["space"] == stance["space"] == "F04_B_BATH"

# Parse the actual V2 collider data, not a second copy of its dimensions.
source = (ROOT / "game/scripts/building/orison_v2_shower.gd").read_text(encoding="utf-8")
pieces = [(list(map(float, a.split(","))), list(map(float, b.split(","))))
          for a, b in re.findall(r"\[Vector3\(([^)]+)\), Vector3\(([^)]+)\)\]", source)]
assert len(pieces) == 10
assert all(all(math.isfinite(n) and n > 0 for n in size) for size, _ in pieces)
lo = [min(pos[i] - size[i] / 2 for size, pos in pieces) for i in range(3)]
hi = [max(pos[i] + size[i] / 2 for size, pos in pieces) for i in range(3)]
assert hi[1] < .3
footprint = [shower["position"][0] + lo[0], shower["position"][2] + lo[2],
             shower["position"][0] + hi[0], shower["position"][2] + hi[2]]
bath = next(r["rect"] for r in layout["spaces"] if r["id"] == "F04_B_BATH")
assert footprint[0] > bath[0] + .07 and footprint[2] < bath[2] - .07
assert footprint[1] > bath[1] + .07 and footprint[3] < bath[3] - .07

def distance_to_receptor(x, z):
    return math.hypot(max(footprint[0] - x, 0, x - footprint[2]),
                      max(footprint[1] - z, 0, z - footprint[3]))

radius = .33  # PlayerController.BODY_RADIUS
for identity in ["4B_wc_STANCE", "F04_4B_SINK_STANCE", "F04_4B_SHOWER_01_STANCE"]:
    x, _, z = anchors[identity]["position"]
    assert distance_to_receptor(x, z) > radius + .05
path_margin = min(distance_to_receptor(-9.05 + i * 1.15 / 100, 4.75) - radius for i in range(101))
assert path_margin > .05
# Source estimate for the player's two valve targets, including eye height.
eye = [stance["position"][0], 1.41, stance["position"][2]]
valve_distances = [math.dist(eye, [-8.45 + x, .98, 5.58 + .275]) for x in [-.095, .095]]
assert max(valve_distances) < 2.1

protected = {}
for name in ["game/scripts/props/tap_prop.gd", "game/scripts/player/player_controller.gd",
             "game/scripts/props/boiler_tend.gd"]:
    path = ROOT / name
    raw = path.read_bytes().replace(b"\r\n", b"\n")
    prior = subprocess.check_output(["git", "show", f"{BASE}:{name}"], cwd=ROOT).replace(b"\r\n", b"\n")
    assert raw == prior
    protected[name] = hashlib.sha256(raw).hexdigest()

result = {"status": "SOURCE_PASS_RUNTIME_PENDING", "base": BASE,
          "previous_fittings_preserved": len(previous), "water_fittings": water,
          "receptor_pieces_per_shower": len(pieces), "receptor_building_xz_bounds": footprint,
          "bath_entry_route_capsule_margin_estimate_m": path_margin,
          "valve_reach_estimates_m": valve_distances, "protected_lf_sha256": protected,
          "godot": "NOT_RUN", "controls_and_routes": "PREPARED_NOT_RUN"}
Path(__file__).with_name("source_checks.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
print(json.dumps(result, indent=2))
