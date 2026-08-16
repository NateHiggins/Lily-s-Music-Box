# The Harukiya rebuild — built phases

Owner commission 2026-08-16. Audit and gating decisions:
`design/HARUKIYA_RECONSTRUCTION_BRIEF.md`. Canon amendments that made
the work possible: `docs/harukiya_reference_notes.md` §0.

## B1 — the descent widens (`b1_stair/`)

1.15 m → **1.60 m clear**, per the owner's ruling: two people pass,
which reads generous against the film while staying tight by any other
measure. The ledger's "never generous" survives as the descent's
character rather than as a dimension.

Widened **east only** — west would have eaten the 0.30 m threshold
between room slab and vestibule, and a 150 mm threshold reads as a
mistake. East leaves 200 mm of fill brick to the block edge and keeps
the shaft's full 0.30 m teal lining, which is canonical.

Everything derived cleanly. The one trap was a hard-coded duplicate: the
`GROUND_HOLES` entry cutting street asphalt over the shaft. Miss it and
the pavement grows a lid over the stairwell.

## B2 — the descent accumulates (`b2_diorama/`)

The owner called this "one of the most important artistic opportunities
in the redesign". It is also the least invented thing in the rebuild:
littered treads, a soiled red rug and layered graffiti are **canonical**,
straight off Otomo's stairwell frame. Widening the stair in B1 is what
made room for it.

**38 pieces, and the rule that keeps it from being mess:** every object
belongs to somebody and answers one of three owners — *the bar
overflowing*, *the building working*, or *the street posting*. Nothing is
decorative rubbish; a thing is there because a person put it down and did
not come back.

- **Street lobby** — three plies of fly-posting, each smaller and prouder
  of the wall than the last; an umbrella stand nobody empties and the
  drip ring under it; newspapers bundled for a collection that is late.
- **The flight** — an older tenant's name ghosting through paint too thin
  to hide it; a dead neon fragment whose tube is long gone and whose
  transformer is still bolted up and still cabled to nothing; the
  building's own surface wiring in three gauges from three decades; and
  flat litter on the treads, east side, never in the lane.
- **The foot** — empty crates stacked two high and one askew, because the
  last person carrying them was tired; bottles in the top crate and two
  that never made it back; a rolled rug on end, kept because it might do
  for the stage; folded chairs from a night that needed more seats; a
  hand truck with a maintenance tag nobody has signed since the year
  before last.
- **The mop and bucket** — the one object here that is not abandoned. It
  is waiting for the next shift, and it is the same tool the entropy
  proposal puts in the player's hands.

**Nothing stacks on the flight itself**, because a crate on a stair falls
down it. The mass piles at the two landings, where a person would
actually abandon it, and the flight gets wall layers and flat litter.

**The lane is sacred.** Accumulation is held east of x 5.28, leaving
**0.98 m of clear walking width** the whole way down — wider than the
entire descent was before B1. Verified by measurement: max intrusion
0.000 m.

## B3 — the lounge decompresses (`b3_lounge/`)

The crowding was measurable, not impressionistic. The south deck offered
**2.65 m of east wall** to two canonical arcade cabinets *and* two
banquettes — **4.46 m of furniture wanting 2.65 m of wall**. The cabinet
at y −36.30 and banquette 0 interpenetrated, and the jukebox stood
inside table 0's footprint. Nothing caught any of it, because couch and
jukebox assemblies carry no registered footprint and the overlap audit
cannot see them.

**The fix is programme, not floor area.** The south deck stops competing
with itself: it becomes the **arcade corner** — the two receivers on the
east wall where canon puts them ("immediately left on entering"), the
jukebox against the south end wall facing north up the room, clear floor
between. The lounge moves to the north deck, which grows 0.25 m to
−31.75, with three banquettes — the third turned to face the other two
across the tables, a conversation pit rather than a rank of seats
staring at a wall.

**Widening the deck westward was tried first and rejected by
measurement.** The deck's west edge at 1.80 is what keeps the crossing
route from (1.50, −32.80) to the pool table walkable, and that crossing
is the entire reason the room was widened on 2026-08-08. Taking lounge
depth out of it would have spent the room's scarcest asset on its
roomiest problem. ShopEntryTest failed exactly this way on the first
attempt and was right to.

## Verified

`gen_layout` clean; 8/8 GLBs; **WalkTest FULL PASS**, ShopEntryTest PASS
(all crossing sweeps), StreetCoreVisibility PASS, ServiceWireResponse
PASS. Harukiya perf station **10.45 ms** against the 16.6 gate — slightly
faster than before the work.

## B4 — the section opens (`b4_well/`)

The commission's headline, and the answer to "much larger" that the
geometry actually permits. The footprint can gain 2.7%; the **section**
gains a two-storey well over the table floor.

`WELL = (-5.60, -35.90, 0.60, -31.00)`, cut out of the block's own
brick, slab soffit at **2.52** over a floor at −2.80: **5.32 m clear**
where there was 2.65. You stand at the counter under a canopy at 1.76
and a ceiling at 2.65; three paces out the room goes up two storeys.

**All four blockers handled, each of which would have shipped a defect:**

