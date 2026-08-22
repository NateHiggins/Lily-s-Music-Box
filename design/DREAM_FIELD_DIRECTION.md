# THE DREAM FIELD — owner direction (2026-08-22), verbatim

*Major task. The encroachment must stop reading as a ghost overlay and
become the 3-D intersection of the same infinite organism the tentacle
belongs to. Recorded unedited; the build log will live in
`art/renders/dream_field/README.md`.*

---

The encroachment should stop reading as a ghost overlay and become the 3D intersection of the same infinite organism the tentacle belongs to. The tentacle is what happens when the adjacent body deliberately pushes one coherent limb into our space; the encroachment is what happens when the rest of that body passes near our dimensional surface.

The key technical idea: **do not model the encroachment as one shader.** Build it as a stack of three coupled representations of the same procedural field — a volume in the air, a distortion of visible reality, and temporary incarnated anatomy where the field intersects matter.

## 1. Make the master object a world-space higher-dimensional field
A `DreamFieldController` whose real state is not a mesh but a procedural scalar field `F(world_position, dream_w, time, seed)`. Think of `dream_w` as the coordinate along the dimension we cannot see. Instead of translating the field normally through XYZ, frequently advance `dream_w`. The 3-D cross-section therefore changes topology without anything visibly travelling through the room: one lobe divides into three; a ring becomes two disconnected masses; a tendril appears simultaneously on opposite sides of a wall; a hollow becomes solid; an apparent object collapses inward and disappears. That is much more convincing as hyperdimensionality than noise-driven wobbling.

Build `F` from smooth-min/max combinations of capsules, branching tubes, toroids, gyroid-like folds, ellipsoidal flesh masses, vascular filaments, mineral/crystal inclusions. Then domain-warp those shapes slowly using world-space noise.

Explicitly imitate a four-dimensional cross-section: for a simple higher-dimensional lobe the apparent 3-D radius behaves approximately like
`r_visible = sqrt(max(0, r_total² - dream_w²))`
Changing `dream_w` causes the thing to materialize from nothing, expand, contract and disappear **without moving away**. Use that principle throughout.

## 2. Three simultaneous physical representations
`DreamFieldVolume` — what the impossible object does to empty air.
`DreamFieldLens` — what its proximity does to photons / perspective / depth.
`DreamIncarnationSurface` — what happens when it intersects ordinary matter.
All sample the same field coordinates, seed, pulse and `dream_w`, so they read as manifestations of one phenomenon rather than unrelated VFX.

## 3. The air itself should acquire anatomy
Localized `FogVolume`s with a custom fog shader around active lobes. Godot's fog shaders work on volumetric-fog froxels and expose world position, an SDF and density/emission — and density can be **negative**, so the Dream can create both matter-like luminous fog and impossible cavities cut out of ordinary atmosphere. Not purple smoke: extremely structured. Faint violet vascular volumes; gold light channels; dense fleshy clouds only near incarnation; negative-density voids; razor-thin luminous planes; nested halos lasting 200 ms; impossible interior darkness; slowly travelling pressure fronts. A good sequence: normal air → slight optical thickening → crimson volumetric perfusion → gold vascular skeleton appears inside the volume → nearby surfaces incarnate into flesh. The air is becoming embryonic anatomy.

## 4. Reality distortion must be depth-aware, not a screen wobble
A localized screen-space pass. Read the viewport's screen and depth textures; reconstruct world position from depth so you know where the visible scene actually lies in 3-D. Evaluate the field at the reconstructed world position and distort only where `abs(F(world_position)) < influence_radius`, so the effect stays spatially attached as the player moves. Use the mask for a few rare, individually authored violations:
**Refraction without glass** — shift the sampled world behind the field; not watery; different portions bend around different dimensional axes.
**Depth disagreement** — sample a neighbouring location as though geometry were centimetres nearer/farther; for a moment the wallpaper appears deeper than the wall containing it.
**Spatial duplication** — one narrow phase slice gets an offset copy. Never the whole image.
**Wrong parallax** — a localized feature moves *with* the camera rather than against it.
**Spectral edge** — only field boundaries acquire the violet/gold/green interference rim.
**Temporal disagreement** — a small phase region briefly shows a previous transform or alternate phase.
Don't use these simultaneously. **One impossible event is supernatural. Six simultaneous impossible effects are a videogame shader.**

