# T1 test checkpoint (synthetic fixture)

## Room profiles

### `T1_A`

Test office room.

### `T1_B`

Test storage room.

## Object and architecture verdicts

| Room | Element | Verdict | Reason |
|---|---|---|---|
| A | walls, floor and `a_counter` work counter | KEEP | Still the primary station. |
| A | `a_chair_90`, `a_chair_45` | KEEP | Seating pair. |
| A | `a_box1..2` crate row | KEEP | Range-expanded family. |
| A | `a_ghost` | REMOVE | Retired placeholder. |
| A | `chair` | REMOVE | Names an assembly kind, not an id. |
| A | `a_gone_*` | REMOVE | Retired glob family. |
| A | `a_ghost2` | KEEP ABSENT | Stays gone. |
| A | prose-only station with no id | KEEP | Not machine-addressable. |
| A | `x_stoop` | KEEP | Facade dressing outside every room rect. |
| A | `a_rug` | MOVE | No machine-readable target here. |
| A | `a_counter_clutter` | REPAIR | Visual repair, no layout property. |
| A | `old_thing` -> `new_thing` | REPLACE | Neither exists yet. |
| B | `b_cross` | KEEP | Boundary crosser stays. |
| B | `pipe_riser` | KEEP | Service pipe. |
| B | `b_new_lamp` | ADD | Not landed yet. |
