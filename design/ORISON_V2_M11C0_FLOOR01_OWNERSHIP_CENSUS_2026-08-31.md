# ORISON-V2-M11C0 floor_01 ownership census — 2026-08-31

## Disposition

This is a read-only census of the protected **floor_01.gltf/.bin**, its
source layout, and every identified production consumer. It derives a
source-owned partition but does not mutate, regenerate, replace, or authorize a
cut of either protected asset.

The important distinction is:

- the target production partition has **17 source-owned cells**; and
- the current export permits only a **17-cell whole-primitive rehearsal** in
  which **CELL_LEGACY_MIXED** still contains all **134** primitives whose
  durable source-to-export lineage is unresolved. This set includes specific
  demonstrated cross-owner batches; the census does not claim every member is
  independently proved cross-owner.

The latter is useful for exact recomposition and loader rehearsal, but it does
not prove independent Orison/site residency.

## Protected export topology

| Property | Measured value |
| --- | ---: |
| GLTF bytes | 682,906 |
| BIN bytes | 12,020,428 |
| Nodes / meshes / primitives | 531 / 531 / 531 |
| Accessors / buffer views | 1,740 / 1,740 |
| Materials / textures / images | 104 / 304 / 304 |
| Referenced vertices | 345,536 |
| Referenced triangles | 183,726 |
| Render plus collision nodes | 371 |
| Collision-only nodes | 9 |
| Render-only nodes | 151 |
| World bounds | [-112, -2.87, -66] to [108, 53.585, 102.2] |

All **531** nodes are scene roots. Each has one unique, equally named mesh and
one primitive; all transforms are omitted identity transforms because world
coordinates are baked into the vertex buffers. There are no child nodes,
animations, skins, cameras, or semantic extras.

The **1,740** buffer views are four-byte aligned, non-overlapping, gapless, and
cover the complete BIN. Blender deduplicated index topology: **531** primitives
share **147** unsigned-16-bit index accessors. **35** of those accessors cross
logical target-cell boundaries, representing **36,396 unique bytes**. An
independent export must therefore emit/remap cell-local index views or a
deliberately owned shared buffer; it cannot leave global accessor references.

## Why a post-export spatial cut is refused

The source layout contains **4,415 furniture records**. Material batching
collapses **1,757** currently unbatched records into the broad
**F01_furnish_*** and **F01_furniture_*** primitive families:

- **625** assembly records from five owners: Orison interior **106**, facade
  shell **4**, street/site **379**, bar **133**, and bodega **3**; and
- **1,132** simple boxes: Orison interior **191**, facade shell **22**, and
  street/site **919**.

Four simple-box primitives are directly proven multi-owner:
**F01_furniture_brass-col**, **F01_furniture_limestone-col**,
**F01_furniture_linen-col**, and **F01_furniture_metal-col**. Assembly material
buffers add many more cross-owner primitives. **F01_wear_fx_scuff** merges wear
from all door-marker owners from the Orison core through Passage. Glazing,
sash, trim, stone, wainscot, and AO buffers also merge emissions from internal
and perimeter walls.

Of the **134** non-prefix-separable primitive bounds, **68** fit the nominal
Orison footprint, **16** lie outside it, and **50** straddle it. This is not
ownership evidence: street leaves and entry details legitimately overlap the
building footprint. A centroid, bounding-box, connected-component, or
triangle-position classifier would manufacture lineage and is prohibited.

## Source-owned target partition

The smallest defensible design is:

1. **CELL_ORISON_F01_INTERIOR**;
2. **CELL_ORISON_FACADE_SHELL**;
3. **CELL_SITE_STREET_COMMON**;
4. **CELL_PASSAGE**;
5. **CELL_SHOP_BAR**;
6. **CELL_SHOP_BODEGA**; and
7. eleven Passage shop cells: **MODEL_LAUNDRY**, **SHOE_REBUILDING**,
   **KEYS_CUT**, **HARDWARE_PAINT**, **FUNERAL_PARLOUR**,
   **PHOTO_SUPPLIES**, **RADIO_SERVICE**, **PAWNBROKER**,
   **NEWS_CIGARS**, **OTIS_SON**, and **LUNCHEONETTE**.

