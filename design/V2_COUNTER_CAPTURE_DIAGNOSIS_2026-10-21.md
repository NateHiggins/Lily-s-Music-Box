# V2 counter timing correction and continuation

Evidence class: **INERT**. Diagnostic issue log, not runtime qualification or human acceptance.

The largest counter-phase spikes in the previous repair-route profile included
synchronous diagnostic image capture. They do not establish a slow purchase
transaction. No production optimization is claimed from removing that work.

| Location / severity | Reproduction / evidence | Repair | Verification |
|---|---|---|---|
| Golden-route profiler / medium measurement defect | Viewport readback and PNG encoding immediately before semantic input were included in wall frames | Default timed profile omits route photographs; explicit **V2_PROFILE_CAPTURE_CONTROL=1** retains them and records readback/encoding separately. Ordinary functional route captures remain enabled. | Two actual windowed 94-waypoint routes, no failed assertions or script errors; original wrapper receipts and raw frames preserved. |
| Remaining played stair route / high responsiveness debt | Capture-free maximum 264.085 ms, 37 frames over 100 ms | Open; no unmeasured collision or detail removal | Next production changes require a matched capture-free comparison. |
| Caption calibrator / interaction migration debt | Existing case target responds by animating its whole box and calling the case callback on click | Next bounded V2 construction: native fixed housing and separately targeted constrained plunger | Pending; no physical-input or case acceptance claimed here. |

Actual playable world: RTX 4080, Godot 4.7.1 Forward+, 1280 x 720,
VSync off, uncapped. Cache/driver history was not reset. Order: capture-free,
then capture-enabled. A read-only audit during the first startup was terminated
before runtime-ready and sampling; no audit ran during either timed route.
The first output directory is named **capture_control** despite its authoritative
**capture_control=false** field. This naming mistake is retained explicitly.

| Capture mode | Frames | p50 / p95 / p99 / max, ms | >100 / >250 ms |
|---|---:|---|---:|
| Disabled | 3505 | 30.838 / 65.580 / 102.684 / 264.085 | 37 / 1 |
| Enabled | 3506 | 31.448 / 65.806 / 122.468 / 351.058 | 45 / 6 |

Counter / repeated-counter phase maxima are **81.162 / 68.206 ms** without
capture and **349.343 / 351.058 ms** with capture. The corresponding capture
calls spend **17.996 / 23.637 ms** in readback and **258.680 / 252.051 ms**
in PNG encoding. The complaint phase falls from **255.789 to 51.363 ms**
when capture is omitted. These are frame windows and measured capture calls,
not isolated transaction costs or input-to-display latency. No production
state, audio, rendering settings or transaction authority changed.

Raw evidence: **art/reviews/v2_counter_hitch_20261021/comparison.json**,
**capture_control/frames.json**, **captures_enabled/frames.json**, both original
wrapper receipts, byte-exact compressed logs and three executed helper sources.
The previous **golden_final** evidence remains unchanged. Its counter-phase
attribution is superseded by this diagnosis; its functional assertions remain.

REPORT - V2-COUNTER-CAPTURE-DIAGNOSIS - 2026-10-21

Branch **codex/v2-acoustic-topology**, starting HEAD **571a9a6b**, main reference
**21f0b1fc**. This checkpoint changes diagnostic test helpers and evidence only.
Both original suite-run receipts report completed runs with zero failures and
zero script errors; neither is a runtime-contract receipt. Existing source-bound
qualifications must be checked after the subsequent construction freeze, including
transitive test-helper bindings. No new gate-board or clean-candidate certificate,
main integration, sustained 60 FPS, eleven-beat completion or V2 completion is
claimed. Shared unrelated untracked files remain untouched. No owner decision
is needed; continue the bounded physical-control construction and qualification.
