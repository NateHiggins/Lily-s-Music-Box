# F02 case-one apartment reconstruction checkpoint

## Room profiles

### `F02_A_MAIN`

Mina Vale's main room is an occupied captioner's living and work room. The
caption desk, ordered filing bank, pinboard and Vantry point are the primary
station; the sofa/television and dining table provide ordinary rest and meals,
while the compact kitchen supplies complete domestic amenities. This is also
the first case's discovery and conversation room, so the route from the entry
to the chirping Vantry point must remain immediate. Its identity is squared,
quiet and correction-oriented. It deliberately contains no generic hobby
clutter, redundant work desk or speculative case symbolism.

### `F02_A_BED`

The bedroom provides private sleep and closed clothes storage away from the
case station. The bed is primary; wardrobe and nightstand are supporting
stations. Its identity is sparse and ordered. It deliberately does not repeat
the caption office, add a second screen or turn unused floor into storage.

### `F02_A_BATH`

The bathroom supplies Mina's private basin, toilet and shower in a compact wet
room. Fixtures, ventilation, reachable switching and privacy are required. It
is worn but sanitary and deliberately contains no decorative fiction beyond
the ordinary towel and mirror.

## Structured object and architecture verdicts

| Room | Exact target | Verdict | Expected position/property or manual proof | Rationale | Validation evidence |
|---|---|---|---|---|---|
| `F02_A_MAIN` | `F02_DOOR_02` | KEEP | [visual] Fully open leaf retains a corridor-to-kitchen/main-room sightline. | Case-one arrival must be immediate and readable. | `00_corridor_to_2a.png`, `01_entry_kitchen_fridge.png` |
| `F02_A_MAIN` | `F02_2A_FRIDGE_01` | KEEP | Remains at `[-6.79, -0.77]`, yaw `180`; [manual] center is about 1.98 m from the `F02_DOOR_02` hinge against a 0.91 m leaf. | The workbench square is conservative; the real radial leaf cannot reach it. | Final workbench packet and `01_entry_kitchen_fridge.png` |
| `F02_A_MAIN` | `F02_2A_STOVE_01`, `F02_2A_KITCHEN_SINK_01`, `F02_2A_TOASTER_01`, `2A_k`, `2A_k_kdishrack`, `2A_k_kmug` | KEEP | [visual] One supported kitchen run with clear standing floor. | Complete ordinary amenities without a second cooking station. | `01_entry_kitchen_fridge.png` |
| `F02_A_MAIN` | `2A_din_t`, `2A_din_dc1`, `2A_din_dc2` | KEEP | [visual] Two chairs retain usable approaches around the round table. | Meal station is compact and distinct from work. | `02_main_room_from_entry.png` |
| `F02_A_MAIN` | `2A_sofa`, `2A_tv`, `2A_cof`, `2A_mug` | KEEP | [visual] Sofa faces the television across the supported coffee surface. | Ordinary decompression station; does not compete with the caption desk. | `02_main_room_from_entry.png` |
| `F02_A_MAIN` | `2A_desk`, `2A_desk_dkch`, `2A_filing`, `F02_A_MONITOR_01`, `F02_A_LAMP_01`, `2A_pinboard`, `2A_phones`, `2A_papers` | KEEP | [visual] Caption equipment remains supported, reachable and squared to the desk. | Primary resident/case station. | `04_caption_workstation.png` |
| `F02_A_MAIN` | `F02_A_MAIN_VANTRY_POINT` | KEEP | Runtime scope: `game/scripts/building/vantry_network.gd`; [visual] point remains reachable from the entry and work station. | This is the enabled case's sound-led discovery target. | `04_caption_workstation.png`; WalkTest interaction contracts |
| `F02_A_MAIN` | `2A_lart_art`, `2A_lart_artf`, `2A_lart_artf2`, `2A_lart_artfl`, `2A_lart_artfr` | KEEP | [visual] Image face remains present inside its complete frame. | Resident wall art is paired rather than an empty frame. | `02_main_room_from_entry.png` |
| `F02_A_BED` | `F02_DOOR_07` | KEEP | [visual] Fully open leaf clears the relocated filing bank and bedroom approach. | Required privacy leaf and case-room egress. | `03_bedroom_door_shelf.png` |
| `F02_A_BED` | `2A_bed0`, `2A_bed0_ns`, `2A_w0_wardrobe` | KEEP | [visual] Clear central approach from threshold to bed and wardrobe. | Complete minimum sleep and clothes-storage stations. | `05_bedroom_from_threshold.png` |
| `F02_A_BED` | `2A_bart0_art`, `2A_bart0_artf`, `2A_bart0_artf2`, `2A_bart0_artfl`, `2A_bart0_artfr` | KEEP | [visual] Image face and frame parts remain paired and wall-supported. | Intentional art, not an empty receiver. | `05_bedroom_from_threshold.png` |
| `F02_A_BATH` | `F02_DOOR_08` | KEEP | [visual] Open leaf retains a clear fixture approach. | Privacy and usable wet-room entry. | `06_bath_from_threshold.png` |
| `F02_A_BATH` | `F02_2A_SINK_01`, `2A_wc`, `F02_2A_SHOWER_01`, `F02_2A_MIRROR_01` | KEEP | [visual] Complete basin, toilet, shower and mirror with central standing floor. | Required sanitary fixtures. | `06_bath_from_threshold.png` |
| `F02_A_BATH` | `2A_trail`, `2A_towel` | KEEP | [manual] Wall-mounted rail/towel remains outside the radial `F02_DOOR_08` leaf despite the square-envelope warning. | Ordinary sanitary support without freestanding clutter. | Final packet and `06_bath_from_threshold.png` |
| `F02_A_BATH` | `F02_A_BATH_VENT_REGISTER`, `2A_LT_SCONCE` | KEEP | [visual] Ventilation and local light remain wall/ceiling supported. | Wet-room building services. | `06_bath_from_threshold.png`; LightingAudit |

