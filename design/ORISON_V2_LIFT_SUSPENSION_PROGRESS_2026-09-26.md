# V2 passenger lift suspension

Evidence class: **INERT**

REPORT - V2-LIFT-SUSPENSION - 2026-09-26

Branch: main. Architecture base: a5c716c, following the verified and pushed
1e8174c846efb96352033ffe476ec05caf179b07. Remote main at the start of this
installation was 1e8174c. Implementation HEAD introduces this report.

## Construction and authority

The existing Blender lift-drive source now builds four parallel suspension
ropes, the traction wrap, two grooved deflectors, a car crosshead, a framed
counterweight and fixed guide channels for both moving assemblies. The
counterweight occupies the gap between the cabin rear and the shaft wall.
The motor, sheave, guard and catalogue materials retain their established form.

The roof source partitions its public landing slab around two narrow rope
openings. The machinery foundation has the matching car-rope opening. Both
penetrations remain inside the fixed guard; no public path crosses them. The
guard's front extension was checked against the actual 0.33-metre capsule,
rather than assuming a smaller controller. The stair and door routes remain
outside its collision envelope.

The production passenger car remains the only travel authority. The visible
car crosshead, rope lengths, rotating sheaves and opposite-moving counterweight
read its current position. No independent integrator, fault controller, call
queue, interlock, repair activity or save record is added. The counterweight
has a matching moving collision body; guide channels have static collision.

## Validation and corrections

Artifacts are under tmp/v2-suspension, with logs and adjacent suite-run receipts.
Each regenerated GLB was followed by two serial imports. The first route caught
a guard-stop expectation based on the wrong capsule radius. The revised guard
preserves the roof approach and its stop is measured against the production
controller. Imported scene ownership is cleared before moving the counterweight
under its collision body, avoiding a stale scene-owner warning.

The third route completes 16 live walking waypoints and 2,062 real-physics
clearance samples while the existing car travels F02 to F06, B1 and F01. It
checks opposite counterweight travel, constant vertical rope length, both actual
roof penetrations, the closed guard, the bulkhead door and return to F06.
The roof gameplay view and supplemental shaft inspection render were inspected.
The shaft view temporarily moves the camera; it is not evidence of a player
route into the inaccessible well. The fourth run also passes using the imported
mesh bounds themselves for 2,062 continuous clearance queries, including the
counterweight hitch and car mounting shoes. Sheave directions follow their
respective rope tangents.

The passenger route passes 64 waypoints, including every landing and B1. The
roof circuit passes 47, including both bulkheads and the existing tank service.
The primary-lamp comparison passes all three night stations with room fixtures
off: measured linear crop gains are 0.198 in the home, 0.320 on the roof and
0.025 in the basement. The basement frame was inspected. The gate board reports
zero regressions against the clean 1e8174c baseline; the reader reports zero
new unread fields. Only two reviewed test-floor references are added to the
spatial manifest, with no previous classifications weakened.

These are scoped construction and regression checks, not runtime-contract or
acceptance promotion. Historical receipts are unchanged. The owner's four
render files remain outside this change.

## Remaining scope

Suspension follows the existing kinematic lift; rope stretch, load-dependent
motor dynamics and a new servicing procedure are not simulated. The first Mina
shift remains the supported campaign slice. The primary optical field remains
beam-local. Existing H23 lighting seams and M11C1 historical receipt debt are
not claimed fixed by this installation.

No owner decision is required for this installation.
