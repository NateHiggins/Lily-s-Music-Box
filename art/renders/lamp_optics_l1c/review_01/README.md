# LAMP-OPTICS-L1C review packet

Exactly five 1600×900 Forward+ acceptance artifacts are present. This remains an isolated review implementation on `codex/lamp-optics-l1`; it does not change Orison architecture, selectors, ecology authority, or production rollout.

## Performance result

With vsync disabled, 90 warm-up frames, and 120 measured frames per row, the focused production-tier optics move the calibration frame from 0.416 to 0.706 ms CPU wall median and from 0.149 to 0.454 ms measured GPU median. The combined feature delta is therefore 0.290 ms CPU and 0.305 ms GPU on the RTX 4080, beneath the preferred 2 ms budget. The controller is 0.003733 ms/update against its 0.20 ms gate.

Capture is outside ordinary frames: the measured texture readback was 6.188 ms and resize/PNG encoding was 466.449 ms. No capture, resource load, or image readback occurs in the instrument’s ordinary update path.

The 48³ froxel experiment reduced the spot-plus-fog GPU median from 0.178 to 0.156 ms. The project-wide 64³ default is deliberately unchanged. The lower-cost optical tier instead uses a 3.9×3.9×6.5 m local volume, 0.034 density, one noise octave, 48 bounded particles, and disables fog/particles below 0.035 useful intensity. The hero tier retains 120 particles.

## Cellular result

Artifact 05 consumes the approved S2H `cellular_interior_lod0/1/2` runtime meshes and their shared membrane, protein/gold, and internal materials. The camera and organism are locked; only real key-light placement changes. The surface has zero emission. Gold is metallic/anisotropic rather than emissive, while cloudy cytoplasm and internal silhouettes belong to separate accepted meshes rather than an exterior decal.

## Teardown disposition

The calibration plus accepted-cellular lifecycle is clean: zero render objects, no retained optical rig, no retained cellular presenter, and no renderer errors.

The full Orison root is not cleanly destructible under Godot 4.7.1. A fully imported, untouched `origin/main` control reproduces 1,264 instances of `BUG, indexing did not unpair geometries from light`; the L1C branch reproduced 1,246 before the review lifecycle was isolated. Both eventually report zero render objects. Attempts to drain internal Light3D nodes first still trigger the assertion and can crash the engine. This is recorded as a baseline engine/Orison blocker, not claimed as an optical fix.

Therefore the focused optical feature and isolated teardown pass, but the requested full furnished-Orison clean-teardown acceptance remains blocked pending an engine/Orison lifecycle correction.
