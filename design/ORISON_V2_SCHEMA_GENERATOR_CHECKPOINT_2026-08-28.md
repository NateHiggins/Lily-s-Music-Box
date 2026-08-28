# Orison v2 parallel schema/generator checkpoint — 2026-08-28

Status: **IMPLEMENTED, DEVELOPMENT-ONLY**  
Owner rulings: Option A compact H-plan and the central-public/northeast-service
core accepted 2026-08-28.

## Exact scope

This checkpoint establishes the reversible replacement path and the first
primitive gray-box data. It does not switch production launch, overwrite a current
floor, change a save owner, or claim a walkable/accepted building slice.

- `game/data/orison_v2_blockout.json` is the sole v2 spatial authority.
- `game/scripts/building/orison_v2_blockout.gd` validates that schema and derives
  primitive floors, ceilings, walls with door openings, complete open door
  leaves/frames/hinges, collision, stairs, continuous risers and named anchors.
- `game/scenes/building/orison_v2_blockout.tscn` is the explicit development scene.
- `game/tests/OrisonV2BlockoutTest.tscn` is the explicit test entrypoint.
- The accepted decision register is updated in the architectural checkpoint.

The existing `game/scenes/building/orison_root.tscn`, title-screen main scene,
`art/data/building_layout.json`, `game/data/building_layout.json`, current glTF/BIN
exports and existing evidence directories are not v2 outputs and were not changed
by this checkpoint.

## Decisions made

1. The v2 schema is semantic and metric. Spaces carry purpose/classification;
   doors carry connections, hinge and swing; anchors carry stable external ids;
   stairs and risers carry vertical intent.
2. Runtime gray-box generation is the initial deterministic geometry path. It is
   not a second decorative generator. The cutover plan is to extend this schema
   until it becomes the building authority, then freeze v1 as a migration fixture.
3. The production selector remains unchanged. Developers opt in by running the v2
   scene or its test directly.
4. Route doors are held open in the blockout so openings and standing envelopes
   can be inspected before interaction classes are migrated.
5. Required external identities resolve from the schema: `F01_DOOR_06`,
   `F02_DOOR_02`, `F04_DOOR_03`, `F02_A_MAIN_VANTRY_POINT`,
   `F04_B_MONITOR_01`, `F04_B_BED`, the three F01 service stations and the
   F01 dumbwaiter landing.

## Validation

- JSON parse/schema census: 31 programmed spaces, four first-route doors, sixteen
  named anchors, three represented route levels.
- Serialized Godot import: exit 0.
- Godot editor parse: exit 0.
- Focused `OrisonV2BlockoutTest`: PASS. It proves development-only selection,
  H-plan identity, schema validation, all required ids, complete open hinges,
  exact 2A/4B anchor transforms, continuous wet/service-lift geometry and
  byte-stability of the production layout during the run.
- `git diff --check`: PASS on checkpoint sources.

## What remains unproved

- The current space-shell algorithm duplicates some shared partition mass. It is
  acceptable for topology review but must consolidate shared walls before the
  wall-junction gate.
- Stairs are primitive straight proof runs, not accepted U-stairs with landings,
  headroom, rails or intermediate F03 geometry. The next vertical-core checkpoint
  must replace them from the same schema.
- Only the four route leaves exist. Internal apartment/service doors, exterior
  windows, lift cars/landings, radiator reservations and functional furniture
  envelopes remain to be authored.
- No player controller, navigation mesh, dynamic door interaction, case owner,
  save restore, semantic audio graph or production prop is attached to the v2
  root yet.
- No player-height capture, door-swing capture, walk proof, performance census or
  human route review has been claimed.

## Rollback and non-interference

Rollback is deletion/reversion of only the v2 JSON, builder, scenes/tests and this
checkpoint document. Production remains the only default path. Existing dirty and
untracked work is preserved. The import generated local cache/UID files only for
the new scripts; no foreign process was terminated and no hook was installed.

## Next bounded checkpoint

Build the F01 arrival shell as a real reviewable gray-box: consolidate its shared
walls; author all vestibule/lobby/watch/mail/parcel/core doors and windows; reserve
lift, radiator and apparatus envelopes; add a player/controller test harness; and
prove exact dimensions, closures, open/closed door clearances and the street-to-
core route. Do not add furnishing or decoration.

Commit SHA: recorded by the publishing commit and handoff.
