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

## Not done, and not pretended

§35's later phases hang off named hooks in the controller that **return
nothing and say so**:

- **Phase 5, personality.** `personality_of()` returns `{}`. No curiosity,
  boldness, startle threshold, hero affinity.
- **Phase 6, neighbours.** `neighbours_of()` returns `[]`. No broadcast, no
  avoidance, grooming, bracing or mimicry.
- **Phase 8, branching.** `try_branch()` returns `false`. No recursive
  unfolding.

And the honest gaps beyond the hooks:

- **Movement is not yet intent-driven.** §9 is explicit — *"No global
  sine-wave waving"* — and each palp currently holds a fixed aim with a small
  tremor at the tip. It is not a global sine wave, but it is not probing,
  tracing, hovering, tasting or bracing either. This is the largest
  outstanding item for the margin.
- **§37 is not yet demonstrated in a single frame.** Four archetypes in one
  cluster is not six, and the archetypes need reviewing at gameplay distance
  for whether their silhouettes actually read as different *from each other*
  rather than merely being different in the data.
- No contact with architecture, no interaction with the hero (§11), and no
  `DreamGlobalAttention`.
