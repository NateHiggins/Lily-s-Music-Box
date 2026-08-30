# LAMP-VOXEL-DIAG1 diagnosis

The isolated chain passes its objective tests. LampOpticalState is deterministic; LampOpticalInstrument's actual SpotLight3D pose/output reaches DreamExposureField.add_lamp(); the bounded CPU volume uploads as RG8; and an independent receiver shader agrees with eight CPU queries within the recorded tolerance.

DreamExposureField is plainly an accumulated ecological exposure map, not an instantaneous volumetric-light solution. Its 0.5 m cells locate room-scale conversion. R persists by dwell; G rises and falls at ruled rates. Neither channel can encode intracellular occlusion, anatomy-scale depth, or microscopic scattering.

## Actual C1D failure

- Field resolution insufficient for intracellular optics.
- System is functioning correctly but is conceptually unsuitable for microscopic volumetric lighting.

C1D's receipt showed CPU-side active texels and claimed a shader binding, but supplied no CPU-query versus rendered shader-sample comparison. Its own teardown also retained the voxel texture. This diagnostic closes the data path with readback and clean ownership, while preserving C1D unchanged.

## Recommendation (after diagnosis)

Keep DreamExposureField as the room-scale ecological-history authority. If microscopic volumetric lighting is required later, use a separate organism-local optical volume or analytic density/occlusion representation driven by the lamp's instantaneous pose; do not increase or reinterpret DreamExposureField to serve that unrelated scale.

L1D remains blocked. S2J is not superseded. No production rollout or merge was performed.
