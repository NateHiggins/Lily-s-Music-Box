# ETHOS-OPEN-SHIFT-1 Checkpoint — 2026-08-28

## Authority map

`OpenShiftSituation` owns only durable observation, elapsed simulation,
commitment, compensation and residue facts. `OpenShiftRadiatorEcosystem`
coordinates the bounded 2B timing and listens to the existing service round.
`RadiatorProp` remains the sole writer of valve, vent, pitch and sound state.
`WorkOrders` remains the sole job lifecycle authority. `MaintenanceInventory`,
resident/case owners, `CoreLoopDirector`, and the building selector retain
their existing authorities. The selector is never serialized.

Production escalation is accumulated from Godot simulation delta into a
durable situation fact. Host wall-clock passage cannot advance the situation.
Harnesses inject a deterministic minute provider.

## Disposition traces

| Disposition | Physical continuation | Social continuation | Recoverable next state |
|---|---|---|---|
| WORK | vent seated; supply fully open | resident saw a visible patch | recurrence and dream/wake remain valid |
| IGNORE | hammer worsens; porter eventually shuts 2B heat off | neighbor hears it; resident knows porter arrived instead | reopen supply, diagnose and repair original fault |
| ABANDON | boundary-specific marks; an opened union hisses and runs partially shut | resident infers help began; porter may find evidence | finish, explain, replace material, or allow compensation |
| MEDDLE | wrong valve leaves uneven heat and a new riser hammer | neighbor hears the change and visible marks identify interference | restore balance, then diagnose original fault |

No disposition emits mission failure or advances a job on the player's behalf.
Porter compensation is delayed, imperfect, physical, evidenced by a valve tag,
and records that the original fault remains unrepaired.

## Save and presentation contract

All situation facts live under `RealityState.data.open_shift_situations` and
are additively backfilled for historical saves. The four-disposition matrix
covers v1→v1, v2→v2, v1→v2, and supported v2→v1 rollback. Root composition
disables the legacy ObjectiveTracker presentation while preserving the API and
job authority required by compatibility suites. Work paper, calls, sounds,
mechanism behavior and conversations remain diegetic surfaces.

## Remaining assumptions

- The competent route retains sequential mechanical dependencies inside the
  maintenance activity; this is causal apparatus order, not a global quest.
- The existing 2B job requires no purchased replacement. “Took part” is
  represented as custody of service packing/material, not a mutation of the
  canonical job definition; a production pickup surface remains a future
  diegetic-detail improvement.
- Full NPC navigation animation for the porter is not authored in this slice.
  Existing complaint/service authority supplies the delay and action; the
  physical shutoff, tag, knowledge and relationship residue are durable.
- Human intentionality and readability remain pending the four-session card.

Production cutover and M09 remain unauthorized. `DEFAULT_ID` remains `v1`.

## Validation receipt

- Four dispositions: WORK 13/13, IGNORE 8/8, ABANDON 13/13, MEDDLE 6/6.
- Save matrix: 17/17 (four dispositions × four root directions, plus v1
  committed default); zero retained ObjectDB instances/resources.
- Situation contract: 8/8. Service round: 13/13. Save compatibility: 14/14.
- Dream/service production answer: PASS. Completeness unit suite: 64/64.
- Evidence capture: 4/4 at 1280×720; production-v2 composition startup was
  772.586 ms cold in the capture run. No GPU gameplay timing is inferred.
- First-slice scope exit 0. Golden-shift scope remains exit 2 on the deliberately
  unperformed human eleven-beat M10 proof. Production-cutover scope remains
  exit 2 with 95 wider-building blockers.
- Spatial dependency audit: clean, exit 0. Production layout blob remains
  `8a7ffeb649d82d09e30f6002964fb2c7b38de353` (SHA-256
  `68838c933c0954092c63403f36ec7fb26d6c0956c01c23109465c680608b399d`).
- The repository-wide prompt-carrier audit remains exit 5 on pre-existing
  baseline debt (including `clock_prop.gd` and fixture findings); this slice
  introduces no new prompt method or carrier. That audit is not silently
  characterized as clean.
