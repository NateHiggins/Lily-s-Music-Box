# SR7-H — the words you sign

**Status: production-rendered proof complete.**

Captured 2026-08-25 in Forward+ (NVIDIA RTX 4080, Vulkan 1.4.341) through the
real `res://scenes/building/orison_root.tscn`, in the F01 lobby corridor, on
the writing slope of the night register built in SR7-G
(`art/renders/night_register_sr7g/README.md`). Shot through the player's own
camera and lit by the corridor's own ceiling fixtures. No proof-only light,
mesh, material, camera rig or production owner.

Base: `1ebdf15`. `origin/main` moved twice during this work — `199960a`
landed the director's consumer for `register_signed`, and `1ebdf15` followed —
so the branch was replayed onto each in turn and every proof below was re-run
on the final one.

Harness: `res://tests/NightRegisterShot.tscn` through the serialized Godot
runner with `-Windowed`, in two passes (`SHOT_PART=a`, then `b`) over one
directory — the production root costs most of the 60-second ceiling to build,
and twenty-two frames do not fit in what is left.

## The truth this teaches

**The register records the claim. It does not check the claim.**

SR7-G's board could say what was missing and never where it went. SR7-H adds
the other half of that silence: the board now asks you to say what happened,
offers exactly four things you are allowed to say, and then writes down
whichever one you chose without testing it against anything.

The proof is a single measured fact: **a job the spine holds at `repaired` can
be filed as "fault corrected; disturbance persists", and the apparatus does not
argue.** The radiator is warm. The work order says the repair was recorded,
quality `good`. You put the index on line 2 and sign, and line 2 is what goes
in the book. Nothing corrects you, and nothing corrects the work order either.

That is not a moral branch and it is not a supernatural diagnosis. It is the
ordinary condition of maintenance paperwork: **the record is a person's
statement, and the machinery it describes is somewhere else.**

## The mechanism, and why this one

An **engraved conclusion card** with four numbered lines and a printed blank,
and a **detented brass index** running in a groove down its margin. The card
lies on the writing slope beside the ruled book, tilted 23° — flatter than the
ledger, so its printing turns toward a standing reader.

Two design consequences fall straight out of the object:

- **There is no default.** The index rests on a line the card has *printed*:
  `--   NOTHING ENTERED`. A resting position you can read is a fact you can
  photograph; an unset variable is not.
- **A fifth conclusion is unreachable rather than rejected.** The selection is
  `index_detent`, a position between 0 and 4, and the conclusion is *derived*
  from it. There is no stored `selected_outcome` field for job state — or
  anything else — to set behind the player's back, and there is nowhere on the
  card for the index to stand that is not one of the four.

Choosing costs deliberate pushes: the index advances one detent at a time and
wraps *through* the blank, so conclusion 4 is four pushes from rest and the
blank is never something you skip past on the way to somewhere else.

## Sources

**Documented:**

- **Elias Abraham, US 853,851, "Hotel-Indicator", filed 23 November 1906,
  granted 14 May 1907.** A casing "provided with a plurality of transparent
  apertures", behind them "cards … having indicating words thereon", changed by
  "depressible levers adapted to individually operate the indicator cards". A
  fixed vocabulary of printed words, mechanically brought into view — the
  direct ancestor of a status board that cannot say anything it was not
  printed with.
  <https://patents.google.com/patent/US853851A/en>
- **Job Hutchinson, assigned to National Indicator Company, US 1,067,249,
  "Changeable Indicator", filed 19 January 1910, granted 15 July 1913.** The
  indicating portion carries "marks or legends suitable for the purpose for
  which the indicator is designed", displayed by "movable webs or curtains …
  each mounted upon a spring drum" and changed with a crank. Same principle,
  larger machine: the legends are manufactured into the instrument.
  <https://patents.google.com/patent/US1067249A/en>
- Carried forward from SR7-G, for the board this sits on: **R. H. Thayer,
  Thayer Telkee Corp, US 1,749,399, "Key Tag", filed 6 April 1926**, a pending
  application in the Orison's 1928.

