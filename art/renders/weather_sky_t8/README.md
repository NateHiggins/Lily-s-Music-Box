# T8 DRIVING RAIN / FOUR-STATE SKY PROOF

All frames use the production Compatibility renderer, fixed cameras and
`WEATHER_SEED=19280731`.

## Sets

- `baseline/{morning,day,evening,night}` — five pre-T8 stations per state.
- `final/{morning,day,evening,night}` — the same five stations with the final
  storm family, depth fog, realistic batched rain, roadway mist, lower cloud
  and synchronized sky key.
- `cloud_motion/04_roof_skyline.png` and
  `cloud_motion/04b_roof_cloud_plus_20s.png` — fixed day camera with rain,
  roadway mist and cloud-light fingers disabled. The sole changing visual is
  the procedural lower cloud inside the existing sky draw.

The five ordered stations are north pavement across the road, south pavement
back to Orison, east road mouth, roof skyline, and atrium skylight. The first
four outdoor views prove exposure; the atrium proves that visible sky does not
mean indoor rain.

## Render command

From the repository root, once per state and never concurrently:

```powershell
$env:DAYNIGHT_FORCE='day'
$env:WEATHER_SEED='19280731'
$env:SHOT_DIR='C:\PleaseRemainOnTheLine\art\renders\weather_sky_t8\final\day'
C:/devkit/bin/godot.cmd --path game res://tests/WeatherSkyShot.tscn
```

Change both `day` values to `morning`, `evening` or `night`. A single station
may be selected with `SHOT_STATION=01_north_pavement`.

The cloud-only motion pair uses:

```powershell
$env:DAYNIGHT_FORCE='day'
$env:WEATHER_SEED='19280731'
$env:WEATHER_RAIN='0'
$env:WEATHER_MIST='0'
$env:WEATHER_RAYS='0'
$env:CLOUD_MOTION_PROOF='1'
$env:CLOUD_MOTION_SECONDS='20'
$env:SHOT_STATION='04_roof_skyline'
$env:SHOT_DIR='C:\PleaseRemainOnTheLine\art\renders\weather_sky_t8\cloud_motion'
C:/devkit/bin/godot.cmd --path game res://tests/WeatherSkyShot.tscn
```

## Measured interpretation

Between the two cloud-only frames, 5.30 percent of sky pixels change by more
than one level; mean absolute channel delta is 0.128 and maximum delta is 3.
That establishes real slow motion without a conspicuous sliding panorama.

At the real north-pavement player station, the first accepted batched weather
pair averaged 42.359 ms on and 41.904 ms off: +0.455 ms. After the final
realism-only rain-shader tuning, repeat means were 40.869 ms on and 41.746 ms
off; the reversed sign is ordinary runtime noise and is not claimed as a
speed-up. The conservative +0.455 ms result remains the reported cost against
the +0.8 ms contract.

The source panorama and 1024-pixel previews live with production textures for
provenance and review, but `WeatherSkyTest` proves that production loads only
the four 4096 × 2048 state assets and holds at most the adjacent pair.
