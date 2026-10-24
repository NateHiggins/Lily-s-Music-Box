# Hose visual-route study — 2026-10-23

Evidence class: **INERT**. Uninstalled candidate, not runtime acceptance.

The owner explicitly authorizes a cheap bounded visual hose, overlap where
needed, and no simulation in stored or resting cloth. This supersedes the
physical full-payout self-contact experiments. Existing maintenance joints,
held-body exceptions, inventory, case and save owners remain authoritative.

The candidate now has an explicit visual-follow mode. It draws the native
135-ring hose along a simple floor-draped curve, bounds endpoint reach by the
15.24 m stock less a 150 mm fitting allowance, and updates the existing joint's
receiver/body toward the FPS hand and reticle. It performs no cloth/contact
solve during these updates. The source port remains fixed. Release stops all
cloth callbacks and retains the accepted pose. Material distribution along
this cosmetic curve is approximate; exact per-segment lengths, self-contact
and environmental cloth contact are deliberately not its contract.

## Issue log

| Location / reproduction | Severity | Evidence | Repair | Verification |
|---|---|---|---|---|
| Candidate full payout while walking | High responsiveness | Physical experiments repeatedly snag at roughly 3.5–14.46 m; different staging hints give inconsistent limits | Replace handled cloth simulation with bounded visual routing | **visual_payout_v3.log.receipt.json**: completed PASS, zero failures, 225 actual walked increments, fixed source, finite native skin, 15.09000015 m span, aimed nozzle and authoritative limit reticle |
| Attached hose seat/nut, walk while holding | High movement | **fps_payout_taut_v1** records the carrier hitting NativeNozzleSeatCollision | Exclude only held assembly parts from their own carrier, retaining pre-existing exceptions | **fps_payout_assembly_v1** and final visual programme verify actual contacts and owned-exception cleanup |
| Fixed source datum | Small geometry drift | **visual_payout_v1** fails exact source equality from trigonometric residue | Assign the final point to the source datum exactly | **visual_payout_v2 / v3** pass the original exact datum assertion |
| Released deployed hose | Unnecessary idle cost | Owner no longer wants cloth simulation at rest | Static accepted pose, no process/physics callbacks | Final actual-click release followed by 12 physics ticks preserves the pose |

All packets live under **art/reviews/v2_hose_carry_20261023/**. Original failed
runs, the timeout/parse failures and test-written receipts are retained. The
physical escape prototypes were archived under **retired_before_visual_follow**
before removing their active solver changes. Earlier failed support/probe
attempts also remain archived. The former native tether and local solver files
are restored to their committed behavior; the visual mode does not call them.

The outer-end floor placement is an additional candidate; the original floor
fixture remains unchanged. It has not been qualified at all eight stations.
The floor-pose builder retains its default behavior and exposes the new pose
only through its explicit optional outer-pickup mode. No generated glTF was
hand-edited or replacement physical surface authored in this checkpoint.

In the final fixture, the retained 512 visual setter samples have p50 **0.278
ms**, p95 **0.514 ms**, p99 **0.550 ms**, max **0.637 ms**. A static gate board
was running concurrently: these are diagnostic CPU timings, not an isolated
benchmark or fair before/after frame-time comparison. The earlier occupied
F02 world's standing p95 **143.918 ms** remains unrepaired. No whole-world
rendering, input-to-display or representative route improvement is claimed.
The full-payout FPS capture was visually reviewed in **visual_payout_v2**.

The full working board, unchanged reader debt and protected-path checks are
recorded with the shared controls checkpoint **5bfaba7d**. These wrapper
**suite_run** receipts and inert studies grant no runtime-contract, ledger or
human acceptance. The clean-main candidate baseline remains unavailable.

## Newest direction and remaining work

The owner now also requires a flat, limp unpressurized hose, separate supply
charging and nozzle-lever spraying. The existing round skin needs a lightweight
flattening state; there is no reason to restore cloth simulation. Existing
cabinet code currently restricts the supply wheel to dry inspection play.
Extend that V2 authority for the owner's requested live operation while keeping
inspection certification and maintenance facts separate. The untracked
**hose_water_charge.gd** is an unfinished response-state draft, not installed or
tested and not included in this candidate checkpoint.

Before production installation: finish flat/charged appearance, supply input,
lever-controlled spray, away-from-cabinet inspection, saved deployment/receiver
and charge reconstruction, and actual-world review. This study does not
complete those tasks or all existing V2 repairs. No owner decision is needed.
