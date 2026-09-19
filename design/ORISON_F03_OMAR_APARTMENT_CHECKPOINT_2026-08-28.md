# F03 Omar apartment reconstruction checkpoint

## Room profiles

### `F03_B_MAIN`

Omar Bell's main room is a maintained repair shop that also supports meals and
ordinary domestic life. The workbench has a clear south service aisle, a
categorized tool field, a half-disassembled sacrificial appliance on newspaper
and a routed extension lead. Shallow intake and outgoing bays make the work's
direction legible without turning the room into generic mess.

### `F03_B_KITCHEN`

The north room remains a working kitchen with a second repair archive along its
west side. Stacked, labelled fastener drawers sit within the existing shelving;
they are deliberate vertical storage, not duplicate floor boxes. The appliance
run and central kitchen approach remain distinct from Omar's repair inventory.

### `F03_B_ALCOVE`

The rear alcove is Omar's compact sleeping and clothes-storage zone. One bed,
nightstand and wardrobe fit behind the privacy stub. Repair work may be visible
from the threshold but does not extend onto the bed or create a second workbench.

### `F03_B_BATH`

The bathroom retains the complete sanitary set, towel support, medicine mirror,
ventilation and one internal privacy leaf. It contains no repair overflow; the
table/chair records seen by the broad packet are neighbouring main-room objects.

## Structured object and architecture verdicts

| Room | Exact target | Verdict | Expected position/property or manual proof | Rationale | Validation evidence |
|---|---|---|---|---|---|
| `F03_B_MAIN` | `3B_workbench`, `3B_toolboard`, `3B_tray1`, `3B_tray2`, `3B_jars`, `3B_manuals`, `3B_radio`, `3B_mug`, `F03_B_LAMP_01` | KEEP | [visual] Bench and supported tools read as one maintained work station. | Preserve Omar's existing repair identity. | `02_workbench_teardown.png` |
| `F03_B_MAIN` | `3B_teardown_newspaper`, `3B_teardown_chassis`, `3B_teardown_cover`, `3B_teardown_motor` | KEEP | Exact IDs occupy the right bench end as a layered teardown. | Required sacrificial appliance that Omar will not declare unrepairable. | `02_workbench_teardown.png`; ADD decision manifest |
| `F03_B_MAIN` | `3B_intake_bay`, `3B_intake_label`, `3B_outgoing_bay`, `3B_outgoing_label` | KEEP | Exact shallow bays remain against the west perimeter. | Separate repair intake from tested/outgoing work. | `03_intake_outgoing_bays.png`; ADD decision manifest |
| `F03_B_MAIN` | `3B_extension_coil`, `3B_extension_lead` | KEEP | Exact coil and narrow routed lead remain south of the bench. | Supply the authored extension lead without blocking circulation. | `01_maintained_main_room.png`, `02_workbench_teardown.png`; ADD decision manifest |
| `F03_B_MAIN` | [manual] entry-to-bath route and workbench service aisle | KEEP | [manual] Workbench route remains 0.80 m in the final packet and visible floor remains south of the bench. | Repair dressing must not consume domestic circulation. | final packet; `01_maintained_main_room.png` |
| `F03_B_KITCHEN` | `3B_fastener_drawer0`, `3B_fastener_drawer1`, `3B_fastener_drawer2`, `3B_fastener_drawer3` | KEEP | Exact drawer fronts stack inside the existing archive shelves. | Required categorized fastener storage. | `04_labeled_fastener_storage.png`; ADD decision manifest |
| `F03_B_KITCHEN` | `3B_fastener_label0`, `3B_fastener_label1`, `3B_fastener_label2`, `3B_fastener_label3` | KEEP | Exact paper label plates remain paired to the drawer fronts. | Labels make organization, not clutter, the governing logic. | `04_labeled_fastener_storage.png`; ADD decision manifest |
| `F03_B_KITCHEN` | `3B_k`, `F03_3B_FRIDGE_01`, `F03_3B_STOVE_01`, `F03_3B_KITCHEN_SINK_01`, `F03_3B_TOASTER_01` | KEEP | [visual] Complete appliance run remains usable and separate. | The repair shop is still a maintained home. | `04_labeled_fastener_storage.png` |
| `F03_B_ALCOVE` | `3B_abed`, `3B_abed_ns`, `3B_aw_wardrobe` | KEEP | [visual] One compact sleep/storage set remains behind the privacy stub. | Preserve a habitable studio rather than duplicating work. | `05_sleeping_alcove.png` |
| `F03_B_BATH` | `F03_3B_SINK_01`, `F03_3B_MIRROR_01`, `3B_wc`, `F03_3B_SHOWER_01`, `F03_B_BATH_VENT_REGISTER` | KEEP | [visual] Complete sanitary and ventilation set remains clear of repair objects. | Required private wet-room service. | `06_bathroom.png`; LightingAudit |

## Source and generated outputs

`art/data/gen_layout.py` adds eighteen exact, apartment-specific records and
one cable-coil assembly. The regenerated authoring and game layout files are
SHA-256-identical. Compare mode isolates every changed record to 3B main or
kitchen; no other F03 room changes at workbench resolution. Blender 5.2 rebuilt
the canonical master and floor exports.

All ADD decisions are machine-authored in the companion decision manifest.

## Validation and visual proof

- Generator: PASS, 1,547 assemblies, 102 architectural door leaves and 23 radiators.
- Final main-room packet: 0.80 m minimum apparent route, no boundary crossers.
- `F03OmarApartmentShot`: PASS, seven 1280x720 player-height frames under
  `art/renders/orison_room_reconstruction/f03_omar_checkpoint_03/`.
- Serialized Godot import: exit 0, recorded in
  `art/renders/orison_room_reconstruction/f03_omar_checkpoint_01/import.log`.
- `LightingAudit`: PASS.
- `WalkTest` FAST: PASS.

## Remaining ambiguities

- Bench-top layers and stacked drawer/label fronts intentionally overlap in
  plan; their different heights are visible in the built scene.
- The existing workbench crosses the kitchen/alcove packet boundary by roughly
  three centimetres because its footprint straddles the declared room seam; it
  remains wholly inside apartment 3B and does not obstruct either use.
- Cable coils, trays, jars, books, radio and mug still lack static footprint
  metadata. They are visually retained rather than assigned invented boxes.
