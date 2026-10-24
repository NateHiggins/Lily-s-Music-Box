# V2 period street traffic — Queens, November 1928 to November 1929

Evidence class: **INERT**. Research, design and stock list. Not acceptance;
the review captures named at the end are appearance evidence only.

Owner direction (relayed 2026-10-24): fill V2's street with period-correct,
subtly uncanny traffic. Apply the Rule of Signal (Bible §VIII.2, §VIII.4):
anything that carries, captures, switches, stores or reproduces a signal is
forty years early, and everything else is 1927 and second-hand.

Implementation:

- recipe **art/blender/scripts/build_v2_period_traffic.py** (RUL-006)
- review **art/blender/scripts/review_v2_period_traffic.py**
- stock **game/assets/props/v2_period_traffic.glb**
- generated table **game/data/orison_v2/exterior/street_traffic.json**
- runtime owner **game/scripts/building/orison_v2_street_traffic.gd**,
  mounted by the V2 runtime root under **STREET_ORISON_01**
- review capture **res://tests/OrisonV2PeriodTrafficShot.tscn** (windowed)

## 1. What already existed

**V1** has `StreetTraffic` (`game/scripts/building/street_traffic.gd`). It
draws boxes and cylinders in four MultiMesh batches, plus one real mesh, the
piano truck. Its lane constants are baked to V1's plan coordinates. V2 composes no
traffic at all: `OrisonV2RuntimeRoot.street_traffic` is null by design, and
the dream boundary test treats that null as V2's documented sleep-gate gap.

**Codex's untracked work** in the main checkout (read-only, not edited or
committed here): `art/blender/scripts/build_v2_traffic_stock.py` exports
`v2_traffic_stock` with three generic primitives (`Coachwork` box, `Wheel`
cylinder, `LampPair`) on the shared native exporter
`fabrication_native_batch.py`. Its docstring says "existing stream retains all
motion". It is a surface-compliant replacement for V1's primitive batches and
names no period vehicles. `street_film_tent.blend` is an unrelated street
fitting. Neither file covers what was asked, so this work builds on the same
exporter (`material`, `partition`, `export`), the same catalogue keys and the
same name-only material binding, and adds the vehicles.

V2's street, from **TEMPLATE_STREET_SEGMENT_V1**: the `street_lane` asphalt runs
x −20.3…20.8 and z 4.955…14.1, with its top at y −0.10. Kerbs are at z 4.785 and 14.269.
Storm curtains close the carriageway at x −20.1 and +20.6. Driving is on the
right. Westbound keeps the Orison half at z 7.205 and eastbound uses z 12.005,
the same lanes V1 used, re-expressed in the street frame.

## 2. Period research: what moved on a Queens street in 1928–29

The real street, which the 95% must match:

- **Horses were still working.** New York's horse population fell from about
  128,000 in 1910 to about 56,000 in 1920 and kept falling, but milk, ice,
  coal and bread stayed horse-drawn longest. Sheffield Farms kept more than
  1,000 horses and stabled delivery horses in Manhattanville until 1938.
  About 6,000 milk wagons worked city streets in the 1920s. Milk horses knew
  their rounds and walked them while the driver was on a doorstep.
- **Ice and coal**: box ice wagons with a canvas rear curtain, tongs and a
  scale; high-sided coal wagons with a chute, often behind a Percheron.
  Motor ice trucks were arriving and coexisted with wagons.
- **Motor cars**: the Ford Model A (introduced December 1927) was the new
  car of 1928–29. The Model T ended production in May 1927, so it was the
  everywhere second-hand car, mostly black, wooden-spoke artillery wheels.
  The Model A had wire wheels, a nickel radiator shell and drum headlamps on a
  tie bar.
- **Taxis**: the Checker Model K appeared in October 1928 (Buda six, 127 in
  wheelbase, landaulet rear quarter). Earlier Mogul-derived Checkers and
  Yellow Cab Manufacturing cabs (GM from 1925) shared the fleets.
- **Trucks**: the Ford Model AA 1½-ton (1928) carried stake beds, panel bodies
  and trade bodies. The Mack AC "Bulldog" (1916–1938) had chain drive,
  solid tyres early, a sloping "coal-scuttle" hood and the radiator behind the
  engine, and was the heavy hauler and coal dumper.
- **Buses**: private franchise bus lines grew in Queens through the late
  1920s. The New York & Queens County Railway formed the Queens-Nassau
  Transit Lines bus division in February 1926. Single-deck saloon buses ran
  beside trolleys that would mostly be gone by 1937.
- **Motorcycles**: Indian and Harley-Davidson, often with sidecars, used
  for trade and by police.
- **Handcarts**: pushcart peddlers worked the kerbs. In the newspapers' own
  carters' dispute, 41 hand-carts and about 300 buckets carried ice and coal
  to 1,312 doors.
- **Prohibition** (1920–33) means no brewery drays.
- The IRT Flushing elevated ran over Roosevelt Avenue to Main Street by 1928.

