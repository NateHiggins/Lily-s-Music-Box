# Dream reproductive path — v1

Production render, 2026-08-20. Fixed campaign seed `f123456789abcdef`, Mina
attachment, night 7. Captured by `DreamLineageShot.tscn` at 1280×720.

No helper environment, helper light or presentation geometry is present. The
frames use the real `DreamMazeRoot`, production player and service lamp.

- `01_brood_knot_lamp_on.png` — the generated brood knot and its descendant
  filaments under the service lamp.
- `02_brood_knot_lamp_off.png` — same seed, room and pose with lamp off. The
  physical descent disappears into the ruled dark.
- `03_birth_frame_into_child.png` — the nested birth-frame at a live aperture,
  with the next generation visible beyond it.

The form is one non-colliding `ArrayMesh` surface per live room. The flat-black
to hammered-gold change is the intended exposure read; the gold shader outputs
zero without lamp energy and is not self-lit.

`PERF_DREAM=1`, 2560×1440: 48 Klimt instances + 4 lineage-gold instances;
fresh paired runs ranged from 1.52–2.06 ms. The worst visible row was 54 calls,
23,053 primitives and 1.61 ms against the 16.6 ms gate.

Reproduce:

```powershell
$env:SHOT_DIR = 'C:\PleaseRemainOnTheLine\art\renders\dream_reproductive_path_v1'
.\Godot_v4.7.1-stable_win64_console.exe --path game --resolution 1280x720 res://tests/DreamLineageShot.tscn
```
