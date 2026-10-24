# Hose household save integration — 2026-10-23

Evidence class: **INERT**. Candidate diagnostics, not installed-world acceptance.

REPORT - hose household persistence - 2026-10-23

Branch: **codex/v2-acoustic-topology**, parent **41afb086**.
Origin/main: **ad5b3899d532d2d0d7f0aecc7b344e5957040141**;
merge-base: **21f0b1fc27ac8e25c8466fe1ed2ce64019ee7ede**.
Worktree is shared and dirty: the unrelated spatial manifest and untracked
street/tent/traffic/art work remain untouched. Named paths only.

The existing cabinet owner now optionally saves deployment, extraction distance,
receiving pose, supply angle and water fill/pressure. Resting skin reconstructs
from that pose and the unchanged native source. There is no serialized particle
or numerical cloth state and no new household authority. A coupled nozzle is
validated against the saved receiver without temporarily moving the live joint.
Validation of the whole cabinet precedes restore. Eight-field cabinet saves and
five/six-field nozzle saves remain readable; legacy restore returns the separate
extended representation to its hidden, empty rack state.

Completed filling and draining publish one final existing manipulation signal,
so household persistence can retain the final charge after the control was
released. Stable pressure and empty rest then stop CPU callbacks. This is a
correctness repair; no new performance improvement is claimed.

| Location / reproduction | Severity | Evidence | Repair | Verification |
|---|---|---|---|---|
| Hose at a different live receiver when loading a deployed save | High save correctness | Saved coupled pose cannot be checked against an unrelated live receiver | Pure proposed-receiver validation | **save_v3** validates without mutation and reconstructs the remote native skin |
| Valve released before filling completes | High persistence | Control release precedes final charge state | Publish final fill/drain through existing owner signal | Exactly one completion update each for charge and drain, no stable CPU tick |
| Malformed deployment or contradictory rack/nozzle payload | High save correctness | Negative saved-state fixtures | Strict finite pose, rotation, reach, control and charge validation | Eight invalid variants rejected before any partial owner mutation |
| Loading historical cabinet/nozzle payloads after deployment | Compatibility | Eight-field cabinet and five-field nozzle fixtures | Restore original receiver before nozzle restoration | Legacy round trip remains valid |

Packet: **art/reviews/v2_hose_save_20261023/**. Original failures and every
wrapper receipt are retained. **save_v1** has four failed assertions because
two negative fixtures were ineffective: scaling a zero basis component changed
nothing, and moving an intentionally loose nozzle is valid. **save_v2** corrects
those fixtures and passes. **save_v3** additionally checks final-charge household
signals: 36 checks pass, stderr empty. These stage mechanism preconditions and
drive the small charge clock directly; they do not prove assembly input.

**water_regression_v1.log.receipt.json** records a completed windowed PASS of
actual extraction/carry, primary-grab/mouse-motion/second-click release, separate
supply and nozzle lever operation, charging, spray, draining, flat rest and
missing-gasket denial. Section and spray images were inspected. The spray still
has sparse droplet presentation; this checkpoint does not claim a visual upgrade.
Repaired-line assembly preconditions remain explicitly staged.

**coupling_regression_v1.log.receipt.json** records completed windowed PASS of
the nozzle, fold, rack and hand chain: 369 checks, four PASS lines, empty stderr.
This retains the original thread, free nozzle, union, washer, mechanical facts,
supported-body restore and actual-input regressions. All receipts are suite_run;
none is a schema-2 runtime_contract or human acceptance.

Reader exit 1 retains the same 33 NEW unrelated street/tent fields. No new data
projection was added. The full board was not repeated for this scoped checkpoint;
the preceding complete board and its explicit existing failures remain in the
service-light review. No protected path or selector was edited; V2 default and
explicit V1 rollback remain. Ledger promotions: []. No clean merge-base verifier
or complete-runtime claim.

Still required: lightweight production setup and native asset publication,
ordinary-world extraction/targeting, household bridge reconstruction, held and
released full payout, remote inspection, actual gasket handoff/dressing and
repeatable world performance including first spray. The candidate is still
installed only by diagnostics. Continue the started-work queue.

Decision needed from owner: none.

BLOCKED full runtime/surface/human qualification remains incomplete
