# Full-length hose and rack continuation — 2026-10-22

Evidence class: **INERT**. Candidate numerical, native and played diagnostics.
No new runtime contract, installed deployment or human acceptance is granted.

The owner authorized full **15.24 m / 50 ft deployment and controllable spray**.
The installed eight cabinets still have the existing ten folds and short leads.
The preceding player-contact/step repairs remain installed. This continuation
keeps the full-length work separate until its geometry and release cost qualify.

| Location / reproduction | Severity and evidence | Repair and verification |
|---|---|---|
| Held candidate fitting, repeated actual primary-click/mouse/second-click input | High: original directional solve stalls around 11.4 m; later runs expose roundoff and nearly taut failures. All original failures remain. | Source-bound native cap solve, rigid-pin joint fallback, Float64 intermediate positions, unchanged final Float32 checks, small swept input substeps and a material-arc starting guess. Three historical numerical inputs pass in **kernel_v23.log.receipt.json**. No original length, bend, support or aggregate tolerance was increased. |
| Held round fitting neck | High: repeated subtraction at large coordinates changes its relative offset. | Retain its configured local offsets instead of repeatedly deriving them from moved world points. Fitting transport can prepare without changing the skin, cancel, reject stale proposals and commit only after renewed native swept contact. Actual fixture checks cover all four paths. |
| Rightward payout, fitting aligned toward the supply | Numerical/input pass only. **right_payout_v4.log.receipt.json**, 280 mouse events; all 15.24 m retained, endpoint-span allowance 20 mm. | Actual primary click latches the native seat, mouse input extends the strand and the next click releases without snapping. Fixed necks, every interval, total length, bending and world sweeps pass. The fixture camera follows with player physics disabled; this is not a building travel or real nozzle test. |
| Deformed cloth at the outlet | High, **not repaired in this checkpoint**: native review finds **1,167** crossing triangle pairs without shared vertices. | Preserve failed native solid, images and report. The round section bends through itself despite passing the old centreline radius check. Next repair derives bend limits from actual loaded section dimensions and repeats the deformed-skin review. Numerical payout is not geometric acceptance. |
| Released full strand reaches a floor | High, **not ready for installation**. Final 120-step / one-second fixture release completes, but takes **4,926.467 ms** of solver work. | Original bounds and atomic rollback stay. Solver-step p50/p95/p99/max **27.386 / 123.643 / 151.219 / 233.679 ms**; 105 fallback projections. These are solver costs, not played frame times. |
| Rack carrier stock | Excess geometry: 15,790 triangles per finger. | New source-owned carrier has 4,526 triangles, retaining the machined eye. Both installed ten-fold stock positions pass 100 bearing samples, maximum gap 73.880 µm. Proposed thirteen-carrier rack passes 65 bearings, 65 lowered negatives, shaft/arm/nut crossing checks and eight case bearings. Its stretched shaft is freshly recharted. |
| Proposed rack appearance | Native and loaded fixture pass, not installed acceptance. | Native renders reviewed. **rack_surface_v4.log.receipt.json** verifies loaded metre UVs, tangent derivatives, registered PBR and mip chains. Production voxel views and separately named neutral-light controls are retained. No glTF was edited by hand. |

The default dense and sparse mass-model controls both pass again. Every
non-timing field, including coordinates, energies, constraints and iteration
counts, is identical to the earlier controls; only **profile_usec** is excluded.
See **default_controls_v2.json**. New math is opt-in; no mechanical, NPC,
inventory, maintenance, save or case owner was replaced.

The successful aligned payout has input-handler p50/p95/p99/max costs of
**3.851 / 7.051 / 7.746 / 10.745 ms**, with solver costs
**2.491 / 3.754 / 6.334 / 6.755 ms**. These measurements include the fixture's
native swept checks; they are neither whole-world frame distributions nor an
installed nozzle qualification. Reverse-pull failures remain preserved.

