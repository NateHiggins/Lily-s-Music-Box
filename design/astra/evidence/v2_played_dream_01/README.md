# Autonomous Dream traversal harness — runtime pending

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
