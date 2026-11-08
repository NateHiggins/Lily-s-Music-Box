# V2 street trams: the trolley line under the el

Evidence class: **INERT**. This is a design note and build record. It is not runtime acceptance, and the
capture it cites grants nothing.

## Ruling

Lily's ruling **trams_route** (2026-11-08): the line runs down the Orison's own avenue, under the el. There are
rails in the roadway and span wire on poles. A car comes every few minutes and shares the road with the period
traffic. The arcs show from the street and from the windows.

Her earlier ruling **sun_storms** (2026-11-04) ties storms to the aurora with "more trolley arcs". This line is
where those arcs happen.

Why here: the elevated station over the avenue, 26 to 104 m east of the door, is Queensboro Plaza, where Queens
Boulevard begins. In 1929 its surface cars ran on the street under the el. Order **T-V2-TRAMS** (TASKS.md).

## What is built

- **Cars are traffic.** `OrisonV2StreetTrams.attach` registers the car with `OrisonV2StreetTraffic` as a rail
  kind of class `tram`. Cars accelerate, brake, follow, stop at the T, yield, warn with the foot gong and are
  drawn by the traffic's own batches. The street's lottery never picks one. The line sends a car each way on its
  headway, 4 minutes at the rush and 20 to 30 through the night, because the 1929 Queens lines ran owl cars.
- **One path per track.** `rail_journey` always turns between the avenue and the far-side cross streets, away
  from the Orison.
  - Westbound uses the near lane, in from the east cross street and out up the west.
  - Eastbound uses the far lane, the other way.
  - Every car on a track takes the same path, so the rails and the contact wire are sampled from the traffic's
    own pose function and cannot drift from the cars.
- **Overhead.**
  - On the avenue, span wires run from far-kerb poles across both wires. At x −58, −33, 31 and 57 m they reach
    near-kerb poles. At x −3 m they reach a rosette on the Orison's own brick, because the door, the lamps and
    the crossing route leave no room for a pole there.
  - Up each cross street, a pole stands on each side every 26 m, out to 60 m.
  - The poles have simple cylinder collision.
- **The car.** `art/blender/scripts/build_v2_street_trams.py` builds a closed double-truck car about 13 m long:
  - green panels and cream window posts
  - a monitor roof with deck lights
  - a lit saloon ceiling
  - the trailing trolley pole up to the wire at 5.5 m, the leading one down on its hook
  - a motorman and six passengers
  The headlamp and the saloon follow the traffic's dusk and dawn rule.
- **Arcs.**
  - A blue-violet flash at the trolley wheel, about 1.6 a minute for each moving car.
  - Six times as many when `aurora` or `steve` is active.
  - Twice as many on wet rails.
  - Under `reduce_flashing`, one soft glow at most every 1.5 s, never a flicker.

## Not built

- **Destination signs:** the sign box over the windscreen is lit but blank. Lettering would be Label3D (RUL-008),
  and the route name is a canon question.
- **Pull-offs on the curves:** the curved wire between the last avenue span and the first cross-street span is
  unsupported in between.
- **Arc sound.**

## Verification

The lane runs are in `C:/ov/reports/v2_trams_20261108/`:
- `V2StreetTramsTest` is a headless contract. It checks:
  - the cars follow their rails round both corners
  - they never drive through a slow wagon
  - the headway
  - the lottery never picks a tram
  - the aurora and wet multipliers
  - the flash at the wire
  - reduced flashing
  - the overhead is raised clear of the door, the lamps and the crossing
- `OrisonV2TrafficBehaviourTest` checks that the street's own behaviour is unchanged.
- `V2StreetTramsShot` is an INERT windowed capture of the production world by day and by night.
