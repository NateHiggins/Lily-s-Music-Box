# Autonomous Dream traversal and live-run repairs

## Executed follow-up (base 5e790a4)

All runs use the unchanged serial runner and 180-second ceiling. No direct
Dream ending, teleport, manual pursuit/hazard stepping or time-scale override
was used in the played driver.

- run_04: initial walking driver travelled 2.85 m in one room before natural
  capture; 50 checks passed. This was insufficient doorway traversal evidence.
- run_05/06: normal run input and doorway selection away from the pursuer
  reached two rooms over 7.51 m. The actual signal-trunk hazard ended the run
  through contact. run_06 records 1.333 seconds of warning against .9 required,
  and passes 52 checks with empty stderr.
- run_07: responding to the perceived TRUNK HISS through normal lamp_toggle
  input allowed about 61 m of travel. It exposed a real live-pocket overflow
  (36.1 by 52 m versus a 48 m tile) and a hollow-runner impact after only .5667
  seconds of its .75-second warning. The failed assertion and warning remain.
- run_08: after the fixes below, 61.44 m across six rooms, one natural capture,
  then actual V2 wake, eight ordinary bedside/switch waypoints and disk reload.
  All 53 checks pass and stderr is empty. The runner records .7500 seconds of
  warning. The lamp-on trunk contact and lamp-off escape are distinct played
  controls; neither proves every maze route or every case.

The driver now samples every newly entered room as well as periodically and
records the field's actual perception/impact logs. Doorway choice reads the
navigation graph and pursuer position; the reactive lamp input reads the
perceived hiss. This is an automated movement route, not a blind human test.
Dream and waking captures were inspected; no new S2J/human art approval is
claimed.

### Production fixes

DreamHazard now enforces the authored minimum warning before non-positional
contact can latch, including late-loaded rooms reached at running speed. The
existing physical void/fall branch remains unchanged. DreamHazardTest adds
the observed short-warning case and passes 45 checks. Its only stderr warning
is the existing intentional attempt to commit contact without a campaign shell.

DreamExposureField grows from 96 to 192 cells in each horizontal direction,
retaining .5 m cells, eight vertical layers, accumulation rates and gameplay
readers. The tile now spans 96 m. DreamExposureTest adds the observed pocket
and passes 36 checks; its intentional 100 m overflow control still warns.
The RG8 volume grows from 147,456 to 589,824 bytes, with corresponding 4x
storage/upload work. Full release performance is not established here, and
the overflow diagnostic remains active for larger future pockets.

## Original source checkpoint

Base 308648b. OrisonV2PlayedDreamTest extends the existing earned-save boundary
test, substituting ordinary controller movement for its direct contact outcome.
The shared test now uses an overridable completion hook and stops cleanly if
completion fails, rather than dereferencing a missing waking root afterward.

The new driver starts at the real Dream spawn after the genuinely earned
request. It reads the live room builder's doorway routes and presses forward
with ordinary collision. Pursuit, hazards, lamp and the authored run clock stay
autonomous. There are no position assignments, direct end_dream calls, manual
pursuit steps, forced contact or time-scale changes in the played driver.
It records room keys, movement distance, collision state, periodic images and
the actual dream_ended event. A 40-second wall-time limit bounds the test and
fails without inventing a successful outcome.

The check requires actual movement, normal collision, exactly one natural
outcome and waking reconstruction. It then inherits the verified 4B wall,
orientation, eight-waypoint movement/switch, lifetime and disk-save checks.
Recorded room count and captures will establish how much of the passage was
actually traversed; one successful outcome will not prove every Dream hazard
or a complete visual acceptance of the maze.

Both scripts pass independent gdtoolkit syntax parsing. Source guards confirm
the absence of the listed direct-outcome/teleport/manual-step mechanisms.
The serial runner refused the first attempt while Jawbreaker test_world_shape
was active. No new gameplay run or pass is claimed.

Next run OrisonV2PlayedDreamTest.tscn through tools/run_godot_serial.ps1 with
the unchanged 180-second ceiling. Set V2_EARNED_SAVE to
v2_wake_caption_verification_01/earned_regression/captures/earned_dream_pending.json.
Inspect stderr, played_route.json, result.json and the actual captures. Fix
any navigation/runtime failure before calling the played route verified.
