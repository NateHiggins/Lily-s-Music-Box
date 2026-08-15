# I4 wardrobe leaf split

Paired production-night proof for `4A_w0_wardrobe` after the furniture rebuild.

- `01_wardrobe_closed.png` — both runtime leaves closed; no missing or doubled
  facade remains after the baked leaves were removed.
- `02_wardrobe_open.png` — both leaves at ±92 degrees, revealing the generator-
  authored hollow carcass, shelf, rail and resident-owned garment silhouettes.

The moving leaves, panels and knobs are owned by the exact furniture record.
The static glTF owns the carcass and contents. Contents have no pickup target and
the telegram response remains resident-private.

Captured with:

```powershell
$env:SHOT_DIR='C:\PleaseRemainOnTheLine\art\renders\wardrobe_split_i4'
.\Godot_v4.7.1-stable_win64_console.exe --path game `
  res://tests/WardrobeInteractionShot.tscn
```

Proof gates passed after the rebuild: `ServiceWireResponseTest`,
`LightingAudit`, `ShopEntryTest`, `RealityCaseTest`, `FinalMapRouteTest`, and
`WalkTest FULL` at `WALKTEST_SCALE=8`, 480 Hz.
