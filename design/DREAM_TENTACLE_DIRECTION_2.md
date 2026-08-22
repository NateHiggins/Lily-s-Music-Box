# DREAM TENTACLE — OWNER DIRECTION 2 (2026-08-22): hero material and anatomy, verbatim

*Supersedes the material and eye sections of `DREAM_TENTACLE_DIRECTION.md`
where they conflict. References supplied with it: (1) macro of wet skin —
dense opaque tissue, droplets and a thin film as a separate specular layer,
fine pores; (2) a cephalopod — pigment cells over structural iridophores,
papillae, a recessed eye under tissue; (3) native gold dendrite in matrix —
crystalline, branching, precipitated from inside its host.*

*Renderer note (Claude): the Orison runs Godot Compatibility/GLES3.
`SSS_STRENGTH`, `SSS_TRANSMITTANCE_*` and clearcoat are Forward+/Mobile
only. BACKLIGHT exists; custom `light()` passes exist. The thickness-driven
scatter, the terminator bloom and the separate moisture lobe are therefore
built in a custom light pass (wrap + transmittance by mask; a second tight
specular lobe for the film), to the same targets.*

---

The biggest correction is stop treating translucency as the thing that makes flesh look fleshy. Too much transmission/refraction produces exactly the clear-gel/gummy-candy look you're trying to escape. Real skin reads as flesh because several phenomena happen simultaneously: a mostly opaque rough surface layer, very shallow subsurface scattering underneath it, fine pore/fold structure, spatially varying oil/wetness, and deeper low-frequency coloration. Oversimplified single-layer scattering tends toward a waxy appearance.

The direction I would lock is dense meat with a microscopic fluid film, rather than translucent purple jelly. Use SSS to soften illumination and create reddish-violet transport principally around thinner/high-curvature areas, while maintaining strong normal information at the surface. Fine pore normals should be a separately tiled detail layer.

For the gold, abandon the idea of regular collars as the dominant treatment. Keep hints of segmentation, but turn the metal into biomineralized anatomy: irregular plates, dendrites, crystalline buttresses and socketed gold bones that have apparently precipitated from inside the flesh. Biological mineralization is matrix-guided crystal growth rather than material coating a surface.

Cephalopods: their appearance comes from several physical structures layered together — pigment cells, reflective iridophores, leucophores, controllable surface papillae. Steal the principle: the purple body gets independent pigment, structural-color, microgeometry and moisture systems.

The priority is now to eliminate anything that reads as: translucent purple gel; rubber; gummy candy; metal painted onto flesh; decorative gold bands; an eyeball stuck onto a tentacle; conventional monster eyelashes.

The target is: dense, pressurized, carnally believable flesh whose surface happens to be purple; living metallic skeletal growth that has biologically mineralized through the organism; and a deeply embedded ocular organ whose anatomy is so coherent and strange that it looks evolved rather than decorated. Favor real geometric structure at silhouette/contact interfaces and shader complexity for sub-surface and microscopic phenomena.

## A. CARNAL FLESH — REBUILD THE MATERIAL MODEL

**A1. Do not make the body transparent.** Overwhelmingly opaque; no general alpha or strong refraction across the body. Subsurface scattering means light enters shallow tissue, diffuses, changes color and exits nearby — not gelatin. Stack: surface oil/moisture over dense epidermal purple over vascular/pigmented tissue over deep almost-black aubergine body mass. The visible surface must retain solidity.

**A2. Multiscale colour.** At least four spatial frequencies. Macro (15–40 cm): aubergine shadows, bruised violet, dark plum, occasional warmer magenta perfusion — corresponding loosely to anatomy and pressure. Meso (2–8 cm): vascular clouds, mottling, pressure discoloration, subtle branching capillary fields, flesh compressed around gold roots; moves extremely subtly with circulation. Micro (mm): pores, shallow creases, follicle pits, tiny raised papillae, minute irregular wrinkles, small scar-like ridges around mineral growth. Submicro: very fine roughness noise to break highlights. Never let procedural noise read as procedural noise.

