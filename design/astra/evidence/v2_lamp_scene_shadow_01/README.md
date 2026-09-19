# Lamp geometry shadows, close inspection, and material transport

Base b9593d1, canonical Astra worktree. This advances the requested lighting
completion; it does not grant whole-game, anatomy, or human visual acceptance.

## Production integration

- A persistent 128x128 lamp camera renders the current World's opaque depth.
  A post-opaque compositor injects its visibility into both optical cascades.
  Moving meshes and shader-displaced geometry now carve the shared field; this
  is engine-depth injection, not solid mesh voxelization or an eight-box proxy.
- V2 and Dream both mount that owner. They use the existing lamp transform,
  range, angle and shadow-caster layer mask. Field initialization now includes
  the 96x96x128 near cascade through 0.6 m alongside the 48x48x64 room cascade.
- A two-by-two depth filter and half-cell bias control the sampled boundary.
  The field refreshes while the lamp is on so moving geometry cannot retain a
  stale shadow. A compositor pass attenuates each new field upload once; paused
  uploads are not multiplied repeatedly. Lamp-off disables the depth viewport.
- RD uniform sets and push-constant storage are cached. Ordinary shadow updates
  have no synchronous readback, file loading, new textures, or RDUniform creation.
  Explicit failure and teardown clear/release the owner, viewport, camera,
  compositor, sampler, pipeline, uniform dependencies and both field cascades.
- Shared Dream sampling now returns normalized lamp spectrum in the same fetch
  as intensity. Architecture, lineage and fauna apply it to their live response;
  native PBR consumers already receive the real lamp colour. Ecological state
  and authored emission remain separate.
- Existing membrane backlight now uses Beer-Lambert absorption in metres,
  including thinning under the existing stretch. The shared transfer helper
  also preserves the glass haze's existing path-length calculation.
- Both export presets explicitly include raw `.compute` files. Previously
  `all_resources` omitted these FileAccess-loaded shader sources. An isolated
  real export plus empty-reader negative/candidate test proves the omission
  and byte-exact inclusion of both compute programs. This is not a full game
  executable export or release acceptance.

## Scoped results

| Final run | Result | Scope |
| --- | --- | --- |
| focused_05 | 9/0 | Actual geometry shadow, movement recovery, GPU vertex deformation, translated/rotated world, 30 cm near cascade, no repeated paused attenuation, off and teardown |
| dream_03 | 47/0 | Real Dream mounting, three shared material families, geometry injection, lamp spectrum, direct/off/translation controls, legacy fallback and retirement |
| glass_01 | 22/0 | Glass shadow/energy controls and shared streamed-material lifetimes |
| ecology_01 | 16/16 | Existing ecological/gutter/gameplay invariants |
| thin_01 | PASS | Existing membrane transmits less with greater thickness |
| interior_02 | 3/0 | Sealed cloud transport, internal depth occlusion, external mesh shadow, zero added light when off |
| composed_04 | 44/0 | Actual V2 lamp, near cascade, environment ownership, profiling and all new owner/resource teardown |
| export_reader | PASS | Old filter omits compute files; fixed exported pack supplies exact source hashes from an empty reader project |

142 scoped rendering/runtime checks plus the packed-file control pass. Final
stderr files are empty. All engine runs used the unchanged exclusive serial
runner and its 180-second ceiling. Earlier passing iterations remain evidence;
export_control failed initially because the minimal fixture lacked a valid
resource and complete preset keys. export_control_02 corrects that fixture.

Focused receiver: clear/moved/transformed/deformed = 0.72549, blocked = 0;
near clear = 1, near blocked = 0, off = 0 (display red channel, not raw radiance).
Membrane display mean: thin 0.10850, thick 0.06536, authored-emission control
0.02222. Sealed volume display mean: full depth 0.25882, internal occluder
0.17255, external shadow 0, off 0. These measurements prove their stated
comparisons, not physical radiometric calibration.

## Performance and limitations

Composed forced field injection: room median 29.184 us, near median 158.208 us
(about 0.187 ms combined); separate maxima 212.416/663.904 us. The depth-view
GPU medians were 2.760, 0.795, 0.807 and 1.745 ms across enabled blocks. The
main viewport timings also vary substantially, so this packet does not infer
a clean total-effect delta from unmatched frame blocks. Both viewport time
series and the separate compute timing are retained; the near compute cost is
not hidden inside the room-only measurement. This is not a whole-game budget.

The depth view captures rendered opaque surfaces and native vertex programs.
Transparent absorption is not injected into that depth map. Native per-instance
cast-shadow flags do not redefine surface opacity in this separate camera;
shadow-only instances invisible to cameras are not captured. View-dependent
vertex programs still see that camera. The existing native spotlight remains
responsible for its own surface and atmospheric shadows. The old composed
cast/clear images toggle that native flag, not the new depth-view opacity.

`lamp_optical_interior.gdshader` implements bounded 24-step single scattering,
achromatic extinction, lamp spectrum, and opaque-scene depth termination. It
is verified in the required sealed-volume technical fixture. **It is not yet
attached to an authored creature interior.** No new organism, outer anatomy,
or interior anatomy was invented to call that integration complete. Multiple
overlapping transparent volumes and camera-inside-volume rendering are not
accepted by this fixture. Their production consumer/geometry work remains open.

The known V2 glassish furniture consumers retain the existing integration;
this work does not identify the previously mentioned green table glass.
Failed S2J remains failed/open. The light's full material/art completion and
human acceptance remain open, and V1 remains the building selector default.
