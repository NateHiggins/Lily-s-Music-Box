# The Projector — reels instead of sets

*Proposed 2026-08-11. **Not canon until the owner rules.** Nothing built.
Replaces the nine televisions ruled in `gen_layout.TV_UNITS`; touches
`BroadcastDirector`, `TVProp`, `PoltergeistLibrary` and `ORISON_BIBLE` III.1.*

---

## 0. Read this first — the clips cannot ship as they are

A contact sheet of all thirty-seven (`ch_01`–`ch_37`, 6–15 s each) turns up two
facts that govern everything below.

**Every clip carries a visible generator watermark.** A "Sora" mark sits in a
corner of nearly all of them, and **the corner moves between clips** — top-left,
bottom-left, bottom-right — so no single crop clears the set. Projected onto a
tenement wall in 1928 it is not a stylistic problem, it is a legal and
presentational one, and it is the single blocking item in this document.

Options, in order of preference:
1. **Re-render the keepers without the mark**, at the aspect ratio §3 asks for.
2. **Per-clip crop**, authored individually. Cheap, lossy, and the vertical
   frames cannot afford to lose much.
3. **Patch in the projected-look pass** — the shader already dirties the image,
   and heavy gate weave plus a hard frame mask can hide a corner. Fragile; the
   mark will show on a still.

**They are vertical phone-format, and modern.** Laptops, headphones, podcast
rigs, contemporary clothing, 3D animation. That is not an accident to fix — see
§2 — but the shape is, because 16 mm and 9.5 mm gates are landscape.

---

## 1. The technology, and the right one to pick

Two real formats put moving pictures in a home before 1928:

- **Pathé Baby 9.5 mm** (1922), the pioneer — a domestic system, camera and
  projector, with a centre perforation between frames so the image is nearly
  16 mm wide on 9.5 mm stock. About 300,000 systems sold, but chiefly in France
  and Britain.
- **16 mm Kodascope** (1923), the American one. 9.5 mm was sold in the USA;
  **16 mm is what North Americans actually used.**

**Pick 16 mm Kodascope.** It is the correct machine for a Queens block, and the
reel is the right object: a flat metal or card can, palm-sized, labelled by hand.

**One honest wrinkle**: a home projector in 1928 was an expensive middle-class
toy, and this is a working-class building. That is a feature, not a problem, and
it wants an answer per machine — second-hand, won, inherited, or left behind by
Vantry as part of the demonstration (§VIII.3). A projector nobody could afford,
in a flat where the light is a bare dome, says something.

---

## 2. Why film is BETTER here than television

This is the argument for the change, and it is stronger than "it looks period".

**A television is a signal from elsewhere. A reel is a thing in your hand.**
Under the sets, the strangeness was ambient — the building receives something it
should not. Under reels, the strangeness is an **object you found, carried, and
chose to load**. The modern content stops being a broadcast from the future and
becomes *found footage of something that has not happened yet, physically
present, in a can, in a drawer.* That is a colder idea and it is the one this
game is better at.

It also fixes the collection problem. You cannot collect a broadcast. You can
absolutely collect a reel.

**And it is a better instrument for the Tenant** (III.1). A projector demands
what the haunting wants: it needs a dark room, it throws its image on the
dwelling's own wall, it puts the viewer's shadow *inside the picture*, and it
requires you to sit still and face it. "Does everything at its disposal to get
the subject to face themselves" is close to a description of a projector.
The horror beats write themselves and none of them need new systems:

- it runs when nobody threaded it
- the reel in the gate is not the reel you loaded
- the film keeps going after the take-up spool has run out
- your shadow is in the frame and it is not doing what you are doing

---

## 3. The projected look

A shader pass over the video texture, plus the light it casts. In rough order of
how much each contributes:

| Element | Note |
|---|---|
| **Frame mask and gate weave** | The image drifts a pixel or two, continuously. More than any other single thing, this reads as film. |
| **Silent-speed flicker** | 16–18 fps shutter, not 24. Slightly too fast, slightly strobing. |
| **Grain and dust** | Sparse, per-frame, brighter than the image. Hairs at the gate edge. |
| **Splices** | A jump and a frame of white every 20–40 s. Reels were cut and rejoined. |
| **Falloff and keystone** | The projected rectangle is brighter at centre and never square to the wall. |
| **Monochrome, warm** | See §7 — this is a decision, not a default. |

**Two things that are not the shader and matter more than it does.** The
projector is a **light source** — a flickering warm beam in a dark room, the
brightest thing in it, casting the player's shadow onto the image. And the
**image lands on the room's own plaster**, so a projection across a corner
breaks over the corner. After the lighting work in section L, this is the most
atmospheric object the building could contain.

**Sound: silent, with a mechanical clatter.** Home projectors in 1928 were
silent; the noise is the mechanism, and the mechanism is a wonderful loop —
sprocket, fan, and the flap of a loose tail when a reel ends. The clips' own
audio goes away, which is a real loss and a real opportunity: **when a film that
has always been silent suddenly has sound, that is the Tenant.**

