# SR7-J — the key that proves the walk

**Status: production-rendered proof complete.**

Base `90f116d` — `origin/main` moved to it mid-work, landing the SR7-I
register checkpoint; the branch was replayed onto it and every proof, this
sheet included, re-run there. Captured 2026-08-25 in Forward+ (NVIDIA RTX 4080, Vulkan
1.4.341) through the real `res://scenes/building/orison_root.tscn`, on the F02
corridor's west wall between the lift and 2A's entry. Shot through the player's
own camera and lit by the corridor's own ceiling fixtures. No proof-only light,
mesh, material, camera rig or production owner.

Harness: `res://tests/WatchStationShot.tscn` through the serialized runner with
`-Windowed`.

## The audit came first, and it changed the apparatus

> *Do not silently pretend a fixed key stamps a distant wall clock.*

It cannot, and the audit says so out loud.

SR7-F's detector in the lobby is a **Newman/Moosmann paper-dial watchman's
clock**. In that system the station key is turned **in the clock**: the mark is
the key's own barrel biting the paper, at a radius its barrel length sets. A key
screwed to a wall on the second floor cannot make a mark in an instrument
standing in the lobby. Building one that did would be the same lie SR7-F exists
to expose.

**So this is not that system.** The period mechanism that *can* mark at a
distance is the other one entirely — the **electric watchman's signal box**,
fixed at the station and wired back to a central register. Its architecture is
the inverse of the detector's: the boxes stay on the wall, the watchman carries
a tour key, and the time record is made at the far end of a wire.

The two coexist in the Orison as what they are: two different systems, from two
different families, with the box's wire going somewhere the building does not
yet model.

## Sources

- **G. A. Jackson, assigned to Gamewell Fire Alarm Telegraph Co.,
  US 1,479,608, "Attachment for Signal Boxes", filed 27 December 1922, granted
  1 January 1924** — four years before the Orison's 1928. Its hinged frame *"is
  normally retained in closed position by engagement of the latch spring"*, and
  is hung so that a section left partly closed swings open under its own
  weight, *"directing attention to the fact that the structure has not been
  properly restored"*. **A door that refuses to sit half-shut is this
  apparatus's entire visual grammar.**
  <https://patents.google.com/patent/US1479608A/en>
- **H. Machinist, US 2,220,937, "Tour Key for Watchmen's Signal Systems", filed
  18 February 1939.** Later than the game, and cited **only** for its account
  of practice already long established: *"the watchman is provided with an
  implement, sometimes called a tour key, which he carries on his rounds"*,
  *"designed to fit into a series of devices in the nature of signal boxes, and
  to be operated in each of them in a certain order"*, and *"one or more of the
  boxes in the system is connected electrically with a central station so that
  a time record is provided"*. Boxes fixed, key carried, record remote — the
  architecture in the patent record's own words.
  <https://patents.google.com/patent/US2220937A/en>

**Orison-specific inference, stated plainly:** this box, its number, its drop
and its lock-out pawl are authored. The corridor it hangs in, the door it
stands beside, the lift the walk arrives on and the hour it reads are not.

## The chosen mechanism

A cast-iron **watchman's signal box**, 0.24 × 0.32, standing 0.13 off the wall:

- a **hinged door**, shut or open and never between, with the latch spring
  Jackson names;
- the **number plate on the door's head** — `STATION 2` — so the box names
  itself to somebody walking past who never opens it;
- inside, painted pale (as signal boxes were, so the works could be read by a
  man with a hand lamp): an **empty tour-key socket**, a **crank**, a **coded
  wheel whose teeth are this station's number**, a **lock-out pawl**, and a
  **numbered vermilion drop**;
- a **conduit** leaving the head of the case into the wall.

Working it: open the door, turn the crank. The wheel runs off the number, the
drop falls, and the latch spring takes the door home.

## What it teaches

| Claim | How the iron makes it true |
| --- | --- |
| A mark proves a station mechanism was operated at a place and time | The record carries `station_id`, `station_number` and `at_minute`, the last read from the same day/night owner the sky and the detector use — measured live to the minute. |
| It does not prove **who** | The key socket is **empty** and the crank is bare: anything with a hand works it. `RECORD_FIELDS` is a closed list and the test asserts the record has no `who`, `watchman`, `player`, `resident` or `resident_id` — the iron has no way of knowing one. |
| It does not advance, diagnose, repair or resolve | The source contains no `WorkOrders`, `RealityCases`, `issue_job`, `acknowledge_job`, `close_job`, `record_job` or `diagnose_job` — asserted by reading the file. |
| Missing it does not fail or block | Nothing declares itself `required`; the box has no route, gate or objective; and the live proof ends with the mark aborted away, 2A's door unlocked and the opening report exactly as unissued as it started. |

**And the one this building adds:** the wire goes into the wall and *what it
reaches is not modelled*. There is no central register in the Orison. The box's
own drop is the only evidence in the building that anybody came this way — a
stronger version of the same lesson, labelled rather than papered over.

