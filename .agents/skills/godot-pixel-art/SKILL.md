---
name: godot-pixel-art
description: Author, animate, integrate and review low-resolution Godot sprites, glyphs and physical pixel displays. Use for intentional pixel art and tile-face reactions; use the texture/shader skill for PBR surfaces and sampling defects.
---

# Readable shapes, bounded animation

Read the active project's instructions, actual display owner, palette, dimensions,
source data and intended viewing conditions. Preserve its visual language and
input/state authorities. In Orison follow DOCS.md, AGENTS.md and the Bible;
use [Godot development](../godot-development/SKILL.md) for runtime verification
and [textures/shaders](../godot-textures-and-shaders/SKILL.md) for sampling.

## Author at the real resolution

Start with silhouette, eye/mouth separation, negative space and a small deliberate
palette. Review at native size and the actual in-game projected size. Detail that
only reads enlarged is not established at its intended distance. Keep glyphs and
illustrations editable in the existing data format; reuse existing art families
rather than introduce another atlas or animation owner. Keep reference images
separate from production assets and follow the project's lettering rules.

Match sampling to the medium. Screen-space pixel art may need nearest filtering,
integer scaling and pixel-aligned placement. World sprites need minification and
motion review. Physical tiles are geometry: use their existing materials and
batches. Orison world PBR maps retain authored UVs and loaded mipmaps; a pixel-art
request does not waive those requirements.

## Animate through the existing owner

Use purposeful key poses and authored holds, with an explicit loop or completion.
Hold a physical display's image after its moving tiles actually settle. Preserve
readability during transitions and avoid excessive full-image changes. Reuse the
existing per-frame change budget; do not add a node per pixel or another viewport
without measured need. Test low/high frame rates and backlog recovery.

Connect mouth activity to real printing/speech progress, gaze to the existing
presentation state, and emotional clips to witnessed context. Keep finite clips,
idle animation, keyboard opening, story presentation, pause and power ownership
explicit so one presenter cannot overwrite another. Preserve cancellation and
return-to-idle behavior. Chatter and sound need their own existing owners.

## Inspect the result

Render neutral and emotional poses, motion and interruptions at actual camera
framing, exposure, glazing and background. For image comparisons declare the
subject crop, repeat an unchanged A/A control and include a known hidden or
incorrect control. Whole-frame colour counts can miss a tiny subject or include
unrelated hardware. Technical checks and readable frames remain distinct from
owner acceptance of personality, humor and timing.

Orison's existing example is the32x12 two-colour companion face:
`game/data/device/companion_face_reactions.json`, `companion_face_player.gd`,
`companion_tile_display.gd` and `CompanionFaceBench.tscn`. Its current32 active
flips/64 transform writes per step are project-specific measured constraints,
not universal pixel-art budgets. See the original failures, rendered review and
limits in [the prologue ledger](../../../design/V2_PROLOGUE_2026-10-28.md) and
[face-reaction notes](../../../design/V2_COMPANION_FACE_REACTIONS_2026-10-25.md).
Update this skill with demonstrated lessons; keep detailed receipts in those
owners instead of appending a session diary here.


For physical segmented readouts, keep row/digit/segment identity separate from
preview colours. Use one batch and update masks only when authoritative content
changes. Preserve UNKNOWN instead of inventing timestamps; an all-eights factory
pattern is not gameplay data. Shared corners may need triangle-level semantic
binding; route that work through the texture/shader skill. Inspect native-sized
frames through the actual glazing, observer and power/pose owner. Keep the face's
ongoing expression owner separate from a temporal register's accepted-jump state.
