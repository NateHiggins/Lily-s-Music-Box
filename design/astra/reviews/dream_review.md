# Dream and lamp branch forensics

Canonical base: `c2dc01771bc25b07f5dcf7a6040102345b8c57d5`. Reviewed voxel tip: `efc5d61f8fb20d2c5ec1cb81be91190715ee467f`. No implementation, rebase, import, runtime tests, staging or merge performed. Historical test results below are evidence, not current-base results.

## Disposition

Do not merge the voxel line wholesale. Scoped V1A and microorganism art acceptance exists, but failed C1C/C1D, unresolved S2J/L1D, unclosed asset resources, default-off rollout, and absent production texture/save consumers prevent treating the branch as integrated.

## Verified branches

| Ref | Tip | Behind / ahead |
|---|---|---|
| codex/dream-surface-s1 | `89ab096fba6c` | 45 / 5 |
| codex/dream-surface-s1e | `9cb9db1c7580` | 44 / 7 |
| codex/dream-surface-s1f | `a8b8d5a1607c` | 41 / 10 |
| codex/dream-surface-s2 | `b5ac8f7fcaac` | 41 / 13 |
| codex/dream-surface-s2d | `b5ac8f7fcaac` | 41 / 13 |
| codex/dream-color-c1c | `c96cc9eb72a3` | 41 / 18 |
| codex/dream-color-c1d | `cacaa0ae150d` | 41 / 19 |
| codex/dream-voxel-v1 | `efc5d61f8fb2` | 41 / 24 |
| codex/lamp-optics-l1 | `10e3d0b71410` | 41 / 4 |
| codex/dream-ecology-cognition-e4 | `e89fa608874f` | 41 / 0 |

## Commit classification

Full exact changed paths, parent/dependency notes, overlapping commits/refs, stable patch equivalence and immutable evidence identities are in `dream_review.json`. Each row below is a specific commit; class applies only to its documented scope.

