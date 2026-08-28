# Orison architectural rebuild — checkpoint 01 — 2026-08-28

Status: **OWNER-ACCEPTED 2026-08-28; PARALLEL GRAY-BOX AUTHORIZED**
Scope: program, contracts, failure synthesis, topology alternatives, recommended
topology, dimensioned first-slice proposal and staged migration.  
Production building changed: **no**.

Companion authorities:

- `design/ORISON_ARCHITECTURAL_PROGRAM_2026-08-28.md`
- `design/ORISON_REBUILD_MIGRATION_CONTRACT_2026-08-28.md`

## Evidence and stop ruling

The old 28 × 20 m, six-floor building declares 127 rooms. Its repeated central
6.5 × 6.5 m atrium/ring envelope, rectangular room records and 4,419-record F01
site/interior ownership made local audits hard to interpret. The bounded room
reconstruction proved many individual stations and routes, but it also proved that
furniture edits cannot correct the plan's governing problems. The old layout is
therefore frozen after its latest bounded checkpoint except for route preservation,
severe regressions or protection of another workstream.

No existing dirty or untracked file was touched. The active Claude interaction-
contract lane is source-only and outside these new design files.

## Current-layout failure synthesis

| Systemic failure | Evidence | Rebuild requirement |
|---|---|---|
| Room rectangles are not reliable built extents | F04 corridor's envelope wraps separated lanes/atrium; checkpoint warns computed width is not literal. Nested baths/alcoves and endpoint offsets complicate ownership. | Polygonal rooms/openings from one schema; no inference from a coarse containing rectangle when explicit ownership is available. |
| Geometry dictates activity instead of supporting it | 4B's 2.75 m² vestibule is entirely door negotiation; its desk rug crossed a bathroom wall. Mina's filing needed movement to clear a leaf. | Size activity envelopes before furniture; vestibules distribute, kitchens work, bedrooms sleep and service bays remain serviceable. |
| Public, private and service traffic share one ring | Lobby apparatus continues into an ambiguously declared hall; deliveries, residents and maintenance rely on the same central geometry. | Legible public core plus continuous rear service spine from B1 to roof. |
| Vertical services are props more than a plan | Current dumbwaiter began as one F01 landing; wet, telephone, refuse and maintenance routes are not all represented by continuous authority. | Explicit riser records and endpoint matrices generated through all floors. |
| Door proof is repeatedly exceptional | Square-envelope false positives required radial/manual rejection; raw ids/positions appear in runtime comments and special cases. | Exact hinge/swing geometry and named approach anchors in the authoritative schema. |
| Necessary functions compete with unsupported rooms | Staff WC, package, watch and storage exist but their relationships are inherited; some vacant/sealed rooms are topology-neutral leftovers. | Program every room, remove filler, and use deliberate vacant/sealed conditions only within complete apartment shells. |
| Route readability depends on learned coordinates | Current evidence proves signs and stations locally, but the ring and long ambiguous envelopes require prior knowledge. | Short decision-to-decision public route with daylight/core landmarks and visible unit directions. |
| Multiple spatial authorities can drift | Generator JSON, built glTF, runtime detail passes and gameplay lookups do not always share a semantic anchor. | One v2 topology/anchor schema; deterministic derived geometry; adapter for preserved ids. |

## Non-negotiable adjacency and circulation

Public route: street → vestibule → lobby → passenger lift/primary stair → floor
landing → short unit corridor → apartment vestibule. Resident travel never crosses
watch work, parcel sorting, coal, boiler, electrical or refuse handling.

Service route: rear/service threshold → F01 service hall/watch back door → service
lift/stair → residential service vestibules/riser cupboards → B1 plant/stores and
roof tank/machinery. Maintenance reaches wet, heat, power and telephone risers
without entering a bedroom. Deliveries can reach parcel storage and kitchen-side
service points without crossing the lobby's central arrival lane.

Private route: apartment vestibule → living/dining and short private distributor →
bed/bath/closet. A bathroom or bedroom is never a through-route. 2A's first view
finds the chirp/work zone; 4B's first view finds home, not the wake bed itself.

## Topology alternatives

Common assumptions: street is south; six residential/entrance levels remain
`F01`–`F06`, with `B1` and `ROOF`; four unit letters per typical residential
floor; 3.20 m floor-to-floor; masonry/fire-resisting core construction; explicit
public and service vertical routes.