- **The slab top is 2.80 and not one millimetre more.** The street-cull
  gate is a whole-AABB test with `hi.y <= 2.80`; overshoot and the
  buffer drops out of the index and the new upper volume renders
  *through the pavement*.
- **The shaft clears the luncheonette's void** above the west end
  (x −11.4..−6.2) — it starts at −5.60. Otherwise the well opens into
  the diner's floor.
- **It stops 0.72 m short of the counter** (−31.00 vs −30.28), so the
  canopy zone keeps the low ceiling that is canon.
- **`GROUND_HOLES` is cut to match.** Without it the street asphalt
  sheet (top −0.02) becomes a black lid hanging two metres over the
  tables — the sweep found this and it was real in the code exactly as
  described.

**Two things resolved themselves well.** The ceiling services run
wall-to-wall, so opening the void turns them into a service bridge
crossing at the old ceiling line — they terminate at both ends, so
Accord 11 holds and the room gains a visible datum saying *the ceiling
was here and they took it away*. And the two table pendants inside the
shaft got real drop rods from the slab soffit; they had been floating
0.47 m under the old slab all along, a defect nobody saw because the
ceiling was dark and close.

**Measured:** the bar station reads **9.98 ms** against the 16.6 gate —
*faster* than before the rebuild began (11.0). Stations-over went 5→6,
but the sixth is apartment 4B at 17.03 (was 15.95), eight floors away
and straddling the gate, in a run where the roof simultaneously improved
3 ms. That is this machine's noise band, not the well.


## B5 — the well gets its lamp (`b5_light/`)

Opening 5.3 m of brick shaft made the room taller and left no way for the
player to know it: the void read as a dark opening. One caged bulb now
hangs deep into it on a flex from the slab soffit, grazing the upper
brick so the height reads, and hanging where nobody will ever change it —
the good kind of unreachable.

**It obeys the doctrine rather than breaking it.** The room's rule is
*small warm sources hung close over people, and nothing lighting the room
in general; you read the room by the pools and the dark between them is
the point.* This is not a wash — it is one source you can point at, and
the dark between it and the table pendants below is still the point.

`navigation: false` deliberately: it is not a circulation light, and nav
weighting (which multiplies squared distance by 0.15) would have it
outranking fixtures people actually stand under. Its z 1.60 sits well
under the 3.80 m storey cliff, so it resolves to F01 with the rest of the
room rather than going dark whenever the player is in the bar — the
failure the arcade's lighting audit flagged as a class.

B3 also moved the lounge north past its light, so the deck sconces went
from two to three: one over the arcade corner's machines, one over each
end of the lounge. Still *over the ends, never the midpoint* — the
doctrine, unchanged.

Stale note corrected in the same pass: the lighting block still reasoned
against "LightRig's budget of fourteen". The runtime budget is 64 now
(TASKS L14), so nothing in this room loses any more. The margin reasoning
is kept, because it is still how to decide which fixture *should* lose if
a budget ever binds again.

LightingAudit, WalkTest FULL, ShopEntry and StreetCoreVisibility all pass.


## B6 — the counter, and what the identity floor bought (`b6_counter/`)

The commission wants the bar to be the room's hero. **Ledger A0.3** says
how it may be grand in a Queens cellar in 1928: the fit-out is
*inherited*, taken out of a closed hotel bar, twenty years old on arrival
and cut down for a room it was never drawn for. **Ledger A0.4** sets the
price: any phase adding fabric must say what it adds on the Japanese side
in the same breath.

**Both constraints made this better, not smaller.**

- **The counter runs 6.30 m**, up from 5.20 — with its canopy grown in
  plan and its z **frozen at −0.98**, because that 1.76 m underside is
  the canonical low element of this room and the one number here that
  may not move.
- **The salvaged mirror sits in one bay, not across the back.** The
  canonical crowded gallery runs the north wall from x −4.30 to 3.80, so
  a continuous mirror would erase eleven authored frames. The only bay it
  can occupy is west of the gallery — so that is where the hotel's mirror
  ended up. *It didn't fit, and a room furnished from salvage is a room
  where things are where they fit.* The rest of the backbar keeps the
  photographs as its back wall, which is a better bar anyway.
- **The barrels take the centre, and finally stand on something.** Two
  rope-bound sake barrels are the only Japanese object inside this room,
  and they were *floating* — pipes at z −0.72 with nothing beneath them,
  which Accord 11 forbids and nobody had caught. They now have the
  backbar's centre bay, a real shelf, and their brewery rope bindings. So
  the hero object's axis is theirs and the inherited mirror is off to one
  side: **A0.4 answered in geometry rather than in prose.**
- **A masu shelf** — square cedar cups stacked in threes at the working
  end, the thing a Japanese bar has that a hotel backbar never did.

**How far west the counter may go is set by the pool table, not by
taste.** Running it to −6.00 was tried and took two cue-lane sweeps: a
cue is 1.45 m, and the room already ruled that *a table you cannot stand
back from is scenery*. With the capsule at 0.33 the counter must start
east of −5.17, so it starts at −5.10 and the cue keeps its swing.

**Verified:** WalkTest FULL, ShopEntry (all four rail lanes and every
crossing), StreetCoreVisibility, LightingAudit, ServiceWireResponse. Bar
station 10.60 ms against the 16.6 gate.
