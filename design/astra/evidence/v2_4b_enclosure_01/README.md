# 4B east enclosure correction — runtime pending

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
