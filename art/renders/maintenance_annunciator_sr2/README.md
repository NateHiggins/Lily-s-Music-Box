# SR2 — Lobby annunciator service

Production checkpoint captured 2026-08-24 at 2560×1440, Forward+, from
`MaintenanceAnnunciatorShot.tscn`. The subject is the actual `OtisProp` used by
`LobbyPorterBoard`, not a second proof-only mechanism. Its existing travelling-
car game remains on the `DispatchReach`; the new `CallHardwareReach` opens the
shared maintenance strip and can return only a mechanism result.

## Frames

- `00_stuck_flag_control.png` — frozen initial board: the first oxblood call
  flag is stuck proud, the silver contact bridge is crooked, and the common
  reset is at rest.
- `00b_stuck_flag_control.png` — frozen A/A control. Its SHA-256 is byte-for-
  byte identical to frame 00 (`672B34EF…130D2C2B`), so live lamps and animation
  contribute no noise to the comparison.
- `01_contacts_squared.png` — shared activity step 2/3, with the real silver
  contact bridge brought square. State is still preview-only.
- `02_common_reset.png` — shared activity step 3/3, with the call flags dark and
  common reset worked. The shot aborts after capture, proving this visual work
  can still restore rather than publish a false repair.

The `CAR / CALL` legend is physical world lettering on the production prop.
The paper strip is the already-landed shared presenter; SR2 adds no annunciator-
specific UI, job owner, case fact, Dream fact, or save record.

## Mechanical proof

- `MaintenanceActivityTest.tscn`: **PASS**, 33 checks. The authored three-step
  annunciator chain stays inside the ultra-short band and the shared run keeps
  its patch withheld until completion.
- `MaintenanceActivityLiveTest.tscn`: **PASS**, 12 checks. It proves distinct
  lift/service ray targets, preview/abort/commit ownership, one result signal,
  and boots `orison_root.tscn` to find the same two-target board in the actual
  lobby.
- Render command exited 0 with `[ANNUNCIATOR SHOT] 4 frames saved`; no script or
  rendering errors were emitted.

The activity layer still cannot advance a work order. `WorkOrders` remains the
only job-stage owner, and the lift game remains a separate interaction.
