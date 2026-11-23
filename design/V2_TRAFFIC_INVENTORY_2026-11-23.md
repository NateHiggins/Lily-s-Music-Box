# V2 traffic inventory and spec pass, 2026-11-23

Evidence class: **INERT**. This is an inventory, a measurement against the current specs, and a build record.
It is not acceptance. The captures it cites are review evidence only.

Lily asked to take inventory of the traffic, bring the models and animations up to the current spec, and add
the piano-moving truck. All text here is a first draft.

The earlier work this builds on:

- the period traffic and the lamps: PRs 21, 22, 24, 28 and 29;
- the trams: PR 181;
- the el viaduct: PR 176.

The design packets are **design/V2_PERIOD_TRAFFIC_2026-10-24.md**, **design/V2_TRAFFIC_BEHAVIOUR_2026-10-24.md** and
**design/V2_STREET_TRAMS_2026-11-08.md**.

## 1. What moves, and who owns it

| Owner | Source | Stock | Table |
|---|---|---|---|
| Street traffic, **OrisonV2StreetTraffic** | **art/blender/scripts/build_v2_period_traffic.py** | **game/assets/props/v2_period_traffic.glb** | **street_traffic.json** |
| Trolley line, **OrisonV2StreetTrams** | **art/blender/scripts/build_v2_street_trams.py** | **game/assets/props/v2_street_trams.glb** | **street_trams.json** |
| Distant el cars, **orison_v2_city_far_motion.gd** | Box meshes in GDScript; now the rail recipe | Now `el_car` in **v2_street_trams.glb** | Now the tram table's finishes |
| Parked cars and pushcarts (city midground) | The street traffic's own stock | **v2_period_traffic.glb** | **city_midground.json** |
| Vehicle light on the road, **orison_v2_street_vehicle_lights.gd** | Runtime lights | No stock | The traffic's |

