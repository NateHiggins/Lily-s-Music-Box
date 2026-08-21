# INC-V3 — Mina surface incarnation production proof

Captured 2026-08-21 on Godot 4.7.1 Compatibility / OpenGL 3.3 / RTX 4080
through the shipped `DreamMazeRoot`, room builder, service lamp, exposure field,
fauna director and material collector. No proof-only world, camera, light,
material, geometry, collision, hazard or save owner is present.

## Result

Mina's active presentation resolves five AI-source derivatives through the
shared profile/cache seam: blue-black ink fiber, erased stock, gilt edge, lens
membrane and THE ROOM AFTER THE CAPTION. The maintained shader include adds
editorial baselines, bounded empty fields, ink recession, blank mercy, a
stillness-only pressure change, family-specific fauna slots and grazing-only
ochre reflection. It reads only presentation, exposure, lamp response and
player velocity; Mina's annotation verb, case truth, maze plan, collision,
hazards, pursuit and save payload are unchanged.

The 17-map active bundle is exactly 100,663,284 lossless mipped bytes
(96.000004 MiB). Roughness is packed into shipped albedo alpha and height into
normal alpha, so the same auditable 17 resources consume nine incarnation
samplers rather than seventeen. Other cases are never loaded or substituted.

## Plates

- `00_control_a.png`, `00_control_a_repeat.png`: sequential A/A procedural
  control establishing the live-animation noise floor (mean absolute RGB
  delta 0.647/255).
- `01_mina_dark.png`, `02_mina_oblique.png`,
  `03_mina_molten_blank_mercy.png`: ordered production bands. Downsampled mean
  RGB is 0.300, 5.767 and 30.227/255 respectively.
- `04_blend_00.png` through `04_blend_04.png`: the continuous five-step field,
  with no material swap or gameplay boundary.
- `05_long_sightline_antitile.png`: hashed dual-orientation sampling breaks the
  one-metre source repeat over the long room view.
- `06_palm_control_moving.png`, `06_still_palm_pressure.png`: identical close
  framing around the stillness-only roughness dent. Their 3.319/255 mean delta
  is 5.13× the A/A noise floor.
- `06_reflected_world_grazing.png`: the empty-room plate contributes only as a
  blurred, warm-ochre grazing term at molten response. The legacy broad ghost
  projection is disabled for Mina so object silhouettes cannot become
  pseudo-annotation.
- `07_fauna_00_gilders_buttons.png` through `07_fauna_04_the_loupe.png`: all
  five existing production families use their profile-selected plate slot;
  their geometry, counts, ecology, danger and batches are unchanged.

Visual review found no readable text, person, face, old faceless figure or new
object fact in the shipped derivatives or final frame set.

## Reproduce

```powershell
$env:SHOT_DIR='C:\PleaseRemainOnTheLine\art\renders\dream_incarnation_mina_v3'
C:\devkit\bin\godot.cmd --path game res://tests/DreamMinaIncarnationShot.tscn
```

Focused contracts:

```powershell
C:\devkit\bin\godot.cmd --headless --path game res://tests/DreamIncarnationPlateTest.tscn
C:\devkit\bin\godot.cmd --headless --path game res://tests/DreamIncarnationTest.tscn
C:\devkit\bin\godot.cmd --headless --path game res://tests/DreamProfileTest.tscn
python art/tools/ingest_dream_material_sources.py --check
```