| Commit | Class | Scope |
|---|---|---|
| `e89fa608874fe2b75ecd0f0b52ab84829c884d82` | CANONICAL_ALREADY_IN_MAIN | Ecology cognition branch tip |
| `a9efdc7b26e85a26c958c018b8b5d01e8deacd88` | DUPLICATE | Original S1/S1E replay |
| `5a4a7698382728ea909adff0401437f4637ee17e` | DUPLICATE | Interleaved Orison service-round duplicate |
| `21c8de357afcf43698c66481ae92be70061a79ee` | DUPLICATE | Original S1/S1E replay |
| `00b3911bdf9648fe60f790e44cc4b7d8b5dd1737` | DUPLICATE | Original S1/S1E replay |
| `89ab096fba6c1f9e098571f8f01399f3f88f0f0c` | DUPLICATE | Original S1/S1E replay |
| `75044f47c66c7b0325f05178709c3aa67c353a53` | DUPLICATE | Original S1/S1E replay |
| `aa5e067c7490ba9f45045428dbe1e53c9c74361c` | DUPLICATE | Original S1/S1E replay |
| `b4c25bc433fb2c784c3f702628f8e61098613e9b` | DUPLICATE | Original S1/S1E replay |
| `fa49d7085f724c06580946309aa8c9af2d226df2` | DUPLICATE | Original S1/S1E replay |
| `4eba3ad9d79e5e7de7a5349706f47618e9f288ad` | DUPLICATE | Original S1/S1E replay |
| `ade6bae89e052f7b781072a00cd6fe09cc4f34ae` | DUPLICATE | Original S1/S1E replay |
| `9cb9db1c7580f55896f4d44c6a9261ab887f7ac9` | DUPLICATE | Original S1/S1E replay |
| `22350771eb607b2ad365365f6558a0be1c11426e` | TECHNICALLY_PROVEN_BUT_HUMAN_PENDING | S1/S1F cellular substrate |
| `27d18d1cf1f417608fff3dea459fc2010305c563` | TECHNICALLY_PROVEN_BUT_HUMAN_PENDING | S1/S1F cellular substrate |
| `2c75967b101c20bd428f0b3951cd18ba2f5867ae` | TECHNICALLY_PROVEN_BUT_HUMAN_PENDING | S1/S1F cellular substrate |
| `54efb2f551ba6279c95a681aabbc22724d31b846` | TECHNICALLY_PROVEN_BUT_HUMAN_PENDING | S1/S1F cellular substrate |
| `8860ff508d49d14b5c02e480bc964f68a00addcb` | TECHNICALLY_PROVEN_BUT_HUMAN_PENDING | S1/S1F cellular substrate |
| `bd311671abdbbb0561a1c338178d17a4c0de1321` | TECHNICALLY_PROVEN_BUT_HUMAN_PENDING | S1/S1F cellular substrate |
| `efb48a617c1e9f0d65fe87e6824a06297c48aa8d` | TECHNICALLY_PROVEN_BUT_HUMAN_PENDING | S1/S1F cellular substrate |
| `a85692bd5994e9fa7b20122f59938ea0abd762af` | TECHNICALLY_PROVEN_BUT_HUMAN_PENDING | S1/S1F cellular substrate |
| `5fce28b94097a49bb8a3ae33a6cc3ec2290d2882` | TECHNICALLY_PROVEN_BUT_HUMAN_PENDING | S1/S1F cellular substrate |
| `a8b8d5a1607cebbe0172cc405e7c3fb00bf044bc` | EVIDENCE_ONLY | S1F receipt |
| `b171ba93357c7f2b50cf9b425c998d72b3a42747` | TECHNICALLY_PROVEN_BUT_HUMAN_PENDING | S2A-S2C surface series |
| `d6b7d340e7ab67fbd056613ab3b9b642d924229a` | TECHNICALLY_PROVEN_BUT_HUMAN_PENDING | S2A-S2C surface series |
| `b5ac8f7fcaacded5e470f88431219ef91bf9b43a` | TECHNICALLY_PROVEN_BUT_HUMAN_PENDING | S2A-S2C surface series |
| `bb4af3159515934fead9dc150c12d36ed4e34e8f` | DUPLICATE | Original lamp replay |
| `00907dc59dd5a4ebf50f702b14111370782800b1` | DUPLICATE | Original lamp replay |
| `7e84f388f5c369b0ffd14c23636aed87dcd24f78` | TECHNICALLY_PROVEN_BUT_HUMAN_PENDING | Original L1C mixed asset bundle |
| `34b1354a01a7fde0445de8d00309a5babed0ef90` | TECHNICALLY_PROVEN_BUT_HUMAN_PENDING | L1-L1C lamp review series |
| `5a8b38a14427f12b5fed44a5a6b8aa6cea3d1287` | TECHNICALLY_PROVEN_BUT_HUMAN_PENDING | L1-L1C lamp review series |
| `702f8f42149e3831928a192a8a762f31b5d42e5b` | UNKNOWN_REQUIRES_REVIEW | S2H hero salvage |
| `f62d69c04067724e15732498cf94dc9034e2f861` | TECHNICALLY_PROVEN_BUT_HUMAN_PENDING | L1-L1C lamp review series |
| `c96cc9eb72a30c8d308226bcd94e45bcd7c2ff64` | FAILED_GATE | C1C cytoplasm |
| `10e3d0b7141063d3c317c2f74c2c6946be2bcf70` | EVIDENCE_ONLY | Lamp voxel diagnosis |
| `cacaa0ae150d7b9c74b408f4b4c3829b0a02a3d8` | FAILED_GATE | C1D voxel microscopy |
| `918e011d095af7da470452a7f22c657c6093a147` | ACCEPTED_CANDIDATE | V1 default-off data-path substrate |
| `f1f4c2369faf8e1fbfe3643fb8b79d713c10e0ed` | ACCEPTED_CANDIDATE | V1A visual/data-path proof |
| `7a7281ff3f3ca77a6df5bac43cde3ba282bf3cf6` | ACCEPTED_CANDIDATE | Twelve microorganism morphologies |
| `d441309ead2289eec7824c1b33231bcfa9553f93` | ACCEPTED_CANDIDATE | Twelve-species motion packet |
| `efc5d61f8fb20d2c5ec1cb81be91190715ee467f` | EVIDENCE_ONLY | Motion acceptance record |

## Decisive findings

### DREAM-001 — BLOCKER

Do not merge the 24-commit voxel branch wholesale: accepted later art proof is interleaved with failed C1C/C1D and incompletely preserved hero dependencies.

### DREAM-002 — RELEASE_CRITICAL

Production critter voxel consumer is absent at committed tip. All bind_voxel_optics callers are under game/tests; changing species/optics functions does not bind the exposure field in gameplay.

### DREAM-003 — RELEASE_CRITICAL

