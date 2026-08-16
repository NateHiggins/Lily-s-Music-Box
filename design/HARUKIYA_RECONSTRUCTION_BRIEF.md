# THE HARUKIYA REBUILD — audit findings and the decisions that gate it

**PROPOSAL — OWNER REVIEW REQUIRED — NOT YET BINDING CANON.**
Owner commission 2026-08-16: do for the bar what the arcade got — much
larger and taller, a generous stair procession, a dense Akira-style
detritus diorama on the stair and landing, a decompressed couch/jukebox
pocket, real sub-zones, back-of-house, ceiling architecture, layered
light, traces of use and subtle unease.

A ten-agent audit surveyed the room, the stair, the social pocket, the
gameplay wiring, the envelope and the identity ledger, produced a
fourteen-phase plan, and then attacked it from three sides. **Two of the
three adversarial lenses returned UNSOUND, with eighteen blockers.** This
document records what the audit proved, so the analysis is not lost, and
states the decisions that must land before anything is built.

---

## 1. The finding that reshapes the commission

> **The footprint essentially cannot grow. Total plan gain available is
> +3.88 m², or +2.7%.**

The bar sits inside a fixed canon mass — the block `nbr_s2` at
x −12.0..6.4, y −38.2..−28.32 — and the rebuild may only reach the inside
faces of that box. This must be said out loud in any conversation about
"substantially larger", because the honest answer to the first objective
is that the *plan* cannot deliver it.

**But the section can.** The block above the bar is currently solid
generated brick (`retail_bar_fill_w0`, 3.55 m of it) and that fabric is
the bar's own — it is free to stop being generated. Reclaiming it turns
one flat lid into three heights:

| zone | clear height | why |
|---|---|---|
| counter, lounge, west bay, stage | 2.65 m | the canonical low ceiling, kept exactly |
| middle field | 3.90 m | release, as you step off the counter |
| **the well** over the table floor | **5.17 m** | two storeys, open to a new upper light |

Measured volume: **556 m³ against 377.9 m³ today — +47%.** The room
becomes dramatically larger by growing *upward into the building*, while
the counter you actually drink at stays as low and close as the evidence
demands. That is compression and release, which the commission asked for
by name, and it is the only route the geometry allows.

The hard stop overhead is `site_nbr_s2_soffit` at z 3.33 — structural,
emitted by `site_pass`, not ours. The street-cull gate is stricter still:
whole-AABB and strict-inequality, so the well's slab may reach z 2.80
exactly and no further.

## 2. What the audit found that nobody was looking for

- **The red door is not red.** `F01_BAR_RED_DOOR` resolves to
  `exterior_service`, and `DoorProp._build_service()` painted every such
  leaf galvanized grey while ignoring `finish_variant` entirely. The
  canonical requirement is "battered painted red steel", and Otomo's
  teal-offset-by-red is named as *the* staircase composition — so the
  single warmest note at the foot of the teal descent has been missing
  since the descent was built. No test caught it because no test asserts
  a colour. **Fixed 2026-08-16** (variant 1, oxblood enamel gone chalky).
- **The room has no `rooms` records at all**, which is why it is invisible
  to the movement validator, ResidentNav, RoomLumaAudit, per-room fixture
  mapping and the whole wear system. Adding them is the highest-leverage
  structural change available — and would fail the build four separate
  ways today (see §4).
- **Seven merged buffers already fail the street-cull gate**, including
  the entire room floor, because the gate tests whole AABBs and the shell
  rects are *derived* (`RX0 − 0.30`) rather than authored.
- **The arcade cabinets are not arcade machines.** They are receivers —
  Bakelite carcass, brass bezel, long-persistence scope — because "there
  is no arcade in this world". Two, variants 0 and 1, in that order.
- **The bar tells the player its history in the wrong century**: "this
  block in 1948", "the bar under its first name, 1962", and three jukebox
  tracks dated 1999–2008 in a 1928 room.

## 3. What is frozen

