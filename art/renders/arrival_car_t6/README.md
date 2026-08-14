# T6 — moving arrival car proof

Captured from `ArrivalCarShot.tscn` at 1280 × 720 in the production GL
Compatibility renderer with `DAYNIGHT_FORCE=morning`, `WEATHER_SEED=19280814`.
These are deterministic vehicle states under live production rain, not posed
replacement geometry.

| Frame | Authored moment |
|---|---|
| `01_just_out_at_south_kerb.png` | Player-height first view from (−3.60, −24.72), facing the Orison door; the held car occupies one traffic slot at the kerb. |
| `02_pull_away_across_crossing.png` | The same car after the 1.15 s hold and 2.20 s of deterministic acceleration/merge, moving east across the zebra. |
| `03_east_tear_swallow.png` | The same uninterrupted lifecycle 2.45 s later, entering the localised storm at the x +20.60 stage edge before removal at x +27.00. |

The close car uses the existing body, cab, wheel and emissive-lamp MultiMeshes:
four traffic draw owners before, during and after T6. It has no physics body,
dedicated light, static mesh or parked remainder. `ArrivalCarTest.tscn` is the
machine proof for those claims and for the one-shot campaign boundary.

Focused verification exited green: `ArrivalCarTest`, `TransitShelterTest`,
`StreetContainmentTest`, `FinalMapRouteTest`, `WeatherSkyTest`, `LightingAudit`,
`PassageVisibilityTest`, `PassageOwnershipAudit`, and WalkTest FAST. One
WalkTest FULL attempt at x8 / 480 Hz produced no report within the mandatory
60-second bound and was terminated. It is recorded as no result, not a pass or
failure, and was not repeated.

Capture command:

```powershell
$env:SHOT_DIR='C:/PleaseRemainOnTheLine/art/renders/arrival_car_t6'
$env:DAYNIGHT_FORCE='morning'
$env:WEATHER_SEED='19280814'
C:/devkit/bin/godot.cmd --path game --resolution 1280x720 res://tests/ArrivalCarShot.tscn
```
