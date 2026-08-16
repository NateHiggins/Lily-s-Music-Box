# Prop and Set Interaction Matrix

**Ruled production inventory — 2026-08-15.** This is the I1 census for the
owner amendment “THE SERVICE WIRE ANSWERS BACK” in `PROP_ACTIVITIES.md`. It
records what is actually in the production scene at `b318d84`, then rules what
each foreground family is allowed to become. It is not a claim that the later
I4/I5/I6 implementation passes are already complete. I2's researched copy book
landed on 2026-08-15 in `game/data/prop_service_wire.json`, with its source
ledger in `PROP_TRIVIA_RESEARCH.md`.

The machine-readable evidence is
`art/renders/prop_interaction_i1/live_inventory.json`. Re-run instructions and
the interpretation boundary are beside it in `README.md`.

## 1. Classification law

Every matrix row has exactly one disposition:

- **OPERATE** — E works a plausible reversible mechanism or enters an authored
  activity. The mechanism remains the sole state owner.
- **INSPECT** — E gives a restrained material/audio acknowledgement and a
  service-wire card; no false moving part is invented.
- **RESIST-REFUSE** — E makes a physically honest attempt that cannot complete
  and says why. Silent failure is a defect.
- **AMBIENT ARCHITECTURE** — repeated, inaccessible or compositional material
  stays out of the interaction registry.

“Current owner” below means the node that receives the production interaction
ray. `—` means I4/I5 must add or map an owner before the row can satisfy the
ruling. Runtime-only state is not a persistence promise. A gameplay authority
named in Dependencies must never be copied into the service-wire presenter.

## 2. Reconciliation at the census boundary

| Population | Instantiated nodes | Logical player targets | Card-capable now | Interpretation |
|---|---:|---:|---:|---|
| `FunctionalProp` interaction owners | 203 | 203 | 203 | 21 live families; two contextual owners currently suppress their prompt. |
| Other prop/set interaction owners | 367 | 366 | 6 | The mail bank has one mechanism plus one forwarding child area; count it once. |
| Resident conversation owners | 18 | 18 | 0 | Reconciled, but people are outside the prop/set matrix and keep dialogue ownership. |
| `LightDebugHandle` owners | 260 | 0 | 0 | Internal lighting diagnostic, no public prompt; never service-wire content. |
| **Total scene interaction nodes** | **848** | — | **209** | `203 + 645`; the 645 non-Functional nodes split exactly as above. |
| **Logical prop/set E targets** | — | **569** | **209** | The implementation denominator before new I4/I5 targets are added. |

The scene also contains 22 scripted visual families with no E owner, 44 layout
marker kinds, 50 furniture assembly kinds and 15 named merged render batches.
Those source populations are reconciled below. Merged buffers are only used for
counts; generator records supply provenance.

## 3. Live `FunctionalProp` families — 203/203 reconciled

