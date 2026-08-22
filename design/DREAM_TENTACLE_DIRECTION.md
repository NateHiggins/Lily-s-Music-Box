# DREAM TENTACLE — OWNER DIRECTION (2026-08-22), verbatim

*This is the governing document for the first on-screen manifestation of
the Orison's primary antagonist. `DREAM_TENTACLE_BRIEF.md` is the concept
brief and the build log; this file is the ruling and is not edited.*

---

You are implementing the first on-screen manifestation of the Orison's primary antagonist in Godot.
This is not allowed to read as "a cool tentacle coming through a wall." It is the player's first direct evidence that the intelligence behind the Dream does not obey the same geometry, material categories, dimensionality, or causality as the building.
The target reaction is:
"I do not understand how I am looking at this, but it may be the most beautiful object I have ever seen."
It should simultaneously feel: sacred, sensual, intelligent, curious, luxurious, biologically convincing, mechanically precise, hyperdimensional, slightly frightening, visually covetable.
The erotic quality should come from beauty, tactility, attentiveness, confidence, and intimate curiosity, not explicit sexual behavior.
Treat this as a hero asset and a systems prototype for later Dream manifestations.

## 1. DESIGN THESIS
The entity is a hyperdimensional intelligence extending only a partial anatomical slice of itself into three-dimensional space.
The visible structure resembles an approximately 1.6 m articulated exploratory limb, superficially suggesting: octopus arm, insect antenna, jeweled reliquary, Byzantine angel, alien machine, living luxury object. But those categories must repeatedly fail.
Build everything around three concurrent design layers:
**Layer A — The Seductive Surveyor.** Its movement is exquisitely deliberate. It investigates objects rather than attacking them. The tip: hovers, trembles subtly, hesitates before contact, samples surfaces, traces edges, performs slow figure-eights, curls around corners, rests briefly against objects, reacts to texture, recoils gracefully when surprised. Its curiosity should feel so attentive that it becomes intimate.
**Layer B — The Reliquary.** Its eye, gold, halos and ornamentation should suggest forbidden sacred machinery. Nothing should look randomly grotesque. Every component should feel composed, intentional and almost ceremonial.
**Layer C — The Geometry Failure.** Repeatedly remind the player that this is not actually a tentacle. It is merely what a higher-dimensional structure looks like when intersecting the room. Use restrained but unmistakable violations of normal geometry. Do not turn this into generic glitch art. The impossibility should feel elegant.

## 2. EXISTING BASE APPEARANCE
Preserve the established color story.
**Flesh.** deep aubergine hollows `#24081F`; bruised violet-magenta body `#6B1640`; rose-violet highlights `#9E3A78`. Plump, slightly translucent, internally pressurized, wet film, strong tight specular response, visible subsurface light transport, slow breathing/plumping, root-to-tip peristaltic motion.
**Gold.** molten gold `#DBA84C`; internal heated cracks `#FF9E2E`. Gold should exist as raised articulation collars, flowing seams, patches, microscopic ornament, internal glowing fractures. It emits warm light. Avoid simple flame flicker. Its illumination should fluctuate as though slices of the luminous structure are moving through another spatial axis.
**Veins.** Three dark crimson raised veins `#80101F`, spiralling loosely; a brighter pressure pulse propagates tipward roughly every 1.5 seconds.
**Suckers.** Two staggered ventral rows, `#C77590`, 1–2 cm. On contact: compress, flatten, brighten around the rim, subtly deform, release sequentially.
**Angel Eye.** ~80 % toward the tip, ~8 cm: pale ivory-gold sclera, complex radial gold iris, deep pupil, fleshy blinking lids. The iris combines Byzantine halo work, astronomical instruments, sunburst reliquaries, microscopic insect optics, stained-glass radial geometry. Around the eye float independent luminous structures: inner gold-bead ring, outer sparse ring, optional third phase structure visible only under certain angles/reflections. The rings are not jewelry attached to the body. They are evidence of surrounding geometry the player cannot completely perceive.

## 3. REBUILD THE SILHOUETTE SO IT IS NOT JUST A TUBE
Controlled variation along the length. Example profile: muscular root, slightly compressed section, rounded segment, ribbed section, subtly flattened ribbon-like span, articulated narrowing section, fine distal limb, rounded sensory club. The cross-section itself rotates and deforms along the spline. Readable from a distance, rewards close inspection. Implement at least some of: collars hovering a few millimetres above flesh; discontinuous phase-offset slices; locally flattened anatomy; asymmetrical swellings; convex/concave transitions; subtle torsion; segments that visually misalign for brief intervals. Do not use random noise everywhere. Strong intentional rhythm.

