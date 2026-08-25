# SR7-G — the night register

**Status: production-rendered proof complete.**

Captured 2026-08-25 in Forward+ (NVIDIA RTX 4080, Vulkan 1.4.341) through the
real `res://scenes/building/orison_root.tscn`, in the F01 lobby corridor, on
the east wall immediately south of the watchman's detector. Shot through the
player's own camera and lit by the corridor's own ceiling fixtures. No
proof-only light, mesh, material, camera rig or production owner.

Harness: `res://tests/NightRegisterShot.tscn` through the serialized Godot
runner with `-Windowed`.

## The truth this teaches

**A key board tells you what is missing. It never tells you where it went.**

Two hooks, two keys, one ruled book. The board is scrupulously honest about
absence — an empty hook carrying a numbered brass check is a fact you can read
across the lobby — and completely silent about everything else. It cannot say
who took the key, whether they went where the report sent them, or whether they
came back by way of anywhere at all. The signed line looks like evidence and is
only a receipt.

**And the second truth, which the building itself supplied.** The two keys on
this board do not open the same kind of building, and nothing on the board says
so:

- the **plant** key is tagged for the five floor service closets,
  `F02_DOOR_04` through `F06_DOOR_04`. Those ship `"leaf": "locked"` in
  `building_layout.json` and **all five are locked right now, at boot**. That
  key opens something.
- the **apartment** key is tagged for `F02_DOOR_03`, 2B's own entry. That door
  is **not locked and never was**: `orison_detail_pass.gd` carries
  `START_LOCKED = false` by the ruling of 2026-08-03, and what actually opens a
  flat is the case, through `RealityCases.case_changed`.

The register lists them in one column as if they were the same permission. One
of them is a formality. The apparatus reports the difference — read-only, live,
from `DoorProp.leaf_state` — and the live test measures it: **5 of 5 locked
against 0 of 1.**

## Sources

**Documented:**

- **R. H. Thayer, assigned to Thayer Telkee Corp, US 1,749,399, "Key Tag",
  filed 6 April 1926, granted 4 March 1930.** The tag is *"adapted to be
  permanently but detachably secured to a key"*. **Note the dates.** In the
  Orison's 1928 this is a *pending application* — the board is contemporary
  with the invention of its own tags rather than a period reconstruction.
  Telkee's numbered-hook-and-numbered-tag key cabinet is the same product line,
  continuous to the present day.
  <https://patents.google.com/patent/US1749399A/en>
- **The spindle file.** Before vertical filing displaced them, paper slips were
  held on pigeonhole, spike and spindle files — the upright spike that takes a
  bill or a message through the middle. This is a documented office practice of
  the period rather than a patent, and it is labelled as such; it is what a
  porter's report actually sat on.
  <https://en.wikipedia.org/wiki/Spindle_(stationery)>

**Orison-specific inference, stated plainly:** this board, its two checks, the
numbers stamped on them (7 and 14) and the ruled book are authored. The doors
it is tagged for, their lock states, the 2B report and its whole lifecycle are
not — every one of those is production's, read at runtime.

## The audit, and what it changed

Nothing was written until four owners had been proved:

| Question | Answer the audit gave | Consequence |
| --- | --- | --- |
| Who owns work lifecycle? | `WorkOrders` — a full stage machine, `issued → acknowledged → diagnosed → awaiting_part → repairable → repaired → closed`, persisted in `RealityState.data.maintenance_jobs`. Its header says case modules "must not grow private work-order-like booleans around this". | The rack **presents**. It holds no ledger. |
| Does the 2B radiator job exist? | Yes: `lena_radiator_round_2b`, authored in `maintenance_jobs.json` with an `origins.reported` entry, `repair_target_id: F02_B_RADIATOR_01`. | No job was authored. The report is the existing one, made physical. |
| Who issues and acknowledges it? | `ServiceRoundDirector` — `answer_incoming_call()` calls `issue_job(JOB_ID, "reported")`, and `_on_resident_interaction` calls `acknowledge_job(JOB_ID)`. | The rack **never issues**. It makes the one call the round already makes, `acknowledge_job`, and only from `issued`. |
| Is there a key or access system? | **No key system at all.** Access is authored *in the layout*: `"leaf": "locked"` on seven doors, five of them the `subtype: "service"` floor closets. `orison_detail_pass._unlock_for_case` is the only runtime unlocker, and `START_LOCKED = false`. | The keys are **accountability, not access**. The board reads `leaf_state` and never writes it. |