| Foreground family | Live / location | Current owner and reaction | Sound | Save / dependencies | Ruling | I4/I5 consequence |
|---|---|---|---|---|---|---|
| Signal-parlour cabinets | 12 / B1, F01 | `ArcadeCabinetProp`; boots receiver and opens programme panel | Programme audio owns response | Runtime / arcade machine | **OPERATE** | Keep machine ownership; card names cabinet and current programme. |
| Boiler | 1 / B1 plant | `BoilerProp`; separate fire, ash, draft and gauge areas operate | Hum, metal tick, building thud | RealityState-backed / plant systems | **OPERATE** | Preserve area-specific verbs and state lines. |
| Resident bookshelves | 8 / F02–F06 | `BookshelfProp`; opens sorting panel; sectional door opens while used | Metal tap | Runtime / resident book data | **OPERATE** | Card may name order/condition, never infer resident facts. |
| Box fans | 4 / F02, F04–F06 | `BoxFanProp`; cycles 0–3 unless possession owns it | Electrical hum | Runtime / possession state | **OPERATE** | Card reports selector position and whether the control is refusing. |
| F03 utility case door | 1 / F03 | `CaseDoorProp`; **current E is a silent no-op** | None | Runtime / later case | **RESIST-REFUSE** | Required fix: latch/leaf attempt plus a specific locked or held reason. |
| 4B windable clock | 1 / F04 | `ClockProp`; hold E winds spring and can close its work order | Metal tick | WorkOrders / Conductor | **OPERATE** | Keep hold interaction; card reports reserve and movement condition. |
| Vantry reference clock | 1 / F01 | `ClockProp`; sealed setting cover rattles but cannot adjust house time | Metal tick | Runtime / Conductor | **RESIST-REFUSE** | Landed I4: the real cover supplies the refusal response and identifies line synchronisation and the visible four-minute error. |
| Darts board | 1 / B1 bar | `DartsProp`; opens Rainbow Round activity | Metal clink | Runtime / activity | **OPERATE** | Card identifies board material/rules without delaying activity. |
| Dead-letter table | 1 / F01 | `DeadLettersProp`; opens sorting activity | Paper rustle | Runtime / mail activity | **OPERATE** | State line reports unsorted/handled condition. |
| Room 0 anomaly door | 1 / F04 | `DoorAnomalyProp`; enters only while manifested | Visual pulse | Conductor / Room0 | **OPERATE** | Contextual prompt/card only while manifest; never reveal the dream. |
| Iceboxes and monitor-tops | 18 / F01–F06 | `FridgeProp`; opens/closes main leaf; ice-door API also exists | Latch, timber creak, hum, droplets | Runtime / possession may co-own motion | **OPERATE** | Already physical; card must read actual main/ice leaf state. |
| Kettles | 6 / F01, F03, F04, F06 | `KettleProp`; starts/stops heat cycle | Switch tick, hum, whistle | Runtime / Conductor | **OPERATE** | Card reports cold/heating/boiling state. |
| Mirror medicine cabinets | 23 / F01–F06 | `MedicineCabinetProp`; swings cabinet leaf | Door squeak | Runtime | **OPERATE** | Card reports open/shut and construction, not contents invented ad hoc. |
| Otis indicator/control | 1 / F01 lobby | `OtisProp`; opens lift activity panel | Selector clack | Runtime / lift activity | **OPERATE** | Card reports car/indicator condition. |
| Point Ball table | 1 / B1 bar | `PointBallProp`; opens game activity | Ball/tap tick | Runtime / activity | **OPERATE** | Preserve missing-eight fiction in state line. |
| Radiators | 23 / F01–F06 | `RadiatorProp`; valve and vent areas operate separately | Whistle, tick, pipe knock | Runtime / maintenance jobs may bind one | **OPERATE** | Card must distinguish supply wheel from air vent and current job target. |
| Songbook phonograph terminal | 1 / B1 bar | `SongbookTerminalProp`; opens songbook and turns cylinder/crank while used | Clunk, mechanical hum | Runtime / songbook | **OPERATE** | No screen language; card describes cylinder/take condition. |
| Gas ranges | 18 / F01–F06 | `StoveProp`; E opens oven; burner service APIs remain separate | Latch clunk, gas/mechanical bed | Runtime / possession may co-own motion | **OPERATE** | Card reads oven/burner condition; do not imply electric hotplates. |
| Shower curtains | 23 / F01–F06 | `TapProp(shower)`; curtain area opens/closes | Tick, shower water | Runtime | **OPERATE** | Keep curtain and water controls distinct in copy and reach. |
| Basin and kitchen taps | 43 / B1, F01–F06 | `TapProp(sink)`; cycles hot, mixed, off; stopper API exists | Tick, running water | Runtime | **OPERATE** | Card reports valve/water/stopper state. |
| Toasters | 14 / F01–F06 | `ToasterProp`; latches, heats and releases timed carriage | Lever click, pop, hum | Runtime / Conductor | **OPERATE** | Busy E must answer rather than silently restart. |
| Mina 2A Vantry point | 1 / F02 | `VantryPointProp`; opens grille and emits inspection; repair uses same mechanism | Carbon-point chirp | WorkOrders + inventory through coordinator | **OPERATE** | Preserve K2–K4 lifecycle and repaired quiet state. |

## 4. Other live interaction owners — every node reconciled

