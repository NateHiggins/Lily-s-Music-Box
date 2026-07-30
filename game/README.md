# Orison Apartments — Godot 4.5 Building Prototype

First-person navigable blockout of the full building, assembled from the
procedural art pipeline in `../art/` (see that README for regeneration).
Open this folder in Godot 4.5+ and press F5. You start in the lobby at
night.

## Controls

- **WASD** move · **Shift** run · **Space** jump · **C** crouch
- **Mouse** look (click to capture, **Esc** to release)
- **E** interact (elevator call buttons and cabin panel)
- **T** architectural walkthrough (guided camera tour; Esc exits)
- **L** flashlight · **V** noclip (debug) · **F1** debug panel

## What is alive right now

**The atrium stair (new):** the whole light court is now one grand open
switchback stair, basement to roof, wrapped around a 2.9 m square open
eye — look up from the lobby deck and you see six storeys of balustrade
and the skylight; look down from the roof and you see the lobby runner.
Each climb is 20 risers (160 mm rise, 324 mm going): a wide west flight
off the floor-level south deck, a full-width north landing at the half
level, and an east flight arriving on the next deck. Every deck opens
south through a court-wall archway into the elevator hall, so corridor ->
hall -> atrium is the same move on every floor (basement included). The
roof is genuinely accessible: the stair tops out inside a glazed monitor
with a door onto the roof, capped by a steel-ribbed skylight. The old
front and service core stairs are gone; their wells are solid slab again,
the south core is the elevator hall, the north core is a per-floor
utility room (trash chute, meter bank, mop sink) — and the slab slivers
that used to show as gaps between floors on the upper stories are closed:
every court opening is now flush with the wall faces.

**Architectural walkthrough (new):** press **T** (or the debug-panel
button) for a guided fly-camera tour — street elevation, lobby, up the
atrium stair floor by floor, into every hero apartment, 4B room by room,
out the roof monitor door, then the basement — with captions naming
each space and resident. The path is computed from `building_layout.json`
(the stair climbs use the real flight geometry), doors swing open ahead of
the camera, and Esc hands control back at any time.

