"""Emit the reviewed cage module instances and Label3D poses for Godot.

Run after build_resident_storage.py and review_resident_storage.py. The review
fits original stock to bays; its neutral context is never exported to Godot.
"""
import hashlib
import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
plan = json.loads((ROOT / "art/data/resident_storage/source_plan.json").read_text(encoding="utf-8"))
assert len(plan["stock_fit_review"]) == 16
assert all(row["inside_bay"] and row["floor_bearing"] for row in plan["stock_fit_review"])
data = {
    "schema_version": 1,
    "asset": plan["asset"],
    "asset_sha256": hashlib.sha256((ROOT / "game/assets/props/resident_storage.glb").read_bytes()).hexdigest(),
    "anchor": plan["anchor"],
    "members": [
        {"name": row["part"] + "__" + row["key"], "position": row["position"],
         "yaw": row["yaw"], "unit": row["unit"]}
        for row in plan["instances"]
    ],
    "labels": [
        {"unit": bay["unit"],
         "position": [(bay["left"] + bay["right"]) / 2 + .025, 2.12,
                      bay["front"] + .06 * bay["front_direction"]],
         "yaw": 0 if bay["front_direction"] == 1 else math.pi}
        for bay in plan["bays"]
    ],
}
assert len(data["labels"]) == 18
path = ROOT / "game/data/orison_v2/resident_storage.json"
path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8", newline="\n")
print("Exported reviewed native storage members and eighteen labels")
