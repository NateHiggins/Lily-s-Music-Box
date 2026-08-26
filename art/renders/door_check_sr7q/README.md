# SR7-Q — the door is not closed

An overhead liquid door check and spring on `ROOF_DOOR_01`, photographed in the
production building through the player's own camera.

**The claim this sheet exists to test:**

> A door that can be shut is not a door that will close itself.

---

## The audit came first, and it corrected the brief

The task asked about "the Orison's stair-enclosure **doors**". Swept in the
built tree, production has **113 door leaves and exactly ONE of them stands on
the stair enclosure** — `ROOF_DOOR_01`, the galvanized 0.96 m service leaf at
the head of the stair, measured at **b(-1.330, -3.250, 19.200)**. Every other
stair core in the building opens through a 3.2 m cased opening with no leaf in
it at all.

The plural premise is spatially wrong. **The singular one is not**, and that is
why this is an apparatus rather than a report saying no. `door_check_live_test`
asserts the count and the identity so it stops being a claim in a comment.

Production also already had the *word*: `data/prop_service_wire.json` carries a
`CLOSER {closer_state}` field and a card about spending a leaf's return slowly,
and `landmark_entry_door.gd` mentions a closer in a comment. **Nothing filled
either.** No closer state, no closer script, and no self-closing door anywhere —
`DoorProp` moves a leaf only when a hand or a resident asks it to.

## What is on the door

Dizer's arrangement, on the frame head, on the landing side: spring box and
liquid cylinder, filler plug, **regulating screw with a brass index tang and a
fixed witness mark**, spindle, jointed arm, eye, shoe bolted to the leaf, and a
hold-open catch on a lug under the head.

**As found it is complete to look at and connected to nothing.** The arm is off
its spindle, hanging on its own elbow, so the spring has nothing to push. And
behind that, the second fault: **the leakage port is screwed home**, so even a
shipped arm would have nothing to move the liquid through.

```
connected() = arm_shipped      the arm is on its spindle
metered()   = port_open        the leakage port will pass liquid
ready()     = connected() AND metered()
```

## Conditions, declared

| | |
| --- | --- |
| Base | **`cf310da`** "Keep the golden shift inside its evidence gate" |
| Scene | production `res://scenes/building/orison_root.tscn` |
| Camera | the player's own, `player.global_position = from - player.camera.position` |
| Clock | `DAYNIGHT=0` **plus `DAYNIGHT_FORCE=13:10`** |
| Weather | `WEATHER_RAIN=0`, `WEATHER_MIST=0`, `WEATHER_SEED=7` |
| Lamp | **off** |
| Freeze | physics off → aim → lamp off → 1.6 s real → process off → `time_scale = 0` |
| Head crop | `520x430+420+270` of 1280×720 |
| Valve frames | measured whole-frame (the crop is the 26° FOV itself) |

The sheet was **re-shot in full on `cf310da`** after the branch was replayed onto
it. The three commits between `efc9325` and `cf310da` touch only design
documents, `dream_tentacle_controller.gd` and `golden_loop_test.gd` — nothing in
this interior's render path — but a spot check moved by up to 0.0038 on the wide
frame, which is run-to-run drift rather than a base change, and re-shooting
removes the question instead of arguing it.

**Why every apparatus frame has the leaf standing open.** The head of this door
is a shadowed reveal. Five probe passes — 03:00 house light, 13:10 daylight, the
player's lamp, from below, from the side — all came back with the apparatus
reading as dark iron on a black leaf. With the leaf **open** it stands against
the sky and every part of it is legible. That is not a trick to flatter the
sheet: it is the state the whole thesis is about, because a door check is only
interesting while a door is open. The one frame that wants a shut leaf is the
last one, where the shut leaf **is** the evidence.

## Frames

