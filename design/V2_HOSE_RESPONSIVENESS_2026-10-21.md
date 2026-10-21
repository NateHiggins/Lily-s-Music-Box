# Fire cabinet responsiveness and hose density — 2026-10-21

Evidence class: **INERT**. Diagnostic measurements and repair record, not a
runtime-contract receipt, human appearance acceptance or V2 completion grant.

The installed cabinet has two independent costs: expensive player step-eligibility
queries near detailed fittings, and unnecessarily dense native cloth stock. The
repair changes the V2 eligibility query and rebuilds the existing short hose and
fold stocks through their Blender recipes. Full 15.24 m deployment and controllable
water spray are explicitly authorized by the owner and remain separate unfinished
work at this checkpoint. The current installed folds are not a deployable 50-foot
hose. The uninstalled older full-length prototype is also not ready to install:
its documented release programme took 24.871 seconds to advance 0.2 seconds.

| Location / reproduction | Severity / evidence | Repair / verification |
|---|---|---|
| Stair fire cabinets; approach, turn, climb and descend near fittings | High: full-height step eligibility tests encounter detailed stock above the legal 300 mm step band. Earlier paired played diagnostics recorded step-query maxima of 216.502 / 0.082 / 200.679 ms for original / lower cap / restored. | V2 uses the capsule's actual lower hemisphere for initial eligibility. The full capsule still checks lift/headroom and raised travel; final slide, masks and obstructions remain. Shipping fixture and played-route results below. |
| Both installed short hose sections | Medium: each native stock contained 49,408 triangles for only 300 or 420 mm of hose. | 13,504 triangles each, a 72.7% reduction. Keep longitudinal rings and 64-sided mouths; reduce the middle circumference to 16. Preserve the open bore using a conservative circumscribed body and native convex-ring loft. |
| Continuous folded stock and transitions | Medium: the twelve-mesh library contained 169,216 triangles, repeated across eight cabinets. | 46,336 triangles, a 72.6% reduction. Reduce curved longitudinal sampling from 64 to 16 while retaining 64-sided mouths, support datums and the original straight sections. |
| Initial reduced short-stock builds | Diagnostic: two original attempts pinched the open bore at transition facets. | Preserve both failed sources/logs. Current authoring checks 129 bore rays, 16 mouth-bearing rays, manifold positive volume, native metric UVs and exported tangent derivatives. No cap fills the bore. |
| Paired step fixture with a reused player | Diagnostic: a 1.980136 mm first-step trajectory mismatch also reproduces with original versus original. | Preserve both failures. Fresh controllers per leg remove carried contact history; the unchanged 1 mm criterion and identical floor flags pass. Shipping suite adds crouch, small-radius and tilted-shape fallbacks. |

The lower-cap helper has no physical layer and an idle mask of zero. Only its
synchronous query temporarily reads the player's collision mask. An actual rigid
body falls through the inert query volume onto the real floor; a deliberately
physical negative control catches that same body, and restoring zero masks lets
it fall. The helper does not replace cabinet collision, exclude obstructions or
change V1's default controller path.

Native rendered review retains rounded cloth, metre-scale weave, visible open
ports and rack bearing. The slight conservative body enlargement is recorded:
maximum outer radius 21.4114 mm versus the unchanged 21 mm mouth radius. This
preserves the nominal bore between the reduced polygon's corners. Loaded stock
checks pass UV derivatives, deformed normals/tangent handedness, normal mapping
and actual mip chains. One-pose stock timings are diagnostics, not whole-frame
improvement: the new outlet pose costs 3.937 ms in its focused run; its original
control cost 6.844 ms in a separate run.

Focused windowed checks preserve the original mechanical programme: actual door,
tag, union, loose stock and washer grabbing; mouse motion; second-click release;
inspection; obstruction protection; maintenance and save validation. Stock, fold,
rack and all 54 shared targeting assertions pass with zero failures. All twelve
paired shipping movement fixtures and four inert-query checks pass. These lane
receipts are **suite_run** diagnostics, not schema-2 runtime qualification.

## Performance controls and rejected candidates

The shipping 1280×720, uncapped, VSync-off A/B/A repeats the same 51 actual
movement waypoints and three installed inspection programmes. All pass, with
zero script errors in the original 297.54-second wrapper receipt. Preparation,
fixture restoration and synchronous image captures are outside measured windows.
All three legs use the simplified meshes, so this isolates the step-query change
and does not claim a causal frame saving from triangle reduction.

| Movement frames | Original A | Lower cap B | Restored A |
|---|---:|---:|---:|
| Samples | 780 | 774 | 782 |
| p50 ms | 47.566 | 46.633 | 47.248 |
| p95 ms | 77.119 | 72.552 | 72.287 |
| p99 ms | 217.335 | 196.586 | 201.903 |
| Maximum ms | 293.656 | 224.247 | 313.334 |
| Frames over 100 ms | 28 | 28 | 33 |
| Frames over 250 ms | 1 | 0 | 1 |

