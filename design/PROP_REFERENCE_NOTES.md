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

## `stove_prop`

### What the real object was

The Orison range is a cheap freestanding gas cooker sold in the first half of
the 1920s: white porcelain enamel panels on an angle-iron base, four open gas
burners, an oven below, a separate broiler, exposed front valve rail, shallow
splash panel and no clock. It is a mechanical gas appliance. It carries no
signal, so the Rule of Signal leaves it in 1927 and on a pipe rather than a
wire. **HISTORICAL; CANONICAL.**

The March 1922 *Washington Times* Champion-range advertisement is the closest
price-class reference: its copy calls out a porcelain-enamel splash back,
porcelain door panels, angle-iron base, broiler and an oven about eighteen
inches deep. A 1924 Clark Jewel advertisement corroborates the period's white
enamel, open-burner, oven-and-broiler organization. The Science Museum's
1920–25 Metro cooker and a surviving 1927 Eriez range supplied three-dimensional
checks for the legged carcass, valve row, removable grates and door hierarchy.
**HISTORICAL.**

Sources:

- Library of Congress, [Champion gas range advertisement, 26 March 1922](https://tile.loc.gov/storage-services/service/ndnp/au/batch_au_engle_ver01/data/sn85038485/00340583073/1922032601/0401.pdf)
- University of North Texas, [Clark Jewel gas range advertisement, 1924](https://texashistory.unt.edu/ark:/67531/metapth893052/m1/4/?q=+date%3A%2A-2008)
- Science Museum Group, [Metro gas cooker no. 370750, c. 1920–25](https://collection.sciencemuseumgroup.org.uk/objects/co49016/metro-gas-cooker-no-370750-c-1920)
- Antique Appliances, [1927 Eriez gas stove](https://www.antiqueappliances.com/product/1927-eriez-gas-stove/)

### What we inherited

- The Blender assembly was a 1930s–40s Chambers/Roper composite: clock-like
  high back, modern continuous cabinet and oven-window language. It was the
  wrong decade and class of object. **CANONICAL fault.**
- The fixed shell lived in Blender while the oven leaf and glowing electric-
  style rings lived in GDScript. The warehouse rendered the moving parts in
  mid-air and no complete silhouette existed outside the installed room.
  **NECESSITY fault.**
- The visual burners were plates rather than open gas grates. There were no
  caps, jets, gas rail, liner, rack, broiler cavity or removable service parts,
  although the activity brief asks the player to clean and diagnose them.
- A random 35% of all seventeen ranges started lit. That turned a deliberate
  domestic hazard into six simultaneous gas leaks and made the event
  impossible to learn. The random beat was authored, not merely a visual bug.
- The baked footprint row survived independently of the marker, and clearance
  checked the obsolete assembly rather than the functional prop.

### Built result

`stove_prop.gd` is now the sole owner of the complete range and its moving
parts. The obsolete `asm_stove` builder and `ASM_FOOT["stove"]` entry are gone.

- 0.64 m wide x 0.60 m deep. The width was already the inherited footprint;
  depth reduces from 0.68 m to the measured kitchen run. The top bearing plane
  is exactly **0.90 m**, preserving contact with 2C's tape boxes and 5B's radio
  collection. **ADAPTATION.**
- Pressed enamel shell on four angle-iron legs, recessed deck, shallow splash
  panel and shelf, exposed dull-brass gas rail and five bakelite valves.
- Four separate cast-iron open grates, caps and jet plugs. Each household gets
  deterministic grime and one deterministic blocked jet; caps and grates are
  removable through the maintenance API.
- A real dark oven cavity has five liner planes and a wire rack. The falling
  oven leaf has an inner heat shield and period pressed panel rather than a
  glass window. The broiler remains a separate pull below it.
- `set_service_pose()` exposes the blocked jet with its cap aside and grate
  leaned against the splashback. `set_burner_lit()` produces a restrained blue
  gas flame; a blocked jet coughs yellow and dies. The compatibility
  `set_ring()` path remains for existing director calls.
- Per-unit wear belongs where heat, hands and grease act. 3D is unusually
  clean; 2C/5B carry old film beneath their shelf loads; 5C carries paint-life
  neglect. This is not a uniform dirt multiplier over the complete object.

All seventeen markers retain `network: gas`. Nothing was repointed to the
electrical graph. 4B has no range and no eighteenth marker was introduced.
Only 2B owns `ambient_lit`: Lena's borrowed-family cookware makes one low,
repeatable unattended flame a discoverable fact instead of a boot-time roll.

### Layout and clearance result

The generator now treats each `stove` marker as the range footprint and
clearance owner. It audits the 0.64 x 0.60 body, a 0.72 m standing square and
the 0.44 x 0.34 m forward oven sweep. Both life and furnishing audits count the
marker, not a deleted furniture assembly. The rebuilt data contains exactly
the approved units: 1A, 1D, 2A, 2B, 2C, 3A, 3B, 3D, 4A, 4C, 4D, 5A, 5B, 5C,
6A, 6B and 6C.

The rendered 1A open pose clears its adjacent counter and monitor-top. 2C's
three tape boxes and 5B's upright radios contact the 0.90 m grate plane without
the 10 mm gap the rejected 0.91 m proposal would have produced.

### Materials and measured render response

- `enamel` and `bakelite` are reused runtime sets.
- `cast_iron` now has the missing `GODOT_STAGE` and `MatLib.SETS` paths. It
  reuses the existing cast-iron source family with 0.35 metallic / 0.60
  roughness response.
- `fx_grease` now has an explicit runtime path rather than relying on its
  Blender-only overlay key. The staged plate preserves its source alpha and
  receives neutral roughness and normal companions; `MatLib` uses alpha depth
  pre-pass so the shaped stain does not become an opaque square.
- `brass_dull`, added during the refrigerator pass, is reused for the
  horizontal shelf edge, rail and hardware.
- Warehouse lighting remains effectively identical before/after: mean RGB
  **(102.6, 102.5, 105.2)** before and **(102.4, 102.0, 103.4)** after;
  luma p10/50/p90 **54.5/108.4/123.4** before and
  **54.1/108.1/123.1** after. The comparison therefore reflects geometry and
  material response, not a brighter inspection rig.

No new generated plate was required. `cast_iron` reuses an ingested source and
`fx_grease` reuses the existing authored alpha decal; see
`PROP_TEXTURE_PROMPTS.md` for the explicit no-generation decision.

### Render evidence

Before:

- Warehouse — `C:/shots/orison_prop_pass/stove_before/stand_410_1.10_4.8_180_-4.png`
- 1A installed — `C:/shots/orison_prop_pass/stove_before/stand_-7.48_1.10_2.50_0_-5.png`

After:

- Warehouse — `C:/shots/orison_prop_pass/stove_after/warehouse/stand_410_1.10_4.8_180_-4.png`
- 1A installed, oven open — `C:/shots/orison_prop_pass/stove_after/insitu_1a/stand_-7.48_1.10_2.50_0_-5.png`
- 2B deterministic ambient flame — `C:/shots/orison_prop_pass/stove_after/insitu_2b/stand_-7.20_4.30_-8.48_-90_-8.png`
- 2B service pose and door sweep — `C:/shots/orison_prop_pass/stove_after/service_2b/stand_-7.20_4.30_-8.48_-90_-8.png`
- 2C tape load — `C:/shots/orison_prop_pass/stove_after/loaded_hobs/stand_7.20_4.30_-2.58_90_-8.png`
- 5B radio load — `C:/shots/orison_prop_pass/stove_after/loaded_hobs/stand_-7.20_13.90_-8.48_-90_-8.png`

Every installed frame uses `SHOT_LIGHTS=1 SHOT_TORCH=1`; none uses the judging
fill.

### Validation

- `python art/data/gen_layout.py` — exit 0; exactly 17 stove markers, all
  `network: gas`, 2B alone `ambient_lit`, no 4B marker; furnishing, footprint,
  standing-room and door-clearance audits passed.
- `python art/tools/ingest_material_sources.py` — exit 0; `cast_iron` and
  alpha-preserving `fx_grease` runtime maps staged.
- Blender 5.2 background build — exit 0; 230 mapped materials validated and
  all eight floor/roof scenes exported.
- JSON copy followed by Godot 4.7.1 import and editor rescan — exit 0; one
  shadowed helper parameter caught by the first WalkTest run was fixed before
  visual acceptance.
- `WalkTest.tscn` — exit 0 in 184.7 seconds; 432 functional props instantiated,
  all navigation, stair and elevator checks passed. Its existing dummy-renderer
  phone-cookie diagnostics remain unrelated and do not fail the suite.

## `tap_prop` plumbing family

### What the real objects were

The cheap Orison kitchen fixture is the smallest roll-rim enameled-iron sink
shown in the J. L. Mott Iron Works catalog: **24 x 18 x 6 inches**, with an
integral back, hanger or legs, optional porcelain-enamel drainboard, and
nickel-plated Fuller-pattern brass faucets. The bathroom basin is Mott's
compact apartment-house enameled lavatory with integral back/apron,
compression taps, pedestal and exposed waste. The shower follows Mott plate
1034-A: a **28-inch corner receptor**, exposed tubular shower and mixing
valves, a roughly 25-inch curtain ring, and white duck curtain. These are
ordinary plumbing fixtures. They carry no signal, so the Rule of Signal leaves
them in 1927, second-hand, and on water pipe. **HISTORICAL; CANONICAL.**

Primary reference copies retained with the project work:

- `tmp/pdfs/mott_plumbing_fixtures_1908.pdf`, plates 7300–7306: Beekman and
  Economic roll-rim sinks, drainboards, hanger/leg options and nickel-plated
  Fuller faucets.
- `tmp/pdfs/mott_modern_plumbing_1908.pdf`, plates 1034-A and 1053: corner
  receptor/tubular shower and inexpensive compact apartment-house lavatory.

### What we inherited

- Blender owned all porcelain and stall geometry while `tap_prop.gd` owned
  only floating handles and a water column. The warehouse therefore showed
  no complete sink silhouette. **NECESSITY fault.**
- The kitchen run used a modern brushed-metal undermount basin with no
  drainboard. The generic bath assembly used a late-century glass enclosure,
  single mixer plate and lever. Both were the wrong period and object class.
- The basin, shower and 4B standalone sink had three different geometry
  owners. Activities could turn a valve but could not address hot and cold
  independently, close a stopper, fill a bowl, or share the boiler curve.
- `asm_sink_ped` also secretly owned the fixed medicine-cabinet carcass. Once
  the basin assembly was removed, the otherwise functional mirror opened onto
  empty wall.
- Nine blind stacks could descend through the 1.00 m court-window sill and
  into the countertop below. 4B made the fault conspicuous, but it was a
  shared generator defect rather than a player-flat exception.

### Built result

`tap_prop.gd` now solely owns three complete period fixtures:

- **Apartment lavatory:** 0.61 x 0.56 m, 0.82 m rim, rolled oval enamel basin,
  tapered pedestal, integral back, independent cross taps, central spout,
  exposed supplies, stops, trap, drain and stopper. The bowl is one continuous
  elliptical surface under one rolled rim; a rejected lower ring and a
  permanently high water plane both read as a second basin in the doorway
  render. Water now begins at the drain and rises/spreads with fill level.
- **Kitchen sink:** measured 0.61 x 0.46 x 0.15 m roll-rim iron bowl with
  integral back, ribbed 0.42 m drainboard and independent wall-mounted
  compression taps. The cross handles now face the user in the wall plane,
  with visible escutcheons, a joined supply bridge and a high gooseneck spout;
  the inherited handles had been modelled as deck taps rotated 90 degrees out
  of their useful plane. The valve centre is 110 mm above the sink rim: this
  keeps the complete escutcheon on the 160 mm integral enamel back instead of
  floating above its edge. The 4B version preserves its existing 0.50 x 0.38
  m opening and separate plate rack; an attached board there would occupy the
  new range.
- **Shower:** 0.72 m corner receptor, real cavity/drain, exposed nickel riser,
  arm and broad rose, separate valves, 25-inch-equivalent rail and gathered,
  partly open white-duck curtain. The deleted glass cubicle does not survive.

`set_hot`, `set_cold`, `set_stopper` and `set_boiler_temperature` are
independent maintenance APIs. A closed stopper fills the visible basin surface
while flow is active and drains when opened; `set_running` remains only as a
compatibility path. Possession can retime a valve or admit a brief cold thread,
but does not make these non-signal objects electrical. Every fixture retains
`network: water`.

The medicine cabinet now owns its recessed pressed-enamel carcass, two glass
shelves and nickel frame as well as its moving mirror leaf and resident-kept
contents. Its stable inspection API renders the complete 1.9-radian door sweep.

### Layout, counts and clearance

The generated building contains **23 showers, 24 bathroom lavatories** (23
apartment/public markers plus the Harukiya bar WC), and **19 kitchen sinks**
(18 kitchen assemblies including `common_k`, plus 4B). Obsolete `sink_ped`,
`shower`, and `sink_basin` furniture assemblies are all zero.

Bath and kitchen semantics live in `fixture` while public marker kinds remain
`sink`/`shower`. Life, furnishing, activity-socket, footprint and circulation
audits now count the semantic marker. The kitchen cabinet keeps its dirty-
counter and trash sockets; new `SINK_EDGE`, `KITCHEN_SINK_EDGE`, and
`SHOWER_EDGE` sockets follow the actual fixtures. A kitchen sink does not add
a duplicate movement obstacle because it is already inside the cabinet/counter
footprint.

The generic blind cap now stops every stack at `WIN_COURT["sill"] == 1.00`.
The rendered 4B follow-up exposed a second, horizontal conflict: its upper
cabinet occupied the window/blind span. The upper now stops at `x == -10.31`,
8 cm before the blind begins, and carries one correctly sized door instead of
two leaves extending past the carcass. 4B retains the approved counter
`-10.86..-9.55`, range `-9.55..-8.91`, mug at `-10.35`, and plate rack at
`-9.605`; its basin remains centered at `(-9.93, 9.31)`.

Both the generic kitchen assembly and 4B now segment the cabinet carcass as
well as the countertop around the exact basin bounds. A sink-hidden render
shows a deep open void instead of the former textured cabinet face, proving
that the bowl descends through a real opening. The generic three-box stand-ins
and 4B's box crockery are gone; a real mug and compact nickel-wire draining
rack with four porcelain plates give each silhouette a legible purpose.

### Materials and measured render response

- `porcelain`, `enamel`, `linen`, `cast_iron` and `brass_dull` reuse existing
  runtime sets.
- New `nickel_plated` is present in `MATERIAL_CATALOG`, ingest `SLOTS` and
  `GODOT_STAGE`, and `MatLib.SETS`. Its generated flat document-scan plate is
  warm silver rather than modern blue chrome: 0.70 metallic / 0.38 catalog
  roughness, with a 0.82 runtime roughness multiplier so horizontal spouts do
  not disappear black under the torch.
- Mineral bloom and rust are positioned at drains, rims and wet corners rather
  than tiled uniformly over dry vertical enamel.

Measured from identical installed crops under `SHOT_LIGHTS=1 SHOT_TORCH=1`:
bath luma p10/50/p90 moved from **30.3/110.9/165.3** to
**31.3/110.6/170.3**; standard kitchen from **29.1/133.9/205.7** to
**34.5/135.2/197.9**; 4B from **3.8/104.5/181.3** to
**15.3/129.7/187.4**. The replacements remain shadowed while their cavities,
hardware and working surfaces read more reliably.

### Render evidence

Before:

- Warehouse split ownership — `C:/shots/orison_prop_pass/tap_before/warehouse/stand_392_1.10_4.6_180_-5.png`
- 1A lavatory — `C:/shots/orison_prop_pass/tap_before/insitu_close/stand_-7.10_1.25_4.27_-90_-5.png`
- 1A shower — `C:/shots/orison_prop_pass/tap_before/insitu_close/stand_-7.10_1.30_5.69_-90_-4.png`
- 2B kitchen — `C:/shots/orison_prop_pass/tap_before/kitchen/stand_-7.15_4.55_-7.60_-90_-10.png`
- 4B kitchen — `C:/shots/orison_prop_pass/tap_before/kitchen/stand_-9.93_10.95_-8.35_0_-10.png`

After:

- Warehouse shower — `C:/shots/orison_prop_pass/tap_after/warehouse_flat/stand_390_1.25_6_180_-8.png`
- Warehouse lavatory — `C:/shots/orison_prop_pass/tap_after/warehouse_flat/stand_394_1.15_6_180_-10.png`
- Warehouse kitchen sink — `C:/shots/orison_prop_pass/tap_after/warehouse_flat/stand_398_1.20_6_180_-10.png`
- 1A lavatory installed — `C:/shots/orison_prop_pass/tap_after/insitu/stand_-7.10_1.25_4.27_-90_-5.png`
- 1A shower installed — `C:/shots/orison_prop_pass/tap_after/insitu/stand_-7.10_1.30_5.69_-90_-4.png`
- 2B kitchen installed — `C:/shots/orison_prop_pass/tap_after/insitu/stand_-7.15_4.55_-7.60_-90_-10.png`
- 4B kitchen installed — `C:/shots/orison_prop_pass/tap_after/insitu/stand_-9.93_10.95_-8.35_0_-10.png`
- Final lowered wall mount, 2B — `C:/shots/orison_prop_pass/tap_after/lowered_mount/stand_-7.15_4.55_-7.60_-90_-10.png`
- Final lowered wall mount, 4B — `C:/shots/orison_prop_pass/tap_after/lowered_mount/stand_-9.93_10.95_-8.35_0_-10.png`
- Old false cutout, sink hidden over the solid carcass — `C:/shots/orison_prop_pass/tap_after/kitchen_cutout_probe/stand_-7.15_4.55_-7.60_-90_-10.png`
- Generic real cutout, sink hidden — `C:/shots/orison_prop_pass/tap_after/kitchen_cutout_after/stand_-7.15_4.55_-7.60_-90_-10.png`
- 4B real cutout, sink hidden — `C:/shots/orison_prop_pass/tap_after/kitchen_cutout_after/stand_-9.93_10.95_-8.35_0_-10.png`
- 1A hot/cold/stopper and cabinet sweep — `C:/shots/orison_prop_pass/tap_after/service/stand_-7.10_1.25_4.27_-90_-5.png`
- 1A shower flow — `C:/shots/orison_prop_pass/tap_after/service/stand_-7.10_1.30_5.69_-90_-4.png`
- 1A shower valve/flow through curtain opening — `C:/shots/orison_prop_pass/tap_after/service/stand_-7.10_1.30_5.32_-72_-4.png`
- Duplicate-owner proof, new sink hidden and no basin left behind — `C:/shots/orison_prop_pass/tap_after/duplicate_probe/stand_-7.10_1.25_4.27_-90_-5.png`

Installed frames use `SHOT_LIGHTS=1 SHOT_TORCH=1`; warehouse frames use the
shed's even inspection light with `SHOT_TORCH=0`.

### Validation

- `python art/data/gen_layout.py` — exit 0; furnishing, wall, movement, life,
  semantic fixture and marker counts passed.
- `python art/tools/ingest_material_sources.py` — exit 0; nickel generated and
  staged. Unrelated tracked roughness rewrites from full ingest were restored;
  only the new nickel maps remain in this pass.
- Blender 4.5.12 build — exit 0; 231 mapped materials, all eight floor/roof
  scenes exported. JSON copy and Godot 4.7.1 import — exit 0.
- Godot editor rescan — exit 0. An exact UP-to-DOWN pipe quaternion caught by
  the first WalkTest was replaced with an explicit 180-degree branch.
- The last exhaustive `WalkTest.tscn` before the inspection-helper-only
  handle correction exited 0 in 196.7 seconds with 453 functional props and
  all route, stair, elevator, lighting and collision checks passing.
- WalkTest now defaults to a focused iteration gate and reserves those long
  physical performances for `WALKTEST_FULL=1`. The exact final source passed
  **WALKTEST RESULT: PASS [FAST]** in **14.1 seconds**, including construction,
  layout, lighting, resident/exterior checks, all 66 plumbing markers and an
  operated 4B hot/cold/stopper/stream state.

## `toaster_prop` — Waters-Genter Toastmaster 1-A-1

### What the real object was

Waters-Genter introduced the automatic Toastmaster Model 1-A-1 in 1926. The
Henry Ford museum example measures **10.125 x 4.75 x 7.375 inches** (0.257 x
0.121 x 0.187 m). Patent US 1,698,146 records one longitudinal bread slot, a
spring carriage, paired resistance-wire mica heater cards, a mechanical timing
device and end-mounted controls. A November 1927 *New Yorker* advertisement
priced it at $12.50: expensive, current, and plausible as an aspirational
second-hand appliance in the Orison. It carries no signal, so bible VIII.2
leaves its mechanism entirely in 1927. **HISTORICAL; CANONICAL.**

The model did not have a factory pull-out crumb tray. The activity requires a
tray that can be opened, so this one is explicitly a crude folded-metal Orison
maintenance retrofit rather than a false factory feature. **NECESSITY;
CANONICAL.**

### What we inherited

- A generic late-century two-slot rectangular toaster, with a modern rotary
  control and no legible carriage mechanism.
- One instance in 4B despite the authored majority-apartment ruling.
- No removable tray, heater cards, exposed resistance system or useful
  maintenance API.
- A single flat material treatment that could not distinguish nickel plate,
  Bakelite, braided cord, mica or hand grease.

### Built result

The prop now owns the measured single-slot 1-A-1 silhouette: plated pressed
case, three stepped shoulder folds, raised slot lip, recessed ventilation,
corner fasteners, four Bakelite feet, braided cord and two-pin plug. The two
end controls have distinct jobs—carriage/switch and clockwork timing stop—and
the bread carrier, lever, click, hum, heater glow and spring pop remain a
complete mechanical cycle.

Inside are two textured mica heater cards and separate resistance-wire
geometry. Only the wire emits. The service pan is a 0.215 x 0.105 m shallow
folded tray with a mismatched Bakelite pull, local grease and deterministic
per-household crumbs. `set_crumb_tray_open()` exposes 160 mm of travel for the
archaeology minigame without replacing the normal carriage interaction.

Fourteen flats instantiate it: **1A, 1D, 2A, 2B, 3A, 3B, 3D, 4A, 4B, 4C, 5A,
6A, 6B and 6C**. The deliberate exceptions remain 2C, 5B, 4D and 5C. Standard
kitchen markers expose local -Z to the cook. 4B deliberately turns the body
across its short bespoke counter, so its superintendent retrofit exits the
open end instead. Real-window maintenance renders caught and corrected the
first implementation withdrawing toward the backsplash; both the standard 2A
pan and 4B end-pull now clear their counters visibly.

### Materials and ingestion

`nickel_plated`, `bakelite_black`, `fabric_warm` and `fx_grease` reuse their
runtime sets. New `mica_heater` is present in `MATERIAL_CATALOG`, ingest
`SLOTS`/`GODOT_STAGE` and `MatLib.SETS`. Its source is a seamless, square,
flat evenly-lit mineral document scan with no marks or writing. The generated
albedo, height, normal, roughness and metadata are staged as the three runtime
maps used by the GDScript prop.

The material ingester is now incremental. It fingerprints each source and its
entire recipe, adopts legacy outputs only when they post-date every source,
does not decode unchanged images, does not rewrite identical Godot maps, and
supports `--slot`, `--full`, `--check` and `--show-unknown`. The mica-only pass
took **1.6 seconds**; the following no-change library pass took **0.18
seconds**, rather than timing out during a whole-library rebake. Unassigned
source art is reported as a count during normal work and can be enumerated for
curation without making the named material contract fail.

### Render evidence

Before:

- Warehouse, generic two-slot box — `C:/shots/orison_prop_pass/toaster_before/stand_398_1.00_10_180_-8.png`
- 4B installed — `C:/shots/orison_prop_pass/toaster_before/stand_-10.70_10.88_-8.40_0_-12.png`

After:

- Warehouse, closed 1-A-1 — `C:/shots/orison_prop_pass/toaster_after/stand_398_0.55_11.25_180_-8.png`
- Standard 2A kitchen, tray open — `C:/shots/orison_prop_pass/toaster_after/stand_-7.94_5.45_1.50_0_-35.png`
- 4B bespoke counter, end-pull tray open — `C:/shots/orison_prop_pass/toaster_after/stand_-10.70_11.35_-8.20_0_-35.png`
- 4B installed, eye-level context — `C:/shots/orison_prop_pass/toaster_after/stand_-10.70_10.88_-8.40_0_-12.png`

The warehouse uses its flat inspection light with the torch off. Installed
frames use `SHOT_LIGHTS=1 SHOT_TORCH=1`. In a sampled warehouse crop, median
luma rose from **103.0** to **116.7** while the p10/p90 range widened from
**89.3/157.3** to **80.0/187.0**: the plated case remains dimensional instead
of flattening white or disappearing black.

### Validation

- Layout generation: exit 0; 14 toaster markers, 1718 assemblies, 599 total
  markers, and all furnishing/life audits passed.
- Godot editor rescan: exit 0.
- FAST WalkTest: **PASS in 14.4 seconds**. It asserts the exact 14-unit set,
  exercises the standard 2A path and measures the tray's full 160 mm travel.
- The Blender build, JSON synchronization and Godot import completed in the
  required order before the inspection render.
