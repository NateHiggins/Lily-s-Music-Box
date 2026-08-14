# T5 SERVED TRANSIT SHELTER PROOF

Captured 2026-08-14 with the production Compatibility renderer,
`WEATHER_SEED=19280731`, fixed human-height cameras and one Godot instance at a
time.

## Sets

- `approved/day/` — five views under the production overcast day.
- `approved/night/` — the same five views at canonical night.

The ordered stations prove the west approach, straight-on architectural read,
weather suppression from beneath the canopy, the 1.37 m rear bypass, and the
real eastbound tram held at its production dwell. The first four deliberately
clear live traffic so a vehicle cannot conceal the architecture; the final
frame is the service proof.

The **CARS STOP HERE** board is in-world typography, not a render
annotation. The day/night pair proves that the stop remains identifiable
without adding a realtime light. The tram's under-read night silhouette is the
separately open T2d issue.

## Reproduction

From the repository root, run once per state and never concurrently:

```powershell
$env:DAYNIGHT_FORCE='day'
$env:WEATHER_SEED='19280731'
$env:SHOT_DIR='C:\PleaseRemainOnTheLine\art\renders\transit_shelter_t5\approved\day'
Godot_v4.7.1-stable_win64_console.exe --path game res://tests/TransitShelterShot.tscn
```

Change both `day` values to `night` for the second set. Each run must print
`[TRANSIT SHELTER SHOT] 5 frames saved` and exit zero.

## Measured interpretation

`PERF_STATION='street elevation'` at canonical pinned night, 2560 × 1440:

| run | shelter visible | visual owners | objects | calls | frame |
|---|---:|---:|---:|---:|---:|
| pair 1 production | yes | 5 | 11,455 | 14,242 | 29.98 ms |
| pair 1 control | no | 0 | 11,441 | 14,228 | 29.98 ms |
| repeat production | yes | 5 | 13,379 | 16,166 | 30.02 ms |
| repeat control | no | 0 | 13,380 | 16,167 | 30.46 ms |

The object swing between pairs is live-scene state, already documented by the
benchmark contract. The controlled first pair identifies the exact submission
delta; the repeat's reversed timing establishes that the shelter has no
measurable frame-time cost rather than claiming a speed-up. The control is
`PERF_TRANSIT_SHELTER_OFF=1` in `perf_probe.gd`; it hides only the four local
generated buffers and the sign, never collision, service logic or weather.
