# Resident home-door passage

Evidence class: **INERT**. Isolated physics/input diagnostics and suite wrappers; no runtime-contract admission.

The unchanged full-building F06 replay goes from 18/19 (leaf collision at step 442) to 19/19 (1464 steps to the lift waiting point). The authored production departure is identical before and after. Both physical replays exclude zero colliders.

The separate DoorProp/ResidentRoutines fixture passes 134/134 across translated, rotated and opposite-swing setups: all five route callers wait and idle, actual departure and return clear the body capsule, closing happens behind the resident, locks remain authoritative, rejected requests retry, and private worlds retire.

Full stderr is preserved. The isolated fixture still reports nine ObjectDB instances and three resources at process teardown. These passed assertions do not constitute a clean-teardown or whole-V2 verdict.

This phase covers home apartment entries. The next extension handles actual non-home door crossings and shares occupancy checks for closing. See **design/astra/RESIDENT_HOME_DOOR_2026-09-19.md**.
