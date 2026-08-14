# Orison Animated Resident Cast

**STATUS 2026-08-14: the generated low-poly bodies this doc's pipeline
built are retired** — the cast repopulation replaced them with raw-dump
hero conversions plus personal baked move libraries (see
`mina_character_pipeline.md`). The table below survives as the
characterization brief: it is the authored motion identity each
resident's REAL animation set must express when the owner generates the
production rigging/animation pass, and it remains the source of the
per-resident motion signatures in `resident_animation_profiles.json`.

All 18 residents use the same reproducible low-poly production language and IK
rig contract, but have individual palettes, proportions, idle performance, and
walk mechanics. Their animation is characterization rather than neutral motion.

| Resident | Animation storytelling |
|---|---|
| Evelyn Marsh | Corrects invisible papers and walks with controlled teacherly precision. |
| Teresa Vale | Holds an exhausted triage posture and takes careful steps anticipating another alarm. |
| Mina Vale | Makes furtive glances and captioning gestures, then paces quickly when self-conscious. |
| Lena Ortiz | Continually stitches and mends with her hands; her weighted walk suggests carrying everyone else. |
| Juno Kells | Keeps an internal beat through asymmetric hands and a syncopated, bouncing stride. |
| Malcolm Reed | Tends an imaginary plant with gentle hands and walks as if rooted by grief. |
| Omar Bell | Checks an imaginary tool in each hand and places every step as though it may require repair. |
| Rhea Sato | Uses controlled singer's breathing that expands into performance-sized movement. |
| Peter Wren | Straightens invisible forms, scans nervously, and advances in small uncertain steps. |
| Cam Ortiz | Never becomes fully still; uses a fast courier stride, high feet, and restless bounce. |
| Noel Price | Maintains museum-handler stillness, precise hands, and artifact-safe measured steps. |
| Transient Guests | Sways with jet lag and walks hesitantly as though the assigned room keeps changing. |
| Nadia Quell | Drafts square angles in the air and walks in sharply controlled, code-compliant lines. |
| Cal Dwyer | Cocks his head toward unheard broadcasts while his body moves half a beat late. |
| Iris Bell | Paints broadly in the air and walks with an expressive, color-seeking lateral sway. |
| Sacha Reed | Holds camera-steady hands, scans for evidence, and moves with purposeful witness momentum. |
| Jonah Price | Writes, pauses, and loses the next word; even his walk feels softly interrupted. |
| Mae Kessler | Handles invisible archives defensively and walks with exact provenance-conscious care. |

## Pipeline

`tools/generate_resident_cast.py` contains the authoritative cast profiles and
invokes Blender 3.6 once per resident. `tools/generate_mina_character.py` is the
shared mesh, material, armature, IK, baking, preview, source-save, and GLB-export
pipeline retained under its original filename for compatibility.

Each character directory contains:

- an editable Blender source;
- a production GLB with a skin and two baked actions;
- a 512 × 640 visual QA preview.

Every idle action is 80 frames at 30 fps. Every walking action is a cyclic
32-frame IK-foot loop. The profile controls sway, gaze, hand amplitude, posture,
stride, foot lift, body bounce, arm counter-swing, body width, head proportion,
and the six-color costume palette.

Godot's `AnimatedResident` selects clips by `idle` and `walk` suffix, preserving
individual action names. Residents idle normally, use their authored walk while
their manifestation is active or reopened, and crossfade back to idle after
stabilization. Sprite residents remain available only as a missing-asset
fallback.