The original joint warm-start and predicted-bend experiments, equal-weight
relaxation, altered ribbon frames, coarse guide and every failed input attempt
remain beside their executed sources. A JSON precision assertion initially
required bit equality after decimal serialization; its original failure is
retained. The replacement independently bounds that serialization error at
**1e-12 m** for spans and **1e-10** for inverse weights. This changes no physical
acceptance tolerance. One batch accidentally wrote to **v3_hose_follower_20261021**;
those original paths and receipts are retained, not rewritten.

## Played carrier-only comparison

**carrier_profile_v1.log.receipt.json**: 301.53 seconds, 51 original waypoints,
zero failures or script errors. Same world/settings; original, reduced carrier,
original restored. All eight player-door contact helpers stay enabled. Both
visual and exact native carrier collision meshes change together; no collision
mask, door, obstruction exemption or interaction owner changes.

Movement and turning frame distributions, including inspection approaches:

| Stock | Frames | p50 ms | p95 ms | p99 ms | Maximum ms | Frames >100 ms |
|---|---:|---:|---:|---:|---:|---:|
| Original A | 879 | 41.256 | 86.515 | 135.955 | 146.890 | 41 |
| Reduced B | 850 | 44.057 | 94.489 | 125.898 | 136.070 | 43 |
| Restored A | 826 | 46.450 | 78.797 | 136.759 | 151.782 | 39 |

The replacement removes **901,120** installed triangles. p99 improves, but p95
and the count above 100 ms worsen. It is not a universal stutter improvement.
GPU p95 is **22.183 / 22.619 / 22.177 ms**; physics p95 is
**12.841 / 12.718 / 12.827 ms**. Pipeline draw/specialization increments are
**14/86, 5/8, 0/0** respectively, so shader warmup is an explicit confound.
The carrier remains a candidate. Raw frame, process, physics, render, pipeline,
residency and phase samples remain in **carrier_profile_v1/frames.json**.
The original door sweep still detects the walked player; all three inspection
programmes exercise actual targeting, grabbing, motion, release and camera exit.

## Continuation and report

Next: repair the round outlet's bend protection and posed skin, reduce long
release work, qualify both fitting carriers, install the supported rack and
actual payout/return, then connect continuous supply/valve/nozzle spray and
world/disk reconstruction. Self-contact is not implemented. Do not publish the
full model on the strength of the isolated aligned-input pass.

REPORT - V2-HOSE-FOLLOWER-STUDY - 2026-10-22

Branch / pre-write HEAD / origin/main / merge-base:
**codex/v2-acoustic-topology / d98f48ce / 21f0b1fc / 21f0b1fc**.
Shared worktree remains dirty; unrelated contributor files and line-ending-only
import changes are retained. Only named owned paths are eligible for staging.
The complete clean main baseline remains the **clean_main_baseline/board.json**
under the prior player-contact diagnostic; historical dirty boards are not used
as clean merge-base validation. Initial gate output is diagnostic, not renewed
runtime qualification. Existing expired surface/route qualification remains open.
Protected **17/17** match origin/main after LF normalization; selector stays V2
with explicit V1 rollback. The complete initial board has **107 PASS, 2 FAIL,
1 INCOMPLETE** across 110 gates. Its completeness tools suite reports three
assertions; the retained direct rerun reports two qualification-dependent
assertions. No assertions were disabled. The initial clean-main comparison has
77 regression entries and 61 changed requirement rows, including earlier branch
work and expired evidence; this is not a clean merge candidate. Ledger scope
blockers are **0/26/56/1/73/75** on clean main and
**7/42/110/8/134/136** in the initial working scan.

The corrected scoped scan has **zero spatial drift** and **zero NEW reader
fields** (1,109 historical unread fields). One isolated rack-camera coordinate
was registered. A Windows encoding failure in the first manifest write is
preserved with its failed scoped board; the exact unchanged HEAD manifest was
restored before appending that one record and rerunning the scan. Original
records remain identical. No qualification packet was edited or repinned.
Numbers and original test-written receipts are retained with the review.
Changes outside the candidate boundary: none intended; no owner decision needed.

BLOCKED — candidate outlet self-intersections, release cost, installed fittings,
full world/save/spray qualification and broader V2 coverage remain unfinished.
