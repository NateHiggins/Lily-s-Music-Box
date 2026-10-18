# Native work-light aperture repair — 2026-10-18

Evidence class: **INERT**. Incremental optical repair, not photoreal, human,
region-completion or V2 completion acceptance.

## Diagnosis and source change

The clipped white oval on the bodega window comes from the original shed-entry
work lamp's direct specular contribution. Independent normal-off, roughness,
all-direct-specular-off and entry-lamp-only controls are retained under
**art/reviews/v2_glazing_20261018**. Normal-off preserves the oval; disabling
only the entry lamp's specular removes it. Raising glass roughness conceals it
but changes the window finish, so that control is not the production repair.

The loaded native emitting envelope is approximately **90 mm wide by 110 mm
high**. The light retained the generic **160 mm** finite-source size. The V2 presentation layer now derives each matching native cage lamp's
horizontal source radius from its actual fitted emitting mesh, including the
six alley/shed lamps and the native fixed-light family. It initializes the
value through the existing light-rig tuning API after authored profiles load. The pear-envelope size is about **45 mm**. The loaded family covers
**72 sources**: 59 fixed, seven front-gallery and six service fixtures. Godot's finite-source shading uses source size divided by distance
to obtain its angular extent; see the [official Light3D documentation](https://docs.godotengine.org/en/4.7/classes/class_light3d.html#class-light3d-property-light-size)
and [4.7 renderer implementation](https://github.com/godotengine/godot/blob/4.7-stable/servers/rendering/renderer_rd/shaders/scene_forward_lights_inc.glsl#L444).

The fixed-camera control reduces clipped white pixels in the observed oval's
ROI from **9,959 to 934**. This is a descriptive comparison, not a visual
acceptance threshold. The production reflection remains specular and finite.
No glass roughness, normal strength, tint, transparency, sky or light energy
was changed to hide the defect. The native bulb remains in its original pose;
the source stays within it. Original light, bounce, halo, emission material,
swing, circuit and maintenance-tuning owners remain authoritative. No new
texture pixels, mesh geometry or export are needed for this optical repair.

The combined instrument checks independently measure the imported bulb vertices
and compare them to the actual source size. They check one emitting envelope,
retained original owners and photometric settings, the fitted radius and the
existing light rig's ownership of that radius. These do not grant full room,
interaction or global resource acceptance.

## Verification status

The service-only combined stage passes **30,701 checks**, zero failures, but
its same-world arcade views reveal the same large reflection beside the portal.
It is retained as a superseded diagnostic under **service_only_stage**. The
broader native cage-family source passes its combined qualification:
**30,989 checks, zero failures**, **25,649 draws, 6,096 materials and 482 textures**.
All 72 actual emitting envelopes are independently checked against their imported
vertices, original source identity/pose/specular contribution and existing tuning
authority; every other original tuning value remains unchanged. The 23 reviewed
renders and actual test-written contract are published in
**art/renders/orison_v2/surface_requirements_20261011**. No gameplay/access proof
was renewed for the superseded intermediate source. Gameplay/save and played-room proofs expired on the source change and
were renewed through the genuine executions below before publishing the source
checkpoint. The earlier receipts remain historical; none is repinned.

The final-source service-round test now passes **360 printed checks** (359
serialized before the final flush check), including real finite-part delivery,
resident return, actual disk reconstruction and bounded teardown. Its unchanged
test-written contract and matching wrapper/raw logs are published at
**art/renders/orison_v2/first_slice_contract_20261011** after independent current-
source validation. The physical fingerprint remains
**a607395345c18840a74138d8ce36a394cf3f6241862aac12771db342aef422e4**.
The home cohort also passes **62 rooms, nine legs and 909 checks**, zero
failures; independent current-source validation passes all 15 transitive test
dependencies. Its ten tracked root/driver nodes retire, none retained. The
unchanged actual proof and logs are published at
**art/renders/orison_v2/access_home_cohort_20261018**. The combined upper/roof cohort also passes **69 rooms, eleven legs and
989 checks**, zero failures. Independent validation passes all 16 dependencies;
its 13 tracked root/driver/check nodes retire, none retained. The complete,
unfiltered contract and matching raw logs are published at
**art/renders/orison_v2/access_upper_cohort_20261018**. These are genuine
executions against the final source; no earlier receipt is repinned.

The additional portal, throat and arcade-hall cameras are observations of the
current world only. Missing authoritative region records and the broader
structural/runtime requirements are not satisfied by these camera placements.
A small bright source reflection, simplified reflection geometry, broad warm
lighting, other fixture families and remaining world detail remain subject to
further visual work. Seven known texture-resource shutdown warnings remain
open unless a new measured result establishes otherwise.

## Management report

REPORT - V2-WORK-LIGHT-APERTURES - 2026-10-18

Branch / HEAD / origin/main / merge-base: **main**;
**5a4a320cdea6fd253382d97605c3fbe1e4ecb3f1** before the named repair diff.
Verified source candidate: **19a20d07f3573e59453e468df24449a8b994ad95**.
Origin/main and merge-base at comparison: **5a4a320cdea6fd253382d97605c3fbe1e4ecb3f1**.
The following publication commit changes only report/verification metadata.

Worktree clean at end: **no**. Unrelated shared changes, generated UIDs and
import/EOL noise remain preserved. Only named owned paths were staged.
The path-only snapshot is **art/reviews/v2_glazing_20261018/shared_checkout_status.json**.

Protected **17/17 unchanged**, selector **V2**, explicit V1 rollback preserved.
The clean temporary checkout passes candidate verification in **in-place** mode
with **--no-godot**. No fresh-cache Godot import or runtime execution is claimed
there; the genuine canonical runs above are reused. Exact outputs are retained
under **art/reviews/v2_glazing_20261018/candidate_verification**.

Ledger before -> after: **0 / 1 / 48 / 25 / 65 / 67** ->
**0 / 1 / 48 / 25 / 65 / 67**; **requirements_changed: []**. No new region or
room status is claimed by this report.

Gates: clean comparison has **81 rows**, **69 tools suites / 980 tests PASS**,
**zero regressions, zero improvements**, no accepted regressions. The full build
remains intentionally **INCOMPLETE**. Reader has **zero NEW** fields. One reviewed optical/camera fixture row is
added to the spatial manifest; all previous records remain. Spatial preflight is clean; systemic
preflight has no new actionable findings, with the same 21 preexisting review
findings. Actual current-source execution results are recorded above.

Numbers management asked for: six fitted service lamps plus the matching native fixed-light family; the
observed native envelope,
source aperture and diagnostic ROI counts are given above.

Changes outside expected boundary, and why: existing shared instrument checks
now verify the native aperture. A camera-only review module joins the already
combined surface world; its source is explicitly bound. The sole spatial
manifest row registers those review fixtures, without a blanket baseline update.

Open findings: simplified source reflection, stretched red alley panels,
repeated arcade floor stock, heavy brick-edge relief, roof joints/openings to
inspect, other fixture families, warm cast,
missing region programs, broader V2 work and known shutdown warnings.

Decision needed from owner: **none** for the authorized incremental repair.

MERGE-CANDIDATE 19a20d07f3573e59453e468df24449a8b994ad95
