# SR7-K — the wire has to end somewhere

**Status: production-rendered proof complete.**

Base: **`9ea96d1`** "Teach the optional first watch station" — the SR7-J
integration checkpoint, which landed mid-work. SR7-J's files on it are
byte-identical to the copy this increment was developed against, so the branch
was replayed onto it and every proof and the whole sheet re-run there.

Captured 2026-08-25 in Forward+ (NVIDIA RTX 4080, Vulkan 1.4.341) through the
real `res://scenes/building/orison_root.tscn`, on the F01 lobby's east wall in
the watchman's lane. Shot through the player's own camera and lit by the
lobby's own fixtures. No proof-only light, mesh, material, camera rig or
production owner.

## What this closes

SR7-J refused to pretend a fixed station key stamps SR7-F's paper-dial clock,
and left one honest limitation on the record: *the conduit enters the wall and
reaches nothing modelled.* This is what it reaches.

## The truth this teaches

**An indication here proves the CIRCUIT operated.**

That is a different and weaker fact than the one the box makes. The box's drop
is mechanical and local — it falls because a hand turned a crank, and nothing
can argue with it. This board's drop falls because current arrived down a wire.
So:

- a drop **down** proves a signal came in at that number, in that order. It
  does not prove who turned the tour key, and it proves nothing whatever about
  what they did next;
- a drop **still parked** proves *nothing at all*. It might mean nobody worked
  the station. It might mean the line is open and the box is standing two
  floors up with its own drop down, perfectly truthful, telling nobody.

**That ambiguity is why the line is closed-circuit and why the pilot exists.**
A healthy watchman's line rests closed so a break is an abnormal condition the
board can *show*, rather than silence you cannot tell from silence.

Frames `07` and `08` are **byte-identical**: working the real box with the wire
cut changes the lobby board by exactly nothing. The pilot, reading `LINE OPEN`
in red, is the only thing in the building that distinguishes those two worlds.

## What it does not record: time

A drop annunciator indicates number and order. It has no clock and no tape. The
hour lives in two other instruments and neither is this one — the paper-dial
detector (SR7-F), which SR7-F spent its whole increment proving you cannot take
on trust, and the night register (SR7-G/H), which is a book a person writes in.

**Three instruments in one lane, three jobs, three mechanisms.** The temptation
to make one of them answer all three questions is exactly the console this is
not.

## Sources

- **R. M. Hopkins, assigned to American District Telegraph Co., US 1,394,832,
  "Watchman's Registry System", filed 10 October 1919, granted 25 October
  1921.** It registers *"the visits of watchmen to certain stations which they
  are supposed to visit regularly"*, the station transmitter *"sending in the
  corresponding signal"*. ADT is the right firm and 1921 the right decade for a
  building reopened in 1928.
  <https://patents.google.com/patent/US1394832A/en>
- **O. M. Leich, assigned to Cracraft Leich Electric Company, US 1,144,605,
  "Annunciator", filed 18 August 1913, granted 29 June 1915.** *"A drop shutter
  9 is provided which is controlled by the shutter arm 10 secured to the
  armature 11"*; it stays down until restored; and the signal *"responds
  directly in accordance with the signals transmitted"* — an annunciator that
  **counts the code** rather than merely buzzing. That count is why this board
  can name a station instead of just announcing one.
  <https://patents.google.com/patent/US1144605A/en>

Carried from SR7-J: Gamewell US 1,479,608 (Jackson, 1922→1924) and
US 2,220,937 (Machinist, 1939) for the tour-key architecture.

**Orison-specific inference, stated plainly:** this case, its four drop
positions, its counter, its pilot and its test key are authored. The lobby wall
it hangs on, the run it hangs in and the station at the far end of its line are
not.

## The mechanism

A small oak-and-glass **signal register**, 0.40 × 0.46, standing 0.11 off the
lobby wall:

- a **line pilot** — two enamel plates, one lit: `LINE CLOSED` green,
  `LINE OPEN` red — the first thing the eye lands on;
- a **line relay** whose armature sits pulled in on a closed line and stands
  off an open one;
- **four numbered drop positions** in guides. A drop is *hooded* when parked
  and *in its window* when fallen, so an unsignalled position is an **empty
  window** and a signalled one is a **numbered leaf**. The position numbers are
  engraved on the case and readable either way;
- a **gong**, struck once per signal;
- a **counter** that steps once per signal and **does not step back**;
- a **reset lever**, and a **test key** for the line;
- a **conduit entering from below** — the other end of SR7-J's run.

## The signal contract

```
station  ──station_marked(id, record)──▶  network  ──receive_signal(record)──▶  board
```

| Stage | Owner | What it means |
| --- | --- | --- |
| `station_marked` | `WatchStationProp` | A mechanism was worked, at a place, at a time. Mechanical, local, unarguable. |
| `marks()` / `delivered()` | `WatchStationNetwork` | Every fact handed over, and the subset the wire actually carried. On a closed line they agree; on an open one the gap is what the break cost. |
| `signal_displayed(number, sequence)` | `WatchRegisterProp` | The circuit operated. Number and order **only** — no time and no person, because neither came down the wire. |

