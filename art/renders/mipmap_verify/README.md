# Mipmap and glass-normal verification — 2026-08-18

Evidence for TASKS.md §MP and §DP. Both changes were claimed as fixes before
anyone had looked at a frame; this is that frame, plus the control that says
the frame means anything.

## How these were taken

```bash
SHOT_DIR=<abs> DAYNIGHT_FORCE=19:20 godot --path game res://tests/StreetShot.tscn
```

`SHOT_DIR` is required — without it `street_shot.gd:66` writes to `/street_N.png`
and fails silently. `DAYNIGHT_FORCE` accepts `HH:MM` (`day_night_director.gd:177`)
and pins the clock, or the pair differs by the hour as well as by the change.

`before/` was produced by flipping `mipmaps/generate=false` on all 119 runtime
sidecars and re-importing; `after/` is the shipped state. Restore with
`python art/tools/fix_runtime_texture_imports.py` then re-import.

## THE CONTROL, WHICH IS THE PART THAT MATTERS

Two runs of the identical build differ by **0.08–0.40% of pixels, max delta 15**.
That is the noise floor, and it is what makes the numbers below mean anything.

It was worth measuring: the first reading of the two A/Bs showed ~13.5% for
both, which looked exactly like a scene that was simply nondeterministic —
traffic moving, weather drifting — and would have made both results garbage. It
is not. The scene is essentially deterministic and both effects are 30–170×
the floor.

| test | pixels changed >4 | max delta | vs noise floor |
|---|---|---|---|
| noise floor (same build, twice) | 0.08–0.40% | 15 | — |
| mipmaps off vs on | 2.0–13.5% | 62 | 30–170× |
| glass normal flattened vs real | 7.0–14.0% | 62 | 35–175× |

## What the difference actually looks like

`mipmap_ab.png` is the densest-difference window at 3× nearest-neighbour, before
on the left. The symptom is not staircase aliasing — it is **speckle and a warm
colour bias**. Without a mip chain a minified texture does not average its
texels, so it both sparkles and drifts off its true mean colour; the joints that
should darken the average are simply missed by the sample points. With mips the
same surface is smooth and correctly averaged.

## What this does NOT establish

The window shown is street pavement, and the street's own surfaces are textured
through the glTF, which was always mipped. The change there must be arriving via
MatLib-textured street props in the same pixels rather than via the pavement
itself, and that attribution was not traced. The measurement stands — turning
mipmaps off on the 119 runtime textures changes the frame far beyond the noise
floor — but "which surface improved" is not answered here.