V1/V1A is default-off, Mina-targeted moss-only bridge. It constructs a field rather than binding a save-owner field; save/restore/reconstruct methods have no production caller. Field/lamp persistence is a harness proof only.

### DREAM-004 — BLOCKER

S2H hero salvage is incomplete. 702f has four missing preloads plus seven absent GLBs. Failed C1C supplies some missing material/transport assets. Final tip still lacks all three plasmodial GLBs, and no committed deterministic hero generator/source receipt was located.

### DREAM-005 — MAJOR

0.5 m DreamExposureField is room exposure/history, unsuitable as an intracellular scattering or occlusion solver. Keep channel/authority semantics; diagnosis is evidence, not rollout authorization.

### DREAM-006 — MAJOR

L1C focused profile is good but full furnished Orison teardown remained blocked; current main must be rerun before calling legacy light-index assertions present or resolved. No new failure was baselined in this audit.

### DREAM-007 — MAJOR

S1/S1E imports once failed; S1F clean import reran matching main successfully. Deduplicate stale missing-audio/tentacle/ecology tasks instead of reopening them from S1E prose. Human acceptance of S1F remains pending.

### DREAM-008 — MAJOR

V1A human PASS applies to isolated review sheet; GPU feature delta 2.332 ms and field update p95 0.945 ms measured only on RTX 4080. Gameplay-distance falloff/dark membrane and low-tier/performance context remain open.

### DREAM-009 — BLOCKER

S2J failed packet exists only as untracked evidence in dirty S2 worktree. Preserve hash/path and inspect as evidence; never adopt its neighboring dirty code/metadata by directory.

## Scope of accepted work

V1A `f1f4c2369faf8e1fbfe3643fb8b79d713c10e0ed` has an explicit 2026-08-31 human visual PASS. Its receipt says it remains isolated and unmerged; S2J/L1D are unchanged. `ApartmentEncroachment` enables the bridge only when `DREAM_VOXEL_LIGHT=1`. The bridge binds target-floor moss, not the critter controller. It constructs an exposure field in `configure()` and offers `reconstruct_from_durable()` without a production save-owner caller.

The motion receipt explicitly authorizes controlled integration using `7a7281ff3f3ca77a6df5bac43cde3ba282bf3cf6` and `d441309ead2289eec7824c1b33231bcfa9553f93`. `efc5d61f8fb20d2c5ec1cb81be91190715ee467f` only records acceptance. Twelve morphologies plus the original four use the existing bounded draw. Historical focused result: 2104 checks, 16 species, 84000 triangles, one material/texture/field; critter regression 43/43. Atlas/motion are microscopy-room evidence, while the regression demonstrates production spawning. All production-tree calls of `bind_voxel_optics` are absent; only test scenes call it.

S1F reports complete objective/capture gates but human visual acceptance pending. S2 closure prose describes an accepted read after pixel review without an attributable owner PASS. The audit keeps these as technically proven/human pending. The S2H preservation commit carries accepted-assets claims but not a closed source/regeneration and acceptance chain.

## Failure and debt deduplication

- C1C: technical compatibility PASS; later receipt explicitly records visual FAIL. Do not revive its review request as pending acceptance.
- C1D: room-scale exposure works but cannot prove intracellular optics; diagnostic sample/readback and texture ownership fixes do not rehabilitate failed art direction.
- S2J: untracked checkpoint explicitly failed material identity, subtle cortex/value separation, red/magenta family and mat/body optics. Preserve it as a failed gate.
- L1D: blocked throughout later accepted V1A/motion receipts. Good L1C isolated timings do not close full Orison lifecycle.
- S1E missing audio/tentacle/ecology failures: S1F traced these to incomplete import and reran matching main successfully; stale missing-source tasks are superseded.
- Renderer light-index / texture warnings: historical main controls exist, but this audit neither reran them on c2dc017 nor grants a new baseline exception.
- Shared dark membrane, Noctiluca/colony gameplay-distance read and V1A directional falloff are accepted non-blocking art debt at their scoped reviews, still open for composed gameplay.

## Resource closure findings

At `702f8f42149e3831928a192a8a762f31b5d42e5b`:

- `art/dream/surface_hero/plasmodial_tissue_lod0.glb`
- `art/dream/surface_hero/plasmodial_tissue_lod1.glb`
- `art/dream/surface_hero/plasmodial_tissue_lod2.glb`
- `art/dream/surface_hero/transmembrane_complex_lod0.glb`
- `art/dream/surface_hero/transmembrane_complex_lod1.glb`
- `art/dream/surface_hero/transmembrane_complex_lod2.glb`
- `art/dream/surface_hero/transmembrane_complex_lod3.glb`
- `materials/dream_surface_cortex_window.tres`
- `materials/dream_surface_nucleus.tres`
- `materials/dream_surface_network.tres`
- `materials/dream_surface_fiber.tres`

