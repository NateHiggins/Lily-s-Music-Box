# Curtain motion: measured rebuild and native skin replacement

Evidence class: **INERT**. Scoped diagnostic and measured repair; no runtime
qualification, human acceptance or V2 completion. Performance findings apply
only to the measured route.

| Location | Reproduction | Severity | Evidence | Repair | Verification |
|---|---|---|---|---|---|
| 4B shower curtain | Grab cloth, move through the rail, click to release | High responsiveness defect | Valid baseline v2: six gestures, all144 movement callbacks above100ms | Native97-cloth/19-ring bone skin and36 reused selection boxes replace per-event mesh/normals/tangents/trimesh reconstruction | Offline25pose/50draw skin checks pass; 43 focused Godot checks and matched occupied-world route pass |
| Gathered cloth targeting | Aim at folds near a travel stop | Medium potential candidate defect | Offline proxy coverage misses cloth with the first narrow proxy draft | Increase selection envelope to cover actual gathered folds; no environment collision is added | All62,304 cloth vertices and face centres covered at each of25 sampled travel positions; actual cloth ray targeting and grab/move/release pass |
| Original profiling cadence | Inject motion every physics tick during long callbacks | Diagnostic defect | Physics catchup groups multiple events before a rendered frame | Preserve v1 and run v2 with one motion per process frame | v2 route/input/frames all pass; do not treat v1 frame tails as normal accumulated mouse input |

The valid occupied-world baseline uses1280x720,75-degree FOV,MSAA8x,TAA,
VSync off and the existing clock fixed at20:00 on November10,1928. Room lights
are on, network/simulation overrides are off. Three opening/closing pairs
use actual player ray targeting, primary click acquisition, mouse displacement
and next-click release. Each gesture has24 motion events; baseline phases have25 rendered
intervals, and after phases have25–26. Median movement intervals range169.024–185.350ms; the worst interval
is325.457ms. Before/after idle controls are separate. These are frame and
callback durations, not OS-to-photon latency.

The original v1 run passed interaction checks but its physics cadence grouped
input events during catchup. It remains archived. The v2 wrapper completes in
219.77s, with seven retained Texture-RID teardown warnings. No script errors or
failed mandatory test-written route/input/frames result occur. The wrapper is
suite_run evidence, not runtime_contract.

The native candidate preserves all17 expanded triangle position/UV streams.
Indexed deduplication changes one nickel vertex and normals/tangents have tiny
float roundoff; do not claim every indexed array is byte-exact. Original exported
tangent derivative checks pass. The GLB grows by1,532,184bytes; this is not a
memory or rendering speed improvement claim. No resting cloth solver, new light,
reflection viewport, water authority, save epoch or case state is introduced.

The original procedural helper remains as a fallback for non-skinned construction.
The installed asset must use the new skin path. Fixed stock retains batching;
only the already-two-draw skin avoids merge_static, which would destroy joint
bindings. Save travel remains0..1.78m and the existing280px bounded gesture remains.

Original run roots: curtain_baseline_v2,curtain_skin_v1 and
curtain_after_v1 under C:/ov/reports/v2integration24. The committed packet retains all original cadence diagnostics and both world
traces. Full source-bound route/save/surface qualification is still separate.

## Matched actual-world result

The after wrapper completed191.95s with exit0. Both test-written route/input/frames
results have no failures; six actual acquisition/motion/release sequences and two
standing walking waypoints pass. The profiling fixture is byte-exact to the valid
baseline. Clock, settings, FOV, ordered phases and waypoint targets match.
Seven pre-existing Texture-RID teardown warnings remain in both runs.

| Gesture | Before p50 / p95 / p99 / max, ms | After p50 / p95 / p99 / max, ms |
|---|---|---|
| curtain_open_1 | 180.920 / 210.712 / 291.747 / 315.831 | 17.392 / 21.003 / 31.774 / 35.254 |
| curtain_close_1 | 179.827 / 195.908 / 274.394 / 299.165 | 27.223 / 43.933 / 44.809 / 45.011 |
| curtain_open_2 | 174.044 / 188.964 / 280.797 / 309.761 | 21.015 / 34.778 / 38.578 / 38.910 |
| curtain_close_2 | 178.860 / 197.142 / 279.878 / 305.383 | 22.515 / 29.693 / 37.859 / 40.390 |
| curtain_open_3 | 169.024 / 191.557 / 293.970 / 325.457 | 19.231 / 30.996 / 38.265 / 40.004 |
| curtain_close_3 | 185.350 / 245.315 / 301.116 / 318.007 | 22.383 / 32.754 / 45.994 / 50.016 |

