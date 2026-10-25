# V2 receipt renewal, 2026-10-25

Evidence class: **INERT**

This folder archives the three V2 packets that were replaced when they were
re-earned on main 862e54a2 together with the fixture rebind on this branch.
The 2026-10-24 renewal (PR 31) had been expired by PR 32 (editorials) and
the house gas service merge.

| Packet | Suite | Result |
|---|---|---|
| `art/renders/orison_v2/first_slice_contract_20261011/` | `orison_v2_first_slice_contract_test.tscn` | PASS, 0 failures |
| `art/renders/orison_v2/surface_requirements_20261011/` | `OrisonV2SurfaceInventory.tscn` | PASS, 0 defects (28,507 draws) |
| `art/renders/orison_v2/access_upper_cohort_20261018/` | `OrisonV2UpperAccessCohort.tscn` | PASS, 69 rooms |

`OrisonV2BarGalleryTest.tscn` also passed on the re-fitted gallery.

## Fixture rebind

93 of the 94 fixtures under `game/tests/fixtures` whose `source_bindings`
were stale were rebound by re-running each fixture's own Blender builder,
upstream first.

- **Re-pinned plans.** Five builders stop when their authority changes. Each
  change was reviewed before the plan was re-pinned:
  - `light_fixture_prop.gd`, `fridge_prop.gd`, `stove_prop.gd` and
    `house_switchboard_prop.gd` changed only at runtime: direct manipulation,
    materials and the V2 native switchboard branch. The geometry the
    builders mirror is unchanged.
  - Photo stock now takes `book_ochre` and `book_teal` from the catalogue,
    following 295836f2's calibrated book stock.
- **Bar fits.** The bar gallery and stage source fits were regenerated from
  fresh windowed WallArtLaw probes. The gallery law re-placed most west-wall
  pictures.
- **Builder fix.** `build_fixed_lighting.py` now writes resolved buffer
  paths. Before, it wrote a `../..` path that the preflight refuses.
- **GLBs.** Six GLBs changed:
  - `bar_gallery`: the re-fit
  - the two roof drainage weather sets: current roof grade
  - `bar_pool` and `cobbler_fittings`: tangent handedness from the current
    `fabrication_normals.py`
  - `basement_airer`: float rounding only

## Not done

- **Heating distribution.** `orison_heating_distribution.json` stays stale.
  No committed script writes it, and `build_heating_refit.py` only writes a
  scratch build.
- **WallArtLaw and fittings.** The law treats only physics colliders as
  blockers. Sconces have none, so one west-wall picture hangs behind a
  sconce.
- **Headless bar fit.** The bar gallery fit probe fails headless because
  the front trim pose check refuses the world. It passes windowed.

## Archive

- `previous_first_slice_packet/`: the replaced first-slice receipt and logs
- `previous_surface_packet/`: the replaced surface packet
- `previous_upper_packet/`: the replaced upper cohort packet
