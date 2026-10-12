# Direct manipulation migration â€” working report

Evidence class: **INERT**. In-progress implementation; no completeness promotion.

Owner request: migrate **all existing interactions** to RUL-013 before resuming
the broader V2 build. Starting published revision: **e0b0dd29**. The source
inventory is **design/DIRECT_MANIPULATION_MIGRATION.json**. It is an initial
inventory, not proof that every runtime entry point has been discovered.

## First implementation batch

The player has a shared, latched constrained-grab controller. A cursor change
identifies a part; mouse input operates the part's hinge or track while camera
look remains stable. A second click releases it. Reach loss, pointer release,
protected interaction and lost ownership stop the grab. The owner retains its
state and travel limits. Existing controller interaction input uses the same
acquire/release path, and its look stick drives a held mechanism.

The first adapters cover ordinary and entrance leaves, refrigerator food/ice
doors and trays, independent faucet handles, medicine and sliding kitchen
cabinets, window-treatment controls, wall switches, radiator wheels, task-lamp
keys, fan selectors and toaster levers/trays. Some families still have additional
service or inspection actions pending. This list is not whole-family acceptance.

Faucet openings are continuous and determine mix, flow, stream width and sound.
Household persistence now includes named mechanical owners and accepts fractional
cabinet travel while reading earlier boolean cabinet records. NPCs cannot claim
a held ordinary leaf. Door travel probes its collision shell through the sweep.
The full toaster stroke engages its existing latch and heating timer; a partial
stroke does not start a cycle. An unlatched carriage returns under its spring.

The focused bench currently passes **56 checks**, with no script errors, and
has rendered views in **tmp/v2-direct-manipulation-20261012/review-ownership**. These are
mechanism-bench views, not composed-room visual acceptance. The door bench uses
the base leaf; native installed-world geometry still needs its own review.

The installed-world probe passed **200 checks** before the range/laundry/window
extensions: startup, installed mechanism validation, household registration and
real player mouse gestures on three kitchen hot caps. Later fresh-root testing
preserved the sampled partial positions but exposed a duplicate window save
owner and float precision at the airer's upper stop. Both are corrected. The expanded reconstruction run passes **257 checks**
with clean stderr: seven installed families restore partial positions in a fresh
V2 root, and the installed boiler window respects its cam and fitted reveal. All these are diagnostic wrapper
receipts, not schema-2 runtime acceptance or completeness evidence.

The second batch adds oven/broiler leaves, washer lid/swing/release, the native
pulley rack and a separately operated boiler window cam/sash. Render review
caught the inherited washer lid's reversed hinge, now corrected. Refrigerator
leaves and trays have blocking shells; stepped proposals stop at external solids.
The focused bench checks obstruction and resumed travel after clearance.

Boiler service now uses independent column cocks, a spring-return drain lever
and a movable witness marker. The glass empties through flow while the lever is
held; reopening the cocks restores communication. The service outcome requires
a drained glass, restored communication and a witness at the actual waterline.
No panel opens and the boiler's water quantity is unchanged. The 56-check bench
passes with clean stderr. It does not prove installed targeting for every part.

The data-consumption audit reports zero new unread fields. The historical owner
baseline still matches for 282 of 283 entries; the documented prep-cabinet edit
is the sole difference. No interaction changes have been committed or pushed.

## Work remaining before completion

- Finish every pending owner and each additional control on partly migrated
  owners. Existing service/minigame panels remain migration debt.
- Replace maintenance, book sorting, tabletop activities and device panel entry
  points with actual physical actions, preserving inventory and case outcomes.
- Remove the temporary legacy dispatch and instructional prompt path once all
  covered activities have their replacements. It is not a compliant fallback.
- Complete obstruction, both-side operation, interruption, accessible input,
  real save/reconstruction and installed part targeting tests for every family.
- Renew affected source-bound surface/runtime/navigation proofs using the new
  player path. Old E-toggle route receipts cannot certify RUL-013.
- Run a clean candidate comparison against the last verified source baseline,
  then commit/publish the finished migration. V2 remains incomplete.

Owner work is preserved. The prep-cabinet path appears in the historical owner
baseline, but its recorded bytes exactly equal the starting HEAD's LF content;
this batch adds only its documented manipulation/travel changes. The other
historically protected owner bytes remain unchanged.

## Static comparison and next verification

