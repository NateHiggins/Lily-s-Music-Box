# LIVING FIELD — the encroachment as a slime mould

Owner direction 2026-08-22: *"I want it to flow over every nearby surface
continuously, with an active, animated edge, leaving a viscous stain where
it approaches and recedes like an active living thing; research how slime
molds grow and design a procedural growth and spread system from that."*

## 1. What a slime mould actually does (the research)

*Physarum polycephalum*, the plasmodial slime mould — one giant cell, a
network of veins with a foraging front.

1. **Shuttle streaming.** Protoplasm is pumped back and forth through the
   vein network by rhythmic contraction of the cell's actomyosin cortex,
   reversing direction with a period of roughly 60–120 s. The whole
   organism breathes; the front advances on one half of the cycle and
   settles on the other. (Kamiya 1950s; Alim et al. 2013, PNAS, on peristaltic
   flow in the network.)
2. **A fan-shaped front, a network behind.** The growing margin is a
   continuous sheet with finger-like lobes; behind it the sheet resolves into
   veins. Veins that carry flow thicken; veins that do not are withdrawn.
   This is the "network optimisation" that famously reproduced the Tokyo
   rail system (Tero et al. 2010, Science): reward strengthens a tube, and
   unrewarded tubes are resorbed.
3. **Chemotaxis toward food, and retraction.** The front grows toward
   attractants (nutrient gradients) at roughly 1 cm/h, and the organism
   **withdraws** from regions that stop paying, pulling its protoplasm back
   through the veins it keeps.
