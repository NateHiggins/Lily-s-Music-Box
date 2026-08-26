# G17 shadow-budget rejection proof

Captured 2026-08-26 at 1600x900 through `tools/run_godot_serial.ps1`, one
Godot instance at a time. `control_64_16` and `control_b_64_16` are independent
production-budget captures. `candidate_64_4` changes only the measured shadow
budget through the test-only `PERF_SHADOW_BUDGET` hook.

## Result

**Reject 64/4. Keep the production desktop budget at 64 lights / 16 shadows.**

The candidate helps the measured GPU-bound stations, but Harukiya loses the
shadow hierarchy that grounds its bar, pool table, floor and ceiling beams. It
reads as evenly filled and substantially flatter. The lobby and carriageway
changes are modest; neither rescues the interior regression.

| station | control A/B RMSE | control/candidate RMSE | ratio |
| --- | ---: | ---: | ---: |
| lobby | 1.164943 | 6.001904 | 5.152x |
| carriageway north pavement | 2.053391 | 3.235859 | 1.576x |
| Harukiya | 0.106686 | 21.413063 | 200.711x |

## Performance observations

- Lobby 64/16: 15,375 objects/calls, 13,406,370 primitives, 18.06 ms mean.
- Lobby 64/5: 10,777 objects/calls, 7,658,864 primitives, 14.58 ms mean.
- Carriageway 64/5: 16.67 ms reported mean and too close to the 16.7 ms gate.
- Carriageway 64/4: 15.81 ms mean, 15.95 ms wall.
- Harukiya 64/4: 8.33 ms mean.

These numbers prove that globally cutting shadow casters buys time, not that it
is the correct visual policy. A later optimization should preserve local hero
fixtures and reduce cost by fixture class, distance, or station-specific
importance rather than imposing a four-shadow global ceiling.

## Capture integrity

This round found that the older shot wrote PNGs without checking `save_png()`.
The shot now creates an absolute `SHOT_DIR` and exits nonzero if any write
fails. Two apparent successful runs with relative paths were discarded before
measurement; they produced no files and are not evidence.
