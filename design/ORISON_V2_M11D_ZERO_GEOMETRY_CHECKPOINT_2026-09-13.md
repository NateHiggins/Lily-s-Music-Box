# Orison v2 M11D zero-geometry checkpoint — 2026-09-13

Evidence class: **TECHNICAL CHECKPOINT — PROMOTES EXACTLY TWO ROWS — NO GEOMETRY — HUMAN ACCEPTANCE ALREADY ON RECORD**

## Disposition

This checkpoint lands the "hour one, zero geometry" item that the Sept-3
rebuild handoff asked for and that no later checkpoint carried out: two v2
spaces that were built, walked and owner-accepted in the M08E gray-box work
have stayed **PROGRAMMED** in the completeness ledger purely because no
admitted checkpoint ever named them in the form the ledger reads. The ledger
admits a document named **ORISON_V2_...CHECKPOINT....md** and raises a
PROGRAMMED space to SPATIALLY_PROVEN when that document names the space's
exact v2 identifier in code formatting. The two identifiers are:

- `F02_B_VESTIBULE` — the apartment 2B vestibule, requirement
  **unit.2B.entry** (dimension 07 domestic minimums, required proof
  SPATIALLY_PROVEN); and
- `F01_WATCH` — the F01 watch, keys and annunciator station, requirement
  **f01.watch_station** (dimension 02 public arrival and F01 program,
  required proof RUNTIME_PROVEN).

Every other identifier in this document is written in bold so that nothing
else moves. The evidence-impact receipt below is the proof that exactly these
two rows changed and no other.

No geometry, layout, script, test, asset or audit tool is changed by this
checkpoint. The production building selector remains **v1**. It does not
authorize M09, selector cutover, v1 retirement, or a merge of any other
branch.

## Authorization, branch, and boundary

- Task: **ORISON-V2-M11D-ZERO-GEOMETRY**, dispatch queue row 2 of
  **design/ORISON_V2_INTERIM_MANAGEMENT_DISPATCH_2026-09-13.md**
  (branch **claude/v2-evaluation-dispatch-981096**), deliverable
  "checkpoint backticking the vestibule and watch ids; 86 to 84".
- Base: **origin/main** at **c2dc01771bc25b07f5dcf7a6040102345b8c57d5**
  (the merge base of the M11 chain; this checkpoint does not depend on the
  chain and can merge independently of it).
- Branch: **claude/orison-v2-m11d-zero-geometry**.
- Worktree before the write: clean. Changed paths: this document only.
- Selector: **v1**.

## Why these two rows and no others

The origin of the item is **design/ORISON_V2_SEPT3_REBUILD_HANDOFF_2026-08-28.md**
lines 101 to 105: "Hour one, zero geometry. A correctly-named checkpoint
backticking F02_B_VESTIBULE and F01_WATCH, and clearing the stale
B1_PUBLIC_LANDING_E. Both spaces are built, walked and owner-accepted, and
block STRUCTURAL purely for want of a backtick. Two blockers, no geometry."
The handoff is classified by the ledger as a work order, not evidence, and
deliberately writes the identifiers in bold, so it could never land the item
itself.

The rehearsal of exactly this amendment is recorded in
**design/ORISON_V2_DRY_RUN_THIRD_REPORT_2026-08-30.md** lines 196 to 203:
its non-landed candidate predicted exactly two status changes,
**f01.watch_station** PROGRAMMED to SPATIALLY_PROVEN and **unit.2B.entry**
PROGRAMMED to SPATIALLY_PROVEN, and the plan
(**design/ORISON_V2_DRY_RUN_PLAN_2026-08-30.md** lines 85 to 97) ruled
"do not land the amendment merely to improve a number". This checkpoint
therefore states the evidence for each space rather than only the name.

### Ledger rows before this document

Read with the completeness audit on the base commit:

