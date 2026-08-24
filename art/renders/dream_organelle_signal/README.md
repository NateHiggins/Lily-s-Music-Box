# DO-2 — local organelle signal proof

Captured 2026-08-24 in Forward+ through the production Dream hero, margin,
palp renderer, critter controller and ecology director, composed in the
existing Dream ecology stage.

## What the frames prove

- `00_control_A.png`, `00_control_A_repeat.png` — frozen arrangement, two live
  exposures, no packet.
- `01_hero_secretes.png` — hero contact has emitted one bounded secretion.
- `02_palp_probes.png` — one receptor palp has adopted the contact point.
- `03_contact_recognized.png` — actual contact has emitted recognition once.
- `04_fauna_presents_receptors.png` — a canonical rare crystal listener fans
  its twelve authored sensory structures upward; the low-social control does
  not answer.
- `05_neighbours_answer.png` — other margin tissue turns after the conduction
  delay, without a whole-body attention event.

The signal is deliberately not drawn as a beam, particle or UI glyph. What is
visible is each receiving organ's existing anatomy changing its work.

## A/A discipline

ImageMagick RMSE, normalized:

| Pair | RMSE |
|---|---:|
| frozen A / frozen A repeat | 0.0024524 |
| secretion / palp probe | 0.0250132 |
| palp probe / contact recognition | 0.0143985 |
| recognition / fauna receptor presentation | 0.00362865 |
| fauna presentation / delayed neighbours | 0.0280836 |

The fauna response is localized to the listener on the pedestal and is
visually inspectable in the paired frames; the other two anatomical changes
are more than 5.8× and 11.4× the whole-frame live-material floor. The A/A pair
is retained because Dream shaders use live `TIME` even while owner simulation
is frozen.

## Contract proof

`DreamEcologyTest.tscn` passes 50/50. Its DO-2 block proves:

- the exact twelve-key packet shape;
- secretion < adoption < recognition < fauna < neighbours;
- one recognition per contact target;
- low-social non-response;
- no global-attention seizure;
- no new `RealityState` key;
- 32 live slots after 40 long-lived emissions, with eight deterministic
  evictions.

Observed ordered clock in the acceptance run:

`41.33 < 41.38 < 41.43 < 41.48 < 41.94 seconds`

Commands:

```powershell
godot --headless --path game res://tests/DreamEcologyTest.tscn
$env:SHOT_DIR='C:\PleaseRemainOnTheLine\art\renders\dream_organelle_signal'
godot --path game --resolution 1280x720 res://tests/DreamOrganelleSignalShot.tscn
```

This is staged production-owner proof for DO-2. It is not DO-4's required
production-root sequence, does not add hazards/pursuit, and is not a completed
waking case loop.
