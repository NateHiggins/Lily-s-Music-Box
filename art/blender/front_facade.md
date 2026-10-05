# Source-fitted Orison front façade

Evidence class: **INERT**

Classification: **ADAPTATION**. The V2 front entrance had a noninteractive
graybox leaf and a coarse canopy. The original entrance records, ornamental
marquee assembly, landmark hardware, practical lamps, plaque and neon blade
provide the vocabulary. V2's retained rooms, apertures, masonry and pavement
provide the fit. The original building exports remain immutable.

**scripts/prepare_front_facade.py** reads both source layouts and freezes
LF-normalized bindings in **art/data/front_facade/source_fit.json**. It derives
the front wall reach, exposed south edges, eighteen forward window surrounds
and the nearest front-wing pier seats for **F01_NEON_BLADE**. The latter are
on **F02_D_RESTRICTED** and **F03_D_BATH**. V2's recessed court screened the
original transverse position from the pavement. The blade stays on the same
side of the entrance, a quarter-metre inside the front-wing corner, with its
original height, text, hardware and conductor identity.

**scripts/build_front_facade.py** imports the original marquee definition
without executing the original building export. It fabricates the glazed tray,
historic patch bays, bronze fascia, ornament, drain, stone entrance surround,
fitted oak jambs and a carcass around two real wired-glass panes. The original
upper tie anchors have no wall at V2's vestibule; seated pier plates, uprights,
return arms and diagonal knees carry the tray instead. The original raised
step is omitted so the existing continuous public pavement remains the sole
floor owner at the threshold. These are geometric fit decisions, not a
structural-capacity calculation.

The saved native contains **416 positive closed construction stocks** and
**59 bounded draws / 8,424 triangles**. Fixed and moving assemblies have
separate branch roots. Four-metre partitions use metre charts and checked
tangent derivatives. Existing catalogue albedo, normal and roughness maps
remain; iron and oak receive scoped tints. No new texture, material key or
bitmap lettering is introduced. Precision import and disabled generated LODs
preserve small joins.

**scripts/inspect_front_facade.py** reopens the saved native and independently
checks every closed stock, positive volume, bounds, partition triangle count,
relative image path and binding. Three native renders show the entrance,
canopy and leaf against temporary read-only retained context. That context
comes from the ignored production discovery under **tmp/v2-facade** and is
never resaved into the native asset.

**OrisonV2FrontFacade** mounts the native against the retained entrance anchor,
retiring only the composed exterior proxies. The standalone exterior is
unchanged. Each fixed native draw owns one collider from its visible faces.
The leaf has one existing **DoorProp** interaction/motion owner and one moving
box collider. **OrisonV2EntryDoor** inherits the original landmark brass
hardware, entry bell, audio, key permissions, saved lock and passage behavior.
It mirrors the original hardware primitives to V2's outward face. The original
marquee lamps, inspection owner, bronze plaque and conductor-driven neon blade
remain their existing runtime owners. The anchor adapter remaps and restores
the blade's original acoustic mouth; its low transformer inspection remains
reachable from the pavement.

**OrisonV2FrontFacadeTest** checks installed charts, maps, exact fixed collision,
eight pier anchor seats, the two blade bracket seats and the actual moving
leaf's swept box through **51 poses from 0 to 100 degrees**. Six ordinary
standing views use the production lights and player lamp. The separate
**OrisonV2FrontEntryRouteTest** uses the live controller to contact the closed
leaf, operate it from both sides, cross the threshold, lock it, test denial,
save and reconstruct the world, unlock it and return. Street-route tests now
operate the front door before departing through it.

Scoped captures, native inspection and wrapper **suite_run** receipts are
under **tmp/v2-facade**. They are inspection evidence and do not promote the
completeness ledger. Wider façade finish review, full V2 acceptance and the
parked heating shell-readiness work remain open.
