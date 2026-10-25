# V2 receipt renewal, 2026-10-24

Evidence class: **INERT**

This folder archives the three V2 packets that were replaced when they were
re-earned on main 1a2f806f ("entrance gas lights operate by hand"). PRs 19,
21-29 and the vestibule PR had changed scripts and data after the previous
receipts were earned.

| Packet | Suite | Result |
|---|---|---|
| `art/renders/orison_v2/first_slice_contract_20261011/` | `orison_v2_first_slice_contract_test.tscn` | PASS, 0 failures |
| `art/renders/orison_v2/surface_requirements_20261011/` | `OrisonV2SurfaceInventory.tscn` | PASS, 0 defects (28,502 draws, 6,409 materials, 542 textures) |
| `art/renders/orison_v2/access_upper_cohort_20261018/` | `OrisonV2UpperAccessCohort.tscn` | PASS, 69 rooms |

Each suite ran windowed through `tools/lane.ps1` in a short-path checkout
after `--import`. The installed `suite_run.receipt.json` records each run.
The surface and access packets were installed by their own publishers
(`tools/publish_v2_surface_packet.py`, `tools/publish_v2_spatial_packet.py`),
which validate before and after installing. The first-slice receipt passes
`runtime_receipt_errors`.

## What had to change before the receipts could be earned

- **First-slice layout pin.** PR 19 (3fd37e0d) changed the protected
  `building_layout.json` on owner direction, unlocking the News & Cigars door.
  The pin in the test now hashes the layout LF-normalized, so CRLF and LF
  checkouts bind the same bytes.
- **Bodega frontage fixture.** It was rebound to PR 19's `door_prop.gd` by
  re-running `build_bodega_frontage.py`. The GLB is byte-identical.
- **City and paving fixtures.** These were rebound to main's layout and
  `runtime_material_sets.json` by re-running the Blender builders:
  - shells, then closure and elevations
  - ground apron, then horizon
  - street paving details

  Every GLB in `game/assets/props` is byte-identical.
- **Drapery maps.** d2543b80 added monks cloth, ninon and velour maps at
  Godot's 2D defaults, with no mipmaps, which fails RUL-012. They were given
  the V2 import policy with `art/tools/fix_runtime_texture_imports.py --v2`.

## Not done

About 130 other fixtures under `game/tests/fixtures` have stale
`source_bindings` on main, mostly shop and household prop batches. None of
the three suites checks them, and they were left alone.

## Archive

- `previous_first_slice_packet/`: the replaced first-slice receipt and logs
- `previous_surface_packet/`: the replaced surface packet (publisher archive)
- `previous_upper_packet/`: the replaced upper cohort packet (publisher archive)
