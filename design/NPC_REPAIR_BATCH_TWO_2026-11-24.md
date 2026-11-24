# NPC repair, batch two: six more residents, 2026-11-24

Evidence class: **INERT**. This is a batch report: the residents added, the measurement on each, and what stays
open. It is not acceptance. The captures it cites are review evidence only.

Work order **w3473eaaf58a9**, continuing under Lily's ruling **npc_feet_descent_backswing_20261124** (widen foot
placement to more residents, revisit the back-swing later). It builds on
**design/NPC_REPAIR_BATCH_ONE_2026-11-24.md**. All text here is a first draft.

## 1. Who joins

Three more residents from each cast body base:

- **Female base:** Lena Ortiz, Juno Kells and Rhea Sato.
- **Male base:** Cal Dwyer, Jonah Price and the transient guests. The transient guests are one resident on the
  route who wears `transient_guests_a`, so this batch also covers a resident whose cast person has another name.

They join both gates in animated_resident.gd, **FEET_PILOT** and **GAIT_PILOT**, as batch one did. That makes twelve
of the eighteen residents. Omar Bell stays outside both gates as the tests' witness. Six residents remain: Omar,
Cam Ortiz, Nadia Quell, Iris Bell, Sacha Reed and Mae Kessler.

## 2. Measured

NpcPilotWalkingFeetTest (`RESIDENTS=lena_ortiz,juno_kells,rhea_sato,cal_dwyer,jonah_price,transient_guests`) gives
the deepest heel or toe joint below the tread on a stair of the house's dimensions, in metres. Negative is above the
tread:

| Resident | Off median | Off p90 | On median | On p90 | Crowded hover p90 |
|---|---|---|---|---|---|
| Lena | 0.177 | 0.290 | -0.054 | -0.024 | 0.088 |
| Juno | 0.177 | 0.280 | -0.056 | -0.029 | 0.087 |
| Rhea | 0.166 | 0.275 | -0.054 | -0.025 | 0.085 |
| Cal | 0.184 | 0.297 | -0.062 | -0.029 | 0.102 |
| Jonah | 0.187 | 0.295 | -0.060 | -0.029 | 0.101 |
| Transient guests | 0.184 | 0.296 | -0.060 | -0.029 | 0.102 |

On the level every resident's largest correction is 0.000 m. The stage measured 89–97 microseconds a frame per
walking body under machine load, against 45–70 in batch one. The limit is 250.

The windowed shot (NpcPilotMinaShot, `RESIDENT=`) gives contact slip with both gates on, in m/s, median:

| Resident | Flat | Up | Down |
|---|---|---|---|
| Lena | 0.066 | 0.174 | 0.170 |
| Jonah | 0.046 | 0.293 | 0.272 |

By eye:

- **Lena, down.** One foot lands on each tread, with short marks on the tread tops. She has the same high
  back-swing as Malcolm, which Lily accepted for now.
- **Jonah, up.** His feet land on the treads, and his long coat folds over them.
- **Jonah's stair slip.** Like Malcolm and Noel, he sits at the 0.5x rate floor going down, so his feet keep some
  slide on the stairs.

Evidence is in **C:/ov/reports/npc_pilot_20261123/batch2** (outside the repo): the `<resident>_gait` captures, tiled
`_up` and `_down` strips, and the test receipts.

## 3. The crowded check

The producer's first run exited 1. Its lane transcript is preserved. A retry
reused the output names, so the original detailed contract and raw samples
are unavailable. The producer recalled excessive peaks for Juno and Rhea.
The retry raised the peak margin to 0.10 m.

Integration retained the original margins of 0.02 m at p90 and 0.03 m at
peak. It added a separate support check that samples the same 18 locations
before and after inserting both obstacles. The isolated Juno and Rhea
diagnostic passed 17 checks. Every fixed location read the tread with and
without obstacles. Crowded-minus-clear hover changes were +0.002 m p90
and -0.008 m peak for Juno, and 0.000 m p90 and -0.010 m peak for Rhea.
Those measurements cover the isolated diagnostic.

Final lane runs, receipts in the batch folder:

- NpcPilotWalkingFeetTest on the batch: 44/0.
- NpcPilotGenericGaitTest: PASS, with Omar as the outside witness.
- CastResidentTest: 24/0.
- CastClipPresentationTest: 43/0.

## 4. What is left

- **House walks.** OrisonV2ResidentWalkTest for this batch joins batch one's, run once on Codex's clean
  composition.
- **The last six.** Omar, Cam, Nadia, Iris, Sacha and Mae join in a final batch. The tests then need a witness
  outside the gates or no witness.
- **Male-base stair slide and the back-swing.** Both are open as in batch one.
- **Cost.** About 90 microseconds a frame per walking body under load. It is not yet on the performance matrix.
