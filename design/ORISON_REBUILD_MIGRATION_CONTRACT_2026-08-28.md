# Orison rebuild migration contract — 2026-08-28

Status: **BINDING FOR THE PROPOSED PARALLEL BLOCKOUT; geometry remains
unapproved.** This separates durable identity and behavior from replaceable
coordinates. It does not change saves, production launch or the current building.

## Authority boundary

The replacement may change footprint, room shapes, walls, openings, vertical-core
positions, furniture positions and generator implementation. It must not become a
new owner of jobs, cases, saves, evidence, semantic audio or interaction behavior.
The old building remains selectable and production-default until cutover gates pass.

The migration rule is: **semantic record → named anchor → derived transform**.
No new gameplay code may look up a raw coordinate, anonymous furniture record or
scene-tree accident when a stable identity is required. Compatibility aliases are
temporary and documented; they are removed only after save/runtime/test consumers
have migrated.

## Preserved identifier inventory

| Preserved identity | Current source | Known consumers | Contract class | Migration method | Compatibility proof |
|---|---|---|---|---|---|
| `vantry_chirp_2a` | `game/data/maintenance_jobs.json`; `ChirpHunt.JOB_ID` | `WorkOrders`, `ChirpHunt`, `MinaCaseGameplay`, `CoreLoopDirector`, service-round sequencing and tests | Durable job identity/save fact | Keep byte-identical; replacement anchor map resolves its target | Maintenance-job, chirp-reachable, first-shift custody and save/reload tests |
| legacy `WO-VANTRY-001` | `game/scripts/game/chirp_hunt.gd` | Legacy-order adoption/retirement | Save compatibility alias | Keep translator; never reissue in new layout | Legacy save fixture advances to `vantry_chirp_2a` without duplicate order |
| `mina_caption_crisis` | `game/data/reality_cases.json`; `MinaCaseGameplay.CASE_ID` | case tracker, dialogue, Dream profile selection, evidence and tests | Durable case identity | Keep byte-identical and geometry-agnostic | Case-one focused tests and save round trip |
| `mina_vale` / `Mina Vale` / unit `2A` | Bible, job/case/resident data, layout resident map | resident spawning, schedules, dialogue, mail, radios, signs, evidence | Fiction/runtime/data contract | Preserve canonical resident id, display name and unit; map 2A to new apartment record | Resident census, signage/mail checks, case route test |
| `F02_A_MAIN_VANTRY_POINT` | layout `vantry_points`; maintenance job `inspect_anchor_id`, `repair_target_id`, `anchor_ids` | `VantryPointNetwork`, `ChirpHunt`, acoustic graph, tests | Runtime lookup and job anchor | Generate named anchor inside new 2A work zone; retain id exactly | Anchor census, chirp-reachable live test, repair approach and acoustic-node checks |
| `F02_A_MAIN` | layout room id and Mina checkpoints | room systems, lighting/switch inference, runtime placement, evidence conventions | Runtime/test room identity | Preserve as semantic room record even if polygon changes; add aliases only for subdivided support zones | Layout schema, room census, light/switch and 2A route tests |
| `F02_DOOR_02` | current layout marker | `OrisonDetailPass` documentation/placement assumptions, route captures/tests | Runtime/test convention with active code coupling | Preserve as 2A public threshold anchor/door id; replace coordinate assumptions with anchor transform | Door census, open/swing/reach test from F02 landing |
| `F04_B_MONITOR_01` | layout furniture marker | `CallInterface`, `VirusSoundDirector`, case library, acoustic graph and tests | Runtime lookup and semantic-audio contract | Generate terminal anchor and prop with same id in 4B work zone | Call interface resolves; acoustic origin/high node and controller interaction tests |
| `F04_B_BED` | `CoreLoopDirector.RETURN_ANCHOR_ID`; conceptual safe return | wake signal/save state and tests | Durable orchestration anchor | Author explicit anchor record; stop resolving anonymous `id == "bed"` furniture as final implementation | Wake returns to explicit bedside stance; old saves reconstruct same boundary |
| legacy furniture id `bed` on F04 | current furniture record; `CoreLoopDirector.resolve_return_anchor()` | wake fallback | Temporary runtime convention | Retain only as compatibility fallback during parallel phase; log use in v2 blockout | Test both explicit anchor and fallback; remove fallback only at cutover |
| `F04_B_MAIN`, `F04_B_KITCHEN`, `F04_B_ALCOVE`, `F04_B_BATH`, `F04_B_VESTIBULE`, `F04_B_CLOSET` | layout room ids and F04 checkpoint | room systems, tests/evidence, runtime passes | Runtime/test identity | Preserve semantic records and unit ownership; polygon geometry may change | Room/anchor census and 4B player-route shot/live tests |
| `F04_DOOR_03` | layout marker | route convention and threshold evidence | Runtime/test convention | Preserve as 4B public threshold id | Door/swing test and F04 route proof |
| `F01_DOOR_06` | layout marker | `BuildingRoot` special exterior door, boundary ownership, commensal director and tests | Runtime lookup | Preserve as street threshold id; remove raw authored-position comments/logic in the v2 path | Exterior-door class, boundary, moth/commensal and first-minute tests |
| `F01_LOBBY` | layout room id | lighting, streaming, room/evidence tools and arrival tests | Runtime/test room identity | Preserve semantic public-room id with new polygon | Arrival route, lighting and room census |
| `LobbyMailBank`, `LobbyPorterBoard`, `F01_HOUSE_TELEPHONE_BOARD` | runtime/detail-pass names | mail/chute, maintenance, telephone networks and live tests | Runtime lookup/interaction identities | Emit anchors from F01 service-station records; instantiate existing props unchanged | Existing focused live tests plus approach/sightline proof |
| `LobbyServiceDumbwaiter` | runtime detail pass | dumbwaiter apparatus tests and maintenance interactions | Runtime interaction identity | Preserve landing identity and map to continuous v2 service shaft | Brake/interlock test and vertical anchor census |
| `B1_BOILER_01`, `F02_B_RADIATOR_01` | maintenance jobs/layout | service round, organism answer and apparatus tests | Durable job anchors/runtime lookup | Preserve identities and attach to new continuous plant/wet-stack records | Service-round route and apparatus tests |
| floors `B1`, `F01`…`F06`, `ROOF` and unit labels `1A`, `1D`, `2A`…`6D` | layout meta/resident map/signage | loaders, residents, signs, tests, saves and evidence paths | Broad runtime/test/fiction contract | Preserve canonical external ids; internal v2 record ids may be namespaced | Floor loader/census, resident/signage checks, save round trip |
| golden-shift boundaries `idle`, `job_open`, `conversation_pending`, `conversation_complete`, `dream_pending`, `wake_complete` | `CoreLoopDirector.BOUNDARIES` | orchestration serialization and tests | Durable save facts | Keep byte-identical; layout only supplies anchors | Golden-shift and save/reload transaction tests |
| work-order stages and evidence flags in `maintenance_jobs.json` | job library / `WorkOrders` | gameplay, UI, save serialization and tests | Durable save facts | Keep byte-identical; no v2 layout state owns progress | Work-order tests and old/new-layout parity run |
| interaction methods `get_interaction_text`, `interact`, `get_interaction_position` and existing target selection | `design/INTERACTION_CONTRACT_2026-08-27.md` and implementors | player controller, prompts, functional props and tests | Interaction semantic contract | Instantiate existing prop classes at named anchors; do not introduce a v2 protocol | Interaction conformance, prompt-carrier and controller tests |
| semantic acoustic node ids | acoustic graph data and marker ids | audio propagation, cases, `VirusSoundDirector` | Semantic-audio contract | Rebuild node positions/edges from v2 topology while retaining externally consumed ids | Acoustic graph integrity and case sound-origin tests |
| evidence/test entrypoints for F01 arrival, F02 case one, F04 player route, WalkTest, LightingAudit | `game/tests`, checkpoint docs and tools | release evidence and reconstruction gate | Test convention | Add v2-selectable fixtures or root injection; do not rewrite old evidence | Old root remains green; same entrypoints can target v2 explicitly |

