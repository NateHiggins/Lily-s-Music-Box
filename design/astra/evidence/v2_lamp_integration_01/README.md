# V2 carried-lamp integration — active, not complete

Owner reprioritized the flashlight on 2026-09-09: remove the projected-looking overlay and resume the preserved voxel/volumetric work. The preceding Mina checkpoint is `d32cbba`.

The first matched composed-world captures (`baseline`) confirmed that the photographic screen multiply darkens room fixtures and paints a ring over the image. V2 now disables that layer through the existing player API. The actual spotlight remains the logical player's lamp, with no projector texture or second switch authority.

The new V2 owner mounts bounded participating air and a 48x48x64 instantaneous optical field. `lamp_field.compute` and the shared sampling include are copied unchanged from the clean optical worktree at `4aa4585`. The field owner preserves its compute, validation, update, binding and disposal behavior; its observation argument is generalized to Node3D, two inferred locals have explicit types, and self-construction/type ownership uses its script resource instead of the editor global-class cache. A read-only adapter supplies the existing production lamp's actual pose, range, energy, color and cone. It does not advance a second electrical controller. Temporal stability currently reports stable; the accepted L1 deterministic controller/save migration is still pending.

Participating air is the first production material to use the shared optical sample. Godot's scene shadow injection handles actual mesh occlusion of the air and opaque surfaces. The custom field's eight-box analytic occlusion API is retained but is not falsely presented as a whole-building geometry adapter. Other material families, particles, near/hero material inspection and complete optical rollout remain unfinished. DreamExposureField and ecological semantics are untouched; the instantaneous field is not saved.

## Alignment correction

The inherited L1 fog setup treated a cone as Z-aligned. [Godot 4.7.1's native cone calculation](https://github.com/godotengine/godot/blob/4.7.1-stable/servers/rendering/renderer_rd/shaders/environment/volumetric_fog.glsl#L174-L185) uses local Y, with its apex at +Y. V2 now rotates that apex toward lamp +Z and places it exactly at the lens, opening down lamp -Z. Local size is 3.9x6.5x3.9 m, preserving 3.9x3.9x6.5 m world bounds. Density stays 0.034. The V2 shader derives longitudinal falloff from shared optical beam depth and samples lateral noise in native XZ. The original L1 shader remains byte-identical in `lamp_beam_fog.gdshader`; the adapted shader is `lamp_optical_air.gdshader`. No preserved optical-worktree files changed.

## Evidence and limits

`production_owner` passed nine initial native-volume checks; `warmed_abba` repeats those. `voxel_air` and `voxel_air_02` failed on adapter type inference and unavailable editor class-cache identity respectively; their hung owned test processes were verified by exact command line and parent PID before being stopped. Both failures are retained. The fixture now exits explicitly if the volume fails to compose.

`voxel_air_03` passes 16 checks with empty stderr. `voxel_air_04` passes 17, adding an explicit full GPU off-state readback outside ordinary frames. `voxel_air_05` passes 18, including the corrected native cone apex/direction. Checks cover live field injection, actual shared texture binding, no ordinary-frame GPU readback, logical off, an entirely zero RGBA16F radiance texture when off, toggling without resurrecting the overlay, lens-following pose and release of all six newly tracked owner/material/texture objects. The original isolated 157-check optical receipt is not relabeled as a V2 integration result.

The blocker sequence holds a mesh in place and toggles only its shadow-casting flag, with a repeat clear control. It visibly removes light behind the blocker. This confirms scene shadow response but is not an exhaustive volumetric-shadow, thin-transmission or material-family acceptance test. Current captures remain restrained at the legacy 0.74 lamp energy; intensity review is underway.

GPU timings use RenderingServer viewport GPU measurements, with warmup and spotlight/volume/volume/spotlight samples. They are inconsistent: even the baseline changed substantially between intervals. The initial 0.74 ms median difference is not accepted as a production performance result. Raw samples, p95 and maxima are preserved; no CPU wall time is labeled GPU time. A stable matched performance gate, full visual polish, controller/particle/material integration and final human acceptance remain open. V1 remains the building default.

`voxel_air_06.log` is the final focused run: 18 checks, zero failures, empty stderr. It includes corrected lateral noise coordinates and explicit 1.5/4.2 energy comparisons. Those brighter views improve the dark-room reach, but are review candidates, not accepted changes to the existing 0.74 production lamp setting. Captures were inspected; neither the restrained current appearance nor these energy alternatives is claimed as finished visual polish.

`composition.log` passes all 521 connected-world checks across two reconstructions with empty stderr on the final integration source. This adds composed lifecycle and room-control regression coverage, not a broader optical or performance acceptance claim.