**The point of both indicator patents, and it is the design brief:** in 1928 a
status instrument is a *closed vocabulary*. Free text is a thing you write in a
book by hand; an indicator shows one of the legends it was built with. The
impossibility of filing "the walls were breathing" is therefore a property of
the object rather than a validation rule bolted on top of one — and the focused
test asserts it that way round.

**Orison-specific inference, stated plainly:** the card, its four printed
lines, the blank, the index and its five detents are authored. The four
conclusion *ids* are not — they are `FirstShiftDirector.FILING_OUTCOMES`,
already in production before this work.

## Ownership audit, done before anything was written

| Owner | What it already holds | What SR7-H does about it |
| --- | --- | --- |
| `WorkOrders` | Sole authority for job lifecycle; `issued → acknowledged → diagnosed → awaiting_part → repairable → repaired → closed`, persisted in `RealityState.data.maintenance_jobs`. | Unchanged. The register still makes exactly one mutating call, `acknowledge_job`, from `issued` — SR7-G's. **Filing closes no job and skips no stage.** |
| `RealityCases` | Sole authority for case lifecycle. | Untouched. The prop contains no reference to it at all, asserted by reading its own source. |
| `FirstShiftDirector` | `FILING_OUTCOMES` = the four ids; `file_outcome()` gated on `PHASE_RETURNED`; **`accept_signed_register(record)`**, which reads `record.filing` and requires `job_id` to match, `report_out` false and `keys_out` empty. Bound to `report_taken` and, as of `199960a`, to `register_signed` — both in `building_root.gd`. | **This work connects nothing.** The director subscribes; the register publishes a receipt and does not know it is read. The record uses the key the consumer actually reads, `filing`, and `report_taken` is preserved exactly as Codex added it. |
| `night_register.lines` | SR7-G's record: `at`, `report_out`, `keys_out`, `job_id`, `job_stage`. | Gains **`filing`** and `filing_printed`. Still a neutral pure-fact line; still the register's whole footprint in the save. |

### The key is `filing`, and that was not a free choice

`FirstShiftDirector.accept_signed_register` landed in `199960a`, mid-assignment,
and it reads `str(record.get("filing", ""))` — its own comment says *"SR7-H
supplies `filing`"*. A record keyed `outcome` would have been dropped silently
by that guard, so the receipt uses `filing`.

The rest of that guard is the more interesting find. It also requires
`report_out` to be false and `keys_out` to be empty before it will act — which
are, exactly, two of the three conditions this board independently refuses to
sign without. The director's precondition and the apparatus's refusals were
designed apart and agree. The focused test asserts the published receipt
satisfies all four clauses of the guard **without wiring the two owners
together**.

## Interaction and refusal rules

Five literal service points, touched in any order: the spindle, two hooks, the
index, the book.

**Route order remains free**, and mechanically so — the report and the two keys
have no gate between them. The only ordering SR7-H adds is on the *signature*,
which the assignment requires and which says nothing about where you went:

Signing refuses unless **all four** are true:

| Refusal | What moves in the frame |
| --- | --- |
| no round was ever opened (also makes a second signature idempotent) | the desk kicks off its slope |
| the report is still in your hand | the spindle leans, the stub rides up the spike |
| a key is still off the board | that hook's brass check lifts and cants |
| **the index is standing on the blank** | the index rocks out of its groove |

Plus SR7-G's three: a key already out, a key already on its hook, and a spindle
with nothing on it. **Every refusal is a held, deterministic pose, and the pose
is targeted** — the thing that refuses is the thing that moves, so two refusals
in one board condition are two different photographs.

## Definitive frames

All frames 1280×720. SHA-256 truncated to 32 hexadecimal characters. Frames
`02`–`07` and `17` are the card camera; the rest are the board and station
cameras.

