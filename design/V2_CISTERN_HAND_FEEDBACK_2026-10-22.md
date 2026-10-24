# Cistern hand path and continuous reticle feedback

Evidence class: **INERT**. Diagnostic repair report, 2026-10-22.
No runtime-contract or human acceptance grant.

| Location | Reproduction / severity | Evidence | Repair / verification |
|---|---|---|---|
| Cistern diagnostic | Cover remains over internal controls; medium | Previous checkpoint reproduces five failures in 54 checks | Add standing floor, enable real player physics for lid pickup, carry with mouse look, next click releases; no production cistern state or collision change |
| Continuous pickup reticle | Hand meets a constraint but still shows grabbed; medium | **hand_v1** logs grabbed at the lid's accepted x=0.65 boundary; **feedback_before_v1** fails the explicit assertion | Retain the previous authoritative readback while a new continuous hand-follow request awaits publication; no new target scan or physics query |

The generic hand previously observed a blocked result, then overwrote it with
optimistic grabbed feedback on every new physics-tick request. Continuous
requests now preserve the observed result. A subsequent accepted readback
clears it normally. Discrete mechanism gestures retain their existing behavior;
book-specific authoritative constraint callbacks remain unchanged.

**feedback_final_v1** passes all 57 toilet checks, including actual lid pickup,
FPS carrying beyond the rim, blocked feedback, primary release, free-cursor
float and discharge movement, physical stops, camera restoration, save state,
locked reticle, handheld paper and steady lamp. **book_regression_v1** passes
89 hand/inspection/obstruction/cancellation/destruction checks. Both completed
wrapper receipts record exit zero and empty stderr. Review the new exposed
cistern capture; native geometry, materials and mechanisms are unchanged.

The original frozen-player test disabled the very physics update that carries
pickups. Its five errors were fixture failures, not evidence that clicking
should toggle the lid. No ownership, inventory, NPC, case or save authority is
replaced. No performance gain is claimed from this feedback-only repair.

## Continuation report

REPORT - V2 cistern hand and reticle feedback - 2026-10-22.
Branch **codex/v2-acoustic-topology**, preceding HEAD
**30b326b36fb704c2bedd16226ed92039640a10e4**; origin/main and merge-base
**21f0b1fc27ac8e25c8466fe1ed2ce64019ee7ede**. Canonical shared checkout,
no new worktree, named stage paths only. Four preceding hose WIP files and
unrelated untracked files remain outside this checkpoint. Protected 17/17,
V2 default and explicit V1 rollback unchanged.

The full continuation board reports 107 PASS, two FAIL and one INCOMPLETE:
existing expired surface qualification, two completeness-test assertions and
incomplete coverage remain. It is a census of the dirty shared checkout,
not a clean-main candidate baseline. Final focused spatial and reader gates
pass, six remaining report-only spatial references, zero NEW unread fields.
Register the reviewed book fixture unit reference as TEST_CONTRACT /
UPDATE_TEST_FIXTURE; shifting its source lines had changed the board fingerprint
without changing the spatial audit identity. Existing manifest rows remain.
No requirement promotion or new full-building acceptance is claimed.

The exact original failure receipts remain in the preceding inspection packet.
This packet retains original **hand_v1**, failing **feedback_before_v1**, final
logs, source snapshots and wrapper **suite_run** receipts under
**art/reviews/v2_cistern_hand_20261022**. These are diagnostic, not schema-2
test-written **runtime_contract** proof. No new native art warrants a Blender
rebuild or repeated unchanged surface qualification.

Remaining: deployed hose carrying performance/FPS aiming, released hose,
controllable spray and coupling-aware saves, wider V2 inspections, first-use
tails, renewed qualifications and human acceptance. Owner decision: none.

BLOCKED - complete V2 and merge qualification remain incomplete; continue
authorized repairs.
