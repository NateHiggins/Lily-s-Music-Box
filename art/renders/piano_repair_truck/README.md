# WE TUNA PIANOS — production traffic proof

The approved advertising art and vehicle concept were generated with the
built-in image generation path, then the complete sign was imported as
`res://assets/building/textures/traffic/we_tuna_pianos_sign.png`.

`PianoRepairTruckShot.tscn` holds the production traffic kind at three fixed
human-height stations. The root frames use canonical morning rain; `day/`
repeats the same placements under the day state. Vehicle geometry remains the
street's deliberately low-cost MultiMesh language rather than substituting the
concept illustration for an in-engine model.

The proof burden is structural and visible:

- 5.8 × 2.05 × 2.30 m, below the ordinary coal-lorry envelope;
- one existing body, cab, wheel and lamp instance set per truck;
- two side-panel instances in one shared `PianoRepairSigns` MultiMesh;
- panel is rough, non-emissive and casts no shadow;
- zero panel instances and therefore no sign submission when the kind is absent;
- no realtime light, physics body, transit stop or dialogue reaction;
- 2.0 / 99.0 selection weight, approximately one in fifty picks.

`PianoRepairTruckTest.tscn` proves those contracts and both lane directions.
The remaining darkness of the unlit vehicle body is the already-open T2d
street-lighting issue; it is not hidden or mislabelled as part of this addition.

Capture command:

```powershell
$env:SHOT_DIR='C:/PleaseRemainOnTheLine/art/renders/piano_repair_truck'
$env:DAYNIGHT_FORCE='morning'
$env:WEATHER_SEED='19280814'
C:/devkit/bin/godot.cmd --path game --resolution 1280x720 res://tests/PianoRepairTruckShot.tscn
```
