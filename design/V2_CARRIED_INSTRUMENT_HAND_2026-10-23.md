# V2 carried instrument hand controls — 2026-10-23

Evidence class: **INERT**. Scoped implementation and diagnostic report;
not whole-V2 acceptance or a management certificate.

## Issue log

| Location | Reproduction / severity | Evidence | Repair | Verification |
|---|---|---|---|---|
| Carried service set | Visible native controls only respond to shortcuts; high interaction debt | **2774d4b4** carrier input | Pick the actual movable parts in the held pass through the existing player hand | **world_v2/carried_controls_runtime_contract.json**, 71 checks |
| Feed shaft | Broad name search collects both pivots and material meshes; medium, doubled motion and overlapping targets | Retained **bench_v3-v5** second-wheel failures | Bind the two actual wheel pivots explicitly; exclude mesh children from gear drivers | Both separate wheel targets and physical input pass in **bench_v6-v7** and composed run |
| Review harness | E/warp observations read before queued input settles; diagnostic failure | **bench_v1-v2** | Allow actual input and physics frames to settle before observing | Later original runs retained alongside passes |
| Incoming slip | Explicit shortcut recipe in paper; low grammar defect | Prior LINE REQUEST body | Opaque waiting-line copy; original call owner unchanged | Source repair; actual pending-call answer not yet qualified |

