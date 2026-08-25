# SR7-I — the first paper on the spindle

**Status: production-rendered proof complete.**

Base `4fea837`. (`origin/main` moved to it mid-work — Codex wiring clock-in to
`offer_opening_report` — so the branch was replayed and every proof re-run.) Captured 2026-08-25 in Forward+ (NVIDIA RTX 4080, Vulkan
1.4.341) through the real `res://scenes/building/orison_root.tscn`, on the
night register built in SR7-G and given its conclusion card in SR7-H
(`art/renders/night_register_sr7g/`, `.../night_register_sr7h/`). Shot through
the player's own camera and lit by the corridor's own ceiling fixtures. No
proof-only light, mesh, material, camera rig or production owner.

Harness: `res://tests/NightRegisterShot.tscn` in three passes over one
directory (`SHOT_PART=a` the card, `b` the round, `c` the papers) — the
production root costs most of the 60-second ceiling to build.

## What changed

The register presented one hardcoded job. It now presents **whichever report
the building actually has open**, and the paper says which one it is.

The immediate purpose is that Mina's already-authored `vantry_chirp_2a` can be
the first report a new watchman takes after clocking in, and that Lena's 2B
follows when its own owner issues it — with no second ledger, no new owner and
no job invented anywhere.

## The selection rule

```gdscript
const PRESENTABLE_JOBS := ["vantry_chirp_2a", "lena_radiator_round_2b"]
const PRESENTABLE_STAGES := ["issued", "acknowledged", "diagnosed",
        "awaiting_part", "repairable", "repaired"]
```

**An authored order, not a scan.** The register presents the first of those two
that the spine is holding open, and it can present nothing else. Writing the
order down rather than sorting a dictionary at runtime means the opening report
is a decision somebody made, and a third job cannot appear on this board by
being issued somewhere else in the building.

`missing` was never issued and `closed` is finished; **everything between is
paper you can hold**. A register that stopped showing a job the moment it was
diagnosed would be losing the report halfway through the round.

The order agrees with what production already produces rather than imposing
anything: `ServiceRoundDirector` gates Lena's call on the chirp being closed,
so 001 was always going to come first.

### The latch

> Never silently swap the paper while a round is open, a report is in hand, a
> key is out, or an outcome is selected.

While the board is **engaged** — any of those four — the presented report is
pinned to whatever it was when the engagement began. One place decides:

```gdscript
if engaged():
    if _latched_job == "":
        _latched_job = first_open_job()
else:
    _latched_job = ""
```

So a board left idle picks up 002 the moment 001 closes, and a board mid-round
does not — even if 001 closes underneath it. **Frames `22` and `23` are
byte-identical**: 002 issued while 001 is open is not a small difference, it is
the same photograph.

### Reload, and why nothing new is persisted

The rule derives the report from `WorkOrders` on every read, and `WorkOrders`
persists its own stages. So a board rebuilt over the same save reconstructs the
same paper **without this apparatus writing a word of it down**. The focused
test asserts the register's whole footprint in the save is still exactly
`{"lines": [...]}` — SR7-G's contract, untouched: `sign_register()` remains the
only writer.

### One deliberate behaviour change

SR7-H left the index standing on the conclusion just signed. SR7-I **returns it
to the blank**, because `outcome_selected()` is one of the four engagement
conditions: a board that stayed engaged after a signature could never present
the next report, and — more importantly — the next watchman would find a
conclusion already entered, which is the one thing that selector exists to
prevent. What was signed is not lost; it is the ink line in the book and the
`filing_printed` in the record.

## The paper says which report it is

Number, name, unit and the complaint, set as real `Label3D` geometry on the
slip and read out of the authored job record — `title` split at its em dash,
`unit`, and the first sentence of `summary`. Nothing is a second copy: change
the record and the paper changes, and a report the library does not hold cannot
be printed at all.

