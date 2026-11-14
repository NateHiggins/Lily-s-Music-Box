# Four kitchen cabinets and two specialist devices

Source integration against `2973f02`; Godot was not launched. V2 remains incomplete, V1 remains the default, and S2J remains open.

## Installed batch

- Sliding preparation/storage cabinets in all four detailed kitchens: 2A, 2B, 3B and 4B. Each has a real open shelf cavity, seven frame collision pieces, a fixed right panel and a moving left panel. The moving panel forwards interaction to its cabinet and slides within the footprint; reversal and teardown cancel its tween. Materials use existing wood, plywood, trim, countertop and brass definitions.
- Mina's authored reel deck on the actual glass top of her coffee table. It remains fixed source geometry with no playback or recording behavior.
- Omar's authored valve radio on the equipment shelf, using the existing radio switch, programme and knob behavior. A V2 wrapper binds the knob material and retires programme/click streams and active motion with the world. Household receivers are separate and unchanged.

The furniture manifest now has 67 records. The batch adds ten anchors, 756 source triangles and 192 runtime cabinet panel/handle triangles, plus the existing native radio knob. These are source counts, not measured performance. The 61 prior furniture records and all existing fittings, surface props, household radios, materials, case placement, resident routine, shared media/audio owners and project default are preserved.

## Source verification

`work/v2_prep_cabinets_batch_01/validate.py` checks preservation against the base commit, finite material geometry inside declared bounds, and byte-identical regeneration. Both category builders pass. The cabinet builder checks 6,876 route samples, 231 operator-approach samples, 17 door sweeps and 101 slider poses. The device builder checks support against actual visible triangles and the specialist radio sightline from the equipment-shelf stance (target under one metre away).

The existing seating, lighting, doors, wall extensions, surface props, storage and household radio source checks pass with the additions. Independent GDScript parsing passes for the two new wrappers, furniture loader and expanded apartment test. This is syntax checking, not Godot compilation.

`work/v2_prep_cabinets_batch_01/kitchen_programs.json` joins installed fittings and furniture for all four kitchens. Each has a sink, stove, fridge, upper cupboard and dry prep cabinet. The three old monolithic kitchen meshes remain uninstalled; their roles have separate owners. The raw inventory continues to disclose these mesh omissions.

## Prepared engine checks and remaining work

`game/tests/orison_v2_apartment_batch_test.gd` now checks malformed mechanism data, real cabinet aperture rays in both states, full slide travel, local state isolation, rapid reversal, specialist receiver targeting/audio independence, reconstruction and active audio/tween teardown. It has not been run.

Device anchors derive from support placement during generation; each device is an independent adapter consumer, not a support child. Parent-support pairs are excluded only from the older coarse furniture-overlap test; the new builder checks visible top contact. The coffee collider's existing margin overlaps the deck base by 5 mm; the radio native collider extends into the shelf's coarse hull. Neither arrangement establishes fine collision contact or table knee clearance.

Physical passage/targeting, cabinet motion, audio cleanup, material/voxel appearance and performance require engine review. Cabinet state is local; no inventory, cooking or persistence mechanic was added. Remaining apartment media/projector integration, twenty other source unit room programs, building services and default-cutover acceptance remain open. Last historical engine evidence predates this furnishing batch.