| Frame | SHA-256 | Claim |
| --- | --- | --- |
| `00_station_control_a.png` | `40fa8622ba0d4362a5e84a86eaa4d18f` | **As found.** Keys on hooks, spike bare, index on the printed blank. |
| `00_station_control_b.png` | `40fa8622ba0d4362a5e84a86eaa4d18f` | Same state, same camera — **byte-identical**. |
| `01_station_context.png` | `d6acf0ec55294401bda6b08d117e3403` | The station: detector and register on one wall. |
| `02_card_control_a.png` | `201141c9a771667cab16764b144eb6da` | The card, close. All four conclusions legible; index on `-- NOTHING ENTERED`. |
| `02_card_control_b.png` | `201141c9a771667cab16764b144eb6da` | **Byte-identical** — the card camera's own A/A floor. |
| `03_card_fault_corrected.png` | `5780a2d254576ed4e9391c90aff5828b` | Index on **1  FAULT CORRECTED**. |
| `04_card_disturbance_persists.png` | `e84d71e26f8e75607652ed040a55e969` | Index on **2  FAULT CORRECTED, DISTURBANCE PERSISTS**. |
| `05_card_no_fault_found.png` | `4a9476f1b55a770ebb28587c3b1353e4` | Index on **3  NO FAULT FOUND**. |
| `06_card_access_unsuccessful.png` | `61650f00316488af2212740ff2441319` | Index on **4  ACCESS UNSUCCESSFUL**. |
| `07_card_returned_to_blank.png` | `201141c9a771667cab16764b144eb6da` | Back to the blank — identical to the control, correctly. |
| `08_report_on_the_spindle.png` | `020c8f0a8a0dbb2b54a38d5ff6966f65` | The spine issued the job; nobody touched the board. |
| `09_round_open.png` | `d2cf0fefeeab044a90ee83e800c92eb0` | Report in hand, plant key out, check 7 on its hook. |
| `10_refused_key_already_out.png` | `986dce287e82b868320b6420dc280e94` | **Refusal — the hook.** |
| `11_refused_signing_with_keys_out.png` | `8881e90a0312c4ad5dd3a493bf46230a` | **Refusal — a key is still out.** |
| `12_refused_signing_report_in_hand.png` | `71a5a4184c1e106dcc3efca3904ac0d6` | **Refusal — the report is still in your hand.** |
| `13_refused_signing_on_the_blank.png` | `61c65a239f95126b14f5bbaf2e0fd87f` | **Refusal — the index is on the blank.** Nothing will choose for you. |
| `14_conclusion_chosen.png` | `48d19c7dfdb3a67dcb4203d4106fb20f` | Conclusion 2 chosen by hand. |
| `15_signed.png` | `69e9a6a0228a544a1f1f3469a4ce6d06` | Signed: one line in ink, shorter than its rule. |
| `16_refused_signing_again.png` | `05ed8cbad493a1daeaffdd78554c9774` | **Refusal — idempotent.** The round closed; no second line. |
| `17_card_after_signing.png` | `62fcbfa2ceb1af84b2663bfdf840cab8` | The card still showing what was signed. |
| `18_station_after.png` | `6463723172d0c5b95f730bbcc20fea14` | The station afterwards. |
| `19_restored_after_abort.png` | `9873fc27fd6713566f4f072200879784` | **Abort — 0.000000 against `08` on the apparatus crop**, the state the session began in. |

**Nineteen unique images across twenty-two frames.** All three collisions are
deliberate state identities: the two A/A pairs and `07 = 02` (returned to
blank). None is a missing capture.

**The abort frame is the one honest asterisk on this sheet.** On the first
sheet, taken against `0475785`, `19` was byte-identical to `08`. On the sheet
that shipped it is not: whole-frame RMSE **0.0000071**. That is 500× below the
smallest real change on the sheet and **exactly 0.000000 over the apparatus
crop `600x420+160+60` and over the far wall** — a handful of pixels elsewhere
in the corridor moving by one 8-bit step. The reversibility claim is therefore
made on the declared subject, where it measures zero, rather than on a
whole-frame hash that a neighbouring commit can perturb.

