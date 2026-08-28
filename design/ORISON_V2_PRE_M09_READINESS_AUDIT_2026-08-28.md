# ORISON-V2 — Pre-M09 Readiness Audit

Date: 2026-08-28

Audited commit: `aa62f9e`

Mode: read-only architecture/runtime audit plus proportionate regression. No
selector, runtime authority, production layout, generated asset or evidence file
was changed.

## Executive finding

The M08 first slice is technically proven and its route readability now has a
durable owner PASS. The repository is **not yet ready for M09’s evidence-backed
default switch**: v2 still has only a development review root, while production
boot and campaign reconstruction directly name the v1 root. Scoped production
consumers were exercised through temporary adapter mounting, but a complete
production service graph has not been composed under a v2 runtime root.

Recommendation: **DO NOT AUTHORIZE M09** until the three BLOCKING items below are
closed in a separately authorized pre-cutover runtime-composition checkpoint.

## Prerequisite classification

| Prerequisite | Classification | Evidence and disposition |
|---|---|---|
| Deterministic v2 schema/generation receipts | PROVEN | Committed schema/generator checkpoint `af39b2b`; current `OrisonV2BlockoutTest` passes the stable layout id, census, geometry derivation and production-output stability assertions. |
| All first-slice anchors resolve exactly once | PROVEN | M08A integrated gate resolves all twelve required identities uniquely through `OrisonV2AnchorAdapter`. |
| Jobs/cases/interaction/audio parity | PROVEN | M08A mounts existing F01 props and exercises their public contracts; real WorkOrders/ChirpHunt/Vantry path advances Mina’s authored job; real SignalTerminalProp/CallInterface runs isolate → capture → route and retains `F04_B_MONITOR_01` as Conductor/acoustic origin. |
| Save/wake parity | PROVEN WITH TEMPORARY FALLBACK | Real v2 save → clear → load → reconstruct resolves explicit `F04_B_BED`. v1 is separately reconstructed through the legacy anonymous `bed` record. The latter is compatibility, not migration. |
| Human street → 2A → 4B readability | MANUAL PASS | Owner statement “I can understand the layout”; all seven questions answered without ambiguity; durable receipt references the ten-frame `_04` packet. |
| Route performance | PROVEN | Latest regression: startup 12.527 ms; 1,706 blockout nodes; 411 collision objects; warm station CPU ≤1.605 ms and physics ≤1.053 ms, below the established 16.67 ms budget. |
| Production v1 remains default | PROVEN | `GameBoot.BUILDING_SCENE` and `CampaignShell.waking_scene_path` both name `res://scenes/building/orison_root.tscn`; project main scene remains the title screen. |
| Production layout remains byte-stable during proof | PROVEN | Integrated and blockout suites hash `game/data/building_layout.json` before/after and pass. Current workspace SHA-256 is `9E6B4FA95A88E7EA23FE8BFAC188FD094FD1CACE628237010A683DB7C0C4356E`. A pre-existing user modification remains dirty and was not touched. |
| Committed reproducible v1 fallback | PROVEN | `orison_root.tscn`, production layout blob, v1 generator outputs and hardcoded v1 boot paths exist in `aa62f9e`; reverting any future selector commit restores them. |
| Selector-only rollback without authority changes | BLOCKING | No shared selector exists. `game/scripts/game_boot.gd` and `game/scripts/dream/campaign_shell.gd` independently hardcode v1, and the only integrated v2 scene is a review scene with a review controller rather than the production service graph. |
| Historical/future saves under both roots | PROVEN WITH TEMPORARY FALLBACK | The root-neutral future-save suite passes 14/14; v2 current-save reconstruction and v1 anonymous-bed reconstruction pass. A literal two-root matrix for every historical fixture is not present and is required before a completed cutover. |
| Anonymous production `bed` fallback | PROVEN WITH TEMPORARY FALLBACK | It is committed, separately tested and safe during parallel development/a staged proposal. The binding migration contract says remove it only at cutover; it may not be described as fully migrated or remain as the final post-cutover wake implementation. |
| Adapter/acoustic/global-state teardown | PROVEN | Deep acoustic snapshot restores byte-equivalent records; mounted consumers and promoted Vantry owner are removed; adapter reports empty state; final run has no ObjectDB/resource leak warning. |
| Full production gameplay/service composition under v2 | BLOCKING | Temporary test mounting proves selected consumers, not a complete `BuildingRoot` replacement. The v2 review root has no production player, resident/service directors, campaign binding, full prop construction or production interaction dispatcher. |
| Full-root raw-coordinate/fallback census | BLOCKING | The first-slice known consumers use stable ids, but no production-capable v2 root exists against which to run the complete consumer census. The anonymous bed lookup remains intentionally active, and broad production passes still read v1 `building_layout.json`. |
| Pre-existing dirty production layout | OPEN NON-BLOCKING DEBT | The file was dirty before M08/M08A/M08B and remains untouched. It does not invalidate in-run byte stability, but any later cutover work must continue to exclude it from staging and compare against an agreed committed baseline. |
| GPU gameplay timing | OPEN NON-BLOCKING DEBT | Headless traversal cannot report GPU frame time. Windowed captures are evidence timing, not gameplay timing. CPU/physics proportional budget passes. |

