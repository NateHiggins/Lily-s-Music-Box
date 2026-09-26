# Guarded V2 roof lift drive

Evidence class: **INERT**

REPORT - V2-LIFT-DRIVE - 2026-09-26

Branch / base / origin/main at start / merge-base: main /
8515c6ca6a83f2f90450c584e2ef8d8b64cf78a6 (all three references).
Implementation HEAD is the commit introducing this report.

## Construction and ownership

The passenger shaft now terminates at a guarded drive assembly inside the
existing public roof bulkhead. The Blender-authored plinth, mounting rails,
motor, reduction housing, grooved sheave and guard use existing material keys.
Lettering is Label3D, not texture content. The existing bulkhead platform
supports the installation; no room overlaps or circulation colliders are removed.
The guard's closed collision envelope covers its visible outer posts.

The sheave reads the production car's height and stops when that height stops.
There is no additional travel controller, fault state, campaign flag, save owner
or maintenance activity. The original lift still owns car movement, landing
barriers, calls and interlocks. This is a visible architectural installation,
not a new simulation of the entire hoisting system. Ropes, counterweight motion
and machinery servicing are not supplied by this slice.

Regenerate the asset with Blender in background mode using
art/blender/scripts/build_lift_drive.py, then run the required double Godot
import through the lane. No glTF bytes are hand-edited. Static geometry is
combined by material while retaining the sheave's separate transform.

## Verification

Logs, windowed captures and adjacent suite-run receipts are under
tmp/v2-machinery. The first rendered review exposed an incorrect wheel axis
despite a passing route. Blender transform preservation was corrected before
re-export. A focused check now measures the imported sheave: 0.235 metres
along its axle and 0.68 metres in both directions of its vertical plane.

The drive2 run passes 16 live waypoints, the actual capsule stopping at the
guard, production car/sheave coupling, stop behavior, roof-door passage and
return down the public stair to F06. Before/after travel frames were inspected.
Both imports of the corrected asset pass. The complete working gate board has
zero regressions against the clean 8515c6c board; the reader has zero new unread
fields. Seven reviewed spatial dependencies are added without reclassifying
existing obligations.

The actual title-launch suite passes Begin (nine checks), New Campaign (nine)
and Continue (six), preserving the selected V2 root and appropriate saved facts.
ZooTeleport passes all 55 windowed checks, including the accepted specimens,
inspection lamp ownership, walking, pause/F1 controls and building return.
WakeReconstruction passes 49 checks with real scene reconstruction, save-file
reload and backtick pointer release/recapture. That wake test uses the public
developer preview; it does not claim to earn a case or play the preceding maze.

This report makes no runtime-contract or human-acceptance promotion. The ledger
retains 240 requirements and blocker counts 7/8/127/42/151/153. Historical
evidence, the protected 17 paths, the V2 default and explicit V1 rollback are
unchanged. The owner's four render files are preserved outside this commit.

## Remaining limitations

The primary light is the existing bright, beam-local voxel optical system with
native surface lighting; this work adds no whole-building indirect-light field.
Modeled ventilation branches and coal delivery remain unfinished. Basement fuse
and roof-tank activities retain their existing local instance state. The first
Mina campaign slice remains the supported story loop. H23 seams and historical
M11C1 receipt-hash debt remain separate from these construction checks.

No owner decision is required for this scoped installation.
