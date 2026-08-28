# Orison v2 M10 runway report — 2026-08-28

**Task:** DEV-M10-1 — prove the golden-shift run card is executable under
explicit v2. **Role:** verification only. No gameplay was authored, no
spatial schema or blockout was touched, and no human acceptance is claimed
or implied by anything below.

**Base:** `e89fa60` (the tip of `origin/main`). The Open Shift integration
(`claude/ethos-open-shift-authority`) has **not** landed on main, so this
verification is based on `e89fa60` as instructed. Two consequences are
recorded as conditional items, not failures: the Open Shift disposition
suites and `tools/audit_systemic_situation_authority.py` exist only on that
unlanded branch and cannot run at this base (see gap G7).

**Branch:** `claude/golden-shift-v2-verify-c72c73`. Additive files only.

## Verdict

Every automated precondition of the eleven-beat run card that is capable of
running under explicit v2 today was run and passed. The completeness
ledger's single golden-shift blocker, `golden.eleven_beats`, is encoded as
HUMAN_ACCEPTED-only (`tools/audit_orison_v2_completeness.py:965-975`): it
clears only when a golden-scoped human acceptance receipt with verdict PASS
exists. **The runway is clear in the sense that no automated gate stands
between the owner and the chair.** Three composition facts about the v2
runtime are pre-declared below (gaps G2–G4) because the human runner will
meet them mid-run; by the card's own rules a stop at the first blocked
transition is a valid result, but the owner should know these are known
before sitting down rather than discovered by the tester.

The three repository gates are exactly as clean as found: completeness
golden-shift query exits 2 with exactly the one expected blocker, the
spatial dependency audit exits 0 clean (588 preserved records, 0 failures),
and the three Python unit suites pass 140/140. `BuildingRootSelector.DEFAULT_ID`
remains `v1` and the production layout remains byte-stable — both asserted
in-run by the passing v2 suites ("committed selector remains v1",
"production layout remains byte-stable") and by a clean final `git status`.

## Selection discipline

- Every Godot suite below ran with `ORISON_BUILDING_ROOT=v2` set in the
  invoking shell only. `DEFAULT_ID` was never edited.
- Only two suites pin the selector themselves via
  `BuildingRootSelector.reset_for_tests("v2")`:
  `game/tests/orison_v2_m08f_runtime_test.gd:20` and
  `game/tests/orison_v2_two_root_matrix_test.gd:16-24`. No test reads the
  environment variable directly; the selector is the only reader
  (`game/scripts/building/building_root_selector.gd:16`).
- One control run (DreamBoundaryTest, selector unset) was performed to
  prove a v2-specific failure was not a tree regression; it is labeled as
  the control in the exit-code table.

## Per-beat table

Postures: **explicit-v2** (instantiates the selector-chosen v2 runtime),
**agnostic** (owner/state-machine logic, never loads a building — valid
under any selector), **v1-world** (proof exists but the world it walks is
hardcoded to the v1 root), **review-v2** (walks v2 geometry via a review
blockout scene, not the selector runtime).

