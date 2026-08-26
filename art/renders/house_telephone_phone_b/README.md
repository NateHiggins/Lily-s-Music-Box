# PHONE-B — the house board enters production

Production Forward+ proof on the real F01 west lobby wall. The board is centred
at building `(-5.05, -6.62, 1.42)`, above the 1.355 m dado and between the
existing Orison ad frame and the documented north end of its 2.72 m plaster run.
It adds an interaction `Area3D` and no blocking body.

The placement took three sheets:

1. The first context camera looked through the lobby corner and was rejected.
2. The second revealed the older ad frame's proud horizontal stay passing
   through the telephone jack field. Plan clearance alone was insufficient.
3. The accepted board is a tighter 660 mm instrument at `y=-6.62`, leaving
   about 630 mm between cases; its 160 mm case stands on shallow mounting cleats
   so the older stay terminates in open plaster instead of either object.

Frames and whole-frame RMSE against `00_board_control_a`:

- `00_board_control_b`: production temporal floor `0.00182147` (not zero).
- `01_west_wall_context`: accepted physical relationship to the older board,
  dado and north wall break.
- `02_4b_asking`: answering lamp, `0.0217605` (11.95× floor).
- `03_a_answered`: listening key thrown, `0.0151145` (8.30× floor).
- `04_b_carrying`: key plus hanging cord, `0.0189096` (10.38× floor).
- `05_released`: returned idle, `0.00348741`; no zero claim.

## Ownership correction

The approved brief called this slice “first report through iron.” Production
now makes that premise false in a useful way. The opening report is
`vantry_chirp_2a`, Mina's 2A chirp: her physical instrument is an intercom, not
a subscriber telephone. The paper is issued by `CoreLoopDirector`, presented
by the night register and accepted by `FirstShiftDirector`. Routing it through
the house board would duplicate a medium and teach the wrong network.

Therefore this checkpoint places and proves the ordinary house line without
connecting it to that report. `FirstShiftOpeningLiveTest` remains green. A
later subscriber slice must supply an actual telephone-origin fact before a
story owner may request this line.