## Where it hangs, and why there

Building coordinates `(-5.33, -3.10, 4.62)`, facing east into the corridor.
F02's floor is at z 3.2, so the case sits **1.42 m above the boards** and its
legend lands in a standing eye line.

The route is read from production, not asserted: the lift lands at
`LiftSheave` b(4.86, −4.73) on the ring's south-east; 2A's entry is
`F02_DOOR_02` on the ring's **west** wall at b(−5.33, −2.11); and the Vantry
point the opening report sends you to is inside that flat at b(−9.20, −3.04).
The walk therefore crosses the south leg and turns **north up the west wall** —
and the box is the last thing on that wall before the door, **0.51 m of clear
plaster** from its opening.

It projects **0.152 m** into a corridor 10.66 m wide, and its only body is an
`Area3D` reach, which reports overlaps and stops nothing.

## The emitted record

```gdscript
signal station_marked(station_id: String, mark_record: Dictionary)

{
    "station_id":     "F02_STATION_2A_LANDING",
    "station_number": 2,
    "serves":         "2A",
    "at_minute":      <house clock, to the minute>,
    "sequence":       1,
}
```

One neutral fact. Nothing in this work subscribes to it — first-shift and
campaign integration is the director's seam. `WatchStationNetwork` collects
marks for a round in memory so a second station is a line in
`WatchStationProp.STATIONS` plus a placement, not a rewrite. It is deliberately
**not** a save owner, **not** a route, and **not** a lifecycle owner.

## Definitive frames

All frames 1280×720. SHA-256 truncated to 32 hexadecimal characters. Two
cameras: the box at 0.66 m, and the approach from the corridor's west leg where
the walk actually comes from.

| Frame | SHA-256 | Claim |
| --- | --- | --- |
| `00_station_control_a.png` | `cfac64560ede6d215bebb163fe82a28c` | **As found**: door shut, `STATION 2` on its head, drop unseen behind it. |
| `00_station_control_b.png` | `cfac64560ede6d215bebb163fe82a28c` | **Byte-identical** — the box camera's A/A floor. |
| `01_approach_control_a.png` | `597dacdacb640124e0ea10058e2c2b44` | **The approach.** Iron furniture at eye level on the way to 2A's door — findable, not a waypoint. |
| `01_approach_control_b.png` | `597dacdacb640124e0ea10058e2c2b44` | **Byte-identical** — the approach camera's A/A floor. |
| `02_box_open.png` | `b72953f9cf11c4e86aac3abc80cede68` | Open: the empty socket, the crank, and the drop **standing up**. |
| `03_marked_drop_fallen.png` | `9d3839dd744804931b51beddb7888186` | **Marked.** The wheel has run and the numbered drop lies flat. |
| `04_approach_marked.png` | `36235fff117732f1af2fc95cc46a11ff` | The same corridor with the box worked. |
| `05_reopened_after_mark.png` | `4b59d7996c2d59e5eba21328692134a5` | Reopened: the drop is down and the pawl is home. |
| `06_second_crank_refused.png` | `1c4ca37e32b7688bde71300deaf0a21d` | **Refusal — the lock-out.** The crank turns against its pawl; the wheel does not move. |
| `07_closed_after_marking.png` | `fe16b53f83f66f906103f5971919c50e` | Shut again, with the mark standing. |
| `08_closing_a_shut_box_refused.png` | `4408e4d5ecb6587a6ee45fc28316e08b` | **Refusal — the door.** The leaf shoves against its stop without leaving it. |
| `09_drop_reset.png` | `cfac64560ede6d215bebb163fe82a28c` | Reset: identical to the control, correctly — a reset box *is* an unworked box. |
| `10_restored_after_abort.png` | `cfac64560ede6d215bebb163fe82a28c` | **Abort — byte-identical to the control.** |
| `11_approach_after_abort.png` | `597dacdacb640124e0ea10058e2c2b44` | **And byte-identical from the corridor too.** |

**Nine unique images across fourteen frames.** All five collisions are
deliberate identities: two A/A pairs, the reset, and both abort frames.

## Pricing

Normalized RMSE, ImageMagick. **Every A/A floor, on both cameras and all three
declared crops, is exactly 0.000000**, confirmed by matching SHA-256.

| Pair | RMSE |
| --- | ---: |
| box control A → B | **0.000000** |
| approach control A → B | **0.000000** |
| control → **restored after abort** | **0.000000** |
| approach control → **approach after abort** | **0.000000** |
| control → box open | 0.060235 |
| box open → **marked** | 0.004499 |
| approach → approach marked | 0.009694 |
| reopened → **refusal, the lock-out** | 0.045565 |
| marked → closed after marking | 0.060244 |
| closed → **refusal, the door** | 0.024920 |
| reopened → drop reset | 0.061283 |

### Declared crops

