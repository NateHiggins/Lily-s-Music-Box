# SR7-F — the watchman's time detector

**Status: production-rendered proof complete.**

Captured 2026-08-25 in Forward+ (NVIDIA RTX 4080, Vulkan 1.4.341) through the
real `res://scenes/building/orison_root.tscn`, in the F01 lobby corridor, on
the east wall between the 1D and 1C entry doors. Shot through the player's own
camera and lit by the corridor's own ceiling fixtures. No proof-only light,
mesh, material, camera rig or production owner.

Harness: `res://tests/MaintenanceWatchmanShot.tscn` through the serialized
Godot runner with `-Windowed`.

## The truth this teaches

**A watchman's clock can run, tick, take every mark you give it and prove
absolutely nothing.**

The paper dial turns once round in a day *on the clock's own spindle*. Where a
key's mark falls **around** the dial is when it was made; how far **out** from
the centre is which station made it. Both facts live in one puncture, and both
depend on the paper having moved while the night went by.

A dial that is merely dropped over the arbor — centre hole on, drive pin **not**
through its index hole — sits perfectly still while the movement runs behind it.
The hand sweeps. The keys emboss. The sheet fills up. And every mark of the
whole night lands at the same angle, so the record reads as one instant: six
stations visited simultaneously, which is the one thing a watchman certainly did
not do. The instrument looks healthy from every angle except the only one that
matters.

The sheet is built so that this reads without a caption. **Frame 00** shows six marks
strung along a single straight radial line. **Frame 11** shows two marks at the
same radius with daylight between them. One line versus two dots apart is the
whole thesis, and it is legible before you read a word.

Transferable verb: **`timing`**, reused rather than invented — the ruled six
were complete at SR7-C, and the roster test records the reuse. The roof tank's
ballcock is about when a float *stops* a flow; this dial is about whether a
record's hours are the hours it claims. Same principle, different machine.

## Sources

**Documented:**

- **A. Newman of Chicago, US 676,764, "Watchman's Clock", patented 18 June
  1901.** The paper dial "rotates once in twenty-four hours with the spindle",
  is graduated and numbered, and is embossed with the characters of whichever
  station key is turned in it. *With the spindle* is the load-bearing phrase:
  the dial is not a passenger, it is driven, and a dial that is not driven is a
  blank sheet with holes in it.
  <https://patents.google.com/patent/US676764A/en>
- **P. Moosmann of Brooklyn, US 1,351,056, "Watchman's Time-Detector", filed
  1 June 1916, granted 31 August 1920.** "each key has a barrel of predetermined
  length which differs from the barrels of the remaining keys, so that the
  indicating mark made by the use of each key may be identified by the position
  on the dial" — that is the radius axis, and it is why `STATION_RADII` has six
  entries. Its stop flange exists because, in the patent's own account, a
  watchman could otherwise copy a key and work the detector without visiting the
  station at all.
  <https://patents.google.com/patent/US1351056A/en>

**Note what the second patent admits, because it is the point.** The period knew
perfectly well that this instrument's entire value is defeatable. SR7-F is
therefore about *proving* a round rather than about reading one, and the last
step of the chain is the only one that produces evidence.

**Orison-specific inference, stated plainly:** that *this* detector's dial is
off its drive pin tonight, the six stations on last night's sheet, the reading
index, the stop lever's particular shape and the two proof marks are authored.
The instrument, its dial geometry and its two axes are not.

## What production already owned, and what it did not

An audit ran before a line was written. **The Orison has no watchman.** There is
no patrol, no guard, no security round, no key station and no night-round owner
anywhere in the game — only planning prose and a dead `route` key in
`resident_schedules.json` that `schedule_director.gd` never reads. So no second
owner was invented, because there was no first one to duplicate.

What the building *does* own, and what this apparatus therefore had to leave
alone:

- **`DayNightDirector`** — the house clock. The detector **reads** it and never
  sets it: `_house_minute()` walks up to the same owner the sky uses and calls
  `_minute_now()` read-only. Two clocks in one building is precisely the class
  of bug this apparatus is about, so it does not become one.
- **`ClockProp`** — the building's two clocks (`F01_LOBBY_CLOCK_01`,
  `F04_B_CLOCK_01`), a hard census of 2 that `walk_test` prices. This is a
  distinct class and joins neither that census nor the `wall_clock` marker
  count.
- **`WorkOrders`** — `clock_prop.gd:370` is the one prop in the game that closes
  a job. SR7 apparatus deliberately do not, and this one holds no `WorkOrders`
  reference at all.
- **`ScheduleDirector`**, **`SwitchSystem`**, **`VantryPointNetwork`**,
  **`AcousticGraphData`** — all untouched, and the live test prices each one
  before and after.

