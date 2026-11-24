# NPC repair pilot, second resident: Malcolm Reed, 2026-11-24

Evidence class: **INERT**. This is a pilot report: a rig survey, a measured defect, a repair and its
before-and-after measurement. It is not acceptance. The captures it cites are review evidence only.

Work order **w3473eaaf58a9** asks to pilot on Mina and on one resident of another rig family before
expanding. Mina's half merged as PR 534; its report is
**design/NPC_REPAIR_PILOT_MINA_2026-11-24.md**. This report covers the second resident. All text here is a first
draft.

## 1. Rig families: which ones still walk

**data/characters/rig_profiles.json** names four families:

- `mpfb_mixamo_76`: the cast.
- `meshy_biped`: the old Meshy shells.
- `adela_rigify`: Adela's earlier body.
- `doodle`: the player's avatar.

Only the cast family walks a route. Every resident on **data/characters/cast_bodies.json** wears a 76-bone cast
body, and so do Lily, Stacy and Adela's current body. Street traffic reuses the residents. The shells are
fallbacks only, and the doodle rig is the player's own.

The cast's one skeleton has two body bases, measured from the hips rest rotation and the shin length:

| Base | Hips at rest | Shin | Bodies |
|---|---|---|---|
| female | about 2–4° | 0.34–0.37 m | Mina, Adela, Evelyn, Iris, Juno, Lena, Mae, Nadia, Rhea, Teresa, guests B |
| male | about 9°, turned | 0.40–0.42 m | Cal, Jonah, Malcolm, Noel, Omar, Peter, guests A |

Cam (3.6°) and Sacha (4.2°) sit between the two. The male base is the "hips frame turned" group that
rig_profile.gd already works around. The second pilot is **Malcolm Reed**, on the male base.

Every resident but Mina also takes a different animation path. animated_resident.gd plays one shared `walk`
from **cast/shared/cast_moves.glb** and discards the route's speed and slope. So the same walk runs at 1x on
the level, on stairs and when slowed.

## 2. The defect

On Malcolm's body the shared walk's planted foot covers 1.72 m/s at 1x, with 1.83 m to a cycle. That is a
long, brisk stride, against the 1.05 m/s the route moves him. Each step smeared about 0.4 m along the floor.
Matched, the walk plays at about 0.6x on the level.

On stairs the same level walk runs at 1x. His feet pass through the treads and slide along the ramp line.

## 3. The repair

The generic path now uses the ClipGait measurement from Mina's pilot:

- The shared walk is measured on the resident's own body at install.
- Each frame its speed scale follows its planted foot's ground speed at that point in the cycle, at the speed
  the route actually stepped (the stair pace included).
- Stopping returns the player to 1x and the idle.

It is gated by **GAIT_PILOT** in animated_resident.gd, which holds only Malcolm. The other sixteen generic
residents keep the plain walk until this qualifies, as the order's batch rule asks. The case-scene pacing
(0.48 m/s) is matched the same way.

No clip was changed or added. I did not give him Mina's stair clips: that would change how he moves, and
that is Lily's call.

## 4. Before and after

These come from the windowed NpcPilotMinaShot with `RESIDENT=malcolm_reed`. It uses the same stage as
Mina's: from a standstill, the flat, then up and down a ten-riser flight (rise 0.16, tread 0.285). The shot's
before mode keeps the level pace on the stairs. That was main before PR 534; current main walks stairs at 0.55
m/s. So the before stair rows overstate today's slide, while the flat rows are exact. Contact slip is the stillest heel or toe after 3.8 s, in m/s:

| Walk | Before median | Before p90 | After median | After p90 |
|---|---|---|---|---|
| flat | 0.631 | 0.734 | 0.045 | 0.155 |
| up | 0.708 (planted toe) | 0.897 | 0.291 | 0.357 |
| down | 0.708 (planted toe) | 0.913 | 0.298 | 0.386 |

By eye:

- **Flat.** The footprints are single points, one per step. Before they were 0.4 m smears.
- **Stairs.** The horizontal slide is smaller, but the level walk still passes through the treads, and its
  footprints follow the ramp line. At the stair pace his long stride would need about 0.35x, and the rate
  stops at 0.5x.

Evidence is in **C:/ov/reports/npc_pilot_20261123/second** (outside the repo):

- before: b1/, strips b1_flat.png, b1_up.png and b1_down.png;
- after: a1/, strips a1_flat.png, a1_up.png and a1_down.png;
- the test receipts are in tests/.

NpcPilotGenericGaitTest is the headless test, and it writes a schema-2 runtime_contract receipt. It checks:

- the measurement on his body;
- per-frame matching on the level and at the stair pace;
- the stop;
- that a resident outside the gate (Peter) still walks at 1x.

Lane runs on this branch, with receipts in **C:/ov/reports/npc_pilot_20261123/second/tests**:

- NpcPilotGenericGaitTest: PASS, with 0 frames off on the level and at the stair pace.
- NpcPilotMinaGaitTest: PASS.
- CastResidentTest: 24/0.
- CastClipPresentationTest: 43/0.
- OrisonV2ResidentWalkTest for Malcolm: 754.7 m from the third floor, and every stop but the bodega.

At the bodega he stands with an empty path while its local itinerary is occupied for 150 s. Codex attributes
that to the grocery's admission, separately from movement.

## 5. What the pilot shows

- **Flat walking.** The repair carries across both body bases and both animation paths. A batch of residents
  can join the gate on the flat with no new clips.
- **Stairs.** Rate matching is not enough. The generic residents have no stair clip, and both pilots hit a
  bound on the stairs: Mina's descent at 3x, Malcolm at 0.5x. The common next step is foot placement on the
  treads (foot IK in the pose pipeline, after the clip). Lily ruled for foot placement first, with no new
  stair clips (section 6).

## 6. What is left

- **Batch one.** Add residents to GAIT_PILOT (flat-walk matching only), qualify, then measure.
- **Foot placement (next).** Lily ruled on 2026-11-24 (npc_generic_stairs_20261124): foot placement first.
  Everyone keeps their own walk, with feet that land on each tread, and there is no new animation. It goes in
  the pose pipeline after the clip, for every walker, as the next step of this order.
- **Earlier open items.** Mina's descent and the head pitch on her climb, as in the first report.