| Option | Plan | Strengths | Costs/risks | Verdict |
|---|---|---|---|---|
| A — compact H-plan | 32 × 24 m outer envelope, two 5.2 × 8.0 m open courts, central public core and north-east service core; four apartments around short hall arms | Strong daylight, repeated wet/service stacks, short readable routes, four-unit ownership, plausible 1912/1928 massing, deliberate F01 asymmetry | Larger footprint; two courts and second stair require owner acceptance; careful street/site fit | **Recommend** |
| B — street-facing U court | 31 × 26 m U opening south, public core at court head, service spine across north | Excellent arrival/court identity and daylight; lobby can address court | Public and service movement cross at court head; long wings; street threshold becomes more ceremonial than current fiction | Hold as fallback if owner prioritizes courtyard arrival |
| C — twin bars with enclosed bridge | Two 11 × 25 m wings, public bridge/core between, rear service core | Clearest separation, easiest staged streaming and daylight | Reads like a complex rather than one Orison house; more exterior envelope, bridge complexity, weakest continuity with established unit language | Reject for current fiction |

### Recommendation: Option A, compact H-plan

The H-plan makes the building's mundane systems legible without decorative
complexity. Two courts give habitable rooms honest light and reveal vertical life;
the public core remains a stable landmark; the rear service spine gives the job a
physical route. Typical floors repeat. Legitimate asymmetries are limited to F01
public/service program, 2A case work, 4B player alcove/work station, sealed/vacant
conditions and roof/basement plant.

## Floor-by-floor adjacency graph

```text
STREET
  -> F01 vestibule -> lobby -> public core -> F02/F04 landings
                         |          |
                         |          +-> primary stair + passenger lift
                         +-> mail / watch / telephone / parcel
                                      |
REAR SERVICE -> service hall -> service stair + dumbwaiter/lift
                                      |
                 B1 plant/stores <- risers -> F02/F04 service vestibules -> ROOF

F02 landing -> west-south arm -> 2A vestibule -> main/work -> bed + bath + kitchen
            -> west-north arm -> 2B
            -> east-north arm -> 2C
            -> east-south arm -> 2D sealed

F04 landing -> west-north arm -> 4B vestibule -> main/work -> kitchen + bath
                                                    -> sleeping alcove + closet
```

## Room schedule and repeating floors

| Level | Public/resident program | Service program | Deliberate difference |
|---|---|---|---|
| B1 | Lift/stair landing, laundry, resident storage | Boiler/coal, electrical, maintenance shop, meter/chute/telephone bottoms, service stair/lift | Plant level |
| F01 | Vestibule, lobby, common room, public core, 1A and 1D | Watch/office, mail/parcel, staff WC, rear hall, service core | Public arrival and staffed service |
| F02 | 2A–2D around short H arms | Wet/heat/telephone risers and service landings | Mina 2A; 2D sealed |
| F03 | 3A–3D | Repeated stacks/service landings | Omar 3B; 3C damaged vacant |
| F04 | 4A–4D | Repeated stacks/service landings | Player 4B; 4D transient |
| F05 | 5A–5D | Repeated stacks/service landings | 5D fire-damaged vacant |
| F06 | 6A–6D | Repeated stacks/service landings | 6D landlord storage within a complete former-unit shell |
| ROOF | Guarded resident drying/garden zone | Tank, lift machinery, vents, service bulkhead | Weather/service terminus |

## Vertical stack diagram and service-riser matrix

```text
ROOF   tank/vent heads | tel head | lift machines | primary + service bulkheads
F06    wet W / wet E   | tel      | public lift   | primary + service stairs
F05    wet W / wet E   | tel      | public lift   | primary + service stairs
F04    4B kitchen/bath | 4B line  | public lift   | primary + service stairs
F03    wet W / wet E   | tel      | public lift   | primary + service stairs
F02    2A kitchen/bath | 2A point | public lift   | primary + service stairs
F01    staff/service   | board    | public lift   | primary + service stairs
B1     boiler/feed/drain | main   | lift pit      | plant + service receiving
```

