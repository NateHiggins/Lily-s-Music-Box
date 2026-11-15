# Harukiya entrance refurbishment

Evidence class: **INERT**. Owner direction and implementation plan; no runtime or artistic acceptance.

## Owner direction

Lily requested a full refurbishment of the bar door and entrance stair on
November 14, then supplied an entrance tableau combining a 1929 speakeasy
with Harukiya: recessed cellar depth, soot-dark brick, damp worn masonry,
exposed pipes and conduit, cyan/magenta neon and warm interior light, and a
heavy reinforced door with brass details. Her supplied image is a private
form and lighting reference. No reference pixels enter textures or exports.

This pass applies that direction to the entrance. Existing cast, narrative,
bar services, stage and room layout retain their owners. The red steel door
and teal descent remain recognizable within the new construction and lighting.
The older reference notes contain retired renderer/arcade statements; current
Bible rulings and the installed V2 Vulkan renderer take precedence.

## Construction target

- A convincing street rim and recessed descent: masonry depth, parapet caps,
  drainage detail and practical lighting reveal where the player walks.
- Continuous treads, risers and landings with readable worn nosings; physical
  handrail brackets and returns; no props or new fittings across the route.
- Soot-dark upper brick and repaired teal lower finish, aged copper/iron
  services with believable wall fixings, selective dampness and contact wear.
- A properly framed red steel door with understandable hinges, latch/keyhole,
  reinforcement and restrained Deco/brass detailing. Fit hardware to the
  existing moving owner and measured opening; review closed, mid-swing and open.
- Controlled cyan/magenta accents with amber light from the room. Existing
  signage and separately authored lettering retain their owners. Reflections
  come from appropriately rough materials and the current renderer; global
  rendering changes require separate measured evidence.

Dense atmosphere belongs around the route. Landings, door swing and hand/foot
clearance must remain usable. Existing stored objects and maintenance tools
must be accounted for rather than silently discarded during replacement.

## November15 reference refinement

Lily supplied a further speakeasy/Harukiya reference and breakdown. Use the
image for spatial layering, material contrast and motivated light: recessed
street-to-cellar depth, soot-dark masonry, exposed iron/copper services,
reinforced steel and brass peephole hardware, wet patches catching cyan and
magenta, and warm light promising an occupied room beyond. Keep the private
reference outside the repository; model original forms and author original maps.

Review of the retained Native08 upper-descent and lower-closed-door captures
finds two concrete gaps: the closed door's peephole/operable hardware loses
readability in shadow, and large finishes remain too uniform and dry. These
captures establish the visual gaps; they do not establish new changes or
artistic acceptance. Finish the existing entrance commission against:

- A legible door, latch/keyhole and peephole from the actual player approach,
  with local motivated grazing light rather than a global exposure increase.
- Patchy moisture at credible drainage/drip locations, worn stair nosings,
  soot and repaired masonry. Preserve roughness variation and dry areas;
  mirror-like treatment of every surface conflicts with the adopted style.
- Continuous, visibly supported services and a restrained neon source whose
  spill separates stair, landing and frame. Keep lettering separately authored.
- Unchanged door sweep, directional passage, waiting pockets and usable route;
  dress the edges without introducing another gate across the qualified lane.

The supplied interior ideas inform the existing destination task: scarred
mahogany/brass, a smoke-aged backbar mirror, bottle silhouettes, used red
upholstery, and practical radio/record-player details. Fit these to the installed
stage, balcony, pool/darts and whole-cast circulation. New weapons, smuggling
scenes and unnamed patrons in the supplied examples are storytelling proposals,
not replacements for the authored cast, schedule or case evidence. Apply the
Bible's period-object and Rule of Signal boundaries to particular equipment.
Use the current Vulkan material/reflection pipeline; the reference's mention of
SSR does not require changing renderers. Haze and sound should preserve face,
clue and dialogue readability and retain existing weather/audio authorities.

## Installed-source intake

The retained cell is loaded by **orison_v2_bar_region.gd** from
**floor_01_cells/shop_bar.gltf**. Source entrance geometry is in
**art/data/gen_layout.py**; the newer destination architecture does not itself
replace this entry. Source audit finds a 1.60 m shaft with an approximately
0.98 m reserved west walking lane and a 0.90 by 2.05 m red door. These are
source measurements, not a completed occupied-clearance or appearance proof.
The private intake records exact replacement stocks and the loader boundaries
before any native replacement is mounted.

## Ownership and verification

Codex owns integration, the entrance asset/adapter and affected clearance tests.
Claude retains cast/presentation ownership. Named paths only; communicate any
shared generator edits before applying them. Work order **w64d37517bac0** is
part of the open Harukiya destination order **wdead817e255d**.

1. Inspect current entry views and measure the opening, landing, full-size
   capsules, leaf sweep and actual retained colliders. Preserve initial failures.
2. Build one editable native entry family with explicit stock retirement and
   independently moving door partitions. Preserve original semantic IDs,
   mechanical/access/save owners, directional passage and stair FIFO.
3. Review native construction, UV scale, registered PBR maps, normals/tangents
   and source/export binding before a combined Godot import/capture.
4. Verify actual loaded surfaces/mipmaps, door operation and directional travel
   in both directions. Exercise occupied entry opposition, waiting pockets and
   all eighteen original resident departures/returns against the final geometry.
5. Run candidate comparison and review before merging. Technical verification,
   human play and Lily's artistic acceptance remain separate.