## 5. A CompositorEffect only for the really unfair tricks
`CompositorEffect` can insert custom passes and request resolved colour, depth, normal/roughness and motion vectors — appropriate for advanced localized dimensional tricks, but explicitly experimental, so isolate it behind a feature flag. Reserve it for temporal phase echoes, local motion-vector disagreement, selective depth-space folding, displaced previous-frame anatomy, tiny regions where perspective becomes inconsistent. Call it `DreamPhaseCompositor`, gate it with `DREAM_ADVANCED_PHASE_FX=0/1`, and make the core encroachment work beautifully without it.

## 6. Surfaces should INCARNATE, not become "corrupted"
As the field passes through a wall, radiator, floor, sofa or door, compute its intersection with that surface and progressively replace normal matter with the same biology as the tentacle: dense plum flesh, tissue folds, crimson vascular structures, embedded gold skeletal growth, mineral dendrites, occasional crystalline organs, wetness only in folds and interfaces, pressure displacement, a subtle internal pulse. Do not tint plaster purple. **Low intensity → material transformation. Medium → surface relief. High → actual new anatomy.** That progression is critical.

## 7. World-space shader conversion for the first stage
All Dream-compatible architectural materials share a world-space conversion function. `dream_influence = smoothstep(...)` from the field, transitioning several channels independently: albedo, roughness, normal/detail normal, SSS, emission, metallic, AO, displacement. As the field crosses wallpaper it might produce, in order: burgundy subsurface discoloration → microscopic pores → veins → raised flesh → mineral specks → gold skeletal seams. Because it is evaluated in **world space**, the phenomenon passes continuously across separate meshes rather than restarting at every object's UVs.

## 8. Don't fake the strongest incarnation with displacement
Three incarnation tiers. **Tier 1 shader only** (distant/subtle): coloration, wetness, veins, SSS, shallow normals. **Tier 2 surface growth mesh**: thin meshes conforming to the affected surface — folds, tendons, fleshy plaques, gold dendrites, vein cords — offset along the original normal for genuine self-shadowing and parallax. **Tier 3 full field anatomy**: independent volumetric growth — fleshy lobes protruding centimetres, gold ribs, crystalline joints, tendrils, cavities, embryonic eyes or sensory structures if narratively appropriate — real meshes with their own silhouette. This prevents the environment ever looking like an animated purple decal.

## 9. A `DreamResidueManager`
The field is ephemeral; its interaction with matter has memory. When field strength on a surface crosses a threshold, register a `DreamResidueStamp`: world position, surface normal, radius, field seed, intensity, birth time, `dream_w` at contact, surface/material category. The residue then evolves independently — not one texture trail but **anatomical events**. A wall contact might spawn a broad flesh patch, two branching veins, one gold root. A radiator intersection: flesh between the fins, gold replacing one edge, tiny crystalline nodules. A wooden table: the grain appears to swell, plum flesh emerges through the seams, gold mineral follows the original grain direction. **The Dream should seem to interpret the object's existing structure rather than paste the same effect everywhere.**

## 10. The carnal trail keeps developing after the field leaves
**Phase 1 incarnation** — rapid swelling, wet, warm, strong perfusion. **Phase 2 organization** — veins align, gold mineralizes, crystal organs briefly develop; the material becomes almost *more* structurally coherent after the field has left. **Phase 3 dimensional withdrawal** — instead of dying or rotting it begins leaving our dimensional slice. **Phase 4 absence** — ordinary matter gradually returns, perhaps subtly altered. That delayed biological development tells the player this is not an energy effect. It's anatomy.

## 11. "Evaporating into the nth dimension" is NOT alpha fading
Never `ALPHA -= time`; that says ghost. Make geometry appear to stop intersecting three-dimensional space.
**Cross-sectional collapse** — advance the residue's hidden `dream_w`; components shrink by higher-dimensional slice functions. A flesh lobe can narrow, split, form a ring, collapse to disconnected islands, disappear. It never becomes transparent; it occupies progressively less 3-D volume.
**Anatomical phase peeling** — parts withdraw in an impossible order: the middle disappears before the exterior; a gold root remains floating after the surrounding flesh has gone; a vein becomes a point; a crystal becomes a razor-thin plane, and that plane rotates into zero thickness.
**Dithered final boundary** — if pixels must disappear, use alpha hashing/scissor/dither only in the last few millimetres of phase loss. Solidity is preserved almost until nonexistence.