| Requirement | Scope | Status | Required proof | Provenance recorded by the ledger | Blocking scopes |
| --- | --- | --- | --- | --- | --- |
| **unit.2B.entry** | unit 2B, space **F02_B_VESTIBULE** | PROGRAMMED | SPATIALLY_PROVEN | v2 space with class, purpose and entrance present; architectural program apartment vestibule row | FULL_BUILDING_STRUCTURAL, PRODUCTION_CUTOVER, V1_RETIREMENT |
| **f01.watch_station** | floor F01, space **F01_WATCH** | PROGRAMMED | RUNTIME_PROVEN | v2 space with class, purpose and entrance present; architectural program superintendent/watch station | FULL_BUILDING_STRUCTURAL, FULL_BUILDING_RUNTIME, PRODUCTION_CUTOVER, V1_RETIREMENT |

Both are among the 86 FULL_BUILDING_STRUCTURAL blockers of the base ledger
on **origin/main** (**ABSENT 52, HUMAN_ACCEPTED 1, PROGRAMMED 42,
RUNTIME_PROVEN 34, SHELL_ONLY 3, SPATIALLY_PROVEN 18**; scopes
**0 / 1 / 86 / 45 / 101 / 103**). The unmerged M11 chain reads two status
counts differently (ABSENT 51, PROGRAMMED 44, SHELL_ONLY 2) with the same
scopes; those movements belong to the chain's own checkpoints and are not
touched here.

### Evidence that the spaces are built, walked and accepted

Schema records, **game/data/orison_v2_blockout.json** on the base commit:

| Space | Level | Class | Rect (m) | Purpose | Walls | Entrances and routes |
| --- | --- | --- | --- | --- | --- | --- |
| **F02_B_VESTIBULE** | F02 | private | 9.5, -3.85 to 11.5, -1.15 | 2B privacy, coat storage and distribution | south, north, west | **F02_B_ENTRY_DOOR** from **F02_SERVICE_CROSSING**; **F02_B_MAIN_OPENING**; **F02_B_THRESHOLD** review station; routes **ROUTE_F02_CORE_2B** and **ROUTE_2B_RADIATOR** |
| **F01_WATCH** | F01 | service | -5.4, -3.85 to -1.2, 0.55 | watch, keys and annunciator | north, west, east | **F01_WATCH_MAIL_DOOR**, **F01_WATCH_CORE_DOOR** |

Built and walked, committed proofs on the base commit:

- **design/ORISON_V2_M08E_SPATIAL_OWNERS_CHECKPOINT_2026-08-28.md**: "The
  v2 schema now owns a coherent F01 caretaker station, a complete apartment
  2B" (line 9); "2B provides vestibule, 18.68 m² living/work room" (line
  11); "The dedicated collision proof traverses boiler control, B1 landing,
  F01 ritual sequence, F02/2B conversation and radiator, F01 porter, B1
  boiler, F02 radiator" (line 17). That checkpoint named only the six ritual
  identities in code formatting, which is why these two rows never moved.
- **game/tests/orison_v2_m08e_spatial_test.gd**: the collision-bearing
  boiler-to-ritual-to-2B-to-porter-to-boiler-to-radiator route (gate at
  line 25); the walked polyline starts inside 2B and exits west through the
  vestibule rect. The suite is in the M11C2 standard battery and passed
  there on 2026-09-13 (exit 0, "ORISON V2 M08E SPATIAL TEST: PASS").
- **game/tests/orison_v2_blockout_test.gd**: route existence from
  **B1_BOILER_ROOM** to **F02_B_MAIN** with vertical travel (line 71),
  single ownership of the **F02_B_** partitions (line 75), door metadata for
  **F01_WATCH_MAIL_DOOR** and **F01_WATCH_CORE_DOOR** (lines 98 to 99) and
  the swing check on **F02_B_ENTRY_DOOR** (lines 499 to 500). Passed on
  2026-09-13 (exit 0, "ORISON V2 BLOCKOUT TEST: PASS").
- **game/scripts/characters/porter_actor.gd** line 15 binds the production
  porter's home station to **F01_WATCH**: the room is a runtime consumer's
  authority today, not a plan.
