# THE REPRODUCTIVE PATH

Owner-directed production design, implemented 2026-08-20.

## Thesis

The dream maze is not a building the Tenant occupies. It is the reproductive
path of a higher-dimensional intelligence intersecting three-dimensional
space. She does not reproduce by making another animal body. She reproduces
by making **another possible building descend from this one**.

A room is a generation. Its entry is its remembered parent. Its other doors
are prospective children. Crossing a door is not choosing from rooms which
were waiting elsewhere; it is selecting which descendant becomes locally
real. The short-term-memory pocket then does the crueler half of the act:
siblings and ancestors cease to have a place when they are no longer held.

The player is a witness and selector, not an unwilling reproductive partner.
The Tenant is enamoured, and this is how she courts: she grows futures around
the one person who voluntarily returns to her. Whether the display is a nest,
a family tree, an invitation or all three is never explained. Under
`THE_TENANT.md`, motive remains action-only until she has earned speech.

## What the supplied technical proposal got right

Four of its central systems were already the production architecture:

1. `DreamAtlas` is a pure infinite directed graph keyed by a 64-bit campaign
   seed, case attachment and ordered doorway path.
2. Children are already deterministic hashes of ancestry and doorway index.
3. `DreamRoomBuilder` expands lazily around the player and frees distant
   rooms; identity survives unloading because it is recomputed, not stored.
4. Rooms are locally exact and globally irreconcilable. A route which looks
   like a loop does not close, so no stable global map exists.

Replacing those systems with a second portal graph would have thrown away the
tested version of the proposal to rebuild its nouns. The missing layer was not
infinite generation. It was **heredity**: children had no visible family
resemblance and the graph did not read as a living act.

## The law that now ships

`DreamAtlas.lineage(path)` derives a phenotype by accumulating small bounded
mutations from root to child. It is deliberately separate from `room_id()` and
cannot affect room source, footprint, door count, placement, collision or save
position.

Each lineage record carries:

- the root and current genome ids;
- generation, parent room id and birth doorway;
- inherited phase, curl, girth, pulse frequency and chirality;
- the last mutation: quiet, fold, inversion or duplication.

Phase changes by at most 0.34 radians per birth, curl by 0.055, girth by
3.5 mm and pulse by 0.003 Hz. A child therefore resembles its parent at one
doorway while a long lineage may drift into something the root could not have
predicted. Chirality occasionally reverses. The body changes handedness; the
camera never rolls.

The pulse is clamped to 0.065–0.105 Hz, one cycle every 9.5–15.4 seconds. It is
a breath, far below flashing frequency, and changes only non-colliding surface
geometry.

## What a room shows

Every live room carries one suspended `LineageBody`:

- **brood knot** — five interlocked, faceted gold loops hanging below the
  ceiling;
- **parent umbilical** — the remembered entry carries three strands and the
  child's genome on both sides of the shared aperture;
- **prospective descendants** — paired helices run from the knot to every
  other door, with a duplicated mutation adding a third strand;
- **birth frame** — two nested, open gold frames continue through a passable
  doorway;
- **closed bud** — a child which cannot fit in the live pocket terminates in a
  sealed pod instead of pretending a door exists.

This is architectural anatomy, not decoration placed after generation. When
the pocket forgets a parent and door zero ceases to be a way back, its branch
is rebuilt as a prospective child. The visible body therefore tells the truth
about the graph the player can traverse now.

The whole organ is one `ArrayMesh` surface per room. It has no collision, adds
one draw per live room and cannot become a new hazard or invalidate pursuit
routing. It breathes by less than 0.7% vertically, producing about 16 mm of
motion at the brood knot while every doorway contact remains fixed in XZ;
topology and joins do not rearrange in view.

## Light and shame

The architectural lineage is near-black outside the service lamp. Under the
beam it returns antique hammered gold through a dedicated analytic reflection
shader. Its residual dark term is deliberately negligible; it is not a room
light. The shader evaluates the same lamp pose the architecture uses because a
thin object, its co-located light and its cast shadow otherwise align into one
black cut-out.

