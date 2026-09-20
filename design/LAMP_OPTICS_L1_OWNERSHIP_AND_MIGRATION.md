# Lamp optics L1 — ownership map and gated migration

## Authority census

| Concern | Current authority | L1 decision |
|---|---|---|
| Input, guarded switch, logical `lamp_on` | `PlayerController.set_lamp_enabled()` | Preserve. Optical presentation must not change gameplay edges. |
| Light node and beam pose | `PlayerController.flashlight` / `lamp_pose()` | Preserve public seam. Review instrument proves a future presentation component. |
| Charge/fuel | None in authoritative main | Do not invent wear, fuel, or depletion. |
| Mechanical disturbance | `PlayerController.mechanical_stimulus` | Optical component may observe shock strength; it issues no world command. |
| Warm-up, cool-down, dream gutter | `PlayerController` | Migrate presentation into `LampOpticalState` only after visual review. |
| Baked projector/cookie | Retired on main; `light_projector` is forcibly null | Keep null. `PhoneLightMask` still contains historical cookie code and a photographic screen multiply. |
| Waking atmosphere plate | `PhoneLightMask` | Candidate for retirement after the focused review; not removed broadly in L1. |
| Dream exposure and surface pose | `DreamMazeRoot`, `DreamExposureField`, dream shaders | Preserve save/behavior owners. Replace direct pose-driven decisions incrementally with observations after review. |
| Ecology decisions | `DreamFaunaDirector` and agent controllers | Preserve. Lamp emits observations only. |
| Save/reconstruction | World owners; lamp transient was not serialized | `LampOpticalState.save_state/restore_state` is complete and deterministic; wiring awaits authority review. |
| Tests | `LampCookieRenderTest`, dream irradiance/ecology suites | Keep cookie-retirement test and add deterministic state test plus focused Forward+ review. |

## Baked-image dependencies

1. `PhoneLightMask` loads three photographic plates and still multiplies them over the waking frame.
2. Its cookie branch remains dead historical code; production repeatedly forces `SpotLight3D.light_projector = null`.
3. Documentation still calls the plate treatment production behavior.
4. Several dream shaders analytically reconstruct the lamp cone from pose. This is not a cookie, but it bypasses real occlusion and must not be mistaken for optical evidence.

## Migration gate

L1 adds an opt-in `LampOpticalInstrument` and deterministic `LampOpticalState` for the focused review scene. It uses one shadow-casting spotlight, one conical `FogVolume`, one bounded `GPUParticles3D`, and a visible HDR filament. It generates observation dictionaries and never commands ecology.

After human review, the production migration is: mount the component under the existing hand/lens transform; forward the existing switch and mechanical signal; persist its state through the established world-save owner; retire the waking photographic mask; then adapt ecology sensory intake and cellular materials without moving decision ownership. No Orison geometry, selector, Open Shift, or ecology authority changes are part of L1.
