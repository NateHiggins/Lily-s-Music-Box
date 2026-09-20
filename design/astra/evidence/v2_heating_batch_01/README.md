# Six-apartment heating integration

Status: SOURCE_INTEGRATED_RUNTIME_PENDING. Base: `7c9a536`. No Godot was launched.

Four new radiators complete the installed heating category for 2A, 2B, 3A, 3B, 4A and 4B. All six use the existing cast-section apparatus, material bindings, handwheel and vent mechanisms. Their case and supply-pipe collision bodies leave the physical controls exposed. Eight new semantic/stance anchors bring the layout to 383 anchors. Furniture, fittings, lighting, resident data and all prior layout records remain unchanged.

The existing HeatBalance now receives all 23 authored radiator demands, copied from the canonical building source. BoilerTend publishes the same real boiler output to that model and the existing hot-water curve. Seventeen emitters retain logical demand without a physical V2 installation; they are not declared spatially migrated. This avoids creating a six-radiator steam budget while the rest of the building is unfinished. Six live radiator mechanisms bind their valve, vent and pitch states to the same model. Household casting tint and temperature observations read its result. Source radiator identities and riser assignments remain stable; underfloor branch geometry is not newly modeled.

2B retains the existing ten-section production apparatus and its complete Open Shift situation, including its maintenance inventory. The legacy marker says nine sections; this pass explicitly preserves the installed ten-section apparatus. The five other homes use a V2 wrapper with listening, temperature, vent inspection, endpoint valve operation and the existing vent-maintenance activity. They cannot acquire or consume 2B's packing or expose its union-repair actions. This also removes the previous 3B connection to that packing custodian. The shared RadiatorProp, HeatBalance, BoilerTend, BoilerProp and inventory classes remain unchanged.

Installed acoustic endpoints follow the six migrated poses through the existing scoped adapter and restore on teardown. Household balance listeners disconnect, active handwheel tweens retire through the shared owner, and an open household service panel is queued for removal with its radiator.

## Validation

Run `python design/astra/work/v2_heating_batch_01/validate.py` from the repository root. The matching work directory contains the generator, source receipt, source validation, category outputs and independent syntax record.

- All 375 prior anchors and other existing layout records are preserved. The full demand roster exactly matches the canonical source; protected domain owners, material/furniture/fitting/radio/lighting data and project configuration are unchanged.
- Placement checks include existing furniture, fixture estimates, separate case tables, surface props, solid service risers, 166 old/new stances, 138 local approach samples and 404 sampled valve sightline points. All 25 domestic/service leaf sweeps and 6,864 source route samples pass. Six analytic handwheel rays reach their targets before their own case/pipe hulls.
- Deliberate sofa overlap, service-riser overlap and an oversized collision hull are rejected. Regeneration is byte-identical. All twelve affected source category checks pass, including film projection paths. The first proposed 2A/4B south-wall locations obstructed projectors; the final placements preserve those throws and the existing walking routes.
- Five modified/new GDScript files pass independent parsing. This is not Godot compilation or type checking.

The prepared apartment engine test covers the full heat budget, redistribution to an unbuilt household when an installed valve closes, zero supplied heat with the boiler's water factor at zero, the shared hot-water response, restored supply, all six physical handwheel rays, model bindings, case/pipe collision, acoustic restoration, refusal of incomplete or mismatched manifests, repair-packing isolation, and teardown while handwheel tweens are active. These tests have not run. Existing runtime evidence predates this pass.

## Limits and next work

No actual heat simulation, physical traversal/interaction, listening, materials/voxel shadows, acoustic propagation, panel/tween lifetime, performance or visual acceptance is claimed. The household heat tint follows the model; 2B retains its existing situation-driven visual behavior. Logical offstage demand currently retains authored defaults and has no newly migrated persistent valve state. Full heating geometry, persistence and remaining room programs are unfinished.

Next category pass: functional bathroom/kitchen accessories across developed homes, then broader residential/building/service programs and persistence. Sixteen residential labels still lack detailed V2 programs; 1B and 1C retain shared/service roles. V2 is incomplete, V1 remains default and S2J remains open.
