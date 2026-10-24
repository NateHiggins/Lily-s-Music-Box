# Hose cabinet rendering attribution — 2026-10-23

Evidence class: **INERT**. Controlled installed-world diagnostics, not runtime
qualification, human acceptance or a production optimization.

REPORT - hose cabinet rendering attribution - 2026-10-23

Branch **codex/v2-acoustic-topology**, parent **b0b65bca**, canonical checkout
**C:/PleaseRemainOnTheLine**. Original spatial-manifest and untracked street,
tent, traffic and art work remain preserved. Named staging only. No production
geometry, materials, light policy, interaction or save owner changed here.

The preceding installation route still had a 61.351 ms frame p95 and a
295.426 ms maximum. This batch isolates the owner's suspected close-up hose
rendering cost before another optimization. Five ordinary standing waypoints
reach the F02 cabinet. Its door is staged open; the camera then remains fixed.
Each treatment has twenty warmup frames and 120 measured presented frames,
with original views interleaved. Captures occur outside those samples. The
resolution is1280x720, VSync disabled, Forward+, on the same RTX4080 machine.
NPCs and other world presentation continue, so original repeats expose drift.

| Geometry control | Wall median ms | Render CPU median ms | Render GPU median ms | Median draw calls |
|---|---:|---:|---:|---:|
| Original A |41.585|24.455|14.600|45600|
| Cloth shadows off |42.453|24.526|15.073|45503|
| Original B |41.393|24.651|15.024|45610|
| Cloth hidden |42.412|24.807|15.093|45506|
| Original C |42.718|25.134|15.133|45615|
| Cabinet shadows off |42.590|25.099|15.076|44925.5|
| Original D |42.532|24.940|15.115|45397.5|
| Cabinet hidden |42.184|24.943|15.010|44828|
| Restored original E |43.353|25.260|15.342|45638|

The collected cloth branches contain43 mesh instances and135676 triangles,
including legacy/hidden draws; this is not a count of visible cloth draws.
All cabinet descendants include147 mesh instances. Hiding these groups does
not produce a clear frame-time improvement relative to original-repeat drift.
The scene submits roughly171 million primitives per frame across render passes.
That is not a count of unique world triangles. The expensive numerical hose
solver is absent from production, as verified in the preceding checkpoint.

| Light-shadow control | Wall median ms | Render CPU median ms | Render GPU median ms | Median draw calls |
|---|---:|---:|---:|---:|
| Original A |41.959|24.315|15.144|45605|
| Sixteen service shadows off |22.136|10.856|8.084|18842|
| Original B |41.790|24.239|14.765|43070|
| Other local shadows off |37.575|22.014|13.087|39987|
| Original C |39.188|22.624|13.746|40897|
| All local shadows off |21.776|10.510|7.581|17942|
| Original D |37.671|22.445|13.212|40899|
| Directional shadows off |35.368|20.659|12.438|32563|
| Restored original E |38.596|22.506|13.388|40906|

The service policy is conservative in **F02_LANDING**, retaining all sixteen
source-owned service practicals. Those shadows are the dominant measured
rendering cost in this view. Turning shadows off changes wall and door-edge
occlusion in the reviewed images; it is a rejected production treatment.
Other local lights retain their own source and electrical owners throughout.

