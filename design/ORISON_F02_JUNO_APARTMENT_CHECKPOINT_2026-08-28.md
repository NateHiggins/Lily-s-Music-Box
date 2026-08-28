# F02 Juno apartment reconstruction checkpoint

## Room profiles

### `F02_C_MAIN`

Juno Kells's main room is an improvised audio workshop that still supports
meals and basic domestic life. The metal bench, monitor, stacked amplifiers,
speakers, guitars, pedalboard, microphone, cable field and record crates form
one deliberately untidy recording rig. The compact kitchen and round table
remain distinct support stations. Vertically stacked amps and record crates
are intentional assemblies, not duplicate floor objects.

### `F02_C_BED1`

The west rear room is Juno's only sleeping room. It retains one bed,
nightstand, wardrobe and paired wall picture with a clear threshold approach.
It deliberately contains no recording equipment so sleep is not duplicated by
the work program.

### `F02_C_BED2`

The east rear room is a recording room despite the generic layout kind name.
Rigid blankets are fixed to the north, east and partition walls with visible
battens; a central microphone, guitar, routed cable, empty archive shelf and
record crate carrying the stolen session define the work. There is no bed,
nightstand, wardrobe or generic bedroom picture, and no simulated cloth.

### `F02_C_BATH`

The compact bathroom supplies Juno's basin, toilet, shower, medicine cabinet,
ventilation, switching and towel support. Its two privacy leaves serve the
bedroom and main-room approaches. The room remains sanitary and deliberately
contains no studio overflow.

## Structured object and architecture verdicts

| Room | Exact target | Verdict | Expected position/property or manual proof | Rationale | Validation evidence |
|---|---|---|---|---|---|
| `F02_C_MAIN` | `F02_DOOR_05` | KEEP | [visual] Open apartment leaf retains a direct view into the domestic/studio room. | Primary arrival. | `00_entry_to_2c.png` |
| `F02_C_MAIN` | `2C_bench`, `F02_C_MONITOR_01`, `2C_amp1`, `2C_amp2`, `F02_C_SPEAKER_01`, `F02_C_SPEAKER_02` | KEEP | [visual] Bench, monitor, stacked amps and paired speakers read as one supported rig. | Juno's primary work identity. | `01_main_studio_wide.png`, `03_recording_rig.png` |
| `F02_C_MAIN` | `2C_guitar1`, `2C_guitar2`, `2C_pedals`, `2C_mic`, `2C_coil1`, `2C_coil2` | KEEP | [visual] Instruments, pedals, microphone and cable field cluster around the rig. | Working audio room rather than generic clutter. | `03_recording_rig.png` |
| `F02_C_MAIN` | `F02_2C_FRIDGE_01`, `F02_2C_STOVE_01`, `F02_2C_KITCHEN_SINK_01`, `2C_k`, `2C_k_hob_tape0`, `2C_k_hob_tape1`, `2C_k_hob_tape2` | KEEP | [visual] Complete compact kitchen remains distinct; tape boxes occupy the cold range as authored. | Juno's appliance-specific ordinary-life evidence. | `02_kitchen_tape_shelf.png` |
| `F02_C_MAIN` | `2C_din_t`, `2C_din_dc1`, `2C_din_dc2` | KEEP | [visual] Round table and two chairs retain approaches outside the central rig. | Minimum meal station. | `01_main_studio_wide.png` |
| `F02_C_BED1` | `2C_bed0`, `2C_bed0_ns`, `2C_w0_wardrobe` | KEEP | [visual] One complete sleep/clothes-storage station remains. | Juno lives alone and retains exactly one bed. | `04_only_bedroom.png` |
| `F02_C_BED1` | `2C_bart0_art`, `2C_bart0_artf`, `2C_bart0_artf2`, `2C_bart0_artfl`, `2C_bart0_artfr` | KEEP | [visual] Bedroom art remains paired and wall-supported. | Intentional picture, not an empty receiver. | `04_only_bedroom.png` |
| `F02_C_BED2` | `2C_bed1`, `2C_bed1_ns`, `2C_w1_wardrobe`, `2C_bart1_art`, `2C_bart1_artf`, `2C_bart1_artf2`, `2C_bart1_artfl`, `2C_bart1_artfr` | REMOVE | Exact IDs are absent; no generic bedroom replacements. | Complete the declared spare-bedroom conversion. | Final packet and companion decision manifest |
| `F02_C_BED2` | `2C_recording_blanket_w`, `2C_recording_blanket_n`, `2C_recording_blanket_e` | KEEP | [visual] Three rigid wall-fixed absorbers remain visible; north/east panels retain battens. | Improvised acoustic treatment without simulated drapery. | `05_recording_room_threshold.png`, `06_recording_room_archive.png` |
| `F02_C_BED2` | `2C_recording_mic`, `2C_recording_guitar`, `2C_recording_cable_coil`, `2C_recording_cable_run` | KEEP | [visual] Central mic, instrument and routed cable retain clear floor around them. | Required recording kit and cable discipline. | `06_recording_room_archive.png` |
| `F02_C_BED2` | `2C_recording_archive_shelf`, `2C_recording_stolen_session` | KEEP | [visual] Archive shelf and record crate occupy the room perimeter. | Material evidence of the stolen session. | `06_recording_room_archive.png` |
| `F02_C_BATH` | `F02_2C_SINK_01`, `2C_wc`, `F02_2C_SHOWER_01`, `F02_2C_MIRROR_01`, `F02_C_BATH_VENT_REGISTER` | KEEP | [visual] Complete sanitary fixture and ventilation set remains available from both thresholds. | Required private wet-room service. | `07_bath_from_main.png`; LightingAudit |

## Source and generated outputs

`art/data/gen_layout.py` suppresses the standard furnishing pass only for
2C's second bedroom, then authors the rigid recording-room kit inside the same
declared room. The conversion removes eight exact generic-bedroom records and
their derived sockets, leaving Juno with one bed and one wardrobe. The
authoring and game layout JSON files are SHA-256-identical. Blender 5.2 rebuilt
the canonical master and exports; Git reports generated geometry changes only
for the F02 GLTF/BIN pair plus `orison_master.blend`.

The eight exact REMOVE decisions are machine-authored in
`design/ORISON_F02_JUNO_APARTMENT_CHECKPOINT_2026-08-28.decisions.json`.

## Validation and visual proof

- Generator: PASS, 1,546 assemblies, 102 architectural door leaves and 23 radiators.
- Integrated room-tool suite: PASS.
- Final `F02_C_BED2` workbench packet: zero conservative door-sweep candidates and zero boundary crossers; four reported contacts are intentional blanket/batten joins.
- `F02JunoApartmentShot`: PASS, eight 1280x720 player-height frames under `art/renders/orison_room_reconstruction/f02_juno_checkpoint_02/`.
- Serialized Godot import: PASS in the same evidence directory.
- `LightingAudit`: PASS.
- `WalkTest` FAST: PASS with all 20 remaining wardrobe records owning paired-leaf mechanisms.

## Remaining ambiguities

- The main-room workbench reports a zero-width route because soft floor layers,
  intentionally stacked equipment and the bathroom overlap envelope share the
  broad living rectangle. FAST WalkTest and the eight-view proof are stronger
  evidence than that aggregate heuristic.
- Cable coils, bottles, dishracks and mugs remain without static footprint
  metadata. They are visually retained rather than assigned invented boxes.
- The room ID remains `F02_C_BED2` for compatibility, while its profile and
  contents make its recording-room purpose explicit.