| | 001 | 002 |
| --- | --- | --- |
| number | `WORK ORDER 001` | `WORK ORDER 002` |
| name | `THE CHIRP` | `BORROWED BREATH` |
| unit | `UNIT 2A` | `UNIT 2B` |
| symptom | *A Vantry point in 2A is issuing a line-test tone at three in the morning.* | *Lena Ortiz reports that the 2B radiator exhales while the iron stays cold.* |

**Not one printed line is shared.** Frames `21` and `25` are the two papers at
reading distance.

## Ownership

| Owner | SR7-I |
| --- | --- |
| `CoreLoopDirector.offer_opening_report()` | **Never called.** The register holds no reference to it — asserted by reading its own source. Wiring clock-in to it is Codex's. |
| `ServiceRoundDirector` | Still the only issuer of 002. |
| `WorkOrders` | Still the only lifecycle owner. The register's *entire* reachable surface on it is read out of its source and asserted: **`job_stage` and `acknowledge_job`, and nothing else** — no `issue_job`, `close_job`, `record_job`, `diagnose_job`. |
| `RealityCases` | Still untouched. No reference in the prop at all. |
| signed lines | Each keeps its own `job_id` and `filing`. A line signed under 001 still reads 001 with 002 on the spindle. |

## Definitive frames

All frames 1280×720. SHA-256 truncated to 32 hexadecimal characters. Three
cameras: station/board, the card close-up (`02`–`07`, `17`), and the slip
close-up (`20`, `21`, `25`).

| Frame | SHA-256 | Claim |
| --- | --- | --- |
| `00_station_control_a.png` | `421715d1f2e019bdbfdbfb49325c9ff5` | **As found**: spike bare, keys hung, index on the blank. |
| `00_station_control_b.png` | `421715d1f2e019bdbfdbfb49325c9ff5` | **Byte-identical** — the board camera's A/A floor. |
| `01_station_context.png` | `0e6dbb3193e267c0d1fe319ce57a743e` | Detector and register sharing the wall. |
| `02_card_control_a.png` | `85bad3efedecd1c0e4768e6c4a1e5e95` | The conclusion card; index on `-- NOTHING ENTERED`. |
| `02_card_control_b.png` | `85bad3efedecd1c0e4768e6c4a1e5e95` | **Byte-identical** — the card camera's A/A floor. |
| `03_card_fault_corrected.png` | `40c4efe928c91de2eb532e29b9546198` | Index on **1 FAULT CORRECTED**. |
| `04_card_disturbance_persists.png` | `fa5a28d6891ee057b6278050968d3137` | Index on **2 FAULT CORRECTED, DISTURBANCE PERSISTS**. |
| `05_card_no_fault_found.png` | `feaf98cbc82854aa2420ce3cc81485f3` | Index on **3 NO FAULT FOUND**. |
| `06_card_access_unsuccessful.png` | `39e5b9c80c86d402538f0a2923745ebf` | Index on **4 ACCESS UNSUCCESSFUL**. |
| `07_card_returned_to_blank.png` | `85bad3efedecd1c0e4768e6c4a1e5e95` | Back to the blank — identical to the control. |
| `08_report_on_the_spindle.png` | `7703fe1a6c79fd2d66993ba5554faadf` | The spine issued 001; nobody touched the board. |
| `09_round_open.png` | `de6c407990dfa44c8c4e433e12b955bd` | Report in hand, plant key out, check 7 hung. |
| `10_refused_key_already_out.png` | `6d0c94bc46de5118d6bac80aefffc079` | **Refusal — the hook.** |
| `11_refused_signing_with_keys_out.png` | `46a3bc577bf2c9a35b75ad3f7bbc1a20` | **Refusal — a key is still out.** |
| `12_refused_signing_report_in_hand.png` | `afb1a43396c50afc705927e3ca14cd89` | **Refusal — the report is still in hand.** |
| `13_refused_signing_on_the_blank.png` | `06f607ef214f31cb4e6e24b769b3af5e` | **Refusal — the index is on the blank.** |
| `14_conclusion_chosen.png` | `0b8a134773534d7adb76fdd6fbd4e1c2` | Conclusion 2 chosen by hand. |
| `15_signed.png` | `3f6407cc20cf0c4b73df1efbb751351a` | Signed: a line in ink, and the index back on the blank. |
| `16_refused_signing_again.png` | `1c06da12e3feeb7b3f32d980d81cf804` | **Refusal — idempotent.** |
| `17_card_after_signing.png` | `9788756123764e03d1c20e458e92bc45` | The card, reset for whoever comes next. |
| `18_station_after.png` | `a86527ee4a74409e1c92cd8495b074d7` | The station afterwards. |
| `19_restored_after_abort.png` | `7703fe1a6c79fd2d66993ba5554faadf` | **Abort — byte-identical to `08`.** |
| `20_slip_control_a.png` | `6d9d33b3aed5385a3eb2287343b14a4d` | **The empty spindle**, close. No open work, no paper. |
| `20_slip_control_b.png` | `6d9d33b3aed5385a3eb2287343b14a4d` | **Byte-identical** — the slip camera's A/A floor. |
| `21_slip_mina_2a.png` | `78d7511eb9dcaf744e892ba01cf7754e` | **001 on the spindle, readable**: number, name, unit, symptom. |
| `22_board_mina_2a.png` | `e71dfce4a36525b5ef3c236d19d738ca` | 001 on the board. |
| `23_board_002_issued_001_still_shown.png` | `e71dfce4a36525b5ef3c236d19d738ca` | **002 issued while 001 is open — BYTE-IDENTICAL to `22`.** The paper did not move. |
| `24_board_lena_2b.png` | `8137a7ac4a6232392cdf7e206e4cca7a` | 001 retired by the spine; **now** 002 comes up. |
| `25_slip_lena_2b.png` | `8a1d402b5eb647317b3ecb8b6cf6a9e3` | 002 close: a different document in every printed line. |

