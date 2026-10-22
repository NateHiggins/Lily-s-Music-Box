# Book inspection possession and pickup targeting

Evidence class: **INERT**. Repair/diagnostic report, 2026-10-22.
No runtime-contract qualification or human acceptance.

| Location | Reproduction / severity | Evidence | Repair / verification |
|---|---|---|---|
| Player book inspection | Carry, Space, Space; medium: book drops before next click | Actual-input baseline **hand_before_v1** fails return/ownership/held-pose assertions | Retain original pickup descriptor/local contact; end inspection, then reacquire through original owner permission and swept hand path |
| Loose book cover/corners | Aim at a loose front cover; medium: offered hinge/turn instead of pickup | Cancellation re-pickup fails in **hand_after_v1/v2** | Book cover and turn targets return the body pickup outside supported inspection; free cursor still targets the specific mechanism during inspection |
| Destroyed inspected stock | Free book while supported; defensive cleanup | Final hand diagnostic | Clear retained grip before callbacks; validate original part/owner/frame before typed access; never acquire a replacement implicitly |

Space returns the same carried object to the hand. The next primary click
releases it. Inspection borrows the hand for its individual mechanisms. The
camera and cursor are restored before reacquisition. No teleport, new scan,
collision bypass, simulated shelf pile or durable save field is introduced.
The same owner's begin/owns/end permissions and physical setters remain
authoritative. Cancelled save/load manipulation and call-locked exits cannot
resume a retained pickup. Non-pickup inspection retains its existing exit.

## Verification and limits

**hand_final_v2** passes 89 checks with empty failures/stderr, including actual
pickup, held obstruction/reticle, free cursor cover/physical stop, opening,
return of the open binding, next-click release, cancellation, re-pickup and
destruction during inspection. **nook_final_v1** passes 3,420 checks, including
return/release for trade, pocket and pamphlet copies plus prior print, native
contact, loaded materials, independent copies and save migration checks.

The first cancellation fixture attempted pickup immediately after release;
two physics frames synchronize released collision. The remaining failure
then exposed the real front-cover targeting defect, repaired in production.
The first destruction fixture incorrectly assumed restore_order destroys
existing copies. It updates their state; that retained original is correctly
reacquired. The final fixture actually frees the selected book. Original
failures and their receipts are retained, not rewritten as passes.

**mechanism_v1** reports five failures in the 54-check toilet inspection
diagnostic. **mechanism_before_v1**, with the preceding exact player script,
reports the identical five. Cover clearance fails first, then internal float
and discharge selection/motion. This fixture disables player physics while
its free lid now uses pickup hand-follow in that physics path. This explains
why its scripted drag no longer clears the cover; the fixture and actual
toilet behavior still need separate verification. It is not a passing suite
or new qualification. Non-pickup camera restoration/cancellation assertions
pass in both runs.

Standalone --check-only probes cannot resolve all autoload globals in these
inherited suites. **preflight_v1** exits one; **world_preflight_v1** even exits
zero while stderr reports dependency compile errors. Neither is a clean
preflight verdict. The subsequently loaded scenes resolve autoloads and run;
cite their completed receipts and test verdicts instead.

## Played world and timing method

The full production-world nook route uses actual pickup, Space, free cursor
inspection, a second Space and primary release. It checks owner possession,
FPS held pose, durable snapshot validity and restoration of carrier contact.
The native physical nook glb and copy JSON are byte-unchanged; previous native
UV/PBR/mipmap and art captures are reused. Native source bindings are rebuilt
in one related Blender batch; no generated glTF is edited manually.

**world_final_v1** passes three waypoints and all return/release assertions,
with zero final held-position error. Its first return/release intervals also
include the preceding diagnostic PNG readback/compression: 249.020 and
200.169 ms. These are retained instrumentation-contaminated observations,
not gameplay optimization evidence. The revised fixture drains three process
frames while still capture-excluded, then delivers the measured input. It
retains every subsequent action/boundary frame. **world_final_v2** repeats the
route on final production source. Detailed distributions, process/physics,
render counters, spike counts and original frames accompany **summarize.py**.
This is one corrected post-fix route, not a matched performance improvement
claim. Counters overlap/lag; cold I/O and cross-cell streaming are not isolated.

The corrected run completes all three waypoints, with empty failures/stderr.
Return-to-hand p50/p95/p99/max: 13.664/18.158/18.998/19.624 ms (110 samples).
Release: 14.126/24.125/35.484/42.659 ms (40 samples). Zero frames above 50 ms;
release has one above 33.333 ms. The held-centre error is approximately
0.000000060 m. These are observations on final source, not a before/after win.

## Continuation report

REPORT - V2 book inspection possession - 2026-10-22.
Branch **codex/v2-acoustic-topology**; preceding HEAD
**71f8889cd32ae542d20c3dac8f68939e7f65c90c**; origin/main and merge-base
**21f0b1fc27ac8e25c8466fe1ed2ce64019ee7ede**. Canonical checkout; no new
worktree. Named paths only. Four pre-existing hose WIP files and unrelated
untracked paths remain outside this checkpoint. Protected 17/17 unchanged;
V2 default and explicit V1 rollback unchanged.

Focused source board passes physical imports, spatial, reader (zero NEW
unread fields) and four nook source tests. Seven previous report-only spatial
references remain; no new production coordinate or material keys. Prior full
effective comparison remains 107 PASS, two FAIL, one INCOMPLETE at
**art/reviews/v2_nook_revamp_20261022**. No new full-board execution or clean
management candidate is claimed. Completeness/expired surface qualification
remain open; no requirement promotion. Wrapper **suite_run** receipts and
test diagnostic JSON are archived exactly; neither is **runtime_contract**.

Remaining: repair the old cistern diagnostic and verify actual lid handling,
first-use/frame tails, wider V2 coverage, installed full-length hose aiming,
spray/release/save, renewed qualification and human acceptance. Decision
needed from owner: none.

BLOCKED - complete V2 and merge qualification remain incomplete; continue
authorized repairs.
