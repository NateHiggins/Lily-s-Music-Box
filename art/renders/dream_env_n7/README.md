# The dream shipped with no light of its own

*2026-08-17. N7's last presentation item. Harness:
`game/tests/DreamEnvironmentShot.tscn`.*

```bash
SHOT_DIR=<abs> godot --path game res://tests/DreamEnvironmentShot.tscn
SHOT_DIR=<abs> DREAM_ENV_CONTROL=1 godot --path game res://tests/DreamEnvironmentShot.tscn
```

Exit code is the finding count.

## The defect

`building_root.gd` builds a `WorldEnvironment` for the **waking** Orison.
`CampaignShell` frees that world outright when it swaps in `DreamMazeRoot`,
which built none, and `project.godot` sets no `default_environment` to fall
back on. So the production dream ran with **no environment of any kind** — no
ambient, no tonemap.

That is not a polish gap. It contradicted a ruled requirement.
`ORISON_MAZE_BRIEF` §"THE LIGHT IS THE GAME":

> The world remains readable enough to move with the light off: black level
> keeps the nearest floor silhouette, and the receding practical supplies a
> vague orientation. "Off" means navigation by sound and memory, **not a black
> video file**.

`before/02_hall_lamp_off.png` is a black video file. Pure black but for the
crosshair. `before/01_hall_lamp_on.png` is barely better: a faint splash in a
void.

## Why nobody saw it

**The harness that photographed the dream built its own light.**
`dream_pursuit_shot.gd` added, before capturing anything:

| what it added | standing in for |
|---|---|
| `WorldEnvironment`, 0.18 ambient, filmic | the environment production lacks |
| `RecedingOrientationControl` (OmniLight3D) | the ruled receding practical |
| `NearestFloorBlackLevelControl` (OmniLight3D) | the ruled black level |

Its comment was candid — *"the ruled light-off state is navigable darkness,
not a black video file"* — and the names say `Control` out loud. But the
consequence is that **N6's accepted proof frames demonstrated navigable
darkness in a scene no player can enter.** The harness had quietly prototyped
both unimplemented features and then photographed them as if they shipped.

This is the "nothing pointed a camera at it" lesson with a twist worth naming
separately: *something* pointed a camera at it, and the camera brought its own
lighting rig.

## What was built

Three things, all in `DreamMazeRoot` — which is the right owner, because
`building_root.gd` owns the waking world's environment by the same logic and
`CampaignShell` then needs to know nothing.

**1. The environment.** The harness's own numbers, adopted rather than
re-invented so the existing record becomes true instead of being replaced.

**2. The black level**, and this is where adopting stopped working. Ambient
0.18 of a near-navy on 0.15–0.20 albedo graybox is worth almost nothing;
adding the environment alone left the frame still black. The harness's
readable darkness came mostly from its two OmniLights, so those are what got
promoted. Carried at ankle height on the body, cool so it can never be
confused with the warm service lamp, **shadowless**, and re-tuned to
`energy 1.6 / range 4.5` from the control's `0.48 / 9.0`. Shorter is the
point: a 9 m falloff lights the far end of a 19.30 m hall and hands over the
room the player is supposed to be listening to.

It cannot make darkness safe. `DreamPursuer` acquires on `lamp_is_enabled()`,
the player's own lamp, so nothing here feeds acquisition — and
`DreamPursuitTest` re-proves N3's contract at 39/39.

**3. The receding practical**, one warm fixture beyond each connector, exactly
one ever burning.

### The practical was wrong first, in this project's signature way

The first implementation put each fixture at its **module's centre**. D01 is
19.30 m long, so its centre stood **11.12 m** from the doorway the player looks
through — outside the fixture's own 9.5 m range. It lit the correct fixture and
could not be seen, which is the worst way for a light to be wrong.

That is "a position derived from something convenient rather than from the
surface it must touch", the defect this repo has recorded seven times, written
fresh. The position now comes from `plan.doors[i].aperture` — the connector
itself — stepped 1.5 m into the room beyond, so it reads from the near side as
a warm room you have not reached.

## The invariant nobody could have seen in a still

> It never slides away in view; the lit fixture changes only while a wall or
> closing door occludes it.

That is not one moving light — a light that slides ahead of the player is the
thing the sentence forbids. It is a series of fixtures with a handover rule,
and the rule is invisible in any screenshot. So the harness walks it:

```
modules walked      : 5
practicals          : 4
handovers           : 2
frames with 2+ lit  : 0
handovers in view   : 0
```

The walk faces the player **at the burning fixture** before asking whether it
can be seen. That is deliberately the worst case: a player looking away cannot
witness a handover however badly it is implemented, so an arbitrary heading
would pass a broken deferral.

