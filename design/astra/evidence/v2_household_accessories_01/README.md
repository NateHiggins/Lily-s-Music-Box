# Six-home kitchen and bathroom accessories

Source integration over `d7f9f8e`. Godot was not launched. V2 remains incomplete;
V1 remains the default and S2J remains open.

All six developed homes (2A, 2B, 3A, 3B, 4A, 4B) now compose their existing native
toaster and medicine-cabinet implementations. The twelve canonical marker IDs,
resident contents, cabinet hinges and 4B's side-opening crumb tray are retained.
Toasters sit on the actual preparation-cabinet meshes. Medicine cabinets mount
against continuous solid wall faces above their sinks, with a 40 mm height
adjustment keeping the flange clear of the fitting envelope. No wall is allowed
to fill the cabinet interior. Supports own each child and its destruction;
no redundant layout markers or furniture copies were added.

One existing planar-mirror renderer serves the six cabinets with a single
384 x 512 viewport. Moving leaves have physical collision, and mirror cleanup
restores the material, disables rendering and releases the viewport texture
before support-owned cabinets retire. The shared renderer now guards freed
active mirrors, including deferred binding and repeated shutdown. Native
toaster cycles, sounds, material bindings and maintenance tray remain shared;
the V2 wrapper blocks a delayed timer after detachment and releases its audio
through FunctionalProp. Existing acoustic endpoints are rebound to the actual
child transforms and restored by the adapter.

`../../work/v2_household_accessories_01/build.py --apply` deterministically owns
`game/data/orison_v2/household_accessories.json`. The companion validator records:

- 294 contact samples, 582 mechanism poses, 1,212 estimated targeting samples,
  6,864 existing route samples and 25 domestic door sweeps.
- Rejection of floating/unsupported toasters and a cabinet pushed into a wall.
- Two byte-identical regenerations; 20 protected files unchanged.
- Thirteen prior category source checks and six GDScript syntax parses passing.

The first proposed 3B cabinet stance was too close to the toilet's conservative
envelope; its final stance is 780 mm ahead of the sink, leaving the required
380 mm body clearance. The source geometry checks include full cabinet motion,
continuous wall backing across 4B's wall extension, and countertop foot contact.
The shared obstacle census now includes these twelve accessories for subsequent
placement batches. Existing furniture, fittings, surface props and layout data
are unchanged.

The apartment engine test is extended for two world lifetimes, real targeting
rays, six concurrent toaster cycles, tray travel, native cabinet contents and
opening, single-view mirror selection, malformed-source refusal, acoustic
restoration and disposal during active mechanisms. These assertions have only
been syntax parsed; they have not been executed.

No new electrical supply simulation or persistence for these mechanisms is
claimed. Reflection correctness/cost, physical interaction and traversal, sound,
materials under voxel lighting, engine compilation and lifecycle remain pending.
Sixteen residential programs with authored occupied/vacant/sealed/storage roles,
shared/service spaces, building migration, persistence and release evidence
remain on the road to V2. The current source inventory is in
`../../work/v2_household_accessories_01/current_inventory.json`.
