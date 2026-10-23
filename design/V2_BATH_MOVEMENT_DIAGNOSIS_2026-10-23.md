# Bathroom movement cost diagnosis

Evidence class: **INERT**. Raw diagnostic evidence, not runtime qualification
or a performance repair claim.

Review packet: **art/reviews/v2_bath_movement_20261023/**.
Production basis: **7731aa87**, before the subsequent bathroom sconce revision.

| Location / reproduction | Severity | Evidence | Repair / verification |
|---|---|---|---|
| Existing 3B bath, standing then actual A/D sidesteps and paired mouse turns | High | **diagnostic_v1/**, six 120-physics-tick phases | Attribution only; no physical bypass installed |
| Player collision movement | High | Slow-tick slide median/max 10.06/44.10 ms in normal phase, 10.09/44.58 on repeat | Keep real movement/collision authority; isolate actual query cost next |
| Step-up queries | High intermittent | Normal maximum 28.97 ms, repeat 29.09 | Diagnostic disable improves tails but is not a shipping repair |
| Native contact synchronizer | Not the measured bottleneck here | About .01 ms in retained slow ticks | Preserve current contact authority |
| Mirror rendering | High overlapping cost | Sleeping the mirror lowers median wall time, but collision costs persist | No rejected mirror culling or warmup installed |
| Global collision attribution | Invalid causal result | **collision_v3/** cost collapses after one frame yield independently of bisection subset | Reject its named spare-tin suspect; no hardware stock repair justified |

## Repeatable played controls

1280x720, Forward+, uncapped, VSync disabled, 60 Hz physics. Each moving phase
resets to the same surveyed full capsule stance, presses A for 12 ticks and D
for 12 ticks, and supplies the same paired mouse turns over 48 ticks, then
finishes 120 ticks. Settle 20 physics ticks and eight rendered frames first.
Captures occur after timed samples. Body collisions remain enabled throughout.

| Phase | Wall p50 / p95 / p99 / max, ms |
|---|---|
| Static | 128.17 / 137.68 / 140.25 / 140.89 |
| Normal | 151.76 / 295.19 / 385.42 / 407.98 |
| Step queries disabled, diagnostic | 126.99 / 226.80 / 302.32 / 321.20 |
| Mirror asleep, diagnostic | 54.11 / 196.18 / 340.38 / 383.24 |
| Both diagnostic controls | 49.46 / 173.14 / 266.56 / 296.45 |
| Normal restored | 151.42 / 289.38 / 383.12 / 406.55 |

**summary.json** retains distributions and >50/>100 ms counts. Its script
excludes only each phase's first incomplete wall sample. Physics stage records
contain ticks above one millisecond; their percentiles are conditional and must
not be presented as the distribution of all physics ticks. Global render,
process and physics monitors overlap and lag. Asset loading, streaming and
driver compilation are not independently isolated by this control. A lowered
mirror median does not establish that the mirror explains all wall-time spikes.

## Isolated query limits and original failures

**collision_v1/** samples synchronous body_test_motion queries at two observed
positions and excludes each exact nearby-overlap body independently. No nearby
owner explains the 52 ms +X query at the first position. That query remains slow
with every nearby exact-overlap body excluded. Other directions/positions are
much cheaper. This is useful negative evidence, not an installed improvement.

**collision_v2** fails to parse because a local variable shadows a later loop
variable. Its own console/child process IDs were identified and stopped; wrapper
exit -1 is a cancelled failed diagnostic, not a suite verdict. The corrected
**collision_v3/** adds global exclusion bisection, but yields a frame between
steps. Both initial half-exclusions take about 26 ms; after the frame yield both
take approximately .02 ms. The final named body is therefore not causal proof.
Retain these original records and repair the attribution method by comparing
interleaved restored baselines at the same published physical pose before
changing production collision stock.

The completed wrapper receipts for diagnostic_v1, collision_v1 and collision_v3
are **suite_run** only. No test-written runtime_contract or human acceptance is
claimed. The private step bypass defaults false and exists solely for the named
diagnostic control. The goal and all started feature closure work remain open.