At `7e84f388f5c369b0ffd14c23636aed87dcd24f78`:

- `art/dream/surface_hero/plasmodial_tissue_lod0.glb`
- `art/dream/surface_hero/plasmodial_tissue_lod1.glb`
- `art/dream/surface_hero/plasmodial_tissue_lod2.glb`
- `art/dream/surface_hero/transmembrane_complex_lod0.glb`
- `art/dream/surface_hero/transmembrane_complex_lod1.glb`
- `art/dream/surface_hero/transmembrane_complex_lod2.glb`
- `art/dream/surface_hero/transmembrane_complex_lod3.glb`

At `efc5d61f8fb20d2c5ec1cb81be91190715ee467f`:

- `art/dream/surface_hero/plasmodial_tissue_lod0.glb`
- `art/dream/surface_hero/plasmodial_tissue_lod1.glb`
- `art/dream/surface_hero/plasmodial_tissue_lod2.glb`

The original lamp L1C commit and voxel L1C replay are not equivalent mixed bundles. Their different hero-presenter bytes and missing references must be reviewed explicitly. No committed surface-hero generator/source hash receipt was located.

## Evidence identities

- **s1f**: `efc5d61f8fb20d2c5ec1cb81be91190715ee467f:design/DREAM_SURFACE_S1F_CHECKPOINT_2026-08-28.md` (lines 7-34); blob `2f37bdd7bfbdcb13c0b7c86a782f5af3187c9629`; SHA-256 `c74554f131fbfecd8c0304095e167d0674b5766f32c2aacfa45545f58b4cd443`.
- **s1e**: `efc5d61f8fb20d2c5ec1cb81be91190715ee467f:design/DREAM_SURFACE_S1E_CHECKPOINT_2026-08-28.md` (lines 33-42); blob `0cae3ecd0dd1611c795803d37f60296eeacb6ee8`; SHA-256 `94534802bea4ec60855cd5bd438345f1805d745de01bdbd05f244b6620108a17`.
- **s2**: `efc5d61f8fb20d2c5ec1cb81be91190715ee467f:art/renders/dream_surface_s2/2026-08-28/README.md` (lines 3-50); blob `d6a42c0aa4e83ee1f59c8f8b5c990ca99a89155f`; SHA-256 `2827cd7d21dcbfe8f00222cbd880f0a100e496be553a0118d9eec135a7228f0e`.
- **l1**: `efc5d61f8fb20d2c5ec1cb81be91190715ee467f:design/LAMP_OPTICS_L1_OWNERSHIP_AND_MIGRATION.md` (lines 3-37); blob `d0ba9ef1d0b9f02f8bb4ca45d5675acc0691c3a1`; SHA-256 `6276da33af2fd2d95dc04a8ccdc3aaac883a8f24419d772a907c41fd83acbc4b`.
- **l1c**: `efc5d61f8fb20d2c5ec1cb81be91190715ee467f:art/renders/lamp_optics_l1c/review_01/README.md` (lines 3-29); blob `377eecd9da3dfb37703b2367b1779a57b8740bb1`; SHA-256 `555ce1461975f645f2696cdd3f11b0ff5353ce639815d8bb80daa18784aec30d`.
- **c1c**: `efc5d61f8fb20d2c5ec1cb81be91190715ee467f:art/renders/dream_color_c1c/2026-08-28/runtime_01/C1C_REVIEW.md` (lines 3-21); blob `b278621fcb4e4dd5c2d57448538d33ae810cc3c9`; SHA-256 `eee0ab6d2cdc5b937c0310dfde0335e63e4f35c0698f5be8e2acd3d099e75618`.
- **c1d**: `efc5d61f8fb20d2c5ec1cb81be91190715ee467f:art/renders/dream_color_c1d/2026-08-28/voxel_gate_01/C1D_REVIEW.md` (lines 3-9); blob `10045e096a396a96f022fde14f8e2842084e7055`; SHA-256 `098e09e34578fa6ddfa7080f658d0611c592a708aa05537b93881444829c7f06`.
- **diag**: `10e3d0b7141063d3c317c2f74c2c6946be2bcf70:art/renders/lamp_voxel_diag1/2026-08-29/runtime_01/DIAGNOSIS.md` (lines 3-21); blob `930a8a00e0ad7f5351909b2074530a682ce2ed8e`; SHA-256 `26467490c786f33690769c19bbdc9e049a29fef02d7dd1102dd34eb18e852e6c`.
- **v1**: `efc5d61f8fb20d2c5ec1cb81be91190715ee467f:art/renders/dream_voxel_v1/2026-08-30/runtime_01/V1_REVIEW.md` (lines 3-7); blob `509de2894b15872f569abae5566f9de1f2762381`; SHA-256 `c119193bbdc883cd466de423496a214adef7419f4d34ae8e4ae8bbbd7ccbaf98`.
- **v1a**: `efc5d61f8fb20d2c5ec1cb81be91190715ee467f:art/renders/dream_voxel_v1a/2026-08-30/runtime_01/V1A_REVIEW.md` (lines 3-11); blob `049ed2b5722e791935ca9ba5a2ebd78226d628c1`; SHA-256 `982be684f0d96e0acd1470abb8a7b7de666921e8c42652e789acb2c690c9736d`.
- **v1a_machine**: `efc5d61f8fb20d2c5ec1cb81be91190715ee467f:art/renders/dream_voxel_v1a/2026-08-30/runtime_01/runtime_evidence.json`; blob `cf3d372adfa53d63f18958c077f6f45ebc492a1a`; SHA-256 `3dafefecae5e97fc031edc32a01c33e6a3b2971ff825cfd8785ac0496f771b3d`.
- **atlas**: `efc5d61f8fb20d2c5ec1cb81be91190715ee467f:art/references/dream_critters_v3/IMPLEMENTATION_RECEIPT.md` (lines 3-16;37-55;92-142); blob `2a846902b128751f3154d4cdc96597d95e4f1200`; SHA-256 `09af6d88ff5d5869ec49b2cc636ab604109614e9753765d73edfed19ffbf3b46`.
- **motion**: `efc5d61f8fb20d2c5ec1cb81be91190715ee467f:art/references/dream_critters_v3/MOTION_ACCEPTANCE_RECEIPT.md` (lines 3-43;91-121); blob `3bbbc9124524d28d1c58abd0d59b54a84fdf2b46`; SHA-256 `d686422695ac92ba8001854b8d3c806d9ad5e81c67ce3bad47e16bc4aa43e860`.
- **enc**: `efc5d61f8fb20d2c5ec1cb81be91190715ee467f:game/scripts/reality/apartment_encroachment.gd` (lines 387-422); blob `be272271987494b800c896ac29d725157f4a7c36`; SHA-256 `48ea8c38f0b53de64d148f64ffd2d788ee966866ee6556acbc6147a2535e65a3`.
- **presenter**: `efc5d61f8fb20d2c5ec1cb81be91190715ee467f:game/scripts/dream/dream_voxel_light_presenter.gd` (lines 42-56;298-312); blob `ffc2e93bd6a9c36cd145633bea1ba821f8036ecc`; SHA-256 `a633eb54edc24d91dde3cb666bd30f3b3f16f42639de7081a92c7d6e367a6d7f`.
- **critter_binding**: `efc5d61f8fb20d2c5ec1cb81be91190715ee467f:game/scripts/dream/critters/dream_critter_controller.gd` (lines 89-131); blob `db8ee973c2236c5d96a954d3f36c712c682a1fd4`; SHA-256 `1c7d4b271b9df1bbf62c21da35070f13ae0f97bed16f7aa7d35e1ae0130a5733`.

