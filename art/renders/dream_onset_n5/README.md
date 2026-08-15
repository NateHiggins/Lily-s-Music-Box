# N5 gradual-onset production proof

Captured 2026-08-15 from `SleepOnsetShot.tscn` at the real F04 waking camera,
with the production CampaignShell, OrisonRoot, service radiophone and N5
screen-space treatment. The dream world is not instantiated in any frame.

The four frames are a same-process A/A/B/C:

- `00_control_a.png` — armed Mina request at pressure 0;
- `01_control_b.png` — identical control for the live-frame noise floor;
- `02_gradual_midpoint.png` — 1.30 / 2.60 seconds;
- `03_gradual_late.png` — 2.30 / 2.60 seconds, deliberately before entry.

The visual is meant to be recognisable without resembling damage or a horror
switch. Peripheral contrast and saturation withdraw while the central field
stays usable; the service set remains visible and controllable. The same scalar
low-passes the Master mix from 20.5 kHz toward 3.6 kHz, raises the existing Room
0 hum from silence, and lengthens the physical service-lamp recovery. No forced
head roll or FOV pulse is used.

Pixel control, measured with Pillow over the 1280 × 720 PNGs (RGB absolute
difference; `changed` means any channel exceeds 3/255):

| comparison | changed pixels | mean absolute channel delta |
|---|---:|---:|
| control A → control B | 0.16% | 0.13/255 |
| control A → midpoint | 27.52% | 2.02/255 |
| control A → late | 41.75% | 3.40/255 |

The maximum deltas are dominated by the still-live carried-object/rain flecks;
the A/A floor prices that movement. The onset signal is 172× and 261× the
control's changed-pixel share at midpoint and late respectively.

Reproduce with one Godot process:

```powershell
$env:SHOT_DIR='C:\PleaseRemainOnTheLine\art\renders\dream_onset_n5'
Godot_v4.7.1-stable_win64_console.exe --path game `
  res://tests/SleepOnsetShot.tscn
```
