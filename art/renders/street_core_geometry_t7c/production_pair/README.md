# T7c — enclosed-F01 STREET gate

Exact same-process A/A/B proof of the production spatial gate at canonical
night. `control_a` and `control_b` retain the old state through
`PERF_STREET_CORE_GEOMETRY_ON=1`; `final` then removes the exact
`BuildingRoot.street_core_nodes` production index while the scene is paused.
The repeated control measures GPU-rain movement that survives the pause.

```powershell
$env:DAYNIGHT_FORCE='night'
$env:WEATHER_SEED='19280731'
$env:WEATHER_STREET_CORE_PAIR='1'
$env:PERF_STREET_CORE_GEOMETRY_ON='1'
$env:SHOT_STATION='01_north_pavement' # then 02_south_pavement, 03_east_road_mouth
$env:SHOT_DIR='<repo>\art\renders\street_core_geometry_t7c\production_pair'
.\Godot_v4.7.1-stable_win64_console.exe --path game --resolution 2560x1440 res://tests/WeatherSkyShot.tscn
```

Pixel deltas (`max RGB` determines the threshold; mean is across RGB channels):

| station | pair | changed | >3 | >8 | mean abs /255 | max |
|---|---|---:|---:|---:|---:|---:|
| north pavement | control A/B | 2.7262% | 0.7624% | 0.0697% | 0.046433 | 111 |
| north pavement | control B/final | 6.1093% | 2.6234% | 0.8186% | 0.240369 | 215 |
| south pavement | control A/B | 3.9563% | 0.8379% | 0.0543% | 0.057785 | 112 |
| south pavement | control B/final | 9.4547% | 2.7636% | 0.9067% | 0.345307 | 230 |
| east road mouth | control A/B | 8.8973% | 4.0216% | 2.0360% | 0.326825 | 150 |
| east road mouth | control B/final | 20.8072% | 4.9847% | 1.7834% | 0.416168 | 152 |

The east view's moving-rain floor is already large. Visual review is the gate:
all three finals retain the authored entry door, occupied-window cards,
complete neon words, marquee, exterior light pools and facade silhouette. The
treatment changes only faint aperture illumination/shadowing from casters that
are fully behind the shell; no exterior object or architectural layer vanishes.

Fresh-process performance, 1440p, canonical night, 16/16:

| state | objects | calls | average ms |
|---|---:|---:|---:|
| control A/B | 9,735 / 9,740 | 11,864 / 11,881 | 26.735 / 26.252 |
| production A/B | 8,198 / 8,202 | 9,433 / 9,433 | 22.870 / 22.794 |
| mean change | -15.8% | -20.5% | **-3.662 ms (-13.8%)** |