4. **The slime trail as externalised memory.** Wherever the plasmodium has
   been it leaves a sheath of extracellular slime, and it **avoids its own
   trail** — negative chemotaxis to deposited slime (Reid, Latty, Alim &
   Beekman 2012, PNAS, "Slime mold uses an externalized spatial memory to
   navigate in complex environments"). That single rule makes it explore
   outward rather than re-cover old ground, and makes the stain it leaves a
   record of where it has been.
5. **The agent model that reproduces all of this** (Jones 2010, *Artificial
   Life*, "Characteristics of pattern formation and evolution in
   approximations of Physarum transport networks"): particles with a
   position and heading sense a diffusing, decaying *chemoattractant trail*
   at three offsets ahead (forward, ±sensor angle, sensor offset ~9 cells),
   turn toward the strongest, step, and deposit trail where they stand.
   Diffusion (a mean filter) plus decay (~0.1 per step) on the trail, and the
   swarm self-organises into fans, fronts and vein networks. Typical
   parameters: sensor angle 45°, rotation 45°, step 1 cell, deposit 5.

## 2. The design: `LivingField`

One field per case flat, owned by `ApartmentEncroachment`, simulated on the
CPU at 8 Hz on a coarse 3-D grid over the flat's volume (the unit rect by
the storey's 3.2 m, 0.2 m voxels), uploaded as a 3-D texture the layered
surface samples in world space — the same mechanism `DreamExposureField`
already uses for the lamp. Every surface inside the volume reads the same
field, so the organism flows over walls, finishes, floor and props
continuously, and the edge is wherever the field's isovalue falls.

Three channels:

| channel | what | dynamics |
|---|---|---|
| **trail** (`T`) | Jones' chemoattractant | agents deposit; diffuses (6-neighbour mean every step); decays 0.10/step |
| **body** (`B`) | the live plasmodium — what the surface shows as flesh/ink | recent agent density; decays 0.25/step so it *recedes* when the agents leave |
| **stain** (`S`) | the extracellular slime — the viscous residue | integrates body slowly (+0.12·B), decays 0.004/step (minutes), **repels** agents (Reid 2012) |

Agents (Jones particles, in 3-D): position, heading (unit vector). Each
step: sense `T − 0.6·S + food` at five offsets (ahead, and ahead tilted
±45° in two planes); turn toward the best; step 1 voxel; deposit trail;
if the trail under it is near zero for a while, **die**; new agents are born
where the body is strongest (the veins) and at the **source** — the case's
beachhead prop — which also deposits food continuously. The agent budget is
`60 + 540·intensity`, so a case's stage sets how much organism there is;
lowering it makes the swarm starve back toward the source and the body
recede, leaving the stain.

**Shuttle streaming** is a global modulation: a 14 s cosine on step size
and deposit (fast on the outward half, slow on the return), and the
surface's isovalue breathes with it, so the whole front advances and
settles together while the fine edge fizzes.

## 3. The surface: the `living` state of `orison_surface`

`living_tex` (RGB = trail, body, stain), `living_origin/size` (the flat's
volume), `living_tint` (the case's ink), `living_stain_tint`.

- **Body** → the case's substance: the plate-tinted ink (or flesh in the
  dream), fully where `B` is past the isovalue, with an **active edge**: the
  isovalue is perturbed by a 3-D noise of world position advected by time
  (fizz at ~1 Hz, fingers at ~0.15 Hz) and by the shuttle pulse, and the band
  just outside the front carries Mina's leader lines / the case's grammar
  lines as before. Wet film on the body: roughness 0.18–0.3.
- **Stain** → the viscous residue: albedo darkened toward the stain tint by
  `S`, roughness pulled toward 0.12 (a gloss), a soft normal flattening (a
  film), metallic 0. It stays after the body leaves and fades over minutes.
- On a cutout finish the body restores torn plaster as a membrane, as the
  wick did.

The per-case grammars (WK-1) stay as the organism's *texture*: its ink, its
lines, its tints. What the grammars drew statically, the field now drives.

## 4. What it is not

No collision, no gameplay owner, no save key: presentation only, like the
encroachment it replaces. The field is bounded by the flat's volume; it does
not enter the corridor. Cost: one 3-D texture fetch per pixel on surfaces
inside a case flat; the CPU step is a few hundred agents and ~30 k voxels at
8 Hz per active case.

## 5. The second ruling (2026-08-22): anywhere, radiant, pooled, and a gravity of its own

*"It can go anywhere it wants and spreads the connection to the dreamworld.
I need all these things to affect meshes close by too, give them 3D radiant
effects. I want it to spill over the baseboard and pool on the floor. Give it
variable, disorienting gravitational-like effects, vector and intensity
varying according to elaborate higher-dimensional logic that also influences
the encroachment's spread and nature."*

### a. Anywhere — one field per storey

The field is no longer the flat's volume: it is the **storey's** (27 × 19 m
by 3.4 m at 0.5 m voxels, ~21 k cells) with one source per case on that
storey (the beachhead), so the organism can leave the flat, take the
corridor, and enter the next flat. Agents carry the index of the source
that bore them; the texture's fourth channel is that index, so the surface
tints the body by **whose** organism it is (Mina's ink, Juno's cloth). Every
layered material on the storey — walls, finishes, floors, trims, props —
binds the storey's field.

### b. The connection to the dream

Where the organism has been longest — body and stain both high — the
surface shows the **dream's own states**: the flesh (purplish tissue) under
the body, gold leaf on the veins, a weld-heat lip at the front. The
organism is the dream's reach into the waking building, and the longer it
holds a surface the more that surface is the dream's.

### c. Radiance — affecting the meshes nearby

Two mechanisms. In the surface: a **volumetric glow** — each pixel samples
the field at six offsets around it (±0.4 m) and takes the body there as
light, so a wall, a floor, a chair *near* the organism is tinted and lit by
it before it arrives, falling off with distance. In the world: the
encroachment keeps up to three **OmniLights per storey** at the organism's
strongest nodes, in its tint, energy from the body, range 2.5 m — so meshes
that do not wear the layered surface (glass, colour-only props, the
residents) take the same light.

### d. Gravity that is not the building's

A vector field **g(x, t)** over the storey, in the surface and in the
simulation from the same rule: the building's down, bent by a
three-octave fbm of position drifting in time (the time axis is the fourth
dimension of the noise; the case's phase its fifth), with an **intensity**
0.4–1.7 from a slower second field. It is never the same twice in a room
and it is not down. It drives:

- **spread** — every agent's heading is pulled along g each step; where g
  points down the organism runs off the wall, **spills over the baseboard and
  pools on the floor** (the bottom slice holds body twice as readily and
  diffuses it sideways); where g bends sideways it sheets across a wall;
  where it points up it climbs and pools on the ceiling;
- **nature** — g's intensity is the organism's appetite: the agent budget,
  the step length and the deposit scale with it, so it surges where the
  field is strong and goes quiet where it is weak;
- **the surface** — the stain's film **drips along g** (streaks, not down),
  the body's lip and the flesh lean with it, and the radiance is pulled the
  same way, so what the player sees of "down" near the organism is wrong in
  a way that is consistent between the stain, the light and the growth.

Presentation only, still: no collider, no player physics, no save key.

## 6. The third ruling (2026-08-22): what it means in someone else's flat

*"Juno will report it and it has the chance of making a fixable condition
happen in the area."*

The organism is now a gameplay object in exactly one way: **trespass**.
`OrganismIncidents` surveys every occupied flat on a living storey
(`LivingField.survey`: whose body, how much, where) twice a second.

- **The report.** A foreign organism held in a flat — six live voxels for
  twenty seconds — is noticed by that flat's resident, who files a simple
  work order on the maintenance spine in their own voice (Juno hears it on
  the patch cables; Lena finds it along the skirting; Peter encloses a
  form). A resident never reports their own organism; the ink on their own
  walls is their case, not a complaint.
- **The chance.** The report rolls a seeded 55 % (the dream seed, the flat,
  the report count — the same on a reload; rolled again every 45 s while the
  trespass persists) of a **fixable condition in the area**: the domestic
  appliance nearest the organism's strongest point in the flat stops
  working — `FunctionalProp.FAULT`, the fault Omar's intrusions already
  throw — and carries a service point. Fixtures, doors, lifts and the
  Vantry points keep their own contracts and are never the condition.
- **The fix.** E on the point restores the appliance, closes the order, and
  **drives the organism out of that flat**: `LivingField.repel` scrubs the
  body, zeroes the trail, starves the agents inside, and raises the stain —
  the extracellular slime Reid's Physarum avoids — so the flat stays
  repellent until the stain has faded over minutes. A report without a
  condition closes itself once the flat has been clear for 30 s. 120 s
  cooldown per flat.
- **The ledger** is `organism_incidents` in RealityState (count, order,
  whose organism, the condition, the prop path, fixed/closed); an unfixed
  condition re-arms on load. Presentation stays the encroachment's; the
  rule owns nothing visual.