## 4. ACTUAL GEOMETRY VS SHADER DETAIL
Geometry for silhouette, deformation, major volume, eye, suckers near interaction zones, gold collars, large protruding veins, membrane emergence. Shader for pores, micro-folds, wetness, fine cracking, gold filigree, tiny vein relief, micro-suckers if distant, subsurface mottling, surface ripple, phase shimmer. Fidelity hierarchy: microstructure → normal/detail normal; shallow relief → height/parallax; regional material changes → masks; deep volume/silhouette → geometry. LOD or distance-based shader controls if necessary.

## 5. MATERIAL SYSTEM
Not one monolithic opaque shader. A reusable modular Dream material architecture with clear parameters and masks. Support: albedo, normal, detail normal, ORM, height/parallax, emission, subsurface approximation, Fresnel, clearcoat/wetness, flow mapping, distortion/refraction, triplanar/world-space noise, layered material-state masks. Mask channels at minimum: flesh wetness, gold coverage, heated gold cracks, vein pulse, subsurface intensity, phase instability, iridescent rim, contact activity, transformed/corrupted surface, microdetail variation. Avoid visible texture repetition.

## 6. FLESH SHADER
Soft, dense, alive — not purple rubber. Macro deformation along the spline coordinate (breathing, low-amplitude muscular compression, peristaltic waves; restrained). Microstructure at two scales (soft tissue folds; tiny skin microdetail), readable under the flashlight at close range. Wet film: controlled high-frequency specular highlights pooling around sucker bases, folds, eyelids, gold/flesh boundaries; never uniformly maxed. Subsurface: thin regions glow when backlit — tip, sucker rims, eyelids, ridges.

## 7. GOLD SYSTEM
Not paint: a second material state fighting the flesh for the same anatomy. Slow directional flow, emissive internal cracks, tiny raised/indented decorative detail, dynamic heat variation, strong metallic response, convincing reflections, slight surface movement. At close range, microscopic moving ornament: filigree, tessellation, clockwork engraving, religious metalwork. Not generic lava. Unmistakably precious metal.

## 8. THE HALO/EYE SYSTEM
The eye is a principal focal point. Eye state machine: closed during early emergence; partial opening; watches contacted object; briefly explores room; locks onto player when appropriate; pupil dilation follows attention/interest; occasional slow blink. No constant twitching; calm. Halos with independent transforms: inner ring smooth ceremonial rotation; outer ring very slow with tiny discontinuous angular jumps; phase ring only partially visible through reflection, Fresnel angle, phase events, occluded view, selected lighting. Not game-VFX circles: particulate structure and depth.

## 9. SIGNATURE HYPERDIMENSIONAL EFFECTS
A small number done extremely well. The first encounter supports at least two.
**A. Reflection Disagreement.** In reflective surfaces the reflection does not match the limb: additional eyes, additional rings, longer anatomy, altered pose, larger scale, different segmentation, impossible continuation outside the room. Subtle enough that some players doubt it. Architect so reflections can expose alternate Dream-state representations.
**B. Phase Slices.** Masked portions of the limb briefly render from a slightly different temporal/spatial pose. Never the whole object. A narrow anatomical section "belongs to another frame" momentarily, blended carefully — a 3-D cross-section changing because it moved through a fourth axis.
**C. Impossible Occlusion.** Optional, sparing: a small section faintly visible when depth says hidden — ghost slice, gold outline, iridescent echo. Do not destroy readability.
**D. Impossible Twist.** During selected curls the ventral sucker surface becomes dorsal without the physical twist required. Rig/UV/material sleight-of-hand, not broken deformation.

## 10. THE INTERIOR IS BIGGER THAN THE EXTERIOR
One controlled glimpse that the organism contains a volume impossible for its exterior. Triggers: membrane stretching around the emerging tip; flesh separating near a gold seam; pupil expanding deeply; a sucker dilating. Inside — no gore: immense violet-gold space, recursive anatomy, distant rotating rings, luminous vascular architecture, cathedral-scale structures, impossible tessellated chambers, distant lights suggesting greater anatomy. Long enough to recognise it cannot fit. A reusable "impossible interior" shader/portal technique if practical.

