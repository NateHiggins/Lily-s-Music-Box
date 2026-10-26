# TENTACLE GANG ENCOUNTER — BIOLOGICAL MODEL, OPTICAL SHADER, BEHAVIOR, AND MAINTENANCE-TASK INTEGRATION BRIEF

Evidence class: **INERT**. Owner implementation brief, 2026-10-25; requirements, not runtime or visual acceptance.
## Objective

Create a rare, task-local encounter in which a small “tentacle gang” emerges from the building within physical reach of the player’s current maintenance work.

The organisms should:

1. Spawn near the active maintenance target without blocking required work.
2. Interfere with the object, nearby fittings, and the player’s attention.
3. Behave like curious, coordinated microscopic/deep-sea organisms—not conventional enemies.
4. React continuously to the carried lamp through the existing instantaneous optical field.
5. Retreat only after the player physically touches a tentacle.
6. Collapse dramatically into the floor.
7. Leave a purplish particulate/volumetric haze for several seconds.
8. Release all temporary resources and leave the maintenance task fully recoverable.

Preserve current maintenance, inventory, save, case, NPC, interaction, lamp, and `DreamExposureField` authorities. The encounter is a bounded complication, not a replacement maintenance flow or a new combat system.

---

# 1. Creature concept

The gang consists of one shared buried biological mass expressing three to seven visible tentacle bodies through seams, cracks, drains, wall penetrations, floor joints, or the underside of the maintained apparatus.

They should appear related but individually specialized:

- a sensory scout;
- one or two manipulator limbs;
- a thicker anchoring limb;
- a translucent observation bud;
- smaller ciliary feelers;
- optional branching juvenile structures.

The player initially sees separate organisms. Their coordinated retreat reveals that they belong to one connected subsurface body.

Avoid:

- octopus caricatures;
- rows of humanlike teeth;
- symmetrical monster faces;
- generic spikes;
- constant roaring;
- neon-purple emission;
- simple red hostile targeting;
- tentacles that behave like rigid animated tubes.

The emotional target is intrusive curiosity: they are examining the maintenance process and touching parts they do not understand.

---

# 2. Advanced biological anatomy

## 2.1 External organization

Each major tentacle should contain:

- muscular hydrostat body;
- asymmetric annular segmenting;
- longitudinal ridges;
- wet epithelial membrane;
- sparse chromatophore-like pigment cells;
- ciliary bands;
- sensory papillae;
- small anchoring hooks or adhesive cups;
- visible internal muscle fibers;
- branching conduction structures;
- one or more specialized distal organs.

The tentacle must taper organically, with localized swelling around sensory and muscular structures.

The surface should vary between:

- taut translucent areas;
- thick cloudy ridges;
- soft joint folds;
- wet recessed channels;
- slightly mineralized contact structures;
- bruised purple internal pigment patches.

## 2.2 Rudimentary eyes

Give the scout tentacles primitive ocelli inspired by deep-sea and larval organisms.

Each eye should have:

- translucent corneal blister;
- dark pigment cup;
- crude refractive lens;
- small photosensitive retinal bowl;
- bundled neural fibers exiting toward the conduction network;
- no eyelids in the human sense;
- optional retracting membrane or pigment curtain for protection.

Eyes should not look like miniature human eyes. Their form should be closer to:

- cup eyes;
- pinhole organs;
- translucent photoreceptor bulbs;
- larval ocelli;
- distributed light-sensitive pits.

Some tentacles may have one large ocellus; others may carry clusters of tiny photoreceptive pits.

Behaviorally, the eyes should:

- orient toward the lamp;
- contract pigment under strong direct light;
- become more readable in side light;
- show a faint retinal reflection only at the correct angle;
- lose clarity behind cloudy tissue;
- never glow continuously.

## 2.3 Striated muscle

Model real internal muscle organization rather than using a surface stripe texture.

The muscular hydrostat should include:

- longitudinal muscle bundles;
- circular muscle bands;
- oblique helical fibers;
- localized transverse septa;
- collagen-like connective sheets;
- dense attachment zones near hooks, cups, eyes, and the buried root.

Use visible striation at close range:

- sarcomere-like alternating bands;
- fibers grouped into fascicles;
- slight phase differences between adjacent bundles;
- compression thickening during contraction;
- narrowing and extension when longitudinal groups relax.

The muscle should deform coherently:

- circular contraction lengthens a segment;
- longitudinal contraction shortens and thickens it;
- opposing longitudinal bundles produce bending;
- helical fibers introduce torsion;
- the inner volume should remain approximately conserved.

Do not animate bends solely through a skeleton while leaving interior fibers undeformed. Internal geometry must follow the same deformation field.

## 2.4 Nervous and conduction structures

Include a distributed nervous system:

- paired longitudinal nerve cords;
- small ganglia at segment boundaries;
- sensory branches entering cilia and papillae;
- thicker bundles leading to each ocellus;
- cross-connections forming irregular ladders;
- sparse gold-mineral conduction filaments embedded alongside organic nerves.

The organic nerve tissue should be pale, cloudy, and soft. Gold should appear only as narrow mineral deposits or conductive inclusions.

When one tentacle detects contact, an impulse should propagate visibly—but subtly—through the network toward the common root. Use a brief traveling change in scattering or reflectivity, not a bright electric bolt.

## 2.5 Pressure and buoyancy anatomy

Borrow from deep-sea organisms:

- incompressible fluid chambers;
- small gasless buoyancy vacuoles;
- flexible pressure bladders;
- gelatinous mesoglea-like connective tissue;
- osmotic sacs that swell or flatten during movement;
- collapsible vascular channels.

These structures make the organism look adapted to pressure and constrained spaces rather than air.

Under side or backlight, the viewer should see:

- chambers compressing as the limb grips;
- internal fluid displacement during bends;
- vacuoles changing shape but not volume;
- denser anatomy sinking optically behind cloudy tissue.

## 2.6 Deep-sea sensory structures

Add selected obscure features without making the organism visually incoherent:

- statocyst-like balance vesicle containing one mineral grain;
- lateral-line-inspired pressure pores;
- ampullary electroreceptive pits;
- chemosensory ciliary fans;
- mechanosensory bristles;
- retractable transparent feelers;
- photophore-like organs that are normally non-emissive and used here as reflective or biochemically latent structures;
- polarization-sensitive platelets around the eyes;
- magnetite-like orientation granules;
- small symbiotic colonies visible as cloudy embedded clusters.

A statocyst should visibly respond to orientation: its mineral grain settles inside a translucent chamber while the tentacle bends.

## 2.7 Circulatory and digestive anatomy

Include a rudimentary open circulatory system:

- slow pulsing dorsal channel;
- lateral sinuses;
- branching capillary-like cavities;
- pale fluid carrying suspended cells;
- valves or constrictions near the root.

Optional feeding anatomy on one manipulator:

- retractable rasping pad;
- ciliary intake groove;
- soft proboscis;
- glandular secretion ducts;
- digestive diverticula extending into the limb.

The gang should investigate grease, corrosion, water, heat, electrical vibration, or residue around the maintenance object. It is sampling the environment, not eating the player.

## 2.8 Internal organs at different depths

Each major limb needs at least three depth bands:

- near-surface sensory and muscular anatomy;
- central fluid, nerves, and digestive channels;
- rear muscles, vascular sinuses, and shared-root structures.

Front anatomy must partially occlude rear anatomy. Internal forms cannot be surface decals or uniformly visible transparent meshes.

---

# 3. Modeling requirements

## 3.1 Shared root body

Create a hidden or partially visible root mass below the emergence surface.

It should include:

- fused muscle knots;
- converging nerve cords;
- shared vascular reservoir;
- folded membrane collar;
- branching attachment tendons;
- retractable tissue skirts connecting each tentacle;
- temporary pores that seal during retreat.

The root is the physical explanation for coordinated motion and the final melting collapse.

## 3.2 Tentacle topology

Use deformation-friendly topology:

- dense enough around bends and contact structures;
- longitudinal edge flow aligned with muscle fibers;
- additional loops around ocelli, cups, pores, and folds;
- controlled interior shells or geometry for thickness;
- no paper-thin transparent tube.

Internal organs should use separate meshes or procedural geometry where depth matters.

Provide at least three geometric tiers:

- close hero model;
- normal encounter model;
- retreat/remnant simplification.