The game's own newspapers (`game/data/newspapers/`) already establish local
traffic that this stock stays consistent with:

- **Ice and coal**: the Flushing Bay, Bowery Bay and Astoria ice companies,
  and the Vernon Avenue coal yard with Dutchman the Percheron. The Astoria
  Ice Co. motor truck plays Nell's bell recording on its horn.
- **Milk**: Douglaston dairy wagons, and Duchess with the Steinway wagon.
- **Signal traffic**: Captain Galvin's **Police Department sound wagon**, the
  Newark valve trucks and the Hollander Valve & Supply receivership selling
  61,000 valves in lots of six hundred. The New York Telephone lineman Joseph
  Marchetti, and the Exchange operators' switchboard on a truck.

## 3. The Rule of Signal applied to vehicles

A chassis, a horse, an engine, a wheel and a seat carry no signal. They are
1927, painted, repaired and second-hand. The finishes stay in tin, enamel,
paint, cast and blackened iron, timber, leather, rubber, nickel and brass. There is no
aluminium and no stainless steel; Bakelite is the only plastic.

Signal reaches a vehicle only where it plausibly would:

| Stock | Ordinary vehicle | What is forty years early |
|---|---|---|
| **checker_cab** | Checker Model K | Garage dispatch receiver: a Bakelite cabinet with a brass grille on the near running board, a square loop aerial on the roof, cloth-braided flex between them. Fleet cabs take calls in the street. |
| **sound_wagon** | Model AA closed van | Galvin's sound wagon. Twin Bakelite recording horns on a turntable, a brass contact mast, a cable reel, and three wet-cell crates slung between the axles. It records the street as it drives. |
| **line_truck** | Model AA line body | Silk-braided pair on a timber reel, a Bakelite test panel with brass posts and one lit lamp, and a wet-cell crate. |
| **broadcast_car** | Model A Tudor | The Record's remote car. A four-wire cage aerial on spreaders, a Bakelite pickup horn and its own wet cells on the running board. |
| **valve_wagon** | One-horse express wagon | The cargo. Sleeve crates of salvaged valves under oilcloth, and a brass-bound Bakelite sample chest with one tester valve glowing in its window. A horse delivers the future. |

Batteries are enormous (§VIII.4), so every signal vehicle carries wet cells
in timber crates, never anything portable.

**The quiet wrong one.** V1's brief keeps the uncanny at 5% and never
acknowledged. V2's is **milk_wagon_riderless**: the same route wagon with
nobody on it, walking slower than the rest. That is true to 1928, because milk
horses walked the round alone, and it is never remarked on. The rest of the
uncanny comes from the signal vehicles being ordinary to everyone on the street.

## 4. Stock list

All stock is in one GLB, with one mesh per (stock, finish) named `<stock>__<finish>`.
Triangle counts are from the build.

| Stock | Period source | Draw | Weight | Speed m/s | Tris |
|---|---|---|---|---|---|
| **model_a_tudor** | Ford Model A Tudor, 1928 | motor | 17 | 5.2–7.4 | 1,404 |
| **model_t_touring** | Ford Model T touring, ≤1927, top up | motor | 13 | 4.6–6.6 | 1,016 |
| **checker_cab** | Checker Model K, 1928 | motor, signal | 12 | 5.0–7.2 | 1,402 |
| **aa_stake** | Ford Model AA stake truck | motor | 9 | 4.4–6.2 | 1,132 |
| **ice_wagon** | Box ice wagon | horse | 9 | 2.4–3.4 | 804 |
| **coal_cart** | High-sided coal wagon, Percheron | horse | 7 | 2.2–3.2 | 712 |
| **milk_wagon** | Route milk wagon | horse | 6 | 2.2–3.0 | 732 |
| **mack_ac** | Mack AC coal dumper | motor, heavy | 5 | 3.6–5.0 | 1,156 |
| **saloon_bus** | Single-deck franchise bus | motor, heavy | 3 | 4.2–5.8 | 1,120 |
| **motorcycle** | Indian Scout with sidecar | motor | 3 | 5.6–7.6 | 942 |
| **valve_wagon** | Express wagon, valve cargo | horse, signal | 3 | 2.4–3.2 | 1,088 |
| **line_truck** | Model AA telephone line truck | motor, signal | 2.5 | 4.2–5.8 | 1,756 |
| **milk_wagon_riderless** | (milk_wagon stock, no figure) | horse | 1.5 | 1.8–2.4 | — |
| **sound_wagon** | Model AA police sound wagon | motor, signal | 1.5 | 3.8–5.0 | 2,388 |
| **broadcast_car** | Model A Tudor, remote rig | motor, signal | 1.5 | 4.6–6.4 | 1,926 |
| **pushcart** | Peddler's pushcart, parked at the kerb | — | parked | 0 | 356 |

Shared stocks: **wheel_wagon** (iron tyre, wooden felloe and spokes),
**wheel_artillery**, **wheel_wire**, **wheel_disc**, **wheel_solid**,
**horse_body**, **horse_leg** and **figure** (a seated teamster or motorist in
a flat cap). Signal vehicles are about 10% of the weight table, horse-drawn
about 28%.

