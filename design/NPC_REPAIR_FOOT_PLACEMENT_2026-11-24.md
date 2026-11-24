# NPC repair: walking foot placement, 2026-11-24

Evidence class: **INERT**. This is a build report: the defect, the stage and its before-and-after measurement on
the two pilot bodies. It is not acceptance. The captures it cites are review evidence only.

Work order **w3473eaaf58a9**. Lily ruled on 2026-11-24 (**npc_generic_stairs_20261124**): foot placement first.
Everyone keeps their own walk, feet land on each tread, and no animation is new. It builds on the two pilot
reports, **design/NPC_REPAIR_PILOT_MINA_2026-11-24.md** and
**design/NPC_REPAIR_PILOT_SECOND_RESIDENT_2026-11-24.md**. All text here is a first draft.

## 1. The defect

The house's stairs (orison_v2_blockout.gd) have two colliders:

- the treads, boxes 0.16 m high and 0.285 m deep;
- a traversal ramp under them, which touches only each tread's back edge.

The route carries a resident up the ramp line, and every walking clip is authored on a flat floor at the body's
root. So on a stair both feet sink into the treads, and the leading foot sinks by up to two risers. Measured on a
stair of the house's dimensions, as the deepest heel or toe joint below the real tread:

- Mina, in her own stair clips: 0.055 m (median), 0.127 m (p90);
- Malcolm, in the level walk: 0.195 m (median), 0.304 m (p90).

## 2. The stage

**walking_feet.gd** is a SkeletonModifier3D placed directly after the PosePipeline. It is a separate modifier
because the Harukiya staff standing profile pins the pipeline's file hash. A first version written into the
pipeline's contact slot broke that pin, and the house refused to start.

Each frame while the route walks the body, the stage:

1. Reads the floor under each heel and toe with a ray onto the real colliders. The swinging foot also reads
   0.12 m ahead of its toe, so it rises over the next nosing.
2. Keeps each foot at the height above that floor that the clip gave it above its flat floor. The correction is
   eased over 0.06 s, up to 0.5 m.
3. Moves the pelvis by the smaller of the two corrections, eased over 0.12 s, so the leg with further to go
   bends instead of overreaching.
4. Solves each leg as thigh and shin in the clip's own knee plane. The foot keeps the clip's orientation.

The floor ray reads support the way the resident route does: collision layer 1 and an up-facing face (normal.y of
at least 0.45). The player and loose props share layer 1, so a CharacterBody3D or RigidBody3D in the way is passed
through to the floor beneath it. Codex raised this after intake. Before the fix, in NpcPilotWalkingFeetTest, a
player-sized body and a loose crate on the stair lifted Mina's lowest foot to 0.325 m above the treads at p90,
against 0.085 m on a clear stair. After it, the figures are 0.088 m for Mina and 0.103 m for Malcolm (clear:
0.102 m).

On a level floor both corrections are zero and the clip passes through unchanged. The stage eases out when the
body stops. The engine restores the clip's pose after skinning, so the stage records where it placed the feet
(`last_feet_world`) for tests and captures.

It is gated by **FEET_PILOT** in animated_resident.gd to the two pilot bodies: Mina (female base, her own stair
clips) and Malcolm (male base, the level walk). Everyone else joins in batches once it qualifies.

## 3. Before and after

These come from the windowed NpcPilotMinaShot. `NO_FEET=1` keeps distance matching and switches only foot
placement off. The figures are the deepest heel or toe joint below the floor under it, in metres; negative is
above the floor:

| Body, walk | Off median | Off p90 | On median | On p90 |
|---|---|---|---|---|
| Malcolm, flat | -0.062 | -0.026 | -0.062 | -0.026 |
| Malcolm, up | 0.126 | 0.314 | -0.064 | -0.029 |
| Malcolm, down | 0.128 | 0.210 | -0.086 | -0.054 |
| Mina, flat | -0.040 | -0.025 | -0.040 | -0.025 |
| Mina, up | 0.031 | 0.129 | -0.045 | -0.028 |
| Mina, down | 0.058 | 0.119 | -0.047 | -0.025 |

With foot placement on, the stairs read like the flat: the joints sit their usual few centimetres above the floor
under them. Two earlier versions fell short:

- **A 0.3 m reach** dropped the leading foot of Malcolm's long stride, which can need about 0.4 m. His p90 stayed
  at 0.31.
- **The toe look-ahead alone** did not fix it.

By eye:

- **Malcolm.** He climbs with knees raised and feet on the treads. Going down his feet land on the treads, but
  the level walk's back-swing now lifts the trailing foot high over the tread behind. It reads a little like a
  kick and needs Lily's look.
- **Mina.** One foot lands on each tread both ways, and the footprints sit on the tread tops.

Horizontal slip is unchanged. It is the gait's job, and the rate bounds still limit it on the stairs.

Evidence is in **C:/ov/reports/npc_pilot_20261123/feet** (outside the repo): `<body>_off`, `_on3` and the tiled
`_up` and `_down` strips.

NpcPilotWalkingFeetTest is the headless test, and it writes a schema-2 runtime_contract receipt. It checks:

- the stage is installed on both bodies, straight after the pipeline;
- the level leaves the clip alone;
- the tread is found on the stair;
- the sink is lower than the same climb with the stage off;
- Peter, outside the gate, has no stage.

Lane runs, with receipts in **C:/ov/reports/npc_pilot_20261123/feet/tests**:

- NpcPilotWalkingFeetTest: PASS.
- NpcPilotGenericGaitTest: PASS.
- NpcPilotMinaGaitTest: PASS.
- CastResidentTest: 24/0.
- CastClipPresentationTest: 43/0.

OrisonV2ResidentWalkTest in the house:

- **Mina:** 384.9 m and every stop but the known bodega hold, with stop timings identical to her run before foot
  placement and no script errors.
- **Malcolm:** every stop matches his earlier run to within a second, through the walk out. He reached the
  1,500 s ceiling before the last leg home. Lily was using the machine heavily: both runs took about 30% more
  wall time than before, while the stage measures 40 microseconds a frame. His full run is to repeat on a
  quiet machine.

## 4. What is left

- **Batches.** Add residents to FEET_PILOT (and to GAIT_PILOT for flat matching), qualify, then measure.
- **Malcolm's descending back-swing.** It needs Lily's look before the batch.
- **Cost.** Measured in NpcPilotWalkingFeetTest at about 40 microseconds a frame per walking body (4.9
  rays) before the floor-ray fix, and about 60 under heavy machine load after it. The stage works only while the route walks the body. It is not yet on the performance matrix.
- **Earlier open items.** Mina's descent at the 3x rate bound and her climb's head pitch, as before.
