# Prop Reference Notes

This is a working record, one prop at a time. It separates historical
evidence from Orison canon and from the adaptations required by the actual
building. A good period object in the wrong kitchen is still the wrong prop.

Evidence labels used below:

- **HISTORICAL** — supported by a period advertisement or museum record.
- **CANONICAL** — ruled by the Orison covenant or appliance bible.
- **ADAPTATION** — changed to fit a measured room, player, or interaction.
- **NECESSITY** — ownership or pipeline work required for the prop to exist
  and behave reliably in this project.

## `fridge_prop`

### What the real objects were

The ordinary 1927 rented-flat cold box was an icebox, not a modern electric
refrigerator. The National Park Service describes the common construction as
a wooden cabinet lined with zinc or tin, with the ice in an upper compartment,
wire shelves below, and melt water collected in a drip pan that had to be
emptied. That is the non-signal object: furniture, plumbing by gravity, and
probably second-hand. **HISTORICAL; CANONICAL.**

A 1916 Bohn advertisement supplies a useful middle-class reference rather than
an ornate hotel specimen: an enamel-lined oak box listed at 39 x 22 x 50 inches
with 125-pound ice capacity and a $64 list price. The Orison version takes its
cabinet organization, top ice door, lower food door, exposed hinges, positive
latches, and drip-pan responsibility from this class of object. By 1927 such a
box could plausibly be a worn eleven-year-old purchase. **HISTORICAL.**

The four electric cabinets are GE DR-series monitor-tops. The Powerhouse
collection dates its example to 1927–1936 and records 1660 x 720 x 640 mm and
212 kg. It also notes that the 1927–1932 machines left their copper cooling
tubing visible. The mechanism is broad and low on the cabinet lid — a hat,
not a tall black tower. The first popular GE refrigerator was a costly luxury,
which makes four owners in one building characterization rather than a new
default. **HISTORICAL; CANONICAL.**

Sources:

