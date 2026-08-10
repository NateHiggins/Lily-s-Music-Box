# AUDIT 2 — WHAT IS BUILT AND NEVER USED

*Run 2026-08-10 after the ceiling, prop-family and H18 terminal passes. This is
an audit only. No candidate below was removed or repaired.*

## Method

The sweep covered all 182 scripts under `game/scripts`, every shipped JSON in
`game/data`, all 617 built layout markers, all 545 built acoustic nodes, the
runtime prop registry, scene/script references and the export-facing asset
tree. Class-name references and resource-path references were checked
separately so a script loaded by `preload()` was not mistaken for a dead class.
Generated output was treated as truth. The one visual finding was rendered with
`SCREENSHOT_STREAMING=1` under authored lighting.

## Findings

```text
P0 | game/scripts/building/building_root.gd:36; game/scripts/props/monitor_prop.gd:2; art/data/gen_layout.py:1475,1525,1674,1856; game/tests/walk_test.gd:2564 | `monitor` is six objects in four homes, but H18 rebuilt the shared class as the unique 4B Vantry desk and tests only F04_B_MONITOR_01. Mina's one display, Juno's one display and Sacha's three-screen editing wall now instantiate the same metre-wide brass receiver. The streaming render shows three complete 4B consoles tiled across 6A. | This is visible shipped regression and character erasure, not dead data: five live markers resolve to the wrong class of object while every test passes. | Split the semantic kind. Preserve marker id F04_B_MONITOR_01 but change only its kind to `signal_terminal`; move the current H18 implementation to `signal_terminal_prop.gd`; restore `monitor_prop.gd` as the ordinary Vantry display family; register both; give the acoustic graph both electrical kinds; assert one signal terminal and five displays, including 6A's three distinct screen owners. | confidence: certain; built count plus streaming render.

P0 | art/data/gen_layout.py:7752-7761,7807-7813; game/data/acoustic_graph.json nodes ROOF_LT_DECK, ROOF_LT_GARDEN, ROOF_ATRIUM_FRUIT_1, ROOF_ATRIUM_FRUIT_2 | Four live roof light props bind to acoustic nodes with zero connections. The generic electrical branch tries `%s_CORRLIGHT_S` for every floor, but the electrical spine authors corridor junctions only for F02-F06. Invalid ROOF_CORRLIGHT_S edges are discarded, leaving all four nodes isolated. | A roof light can react to the global motif but cannot receive, relay or transmit network propagation; possession appears to stop at the roof line with no warning. | Give the roof a real electrical junction/hub and connect the four fixtures to it, or explicitly edge them to F06_CORRLIGHT_S through a roof riser node. Add a graph audit requiring degree > 0 for every marker-bound acoustic node; permit isolated nodes only through a named allow-list, currently empty. | confidence: certain; all 545 built nodes measured, exactly four isolated.

P1 | art/data/gen_layout.py:2513; game/data/building_layout.json marker B1_ROOM0_DOOR; game/scripts/building/building_root.gd:394-398 | The `room0_threshold` marker is built data that no runtime path reads. It is unregistered, absent from the graph and absent from every script lookup; `BuildingRoot` constructs `Room0` directly and binds it only to the F04 anomaly. | Moving or deleting the authored basement threshold changes nothing, while a reviewer can reasonably believe it governs access to Room 0. This is the dangerous half of dead data: a control that silently controls nothing. | Either make `Room0.setup()` consume B1_ROOM0_DOOR as its threshold/return anchor and assert the id, or remove the marker at the generator and state that Room 0 has no basement entrance. This is a fiction choice, so do not silently choose deletion. | confidence: certain about non-consumption; owner decision required on intended fiction.

P1 | game/data/creature_index.json; game/assets/creatures/harpy/*; game/assets/creatures/oni/* | The creature index has no repository consumer, and neither indexed model or move library is loaded by any scene, script, generator or test. The directory is 6.2 MB in the repository. The owner has separately ruled that the moth harpy and oni are not among the game's current seventeen-character cast. | These assets increase repository/import/export surface while describing characters explicitly outside current canon. Their presence also invites a future agent to treat them as approved cast because the JSON calls itself the creature roster. | Remove `game/data/creature_index.json` and both creature directories after confirming no planned dream-case decision reintroduces them. If they are retained as source experiments, move them outside `game/` so `all_resources` cannot package them. | confidence: high; zero references and explicit owner ruling, tempered only by unresolved dream work.

P2 | game/scripts/props/corridor_light_prop.gd:1-61; game/scripts/building/building_root.gd:31; art/data/gen_layout.py:2797-2804; game/data/prop_catalog.json key `corridor_light` | The fluorescent `CorridorLightProp` has no marker and cannot spawn in the shipped building. The generator comment says its old markers were deliberately removed because they duplicated fixtures. It survives only because the warehouse registry instantiates every registered kind; its catalog profile and switch/audit branches remain too. | This is release-dead code and an anachronistic non-signal fluorescent fixture which can mislead prop review by appearing as a supported family. | Remove the script, registry entry, prop-catalog row and now-unreachable `corridor_light` branches in generator/switch audits together; retain no warehouse variant. Add a registry audit distinguishing marker-spawned kinds from explicitly documented warehouse-only kinds. | confidence: certain.

P2 | game/data/clock_dials.json; game/scripts/props/domestic_witness_clock.gd:28-39 | `clock_dials.json` has no consumer. The live clock duplicates its 4x3 atlas map in `DIAL_INDEX`, and the JSON is already stale: it names `memphis`/`sunburst` while runtime uses `vantry_modular`/`sunray_1920`; it omits several non-atlas digital forms by design. | Editing the JSON cannot change a clock, so it is a false authority beside the actual hard-coded map. | Delete both art/game copies, or preferably make the runtime load one generated atlas manifest and remove DIAL_INDEX. Do not keep two editable maps. | confidence: certain.

P2 | game/data/resident_decor_profiles.json | This complete seventeen-household decorating brief has no code, generator, Blender or test consumer. Similar resident-specific placement is now authored through WallArtLaw, character-memory catalogs and procedural passes. | The file is valuable design prose but inert game data: changing an `avoid` rule cannot prevent a placement, and shipping it under `game/data` implies otherwise. | Move it to `design/` as a human brief, or make one placement audit consume its rules. Do not leave it in the runtime data directory unconsumed. | confidence: certain about non-consumption; medium on deletion because the prose remains useful.

P3 | game/scripts/props/smoke_detector_prop.gd:1-4; art/data/gen_layout.py:6871,7633,8011; game/data/prop_catalog.json key `smoke_detector`; game/scripts/props/possessed_domestic_prop.gd:47,74 | The alias class has no scene, script or serialized-resource reference. There are no smoke-detector markers, no domestic anomaly spec of that kind and no runtime registry entry. A dead build-validation branch, catalog profile and a dead visual branch survive beside it. | Today it costs little, but the compatibility comment claims an old serialized save path that cannot be demonstrated anywhere in the repository. It makes the pre-covenant object look supported after the Vantry-point ruling replaced it. | First define save compatibility: if old external saves can serialize script classes, add a migration test and retain the alias only there. Otherwise remove the alias, dead branch, catalog row and generator references as one change. | confidence: high on repository unreachability; external-save policy unknown.

P3 | art/data/gen_layout.py:2349 and 2372; game/data/building_layout.json marker ROOF_TANK | `ROOF_TANK` is an unregistered marker with no graph node or runtime lookup. The visible water tank is separately baked as `watertank` furniture, so the marker neither owns the object nor carries its network. | This duplicates the apparent authority for one roof object. Moving the marker leaves the visible tank behind and changes no system. | If the tank is meant to join the water network, author a real node/owner from this marker and make the furniture follow it. Otherwise remove only the marker and keep the baked tank. | confidence: certain about current non-consumption.
```

