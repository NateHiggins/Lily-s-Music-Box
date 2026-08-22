# ORISON MODEL 28-R — owner direction (2026-08-22), verbatim

*Radio-Telegram / Electrical Maintenance / Inspection Lamp. Priority major
task: the player's principal physical interface with the Orison, and the
single most obsessively realized functional object in the game. Recorded
here unedited; the build log lives in `art/renders/model_28r/README.md`.*

---

Upgrade the existing placeholder maintenance tool into the single most obsessively realized functional object in the game. This is the player's principal physical interface with the Orison. It should feel like an alternate-1928 technician could genuinely: illuminate a dark boiler room, test a telephone line, measure electrical faults, listen to a wireless signal, send Morse, receive a telegram, diagnose machinery, inspect hidden damage — with it. Only gradually does the player discover that its engineers also designed it to diagnose faults in reality itself.

Do not make a generic steampunk gadget. No gratuitous exposed gears. No random brass. No sci-fi screen. No modern LED language. No arbitrary glowing runes. The object begins with real 1915–1928 electrical, radio, telegraph and flashlight engineering, then diverges along one extremely specific alternate technological history. Its impossible systems should look like technologies that were developed, patented, serviced, repaired and eventually forgotten.

## 1. Core design principle
The player should be able to stare at this object for five minutes and continue discovering: mechanisms, fasteners, markings, wear, movable components, optical behavior, material transitions, evidence of previous repairs, evidence of manufacture, evidence of field servicing, unexplained engineering. The target is not "beautiful hero prop." It is **"a machine with a biography."** Every visible piece must answer at least one question: What does this do? How is it attached? How would it be serviced? What material is it? Why did the engineer choose that material? What touches it during use? Where would it wear? Where would heat accumulate? Where would oil collect? Where would fingers polish it? What could break? What has already been replaced? If a detail cannot answer one of these, reconsider it.

## 2. Historical design DNA
Synthesize rather than copy: **Eveready industrial/focusing flashlight** (elongated durable body, nickel-plated brass, focusing front assembly, silvered reflector, replaceable Mazda lamp, faceted non-rolling bezel, rear service cap, spare bulb storage, mechanical slide switch). **Western Electric lineman's test set** (field-repair seriousness, physical switches, line-test terminals, induction coil, magneto, replaceable batteries, receiver, cloth-insulated leads, service diagrams, utilitarian labeling). **Weston portable electrical meter** (curved analog scale, ivory paper dial, black instrument face, polished glass, needle mechanics, calibration screws, range terminals, precision typography). **1920s crystal radio** (exposed galena detector, glass capsule, cat's-whisker contact, tuning condenser, coils, Fahnestock clips, hard rubber panel, knurled dial). **Morkrum-Kleinschmidt printing telegraph** (solenoids, selector mechanism, tiny type machinery, ink ribbon, paper tape, escapement, electromagnetic clacking, mechanically printed incoming information). The result must appear as if these industries unexpectedly converged around 1926.

## 3. Overall form
Not a pistol. Not a modern rectangular scanner. A distinctive service-instrument silhouette. Length 30–34 cm, width ~9 cm, height ~10–12 cm, apparent weight 1.8–2.4 kg — heavy enough that the player's hand respects it. Industrial flashlight + portable test meter + miniature telegraph laboratory along a strong longitudinal chassis. **Front third**: optical/flashlight assembly. **Middle third**: meter + radio detector + controls. **Rear third**: battery, magneto, service access, telegram mechanism. **Underside**: ergonomic leather/phenolic hand cradle plus deployable maintenance leads. Avoid perfect symmetry: a clear "instrument side" and a clear "service side."

## 4. Primary silhouette
Recognizable in pure black. Five landmarks: (1) large faceted front lamp bezel, (2) arched analog meter housing, (3) glass-covered crystal detector rising slightly from the top, (4) rear cylindrical/rectangular battery-service mass, (5) paper telegram slot and small mechanical appendages. Recognizable lying on a table from across the room.

## 5. Chassis
A genuine internal frame: blackened/japanned brass or phosphor-bronze, with external black phenolic/hard-rubber panels, nickel-plated brass wear components, small exposed brass service fittings, leather hand contact surfaces. NOT one continuous shell: separate plates, countersunk screws, machine screws, washers, captive hardware, backing plates, seams, gaskets, spring clips. Panels have believable thickness; through gaps there is actual darkness/internal hardware, not an empty shell.

