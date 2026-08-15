# Service-wire style proof

Owner-ruled 2026-08-15. `telegram_service_wire.png` is a production-scene
capture at 1280 × 720 showing the shared paper stock and type hierarchy on the
objective slip and field copy, plus the physical crown-fed ticket above the
carried Vantry service set. The field copy stays clear of the crosshair and the
objective slip.

Command, one Godot process:

```powershell
$env:SHOT_DIR='C:\PleaseRemainOnTheLine\art\renders\telegram_style_i3'
.\Godot_v4.7.1-stable_win64_console.exe --path game `
  res://tests/TelegramStyleShot.tscn
Remove-Item Env:SHOT_DIR
```

Focused deterministic proof:

```powershell
.\Godot_v4.7.1-stable_win64_console.exe --headless --path game `
  res://tests/ServiceSetTest.tscn
```

Result: PASS, 203/203 functional E owners and all 18 refrigerators retained;
powered print, radio-off suppression, same-frame object response, HUD
replacement, non-locking behavior and the prior seating/support release contract
all pass. `MaintenanceCounterTest.tscn` and WalkTest FAST also pass. A FULL x8
/ 480 Hz attempt reached the mandatory 60-second watchdog without reporting a
result; its orphaned process pair was terminated and the run is not claimed as
evidence.
