# K2-A — the player does not read source

The first playable minute of the Orison, from the kerb to the report in hand,
photographed in production from a **fresh campaign** through the player's own
camera, with the HUD left on — because what the player is told is exactly what
is under examination.

---

## The audit, and the one thing it found

I started the real game from a fresh campaign and walked the opening with
ordinary interaction seams. The chain is:

| Step | What the player is told | What answers |
| --- | --- | --- |
| Kerb, b(-3.60, -24.72) | *FIRST SHIFT — ORISON APARTMENTS.* "Cross to the Orison lobby. Clock in at the watchman's detector; tonight's first report is waiting beside it." | the lit entrance, 15.25 m away, under a neon sign |
| Lobby | (unchanged) | — |
| Detector, b(5.24, -1.50) | "[E] Clock in — seat tonight's paper dial" | `F01_WATCHMAN_DETECTOR` |
| Register, b(5.24, -2.27) | "[E] The spindle is empty" → "[E] Take the report off the spindle" | `F01_NIGHT_REGISTER` |
| Report taken | *WORK ORDER 001 — THE CHIRP* | `WorkOrders` + `RealityCases` |

**The kerb is excellent.** Rain, the vertical ORISON neon, a lit awning reading
THE ORISON, DRUGS across the street. Nobody needs help crossing that road.

**The next transition is the first genuinely ambiguous one, and it is
ambiguous by a measurable amount.** I sampled every walkable cell of the ground
floor at 0.5 m and asked, from a standing eye, whether the detector's face is
visible with a clear line:

> **831 walkable cells. The detector is visible from 112 of them (13%) — and
> not one of those is in the entrance hall.**

The 112 form a single north–south stripe at x ≈ 3.5–5.0: you can see the desk
only once you are already in the corridor it stands in. On the direct walk from
the front door to the desk, the **first clear sight of it arrives at 2.71 m** —
barely ahead of the player's own **2.10 m** interaction ray. So the sequence for
a fresh player was: be told to clock in at a named object, walk into a room
where that object cannot be seen from anywhere, and guess.

**And what they are guessing about is the best thing in the room.** The east
wall of the ground floor is the Orison's entire working spine, in order from the
front wall northward: lobby clock, post tray, mail chute, porter's board,
service dumbwaiter, signal register, tour-key guard, night register, and the
watchman's detector at the head of it. From just inside the door, turning right
puts all of it on one clear 7.5 m axis. The building was never hiding the desk.
**It simply never said which way it was.**

## The fix: two cues, both building facts

1. **The clock is audible, because it is running.** `WatchmanClockProp` already
   owned `movement_running` and a `tick` emitter it only used for a lever event.
   A wound movement in an empty lobby at three in the morning now beats once a
   second. The beat is a function of `movement_running` and **nothing else** —
   not the ritual phase, not where the player is standing, not whether the game
   would like to help. Stop the movement and the lobby goes silent, which is
   SR7-F's whole lesson said out loud.
2. **The building has the plate it was missing.** `WayfindingSignagePass`
   already builds brass-framed directional signs — eight FIRE EXIT plates, one
   per floor. It had nothing naming the watchman's post. It does now, on a
   measured pier in the entrance hall, naming the spine in the order the player
   will walk past it, and pointing right.

Neither owns lifecycle state. Neither knows what phase the shift is in. The
plate has no script at all.

## Conditions, declared

| | |
| --- | --- |
| Base | `c78a280` "Let the roof stair leaf swing with egress" |
| Scene | production `res://scenes/building/orison_root.tscn`, **fresh campaign** |
| Camera | the player's own, `player.global_position = from - player.camera.position` |
| Clock | `DAYNIGHT=0` |
| Lamp | off |
| HUD | **left on, deliberately** |
| Freeze | physics off → aim → lamp off → 1.6 s real → process off → `time_scale = 0` |
| Plate crop | `220x140+530+290` of 1280×720 |
| Spindle crop | `230x230+560+170` |