## Where it hangs, and why exactly there

Building coordinates `(5.24, -1.50, 1.44)`, facing west into the corridor.

**The height is set by the millwork, not by taste.** `build_orison.py` runs the
lobby dado to 1.32 with a 0.04 cap on top and a bullnose bead at 1.355, and that
cap stands about 0.035 proud of the plaster — further out than this case is
deep. **An earlier pass of this sheet was thrown away because of it**: hung at
1.20 the chair rail ran straight through the glass, across the middle of the
dial. A clock goes above the panelling, which is where they were hung anyway;
the dial then centres at 1.66, a standing man's eye.

**The station was measured, not chosen.** The east wall's service end is full,
and the live scene was queried for the extents rather than guessed at:

| Owner | y extent |
| --- | --- |
| `LobbyMailBank` | −8.56 … −7.20 |
| `LobbyPostTray` | −7.57 … −7.23 |
| `LobbyMailChute` | −6.92 … −6.58 |
| `LobbyPorterBoard` | −6.33 … −6.07 |
| `LobbyServiceDumbwaiter` | −5.32 … −4.48 |

The porter's board is where a house detector belongs by rights, but the widest
gap anywhere near it is the 0.75 m between the board and the dumbwaiter, and a
0.34 m case hung there stands 0.20 m off two neighbours. **A second discarded
pass proved it**: at y −4.12 the sheet came back with the case jammed against
the dumbwaiter and the shaft lights behind the partition burning a hole in the
right of every frame.

The wall's openings are at y −3.77…−2.86 and −0.13…0.78, so the run *between*
the two doors is 2.73 m of unbroken panelling with nothing on it. The case sits
in the middle of it, 1.19 m clear of one door and 1.20 m of the other.

## Definitive frames

All frames are 1280×720. SHA-256 truncated to 32 hexadecimal characters.

| Frame | SHA-256 | Claim |
| --- | --- | --- |
| `00_detector_control_a.png` | `42bdb5a3e5cae37290266c5f1d544fbd` | **As found.** Movement running, hand sweeping, sheet full — and every one of last night's six station marks on ONE straight line out from the centre. A whole night at one instant. |
| `00_detector_control_b.png` | `42bdb5a3e5cae37290266c5f1d544fbd` | Same state, same camera — **byte-identical**. |
| `01_lobby_context.png` | `5e00020fcd97d11be4eb0c499355e56d` | The case above the dado between the two entry doors, in the corridor's own light. |
| `02_last_nights_record.png` | `511c730ad3a7586476751b4106438068` | The reading index swept across the record. |
| `03_seat_against_running_refused.png` | `ee74f169773252862064182faff3424b` | **Refusal 1 — the paper against a turning spindle.** Sheet lifted and tipped, key swung out of its hasp, stop lever kicked. |
| `04_movement_stopped.png` | `7db67b784cd0c8549a48d475b8a48bfe` | Stop lever thrown, spindle standing. |
| `05_datum_without_dial_refused.png` | `9a0edba445e87aa3f677c5c292fa5d9f` | **Refusal 2 — a datum for a dial that is not on the spindle.** A loose dial has no datum, only a position it happens to be lying in. |
| `06_dial_seated_on_pin.png` | `f0004c7d88b033d092d45105de789f92` | The drive pin up through the index hole and standing proud of the paper. The whole repair, and it is 4 mm of brass. |
| `07_wrong_hour_refused.png` | `1203c6493b14b8a8b675dcb5c69dfa21` | **Refusal 3 — the wrong hour.** A datum a quarter-turn out gives a careful, legible, wholly false account of the night. |
| `08_datum_set_to_the_house.png` | `b70ca8b759710f30684c6b29a2417c7a` | The datum agreeing with the house clock. |
| `09_proof_against_stopped_refused.png` | `d71ce843bd24774196f5b42972166788` | **Refusal 4 — the fault itself, offered as a repair.** Both marks would land at the same angle. |
| `10_movement_running.png` | `7ab8d0a0fa4044791856876f981bf158` | Movement restarted; the paper is finally being carried. |
| `11_two_marks_apart.png` | `26a67e6df05f93fb9b8e0ca89a87d532` | **THE PROOF.** Two marks at one radius with daylight between them — beside last night's six on their single line. |
| `12_committed.png` | `426eda581ca2350406abd208cc0214b1` | The committed condition, through the guarded seam. |
| `13_lobby_after.png` | `77efc38d388a2168b202b0bc37cac095` | The corridor afterwards. |
| `14_restored_after_abort.png` | `6ed25a783a8f6418235fb574d332a8e4` | **Abort.** The same snapshot the panel's abort uses, restored over the whole round. |
| `zz_lamp_on_diagnostic.png` | `e8aacdb6ea7b455ed86341eb9db4e7c6` | Service lamp on — see below. |
| `zz_lamp_off_diagnostic.png` | `39a2ebde037d54b4e0511ebdefb55ceb` | Service lamp off, same camera. |

