# Orison basement and roof vertical-services checkpoint

## Room profiles

### `B1_STORAGE_CAGES`

The west basement room is the tenants' locked overflow store. Four open metal
cages, visible crate stacks, the structural pier/beam rhythm and a clear east
aisle are its complete station. The cages must read as permeable security
work—not opaque rooms—and must not absorb the stair/door approach. It does not
become a generic prop dump or a second maintenance workshop.

### `B1_LAUNDRY`

The laundry is a shared wash-and-fold room. Two washers, drying airer, folding
surface, baskets, bench and local cage bulb form an ordinary resident service
station. The broad central standing floor and the route back to the stair are
more important than added dressing.

### `B1_BOILER`

The boiler room is the building's heat-production station. Boiler, breeching,
header/riser network, feed tank, chemical bucket, drain and gauge board must
remain readable as one maintained system with clear access from both service
doors. The room is machinery first; unrelated storage does not belong here.

### `B1_COAL`

The coal room is the boiler's compact fuel annex. The coal heap, low service
light and direct open leaf to the boiler room are its complete purpose. It is
deliberately sparse and dirty, not a second general store.

### `B1_ELECTRICAL`

The electrical room is the house distribution station. Panel bank, conduit,
service light and clear inspection floor are primary. The panel face must stay
reachable for the fuse maintenance route; no resident furniture is added.

### `B1_HALL`

The basement hall is the compact lift-to-stair transfer. Its only job is to
keep the lift, stair and basement service approaches legible under a flush
light. It remains unfurnished.

### `B1_ATRIUM`

The basement atrium is the bottom stair landing and the lower termination of
the building's vertical service tree. Stair guards, landing, pipe header and
the small resident nook remain distinct around an open circulation floor.

### `B1_UTILITY`

The utility room is the basement continuation of the chute and meter service
stack. Hopper, meter bank, mop fixture, light and clear centre standing area
remain the complete station.

### `ROOF_OPEN`

The roof is the upper terminus of circulation and building services: stair
bulkhead doors, guarded atrium eye, skylight, tank and ball cock, garden beds,
clothesline and sheltered deck. Both roof doors must lead onto continuous
walkable surface and the new top guard must close the stair-eye drop. Weather,
maintenance and tenant gardening share the roof without speculative clutter.

## Structured object and architecture verdicts

| Room | Exact target | Verdict | Expected property or visual proof | Rationale | Validation evidence |
|---|---|---|---|---|---|
| `B1_STORAGE_CAGES` | `b1_cage_front_bottom`, `b1_cage_front_top`, `b1_cage_front_bar00`, `b1_cage_front_bar20`, `b1_cage_front_bar39` | KEEP | [visual] Representative rails and the full bar run remain visibly permeable. | Replace the opaque placeholder wall with legible cage construction. | `00_storage_cages_entry.png` |
| `B1_STORAGE_CAGES` | `b1_cage_div0_bottom`, `b1_cage_div0_top`, `b1_cage_div0_bar00`, `b1_cage_div3_bar09` | KEEP | [visual] Representative divider rails/bars preserve four distinct bays. | Security partitions should divide storage without hiding it. | `00_storage_cages_entry.png` |
| `B1_STORAGE_CAGES` | `b1_crate0`, `b1_crate1`, `b1_crate1_top`, `b1_crate2`, `b1_crate3`, `b1_crate3_top` | KEEP | [visual] Battened crate assemblies remain visible behind the bars. | Stored objects replace featureless trim blocks. | `00_storage_cages_entry.png` |
| `B1_LAUNDRY` | `B1_WASHER_01`, `B1_WASHER_02`, `B1_LAUNDRY_AIRER_01`, `b1_foldtable`, `b1_bench` | KEEP | [visual] Wash, dry, fold and wait stations retain clear standing floor. | Complete shared laundry service. | `01_laundry_entry.png` |
| `B1_BOILER` | `B1_BOILER_01`, `b1_boiler_breeching`, `ops_feed_tank`, `ops_boiler_gauge_board` | KEEP | [visual] Boiler and service network remain readable with both approaches clear. | Preserve the building heat-production system. | `02_boiler_from_door.png` |
| `B1_COAL` | `B1_DOOR_07`, `b1_coal_heap` | KEEP | [visual] Open service leaf reaches the fuel annex without an obstruction. | Preserve the boiler/fuel relationship. | `03_coal_room.png` |
| `B1_ELECTRICAL` | `b1_panel0`, `b1_panel1`, `b1_panel2`, `b1_econduit` | KEEP | [visual] Panel faces and conduit remain visible from clear inspection floor. | Preserve fuse-service access. | `04_electrical_entry.png` |
| `B1_HALL` | `B1_HALL_LT_FLUSH_DOME` | KEEP | [visual] Lit lift/stair transfer remains unfurnished and readable. | Pure circulation room. | `05_basement_hall.png` |
| `B1_ATRIUM` | `b1_header`, `B1_NOOK_LAMP` | KEEP | [visual] Basement pipe terminus and resident nook remain distinct around the stair landing. | Prove the lower end of the shared stair/service stack. | `06_basement_atrium.png` |
| `B1_UTILITY` | `B1_chute`, `B1_hopper`, `B1_meter0`, `B1_meter1`, `B1_meter2`, `B1_mop` | KEEP | [visual] Service fixtures remain perimeter-supported around open standing floor. | Complete basement stack service. | `07_basement_utility.png` |
| `ROOF_OPEN` | `ROOF_DOOR_01`, `ROOF_DOOR_02` | KEEP | [visual] Both open leaves land on continuous roof route. | Preserve stair and service access to the roof. | `08_roof_door_route.png` |
| `ROOF_OPEN` | `ROOF_EYEGUARD_s_rail`, `ROOF_EYEGUARD_n_rail` | KEEP | [visual] Continuous top guards close both exposed eye edges. | Prevent the former unguarded roof-level drop. | `09_roof_eye_guard.png` |
| `ROOF_OPEN` | `roof_deck`, `roof_bench`, `roof_table`, `watertank`, `roof_bed0`, `roof_bed1`, `roof_bed2` | KEEP | [visual] Maintenance, seating and garden zones remain separated by open walking surface. | Shared roof use without route clutter. | `10_roof_garden_deck.png` |