## Negative controls and repaired precedents

- No other script was unreachable after checking both class references and
  resource-path loads. `OrisonDetailPass.START_LOCKED` remains a deliberate
  scenario switch and was not filed.
- `electrical_junction` is intentionally unregistered as a prop: all ten built
  markers become connected acoustic-graph nodes. It is data-only by design.
- The five flue-breast markers no longer carry hybrid units such as `F02C`.
  Built data now has real units `2C`-`6C`, explicit bedroom ids and unchanged
  binding ids. The precedent in the original brief has been repaired.
- Registered kinds with no markers are not automatically dead. `mail_bank`,
  `landmark_entry` and `arcade_cabinet` document separate runtime ownership;
  `vantry_point` is built from the top-level `vantry_points` table. Only
  `corridor_light` lacked a non-warehouse owner or a continuing fiction.

## Render evidence

- 6A with streaming active, showing three 4B receiver desks replacing Sacha's
  display wall:
  `C:/PleaseRemainOnTheLine/art/renders/audit_unused_systems/b_15_6a_sacha.png`

## Recommended repair order

1. Split `monitor` / `signal_terminal`; it is the only immediately visible
   shipped regression.
2. Connect the four isolated roof nodes and add the graph-degree assertion.
3. Rule whether B1_ROOM0_DOOR is an entrance or false data.
4. Remove the corridor-light family and the three demonstrably inert JSON
   authorities in separate commits; creature removal waits on the dream ruling.
5. Decide external-save compatibility before touching the smoke-detector alias.
