# Orison architectural program — 2026-08-28

Status: **PROPOSED FOR OWNER ACCEPTANCE**. This is the room-program authority for
the replacement Orison. It describes activities and performance, not a furniture
shopping list. Existing room profiles and checkpoints are observations only.

## Basis and dimensional language

The Orison is a six-storey, basement-and-roof, 1928 reopening of a 1912 Queens
apartment house. Its residential floors retain four lettered units so resident
ownership and route language survive. Habitable rooms receive a street, yard or
substantial court window; bathrooms may use a legal shaft or mechanical exhaust.
Public and service circulation are distinct wherever staff work, refuse, fuel or
repairs would otherwise cross a private domestic room.

Historical baseline is deliberately conservative. New-law tenements were shaped
by light, air, indoor sanitation and fire-protection requirements; New York's
official historical summaries describe outward-facing windows, indoor bathrooms,
ventilation and increased fire safeguards. The later Multiple Dwelling Law records
a 0.914 m clear minimum for post-1912 public halls and stairs and their separation
from elevators. Those are period floors, not the gameplay target. The blockout uses
1.20 m primary public routes, 1.05 m service routes, 0.90 m apartment clear routes
and a 0.66 m interaction body envelope. Historical plan catalogs and surviving
apartment-house records support repeated stacks, double-loaded halls, galley
kitchens, dining alcoves, courtyards/light courts and hotel-like common amenities.