| Foreground family | Live / location | Current owner and reaction | Sound | Save / dependencies | Ruling | I4/I5 consequence |
|---|---|---|---|---|---|---|
| Maintenance headquarters wall | 1 / F01 office | `MaintenanceHeadquarters`; status lettering brightens | None | RealityState / RealityCases | **INSPECT** | Add material acknowledgement and case-safe card. |
| Room 0 interior seam | 1 / hidden root | `Room0`; E returns its occupant | Hum, collapse flash | Runtime / Conductor | **OPERATE** | Remains contextual and outside ordinary exploration copy. |
| Room light switches | 215 / all floors | `SwitchPlate`; toggle click then room-light request | Metal toggle click | Runtime / lighting system | **OPERATE** | Card reads circuit/fixture result; dead circuits still click honestly. |
| Lobby directory buzzer | 1 / F01 | `WayfindingSignagePass`; one call button travels and rings the bell on every press | Elevator bell | Runtime / RealityCases | **OPERATE** | Landed I4: one assembly owner reports button return and sounded/still-ringing state; it selects no resident and adds no call state. |
| 4B support desk chair | 1 / F04 | `DeskZone`; sit/stand and open/leave call interface | None | Runtime / call system | **OPERATE** | Add chair/receiver sound; second E must continue to release. |
| Case-specific object zones | 6 / F01, F02, F04 | `CaseInteractable`; kind-specific card/book/pencil/control/clock/letter touch, then forwards the case callback result | Metal/paper handling tick | RealityCases | **OPERATE** | Landed I4: Mina alone returns each outcome dictionary; wrapper owns no flags. Disabled letter has no prompt or collision until the case enables it. |
| HARDWARE PAINT counter | 1 / Passage | `MaintenanceShopCounter`; contextual part acquisition | None | Inventory + WorkOrders through shop service | **OPERATE** | Add counter acknowledgement/card only when job service is valid. |
| Harukiya bar stools | 3 / B1 | `BarSeatZone`; first E seats, second stands | None | Runtime | **OPERATE** | Add seat scrape; preserve occupied refusal and release. |
| Lobby bench seat | 1 / F01 | `LobbyBenchZone`; first E seats, second stands | None | Runtime | **OPERATE** | Add upholstery/wood response; preserve release. |
| Ordinary operable doors | 112 / all floors | `DoorProp`; 102 initially closed and 10 initially open generic leaves | Squeak, latch click | Runtime | **OPERATE** | Exact 120-source split is 103 closed/10 open/7 locked; the separate landmark consumes one closed source. |
| Locked doors | 7 / all-floor door set | `DoorProp`; rattles without opening | Three latch clicks | Runtime | **RESIST-REFUSE** | Card must say why this leaf is unavailable without inventing a master-key quest. |
| Landmark Orison entrance leaf | 1 / F01 | `LandmarkEntryDoor`, inherited door interaction; opens/closes hero leaf | Squeak, latch, building thud | Runtime | **OPERATE** | Hero material/fittings deserve their own copy, not generic door text. |
| Harukiya look-points | 6 / F01 and B1 | `InspectableZone`; cycles authored observations and returns card dictionary | None | Runtime cursor | **INSPECT** | Already uses interaction-result card seam; add restrained touch/room sound if appropriate. |
| Box 4B mail bank | 1 logical / F01 | `MailBankProp` plus one forwarding `MailBoxZone`; opens leaf and offers/takes mail | None | RealityState | **OPERATE** | One target, not two; card cannot replace mail-choice panel. Add leaf/latch sound. |
| Passage handcarts | 3 / Passage | `PassagePushcart`; shoves by day, silently rejects while chained after hours | Physics response | Runtime / passage hours | **OPERATE** | Day remains OPERATE; night must visibly/audibly chain-rattle and explain refusal as its state branch. |
| Apartment projectors | 5 / F02–F06 | `ProjectorProp`; toggles inherited TV state and throws reel on found wall | Reel/video bed | Runtime / broadcast system | **OPERATE** | Card reports reel threaded/running/aimed condition. |
| Harukiya television | 1 / F01 | `TVProp`; toggles player power unless possession dominates | Programme/possession audio | Runtime / broadcast + possession | **OPERATE** | Card reads actual powered/player/possessed state. |
| Resident conversations (outside scope) | 18 / F01–F06 | `AnimatedResident`; dialogue/case interaction | Dialogue-owned | RealityState + RealityCases | **AMBIENT ARCHITECTURE** | Accounting sentinel only: people are not props and receive no service-wire card. |
| Lighting debug handles (outside scope) | 260 / all zones | `LightDebugHandle`; public prompt is empty | None | Diagnostic only | **AMBIENT ARCHITECTURE** | Must remain unreachable/undiscoverable in shipped play and outside coverage denominator. |

The last two rows use the ambient label only to keep the four-value schema
closed. They are exclusions, not a statement that residents are architecture.

## 5. Scripted visual families with no independent E owner

These are live, individually scripted meshes that the old `FunctionalProp`
count could not see. “Mapped owner” means I4/I5 should reuse an existing nearby
owner instead of placing two ray targets on one physical object.

