## How this brief was made

Every registered prop kind was built once in the inspection shed and
photographed alone from four bearings under a camera-carried fill, with the
camera distance derived from the specimen's own bounds. The harness wrote a
manifest with each specimen's mount, bounds in metres and a material census.
For every specimen, licence-clean reference photographs and period catalogue
plates were fetched from Wikimedia Commons under queries authored from the
prop script and `design/PROP_REFERENCE_NOTES.md` (nine families adversarially
verified against the geometry the script builds; the rest flagged unverified
in `tools/prop_reference/queries.json`), then laid beside our frames on one
sheet per specimen. A reviewer scored each sheet on seven axes under
`tools/prop_reference/CRITIQUE_CONTRACT.md`. The ranking is a formula over
those scores and repository facts, not a vote. Everything is reproducible with
`tools/prop_reference/README.md`.

Counts, so the reader knows the size of the survey rather than the size of
the opinion:

| what | count |
|---|---:|
| registered prop kinds | 44 |
| shed specimens (kinds x variants) | 69 |
| frames photographed | 269 |
| specimens that drew nothing standalone | 2 |
| families whose queries were adversarially verified | 9 of 36 |

## What photographing the shed found before any prop was judged

The instrument had to be corrected four times, and each correction is a
finding about the shed, not about a prop:

- **The shed placed props after adding them.** A door leaf is an
  `AnimatableBody3D` with `sync_to_physics`, which does not follow a parent
  moved after it entered the tree. Every door frame stood on its plinth with
  its leaf at the shed origin. Fixed in `prop_warehouse.gd`: place first, as
  the layout does. Any earlier warehouse render of a door showed a frame
  without a leaf.
- **The front door was built six times.** `LandmarkEntryDoor` inherited
  `DoorProp`'s six inspection variants. It now declares one.
- **The four box fans were one fan.** `boxfan_prop.warehouse_variants()`
  returned rows without `label` or `properties`, so the shed applied nothing
  and built the default fan four times. The earlier box-fan family review
  compared four identical fans. Fixed to the shed's contract.
- **Two props draw nothing outside the building.** `porch_deck` and
  `shop_sign` build from layout context the shed does not supply. They are
  listed at the top of the ranking by construction, because a specimen that
  cannot be inspected cannot be judged; the fix is a warehouse variant that
  supplies a minimal context, not a change to the prop.

Two texturing facts came out of the census rather than the pictures: the
hero front door reads 91% flat colour because its albedo map reaches one of
eleven surfaces after batching, and seventeen specimens, mostly lamps,
signage, the arcade chassis and the case props, carry no albedo map at all.

The reviewers found two more instrument facts while judging:

- **Some props were photographed from behind.** The harness's "front"
  bearing looks from the shed's aisle (+z). A prop whose tended face is
  authored at local -z and that declares no `warehouse_rotation_y()` (the
  stove, the boiler, both fridges and both kettles; the medicine cabinet,
  mail bank, flue breast and doors do declare it) shows the aisle its back,
  so its doors, valves, gauges and wear marks were never in frame. Their
  critiques say so and are capped at medium confidence. The harness now
  carries a fifth bearing from behind so a missing declaration costs a
  frame, not the comparison; this run predates it. The registration fix is
  one line per prop.
- **Two props the shed cannot show as built.** The case door keeps its
  leaf invisible until a scripted reveal, so every bearing framed an empty
  plinth and its critique is from the script. The neon sign is a 6.4 m
  blade whose bounds centre sits above the camera's eye line, so only the
  front bearing catches it, edge-on. Both need a warehouse variant that
  shows the object in its inspectable state, the same class of fix as the
  porch deck and shop sign.
- **The arcade cabinets booted their world.** The inspection camera is
  always inside an arcade machine's live range, so the machine package
  started under the prop node; two of the four chassis then reported
  level-sized bounds (about 400 x 4 x 45 m), a census full of level
  materials, and four empty frames, and the other two are visible in one
  bearing only. All four critiques are written from the script and the
  assembly rulings at low confidence. The shed needs the machine node held
  out of the bounds and the boot gated off for inspection.
- **The hero door's side bearing landed inside its jamb**, so that frame
  is black and three of four bearings show the interior face; its exterior
  pull, slot and lettering were checked in the script.
- **"Mount" is the shed's classification, not the layout's.** The shed
  hangs anything that builds downward from its origin on a soffit and
  stands anything that straddles its origin on a stub wall. The point ball
  therefore reads as a ceiling fixture though the layout places it on a
  rail, and the kitchen batten as a wall fixture. Reviewers scored mount
  against the geometry, not that label.

## Limits of this pass

- Commons full-text search is noisy. Where an authored phrase returned
  nothing, plain fallbacks ran, and some sheets carry an off-topic plate
  beside a good one. The critique names the references it actually used;
  the rest are on the sheet for honesty, not authority. For the five desk
  lamps every fetched reference was off-topic, so those five critiques
  lean on the notes' descriptions of the Emeralite, the friction-joint
  bench lamp and the Buquet pattern rather than on a photograph; three
  fixtures (flush dome, point ball, sconce globe) had no reference at all.
- Twenty-seven families' queries were authored but not adversarially
  verified, because the verification stage ran out of budget twice. Their
  `real_object` statements are the author's reading of the script and the
  notes, unchallenged.
- The shed is a lightbox. Finish that only reads under the building's
  tungsten and shadow is invisible here, and a prop that looks right here
  can still look wrong in its room. The brief says what to model and what to
  texture; it does not replace the installed before/after render the art
  brief requires for every change.
- Effort figures are a modeller-hour estimate from the critique, not a
  schedule.
