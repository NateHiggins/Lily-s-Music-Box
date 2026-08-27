# Orison room reconstruction plan

## Ruling

The Orison is rebuilt as a sequence of believable rooms, not polished as one
undifferentiated prop field.  Traversal tests are necessary but insufficient:
an object may leave a mathematically open route while still intersecting trim,
blocking a door leaf, floating, duplicating another object, or making the room
read as a warehouse of unrelated assets.

No generated JSON or glTF is hand-edited.  Spatial corrections are authored in
`art/data/gen_layout.py`, regenerated, tested, and visually accepted in small
floor-scoped commits.  Runtime props placed by GDScript receive the same audit;
they are not exempt merely because the layout generator cannot see them.

## The room sentence

Every declared room gets one short profile before it receives another object:

1. **Purpose:** what ordinary activity justifies the room.
2. **Primary station:** the surface or apparatus around which that activity is
   organized.
3. **Clear route:** entry to primary station and any required secondary exit.
4. **Resident evidence:** one ordinary clue and one specific clue.
5. **Restraint:** what the room deliberately does not contain.
6. **Condition:** maintained, improvised, exhausted, damaged, vacant, or sealed.

Corridors, plant rooms, stairs, the roof and the street receive profiles too.
“Circulation” is a purpose only when the route, sightline and service hardware
make that purpose legible.

## Object verdicts

Every visible object receives exactly one disposition:

- **Keep:** belongs, fits, is supported and does not obstruct use.
- **Move:** belongs but its relationship, clearance, support or sightline is
  wrong.
- **Repair:** geometry/material/content is broken (including an empty frame).
- **Replace:** the function belongs but this object is redundant, anachronistic
  or visually incoherent.
- **Remove:** no room sentence, gameplay sentence or resident sentence supports
  it. Removal is proposed and traced through the whole tree before authoring.

Interactive objects additionally require a reachable standing position, a
legible prompt sightline, feedback, and a restore/abort condition where stateful.

## Measured gates

- Wall junctions close visually and physically; openings are authored, not
  accidental endpoint gaps.
- Closed and fully open door leaves clear furniture, fixtures, signs, frames,
  interaction positions and the player's 0.33 m body envelope.
- Primary circulation retains 0.80 m clear width; local interaction positions
  retain a 0.66 m body diameter plus reach margin.
- Furniture has credible support and wall standoff. Thin wall art has a real
  image face paired with its frame and sits in the player's reading band.
- No two objects claim the same domestic function without a profile explaining
  the redundancy.
- From the threshold, the room's purpose and primary station read without a UI
  label.
- A floor is accepted only after entry, reverse-angle and door-open proof views,
  plus focused collision/interaction tests and the production walk.

## Order of work

1. **Opening route:** exterior threshold, F01 lobby/navigation, watch desk,
   mail/telephone/service objects, lift and stair decisions. This is the first
   impression and currently the densest authored floor.
2. **Player route:** F04 corridor and 4B, then the exact route to 2A.
3. **Case-one apartment:** F02 corridor and 2A, with Mina's functional stations
   protected before decorative work.
4. **Building services:** B1, roof and every vertical service object. Their
   repeated hardware must form a coherent system rather than eight prop piles.
5. **Remaining occupied units:** one stack at a time, using
   `apartment_life_profiles.json` and `resident_decor_profiles.json` as intent.
6. **Vacant/sealed/transient rooms:** absence and damage become authored
   conditions, not unfinished dressing.
7. **Whole-building reconciliation:** repeated props, lighting correspondence,
   acoustic ownership, unreachable content and final performance budget.

## Evidence ledger

`tools/audit_orison_rooms.py` produces
`design/ORISON_SPATIAL_CENSUS_2026-08-27.md`. Its candidates are intentionally
conservative. A candidate becomes a defect only after checking the generator,
the built production scene and a useful camera angle. Each floor pass appends a
room-profile table and object dispositions to the evidence sheet; screenshots
are evidence, never substitutes for measurements.

## Immediate finding

The exported layout declares 127 rooms and thousands of visible records, but
only supplies a coarse `kind` for room intent. F01 alone has 4,419 furniture
records because the street/site and building interior share one floor owner.
That explains why global counts and generic validators have concealed local
composition failures. The first corrective pass therefore separates F01's
interior-room census from exterior/site dressing before moving a single prop.
