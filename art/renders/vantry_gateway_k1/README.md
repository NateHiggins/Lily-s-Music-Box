# Vantry gateway K1 render proof

Captured 2026-08-14 from the canonical Blender 4.5 export with the fixed
`VantryGatewayShot.tscn` cameras at canonical night.

- `dry/` contains the seven established K0 approaches plus the supplemental
  `08_stair_detail.png` proof with production weather hidden.
- `weather/` repeats all eight cameras with production weather live.
- Cameras 01–07 are unchanged from K0. Camera 08 remains outside the barred
  exit gate and looks down through it at the real pavement cut, eight treads,
  tiled cheeks, handrails, lower landing and finite dark terminus.

The ordinary player route remains the separate six-metre Vantry portal. The
kiosk has visible collision and no interaction, route, station, train,
cutscene, new zone or new real-time light.

## Reproduction

From the repository root, run one Godot instance at a time:

```powershell
$env:SHOT_DIR='C:\PleaseRemainOnTheLine\art\renders\vantry_gateway_k1\dry'
$env:GATEWAY_DRY='1'
.\Godot_v4.7.1-stable_win64_console.exe --path game res://tests/VantryGatewayShot.tscn
```

Then remove `GATEWAY_DRY`, point `SHOT_DIR` at `weather`, and repeat. Each run
must print `[VANTRY GATEWAY SHOT] 8 frames saved` and exit zero.
