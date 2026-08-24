# DT-5 — LOCAL EMERGENCE PRESSURE

The procedural tentacle now makes the existing `LivingField` swell around its
membrane while it crosses into our slice. This is temporary body volume, not
contact conversion: it creates no agents, adds no stain, owns no save record
and relaxes through the field's ordinary decay after the limb stops pressing.

## Production proof

[`contact_sheet.png`](contact_sheet.png) is one Forward+ production
`OrisonRoot`, the procedural limb, the bound storey field, the real 2A room and
the player's own lamp. The harness disables only automatic pressure during
setup. Once the limb is present it freezes simulation and shader time, records
two null controls, applies one production-strength `LivingField.pressurize()`
write at the membrane and explicitly uploads one complete field volume pass.

The write touched 14 half-metre field cells. The full-frame normalized RMSE is:

| comparison | RMSE |
| --- | ---: |
| control A / control B | 0.000263546 |
| control A / pressure | 0.002849020 |

Treatment is **10.81×** the live-render A/A floor. The contact sheet includes
both differences at 5× gain; change remains confined to the field-sampled
surface around the emergence instead of moving the camera, lamp or limb.

Source frames are `control_a.png`, `control_b.png` and `pressure.png`.
`diff_aa_x5.png` and `diff_pressure_x5.png` are derived inspection aids.

## Contracts and tests

- `LivingFieldTest.tscn`: 18/18. Pressure adds temporary body with zero agents
  and zero stain, then decays to zero when unfed.
- `DreamTentacleTest.tscn`: 22/22. The production emergence reaches pressure
  peak 1.00 and performs 36 field writes through the existing shared owner.
- CPU frame in the focused production behavior run: 0.647 ms, below the
  existing 1.2 ms limit.

This closes only DT-5's local swelling beat. Behind-membrane search,
progressive membrane release and the final six-beat emergence proof remain
open; this is not a waking case-loop claim.
