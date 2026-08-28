# F04 corridor and player-flat reconstruction checkpoint

## Room profiles

### `F04_CORRIDOR`

The fourth-floor corridor carries the player's daily route between lift/stair,
4B and the other apartments. Its primary station is the apartment threshold,
not freestanding furniture. Doors, wall switches, service meters, the chute and
direction signs must remain readable while the long lanes stay clear. Its visual
identity is dim, worn circulation; it deliberately contains no domestic
seating, resident decoration or storage spill.

### `F04_B_VESTIBULE`, `F04_B_BATH` and `F04_B_CLOSET`

The vestibule is the compact distributor from the corridor to the main room,
bath and closet. It exists to make those choices legible and therefore remains
unfurnished. The bath supplies the player's private sanitary station with
basin, toilet and shower; the closet supplies enclosed clothes and equipment
storage. Both are economical landlord rooms and deliberately receive no
speculative decoration.

### `F04_B_MAIN`, `F04_B_KITCHEN` and `F04_B_ALCOVE`

The player flat is a maintenance worker's compact home and decompression base.
The main room combines a couch/television rest station and a desk/Vantry work
station without turning either into a separate room. The galley kitchen supplies
all ordinary amenities in one dense north-wall run. The sleeping alcove is an
open, private bed bay rather than a falsely enclosed bedroom. Its identity is
second-hand, functional and exhausted; empty floor, matched luxury furniture
and invented biography remain absent.

## Object and architecture verdicts

| Room | Element | Verdict | Reason |
|---|---|---|---|
| Corridor | walls, dados, floor, ceiling and route lighting | KEEP | The open-door proof shows a continuous route into 4B; WalkTest and LightingAudit pass. The deliberately dim lane still reads by practical and lamp light. |
| Corridor | `F04_DOOR_03`, apartment signs and switches | KEEP | The 4B threshold is visible from the west lane and the open leaf clears the approach. |
| Corridor | service meters, mop/chute and directional signs | KEEP | Each is wall-backed service or navigation hardware and does not enter a door sweep. |
| Vestibule | enclosure and `F04_DOOR_03`, `F04_DOOR_10`, `F04_DOOR_11` | KEEP | Open entry/main leaves expose a direct sightline into the apartment; the bath branch remains distinct. |
| Vestibule | freestanding furnishing | KEEP ABSENT | At 2.75 square metres, its whole purpose is turning and door distribution. |
| Bath | basin, toilet, shower, mirror, towel rail and services | KEEP | Threshold proof shows complete fixtures, clear central floor and supported wet-zone relationships. |
| Closet | enclosure and `F04_DOOR_12` | KEEP | Dedicated enclosed storage remains reachable from the vestibule; no loose prop is needed to prove its use. |
| Main | couch, television, coffee table and main rug | KEEP | One coherent decompression station reads immediately from the entry. Supported tabletop dressing is retained. |
| Main | desk, chair, signal terminal, lamp and shelf | KEEP | The work station is complete and reachable, with the bathroom partition visibly clear behind it. |
| Main/bath | `4B_deskrug_rug` | REMOVE | The 1.15 m mat crossed the bathroom partition by 0.31 m and entered the shower footprint. The strip between the main rug and wall is narrower than the mat, so moving it would merely trade one overlap for another. The oak floor already supports the desk station. |
| Kitchen | sink/counter run, range, refrigerator, radiator, cupboards and small appliances | KEEP | The player retains all ordinary amenities. Worktop layers are intentional assembly joins, not competing furnishings. |
| Kitchen | `F04_DOOR_07` and `F04_B_FRIDGE_01` | KEEP | The workbench square reports a candidate, but the fridge center is about 1.42 m from the hinge against a 0.81 m leaf; player-height proof shows the opening clear. |
| Alcove | bed, mattress, blanket, pillow, headboard, posts and nightstand | KEEP | These intersections are the intended construction of one bed assembly. The entry view shows standing floor alongside it. |
| Main/alcove | reported 0.209 m and 0.283 m wall endpoint near-misses | KEEP | Player-height views show closed, thickness-offset corner junctions rather than navigable gaps. |
| Entire flat | speculative replacement dressing | KEEP ABSENT | Existing stations already explain work, rest, cooking, washing, storage and sleep. |

## Source and generated outputs

`art/data/gen_layout.py` removes only the impossible `4B_deskrug` call and
records why it must remain absent. The authoring and game layout JSON copies
were regenerated and are SHA-256-identical. Blender 5.2 rebuilt the canonical
master and exports; Git reports generated geometry changes only for the F04
GLTF/BIN pair plus `orison_master.blend`.

The room-layout workbench was also corrected in the preceding pushed commit
`2673502`: markers authored as `kind: door, cabinet: true` are cabinet leaves,
not room entrances. A regression fixture now protects that distinction.

## Validation and visual proof

- Generator: PASS, 1,539 assemblies, 102 architectural door leaves and 23
  radiators; all furnishing, wall, movement, service and life gates passed.
- Room-layout workbench: PASS, 35/35 self-tests.
- Corrected 4B packets: no boundary crossers after regeneration; only the
  measured refrigerator square-envelope candidate remains and is rejected by
  radial geometry and visual proof.
- Serialized Godot import: PASS.
- `LightingAudit`: PASS, 127 spaces, 11 intentionally ambient/dark.
- `WalkTest` FAST: PASS.
- `F04PlayerRouteShot`: PASS, seven 1280x720 player-height frames with corridor
  and main doors open, under
  `art/renders/orison_room_reconstruction/f04_player_route_checkpoint_03/`.
- Fresh static room census generated in the same evidence directory.

## Remaining ambiguities

- The corridor declaration is a large envelope around separated lanes and the
  atrium. Its 0.66 m computed minimum is not a literal width for every segment;
  production navigation remains the traversal authority until compound room
  polygons exist.
- Cabinet leaves use DoorProp at runtime but are furniture-scale contents. Any
  future audit must preserve the new `cabinet: true` distinction.
- This checkpoint closes the F04 corridor and 4B. Other F04 apartments and
  service rooms remain for resident-grouped and building-service passes.
