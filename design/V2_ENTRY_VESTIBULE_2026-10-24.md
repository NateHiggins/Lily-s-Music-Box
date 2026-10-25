# V2 front entrance and entry vestibule

Evidence class: **INERT**. Design, stock list and review notes. Not
acceptance; the captures named in §6 are appearance evidence only.

Owner direction (relayed 2026-10-24): "all those lights in the entrance
awning are unnecessary, we want a more foreboding feel anyway, please rethink
it, also two front doors is unnecessary, make it an entry vestibule with
informative dress and decor."

Implementation:

- recipe **art/blender/scripts/build_v2_entry_vestibule.py** (RUL-006)
- review **art/blender/scripts/review_v2_entry_vestibule.py**
- stock **game/assets/props/v2_entry_vestibule.glb**
- generated finish table **game/data/orison_v2/entry_vestibule_stock.json**
- placements and copy **game/data/orison_v2/entry_vestibule.json**
- runtime owner **game/scripts/building/orison_v2_entry_vestibule.gd**,
  mounted by the V2 runtime root after the front facade
- door policy **game/scripts/building/orison_v2_domestic_doors.gd**
- dark marquee **game/scripts/props/orison_v2_marquee_dress.gd**
- gas fittings and supply in the same recipe and owner
- review capture **res://tests/OrisonV2EntryVestibuleShot.tscn** (windowed)

## 1. The entrance is dark

V2's marquee inherited V1's lit dress: two soffit lamps in prismatic
reflectors, a pavement wash, three fascia troughs, two grazing lights on the
returns and a sign trough. That is nine lights on one canopy, and it read as a
theatre front. All nine are gone. The tray's glass is black from the street.
The bronze legend on the fascia stays but is shaded, so it shows only where
street light reaches it. The gilt transom title is shaded the same way.

The entrance is lit by gas, at the owner's direction (2026-10-24: "research
gas lighting and build sconces and piping"). Light carries, captures,
switches, stores and reproduces no signal, so under the Rule of Signal
(§VIII.2) it did not advance. A building wired past a broadcast house can
still light its front door the way it did in 1912. That is the same split as
the ice and coal in its kitchens (§VIII.4).

The entrance keeps three honest sources:

1. **An iron gas lantern** on the west pier, under the dark marquee: a
   blackened wall plate and scrolled arm, and a tapered four-light lantern
   with a vented cap. The supply comes through the masonry.
2. **An inverted-mantle gas bracket** over the vestibule's inner doorway: a
   brass rosette, a swing arm with its gas cock and flat key, an inverted
   Welsbach mantle in an etched 5½-inch bell. Its light reaches the street
   only through the glazed street door.
3. **The bishop's-crook street lamps** (PR 22), out at the kerb.

The bracket is fed by an exposed, surface-run **half-inch black iron gas
pipe**. It rises from a floor flange in the vestibule's north-east corner,
with a plug cock at 0.9 m, runs west under the cornice at 2.80 m, and drops
into the rosette's inlet boss, strapped to the wall about every 0.8 m. The
recipe derives the run from the placement data, so the pipe always lands on
the bracket. The runtime refuses a bracket placed above the baked run.

Both mantles burn a hard warm white and breathe a few percent with the
supply pressure. Both lights cast shadows; the fittings themselves do not,
because an etched shade diffuses rather than cutting a cone out of its own
light.

### Operating the gas (finished 2026-10-24, owner: "finish the gas lights")

Each fitting is an **OrisonV2GasFitting**
(`game/scripts/props/orison_v2_gas_fitting.gd`) under a semantic name:
**F01_VESTIBULE_GAS_BRACKET** and **F01_ENTRANCE_GAS_LANTERN**.

- **The cock is the control** (RUL-013). Grab the flat brass key, turn it a
  quarter turn about the plug, release. Across the pipe is shut; in line is
  open. There is no toggle and no prompt. The bracket's cock is on its arm;
  the lantern's is on its arm by the wall plate, within reach from the
  pavement.
- **Partial opening is real.** The main jet opens past 12% of the turn. The
  mantle reaches full incandescence at 55% of the jet, as a Welsbach mantle
  saturates. The light, the mantle, the shade and the lantern panes follow
  the flame.
- **The bypass pilot never goes out.** A bead of blue flame stays at the
  burner with the cock shut, and the mantle relights from it when the cock
  opens. No matches are needed, which is why period inverted burners had a
  bypass.
- **The lantern is on a clockwork controller.** It opens the gas from dusk
  to dawn by the street lamps' month-by-month table
  (`game/data/orison_v2/exterior/street_lamps.json`), so the lantern is dark
  by day with its cock open. The player's cock still governs it at night.
- **Sound.** Each fitting hisses: a whisper from the pilot that opens into
  the jet as the cock turns.
