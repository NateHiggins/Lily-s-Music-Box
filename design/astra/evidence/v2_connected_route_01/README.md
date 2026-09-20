# Actual connected interior / street / bodega return

`candidate_02.log`: 18 reached waypoints, zero failures, empty stderr. The fixture
starts once inside the V2 F01 core, walks through the lobby and vestibule onto
the +Z exterior, follows the existing named bodega route, opens the production
storefront via the player's actual ray/input, targets the real counter, and
returns through the same portal to the lobby. Movement, gravity and collision
remain active throughout. Counter/door screenshots retain the real player HUD.

The exterior uses the interior's sole player, job, inventory and shop service.
The test seeds an existing maintenance job's awaiting-part precondition through
its production authority. The bodega counter correctly refuses the hardware
shop's part without changing that job or inventory. No fictional purchase is
claimed. The same facts survive the physical return to Orison.

Candidate 01 exceeded a fixed six-second harness leg limit on an approximately
19-metre pavement segment. The shared movement driver now derives its time limit
from distance and ordinary walking speed, with bounded settling margin; arrival
tolerances and movement behavior are unchanged. Candidate 02 completes the leg.

This proves connected resident composition, not streaming, construction seam,
Passage/hardware-shop integration, complete errand gameplay or cutover.