## 6. Fastener language
A coherent 1928 vocabulary: slotted machine screws, knurled thumb screws, brass terminal nuts, small rivets, spring clips, cotter/split pins. No Phillips, Torx or modern socket-head bolts. Fastener wear corresponds to service frequency — frequently opened screws have damaged slots, bright exposed metal, circular screwdriver scratches; factory-sealed screws are darker, less damaged, lacquer/patina intact.

## 7. The flashlight
Its own hero assembly. Bezel: large octagonal or subtly faceted non-rolling ring; nickel-plated brass, deep knurling on the focus ring, engraved focus arrows, thick front glass, internal retaining ring, visible gasket. Actual geometry for knurling at hero distance where practical; do not fake the entire bezel with a normal map.

## 8. Flashlight optics
Do not simply spawn a SpotLight3D from the centre. Model the assembly: convex front glass, silvered parabolic reflector, incandescent Mazda bulb, filament, bulb support, ceramic insulation, adjustable focus carriage. The filament is visible when off. Switched on: filament dark → rapidly warms orange → incandescent white-yellow → reflector fills → beam stabilizes. On power loss the filament stays visibly hot for a fraction of a second, falling through amber to dark. This thermal persistence dramatically improves physical credibility.

## 9. Focusing mechanism
Turning the front ring physically moves the bulb or reflector assembly. Do not fake focus solely by changing the spotlight cone angle. Connect ring rotation to carriage translation, beam cone, hotspot size, intensity distribution, and a slight mechanical sound. The player can visually inspect the mechanism moving behind the lens.

## 10. Flashlight beam
A premium beam profile: strong central hotspot, softer corona, slight optical asymmetry, extremely subtle reflector imperfections, faint warm spectral falloff, dust interaction. Not perfectly uniform. At very close wall distance, tiny imperfections in reflector/bulb alignment become visible. Slight chromatic warmth toward centre, cooler low-level scatter at the edge if effective.

## 11. Glass
All glass has thickness, with different responses for: front lens (thick optical), meter window (thin polished instrument), detector capsule (small laboratory enclosure), optional spectral inspection window (special treated). Support Fresnel reflection, roughness variation, microscopic cleaning scratches, dust along frame contact, subtle internal reflection, fingerprints only where physically touched. Do not coat every glass surface in grime.

## 12. The analog meter
One of the most beautiful components. A Weston-inspired arched meter ~55–70 mm wide behind curved glass: ivory dial paper, black radial calibration, hairline needle, tiny mirrored anti-parallax band if appropriate, range labels, mechanical stop, calibration screw, needle pivot jewel. The pointer has real inertia — a critically damped spring simulation: accelerates, slightly overshoots, oscillates microscopically, settles. Different fault types produce distinct needle behaviour. The needle is gameplay animation, not decorative VFX.

## 13. Meter modes
A mechanical selector determines what is measured: `LINE`, `CONT.`, `BATT.`, `FIELD`, `WIRELESS`, `RETURN`. The first four or five seem mundane; `RETURN` is initially unexplained and later becomes one of the most important controls in the game. Selector rotation must rotate actual internal wafer contacts, click through detents, alter meter scale illumination, change audio routing, alter available interactions.

## 14. The crystal detector
A real hero mechanism from galena cat's-whisker detectors. On top: a tiny cylindrical or domed glass housing containing an irregular dark metallic crystal, brass crystal cup, delicate spring-wire contact, ball-and-socket adjustment, knurled micro-adjust screw. The crystal must not look like a fantasy gemstone — start from a galena/metallic mineral specimen, then introduce one tiny impossible property. Ordinary radio: the wire stays mechanically believable. Dream interference: the contact makes tiny movements despite being mechanically locked; later it may occasionally contact a point slightly above the crystal surface. Do not explain this.

## 15. Three-position detector turret
A miniature rotary turret with three detector materials: I ordinary galena; II a pale laboratory crystal; III an unknown dark-violet/gold inclusion material. The first two have mundane diagnostic functions; the third is factory-installed but barely documented. Each position physically moves a different detector beneath the contact — no magic inventory switching; show the machine doing it.

