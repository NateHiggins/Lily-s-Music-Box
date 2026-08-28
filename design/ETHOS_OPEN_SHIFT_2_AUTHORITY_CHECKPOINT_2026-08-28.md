# ETHOS-OPEN-SHIFT-2 — authority checkpoint (2026-08-28)

Status: **counterfeit consequences removed; systemic-authority gate
passes with zero Open Shift suppressions.** The radiator-specific human
visual gate remains accepted; Open Shift's overall human gate, M09/M10,
selector changes and production cutover remain unauthorized.
`BuildingRootSelector.DEFAULT_ID` is `"v1"` and untouched.

## What changed (ADMIN-ETHOS2)

Base: `codex/ethos-open-shift` tip `5ed8bf3` (includes the accepted
radiator rebuild `f572896`), plus the ADMIN-ETHOS1 audit tooling
(`dcc4a69`, cherry-picked).

### 1. Knowledge is now earned, never authored

`OpenShiftSituation` can no longer record `npc_knowledge`,
`relationship_consequence` or `part_custody` — the whitelist rejects
them and the default record no longer carries them. A new observation
authority, `NpcObservationLedger`
(`game/scripts/reality/npc_observation_ledger.gd`, sole writer of
`RealityState.data.npc_observations`), records beliefs only through
concrete evidence routes, each with full provenance (who, learned,
channel, where, simulation minute, evidence):

- **Acoustic**: `AcousticGraphData.audibility(origin)` (new pure read
  over the cached propagation plan) decides who physically hears a
  riser sound. The heating riser from `F02_B_RADIATOR_01` reaches 2B
  and **3B** — so the neighbor who hears the hammer is `omar_bell`
  (3B), not the previously asserted "2c_neighbor", which the acoustic
  fabric never supported. The evidence route corrected the fiction.
- **Sight**: residents learn in-flat changes (tool marks, open union,
  porter tag) only while present.
- **Direct inspection**: the porter's own knowledge comes from his own
  arrival and inspection.

The coordinator emits neutral world events and records situation
observation facts; it never decides their social interpretation.

### 2. The porter is an actor

`PorterActor` (`game/scripts/characters/porter_actor.gd`, sole writer
of `RealityState.data.porter_actor`): intention (`riser_complaint`),
source (`F01_WATCH`), dispatch delay (finishes his board round), 4
simulation minutes of off-screen transit, an access check on 2B,
arrival + inspection (his own observation), then the shutoff performed
through the mechanism's own API and the porter tag the radiator itself
shows. Elapsed time only makes him ELIGIBLE (`consider`); every later
phase derives deterministically from durable timestamps
(`advance_to(now)` is pure catch-up), so save/load, scene unload and
frame rate cannot pause, repeat or accelerate him. **If he cannot
reach 2B he is turned away, records that honestly
(`compensation: attempted_but_no_access`), and the intervention does
not occur.** A player repair stands him down (`cancel`).

### 3. Packing custody is singular

`"player_has_radiator_packing"` no longer exists. The packing is
`radiator_packing_2b` in `MaintenanceInventory`; `RadiatorProp`
derives `packing_location()` — `radiator` / `player` / `consumed` —
from the inventory alone. Pickup happens through the union surface
when the union is open (prompt "Remove radiator packing"); repair
consumes carried packing; a consumed packing blocks any further
repair; the situation record carries no custody fact at all.

### 4. Consequences from mechanisms, boundaries from evidence

- The mechanism owns its degradation: `RadiatorProp.apply_neglect()`
  worsens an unrepaired air-bound fault after 5 neglected minutes.
- The abandonment boundary is **derived** from attested state (the
  prop's condition, the inventory's custody, the recorded attention),
  never declared; `abandon_after` and `meddle_wrong_valve` are
  deleted. Meddling is the `turn_valve` surface doing what it always
  did — the ecosystem merely observes the attested outcome.
- Residue writes go through `OpenShiftSituation.merge_residue()`; the
  raw-record bypass (`_record_mutable`) is gone.
- Without an injected clock, the situation's own durable simulation
  minutes are the clock (`_minute_now` falls back to
  `180 + elapsed`), so production timestamps are meaningful and
  reconstruct deterministically. The ecosystem lives at the waking
  root — simulation time accrues regardless of which rooms are loaded
  or where the player stands.