Sources: repository authority `design/ORISON_BIBLE.md`; measured evidence
`design/ORISON_SPATIAL_CENSUS_2026-08-27.md` and the bounded F01/F02/F04/B1-roof
checkpoints; [NYC Department of Buildings, Multiple Dwelling Law](https://www.nyc.gov/assets/buildings/pdf/multiple_dwelling_law.pdf);
[NYC Municipal Archives, Department of Buildings plans](https://a860-collectionguides.nyc.gov/repositories/2/resources/72);
[NYPL, 1925 Pease & Elliman apartment-plan catalog](https://digitalcollections.nypl.org/collections/1e5aae20-483b-0137-02c7-7d9c2cc9fc4a);
[NPS, Cambridge Apartments](https://home.nps.gov/articles/000/cambridge-apartments.htm).

Dimension codes used below:

- **P** period/architectural requirement or historically grounded allowance.
- **G** gameplay/controller requirement.
- **A** accessibility/readability allowance (not a claim of modern-code compliance).
- **C** existing content or contract requirement.
- **D** conservative design allowance.
- **E** estimate to be proved in blockout.

All dimensions are clear finished dimensions. `—` means deliberately absent.
Every door needs a complete leaf, frame, latch side and reachable standing position;
public/service fire doors are self-closing in the fiction and must never conceal a
required prompt.

## Universal use envelopes

| Envelope | Minimum clear reservation | Basis |
|---|---:|---|
| Controller interaction stance | 0.90 × 0.90 m, 0.66 m body circle, 0.45–1.20 m reach | G/A |
| Door approach, pull side | 0.90 × 1.20 m beyond open leaf | G/A/D |
| Door approach, push side | 0.90 × 0.90 m beyond open leaf | G/A/D |
| Primary public route | 1.20 m continuous; 1.50 m passing/turning at decisions | G/A/D |
| Service route | 1.05 m continuous; 1.35 m at carts/apparatus | G/D |
| Apartment route | 0.90 m continuous; local 0.80 m only at existing-content pinch | G/D/C |
| Chair in use | 0.60 × 0.75 m plus 0.75 m rear withdrawal | D/G |
| Desk work station | 1.20 × 1.80 m including chair and approach | D/G |
| Bed, single/double | 1.0 × 2.0 / 1.4 × 2.0 m plus one 0.75 m side approach | D/G |
| Kitchen work front | fixture depth 0.65 m plus 1.05 m clear standing strip | D/G |
| Bath fixture front | 0.75 m deep clear approach; 0.90 m at interactive fixture | D/G/A |
| Radiator reservation | unit depth 0.25 m plus 0.45 m service front | P/D/G |

## Public and shared program

| Category | Why / users / ordinary activities | Minimum and preferred geometry / clear area | Doors, daylight and building services | Adjacency, separation and classification | Gameplay, interaction, controller and deliberate absence | Every residential floor? |
|---|---|---|---|---|---|---|
| Street entrance and vestibule | Weather lock and address for residents, visitors, post and staff; enter, shed rain, verify address | 2.4 × 3.0 m min; preferred 3.0 × 3.6 m, 7.5 m² clear route | Two sequential 1.10 m outward-egress doors, non-conflicting swings; glazed street light; radiator outside wet mat; bell/house-line conduit | Street → vestibule → lobby; public; no direct view into private apartment or service yard | First threshold, readable handle/prompt and 1.50 m turn; no desk, mail sorting, display clutter or decorative island | No, F01 only |
| Lobby | Orientation, short wait, post and house identity for residents/visitors/watch | 5.4 × 7.2 m min; 1:1.2–1.5 preferred; 22 m² clear after stations | Two public exits/branches; street/court daylight; radiators under windows; general light, clock and telephone circuits | Vestibule, mail, watch, passenger core; buffered from refuse/fuel; public | Street-to-core sightline, landing direction and optional stations; controller-complete benches/mail/telephone; no reception counter, arcade cabinet or duplicate apparatus | No, F01 only |
| Superintendent/watch station | Night watch, keys, register, annunciator, resident contact; player and superintendent | 3.0 × 4.2 m min; preferred 3.6 × 4.8 m; 8 m² work clearance | One 0.91 m door plus open counter to lobby/service hall; borrowed lobby light acceptable; radiator; dedicated light, telephone, annunciator and clock circuits | Lobby-facing but lockable; service hall and office adjacent; private records screened; service-controlled | Opening clock-in and work-order custody; each instrument gets stance/feedback/abort; no case-state ownership or generic reception furniture | No, F01 only |
| Common room | Resident meeting, reading, radio listening and brief events | 4.8 × 6.0 m min; preferred 1:1.3, 18 m² reconfigurable clear area | Two 0.91 m doors if occupancy/route demands; street/court windows on two bays; two radiators; multiple receptacles and radio/telephone jack | Public-resident zone off lobby, acoustically separated from apartments and watch records | Optional conversation/event venue; clear perimeter and seated approaches; no bar, stage or storage overflow unless fiction earns it | No |
| Parcel/package storage | Secure incoming parcels and short sorting by post/staff/residents | 2.4 × 3.6 m min; 6 m² clear aisle; shelving envelopes 0.45 m deep | One 0.91 m staff door and controlled resident hatch/door; borrowed light allowed; low heat, ventilated; light and call bell | Watch/mail/service hall; separated from lobby path, boiler and refuse; service | Parcel interaction and maintenance deliveries; no resident long-term storage or decorative display | No |
| Staff restroom | Sanitary provision for superintendent/watch/service staff | 1.5 × 2.1 m min; preferred 1.8 × 2.4 m | One 0.81 m inward or outswing-to-private door; shaft/court window or exhaust; basin/WC, hot/cold/waste, light | Service hall near station; never opens directly to lobby or food space; service/private | Simple readable fixtures; no resident case content or storage | No |
| Resident storage | Locked seasonal trunks and household overflow | Cage bay 1.5 × 2.1 m; 1.05 m shared aisle | One 0.91 m controlled room door; open cage gates; dry ventilation, low heat, protected light | Basement dry zone near resident stair/lift; separated from coal, boiler, electrical and laundry wet work; resident/service | Search/inspection possible without making a maze; no prop dump, bedroom or workshop | No |
| Passenger elevator | Resident/visitor vertical travel; attendant/service inspection as secondary use | Shaft about 2.35 × 2.45 m; car 1.55 × 1.75 m; 1.50 × 1.80 m landing clear | 0.91 m landing opening and car gate; ventilated shaft; machine power, call stations, interlock circuit | Public core, fire-separated from stair; never sole egress; not used as dumbwaiter | Legible call/arrival/locked state; full controller input; named landing anchors; no freight clutter | Yes, one landing |
| Service lift/dumbwaiter | Parcels, linen and light service goods without occupying passenger core; staff only | Dumbwaiter shaft 1.15 × 1.15 m; landing work bay 1.35 × 1.50 m | 0.76–0.91 m vertically sliding/latched landing opening; shaft vent; brake/interlock and call wiring | Continuous rear service stack: F01 parcel/service, residential kitchen/service lobbies, B1 stores, roof service; never opens in bedroom/public lobby | Maintenance apparatus and delivery continuity; not player transportation; absent if owner rejects separated service stack | Yes where stack passes |
| Primary stair | Main egress and everyday resident route | 1.20 m clear; riser 0.165 m, tread 0.285 m; 1.20 m landings | Fire-separated doors 0.91 m; window/court daylight each floor plus electric light; roof access | Public core, directly accessible from every apartment by public hall; separated from lift and service stair | Readable up/down, floor plates, continuous handrail; controller-safe cadence; no storage under/within route | Yes |
| Service stair/circulation | Staff, deliveries, refuse and maintenance route; secondary egress assumption pending code review | 1.05 m stair/hall; riser 0.175 m, tread 0.265 m; 1.05 m landings | 0.91 m self-closing doors; court/rear windows; protected lights and service call | Rear service spine linking B1–roof and kitchen/service vestibules; separated from public lobby and bedrooms | Essential service continuity and alternate route; no resident lounge, loose storage or case gate | Yes |
| Corridors and landings | Distribute residents and orient player | 1.20 m clear, 1.50 m at lift/stair/apartment decision; run preferably under 12 m between decisions | Apartment doors 0.91 m; core doors 0.91 m; court/end daylight; radiators only in protected recesses; lights, floor plates, phone/conduit riser | Public resident route; no direct coal/refuse opening; apartments buffer private rooms with vestibules | Landing tells floor and unit direction without HUD; prompts remain visible with doors open; no seating/storage spill | Yes |
| Telephone/message infrastructure | House board, subscriber lines, service calls and physical message custody | Board work bay 1.8 × 2.4 m; riser cupboard 0.9 × 1.2 m; 0.9 m stance | Lockable cupboard; dry, ventilated; dedicated low-voltage routes separated from power where practical | Main board at watch station, riser at service core, branches to units and apparatus; service/private | Semantic audio ownership and house-line interactions; no wireless abstraction or story-state ownership | Riser/branch yes; staffed board no |

## Apartment program

| Category | Why / users / activities | Minimum and preferred geometry / clear area | Doors, daylight, heat, ventilation, plumbing, power/telephone | Adjacency, separation and classification | Gameplay / interaction / deliberate absence | Every residential floor? |
|---|---|---|---|---|---|---|
| Apartment vestibule | Privacy and distribution: enter, remove coat, choose room | 1.5 × 2.1 m min; 1.8 × 2.4 m preferred; 1.2 m turn at branch | 0.91 m inward apartment door; internal doors 0.81 m; borrowed light acceptable; hall switch/telephone conduit | Public hall → vestibule → domestic rooms; bedrooms/bath not exposed to corridor | Threshold read and door clearance; no freestanding furniture except shallow coat storage | Each unit |
| Living/dining room | Household rest, meals, guests; resident and visitors | 3.6 × 5.4 m min; 1:1.3–1.6 preferred; 12 m² unclaimed floor after use envelopes | One/two 0.81 m internal doors; exterior/court window area; radiator; general/task receptacles and telephone/radio point | Vestibule, kitchen/dining alcove; separated from service stair and bathroom fixture wall where possible | Primary resident/case room; stations readable from threshold; no duplicate sofas/desks or filler furniture | Each unit |
| Kitchen | Cooking, washing dishes, food storage; resident and service worker | 2.4 × 3.3 m min; galley 2.4–2.8 m wide; 1.05 m work aisle | 0.81 m door or cased opening; court/rear window or exhaust; radiator clear of work run; hot/cold/waste/gas or electric and dumbwaiter/service bell where justified | Shares wet/service wall with bath/neighbor kitchen; near dining; never route to bedroom/bath | Required appliance envelopes before props; repair stances; no island, luxury duplicate appliances or door swing into range | Each unit |
| Bedroom | Sleep, dressing, clothes storage | 3.0 × 3.6 m min; preferred 1:1.2–1.4; 5 m² clear beyond bed/storage | One 0.81 m privacy door; exterior/court window; radiator under/near window; light/receptacle, optional telephone only if fiction supports | Off vestibule/private short hall; not a route to another room; separated from lift/service stair machinery | Bedside/wake approach where required; no case workstation unless resident program says study-bedroom | At least one per family unit; studio exception |
| Bathroom | Toilet, basin, bathing | 1.8 × 2.4 m min; preferred 2.1 × 2.4 m | 0.76–0.81 m privacy door not colliding with fixtures; shaft/court window or exhaust; heat; hot/cold/waste and protected light | On wet stack beside kitchen/other bath; reached from vestibule/private hall, never through bedroom for primary bath | Complete fixture and interaction fronts; no decorative fiction, storage spill or maintenance path through bedroom | Each unit |
| Office/study | Sustained private work, records, reading | 2.4 × 3.0 m min; 1:1.2–1.5; 4 m² clear beyond desk/storage | 0.81 m door/cased opening; exterior/court window; radiator; task power and telephone | Living/vestibule, acoustically buffered from service stair; may be alcove if privacy not required | Case station where earned; no second generic desk or invented profession | Only resident programs that require it |
| Alcove | Compact defined secondary use: dining, sleep or work | 2.1 × 2.4 m min; at least 2.1 m clear opening if unenclosed | No door unless it becomes a room; borrows adjacent window only if open; heat/power from parent | Opens directly to parent living room; never contains sole apartment egress | One named use envelope; no ambiguous leftover pocket | Optional |
| Closet | Enclosed clothes/linen/equipment storage | 0.65 m clear depth; walk-in 1.5 × 1.8 m | 0.61–0.76 m door, preferably out of circulation; dry vent where deep; light only if walk-in | Vestibule/bedroom/bath linen edge; not wet-stack access unless separate panel | Door and access fit; no playable room or filler objects | At least coat + bedroom storage per unit |

## Service, basement and roof program

| Category | Why / users / activities | Minimum and preferred geometry / clear area | Doors, environmental and utility requirements | Adjacency, separation and classification | Gameplay / interaction / deliberate absence | Every residential floor? |
|---|---|---|---|---|---|---|
| Boiler room | Heat production, firing, gauge/valve maintenance | 5.4 × 7.2 m min; 1.2 m apparatus aisles, 1.5 m firing front | Two 0.91 m service exits where feasible; combustion air/exhaust; drain, feed water, power/light; no radiator | Coal annex, chimney, service stair and risers; fire-separated from resident storage/laundry | Whole plant reads as one system; apparatus stances and rollback; no unrelated storage | No, B1 |
| Coal room | Dry fuel receipt and short path to boiler | 3.0 × 4.2 m min; delivery and shoveling clearances | 0.91 m fire door to boiler/service yard; dust ventilation, low protected light | Exterior/service delivery and boiler only; separated from laundry/electrical | Fuel continuity; sparse and dirty, not general storage | No, B1 |
| Electrical room | Main switch/fuse distribution | 3.0 × 4.2 m min; 1.2 m panel-front clearance | 0.91 m outward service door; dry ventilation; dedicated protected light; main feeders/earth | Service entrance/riser; separated from water, coal and resident access | Fuse/inspection station; no storage or wet pipe above panels | No, B1 |
| Laundry | Shared wash, dry, fold and wait | 4.2 × 5.4 m min; 1.2 m machine fronts, 8 m² shared clear floor | 0.91 m door; court/rear window plus exhaust; heat, hot/cold/waste, power/gas | Resident/service stair, drying yard/roof route; separated from coal/boiler dust | Complete wash-dry-fold sequence; no cage storage or second workshop | No, B1 |
| Maintenance shop/storage | Repair bench, parts, cart and safe tool custody | 3.6 × 5.4 m min; 1.2 m bench front, 1.05 m cart route | 0.91 m door; rear/court window or exhaust; heat, sink if possible, robust power/telephone | Watch/service spine, electrical/boiler nearby but separated; no public passage through shop | Fetch/return station and tool interactions; no case authority or resident storage | No, B1/F01 split allowed |
| Roof service spaces | Tank, lift machinery, vents, clothesline/garden maintenance | Bulkhead 3.0 × 4.2 m; machinery rooms by equipment; 1.2 m roof paths | 0.91 m roof doors; weatherproof ventilation/drainage; tank/vent/electrical routes | Direct continuation of both cores and risers; resident deck separated from machinery | Service continuity and safe guardrails; no speculative penthouse, bedroom or clutter | No, roof |
| Maintenance circulation | Inspect risers, meters, chutes and plant without crossing bedrooms | 1.05 m continuous, 1.35 m work bays | Lockable 0.91 m doors/panels; protected light and service call points | Service stair, rear halls, riser cupboards, basement/roof; never through private sleeping rooms | Route supports carts and controller stances; no unexplained corner stations | Service path on every floor |

## Special residential conditions

| Category | Required program | Spatial consequence | Must remain absent |
|---|---|---|---|
| Case-specific apartments | Preserve resident/unit ownership and only the activities established by case authority. Mina 2A needs immediate sound-led entry, caption/work station, ordinary living/dining, full kitchen, private bedroom/bath, filing, conversation clearance and `F02_A_MAIN_VANTRY_POINT`. Later cases reserve adaptable stations without inventing unsanctioned case geometry. | Unit envelopes may differ by one bay where work/study or household size requires it; wet/service stacks stay aligned. | Prop-authored symbolism, debug labels, topology that reveals case truth, duplicate work stations |
| Player apartment 4B | Exhausted maintenance worker's compact home: vestibule, complete bath, galley, living/work room, sleeping alcove, clothes/equipment storage, physical telephone/terminal route and bedside return. | 4B remains on F04, letter B, with a readable path from public landing; `F04_B_MONITOR_01` and `F04_B_BED` are named anchors independent of raw coordinates. | Luxury matching suite, invented biography, route through bath/closet, wake point derived from anonymous furniture search |
| Vacant space | Legally complete but intentionally unoccupied unit; inspectable fabric and services | Normal apartment topology, fewer authored use envelopes, services capped/readable | Placeholder furniture, unexplained empty room, false active utility |
| Sealed space | Known unit whose access is physically and narratively closed | Door/threshold remains on public route; interior may be gray-boxed only when a case needs it | Accidental navigable gap, arbitrary lock state, decorative tease that implies authority |
| Transient/short-term space | Temporary occupancy with luggage, sleep, bath and minimal meals | Standard apartment shell with flexible storage and no permanent study claim | Permanent resident biography, missing sanitary/cooking minimums |

## Required adjacency and separation rules

1. Every unit touches a public hall at its vestibule and an exterior wall or
   substantial light court at every habitable room.
2. Kitchens and bathrooms cluster around two wet-stack bands; no maintenance
   route enters a private bedroom.
3. Passenger lift and primary stair form a legible public core but are
   fire-separated. The service stair/lift form a distinct rear core.
4. Watch, mail, parcel and telephone board share an F01 service cluster visible
   from the lobby without turning the lobby into a workroom.
5. Coal touches boiler and delivery; it never touches laundry, resident storage
   or public circulation without a fire-separated buffer.
6. Electrical stays dry and away from fuel. Telephone/message risers are
   accessible from service circulation, not apartments.
7. Bedrooms do not share the lift machine wall, service stair, refuse handling
   or common-room event wall where a buffer room can intervene.
8. Radiators reserve service frontage before furniture. Doors never consume a
   required apparatus, fixture, interaction or turning envelope.

## Program acceptance tests

- Every scheduled room has one named ordinary activity and sufficient clear
  envelope for it before props exist.
- Every included habitable room has a plausible daylight/ventilation source.
- Every wet room resolves to a continuous stack from B1 to roof.
- Every required player interaction has a reachable standing envelope and
  readable feedback path with keyboard/mouse and controller.
- Public, private and service paths can be traced without crossing one another
  at a bedroom, bathroom, coal room or back-of-house work station.
- Anything absent is absent deliberately; no leftover polygon becomes a room.