Paint is per vehicle from period palettes. Fords are dark blue, green, maroon
or sand; the Model T is black. Cab fleets are yellow, green or maroon. Ice wagons
are cream or green, police green-black, and the Record maroon. Horse coats
are bay, brown, grey or black.

## 5. Surfaces (RUL-012, RUL-008)

- No new material keys. Every finish names an existing catalogue key, for
  example `car_paint`, `door_paint`, `iron_blackened`, `cast_iron`,
  `wood_dark`, `timber`, `rubber_aged`, `nickel_plated`, `brass_dull`,
  `milk_glass`, `leather_worn`, `fabric_warm`, `linen`, `bakelite_black`,
  `soot` and `plant`.
- UVs are the shared physical metre charts from `partition()`, with grain
  frames on timber. The exporter validates tangents (build proof: 25,004
  triangles, minimum tangent agreement 0.99999996, PASS).
- Runtime materials duplicate the MatLib stock, with triplanar off and
  anisotropic mipmapped filtering. Paint and horse coats are the catalogue
  albedo map divided by its measured mean (measured by the recipe, never
  typed), then multiplied by the per-vehicle colour, so the map still carries
  the relief.
- Lamps are physical. Lit milk-glass lenses carry emission (electric warm,
  kerosene amber, tail red), with no additive halo quads and no projected
  pools. The surface audit admits halos only for named owners, and a lamp
  lens is a physical surface. V1's wet-road headlight pools are therefore not
  carried over; see §8.
- No lettering. Fleet names, ice company and dairy signwriting would be
  Label3D (RUL-008) and are deferred.
- Reference photographs were not used. Forms are drawn from period
  specifications (wheelbases, wheel types, hood shapes).

## 6. Runtime behaviour

- The owner is mounted under **STREET_ORISON_01** by
  `OrisonV2RuntimeRoot._compose_exterior`, after the paving details. It is
  `period_traffic`; `street_traffic` stays null so the dream boundary test's
  V1 probe points are not applied to V2's frame.
- It draws one MultiMesh per stock and shares the wheel, horse, leg and
  figure batches. An empty batch is hidden. Wheels turn by distance
  travelled. Horse legs swing in a four-beat walk with a slight body bob.
  Nothing casts shadows, as in V1.
- V1's promise stands: `max_wait` 8 s and `gap_seconds` 3.4. A lane whose
  entry is occupied waits. Vehicles follow and never pass through each
  other. Up to 8 vehicles are live; the V2 street is 41 m against V1's 104 m.
- **Yield**: a vehicle slows for a person standing in its lane and stops
  `yield_stop_m` short. Only stepping into the side of a moving vehicle
  earns V1's shove (`stagger`, 4 s cooldown). No damage, no UI.
- The whole carriageway refuses sleep (`blocks_sleep_entry`).
- Voices: four pooled `AudioStreamPlayer3D`, using V1's forged motor and
  hoof loops (`StreetTraffic._forge`, now static), pitched by speed.
- The street starts already in use (30 simulated seconds at build).

## 7. Verification

- Blender review, before Godot: sheet and per-stock renders in
  `art/reviews/v2_period_traffic_20261024/`.
- Godot, windowed: **res://tests/OrisonV2PeriodTrafficShot.tscn** checks the
  owner, its frame, the finish maps and mips, the sleep gate and the yield,
  then captures the live stream and four staged scenes. It records draw calls
  with and without traffic in `period_traffic_review.json`.

## 8. Not done, and follow-ups

- Signwriting (Label3D) for fleets, the ice companies and dairies.
- Nell's bell played on the Astoria Ice Co. truck's horn (newspaper canon,
  date-bound to after September 1929) needs a date gate and a sound.
- Wet-road headlight reflections would need a named optical-effect class in
  `tools/audit_v2_surfaces.py`. That is a policy change for the owner.
- Faces use `linen` tinted to skin; no catalogue skin finish exists.
- Any merged script or data change expires the V2 runtime, access and
  surface receipts; this one does too. Renewing them is separate work.
- Codex's `v2_traffic_stock` remains its own untracked work.

Sources: [Checker Taxi](https://en.wikipedia.org/wiki/Checker_Taxi),
[The Henry Ford: Model K Checker Taxicab, 1928](https://www.thehenryford.org/collections/explore/artifact/522920),
[Mack AC](https://en.wikipedia.org/wiki/Mack_AC),
[Sheffield Farms Stable](https://en.wikipedia.org/wiki/Sheffield_Farms_Stable),
[Sheffield Farms, Columbia neighbours history](https://sheffieldfarms.neighbors.columbia.edu/content/chapter-2-sheffield-farms),
[History of current bus routes in Queens](https://en.wikipedia.org/wiki/History_of_current_bus_routes_in_Queens),
[List of streetcar lines in Queens](https://en.wikipedia.org/wiki/List_of_streetcar_lines_in_Queens).