| Beat | Automated proof (file:line) | Result this run | Human half remaining |
| --- | --- | --- | --- |
| 1 arrive and clock in | Ritual + reload reconstruction: `game/tests/first_shift_ritual_test.gd:41,59-77,106-108` (agnostic). Custody: `first_shift_custody_test.gd:36-46` (agnostic). Coordinator: `core_loop_test.gd:111-136` (agnostic). Full walk: `golden_loop_test.gd:267` complaint block + checkpoint "issued" (v1-world). K3 facts under v2: `orison_v2_two_root_matrix_test.gd:110-113,142-146` reconstructs first-shift phase/report/filing in all four v1/v2 directions (explicit-v2). | ALL PASS, exit 0 | Physically finding the register and slip inside the v2 lobby, unaided. The clock-in ritual has never been driven inside a v2 world. |
| 2 find the fault by ear | Audibility contract: `chirp_reachable_test.gd:46-141` — cue interval ceiling, enforced silence floor, listener-blind source discipline (agnostic, PASS 31/31). Walk-and-listen: `golden_loop_test.gd:302-310` (v1-world). v2 acoustic owner composed: `orison_v2_runtime_root.gd:50-52` installs the override on the F02 vantry point; `orison_v2_two_root_matrix_test.gd:49-50` asserts the acoustic node exists (explicit-v2). | ALL PASS, exit 0 | Locating the fault by ear inside v2 geometry — no automated walk does this under v2. The card's exact K3 moment (standing at the fitting, **before** inspecting) is untested anywhere; the nearest checkpoint is after inspection (`golden_loop_test.gd:311`, gap G6). |
| 3 name the part | Part authored + gate: `maintenance_job_test.gd:28-35,104-107`; objective text reconstructed from data, not persisted: `:170-172` (agnostic). K3: `core_loop_test.gd:168-171` awaiting-part roundtrip (agnostic). Prompt names the part on v2 geometry: `orison_v2_integrated_test.gd:136-142` (review-v2). Full walk: `golden_loop_test.gd:305-313` (v1-world). | ALL PASS, exit 0 | Whether the diagnosis is legible and reachable in the v2 2A flat as a player experiences it. |
| 4 fetch it | Real shop transaction + K3: `core_loop_test.gd:174-182` (agnostic — constructs the shop service by hand). Physical buy: `golden_loop_test.gd:350-364`, `shop_entry_test.gd:283-321` (v1-world). **Under explicit v2: none, and none possible** — MaintenanceShopService is composed only by the v1 root (`building_root.gd:350-351`); `orison_v2_runtime_root.gd` contains no shop or street composition (gap G2). | Agnostic/v1 proofs PASS, exit 0. v2: NO ENTRYPOINT | Everything. Under v2 there is currently no composed part source; K2 is expected to block at this beat unless the owner rules the v2 route sources the part differently. |
| 5 come back | Return route + reopened door + floor arrival: `golden_loop_test.gd:369-395` (v1-world). v2 collision-bearing there-and-back walk: OrisonV2M08ESpatialTest — boiler-ritual-2B-porter-boiler-radiator route (review-v2, `orison_v2_m08e_spatial_test.gd:24-70`). Street-to-bedside traversal: `orison_v2_integrated_test.gd:42` (review-v2). | ALL PASS, exit 0 | "Notice whether the building is the same as you left it" — no test asserts world changes persist across the round trip. The beat-5 K3 boundary (back at the fitting, before starting work) is uncovered anywhere (gap G6). |
| 6 make the repair | Vantry repair, consume, quiet, earned conversation: `golden_loop_test.gd:404-424` + checkpoint (v1-world). K3: `core_loop_test.gd:193-197` (agnostic). **Explicit-v2 repair mechanism:** `orison_v2_m08f_runtime_test.gd:62-90` — premature mechanisms cannot counterfeit progress, evidence earns repairability, duplicates cannot double-advance, the real 2B radiator authority records the repair. Vocabulary: `maintenance_job_test.gd:108-116` (agnostic). | ALL PASS, exit 0 (M08F 29/29) | The card's point of the beat — resistance, commitment feel, telling it worked unaided — is inherently human. Note the explicit-v2 repair proof is the **service-round radiator**, not the vantry job the card follows. |
| 7 talk to the resident | Full Mina tree incl. wrong turns, earned silence, integration: `mina_case_gameplay_test.gd:48-147` (agnostic). Real conversation + release + not-re-offered K3: `golden_loop_test.gd:431-442,481-518` + checkpoints "conversation_pending"/"conversation_complete" (v1-world); `core_loop_test.gd:227-232` (agnostic). Explicit-v2 resident interaction: `orison_v2_m08f_runtime_test.gd:67-70,87-90` — threshold acknowledges the work order, return closes the round (Lena, not Mina). v2 does compose MinaCaseGameplay (`orison_v2_runtime_root.gd`). | ALL PASS, exit 0 | Mina's authored conversation has never run inside a v2 world; only Lena's service-round dialogue has explicit-v2 proof. |
| 8 it comes back | Recurrence semantics: `reality_case_test.gd:21-28` (temporary stabilization, recurrence at higher stage); letter under the door: `mina_case_gameplay_test.gd:60-78`; full-walk recurrence + second stabilization: `golden_loop_test.gd:449-476` (v1-world); `core_loop_test.gd:209-212` (agnostic). | ALL PASS, exit 0 | **The beat-8 K3 boundary is uncovered by any test, v1 included** — no save/reload exists inside a recurrence anywhere (gap G5). "The recurrence has not been undone by reloading" rests entirely on the human check. Noticing recurrence without being told is also human-only. |
| 9 sleep takes the shift | Onset form, warning, four physical gates (engaged, unstable body, elevator seam, traffic), presentation sharing: `sleep_pressure_test.gd:38-94` (agnostic, PASS 20). **K3 at the card's exact moment:** mid-onset real-file save at elapsed 1.3 s, destroy, restore resumes the same request and exact midpoint without re-announcing: `sleep_pressure_test.gd:95-118`. Production-shell smoke (the only selector-live CampaignShell spawn): `dream_boundary_test.gd:250-276`. | SleepPressureTest PASS, exit 0. **DreamBoundaryTest under v2: FAIL 1 of 36 checks** (gap G4; 39/39 PASS in the v1 control) | Warning sufficiency and "taking a turn vs punishment" are human. Under v2 the physical sleep-gate owners are null (`orison_v2_runtime_root.gd:27-28`), so the carriageway/elevator gating the human would feel in v1 does not exist in v2. |
| 10 the dark | Dream boundary transactions — armed/entered/active/return-pending/awake, each with real-file checkpoint, destroy, restore, reconcile; same room, not a chase frame: `dream_boundary_test.gd:41-106` (agnostic; these 35 checks all passed in the v2 run). Pursuit/capture in the real maze: DreamPursuitTest PASS 39/39 (agnostic). Golden loop stubs the dream entirely (`golden_loop_test.gd:30-56`) and proves only single-arming with the authored case/profile/window (`:542-549`). | ALL boundary + pursuit checks PASS, exit 0 | "You learn one true thing about the resident's situation" — no test asserts a learned fact crosses back into the case. Knowing **why** the passage ended is human. |
| 11 wake in your own room | Wake preservation set + bedside anchor + duplicate rejection + K3: `golden_loop_test.gd:557-611` incl. residue surviving the save boundary exactly once (v1-world); `core_loop_test.gd:257-282` (agnostic); awake restores resurrect nothing: `dream_boundary_test.gd:99-106` (passed in the v2 run). **Explicit-v2 bedside contract:** `orison_v2_m08f_runtime_test.gd:126-127` (v2 wake uses the explicit bedside-return contract) and `orison_v2_two_root_matrix_test.gd:54-55,93-94,142-146` (wake-complete boundary + safe-return anchor reconstructed in all four selector directions; v1 anonymous-bed fallback intact). | ALL PASS, exit 0 | The waking residue has no v2 owner — MinaCaptionManifestation is composed only by the v1 root (gap G3) — so "the room is as you woke into it" and the residue itself are human-only observations under v2, and the residue will simply be absent. |

