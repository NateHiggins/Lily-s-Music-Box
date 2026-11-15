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
