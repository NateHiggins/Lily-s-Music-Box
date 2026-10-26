# Tentacle encounter acceptance closure - 2026-10-26

Evidence class: **INERT**. Implementation and verification report; the linked
test-written runtime contract supplies the scoped runtime evidence.

The remaining composed-world surface qualification is complete. The final
windowed run passed **39,699 checks with zero failures**. Its exhaustive
inventory covers **27,586 draws, 16,923 meshes, 6,350 materials and 505 textures**;
no unresolved UV, custom PBR, loaded-mipmap or filtering findings remain.
Shutdown stderr is empty: no leaked Texture, Mesh, Material, Shader or ObjectDB
instances were reported. Sixteen final captures were reviewed, including
installed tentacles/residue, transparent passage panes, wet rooms, controls,
fire stock and exterior geometry.

The canonical [runtime contract](../art/renders/orison_v2/surface_requirements_20261011/runtime_contract.json),
[runner receipt](../art/renders/orison_v2/surface_requirements_20261011/suite_run.receipt.json)
and [render review](../art/renders/orison_v2/surface_requirements_20261011/visual_review.json)
are published together with byte-identical compressed logs. The publisher
independently returned **PASS, zero defects** after installing the packet.
The preceding packet and failed diagnostic logs remain preserved under
[the closure archive](../art/reviews/tentacle_surface_20261026/manifest.json).

## Repairs

Literal-alpha glass now has a subtle generated film albedo alongside its
existing custom roughness and normal maps. Authored tint and opacity remain.
Mirror fallback materials own native-UV copies, so leaving the live reflection
view cannot restore the catalogue's triplanar setting. The surface auditor
recognizes the typewriter's three physical steel channels and separately
inventories its exact smoke shader/owner pair; negative controls still reject
missing maps, missing mips and unrelated owners.

Verbose shutdown identified the remaining six meshes and two materials as
fire-rack test resources. A typed child loop aborted on a native body, leaving
an unparented stock probe alive. The loop now inspects actual collision shapes,
and the read-only stock probe belongs to the world even if a check aborts.
The surface harness also retires its storage review and drains deferred cleanup.
The earlier seven Texture RIDs were a separate reflection-atlas engine defect,
resolved by the documented hash-pinned backport in **71664cfe**.

Qualification retains real player collision layers, grab/motion/release and
self-closing doors. The route driver follows the door's declared gesture and
reopens both leaves on return. Streamed region residency is observed during
the walked programme. Wet-room coverage checks every authored room and the
actual ceramic triangles that replace wood skirting. Wall UV checks account
for 16-bit packed directions in their analytic authoring frame; floors retain
the decoded frame used by their existing builder. The source-coordinate UV
tolerance remains 0.02 mm. The retired arcade cabinet capture was removed in
accordance with the existing arcade retirement ruling.

## Encounter verification retained

The searching, neighbouring-tip approaches, strong directional recoil,
continued struggling, viscous rainbow/char pool and purple smoke implementation
remains **71664cfe**. Its unchanged focused proof passes **402 checks**, and the
installed encounter passes **20**. The fresh user pipeline-cache control measured
maximum emergence/melt/puff frames of **29.323 / 21.964 / 23.124 ms** against a
22.639 ms baseline on this RTX 4080; project shader and driver caches remained.
This closes the previous first-use hitch finding within that measured scope.
The owner's optical shader work is preserved. Guide-bell **60-check** and Tardi
**103-check** isolated reviews remain unchanged verification, not whole-campaign
acceptance. See [the creature checkpoint](TENTACLE_GANG_COMPLETION_2026-10-26.md).

## Management record

REPORT - TENTACLE-SURFACE-CLOSURE - 2026-10-26

- Branch / candidate / origin/main / merge-base: **codex/v2-acoustic-topology** /
  **970c5bb8fed68b947a58e5be42a7ac93ae904dc8** / **4dec20aa369ea24a1c237317e11b4a1abbbd60cd** /
  **7a548239e3fddba395341e05fcb3be6ec583ae3e**.
- Worktree clean at end: **no**. Other owners' geometry, catalogue, Tardi,
  guide-bell and tooling work remains; the two guide-bell paths remain staged.
  The [named remaining changes](../art/reviews/tentacle_surface_20261026/shared_worktree_status.txt)
  were recorded after the scoped code/evidence commit.
- Protected **17/17 unchanged against 71664cfe**; selector **v2**, explicit v1
  rollback retained. No protected path belongs to this change.
- Ledger before -> after, ordered ABSENT / ANCHOR_ONLY / SHELL_ONLY / PROGRAMMED /
  SPATIALLY_PROVEN / RUNTIME_PROVEN / HUMAN_ACCEPTED:
  **4 / 0 / 0 / 122 / 86 / 27 / 1 -> 4 / 0 / 0 / 122 / 86 / 27 / 1**.
  Requirements changed: **[]**. All requirement records are identical.
- Gates: completeness **exit 2**, unchanged existing blockers; reader **exit 0,
  NEW 0**; physical import sources **exit 0, 349 present, zero wrong/missing**;
  physical texture settings **exit 0, 1,399 correct**; surface-tool unit tests
  **37 pass** across the suite and a successful retry of one import-file lock.
  The full gate board, spatial/systemic/period suite and clean merge-base
  candidate verifier were not rerun; no broad integration-green claim is made.
- Godot: **BATHROOM TILE PREVIEW: PASS; failures=0**, runner **exit 0**;
  **PUBLIC REGION WALK PROBE PASS checks=3 failures=0**, runner **exit 0**;
  **V2 SURFACE QUALIFICATION: PASS; 39699 checks; 0 failures**, runner **exit 0**.
  Full run LogPath: **tmp/tentacle_acceptance/surface_repair4.log**;
  its durable receipt/logs are linked above. Focused receipts and exact logs are
  preserved in the archive's **focused/** directory.
- Numbers requested: zero surface findings, zero shutdown leaks; first-use
  frame measurements and encounter check counts are recorded above.
- Outside the creature file boundary: glass, mirror fallback and qualification
  helpers required repair to close the composed-world acceptance failure.
- Open findings not fixed within this task: **none**. Broader ledger blockers
  remain outside encounter/surface scope. This receipt binds the shared rendering
  inputs present during the run; it is not a clean release or full-game claim.
- Decision needed from owner: **none**. The scoped changes are committed;
  unrelated branch history has not been merged into main.

MERGE-CANDIDATE 970c5bb8fed68b947a58e5be42a7ac93ae904dc8
