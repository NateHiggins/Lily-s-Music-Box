# Dream Blender anatomy pilot implementation — 2026-09-19

Evidence class: **INERT**

REPORT - DREAM-BLENDER-PILOTS - 2026-09-19

Branch: codex/astra-reconcile-20260919. Parent HEAD: 9f9f180. This is a saved
implementation slice inside the authorized sixteen-specimen pass; it does
not claim completion or owner art acceptance. The research map and dossier
remain reference, and no reference image bytes were used or committed.

## Implemented

Tardigrade and Vorticella now use editable Blender anatomy and two exported
detail levels in the debug warehouse. The tardigrade has one continuous
cuticle, eight rooted leg pads, paired hooked claws, mouth lamellae, a hollow
digestive tube and contained storage tissues. Vorticella has a continuous
holdfast, coiling sheath, contained spasmoneme, rolled oral bell, rooted
ciliary bundles, macronucleus and vacuole. Nineteen authored pose samples
preserve the existing controller clocks, tun cycle, stalk contraction and
ten-to-twelve cilium variation. The renderer consumes imported absolute
morph positions/normals; it does not create per-animal skeletons or materials.

Both controllers share one weakly cached float pose atlas and the existing
RG8 world light. Stable compiled sections survive sorting; membership and
inspection LOD changes rebuild bounded batches. A shared membrane pass per
controller reveals actual internal meshes. It adds at most one transparent
draw per controller, plus depth prepass work, and duplicates vertex attribute
storage for split batches. This intentionally revises the earlier two-draw
proposal to make tissue transmission usable. All critter shadow casting
remains off. The new material path contains no decorative stripes.

The inspector includes intact, neutral and explicitly labelled diagnostic
cutaway views. A cutaway may remove skin supporting a still-visible claw;
that image is not an intact attachment failure. Lamp placement now reaches
the half-metre optical grid at close camera distances.

## Verification

Source checks: each tardigrade LOD 4446/4446; each Vorticella LOD 975/975,
over 39 evaluated pose samples. Continuous skin topology, winding, normals,
self-contacts, organ containment and claw attachment drift are checked.
Vorticella's 456 cilium anchor states exactly match evaluated root centroids.
These checks do not prove a continuum collision-free deformation.

Native import/render fixture: 77/77, empty stderr. It checks imported poses
against the GPU atlas, bounded disjoint tissue partitions, sorted identity
mapping, membership changes, actual live controller cycles, paused light
unbind/rebind, resource retirement and 17 rendered diagnostic plates. Source
and native evidence is in art/renders/dream_critter_blender_pilots_20260919.
The custom JSON is INERT diagnostic evidence, not a schema-2 runtime_contract.

At the same isolated warehouse camera: legacy baseline median20.015ms,
p95 20.307ms,231 draws/210937 primitives; new pilot median20.012ms,
p95 20.166ms,232 draws/163303 primitives. These are 240 desktop wall-frame
intervals with CPU clocks paused, not GPU timings or a speedup claim. The
shared atlas is19447808 bytes. Tardigrade LOD0/1:17584/4812 triangles;
Vorticella:18920/4752. Per-controller compilation remains at most84000.

Existing regression suites: warehouse147/147; full-world critter70/70;
debug entry13/13. The full-world critter suite required115 seconds; an earlier
90-second run timed out and is not a verdict. It also logged resident route
errors outside the changed code. Entry retained the known found-art placement
warning. Only the isolated native pilot and zoo logs are error-free here.
Reader gate: NEW0 (1130 known baseline findings). Design document lint clean.

## Remaining work

Fourteen specimens still use the preceding presentation in this slice.
Lacrymaria, Volvox and Stentor are the next source-checked candidates; they
are not enabled by this checkpoint. The full pass still needs their native
motion integration, later researched organisms, then the three fictional
critters. Surface microdetail, species palette separation, material baking,
and final art refinement remain open. Vorticella's sparse bundled cilia and
the tardigrade's broad pads are presentation abstractions, not microscopic
anatomical replicas. Transparent window boundaries still merit close review.

No main merge or push. No protected gameplay authority or selector change
was intended. Prior branch integration blockers remain. No new ruling,
campaign completeness promotion or owner decision is requested by this slice.

Last line: BLOCKED as a full-pass merge candidate; fourteen native rebuilds
and final visual review remain. The pilot implementation itself is runnable.
