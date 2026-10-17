# Front-lighting export repair and support optimization — 2026-10-17 UTC

Evidence class: **INERT**. Native authoring/export report, not a runtime contract,
production installation, ledger checkpoint or human acceptance.

The restored-front lighting candidate now exports with a valid tangent basis.
The existing shared validator remains unchanged, including its **>0.999**
agreement requirement. The supply passes at **0.9999999580654724** minimum;
the two drilled fixture variants pass at **0.9999999569869357** minimum.

The native batch still covers twenty rooms, 35 fixtures and twenty controls.
It remains uninstalled. No game scene, runtime script, data record, shipped
texture, saved setting, circuit or nonvisual owner changes in this checkpoint.

## Geometry and chart changes

Each ceiling hanger now has 344 triangles instead of 1,256. Its annular band
uses an explicit 24-sided profile with outer rim chamfers, a twelve-sided rod
and a full 45 x 45 x 6 mm ceiling seat. The bore retains its 12.7 mm nominal
radius and clearance around the 12.5 mm conduit. Both orientations pass 102
prototype checks, including radial probes at vertices and between vertices.

Across 405 supports, the change removes 369,360 triangles: **508,680 → 139,320**,
about 72.6% less support geometry. The whole editable assembly drops from
**1,945,522 → 1,576,162** triangles. Existing lamp/switch geometry and all source
positions remain. Construction passes 1,465 checks; reopened native inspection
passes 2,162 checks. Five new fitting views were rendered and inspected.

Nonanalytic fixed stock uses the established precision-safe metre chart builder.
Analytic support bands retain cylindrical charts and planar annular caps.
The exporter derives tangent and bitangent guides against its actual float32
positions and flipped-V charts. Guide attributes preserve seams during vertex
deduplication and are removed inside the Blender exporter. No finished glTF
is hand-edited. Final face geometry supplies invalid corner-normal corrections
where float32 cancellation left a zero normal or one outside its face hemisphere;
valid smoothed normals remain. The original validator then checks the result.

The supply stores eighteen floor/material batches plus two shared support
meshes. All 405 support placements survive export/reimport, giving 423 posed
mesh nodes but only twenty unique meshes. It is **73,390,964 bytes**, compared
with the earlier **101,199,780-byte** preliminary export. File-size reduction
is not a measured FPS or GPU-memory claim. The game loader must turn support
nodes into floor-scoped MultiMesh groups before production acceptance.

The separate fixture library contains eight parts across two drilled variants,
40,878 triangles, and is **6,006,800 bytes**. Its generated family data retains
the original catalogue aliases, finish settings, component roles and the
35 source fixture identities. Runtime actors still need to be connected to it.

## Evidence and reproduction

The packet is **art/renders/orison_v2/front_lighting_export_20261017/**. It keeps
both exported libraries, the generated fixture family, actual export/reimport
checks, native/prototype checks, five reviewed images and failed diagnostic logs.
Earlier rejected exports remain documented by the previous native report.

Run **prototype_stock.py**, then **build.py**, **refine_normals.py** and
**inspect_native.py** in **art/blender/front_lighting_candidate/**. Run
**export_candidate.py** for supply, and again with
**FRONT_LIGHTING_EXPORT_KIND=fixtures** for the fixture library. **review.py**
renders the native cutaway. These offline scripts do not install assets.
The normalized recipe/native hashes and binary hashes are recorded separately.

One normal-refinement attempt could not replace its native file; it reported
a save error. The unchanged-input retry completed, saved/reopened the file,
and passed exact geometry/UV identity checks. That failed log is retained.
Other diagnostics exposed wrong face normals on thin float32 triangles and
an export-metadata reference to objects already removed for the roundtrip.
The corrected run snapshots plain placement records before removing objects.

## Remaining integration

Use the shared support meshes as actual floor-scoped MultiMesh instances,
retaining their fitted transforms and physical geometry. Integrate the fixture
family, source-owned anchors and controls, bounded wall penetrations and
source-cover replacements together. Review their complete retained shell,
risers, door/furniture clearance and wall-entry finish before acceptance.

Then verify actual pointer grabbing/motion/release on all controls, circuit/light
budget behavior, disk save/reconstruction, loaded PBR/mip chains and day/night
appearance/performance in Godot. Renew changed runtime proof by execution.
The installed surface fingerprint is still **4,815 files**, hash
**da777f2876a1a2bec38d7eceee1478f64e6734a84990aaebe8369dad701b33c5**;
old contracts are unchanged/current, not executions of this candidate.
Whole-game V2 completion and human acceptance remain unfinished.

## Management report

REPORT - V2-FRONT-LIGHTING-EXPORT - 2026-10-17 UTC

Branch / verified source / origin-main / merge-base: local main /
**43923a6eefb1aa7d46fb8fc729a9282a6137365a** /
**e0b0dd293325a49c207785888112262a4990e474** / same origin-main.
Publication target: **codex/v2-direct-manipulation-checkpoint** only.

Worktree clean at end: no. Inherited imports, UIDs and review artifacts remain
outside named commits; the prior canonical board records their full path list.
The candidate verification itself used a clean fresh checkout.

Protected 17/17: unchanged versus merge-base. Selector: V2, explicit V1 rollback
retained. Fresh static verification: 56/56 tools suites PASS, no regressions,
no exemptions and zero design-document errors. The verifier used **--no-godot**;
it does not establish fresh imports, runtime execution or human acceptance.

Ledger before/after this native batch: **0 / 1 / 48 / 25 / 65 / 67**, unchanged.
No requirement is promoted by these offline checks. Main's cached clean baseline
has **0 / 1 / 102 / 34 / 119 / 121**; the branch improvement to the current counts
comes from earlier runtime/geometry work. Ledger remains INCOMPLETE, exit 2.
Surface/import, spatial, systemic, period and reader gates pass. Per-gate exits
are recorded in **candidate_verification.json** and its embedded candidate board.

Numbers: 102 support-prototype checks, 1,465 construction checks, 2,162 saved-native
checks; twenty unique supply meshes with all 423 poses retained, and eight fixture
meshes. Both shared tangent validations and all export/reimport checks pass.
Five native views reviewed. Zero Godot launches in this phase.

Changes outside the expected boundary: none. Native recipes/source, qualified
offline exports and their evidence are the boundary. The follow-up contains
only documentation and verification evidence after the verified source commit.

Open findings: production integration, full retained-context and wall-entry fit,
support MultiMesh conversion, controls/circuits, disk reconstruction, loaded
mipmaps and actual day/night/performance review. Whole-game structural/runtime,
V1 retirement, seven shutdown Texture RID warnings and human acceptance remain.
Decision needed from owner: none; development continues autonomously.

MERGE-CANDIDATE 43923a6eefb1aa7d46fb8fc729a9282a6137365a
