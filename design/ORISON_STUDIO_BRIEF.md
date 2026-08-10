# THE BASEMENT STUDIO — PROPOSAL

*Filed 2026-08-09. Proposal, not a ruling: nothing below is canon until the
owner says so. Obeys `ORISON_BIBLE.md` §VIII (the Rule of Signal) and Accord 9.*

---

## THE ONE-LINE CASE

**In a world where signal technology ran sixty years ahead and nothing else
moved, a building sold as a showcase would have a recording room in the
basement — and it would be the best-made thing in the building.**

The Rule of Signal makes this the single room in the Orison that is allowed to
be uncannily advanced from end to end. Everything in it carries, captures,
switches, stores or reproduces a signal. There is no part of a studio that does
not. It is the purest possible expression of §VIII.2 and it needs no special
pleading to exist.

And per §VIII.3, Vantry & Co. built the Orison in 1912 **as a demonstration**.
This is what you would demonstrate.

---

## WHERE

Two empty basement rooms, ten metres apart, and the run between them.

| | Room | Rect (Blender) | Size | Now |
|---|---|---|---|---|
| **The studio** | `B1_STORAGE_CAGES` | `[-13.65, -9.65, -5.51, -0.45]` | **8.14 × 9.20 m** | one cage bulb |
| **The chamber** | `B1_UTILITY` | `[-3.25, 3.25, 3.25, 6.75]` | **6.50 × 3.50 m** | a switch, a bulb, a door |

Both are the largest genuinely empty volumes down there. Clear height is
**2.62 m** (2.80 floor-to-floor less the 0.18 slab), which matters — see below.

**The studio shares its north wall with `B1_LAUNDRY`.** That is the room WORS
1610 broadcast out of from 1962 to 1999 with no transmitter ever found (§III).
Nothing needs to be said about this. It needs to be *true on the plan*.

---

## THE LAYOUT

Entry from the east corridor at `x = -5.51`, so the player arrives behind the
desk and looks through the glass, which is the correct way to meet a studio.

```
        x -13.65                                        x -5.51
  y -0.45  ┌──────────────────────────────────────────────┐
           │  CONTROL ROOM              8.14 × 2.60       │  ← door, east wall
           │  desk facing the glass, tape machines behind │
  y -3.05  ├════════════ GLASS ════════════╤══════════════┤
           │                               │  VOCAL BOOTH │
           │  LIVE ROOM                    │  2.20 × 2.60 │
           │  8.14 × 6.60                  ├──────────────┤
           │                               │  CAGES       │
           │  drapes on two walls,         │  the ones    │
           │  bare boards under the piano  │  nobody      │
  y -9.65  └───────────────────────────────┴──────────────┘  cleared
```

**Keep some storage cages.** The studio was built *around* them, not instead of
them — mesh partitions along part of the east wall, still holding tenant junk,
one of them full of tape boxes nobody has opened. Nothing in this building was
purpose-built; everything was adapted, and a facility that erased its own
predecessor would be the only tidy history in the Orison.

### The ceiling is too low, and that is the point

2.62 m clear is roughly a metre short of what a tracking room wants. A live room
that low is boxy, and it sounds it — early reflections arrive too soon and the
low end piles up in the corners.

**This is the reason the echo chamber exists**, and it is a better reason than
"studios have them". The room cannot make its own reverberation, so the signal
is sent somewhere that can.

### The chamber

`B1_UTILITY`, 6.50 × 3.50 m, stripped to hard surfaces: cement plaster on metal
lath over the brick, glazed tile to shoulder height, a sloped floor with a
drain because it was a utility room and the drain is still there. One
loudspeaker in a corner facing the wall; two microphones at the far end, at
different heights. No parallel treatment, no absorption, one door with a heavy
seal and a lamp outside it that says the chamber is live.

This is how it was actually done. Capitol built eight concrete chambers nine
metres under Hollywood, each tuned to a different decay, reached by loudspeaker
and microphone. Abbey Road's most-used chamber was a heavily tiled room 21 by 12
feet — **6.40 × 3.66 m, which is `B1_UTILITY` to within fifteen centimetres.**
The room is already the right size. It has been the right size since 1912.

### The run

The send and return between studio and chamber cross **`B1_ATRIUM`** — the room
with forty-six pipes in it and the `room0_threshold` marker on its floor.

That is the whole horror of the proposal and it is entirely structural: **the
echo return does not travel through a cable of its own.** It goes out on house
wiring, through the atrium, past Room 0, and comes back. What returns is the
room plus whatever else is on that line.

Nobody explains this. The chamber simply has a longer tail on some nights than
its dimensions allow, and a competent engineer would notice and could not
account for it.

---

## WHAT IS IN IT

Under §VIII.2, every item below is forty years early, beautifully made and
repairable by anyone who can read. Under Accord 9, all of it is also twenty
years old, has been repaired by four people, and sits on a floor that slopes.

**Control room** — a Vantry desk in Bakelite and brass: twelve channels, rotary
faders (linear faders are a later idea and this world did not get them), a
patch bay wired in cloth-braided flex, VU meters with the glass gone yellow. Two
tape machines on a rack, one of them not working. A monitor pair on the
soffit. A wet-cell bank under the desk in a wooden case. A schematic pasted
inside the desk lid, because §VIII.4 says everything is repairable and the
schematic is how the player is allowed in.

