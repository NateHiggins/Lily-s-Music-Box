# DREAM-SURFACE-S1 census and phenotype bible — 2026-08-28

Scope: presentation only. Ecology, target selection, gait, lifecycle, save, and
cleanup authorization remain with their existing owners. The renderer consumes
a compact state packet and never writes those authorities.

## Render ownership census

| Type | Ecological/controller owner | Geometry and draw owner | Material / transparency | Animation inputs | Existing proof |
|---|---|---|---|---|---|
| Pioneer film, ether moss, heart, tending cilia, ether atmosphere | `DreamMossColony` via `DreamEcologyDirector` | `DreamMossColonyRenderer`; cached `ImmediateMesh`, one heart mesh, fixed 8-cilium and 24-mote MultiMeshes | formerly five per-colony `StandardMaterial3D`s; alpha blend | phase, maturity, reserve, production, routes, collapse, reports | `DreamMossPresentationTest`, `DreamMossLifecycleShot` |
| Sensory tentacles, suckers, ocular assembly, lids, halos, membrane | `ApartmentEncroachment` + `DreamTentacleBehavior`; E3 target authority unchanged | `DreamTentacleController` batched tube; bounded child assemblies | `dream_tentacle`, `dream_sucker`, `dream_eye`, `dream_eyelid`, `dream_halo`, `dream_membrane`; mostly opaque/depth-writing | exploration state, novelty, contact, reporting, breathing, recall, withering | `DreamTentacleTest`, hero lifecycle and E3 suites |
| Fold crabs and crystal listeners | `DreamCritterController` bound to colony records | one procedural batched mesh/material; maximum 12 animals and 96 cached leg rows | `dream_critter`, opaque/depth-writing | vigor, attention, examination, loaded information, return/deposit, gait | `DreamCritterTest`, `DreamEcologyE3Test`, E3A shot |
| Other gated fauna and ocular fauna | `DreamFaunaDirector` / organelle lifecycle | fixed-capacity MultiMeshes grouped by family | `dream_fauna`, unshaded opaque; shared skin atlases | lifecycle stage, ether breath, family motif, vertex channels | fauna lifecycle, visible, trophic, breath suites |
| Ether field | `LivingField` / colony sampling | moss fixed MultiMesh plus field presentation | shared mote material; alpha | connected ether volume and local concentration | E2 lifecycle |
| Withering organisms | existing lifecycle owners above | same meshes and batches; no replacement nodes | phenotype shaders consume collapse/senescence | collapse progress, vigor, lifecycle stage | ecology/fauna/hero lifecycle suites |
| Residue and cleanup stain | `DreamResidue` plus authorized field/colony cleanup | one bounded 24-patch surface | `dream_residue`, alpha/unshaded/depth-never | patch life, density/generation memory, dream weight, cleanup authority | margin death stain, ecology lifecycle, residue tests |

## Shared versus phenotype ownership

`dream_cellular_surface.gdshaderinc` owns stable seeded fields, multi-scale
membrane compartments, thickness windows, phase/DIC boundary response,
cytoplasmic streaming, bounded protein families, transport, and senescent
failure. Phenotype shaders retain geometry deformation, anatomy masks, palette,
lighting integration, and their established batching. No global post-process is
introduced.

The compact CPU packet is `DreamCellularState`: ether, information, novelty,
contact, reporting, breathing/return, disturbance, recall, senescence, death,
and cleanup. `DreamCellularPhenotype` supplies deterministic bounded visual
profiles. Both are presentation-only `RefCounted` values.

## Phenotype table

| Phenotype | Silhouette-scale membrane organization | Cilia / proteins | Interior and light behavior |
|---|---|---|---|
| Pioneer film | thin advancing lobes and adhesion plaques | sparse receptors, no carpet | edge-directed granules; broad phase boundary |
| Moss / heart | branching folds, radial breathing chambers, protected core | exchange gardens and report rosettes | radial streams, filling vacuoles, information-complexity pulses |
| Tending cilia | dense rooted exchange carpet | short metachronal transport shafts, bidirectional cargo | heart-synchronized base fluorescence |
| Tactile tentacle | pressure pits and stretched joint compartments | short mechanocilia, adhesion clusters | contact blooms and returning packets |
| Chemical tentacle | porous clearing patches | receptor islands and gated pores | absorbed color clouds and vesicle traffic |
| Thermal tentacle | layered lamellae | sparse slow gates | convection-like broad pulses |
| Vibrational tentacle | aligned filament ridges | nodal sensory shafts | standing directional gradients |
| Optical tentacle / advanced ocular | pigment cups, lens vesicles, contractile apertures | retinal ciliary arrays | converging signals; no pasted vertebrate face requirement |
| Electrical tentacle | stretched conduction lanes | pump chains and transfer rosettes | traveling membrane potentials |
| Fold crab | dark dorsal compartments, ventral breathing mantle | rooted manipulator hairs, foot adhesion clusters | return packets, gold conduction, fold-seam parallax |
| Crystal listener | grown membrane-mineral lamellae | ordered lattice, nodal cilia | slow vesicles, standing waves, birefringent bands |
| Senescent / stain | cloudy slack membrane collapsing into route-shaped residue | stalled/tangled shafts and misclustered proteins | slowed streaming, collapsed vacuoles, distorted halos, coagulated pigment |

## Hard budgets

- 64 moss branch segments, 24 ether motes, 32 moss cilia, 64 protein/cargo
  instances per colony; all fixed-capacity MultiMeshes.
- Existing maxima remain: 12 critters, 96 cached crab leg rows, bounded fauna
  MultiMeshes, and one batched tentacle body per limb.
- Three shared moss material resources (membrane, cilium, cargo) per renderer;
  no material per cilium or protein.
- Stable anatomy is cached. State uniforms may update at 5 Hz; instance poses at
  the existing visible animation cadence. No texture generation, GPU readback,
  molecular node forests, or simulation mutation.
- Opaque/dithered cellular skins own core readability. Alpha is reserved for
  sparse atmosphere and existing residue; internal visibility is depth-gated
  in the near surface rather than X-rayed through the far side.

Automated capture PASS proves deterministic state, bounded resources, and
camera provenance. It is not human aesthetic acceptance.