## 11. WALL EMERGENCE
Not a hole. The Dream encroachment on the wall becomes a soft violet membrane: tension increases; surface bulges; internal gold light through the membrane; rounded tip presses outward; membrane stretches semi-translucent; tip pushes through; membrane clings around the root; the opening never becomes an empty hole. The building has temporarily adopted the entity's biology. Animated normals, vertex displacement, tension masks, translucency, local stretching, wet specularity, gold backlighting. No gore. Birth, portal, flower, bubble membrane, dimensional extrusion at once.

## 12. MOVEMENT RIG
Spline/IK-driven. ~1.6 m reach; root constrained near emergence; procedural follow-through; controllable distal curl; independent tip tremor; eye orientation independent of limb; local peristaltic displacement; collision/contact awareness; scripted poses for cinematics; procedural investigation. Hierarchy: root heavy, slow; midsection fluid, muscular; final third dexterous; tip extremely precise. Tremor ~5–7 Hz, low amplitude, when sampling, not on the whole limb.

## 13. BEHAVIOR STATE MACHINE
Explicit states: `DORMANT` `MEMBRANE_BULGE` `EMERGING` `ORIENTING` `SEEKING` `APPROACHING` `HOVER_INSPECTION` `TOUCHING` `CARESSING` `TASTING` `WATCH_PLAYER` `FLINCH` `RESUME` `WITHDRAW`. Data-driven transitions. Targets world objects marked interesting, with metadata: preferred contact point, edge/path to trace, target material, response strength, transformation eligibility.

## 14. CONTACT SYSTEM
Not a decal. A reusable Dream Contact / Material Conversion System: touched matter appears invited into the Dream. Contact alters albedo, roughness, metallic, normal, emission, microdetail, subsurface, local displacement. Example: behind the tip on a cast-iron radiator, ordinary paint becomes luxurious violet lacquer, gold-veined enamel, softly luminous, subtly breathing, ornamented with microscopic structures. Spreads centimetres beyond contact, then remains, recedes, or keeps crawling. Mask-driven, for arbitrary compatible surfaces.

## 15. DREAM CONTACT PHILOSOPHY
Not mold, slime, infection, rot, demonic corruption. The Dream does not ruin matter; it reveals a more extravagant state matter could occupy. Touched surfaces become less ordinary, more alive, more luxurious, more geometrically sophisticated, slightly impossible. The unsettling implication: the transformation may be an improvement.

## 16. SUCKER CONTACT
Distal suckers orient to the surface; first contact compresses the dome; rim flattens; rim emits soft pink light; neighbours engage sequentially; tiny sliding; release propagates backward. Hero suckers on the distal third if full simulation is too expensive. Normals and contact orientation influence compression.

## 17. OBJECT INVESTIGATION
One polished sequence first (radiator or another detailed object): notices; eye looks; tip pivots; approach slows inside 10 cm; hovers; tremor; first sucker contact; eye observes contact; tip traces the rim; gold light across the object; Dream conversion follows; rests; player movement attracts the eye; proximity causes restrained flinch; curiosity overcomes fear; resumes. Intelligence without dialogue.

## 18. PLAYER RESPONSE
Curious, not hostile. Zones: Far (ignores unless in field of interest); Near (eye periodically watches); Arm's reach (pauses; slight contraction; distal curl; eye locks; halos shift; may resume). Rushing: quick elegant recoil, tighter coil, sustained observation. No monster-combat language. Something studying the player.

## 19. LIGHTING
Alters the room's lighting: molten gold, heated cracks, halo, eye, sucker contact, transformed material; warm local light against the darker palette, moving across furniture with the limb. A strange flicker — not noise: luminous slices appearing/disappearing as higher-dimensional geometry intersects the room; several overlapping frequencies or spatial masks.

## 20. SHADOWS
Prototype an "absence shadow": ordinary shadowing plus a second softer phenomenon — local light suppression, chromatic shadow, impossible offset shadow, a shadow that briefly leads motion. Subtle; noticed subconsciously first.

## 21. IRIDESCENT PHASE EDGE
Thin Fresnel rim of violet, green, gold, rose, spectral tones. Not gamer RGB; constrained saturation and width. Colour from dimensional interference, not pigment.

## 22. SOUND DESIGN HOOKS
Events: membrane strain, emergence, eye opening, vein pulse, gold phase shift, halo phase, sucker attach, sucker release, surface caress, Dream conversion, player attention, flinch, impossible-space event, withdrawal. Vocabulary: wet silk tension, microscopic suction, bowed crystal, glass harmonics, resonant gold chimes, very low heartbeat/sub pressure, breath-like harmonic layers, spatially displaced whispers without language. One layer may be spatially inconsistent with the visual source.

