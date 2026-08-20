# TRAFFIC COACHWORK SURFACE — 2026-08-18 CHECKPOINT

This closes the paused surface half of T2c. It does not redesign vehicle
silhouettes, movement, cadence, lights or the piano-repair truck.

## What changed

The ordinary traffic body and cab batches were vertex-coloured boxes using a
flat `StandardMaterial3D` with `metallic = 0.35`. Compatibility rendering has
no useful scene reflection for that value, so the paint returned less light and
read as a black slab. Both batches now retain their authored per-kind colours
while borrowing the `car_paint` normal and roughness maps. Their albedo texture
is deliberately removed rather than multiplied through the tint; its measured
mean is 0.321 and would darken the already night-tuned palette. Coachwork is
painted, so metallic is zero.

Tyres independently use the `rubber_aged` normal/roughness plate at 0.94
roughness and zero metallic. Their shared cylinder rises from 10 to 16 radial
segments. That changes silhouette inside the existing wheel draw; it creates no
new owner, instance, light or shadow caster.

## Render method

`TrafficNightReadabilityShot.tscn` was run once before and once after at pinned
night, fixed weather seed and fixed traffic records:

```powershell
$env:SHOT_DIR='C:/PleaseRemainOnTheLine/art/renders/traffic_paint/before'
Godot_v4.7.1-stable_win64_console.exe --path game `
  res://tests/TrafficNightReadabilityShot.tscn

$env:SHOT_DIR='C:/PleaseRemainOnTheLine/art/renders/traffic_paint/after'
Godot_v4.7.1-stable_win64_console.exe --path game `
  res://tests/TrafficNightReadabilityShot.tscn
```

Each directory contains two same-build controls with the wet-road headlight
pool hidden and one final frame with it visible. The rain remains live, so the
controls are the required noise floor.

## What the images prove — and do not

Across the complete 1280 × 720 south frame, paint signal RMSE is 0.01177 against
an A/A floor of 0.01169: not separable. That is expected when animated rain
changes most of a frame and the edited vehicle occupies one corner. Inside the
470 × 360 foreground-vehicle crop, paint signal is 0.02641 against an after A/A
floor of 0.00254: **10.4× the measured noise**. The new panel variation is
visible on the large foreground body without lifting its base colour into a
glowing rectangle. The north long view is too distant to license a visual claim.

This is therefore evidence for a local coachwork response, not a claim that the
whole street changed or that vehicle modelling is finished.

## Contracts

- `TrafficNightReadabilityTest.tscn`: PASS. It now checks tint preservation,
  normal/roughness ownership, zero metallic, 16-segment wheels and matte rubber
  in addition to the existing wet-road/cadence contract.
- `PianoRepairTruckTest.tscn`: PASS. Its stale fallback-panel assertions were
  corrected to the production projected-mesh contract; the truck itself was not
  changed by this pass.
- `ArrivalCarTest.tscn`: PASS before the contract update. The material code does
  not alter arrival ownership, trajectory or removal.

No FULL WalkTest is claimed for this checkpoint. The production change is one
material reassignment and one shared mesh subdivision; the focused contracts
are the proof carried here.