## Source and generated outputs

`art/data/gen_layout.py` shifts only Mina's three-shelf filing bank 0.30 m
west. The repeated `2A_WORK_ARCHIVE` surface anchors follow their owning shelf
surfaces automatically. Authoring and game layout JSON copies were regenerated
and are SHA-256-identical. Blender 5.2 rebuilt the canonical master and exports;
Git reports generated geometry changes only for the F02 GLTF/BIN pair plus
`orison_master.blend`.

Workbench `--compare` reports exactly `2A_shelf0`, `2A_shelf1`, `2A_shelf2`
and the generated archive anchor positions moving 0.30 m; no other room object
delta appears.

The three MOVE verdicts and exact final positions are machine-authored in
`design/ORISON_F02_CASE_ONE_ROOMS_CHECKPOINT_2026-08-27.decisions.json`. This
companion manifest is part of this checkpoint; it avoids pretending that MOVE
targets embedded in Markdown prose are reconciler-readable.

## Validation and visual proof

- Generator: PASS, 1,539 assemblies, 102 architectural door leaves and 23
  radiators; all furnishing, movement, wall, service and life gates passed.
- Integrated spatial-tool suite: PASS, 126/126.
- Room-layout workbench packet: final `F02_A_MAIN` packet removes the
  `F02_DOOR_07`/`2A_shelf2` sweep candidate and retains no boundary crossers.
- `F02CaseOneRoomsShot`: PASS, seven 1280x720 player-height frames with the
  apartment, bedroom and bathroom leaves open under
  `art/renders/orison_room_reconstruction/f02_case_one_checkpoint_02/`.
- Serialized Godot import: PASS.
- Checkpoint linter: Markdown 15/15 READY; companion MOVE manifest 3/3 READY;
  zero needs-attention or malformed decisions.
- Checkpoint reconciler: 88 SATISFIED, 0 OPEN, 0 CONTRADICTED, 55 explicitly
  UNVERIFIABLE legacy/manual rows, 0 MALFORMED and 0 conflicts.
- Progress ledger: F02 advances from 0 to 3 checkpointed/structured rooms;
  building READY decisions advance 27 to 45 while needs-attention remains 51.
- `ChirpReachableLiveTest`: PASS, 25/25; the Vantry point remains reachable and
  repeated looks/prompts preserve case state.
- `LightingAudit`: PASS, 127 spaces, 11 intentionally ambient/dark.
- `WalkTest` FAST: PASS.
- Fresh static room census generated in the final evidence directory.

## Remaining ambiguities

- `2A_WORK_ARCHIVE` is intentionally repeated once per shelf surface in layout
  sockets. The move is verified through its owning shelf IDs because the
  repeated socket ID is not a unique reconciliation key.
- Mina, the active Vantry owner and case overlays are runtime-created and
  cannot be established by layout JSON alone. Their visibility, reachability
  and absence of debug labels remain visual/live-test evidence.
- This checkpoint closes the case-one apartment rooms. The F02 corridor and
  floor services remain a separate route checkpoint.