| Riser | B1 | F01 | Typical residential floors | Roof | Must not share |
|---|---|---|---|---|---|
| West wet/soil | boiler feed nearby but separated; drain/cleanout | staff WC/service sink | A/B kitchens and baths back-to-back | vent head/tank feed | electrical room/panels |
| East wet/soil | laundry/cleanout | 1D/service sink | C/D kitchens and baths back-to-back | vent head | bedrooms without pipe chase buffer |
| Heat supply/return | boiler header | lobby/common/watch branches | corridor cupboard to radiators | tank/vent/expansion | door swings and furniture envelopes |
| Electrical | main switch room | public/service distribution | locked service cupboard and unit branches | lift/tank machinery | wet/coal rooms |
| Telephone/message | main entry/earth | watch board | locked service cupboard; unit/Vantry branches | protected termination | high-power feeder where avoidable |
| Parcel/service lift | B1 receiving/store | parcel/watch landing | kitchen-side service vestibule | machine/brake room | public lift shaft, bedrooms |
| Refuse/maintenance | service receiving | service hall | locked service landing/cupboard | vented head | public lobby and private rooms |

## Circulation matrix

| Route | Street/lobby | Public core | Unit hall | Apartment | Service core | Plant/roof |
|---|---:|---:|---:|---:|---:|---:|
| Visitor | yes | yes | escorted/allowed | invited | no | no |
| Resident | yes | yes | yes | own/invited | limited service landing | laundry/roof resident zone |
| Player on ordinary shift | yes | yes | yes | authorized case/4B | yes | yes |
| Superintendent/watch | yes | yes | as required | authorized | yes | yes |
| Delivery | vestibule only | no | no | no | yes | receiving/parcel |
| Refuse/fuel | no | no | no | no | yes | service receiving/coal |
| Emergency egress | yes | primary stair | yes | from unit | service stair subject to owner/code ruling | roof/basement protected exit |

## Dimensioned first-slice blockout

### Coordinate and construction rules

Option A uses metres, `+X` east, `+Z` north, street at `Z = -12.00`, and each
floor datum at `Y = 0.00 / 3.20 / 6.40 / 9.60 / 12.80 / 16.00`; B1 is `-3.20`,
roof `19.20`. Outer walls are 0.35 m **P/D**, party/core walls 0.25 m **P/D**,
internal partitions 0.14 m **P/D**, slabs 0.20 m **D**, clear ceiling 3.00 m
**P/C**, floor-to-floor 3.20 m **C**. Outer boundary is `X -16.00..16.00`,
`Z -12.00..12.00`. Court voids begin above F01 where noted; all values remain
blockout-testable estimates until owner accepts topology.

Gray-box semantics: public floors warm gray, private floors muted ochre, service
floors blue-gray, wet/service chases cyan, structural/core walls charcoal,
openings white, door swing arcs amber, required clearances translucent green,
interaction stances magenta, unresolved estimates striped yellow. No trim,
ornament, clutter or final material belongs in this slice.

### F01 arrival and service spine boundaries

| Space / anchor | Exact clear boundary or point | Openings and fixed reservations | Basis |
|---|---|---|---|
| `F01_VESTIBULE` | X -2.40..2.40, Z -11.65..-9.25 | `F01_DOOR_06`: centered south, 1.10 m, LH viewed entering, swings out; inner pair/leaf 1.10 m centered north, swings into lobby | C/G/P/D |
| `F01_LOBBY` | X -5.40..5.40, Z -9.25..-3.85 | 3.20 m central clear axis; two south windows each 1.50 m wide; radiator bays below; north-west watch opening and north-east core approach | C/G/D |
| `F01_WATCH` | X -5.40..-1.20, Z -3.85..0.55 | 0.91 m service-hall door swings into watch; 2.40 m counter/work wall; `LobbyPorterBoard`, register and key stances | C/G/D |
| `F01_MAIL_TELEPHONE` | X -9.20..-5.40, Z -3.85..0.55 | 0.91 m door; `LobbyMailBank` and `F01_HOUSE_TELEPHONE_BOARD` each 0.90 m stance | C/G/D |
| `F01_PACKAGE` | X -9.20..-5.40, Z 0.55..4.25 | 0.91 m staff door south, parcel hatch/door east; 1.05 m aisle | P/G/D |
| `F01_COMMON_B` | X -15.65..-9.20, Z -3.85..5.65 | two 0.91 m doors on east if final occupancy warrants; west street/court windows; radiator reserves | C/P/D |
| public core lobby | X -1.20..5.40, Z -3.85..3.85 | 1.50 m lift/stair decision zone | G/A/D |
| passenger lift shaft | X -1.20..1.20, Z -2.80..-0.30 | 0.91 m south landing opening; 1.50 × 1.80 m clear approach | P/C/D |
| primary stair | X 1.45..5.40, Z -3.35..3.35 | 1.20 m clear U stair; 20 risers/storey at 0.160 m; 0.285 m treads; 1.20 m landings; separated 0.91 m doors | P/G/D |
| service hall | X 8.30..9.50, Z -9.25..9.25 | 1.20 m clear continuous route; 1.35 m work bays | G/D |
| service stair | X 9.50..13.20, Z 4.20..10.20 | 1.05 m clear U stair; 19 risers/storey near 0.168 m; 0.275 m treads; 0.91 m doors | P/G/E |
| service lift shaft | X 9.70..11.00, Z 0.30..1.60 | `LobbyServiceDumbwaiter` F01 landing; 0.90 × 1.20 m stance | C/P/D |
| rear service threshold | centered at X 8.90, Z 11.65 | 0.91 m outward door; weather/service receiving bay outside | P/D/E |