Movement callbacks have median138.050–147.362ms before versus0.233–0.272ms
after, with worst199.384→0.512ms across144 events per run. The150 before gesture
intervals include138 above100ms and142 above50ms;151 after intervals include
zero above100ms and one above50ms (50.016ms). The before-idle control median/p95
stays21.519/27.154→21.324/27.069ms. The after-idle control improves in this pair,
but no general idle or whole-V2 rendering improvement is established.

The first open median main render CPU/GPU is8.478/10.829→7.771/5.284ms;
physics3.741→4.091ms, aggregate process173.766→21.050ms. Mirror CPU/GPU readings
are16.393/7.079→17.352/6.424ms and can lag. These overlapping engine measurements
must not be summed or labelled exclusive script cost. The controller's constrained
writer includes script, mesh construction and collision-resource work; it is not
a pure physics or pure rendering timer. The removed synchronous rebuild is the
measured responsive-motion repair, not a claim that every subsystem got faster.

Passage residency is DORMANT in gesture phases and pipeline counters do not
change there. That bounds passage streaming and observed compilation during this
sample; it does not prove zero asset loading everywhere. Approach spikes remain:
maximum271.595→268.428ms, including after intervals coincident with draw/surface/
specialization pipeline counter increases. Keep these separate from the curtain
repair. Asset-loading and exclusive script costs are not independently isolated.

The three focused native Godot poses and the final occupied bathroom image were
viewed. Cloth retains its woven material and rounded rail travel; a dense gathered
strip leaves access to the tray. Existing room illumination can produce a strong
lamp highlight. This is scoped visual review, not acceptance of every bathroom.

The43-check focused bench retains both native-bound draws and all116 bearings,
36 reusable selection proxies, nondegenerate UVs, custom PBR maps and six loaded
complete mip chains. Four actual grab cases cover0.85/1.55m and55/85-degree FOV.
Fresh fixtures reconstruct exact released travel0,0.89,1.78 through the existing
mechanism validator. This is reconstruction diagnostics, not a disk-save cohort
runtime contract. Every motion reuses the original imported meshes.

Packet: **art/reviews/v2_curtain_skin_20261024/archive.json**. Historical offline
scripts preserve their original external execution paths. Original native assets
remain in commit4ec06d55 with their raw hashes in the archived original manifest.
The analysis tool rejects incomplete/misordered gestures, invalid timing, failed
walking traces and mismatched comparison settings. Its negative controls are
archived. No original failure, runner receipt or test-written result was rewritten.

## Developer report

REPORT - V2-CURTAIN-SKIN - 2026-10-24

Branch / HEAD / recorded origin/main / merge-base:
**codex/v2-main-integration-20261024 / 941a9673 / 55e60195 / 5485fbb4**
at diagnostic launch. Worktree clean at end: **no**; named curtain changes and
unrelated generated untracked UID files remain. Only owned named paths will be
staged. Canonical shared manifest and traffic hashes are preserved.
Protected17/17 and selectorV2 pass the independent check before the checkpoint;
no protected owner is edited. Ledger240 requirements retain4 ABSENT,122 PROGRAMMED,
86 SPATIALLY_PROVEN,27 RUNTIME_PROVEN and1 HUMAN_ACCEPTED; requirements_changed
is empty. This inert report grants no ledger status.

Gates: final static board is **105 PASS / 6 FAIL / 1 INCOMPLETE**, archived in the
packet. It has no regressions against the preceding complete calendar board,
and the catalogue-persistence test improves to PASS. Against the complete clean
5485 main board, the open surface qualification has defects2→3 because the
old contract does not bind the current surface test. Reader has zero NEW fields.
No merge-ready or full-candidate verification is claimed; recorded origin/main
has advanced to55e60195 and still needs a separate integration review. The first
board's only new failures are its unreviewed spatial records and associated unit
test; all other defect/count fields match the preceding calendar board. Four
owned records were reviewed and appended without altering any of the10,713 prior
records. Focused spatial is clean with eight pre-existing reported fixtures;
59 spatial unit tests pass. The independently committed catalogue source repair
3d23d033 also passes its existing persistence test. No threshold, failing owner,
save contract or runtime qualification is rebased to green.

Godot: import1/import2/bench complete0 with empty stderr; the bench prints
**CURTAIN GESTURE BENCH: PASS checks=43 failures=[]**. Both matched world wrapper
receipts complete0; test-written route/input/frames have no failures. Exact
LogPaths and receipts are archived. These are diagnostic suite_run records,
not schema-2 runtime_contract receipts.

Changes outside the physical motion boundary: portable analysis tool; four
reviewed spatial records; hash-stable source attributes; this inert report and
retained packet. Original non-skinned construction has its verbatim helper
fallback. Tap, water, inventory, NPC, save and case authorities are preserved.
Open findings: approach/first-view pipeline spikes; mirror costs; complete-source
route/save/surface renewal; all remaining requested V2 feature closure and human
review. No V2 completion, merge-ready verdict or general FPS claim.
Decision needed from owner: **none**.