## 16. Radio tuning as physical mechanism
A large ~45 mm tuning dial: dense period scale markings, engraved numbers, knurled circumference, geared reduction, mechanical end stops. Behind the panel the dial physically rotates variable capacitor plates or adjusts inductive coil coupling, glimpsed through a mica/glass inspection window. The dielectric gaps between capacitor plates actually change.

## 17. Internal coils
Lacquered copper wire, black insulating formers, shellacked cloth, fiber washers, brass terminals. Anisotropic/specular behaviour so windings reveal their winding direction under moving light. Hero geometry for large turns; parallax/normal for tightly packed winding; anisotropy aligned with coil direction.

## 18. Radio audio
Analog: RF hiss, atmospheric crackle, distant heterodyne whistles, electrical pops, very faint carrier beat, occasional station bleed. Tuning continuously affects sound; no binary "you found the frequency" — the player tunes through a field.

## 19. Telegraph key
A small fold-out or thumb-operated Morse key: polished lever, ebonite/phenolic finger pad, brass pivots, adjustable contact screws, spring tension screw, visible contact. Pressing moves the lever, compresses the spring, closes visible platinum-like contacts, produces a physical click, keys transmitter/audio. It must feel delightful enough that players press it unnecessarily.

## 20. The telegram printer
The hero mechanical surprise. A miniature electromechanical tape printer in one side/rear portion: narrow paper roll, feed rollers, tiny ink ribbon, type wheel/typebar, selector magnets, pawls, escapement, return spring, paper guide, tear edge. As a telegram arrives: relay clicks → selector moves → type mechanism strikes → paper advances → letters physically appear → tape emerges from the slot. **In world space. Do not substitute UI text for the primary experience.**

## 21. Paper
A real material: warm off-white fiber, subtle translucency, roughness, micro-normal fibers, slightly fuzzy torn edge, uneven ink transfer, occasional embossing from type pressure. Fresh characters slightly darker/wetter initially, tiny irregular ink density, microscopic strike misregistration. The paper physically curls based on how much has exited — a small bone/curve chain or procedural ribbon.

## 22. Telegram typography
Mechanically produced: all-caps period-compatible monospaced/typewriter. Restrained imperfections — occasional vertical misalignment, slight character pressure variation, tiny spacing inconsistency, worn letters, marginal ink spread. Never illegible for aesthetics.

## 23. Optional punched-tape view
Messages may pass through a tiny selector/perforator representation; a maintenance panel could reveal holes, five-unit code logic, star-wheel feed, mechanical sensing fingers. An extraordinary inspection detail; need not be exposed during normal use.

## 24. Line test leads
Two real deployable leads: cloth-braided wire, rubber internal insulation, brass or nickel terminal hardware, small clips/probes, strain relief. The braid gets fuzz, dirt, oil, compression, fraying at high-flex zones — geometry for hero loose fibers at broken regions only. Stowed, they sit in dedicated recesses. Cables do not magically vanish.

## 25. Retractable / stowed service hardware
Every ancillary component has a home: receiver clips to the side, leads wind around two folding cleats, key folds flat, crank folds into a recess, spare bulb in the rear cap, paper roll behind a hinged door, calibration screwdriver beneath a panel. Part of the pleasure is understanding how efficiently engineers packaged it.

## 26. Magneto crank
A folding hand magneto crank from field telephone test sets, normally flush. Deploy: release spring catch → crank rotates outward → handle locks → player spins it. Internally gears rotate, armature spins, meter responds, contacts vibrate, generator whines. Uses: waking dead circuits, continuity testing, charging a capacitor, ringing distant lines, powering the strange inspection circuit without house electricity. One of our best tactile interactions.

## 27. Battery compartment
The rear cap exposes historically plausible dry-cell architecture — no modern batteries: labeled cylindrical cells or battery block, spring contacts, fiber/cardboard wrapper, brass terminals, wax/sealant, service date markings. One cell may have been replaced with an Orison proprietary chemical cell: ceramic/glass vents, dark electrolyte window, brass electrode architecture. This is the technological bridge into the impossible system.

## 28. Spare bulb compartment
A spare incandescent bulb in the rear cap — tiny socket, felt/cardboard cushion, embossed bulb type, glass bulb, visible filament. The player may never need it; model it anyway. This unnecessary correctness is what makes the hero prop believable.