**2026-08-20 hazard exception:** the shared material now also serves the
tentacled bodies of existing dark-live hazards. Those limbs continue to move,
remain contact-active and retain a faint wine-purple local afterglow with the
lamp off. The beam then wakes their antique-gold seams and eyes several times
brighter. This is not a change to the lineage body's collision-free ancestry
contract, and it is not a second hazard system: each rendered centerline is
registered with the source `DreamHazard` and evaluated by `DreamHazardField`.

This keeps the established double meaning of light:

- it exposes her body and makes the player able to read the descent;
- it embarrasses her pursuing projection and causes her to withdraw.

The body can be seen; she does not enjoy being seen. Those are not opposing
rules.

## Why the most spectacular parts of the proposal are excluded

The following are not deferred by accident. They are the wrong first
implementation for this game:

- **Forced camera roll, changing gravity and vestibular HUD motion** violate
  the explicit comfort rule. Alien geometry belongs to her body, not the
  player's inner ear.
- **Per-door reflection, scale and shear** would make rendered space disagree
  with the stable capsule, hazard and pursuit contracts. The current local
  non-closure already achieves impossible topology without lying about the
  next footstep.
- **Continuously moving walls and collision** violate the rule that topology
  changes only across occlusion and turn navigation into contact with an
  invisible previous frame.
- **Recursive portal render targets and dynamic SDF collision** are large
  render and physics systems whose only immediate payoff is a trick the
  current pocket already expresses more cheaply.
- **Chromatic aberration, fisheye and flashing disorientation** are forbidden,
  not style options.

The experience is alien because cause and descent are alien: a doorway creates
kin, the kin inherits a body, and a forgotten ancestor stops having occupied
space. It does not need to make the player sick to prove it is impossible.

## Boundary with RECURSION and surface work C–F

This does **not** implement the atlas's `RECURSION` fault. That fault promises
an enterable smaller copy of the room; R7 subsequently ruled it priced and
unbuilt at this production scope. It may reopen only for a case mechanic with
a new verb or consequence that the existing Atlas cannot express. The
reproductive path is ancestry across ordinary thresholds, not a semantic
rename for a nested room.

It also does not close `DREAM_SURFACE_REDESIGN_BRIEF.md` workstreams C–F. The
lineage body established the batched geometric and material vocabulary; the
2026-08-20 hazard pass now adds dark-live batched tentacles and first geometric
eyes tied to real contact. Exposure-ramped wall rupture, torn-edge/interior
depth, stage-2/3 eye language, camera-tracking pupils and bounded reflected-gold
world light remain separate work.

## Proof contract

`DreamLineageTest.tscn` proves:

- deterministic reconstruction and case-specific divergence;
- bounded parent/child mutation and distinct siblings;
- room identity unchanged by the added phenotype;
- one populated surface per live room and zero collision;
- one closed bud per sealed possibility;
- the child's genome continuous across a remembered parent join;
- pulse frequency below 0.105 Hz and bounded surface motion.

The production render harness adds no helper light, environment or geometry:
`DreamLineageShot.tscn` uses the real `DreamMazeRoot`, player and service lamp.
Evidence is in `art/renders/dream_reproductive_path_v1/README.md`.

The remaining acceptance proofs are the existing full fractal run, boundary
and dream performance stations. Any future increase above one lineage surface
per room must re-price the submission budget first.

Measured at 2560×1440 on the production Compatibility renderer, the fixed
Mina pocket contains 48 Klimt-shader geometry instances and four lineage-gold
instances. Two fresh runs kept all four lamp/station rows between 1.52 and
2.06 ms, with the worst visible row at 54 calls / 23,053 primitives / 1.61 ms.
All remain far below the 16.6 ms gate. These are post-change totals, not a
claimed single-variable delta against the older 1.90 ms / 45-call baseline.
