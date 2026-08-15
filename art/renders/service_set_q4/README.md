# Q4 — Vantry service-set production proof

Generated 2026-08-15 from the production building and actual player camera.

| Frame | Proof |
|---|---|
| `01_carried_lamp_on.png` | normal carried back, green NET and red LAMP, warm work-light pool |
| `02_carried_lamp_off.png` | same station and pose family, lamp circuit and pool off |
| `03_front_order_lit.png` | speaker, carbon mouthpiece, attached lamp and authoritative amber ORDER jewel |
| `04_back_mod_indicators.png` | owner-amended NET/LAMP service telltales and 1924 rebuild plate |

The front/back frames use `ServiceSetCarrier.set_proof_pose()` in the shot
harness only. Production carry always uses pose zero.

Run one Godot instance at a time:

```powershell
$env:SHOT_DIR=(Resolve-Path 'art\renders\service_set_q4').Path
C:\devkit\bin\godot.cmd --path game res://tests/ServiceSetShot.tscn
C:\devkit\bin\godot.cmd --headless --path game res://tests/ServiceSetTest.tscn
$env:WALKTEST_SCALE='8'
C:\devkit\bin\godot.cmd --headless --path game res://tests/WalkTest.tscn
```

Settled focused result: `ServiceSetTest` PASS, 203 functional E owners, 18
fridges, no production PhoneCarrier/Phone3D, no screen SubViewport in the
physical set. WalkTest PASS at x8 / 480 Hz.