## 29. Ordinary material stack
Distinct identities: nickel-plated brass, exposed brass, black japanned metal, black phenolic/hard rubber, lacquered copper, steel springs, ivory dial paper, optical glass, mica, ceramic, leather, cloth braid, telegram paper, rubber, ink. They cannot share one roughness model.

## 30. Nickel-plated brass shader
Visibly plating over brass. Masks for intact nickel, polished wear, micro-scratches, brass exposure, oxidation, edge wear, fingerprint contact. At frequently handled edges nickel wears through to warmer brass; use curvature and authored wear masks, not universal edge noise. Layer nickel → thin transitional worn plating → brass substrate.

## 31. Brass shader
Nearly full metallic. Roughness by function: frequently touched — smooth, polished, warm; recessed — darkened oxidation; machined — fine directional scratches; cast — subtle irregular grain; engraved recesses — dark grime/wax. Optional very subtle tarnish (brown, olive, near-black). Avoid bright fantasy gold.

## 32. Japanned black metal
Deep black lacquer/enamel over metal: very dark slightly warm body, restrained gloss, subtle orange-peel micro-normal, edge chips revealing metal, fine age crazing in selected regions, tiny grime around hardware. Clearcoat selectively. The lacquer produces beautiful sharp flashlight highlights.

## 33. Phenolic / hard rubber
Not generic plastic: dense dark brown-black base, warm undertone under strong light, molded microtexture, polishing where handled, hairline scratches, slight edge rounding, occasional amber/brown abrasion. Control knobs should look extremely satisfying to touch.

## 34. Leather
Layered construction: vegetable-tanned dark brown, grain normal, compressed high spots, dark sweat/oil absorption, lighter flex cracks, worn edges, stitches, backing layer. Displacement/geometry for major edge thickness and stitching. Do not wallpaper a leather texture over a flat plane.

## 35. Cloth braid
Woven pattern, anisotropic fiber response, dirt embedded between fibers, occasional loose strands, compression at clips. Tessellated/geometry detail sparingly at close-range break points.

## 36. Copper coils
Directionally anisotropic highlights, lacquer clearcoat, slightly reddish copper, darkened aged regions, tiny heat discoloration near terminals, individual winding shadowing. For tight coils: base cylinder + parallax/normal winding + anisotropy tangent around the coil.

## 37. Ceramic insulators
Glazed cream porcelain: high-frequency glaze roughness, tiny pits, subtle crazing, dirty recesses, darker unglazed foot. Valuable because it contrasts with metal, rubber and glass.

## 38. Multiscale detail policy
Every major material gets at least three spatial scales — macro (manufacturing and aging differences), meso (scratches, stains, handling, wear), micro (grain, pores, machining, polish breakup). Avoid one tiling grunge texture controlling everything; use independent maps/frequencies.

## 39. Full PBR map suite
Where appropriate: albedo, normal, detail normal, roughness, metallic, AO, height, emissive, opacity/cutout, clearcoat, anisotropy, wear masks, dirt masks, fingerprint masks, heat masks, Dream-state masks. Pack ORM once stable; keep readable independent maps during development.

## 40. Height / parallax
Where it creates genuine close-view depth without geometry: engraved lettering, shallow machining marks, leather grain, paper emboss, enamel chips, tiny corrosion pits, knurled secondary areas, phenolic molded pattern. Not for features that alter silhouette.

## 41. Detail normals
Independent frequencies: metal — machining microgrooves; glass — almost imperceptible cleaning scratches; phenolic — molded pebble; leather — grain; paper — fibers; paint — orange-peel. Separate UV scale parameters.

## 42. Decals and authored wear
Story-specific: the technician's thumbnail polish below the tuning knob; a screwdriver arc beside the calibration screw; one badly replaced rear screw; a ring of grime around the focus collar; an old adhesive rectangle where an inventory tag was removed; a tiny dent from a drop; worn leather exactly where the thumb rests; blackened brass around the magneto hinge. Avoid procedural "damage everywhere" — wear tells how the object was used.

