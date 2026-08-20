# Dream rendering R6 — one impossible view, zero new space

R6 proves the smallest useful portal claim in the production dream. At the
existing R4 wound, retained high exposure replaces the central false tunnel
with a live view of another room already present in the bounded dream pocket.
The image is rotated one deterministic odd quarter-turn. The lath, torn
plaster, living rim and R4 false-depth lattice remain visible around it, so it
reads as a violated wall rather than a second screen.

This checkpoint does **not** build enterable space or RECURSION. R7 remains the
separate owner decision for either escalation.

## Production ownership

- `DreamAtlas` and `DreamRoomBuilder` remain the only topology owners.
  `DreamRoomBuilder.view_fault()` selects the first real live destination in
  the source room's authored door order and returns a pure rendering record.
- The destination is an already-live, already-rendered room. The request adds
  no room, graph edge, door, navigation state, persistence fact or lifetime.
- `DreamViewPortal` is one 384 × 672 `SubViewport`, one `Camera3D`, and no
  other node. It shares the production `World3D` (`own_world_3d=false`). It
  owns no geometry, light, sound, collision, interaction, damage or hazard.
- `DreamHazard` remains the danger owner. The wound remains one surface in the
  existing batched growth mesh. The authoritative Atlas wall and its collision
  stay intact; a physics ray still hits it after the view opens.
- The growth surface occupies presentation layer 20. The main camera sees that
  layer; the portal camera excludes it. The feed therefore cannot see the
  surface that samples the feed. Its explicit recursion depth and maximum
  recursion depth are both zero.
- The portal sleeps below retained exposure 0.88→0.98, beyond 14 m, outside
  the frustum, or from the wall's wrong side. Otherwise it follows the main
  camera with bounded parallax while keeping its authored destination and
  90°/270° image roll.
- Destination readability is a camera-local rendering grade selected through
  `CAMERA_VISIBLE_LAYERS`. It changes existing material output only for the
  layer-20-excluding portal camera. It does not place a helper light or alter
  the room state the player could later enter.

## Evidence

The permanent proof sets are:

- `00_control_r5_tunnel/` — R5 false-depth control with the R6 consumer off.
- `01_view_portal/` — production view-only portal at the same pose and phase.
- `02_portal_id/` — cyan isolates portal ownership and aperture coverage.
- `03_depth_zero/` — blue reports the only permitted recursive depth: zero.
- `04_final_1440p/` — final 2560-wide production frames plus the portal
  camera's raw 384 × 672 feed for source verification.

All sets contain lamp-on, motion, and lamp-off/dark-live frames. The final
camera records the deterministic fault `@2.2.0 -> @2.2` with a 270° image roll
for this seed. The destination is a real furnished Orison hall visible in the
same `World3D`, not a test card or helper-room reconstruction.

## Measured price

Fresh-process measurements used the exact aperture-facing station at retained
high exposure, 2560 × 1421, with the production clock pinned. The control set
`DREAM_VIEW_PORTAL_OFF=1`; all other state was identical.

| state | objects / calls | control ms | portal ms | delta |
|---|---:|---:|---:|---:|
| lamp off | 12 / 12 → 194 / 194 | 2.01 | 2.19 | +0.18 ms |
| lamp on | 21 / 21 → 221 / 221 | 2.01 | 2.30 | +0.29 ms |

All four rows remain below 16.6 ms. The added submissions are the already-live
destination room rendered once into the bounded target; there is no hidden
recursive pass.

## Verification

- `DreamSurfaceTargetTest`: **92/92 PASS**, including 21 R6 ownership,
  lifecycle, render-layer, no-recursion and wall-collision checks.
- `DreamRoomBuilderTest`: **175/175 PASS**.
- `DreamHazardTest`: **42 checks, PASS**.
- `DreamLineageTest`: **21/21 PASS**.
- `DreamAtlasTest`: **26/26 PASS**.
- `DreamFractalRunTest`: **24/24 PASS**.
- `WalkTest` FAST and FULL: **PASS** at x8 / 480 Hz. Both retain the project's
  pre-existing logged diagnostics; R6 introduces no new error path.

## Corrected readings during the pass

1. The breach normal points into its Atlas room. The first half-space test was
   reversed, so the viewport correctly slept rather than proving a black feed.
2. A valid feed remained black until its `SubViewport` was deliberately woken;
   the renderer now updates only when the view is useful at high exposure.
3. The destination's dream materials are analytical to the player's inspection
   lamp. A remote camera cannot carry that lamp, and camera exposure alone did
   not recover photographed material separation. The bounded camera-pass grade
   solves that without inventing a world light.
4. The capture harness freezes physics immediately after teleporting. It now
   advances the existing receding practical once before freeze, matching the
   production room state rather than manufacturing a shot-only lamp.

R6 has answered the view-only question. It has not answered whether recursion
depth one, an enterable fault, or either one's gameplay is worth owning. That
is R7.