| Visual family | Live / location | Current reaction / audio / persistence | Current or mapped owner | Ruling | Required disposition |
|---|---|---|---|---|---|
| Bodega fascia/signage | 1 / F02 runtime ownership | `BodegaSignageProp`; lit sign geometry, no E | — | **INSPECT** | One reachable shopfront look-point, not 11 child collisions. |
| Orison building-entry sign | 1 / F01 | `BuildingEntrySign`; hero enamel/brass sign, no E | Landmark entrance area may map it | **INSPECT** | Use one entrance-sign target distinct from opening the door only if ray legibility proves it. |
| 4B ceiling-light hero | 1 / F05 census band | `CeilingLightProp`; visual fixture only | Its room switch | **AMBIENT ARCHITECTURE** | Switch card names the circuit; no ceiling collider. |
| Character/case/found wall art | 73 / all floors | `CharacterMemoryArt`; 367 geometry draws, no direct E | Six Harukiya zones and case zones cover only named subsets | **INSPECT** | Tag named foreground pieces; repeated hall/found-art fillers stay ambient and must be counted separately in I5. |
| Domestic witness clocks | 18 / apartments | `DomesticWitnessClock`; tick and case-driven distortion, persistent case state | Case zones where authored | **INSPECT** | Each foreground witness needs a case-owner mapping or a neutral inspect owner; no second truth store. |
| Entrance marquee dress | 1 / F01 | `EntranceMarqueeDress`; 35-piece hero canopy, no E | Entry look-point to add | **INSPECT** | One material/history target for the assembly. |
| Roof exhaust fans | 4 / roof | `ExhaustFanProp`; autonomous hum and acoustic propagation | — | **RESIST-REFUSE** | Reachable motor housing gets guarded/service-isolated refusal; inaccessible blades remain ambient child geometry. |
| Flue breasts | 5 / F02–F06 | `FlueBreastProp`; hum/pipe-knock response, no E | — | **INSPECT** | One frontage target each; never pretend masonry opens. |
| Harukiya signage assembly | 1 / F02 census band | `HarukiyaSignageProp`; 47-piece lit hero, no E | Existing six bar look-points cover adjacent heritage objects, not this sign | **INSPECT** | Add one sign look-point. |
| Table/floor lamps | 5 / B1, F02–F05 | `LampProp`; lit visual, no direct E | — | **OPERATE** | Add a local key/pull/rotary switch only where hand-reachable. |
| Laundry ceiling airer | 1 / B1 | `LaundryAirerProp`; has lower/raise API and tick, no E | — | **OPERATE** | Add rope/cleat owner and preserve obstruction truth. |
| Repeated light fixtures | 254 / all zones | `LightFixtureProp`; 1,925 geometry draws, some buzz; room lighting owns state | 215 wall switches | **AMBIENT ARCHITECTURE** | No per-fixture E. I5 records the 260 light sources behind 215 plate owners; no one-to-one contract exists. |
| Lobby bulletin board | 1 / F01 | `LobbyBulletinBoard`; 23-piece authored board, no E | — | **INSPECT** | One readable board target and current-notice condition. |
| Lobby Orison advertisement | 1 / F01 | `LobbyOrisonAdBoard`; 31-piece authored board, no E | — | **INSPECT** | One look-point; service wire must not repeat all ad copy. |
| CRT monitor props | 5 / F02, F06 | `MonitorProp`; case/conductor-driven display, no E | Case owner where authored | **OPERATE** | Add physical power/tuning control or specific protected refusal by source; preserve case control. |
| Neon signs | 3 / F01 street and Harukiya | `NeonSignProp`; conductor/business-hours light, one low transformer or frontage target | Same `NeonSignProp`; observational only | **INSPECT** | Landed I4: the complete ORISON blade, DRUGS wall cabinet and HARUKIYA stage sign each own one reachable service point and sourced tube/transformer condition. Inspection cannot switch, surge or repair the circuit; glyphs never become targets. |
| Possessed domestic mechanisms | 19 / apartments | `PossessedDomesticProp`; case-driven movement/tick, persistent case state | Same `PossessedDomesticProp`; one neutral inspection target per mechanism | **INSPECT** | Landed I4: all 16 kinds answer with a local material sound and complete owner-result copy; visible movement is restrained and case authority pre-empts it. No card names a case, resident, tell or cause. |
| Eleven shop signs | 11 / Passage | `ShopSignProp`; one fascia-sized inspection owner, live lettering glint and hours-owner binding | Same `ShopSignProp`; never a glyph target | **INSPECT** | Landed I4: one target per complete shopfront sign. Authored name/trade stay in the generator marker; live OPEN/CLOSED/NIGHT SERVICE and LIT/DARK copy comes only from `PassageHoursDirector`. No stock, economy or shop contents are inferred. |
| 4B signal terminal visual | 1 / F04 | `SignalTerminalProp`; Conductor-driven visual, no direct E | `DeskZone` | **AMBIENT ARCHITECTURE** | Supporting geometry of the desk interaction, not a second target. |
| Speakers | 7 / F01–F03 | `SpeakerProp`; pipe knock, buzz or line murmur, no E | — | **INSPECT** | Reachable cabinet/grille gets inspect; elevated PA child meshes stay ambient. |
| Entry vault-light glow | 2 / F01 | `VaultLightGlow`; pure glow dressing, 40 geometry draws | Entry lighting/architecture | **AMBIENT ARCHITECTURE** | No E target. |
| Laundry washers | 2 / B1 | `WasherProp`; lid, wringer, gap, agitate and drain APIs; full mechanical audio, no E | — | **OPERATE** | Highest-priority missing mechanism owner: expose area-specific controls without a fake omnibus toggle. |
| Carried Vantry service set | 1 / player camera | `ServiceSetProp`; R toggles radio, L toggles lamp, job light and paper printer answer state | Physical levers, printer tick/feed | WorkOrders read-only / PlayerController owns input | **OPERATE** | Not an E-ray target; keep its dedicated physical controls and include it in I5 usability proof. |
| Street traffic, including piano-repair truck | 1 batched system / STREET | `StreetTraffic`; moving vehicle stream, horn/shove contact, tram dwell | Five pooled vehicle voices | Runtime / arrival and crossing directors | **AMBIENT ARCHITECTURE** | Inaccessible moving traffic is environmental behavior, not an E target. The truck sign remains readable dressing. |
| Weather field | 1 system / STREET and exterior | `WeatherFX`; rain, cloud and fog layers respond to time/weather authority | Weather bed | Runtime / weather and day-night system | **AMBIENT ARCHITECTURE** | Never attach E to rain, cloud, puddle repeats or fog planes. |