F01 review cameras/stances: street `(0, 1.41, -15.0)` toward vestibule; inner
threshold `(0,1.41,-8.8)` toward core; watch stance `(-3.3,1.41,-2.4)`;
lift decision `(0,1.41,-3.2)`; service entry `(8.9,1.41,10.8)`. The first view
must reveal address → dry threshold → lobby → core without exposing service/fuel.

### Typical-floor H geometry

Above F01, open courts occupy west `X -10.80..-5.60, Z -4.00..4.00` and east
`X 5.60..10.80, Z -4.00..4.00`. The public core is `X -2.20..5.40,
Z -3.85..3.85`. Public hall arms are 1.20 m clear: west arm
`X -5.60..-2.20, Z -0.60..0.60`; east arm `X 5.40..5.60` expands into unit
vestibule decisions and will be resolved with the east-wing full plan; north/south
decision landings are 1.50 m squares. The service corridor and core repeat at
`X 8.30..13.20` behind east-unit service walls.

### F02 case-one route and 2A

| Space / anchor | Exact clear boundary / point | Openings and fixed reservations | Basis |
|---|---|---|---|
| F02 public landing | X -2.20..1.45, Z -3.35..0.60 | lift and stair approaches, 1.50 m decision square; floor/unit plate visible on exit | G/C/D |
| west-south hall to 2A | X -5.60..-2.20, Z -0.60..0.60 | 1.20 m clear; end daylight at court; no radiator/props in route | G/A/D |
| `F02_DOOR_02` / 2A threshold | centered at X -5.60, Z -0.00 | 0.91 m, RH viewed entering, swings into vestibule against south partition; pull/push envelopes | C/G/D |
| 2A vestibule | X -7.55..-5.60, Z -1.35..1.35 | cased opening west to main; 0.81 m private-hall door north | G/D |
| `F02_A_MAIN` | X -15.65..-7.55, Z -3.85..3.10 | two west windows 1.50 m each; north court window 1.35 m; radiator bays; 14 m² unclaimed clear floor | C/P/G/D |
| caption/work zone | X -12.80..-9.60, Z -0.90..2.40 | desk/file envelopes and 1.20 m conversation clearance; `F02_A_MAIN_VANTRY_POINT` at (-10.10, 1.40), interaction stance (-9.20, 1.40) | C/G/D |
| living/dining zone | X -15.30..-12.80, Z -3.35..2.70 | sofa/dining envelopes only, not authored props | C/D |
| 2A kitchen | X -15.65..-10.25, Z 3.10..6.20 | 0.81 m cased/door opening; 0.65 m north work run, 1.05 m aisle; west window; west wet stack | C/P/G/D |
| 2A private hall | X -10.25..-8.95, Z 3.10..7.85 | 0.90 m clear; no furniture | G/D |
| `F02_A_BATH` | X -8.95..-5.95, Z 3.10..5.65 | 0.81 m outswing to private hall or pocket-like period door subject to proof; wet wall east; shaft/court vent | C/P/D |
| `F02_A_BED` | X -15.65..-8.95, Z 6.20..11.65 | two west/north windows; radiator; bed/wardrobe envelopes and 0.90 m route | C/P/G/D |
| west wet/heat riser | X -9.20..-8.75, Z 3.10..6.20 | continuous B1–roof chase; access from service/private hall, not bedroom | P/D |

