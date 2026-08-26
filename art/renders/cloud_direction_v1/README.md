# Direction-space lower cloud proof

Fixed production camera: `04_roof_skyline`, forced night, public weather
simulation presets, seed `19280731`. Captured through
`tools/run_godot_serial.ps1` with one Godot instance at a time.

## Plates

- `clear_night/04_roof_skyline.png` — zero-cloud control. The measured Milky
  Way and catalog stars remain unobstructed.
- `scattered_night/04_roof_skyline.png` — accepted 38% coverage claim. Broad,
  overlapping bodies remove stars in irregular cells while leaving large clear
  holes. No azimuth/elevation grid is visible.
- `scattered_night/04_roof_skyline_linear_alpha.png` — rejected predecessor.
  Its valid coverage mask was nearly invisible because a low-cloud report was
  treated as linear alpha.
- `overcast_night/04_roof_skyline.png` — 100% coverage proof. The closed deck
  prevents stellar leakage while the independent relief channel keeps the
  underside from becoming a flat card.

## Measurements

ImageMagick normalized RGB RMSE, same 1280x720 production output:

| Comparison | Whole frame | Sky crop (1280x330) |
| --- | ---: | ---: |
| clear → accepted scattered | 0.0159272 | 0.0217752 |
| rejected linear alpha → accepted scattered | 0.00827267 | 0.0121970 |

The test contract supplies the exact floor that photographs cannot: the clear
preset reports both zero coverage and zero strength, so its optical depth is
mathematically zero. The claim does not add a texture, volume, node, light or
shadow caster; the cloud field remains part of the existing sky draw.
