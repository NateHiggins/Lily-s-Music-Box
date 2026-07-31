# Character Memory Art

Five AI-generated production atlases provide 20 framed memories across all 18
resident spaces. Existing character concept portraits were supplied as identity
references. The images intentionally show ordinary moments before or outside
the manifestations, giving each resident a life that is larger than their
trauma.

| Apartment | Memory |
|---|---|
| 1A | Evelyn's faded retirement class photograph |
| 1D | Teresa at the end of a 4:30 AM hospital shift |
| 2A | Mina concentrating at her captioning desk |
| 2B | Lena's oil-painted visible family-quilt repair |
| 2C | Juno laughing when a late-night studio session finally worked |
| 3A | Malcolm holding a successfully propagated cutting |
| 3B | Omar testing a radio he repaired |
| 3D | Rhea taking a centering breath before a performance |
| 4A | Peter submitting an important imperfect form |
| 4C | Cam completing a difficult courier delivery |
| 4C | Noel correctly returning an artifact to its box |
| 4D | The Transient Guests on a trip when they felt safely located |
| 5A | Nadia listening while presenting a tenant-protecting plan |
| 5B | Cal receiving a distant human radio signal |
| 5C | Iris's expressive painted self-portrait |
| 6A | Sacha lowering the camera to witness someone directly |
| 6B | Jonah paused over unfinished words |
| 6B | A private watercolor of Jonah listening |
| 6C | Mae holding an inherited box without opening it |
| 6C | A private painted portrait of younger Mae cataloging family history |

Wall pieces use 72-centimeter generated frames. Jonah's watercolor and Mae's
younger portrait use 34-centimeter tabletop frames with freestanding bases.
Frame color and surface roughness vary for photographs, Polaroids, watercolors,
and oil paintings.

The authoritative placement catalog is
`res://data/character_memory_art.json`. `CharacterMemoryArt` selects a quadrant
from the appropriate source atlas at runtime, avoiding duplicate texture memory
or destructive crops.

## Generation prompts

The five built-in image-generation prompts used the
`photorealistic-natural` or mixed `photorealistic-natural` /
`illustration-story` taxonomy. Every prompt requested:

- an exact 2 × 2 atlas with dark gutters;
- identity preservation from named concept references;
- one explicit character-defining scene per panel;
- authentic print aging, fingerprints, fading, or medium-specific wear;
- emotionally sincere ordinary life without paranormal effects;
- no captions, logos, or watermark.

Panel-specific scene descriptions are preserved in the corresponding placement
names and inventory above. The production atlases live under
`res://assets/building/textures/character_memories/`.
