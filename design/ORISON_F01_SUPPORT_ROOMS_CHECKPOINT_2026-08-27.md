# F01 office, package and public-restroom checkpoint

## Room profiles

### `F01_OFFICE`

The superintendent/night-maintenance office exists to receive work, keep the
building's case residue and issue tools. The desk is the ordinary primary
station; the north workbench, pegboard and case wall are the maintenance
station. Staff use it for paperwork, inspection and tool custody. It should
not contain domestic furniture, resident-specific art or a second reception
function. Its identity is compact, workmanlike and accumulated rather than
decorative; condition is maintained and busy.

### `F01_PACKAGE`

The package room holds parcels between delivery and collection. Staff and
residents use two open shelf banks with a clear center aisle. It requires a
guarded service lamp, a reachable door and shelving; it deliberately contains
no desk, chair, decorative picture, duplicate mail bank or invented resident
story. Its identity is spare storage; condition is orderly.

### `F01_RESTROOM`

The public/service restroom supports lobby staff and residents without
entering an apartment. The basin/mirror is the primary station, with toilet
and compact shower as secondary fixtures. It requires water, drainage,
ventilation, wet-zone tile, a reachable switch and privacy door. It deliberately
contains no domestic decoration or redundant storage. Its condition is worn
but sanitary.

## Object and architecture verdicts

| Room | Element | Verdict | Reason |
|---|---|---|---|
| Office | walls, floor, ceiling, trim and `F01_DOOR_07` | KEEP | Final inside-threshold and reverse views show a closed enclosure, clear route and complete door approach. |
| Office | desk and chair | KEEP | Ordinary paperwork station with credible facing and standing approach. |
| Office | `office_magazine` surface print | KEEP | Fully supported on the desk; the historic diagonal desk-panel collision does not reproduce. |
| Office | maintenance workbench, pegboard, shelves and tool tiers | KEEP | Distinct repair/tool-custody station on the north wall; does not overlap the desk. |
| Office | case-wall sockets, tokens, status and interaction area | KEEP | Progress display has a named maintenance purpose and one consolidated reachable target. |
| Office | counterweighted pendant and door switch pair | KEEP | Required office service and reachable switching. |
| Package | walls, floor, ceiling, trim and `F01_DOOR_08` | KEEP | Clear central aisle and unobstructed shelf approach. |
| Package | `f01_pkg0`, `f01_pkg1` | KEEP | Two complete shelf banks establish the parcel-storage function; both have boards, frames and supported parcel boxes. |
| Package | guarded cage bulb and switch pair | KEEP | Appropriate service-room lighting. |
| Package | `common_notice_*` framed paper panel | REMOVE | Physically in the package room, directly behind `f01_pkg0`; unreadable, unreachable, blank and misowned. Shelving supplies the room's purpose without replacement decoration. |
| Restroom | enclosing walls, tiled wet zone, floor, ceiling and `F01_DOOR_09` | KEEP | Final entrance/work-position views show complete enclosure and fixture access. |
| Restroom | toilet | KEEP | Required sanitary fixture with clear front approach. |
| Restroom | basin, wall taps and drain | KEEP | Required wash station; tapwork is seated and reachable. |
| Restroom | medicine cabinet/mirror | KEEP | Supported above the basin with complete framed reflective face and usable opening convention. |
| Restroom | compact shower | KEEP | Historically plausible staff wash provision and bounded wet zone. |
| Restroom | towel rail and towel | KEEP | Reseated on the real wall face and clear of door/window reveals. |
| Restroom | converted gas-arm sconce, vent register and switch | KEEP | Required light/ventilation services; switch retains 1.267 m wet clearance. |

## Source and generated outputs

`art/data/gen_layout.py` retires only the obstructed `common_notice` frame
family. The two layout JSON copies were regenerated and synchronized. Blender
5.2 rebuilt the canonical master and exports; Git reports generated geometry
changes only for F01 GLTF/BIN plus `orison_master.blend`.

## Validation and evidence

- Generator: PASS, 1,533 assemblies, 102 door leaves, 23 radiators; all
  furnishing, wall, switch, ventilation and wet-clearance gates passed.
- Fresh static room census generated from the final game layout.
- Serialized Godot import: PASS.
- `LightingAudit`: PASS, 127 spaces, 11 intentionally ambient/dark.
- `WalkTest` FAST: PASS.
- `F01SupportRoomsShot`: PASS, six 1280×720 player-height frames and receipt
  under `art/renders/orison_room_reconstruction/f01_support_checkpoint_02/`.

## Remaining ambiguities

- The office's runtime maintenance headquarters is intentionally richer than
  the generator census can report. Future audits must continue counting it.
- The restroom's old “dotted diagonal seam” does not reproduce in the final
  entrance or basin view. It remains a historical candidate, not a source
  change, unless a repeatable camera or geometry measurement identifies it.
- Storage C, utility, hall/atrium, lift/stair approaches and occupied F01
  apartments remain open checkpoints.
