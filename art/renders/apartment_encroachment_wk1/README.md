# WK-1 — the flats feel the encroachment (and the plaster that had never rendered)

Decision 3 of the 2026-08-21 ruling (`design/DREAM_ENCROACHMENT_BRIEF.md`):
the dream's generated plates reach into each case's waking apartment. Built
2026-08-21; Mina's 2A is the proving flat, all six cases are wired.

## What landed

`ApartmentEncroachment` (`game/scripts/reality/apartment_encroachment.gd`),
built by `BuildingRoot` after the domestic witnesses. Presentation only — no
case state, no save key, no collision, no light, no new draw.

- Per case with shipped plates (Mina 2A, Peter 4A, Juno 2C, Mae 6C, Cal 5B,
  Omar 3B), every baked wall-finish quad on the unit's storey whose footprint
  meets the unit rect takes `wall_encroachment.gdshader`: the **same finish**
  (albedo with the survival mask in alpha, relief normal, glTF-packed
  roughness) plus a creep of the case's first three substance plates, masked
  in world space and **clipped to the unit rect** — a perimeter quad shared
  with the neighbour changes only inside this flat. 22 finish surfaces across
  the six flats.
- The creep is the resident's language (`SIX_INCARNATIONS.md` §2 for Mina):
  the **wicking substance** (ink fibre) rising from the skirting and the
  room's corners, dried to blue-black, with thin **leader lines** in the band
  ahead of its front that stop short of the plaster they have not reached;
  where the century stripped the plaster to brick, the wick **restores the
  surface as a membrane**; **gilt** along the torn edge of the survival mask
  once the case is well along; calm pale **blanks** (erased stock) at the
  late stage. Motion is a 0.05 Hz breath in the front only.
- **Intensity** = the case's stage (`unseen` 0 → `active` 0.35 →
  `recognized` 0.6 → `integration_ready` 0.85; `stabilized` 0.45;
  `reopened` 0.9), lifted by `manifestation_intensity`, held to a 0.2 residue
  once `resolved`. It follows `RealityState.state_changed`, so a repair or a
  conversation moves the flat the same frame.
- The case's authored anomaly prop is the **beachhead**: past 0.3 its body
  wears the first plate (Mina's intercom takes her ink fibre) and gives it
  back below.
- `ENCROACH=0` disables the pass; `ENCROACH_FORCE="mina:0.8,peter:0.3"` pins
  intensities for frames and tests.

Contract: `ApartmentEncroachmentTest.tscn` **13/13** — one owner; 2A has
surfaces; six cases registered; overrides on existing quads only, each
clipped to a real unit rect; a fresh campaign shows nothing; a recognised
case raises only its own flat to 0.6; manifestation lifts, resolution
settles to 0.2; the intercom takes and gives back the plate; no save key.
WalkTest FAST PASS, LightingAudit PASS (127 spaces), 0 script/shader errors.

## The bug it found first: the plaster faced the brick

The first frames showed bare brick on 2A's bedroom wall with the pass on
*and* off, though the wall's compiled finish keeps 87 % of its plaster.
Probing `floor_02.gltf`: `build_baked_wall_finish` emitted every finish quad
with one winding per orientation regardless of `in_side` — x-walls facing
+x, y-walls facing +z — so the alpha-masked plaster on the east and the
north/south perimeter was back-face-culled from its own room. **Only
west-wall finishes had ever rendered**, on every storey. The quad now flips
with side and orientation (`build_orison.py`), the GLBs are rebuilt, and
every perimeter finish faces its room (`F02_finish_f02_w01` normal −z,
`w04`/`w06` −x, `w03`/`w09` +z). `finish_facing_before_after.png` is the
same stand before and after: bare brick becomes damp, torn, compiled plaster.
That frame is the largest single change to how the building reads that this
programme has made, and it was a one-line winding.

## Frames

`f02_a_bed_wall_off_half_full.png` and `f02_a_main_wall_off_half_full.png`:
the shipping flat (facing fixed), then Mina's case forced to 0.5 and 1.0,
from FreeCam's room framings under the flat's own fixtures and the carried
torch. At 0.5 the ink has a few fingers up from the skirting and the corners;
at 1.0 a dark tide line rises under the window and the blanks sit as pale
stains above it, with the gilt catching along the torn plaster edges. The
living-room views barely change because their visible walls are partitions
— only perimeter masonry carries a finish quad today; partitions get the
creep when they get a finish (MX-4).

## What this does not do yet

- The late-stage mirror (the case's reflected-world plate through the
  late-reflection tell) is not wired; it is a one-plate addition once the
  mirror tell exposes a material hook.
- Partition walls and floors carry no encroachment; they carry no finish
  surface to encroach on. MX-1's layered surface gives them one.
- The other five flats are wired and registered but their creep grammar is
  Mina's; each gets its own language (Peter's carbon ghosting and legal
  brass, Juno's speaker-cloth and oxidised brass, …) as a per-case mask
  recipe in the same shader.

## Addendum 2026-08-21 — the states reach the props (owner ruling)

"It should reach the props." Every script-built prop inside a case's flat
whose draw wears the layered surface (`SurfacePass`, after its deferred
sweep) takes its own copy of that material with the case's states on it:
corruption (the dream's flesh) and gilding rising with the intensity, grime
and moisture under them — `ApartmentEncroachment.reach_props`, called
through `SurfacePass.on_props_applied` after the sweep lands and again
whenever the governor's lever re-applies the tier; `refresh()` pushes the
amounts on every state change. A batched prop draw spans a storey, so the
layered surface gained a world-space clip (`state_rect`, `state_y`): a
case's states show only inside its flat, with a 15 cm soft edge. Six flats,
933 prop draws reached (135–170 each). `sheet_props_reach.jpg`: 2A with
Mina forced to 0.9 against the encroachment off — the ink at the skirting
as before, and now the radiator, the board and the frame under the window
take the same field. `ApartmentEncroachmentTest` 13/13, WalkTest PASS.

Two corrections found on the way: the surface harness restored overridden
surfaces to null rather than to the previous override, wiping the
production pass and the encroachment during its warm-up — its "current"
rows were bare StandardMaterial3D rather than "production minus this class"
(A/B deltas stand, absolute "current" numbers in the MX-1 record are the
bare material); and its "2A" stands stood in 2D — the layout's y is Godot's
−z — so the masonry frames there are 2D's walls. Both fixed; the 2A frames
here are 2A.

## Addendum 2026-08-22 — the encroachment is a state of the one surface

WK-1's grammar moved into `orison_surface.gdshaderinc` as the
`encroachment` group (`os_encroach`: the wicking plate from skirting and
corners, leader lines ahead of the front, gilt on the torn survival edge,
the late blanks; its membrane feeds the cutout's alpha beside corruption's).
`ApartmentEncroachment._material_for` now builds each finish through
`SurfacePass.surface_for` with the finish class's own recipe plus the
encroachment uniforms — so an encroached finish also carries the self-detail
tier and the standing age, and there is no second wall shader to keep in
step. `wall_encroachment.gdshader` is kept as the grammar's reference;
nothing binds it. `sheet_encroachment_recipe.jpg`: 2A with Mina forced to
0.9 through the one surface. Test 13/13, WalkTest PASS.
