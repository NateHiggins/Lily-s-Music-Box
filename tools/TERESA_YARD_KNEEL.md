# Teresa's kneel source calibration

`python -B tools/calibrate_teresa_yard_kneel.py` verifies the current baked
work profile and independently skins the repository's actual Teresa glTF
vertices over 129 lower-body poses. It needs Python and NumPy, already used by
the source UV tools. It needs neither Godot nor Blender and works from any
directory; `--root PATH` can name another checkout.

The tool reads the motion-free body, `a_feet` and `a_bottom`, their external
buffers and skin bind matrices. It preserves the rest-measured lateral leg
angles and individual ankle footprints, solves the shin direction against
near-knee skin, and derives 33 whole-shoe lift samples. The source floor is
model-local Y=0. The intended clearance is 1 mm; endpoint knee skin must lie
between 0.9 and 1.2 mm, intermediate whole shoes/leg skin above 0.8 mm, skirt
above the floor, and individual horizontal ankle drift below 1 micrometre.
Both knees are checked separately. Unsupported source encodings fail rather
than silently dropping skin influences, morphs or sparse accessors.

The current work profile must equal the reproducible bake exactly. Angles
use six decimal degrees and lifts seven decimal metres; numerical noise is
not authored precision. The default command never writes a source or report.
`--out PATH` writes an optional **INERT**, source-only JSON report with relative
source paths, SHA-256 provenance, the baked profile and contact minima.

After an intentional body/shoe/skirt edit:

1. Run the default verification and preserve its failure/report.
2. Run `python -B tools/calibrate_teresa_yard_kneel.py --write` to regenerate
   only the work `FIT` dictionary, after all source contact checks pass.
   Inspect that named script diff; no generated glTF is edited.
3. Run `python -m unittest tools.tests.test_calibrate_teresa_yard_kneel` and
   the default verification again. A changed runtime pose recipe also needs
   its independent CPU recipe updated; mismatched declared thigh angle or
   lift interval count fails explicitly.
4. Renew the native actual-skin/morph/cloth and live-clip transition proof,
   including descent, held dialogue/gaze, click-facing suppression, reverse
   rise before travel, and actual installed S04 route/obstacle/player view.
   Follow the shared lane, patched engine, source custody and runtime receipt
   requirements in `AGENTS.md`. CPU success does not replace those checks.

`--feet b_feet --bottom b_bottom` can diagnose a future outfit without
admitting it. The current formal skirt penetrates the raw source floor by
about 127 mm; calibrated shoes do not excuse that failure. Writing a different
outfit is deliberately refused: runtime wardrobe/pose admission and native
qualification require separate review. Do not change wardrobe, hide clothing,
move the route capsule or weaken the test to obtain a passing calibration.

This is source contact verification only. It does not certify imported skin
compression, active worn morphs, runtime skirt draping, the first live-clip
handoff, skin/obstacle sweeps, storytelling, player visibility or artistic
acceptance. Runtime uses installed bones/parts/skin; it never reads raw
authoring `.gltf`/`.bin` files for admission.