The interim board in **tmp/v2-direct-manipulation-20261012/gates/board.json**
reports 43 regressions against **8996abf2**. Changed rendering/runtime inputs
invalidate earlier surface, spatial and first-slice proof. They require new
physical-path runs and rendered review after the remaining migration; no receipt
hash was patched and no acceptance requirement was weakened.

The historical M11C1 tools-test failure is separately diagnosed: its export
bound the protected glTF with CRLF, while this canonical checkout has identical
content with LF. Both protected assets match HEAD and **8996abf2** byte for byte.
The test now recreates the exact hash-verified historical newline encoding only
in its disposable fixture, and still verifies production rejects mismatched raw
bytes. All 19 tests pass. Protected production assets and historical receipts
are unchanged. The full board has not been repeated after this focused fix.

The final ownership guard cancels stale grabs following state restoration and
suppresses stale modification events. It passes the 56-check bench. The
257-check world run preceded this small guard change. Current scripts retain LF
line endings; the temporary Windows CRLF serialization was corrected.


## Pressure screw continuation

The washer pressure handle now rotates about its shaft and advances 12 mm over
four turns. Roller clearance follows the adjustment; tightening cannot defeat a
tripped safety release. The release bar now pivots at its own rear fulcrum rather
than orbiting the wringer origin. Existing geometry and material authority remain
unchanged. Old three-field washer saves remain readable, while new saves also
retain the screw setting and reject contradictory clearance.

**tmp/v2-direct-manipulation-20261012/bench-pressure-input.log.receipt.json**
reports 66 checks, zero failures and clean stderr. This includes actual player
mouse targeting, acquire without movement, counterclockwise loosening and second
click release retaining the setting, plus pressure/clearance reconstruction and
safety refusal. The combined washer render was inspected. This remains diagnostic
bench evidence: installed washer access and whole-world reconstruction after this
change have not been rerun. Safety reset, drive, fill and drain remain pending.
Sink plug handling and continuous shower cloth motion also remain pending; no
artificial slider or visibility toggle has been substituted for those actions.


## Range gas-control continuation

Four burner cocks now have independent moving-part targets and continuous
opening. A lit flame and its sound follow gas admission. Closing extinguishes
it; reopening a cold cock supplies no automatic spark. The blocked jet remains
under its existing owner. Claimed knobs refuse director changes, cancel old
knob motion, and stop old light tweens from overwriting hand adjustment.
Native stove installation rebuilds targets and leaf sweep shapes from the
actual installed meshes. Saves retain fractional gas and lit states together,
reject flame-without-gas states, and still read older door/drawer-only records.
Physical ignition, the oven fuel control and service work remain pending.

**tmp/v2-direct-manipulation-20261012/bench-gas.log.receipt.json** reports
77 checks, zero failures and clean stderr; the combined range render was
inspected. **tmp/v2-direct-manipulation-20261012/world-gas.log.receipt.json**
reports 270 checks, zero failures and clean stderr. Three installed native
ranges resolve and operate the intended knob through player mouse input.
Fresh-world reconstruction preserves the sampled gas/flame arrays and washer
pressure setting, alongside the other six sampled mechanism families. These
are diagnostic tests, not navigation or schema-2 completeness acceptance.
The historical owner baseline still has only the previously documented prep
cabinet difference. Publication gates and the wider migration remain open.


## Loose basin plugs

The shared hand now supports screen-plane movement of an owner-constrained
loose part. Kitchen and lavatory plugs lift and move within the basin, unseat
the water seal when lifted, and settle under gravity after release. Support
heights come from the fixed casting triangles and sample the plug footprint.
Bath chain presentation follows the plug; full chain dynamics are not claimed.
Saved sink state includes plug position and water quantity, with old valve-only
records still readable. Shower stopper and curtain migration remain pending.

Installed testing found two defects and both are fixed: the shared sink subtype
must not install a nonexistent kitchen plug on a lavatory, and the old solid
basin collision box hid the plug. Sink collision now follows the fixed casting
mesh, preserving the open bowl. This collision change still needs the formal
navigation suite; the interaction probe does not certify traversal.

**tmp/v2-direct-manipulation-20261012/bench-plug-collision.log.receipt.json**
passes 89 checks with clean stderr, including installed collision on the bench.
Close renders in **review-plug-contact** were inspected for both basin shapes.
**tmp/v2-direct-manipulation-20261012/world-plug-collision.log.receipt.json**
passes 278 checks with clean stderr: native kitchen plugs in 3B, 4B and 2A are
targeted and lifted by real mouse input, and a fresh V2 root retains a seated
plug and its water quantity. Earlier failed **world-plugs** and
**world-plug-fixtures** diagnostics remain on disk. The reader audit remains
NEW 0. No schema-2 acceptance is promoted and no interaction work is published.


