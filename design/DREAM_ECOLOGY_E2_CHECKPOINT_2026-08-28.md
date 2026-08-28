# DREAM-ECOLOGY-E2 checkpoint — 2026-08-28

Start: `9969beea6334a8fc19c886ef2acb20ea48c31741` (`origin/main`). This checkpoint adds a bounded presentation consumer to the E1 moss authority; it does not add ecology, ether, field, stain, case, save, or narrative authority.

## Gate-zero timeout diagnosis

Both production harnesses were run through `tools/run_godot_serial.ps1` with a bounded 60-second ceiling and exited normally. Neither is hung or mutex-contended.

| Harness | Measured wall interval | Verdict |
|---|---:|---|
| `DreamTentacleTest` | about 42 s | PASS 28/28. Production-root construction plus authored emergence/contact/withdrawal timers exceed the former 30-second wrapper. Teardown now frees the production root and waits three frames; the final run has no retained-instance/resource report. |
| `OrganismIncidentsTest` | about 34 s | PASS 18/18. Production-root construction and the authored incident/fix/cooldown sequence exceed 30 seconds; normal clean exit. |

The honest wrapper ceiling for both is 60 seconds. No foreign Godot process was terminated.

## Presentation ownership and bindings

`DreamMossColonyRenderer` is one presentation owner per E1 colony. It reads colony phase, routes, concentration, organism records, and reports. It owns six nodes total and no simulation state. A heart mesh, bounded vascular `ImmediateMesh`, cilia `MultiMesh`, ether `MultiMesh`, and one report pulse communicate searching, seed commitment, tending, mature local atmosphere, reinforcement/pruning, recall, withering, stain, and cleanup.

`ApartmentEncroachment` creates the renderer beside each colony, sends the value from the real typed cilium report into the visual return pulse, and refuses production tentacles when E1 support/spawn facts refuse them. `DreamTentacleController` maps the existing rig to ecological purpose, drains through `update_excursion`, returns on low support/load, reports on arrival, and senesces at its actual unsupported location. Its spline root is now embedded 0.092 m behind the measured flat support plane while the membrane remains flush on the plane; the first cubic segment exits along the surface normal, eliminating the hovering/placed-prop root.

The existing critter presentation consults the E1 `complex_unlocked` gate when attached to production ecology. It starts in supported atmosphere, reports excursion support, pauses to return, and loses vigor when senescent. Standalone fauna contracts retain their existing bounded controller behavior.

Disturbance presentation follows only the E1 ordered phases. The renderer folds cilia, drains motes and peripheral routes, collapses/desaturates the heart, and presents E1 stain impressions. Authorized cleanup in the evidence calls the public colony cleanup fact after the existing incident/LivingField path has demonstrated persistent repellent stain; no save or case facts are written.

## Bounds and measured cost

- 6 presentation nodes per colony.
- 64 branch segments, 8 visible cilia, and 24 ether motes maximum.
- 33 peak visible presentation elements in the final lifecycle receipt.
- Presentation update: 0.0021 ms average over 300 direct refreshes in the deterministic shot.
- LivingField: 2.90 ms/tick at 15,680 voxels and 512 agents, under its 6 ms budget.
- Cellular audio remains capped at four voices (`DreamCellularAudioTest` PASS 9/9).
- Tentacle frame cost: 0.649 ms, under its 1.2 ms contract.

## Regression receipt

| Suite | Result |
|---|---|
| DreamMossPresentation | PASS 16/16 |
| DreamMossEcology | PASS 26/26 |
| LivingField | PASS 24/24 |
| DreamOrganelleLifecycle | PASS 16/16 |
| DreamCellularAudio | PASS 9/9 |
| DreamFaunaLifecycle | PASS 34/34 |
| DreamMarginLifecycle | PASS 61/61 |
| DreamEncounterLifecycle | PASS 24/24 |
| DreamMicrobiologyEncounter | PASS 12/12 |
| DreamTentacle production harness | PASS 28/28 |
| OrganismIncidents production harness | PASS 18/18 |
| DreamEcology legacy integration | FAIL 29/33 |
| deterministic 13-frame capture | PASS 13/13, normal exit in 13.343 s |

The legacy `DreamEcologyTest` failure is an explicit compatibility debt, not hidden: its four failing assertions require two fauna to exist immediately in a freshly seeded ecology. E2 now correctly keeps complex fauna at zero until the E1 maturity/ether/diversity/route gate passes. The focused E2 contract proves the gate, while the older integration fixture still needs a public-fact mature-colony setup before exercising fauna-wide attention and contact assertions.

## Thirteen-stage evidence

Final inspected evidence: `art/renders/dream_ecology_e2/2026-08-28/lifecycle_07/`.

The directory contains all thirteen 1280×720 production-backed frames, `capture_receipt.json`, `lifecycle_timeline.json`, and `contact_sheet.png`. The timeline records phase/reason transitions, maturity, ether volume, counts by class, report presentation count, information diversity, reinforced/pruned routes, excursion ether minimum, 2 recalled versus 1 stranded organism, 3.2 seconds disturbance-to-stain, stain coverage 5.32 before and 0.0 after cleanup, node/element peaks, and presentation CPU. Final renderer census reports no visible heart, cilia, ether, or pulse after authorized cleanup.

## Remaining limitations

- Palpator and vibration-listener distinctions are proven with the current shared rig. Ocular, sucker, manipulator, and relay purposes alter supported behavior parameters, but bespoke silhouettes/anatomy remain presentation debt; no rigs were duplicated to imply otherwise.
- Frame 8 proves the real E1 complex record/gate and supported atmosphere, but does not yet show a fully readable production fauna body. The legacy integration fixture also needs migration as recorded above.
- Production incident removal proves `OrganismIncidents -> LivingField.repel` persistence. The deterministic sheet uses the colony's public authorized cleanup operation to make the cleaned control; a player-facing maintenance action that bridges that operation is still future work.
- The shot accelerates public lifecycle facts. It does not serialize transient organism nodes.

Accordingly, the bounded moss/cilia/tentacle lifecycle and collapse are behaviorally and visually proven for the supported subset. The complete six-purpose morphology and readable complex-fauna stage are not yet fully proven.
