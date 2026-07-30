# Orison Apartments — Character Art Bible

These four boards are the visual source of truth for the current named cast.
Read every board left to right. The pale strips are intentionally blank so
the images remain useful in layout, pitch, and modeling contexts without
AI-rendered pseudo-type.

## Board index

| Board | Columns, left to right |
|---|---|
| `orison_cast_board_01_core.png` | Player; Mara Chen; Mina Vale; Juno Kells; Omar Bell |
| `orison_cast_board_02_heroes.png` | Rhea Sato; Nadia Quell; Sacha Reed; Cam Ortiz; Noel Price |
| `orison_cast_board_03_residents_a.png` | Evelyn Marsh; Teresa Vale; Lena Ortiz; Malcolm Reed; Peter Wren |
| `orison_cast_board_04_residents_b.png` | Cal Dwyer; Iris Bell; Jonah Price; Mae Kessler; Transient Guest pair |

The transient guests are recurring anonymous occupants, deliberately treated
as a replaceable pair rather than permanent Orison residents.

## Reproducible 3D target

The target is **grounded stylized realism**, built to survive the project's
Compatibility renderer:

- realistic adult proportions with slightly simplified facial planes;
- 22–30k triangles for a primary resident, 14–20k for supporting residents;
- one shared humanoid rig and one shared base topology;
- separate head, hair, upper garment, lower garment, shoes, and signature prop;
- modeled hair clumps for the silhouette, with hair cards only at the hairline;
- no simulated garments, dangling chains, or layered transparent fabric;
- one 2K body/face set for heroes, one 1K set for supporting characters;
- packed ORM plus albedo and normal; no subsurface dependency;
- rough skin, cloth, canvas, wool, leather, and aged plastic tuned for the
  existing low-light material system;
- four facial blend shapes at minimum: blink, jaw open, concern, and suspicion;
- restrained idle motion: breathing, weight shift, eye darts, and listening;
- LOD1 at roughly 55% triangles and LOD2 at 20%.

## Silhouette and narrative rule

Every resident must remain identifiable in corridor darkness by three things:

1. body/posture silhouette;
2. one garment color family;
3. one occupational or domestic prop.

Do not increase accessory count to add personality. Wear, repair, fit, posture,
and the way a character holds one useful object should carry the story.

## Character production notes

| Character | Unit / role | Modeling anchors |
|---|---|---|
| Player | 4B, night support worker | Androgynous base; charcoal hoodie; headset; exhausted guarded posture |
| Mara Chen | Case 01 caller | Rust cardigan; phone; listening pose; anxious eye line |
| Mina Vale | 2A, caption editor | Ochre mock-neck; square glasses; precise stationery kit |
| Juno Kells | 2C, audio artist | Asymmetric crop; washed black volume; headphones and recorder |
| Omar Bell | 3B, repair technician | Broad apron silhouette; mustache; categorized hand tools |
| Rhea Sato | 3D, vocal coach | Severe bob; green blouse; tuning fork; controlled upright stance |
| Nadia Quell | 5A, architect | Long braid; inked vest; plans and scale; angular silhouette |
| Sacha Reed | 6A, investigator | Lanky track-jacket silhouette; camera; tangled adapters |
| Cam Ortiz | 4C, bicycle courier | Maroon shell; messenger bag; compact athletic posture |
| Noel Price | 4C, museum preparator | Indigo chore coat; archival gloves; practical work trousers |
| Evelyn Marsh | 1A, retired teacher | Plum cardigan; glasses chain; red pencil; dignified posture |
| Teresa Vale | 1D, night nurse | Navy scrubs; camel coat; thermos; compressed tired stance |
| Lena Ortiz | 2B, seamstress | Burgundy knit; work apron; tape measure; shears |
| Malcolm Reed | 3A, horticulturist | Tall moss silhouette; gloves; clipping shears; propagated plant |
| Peter Wren | 4A, legal clerk | Narrow rumpled brown suit; overfilled document wallet |
| Cal Dwyer | 5B, radio collector | Mustard cardigan; hearing aid; Bakelite radio and cable |
| Iris Bell | 5C, painter | Coral underlayer; paint-stained coveralls; brushes and palette |
| Jonah Price | 6B, insomniac writer | Folded posture; navy robe-cardigan; mug and annotated notebook |
| Mae Kessler | 6C, estate collector | Bottle-green coat; silver pageboy; gloves and cataloged box |
| Transient Guests | 4D, short-term rental | Mismatched luggage; faded travel layers; deliberately weak roots |

## Implementation order

1. Player arms/body proxy and Mara Chen.
2. Mina, Juno, Omar, Rhea, Nadia, and Sacha.
3. Cam and Noel.
4. Supporting residents using the shared body, garment, and hair library.
5. Transient guest variants assembled from the same modular wardrobe.

This order supports the intro and Case 01 first, then fills the apartments
whose environmental storytelling is already strongest.
