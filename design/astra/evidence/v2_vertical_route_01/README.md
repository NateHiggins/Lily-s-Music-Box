# Real primary and service stair traversal

The first production-player climb stopped below the stacked flight: each tread
was a full-height solid down to its flight base, creating a false low ceiling.
Treads now have one riser's thickness; authored rise/run, landing dimensions and
traversal ramps are unchanged. This repairs physical geometry, not player height,
collision, gravity or step limits.

Rendered `candidate_03.log`: 61 reached waypoints, zero failures, empty stderr.
One initial F01 placement precedes normal-controller movement up through F03 to
F04 and back; the route visits the 3B public approach, navigates the F03 riser
bypass, climbs/descends the service stair, and descends to B1 before returning.
The JSON retains every target and actual position with height/collision checks.
No teleport follows initialization, and no jump, noclip or physics freeze is used.
Candidate 01 preserves the original headroom failure; candidate 02 is the narrower
31-waypoint primary-stair pass. A two-line explanatory source comment was added
after candidate 03; no geometry behavior changed after that capture.

`blockout_fixed.log` passes with empty stderr. The old suite had eight stale
inventory expectations from before 3B and incorrectly placed all stations at F04
height. It now checks the current explicit inventory and resolves each station's
declared floor before capsule testing. Its existing continuous F04 bedside walk,
clearances, window/partition rules and protected V1 layout hash also pass.

These results do not establish guard collision, finished stair art, elevator
operation, F05/F06/roof, complete B1 program or a full golden shift.
