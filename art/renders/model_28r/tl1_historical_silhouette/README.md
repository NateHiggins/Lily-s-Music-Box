# MODEL 28-R — TL-1 HISTORICAL SILHOUETTE

This is the first production checkpoint for the player's principal physical
instrument. It replaces the compact Model No. 4 presentation without changing
the production lamp, radio, work-order or paper ownership seams.

## Camera truth

- `01_carried_historical_silhouette.png` is the actual carried pose in the
  production Orison and shows the asymmetric service face at gameplay scale.
- `02_instrument_side.png` proves the five black-shape landmarks together:
  faceted focusing bezel, arched meter, detector dome, rear battery mass and
  telegram throat.
- `03_service_side.png` proves this is not a one-faced prop: a separately
  fastened access plate, twin lacquered coils, line posts and serialized maker
  plate occupy the reverse.
- `Z_control_a/b.png` are consecutive, unchanged instrument-side captures from
  the same Forward+ process. Their normalized full-frame RMSE is **0.00317172**;
  animation in the production building is the measured noise floor.

The earlier production baseline remains in `art/renders/service_set_q4/`. The
new silhouette is materially larger and changes every landmark, so the visual
claim clears that A/A floor by inspection without pretending the two dated
runs are a controlled pixel pair.

## Measured contract

`Model28RTest.tscn` passes **9/9**:

- historical chassis **0.316 x 0.115 x 0.082 m** (length within the ruled
  30–34 cm envelope);
- five named physical landmark owners;
- 36+ slotted screw/washer pieces across separate plates;
- 147 geometry owners in the current untextured construction;
- maker/model labeling and retained radio, lamp and physical-paper seams.

The full production `ServiceSetTest.tscn` also passes after the swap: 275
functional interaction owners, 18/18 refrigerator interactions, device input,
work-order projection and the deliberate 0.24 s unpowered filament tail.

This closes TL-1 only. The moving focus carriage, damped needle, selector,
tuning condenser, key, printer mechanism, magneto and leads are TL-2. The
fifteen-identity authored material stack is TL-3; the restrained dark values in
these frames establish period mass and separation, not final surface quality.

## Reproduce

Run one Godot instance at a time under the shared mutex:

```powershell
C:\devkit\bin\godot.cmd --headless --path game res://tests/Model28RTest.tscn
$env:SHOT_DIR=(Resolve-Path 'art\renders\model_28r\tl1_historical_silhouette').Path
C:\devkit\bin\godot.cmd --path game res://tests/Model28RShot.tscn
magick compare -metric RMSE Z_control_a.png Z_control_b.png null:
```
