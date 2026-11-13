# Door passage

Lily's November 13 direction is recorded in Bible VIII.5.l and RUL-018.
This is the door-specific exception to grab-and-drag controls.

Walk toward the opening. The player guide aligns the ordinary capsule, waits
outside the swing, asks the door to unlock/open using the character's own key,
then guides movement past the frame and leaf. Look remains free. Release or
reverse the direction to cancel; dialogue, inspection and seating also cancel.
The guide changes requested movement, never the character's transform or
collision exceptions. Walls, people, carried stock and missing floor remain
real constraints.

Click the leaf to open or close it. Click the keyhole to lock or unlock it;
the existing keyboard/controller key action remains available. Automatic
unlocking is remembered by DoorKeyring and does not silently relock later.
A visitor without the appropriate key cannot pass a locked door.

Ordinary doors remain open until someone explicitly closes them. The roof's
mechanical closer retains its arm, port, catch and proof requirements. Active
passage briefly holds that closer; completed/canceled passage releases the
hold. The weak lease expires if its controller disappears. Occupants and a
deployed hose still prevent an unsafe close.

Owners:

- DoorProp: leaf motion, sweep clearance, lock request and passage holds.
- DoorPassageGuide / PlayerController: directional player steering and input.
- Orison V2 resident route: existing graph, capsule, access and animation route.
- DoorKeyring / household state: durable locks and leaf angle.
- Orison V2 door check: actual return mechanism.

Focused tests are DoorPassagePolicyTest, DoorPassagePlayerTest, ResidentKeysTest
and OrisonV2MinaDoorSafetyTest. Installed route, closer and hose tests remain
separate qualifications; passing the isolated fixtures does not certify every
building doorway or artistic/game-feel acceptance. Current receipts and open
qualification are in HANDOFF.md and TASKS.md.
