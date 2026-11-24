# NPC repair pilot: Mina, 2026-11-24

Evidence class: **INERT**. This is a pilot report: an inventory, a measured defect, a repair and its
before-and-after measurement. It is not acceptance. The captures it cites are review evidence only.

Lily's work order **w3473eaaf58a9** asks to inventory every character from source to controller, reproduce
the defects, repair them at source, and pilot on Mina and on one resident of another rig family before
expanding. This is the first half of that pilot: Mina only. All text here is a first draft.

## 1. Mina's chain, source to controller

| Stage | Owner on main |
|---|---|
| Body | **game/assets/characters/cast/mina_vale/mina_vale.gltf**: 76-bone Mixamo-style skeleton with skirt chains, built by `CastBodies.model_for` |
| Clips | the 20 `mina_*` clips in **cast/shared/cast_moves.glb**, re-based to the body by ResidentMovesLibrary |
| Clip choice | MinaAnimationBehavior, installed by animated_resident.gd |
| Pose modifiers | PosePipeline attention (Spine, Spine2, Neck, Head), then SkirtFollow and the hair-look nodes; the face controller drives blend shapes |
| Translation | the V2 resident route (orison_v2_resident_route.gd): 1.05 m/s, with stairs walked on ramp colliders |

Dead or fallback parts:

- gaze_tracker.gd is never created.
- The old shell, **game/assets/characters/mina_vale/**, is still the fallback body and the source of the clips.

## 2. What was measured

The probe (NpcPilotMinaProbe) checked her clips on her cast body:

- the idles, clip facing, lean and the 30 finger tracks are clean;
- the walk covers about 0.77 m a second at 1x, not the 0.88 assumed in the behaviour;
- the generated stair clips are slow: about 0.32 m/s climbing and 0.10 m/s descending;
- within one cycle the planted foot does not move at an even speed (0.61 to 0.89 m/s between quartiles).

Two other findings:

- **Not a clip defect.** The upward look and turn in earlier captures came from attention looking at the
  camera.
- **Still open.** The stair-climb clip itself tips the head up mid-flight.

## 3. The defect

The route moved her at 1.05 m/s everywhere while the behaviour played each travelling clip at one fixed rate.
Her feet slid on the flat. On the stairs, where she kept the level pace in a clip made for a fraction of it,
they smeared the length of the flight.

The walk-stop clip also walked on for 3.7 s after the route had already stopped her body.

## 4. The repair

**ClipGait** (game/scripts/characters/clip_gait.gd, new) measures each travelling clip on the body when it is
installed. The planted foot is the toe moving backward under the body; going downstairs, height cannot tell
it from the swing foot. From that foot's speed through the cycle, smoothed over 0.18 s, it builds a table.
Each frame the player's speed scale is set so that the clip covers ground at her actual speed at that point
in the cycle, bounded to 0.5x–3x.

**MinaAnimationBehavior** has four changes:

- It measures the walk, the hurried walk, both stair clips and the walk start.
- It distance-matches them every frame, including the walk start while it plays as a one-shot.
- It times one-shots in clip time.
- On a measured body, a stop settles straight into the idle instead of playing the sliding stop clip.

The old shell has no skeleton handed in, so it keeps the old behaviour.

**The route** caps the step on a stair edge at **STAIR_PACE** 0.55 m/s, beside the existing squeeze cap. The
member `route_speed` is never written and stays 1.05 for traffic and the receipts. The animation is now told
the speed she actually stepped at, so a squeeze, the stair pace or traffic slowing are all matched.

## 5. Before and after

The windowed NpcPilotMinaShot moves her as the route does. She walks on the flat from a standstill, then up
and down a ten-riser flight of the house's dimensions (rise 0.16, tread 0.285), with a dot at each frame's
planted foot. Contact slip is the speed of the stillest of the four heel and toe points, after the first
3.8 s, in m/s:

| Walk | Before median | Before p90 | After median | After p90 |
|---|---|---|---|---|
| flat | 0.217 | 0.705 | 0.079 | 0.182 |
| up | 0.714 (planted toe) | 1.005 | 0.104 | 0.161 |
| down | 0.938 (planted toe) | 1.047 | 0.234 | 0.550 |

The "before" stair runs were too short to reach the 3.8 s mark, so their numbers are the planted toe's slip
over the whole walk.

How the frames read by eye:

- **Flat.** After the repair, the footprints are tight clusters, one per step. Before, they were 0.3–0.6 m
  smears.
- **Up.** One foot lands on each tread.
- **Down.** One foot lands on each tread with about 0.1 m of slide.

Evidence is in **C:/ov/reports/npc_pilot_20261123** (outside the repo):

- before: b3/, strips b3_flat.png, b3_up.png and b3_down.png;
- after: a3/, strips a3_flat.png, a3_up.png and a3_down.png;
- probe.json and the earlier iterations.

NpcPilotMinaGaitTest is the headless behaviour test. It writes a schema-2 runtime_contract receipt.

## 6. Existing tests on this branch

These ran through the lane, with receipts in **C:/ov/reports/npc_pilot_20261123/tests1**:

- NpcPilotMinaGaitTest: 18 assertions, PASS. The wrapper counts the PASS summary as a nineteenth matching line.
- CastResidentTest: 24/0.
- CastClipPresentationTest: 43/0.
- CastMovesLibraryTest: 184/0.
- OrisonV2MinaDoorSafetyTest: PASS.
- LuncheonetteRouteTest: PASS.
- PublicTrafficCounterflowTest: PASS.
- HarukiyaBalconyDepartureTest: PASS.
- HarukiyaBackstageAccessTest: 80/0.

OrisonV2ResidentWalkTest for Mina has one failure. She walks 384.9 m and reaches every stop over the stairs
except the bodega, where she holds for 150 s on its capacity reservation with no path. Codex reproduced the
same hold for Mae on the base without this change. It is an admission issue, not a movement one.

## 7. What is left

- **Descent at the cap.** At 0.55 m/s the descending clip needs about 5x and is held at 3x, so it still
  slides a little. The choices are a slower descending pace, a regenerated descent clip, or foot IK.
- **Foot IK.** The body rides the ramp while the feet land on treads, so some vertical drift remains. This
  needs a foot-placement stage in the pose pipeline.
- **Head on the climb.** The head tips up in the climbing clip; that is a source repair.
- **Second pilot resident.** One resident of another rig family is still owed, before any batch.
- **Receipts.** The stair pace changes every walking resident's stair timing. The Harukiya balcony
  departure and backstage access receipts digest the route file and must be renewed; Codex owns them.
