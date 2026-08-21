# The generator watermark in the material sources — found, unblended, rebuilt

Owner report 2026-08-21: a repeated glyph on the 2A bedroom brick. It is the
image generator's four-point sparkle — **the same shape at the same place in
every one of its images**: ~96 px of ~40 % white, its box beginning ~190 px
in from the bottom-right corner. Because `ingest_material_sources.py` makes
each source seamless by a half-roll crossfade and derives height, normal and
roughness from the albedo, the glyph lands on every tile of every surface
built from a carrying source, in all four maps.

## The tool

`art/tools/scrub_source_watermarks.py` (`--report`, `--preview`, `--apply`,
optional file names). Detection uses what the owner said: a synthetic
concave four-point star is correlated, band-passed, against a small window
at the generator's fixed inset (three scales). Acceptance is by **measured
opacity**: a plane is fitted to the ring around the star, alpha is read per
pixel as `(observed − background) / (white − background)`, and the hit is real
when that opacity is plausible (0.12–0.75) **and** either the measured alpha
looks like the star or the file is the generator's own
(`Gemini_Generated_Image*`, plus a short list of named sources confirmed by
eye whose busy ground spoils the shape correlation — `common_brick_interior`).
Removal **unblends** rather than paints: `original = (observed − α·white) /
(1 − α)` with the per-pixel alpha floored by 70 % of its core value inside the
eroded star, then the recovered region's low frequencies are matched to the
fitted background so no faint star survives. The texture underneath is what
comes back; a hairline at the star's edge can remain on dark grounds — under
3 mm on a wall.

Run on 278 sources: **124 corner hits, 72 real and rewritten, 52 left alone**
(ChatGPT drops and dream plates whose "hit" was a bright feature with
opacity ≈ 0 or no star shape). Previews of every rewrite are written to
`art/textures/ai_sources/_scrub_preview/`; `source_previews_before_after.png`
here shows ten of the hard ones (brick, concrete, tin ceiling, bakelite, oak,
dark and saturated grounds).

## What it surfaced on the way

- The ingest's **flat-surface coarse-luma check had never run against the
  shipping cellar concrete** (the set predates the check); the first re-ingest
  refused it at 0.034 absolute. Per `TASKS.md` §D5 the absolute threshold was
  perceptually backwards, so the check is now **relative** (range / mean ≤
  0.065): concrete's real stains (6.0 %) pass on their own merits, plaster
  (0.7–1.0 %) keeps its margin, dark floors get tighter. Recorded under D5 as
  an applied default the owner may tighten.
- Windows intermittently refuses a valid texture write with `EINVAL`
  (`paper_b`, `tin_ceiling_c`) — the same fault the Blender builder already
  retries; the ingest is run with retries.

## Frames

- `bedroom_brick_before_owner_report.png` — the 2A bedroom wall as reported
  (before the finish-facing fix, bare brick with the glyph on the right).
- `bedroom_brick_after_close.png` / `bedroom_brick_zoom_before_after.png` —
  the exposed face brick under the same window after the scrub, rebuild and
  re-import: clean courses.

Pipeline after the scrub: `ingest_material_sources.py` (145 sets rewritten,
albedo/height/normal/roughness), `build_orison.py` (327 game textures),
`--import`; WalkTest FAST PASS, LightingAudit PASS, 0 script/shader errors.
Every future source drop runs the scrub before the ingest (MX-3a).
