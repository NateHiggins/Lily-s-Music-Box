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
  bands where its waves stand — is the next taste row (LF-2).
- *(v1 bounded the field to the flat; the second ruling below lifts that.)*
- `LIVING=0` restores the static encroachment.

## v2 — anywhere, radiant, pooled, and a gravity of its own (2026-08-22, second ruling)

*"It can go anywhere it wants and spreads the connection to the dreamworld…
affect meshes close by too, 3D radiant effects… spill over the baseboard
and pool on the floor… variable, disorienting gravitational-like effects,
vector and intensity varying according to elaborate higher-dimensional
logic that also influences the encroachment's spread and nature."* Design
in `design/LIVING_FIELD_BRIEF.md` §5.

- **Anywhere.** One field per **storey** (56 × 7 × 40 at 0.5 m), one source
  per case on it; agents carry their source and the texture's A channel
  tints the body by whose organism it is (Mina's ink, Juno's cloth). Every
  layered material on the storey binds the field — walls, finishes, floors,
  trims, and every prop (580–711 materials on F02).
- **Radiant.** In the surface, six taps around each pixel take the body
  nearby as a glow that tints and lights what the organism has not reached
  yet; in the world, up to three OmniLights per storey sit on its strongest
  nodes in its ink, so glass, colour-only props and the residents take the
  same light.
- **Pooled.** Gravity pulls every heading; the bottom slice holds body twice
  as readily and spreads it sideways, so the organism runs off the wall over
  the baseboard and pools on the floor (649 live floor voxels in the
  contract).
- **A gravity of its own.** `gravity_at(p, t, phase)` in the field and
  `os_gravity` in the surface, the same rule: the building's down bent by a
  drifting fbm (time the fourth axis, the shuttle phase the fifth), with an
  intensity 0.4–1.7. It sets the agents' pull and appetite (budget, step,
  deposit), the stain's **drips** (streaks along g, not down), the lean of
  the fingers, and where the body pools — up when it points up. Cached on a
  2 m lattice refreshed a few cells a tick.
- **The dream comes with it.** Where body and stain are both high the flesh
  shows under the body, gold leafs the veins, the front carries a weld's
  heat.

`v2_t60/sheet_v2_60s.jpg`: after 60 s with Mina and Juno both forced on
F02 — the 2A main room taken wall to sofa to floor in its violet, the dream's
tints where it has held, a fingered edge climbing, the pool at the floor and
its own light on the wall it is reaching; the corridor outside lit by that
light on its wainscot before the body arrives; the bedroom a room further
still untouched. `LivingFieldTest` 14/14 (2.6 ms a tick), encroachment
13/13, WalkTest PASS. Only the player's storey ticks in play (`LIVING_ALL=1`
ticks every storey, for frames).

## v3 — in someone else's flat (2026-08-22, third ruling)

*"Juno will report it and it has the chance of making a fixable condition
happen in the area."* `design/LIVING_FIELD_BRIEF.md` §6. The rule, not a
frame: `OrganismIncidents` surveys the storey's flats; a foreign organism
held in a flat makes its resident file a work order in their voice and
rolls a seeded chance of a fixable condition — the nearest appliance goes
to FAULT with a service point; the fix restores it, closes the order and
repels the organism from the flat (stain raised, body scrubbed).
`OrganismIncidentsTest` 18/18 (Juno reports Mina's organism in 2C; the
speaker is held; the fix drives 1,659 live voxels to 0 and leaves the
stain; the flat is not re-reported during the cooldown; the condition
re-arms from the ledger). In WalkTest FULL's ordinary campaign it fired
unprompted: Lena reported Mina's organism in 2B (the fridge held), Juno in
2C.

## LF-2 — the grammars ride the organism (2026-08-22)

The surface now samples the field *before* the grammar runs and hands
`os_encroach` the organism's sheet. Every grammar's spread is the larger of
its static foothold (the old spread × 0.45 when the field is on) and the
organism (× 0.8, so only the pattern's peaks ink and the organism's own
substance shows between them): Peter's docket is filed where the body is,
Juno's bands stand where it stands, Cal's arcs complete around it, Omar's
cracks load where it loads, Mina's wick marbles inside it. Where the
grammar has drawn, the body is a wet glaze over the ink rather than a tint
that flattens it. The walls speak their resident's language over whoever's
organism is there — Juno's bands on Mina's violet.

`lf2_ride/sheet_lf2.jpg` (every case forced 0.9, 75 s of growth per stand):
2A west, the organism across the wall with Mina's ink marbled inside its
lobes and the wallpaper between them; 4A, Peter's docket grid as foothold
across the wall and the organism riding in from the corner; 2C, Juno's
bands faint as foothold, Mina's organism pooled over her floor and props;
5B, Cal's arcs as foothold by the window, the organism this run still
beyond the partition at 75 s (growth is not frame-locked, so it varies
between runs) with its light on the far ceiling. `_first/` is
the pass before the foothold step-back (the static docket at 0.9 still
covered the wall); `_rings/` the 5B frame before the ceiling rings were
softened (the stain's drip relief now only where the film is thick).