### 5. Tests drive public surfaces

WORK / IGNORE / ABANDON / MEDDLE and the save matrix now run through
the seven interaction surfaces, WorkOrders' public API, the porter's
own timeline and injected simulation minutes. A new
`OpenShiftAuthorityTest` proves: knowledge absent before observation;
two observers deriving different beliefs from different evidence;
an unreachable porter not acting; delayed off-screen determinism;
single-custodian packing; save/load mid-transit preserving the actor's
timeline; and room unload/reload neither pausing nor repeating a
consequence.

## Audit result

Before (fresh scan of the unmodified tip against the main baseline):
**exit 1 — 14 Open Shift findings, 10 actionable STRONG.** After:
**exit 0 — zero actionable, zero Open Shift baseline suppressions.**
Per-finding dispositions are in
`design/ETHOS_OPEN_SHIFT_2_AUDIT_DELTA_2026-08-28.md`.

## Validation receipt (full battery, this worktree)

1. `OpenShiftAuthorityTest` 21/21 PASS (all eight authority proofs).
2. `OpenShiftWorkTest` PASS (public surfaces + commit-gating proof).
3. `OpenShiftIgnoreTest` PASS (mechanism degradation, acoustic route,
   porter phase timeline, single-application reconstruction).
4. `OpenShiftAbandonTest` PASS (five boundaries derived, distinct
   evidence, sight-earned resident belief).
5. `OpenShiftMeddleTest` PASS (turn_valve surface, earned observers).
6. `OpenShiftSituationTest` PASS (whitelist rejections, merge_residue,
   clockless simulation-minute timestamps).
7. `OpenShiftSaveMatrixTest` 17/17 PASS (4 dispositions x 4 root
   directions, porter facts + belief provenance compared).
8. `RadiatorPropRebuildTest` 20/20 PASS (accepted model intact).
9. `MaintenanceServiceRoundTest` PASS; `MaintenanceActivityTest` PASS.
10. `orison_v2_m08f_runtime_test` 29/29 PASS (byte-stable production
    layout, v1 selector, in-test 0-retention assertions).
11. `RealitySaveCompatTest` 14/14 PASS.
12. `orison_v2_two_root_matrix_test` 24 checks PASS, exit 0 (all four
    reconstruction directions; global-state restoration).
13. Systemic situation-authority audit: exit 0, zero Open Shift
    suppressions. 14. Its 34 self-tests: PASS.
Also: spatial dependency audit exit 0 after a deliberate manifest
update classifying the seven new porter/ecosystem references (plus two
`F02_B_RADIATOR_MASS/USE` records the accepted `f572896` rebuild had
left unclassified); its 48 self-tests PASS. Prompt-carrier audit
reports only the pre-existing `clock_prop.gd` "Hold E" debt (owned by
the K2 stream; not an Open Shift surface) — no new carrier debt.
Pre-existing, unchanged: a 4-ObjectDB-instance exit-time warning under
`run_godot_serial.ps1` on the M08F suite that reproduces byte-for-byte
on the unmodified branch tip (A/B verified) and does not appear in
direct runs; the in-test retention assertions pass in both.

## Preserved

All four dispositions remain distinct with their authored residue
vocabularies; the accepted radiator model, its seven surfaces, service
clearances, fault states, porter tag and repair consequences are
unchanged in presentation; no objectives, tutorial language, forced
acceptance or moral score anywhere; the production layout is
byte-stable and the selector default is v1.

## Remaining honest debts

- The porter exists as durable actor state and events — still no
  navigation/animation body (unchanged from ETHOS-OPEN-SHIFT-1's
  admission); his transit is credible off-screen time, not a walked
  route.
- Resident presence uses an assume-home default until a schedule
  provider is bound (`NpcObservationLedger.setup(presence)`).
- The audit's `AUTONOMY_DEPENDS_ON_PROXIMITY` heuristic still flags
  the ecosystem's `_process` (REVIEW): simulation minutes accrue only
  while the waking root runs. That is the game's definition of time
  passing, and all consequences catch up deterministically from
  durable facts — documented, not suppressed.
- Open Shift's OVERALL human gate remains pending the four-session
  card; nothing here authorizes M09/M10 or a selector change.
