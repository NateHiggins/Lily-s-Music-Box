# V2 traffic behaviour — motion, schedule, the T junctions and warnings

Evidence class: **INERT**. Research, design and implementation notes. Not
acceptance; the review capture is appearance evidence only.

Owner direction (relayed 2026-10-24): "i want the traffic motion deeply
simulated for behavior, include acceleration and LOD traffic in the middle
distance both directions cut off at T intersection to give illusion of a city
scale traffic pattern, time of day, year etc. they should also honk and slam
on the brakes if the player gets in front of them, make it period apropriate".

This builds on the stock and owner in **V2_PERIOD_TRAFFIC_2026-10-24.md**
(PR 21). Implementation:

- recipe **art/blender/scripts/build_v2_period_traffic.py**, which now also
  generates the class, schedule, junction and LOD tables and the
  **signal_arm** stock
- owner **game/scripts/building/orison_v2_street_traffic.gd**
- warnings **art/tools/build_street_warning_audio.py** writing
  **game/assets/audio/synth/traffic/**, registered in
  `game/data/audio_cues.json` and `PropAudio`
- headless contract **res://tests/OrisonV2TrafficBehaviourTest.tscn**
- windowed review **res://tests/OrisonV2PeriodTrafficShot.tscn**

## 1. Period research

- **Speeds.** In-town motor traffic in 1928 ran 15–25 mph (6.7–11.2 m/s).
  Solid-tyred heavy trucks such as the Mack AC were governed near 12 mph. A
  working dray horse walks at 1.5–2.2 m/s, and delivery horses jog-trot at
  2.5–3.5 m/s.
- **Brakes.** The Ford Model A (December 1927) made four-wheel mechanical
  brakes the norm. A panic stop from 20 mph in about 25 ft is roughly
  5.3 m/s² dry, which is less on wet granite setts, so 4.2 m/s² is used here.
  Two-wheel brakes (the Model T's transmission and rear brakes) need about
  twice the distance. Horses pull up within a couple of metres from a walk.
  Driver reaction is taken as 0.5–1.1 s, and alert drivers anticipate, so
  panic braking starts after half the class reaction.
- **Warnings.** The Klaxon's motor-driven diaphragm "ah-oo-gah" (patented
  1908) was the horn of the Model T and Model A. Squeeze-bulb horns stayed
  on motorcycles. Buses and street railways used a foot gong, and teamsters
  used the whip and the voice.
- **Signals.** Drivers signalled by hand, with no indicators: left arm out
  straight to turn left, forearm raised to turn right, arm down to stop or
  slow. New York's red/green signal towers (simplified to two colours in 1925)
  stood on the avenues, not on a side street like this one.
- **The street year (Speaker and Record).**
  - Ice is a summer trade and coal a winter one.
  - Milk comes before dawn, seven days a week.
  - Sunday is quiet: blue laws keep trucks off and coal yards closed, but
    Sunday drivers are out.
  - **Carters' stoppage, 15–20 March 1929:** no horse under the El on
    Roosevelt Avenue, so ice and coal came round by the side streets.

## 2. Behaviour (per vehicle class)

| Class | Accel m/s² | Service brake | Panic brake | Reaction s | Warning |
|---|---|---|---|---|---|
| **horse_heavy** (ice, coal) | 0.45 | 1.1 | 2.6 | 0.55 | whip crack |
| **horse_light** (milk, valve) | 0.7 | 1.4 | 3.0 | 0.5 | whip crack |
| **car_four_wheel** (Model A, broadcast car) | 1.1 | 1.6 | 4.2 | 0.9 | Klaxon |
| **car_two_wheel** (Model T) | 0.85 | 1.2 | 2.4 | 0.9 | Klaxon |
| **taxi** (Checker K) | 1.25 | 1.8 | 4.2 | 0.75 | Klaxon |
| **light_truck** (Model AA bodies) | 0.7 | 1.3 | 3.4 | 1.0 | Klaxon |
| **heavy_truck** (Mack AC) | 0.4 | 0.9 | 2.0 | 1.1 | Klaxon |
| **bus** | 0.55 | 1.2 | 3.0 | 0.9 | foot gong |
| **motorcycle** | 1.6 | 2.0 | 4.5 | 0.7 | bulb horn |

Every motor class adds the brake shriek to a hard stop from above 3 m/s.

- **Journeys.** A vehicle turns in from the cross street at one T, drives the
  block, stops at the far T's stop line, waits 0.8–2.2 s and until the cross
  traffic clears, signals by hand and turns off. Turns are quarter arcs into
  the right-hand lane of the cross street.
- **Following.** Each vehicle keeps a 2 m standing gap and a speed limited
  by its service braking into the gap. Nothing closes inside the vehicle
  ahead.
- **A person in the road.**
  - **Seen early:** a service stop 1.6 m short, with the arm down.
  - **Seen late or within three seconds of the nose:** after half the class
    reaction time, panic braking with the class's warning, plus the brake
    shriek for motors.
  - **Waiting long:** a driver held up more than four seconds gives a
    courtesy note, and one more after twelve; then silence.
  - **Never through:** position is clamped so no vehicle ever passes through
    the person.
  - **Riderless milk wagon:** with nobody on the box it stops in silence.
- **Contact.** Only stepping into the side of a moving vehicle earns the
  street brief's shove.
- **Animation.** Horses walk below 2.2 m/s and trot above, with a longer
  stride and more swing. Wheels turn by distance travelled.

## 3. Schedule (`CampaignClock`)

The table generates patterns of 24 hourly and 12 monthly multipliers, plus a
Sunday factor, for ten trades: car, taxi, trade, coal, ice, milk, bus,
service, police and press. A weekday factor runs Monday first, as
`CampaignClock.DAY_NAMES`. A dated event list holds the carters' stoppage.

The base flow is 8.5 vehicles a minute; the 3 a.m. street is nearly empty
against the morning rush. The kind mix is the kind weight times its pattern
for the current hour, month and day. The clock is read every four seconds.

Lamps burn from dusk to dawn by month, using New York times and 1929
daylight saving, and ramp over 25 minutes. A 1928 vehicle runs dark by day.
The valve tester's glow is signal and burns always.

## 4. The T junctions and the middle distance

See §6 for the measured site (T junctions at x 68.8 and −69.6). Each end of the block meets a cross street at a
T. Vehicles of ours stop at it and turn off, and new journeys turn in from
it. Both cross streets carry their own flow both ways at three times the
street's rate, up to 12 vehicles.

That flow is the LOD: bodies and horses (legs walking) only, with no wheels,
riders, arms, voices or player reaction. It holds short of the junction while
one of ours is turning, and our drivers wait for it. Vehicles of ours beyond
x ±24 also drop riders and arms.

## 5. Warnings (sound and captions)

The five warnings are real recordings, downloaded with the owner's permission
(2026-10-24) from Freesound, every one CC0 and confirmed on its own page.
They are the HQ previews, kept as downloaded in the engine-ignored
`game/assets/audio/freesound/source/` and listed in its `ATTRIBUTION.md`.
`art/tools/build_street_warning_audio.py` cuts each event, fades and
normalizes it, and writes 16-bit mono 44.1 kHz WAVs to
`processed/traffic/`. Cuts were chosen by measured envelopes and spectra:

- the Klaxon: craigsmith's old car Ahooga horn, one full call
- the bulb horn: Breviceps' vintage squeeze horn, two honks
- the bus bell: AmazingRolo's struck tram bell, one clang and its ring
- the brakes: craigsmith's large old car pulling up, its drum brakes
  squealing near 920 Hz
- the whip: G.Lamont's whip crack

Each is an `AudioPolicy` cue with purpose `hazard` on the Hazard bus:

- **traffic.klaxon**: "Klaxon: ah-oo-gah"
- **traffic.bulb_horn**: "bulb horn honks"
- **traffic.foot_gong**: "bus bell clangs"
- **traffic.brake_shriek**: "brakes squeal"
- **traffic.whip_crack**: "whip cracks"

## 6. Site (measured)

A windowed axis probe and the registered city plan agree. The street frame
is the world frame, and V2 shifts the plan's street rows by the offsets in
`art/blender/city_shells_registration.json`: −3.2 m for the north-west row
and +5.58 m for the north-east row. The plan's thin end slabs (**end_w**,
**end_e**) are not part of the V2 city. Asphalt court ground runs throughout.
The playable carriageway is x ±20.8 behind the storm curtains; beyond is
middle distance seen through haze.

Each end of the block already opens onto a cross street before a building
that faces down the street, so V2 has its T junctions without any city
change:
- **West:** the corner masses end at x −61.4 (**nw4**) and −58.2 (**sw3**),
  and **site_far_w** stands across the end at x −77.8. The cross street is
  centred at x −69.6 and open from z −39.6 to z 28.
- **East:** the corners end at x 63.8 (**ne4**) and 58.2 (**se3**), and
  **site_far_e** stands across the end at x 73.8. The cross street is
  centred at x 68.8 and open from z −37.6 to z 30. On the far half
  (z 8.4–18.3) the view runs on to the horizon, so the east end reads as a
  street that jogs.

The junctions use a 4.6 m half width and a 1.5 m lane offset. Cross reach is
±18 m from the street centre, so cross traffic comes and goes behind the
corner masses.

An earlier reading of the plan without the registration offsets suggested
the corners closed the street and a city cut was needed. That was wrong; no
city stock was changed.

## 7. Verification

- Headless **OrisonV2TrafficBehaviourTest** checks:
  - class acceleration
  - cruise speeds within period bounds
  - service-braked stop at the T stop line, then the turn-off
  - following without overlap
  - hard stops with the right warning for six classes
  - brake shriek
  - never driving through a person
  - the silent riderless horse
  - the schedule's night, rush, season, Sunday and stoppage shapes
  - dusk-to-dawn lamps
  - cross flow both ways
- Windowed **OrisonV2PeriodTrafficShot** adds the teamster's whip and a cab's
  Klaxon-and-shriek stop as seen from the road, hand signals, and views to
  both T junctions.

## 8. Not done

- Arm signals are a straight arm, raised or lowered. The right-turn signal
  is a raised arm, not a bent forearm. The sleeve is a linen motoring
  duster with a pale glove, so the signal reads on dark coachwork at night.
- A left turn at the T gives way to any vehicle turning in from that same T
  within 8 m of the arc (`left_turn_yield_m`); right turns do not cross it.
- Street lamps follow the same dusk-to-dawn rule as the vehicles
  (`OrisonV2StreetTraffic.lamp_factor`, one source of the times).
- Any merged script or data change expires the V2 runtime and surface
  receipts.

## 9. Authored body-mesh LOD extension — queued design, October 28

Owner request: extend LOD beyond omitting detail to switching the main body
mesh. This section specifies future implementation; it changes no runtime
schema, installed asset or acceptance status. **P-BODY-MESH-LOD** in TASKS.md
owns delivery. Start with one measured traffic stock, then extend only where
the same approach has demonstrated value. Keep this design here rather than
create another parallel specification or global LOD manager.

### Existing owners and the gap

**orison_v2_street_traffic.gd**, **_write_instances / _write_vehicle**, selects
detail using street x and always writes **kind.stock** for the body. Omitting
wheels/riders does not simplify that body. The generated traffic table uses
**orison.v2.street-traffic.v1**; its existing **lod** fields also control flow
and junction policy, so they must not be reinterpreted as mesh-selection data.

Body alternatives already exist elsewhere: **dream_critter_blender_assets.gd**
loads separate LOD0/LOD1 templates, and **dream_critter_blender_batch.gd** owns
their inspection selection and triangle budget. Resident presentation retains
imported surface index LODs. Reuse those owners; do not replace them with a
traffic-specific convention. Prefer native index LOD where it already solves
the measured cost. Authored body variants serve topology, material/part-count
or silhouette simplification that detail hiding/index reduction cannot supply.

### Proposed visual-only contract

Add an optional, explicitly versioned **visual_lod** block to participating
asset recipes. The traffic adapter should emit a versioned v2 table and accept
legacy v1 tables unchanged. No block means the current body and current detail
policy. Keep the new block independent of existing **lod** flow settings.
The example below is illustrative design data, not a new runtime input:

```json
{
  "visual_lod": {
    "schema": "orison.visual-body-lod.v1",
    "reference_height_px": 1440,
    "selection": "projected_height",
    "variants": [
      {"id": "near", "mesh_set": "body_near", "detail_profile": "full"},
      {"id": "mid", "mesh_set": "body_mid", "detail_profile": "reduced"},
      {"id": "far", "mesh_set": "body_far", "detail_profile": "silhouette"}
    ],
    "transitions": [
      {"fine": "near", "coarse": "mid", "coarsen_below_px": 140, "refine_above_px": 175},
      {"fine": "mid", "coarse": "far", "coarsen_below_px": 40, "refine_above_px": 55}
    ],
    "fallback": "near"
  }
}
```

Thresholds are calibration examples, not approved budgets. Normalize projected
height to the declared reference viewport height, using the actual camera
projection/FOV and conservative shared body bounds. Account for orthographic
views and near-plane intersections; a camera inside the bounds requests near.
Distance may cheaply reject irrelevant objects but must not determine final
detail during telescope zoom. Use separate refine/coarsen thresholds, bounded
selection cadence and minimum dwell to prevent flicker without delaying a
close approach. Validate positive ordered thresholds, unique variant ids,
resolvable mesh sets, compatible bounds/material partitions and a valid
fallback. Missing optional variants keep a valid loaded body with a bounded
diagnostic; they must never make an actor disappear or trigger synchronous
loading during a turn. Malformed authored data fails its build/schema check.

Each mesh set resolves explicit body meshes and material partitions in the
existing stock manifest. Each variant must contain genuinely different geometry
with measured triangle/surface counts, not another name for the same mesh.
Detail profiles remain separate: a reduced body may retain necessary moving
parts. In particular, distant cars need believable wheels, ground contact and
wheel arches; merge simple wheels into a far silhouette if appropriate rather
than produce floating coachwork. Preserve distinctive proportions, windows,
rooflines and period identity before small ornament.

### Authoring, ownership and residency

- Author alternatives in the same editable Blender source and preferably the
  same exported GLB/manifest. No hand-edited glTF and no separate file per LOD
  unless measured residency requires it. Shared packaging reduces file/import
  overhead but does not automatically reduce resident memory. Record triangles,
  surfaces/materials, bounds, texture use and packaged bytes per variant.
- Keep stable semantic actor/part ids, local origins, scales, hinge/wheel pivots
  and attachment roots. Swap visuals within the existing actor; retain motion,
  wheel travel, steering, brake/signal state, audio and animation phase. Collision,
  reticle targets, physical constraints, inventory, resident relationships,
  quests and saves stay with their current owners. Visual LOD never changes live
  braking/avoidance or promotes background cross-flow into gameplay simulation.
- Rigid stock, skinned residents and procedural critters need distinct adapters.
  Skinned variants share validated skeleton/bone mappings and animation state;
  procedural templates preserve atlas/anchor contracts. Keep the critter batch's
  existing triangle cap and inspection allocation. Do not force all families
  through one replacement scene or override budgets to satisfy a detail pin.
- Traffic MultiMesh batches become stock + variant + material/part batches.
  Maintain stable actor-to-slot bookkeeping and bounded dirty migrations. Avoid
  per-frame scene scans, mesh rebuilding, scene instantiation or resource loads.
  Prewarm through the current residency loader; retain a ready fallback. Budget
  added batches and shader/material variants as well as saved triangles.
- Selection is transient derived presentation, never a campaign save field.
  Reload reconstructs it from current observers. A grab or inspection uses its
  existing owner's suitable detail/reservation policy without resetting input
  or bypassing a hard rendering budget. Companion readability stays with its
  installed presentation owner.

### Cameras, transitions and surfaces

Evaluate relevant main, mirror and telescope observers using their actual
visibility masks. Shared MultiMeshes choose the finest required variant across
those observers unless the existing renderer already supplies per-view index
LOD; do not duplicate the world for each camera. Small reflections should not
pin unrelated stock at near detail. Preserve the companion layer's visibility
and the lamp's separate world-occlusion rules.

Start with hard swaps plus hysteresis. Do not require alpha/dither crossfades:
they can add draws, disrupt glass and introduce visible noise. Add a transition
effect only if rendered comparisons justify its cost. All variants still need
UVs, custom catalogue PBR, normals/tangents and loaded mipmaps. Preserve glass
tint, alpha/culling and shared finish ownership; lower detail is no exemption.
Check silhouettes, gaps and contact shadows from all supported views.

### Delivery and verification

1. Freeze a baseline for one traffic body and the existing traffic route. Measure
   CPU/render submission, main and private-view GPU costs, triangles, draw calls,
   shadow passes, resident memory and first-view load/compilation separately.
2. Implement the optional schema/validator, Blender export and traffic adapter
   together. Prove real distinct body geometry, legacy/no-block fallback, missing
   variant fallback, hysteresis and stable part ownership with meaningful tests.
3. Through the shared Godot lane, compare the same occupied route/settings,
   cold and warm: p50/p95/p99/max and spike counts. Exercise rapid turning,
   approach/retreat, transitions, mirror/telescope zoom and relevant actual
   grab/inspection/release. Check traffic stop/avoidance and unchanged validated
   save/load reconstruction; do not rerun unrelated mechanisms.
4. Inspect rendered transitions and silhouettes before broad rollout. Record
   gains and regressions, including extra batches, memory and loading spikes.
   Expand only to measured beneficiaries; do not manufacture three variants for
   every asset. Retain original failures, runtime-contract evidence and static
   comparison gates separately from diagnostics and human artistic acceptance.

This is a queued optimization capability, not a claim of improved frame times
or completed visual qualification. It does not displace current repairs or
authorize unrelated gameplay changes.