Split into two parts. Thirteen frames plus a production boot writes every frame
and then blows the 60-second ceiling on **Godot's own shutdown** — the engine
reports `BUG, indexing did not unpair geometries from light` and never exits.
The work completed either way; splitting is how the run also *exits* clean, and
each part carries its own A/A pair.

The whole sheet was **re-shot on `c78a280`** after the branch was replayed onto
it. That commit regenerates `building_layout.json`, so it could in principle
have moved the lobby; it did not — the live suite's measurements (2.71 m to
first sight, 4.05 m to the plate) came back identical — but re-shooting settles
it rather than arguing it.

## Frames

| File | md5 | What it is |
| --- | --- | --- |
| `00_arrival_control_a.png` | `8fe919388575298ff478fd5b2a5503d3` | **A/A**, and step 1: the kerb, exactly where a new game puts you. |
| `00_arrival_control_b.png` | `3859f84508c0637d7669dff71ce88aa6` | The same, untouched. |
| `01_doorway_control_a.png` | `45c225a46eccb531fe44cedc9e471eb7` | **A/A** at the doorway camera. |
| `01_doorway_control_b.png` | `75d0e1633355d1f33a637f3d6da4cec8` | The same, untouched. |
| `01_doorway_before.png` | `90b9e86785e0ea0657929afa2c25caac` | The entrance hall **with the plate hidden**. |
| `02_doorway_the_invitation.png` | `13c656fdbd4d637f606e12aeaa3ca68d` | Step 2: the same frame **with the plate**. |
| `03_up_the_spine.png` | `4c4e4d6561b3bd56bff519732bfd3b54` | Step 4: the turn it asks for — the whole spine on one axis. |
| `04_desk_control_a.png` | `4598d6db1acdfa9034b6fd36d342cc3b` | **A/A** at the desk camera. |
| `04_desk_control_b.png` | `4598d6db1acdfa9034b6fd36d342cc3b` | The same, untouched. |
| `04_refusal_the_spindle_is_empty.png` | `4598d6db1acdfa9034b6fd36d342cc3b` | Step 5: **the refusal, physical** — a bare spindle. |
| `05_the_paper_is_on_the_spindle.png` | `2b6343b58309ba08fed9089f5be3f8d9` | Step 3: **the physical response** — WORK ORDER 001 / THE CHIRP / UNIT 2A. |
| `06_the_report_in_hand.png` | `07ab2d79fc3a42f0dce5f656beb58fde` | Step 6: the report honestly in hand. |
| `07_the_round_ahead.png` | `2595f648561bd56f3c56502b1c74009f` | The corridor again, with the night's actual intention on the card. |

Thirteen frames, eleven distinct files. `04_desk_control_a/b` and
`04_refusal_the_spindle_is_empty` are byte-identical: the A/A pair **is** the
refusal frame, because a refused action changes nothing to photograph. That
collision is the point, not an economy.

## The floors, first

| A/A pair | RMSE |
| --- | ---: |
| `04` desk, interior | **0** (byte-identical) |
| `00` arrival, through rain | 0.0000135 |
| `01` doorway, windows onto rain | 0.000689 |

The desk pair is exactly zero. The other two are not, and the reason is stated
rather than hidden: **a rain shader answers to its own clock, not to
`Engine.time_scale`**, so any frame with weather in it has a floor. Every claim
below is measured against the floor of *its own* camera.

## The invitation

The plate hidden and shown, same frame, same light, same everything.

| | RMSE | vs its own A/A |
| --- | ---: | ---: |
| plate crop | **0.0639** | 0.000142 → **449×** |
| whole frame | 0.0118 | 0.000689 → 17× |

## The physical response

Spindle crop, against a desk A/A of **exactly zero**.

| Change | RMSE |
| --- | ---: |
| bare spindle → **paper on it** (clock in) | **0.0958** |
| paper → taken (the report in hand) | 0.0937 |
| bare → bare, before and after the whole exchange | 0.0456 |

That last row is not noise and is not a failure: after the report is taken the
register is **not** in the state it started in, because it knows a report is
out. The spindle is bare for a different reason than it was at the start, and
the desk says so.

