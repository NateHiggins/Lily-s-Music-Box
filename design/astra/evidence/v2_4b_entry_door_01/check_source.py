"""Source checks only. Does not import, invoke or emulate Godot physics."""
import ast
import hashlib
import json
import math
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[4]
BASE = "b7ef79b"
ADAPTER = "game/scripts/building/orison_v2_domestic_doors.gd"


def baseline(name):
    return subprocess.check_output(["git", "show", f"{BASE}:{name}"], cwd=ROOT)


def specs(text):
    table = re.search(r"const SPECS := (\{.*?\n\})", text, re.S).group(1)
    return ast.literal_eval(re.sub(r"\b(false|true)\b",
                                  lambda m: m.group(0).title(), table))


current = specs((ROOT / ADAPTER).read_text(encoding="utf-8"))
previous = specs(baseline(ADAPTER).decode("utf-8"))
assert set(current) - set(previous) == {"F04_DOOR_03"}
assert all(current[key] == value for key, value in previous.items())
assert current["F04_DOOR_03"] == {
    "kind": "apartment_entry", "swing_out": False, "unit": "4B"}

protected = ["game/data/orison_v2_blockout.json", "game/scripts/props/door_prop.gd"]
hashes = {}
for name in protected:
    raw = (ROOT / name).read_bytes().replace(b"\r\n", b"\n")
    assert raw == baseline(name).replace(b"\r\n", b"\n"), name
    hashes[name] = hashlib.sha256(raw).hexdigest()

layout = json.loads((ROOT / protected[0]).read_text(encoding="utf-8"))
door = next(r for r in layout["doors"] if r["id"] == "F04_DOOR_03")
vestibule = next(r for r in layout["spaces"] if r["id"] == "F04_B_VESTIBULE")
assert door["hinge"] == "left" and door["width"] == .91 and door["height"] == 2.13
assert door["connects"] == ["F04_WEST_HALL", "F04_B_VESTIBULE"]
# Sample the production collider's four horizontal corners through 100 degrees,
# including DoorProp's 26 mm setback. This estimates bounds, not collisions.
samples = []
for degrees in range(101):
    angle = math.radians(degrees)
    for x in [.01, door["width"] - .01]:
        for z in [.026 - .022, .026 + .022]:
            local_x = -door["width"] / 2 + x * math.cos(angle) + z * math.sin(angle)
            local_z = -.026 - x * math.sin(angle) + z * math.cos(angle)
            yaw = door["yaw"]
            samples.append((door["center"][0] + local_x * math.cos(yaw) + local_z * math.sin(yaw),
                            door["center"][1] - local_x * math.sin(yaw) + local_z * math.cos(yaw)))
rect = vestibule["rect"]
assert all(rect[0] + .07 < x < rect[2] + .023
           and rect[1] + .07 < z < rect[3] - .07 for x, z in samples)
result = {
    "status": "SOURCE_PASS_RUNTIME_PENDING", "base": BASE,
    "prior_door_specs_preserved": len(previous),
    "new_entry": door, "protected_lf_sha256": hashes,
    "sampled_collider_sweep_xz_bounds": [min(p[0] for p in samples), min(p[1] for p in samples),
                                        max(p[0] for p in samples), max(p[1] for p in samples)],
    "sweep_estimate_stays_in_vestibule_or_threshold_thickness": True,
    "godot": "NOT_RUN", "physical_route": "PREPARED_NOT_RUN"
}
Path(__file__).with_name("source_checks.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
print(json.dumps(result, indent=2))
