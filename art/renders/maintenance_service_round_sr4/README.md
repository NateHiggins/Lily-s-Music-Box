# SR4 — first resident-filed service round

Production Forward+ proof captured 2026-08-24 through
`res://tests/MaintenanceServiceRoundRouteShot.tscn`, using the production
`orison_root.tscn` and the serialized Godot runner.

## What the frames prove

- `01_no_call_control_a.png` and `02_no_call_control_b.png` are the unchanged
  no-call A/A pair. The sampled mean RGB delta is 3.74 and 14.77% of sampled
  pixels clear an 18/765 delta threshold: the live building, lighting and held
  object establish a substantial animation/noise floor before any SR4 claim.
- `03_lena_line_waiting.png` is the same production camera after Work Order 001
  closes. The held Vantry 28-R carries a persistent physical slip naming Lena,
  2B and `PRESS R`; the amber order jewel is live. Against control A, sampled
  mean RGB delta is 12.22 and 74.62% of pixels clear the same threshold.
- `04_lena_call_answered.png` shows the protected resident-filed call and the
  newly issued `WORK ORDER 002 — BORROWED BREATH` objective together.
- `05_lena_threshold_conversation.png` shows the distinct resident visit. Lena
  names the diagnostic order—vent, call contacts, boiler glass—and the
  objective sends the player out through the building rather than chaining
  props in a test shed.

The radiator, lobby annunciator and boiler visual/mechanical claims remain
proved by the approved M1, SR2 and SR3 sets. This set proves only SR4's new
production surfaces and route boundary; the executable route is the stronger
proof for later beats.

## Executable proof

- `MaintenanceServiceRoundTest.tscn`: PASS, 13 checks. It rejects SR4 before
  Mina's job closes; rejects apparatus activity before Lena; rejects a
  basement-first shortcut; requires apartment → lobby → basement evidence;
  admits one radiator repair; and leaves the repaired job open until the
  deliberate resident reply.
- `MaintenanceJobTest.tscn`: PASS, including strict two-job schema coverage and
  all three SR4 production anchors.
- `MaintenanceActivityLiveTest.tscn`: PASS. It boots `orison_root.tscn` and
  proves the route binds the production 2B radiator, lobby porter board and
  basement boiler.

`ServiceRoundDirector` stores no lifecycle. It translates the established
call, resident and mechanism signals into legal public `WorkOrders` calls.
SR4 creates no Dream owner or Dream fact; SR5 remains the shared-organism
interruption/answer inserted into this waking route.
