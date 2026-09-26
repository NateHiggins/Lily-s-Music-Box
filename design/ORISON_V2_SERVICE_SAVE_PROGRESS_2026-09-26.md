# V2 completed service restoration

Evidence class: **INERT**

REPORT - V2-SERVICE-SAVE - 2026-09-26

Branch / base / origin/main at start / merge-base: main /
ed17485c043dd68de32c5d573aac8783480bfdac (all three references).
Implementation HEAD is the commit introducing this report.

## Change and ownership

The completed basement fuse and roof tank repairs previously disappeared when
the building was rebuilt. The existing household-state adapter now records two
boolean completion facts through RealityState. The production mechanisms and
maintenance director still decide whether service succeeded; no new job, case,
power network, water network or disk writer is introduced.

Restoration uses the existing authored completion patches and each mechanism's
snapshot-restoration method. It does not replay completion events. Temporary
slider positions and an unfinished attempt are never saved as completed work.
Loading another state closes any previous service panel before restoring the
mechanism, preventing a later cancellation from undoing the loaded result.
Missing records use the original faults. Existing schema-1 control records and
the campaign file format are retained; malformed completion values are refused.

## Validation

The focused real-save regression completes both production activities, saves
through the actual disk path, destroys the world, reloads and constructs new
physical mechanisms. It also checks unfinished saves, abort, legacy records,
malformed values, mid-session load with an open preview and teardown. The first
run passes 131 checks with no script errors after two serial imports.

The basement route passes 88 live waypoints, including the actual fuse reach,
service completion, doors and lower service stair. The windowed roof route
exercises the existing tank activity and captures its dry, serviced mechanism.
The rendered fuse and tank approaches were inspected. Four references to the
existing service anchors are registered in the spatial manifest without
changing previous classifications. The reader reports zero new unread fields.

Logs and adjacent suite-run receipts are under tmp/v2-service-save. These are
scoped regression results, not runtime-contract promotion or campaign acceptance.
The owner's four render files remain outside this change.

## Remaining scope

These two optional services do not advance the Mina case or control apartment
utilities. Architectural lift suspension and broader campaign content remain
separate work. Existing H23 seams and historical M11C1 receipt debt are unchanged.

No owner decision is required for this change.