## Commands run and exit codes

Working directory for all commands: this worktree root. All Godot runs were
one process at a time; the shared lane was checked free before every run.
The fresh worktree required `--headless --import` first, and the tracked
console executable requires the untracked main executable
(Godot_v4.7.1-stable_win64.exe) beside it — it was copied from the primary
checkout into this worktree (local, untracked, not committed).

| # | Command (abbreviated) | Result | Exit |
| ---: | --- | --- | ---: |
| 1 | `python tools/audit_orison_v2_completeness.py --blockers-for golden-shift` | 1 blocker: golden.eleven_beats [ABSENT] | 2 (expected) |
| 2 | `python tools/audit_orison_spatial_dependencies.py` | clean, 588 preserved records, 0 FAIL | 0 |
| 3 | `python tools/tests/test_orison_v2_completeness.py` | 64 tests OK | 0 |
| 4 | `python tools/tests/test_orison_spatial_dependencies.py` | 48 tests OK | 0 |
| 5 | `python tools/tests/test_interaction_prompt_carriers.py` | 28 tests OK | 0 |
| 6 | `python tools/audit_systemic_situation_authority.py` | **not runnable — file absent at e89fa60** (Open Shift branch only, gap G7) | n/a |
| 7 | Godot `--headless --import` (fresh worktree) | import completed | 0 |
| 8 | serial runner: `res://tests/GoldenLoopTest.tscn` (env v2) | PASS 87/87, blocks ledger exact | 0 |
| 9 | serial runner: `res://tests/CoreLoopTest.tscn` (env v2) | PASS, full boundary trace | 0 |
| 10 | serial runner: `res://tests/RealitySaveCompatTest.tscn` (env v2) | PASS 14/14 | 0 |
| 11 | serial runner: `res://tests/FirstShiftCustodyTest.tscn` (env v2) | PASS, 0 failures | 0 |
| 12 | serial runner: `res://tests/MaintenanceServiceRoundTest.tscn` (env v2) | PASS | 0 |
| 13 | serial runner: `res://tests/DreamBoundaryTest.tscn` (env v2) | **FAIL 1 (36 checks)** — see gap G4 | 0 (exit masks failure, gap G8) |
| 14 | serial runner: `res://tests/SleepPressureTest.tscn` (env v2) | PASS (20 checks) | 0 |
| 15 | serial runner: `res://tests/orison_v2_m08f_runtime_test.tscn` (env v2) | PASS checks=29; committed selector remains v1; layout byte-stable | 0 |
| 16 | serial runner: `res://tests/orison_v2_two_root_matrix_test.tscn` (env v2, 60 s ceiling) | terminated at ceiling — suite needs a direct run (gap G8) | 73 |
| 17 | serial runner: `res://tests/OrisonV2M08ESpatialTest.tscn` (env v2, 60 s ceiling) | terminated at ceiling — suite needs a direct run (gap G8) | 73 |
| 18 | serial runner: `res://tests/OrisonV2IntegratedTest.tscn` (env v2) | PASS, route walk 43.1 s | 0 |
| 19 | direct: `res://tests/orison_v2_two_root_matrix_test.tscn` (env v2, lane checked) | PASS checks=24, all four directions; layout byte-stable | 0 |
| 20 | direct: `res://tests/OrisonV2M08ESpatialTest.tscn` (env v2, lane checked) | PASS incl. collision-bearing route; layout byte-stable | 0 |
| 21 | serial runner: `res://tests/DreamBoundaryTest.tscn` (**control, selector unset**) | PASS (39 checks) — proves #13 is v2-specific, not a regression | 0 |
| 22 | serial runner: `res://tests/FirstShiftRitualTest.tscn` (env v2) | PASS, 0 failures | 0 |
| 23 | serial runner: `res://tests/MaintenanceJobTest.tscn` (env v2) | PASS, full lifecycle trace | 0 |
| 24 | serial runner: `res://tests/RealityCaseTest.tscn` (env v2) | PASS | 0 |
| 25 | serial runner: `res://tests/MinaCaseGameplayTest.tscn` (env v2) | PASS | 0 |
| 26 | serial runner: `res://tests/ChirpReachableTest.tscn` (env v2) | PASS 31/31 | 0 |
| 27 | serial runner: `res://tests/DreamPursuitTest.tscn` (env v2) | PASS (39 checks) | 0 |