- National Park Service, [The Icebox, the Predecessor of Modern Refrigeration](https://www.nps.gov/articles/000/the-icebox-the-predecessor-of-modern-refrigeration.htm)
- Library of Congress, [Bohn Syphon Refrigerator advertisement, 18 June 1916](https://tile.loc.gov/storage-services/service/sgp/sgpbatches/batch_dlc_belleauwood_ver02/data/sn83030214/print/1916061801/0005.pdf)
- Powerhouse Collection, [General Electric monitor-top refrigerator](https://collection.powerhouse.com.au/object/210813)
- Albany Institute, [General Electric refrigerator object sheet](https://www.albanyinstitute.org/tl_files/pdfs/50%20Objects%20Curriculum/GE_Refrigerator.pdf)

### What we inherited

- Four markers requested a monitor-top, but fourteen ordinary flats received a
  rounded 1950s refrigerator shell named `fridge50`. It was the wrong object
  class by nearly thirty years. **CANONICAL fault.**
- The cabinet lived in Blender while its door and contents lived in GDScript.
  The warehouse therefore displayed a floating door; 4B could display the
  moving half with no shell at all. Source inspection made both halves look
  reasonable, but neither render did. **NECESSITY fault.**
- All eighteen markers and acoustic nodes were electrical. Fourteen oak boxes
  therefore hummed, clicked, and carried electrical infection despite having
  no motor, relay, lamp, or wire. **Rule-of-Signal fault.**
- The old clearance audit selected only `fridge50`; monitor-tops were never
  checked. The first corrected run immediately found 4B inside the apartment
  door sweep and overlapping its radiator. **NECESSITY fault.**
- The old monitor mechanism was a narrow three-storey drum. The height was
  plausible, but the silhouette was not the GE object it claimed to be.

### Built result

`fridge_prop.gd` now owns the complete visible object and all moving parts.
The obsolete Blender builders are gone, so there is no baked shell to duplicate
or disappear independently.

#### Oak-and-zinc icebox — fourteen flats

- 0.70 m wide x 0.58 m deep x 1.24 m high. The proposed 0.76 m cabinet did not
  fit the generated run: standard stove/fridge centres are only 0.69 m apart.
  The compact width keeps two distinct bodies without interpenetration.
  **ADAPTATION.**
- Board-built quarter-sawn oak carcass, feet and recessed kick rather than a
  modern moulded shell.
- Separate upper ice door, lower food door, zinc-lined chambers, wire shelves,
  positive brass hardware, and a real pull-out drip tray. Every part named by
  the inventory and melt-water activities exists as a separate mechanism.
- Water staining is concentrated below the tray; hand wear belongs at latches
  and pulls. The cabinet is not covered by a uniform dirt filter.
- No compressor hum, relay click, thermostat, electric lamp, electrical node,
  or corridor-light edge. Its rare idle events are a soft drip or cabinet
  creak. Possession can nudge the tray — an unnerving mechanical event that
  remains physically possible without granting the box electricity.

#### GE-style monitor-top — 1A, 3A, 5B, 6C

- 0.72 m wide x 0.64 m deep x 1.66 m high, matching the museum dimensions.
  The kitchens have 3.02 m clear height, leaving 1.36 m above the appliance.
  Its crown clears the 1.41 m player eye line on purpose: this expensive new
  machine has presence. The measured footprint fits the run and is now audited.
- Pressed off-white enamel cabinet around a real cavity, porcelain liner, wire
  shelves, freezing box, chrome latch and hinges.
- Broad low top mechanism with exposed aged-copper rings and service tubes,
  plus restrained chips at the latch strike and lower boot.
- The cabinet has the hum, relay tick, thermostat cycle, electrical acoustic
  node, infection edge, and a low-output interior lamp that only lights its
  liner. These are signal-adjacent electrical behaviours and belong only here.

All eighteen larders retain per-household contents. No generated texture carries
words: the existing authored larder atlas owns the invented packaging labels.

### Layout and clearance result

The generator now treats the `fridge` marker as the semantic cold-storage
object, footprint, standing-room source, and door-sweep owner. A monitor-top
can satisfy the need because it is a variant of the same marker, not an
equivalent furniture assembly. This removes all load-bearing references to
`fridge50` and makes both variants pass the same audits.

4B was the one inherited failure. Its radiator moved to the free pipe run and
its icebox moved to the east kitchen wall, outside the apartment-entry sweep.
The rendered maintenance pose shows food door, ice door, and tray open without
crossing the counter, radiator, or entry leaf.

### Materials and measured render response

- `oak_quartered` and `enamel` are reused.
- `brass_dull` is now a real runtime finish in `MatLib.SETS` and
  `GODOT_STAGE`. It shares the existing brass plate through
  `catalog_mapping`, but carries its own 0.30 metallic / 0.52 roughness
  response.
- `zinc_liner` and `copper_aged` are new catalog, ingest, staged, and runtime
  sets. Their source images are documented in `PROP_TEXTURE_PROMPTS.md`.
- Zinc was corrected after render, not by eye. At 0.38 metallic, an oblique
  4B view sampled nearly black. The oxidized liner now uses 0.12 metallic and
  0.82 roughness. A direct installed view samples median RGB **(91, 86, 99)**,
  luma p10/50/p90 **20/88/141**, with **0.0%** clipped pixels in the measured
  cavity crop. The oak carcass samples median **(74, 39, 29)** in the same
  frame, so the two materials separate without a fake interior light.
- The open 1A liner samples median RGB **(213, 185, 151)** under its practical
  plus the required torch. Its shelves and contents remain legible. The
  monitor-top is deliberately the brighter, newer, more expensive object.

### Render evidence

Before:

- Warehouse — `C:/shots/orison_prop_pass/fridge_before/warehouse/stand_406.0_1.00_-1.50_0_-3.png`
- 4B in situ — `C:/shots/orison_prop_pass/fridge_before/insitu/stand_-8.3_10.70_-7.50_0_-10.png`
- 1A in situ — `C:/shots/orison_prop_pass/fridge_before/insitu/stand_-6.79_1.10_2.50_0_-5.png`

After:

- Warehouse family — `C:/shots/orison_prop_pass/fridge_after/final_warehouse/stand_408_1.08_-7.0_180_-3.png`
- 4B installed — `C:/shots/orison_prop_pass/fridge_after/insitu/stand_-9.7_10.70_-8.6_-90_-4.png`
- 4B door, ice door, tray, and liner — `C:/shots/orison_prop_pass/fridge_after/final_clearance/stand_-9.7_10.70_-8.6_-90_-4.png`
- 4B three-quarter clearance — `C:/shots/orison_prop_pass/fridge_after/final_clearance/stand_-9.7_10.75_-7.5_-55_-7.png`
- 1A monitor-top, open — `C:/shots/orison_prop_pass/fridge_after/final/stand_-7.8_1.25_2.3_-35_-6.png`

All installed frames use `SHOT_LIGHTS=1 SHOT_TORCH=1`; none uses the judging
fill.

### Validation

- `python art/data/gen_layout.py` — exit 0; 18 refrigerator markers, all
  furnishing, standing-room, footprint, and door-clearance audits passed.
- Blender 5.2 background build — exit 0; 230 mapped materials validated and
  all eight floor/roof scenes exported.
- JSON copy followed by Godot 4.7.1 import — exit 0; `FridgeProp`, `MatLib`,
  and `PropWarehouse` registered without parse errors.
- `WalkTest.tscn` — exit 0 in 202.9 seconds; all eight floors and 432
  functional props instantiated. Its existing dummy-renderer null-texture
  diagnostics remain in the phone/broadcast cookie paths; they are unrelated
  to this prop and do not fail the suite.