`INDICATION_FIELDS` is a closed list and the focused test asserts the board
displays nothing about `at_minute`, `time`, `who`, `watchman` or `player`.

## Where it hangs

Building coordinates `(5.24, −3.55, 1.42)`, facing west into the lobby.
**Measured placement:** the east wall's clear run between the service
dumbwaiter's north edge (b y −4.48) and the night register's shelf (−2.63) is
1.85 m of empty plaster. A 0.40 case centred on −3.55 spans −3.75…−3.35, with
**0.73 m clear of the dumbwaiter and 0.72 m clear of the register**. It hangs
at the same 1.42 as the rest of the lane and projects 0.132 m.

Near the detector and the night register. Mechanically distinct from both.

## Definitive frames

All 1280×720. SHA-256 truncated to 32 hexadecimal characters. Two cameras: the
board at 0.69 m, and the lane.

| Frame | SHA-256 | Claim |
| --- | --- | --- |
| `00_board_control_a.png` | `0638a933370e7467ac25705c551419af` | **As found**: line closed, every window empty, counter at 000. |
| `00_board_control_b.png` | `0638a933370e7467ac25705c551419af` | **Byte-identical** — the board camera's A/A floor. |
| `01_lane_control_a.png` | `0f51a28a9f7d204262637800529a8b25` | The lane: three instruments on one wall. |
| `01_lane_control_b.png` | `a71d1bf30740031fcb5f54a9125b3f47` | The lane A/A pair (see the note below). |
| `02_signal_received.png` | `890356efb6fbd0c19606e7f0627effcc` | **A signal.** Worked two floors up; drop 2 is in its window, counter 001. |
| `03_lane_signal_received.png` | `8a062308b62cff86fc4a89932734cd8e` | The same from the lane. |
| `04_repeat_refused.png` | `a949493c8b836d860e4e2ccdaad1927f` | **Refusal.** The rank jumps in its guides; no second indication. |
| `05_shutters_restored.png` | `c63a1a4dac4a5db60fe33ba37430cd50` | Reset: drop parked again, **counter still 001**. |
| `06_reset_of_clear_board_refused.png` | `68aad634f8e3b23d5ea345a8884cdbb4` | **Refusal.** A clear board has nothing to restore; the lever throws and returns. |
| `07_line_open.png` | `04bb26ea1d6796ee658b8a2f99d1c70d` | **`LINE OPEN`**, red, and the relay armature standing off. |
| `08_open_line_nothing_arrives.png` | `04bb26ea1d6796ee658b8a2f99d1c70d` | **The box was worked. BYTE-IDENTICAL to `07`.** Nothing arrived. |
| `09_line_closed_no_backfill.png` | `68aad634f8e3b23d5ea345a8884cdbb4` | Line closed again — and the missed signal is *not* back-filled. |
| `10_restored_after_abort.png` | `0638a933370e7467ac25705c551419af` | **Abort — byte-identical to the control.** |
| `11_lane_after_abort.png` | `043b85d136787a11365c6720a20d2116` | The lane afterwards. |

**Ten unique images across fourteen frames.** Three of the four collisions are
the sheet's strongest claims — the A/A floor, the abort, and the open line —
and the fourth (`09` = `06`) is a true identity: a clear board on a closed line
is a clear board on a closed line, whether or not a signal was missed while the
wire was cut. That the missed signal leaves *no trace* is the point.

## Pricing

Normalized RMSE, ImageMagick.

| Pair | RMSE |
| --- | ---: |
| board control A → B | **0.000000** |
| control → **restored after abort** | **0.000000** |
| **line open → box worked on an open line** | **0.000000** |
| control → signal received | 0.019433 |
| signal → **repeat refused** | 0.014597 |
| signal → shutters restored | 0.019177 |
| restored → **reset of a clear board refused** | 0.001928 |
| restored → line open | 0.016218 |
| open line → line closed again | see `09` = `06` |
| lane control → lane signal received | 0.006827 |
| lane control A → B | 0.0000024 |

### Declared crops

| Subject (crop) | Change | RMSE |
| --- | --- | ---: |
| pilot `260x90+370+80` | A/A floor | **0.000000** |
| pilot | **CLOSED → OPEN** | **0.099790** |
| windows `560x140+380+300` | A/A floor | **0.000000** |
| windows | **the indication: empty → drop 2** | **0.065749** |
| windows | refusal: the rank jumps | 0.029235 |
| windows | **open line, box worked** | **0.000000** |
| windows | reset: drop parked again | 0.065749 |
| counter `220x110+390+470` | A/A floor | **0.000000** |
| counter | 000 → 001 | 0.019398 |
| counter | unchanged by reset | 0.000378 |

The two zeroes on the windows crop carry the increment: an indication is worth
0.066 on its own subject, and an open line is worth *exactly nothing*.

