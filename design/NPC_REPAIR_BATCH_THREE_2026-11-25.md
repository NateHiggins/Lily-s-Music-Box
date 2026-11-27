# NPC repair, batch three: the last six residents, 2026-11-25

Evidence class: **INERT**. This is a batch report: who joined, what was measured, and what stays open. It is not
acceptance. The captures it cites are review evidence only.

Work order **w3473eaaf58a9**, continuing under Lily's ruling **npc_feet_descent_backswing_20261124** ("widen to
more residents"). It follows **design/NPC_REPAIR_BATCH_TWO_2026-11-24.md**. Lily asked for cast work next on
2026-11-25. All text here is a first draft.

## 1. Who joins

Cam Ortiz, Iris Bell, Mae Kessler, Nadia Quell, Omar Bell and Sacha Reed join both gates in animated_resident.gd,
**FEET_PILOT** and **GAIT_PILOT**. All eighteen regular residents are now in both gates.

Omar was the tests' outside witness. Following Codex's route intake (FINAL_CAST_ROUTE_INTAKE.json, outside the
repo), the witness is now Adela Voss's rebuilt body. She is staff, not a resident, and stays outside both gates. The
tests mount her real rebuilt rig through the CastBodies test override and check that it loaded. Neither her schedule
nor her animation changes.

## 2. Measured

NpcPilotWalkingFeetTest (`RESIDENTS=cam_ortiz,iris_bell,mae_kessler,nadia_quell,omar_bell,sacha_reed`) gives the
deepest heel or toe joint below the tread on a stair of the house's dimensions, in metres. Negative is above the
tread. Crowded is the same climb past a player body and a loose crate:

| Resident | Off median | Off p90 | On median | On p90 | Crowded hover p90 (clear) |
|---|---|---|---|---|---|
| Cam | 0.178 | 0.284 | -0.057 | -0.029 | 0.092 (0.092) |
| Iris | 0.174 | 0.285 | -0.056 | -0.028 | 0.084 (0.083) |
| Mae | 0.177 | 0.286 | -0.054 | -0.023 | 0.093 (0.092) |
| Nadia | 0.174 | 0.285 | -0.055 | -0.028 | 0.085 (0.084) |
| Omar | 0.171 | 0.282 | -0.060 | -0.029 | 0.096 (0.097) |
| Sacha | 0.188 | 0.296 | -0.059 | -0.028 | 0.095 (0.093) |

On the level every resident's largest correction is 0.000 m. The stage measured 41–44 microseconds a frame per
walking body, against 89–97 in batch two under machine load. The limit is 250.

The windowed shot (NpcPilotMinaShot, `RESIDENT=`) gives contact slip with both gates on, in m/s, median:

| Resident | Flat | Up | Down |
|---|---|---|---|
| Mae | 0.086 | 0.180 | 0.180 |
| Omar | 0.042 | 0.247 | 0.248 |

By eye:

- **Mae, down.** One foot lands on each tread, with short marks on the tread tops. Her raised heel shows through
  the back of the skirt on the high back-swing, as with Malcolm and Lena, which Lily accepted for now.
- **Omar, up.** His feet land on the treads. His apron swings clear of the leg on the high steps.
- **Omar's stair slip.** Like the other men, he sits at the 0.5x rate floor going down, so his feet keep some slide.
  This is now a ruling for Lily, **npc_male_stair_slide_20261125**.

Evidence is in **C:/ov/reports/npc_pilot_20261123/batch3** (outside the repo): the `<resident>_gait` captures, the
tiled `_up` and `_down` strips, and the test receipts.

## 3. Lane runs

One batch on the pinned engine, after two imports of the refreshed worktree. Receipts are in the batch folder:

- CompileChangedScripts on the three changed scripts: PASS.
- NpcPilotWalkingFeetTest on the batch: 50/0.
- NpcPilotGenericGaitTest: 12/0, with Adela as the outside witness. It was rerun once after renaming one check
  label; both receipts are kept.
- CastResidentTest: 29/0.
- CastClipPresentationTest: 43/0.

## 4. What is left

- **House walks.** OrisonV2ResidentWalkTest for all three batches, run once on Codex's clean composition.
- **Male-base stair slide.** Waiting on **npc_male_stair_slide_20261125**.
- **The back-swing.** Open, as accepted for now.
- **Cost.** About 40–90 microseconds a frame per walking body. It is not yet on the performance matrix.
