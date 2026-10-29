"""Preserve authored UV precision on the small charts proven to collapse on import.

This is a narrow source policy, not a global disabling of mesh compression.
Run --check in the gate board; run without it before a single batch import.
"""
import json
import sys
from pathlib import Path
from fix_runtime_texture_imports import ROOT, patch

ASSETS = (
    "props/service_companion_v2.glb", # mechanism_v1: small worked charts stretch 1-4% and tangent derivatives fail under default compression; original native charts pass.
    "props/lift_frame_mitres.glb", # loaded_v3: grooved landing head metre chart stretches 0.618%, beyond the unchanged 0.5% limit.
    "props/door_lining_mitres.glb", # lining loaded_v1: a complete frame's imported metre chart exceeds its edge by 51.23 micrometres, past the retained 50 micrometre bound.
    "props/bar_cafe_seating.glb", # loaded_v6: imported oak metre charts stretch 1.481% under default compression.
    "props/bar_resident_alcove.glb", # loaded_v6: small cloth/oak/brass charts stretch 0.586-6.293% under default compression.
    "props/door_casing_mitres.glb", # mitre_stock_v1: small native casing charts stretch1.177% under default compression, beyond the retained0.5% metric gate.
    "props/service_alley.glb", # Rebuilt bored boundary and worked coping now use authored metric charts, including millimetre arrises.
    "props/c_stove_stack.glb", # Same thin mortar, bored collar and worked arris charts as the fitted flue family; source precision preflight retained.
    "props/flue_breast_fitting.glb", # Same small annular anchor, slotted head and thin casting charts as the measured flue-wall family.
    "props/flue_wall_thimble.glb", # stock1: small anchor charts stretch 1.15% and 228 tangent derivatives fail under default compression.
    "props/nook_readable_books.glb", # Same thin binding charts and tangent precision as the readable native library.
    "props/readable_library.glb", # Thin printed ink, page gatherings and binding bevels retain authored metre charts.
    "props/fire_cabinet_skin.glb", # Retain fine wire, hinge-bore and folded sheet metre charts.
    "props/kitchen_plumbing.glb", # bench1: default import distorts small wheel/union charts and tangent derivatives.
    "props/kitchen_prep_stations.glb", # Preserve the worked-edge metre charts validated by the kitchen prep bench.
    "props/fire_capacity_candidate.glb", # stage22_capacity1: default import stretches small cloth charts21.2% and produces3593 bad tangent derivatives; texture mip policy is unchanged.
    "props/fire_floor_enamel.glb", # stage19_floor_uv1: default compression stretches thin coating edge charts by 0.508%, exceeding metric gate.
    "props/fire_nozzle_joint.glb", # nozzle_joint_stock1: default import stretches all three small thread/seat charts by up to33.6%.
    "props/fire_nozzle_detail.glb", # nozzle_detail_stock1: small fabricated charts lose scale and tangent derivatives under default compression.
    "props/fire_fold_stock.glb", # fold_stock1: default import collapses small annular UV derivatives on all seven templates.
    "props/fire_hose_rack.glb", # rack_stock1: default UV quantization stretches the small worked charts by up to72.8%, with collapsed derivatives.
    "props/fire_nozzle_hose.glb", # nozzle_stock2: default import stretches native hose/socket metre charts by up to2.74%.
    "props/fire_joint_stock.glb", # joint_stock1: loaded small thread charts stretch by up to32.6% under default compression.
    "props/house_switchboard.glb", # stock2: loaded jack UVs collapse and small stock metrics stretch under default compression.
    "props/city_horizon_near.glb", "props/city_horizon_far.glb", # The same thin closed pane/reveal metre charts as validated city stock.
    "props/city_ground_apron.glb", # source_bench1: default import stretches thin-edge metre charts by 1.69%.
    "props/city_frontage.glb", # imported_bench_01: default quantization stretches barricade stock charts by 6.07%, beyond the retained 0.5% metric gate.
    "props/city_elevations.glb", # Preserve the validated metric charts of retained cap bevels and recessed window stock.
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