The facade shell must be separate. Orison residency is interior plus facade;
street residency is street plus facade. This lets the exterior retain the
shared entrance/facade boundary without loading the complete interior or
duplicating facade geometry. A persistent, geometry-free **F01 composition
host** retains service and gameplay ownership above those residency sets.

### Source record census

| Target cell | Furniture | Markers | Other source ownership |
| --- | ---: | ---: | --- |
| Orison interior | 297 | 61 | 32 internal walls; 16 rooms; 1 slab; 26 ceilings; 3 vents; 29 sockets; F01 stair parts |
| Facade shell | 26 | 5 | 10 perimeter walls and all emissions from those walls; rainwater/facade detail |
| Street common | 1,620 | 7 | 565 site lights pending explicit ownership resolution; includes 42 proxy and 280 proxy-gateway furniture records plus two STREET-zone portal lights |
| Passage | 486 | 8 | Passage shell, aisle and common party-wall work beyond the ruled portal plane |
| Bar | 345 | 29 | 1 socket |
| Bodega | 155 | 6 | shop threshold and fitted interior |
| Model Laundry | 159 | 7 | shop-owned threshold/interior |
| Shoe Rebuilding | 103 | 6 | shop-owned threshold/interior |
| Keys Cut | 182 | 6 | shop-owned threshold/interior |
| Hardware/Paint | 224 | 7 | shop-owned threshold/interior |
| Funeral Parlour | 115 | 7 | shop-owned threshold/interior |
| Photo Supplies | 120 | 7 | shop-owned threshold/interior |
| Radio Service | 95 | 6 | shop-owned threshold/interior |
| Pawnbroker | 117 | 6 | shop-owned threshold/interior |
| News/Cigars | 79 | 6 | shop-owned threshold/interior |
| Otis & Son | 183 | 7 | shop-owned threshold/interior |
| Luncheonette | 109 | 7 | shop-owned threshold/interior |
| **Total** | **4,415** | **188** | exact source collection totals |

All furniture, marker, room, ceiling, vent, and socket records have unique
identities. The **42 walls**, **565 site lights**, and **one slab** do not. A
rehearsal may name those anonymous records by canonical content hash for audit
comparison only. Before a production cut, they need durable source identities
and an explicit **owner_cell** (or a separately governed source-owned ownership
map). Three anonymous site lights overlap the Passage block; location alone may
not decide their owner.

Every emission from a source wall or marker must inherit that record's owner.
The real exporter must batch by **owner_cell before material**, while preserving
the current **-col** and **-colonly** importer suffix contracts.

## Current whole-primitive rehearsal partition

The protected export can be assigned exactly once without geometric inference
only as:

| Disposable cell | Nodes | Purpose |
| --- | ---: | --- |
| CELL_LEGACY_MIXED | 134 | lineage-unresolved remainder, including demonstrated cross-owner material/wall batches |
| CELL_SITE_STREET_DEDICATED | 8 | four retail-site and four transit-shelter primitives |
| CELL_PASSAGE_PORTAL_PROXY | 12 | current proxy/gateway primitives; street-resident dependency |
| CELL_PASSAGE_SHELL | 20 | current Passage shell primitives |
| CELL_SHOP_BAR | 31 | prefix-separable legacy bar |
| CELL_SHOP_BODEGA | 16 | prefix-separable legacy bodega |
| Eleven Passage shops | 310 | exact shop-prefix cells |
| **Total** | **531** | every original node/mesh/primitive once |

This exact cut may prove independent resource import, cell-local remapping,
recomposition, and teardown. It cannot claim that Orison or the exterior is
independently loadable because both still require parts of
**CELL_LEGACY_MIXED**.