## Where it hangs

Building coordinates `(5.24, -2.27, 1.42)`, facing west into the corridor.

The watchman station is now two objects, which is what it always was in a real
building: an instrument that records the round, and a board that accounts for
the keys. The run between the two entry doors is −2.86…−0.13; the detector
holds −1.68…−1.32, leaving 1.18 m south of it, and a 0.62 m case centred on
−2.27 sits in the middle — 0.29 m clear of the door opening and 0.29 m clear of
the detector. It is above the 1.355 bullnose bead for the same millwork reason
the detector is.

## Definitive frames

All frames are 1280×720. SHA-256 truncated to 32 hexadecimal characters.

| Frame | SHA-256 | Claim |
| --- | --- | --- |
| `00_station_control_a.png` | `fc0d6806c3058a2149cc77c6a21bfec6` | **As found.** Both keys on their hooks, the spike bare — at boot the building has reported nothing, and the board does not invent work. |
| `00_station_control_b.png` | `fc0d6806c3058a2149cc77c6a21bfec6` | Same state, same camera — **byte-identical**. |
| `01_station_context.png` | `aae7b317994f5d80f1a04cc0e382ca50` | The station: detector and register sharing one wall above the dado. |
| `02_report_arrives.png` | `82cccf7d93f059e404d6f2895368133b` | **Nobody touched the board.** The spine issued the job and a slip is on the spindle. |
| `03_report_taken.png` | `f91779bafb8c920851b8fe5cf8da91de` | Report in hand. The slip tore off the spike and left its stub. |
| `04_apartment_key_taken.png` | `1de90f4e77b33c05cb6c0fa295c948b3` | Apartment key gone; **check 14** hangs in its place. |
| `05_both_keys_taken.png` | `88b31df7b3123deadfea2d815aefab55` | Plant key gone too; **check 7**. A hook is never simply empty. |
| `06_second_plant_key_refused.png` | `25d8a20d42de2bb72071fe76ecd61602` | **Refusal — the hook.** That check kicks; the desk does not move. |
| `07_filing_with_keys_out_refused.png` | `4e29ab04969d59b7d3b6ddbd70d33254` | **Refusal — the spindle.** It leans over and the stub rides up the spike. You do not file the report holding the keys. |
| `08_keys_returned.png` | `f91779bafb8c920851b8fe5cf8da91de` | Both keys back. Identical to `03` — same condition, correctly. |
| `09_report_filed.png` | `82cccf7d93f059e404d6f2895368133b` | Report back on the spindle, stub gone. Identical to `02`. |
| `10_register_signed.png` | `94785d8f391474aa83198ccf56778443` | The one publication: a line written in ink, shorter than its rule. |
| `11_station_after.png` | `3237c7be627dbc2bc7b1d9b3279a7bc3` | The station afterwards. |
| `12_restored_after_abort.png` | `82cccf7d93f059e404d6f2895368133b` | **Abort — byte-identical to `02`, the state the session began in.** |

**Ten unique images across fourteen frames, and every collision is a deliberate
state identity**: the A/A pair, `08 = 03` (report out, keys in), and
`09 = 12 = 02` (report on the spindle, keys in). None is a missing capture.

## Pricing

Normalized RMSE, ImageMagick. **The A/A pair is byte-identical: exactly
0.000000**, confirmed by matching SHA-256.

