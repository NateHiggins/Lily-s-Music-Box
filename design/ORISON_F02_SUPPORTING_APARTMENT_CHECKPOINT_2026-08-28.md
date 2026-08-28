# F02 supporting apartment reconstruction checkpoint

## Room profiles

### `F02_B_MAIN`

Lena Ortiz's main room is a seamstress's combined work, meal and receiving
room. The rectangular dining table is her primary pattern-cutting station;
notions and loose patterns live on that surface, while the west-wall pattern
board carries the reference layer. The room remains deliberately modest: one
work/meal table, one paired wall picture and no generic sofa or television.

### `F02_B_KITCHEN`

The kitchen is a compact but complete east-wall run serving Lena's work and
home life. Fridge, stove, sink, toaster, counter and washable floor define the
room. Its open connection to the sleeping alcove is architectural; the actual
apartment entry leaf is present and operable. It deliberately adds no island
or freestanding storage to the narrow central route.

### `F02_B_ALCOVE`

The rear alcove is Lena's private sleeping space, not a second workroom. A bed
and closed wardrobe are the two necessary stations. The standardized bedside
cube was unusable because it occupied the wardrobe footprint, so this room
deliberately omits it; the main-room table already supplies Lena's personal
surface. The open arch remains the alcove entrance.

### `F02_B_BATH`

The bathroom supplies Lena's basin, toilet, shower, medicine cabinet,
ventilation and towel rail in a compact wet room. The cabinet retains her
thimble tin, aspirin and iodine. Fixture standing floor and the privacy leaf
remain visually checkable; no decorative shelf or freestanding clutter is
introduced.

## Structured object and architecture verdicts

| Room | Exact target | Verdict | Expected position/property or manual proof | Rationale | Validation evidence |
|---|---|---|---|---|---|
| `F02_B_MAIN` | `F02_DOOR_03` | KEEP | [visual] Open entry leaf preserves a direct view into the apartment. | Primary apartment arrival. | `00_entry_to_living.png` |
| `F02_B_MAIN` | `2B_din_t`, `2B_din_dc1`, `2B_din_dc2`, `2B_story_notions`, `2B_story_patterns` | KEEP | [visual] One supported sewing/meal station remains reachable from both chairs. | Lena's primary resident-specific station. | `01_living_story_wall.png` |
| `F02_B_MAIN` | `2B_story_pattern_board` | KEEP | [visual] Pattern backing remains on the dry west-wall pier, outside the bathroom. | Keeps work references out of the wet room. | `01_living_story_wall.png`; WalkTest story-board contract |
| `F02_B_MAIN` | `2B_lart_art`, `2B_lart_artf`, `2B_lart_artf2`, `2B_lart_artfl`, `2B_lart_artfr` | KEEP | [visual] Image face remains inside its complete frame. | Intentional resident art rather than an empty receiver. | `01_living_story_wall.png` |
| `F02_B_KITCHEN` | `F02_2B_FRIDGE_01`, `F02_2B_STOVE_01`, `F02_2B_KITCHEN_SINK_01`, `F02_2B_TOASTER_01`, `2B_k`, `2B_k_kdishrack`, `2B_k_kmug` | KEEP | [visual] Complete wall run retains open standing floor. | Ordinary domestic service without duplicate appliances. | `02_kitchen_from_living.png` |
| `F02_B_KITCHEN` | `F02_DOOR_06` | KEEP | [visual] The open leaf is present beside the kitchen run. | Retires the stale missing-panel punch-list report. | `02_kitchen_from_living.png` |
| `F02_B_ALCOVE` | `2B_abed`, `2B_aw_wardrobe` | KEEP | [visual] Bed and closed clothes storage remain distinct and reachable. | Minimum private sleep/storage program. | `03_alcove_from_kitchen.png`, `04_alcove_storage.png` |
| `F02_B_ALCOVE` | `2B_abed_ns` | REMOVE | Exact ID is absent; no replacement. | The standardized cube intersected the wardrobe and could not function. | Final workbench packet reports zero footprint intersections; `04_alcove_storage.png` |
| `F02_B_BATH` | `F02_DOOR_09` | KEEP | [visual] Open privacy leaf retains a fixture view and threshold approach. | Required bathroom privacy. | `05_bath_from_living.png` |
| `F02_B_BATH` | `F02_2B_SINK_01`, `2B_wc`, `F02_2B_SHOWER_01`, `F02_2B_MIRROR_01` | KEEP | [visual] Complete sanitary run remains present; cabinet is closed at capture and retains the explicit 2B inventory. | Required wet-room service and resident-specific medicine storage. | `05_bath_from_living.png`; `godot_shot.log` cabinet receipt |
| `F02_B_BATH` | `2B_trail`, `2B_towel`, `F02_B_BATH_VENT_REGISTER`, `2B_LT_SCONCE` | KEEP | [visual] Towel support, ventilation and local light remain wall-supported. | Ordinary sanitary support. | `05_bath_from_living.png`; LightingAudit |

## Source and generated outputs

`art/data/gen_layout.py` adds an opt-out to the standard bed-set helper and
uses it only for Lena's `2B_abed`. The resulting layout removes exactly
`2B_abed_ns` and its derived `2B_BEDSIDE_TOP` socket. The bed-owned bedside
approach socket remains. Authoring and game layout JSON copies are
SHA-256-identical. Blender 5.2 rebuilt the canonical master and exports; Git
reports generated geometry changes only for the F02 GLTF/BIN pair plus
`orison_master.blend`.

The exact REMOVE decision is machine-authored in
`design/ORISON_F02_SUPPORTING_APARTMENT_CHECKPOINT_2026-08-28.decisions.json`.

## Validation and visual proof

- Generator: PASS, 1,544 assemblies, 102 architectural door leaves and 23 radiators.
- Integrated room-tool suite: PASS.
- Final `F02_B_ALCOVE` workbench packet: zero footprint intersections, zero boundary crossers and zero conservative door-sweep candidates.
- `F02SupportingApartmentShot`: PASS, six 1280x720 player-height frames under `art/renders/orison_room_reconstruction/f02_supporting_apartment_checkpoint_02/`.
- Serialized Godot import: PASS in the same evidence directory.
- `LightingAudit`: PASS.
- `WalkTest` FAST: PASS.

## Remaining ambiguities

- The bathroom workbench's square door envelope reaches the toilet and sink,
  while the rendered radial leaf and threshold view remain usable. This stays
  advisory pending a dedicated physical bathroom-leaf sweep.
- The kitchen's 0.62 m grid estimate is 0.04 m below the local advisory gate;
  the floor image and FAST WalkTest remain the stronger current evidence.
- Dishrack, mug, notions, papers and pinboard assemblies do not yet have static
  footprint metadata. They are retained by visual/runtime evidence rather
  than invented plan boxes.
