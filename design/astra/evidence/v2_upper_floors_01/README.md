# Floors five and six: structure and apartment programs

Source integration over `27f407b`. Godot remains paused. This packet does not
claim played traversal, material/lighting appearance, resident migration or V2
completion. V1 remains default and S2J remains open.

Both formerly absent upper levels now enter the production V2 layout: 58 spaces,
30 operable/restricted door leaves, 24 windows, four stair connections, ten
landing platforms and four lift landing records. The primary and service stairs
continue F04–F05–F06 using their existing geometry parameters. These are lift
landing provisions, not newly functioning elevators. The F06 core ceilings close
the top of this stair stack; intermediate cores retain their stair voids.

Six occupied apartment programs cover Nadia Quell (5A), Cal Dwyer (5B), Iris Bell
(5C), Sacha Reed (6A), Jonah Price (6B) and Mae Kessler (6C). Their 42 rooms provide
private arrival, living/meals, sleep, sanitary, cooking and resident work areas.
Iris and Mae retain the source program's two sleeping rooms without assigning
an additional resident. The 5D fire-damaged vacancy and 6D landlord storage retain
locked thresholds and empty resident fields. No new case is enabled.

Every new wall interval has one owner, including partial shared boundaries.
Existing layout records and properties are preserved; only new floor records
are appended. The runtime consumes the generated upper-floor program manifest
through the existing DoorProp mounting owner. The new loader validates the whole
eight-unit/room/door roster, canonical resident assignments, lock states and
reveal settings before replacing any placeholder leaf. The six previously
developed homes retain their original door specifications and zero mount offset.

A source swing check found centre-plane hinges hitting their own jambs near
95 degrees. New doors now sit 80 mm onto the reveal face in their opening
direction, with 220 mm deep frames; the native 100-degree leaf movement remains
unchanged. Existing DoorProp source and existing door placement are preserved.

Source checks pass for unique IDs, original-record preservation, room/chase
separation, single wall ownership and full boundary coverage, portal placement,
window cuts, stair rise/template/core fit, and connected room programs. Checks
against derived wall solids and chases cover 6,030 leaf poses. A 0.38 m capsule
plan search reaches all 42 occupied rooms and both stair arrival lanes on each
floor; traversed grid edges are resampled at 25 mm. With ordinary leaves open,
the closed restricted leaves keep their interiors out of that reachable set.
This is plan clearance, not a door-operating route or stair-climbing simulation.

Four rejecting controls remove a stair, displace an entry, change an original
room, and unlock the fire-damaged unit. Six GDScripts parse. The existing heating,
accessory, preparation-cabinet, bathroom-detail and 56-control persistence source
checks still pass. Earlier preservation checks now compare every original layout
record/property exactly while allowing additive floor records; their original
receipts are retained and replays are stored in this packet.

The official completeness ledger reports all 18 selected F05/F06 obligations
as PROGRAMMED. Its actual exit is **2**, retaining structural/runtime/cutover
blockers. No source packet is promoted to a runtime or human acceptance tier.

`OrisonV2UpperFloorsTest.tscn` is prepared for two complete runtime lifetimes,
single leaf ownership, reveal placement, native full swing, locked-door refusal,
42 floor probes per lifetime, invalid roster rejection and disposal. It has only
been syntax parsed. No Godot process or user save was opened by this work.

`floor_plans.png` is an inspected source drawing. The new occupied apartments
still need furniture, water/heat fittings, lighting circuits, material/voxel
review, resident placement and runtime/performance verification. Eight other
numbered residential programs remain, along with B1 housing, shared/service
provisions, roof/exterior work and wider case migration. The six furnished
source apartments are not counted as completed households.
