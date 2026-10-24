# Separate unracked hose candidate — 2026-10-22

Evidence class: **INERT**. Candidate implementation and diagnostics only.
No production removal, spray, save/reconstruction or human acceptance.

The owner's removal interaction replaces static stored folds with a separate,
simple extended hose. Stored stock has no hose solver. The candidate keeps
15.24 metres of material with 135 native rings and 17,280 triangles. The
original coupling, gasket and maintenance authorities remain. This component
is mounted by diagnostic scenes only.

| Location / reproduction | Severity / evidence | Repair / verification |
| --- | --- | --- |
| Stored hose simulation | High: dense stored-form experiments were expensive and had crossing native skins. | Retired in **V2_STORED_HOSE_DIAGNOSTICS_2026-10-22.md**. The new owner starts hidden with processing disabled. Actual click, mouse pull and release swap representations only after occupancy and nozzle sweeps pass. |
| Round hose bends and crossings | High: early native payout has 1,620 crossing triangle pairs. | Native continuous round-contact constraints, physical bend bounds and conservative world sweeps reject invalid proposals. Six final native poses have zero crossing pairs and nonmanifold edges, positive volume and a working known-crossing control. |
| Full-length carrying | High: **guide_v6** has 357 pending events out of 510 and CPU pose-acceptance p50/p95/p99/max 40.236/614.930/621.316/628.698 ms. | Exact material-length seeds and one fully swept proposal avoid repeated microsteps. **guide_v9** has 272 events, zero pending events and CPU acceptance 4.785/5.028/5.211/5.259 ms. The original 15.09 m endpoint-span threshold passes at 15.098208 m; full material remains 15.24 m. |
| Rotating nozzle collision | High: rebuilding convex stock costs 44–51 ms per input in a rejected intermediate. | Cache immutable stock bounds; conservatively bound rotation arcs and sweep original convex shapes when occupied. A real blocker stops motion and the shared reticle reports blockage. |
| Picking after the nozzle turns | Diagnostic defect: an early fixture clicked the nut while expecting the barrel. | Aim at the actual imported barrel and confirm authoritative part identity before moving. Original failed runs remain. |
| Loaded cloth finish | Required UVs, custom PBR, normal mapping and mipmaps. | Native metre charts, registered linen, loaded three-map mip chains and UV/TBN checks pass in isolation. Composed-world appearance remains pending. |
| Actual stair cabinets | High: the initial isolated-floor layout does not fit the building. | Complete-world survey retains player collision and all architecture. All eight stations refuse initial deployment: six lift jambs, the roof plant guard and the walked F02 player obstruct proposals. Repair remains open. |

Quantiles use linear interpolation over original event records. CPU input and
accepted pose submission are not displayed latency. Both compared isolated
runs disable following-camera player physics and capsule collision. These
are not played-world frame-time gains. Production collision layers remain
unchanged. Neutral native renders do not prove installed atmosphere or access.

## Continuation report

Branch: **codex/v2-acoustic-topology**, canonical **C:/PleaseRemainOnTheLine**.
Previous pushed checkpoint: **d14cc63e**. Origin main and merge-base remain
**21f0b1fc27ac8e25c8466fe1ed2ce64019ee7ede**. No new worktree.

Changes: separate native round asset, owner-controlled removal and constrained
carrying, opt-in native guide/contact methods and actual-input diagnostics.
Legacy tether defaults remain unchanged. Sparse and dense control traces match
their previous controls in every non-timing field; only **profile_usec** is
excluded. The new component is not installed in the production builder.

Verification: final round-contact controls, legacy follower kernel, 69
reticle/hand checks and sparse/dense controls pass. Native renders cover poses
0, 64, 128, 192, 256 and 272 of the final pull. Wrapper receipts are **suite_run**
and Blender receipts are diagnostic, not runtime contracts. The foundation
board remains non-green on surface qualification, the incomplete ledger and
its completeness test. No merge-ready or V2-complete claim is made.

The complete checkpoint board has 107 PASS, two FAIL and one INCOMPLETE.
All seventeen protected paths match main after LF normalization; selector V2
and explicit V1 rollback pass. Reader audit has zero new unread fields.
Two new incidental spatial records identify the new test fixture's riser name
and walked survey coordinates; there are no new failing spatial bindings.
The clean-main comparison still reports 77 regressions, including these new
report-only records and the preceding branch's qualification debt. This is a
diagnostic checkpoint, not a management candidate.

The corrected alternate-direction survey also refuses all ten additional F02
layouts. The previous alternate survey's one-initialization test-harness bug
is retained in **world_survey_v2**; **world_survey_v3** creates a fresh owner per
direction and records actual architecture/player obstructions. A compact
off-rack floor-layout proposal is the next repair; it is not yet qualified.

Open work: world-fitting route and frame-time comparison, released endpoint
behavior, collision protection for other moving bodies, default bare-end
removal, coupling-aware save/rebuild, supply-valve/nozzle-controlled spray,
installed free-cursor inspection, broader V2 coverage and human review.
Do not install the candidate because isolated payout passes.

Decision needed from owner: none. Full deployment and controllable spray are
authorized. Continue implementation and preserve physical obstructions.