## A/A pricing

Normalized RMSE, ImageMagick. **The A/A pair is byte-identical: RMSE exactly
0.000000**, confirmed by matching SHA-256. With `Engine.time_scale` at zero and
the prop's `_process` stopped, nothing moves between two captures of the same
state. Every state claim on the close camera is priced against that one floor.

| Pair | RMSE |
| --- | ---: |
| control A → control B | **0.000000** |
| control → **restored after abort** | **0.0000131** |
| control → last night's record read | 0.005961 |
| record → **refusal 1**, seat against running | **0.039270** |
| refusal 1 → movement stopped | 0.039462 |
| stopped → **refusal 2**, datum with no dial | **0.037404** |
| refusal 2 → dial seated on its pin | 0.037305 |
| seated → **refusal 3**, wrong hour | **0.038952** |
| refusal 3 → datum set to the house | 0.038697 |
| datum → **refusal 4**, proof against a stopped movement | **0.038492** |
| refusal 4 → movement running | 0.038581 |
| running → **two marks apart** | 0.003795 |
| control → **two marks apart** | 0.011420 |
| control → committed | 0.009924 |
| corridor before → corridor after | 0.001136 |
| lamp off → lamp on | 0.134309 |

**The refusals are the loudest thing on the sheet, by an order of magnitude.**
Every refusal transition prices at 0.037–0.039 against state changes of
0.004–0.011. That is the intended reading: a refusal is not a quieter version of
a step, it is the apparatus visibly balking. Each is a deterministic pose —
sheet lifted and tipped, station key swung out of its hasp, stop lever kicked —
so it survives a frozen photograph, which is the lesson SR7-E paid for.

**The abort frame is not byte-identical, and 1.31 × 10⁻⁵ is the honest number.**
It is 290× smaller than the smallest real state change on the sheet and 3000×
smaller than a refusal; it is renderer temporal accumulation between two
captures ten seconds apart, not apparatus state. The state claim itself is
proved numerically instead of photographically: `MaintenanceWatchmanLiveTest`
works four steps and a refusal on the production prop, aborts, and asserts every
key of `maintenance_snapshot()` back to 1 × 10⁻⁶.

## Three passes were thrown away to get here

Recorded because each was a real defect, not a preference.

1. **The chair rail through the glass.** Hung at z 1.20 the lobby's dado cap ran
   across the middle of the case. Fixed by hanging the clock above the panelling
   where clocks go, and the reason is now a comment at the placement.
2. **The dial edge-on.** `rotation.y` on an X-tipped cylinder is not a spin
   about the cylinder's own axis, so setting the datum turned the paper
   perpendicular to the glass. Fixed by rebuilding the assembly on two real
   pivots — see below — which turned a rendering bug into the mechanism.
3. **The lamp welded half-lit to the camera.** `set_lamp_enabled` starts a
   gutter transient that `_process` has to finish. Freezing the player first
   stopped the lamp mid-fade and threw a blown highlight into the lower right of
   every plate. Fixed by taking both lamp diagnostics with the world still
   running and freezing only afterwards.

## What the second discarded pass bought: two pivots

The dial is not one node. `SpindlePivot` carries the spindle and the drive pin
and turns with the movement; `PaperPivot` carries the sheet — the twenty-four
graduations, the index hole, the six station marks and both proof marks. **They
are the same angle only when the pin is through the hole.** Off the pin the
arbor runs and the paper does not, and the two are visibly out of register.

That is not tidiness. A graduation that stayed put while the paper turned would
make the datum meaningless, and the datum is what the fourth step of the round
exists to set. Setting the datum *is* setting the spindle: you turn the movement
and the paper clamped to it comes round with the pin. The focused test asserts
both halves.

## The service lamp: a defect I reported in SR7-E is fixed

SR7-D and SR7-E found the player's torch projecting a Dream Klimt plate onto the
waking building — `_bake_cookie()` in `player_controller.gd` sampling
`_mask_view`'s render target before that SubViewport had drawn. The SR7-E sheet
was shot with the lamp off and the defect reported rather than worked around.

**`e1314f0` fixed it.** `zz_lamp_on_diagnostic.png` and
`zz_lamp_off_diagnostic.png` are the same camera on the same apparatus with the
lamp the only variable: the lamp throws a clean warm pool with a hard cone edge
and **no mural appears**. The 0.134 RMSE between them is entirely illumination.