**Twenty-three unique images across twenty-nine frames.** All six collisions
are deliberate identities: three A/A pairs, the card returning to blank, the
abort, and the non-swap. None is a missing capture.

## Pricing

Normalized RMSE, ImageMagick. **Every A/A floor on all three cameras and the
declared crop is exactly 0.000000**, confirmed by matching SHA-256.

| Pair | RMSE |
| --- | ---: |
| board control A → B | **0.000000** |
| card control A → B | **0.000000** |
| slip control A → B | **0.000000** |
| session start → **restored after abort** | **0.000000** |
| **001 open → 002 issued** | **0.000000** |
| empty spindle → 001 on it *(slip camera)* | 0.094003 |
| **001 → 002** *(slip camera)* | 0.014961 |
| bare board → 001 on it *(board camera)* | 0.039565 |
| 001 closed → 002 presented *(board camera)* | 0.006332 |
| refusal on the blank → conclusion chosen | 0.004796 |
| conclusion chosen → signed | 0.006170 |

### Declared crop — the slip on the board camera, `260x300+300+110`

| Change | RMSE |
| --- | ---: |
| A/A floor | **0.000000** |
| bare spindle → 001 on it | 0.135902 |
| **002 issued, 001 still shown** | **0.000000** |
| 001 closed → 002 on the spindle | 0.021762 |

The two zeroes are the point of the sheet. The paper appearing scores 0.1359 on
its own subject; the paper *not* changing when it must not scores exactly
nothing.

## One sheet was thrown away

`close_job` refuses from `issued`, so the first part-`c` run closed nothing and
002 never came up — a frame that looked like a bug in the register and was a
bug in the harness. The harness now walks 001 through its whole real
lifecycle (`acknowledge → diagnose → awaiting_part → repairable → repair →
close`, taking the `required_item_id` road the record declares) and prints the
stage it reached.

## Executable proof

