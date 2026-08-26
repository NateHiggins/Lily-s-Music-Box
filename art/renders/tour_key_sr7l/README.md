# SR7-L — the key is not the man

**Status: production-rendered proof complete.**

Base: **`4f1ac40`** "Trust the central watch signal" — the SR7-K integration
checkpoint, which landed mid-work. SR7-K's files on it are byte-identical to
the copy this increment was developed against, so the branch was replayed onto
it and every proof and the whole sheet re-run there. The SR7-L commit contains
only SR7-L.

Captured 2026-08-25 in Forward+ (NVIDIA RTX 4080, Vulkan 1.4.341) through the
real `res://scenes/building/orison_root.tscn` — the guard in the F01 lobby
lane, the box on the F02 corridor wall. Shot through the player's own camera,
lit by the rooms' own fixtures. No proof-only light, mesh, material, camera rig
or production owner.

## What this closes

SR7-J built a station box with an **empty tour-key socket** and said so on the
record: the building never issued a key, which made the box weaker evidence
than a real 1928 station and made its "who" lesson literal — *and let the crank
work anyway*, which was the one thing about it that was not period-true.

This is the key, the hook it lives on, and the socket finally mattering.

## The truth this teaches

**Possession proves the key is not on its hook.**

That is the whole of it. The check hanging in the key's place carries a
**number, not a name**. It says this hook is empty and somebody emptied it, and
it has no opinion whatever about who, or where they went, or whether they came
back by way of anywhere. It is the same silence SR7-G's key board keeps about
its two keys, kept about a third.

## And what the key is not

| | |
| --- | --- |
| **Not a permit.** | It opens **no** door — not an apartment, not a service closet, not the plant. The focused proof reads the guard's source and finds no `leaf_state`, `DoorProp`, `unlock`, `locked` or `START_LOCKED` in it; the live proof takes the key, uses it, and finds **not one of 74 real doors moved**, with `F02_DOOR_04` still locked and 2B's entry exactly as it was. |
| **Not a quest token.** | It gates one optional thing: the station's crank. A watchman without it can investigate, repair, file and clock out. Nothing about the guard or the box declares itself `required`, `gate` or `blocks_route`. |
| **Not inventory.** | `MaintenanceInventory` rules itself out in its own words — an item is *"granted at most once per campaign and consumed at most once — deterministic single use"*, `grant()` refuses a second, and it calls `RealityState.commit()`. A key taken and hung back every night is none of those three. Custody lives in the iron and is transient by design. |

## Sources

- **J. P. Venegas, US 1,626,987, "Key Lock", filed 24 November 1925, granted
  3 May 1927** — one year before the Orison's 1928. *"A suitable locking device
  or latch is adapted to hold the split ring"*, and the keys are retained
  *"preventing removal until the operator manipulates the locking mechanism"*.
  A key you can only take by working a latch is a key whose taking is an **act**
  — which is the whole reason this apparatus is a guard and not a nail.
  <https://patents.google.com/patent/US1626987A/en>
- **R. H. Thayer, Thayer Telkee Corp, US 1,749,399, "Key Tag", filed 6 April
  1926** — a pending application in 1928, and the same source SR7-G's night
  register cites for its numbered checks. One check series, three hooks, two
  apparatus.
  <https://patents.google.com/patent/US1749399A/en>
- **H. Machinist, US 2,220,937**, cited by SR7-J for the established practice:
  *"the watchman is provided with an implement, sometimes called a tour key,
  which he carries on his rounds"*.

**Orison-specific inference, stated plainly:** this guard, its latch, its check
number and the key's silhouette are authored. The wall it hangs on, the lane it
hangs in and the box at the other end of the round are not.

## The custody contract

```gdscript
signal tour_key_taken(check_number: int)
signal tour_key_returned()

func key_carried() -> bool
func take_key()   -> bool   # latch releases; check 3 goes on the hook
func return_key() -> bool   # key back; check away
func hook_reads() -> String # "TOUR KEY" or "check 3" — never a name
```

`maintenance_snapshot()` is **one key**: `{"key_on_hook": bool}`. That is the
entire footprint, and it reaches no save.

### Station integration — one narrow question

```
guard ──key_carried()──▶ WatchStationNetwork.tour_key_carried()
                                    ▲
                    station.tour_key_available() ──┘
```

`WatchStationNetwork.attach_key_guard()` adopts one guard and
`register()` hands each box the line via `bind_line()`, so a station never
walks the scene tree looking for a key. **A line with no guard answers
`false`** — which is the SR7-J condition and the honest one: a station cannot
be worked with a key that does not exist.

The receiver is untouched: it still displays **number and sequence only**, and
the test asserts its indication carries no `check` and no `carried_by`.