**A3. Three depth scales of normal information.** Primary anatomical (broad wrinkles, muscular compression, large ridges, sockets around gold, eye-socket folds); secondary tissue (smaller creases, vascular elevation, soft papillae, compressed tissue around suckers); tertiary micro (pores, microscopic relief), tiled independently at high frequency, strength modulated by region, reduced at grazing angles so the skin does not become sandpaper.

**A4. Subsurface scattering must express thickness.** A `flesh_thickness` map/equivalent; not uniform SSS. Maximum scattering at the thin distal tip, raised folds, sucker rims, eyelids, tissue stretched around gold, the membrane interface, thin margins around the eye; minimum at the muscular root, deep folds, thick central mass. SSS colour warm crimson / magenta / deep violet-red, not pink-white: light disappearing into several millimetres of living matter, not shining through silicone.

**A5. Terminator bloom.** At the light/shadow boundary a restrained warm subsurface bleed — burgundy, red-magenta, warm violet surviving slightly into shadow. BACKLIGHT only as a restrained supplement. Never an emissive red rim on the whole silhouette.

**A6. The surface film is not the flesh.** Flesh at moderate roughness; over it an irregular moisture/oil mask giving a second, tighter highlight (clearcoat or equivalent). Wet areas: slightly lower roughness, sharp white glints, albedo darkened very slightly, the finest micro-normal attenuated as if fluid fills the valleys. Concentrated at folds, sucker fields, eye socket, gold interfaces, contact regions. Not uniform gloss; the viewer distinguishes wet surface from soft tissue beneath.

**A7. Pressure.** Hydraulically full. Low-amplitude vertex deformation synchronised to the internal pulse: deep tissue darkens slightly; selected regions expand by millimetres; veins more pronounced; SSS slightly up; roughness changes subtly; gold-root tissue compresses against rigid mineral. Mass moving inside the body.

**A8. Cephalopod-inspired structural skin.** Sparse patches of structural colour beneath the flesh: a masked angle-dependent component — violet, plum, green-gold, copper, rose — like microscopic reflective plates under tissue; never full-spectrum rainbow Fresnel; visible mostly at grazing angles, stretched skin, around the eye, near mineral interfaces, during heightened attention. A sparse papilla system: selected regions raise tiny bumps (normal deformation at distance, low-amplitude vertex deformation close-up). The flesh can subtly change texture while thinking.

## B. REPLACE GOLD COLLARS WITH LIVING BIOMINERALIZATION

Retain some suggestion of segmentation; break the gold into grown mechanical anatomy: gold bone, electrum cartilage, dendritic native-metal growth, crystalline tendon anchors, mechanical osteophytes, jeweled vertebral structures, living armour that grew from tissue — NOT bracelets, rings, paint, steampunk parts attached afterward.

**B1. Three classes of gold.** Structural gold — actual geometry, 3–20 cm plates/struts: skeletal reinforcement, joints, load-bearing ribs, articulated plates, a protective socket around the eye, roots; affects silhouette. Dendritic gold — branching mm-to-cm structures growing outward from structural pieces into flesh, resembling mineral dendrites, vascular systems and neural arborisation at once; roots every structure. Microscopic mineralization — shader/normal/height flecks, seams, crystals, embedded grains around major roots: flesh → mineralizing flesh → crystalline interface → solid gold anatomy. Rarely a clean flesh/gold border.

**B2. Gold must have sockets.** At every root: flesh rises around it; a compressed lip; veins redirect around the socket; tiny branches disappear beneath skin; tension lines; wetness at the boundary; local SSS changes. Gold grew through flesh and forced it to reorganise.

**B3. Mechanically active.** Hero plates have their own transforms: rotate fractionally, slide 1–4 mm, separate from neighbours, reseat, telescope slightly, flex through an organic hinge, lift during a pulse, settle under compression. Real transforms/bones for hero plates; vertex deformation only for microscopic motion. A living skeleton continually making minute corrections.

**B4. Movement has purpose.** Breathing: very slow expansion/contraction. Vein pulse: tiny sequential shifts travelling along the body. Object investigation: distal gold aligns toward the target. Eye attention: orbital gold rearranges by fractions of a degree. Startle: plates lock closer. Relaxation: open slightly. Dream phase event: one component moves in an impossible direction and returns. Gold is body language.