## Dangerous seams and owners

| Seam | One owner | Measured condition |
| --- | --- | --- |
| Orison south shell / street | facade shell | perimeter wall ends at source y -10.00; pavement reaches -9.98, a deliberate 20 mm overlap |
| Street / Passage portal | street common; Passage depends on it | Passage floor begins at GLTF z 28.316 and overlaps street ground by 4 mm |
| Passage / shop aisles | Passage common work | shop floors meet Passage at source x 11 and 17; backs meet shell at x 4 and 24 |
| Bodega / street | street common plus bodega threshold | bodega floor begins at source y -12; vertical faces meet at elevation zero |
| Facade shell / interior | facade shell owns perimeter-wall emissions | current glazing/sash/trim/wainscot/AO buffers mix perimeter and internal wall emissions |

Passage owns its common aisle, openings, and party-wall structure after the
ruled portal plane. A shop owns its inward threshold and storefront volume.
The legacy Passage proxy and proxy gateway are owned by street common even
though their exported names begin **retail_passage_proxy**; production already
rules them STREET-owned and always eligible. Shared use is expressed through
dependencies, never duplicate geometry.

## Runtime consumer census

This table covers the production runtime surface found by the source searches
below. Rows that establish an absence name the exact bounded search rather than
treating silence as evidence.

| Consumer | Exact source or reproducible census | Current contract | Cut disposition |
| --- | --- | --- | --- |
| BuildingRoot load/host | **game/scripts/building/building_root.gd:304–324** | maps F01 to one GLTF/PackedScene and one persistent floor node | replace only the geometry load with a cell registry while retaining one non-geometric composition host |
| BuildingRoot indexing/visibility | **building_root.gd:1447–1742, 2563–2671** | indexes Passage, late-F01 and street-core content by subtree/spatial assumptions, then applies whole-F01 visibility | query the active residency/cell registry and preserve one facade owner |
| F01-host pass/director dependents | **building_root.gd:362–432, 498–522, 589, 2163–2475**; **heightmap_pass.gd:50–68**; **surface_pass.gd:259–289**; **atmospheric_decal_pass.gd:17–40**; **broadcast_director.gd:74–148**; **arcade_row.gd:30–77**; **furniture_interaction_pass.gd:19–44**; **found_art_pass.gd:10–79**; **game/scripts/reality/domestic_witness_system.gd:17–41, 182–200**; **apartment_encroachment.gd:163–182** | attach generated/runtime owners to, or scan, the monolithic floor host | retain one persistent geometry-free host; make spatial scanners residency-aware before selective unload |
| Dormant FloorCoverage reference | **building_root.gd:329–332**; **game/scripts/building/floor_coverage_pass.gd:46–67** | instantiates the reference implementation but deliberately does not call **apply(floor_nodes)** | reference-only today; do not count it as a runtime consumer unless a future change reactivates it |
| OrisonDetailPass | **game/scripts/building/orison_detail_pass.gd:200–224, 264–719, 861–951**; **game/scripts/building/domestic_radio_pass.gd:13–49** | mounts thirteen F01 lobby/service actors plus floor/resident detail and domestic radios beneath floor hosts | keep those authorities on persistent composition hosts or semantic owners, never unloadable geometry cells |
| VantryPointNetwork | **game/scripts/building/vantry_point_network.gd:156, 169–201** | parents F01 point batches and the Teresa shutter to the F01 node | parent to the persistent host or a semantic owner registry |
| ExteriorDetailPass | **building_root.gd:446; game/scripts/building/exterior_detail_pass.gd:34–258** | adds persistent site visuals/collision outside the imported cell graph | place output in governed cell/shared residency before claiming selective unload |
| ResidentNav | **game/scripts/characters/resident_routines.gd:292–353, 366–384**; **resident_nav.gd:478–575** | binds floor roots and validates collision against the complete loaded world | scope validation to active cell sets or a semantic navigation authority |
| M11A exterior cell | **game/scripts/building/orison_v2_exterior_cell.gd:82–341, 531–928; game/scenes/building/orison_v2_exterior_cell.tscn** | surface/semantic-data-driven; no **floor_01** or **floor_nodes** dependency | **independent/reference-only**; the real cut must not absorb or duplicate it |
| Save/reconstruction | **game/scripts/game/reality_game_state.gd:42–76, 116–173, 254–281**; **game/scripts/building/orison_v2_exterior_semantic_state.gd:16–117**; **game/scripts/building/orison_v2_exterior_spatial_resolver.gd:231–304**; **game/scripts/dream/campaign_shell.gd:8–71**; **game/scripts/campaign/core_loop_director.gd:26–56, 266–334**; bounded negative search below | uses the non-persisted session selector during reconstruction; persists semantic route, threshold and return-anchor facts through RealityState; no selector, GLTF node path or raw world coordinate is durable, and the v1 anonymous-bed branch derives a transient return position | preserve semantic IDs and aliases; retain the v1 fallback; keep selector state outside the save contract; no floor-cut save migration is indicated by this bounded census |
| Historical tests/tooling | exact **rg** command below plus the 3,684-row spatial audit | exact node names, F01 identities and whole-root assumptions occur in test/evidence code | preserve names where possible and provide explicit legacy-node aliases; update only fixtures justified by the real cut |

