# Prop modelling and texturing brief - 2026-09-18

Evidence class: **BRIEF - INERT - PROMOTES NOTHING**

## How this brief was made

Every registered prop kind was built once in the inspection shed and
photographed alone from four bearings under a camera-carried fill, with the
camera distance derived from the specimen's own bounds. The harness wrote a
manifest with each specimen's mount, bounds in metres and a material census.
For every specimen, licence-clean reference photographs and period catalogue
plates were fetched from Wikimedia Commons under queries authored from the
prop script and `design/PROP_REFERENCE_NOTES.md` (nine families adversarially
verified against the geometry the script builds; the rest flagged unverified
in `tools/prop_reference/queries.json`), then laid beside our frames on one
sheet per specimen. A reviewer scored each sheet on seven axes under
`tools/prop_reference/CRITIQUE_CONTRACT.md`. The ranking is a formula over
those scores and repository facts, not a vote. Everything is reproducible with
`tools/prop_reference/README.md`.

Counts, so the reader knows the size of the survey rather than the size of
the opinion:

| what | count |
|---|---:|
| registered prop kinds | 44 |
| shed specimens (kinds x variants) | 69 |
| frames photographed | 269 |
| specimens that drew nothing standalone | 2 |
| families whose queries were adversarially verified | 9 of 36 |

## What photographing the shed found before any prop was judged

The instrument had to be corrected four times, and each correction is a
finding about the shed, not about a prop:

- **The shed placed props after adding them.** A door leaf is an
  `AnimatableBody3D` with `sync_to_physics`, which does not follow a parent
  moved after it entered the tree. Every door frame stood on its plinth with
  its leaf at the shed origin. Fixed in `prop_warehouse.gd`: place first, as
  the layout does. Any earlier warehouse render of a door showed a frame
  without a leaf.
- **The front door was built six times.** `LandmarkEntryDoor` inherited
  `DoorProp`'s six inspection variants. It now declares one.
- **The four box fans were one fan.** `boxfan_prop.warehouse_variants()`
  returned rows without `label` or `properties`, so the shed applied nothing
  and built the default fan four times. The earlier box-fan family review
  compared four identical fans. Fixed to the shed's contract.
- **Two props draw nothing outside the building.** `porch_deck` and
  `shop_sign` build from layout context the shed does not supply. They are
  listed at the top of the ranking by construction, because a specimen that
  cannot be inspected cannot be judged; the fix is a warehouse variant that
  supplies a minimal context, not a change to the prop.

Two texturing facts came out of the census rather than the pictures: the
hero front door reads 91% flat colour because its albedo map reaches one of
eleven surfaces after batching, and seventeen specimens, mostly lamps,
signage, the arcade chassis and the case props, carry no albedo map at all.

The reviewers found two more instrument facts while judging:

- **Some props were photographed from behind.** The harness's "front"
  bearing looks from the shed's aisle (+z). A prop whose tended face is
  authored at local -z and that declares no `warehouse_rotation_y()` (the
  stove, the boiler, both fridges and both kettles; the medicine cabinet,
  mail bank, flue breast and doors do declare it) shows the aisle its back,
  so its doors, valves, gauges and wear marks were never in frame. Their
  critiques say so and are capped at medium confidence. The harness now
  carries a fifth bearing from behind so a missing declaration costs a
  frame, not the comparison; this run predates it. The registration fix is
  one line per prop.
- **Two props the shed cannot show as built.** The case door keeps its
  leaf invisible until a scripted reveal, so every bearing framed an empty
  plinth and its critique is from the script. The neon sign is a 6.4 m
  blade whose bounds centre sits above the camera's eye line, so only the
  front bearing catches it, edge-on. Both need a warehouse variant that
  shows the object in its inspectable state, the same class of fix as the
  porch deck and shop sign.
- **The arcade cabinets booted their world.** The inspection camera is
  always inside an arcade machine's live range, so the machine package
  started under the prop node; two of the four chassis then reported
  level-sized bounds (about 400 x 4 x 45 m), a census full of level
  materials, and four empty frames, and the other two are visible in one
  bearing only. All four critiques are written from the script and the
  assembly rulings at low confidence. The shed needs the machine node held
  out of the bounds and the boot gated off for inspection.
- **The hero door's side bearing landed inside its jamb**, so that frame
  is black and three of four bearings show the interior face; its exterior
  pull, slot and lettering were checked in the script.
- **"Mount" is the shed's classification, not the layout's.** The shed
  hangs anything that builds downward from its origin on a soffit and
  stands anything that straddles its origin on a stub wall. The point ball
  therefore reads as a ceiling fixture though the layout places it on a
  rail, and the kitchen batten as a wall fixture. Reviewers scored mount
  against the geometry, not that label.

## Limits of this pass

- Commons full-text search is noisy. Where an authored phrase returned
  nothing, plain fallbacks ran, and some sheets carry an off-topic plate
  beside a good one. The critique names the references it actually used;
  the rest are on the sheet for honesty, not authority. For the five desk
  lamps every fetched reference was off-topic, so those five critiques
  lean on the notes' descriptions of the Emeralite, the friction-joint
  bench lamp and the Buquet pattern rather than on a photograph; three
  fixtures (flush dome, point ball, sconce globe) had no reference at all.
- Twenty-seven families' queries were authored but not adversarially
  verified, because the verification stage ran out of budget twice. Their
  `real_object` statements are the author's reading of the script and the
  notes, unchallenged.
- The shed is a lightbox. Finish that only reads under the building's
  tungsten and shadow is invisible here, and a prop that looks right here
  can still look wrong in its room. The brief says what to model and what to
  texture; it does not replace the installed before/after render the art
  brief requires for every change.
- Effort figures are a modeller-hour estimate from the critique, not a
  schedule.

Generated by `tools/prop_reference` from the warehouse manifest, the
licence-clean Wikimedia Commons references, and the per-specimen
critiques. Priority is deterministic: tier weight x installed factor x
measured gap, discounted for families a completed review already served
(see `tools/prop_reference/priority.py`). The photographs and the
reference sheets live outside git under `art/reference/props/_fetched`;
references are cited by Commons URL and licence.

Rules that bind every item below, from `design/PROP_ART_BRIEF.md`: props
are GDScript primitives, not imported meshes; new material keys go in
`MATERIAL_CATALOG` in `gen_layout.py` and through `ingest_material_sources.py`
(`SLOTS` + `GODOT_STAGE`) or they stay flat colour; verify by rendering,
never by reading code; horizontal metal uses `brass_dull`, polished brass
only vertical or hand-touched.

## Priority table

| # | priority | kind | variant | installed | tier | gap | flat colour | effort h |
|---:|---:|---|---|---:|---|---:|---:|---:|
| 1 | 7.33 | door | glazed storefront | 120 | touched_often | 1.74 | 25% | 3 |
| 2 | 7.30 | radiator | radiator / 7-section dark | 23 | carries_game | 1.85 | 50% | 5 |
| 3 | 7.30 | radiator | radiator / 9-section silver | 23 | carries_game | 1.85 | 50% | 4 |
| 4 | 5.75 | bookshelf | repaired shelf / Mina | 16 | touched_often | 2.01 | 0% | 4 |
| 5 | 4.84 | monitor | monitor | 5 | lighter_pass | 3.32 | 0% | 8 |
| 6 | 4.13 | boiler | boiler | 1 | carries_game | 2.07 | 16% | 10 |
| 7 | 3.96 | lamp | emeralite · the good reading lamp | 5 | lighter_pass | 2.29 | 100% | 4 |
| 8 | 3.92 | door | exterior service | 120 | touched_often | 1.43 | 0% | 2 |
| 9 | 3.92 | door | service leaf | 120 | touched_often | 1.43 | 0% | 3 |
| 10 | 3.91 | sink | sink / lavatory — legacy granular porcelain | 43 | carries_game | 1.28 | 27% | 0 |
| 11 | 3.85 | sink | sink / roll-rim kitchen | 43 | carries_game | 1.24 | 33% | 3 |
| 12 | 3.84 | pendant_shade | pendant_shade | 29 | leave_alone | 3.35 | 60% | 5 |
| 13 | 3.84 | lamp | buquet pattern · counterweighted | 5 | lighter_pass | 2.18 | 100% | 4 |
| 14 | 3.77 | shower | shower / curtain gathered | 23 | carries_game | 1.45 | 25% | 4 |
| 15 | 3.77 | lamp | office green · squared to the desk | 5 | lighter_pass | 2.12 | 100% | 3 |
| 16 | 3.67 | laundry_airer | laundry / rinse tubs + pulley airer | 1 | carries_game | 1.72 | 0% | 6 |
| 17 | 3.66 | lamp | friction joint · the bench lamp | 5 | lighter_pass | 2.03 | 100% | 3 |
| 18 | 3.53 | shower | shower / curtain drawn | 23 | carries_game | 1.29 | 25% | 4 |
| 19 | 3.47 | fridge | fridge / oak icebox | 18 | carries_game | 1.35 | 14% | 5 |
| 20 | 3.44 | door | 1928 apartment entry | 120 | touched_often | 1.13 | 0% | 4 |
| 21 | 3.44 | flush_dome | flush_dome | 90 | leave_alone | 2.22 | 20% | 2 |
| 22 | 3.43 | sink | sink / lavatory — calm fired glaze | 43 | carries_game | 0.99 | 27% | 3 |
| 23 | 3.35 | cage_bulb | cage_bulb | 77 | leave_alone | 2.22 | 29% | 3 |
| 24 | 3.33 | kitchen_linear | kitchen_linear | 10 | leave_alone | 3.62 | 33% | 3 |
| 25 | 3.28 | door | cabinet leaf | 120 | touched_often | 1.03 | 0% | 1.5 |
| 26 | 3.11 | fridge | fridge / 1927 monitor-top | 18 | carries_game | 1.10 | 33% | 4 |
| 27 | 3.00 | speaker | speaker | 7 | lighter_pass | 1.46 | 44% | 3 |
| 28 | 2.96 | exhaust_fan | exhaust_fan | 4 | lighter_pass | 1.75 | 0% | 6 |
| 29 | 2.89 | door | 1928 apartment interior | 120 | touched_often | 0.78 | 0% | 2 |
| 30 | 2.87 | landmark_entry | landmark entry / the Orison front door | 0 | touched_often | 2.28 | 91% | 8 |
| 31 | 2.86 | stove | stove / 1922 fired-enamel gas range | 18 | carries_game | 0.93 | 17% | 3 |
| 32 | 2.86 | flue_breast | sealed 1912 thimble | 5 | lighter_pass | 1.53 | 0% | 3 |
| 33 | 2.80 | lamp | stamped enamel · landlord supplied | 5 | lighter_pass | 1.28 | 86% | 2 |
| 34 | 2.78 | boxfan | boxfan / sacha nickel | 4 | lighter_pass | 1.58 | 0% | 2 |
| 35 | 2.78 | mirror | medicine cabinet / closed | 23 | touched_often | 1.25 | 29% | 3 |
| 36 | 2.76 | toaster | toaster | 14 | carries_game | 0.96 | 23% | 3 |
| 37 | 2.76 | bookshelf | open oak case / Iris | 16 | touched_often | 1.40 | 0% | 3 |
| 38 | 2.73 | mirror | medicine cabinet / open | 23 | touched_often | 1.21 | 29% | 4 |
| 39 | 2.62 | bookshelf | sectional case / Mae | 16 | touched_often | 1.28 | 43% | 4 |
| 40 | 2.59 | case_door | case_door | 1 | case_system | 1.62 | 0% | 4 |
| 41 | 2.59 | street_lamp | street_lamp | 5 | leave_alone | 3.16 | 25% | 3 |
| 42 | 2.59 | vantry_point | Vantry point / 1912 listening head | 0 | carries_game | 1.55 | 0% | 5 |
| 43 | 2.56 | arcade_cabinet | arcade_cabinet 0 · 1916 | 0 | lighter_pass | 2.85 | 94% | 6 |
| 44 | 2.54 | arcade_cabinet | arcade_cabinet 1 · 1924 | 0 | lighter_pass | 3.22 | 50% | 6 |
| 45 | 2.54 | arcade_cabinet | arcade_cabinet 2 · 1922 | 0 | lighter_pass | 3.21 | 45% | 6 |
| 46 | 2.46 | bodega_signage | bodega_signage | 1 | leave_alone | 3.97 | 100% | 8 |
| 47 | 2.38 | signal_terminal | signal_terminal | 1 | case_system | 1.40 | 50% | 5 |
| 48 | 2.37 | arcade_cabinet | arcade_cabinet 3 · 1922 | 0 | lighter_pass | 2.53 | 95% | 5 |
| 49 | 2.36 | sconce_globe | sconce_globe | 28 | leave_alone | 1.67 | 25% | 2 |
| 50 | 2.23 | ceiling_light | ceiling_light | 1 | leave_alone | 3.45 | 100% | 4 |
| 51 | 2.21 | kettle | kettle · polished nickel | 6 | touched_often | 1.34 | 0% | 3 |
| 52 | 2.18 | door_anomaly | door_anomaly | 1 | case_system | 0.93 | 100% | 2 |
| 53 | 2.16 | kettle | kettle · aged copper | 6 | touched_often | 1.29 | 0% | 3 |
| 54 | 2.12 | washer | washer / 1926 powered wringer | 2 | carries_game | 1.28 | 7% | 4 |
| 55 | 1.90 | darts | darts | 1 | leave_alone | 2.68 | 100% | 2 |
| 56 | 1.80 | wall_clock | clock / 8-day drop octagon | 2 | touched_often | 1.42 | 50% | 5 |
| 57 | 1.80 | wall_clock | clock / Vantry lobby master | 2 | touched_often | 1.42 | 50% | 4 |
| 58 | 1.63 | songbook_terminal | songbook_terminal | 1 | leave_alone | 2.08 | 100% | 4 |
| 59 | 1.58 | boxfan | boxfan / iris green | 4 | lighter_pass | 1.43 | 0% | 1 |
| 60 | 1.58 | boxfan | boxfan / juno black | 4 | lighter_pass | 1.43 | 0% | 5 |
| 61 | 1.50 | bar_signage | bar_signage | 1 | leave_alone | 1.78 | 100% | 6 |
| 62 | 1.50 | eye_pendant | eye_pendant | 8 | leave_alone | 1.15 | 50% | 2 |
| 63 | 1.49 | neon_sign | neon_sign | 3 | leave_alone | 1.20 | 100% | 4 |
| 64 | 1.49 | boxfan | boxfan / landlord plain | 4 | lighter_pass | 1.29 | 0% | 1 |
| 65 | 1.48 | point_ball | point_ball | 1 | leave_alone | 1.72 | 100% | 1 |
| 66 | 1.11 | mail_bank | mail_bank | 0 | touched_often | 1.28 | 46% | 5 |
| 67 | 1.05 | chandelier | chandelier | 1 | leave_alone | 1.32 | 16% | 3 |

## Not assessable in the shed

These kinds drew nothing standalone: their visible geometry comes from the
layout pass, not the script, so no comparison was possible. The finding is
about their inspection registration, not their modelling.

- **porch_deck** (porch_deck): Not assessable in the shed. porch_deck_prop.gd builds no geometry: _build_visual creates two AudioStreamPlayer3D emitters (a creak and a board thud) and the script's only behaviour is a 25-60 s wind-creak loop and the accent-driven knock. The five decks the player sees are baked by the layout pass into the floor shells, so a modelling or texturing change to the deck is a gen_layout and Blender change, not a prop change, and the interaction matrix rules the decks ambient architecture with no per-deck verb.
- **shop_sign** (shop_sign): Not assessable in the shed. shop_sign_prop.gd hangs Label3D lettering (name, trade line, blade text, tint) on a fascia board, blade panel and awning valance that gen_layout's shopfront pass bakes into the ground-floor shell; standing alone on a plinth with no marker it has no board to letter and no text to set, so it drew nothing. The lettering itself is ruled Label3D, never a texture, so there is no texturing brief for this kind at all; what a reviewer could judge is glyph style, colour and layout against the eleven shopfronts in situ.

## Specimens, in priority order

### 1. door - glazed storefront

- **Priority** 7.33 (gap 1.74, tier touched_often, installed 120, review discount 1.0)
- **What we have:** 0.99 x 2.10 x 0.17 m, floor mount, 1236 triangles, 4 surfaces, 25% flat colour
- **Real object:** A 1928 apartment-house contractor door: a standardized painted stile-and-rail leaf with two recessed fields, three mortised steel butt hinges and a knob on a long brass backplate over a mortise lock, hung in the building's older 1912 openings.
- **Confidence:** high

The field below the mid rail is an open hole: the oak carcass has rails centred at 0.065, 0.78 and 2.035 m but the glass box spans only 0.83-1.95 m, so from 0.13 to 0.715 m the leaf is empty and the shed floor shows through it in the front and high-quarter bearings. Object class is right (a narrow oak carcass around a plate-glass light with a brass pull bar), the push bar the variant names is missing, and the fix for the hole is one box.

**Modelling**

  - Close the lower field: one oak_quartered box (width - 0.19) x 0.585 x 0.030 centred at (width * 0.5, 0.4225, 0) as a flush oak panel; or, if the shop is to be seen to the floor, extend the glass box to (width - 0.19) x 1.84 centred at y 1.065 and drop the 0.78 rail to y 0.40 as a deep bottom rail - either way one primitive edit closes the hole.
  - Add the push bar on each face: a horizontal brass cylinder r 0.012 x (width - 0.34) at y 1.00 at z +/-0.07 with two standoff cylinders r 0.012 x 0.065 at x 0.17 and width - 0.17 (6 primitives); today both faces carry only the vertical 0.34 m pull bar.
  - Make the bottom rail a shop rail: raise the y 0.065 rail from 0.13 to 0.25 tall (centre y 0.125) and add a brass_dull kick plate box (width - 0.19) x 0.15 x 0.004 on the outer face at y 0.11, the deep footworn rail every store door on the two street plates shows (1 edit, 1 primitive).
  - Add the lock cylinder: a brass_dull cylinder r 0.016 x 0.006 proud of the outer face at (width - 0.16, 0.92, -0.03) below the pull bar's lower standoff; a shop leaf that locks at night has a visible cylinder (1 primitive).

**Texturing**

  - Glass: the flat alpha material at (0.16, 0.22, 0.20, 0.34) reads as murky teal film; plate glass is near-colourless with a faint green edge. Use albedo (0.80, 0.88, 0.84, 0.14) and roughness 0.06 so the interior stays visible and the pane reads as glass.
  - Brass bars: use 'brass' (metallic 0.85) rather than brass_dull for the vertical pull and the new push bars; these are the hand-polished vertical parts the brief reserves polished brass for, and the sheet's storefronts show bright bar hardware against dark frames.
  - Oak: keep oak_quartered at scale_mult 0.8 but tint the bottom rail darker, about (0.36, 0.25, 0.16), and lay a 0.30 x 0.20 x 0.001 'soot' decal at the foot of the lock stile so the varnish reads footworn where 13 shops' customers kick it.

**References used**

  - File:The Colonial Flats and Annex Jul 16.JPG - CC BY 2.0 - https://commons.wikimedia.org/wiki/File:The_Colonial_Flats_and_Annex_Jul_16.JPG
  - File:Delaware Avenue and Upper Street, Allentown, Buffalo, NY.jpg - CC BY-SA 2.0 - https://commons.wikimedia.org/wiki/File:Delaware_Avenue_and_Upper_Street,_Allentown,_Buffalo,_NY.jpg
  - (4 other plates on the sheet not relied on)

### 2. radiator - radiator / 7-section dark

- **Priority** 7.30 (gap 1.85, tier carries_game, installed 23, review discount 1.0)
- **What we have:** 1.08 x 0.69 x 0.36 m, floor mount, 6068 triangles, 18 surfaces, 50% flat colour
- **Real object:** A second-hand American Radiator Company-class plain three-column cast-iron sectional one-pipe steam radiator (Peerless/'American' plain column pattern; a 1912 original or a same-class second-hand replacement, never an ornate Rococo casting), floor-standing on integral cast loop feet with two light wall stand-offs behind the top header, bottom-fed at the marker's -X end through a dark brass angle valve, rising stem and six-spoke dark bronze-iron handwheel, joined by a union with a dull brass nut to a black iron branch from the building's 1912 riser, with a dull brass automatic air vent tapped into the far upper end and a downward rust track beneath it; the 1922 Corto catalog is cited only for header-shoulder and waist language, as the notes rule.
- **Confidence:** high

The finish is the most wrong thing: the section MultiMesh takes its albedo from the heat tint in _apply_visual_state (cold 0.30/0.32/0.34 to hot 0.93/0.48/0.23, at 0.82 heat on the supply end in the default 'sounding' condition) multiplied over the cast_iron plate, and the IRON_DARK and IRON_SILVER retexture rows match no mesh, so this 'dark' 1D body renders the same warm tan as the silver lobby variant and reads as a row of turned wood balusters, not black-japanned iron. Object class is right and stays as ruled (an ARCO-class joined-section one-pipe steam radiator with bottom angle valve, union, rising stem and six-spoke wheel, far-end automatic vent and cast feet); the execution gaps against the Steam Radiator and Cast Iron Radiator Refurbishment photographs are the 92 mm pitch that makes seven sections 552 mm across where a real three-column body is about 445, a lathed spindle with no through-voids between its three columns, and a union nut that on this count ends at x -0.38 with the end casting's surface at -0.321, 59 mm of daylight visible in the front bearing between the supply and the body.

**Modelling**

  - Pitch: SECTION_PITCH 0.092 to 0.064 (2.5 in centres). Seven sections then span 0.384 m, about 0.51 over the feet; shrink the x radii in _cast_section_mesh from 0.032-0.046 to 0.022-0.032 so the shoulders still touch at the new pitch, and keep the z radii (0.082-0.114) so the body stays 0.228 deep.
  - Through-voids: replace the single ten-ring lathe with three lathed columns per section (r 0.020, at z -0.075, 0 and +0.075, 0.42 m tall between the headers) under one top and one bottom header ellipsoid of 0.064 x 0.05 x 0.228, all five pieces in the one shared ArrayMesh so the MultiMesh stays one draw. The daylight between columns is what both reference photographs show from the front and what makes a section read as a casting rather than a spindle.
  - Union gap: derive the valve and union from the body, SUPPLY_X = -(half_width + 0.20) and the union at -(half_width + 0.06), and lengthen the branch cylinder back to the fixed RISER_X (-0.67), so the brass nut seats on the end section's bottom tapping at seven, eight and nine sections; today it only reaches the nine-section body.
  - Nipple joints: one Ø 25 x 8 mm dark cylinder between adjacent sections at the top and bottom header centres (12 for seven sections, in the shared mesh or a second MultiMesh) so the sections read pushed together on nipples instead of standing separately on the floor.
  - Handwheel: the make_ring(0.062, 0.009) plus six Ø 11 mm spokes is right at Ø 124 mm; keep it, retexture it (below).

**Texturing**

  - Wire the variant into the finish: choose a base tint from `unit` (1D and the flats: dark japan (0.18, 0.17, 0.16); LOBBY: silver (0.62, 0.63, 0.65)) and multiply it into the per-instance colour in _apply_visual_state, clamping the heat contribution to at most +0.15 luminance so heat reads as warmth on a black body rather than turning it orange. This stays inside cast_iron with no new key, as ruled.
  - Feet and dust shelf: the feet are built in `iron` (0.20, 0.205, 0.20), which fails is_equal_approx against IRON_DARK (0.16, 0.16, 0.17), so both foot cylinders and toe boxes stay flat #333433 (the census's two flat #333433 surfaces). Build them in IRON_DARK, or add an `iron` row, so they take cast_iron like the body.
  - Handwheel and hub in (0.27, 0.23, 0.16) match no row and stay flat #453b29: add a row to brass_dull tinted (0.45, 0.38, 0.24) at 0.72 (a dulled bronze wheel), the one part of this prop the player turns.
  - Wear as ruled for 1D: bare iron on the top header edges as a per-vertex colour array on the shared mesh (top 40 mm toward (0.45, 0.44, 0.42)); the foot rust box (0.105 x 0.006 x 0.17) already rides cast_iron at (0.48, 0.20, 0.10) but is a flat slab, so scale it to 0.06 x 0.004 x 0.10 and offset it toward the wall so it reads as bloom under a foot, not a mat.

**References used**

  - File:Steam Radiator.jpg - CC BY-SA 3.0 - https://commons.wikimedia.org/wiki/File:Steam_Radiator.jpg
  - File:Cast Iron Radiator Refurbishment.jpg - CC0 - https://commons.wikimedia.org/wiki/File:Cast_Iron_Radiator_Refurbishment.jpg
  - (6 other plates on the sheet not relied on)

### 3. radiator - radiator / 9-section silver

- **Priority** 7.30 (gap 1.85, tier carries_game, installed 23, review discount 1.0)
- **What we have:** 1.17 x 0.69 x 0.36 m, floor mount, 6068 triangles, 18 surfaces, 50% flat colour
- **Real object:** A second-hand American Radiator Company-class plain three-column cast-iron sectional one-pipe steam radiator (Peerless/'American' plain column pattern; a 1912 original or a same-class second-hand replacement, never an ornate Rococo casting), floor-standing on integral cast loop feet with two light wall stand-offs behind the top header, bottom-fed at the marker's -X end through a dark brass angle valve, rising stem and six-spoke dark bronze-iron handwheel, joined by a union with a dull brass nut to a black iron branch from the building's 1912 riser, with a dull brass automatic air vent tapped into the far upper end and a downward rust track beneath it; the 1922 Corto catalog is cited only for header-shoulder and waist language, as the notes rule.
- **Confidence:** high

Silver in name only: nothing in radiator_prop.gd reads `unit` LOBBY into a finish, the IRON_SILVER retexture row (0.62, 0.63, 0.65) is assigned to no mesh, and the nine castings carry the heat tint over the cast_iron plate exactly as the 1D body does, so the lobby radiator renders the same warm tan as the dark variant and reads as turned wood rather than landlord aluminium bronze over old japan. Object class is right and stays as ruled; against the Steam Radiator and Cast Iron Radiator Refurbishment photographs nine sections at 92 mm span 736 mm (about 866 over the 0.13 m toes) where a real three-column body is about 572, which also puts the feet 56 mm past the ruled 810 mm envelope, the spindle has no through-voids, and here the union nut does meet the end casting, by passing 33 mm into it rather than seating on a tapping.

**Modelling**

  - Pitch: SECTION_PITCH 0.092 to 0.064; nine sections then span 0.512 m, about 0.64 over the feet, back inside the ruled 810 mm envelope. Shrink the x radii in _cast_section_mesh from 0.032-0.046 to 0.022-0.032 so shoulders still touch; z radii and the 0.228 depth stay.
  - Through-voids: three lathed columns per section (r 0.020 at z -0.075, 0, +0.075, 0.42 m tall) under top and bottom header ellipsoids 0.064 x 0.05 x 0.228, five pieces in the one shared ArrayMesh, one MultiMesh draw as now.
  - Union: derive SUPPLY_X = -(half_width + 0.20) and the union at -(half_width + 0.06) from the section count and lengthen the branch to the fixed RISER_X; on nine sections the nut (x -0.43 to -0.38) currently overlaps the end casting (surface at -0.413) instead of seating on it, and on seven it floats 59 mm short.
  - Nipple joints: Ø 25 x 8 mm dark cylinders between adjacent sections at both header centres, 16 for nine sections, in the shared mesh.
  - The section count itself (nine) and the 0.67 m casting height are right for a lobby unit and stay.