## Untracked evidence quarantine

- `C:\PleaseRemainOnTheLine-s2\art\renders\dream_surface_s2j\2026-08-28\runtime_01\S2J_CHECKPOINT.md` — FAILED_GATE; SHA-256 `4fe6a11f16eadfd104bf2ce54080a098e062d8ff733ef12c6809fec089cfa342`. Untracked bytes, not an accepted commit.
- `C:\PleaseRemainOnTheLine-s2\art\renders\dream_surface_s2i\2026-08-28\runtime_01\S2I_RUNTIME_REPORT.md` — QUARANTINED_DIRTY; SHA-256 `7e327b25efb1f225cfed9d6e13b16a43005741577ac6912cc07789acad944eee`. Untracked bytes, not an accepted commit.
- `C:\PleaseRemainOnTheLine-s2\art\renders\dream_color_c1\2026-08-28\runtime_01\C1_CHECKPOINT.md` — FAILED_GATE; SHA-256 `dfc372389c6e19485ad1160121de3abbce59a4cb1f9465738ae2bd7fa53b243d`. Untracked bytes, not an accepted commit.
- `C:\PleaseRemainOnTheLine-s2\art\renders\dream_color_c1b\2026-08-28\runtime_05\C1B_REVIEW.md` — QUARANTINED_DIRTY; SHA-256 `5992aee35771286c9704223a23ed20ecae2c404698c3c306d314ba1663d9487b`. Untracked bytes, not an accepted commit.

