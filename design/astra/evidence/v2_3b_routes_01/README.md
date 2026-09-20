# 3B production doors and continuous domestic route

Four semantic openings now mount existing DoorProp leaves: entry, kitchen
service, alcove and bath. Opening frames remain construction-owned. The loader
removes only each mounted world's placeholder hinge and preserves dimensions,
household identity and inward swing into the corresponding room. Leaf names
are unique for spatial audio. Other V2 doors and V1 are unchanged.

Rendered `candidate_03.log`: 51 checks, zero failures, empty stderr. One initial
placement on the F03 service crossing precedes a continuous ordinary-controller
walk through entry, main, kitchen, alcove, bath and service exit. The test uses
normal movement input, gravity and collision, with no subsequent placement,
noclip or disabled physics. Actual player rays and prompts acquire four closed
doors, the bench lamp, wardrobe and WC; real input opens/operates them. The
route JSON records achieved positions; native screenshots retain the actual HUD.
The first route exposed an open-entry-leaf obstruction to an immediate turn;
walking beyond the leaf before turning gives a clear route without shrinking
the player or disabling collision. Candidate 01 was stopped after a parse error;
candidate 02 preserves the failed early turn. Only candidate 03 is accepted.

`composition.log`: previous 374 connected-world checks still pass, empty stderr,
including two reconstructions and all room-switch input checks. Both runs used
the unchanged exclusive Godot runner. Source hashes bind candidate 03.

This proves the bounded domestic route, not F03 vertical travel, complete case
play, all appliance interactions, persistent domestic state, full visual art
acceptance, performance or V2 cutover. The sleeping/wardrobe area remains visually
plain and the held-device note can overlap the prompt during rapid interactions.