This inventory is exhaustive for the first slice's known externally consumed
identities. Before each later floor migrates, the same `rg`-based consumer census
must extend the table; unlisted coordinates and decorative ids are not presumed
contracts.

## Facts that survive unchanged

- Established resident/unit ownership, the eleven golden-shift beats and Mina's
  complete case-one route.
- Work-order/case authorities, stages, evidence flags, inventory ownership and
  all saved boundary facts.
- The street → F01 → F02/2A → F04/4B traversal promise and waking in 4B.
- Existing interaction semantics, controller completeness, semantic audio owners,
  historical-period covenant and proportional performance gates.
- Current production scene, current layout JSON, current saves and historical
  evidence during the parallel phase.

## Things explicitly free to change

Footprint, courts, room dimensions and shapes, corridor route, apartment outline,
wall/opening coordinates, vertical-core placement, furniture coordinates,
decorative selection, generated mesh structure and internal v2-only identifiers.
No current coordinate is a contract merely because a comment repeats it.

## Compatibility architecture

1. A versioned v2 layout is selected only by an explicit development/test switch.
2. One v2 semantic schema owns boundaries, openings, stacks and named anchors.
   Geometry, navigation probes and evidence plans derive deterministically from it.
3. Existing gameplay systems receive an adapter exposing the current external ids;
   they do not read v2 coordinates directly.
