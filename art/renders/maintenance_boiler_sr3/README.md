# SR3 — Boiler water-column service

Production checkpoint captured 2026-08-24 at 2560×1440, Forward+, from
`MaintenanceBoilerShot.tscn`. The subject is the actual `BoilerProp` used by
the production basement's `B1_BOILER_01`: the 1912 coal plant, its water glass,
two gauge cocks, blow-down lever, returning water and witness marker.

## Frames

- `00_service_control.png` — frozen operating plant before the activity.
- `00b_service_control.png` — frozen A/A control. Its SHA-256 is byte-identical
  to frame 00 (`262E30FB…0FF0FC30`), removing the plant's live fire, draft and
  audio animation from the visual comparison.
- `01_column_isolated.png` — step 1/4. Both brass gauge cocks are visibly shut.
- `02_false_column_empty.png` — step 2/4. The held blow-down lever is worked and
  the false column is visibly empty.
- `03_level_witnessed.png` — step 3/4. Water has returned and the witness is set
  to the honest level.
- `04_guarded_service.png` — step 4/4. Both passages are reopened at the guarded
  service detent.

The shot aborts after its last preview, so none of these staged frames publishes
a false boiler level. Only completion may set `water_level`, set
`column_proved`, return the cocks to service and emit one mechanism result.

## Mechanical proof

- `MaintenanceActivityTest.tscn`: **PASS**, 33 checks. The authored four-step
  chain remains data-owned, ultra-short and patch-withholding.
- `MaintenanceActivityLiveTest.tscn`: **PASS**, 18 checks. It proves radiator,
  annunciator and boiler preview/abort/commit boundaries, boots
  `orison_root.tscn`, and finds this same service reach on the production
  basement boiler.
- The final render command exited 0 with `[BOILER SHOT] 6 frames saved`, no
  leaked objects, script errors or rendering errors.

The shared presenter now offers an optional hold-progress preview callback.
It owns no boiler fact: the physical prop alone moves its temporary fittings
and consumes the final patch. `WorkOrders` remains the only job-stage owner.
