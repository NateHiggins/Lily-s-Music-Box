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

- **The §24 laws are declared, not enacted.** Every species carries exactly
  one impossible rule in its data and the contract checks they are distinct —
  but no grazer has yet appeared on both sides of a wall, no listener's
  crystal turns inside a still shell, and no crab shortens a leg. That is the
  single largest gap in this phase.
- No §21 interaction with the margin: they do not crawl across palps, hide
  beneath them, or feed on residue. They share a world and ignore each other.
- No §23 social behaviour — the species declare solitary/colonial/
  opportunistic and nothing acts on it.
- No contact, so they leave no residue.
- All three read quite gold at close range; the material rebalance per species
  (§25) is coarse.
