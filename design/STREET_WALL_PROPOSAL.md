# The street wall — framing the arcade gate and closing the city illusion

*Proposed 2026-08-16. A systematic facade-continuity design for the STREET
play area, surveyed from eight fixed camera stations in production night
lighting (`game/tests/gateway_shot.gd`, renders in
`art/renders/street_facade_survey_v1/`). This extends
`design/VANTRY_GATEWAY_AND_SUBWAY_PROPOSAL.md` §3.1 — which is diagnosis and
vocabulary, already owner-reviewed at Gate A — into a complete perimeter
doctrine. No geometry changes in this document; it needs the owner's ruling
on §6 before anything is built.*

---

## 1. The survey — what the camera actually finds

The eight stations are fixed and reusable, so every claim below has a frame
and every future fix has a before/after. The north side is the control: shot
`04_from_gate_to_orison` reads as a city street with no caveats — full-height
frontage at the pavement, neon at two depths, tenement backdrop behind, no
sky touching a parapet at eye level. **That shot is the standard the south
side has to meet.** Against it:

- **A. The gate host is one storey short.** (`01`, `02`, `05`) K0's blockout
  works at arm's length — brick piers, corrugated soffit, recessed glazing,
  the shielded globe, the EXIT kiosk beside it. But the parapet tops out just
  above the 4.38 m head and open sky sits directly on it, with the pale
  backdrop slabs floating detached behind the roofline. §3.1's own
  prescription — "a real cornice/parapet … closing the skyline gap" on a
  **two-storey** frontage — is the unbuilt half, and it is the half that kills
  the "pasted portal" read from any distance beyond arm's length.
- **B. The east residual strip is a placeholder in plain view.** (`02`, `08`)
  From x 17 to the stage edge at 20.6 the frontage is a flat pale slab with
  two token windows: no reveals, no relief, no ground-floor anything. At
  pavement range it reads as untextured blockout, which it is.
- **C. West of the Harukiya there is no frontage at all.** (`03`, `06`) From
  the Harukiya's west party wall to the stage edge at x −20.1 the street is
  closed by the 2 m timber hoarding alone, with dark air behind it, then the
  detached backdrop slabs. Three unrelated planes with sky between them —
  the "set edge" read, visible from the shelter, the zebra and the Orison
  steps.
- **D. The near backdrop is unfinished-looking and floats.** (`06`, `07`)
  The pale masses behind the south boundary have flat albedo, sparse
  unreveal-ed windows, single-step rooflines, no chimneys or tanks, and stand
  clear of the play boundary with visible ground gaps. From the high oblique
  (`07`) the largest of them looms directly over the shelter as an obvious
  card. The north side's backdrop (with its fire escapes and varied windows)
  shows the treatment that works.
- **E. The ends terminate in furniture, not architecture.** (`06`, `08`)
  At x ±20.1/20.6 the boundary hoarding and storm meet low silhouettes and
  sky. The storm family (T8) is doing its job; what is missing is a tall
  corner mass for the weather to happen *between*.

## 2. The doctrine

One law, stated once and applied everywhere:

> **Every sightline from the play volume terminates on authored architecture
> or on weather — at pavement height AND at the skyline — and adjacent
> masses share party-wall edges with no daylight between them.**

The north side already obeys it. The south side gets there with a three-layer
system, mirroring what shot `04` proves works:

### Layer 1 — frontage (the meter the player can touch)

- **The gate's upper storey.** Continue the host masonry from the existing
  parapet up to a ~9.5 m cornice line across x 6.4..20.6 — Harukiya party
  wall to stage east edge, one continuous band over portal, kiosk and east
  strip. Window grid with recessed 100 mm reveals (fake depth, no
  interiors), WindowGlow-eligible lit quads on the existing emissive-window
  system, the §3.1 VANTRY ARCADE lintel/mosaic on the portal bay. This
  single band resolves findings A and B's skyline half.
- **East strip ground floor** (x 17..20.6): two shuttered storefronts in the
  Passage's own night vocabulary — PS6's folded-lattice grilles, dark
  transoms, one painted fascia each — plus a downpipe and drain per §3.1's
  rain logic. Dead frontage, honestly dressed: no new venues promised, no
  interiors, no collision beyond the existing containment plane.
