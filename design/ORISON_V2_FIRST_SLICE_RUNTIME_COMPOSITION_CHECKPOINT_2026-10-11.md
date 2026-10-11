# V2 first-slice runtime composition checkpoint

Evidence class: **CHECKPOINT**. Executed runtime authority proof.
Status: **TECHNICAL PASS**, scoped to the seven authorities below.

The self-contained production test is
**game/tests/orison_v2_first_slice_contract_test.gd**. Its test-written schema-2
receipt is **art/renders/orison_v2/first_slice_contract_20261011/runtime_authority_receipt.json**.
The receipt binds the root test source and current production runtime inputs.
The wrapper **runtime3.log.receipt.json** confirms completed execution without
timeout. Final run: 113 checks, zero failures. An earlier parse-failed run is
diagnostic only; it grants no proof.

| Function | Composition | Authority | Durable/save owner | Teardown owner |
|---|---|---|---|---|
| Opening clock | v2 at `F01_WATCHMAN_DETECTOR` | `WatchmanClockProp` | RealityState first_shift; FirstShiftDirector | Mounted prop and runtime root |
| Opening report | v2 at `F01_NIGHT_REGISTER` | `NightRegisterProp` | WorkOrders; RealityState first_shift | Mounted prop and runtime root |
| Central drops | v2 at `F01_SIGNAL_REGISTER` | `WatchRegisterProp` | Session-only network facts | Mounted prop and runtime root |
| Tour-key hook | v2 at `F01_TOUR_KEY_GUARD` | `TourKeyGuardProp` | Session custody, observed by FirstShiftDirector | Mounted prop and runtime root |
| Lena's radiator | v2 at `F02_B_RADIATOR_01` | `RadiatorProp` | WorkOrders repair evidence | Mounted prop and runtime root |
| Basement comparison | v2 at `B1_BOILER_01` | `BoilerProp` | WorkOrders ordered comparison evidence | Mounted prop and runtime root |
| Lobby comparison | v2 at `LobbyPorterBoard` | `OtisProp` | WorkOrders ordered comparison evidence | Mounted prop and runtime root |

One production gameplay authority and one semantic owner resolve for each of
the original six M08F anchors. FirstShiftDirector, ServiceRoundDirector and
WorkOrders each retain one lifecycle authority. Opening clock-in uses the real
detector control; taking the spindle slip acknowledges one authored job.
Arrival rejects premature clock-out, premature report acceptance and an empty
spindle. Duplicate report-taking is refused.

The real PlayerController interaction ray takes the tour key and operates all
seven stations, delivering numbered drops 1 through 7 in order. Wall bearings,
clear approaches, station legends, reset and returned key custody are checked.
Player positions are placed at the established test stances: this proves
interaction access, not continuous walking between those stances.

The inherited M08F service sequence is now included directly in the bound test
source. Production owner signals execute Lena's call, threshold conversation,
radiator inspection, lobby comparison, basement comparison, repair and resident
return. Premature and duplicate completions cannot counterfeit progress. The
opening repair is explicitly completed as a prerequisite fixture on WorkOrders;
this checkpoint does not claim the complete Mina repair/dream journey.

Actual disk save, destruction, load and CampaignShell reconstruction preserve
the closed round and durable ritual state. Transient guard custody and central
marks reconstruct with their existing semantics; no session marks are invented.
The test uses a unique isolated save, never the player's save. Nodes in both
worlds, unpathed collision shapes below the seven authorities, and active audio
playbacks are tracked by WeakRef. All measured retained counts are zero.
Imported/shared caches are outside that resource measurement scope.

No geometry, texture, production authority or protected selector logic changes.
Existing Blender and composed surface reviews remain valid. This checkpoint
does not grant human acceptance, movement-route proof, whole-building service
continuity, acoustics acceptance, performance acceptance or V1 retirement.