## 6. Generator furniture assemblies — all 50 source kinds

The layout contains 6,082 furniture records. The table groups records by the
generator's `asm` provenance, not by merged runtime AABB. A row can be ambient
while a separately spawned mechanism on top of it is interactive; that mapping
is stated explicitly.

| Assembly source | Count / floors | Existing or intended foreground owner | Ruling | Note for I4/I5 |
|---|---|---|---|---|
| `amp` | 2 / F02 | — | **RESIST-REFUSE** | Resident-owned powered equipment; switch/knob attempt should explain private/live setup. |
| `arcade_cab` | 12 / B1, F01 | 12 `ArcadeCabinetProp` overlays | **OPERATE** | Fully mapped. |
| `bed` | 21 / F01–F06 | 4B dream/bed owner only | **INSPECT** | Ordinary beds acknowledge ownership/condition; only authored sleep bed operates. |
| `bench` | 5 / B1, F01, roof | Lobby + three bar seat zones cover four seats | **OPERATE** | Prove which fifth bench is safely sittable or classify its source explicitly as blocked. |
| `bookpile` | 10 / B1, F01, F03–F06 | — | **INSPECT** | Named piles are foreground; no book-by-book collisions. |
| `bottles` | 13 / F01–F06 | — | **INSPECT** | One cluster target per named story/bar grouping; bulk shop stock stays ambient child geometry. |
| `cablecoil` | 6 / F02, F03, F05, F06 | — | **RESIST-REFUSE** | Lift/tug attempt; connected, heavy or privately rigged reason comes from source owner. |
| `chair` | 60 / F01–F06, roof | Four authored seat zones cover only designated seats | **AMBIENT ARCHITECTURE** | Do not make every dining chair a teleport; explicitly tag any additional sit hero. |
| `coal_chute` | 1 / F01 | — | **RESIST-REFUSE** | Locked/service-danger response. |
| `coal_heap` | 1 / B1 | — | **INSPECT** | Material acknowledgement; no pickup economy. |
| `coffee` | 7 / B1, F01, F02, F04, F06, roof | — | **INSPECT** | Table-setting cluster, condition only. |
| `couch` | 3 / F01 bar | — | **AMBIENT ARCHITECTURE** | Banquettes frame occupied social space; no generic sit snap. |
| `crate` | 60 / F01–roof | — | **INSPECT** | Named foreground crates get one target per stack; bulk storeroom/shop repeats remain ambient. |
| `desk` | 5 / F01–F04 | 4B desk has `DeskZone` | **INSPECT** | Other desks are resident/private surfaces; inspect without opening invented drawers. |
| `dishrack` | 19 / F01–F06 | — | **INSPECT** | One kitchen cluster target, no plate collisions. |
| `entrance_marquee` | 1 / F01 | `EntranceMarqueeDress` visual | **INSPECT** | Hero assembly mapped to §5. |
| `fire_escape` | 3 / F01 | — | **AMBIENT ARCHITECTURE** | Exterior architecture; no E unless later traversal makes it reachable. |
| `guitar` | 2 / F02 | — | **RESIST-REFUSE** | Private tuned instrument; touch/owner refusal, no generic performance minigame. |
| `headphones` | 4 / F02, F03, F05, F06 | — | **RESIST-REFUSE** | Connected/private equipment. |
| `jarrow` | 4 / F02, F03, F06 | — | **INSPECT** | Inspect row/contents label; do not individualize jars. |
| `jukebox` | 1 / F01 bar | `FurnitureInteractionPass`; distinct selection bank and coin return, moving caps, live sign and cabinet-local three-record pickup | **OPERATE** | Landed I4; cycles shipped bar records without routing through or stopping the unlocatable WORS emitter. |
| `kitchen` | 18 / F01–F06 | Appliances/taps own mechanisms | **AMBIENT ARCHITECTURE** | Cabinet run is structural support; do not duplicate appliance rays. |
| `micstand` | 3 / F01–F03 | Songbook activity owns bar mic only | **RESIST-REFUSE** | Bar mic can be busy/not recording; resident mics are private/connected. Source-aware refusal required. |
| `mug` | 28 / B1, F01–F06 | — | **INSPECT** | One table-setting cluster; no pickup system. |
| `nightstand` | 21 / F01–F06 | — | **INSPECT** | Surface condition only; no invented drawer interior. |
| `papers` | 14 / F01–F06 | `FurnitureInteractionPass`; one record-aligned stack owner and lifted corner | **INSPECT** | Landed I4; closed source-id table names only visible working category/authority. No paper text or case answer enters the neutral card. |
| `partstray` | 2 / F03 | — | **INSPECT** | Named parts tray as one cluster. |
| `pedalboard` | 1 / F02 | — | **RESIST-REFUSE** | Connected resident rig; footswitch click may answer but does not alter routing. |
| `pinboard` | 8 / F01, F02, F04, F05 | `FurnitureInteractionPass`; one board-sized owner and one pressed tack | **INSPECT** | Landed I4; exactly one target per board, including the empty pattern board. Case transitions remain with their existing owners. |
| `pipe` | 781 / all floors | Radiator/boiler/service endpoints own action | **AMBIENT ARCHITECTURE** | Explicit bulk exclusion; no pipe-by-pipe collision. |
| `plant` | 28 / B1, F01, F03, roof | — | **INSPECT** | One pot/bed cluster per foreground grouping. |
| `plantable` | 1 / F05 | — | **OPERATE** | Add soil/planting state only if the existing gardening activity owns it; otherwise an honest refusal. |
| `radio` | 5 / F03, F05, F06 | `FurnitureInteractionPass`; record-aligned local knob, switch click and valve-programme bed | **OPERATE** | Landed I4; reversible power stays separate from both the carried service set and case-anomaly props. |
| `reeldeck` | 2 / F02, F03 | — | **RESIST-REFUSE** | Private threaded media; controls answer but playback remains owner/case gated. |
| `shelf` | 25 / B1, F01–F06 | Bookshelf overlays only cover eight authored shelves | **INSPECT** | One target per foreground shelf run; bulk shop stock ambient. |
| `sitemodel` | 1 / F05 | — | **INSPECT** | Named model is a hero object, not traffic architecture. |
| `sofa` | 5 / F01, F02, F04, F06 | — | **AMBIENT ARCHITECTURE** | No generic sit snap; promote only explicitly cleared seat anchors. |
| `softbox` | 2 / F06 | — | **RESIST-REFUSE** | Hot/private studio equipment; hardware acknowledgement. |
| `switch` | 215 / all floors | 215 `SwitchPlate` owners | **OPERATE** | Fully mapped. |
| `table_rect` | 10 / F01–F06 | Activity owners only where authored | **AMBIENT ARCHITECTURE** | Supporting surface; foreground contents own inspection. |
| `table_round` | 13 / F01–F06 | Activity owners only where authored | **AMBIENT ARCHITECTURE** | Supporting surface. |
| `toilet` | 24 / F01–F06 | `FurnitureInteractionPass`; record-aligned cistern handle, finite refill and impatient-handle response | **OPERATE** | Landed I4; close-coupled porcelain remains baked, no bodily-needs system implied. |
| `toolboard` | 1 / F03 | — | **INSPECT** | Named tool arrangement; inventory does not transfer. |
| `tripod` | 1 / F06 | — | **RESIST-REFUSE** | Set/locked/private rig. |
| `tv` | 6 / F01–F06 | One `TVProp` + five `ProjectorProp` owners | **OPERATE** | Fully mapped despite mixed physical presentation. |
| `utility_cover` | 2 / F01 | — | **RESIST-REFUSE** | Gas/water covers are bolted service access. |
| `vault_lights` | 2 / F01 | `VaultLightGlow` visual | **AMBIENT ARCHITECTURE** | Fully mapped as entry lighting. |
| `wardrobe` | 21 / F01–F06 | `FurnitureInteractionPass`; two record-aligned textured leaves open/close over a generator-authored hollow carcass, rail and owned garment silhouettes | **OPERATE** | Landed I4 and rendered closed/open. Leaves exist only at runtime; resident contents remain scenery, never generic loot. |
| `watering_can` | 2 / roof | — | **INSPECT** | Current fill/condition; operate only after a gardening owner exists. |
| `workbench` | 1 / F03 | — | **INSPECT** | One bench target; tools remain arranged, not collectible. |