- **Saved.** The cock's opening is a `mechanism` record in the household
  save (`orison_v2_household_state.gd`). No new save owner exists.

### The house gas service (2026-10-24, owner: "continue the things missing")

**OrisonV2GasService** (`game/scripts/building/orison_v2_gas_service.gd`),
semantic name **F01_GAS_METER**, owns the supply. Its geometry is the frame
stock `gas_service_workroom`, generated from
`game/data/orison_v2/gas_service.json`.

- **Where.** The service enters through the street wall of
  **F01_FRONT_WORKROOM**, the maintenance tenant's own front workroom, on the
  solid pier east of its window. It rises past the gas company's plug cock
  to a painted steel-plate dry meter on an oak shelf. The house outlet drops
  back into the floor. The run under the floor to the vestibule riser and the
  lantern's wall plate is concealed: the basement does not reach under the
  front of the building.
- **The company cock is sealed.** Its lock wings are wired together and
  lead-sealed, and a second seal hangs on the meter's inlet union. In 1928
  the meter cock belonged to the gas company, so the player cannot shut the
  house gas, and no pilot is ever put out by the house.
- **The meter reads the burn.** Every fitting reports its own consumption:
  3.0 cubic feet an hour for the bracket and 3.5 for the lantern at a full
  jet, plus 0.15 for each pilot. The meter integrates that through campaign
  time. Its five-dial index (one test dial at one turn per cubic foot, three
  register dials) turns, with adjacent dials turning opposite ways as the
  gearing does. Shut every cock and the test dial still creeps on the two
  pilots. The cumulative index (starting at 48,217 cubic feet) is the
  household save's `mechanism` record. Dial labels are Label3D.
- **Mains pressure follows the day.** The works deliver less at the evening
  peak (0.80 of nominal at 18:00 to 20:00) and a little more in the small
  hours (1.06). A saturated mantle still dims with the pressure, so every
  gas light in the building browns down at supper time.
- **Residents operate the vestibule gas, on their own timetables.** On her
  morning rounds in the lobby (08:30), **evelyn_marsh** turns the bracket
  down to its pilot once it is daylight. On his evening pass (18:00),
  **cam_ortiz** turns it back up once it is dark. Each acts only while their
  timetable (`resident_schedules.json`) puts them in the lobby, at most once
  a day, never while the player is within 7 m, and never while the player
  holds the key. The turn goes into the household save like the player's.
  Nothing here authors resident knowledge or observations.

### Mantles wear and are renewed by hand (2026-10-25, owner: "keep going")

- **Wear.** Each fitting counts burning hours at incandescence toward its
  mantle's life. The gas service's clock drives this, the same clock the
  meter uses. Lives fall between 450 and 900 hours, seeded by fitting and
  mantle count so a reload never rerolls one. The vestibule bracket starts
  at 640 of 700 hours, so it fails within a few nights; the lantern starts
  at 150 of 820.
- **Breaking.** A spent mantle breaks and leaves its collar and a few
  shreds of ash. The burner then burns a naked flame: a sixth of the light,
  yellower, guttering hard, and louder than the mantle's hiss.
- **Renewal.** The carton of a dozen spare mantles, **F01_GAS_MANTLE_CARTON**,
  stands on its own oak shelf on the workroom's east wall. Each mantle is a
  single-use MaintenanceInventory id, `gas_mantle_01` to `gas_mantle_12`.
  The inventory alone records which are taken and spent; the packets left in
  the carton are read back from it. Lift the lid with no spare in hand and
  the next one is yours, one at a time.
- **The access is physical** (RUL-013). The bracket's etched shade slides
  straight down off its gallery. The lantern's street-facing light is an
  iron-framed door hung on its left post, and it swings out. Opening either
  one past its reach point crumbles a broken mantle's brittle ash, as spent
  Welsbach ash does. Closing it again with a spare in hand hangs the new
  mantle and consumes the spare; closing it without one leaves the burner
  bare. A new mantle burns off with a brief flare.
- **Saved.** The fitting's household record now holds the cock, the mantle
  condition, hours, life, mantle count and access position. A save from
  before mantles wore (cock only) still loads. The carton's record is its
  lid alone.

Research, in addition to §1:

