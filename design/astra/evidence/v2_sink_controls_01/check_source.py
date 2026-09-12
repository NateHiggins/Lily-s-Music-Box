"""Source preservation and control-ray estimates; does not run an engine."""
import hashlib
import json
import math
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[4]
BASE = "4dae293"


def previous(name):
    return subprocess.check_output(["git", "show", f"{BASE}:{name}"], cwd=ROOT).replace(b"\r\n", b"\n")


protected = {}
for name in ["game/data/orison_v2_blockout.json", "game/data/orison_v2/domestic_fittings.json",
             "game/scripts/props/tap_prop.gd", "game/scripts/player/player_controller.gd",
             "game/scripts/props/boiler_tend.gd", "game/scripts/building/orison_v2_water_valve.gd"]:
    raw = (ROOT / name).read_bytes().replace(b"\r\n", b"\n")
    assert raw == previous(name), name
    protected[name] = hashlib.sha256(raw).hexdigest()

shower_path = "game/scripts/building/orison_v2_shower.gd"
old_shower = previous(shower_path).decode("utf-8")
new_shower = (ROOT / shower_path).read_text(encoding="utf-8")
pieces = r"\[Vector3\([^)]+\), Vector3\([^)]+\)\]"
assert re.findall(pieces, old_shower) == re.findall(pieces, new_shower)
factory = (ROOT / "game/scripts/building/orison_v2_water_controls.gd").read_text(encoding="utf-8")
for line in ["control.position = tap._handles[index].position + Vector3(0, 0, -.06)",
             "shape.radius = .07", "control.hot = index == 0"]:
    assert line in old_shower and line in factory

layout = json.loads((ROOT / "game/data/orison_v2_blockout.json").read_text(encoding="utf-8"))
anchors = {a["id"]: a for a in layout["anchors"]}
fittings = json.loads((ROOT / "game/data/orison_v2/domestic_fittings.json").read_text(encoding="utf-8"))["fittings"]
results = []
for fitting in fittings:
    if fitting["kind"] != "sink": continue
    identity = fitting["id"]
    anchor = anchors[identity]
    stance = anchors.get(identity + "_STANCE", anchors.get(identity.replace("_01", "_STANCE")))
    assert stance is not None
    delta = [stance["position"][i] - anchor["position"][i] for i in range(3)]
    yaw = anchor["yaw"]
    eye = [delta[0] * math.cos(yaw) - delta[2] * math.sin(yaw), 1.41,
           delta[0] * math.sin(yaw) + delta[2] * math.cos(yaw)]
    if fitting["properties"]["fixture"] == "bath_sink":
        rim, panel_front, valve_y, separation = .815, .205 - .045 / 2, .91, .18
    else:
        compact = fitting["properties"].get("compact_kitchen", False)
        top, depth = (.905, .38) if compact else (.90, .46)
        rim, panel_front, valve_y, separation = top + .02, depth / 2 - .004 - .035 / 2, top + .11, .19
    cap_z = panel_front - .0135 - .06
    distances = []
    for sign in [-1, 1]:
        target = [sign * separation / 2, valve_y, cap_z]
        # The complete eye-to-cap segment is above the lower hull and in
        # front of the splash panel. This says nothing about other scene props.
        assert min(eye[1], target[1]) > rim
        assert max(eye[2], target[2]) < panel_front
        distances.append(math.dist(eye, target))
    assert max(distances) < 2.1
    assert separation > 2 * .07
    results.append({"id": identity, "cap_reach_estimates_m": distances,
                    "lower_hull_top_m": rim, "control_line_clears_sink_hulls": True})
assert len(results) == 4
result = {"status": "SOURCE_PASS_RUNTIME_PENDING", "base": BASE, "sinks": results,
          "shower_pieces_and_valve_placement_preserved": True,
          "protected_lf_sha256": protected, "godot": "NOT_RUN"}
Path(__file__).with_name("source_checks.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
print(json.dumps(result, indent=2))
