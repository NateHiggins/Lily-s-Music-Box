# Dream embrace — production proof

**Landed 2026-08-20.** This directory proves the ordinary capture presentation
specified in `design/THE_TENANT.md`. It does not implement friendship, romance,
dialogue or the later chosen meaning of the same event.

## The production sequence

`DreamMazeRoot._on_captured()` now latches pursuit immediately, then asks one
`DreamEmbrace` owner to perform a 1.50-second monotonic close and a 0.18-second
held final frame before the existing `capture` outcome is committed.

- One inward-facing sphere, radius 0.68 m, belongs to the existing player
  camera. Its fragment frontier advances from every screen edge toward the
  centre. Nothing enters along an axis, no camera changes and there is no
  strobe.
- The player body stops and the crosshair/telegram HUD hides. The shell adds no
  collision, `Area3D`, hazard, navigation, topology, input verb, light or
  camera.
- One uniform closes every authored eye in the existing single hazard surface
  before the central view disappears. No lid node or draw was added.
- The current case signature plays from an ordinary non-spatial
  `AudioStreamPlayer`: the ruled fifth position is inside the listener. A
  temporary Master-bus low-pass and short reverb make the room close and warm;
  teardown removes only those two effects.
- The Tenant never touches the switch. Ordinary capture enters with the service
  lamp on and reveals burnished plum/gold. A later chosen embrace may enter
  after the player deliberately turns it off; the same shell preserves OFF and
  retains only a faint wine-dark biological afterglow. “The lamp stays yours”
  resolves the earlier literal “stays lit” wording without rebuilding the
  event.

The outcome vocabulary remains exactly `capture`, `fall`, `contact`; the
existing DreamDirector and 4B wake/residue boundary remain authoritative.

## Refinement ruling

The useful suggestions from the procedural-shader review were adopted at the
scale this effect can support: local-3D multi-scale cells, tendon folds,
microfolds and wet-film motion share the established corruption genome, while
irregular cell boundaries provide fine capillaries without a UV or polar seam.
The fields evolve slowly with `TIME`; there is no flashing-frequency motion.

The 0.68 m capture shell is deliberately lamp-gated and exposure-owned rather
than conventionally PBR-lit. Rendered controls showed that putting the real
SpotLight3D inside a sub-metre PBR sphere bleached even very dark albedo to flat
parchment. Tangent-derived normals and vertex displacement disclosed a triangle
lattice, and the shared long-vessel field disclosed three coordinate families
from inside the sphere. POM, particles, decals and additional eye impostors were
also rejected here: none earns a new interaction or owner during a 1.68-second
terminal presentation. Room growth keeps its ordinary PBR and world light.

## Plates

`production_1440p/` contains six production frames at the 2560 × 1440 request
(Godot's window client saved 2560 × 1421):

1. `00_room_before_capture.png` — the same target pocket before presentation.
2. `01_gold_at_every_edge.png` — first simultaneous contact on all edges.
3. `02_no_direction.png` — the irregular frontier closes without an attacker.
4. `03_eyes_closed.png` — eye closure is visible before the centre disappears.
5. `04_lamp_inside_gold.png` — final ordinary-capture frame, chosen lamp ON.
6. `05_chosen_lamp_stays_off.png` — same production owner, chosen lamp OFF.

`coverage_debug/` replaces the shell with an exact coverage ID so the
edge-to-centre topology can be inspected independently of its material.
`eye_close_debug/` uses the existing eye-family diagnostic while exercising the
same stages. Generate them with `DREAM_EMBRACE_DEBUG=1` and
`DREAM_EYE_DEBUG=1`, respectively, through `DreamEmbraceShot.tscn`.

## Measured price

Fresh real-window runs, 2560 × 1421, production seed and 64/16 light/shadow
budgets:

| station | control objects/calls | control ms | full embrace objects/calls | full embrace ms |
|---|---:|---:|---:|---:|
| waking room, lamp off | 87 / 87 | 1.99 | 79 / 79 | 1.61 |
| waking room, lamp on | 87 / 87 | 2.00 | 79 / 79 | 1.00 |
| deep pocket, lamp off | 133 / 133 | 2.09 | 127 / 127 | 0.88 |
| deep pocket, lamp on | 172 / 172 | 2.23 | 151 / 151 | 0.93 |

The presentation adds one geometry instance and one shader. At full coverage it
occludes the costlier room rather than accumulating over it; all eight rows are
under the 16.6 ms gate. Reproduce the second run with
`PERF_DREAM=1 PERF_DREAM_EMBRACE=1` and `game/tests/Perf.tscn`.

## Contracts

- `DreamEmbraceTest.tscn`: 31/31 — single owner, monotonic timing, no gameplay
  additions, body/HUD lock, lamp ON/OFF preservation, eye closure, fifth
  position, exact bus-effect ownership and delayed outcome.
- `DreamPursuitTest.tscn`, `DreamSurfaceTargetTest.tscn`,
  `DreamRoomBuilderTest.tscn`, `DreamHazardTest.tscn`,
  `DreamLineageTest.tscn`: production owner regressions.
- `WalkTest.tscn` FAST and FULL x8/480: integration boundary.

Only the ordinary capture presentation is built. The same geometry, timing and
acoustics can be re-meant later if friendship/romance earns the chosen path;
this checkpoint does not invent its gates.
