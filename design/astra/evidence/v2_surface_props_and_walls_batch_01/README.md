# Apartment surface props and boundary closure

Source integrated; runtime pending. No Godot launched. Continues the owner's
category-batch workflow across the four detailed apartments.

Nineteen fixed surface objects now mount under their actual supporting furniture
or sink: six mugs, four dish racks, two paper groups, headphones, two parts
trays, two jar groups, manuals and a cable coil. The batch contains 9,148 triangles and
reuses the furniture material builder, including its glass shader/haze path.
It adds no collision or interaction owners. Objects follow support transforms
and retire with their supports. They are decoration, not inventory containers.
All source records are validated before mounting; absent supports, occupied
identities, unknown materials and malformed coordinates refuse installation.

The source generator extracts the existing authored assemblies without running
Blender or Godot. It aligns visible mesh bottoms to supports, checks all four
footprint corners against extracted horizontal furniture triangles, and uses
the production sink's drainboard dimensions/rib height as a contact estimate.
Objects sharing a support have at least 1 cm between their footprint bounds.
Omar's existing bench lamp base remains clear; his cable coil uses the exposed
upper-middle shelf board rather than the tops of the shelf uprights. The current
apartment inventory distinguishes these mounted objects from remaining source
assemblies. The three kitchen aggregates still need a storage/cabinet review;
their replaced sinks and appliances do not mean the whole aggregate is complete.

A full-edge ownership audit of all 26 detailed apartment spaces found fifteen
unowned intervals on eleven room edges in 2A, 2B and 4B. Optional `wall_extensions`
now fill precisely those intervals, using the existing wall/material/collision
builder and aperture records. Neighbour-owned walls remain intact; the 2B main
room's east window is cut into its newly present wall. No room rectangles,
doors, openings, windows, anchors or other layout records moved in this batch.
The validator rejects malformed, nonfinite, out-of-bounds or overlapping
extensions, including overlaps with walls owned by other rooms on the floor.

The existing aperture loop also needed to ignore openings wholly outside a
partial segment. Without that guard, an aperture belonging to another part of
the same room edge could create an oversized wall or negative-sized head box.
The fix applies to full walls as well as extensions. Prepared regression checks
include apertures before and after a short segment, production geometry bounds,
matching visual/collision dimensions, preserved window voids and invalid inputs.

Source validation:

- Surface generator: 19 reproducible records; material, geometry, support and
  same-support separation checks pass.
- Wall generator: 15 missing boundary intervals before, zero after; no duplicate
  ownership; semantic preservation checks pass. Authored apertures are retained.
- New wall solids clear furniture collision bounds/pieces, conservative fitting
  estimates and separately owned case tables. The source route audit checks
  6,754 positions against the new wall solids, including the prepared 2A/2B
  player route, Mina's home graph and case/3B/4B circulation spines.
- Existing seating, lighting and door source checks still pass. Lighting's
  support audit now understands partial wall ownership.
- Five affected GDScript files parse with the independent syntax parser. This
  does not establish Godot type checking, engine startup or physics correctness.
- Prepared apartment composition tests cover surface ownership, relative poses,
  duplicate/invalid sources and reconstruction/teardown with the support owners.

Reproducible generators and receipts:
`design/astra/work/v2_surface_props_batch_01/` and
`design/astra/work/v2_apartment_walls_batch_01/`. Both accept `--apply` and refuse
conflicting existing data. The latter audits complete room-edge ownership before
subtracting apertures; zero missing edges is not proof of watertight geometry,
light containment or freedom from all collisions. Route checks address added
walls, not a new whole-world acceptance pass.

Runtime remains pending: engine parsing, complete composition, actual movement,
surface contact, valve targeting, windows, wall seams, materials, voxel/volumetric
light response, lifecycle and performance. Small props add no optical collision
authority; their presence does not establish voxel shadow participation. V1
remains default, V2 is incomplete and S2J remains open.

Next batches: remaining cabinets/storage, coffee tables, boards and equipment
across these four homes; room programs for the twenty other source unit IDs;
remaining building levels/services and persistence. Resume the prepared runtime
and visual acceptance suite when the owner permits Godot again before any
default cutover.