The bounded negative save search was:

```powershell
rg -n "floor_01\.gltf|floor_nodes|NodePath" game/scripts/game/reality_game_state.gd game/scripts/building/orison_v2_exterior_semantic_state.gd game/scripts/building/orison_v2_exterior_spatial_resolver.gd game/scripts/dream/campaign_shell.gd game/scripts/campaign/core_loop_director.gd
```

It returns no match. The positive sources named in the table show that the
session selector is consulted but not serialized, while semantic route,
threshold and return-anchor facts are persisted. The transient
**player.global_position** write in **core_loop_director.gd:286–316** is derived
from the semantic anchor resolver or the preserved v1 anonymous-bed layout
fallback; no raw world position is serialized.

The test/tooling enumeration command was:

```powershell
rg -l "floor_01\.gltf|floor_nodes|F01_[A-Z0-9_]+|SITE_SHOP_[A-Z0-9_]+|PASSAGE_[A-Z0-9_]+" game/tests tools
```

Its findings are test/evidence dependencies, not production owners. The
repository spatial audit provides the durable machine census and reports
**3,684** classified dependencies with no new unclassified, changed, vanished,
or unresolved-save record.

Production gameplay/save consumers use semantic identities rather than GLTF
node names or raw coordinates. In particular, **F01_DOOR_06**,
**F01_BODEGA_DOOR**, **F01_BAR_DOOR**, **PASSAGE_PORTAL_LT_W/E**, and the
**SITE_SHOP_*** identity families—including the sole non-prefix darkroom
marker **SITE_SHOP_DARKROOM_PHOTO_SUPPLIES**—must resolve uniquely after a cut. The v1
**F01_BODEGA_DOOR** and v2 **THRESHOLD_SHOP_BODEGA_FRONT** identities may not
be silently aliased across roots merely because they refer to similar places.

## Rehearsal decision boundary

A production authorization requires all of the following before protected
mutation:

1. durable identity and explicit owner for every source record;
2. a disposable provenance build that first matches the protected monolith by
   canonical material/attribute/triangle and collision identity;
3. owner-first rebatching that resolves all **134** legacy-mixed primitives;
4. exact-once source-range and triangle recomposition;
5. independently loaded target residency sets;
6. bidirectional collision and navigation proof at each named seam;
7. unique semantic owner resolution and tested compatibility aliases; and
8. deterministic unload with no retained rehearsal-owned resources.

The whole-node rehearsal is deliberately incapable of satisfying items 1, 3,
and 5. Its measurements and images can validate the rehearsal mechanism, not
authorize a production export cut.