F02 cameras/stances: stair exit `(0,4.61,-2.8)`, landing decision
`(-1.5,4.61,0)`, 2A corridor approach `(-4.6,4.61,0)`, inside threshold
`(-6.2,4.61,0)`, work stance `(-9.2,4.61,1.4)`, bedroom/bath thresholds.
The chirp target must be audible from the open 2A threshold and visible after one
intentional turn, not from the public corridor.

### F04 player route and 4B

4B occupies the west-north stack, deliberately mirroring neither 2A's case plan nor
its room count.

| Space / anchor | Exact clear boundary / point | Openings and fixed reservations | Basis |
|---|---|---|---|
| F04 public landing / west-north hall | landing as F02; hall X -5.60..-2.20, Z -0.60..0.60 then north decision bay | 1.20 m clear; 4B plate readable before threshold | G/C/D |
| `F04_DOOR_03` | centered at X -5.60, Z 0.00 | 0.91 m, LH entering, swings against vestibule north wall without hiding main-room view | C/G/D |
| `F04_B_VESTIBULE` | X -7.55..-5.60, Z -1.35..1.65 | 1.50 m turning zone; bath/closet doors outside entry swing | C/G/A/D |
| `F04_B_MAIN` | X -15.65..-7.55, Z -3.85..3.45 | west/court windows; radiator reserves; 12 m² unclaimed floor | C/P/G/D |
| 4B work zone | X -11.30..-8.10, Z -1.10..2.30 | `F04_B_MONITOR_01` at (-9.05,1.25); interaction stance (-9.90,1.25); telephone/message conduit on service wall | C/G/D |
| `F04_B_KITCHEN` | X -15.65..-11.10, Z 3.45..6.35 | north work run and west wet stack; 1.05 m aisle; court/window ventilation | C/P/G/D |
| `F04_B_BATH` | X -9.05..-5.95, Z 3.45..6.05 | 0.81 m privacy door from vestibule/private hall; east wet wall; complete fixture envelopes | C/P/G/D |
| `F04_B_CLOSET` | X -7.55..-5.95, Z 6.05..8.25 | 0.76 m door swings out of storage envelope; 0.65 m shelf depth | C/D |
| `F04_B_ALCOVE` | X -15.65..-10.55, Z 6.35..11.65 | 2.40 m open connection to main/private hall; north/west windows; radiator clear of bed | C/P/G/D |
| explicit `F04_B_BED` | anchor at (-13.10, 8.90); bedside return stance (-11.95, 8.90), facing west; 0.90 × 1.20 m clear | Stable named anchor; legacy `bed` record adapter during migration | C/G/D |
| west wet/heat riser | X -9.30..-8.85, Z 3.45..6.35 | continuous, accessed from bath/service panel, never through alcove | P/D |

F04 cameras/stances: landing, corridor approach, inside threshold, work stance,
kitchen aisle, bath threshold, alcove threshold, and wake view at eye height 1.41 m
from `F04_B_BED`. The wake view must read bed → familiar work/home context → exit
without showing a developer label or forcing an immediate collision.

### Door, window and service rules for the slice

- Apartment entry leaves: 0.91 m **P/G/D**; internal habitable leaves 0.81 m
  **D/G**; bath/closet 0.76–0.81 m **D**; public/service leaves 0.91–1.10 m.
- Every schema door records wall, center, width, height 2.13 m, hinge side, swing,
  normally-open state and both interaction stances. Swing arcs are generated proof.
- Typical windows: sill 0.75 m, head 2.45 m, 1.35–1.50 m clear width **P/D**;
  bath/shaft windows may be 0.75 m wide with higher sill **P/E**.
- Radiators occupy window bays but never the usable door/desk/bed approach. Heat,
  west/east wet stacks, telephone, electrical and service-lift routes are reserved
  before any functional furniture.

## Deliberate asymmetries

1. F01 trades two residential units for lobby/common/watch/mail/parcel/staff work.
2. 2A gains a larger work-capable main room and ordered filing zone for case one.
3. 4B uses a sleeping alcove and combined work/living room rather than a standard
   one-bedroom plan.
4. Sealed, damaged, transient and landlord-storage units retain complete shells but
   differ in access and occupancy, not arbitrary exterior massing.
5. B1 and roof follow service needs; neither imitates residential repetition.

## Staged implementation plan

