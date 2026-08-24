# DT-5 — CANONICAL SIX-BEAT SEQUENCE

One procedural limb, one production `OrisonRoot`, one fixed gameplay camera
and the player's real lamp carry the complete animation without replacing the
state machine or forcing presentation poses. The harness supplies only the two
inputs ordinary play supplies: the player enters arm's reach, then the
encounter eventually asks the limb to withdraw.

## Production proof

[`contact_sheet.png`](contact_sheet.png) records the complete sequence:

1. `01_BULGE_pressure` — the intact wall tightens and gains local volume.
2. `02_EMERGENCE_release` — the chosen soft spot progressively releases the
   club and weighted limb.
3. `03_SEEK_candidate` — the distal club tests a synapse-like candidate cleft.
4. `04_CARESS_hover` — the club holds off the radiator before contact.
5. `05_CARESS_exchange` — the vascular bolus and contact organ flare at the
   electrochemical handoff.
6. `06_CARESS_secretion` — sequentially engaged suckers stabilize secretion
   transfer into the shared LivingField.
7. `07_FLINCH_distal_first` — arm's-reach proximity releases contact and
   contracts the distal limb before the heavy root: surprise, not attack.
8. `08_FLINCH_curiosity_wins` — the creature reorients to watch the player.
9. `09_WITHDRAW_gripped` — the membrane grips the shortening anatomy.
10. `10_WITHDRAW_last_cilia` — only the ocular/distal anatomy remains.
11. `11_WITHDRAW_sealed` — the conventional hole never exists; the membrane
    is sealed and the transformed material remains.

The production harness logged every landmark true in the single 53.7-second
Forward+ run. `Z_control_a/b` is a frozen identical sealed-state A/A pair with
normalized full-frame RMSE **0.00000913426**.

## Contract

The production `DreamTentacleTest.tscn` remains **27/27**, including the
independent emergence and synaptic behavior sweeps, contact conversion,
player flinch, withdrawal and the **0.644 ms/frame** controller cost. The
focused component proofs remain at `dt5_field_pressure`, `dt5_bobbing`, and
`dt5_synaptic_seek` beside this directory.

This closes DT-5's rendered BULGE → EMERGENCE → SEEK → CARESS → FLINCH
→ WITHDRAW requirement. It does not close DT-6's broader hero-read review
and does not claim a completed waking case loop.
