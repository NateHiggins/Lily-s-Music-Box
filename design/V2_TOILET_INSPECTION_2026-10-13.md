# REPORT - V2-TOILET-INSPECTION - 2026-10-13

Evidence class: **INERT**. Implementation report and scoped visual review;
not whole-building acceptance or a ledger promotion.

## Branch and scope

Branch: local **main**, publishing to **codex/v2-direct-manipulation-checkpoint**.
Starting HEAD: **f0fb4bf313d55f786305bfaab7fb853ed2e70ed0**.
Origin/main and merge-base: **e0b0dd293325a49c207785888112262a4990e474**.
Worktree clean at end: no; pre-existing owner changes, import churn and generated
UIDs outside the named work manifest remain excluded. Protected 17/17: unchanged
by this batch. Selector: **v2**, with the explicit V1 rollback retained.

## Implementation

The Blender closet now has a hollow porcelain cistern, separately hinged seat
and lid, a liftable removable cover, an accessible spring-return flush handle,
float arm and inlet valve, overflow standpipe, discharge ball and lift linkage.
The fixed collision follows the castings. Internal linkage ray targets use the
actual mesh surfaces, avoiding a convex bend that hid the discharge ball.
The external handle clears the raised lid; depressing it lifts the discharge.
The cover must clear the rim, can move aside, and settles under gravity against
external support. Seat and lid retain their hinge limits and resist crossing.
The existing catalogue supplies porcelain, wood, nickel, brass, rubber and
clear-water PBR; the editable Blender source and generated GLB are both retained.
The older bathroom batch calls the dedicated builder so it cannot replace the
articulated closet with its former solid cistern.

The float and discharge can be grabbed independently. Tank level drives the
float and refill, the handle returns under spring tension, and the discharge
remains buoyant through the flush. Existing household save, service-condition,
inlet restriction and water-audio owners remain in use. Snapshots validate
finite values and travel bounds; restoration revokes the old grab.
Period form references, without baked photographs: US1551808A (1925 ball cock)
and US1190917A (1916 closet-tank discharge and guide).

Space after grabbing an inspectable part enters its authored fixed mechanism
view. The free cursor can then acquire and operate individual parts; mouse
motion does not steer the camera. Space or Escape restores the prior camera
and pointer mode. Restoration cancels inspection. A blocked approach refuses
the camera move. Inspection neither removes the cover nor repairs a fault.
The toilet is the first inspection provider; other owners need authored views.

The handheld collapses to the actual first line of printed text at bottom right.
E expands the original instrument and message into the right third, then
collapses it again. E no longer operates a world object. The hidden instrument
viewport stops rendering while its printer, radio and lamp owners keep working.
The startup slip now uses an opaque hint and ASCII sketch instead of obsolete
E/T recipes. Legacy interaction carrier formatting now identifies the click.
The carried V2 flashlight has a stable supply: no contact chatter, drift or
impact-driven flickering. Its switch, thermal transition and optical save
contract remain intact; the isolated electrical review instrument keeps its
separate electrical model.

## Verification and images

The focused windowed bench passes **39 checks**, including actual click, motion,
release, seat/lid endpoints, flush/refill, cover removal, internal float and
ball selection, fixed camera, safe exit/restoration, finite snapshots, E input,
right-third framing and steady beam through multiple contact cycles and shocks.
The existing manipulation bench passes **95 checks**, controller input passes,
and optical-driver save/restore passes **24 checks**. The headless manipulation
attempt could not capture a mouse and is not counted as passing evidence; its
windowed rerun is the qualification. Earlier failed development benches remain
in the task's temporary directory and are superseded by the passing run.

Bench wrapper and reviewed images: **art/renders/orison_v2/toilet_inspection_20261013/**.
The wrapper is **suite_run**, not a schema-2 runtime contract. The images show the
isolated production owner and its real handheld; they do not prove installed
clearance in every apartment. The separate apartment and surface contracts cover
their stated production scopes. Historic **4B_toilet_flush.png** in the apartment
packet is not refreshed by the new drag helper and is not current visual proof.

- **cistern_inspection.png**: removed cover, visible float, overflow and discharge;
  gold pointer tracks the selected internal part.
- **handheld_collapsed.png**: only the printed first line remains at bottom right.
- **handheld_expanded.png**: the physical printer/message stays in the right third.

The actual 4B route acquires and turns the installed flush handle, releases it,
and waits for refill. The apartment contract passes **268 checks**, the same
**19 rooms / 89 waypoints**. Formal receipts and the final board are renewed at
publication; the dated apartment and first-slice documents retain their narrow
scope. Seven Texture RIDs remain disclosed by composed-world shutdown, as before.

## Final comparison

**tmp/v2-toilet-inspection-20261012/gates/board.json** reports **NO REGRESSIONS**
against the completed regression-repair board. Ledger before -> after:
**0 / 1 / 102 / 34 / 119 / 121 -> 0 / 1 / 102 / 34 / 119 / 121**;
requirements_changed: **[]**. The ledger remains INCOMPLETE (exit 2), as designed.
Spatial, systemic, period, reader, carrier, ruling and surface gates exit 0;
every tools test passes. Reader NEW is **0**; the existing **21** systemic review
findings remain. The full board records individual exits and test counts.

Final Godot wrapper receipts (all exit 0), under
**tmp/v2-toilet-inspection-20261012/**:

- **bench7.log.receipt.json**: TOILET INSPECTION PASS, 39 checks, clean stderr.
- **manipulation-windowed.log.receipt.json**: DIRECT MANIPULATION PASS, 95 checks.
- **controller.log.receipt.json**: CONTROLLER INPUT TEST PASS.
- **lamp.log.receipt.json**: CARRIED OPTICAL DRIVER, 24 checks, 0 failures.
  Its fixture also reports four ObjectDB instances at shutdown; no global
  resource-clean claim is made for that diagnostic run.
- **apartment-contract-release.log.receipt.json**: V2 APARTMENT ACCESS CONTRACT
  PASS, 268 checks, 19 rooms.
- **first-slice-final-release.log.receipt.json**: ORISON V2 M08F RUNTIME PASS,
  113 checks.
- **surfaces-final-release.log.receipt.json**: V2 SURFACE QUALIFICATION PASS,
  26,433 checks. Inventory: **23,693 draws / 16,213 meshes / 5,846 materials /
  453 textures**, zero unresolved surfaces. Reviewed packet renewed in
  **art/renders/orison_v2/surface_requirements_20261011/**.

No engine run was repeated for this report-only update. Source-bound production
receipts are distinct from wrapper receipts and retain their declared scopes.

## Boundaries and remaining work

Changes outside toilet geometry are the shared inspection controller, handheld
presentation/input mapping, stable carried-lamp mode and matching tests/rulings;
all were requested by the owner. Existing V1 mechanisms and unrelated owner work
are preserved. The old renderer import churn is not staged.

V2 is not complete. Remaining direct-manipulation debt includes the shower
stopper, paper/device/service controls and activity-panel retirement; whole-world
navigation, human acceptance and V1-retirement gates remain separate. These
receipts do not certify whole-world photorealism or retire either V1 fallback.
No owner decision is needed for this scoped checkpoint. Clean-checkout candidate
verification and main promotion are outside this shared-tree publication.

BLOCKED whole-building acceptance: remaining migration, runtime and human-review gates.