| Checkpoint | Exact scope | Validation / rollback |
|---|---|---|
| 01 — this checkpoint | Program, contracts, options, recommended topology and dimensioned slice | Markdown/link/schema review; rollback removes only three new docs |
| 02 — owner ruling | Record accepted footprint/core/stack and any dimension changes | No geometry; amended decision register |
| 03 — v2 schema/generator | Versioned semantic layout, deterministic plan/mesh output, explicit dev selector, id adapter, retirement plan | Static schema, deterministic hash, production-output hash unchanged; rollback selector/v2 paths |
| 04 — F01 gray-box | Street threshold, vestibule, lobby, watch/mail/parcel and both core approaches | Exact dimensions, junctions, door swings, import, route/anchor/player-height proof |
| 05 — vertical core | Primary/service stairs, passenger/service lift reservations, risers B1–roof | Stack matrices, landing/door tests, no production launch change |
| 06 — F02/2A gray-box | Landing, route, apartment shell and required envelopes/anchors | Chirp/job/case parity, walk/controller and acoustic proof |
| 07 — F04/4B gray-box | Landing, route, shell, terminal and explicit bedside return | Call/audio/wake/save parity and player-height proof |
| 08 — integrated slice | Street → F01 → F02/2A → F04/4B plus essential service continuity | Ordered ten-stage gate, performance, human route review |
| 09 — cutover proposal | Evidence-backed default switch and v1 retirement schedule | Owner approval, tagged fallback, no lost save fact |

No detailed furniture, decoration, resident dressing, detritus or final materials
enter checkpoints 03–08.

## Decision register

| ID | Decision | Owner | Recommendation/status | Consequence if deferred |
|---|---|---|---|---|
| AR-01 | Overall footprint/massing | User | **ACCEPTED 2026-08-28 — Option A compact H-plan** | Clears authoritative v2 geometry |
| AR-02 | Vertical-core arrangement | User | **ACCEPTED 2026-08-28 — public central core plus north-east service stair/lift** | Clears stair/service gray-box |
| AR-03 | Four lettered unit stacks and six floors | User | **Preserve** | Changing it remaps residents, signs and save-visible identity |
| AR-04 | Service lift scope | User | **Continuous light-service dumbwaiter, not player lift** | Shaft may be reserved but apparatus route stays provisional |
| AR-05 | Fire-egress fiction | User with later specialist review | **Two protected stairs; service stair also secondary egress** | Blockout can reserve it; compliance claim remains withheld |
| AR-06 | F01 common room retained | User | **Retain as resident amenity** | F01 west wing can become offices/storage if rejected |
| AR-07 | 2A and 4B relative stack positions | User | **2A west-south, 4B west-north** | Required routes remain possible, but exact dimensioned plan changes |
| TD-01 | Metric schema, semantic anchors and generated swing proofs | Technical | Decided, reversible and contract-preserving | None |
| TD-02 | 3.20 m floor-to-floor, 3.00 m clear height | Technical | Retain existing content allowance pending blockout | Revisit only if stair/window proportions fail |
| TD-03 | Production v1 remains default through integrated proof | Technical/safety | Decided | None |

AR-01 and AR-02 were accepted by the owner on 2026-08-28. Parallel gray-box
implementation may proceed under TD-01 through TD-03. AR-03 through AR-07 remain
explicit decisions; the current recommendations govern reversible blockout work and
none may silently change save-visible identity or established fiction.

## Validation performed and unproved items

Performed: repository/branch/history/dirty-tree/worktree inspection; current layout
metadata and F01/F02/F04 room/door/core extraction; bounded checkpoint review;
identifier consumer census; maintenance-job and wake-anchor source inspection;
historical-source review; internal dimensional, adjacency and route consistency
review of the proposal.

Still unproved: owner acceptance; site fit against the existing street/arcade;
complete east-wing apartment polygons; structural bay sizing; legal/code compliance;
full stair headroom; exact window-to-room light ratios; Blender/Godot generation;
collision/navigation; door swing simulation; anchor import; playability; acoustic
behavior; saves under a v2 root; performance and human route comprehension.

## Checkpoint receipt

- Exact changed files: the three dated documents listed in this checkpoint.
- Unrelated dirty/untracked files: preserved and unstaged.
- Rollback: delete/revert only these three documents; production behavior is
  unchanged.
- Commit SHA: filled by the publishing commit; see repository history.
