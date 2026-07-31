# Orison Environment Detail Pass

The detail pass adds building infrastructure and resident archaeology without
adding collision, lights, or unique meshes for every object.

## Shared construction history

- continuous red standpipe through the stair core
- brass pipe couplings and regularly spaced wall brackets
- electrical access panels and extinguisher cabinets on every level
- a 24-door lobby mail wall
- boiler inspection layers, standpipe instructions, lift schematics, and
  painted-over hazard notices

## Resident detail language

Every occupied unit receives:

- a uniquely colored archive/tool/domestic box
- a small paper or receipt stack
- a vessel, jar, thermos, mug, or parts container
- one wall cluster selected from domestic, shift/work, creative, or archival
  ephemera

Placement, palette, and cluster selection come from
`resident_story_details.json`. The catalog includes a prose story intention
for all eighteen residents, so future model replacements can preserve the
same characterization.

## Runtime cost

Primitive details are emitted as at most two `MultiMeshInstance3D` batches per
floor. The four resident paper textures and four infrastructure textures are
cropped once and cached, then reused by lightweight quads. Nothing in this
pass has physics, animation, audio, scripts per prop, or additional lights.

The source atlases were generated with built-in ImageGen in
`stylized-concept` mode as exact 2x2 front-facing artifact grids. Prompts
specified worn Queens building inspection/service material and tactile
resident paper clusters with restricted readable text.