- Capture packet
  **art/renders/orison_v2/m08e_spatial_owners_checkpoint_03/** with
  **scene_capture_receipt.json**, 13 frames at 1600 by 900; the frames that
  show these two spaces are **01_f01_station_from_lobby**,
  **02_f01_four_owners_and_stances**, **03_f01_station_toward_primary_core**,
  **08_f02_arrival_2b_threshold**, **09_2b_entry_domestic_organization**,
  **12_2b_exit_toward_core** and **13_topdown_complete_service_round**. A
  screenshot receipt is walked evidence, not acceptance, and is cited as such.

Owner-accepted:

- **design/ORISON_V2_M08E_A_HUMAN_ACCEPTANCE_RECEIPT_2026-08-28.md**:
  "Verdict: PASS for the gray-box spatial contract", accepting that packet,
  "the F01 ritual station, apartment 2B radiator service stance, and B1
  boiler route". Being an acceptance-named document its own identifiers are
  ignored by the ledger; it acts only through the curated acceptance grant
  that raised **unit.2B** itself to SPATIALLY_PROVEN, which is why the unit
  is proven while its vestibule entry was not.

What this checkpoint does not claim: it does not raise **f01.watch_station**
to its required RUNTIME_PROVEN. The ledger caps a checkpoint mention at
SPATIALLY_PROVEN by design; runtime proof for the watch station stays open
and that row keeps blocking FULL_BUILDING_RUNTIME, PRODUCTION_CUTOVER and
V1_RETIREMENT. The structural scope caps its demand at SPATIALLY_PROVEN,
which is the only reason two structural blockers clear here.

## Expected completeness movement

The expected ledger movement is exactly two promotions and no new
requirement:

- **unit.2B.entry**: PROGRAMMED to SPATIALLY_PROVEN, clearing
  FULL_BUILDING_STRUCTURAL, PRODUCTION_CUTOVER and V1_RETIREMENT for that row.
- **f01.watch_station**: PROGRAMMED to SPATIALLY_PROVEN, clearing
  FULL_BUILDING_STRUCTURAL only.

Predicted counts on the base: **PROGRAMMED 42 to 40, SPATIALLY_PROVEN 18 to
20**; blocker scopes **0 / 1 / 86 / 45 / 101 / 103** to
**0 / 1 / 84 / 45 / 100 / 102**.

Measured on this document (transcribed from the audit output; see the
validation table for the raw lines):

Ledger before (this document set aside): **ABSENT 52, HUMAN_ACCEPTED 1, PROGRAMMED 42, RUNTIME_PROVEN 34, SHELL_ONLY 3, SPATIALLY_PROVEN 18**; scopes **0 / 1 / 86 / 45 / 101 / 103**.

Ledger after: **ABSENT 52, HUMAN_ACCEPTED 1, PROGRAMMED 40, RUNTIME_PROVEN 34, SHELL_ONLY 3, SPATIALLY_PROVEN 20**; scopes **0 / 1 / 84 / 45 / 100 / 102**.

Evidence-impact receipt for this document: exit **1**, admitted as
evidence (marker CHECKPOINT), requirements_changed = **[f01.watch_station: PROGRAMMED to SPATIALLY_PROVEN, unit.2B.entry: PROGRAMMED to SPATIALLY_PROVEN]**. For this
document the correct exit is 1 (it changes requirement status), the inverse
of every prior checkpoint's inert receipt.

## Stale identifier finding, not cleared here

The Sept-3 item also asked to clear the stale **B1_PUBLIC_LANDING_E** claim
in **design/ORISON_V2_M08E_SPATIAL_OWNERS_CHECKPOINT_2026-08-28.md** line
25. The dispatch of 2026-09-13 states that claim is already gone; on the base
commit the audit still reports it (**stale_checkpoint_ids: 1**). The
identifier does exist in the v2 layout, in the platforms array, which the
audit's identity universe does not include (only spaces, doors, openings,
anchors, risers, stairs, lift landings and levels). It is a finding beside the
requirement list, blocks no scope, and does not affect 86 to 84. Clearing it
honestly means widening the audit's identity universe, a tool change outside
this zero-geometry checkpoint; it is left open and named here rather than
edited away in a frozen M08E document.

## Validation and audit disposition

Standard battery per the 2026-09-13 dispatch rulings: completeness, spatial,
systemic authority, period dates, data consumption (reader), the interaction
prompt carrier suite and every tools test, all with real exit codes captured
through log files. No Godot suite is run by this checkpoint because it
changes no runtime file; the Godot proofs it relies on are the committed
suites cited above, last run in the M11C2 battery on 2026-09-13.

| Proof | Command | Exit | Result |
| --- | --- | ---: | --- |
| Completeness audit | python tools/audit_orison_v2_completeness.py | 2 | ABSENT 52, HUMAN_ACCEPTED 1, PROGRAMMED 40, RUNTIME_PROVEN 34, SHELL_ONLY 3, SPATIALLY_PROVEN 20; blockers 0 / 1 / 84 / 45 / 100 / 102 |
| Evidence impact of this checkpoint | python tools/audit_orison_v2_completeness.py --evidence-impact design/ORISON_V2_M11D_ZERO_GEOMETRY_CHECKPOINT_2026-09-13.md | 1 | admitted as evidence (marker CHECKPOINT, epoch 2); CHANGES 2 requirement(s): f01.watch_station PROGRAMMED to SPATIALLY_PROVEN; unit.2B.entry PROGRAMMED to SPATIALLY_PROVEN |
| Spatial dependency audit | python tools/audit_orison_spatial_dependencies.py | 0 | clean |
| Systemic situation authority audit | python tools/audit_systemic_situation_authority.py | 0 | vanished baseline entries (cleanup): 0 |
| Period date audit | python tools/audit_period_dates.py | 0 | PERIOD DATE AUDIT: PASS (10 classified findings) |
| Data-consumption (reader) audit | python tools/audit_data_consumption.py | 1 | report with zero exceptions, unchanged by this document (no data file changed) |
| Interaction prompt carrier audit (report) | python tools/audit_interaction_prompt_carriers.py | 1 | forbidden 2 (clock_prop Hold E, pre-existing, awaiting K2), legacy_uncovered 0, covered 185, stale 0, cleanup 1 |
| tools/tests/test_data_consumption.py | python tools/tests/test_data_consumption.py | 0 | OK, 4 tests |
| tools/tests/test_interaction_implementors.py | python tools/tests/test_interaction_implementors.py | 0 | OK, 31 tests |
| tools/tests/test_interaction_prompt_carriers.py | python tools/tests/test_interaction_prompt_carriers.py | 0 | OK, 28 tests |
| tools/tests/test_orison_spatial_dependencies.py | python tools/tests/test_orison_spatial_dependencies.py | 0 | OK, 51 tests |
| tools/tests/test_orison_v2_completeness.py | python tools/tests/test_orison_v2_completeness.py | 0 | OK, 91 tests |
| tools/tests/test_room_checkpoint_linter.py | python tools/tests/test_room_checkpoint_linter.py | 0 | OK, 29 tests |
| tools/tests/test_room_checkpoint_reconciler.py | python tools/tests/test_room_checkpoint_reconciler.py | 0 | OK, 38 tests |
| tools/tests/test_room_evidence_verifier.py | python tools/tests/test_room_evidence_verifier.py | 0 | OK, 34 tests |
| tools/tests/test_room_gate_hook.py | python tools/tests/test_room_gate_hook.py | 0 | OK, 24 tests |
| tools/tests/test_room_layout_workbench.py | python tools/tests/test_room_layout_workbench.py | 0 | OK, 35 tests |
| tools/tests/test_room_reconstruction_gate.py | python tools/tests/test_room_reconstruction_gate.py | 0 | OK, 26 tests |
| tools/tests/test_room_reconstruction_progress.py | python tools/tests/test_room_reconstruction_progress.py | 0 | OK, 24 tests |
| tools/tests/test_systemic_situation_authority.py | python tools/tests/test_systemic_situation_authority.py | 0 | OK, 34 tests |

## Remaining limitations and debts

- **f01.watch_station** still requires RUNTIME_PROVEN; a runtime-composition
  checkpoint with a passing runtime authority receipt is the only path.
- **B1_PUBLIC_LANDING_E** remains reported stale for the tool reason above.
- **unit.2B** is mapped by identifier grammar (a heuristic unit); the ledger
  documents that a heuristic unit reaches SPATIALLY_PROVEN when a checkpoint
  names its spaces, and that is the path used here.
- The 84 remaining structural blockers are geometry work; none is touched.

## Decision

Technical recommendation: **MERGE-CANDIDATE**, independent of the M11 chain.

Human review: **not required for the promotion itself** (the spaces carry
the M08E-A owner verdict); the owner may still veto the reading that a
checkpoint mention is the right instrument for these two rows.
