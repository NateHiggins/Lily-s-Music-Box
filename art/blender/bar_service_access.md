# Retained Harukiya service access

Evidence class: **INERT**

The V2 bar keeps its original imported mesh, static collision, 29 source marker
owners, three doors and 18 fixtures. No Blender geometry or material is replaced
for this correction. The original 700 mm customer WC opening admits the 660 mm
player capsule when the existing leaf clears the jamb at 145 degrees. Its usual
100-degree pose projected enough of the leaf into the opening to stop passage.

**orison_v2_bar_wc_door.gd** retains DoorProp's input, hinge setback, leaf,
collision, tween and closed pose, overriding only the WC's open angle. No other
bar or building door uses the override. **orison_v2_bar_sink.gd** routes the
retained sink's generated primary interaction area to TapProp's existing
hot/mixed/off cycle; the inherited area handler only handled shower curtains.
TapProp remains the valve/water/sound owner. V1 uses the unchanged base scripts.

The pool inspection volume now fits the source **retail_bar_pool_body** at
source Godot **(-7.4,-1.95,31.25)**. Its retained helper predated the table's move
to the west bay; the room, table, gameplay owner and inspection text are unchanged.

**tmp/bar-access/route3.log.receipt.json** records 54 actual walking waypoints,
zero failures, ordinary input on both doors, all three tap states, actual ray
closure from the swung leaf and the return to Orison. The route captures were
inspected directly. Earlier failed discovery/test runs remain available and
are not acceptance. Before discovery is **tmp/city-architecture/bar-service-audit-2**;
after is **tmp/bar-access/route3**. The scratch 145-degree probe was manually
posed; the production route contains no pose override or interstage teleport.

The open leaf occupies the north/west side of the doorway, outside the WC.
The approach follows the clear north aisle instead of crossing the table/chair
row. Runtime geometry counts stay unchanged; this adds two narrow script adapters
and repositions one existing Area. Startup samples from the failed first focused
run and final run are available in their logs, but are not stable performance
comparisons or a performance acceptance claim. No new lights or optical policy
are introduced. Candidate-bound checks are **tmp/bar-access/verified/verification.json**.

Five individually reviewed WC/pool spatial references are appended; existing
manifest records and audit logic remain. Reader has zero new unread fields.
The city composition handoff records the preceding pushed candidate. Continue
bar seat/apparatus reach, service/storage and physical utility distribution;
this sanitary connection does not finish the wider infrastructure phase.

Published on canonical main as **3bdd7e5bf4a1d4876b0c3cc07efb8a4bc0fc6fac**.
Its complete clean baseline is **tmp/city-architecture/d5330a5-clean-board.json**.
The bound verifier repeats city composition, the 54-waypoint bar route, the
36-waypoint passage/reload route and the six title Continue checks, all with
zero failures. It records zero regressions, 17 protected paths, selector V2,
zero new unread fields and unchanged completeness counts. The complete clean
candidate board is preserved as **tmp/bar-access/3bdd7e5-clean-board.json**.