**Surface detail pass (new):** every plastered wall now carries a
baseboard and cornice; corridors, cores and the stairwell wear a
dado-height wainscot band with cap rail (the reference stairwell's green);
rooms get real floor finishes (terrazzo ring corridors and lobby, oak
boards in apartments, ceramic in bathrooms); door reveals and window
frames/sills/glazing as before; a cornice band crowns the facade, a portal
surrounds the street entry, and the basement ceiling runs visible heating
mains, risers and conduit.

**Lived-in apartments (new):** every occupied unit is furnished as its
resident's home — beds with mattress/blanket/pillow, sofas, dining sets,
book-filled shelves, kitchens with counters/uppers/stove/fridge, rugs,
plants and wall art, palette-varied per unit so no two households read the
same. The heroes keep their signature clusters on top (Mina's caption
station, Juno's amp-strewn studio, Omar's workshop, Rhea's booth, Nadia's
plan table, Sacha's capture wall); 3C stays stripped to studs with
buckets and sawhorses, 5D is charred with soot shadows, 6D is crate
storage, and the lobby, community room, laundry and storage cages are
dressed to match.

**Parametric asset library (new):** every furniture piece and appliance is
now an original detailed model in the spirit of an iconic typology — see
`../art/docs/furniture_references.md` for the full design-reference table.
Bentwood-style café chairs with steam-bent hoop backs, pedestal dining
tables, spool beds with turned posts and spindles, armoires with raised
panels and brass knobs, steel-ladder shelving with individual jittered
books (one leaning per bay), Frankfurt-style flat-front kitchens with real
sinks and cross taps, enamel ranges with clock panels and bakelite knobs,
rounded-shoulder 1950s refrigerators with chrome pulls, porcelain pedestal
sinks and close-coupled toilets, and **a molded bakelite toggle switch on
both faces of all 94 doorways** (validated: switches = 2 × doors, every
occupied unit's bed/kitchen/bath/dining completeness and kitchen-trio
facing are asserted at generation time). The conductor props got the same
treatment: four-column cast-iron radiators with brass valve wheels,
porthole front-loader washers, articulated task lamps, batten fluorescents
with starter cans and pull chains, studio monitors with real cones,
ring-shroud floor fans, a riveted boiler with gauge and fire door, and
stile-and-rail door leaves with brass levers on rosettes.

**Complete apartment set (new):** every unit is modeled to its stack
archetype at the brief's real areas — A one-bedroom 74.9 m² (street), B
studio with sleeping alcove 56.8 m² (rear), C two-bedroom 85.7 m² (rear),
D one-bedroom + office 70.4 m² (street) — plus the locked "former suite"
storage room the 1927 subdivision stranded between A and B on each floor.
Unit states and resident identity are layered on: 2D is sealed (no
doorway at all), 3C stands vacant with exposed studs and debris, 5D is
fire-damaged, 6D is landlord crate storage, and the six hero apartments
carry their residents — Mina's ordered caption station (2A), Juno's
speaker-strewn studio (2C), Omar's workshop (3B), Rhea's vocal booth and
aligned playback pair (3D), Nadia's plan table (5A), Sacha's three-monitor
capture wall (6A). Speakers are a new conductor body: the cone thumps the
motif pitched low.

**Vertical slice (new):** apartment 4B is detailed to the brief's Section 4
plan — entry vestibule, bathroom, closet, galley kitchen, main room,
sleeping alcove, furniture — with its functional ensemble: the hero
**toaster** (full latch → coil → relay → pop cycle with 46 mm lever travel
and 4 mm overshoot; press E to run it; at infection > 0.4 its release
quantizes to the conductor), fridge compressor, twin monitors, box fan,
desk lamp, radiator under the rear window, and the **door anomaly** — a
door-shaped seam that only manifests above 0.75 infection, between the
workstation and the radiator.

**Case 01 at the desk (new):** interact (E) with the 4B workstation chair
to take Mara Chen's support call — a compact in-world port of the Audio
Virus prototype loop. Her breathing rides the same conductor clock the
building follows; isolating and capturing reveal the four-mark timeline
with its empty fifth slot; routing the loop moves the conductor's origin
to the desk so the building hears it through the electrical network; and
the three responses change real building state — Complete pushes
infection to 0.85, which is what lets the door anomaly manifest in the
wall. One outcome per case, latched. Esc steps away; the call continues.

**Room 0 (new):** once the door anomaly is manifest, interact with the
seam to step through into the hidden room — a pocket space held open by
the building's infection, where the wall seams pulse with the motif
directly (no translation profile: the room *is* the motif). Leave by the
far seam, or let infection drop below 0.7 and the room collapses,
ejecting you into a very slightly incorrect apartment: the conductor's
tempo returns 0.8 BPM wrong, permanently.

**Networked propagation (new):** motif events no longer broadcast — they
are injected at an origin node (default: the basement boiler) and travel
`acoustic_graph.json` with per-node delays and damping. A knock reaches
Floor 5's radiator ~117 ms after Floor 2's; the sweep is audible if you
stand in the stairwell. Debug panel: toggle networked/global, switch
origin (boiler / 4B radiator / F04 corridor light).

- All eight levels (basement → roof) walkable: ring corridors, the atrium
  stair (physically climbable, ramp colliders, fall-guarded eye), the
  elevator (call it, ride it, B1–F6, arrival bell).
- **The unseen conductor** (`Conductor` autoload): BPM clock + the
  `incomplete_knock` motif loop. It *requests* events; props translate
  them through mechanical profiles (`data/prop_catalog.json`) — action
  rate limits, response latency, receptivity. Raise the Infection slider
  in the debug panel and stand in a corridor: radiators knock the motif,
  fluorescents dip on its accents, the basement boiler answers late and
  heavy, laundry drums thump. At 0 infection the building is just a
  building.
- 38 functional props spawned from the shared layout markers: 23
  radiators (every unit + lobby), corridor fluorescents, the 4B desk
  lamp, washers/dryers, the boiler.
- Acoustic graph (`data/acoustic_graph.json`, 40 nodes): heating risers
  H-A…H-D chaining radiators to the basement headers and boiler. Debug
  overlay draws the networks in 3D.
- Debug panel: floor teleports, BPM, infection, show-all-floors,
  acoustic overlay, mute, position/FPS.

## Tests

```bash
godot --headless --path game --import                     # first time
godot --headless --path game res://tests/WalkTest.tscn    # 64 checks
xvfb-run godot --path game res://tests/Screenshot.tscn    # doc renders
```

WalkTest validates floor collision on every level, apartment slabs, prop
spawning, the conductor clock, a *physical* climb of the new dog-leg
F1→F2 by the real player capsule, elevator travel B1↔F6, acoustic graph
connectivity, the vertical slice, Case 01 end-to-end, Room 0, and the
architectural walkthrough. Exit code = failure count.

**The lighting model (new):** 112 period fixtures across seven original
types — fabric drum pendants (living rooms), opal flush domes (bedrooms,
halls), milk-glass sconces over every bathroom mirror, enamel kitchen
linears, caged vapor-proof bulbs (basement/utility, they swing on motif
accents), a six-arm brass chandelier in the lobby, and long-drop globe
pendants down the atrium eye. Every fixture is a conductor body
(filament class: motif events surge the envelope and sway the drops).
Light quality is faked ray tracing on the compatibility renderer, by
design: a LightRig spends the light budget on the 14 nearest fixtures
(10 more at reduced energy, everything else keeps only its emissive
envelope + additive halo so it still reads as ON), the nearest six gain
a dim floor-tinted counter-light that fakes the first bounce, and the
three nearest eligible fixtures cast sticky, Compatibility-safe cubemap
shadows. Every fixture family participates, and a short distance cutoff
prevents lights in adjacent rooms from stealing the shadow budget. The
exterior moon casts tuned directional shadows, while the Blender build
bakes the rest of the GI impression into geometry: radial contact-shadow
quads under every furniture assembly and gradient AO strips along every
wall/floor junction. Environment retuned to match — lower flat ambient,
gentle depth fog, soft glow so bright sources bloom.

**Textured (new):** every mesh now carries deterministic world-projected
UVs and the full PBR texture pipeline — 24 texture sets (plaster, brick
families, oak, terrazzo, wainscot green, walnut, upholstery, aged enamel,
brushed steel, galvanized metal, bakelite and more) with albedo,
roughness and tangent normals, plus pre-composited stain/wear passes
(scuffed plaster, water-bloomed basement concrete, greasy appliance
enamel, rust-run utility metal, chipped wainscot). Floors export as
.gltf with one shared texture directory; see
`../art/textures/README.md` for the mapping and how to add a material.

## Performance snapshot (furnished)

- Whole building: 325 meshes, ~225,500 triangles, ~16 MB geometry + 50 MB shared textures —
  still light for a full furnished building. Detailed furnishings render
  without collision; each assembly carries one invisible coarse hull for
  physics instead of trimesh furniture.
- 38 audio emitters, all procedural `AudioStreamWAV` (mono 22 kHz),
  synthesized at startup; no audio files on disk
- Coarse floor visibility keeps ≤3 floor scenes rendered while walking

## Structure

```
scenes/building/orison_root.tscn   thin root; building_root.gd assembles
scripts/building/                  assembly, elevator
scripts/audio/                     conductor clock, acoustic graph, synth
scripts/props/                     FunctionalProp base + radiator, lamp,
                                   corridor light, washer, boiler
scripts/tour/                      architectural walkthrough (T)
scripts/player/player_controller.gd
data/*.json                        copied from art/data (single source)
tests/                             WalkTest, Screenshot drivers
docs/screenshots/                  rendered from the real build
```

## Screenshots

![exterior](docs/screenshots/b_01_exterior_street.png)
![lobby & grand stair](docs/screenshots/b_02_lobby.png)
![the atrium stair](docs/screenshots/b_05_front_stair.png)
![the atrium eye](docs/screenshots/b_18_atrium_eye.png)
![half landing](docs/screenshots/b_16_stair_half_landing.png)
![corridor](docs/screenshots/b_03_corridor_f04.png)
![2A living room](docs/screenshots/b_17_2a_mina_living.png)
![acoustic graph](docs/screenshots/b_08_acoustic_graph.png)

## Known limitations

See `../art/README.md` — additionally: elevator has no doors/interlocks
yet (open shaft-front cabin), and night lighting is minimal (flashlight
recommended indoors; the walkthrough brightens nothing — it tours the
building as it is).