**Recorded honestly:** only 2 handovers across 5 modules. The deferral is
holding, which is ruled-correct — it will keep a stale fixture lit indefinitely
rather than switch in view. But it means that down a straight chain the guiding
light can lag behind "one connector ahead" until a wall intervenes. That is the
conservative failure and the right one, and it is a design question rather than
a bug if the lag ever reads as the light being lost.

## DARK, NOT PITCH BLACK — corrected 2026-08-17 after owner review

The first landing was still black. Measured on the frames rather than judged
by eye:

| frame | mean | median | pixels at or below 3/255 |
|---|---:|---:|---:|
| hall lamp-off, before any of this | 0.0 | 0 | **100%** |
| hall lamp-off, first attempt | 1.0 | 1 | **95.3%** |
| hall lamp-off, now | 15.5 | 15 | **0%** |

Two real defects were behind it, and neither was a tuning value.

**1. The ambient was never applied at all.** `ambient_light_sky_contribution`
defaults to **1.0**, so with `AMBIENT_SOURCE_COLOR` Godot still blends the
ambient toward the SKY — and against a `BG_COLOR` background there is no sky,
so the term evaluated to zero. Raising `ambient_light_energy` did nothing
because the colour it scaled was weighted out. This is also why the old
harness's environment had never lifted anything: it had the same line missing.
Fixed, and the energy then set from measurement rather than taste.

**2. The beam mask crushed what was left, and inverted the lamp.** The torch's
screen mask multiplies over the frame, and how far it may dim is set by how
much light `LightRig` reports. The dream has no LightRig, so it reported
nothing, the vignette sat at its darkest 0.18, and the ambient outside the
beam was multiplied to a fifth. Switching the lamp **ON** took the frame from
median 12 to median 3 with 68% of it at or below 3/255 — a torch that darkened
the room, against a ruled contract that says light on gives information.

A world that lights itself can now say so (`PlayerController.set_world_lift_floor`,
`DREAM_LIFT_FLOOR = 0.72`). Not 1.0: the torch has to stay the reason you can
see, and the vignette is most of why it feels carried. Waking Orison never
calls it and still answers entirely to its own fixtures — `WalkTest` and
`GoldenLoopTest` confirm it is unchanged there.

Final, all four frames at **0%** below 3/255:

| frame | mean | median | p95 | max |
|---|---:|---:|---:|---:|
| hall lamp on | 10.1 | 9 | 19 | 135 |
| hall lamp off | 15.5 | 15 | 19 | 136 |
| threshold lamp on | 18.4 | 12 | 43 | 150 |
| threshold lamp off | 23.0 | 21 | 28 | 141 |

The lamp still reads as the information source — its beam is the max in every
frame, and at the threshold it lifts p95 from 28 to 43 — while nothing in the
passage is a hole in the screen any more.

## Frames

| file | |
|---|---|
| `before/01_hall_lamp_on.png` | a splash in a void |
| `before/02_hall_lamp_off.png` | **pure black** |
| `after/01_hall_lamp_on.png` | beam splash and the borrowed shadow still dominant — the light decision still reads |
| `after/02_hall_lamp_off.png` | the floor plane and wall edge, and nothing else: where the floor stops, without the room |
| `after/04_threshold_lamp_off.png` | the practical through the doorway — a direction to move, in the dark |
| `../dream_pursuit_n6/reshot_2026-08-17/` | N6's own frames, re-shot with the controls removed |

The last of those matters most. `dream_pursuit_shot.gd` no longer builds an
environment or any control lights, because keeping them would now **double**
production's and leave the frames just as unlike the game as before, in the
other direction. Its caption "DARKNESS DELAYS, NEVER HIDES" is finally over a
frame that is true of the shipping build.

## Gates

| gate | result |
|---|---|
| `DreamPursuitTest` | PASS, 39/39 |
| `DreamHazardTest` | PASS, 31/31 |
| `DreamPerceptionTest` | PASS, 20 |
| `DreamBoundaryTest` | PASS, 36 |
| `GateDJoinTest` (capture) | PASS, 69/69 |
| `DreamEnvironmentShot` | 0 findings |

## Still open in N7

The hollow runner's effect remains blocked on the owner's module ruling
(catalog places its socket in `D01_F04_LONG_HALL`; the brief's script says
D04, which has no sockets). The trunk's lit beam-splash confirmation is the
remaining presentation item.

No dream perf station exists in `Perf.tscn`; Gate E's "16.6 ms at its critical
stations" for the isolated dream scene is still unmeasured, and these lights
are new draws that nothing has priced.
