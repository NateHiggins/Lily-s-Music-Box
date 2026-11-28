# NPC repair: the men's stair rate, 2026-11-25

Evidence class: **INERT**. This is a change report: what changed, what was measured, and what stays open. It is not
acceptance. The captures it cites are review evidence only.

Work order **w3473eaaf58a9**, under Lily's ruling **npc_male_stair_slide_20261125**: on stairs the men's walk may
play down to a third of its speed so their feet stay planted, and flat walking is unchanged. It follows
**design/NPC_REPAIR_BATCH_THREE_2026-11-25.md**. All text here is a first draft.

## 1. What changed

- **clip_gait.gd.** `STAIR_MIN_SCALE` is one third. `scale_for` takes an optional floor, so Mina's callers keep 0.5.
- **animated_resident.gd.** A resident whose left shin measures at least 0.40 m at rest is long-legged. On a route
  edge with a slope of 0.3 or steeper the walk may slow to a third; the house stair is 0.56. Level walking keeps
  the 0.5 floor.

The threshold comes from measuring all seventeen generic bodies. The male base measures 0.405–0.486 m, Cam
shortest. The female base measures 0.377–0.397 m. The first threshold, 0.385 m, put the women on the long-legged
side too. That run failed two checks, and its receipts are kept in **stair_rate/run1**. The test now holds the
split against the nine men named in it (Cal, Cam, Jonah, Malcolm, Noel, Omar, Peter, Sacha and the transient
guests), whose bodies wear the male base.

## 2. Measured

Lane runs on the pinned engine. Receipts are in **C:/ov/reports/npc_pilot_20261123/stair_rate**:

- CompileChangedScripts on the three changed scripts: PASS.
- NpcPilotGenericGaitTest: 18/0. Malcolm's level walk never plays below 0.50x. On the stair he slows to 0.333x and
  his rate follows the stair floor in every frame. Evelyn keeps 0.50x on the same stair.
- NpcPilotWalkingFeetTest on Malcolm, Omar, Cam, Sacha and Evelyn: 42/0.
- CastResidentTest: 29/0. CastClipPresentationTest: 43/0.

Omar's contact slip in the windowed shot, median, in m/s:

| | Flat | Up | Down |
|---|---|---|---|
| Batch three, before | 0.042 | 0.247 | 0.248 |
| Stair rate | 0.042 | 0.026 | 0.023 |

By eye: in batch three, every tread carries a long slide mark under Omar. With the stair rate the marks shrink to
the point where each foot lands. As the ruling expected, his stride is slower and heavier on the stairs. Going down,
the back leg also stays raised behind him for longer, so the lowest foot sits higher over the treads (median 0.116 m
against 0.081 m before).

Codex's read-only review of 9c710e09e measured the same tradeoff at p90: Omar's descent sink p90 moved from
-0.027 m to -0.088 m, with clearer gaps under the advancing foot, while the median contact slip fell from 0.248 to
0.023 m/s. Its evidence is in **D:/ov_reports/npc_stair_rate_readonly_intake_20261125**. The change merged to main in
PR 571.

## 3. What is left

- **House walks.** OrisonV2ResidentWalkTest with the men on the house stairs, run once on Codex's clean composition.
- **The back-swing.** Open, as accepted for now. It shows more clearly on the men going down at the slower rate.
