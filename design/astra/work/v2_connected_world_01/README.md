# V2 connected world — source implementation, native verification pending

Base: `135d6b49dcd9f6feaa62b2125cb00203cb6c7d97`.

The actual explicitly selected V2 runtime now composes the existing street and
bodega module with its sole player, WorkOrders, MaintenanceInventory and a shared
MaintenanceShopService. This is resident composition, not cell streaming.

`world_connection.json` names the construction front door, vestibule, old review
apron and the exterior public threshold/arrival. The connection derives a rigid
transform from these records. The exterior stays at the ruled identity; the
interior rotates 180 degrees and its threshold maps to the origin. Interior
readability cues inherit that same transform. The adapter continues to mount
consumers and acoustic overrides from global semantic anchors.

The exterior receives a derived geometry copy: the closed stand-in door and its
decorations are removed, and the low stone base course is split at the public
portal width. The original standalone exterior data remains unchanged. Only the
named open-shell review apron relinquishes its physical geometry; its semantic
node survives. Dedicated blockout review defaults remain unchanged.

FirstShiftDirector uses the building's arrival placement when supplied. V1's
existing coordinate path remains its default. V2's safety-net seed also uses the
named arrival. Exterior teardown releases its counters and audio before root
services disappear; its injected resolver remains root-owned.

## Evidence and limits

`check_source.py` passes with `source_checks.json`: independent authored geometry
calculation, portal AABB inspection, five files parsed with gdtoolkit 4.5, and
unchanged 17 protected production paths. The parser is installed outside the
repository at `C:/Users/nate_/.cache/orison-source-tools/gdtoolkit`.

This is not a Godot compile, physics walkthrough, screenshot, performance result,
or acceptance of V2. Native runs remain paused by the owner's instruction to
continue source work. Previous runtime receipts apply to their original hashes,
not this new connected composition.

Prepared native scene: `res://tests/OrisonV2ConnectedWorldTest.tscn`. It exercises
missing/duplicate source controls, two complete runtime constructions, shared
authorities, first-shift arrival, doorway ray clearance, bodega counter presence,
and teardown. It is unrun. Ray clearance does not replace capsule traversal.

When native work resumes, use the unchanged serial runner in an empty native
engine lane: compile/import first, then this fixture, then actual capsule walks
both ways through the entrance and shop, a shared-inventory purchase, and matched
player views. Recheck the operator terminal after the global-frame change.

The older F01 provider execution_05/capture_01 baseline is now stale because
these game sources changed. Preserve those seals and evidence; prepare a new
baseline before attempting that continuation. No F01 provider cutover occurred.

Streaming, construction seam/Passage integration, F03 vertical proof, remaining
floors, complete gameplay/save integration, performance and human review remain
open. V1 remains the selector default. No release or default adoption is claimed.
