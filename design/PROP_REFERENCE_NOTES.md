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

## Review progress — 2026-08-09

The ordered brief contains **24 review families**. **Sixteen are complete
(67%)**: all eight first-priority/gameplay families, all six second-priority
families, and the first two lighter-pass families. Every completed family has a reference comparison,
model and runtime-material pass, warehouse and installed renders, generated
data synchronized after the final edit, and automated validation.

| Priority | Complete | Remaining |
|---|---:|---:|
| First — carries a game | **8 / 8** | none |
| Second — touched often | **6 / 6** | none |
| Third — lighter pass | **2 / 10** | eight |
| **Total** | **16 / 24** | **8** |

Completed in review order: `fridge_prop`, `stove_prop`, `tap_prop`,
`toaster_prop`, `radiator_prop`, `boiler_prop`, `washer_prop` with
`laundry_airer_prop`, `vantry_point_prop`, `kettle_prop`,
`medicine_cabinet_prop`, and `clock_prop` with the domestic witness clocks.
The fourth through sixth second-priority families are `mail_bank_prop`,
`bookshelf_prop` and `door_prop`. The first two lighter families are
`boxfan_prop` and `exhaust_fan_prop`.

**Next:** `flue_breast_prop`. The mesh-count sweep
identified `stove_prop` as a later optimization candidate, but it is not
reopened unless performance work is explicitly scheduled.

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

## `radiator_prop` — American three-column one-pipe steam radiator

### What the real object was

The Orison's six-storey heating is one-pipe steam: one connection admits
steam and drains condensate in the opposite direction, while an automatic
air vent at the far end releases air so steam can enter. The American
Radiator Company's 1922 Corto catalog and Archer A. Landon's 1926 American
Radiator section patent show the right body language: repeated joined iron
castings with rounded header shoulders and narrow column waists, not a row of
independent pipes. William Russell's 1924 automatic radiator air-valve patent
supplies a period-correct far-end vent precedent. **HISTORICAL; CANONICAL.**

- https://heatinghelp.com/systems-help-center/american-radiator-companys-corto-1922/
- https://patents.google.com/patent/USD70077S/en
- https://patents.google.com/patent/US1490940A/en
- https://www.nyc.gov/assets/nycaccelerator/downloads/pdf/hprt-techprimer-1pipe-steam.pdf

The supply handwheel has healthy endpoints, open or shut. A partly closed
one-pipe valve admits steam while obstructing the water returning through the
same throat, causing poor heat and hammer. Building balance therefore belongs
to vent rate, radiator pitch and the finite boiler cycle rather than a bank of
twenty-three proportional supply knobs. **HISTORICAL; CANONICAL.**

### What we inherited

- Nine groups of four skinny freestanding cylinders under flat bars: closer
  to a fence than a joined cast radiator section.
- Box feet and a straight local pipe ending at an upper brass wheel.
- No automatic air vent, union, angle-valve body, visible riser branch,
  condensate pitch or service API.
- `metal`/`brass` semantic finishes instead of the staged `cast_iron` and
  `brass_dull` material sets.
- A continuous baked riser beside the body with no convincing termination.
- Twenty-three bodies that passed general furnishing checks even where a
  desk or workbench covered the fittings.
- An activity document describing hot-water bleeding and proportional valve
  positions in a one-pipe steam building.

### Built result

Seven-, eight- and nine-section bodies now share a measured maximum clearance
envelope. Each section is one three-column casting: narrow vertical waterways,
ellipsoidal shoulders, transverse top/bottom headers, nipple-shadow gaps and
integral end feet. Dark old enamel and later landlord silver use deterministic
household variation without creating another material family.

The installed assembly has a bottom-fed union, angle-valve body, rising stem,
six-spoke handwheel, building-owned slab-to-slab riser and a short prop-owned
branch visibly joining the two. The opposite upper end carries a removable
automatic vent with a local downward rust track. A small far-foot wood shim
records the deliberate pitch toward the supply. The first installed render
caught the generator/runtime yaw-sign mismatch placing the riser at the vent;
the final render rules the transform and shows the riser terminating beside
the supply valve.

`set_supply_open()` gives the healthy binary operation;
`set_supply_position()` exists so the maintenance activity can deliberately
demonstrate the partly-closed hammer fault. `set_vent_grade()` exchanges one of
five fixed service inserts, `set_pitch()` creates or corrects the condensate
fault, and `get_heat_state()` exposes heat, satisfaction, hiss and hammer.
Handwheel and vent retain separate named interaction areas after static mesh
merging.

`heat_balance.gd` is one finite building model over all 23 marker IDs. Faster
venting raises one radiator's share and reduces the rest; household target
temperatures turn a mathematically even allocation into an uneven complaint
problem. It consumes the existing `H-A` through `H-D` identities but does not
duplicate the acoustic graph: possession continues to travel through the
already-authored radiator-to-header chain.

The generator now proves five possible angled approaches to both fittings on
all 23 instances. It exposed three actual furnishing faults. Mina's complete
caption desk composition moved 700 mm into the room, Omar's complete repair
bench cluster moved 900 mm, and Sacha's falsely solid 2.4 m "desk legs" became
two real end frames with an open service bay. Paper, wall art, soot paint and
the shallow masonry water table are correctly treated as surfaces behind a
hand rather than floor obstacles.

### Materials and texture prompt batch

`cast_iron`, `brass_dull`, `metal` and the small existing `wood_dark` shim all
reuse staged runtime sets. No material key or source plate was added, so there
is no texture-generation batch for this family.

### Render evidence

Before:

- Warehouse blockout — `C:/shots/orison_prop_pass/radiator_before/stand_402_0.85_2.35_180_-10.png`
- 1D installed — `C:/shots/orison_prop_pass/radiator_before/stand_11.65_1.05_5.325_-90_-8.png`

After:

- Warehouse, seven-section dark — `C:/shots/orison_prop_pass/radiator_after/stand_402_0.90_2.25_180_-8.png`
- Warehouse, nine-section silver — `C:/shots/orison_prop_pass/radiator_after/stand_406_0.90_2.25_180_-8.png`
- 1D installed, partly closed service pose — `C:/shots/orison_prop_pass/radiator_after/stand_11.65_1.05_5.325_-90_-8.png`
- 6A, open service bay beneath capture desk — `C:/shots/orison_prop_pass/radiator_after/stand_-11.65_17.05_5.05_90_-8.png`

Installed frames use `SHOT_LIGHTS=1 SHOT_TORCH=1`; warehouse frames use the
shed's even inspection light. In the identical 1D crop, median RGB moved from
**(22, 11, 11)** to **(37, 20, 16)** and luma p10/50/p90 from
**0.2/13.2/77.7** to **0.3/23.2/80.9**. The body remains black cast iron in a
night room, but its shoulders, fittings and section gaps no longer disappear.

### Validation

- `python art/data/gen_layout.py` — exit 0: 23 radiator markers, all general
  movement checks, and both fitting-reach checks on every instance passed.
- Blender 4.5.12 build — exit 0: 232 mapped materials and all floor scenes
  exported; generated JSONs copied to the game and Godot 4.7.1 imported them.
- Real-window warehouse and installed inspection renders completed under the
  Compatibility renderer; the installed render corrected the first riser-end
  transform rather than accepting source coordinates as proof.
- FAST WalkTest exercises all 23 props, preserves the riser graph, forces a
  partly closed hammer, changes fixed vent grades, proves another flat loses
  heat, and proves total delivered heat remains constant. Final run:
  **PASS [FAST] in 12.6 seconds**, with the phone-cookie dummy-renderer warning
  removed rather than ignored.

## `boiler_prop` — original 1912 hand-fired sectional coal boiler

### What the real object was

American Radiator Company's 1910 *Ideal Fitter* and its 1920 Type A “Heat
Machine” advertising establish the right class of object: a coal-rated
cast-iron steam boiler assembled in sections, jacketed to contain heat and
dust, with long recoaling intervals and automatic draft regulation. A 1904
water-gauge patent shows that an exposed glass level tube with isolating cocks
and automatic protection was ordinary steam-boiler hardware well before the
Orison was built. **HISTORICAL; CANONICAL.**

- https://commons.wikimedia.org/wiki/File:The_Ideal_fitter_-_American_radiators_%26_Ideal_boilers_%28IA_idealfitterradia00amerrich%29.pdf
- https://usmodernist.org/AF/AF-1920-09.pdf
- https://patents.google.com/patent/US755456A/en

Oil burners were commercially real in the twenties; their availability is not
the reason for this choice. The activity's authored premise is that the
building's heart is older than every resident and still needs to be kept lit.
One surviving coal plant gives the player a firebed to bank, ash to rake, draft
to balance and a glass to watch. **FICTION RULING; CANONICAL.**

