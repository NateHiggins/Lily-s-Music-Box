# Measured roof access repair and spatial publication

Evidence class: **INERT**. Diagnostic and implementation report; no room promotion.

The failed combined cohort exposed a bad roof waypoint, not a missing passage.
Its nominal **(5.0, 19.2, -3.4)** sent the player across the formed fire cabinet
and riser at the top landing. The real player stopped at approximately
**(4.8041, 19.2008, -3.2638)**. Actual slide contacts identify the cabinet leaf
and native pipe. A full standing-capsule probe found all 180 clear sampled cells
connected, including a usable corridor south of the case. The old x=5 target
also crowds the east wall.

The route now walks across the existing landing through **(3.975, 19.2, -3.0)**
and **(4.9, 19.2, -3.0)**, then uses x=4.9 on the east return strip. Reverse
travel uses the same measured bypass in reverse. The existing roof-floor rays,
normal controller, collision mask and endpoint tolerances remain. Cabinet/riser
geometry, positions, collisions and mechanical owners are unchanged. The common
roof-route helper serves the plant, lift and related inherited circuits.

**roof-probe2** completes the crossing and return through ordinary controller
movement: eight actual waypoints, zero failures, 147.87 seconds. It retains the
real **0.33 m radius / 1.524 m standing-height** capsule. Both overhead diagnostic
frames were visually inspected. Green markers indicate standing clearance; red
markers indicate contact or missing support. They are diagnostic geometry,
not new world props. This small pass is not the complete roof-circuit proof.

## Lamp regression expectation

The old roof assertion expected the carried light to stay parallel to the camera
and checked unit rotation in its local frame. The production offset emitter now
converges on viewed work and compensates parent-frame drift in world space.
The independent probe measured world determinant **1.0**, local determinant
**1.00001276** and focus alignment approximately **1.0** after actual walking.
The local assertion could therefore fail while the physical light was correct.

The test retains its injected scale drift and original numerical tolerances,
but checks the resolved world rotation and an independently raycast work point.
Both assertions pass in the same full-size roof diagnostic. No lamp, optical,
electrical, camera or interaction production authority was changed.

## Failure retention and bounded replay

**all-home1** completed at exit 1 in **1,281.24 seconds**, with **1,704 checks and
12 failed observations**. It finished 18 apartment/completion/remaining-home legs;
its claims include 122 rooms from those legs and one roof-core witness. The
aggregate still failed. Two lamp assertions and the blocked roof leg caused the
remaining completion/coverage failures. No successful leg was promoted from
its logs, captures or failed contract. Exact original contract, wrapper, log bytes
and all 24 bound test sources are retained under **failed_all_home**.

The four-family aggregate scene is retired. Its historical source and receipt
remain recoverable. The two existing bounded home and upper cohorts retain all
four original families and declared starting placements. They are being replayed
with source freeze; first-slice authority, public landing, service circulation
and exterior runs follow through the lane and stop on a failure.

The bounded **home2** replay subsequently passes **62 rooms, nine legs and 909
checks**, zero failures, in **466.96 seconds**. The checked publisher validated
the actual packet and published its original test-written contract, matching
wrapper and byte-verified logs to **access_home_cohort_20261018**. The prior packet
is preserved under **previous_home_packet**. The existing home checkpoint is
renewed for only its actual room witnesses. Upper/roof and the later authority,
public, service and exterior proof results remain pending.

## Checked publication

**tools/publish_v2_spatial_packet.py** validates current source-bound played-room
claims, any additional typed connections/regions, matching wrapper provenance
and original raw-log hashes. It preserves the preceding files, copies the
unmodified receipt bytes and installs the contract last. It never manufactures
or repins evidence. Archives are tied to one incoming contract; retries preserve
the same prior bytes and new runs require a fresh archive. Captures remain
optional diagnostic records, never human acceptance.

Eleven tools tests cover exact byte preservation, safe retry, stale helpers,
unplayed rooms, failed wrappers, altered logs, path/capture restrictions, archive
corruption, independently validated connection/region claims, portable compressed
logs and changed inputs without receipt repinning. The publisher also refused
the actual failed **all-home1** contract and created no destination packet.
Reader baseline remains zero NEW unread fields. Roof source-binding preflight
passes. The composed surface qualifier independently remains **PASS, zero
defects** after these route-only changes; its declared rendering inputs did not
change, so no unchanged 16-minute surface run was repeated.

Review: **art/reviews/v2_roof_access_repair_20261020/index.html**. Wrapper receipts
are **suite_run**, not runtime-contract proof. Seven existing Texture RID shutdown
warnings remain outside this bounded diagnostic's retirement claim.

REPORT - V2-ROOF-ACCESS-REPAIR - 2026-10-20

Branch/source parent: **codex/v2-fire-fitting-checkpoint / e7c97ae3**.
Origin/main and merge-base: **82887a14**. Shared main is preserved and not yet
integrated. Protected 17/17 are outside this change; selector remains V2 with
explicit V1 rollback. Checkpoint paths are named; the active lane batch is a
verification job, not an asserted pass.
Ledger before -> after: **7/42/110/8/134/136 -> 7/41/98/8/122/124**.
The renewed executed home proof changes 15 requirement statuses; its exact
before/after list is retained in **home2-ledger-delta.json**. This inert report
does not itself grant those changes. Main baseline remains **0/25/21/1/38/40**.

No fresh green-board or merge-ready claim is made. Current surface qualification
passes; route/runtime renewal, candidate comparison, remaining V2 content and
human appearance acceptance remain open. Changes are limited to route/test
expectations, an isolated diagnostic, evidence publication, retained diagnostics
and workflow documentation. No additional owner decision is needed.

BLOCKED for integration pending completed route/runtime proof and candidate verification.
