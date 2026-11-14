# Apartment projector category

Source integration against `55d2137`. No Godot launch or new visual/performance acceptance. V1 remains the default; V2 and S2J remain open.

## Composition

The three authored apartment media markers (`2A_tv`, `3B_tv`, `4B_tv`) now instantiate the existing projector model and reel renderer through a V2 wrapper. Each has a dedicated wood stand and operator stance. 2B has no authored television marker and receives no invented additional machine. The furniture manifest has 70 records; the three projectors are separately owned children of their stands. Six anchors are added.

The installed reels are existing `ch_01`, `ch_02` and `ch_03`, one per household. Their presence and hashes are recorded, without claiming decoded-image review. Shared ProjectorProp, TVProp, BroadcastDirector, film shader, media library and V1 project settings are unchanged. V2 uses local projector decoders and does not create the unused building station viewport or connect new resident/possession scheduling.

| Unit | Source throw | Image height | Placement |
| --- | ---: | ---: | --- |
| 2A | 2.10 m | 0.966 m | Stand faces the main room's south wall |
| 3B | 0.55 m | 0.500 m | Stand beside workbench, compact north-wall image |
| 4B | 1.70 m | 0.782 m | Stand faces the main room's south wall |

Omar's short throw keeps the radiator, repair stance, shelves and circulation free. All three body footprints rest on extracted visible stand tops. The existing stand hull extends 5 mm above the visible top; this coarse contact margin is not fine-contact physics proof.

## V2 behavior

The wrapper replaces the inherited television skin with a fitted 0.29 × 0.51 × 0.40 m body. Cast iron, brass, Bakelite, rubber and lens materials use the existing catalogue. Repeated material/roughness combinations share an instance within each projector. Lens and beam align with the model's actual barrel height. Beam range and angle fit the resolved image throw, including Omar's compact image.

Power retains the player/NPC/possession latch vocabulary. Repeated notifications while running preserve playback. Replacing, clearing or requesting an absent reel first stops the old decoder. Switching off disables both render buffers and the beam; exposure history clears once on the next run. Scene teardown stops and releases video and possession audio. Ordinary films remain silent, following the source projector behavior.

The image is admitted by a centre ray plus eight surrounding plane samples. A missed or oblique wall, or sampled aperture/obstacle, leaves the decoder and image off. This is a sampled check, not proof that every pixel has continuous wall backing. Geometry and projection are fixed after power-on; movable projector aiming is not implemented. The existing projected-film quad and a shadow-enabled spotlight are used; this does not establish voxel-projected film or alter the carried-lamp system.

## Verification

`work/v2_projectors_batch_01/build.py` passes source stand/body occupancy, visible support contact, 6,876 existing route samples, 183 operator approach samples, 17 door sweeps, 27 sampled projection rays (101 points each) and operator targeting estimates. Wall apertures are checked across each image rectangle.

`validate.py` passes preservation of all 67 earlier furniture records and protected shared owners, bounded finite material geometry, exact media-marker coverage, installed clip hashes and byte-identical regeneration. Existing seating, lighting, doors, walls, surface props, storage, household radios, cabinets and specialist-device source checks also pass. Independent GDScript syntax parsing passes; it is not Godot compilation.

The apartment batch engine test is prepared for household targeting and isolation, advancing video, overlapping latches, invalid reels, parked buffers, missed-wall and centre-only-hit negatives, reconstruction and active-decoder teardown. It has not run. Three independent loaded reels and six render buffers are a source resource count, not measured cost.

The current inventory accounts for all authored media markers in the four detailed units. Its remaining raw assembly omissions are the three legacy kitchen aggregates, whose replacement roles are reconciled in the kitchen-program packet. Detailed programs for twenty other source unit IDs, remaining building services/levels, persistence and engine/visual/default-cutover acceptance remain open.