| File | md5 | What it is |
| --- | --- | --- |
| `00_as_found_control_a.png` | `c006994e09da0234116e59ca52165e61` | **A/A control**, and the as-found frame. Arm off its spindle. |
| `00_as_found_control_b.png` | `c006994e09da0234116e59ca52165e61` | The same, untouched. |
| `01_catch_thrown.png` | `bdf21dca263c1d81e61466e7f1616b0a` | The hold-open catch thrown. |
| `02_arm_shipped.png` | `19622f7a7fb3baa34d2bc5ed5568a56b` | **The repair**: the arm on its spindle. |
| `03_catch_off.png` | `ea15a1f4f6131321b4bdf666790b67e2` | Catch off again, arm still shipped. |
| `04_valve_control_a.png` | `cb4015923574a206930ae4c0928b7452` | **A/A control** on the valve crop; port home. |
| `04_valve_control_b.png` | `cb4015923574a206930ae4c0928b7452` | The same, untouched. |
| `05_port_open.png` | `8dd4bcee0aa51c238b622aea9ffa06d6` | The screw backed out to 3/5. |
| `06_bulkhead_wall.png` | `6f3bdc34f0bedecf6317283faa8a3842` | The wall: this door and SR7-P's roof board. |
| `10_control_a.png` | `c3806366333682fb821c7bad76a0d6aa` | **A/A control** for part B. |
| `10_control_b.png` | `c3806366333682fb821c7bad76a0d6aa` | The same, untouched. |
| `11_refuse_arm.png` | `4d2a2655a298f83ad9deb524d0100fe9` | Refusal: the arm. |
| `12_refuse_valve.png` | `3776043156a80cd7104a89be508be60f` | Refusal: the regulating screw. |
| `13_refuse_hold.png` | `f0100b5982232cee36c7b90a193af880` | Refusal: the catch. |
| `14_refuse_leaf.png` | `d26f981643abf29ab703cf6752d50cf2` | Refusal: the leaf. |
| `15_refuse_lock.png` | `25088859299c4eed7e27b4dc23ac7003` | Refusal: **locked is not closed**. |
| `16_calm.png` | `08e6e64a3be124fffea68761f192d84c` | After all five, everything let go. |
| `17_stopped_short.png` | `dc7966b0d96953564348a84739a06321` | Asked to prove a close with the port home. **The leaf did not move.** |
| `18_ready_and_open.png` | `f70174dd79c48d917b6f1a5d2d57323d` | Port open. Ready. Leaf still standing. |
| `19_came_home.png` | `2599062ffd837bf043a0d3996cb93592` | Let go — **and it came home on its own.** |

Twenty frames, seventeen distinct files. The three collisions are the A/A pairs,
which double as their own state frame; the sheet does not stage a second copy of
a frame it already has.

## The floors, first

| Pair | RMSE | Differing pixels |
| --- | ---: | ---: |
| `00_a` ↔ `00_b` | **0** | 0 |
| `04_valve_a` ↔ `04_valve_b` | **0** | 0 |
| `10_a` ↔ `10_b` | **0** | 0 |

Three A/A pairs, all **exactly zero, byte for byte**. Every number below is
worth what these are.

## What a hand changes

Head crop, within one run.

| Change | RMSE |
| --- | ---: |
| catch thrown → **arm shipped** | **0.0608** |
| as found → **arm shipped**, catch off in both | **0.0608** |
| as found → catch thrown | 0.0758 |
| arm shipped → catch off | 0.0758 |

The arm is measured **twice, independently** — once with the catch thrown in
both frames and once with it off in both — and lands on 0.06075 each time. That
is the fault and its repair, and it is 0.06 against a floor of 0.

## The port, on its own crop

| Change | RMSE |
| --- | ---: |
| port home → **port open (3/5)** | **0.00680** |

**This number is the sheet's second draft, and the first one is why the hardware
changed.** The screw originally carried a 30 mm slot cut in its head. It moved
its own tight crop by **0.000375** — which is to say the setting was *not*
readable, whatever the source comment claimed. It now carries a brass index tang
sweeping past a fixed witness mark, which is how a man actually reads a
regulating screw, and the same measurement is **18× larger**. The valve refusal
improved with it, from 0.000673 to 0.0116.

## Five refusals, five photographs

Head crop, each against `16_calm`.

| Refusal | vs calm |
| --- | ---: |
| `11` the arm | **0.0827** |
| `13` the catch | **0.0736** |
| `15` locked is not closed | **0.0673** |
| `14` the leaf | **0.0298** |
| `12` the regulating screw | **0.0116** |

And against each other — every pair, no exceptions:

| | `12` | `13` | `14` | `15` |
| --- | ---: | ---: | ---: | ---: |
| `11` | 0.0835 | 0.1107 | 0.0851 | 0.1043 |
| `12` | — | 0.0745 | 0.0320 | 0.0683 |
| `13` | — | — | 0.0794 | 0.0848 |
| `14` | — | — | — | 0.0743 |

**The smallest distance between any two refusals is 0.0320, which is 2.8× the
weakest refusal's own signal and infinitely more than the floor.** Five
refusals, five different photographs.

### And every one of them lets go

`16_calm` against `10_control_a` — the same state, before the five refusals and
after them — is **RMSE 0**, with **257 of 921,600 pixels differing (0.028%)**.

**That number was 0.00414 on the previous sheet**, and finding it was worth the
whole exercise: the valve refusal nudged `position.x` by 14 mm and
`_refresh_closer` reset only the *rotation*, so the screw stayed nudged forever.
A refusal that leaves a mark lies about the next frame. The prop now names a
`VALVE_REST` pose and puts every part back, and `door_check_test` grew a guard
that snapshots every transform this apparatus owns, balks, and demands the exact
string back — for all five refusals.

