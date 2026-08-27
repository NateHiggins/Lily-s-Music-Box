# F01 exterior-threshold and lobby reconstruction checkpoint

## Room profile

The south lobby is the Orison's weather lock, address, waiting place and first
orientation room. Residents, visitors, post carriers and the night watchman
enter here; ordinary activities are entering out of the rain, checking post,
waiting briefly, reading building notices and turning north toward the lift,
stairs and service instruments. The street door and the view to the atrium are
the primary route; the mail bank and house switchboard are secondary stations.

The visual identity is worn but attended prewar dignity: limestone surround,
marble floor/dado, brass service hardware, a warm marquee and restrained
seating. It deliberately has no electronic amusement machine, obsolete sales
broadside, reception counter, decorative furniture island or duplicate mail
station. Its condition is maintained, busy and voltage-tired.

## Object and architecture verdicts

| Element | Verdict | Reason |
|---|---|---|
| Street façade, limestone pilasters/entablature, water table and door step | KEEP | Complete threshold surround; final exterior view shows no open joint or unsupported trim. |
| `F01_DOOR_06` street leaf and frame | KEEP | The opening route and FAST walk remain valid. Census sweep hits are the authored step/surround, runner and exterior site layers, not a lobby furnishing placed in its swing. |
| `entry_marquee`, two soffit domes and entry sign | KEEP | The marquee is the weather cover and arrival light; the former redundant door sconce remains absent. |
| Orison and tenant neon signs | KEEP | Street-scale address and tenant wayfinding; neither competes inside the room. |
| Lobby floor, ceiling, marble dado, plaster walls and north opening | KEEP | Final threshold view shows a continuous enclosure and a direct readable route to the atrium. |
| South windows | KEEP | Plausible public-room daylight and street surveillance; both remain clear. |
| `lobby_runner` | KEEP | Centers the wet arrival route and does not create a visible trip or closed-door obstruction. |
| `lobby_bench_w`, `lobby_bench_e` and west bench interaction zone | KEEP | Short waiting/rest function; benches remain against the wall and out of the central route. |
| `lobby_plant` | KEEP | Period-plausible aspidistra and the only non-service decorative object; it does not obstruct the threshold. |
| `F01_LOBBY_RADIATOR_01` | KEEP | Required public-room heating service, seated under the south-wall zone. |
| `F01_LOBBY_CLOCK_01` Vantry master | KEEP | Building-service time authority; its 179 mm clearance from the mail bank and sealed cover remain tested. |
| `LobbyMailBank` | KEEP | Primary resident/post station; labeled compartments face the lobby, the 4B leaf clears clock/tray and a full standing lane remains. Its correct assembly convention is local `-Z`, unlike neighboring apparatus. |
| `LobbyPostTray` | KEEP | Reachable sorting handle derived from the bank center. |
| `LobbyMailChute` | KEEP | Historically/functionally earned service hardware in a measured gap; working face and maintenance activity remain reachable. |
| `LobbyPorterBoard` | REPAIR | Rotated 180 degrees: its blank back faced the player while its call controls were buried in the east partition. Changed `+PI/2` to `-PI/2`; the labeled `TAP CALL` face now reads from the lobby. |
| `LobbyServiceDumbwaiter` | KEEP | Back-of-house delivery function; correctly faces the corridor and remains separate from the passenger lift. |
| Passenger lift, grille and `F01LandingInterlock` | KEEP | Required vertical route and period service hardware; the interlock remains reachable from the landing. |
| `LobbyBulletinBoard` | KEEP | Ordinary rent/heat/exterminator information on the route; current implementation has real notices and one foreground inspection target. |
| `F01_HOUSE_TELEPHONE_BOARD` | KEEP | Period house-line station on the clear west pier; reachable, nonblocking and proven to own no story/case progression. |
| `ServiceSpineDirection` | KEEP | First-minute contract proves it is visible from the threshold while the watch detector is not; it gives one necessary turn without duplicating the objective. |
| Work-order board | KEEP | Rebuilt oak/cork board with pinned slips and an integrated brass legend, not the obsolete overlapping teal slabs described by the old walkthrough. |
| Maintenance cart, clipboard and tape measure | KEEP | The cart is the shared work surface and the two tools sit on it. Generic floating nameplates were already retired; no new label fix was required. |
| Watch detector, night register, signal register and tour-key guard | KEEP | Distinct working instruments on the north service run; their optional opening-shift sequence remains coherent and reachable. |
| Retired `lobby_cab` and original-sales broadside | KEEP ABSENT | Both crowded the west wall, weakened 1928 period trust and duplicated stronger stations. Production/live tests prove they stay absent. |

## Candidate correction

The 2026-08-25 walkthrough grouped `LobbyMailBank` and `LobbyPorterBoard` as
the same facing defect. The new measured live test and player-height A/B
inspection show they do not share an authoring convention. `MailBankProp`
presents its labeled face on local `-Z` and was already correct at `+PI/2`;
`OtisProp` presents its controls on local `+Z` and required `-PI/2`. The final
change repairs only the porter board and adds regression checks for both
opposite conventions.

## Source, validation and evidence

- Runtime source: `game/scripts/building/orison_detail_pass.gd` changes only
  the porter-board yaw and documents the mail-bank exception.
- Focused regression: `maintenance_chute_live_test.gd` now proves the bank,
  chute and porter board each present the correct working face.
- No generator input changed, so no JSON, Blender or glTF regeneration was
  required for this runtime-only repair.
- `MaintenanceChuteLiveTest`: PASS, 27/27.
- `FirstMinuteLiveTest`: PASS, 43/43.
- `HouseTelephoneLiveTest`: PASS, 16/16.
- `WalkTest` FAST: PASS.
- `F01ArrivalRoomShot`: PASS, five 1280×720 player-height frames and receipt
  under `art/renders/orison_room_reconstruction/f01_arrival_checkpoint_02/`.

## Remaining ambiguities

- The static census treats the exterior site and lobby as one F01 owner, so
  the street-door sweep includes site slabs and weather geometry. Those are
  not automatic placement defects; a later exterior/site ownership pass should
  classify them separately.
- The service apparatus continues north beyond the declared `F01_LOBBY` rect.
  This checkpoint validates the first route read and the repaired wall-run
  face, but the full hall, lift/stair approaches and every north-corridor door
  remain their own F01 checkpoints.
