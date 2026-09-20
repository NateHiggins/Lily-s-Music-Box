# Matched one-census execution review

The optimized source passes the complete material and renderer contracts. The
two matched runs show about **14% lower median synchronous Street–Passage apply
times**, with different adaptive-governor behavior. This is an observed two-run
delta, **not acceptance of an isolated speedup or release performance**. The
remaining roughly 1.18-second calls are still substantial stalls.

All **124 retained artifacts** (62 per run), including 36 PNGs and 64 source
copies, match their hashes. Each run's before/after inventory is stable. The
two 4,045-path game/tools maps differ only at
`game/scripts/reality/apartment_encroachment.gd`: `2a440504…` → `1a1b067f…`.
The four inactive equivalence copies have identical baseline bytes in both
recorded runs. Their subsequent restoration belongs to the separate outer
invocation evidence. Both engine binaries, wrapper/gate/serial-runner hashes,
HEAD, hardware context and commands normalized only for output paths match.
Both use the exact `d67ce1ac…` observer. Complete inherited host environment
and background OS/GPU activity were not snapshotted.

Each run completes 314 checks and 18 captures with engine/base/material gates
all zero. This review verifies image bytes; root independently reviewed their
appearance. No human acceptance is inferred.

## Direction-specific synchronous apply times

Five warmups are excluded. These are the contiguous six-cycle loop's calls,
measured before four rendered frames and the separate 16 repeated scans.
Values are medians in milliseconds; percentage is optimized versus baseline.

| Direction | n | Baseline | Optimized | Change |
|---|---:|---:|---:|---:|
| Harukiya → Street, first cycle | 1 | 35.857 | 35.025 | −2.32% |
| Street → Passage | 6 | 1385.249 | 1188.594 | −14.20% |
| Passage → Street | 6 | 1377.800 | 1179.574 | −14.39% |
| Street → Orison | 6 | 40.383 | 40.310 | −0.18% |
| Orison → F04 | 6 | 4.114 | 4.056 | −1.40% |
| F04 → Orison | 6 | 2.980 | 2.984 | +0.17% |
| Orison → Street, later cycles | 5 | 37.689 | 37.623 | −0.18% |

The JSON retains every sample, mean, min/max and nearest-rank p95 (with six
samples, p95 is simply the maximum). Separately, the post-loop Orison→Harukiya
capture return is 2.549→2.761 ms; the post-control Orison→Passage retirement
return is 1688.082→1157.631 ms. Each has only one sample. The latter direction
uses the fixture's explicit Orison visibility reset, not the preceding
transition-array entry.

## Workload and material boundaries

Across 144 main-loop frames, baseline budget observations are 1.0×124 and
0.75×20; optimized observations are 1.0×113, 0.75×25 and 0.5×6. Both remain
unpinned, keep the prop tier enabled and report zero queued material changes.
These different adaptive decisions prevent treating the measured delta as a
controlled fixed-workload speedup.

Initial core count 1785, Harukiya count 247 and its complete path/AABB census
match exactly. Geometry and zero-layer counts match across all 43 population
rows. Full population records match in 25 rows; elsewhere optimized eligible
count differs by −1 and owner-hidden count by +1. No causal attribution for
that small live-population difference is established here.

All six case row sets, cache keys and per-floor registry counts match before
measurement and after each of cycles 0–5. Before retirement, Cal prop rows
differ 140→133, Mina 171→167 and Peter 156→160; the associated F05/F02/F04
registry counts differ correspondingly. Every observed registry remains
unique and valid; installed ownership, field, cache and exclusion predicates
pass. These later differences are retained, not normalized away or assigned
an unproven cause.

The independent refresh observer evaluates 948 case materials and all 1374
registered lifecycle targets at the first observation in each run. At the
final observation it evaluates 958/1384 baseline versus 951/1377 optimized.
Every comparison executes. Case state, force/intensity facts, beachhead
identities and the complete registered lifecycle write set restore exactly
within each run. Actual retirement releases all 959 versus 952 cumulatively
observed case materials, with no retained IDs.

This is one ordered V1 run per source on Godot 4.7.1, RTX 4080/i7-13700KF.
It supplies no randomized/order-balanced replication, confidence interval,
V2 timing, arbitrary texture equivalence, isolated callback-cost attribution,
or release-FPS claim. The synchronous measurement includes downstream
visibility, indexing, material and callback work.

Machine review: `one_census_matched_execution_review.json`, SHA256
`bfaf35b5fabac0fc659a6b8c8badf81a1f59eee23e950be52e75e33a1887faf2`.
It binds every artifact and retains the raw timing and population comparisons.
Baseline result: `a989c22dcab75312591058f50ba7d18ce2e9a073e254b0f929572f2a58ca452e`.
Optimized result: `ad119d32fa1c0b48de3dd567921356d2af821dd79ca64a6d137ac5adca0d8496`.
