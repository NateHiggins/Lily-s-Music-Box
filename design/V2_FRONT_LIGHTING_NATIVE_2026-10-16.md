# Restored-front lighting native batch — 2026-10-16

Evidence class: **INERT**. Native authoring and diagnostic report. This is not
a runtime contract, ledger checkpoint, production installation or human acceptance.

The restored front has twenty spaces without explicit room lighting. The new
authoring batch covers all twenty with 35 fixtures and twenty physical switch
plates. Galleries and halls use the existing schoolhouse globe family; the
workroom and service returns use the existing caged drop family. The shallow
ground-floor store alcove receives its own small ceiling fixture.

**art/data/front_lighting_plan.json** is the reproducible fabrication plan.
**tools/plan_v2_front_lighting.py** reads the actual restored spaces and existing
floor junctions. It proposes 159 split, deduplicated conduit segments, 165 graph
vertices, 405 ceiling supports and 56 owner-specific wall bores. Opposing owners
of shared walls retain distinct proposed cuts. These bores are not installed.
All routes, including control drops, connect to their original floor junction.
There is no parallel electrical graph, circuit controller or save authority.

The existing junction casting, screws and vertical entries remain. A separately
bored replacement cover provides the front branch; its original solid cover
must be removed during installation. Every control has a hollow 40 mm surface
box, a conduit entry, wall saddles and its retained native plate/toggle stock.
The box rear seats against the wall face while its front seats the plate gasket.
Existing doorway and window apertures are excluded from switch bearings.

Horizontal conduit runs at 2.95 m. The native canopies seat at 2.92 m on separate
round adapters and supported junction boxes. This avoids passing supply stock
through an opal globe. Native ceiling stays carry the adapter instead of asking
the conduit to suspend the fixture. Pipes have actual interiors; corners and
tees enter bored boxes instead of overlapping closed cylinder ends. Unused spine
tips are capped. The cage rosette uses a stepped entry and a narrower pilot bore
so its suspension tube retains a metal wall.

