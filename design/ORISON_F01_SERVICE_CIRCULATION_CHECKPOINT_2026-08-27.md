# Orison F01 service and circulation checkpoint — 2026-08-27

## Scope and room verdicts

This checkpoint closes the remaining F01 building-service/circulation group at
player height: `F01_STORAGE_C`, `F01_UTILITY`, `F01_HALL`, and `F01_ATRIUM`.
The group owns tenant overflow storage, the chute/meter/mop service room, the
lift-to-stair approach, and the open switchback stair respectively.

- **Storage C — reconstruct one placeholder family.** Three 0.8 m square,
  featureless `trim` boxes claimed to be crates. They were replaced in the same
  three bays by six small, battened wooden crate assemblies. The shelves,
  windows, aisle and room lighting remain unchanged.
- **Utility — retain.** The full-height chute and attached hopper, west-wall
  meter bank, low mop fixture, caged pendant and clear centre aisle all resolve
  in the proof pair. The suspected pendant/chute collision does not reproduce.
- **Hall — retain.** `OUR QUEENS` is centred on a legal solid wall face and
  stays inside both wall edges. The lift, lobby threshold and atrium approach
  remain readable from one standing view.
- **Atrium — retain.** The apparent handrail stub resolves as the end of the
  continuous stair/landing rail system. The stair flights, newels, landing
  guard and fire-line station remain coherent and traversable.

No speculative dressing was added to the three retained rooms.

## Authoritative change and generated artifacts

`art/data/gen_layout.py` now authors two existing `crate` assemblies per storage
bay instead of one raw box. `art/data/building_layout.json` was regenerated and
copied to `game/data/building_layout.json`; Blender then rebuilt
`art/blender/orison_master.blend` and the F01 GLTF/BIN pair. The other floor
exports were byte-stable and are not part of this checkpoint.

## Evidence

`game/tests/F01ServiceCirculationShot.tscn` is a deterministic seven-view,
player-height windowed capture suite. Evidence lives in
`art/renders/orison_room_reconstruction/f01_service_circulation_checkpoint_03/`:

- `00_storage_south.png`, `01_storage_north.png`
- `02_utility_from_door.png`, `03_utility_reverse.png`
- `04_hall_lift_approach.png`, `05_hall_art_wall.png`
- `06_atrium_from_southwest.png`

The same directory includes the shot log, lighting log, FAST walk log, and
read-only spatial census.

## Validation

- Generator furnishing/layout validation: PASS.
- Godot import after GLTF/BIN rebuild: exit 0.
- `F01ServiceCirculationShot`: PASS, 7/7 captures.
- `LightingAudit`: PASS, 127 spaces; 11 intentionally ambient/dark.
- `WalkTest` FAST: PASS.
- `audit_orison_rooms.py`: completed; candidates retained as review prompts,
  not treated as automatic deletion orders.