## 7. Layout marker reconciliation — all 44 kinds

| Provenance class | Marker kinds | Count reconciliation | Matrix destination |
|---|---|---:|---|
| Live `FunctionalProp` | `boiler`, `bookshelf`, `boxfan`, `case_door`, `darts`, `door_anomaly`, `fridge`, `kettle`, `mirror`, `point_ball`, `radiator`, `shower`, `sink`, `songbook_terminal`, `stove`, `toaster`, `wall_clock` | 188 | §3; the remaining 15 functional instances are 12 arcade cabinets, Otis, the dead-letter table and Mina's Vantry point. |
| Live non-Functional owner | `desk_zone`, `door`, `room0_threshold` | 122 | §4; 120 doors split into 119 generic + one landmark. |
| Scripted visual awaiting/mapped review | `bodega_signage`, `ceiling_light`, `exhaust_fan`, `flue_breast`, `lamp`, `laundry_airer`, `monitor`, `neon_sign`, `shop_sign`, `signal_terminal`, `speaker`, `washer` | 46 | §5. |
| Light-system source, no per-fixture E | `cage_bulb`, `chandelier`, `electrical_junction`, `eye_pendant`, `flush_dome`, `kitchen_linear`, `pendant_shade`, `sconce_globe`, `street_lamp` | 264 | §4 switch owners or §5 ambient fixture family. |
| Authored shell/hero source | `bar_signage`, `passage_shop_hours`, `porch_deck` | 17 | Bar/shop signage is INSPECT; five porch decks remain **AMBIENT ARCHITECTURE** until traversable foreground use exists. |