Serial runner = `tools/run_godot_serial.ps1 -Scene <scene> -TimeoutSeconds 60
-LogPath <log>`; "env v2" = `ORISON_BUILDING_ROOT=v2` set in the invoking
shell only. Post-verification re-runs of commands 1 and 2 after adding this
report produced identical results (same blocker, same clean spatial audit).

## Gaps, precisely, with owners

**G1 — the golden-loop harness cannot run under v2 by construction.**
`game/tests/golden_loop_test.gd:91` hardcodes
`load("res://scenes/building/orison_root.tscn")`; it never consults the
selector. The 87-check end-to-end walk is therefore v1-world evidence only.
Even if repointed, it would fail for the real reasons in G2/G3. Owner: the
golden-shift v2 milestone (test-fixture lane, disposition
UPDATE_TEST_FIXTURE) — after G2/G3 are decided. Not fixed here: repointing
an existing production test is not an additive change.

**G2 — beat 4 has no part source under v2.** MaintenanceShopService is
composed only by the v1 root (`game/scripts/building/building_root.gd:350-351`);
`game/scripts/building/orison_v2_runtime_root.gd` composes no shop and no
street commerce. Exact consequence: under explicit v2 no automated
entrypoint can prove acquisition, and the human K2 is expected to block at
beat 4. Owner: v2 runtime composition authority (this is part of what the
golden.eleven_beats route needs; any new spaces it requires are ChatGPT's
spatial-schema lane, per the standing lane split).

**G3 — beat 11's waking residue has no v2 owner.** The residue
manifestation owner is composed only by the v1 root
(`building_root.gd:467-470` region); it is absent from
`orison_v2_runtime_root.gd`. Under v2 the residue will not appear, so the
card's "the room is as you woke into it" check observes an absence, not the
authored residue. Owner: v2 runtime composition authority.

**G4 — the only selector-live production-shell smoke fails under v2.**
`game/tests/dream_boundary_test.gd:250-276` spawns the production
CampaignShell. Under `ORISON_BUILDING_ROOT=v2`: the check at `:256-258`
fails because it requires the root node name "OrisonRoot" (the v2 root is
named "OrisonV2Runtime", `game/scenes/building/orison_v2_runtime.tscn:5`);
then `:262` raises `Invalid call. Nonexistent function 'blocks_sleep_entry'
in base 'Nil'` because the v2 root's street_traffic and elevator fields are
deliberate null placeholders (`orison_v2_runtime_root.gd:27-28`), aborting
the remaining three checks (traffic gate, elevator gate,
facts-preserved-after-smoke) — hence FAIL 1 with 36 of 39 checks run. Two
distinct owners: (a) the v1-shaped test expectations are the dream-boundary
test owner's (UPDATE_TEST_FIXTURE); (b) the missing physical sleep-gate
owners under v2 are the v2 runtime composition authority's, and they change
what the human feels at beat 9. The 35 boundary-transaction checks all pass
under v2; the K3 evidence for beats 9–11 stands. Exact failing output is
preserved in the run logs quoted above. Not fixed here per non-interference.