| Pair | RMSE |
| --- | ---: |
| control A → control B | **0.000000** |
| session start → **restored after abort** | **0.000000** |
| control → report arrives | 0.032467 |
| report arrives → report taken | 0.031992 |
| report taken → apartment key taken | 0.003180 |
| apartment key → both keys taken | 0.003794 |
| both keys → **refusal, the hook** | **0.009512** |
| refusal (hook) → **refusal, the spindle** | **0.013291** |
| refusal (spindle) → keys returned | 0.010521 |
| keys returned → report filed | 0.031992 |
| report filed → register signed | 0.032424 |
| corridor before → corridor after | 0.001642 |

**Whole-frame RMSE understates a key**, and saying so is more useful than
picking a flattering number: a key swapped for a check is 4 cm of brass in a
1280×720 frame of corridor. Three subjects are therefore declared and priced on
their own crops, each against its own A/A floor of **exactly 0.000000**:

| Subject (crop) | Change | RMSE |
| --- | --- | ---: |
| hooks `280x180+650+80` | apartment key → check 14 | 0.013559 |
| hooks | plant key → check 7 | 0.014398 |
| hooks | **refusal** | **0.040588** |
| spike `220x300+330+120` | bare → report on it | 0.121259 |
| spike | report → torn stub | 0.119485 |
| spike | never issued vs. in hand | 0.020600 |
| spike | **refusal** | **0.034686** |
| desk `360x180+560+360` | unsigned → signed line | 0.013832 |

On its own subject the refusal is the loudest thing in every case — 3× a key
swap at the hooks, 1.7× the state change at the spindle. That is the intended
reading: a refusal is not a quieter version of a step.

## Four sheets were thrown away, and each was a real defect

1. **The register book photographed as a black wedge.** Book, page and every
   ruled line were tilted by the same euler about three *different* origins,
   which is not a plane. Fixed by putting the whole desk on one pivot — the
   same lesson SR7-F learned about the paper dial.
2. **The desk then tilted the wrong way.** `Rx(-t)` faces the page away from
   the room. The sign is now a comment at the site.
3. **The refusals photographed as nothing at all.** `_balk()` set the timer and
   left the pose to `_process` — and a proof sheet freezes `_process` to hold
   the world still. `_balk()` now applies the pose itself. This is the third
   time this family of bug has cost a sheet (SR7-E, SR7-F, SR7-G), so the
   focused test now asserts the pose moves *without a process tick*.
4. **Two different refusals came back byte-identical.** One shared pose cannot
   say which of four things refused. Refusals are now targeted — the thing that
   refuses is the thing that moves — and the test asserts that two refusals in
   one board condition are two different pictures.

A fifth adjustment was measured rather than eyeballed: the signed line scored
**0.00095** on its own declared subject, which is invisible. Thickened and made
shorter as well as darker, it now scores **0.013832** — 14.6× stronger, against
the same zero floor.

## Executable proof

Every run went through `tools/run_godot_serial.ps1`, one instance, 60-second
ceiling, full engine output redirected to a log and only filtered results read.
Zero script errors and zero parse errors on every run below; no timeouts.

- `NightRegisterTest.tscn`: **PASS 80/80**. Presentation, five refusals, route
  order, abort, access ownership, signing and what the board is not.
  - *No duplicate work order:* with no job issued, touching the spindle issues
    **nothing** and `maintenance_jobs` stays empty; once the spine issues,
    taking the slip acknowledges the **existing** record and the record count
    is unchanged; taking it repeatedly cannot re-acknowledge or double-advance.
  - *No second ledger, proved by absence:* the source carries no `issue_job`,
    no `close_job`, no `record_job`, no `RealityCases`, no `activate_case` and
    no `leaf_state =`. `acknowledge_job` is the **one** mutating spine call.
  - *Route order free:* all **six** orders of (report, apartment key, plant
    key) are walkable and reach **one identical condition**; either key alone
    and the report alone are each legal.
  - *Keys restore on abort:* a session that takes the report and both keys and
    is left holding a refusal restores every fact exactly, clears the pose, and
    wrote nothing. The **spine is deliberately not rolled back** — the
    acknowledgement was real work by its real owner.
  - *Access ownership:* taking and returning both keys changes **not one** of
    the six tagged doors' `leaf_state`.
  - *Signing:* one line per signature, never an overwrite, and the line records
    **nothing** about where the key went.
