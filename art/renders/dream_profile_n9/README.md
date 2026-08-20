# N9 — Peter proves the shared profile seam

Production capture, 2560 × 1440, Godot 4.7.1 Compatibility renderer. The
harness adds no camera, light, room, geometry or environment. It places the
real dream body in a deterministic Peter-salted pocket, uses the production
service lamp and asks the production room owner to resolve one real junction
reversal.

## The four frames

- `00_pending_corridor_before.png` — the remembered bathroom-procession wall
  before Peter reverses out of the junction beyond it.
- `00b_pending_corridor_control.png` — the same build, pose and lamp one
  capture interval later. This is the live-shader negative control.
- `01_reversal_stamps_another_door.png` — the same remembered room after the
  shared profile transition. Its source, scale, footprint and all existing
  openings are unchanged; one deterministic opening has been added. The
  oxblood casing is papered with aged work forms and red decision lines. The
  forms use the project's production aged-paper texture set.
- `02_form_door_lamp_off.png` — the same new door with the service lamp off.
  The paperwork nearly disappears while the distant practical still preserves
  navigation. This is Peter's light rule in one pair: illumination reveals the
  instructions and makes the hesitation legible.

The unchanged A/A pair has mean absolute normalized delta `0.00638843`; the
control-to-door A/B has `0.0509536`, or 7.98 times the live shader floor. The
percentage of non-identical pixels is intentionally not used as an attribution
metric: the Klimt and tissue shaders animate over 27.85% of the unchanged
frame. The images establish the composition; the deterministic test proves
the cause.

## What changed, and what did not

`peter_release_print` is data in `game/data/dream_profiles.json`: campaign slot
2, a 38-second run, gradual or sudden accessible onset, Peter's borrowed
release print, Peter-specific pursuit values, the generic `junction_reverse`
attention event and the sentence **“Uncertainty does not prevent action.”**
Peter does not silently inherit Mina's hazard allowlist; later hazard content
remains separate authored work.

There is no Peter scene, director, pursuer, hazard owner or save record. The
shared root reports a real threshold crossing to `DreamRoomBuilder`; the room
owner recognises a data-authored reversal, rebuilds the same remembered room
with one additional deterministic opening, and returns only an event name.
The shared Tenant refreshes its ordinary last-known-position record when its
profile accepts that event. Mina's empty maze grammar and absent attention
event are true no-ops.

The form door owns no collision, navigation, light, sound, interaction or
per-frame callback. Frame, paper and ink are three `MultiMeshInstance3D`
submissions; a normal overlap-sealed opening adds one non-colliding false-door
leaf. Twenty-one individual paper slips remain one draw, not twenty-one.

## Proof

- `DreamProfileTest.tscn`: **28/28 PASS**. It validates both profiles, the
  exact case truth, slot/onset/run ceiling, no accidental Mina hazards, shared
  root and pursuer ownership, the real `_follow_player` bridge, exact retention
  of every remembered door, one additional opening, batched forms,
  idempotency at one threshold and Mina's no-op.
- `DreamRoomBuilderTest.tscn`: **175/175 PASS**.
- `DreamPursuitTest.tscn`: **39/39 PASS**.
- `DreamFractalRunTest.tscn`: **24/24 PASS**.
- `DreamHazardTest.tscn`: **42/42 PASS** (its deliberate no-shell warning is
  the test premise).
- `DreamAtlasTest.tscn`: **26/26 PASS**.
- `SleepPressureTest.tscn`: **20/20 PASS**; Peter's dual-form onset still
  yields to the existing Always Warn accessibility rule.
- `DreamBoundaryTest.tscn`: **39/39 PASS**.
- `WalkTest.tscn`: **FAST and FULL PASS**, exit 0, x8 / 480 Hz. The FULL log
  retains unrelated waking-world diagnostics already present on this tree:
  resident route failures, dummy-renderer null television textures and the
  safety-net's deliberately injected non-finite transform. No N9 script or
  shader error appears.

The first attempted proof is deliberately not represented here. It froze the
root's production surface/light update while moving the camera into a room the
root still considered foreign, then used a yaw sign that looked away from the
target. That produced a mostly black frame and could not support an art or
engineering claim. The final harness keeps the production update alive,
stages the authoritative current-room fact, resolves the new opening exactly
as `_follow_player` does and includes the shader-time negative control above.