Do not hand-edit generated glTF files. Update the proper modeling source and export through the repository’s established asset workflow.

## 3.3 Surface microstructure

Create original authored maps or procedural material inputs for:

- membrane pores;
- shallow epithelial cells;
- wet furrows;
- scarred attachment zones;
- cilia roots;
- chromatophore distribution;
- muscle-fiber direction;
- mineralized gold paths;
- ocellus pigment;
- cloudy internal density.

Any production surface introduced into V2 must satisfy current UV, custom-PBR, and loaded-mipmap requirements.

## 3.4 Contact appendages

Different tentacles should have different contact ends:

- adhesive disk with radial folds;
- two-lobed probing pad;
- ciliary brush;
- soft gripping hook;
- ocellus-bearing blunt tip;
- small branching fingers.

These ends must visibly contact the maintenance object rather than hovering near it.

---

# 4. Optical shader architecture

Use the current instantaneous `LampOpticalVoxelField`, optical material bridge, receiver registry, scene-depth injection, and shared sampling include.

Do not create another light owner.

Do not use `DreamExposureField.G` as instantaneous illumination. Durable ecological exposure may affect coloration or long-term biological state but must remain independent.

All tentacle materials should receive the shared optical sample:

```text
lamp radiance
spectral color
cone visibility
scene/analytic occlusion
transmittance
distance through field
temporal stability
rate of change
world-to-optical transform
```

Use several coordinated shader families:

- wet external membrane;
- cloudy internal tissue;
- muscle and connective tissue;
- eyes and sensory organs;
- nerves and gold conduction filaments;
- haze/remnant material.

Avoid one enormous shader with branches for every organ.

---

# 5. Material behavior

## 5.1 Wet membrane

The outer membrane should combine:

- fine epithelial normal;
- broader fold normal;
- localized wet-film thickness;
- tight grazing highlights;
- rougher bruised or scarred regions;
- restrained direct-facing specular;
- slight opalescent edge separation.

Wetness must pool around:

- folds;
- cups;
- ocelli;
- emergence seams;
- contact points.

It should not look varnished uniformly.

## 5.2 Thickness-dependent transmission

Transmission must respond to real or authored thickness.

Thin tissue:

- transmits more lamp color;
- reveals near-surface fibers;
- produces pearl/cyan/violet edge shifts;
- preserves sharp surface highlights.

Thick tissue:

- becomes milkier;
- absorbs short wavelengths more strongly;
- diffuses the lamp;
- softens deeper organs;
- produces warmer transmitted color.

Do not use alpha as the primary transmission model.

## 5.3 Muscle shader

Muscle must reveal:

- striation under directional light;
- alternating bright/dark fiber bands;
- anisotropic highlights aligned with fascicles;
- darker compressed segments;
- increased scattering in stretched thin areas;
- localized wet connective sheaths.

Striations should bend with muscle direction and deformation. They must not remain in world space or slide across the surface.

Contraction may modulate:

- local fiber density;
- roughness;
- subsurface distance;
- striation frequency slightly;
- vascular compression.

Keep these changes physical and restrained.

## 5.4 Eyes

The eye shader should layer:

- wet corneal interface;
- refractive lens;
- cloudy internal medium;
- pigment cup;
- retina-like scattering bowl;
- angle-dependent retroreflection.

The eye should show:

- a narrow corneal highlight;
- a moving lens distortion;
- a dim retinal return at a precise lamp/view alignment;
- pigment contraction under intense illumination;
- partial loss of clarity behind membrane or haze.

Avoid emissive pupils and full-time eye glow.

## 5.5 Cytoplasm and internal medium

Use organism-local volumetric or pseudo-volumetric density:

- cloudy heterogeneous medium;
- slow suspended granules;
- forward scattering;
- reduced contrast with depth;
- local extinction around dense organs;
- slight advection during deformation.

Noise must remain attached to the organism and should not visibly loop.

## 5.6 Nerves and gold

Organic nerves:

- pale and soft;
- faintly anisotropic;
- more visible in side or backlight;
- briefly change scattering during propagated impulses.

Gold inclusions:

- narrow and discontinuous;
- embedded at varied depths;
- non-emissive;
- dependent on tangent/light/view alignment;
- filtered by overlying tissue;
- almost invisible when misaligned.

A retreat impulse may produce a brief traveling gold glint, but not a glowing network.

## 5.7 Deep-sea structures

Optical behaviors should distinguish structures:

- statocyst: clear chamber with a dense mineral grain and internal lensing;
- pressure bladder: smooth transmission with deformation-dependent thickness;
- electroreceptive pit: dark recessed cup with wet rim;
- chromatophore: pigment expansion changes absorption, not emission;
- polarization platelets: subtle angle-dependent pearl flashes;
- symbiotic colonies: cloudy embedded knots with granular parallax.

---

# 6. Gang behavior

## 6.1 Encounter states

Implement a deterministic, authority-bounded state machine:

```text
DORMANT
→ EMERGING
→ OBSERVING
→ INTERFERING
→ CONTACT_ALARM
→ COORDINATED_RETREAT
→ PURPLE_HAZE
→ CLEARED
```

No combat, health, damage, chase, or hostile targeting is required.

## 6.2 Dormant

Before eligibility:

- no rendered tentacles;
- no particles;
- no collision;
- no audio emitters;
- no lamp receiver registrations;
- no retained root instance.

The maintenance task behaves normally.

## 6.3 Emerging

When the player approaches the active maintenance target:

- subtle seam displacement begins;
- cilia or feelers emerge first;
- a scout eye appears and tests the lamp;
- the shared root presses upward;
- larger tentacles follow;
- nearby dust, moisture, or residue reacts locally.

The emergence should take roughly 1.5–3 seconds and remain interruptible by task or scene teardown.

Do not spawn directly inside the camera, player collider, held item, or required manipulation path.

## 6.4 Observing

The gang studies:

- player position;
- lamp direction and energy;
- current held object;
- active maintenance part;
- motion of nearby mechanisms;
- water, heat, electrical activity, corrosion, or residue if those facts are already exposed by the relevant authority.

Behaviors include:

- scout eye orienting toward the lamp;
- statocyst settling after movement;
- ciliary fans sampling air;
- tentacles mirroring the player’s tool motion;
- small muscle waves passing down limbs;
- one limb bracing while another investigates.

Avoid psychic knowledge. Use real available observations and bounded proximity.

## 6.5 Interfering

The gang may “mess with” the maintenance activity through physical presentation and reversible obstruction:

- curl around a pipe without changing its authoritative state;
- tap a switch or valve housing without operating it;
- steal visual attention by following the tool;
- push loose nonessential debris;
- briefly rest across a reachable surface;
- withdraw from bright direct illumination;
- approach the player’s hand when the lamp moves away;
- imitate repeated mechanical movement;
- cluster around leaks, vibration, grease, or warmth.

It must not:

- complete the repair;
- consume required inventory;
- modify the maintenance task’s authoritative stage;
- operate protected controls;
- delete or permanently relocate required parts;
- block the only route to task completion;
- introduce a parallel minigame.

If a tentacle obstructs a manipulation point, it must move away when approached or be touch-triggerable within the same reachable area.

## 6.6 Touch detection

The retreat trigger must be physical contact with a tentacle.

Acceptable triggers:

- player hand collider contacts the tentacle;
- a currently grabbed object contacts it;
- the direct-manipulation cursor grabs or presses a physically represented tentacle part, if that route obeys the existing interaction contract.

Do not trigger retreat merely from:

- proximity;
- looking at it;
- shooting a ray through it;
- lamp illumination;
- arbitrary button press;
- task completion.

Use a bounded contact owner that reports the real touched tentacle and contact point.

The first valid touch should latch the retreat. Additional contacts during retreat do nothing.

---

# 7. Dramatic retreat

## 7.1 Contact alarm

Immediately after touch:

- contacted tissue compresses at the contact point;
- a muscular recoil travels toward the root;
- nearby eyes retract or pigment over;
- cilia flatten;
- a nerve impulse travels across the gang;
- every tentacle pauses for a fraction of a second;
- the root contracts.

Target duration: approximately 0.25–0.6 seconds.

This anticipation is essential. Do not make the gang disappear instantly.

## 7.2 Coordinated withdrawal