- `NightRegisterLiveTest.tscn`: **PASS 41/41**. In the real Orison the board
  hangs at b(5.24, −2.27, 1.42), clear of the 1D opening and of the detector,
  above the bead, facing the corridor. It reads the production `WorkOrders`;
  at boot the job is missing and the spindle is empty; touching it issues
  nothing into the real spine. All six tagged doors are real production doors,
  **5/5 plant locked and 0/1 apartment**, and with both keys off the board not
  one real lock has moved. Abort restores; signing writes exactly one line.
  **The cross-system proof:** 231 lamps powered before and after, no
  `room_toggled`, 215 switch plates, 119 vantry points, 550 acoustic nodes with
  none added, the schedules untouched, **no case signal published, the whole
  case table byte-for-byte identical, and the Dream block byte-for-byte
  identical**.
- `MaintenanceWatchmanTest` 60/60, `MaintenanceWatchmanLiveTest` 46/46,
  `MaintenanceFuseLiveTest` 27/27, `MaintenanceChuteLiveTest` 25/25,
  `MaintenanceActivityTest`, `MaintenanceActivityLiveTest`,
  `MaintenanceServiceRoundTest`, **`CoreLoopTest`** and `InteractionInventory`:
  all **PASS**. `CoreLoopTest` matters most here — it drives `WorkOrders`
  through the whole reported and discovered lifecycle, and it is untouched.
- `InteractionInventory`: functional 276/32, up from 275/31 — the one new
  functional prop and its one new family, which is this board.
- `WalkTest` (FAST): **239 checks pass, 2 fail** — `production spine loads the
  one authored job, the chirp hunt` and `boiler's long parts list stays merged
  (23 meshes)`. Both **pre-existing**: a clean detached worktree at `fd90ba0`
  was built and imported and returns **the identical 239 passes and the
  identical 2 failures**.

## Ownership

The board owns its own hooks, its own spindle and its own book. It presents
`WorkOrders` and never becomes one. It never issues a job, never touches
`RealityCases`, never writes a lock, and adds no quest manager, patrol NPC,
schedule route, waypoint chain or UI surface. Its whole footprint in the save is
`RealityState.data.night_register.lines`, written only by `sign_register()`.

Placement is inside the existing `if floor_nodes.has("F01"):` branch of
`orison_detail_pass.gd`, the seam SR7-A through SR7-F used.
**`building_root.gd` is not touched**, no `PROP_SCRIPTS` kind is registered, and
the new `class_name` is preloaded by its production caller as
`NightRegisterPropScript` so a clean checkout does not depend on Godot's
generated class cache.

## Limitations

- **The report is one report.** Only `lena_radiator_round_2b` is presented. A
  rack that enumerated every open job would be a better rack and a worse
  proof; the presentation path is generic but the board is tagged for one job.
- **The keys unlock nothing, deliberately.** They are accountability, not
  access, because production's access owner is the layout and the case system.
  If a future ruling turns `START_LOCKED` on, this board is already reading the
  right doors and would need a *deliberate* new owner to start writing them.
- **Nothing consults the signed lines.** No resident, case or job reads
  `night_register`. The register records; it does not yet feed anything.
- The board is not on the acoustic/possession graph, by choice.
- The stub says a report is out and nothing more. That is the thesis, not an
  oversight — but it does mean the board cannot tell you *whose* hand it is in.

## Seams reported, not taken

None were required. The three owners this work sits against — `WorkOrders`,
`ServiceRoundDirector` and the layout's `leaf` field — all expose enough public
surface to present without modification, and none of Codex's reserved
watchman-clock, case-activation or onboarding paths was opened.