- Domestic dry meters of the 1920s were light steel plate, painted, with a
  row of small circular dials, among them a one-foot test dial in hundredths,
  and carried two seals ([Science Museum Group, Glover 1926](https://collection.sciencemuseumgroup.org.uk/objects/co11693/dry-gas-meter);
  [Glover 1927](https://collection.sciencemuseumgroup.org.uk/objects/co11558/dry-gas-meter);
  [South Metropolitan 1933](https://collection.sciencemuseumgroup.org.uk/objects/co11694/dry-gas-meter)).
- Works stored gas in holders and boosted the mains because peak use
  outran production. Pressure fell with heavy demand, and consumers
  complained of dim light ([Gasworks Museum, distribution](https://www.gasworksmuseum.org.nz/distribution-of-gas);
  [Manawatu Herald, 1917](https://dynamic-rsnz.natlib.govt.nz/newspapers/MH19170515.2.5)).

### Research

- Inverted burners came in about 1905. They threw light downward, and the
  shorter mantles were less fragile ([NPS, Myers, plate 11](https://www.nps.gov/parkhistory/online_books/hcrs/myers/plate11.htm)).
- Wall brackets were converted to upright mantles and later to inverted
  ones ([William Sugg & Co., open-flame brackets](https://williamsugghistory.co.uk/lighting/interior-lighting/open-flame-brackets-pendants);
  [fixtures with mantles](https://williamsugghistory.co.uk/lighting/interior-lighting/fixtures-with-mantles)).
- A bracket's tap controlled and trimmed the flame ([Victorian Collections](https://victoriancollections.net.au/collections?q=gas+lamp)).
  A Welsbach Junior bracket is catalogued with a gas cock and mica chimney
  ([Ingenium 1998.0334](https://collection.ingenium.ca/en/id/1998.0334.001)).
- Exposed supply pipe crossing a room to its gasolier and sconce was
  ordinary ([University of Delaware, Material Matters](https://sites.udel.edu/materialmatters/?p=2692)).
- In 1913 New York had 44,653 single-mantle gas street lamps against about
  37,000 electric ones, and gas was still in general use in residential
  districts ([NYC LPC report](https://s-media.nyc.gov/agencies/lpc/lp/1961.pdf);
  [Milrose](https://milrose.com/insights/an-early-history-of-lighting-in-nyc)).
  Electric light became the US norm only in the 1930s ([Brownstoner](https://www.brownstoner.com/?p=364921)).

The fitted neon blade is untouched. It is the other agent's front lighting
and the building's landmark.

None of the removed lights were `LightFixtureProp` actors. They were bare
Omni and Spot lights in the dress, so they had no provenance, personality,
circuit or conductor records to clean up in `game/data/light_provenance.json`
or the lighting director.

## 2. One front door

The street door **F01_DOOR_06** is the only leaf. The vestibule's inner
doorway **F01_INNER_DOOR** keeps its opening, frame, casings and linings, but
hangs no leaf. The door policy marks it `unhung`. The leaf came off at the
1928 reopening. The jamb halves of its three butt hinges are still screwed
to the hinge jamb, pins drawn, which is the kind of trace the Bible asks the
sixteen years to leave (§VIII.5, "The oldest things in the building are
older than the building's own front door").

**Why the blockout is unchanged.** The blockout owns the opening, and the
opening stays. The door policy owns the leaf, so the leaf changed there.
**game/data/orison_v2_blockout.json** is hash-bound: 30 files carry its
LF hash (the Blender constructions and source snapshots for the ground, roof,
foundations, pavement, city closure, flue and front trim, and their test
fixtures), and 17 Godot tests hash it at run time. Any byte change there
expires them all and needs every owning builder rerun. The spatial audit classes **F01_INNER_DOOR** as
PRESERVE_OR_ALIAS, so the id is preserved. A saved lock on the old leaf is
ignored; `DoorKeyring` looks locks up per door.

Consumers updated:

- `orison_v2_door_casings.gd` cases an unhung doorway from the kind the
  policy leaves on the anchor (three lines; the other agent is reworking
  this file into native mitred stock).
- `orison_v2_vestibule_door.gd`, the quarter-turn inner leaf, is deleted.
- The route helpers in `orison_v2_vertical_route_test.gd` now operate one
  door. They are inherited by the passage, news, golden repair, connected
  exterior, street boundary, street crossing, subway, bar, arcade, bodega,
  resident key and coal delivery routes. The golden repair route's own entry
  and the street crossing's return were updated too. The knock route never
  used the front entrance.
- `orison_v2_inner_door_test.gd` (**OrisonV2InnerDoorTest**, also the
  `inner` walker in the owner building routes) now proves the unhung
  doorway: no leaf, nothing in the clear aperture through the wall depth,
  casings and butts present, both approaches walked.

Resident navigation needed no change. Residents path through spaces and
passage residency uses **F01_VESTIBULE**'s box, not the leaf.

## 3. The vestibule tells you where you are

Laid out for someone stepping in from the street (walking north):

| Wall | Fitting | What it tells the player |
|---|---|---|
| West | **Tenant directory**: black felt in a stained oak case, a brass header strip | Who lives here, by unit. Names are Label3D from `resident_schedules.json`, set the way a superintendent sets felt letters (E. MARSH). 4D reads FURNISHED ROOMS. The player's 4B has a row and no name yet |
| North, west of the doorway | **EST. 1928 plaque**, moved in from the pier | BuildingEntrySign's legend and inspection on a native bronze tablet. The paper trail begins in 1928 (§VIII.5) |
| North, east | **Notice: RE: THE HUM** | The mail catalogue's own Management notice, reused word for word |
| North, east | **Notice** | The door is kept shut, callers wait here, the house operator rings the tenant. The operator is the player (§VIII.4) |
| North, above the wainscot | **Vantry point** beside the power socket | Brass flush signal outlet, the one signal object here (§VIII.3) |
| East | **Radiator**, one-pipe steam, valve and vent; **coat hooks** above | §VIII.5.c. Dress only: not on the house heating graph |
| Floor | **Coir mat** inside the street door | |

The cast-iron umbrella stand (dossier slice 32) stays in the north-west
corner.

## 4. Surfaces (RUL-012, RUL-008)

- No new material keys. Finishes name catalogue keys: `wood_dark`,
  `fabric_warm`, `paper`, `brass_dull`, `bronze_sheet`, `bakelite_black`,
  `iron_blackened`, `radiator_cast_iron`, `radiator_service_brass` and
  `milk_glass` (the lit mantle, shade and lantern glass carry emission). The `bronze` and `cast_iron` keys were tried and rejected in
  Blender review: `bronze` is an outdoor verdigris and `cast_iron` read silver
  on the hooks.
- UVs are the shared metre charts from `partition()`. Build proof: 23
  primitives, 11,504 triangles, minimum tangent agreement 0.99999996, PASS.
- Runtime materials are `OrisonV2StreetTraffic.stock_material`: MatLib stock
  duplicated, triplanar off, anisotropic mipmapped filtering.
- No lettering in any texture. Names, notices, header and plaque legend are
  shaded Label3D, so they read only in light.
- No reference photographs.

## 5. Not done, and follow-ups

- The run from the workroom meter to the vestibule riser and the lantern is
  concealed under the floor and in the masonry, not modelled.
- Residents act as timetable facts: there is no visible body turning the
  key. That stays out of the player's sight by construction.
- When the dozen spare mantles are gone, nothing restocks the carton. The
  hardware counter could sell more; that is a follow-up.
- The carried spare is an inventory fact with no pocket line on the
  handheld or the caretaker notebook yet.
- The radiator is not on the heating graph and cannot knock or be bled.
- The directory board and notices are not inspectable.
- Any merged script or data change expires the V2 runtime, access and
  surface receipts, and this one does too. Renewing them is separate work.

## 6. Verification

- Blender review, before Godot, including the gas run landing on the
  bracket's inlet boss: **art/reviews/v2_entry_vestibule_20261024/**.
- Godot, windowed: **res://tests/OrisonV2GasCockTest.tscn** turns both cocks
  through the player's latched grab and mouse input: shut to the pilot, half,
  full open. It checks the household save and the lantern's clock at noon and
  after dusk.
- Godot, windowed: **res://tests/OrisonV2GasMantleTest.tscn** breaks the
  bracket's worn mantle, then by the player's own grab and mouse lifts the
  carton lid for one spare, slides the shade down (the ash crumbles) and up
  (a new mantle is hung, the spare consumed, the flare burns). It checks the
  household save, then swings the lantern's door out and shut with no spare.
- Godot, windowed: **res://tests/OrisonV2GasServiceTest.tscn** checks that
  the meter reads an hour's burn, that the evening peak dims a full mantle,
  that the company cock is not operable, and that each resident acts only
  out of sight, on their timetable and light condition, and is saved. It
  captures the meter.
- Godot, windowed: **res://tests/OrisonV2EntryVestibuleShot.tscn**, 0
  failures. It checks the leafless doorway, its casings and butts, the dress
  and the gas supply. It counts every light within 6 m of the street door
  (two: the lantern and the bracket, excluding the player's carried set and
  the sky). It captures the street at night and the vestibule; the frames are
  in **art/reviews/v2_entry_vestibule_20261024/godot/**.
- Route tests, windowed, through the one front door: **OrisonV2InnerDoorTest**
  (unhung doorway), **OrisonV2PassageRouteTest**,
  **OrisonV2GoldenRepairRouteTest**, **OrisonV2NewsRouteTest**,
  **OrisonV2StreetCrossingTest** and, after merging main's PR 24,
  **OrisonV2ConnectedExteriorRouteTest** (18 waypoints) pass with 0 failures.
- **OrisonV2VerticalRouteTest** fails with the same F03 fire-cabinet
  collision on clean main at 662aa9fc; that failure is not caused here.
- Static: reader gate 0 new, period dates PASS, spatial audit clean after
  registering the new rows, design-doc lint clean. The gate board against
  main's board regressed only on the then-uncommitted GLB and the
  then-unregistered spatial rows.
