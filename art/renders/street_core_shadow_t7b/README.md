# T7b — STREET/core fixture shadow ownership

Canonical night, fixed `WEATHER_SEED=19280731`, north-pavement production lens,
1600 x 900 visual proof and 2560 x 1440 performance proof. The light remains;
only shadow maps belonging to fixture sources physically inside the Orison core
are declined while the player is in STREET.

## Same-process visual pair

`paired/` was produced in one Godot process. The scene settles with
`PERF_STREET_CORE_SHADOWS_ON=1`, then pauses. `control_a` and `control_b` price
renderer/rain movement that survives the pause. Exactly eleven core fixture
shadow flags are cleared before `final`; no camera, light energy, visibility,
weather, traffic or clock state changes.

Command:

```powershell
$env:SHOT_DIR='<repo>\art\renders\street_core_shadow_t7b\paired'
$env:SHOT_STATION='01_north_pavement'
$env:DAYNIGHT_FORCE='night'
$env:WEATHER_SEED='19280731'
$env:PERF_STREET_CORE_SHADOWS_ON='1'
$env:WEATHER_CORE_SHADOW_PAIR='1'
godot --path game --resolution 1600x900 res://tests/WeatherSkyShot.tscn
```

Pixel measurements (RGB):

| pair | changed | >3/255 | >8/255 | mean abs | max |
|---|---:|---:|---:|---:|---:|
| control A / control B | 3.3976% | 1.1308% | 0.1352% | 0.064568/255 | 110 |
| control B / final | 5.3940% | 2.1619% | 0.4780% | 0.120782/255 | 124 |

The difference is small and localized around the distant lit entrance recess;
the playable frame retains its light pools and facade depth.

## Same-build performance pair

`WeatherPerf.tscn`, 1440p, 16/16 pinned, 30 warm-up / 120 samples, one Godot
instance at a time:

| state | objects | calls | primitives | average ms |
|---|---:|---:|---:|---:|
| control A | 19,900 | 25,248 | 19,696,063 | 35.929 |
| control B | 20,072 | 25,370 | 19,695,615 | 36.486 |
| production A | 10,401 | 12,530 | 7,905,771 | 26.486 |
| production B | 9,741 | 11,883 | 6,697,071 | 27.042 |
| mean change | -49.6% | **-51.8%** | -62.9% | **-9.444 (-26.1%)** |

The retained control is `PERF_STREET_CORE_SHADOWS_ON=1`; it forces the old
shadow allocation on without reverting production code.

## Regression proof

- `LightingAudit` — 127-space PASS, including STREET suppression, exterior
  shadow preservation and ORISON restore;
- `WeatherSkyTest` — PASS;
- `PassageVisibilityTest` — PASS (0 failures);
- `FinalMapRouteTest` — PASS in both route directions;
- `WalkTest` FAST x4/240 and FULL x8/480 — PASS.

One Godot instance ran at a time; every invocation stayed inside 60 seconds.
