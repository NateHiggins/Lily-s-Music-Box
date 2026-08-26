# SR7-M — two boxes do not make a route

**Status: production-rendered proof complete.**

Base **`40cdf2c`**. SR7-L and Codex's tour-key integration had both landed
before this began, so no replay was needed; `origin/main` then moved four
commits during the work — three of them Codex's first-shift lane, including
"Keep the opening watch round optional" — and the branch was replayed onto the
new head with every proof and the whole sheet re-run there.

Captured 2026-08-25 in Forward+ (NVIDIA RTX 4080, Vulkan 1.4.341) through the
real `res://scenes/building/orison_root.tscn` — the boiler room in B1, and the
lobby board in F01. Shot through the player's own camera, lit by the rooms' own
fixtures. No proof-only light, mesh, material, camera rig or production owner.

## The thesis

**Two numbered indications prove two boxes were worked.** They do not prove who
carried the key, which path was walked, or that the building was inspected.

The measurable form: the board records **identity** (which number) and the wire
records **arrival** (which order), and those are different axes.

Frames `09` and `11` are **byte-identical**. One was taken after working the
boiler then the landing; the other after working the landing then the boiler.
The lobby board cannot tell those two nights apart — both windows filled, the
counter at 002 — and the live proof shows the network's own delivery log
*does* differ (`[1, 2]` against `[2, 1]`). **The board proves two boxes; only
the wire knows the order; and nothing anywhere knows the route.**

## Where the second station went, and why

### The audit

| Evidence | Finding |
| --- | --- |
| B1 floor plan | `B1_BOILER` `[5.51, −0.88, 13.65, 9.65]` is a real generated room with a real **coal bunker** `B1_COAL` `[11.3, 0.3, 13.65, 2.7]` off it through `B1_DOOR_07`. |
| Existing apparatus | `B1_BOILER_01` stands at b(9.05, 1.55), 2.05 m tall. SR7-E's fuse panel is far away in `B1_ELECTRICAL` at b(13.30, −6.80) — no duplication. |
| Wall occupancy | A full-tree scan of the boiler room's south neighbourhood returned **zero props**. |
| Lighting | The room has **exactly one** fixture, `B1_BOILER_LT_CAGE_BULB` at b(9.58, 4.38). |

### Why it matters to a 1928 watchman

A coal-fired plant is the reason the building employs a watchman at all.
Banked fires, hot ash, and a coal pile that can heat itself are the fire risks
an insurer wrote the round around; the boiler room is the first room on any
such round and the last one anybody would leave out.

**The station stands on the coal bunker's north wall at b(12.00, 2.70)**: the
boiler 3.0 m in front of it, the coal directly behind the wall it hangs on.
Both fire risks from one standing position.

### The contrast with Station 2

| | Station 1 | Station 2 |
| --- | --- | --- |
| where | B1 boiler room | F02 residential corridor |
| what kind | the plant — machinery, heat, brick, one bulb | papered wall, dado, ceiling domes |
| why you're there | fire | a resident's report |
| height apart | **6.00 m** — basement against second floor | |

### One placement was thrown away, and the sheet found it

The first choice was the boiler room's **south party wall at b(9.05, −0.88)**,
dead on the boiler's own axis. It is 5.3 m from the room's only bulb with the
boiler itself in the way, and it **photographed as a black rectangle**. A
station a watchman cannot read by the room's own light is a station he cannot
work. The bunker wall is 2.4 m from that bulb.

## Mechanism

Same family, same key, same wire, same board — `WatchStationProp` with one new
row in its authored table:

```gdscript
"B1_STATION_BOILER": { "number": 1, "serves": "boiler", "legend": "STATION 1" },
```

- **Distinct number and coded wheel.** The wheel's teeth *are* the number, cut
  in the metal: one tooth against the landing's two, asserted in the test.
- **Its own gravity drop**, in its own guides, showing its own `1`.
- **The same carried tour key** — one guard, one hook, one question.
- **The central register indicates its number only when the line delivers it.**
- **Per-station lockout**: a box's pawl stops its own second signal and does
  not reach the other box.
- **Either station may be worked first**, proved in both orders on the real
  building.

**Station 1 is in the basement and Station 2 is on the second floor, and the
numbers do not dictate the order.** That is deliberate: a watchman who works 2
before 1 leaves a perfectly good record of two boxes and a perfectly useless
record of a route.

## Refusals

