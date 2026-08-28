# F01 flats 1A and 1D reconstruction checkpoint

## Room profiles

### `F01_A_MAIN`, `F01_A_BATH` and `F01_A_BED`

Flat 1A is an occupied teacher's apartment whose main room combines modest
living, classwork, dining and cooking functions. The table is the primary work
and meal station; the north wall supplies a compact period kitchen. The bath is
a complete private wet room, and the bedroom is a deliberately plain sleep and
clothes-storage room. The flat should read as maintained, economical and lived
in without acquiring speculative hobbies, luxury fixtures or extra dressing.

### `F01_D_MAIN`, `F01_D_BATH` and `F01_D_OFFICE`

Flat 1D is Teresa Vale's lived-in apartment for a night nurse. Its main room is
the domestic living, dining and cooking station; its bath is private sanitary
support. The small office is a focused work nook rather than a second bedroom:
desk and chair are the primary station, while the shelf stores records and
books. Its identity is practical, tired and orderly. It deliberately receives
no invented medical equipment, patient records or narrative shrine.

`F01_D_BED` was closed separately by the 1D bedroom repair checkpoint; this
pass verifies the apartment around it without reopening that settled layout.

## Object and architecture verdicts

| Room | Element | Verdict | Reason |
|---|---|---|---|
| 1A main | walls, floor, ceiling, windows and `F01_DOOR_02` | KEEP | Threshold and reverse views show a complete enclosure and a readable route from entry to table and internal doors. |
| 1A main | table, chairs, living furniture and resident dressing | KEEP | The table remains usable from both long sides and the furnishing reads as one modest occupied room. |
| 1A main | sink run, stove and refrigerator | KEEP | All three appliances form one compact kitchen wall. The refrigerator is tight to the entry zone but remains outside the visible door path and leaves a clear passage. |
| 1A bath | basin, toilet, shower, mirror, towel and services | KEEP | Player-height proof shows complete fixtures and usable floor approach. The workbench towel finding is caused by the deliberately square door envelope, not contact with the actual leaf. |
| 1A bedroom | bed, wardrobe, windows and circulation | KEEP | The entry view shows an unobstructed central approach and no furnishing crossing the enclosure. |
| 1D main | walls, floor, ceiling, windows and apartment doors | KEEP | Entry proof shows a continuous enclosure and broad central circulation area. |
| 1D main | dining, living, kitchen and resident dressing | KEEP | Existing objects support the named domestic purpose without competing stations or unsupported additions. |
| 1D bath | basin, toilet, shower, mirror, towel and services | KEEP | The room is complete and traversable. As in 1A, the towel candidate belongs only to the conservative square sweep. |
| 1D office | desk and chair | KEEP | Exact hinge-distance review and both player-height views show the chair outside the leaf radius and the desk edge just beyond it; the conservative square is a near-miss warning, not a collision. |
| 1D office | shelf and stored frames/books | KEEP | The shelf is wall-backed and retains a narrow but usable standing area at the desk. Its foreground occlusion in the reverse proof is expected from the room's 2.2 by 1.9 metre extent. |
| Both flats | speculative replacement dressing | KEEP ABSENT | Every room already has a named station and readable use; no unearned prop was added to fill empty floor or wall area. |

## Source and generated outputs

No production source, layout JSON or generated building asset changed in this
checkpoint. The room-layout workbench was used read-only against the current
layout. A dedicated deterministic Godot capture suite and its eight-view proof
packet are the only implementation additions.

## Validation and visual proof

- Room-layout workbench self-tests: PASS, 34/34.
- Workbench room packets: no boundary crossers in `F01_A_MAIN` or
  `F01_D_MAIN`; the refrigerator, bathroom towels and 1D desk/chair findings
  were reviewed as conservative sweep candidates rather than automatic
  verdicts.
- `F01FlatsShot`: PASS, eight 1280x720 player-height frames with receipt under
  `art/renders/orison_room_reconstruction/f01_flats_checkpoint_03/`.
- Fresh static room census generated from the current game layout in the same
  evidence directory.
- The lamp is enabled in every proof frame; none contains the retired projected
  image cookie.
- `WalkTest` FAST: PASS.

## Remaining ambiguities

- Assembly footprints are intentionally worst-case. Chair tuck and objects
  close to a square door envelope must continue to be judged against the real
  radial leaf before any layout edit.
- Runtime-only dressing is not represented in the layout JSON. Visual proof is
  therefore authoritative for presence and support, while the packet remains
  authoritative for serialized positions.
- This closes the remaining 1A and 1D F01 rooms. Other floors remain independent
  room-by-room checkpoints.