All review paths below are under **art/reviews/v2_device_hand_20261023/**.
Original failures are retained. One early fixture shutdown also reported four
ObjectDB instances / two resources; later fixtures and the composed run do
not repeat that error. Full-world shutdown retains the prior seven-texture
RID warning; no whole-world clean-shutdown claim.

## Physical UI behavior

E raises the readable paper and instrument without entering inspection or
stopping ordinary movement. With the set raised and the hand free, Space
explicitly enters the carried mechanism view. The world eye stays at its
current position and the pointer becomes free. Space or Escape restores
ordinary looking; E collapses the instrument and exits its inspection. An
existing world-object grab retains priority for Space inspection.

Primary click takes the specific lamp lever, radio lever, service cover,
focus wheel or either feed wheel. Mouse displacement moves it within its
constraint; the next click releases without an endpoint snap. The cover and
levers retain intermediate geometry. The focus wheel adjusts the actual
reading distance. Feed-wheel movement reviews pages of the existing physical
copy, drives the common platen shaft and never creates another received
report. Merely grabbing a feed wheel does not interrupt printing.

Lamp contacts call the original player's lamp-power setter; radio contacts
call the existing carried radio owner and retain printer power gating. A
moving lever cannot be overwritten by its own indicator update. Unrelated
jewel changes no longer reanimate stationary switches. Seating the live radio
contact can call the existing service-round answer method when a call waits;
that path still needs actual pending-call qualification. Keyboard equivalents
remain, including the existing report-history shortcuts; this checkpoint does
not claim every paper-history operation has a separate physical control.

The private render World3D has exact fixed-stock triangle occluders and moving
part areas built once. The free-cursor ray uses the texture's actual viewport
mapping, including resize and reading distance. It is the same target provider
for hover and acquire. The shared constrained hand supplies ownership, motion,
limits, release and reticle feedback. No second drag controller or indicator
scan exists. No playable-world collision, environment sweep or new surface is
added. Previous imported UV/PBR/mip evidence remains scoped to the unchanged
native mesh/material assets; all 1,380 texture sidecars still pass policy.

The shared hand accepts an explicit carried-view camera for reach and gesture
projection, with an owner-supplied context validity check. Ordinary world/free
stock keeps its existing camera and physical collision rules. Cancellation,
protected calls, owner loss and leaving the carried inspection release the
same grip. Changed-world events use the player's real world position rather
than coordinates from the isolated held pass.

## Measurements

Same route/settings as **profile_ui_v2/**: 300 physics ticks per phase, actual
W/S and turning, 1280x720 Forward+, uncapped, VSync off. Screenshots are outside
samples. Exclude the first partial wall sample per phase. Raw samples and
**performance_comparison.json** retain distributions, spikes and renderer /
physics monitors. These monitors overlap and lag; asset loading and streaming
are not independently isolated. This is an initialized world, not a cleared
driver cache. One pair does not establish the cause of wall-time differences.

| Phase | Before p50 / p95 / p99 / max ms | After p50 / p95 / p99 / max ms |
|---|---|---|
| First report | 20.868 / 32.208 / 39.697 / 322.443 | 21.550 / 31.646 / 35.738 / 282.589 |
| Steady print | 19.758 / 26.460 / 29.199 / 36.181 | 21.228 / 27.183 / 29.949 / 37.650 |
| Raised idle | 19.922 / 26.093 / 27.525 / 28.565 | 20.599 / 26.757 / 28.129 / 32.204 |
| Lowered | 19.647 / 26.392 / 28.916 / 38.912 | 21.578 / 28.163 / 30.188 / 36.260 |

Raised-idle physics median is 3.249 -> 3.247 ms; held renderer CPU median
0.109 -> 0.120 ms and GPU median 0.075 -> 0.073 ms. The added interaction has
no observed large steady-state spike in this route, but wall medians/tails are
slightly worse. This is an interaction checkpoint, not a performance win. The
first-use reflection hitch remains and the previously rejected warmup is not
installed. Broader routes, cell streaming and shader capture need continued work.

The final **world_v2/** run additionally checks actual next-page selection,
no reprinting and unchanged local child-mesh basis for both feed wheels. Its
71-check contract supersedes the earlier 67-check test-source binding in
**world_v1/**. Both raw profile runs remain. The second run repeats the same
route; **performance_comparison.json** records it separately, without replacing
the first after-run or trimming its remaining first-use hitch. Tools tests
finished before the second timed route began.

## Verification and report

REPORT - carried-instrument-hand - 2026-10-23

Starting **2774d4b4**, branch **codex/v2-acoustic-topology**. Named paths only;
unrelated spatial manifest and street/tent/traffic work preserved. All 17
protected paths compare unchanged against the starting checkpoint. Selector V2
and its explicit V1 rollback remain unchanged.

- **world_v2/carried_controls_runtime_contract.json**: test-written schema 2,
  71 checks, specific parts, real click/motion/release, partial travel, four
  stops, circuit authority and inspection interruption pass.
- **world_v2/runtime_contract.json**: separate existing listener / deployment
  contract, 24 checks and two grille grabs pass. Does not expand listener coverage.
- **world_v2.log.receipt.json**: wrapper completion only, not runtime proof.
- **printer_regression.log.receipt.json**: production printer diagnostic, 21 checks pass.
- **world_hand_regression.log.receipt.json**: actual shared-hand diagnostic,
  116 door, fixture and obstruction checks pass.
- **book_hand_regression.log.receipt.json**: 89 stored-slot, pickup and fixed
  inspection checks pass; not full book editorial or surface acceptance.

Static follow-up: **gates/board.json**, reader still 33 existing NEW street/tent
findings; carriers and systemic pass. Spatial still has eight failing findings.
The 17 reported findings include the preceding checkpoint's rejected warmup
fixture coordinate and line-shifted historical profile fixtures; none is a new
production device coordinate. The unrelated manifest is not rebaselined.
All 98 tools suites ran 1,194 tests in **tool_tests/board.json**. Five existing
failures remain across four suites: interaction implementor census, prompt
census, spatial live-check and completeness live smoke (two failures). They
have the same failure counts as the preceding full board. The previously stale
front-trim tools suite now passes all five tests. See **tools_comparison.json**;
no blanket baseline update or green-board claim.

Remaining: real pending-call hand answering, saved device intermediate states,
physical report-history selection, subjective handling/audio acceptance,
reflection stutter and broader V2 repairs/coverage. No completeness promotion.
