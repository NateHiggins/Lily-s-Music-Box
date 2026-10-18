"""Preserve authored UV precision on the small charts proven to collapse on import.

This is a narrow source policy, not a global disabling of mesh compression.
Run --check in the gate board; run without it before a single batch import.
"""
import json
import sys
from pathlib import Path
from fix_runtime_texture_imports import ROOT, patch

ASSETS = (
    "props/arcade_clock.glb", # bench2: fine dial/hand charts deform by up to 64% under default import quantization.
    "props/arcade_lantern.glb", # Folded 2 mm roof skin and small closed seams retain metric charts.
    "building/orison_v2/passage/passage.gltf", # Shared long-range UV quantization stretches thin terrazzo border charts by 1.66%.
    "props/arcade_canopy.glb", "props/arcade_throat.glb", # Source-fitted glass and small mortar/bevel charts retain metric UVs.
    "props/construction_shed.glb", # Native small stock bevels and mirrored charts require full UV precision.
    "props/light_switch.glb", # Imported metre charts stretch 9.3% and their tangent derivatives fail under quantization.
    "props/annunciator_controls.glb", # Loaded bearing cap charts collapse even after periodic UV rebasing.
    "props/annunciator_dispatch.glb", # Loaded collar/cap UV metrics and tangent derivatives fail under default quantization.
    "props/radiator_service_stock.glb", # Blind pockets and worked screw/bevel charts collapse under UV quantization.
    "props/radiator_mechanisms.glb", "props/radiator_air_vent.glb",
    "props/radiator_wall_support.glb", "props/radiator_pitch_shims.glb", # Preserve fitted bores, cloth folds and shim charts.
    "props/front_lighting_trim.glb", # Preserve the small drilled wood passage charts.
    "props/front_lighting_supply.glb", "props/front_lighting_fixtures.glb", # Preserve small fitted bores and stock bevel charts.
    "props/heating_distribution.glb", # Imported small pipe charts collapsed in the native candidate check.
    "props/watch_stations.glb", # Involute tooth and shaft bevel charts collapse under import quantization.
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
