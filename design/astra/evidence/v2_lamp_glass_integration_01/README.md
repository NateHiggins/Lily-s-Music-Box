# V2 bedside glass integration

The actual source-authored `glassish` surface under `3B_abed_ns` now participates in the instantaneous lamp optical field. This is the clear bedside object, not a verified identification of the user's green glass; after the identification question the user instructed continuation.

The original high-albedo alpha material looked like a milky, bright column in the controlled flashlight close-up (`visual_01`). Its replacement is a clear dielectric with zero diffuse albedo, native GGX/specular lighting, fixed roughness and angle-dependent transparency. The engine retains room-light and shadow authority. No emission, stochastic alpha, animated distortion or screen-texture refraction is introduced. Original mesh, topology and placement remain unchanged.

A separate shared-mesh layer supplies a small thickness-dependent forward scattering response. It reads shared field visibility/transmittance and radiance occupancy; native lamp attenuation and color supply energy once. It does not replace the material's native BRDF. This is a thin-layer approximation, not ray-traced refraction, internal anatomy or a whole-building voxel shadow field.

## Binding and ownership

`lamp_optical_receivers.gd` owns V2-local receiver bindings. Render layer 20 is reserved for the added layer and illuminated only by the actual carried lamp. Existing and late-added ordinary lights exclude it; lights outside this runtime subtree are not enrolled. Teardown restores only the owned mask bit, preserving unrelated mask changes. Removed receivers immediately unbind their textures, removed lights release their records, and deferred enrollment uses weak references. A failed field hides the additional layer and refuses new bindings while leaving the native surface available.

The lamp atmosphere mounts this registry, binds the one bedside consumer when the field is ready, and disposes it before the field. Air, dust and glass use the same pair of optical textures; no third field, ecology mutation or save authority is introduced. V1 is unchanged.

## Evidence

- `material_05.log`: 13 checks, zero failures, empty stderr. A controlled receiver measures 0.069281 mean display-space brightness lit, 0 behind a real mesh blocker, the same 0.069281 after removal and after an ordinary light is added, and 0 with native lights off or the field logically off. These are screenshot samples, not calibrated physical radiance. Geometry sharing, late-light exclusion, removal/resource release, owned-bit restoration, failed-field visibility and refused late binding are covered.
- `composed_03.log`: 38 checks, zero failures, empty stderr. Includes all original field/controller/lens/off/on checks, three live material bindings and release of the new registry, material and receiver. The subsequent small failed-field guard is covered by `material_05` and actual-root startup/capture in `visual_03`.
- `visual_03`: actual bedside object, frozen world/camera/lamp/noise, native/haze/native. Ordinary lamps are off and atmospheric fog/motes hidden equally to isolate the material. Removing haze restores the exact original image. Visible draw counts are 616 / 617 / 616, with no duplicated mesh buffer. The placement record's legacy `native_surface_unchanged` name tests **mesh sharing**, not shader equality; the base glass shader was deliberately revised.
- `visual_01` records the rejected milky material; `visual_02` the clear material before adding draw-counter evidence. These are not evidence for a separate green table object.
- `material_01` is a fixture parse failure (inferred WeakRef Variant); `material_02` is a fixture assertion failure (assuming an exact default light mask rather than recording it). Both are retained. Later controls record the mask and verify preserving unrelated changes.

One added draw in one room is not full GPU-budget acceptance. The existing 0.22-0.32 ms atmosphere estimates belong to the previous packet and are not relabeled as glass cost. Original low-polygon glass geometry remains visibly faceted in this close-up. Cellular wet-film, cilia, cloud/interior-depth, gold and SSS integration still need composed consumers and review. Human material acceptance and V2 default cutover remain open.