The uncapped per-tick recorder retains every cycle, avoiding the old 6,000-row
ring's truncation. Step maxima are **211.168 / 0.084 / 207.849 ms**; slide maxima
remain **28.065 / 28.108 / 27.763 ms**. Prompt maxima are 0.308 / 0.196 / 0.272 ms.
Inspection p99 is 97.935 / 107.032 / 108.579 ms; its maximum is 163.516 / 156.963 /
166.556 ms. This repair removes a demonstrated long eligibility stall, but neither
the inspection distribution nor movement p99 establishes universally smooth
frames. Expensive slide work and physics catch-up remain open. No hardware
input-to-photon latency measurement is claimed.

The separate continuous arrival / furnished apartment / cell-transition /
physical counter / repair route also completes **94 waypoints, zero failures**
in its original 267.13-second wrapper run. Its 3,467 measured frames have p50 /
p95 / p99 / maximum **30.707 / 65.738 / 102.600 / 253.636 ms**, 37 frames over
100 ms and one over 250 ms. The previous frozen-source route had 3,540 frames
at 30.592 / 64.439 / 108.701 / 261.564 ms. These are ordered separate runs,
not an isolated triangle-density experiment. They show preserved route behavior
and remaining stalls, not a proven whole-world FPS or input-latency gain. The
route's legacy listening-head click-repair remains migration debt; passing this
route does not qualify that verb as direct manipulation or complete the shift.

The cabinet isolation programme temporarily removes each cost only to diagnose
it, then restores it. It is not a production removal of collision. Near-turn
p99 is 83.307 / 66.331 / 85.866 ms for original / collision disabled / restored;
hiding visuals gives 78.678 ms between restored legs at 85.866 and 89.560 ms.
Disabling script callbacks gives 84.308 ms between 89.560 and 89.151 ms restored
legs. The authoritative target scan has a median near 0.092 ms and maximum
0.218 ms in this diagnostic. Independent ordering and cache variation remain;
delayed renderer and rolling Performance monitors are not exact same-frame
attribution. The truncated player-cost ring in this particular run cannot
support per-cycle stage costs and is not used for that claim.

Exact triangle grids and merged cabinet collision bodies were rejected. A grid
can improve isolated casts yet worsens inspection; merged bodies worsen the
played walk. Original failures, strict-contact diagnostics, source variants,
timings and wrapper receipts remain under the review directory. None changes
production geometry or masks. Removing old temporary test scenes is recorded
in a byte-hashed archive; their originals remain available for diagnosis.

## Checkpoint record

REPORT - V2-HOSE-RESPONSIVENESS - 2026-10-21

Branch / pre-write HEAD / origin/main / merge-base:
**codex/v2-acoustic-topology** / **5e031fb4** / **21f0b1fc** / **21f0b1fc**.
Worktree clean at end: **no**; preserve unrelated shared changes and stage named
owned paths only. Evidence is under
**art/reviews/v2_case_calibrator_20261021/hose_mesh_repair**: original wrapper
receipts, compressed byte-preserving logs/raw frames, executed sources, native
authoring summaries and the viewed rendered images. Its analysis script records
nearest-rank distributions; the original individual samples remain available.
Static checks are recorded separately below after completion; no pending run is
treated as a pass.

The original complete static board is preserved under **hose_mesh_repair/board**:
**107 PASS / 2 FAIL / 1 INCOMPLETE**. Ninety-seven of 98 tool suites pass; the
remaining completeness suite has two failed live-current-qualification assertions.
The surface gate reports stale rendering bindings and stale rendered review.
Comparison against the prior complete baseline reports **113 regressions**,
including ledger status losses as the seven source-bound packets expire. Ledger
blockers move **0/25/21/1/38/40 → 7/42/110/8/134/136**. This is a development
checkpoint with pending renewed qualification, not an integration candidate or
a green board. No failing predicate or old source hash is changed to hide that.

Reader baseline passes with zero NEW findings (1,109 historical unread fields).
Spatial audit has zero failing, incidental or stale drift after nine reviewed
test-only fixture references are added to the manifest; no production spatial
authority changes. The new design document lints clean. Named import cleanup
restores 285 EOL-only checkout changes after byte-normalized comparison against
HEAD; no substantive import edit is restored. Protected paths and selector are
checked read-only in the checkpoint sidecar; full clean candidate verification
remains pending.

The seven composed source-bound qualification packets were valid at the prior
calibrator checkpoint. These production mesh/controller changes expire those
bindings normally. Historical receipts are preserved without repinning; this
report promotes no spaces and grants no runtime status. Full world renewal,
remaining slide spikes, full deployment, water operation, disk reconstruction
and human acceptance remain **OPEN**. Decision needed from owner: **none**.