### What we inherited

- Three incompatible plants: an interactive 1.6 m round vertical tank at
  `(10.0, 5.0)`, a detailed but dead coal assembly at `(9.05, 1.55)`, and a
  later oil package at `(7.35, 1.62)`.
- The functional prop stood 3.58 m from the coal plant and 4.29 m from the oil
  plant, in open floor, while the acoustic graph repeated the same wrong magic
  coordinate.
- Its upper pipe reached roughly 3.25 m through a 2.72 m basement ceiling.
- A blank gauge disc, one oversized round hatch, no water glass, no grate,
  no ashpit, no draft control, no return and no credible chimney connection.
- `PROP_ACTIVITIES.md` asked the player to watch a “pilot,” which belongs to
  neither a hand-fired coal plant nor the physical tending game described.

### Built result

`B1_BOILER_01` is now the sole owner of the working plant at `(9.05, 1.55)`,
facing the service aisle. The baked coal and oil shells are removed. The
rewritten plant-room comment preserves the tableau's historical purpose: this
room now records a boiler that was never replaced, only patched. Ceiling steam
header, return and rear breeching visibly meet the prop, and the acoustic node
derives its position from the same marker instead of repeating a coordinate.

The body is a measured `1.16 x 1.02 m` five-section block on a concrete hearth,
under 2 m at its own fittings. It carries patched canvas lagging, steel bands,
an opening firing door, independent ash door, firebrick throat, real grate
bars and a coal bed inside the opening. A readable water glass has upper and
lower cocks plus a blow-down tail; the pressure gauge has a live needle. The
top carries a safety valve, takeoff and equalizer/return, while a weighted
barometric damper regulates the smoke hood and chimney breeching.

`boiler_tend.gd` advances coal, firebed, ash, draft, pressure and water on one
slow deterministic clock. Its output multiplies the existing finite radiator
budget and feeds the hot-water curve on every tap. Low water therefore cools
the building instead of changing only a gauge animation. The two doors,
damper, water fill and needle remain rigged; everything inside each rigid
assembly merges by material. The complete boiler is 19 meshes.

### Materials and texture prompt batch

`cast_iron`, `linen`, `metal`, `brass_dull` and `paper` reuse existing runtime
sets. `soot` already existed in `MATERIAL_CATALOG` and the source library but
was absent from `GODOT_STAGE` and `MatLib.SETS`; it now uses the shared charred
surface maps on the GDScript plant. No material key or source plate was added,
so there is no texture-generation batch for this family.

### Render evidence

Before:

- Warehouse tank blockout — `C:/shots/orison_prop_pass/boiler_before/stand_398_1.10_-14_180_-6.png`
- Installed third boiler — `C:/shots/orison_prop_pass/boiler_before/stand_10_-1.30_-7.4_180_-6.png`
- Separate baked coal and oil shells — `C:/shots/orison_prop_pass/boiler_before/stand_8.4_-1.25_-4.2_180_-5.png`

After:

- Warehouse, closed — `C:/shots/orison_prop_pass/boiler_after/closed2/stand_398_1.10_-14_180_-6.png`
- Installed, closed — `C:/shots/orison_prop_pass/boiler_after/closed2/stand_9.05_-1.30_0.25_0_-5.png`
- Installed, both service doors open — `C:/shots/orison_prop_pass/boiler_after/final/stand_9.05_-1.30_0.25_0_-5.png`
- Installed three-quarter service view — `C:/shots/orison_prop_pass/boiler_after/final/stand_7.65_-1.25_0.10_-22_-6.png`

Installed frames use `SHOT_LIGHTS=1 SHOT_TORCH=1`; the warehouse uses its even
inspection lighting. The old installed frame's median RGB was **(0, 0, 5)**
with luma p10/50/p90 **0.0/0.5/26.2**. The closed replacement is
**(42, 18, 12)** and **0.5/22.6/77.1**: still a night basement, but the water
glass, jacket, door hardware and gauge now survive the intended light.

### Validation

- `python art/data/gen_layout.py` — exit 0: 1,717 assemblies, 599 markers,
  23 radiator markers and exactly one boiler marker.
- Blender 5.2 build — exit 0: 232 mapped materials, 11 shader-only
  materials, every floor exported and the master blend saved. Generated JSONs
  were copied to `game/data/`, then Godot 4.7.1 completed its import pass.
- Material-source audit — 72 staged source slots, 0 problems. The existing
  charred-surface maps now reach the runtime `soot` set.
- Real-window warehouse and installed renders completed under the
  Compatibility renderer. Both the shut and independent two-door service
  poses were judged from pixels, not from source geometry.
- FAST WalkTest — **PASS [FAST]**. FULL WalkTest — **PASS [FULL]** at sim x4
  / 240 Hz in approximately 57 wall-clock seconds. The final assertions report
  **7.0 meshes per radiator across all 23** and **19 meshes for the boiler**;
  they also exercise its collider, service zones, independent doors, low-water
  heat starvation and the tending clock's heat/hot-water feed.

## `washer_prop` + `laundry_airer_prop` — 1920s basement wash line

### What the real objects were

An electric domestic washer in 1927 was an open tub on a frame, with an
electric gyrator below and a separate powered wringer above. Maytag's 1922
gyrator machines establish the mechanism and date; the operator still moved a
garment by hand through wash, rollers and rinse. Automatic tumble drying did
not belong here: the first domestic machines followed in the 1930s, with the
Hamilton June Day appearing in 1938. A shared tenement room dried on a raised
wooden-lath pulley airer. **HISTORICAL; CANONICAL.**

The Orison's machines use patched galvanised steel rather than the cast
aluminium associated with surviving Maytags. That keeps ordinary, non-signal
technology inside the 1927 rule and records a maintenance history instead of
making this basement a showroom. **FICTION RULING; CANONICAL.**

### What we inherited

- Three modern front-loading cubes at 0.80 m centres, including an automatic
  tumble dryer which post-dated the setting.
- Coin-laundry portholes, programme dials and sealed drums; none of the parts
  requested by `PROP_ACTIVITIES.md` could physically move.
- The brick pier did not collide with the row, but concealed its second and
  third machines from the room's useful approach.
- Both wet machines and the dryer were water nodes connected to the steam
  header. There was no cold-water-main node.
- No rinse stage, drying apparatus, supply cocks, drain, safety release or
  hand-reachable service points.

### Built result

The dryer is gone. Two electrically powered wringer washers stand 1.15 m apart
north of the pier, with two open rinse tubs and a ceiling pulley airer completing
the real wash path. Each washer has a hollow tub, bottom gyrator, independent
lid, swinging yoke, two rubber rollers, pressure screw, safety release, exposed
motor guard, belt housing, paired supply cocks and drain. The stable service API
opens the lid, swings the wringer, separates the rollers, runs agitation and
drain states, and makes the release give fractionally before the player touches
it. The ensemble supplies five named reach zones per washer and separate rinse
and airer zones.

The two washers bridge a real `B1_WATER_MAIN` and the electrical hub. The airer
runs through the laundry joists. None of them uses the steam header. The 4C case
beat now predicts a tiny icebox-latch sound—never a compressor—before voices
rise. Static parts merge by material; only the lid, gyrator, yoke, rollers,
pressure screw and release remain independently rigged.

### Materials and texture prompt batch

`enamel`, `brass_dull`, `wood_dark`, `linen` and the existing `zinc_liner`
response are reused. The last is deliberately used for the broad galvanised
faces: generic high-metallic steel rendered nearly black under the real
basement lamps, while dull zinc preserves both oxidation and silhouette.
`rubber_aged` is the one new catalog, ingest, staged and runtime material.

Paste-ready source prompt:

> square, high resolution, seamless tileable PBR material swatch, flat
> evenly-lit document scan, close crop of an aged black natural-rubber wringer
> roller, fine vulcanised grain, compressed polished band where wet fabric has
> passed, faint chalk bloom and hairline age checking, restrained 1920s service
> wear, no baked directional light, no perspective, no object silhouette, no
> letters, numbers, words, labels, brands or logos

### Render evidence

Before:

- Warehouse modern washer — `C:/shots/orison_prop_pass/washer_before/stand_410_1.15_14.35_0_-7.png`
- Installed front-loader row — `C:/shots/orison_prop_pass/washer_before/stand_-11.15_-1.30_-4.35_90_-7.png`

After:

- Warehouse wringer — `C:/shots/orison_prop_pass/washer_after/normal/stand_410_1.15_14.35_0_-7.png`
- Warehouse rinse tubs and airer — `C:/shots/orison_prop_pass/washer_after/normal/stand_398_1.25_2.85_0_-8.png`
- Installed complete line — `C:/shots/orison_prop_pass/washer_after/final_normal/stand_-9.65_-1.25_-6.55_90_-7.png`
- Installed service pose — `C:/shots/orison_prop_pass/washer_after/final_service/stand_-9.65_-1.25_-6.55_90_-7.png`