## 12. Particles are pieces of dimensional anatomy, not sparks
`GPUParticles3D` with custom particle shaders (they can keep state between frames and drive position/rotation/colour procedurally). Spawn only at the phase boundary where incarnated anatomy leaves. Microscopic gold fragments, violet membrane flakes, tiny crystalline facets, capillary filaments, droplets that stretch into lines and vanish, gold beads on impossible curved paths. **Don't have them all move upward** — give them an nth-dimensional vector field: move normal to the surface, curve sideways, suddenly compress toward an invisible plane, reverse apparent depth, vanish without shrinking. A few can move toward the camera in screen space while getting smaller — a tiny perspective contradiction.

## 13. Let material disappear before its shadow — or the reverse
During withdrawal: flesh begins cross-sectional collapse; its ordinary shadow remains another 100–250 ms; gold geometry phases out; an impossible violet "absence shadow" survives; then the shadow collapses toward a point and disappears. Occasionally reverse it. Not every time. The visual system is extremely sensitive to shadow/object synchronization, and breaking it deliberately can feel more uncanny than expensive distortion.

## 14. Couple it directly to the tentacle
Shared globals: `dream_w`, `pulse_phase`, `attention`, `incarnation`, `mineralization`, `vascular_pressure`, `phase_instability`, `contact_activity`. When the tentacle pulses, nearby field anatomy pulses. When its eye becomes attentive, distant lobes orient, crystal facets turn, nearby gold tenses, atmospheric cavities shift. The implication: **the tentacle isn't controlling the encroachment — they are both visible portions of one enormous adjacent organism.**

## 15. A killer visual: the body behind the wall
Occasionally imply a gigantic anatomical structure that cannot fit inside the building. For perhaps half a second: wallpaper becomes thin flesh; the wall bulges; through shallow SSS we perceive a gold structure two metres across; it passes behind several separate rooms simultaneously; their walls react in sequence; then it recedes along `dream_w`; no hole ever exists. The player should realize **the tentacle was never the creature — it was the equivalent of a fingertip.**

## 16. Proposed architecture
`DreamFieldController` (canonical seed/state, `dream_w`, pulse, world anchors) · `DreamFieldSDF` (shared GLSL field functions, world-space evaluation) · `DreamFieldVolume` (FogVolumes / atmospheric incarnation) · `DreamPhaseLens` (depth-aware screen distortion) · `DreamPhaseCompositor` (optional experimental advanced FX) · `DreamSurfaceReceiver` (component marking transformable geometry) · `DreamSurfaceShader` (material incarnation) · `DreamResidueManager` (persistent contact history) · `DreamResiduePatch` (actual carnal surface geometry) · `DreamMineralGrowth` (gold/crystal geometry) · `DreamPhaseEvaporator` (nth-dimensional withdrawal) · `DreamBoundaryParticles` (residue fragments) · `DreamFieldLightRig` (limited moving gold/crimson lights). Critically, all consume one `DreamFieldState` resource.

## 17. Performance strategy
Spatial activation: the controller maintains a handful of active lobes; only receivers within their bounding volumes get live parameters; surface shaders receive only the nearest 4–8 lobes. Pool residue meshes, particles, lights, FogVolumes. Keep only 2–4 dynamic lights on the strongest features and let emission do the rest. The advanced compositor is optional. Quality tiers — **far**: volume + inexpensive screen signature; **medium**: material transformation; **near**: displacement + residue mesh; **hero**: flesh geometry + gold + crystal + full phase effects.

## 18. The art-direction rule, at the top
**The Dream Field is not fog surrounding the antagonist. The Dream Field is the antagonist's infinite body failing to fit into three dimensions.**
Every effect must resemble a consequence of partially intersecting anatomy: volumetric fog = unincarnated tissue; refraction = displaced spatial geometry; purple surface = incarnated flesh; gold = mineralized skeleton; crystal = sensory/structural organ; particles = cross-sectional debris; disappearance = dimensional withdrawal. Never use an effect merely because it looks supernatural. The transformation should read as matter temporarily discovering the anatomy it has in the adjacent dimension — becoming lush purple flesh, living gold bone and crystal machinery — and then **ceasing to intersect our world rather than dissolving.** That gives one coherent physical language connecting the wall encroachment, room corruption, portal effects and fully incarnated tentacle.