The sheet is still shot with the lamp off, now for composition rather than for
the defect: the corridor's own ceiling fixtures light the dial perfectly well,
and the lamp's pool falls low and to the right of the case.

## Executable proof

Every run went through `tools/run_godot_serial.ps1`.

- `MaintenanceWatchmanTest.tscn`: **PASS 60/60**. The book validates, holds the
  25–40 s window across five verbs (36 s), and reuses `timing` rather than
  widening the ruled six. A running movement is asserted **not** to be the same
  question as a turning dial. Five refusals are asserted explicitly. Two marks
  at different angles are asserted to be what proves the paper moved, and one
  mark is asserted not to be. **No patch can call an unseated detector honest.**
  The two pivots are asserted as a structure: the pin rides on the spindle, the
  index hole and every mark ride on the paper, the hand and the reading index
  ride on the case, an unseated sheet lies still while the arbor runs, and a
  seated sheet is at its spindle's own angle.
- `MaintenanceWatchmanLiveTest.tscn`: **PASS 46/46**. In the real Orison the
  detector hangs on the east wall at b(5.24, −1.50, 1.44), the whole case inside
  the run between the two entry doors and 2.81 m clear of the packed service
  end, above the bullnose bead, facing the corridor. Its datum is derived from
  the **same** clock the sky uses. It is not one of the building's two clocks
  and holds no `WorkOrders` reference. A preview moves the whole apparatus and
  publishes nothing; an abort taken *while a refusal is live* restores every
  fact exactly and clears the balk.

  **The cross-system proof:** 231 lamps powered before and 231 after, no
  `room_toggled` published, 215 switches unchanged, 119 vantry points and the
  active point unchanged, the winding clock's work order still `active`, the
  resident schedules unchanged (18 residents, 18 dispatched), the acoustic graph
  unchanged at 550 nodes with no node added, `RealityState.data` byte-for-byte
  identical (which prices persistence and the Dream block together), no reality,
  residue or case signal published, and nothing written to the save file. The
  result patches four keys of the apparatus and nothing else; it closes no job
  and advances no case. The prop owns no light and exactly one collision body,
  its own reach.
- `MaintenanceActivityTest`, `MaintenanceActivityLiveTest`,
  `MaintenanceServiceRoundTest`, `MaintenanceChuteLiveTest`,
  `MaintenanceFuseTest` (56/56), `MaintenanceFuseLiveTest` (27/27),
  `InteractionInventory`: all **PASS**.
- `WalkTest` (FAST): 239 checks pass, 2 fail — `production spine loads the one
  authored job, the chirp hunt` and `boiler's long parts list stays merged
  (23 meshes)`. Both **pre-existing**: a clean detached worktree at `e1314f0`
  was built and imported, and returns **the identical 239 passes and the
  identical 2 failures**.

## Ownership

The prop owns its own detector and nothing else. It reads the house clock and
never sets it. It creates no patrol, no station network, no resident schedule
and no route. It closes no job, advances no case, mutates no Dream state and
adds no save owner. Only `apply_maintenance_result` may record the detector
honest — and it refuses unless the paper is on the pin, the movement is running
and the datum agrees with the house.

Placement is inside the existing `if floor_nodes.has("F01"):` branch of
`orison_detail_pass.gd`, the seam SR7-A through SR7-E used.
**`building_root.gd` is not touched**, no `PROP_SCRIPTS` kind is registered, and
the new `class_name` is preloaded by its production caller as
`WatchmanClockPropScript` so a clean checkout does not depend on Godot's
generated class cache.

**SR7-F is not on the Service Round.** `ServiceRoundDirector` is a fixed
three-owner route — `F02_B_RADIATOR_01`, `LobbyPorterBoard`, `B1_BOILER_01` —
and names no maintenance activity id. Nothing was added to it.

## Limitations

- **Nothing in the building consults `detector_honest`.** No resident walks a
  round, no case turns on the record, and the six stations are marks on paper
  rather than six reachable places. The apparatus teaches the fault; it does not
  yet feed anything.
- The detector is not on the acoustic/possession graph, by choice: adding a node
  would mean a generator re-bake and an edge nobody asked for.
- The station key is one key, not six. Moosmann's six barrel lengths are
  modelled as six radii on the sheet, which is where the difference is legible;
  six physical keys on a hasp would be six meshes teaching nothing extra.
- The house hour under `DAYNIGHT=0` is pinned to 03:00, so the sheet's datum is
  the canonical one. In an unpinned session the datum tracks the real clock, and
  the live test exercises it there (it ran against house minute 923).
