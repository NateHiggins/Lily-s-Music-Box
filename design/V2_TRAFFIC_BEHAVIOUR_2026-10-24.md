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

The five warnings are synthesized offline by a deterministic recipe as
16-bit mono 22.05 kHz WAVs. Nothing is recorded or downloaded. Each is
registered as an `AudioPolicy` cue with purpose `hazard` on the Hazard bus,
with these captions:

- **traffic.klaxon**: "Klaxon: ah-oo-gah"
- **traffic.bulb_horn**: "bulb horn honks"
- **traffic.foot_gong**: "bus gong clangs"
- **traffic.brake_shriek**: "brakes shriek on wet setts"
- **traffic.whip_crack**: "whip cracks; iron shoes skid"

`PropAudio` describes itself as a recorded bank. Recorded period
replacements, such as CC0 recordings of a Klaxon, a bulb horn and a gong, are
a follow-up that needs the owner's permission to download.

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
  is a raised arm, not a bent forearm.
- Left-turning vehicles do not yet yield to oncoming traffic in the other
  lane.
- Street lamps (PR 22) do not follow the clock.
- Any merged script or data change expires the V2 runtime and surface
  receipts.