4. The production v1 root remains default and immutable until integrated route,
   import, interaction, save and performance gates pass.
5. Cutover changes the default selector, not the gameplay/save authorities.
6. After a release checkpoint and rollback window, v1 generation becomes a frozen
   migration fixture. The adapter is retired id-by-id only after consumer census
   and compatibility proof; no second forever-generator remains.

## Migration risks and required tests

| Risk | Control | Blocking proof |
|---|---|---|
| Raw-coordinate coupling moves a prop or effect to empty space | Consumer census; named anchor adapter; warn on fallback | Zero unresolved required anchors; exact anchor census |
| Anonymous `bed` lookup wakes player at wrong bed | Explicit `F04_B_BED` stance plus temporary fallback | Save/reload and wake test under v1 and v2 |
| Changed room polygons alter light, switch, resident or acoustic inference | Explicit room/service metadata where inference is ambiguous | Room/light/switch/acoustic parity tests |
| Old and new generators both become permanent authorities | Cutover/retirement milestones and one authoritative v2 schema | Generated-output provenance check |
| New root mutates production evidence or layout outputs | Separate output tree and explicit selector | Clean production-output hash before/after v2 generation |
| Door id survives but approach/swing does not | Door record includes hinge, swing and both stance envelopes | Automated clearance plus player-height proof |
| Saves serialize scene position rather than semantic fact | Keep save owners unchanged; reconstruct transforms on load | Future/legacy save fixtures under both roots |
| Service continuity becomes decorative | Stack/riser records span B1–roof | Vertical matrix and named-endpoint census |
| Performance proof is hidden by primitive blockout | Measure CPU/GPU/import size at each integrated slice | Same route stations and documented budgets |

## Cutover and rollback

Rollback during development is the explicit v1 selector. No v2 generation may
write `art/data/building_layout.json`, `game/data/building_layout.json`, current
floor glTF/BIN files or current checkpoint evidence directories. Cutover requires:

1. deterministic schema/generation receipts;
2. all first-slice anchors resolved once and only once;
3. old/new parity for jobs, cases, saves, interaction and audio semantics;
4. human acceptance of street → 2A → 4B readability;
5. performance at or better than the agreed route budget; and
6. a tagged/committed v1 fallback and documented retirement issue.