**One honest asterisk.** The board camera's A/A floor is exactly 0.000000; the
**lane** camera's is 0.0000082 — a few pixels of lobby drifting one 8-bit step
between two captures of the same state. It is 800× below the smallest real
change on the sheet, and every load-bearing claim is measured on the board
camera or a declared crop, where the floor is exactly zero.

## Two sheets were thrown away

1. **The drops swung out of the case.** Hinged on a pivot, the parked ones
   stood into the lobby like little shelves with their numbers facing the
   ceiling — unreadable, and wrong about the mechanism: a *gravity drop* falls
   straight down. They now slide flush in guides and never leave the plane of
   the board.
2. **The parked drops peeked over their rail** into the pilot row. The hood now
   covers the parked position completely — 0.078 of leaf behind 0.082 of oak —
   so an unsignalled position is not a leaf sitting high in a window, it is an
   empty window, and the read is binary.

## Executable proof

Every run through `tools/run_godot_serial.ps1`, one instance, 60-second
ceiling, output redirected and only filtered results read. **Zero script
errors, zero parse errors, no timeouts.**

- `WatchRegisterTest.tscn`: **PASS 87/87**.
  - One signal → **one** fact, **one** delivery, **one** indication; station
    and board agree on number *and* sequence.
  - A repeated crank makes no second anything — and the board refuses a second
    signal at a fallen drop directly, so the guarantee does not rest only on
    the station's pawl. A number the board has no drop for is refused, not
    invented.
  - **Open line:** the crank still turns, the box's drop still falls, the fact
    is still made and published — and `delivered_count() == 0`,
    `undelivered_count() == 1`, the board shows nothing. Closing the line again
    does **not** back-fill.
  - **Loss of the receiver:** a line with no board is a legal building; the box
    works and publishes; one board per line, a second refused.
  - **Reset** restores the drops; the **counter does not go back**; a clear
    board refuses and its lever returns to rest.
  - **Abort** restores drops, counter and line — and **cannot retract** the
    facts the network already holds.
  - Neither the register, the network nor the station can reach `WorkOrders`,
    `RealityCases`, `RealityState`, `ObjectiveTracker`, `ScheduleDirector`,
    `AcousticGraphData`, `FirstShiftDirector`, `CoreLoopDirector`,
    `activate_case`, `issue_job`, `acknowledge_job` or `dream`. A whole
    signalled round writes **nothing** to the save.
- `WatchRegisterLiveTest.tscn`: **PASS 39/39**. In the real Orison: measured in
  the lane with over half a metre of plaster each side; a **third** instrument,
  not a merge; the real F02 box lights the real lobby board once, agreeing on
  number and sequence; cutting the **real** line leaves the box truthful and
  the lobby ignorant; jobs, cases, the whole save, 231 lamps, the switch
  plates, 550 acoustic nodes and the schedules all byte-for-byte unchanged; two
  Area reaches and no light; projects 0.132 m.
- `WatchStationTest` **74/74** and `WatchStationLiveTest` **37/37** — SR7-J
  still green with its network extended underneath it.

### An invariant that had to be restated, honestly

Both live tests previously asserted *"the WHOLE SAVE is byte-for-byte what it
was"*. That held until the SR7-J checkpoint, which wired
`FirstShiftDirector.observe_station_mark` to `station_marked` — so a mark now
moves `RealityState.data.first_shift`.

Nothing on this line changed. The station, the network and the receiver still
contain no `RealityState` at all, asserted from their own source in the focused
proof. What changed is that production finally has a **consumer**, and a
consumer acting on a published fact is the integration working.

Both live tests now name the keys that moved rather than demanding stillness:
**the only save key that moves is `first_shift`**, and that is the director's,
not the apparatus's.
- **`FirstShiftRitualTest`, `FirstShiftOpeningLiveTest`, `CoreLoopTest`:
  PASS** — Codex's reserved suites. `NightRegisterLiveTest` **64/64**.
- `InteractionInventory`: functional 278/34, up one for the receiver.
- `WalkTest` (FAST): **239 pass, 2 fail** — `the chirp hunt` and `boiler's long
  parts list`. Both **pre-existing**, reproduced identically on a clean
  detached worktree at `cc08d37`, the head before the checkpoint.

## Limitations

- **No time, by design and by mechanism.** A drop annunciator has no clock. The
  fact carries `at_minute`; this instrument does not display it, and inventing
  a dial for it would be inventing evidence.
- **One station on a four-position board.** Positions 1, 3 and 4 are wired to
  nothing and say so by never falling.
- **No save owner anywhere on the line.** Drops, counter and marks are
  session-only. Real boards were reset every morning and the register end kept
  the tape; this building has no tape.
- **The line cannot break on its own.** Only the test key or a caller opens it,
  so an open circuit is currently something you cause rather than something
  that happens to you.
- **Nothing consumes `station_marked` yet** — onboarding integration is
  Codex's.