## Authoritative reconstruction and generated outputs

`art/data/gen_layout.py` replaces five opaque B1 storage-cage slabs
(`b1_cagefront`, `b1_cagediv0` through `b1_cagediv3`) with open bottom/top
rails and vertical bars. The four existing `b1_crate0` through `b1_crate3`
ids now instantiate real crate assemblies, with two upper crates added to the
taller stacks. The four bay positions, east aisle and room envelope do not
move.

The regenerated authoring and game layout JSON files are SHA-256-identical.
Blender 5.2 rebuilt the canonical master and B1 GLTF/BIN pair; every other
floor export remained byte-stable. Workbench comparison confines layout
record changes to `B1_STORAGE_CAGES`; its final occupied ratio falls from
0.064 to 0.020 while the 0.666 m conservative route estimate remains green at
the local 0.66 m gate.

Machine-checkable replacement/assembly decisions live in
`design/ORISON_B1_ROOF_VERTICAL_CHECKPOINT_2026-08-28.decisions.json`.

## Validation and visual proof

- Generator: PASS, 1,545 assemblies, 102 architectural door leaves and 23 radiators.
- Integrated spatial-tool suite: PASS, 186/186.
- `B1RoofVerticalServicesShot`: PASS, eleven 1280x720 player-height frames under `art/renders/orison_room_reconstruction/b1_roof_vertical_checkpoint_05/`.
- Serialized Godot import: exit 0, recorded in `art/renders/orison_room_reconstruction/b1_roof_vertical_checkpoint_05/import.log`.
- `LightingAudit`: PASS, recorded in `art/renders/orison_room_reconstruction/b1_roof_vertical_checkpoint_05/lighting_audit.log`.
- `WalkTest` FAST: PASS, recorded in `art/renders/orison_room_reconstruction/b1_roof_vertical_checkpoint_05/walk_fast.log`.

## Remaining ambiguities

- The storage-door square sweep still touches a structural pier at one corner;
  the real open leaf and player aisle remain visually clear. The pier is not
  movable furniture.
- The roof workbench reports a 0.64 m grid estimate from the open service door
  to its remote anchor, 0.02 m below the local advisory gate. The direct
  door-to-door route is 0.708 m and FAST WalkTest passes; a physical full walk
  remains the stronger release proof.
- Watering-can, coal-heap and legacy arcade-cabinet footprints remain unknown
  to the static workbench. They are retained by visual evidence, not invented
  plan geometry.
