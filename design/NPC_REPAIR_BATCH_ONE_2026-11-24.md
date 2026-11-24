# NPC repair, batch one: four more residents, 2026-11-24

Evidence class: **INERT**. This is a batch report: the residents added, the measurement on each, and what stays
open. It is not acceptance. The captures it cites are review evidence only.

Work order **w3473eaaf58a9**. Lily ruled on 2026-11-24 (**npc_feet_descent_backswing_20261124**): Malcolm's
descending back-swing is acceptable for now; widen foot placement to more residents and revisit later. It builds
on the foot placement report, **design/NPC_REPAIR_FOOT_PLACEMENT_2026-11-24.md**, and the two pilot reports. All
text here is a first draft.

## 1. Who joins

Two more residents from each cast body base:

- **Female base:** Evelyn Marsh and Teresa Vale.
- **Male base:** Peter Wren and Noel Price.

With the pilots (Mina and Malcolm) that is six residents. All four new residents take the generic resident path,
so they play the shared walk.

They join both gates in animated_resident.gd:

- **FEET_PILOT** puts their feet on the tread under them.
- **GAIT_PILOT** distance-matches their shared walk, as it does Malcolm's.

Both are needed. Foot placement alone put their feet on the treads, but at the shared walk's fixed 1x rate the
planted feet still slid along each tread. Teresa's stair slip was about 0.8 m/s and Noel's about 1.07 m/s.

Omar Bell, outside both gates, is now the witness in the gait and feet tests that a resident outside them is
unchanged. Peter, the earlier witness, has joined the batch.

## 2. Measured

NpcPilotWalkingFeetTest (`RESIDENTS=evelyn_marsh,teresa_vale,peter_wren,noel_price`) gives the deepest heel or
toe joint below the tread on a stair of the house's dimensions, in metres. Negative is above the tread:

| Resident | Off median | Off p90 | On median | On p90 | Crowded hover p90 |
|---|---|---|---|---|---|
| Evelyn | 0.175 | 0.276 | -0.058 | -0.026 | 0.103 |
| Teresa | 0.168 | 0.271 | -0.057 | -0.027 | 0.097 |
| Peter | 0.182 | 0.293 | -0.063 | -0.029 | 0.119 |
| Noel | 0.189 | 0.299 | -0.062 | -0.029 | 0.117 |

On the level, every resident's largest correction is 0.000 m, so the clip is left alone. The stage costs 45–50
microseconds a frame per walking body under Lily's machine load. "Crowded" is the same climb past a player-sized
body and a loose crate; the feet follow the treads as on the clear climb.

The windowed shot (NpcPilotMinaShot, `RESIDENT=`) gives contact slip in m/s, median. It compares the plain shared
walk with both gates on:

| Resident | Flat, plain | Flat, both | Stairs, plain | Stairs, both |
|---|---|---|---|---|
| Teresa | 0.337 | 0.051 | 0.82 | 0.14 |
| Noel | 0.60 | 0.05 | 1.07 | 0.28 |

By eye:

- **Flat.** Noel's walk leaves single footprints, one per step.
- **Teresa on the stairs.** She climbs and descends with a foot on each tread and short marks.
- **Noel on the stairs.** Like Malcolm, he is held at the 0.5x rate floor at the stair pace, so his feet keep
  some slide.

Evidence is in **C:/ov/reports/npc_pilot_20261123/batch1** (outside the repo): `<resident>_off`, `_on` and
`_gait` captures with tiled strips, and the test receipts.

Final lane runs with both gates on, receipts in the batch folder:

- NpcPilotWalkingFeetTest on the batch: 29/0.
- NpcPilotGenericGaitTest: PASS, with Omar as the outside witness.
- NpcPilotMinaGaitTest: PASS.
- CastResidentTest: 24/0.
- CastClipPresentationTest: 43/0.

There were no script errors. The reader gate shows 0 new unread fields, and the spatial audit is clean.

## 3. What is left

- **House walks.** OrisonV2ResidentWalkTest for the four, and Malcolm's full repeat. Codex asked that these run
  once, on the clean composition.
- **Male-base stair slide.** The shared walk's long stride needs about 0.35x at the stair pace, and the rate floor
  is 0.5x. Lowering the floor or giving the stair its own pace are choices for later.
- **The rest of the cast.** Twelve more residents join in later batches once this one qualifies.
- **Earlier open items.** Malcolm's descending back-swing is accepted for now, to revisit. Mina's descent and her
  climb's head pitch remain open as before.
