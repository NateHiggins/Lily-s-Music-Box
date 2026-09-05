# Omar's storage — source checkpoint

Base: `3a4ffbd7907fa6e3320388eceaf776c650be639b`. No Godot or Blender launched.

V2 now mounts the original `3B_abed_ns`, `3B_aw_wardrobe`, `3B_tools0` and
`3B_tools1` assemblies. The nightstand retains its bedside book and glass;
the shelves retain their steel uprights, oak boards and sorting containers.
The wardrobe retains its hollow oak carcass and resident garments. Original
assembly parameters and identities are preserved. This adds storage presentation,
not a new repair puzzle, tool inventory or completed Omar case.

The new extraction recipe extends the prior pure-Python source extraction.
The prior bed, bench and WC records are byte-equivalent as parsed records.
The new meshes contain 228, 248, 236 and 236 triangles respectively. Original
production layout JSONs, art generator and floor meshes remain unchanged.
Historical extraction receipts are preserved; this directory records the new
source and output hashes and all seven furniture placements.

The existing wardrobe mechanism owns both moving leaves, knobs, prompts and
open/close behavior. Its identity, 1.3 m width and oak setting are validated
before any mounting. A V2 subclass kills its tween and releases scene-owned
creak audio on teardown. Original BakedFurnitureInteraction remains unchanged.
No second static set of wardrobe doors is generated.

The runtime library does not expose fabric_cool, fabric_green or glassish.
These have explicit scoped presentation policies: garments use linen texture
with the source catalog's cool/green tints and roughness; the bedside glass uses
the source exporter's alpha, tint and roughness values, without its ripple maps.
These are pending optical review, not claims of exact Blender material parity.
Unknown material names still fail validation.

Shelves stand south of the main entrance, clear of the bench approach. The
wardrobe stands against the alcove's north wall; its approach is offset to the
right. Eight semantic anchors and four capsule stations are added. The older
alcove capsule station moves 0.4 m east to clear the opening wardrobe. Every
other prior layout record is preserved.

Source checks reproduce extraction, preserve prior meshes, validate normals and
winding, check material coverage and room containment, and test all F03 standing
capsules against closed furniture/fittings. A conservative rectangular leaf
model, including knob/panel thickness, is sampled every degree from 0 through
92 degrees against those stations. This is source geometry checking, not actual
physics, continuous movement or swept-volume certification. GDScript parses with
gdtoolkit; native compilation is unrun.

The connected-world fixture now verifies wardrobe ownership, prompts and open
action, rejects a mismatched mechanism owner, waits for its open animation, then
runs the existing capsule checks. Two constructions exercise teardown, but the
fixture remains unrun. Native targeting, animation, audio and visual review,
closed/open reconstruction and saved-state acceptance remain pending.

Fresh audit results are in `../../evidence/v2_f03_storage_01`. Systemic authority,
interaction carrier/implementor and audio audits and self-tests pass. The data
audit fails globally but has no findings against the furniture or wardrobe
changes. Completeness retains 114 cutover blockers. Spatial dependencies and its
live-repository self-test fail: 37 new failing references, 18 classification
changes, no vanished targets or unresolved save contracts. No baseline updated.

Next: review new spatial bindings individually; extend Omar's bench with his
source-authored radio, parts trays, manuals and toolboard, then connect only
established interactions. Other F03 apartments and full V2 cutover remain open.
V1 is still the default.
