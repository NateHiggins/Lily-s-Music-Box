# Owner dossier implementation — service and household finishes

Evidence class: **INERT**

REPORT - Owner improvement dossier, household finish batch - 2026-10-08

Branch / source HEAD / origin/main / merge-base at start: main /
f32c09f354c59123d66a04452a887b61f6f11bcc / same / same.
This batch completes the visual work recorded for **T01**, **T05**, **T08**
and **A03**, and advances **T02**, **T03**, **T04** and **T06**. The latter
four retain explicit unfinished details in the owner inventory. This is
neither full dossier completion nor broader V2 acceptance.

The new **zinc_quiet** catalogue material is a generated 1254-square pigment
plate, copied byte-exact to the canonical and runtime albedo. Independent
periodic roughness, normal and height data represent a near-flat coating:
0.008 mm nominal relief, 0.60 m tile and 0.58 mean roughness. Spangle does
not become raised aggregate. No generated lettering or logos are present.
The [tiled and curved material review](../art/renders/orison_v2/zinc_quiet_20261008/quiet_zinc_review.png)
and original prompt/provenance are retained. The
[additive catalogue proof](../art/renders/orison_v2/zinc_quiet_20261008/catalogue_proof.json)
preserves all 65 preceding material definitions and all native/export bytes
of 88 affected families. Existing stale provenance remains stale.

Actor-scoped recipes separate zinc, enamel, iron, brass and plated fittings.
Timber and textile pigment contrast is reduced around the correctly decoded
linear mean; source tints, metre charts and shared geometry survive. The
override skips transparent water/glass and emission, and leaves radiator
vertex-colour heat materials on StandardMaterial3D. V1's material cache is
unchanged. Original moving nodes, controller references and collisions remain
with their original owners. Boiler/radiator service bodies are covered;
independent network pipework is outside this scoped override.

The three existing native bed sizes now carry restrained turnback/foot slack,
pinched pillow seams and flattened undersides at the mattress. A close review
caught the earlier floating cover/pillow gap. The corrected export uses
upward slack above the mattress, retaining thin sheet geometry and the bed
footprint. Engine vertex compression rounds a native 0.051 mm underside
intrusion to 0.100 mm; the contact assertion allows 0.110 mm, including float
representation. This measurement replaces an initially over-tight bound.

The final [shared batch](../art/renders/orison_v2/service_finishes_20261008/batch.json)
passes **11,848 module checks**, plus **22 batch checks**, with zero failures
and one production world. It covers 287 finish owners, 1,610 changed material
slots, 604 opaque pigment-shader slots and 48 loaded mipmapped texture maps.
All 22 beds retain 12 shared meshes, 88 physical top contacts, correct
headboard orientation and clear standing inspection positions. The batch also
checks 41 seating actors, 62 tables, 43 storage actors, 17 small objects,
21 wardrobes, 12 medicine cabinets and 10 complete toaster cycles.

The [runner receipt](../art/renders/orison_v2/service_finishes_20261008/suite_run.json)
binds the tested source and completed run. The test-written
[schema-2 contract](../art/renders/orison_v2/service_finishes_20261008/owner_service_finish/runtime_contract.json)
covers deployed finishes, service-control restoration and owner retirement.
It does not claim disk-save reconstruction or complete player approach routes.
The seven-Texture-RID shutdown warning also occurs in preceding B0/B1/B2
captures; no owner nodes remain in this contract. It is not an empty-stderr run.

[Selected native and installed plates](../art/renders/orison_v2/service_finishes_20261008/review_images.json)
retain full-size images and source hashes. Unchanged household views are reused
from the earlier broad capture. The final bedding export was recaptured at
two representative beds. A paired basin/support camera includes both original
owners and excludes only their own collision when testing visibility; furniture
was not moved. The 3B wardrobe still has an oblique installed contents view,
so garment detail and improved framing remain open.

Failed attempts are preserved as diagnostic logs. They exposed a stale bedding
test base, an unset shader uniform, an overly strict sink-support view and the
contact quantization bound. A premature per-module contract from an interrupted
attempt is not included as proof. Validators now require complete execution
before writing the finish contract, and the shared runner preserves incomplete
validation failures through teardown. All nine modules pass after these fixes.

Gates: reader NEW=0, no missing planner inputs, and the same 36 pre-existing
source-drifting families. The shared runtime change appropriately invalidates
the planner's broader queue; scoped testing does not claim every V2 family was
rerun. Initial fresh verification found only four new test-anchor inventory records.
The manifest appends their exact reviewed records, preserving every previous
entry; all are non-gameplay test references to existing boiler, washer, radiator
and shower anchors. Candidate verification is recorded separately after this
classification update.
This INERT document promotes no completeness-ledger requirement.

Worktree clean at report time: no. Owner dossier files, in-situ shots, unrelated
UIDs and two preceding line-ending-only changes remain outside the commit.

Open findings: local wet-use masks, airer and curtain folds, garment seam cues,
crate/diffuser detail, basement context, the shop finish sets, exterior/roof/lift
finishes and final lighting review remain in their individual inventory cards.
**G15** remains conditional and uninstalled. Broader V2 work remains open.