Both tables are in **game/data/orison_v2/exterior/**. The street traffic's pose function places every street
vehicle and every tram. The far motion owns the bridge's lamp points, its el cars and a tug, which is not traffic.
The near el viaduct over Queensboro Plaza (**Builder.el_viaduct**) carries no trains. See section 6.

### 1.1 The vehicles

Draw is one MultiMesh per stock. Wheels, horse bodies, horse legs, seated figures and signal arms are shared
batches. Lamps are lit milk-glass lens finishes (`lamp_lit`, `lamp_tail`, `lamp_oil`) that follow one
dusk-to-dawn rule with a 25-minute ramp. After dusk, **orison_v2_street_vehicle_lights.gd** adds the
shadowless beams and pools that those lamps throw on the road.

| Kind | Model (period) | Wheels | Driver | Lamps | Class | Pattern | Cruise m/s | Weight |
|---|---|---|---|---|---|---|---|---|
| `model_a_tudor` | Ford Model A Tudor, 1928 | 4 wire | closed cab, none seen | electric, tail | car_four_wheel | car | 7.5–10.5 | 17 |
| `model_t_touring` | Ford Model T touring, ≤1927 | 4 artillery | seated figure | electric | car_two_wheel | car | 6.5–9.0 | 13 |
| `checker_cab` | Checker Model K, 1928, dispatch set | 4 disc | closed cab | electric, tail | taxi | taxi | 8.0–11.0 | 12 |
| `aa_stake` | Ford AA stake truck | 4 disc | closed cab | electric, tail | light_truck | trade | 6.0–8.5 | 9 |
| `mack_ac` | Mack AC coal dumper | 4 solid | seated figure | brass electric, tail | heavy_truck | coal | 4.5–6.0 | 5 |
| `saloon_bus` | Single-deck franchise bus | 4 disc | closed | electric, tail, destination | bus | bus | 6.0–8.0 | 3 |
| `motorcycle` | Indian Scout and sidecar | 3 wire | rider | electric | motorcycle | car | 8.0–11.0 | 3 |
| `ice_wagon` | Box ice wagon and horse | 4 wagon | teamster | oil lanterns | horse_heavy | ice | 1.5–2.2 | 9 |
| `coal_cart` | Coal wagon and Percheron | 4 wagon | teamster | oil lanterns | horse_heavy | coal | 1.5–2.1 | 7 |
| `milk_wagon` | Route milk wagon and horse | 4 wagon | driver | oil lanterns | horse_light | milk | 2.0–3.2 | 6 |
| `milk_wagon_riderless` | The same, nobody on it | 4 wagon | none, on purpose | oil lanterns | horse_light | milk | 1.4–1.8 | 1.5 |
| `valve_wagon` | Express wagon, valve cargo | 4 wagon | teamster | oil, valve glow | horse_light | trade | 2.5–3.4 | 3 |
| `line_truck` | AA telephone line truck | 4 disc | closed cab | electric, test lamp | light_truck | service | 6.0–8.0 | 2.5 |
| `sound_wagon` | AA police sound wagon | 4 disc | closed cab | electric, tail | light_truck | police | 5.0–7.0 | 1.5 |
| `broadcast_car` | Model A, the Record's remote car | 4 wire | closed cab | electric, tail | car_four_wheel | press | 6.5–9.0 | 1.5 |
| **piano_truck** (new) | WE TUNA PIANOS, 1928 one-ton box | 4 disc | closed cab | brass electric, tail | light_truck | piano | 5.0–7.0 | 2 |
| `tram` (rail) | Double-truck closed car, NY&QC | 8 tram (new) | motorman and 6 passengers | headlamp, saloon, tail | tram | headway table | 4.5–6.0 | line |
| `el_car` (far) | Steel el car, 5-car trains | in the body | none at 1 km | lit window band | none | constant 13 m/s | 13 | — |
| `pushcart` (parked) | Peddler's pushcart | 2 wagon | none | none | none | parked | 0 | — |

Every closed cab shows no figure: its glass is opaque `upholstery`. The windows of the bus and the tram are a lit
or dark finish, and the tram's seated figures read through them.

### 1.2 Route timing

- A street vehicle lives one journey. It turns in at one T, crosses the block, stops at the far T, looks for a
  gap, signals by hand and turns off. The Ts are at x −69.6 and 68.8.
- Flow is 8.5 vehicles a minute at multiplier 1. It is shaped by:
  - each pattern's hours, months and Sunday factor;
  - the weekday factors;
  - the dated events: the carters' stoppage, and now Moving Day.
- At most 12 vehicles are on the street. No gap is ever longer than 8 s while the street is in use.
- The cross streets carry three times the flow, up to 12 vehicles, both ways.
- Trams run to their own headway: 4 minutes at the rush, 20–30 minutes for the owl cars.
- The far el runs two 5-car trains at 13 m/s across the 1,135 m span, without stopping.
- Doors: no vehicle stops to load or unload, so no door opens anywhere. None is modelled as a separate part.

## 2. The specs it was measured against

- **RUL-012**, **design/V2_SURFACE_REQUIREMENTS_2026-10-11.md**: authored finite UVs that sample physical
  metre charts; registered custom PBR maps; complete loaded mip chains.
- **RUL-006**: generated props come from Blender recipes, and a glTF is never hand-edited.
- **RUL-008**: no lettering in textures; lettering is Label3D.
- **On the road**: wheels turn at ground speed, nothing slides or pops, and stops and starts read as physical.

## 3. Findings

### 3.1 Surfaces (RUL-012): pass, unchanged

- Every finish in both recipes names an existing catalogue key with its own albedo, roughness and normal maps.
  The runtime copies switch triplanar off and use anisotropic mipmapped filtering
  (`OrisonV2StreetTraffic.stock_material`). UVs are the shared metre charts from `partition()`.
- Both rebuilt exports pass the exporter's tangent check: traffic 27,572 triangles at a minimum agreement of
  0.99999996, and the rail stock 4,934 triangles at 0.99999996.
- The strict surface packet on main had zero defects at PR 512.
- This pass imports no new texture, so **art/tools/fix_runtime_texture_imports.py** had nothing to apply.
- The far el cars were BoxMesh with a metre chart, plus unshaded window quads. The audit admitted the quads
  under its named exemption `distant_el_light_strips`. They now use the rail stock's catalogue finishes. The
  exemption is unused but stays in the audit, where its unit test still covers it.

### 3.2 Source (RUL-006)

- Street traffic, trams and parked stock: pass. Each recipe writes its GLB and table, and neither is ever hand-edited.
- Far el cars: **fell short**. They were built in GDScript from boxes, not in Blender. Fixed (section 4).
- V1 leftovers that V2 never loads:
  - **game/assets/vehicles/piano_truck.glb**, a Meshy mesh decimated to 12k triangles;
  - its **T_piano_truck_*** textures;
  - **we_tuna_pianos_sign.png**, which carries baked lettering (RUL-008 debt);
  - **art/blender/scripts/build_traffic_vehicle.py**.

  V1's **street_traffic.gd** survives only because V2 calls its static audio forge.
  These are retirement work (section 6), not this pass.

### 3.3 Lettering (RUL-008)

- Pass. No traffic texture carries letters. The tram's destination box is lit and blank on purpose.
- The new piano truck's legend is Label3D, never a texture.

### 3.4 Animation on the road

| Defect | What the player saw | Fix |
|---|---|---|
| Wheels, drivers and arms drawn only within 24 m of the door, a limit dating from the 41 m street. The block now runs ±69 m. | Bodies glided wheel-less and driverless beyond 24 m, and the wheels and driver popped on at the line. | **Fixed.** Every vehicle is drawn whole everywhere; the table's `detail_x` is retired. |
| Cross-street vehicles drawn with no wheels or drivers. | Wheel-less bodies crossing both corners. | **Fixed.** Wheels and figures are drawn there too. |
| Cross-street vehicles stopped in one frame (infinite deceleration) and pulled away at full speed. A stopped horse froze mid-stride. | Popping stops and starts at both corners. | **Fixed.** Each one brakes and accelerates on its class's curves. |
| A horse's leg phase was distance ÷ stride, with the stride switching at 2.2 m/s. | A visible jump in all four legs whenever a horse broke into a trot or fell back to a walk. | **Fixed.** The gait phase is carried per vehicle. Stride and swing blend across 1.9–2.6 m/s. |
| No front-axle steering. | Wheels skated sideways through every 90° turn at the Ts. | **Fixed.** Front axles steer toward the curvature actually being driven, at 1.6 rad/s up to 0.6 rad of lock. Rail trucks do not steer. |
| Rigid motor bodies. | Stops and starts read as dead stops. | **Fixed.** Bodies dip under braking and squat pulling away, about 1° at service braking and never past 2.6°. They pivot near the axles. Horse-drawn and rail vehicles stay level. |
| The tram's eight wheels were baked into the trucks. | The car slid on wheels that never turned. | **Fixed.** A new `tram_wheel` stock, turned by the traffic at the car's ground speed. |
| Wheel roll rate. | Already correct: distance ÷ radius. | Kept. The new test now measures it as no slip at the road contact. |

## 4. What was built

- **Traffic recipe**:
  - the `piano_truck` stock and kind;
  - three finishes on existing catalogue keys: `sign_cream` and `sign_vermilion` on `car_paint`, and `quilt` on
    `fabric_warm`;
  - the `piano` pattern, and the Moving Day events;
  - `solo` and `signs` on every kind;
  - `detail_x` retired.
  - `aa_cab` takes the radiator shell and tail-lamp position. The defaults leave every existing stock unchanged.
    The triangle counts of all 24 earlier stocks are identical after the rebuild.
- **Rail recipe**:
  - `tram_wheel`, with the trucks' baked wheels removed (the car goes from 3,058 to 2,578 triangles);
  - eight wheel records on the tram kind;
  - `el_car`, 568 triangles.
- **OrisonV2StreetTraffic**:
  - wheel batches built from whatever wheel stocks the kinds name, so the tram's are included;
  - figure capacity for the tram's seven seats;
  - the whole-vehicle drawing, the cross-street braking, the gait, steer and pitch state (`_animate`);
  - the solo rule in `_pick`;
  - the Label3D legend holder (`_build_signs`).
- **OrisonV2StreetTrams**: registers `tram_wheel` and validates the wheel records.
- **Far motion**: draws `el_car` with the rail table's finishes. The lit `window` finish replaces the separate
  window quads, so the draw count is unchanged, and its emission follows the bridge's darkness. The batch keeps the
  name `ElCars`.

### 4.1 The piano truck

Lily asked for "the piano moving truck". The street brief already has one: the WE TUNA PIANOS truck, approved
for V1 on 2026-08-14 (**design/ORISON_STREET_BRIEF.md**). It is a battered 1928 one-ton box truck in oxidised
teal, cream and vermilion, 5.8 × 2.05 × 2.30 m. Its concept is
**art/concept/vehicles/we_tuna_pianos_truck_turnaround_v1.png**. In V1 it was a Meshy mesh with a sign texture.
In V2 it is rebuilt in the traffic recipe on the AA chassis:

- a brass radiator shell, the teal box body and a cream roof;
- signwriters' panels on both sides: a vermilion border, a cream field and a vermilion ribbon;
- a black-and-ivory keyboard border along the top of each panel;
- rear doors with nickel hinges and a brass handle, and a rear step;
- the movers' skid board slung under the box, rope coils on the rear corners, and folded quilts on a low roof rail.

**Staged with no hands.** The piano rides inside the box, and nobody carries, lifts or handles anything. The
approved advertisement shows a shark swinging a tuna in its hands. That picture is not baked: it would put
lettering and hands in a texture. The keyboard border stands in for it, and the legend **WE TUNA PIANOS** is
Label3D:

- on each side's ribbon;
- in two lines on the rear doors;
- in Abril Fatface, cream on vermilion;
- readable to 45 m.

**Schedule.**

- Weekday daylight only, never on a Sunday.
- The months follow spring moving, the autumn tuning season and Christmas deliveries.
- New York's Moving Day, when leases ran out on 1 May and again on 1 October, multiplies it by 6 and 3.
- Weight 2 in about 104 makes it about 2% of the street, as in V1.
- It is `solo`: one at a time, so one set of labels follows it wherever it is, the cross streets included.

**Cost.** One more batch (the truck's own surfaces) while it is in view, and four Label3D draws within 45 m. There
are no new lights and no shadows. Vehicle lights treats it like any motor.

## 5. Verification

Runs are in **C:/ov/reports/traffic_spec_20261123/**, through **tools/lane.ps1** with receipts. Windowed runs
went on the hidden desktop. The review renders and their receipts are in **art/reviews/v2_traffic_spec_20261123/**.

- **Blender exports.** Both pass the exporter's tangent check: traffic 27,572 triangles, minimum agreement
  0.99999996; rail stock 4,934 triangles, 0.99999996.
- `OrisonV2TrafficBehaviourTest` (headless): 108 checks, 0 failures. The new contracts read the transforms the
  owner writes, through its `trace` hook, because a headless renderer keeps no MultiMesh transforms. They
  measured:
  - a Model T 55 m up the block keeps its 4 wheels and its driver;
  - the road contact of a rolling wheel moves at most 0.147 of the car's step. That is the geometry of a true roll
    (about step ÷ 2r); sliding would give 1;
  - the body dips 0.018 rad under service braking;
  - the front axle steers 0.29 rad into the east T, moves at most 0.027 rad a frame, and is back to 0.000 on the
    cross street;
  - a milk horse's legs move at most 0.066 rad a frame through the walk-to-trot band, which is the gait's own
    continuous rate;
  - a cross-street cab stops 2.00 m behind a standing one, at a peak of 2.64 m/s² against its 4.2 panic limit;
  - the piano truck is solo, Moving Day multiplies it, and its four legends sit inside their panels and leave with it.
- `V2StreetTramsTest`: 41 checks, 0 failures, including the eight turning tram wheels.
- `V2TrafficSpecShot` (windowed, INERT): 0 failures. It captures the production world on 1 May 1929, by day and
  night:
  - the piano truck from the far kerb, the front and behind;
  - rolling frames 1.1 m apart;
  - the Tudor in the east T;
  - the Model T at the far end;
  - the milk wagon and a tram;
  - the el car seen close.

  The first round showed the cream panels rendering brown, because `car_paint`'s dark map multiplied the tint. They
  moved to `door_paint` (painted panelling) and now read cream and vermilion.
- **Surface packet** (RUL-012), renewed with the physical-only **OrisonV2SurfaceInventory** on the patched engine:
  - 818 checks and 0 failures;
  - **tools/audit_v2_surfaces.py** reports 0 unresolved surfaces;
  - every traffic batch is inventoried, including `Traffic_piano_truck`, `Traffic_tram_wheel` and `ElCars`;
  - **tools/v2_surface_evidence.py** qualifies the published packet with 0 defects.

  Of the 23 frames, two differ from the last packet by more than 4 of 255: `watch_station` and `fuse_panel`. Both
  were looked at, and the difference is warmer lamp light on the wall, not a surface.
- **Static gates.**
  - The reader gate has 0 new unread fields. The tram loader now validates its wheel records, so the table's `at`
    is read.
  - The spatial manifest was regenerated.
  - The design-doc lint is clean.
- **Pins renewed.** `street_traffic.json` is pinned in the city streets and transport records, and its `junctions`
  and `site` are unchanged, so those geometries are unaffected. The bass candidate's manifest pins this change's
  scripts, tables, GLBs and their imported scenes.

## 6. Not done, and follow-ups

- **No trains on the near el.** The viaduct over Queensboro Plaza is static. Running trains on it would be new
  work, with a frame-rate cost to measure against the open 30 fps order.
- **V1 piano-truck assets.** The Meshy GLB, its textures, the lettered sign PNG and the V1 recipe are unused by V2.
  Retiring them is a size-pass task.
- **The advertisement picture.** A lettering-free, hand-free illustration for the side panels would need Lily's
  approval as new art, through the catalogue.
- **The delivered Model A Tudor prototype** (section 9 of the period-traffic packet) is still not integrated.
- **Door animation** for any vehicle would only matter once something stops at the kerb to deliver.
