# RENDERER DECISION OVERRIDE — FORWARD+ IS CANONICAL (owner, 2026-08-22)

*Third and governing direction for the Dream tentacle. Supersedes the
renderer constraint in `DREAM_TENTACLE_DIRECTION.md` and
`DREAM_TENTACLE_DIRECTION_2.md`; the material and anatomy rulings in
DIRECTION_2 stand and are now implemented with real Forward+ features
instead of approximations.*

Disregard the previous instruction to preserve Compatibility as the visual
target. We are optimizing first for the best possible Orison image, then for
performance and fallback compatibility afterward. Move the project to
Forward+ and treat the existing Compatibility implementation as a preserved
historical/fallback branch, not a constraint on the new art direction. Do
not compromise the Dream Tentacle because an older renderer cannot reproduce
it.

## 0. Preserve before migration
Commit/tag the current known-good Compatibility state; preserve all existing
tests; capture baseline screenshots of the important Orison spaces; record
representative frametimes; preserve the current tentacle shader rather than
destructively replacing it. Then migrate. During development, make it
obvious if Godot silently falls back to Compatibility on unsupported
hardware — I do not want us visually evaluating a Forward+ feature while
unknowingly looking at the fallback renderer. Do not begin by spending days
making every existing Orison material pixel-identical. First: switch
renderer, repair anything actually broken, establish a reasonable global
lighting baseline, immediately return to the Dream Tentacle hero patch. The
encounter is the renderer migration's reference-quality vertical slice.

## The new target
The viewer should perceive the material hierarchy in this order: **living
flesh → blood volume → wet film → metallic skeleton → crystal organ →
recessed eye.** Each needs a distinct optical behaviour. Nothing should
collapse into "purple translucent shader with gold stuff."

## A. Real subsurface flesh
`render_mode sss_mode_skin`, driving `SSS_STRENGTH`,
`SSS_TRANSMITTANCE_COLOR`, `SSS_TRANSMITTANCE_DEPTH`,
`SSS_TRANSMITTANCE_BOOST` — not rim lighting pretending to be transport.
But not human skin: a deliberately alien tissue model. **Macro dermis**:
broad purple/wine flesh with genuine volumetric-looking colour variation;
thick regions dark plum / almost black-red with low transmitted light; thin
regions crimson, fuchsia-red, occasional hot internal magenta under strong
illumination. The flashlight moving around the object should radically
change what can be seen inside it. **Mesostructure** beneath the skin:
vascular branching, fibrous cords, muscle-like striation, denser nodules,
tissue compartments — revealed because light travels through surrounding
tissue, not tattooed on the albedo. **Microstructure**: pores, minute
ridges, fine creases, puckering near embedded structures, stretched and
compressed areas, microscopic directional fibre; normals, roughness, SSS and
albedo driven at different frequencies so it is not one noise texture reused
six ways.

## B. Thickness must matter
A usable thickness representation for the hero region: the flashlight
exposes anatomy by local depth. An eyelid must not scatter like the muscular
root; a stretched membrane must not scatter like a dense fold. Around
eyelids, cilia follicles, gold penetration sites, thin membranes and sucker
margins, increase transmitted red. Deep muscular flesh swallows light. Avoid
an omnipresent red glow — if every edge glows, we have failed.

## C. Wetness is a second material system
A genuine wet-film response on the tighter secondary specular/clearcoat
layer rather than "wet" baked into base roughness. Irregular distribution:
stretched smears, tiny beads, nearly dry islands, fluid gathering in creases,
extra moisture around eyelids and sockets, directional streaking from
movement. A separate high-frequency film normal; when the limb flexes the
broad flesh normal and the microscopic fluid normal must not move
identically. Under the flashlight, light scattering *through* flesh must be
distinguishable from light reflecting *off* liquid sitting on flesh.

## D. Make the blood actually move
One prominent vascular structure in the hero patch with a slow hydraulic
pulse — not a glowing stripe. It propagates through several properties: tiny
vessel dilation, slight local displacement, darker pooled blood immediately
before/after, changed SSS/transmittance, minute wet-film distortion above it.
The realization to produce: *something beneath this skin has pressure.* The
pulse must not synchronize with the limb motion, blink, crystals or gold —
multiple biological clocks.

## E. Gold is internal anatomy
Mineralized biomechanical skeleton; nothing resembling decorative rings
around a tube. It enters and exits flesh unpredictably, disappears beneath
tissue, branches into dendritic supports, forms sockets, hinges, partial
ribs, ligament attachment points, carries the crystal organ, mechanically
supports the eye. True metallic behaviour, roughness varied at several
scales: polished contact surfaces, worn edges, crystalline grain, rough
fracture interiors. Gold emerging from tissue deforms the tissue: raised
scar ridges, stretched dermis, vascular concentration, folds caught beneath
plate edges. In several places purple tissue grows back over the metal, so
it cannot be read as armour attached afterward.

## F. Gold must move
Selected structural pieces get extremely small autonomous mechanical motion.
Neighbouring plates separate by fractions of a millimetre during a
contraction; a socket tightens around the crystal when the eye focuses;
dendritic struts change tension; one overlapping plate slides beneath
another; orbital gold contracts fractionally during a blink. Amplitudes
tiny — the horror is realizing it moved at all.

## G. Crystal organ
One hero crystalline organ near the orbit, reading deep tissue → mineral
root → gold socket → crystal growth. Asymmetric growth, internal fracture
planes, inclusions, imperfect transparency, local coloration from
surrounding tissue, internal optical depth, small secondary growths. It
should occasionally produce an astonishing glint or internal optical event
when the flashlight crosses the correct angle — occasionally, not
continuously. We want discovery.