Installed frames use `SHOT_LIGHTS=1 SHOT_TORCH=1`. Replacing the broad-face
generic metal response with dull zinc moved the washer-region median luminance
from **60 to 68** and the tub-region median from **27 to 35** in the same crop.
The result stays dim and dirty, but the object boundaries now survive the
intended room light.

### Validation

- `python art/data/gen_layout.py` — exit 0: 1,721 assemblies, 599 markers,
  exactly two washers and one airer ensemble; no dryer marker remains.
- Blender 5.2 build — exit 0: 233 mapped materials, 11 shader-only materials,
  all floors exported and generated JSON copied to `game/data/`; Godot 4.7.1
  completed the import pass.
- Material-source audit — 73 staged source slots, 0 problems.
- FAST WalkTest — **PASS [FAST]**. It verifies count, 1.15 m spacing, all reach
  zones, service motion, the lowered airer, a **28-mesh** two-washer total,
  **6 meshes** for the airer, the cold-water main and absence of a steam-header
  edge. FULL WalkTest — **PASS [FULL]** at sim x4 / 240 Hz in 58.2 wall-clock
  seconds; its physical walks, elevator rides and complete case sequence also
  completed.

## `vantry_point_prop` — 1912 house-circuit listening head

### What the real object was

There was no domestic smoke detector to make prettier in 1927. Early fire
alarm systems were wired alarm-telegraph apparatus, while carbon telephone
transmitters had already established a practical diaphragm, granule chamber
and perforated mounting. The Orison's ruled object is therefore a building-
specific hybrid: a 1912 hard-wired Vantry point that listens for fire, flood
and line-test signals. Its signal function is forty years early under VIII.2;
its Bakelite-like moulded body, brass grille, cloth pair and mechanical flag
remain legible as installed apparatus rather than a modern detector in brown
paint. **HISTORICAL BASIS; FICTION RULING CANONICAL.** Reference anchors:
[Berliner carbon transmitter, 1897](https://patents.google.com/patent/US579699A/en),
[Gamewell alarm telegraph, 1909](https://patents.google.com/patent/US923114A/en),
and [Western Electric perforated transmitter mounting, 1927](https://patents.google.com/patent/US1636006A/en).

### What we inherited

- One 120 mm white cube in 4B, visually a modern domestic detector and absent
  from every other room.
- No service interior, moving face, line circuit, direction-finding job or
  relationship to Teresa's held-breath manifestation.
- The generic anomaly layer could still build a second detector-like object,
  while the acoustic graph had no dedicated signal trunk for either one.
- No `WorkOrders` implementation existed, so gating the chirp behind the named
  spine would simply have made the building silent.

### Built result

Every enclosed room except the roof and atrium volumes now receives one
230 mm ceiling point—119 in the current 127-room layout. The broad stepped
moulding, true-open radial brass grille, dark carbon diaphragm, three service
screws, paired terminals, exposed cloth-and-copper tail and red mechanical
telltale survive both room light and a five-foot worker's eye line. The captive
grille twists and drops to expose an interior with no battery bay.

Quiet points are one three-surface MultiMesh per floor: three static draws on
each of seven floors. One six-mesh `VantryPointProp` owns audio, interaction and
service motion. Promotion compacts only the affected floor's small transform
list and changes `visible_instance_count`, then restores the former face in the
same frame; this is the Compatibility-renderer-safe version of the invisible
handoff. The first minimal `WorkOrders` spine issues, persists, activates and
closes `WO-VANTRY-001`. `ChirpHunt` caches its source, waits 50–95 seconds
between attributed recorded chirps, propagates them through the dedicated
seven-floor signal trunk and closes only when the player opens the correct
grille. Teresa's 1D point uses the same network and closes a mechanical shutter
before she stops speaking. The old `smoke_detector` name remains a data/class
alias only.

### Materials and texture prompt batch

No material work was required. `bakelite_black`, `brass_mesh`, `copper_aged`
and `indicator_enamel` already travel through the runtime material library.
`linen` deliberately remains on its older `T_library_furniture_linen_*` path;
it was not added to `GODOT_STAGE`, which would have generated three unused,
competing files. Because no new surface exists, there is no texture prompt
batch for this family.

### Render evidence

Before:

- Warehouse white cube — `C:/shots/orison_prop_pass/vantry_before_close/stand_406_2.0_8.75_0_40.png`
- Installed 4B cube — `C:/shots/orison_prop_pass/vantry_before_close/stand_-9.5_11.45_-4.65_0_42.png`

After:

- Warehouse silhouette under even inspection light — `C:/shots/orison_prop_pass/vantry_after/warehouse/stand_402_2.0_13.4_0_25.png`
- Installed 4B, shut — `C:/shots/orison_prop_pass/vantry_after/close/stand_-11.06_11.55_-3.35_0_45.png`
- Installed 4B, captive grille open — `C:/shots/orison_prop_pass/vantry_after/service/stand_-11.06_11.55_-3.35_0_45.png`
- Teresa's 1D point in context — `C:/shots/orison_prop_pass/vantry_after/evidence/stand_9.96_2.0_8.8_0_45.png`

Installed frames use `SHOT_LIGHTS=1 SHOT_TORCH=1`; the warehouse uses its flat
inspection rig. The installed shut frame has median RGB **(124, 66, 39)** and
luma p10/50/p90 **20.3/76.5/190.6**. Its grille, terminal tail and stepped dark
body remain separable without lifting the building's night grade.

### Validation

- Final-source `python art/data/gen_layout.py` — exit 0: 1,721 assemblies,
  598 ordinary markers and one generated Vantry point for each of 119 eligible
  rooms. The validator derives this count from room data rather than freezing
  it as a constant, checks unique IDs, room bounds, ceiling seating, signal
  network ownership and absence of legacy smoke-detector markers.
- Blender 5.2 build — exit 0: 233 mapped materials, 11 shader-only materials,
  all eight levels exported; generated JSON was copied to `game/data/`, then
  Godot 4.7.1 completed its import pass.
- FAST WalkTest — **PASS [FAST]**. It verifies 119 points, seven floor batches,
  three static draws per floor, a six-mesh movable owner, the active persisted
  work order, cached chirp source, every signal-trunk edge, synchronous owner
  handoff, service pose, Teresa's telltale, attributed audio and correct-order
  closure. FULL WalkTest — **PASS [FULL]** at sim x4 / 240 Hz in 72.2
  wall-clock seconds; its physical walks, stair and elevator routes, complete
  case sequence and restoration checks also completed.

## `kettle_prop` — c.1925 formed-metal electric kettle

### What the real object was

Electric kettles are ordinary period domestic technology, not an Orison
divergence. A 1917 New York advertisement offered Hotpoint polished-nickel
electric tea kettles through New York, Queens and Long Island distributors;
the Science Museum's c.1925 General Electric example is 250 mm high by 170 mm
wide, with copper-plated versions combining brass fittings, Bakelite feet and
knob, and a wooden handle. Contemporary patents also establish detachable
heating terminals and kettle whistles before the building's present year.
**HISTORICAL.** Reference anchors: [New York Tribune Hotpoint advertisement,
1917](https://tile.loc.gov/storage-services/service/sgp/sgpbatches/batch_dlc_belleauwood_ver02/data/sn83030214/print/1917110401/0004.pdf),
[GE electric kettle, c.1925](https://collection.sciencemuseumgroup.org.uk/objects/co8408515),
[electric kettle patent, 1921](https://patents.google.com/patent/US1390028A/en),
and [combined kettle and whistle patent,
1915](https://patents.google.com/patent/US1161713A/en).

### What we inherited

- One 160 x 160 x 200 mm bright rectangular block in 4B, with a box handle
  and box spout: the silhouette was closer to a late electric jug than a
  formed 1920s vessel.
- No lid, whistle cap, heating well, terminal, cord, plug, water cavity or
  reachable service parts; the appliance could only switch and make sound.
- The only household was 4B, despite established kettle evidence in 1A, 3D,
  4C and 6C and Teresa's canonical night-shift vacuum flask.
- Switching off did not cancel its `SceneTreeTimer`. Restarting before the
  old due time made that stale timer whistle early during the new cycle.

### Built result

Six 180 mm formed vessels now occupy the former rear-mug socket in 1A, 1D,
3D, 4B, 4C and 6C. The stepped belly and shoulder, rolled seams, tapered
three-part spout, exposed heating well, detachable cloth lead, Bakelite plug,
wooden bail, removable lid and chained brass whistle keep the silhouette and
construction in 1925. Nickel and copper warehouse variants now remain beside
one another instead of wrapping across rows.

Finish belongs to the household. Evelyn's nickel is kept bright; Teresa's is
dull, mineral-ringed inside and fitted with a wrong squat replacement knob;
Rhea and 4C carry increasingly handled copper; 4B receives the landlord's
scuffed nickel; Mae's old copper is deliberately maintained. The lid, cap and
whole vessel have stable service APIs, steam begins only at a real boil, and a
generation token makes an interrupted timer harmless. Marker `F04_4C_KETTLE_01`
is explicitly bound to case `4519`, whose opening kettle cue is load-bearing.

### Materials and texture prompt batch

No new material or texture was required. `nickel_plated`, `copper_aged`,
`bakelite_black`, `rubber_aged`, `brass_dull`, `wood_dark` and `enamel` all
already have valid runtime paths through `MatLib.SETS`. There is therefore no
paste-ready generation batch for this family; inventing one would duplicate
surfaces already in the library.

### Render evidence

Before:

- Warehouse block — `C:/shots/orison_prop_pass/kettle_before/stand_410_1.05_-1.2_0_-10.png`
- Installed 4B block — `C:/shots/orison_prop_pass/kettle_before/stand_-10.5_10.95_-7.9_0_-12.png`

After:

- Nickel and copper family, side by side under flat inspection light —
  `C:/shots/orison_prop_pass/kettle_after/warehouse/stand_392_0.85_0.4_0_-5.png`
- Installed 4B service pose with room lights and torch —
  `C:/shots/orison_prop_pass/kettle_after/close/stand_-10.5_10.95_-7.9_0_-12.png`

The identical installed crop moves from median RGB **(109, 103, 112)** to
**(97, 96, 107)**, with luma p10/50/p90 moving from **31.9/105.2/161.9** to
**22.5/97.3/149.4**. The lower response is intentional: the old untextured
front was a luminous rectangle; the new dark formed silhouette retains metal,
wood, cap and handle separation in the required night lighting.

### Validation

- Final-source generator: exactly six kettle markers, exactly the ruled unit
  set, 49.5 mm at the 4B kettle/toaster gap and case `4519` retained on 4C.
- Blender 5.2: 233 mapped and 11 shader-only materials; eight levels exported,
  generated JSON copied to `game/data/`, Godot import completed.
- FAST WalkTest: **PASS [FAST]**. Six kettles, eight meshes each / 48 total,
  all four service reaches, full service pose, case evidence and stale-timer
  rejection pass. The family sweep also freezes improved averages for fridges
  (13.1), ranges (47.0), taps (15.4) and toasters (13.0); ranges fell from
  98 meshes each without sacrificing independently moving mechanisms.
- FULL WalkTest: **PASS [FULL]** at sim x4 / 240 Hz in 58.5 wall-clock
  seconds, including physical routes, the complete case sequence and the
  interrupted/restarted boil cycle in 4B.
- LightingAudit: **PASS**, 127 spaces with 11 intentionally ambient/dark;
  all 244 catalog fixtures and their local shadow casters remain covered.

## `medicine_cabinet_prop` — 1926 white-enamel mirror cabinet

### What the real object was

A January 1926 hardware advertisement offers a white-enamel medicine cabinet
for the bathroom. The contemporary object was already ordinary enough that a
1926-origin concealed-cabinet patent calls the projecting box with a tell-tale
mirror door old-fashioned and unsightly: the patent's concealed universal
hinge, beveled Venetian glass, wheel-cut ornament and glass studs are the
luxury alternative, not what a cheap Queens landlord supplied. The Orison's
cabinet is therefore the established folded-enamel rectangle with obvious pin
hinges, friction catch, shallow wall recess and plate-glass shelves. It carries
no signal. **HISTORICAL.** Reference anchors: [Wichita Hardware advertisement,
1926](https://texashistory.unt.edu/ark:/67531/metapth1773582/m1/8/?q=Pine+Needle)
and [concealed-cabinet continuation of a 1926 application](https://patents.google.com/patent/US1908831A/en).

### What we inherited

- A 440 x 500 mm luminous square without readable cabinet depth, flange,
  fasteners, shelf clips, hinge barrels, backing plate or mechanical catch.
- The supposed back plate sat at local Z -0.225, farther into the room than
  the trim. Opening the mirror exposed another white rectangle in front of the
  shelves; closed and open renders were visually indistinguishable.
- Every leaf was left-hinged and swung 1.9 radians (108.86 degrees), with no
  return-wall, faucet, sconce or worker-position clearance audit.
- 2D, 3C, 5D, 6D and the lobby public lavatory were absent from `KEPT` and
  silently inherited the player's aspirin, iodine and razor.
- All markers claimed a water network. `acoustic_graph()` has never created a
  mirror node, so the field was dead metadata rather than propagation.

### Built result

Twenty-three 460 x 610 mm cabinets now carry a real wall-depth order: rolled
enamel mounting flange and screws at the plaster, folded box into the wall,
visible cavity, two clipped plate-glass shelves, and the mirror leaf on the
room side. The leaf has an enamelled steel back, nickel channel frame, two pin
hinges, friction catch and pull. It opens 95 degrees. `hinge_side` is authored
from the resident's view at the basin and chosen from bathroom geometry; both
hands occur in the building. The rebuilt family moved onto the same local -Z
front/yaw contract as the other complete props after the clearance sweep
proved the legacy negated transform opened every east/west cabinet into its
mounting wall.

Every cabinet now owns one interaction volume and an explicit inventory.
Sealed and vacant flats are empty, 5D retains one landlord-left tin, and the
public lavatory holds only carbolic soap and plasters. The data field is now
`network: structural`, but cabinets remain absent from the acoustic graph; no
test pretends a new propagation feature exists. Closed and open variants stand
side by side in the warehouse, whose copy turns 180 degrees so the generic
wall backing no longer covers its face.

### Materials and texture prompt batch

`enamel` and `nickel_plated` are reused. One new key, `mirror_aged`, travels
through `MATERIAL_CATALOG`, `GODOT_STAGE` and `MatLib.SETS`. `glassish` remains
Blender-only by design. The generated source is
`art/textures/ai_sources/mirror_aged.png`; the ingest derives and stages the
runtime albedo, roughness and normal set.

```
Square, high-resolution, seamless, flat evenly-lit document-scan material swatch of aged early-twentieth-century back-silvered bathroom mirror viewed from the glass side; pale cool silver-grey with faint warm mercury-grey clouding, sparse black pinprick oxidation, subtle damp haze and very fine cleaning scratches, extremely low contrast, no reflected room, no reflected objects or people, no highlights, no perspective, no frame, no border, no watermark, no letters, numbers, words, labels, symbols or logos. Edge-to-edge infinitely wrapping surface, production-ready base color asset.
```

### Render evidence

Before:

- Warehouse side silhouette — `C:/shots/orison_prop_pass/medicine_cabinet_before/warehouse_side/stand_407.4_1.35_-2.0_-90_0.png`
- Installed 4B, closed — `C:/shots/orison_prop_pass/medicine_cabinet_before/in_situ_detail/stand_-5.83_10.95_-5.20_0_0.png`
- Installed 4B, commanded open — `C:/shots/orison_prop_pass/medicine_cabinet_before/in_situ_open/stand_-5.83_10.95_-5.20_0_0.png`

After:

- Closed/open warehouse family — `C:/shots/orison_prop_pass/medicine_cabinet_after/warehouse/stand_392_1.35_4.6_0_0.png`
- Installed 4B, closed — `C:/shots/orison_prop_pass/medicine_cabinet_after/in_situ_closed/stand_-5.83_10.95_-5.20_0_0.png`
- Installed 4B, open — `C:/shots/orison_prop_pass/medicine_cabinet_after/in_situ_open/stand_-5.83_10.95_-5.20_0_0.png`

Installed frames use `SHOT_LIGHTS=1 SHOT_TORCH=1`. Before, the cabinet crop's
closed/open median luma was **141.4/141.2**: moving the door disclosed nothing.
After, it is **45.6/134.9**. The closed aged glass no longer glows like paper,
and the open pose visibly reveals the cavity, shelves, contents and door back.

### Validation

- Final-source generator: 23 mirror markers, two geometry-derived hinge sides,
  every marker structural, and no mirror node added to the acoustic graph.
- The family remains at **150 meshes total**, every individual cabinet at or
  below eight meshes.
- WalkTest verifies count, both hands, interaction, explicit exceptional
  inventories, 95-degree motion, shut return, graph absence, independent
  family budget, and every sweep against real wall collision, basin fittings,
  sconces and the five-foot worker's basin position.
- FAST and FULL WalkTest both pass; FULL completed at sim x4 / 240 Hz in
  59.8 wall-clock seconds. LightingAudit passes all 127 spaces with 11
  intentionally ambient/dark.

## `clock_prop` + `domestic_witness_clock` — house time and case time

### What the real objects were

The ordinary apartment clock is a cheap second-hand eight-day American
drop-octagon: roughly a twelve-inch dial in a sixteen-inch oak case, brass
bezel, two winding arbors and a visible pendulum below. Drop-octagon and
schoolhouse regulators remained ordinary catalogue goods into the late 1920s.
The player winds the time train; the clock stops when its spring is spent.
**HISTORICAL; CANONICAL.** References: the Smithsonian's
[wall regulator](https://americanhistory.si.edu/collections/object/nmah_1172811),
the Henry Ford's [drop-octagon wall clock](https://www.thehenryford.org/collections/explore/artifact/166687),
a [1920 winding-key patent](https://patents.google.com/patent/US1358457A/en),
and the [Pequegnat catalogue survey](https://skipkerr.com/pequegnat-clocks/pequegnat-wall-clocks/).

The lobby master is not a decorative domestic movement. Early electrical
master/secondary clock systems already existed; Vantry's house-time signal
licenses a sealed receiver through the Divergence's 1967 ceiling. It is
authoritative, permanent, and four minutes fast. Reference:
[1918 electrical clock system patent](https://patents.google.com/patent/US1283431A/en).

### What we inherited

- `clock_prop` was one 280 mm bare disc with fixed L-shaped hands, no glazing,
  collision, interaction, spring, winding point, work order, material pass or
  relationship to the lobby. Its only marker was incorrectly electrical and
  intersected 4B's door zone.
- Eighteen case witnesses existed, but all were forced onto one low wall before
  later art ignored them. Three post-1967-looking forms had no recorded signal
  licence; Malcolm's non-signal sunburst and 4D's motel alarm were simply late.
- `PROP_ACTIVITIES` simultaneously said to wind the witnesses and forbade
  gamifying them. The more specific case-system rule now governs.

### Built result

4B now owns the measured oak drop-octagon, with brass bezel, paper dial,
winding holes, pendulum, clear optical glass and an eight-day reserve that
actually stops the hands. Holding the winding interaction completes
`WO-CLOCK-001`. The clock is structural, not electrical—the same category
correction previously made for fourteen iceboxes. The lobby owns a separate
sealed Bakelite/enamel/brass Vantry receiver on the signal trunk, placed beside
the resident directory and clear of the historic advertisement board.

The eighteen witnesses remain case props and receive no maintenance action.
Juno's Vantry modular clock, Cal's split-flap receiver and Sacha's Nixie display
are signal-bearing designs capped at 1967. Malcolm gets a mechanical 1920s
sunray; the Transient Guests get a nickel folding travelling alarm that packs.
All witnesses reserve real wall or furniture space before art. Cam uses 4C's
wall budget while Noel's protected mantel clock occupies a shelf surface.

### Materials and texture prompt batch

No new material key and no texture batch. `oak_quartered`, `wood_dark`,
`brass_dull`, `nickel_plated`, `enamel`, `paper` and `bakelite_black` already
have runtime sets. Clear clock glass is an optical runtime material; baking a
room reflection into a bitmap would make every clock repeat the same room.

### Render evidence

Before:

- Warehouse generic disc — `C:/shots/orison_prop_pass/clock_before/stand_398_1.45_16_0_0.png`
- Installed 4B wall/door context — `C:/shots/orison_prop_pass/clock_before/stand_-9.25_11.30_4.60_-90_0.png`
- 2A/6A witness and art overlap — `C:/shots/orison_prop_pass/clock_before/stand_-11.29_4.98_-4.70_0_0.png`

After:

- Both honest warehouse variants — `C:/shots/orison_prop_pass/clock_after/warehouse/stand_400_1.45_18_0_0.png`
- 4B drop-octagon installed — `C:/shots/orison_prop_pass/clock_after/details/stand_-9.37_11.10_-4.40_180_0.png`
- Lobby master beside the directory — `C:/shots/orison_prop_pass/clock_after/details/stand_3.50_1.50_8.97_-90_0.png`
- Cam witness with reserved art spacing — `C:/shots/orison_prop_pass/clock_after/in_situ/f04_c_main_room.png`
- Juno signal clock with reserved art spacing — `C:/shots/orison_prop_pass/clock_after/in_situ/f02_c_main_room.png`
- Noel's shelf clock — `C:/shots/orison_prop_pass/clock_after/details/stand_10.20_11.10_-4.30_0_0.png`

Installed crops were measured, not brightened by eye. Median RGB/luma is
**(182,141,140)/146.3** for 4B, **(118,96,92)/99.9** for the lobby master,
**(44,16,18)/22.4** for Cam, **(98,109,129)/107.5** for Juno, and
**(111,55,38)/64.6** for Noel; the flat-light warehouse crop reaches luma
p90 **122.4** despite the intentionally black wall backers.

### Validation

- Generator and graph: exactly two `wall_clock` markers; 4B structural and
  lobby signal, both present on the corresponding propagation path.
- FAST WalkTest: **PASS**. It verifies 20 clocks, the five historical/signal
  rulings, independent wall/surface budgets in 4C, five-foot readability,
  4B door clearance, spring exhaustion, winding/order closure and the lobby's
  fixed error. Every clock is at or below ten meshes; the family totals
  **156 meshes**, below its independent 160 limit.
- FULL WalkTest: **PASS** on the clean rerun at sim x4 / 240 Hz in **63.4
  wall-clock seconds**. The first run encountered the existing stochastic
  monitor-door roof-route failure; no clock assertion failed, and the rerun
  completed with exit code 0.
- LightingAudit: **PASS** for all **127 spaces**, including the 11 spaces
  intentionally classified as ambient/dark.

## `mail_bank_prop` — the lobby tenant bank

### What the real object was

The Orison calls the bank Cutler-descended, but Cutler's 1920 Model F is the
large receiving box at the foot of a mail chute, not the tenant compartments
above it. The useful subtype is S. H. Couch's 1915 apartment-house bank:
inclined sheet-metal pockets behind one faceplate, horizontally swinging
tenant leaves on a common concealed hinge, an upper gravity delivery flap,
glass identification window and keyed cylinder. Francis Keil's 1889 catalogue
corroborates the long, low bronze-box proportion and the wood mounting frame.
The bank carries no signal, so this is ordinary 1912 hardware still working in
1927—not Divergence technology. **HISTORICAL; CANONICAL.**

Sources:

- Smithsonian National Postal Museum, [Cutler Model F mailbox, 1920](https://postalmuseum.si.edu/object/npm_0.279485.1.1)
- S. H. Couch, [US1173961A apartment-house letter box, filed 1915](https://patents.google.com/patent/US1173961A/en)
- Francis Keil, [Illustrated catalogue of apartment-house letter boxes, 1889](https://upload.wikimedia.org/wikipedia/commons/d/d7/Illustrated_catalogue..._%28IA_illustratedcatal00keil%29.pdf)

### What we inherited

- Twenty-four 240 x 200 mm nearly square doors made the wall read as a safe-
  deposit bank. Every leaf carried body, bevel, card, frame and lock as a
  separate draw—roughly 149 meshes for one static lobby elevation.
- The absolute card and lock dimensions happened to fit the old 148 mm leaf;
  shrinking the cell without re-deriving them would have floated both off it.
- There was no carrier insertion flap and no inclined-pocket read. All twenty-
  four cards implied occupied households, although only eighteen units have
  resident profiles.
- The bank overlapped the built Vantry master at `(5.225, -8.970, 1.95)` and
  the separately hard-coded post tray could not follow a placement change.
- The 4B hinge inherited a room-side sign error. The first after render showed
  the cavity but not the leaf: it had swung into the wall.
- `MailBankProp` was absent from the warehouse registry. Source inspection
  therefore had no flat-light silhouette or one-metre-grid comparison at all.

### Built result

The elevation is now a 4 x 6 Couch-pattern array of 310 x 140 mm cells, with
its base at 0.92 m and box 4B centred at the five-foot worker's 1.41 m eye
line. Carrier flaps live in the shared faceplate above the occupied leaves;
each leaf has room only for its glass card and low keyed cylinder. Six units
without resident profiles—1B, 1C, 2D, 3C, 5D and 6D—remain literal recessed
dark gaps rather than invented tenants.

The sole functional leaf, 4B, opens 95 degrees into the lobby and reveals the
existing delivery contents. Delivery gates, upgrades, dialogue, persistence
and Dead Letters are unchanged. The bank centre is the measured Blender
`y = -7.88`; the tray derives from it at `+0.48`, while the layout-owned clock
stays untouched. Closed bank, open sweep, tray, clock and worker standing lane
all clear independently.

The 17 fixed occupied doors, six empty pockets, shared faceplate hardware and
surround merge by material. Seventeen fixed name cards bake their atlas regions
into vertex UVs under one material; the first render caught and corrected the
back-face U reversal. The closed bank is **13 meshes**, removing roughly 136
from the lobby. `MailBankProp` now inherits the ordinary prop base solely so it
can enter the review registry; it does not join a propagation network. The
warehouse infers its wall datum generically because its complete depth lies
behind local origin, preserving the rule that a prop describes its own mount.

### Materials and texture prompt batch

No new material key and no texture batch. `oak_quartered`, `brass_dull`,
`brass_bright` and `paper` already have valid runtime paths. The placed card
and header atlases retain necessary authored lettering; `paper` remains on its
older library path and is deliberately not duplicated through `GODOT_STAGE`.

### Render evidence

Before:

- Installed lobby bank — `C:/PleaseRemainOnTheLine/art/renders/mail_bank_review/before/b_43_mail_bank.png`
- Warehouse — unavailable by construction: the prop was absent from the
  registry, which was itself a review defect.

After:

- Flat-light warehouse specimen — `C:/PleaseRemainOnTheLine/art/renders/mail_bank_review/after/warehouse/warehouse_mail_bank.png`
- Installed, closed — `C:/PleaseRemainOnTheLine/art/renders/mail_bank_review/after/installed_closed/stand_3.2_1.45_7.55_-99_5.png`
- Installed, 4B open — `C:/PleaseRemainOnTheLine/art/renders/mail_bank_review/after/installed_open/stand_3.2_1.45_7.55_-99_5.png`
- Installed, 4B open detail — `C:/PleaseRemainOnTheLine/art/renders/mail_bank_review/after/installed_open_detail/stand_4.0_1.42_7.20_-123_0.png`

The installed closed/open bank crops measure median RGB/luma
**(99,57,40)/64.6** and **(92,55,38)/61.7**. The flat-light warehouse crop is
**(157,120,83)/125.5**, with luma p90 **176.3**; the details are present rather
than accepted by brightening a dark frame by eye.

### Validation

- `MailBankTest`: **PASS**. It verifies 24 addresses, 18 occupied boxes, six
  empty slots, faceplate flaps, 4B height and 95-degree room-side motion, the
  13-mesh cap, every delivery gate, persistence and upgrade grant.
- FAST WalkTest: **PASS**. It verifies measured placement, derived tray,
  master-clock clearance, open sweep and worker standing lane.
- FULL WalkTest reached **PASS** in **63.8 wall-clock seconds** with every mail
  assertion green. The run also reported parse errors from concurrent,
  unrelated uncommitted `arcade_cabinet_prop.gd` work; that file was not
  changed or folded into this pass.
- LightingAudit: **PASS** for all **127 spaces**, including 11 intentionally
  ambient/dark spaces.

## `bookshelf_prop` — resident bookcases

### What the real objects were

Globe-Wernicke's 1907 “Elastic” catalogue describes the sectional form: a
base, stackable glazed units and cornice, expanded one section at a time. The
Smithsonian's 1899–1929 example has four dark-mahogany glazed sections with
brushed-brass fittings. That is the right aspirational object for archivist
Mae and exacting Peter. Ordinary inherited open oak cases and repaired board
shelves cover the less prosperous households. None carries a signal, so all
three remain ordinary, second-hand 1927 furniture. **HISTORICAL; CANONICAL.**

Sources:

- Smithsonian Libraries, [Stacking the Books: The Globe-Wernicke Elastic Bookcase](https://blog.library.si.edu/blog/2019/04/11/stacking-the-books/)
- National Museum of African American History and Culture, [Sectional bookcase, 1899–1929](https://nmaahc.si.edu/object/nmaahc_2011.12.8a-f)

### What we inherited

- Eight interactive shelves were 500 mm-high floating boxes sharing one
  silhouette. Their books intersected the middle board and cost one mesh each.
- A separate 1.85 m steel-ladder `asm_shelf` duplicated the same ownership in
  six households; Mina's three studio racks and Nadia's plan rack also carried
  generic books unrelated to their actual use.
- Runtime placement chose the exterior wall without examining openings. Five
  of eight cases crossed windows, and the result was absent from versioned
  layout data and the Blender context.
- The warehouse had no `bookshelf` registry entry. Mae's covenant prospectus
  could be omitted by the deterministic random deal.

### Built result

Eight generator-authored markers now choose a solid living-room boundary,
reject openings and clear both the case footprint and a 550 mm standing/reach
strip. The chosen wall index and measured coordinate are written to layout and
validated at build time. Generic domestic shelf assemblies are removed; Mina's
three studio racks and Nadia's plan rack remain as useful storage with their
generic books removed.

The family now has three silhouettes: dark three-tier glazed sectionals for
Mae and Peter, inherited open oak cases for Iris, Nadia and Jonah, and visibly
repaired board cases for Mina, Sacha and Malcolm. Sectional glass lifts into
its own pocket rather than swinging into the room. Its three door meshes remain
outside `merge_static`; the fixed body still batches normally.

Every cover, rubbed band and page block is emitted into one of two shared
vertex-colour meshes. Colour variation therefore survives without causing
`_material_key()` to split the family back into a draw per book. The active
run tops out at 1.18 m, below the five-foot worker's 1.41 m eye line. Mae's
1912 Orison prospectus is required by `library.json`, repeated on her layout
marker and kept behind the upper glass tier.

### Materials and texture prompt batch

No new key and no prompt batch. `oak_quartered`, `wood_dark`, `linen`, `paper`
and `brass_dull` already have valid runtime paths. `linen` continues through
the older library path and is deliberately not duplicated in `GODOT_STAGE`.
The sectional pane is optical runtime glass with no reflected room baked in.

### Render evidence

Before:

- `C:/PleaseRemainOnTheLine/art/renders/bookshelf_review/before/f02_a_main_room.png`
- `C:/PleaseRemainOnTheLine/art/renders/bookshelf_review/before/f03_a_main_room.png`
- `C:/PleaseRemainOnTheLine/art/renders/bookshelf_review/before/f05_c_main_room.png`
- `C:/PleaseRemainOnTheLine/art/renders/bookshelf_review/before/f06_c_main_room.png`
- Warehouse unavailable: the kind was absent from the registry.

After:

- Family warehouse comparison — `C:/PleaseRemainOnTheLine/art/renders/bookshelf_review/after/warehouse_bookshelf.png`
- Mina — `C:/PleaseRemainOnTheLine/art/renders/bookshelf_review/after/f02_a_main_room.png`
- Peter — `C:/PleaseRemainOnTheLine/art/renders/bookshelf_review/after/f04_a_main_room.png`
- Iris — `C:/PleaseRemainOnTheLine/art/renders/bookshelf_review/after/f05_c_main_room.png`
- Mae — `C:/PleaseRemainOnTheLine/art/renders/bookshelf_review/after/f06_c_main_room.png`

The first warehouse render exposed an opaque full-face sash that hid every
book. Four perimeter rails replaced it before the accepted render. This is the
render-verification defect source inspection and mesh assertions did not catch.

### Validation

- `BookshelfTest`: **PASS**. Plain/repaired/sectional cases render in **4 / 5 /
  7 meshes**, keep books in two batches, retain one door per glazed tier, lift
  without a room-side sweep, stay below eye line and retain the prospectus.
- Generator: **8 unique owners**, solid backing walls, no openings, no generic
  domestic duplicate, Mina's three racks and Nadia's plan rack book-free.
- FULL WalkTest: **PASS** at sim x4 / 240 Hz in **61.7 wall-clock seconds**.
  It verifies all eight owners, three silhouettes, the 64-mesh family cap and
  Mae's canonical title in the assembled building.

## `door_prop` — reopening joinery and shop leaves

### What the real objects were

The 1928 apartment-house door was contractor joinery: a standardized painted
stile-and-rail leaf with recessed fields, mortised butt hinges and a knob on a
long backplate. Corridor entries accumulated a closer, peephole, kick plate
and replacement lock; bedroom and bath leaves did not inherit that entire
security stack. Service rooms used reinforced sheet-metal or boarded leaves.
A retail entrance was a narrow timber carcass around a large clear pane, built
to disclose the shop rather than hide it. **HISTORICAL; CANONICAL.**

The landmark entrance remains the 1928 reopening door. Nothing was re-dated:
the 1912 fabric is older, the address and its paper trail begin in 1928, and no
door explains the missing years. Ordinary leaves are consequently plainer and
more uniform than the Vantry-era structure around them. **CANONICAL.**

Reference families: Russwin and Corbin 1920s builders' hardware catalogues;
Sweet's 1927 architectural catalogue; surviving New York glazed shopfronts and
apartment-corridor joinery documented by the Building Technology Heritage
Library.

### What we inherited

- Width was the subtype. Every leaf wider than 850 mm became an apartment
  entry with the same kick plate, peephole, three elaborate hinges and closer.
- Lock state was the finish specification, so locking a painted wood door
  silently converted it to galvanized metal.
- Panel fields were shallow boxes pasted onto a slab. Both leaves of each butt
  hinge rotated with the door, visibly pulling the jamb half away.
- Storefront leaves were opaque and concealed the eleven interiors they were
  meant to advertise.
- All 120 actors were root-owned but absent from storey streaming and from the
  performance census. Roughly 4,489 door meshes rendered on every floor and in
  every applicable shadow view while the reported census omitted them.
- The movement audit skipped every exterior/shop leaf. The first real audit
  found the radio-service cone display inside its door sweep.

### Built result

The generator now emits `subtype`, `unit`, adjacent room ids and a stable
finish variant for every one of the 120 markers. Runtime consumes those facts;
it no longer re-derives household identity from geometry. The resulting family
is 23 apartment entries plus the landmark, 55 apartment-interior leaves, 23
service leaves, 13 glazed storefronts, two exterior-service leaves and three
cabinet leaves.

Residential leaves share economical 1928 two-field joinery, with darker
corridor finishes and security hardware only on entries. Service leaves have
galvanized skins and a physical Z-brace. Storefront leaves are oak carcasses
with optical runtime glass, so the shop remains visible through the closed
door. Locking changes behavior only. Jamb-side hinge barrels and saddles are
fixed; the leaf, collision and player/NPC APIs remain animated together.

Doors remain plain `Node3D` actors by design. A shared `StaticMeshBatcher`
gives them and the mail bank FunctionalProp's batching discipline without
subscribing architectural joinery to the signal and possession systems. The
warehouse now inspects either class through optional methods, making plain
`Node3D` the canonical pattern. The mail bank returns to that base.

All doors now follow the floor visibility gate and the census includes them.
The assembled family is **575 meshes**, under the 600 cap and down about 87%
from the uncounted predecessor. Exterior door sweeps are audited against real
fittings while exempting only their own named jamb/storefront fabric; the cone
speaker moved 250 mm deeper after failing that audit. Furniture-aware resident
navigation remains the separate open R6 task.

The 1080p windowed probe confirms that this was not bookkeeping theatre. The
F04 corridor fell from the last recorded **39.62 ms to 27.11 ms**, and its
render submissions from roughly **26,269 to 13,265 objects**. Lobby is 27.42
ms, atrium 38.59 ms and 4B 17.69 ms. Six of seven stations remain over the
16.6 ms target, but doors are no longer the hidden all-floor multiplier.

### Materials and texture prompt batch

No new key and no prompt batch. `trim`, `wood_dark`, `oak_quartered`,
`brass_dull`, `metal` and `cast_iron` already have complete runtime paths.
Storefront glass is optical runtime material rather than a bitmap with a room
or highlight baked into it.

### Render evidence

Before:

- Corridor family — `C:/PleaseRemainOnTheLine/art/renders/door_review/before/f04_corridor_room.png`
- Installed 4B context — `C:/PleaseRemainOnTheLine/art/renders/door_review/before/f04_b_main_room.png`
- Warehouse unavailable: `DoorProp` was outside the FunctionalProp-only
  registry contract.

After:

- Six silhouettes together — `C:/PleaseRemainOnTheLine/art/renders/door_review/after/warehouse_door.png`
- F04 corridor repetition — `C:/PleaseRemainOnTheLine/art/renders/door_review/after/b_03_corridor_f04.png`
- 4B entry close — `C:/PleaseRemainOnTheLine/art/renders/door_review/after/b_80_door_4b_close.png`
- Radio-service glazed leaf — `C:/PleaseRemainOnTheLine/art/renders/door_review/after/b_81_door_radio_close.png`
- Lobby context — `C:/PleaseRemainOnTheLine/art/renders/door_review/after/b_02_lobby.png`
- Street/elevation context — `C:/PleaseRemainOnTheLine/art/renders/door_review/after/b_16_street_level.png`

Measured rather than judged only by a dark frame: corridor / 4B close / shop
close mean luminance is **52.0 / 46.3 / 45.7**, with 95th-percentile luminance
**92 / 84 / 117**. The scene retains its night range without losing the leaf
silhouettes or glazed shop interior.

### Validation

- Generator and Blender pipeline: **PASS**; 120 classified markers, exterior
  sweep audit green, generated layout synchronized after the final edit.
- FULL WalkTest: **PASS** in **61.2 seconds**. It verifies the semantic counts,
  explicit entry units, floor streaming and the 575-mesh family cap while
  physically traversing the building.
- LightingAudit: **PASS** for all 127 spaces. ShopEntryTest and MailBankTest:
  **PASS**. WarehouseTeleportTest: **PASS**, 65 displays from 44 kinds.

## `boxfan_prop`

### What the real object was

`boxfan` remains the serialized compatibility name, not the description of
the object. A square window box fan would be the wrong postwar silhouette.
The real household object available to a Queens tenant was a portable desk or
floor fan: a heavy cast-metal base, exposed cylindrical motor, broad blades,
deep wire guard, carrying handle and cloth-covered line cord. The Henry Ford
dates its comparable Westinghouse example to **1920–1927**, and Springfield
Museums records electric fans as a popular 1920s product before domestic air
conditioning. The fan carries no signal, so it receives no divergent licence:
it is ordinary 1927 electrical hardware, bought second-hand. **HISTORICAL;
CANONICAL.**

Reference objects:

- [Westinghouse Electric Fan, 1920–1927 — The Henry Ford](https://www.thehenryford.org/collections/explore/artifact/318696)
- [Westinghouse Electric Fan — Springfield Museums](https://springfieldmuseums.org/blog/portfolio-item/westinghouse-electric-fan-westinghouse-electric-company/)

### What we inherited

- Two fans existed although the appliance bible named three households and
  the standing player-flat ruling required a fourth. 2C and 5C were absent;
  6A and 4B followed different authoring paths.
- The rotor was distributed in the local XY plane but rotated around local Y,
  so the blades tumbled instead of spinning about their shaft.
- `_process()` spun and hummed unconditionally. The selector was scenery, and
  the header's “never stops dead” motif contract made an ordinary switched-off
  appliance impossible.
- 6A's marker floated 250 mm above the floor. 4B's occupied an unreadable gap
  between furniture. The old model had a generic ring on legs: no massive
  base, deep motor, front/rear guard, handle, speed selector, cord termination
  or plug to carry the activity.
- The proposed unseen plug change had no supporting sightline machinery. A
  camera-forward or frustum shortcut would still fire through an open doorway
  and would be brittle in headless validation.

### Built result

There are now exactly four: Juno's black fan in 2C, the landlord's plain fan
in 4B, Iris's green fan in 5C and Sacha's dull-nickel fan in 6A. All four are
floor-seated, explicitly room-owned and checked against the generator's real
furniture and door-sweep obstacles. The first proposed 2C position failed that
audit against `F02_DOOR_11`; the marker moved 450 mm rather than weakening the
rule. Counting the final built layout covers both the standard `dress_unit()`
path and 4B's bespoke marker.

The rebuilt silhouette follows the 1920–27 reference family: 440 mm sweep,
cast base and neck, trunnions, deep motor can, two concentric wire guards,
four broad blades, rear vents, carrying handle, selector, cloth cord and a
separate two-pin plug. The rotor now turns around its actual local Z shaft.
The selector provides 0–1–2–3, speed and hum coast together, and a motif accent
does nothing while the appliance is off.

Only 6A may break that physical contract. Possession arms while the player is
in Sacha's room, waits for a room exit, then puts the plug on the floor while
the blades continue. It waits for the player to return before exhibiting the
beat, leaves the impossible evidence behind, and restores the connection only
after a second exit. This uses the building's authored room partition rather
than new camera or occlusion machinery; it is deterministic and testable. The
other three fans always obey their switches.

Static components are merged by material while rotor, selector and plug stay
independent. The result is **9 visible meshes per fan / 36 across the family**.
That is 44% cheaper per appliance than the inherited approximately sixteen,
but four meshes more at family level because two missing households were
restored. Both facts are intentional.

### Materials and texture prompt batch

No new material key and no texture batch. `cast_iron`, `metal`,
`brass_dull`, `bakelite_black`, `rubber_aged` and `linen` already have valid
runtime paths. `linen` deliberately remains on its older
`T_library_furniture_linen_*` path; adding it to `GODOT_STAGE` would create an
unused competing texture set.

### Render evidence

Before:

- Single inherited silhouette — `C:/PleaseRemainOnTheLine/art/renders/boxfan_review/before/warehouse_boxfan.png`
- 4B context — `C:/PleaseRemainOnTheLine/art/renders/boxfan_review/before/f04_b_main_room.png`
- 6A context — `C:/PleaseRemainOnTheLine/art/renders/boxfan_review/before/f06_a_main_room.png`

After:

- Four household variants — `C:/PleaseRemainOnTheLine/art/renders/boxfan_review/after/warehouse_boxfan.png`
- 2C placement — `C:/PleaseRemainOnTheLine/art/renders/boxfan_review/after/stand_10.2_4.4_-3.6_-45_-20.png`
- 4B placement — `C:/PleaseRemainOnTheLine/art/renders/boxfan_review/after/stand_-11.5_10.8_-4.5_48_-20.png`
- 5C context — `C:/PleaseRemainOnTheLine/art/renders/boxfan_review/after/f05_c_main_room.png`
- 6A unplugged/running evidence — `C:/PleaseRemainOnTheLine/art/renders/boxfan_review/after/stand_-8.4_17.3_7.0_-132_-15.png`

Measured rather than accepted from a dark frame: mean sRGB for 2C / 4B / 6A
is **(89.7, 62.9, 49.4) / (83.5, 67.5, 59.7) / (41.7, 29.0, 24.6)**.
The darkest evidence frame still separates the nickel motor, black cage,
wood floor and loose plug; the light has not been raised to sell the prop.

### Validation

- Generator and full asset pipeline: **PASS**; four authored owners, all
  grounded, room-contained, electrically networked and clear of fixed
  obstacles; generated data synchronized after the last source edit.
- Fast WalkTest: **PASS**; four owner identities, 9/36 mesh caps, selector and
  off-motif behavior, service anchors, and the complete exit/return/exhibit/
  second-exit possession sequence.
- FULL WalkTest: **PASS** in **59.6 seconds**. LightingAudit: **PASS** for all
  127 spaces. WarehouseTeleportTest: **PASS**, with four fan variants among
  68 displays from 44 kinds.

## `exhaust_fan_prop`

### What the real system was

The relevant 1928 object is not a private plastic bathroom extractor. It is a
commercial direct-driven propeller fan terminating a shared sheet-metal duct,
with a protected motor, gravity louvers and weather housing. ILG's company
history records self-cooled motor propeller fans and automatic louvers in its
first 1908 production line, explicitly noting that a sheet-metal plenum made
roof mounting possible. By the late 1920s the firm sold nationwide and was
beginning to adapt that commercial ventilation family to domestic kitchens.
**HISTORICAL; CANONICAL.**

Robert Ilg's 1906 patent supplies the construction logic rather than a modern
roof-fan silhouette: a direct-driven fan, motor behind the impeller, removable
cylindrical protective hood, frustum transition, brackets, bolts and a
serviceable cover. It names kitchens among the rooms this machinery ventilates
and specifies enameled sheet metal for the corrosive air path. The Orison uses
that exposed, repairable vocabulary beneath a simple weather cap; it does not
borrow the spun-aluminium low-profile form ILG's history dates to the 1940s
and 1950s. **HISTORICAL; ADAPTATION.**

Sources:

- [ILG Fan and Blower — company history](https://ilgblower.com/history/)
- [Robert A. Ilg, US831284A, Protective device for ventilating-fans (1906)](https://patents.google.com/patent/US831284A/en)

### What we inherited

- One marker existed, in 4B alone. Its two flat boxes described a 280 mm
  private ceiling appliance while the other twenty-two windowless bathrooms
  had no ventilation object at all.
- The placeholder was electrically graphed to the fourth-floor corridor
  lights. Its whir started at boot, never stopped, and answered every motif
  without a switch, duct or other physical route.
- Four anonymous 400 x 400 x 900 mm metal boxes already occupied the roof,
  but they were Blender furniture with no motors, ownership or connection to
  any bathroom. The correct infrastructure count was hiding in the wrong
  authoring path.

### Built result

The 1928 reopening now owns **four** central roof ventilators, one per V-A to
V-D riser, and **twenty-three** passive bathroom registers. The public lobby
lavatory takes a first-floor branch into V-A; the apartment stacks remain
vertical. 4B's private fan is gone. Every bathroom receives the same 340 mm
painted stamped-steel grille, shallow dark throat, five real louvers and four
dull-brass fasteners, batched by finish per floor rather than instanced as a
script.

Each roof owner is 720 mm across the curb and 940 mm high: square sheet-metal
plenum, bell transition, broad rain cap with a discharge gap, four supports,
external cast motor and belt guard, service panel, unlettered brass plate,
rubber isolation feet, a vertical four-blade rotor and gravity louver. The
four finishes vary only through plausible maintenance history; they remain
one contractor's 1928 plant rather than four character appliances.

The normal cycle is staggered by riser. A motor starts, its louver opens and
the same low mechanical recording becomes audible at only the grilles on that
duct; it coasts away before another stack joins it. A motif may bend a running
motor but cannot start one between cycles. The acoustic graph contains 51
ventilation nodes — 23 register mouths, 24 vertical trunk points and four roof
owners — in four isolated connected components. There is no shortcut through
the electrical lighting spine.

The family grows from **2 placeholder meshes to 32 roof-owner meshes**: eight
per motor. The registers add three batched finish buffers on each residential
floor, not twenty-three FunctionalProps. The separate ceiling repair adds one
plaster draw per floor and remains far cheaper than retaining an entire upper
storey merely to borrow its slab underside.

### Materials and texture prompt batch

No new key and no texture batch. `metal`, `cast_iron`, `trim`, `brass_dull`
and `rubber_aged` already have valid runtime paths. Variation comes from
material tint and physically separate hand/water/weather zones, not from a
new low-frequency albedo plate. There are no generated letters, numbers,
words, badges or logos; the small service plate is deliberately blank.

### Render evidence

Before:

- Flat two-box warehouse placeholder — `C:/PleaseRemainOnTheLine/art/renders/exhaust_fan_review/before/warehouse_exhaust_fan.png`
- Private 4B ceiling appliance — `C:/PleaseRemainOnTheLine/art/renders/exhaust_fan_review/before/f04_b_bath_room.png`
- Streaming exposed the absent ceiling and floating private owner — `C:/PleaseRemainOnTheLine/art/renders/exhaust_fan_review/before/stand_-6.6_10.7_-5.67_0_70.png`

After:

- Flat-light roof-machine silhouette — `C:/PleaseRemainOnTheLine/art/renders/exhaust_fan_review/after/warehouse_exhaust_fan.png`
- Roof context and service side — `C:/PleaseRemainOnTheLine/art/renders/exhaust_fan_review/after/stand_-10.0_20.3_8.0_37_-12.png`
- Opposite roof silhouette — `C:/PleaseRemainOnTheLine/art/renders/exhaust_fan_review/after/stand_-12.8_20.2_8.0_-33_-12.png`
- 4B passive grille under its real light — `C:/PleaseRemainOnTheLine/art/renders/exhaust_fan_review/after/stand_-6.61_11.2_-5.72_86_62.png`
- Standard bathrooms, own lights and torch — `C:/PleaseRemainOnTheLine/art/renders/exhaust_fan_review/after/f04_b_bath_up.png` and `C:/PleaseRemainOnTheLine/art/renders/exhaust_fan_review/after/f02_a_bath_up.png`

Measured rather than accepted from dark frames: mean sRGB for the flat-light
warehouse crop / two roof-context crops / register crop is **(127.9, 130.3,
126.8) / (29.2, 28.0, 35.0) / (37.1, 34.1, 41.3) / (188.6, 159.3,
151.8)**. The roof owners retain a readable painted body and dark separate
motor without raising the scene lights; the register remains legible under
the bathroom's authored light and torch.

### Validation

- Generator and graph audit: **PASS**; 23 bathrooms/registers, four distinct
  roof owners, 51 ventilation nodes, and every motor reaches its own complete
  stack without reaching another.
- FAST WalkTest: **PASS in 13.4 seconds**; 8/32 mesh caps, roof ownership,
  service anchors, no private 4B owner, 23 audible mouths, isolated graph
  components, off-motif restraint and running/louver state.
- FULL WalkTest: **PASS in 63.1 seconds**. LightingAudit: **PASS** for all
  127 spaces, including 11 intentionally ambient/dark. WarehouseTeleportTest:
  **PASS**, 68 displays from 44 kinds. Parser/editor scan and final Godot
  import: **PASS**; `art/data` and `game/data` layout, acoustic-graph and
  material-catalog hashes are byte-identical after the final source build.