## 43. Labeling
Plausible manufacturing and service information without clutter. Maker: **ORISON ELECTRICAL & SIGNAL WORKS, LONG ISLAND CITY, N.Y.** Model: **TYPE 28-R**. Also serial number, patent dates, voltage ratings, bulb number, battery number, calibration date, inspector stamp, TELEGRAPH / LINE / WIRELESS, CAUTION labels, a service diagram inside a panel. Use engraving, stamped brass, enamel-filled engraved letters, paper calibration labels, tiny punched inspection marks. Not one decal for all text.

## 44. Serialized object history
Give this specific tool a unique life: manufactured 1928; factory calibration 1928; a major service; a replacement crystal from a different manufacturer; one panel of newer alloy; one screw of the wrong finish; a field-spliced receiver cable; a slightly bent paper door. Add initials or service marks belonging to a previous maintenance worker. Nothing huge. Players who inspect closely should realize other people depended on this machine before them. *(Dates must stay game-consistent.)*

## 45. The impossible circuit
A subsystem that does not belong in ordinary 1928 engineering, packaged with the exact same industrial discipline as everything else. Call it something mundane — `RETURN CIRCUIT`, `SECONDARY FIELD DETECTOR`. Do NOT label it "ELDRITCH MODE." The engineers who built this considered it equipment.

## 46. From Beyond homage — without a reference joke
On `RETURN`: a small cluster of unusual glass detector bulbs inside the chassis wakes. Tiny electrical sputter → rising high-frequency whine → folds into a low nearly silent drone → ordinary lamps dim slightly → detector glass acquires faint violet luminosity → meter needle moves somewhere the printed scale does not reach → the room acquires a second perceptual layer. Do not name Tillinghast. No Cthulhu logo. The knowledgeable player should recognize the lineage, not be elbowed in the ribs.

## 47. The return field
Not "detective vision." Tuned correctly it reveals information **through the flashlight itself**: hidden interference fringes, displaced object outlines, alternate surface normals, traces of Dream contact, geometry visible only in specular response, impossible shadows, latent writing, objects at slightly incorrect depth, faint structures in supposedly empty air. The mundane flashlight becomes an instrument for interrogating reality.

## 48. Spectral inspection
*The Colour out of Space* as a conceptual deep cut. A small optical analyzer: rotating diffraction element, slit, tiny spectral scale, inspection window. Ordinary materials produce recognizable spectral behaviour. Dream material produces a response that does not stay within the visible gradient printed on the instrument. Not rainbow RGB — opponent-colour shifts, localized desaturation, impossible luminance relationships, subtle chromatic aberration, angle-dependent structural colour, scene-colour remapping. The player should struggle to name the apparent colour. Keep it rare.

## 49. The "unknown band"
A tiny region beyond the normal printed meter/spectrum scale. Initially the needle never enters it. Later it does. Not labelled dramatically — perhaps the factory simply printed `R` or `X`, or left it blank. Restraint makes it much more disturbing.

## 50. Dunwich deep cut
Hide the most explicit reference where only obsessive players will find it: inside the battery/service cover, engraved around the inner brass rim, *NEgotium perambulans in tenebris* or a similarly obscure period-appropriate service inscription. Not on the exterior. Alternatively the date or initials of a fictional Orison technician. The exterior remains an industrial tool.

## 51. Impossible galena
The third detector crystal is the visual bridge into the Dream. Normally: dark metallic violet-black mineral, gold inclusions, irregular crystalline fracture. Under RETURN excitation the gold inclusions appear to rearrange microscopically — parallax, animated normal, anisotropic spectral shift, tiny emissive subsurface channels. Do NOT make the whole crystal glow. Its reflections should become more active than its body.

## 52. Impossible internal depth
At extremely close inspection the third crystal can contain a spatial cheat: a fracture plane appears deeper than the physical crystal. Parallax occlusion, nested inner mesh, cubemap/viewport trick, extremely restrained portal representation. The player should not immediately interpret this as "portal" — it simply seems physically wrong.

## 53. Mechanical response to Dream signal
Never communicate supernatural activity solely through glow. The machine responds physically: the meter needle reverses; the cat's whisker lifts from the crystal yet continues receiving; the telegraph selector chatters without printing; tuning capacitor plates move a fraction of a degree by themselves; the magneto crank rotates backward several millimetres; paper advances one character; the receiver diaphragm vibrates; screw heads resonate; a loose cable twitches. Physical effects are more frightening than particles.