The mark itself is a 6 cm tab in a corridor frame, so it is priced on its own
subject rather than on a number that flatters the door:

| Subject (crop) | Change | RMSE |
| --- | --- | ---: |
| drop `180x190+650+380` | A/A floor | **0.000000** |
| drop | **THE MARK: drop up → fallen** | **0.022250** |
| drop | reset: fallen → up | 0.043104 |
| works `260x480+600+90` | A/A floor | **0.000000** |
| works | the mark | 0.012225 |
| works | **refusal: crank on its pawl** | **0.057568** |
| whole box `420x680+430+40` | A/A floor | **0.000000** |
| whole box | shut → open | 0.095728 |
| whole box | **control → restored after abort** | **0.000000** |
| whole box | refusal: shut box shoved | 0.025795 |

On its own subject the mark is **5× louder** than whole-frame RMSE suggests,
and the abort is exactly nothing.

## Three sheets were thrown away

1. **The case photographed as a black hole.** Cast iron inside a dim corridor
   swallowed the whole mechanism. Fixed by lining the interior pale — which is
   what signal boxes actually were, and for exactly this reason.
2. **Opening the box hid its own name.** The number plate was on the case head,
   where the swung door covered it. It is on the **door** now, so the box names
   itself to somebody who never opens it.
3. **The approach frame was empty plaster.** The rig stood in the south leg and
   sighted straight through the atrium's corner. It now stands in the west leg
   where the walk actually comes from.

A fourth adjustment was measured rather than eyeballed: marked-versus-unmarked
came back as two nearly identical dark outlines, so the drop was enlarged,
turned vermilion and given its station number in enamel.

## Executable proof

Every run through `tools/run_godot_serial.ps1`, one instance, 60-second
ceiling, full engine output redirected and only filtered results read. **Zero
script errors, zero parse errors, no timeouts.**

- `WatchStationTest.tscn`: **PASS 74/74**.
  - One deliberate turn makes **one** record; the drop falls; the pawl rides
    home.
  - **Five** consecutive further turns are each refused, each acknowledged, and
    the count stays at one — and the refusal visibly moves the crank.
  - The record is **closed**: exactly `RECORD_FIELDS`, and asserted to contain
    no `who`, `watchman`, `player`, `resident`, `resident_id`, `job_id`,
    `case_id`, `objective`, `route` or `next`. The emitted copy cannot be
    mutated back into the apparatus.
  - Abort restores the door, the drop, the count and the iron itself.
  - The source can reach **no** `WorkOrders`, `RealityCases`, `RealityState`,
    `ObjectiveTracker`, `ScheduleDirector` or `AcousticGraphData`, and declares
    no `required`, `must_mark`, `blocks`, `gate` or `objective`.
  - A whole marked round writes **nothing** to the save.
  - One collision object, an `Area3D`, and no light.
- `WatchStationLiveTest.tscn`: **PASS 37/37**. In the real Orison: on the
  corridor's own wall face at 1.42 m above the boards, facing the corridor,
  passed **before** 2A's door with 0.51 m of wall between, between the lift and
  the Vantry point. Projects 0.152 m. Adds no acoustic node. The production
  network adopted exactly one station. Marking it leaves the maintenance jobs,
  the case table, the **whole save**, 231 lamps, the switch plates, 550
  acoustic nodes, the schedules and every F02 door byte-for-byte unchanged, and
  publishes no case signal. Its hour matches the house clock to the minute.
  Working it again cannot duplicate the mark. Abort restores the real box.
- **`FirstShiftRitualTest`: PASS**, **`CoreLoopTest`: PASS** — Codex's reserved
  suites, untouched. `NightRegisterLiveTest` **54/54** and
  `MaintenanceWatchmanLiveTest` **46/46**.
- `InteractionInventory`: functional 277/33, up one for the new station and its
  family.
- `WalkTest` (FAST): **239 pass, 2 fail** — `the chirp hunt` and `boiler's long
  parts list`. Both **pre-existing**, reproduced identically on a clean
  detached worktree at `4fea837`, the immediately preceding head.

## An honest boundary the tests draw

**Abort restores the apparatus. It does not un-say what was said.** Restoring
the box puts the iron back, but the network keeps the fact it was handed, and
the live test asserts exactly that. A prop that could reach into a consumer and
retract a published fact would be a worse instrument than one that cannot.

## Limitations

- **The wire goes nowhere.** No central register exists, so the remote half of
  the period system is absent by design and stated rather than faked.
- **The tour key is not modelled.** The socket is empty because this building
  never issued one, which makes the box weaker evidence than a real 1928
  station — and makes the "who" lesson literal.
- **One station.** The table is the architecture; a second is a line and a
  placement.
- **Marks do not persist.** They live for the session. A watchman's boxes were
  reset every morning and the register end kept the tape; inventing a save key
  for a tape this building does not have would be inventing the evidence.
- **Nothing consumes `station_marked` yet.** Integration is the director's.