## H. Completely rebuild the eye socket
An organ embedded in a headless organism, not an eyeball mounted on a hose.
Sink the majority of the globe; the complete sphere must never be
inferable. Orbital flesh: thick purple tissue with folds, compression,
stretched vascular areas, wet inner margins. Orbital gold skeleton:
asymmetric internal framework cradling the globe, anchoring the three lids,
holding cilia sockets, connecting to deeper gold, partially hidden beneath
tissue — halfway between vertebrate orbit, arthropod mouthparts, camera
iris, mineral skeleton, and anatomy from a universe with different
evolutionary constraints; not a copy of any one.

## I. Three lids that could not have evolved here
Real geometry and thickness. Lid A sweeps obliquely; lid B twists partially
around the orbital circumference; the third translucent membrane traverses
on another vector. The blink looks mechanically impossible while appearing
anatomically inevitable. Each lid: wet internal margin, thickness, local
translucency, vascularity, tiny compression when closed, independent timing.
During tracking: cilia react → orbital gold tenses → lids make a minute
anticipatory adjustment → globe moves → surrounding flesh catches up.

## J. Cilia
At least 12 hero cilia from visible biological/mineral follicles; not human
eyelashes. Vary length, curvature, stiffness, thickness, orientation,
colour: some lashes, some whiskers, some insect sensory hairs, some with
gold or crystalline bases. Delayed secondary motion; several detect and
respond before the eye reacts.

## K. Use Forward+ to make the encounter better
Audit what Forward+ gives: TAA, higher-precision HDR, normal/roughness
buffer access, compute shaders, decals, particle trails, depth-aware post,
screen-space processing. Every feature must serve the image; no checklist
graphics programming. Investigate whether depth/normal information can make
an extremely subtle local reality disturbance around the limb — not heat
haze, not chromatic aberration, but nearby geometry appearing microscopically
inconsistent when viewed across the creature: invisible when frozen,
disturbing in motion. Its presence should occasionally make the renderer
seem uncertain about ordinary Euclidean space.

## L. The flashlight is the reveal mechanism
An interactive anatomical scanner. One angle: wet purple flesh. Another:
blood-filled thin membrane. Another: a gold structure appears beneath
tissue. Another: a crystal catches light internally. Another: the recessed
eye becomes disturbingly deep. Author specifically around moving local
illumination. Excellent under ambient; impossible under the flashlight.

## M. Control bloom
HDR is permission for range, not neon soup. Gold glints and crystal
highlights may spike; wet film catches tiny highlights; tissue saturates
under transmission — but the dominant flesh stays substantial. Preserve
black levels, occlusion and weight. Darkness is where the optical phenomena
happen.

## N. Art direction test — hero patch only
Finish the 20–30 cm region around the eye as if it were the entire game, and
photograph it under: direct flashlight; slow grazing flashlight;
backlighting through thin tissue; dim ambient; extreme macro; gameplay
distance; direct eye contact; lateral tracking; a full three-lid blink;
cilia reaction; vascular pulse; gold articulation; crystal at a favourable
angle; everything at once. Then one slow 10–15 s continuous flashlight sweep
across the patch — that sweep is the review asset.

## O. Success criterion
Gameplay distance: "What the fuck is that?" Closer: "Wait — the gold is
underneath the skin." Closer: "Wait — the gold moved." Closer: "Those are
blood vessels." Then: "Oh Jesus, that thing around the eye is bone." Then
the eye focuses on the player. Then one cilium touches the flashlight
housing. Do not optimize it back into sanity before we have seen the correct
version. Correct image first, performance second, compatibility fallback
much later. Build the impossible version.

*HDR headroom is a stated reason for the move: Compatibility outputs
RGBA8, Forward+ RGBA16F, so crystal, wet highlights, gold and transmitted
tissue can carry genuinely violent local brightness without lifting the
whole creature toward glowing jelly. The old renderer build is kept as a
future optimization target: once the canonical version exists, ask how much
of the perception can be preserved cheaply.*

---

## Migration record (Claude, 2026-08-22)

- Compatibility state committed and tagged **`compat-renderer-final`**
  (`29ca673`) before any renderer change; the Compatibility-era tentacle
  shader and its frames are preserved in that commit and in
  `art/renders/dream_tentacle/wip1/`.
- Baselines: `art/renders/renderer_migration/compat_baseline/` and
  `.../forward_plus/` — 2A main, an F04 corridor, the lobby, the 4B
  kitchen, same stands, same settle.
- **Forward+ is 2–3× FASTER on this building**, because the frame is
  draw-call bound and clustered lighting costs less than Compatibility's
  per-object light loop: corridor 13.57 → 4.60 ms GPU, lobby 13.63 → 6.00,
  4B kitchen 9.50 → 3.84, 2A main 2.12 → 1.74. (CPU likewise: 21.9 → 11.5,
  24.4 → 14.4, 17.1 → 8.7, 5.7 → 4.3.)
- Gates on Forward+ before any new material work: ShaderParseCheck PASS,
  WalkTest FAST PASS, LightingAudit 127 spaces PASS, DreamTentacleTest
  20/20, ApartmentEncroachmentTest 13/13, OrganismIncidentsTest 18/18.
- Silent-fallback guard: `BuildingRoot._announce_renderer()` prints
  `[RENDER] <method>` and pushes a warning + `printerr` if the driver gave
  a different renderer than the project asked for.
