# F02 sealed apartment reconstruction checkpoint

## Room profiles

### `F02_D_MAIN`

The main room is the undressed shell of apartment 2D, sealed off from the
landing since 1927. It retains floorboards, damaged plaster, one radiator,
switching and the original internal circulation, but no household furniture,
appliances, pictures or resident story. Its darkness and vacancy are authored
state, not missing dressing.

### `F02_D_BED`

The large rear room is an empty former bedroom inside the sealed shell. The
room retains its envelope, window, switch and internal leaf only. A bed,
wardrobe, nightstand or decorative substitute would contradict the unit state.

### `F02_D_OFFICE`

The small front room is an empty former office inside the sealed shell. Its
plain floor, walls, switch and internal leaf are the complete intended program;
the narrow dimensions are not an invitation to add compact furniture.

### `F02_D_BATH`

The bathroom retains the building's fixed sanitary fabric: basin, mirror,
toilet, shower, towel rail, sconce and ventilation register. These fixtures
belong to the apartment's original construction and do not imply occupation.
No toiletries, storage or resident dressing are present.

## Structured object and architecture verdicts

| Room | Exact target | Verdict | Expected position/property or manual proof | Rationale | Validation evidence |
|---|---|---|---|---|---|
| `F02_D_MAIN` | [manual] landing wall at stack D | KEEP | [visual] Continuous wainscoted wall has no apartment opening, leaf, plate or threshold. | The absence of an entrance is the canonical seal. | `00_solid_landing_wall.png`; generator branch for F02/D |
| `F02_D_MAIN` | `F02_D_RADIATOR_01`, `F02_D_RADIATOR_01_continuous_supply` | KEEP | [visual] Original radiator and connected riser remain at the exterior wall. | Fixed building service, not household dressing. | `01_empty_main_room.png`, `05_black_exterior_window.png` |
| `F02_D_MAIN` | `F02_DOOR_13`, `F02_DOOR_14`, `F02_DOOR_15` | KEEP | [visual] Internal leaves remain while no corridor leaf exists. | Sealing the apartment does not erase its internal plan. | `01_empty_main_room.png`; final packets |
| `F02_D_MAIN` | [manual] movable household contents | KEEP | [visual] No movable household contents are present. | The empty shell is the authored fiction. | `01_empty_main_room.png`; final packet |
| `F02_D_BED` | [manual] movable bedroom contents | KEEP | [visual] No bed, wardrobe, nightstand or art is present. | Nobody dresses a tomb. | `02_empty_bedroom.png`; final packet |
| `F02_D_OFFICE` | [manual] movable office contents | KEEP | [visual] No desk, chair, storage or art is present. | Preserve the sealed unit's undressed state. | `03_empty_office.png`; final packet |
| `F02_D_BATH` | `F02_2D_SINK_01`, `F02_2D_MIRROR_01`, `2D_wc`, `F02_2D_SHOWER_01` | KEEP | [visual] Original sanitary set remains complete. | Fixed 1927 fabric is compatible with a sealed apartment. | `04_retained_bath_fabric.png` |
| `F02_D_BATH` | `2D_trail`, `2D_towel`, `2D_LT_SCONCE`, `F02_D_BATH_VENT_REGISTER` | KEEP | [visual] Fixed towel support, sconce and ventilation remain; towel is inert building-era residue. | Retain the minimal wet-room fabric without adding occupation. | `04_retained_bath_fabric.png`; LightingAudit |

## Source and generated outputs

`art/data/gen_layout.py` independently enforces all three parts of the unit
state: `dress_unit()` returns before household dressing, the F02 stack-D
landing opening is omitted entirely, and exterior window glow is suppressed.
The existing generated layout already embodies those rules, so this checkpoint
requires no production geometry change and invents no replacement contents.

The companion decision manifest is intentionally empty: this pass verifies an
already-satisfied architectural state rather than landing object mutations.

## Validation and visual proof

- Four deterministic workbench packets confirm zero dressing in the bedroom
  and office, only fixed services in the bath, and no corridor entrance.
- `F02SealedApartmentShot`: PASS, six 1280x720 player-height frames under
  `art/renders/orison_room_reconstruction/f02_sealed_apartment_checkpoint_02/`.
- Serialized Godot import: exit 0, recorded in
  `art/renders/orison_room_reconstruction/f02_sealed_apartment_checkpoint_01/import.log`.
- `LightingAudit`: PASS.
- `WalkTest` FAST: PASS.

## Remaining ambiguities

- The interior is unreachable in ordinary play by design. Interior proof uses
  a test camera and opens only the three original internal leaves.
- The main-room route heuristic is not meaningful for a room with no player
  entrance; its bathroom overlap envelope also spans the broad room rectangle.
- The towel is retained as a small exact authored remnant. Its overlap with the
  towel rail is an intentional soft/fixed pairing, not a collision defect.
