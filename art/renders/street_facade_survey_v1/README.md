# Street facade survey v1 — 2026-08-16

Eight fixed production-night stations around the arcade gate and the STREET
play-area perimeter, shot by `game/tests/gateway_shot.gd` (committed as the
permanent rig so before/after pairs stay comparable). Evidence base for
`design/STREET_WALL_PROPOSAL.md`; findings A–E in that document cite these
frames by number.

| frame | station | finds |
|---|---|---|
| 01_gate_head_on | carriageway, square to the portal | A |
| 02_gate_oblique_west | pavement west of the gate | A, B |
| 03_south_frontage_wide | mid-street toward the gate | C |
| 04_from_gate_to_orison | the north-side CONTROL — the standard to meet | — |
| 05_east_end_join | kiosk/hoarding/backdrop junction | A, C |
| 06_west_end_join | west stage end | C, D, E |
| 07_high_oblique | elevated three-quarter over the play area | D |
| 08_pavement_east_sweep | along the south pavement from the east | B, D |

Rerun: `SHOT_DIR=<abs> godot --path game res://tests/GatewayShot.tscn`
(real window, no --headless).