## What this does not show, and what I declined to do

- **The beat cannot be photographed.** Half this increment is a sound, and a
  proof sheet is silent. It is proved by state instead — `first_minute_test`
  drives the escapement without listening to it, and asserts that a stopped
  movement advances nothing and makes no sound.
- **No waypoint, no arrow overlay, no modal card, no narrator.** The plate is a
  sign on a wall, and the sign is as true at the end of the game as at the
  start.
- **I fixed ONE transition.** The second thing the audit found is real and is
  *not* repaired here: clocking in produces no visible change **at the clock
  itself** — the paper appears 0.77 m away on the register instead. That is the
  next candidate, and broadening into it before this one is proved would have
  been exactly the mistake the brief warns about.
- **The objective text at `report_accepted` is a three-clause checklist**
  ("Follow the chirp… take the TOUR KEY… work STATION 2 if you see it"). I left
  it alone: it is `FirstShiftDirector`'s copy, it is the *third* transition, and
  changing it was not required to fix the first.

## An unrelated defect this sheet caught, and did not repair

**`03_up_the_spine.png` has no ceiling over the service corridor.** Above the
wall line the frame shows night sky and a neighbouring facade with fire escapes,
where a 1912 corridor ceiling should be. Measured rather than eyeballed:

| | |
| --- | --- |
| Collision straight up from the corridor | solid at **z 3.02** at every sampled point, x 3.6–4.8, y -9.6 → -0.6 |
| Who owns that collider | `OrisonRoot/F02/F02_slabs/StaticBody3D` — the floor slab of the storey above |
| Rays north and up (+10° to +70°) | all stop on that slab |
| Ceiling finish meshes | `F01_ceiling_plaster` and `F01_ceiling_tin_ceiling` are present and `visible=true`, and their bounding boxes span the corridor |

So the storey above supplies **collision but no visible underside**, and the
finish meshes whose bounding boxes cover this span evidently do not cover it in
fact — a bounding box is not coverage. The camera therefore sees straight past
z 3.02 to the sky dome. The entrance hall a few metres away renders its tin
ceiling correctly, so this is a gap in one span rather than a missing system.

**NOT REPAIRED, DELIBERATELY.** The fix belongs in geometry generation —
`art/data/gen_layout.py` and `game/data/building_layout.json` — which is
Codex's reserved lane for this task. It is also entirely unrelated to K2-A: this
increment adds a sign and a sound, and the gap is present with both of them
removed.

## Discarded attempts

1. **The player's lamp as the cue.** Turning it on at the doorway puts a hot
   spot on the stucco east of the reveal and reaches none of the iron; it also
   makes the sheet depend on a cookie bake. Rejected on the frame.
2. **The plate at x 2.20.** The entrance hall's north wall is not continuous —
   solid across x 0.8–1.2 and 2.4–3.2, open between, because the elevator stands
   in the gap. The first plate hung in the lift doorway with nothing behind it.
   Moved to the measured pier at x 2.80.
3. **The plate in `_enamel`.** Built in the fire signs' vitreous enamel,
   Color(0.055, 0.075, 0.068) at roughness 0.08, it photographed against warm
   plaster as a black glossy rectangle and read as **a flat screen hung on a
   1912 wall**.
4. **The plate in `_brass`.** Darker still: the pier is a dim corner, and a
   metallic material with nothing to reflect renders black, taking the engraved
   letters with it. Settled on a painted board with pale lettering — which is
   what a lobby directory read from four metres in low light actually is.
5. **Four probe passes of camera guesswork** before I stopped guessing standing
   places and sampled the floor on a grid. Two of those posts had put me inside
   the elevator car.
6. **A bearing convention off by 180°** in the first sweep, which reported the
   station "off-screen" from every post because every sweep faced backwards.

## Reproducing

```bash
SHOT_PART=a tools/run_godot_serial.ps1 -Scene res://tests/FirstMinuteShot.tscn -ProjectPath <checkout>/game -Windowed -ShotDir <dir>
```

Then `SHOT_PART=b`.
