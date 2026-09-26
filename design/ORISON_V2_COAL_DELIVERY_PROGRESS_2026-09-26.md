# V2 coal delivery architecture

Evidence class: **INERT**

REPORT - V2-COAL-DELIVERY - 2026-09-26

Branch / base / origin/main at start / merge-base: main /
8b5de73ee0bbd6acff62d08f2d988db97949a9a4 (all three references).
Implementation HEAD is the commit introducing this report.

## Construction and ownership

The basement coal room extends to the south exterior wall. Its fuel heap
and bunker anchor move toward that wall, leaving the existing boiler door and
firing route clear. A Blender-authored, 45-degree sheet-metal chute connects
the bunker to a closed coal-hole cover on the street. The cover reuses the
existing assembly in build_orison.py; the standalone exporter executes only
that assembly and adds the gravity run. Materials retain catalogue identities.

The raised delivery aperture preserves the solid wall below it. Generic
openings now consume their optional sill height, defaulting to the existing
zero-height threshold. Negative and above-storey sills fail validation before
construction. This does not change any existing door, interlock, boiler owner,
fuel state, save schema or protected spatial authority.

The cover stays closed and walkable. This is a physical delivery connection,
not a coal-delivery activity, animated fuel transport or an inventory producer.
Regenerate with Blender -b -P art/blender/scripts/build_coal_delivery.py, then
double-import through the approved Godot lane. The completion-interiors source
and its existing projector own the room, heap, anchor and wall aperture.

## Verification

Logs, windowed frames and adjacent suite-run receipts are in tmp/v2-coal.
The first route never started because of a test type-inference error and was
terminated at the runner ceiling; it has no suite verdict. The second exposed
a route turn against the open boiler-door tip. Its rendered street frame also
exposed chute metal protruding beside the cover. The route now clears the
door tip before turning, and Blender trims the chute shell below the pavement.

The corrected route3 passes 32 ordinary-input waypoints from the lobby to the
street cover, down the public stair, through both production service doors,
into the bunker and back to the boiler approach. Physics rays verify the
actual open delivery aperture, retained solid sill and imported cover collider.
The corrected cover and basement chute frames were inspected. The focused
test also guards the imported shell's upper bound and records a wider view;
route4 passes all of those checks and its frames were inspected. The full
basement suite passes 88 waypoints, including storage, fuse maintenance and
the lower service stair.
Blockout passes 2,073 checks, including malformed-sill mutations. Both imports
of the corrected asset pass. The working gate board has zero regressions
against the clean 8b5de73 baseline and the reader has zero new unread fields.
Six reviewed spatial dependencies are admitted without reclassifying old ones.

This report makes no runtime-contract or acceptance promotion. Historical
evidence remains unchanged. The owner's four render files are excluded.

## Remaining limitations

Modeled ventilation branches and lift ropes/counterweight remain unfinished.
The first Mina campaign slice remains the supported story loop; existing fuse
and roof-tank maintenance retain local instance state. Primary voxel lighting
remains beam-local, not whole-building indirect illumination. H23 seams and
historical M11C1 receipt-hash debt remain separate from these construction checks.

No owner decision is required for this installation.
