# 3A / 4A apartment expansion

Status: SOURCE_INTEGRATED_RUNTIME_PENDING. No Godot was launched. Base: `1aa22cc`.

Malcolm Reed's 3A and Peter Wren's 4A now have six-room domestic programs each, connected to the existing F03/F04 public cores. The pair adds 22 furniture records, ten fittings (including six water consumers), twelve ceiling fixtures with twelve physical switches, eight production doors, nine openings, eight windows and 91 anchors. Four supporting circulation spaces are also added. Source totals are 92 furniture, 30 fittings, 38 detailed apartment rooms/circuits, 78 layout spaces, 35 doors, 37 openings, 30 windows and 370 anchors. Existing radios, specialist devices and projectors retain their original household coverage.

Each apartment receives its authored toilet, bed, wardrobe, nightstand, meal table and two chairs, plus sink stand, preparation cabinet, upper cupboard and work table. Household bed, wood and fitting profiles come from the original building source. The work tables designate Malcolm's propagation work and Peter's correspondence; plants and papers are not yet installed. Six-unit composition, water supply, circuit isolation, cupboard/material, cabinet interaction, door operation and teardown checks are prepared in the existing apartment batch engine test.

The inventory distinguishes 22 residential source labels from shared/service labels 1B and 1C. Six residential programs are now developed in source; sixteen remain. Vacant, sealed and storage dispositions are preserved. This is not a claim of 22 occupied households or completed resident migration. See `../../work/v2_apartment_expansion_01/current_inventory.json` for the current inventory; older batch inventories retain their original scope and terminology.

## Geometry repairs

The solid west wet-service riser was absent from earlier furnishing collision estimates. It intersected the 2A shower and toilet edge, concealed the bathroom switch and constrained the 4B WC stance. The riser stays fixed. The new 3A program and existing 2A now place the toilet and shower west of its collider, mount the switch on its west face and provide clear operating stances. Their bathroom openings widen from 0.81 to 0.91 metres; the prepared 2A bathroom route clears the moved toilet and fully opened leaf. The 4B WC stance also moves clear of the riser.

F04 service circulation is split around the public crossing, with the northern segment widened to follow the existing F03 bypass pattern. F03's new west approach cuts a named opening in the actual public-core wall. Stairs, lifts and risers remain fixed. The lighting source check now accepts a physically supported solid-riser face, and the earlier wall batch counts only the wall intervals it owns.

## Validation

`../../work/v2_apartment_expansion_01/validate.py` passes preservation checks, byte-identical regeneration and four rejection controls: overlapping room, severed entry, riser obstruction and invalid material. The builder checks unique references, room separation, new room boundary coverage, graph connections to public cores, three-dimensional obstacle estimates including solid risers, 0.38-metre stance clearance, bounded material geometry, and eight new leaves at 201 samples through their full 100-degree opening.

All eleven affected category source checks pass: apartment furnishings, seating, lighting, doors, wall extensions, surface props, storage/tables/boards, household radios, preparation cabinets, specialist devices and projectors. The existing door check covers 1,647 resident-route and 3,743 player-route samples. The storage check covers 6,864 source route samples and 25 domestic/service door sweeps. These are scoped source estimates, not physical route playback for the new apartments. Their working receipts were refreshed; historical runtime evidence was not rewritten. Independent GDScript syntax parsing passes for both modified production scripts and both modified engine tests.

## Remaining work

Godot compilation, actual passage and targeting, water/light behavior, materials and voxel shadows, resident navigation, sound, save/reconstruction, performance and visual acceptance remain unverified. Source geometry uses conservative envelopes and does not prove hardware or jamb clearance. New homes still need personal dressing, domestic receivers and heating, followed by the remaining residential programs and building/service migration. V2 is incomplete, V1 remains default and S2J stays open.
