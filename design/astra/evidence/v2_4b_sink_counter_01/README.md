# 4B supported compact kitchen sink

Added `4B_sink_counter` and `F04_4B_KITCHEN_SINK_01` to the existing V2
furniture/fitting pipelines. The counter reuses all four authored 4B worktop
pieces relative to the original sink centre. A new open wood support frame
carries the top to the floor. It does not introduce decorative cabinet doors
that imply an unavailable interaction. The assembly has 144 triangles.

The compact TapProp retains the authored 500 x 380 mm basin, no drainboard,
4B unit and existing valve/stopper behavior. Its new anchor coincides with the
counter cutout. BoilerTend discovers it alongside the other mounted TapProps;
the hot-water harness derives expected membership from the fitting data.

The countertop material now uses its existing catalog mapping and shipped
albedo, roughness and normal maps. All 49 prior material records remain
unchanged. The V2 furniture validator now admits the explicit `counter` kind;
the existing mesh, material, collision and adapter lifecycle handle it.

Source checks pass for byte-identical repeated generation, clockwise triangle
winding, clear visual bowl interior, outer-wall and approach clearance,
preservation of prior furniture/fitting/material records, and GDScript syntax.
The earned boundary harness checks the counter, compact sink settings and live
boiler membership after wake. Those assertions have not run.

Rebuild with `python design/astra/work/v2_4b_sink_counter_01/build.py`, then
`python art/tools/generate_runtime_materials.py`. The assembly record retains
the original worktop records, source hash, new frame blocks and anchors.

**No Godot was launched, per owner instruction.** Source bowl clearance refers
to visible mesh geometry; the furniture retains the loader's coarse solid
collision bounds. Sink ray targeting over the counter, physical route, faucet
use, retirement, material loading and appearance need engine validation.
Kitchen lighting, final pipe presentation and full water-network/persistence
integration remain open. This is source integration, not kitchen or V2 release
acceptance.
