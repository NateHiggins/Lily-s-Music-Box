# F01 guest haunt proposal — outside game, runtime unrun

The production proposal changes only `HAUNTS.transient_guests.at` in `resident_routines.gd`, from Blender `(2.2,-6.2)` to `(2.2,-8.3)`. All other haunt entries, destination height resolution, actor intent, movement and lift arrival code remain byte-identical. The old point is strictly inside the authored shaft despite its “vestibule” description. The new point is in the public F01 lobby, ahead of the east bench.

## Source geometry

`static_geometry_01.json` binds the authored layout, actual exported F01 mesh/buffer and actor body definitions. `inspect_static_geometry.py` parsed all49,296 collision triangles. The candidate footprint, including0.05m extra horizontal margin, fits F01_LOBBY `[-5.33,-9.65,5.33,-6.93]`; no exported collision triangle AABB overlaps the body box. The `F01_slabs-col` top triangle at the destination is Godot height0. The production resolver adds its unchanged0.03m foot offset. This is exported-source geometry proof. Dynamically spawned props and runtime collision remain unverified.

The actual resident Body is a radius0.28m, height1.55m capsule with local centre+0.775m. The fixture reads that actual `CollisionShape3D` and relative transform. It does not substitute the earlier navigation audit's radius0.33m, height1.524m, centre+0.80m capsule. The appended correction in `design/astra/reviews/resident_lift_waiting_review.md` preserves all historical receipts while limiting their earlier shape claims.

## Prepared runtime contract

The new `ResidentF01HauntTest.tscn` instantiates actual V1 and the real4D Transient Guests owner. It holds other residents' choices and the player, freezes CampaignClock, and gives the selected production `_step` one actual physics-frame delta per tick. It does not accelerate `_follow`, edit its timer/stage/haunt, teleport the fixture actor or force elevator readiness. The production owner's normal hidden-rider abstraction and landing placement are unchanged and remain the scope of the proof; the NPC remains walk-through scenery, not a collision-bearing human traversal.

One initial RNG seed is selected for the existing outbound/return elevator choices and the authored40–90second dwell range. Actual cabin physics must first fetch the actor at F04, admit boarding only when ready, arrive/open at F01, release it onto the public landing, let it walk to the authored point and dwell until its unmodified timer expires, then carry it back to F04 and allow its production home route to finish. Stage/visibility/position transitions are retained. No complete-builder-ready signal is claimed from the inherited1.6second settle heuristic.

The fixture separately checks destination footprint, real support collider and actual Body overlap before departure and at arrival. While F01's landing is actually closed after the cabin fetches the resident, it checks the public route with unchanged nav wall/ray rules and an independent actual-body shape sweep. Ordinary `_follow` preserves actorY, so the query uses the route's real owner-height instead of graph nodes' slab datum; both graph and effective body coordinates are recorded. There are no collision exemptions in the shape sweep. An unsafe old destination still runs through real lift arrival, then ends dependent dwell/return proof honestly.

## Proposed execution after explicit source/lane handoff

1. Install the new fixture/scene with original production source and retain the initial old-haunt red, including native diagnostics.
2. Apply the one-coordinate candidate and run a fresh-profile candidate. Any parse, lifecycle, source-binding or diagnostic failure remains red and must be reviewed before expanding scope.
3. Use `run_omission.py NEW_TRANSACTION_NAME` only with the reviewed candidate installed and exclusive engine/source ownership. It verifies exact prepared source hashes, swaps only ResidentRoutines to the exact original, invokes `run_haunt.py` in a fresh run, restores exact candidate bytes in `finally`, and runs a separate restored candidate with unchanged fixture. Preserve and inspect both raw receipts; the wrapper return alone is insufficient proof.

The copied `run_haunt.py` uses the unchanged serial runner and existing fail-closed diagnostic parser, fresh APPDATA, windowed Vulkan Forward+, engine/PID and before/after source binding. Native exit, completion and diagnostic gate stay separate. Its240second timeout is a bounded allowance for real elapsed dwell and rides, not a performance claim. The original and candidate source bytes and three-file patch are retained; `preparation.json` records patch applicability only. No Godot run, live installation, staging or commit occurred during preparation.
