# Generator-to-runtime interface map

**Status:** K0-ENGINE dependency trace, 2026-08-27. This records the current
Orison production pipeline. It does not declare the pipeline portable, invent a
schema, regenerate geometry, or move code. Evidence level: **L2 local
invariant** under `ENGINE_EXTRACTION_BOUNDARY_2026-08-27.md` §G.

## 1. The production building chain

```text
art/data/gen_layout.py                         canonical authored program
  ├─ art/data/building_layout.json             semantic world + markers
  ├─ art/data/acoustic_graph.json              transmission topology
  ├─ art/data/prop_catalog.json                functional-prop profiles
  ├─ art/data/material_catalog.json            build-time material facts
  └─ art/data/fixture_light_map.json           fixture census
              │
              ├─ manual exact copy ──────────► game/data/<same five names>
              │                                  │
              │                                  ├─ BuildingRoot / tests
              │                                  ├─ AcousticGraphData
              │                                  ├─ FunctionalProp / Conductor
              │                                  └─ LightingAudit
              │
              └─ art/blender/scripts/build_orison.py
                   reads layout + material catalog
                   ├─ game/assets/building/{floor_b1,floor_01…floor_06,roof}.gltf
                   ├─ sibling .bin / exported textures
                   └─ art/blender/orison_master.blend
                                      │
                                      └─ BuildingRoot.FLOOR_SCENES
```

The chain has two independent production inputs at runtime: semantic JSON and
imported floor geometry. A valid new JSON beside stale glTF is a valid build of
two different revisions; Godot does not diagnose that split. The embedded
`orison_bin_sha256` in each glTF descriptor protects descriptor/buffer import
atomicity, not JSON/glTF revision agreement.

## 2. Authority and consumer table

| Artifact | Writer / authority | Mirror / build step | Production consumer | Failure behavior and gap |
| --- | --- | --- | --- | --- |
| `building_layout.json` | `art/data/gen_layout.py` | copied `art/data` → `game/data`; Blender reads authoring copy | `BuildingRoot` loads the game copy; many live/audit suites query it | No schema/version field or generated revision handshake with floor glTF. Missing file is not checked before `get_as_text()`. |
| `acoustic_graph.json` | `gen_layout.py` | copied to game | `AcousticGraphData` autoload | Missing file warns; schema is interpreted by Orison code. |
| `prop_catalog.json` | `gen_layout.py` | copied to game | `FunctionalProp`; `ConductorClock` depends on the profile vocabulary | Lazy static cache; no external schema or migration contract. |
| `material_catalog.json` | `gen_layout.py` | copied to game; read by `build_orison.py` and art tools | **No direct production GDScript consumer found** | The `game/data` mirror currently ships but is build-time/reference data. Copying it does not make it a runtime API. |
| `fixture_light_map.json` | `gen_layout.py` | copied to game | `LightingAudit`; `author_light_provenance.py` reads game copy | Audit substrate, not the runtime lighting owner. A stale copy can make fixture coverage look like a lighting defect. |
| floor `.gltf` + `.bin` | `build_orison.py` from authoring layout/material data | written directly under `game/assets/building` | `BuildingRoot.FLOOR_SCENES` loads eight fixed paths | Staleness against JSON is manual/history-based. Descriptor includes buffer SHA so Godot notices changed binary data. |
| `orison_master.blend` | `build_orison.py` | written to `art/blender` or explicit `ORISON_BLEND_OUT` | human inspection; not game runtime | Blender 4.5/bpy dependency; not part of exported game. |

The five primary JSON mirrors were hash-equal in Git at this checkpoint. Their
equality is a repository fact, not an enforced generator feature: `gen_layout`
writes only `art/data`, and the copy remains a documented manual command.

## 3. Runtime assembly boundary

`BuildingRoot._ready()` opens `res://data/building_layout.json`, builds the
environment, then loads the eight fixed floor scenes. The layout supplies room,
wall, opening, furniture and marker meaning; the glTF supplies baked visible and
collision geometry. Runtime passes then interpret markers and attach behavior.

This is not a clean compiler API:

- `building_root.gd` is 2,851 lines and imports Orison props, autoloads and
  fixed asset paths;
- marker `kind` strings select game classes through product-owned tables;
- floor ids and coordinate conversion are Orison facts;
- consumers read raw dictionaries with defaults rather than a versioned schema;
- generator validation proves authored geometry constraints, while Godot tests
  separately prove imported collision and behavior.

The durable lesson is the two-stage validation boundary: source invariants
before export, then imported/runtime invariants after assembly. The current
types and vocabulary remain game-only.

## 4. Derived light-provenance chain

```text
game/data/building_layout.json
game/data/fixture_light_map.json
        └─ tools/author_light_provenance.py
             ├─ game/data/light_provenance.json ─► LightRig
             └─ art/data/light_provenance.json  ─► authoring mirror
```

Dependency tracing found that `bf2e650` had added `field_semantics` only to the
game mirror. The authoring script would therefore erase the period-release
classification on its next run. Checkpoint `64dc248` moved that classification
into the generator payload, repaired the authoring mirror, and made
`audit_period_dates.py` fail when the two objects differ.

The trace also found a separate content drift that was **not adopted**: running
the current author against current inputs proposes 254 records rather than the
committed 191 (72 ids added, 9 removed). The committed 191-record objects remain
the production baseline. Reviewing that 63-net-fixture expansion requires a
lighting-owner/live audit and is not part of the authority repair.

## 5. Other generated seams in the repository

These are separate pipelines and must not be described as children of
`gen_layout.py` merely because their output lands in `game/`.

| Seam | Authority | Generated outputs | Runtime consumer / status |
| --- | --- | --- | --- |
| Arcade packages/catalog | external `C:\FPSengine01` world compiler; repository is not versioned here | `game/assets/arcade/arcade_cabinets.json`, `.swcpkg`, semantic scene | `ArcadeCatalog`, `SWCFormats`, `ArcadeRow`; build output must not be hand-edited. |
| Runtime material sets | `art/tools/generate_runtime_materials.py` plus material sources/catalog | two `runtime_material_sets.json` mirrors and `game/scripts/generated/material_sets.gd` | building surface/material code; generator has explicit stale-output checks. |
| Surface calibration | `art/tools/ship_surface_tables.py` | normalized height/mask textures and `scripts/generated/surface_calibration.gd` | `SurfacePass` preloads the generated table. |
| Light temporal classification | `author_light_provenance.py` | two provenance JSON mirrors | `LightRig` plus release-period audit. |
| Character assets | Blender/Python scripts per character pipeline | `.glb`, `.blend`, animations, previews | resident/character loaders; asset-specific, not one shared compiler contract. |
| Media/texture builders | many `art/tools/build_*` and ingest scripts | game textures, video, audio and proof artifacts | consumers vary; outputs often carry their own `SOURCE.md`/manifest rather than a central registry. |

## 6. Current enforcement and missing enforcement

Enforced now:

- `gen_layout.py` validates its semantic construction before writing;
- Blender fails the build if a floor export fails;
- glTF descriptors fingerprint their sibling binary buffers;
- production/live tests validate important imported geometry, routes, markers,
  light coverage and behavior;
- period audit now enforces equal light-provenance objects and classification.

Not enforced now:

- automatic copying or hash comparison for the five primary JSON mirrors;
- a shared schema version for generator outputs;
- JSON-to-glTF source revision identity;
- a complete registry of generators, inputs, outputs and runtime consumers;
- stale-output checking across the many satellite media pipelines;
- reproducibility of the external arcade compiler from this repository.

## 7. Safe next steps

Before the friends build, use the current commands and audits; do not refactor
the chain. A future integrity improvement may add a read-only manifest/audit
that compares declared mirrors and records source hashes, but it must be driven
by an observed release failure and must not rebuild assets automatically.

After a second consumer exists, a real compiler contract would need versioned
schemas, declared coordinate space, deterministic inputs/outputs, structured
validation failures, explicit runtime adapters and a source-revision handshake
for semantic data plus geometry. None exists today.
