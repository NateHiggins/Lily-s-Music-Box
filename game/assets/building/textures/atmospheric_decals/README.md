# Atmospheric bitmap library

Four 2x2 atlases provide a reusable evidence layer for the Orison. Columns and
rows are zero-based. Use `StoryDecal.setup(path, col, row, size)` for sparse
marks; use `period_patterns_atlas.png` as four source swatches for authored
materials or derived seamless crops.

| Atlas | 0,0 | 1,0 | 0,1 | 1,1 |
| --- | --- | --- | --- | --- |
| `domestic_residue_atlas.png` | coffee rings | hand/grease smear | moved-picture dust ghost | hard-water/soap tide |
| `institutional_wear_atlas.png` | shoulder/traffic rub | torn notice adhesive | threshold foot scuffs | radiator heat/nicotine plume |
| `uncanny_trace_atlas.png` | condensation almost-face | overlapping pressure shadows | impossible-loop plaster crack | elongated hand-like dust streak |
| `period_patterns_atlas.png` | oxblood hotel carpet | faded Art Deco wallpaper | speckled institutional linoleum | tobacco flame upholstery |

The `_chroma` files are retained as editable masters. Runtime code references
only the keyed PNGs. Ordinary marks should outnumber uncanny marks by at least
four to one: the strange marks work when they can initially be read as dirt,
age, damp, or tired pattern recognition.

`AtmosphericDecalPass` distributes one domestic mark per living room, two
institutional marks per occupied floor/core, and six fixed uncanny traces in
the entire building. All extracted atlas quadrants are cached by `StoryDecal`,
so repeated placements add quads but do not duplicate textures.
