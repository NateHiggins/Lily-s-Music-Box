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

## Not yet built

The section — reclaiming the brick above the room for the 5.17 m well
and its +47% volume — is the commission's headline and carries most of
the audit's blockers (the ground plane is not cut over the room, the
walls die at the old ceiling line, ceiling services and table pendants
would hang from nothing, the street-cull gate caps the slab at z 2.80).
It needs its own pass.