**B5. Crystalline transition structures.** Gem-like mineral organs as punctuation, not a covering: garnet-like prisms, smoky violet crystals, amber-gold faceted nodules, opalescent mineral lenses, crystal wedges between plates. Hero crystals are faceted geometry; halfway between skeleton, sensory organ, gemstone and machine; some carry pulses of light internally.

**B6. Crystal depth without transparency.** Real faceted geometry, strong Fresnel, sharp specular, internal emissive core, dark internal occlusion, angle-dependent colour; optional screen-space refraction for a few hero crystals only, in a separate material. Construction: outer faceted shell + smaller dark/emissive interior mesh.

**B7. Gold surface response.** Near fully metallic; roughness varied — polished pressure ridges, rough crystalline fracture, satin grown surfaces, razor-bright fresh facets; anisotropy along elongated growth; a flow field for crystal-growth direction so the highlight reveals how each structure grew.

**B8. Gold cracks are joints, not lava.** Glowing seams correspond to plate boundaries, growth fronts, articulations, buried channels, crystal interfaces; brighten when a plate moves, dim when it reseats. Emission reveals anatomy and mechanics.

## C. MOVE AND REBUILD THE EYE

Move the major eye substantially closer to the root: begin around 35–50 % of visible extension. Tactile distal appendage; intelligent central/proximal eye; massive root.

**C1. Ensconced.** A real deep ocular socket; the globe recessed substantially; only part exposed. Around it: thick upper flesh mass, lower cushioning fold, lateral muscular folds, compression wrinkles, vascular tissue, wet inner margins, irregular gold skeletal structures. Purple tissue overhangs the globe; strong AO/contact shadow in the orbit; from oblique angles parts of the eye disappear behind flesh.

**C2. Gold orbital skeleton.** Not a clean circular frame: one heavy structural gold brow, several branching supports, crystal wedges, thin gold roots into purple tissue, mechanically active orbital plates; tiny components reposition during tracking. Cradled by living metallic bone.

**C3. The globe.** Layered geometry: eyeball body (opaque wet ivory-gold tissue); iris physically recessed beneath the cornea with real depth; pupil a deep recessed opening with parallax/portal depth; a separate convex corneal bulge (controlled transparency/refraction only here if required); a tear film. The eye may look wet and optically strange; the flesh must not.

**C4. Iris.** Impossible radial anatomy: gold filaments, violet connective tissue, microscopic radial muscles, crystal structures, Byzantine radial ornament, astronomical instrument geometry. Height/normal/parallax for secondary structures; real geometry for several hero radial ridges. Contraction mechanically rearranges elements — never just scaling a black pupil.

**C5. Triple eyelid.** Three independently animated systems in three anatomical directions. Lid A — dorsal flesh lid, heavy, muscular, the primary blink. Lid B — ventral/lateral flesh lid from below and around the side, not mirroring A; together they nearly seal with an alien diagonal seam. Lid C — nictitating sensory membrane sweeping sideways/diagonally across the cornea, thinner, partially translucent, pale violet with microscopic gold vascular filaments, slightly pearlescent, its own muscular leading edge; may close while the outer lids stay open.

**C6. Blink language.** Full blink: cilia respond first; membrane sweeps halfway; dorsal lid descends; ventral/lateral lid rises; all overlap for a fraction; flesh lids open; membrane remains an instant; membrane retracts; pupil reacquires; orbital gold relaxes. Also: membrane-only, partial flesh, asymmetric, very slow three-stage closure when relaxed. Blinking communicates cognition.

## D. ABSURDLY OTHERWORLDLY EYELASHES — orbital cilia

A new sensory organ in the niche of eyelashes: eyelashes + insect antennae + whiskers + gold filigree + crystalline fibres + sensory hairs.

**D1.** 12–30 hero filaments, varied in length, curvature, thickness, material, branching, orientation; some several centimetres; asymmetric around the orbital folds; a spectacular recognisable silhouette that does not conceal the eye.

