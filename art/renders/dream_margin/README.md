# PHASES 2–3 — THE DREAM MARGIN

> §4: *"The violet Dream field does not end in a shader fade. Its boundary is
> populated with independently behaving appendages."*

`DreamMarginController` owns the population; `DreamPalpMorphology` owns what
each appendage *is*; `DreamPalpRenderer` draws the whole margin in **one mesh
and one draw**, because the frame is submission-bound
(`design/DT4_PERFORMANCE_REAUDIT.md`).

Contract: `DreamMarginTest` — **12/12**, with 64 live appendages across three
tiers.

## Six authored archetypes (§5)

Soft palp, flat ribbon, sucker probe, gold-jointed finger, crystal feeler,
ciliated whisker. Each authors **four cross-sections** — root, shaft, sensory
region, tip — and the shader interpolates between them.

That is the load-bearing decision, and it is §7's point: a tube with a
different radius curve is still a tube. What reads as biological variety is
the *section changing along the length*. A flat ribbon is flattened to 0.86
at its tactile face; a crystal feeler is 0.02 with six deep lobes at its
organ. They are different organs, not differently-scaled noodles.

The contract asserts all six progressions are unique, that all six specialise
their far ends differently (pad, crystal organ, mineral claw, tactile face,
cilia tuft, lobed sensory), and — the "no procedural oatmeal" rule — that
twelve individual flat ribbons vary in length from 0.226 to 0.551 m while
never dropping below 0.76 flatten. **Individuals vary; archetypes do not
blur.**

## What the photographs changed

`01_before__all_whiskers.png` — **rejected.** The population came out 29
ciliated whiskers of 64, and the closest cluster on a lit wall held *two*
archetypes between six members. §37 asks for at least six nearby appendages
clearly different in silhouette, movement, function and distal anatomy; this
was a handful of wires.

The cause was rolling dice for every birth. The **primary tier** — the six
the player actually walks up to — now takes each archetype in turn and is
guaranteed to show the whole library. The lower tiers stay random, because
distributed sensing genuinely *is* mostly whiskers.

The review stand also changed: it framed the **biggest** cluster, and the
biggest cluster was six whiskers. It frames the most *varied* one now, since
§37 is about difference.

`02_edge.png`, `03_gameplay.png`, `04_close.png` — after: a cluster of 11
carrying four archetypes.

## Phase 5 — personality and intent

§8's traits are generated from each palp's own seed and never change for its
life, which is the point: *"Do not reshuffle these continuously. Stable
personality makes individual appendages memorable."* The contract asserts they
are stable across time and that individuals differ (curiosity spread 0.93
across a live population).

§9's ten primitives are implemented as **rules for choosing where the tip
wants to be**, not as animations — probe steps and pauses, sample tremors at
the individual's own 5–9 Hz, touch decelerates before arriving, trace slides
along the surface, brace plants and stops moving entirely. The rig solves
toward that. Measured across 51 live appendages: **eight of the ten primitives
running simultaneously** (probe 16, trace 14, withdraw 6, touch 4, hover 4,
brace 3, taste 3, sample 1).

The first version had almost nothing to do: 29 probing, 26 hovering, one each
tracing and sampling. Seeking only looked *outward into the room*, and a palp
on a wall has nothing within half a metre of itself, so it almost always
failed and every characterful act starved. But the wall **is** a surface, and
§9's *"Trace: follow edge, seam, contour or grain"* is exactly about working
it. A palp that finds nothing to reach for now turns its attention to what it
is already touching.

## §37, arranged — `07`, `08`, `09`

*"At least six nearby appendages must be clearly different without relying
purely on colour ... The edge should never look like repeated noodles."*

That is a **review** test, and reviewing it against whatever the simulation
happens to have produced is not a review. `SWEEP_MODE=archetypes` puts one of
every archetype in a row on a found wall in 2A, at primary scale and full
extension, and photographs it at three distances. This is the §24 contact
sheet for the margin.

They differ in silhouette — a hair-fine whisker, a broad flat ribbon, a
knobbed soft palp, a shafted probe with a spread pad, and a narrow stem
carrying a flared faceted head — and, crucially, **in material**.

`07a_rejected_all_gold.png` is why that second half matters. The palp shader
carried `EMISSION × 2.2`, tuned back when these were 5 cm tendrils that had to
be visible at all. At primary scale it blew every archetype out to the same
molten gold, so six different organs photographed as six gold blobs — exactly
the failure §37 names. Emission now scales with the individual's own gold
fraction (§6 makes that anatomy, not decoration), so a whisker at 5% gold
reads as dark flesh and a gold-jointed finger at 72% carries light.

## Not done, and not pretended

- **§37, in the wild**, is still not demonstrated. The best naturally
  occurring lit cluster reached five appendages and four archetypes, and they
  read as small dark forms on a wall at gameplay distance. Primaries now
  congregate rather than scattering and run at 1.35× so they sit inside §3's
  10–60 cm band, which helped and was not enough. What the simulation
  produces in one flat at one moment is not yet a review.
- **Phase 6, neighbours.** `neighbours_of()` returns `[]`. No broadcast, no
  avoidance, grooming, bracing against each other or mimicry.
- **Phase 8, branching.** `try_branch()` returns `false`. No recursive
  unfolding.
- No interaction with the hero (§11) and no `DreamGlobalAttention` (§13).
- Palps do not leave residue, though the system now exists and would only need
  a contact hook.
