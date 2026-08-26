# Cloud light and dry-overcast proof

Fixed production camera `04_roof_skyline`, forced day, seed `19280731`.
Every frame used the public weather simulator and the serialized Godot runner.

## Accepted argument

- `clear_day` is the zero-cloud control: direct transmission `1.0`.
- `overcast_day_accepted2` is dry 100% cover: direct transmission `0.12`.
  The Environment's diffuse fill remains, so facade form softens instead of
  going black. The window grid remains visible because dry cloud no longer
  impersonates ground fog.

Normalized RGB RMSE is `0.183818` whole-frame, `0.269862` on the 1280x330 sky
crop, and `0.0514345` on the 1280x400 scenery crop. These are presentation
states rather than an A/A mutation claim; the exact control floor is the tested
coefficient (`coverage 0.0 -> transmission 1.0`).

## Rejected iterations retained

- `overcast_day`: relief spanned 0.72–2.07 times the fog key and photographed
  as charcoal ink beside blown white paint.
- `overcast_day_tuned`: relief was compressed too far and became a flat card.
- `overcast_day_tuned2`: accepted relief range, but the old cloud-driven fog
  multiplier still bleached the distance.
- `overcast_day_accepted`: first dry-fog separation; still too aggressive.
- `overcast_day_accepted2`: accepted 0.78–0.84 low-cloud fog band.

Rain/storm and WMO fog codes 45/48 retain the separate extinction term. One
DayNightDirector still owns the Environment, the only exterior directional key
and the sky material; this work adds no light, volume, texture or persistence.