## 23. FIRST REVEAL STAGING
Beat 1 something is wrong (moving gold reflection; violet breathing in the wall; impossible reflected movement). Beat 2 presence before body (halo fragment; shadow; membrane pulses; gold light travelling under the wall). Beat 3 emergence (tip through membrane; eye hidden). Beat 4 recognition. Beat 5 category failure (first impossible effect, e.g. reflection longer than the limb). Beat 6 the eye opens — the iconographic hero moment, given space. Beat 7 caress and material transformation. Beat 8 attention (eye to player; halo response; no attack). Beat 9 mutual uncertainty (player approaches; flinch; then decides the player is interesting).

## 24. PERFORMANCE ARCHITECTURE
Tiers: always-on inexpensive (base materials, spline animation, eye tracking, simple emission, primary normals); near-camera (detail normal, advanced wetness, per-sucker response, parallax, filigree, subsurface); event-triggered expensive (impossible interior, phase slices, alternate reflection, contact conversion spread, distortion). Feature toggles. No full-screen effects where a localised shader/mesh/viewport will do.

## 25. DEBUGGING TOOLS
A developer panel to enable/disable and tune independently: breathing, peristalsis, vein pulse, gold flow, gold emission, eye tracking, halos, suckers, contact deformation, surface conversion, iridescent rim, phase slice, reflection disagreement, impossible interior, membrane, contact target visualisation, spline/IK bones, collision, LOD state; amplitude/speed parameters.

## 26. IMPLEMENTATION PHASES
Build vertically. **Phase 1** hero silhouette (spline/rig architecture, base mesh, articulated segmentation, collars, eye location, major suckers, membrane root; success: the untextured silhouette is graceful and unusual). **Phase 2** baseline animation (emergence, seek, approach, hover, caress, recoil, withdrawal, peristalsis, tip tremor; success: in gray the creature feels intelligent). **Phase 3** flesh/gold material stack (flesh, wet film, subsurface, gold, emissive cracks, veins, pulse, iridescent edge; success: compelling under flashlight and room light). **Phase 4** eye and halo (tracking, blinking, pupil, 3-D iris, independent rings; success: the eye feels intelligent). **Phase 5** contact mechanics (targeting, surface following, sucker response, figure-eight caress, edge curling; success: inspects one radiator/sofa without clipping or robotic motion). **Phase 6** material conversion (touch mask propagation, violet/gold transformed state, emissive/normal/roughness transition, persistence; success: seductively re-authored, not slimed). **Phase 7** hyperdimensional signature (reflection disagreement, phase slices; optional impossible interior; success: no longer explicable as conventional 3-D animation). **Phase 8** encounter staging. **Phase 9** audio integration. **Phase 10** optimisation and reusable library extraction.

## 27. CODE/ASSET ORGANIZATION
`DreamTentacleController` `DreamTentacleRig` `DreamTentacleBehavior` `DreamTentacleEye` `DreamHaloController` `DreamSuckerController` `DreamContactSensor` `DreamSurfaceTransformer` `DreamMembrane` `DreamPhaseRenderer` `DreamReflectionVariant` `DreamInteriorPortal` `DreamMaterialProfile` `DreamContactProfile` `DreamTargetProfile`. Resources for tunable profiles; low hard dependencies.

## 28. ACCEPTANCE TESTS
Silhouette test (paused, untextured: distinctive?). Motion test (gray: intelligence, curiosity, sensitivity, confidence?). Material test (frozen: close-up compelling?). Eye test (alone: meaningful attention?). Contact test (gold muted: exploration still legible?). Hyperdimensional test (unexplained viewer notices the impossible?). Beauty test (architecture richer, not damaged?). Restraint test (effects fighting? simplify).

## 29. NON-NEGOTIABLE ART DIRECTION
No generic Lovecraft tentacle, purple slime, generic eldritch corruption, noisy RGB glitching, lava-shader gold, hologram look, random procedural wobble, constant twitching, excessive particles, "more detail = better", every effect at once. Composed. Beauty is part of the horror. Elegance is part of the impossibility. Restraint makes the violations more powerful.

## 30. FINAL EXPERIENCE TARGET
"What is that?" → "It's looking at that radiator." → "It's touching it." → "Why is that beautiful?" → "Wait. Its reflection is wrong." → "That space cannot possibly fit inside it." → the eye notices the player, and instead of attacking, it hesitates. It is deciding what we are.
The supernatural is not uglier than reality. It is impossibly, seductively more elaborate.