## Pricing

Normalized RMSE, ImageMagick. **Every A/A floor is exactly 0.000000**,
confirmed by matching SHA-256 — on the board camera, the card camera, and each
declared crop.

### The card camera, where the whole frame is the subject

| Pair | RMSE |
| --- | ---: |
| card control A → B | **0.000000** |
| blank → 1 fault corrected | 0.012083 |
| 1 → 2 disturbance persists | 0.013053 |
| 2 → 3 no fault found | 0.013981 |
| 3 → 4 access unsuccessful | 0.014793 |
| 4 → returned to blank | 0.013590 |

### The board camera

| Pair | RMSE |
| --- | ---: |
| station control A → B | **0.000000** |
| session start → **restored after abort** | **0.0000071** |
| report on spindle → round open | 0.032642 |
| round open → **refusal, the hook** | 0.009692 |
| → **refusal, keys out** | 0.014136 |
| → **refusal, report in hand** | 0.003819 |
| → **refusal, on the blank** | 0.032468 |
| refusal → conclusion chosen | 0.004860 |
| conclusion chosen → signed | 0.003683 |
| signed → **refusal, signing again** | 0.032206 |
| corridor before → after | 0.008912 |

### Declared crops on the board camera

Whole-frame RMSE understates a 26 mm brass index and a 2 mm ink line, so the
three claims that live in small objects are priced on their own crops, each
against its own zero floor:

| Subject (crop) | Change | RMSE |
| --- | --- | ---: |
| index `130x175+172+362` | A/A floor | **0.000000** |
| index | blank → conclusion 2 chosen | **0.030813** |
| index | **refusal pose** | 0.028451 |
| apparatus `600x420+160+60` | A/A floor | **0.000000** |
| apparatus | session start → **restored after abort** | **0.000000** |
| card `400x175+168+362` | A/A floor | **0.000000** |
| card | blank → conclusion 2 chosen | 0.017606 |
| book `320x140+575+362` | A/A floor | **0.000000** |
| book | unsigned → signed line | 0.016699 |
| book | **refusal pose (idempotent)** | **0.133707** |

## Two sheets were thrown away

1. **The whole run hit the 60-second ceiling at frame five.** The production
   root takes most of the budget to build and twenty-two frames do not fit
   after it. Split into `SHOT_PART=a`/`b` over one directory rather than
   trimming the sheet, because "every refusal" is the requirement.
2. **The longest conclusion ran off its own rail.** Set at 0.017 em,
   `DISTURBANCE PERSISTS` was clipped by the card's right-hand brass rail —
   which would have made the one ambiguous outcome the only unreadable line on
   the card. Reset at 0.0138 em; the index tongue was also shortened, because
   it was landing *on* the numeral it was selecting.

A third adjustment was necessary rather than cosmetic: the shot harness's
overlay sweep hides every `Label3D` in the tree, and the card's engraving *is*
`Label3D` — the established Orison prop lettering idiom, the same one
`lobby_bulletin_board.gd` uses for its brass plate. The sweep now exempts the
register, or SR7-H photographs as a blank card.

## Executable proof

Every run went through `tools/run_godot_serial.ps1`, one instance, 60-second
ceiling, full engine output redirected to a log and only filtered results read.
**Zero script errors and zero parse errors on every run below; no timeouts.**

- `NightRegisterTest.tscn`: **PASS 118/118** (was 80/80 at SR7-G).
  - *All four require an intentional selection:* each is reached by exactly
    `i + 1` deliberate pushes of the index from the blank.
  - *No default:* a fresh board reads `index_detent == 0`, `selected_outcome()
    == ""`, and `card_line() == CARD_BLANK`.
  - *No job-derived outcome:* the spine is driven `issued → acknowledged →
    diagnosed → repairable → repaired` under its own power and **the index has
    not moved**.
  - *Repaired work either way:* the same `repaired` job is filed once as
    `disturbance_persists` and once as `fault_corrected`, and the spine stays
    `repaired` both times.
  - *No free text:* six invalid conclusions — including `"the walls were
    breathing"`, a case-variant and a trailing-space variant — are all
    unreachable, leaving the index on the blank. Pushing the index eleven times
    visits **exactly five** distinct stops.
  - *Exactly one neutral record per signature*, carrying `outcome` and
    `outcome_printed` and **nothing** that would verify the claim.
  - *Idempotent:* a second press files nothing and adds no line.
  - *Abort:* restores the index, the report, the keys, the round **and the
    written lines**, byte-for-byte across the whole snapshot.