## Direct answers

- **Durable deterministic receipts?** Yes: committed schema/checkpoint/tests.
- **All first-slice anchors unique?** Yes, twelve of twelve.
- **Runtime parity exercised?** Yes for the first slice’s named F01/F02/F04
  consumers and root-neutral save owner; not for a full production v2 root.
- **Human readability accepted?** Yes, MANUAL PASS.
- **Performance within budget?** Yes.
- **v1 default and stable?** Yes; both boot paths remain v1 and test-time hashes
  remain unchanged.
- **Reproducible v1 fallback?** Yes, committed at `aa62f9e`.
- **Reversible selector-only cutover today?** No; there is no single selector and
  no production-composed v2 scene.
- **Historical/future saves under both roots?** Root-neutral compatibility plus
  v2 reconstruction and v1 fallback are proven, but the legacy bed path remains a
  temporary fallback and a full two-root fixture matrix is absent.
- **Compatibility debt blocking a cutover proposal?** Yes: production v2
  composition, one reversible selector, and a full-root consumer/save matrix.

## Expected M09 change boundary

M09 must not start until a separately authorized checkpoint closes the blockers.
If later authorized, the expected/allowed cutover proposal paths are:

- `game/scripts/game_boot.gd` — consume one reversible building selector rather
  than independently naming a root;
- `game/scripts/dream/campaign_shell.gd` — consume that same selector during
  waking-world reconstruction;
- `game/scripts/building/orison_v2_anchor_adapter.gd` — only runtime-grade mounting
  and teardown needed by the selected production composition;
- `game/scenes/building/orison_v2_runtime.tscn` — new production-composed v2 root,
  distinct from the review scene;
- `game/scripts/building/orison_v2_runtime_root.gd` — new composition boundary if
  scene-only wiring is insufficient;
- `game/tests/orison_v2_cutover_test.gd` and
  `game/tests/OrisonV2CutoverTest.tscn` — selector, rollback, two-root save and
  complete authority-parity proof;
- `design/ORISON_V2_M09_CUTOVER_PROPOSAL_2026-08-28.md` — evidence, fallback tag,
  rollback instructions and retirement schedule.

The exact files forbidden from M09 modification are:

- `game/project.godot` (title remains the application entrypoint);
- `game/scenes/building/orison_root.tscn`;
- `game/data/building_layout.json`;
- `art/data/building_layout.json` and `art/data/gen_layout.py`;
- existing `game/assets/building/floor_*.gltf` and `floor_*.bin` outputs;
- `game/scripts/game/reality_game_state.gd`;
- `game/scripts/game/work_orders.gd` and `game/data/maintenance_jobs.json`;
- `game/scripts/call/case_library.gd`, `game/data/reality_cases.json` and
  `game/scripts/call/call_interface.gd`;
- `game/scripts/campaign/core_loop_director.gd`;
- acoustic authority/data and `game/scripts/audio/virus_sound_director.gd`;
- all existing v1 and Orison v2 evidence packet directories.

These prohibitions enforce the contract: cutover changes selection/composition,
not jobs, cases, saves, interaction, audio, wake facts, v1 generation or evidence.

## Regression receipt

Run from `aa62f9e` with no foreign Godot/Blender process present:

- `OrisonV2BlockoutTest.tscn`: PASS, including v2 development-only assertion,
  deterministic census, route/collision checks and production-layout stability.
- `OrisonV2IntegratedTest.tscn`: PASS, including twelve unique anchors,
  strengthened F01/F02/F04 runtime behavior, real save/reconstruct, continuous
  traversal, service continuity, performance and adapter/global restoration.
- `RealitySaveCompatTest.tscn`: PASS 14/14.
- Default assertion: PASS — title → CampaignShell → `orison_root.tscn`.
- Production layout before/after assertion: PASS; workspace SHA-256 recorded above.
- Shutdown teardown: PASS; no ObjectDB/resource leak warning.
- Visual recapture: not run; committed receipt and all ten referenced PNGs are
  present and readable.

## Final recommendation

**DO NOT AUTHORIZE M09.** First authorize a bounded production-v2 composition and
single-selector checkpoint that closes the three BLOCKING rows without changing
gameplay/save authorities. M08A route-readability acceptance remains valid and
closed; this recommendation does not reopen it.