## Where it hangs

Building coordinates `(5.24, −2.99, 1.42)`, facing west. The lane now reads
north-bound: dumbwaiter to −4.48, **signal register −3.75…−3.35**, **the guard
−3.07…−2.91**, **night register shelf −2.63…−1.91**, detector −1.68…−1.32. The
0.72 m between the receiver and the register shelf was the last gap in the
lane; a 0.16 guard centred on −2.99 sits in the middle of it with 0.28 m clear
on each side. It projects 0.058 m.

**Mechanically separate from the night register, and physically so:** a
different board, a different hook, and check **3** against that register's 14
(apartment) and 7 (plant). Those two account for rooms. This one works
stations.

## Definitive frames

All 1280×720. SHA-256 truncated to 32 hexadecimal characters. Three cameras:
the guard's hook, the lane, and the F02 box.

| Frame | SHA-256 | Claim |
| --- | --- | --- |
| `00_guard_control_a.png` | `78f7aac6d4fe05aaff708b239b627702` | **As found**: `TOUR KEY` plate, the key on its hook, the latch lying across it. |
| `00_guard_control_b.png` | `78f7aac6d4fe05aaff708b239b627702` | **Byte-identical** — the guard camera's A/A floor. |
| `01_lane_control.png` | `38f32125ff64c4a832325bb73fcdb37a` | The watchman's lane: four instruments, four jobs. |
| `02_key_taken_check_hung.png` | `ab483c938ab67617f3c76555b8776cbf` | **Key taken.** Check **3** hangs in its place; the latch stands open. |
| `03_second_take_refused.png` | `853e48ee59be1a9168bc43a03f431e07` | **Refusal.** A hook carrying its check has no second key to give. |
| `04_key_returned.png` | `78f7aac6d4fe05aaff708b239b627702` | Returned — **identical to the control**, correctly: a returned key is a loaded hook. |
| `05_copied_key_refused.png` | `9f07c95c554f7c90b4040ea26fd8f183` | **Refusal.** A loaded hook will not take a second, copied key. |
| `06_restored_after_abort.png` | `78f7aac6d4fe05aaff708b239b627702` | **Abort — byte-identical to the control.** |
| `07_box_control_a.png` | `f748b078dce63bcbe36efec8f7eafcfc` | The F02 box, shut. |
| `07_box_control_b.png` | `f748b078dce63bcbe36efec8f7eafcfc` | **Byte-identical** — the box camera's A/A floor. |
| `08_box_open_no_key.png` | `f887dde7bef6cbf5058c9ab190d529e9` | Open, with the key still on its hook in the lobby: **an empty socket**. |
| `09_empty_socket_refused.png` | `47221ee98b54b202301dd4fb0596536a` | **Refusal — the socket.** The crank swings its whole travel against nothing and the socket is shoved forward. |
| `10_box_open_with_key.png` | `7e8ad3b17f3914a821769eb140773104` | The same box, with the key taken two floors away. |
| `11_marked_with_key.png` | `a3fa7f0101538d66f336cb5d76ef6ca9` | **Marked.** Drop down, wheel run. |
| `12_repeat_crank_refused.png` | `2f0719769443941c60a2eba7f2fa8e20` | **Refusal — the pawl.** A different refusal, and a different picture. |

**Eleven unique images across fifteen frames.** All four collisions are
deliberate identities: two A/A pairs, the returned key, and the abort.

## Pricing

Normalized RMSE, ImageMagick. **Both A/A floors and the abort are exactly
0.000000**, confirmed by matching SHA-256.

| Pair | RMSE |
| --- | ---: |
| guard control A → B | **0.000000** |
| box control A → B | **0.000000** |
| control → **restored after abort** | **0.000000** |
| control → key taken | 0.008429 |
| key taken → **second take refused** | 0.004524 |
| key returned → **copied key refused** | 0.008150 |
| box shut → box open, no key | 0.011799 |
| box open → **empty-socket refusal** | 0.002032 |
| box open with key → **marked** | 0.009761 |
| socket refusal → **pawl refusal** | 0.003860 |

### Declared crops

The key, the check and the socket are small brass objects in corridor frames,
so the claims are priced on their own subjects:

| Subject (crop) | Change | RMSE |
| --- | --- | ---: |
| hook `200x230+560+320` | A/A floor | **0.000000** |
| hook | **key → numbered check** | **0.037448** |
| hook | refusal: second take | 0.019990 |
| hook | refusal: copied key | 0.035801 |
| hook | control → **abort** | **0.000000** |
| works `300x420+560+120` | A/A floor | **0.000000** |
| works | **refusal: empty socket** | 0.005493 |
| works | **the mark, with the key** | **0.021638** |
| works | socket refusal vs pawl refusal | 0.010435 |