## Continuous shower curtain

The existing Blender-authored cloth and rings now deform along the original
U-shaped rail, retaining their material and UV arrays. The same cloth is shown
through closed, intermediate and gathered positions. Selection follows its
updated mesh; the hand constraint follows the rail direction through each turn.
No replacement generated asset or texture was introduced. The old alternate
mesh stays hidden. Partial gathering is saved and restored by the fixture owner.
This is constrained deformation, not a general cloth simulation.

**tmp/v2-direct-manipulation-20261012/bench-curtain-motion.log.receipt.json**
passes 95 checks with clean stderr. Closed, halfway and fully gathered renders
in **review-curtain-motion** were inspected. The first bench's incorrect mouse
sign was corrected. Unchanged-pose rebuilds were subsequently eliminated and
inverse transforms cached; the composed run covers those optimizations.

**tmp/v2-direct-manipulation-20261012/world-curtain-final.log.receipt.json**
passes 285 checks with clean stderr. It covers installed mouse operation and
fresh-world restoration of eight mechanism families, including partial curtain
travel, seated plug/water state, gas controls and washer pressure. An earlier
285-check run warned about concave overlap monitoring; disabling monitoring on
the ray-only cloth selection area removed that warning. Final reader audit:
NEW 0. Owner baseline: only the previously documented prep cabinet differs.

The shower stopper and other pending service/device families remain migration
debt. Full navigation, formal source-bound runtime/surface proof renewal and
candidate verification remain outstanding. These diagnostic runs do not grant
schema-2 acceptance. The interaction WIP remains uncommitted and unpublished.


## Owner-requested checkpoint publication

The owner requested commit and push on 2026-10-12. This checkpoint records the
unfinished migration; it does not declare V2 complete or authorize acceptance
promotion. The refreshed **commit-gates/board.json** reports 41 regressions
against **8996abf2**, including expired surface/runtime proof, three spatial
findings, one additional systemic review and the dependent completeness smoke
test. The historical M11C1 fixture test now passes. Reader NEW remains 0.

Push destination: **codex/v2-direct-manipulation-checkpoint**. Remote main is
not advanced by this checkpoint. Runtime source files retain tested LF bytes
through explicit attributes. Unrelated owner files, import churn and untracked
UIDs outside the named work manifest are excluded. Formal candidate verification
and promotion remain pending while the shared checkout contains other work.

## Regression repair in progress

The migrated apartment route exposed two real door defects: the AnimatableBody
transform can be deferred while the open flag reads the previous pose; and
float32 stop angles could fail strict save bounds, rejecting household snapshots
and permitting an older closed pose to return. The sweep now accumulates one
accepted angle before publishing it; snapshots normalize the limits and the
validator admits float32 endpoint tolerance. The route now checks saveability
with actual mouse-driven endpoints. The fifth run passes 265 checks, 19 rooms
and 89 waypoints with zero failures, retaining the disclosed seven Texture RIDs.

The synchronous restoration-ownership bench case was extracted from its
monolithic timed routine, removing the additional timer heuristic finding.
Three spatial records were reviewed and added to the dependency inventory:
the isolated bench placements, the existing boiler-window identity, and the
world-test staging position outside the sash sweep. All retain TEST_CONTRACT /
UPDATE_TEST_FIXTURE classification; no production dependency, gate policy or
frozen comparison board was exempted or changed.

Regression verification is now complete: first-slice 113 checks, focused bench
95 checks, apartment access 265 checks, and surface qualification 26,433 checks
all pass. The reviewed surface inventory covers 23,465 draws, 16,201 meshes,
5,827 materials and 453 textures with zero unresolved surfaces.
**tmp/v2-direct-manipulation-20261012/regression-gates/board.json** reports zero
regressions against **8996abf2**; every tools suite passes and reader NEW is zero.
The baseline’s existing incompleteness and 21 systemic review findings remain.
The first-slice and surface runs retain the disclosed seven Texture RIDs;
tracked runtime-owner retirement passes, not global resource-clean acceptance.

The owner’s new movable cistern, inspection-camera and compact handheld request
follows this repair checkpoint. Its Blender prototype remains outside shipping
assets until reviewed and integrated; it is not included in these receipts.
