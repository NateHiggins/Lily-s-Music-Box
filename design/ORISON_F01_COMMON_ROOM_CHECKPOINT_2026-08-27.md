# F01 common-room reconstruction checkpoint

## Room profile

`F01_COMMON_B` is the Orison's plain residents' meeting and song room. Its
primary users are residents gathering around the long table for notices,
informal meetings, cards, rehearsal and communal singing. The table is the
primary station; the small east-wall basin supports tea and cleanup without
turning the room into a second apartment kitchen. The room is on the opening
floor and also distributes staff access to the office, package room and public
restroom, so its threshold and three service approaches must remain obvious.

Its visual identity is deliberately ordinary: repaired plaster, wood floor,
mismatched chairs, one settle and a single warm pendant. It deliberately has
no range, refrigerator, electronic amusement cabinet, performance stage or
resident-specific shrine. Its condition is maintained but worn.

## Object and architecture verdicts

| Element | Verdict | Reason |
|---|---|---|
| Floor, ceiling, perimeter/partition walls, wainscot and trim | KEEP | The final entrance and reverse views show continuous enclosing surfaces and complete junctions; the west bay is an authored recess, not a navigable wall gap. |
| East and north windows | KEEP | Both light the shared room and retain clear approaches. |
| `F01_DOOR_03` corridor entry | KEEP | Readable from inside the room; no room furniture appears in its conservative sweep audit. |
| `F01_DOOR_07` office service door | KEEP | Clear approach beside the table; no room furniture appears in its conservative sweep audit. |
| `F01_DOOR_08` package service door | KEEP | Clear approach at the table's south-east end; no room furniture appears in its conservative sweep audit. |
| `F01_DOOR_09` restroom service door | KEEP | Its north-west approach remains empty; no room furniture appears in its conservative sweep audit. |
| Door-paired switch plates | KEEP | Plates are reachable on the approach side and the bathroom pair remains outside the wet zone. |
| `F01_COMMON_B_LT_PENDANT_SHADE` | KEEP | One centered warm source identifies the shared table without inventing a second focal station. |
| `common_table` | KEEP | Primary meeting, card and songbook surface; reads immediately from the threshold. |
| `common_ch0..2`, `common_chn0..2` | KEEP | Six usable chairs face the table and retain standing routes at both ends. |
| `common_bench` | KEEP | Intentional mismatched overflow seating, backed against the south partition. |
| `common_k`, sink, mug, dish rack and linoleum/brass edge set | KEEP | Minimal tea/cleanup station; period-plausible and intentionally lacks domestic cooking appliances. |
| `common_cab` (`arcade_cab`) | REMOVE | The tall electronic-game silhouette contradicted the 1928 room, duplicated the Passage arcade family and consumed the only quiet bay. Historical proof shows it was the reported loose-door silhouette. |
| `common_stack1` | REMOVE | A featureless 550 mm square by 1.35 m metal prism did not model usable stacked chairs or any named activity; in production it read as a second black slab. Six chairs plus the settle already satisfy seating. |
| Cleared north-west bay | KEEP ABSENT | It preserves a turning/rest area between the restroom return and north window. No replacement prop is earned. |

The generator-named `common_notice_*` frame is physically at `y=2.745`, outside
this room and inside the office/package band. It was not claimed as common-room
dressing or moved speculatively; its ownership is deferred to those room
profiles.

## Source and generated outputs

Authoritative changes are confined to `art/data/gen_layout.py`: retire
`common_cab` and `common_stack1`. `art/data/building_layout.json` was regenerated
and copied byte-for-byte to `game/data/building_layout.json`. Blender 5.2 rebuilt
the canonical master and all floor exports; Git reports generated changes only
for `art/blender/orison_master.blend`, `game/assets/building/floor_01.gltf` and
its `.bin`. No other floor payload changed.

## Validation and visual proof

- Generator: PASS, 1,533 assemblies, 102 door leaves, 23 radiators; all layout,
  furnishing, wall, switch, ventilation and wet-clearance gates passed.
- Synchronized layouts: SHA-256-identical after regeneration.
- Static room census: no conservative sweep candidate names `F01_DOOR_03`,
  `F01_DOOR_07`, `F01_DOOR_08` or `F01_DOOR_09`; the census remains candidate
  detection rather than geometric proof.
- Godot import: PASS through the serialized editor lane; this was necessary
  because the initial review exposed a stale `floor_01` import cache.
- `WalkTest` FAST: PASS.
- `DoorCheckTest`: PASS, 116/116.
- `F01CommonRoomShot`: PASS, four 1280×720 player-height frames with a receipt:
  threshold-to-table, tea-station-to-table, table-to-exits and quiet west bay.
  Evidence is under
  `art/renders/orison_room_reconstruction/f01_common_b_checkpoint_03/`.

## Remaining ambiguities

- The room declaration is rectangular and excludes the small north-west leg
  behind the restroom even though the built room uses it. A future census may
  need compound room polygons; changing the schema is outside this checkpoint.
- The externally placed `common_notice_*` name is misleading. Its visible and
  functional owner must be decided with the office/package profiles.
- This closes only `F01_COMMON_B`. The lobby, service rooms, atrium/hall,
  apartments and the rest of the required F01 opening-route pass remain open.
