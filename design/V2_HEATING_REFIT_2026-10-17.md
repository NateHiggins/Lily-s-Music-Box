# V2 restricted-cell heating refit — 2026-10-17

Evidence class: **INERT**. Construction and diagnostic report, not a completion
checkpoint or human acceptance. Verification and publication remain in progress.

The original 23-demand heating budget now has 23 installed radiator actors. The
four additions serve 2D, 3C, 5D and 6D at actual V2 room coordinates. Their
section counts, heat-balance ownership, acoustic identities, disk state and sealed
thresholds retain existing authorities. Teleported service checks do not prove
walking access through those thresholds.

The native assembly extends H-D and gives the additions graded overhead branches.
The corrected revision has 96 new hangers, four main bearings, four union tails
and 21 sleeve assemblies. H-D branches pass west of both telephone and electrical
services. The main receives a real opening through the F04 ceiling/F05 floor,
with an annular liner inside the shaft bore. This enclosed passage has no
decorative face plates to intersect the solid shaft. The 3C openings are fabricated into the native
outer leaf as well as the room-side shell.

## Reproduction and ownership

**art/data/orison_v2/heating_refit_authoring.json** contains routes, supports and
owned openings. Its pinned original layout and nineteen-emitter native base
retain the previous assembly. Run **art/blender/scripts/build_heating_refit.py**
in Blender with **--python-exit-code 1**, followed by **-- --work-dir** and a scratch
directory. The recipe binds inputs before/after generation, inspects native
stocks and exports seven batches with metric charts and strict final-buffer
tangent checks. Generated glTF is never edited by hand.

**tools/prepare_v2_heating_refit.py** projects declared anchors, wall/shaft/slab/
masonry openings and four installed consumers. Its **--previous-plan** revision
requires every earlier owned record to match the installed world exactly.
Foreign or modified records, changed pinned authorities and relocated emitters
are rejected. Ten projection tests pass, including preservation/rejection cases.

After projection, regenerate **art/blender/scripts/build_exterior_masonry.py**.
Declaring an opening in JSON does not change that native mesh. Reacquire actual
millwork and run **tools/plan_v2_front_trim.py**; the retained 20 rail and 22 cornice
fittings still cover 21 rooms and 154 source instances. No new catalogue keys.

## Discoveries and verification

The earlier installation passed 100 actual component checks, including twelve
click/grab/motion/release operations and disk reconstruction of distinct partial
valve positions. That result did not prove complete geometry fit.

The actual-world triangle audit subsequently exposed electrical-riser contact,
an uncut shared slab and an outer masonry leaf that had not been regenerated.
Those findings were retained rather than waived. The corrected route clears
acquired electrical geometry. A subsequent exact contact review rejected the
main sleeve's two face plates where they crossed shaft stock. Removing those
unexposed plates retains the liner inside the existing bore. The same bounded
review rejects the earlier plates and clears the revised candidate against the
acquired surroundings; it does not infer full-world containment or access.

Expanded full-height acquisition then found the old generic repair collar
penetrating F04's floor by 15 mm. The fitted sleeve leaves 2 mm above that
actual floor and retains roughly 18 mm engagement on each pipe. Ten native
joint checks cover that clearance, engagement and the unobstructed main bore.
The earlier rejected contact findings remain diagnostic counterexamples.

Native construction passes 179 pipe, 771 hanger and 554 sleeve/bearing checks.
Seven exported batches contain 2,054 closed stocks and 534,568 triangles,
with strict tangent agreement above 0.99999995. The roughly
71.5 MB export is not a performance improvement claim. Native passage renders
were inspected before the next Godot verification.

The earlier packet **art/renders/orison_v2/heating_refit_20261017/** records the
superseded installation. Its receipts remain stale when their source bindings
change; they are never repinned. The corrected native packet is
**art/renders/orison_v2/heating_refit_clearance_20261017/**. Runtime verification
contains the actual 108-check control/save run, including eight shell-collision
probes with nearby solid controls so missing collision geometry cannot
masquerade as a clear opening. Twelve grab/motion/release sequences exercise
closed, open and distinct saved partial valve positions in two production worlds.

The fresh V7 acquired corridor contains 611 draws and 70 walls. All 16 actual
body, supply, shaft and ceiling-entry views were individually inspected. The
native/world diagnostic finds 265 contacts, zero unexplained contacts and zero
sampled containments; its bounded dispositions do not prove complete containment.
A separate native assembly audit checks 393 contacts with no unexpected joins.
The scoped qualifier binds the complete changed main height as well as all four
unchanged authored branches. No walking access through sealed doors is inferred.

The current surface inventory passes 26,799 checks with zero failures across
25,248 draws, 6,086 materials and 465 textures. Seven fresh representative views
were inspected and the real test-written receipt archived. The 19-room access
suite also passes, as does the remaining 60-room suite. Five other
broad runtime contracts retain their original receipts because their runtime
and executed helper bindings are unchanged by the final native-only collar fix.
The native/rendering-bound suites are renewed by execution, never by repinning.

Projection/surface tooling tests and source preflight pass; reader and spatial
audits report zero new issues in the earlier scoped runs. The full baseline
comparison and reviewed commit/push remain pending.
Preserve inherited unrelated dirty paths and stage only named owned paths.

Full V2 remains incomplete: remaining geometry, artistic lighting/material
polish, gameplay/V1 replacement, acoustic integration and whole-game performance
remain separate work. Human visual/navigation/listening acceptance is also
outstanding; automated UV/PBR/mipmap compliance cannot grant photorealism.