**G5 — beat 8's K3 boundary has no automated coverage at all, v1
included.** `golden_loop_test.gd:449-476` (the recurrence block) contains no
checkpoint; `core_loop_test.gd:209-212` has no roundtrip between reopen and
second stabilization; no case/Mina test saves inside a recurrence. The
nearest boundaries bracket the beat from outside (checkpoints at
`golden_loop_test.gd:422` and `:504`). Owner: K3 test lane (an additive
boundary check would close it).

**G6 — two card K3 moments differ from the nearest automated checkpoint.**
Beat 2's save moment (at the fitting, before inspecting) and beat 5's (back
at the fitting, before starting work) have no corresponding automated
save/reload anywhere; the automated eight semantic boundaries were never
meant to match the eleven route beats one-for-one
(`design/SAVE_RELOAD_TRANSACTION_MODEL_2026-08-27.md:93-97`). Owner: K3
test lane, priority behind G5.

**G7 — two required validation items cannot exist at this base.**
`tools/audit_systemic_situation_authority.py` and the Open Shift
disposition suites live only on `claude/ethos-open-shift-authority`
(commits 51a0619 and 66355da), which has not landed on main. Owner: the
Open Shift integration lane; this verification must be re-extended over
those two items when that branch lands.

**G8 — two operational traps for whoever runs these next.**
(a) DreamBoundaryTest exits 0 even when it prints FAIL — exit codes cannot
gate that suite; the result line must be read (observation for the test
lane). (b) orison_v2_two_root_matrix_test and OrisonV2M08ESpatialTest both
exceed the 60-second serial-runner ceiling and must be run directly (they
passed in 1–4 minutes); the serial runner's exit 73 there is the ceiling,
not a test verdict.

## What the human runner must still do, in order

Automated suites support K3 and cannot replace any of this; a green test is
not one of the eleven checks (run card, "THE TWO JOBS").

1. Print `design/GOLDEN_SHIFT_HUMAN_RUN_CARD_2026-08-27.md`; fill in the
   SETUP block. Read the owner note on G2 first: beat 4 currently has no
   part source under v2, and a K2 stop there is the expected, valid result
   unless composition lands first. The owner should decide before sitting
   down whether to run K2 now (documenting the beat-4 stop) or wait.
2. **K2** — one fresh, uninterrupted curb-to-wake run at default settings:
   `tools/run_orison_v2_m10.ps1 -Gate K2 -Fresh` (pass `-GodotPath` if the
   console executable is not on PATH; in a fresh worktree the untracked
   main executable must sit beside the tracked console shim). No saving,
   no reloading, no coaching; stop at the first blocked or unclear
   transition and write the seven-line stuck report.
3. Fill `art/renders/orison_v2/m10_golden_shift_v2_01/k2_human_run_card.md`
   and `k2_timeline.json`; copy the build commit from the launcher's
   `_private/profiles/k2/launch_receipt.json`.
4. **K3** — only after K2, eleven separate checks:
   `tools/run_orison_v2_m10.ps1 -Gate K3 -Boundary <1..11> -Fresh`, save
   and quit at each card-stated moment, relaunch, and record all four rows
   (resume location, immediate intention, durable owner, physical answer)
   in `k3_human_observations.md` and `k3_boundary_matrix.json`; hash each
   preserved save into `save_hashes.json`. Stop at the first defective
   reconstruction and name which of the three broke.
5. Route any failure as one bounded task named after the missing
   transition. Only a durable golden-scoped human acceptance receipt with
   verdict PASS moves golden.eleven_beats; nothing in this report does.

## Non-interference confirmation

No production file, layout, schema, scene, blockout, selector, checkpoint,
evidence packet, manifest, or baseline was modified. The only committed
change is this report. `BuildingRootSelector.DEFAULT_ID` is untouched
(`git diff` clean over `game/`; asserted in-run by commands 15 and 19). The
production layout hash was asserted byte-stable by four independent passing
suites during the runs. The completeness ledger, spatial audit, and Python
unit suites finished exactly as clean as they were found.