- **West strip frontage** (x −20.1..−12): a NEW shallow two-storey
  commercial row at back-of-pavement, butted to the Harukiya's west party
  wall — shuttered shops or a warehouse/loading face (owner's pick, §6).
  The existing hoarding stays in front of one bay as construction dressing:
  a 1928 street repair reads as period truth and keeps T4's containment
  exactly where it is.

### Layer 2 — the party-wall backstop (the skyline)

One continuous stepped masonry silhouette plane rising **directly behind**
Layer 1 with zero ground gap, spanning the full south side x −20.1..20.6:
12–18 m tall in 3–4 parapet steps, carrying the roofline items that make a
block read as inhabited — chimney groups, one timber water tank, cornice
returns — and a window grid at the north backdrop's density (emissive quads,
`_city_windows` vocabulary, no lights). Because it touches the frontage
roofs, sky can never sit on a playable parapet again, and the floating-slab
read of finding D dies from every angle including the high oblique.

### Layer 3 — the distance (already exists)

The existing far backdrop and skyline glow stay. The two pale near masses
either inherit the Layer 2 treatment (reveal strips, roofline items, albedo
variation) or move one fog band back — whichever measures cheaper; Layer 2
occludes their ground line either way.

### The ends

One tall corner "bookend" mass at each stage end (both sides of the
carriageway), meeting the T8 storm so the quiet dense weather reads as
falling between buildings rather than past the last flat. The hoarding and
shelter keep their jobs; they just stop being the tallest things at the
boundary.

## 3. Systematics — how it is built, in this pipeline's terms

- **One generator pass** (`street_wall_pass`, site_pass family) owns every
  Layer 1–2 record: coordinates from the constants above, never hand-edited
  JSON, one `streetwall_<mat>` buffer per material family so the whole
  system lands as a handful of merged draws.
- **Zero new `Light3D`.** Lit windows are emissive quads on the existing
  window system; the gate reuses its two shielded fixtures per §3.1; PS6's
  business-hours ownership is untouched.
- **Ownership discipline** (T7b/T7c law): all new buffers are STREET-owned,
  registered with bounded AABBs in the existing spatial gates so PASSAGE
  frames drop them; zero draws added to any PASSAGE station.
- **Performance contract**: ≤ +0.5 ms direct at the `WeatherPerf`
  north-pavement gate (half of T7's settled 0.88 ms headroom), proven by
  same-build fresh-process A/B pairs per the standing benchmark rules; ≤ 6
  new merged draws visible at street elevation.
- **Containment unchanged**: Layer 2 has no collision; Layer 1 collides only
  at the back-of-pavement plane where T4's timber works already do.
- **Fiction constraints**: 1928 Queens vocabulary throughout; signage
  limited to painted ghost ads and dead fascias (no new live venues, no
  screen-shaped anything per VIII.5.g); the arcade gate becomes a civic
  entrance *in a block* rather than a pavilion in a field.

## 4. Proof gates (each phase, before commit)

1. The eight survey stations re-shot — `gateway_shot.gd` is committed as the
   fixed rig — and diffed against `art/renders/street_facade_survey_v1/`.
2. `WeatherPerf` same-build A/B inside the +0.5 ms contract.
3. `StreetCoreVisibilityTest` extended for the new AABBs; Passage stations
   show zero new draws.
4. Containment, route, transit, lighting suites and WalkTest FULL green.

## 5. Phasing

| phase | scope | closes |
|---|---|---|
| **W1** | Gate upper storey + cornice band x 6.4..20.6, east-strip ground dressing | findings A, B |
| **W2** | South party-wall backstop plane + roofline items | finding D (south) |
| **W3** | West strip frontage row behind the hoarding | finding C |
| **W4** | Corner bookends both ends + near-mass retexture or fog push | findings D (west), E |

Each phase is independently shippable and independently reversible; W1 is
the single highest-value cut (it is the gate frame the whole question began
with).

## 6. Owner questions (blocking only W3's flavor, nothing else)

1. **West strip character**: shuttered shop row (more Vantry commerce,
   implies interiors that never open) or warehouse/loading face (mute,
   no promises)? The warehouse face is the safer fiction.
2. **Ghost-sign copy**: painted-ad texts on Layer 2 gables need the usual
   period sign-off (same review as the shop fascias got).
3. **Gate lintel**: confirm the §3.1 VANTRY ARCADE mosaic band carries to
   the new upper storey as drawn there, or stays at the current head height.