The marker total is 637 source records across 44 kinds. Counts intentionally do
not equal live owner counts one-for-one: an assembly can spawn an owner, several
markers can feed one lighting system, and root-built content has no marker.

## 8. Passage and merged render provenance — all 15 batches

| Generated batch | Source records | Ruling | Foreground extraction rule |
|---|---:|---|---|
| `shop_model_laundry` | 130 | **AMBIENT ARCHITECTURE** | Extract counter ledger, washer/service plate or named machine as a separate INSPECT/OPERATE target; stock repeats stay merged. |
| `shop_shoe_rebuilding` | 74 | **AMBIENT ARCHITECTURE** | Extract repair bench, ticket rack and hero machine only. |
| `shop_keys_cut` | 155 | **AMBIENT ARCHITECTURE** | Extract key machine, order ledger and counter object only. |
| `shop_hardware_paint` | 195 | **AMBIENT ARCHITECTURE** | Existing maintenance counter is OPERATE; extract paint-chip/ledger/hero stock clusters only. |
| `shop_funeral_parlour` | 88 | **AMBIENT ARCHITECTURE** | Extract consultation ledger/nameplate; no comic corpse/container operation. |
| `shop_photo_supplies` | 89 | **AMBIENT ARCHITECTURE** | Extract camera/chemical/ledger hero clusters with safety-aware refusal. |
| `shop_radio_service` | 74 | **AMBIENT ARCHITECTURE** | Extract service receiver, valve/tool cluster and ledger. |
| `shop_pawnbroker` | 87 | **AMBIENT ARCHITECTURE** | Extract pledge ledger and named window hero; locked stock refuses. |
| `shop_luncheonette` | 80 | **AMBIENT ARCHITECTURE** | Extract counter service objects and named machine; bulk crockery stays merged. |
| `shop_news_cigars` | 60 | **AMBIENT ARCHITECTURE** | Extract headline board/ledger; tobacco stock remains non-operable display. |
| `shop_otis___son` | 153 | **AMBIENT ARCHITECTURE** | Extract lift-service plate, dispatch ledger and hero mechanism. |
| `passage_shell` | 130 | **AMBIENT ARCHITECTURE** | Hall architecture only. |
| `passage_proxy` | 9 | **AMBIENT ARCHITECTURE** | Portal proxy only; never an E owner. |
| `passage_proxy_gateway` | 249 | **AMBIENT ARCHITECTURE** | Gateway occlusion/transition architecture; no false doors. |
| `transit_shelter` | 8 | **AMBIENT ARCHITECTURE** | Current street shelter shell; period plaque/bench may be separately promoted after reach audit. |