Godot documents light and shadow distance controls separately in
[Light3D 4.7](https://docs.godotengine.org/en/4.7/classes/class_light3d.html#class-light3d-property-distance-fade-shadow).
The next control keeps the light-fade beginning at128m and tests service-shadow
distances8/12/16m with4m length. Wall medians are42.463/41.669/42.481ms against
originals41.630/42.211/42.352/41.794ms. Draw calls remain around45600: no measured
benefit. This does not establish an engine bug; per-phase effective settings
and camera distances were not recorded in that earlier control. A subsequent
whole-light-fade positive control records those values explicitly.

The whole-light control also shows no measurable benefit: medians at8/12/16m
are42.310/41.618/41.876ms; interleaved originals42.282/42.570/42.448/42.409ms.
Draw calls remain45569–45585. Effective properties are recorded after warmup:
fading enabled, begin/shadow distance8m, length4m; two sources are13.215/15.883m
from the camera, so this cannot simply be explained by every light lying inside
the12m endpoint. A minimal isolated engine/API control passes: mean sampled
luminance0.438051 →0 →0.438051 with a0.1m beginning/length and restored settings.
Its stderr is empty. Neither composed-world fade variant is installed.

The official4.7.1 source's
[RD light storage](https://github.com/godotengine/godot/blob/4.7.1-stable/servers/rendering/renderer_rd/storage_rd/light_storage.cpp)
applies distance fading while preparing light/shadow shader data. The inspected
scene/light-culler files did not contain the same distance-fade checks. This
suggests a distinction between fading visible contribution and avoiding shadow
generation; it does not establish the exact cause or an engine defect. Next
test an explicit, smooth distance/visibility control against original restores,
including active reflection cameras, and inspect caster submission if needed.
Do not infer a performance win from an advertised fade property alone.

Packet **art/reviews/v2_hose_render_20261023/** retains every raw frame,
CPU/GPU distribution, counter delta, image, original repeat, source archive
and wrapper receipt. Every completed control checks camera equality and
mechanism-state preservation. The walk proves only this five-waypoint approach;
the rendering perturbations are fixed-view diagnostics. Captions and suite_run
wrapper receipts do not grant schema-2 runtime_contract or human acceptance.
There is no shader/streaming/all-script attribution or V2-complete claim.

All four world controls completed through the long shared-lane wrapper with
five walked waypoints, zero failures and empty stderr. The minimal API control
completed through the serial wrapper with PASS and empty stderr. Original
executed scripts are archived separately as the adaptive fixture evolved.
Raw p50/p95/p99/max distributions and pipeline-counter deltas are in each
**analysis.json**, not just the medians summarized above. The geometry/light
controls each contain1080 measured frames; each fade control contains840.

Worktree clean at end: no; the original two bathroom-optics manifest records
and unrelated untracked assets remain. Two executed test-coordinate records
were registered separately, preserving those original records unstaged. The
affected spatial audit retains eight existing failing and45 reported references;
its tools test retains the same one failure among59 tests. No gate implementation
or baseline for unrelated failing production references was changed. The
preceding complete board remains101 PASS/eight FAIL/one INCOMPLETE, with its
explicit existing failures. It was not repeated for diagnostic-only source and
report additions. Ledger promotions: []; no clean merge-base verifier claim.
Protected17/17 and selector V2/V1 rollback are unchanged from the parent.

| Location / reproduction | Severity | Evidence | Repair / disposition | Verification |
|---|---|---|---|---|
| Close to the stored hose cabinet | High responsiveness | Interleaved geometry controls | Cabinet-specific geometry removal is unsupported as a frame-time fix | Nine fixed views and original restores |
| Public stair/service context retains sixteen shadowed practicals | High rendering cost | Service-shadow perturbation halves approximate wall median | Preserve present policy while evaluating an atmosphere-preserving treatment | Original/disabled/restored images and timings |
| Shadow-only distance setting yields no timing reduction | Diagnostic uncertainty | Three distances and four originals | Do not install an unmeasured optimization | Whole-light positive control records effective fields |

Released-nozzle support remains open. Inspection activates before releasing the
hand, so a release repair must preserve its static floating inspection pose.
Ordinary release should find a supported nozzle pose without changing coupling
or water facts and without an ongoing resting simulation. Full payout, actual
maintenance input, broader performance, bathroom/books/device/street/shops/avatar
work and complete area coverage remain in the started-work queue.

Decision needed from owner: none.

BLOCKED production performance repair and full qualification remain incomplete