The retreat should feel like melting and suction rather than ordinary reverse animation.

Sequence:

1. Distal ends recoil.
2. Muscle bundles contract in waves.
3. Tentacles lose structural tension.
4. Internal fluid moves toward the root.
5. Limbs flatten into translucent ribbons.
6. Eyes and dense organs sink before the membrane.
7. Gold flashes briefly along retracting conduction paths.
8. The shared root liquefies into the floor seam.
9. Surface folds pull inward.
10. The opening seals with a wet, purplish residue that immediately begins evaporating.

Use geometry deformation and controlled dissolution together.

The dissolve boundary should travel anatomically from distal limbs toward the root. A full-body opacity fade is insufficient.

## 7.3 Floor integration

The disappearance point must be tied to real local geometry:

- floor crack;
- drain;
- wall/floor junction;
- conduit penetration;
- pipe sleeve;
- damaged plaster seam;
- underside of an installed apparatus.

Do not let the creature simply descend through an arbitrary intact surface unless the encounter explicitly creates and reseals a membrane-like pore.

The final surface must return to its original collision and task state.

---

# 8. Purplish haze

After the body vanishes, leave a restrained haze for approximately 3–7 seconds.

The haze should contain:

- low-density purple-violet vapor;
- sparse wet aerosol droplets;
- a few dim particulate inclusions;
- slight pearlescent scattering in the lamp;
- stronger visibility inside the lamp cone;
- natural occlusion by nearby geometry;
- gradual cooling, settling, and disappearance.

It must not be:

- a solid purple sphere;
- emissive smoke;
- screen-space overlay;
- permanent fog-volume ownership;
- a global environmental change.

Suggested phases:

- **0–0.6 s:** dense local exhalation at the retreat seam.
- **0.6–2.5 s:** upward and lateral curl following nearby geometry.
- **2.5–5 s:** sparse suspended droplets and fading violet scatter.
- **5–7 s:** final particles disappear; all haze resources release.

Lamp behavior:

- stable lamp reveals coherent curling layers;
- unstable lamp breaks visibility into brief translucent fragments;
- lamp off leaves only extremely faint ambient visibility;
- occluders must carve the haze.

The haze must unregister from the optical receiver path and free all resources when complete.

---

# 9. Spawn integration with the maintenance task

## 9.1 Eligibility

The encounter may spawn only when:

- a valid maintenance task is active;
- its physical target exists and is loaded;
- the player is within the task’s working region;
- at least one safe emergence anchor is available;
- required task controls remain reachable;
- no incompatible cutscene, save transition, scene teardown, or major interaction owns the player;
- the encounter has not already been consumed according to its explicit lifecycle.

## 9.2 Anchor selection

Maintenance targets should expose or derive candidate anchors:

- target-relative transform;
- surface normal;
- available radius;
- emergence type;
- clearance volume;
- distance to required controls;
- visibility preference;
- allowed tentacle count.

Choose deterministically from valid candidates using task identity, room identity, and encounter seed.

Reject anchors that:

- overlap the player;
- overlap required controls;
- fall behind unloaded geometry;
- intersect door travel;
- intersect the held-object return path;
- lie outside practical reach;
- lack a valid retreat surface.

“Within reach” should mean the player can touch a tentacle from the normal maintenance stance without abandoning the task area.

## 9.3 Maintenance authority boundaries

The encounter can observe task facts but may not own them.

It may read:

- active task ID;
- target transform;
- current task stage;
- authorized visible fault facts;
- manipulation activity;
- task completion or cancellation.

It must not write task progress except through pre-existing physical mechanisms the player actually operates.

If the task completes while the gang remains:

- allow a short observational reaction;
- then retreat automatically only if the specification permits a non-contact cleanup;
- otherwise reposition the touchable scout within reach and wait for actual contact.

If the task aborts, room unloads, or scene tears down:

- perform immediate nonvisual cleanup;
- do not require the dramatic animation;
- retain nothing.

## 9.4 Frequency and persistence

This should be rare enough to remain uncanny.

Persist only the minimum existing contract requires, such as:

- encounter consumed/not consumed;
- deterministic seed, if campaign consistency requires it.

Do not serialize:

- tentacle bone poses;
- haze particles;
- optical textures;
- transient muscle impulses;
- current dissolve state;
- receiver bindings.

On reconstruction, either restore the ruled high-level encounter state or cleanly restart from a permitted state. Never reconstruct half-dissolved geometry from incidental render state.

---

# 10. Audio behavior

Use spatial, source-bound audio:

- wet adhesion release;
- faint ciliary brushing;
- internal fluid pulses;
- soft muscular creaks;
- tiny mineral ticks from statocysts or hooks;
- low pressure-chamber knocks;
- retreat suction;
- brief damp exhalation into haze.

Avoid:

- monster roars;
- human vocalizations;
- musical stingers unrelated to the physical event;
- sounds originating at the camera;
- constant looping slime audio.

Contact alarm audio should propagate from the touched point into the root, followed by the larger retreat sound at the seam.

---

# 11. Required tests

## Spawn and authority

- No active maintenance task produces no gang.
- Valid task and anchor produce a bounded encounter.
- Spawn remains within player reach.
- Spawn does not overlap the player.
- Required maintenance controls remain operable.
- Encounter does not advance or corrupt task state.
- Task cancellation cleans up immediately.
- Room unload retains no encounter resources.
- Deterministic seed and task produce the same valid arrangement.

## Behavior

- Gang progresses from emergence to interference.
- Eyes track the real lamp or player observation.
- Tentacles react to actual manipulation motion.
- Lamp alone does not trigger retreat.
- Proximity alone does not trigger retreat.
- Real physical contact triggers exactly one retreat.
- Contact propagates a coordinated alarm to all limbs.
- The gang cannot re-enter interference after retreat begins.

## Optical response

- Lamp off removes instantaneous optical response.
- Front light reveals membrane and wet microrelief.
- Side light reveals muscle striation and gold alignment.
- Backlight reveals organ depth and pressure chambers.
- Eyes show angle-dependent corneal and retinal responses.
- Gold remains non-emissive.
- Occluding geometry attenuates tentacle and haze response.
- Stable versus unstable light changes temporal readability without changing anatomy.
- Internal structures preserve depth ordering.

## Retreat and haze

- Dissolve travels from limbs toward the shared root.
- Internal organs withdraw before final membrane collapse.
- Collision disables in anatomical retreat order without trapping the player.
- Original task collision and geometry remain intact.
- Haze appears at the real retreat seam.
- Haze persists for the ruled duration.
- Haze responds to the lamp field and scene occlusion.
- Haze fully releases afterward.
- No newly owned texture, RID, particle system, material, audio player, or viewport remains.

---

# 12. Required review packet

Capture identical-camera comparisons:

1. Gang emerging beside a real maintenance target.
2. Front-lit exterior and rudimentary eyes.
3. Side-lit striated muscle, nerves, and gold.
4. Backlit internal anatomy and pressure chambers.
5. Gang physically interfering while controls remain reachable.
6. Exact physical contact frame.
7. Contact-alarm propagation.
8. Mid-retreat anatomical melting.
9. Root disappearing into the floor seam.
10. Purplish haze immediately after retreat.
11. Haze after several seconds.
12. Clean task area after complete teardown.

Also provide:

- stable/unstable lamp comparison;
- lamp-off control;
- occluder control;
- collision/contact visualization;
- anchor-clearance visualization;
- machine-readable lifecycle receipt;
- resource-retention result;
- performance profile.

---

# 13. Acceptance criteria

The result passes only if:

- the gang visibly possesses modeled internal anatomy;
- eyes behave like primitive sensory organs rather than decorative glowing beads;
- striated muscle influences deformation and lighting;
- several internal structures occupy distinct depths;
- lamp direction changes what anatomy can be seen;
- the organisms interfere without stealing maintenance authority;
- the player can physically touch a tentacle from the normal work position;
- only physical contact begins the dramatic retreat;
- the retreat reads as coordinated biological collapse into a real surface;
- the purple haze is volumetric, lamp-responsive, temporary, and cleanly released;
- the maintenance activity remains usable before, during, and after the encounter.

Reject it if the gang is merely animated tubes with transparent materials, if the organs are painted onto the exterior, if the retreat is a uniform opacity fade, or if the haze conceals retained resources or broken task state.