## 54. Telegrams from the wrong place
Eventually the printer receives transmissions with no carrier, no connected line, no valid frequency, impossible timestamps, partial typography, repeated characters that become geometry, messages apparently responding to player behaviour. The machine must still print them mechanically: solenoid → type mechanism → ink → paper. That physical chain is important.

## 55. Never a magic tablet
The tool always requires interpretation. The player reads the meter, the sounds, the paper, the light behaviour, the physical responses — never `DREAM ENERGY: 78%`. Maintain analog ambiguity.

## 56. Control tactility
Every major control gets geometry, mass, range, detent, sound, animation, material response: master switch, focus ring, tuning dial, detector turret, mode selector, telegraph key, magneto release, magneto crank, meter zero, line terminals, paper door, service cover. No interaction should simply rotate exactly 90° with a generic click.

## 57. Knob physics
A consistent hierarchy — large tuning knob: heavy, smooth, geared; selector: strong detents; meter zero: tiny delicate adjustment; crystal contact: fine precision screw; flashlight switch: mechanical sliding snap. Distinct audio and animation personalities.

## 58. Hand contact
Context-sensitive contact polish where fingers interact: leather compression, bright phenolic polish, nickel wear, brass exposure, oil residue. Model the grip so fingers appear to belong there; avoid hand clipping. The tool looks excellent both held and placed on a table.

## 59. First-person microanimation
Physical mass, not rigid float. Walking: low amplitude, inertia lag. Turning quickly: chassis lags slightly, hanging lead/strap responds. Operating the crank: the whole unit counters torque. Printing a telegram: tiny impulses propagate into the player's hand. Strong Dream signal: subtle vibration appears before overt supernatural effects.

## 60. Sound design
Individual mechanical families: metal (small brass/nickel clicks), phenolic (hard dull switch contact), paper (feed/scrape/tear), telegraph (relay/selector/type strike), magneto (gear + generator whine), radio (static/heterodyne), flashlight (switch + filament electrical onset), glass (tiny resonances). Identifiable off-screen from sound alone.

## 61. Internal sound transmission
Held, some machine sound behaves as structure-borne vibration: magneto gear noise is not purely world-space. Blend an external mechanical source with a low-frequency hand/body transmitted component. This gives the tool weight.

## 62. Texture resolution
A hero asset: intentional texel density. Exceptional resolution for the front bezel, controls, meter, detector, labels, hand-contact regions, printer; less for internal faces. Trim/tiling materials where sensible, with unique masks for history and wear.

## 63. UV strategy
Separate unique hero UV (labels, authored wear, meter, chips), tiled microdetail (metal scratches, phenolic grain, leather, paper fiber), procedural/world detail (dust, grime modulation), projected decals (service stickers, scratches, repair history). Avoid baking microdetail into low-resolution unique textures.

## 64. Mask architecture
Masks are first-class: `edge_wear` `hand_polish` `oil` `dust` `oxidation` `plating_loss` `paint_chip` `heat` `fingerprints` `engraving_grime` `wetness` `dream_influence` `return_excitation` `unknown_spectrum` `active_current`. Each modulates multiple properties at once — `hand_polish` alters roughness, albedo, plating wear and micro-normal strength together, so wear is physically coherent.

## 65. Active-current material system
Current through selected components manifests subtly — not Tron lines: copper slightly warms, ceramic picks up reflected amber, relay points spark microscopically, coil varnish gains highlight, the filament changes, the detector contact produces a tiny point emission. At extreme Dream excitation these responses become physically impossible.

## 66. Heat
A low-frequency heat state: active components (bulb housing, coils, resistor-like elements, chemical battery) acquire tiny changes in roughness, emission, thermal distortion. Sparingly. No giant heat haze from a hand tool.

## 67. Dust
Dust obeys geometry: accumulates in upward-facing recesses, the meter lip, screw holes, the detector base, unused crevices; absent from hand contact, sliding surfaces, knob rims, frequently opened doors. Operating an old control for the first time may disturb a microscopic amount.

## 68. Oil and grease
Localized on gear teeth, hinge pivots, selector shaft, magneto bearing, printer mechanism: darkened albedo, tighter specular, trapped dust. Function determines texture.