---

## 4. The collection loop

- **Reels are found objects**, scattered across the map — apartments, the
  basement, the Passage if it is built, the shops, the dream.
- **Every projector arrives with one reel already in the gate.** Nine machines,
  nine free clips, so a player who never searches still sees a third of the set
  and understands the system without being taught it.
- **Interacting with any projector plays anything you have found.** The
  collection is global, not per-machine. Carry nothing; the reels are known, not
  inventoried.
- **A reel is a place, not a list entry.** Where you found it is most of what it
  means — a reel in Cal's flat, a reel in the boiler room, a reel that was not
  there yesterday.
- **No completion reward.** Consistent with the fidget doctrine: the reward for
  finding a reel is watching it. If the set needs a prize at the end, the reels
  were not interesting enough.

**This is also the errand loop's natural cargo.** If the Passage is built (PS5),
a can of film is exactly the sort of thing you carry back across the street, and
carrying changes how you cross.

---

## 5. Which clips — a proposed twelve

Chosen by eye from the contact sheet, for footage that survives being made
grainy, flickering and possibly monochrome, and that reads as *a record of
something* rather than as a video someone posted.

| Reel | What it is | Why it earns a can |
|---|---|---|
| `ch_01` | a dress on a hanger in a doorway | domestic, and the person is absent |
| `ch_06` | one figure alone in a gallery with a dark sculpture | scale and solitude |
| `ch_07` | a snow road, a figure walking away | leaving, which is the building's subject |
| `ch_13` | a laundromat at night, someone sitting alone | **the Orison's laundry is where WORS 1610 broadcast from** |
| `ch_17` | an avenue of mossy trees | timeless; works in mono |
| `ch_19` | underwater, a swimmer | dream logic, and it suits the maze |
| `ch_21` | a lecture in front of a projected image | a projection inside a projection |
| `ch_24` | two figures in a bare room, one in a conical hat | unexplainable, and period-ambiguous |
| `ch_25` | a figure against cloud | reverie |
| `ch_30` | aurora over water | abstract, and beautiful at low contrast |
| `ch_36` | a classical colonnade | the building's own pretensions, quoted |
| `ch_37` | a ribcage and smoke | the macabre one; every set needs one |

**Cut**: the talking-head and vlog clips (`ch_02`, `ch_05`, `ch_08`, `ch_11`,
`ch_12`, `ch_22`, `ch_27`, `ch_28`, `ch_31`, `ch_33`), the cartoons (`ch_14`,
`ch_23`, `ch_34`), the fashion and product pieces (`ch_15`, `ch_18`, `ch_20`,
`ch_26`, `ch_35`), and `ch_04`, `ch_10`.

**The counter-argument, stated because it is good**: the contemporary clips are
the strangest ones. A 1928 flat projecting a woman recording a podcast is more
uncanny than a landscape. If the owner wants that, the set should be *mostly*
landscape and architecture with **two or three modern intrusions held back as
late finds** — the strangeness lands far harder as an exception than as the
norm.

---

## 6. What this costs elsewhere

- **`BroadcastDirector` inverts.** It currently shuffles all thirty-seven at
  will, a card break every third. Under reels it plays *what the player chose*,
  from *what the player has found*. The shuffle survives only for the Tenant's
  own use — when the machine runs by itself, it picks, not you.
- **The television assertion changes again.** `WalkTest` guards `sets >= 8` as a
  floor on the haunting's reach (see the cull commit). Projectors inherit that
  duty and the check should follow them, not be deleted.
- **`TVProp` becomes `ProjectorProp`**, and the screen stops being part of the
  prop — it is a wall. That is a real change in kind, not a re-skin.
- **Nine locations, revisited.** `TV_UNITS`' nine households each had a reason
  for owning a set; some of those reasons survive the change to a projector and
  some do not. Cal and Sacha keep theirs easily. Teresa's set that "runs for
  company while she sleeps" does not survive at all — a projector cannot be left
  on unattended, which may be worth losing or worth writing around.

---

## 7. Open questions for the owner

1. **Monochrome or colour?** Mono is the period read and flatters the shader.
   Colour is what these clips are, and stripping it removes the one thing that
   makes the modern footage feel modern. A third option: mono for the found
   reels, colour only when the Tenant is running the machine.
2. **What shape is the frame?** The footage is vertical and the gate is
   landscape. Letterbox it into the gate (safe), crop to 4:3 (loses most of the
   frame), or **let the gate be the wrong shape** — a tall slot in a 1928
   projector, which is impossible and unremarked, and is the most this-game
   answer available.
3. **How many reels, total?** Twelve is proposed. The number is the collection.
4. **Do the modern clips stay at all?** §5's counter-argument says keep two or
   three as late finds.
5. **Does a reel play anywhere, or only where it was found?** Global is kinder
   and simpler; place-locked is more haunted.
