# Household wireless category batch

Source integrated; runtime pending. No Godot launched.

Each of the four detailed apartments now composes its existing authored
household receiver profile through DomesticRadioProp. A dedicated 1.10 m by
0.46 m table keeps the set and its separate speaker clear of the desks,
case instruments, dining surfaces and previously mounted small props.

| Unit | Existing receiver family | Speaker | V2 support |
| --- | --- | --- | --- |
| 2A | Atwater Kent 44 | Cone | 2A_wireless_table |
| 2B | Three-dial battery | Cone | 2B_wireless_table |
| 3B | Three-dial battery | Horn | 3B_wireless_table |
| 4B | Three-dial battery | Cone | 4B_wireless_table |

The global 1928 household profile catalog is unchanged. V2 takes a copy of each
selected profile and substitutes its support and measured tabletop height.
Each receiver is a child of its table, so position, yaw and destruction follow
that furniture owner. All four sets start off. Their shared implementation owns
the power switch, tuning pose, bounded local programme murmur, conductor-event
gating, primary interaction area and emitter release. This adds no second
broadcast director or video decoder and writes no persistent listening state.
It does not add dated news, programme selection or a new historical broadcast.

The V2 subclass adds feet/pedestals beneath the separate speaker cones and
applies existing texture-backed walnut, Bakelite, cloth, paper, brass and metal
materials. The Atwater Kent chassis receives enamel while its knobs remain
Bakelite. The existing radio and FunctionalProp classes, audio policy, sound
asset and material catalog remain unchanged. No receiver detail adds a movement
body; its table retains the furniture system's conservative collision box.

Four new tables contain 2,016 source triangles. Furniture now totals 61 records,
alongside 19 fixed surface props, 20 functional household fittings and the four
new household radios. There are eight new semantic anchors: four table anchors
and four operator stances. Receiver geometry is built by the shared runtime
family; the table triangle count is not a complete receiver cost measurement.

Source checks pass:

- Each receiver's conservative envelope has all four footprint corners on
  the extracted tabletop at 0.745 m. The off-centre positions leave room for
  the separate cone or horn speaker without hanging it beyond the table.
- Tables and estimated receiver envelopes clear current furniture, fittings,
  radiator bounds, switches, separately owned case tables and surface props.
- Existing circulation is checked at 6,876 sampled positions. All 17 domestic
  and service door leaves clear the tables across 201 samples per sweep.
- The four new operator approaches are checked at 209 additional positions
  against existing obstacles. Each eye-to-receiver segment is within 2.1 m and
  sampled at 101 points for intervening source bounds.
- Existing seating, lighting, door, wall, surface-prop and storage-batch source
  checks continue to pass. The current inventory lists household receivers
  separately from source furniture assemblies.
- All 57 previous furniture records and all previous layout records/anchors
  are preserved. Global radio profiles, fixtures, small props, lights, case
  placement, Mina's routes, shared behavior/audio/media owners and project
  configuration are unchanged. Re-applying the batch changes no bytes.
- Four changed/new GDScript files parse with the independent parser. This is
  syntax validation, not Godot type checking or engine execution.

Prepared apartment composition checks include physical rays from the operator
stances, silence on reconstruction, per-household power isolation, programme
start/stop, texture coverage, unchanged campaign state, malformed/duplicate
source refusal and teardown with all four programme emitters playing. Receivers,
interaction areas and emitters must retire with their supports. No prepared
engine check has run, and the sampled source sightlines do not establish real
player targeting, audio behavior or lifecycle correctness.

Reproduce the source checks with
`design/astra/work/v2_household_radios_batch_01/validate.py`.
The batch builder accepts `--apply` and rejects conflicting existing IDs.
The component-aware inventory remains at
`design/astra/work/v2_apartment_seating_batch_01/apartment_inventory.json`.

The existing 3B specialist bench-radio assembly is still a separate pending
object; this household receiver does not silently replace it. Likewise, the
remaining legacy television records require the existing projector/media
integration path, not bare television cabinet geometry. The reel deck, lower
kitchen cabinetry, other twenty source unit programs, remaining building
levels, services and persistence remain open. Physical targeting, material/light
appearance, audio isolation/release and performance still need runtime review.
V1 remains default; V2 is incomplete and S2J remains open.
