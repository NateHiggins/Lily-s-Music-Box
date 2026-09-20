# 4B main-room furniture: source integration

The playable V2 furniture loader now consumes the original `4B_couch` and
`4B_shelf` assemblies at named F04 anchors. The sofa is 2.46 m across its arm
extents, with cool upholstery, seam geometry and dark wood legs. The 1.10 m
bookshelf retains its oak boards, metal frame and authored book arrangement.
Their extracted meshes contain 476 and 704 triangles respectively.

Both stand along the main room's south wall, away from its west windows,
entrance, monitor stance and north kitchen/private-hall thresholds. No room,
door, window, case, clock, save or lighting authority changed. The common V2
furniture loader supplies their physical collision and material bindings.

Six book-cover families were missing from the runtime material contract.
They now resolve the catalog's existing shipped library textures at catalog
scale. All 42 prior material records and 15 visual locks are unchanged; no
textures were duplicated. The generator now validates texture availability
before writing its outputs. A missing-texture negative control confirmed that
failure leaves the generated artifacts unchanged.

## Checks completed without Godot

- Repeated pure-source assembly extraction is identical; installed meshes
  match it, and all ten existing furniture records are unchanged.
- Unique anchors, finite vertices, unit normals, supported material families
  and existing texture files pass.
- Both collision bounds fit inside the room with a conservative 0.175 m wall
  allowance. Five planned route points clear their bounds using a 0.25 m
  expanded rectangle check; an intentionally placed blocker is rejected.
- Material generation is repeatable with zero output changes on rerun.
- The earned Dream boundary harness now tracks both furnishings through
  retirement and checks their reconstruction after waking. Syntax is checked;
  these added runtime assertions have **not** been executed.

Source: `art/blender/scripts/build_orison.py` and the exact 4B records in
`game/data/building_layout.json`. Rebuild using
`python design/astra/work/v2_4b_main_furnishing_01/extract.py`, then run
`python design/astra/work/v2_4b_main_furnishing_01/verify.py`.
The extraction receipt records source hashes; `source_checks.json` records
bounds, route points and texture hashes.

**Runtime and visual validation pending at the owner's request.** Godot was
not launched. The source route calculation is not a played collision route,
and this does not establish final room presentation, GPU residency cost,
whole-game performance or V2 release readiness. Next engine session should
run the earned boundary/played Dream regression and walk/capture the main-room
route, including bookshelf readability and material loading.
