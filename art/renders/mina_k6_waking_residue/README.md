# K6 waking-residue acceptance pair

Captured 2026-08-15 from the production Orison scene at canonical 03:00.

- `00_resolved_control_a.png` and `01_resolved_before_wake.png`: an A/A noise
  control. Mina's case is resolved, but no wake boundary has committed a
  residue; the refrigerator is ordinary in both frames.
- `02_waking_residue.png`: the same fixed camera after the one persisted wake
  fact. Only the pale factual `REFRIGERATOR` caption appears.

The full-frame A/B RMSE is 2.11x the A/A floor. In the fixed 260 x 120 caption
region it is 25.4x the A/A floor (0.07571 versus 0.00299 normalized RMSE), so
the accepted difference is localized and clears live-render noise.

The first attempted render exposed an invalid provisional anchor:
`F02_A_FRIDGE_01` resolved to world origin. The accepted pair uses the actual
generated acoustic marker `F02_2A_FRIDGE_01` for ownership and generated socket
`2A_FRIDGE_FACE` for presentation. The shot harness asserts both provenance and
the before/after visibility rule, so a future layout move cannot silently bury
the label in the appliance centre.

Reproduce with one Godot instance:

```powershell
$env:SHOT_DIR='C:\PleaseRemainOnTheLine\art\renders\mina_k6_waking_residue'
Godot_v4.7.1-stable_win64_console.exe --path game --resolution 1280x720 `
  res://tests/MinaWakingResidueShot.tscn
```

This is waking-world evidence only. K6 still uses a dream-entry/return test
stub and does not reveal or implement the production dream world.

## Verification

- `GoldenLoopTest`: PASS, 82/82, all 13 ordered blocks, 44.9 s.
- `MaintenanceCounterTest`: PASS; production ray, repair, case integration,
  protected dream request and 4B wake.
- `RealityCaseTest`: PASS.
- `WalkTest` FAST at x8 / 480 Hz: PASS.
- `WalkTest` FULL at x8 / 480 Hz: no bounded verdict in this session. Two runs
  were killed by the required 60-second outer timeout; neither returned test
  output or left a Godot process. Do not report those runs as either PASS or a
  functional assertion failure.
