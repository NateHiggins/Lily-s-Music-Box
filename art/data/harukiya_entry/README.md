# Harukiya entrance source

The editable source is `art/blender/harukiya_entry.blend`; its catalogue image
paths are repository-relative. The generator is
`art/blender/scripts/build_harukiya_entry.py`, using `source_plan.json` here.

Run Blender through the shared lane with `--root <checkout> --out <private-dir>`.
The builder deliberately refuses output inside the checkout. It creates the
editable blend, three GLBs, runtime specification and construction diagnostics.
Run `art/blender/scripts/prepare_harukiya_entry.py` through the same lane with
`--root`, `--spec <generated-spec>` and `--out <private-retirement-json>` to select
only the original entrance stocks. Preserve unrelated retained-cell geometry.

Review native construction and exported derivatives before publishing named
assets and data. Save the blend to its public path through Blender with relative
image remapping, reopen it and compare meshes, UVs and image bindings. Do not
copy a private blend whose relative image paths point outside the repository.

The Godot loader preserves existing door, access, save and opening-hours owners.
Native build/packaging checks do not establish door sweep, occupied clearance,
rendered appearance or artistic acceptance. Current qualification is tracked in
HANDOFF.md and the Harukiya entrance refurbishment brief.
