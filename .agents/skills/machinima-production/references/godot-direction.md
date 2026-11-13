# Godot direction contracts

Use [godot-development](../../godot-development/SKILL.md) and current repository
rules. These are implementation patterns for an authorized scene change, not a
request to install a new director, parser, AnimationTree or camera framework.
Inspect the patched engine and actual owners before choosing APIs.

## Reuse the current architecture

First map existing camera/controller, scene director, dialogue, pose/face writers,
audio buses, save lifecycle and timeline evaluator. This game's source entry
points include `game/scripts/game/prologue_director.gd`,
`game/scripts/game/temporal_loop.gd`,
`game/scripts/building/orison_v2_loop_stage.gd`,
`game/scripts/characters/resident_agenda.gd` and
`game/scripts/characters/cast_model_presentation.gd`. Their presence is not proof
that a proposed scene mode or skip policy exists. Read the relevant call chain.

Separate authority, orchestration and presentation:

- The existing game owner validates and commits its own state under its current
  contract; it supplies the scene context and handles terminal results.
- The coordinator acquires/releases control and selects the authorized event.
- Camera rigs, markers and authored/procedural tracks present it. Borrow real
  actor instances where appropriate; don't clone gameplay identity or reparent
  existing actors merely to match an example node tree.
- The recorder evaluates selected poses and captures completed frames. It does
  not own game truth or prove real-time performance.

A useful conceptual grouping is director → camera rig/aim target, actor/prop
marks, performance tracks, spatial sound and subtitle presenter. Existing
private film fixtures may already provide all of these without AnimationPlayer.

## Timing and ownership

Use the [capture guide](capture-and-delivery.md) for integer output frames and
absolute movie time. Gameplay retains its civil, visit and monotonic clocks.
Audio cues bind measured samples and selected takes. Seeking to a nonzero time
must reconstruct current presentation without replaying owner mutations.

AnimationPlayer is suitable for fixed authored tracks; AnimationTree may blend
existing clips with gaze, breathing and locomotion when supported. Do not have
both independently drive playback of the same actor. Order root placement,
posture, bounded gaze/contact and face evaluation consistently. Procedural motion
must remain reproducible at pickup/section boundaries.

For control takeover, use an explicit lifecycle in the existing coordinator:
idle → prepare → run/interactive pause → finalize or recover → release.
Track a per-run identity, acquired resources, committed owner result and terminal
outcome. Cleanup must work after partial preparation, repeated skip, missing
assets and unload, as well as normal end. Clear the old run before external
notifications can start a new one; late callbacks cannot finish a newer run.

`AnimationPlayer.seek()` skips intervening events; seeking to the end does not
emit the usual completion signal. Do not use it as a substitute for explicit
terminal-state logic or quest transactions. Verify the installed version's
behavior against the [official AnimationPlayer reference](https://docs.godotengine.org/en/stable/classes/class_animationplayer.html#class-animationplayer-method-seek).
The supplied package's small coordinator was illustrative and was not installed.

## Optics with explicit units

Record lens intent separately from actual engine projection. For a perspective
camera with a declared 36 mm horizontal gate and aspect `a = width / height`:

```text
horizontal_fov_deg = degrees(2 * atan(36 / (2 * focal_length_mm)))
sensor_height_mm = 36 / a
vertical_fov_deg = degrees(2 * atan(sensor_height_mm / (2 * focal_length_mm)))
```

At 16:9 the vertical gate is 20.25 mm: 28/35/50/85 mm give approximately
39.76/32.27/22.90/13.59 degrees vertically. With `Camera3D.KEEP_HEIGHT`, `fov`
is vertical; with `KEEP_WIDTH`, it is horizontal. Set and record the aspect mode
explicitly. Confirm projection and viewport against the
[official Camera3D reference](https://docs.godotengine.org/en/stable/classes/class_camera3d.html#class-camera3d-property-fov).
These formulas do not apply unchanged to orthographic projection or a different
sensor gate. A physical camera-attributes resource may own optical values;
inspect that binding before assigning overrides.

When changing ratio, state whether the physical gate is recropped or a fixed
vertical FOV is preserved. Don't silently recompute both. Verify subject distance,
headroom, near clip, camera obstructions and playable affordances in the actual
render. Lens equivalence alone does not establish the desired composition.

Use the [adopted style](neo-noir-neon-1929.md) for exposure/shutter, diffusion and
focus intent. Unavailable physical effects remain disclosed approximations.
No global FOV, clock, postprocess or input change follows from a film setting.

## Authoring data and proof

The [manifest example](../assets/shot-manifest.example.json) is interchange data,
not a runtime schema. Extend a working director's existing edit format where
possible. If a loader is actually needed, validate resource/actor IDs, finite
times, ordered ranges, pose dependencies, owner operations and terminal policy.
Don't evaluate arbitrary commands from a manifest or call a parser installed
without an actual consumer.

Keep captions/line IDs with their dialogue owner, spatial sounds with current bus
and attenuation conventions, and source/destination ambience with the owning
transition. Generated backgrounds contain no lettering (RUL-008); exact text
uses authored UI or the existing diegetic Label3D/printing system.

Use proportional checks: static data/reference checks; bounded lifecycle tests;
then rendered contact, face, light, camera and sound review. For an interactive
change exercise early/middle/late skip, duplicate skip, cancellation, reload,
repeat entry and control restoration where those paths exist. Include relevant
knowledge, time/weather, viewport and quality variants rather than an unrelated
whole-game matrix. Record unsupported paths honestly.

All native Godot/GPU proofs retain the shared FIFO, hidden desktop, patched
engine, receipts and frozen-input rules. Use bounded captures, not direct
Movie Maker launches outside the lane. Offline capture timing is not a gameplay
frame-time benchmark. Documentation-only integration requires skill/data checks,
not a ceremonial engine run.