Sixteen items the audit ruled untouchable, the load-bearing ones being:
the counter canopy at z −1.04 (1.76 m clear — *this*, not the ceiling, is
the canonical "huge low canopy"); the violet-felt pool table, which is
also a live test anchor for four rail sweeps; the teal descent's 0.30 m
lining, which must own its skin; the red steel door; the two receivers
immediately left of the entrance; the rope-bound sake barrels and the
22-frame gallery; light only from something you can point at; the floor
datum FLR −2.80 with the schedule's `harukiya_bar` anchor on it; and a
long list of literal identifiers the engine looks up by name.

## 4. Why the plan is not buildable yet — eighteen blockers

Highlights, all with file:line evidence in the run transcript:

- **Four separate hard build failures** from one edit: adding `rooms`
  records trips `validate()`'s footprint guard (the bar is at y −38..−28,
  the guard admits ±10), `_validate_ceilings`, `RoomLumaAudit`'s storey
  datum, and silently manufactures light markers via `ROOM_FIXTURE`.
- **Two cast-iron columns pass through the frozen pool table.**
- **The raised deck and the counter occupy the same 0.75 m.**
- **The ground plane is not cut over the room** — `GROUND_HOLES` has three
  entries and the bar is not one, so the asphalt sheet sits below both
  new soffits.
- **The stair's reserved lane is 0.70 m** against a 0.66 m player capsule,
  before handrails; it needs 1.10 m.
- **One blocker was already stale when written**: the lighting phase
  assumed a 16-light budget, and the budget became 64 while the audit was
  running.

None of these are reasons to abandon the plan. They are the reason to
revise it before cutting geometry, which is precisely what the
adversarial pass is for.

## 5. The decisions that gate the build

Twelve rulings came back. These four block phases directly:

1. **Is the Harukiya Japanese-run, or Japanese-named and inherited?** No
   document in the repo states it. The Music Bible gives a proprietor and
   a mother who sang Yoshii's Japanese text, but that document is itself
   still a proposal.
2. **The Japanese share of an enlarged room.** Today it is three things:
   the kanji board, the chochin, and two sake barrels. Add 178 m³, a
   coffered ceiling, a mirrored backbar, cast-iron columns and a tin
   field, and that share falls toward zero *without anyone deciding to
   remove anything* — the identity erased by arithmetic rather than by a
   decision. The identity reviewer's verdict was that the plan named this
   risk and then committed it in every phase. **This must be answered
   before the counter and ceiling phases, not alongside them.**
3. **The low ceiling.** The 2.65 m figure is filed INFERRED, not
   canonical; the canonical low element is the 1.76 m counter canopy. The
   proposal keeps 2.65 m over the counter, lounge, west bay and stage and
   opens only the middle. Does that satisfy "the low ceiling" as canon?
4. **Does the entrance move to the south-east corner?** A 16-riser
   procession with a half-landing needs 8.98 m of the shaft's 9.28 m,
   which puts the red door where the reference drawings always had it —
   but it moves a canonical object.

The remaining eight, recorded for later: who owns this room's fiction;
whether the consultation gate applies to blockout or only to shipping;
the second-hand-grandeur route (a tenant fitting out from a closed hotel
bar, which is how mahogany and a leaded mirror legitimately reach a
Queens basement in 1928); the 1948/1962 photographs; the jukebox
catalogue's dates; whether the room gets `rooms` records and a light
switch; reconciling the reference notes' stale contemporary-fiction
section; and whether the red-door fix needed a ruling at all (it did
not — canon was explicit and the code disagreed with it).

## 6. Standing decisions already made

- **B1, owner ruling 2026-08-16:** the stair widens from 1.15 m to
  roughly 1.6 m — two people pass, which reads generous *relative to the
  film* — and the descent stays tight and dense. Compression is the
  arrival; release happens when the room opens. Filed as NYC ADAPTATION,
  with the 2026-08-07 precedent that already took the room 6.8 → 9.2 m
  deep under that heading.
