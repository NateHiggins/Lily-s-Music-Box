# The grey test

`design/DREAM_TENTACLE_BLENDER_BUILD.md`, the rule that gates the whole
programme:

> The finished Blender model should look impressive with flat grey
> materials… Shaders should reveal the anatomy. They should not be
> responsible for inventing it.

So the model is judged in flat grey clay under a raking key, a fill and a
rim — sculptor's light, nothing flattering — from ten angles including the
ruling's own explicit test (§4): **from 45° the complete sphere of the eye
must not be reconstructible.**

    "/c/Program Files/Blender Foundation/Blender 5.2/blender" -b \
        -P art/blender/scripts/build_dream_tentacle.py
    "/c/Program Files/Blender Foundation/Blender 5.2/blender" -b \
        art/blender/dream_tentacle.blend \
        -P art/blender/scripts/render_dream_tentacle_grey.py

## TB-1 / TB-2, first pass (2026-08-22)

The cage is built from **authored cross-sections, not a taper** (§1): a
broad asymmetric muscular root and shoulder, a hard compressed neck at
0.16, the ocular station swelling to 104 mm at 0.42, a flattened ribbon at
0.57, a ribbed shaft that swells and pinches, an articulated knuckle, a
dexterous narrowing and a tactile club — 150 sections × 28 around, and the
silhouette is meant to be interesting *before* subdivision.

The **orbit is cut into the flesh** (§4): a bowl displacing the cage's own
vertices, with a heavy dorsal brow, a lower cushion and lateral muscular
walls raised around it, so the socket is topology rather than a sphere
intersecting a tube.

The **§3 sculpt forms are in the geometry**, because the grey test looks at
geometry: three longitudinal muscular cords out of phase so no
cross-section is round; six authored asymmetric bulges, never mirrored,
never evenly spaced; compression folds only where the anatomy actually
narrows; longitudinal tension creases along the flanks; and a softer,
flatter ventral field where the suckers will sit.

The **ten anatomy masks** (§22) are baked as vertex colours on the cage —
`flesh_thickness`, `wetness`, `vascular`, `papilla`, `gold_root`,
`contact_sensitive`, `sucker_region`, `phase_sensitive`, `ocular_region`,
`distal_region` — so Godot never has to rediscover anatomy the model
already knows.

**Verdict, honestly.** `grey_test_sheet.jpg`. The three-quarter and profile
views now read as a muscular animal with an obvious ocular station,
compression at the neck and a club — not a hose. It does not yet pass: the
distal half is still too uniform, the folds are too shallow to catch a
raking light, and the model has none of the systems that carry the rest of
the silhouette — no gold, crystals, cilia, suckers, lids or membrane. Those
are TB-3 through TB-11, and every one of them is judged here before it is
allowed near a shader.