- `NightRegisterLiveTest.tscn`: **PASS 54/54** (was 41/41). On the real
  Orison: the board's four ids `== FirstShiftDirector.FILING_OUTCOMES`; the
  production index is on the blank as found; the **production** job is driven to
  `repaired` and the index still has not moved; all three signing refusals fire
  on the real apparatus and leave the save untouched; a `repaired` job is filed
  as `disturbance_persists` unchallenged; **no work order was closed or
  skipped**; still exactly one job record. Carried forward from SR7-G: 231
  lamps, 215 switch plates, 119 vantry points, 550 acoustic nodes, schedules,
  **no case signal, the case table byte-for-byte identical, the Dream block
  byte-for-byte identical**, and 5/5 plant doors locked against 0/1 apartment
  with no lock moved.
- **`FirstShiftRitualTest`: PASS (0 failures)** — Codex's suite over the owner
  this register will eventually be joined to, unaffected.
- `MaintenanceWatchmanTest` 60/60, `MaintenanceFuseLiveTest` 27/27,
  `MaintenanceChuteLiveTest` 25/25, `CoreLoopTest`, `MaintenanceActivityTest`,
  `MaintenanceActivityLiveTest`, `MaintenanceServiceRoundTest`: all **PASS**.
  `CoreLoopTest` matters most — it drives `WorkOrders` through the whole
  reported and discovered lifecycle.
- `InteractionInventory`: functional 276/32; non-functional 744, up one for the
  index's own reach.
- `WalkTest` (FAST): **239 pass, 2 fail** — `the chirp hunt` and `boiler's long
  parts list stays merged`. Both **pre-existing**, reproduced identically on a
  clean detached worktree at `1ebdf15`.

## REPORTED, NOT REPAIRED — one seam

`MaintenanceWatchmanLiveTest` returns **45/46** on this branch, failing `the
detector is a ray-reachable service point`. **It returns the identical 45/46 on
a clean `1ebdf15`**, so it is not this work.

Cause: `0475785` made `WatchmanClockProp.control_prompt()` phase-dependent. At
boot the ritual phase is `PHASE_ARRIVED`, so the detector's prompt is now
`"[E]  Clock in — seat tonight's paper"`, and SR7-F's assertion that the prompt
contains `"dial"` no longer holds. The reach itself is intact — only the
wording moved.

The one-line fix is in `game/tests/maintenance_watchman_live_test.gd`, which is
outside the paths this assignment permits, and `watchman_clock_prop.gd` is
reserved. Left for its owner: the assertion should accept either the dial
wording or a `FirstShiftDirector` phase prompt.

## Limitations

- **Not connected to `FirstShiftDirector`.** `register_signed` carries the
  outcome and matches the director's vocabulary exactly, but nothing subscribes
  to it. Joining `file_outcome` to it is the director's seam.
- **The register verifies nothing, and nothing reads it back.** No resident,
  case or job consults `night_register.lines`. That is deliberate for the
  claim/verification split, but it does mean a filed conclusion currently has
  no downstream consequence.
- **One report, one job.** The card is general; the board is tagged for
  `lena_radiator_round_2b`.
- **The index wraps rather than reversing.** There is no push-back-up, so
  correcting an overshoot costs a lap through the blank. A real slide would go
  both ways; a single interact key does not.
- `outcome_printed` duplicates the card wording into the record. It is
  convenience for a reader of the save, and it is derived — the id is the fact.