Every run through `tools/run_godot_serial.ps1`, one instance, 60-second
ceiling, full engine output redirected and only filtered results read. **Zero
script errors, zero parse errors, no timeouts.**

- `NightRegisterTest.tscn`: **PASS 148/148** (was 118/118 at SR7-H).
  - empty spindle with neither report issued, and touching it issues nothing;
  - 001 appears when issued, and identifies itself by number, unit and symptom;
  - taking it acknowledges **exactly** 001 and reports the id it took;
  - 002 issued mid-round does not move the paper — **and neither does 001
    closing underneath it**;
  - the round files under 001, the job it was actually taken for;
  - with the round signed off, 002 comes up and prints itself instead;
  - a board rebuilt over the same save presents the same report, mid-round or
    idle, and the register persists nothing but `lines`;
  - with both reports closed the spindle is bare again;
  - the printing is live geometry in the tree, and leaves with the paper.
  - Every SR7-G/H proof still green, now running on 001: route order, refusals,
    abort, access ownership, the four conclusions, no free text.
- `NightRegisterLiveTest.tscn`: **PASS 64/64** (was 54/54). On the real Orison:
  the authored order is 001 then 002; at boot both are missing and the spindle
  is empty; both issuing owners exist and neither is this board
  (`CoreLoopDirector.offer_opening_report` for 001, `ServiceRoundDirector` for
  002); 002 issued does not displace an open 001; once 001 closes the real
  board presents 002; the line already signed still reads 001. Plus SR7-G/H:
  231 lamps, 215 switches, 119 vantry points, 550 acoustic nodes, schedules and
  the Dream block all unchanged.
- **`FirstShiftRitualTest`: PASS (0 failures)** and **`CoreLoopTest`: PASS** —
  Codex's reserved suites over the owners this board reads. `FirstShiftRitualTest`
  issues only 002, and the authored order falls through to it, so its contract
  is unaffected.
- `MaintenanceServiceRoundTest`, `MaintenanceActivityTest`: **PASS**.
- **`MaintenanceWatchmanLiveTest`: PASS 46/46** — the seam reported in SR7-H
  (the detector's prompt turned phase-dependent) was fixed by `7fc9288`.
- `InteractionInventory`: functional 276/32, unchanged.
- `WalkTest` (FAST): **239 pass, 2 fail** — `the chirp hunt` and `boiler's long
  parts list`. Both **pre-existing**, reproduced identically on a clean
  detached worktree at `7fc9288`, the immediately preceding head.

## An invariant that had to be restated, honestly

SR7-H's live proof asserted **"no case signal was published"**. That passed only
because 002's case has no owner watching its stages. Presenting 001 changes
that: `CoreLoopDirector` owns the chirp's case boundary, so Mina's case moves
when the **spine** reaches `repaired`.

The live test now proves the attribution in three steps rather than asserting
the world stays still:

1. issuing 001 moves **no** case;
2. the board taking and acknowledging it moves **no** case;
3. the case moves only when the test drives the spine to `repaired` through
   `WorkOrders` — with the board untouched.

And the surviving invariant is the one that was always meant: **every case that
moves belongs to a presented report's own declared `case_id`**, and this board
is never what moved it. The register holds no `RealityCases` reference at all.

## Limitations

- **Two reports.** The order is authored, so a third job needs a line added
  here. That is the intended trade against scanning.
- **The in-hand condition is not persisted.** A reload reconstructs the
  presented *report*, not the fact that it was in your hand — the round is a
  session thing and the ledger is the persistent thing. Making the round
  survive a reload would mean a second writer to `RealityState`, and
  `sign_register()` being the only one is a contract three increments deep.
- **Nothing calls `offer_opening_report()` yet**, so in a live game the spindle
  is bare until an owner issues 001. That wiring is Codex's clock-in seam.
- The symptom is the summary's first sentence. Both existing records happen to
  open with exactly the complaint; a record that opened with something else
  would print something else.
