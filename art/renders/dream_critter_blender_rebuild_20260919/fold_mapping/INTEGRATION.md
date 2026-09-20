# Fold crab staged mapping integration
Evidence class: **INERT**

This directory is an external proposal and bounded geometry probe, not a native shader or art acceptance receipt. No production file was changed.

Use `fold_crab_mapping.gdshaderinc` after the existing atlas helpers and crab uniform declarations. Spatial owns `blender_joint_base[12]` and `blender_manipulator_base[12]`; do not declare competing arrays. They address respectively 8×5 and 2×3 constant atlas rows, sampled at pose0/component0. Validate nonnegative bases before invoking the paths.

## Caller order

1. For kind2 and positive canonical code0..7, compute `cpu=fold_cpu_leg(code,int(round(counts.x)))` before selecting the law sample. Only an active leg whose mapped CPU index equals `law.y` gets `law.z`; other legs and unbound body use Basis. Apply the existing source phase delta separately.
2. Scale source positions by `dimensions=(size.y,size.z,size.x)` and source normals by inverse dimensions. For positive codes call `fold_leg_point` and `fold_leg_normal`, with `bob=counts.w-1`. These calls apply to explicit zero-weight root vertices too. Do not also run the tardigrade foot-delta path.
3. Codes-20/-21 call the jaw helpers with index=-20-code, `photo.x` as deploy and TIME for the pre-existing tiny lateral wave. Do not treat them as count-controlled feelers. Codes-2..-6 retain the five-feeler branch/collapse path; body code-1 stays Basis in the selected initial integration.
4. Keep authored visibility binary (`slot_valid && counts.w>0`), as root is implementing. `counts.w` carries body bob and must not multiply the complete world offset. The common final world transform adds bob once; foot target in this helper subtracts it once.

The canonical mappings are:

| CPU count | source slots0..7 → CPU |
|---|---|
|6|0,1,hidden,2,3,4,hidden,5|
|7|0,1,2,3,4,5,hidden,6|
|8|0,1,2,3,4,5,6,7|

`root_only_mapping_probe.json` contains18 actual source-mesh cases, bothLODs × counts6/7/8 × neutral/first-leg fullfold/last-leg fullfold, with no detected crossings or organ escapes. It uses nominal CPU fallback feet and no body bob. It excludes and explicitly counts zero-area triangles created by intentional inactive-branch collapse. It does not prove a nondegenerate closed runtime mesh for hidden branches. `old_mapping_probe.json` reproduces at least20 actual crossings under the discarded first-N mapping in six-leg LOD1 neutral. `root_only_red_probe.json` is retained despite its name: the proposed extra red for revised root-only mapping did NOT fail. The anticipated collar failure was not reproduced.

The optional `fold_collar_*` functions are NOT part of the selected integration. A monotone lateral cortex adaptation also passes the separate18-case `source_mesh_mapping_probe.json`, but changes body shape and is unnecessary absent a visible/native defect.

## Source authority and limitations

CPU gait owner: `game/scripts/dream/critters/dream_critter_controller.gd:820` and slot packing at1438. Real stance feet, side-dependent row counts, turn bias, phase staggering, terrain rays and reach recovery remain CPU-owned. Legacy visual joint recipe is `game/shaders/dream_critter_body.gdshaderinc:254`; mouth deployment is at491. Root/crab uniform recipes are retained exactly; continuous Hermite interpolation between the five controls follows the new source geometry, replacing the old piecewise visual tubes.

The source deliberately uses flank-normal laminated limb sections. The normal helper implements the inverse transpose of that axial-translation warp, with near-zero source tangent/output guards. It does not turn them into circular tubes. Their blade appearance needs native inspection; the legacy shader itself documents why accidentally fixed-plane circular tubes looked like ribbons. Jaw normal transport is a first-order centerline-gradient approximation, also guarded against zero vectors. It needs native lighting inspection at full deployment.

Nominal anchor equality is not a measurement of every sole vertex's contact. The terminal pad is authored around a synthetic sole datum and can extend slightly beyond it. The18 probes do not cover actual raycast feet, turn extremes, limb crossing during live swing, every possible selected knee, deployment sweeps, material normals or native compiler behavior. Root-required6/7/8 captures plus live gait, selected fold and deploy0/1 controls remain mandatory. No clamping of actual CPU joint positions is proposed: extreme packed positions could still make a target segment reverse or pinch; such a defect must be diagnosed from live evidence.