## Worktree quarantine

| Worktree | Tracked changes | Untracked paths | Disposition |
|---|---:|---:|---|
| `C:\PleaseRemainOnTheLine` | 13 | 2300 | QUARANTINED_DIRTY |
| `C:\PleaseRemainOnTheLine-s1e` | 0 | 230 | QUARANTINED_DIRTY |
| `C:\PleaseRemainOnTheLine-s1f` | 121 | 350 | QUARANTINED_DIRTY |
| `C:\PleaseRemainOnTheLine-s2` | 129 | 408 | QUARANTINED_DIRTY |
| `C:\PleaseRemainOnTheLine-lamp-optics-l1` | 0 | 0 | CLEAN_COMMITTED_SNAPSHOT |
| `C:\PleaseRemainOnTheLine-ecology-cognition` | 0 | 0 | CLEAN_COMMITTED_SNAPSHOT |

The exact tracked/untracked names are preserved in JSON. These counts are an observation, not permission to reset/clean/import these worktrees.

## Reversible proposed sequence

1. Preserve forensic packet; do not replay any dream series into canonical line yet.
2. Close exact S1F/S2 substrate acceptance and hero resource/source provenance in a separate clean rehearsal. Initial S1F ten hashes have no human visual PASS; S2 six-shot prose is not independently attributable owner acceptance. Exact commits: `bd311671abdbbb0561a1c338178d17a4c0de1321`, `efb48a617c1e9f0d65fe87e6824a06297c48aa8d`, `8860ff508d49d14b5c02e480bc964f68a00addcb`, `27d18d1cf1f417608fff3dea459fc2010305c563`, `22350771eb607b2ad365365f6558a0be1c11426e`, `54efb2f551ba6279c95a681aabbc22724d31b846`, `2c75967b101c20bd428f0b3951cd18ba2f5867ae`, `a85692bd5994e9fa7b20122f59938ea0abd762af`, `5fce28b94097a49bb8a3ae33a6cc3ec2290d2882`, `a8b8d5a1607cebbe0172cc405e7c3fb00bf044bc`, `b171ba93357c7f2b50cf9b425c998d72b3a42747`, `d6b7d340e7ab67fbd056613ab3b9b642d924229a`, `b5ac8f7fcaacded5e470f88431219ef91bf9b43a`, `702f8f42149e3831928a192a8a762f31b5d42e5b`.
3. Choose one L1-L1C representation after dependency audit; retain focused evidence, rerun full composed lifecycle, and keep L1D blocked. Exact commits: `5a8b38a14427f12b5fed44a5a6b8aa6cea3d1287`, `f62d69c04067724e15732498cf94dc9034e2f861`, `34b1354a01a7fde0445de8d00309a5babed0ef90`.
4. Rehearse V1 plus V1A only once required substrate and lamp dependencies are accepted. Preserve default-off gate; close actual field ownership, production save, and composed GPU/perceptual proof. Exclude C1C/C1D broad replay. Exact commits: `918e011d095af7da470452a7f22c657c6093a147`, `f1f4c2369faf8e1fbfe3643fb8b79d713c10e0ed`.
5. Rehearse exact microorganism implementation and motion hashes as the receipt authorizes; resolve S1 substrate dependency and production texture binding explicitly. Keep material/geometry authority fixed. Exact commits: `7a7281ff3f3ca77a6df5bac43cde3ba282bf3cf6`, `d441309ead2289eec7824c1b33231bcfa9553f93`.
6. Carry acceptance documentation as evidence; do not count it as implementation. Exact commits: `efc5d61f8fb20d2c5ec1cb81be91190715ee467f`.

No listed rehearsal is performed by this audit. Any canonical adoption still needs current-base dependency closure, tests with real exit status and red fixtures, production consumption, save/reconstruction, composed performance and appropriate human acceptance.