**Texturing**

  - Wire the lobby finish: multiply the per-instance colour in _apply_visual_state by (0.62, 0.63, 0.65) when `unit` is LOBBY, with the heat contribution clamped to +0.15 luminance; keep cast_iron at roughness 0.72 so the silver reads as dull brush-marked bronze paint, never chrome. No new key, as ruled.
  - Earlier dark coat at chips: six 8 x 8 x 1 mm boxes on header edges and one foot toe tinted (0.18, 0.17, 0.16) through cast_iron, placed by hash(unit).
  - Painted-over fittings, per the variant note: for the LOBBY unit only, tint the valve bonnet, packing nut and air-vent brass_dull rows toward (0.60, 0.60, 0.58) so the landlord's silver runs over the brass as it did.
  - Feet (`iron` 0.20/0.205/0.20, flat #333433) and handwheel ((0.27, 0.23, 0.16), flat #453b29) miss every retexture row exactly as on the 7-section: build the feet in IRON_DARK and add a handwheel row to brass_dull (0.45, 0.38, 0.24).
  - Wear for a lobby: less rust, more scuffing. Shrink the two foot rust boxes to 0.05 x 0.004 x 0.08 and add a dust film on the top header (a per-vertex lightening of the top 30 mm toward (0.70, 0.70, 0.68)) and a scuffed toe on the aisle-side foot (tint band (0.50, 0.50, 0.48) on the toe box).

**References used**

  - File:Steam Radiator.jpg - CC BY-SA 3.0 - https://commons.wikimedia.org/wiki/File:Steam_Radiator.jpg
  - File:Cast Iron Radiator Refurbishment.jpg - CC0 - https://commons.wikimedia.org/wiki/File:Cast_Iron_Radiator_Refurbishment.jpg
  - (6 other plates on the sheet not relied on)

### 4. bookshelf - repaired shelf / Mina

- **Priority** 5.75 (gap 2.01, tier touched_often, installed 16, review discount 1.0)
- **What we have:** 0.75 x 1.22 x 0.28 m, floor mount, 492 triangles, 5 surfaces, 0% flat colour
- **Real object:** A rented-flat bookcase of 1927-28 Queens: either a dark-mahogany Globe-Wernicke-type glazed sectional (stackable units whose glass doors lift and recede) owned by the two better-off households, an inherited open quartered-oak case of 1900s-1910s manufacture, or a shelf patched together from salvaged boards and packing-case stock by the poorest tenants.
- **Confidence:** medium

No reference on this sheet shows a home-made board-and-crate shelf, so this is judged against the real_object text and the notes; the case reads as a dark walnut factory bookcase with one short side, not softwood salvage, and its two brass 'brackets' are straps stuck across the front of the wrong shelf. The object class is nominally right, but nothing in the silhouette, material or wear yet says repaired.

**Modelling**

  - Brackets: the two brass_dull bars 0.022 x 0.16 x 0.018 at x +/-0.24, y 0.47, z +0.137 stand 12 mm proud of the shelf fronts and straddle the y 0.43 shelf, reading as straps. Make each an L-bracket (vertical leg 0.022 x 0.12 x 0.018 against the inside of the side board, horizontal leg 0.10 x 0.018 x 0.022 under the shelf) and put both under the active y 0.82 shelf where the books are; 4 boxes merged into the same 1 mesh.
  - The 27 mm oak side ends at y 1.165 and the top shelf starts at 1.1765, leaving an 11 mm unsupported gap that reads as a build error; fill it with a visible folded-paper shim (paper box 0.027 x 0.011 x 0.08) so the gap becomes a repair.
  - All boards agree in width and are full-depth slabs; make the salvage read: split the y 1.19 top shelf into two 0.105 m slats with a 25 mm gap (2 boxes), cut the y 0.08 bottom shelf 30 mm short at one end, and notch one side board with a 0.036 x 0.30 x 0.012 wane - crate stock is narrow and irregular.
  - Fasteners: eight r 0.004 x 0.002 nail heads (brass_dull) through the side boards at each shelf end, merged into the bracket mesh; a repaired shelf shows what holds it.
  - Books float 26 mm: _book_y = 0.86 while the y 0.82 shelf (0.027 thick) has its top face at 0.8335; derive _book_y from the shelf surface.

**Texturing**

  - Sides and all four shelves are wood_dark (walnut albedo) with only the short side in oak_quartered; the real object is pine and packing-case softwood with one oak board reused. Invert it: shelves and the 36 mm side in oak_quartered tinted pale grey-pine (0.70, 0.62, 0.48) at scale 0.6, one board left in wood_dark, so the case reads as mismatched salvage rather than a matched walnut set.
  - Wear is uniform and factory-fresh in every bearing; salvage needs darkened end grain (tint 0.7 on 4 mm end-cap strips), a paler scuffed front edge on the y 0.82 active shelf, and a grey water ring under the left front foot - all as second tints of the two allowed wood keys, no new map.
  - Cover palette: the pastel spines on the linen batch read as modern; set HSV value 0.22-0.36, saturation 0.45-0.60 with hues from navy, maroon, green and brown.

**References used**

  - none relied on; the 5 plates on the sheet were off-topic

### 5. monitor - monitor

- **Priority** 4.84 (gap 3.32, tier lighter_pass, installed 5, review discount 1.0)
- **What we have:** 0.15 x 0.41 x 0.52 m, wall mount, 384 triangles, 4 surfaces, 0% flat colour
- **Real object:** A fictional Vantry compact domestic picture receiver: a self-contained tabletop set, overall about 0.52 W x 0.41 H x 0.15 D (case 0.52 x 0.36 x 0.10 plus foot and knobs), in a dark phenolic Bakelite case (MatLib bakelite_black tinted 0.46/0.44/0.40) with a dull stamped-brass bezel plate (brass_dull tinted 0.55/0.50/0.38) and two 48 mm-diameter Bakelite knobs low on the front corners (power left, tuning right; tuning turns 38 degrees on E), line-fed (LINE LIVE), showing a green-teal monochrome picture from one of eight found-art tiles on a 0.39 W x 0.25 H landscape plate (about 18 in diagonal, despite the '13-inch portrait' code comment) whose face sits 2.5 cm proud of the case face and 8 mm proud of the bezel. Under the Rule of Signal it is a CRT-class valve receiver forty years early (ceiling about 1968) dressed per VIII.4, so the nearest real objects are the 1946-1955 Bakelite direct-view tabletop valve sets (Bush TV22 class; American 7-10 inch tabletops such as the RCA 630-TS for proportion and control layout), NOT the mechanical Baird Televisor, NOT a mirror-lid or floor console, NOT a portable or transistor set. Any stand or cabinet is the room's second-hand furniture, not part of the prop. Whether the domestic receiver's mask should be round per VIII.5.g remains unruled; the build is a rounded-rectangle landscape plate. It is a distinct object from the household television (TVProp: 0.50 x 0.90 glass in a floor-mesh cabinet showing the broadcast director's shared feed).
- **Confidence:** high

It reads as a present-day flat panel on a pedestal stand with a gilt frame: a 0.10 m deep slab whose 0.39 x 0.25 m picture (about 18 in) covers three quarters of the face and stands 25 mm proud of it, on a 0.24 x 0.12 m central foot, where the RCA 630-TS on this sheet is a cabinet as deep as it is tall with a small round-cornered mask, a cloth grille beside it and a row of knobs below. The ruled object class (a 1946-1955 Bakelite tabletop valve receiver of the fiction, never a present-day flat display) is right in intent and in the bakelite_black and brass_dull keys, but the built shape is the excluded one, and the brass_dull bezel tinted 0.55/0.50/0.38 at scale 0.58 reads as burl veneer rather than stamped brass.

**Modelling**

  - Depth: add a tube housing behind the case, make_box(0.30, 0.28, 0.30) at x -0.20 (the case is 0.10 deep with its face at +0.05), or grow the case to 0.42 deep; either is 1 box and gives the side bearing the neck that makes a receiver.
  - Picture: shrink the plate from 0.39 x 0.25 to 0.26 x 0.195 m (about 12.8 in, still 'better than it should be' against the 10-in 630-TS) and sink it to x +0.041 so it sits 9 mm behind the bezel face instead of 25 mm in front of it. The mask outline (round per VIII.5.g or the present rounded rectangle) is unruled and is not decided here.
  - Bezel: the 0.46 x 0.30 x 0.018 brass plate becomes a frame of four boxes 0.018 thick around the 0.26 x 0.195 opening plus a 0.14 x 0.22 x 0.006 speaker-grille box to its right, as the 630-TS lays out: 5 boxes for 1.
  - Knobs: two Ø 48 mm at the lower corners become four Ø 36 mm make_cyl(0.018, 0.018, 0.022) in a row under the mask at x +0.056, y -0.15, z -0.10/-0.035/0.035/0.10 (on-off/volume, contrast, brightness, tuning); the tuning knob keeps its 38-degree verb and stays outside the merge.
  - Foot: replace the 0.24 x 0.055 x 0.12 central pedestal with four Ø 30 x 12 mm Bakelite feet make_cyl(0.015, 0.015, 0.012) under the case corners so it stands like a set on second-hand furniture, not a monitor on a stand: 4 cylinders for 1 box.
  - Service back and flex: make_box(0.50, 0.34, 0.006) behind the housing with four Ø 6 mm screw heads and six 0.20 x 0.008 x 0.002 slot boxes tinted darker (11 primitives), and a cloth flex make_cyl(0.004, 0.004, 0.30) leaving the lower back corner (1 primitive): VIII.4's slotted screwed-on back and braided flex.

**Texturing**

  - Bezel/frame: brass_dull at tint (0.55, 0.50, 0.38) and scale 0.58 mottles into tortoiseshell over a 0.46 x 0.30 plate; use (0.78, 0.68, 0.44) at scale 1.0 as tap_prop does, and the narrower frame shows less of the mottle.
  - Case: bakelite_black at 0.46/0.44/0.40 reads as dark grey plastic; VIII.4 Bakelite is warm brown-black chipped white at the edges, so tint (0.40, 0.34, 0.28) and add four 2 mm edge strips along the front top and side edges tinted (0.80, 0.78, 0.72): the chips.
  - Wear as ruled (twenty years old, repaired by four people): one mismatched knob tinted brown Bakelite (0.55, 0.35, 0.20), one replaced screw head on the back in nickel_plated, and one scuff on the top face as a 0.08 x 0.06 tint patch (0.52, 0.48, 0.42): 3 tints, so the set stops reading factory-fresh.
  - Screen: the found-art tile as albedo and emission and the green-teal (0.38, 0.62, 0.52) glow are the ruled picture and stay; the OmniLight pool moves with the recessed plate.

**References used**

  - File:RCA 630-TS Television.jpg - CC BY-SA 3.0 - https://commons.wikimedia.org/wiki/File:RCA_630-TS_Television.jpg
  - File:MoMI RCA TV.JPG - CC BY-SA 3.0 - https://commons.wikimedia.org/wiki/File:MoMI_RCA_TV.JPG
  - (2 other plates on the sheet not relied on)

### 6. boiler - boiler

- **Priority** 4.13 (gap 2.07, tier carries_game, installed 1, review discount 1.0)
- **What we have:** 1.44 x 2.05 x 1.84 m, floor mount, 9952 triangles, 19 surfaces, 16% flat colour
- **Real object:** The Orison's original 1912 heating plant: a coal-fired, hand-stoked cast-iron sectional low-pressure steam boiler of the American Radiator Company 'Ideal' class, lagged and patched by sixteen years of caretakers, feeding twenty-three one-pipe steam radiators from a basement plant room.
- **Confidence:** medium

All four bearings show the boiler's back and sides because the prop declares no warehouse_rotation_y and its tended face is local -Z: the fire and ash doors, water column, gauge, nameplate and every authored wear mark are never captured, and what is captured is a bright cream box with three dark stripes that reads as a jacketed cabinet, not the sooted, strapped canvas-over-asbestos plant beside the 1918 Mechanics of the Household boiler. The object class (Ideal-type hand-fired sectional steam boiler) is ruled and respected; this is execution, and two script-level defects - the Hartford loop buried inside the section block and the upper boss row rotated into rods that cross the gauge and nameplate - need a front render to confirm.

**Modelling**

  - Declare warehouse_rotation_y() -> PI as medicine_cabinet_prop and mail_bank_prop do, so the shed's front bearing shows the -Z door face; until then no before/after render of the doors, glass, gauge or nameplate exists.
  - Hartford loop is inside the body: the equalizer (r 0.038 x 0.72 at x -0.49, z 0.28), the return leg (r 0.038 x 0.48 along X at y 0.18, z 0.28) and the brass union (r 0.055 at x -0.49, y 0.77) all lie within the section block (x +/-0.5625, z +/-0.51) and jacket (x +/-0.6125). Move the equalizer to x -0.70, z 0.30 outside the jacket, bring the return leg out through the base at z 0.30, and keep the union at 0.77 m where a hand reaches it.
  - Section 'bosses' are rods: make_cyl r 0.045 x 0.225 rotated 90 degrees about Z has its axis along X, so the five at y 0.41 and the five at y 1.48 form two near-continuous rails across the front; the upper rail (z -0.48 to -0.57) crosses the gauge dial (z -0.546 to -0.584, x 0.218 to 0.402) and the nameplate (x -0.35 to -0.05, z -0.558 to -0.570). Rotate about X instead (0.06-thick discs facing -Z) and move the upper row to y 1.60 above the jacket.
  - Sections run across the width (five 0.205 x 1.28 x 1.02 boxes along X); the reference joins sections front-to-back so the seams and tie-rod nuts read on the sides and the front is one cast plate. In the 0.12 m band exposed under the jacket, cut the block as five 1.16 x 1.28 x 0.204 slabs along Z with 4 mm seams and put six r 0.012 nut heads on each side face at y 0.38.
  - Jacket is one 1.225 x 1.12 x 1.085 box with three 0.035 steel bands: add two raised canvas seams per face (0.006 x 1.12 x 0.006), a buckle on each band (brass_dull box 0.05 x 0.035 x 0.02 at x 0.61) so the straps hold something, and a fourth band at the jacket top edge.
  - Smoke hood is a 0.68 x 0.30 x 0.32 iron box; the real hood tapers into the breeching - one frustum r 0.28 to 0.17, h 0.22 along Z between the box and the collar.

**Texturing**

  - linen at tint (0.90, 0.84, 0.69) renders the jacket near white in every bearing; sixteen-year canvas over asbestos is grey-cream - tint (0.62, 0.58, 0.48), roughness 1.0.
  - All wear geometry is on the hidden -Z face (soot bloom, torn SOOT patch, mineral streak, ash apron, tag). The captured faces are factory-fresh: add a 0.22 x 0.18 soot patch on the +X side at (0.615, 0.90, 0.20), a fly-ash dusting under the hood (soot 0.68 x 0.06 x 0.30 on the jacket top at z 0.40), a rust wash (cast_iron tint 0.5) below each band end, and a drip stain under the safety-valve discharge.
  - Steel bands (metal key, tint 0.52, 0.50, 0.47) read as flat black stripes under shed light; tint (0.62, 0.58, 0.52) with roughness 0.55 so they read as strapping rather than painted lines.
  - cast_iron on the base, sections and hood reads as fine grey speckle like cast plaster; drop the albedo scale from 0.72 to 0.45 so the casting reads as a skin at 3 m and darken the hood tint 15 % - it carries the flue heat.

**References used**

  - File:Mechanics of the household; a course of study devoted to domestic machinery and household mechanical appliances (1918) (14779082252).jpg - No restrictions - https://commons.wikimedia.org/wiki/File:Mechanics_of_the_household;_a_course_of_study_devoted_to_domestic_machinery_and_household_mechanical_appliances_(1918)_(14779082252).jpg
  - File:Elevation of boiler backhead showing (left to right at top) steam pressure gauge, sight glass (indicates water level in boiler), manhole (for maintenance access to steam space), HAER VT,4-SHEL,1-14.tif - Public domain - https://commons.wikimedia.org/wiki/File:Elevation_of_boiler_backhead_showing_(left_to_right_at_top)_steam_pressure_gauge,_sight_glass_(indicates_water_level_in_boiler),_manhole_(for_maintenance_access_to_steam_space),_HAER_VT,4-SHEL,1-14.tif
  - (5 other plates on the sheet not relied on)

### 7. lamp - emeralite · the good reading lamp

- **Priority** 3.96 (gap 2.29, tier lighter_pass, installed 5, review discount 1.0)
- **What we have:** 0.27 x 0.41 x 0.19 m, floor mount, 1044 triangles, 9 surfaces, 100% flat colour
- **Real object:** Five different second-hand electric task lamps on desks in a 1927-28 Queens walk-up: two cased-glass bankers' lamps of the Emeralite class, a knuckled cast-iron machinist's bench lamp, a cheap stamped-steel landlord-issue desk lamp, and a 1927 Buquet counterweighted architect's lamp.
- **Confidence:** medium

The shade is an opaque flat-green box 0.26 x 0.075 x 0.13 m with no curve, no end caps, no white underside and no light through it, so the one feature that identifies an Emeralite reads as a painted slab on a stick; the base at dia 0.19 m is a third wider than the real dia 0.14-0.15 and the overall 0.41 m is a fifth taller than the 0.33-0.36 m No. 8734. The object class is right (a 1916-1930s cased-glass bankers' lamp), but no usable reference was on the sheet (a 1922 portrait, a 1902 X-ray tube stand and a Norfolk church), so this is judged against the variant text in queries.json.

**Modelling**

  - Replace the 0.26 x 0.075 x 0.13 shade box with a half-cylinder trough: an ArrayMesh arc of dia 0.13 m, 0.26 m long, 12 segments over 180 deg, open underneath, axis along x at y 0.375; close the ends with two 0.008-thick brass half-discs (r 0.065) at x +/-0.13 for the cast end caps.
  - Add the tilt knuckle a real 8734 has: a dia 0.024 x 0.030 brass cylinder on the z axis at the stem top (y 0.34) joining stem to trough, and tip the trough 12 deg toward the reader.
  - Shrink the base from dia 0.19 (make_cyl 0.085/0.095) to dia 0.145 (0.065/0.0725) and add a second step dia 0.10 x 0.012 above it so it reads as the stepped 8734 base; shorten the stem from 0.30 to 0.26 so the overall height lands at 0.35-0.36 m.
  - Hang the pull-chain socket where it belongs: move the dia 0.034 x 0.024 bakelite collar to the trough's centre underside and add a dia 0.002 x 0.06 chain with a dia 0.006 bead; run the cord (dia 0.0035) from the socket down the stem, hugging it at z +0.013 for 0.30 m, to the base and 0.15 m across the desk - it currently stops 0.155 m above the desk in mid-air.
  - Move the SpotLight3D from (0.10, 0.40, 0), which is inside the closed shade box (y 0.3375-0.4125), to y 0.33 just under the open trough so a shadow-casting spot is not occluded by the shade's own faces.

**Texturing**

  - Shade: new key `cased_glass_green` (no catalog key fits; `glassish` and `milk_glass` are the wrong substance): outer albedo (0.10, 0.36, 0.22) roughness 0.15, a `milk_glass` inner face on the underside, and when the lamp is on an emission (0.35, 0.90, 0.50) x 0.6 on the outer and (1.0, 0.95, 0.80) x 1.2 on the inner, so the shade glows green through and throws white down; wire it through GODOT_STAGE and MatLib.SETS or it stays flat colour.
  - Brass: retexture the three _BRASS flat colours (0.62, 0.50, 0.24 at metallic 0.75-0.80) to `brass` on the vertical stem and end caps and `brass_dull` on the horizontal base top (brief section 3: flat metal reads black, horizontals carry oxide); in every bearing the current brass renders as saturated toy gold.
  - Wear for a 16-year-old house lamp carried down two flights: an `fx_scuff` decal dia 0.05 on the base rim where it is dragged, the stem tinted 0.85 between y 0.15 and 0.25 where hands have worn the lacquer, and one 3 mm notch in an end cap for the chipped glass edge.

**References used**

  - none relied on; the 3 plates on the sheet were off-topic

### 8. door - exterior service

- **Priority** 3.92 (gap 1.43, tier touched_often, installed 120, review discount 0.6)
- **What we have:** 0.94 x 2.09 x 0.18 m, floor mount, 684 triangles, 4 surfaces, 0% flat colour
- **Real object:** A 1928 apartment-house contractor door: a standardized painted stile-and-rail leaf with two recessed fields, three mortised steel butt hinges and a knob on a long brass backplate over a mortise lock, hung in the building's older 1912 openings.
- **Confidence:** medium

The same _build_service as the interior service leaf at 0.90 x 2.10 x 0.052 m and it inherits the same gaps: a smooth galvanized slab with three plain straps, no rivets, no plate seams and none of the 'battered, dented, hard-used' condition the variant asks of an areaway door. No usable reference was on the sheet (a 1935 tow truck, a Portsmouth boathouse, a 1909 streetcar and a garden gate), so this is scored against the variant description; the object class is close.

**Modelling**

  - The service leaf's rivet (21 primitives), seam (6 boxes) and strap-hinge (4 primitives) bullets apply here through the shared _build_service; fix them once.
  - Battering the flat slab cannot show: two dent boxes 0.18 x 0.10 x 0.004 in the leaf material set 2 mm into the face at (0.30, 0.55) and (0.62, 1.35) with rotation.z 0.15 and -0.25, and a bent lower corner box 0.10 x 0.10 x 0.006 at (width - 0.05, 0.05) rotated 0.12 rad on Z (3 primitives) so the rectangle breaks from 3 m.
  - A drip across the head: a 0.02 x 0.02 x width cast_iron box along the top of the front face at y height - 0.01, which an alley door has and a boiler-room door does not (1 primitive).
  - Hasp and staple: one 0.16 x 0.035 x 0.004 cast_iron box at (width - 0.20, 1.25, -0.03) with a r 0.012 x 0.02 cylinder staple (2 primitives); an areaway leaf is padlocked from outside.

**Texturing**

  - Variant 0: the galvanized tint (0.48, 0.50, 0.47) on 'metal' reads as dark grey-green; lift toward (0.66, 0.68, 0.66) as for the service leaf, and add weather with a 0.12 x 0.80 x 0.001 'fx_grease' run from each strap end and a 0.30 m 'soot' band across the foot ('fx_drip' and 'fx_damp' are the catalog keys for this but are not in MatLib.SETS).
  - Variant 1 (Harukiya): keep (0.44, 0.13, 0.11) but give it the chalk the ruling describes: a 0.40 x 0.30 x 0.001 decal at (0.45, 1.10) in 'metal' with a light tint where the enamel has worn through to grey steel; chalk is a surface, not a darker tint.

**References used**

  - none relied on; the 4 plates on the sheet were off-topic

### 9. door - service leaf

- **Priority** 3.92 (gap 1.43, tier touched_often, installed 120, review discount 0.6)
- **What we have:** 1.00 x 2.09 x 0.18 m, floor mount, 684 triangles, 4 surfaces, 0% flat colour
- **Real object:** A 1928 apartment-house contractor door: a standardized painted stile-and-rail leaf with two recessed fields, three mortised steel butt hinges and a knob on a long brass backplate over a mortise lock, hung in the building's older 1912 openings.
- **Confidence:** medium

A metal-skinned service leaf of the right size and thickness (0.96 x 2.10 x 0.052 m) with a physical Z-brace, but the skin is one smooth dark slab: the two tin-clad door plates on the sheet show a quilt of lapped tin plates with nailed seams hung on straps, and the script's 'riveted' straps carry no rivets. Object class is close (a metal service leaf); as built it reads as a galvanized sheet-and-batten door rather than kalamein or tin-clad, and it is factory clean where the variant asks for a hard-used boiler-room door.

**Modelling**

  - Rivets on the three straps: 7 per strap as cylinders r 0.007 x 0.004 (or SphereMesh r 0.007) spaced 0.12 m along each 0.065 m strap, proud of the strap face at z -0.046; 21 primitives, the one cue the variant names that is not built.
  - Plate seams for the tin-clad read: a lattice of thin boxes 0.010 wide x 0.003 proud on the front face, 2 vertical at x = width / 3 and 2 * width / 3 (height - 0.34 tall) and 4 horizontal every 0.42 m between the straps; 6 boxes that turn the slab into lapped sheet without a new map.
  - Strap hinges on service kinds in place of the three r 0.010 x 0.105 butt barrels: two 0.40 x 0.05 x 0.006 cast_iron straps on the front face at y 0.30 and height - 0.30 running from the hinge edge, each with a knuckle cylinder r 0.014 x 0.12 at the edge in _fixed; the references hang on straps, not mortised butts (4 primitives replacing 3).
  - Iron rather than brass fixed hardware: build the backplate and thumbturn of _build_knob_set in cast_iron for service kinds and keep brass_dull for the knob only, per the variant's 'iron rather than brass fixed hardware'.

**Texturing**

  - 'metal' with tint (0.48, 0.50, 0.47) over the galvanized map at metallic 0.90 renders as dark grey-green; unpainted galvanized zinc is a light satin grey. Lift the tint to about (0.66, 0.68, 0.66) so the leaf reads as zinc under corridor light rather than painted olive.
  - Wear for a boiler-room and refuse-room door: a 0.30 x 0.25 x 0.001 'soot' decal at the foot of the leaf (y 0.15) and a 0.10 x 0.60 x 0.001 'fx_grease' run below the top strap, offset by finish_variant so the 23 leaves are not identical clean slabs; 'fx_drip' is the better catalog key for the run but is not in MatLib.SETS.

**References used**

  - File:The Architect and engineer of California and the Pacific Coast (1916) (14577058899).jpg - No restrictions - https://commons.wikimedia.org/wiki/File:The_Architect_and_engineer_of_California_and_the_Pacific_Coast_(1916)_(14577058899).jpg
  - File:The Architect and engineer of California and the Pacific Coast (1917) (14779537594).jpg - No restrictions - https://commons.wikimedia.org/wiki/File:The_Architect_and_engineer_of_California_and_the_Pacific_Coast_(1917)_(14779537594).jpg
  - (3 other plates on the sheet not relied on)

### 10. sink - sink / lavatory — legacy granular porcelain

- **Priority** 3.91 (gap 1.28, tier carries_game, installed 43, review discount 0.6)
- **What we have:** 0.66 x 1.01 x 0.51 m, floor mount, 12636 triangles, 11 surfaces, 27% flat colour
- **Real object:** Two cheap J. L. Mott Iron Works catalog fixtures: the compact 24-inch enameled apartment-house lavatory with integral back and apron, compression cross taps, pedestal and exposed nickel-plated waste (Mott Modern Plumbing 1908, plate 1053), and Mott's smallest roll-rim enameled-iron kitchen sink, 24 x 18 x 6 inches, with integral back, wall hanger or iron legs, optional porcelain-enamel drainboard and nickel-plated Fuller-pattern brass faucets (Mott Plumbing Fixtures 1908, plates 7300–7306).
- **Confidence:** high

The plate, not the geometry, is what is wrong here: in the 1280 px high_quarter frame the rejected 'porcelain' key reads as fine sprayed-stone grain over the 0.61 x 0.18 m back and the pedestal (luminance std 36.7 on the back panel against 29.6 on the fired-glaze twin), while at the shed's three-metre bearings the two variants are indistinguishable, so the specimen does its labelled job only in close frames. Object class is right, a pedestal apartment lavatory with integral back, wall cross valves, bridge spout and nickel waste; the geometry is identical to sink__lavatory_calm_fired_glaze and its gaps (a back slab short of the rim with no cove, a tailpiece and torus trap buried inside the solid pedestal column, a nickel disc for a rubber stopper, no wear) are scored and itemised there; this variant is never installed, so the index's installed count of 43 does not belong to it and the effort here is zero.

**Modelling**

  - Nothing on this specimen: it exists so the rejected plate can be recognised in the warehouse. Every geometry bullet is in sink__lavatory_calm_fired_glaze.json and lands once in tap_prop.gd _build_bath_sink (shared by both variants): widen the 0.61 m back box to the rim's 0.66 m with a 40 mm cove cylinder, free the tailpiece and 0.075 m torus trap from inside the 0.094 m-radius pedestal column, and shrink the 92 mm cross arms to 64 mm.
  - If the shed must show the defect at its own bearings, add a close bearing (camera 0.6 m from the back panel) to the warehouse pass; at 3 m under flat light the granular relief averages out to the same ivory as porcelain_fixture and the comparison proves nothing.

**Texturing**

  - Do not touch the 'porcelain' key on this specimen and do not promote it anywhere: porcelain_fixture already covers all 24 installed basins, and the point of this variant is that the granular, crazed plate reads as plaster at hand distance, which the close crop confirms.
  - The rest of the specimen's surfaces are the calm variant's and are right: nickel_plated on the valves, bridge, spout and risers, brass_dull on the caps, cast_iron on the drain bars.

**References used**

  - File:Mott's Open Lavatory (NYPL b15260162-487472).jpg - Public domain - https://commons.wikimedia.org/wiki/File:Mott%27s_Open_Lavatory_(NYPL_b15260162-487472).jpg
  - File:Mott's Open Lavatory (NYPL b15260162-487473).jpg - Public domain - https://commons.wikimedia.org/wiki/File:Mott%27s_Open_Lavatory_(NYPL_b15260162-487473).jpg
  - (2 other plates on the sheet not relied on)

### 11. sink - sink / roll-rim kitchen

- **Priority** 3.85 (gap 1.24, tier carries_game, installed 43, review discount 0.6)
- **What we have:** 1.05 x 0.48 x 0.49 m, floor mount, 5644 triangles, 12 surfaces, 33% flat colour
- **Real object:** Two cheap J. L. Mott Iron Works catalog fixtures: the compact 24-inch enameled apartment-house lavatory with integral back and apron, compression cross taps, pedestal and exposed nickel-plated waste (Mott Modern Plumbing 1908, plate 1053), and Mott's smallest roll-rim enameled-iron kitchen sink, 24 x 18 x 6 inches, with integral back, wall hanger or iron legs, optional porcelain-enamel drainboard and nickel-plated Fuller-pattern brass faucets (Mott Plumbing Fixtures 1908, plates 7300–7306).
- **Confidence:** high

The drainboard is the most wrong part: a level 0.42 x 0.46 x 0.026 m slab with seven 10 x 11 mm rib boxes and no raised edge, where the Gordon-Van Tine plate and the Mott catalog class show boards pitched to the bowl inside a continuous roll rim, so ours would shed water onto the floor and reads as a ribbed tray laid beside the sink; second is the wet-corner rust, a 3 mm-thick saturated flat-colour oval (#632e16, 62 x 105 mm) on the front rim that reads as a red sticker in the high quarter. Object class is right: a 0.61 x 0.46 x 0.15 m roll-rim enamelled trough with a 0.16 m integral back, wall cross valves, bridge and high gooseneck at 0.90 m; in the building the cabinet cut-out carries it as ruled, so the shed's basin floating at 0.75 m is staging rather than a defect, and only the missing catalog legs or hanger keep mount off zero.

**Modelling**

  - Pitch the drainboard: rotate the board box and its seven rib boxes 2 degrees about Z toward the bowl (a 15 mm fall over 0.42 m, the outer edge rising to y 0.912) and run the rim round it with three lip boxes matching _open_rect_basin's 35 mm lip: two of 0.42 x 0.025 x 0.035 along the long edges and one of 0.035 x 0.025 x 0.46 at the free end: 3 primitives.
  - Cross handles: the two 0.092 m arm boxes per valve shrink to 0.064 m (the 2.5 in Fuller cross); the Ø 68 mm escutcheon stays. One edit in _build_pair_taps serves the lavatory too.
  - Gooseneck: the five Ø 24 mm chords are a heavy pipe; a 1920s swing spout is Ø 16-19 mm tube on a Ø 30 mm swivel collar. Set the chord radius to 0.009 and add make_cyl(0.015, 0.015, 0.020) at the spout base (0, 1.01, 0.175): 1 primitive.
  - Warehouse only: the shed shows the basin at 0.75-1.23 m over nothing. If the shed needs a carrier, two catalog iron legs make_box(0.035, 0.75, 0.035) under the front corners in IRON (cast_iron) inside the warehouse_variants entry: 2 primitives; the building's carcass cut-out stays as ruled.
  - The compact 4B variant (0.50 x 0.38 m, no board) inherits every change above except the drainboard; keep its plate rack as ruled.

**Texturing**

  - Rust: add a RUST row to the retexture table so the wet-corner oval rides cast_iron tinted (0.48, 0.20, 0.10) as radiator_prop does, and drop its height from 0.003 to 0.0008 like the mineral film; the ruling keeps it at the wet corner only, and this keeps it there as a stain rather than a puck.
  - enamel (T_library_appliances_aged_enamel_worn) at tint (0.78, 0.80, 0.75) renders cream-yellow next to the ivory lavatory; a kitchen roll-rim sink is white enamel inside. Lift the enamel row's tint to (0.86, 0.87, 0.84); it is still the kitchen's own enamel job, not porcelain_fixture.
  - Wear by household: a dark scale ring make_ring(0.05, 0.003) around the drain disc in the MINERAL colour, and one chipped corner on the drainboard's outer edge (10 x 10 x 1 mm box tinted through cast_iron at (0.33, 0.32, 0.29)), both placed by hash(unit) so 19 kitchens do not share one stain.
  - The basin walls' outer faces render the same cream as the inside; the real casting is black-japanned outside. Installed, the carcass hides them, so this is warehouse-only and not worth a draw: leave it.

**References used**

  - File:Gordon-Van Tine homes (1921) (14802245763).jpg - No restrictions - https://commons.wikimedia.org/wiki/File:Gordon-Van_Tine_homes_(1921)_(14802245763).jpg
  - File:Mott's Open Lavatory (NYPL b15260162-487472).jpg - Public domain - https://commons.wikimedia.org/wiki/File:Mott%27s_Open_Lavatory_(NYPL_b15260162-487472).jpg
  - File:Mott's Open Lavatory (NYPL b15260162-487473).jpg - Public domain - https://commons.wikimedia.org/wiki/File:Mott%27s_Open_Lavatory_(NYPL_b15260162-487473).jpg

### 12. pendant_shade - pendant_shade

- **Priority** 3.84 (gap 3.35, tier leave_alone, installed 29, review discount 1.0)
- **What we have:** 0.55 x 0.90 x 0.46 m, ceiling mount, 674 triangles, 5 surfaces, 60% flat colour
- **Real object:** In a 1927-28 Queens rented flat the landlord's parlour fixture was a cheap brass-finished ceiling piece: most often a three- to five-light stamped-brass 'pan' fixture with small glass shades, or a semi-indirect inverted opal bowl hung on three chains; a fabric drum shade on a bare cord is a post-war form, and the silk-shaded ceiling fixtures of the twenties were fringed bell or empire shapes bought by better-off households.
- **Confidence:** medium

A fabric drum on a bare 6 mm cord is the post-war form the kind's own notes rule out; the landlord's 1927-28 parlour piece was a stamped-brass pan with small glass shades or an inverted opal bowl on three chains from a canopy, and none of that is built (no canopy, chains, hub, sockets or finial). No usable reference was on the sheet (a furnace plate, a door-hardware plate, an early-1800s painting and a Locarno hall), so this is scored against the real-object description; the era is wrong, the category (a ceiling pendant) is right.

**Modelling**

  - Cheapest correct form, the pan: canopy make_cyl r 0.06 -> 0.05 x 0.025 at y -0.012, stem make_cyl r 0.008 x 0.30 at y -0.165, pan make_cyl r 0.18 -> 0.17 x 0.025 at y -0.325 with rim make_ring r 0.18 tube 0.006, three sockets make_cyl r 0.018 x 0.05 at radius 0.12 and 120 degrees, three opal shades make_cyl r 0.055 -> 0.035 x 0.09 below them named bulb_shade_0..2, and a finial make_cyl r 0.02 -> 0.005 x 0.05 under the pan; about 12 primitives, drop 0.45 m.
  - Or the bowl pendant, reusing the chandelier branch's own code: canopy r 0.06 x 0.025, three chains of 7 make_ring links r 0.021 from the canopy edge to a hub at y -0.50, an inverted opal bowl of 4 stacked make_cyl bands from r 0.19 at the rim to r 0.02 at y -0.75 named bulb_bowl_0..3, and a brass finial; about 30 primitives, drop 0.78 m, the same as today's drum so no marker moves.
  - Either way delete the drum (make_cyl 0.19 -> 0.23 x 0.24), the 0.40 m opal disc and the 0.55 m cord; leave the bulb node at y -0.62 so light, halo and bounce positions are unchanged.

**Texturing**

  - Brass parts to 'brass_dull' (a horizontal pan at metallic 0.85 would read black under the brief's flat-metal warning), shades or bowl to the shared emissive opal with 'milk_glass' (staged) as unlit albedo; the 'linen' key and its 0.5 UV scale go with the drum.
  - The cord's flat (0.15, 0.14, 0.13) material disappears with it; chain links or stem take 'brass_dull', which removes two of the three flat-colour surfaces the census counts (flat_colour_share 0.6 today).
  - Wear: tarnish on the pan by the existing name seed (tint darkened 0.0-0.12) and, on a quarter of the 29 fixtures, one shade in a slightly different opal tint, the replaced-shade tell of a rented flat.

**References used**

  - none relied on; the 4 plates on the sheet were off-topic

### 13. lamp - buquet pattern · counterweighted

- **Priority** 3.84 (gap 2.18, tier lighter_pass, installed 5, review discount 1.0)
- **What we have:** 0.27 x 0.67 x 0.22 m, floor mount, 2544 triangles, 10 surfaces, 100% flat colour
- **Real object:** Five different second-hand electric task lamps on desks in a 1927-28 Queens walk-up: two cased-glass bankers' lamps of the Emeralite class, a knuckled cast-iron machinist's bench lamp, a cheap stamped-steel landlord-issue desk lamp, and a 1927 Buquet counterweighted architect's lamp.
- **Confidence:** medium

The counterweight - the mechanism the header says is worth showing - is a dia 0.052 x 0.052 cylinder centred at y 0.008, inside the dia 0.224 wooden base disc and 18 mm into the desk, and the second arm (0.30 m at -30 deg) folds back so the head sits over the base axis, so the cantilevered balance that reads across a room is absent and the lamp is another zig-zag stand; the arms at 0.34 and 0.30 m are a quarter to a third short of the real 0.45-0.50. The object class is right (a 1927 Buquet, the newest lamp allowed); no usable reference was on the sheet (an X-ray tube stand and two churches), so this is judged against the variant text.

**Modelling**

  - Put the hip where a Buquet's is: a dia 0.016 x 0.24 nickel column from the base collar up to a hip at y 0.28; run the first arm through the hip so 0.12 m of it continues past the pivot on the far side, and hang the dia 0.050 x 0.050 counterweight from that short end near (-0.11, 0.20, 0) - free, below and behind the hip, clear of the base top (y > 0.034) and of the desk.
  - Lengthen and re-aim the arms to the real 0.45-0.50 m each: first strut 0.46 m at +42 deg from the hip, second strut 0.46 m at +70 deg leaning the same way, giving a wrist near (0.74, 0.78, 0) and about 0.75 m of reach over the board; set _SPECS.architect_counterweight.reach to 0.72 (the spot already follows _head) and check the 5A drafting-table marker for clearance at that reach.
  - Ball joints as balls: a dia 0.026 nickel sphere at hip, elbow and wrist, each with a knurled locking collar (torus r 0.017 tube 0.004), in place of the two stacked cylinders (dia 0.038 x 0.026 and dia 0.026 x 0.034); a fourth dia 0.020 ball between the wrist and the shade so the cone swivels on its own.
  - Cord: from the socket along the arms as three cloth segments following the struts, down the column to the board, then 0.20 m across it - it currently hangs free and stops 0.36 m above the board.
  - Turn the base: keep dia 0.224 but add a cove (torus r 0.105 tube 0.006 at y 0.006) and an upper step dia 0.18 x 0.008 so it reads as turned wood rather than a slab.

**Texturing**

  - Base: `wood_dark` (catalog) tinted (0.12, 0.10, 0.09) at roughness 0.35 for the ebonised black lacquer the variant text calls for; the flat mid-brown (0.29, 0.20, 0.13) reads as raw pine.
  - Arms, balls, collars, counterweight and shade: `nickel_plated` (catalog) in place of the flat _NICKEL (0.72, 0.74, 0.76) at metallic 0.85-0.90; tint the collars 0.9 to show plating rubbed at the joints.
  - The scar: replace the grey 0.050 x 0.004 x 0.010 box floating beside the wrist with an `fx_scuff` decal 0.06 x 0.012 on the outer face of the second arm 0.05 m below the wrist, tinted (0.40, 0.36, 0.30) for brass showing through nickel - the mark of the arm hitting the board.
  - Cord in coloured silk braid: tint the shared _CORD brown to a deep red (0.40, 0.12, 0.10) in the `fabric_warm` family for this lamp only; VIII.4 makes cloth braid the good flat's status and 5A is a good flat.

**References used**

  - none relied on; the 3 plates on the sheet were off-topic

### 14. shower - shower / curtain gathered

- **Priority** 3.77 (gap 1.45, tier carries_game, installed 23, review discount 0.6)
- **What we have:** 0.79 x 2.06 x 0.76 m, floor mount, 36332 triangles, 16 surfaces, 25% flat colour
- **Real object:** Mott Modern Plumbing 1908 plate 1034-A: a 28-inch enameled-iron corner shower receptor with an exposed nickel-plated tubular shower — vertical riser, crooked arm, broad rose and separate hot and cold compression valves — under a roughly 25-inch nickel curtain ring hung with a white cotton duck shower curtain.
- **Confidence:** medium

The one thing most wrong is the gathered stack: eight sine folds compressed into a 0.095 m run (x 0.245 to 0.34 at the right rear) with a uniform 0.040 m amplitude produce a flat-faced rectangular column about 0.10 x 0.10 x 1.62 m, and in the high_quarter and three_quarter bearings it reads as a square timber post standing in the receptor with a comb of seven rings on top, not as 1.96 m of duck bunched on its rings. The object class is right and ruled (Mott 1034-A receptor, exposed nickel riser, arm and rose, two cross valves, U rod), and with the curtain back the fixture's full silhouette reads correctly. The hem gap is the same as the drawn state (hem at 0.345 m, 0.225 m above the rim). The sheet's only reference is an off-topic 1920 yearbook cartoon, so this is judged against the plate description and the notes at medium confidence.

**Modelling**

  - Rebuild the stack as a bundle, not a plank: spread the eight folds over 0.16 m (x 0.18 to 0.34), taper the amplitude from 0.030 m at the rings to 0.075 m at the hem, and add a second sine at 3 folds with 0.025 m amplitude and a 0.4 phase offset so the plan outline is an irregular bulge widest at the foot; 8 folds x 12 segments = 96 segments, about 0.8 k triangles two-sided.
  - Ring cluster: seven 22 mm rings in 0.095 m overlap into a solid comb; place them over the 0.10 m rod length nearest the wall eye with alternating tilts of plus and minus 15 degrees about the rod axis so they read as rings bunched, and let the top 0.055 m of the bundle hang from them rather than starting flat at rod_y - 0.055.
  - Lengthen the drop from -1.62 m to -1.88 m in _make_curtain_panel so the bundle's foot is at 0.085 m inside the receptor's 0.12 m rim, as for the drawn state.
  - Interaction area: the open-state box 0.18 x 1.55 x 0.16 m at (0.29, 1.18, 0.25) should grow with the bundle to 0.22 x 1.55 x 0.20 m at (0.26, 1.18, 0.24) so the draw-again verb still lands on the cloth.
  - Rolled rim and rose face as in the drawn critique: four make_cyl r 0.018 m rim edges plus four corner spheres in place of the lip boxes; a 0.002 m perforated disc under the rose.
  - Ceiling hangers for the U rod's front corners (two nickel_plated make_cyl r 0.004 m drops to the ceiling), as in the drawn critique; with the curtain back the unsupported 0.68 m front run is the most visible part of the fixture.

**Texturing**

  - Curtain tint (0.90, 0.84, 0.67) reads yellow-tan; move to (0.93, 0.91, 0.84) over the ruled triplanar linen so the bundle reads as white duck.
  - Bundle shading: the stacked cloth is where the triplanar weave is densest and darkest; a 0.85 albedo multiplier on the gathered panel only (it is a separate MeshInstance3D, RubberizedDuck under CurtainGathered) keeps the shadowed folds from flattening to the same value as the open panel.
  - Receptor enamel toward neutral white (0.86, 0.86, 0.83) as in the drawn critique; the exposed receptor is the largest surface in this state.
  - Wear: with the curtain back the drain and wet corner are the whole story - the mineral film r 0.035-0.050 m and the rust bloom at (0.25, 0.125, -0.24) exist and read; add a 0.30 m water line inside the receptor walls (alpha 0.20 grey quad) and a scale ring r 0.045 m around the drain disc so the sixteen-year receptor does not read as newly set.

**References used**

  - none relied on; the 1 plates on the sheet were off-topic

### 15. lamp - office green · squared to the desk

- **Priority** 3.77 (gap 2.12, tier lighter_pass, installed 5, review discount 1.0)
- **What we have:** 0.21 x 0.33 x 0.16 m, floor mount, 876 triangles, 8 surfaces, 100% flat colour
- **Real object:** Five different second-hand electric task lamps on desks in a 1927-28 Queens walk-up: two cased-glass bankers' lamps of the Emeralite class, a knuckled cast-iron machinist's bench lamp, a cheap stamped-steel landlord-issue desk lamp, and a 1927 Buquet counterweighted architect's lamp.
- **Confidence:** medium

Same fault as its Emeralite sibling: the shade is a closed flat-green box 0.20 x 0.062 x 0.105 m with no curve, end caps, white lining or glow, and the base at dia 0.156 m is 30% wider than a junior-size dia 0.12 while the 0.33 m overall is a tenth over the 0.28-0.30 m of a Verdelite or Greenalite. The object class is right (a rival-make green-glass bankers' lamp of the Emeralite class); the sheet's three references (a 1902 X-ray tube stand and two English churches) are off-topic, so this is judged against the variant text.

**Modelling**

  - Build the shade with the same half-cylinder helper as the Emeralite but squarer, which is the script's stated intent: a 0.20 m trough of dia 0.105 with a 150 deg arc and a 0.02 m flat crown so it keeps sharp corners while staying a glass trough open underneath; end caps r 0.0525 x 0.008 in brass at x +/-0.10.
  - Tilt knuckle dia 0.020 x 0.026 on the z axis at the stem top (y 0.265), shade tipped 12 deg toward the desk.
  - Base dia 0.156 (make_cyl 0.070/0.078) to dia 0.12 (0.055/0.06) as one plain disc 0.014 thick - several rival makes used a plain disc, not a step; stem 0.24 to 0.21 so the overall height lands at 0.29-0.30 m.
  - Pull-chain socket under the trough centre (collar dia 0.034 x 0.024, chain dia 0.002 x 0.05 with a bead); run the cord down the stem to the base and 0.12 m across the desk instead of stopping 0.09 m above it.
  - Move the SpotLight3D from the spec fallback (0.08, 0.33, 0), which sits in the top of the closed box (y 0.269-0.331), to y 0.26 under the open trough.

**Texturing**

  - Shade: share the new `cased_glass_green` key with the Emeralite (outer green, `milk_glass` inner, emission when on); the current flat (0.16, 0.34, 0.22) at roughness 0.18 is an opaque painted slab.
  - Brass: `brass` on the stem, `brass_dull` on the disc base top; the variant text allows a bronze or verdigris finish on rival makes, so tint the base recess toward (0.45, 0.50, 0.40) to separate it from the Emeralite's brighter brass.
  - Wear kept neater than the Emeralite because Mina squares everything: one `fx_scuff` under the base edge only, and a 0.3-alpha `fx_ao` dust band along the top of the shade rather than chips.

**References used**

  - none relied on; the 3 plates on the sheet were off-topic

### 16. laundry_airer - laundry / rinse tubs + pulley airer

- **Priority** 3.67 (gap 1.72, tier carries_game, installed 1, review discount 1.0)
- **What we have:** 1.39 x 2.48 x 0.64 m, floor mount, 2004 triangles, 6 surfaces, 0% flat colour
- **Real object:** In the shared basement wash room of a 1928 Queens walk-up, a pair of rectangular galvanised-iron laundry set tubs (the plumbing-catalogue 'galvanized iron wash tubs' / laundry-tray class, about 24 x 18 in plan and 14 in deep with the rim near 32 in) standing on plain square wood legs, each with its own brass drain cock and tail, serving as first and second rinse beside the wringer washers whose own swinging-yoke wringer feeds them; above, a five-lath wooden ceiling pulley airer with metal rack ends, two ropes rising to two ceiling pulleys, tied off on a wall-mounted wood pin-block with brass pins. Period-correct references are the NYPL 1888 galvanized/porcelain wash-tub catalogue plates, the 1922 Sears and Structural Slate laundry-tray plates (same twin rectangular form in other materials), and HABS photographs of surviving laundry wash tubs; the only photographic pulley airers on Commons are 2018/2022 modern examples of the unchanged Victorian design and should be used for mechanism only, with that caveat recorded.
- **Confidence:** high

The two ropes are merged into the rack and stop at the pulleys, so lowering the airer to 1.38 m opens 0.6 m of empty air under the ceiling tackle at 2.42 m and nothing ever runs to the pin-block on the wall, on the one prop whose tier is carried by that mechanism; the tubs are vertical-sided 28 mm crates where every set-tub plate on the sheet (the Mott/NYPL 1888 plates, the Otis House HABS laundry) shows steep-sided thin galvanised hoppers on a framed stand. Object class is right for the verified reading: rectangular galvanised-iron laundry set tubs with a lath pulley airer, not round bail-handled tubs.

**Modelling**

  - Rope: the two LINEN cylinders (r 0.009 h 0.43 at rack-local y 0.23) travel with PulleyAirer, so at the 1.38 m lowered height they end at 1.83 m below pulleys at 2.42 m. Put them in StaticRinseStand anchored at the pulleys and scale height with the tween (h 0.43 raised to 1.03 lowered), or split each into a fixed upper cylinder and a rack-side stub.
  - Run the rope to the cleat: there is no rope between the pulleys at x +/-0.52 and the pin-block at (0.72, 1.15, 0.26). Add a third pulley (r 0.055 h 0.045 plus its 0.12 x 0.07 x 0.16 bracket) at (0.72, 2.42, 0), two horizontal LINEN cylinders r 0.009 from each pulley to it (1.24 m and 0.20 m) and one vertical drop r 0.009 from (0.72, 2.42) to the pins at 1.24 m; 5 primitives in existing materials.
  - Pulleys: the two r 0.055 cylinders stand with a vertical axis, so each wheel lies flat and the rope rises into its underside. Rotate them 90 degrees about X so the rim faces the rope, and move them to x +/-0.56 over the rack ends.
  - Tub form: each shell is four 0.028 m boxes standing vertical on a 0.56 x 0.47 floor. The Mott plates show sides sloping so the bottom is about 60% of the 24 x 18 in top. Tilt the long-side boxes +/-14 degrees about X and the short sides -/+14 degrees about Z, shrink the floor to 0.42 x 0.30 and thin the sides to 0.006 (floor 0.012); same 5 boxes per tub.
  - Rim: replace the four 0.03 x 0.035 lip bars per tub with four cylinders r 0.010 (a wired rolled rim); same count, and the 28 mm slab edge that reads as slate goes away.
  - Stand: eight loose 0.045 legs with nothing between them; the Otis House tubs sit in a framed stand. Add two 1.24 x 0.045 x 0.045 WOOD stretchers at y 0.12, z +/-0.20, two 0.045 x 0.045 x 0.44 end rails and a 1.24 x 0.03 x 0.02 rail at y 0.42 under the rims; 5 boxes.
  - Drain: the BRASS tail (r 0.025 h 0.26 at y 0.31 along Z) floats 0.12 m below the tub floor at 0.4275 with no riser. Add a vertical BRASS cylinder r 0.020 h 0.12 at (cx, 0.37, 0.20) per tub (2 primitives) so the cock hangs off a pipe that leaves the tub.
  - Rack ends: the METAL end bars are 0.05 x 0.12 x 0.56 slabs; cast rack ends are plates about 10 mm thick. Make them 0.012 x 0.10 x 0.56.
  - Laundry: the three LINEN cards hang from under the laths as flat sheets. Fold each over its lath: two 0.018 boxes at z +/-0.032 from the lath centre with a 0.05 x 0.018 x 0.064 cap (9 boxes for 3 pieces) so wet cloth reads draped, not pegged.
  - Laths: 1.14 m against the 1.2-1.8 m real range; 1.30 m fits over the 1.24 m tub pair and keeps the 0.11 spacing. Optional: a pair of brass bibbs (r 0.008 h 0.06 rotated X 90) above each tub at y 0.90 on a 1.24 m supply rail, as the plates' 'faucet holes in back' and the Otis House back rail show, if the rinse tubs are meant to fill from the wall and not only from the wringer.

**Texturing**

  - zinc_liner on the tubs is ruled and stays; the gap is form (28 mm walls), not the response. Keep tint (0.80, 0.82, 0.80) at 0.72.
  - wood_dark (walnut albedo) tinted (0.74, 0.64, 0.50) makes pine laths and a deal stand read as dark furniture; lift the lath tint to (0.88, 0.80, 0.64) (unpainted pine or whitewash) with a second WOOD colour constant and leave the legs darker, so the two tints are two surfaces of the same key and no new key is needed.
  - Wear: the fiction rules a patched, mended, mismatched line and the tubs render as uniform clean zinc. Give the two tubs different tints (0.80/0.82/0.80 and 0.70/0.72/0.68) and add a 0.03 x 0.15 strip below each drain tinted (0.50, 0.32, 0.22) on zinc_liner as the rust weep (fx_drip is not in GODOT_STAGE, so no decal is available at runtime); a rust weep and a waterline band are the two marks every galvanised tub in the HABS photograph carries.
  - brass_dull on the cocks and pins and linen on the rope read right; leave them.

**References used**

  - File:Porcelain-Lined and Galvanized Iron Wash Tubs (NYPL b15260162-487530).tiff - Public domain - https://commons.wikimedia.org/wiki/File:Porcelain-Lined_and_Galvanized_Iron_Wash_Tubs_(NYPL_b15260162-487530).tiff
  - File:Porcelain-Lined and Galvanized Iron Wash Tubs (NYPL b15260162-487529).tiff - Public domain - https://commons.wikimedia.org/wiki/File:Porcelain-Lined_and_Galvanized_Iron_Wash_Tubs_(NYPL_b15260162-487529).tiff
  - File:Imperial' Porcelain Wash Tubs (NYPL b15260162-487525).jpg - Public domain - https://commons.wikimedia.org/wiki/File:Imperial%27_Porcelain_Wash_Tubs_(NYPL_b15260162-487525).jpg
  - File:Imperial' Porcelain Wash Tubs (NYPL b15260162-487527).tiff - Public domain - https://commons.wikimedia.org/wiki/File:Imperial%27_Porcelain_Wash_Tubs_(NYPL_b15260162-487527).tiff
  - File:LAUNDRY, WASH TUBS - Harrison Gray Otis House (second), 85 Mount Vernon Street, Boston, Suffolk County, MA HABS MASS,13-BOST,114-15.tif - Public domain - https://commons.wikimedia.org/wiki/File:LAUNDRY,_WASH_TUBS_-_Harrison_Gray_Otis_House_(second),_85_Mount_Vernon_Street,_Boston,_Suffolk_County,_MA_HABS_MASS,13-BOST,114-15.tif
  - (3 other plates on the sheet not relied on)

### 17. lamp - friction joint · the bench lamp

- **Priority** 3.66 (gap 2.03, tier lighter_pass, installed 5, review discount 1.0)
- **What we have:** 0.27 x 0.61 x 0.23 m, floor mount, 2532 triangles, 11 surfaces, 100% flat colour
- **Real object:** Five different second-hand electric task lamps on desks in a 1927-28 Queens walk-up: two cased-glass bankers' lamps of the Emeralite class, a knuckled cast-iron machinist's bench lamp, a cheap stamped-steel landlord-issue desk lamp, and a 1927 Buquet counterweighted architect's lamp.
- **Confidence:** medium

The second arm folds back (0.28 m at -34 deg after 0.30 m at +26 deg) so the shade sits over its own foot - the wrist lands at x -0.025 and the head within 25 mm of the base axis - where an O.C. White or Faries bench lamp carries the head 0.5-0.9 m out over the work, which is the whole point of the object; the arms themselves are at the short end of the real 0.30-0.45 m. The object class is right (a knuckled cast-iron machine-arm bench lamp); the sheet's only usable reference is a 1902 X-ray tube stand showing the same thumb-screw collar clamps, so reach and finish are judged against the variant text.

**Modelling**

  - Re-pose the arms so the head reaches the work: first strut 0.36 m at +38 deg from the hip, second strut 0.34 m at +62 deg leaning the same way (not back), which puts the wrist near (0.52, 0.52, 0) and the head about 0.55 m out from the foot; set _SPECS.bench_friction.reach to 0.55 so the spec agrees with _head, and check the 3B marker's clearance to the bench edge at that reach.
  - Knurl the knuckles: replace each smooth dia 0.048 x 0.028 cylinder with a dia 0.044 core plus a torus ring r 0.024 tube 0.004 on each face, and give the dia 0.030 x 0.014 thumbscrew a T-bar (a 0.040 x 0.006 x 0.006 nickel box across its head) as the 1902 stand drawing shows - the bar is what the hand turns.
  - Add a ball joint at the shade: a dia 0.024 nickel sphere between the wrist and the cone so it can tip more than the current 8 deg; tip the shade 25-30 deg at the work.
  - White inside the cone: a second cone dia 0.056 -> 0.222 x 0.146 nested inside the shade with cull mode front so the interior reads white from below; the real spun shade is japanned outside and white inside.
  - Cord: run it along the arms as three dia 0.0035 segments following each strut, with a 0.010 x 0.012 tape wrap at each joint, then down the foot to the bench - it currently hangs free from the shade and stops 0.31 m above the bench.
  - Foot: dia 0.22 x 0.03 to dia 0.19 x 0.035 with a 0.02 chamfer step (real 0.15-0.20); the flat disc reads as a coaster rather than a cast foot.

**Texturing**

  - Foot and boss: `cast_iron` (catalog, metallic 0.35 / roughness 0.60) in place of the flat _IRON (0.19, 0.19, 0.20), tinted (0.16, 0.16, 0.17) for japanned black with the edge rubbed lighter.
  - Arms, knuckle bodies and screws: `nickel_plated` (catalog) instead of the flat _NICKEL (0.72, 0.74, 0.76) at metallic 0.70-0.80; tint the joint collars (0.55, 0.56, 0.58) where the plating is worn through by adjustment.
  - Shade: `enamel` tinted dark green (0.14, 0.20, 0.15) outside with the `milk_glass` inner cone; the flat (0.22, 0.23, 0.22) is neither japanned steel nor spun metal.
  - Wear for a repair bench: offset the rim ring 0.004 off-axis for a dent, an `fx_scuff` on the foot where the vice sits, and `fx_grease` fingerprints at the shade rim where it is grabbed hot.

**References used**

  - File:X-ray apparatus, miniature lamps and accessories (1902) (14571236898).jpg - No restrictions - https://commons.wikimedia.org/wiki/File:X-ray_apparatus,_miniature_lamps_and_accessories_(1902)_(14571236898).jpg
  - (2 other plates on the sheet not relied on)

### 18. shower - shower / curtain drawn

- **Priority** 3.53 (gap 1.29, tier carries_game, installed 23, review discount 0.6)
- **What we have:** 0.79 x 2.06 x 0.76 m, floor mount, 36332 triangles, 16 surfaces, 25% flat colour
- **Real object:** Mott Modern Plumbing 1908 plate 1034-A: a 28-inch enameled-iron corner shower receptor with an exposed nickel-plated tubular shower — vertical riser, crooked arm, broad rose and separate hot and cold compression valves — under a roughly 25-inch nickel curtain ring hung with a white cotton duck shower curtain.
- **Confidence:** medium

The one thing most wrong is the hem: the curtain drop is 1.62 m from a top at 1.965 m, so the hem hangs at 0.345 m, 0.225 m clear above the receptor's 0.12 m rim, and every bearing shows a curtained box hovering over a separate tray instead of duck falling inside the receptor as Mott plate 1034-A hangs it. The object class is right and ruled - 0.72 m enameled corner receptor, exposed nickel riser to 1.89 m, 0.17 m arm, 0.11-0.15 m rose, two cross valves at 0.98 m, ceiling U rod at 2.02 m with 22 mm rings and one continuous curtain. The sheet's only reference (a 1920 yearbook cartoon of three students) is off-topic and was not used; this critique is against the Mott plate description in queries.json and the tap_prop notes, so confidence is capped at medium.

**Modelling**

  - Lengthen the curtain: in _make_curtain_panel change the hem offset from -1.62 m to -1.88 m so the hem sits at 0.085 m, inside the receptor cavity below its 0.12 m rim; keep the rod footprint 0.68 x 0.64 m, which already sits inside the 0.72 m receptor in plan.
  - Hem and fold sampling: segments = max(8, folds * 4) gives 4 samples per 0.128 m wave, so the sine profile and the 12 mm hem ripple render as a saw-tooth in the side and high_quarter bearings; raise to folds * 12 (60 / 84 / 60 segments, about 1.6 k triangles for the three panels after the two-sided duplicate) and taper the wave amplitude from 0.020 m at the rings to 0.055 m at the hem so the cloth hangs from its rings instead of reading as corrugated panelling.
  - Rolled rim: the receptor's four 35 x 25 mm lip boxes read as a square-edged tray; replace them with four make_cyl edges r 0.018 m along the rim and four corner spheres r 0.018 m (8 primitives for 4) so the rim rolls as enameled iron does.
  - Rose face: the 55/75 mm inverted cylinder reads as a solid disc from below; add one 0.002 m nickel_plated disc r 0.052 m with the spray_holes drawn as 24 make_cyl r 0.0015 m dark stubs, or a 12-hole subset, so the rose is a rose.
  - Wall eyes: the two make_ring(0.030, 0.007) eyes at z 0.338 are 60 mm rings for a 9 mm rod; a period wall flange is a 32 mm escutcheon - drop to make_ring(0.016, 0.005) plus a 0.004 m disc r 0.020 against the wall.
  - Ceiling hangers: the rod is ruled ceiling-hung but has no ceiling attachment, so a 0.68 m front run of 9 mm tube cantilevers from two wall eyes; add two nickel_plated make_cyl drops r 0.004 m from the front corners (-0.34, 2.02, -0.32) and (0.34, 2.02, -0.32) up to the room ceiling (about 0.55 m in the standard flat), which is what keeps the front bar level in the Mott plate.

**Texturing**

  - Curtain colour: the shower_duck tint (0.90, 0.84, 0.67) over the library linen albedo renders a distinctly yellow-tan cloth in all four bearings; white rubberized cotton duck is off-white - move the runtime multiplier to (0.93, 0.91, 0.84) and keep the triplanar linen source, which is ruled.
  - Receptor enamel: the aged_enamel_worn albedo reads greenish-cream in the shed's flat light; keep the enamel key (ruled: receptors keep their own enamel job) but sample the installed 1A frame against the lavatory's porcelain_fixture and pull the tint toward neutral white (0.86, 0.86, 0.83) so it does not read as a different substance from the splash panel.
  - Curtain wear, the piece that says who owns it: a mildew band 0.06 m tall at the hem (alpha 0.25 grey-green quad along the front panel's foot), a water line at 0.30 m, and a hand-greyed leading edge 0.05 m wide at the front panel's rod-side end; the fixture is sixteen years installed and the curtain is the one part a tenant replaces, so per-unit variation belongs here rather than on the enamel.
  - Nickel: keep nickel_plated (ruled warm silver); add a verdigris ring r 0.036 m, 0.001 m thick, behind each valve escutcheon and at the riser's foot where the two metals meet, which is where sixteen years of water show on nickel over brass.

**References used**

  - none relied on; the 1 plates on the sheet were off-topic

### 19. fridge - fridge / oak icebox

- **Priority** 3.47 (gap 1.35, tier carries_game, installed 18, review discount 0.6)
- **What we have:** 0.70 x 1.24 x 0.66 m, floor mount, 5940 triangles, 14 surfaces, 14% flat colour
- **Real object:** In a 1927-1928 Queens rented flat the cold box was almost always a second-hand wooden (oak) icebox lined with zinc or tin, ice in an upper compartment behind its own door, wire shelves in the food compartment below, and a drip pan that had to be emptied; four flats only (1A, 3A, 5B, 6C) own a new, expensive GE DR-series monitor-top electric refrigerator with the compressor and copper cooling coil sitting on the lid like a hat.
- **Confidence:** medium

From three metres the icebox reads as one plain orange plank box: both leaves span the full 0.70 m carcass width with no stiles, lever latches or hinge plates showing, so nothing says 'cabinet with two doors' the way the North Star section and the Temperator box do. The object class is right (oak carcass, zinc chambers, small ice door over the food door, pull-out drip tray); confidence is medium because the shed's front bearing images the +Z back board (fridge_prop.gd has no warehouse_rotation_y()), so the door face was judged edge-on from the side bearing and from the script.

**Modelling**

  - Narrow both leaves from 0.70 m to 0.55 m (food door box 0.55 x 0.69 x 0.035, ice door 0.55 x 0.235 x 0.035) and move their hinge pins to x = 0.075 in door space, so the two 75 mm cheek edges read as face-frame stiles between the existing top and bottom front rails; the leaves currently overlay the cheeks and the whole front reads as one slab.
  - Replace the food door's 0.085 x 0.055 x 0.045 latch block and 0.18 m vertical bar pull with a cast lever latch: one 0.11 x 0.022 x 0.014 BRASS_DULL box pivoted on a 0.020 r x 0.006 rose at (ICE_W - 0.075, 0.60), tilted 20 deg; give the ice door the same lever at 0.08 m in place of its 0.12 m bar. Lever latches are the hardware the North Star engraving and every 1910s catalogue box show.
  - Hinges: the food door's two 0.014 r x 0.08 pins get a 0.02 x 0.08 x 0.004 BRASS_DULL leaf each on the door face; the ice door has no hinge pins at all, so add two pins plus leaves at y 1.00 and 1.17 on the hinge side.
  - Drip-tray front (0.52 x 0.11 at y 0.15) overlaps the lower front rail (y 0.1925-0.2475, same z band) by 12 mm; shorten the tray front to 0.09 tall (y 0.095-0.185) so the tray reads as its own drawer with a shadow line above it.
  - Leave the four 55 mm block feet and the recessed kick: Bohn-class boxes stood on blocks or short turned feet, and the 0.70 m width is ruled.

**Texturing**

  - oak_quartered renders on the side bearing at median sRGB (132,80,49): a saturated straight grain that reads as rough-sawn orange plank rather than a varnished quarter-sawn carcass with ray fleck. Pull the four _oak_tint() tones about 20% down in saturation (warmest to about 0.58,0.50,0.40) so the eleven-year-old finish reads golden-brown.
  - WATER_STAIN is a flat #301b0e box (one of the census's two flat surfaces on this variant); retexture it to the existing `plaster_stained` or `fx_drip` key with a dark tint so the stain under the tray has a feathered edge instead of a painted bar.
  - Hand wear at latches and pulls is ruled but not built: a 0.12 x 0.10 patch of oak_quartered tinted (0.45,0.38,0.30) around each lever on the leaf face puts sixteen years of hands where the hand goes.

**References used**

  - File:Sectional View of the North Star Refrigerator.png - Public domain - https://commons.wikimedia.org/wiki/File:Sectional_View_of_the_North_Star_Refrigerator.png
  - File:Temperator refrigerator, 1920s (color corrected).jpg - CC BY 4.0 - https://commons.wikimedia.org/wiki/File:Temperator_refrigerator,_1920s_(color_corrected).jpg
  - File:Dr. Evans' How to keep well; (1917) (14583628198).jpg - No restrictions - https://commons.wikimedia.org/wiki/File:Dr._Evans%27_How_to_keep_well;_(1917)_(14583628198).jpg
  - (5 other plates on the sheet not relied on)

### 20. door - 1928 apartment entry

- **Priority** 3.44 (gap 1.13, tier touched_often, installed 120, review discount 0.6)
- **What we have:** 0.95 x 2.12 x 0.18 m, floor mount, 1068 triangles, 5 surfaces, 0% flat colour
- **Real object:** A 1928 apartment-house contractor door: a standardized painted stile-and-rail leaf with two recessed fields, three mortised steel butt hinges and a knob on a long brass backplate over a mortise lock, hung in the building's older 1912 openings.
- **Confidence:** medium

The leaf is the right 1928 contractor two-field door at 0.91 x 2.13 m with the corridor security stack in place (closer, peephole, kick plate, knob on a long backplate, three jamb barrels), but the added cylinder deadbolt the variant calls for is not built, and the brass kick plate renders as the brightest, most patterned thing on the leaf instead of dull sheet polished only where shoes land. Object class is right; only the two peephole plates on the sheet are on-topic (the Bekescsaba facade, the 1904 and 1909 mansion interiors and the Lutyens gate are not), so the scores lean on the variant description and the script.

**Modelling**

  - Add the cylinder deadbolt the variant names and the script omits: one brass_dull cylinder r 0.016 x 0.006 proud of the outer face at (width - 0.085, 1.12, -0.025) and one thumbturn box 0.012 x 0.030 x 0.006 on the inner face at the same height (2 primitives).
  - Enlarge the peephole from a r 0.014 x 0.018 nub to a flanged viewer: add an outer flange cylinder r 0.018 x 0.004 at z -0.026 in front of the existing barrel so it reads as a brass eyepiece from the corridor at 1.49 m (1 primitive).
  - Give the closer a two-piece arm: keep the 0.33 x 0.018 x 0.018 main arm and add a 0.18 x 0.016 x 0.016 forearm box from its free end at y = height - 0.03 angled about 0.55 rad toward the frame head, so the arm folds the way a surface closer's does instead of running as one bar off the edge of the leaf (1 primitive).
  - Add hinge leaves so the three r 0.010 x 0.105 barrels read as mortised butts: one 0.025 x 0.105 x 0.003 brass_dull box on the leaf's hinge edge at x 0.012 beside each barrel (3 primitives on _body so they swing with the leaf).

**Texturing**

  - Kick plate: keep brass_dull but drop the tint from (0.82, 0.74, 0.55) to about (0.62, 0.56, 0.42) and pass scale_mult 2.5 so the map's hatching stops tiling as a visible pattern across a 0.78 x 0.17 m plate.
  - Build the shoe crescent the script comment claims: one 0.30 x 0.05 x 0.001 box in 'brass' (metallic 0.85) laid over the kick plate at (width * 0.5 - 0.05, 0.10, -0.0335), the only polished brass on the door.
  - Wear where hands and shoes go: a 0.10 x 0.22 x 0.001 'fx_grease' decal box (staged in MatLib.SETS) centred on the backplate at 0.94 m and a 0.30 x 0.20 x 0.001 'soot' decal low on the lock stile at y 0.35, offset by finish_variant so the 23 entries are not identical; 'fx_scuff' is the better catalog key for the stile but is not in MatLib.SETS and would need GODOT_STAGE.

**References used**

  - File:Door ~ peep hole - Flickr - striatic.jpg - CC BY 2.0 - https://commons.wikimedia.org/wiki/File:Door_~_peep_hole_-_Flickr_-_striatic.jpg
  - File:Peephole01.jpg - CC BY 2.0 - https://commons.wikimedia.org/wiki/File:Peephole01.jpg
  - (5 other plates on the sheet not relied on)

### 21. flush_dome - flush_dome

- **Priority** 3.44 (gap 2.22, tier leave_alone, installed 90, review discount 1.0)
- **What we have:** 0.55 x 0.55 x 0.33 m, wall mount, 2242 triangles, 5 surfaces, 20% flat colour
- **Real object:** A ceiling 'schoolhouse' or globe fixture: a small stamped-brass canopy with a 4- or 6-inch fitter ring holding a blown opal (milk) glass globe or shallow bowl by its neck over one Mazda lamp, the ordinary 1920s fitting for apartment corridors, halls and the cheaper bedrooms.
- **Confidence:** medium

The retaining rim is built as a vertical hoop: make_ring lies flat in XZ and the script rotates it 90 degrees about X, so the front bearing shows a brass arch standing over the canopy and the side bearing a thin vertical stalk, a basket handle rather than a fitter ring; with a canopy that steps wider away from the ceiling (r 0.115 then r 0.135) over a 0.33 m bowl, the fixture reads as a lidded pot. No reference was available (no permissively licensed plate matched the queries), so this is scored against the real-object description and the in-script ruling; the object class is right, a flush opal fixture on brass.

**Modelling**

  - Delete the line rim.rotation_degrees = Vector3(90, 0, 0): the torus then lies flat at y -0.072 as a ring around the neck, which is what a fitter is (0 primitives, 1 line).
  - Re-proportion to a 4-inch fitter: canopy make_cyl r 0.065 -> 0.055 x 0.020 at y -0.010, collar r 0.052 x 0.030 at y -0.035, fitter ring make_ring r 0.058 tube 0.007 at y -0.055 with three thumb screws make_cyl r 0.004 x 0.010 at 120 degrees; today the 0.27 m canopy is 82 percent of the glass width where the real fitting is about half (5 primitives replacing 3).
  - Globe held by its neck: SphereMesh r 0.125, height 0.22, centred at y -0.175 so the neck passes through the ring and the glass hangs clear of the canopy; total drop 0.285 m, in the real 0.25-0.30 m for an 8-10 inch schoolhouse globe.
  - Shed registration, not a prop edit: the index mounts this kind on a wall and the bearings show it hung beside a wall plane, while the prop builds downward from y 0 as a ceiling fixture; if the warehouse mount table can take it, register flush_dome as ceiling so the bearings show it under a plane.

**Texturing**

  - 'brass' at metallic 0.85 with the aged-brass map renders as polished gold under flat light; for a bedroom and corridor fitting of lacquered brass or brass-plated steel, retexture canopy and ring to 'brass_dull' (metallic 0.30) and keep 'brass' only for the thumb screws.
  - The bowl is the shared emissive material (flat (1.0, 0.97, 0.9) with emission), acceptable for opal; give its unlit albedo 'milk_glass' (staged) so a powered-off dome reads as white glass, not a cream plastic ball.
  - Wear: the 90 installed domes are identical; the per-name seed already drives tone and gain, so use it to darken the upper bowl tint by 0.00-0.08 for dust so the corridor's eight domes are not eight copies.

**References used**

  - no reference was relied on; the critique is from the script and the notes

### 22. sink - sink / lavatory — calm fired glaze

- **Priority** 3.43 (gap 0.99, tier carries_game, installed 43, review discount 0.6)
- **What we have:** 0.66 x 1.01 x 0.51 m, floor mount, 12636 triangles, 11 surfaces, 27% flat colour
- **Real object:** Two cheap J. L. Mott Iron Works catalog fixtures: the compact 24-inch enameled apartment-house lavatory with integral back and apron, compression cross taps, pedestal and exposed nickel-plated waste (Mott Modern Plumbing 1908, plate 1053), and Mott's smallest roll-rim enameled-iron kitchen sink, 24 x 18 x 6 inches, with integral back, wall hanger or iron legs, optional porcelain-enamel drainboard and nickel-plated Fuller-pattern brass faucets (Mott Plumbing Fixtures 1908, plates 7300–7306).
- **Confidence:** high

The most wrong thing is the exposed waste the ruling calls legible from the doorway: the Ø 36 mm nickel tailpiece at z -0.02 and the 0.075 m torus P-trap at (0, 0.40, 0.06) both sit inside the solid pedestal column, whose radius is 0.094 m at that height, so in every bearing the pedestal is a plain post with two brass-tan risers beside it and no trap or tailpiece renders, while the integral back is a 0.61 x 0.18 x 0.045 m slab set on the rear of a 0.66 m rim, 25 mm short of the rim at each end and with no cove into it, reading in the high quarter as a board propped on the basin. Object class is right: the compact enamelled apartment lavatory with pedestal, integral back, wall cross valves, bridge and swan spout of the Mott class, rim at 0.79 m, 0.61 m across, and the fired-glaze plate is the right substance; what is left is a nickel disc standing in for a rubber stopper and chain, cross arms 92 mm across where the 1908 pattern is 64, and a fixture that reads factory-new in a flat rented for sixteen years.

**Modelling**

  - Free the waste: narrow the pedestal column (make_cyl 0.085/0.11 radii, 0.49 m tall) to 0.060/0.075 above y 0.30 and move the tailpiece and trap to z -0.095 so the U hangs in front of the column as the ruling intends; or, if the pedestal is to conceal it as real pedestals do, delete the two hidden primitives (the 64 x 32 torus alone is about 4,000 of this prop's 12,636 triangles).
  - Widen the integral back box from 0.61 to 0.66 m (the rim's outer width, w*0.5 + 0.025 each side) and add one cove, a make_cyl(0.020, 0.020, 0.66) rotated 90 degrees about Z at y 0.79, z 0.18 in PORCELAIN, so the back meets the rim as one casting instead of a slab whose ends stop short of the torus.
  - Cross handles: the two arm boxes per valve are 0.092 m long; a 1908 Mott cross is 2.5 in, so 0.064 m; the Ø 68 mm escutcheon and Ø 46-54 mm stem can stay. Same change in _build_pair_taps serves the kitchen sink.
  - Stopper: the Ø 72 x 10 mm nickel disc is a pop-up plug; the catalog stopper is rubber on a bead chain. Keep the disc as the rigged Stopper node, add a make_cyl(0.0015, 0.0015, 0.16) chain from its edge to a Ø 10 mm chain stay on the back panel at (0.12, 0.83, 0.18): 2 primitives.
  - The two Ø 14 mm supply risers rise from y 0.03 to 0.76 and stop 20 mm under the panel with nothing at either end; add two angle stops make_cyl(0.012, 0.012, 0.030) at (±0.09, 0.40, 0.18) and two floor escutcheons make_cyl(0.020, 0.020, 0.004) at y 0.002: 4 primitives, all NICKEL so they merge into the existing nickel_plated draw.

**Texturing**

  - porcelain_fixture is right and stays: the close crop shows smooth warm ivory with no grain, exactly the ruled plate.
  - Wear that says sixteen years, since the 0.40 m plate is shared by 24 basins and must stay clean: a grey water-line ring, make_ring(0.20, 0.002) scaled to the bowl ellipse at y 0.755, in the existing MINERAL colour (0.79, 0.76, 0.65) left flat; one rim chip, a 12 x 8 x 1 mm box on the rolled rim front tinted through cast_iron at (0.33, 0.32, 0.29), placed by hash(unit) so 24 basins chip in 24 places.
  - Nickel worn to brass where hands go: tint only the four cross-arm boxes' nickel_plated row toward (0.80, 0.72, 0.55); the stems, escutcheons, bridge and spout keep the ruled warm-silver (0.93, 0.91, 0.84) tint.
  - The mineral film disc at (0.22, 0.805, -0.19) is the right thin film (0.8 mm) and the right placement under the ruling; leave it.

**References used**

  - File:Mott's Open Lavatory (NYPL b15260162-487472).jpg - Public domain - https://commons.wikimedia.org/wiki/File:Mott%27s_Open_Lavatory_(NYPL_b15260162-487472).jpg
  - File:Mott's Open Lavatory (NYPL b15260162-487473).jpg - Public domain - https://commons.wikimedia.org/wiki/File:Mott%27s_Open_Lavatory_(NYPL_b15260162-487473).jpg
  - (2 other plates on the sheet not relied on)

### 23. cage_bulb - cage_bulb

- **Priority** 3.35 (gap 2.22, tier leave_alone, installed 77, review discount 1.0)
- **What we have:** 0.55 x 0.78 x 0.14 m, ceiling mount, 8402 triangles, 7 surfaces, 29% flat colour
- **Real object:** A drop-cord or pendant lamp holder with a wire bulb guard: a porcelain or brass socket on cloth cord, a stamped-steel wire cage clipped over a clear pear-shaped tungsten Mazda lamp, sometimes under a green-and-white porcelain-enamelled RLM reflector; the standard cellar, boiler-room and storage fitting of the 1920s.
- **Confidence:** medium

Proportion is the most wrong thing: the socket cap is a Ø 100-120 x 40 mm cylinder where a brass or porcelain drop socket is about Ø 36 x 60 mm, the lamp is a Ø 90 x 110 mm ellipsoid where a clear Mazda A-lamp is Ø 60 x 110 mm, and the guard is three Ø 150 mm great-circle tori meeting at the poles, a birdcage globe rather than the basket of 8-12 vertical wires under two or three hoops that the kind describes, so the three_quarter bearing reads as a small lantern with a glowing ball inside. No usable reference: the 1898 handbook pull is a cement-company trade mark and the 1920 pressroom photograph shows only drop-cord reflector pendants at distance, so this is judged against the kind description (unverified) at medium confidence; the object class is right, a drop-cord lamp holder with a wire guard on a cloth cord.

**Modelling**

  - Cap: replace make_cyl(0.05, 0.06, 0.04) at y -0.425 with a socket shell make_cyl(0.018, 0.018, 0.060) at y -0.450 and a cord-grip cap make_cyl(0.011, 0.011, 0.015) at y -0.412: 2 primitives for 1, and the fitting stops reading as a shade.
  - Lamp: SphereMesh r 0.045 h 0.11 becomes r 0.030 h 0.060 at y -0.515 with a neck make_cyl(0.012, 0.017, 0.035) at y -0.480 between shell and bulb: the pear read from three metres, 2 primitives for 1. Move the returned bulb position and the OmniLight to y -0.515 with it.
  - Guard: the three TorusMesh rings at 64 x 32 default segments are about 2,000 triangles each, most of this prop's 8,402. Replace them with a basket: hoops make_ring(0.048, 0.0015) at y -0.475, make_ring(0.052, 0.0015) at y -0.530 and make_ring(0.030, 0.0015) at y -0.580, plus eight make_cyl(0.0015, 0.0015, 0.115) wires at 45-degree steps tilted 12 degrees inward from the top hoop to the bottom: 11 primitives at 24 x 6 ring segments, about 900 triangles.
  - Cord: r 0.0025 to 0.004 (an 8 mm twisted cloth pair), and a Ø 60 x 15 mm ceiling receptacle make_cyl(0.030, 0.030, 0.015) at the anchor in the enamel colour (0.88, 0.86, 0.80): 1 primitive, only if the anchor is not already buried in ceiling geometry.

**Texturing**

  - Socket shell and cord-grip cap: build them in the brass colour (0.62, 0.55, 0.30) so the existing retexture row sends them to 'brass'; today the cap shares the guard's 'metal' and reads as the same dark galvanized steel as the wires.
  - Guard stays 'metal' (galvanized worn, metallic 0.9), the right substance for a Benjamin or Appleton wire guard; lift its tint from (0.46, 0.46, 0.50) to (0.60, 0.60, 0.58) so 1.5 mm wires do not go black against the lamp.
  - Lamp: keep the emissive envelope, the LightRig depends on it. A visible filament (two Ø 1 mm emissive tubes inside an alpha-0.25 glass sphere) is a new ad-hoc material and waits for the family to open.
  - Wear, restrained because it is 77 cellar fittings: a soot band on the socket shell's upper 15 mm (tint toward (0.30, 0.28, 0.26)) and rust at three hoop-to-wire welds (Ø 4 mm discs through cast_iron at (0.48, 0.20, 0.10)), placed by hash(name).

**References used**

  - File:The lighting of printing plants - information compiled by A.D. Bell. (1920) (14597069778).jpg - No restrictions - https://commons.wikimedia.org/wiki/File:The_lighting_of_printing_plants_-_information_compiled_by_A.D._Bell._(1920)_(14597069778).jpg
  - (1 other plate on the sheet not relied on)

### 24. kitchen_linear - kitchen_linear

- **Priority** 3.33 (gap 3.62, tier leave_alone, installed 10, review discount 1.0)
- **What we have:** 0.72 x 0.55 x 0.13 m, wall mount, 182 triangles, 3 surfaces, 33% flat colour
- **Real object:** A 1927-28 rented-flat kitchen was lit by one Mazda lamp in a glazed-porcelain keyless or pull-chain ceiling receptacle, bare or under a flat opal 'kitchen' shade on a short brass stem; nothing linear existed, because the fluorescent tube is a 1938 product and even General Electric's tubular incandescent Lumiline dates from 1931.
- **Confidence:** medium

It is a fluorescent batten - a 720 x 50 x 130 mm enamel housing against the ceiling with a dia 40 x 620 mm glowing tube and a deeper 'fluorescent' dropout authored into flicker profile 4 for this kind alone - in a 1927-28 kitchen, ten years before the fluorescent tube and four before GE's Lumiline, where the real fitting was one Mazda lamp in a porcelain pull-chain receptacle or under a flat opal shade on a short brass stem. The object class is wrong, and the resolution (point fixture or least-wrong linear) is ruled the owner's; none of the sheet's four references shows a period kitchen ceiling fitting (a remodelled HAER kitchen with no fixture in frame, a Unity Temple sconce, a 1944 brochure, a modern Japanese kitchen), so this is judged against the kind text and the script.

**Modelling**

  - Option A, porcelain pull-chain receptacle with a bare Mazda lamp: a dia 0.10 x 0.045 `porcelain_fixture` cylinder against the ceiling, a dia 0.035 x 0.030 brass socket shell below it, a bulb_ sphere dia 0.06 (height 0.11, teardrop) centred at -0.11, and a dia 0.002 x 0.18 pull chain with a dia 0.008 bead hanging at x +0.03; OmniLight3D at -0.12.
  - Option B, flat opal kitchen shade on a stem: dia 0.12 x 0.03 brass canopy, dia 0.012 x 0.12 brass stem, a dia 0.06 fitter collar, and a bulb_ dish made of make_cyl 0.10 -> 0.14 x 0.06 with a dia 0.28 x 0.012 opal flat under it at -0.18; pull chain from the fitter; light at -0.16.
  - Option C, least-wrong linear if the owner keeps a bar (the 1931 Lumiline): delete the 0.72 x 0.05 x 0.13 box; two dia 0.05 x 0.03 `porcelain_fixture` disc holders 0.46 m apart on a 0.50 x 0.03 x 0.03 brass channel and a bulb_tube dia 0.03 x 0.45; light at -0.05.
  - Whichever is chosen, re-author _author_personality so profile 4's 0.11 dropout for this kind becomes the tungsten family's 0.065; the deeper dropout is the fluorescent tell.
  - Before touching the mesh: gen_layout.py also issues this kind as the bodega's lights (F01_BODEGA_LT_n) and the bar's can lights (F01_BAR_LT_CANn), ten installed in all; a kitchen receptacle may not suit those, so split the kind or give them their own _build_body branch first.

**Texturing**

  - Receptacle or disc holders: `porcelain_fixture` (catalog, roughness 0.16) tinted (0.95, 0.94, 0.90); socket shell and pull chain in `brass_dull`; the housing's `enamel` retexture goes away with the box.
  - Bulb: keep the bulb_ emissive material but warm the tone from the coolest interior (0.95, 0.93, 0.82) to the tungsten family used by flush_dome (1.0, 0.86, 0.66); a Mazda lamp is warm.
  - Opal shade (option B): `milk_glass` (catalog) with emission near 0.8x so the dish reads as glass rather than a white marker.
  - Wear per household, like the stove's grime seed: an `fx_grease` decal dia 0.08 at alpha 0.4 on the underside of the shade or receptacle in the flats that cook, and a chipped porcelain edge as a darker tint step on the rim.

**References used**

  - none relied on; the 4 plates on the sheet were off-topic

### 25. door - cabinet leaf

- **Priority** 3.28 (gap 1.03, tier touched_often, installed 120, review discount 0.6)
- **What we have:** 0.54 x 0.70 x 0.06 m, floor mount, 168 triangles, 3 surfaces, 0% flat colour
- **Real object:** A 1928 apartment-house contractor door: a standardized painted stile-and-rail leaf with two recessed fields, three mortised steel butt hinges and a knob on a long brass backplate over a mortise lock, hung in the building's older 1912 openings.
- **Confidence:** high

A 0.55 x 0.72 x 0.032 m painted cupboard leaf with one knob, the right thing at the right size, but the 'recessed panel' is built proud: the 0.006 m field box sits at z -0.020 on a slab whose face is at -0.016, so the panel stands 7 mm out from the frame, the opposite of the Hoosier and built-in cabinet doors on the sheet, and there are no hinges at all so it floats in the shed. Object class is right.

**Modelling**

  - Make the recess real: delete the proud field box and add four 'trim' frame boxes 0.060 wide x 0.006 thick at z -0.019 along the edges (two of (width - 0.015) x 0.060 and two of 0.060 x (height - 0.135)), so the frame stands 6 mm proud and the slab face is the recessed field; 4 primitives replacing 1, slab unchanged at 0.032.
  - Two small butt hinges on the hinge edge: brass_dull cylinders r 0.005 x 0.050 at (0, 0.10, -0.014) and (0, height - 0.10, -0.014) on _body (2 primitives); the variant lists small brass or steel butts and the shed shows a leaf with no way to hang.
  - The knob: keep r 0.014 x 0.026 but add a rose cylinder r 0.010 x 0.004 against the face so it reads as a turned brass knob on a shank rather than a peg (1 primitive).

**Texturing**

  - Keep 'trim' at tint (0.70, 0.68, 0.61); once the recess is geometric the second tint (0.56, 0.54, 0.48) should become the same tint darkened 0.06 so the field reads as shadow, not a second paint.
  - Add the hand: a 0.10 x 0.10 x 0.001 'fx_grease' decal (staged) around the knob at (width - 0.055, height * 0.53) on the outer face; a kitchen cupboard door is grubbiest at the knob and this one is clean.

**References used**

  - File:Hoosier Cabinet in original condition.jpg - CC BY-SA 4.0 - https://commons.wikimedia.org/wiki/File:Hoosier_Cabinet_in_original_condition.jpg
  - File:The Architect and engineer of California and the Pacific Coast (1917) (14595380310).jpg - No restrictions - https://commons.wikimedia.org/wiki/File:The_Architect_and_engineer_of_California_and_the_Pacific_Coast_(1917)_(14595380310).jpg
  - (5 other plates on the sheet not relied on)

### 26. fridge - fridge / 1927 monitor-top

- **Priority** 3.11 (gap 1.10, tier carries_game, installed 18, review discount 0.6)
- **What we have:** 0.72 x 1.66 x 0.74 m, floor mount, 11412 triangles, 12 surfaces, 33% flat colour
- **Real object:** In a 1927-1928 Queens rented flat the cold box was almost always a second-hand wooden (oak) icebox lined with zinc or tin, ice in an upper compartment behind its own door, wire shelves in the food compartment below, and a drip pan that had to be emptied; four flats only (1A, 3A, 5B, 6C) own a new, expensive GE DR-series monitor-top electric refrigerator with the compressor and copper cooling coil sitting on the lid like a hat.
- **Confidence:** high

Cabinet and mechanism footprint match the 1929 Tallahassee machine, but the crown is a 0.17-to-0.075 m cone that reads as a pointed bell, the three copper hoops sit 70 mm apart like barrel bands instead of a wound coil, and the four legs are thin chrome rods where the DR-series stands on stout white-enamelled cast legs. It is the right object (1927-32 open-coil GE, one full-height door, long lever latch on the right, hinges on the left) and reads correctly as one to two years old.

**Modelling**

  - Replace the cap cone (_cyl_on r 0.075 top / 0.17 bottom, 0.075 tall at y 1.622) with a flat-topped crown: a CylinderMesh r 0.19 to 0.17 x 0.035 under a SphereMesh r 0.17 scaled to 0.05 tall, so the mechanism is a hat, not a bishop's mitre; the Tallahassee drum is flat-topped with a shallow dome.
  - Condenser: six COPPER torus rings (tube r 0.010) from y 1.375 to 1.550 on a 0.035 pitch instead of three on 0.070; they merge into the carcass draw so the cost is triangles only, and the ring stack starts reading as wound tubing.
  - Legs: replace the four r 0.018 to 0.014 x 0.17 CHROME cylinders with ENAMEL legs r 0.032 to 0.020 x 0.20 on a 0.045 r x 0.012 foot disc and raise the cabinet base to y 0.235; the real legs are white-enamelled cast steel, not plated wire.
  - Nameplate box 0.18 x 0.08 at y 1.28 is about twice the real GE plate; make it 0.09 x 0.032 and keep it centred on the rail above the door.
  - Door: give the leaf a 6 mm reveal (0.708 wide instead of MON_W, hinge pins on the jamb) so the side bearing shows a hung door rather than a flush face; the applied 0.59 x 0.90 x 0.014 panel can stay as the pressed-steel field.

**Texturing**

  - DARK (drum and cap) has no row in retexture() and is the census's two flat #1f1a16 surfaces; map it to the existing `cast_iron` key with tint (0.18,0.17,0.16) so the hermetic dome reads as black japanned iron with sheen instead of flat paint (the three_quarter bearing samples it at (52,46,41), textureless).
  - The enamel key at roughness 1.00 clips to (255,255,229) on the three_quarter bearing under flat light and reads as matte cream; on the monitor-top only, set the material roughness to about 0.35 (metallic 0) so the pressed-steel lacquer shows the soft reflections the Tallahassee and Weizmann cabinets show.
  - chrome (brushed_steel plate at m1.00 r1.00) reads as flat light grey on the latch bar and hinge pins; roughness 0.30 on those vertical parts only, since horizontal high-metallic surfaces read black under the brief's rule.

**References used**

  - File:1929 General Electric 'Monitor Top' Refrigerator, Tallahassee Automobile Museum.jpg - CC BY-SA 4.0 - https://commons.wikimedia.org/wiki/File:1929_General_Electric_%27Monitor_Top%27_Refrigerator,_Tallahassee_Automobile_Museum.jpg
  - File:General Electric "Monitor-Top" refrigerator at Chaim Weizmann mansion.jpg - CC BY-SA 3.0 - https://commons.wikimedia.org/wiki/File:General_Electric_%22Monitor-Top%22_refrigerator_at_Chaim_Weizmann_mansion.jpg
  - (6 other plates on the sheet not relied on)

### 27. speaker - speaker

- **Priority** 3.00 (gap 1.46, tier lighter_pass, installed 7, review discount 1.0)
- **What we have:** 0.34 x 0.56 x 0.32 m, floor mount, 2312 triangles, 9 surfaces, 44% flat colour
- **Real object:** In a real 1927-1928 Queens rented flat the loudspeaker was the wireless set's separate speaker: a magnetic-motor paper cone in a wooden or metal frame (RCA Radiola 100A, Atwater Kent Type E, Western Electric 540AW) or a bell-mouthed horn (Atwater Kent Model M, Magnavox R3) standing on top of the cabinet, with moving-coil electrodynamic units (Rice-Kellogg 1925, RCA 104, Jensen 1927) only just arriving and dear.
- **Confidence:** high

The right class under the Rule of Signal, a 0.34 x 0.55 x 0.30 m veneer two-way the size of the Heresy on the sheet, but the drivers are built backwards: make_cyl puts r_top on +Y and the -90 degree X rotation sends +Y into the cabinet, so the 0.10 m woofer cone and the 0.052 m horn mouth both point away from the listener and the front bearing shows a black ring around a 28 mm nub and a 16 mm nub where a dished cone and a flaring horn should be, with the port as a raised puck. Object class is right; detail and salvage wear are the gaps.

**Modelling**

  - Flip the cone: make_cyl(0.028, 0.10, 0.05, Vector3(0, 0.36, 0.13)) with the same -90 rotation puts the 0.10 m rim at the baffle plane (z 0.155) and the apex 0.05 m inside; move the dust cap to (0, 0.36, 0.112) as r 0.026 -> 0.020 x 0.018 so it sits at the recessed apex (0 new primitives, 2 edits).
  - Flip the horn the same way: make_cyl(0.016, 0.052, 0.035, Vector3(0, 0.115, 0.138)) so the 0.052 m mouth is flush with the baffle and the throat recedes; or build the sectoral horn the Altec 604 plate shows from a make_box 0.12 x 0.05 x 0.03 mouth frame with a black make_box 0.10 x 0.035 x 0.001 throat plate behind it (2 primitives).
  - Port as a hole: replace the r 0.030 x 0.02 puck at z 0.152 with a black make_cyl r 0.030 x 0.06 sunk to z 0.12 and a make_ring r 0.030 tube 0.004 at the baffle plane in the baffle colour (2 primitives replacing 1).
  - Pegs: four grille-peg positions at the baffle corners (+/-0.13, 0.05) and (+/-0.13, 0.50), three built with the upper-right missing; today both pegs are on the left edge and the top one at y 0.55 straddles the cabinet's top edge (3 primitives).
  - Rear terminal plate: make_box 0.06 x 0.04 x 0.004 at (0, 0.10, -0.152) in the bakelite colour with two make_cyl r 0.005 x 0.008 screw terminals and a maker's label make_box 0.08 x 0.05 x 0.001 above it in 'paper' (4 primitives); the back is bare veneer today.
  - Optional, to match every monitor on the sheet: put the horn above the woofer (woofer centre y 0.20, horn y 0.43), the Heresy and 604 arrangement, instead of the inverted one the script chose.

**Texturing**

  - Surround: the flat (0.16, 0.15, 0.14) torus should be the pleated-paper or doped-cloth surround VIII.4 requires; add it to the retexture table as 'paper' tinted (0.30, 0.28, 0.25) and the dust cap as 'paper' tinted (0.45, 0.42, 0.38); with the cone flipped the 'paper' key finally shows.
  - Baffle: the (0.10, 0.095, 0.09) flat slab is black-painted hardboard; retexture to 'bakelite_black' (staged, roughness 0.28) or 'wood_dark' tinted (0.25, 0.24, 0.23) for grain, which with the port ring drops the flat share from 0.44 to under 0.2.
  - Salvage wear on the veneer: a 0.03 x 0.03 x 0.001 'soot' decal on the top face at (0.10, 0.551, 0.05) for the cigarette burn, a 0.09 x 0.09 x 0.001 ring decal in 'fx_grease' for the water ring, and a chipped-corner box 0.02 x 0.02 x 0.02 in the baffle colour let into the front top-left corner; the 'one missing grille peg' is the only wear cue built and it is not readable from the front ('fx_burn' and 'fx_drip' are the catalog keys for these but are not in MatLib.SETS).

**References used**

  - File:Altec 604 Duplex Loudspeaker.jpg - CC0 - https://commons.wikimedia.org/wiki/File:Altec_604_Duplex_Loudspeaker.jpg
  - File:Cutaway View Of Altec 604 Duplex Loudspeaker.jpg - CC0 - https://commons.wikimedia.org/wiki/File:Cutaway_View_Of_Altec_604_Duplex_Loudspeaker.jpg
  - File:Line Magnetic LM 218ia tube amplifier (22931532793).jpg - CC BY 2.0 - https://commons.wikimedia.org/wiki/File:Line_Magnetic_LM_218ia_tube_amplifier_(22931532793).jpg

### 28. exhaust_fan - exhaust_fan

- **Priority** 2.96 (gap 1.75, tier lighter_pass, installed 4, review discount 1.0)
- **What we have:** 0.84 x 0.95 x 0.86 m, floor mount, 1548 triangles, 8 surfaces, 0% flat colour
- **Real object:** One of four 1928 commercial direct-driven propeller exhaust fans on the Orison roof, each on a sheet-metal plenum over a curb, terminating a shared bathroom ventilation riser (V-A to V-D), with an enclosed cast motor and belt guard, gravity back-draft louvers, a bell transition and a broad rain cap; it is building plant, never a private bathroom extractor.
- **Confidence:** medium

None of the four references on this sheet is usable - a Mughal hammam roof oculus, an attic floor ventilator and two aerial views of a wind tunnel - so this is judged against the real_object text and the notes; the biggest gap is that the external cast motor and belt guard, the parts that distinguish central plant from a decorative vent, render as one dark portrait rectangle on the +X face because the motor end cap is only 35 mm proud of the guard and shares its cast_iron texture, and the gravity louver is glued flush onto the service panel on the never-captured -Z face. The object class (ILG-pattern 1928 roof exhauster on a plenum) is ruled and respected.

**Modelling**

  - Motor: the r 0.105-0.12 x 0.33 cylinder centred at x 0.24 has 0.215 m of its length inside the plenum (x -0.29 to 0.29) and its end cap is swallowed by the 0.12 x 0.38 x 0.24 belt-guard box at x 0.25-0.37 (the side bearing shows one dark 0.24 x 0.38 rectangle). Move the motor fully outside to x 0.50 on two 0.03 x 0.10 x 0.20 iron bracket boxes and make the guard a 0.05 x 0.40 x 0.20 vertical box running from the motor pulley up to shaft height at y 0.70, so motor, guard and drive read as three things.
  - Louver and service panel overlap: the four 0.26 x 0.045 x 0.012 slats at x 0 +/- 0.13, y 0.425-0.575, z -0.322 sit 1.5 mm in front of the 0.31 x 0.30 panel at x -0.10 (x -0.255 to 0.055, face z -0.3145) in the same tint, so the louver cannot be seen even when the -Z face is rendered. Put the panel at x -0.20 (0.20 x 0.30) and the louver at x +0.13 in a 0.30 x 0.24 x 0.02 frame with 6 mm gaps between slats, or move the gravity shutter into the bell throat (four 0.24 slats at y 0.72-0.86) where a back-draft damper hangs on a vertical-discharge unit.
  - Plenum and curb are two plain boxes with no seams: add a 0.012 x 0.012 folded corner angle on the four plenum verticals, eight r 0.006 x 0.004 rivet heads per face edge (merged), and a 0.72 x 0.03 x 0.02 flashing lip where the plenum meets the curb - sheet metal reads through its seams.
  - Rain-cap braces are four 0.045 x 0.19 x 0.045 iron posts at r 0.25; period caps sit on flat strap legs bolted to the bell rim - replace with four 0.04 x 0.19 x 0.006 straps with a 0.03 x 0.03 x 0.006 gusset each.
  - The rotor has no shaft: add r 0.012 x 0.30 iron from the hub at y 0.70 down to y 0.40 so the belt drive has something to turn (the blades themselves stay invisible under the cap from every standing bearing, which is right).

**Texturing**

  - trim at tint (0.39, 0.40, 0.38) renders as uniform matte khaki with no metal read; enameled sheet steel needs roughness 0.45 and a 10 % lighter tint on the top faces (cap disc, curb top) than on the verticals so the folded planes separate under flat light.
  - Wear is uniform across the stack and the four variants differ only in one tint. Add zones: cast_iron at tint 0.30 on the lower 0.10 m of the plenum (splash), a paler 0.25 x 0.30 patch of fresh paint beside the panel on -Z (repaint history), and a rust streak under the motor bracket (cast_iron tint 0.55, box 0.03 x 0.12 x 0.004) - without them the tints are not maintenance history.
  - cast_iron on the motor reads as the same grey speckle as the painted plenum; darken the motor tint to (0.28, 0.29, 0.27) and drop its albedo scale so the casting reads as a different substance from the sheet.
  - rubber_aged feet at tint (0.36, 0.34, 0.30) read as grey concrete; tint (0.24, 0.22, 0.20).

**References used**

  - none relied on; the 4 plates on the sheet were off-topic

### 29. door - 1928 apartment interior

- **Priority** 2.89 (gap 0.78, tier touched_often, installed 120, review discount 0.6)
- **What we have:** 0.85 x 2.02 x 0.18 m, floor mount, 888 triangles, 4 surfaces, 0% flat colour
- **Real object:** A 1928 apartment-house contractor door: a standardized painted stile-and-rail leaf with two recessed fields, three mortised steel butt hinges and a knob on a long brass backplate over a mortise lock, hung in the building's older 1912 openings.
- **Confidence:** medium

The closest of the family to its real object: a 0.81 x 2.03 m light-painted two-field leaf with a knob set, three barrels and none of the entry security hardware, as the variant asks; what remains is that the fields read as tinted rectangles because the recess is only 6 mm and the paint carries no use. No on-topic reference was available (the eight plates are a sash-and-door mill, two college halls, a Wright dining room, two city-hall entrances, a blot and a garden gate), so this is scored against the variant description and the notes.

**Modelling**

  - Deepen the field shadow line: move the field box from z +/-0.025 to z +/-0.019 (3 mm inside the 44 mm slab face) and thicken the stile and rail boxes from 0.018 to 0.024 so the moulding stands 10 mm proud of the field instead of 6 mm; same 20 primitives per leaf, only depths change.
  - Add hinge leaves on the hinge edge: one 0.025 x 0.105 x 0.003 brass_dull box at x 0.012 beside each of the three barrels, so the butts read as mortised hardware rather than three brass pegs on the jamb (3 primitives).
  - Add the lock face on the lock edge: a 0.025 x 0.20 x 0.002 brass_dull box at (width - 0.001, 0.94, 0), so the mortise lock reads when the leaf stands open, which is how most of the 55 interior leaves are met (1 primitive).

**Texturing**

  - Keep 'trim' with the three light tints; once the recess is geometric, lift the field tint from tint.darkened(0.18) to darkened(0.08) so the field reads as the same paint in shade rather than a second colour.
  - Per-variant wear where hands go: a 0.14 x 0.22 x 0.001 'fx_grease' decal centred on the backplate at 0.94 m and a 0.20 x 0.12 x 0.001 'soot' decal at the bottom rail, y 0.10, offset by finish_variant; both keys are staged in MatLib.SETS.

**References used**

  - none relied on; the 8 plates on the sheet were off-topic

### 30. landmark_entry - landmark entry / the Orison front door

- **Priority** 2.87 (gap 2.28, tier touched_often, installed 0, review discount 1.0)
- **What we have:** 1.15 x 2.69 x 0.38 m, floor mount, 11180 triangles, 11 surfaces, 91% flat colour
- **Real object:** A 1928 New York apartment-house street entrance: one heavy quarter-sawn oak stile-and-rail leaf, about 0.91 x 2.13 m, with glazed upper panels of wired or bevelled plate glass, a fixed glazed transom under a stepped architrave, catalogue bronze builders' hardware (Corbin, Sargent or Russwin: long cast escutcheon with knob over a covered keyhole and a thumb-latch, letter slot, jamb bell-push), four ball-tip butt hinges and a bluestone saddle.
- **Confidence:** medium

The one thing most wrong is the leaf's face: HERO_ALBEDO is a photograph of a solid four-panel Eastlake door with incised panels, and the two 0.25 x 0.62 m green wired-glass panes at 1.61 m are laid over it with their 4 x 8 iron grids, so from the front and high_quarter bearings the glazing reads as green rectangles pasted on a painted Victorian panel door, about 15 percent glass where a 1928 New York entrance leaf (the Christadora House pair on this sheet is mostly glass in bronze frames) carried 40-60 percent. The object class is right in intent - a single 0.91 x 2.13 m stile-and-rail entrance leaf under a stepped head and transom with a Corbin-pattern long escutcheon, faceted knob, thumbpiece, covered keyhole, offset pull, letter slot, jamb bell and four ball-tip butts, all at plausible heights - but the script's narrated century of accretions (a 1970s iron panic bar, a welded-shut slot, a cracked stile held by a mending plate, bronze unpolished since the sixties) sits against the ruled 1928-new door. Three bearings show the interior face only; the side bearing is black (the camera sits inside the jamb box), so the exterior pull, slot and lettering were checked in the script, not a frame.

**Modelling**

  - Glazed upper fields as openings, not overlays: build the leaf as joinery instead of a slab plus photo - two stiles 0.105 x 2.09 x 0.045 m, a bottom rail 0.075 m tall at 0.12 m, a lock rail 0.14 m tall at 0.98 m, a top rail 0.075 m at 2.035 m, a centre mullion 0.06 m wide from 1.05 to 2.0 m, two raised lower panels 0.34 x 0.78 x 0.03 m, and two glass fields 0.34 x 0.90 m from 1.10 to 2.00 m with the slab cut away behind them so the lobby shows through (nine boxes plus two glass quads replace the 0.064 m slab, the two QuadMesh faces and the eight rail boxes). Glass share rises to about 33 percent of the leaf, the low end of the class.
  - Transom over the leaf, under the head: the 0.43 m transom box now sits at 2.255-2.685 m above the 0.07 m head slab, and its pane is only 0.85 x 0.28 m in a 0.055 m box, so the front bearing reads a dark signboard with a small window. Put a 0.91 x 0.40 m light directly on the 2.13 m head (transom_y = height + 0.20 + 0.06), full opening width, with the 8 x 3 wire grid, and move the stepped architrave head to 2.55-2.685 m above it as the Christadora surround places its lintel over the glass.
  - Lettering: the 'THE ORISON  ·  1928' Label3D at font 26 / pixel 0.00115 gives about 0.03 m capitals that no bearing can read at three metres; keep the text (ruled) but make it a bronze plate 0.60 x 0.10 x 0.006 m on the head with 0.075 m capitals (pixel_size 0.0032) - the Christadora lettering is carved at roughly 0.12 m.
  - Remove the 1970s exit device: the iron box 0.73 x 0.055 x 0.085 m at 0.94 m on the inside face is a later object on a door ruled 1928 or older. If an exit device is wanted, the 1908-pattern Von Duprin is a brass tube r 0.012 m x 0.70 m on two cast brackets 0.05 x 0.08 x 0.06 m; otherwise the inside carries the same escutcheon and knob only.
  - Remove the century-of-repair geometry on a new leaf: the tilted 0.013 x 0.46 m iron crack strip and 0.075 x 0.19 m brass mending plate at 0.49 m, and the 0.27 x 0.035 m iron weld bar over the letter slot. The 1912 fabric that may show age is the jamb and the saddle, not the 1928 leaf; keep the brass slot plate 0.34 x 0.105 m with a working flap (a second box 0.26 x 0.06 x 0.006 m hinged at its top edge).
  - Head: the 1.25 x 0.07 x 0.19 m upper slab reads as a shelf in the high_quarter bearing; step it as three boxes of 0.04 m rise each (widths 1.12 / 1.19 / 1.25 m) so the battered architrave reads as mouldings rather than one plank.
  - Harness: the side bearing is black because the camera lands inside the 0.10 x 2.33 x 0.15 m jamb box; offset the side camera 0.25 m outboard for this kind, and add an exterior bearing - the door's face, the pull and the slot are on the +Z side that no current bearing shows.

**Texturing**

  - Oak: drop HERO_ALBEDO (a photograph of the wrong door) and key the leaf, stiles, rails and jamb to oak_quartered (varnished quarter-sawn white oak, ruled materials_expected), with wood_dark for the jamb interior returns; the jamb's flat (0.085, 0.032, 0.021) reads as black plastic in every bearing. Both keys already have complete runtime paths from the door_prop pass.
  - Bronze hardware: the _brass StandardMaterial3D (0.48, 0.30, 0.105 at metallic 0.84 / roughness 0.39) renders as orange plastic in the shed's flat light; use the catalog key bronze for the escutcheon, rose, pull, slot plate and bell rosette, and brass_bright only for the knob crown and thumbpiece where hands land - the two spots the script already names as worn bright.
  - Bluestone saddle: it is built in _iron (0.075, 0.070, 0.064 at metallic 0.72), which is a black metal plate; bluestone is a matte blue-grey sandstone - use limestone tinted (0.42, 0.45, 0.48) at roughness 0.9, or new key bluestone, and keep the brass wear strip.
  - Glass: the transom and pane material (0.16, 0.22, 0.20, alpha 0.66) is opaque bottle green; wired plate glass is near-clear - alpha 0.30, albedo (0.80, 0.85, 0.82), roughness 0.08, so the lobby light reads through the door at night as the notes' b_16_street_level context expects.
  - Wear that says 1928-new in 1912 fabric: the saddle worn hollow at centre (a 0.02 m darker band across the middle 0.42 m), the jamb's lower 0.30 m scuffed to 0.9 roughness, and nothing on the leaf but the knob crown polished; strip the tarnish narrative from the escutcheon.

**References used**

  - File:Christadora House entrance.jpg - CC BY-SA 4.0 - https://commons.wikimedia.org/wiki/File:Christadora_House_entrance.jpg
  - File:Christadora House entrance detail.jpg - CC BY-SA 4.0 - https://commons.wikimedia.org/wiki/File:Christadora_House_entrance_detail.jpg
  - (6 other plates on the sheet not relied on)

### 31. stove - stove / 1922 fired-enamel gas range

- **Priority** 2.86 (gap 0.93, tier carries_game, installed 18, review discount 0.6)
- **What we have:** 0.64 x 1.15 x 0.69 m, floor mount, 30276 triangles, 47 surfaces, 17% flat colour
- **Real object:** A cheap freestanding gas range sold in the first half of the 1920s: white porcelain-enamel panels skinning a pressed-steel body on an angle-iron legged base, four open gas burners on cast-iron grates, an oven below with a separate broiler pull, an exposed front valve rail, a shallow enamel splash back with a small shelf, and no clock and no oven window.
- **Confidence:** medium

The range is the right object and its ruled contract (0.64 x 0.60 footprint, grate top at 0.90, oven 0.44 x 0.34, five valves, shallow splash panel, no clock, no oven window) survives, but the shed photographed only its back and sides - every bearing looks at the +z splash-panel face while the door, broiler and valve rail sit at -z - and that back is open: no sheet-steel panel closes the carcass, so the oven liner's back and the five valve pointers show through a hollow cabinet on four round legs. Object class right; judged from the script, the notes' prior installed renders and the A-B and Reliable references rather than from the unseen front.

**Modelling**

  - Close the back: a 0.60 x 0.66 x 0.010 m IRON_DARK sheet at z +0.293 from y 0.19 to 0.85 between the two side slabs; even the cheap 1922 order was closed with plain japanned steel where it stood against the wall.
  - Angle-iron legs: replace each tapered dia 0.036-0.046 x 0.17 cylinder with an L of two 0.028 x 0.17 x 0.004 boxes at right angles (IRON), and make the two lower rails 0.020 x 0.020 boxes instead of r 0.011 tubes - the notes call the base angle-iron and a round tube reads as pipe.
  - Skin, not plinth: side slabs 0.065 to 0.020 m thick with a 0.020 x 0.020 IRON corner post behind each vertical edge, and the base slab 0.055 to 0.025, so the enamel reads as panels on a frame as the kind text describes.
  - Door hardware from the A-B photograph: two 0.045 x 0.012 x 0.006 hinge straps on the door's lower edge and a spring latch (a 0.030 x 0.015 x 0.010 BRASS_DULL box with a 0.020 lever) at the top centre - the parts a hand reaches after the bar handle.
  - Shed bearings: the warehouse's front camera looks at the +z face; give the single warehouse_variants() entry a 180 deg yaw, or fix the harness, because as it stands no run photographs the knobs and door the tier note names.

**Texturing**

  - Keep `enamel_appliance` (per-unit tint), `cast_iron` (two tones), `bakelite`, `brass_dull` and `fx_grease`; the substances read right where the bearings show them.
  - Edge chips: an `fx_scuff` strip at alpha 0.5, tinted (0.20, 0.19, 0.18), along the door's bottom edge and the shelf's front edge - chipped enamel edges are the one wear cue the A-B photograph shows that the range lacks.
  - Heat discolouration: tint the 0.006 IRON_DARK deck inlay toward (0.28, 0.22, 0.16) in a dia 0.14 ring around each burner, driven by the same unit grime seed, so the deck shows heat even on wiped 3D.
  - Legs and rails: `cast_iron` tinted japanned black (0.08, 0.08, 0.09) rather than the mid-grey (0.42, 0.40, 0.38) tint the carcass IRON row uses for everything.

**References used**

  - File:A-B Gas Range Battle Creek, Michigan in use by Ethel Leginska - LCCN2014715510 (cropped).jpg - Public domain - https://commons.wikimedia.org/wiki/File:A-B_Gas_Range_Battle_Creek,_Michigan_in_use_by_Ethel_Leginska_-_LCCN2014715510_(cropped).jpg
  - File:Reliable gas stoves and ranges (1905) (14784625792).jpg - No restrictions - https://commons.wikimedia.org/wiki/File:Reliable_gas_stoves_and_ranges_(1905)_(14784625792).jpg
  - (6 other plates on the sheet not relied on)

### 32. flue_breast - sealed 1912 thimble

- **Priority** 2.86 (gap 1.53, tier lighter_pass, installed 5, review discount 1.0)
- **What we have:** 0.41 x 0.41 x 0.10 m, floor mount, 4620 triangles, 3 surfaces, 0% flat colour
- **Real object:** A cast-iron stove-pipe thimble set into the room face of the 1912 C-stack chimney breast: a short tubular sleeve through plaster and brick with an annular faceplate, nested reducing rings for different pipe diameters, and a centre closure plate seated because no stove has been connected since the building's earlier use.
- **Confidence:** high

The fitting projects 89 mm as a stack of three fat torus rings and from the side reads as cushions stuck to the wall, and its cast_iron tints (0.62-0.78) render pale bone: the 5C closure samples median sRGB (184,171,154) against the shed wall's (147,143,134), so the iron is lighter than the plaster and from the front the target reads as a plaster medallion. Smith's 1873 drawing shows the opposite: a thin flat flange at the plaster with sleeve and rings disappearing into the wall. The object class is right, a sealed ringed thimble on a chimney breast with soot bloom and cracks where heat met plaster.

**Modelling**

  - Rings: replace the three tori (tube r 0.010/0.010/0.008 at r 0.145/0.108/0.078) with flat annuli, three CylinderMesh discs r 0.155, 0.118 and 0.086, each 0.006 thick and stepped 5 mm apart, so they read as nested reducing rings rather than hoops.
  - Flange: add a flat faceplate disc r 0.160 x 0.004 at z -0.004 against the plaster and sit the throat (r 0.133 x 0.036) inside it at z -0.010 to -0.030 with the rings within the throat's depth; total projection drops from 0.089 to about 0.036 (Smith fig. 3: sleeve into the wall, flange B on the face). The masonry is Blender-owned, so the recess is faked inside the flange, not cut.
  - Fasteners: four IRON heads r 0.006 x 0.004 at r 0.145 on the flange at 45/135/225/315 deg; the notes describe them and the script never built them.
  - Closure: keep the r 0.072 x 0.012 disc and 0.052 x 0.018 finger pull but dome it 4 mm (SphereMesh r 0.072 scaled) so the seated cap carries a highlight edge for the ruled 3 mm knock rock.
  - Cracks: the four 0.063-0.086 m boxes stop at the halo rim and read as radial tick marks on the front bearing; start them at the flange rim (r 0.16) and shorten to 0.05-0.06 so they read as hairlines from the hot iron.

**Texturing**

  - cast_iron per-unit tints (2C 0.78, 3C 0.66, 4C 0.73, 6C 0.62, default 0.70) are far too light for iron; drop them to the 0.28-0.36 band (e.g. 5C (0.32,0.31,0.29), 2C (0.36,0.35,0.33)) so the fitting reads dark grey-black and keeps the ruled per-unit variation.
  - Halo: the 32-segment `soot` disc has a hard edge at 0.41 m (halo (61,57,54) straight to wall (147,143,134)); add an inner 0.34 m disc at tint 0.55 and lift the outer disc's tint to 0.80 so the bloom fades, two soot surfaces still merging to one draw.
  - Tint the outer ring 10% lighter (heat-greyed edge) and the closure 10% darker than the throat so the target reads as three separate castings rather than one moulded piece.

**References used**

  - File:H. Smith Stove-Pipe Thimbles - DPLA - 02f88352ad05b622a7ae573a9c9e0af8 (page 1).jpg - Public domain - https://commons.wikimedia.org/wiki/File:H._Smith_Stove-Pipe_Thimbles_-_DPLA_-_02f88352ad05b622a7ae573a9c9e0af8_(page_1).jpg
  - File:VIEW OF EAST WALL OF MIDDLE ROOM ON NORTH SIDE OF HOUSE (LABELLED DINING ROOM ON FLOOR PLAN); LOOKING EAST. STOVEPIPE HOLE CONNECTS TO CENTRAL CHIMNEY. - Mary Cecil Cantrill No. HABS KY,105-GEOTO,2-8.tif - Public domain - https://commons.wikimedia.org/wiki/File:VIEW_OF_EAST_WALL_OF_MIDDLE_ROOM_ON_NORTH_SIDE_OF_HOUSE_(LABELLED_DINING_ROOM_ON_FLOOR_PLAN);_LOOKING_EAST._STOVEPIPE_HOLE_CONNECTS_TO_CENTRAL_CHIMNEY._-_Mary_Cecil_Cantrill_No._HABS_KY,105-GEOTO,2-8.tif
  - File:View of Dogtrot, detail showing stove-pipe hole in Room 1, north wall - Korus Farmstead, Dogtrot, U.S. Highway 281 at Farm Road 536, Leming, Atascosa County, TX HABS TEX,7-LEM.V,1A-6.tif - Public domain - https://commons.wikimedia.org/wiki/File:View_of_Dogtrot,_detail_showing_stove-pipe_hole_in_Room_1,_north_wall_-_Korus_Farmstead,_Dogtrot,_U.S._Highway_281_at_Farm_Road_536,_Leming,_Atascosa_County,_TX_HABS_TEX,7-LEM.V,1A-6.tif
  - (5 other plates on the sheet not relied on)

### 33. lamp - stamped enamel · landlord supplied

- **Priority** 2.80 (gap 1.28, tier lighter_pass, installed 5, review discount 1.0)
- **What we have:** 0.27 x 0.38 x 0.18 m, floor mount, 1692 triangles, 7 surfaces, 86% flat colour
- **Real object:** Five different second-hand electric task lamps on desks in a 1927-28 Queens walk-up: two cased-glass bankers' lamps of the Emeralite class, a knuckled cast-iron machinist's bench lamp, a cheap stamped-steel landlord-issue desk lamp, and a 1927 Buquet counterweighted architect's lamp.
- **Confidence:** medium

The repaint the header promises ('did not go all the way into the crimp') is not there: base, arm and shade share one uniform pale-khaki `enamel` surface that renders far lighter than the (0.34, 0.37, 0.32) dark-green tint the retexture row asks for, and the one joint carries the bench lamp's machined nickel thumbscrew where a landlord's stamped-steel lamp has a stamped wing nut. The object class is right (a cheap one-joint Sears/Ward-class desk lamp, dia 0.164 base and 0.39 m overall inside the real 0.12-0.15 / 0.30-0.45 envelope); no usable reference was on the sheet (an X-ray tube stand and two churches), so this is judged against the variant text.

**Modelling**

  - Wing nut: replace the dia 0.025 x 0.014 nickel thumbscrew on the knuckle with a stamped wing nut - a dia 0.012 x 0.006 hex boss plus two 0.018 x 0.010 x 0.002 wings in the paint colour; the variant text says no knurled brass anywhere on this lamp.
  - Base: dia 0.164 to dia 0.14 (real 0.12-0.15) and give the top disc a rolled rim (torus r 0.068 tube 0.004) so it reads as pressed sheet rather than a turned block; a 0.003-thick felt disc underneath in `fabric_warm`.
  - Cord: extend the dia 0.0035 cord to the desk and 0.15 m across it (it stops 0.10 m above the desk) and add a 0.012 x 0.008 tape wrap 0.06 m below the socket - VIII.4's poor-flat wiring.
  - Shade rim: replace the flat grey (0.53, 0.53, 0.50) disc dia 0.182 x 0.006 with a rolled rim torus r 0.09 tube 0.003 in the paint colour, set 0.004 off-axis so the rim reads dented.
  - Optional gooseneck (the other Sears form): swap the single 0.34 m strut for six chained 0.06 m struts at 14, 20, 30, 45, 60 and 75 deg using the existing _strut helper; same one-joint silhouette count, more landlord.

**Texturing**

  - Two-tone repaint: split the single paint constant so retexture() sends base and arm to `enamel` tinted (0.34, 0.37, 0.32) (the super's green) and the shade's crimp band, the rim and the underside of the base to `enamel` tinted (0.10, 0.10, 0.09) (the original japanning the brush missed); the header's repaint is currently invisible because one colour goes to one row.
  - Check the tint path: the sheet shows a pale khaki where (0.34, 0.37, 0.32) multiplied into T_library_appliances_aged_enamel_worn_enamel_albedo should read dark green; confirm MatLib.get_mat multiplies the tint for the `enamel` set, or drop the tint to (0.20, 0.22, 0.19).
  - Flaked paint at the crimp: a 0.3-alpha `fx_scuff` ring on the shade rim and the base edge, and a rust tint (0.35, 0.22, 0.12) on the wing nut.
  - Cord: `rubber_aged` (catalog) instead of the shared cloth _CORD colour for this flat only - stiff rubber and tape is 4B's wiring under VIII.4.

**References used**

  - none relied on; the 3 plates on the sheet were off-topic

### 34. boxfan - boxfan / sacha nickel

- **Priority** 2.78 (gap 1.58, tier lighter_pass, installed 4, review discount 1.0)
- **What we have:** 0.59 x 0.66 x 0.44 m, floor mount, 12564 triangles, 9 surfaces, 0% flat colour
- **Real object:** A second-hand 1920–1927 portable desk or floor electric fan of the Westinghouse/Emerson/GE class: heavy japanned cast-iron base and neck, exposed cylindrical motor can, four broad overlapping blades, deep front and rear wire guards, a carrying handle, a stepped speed switch and a cloth-covered line cord ending in a two-pin plug.
- **Confidence:** high

Both plated parts read as paint: the motor and base are the cast_iron albedo tinted putty-beige (0.63/0.62/0.57 at roughness 0.60) and the guard is worn galvanised metal at roughness 1.00 tinted khaki, so the one thing that distinguishes Sacha's dearer fan from the family, plated metal against paint, is absent from the frame. Object class is right; the modelling faults are the shared ones as juno_black.

**Modelling**

  - As juno_black (shared script): handle onto the motor top, two-cylinder round base, wider three-box blades, brass_dull hub badge, trunnions at the motor axis; no variant-specific geometry.
  - The attachment plug (0.055 x 0.033 x 0.070 bakelite_black block with two 0.007 x 0.012 x 0.030 brass_dull prongs) is right for a 1920s two-pin plug, and its exhibit pose at (0.29, 0.030, -0.16) prongs forward lies clear of the base; no change.

**Texturing**

  - Body: choose the key by variant, not only the tint. For sacha_nickel the BODY row becomes [BODY, nickel_plated, (0.80, 0.80, 0.78), 0.55]: worn dull plate on the can and base. nickel_plated is runtime-staged (toaster_prop and the lobby clock already draw it), so no new key.
  - Guard: [GUARD, nickel_plated, (0.96, 0.96, 0.94), 0.35], brighter and smoother than the motor as the variant states; the current metal row at roughness 1.00 / metallic 0.90 cannot read as bright plate under any tint.
  - Blades stay dark phenolic on bakelite_black (0.25, 0.21, 0.17): correct.
  - Wear: worn nickel is roughness, not colour; 0.55 on the motor against 0.35 on the guard says handled plate and untouched wire, which is all a second-hand plated fan needs.

**References used**

  - File:Hardware merchandising March-June 1921 (1921) (14784650333).jpg - No restrictions - https://commons.wikimedia.org/wiki/File:Hardware_merchandising_March-June_1921_(1921)_(14784650333).jpg
  - (3 other plates on the sheet not relied on)

### 35. mirror - medicine cabinet / closed

- **Priority** 2.78 (gap 1.25, tier touched_often, installed 23, review discount 0.6)
- **What we have:** 0.51 x 0.66 x 0.16 m, floor mount, 1644 triangles, 7 surfaces, 29% flat colour
- **Real object:** A cheap white-enamel pressed-steel bathroom medicine cabinet, roughly 18 x 24 in, set into a shallow wall recess with a rolled flange and four screws, whose door is a plain rectangular back-silvered plate-glass mirror hung on two exposed pin hinges with a friction catch and small pull, holding two clipped plate-glass shelves of patent medicines and shaving kit.
- **Confidence:** high

The mirror leaf is the whole read from three metres and it renders as a mottled grey-green slab - matte, no specular, with the nickel channel frame indistinguishable from the cream enamel flange - so the closed cabinet reads as a framed cork board rather than glass. The object class is right: 460 x 610 x 95 mm, two pin barrels, catch, pull, rolled flange and four screws match the ruled 1926 cheap enamel cabinet and the Morgan 1921 bathroom plate.

**Modelling**

  - Pull: the 0.025 x 0.030 x 0.018 nickel box at y -0.13 reads as a lug; the reference's pull is a small knob - cylinder r 0.008 x 0.014 on a r 0.005 x 0.006 stem (2 cylinders, merged into the door batch) at the same far_x.
  - Hinge barrels are r 0.008 x 0.070 cylinders sitting at z -0.001, flush with the door face; a butt-hinge barrel stands proud of the leaf edge. Move them to the hinge edge x +/- 0.004, z -0.012, and split each into two 0.033 knuckles with a 4 mm gap so the two hinges read at 3 m.
  - Flange: the 0.024 x 0.018 'rolled' flange is a square-edged box; a rolled edge reads through a 4 mm quarter-round - add make_cyl r 0.006 along each of the four flange edges (4 cylinders, merged), or keep the box and bevel it 3 mm.
  - Screw heads r 0.007 x 0.006 at the flange corners are fine in size; add a 0.001 x 0.008 x 0.001 slot box in the enamel tint on each so they read as screws rather than rivets.

**Texturing**

  - mirror_aged runs at roughness 0.45 / metallic 0.35 (tint 0.78, 0.79, 0.76, scale 0.60) and renders as matte stone; set roughness 0.12 and metallic 0.85 on the static fallback so flat shed light produces a specular sheen, and raise the albedo scale to 1.5 so the clouding is not one uniform mottle across the plate.
  - Regenerate the mirror_aged albedo (existing key, one-plate batch) with the clouding and black oxidation confined to a 60 mm edge band and a nearly clear centre; an evenly clouded plate is the uniformly grubby failure the wear axis names.
  - nickel_plated at tint (0.88, 0.86, 0.80), roughness 0.82 reads as cream enamel; tint cooler (0.80, 0.82, 0.84) with roughness 0.35 so the channel frame, barrels, catch and pull separate from the enamel flange in the front bearing.
  - enamel (aged appliance enamel albedo) is right for the carcass; add one chipped corner on the flange bottom-left (a 0.012 x 0.012 quad in a dark grey tint) so sixteen years of a rented bathroom read somewhere on the steel.

**References used**

  - File:Building with assurance (1921) (14783717283).jpg - No restrictions - https://commons.wikimedia.org/wiki/File:Building_with_assurance_(1921)_(14783717283).jpg
  - File:Building with assurance (1921) (14760678701).jpg - No restrictions - https://commons.wikimedia.org/wiki/File:Building_with_assurance_(1921)_(14760678701).jpg
  - File:INTERIOR OF BATHROOM NUMBER TWO LOOKING BACK THROUGH OPEN DOOR TO BEDROOM NUMBER THREE. MIRRORED MEDICINE CABINET FLANKED BY 1-LIGHT OVER 1 LIGHT SASH WINDOWS IN GROUPED HAER CAL,26-JULA.V,1E-22.tif - Public domain - https://commons.wikimedia.org/wiki/File:INTERIOR_OF_BATHROOM_NUMBER_TWO_LOOKING_BACK_THROUGH_OPEN_DOOR_TO_BEDROOM_NUMBER_THREE._MIRRORED_MEDICINE_CABINET_FLANKED_BY_1-LIGHT_OVER_1_LIGHT_SASH_WINDOWS_IN_GROUPED_HAER_CAL,26-JULA.V,1E-22.tif
  - (2 other plates on the sheet not relied on)

### 36. toaster - toaster

- **Priority** 2.76 (gap 0.96, tier carries_game, installed 14, review discount 0.6)
- **What we have:** 0.30 x 0.18 x 0.21 m, floor mount, 3948 triangles, 13 surfaces, 23% flat colour
- **Real object:** A Waters-Genter Toastmaster Model 1-A-1 (introduced 1926), the first domestic automatic pop-up toaster: a single-slice, single-slot nickel-plated pressed-metal machine with a spring carriage, paired mica heater cards, a clockwork timer, end-mounted controls, and no crumb tray, bought new or nearly new at about $12.50 as an aspirational appliance in a Queens rented flat.
- **Confidence:** medium

The one reference on the sheet (Country Tea Room) is a house exterior, so the toaster is judged against the ruled Henry Ford 1-A-1 description: the body measures right (0.257 x 0.121 x 0.187) but its plated shell renders as chalky cream stone (nickel_plated at roughness 0.82 under a warm tint), and the pressed rounded top is stood in for by three stepped courses that read as a Deco ziggurat at room distance. Object class is right: single longitudinal 218 x 20 mm slot, end lever and notched timer stop, four feet, side louvers, braided cord and the ruled homemade crumb pan.

**Modelling**

  - Shoulder: the three course pairs (6 boxes at y 0.153/0.162/0.170) step like a ziggurat; the 1-A-1's shoulder is one pressed curve. Replace them with a CylinderMesh r 0.052 h 0.226 laid along X at (0, 0.148, 0), its lower half inside the 0.132-tall walls, and keep the four slot-lip boxes on top; 6 primitives become 1 and the 0.183 m top stays.
  - Ends: with the curved shoulder the end walls (0.006 x 0.132 x 0.109 at x +/-0.1215) need a matching cap: one CylinderMesh r 0.052 h 0.006 at each end (2 primitives), NICKEL.
  - Badge: an unlettered oval nickel plate 0.040 x 0.022 x 0.001 at (0.06, 0.110, -0.061) marks where the maker's badge sits without putting letters in a plate (1 box); low priority.
  - Everything a hand reaches exists: the 0.034 x 0.015 x 0.026 lever on its pin at +X, the timer post with five nickel notches at -X, the carrier plate and five rods in the slot, four 12 mm feet and the plug with two pins; no change.

**Texturing**

  - nickel_plated on the shell at the census roughness 0.82 with tint (0.94, 0.92, 0.86) reads as sandstone; polished nickel is warm grey and reflective on vertical faces (brief section 3: polished for vertical and hand-touched parts, dull only where horizontal). Pass roughness 0.40 for the four wall slabs and the shoulder, 0.75 for the base plate, and a neutral tint (0.90, 0.90, 0.88).
  - bakelite_black on the feet, lever, timer post and vent strips at 0.75 reads right, and the mica_heater cards show orange-brown through the slot: keep.
  - fabric_warm cord tint (0.62, 0.48, 0.40) reads as a red-brown braid; period braided cords were brown or black: (0.45, 0.36, 0.30).
  - Wear: a one-to-two-year-old aspirational machine should read new, so the near-absence of wear is nearly right; the two marks it would carry are heat-tint at the slot lip (tint the four lip boxes (0.86, 0.80, 0.70)) and a finger smudge by the lever (a 0.03 x 0.02 fx_grease strip at (0.118, 0.13, -0.061) at low alpha); the retrofit pan already carries its grease decal and the per-household crumbs.

**References used**

  - none relied on; the 1 plates on the sheet were off-topic

### 37. bookshelf - open oak case / Iris

- **Priority** 2.76 (gap 1.40, tier touched_often, installed 16, review discount 0.6)
- **What we have:** 0.76 x 1.30 x 0.29 m, floor mount, 540 triangles, 4 surfaces, 0% flat colour
- **Real object:** A rented-flat bookcase of 1927-28 Queens: either a dark-mahogany Globe-Wernicke-type glazed sectional (stackable units whose glass doors lift and recede) owned by the two better-off households, an inherited open quartered-oak case of 1900s-1910s manufacture, or a shelf patched together from salvaged boards and packing-case stock by the poorest tenants.
- **Confidence:** medium

No reference on this sheet shows an open oak case (the Globe-Wernicke plates are glazed sectionals and the Honor-Bilt living room is a built-in), so this is judged against the real_object text and the notes; the biggest gap is that the case reads as a flush, walnut-backed crate standing on its side boards, while the ruled unequal feet are buried inside it and the second-hand story (rubbed edges, a shim, golden-oak fleck) is not told. The object class (inherited open quartered-oak case) is right.

**Modelling**

  - The two 0.034 m side boards run the full 1.30 m to the floor, so the ruled unequal feet (0.08 / 0.075 m blocks at x +/-0.27) are hidden and pierce the y 0.045 bottom shelf by 20 mm (foot top 0.080, shelf top 0.060). Start the sides at y 0.08, raise the bottom shelf to y 0.095, and let the two feet carry the case; the 5 mm foot difference then gives the 0.5-degree lean the folded-paper shim is supposed to explain.
  - Add a front base rail 0.72 x 0.06 x 0.02 at y 0.11 between the feet and a top board 0.80 x 0.03 x 0.30 at y 1.285 overhanging the sides by 20 mm, so the silhouette has the plinth-and-top read of a factory case rather than a flush box; 2 boxes, merged.
  - Shelf pitch: tiers of 0.405 / 0.41 / 0.415 m leave 0.14 m of air above a 0.27 m book; 1900s-1910s factory cases ran 0.28-0.32 m tiers. Five shelves at 0.095, 0.40, 0.70, 1.00, 1.275 (one more 0.76 x 0.03 x 0.28 box) matches the shelf density of the built-in case in the Honor-Bilt living-room plate.
  - Books float 15 mm: _book_y = 0.89 while the y 0.86 shelf (0.03 thick) has its top face at 0.875; derive _book_y from the shelf surface.
  - The shim is the story: one paper box 0.06 x 0.005 x 0.05 under the shorter foot, visible from the front.

**Texturing**

  - The 12 mm back is wood_dark (walnut albedo) inside an oak_quartered case and reads as a dark walnut panel in the high_quarter bearing; real backs are thin poplar or pine boards. No softwood key is allowed for this family, so tint oak_quartered pale (0.72, 0.64, 0.50) at scale 0.6 for the back.
  - oak_quartered at tint (0.48, 0.40, 0.30), scale 1.1 renders as a red-brown speckle; golden-oak shellac is amber with pale ray-fleck ribbons - tint (0.62, 0.48, 0.28) and scale 1.6 so the fleck reads on the side boards at 3 m.
  - Cover palette: the pastel pink and mint spines on the linen batch read as modern paperbacks; set HSV value 0.22-0.36 and saturation 0.45-0.60 with hues from navy, maroon, green and brown, still as vertex colour.
  - Wear that says inherited: darken the front 40 mm of each shelf top and the top board's front edge by 15 % (four 0.72 x 0.004 x 0.04 strips in a second oak_quartered tint) and leave the sides clean - the case is currently factory-fresh.

**References used**

  - File:Honor bilt modern homes. (1921) (14763667892).jpg - No restrictions - https://commons.wikimedia.org/wiki/File:Honor_bilt_modern_homes._(1921)_(14763667892).jpg
  - (4 other plates on the sheet not relied on)

### 38. mirror - medicine cabinet / open

- **Priority** 2.73 (gap 1.21, tier touched_often, installed 23, review discount 0.6)
- **What we have:** 0.56 x 0.66 x 0.58 m, floor mount, 1740 triangles, 7 surfaces, 29% flat colour
- **Real object:** A cheap white-enamel pressed-steel bathroom medicine cabinet, roughly 18 x 24 in, set into a shallow wall recess with a rolled flange and four screws, whose door is a plain rectangular back-silvered plate-glass mirror hung on two exposed pin hinges with a friction catch and small pull, holding two clipped plate-glass shelves of patent medicines and shaving kit.
- **Confidence:** high

Open, the cavity reads correctly as a shallow enamel box with a leaf at 95 degrees, but the two plate-glass shelves render as opaque cream ledges and the 1D QUELL TONIC bottles wrap the entire larder label atlas around themselves, reading as red-and-green soup cans; the mirror face carries the same matte-stone read as the closed specimen. The object class is right.

**Modelling**

  - Shelves: each is a 0.405 x 0.008 x 0.070 alpha-0.34 box fronted by a 0.415 x 0.010 x 0.009 enamel lip, and the lip is what renders, so the shelves read as pressed steel. Drop the lip to 0.004 tall, push the glass 6 mm proud of it, and add four r 0.004 x 0.008 nickel clip cylinders per shelf (8 cylinders merged into the carcass) - the clips are the parts the real_object names.
  - Contents sit at z 0.005 +/- 0.010, the middle of a 95 mm cavity, and the 1D set (two 36 mm QUELL, one brown bottle) leaves both shelves reading bare from the front bearing; the inventory is ruled, but push the items to z +0.030 (back third, against the enamel back) and stand the tallest on the lower shelf so the cavity reads used.
  - The door back is one 0.448 x 0.598 x 0.012 enamel slab; a folded steel door back has a 12 mm turned edge - add a 0.012 x 0.598 x 0.010 and a 0.448 x 0.012 x 0.010 rim (4 boxes, merged into the door batch) inside the nickel frame.
  - Same hinge-knuckle, pull-knob and flange-roll changes as the closed specimen.

**Texturing**

  - QUELL TONIC bottles load FridgeProp.LABEL_SHEET with no uv1_scale/uv1_offset, so the whole atlas wraps once around each cylinder; crop to the QUELL cell with uv1_scale/uv1_offset as mail_bank_prop does for its cards, and confine the label to the middle 60 % of the bottle height with the amber alpha material above and below.
  - Amber alpha material (0.34, 0.20, 0.095, roughness 0.38) reads as an opaque brown rod in the high_quarter bearing; set alpha 0.75 and roughness 0.15 so the brown bottle reads as glass.
  - Shelf glass alpha material (0.67, 0.73, 0.72, alpha 0.34, roughness 0.16) needs its green edge: tint the 8 mm front face (0.45, 0.62, 0.55) - plate-glass edges are what say glass.
  - Same mirror_aged (roughness 0.12, metallic 0.85, edge-band clouding), nickel_plated (cooler tint, roughness 0.35) and enamel chip changes as the closed specimen.

**References used**

  - File:Building with assurance (1921) (14783717283).jpg - No restrictions - https://commons.wikimedia.org/wiki/File:Building_with_assurance_(1921)_(14783717283).jpg
  - File:Building with assurance (1921) (14760678701).jpg - No restrictions - https://commons.wikimedia.org/wiki/File:Building_with_assurance_(1921)_(14760678701).jpg
  - File:INTERIOR OF BATHROOM NUMBER TWO LOOKING BACK THROUGH OPEN DOOR TO BEDROOM NUMBER THREE. MIRRORED MEDICINE CABINET FLANKED BY 1-LIGHT OVER 1 LIGHT SASH WINDOWS IN GROUPED HAER CAL,26-JULA.V,1E-22.tif - Public domain - https://commons.wikimedia.org/wiki/File:INTERIOR_OF_BATHROOM_NUMBER_TWO_LOOKING_BACK_THROUGH_OPEN_DOOR_TO_BEDROOM_NUMBER_THREE._MIRRORED_MEDICINE_CABINET_FLANKED_BY_1-LIGHT_OVER_1_LIGHT_SASH_WINDOWS_IN_GROUPED_HAER_CAL,26-JULA.V,1E-22.tif
  - (2 other plates on the sheet not relied on)

### 39. bookshelf - sectional case / Mae

- **Priority** 2.62 (gap 1.28, tier touched_often, installed 16, review discount 0.6)
- **What we have:** 0.86 x 1.34 x 0.34 m, floor mount, 732 triangles, 7 surfaces, 43% flat colour
- **Real object:** A rented-flat bookcase of 1927-28 Queens: either a dark-mahogany Globe-Wernicke-type glazed sectional (stackable units whose glass doors lift and recede) owned by the two better-off households, an inherited open quartered-oak case of 1900s-1910s manufacture, or a shelf patched together from salvaged boards and packing-case stock by the poorest tenants.
- **Confidence:** high

The case reads as one glazed cabinet, not a stack of separate units: the 1908 and 1913 Globe-Wernicke plates show a thick double-board band at every section join, a moulded base and top, and a pull on each lift door, while ours has a single 26 mm shelf between 0.39 m tiers (taller than any Globe-Wernicke book unit) and doors with nothing to grip. The object class (dark mahogany lift-and-recede sectional) is right and the plinth, cap, glass tiers and brass plate are all in the right places.

**Modelling**

  - Read the stack as units: at the two inter-tier joins (y 0.53 and 0.92) replace the single 0.78 x 0.026 x 0.30 shelf with a 50 mm band (one box 0.78 x 0.050 x 0.30, or two 25 mm boards) standing 6 mm proud of the door plane, so the three sections read as three boxes as in the 1908 and 1913 advertisements; +0 meshes after merge.
  - Tier height: tiers are 0.39 / 0.39 / 0.34 m; Globe-Wernicke book units were 8.75-13.25 in (0.22-0.34 m). Either drop to three 0.34 m tiers (shelves at 0.14, 0.48, 0.82, 1.16, cap top at 1.25) or keep 1.34 m and add a fourth 0.30 m tier with its own lift door (one more SurfaceTool door, 8 meshes) - the reference stack is more, shorter sections.
  - Each lift door needs a pull: one brass_dull box 0.060 x 0.012 x 0.010 centred on the bottom rail (y = door_y - 0.145, z = door front + 0.005), plus two 0.006 x 0.30 x 0.004 sash-guide strips inside each side board beside the pane; the doors are currently four rails and a pane with nothing a hand would lift.
  - Books sink 23 mm into the shelf: _book_y = 0.91 while the y 0.92 shelf (0.026 thick) has its top face at 0.933; set _book_y = shelf_y + 0.013 so the spines stand on the board. The same derivation fixes the plain case (15 mm float) and the repaired case (26 mm float).
  - Plinth (0.86 x 0.10 x 0.34) and cap (0.86 x 0.085 x 0.34) are plain slabs; give the base a 12 mm set-back skirt (box 0.82 x 0.04 x 0.30 under a 0.86 x 0.06 x 0.34 top) and the cap a 15 mm overhanging moulding (box 0.90 x 0.025 x 0.36 on top) - the advertisements' base and top units are mouldings, 2 boxes merged.

**Texturing**

  - Door sash rails are flat vertex colour (0.40, 0.28, 0.15) on a vertex-coloured alpha material against a textured wood_dark carcass; in the front bearing they read as lighter tan frames. Sample the rendered carcass mean and set the rail colour to match (about 0.30, 0.20, 0.13), or give the rail quads UVs into the wood_dark albedo while keeping the 20 %-alpha pane in the same mesh (the 7-mesh cap forbids a separate opaque rail mesh).
  - wood_dark (walnut albedo) at tint (0.46, 0.39, 0.30), scale 1.2 renders as bold figured walnut; mahogany-finished birch or gum veneer is a straighter, redder, finer figure - tint toward (0.40, 0.24, 0.17) and raise the scale to 2.0 so the figure tightens; the key stays wood_dark per the ruling.
  - Cover palette: HSV saturation 0.38 and value 0.47-0.50 on the linen batch give pastel pink and lavender spines behind the top glass; 1920s cloth bindings are navy, maroon, bottle green, brown and black - draw hue from that set with value 0.22-0.36 and saturation 0.45-0.60, still as vertex colour on the shared linen batch.
  - Wear on a near-new sectional belongs only where fingers lift: a 0.10 m wide lightened band (vertex tint x1.10) at the centre of each bottom rail and on the brass_dull pull; leave the carcass and the maker's plate clean - the period note says this case could be nearly new.

**References used**

  - File:Globe-Wernicke elastic bookcases ad from The Bookman, May 1908.png - Public domain - https://commons.wikimedia.org/wiki/File:Globe-Wernicke_elastic_bookcases_ad_from_The_Bookman,_May_1908.png
  - File:Globe Wernicke Sectional Bookcases, May 1913.jpg - No restrictions - https://commons.wikimedia.org/wiki/File:Globe_Wernicke_Sectional_Bookcases,_May_1913.jpg
  - File:Globe Wernicke - Individual libraries for new homes, 1911.jpg - No restrictions - https://commons.wikimedia.org/wiki/File:Globe_Wernicke_-_Individual_libraries_for_new_homes,_1911.jpg
  - File:Lincoln centennial number (1909) (14592696547).jpg - No restrictions - https://commons.wikimedia.org/wiki/File:Lincoln_centennial_number_(1909)_(14592696547).jpg
  - (3 other plates on the sheet not relied on)

### 40. case_door - case_door

- **Priority** 2.59 (gap 1.62, tier case_system, installed 1, review discount 1.0)
- **What we have:** 0.98 x 2.12 x 0.13 m, floor mount, 240 triangles, 7 surfaces, 0% flat colour
- **Real object:** A painted two-field (two-panel) stile-and-rail softwood door, about 34 x 80 in (0.86 x 2.03 m) and 1-3/8 in thick, hung on two or three painted-over steel butt hinges in a plain flat pine casing with stop and backband standing proud of the plaster, with a mortise lock and a brass knob on a long backplate with keyhole at about 1.0 m: the same 1928 contractor joinery as the floor's residential interior leaves, serving the F03 west storage room from the corridor between 3B's door and the storage door. It is not the building's galvanized Z-braced service leaf and not a kalamein or tin-clad leaf; the script builds no sheet metal and no brace, and the horror is placement, so the reference is the ordinary painted panel door that passes unnoticed. For the comparison: the generator sets it on the plaster face with no cut opening behind it, so the casing sits proud of the wall rather than in a reveal, and the built panels stand 10 mm proud of the slab (12 mm boxes centred 4 mm out), not 4 mm.
- **Confidence:** medium

The shed imaged an empty floor in all four bearings because case_door_prop.gd hides its leaf until reveal(), so this is judged from the script against the HABS closet doors and knobs: the two fields are 12 mm boxes standing 10 mm proud of a 50 mm slab and coloured like the casing, and the knob is a bare 28 mm brass cylinder with no backplate, keyhole, hinges, stop or saddle. The object class is right, an ordinary painted two-field contractor leaf, and it has to stay ordinary, which is exactly why the missing builders' hardware matters; confidence is medium because nothing was rendered.

**Modelling**

  - Build the leaf as stile-and-rail: two 0.11 x 2.04 x 0.044 stiles, top rail 0.11, lock rail 0.20 at y 0.95, bottom rail 0.22, with two 0.64 x 0.62 x 0.010 panels set 8 mm BACK from the face (7 boxes replacing 1 slab + 2 applied panels); leaf thickness 0.044 (1-3/4 in) rather than 0.05.
  - Knob: keep the r 0.028 knob but stand it on an r 0.012 x 0.06 shank over a 0.045 x 0.19 x 0.004 backplate with a 0.008 x 0.02 keyhole box 0.06 below the knob centre, as both Fort Sheridan HABS knobs show; or call DoorProp._build_knob_set() so it is indistinguishable from the floor's real leaves.
  - Hinges: three painted-over butt knuckles r 0.008 x 0.09 on the jamb side at y 0.25, 1.02 and 1.80 (DoorProp.butt_hinge() exists for this).
  - Stop and saddle: a 0.012 x 2.04 x 0.04 stop strip on each jamb's inner face and a 0.98 x 0.015 x 0.12 wood saddle at the floor.
  - Casing: the 0.06 jambs and 0.07 head read as a picture frame; widen to 0.10 with a 0.02 x 0.02 backband and 0.12 x 0.20 plinth blocks at the floor, the plain 1928 flat casing the real_object describes.

**Texturing**

  - The two panels take `trim` (T_library_architectural_painted_trim) on a `wood_dark` leaf; recessed fields belong to the leaf, so they take `wood_dark` with the slab's tint (0.40,0.31,0.24).
  - Knob `brass` (flagged P1 in AUDIT_TEXTURE_LANDING_REPORT, 0.50 m/tile) to `brass_dull` (0.30 metallic / 0.52 roughness), the internally consistent hand-hardware finish; backplate the same key.
  - Wear that says corridor: two 0.05 x 0.03 chip boxes in the `trim` tint at the lock-stile edge and a 0.30 x 0.08 `fx_scuff` band across the kick zone at y 0.05-0.13.

**References used**

  - File:DOOR KNOB TO FIRST FLOOR CLOSET DOOR - Fort Sheridan, Lieutenants' Quarters, 165 Scott Loop, Lake Forest, Lake County, IL HABS ILL,49-FTSH,1-4-9.tif - Public domain - https://commons.wikimedia.org/wiki/File:DOOR_KNOB_TO_FIRST_FLOOR_CLOSET_DOOR_-_Fort_Sheridan,_Lieutenants%27_Quarters,_165_Scott_Loop,_Lake_Forest,_Lake_County,_IL_HABS_ILL,49-FTSH,1-4-9.tif
  - File:DOOR KNOB TO SECOND FLOOR BEDROOM DOOR - Fort Sheridan, Lieutenants' Quarters, 165 Scott Loop, Lake Forest, Lake County, IL HABS ILL,49-FTSH,1-4-8.tif - Public domain - https://commons.wikimedia.org/wiki/File:DOOR_KNOB_TO_SECOND_FLOOR_BEDROOM_DOOR_-_Fort_Sheridan,_Lieutenants%27_Quarters,_165_Scott_Loop,_Lake_Forest,_Lake_County,_IL_HABS_ILL,49-FTSH,1-4-8.tif
  - File:DETAIL OF FRONT SIDE OF CLOSET DOOR IN ROOM NO. 16 - Paymaster's Quarters, Harpers Ferry, Jefferson County, WV HABS WVA,19-HARF,14-7.tif - Public domain - https://commons.wikimedia.org/wiki/File:DETAIL_OF_FRONT_SIDE_OF_CLOSET_DOOR_IN_ROOM_NO._16_-_Paymaster%27s_Quarters,_Harpers_Ferry,_Jefferson_County,_WV_HABS_WVA,19-HARF,14-7.tif
  - File:DETAIL OF BACK SIDE OF CLOSET DOOR IN ROOM NO 16 - Paymaster's Quarters, Harpers Ferry, Jefferson County, WV HABS WVA,19-HARF,14-8.tif - Public domain - https://commons.wikimedia.org/wiki/File:DETAIL_OF_BACK_SIDE_OF_CLOSET_DOOR_IN_ROOM_NO_16_-_Paymaster%27s_Quarters,_Harpers_Ferry,_Jefferson_County,_WV_HABS_WVA,19-HARF,14-8.tif
  - File:INTERIOR DOOR DETAIL - Harper House, Harpers Ferry, Jefferson County, WV HABS WVA,19-HARF,10-10.tif - Public domain - https://commons.wikimedia.org/wiki/File:INTERIOR_DOOR_DETAIL_-_Harper_House,_Harpers_Ferry,_Jefferson_County,_WV_HABS_WVA,19-HARF,10-10.tif
  - (3 other plates on the sheet not relied on)

### 41. street_lamp - street_lamp

- **Priority** 2.59 (gap 3.16, tier leave_alone, installed 5, review discount 1.0)
- **What we have:** 0.55 x 0.55 x 0.32 m, wall mount, 4562 triangles, 4 surfaces, 25% flat colour
- **Real object:** A 1928 Queens street was lit by cast-iron city standards with incandescent luminaires: the bishop's-crook (NYC Type 24), the Corvington (Type 1BC) or the straight Type 6 mast-arm post, each hanging an opal or Holophane prismatic globe under a spun-metal reflector cap and burning a clear tungsten series lamp; there was no sodium light (first installations 1932 in the Netherlands, mid-1930s in the USA) and no cobra head (1957).
- **Confidence:** high

The one thing most wrong is the object: a 0.20-0.32 m conical shroud over a flat-bottomed 0.26 x 0.16 m amber lens with a sodium tone (1.0, 0.66, 0.28) is a cobra-head luminaire of the late 1950s, and both usable references on the sheet (the West 9th Street and Sixth Avenue bishop's crooks) show what lit a 1928 street - a globe hung below a spun-metal cap with a finial on a cast-iron crook arm, burning a warm-white tungsten series lamp. The object class is wrong by about thirty years and the queries file it as the owner's decision, so this critique measures the gap and gives the replacement's dimensions without ordering it; the head is also squat (0.32 wide x 0.26 tall against a Type 24 globe of roughly 0.32 x 0.50 m with its cap) and hangs on gen_layout's 4.6 m square mast with a 0.42 x 0.42 x 0.25 m box head, a mid-century silhouette that is site geometry, not this prop's. The frames are clear and the references are on-topic; the stained-glass window and the 1939 Packard on the sheet are off-topic and were not used.

**Modelling**

  - Owner decision, dimensioned so it can be taken: the 1928 head is a globe luminaire - a spun cap make_cyl r 0.17 m top / 0.10 m bottom x 0.10 m, a collar make_ring r 0.10 m tube 0.012 m, a hung globe SphereMesh r 0.155 m x 0.42 m tall (teardrop, as a hung globe pulls), a finial make_cyl r 0.02 -> 0.006 m x 0.06 m under it, and the bulb_core inside; five primitives replacing the shroud and lens, overall 0.34 x 0.58 m, which is the proportion a Type 24 acorn carries.
  - If the head stays as built (tier leave_alone: proportion only), fix the proportion alone: lift the shroud to r 0.12 -> 0.17 m x 0.14 m and deepen the lens to 0.26 x 0.30 m so the head is taller than it is wide; a 0.8 h:w luminaire reads as a downlight from three metres in every bearing.
  - Hanger: the head has nothing between it and the mast - add a make_cyl r 0.014 m x 0.12 m stem above the cap so the luminaire hangs from a fitter rather than sitting on the box head.
  - Site geometry, not this script's (flag for gen_layout._street_furniture): the 4.6 m square-section pole with its 0.42 x 0.42 x 0.25 m box head is the mid-century mast; the 1928 standard is a fluted cast-iron post 4.0-4.5 m with a ladder rest and a crook or scroll arm from which the globe hangs. Both references show the crook; nothing in this prop can supply it.
  - Ambient architecture with no E target (PROP_SET_INTERACTION_MATRIX): no interactive parts are missing; the detail gap is the finial, the collar and the fitter only.

**Texturing**

  - Tone: change the street_lamp TONE from sodium (1.0, 0.66, 0.28) to a tungsten series lamp (1.0, 0.84, 0.62) and the lens emission from (0.65, 0.27, 0.055) to (0.95, 0.80, 0.55); this keeps 'warmest thing outside' as the composition cue the exterior pass relies on without the 1932+ sodium colour. Also an owner call, since exterior_detail_pass.gd authors the composition.
  - Globe glass: stained_cracked_prismatic_glass.png with albedo (0.54, 0.38, 0.18) reads as a church window in the high_quarter bearing; an opal or Holophane globe is milk_glass (catalog key, runtime path exists) or a clear ribbed prismatic - use milk_glass at roughness 0.35 with emission, and keep one crack as a 0.25 alpha decal quad rather than a whole cracked-stained texture.
  - Cap: the shroud retextures to the galvanized_metal_worn albedo (metallic 0.9); a spun-steel or copper reflector cap on a city standard was painted - use metal with a dark green (0.16, 0.22, 0.17) or black albedo at roughness 0.6, matching the cast-iron post the references show.
  - Wear is the axis this head does best: weathered flicker on every head, the failing-ballast fault on F01_STREETLAMP_04 and the cracked lens all read as a lamp nobody has serviced; keep the flicker profiles, add a soot ring inside the cap's rim (0.02 m dark band) and let one of the five installed heads carry a chipped-paint cap so the five are not identical.

**References used**

  - File:Ornately-framed window (and air conditioners) and a Bishop's Crook lamppost West 9th Street, Greenwich Village, New York City (23163559466).jpg - CC BY-SA 2.0 - https://commons.wikimedia.org/wiki/File:Ornately-framed_window_(and_air_conditioners)_and_a_Bishop%27s_Crook_lamppost_West_9th_Street,_Greenwich_Village,_New_York_City_(23163559466).jpg
  - File:NYC Manhattan 6th Avenue Bishop crook lamppost.jpg - CC BY 2.0 - https://commons.wikimedia.org/wiki/File:NYC_Manhattan_6th_Avenue_Bishop_crook_lamppost.jpg
  - (2 other plates on the sheet not relied on)

### 42. vantry_point - Vantry point / 1912 listening head

- **Priority** 2.59 (gap 1.55, tier carries_game, installed 0, review discount 1.0)
- **What we have:** 0.31 x 0.07 x 0.23 m, ceiling mount, 3440 triangles, 6 surfaces, 0% flat colour
- **Real object:** A fictional but historically grounded 1912 hard-wired ceiling listening head: a carbon-granule telephone-transmitter capsule behind a brass grille in a moulded phenolic (Bakelite-type) saucer, on the Orison's dedicated house fire/flood/line-test signal circuit, standing in for the modern smoke detector that does not exist in this world.
- **Confidence:** medium

Two of the four bearings (high_quarter, three_quarter) are blank because the shed's raised cameras look into the ceiling for this ceiling-mounted prop and no bearing looks up at the grille, so the ruled true-open radial face is unverifiable here - and the script says it is wrong: the twelve 62 mm spokes are all centred on the axis, forming a 62 mm asterisk with a 38 mm open annulus before the r 78 mm ring rather than twelve slots from hub to rim. The object is a ruled fiction (1912 listening head, no smoke detector) and the two solid-back transmitter photographs inform only the capsule; what the bearings do show reads as speckled stone and a woven rattan ring, not moulded phenolic and dull brass.

**Modelling**

  - Spokes: each 0.010 x 0.007 x 0.062 box is positioned at (0, -0.066, 0) and rotated i x 30 degrees about its own centre, so all twelve span r 0 to 0.031 and rotations 180 degrees apart coincide. Position each at (sin(a) x 0.049, -0.066, cos(a) x 0.049) so it spans r 0.018 (hub) to 0.080 (ring) - twelve distinct spokes and twelve real openings, no new mesh.
  - Capsule: the service pose drops the grille 50 mm to show a capsule with two terminals, but only the two r 0.010 posts exist over the flat r 0.072 bakelite step. Add a r 0.032 x 0.018 copper_aged drum at y -0.062 with a r 0.026 x 0.002 dark bakelite disc as its diaphragm face between the terminals - the solid-back transmitter in the museum photographs is that drum at about 90 mm; 60 mm suits a ceiling capsule.
  - Flex tail: one r 0.006 x 0.110 cylinder laid dead horizontal at y -0.006 from x 0.09 to 0.20 reads as a dowel in the front bearing; a cloth pair drooping from failed plaster is two r 0.004 cylinders 5 mm apart in two segments (0.06 m at -12 degrees, then 0.05 m at -35 degrees) with the r 0.003 copper end bent 42 degrees as now.
  - Failed plaster: nothing shows why a tail is exposed - add a 0.07 x 0.05 x 0.004 chipped patch beside the rim (the existing plaster key if it is in MatLib.SETS, else a bakelite tint of 1.8) with the flex emerging from it.
  - Three r 0.007 service screws sit on the underside of the second step at r 0.092 and, like the spokes, hub, terminals and telltale, are never in frame; the family needs a fifth shed bearing (low quarter, pitch +35 degrees) for ceiling props so the parts a hand reaches are captured at all.

**Texturing**

  - bakelite_black at tint (0.72, 0.65, 0.58), scale 0.42, roughness 0.48 renders as grey-brown speckled stone; moulded phenolic is smooth and semi-gloss - tint (0.45, 0.38, 0.33), roughness 0.22, scale 1.2 so the two steps read as one moulding.
  - brass_mesh is a woven-mesh albedo; on the solid torus, spokes and hub it reads as rattan basketry in the front and side bearings. Key the ring, spokes and hub to brass_dull (existing) at tint (0.62, 0.52, 0.34); brass_mesh belongs on a perforated plate, if one is ever added behind the spokes.
  - linen at tint (0.38, 0.30, 0.23) on the flex reads as tan wood; a braided cotton pair is (0.30, 0.26, 0.20) at roughness 1.0 with uv1_scale 6 on the cylinder so the weave reads as braid at 0.4 m.
  - Sixteen years of ceiling paint: a paint ridge (r 0.118 x 0.004 ring in the ceiling tint) where the roller stopped at the rim, and a 20 % darker tint on the lower step where soot and hands reach - the body is currently uniform.

**References used**

  - File:Microfono a carbone Solid back - Museo scienza tecnologia Milano 08284.jpg - CC BY-SA 4.0 - https://commons.wikimedia.org/wiki/File:Microfono_a_carbone_Solid_back_-_Museo_scienza_tecnologia_Milano_08284.jpg
  - File:Microfono a carbone Solid back - Museo scienza tecnologia Milano 08284 02.jpg - CC BY-SA 4.0 - https://commons.wikimedia.org/wiki/File:Microfono_a_carbone_Solid_back_-_Museo_scienza_tecnologia_Milano_08284_02.jpg
  - (3 other plates on the sheet not relied on)

### 43. arcade_cabinet - arcade_cabinet 0 · 1916

- **Priority** 2.56 (gap 2.85, tier lighter_pass, installed 0, review discount 1.0)
- **What we have:** 0.61 x 0.79 x 0.12 m, floor mount, 506 triangles, 17 surfaces, 94% flat colour
- **Real object:** In this world there is no arcade: each cabinet is a 1912-1924 Vantry-descended coin-operated receiving cabinet, i.e. a second-hand floor-standing radio-receiver console in Bakelite and brass with a circular long-persistence cathode-ray scope where a loudspeaker grille would be, a valve rack behind a hinged service door, wet cells in the base and an enamel-on-steel programme card in a lit frame above the glass; the nearest real 1927-1928 objects are the Atwater Kent / RCA Radiola floor console, the Mills / Caille / Mutoscope penny-arcade upright, and a laboratory oscillograph or 1928 mechanical televisor for the scope itself.
- **Confidence:** low

The one thing most wrong is the marquee: a 0.61 x 0.13 m emissive slab in the card's accent colour (#7a2018 here) carrying two fitted text lines is a backlit video-arcade header, where the ruling asks for an enamel-on-steel programme card behind milk glass in a lit brass frame, and everything the script builds is raw Color with no MATERIAL_CATALOG key. The object class is half right: the square quad with the shader's circular willemite-green aperture and the single brass tuning dial are receiver furniture, but they are hung on the Blender asm_arcade_cab carcass (body 'metal', stick and three buttons, docstring 'late-century cabinets') that ruling VIII.5.g has already condemned. Only the side bearing shows the specimen; front, high_quarter and three_quarter are filled by an untextured beige plane in the shed, and the shed shows the three live parts floating at 1.02, 1.10-1.48 and 1.67-1.81 m with no carcass under them, so silhouette and proportion are read from the script's bands and the Henry Ford Radiola 60, not from a frame.

**Modelling**

  - Programme card, not marquee: replace the 0.61 x 0.13 x 0.012 m emissive accent box at 1.67-1.81 m with a lit frame of three primitives - a brass_dull make_box frame 0.44 x 0.12 x 0.02 m, a milk_glass QuadMesh 0.40 x 0.09 m set 4 mm behind its front plane, and an indicator_enamel card plate 0.38 x 0.075 m behind the glass carrying the title line (0.030 m cap height) and the station / manufacturer / received_from line (0.014 m) - and move the 0.85-energy OmniLight behind the glass so the frame glows through milk glass rather than the whole panel emitting.
  - Circular bezel as geometry: add one make_ring in brass_dull, radius 0.19 m (face_size 0.38 / 2), tube 0.012 m, at the quad's position 30 mm proud of the assembly's bakelite surround, so the round tube face the shader discards to is a brass ring from three metres instead of a green disc inside a black 0.38 m square.
  - Tuning dial: keep the 0.062 m plate, twelve ticks, Bakelite knob and pointer (the one honest control, and correctly the default), but add an engraved scale arc - a second make_ring radius 0.046 m tube 0.002 m in bakelite_black on the plate - and a 0.010 m brass_dull escutcheon ring at the knob's foot; five primitives total for the dial instead of fifteen loose ticks that read as a sunburst in the side bearing.
  - Coin entry is in the assembly (brass box 0.18 x 0.17 m at 0.38-0.55 m) and stays there; the script should add nothing at the deck a hand would not reach on a receiver.
  - Assembly task, not this script's (flag for the Blender pass): asm_arcade_cab variant 0 gives this cabinet a 'metal' body, a bakelite_black control wedge with a stick and three buttons (one terracotta) and side louvres; the ruled carcass for variant 0 is a 0.66 x 0.72 x 1.83 m oak console (oak_quartered) with a bakelite_black bezel band 1.06-1.52 m, a hinged service door 0.40 x 0.55 m on the right flank at 0.45-1.00 m, and no stick or buttons. Remove the three buttons and the stick from the wedge.
  - Warehouse registration: give warehouse_variants() a stand-in carcass for the shed (one wood_dark make_box 0.66 x 0.72 x 1.83 m plus a bakelite_black box 0.60 x 0.42 x 0.02 m at the glass band) so the live parts can be judged against the case they sit in, and re-frame: three of four bearings here show shed furniture, not the prop.

**Texturing**

  - Name catalogue keys instead of raw Color: dial plate and pointer -> brass_dull (horizontal brass, per brief section 3 metallic 0.30), knob and ticks -> bakelite_black, card frame -> brass_dull, card glass -> milk_glass, card plate -> indicator_enamel. All five exist in MATERIAL_CATALOG; none reaches Godot unless also in ingest GODOT_STAGE and MatLib.SETS - check before naming.
  - Marquee light colour: the OmniLight and the card should be the warm 2700 K of a tungsten lamp behind milk glass (Color 1.0, 0.86, 0.66), not the card's accent colour; the accent belongs to the enamel card's lettering only.
  - Tube face: keep scope_screen.gdshader and the 1916 willemite phosphor (0.46, 0.95, 0.34); add a 0.02 m unlit glass rim inside the bezel by raising the shader's discard radius margin, so the phosphor does not run to the metal edge.
  - Wear (sixteen years, four repairers, Accord 9): none of the script's parts carries any - a chipped-white edge on the Bakelite knob, a dulled arc where a thumb rides the dial plate, and dust on the card glass are the three marks; do them as a 0.30 roughness step on the knob and a 0.12 alpha smudge quad 0.04 x 0.02 m on the glass, not a grime texture.

**References used**

  - File:Turning Technology into Furniture - Stove(1886), Radiola60 in Cab.(1927-28), Predicta TV(1958-60), RCA TV(1949), Edison Phonograph(1919), Sewing Machine(1950-55,1860-65) - Fully Furnished - Historic Furniture Exhibit - Henry Ford Museum.jpg - CC BY-SA 2.0 - https://commons.wikimedia.org/wiki/File:Turning_Technology_into_Furniture_-_Stove(1886),_Radiola60_in_Cab.(1927-28),_Predicta_TV(1958-60),_RCA_TV(1949),_Edison_Phonograph(1919),_Sewing_Machine(1950-55,1860-65)_-_Fully_Furnished_-_Historic_Furniture_Exhibit_-_Henry_Ford_Museum.jpg
  - File:Televisore a valvole, bianco e nero, a consolle - Museo scienza tecnologia Milano 02239.jpg - CC BY-SA 4.0 - https://commons.wikimedia.org/wiki/File:Televisore_a_valvole,_bianco_e_nero,_a_consolle_-_Museo_scienza_tecnologia_Milano_02239.jpg
  - File:Televisore a valvole, bianco e nero, midget - Museo scienza tecnologia Milano 02229 dia.jpg - CC BY-SA 4.0 - https://commons.wikimedia.org/wiki/File:Televisore_a_valvole,_bianco_e_nero,_midget_-_Museo_scienza_tecnologia_Milano_02229_dia.jpg

### 44. arcade_cabinet - arcade_cabinet 1 · 1924

- **Priority** 2.54 (gap 3.22, tier lighter_pass, installed 0, review discount 1.0)
- **What we have:** 402.48 x 4.00 x 44.65 m, floor mount, 11854 triangles, 231 surfaces, 50% flat colour
- **Real object:** In this world there is no arcade: each cabinet is a 1912-1924 Vantry-descended coin-operated receiving cabinet, i.e. a second-hand floor-standing radio-receiver console in Bakelite and brass with a circular long-persistence cathode-ray scope where a loudspeaker grille would be, a valve rack behind a hinged service door, wet cells in the base and an enamel-on-steel programme card in a lit frame above the glass; the nearest real 1927-1928 objects are the Atwater Kent / RCA Radiola floor console, the Mills / Caille / Mutoscope penny-arcade upright, and a laboratory oscillograph or 1928 mechanical televisor for the scope itself.
- **Confidence:** low

Nothing of this specimen can be seen: the index reports bounds of 402.48 x 4.00 x 44.65 m, 11854 triangles and 231 surfaces whose keys (graybox_wall, graybox_floor, board_concrete, safety_yellow, galvanised, sealed_screed, strip_light, wire_glass) are the compiled arcade_pit world package that ArcadeMachine booted under the prop node, so the census counted the level and all four bearings are empty grey frames of a 400 m box. The axes below are therefore read from the script, the variant ruling in queries.json and the asm_arcade_cab source, with confidence low: the one thing most wrong is the object class, because variant 1 is the finned late-80s cabinet (fabric_cool body, two terracotta fins 0.55-1.80 m, a milk_glass header 0.10 m wider than the body each side) that the period note calls the most anachronistic geometry in the family, and the script crowns it with a 0.61 x 0.21 m emissive accent marquee at 1.68-1.90 m. Re-render before scoring against these numbers.

**Modelling**

  - Harness first: exclude the Machine node (and its booted world) from the shed's bounds and census, or build the display with the machine unbooted (_process boots at LIVE_RANGE 9.0 m, which the inspection camera is always inside), then re-shoot; until then no bearing exists for this specimen.
  - Programme card, not marquee: the header band is 1.68-1.90 m (0.22 m), so replace the 0.61 x 0.207 x 0.012 m emissive accent box with a brass_dull frame 0.50 x 0.16 x 0.02 m holding a milk_glass QuadMesh 0.46 x 0.13 m over an indicator_enamel card 0.44 x 0.11 m (title 0.035 m cap height, station / manufacturer / received_from line 0.016 m), with the 0.85-energy OmniLight behind the glass.
  - Circular bezel as geometry: one make_ring in brass_dull, radius 0.205 m (face_size 0.41 / 2), tube 0.012 m, 30 mm proud of the assembly's bakelite surround at the 1.14-1.55 m band, so the blue-white 1924 tube reads as a round bezelled face and not a square.
  - Claimed controls for whatever card lands here: keep the deck at 1.06 m but give every layout its material keys (see texturing) and cap the primitive count at eight per layout; the twin-dial layout currently spends 30 primitives on two dials and reads as two sunbursts.
  - Assembly task, not this script's (flag for the Blender pass): asm_arcade_cab variant 1 must lose the two terracotta fins (0.03 x 0.62 x 1.25 m each flank), the stick and the three buttons, and swap the 'fabric_cool' body for oak_quartered with cast-iron or brass scroll trim; the ruled real analogue is the Mills / Caille / Watling oak-and-iron upright with a lit top glass, 0.66 w x 0.72 d x 1.90 h, carcass stopping at 1.68 m under a 0.22 m header no wider than the body plus 0.05 m each side.
  - Warehouse registration: as for variant 0, supply a stand-in carcass (wood_dark make_box 0.66 x 0.72 x 1.68 m plus a milk_glass box 0.76 x 0.22 x 0.16 m header) so the live parts are judged in place.

**Texturing**

  - Name catalogue keys instead of raw Color across _build_claimed_controls: plates, pointer, bell dome, key base and jacks -> brass_dull; knobs, ticks, tape head, patch bay -> bakelite_black; throw-lever knob (0.62, 0.16, 0.13) -> indicator_enamel red; wheel rim -> bakelite_black, hub -> nickel_plated. None of the current 14 Color literals maps to a key.
  - Header: milk_glass over indicator_enamel, lit warm (Color 1.0, 0.86, 0.66) - not the card's accent colour; the accent is the card's lettering only.
  - Tube face: keep scope_screen.gdshader with the 1924 blue-white phosphor (0.44, 0.86, 0.92) and mono 1.0; that part is right.
  - Wear: the carcass is twenty years old and serviced by four people (Accord 9) - a 0.30 roughness step on the Bakelite knobs, a rubbed bright arc on the dial plate, and dust on the card glass; no grime texture.

**References used**

  - File:Turning Technology into Furniture - Stove(1886), Radiola60 in Cab.(1927-28), Predicta TV(1958-60), RCA TV(1949), Edison Phonograph(1919), Sewing Machine(1950-55,1860-65) - Fully Furnished - Historic Furniture Exhibit - Henry Ford Museum.jpg - CC BY-SA 2.0 - https://commons.wikimedia.org/wiki/File:Turning_Technology_into_Furniture_-_Stove(1886),_Radiola60_in_Cab.(1927-28),_Predicta_TV(1958-60),_RCA_TV(1949),_Edison_Phonograph(1919),_Sewing_Machine(1950-55,1860-65)_-_Fully_Furnished_-_Historic_Furniture_Exhibit_-_Henry_Ford_Museum.jpg
  - File:Televisore a valvole, bianco e nero, a consolle - Museo scienza tecnologia Milano 02239.jpg - CC BY-SA 4.0 - https://commons.wikimedia.org/wiki/File:Televisore_a_valvole,_bianco_e_nero,_a_consolle_-_Museo_scienza_tecnologia_Milano_02239.jpg
  - File:Televisore a valvole, bianco e nero, midget - Museo scienza tecnologia Milano 02229 dia.jpg - CC BY-SA 4.0 - https://commons.wikimedia.org/wiki/File:Televisore_a_valvole,_bianco_e_nero,_midget_-_Museo_scienza_tecnologia_Milano_02229_dia.jpg

### 45. arcade_cabinet - arcade_cabinet 2 · 1922

- **Priority** 2.54 (gap 3.21, tier lighter_pass, installed 0, review discount 1.0)
- **What we have:** 406.48 x 4.00 x 44.68 m, floor mount, 13166 triangles, 257 surfaces, 45% flat colour
- **Real object:** In this world there is no arcade: each cabinet is a 1912-1924 Vantry-descended coin-operated receiving cabinet, i.e. a second-hand floor-standing radio-receiver console in Bakelite and brass with a circular long-persistence cathode-ray scope where a loudspeaker grille would be, a valve rack behind a hinged service door, wet cells in the base and an enamel-on-steel programme card in a lit frame above the glass; the nearest real 1927-1928 objects are the Atwater Kent / RCA Radiola floor console, the Mills / Caille / Mutoscope penny-arcade upright, and a laboratory oscillograph or 1928 mechanical televisor for the scope itself.
- **Confidence:** low

As with variant 1, nothing of this specimen is visible: bounds 406.48 x 4.00 x 44.68 m, 13166 triangles and 257 surfaces keyed fossil_bone, decaying_velvet, tarnished_brass, vault_plaster, worn_flagstone and candleflame are the booted arcade_pit world package (a different skin) parented under the prop, and all four bearings are empty grey. The axes are read from the script, the variant ruling and asm_arcade_cab, confidence low. The one thing most wrong is material: the assembly gives this 'chrome amusement' a chrome body, and chrome plating was barely commercial in 1927 and sits outside the VIII.4 family; the ruled real analogue is the coin-operated automatic phonograph cabinet (Mills Violano-Virtuoso, Gabel Automatic Entertainer, and the oak Concert Automatique on this sheet) in oak with nickel or dull brass trim and a glass window over the mechanism. The script's contribution - square scope quad at 1.02-1.38 m, emissive accent marquee at 1.56-1.70 m, claimed controls at 0.97 m - repeats the family's marquee and material faults.

**Modelling**

  - Harness first: exclude the Machine node and its booted world from the shed's bounds and census (or build the display unbooted) and re-shoot; there is no bearing to score until then.
  - Programme card, not marquee: the band is 1.56-1.70 m (0.14 m), so replace the 0.61 x 0.132 x 0.012 m emissive accent box with a brass_dull frame 0.46 x 0.12 x 0.02 m, a milk_glass QuadMesh 0.42 x 0.09 m and an indicator_enamel card 0.40 x 0.075 m (title 0.028 m cap height, second line 0.013 m), OmniLight behind the glass.
  - Circular bezel as geometry: one make_ring in nickel_plated (this is the nickel-trimmed variant), radius 0.18 m (face_size 0.36 / 2), tube 0.012 m, 30 mm proud of the bakelite surround.
  - Mechanism window: the phonograph class shows its works; add a glassish QuadMesh 0.44 x 0.16 m at 0.62-0.78 m on the front with a nickel_plated make_box frame 0.48 x 0.20 x 0.015 m, and behind it two bakelite_black cylinders r 0.05 x 0.10 m (a drive drum and a roll) so the window is not black - five primitives, and the only thing that makes this variant read as a music machine rather than a shorter copy of variant 0.
  - Assembly task, not this script's (flag for the Blender pass): asm_arcade_cab variant 2 body 'chrome' -> oak_quartered carcass 0.66 x 0.72 x 1.72 m with nickel_plated trim strips 0.02 m wide on the four front edges; remove the stick and three buttons; keep the brass coin door at 0.38-0.55 m and the feet.
  - Warehouse registration: stand-in carcass (wood_dark make_box 0.66 x 0.72 x 1.72 m plus milk_glass box 0.62 x 0.14 x 0.08 m at 1.56-1.70 m) so the live parts are judged in place.

**Texturing**

  - Name catalogue keys instead of raw Color across _build_claimed_controls: brass parts -> brass_dull, knobs and plates -> bakelite_black, wheel hub -> nickel_plated, lever knob -> indicator_enamel; the script currently names no key at all (14 Color literals).
  - Trim on this variant is nickel, not chrome: nickel_plated is ruled warm silver (0.70 metallic, 0.38 roughness) and already exists with a full runtime path from the tap_prop pass; use it for the bezel ring, window frame and coin-door rim.
  - Tube face: keep scope_screen.gdshader with the 1922 willemite green (0.34, 0.98, 0.56), mono 1.0.
  - Wear: rubbed nickel at the window frame's lower rail where hands rest (roughness 0.25 band 0.03 m tall), a 0.30 roughness step on the Bakelite knobs, dust on the card glass; no grime texture.

**References used**

  - File:Le Concert Automatique Francais, undated - Kanazawa Phonograph Museum - Kanazawa, Japan - DSC00985.jpg - CC0 - https://commons.wikimedia.org/wiki/File:Le_Concert_Automatique_Francais,_undated_-_Kanazawa_Phonograph_Museum_-_Kanazawa,_Japan_-_DSC00985.jpg
  - File:Turning Technology into Furniture - Stove(1886), Radiola60 in Cab.(1927-28), Predicta TV(1958-60), RCA TV(1949), Edison Phonograph(1919), Sewing Machine(1950-55,1860-65) - Fully Furnished - Historic Furniture Exhibit - Henry Ford Museum.jpg - CC BY-SA 2.0 - https://commons.wikimedia.org/wiki/File:Turning_Technology_into_Furniture_-_Stove(1886),_Radiola60_in_Cab.(1927-28),_Predicta_TV(1958-60),_RCA_TV(1949),_Edison_Phonograph(1919),_Sewing_Machine(1950-55,1860-65)_-_Fully_Furnished_-_Historic_Furniture_Exhibit_-_Henry_Ford_Museum.jpg
  - File:Televisore a valvole, bianco e nero, a consolle - Museo scienza tecnologia Milano 02239.jpg - CC BY-SA 4.0 - https://commons.wikimedia.org/wiki/File:Televisore_a_valvole,_bianco_e_nero,_a_consolle_-_Museo_scienza_tecnologia_Milano_02239.jpg
  - File:Televisore a valvole, bianco e nero, midget - Museo scienza tecnologia Milano 02229 dia.jpg - CC BY-SA 4.0 - https://commons.wikimedia.org/wiki/File:Televisore_a_valvole,_bianco_e_nero,_midget_-_Museo_scienza_tecnologia_Milano_02229_dia.jpg

### 46. bodega_signage - bodega_signage

- **Priority** 2.46 (gap 3.97, tier leave_alone, installed 1, review discount 1.0)
- **What we have:** 4.40 x 1.76 x 1.07 m, wall mount, 84 triangles, 7 surfaces, 100% flat colour
- **Real object:** The street signage of a 1927-1928 corner grocery-delicatessen across from a Queens walk-up: a hand-painted wooden fascia signboard, a canvas roll-up awning with the name painted on its scalloped valance, a sheet-metal or porcelain-enamel projecting sign on an iron bracket (at most an incandescent-bulb electric sign with opal-glass letters), gold-leaf window and transom lettering, and supplier enamel signs nailed round the door; never a backlit vinyl valance, an acrylic lightbox or a fluorescent tube.
- **Confidence:** medium

Every component is the wrong decade: a backlit emissive vinyl valance 4.35 x 0.55 x 0.05 m (a 1970s-80s convention), an acrylic lightbox cabinet 0.15 x 1.50 x 0.60 m (acrylic sheet is 1933-36) and a fluorescent dropout faked in _process (the tube is 1938), where a 1928 corner grocer had a painted wooden fascia, a canvas awning with a painted scalloped valance, and an enamel or bulb-lit blade on an iron bracket lit from outside by gooseneck reflectors. The object class is wrong; only the front bearing rendered (high_quarter, side and three_quarter are blank at 4.4 m) and none of the sheet's three references is period or on-topic (a 2021 Buffalo lodge with a printed sign, a COVID paper notice, a Venezuelan shop gate), so this is judged from that one frame, the script and the kind text.

**Modelling**

  - Fascia: a 4.40 x 0.45 x 0.04 m `sign_board` box on the pier line above the transom (y +0.30 from the marker, z 0) carrying the two Label3D lines in sign-writer's serif capitals (keep HALF BAKED at 92 px; the sub-line becomes DELICATESSEN - GROCERIES - OPEN ALL NIGHT, the period phrasing); delete the emissive VINYL_YELLOW valance box and its two 0.05 x 0.55 x 1.02 side returns.
  - Awning valance as canvas: a 4.35 x 0.28 x 0.012 m strip hung from the awning slab's front edge (real valances are 0.20-0.35 m, not 0.55) with a scalloped bottom made of 14 half-discs r 0.15 along its lower edge, no emission; the shop name painted on it as a Label3D at 46 px; pipe frame of two dia 0.02 x 1.0 m galvanized arms from the pier to the front bar and a dia 0.06 roller tube along the fascia.
  - Blade sign: replace the 0.15 x 1.50 x 0.60 cabinet and its two 0.02 x 1.38 x 0.50 acrylic faces with one 0.03 x 0.90 x 0.60 m double-faced enamel panel at x -2.05 hung from a wrought-iron bracket - a 0.03 x 0.03 x 0.75 horizontal bar at y +0.88, a 0.02 x 0.02 x 0.55 diagonal brace back to the pier at 45 deg, two dia 0.006 hang rods; keep the existing four-line Label3D on each face.
  - Light from outside, the bar's own convention: three gooseneck reflector lamps at x -1.4, 0 and +1.4 on the fascia top plus one over the blade, each a dia 0.008 x 0.45 conduit arm and a dia 0.20 x 0.10 enamel cone with a dia 0.04 bulb_ sphere; replace the two unshadowed OmniLight3Ds with warm spots from those cones; delete the fluorescent dropout gate in _process() or re-author it as one dead bulb.
  - Supplier signs: two 0.40 x 0.60 x 0.01 m `indicator_enamel` panels flanking the door at y +0.9 as colour fields with a border only, no text in the plate.
  - Warehouse: add warehouse_variants() so the shed frames the 4.4 m fascia - three of four bearings are blank at this size and the scorer cannot see the object.

**Texturing**

  - Fascia: `sign_board` (catalog, roughness 0.72) tinted dark green (0.12, 0.22, 0.16) or oxblood, Label3D letters in cream and gold; no emissive material anywhere on the sign.
  - Canvas valance and awning skin: new key `canvas_duck` (the catalog's `awning_vinyl` is the wrong substance); until it exists use `linen` tinted (0.62, 0.58, 0.48) with a 0.4-alpha `fx_damp` water-stain band along the bottom 0.08 m.
  - Blade panel: `indicator_enamel` (catalog) tinted (0.94, 0.92, 0.86) with a 0.02 m black border and `fx_scuff` chips at the corners; bracket in `cast_iron` tinted black (0.08, 0.08, 0.09) with a rust streak below it via `fx_drip` tinted (0.35, 0.20, 0.10).
  - Gooseneck cones: `enamel` tinted dark green outside, `milk_glass` inside; conduit in `metal`.
  - Wear: sun-fade the valance's upper half 0.15 lighter than its lower, leave one reflector lamp dead (its bulb_ material unlit), and flake the fascia's lower edge with `fx_scuff` - Accord 9's ordinary decay, and the bodega stays less lit than the bar.

**References used**

  - none relied on; the 3 plates on the sheet were off-topic

### 47. signal_terminal - signal_terminal

- **Priority** 2.38 (gap 1.40, tier case_system, installed 1, review discount 1.0)
- **What we have:** 0.45 x 0.54 x 1.11 m, floor mount, 4784 triangles, 10 surfaces, 50% flat colour
- **Real object:** A fictional Vantry house receiver/transmitter (the player's operator instrument) built into a second-hand 1920s oak table-radio cabinet: a round cathode scope, two moving-coil meters, a three-valve bank behind nickel guards, a six-jack patch field, an amber line-annunciator lamp and a carbon handset on a cradle, whose nearest real analogues are a 1920s oak TRF radio receiver with black panel and dials, a small telephone/PBX switchboard jack field with lamps and operator handset, and a round-screen cathode-ray oscilloscope with Weston-type panel meters.
- **Confidence:** high

The front face is the most wrong thing: the 'brass edge strip' is built as a 0.018 x 0.225 x 0.94 m brass_dull box covering nearly the whole 1.02 x 0.27 m face, tinted 0.72/0.66/0.52, so the panel the meters, knobs and jacks sit on reads as mottled tortoiseshell where the Atwater Kent sets and the Western Electric boards on this sheet show a black panel with brass and nickel escutcheons, and the carcass wears the wood_dark walnut plate although the ruled cabinet is second-hand oak. Object class is right and stays as ruled, a machine of the fiction and not a computer: scope, two meters, three valves behind nickel rails, six jacks, amber annunciator and cradle are all there at plausible sizes; the gaps are that the 'three occupied' jack field has no plugs or cords, the scope is a flat emissive disc with no glass or graticule, the handset is a bar with two cups, and nothing on it looks twenty years old and repaired.

**Modelling**

  - Front panel: replace the 0.018 x 0.225 x 0.94 brass box with a bakelite_black panel of the same size and four brass_dull edge strips (two of 0.018 x 0.012 x 0.94, two of 0.018 x 0.225 x 0.012) around it: 5 boxes for 1, and the finish count stays at five.
  - Patch field: add three plugs make_cyl(0.011, 0.011, 0.040) at x +0.245 in jacks 1, 3 and 4, each with a three-chord cord loop (tube_between, r 0.003) dropping to a cord rail make_box(0.02, 0.02, 0.35) under the strip: 13 primitives. This is the physical route diagram the ruling says the player learns from the face, and today all six sockets are empty.
  - Scope: a glass cap (SphereMesh r 0.10 scaled to 0.02 in x, alpha 0.3) over the Ø 196 mm disc and a graticule of two 1 mm boxes 0.19 long in low emission (0.10, 0.30, 0.20): 3 primitives, so it reads as a tube face rather than a green button.
  - Handset: replace the 0.08 x 0.055 x 0.29 box with a handle make_cyl(0.015, 0.015, 0.22) between a Ø 55 x 30 mm transmitter cup and a Ø 50 x 25 mm receiver cap (the E1 pattern named in the period note): 3 primitives for 1; the two cradle cups stay.
  - Valves: a Bakelite base make_cyl(0.020, 0.020, 0.018) under each of the three envelopes (3 primitives), as on the breadboard receivers, where the glass sits in a base and not on bare oak.
  - Meters: a half make_ring(0.045, 0.002) tinted (0.85, 0.82, 0.72) behind each needle as the dial arc (2 primitives, no letters or numbers).

**Texturing**

  - Cabinet: wood_dark (T_library_furniture_walnut) to oak_quartered (in the catalog, GODOT_STAGE and MatLib.SETS), tinted (0.62, 0.50, 0.34) at 0.65: one key change, and the ruled 'second-hand oak radio cabinet' is what renders.
  - Front panel: bakelite_black tinted (0.40, 0.34, 0.28), warm brown-black; the four edge strips keep brass_dull at (0.78, 0.68, 0.44) so the brass reads as brass on a narrow strip instead of veneer on a plate.
  - Valves: the envelopes are one solid amber alpha-0.72 material emitting (0.82, 0.25, 0.06) at 0.22 (0.64 on a surge), so they read as three neon tubes; a valve heater glows as a small orange point. Drop the envelope emission to 0.06 and put a 3 mm emissive filament box inside each: 3 primitives, one material change.
  - Wear as ruled (VIII.6, old and repaired): worn varnish on the cabinet's top front edge as a lighter tint band on oak_quartered (0.72, 0.62, 0.46), one meter bezel with a white-chipped corner (2 mm box tinted (0.80, 0.78, 0.72)), one replaced jack in nickel_plated among the five copper_aged ones, and a cloth cord on the handset (make_cyl 0.0025 r, fabric_warm): 4 items.

**References used**

  - File:Vintage Atwater Kent Model 40 Radio Receiver and Model L Horn Speaker, Circa 1920s (32974715560).jpg - CC BY-SA 2.0 - https://commons.wikimedia.org/wiki/File:Vintage_Atwater_Kent_Model_40_Radio_Receiver_and_Model_L_Horn_Speaker,_Circa_1920s_(32974715560).jpg
  - File:Vintage Atwater Kent Breadboard Receivers, Model 10B (Top), Model 10C (Bottom), Circa 1924 (31715077946).jpg - CC BY 2.0 - https://commons.wikimedia.org/wiki/File:Vintage_Atwater_Kent_Breadboard_Receivers,_Model_10B_(Top),_Model_10C_(Bottom),_Circa_1924_(31715077946).jpg
  - File:First Neutrodyne radio receiver closeup.jpg - Public domain - https://commons.wikimedia.org/wiki/File:First_Neutrodyne_radio_receiver_closeup.jpg
  - File:Western Electric 555 PBX switchboard - Telephone Museum - Waltham, Massachusetts -DSC08231.jpg - CC0 - https://commons.wikimedia.org/wiki/File:Western_Electric_555_PBX_switchboard_-_Telephone_Museum_-_Waltham,_Massachusetts_-DSC08231.jpg
  - (4 other plates on the sheet not relied on)

### 48. arcade_cabinet - arcade_cabinet 3 · 1922

- **Priority** 2.37 (gap 2.53, tier lighter_pass, installed 0, review discount 1.0)
- **What we have:** 0.29 x 0.32 x 0.12 m, floor mount, 686 triangles, 19 surfaces, 95% flat colour
- **Real object:** In this world there is no arcade: each cabinet is a 1912-1924 Vantry-descended coin-operated receiving cabinet, i.e. a second-hand floor-standing radio-receiver console in Bakelite and brass with a circular long-persistence cathode-ray scope where a loudspeaker grille would be, a valve rack behind a hinged service door, wet cells in the base and an enamel-on-steel programme card in a lit frame above the glass; the nearest real 1927-1928 objects are the Atwater Kent / RCA Radiola floor console, the Mills / Caille / Mutoscope penny-arcade upright, and a laboratory oscillograph or 1928 mechanical televisor for the scope itself.
- **Confidence:** low

The one thing most wrong is that the rake exists only in a comment: the assembly's 'steeply raked screen' is a vertical box and the script's 0.28 m quad at 0.84-1.12 m is vertical too, so the compact unit - whose ruled analogues are the counter-top Mutoscope / Exhibit Supply viewer and the 1928 televisor or oscillograph with a raked hood over a small round tube - reads as a short copy of the upright. The object class is otherwise the closest in the family: no marquee, the title screened on the bezel at 1.165 m in the accent colour, a 0.058 m tuning dial and a telegraph key on a brass base at the 0.80 m deck are all receiver furniture. Only the side bearing shows the specimen (front, high_quarter and three_quarter are filled by an untextured beige plane), and it shows the quad, label, dial and key floating with no carcass; the 686 triangles are 95 percent flat colour with no catalogue key.

**Modelling**

  - Raked viewing hood as geometry: add four bakelite_black make_box walls forming a hood 0.32 m wide, 0.30 m tall and 0.12 m deep in front of the glass band, with the top wall 0.06 m shorter than the bottom so the opening plane leans back 20 degrees, and set the quad's rotation.x to the same 20 degrees inside it; the assembly's vertical dark-glass box stays behind as the tube's housing. Five primitives, and the only change that makes variant 3 read as the raked box its own comment describes.
  - Round bezel: one make_ring in brass_dull, radius 0.14 m (face_size 0.28 / 2), tube 0.010 m, inside the hood opening, so the small round tube is a bezelled circle rather than a green disc in a square.
  - Bezel title: keep the screened label at sz1 + 0.045 (1.165 m) but give it a plate - an indicator_enamel make_box 0.30 x 0.04 x 0.003 m behind the Label3D - so the title is a fixed enamel strip on the bezel and not text floating 6 mm off the glass band.
  - Deck: the dial (plate r 0.058, 12 ticks, knob, pointer) and the key (base 0.055 x 0.010 x 0.085 m, lever, knob) are the right parts at 0.80 m; reduce the dial's ticks to an engraved arc (make_ring r 0.043, tube 0.002, bakelite_black) and add a 0.010 m brass_dull escutcheon at the knob foot - the side bearing shows the ticks as a sunburst.
  - Assembly task, not this script's (flag for the Blender pass): asm_arcade_cab variant 3 keeps the 'enamel' body only if it is dented tin enamel, removes the stick and three buttons from the 0.72-0.80 m wedge, and adds the raked hood profile to the carcass so the hull matches the prop's hood.
  - Warehouse registration: supply a stand-in carcass (make_box 0.60 x 0.60 x 1.45 m in enamel plus a bakelite_black box 0.54 x 0.36 x 0.02 m at 0.80-1.16 m) and re-frame; three of four bearings show shed furniture, not the prop.

**Texturing**

  - Name catalogue keys instead of raw Color: dial plate, pointer and key base -> brass_dull; knob, ticks, lever and key knob -> bakelite_black; hood -> bakelite_black; bezel ring -> brass_dull; title plate -> indicator_enamel. The census shows six flat colours and the shader, no key.
  - Tube face: keep scope_screen.gdshader with the 1922 willemite green (0.34, 0.98, 0.56), mono 1.0; the side bearing's green sliver is the right colour.
  - Enamel carcass (assembly): the 'enamel' key must read as chipped tin enamel over steel, not gloss appliance enamel - a roughness of 0.55 and a 0.10 chip mask at the deck edge; if the assembly cannot, prefer bakelite_black for the whole case per materials_expected.
  - Wear: a rubbed bright patch 0.05 x 0.03 m on the key base where the wrist rests, a 0.30 roughness step on the dial knob, and dust on the hood's lower sill; no grime texture.

**References used**

  - File:Televisore a valvole, bianco e nero, midget - Museo scienza tecnologia Milano 02229 dia.jpg - CC BY-SA 4.0 - https://commons.wikimedia.org/wiki/File:Televisore_a_valvole,_bianco_e_nero,_midget_-_Museo_scienza_tecnologia_Milano_02229_dia.jpg
  - File:Televisore a valvole, bianco e nero, a consolle - Museo scienza tecnologia Milano 02239.jpg - CC BY-SA 4.0 - https://commons.wikimedia.org/wiki/File:Televisore_a_valvole,_bianco_e_nero,_a_consolle_-_Museo_scienza_tecnologia_Milano_02239.jpg
  - (1 other plate on the sheet not relied on)

### 49. sconce_globe - sconce_globe

- **Priority** 2.36 (gap 1.67, tier leave_alone, installed 28, review discount 1.0)
- **What we have:** 0.55 x 0.55 x 0.22 m, wall mount, 4406 triangles, 4 surfaces, 25% flat colour
- **Real object:** Beside the 1926 white-enamel mirror cabinet a rented-flat bathroom had a nickel-plated brass or glazed white porcelain wall bracket: a small round or oval backplate, a short arm or straight socket, a brass pull chain, and either a bare lamp or a small opal glass globe or bath shade on a 3¼- or 4-inch fitter.
- **Confidence:** medium

No reference was available (no permissively licensed image was found for any query), so this is judged against the ruled description of a 1920s rented-bath bracket: a lacquered-brass 90 x 160 mm rectangular backplate and a bare 170 mm ball, with no pull chain, no fitter collar and no socket, where the real fitting is nickel or white porcelain with a small round plate, a neck holding the globe and a chain a hand reaches for. Object class is close (a wall bracket with an opal globe) but the brass finish and the tall plate read as a hallway sconce rather than a bath bracket; the tier is leave_alone, so the proportion bullets come first and the rest are recorded for the scorer.

**Modelling**

  - Globe: SphereMesh r 0.085 (170 mm) is the large end for a bath bracket; a 4-inch-fitter bath globe is 130-150 mm. r 0.070 at (0, 0.085, 0.105) also trims the projection from 0.20 to 0.175 m beside the 460 mm cabinet.
  - Backplate: the 0.09 x 0.16 x 0.025 box is a tall rectangle; the real plate is a small round or oval canopy. One CylinderMesh r 0.055 h 0.020 rotated X 90 at z -0.010 replaces it; same count.
  - Triangles: bulb_globe at default segmentation is 4,224 of the prop's 4,406 triangles, times 28 installs; radial_segments 24 and rings 12 (600 triangles) is enough for a 140 mm globe that glows.
  - Beyond the leave-alone tier: a fitter collar (CylinderMesh r 0.052 to 0.046 h 0.025 in the plate material) between the arm and the globe so the glass is held by its neck instead of floating on the arm tip, and a pull chain of six make_ring links r 0.004 (or one 0.003 x 0.12 cylinder) from the collar down to y -0.06; 2-7 primitives.
  - Arm: the 0.10 m tapered cylinder at 55 degrees is right for a short bracket arm; keep.

**Texturing**

  - The sconce parts take the brass row (aged brass albedo, metallic 0.85) and render as lacquered brass; the bathroom finish of the 1920s is nickel or white porcelain. Add a retexture row for this prop_type only, [Color(0.70, 0.70, 0.68), nickel_plated, Color.WHITE, 0.45] (runtime-staged), or [Color(0.90, 0.90, 0.86), porcelain_fixture, Color.WHITE, 0.30] for the landlord's cheap porcelain bracket, and paint the plate, arm and collar with that colour in _build_body.
  - Globe: bulb_globe is an unmaterialed sphere carrying only the emissive tone (1.0/0.88/0.72), so it renders as a flat white ping-pong ball; give it milk_glass (runtime-staged) under the emission, or enable rim on _bulb_mat, so the opal reads as glass that is thick at the edge and bright at the centre.
  - Wear: a sixteen-year fitting in a rented bath shows tarnish at the chain and a dust ring on the globe's top; with nickel, roughness 0.55 on the plate and 0.45 on the arm is the whole story. Factory-bright brass at metallic 0.85 is the current read.

**References used**

  - no reference was relied on; the critique is from the script and the notes

### 50. ceiling_light - ceiling_light

- **Priority** 2.23 (gap 3.45, tier leave_alone, installed 1, review discount 1.0)
- **What we have:** 0.30 x 0.10 x 0.30 m, ceiling mount, 12 triangles, 1 surfaces, 100% flat colour
- **Real object:** The landlord-supplied living-room ceiling fixture of a 1912-wired Queens walk-up as it stood in 1927-1928: a shallow opal (milk) glass bowl, roughly 25-36 cm across and 8-12 cm deep, held flush or semi-flush to the plaster by a spun-brass canopy and fitter ring with three thumb screws or three short brass chains, around one or two medium-base Mazda tungsten bulbs in a porcelain pull-chain socket, with the cheapest flats making do with a brass 'pan' fixture or a bare porcelain lampholder instead.
- **Confidence:** high

The 4B main-room fixture is a single cream 0.30 x 0.10 x 0.30 m box with no canopy, ring, glass, socket or chain; against the shallow opal bowl on a brass fitter the real object describes, and the opal pendants in the two usable plates, it reads as a modern flush box, and when the OmniLight is budgeted away it is a bare box on the ceiling. The class is wrong as built, though the footprint (0.30 across, 0.10 deep) is exactly the bowl's.

**Modelling**

  - Replace the box with the bowl: one flattened SphereMesh r 0.155, height 0.20, centred at y -0.05 with cast_shadow off and named bulb_bowl so it takes an emissive opal material; the visible lower half gives a 0.31 m bowl 0.10 m deep, inside the real 25-36 x 8-12 cm (1 primitive, same footprint).
  - Brass fitter ring at the rim: make_ring r 0.150, tube 0.008 at y -0.055, left flat, plus three thumb screws make_cyl r 0.004 x 0.012 at 120 degrees on the ring's outer edge (4 primitives).
  - Canopy against the plaster: make_cyl r 0.065 -> 0.055 x 0.020 at y -0.010 (1 primitive), so the fixture meets the ceiling the way a flush bowl does instead of as a box edge.
  - Bead chain: make_cyl r 0.002 x 0.14 at (0.10, -0.17, 0) with a r 0.006 x 0.012 fob at its end, so the pull-chain socket the canonical quirk gives the fixture shows below the rim (2 primitives).
  - Bulb ghost: a make_cyl r 0.025 -> 0.030 x 0.06 inside the bowl at y -0.06 named bulb, emissive, so the tungsten silhouette shows through the opal as the distinguishing features ask (1 primitive).

**Texturing**

  - Bowl: give it the emissive opal treatment light_fixture_prop uses for bulb_* nodes (albedo (1.0, 0.97, 0.9), emission = the fixture tone, energy multiplier 1.0-1.6 driven by _target_scale) instead of the flat vertex colour (0.95, 0.93, 0.85); 'milk_glass' is staged in MatLib.SETS for the unlit albedo.
  - Brass parts: retexture canopy, ring and screws to 'brass_dull' (metallic 0.30), the poor flat's lacquered fitting; 'brass' at 0.85 only if the owner wants the 1912 original to gleam, and 'trim' paint on the canopy is also period, since these were often painted over with the ceiling.
  - The script declares no material key at all (flat_colour_share 1.0); every surface above must go through retexture or a keyed material so the census stops reading this fixture as 100 percent flat.

**References used**

  - File:The lighting of printing plants - information compiled by A.D. Bell. (1920) (14597198867).jpg - No restrictions - https://commons.wikimedia.org/wiki/File:The_lighting_of_printing_plants_-_information_compiled_by_A.D._Bell._(1920)_(14597198867).jpg
  - File:Karmsund folkemuseum (Regional Museum) Haugesund Norway Interior Baderom fra 1920-åra, rør, varmtvannstank, tak, lampe (Bath room from the 1920s, ceiling, light bulb, piping) etc 2020-06-10 DSC00381.jpg - CC BY-SA 4.0 - https://commons.wikimedia.org/wiki/File:Karmsund_folkemuseum_(Regional_Museum)_Haugesund_Norway_Interior_Baderom_fra_1920-%C3%A5ra,_r%C3%B8r,_varmtvannstank,_tak,_lampe_(Bath_room_from_the_1920s,_ceiling,_light_bulb,_piping)_etc_2020-06-10_DSC00381.jpg
  - (1 other plate on the sheet not relied on)

### 51. kettle - kettle · polished nickel

- **Priority** 2.21 (gap 1.34, tier touched_often, installed 6, review discount 0.6)
- **What we have:** 0.21 x 0.28 x 0.35 m, floor mount, 10016 triangles, 8 surfaces, 0% flat colour
- **Real object:** A c.1925 General Electric / Hotpoint electric tea kettle: a spun-and-soldered formed-metal vessel, nickel- or copper-plated, with an exposed heating well in the base, a side two-pin terminal for a detachable cloth-covered lead with Bakelite plug, brass ears carrying a turned wooden bail handle, a removable domed lid with Bakelite knob, and a chained brass whistle cap on the spout.
- **Confidence:** medium

Evelyn's 'kept bright' nickel renders as a chalky parchment barrel (body median sRGB (210,198,172) on the front bearing, no reflection): nickel_plated at 0.82 roughness cannot say the one thing this variant exists to say, mirror plate over brass, and the pale-tinted bakelite_black terminal and plug read as grey stone. The object class is right (c.1925 formed electric vessel with heating well, side terminal, cloth lead, bail and chained whistle); the sheet's only kettles are 1930s stovetop copper and the kind is unverified, so proportion was judged against the museum figures in the notes and confidence is medium.

**Modelling**

  - Feet: the base carries two BAKELITE feet (x +/-0.046, r 0.010 to 0.012 x 0.014); a kettle stands on three, so place three at 120 deg on a 0.055 m radius.
  - Bail: five WOOD tubes (r 0.008) make an all-wood pentagon that reads angular from every bearing; build it as two body-finish wire arms r 0.005 rising from the ears to y 0.245 and one turned WOOD grip r 0.012 x 0.10 across the top at y 0.272, the Hotpoint pattern and the bail form in both NGA kettles.
  - Ears: the two r 0.010 x 0.025 ear cylinders use _body_color; make them BRASS so 'brass ears' read yellower than the plate as the variant notes require.
  - Spout: the three straight cones kink visibly at y 0.145 and 0.192; raise the tip from y 0.207 to 0.215 (level with the lid seat, so it pours) and add a fourth r 0.020 segment so the run reads as the curved gooseneck of the Croe and Cheney kettles.
  - Lid: the r 0.052 to 0.060 x 0.014 disc reads flat; add a SphereMesh cap r 0.052 scaled to 0.012 tall under the knob so it reads as the removable domed lid.

**Texturing**

  - nickel_plated: for unit 1A set the material roughness to about 0.30 (metallic stays 0.70) so the bright plate shows soft warm reflections; the 0.82 the key ships with suits 1D's and 4B's dull kettles, not the polished one.
  - bakelite_black is tinted (0.75,0.68,0.58) for every unit but 1D, which turns the terminal block, pins and plug pale grey (front bearing median (92,88,85)); tint it (0.32,0.28,0.24) at roughness 0.45 so Bakelite reads black-brown with a slight sheen.
  - The two make_ring seams (y 0.075 and 0.196) share the body finish and vanish in the plate; tint them 10% darker so the rolled seams stay visible, as the variant notes ask.

**References used**

  - File:Eugene Croe, Copper Tea Kettle, c. 1939, NGA 27052.jpg - CC0 - https://commons.wikimedia.org/wiki/File:Eugene_Croe,_Copper_Tea_Kettle,_c._1939,_NGA_27052.jpg
  - File:Clyde L. Cheney, Copper Tea Kettle, 1935-1942, NGA 27044.jpg - CC0 - https://commons.wikimedia.org/wiki/File:Clyde_L._Cheney,_Copper_Tea_Kettle,_1935-1942,_NGA_27044.jpg
  - (2 other plates on the sheet not relied on)

### 52. door_anomaly - door_anomaly

- **Priority** 2.18 (gap 0.93, tier case_system, installed 1, review discount 1.0)
- **What we have:** 0.92 x 2.14 x 0.04 m, floor mount, 4260 triangles, 4 surfaces, 100% flat colour
- **Real object:** There was no such object in a 1927-28 Queens flat: the seam is a supernatural light-leak in the 4B wall between the workstation and the radiator, and the only real thing it imitates is the hairline of light that shows round a closed painted stile-and-rail apartment entry door (3 ft 0 in x 7 ft 0 in, knob on a long backplate at about 38 in) when the room beyond is lit, or the ghost outline of a plastered-over doorway showing through a tenement wall.
- **Confidence:** medium

The shed shows the seam at zero infection, three near-black 12 mm bars and a dot, and the one reference on the sheet (Building with assurance, 1921) is a house exterior, so silhouette and material are judged against the ruled description of a light-leak round a 3 ft x 7 ft entry leaf: the knob is a solid 40 mm ball (a 1920s Russwin/Corbin knob is 51-57 mm) carrying 4,224 of the prop's 4,260 triangles, and the U has no sill line where a real closed door leaks brightest. Object class is right by definition: a door-shaped hairline of light with a latch-side knob at 0.96 m, no leaf, no joinery.

**Modelling**

  - Knob: SphereMesh r 0.02 at Godot's default 64 radial segments x 32 rings is 4,224 triangles for a 40 mm dot seen from the 1.41 m eye line; set radial_segments 12 and rings 6 (168 triangles). The whole prop then costs about 200 triangles.
  - Knob size and reading: a 1920s knob on a long backplate is 51-57 mm, so r 0.027; and since the seam is leaked light rather than a fitting, a make_ring torus r 0.027 minor 0.006 (light round a rose) keeps the outline language better than a lit ball. 1 primitive either way.
  - Sill: the U is two 2.13 m uprights and a 0.91 m lintel, 12 mm square, and a closed door leaks brightest at the undercut. Add a fourth bar 0.91 x 0.012 x 0.012 at y 0.006 (1 box) if the intended reading is the door leak; leave it out only if the intended reading is the plastered-over doorway outline, which the real_object also allows, and record which.
  - Bar section: 12 mm square bars read as tubes; a hairline is 2-4 mm. Keep a 6 mm core (0.006 x H x 0.006) at full emission for legibility at three metres and let the bloom quads in the texturing bullets carry the width.

**Texturing**

  - No MatLib key by design (unshaded emission 0.34/0.90/0.83 over albedo 0.05/0.10/0.10); keep that. A uniform bar is a neon tube, not light through plaster: add a 60 mm-wide additive billboard strip behind each bar using the light_fixture_prop halo recipe (GradientTexture2D, BLEND_MODE_ADD, alpha 0.30 to 0.0) so the light spills onto the wall; 3-4 quads, no key.
  - Vary the leak along its length: a 1 x 64 GradientTexture2D in the emission slot that thins the uprights toward the head and brightens them toward the floor, matching how a real door gap reads; the teal-cyan stays as the signal-licensed colour.
  - Harness: at infection 0 the shed renders only the albedo; an imaging pass on this prop should force emission_energy_multiplier 1.4 (the manifest base) so the silhouette can be judged at all. The material axis here is scored from the script, not the frame.

**References used**

  - none relied on; the 1 plates on the sheet were off-topic

### 53. kettle - kettle · aged copper

- **Priority** 2.16 (gap 1.29, tier touched_often, installed 6, review discount 0.6)
- **What we have:** 0.21 x 0.28 x 0.35 m, floor mount, 10016 triangles, 8 surfaces, 0% flat colour
- **Real object:** A c.1925 General Electric / Hotpoint electric tea kettle: a spun-and-soldered formed-metal vessel, nickel- or copper-plated, with an exposed heating well in the base, a side two-pin terminal for a detachable cloth-covered lead with Bakelite plug, brass ears carrying a turned wooden bail handle, a removable domed lid with Bakelite knob, and a chained brass whistle cap on the spout.
- **Confidence:** medium

Rhea's copper reads as copper but as one even orange-brown skin (three_quarter median sRGB (127,52,27)): no darker oxidised patches, no brighter hand-polish at the ears, lid rim and spout, and no dent, since the deterministic dent goes to 1D/4B/4C and not to the 3D variant shown, so a 'tarnished and handled' kettle reads freshly plated. Right object class; it shares the two-foot base, all-wood pentagon bail and kinked three-cone spout of the nickel variant, and the sheet's stovetop copper references carry the bail and spout form but not the electric fittings, so confidence is medium.

**Modelling**

  - Feet: the base carries two BAKELITE feet (x +/-0.046, r 0.010 to 0.012 x 0.014); a kettle stands on three, so place three at 120 deg on a 0.055 m radius.
  - Bail: five WOOD tubes (r 0.008) make an all-wood pentagon that reads angular from every bearing; build it as two body-finish wire arms r 0.005 rising from the ears to y 0.245 and one turned WOOD grip r 0.012 x 0.10 across the top at y 0.272, the Hotpoint pattern and the bail form in both NGA kettles.
  - Ears: the two r 0.010 x 0.025 ear cylinders use _body_color; make them BRASS so the brass ears contrast as duller yellow against the copper, as the variant notes require.
  - Spout: the three straight cones kink visibly at y 0.145 and 0.192; raise the tip from y 0.207 to 0.215 (level with the lid seat, so it pours) and add a fourth r 0.020 segment so the run reads as the curved gooseneck of the Croe and Cheney kettles.
  - Lid: the r 0.052 to 0.060 x 0.014 disc reads flat; add a SphereMesh cap r 0.052 scaled to 0.012 tall under the knob so it reads as the removable domed lid.
  - Positional wear that shares the body draw: a 0.020 r x 0.003 flattened patch on the spout root and on each ear, in copper_aged with the brighter 6C tint (0.82,0.60,0.38), so the high-touch areas read polished against the dull body for 3D and 4C.

**Texturing**

  - copper_aged is one uniform per-unit tint (3D 0.72,0.48,0.29); retexture the two lower body cylinders (y 0.045 and 0.1075) with a darker band (0.50,0.30,0.20) so oxidation sits low and grease-dark while shoulder and lid stay brighter, the Cheney kettle's pattern.
  - brass_dull on the whistle cap and chain sits close to the copper in hue; tint it (0.80,0.66,0.34) so the brass contrasts as duller yellow, per the variant notes.
  - bakelite_black tint (0.75,0.68,0.58) to (0.32,0.28,0.24) at roughness 0.45, as for the nickel variant, so the terminal and plug stop reading as grey stone.

**References used**

  - File:Eugene Croe, Copper Tea Kettle, c. 1939, NGA 27052.jpg - CC0 - https://commons.wikimedia.org/wiki/File:Eugene_Croe,_Copper_Tea_Kettle,_c._1939,_NGA_27052.jpg
  - File:Clyde L. Cheney, Copper Tea Kettle, 1935-1942, NGA 27044.jpg - CC0 - https://commons.wikimedia.org/wiki/File:Clyde_L._Cheney,_Copper_Tea_Kettle,_1935-1942,_NGA_27044.jpg
  - (2 other plates on the sheet not relied on)

### 54. washer - washer / 1926 powered wringer

- **Priority** 2.12 (gap 1.28, tier carries_game, installed 2, review discount 0.6)
- **What we have:** 0.70 x 1.34 x 0.70 m, floor mount, 3384 triangles, 14 surfaces, 7% flat colour
- **Real object:** A mid-1920s electric domestic wringer washer of the Galloway 1926 catalog class: an open square galvanized-steel tub on an angle-iron leg stand with daylight beneath, a fractional-horsepower electric motor slung under the tub driving a finned bottom gyrator by belt, and a separate powered wringer (two horizontal rubber rolls, top pressure screw, safety-release bar) on a post at one corner that swings over tub and rinse tub.
- **Confidence:** high

The finish is the most wrong thing: the four 55 mm legs, the ring frame, the belt guard and the whole wringer head (cheeks, bar and post cap) are keyed ENAMEL and render cream-white, so the machine reads as a 1930s white-enamel Maytag like the Old Maytag and VA1 photographs on this sheet rather than the ruled 1926 galvanized-class Galloway with a black-japanned angle-iron stand and cast-iron wringer head; the zinc_liner tub is the right substance and stays. Object class is right: an open square tub on legs with daylight beneath, an underslung motor, a bottom gyrator and a swinging two-roll powered wringer with pressure screw and release bar, standing as the Antique Maytag Washing Machine reference stands; the detail gaps are a Ø 240 mm motor with no pulley or belt, box rim strips for a wired rolled rim, a drain pipe with no cock, and a machine that reads freshly painted for a landlord-supplied 1922-27 purchase.

**Modelling**

  - Motor: make_cyl(0.12, 0.12, 0.30) becomes make_cyl(0.085, 0.085, 0.22) (a fractional-hp frame is about Ø 170 x 220), plus a Ø 80 x 12 mm pulley disc on its end, a belt make_box(0.20, 0.004, 0.025) and a Ø 60 x 12 mm pulley under the gyrator hub: 3 primitives added, so 'belt-driven from below' is visible under the tub instead of asserted.
  - Tub rim: the four 0.70 x 0.035 x 0.04 rim strips become four Ø 25 mm cylinders make_cyl(0.0125, 0.0125, 0.70) at y 0.825, the wired rolled rim of a galvanized tub: same count.
  - Legs: 0.055 square to 0.040 square (angle-iron scale) with a Ø 40 x 15 mm cast foot make_cyl(0.020, 0.020, 0.015) under each: 4 primitives added.
  - Wringer head: two Ø 90 x 12 mm drive gears on the outer face of the post-side cheek and a Ø 30 mm drive-shaft cylinder up the post: 3 primitives; the two 0.44 m rolls, the brass screw, the 0.19 m wooden T-handle and the release bar are right and reach the hand.
  - Drain: the Ø 56 x 240 mm pipe has no cock; add a handle make_box(0.06, 0.012, 0.012) at its end and a hose make_cyl(0.010, 0.010, 0.25) dropping to the floor: 2 primitives.

**Texturing**

  - Frame and head: change the ENAMEL retexture row from 'enamel' to 'cast_iron' tinted (0.30, 0.29, 0.27) at 0.68 so the legs, ring frame, belt guard, cheeks and yoke bar read as black-japanned iron; the finish count stays at five and the 28-mesh two-washer budget is untouched.
  - Fill cocks: brass_dull at (0.78, 0.70, 0.49) reads as brown wood in the shed's flat light; use (0.82, 0.72, 0.48) at 0.72 as radiator_prop does.
  - Wear as ruled (patched galvanized, landlord-supplied): three solder patches make_box(0.08, 0.06, 0.002) in a lighter zinc tint (0.90, 0.90, 0.86) on the tub sides, four rust discs through cast_iron at (0.48, 0.20, 0.10) under the feet, a soap-scum line inside the tub (a 0.60 x 0.002 x 0.60 ring tinted (0.85, 0.82, 0.75) at y 0.80, seen when the lid is open), and a polished band 0.30 m long at the centre of each roll as a lighter rubber_aged tint: 9 primitives.
  - Lid: METAL to zinc_liner is right; the stamped grip in the lid's own finish stays as ruled.

**References used**

  - File:Antique Maytag Washing Machine.jpg - Public domain - https://commons.wikimedia.org/wiki/File:Antique_Maytag_Washing_Machine.jpg
  - File:Maytag wringer washing machine VA1.jpg - CC BY-SA 4.0 - https://commons.wikimedia.org/wiki/File:Maytag_wringer_washing_machine_VA1.jpg
  - File:Old Maytag wringer washing machine clothes washer.jpg - CC BY 2.0 - https://commons.wikimedia.org/wiki/File:Old_Maytag_wringer_washing_machine_clothes_washer.jpg
  - File:The Saturday evening post (1920) (14761946986).jpg - No restrictions - https://commons.wikimedia.org/wiki/File:The_Saturday_evening_post_(1920)_(14761946986).jpg
  - (4 other plates on the sheet not relied on)

### 55. darts - darts

- **Priority** 1.90 (gap 2.68, tier leave_alone, installed 1, review discount 1.0)
- **What we have:** 0.07 x 0.21 x 0.07 m, floor mount, 84 triangles, 7 surfaces, 100% flat colour
- **Real object:** A heavy bar tumbler or nonic pint glass, chipped at the rim, standing on a shelf beside the throwing line of a 1928 bar and holding three mismatched house darts (turned-wood or brass barrels, steel points, turkey-feather flights) for the elm or clay dartboard hung on the wall 2.37 m away.
- **Confidence:** medium

The one thing most wrong is the glass: the pot is an opaque 0.075 x 0.10 x 0.075 m box in pale grey-green (0.72, 0.76, 0.74) at roughness 0.18, and in every bearing it reads as a white ceramic cube, not a bar tumbler, while the three 8 mm square sticks and three flat 26 x 30 x 2 mm coloured plates read as pencils with paper flags rather than darts with feather flights. The object class - a pot of three mismatched house darts on the oche ledge - is the right thing and the mismatch is already there; the parts are the wrong shapes. The sheet's only reference (a 1937 Capitol milking contest) is off-topic and was not used, so this is judged against the real_object description at medium confidence; the tier is leave_alone, so the bullets are proportion fixes plus the one material change that turns the cube into a glass.

**Modelling**

  - Tumbler: replace the box with one make_cyl r 0.036 m top / 0.031 m bottom, 0.125 m tall (a 12-oz bar tumbler; 0.085 dia x 0.15 m if it is to read as a pint) on a 0.004 m base disc r 0.031 m - two primitives - and drop the darts' start height from y 0.12 to 0.085 so their points stand on the glass floor.
  - Darts at real length: each 0.14 m overall, not 0.16 - a barrel make_cyl r 0.006 m top / 0.0045 m bottom, 0.050 m long; a shaft r 0.0025 m, 0.055 m; a point r 0.0012 m, 0.028 m; nine primitives for three darts in place of three square sticks. Make one barrel wood (r 0.0065 m, fatter), one knurled brass (r 0.005 m), one wood, so the mismatch is in the hand and not only in the flight colour.
  - Flights: three vanes per dart instead of one flat plate - 0.012 x 0.032 x 0.001 m plates at 120 degrees around the shaft end, nine plates total, with one vane missing on one dart per distinguishing_features; keep the fan of -7 / -1 / +5 degrees, which already reads as three darts dropped in at different angles.
  - Keep the marker at floor +0.97 on the 0.92 m ledge and the 'tick' emitter; the pot's height change (0.10 to 0.125 m) does not move the interaction.

**Texturing**

  - Glass: the one material that changes the object - transparency alpha with albedo (0.85, 0.90, 0.88, 0.32), roughness 0.05, metallic 0.0, cull disabled; the catalog key glassish (the jukebox's mechanism window) is the nearest existing runtime path, otherwise new key bar_glass. The census is 100 percent flat colour and this surface is the reason.
  - Barrels: brass barrel -> brass_dull (hand-touched but horizontal in the glass, oxidised); wooden barrels -> wood_dark with a painted ring (0.004 m band in indicator_enamel red or green); points -> metal with roughness 0.6 for rusting steel.
  - Flights: turkey feather, not enamel - desaturate the three colours (c8352b, 2f8f86, e3b02f) by half and lift roughness to 0.9; one flight in plain grey-brown (0.45, 0.40, 0.33) is the cheapest way to say three different sets.
  - Wear: a chip at the rim (one 0.006 m notch cut as a second short cylinder subtract is not available - fake it with a 0.004 m dark wedge quad at the rim), a rust tint on two of three points, and a grey thumb-mark band 0.03 m tall on the glass at 0.06 m; the pot is cheap, second-hand and a bit broken by the divergence rule.

**References used**

  - none relied on; the 1 plates on the sheet were off-topic

### 56. wall_clock - clock / 8-day drop octagon

- **Priority** 1.80 (gap 1.42, tier touched_often, installed 2, review discount 0.6)
- **What we have:** 0.48 x 0.74 x 0.12 m, wall mount, 4514 triangles, 10 surfaces, 50% flat colour
- **Real object:** Two different objects share the marker: 4B's is a cheap second-hand American eight-day spring-driven drop-octagon wall regulator (about a 12-inch dial in a 16-inch oak octagonal head with a short glazed drop showing a brass-bobbed pendulum, brass bezel, two winding arbors), while the lobby's is a sealed institutional secondary clock receiving Vantry house time in a moulded phenolic drum with an enamel dial, screwed brass bezel and no winding holes, running permanently four minutes fast.
- **Confidence:** high

The pendulum swings outside the case: PendulumRig sits at z 0.055 and the bob at z 0.053-0.065, in front of the drop's dark panel whose face is at z 0.050, with no glazed drop door, and the 0.318 m square dial glass sits over a 0.364 m round bezel so its corners lie on the oak while its edges fall inside the dial. Object class is right: an American eight-day drop-octagon with brass bezel, two winding arbors and a brass-bobbed pendulum, as the Schoolhouse Regulator and Seth Thomas references show.

**Modelling**

  - Glaze the drop: move the 0.165 x 0.238 x 0.010 DARK_WOOD panel (now at z 0.045, proud of the drop face at 0.039) to z -0.030 as a back board, move PendulumRig to z 0.005 so the 0.255 rod and 0.051 bob hang inside the 0.082 m case, and add a second optical QuadMesh 0.165 x 0.238 at z 0.040 as the drop-door glass; 1 quad added, panel moved.
  - Dial glass: the QuadMesh 0.318 square at z 0.082 has a 0.225 half-diagonal (over the rails at r 0.184-0.224) and a 0.159 half-edge (inside the 0.182 bezel). Use a CylinderMesh r 0.172 h 0.002, 16 segments, at z 0.060, seated in the bezel like the Virginia V Seth Thomas glass; same mesh count.
  - Drop height: the 0.225 x 0.335 drop plus the 0.243 corner radius make the clock 0.74 m tall; a 12-inch short-drop (Schoolhouse Regulator Pendulum Clock, Seth Thomas Clock) is 0.61-0.66. Shorten the drop to 0.225 x 0.260 (centre y -0.297) and the rod to 0.190 so the bob centres at y -0.395.
  - Head frame: rails 0.165 x 0.040 x 0.082 at r 0.204 leave 40 mm of wood outside the bezel; the references show 60-70 mm of moulded frame round the dial. Make the rails 0.165 x 0.060 x 0.082 at r 0.194 (outer edge unchanged at 0.224).
  - Second hand: a cheap eight-day drop octagon carries hour and minute only (Seth Thomas Clock, Old Pendulum clock); the Virginia V ship's clock has a subsidiary seconds bit, never a red centre-seconds. Drop the 0.136 x 0.004 red hand on this variant and point _perform_synced_event's 'advance a hand' verb at _minute (TAU/60 x accent) so the corrupted verb survives.
  - Spade hands: the 0.013 x 0.083 hour and 0.009 x 0.122 minute bars are plain sticks; add one 0.024 x 0.030 x 0.006 INK box at 0.7 of each length (2 boxes, inside the INK surface) for the spade.
  - Numerals and track: the dial has twelve INK boxes and nothing else. Build Roman numerals from INK strokes (about 34 boxes 0.004 x 0.022 x 0.003 at r 0.129) and a 60-mark minute track (0.002 x 0.006 x 0.003 at r 0.150); all merge into the existing INK surface, the ten-mesh cap is untouched, and no lettering goes into a texture plate.

**Texturing**

  - oak_quartered tint (0.76, 0.62, 0.46) at roughness 0.82 reads as fresh-sawn orange oak with heavy flake; a varnished 1890s-1910s case (all four references) is darker and glossier: tint (0.55, 0.40, 0.26), roughness 0.45.
  - paper dial (aged_paper albedo) tinted (0.92, 0.88, 0.78) reads clean cream; the second-hand dials in the Virginia V and Seth Thomas references are foxed and yellowed toward the rim: tint (0.84, 0.77, 0.60) at the same 0.68 roughness.
  - brass_dull bezel and bob tint (0.82, 0.72, 0.48) at roughness 0.62 is right for handled brass; keep.
  - Wear: nothing says second-hand: no darkened varnish where a hand opens the drop door, no dust line on the dial. Tint the drop box's own colour constant darker on wood_dark (0.50, 0.38, 0.28) so the lower case reads re-finished and mismatched, the way a cheap clock accumulates; no new key.

**References used**

  - File:Schoolhouse Regulator Pendulum Clock.jpg - Public domain - https://commons.wikimedia.org/wiki/File:Schoolhouse_Regulator_Pendulum_Clock.jpg
  - File:Old Pendulum clock.jpg - Public domain - https://commons.wikimedia.org/wiki/File:Old_Pendulum_clock.jpg
  - File:Seth Thomas Clock.jpg - CC0 - https://commons.wikimedia.org/wiki/File:Seth_Thomas_Clock.jpg
  - File:Virginia V (ship, 1922) engine room 10 - old Seth Thomas wall clock.jpg - CC BY-SA 4.0 - https://commons.wikimedia.org/wiki/File:Virginia_V_(ship,_1922)_engine_room_10_-_old_Seth_Thomas_wall_clock.jpg
  - (1 other plate on the sheet not relied on)

### 57. wall_clock - clock / Vantry lobby master

- **Priority** 1.80 (gap 1.42, tier touched_often, installed 2, review discount 0.6)
- **What we have:** 0.46 x 0.47 x 0.14 m, wall mount, 2482 triangles, 10 surfaces, 50% flat colour
- **Real object:** Two different objects share the marker: 4B's is a cheap second-hand American eight-day spring-driven drop-octagon wall regulator (about a 12-inch dial in a 16-inch oak octagonal head with a short glazed drop showing a brass-bobbed pendulum, brass bezel, two winding arbors), while the lobby's is a sealed institutional secondary clock receiving Vantry house time in a moulded phenolic drum with an enamel dial, screwed brass bezel and no winding holes, running permanently four minutes fast.
- **Confidence:** medium

No on-topic reference reached the sheet (it carries two St Pancras tower views, a hotel plate, an Underground roundel, a jukebox, the Colgate sign and the 4B drop-octagon photographs), so this is judged against the ruled description of a sealed IBM/Simplex-class secondary: the dial has twelve bar marks and no Arabic numerals or minute track, the sealed setting cover sits on the enamel dial at 6 o'clock inside the bezel instead of on the case, and the 0.404 m square glass has corners 5 cm outside the 0.47 m drum. Object class is nearly right, a phenolic drum with a screwed brass bezel and no winding holes, but the cream matte dial and the dial-mounted cover pull it toward a domestic clock.

**Modelling**

  - Setting cover: the 0.064 x 0.030 x 0.010 BRASS box at (0, -0.176, 0.063) is on the dial face inside the r 0.203 bezel. Move it to the drum's underside at (0, -0.235, -0.005) as 0.064 x 0.010 x 0.030 and run the rattle tween on position:y; it stays the one hand-testable part and now reads as a locked case cover.
  - Glass: the 0.404 QuadMesh at z 0.082 has a 0.286 half-diagonal, beyond the 0.235 drum radius. Use a CylinderMesh r 0.203 h 0.002, 24 segments, at z 0.058 inside the bezel; same mesh count.
  - Minute track and numerals: add 60 INK boxes 0.002 x 0.008 x 0.003 at r 0.190 (merged into INK) and twelve Arabic numerals as Label3D at r 0.150 with 0.045 m cap height if the family's ten-mesh cap counts MeshInstance3D only; otherwise build 1-12 from about 40 INK stroke boxes. The ruled dial is dominated by bold Arabic numerals and a full minute track for reading at distance.
  - Hands: minute 0.154 and second 0.172 stop short of the 0.166 marks on a 0.202 dial; institutional hands reach the track: minute 0.168 x 0.009, second 0.185 x 0.004 with a 0.03 x 0.03 x 0.006 counterweight box, hour 0.110 x 0.016.
  - Drum back: r 0.235 h 0.082 is a flat can; moulded secondary drums step into the back. One BAKELITE cylinder r 0.215 h 0.020 at z -0.063 behind the drum gives the moulding line; 1 primitive.

**Texturing**

  - enamel dial tint (0.80, 0.81, 0.77) at roughness 0.66 reads cream and matte; a vitreous enamel steel dial is white and glossy: tint (0.95, 0.95, 0.93), roughness 0.25.
  - brass_dull bezel tint (0.82, 0.72, 0.48) at roughness 0.62 shows the albedo's mottle as burl-wood figure on the 0.014 torus (visible in the high_quarter bearing); a machined bezel wants brass_bright (runtime-staged) at roughness 0.35, or nickel_plated to match the four screws.
  - bakelite_black drum tint (0.52, 0.46, 0.38) reads as good dark phenolic: keep.
  - Wear: service equipment stays clean and the fiction is permanent and authoritative, so the near-absence of wear is right; one darker tint on the cover box where it is handled is enough.

**References used**

  - none relied on; the 8 plates on the sheet were off-topic

### 58. songbook_terminal - songbook_terminal

- **Priority** 1.63 (gap 2.08, tier leave_alone, installed 1, review discount 1.0)
- **What we have:** 0.66 x 0.45 x 0.40 m, floor mount, 2256 triangles, 19 surfaces, 100% flat colour
- **Real object:** An 1857-1860s Paris phonautograph as sold by Rudolph Koenig: a horn (Scott's 1857 prototype used a wooden barrel; Koenig's commercial version a large plaster-of-Paris horn) feeding a membrane diaphragm whose hog-bristle stylus scratches a trace into lampblacked paper wrapped on a hand-cranked brass cylinder that advances on a lead screw — a sound-writing laboratory instrument that records and cannot play back, standing here as a ~70-year-old second-hand machine on a wooden plinth at chest height by the bar's stage.
- **Confidence:** high

The recording cylinder is turned the wrong way: its axis runs front-to-back with the crank on its end face toward the viewer, so the horn points at the drum's flat end and the 0.075 m bristle enters that end face by 12 mm, whereas in the 1868 Koenig engraving the cylinder axis runs parallel to the horn, the bristle rests on the curved surface and crank and flywheel sit on the far end; with all 19 surfaces flat-coloured it reads as a small bucket aimed at a turntable stood on edge. It is the right object (barrel horn, membrane, bristle, sooted cylinder, lead screw, hand crank, no electricity).

**Modelling**

  - Cylinder: set _cylinder.rotation.z = 90 deg (axis along X, parallel to the horn and the lead screw), centre it at (0.185, 0.223, 0) so its top tangent meets the bristle tip at y 0.298, and move the 0.30 m axle, crank hub, arm and knob to the +X axle end at x 0.35; the crank orbit in _process() then rotates about X instead of Z.
  - Bearing stands: the axle floats 0.125 above the carriage rail with nothing holding it; add two IRON A-stands 0.03 x 0.11 x 0.06 at x 0.075 and 0.30 from the plinth top (y 0.115) to the axle, the cast frames M in the engraving.
  - Horn: 0.30 long with a 0.145 mouth radius reads as a bucket beside a 0.15 m drum; lengthen to 0.45 with mouth r 0.19, letting the mouth overhang the -X plinth end by 0.08 as the engraving's does, and set two iron cradles 0.02 x 0.05 x 0.12 under the hoops, since the horn currently floats 40 mm above the plinth.
  - Feet: two r 0.028 iron feet along X make a tipping plinth; either four at (+/-0.26, +/-0.13) or, since the ruling brackets it at FLR + 0.92 m, two 0.04 x 0.06 x 0.30 iron bracket arms under the plinth against the wall so it hangs the way the marker says.
  - Flywheel (leave_alone tier, optional): a torus r 0.11 tube 0.008 with six r 0.004 spokes on the axle behind the crank, the speed-steadier B in the engraving.

**Texturing**

  - The script never calls retexture(), so every surface is flat colour (horn samples (60,44,35), drum (25,24,22)); add the table [walnut to `wood_dark`, brass to `brass_dull` (the vertical throat and crank may take `brass_bright`), iron to `cast_iron`, soot to `soot`]; every key exists in MatLib.SETS, so no batch.
  - Diaphragm (0.72,0.68,0.58) and bristle (0.62,0.58,0.44) can stay flat at this size, but lower the diaphragm's roughness to 0.35 so the stretched skin reads as skin rather than card.
  - Seventy years second-hand: tint the walnut lip (0.66 x 0.022) 15% lighter for handling wear and the 0.10 x 0.035 maker's plate toward (0.40,0.33,0.18) so the brass reads tarnished, not new.

**References used**

  - File:Cours de physique de l ecole Polytechnique - ed 2 vol 2 1868 p509 - phonautograph.jpg - Public domain - https://commons.wikimedia.org/wiki/File:Cours_de_physique_de_l_ecole_Polytechnique_-_ed_2_vol_2_1868_p509_-_phonautograph.jpg
  - File:Phonautographic recording session - Scott 1857.jpg - Public domain - https://commons.wikimedia.org/wiki/File:Phonautographic_recording_session_-_Scott_1857.jpg
  - (1 other plate on the sheet not relied on)

### 59. boxfan - boxfan / iris green

- **Priority** 1.58 (gap 1.43, tier lighter_pass, installed 4, review discount 0.6)
- **What we have:** 0.57 x 0.65 x 0.44 m, floor mount, 12564 triangles, 9 surfaces, 0% flat colour
- **Real object:** A second-hand 1920–1927 portable desk or floor electric fan of the Westinghouse/Emerson/GE class: heavy japanned cast-iron base and neck, exposed cylindrical motor can, four broad overlapping blades, deep front and rear wire guards, a carrying handle, a stepped speed switch and a cloth-covered line cord ending in a two-pin plug.
- **Confidence:** high

The green reads as pale chalky sage (cast_iron tint 0.34/0.43/0.34 at roughness 0.60) where the ruled finish is dark green enamel with the guard and blades staying dark so the colour reads as paint on the same construction; the modelling faults are the shared ones as juno_black (floating handle, rectangular plinth, narrow flat blades, bare hub, low trunnions). Object class is right.

**Modelling**

  - As juno_black (shared script): handle onto the motor top, two-cylinder round base r 0.150 / 0.115, wider three-box blades, brass_dull hub badge r 0.028, trunnions raised to the 0.305 axis with two yoke uprights; this variant adds no geometry of its own.

**Texturing**

  - cast_iron body tint (0.34, 0.43, 0.34) reads as mint-sage primer; dark green enamel is tint (0.15, 0.25, 0.17) with roughness 0.40 passed as the fourth retexture element so it reads as gloss enamel over cast, not paint over paint.
  - metal guard tint (0.48, 0.47, 0.43) is right in hue for dull grey steel; keep the tint and drop roughness from 1.00 to 0.7 so the wire catches a highlight and the green body reads as a different construction from the guard, which is the variant's own distinguishing note.
  - Blades on bakelite_black tint (0.25, 0.21, 0.17) read correctly as dark phenolic; no change.
  - Wear as juno_black: nothing marks a second-hand fan; a darker lower-base colour constant on cast_iron, not a new key.

**References used**

  - File:Hardware merchandising March-June 1921 (1921) (14784650333).jpg - No restrictions - https://commons.wikimedia.org/wiki/File:Hardware_merchandising_March-June_1921_(1921)_(14784650333).jpg
  - (3 other plates on the sheet not relied on)

### 60. boxfan - boxfan / juno black

- **Priority** 1.58 (gap 1.43, tier lighter_pass, installed 4, review discount 0.6)
- **What we have:** 0.60 x 0.67 x 0.44 m, floor mount, 12564 triangles, 9 surfaces, 0% flat colour
- **Real object:** A second-hand 1920–1927 portable desk or floor electric fan of the Westinghouse/Emerson/GE class: heavy japanned cast-iron base and neck, exposed cylindrical motor can, four broad overlapping blades, deep front and rear wire guards, a carrying handle, a stepped speed switch and a cloth-covered line cord ending in a two-pin plug.
- **Confidence:** high

The carrying handle floats: its three tubes run from y 0.492 to 0.545 at z 0.06, which is 90 mm above the motor top (y 0.40) and midway between the guard rings at z -0.105 and 0.115, so the loop hangs in air; and the fan stands on a rectangular two-step plinth where the one on-sheet reference, the 1921 Westinghouse advertisement, shows the round bell base of the ruled Westinghouse/Emerson class, while the black-japanned body renders as matte mid-grey. Object class is right: a 1920-27 portable cast-base fan with a 440 mm cage and a separate two-pin plug, not a postwar box fan.

**Modelling**

  - Handle: move the three BAKELITE tubes (r 0.009) from (+/-0.105, 0.492-0.545, 0.06) onto the can: legs (+/-0.055, 0.40 to 0.45, 0.035) and a 0.11 m crossbar at y 0.45, so the loop is cast onto the motor top; the one-line alternative is z 0.115 so the legs land on the rear ring. Same three primitives.
  - Base: the two boxes 0.31 x 0.045 x 0.23 and 0.24 x 0.035 x 0.17 make a rectangular plinth; the Westinghouse 1921 advertisement shows a round stepped bell. Swap for two cylinders, r 0.150 h 0.045 at y 0.023 and r 0.115 h 0.035 at y 0.052 (same primitive count), keeping the 0.18 m tapered neck above them.
  - Blades: each blade is two boxes 0.082 and 0.102 wide x 0.125 tall x 0.010, so four tips cover about 31% of the 1.32 m circumference at r 0.21; the advertisement's blades are broad, overlapping and round-shouldered (roughly 60% coverage). Widen to 0.110 and 0.150 and add a third 0.13 x 0.06 x 0.010 tip box per blade at radial 0.185 rotated a further 18 degrees about Z to round the shoulder: 4 boxes added inside the single rotor draw.
  - Guard badge: the six spokes meet at a bare hub on both cages. Add one brass_dull disc r 0.028 h 0.004 at (0, 0.305, -0.112) on the front guard, the cast maker's medallion the advertisement shows at the hub; 1 cylinder.
  - Yoke: the trunnion cylinders (r 0.030 h 0.035) sit at y 0.275, 30 mm below the 0.305 motor axis, and poke out of the can's underside from a flat 0.25 x 0.045 x 0.055 bar. Raise them to y 0.305 and add two BODY uprights 0.025 x 0.09 x 0.03 at x +/-0.115, y 0.26 so the yoke visibly rises round the can to the tilt axis; 2 boxes.
  - Motor can: r 0.082-0.095 (dia 0.19) is 43% of the 0.44 cage; the advertisement's can is about a third. r 0.072-0.080 at the same 0.17 m depth keeps the ruled motor depth and reads less like a drum.

**Texturing**

  - cast_iron body tint (0.31, 0.31, 0.29) at the key's roughness 0.60 reads as matte mid-grey; japanning is a glossy black lacquer. Tint (0.13, 0.13, 0.12) and pass roughness 0.35 as the fourth retexture element (clock_prop already uses that slot) so only the badge, handle and prongs read as bare metal, as the variant states.
  - metal guard (galvanized worn albedo) at roughness 1.00 / metallic 0.90 with tint (0.48, 0.47, 0.43) reads khaki; a black-painted steel guard 'slightly lighter than the body' is tint (0.24, 0.24, 0.23) at roughness 0.6.
  - Handle tubes keyed bakelite_black read as a plastic hoop; once on the can, key them with the body row (cast_iron, same tint) or metal for a plated steel handle.
  - Wear: nothing separates a second-hand japanned fan from a new one: no chipped lacquer on the base edge, no dust on the cage wire. Give the lower base step its own colour constant tinted (0.20, 0.19, 0.17) on cast_iron for the scuffed foot, no new key; all four fans currently share identical untouched surfaces, which the brief's 'wear that says who owns it' rule forbids.

**References used**

  - File:Hardware merchandising March-June 1921 (1921) (14784650333).jpg - No restrictions - https://commons.wikimedia.org/wiki/File:Hardware_merchandising_March-June_1921_(1921)_(14784650333).jpg
  - (3 other plates on the sheet not relied on)

### 61. bar_signage - bar_signage

- **Priority** 1.50 (gap 1.78, tier leave_alone, installed 1, review discount 1.0)
- **What we have:** 2.82 x 1.50 x 0.60 m, wall mount, 43452 triangles, 45 surfaces, 100% flat colour
- **Real object:** The street sign of a Japanese-run basement bar on a Queens block in late 1928: a hand-painted timber fascia signboard (kanban) reading 春木屋 lit from outside by two gooseneck reflector lamps, a red bamboo-and-washi chochin lantern (akachochin, the izakaya open-for-business signal) hung on a bracket arm, and an incandescent light-bulb arrow sign pointing down the enclosed stair to a below-grade entrance.
- **Confidence:** medium

All 45 surfaces are flat colour and nothing has weathered: the sixteen-year board is a smooth slab the gooseneck wash lifts to a textureless (130,121,112), the kanji are crisp 12 mm slats with square ends, and the akachochin is a smooth orange capsule (255,152,85) with no ribs. The object class is right (painted kanban lit by two gooseneck reflectors, red chochin on a bracket arm, incandescent down-arrow with two dead bulbs), but no reference on this sheet shows any of the three sign types, a Tampa street postcard and three Tsingtau postcards, so this critique is against the real_object description and the Harukiya rulings only, with confidence held at medium.

**Modelling**

  - Kanji strokes are 0.045 tall x 0.012 deep boxes standing 32 mm proud with square ends; paint has no thickness. Drop stroke depth to 0.003, vary widths 0.035-0.060 per stroke in the KANJI tables, and add an r 0.020 sphere at each stroke start so ends swell like a brush; 春木屋 stays stroke-built because no CJK font ships.
  - Board 2.35 x 0.55 x 0.05 is one box with no fixings: build it as three 0.18 m planks with 3 mm gaps and back it with three 0.04 x 0.30 x 0.06 iron angle brackets carrying r 0.012 lag heads (Accord 11: every bracket has anchors, one painted over).
  - Goosenecks are a 0.12 stub plus a 0.36 straight arm plus a cone, an L not a gooseneck; give each arm a three-segment bend (0.12 + 0.20 + 0.14 cylinders at 0/40/80 deg) and enlarge the reflector mouth from r 0.095 to r 0.14 with a torus lip (tube 0.006), the 12-inch spun-steel shade of a 1920s fascia.
  - Chochin: CapsuleMesh r 0.20 h 0.60 is a pill; use a five-section CylinderMesh stack (r 0.16 to 0.20 to 0.16, 0.12 each) with twelve dark torus ribs (tube 0.003) at 0.05 pitch so the split-bamboo spiral reads, with flat ends under the two r 0.09 rims.
  - Arrow bulbs sit as bare r 0.026 spheres on the cabinet face; add a porcelain socket cylinder r 0.018 x 0.025 under each (the neon_sign_prop _bulb() pattern) and stand the bulbs 0.05 proud so the cabinet reads as a studded electric sign.

**Texturing**

  - Board TIMBER (0.15,0.115,0.085) to the catalog's `sign_board` key (already in MATERIAL_CATALOG; confirm it is in GODOT_STAGE and MatLib.SETS before naming it in retexture()) with a dark tint, and the kanji PAINT to a worn cream (0.70,0.66,0.56) at roughness 0.9 so the strokes read as sixteen-year-old sign paint, not fresh white.
  - Lantern body to the catalog's `chochin` key with emission kept, base colour (0.85,0.10,0.08) instead of the (0.72,0.14,0.08) that lights to orange (1.0,0.30,0.10), so it reads red against the teal stair per the CANONICAL composition.
  - Arrow cabinet and gooseneck steel to `metal` with a chipped dark-enamel tint, and two `fx_drip` rust runs (0.03 x 0.20) below the bracket lags; weathering follows the drip line and the lamp heat (Accord 12), not a filter.

**References used**

  - none relied on; the 4 plates on the sheet were off-topic

### 62. eye_pendant - eye_pendant

- **Priority** 1.50 (gap 1.15, tier leave_alone, installed 8, review discount 1.0)
- **What we have:** 0.55 x 0.55 x 0.23 m, wall mount, 734 triangles, 4 surfaces, 50% flat colour
- **Real object:** The fitting is a hung opal-glass globe pendant on a short brass stem with a calyx-shaped fitter, the ordinary 1920s stair-well and light-court globe; what carries it is fictional, a commissioned brass foliate tree wound up the court, whose real-world reference the generator names as the composed foliate ironwork of Edgar Brandt and the Brandt-Daum lamps of exactly these years.
- **Confidence:** medium

No usable reference: all four Commons pulls on this sheet are off-topic (a 1921 children's-book plate, a 2012 flower-show structure, a chewing-gum advertisement and a biscuit box), so this is judged against the kind description and the owner's atrium-tree direction at medium confidence. The globe itself is close, a Ø 230 x 270 mm opal egg the notes accept as a blown form; what is wrong is the joint and the stem: the Ø 60-104 x 28 mm brass calyx sits on the globe's top pole like a hat with no neck or collar under it, and the Ø 16 x 100 mm stalk above is a flat-colour rod (its 0.42/0.35/0.18 colour matches no retexture row) that ends in air 0.15 m above the calyx in the shed. Object class is right: an opal globe pendant on a brass fitter hung from composed brasswork, as ruled.

**Modelling**

  - Neck and collar: add an opal neck make_cyl(0.038, 0.042, 0.025) at y +0.045 on the globe's top and turn the calyx cone into a fitter collar make_cyl(0.048, 0.052, 0.030) at y +0.062 with three Ø 5 mm set-screw nubs make_cyl(0.0025, 0.0025, 0.008) set radially at 120 degrees: 5 primitives, so the globe is held at its neck as the notes require instead of capped.
  - Stalk: confirm the generator's 0.34 m drop stem meets the stalk top at +0.15; if it does not, lengthen the stalk to make_cyl(0.008, 0.008, 0.34) centred at y +0.22 so the eight court lanterns hang on visible brass and not on air, and finish it with a Ø 12 x 10 mm ferrule at the top: 1 primitive.
  - Globe: SphereMesh at 18 x 10 segments facets on a Ø 230 mm emissive surface seen from the stair; radial_segments 32, rings 16, eight instances.

**Texturing**

  - Stalk: add a retexture row for (0.42, 0.35, 0.18) to 'brass', or build the stalk in the brass constant (0.62, 0.55, 0.30), so stalk and calyx share the aged-brass plate; today the stalk is the census's flat #6b592e.
  - Globe: it is named bulb_fruit so it takes _bulb_mat (albedo 1.0/0.97/0.9, no texture). Give _bulb_mat the milk_glass albedo and normal (the key is in the catalog, GODOT_STAGE and MatLib.SETS), because the LightRig darkens the other storeys and the court shows all eight lanterns at once, so the unlit ones must read as opal glass rather than white plastic eggs.
  - Wear: a dust cap on the globe's upper third as a tint band toward (0.86, 0.85, 0.80) on the milk_glass, per lantern by hash(name); the calyx already carries aged brass and needs nothing.

**References used**

  - none relied on; the 4 plates on the sheet were off-topic

### 63. neon_sign - neon_sign

- **Priority** 1.49 (gap 1.20, tier leave_alone, installed 3, review discount 1.0)
- **What we have:** 0.41 x 6.39 x 1.27 m, wall mount, 24180 triangles, 46 surfaces, 100% flat colour
- **Real object:** A late-1920s American 'electric sign' in its two trade forms: a double-faced projecting blade of painted sheet steel on an angle-iron frame, hung off the facade on wall brackets with tie rods and edged with an exposed incandescent bulb border, or a flat sheet-steel fascia pan; in either case carrying bent clear-glass luminous tubing (red-orange neon or blue argon-mercury) mounted proud of the dark face on glass tube supports and fed by a luminous-tube transformer in a ventilated steel box via rigid conduit.
- **Confidence:** medium

The tube is 44 mm across on six-sided cylinders in phosphor pink with a pale porcelain boot at every stroke end, about ten boots per letter where a real tube has two, so the letters read as pink pipe fittings rather than 12-18 mm clear glass carrying red-orange neon; the blade itself, its two arms, wall plates, lags, rust runs, transformer, conduit and LB condulet are the right hardware. Right object class, a bulb-bordered projecting electric sign re-lettered in neon, which is the honest 1928 reading; confidence is medium because the shed shows the 6.4 m blade edge-on in one bearing only, the other three frame empty air, and the sheet's usable references are a modern script fascia and a wrought-iron bracket sign.

**Modelling**

  - TUBE_R 0.022 to 0.008 (16 mm glass) and radial_segments 6 to 8; at 0.45 x 0.75 m glyph cells the strokes stay legible from the street and stop reading as pipe.
  - Boots: build two per letter (first stroke start, last stroke end) instead of two per stroke; ORISON drops from about 88 to 24 boot cylinders across both faces and the dark face stops being freckled with pale dots, which is what the front bearing shows even edge-on.
  - Corners: add a SphereMesh r TUBE_R at every stroke joint (about 24 per face for ORISON) so butt-jointed cylinders read as bent tube with painted-out crossovers.
  - Bulb border: the 19-per-edge run covers only the two vertical edges; add three bulbs on a 0.30 pitch along the top and bottom between z0 and z1 so the border runs the full perimeter, and replace `i % 9 != 4` with a fixed two dead lamps (the variant asks for one or two, not one in nine).
  - Tie rod: an r 0.012 rod from the blade's top outer corner (z1, +half_y) to a 0.12 x 0.12 wall plate 0.60 m above the upper arm; period blades are tied up to the wall as the Romsey bracket sign shows, not only braced below.

**Texturing**

  - Default tint (1.0,0.30,0.42) is 1933+ phosphor pink; 1928 tubing is clear glass with red-orange neon, so set the default to (1.0,0.28,0.10) and keep DRUGS cyan (close to argon-mercury blue) and HARUKIYA amber as yellow-tinted glass.
  - Dead tube (0.36 grey, roughness 0.42) is described as a phosphor coat; keep the grey but treat it as dust on clear glass at roughness 0.25 so the dead run still catches the border bulbs.
  - Cabinet near-black (0.055,0.055,0.062) at metallic 0.45 is flat colour (edge samples (62,62,63)); the `metal` key with a black-japan tint gives painted sheet steel a surface, and the two rust boxes at the wall plates could use `fx_drip` for a feathered run.

**References used**

  - File:Parkside Candies store Buffalo NY 2025-09-09 18-47-06.jpg - CC BY 4.0 - https://commons.wikimedia.org/wiki/File:Parkside_Candies_store_Buffalo_NY_2025-09-09_18-47-06.jpg
  - File:Sign for the Conservative Club, Romsey - geograph.org.uk - 1135253.jpg - CC BY-SA 2.0 - https://commons.wikimedia.org/wiki/File:Sign_for_the_Conservative_Club,_Romsey_-_geograph.org.uk_-_1135253.jpg
  - (4 other plates on the sheet not relied on)

### 64. boxfan - boxfan / landlord plain

- **Priority** 1.49 (gap 1.29, tier lighter_pass, installed 4, review discount 0.6)
- **What we have:** 0.45 x 0.61 x 0.44 m, floor mount, 12564 triangles, 9 surfaces, 0% flat colour
- **Real object:** A second-hand 1920–1927 portable desk or floor electric fan of the Westinghouse/Emerson/GE class: heavy japanned cast-iron base and neck, exposed cylindrical motor can, four broad overlapping blades, deep front and rear wire guards, a carrying handle, a stepped speed switch and a cloth-covered line cord ending in a two-pin plug.
- **Confidence:** medium

The brown paint and the lighter warm blades read as intended, so this is the best-matched finish of the four; what is missing is the wear a furnished-flat fan handled by every tenant would carry, plus the shared faults as juno_black. Object class is right, but the sheet's only fan reference is a dearer Westinghouse and none of the Polar Cub / Star-Rite / Hunter class the variant names appears, hence medium confidence.

**Modelling**

  - As juno_black (shared script): handle onto the motor top, two-cylinder round base, wider three-box blades, hub badge, trunnions at the motor axis. For this variant keep the added badge a plain brass_dull disc and the tilt fixed: the cheapest model had no oscillator and a plain badge.
  - Optional character cut: the cheapest fixed-tilt household fans carried the smallest bases; make the two base cylinders r 0.135 / 0.100 against juno's 0.150 / 0.115 so the landlord's fan reads as the light one of the four, sweep unchanged.

**Texturing**

  - cast_iron tint (0.47, 0.39, 0.31) reads as brown paint over cast, correct in kind but slightly orange in the frame; (0.42, 0.35, 0.28) sits closer to bronze-brown paint. Keep roughness 0.60: cheap paint, not japan.
  - Blade tint (0.42, 0.29, 0.18) on bakelite_black reads as the lighter, warmer blade the variant asks for; no change.
  - metal guard tint (0.48, 0.47, 0.43) is plain unplated steel: correct; keep roughness at 0.8 so it stays duller than Iris's guard.
  - Wear is the gap: the landlord's fan should be the most worn of the four and renders as clean as Juno's. Tint the lower base step (0.30, 0.25, 0.20) for scuffed paint, and add a second BLADE colour constant tinted 10% darker on two of the four blades so the rotor reads re-painted; both stay inside cast_iron and bakelite_black, no new key.

**References used**

  - File:Hardware merchandising March-June 1921 (1921) (14784650333).jpg - No restrictions - https://commons.wikimedia.org/wiki/File:Hardware_merchandising_March-June_1921_(1921)_(14784650333).jpg
  - (3 other plates on the sheet not relied on)

### 65. point_ball - point_ball

- **Priority** 1.48 (gap 1.72, tier leave_alone, installed 1, review discount 1.0)
- **What we have:** 0.03 x 0.03 x 0.03 m, ceiling mount, 24 triangles, 2 surfaces, 100% flat colour
- **Real object:** A paper-wrapped cube of abrasive billiard cue chalk (Spinks or Brunswick-Balke-Collender type, pressed silica and corundum with blue or green pigment, about 22 mm square) left on the wooden rail of the bar's pool table in the Orison's basement Harukiya, where a hand goes before a shot.
- **Confidence:** medium

No reference was available for this specimen, so it is judged against the kind text: the worn dish is built backwards - a 20 x 4 x 20 mm darker slab stands proud of the top face like a lid where a used cube's open face is a shallow concave hollow - and there is no paper wrapper, no rounded corner and no dust on the rail. The object class is right (a blue cue-chalk cube left on the pool-table rail); the cube is 26 mm wide by 22 tall where a Spinks or Brunswick cube is about 22 mm and slightly taller than wide once the wrapper edge counts.

**Modelling**

  - Cube 0.026 x 0.022 x 0.026 to 0.022 x 0.024 x 0.022 m - a 22 mm cube plus the 2 mm the wrapper edge adds to height; the current block is wider than tall, the inverse of the real aspect.
  - Dish: delete the raised 0.020 x 0.004 x 0.020 cap and sink the wear instead - a 0.018 x 0.002 x 0.018 darker box set 1 mm into the top face (top at y 0.024, flush), or for one primitive more a recessed make_cyl 0.008 -> 0.004 x 0.003 cone so the hollow catches its own shadow.
  - Wrapper: a 0.0235 x 0.019 x 0.0235 m box in paper colour around the lower 19 mm, leaving 5 mm of blue exposed at the top; the open face is the working one.
  - Dust: a dia 0.06 x 0.001 disc decal on the rail cap around the cube at alpha 0.35 in the chalk blue - used chalk is never clean, and the cube alone at 22 mm does not read from standing height without it.
  - Corners: at this size accept the sharp cube; the crumbling edge is a texture job (below), not a primitive.

**Texturing**

  - Chalk body: matte - roughness 0.95, albedo (0.16, 0.30, 0.50); no catalog chalk key exists, so either a new key `cue_chalk` (a 128 px pressed-pigment plate) or the flat colour at roughness 0.95; the current roughness 0.6 gives it a plastic sheen in the three_quarter bearing.
  - Wrapper: `paper` (catalog, roughness 0.85) tinted (0.85, 0.82, 0.72) with a darker 3 mm band implying the printed label; no letters (house texture rule), so the maker's name stays unwritten.
  - Dish face: (0.10, 0.18, 0.32) at roughness 1.0 - the dished face is dust, not a glossy lid.
  - Rail dust decal: the chalk blue at alpha 0.35 in the fx family, like `fx_scuff`.

**References used**

  - no reference was relied on; the critique is from the script and the notes

### 66. mail_bank - mail_bank

- **Priority** 1.11 (gap 1.28, tier touched_often, installed 0, review discount 0.6)
- **What we have:** 1.36 x 1.39 x 0.12 m, floor mount, 15350 triangles, 13 surfaces, 46% flat colour
- **Real object:** A surface-mounted apartment-house letter-box bank of the S. H. Couch 1915 pattern: inclined japanned sheet-metal pockets behind one cast-bronze faceplate, long low horizontally swinging tenant leaves on a common concealed hinge, an upper gravity carrier-delivery flap per box, a glass name window and a keyed cylinder on each leaf, the whole set in a wood mounting frame proud of the lobby wall, with a U.S. MAIL header and an outgoing slot; the Cutler Model F is only the receiving box at the foot of a mail chute, not these tenant compartments.
- **Confidence:** medium

The four references are Cutler chute receiving boxes and signs, not the Couch tenant bank, so they anchor only the bronze finish; against that finish the specimen is mostly a material gap - a flat orange-brown surround (flat:#78532f, although the ruling names oak_quartered for it), bright new-gold brass with two tints staggered by index, paper-white cards and flat black pockets - where the Cutler plate reads as dark patinated bronze polished only where hands go. The object class (Couch 1915 apartment-house bank as a 4 x 6 elevation of the building) is ruled and the geometry respects it.

**Modelling**

  - Surround is one 1.36 x 1.39 x 0.05 slab with no frame: a wood mounting frame reads through its rebate - add a 0.04 x 1.39 x 0.02 stile each side and a 1.36 x 0.04 x 0.02 rail top and bottom proud of the panel (4 boxes, merged), and step the array faceplate 6 mm below the frame face.
  - Card windows are quads on the leaf face inside a 0.155 x 0.048 x 0.004 frame; the real name window is glazed and recessed - sink the card 3 mm behind the frame and put a 0.142 x 0.038 x 0.002 alpha-0.25 glass box in front, so the window reads as glass rather than a paper sticker (same fix on the hinged 4B leaf).
  - The outgoing slot plate (0.30 x 0.10 at y 0.60) sits 0.32 m below the array with 0.38 m of blank surround under the grid; raise the surround bottom to y 0.75 (height 1.18) with the slot at y 0.82, or give the apron a purpose - the reference installations put the outgoing slot at the array's edge, not on a blank board.
  - Empty units are 0.268 x 0.09 x 0.018 near-black boxes at Z_BODY that read as holes; an inclined japanned pocket shows a sloping floor - tilt a 0.26 x 0.004 x 0.05 plate 20 degrees inside each of the six (6 boxes, merged) so the gaps read as pockets.
  - Lock cylinders are r 0.011 x 0.012 flat grey discs; add a 0.002 x 0.006 x 0.002 keyway box and a r 0.014 x 0.002 escutcheon ring on each - the lock is the one part every finger polishes.

**Texturing**

  - Surround: flat Color(0.47, 0.325, 0.185) at roughness 0.6 - key it to oak_quartered as the ruling already names, tint (0.55, 0.40, 0.24), so the frame reads as hardwood in the front and high_quarter bearings instead of painted board.
  - T_mailbank_brass at tints 1.0 / 0.72 renders as new gold; the Cutler plate is dark oxidised bronze with bright raised edges - set the base tint to (0.55, 0.42, 0.28) and the dark tint to (0.38, 0.28, 0.18) at metallic 0.55 as now, and assign the bright tint by position (lock rings, leaf bottom edges, the 4B leaf) rather than by atlas_index % 3, which produces a checkerboard, not touch wear.
  - Card material (white, roughness 0.42) is the brightest thing on the wall; cards under glass read (0.86, 0.84, 0.78) at roughness 0.15.
  - Empty pockets use three near-black flats (#0b0a08, #0f0d0a, #17130e); one tint of the brass texture at 0.18 gives them the japanned-steel sheen the reference shows in its recesses.
  - Header lettering stays (authored atlas); match its brass carrier plate to the darkened leaf tint so the plate does not float brighter than the array.

**References used**

  - File:Cutler mail chute letter box.JPG - CC BY-SA 3.0 - https://commons.wikimedia.org/wiki/File:Cutler_mail_chute_letter_box.JPG
  - File:Cutler Mail Chute Co.jpg - CC BY-SA 4.0 - https://commons.wikimedia.org/wiki/File:Cutler_Mail_Chute_Co.jpg
  - File:Disused Cutler mail chute in Clifton, NJ.JPG - CC BY-SA 4.0 - https://commons.wikimedia.org/wiki/File:Disused_Cutler_mail_chute_in_Clifton,_NJ.JPG
  - (1 other plate on the sheet not relied on)

### 67. chandelier - chandelier

- **Priority** 1.05 (gap 1.32, tier leave_alone, installed 1, review discount 1.0)
- **What we have:** 1.23 x 1.24 x 0.72 m, ceiling mount, 37946 triangles, 68 surfaces, 16% flat colour
- **Real object:** A Colonial Revival semi-indirect 'electrolier' of c.1926: a cast-bronze or bronze-finished spelter crown on three chains, an inverted opal or etched glass bowl hung under it, and a ring of candle sockets with flame-tip lamps around the crown, the one expensive fixture an apartment house put in its lobby.
- **Confidence:** medium

The bowl at dia 0.68 m is a third wider than the 350-500 mm opal bowls the 1920s catalogues sold, and because the candle ring sits at r 0.31 inside that bowl's radius the six candles vanish behind it from the lobby floor; the bowl bands share the flame lamps' 1.6x emission and sit inside a 1.2 m additive halo, so in every bearing the glass blows to white and never reads as opal. The object class is right (a Colonial Revival bowl-and-candle electrolier, canopy, three chains, crown, bobeches, straps and finial all present and intact per the in-script ruling); the two usable references (a French Art Deco hung bowl, the 1928 Orpheum candle chandelier) informed the glass and candle read, not the type.

**Modelling**

  - Scale the bowl to dia 0.48 m: multiply the five profile radii (0.340 down to 0.014) by 0.70, move the rim ring from r 0.345 to r 0.245 and the three straps' outer ends from r 0.330 to r 0.235, keep the band heights so the bowl still closes at -0.80; this also brings the bowl inside the r 0.31 candle ring so the candles show from below.
  - Halo quad from 1.2 to 0.7 m: the metalwork spans 0.62 m and the billboard inflates the reported bounds to 1.23 x 1.24 x 0.72 and swallows the candles in the three_quarter bearing.
  - Optional, leave-alone tier: a 12-lobe gadroon on the crown as twelve 0.020 x 0.014 x 0.010 bronze boxes around the -0.434 band; the crown is otherwise plain banding where the kind text expects cast ornament.
  - Nothing else: chains (7 links x 3), bobeches, 0.09 m candle tubes, flame lamps, three straps and the two-part finial are placed as the type is.

**Texturing**

  - Bowl: give the five bulb_bowl_ bands their own material from `milk_glass` (catalog) with emission near 0.8x instead of sharing _bulb_mat at 1.6x with the flames, so the turned profile reads as opal; the flames keep 1.6x.
  - Metal: `bronze` (catalog, metallic 0.75 / roughness 0.62) in place of `brass` for the crown, arms, straps, bobeches and finial - the kind text is bronze-finished spelter - keeping `brass` only for the chain links; the current aged_brass at metallic 0.85 renders as saturated yellow in flat shed light.
  - Patina in the recesses, per the in-script ruling that wear lives in the texture: tint the -0.470 lower crown ring and the collar's lower step to (0.55, 0.48, 0.32) so the antique finish sits where a duster does not reach.
  - Candle tubes: `enamel` tinted ivory (0.92, 0.88, 0.78) is close enough to celluloid; keep.

**References used**

  - File:French Art Deco Wrought Iron and Art Glass Chandelier-1.jpg - CC BY-SA 4.0 - https://commons.wikimedia.org/wiki/File:French_Art_Deco_Wrought_Iron_and_Art_Glass_Chandelier-1.jpg
  - File:Chandelier at Orpheum Theatre, Seattle, ca 1928 (MOHAI 1293).jpg - Public domain - https://commons.wikimedia.org/wiki/File:Chandelier_at_Orpheum_Theatre,_Seattle,_ca_1928_(MOHAI_1293).jpg
  - (4 other plates on the sheet not relied on)