**D2. Three types.** Flesh filaments (dark violet, flexible, thin, subtle wet highlight); gold filaments (fine metallic, tapering from mineral follicles, like living clock springs / jewellery wire); crystal cilia (sparse faceted needles ending in lens bulbs, gold beads, forked tips, floating droplets; used sparingly).

**D3. Root every lash.** A follicle/socket: tiny purple mound, gold mineral ring on selected follicles, local vascular colour, small AO shadow, root deformation.

**D4. Implementation.** Hero cilia as curve/mesh geometry, 2–4 segments each, procedural spring, independent phase, collision avoidance against eye/lids; secondary cilia as ribbon geometry with alpha scissor/hash; anisotropic specular on gold filaments.

**D5. Sensory.** Cilia notice → eyelids react → eye turns → orbital gold adjusts. Near the player's face the longest bend toward them without contact. Startle: cilia snap inward, lids tighten, gold orbit contracts. Fascination: cilia fan out, pupil expands, gold opens microscopically.

## E. MATERIAL COUPLING

Shared parameters — `attention`, `pulse_phase`, `breath_phase`, `contact_intensity`, `startle`, `dream_phase`, `ocular_focus` — influencing multiple systems at once (attention dilates the pupil, spreads cilia, raises papillae, increases iridescence, shifts orbital plates, intensifies crystal interiors, alters pulse rate). One organism, not twenty effects.

## F. MASK/MAP LIBRARY

`flesh_albedo_macro` `flesh_mottle` `flesh_primary_normal` `flesh_detail_normal` `flesh_pore_normal` `flesh_roughness` `flesh_thickness` `flesh_sss_mask` `flesh_wetness` `flesh_pressure` `vascular_mask` `iridophore_mask` `papilla_mask` `gold_growth_mask` `gold_root_mask` `gold_roughness` `gold_growth_direction` `crystal_mask` `ocular_wetness` `eyelid_thickness` `cilia_distribution`. Readability before packing.

## G. GEOMETRY PRIORITY

Geometry: flesh silhouette, major folds, eye socket, eyeball, eyelids, large gold bones/plates, large dendrites, hero crystals, hero cilia, major veins, contact-deforming suckers. Shader: pores, micro-wrinkles, tiny vascular relief, microscopic crystals, gold grain, fine mineral veins, sub-surface mottling, microscopic papillae at distance.

## H. FIRST DEVELOPMENT VERTICAL SLICE

One 20–30 cm hero patch around the eye first: thick purple flesh; full multiscale skin material; thickness-aware SSS; irregular moisture film; one vascular pulse; one major gold skeletal plate; several dendritic gold roots; one crystal transition organ; recessed eyeball; gold orbital skeleton; three eyelids; 12+ hero orbital cilia; mechanically active gold; angle-dependent structural colouration. Under the encounter flashlight and room lighting. Make it spectacular before propagating down the limb.

## I. ACCEPTANCE TESTS

Flesh test (gold, eye, emission off: heavy, fleshy, vascular, soft, pressurised, moist — not jelly, rubber, wax, silicone, translucent plastic). Gold test (geometry alone: growth, structural purpose, articulation, crystal formation — not accessories). Integration test (at every root: flesh grew around metal or metal through flesh). Eye test (from 45° substantial globe hidden behind real tissue). Blink test (impossible to mistake for a human lid). Cilia test (silhouette alone makes the eye recognisable; sensory anatomy, not makeup). Lighting test (under a moving flashlight, separately: surface oil, micro skin texture, flesh beneath, vascular mass, rigid gold, crystal interior, wet cornea).

## J. FINAL TARGET

Flesh: warm, dense, yielding, hydraulically pressurised living tissue beneath a microscopically wet surface. Gold: rigid living mineral structures shifting underneath and through that flesh like a self-assembling precious-metal skeleton. The eye: the organism evolved substantial anatomy merely to support it — buried in purple muscle, cradled by living gold bone, protected by three incompatible eyelids, surrounded by impossible sensory cilia. Nothing attached. Nothing coated. Everything grown. Its flesh and its gold are two phases of the same impossible biology.