The two refusals on the box are **different photographs**, which is the point:
the empty socket swings the crank and shoves the socket, the pawl stops the
crank dead.

## Executable proof

Every run through `tools/run_godot_serial.ps1`, one instance, 60-second
ceiling, output redirected and only filtered results read. **Zero script
errors, zero parse errors, no timeouts.**

- `TourKeyTest.tscn`: **PASS 65/65**.
  - Taking replaces the key with check **3**; returning restores the hook; the
    latch stands open on an emptied hook and lies across a loaded one.
  - **Repeat take** and **copied-key return** are both refused, visibly, and
    change nothing.
  - The station reports an empty socket with the key on its hook and **refuses
    the crank**, with the refusal showing the *socket* rather than the pawl. A
    network with **no guard at all** answers `false` rather than permissively.
  - With the key carried: **one** drop, **one** fact, **one** delivery, **one**
    indication, agreeing on number. Three more cranks add nothing.
  - The guard cannot reach `leaf_state`, `DoorProp`, `unlock`, `locked`,
    `WorkOrders`, `RealityCases`, `RealityState`, `MaintenanceInventory`,
    `ObjectiveTracker`, `ScheduleDirector`, `AcousticGraphData`,
    `FirstShiftDirector`, `CoreLoopDirector` or `dream`.
  - A key never taken, and a key taken and never returned, both block nothing.
  - A whole keyed round writes **nothing** to the save.
  - **Abort** hangs the key back and **cannot retract** the mark already made.
- `TourKeyLiveTest.tscn`: **PASS 39/39**. In the real Orison: measured in the
  lane with clear plaster each side; its own board and its own check number,
  not a third hook on the night register; the real box refuses with the real
  key on its hook and marks with it carried; **not one of 74 real doors moved**;
  jobs, cases, lamps, switches, acoustics and schedules unchanged, and the only
  save key that moves is `first_shift`, the director's.
- `WatchStationTest` **77/77**, `WatchStationLiveTest` **38/38**,
  `WatchRegisterTest` **87/87**, `WatchRegisterLiveTest` **40/40** — SR7-J and
  SR7-K back-filled: their lines now carry a guard and their rounds take the
  key, which is what walking a round costs from here.
- `FirstShiftRitualTest`, `CoreLoopTest`, `NightRegisterLiveTest`: **PASS**.
- `InteractionInventory`: functional 279/35, up one for the guard.
- `WalkTest` (FAST): **239 pass, 2 fail** — `the chirp hunt` and `boiler's long
  parts list`. Both **pre-existing**, reproduced identically on a clean
  detached worktree at `9ea96d1`.

## REPORTED, NOT REPAIRED — one blocking seam

**`FirstShiftOpeningLiveTest` fails on this branch and passes 0-failures on a
clean `4f1ac40`.** It fails the same three assertions and then exceeds the
60-second ceiling rather than completing, because its later steps depend on the
mark it never gets. The cause is this increment, and it is the
increment the assignment asked for.

That test works the real box directly:

```gdscript
station.call("interact_control", "station", root.player)   # opens the door
station.call("interact_control", "station", root.player)   # turns the crank
```

Since SR7-L the second call refuses, because the tour key is on its hook —
*"A player without the tour key cannot operate the watch station"* is the
core rule of this assignment, and that test encodes the pre-SR7-L world.

**The fix is one line**, inserted before it works the box:

```gdscript
root.find_child("F01_TOUR_KEY_GUARD", true, false).take_key()
```

which is exactly the line added to `watch_station_live_test.gd` and
`watch_register_live_test.gd` here. `game/tests/first_shift_opening_live_test.gd`
is a reserved path this assignment forbids me to modify, so it is left for its
owner. The three failing assertions are about the mark, the duplicate guard and
the objective afterwards; all three should pass unchanged once the key is taken.

## Limitations

- **The key is not an object the player holds.** Custody is a fact about the
  hook, not a carried item: there is no hand, no encumbrance and no way to drop
  it in a corridor. "Carried" means "not on its hook".
- **Nobody can take it but the hook's own reach.** There is no second guard, no
  duplicate and no locksmith, so the copied-key refusal is a rule about the
  hook rather than a thing the building can produce.
- **Custody is transient.** A reload puts the key back on its hook, because a
  guard is emptied and refilled rather than journalled — and because owning
  save state is explicitly not this apparatus's business.
- **One key, one station.** The gate is a single boolean for the whole line; a
  building with two stations would still ask one question.
- **Nothing consumes `tour_key_taken`.** Onboarding integration remains
  Codex's.
