# V2 lamp material and performance pass

Production changes: dust now uses a bounded forward-scattering phase response instead of the billboard's flat-surface normal/specular highlight. Native light color, cone/range attenuation and scene shadows remain authoritative; the shared optical sample gates occupancy and never adds the lamp's radiance once per scene light. Ordinary opaque PBR materials retain their existing renderer response.

Empty fog voxels skip procedural noise without changing the accepted density/detail tier or voxel dimensions. An inactive lamp releases the full-screen volumetric pass when this owner introduced it; an environment with pre-existing fog stays enabled. Teardown restores the original environment settings. Electrical state, ecology, anatomy, saves and V1 are unchanged.

## Validation

- `material_02.log`: five rendered controls pass, empty stderr. Mean display-space sample: clear 0.280666; native mesh shadow 0; blocker removed 0.280666; second native light 0.371246; nonzero field with both native lights off 0; logical field off with native lamp retained 0. These are screenshot sample values, not calibrated physical radiance.
- `composed_02.log`: 35 checks pass, empty stderr, including GPU field clearing, native shadow setup, logical off/on fog-pass ownership, and resource teardown. Its captures were reviewed in the actual room.
- `paired_03`: before/after fog optimization at frozen pose, thermal state and noise time, with particles hidden in both captures. Maximum RGB difference is one 8-bit code value; channel mean differences are below 0.0021 code values. Density/detail were not reduced.
- `tools/analyze_v2_lamp_material_performance.py` validates the final logs, raw timing population, image difference and unchanged controller SHA256, and regenerates `summary.json`.

## GPU timing and limits

Godot 4.7.1 Forward+, RTX 4080, two fixed 1280x720 views of the same actual V2 World3D and identical cameras. World simulation is frozen. Both views retain ordinary materials, room lighting and the real shadowed spotlight. One adds fog and dust, and roles are exchanged. Held-device/UI passes are excluded equally. Both-off and both-on controls expose substantial renderer order bias. Each interval has 60 settling frames and 120 raw GPU pairs.

With d = median(view1 GPU - view0 GPU), the balanced estimate is (d_when_view1_has_atmosphere - d_when_view0_has_atmosphere)/2. The four estimates across `paired_02` and `paired_03` are 0.25625, 0.22475, 0.31475 and 0.30250 ms. This estimates the *added atmosphere over an already-shadowed spotlight* in this one paired room setup. Null controls show the order bias is not fully constant; these are not a release budget, whole-game frame time, or an isolated fog-optimization speedup. No performance threshold was loosened to award acceptance.

Compute injection lies outside the viewport query. Forced injection in the final ordinary composed review measures median 0.020160 ms GPU, p95 0.040544 ms, max 0.103872 ms; CPU construction median 20 us and submission 12 us. Paired-view injection has a different workload/clock state (median 0.010656 ms in `paired_03`) and is retained separately. Neither is advertised as total flashlight cost.

`paired_01` is the initial paired attempt, without null controls. `composed_01` is FAILED even though its GDScript assertions print 35/0: fog shader compilation rejected a return in the processor. It was corrected to a branch; final stderr is empty. `material_01` is a fixture parse failure caused by an unavailable enum; the verified owned process was stopped, the fixture corrected, and `material_02` passed. Failed controls are retained rather than relabeled.

## Remaining work

This completes the dust material correction, empty-fog optimization and lamp-off pass release. It does not complete all optical families. Cellular wet films, cilia, cloudy internal volumes, thin transmission, depth anatomy, gold, SSS and glass still need their composed consumers and review. The isolated lab receiver is unsuitable for blind substitution because it adds field radiance per scene light without native attenuation. No failed anatomy gate, human acceptance, full V2 completion or default selector change is claimed.

Native light-loop reference: https://docs.godotengine.org/en/4.6/tutorials/shaders/shader_reference/spatial_shader.html