## Current status

November15 finish follow-up: actual **entry_*** keys previously missed the
existing wall/floor/paint ageing recipes. The local dispatch now strips that
prefix for recipe selection only. The painted leaf uses the registered
**door_paint** material with roughness0.58; brass roughness is0.48. Geometry,
light sources, clock, access and collision owners are unchanged. Loaded green02
passes29checks; focused door636/0, retirement813/0 and light63/0 renew. The
retirement test retains its two deliberate rejection errors in stderr.

All nine **runtime_visual_07** captures were inspected. The red leaf and
reinforcement are more legible, masonry has greater variation and closed-hours
lighting still switches normally. The closed peephole and latch remain dark;
generic mapped ageing does not establish moisture following actual drips or
drainage. These are remaining polish items, not artistic acceptance. Private
**finish_dispatch_green_02** and **runtime_visual_07** hold the new evidence;
earlier failed dispatch diagnostics and the original material bytes are retained.

Native07 repairs the north return and right steel liner with a 35 mm local
rebate, retaining the original pivot and 100-degree travel. Native construction,
strict derivatives and all four reviewed construction views pass; the finish
still needs the installed-lighting review. Public source packaging preserves
220 editable meshes and 27 relative map bindings. Only the static frame GLB
changes; leaf and fixture GLBs remain byte-identical to Native05.

The original loaded door test now passes 636 checks with no sampled contacts,
including the corrected fixed-barrel axis. Actual-cell retirement repeats
813/0 with both deliberate rejection controls; fixture policy repeats 63/0.
The original 635-check door failure and exact-triangle contact diagnostic are
preserved. These are focused diagnostics, not occupied-world proof. Receipts:
private **runtime_repair_01/CHECK_SUMMARY.json** and native07/source_packaging02.

Shipped data now contains the fields used by the loaders; complete construction
metadata remains in adjacent full reports. Complete source rows and retirement
triangles remain authoritative. The unchanged-baseline reader audit has zero
new unread fields, with 34 CPU audit tests passing. Nine installed-lighting
views are queued; optional candid player views compile for the later full-crowd
run without changing its movement, camera or deadline owners.

Earlier retained evidence and outstanding scope:

Native05 construction and strict exported derivatives pass: entrance 3,440
triangles, leaf 1,620, two fixture assemblies 1,232. Four retained-context views
were reviewed; continuous service routing and full door framing improve the
construction, and teal is restored. Finishes remain too clean for the reference.
The neutral preview omits powered lighting and inherited door hardware; it is
not an installed appearance or artistic acceptance claim.

Three GLBs and the source records are installed on the unqualified working
branch. The loader preserves the inherited red-door mechanism and registers
two accent fixtures before the existing opening-hours director starts. Patched
script compilation and both imports pass. Actual fixture/director/budget checks
pass 63 assertions with empty stderr; full LightRig ranking and installed
appearance are outside that focused diagnostic's scope.
The actual-cell retirement preflight passes 813 checks, including deliberate
double-application and late-collider failure controls. Native05's retirement
projection is unchanged; its materials and new fixtures require fresh checks.

The proposed rail leaves about 0.901 m between it and retained storage:
occupied clearance must be tested, not inferred from the 1.60 m shaft width.
The preceding crowd-spacing repair has focused checks passing; full-crowd
qualification remains open. Separate threshold diagnostics accept actual support
and reject a 10 mm floating control at the unchanged 3 mm tolerance. They do
not qualify the entrance. Original failures and source-bound receipts remain
in the private **harukiya_entry_refurb_20261114** report case; the live queue
and immediate next action are recorded in HANDOFF.md.

## November14 qualification update

Native08 finish and nearby nine-view review are complete, with uniform finishes
and closed-door contrast still explicitly unaccepted. Original mass-return
failure is preserved. The approach handoff repair passed the original programme:
421 checks, all five contracts, all18 physical returns, queue drain, continuous
safety and preview/source cleanup. This does not qualify staff, services or play.

Composed surface renewal stopped before composition on stale city fixture
bindings. Exact historical-source review found nine additive grocery placement
markers, unchanged door shop-leaf geometry despite revised mechanics, equivalent
CPU-backed MultiMesh transforms, and reach-limited horizon collision changes that
do not change native construction. Four source dependencies were renewed only
in current INERT construction fixtures, with transitive fixture provenance:
11 documents,14 digest replacements. Every non-binding field and asset stayed
unchanged; historical native/render/runtime reports were not relabelled. All13
surface source preflights and21 horizon CPU tests passed. This is metadata
renewal, not loaded-surface acceptance; the composed run remains required.
Private original bytes, exact diffs and renewal manifest are retained in the
entry-refurb case under **surface_binding_review_01**. The failed surface01
and original failed return receipts remain intact.

Original occupied-opposition renewal also passed:221 checks/all five contracts,
including real opposite-side FIFO requests and physical reoccupation. Final
patched composed surface run completed754 checks with one aggregate failure:
74 surfaces in dream residue(1), margin palps(1), and moss colonies(72).
The33,193-draw inventory reports no Harukiya findings, but the global packet
failed and was not published. This is a technical merge blocker, not a waiver
based on unchanged main debt. Exact ownership/repair coordination was sent to
Claude; original runtime receipt and20 render images remain in the private
**final_qualification_01** case. Staff fit, services/cost, play and artistic
acceptance remain open independently.
