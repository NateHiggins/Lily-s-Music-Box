# 4B east enclosure and authored wake view

## Runtime follow-up (base 7c0b5c2)

boundary_02 exposed a Godot type-inference error in the new test's room
variable. It now explicitly declares Node. Only the verified owned test
processes were stopped; the failed log is retained.

boundary_03 passes 36 checks, including all three east-wall collision rays,
the eight normal controller waypoints, two physical switch presses, actual
Dream/V2 replacement, subject release and disk reload. Its actual wake image
shows the exposed-sky gap replaced by the room wall. Stderr is empty.

The V2 return anchor now optionally supplies a world-space facing position
above the semantic bed. CoreLoopDirector applies it through the player's
face_world_point method after the existing placement and velocity reset.
The method keeps the body level and aims the camera at the authored subject.
Legacy anchors have no facing field and retain their previous orientation.
No campaign facts, Dream outcome, return position or selector defaults change.

boundary_04 passes 37 checks with empty stderr, adding a direction check on
the actual wake camera before any review staging. The inspected earned_wake
image now faces the physical bed. This improves orientation after returning;
the room's material, furnishing and window presentation still need finishing.

The first legacy CoreLoopTest attempt was refused because another Godot run
acquired the lane. After it exited, core_loop_02 passed with empty stderr,
including the new assertion that a legacy return preserves orientation.

## Initial source checkpoint

Base 1537018. The preceding earned_wake capture exposed sky beside the bed.
Source inspection found that F04_B_ALCOVE omitted its east wall, relying on
the approach room's west wall. That room ends at z=8.25; the alcove continues
to z=11.65, leaving 3.4 metres of its boundary unbuilt.

The alcove now owns its complete east wall. The approach relinquishes its
west wall to avoid duplicate geometry. Their existing opening is narrowed
from 2.4 to 1.8 metres at the same centre: its former z=[6.05,8.45] aperture
exceeded the shared z=[6.35,8.25] boundary. The new z=[6.35,8.15] aperture
fits. Bed, wake, fixture and switch anchors, windows and doors are unchanged.

source_checks.json records the failing old conditions and passing new ones.
The updated earned boundary test adds collision rays across the formerly open
east boundary at z=8.3, 8.9 and 10.8 and requires the alcove to own the hit.
Its existing eight walking waypoints, actual switch interactions, Dream/wake
transaction, lifetime and disk checks remain the required runtime regression.
The script passes independent gdtoolkit syntax parsing.

The serial runner refused before launch because Jawbreaker Godot processes
7800 and 29372 were active. No new runtime or rendered pass is claimed.
Next run OrisonV2EarnedDreamBoundaryTest through the unchanged serial runner
with V2_EARNED_SAVE pointing to v2_wake_caption_verification_01/
earned_regression/captures/earned_dream_pending.json. Inspect earned_wake and
bedside_review, all three boundary rays, the walking route and stderr.
V2 remains unfinished; this is not room visual acceptance or default cutover.
