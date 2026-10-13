"""Preserve authored UV precision on the small charts proven to collapse on import.

This is a narrow source policy, not a global disabling of mesh compression.
Run --check in the gate board; run without it before a single batch import.
"""
import json
import sys
from pathlib import Path
from fix_runtime_texture_imports import ROOT, patch

ASSETS = (
    "props/front_restoration_details.glb", # Keep thin cornice and seat edge metric charts.
    "props/fire_repairs.glb", # Thin masonry/iron edge charts retain authored metric precision.
    "props/washer_controls.glb", # 96 fine thread/seal UV triangles collapse under import quantization.
    "props/stair_ironwork_service.glb", "props/boiler_body.glb",
    "props/bath_shower.glb", "props/bath_lavatory.glb",
    "props/bedding.glb", "props/roof_coping.glb",
    "building/v2_lift_drive.glb", "props/fire_service.glb",
    "props/roof_lighting_supply.glb",
    "props/active_household_radios.glb", "props/active_household_projector.glb", "props/media_ac_supply.glb", "props/media_battery_supply.glb",
)

def main():
    missing, wrong, fixed = [], [], []
    for asset in ASSETS:
        path = ROOT / "game/assets" / (asset + ".import")
        if not path.is_file(): missing.append(asset); continue
        if "meshes/force_disable_compression=true" in path.read_text(): continue
        wrong.append(asset)
        if "--check" not in sys.argv and patch(path, {"meshes/force_disable_compression":"true"}):
            fixed.append(asset)
    print(json.dumps({"scope":"v2_uv_precision","referenced":len(ASSETS),
                      "missing":missing,"wrong":wrong,"fixed":fixed}))
    return int(bool(missing or ("--check" in sys.argv and wrong)))

if __name__ == "__main__": raise SystemExit(main())
