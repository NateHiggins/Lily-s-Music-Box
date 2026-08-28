# Lint draft fixture (synthetic)

Covers `T1_A` and `T1_B`.

## Object and architecture verdicts

| Room | Element | Verdict | Reason |
|---|---|---|---|
| A | `a_counter` | KEEP | Exact id, machine-checkable. |
| A | `a_chair_9` | KEEP | One prefix match exists. |
| A | `a_chair` | KEEP | Two prefix matches exist. |
| A | `chair` | REMOVE | Assembly kind mistaken for an id. |
| A | `RuntimePropX` | KEEP | Runtime-source identifier. |
| A | mystery gadget nonsense | KEEP | Unknown prose. |
| A | `a_rug` | MOVE | No machine-readable target supplied. |
| A | `a_counter` | REPAIR | No checkable property named. |
| A | `a_counter` scuffed edge [visual] | REPAIR | Explicit visual verification. |
| A | `old_x` replacement pending | REPLACE | Missing the replacement side. |
| A | `a_box1` -> `a_newbox` | REPLACE | Old present, replacement proposed. |
| A | `a_box2` (`chair`) | ADD | Proposed id already exists. |
| A | `a_new_chair9` (`chair`) | ADD | Fresh proposed id with type. |
| A | walls, floor and ceiling | KEEP | Architectural envelope prose. |
| B | west corner oddment [manual] | KEEP | Declared manual verification. |
| A | `long_gone` | KEEP ABSENT | Absence is checkable as written. |
| A | the gizmometer device | KEEP | Phrase resolving to one record. |
| A | seating chair | KEEP | Phrase resolving to two records. |