**Live room** — an upright piano against the north wall, out of tune in a way
that is consistent; a drum riser that is really a pallet; two boom stands; a
guitar amp with a valve missing; drapes on runners, mostly drawn.

**Booth** — a stool, a stand, a music desk, a cloth-covered window into the live
room, headphones on a nail.

**Reuse before building.** `asm_amp`, `asm_guitar`, `asm_pedalboard`,
`asm_micstand`, `asm_reeldeck`, `asm_headphones`, `asm_shelf`, `asm_workbench`
and `asm_bench` already exist in `build_orison.py` — they were built for Juno's
and Rhea's flats. Six new assemblies are genuinely needed:

| New assembly | Notes |
|---|---|
| `mixing_desk` | the hero object; sloped panel, rotary controls, meter bridge |
| `monitor_pair` | soffit-mounted, in a wooden baffle |
| `patch_bay` | already prototyped as the signal cabinet control-panel variant; promote it |
| `control_glass` | double-glazed, splayed, with the reveal deep enough to read |
| `acoustic_drape` | runner-hung, gathered; also useful in the Harukiya |
| `chamber_fitting` | the speaker-and-two-mics set, and the live lamp |

The upright piano may already be answerable from the Harukiya's set; check
before authoring a seventh.

---

## WHOSE IT IS

**Nobody's, and that is what makes it usable.** Vantry & Co. built it, Vantry &
Co. no longer exists, and nothing in the building has been serviced by the
people who made it since 1924 (§VIII.3). It is house equipment in a house that
forgot it owned it.

Three residents have standing here and none of them should get a case out of it
yet — §I is explicit that Peter Wren is the ordained second case and none of the
other four are built before he meets Mina's bar (§I, as amended by §IV.1).
**This proposal adds a place, not a case.**

- **Juno Kells (2C)** — audio artist; her work was taken and the feedback became
  load-bearing. The studio is where taking happens. When her case is built, this
  room is already standing.
- **Rhea Sato (3D)** — *sanctioned expansion under §IV.1, not a case yet.*
  Vocal coach and recording artist; her mistakes accumulate
  as a captive note. A room that returns more than you sent it is her wound with
  a door on it.
- **Cal Dwyer (5B)** — radio collector; perfect tuning preserves moments by
  preventing them ending. He is the one keeping the desk alive, and the one who
  will tell the player which valve to buy at the bodega.

---

## WHAT IT IS FOR

**The Songbook's upstream.** `songbook_brief.md` makes the Harukiya a community
song-mutation machine: songs are written, performed, covered, mutated, and
become the bar's cultural memory. That is the *performance* half.

This is the *capture* half, and the two want each other:

- The bar is where a song changes. The studio is where one is **fixed** — a take,
  a master, an artefact with a date on it that the mutation can be measured
  against.
- **Ghost duets** (songbook §GHOST DUETS) belong in a room that records. Cutting
  a take with a part already on the tape that nobody performed is the same idea
  the bar has, in the room where it would actually be frightening.
- A song cut here and played on the Harukiya's jukebox closes a loop between two
  ends of the same building.

**And one maintenance chore, which the Rule of Signal licenses directly:** the
desk has a dead channel. Valves are a consumable, sold six for a dollar at the
bodega beside the cigarettes (§VIII.4). Pull the rack, read the schematic in the
lid, find the dead one, walk to the bodega, come back. That is a complete loop
using systems that already exist, and it teaches the player that the building's
best-made object is also the one they are allowed to open.

---

## WHAT THIS PROPOSAL DOES NOT DO

- **No new case.** Per §I and §IV.1, four resident cases wait behind Peter Wren.
- **No pitch scoring.** The songbook brief rules that out and this does not
  reopen it.
- **No explanation of the chamber's tail.** Per §VIII.6 and the receiver ruling
  (§VIII.5.g),
  the building does not confirm things.
- **No hand-edited JSON.** `gen_layout.py` authors every coordinate (§III).

---

## OPEN QUESTIONS FOR THE OWNER

1. **Does the studio survive as a working room, or as a sealed one?** A room the
   player can use is a system; a room they can only look into is a landmark. The
   layout supports either — the difference is whether the desk powers up.
2. **Do the storage cages stay?** Argued for above, but it costs floor area.
3. **Is the chamber's extra tail ever *heard* by the player, or only measured?**
   It could be a thing the reel shows and the ear does not.
4. **Which resident is found down here**, if any, and at what hour.

---

## SOURCES

Echo chamber practice: Capitol Studios' eight subterranean concrete chambers,
each tuned to a different reverb time, connected to the rooms above by
loudspeaker and microphone; Abbey Road's tiled 21′ × 12′ chamber off Studio Two;
construction in reinforced concrete with metal lath and cement plaster.

- <https://www.soundonsound.com/techniques/inside-abbey-road-reverb-chamber>
- <https://reverb.com/news/6-echo-chambers-that-shaped-the-sound-of-popular-music>
- <http://audiogeekzine.com/2011/02/the-history-of-echo-echo-chambers-chambers/>
- <https://en.wikipedia.org/wiki/Abbey_Road_Studios>
