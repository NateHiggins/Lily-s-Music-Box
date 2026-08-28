# F02 service circulation and west-storage family checkpoint

## Room profiles

### `F02_CORRIDOR`

The second-floor corridor is the shared residential route linking four flats,
the lift/stair hall, the utility room and the locked west plant store. Its
primary station is movement: both long runs, every apartment threshold and
both service approaches must remain legible and unobstructed. Meter/chute
details may be glimpsed at the utility end, but tenant furniture and decorative
clutter do not belong in this common path.

### `F02_HALL`

The hall is the compact lift-to-stair transfer landing. The lift approach,
floor sign and atrium opening are its only stations. It remains deliberately
spare so a player can read the change from enclosed corridor to open stair
without furniture competing with the route.

### `F02_ATRIUM`

The atrium is the open switchback-stair well and vertical orientation space.
Flights, landings, guards, the living service-tree detail and floor signage are
the identity. Its apparent occupied-area ratio is the stair-well void, not
furniture; nothing speculative is added to the circulation floor.

### `F02_UTILITY`

The utility room is the floor's chute and meter service station. The hopper,
meter bank, mop fixture, caged light and clear centre standing area are
required. It is workmanlike building fabric, not resident overflow storage.

### `F02_WSTOR`

The locked west store holds tenant overflow and unfitted building stock. Crate
stacks, covered suite furniture, shelf run, rolled rug and spare radiator
sections form distinct storage bays around a clear plant-key approach. The
room should feel densely used without blocking its only door or centre aisle.

### `F03_WSTOR`, `F04_WSTOR`, `F05_WSTOR`, `F06_WSTOR`

These four rooms repeat the same landlord overflow function and locked
plant-key access on their respective floors. Their deterministic crate stacks
vary, but the required station and exclusion are identical: stored material
belongs against the perimeter and must not occupy the service-leaf sweep.
This checkpoint verifies their shared authored placement exactly; their final
full-size visual review remains declared manual debt.

## Structured object and architecture verdicts

| Room | Exact target | Verdict | Expected position/property or manual proof | Rationale | Validation evidence |
|---|---|---|---|---|---|
| `F02_CORRIDOR` | `F02_DOOR_01`, `F02_DOOR_02`, `F02_DOOR_03`, `F02_DOOR_04`, `F02_DOOR_05` | KEEP | [visual] Door thresholds remain readable from both corridor directions. | Preserve every apartment and service connection. | `00_corridor_southbound.png`, `01_corridor_northbound.png` |
| `F02_CORRIDOR` | `age_lane_sF02`, `age_lane_wF02` | KEEP | [visual] Wear lanes remain surface treatment and do not read as obstacles. | Retain circulation history without invented clutter. | `00_corridor_southbound.png`, `01_corridor_northbound.png` |
| `F02_HALL` | `sign_F02_hall_face`, `sign_F02_hall_ground`, `sign_F02_hall_num` | KEEP | [visual] Complete sign stack remains wall-supported at the lift/stair transfer. | Required floor orientation. | `05_hall_lift_approach.png` |
| `F02_ATRIUM` | `tree_F02_trunk1`, `tree_F02_br0_stem`, `tree_F02_pad0_0` | KEEP | [visual] Representative trunk, branch and terminal pad remain integrated with the stair well. | Preserve the authored vertical service-tree identity. | `06_atrium_from_southwest.png` |
| `F02_UTILITY` | `F02_chute`, `F02_hopper`, `F02_meter0`, `F02_meter1`, `F02_meter2`, `F02_mop` | KEEP | [visual] Service fixtures remain perimeter-supported around clear standing floor. | Complete floor-service station. | `04_utility_from_door.png` |
| `F02_WSTOR` | `F02_DOOR_04` | KEEP | [visual] Fully open leaf retains an unobstructed threshold. | The plant key must expose a usable route, not a blocked store. | `02_wstor_open_leaf.png` |
| `F02_WSTOR` | `F02_wstor_shelf`, `F02_wstor_sheet_a`, `F02_wstor_sheet_b`, `F02_wstor_sections` | KEEP | [visual] Four distinct perimeter storage groups retain a clear centre aisle. | Dense but navigable landlord overflow. | `03_wstor_interior.png` |

## Source and generated outputs

`art/data/gen_layout.py` moves the shared west-storage rug-roll family 0.95 m
west of its previous position. The regenerated authoring and game layout JSON
copies are SHA-256-identical. Blender 5.2 rebuilt the canonical master and the
F02-F06 GLTF/BIN pairs; B1, F01 and roof exports remained byte-stable.

Workbench comparison isolates exactly `F02_wstor_roll` through
`F06_wstor_roll`, each moving from `[-5.92, 2.07]` to `[-6.87, 2.07]`.
The final F02 packet reports zero `F02_DOOR_04` sweep candidates, no boundary
crossers and a 1.703 m apparent minimum route. Vertically stacked crate
footprints and layered sign/service-tree parts are intentional composition,
not deletion candidates.

The five exact MOVE targets are machine-authored in
`design/ORISON_F02_SERVICE_CIRCULATION_CHECKPOINT_2026-08-27.decisions.json`.

## Validation and visual proof

- Generator: PASS, 1,539 assemblies, 102 architectural door leaves and 23 radiators.
- Integrated spatial-tool suite: PASS, 160/160.
- `F02ServiceCirculationShot`: PASS, seven 1280x720 player-height frames under `art/renders/orison_room_reconstruction/f02_service_circulation_checkpoint_01/`.
- Serialized Godot import: exit 0, recorded in `art/renders/orison_room_reconstruction/f02_service_circulation_checkpoint_01/import.log`.
- `LightingAudit`: PASS, recorded in `art/renders/orison_room_reconstruction/f02_service_circulation_checkpoint_01/lighting_audit.log`.
- `WalkTest` FAST: PASS, recorded in `art/renders/orison_room_reconstruction/f02_service_circulation_checkpoint_01/walk_fast.log`.
- Checkpoint linter: Markdown 7/7 READY; MOVE manifest 5/5 READY; zero needs-attention or malformed decisions.
- Checkpoint reconciler: 117 SATISFIED, 0 OPEN, 0 CONTRADICTED, 55 explicitly UNVERIFIABLE legacy/manual rows, 0 MALFORMED and 0 conflicts.
- Evidence verifier: 9 citations, 5 recorded passes, 2 present artifacts, 2 symbolic assertions; zero missing, recorded failures or metadata mismatches.
- Progress ledger: 35 of 127 rooms checkpointed, 30 structured; F02 advances from 3 to 8 profiled/checkpointed/structured rooms, and the four sibling west stores gain exact structured placement while retaining declared visual debt.

## Remaining ambiguities

- The workbench's 0.18-0.26 m wall endpoint near-misses occur where nested
  corridor/room envelopes meet thicker perimeter construction. The captures
  show continuous finished junctions; they are retained as audit prompts.
- The four F03-F06 west stores share exact authored geometry with the verified
  F02 door relationship, but their lighting, composition and room-specific
  crate variation still require full-size visual review.
- The open-leaf capture is deterministic proof staging; normal access remains
  locked behind the plant key and its runtime custody tests.