The editable assembly is **art/blender/front_lighting_candidate.blend**. Its
build, independent saved-native inspection and cutaway renderer live in
**art/blender/front_lighting_candidate/**. This is an uninstalled authoring study,
separate from shipping fabrication scripts. Original fixture/switch sources
and catalogue images are reused by hash. No generated texture, runtime scene,
shipping asset, collision mask, fixture owner or saved setting has changed.

The assembly has 1,430 editable mesh parts. Its construction census passes
1,465 checks, and the saved-file inspection passes 2,159 checks, including the
three-height suspension probes. Twenty moulded plates receive a separate
weighted-normal refinement; exact geometry, UVs and transforms are compared
before and after saving/reopening. Five newly rendered views were inspected.
The packet lives at **art/renders/orison_v2/front_lighting_candidate_20261016/**.

The scratch exporter groups 1,132 fixed supply parts into eighteen floor/material
batches. Its preliminary geometry/UV roundtrip passed, but its subsequent tangent
gate failed. The latest failure is **F01_iron_neutral**, minimum tangent agreement
**0.9832377168006075**, against the unchanged **>0.999** requirement. Earlier
failures exposed flipped-V handedness and invalid normals on degenerate float32
triangles. None is waived. The preliminary supply export has 1,044,828 triangles
and is about 101 MB; small-hardware tessellation must also be reduced with fit
checks. The failed scratch GLB is not shipped or included as an accepted asset.
Its status, diagnostics and the earlier limited roundtrip are explicitly separated.
The native inventory identifies ceiling hangers as the first optimization target:
405 supports contain 508,680 triangles. Analytic lower-density stock with the same
bores/bearings should precede broad decimation of mechanically fitted parts.

## Review method and rejected attempts

Native checks cover closed positive stock, finite-area triangle charts, real
entry holes, surrounding metal, adapter seats, wall-box bearings and ceiling
contacts. They reopen the saved file and inspect transformed geometry. The first
saved-file probe had stale BMesh normals after transformation; updating normals
corrected the probe without changing the assembly or relaxing its limits.

The first drilled caps had collapsed Boolean UVs. The repair removes only
sub-nanometre duplicate edge endpoints and charts the resulting triangles with
a local origin, preserving the other source charts. Rejected mesh inspections
are retained. Rendered review then caught an over-wide bore erasing the upper
cage suspension even though each remaining stock was closed. The corrected
entry has explicit suspension-wall probes at three heights on every cage.
Those rejected images and their then-passing mesh checks remain diagnostic
evidence, never visual acceptance.

Cutaway views use source-owned floor/ceiling planes, approximate optical lights
and a separate close-up key light. The source-cover view includes the actual
retained native junction casting. These are fitting reviews, not screenshots
from the production game. Missing walls/apertures in the cutaway are explicit;
they do not demonstrate walking clearance, finished architecture or light mood.

## Verification scope

The source planner passes eight tests: complete room/control coverage,
deterministic generation without source mutation, real fixture clearances and
canopy seats, wall bearings outside apertures, connectivity to each floor
junction, split nonoverlapping stock, supported ceiling seats, and refusal of
an unreviewed room-program or ceiling-height change.

The canonical static board passes all 56 tools suites, with zero regressions
against the cached clean main baseline. Its sole nonpass gate is the genuinely
INCOMPLETE ledger. Blocker counts remain **0 / 1 / 48 / 25 / 65 / 67**. The reader
gate has zero NEW unread fields. The installed surface fingerprint remains
**da777f2876a1a2bec38d7eceee1478f64e6734a84990aaebe8369dad701b33c5**, 4,815 files.
No old runtime receipt was repinned or newly claimed as an execution of this
candidate. No Godot process was launched for this native authoring phase.

## Remaining installation batch

First repair the continuous surface charts/exported tangent basis and excessive
small-hardware tessellation without weakening the shared validator. Recheck actual
bores and bearing surfaces after optimization. Then export static supply stock
in floor/material batches with metre UVs and checked
tangents; retain separate fixture and toggle actors. Integrate the drilled native
variants and the explicit anchors into authoring projections and runtime data.
Remove only the six superseded solid covers. Add the bounded wall cuts after
checking actual shell, masonry, risers, doors and furniture. Preserve the original
floor junctions, circuit behavior, light budget, NPC and save owners.

Then perform a combined Godot installation review: ordinary walking routes,
actual pointer grabbing/motion/release on all twenty switches, circuit and light
budget behavior, real disk save/reconstruction, actual loaded maps/mips, and
day/night appearance. Renew affected runtime/surface proof by execution after
shipping inputs change. Human visual, navigation and whole-game acceptance
remain separate and unfinished. The broader V2 build remains active.

## Management report

REPORT - V2-FRONT-LIGHTING-NATIVE - 2026-10-16

Branch / verified source / origin-main / merge-base: local main /
**e95c35d29ebf892726544286b863d067d3158025** /
**e0b0dd293325a49c207785888112262a4990e474** / same origin-main.
Publication targets **codex/v2-direct-manipulation-checkpoint** only.

Worktree clean at end: no. Inherited imports, UIDs and review artifacts remain;
the canonical board records their complete path list. Only named native-authoring,
tool, workflow and review-packet paths belong to this checkpoint.

Protected paths: 17/17 unchanged against merge-base. Selector: V2, retaining
explicit V1 rollback. Fresh candidate checkout: clean. Static verification:
56/56 tools suites PASS, zero regressions/exemptions, zero design-document errors.
The verifier used **--no-godot**: no fresh Godot imports or runtime execution are
claimed. Its temporary checkout was removed after verification.

Ledger before/after this native batch: **0 / 1 / 48 / 25 / 65 / 67** unchanged;
no room or requirement is promoted by this report or these native diagnostics.
Compared with main's cached clean baseline, the complete branch has
**0 / 1 / 102 / 34 / 119 / 121** before and **0 / 1 / 48 / 25 / 65 / 67** after.
Those improvements come from earlier branch work, not the uninstalled lights.
The ledger remains INCOMPLETE, exit 2; spatial, systemic, period, reader, surface
and import gates pass. Complete per-gate exits and claims are in the archived
**candidate_verification.json**, **candidate_verification.md** and **board.json**.

Numbers: twenty rooms, 35 fixtures, twenty controls; 1,465 construction checks
and 2,159 independently reopened native checks pass. Five native views were
reviewed. No Godot suite was launched. Native fitting success does not supersede
the failed scratch tangent gate, its size findings or required runtime proof.

Changes outside the expected boundary: none. The source plan, offline native
recipes, editable assembly, planner/tests, workflow and diagnostic packet are
the authoring boundary. The follow-up adds only documentation/evidence files after
the verified source; it does not change production or test-source inputs.

Open findings: repair export charts/tangents; reduce the oversized support stock;
perform actual shell/door/furniture fit and integration; qualify controls,
save/reconstruction, loaded mipmaps and day/night appearance in Godot. Existing
whole-game work, seven shutdown Texture RID warnings and human acceptance remain.
Decision needed from owner: none; development continues autonomously.

This is an uninstalled authoring checkpoint; the scratch export is not a
production candidate and full V2 completion is not claimed.

MERGE-CANDIDATE e95c35d29ebf892726544286b863d067d3158025