| Refusal | What it looks like |
| --- | --- |
| no tour key, **either** station | the crank swings its whole travel and the empty socket is shoved forward |
| repeat crank at a box | that box's pawl stops the crank dead — a different pose |
| one box cannot satisfy the other | the other's drop simply stays parked |
| copied/apartment/plant keys | the line asks **one** guard **one** question; it contains no reference to `APARTMENT_HOOK`, `PLANT_HOOK` or `NightRegister` |
| open line | both local drops fall; the lobby receives neither, and closing the line back-fills nothing |

## Definitive frames

All 1280×720. SHA-256 truncated to 32 hexadecimal characters. Three cameras:
the boiler box close, the plant, and the lobby board.

| Frame | SHA-256 | Claim |
| --- | --- | --- |
| `00_boiler_control_a.png` | `e68ef57825cb0444ad25fa919705ff13` | **As found**: the boiler box shut, `STATION 1` on its door. |
| `00_boiler_control_b.png` | `e68ef57825cb0444ad25fa919705ff13` | **Byte-identical** — the box camera's A/A floor. |
| `01_plant_control_a.png` | `c6c2b6e65013ca73d1dc3d38f1d5ca61` | **The second place**: brick chimney breast, the bunker wall, the boiler at right. |
| `01_plant_control_b.png` | `c6c2b6e65013ca73d1dc3d38f1d5ca61` | **Byte-identical** — the plant camera's A/A floor. |
| `02_boiler_open_no_key.png` | `1eb8f8cb8b22cdcd5100b58bf6dcbc79` | Open, with the key on its hook three floors up: an empty socket. |
| `03_boiler_empty_socket_refused.png` | `b97c935f1af6ede46a88a4249f6924c0` | **Refusal — the socket**, at the second box as at the first. |
| `04_boiler_open_with_key.png` | `1384338c7e0bfe03e34f6b5c15c27097` | The same box with the tour key taken. |
| `05_boiler_marked.png` | `b17e49ba0a1677d8084bb87a541c5504` | **Marked.** Its own numbered drop, showing `1`. |
| `06_plant_marked.png` | `6e7bfb4dadbfbbd2e8cecea20b11d2de` | The plant with the box worked, lit by the room's one bulb. |
| `07_board_control_a.png` | `c81e85ef74406ceca93b5fc3dd99f445` | The lobby board: both windows empty, counter 000. |
| `07_board_control_b.png` | `c81e85ef74406ceca93b5fc3dd99f445` | **Byte-identical** — the board camera's A/A floor. |
| `08_board_station_1_only.png` | `bda90a31b51e235a270c884b5226a230` | **Station 1 alone.** One window fills; the other stays empty and says nothing. |
| `09_board_both_stations.png` | `5fa38dd7957d24d37daec8e8e9b28a0c` | Both windows, counter 002 — **boiler first**. |
| `10_board_station_2_first.png` | `6e04e198ac025367bd787675e0f6f41e` | **Station 2 alone**, from a clean line. |
| `11_board_both_other_order.png` | `5fa38dd7957d24d37daec8e8e9b28a0c` | Both windows, counter 002 — **landing first. BYTE-IDENTICAL to `09`.** |
| `12_board_open_line_neither.png` | `12bffb83026dff7e8f9f11cff56cac09` | **Open line**: both locals fell; the board has nothing but a red pilot. |

**Twelve unique images across sixteen frames.** Three of the four collisions
are A/A floors; the fourth, `11 = 09`, is the increment's whole argument.

## Pricing

Normalized RMSE, ImageMagick. **All three A/A floors are exactly 0.000000**,
confirmed by matching SHA-256.

| Pair | RMSE |
| --- | ---: |
| boiler control A → B | **0.000000** |
| plant control A → B | **0.000000** |
| board control A → B | **0.000000** |
| **both orders → same board** | **0.000000** |
| open no key → **empty-socket refusal** | 0.006799 |
| open with key → **marked** | 0.029125 |
| plant control → plant marked | 0.008350 |
| board control → station 1 only | 0.009797 |
| station 1 only → both stations | 0.009577 |
| board control → station 2 first | 0.009619 |
| board control → open line, neither | 0.005795 |

### Declared crops

| Subject (crop) | Change | RMSE |
| --- | --- | ---: |
| drop `220x260+620+400` | A/A floor | **0.000000** |
| drop | **STATION 1's drop falls** | **0.067274** |
| works `300x420+560+120` | A/A floor | **0.000000** |
| works | **empty-socket refusal** | **0.018373** |
| windows `560x140+380+300` | A/A floor | **0.000000** |
| windows | window 1 fills, window 2 stays empty | **0.033010** |
| windows | window 2 then fills | 0.032380 |
| windows | window 2 first, window 1 empty | 0.032386 |
| windows | **BOTH ORDERS: same board** | **0.000000** |
| windows | open line: both locals fell, board empty | 0.000039 |
| counter `220x110+390+470` | A/A floor | **0.000000** |
| counter | 001 → 002 | 0.009814 |

