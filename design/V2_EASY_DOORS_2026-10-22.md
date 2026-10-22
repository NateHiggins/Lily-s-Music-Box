# V2 passage-first door controls

Evidence class: **INERT**. Work and diagnostic continuation; no runtime
qualification, human acceptance or completeness promotion.

The owner directs fixed mouse travel, moving the player back to make room,
slow automatic closing, and passage priority over door collisions. This
supersedes the earlier instruction to retain obstruction tests for these
leaves. Locks, keyed NPC access, angular stops and saved angles retain their
existing DoorProp authorities.

Current implementation applies to DoorProp and its fitted, landmark, bar-WC
and passage-shop subclasses. One 240-pixel horizontal stroke opens either
hinge direction; reverse closes. Primary grabs the actual ray-hit part and
the next primary releases. The initial ray retains its ordinary reach; a
held door uses a fixed frame anchor for reach and does not rescan occlusion.
Moving the leaf around a corner no longer steals the hand.

The first opening gesture backs a nearby player away only when the leaf
comes toward them. That short character movement uses ordinary wall/floor
collision. The open leaf gives the player a temporary collision exception;
closed locked doors retain their barrier. The closer waits 3.5 seconds,
then returns at 0.20 radians per second. It pauses while the player occupies
the passage, permits immediate re-grabbing, and sleeps when inactive. NPC
motions retain their own owner API and can interrupt the return. No extra
save fields are introduced.

No door obstruction sweep is called. The passage-shop compound probe and
base door shape query are removed. Existing native clearance and fitted
hardware geometry remain available; no new impact test is requested.

## Original findings and current checks

The original easy-door diagnostic passes fixed travel, backing, retention,
release, passage priority and interruptibility, but fails slow latch return.
Updating the synchronized AnimatableBody incrementally from rendering loses
progress between physics submissions. Returning it on physics ticks repairs
that failure. The next diagnostic verifies closure and restored lock barrier;
its walking fixture uses the camera heading while locomotion follows the
player body, so the first hinge direction walks away instead. Correct the
fixture's body heading and require actual ordinary passage, exact save-angle
restoration and locked-leaf acquisition. All original logs and wrapper
receipts remain under **art/reviews/v2_easy_doors_20261022**.

The focused **hand_v4** run passes 34 checks with empty stderr, including both
hinge directions, 240-pixel strokes, physical backing, ordinary walking through
and back, interruptible slow return, exact saved-angle restoration, actual
locked-part acquisition and retained lock/barrier state. The legacy broad
fixture's first door gestures are changed to horizontal input; its separate
furniture impact checks still require migration before it can qualify the new
owner direction. No new door impact run is performed.

Playable-world door qualification and performance comparison remain pending;
do not call the family or V2 complete from this bench.

A new **V2BathroomOpticsProfile** fixture is prepared for the actual occupied
world. It starts once outside the bathroom door, operates it with real input,
walks in, operates the curtain and hot/cold valves, and records dry, cold,
hot-developing, mirror and drying phases. Frame wall/process/physics costs,
main and reflected viewport CPU/GPU times, compilation/resource counters,
streaming state and authoritative mixed-water state are retained. No image
readback or PNG compression occurs inside measurement phases. This is a
baseline before adding the requested spray cone, local steam, edge wear and
side-correct condensation/rivulets, not evidence those effects exist already.

Other mechanism families, including fire-service and furniture hinge owners,
still need review against the owner's new direction. Hose carrying, usable
water supply and spray, wider V2 coverage and human acceptance remain open.

## Continuation report

REPORT - passage-first architectural doors - 2026-10-22.
Branch **codex/v2-acoustic-topology**, preceding HEAD **e801168b**;
origin/main and merge-base **21f0b1fc27ac8e25c8466fe1ed2ce64019ee7ede**.
Canonical shared checkout; no new worktree. Protected 17/17 and V2 selector /
explicit V1 rollback remain unchanged. No requirements are promoted; existing
ledger blockers remain 7 / 42 / 110 / 8 / 134 / 136.

The completed focused suite has 34 checks, zero failures and empty stderr;
its wrapper receipt is diagnostic suite_run, not a runtime_contract. Reader
refresh reports zero NEW unread fields. Spatial refresh reports no new failing
records and the preceding six report-only references after reviewing two
new bathroom diagnostic stations. Those two manifest rows and the prepared
bathroom profile remain outside this checkpoint until baseline verification.
The last complete board is the preceding toilet checkpoint's 107 PASS, two
FAIL and one INCOMPLETE census, with no regressions against its continuation
baseline. Do not present it as a new clean candidate board for these changes.
The two existing qualification/completeness failures remain open.

No frame-time gain is claimed before the new actual-world baseline completes.
The removed door shape queries can be inspected in source; a query count is
not a paired FPS result. No Blender run is needed for unchanged native doors.
This checkpoint includes a horizontal-input migration for the broad fixture,
whose remaining furniture impact assertions are not rerun as door acceptance.

Worktree is not clean: four pre-existing hose WIP files, their helper, prepared
hose/optics diagnostics and the bathroom spatial-manifest rows remain outside
the checkpoint, along with unrelated untracked work. Preserve those files.
Original easy-door failures and final focused evidence are retained in
**art/reviews/v2_easy_doors_20261022**. The requested steam/wet-glass scope is
recorded in **V2_BATHROOM_WET_GLASS_BRIEF_2026-10-22.md** and is not installed.

Decision needed from owner: none. Continue the queued played baseline, remaining
hinge-family migration and spray/steam/wet-glass work under the active V2 goal.

BLOCKED - broader runtime and merge qualification remain incomplete.
