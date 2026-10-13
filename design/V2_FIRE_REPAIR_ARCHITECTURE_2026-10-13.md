# V2 building form and localized fire repairs — 2026-10-13

Evidence class: **INERT**. Architectural review and implementation report;
this document grants no room, runtime, or human acceptance.

## Form diagnosis

Eight installed daylight views were reviewed against the authored occupied
footprint, exterior masonry leaf and roof bridge. The front court is very
tall, recessed and mostly blank. Its changing lower footprints leave prominent
isolated-looking brick masses below a six-storey roof bridge. The roof already
has three seated steel girders; the masonry suite measured 1,598 underside
triangles and found zero competing slab faces. That establishes geometric
ownership, not a convincing architectural composition or structural capacity.
The rear reads as a more continuous occupied wall; it should not receive the
same uniform distress as the entrance court.

The malformed impression therefore includes a real visual-design problem:
the volumes lack a readable construction history. It is not resolved merely
by confirming their JSON dimensions. This first repair batch makes the
building-frame west front wing an active work site. The central recess,
remaining exposed transitions and interior construction history still need
further architectural development. They are not accepted as finished.

## Added architecture

The owner's instruction supplies the post-fire, mid-renovation direction.
No fire date, cause, displaced resident or demolished former room has been
invented as established Bible canon. Native construction comprises 188 closed
stocks, three finish partitions and 7,888 triangles:

- Four timber uprights seated on individual sole boards, with four tiers of
  ledgers, transverse bearers, separate jointed deck planks and alternating
  face/end braces. Each tier has toe boards, guard posts and two guard rails.
- Fixed iron straps at ledger joints and wall ties embedded at floor lines,
  with independent bearing plates. Staging occupies the outside of the west
  front wing, clear of the entrance and retained glazing apertures.
- Five source-fitted west study window heads have separate angle webs and
  horizontal seats, with 180 mm end bearing. Alternating replacement brick
  reveal lengths produce toothed repairs rather than a flat distress decal.

The shell, occupied rooms, original windows, door controls, service connections,
roof supports, resident ownership and circulation authority remain source-owned.
These additions are fixed renovation architecture, not a new gameplay system.
The recipe is **art/blender/scripts/build_fire_repairs.py**, editable native
file **art/blender/fire_repairs.blend**, and generated asset
**game/assets/props/fire_repairs.glb**. The construction inventory is
**art/blender/fire_repairs_construction.json**.

## Verification and limits

Review packet: **art/renders/orison_v2/fire_repairs_20261013/**. Native review
precedes installed captures. The packet's **installed.log.receipt.json** records
completed execution; the actual test prints **EXTERIOR MASONRY: failures=0**.
It checks retained slab interfaces and shell contacts, new noncollapsed imported
UV triangles, real loaded albedo/roughness/normal mip chains, matching fixed
collisions and the clear entrance approach. This wrapper is a suite-run receipt,
not a schema-2 runtime contract and does not promote requirements.

The schema-2 whole-world surface contract is refreshed in
**art/renders/orison_v2/surface_requirements_20261011/runtime_contract.json**.
Its run completes 26,435 checks with zero failures, covering 23,748 draws,
16,229 meshes, 5,846 materials and 465 textures. All new stock uses existing
registered custom PBR maps and authored metric UVs; no texture files are added.
Selective import precision preserves the thin iron/brick-edge charts.
Exported tangent agreement is at least 0.99999996. The rendered-review manifest
explicitly records the unfinished central recess. Technical surface compliance
does not imply photoreal or whole-building acceptance.

The unrelated ongoing nine-apartment walkthrough is retained as diagnostic
work: its latest completed run reached 48 of 60 rooms, with 16 failed checks
concentrated in the 4A and 5B entry legs. It grants no access promotions.
The 69 newly scanned room/unit references are test-only and were registered
append-only after review; production spatial references are unchanged.

Further architectural work must address the tall court's construction history,
provide a convincing site-access arrangement, and inspect the two entry
obstructions before changing occupied-room geometry. Human aesthetic approval,
complete V2 construction and V1 retirement remain outstanding.

## Management report

REPORT - V2-FIRE-REPAIR-ARCHITECTURE - 2026-10-13

Branch / validation HEAD / origin/main / merge-base: main /
cb218439df1f45eaa05c6ff8d0cdd627f903cc94 /
e0b0dd293325a49c207785888112262a4990e474 / same origin/main.
Publishing a scoped checkpoint to **codex/v2-direct-manipulation-checkpoint**;
no origin/main integration is claimed.

Worktree clean at end: **no**. Shared inherited artifact/import changes and
ongoing work remain; only named owned paths are staged.
Protected 17/17: **yes**, unchanged versus merge-base. Selector: **v2**.
Ledger before -> after, in first-slice / golden / structural / runtime /
cutover / retirement order: **0 / 1 / 102 / 34 / 119 / 121 -> unchanged**;
requirements_changed: **none**.

Gates: 55-row final board in the review packet; zero regressions against
**tmp/v2-next-20261013/gates-final/board.json**. Completeness remains exit 2
(incomplete baseline); spatial, systemic, period, reader, import policies,
surface qualification and all 45 tools tests pass. Reader NEW is zero.
The board transparently reuses the unchanged rows from this batch's complete
run and refreshes spatial, ledger, surface qualification and the live
completeness test after renewal of the canonical receipts.

Godot receipts in the packet: **installed.log.receipt.json** completed,
**surfaces.log.receipt.json** PASS / 26,435 checks,
**apartments.log.receipt.json** PASS / 268 checks / 19 rooms,
**firstslice.log.receipt.json** PASS / 113 checks with reconstruction.
The original 60-second exterior baseline capture timed out and is not proof;
the 300-second retry completed. No legacy acceptance is inferred from it.

Changes outside the architectural boundary: canonical surface, existing
apartment access and first-slice authority contracts renewed because their
production-input bindings expired; ongoing nine-apartment diagnostic harness
and its test-only spatial references retained. No failed diagnostic promotes
any room. Open findings are the central-court silhouette, site-access detail,
4A/5B entry paths, remaining direct-manipulation debt and wider V2 completion.
Decision needed from owner: **none** for the next authorized work.

BLOCKED whole-building merge/completion claim: architecture and access work remain.