The two zeroes on the windows crop are the sheet. Filling a window scores
0.033 on its own subject; **the difference between the two orders scores
nothing at all**, and an open line leaves the board 0.000039 from a board
nobody signalled — a red pilot and no more.

## Executable proof

Every run through `tools/run_godot_serial.ps1`, one instance, 60-second
ceiling, output redirected and only filtered results read. **Zero script
errors, zero parse errors, no timeouts.**

- `WatchPairTest.tscn`: **PASS 118/118**.
  - Two authored stations, distinct numbers, **one tooth against two** in the
    metal, and the same script — one family, not a second.
  - **Both orders deliver the same two indications** `[1, 2]`, while arrival
    order differs. The indication has no `route`, `path`, `order_walked`,
    `tour`, `complete` or `who`; the network offers no `next_station`,
    `route`, `complete` or `required_stations`.
  - One station cannot satisfy the other; repeats on one do not reach the
    other.
  - **No key: neither station marks.** No substitute: the line knows nothing of
    the register's apartment or plant hooks and asks exactly one guard one
    question.
  - **Open line: both locals fall, neither is delivered**, and closing the line
    back-fills neither.
  - Abort restores a box and the board and **cannot retract** either published
    fact; the box nobody restored is untouched by it.
  - The key returns after two marks, after one, and after none.
  - No file on the line can reach `WorkOrders`, `RealityCases`, `RealityState`,
    `FirstShiftDirector`, `CoreLoopDirector`, `ObjectiveTracker`,
    `ScheduleDirector`, `AcousticGraphData`, `leaf_state` or `dream`, and none
    declares `required`, `must_visit`, `checklist`, `objective`, `completion`
    or `all_stations_marked`.
- `WatchPairLiveTest.tscn`: **PASS 42/42**. On the real Orison: the box hangs
  on the real bunker wall, 3.0 m from the real boiler and 2.4 m from the room's
  only bulb, 6.0 m below the landing station; both real boxes work off the one
  real key in **both orders** delivering the same two indications with
  different arrival; repeats duplicate nothing; an open real line drops both
  locals and delivers neither; **not one of 74 real door leaves moved**, the
  boiler and coal doors included; the key returns after one mark, two, or none;
  and the only save key that moves is `first_shift`, the director's.
- `WatchStationTest` 77/77, `WatchStationLiveTest` 38/38, `WatchRegisterTest`
  87/87, `WatchRegisterLiveTest` 40/40, `TourKeyTest` 65/65,
  `TourKeyLiveTest` 39/39 — the whole line still green.
- **`FirstShiftRitualTest`, `FirstShiftOpeningLiveTest`,
  `FirstShiftOpenLineLiveTest`, `FirstShiftCustodyTest`, `CoreLoopTest`:
  PASS** — Codex's reserved suites, including the custody suite that landed
  mid-work, with a second station in the building and **nothing added to
  onboarding**. Codex's own "Keep the opening watch round optional" still holds
  with two boxes on the line.
- `NightRegisterLiveTest` 64/64. `InteractionInventory`: functional 280/35, up
  one for the new box.
- `WalkTest` (FAST): **239 pass, 2 fail** — `the chirp hunt` and `boiler's long
  parts list`. Both **pre-existing**, reproduced identically on a clean
  detached worktree at `e06a68a`, the head this work began on.

**One back-fill was necessary:** `watch_station_live_test.gd` asserted the
production network had adopted *exactly one* station. It now asserts the line
carries the landing station and that every box on it is one the building
authored — which is the invariant that was always meant.

## Limitations

- **Two stations is not a round.** A real 1928 tour had six or eight boxes.
  Adding a third is a row in the table and a placement; nothing here scales
  badly, and nothing here pretends two is enough.
- **The register still records no time.** Number and arrival order only, as a
  drop annunciator does.
- **Nothing reads the pair.** The first-shift director observes marks
  individually; no consumer asks "were both worked", and adding one would be
  adding the checklist this increment exists to refuse.
- **Marks and custody remain transient.** A reload clears both boards and hangs
  the key back up.
- **The boiler room is dark**, honestly so. The station is placed where the
  room's one bulb reaches; most of the rest of that room is not readable
  without the player's own lamp, which is a fact about a 1928 basement rather
  than a defect.
