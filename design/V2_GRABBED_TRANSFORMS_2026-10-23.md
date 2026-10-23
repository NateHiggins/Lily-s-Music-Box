# REPORT — grabbed-stock XYZ controls — 2026-10-23

Evidence class: **INERT**. Diagnostic report; no runtime-contract acceptance.

Branch: **codex/v2-acoustic-topology**. Pre-change HEAD **d6ea2a50**;
origin/main **bfe005ff**; merge-base **21f0b1fc**. Canonical checkout
**C:/PleaseRemainOnTheLine**. Worktree clean at end: **no**. Uncommitted hose
candidate/layout studies and unrelated spatial dependency manifest remain;
untracked contributor work is preserved. Named paths only are staged.

Protected 17/17: **yes**, worktree bytes compared after LF normalization with
the merge-base, recorded in **protected_worktree.json** in the packet below.
Selector remains V2 with explicit V1 rollback. No ledger statuses promoted;
completeness totals were not rerun for this inert report.

## Changes and measurements

The owner clarified nozzle alignment requires independent Y and Z translation,
then requested a shared XYZ translation/rotation system. In the existing static
inspection view, free stock now uses camera-plane mouse translation and wheel
depth, with X/Y/Z selecting an owner-frame axis. Repeating the key clears the
axis. Secondary-button drag rotates yaw/pitch; its wheel rolls. Selecting an
axis constrains rotation as well. A restrained coloured reticle notch and arc
show axis/mode without instructional text or another target scan. FPS holding
outside inspection and constrained part gestures retain their existing paths.

The controller submits orientation through optional owner callbacks and reads
back the accepted basis. Library stock (books, bookends, service bottles) and
the loose nozzle provide these callbacks; unrelated constrained owners do not
gain arbitrary rotation. Collision checks, thread pickup, possession, case and
household save ownership remain with the original owners. The nozzle saves its
full loose orientation, accepts historical five-field records and rejects
nonrigid or contradictory threaded records. Rotations do not change its scale
or length. The existing receiving brass seat and nut stay attached to the hose;
the original thread still draws the separate rigid spigot toward its seal.

Whole-book manipulation is selectable on the exposed upper spine, independent
of the cover target and lower single-axis grip. Claiming inspected stock stops
its earlier floating-pose settling so release retains the user's position.

Three isolated nozzle translation calls measured median **0.219 ms**, max
**0.255 ms**; three rotation calls measured median **1.064 ms**, max **1.067 ms**.
These are owner setter CPU samples, not frame-time distributions, display
latency, or a playable-world performance comparison. No rendering improvement
is claimed. Control/owner details: **game/docs/grabbed_object_transforms.md**.

## Verification and original failures

Packet: **art/reviews/v2_grab_transform_20261023/**. Every Godot run used the
shared serial wrapper, windowed, with its original log and suite-run receipt.

| Location / reproduction | Severity | Evidence | Repair | Verification |
|---|---|---|---|---|
| Loose nozzle, inspection drag along a foreshortened axis | High interaction | Ordinary camera-plane drag cannot independently reach all owner axes | Axis translation plus owner-approved XYZ rotation | **input_v3.log.receipt.json**: completed, PASS, zero assertions failed; all six axes, rigid dimensions, fixed camera, save/rebuild and release checked; captured inspection visually reviewed |
| Floating book, try to select whole binding | High interaction | **book_v1** cannot acquire free stock behind the cover/corner targets | Upper spine exposes whole-book grip | **book_v4.log.receipt.json**: completed, 102 checks, zero failures; all six axes, secondary-wheel roll, static release, original cover/obstruction/hand/save routes pass |
| Book test's first explicit axis event | Fixture timing | **book_v2 / book_trace** observes an extra -48 mm X movement after cursor warp; no physical blocker | Flush OS warp events before measuring explicit motion | **book_v3 / book_v4**: independent X/Y/Z movements approximately +2.359 mm; no object pose assignment used to repair the test |
| Historical nozzle suite, household field count | Test migration | **coupling_regression** expects seven fields although rubber dressing already makes eight | Require the actual eight named fields, retaining validity/authority assertions | **coupling_v2.log.receipt.json**: completed PASS; actual insertion, nut pickup, partial screw travel, seal fact, save and support paths retained |
| Hardware service bottle | Regression risk | Shared library manipulation owner changed | Retain original stock/cap/inventory path | **bottle_regression.log.receipt.json**: completed; 72 checks, zero failures |

Successful runs above have empty stderr. Original failed logs, screenshots and
receipts remain in the same packet. These are scoped diagnostics and wrapper
**suite_run** receipts, not schema-2 **runtime_contract** receipts or human
acceptance. The input programme was exercised through actual player events,
not legacy toggles. No reference photograph was baked or new physical surface
authored in this checkpoint.

Reader gate still exits 1 on the same **33 NEW** uninstalled street/tent findings
as before; **reader.txt** retains the output. The baseline was not changed.
The full working static board completes with **101 PASS / 8 FAIL / 1 INCOMPLETE**.
Compared with the older dirty **working_gate_v2** board, it reports six named
regressions and five improvements; this is not a clean-main comparison. Three
spatial records are in previously committed counter, street-route and fitting
capture files unchanged by this controls checkpoint. The systemic review is a
new hose-test diagnostic line that serializes elapsed host time; it does not
write durable world state. Its count and named defect account for two reported
regressions. The remaining count increase is the spatial report total. Keep
these explicit; do not widen the baselines or label the board green. The two
maintenance model/import findings have resolved since that older board.
Clean-main candidate verification remains unavailable. **gate_compare.txt**,
**spatial.json** and **systemic.json** retain the findings, and all tools tests
run by the board retain their actual outcomes. This checkpoint adds no
completeness promotion.

## Remaining work

The deployed hose is still an uninstalled candidate. The owner now authorizes
cheap bounded visual routing, overlap where useful, and no hose simulation at
rest. Its earlier physical full-payout failures and the replacement visual
study remain separate from this controls checkpoint. Complete the simpler
route's world review, maintenance alignment, supply/controllable spray and
save/rebuild before production installation. Continue measured world stutter,
mirror/avatar, street and existing V2-area repair work. Other free mechanisms
may adopt orientation callbacks where their physical authority permits it.

Decision needed from owner: none. **BLOCKED (full candidate qualification
only): no complete clean-main baseline. Scoped checkpoint work continues;
broader V2 work and qualification remain open.**
