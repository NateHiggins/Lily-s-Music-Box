# T1 contradiction fixture (synthetic)

Covers `T1_A` and `T1_B`.

## Object and architecture verdicts

| Room | Element | Verdict | Reason |
|---|---|---|---|
| A | `a_counter` | REMOVE | Should be gone but is not. |
| A | `a_counter` | KEEP | Conflicting row on purpose. |
| B | `a_chair_90` | KEEP | Wrong room on purpose: it lives in T1_A. |
| A | `vanished_thing` | KEEP | Never existed; a kept object that vanished. |
