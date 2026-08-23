# PHASE 9 — THE FIRST THREE CRITTER SPECIES

Level 3 of the ecology. Not arbitrary animals synthesised from nothing — §14
forbids that — but three authored species templates with controlled variation.

| species | thesis | plan | its one impossible rule (§24) |
| --- | --- | --- | --- |
| **Seam grazer** | tastes architectural seams, therefore its ventral anatomy is a sensory comb | flattened crawler | occupies both sides of a thin wall at once |
| **Crystal listener** | collects vibration, therefore most of its body mounts mineral resonators and it holds still to use them | radial sensor | its crystal turns inside a shell that does not |
| **Fold crab** | works surfaces apart, therefore its front limbs are mouthparts and its joints are mineral cups | multi-limbed walker | shortens a leg without moving either of its ends |

Eight individuals at a time, three body plans, **one mesh and one draw**. UV2
carries the critter index and which *part* a vertex belongs to, so one vertex
program builds three anatomies.

## Measured, not asserted

`DreamCritterTest` — **16/16**.

§16's third clause (what a species *cannot* be) is executable, and it earned
that on its first run: across 1200 generated individuals it caught **23 fold
crabs** violating *"stands off the surface on its legs"*. The height and width
bounds allowed 0.045 against 0.17 — a ratio of 0.26 against a rule demanding
0.35. **Bounds must guarantee a species rule, not merely usually satisfy it.**

§38 is measured rather than eyeballed. Ten seam grazers spread 0.27–1.15 in
visual distance, so they are individuals; the closest pair drawn from
*different* species sits at **2.05**. The furthest siblings are nearer each
other than the nearest strangers.

In the world: 8 alive, furthest travelled 0.99 m in 9 s, **0 airborne** —
they stay attached to the architecture they walk on.

## What the photographs fixed

`00_rejected_ribbon_legs.png` — the crab's legs came out as **flat ribbons**.
A tube's cross-section has to be perpendicular to the tube, and I was
offsetting along the ring normal in a fixed plane, so every limb's section lay
in the *same* plane regardless of which way the limb pointed.

Then they read as **bars**: five segments is a pentagonal prism and four is a
square one. Eight and six now.

The body showed its polygons on the silhouette at 40 cm, which is the one
place a low count always tells: 9×12 became 13×18.

## Not done, and worth being blunt about

## §24 — the laws, enacted

Each species now DOES its impossible thing, and each is measured doing it.

**Seam grazer — both sides of a thin wall at once.** Not a copy: the same
animal, met twice, because a body with more extent than our space has can
intersect one slice in two places. It faces the same way on both sides,
because it is facing one way. Measured at a 0.216 m gap through a wall;
`04_law_both_sides_of_a_wall.png` shows the two lens bodies flanking a thin
panel.

**Crystal listener — its resonator turns inside a shell that does not.** The
body's orientation is never written at all; only the crystal's shading frame
rotates. So the outside is demonstrably still while the mineral inside turns,
which is not something a solid object can do. Measured: 26.09 rad of rotation
against an untouched shell.

**Fold crab — a leg shorter than the gap it spans.** Root on the body, foot
planted, neither moving, and the limb between them simply stops covering the
distance: past its reach the leg is *absent* rather than stretched, because
stretching it would make it possible again. It stands still while it does
this — a walking animal's feet move anyway, which would hide the whole point.
Measured: the body moves **3 mm** during a fold.

That last figure started at 438 mm, and the fault was the test rather than the
crab: it compared position across every fold event over eighteen seconds, and
between events the crab simply walks. It was measuring locomotion, not law.
- The review photograph of the grazer's law is weak: it twinned on an
  exterior wall at night, so the frame is dark and the framing is outdoors.
  The phenomenon reads — two lens bodies either side of a thin panel — but
  this deserves a deliberate stand like §37's archetype row.
## §21 — the margin as habitat

*"This turns the wall into a functioning biome."* A biome is not two
populations sharing a wall and ignoring each other, so three things happen,
each chosen because it is legible from across a room:

- **Shoved aside.** A primary palp is several times a critter's size and does
  not notice it. A startle-prone individual freezes afterwards.
- **Following a discovery.** A curious critter treats a nearby palp's target
  as worth investigating and heads for it.
- **Feeding on residue.** Fresh Dream saliva is transformed matter, and a
  scavenger stops for it.

Measured in one run: **3 shoved, 3 following**, alongside 2 grazers on both
sides of walls and 2 crabs folding a leg. That census reads like an ecosystem
rather than a list of spawned props.

Feeding shows zero in the contract because nothing has laid residue in that
run — the path is wired, not exercised.

## §22 — the hero, and who is brave

*"hero emerges, several critters flee into Dream margin, one remains, hero
examines the brave individual … These interactions can create character
without dialogue."*

The beat only works if individuals differ, and §19 already gave every critter
a confidence, so it costs no authoring: a timid one flees along the surface,
a confident and curious one holds its ground and comes closer. The hero
notices whatever is alive nearest it — along its whole body, not only its very
tip, since a critter clinging to a gold plate halfway down is §22's own
example — and looks at it in preference to whatever it was reaching for.

Its cross-sectional withdrawal is treated as more alarming than its presence,
so even a fairly bold animal reacts to the hero ceasing to have a thickness.

Half of all critters are now born near the hero. Left purely to chance they
and the hero met only occasionally, and a beat where several flee and one
remains cannot happen to animals that are never in the same room.

## A note on what these tests assert

Three checks here were flaky, and for the same reason: whether a grazer
*wanders* onto a thin wall, or a critter *happens* to be near the hero, inside
any given twenty seconds is chance. Asserting on chance produces a test that
fails for reasons unrelated to the code it names, which is worse than no test.

Those observations are still printed — they are the interesting number — but
they are marked *(emergent, not asserted)*. The **mechanisms** get constructed
tests instead: a 6 cm panel is built, a grazer is placed on it, and its two
appearances are measured on opposite faces; a critter is placed beside the
hero's club and the hero's notice is checked. Same reasoning as §37's arranged
row.
- No §23 social behaviour — the species declare solitary/colonial/
  opportunistic and nothing acts on it.
- No contact, so they leave no residue.
## Phases 10–11 — variation that is visible

**§26, material, seeded per individual and inside the colour language.**
*"Avoid arbitrary hue randomization."* So none of these is a hue: they are
balances between things the palette already contains — how far toward magenta
the plum sits, how proud the crimson perfusion is, how coarse the skin, how
wet, how much the structure catches light, how oxidised the gold. Two animals
differ; neither becomes green. The contract tests both sides, because a
generator that produced a green critter would pass a variation test and fail
the brief: hue spread across 500 individuals is the full 0.00–1.00 and **zero
strays** leave the bounds.

**§20, movement beyond speed.** Two fold crabs from adjacent seeds differ in
**7 of 7** movement properties: which limb leads, pause bias, preferred
turning side, gait phase, gait asymmetry, stride phase and body bob. A moving
animal now rises and falls on its legs; a still one does not.

This also answers the earlier note that all three species read gold at close
range — the balance is per-individual now rather than per-species.
