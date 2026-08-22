# The living field — the encroachment as a slime mould

Owner direction 2026-08-22: flow over every nearby surface continuously,
with an active animated edge, leaving a viscous stain where it approaches
and recedes, like a living thing; built from how slime moulds grow. The
research and the design: `design/LIVING_FIELD_BRIEF.md`.

## What was built

`LivingField` (`game/scripts/reality/living_field.gd`), one per case flat,
owned and ticked by `ApartmentEncroachment`: a 0.25 m 3-D field over the
flat's volume (33 × 14 × 37 for 2A) with three channels — **trail** (Jones's
chemoattractant: deposited, diffused by a 6-neighbour mean, decaying),
**body** (the live plasmodium: agent hits, persisting for minutes, so the
organism keeps the ground it has taken until it withdraws) and **stain**
(the extracellular slime: a slow integrator of the body that decays over
minutes and **repels** the agents, Reid 2012's externalised memory). Agents
are Physarum particles in 3-D: sense the trail minus the stain ahead and at
four 45° tilts, turn to the strongest, step, deposit; starve and die where
the trail is gone; are born at the source (the case's beachhead, which also
feeds) and on the body (the veins). The budget is 120 + 780 × intensity, so
the case's stage is how much organism there is. **Shuttle streaming** is a
14 s cosine on step and deposit, and the surface's isovalue breathes with
it. The relaxation is amortised five slices per tick; agents step at 8 Hz;
the texture uploads once per full pass. 4.3 ms per tick in GDScript at
intensity 0.8 in the test's worst case (every tick stepping the agents).

The surface's **`living` state** (`orison_surface.gdshaderinc`): every
material the case reaches — finishes, the flat's props — samples the field
in world space. The body shows as the case's substance (its ink tint), wet,
with a brighter lip at the front; the **edge** is the sheet's isovalue
perturbed by a 1 Hz fizz and 0.15 Hz fingers and the shuttle pulse; the
**stain** is a viscous film — darker toward the stain tint, roughness 0.12,
the surface's own texture flattened under it — that stays when the body
goes. On a torn finish the body restores the plaster as a membrane. Where
the field is live the static grammar creep steps back to a foothold and the
organism does the reaching.

## Frames (`sheet_growth.jpg`)

2A with Mina forced to 0.9, photographed after 3, 15 and 45 s of real-time
growth from the same stands. At 3 s a patch at the source; at 15 s the
patch has a lobed edge and a film around it; at 45 s the organism has
spread a glossy violet sheet across the west wall with a living, fingered
edge and its stain beyond it. The bedroom wall has not been reached at
45 s — the organism crosses a room in a minute or two, and that is the
pace a slime mould should have.

## Contracts

`LivingFieldTest` 10/10: a 3-D texture over the flat; nothing at intensity
0; a body after 10 s at 0.6 with the full budget; keeps covering ground
(stain grows) while the footprint **retracts** after the first surge — the
Physarum rule, not a fault — and keeps a body; the stain outlives the body
when the case drops to 0 and the agents starve; the pulse has a phase; cost
under 6 ms per worst-case tick. `ApartmentEncroachmentTest` 13/13,
WalkTest FAST PASS, 0 script/shader errors.

## Not done

- The organism's texture is the ink tint; the case plates (the grammars)
  still draw their own static foothold. Driving the grammar's plates by the
  field — so Peter's docket rectangles are filed where the organism is, Juno's
  bands where its waves stand — is the next taste row.
- The field is bounded by the flat; an organism that crosses into the
  corridor is a gameplay question (what it means for the case), not a
  presentation one.
- `LIVING=0` restores the static encroachment.
