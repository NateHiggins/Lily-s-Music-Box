# T5B ROAD CLEARANCE PROOF

Captured 2026-08-14 with the production Compatibility renderer, fixed
human-height cameras, `DAYNIGHT_FORCE=day`, `WEATHER_SEED=19280731`, and one
Godot instance at a time.

## Scope

The cleanup retires the obsolete utility-excavation layer only: four trench
slabs, four spoil heaps, two loose planks, sixteen striped contractor
barricades, and the loose paper assembly that straddled the south kerb. The
zebra, wet road, drains, puddles, moving traffic, served shelter, pavement
dressing, and the final timber/weather architecture at x -20.10 / +20.60 all
remain.

The source A/B uses the unchanged `TransitShelterShot.tscn` cameras:

- before: `art/renders/transit_shelter_t5/approved/day/` (commit `afd6dc1`);
- after: `after/`;
- same-build live-rain control: `noise_control/`.

Frames 01 and 03 are the useful visual proof. Their cleanup signal is 4.0x and
11.2x the repeat-render mean pixel noise respectively. Frame 02 contains no
meaningful cleanup geometry and correctly lands at its repeat noise floor.
The complete five-frame sets are retained so the shelter and serving-tram
controls can be compared without choosing favorable views after the fact.

## Geometry and collision reconciliation

The regenerated F01 build removes one merged primitive containing exactly
10,816 position vertices, 17,952 indices, and 381,296 buffer bytes. The
production layout contains zero `retail_dig_*` records and no
`retail_street_papers`, while all eleven `retail_zebra*` records remain.

`RoadClearanceTest.tscn` proves all sixteen former barricade stations with the
production player capsule. Its deliberate evidence ladder was:

1. before data change: obsolete records present; 16/16 stations blocked;
2. after data regeneration but before glTF rebuild: records absent; 16/16
   stations still blocked, proving the stale build independently;
3. after Blender rebuild and Godot import: records absent; 16/16 stations
   clear; six-span visible street-end boundary still present.

Focused regression results: `StreetContainmentTest`, `TransitShelterTest`,
`FinalMapRouteTest`, `WeatherSkyTest`, `PassageVisibilityTest`,
`PassageOwnershipAudit`, `LightingAudit`, and WalkTest FAST all pass. WalkTest
FULL at x8/480 was attempted under the repository's hard 60-second process
bound but did not report before timeout; it is recorded as **no result**, not a
pass or a regression. No Godot instances were overlapped.

## Reproduction

Run without `--headless`; Godot's headless display executes the scene but does
not produce real rendered frames.

```powershell
$env:DAYNIGHT_FORCE='day'
$env:WEATHER_SEED='19280731'
$env:SHOT_DIR='C:\PleaseRemainOnTheLine\art\renders\road_clearance_t5b\after'
Godot_v4.7.1-stable_win64_console.exe --path game res://tests/TransitShelterShot.tscn
```

The run must print `[TRANSIT SHELTER SHOT] 5 frames saved` and exit zero.