### Street loose-record heroes

The unmerged generator records also contain one hydrant (two parts), one postal
box, three news boxes, one three-part street bench, one two-part call booth, two
bins, one dumpster, one three-part traffic signal, streetlamp poles/heads and
eight Passage bollards. These are not lost inside the batch table.

| Street family | Current owner | Ruling | I5 treatment |
|---|---|---|---|
| Hydrant | — | **RESIST-REFUSE** | Cap/wrench attempt answers as municipal live-water equipment. |
| Postal box | — | **INSPECT** | Slot/body acknowledgement; no false mail-deposit economy. |
| Three news boxes | — | **RESIST-REFUSE** | Coin/door attempt answers as locked paid dispensers. |
| Street bench | — | **OPERATE** | Add a physically cleared sit/stand zone if route audit proves the seat reachable. |
| Call booth | — | **OPERATE** | Door and receiver become one authored booth interaction with line-state response. |
| Bins and dumpster | — | **INSPECT** | One target per foreground container, no opening or loot fiction. |
| Traffic signal and streetlamps | lighting/traffic authority | **AMBIENT ARCHITECTURE** | Elevated civic equipment; no E target. |
| Eight Passage bollards | — | **AMBIENT ARCHITECTURE** | Repeated boundary architecture. |

This is the binding answer to “all eleven shops”: their merged shells and bulk
stock remain ambient, but each shop must receive a small, separately proven set
of foreground hero targets. I5 must name those generator record IDs; it may not
attach one collider to the merged batch and call hundreds of objects covered.

## 9. Priority order handed to I2/I4/I5

1. Fix existing dishonest silence: the F03 case door, after-hours handcarts,
   busy toaster branches, disabled case zone and any contextual counter prompt
   that can receive E without an answer.
2. Add owners to mechanisms already modeled with state APIs: two washers, the
   laundry airer, five lamps, five CRT monitors, one jukebox, five radios,
   twenty-four cisterns and twenty-one wardrobes.
3. Map gameplay-bearing visuals to their authoritative case/activity owners:
   domestic witnesses, possessed props, papers, boards and signal equipment.
   The 18 witness clocks and both lobby board assemblies landed 2026-08-15:
   their existing visual owners now supply the only ray target and condition,
   with case identifiers and resident facts excluded from the returned card.
   The headquarters case wall uses the same law: one assembly target reads the
   RealityCases-derived count and identifies itself as review-only.
   All 19 possessed domestic mechanisms now reuse their existing
   `PossessedDomesticProp` owner. The 16 physical kinds receive one neutral ray
   target, a local material response and a provenance-backed field slip; the
   card reports only AT REST or VISIBLY ALTERED. A case intrusion cancels the
   restrained handling motion before applying its authoritative tell.
   The lobby's two remaining signal mechanisms also answer physically: its
   directory owner depresses a real call button and reports the bell's current
   response, while the Vantry reference clock rattles its sealed setting cover
   and refuses adjustment without interrupting house time.
   All 14 loose-paper assemblies and eight pinboards now regain one
   record-aligned `FurnitureInteractionPass` owner. A single top corner lifts
   or a single tack depresses; there are no per-sheet/card child targets. The
   closed 22-id attribution table includes the bodega and Harukiya working
   sheets, reports only visible count/category and public authority, and never
   reads case state or paper contents. The generator record set must equal that
   table exactly or the focused proof fails.
   Mina's six case-object zones now obey the same owner-result law. The wrapper
   supplies only a kind-specific material touch, invokes the existing callable
   once, and forwards its dictionary; Mina's owner determines caption,
   calibration, visit and letter outcomes. The unavailable letter remains
   invisible with collision disabled. Five direct period patent sources ground
   the six object facts without moving any flag into the presenter.
4. Add sparse inspection/refusal zones to the named set heroes in §5–§8.
5. Leave bulk pipework, fixture meshes, tables, chairs, shell geometry, weather,
   trim, shelf repeats and portal proxies ambient. Count them in the proof; do
   not manufacture interactions to improve a percentage.

I2 supplies researched copy. Its machine-readable registry names all 105
non-ambient rows with stable ids: 50 OPERATE, 38 INSPECT and 17 RESIST-REFUSE.
Those ids are the coverage keys for I4–I6; table labels above remain the human
review surface. I4 supplies physical answers. I5 proves the foreground
selection in situ. I6 turns this document's rulings into executable coverage,
reach, state-change and non-silent-refusal gates.