## 69. Corrosion
Not uniform rust. Nickel/brass ages differently from exposed steel screws, copper, spring steel. Steel shows tiny rust at damaged surfaces; brass tarnishes; copper darkens; nickel scratches and wears. Material identity must survive aging.

## 70. Internal reveal
A service hatch the player can open, outrageously detailed: wiring loom, lace cord, coils, terminal boards, relays, capacitors, mechanical printer, battery, calibration marks, handwritten service notation. And one subsystem whose topology does not make engineering sense — a wire leaves one terminal and visually appears to enter another component without traversing the space between. Do this once. Do not make the whole interior Escher.

## 71. Wiring
Period construction: cloth insulation, lacquered wire, lacing, screw terminals, solder joints. No modern PCB language, no green circuit board. Point-to-point, mechanically assembled.

## 72. Solder
Hero joints: irregular meniscus, dull tin/lead appearance, flux staining, hand-soldered variance. One repaired connection clearly newer or rougher.

## 73. Manufacturing marks
Lathe lines, casting seams, stamped numbers, mill marks, punch marks, inspector ink, machining chatter, hand-filed fit on one repair part — emerging only under close flashlight examination.

## 74. Shader debug system
Independent toggles for albedo, roughness, normals, detail normals, AO, metallic, height/parallax, clearcoat, anisotropy, glass, wear masks, dust, oil, corrosion, active current, Dream state, spectral state. Evaluate materials scientifically rather than guessing from the composite.

## 75. Performance
Do not optimize the hero view prematurely, but architect tiers. Held/inspection: full parallax, detail normal, glass, moving internals, high-quality reflection, telegram simulation, spectral effects. Table nearby: reduced microdetail. Distance: simplified shaders and internals. Shadow-only/extreme distance: LOD mesh. Geometry for silhouette; shaders for microstructure.

## 76. Development phases
**1 Historical silhouette** — entirely believable 1928 components, no supernatural effects. Success: it could appear in a museum case without looking fictional. **2 Functional mechanism** — flashlight, focus, meter, selector, tuning, telegraph key, printer, magneto, test leads. Success: the object tells us how it works even without textures. **3 Material masterpiece** — the full multi-material PBR stack. Success: a close-up still frame is convincing enough to photograph. **4 Wear/history** — authored service history. Success: used, not "weathered." **5 Audio/tactility** — every control pleasurable. Success: operating it unnecessarily is fun. **6 RETURN subsystem** — detector turret, strange chemical circuit, violet glass apparatus, impossible crystal, spectral mode. Success: the supernatural appears to be another branch of electrical engineering. **7 Reality inspection** — RETURN connected to Dream materials and environmental diagnostics. Success: the flashlight becomes a way of discovering hidden material/geometry states. **8 Impossible telegram** — the first message from a source that cannot logically be connected. Quietly. No jumpscare. The machine simply starts printing.

## 77. Hero encounter with the Dream tentacle
Aimed at ordinary flesh the meter behaves one way; at gold, another; at the eye the detector becomes unstable; at the hyperdimensional phase edge the spectrum produces a response outside its normal scale. The tentacle notices the device: the eye tracks its beam, cilia react to the radio field, gold structures subtly align with the receiver, the telegram mechanism prints one character. The implication: the machine is not merely detecting the entity — **the entity recognizes the machine.**

## 78. One unforgettable moment
Architecture for a later event: the player is holding the tool. It is switched off. There is no electrical power. No battery connection. The printer mechanism clicks once. Paper advances. One character is mechanically struck. The meter needle moves. Then the flashlight filament begins glowing a dark violet colour even though there is visibly no closed circuit. Nothing else happens. No sting. No monster attack. That moment justifies every hour spent making the machine physically credible. The more real the instrument feels, the more impossible the violation becomes.

## 79. Final art direction rule
Never add weirdness merely because the prop needs visual interest. The mundane engineering should already be fascinating. The supernatural layer earns its power because we have first convinced the player: this machine has screws, batteries, optics, gears, relays, contacts, tolerances and reasons. Then we let one reason fail.

The desired final object: an exquisite alternate-1928 piece of American industrial engineering that begins as a flashlight and technician's instrument, gradually reveals itself as an analog interface for realities human beings were never equipped to perceive, and remains mechanically credible down to the final screw.
