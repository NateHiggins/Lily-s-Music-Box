# N3 — disposable light/pursuit control

Generated 2026-08-15 from `DreamLightControlTest.tscn` and
`DreamLightControlShot.tscn`. This closes **Gate B only** in
`design/ORISON_MAZE_BRIEF.md`. Nothing in this directory is production maze
geometry, a campaign scene, a case profile or a canonical Tenant body.

## Exact control geometry

The timing corridor is a closed rectangular tube **42.00 m long × 3.20 m clear
wide × 3.00 m clear high**, with 0.20 m solid floor, ceiling and wall plates.
The measured target begins at z=8.00 m, runs at the module catalog's authored
4.60 m/s and stops against the real end at z=40.00 m. One invisible
`CharacterBody3D` begins at z=1.00 m; capture radius is 0.75 m.

`control_corridor_top_down.svg` records those dimensions and the separate
opaque-wall sensor cell. The sensor cell uses a real 0.35 × 2.80 × 3.00 m
`StaticBody3D`: body x=5.80 to target x=9.20 at z=0 is blocked; moving the
target to z=4.60 opens a line around the wall end and acquires it. The timing
corridor stays straight and unobstructed, so wall proof cannot contaminate its
capture measurements.

## Deterministic pursuit rule

Eleven fixed seeds run three paired scenarios at a fixed 120 Hz step:

- **light on:** clear physics ray continually refreshes the target and uses
  6.35 ± 0.12 m/s pursuit;
- **light off:** footsteps update a coarse last-known point every
  0.72 ± 0.08 s and use 3.35 ± 0.08 m/s pursuit;
- **extinguished:** identical to light-on until 0.15 s after acquisition, then
  identical to light-off.

The final shoe plant at the real end wall is an audible sample. This is not
rubber-banding: it fixes the last-known point to a place the player physically
reached, preventing a stop between footstep samples from creating an accidental
infinite hiding state.

| paired median | capture |
|---|---:|
| lamp continuously on | **3.425 s** |
| lamp continuously off | **11.358 s** |
| lamp extinguished after acquisition | **11.225 s** |

Light-on therefore shortens median survival by **69.8%**, against the required
33.3%. Extinguishing after acquisition buys **7.800 s**, against the required
6.000 s. Every dark run still captures by 11.542 s. Raw per-seed results are in
`capture_times.csv`.

The first harness run was rejected rather than tuned around: darkness reached
the 30 s cap because stopping between hearing samples left a stale last-known
point forever. The terminal footstep above corrected the invalid safe state;
all numbers in this record are fresh runs after that correction.

## Input and image proof

All three input surfaces reach `PlayerController.toggle_lamp()` through the
same `lamp_toggle` action:

| surface | physical control |
|---|---|
| keyboard | `L` |
| controller | left shoulder |
| touch | `LAMP` |

`01_lamp_on_shadow_only.png` shows the warm beam and the diagnostic proxy's
shadow while the proxy itself remains absent from the beauty pass.
`02_lamp_off_navigation_black.png` shows the permitted black level: the nearest
floor edge and one unreachable receding cool practical remain, without a
visible body. The proxy is a capsule only because the control needs a caster;
it is `SHADOW_CASTING_SETTING_SHADOWS_ONLY` and is not a Tenant asset.

## Reproduce

Run one Godot instance at a time, each under 60 seconds:

```powershell
$env:N3_RESULT_DIR=(Resolve-Path 'art\renders\dream_light_n3').Path
C:\devkit\bin\godot.cmd --headless --path game res://tests/DreamLightControlTest.tscn

$env:SHOT_DIR=(Resolve-Path 'art\renders\dream_light_n3').Path
C:\devkit\bin\godot.cmd --path game res://tests/DreamLightControlShot.tscn
```

Settled result: **N3 PASS / Gate B complete.** K7 documentation remains the
required next step before N4 adds any campaign scene boundary. Regression:
`ServiceSetTest` PASS (203/203 functional E owners, 18/18 refrigerators) and
`WalkTest` PASS at x8 / 480 Hz after the controller binding landed.
