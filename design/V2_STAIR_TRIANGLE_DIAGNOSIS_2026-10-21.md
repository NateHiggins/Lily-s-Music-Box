# V2 stair collision experiment — 2026-10-21

Evidence class: **INERT**

The exact disconnected-triangle partition is rejected for production. It preserves
native triangle bytes and winding and matches the original engine ray contacts,
but does not establish a played-world improvement. No production collision shape,
mask, constraint, player step rule or obstruction exemption changed.

| Location / reproduction | Severity / evidence | Repair / verification |
|---|---|---|
| Lower-to-upper landing, repeat nine-waypoint ascent/turn/descent three times | High: 246.856 / 246.362 / 246.779 ms maxima for original / partition / restored original; p99 220.340 / 223.959 / 222.249 ms | Candidate rejected. All 27 actual movement waypoints pass. Raw frames, controller stage costs and source are retained. |
| Native SafetyWire contact microbench | Diagnostic: separate triangle shells reduce isolated capsule-query cost, but that does not prove overall frame improvement | Byte-exact triangle multiset and paired engine contacts pass. Absolute native-boundary precision remains the original unresolved diagnostic; the failed stricter measurement is preserved. |
| Prototype output | Low: partitions.json was not written because its output directory did not exist until the parent profiler completed | One original SCRIPT ERROR retained in the wrapper receipt. Raw frames and executed test source permit assessment; no missing metadata is invented and no runtime grant is claimed. |

The candidate reduced maximum slow step-probe calls from 82.882 / 82.199 ms to
40.636 ms, while worst slide calls remain 27.495 / 27.604 / 27.964 ms. The two
original legs have p95 162.243 and 98.135 ms; candidate p95 is 101.608 ms. Cache
and order variation prevent treating the first-leg difference as a gain. Preparation
and shape-switch frames are excluded. All original bodies are restored before exit.

REPORT - V2-STAIR-TRIANGLE-DIAGNOSTIC - 2026-10-21

Branch / HEAD / origin/main / merge-base: **codex/v2-acoustic-topology** /
**7f88c923** / **21f0b1fc** / **21f0b1fc**.

Worktree clean at end: **no**; unrelated shared untracked files and import EOL
churn remain. Only named owned paths will be staged. Protected 17/17 and V2
selector are unchanged by this diagnostic; formal final checks follow renewal.

Ledger before -> after: no grants from this report. No gate predicate, receipt,
source-bound hash or original failed test is repinned. The schema-2 qualification
batch is separate from these INERT measurements.

Gates: original lane wrapper receipts under
**art/reviews/v2_case_calibrator_20261021/** retain the failed absolute-boundary
bench, failed parse run and subsequent paired-equivalence pass. The played
**partition_stair_control.log.receipt.json** records exit 0, **27 waypoints; 0 route failures**, and **one SCRIPT ERROR** from
the final metadata write. This is a failed diagnostic run despite completed walking
and restored original shapes; the raw timed windows still support rejecting the
candidate. It is not a clean test pass or a runtime contract.

Numbers requested: paired distributions in **partition_stair_control/comparison.json**.
Changes outside expected boundary: temporary diagnostic tests only; no production
integration. Open findings: physics catch-up and stair spikes remain. Decision
needed from owner: **none**; source-bound qualification renewal continues.

BLOCKED - remaining frame spikes and full candidate qualification; no V2 completion claim.
