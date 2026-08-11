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

**Tested 2026-08-11, and options 2 and 3 are dead.** A crop of sides 10% /
top 9% / bottom 20% cleared the watermark on all fifteen shortlisted clips at
one second in — and `ch_01` still showed it near the end, floating in the middle
of the frame. **The mark moves within a single clip.** A static crop cannot
follow it, and neither can a static gate mask, which kills the idea of hiding it
in the projected-look pass.

**Two masking ideas were tried against the footage and both failed on the same
fact.** A burn that grows over the mark and recedes means burning *permanently*,
because the mark is in nearly every frame — and a permanent burn is not an
effect, it is a fault. Placing a burn over it fails too, because the mark
**wanders through the middle of the picture**: in `ch_01` it starts top-left,
drifts to dead centre at mid-height, and ends bottom-left. Anything large enough
to cover that path is large enough to eat the shot.

Both effects were built anyway (§3) because they are worth having on their own
terms. Neither is a fix.

**Only a clean re-render works**, at whatever aspect §3 settles on. Everything
else in this brief can be built in parallel; no reel ships until this is done.

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

## 2b. THE PLATE — ruled 2026-08-11, and it changes the machine

*Reference: Niépce's heliograph at Le Gras (1826) and Cornelius's self-portrait
daguerreotype (1839). The brief was "ghostly projections from some forgotten
past".*

**What makes those images read as haunted is exposure time, not grain.** Niépce
needed eight hours; Cornelius sat for minutes. Anything that moved during the
exposure smeared or never registered at all — so an early photograph is a record
of *what held still*, and people do not. That is the whole effect and it is
temporal, not a filter.

So the pass is built in two halves:

**1. The long exposure, which does the work.** Accumulate the video over ~1–2
seconds so movement becomes a luminous smear and only stationary things resolve.
A person walking loses their head. A dress becomes a column of light. **The
project already has this exact machine**: `ArcadeMachine._build_phosphor()`
accumulates into a SubViewport with `CLEAR_MODE_NEVER`, dimming the previous
frame with a low-alpha black rect. The plate is the same construction with the
decay turned right down — a phosphor with a memory of seconds instead of
milliseconds. Reuse it; do not write a second one.

**2. The plate itself, which sells it.** Tonal compression toward a mirror
rather than a photograph — crushed floor, rolled highlight, no real midtones —
a pewter/silver duotone that runs warm where the metal is thick and cool where
it is thin, and **damage that sits IN FRONT of the picture**: chemical blotch,
sparse vertical wipe streaks, bright flecks, and edge rot where the emulsion
gave up first. Damage occludes. It does not tint. That distinction is most of
the difference between this and a sepia filter.

**This changes the machine, and for the better.** A 16 mm Kodascope shows
moving film. What is described above is a *still that breathes* — and the
period-correct device for projecting a still is the **magic lantern**, which is
older than film, domestic, and exactly "some forgotten past". The reels become
**glass slides** in paper sleeves, which is a better collectable object than a
film can, and the horror sharpens: a lantern slide is not supposed to move at
all, and this one is.

Keep §1's 16 mm research on file — if the owner wants motion rather than
breathing, Kodascope is still the right answer for an American block.

**One honest consequence.** At this level of degradation the watermark becomes
the only crisp, high-contrast element in the frame, so the plate pass makes it
**more** conspicuous, not less. The owner has deprioritised it; noting it here
so nobody is surprised.

## 3. The projected look

A shader pass over the video texture, plus the light it casts. In rough order of
how much each contributes:

| Element | Note |
|---|---|
| **Frame mask and gate weave** | The image drifts a pixel or two, continuously. More than any other single thing, this reads as film. |
| **Silent-speed flicker** | 16–18 fps shutter, not 24. Slightly too fast, slightly strobing. |
| **Grain and dust** | Sparse, per-frame, brighter than the image. Hairs at the gate edge. |
| **Splices** | A jump and a frame of white every 20–40 s. Reels were cut and rejoined. |
| **Cigar burns** | The projectionist's changeover cue: a small circle in the top corner, four frames, twice. Almost nobody consciously notices one, which is why it works. **A cue means a JOIN** — a print with cues every few seconds is a print assembled out of scraps, which is what these reels are. It is the punctuation of a badly edited film. |
| **Film burn** | The reel stopping in the gate: a bright ring, a brown scorched edge, and a hole that is not a colour but the bare lamp. **Authored, never automatic** — it is what a reel does when it ends, and what the Tenant does when it wants the film to stop being the point. |
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

**Caveat added 2026-08-11 after checking: this table is a first pass and part
of it is already wrong.** These were chosen from a single frame each, and the
clips are multi-shot montages rather than continuous takes. `ch_36` opens on a
colonnade and resolves into a title card — ALEXANDRA OF MACEDON / INSPIRED BY
TRUE ACCOUNTS — so it is a trailer, and it is cut. `ch_19` leaves the water for
a snorkeller at sunset, `ch_07` leaves the snow for a blue-lit interior, `ch_24`
ends on blown white. **Re-curate against the five-frame strips, not the contact
sheet.**

Chosen by eye for footage that survives being made grainy, flickering and
possibly monochrome, and that reads as *a record of something* rather than as a
video someone posted.

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