## Letting go

Head crop.

| Change | RMSE |
| --- | ---: |
| as found → **arm shipped** (part B's own measurement) | 0.0618 |
| stopped short → ready (the port, seen from the head camera) | 0.0115 |
| **ready and open → came home** | **0.3579** |
| the same, whole frame | 0.2491 |

`17_stopped_short` is the frame that matters most after `00`. The closer is
asked to prove a close while the port is screwed home, and **it does not request
one**, because it cannot deliver one — so the leaf is photographed exactly where
it was left, and the record says `stopped_short`, not `closed`. Nothing
pretended a door shut.

`19_came_home` is the only frame on this sheet where a door closes with no hand
on it.

## Cross-part

`00_as_found_control_a` ↔ `10_control_a` — the same state photographed in two
separate runs — is **0.000619**. Within a run the floor is exactly zero; across
runs it is six ten-thousandths. **Every comparison in the tables above is
within-part.** Nothing here is quoted across the two runs.

## Discarded, and why

0. **A 03:00 house-light sheet.** `DAYNIGHT=0` alone parks the clock at three in
   the morning, and this apparatus is on the roof — the first probe came back a
   black doorway in the rain.
1. **The player's lamp.** The beam lands east of the reveal and puts a hot spot
   on the stucco without reaching the iron. It also makes the light depend on a
   cookie bake, which is a determinism risk for no gain.
2. **From below, and from the side.** Three more camera families, all still dark
   iron on a black leaf. The reveal is shadowed in every condition tried, and
   saying so is more honest than lighting it artificially — a proof-only light
   is not allowed and would not have been used if it were.
3. **A 0.19 + 0.17 m arm with the shoe at local x 0.76.** It needed **0.956 m of
   reach** at full open and had 0.36. It photographed as an arm waving at a shoe
   it could never touch. The linkage was re-solved — spindle at 0.140, shoe at
   0.620, links 0.30 and 0.32 — and the arm angles are now real two-link
   geometry computed against the shoe's actual position, so the eye lands **on**
   the pin in both states and can never be drawn reaching for a shoe it does not
   reach.
4. **The 30 mm slot on the regulating screw** — 0.000375, above.
5. **The leaked valve position** — 0.00414, above.
6. **A hold-open catch floating in the doorway.** The first one hung on nothing
   at all. It now has a lug bolted up under the head, because a thing bolted to
   a building has to be seen bolted to it.

## What this sheet does not show, and what it does not claim

- **Production does not distinguish "closed" from "latched".** `DoorProp`'s
  `leaf_state` is `closed | open | locked`; a latch exists only as the click on
  `_settled()`. This sheet therefore photographs a leaf that **reached closed**,
  and no frame here proves a latch was thrown, because there is no latch in
  production to photograph. The apparatus records `reached_closed`, never
  `latched`.
- **The port setting is legible only on its own 26° crop**, not from the head
  camera. It is 0.00680 there and 0.0115 at the head, both real, both small.
- **I found no pre-1928 source requiring that a stair door be self-closing**, or
  specifying a closing force, a closing time, or an inspection interval, so the
  apparatus asserts none of them. It has no schedule, no due date and no
  standard. No modern life-safety rule is projected backward anywhere in it.
- **The Orison-specific inference** is that this building fitted a check to the
  bulkhead leaf at the head of its stair. **The authored fault** is that this
  unit's arm was knocked off its spindle and its port left shut.

## Sources

- **W. M. Dizer**, Brookline, Massachusetts — US **866,719**, *Door Check and
  Closer*, filed 20 February 1907, patented 24 September 1907. The whole
  apparatus in one place: a cylinder that "contains a liquid" with "a ported
  piston therein"; a spring above the door whose "resiliency … operates to close
  the door"; an arm linking the piston-rod to a spindle; and the sentence the
  check setting comes from — "the speed of the closing movement of the door is
  determined by the size of the leakage port."
- **J. B. Erwin**, Milwaukee, Wisconsin — US **797,273**, *Door Closer and
  Check*, filed 9 October 1903, patented 15 August 1905. Cited for what a closer
  is *for*, in the record's own words: "to provide a simple and efficient device
  for checking and regulating the movement of a door … whereby the same is
  prevented from slamming." **Erwin's check is a centrifugal governor, not a
  liquid one**, so it is cited for the purpose and the linkage and **not** for
  this unit's mechanism.

## Reproducing

```bash
SHOT_PART=a tools/run_godot_serial.ps1 -Scene res://tests/DoorCheckShot.tscn -ProjectPath <checkout>/game -Windowed -ShotDir <dir>
```

Then `SHOT_PART=b` for the second half. Split because a full sheet does not fit
the 60-second ceiling; each part carries its own A/A pair so neither borrows the
other's floor.
