# Prop Texture Prompt Batch

Paste-ready prompts for new prop material plates. One image per numbered item.
The filenames are the ingest contract. These are surface swatches, not pictures
of objects.

## Refrigerator pass

1. **`zinc_liner.png`**

   Seamless square high-resolution material texture of old galvanized zinc
   sheet used to line a 1910s domestic oak icebox, flat evenly-lit
   document-scan, close crop filling the frame edge to edge, pale cool grey
   zinc with very fine restrained crystalline spangle, forty years of soft
   wipe haze, faint mineral bloom and sparse tiny dull oxidation freckles,
   no directional lighting, no highlights, no shadows, no glare, no vignette,
   no baked gradient, no seams, no panel borders, no object edges, no props,
   no letters, no numbers, no words, no logos, no symbols, no labels, no
   stamps, no writing, no branding, flat matte color, physically plausible,
   perfectly tileable on all four edges.

2. **`copper_aged.png`**

   Seamless square high-resolution material texture of exposed copper cooling
   tubing from a 1927 electric monitor-top refrigerator, flat evenly-lit
   document-scan, close crop filling the frame edge to edge, warm brown aged
   copper with rubbed reddish high areas, restrained dark oxide in shallow
   pits, a few tiny desaturated blue-green verdigris traces where condensation
   sat, fine handling and service scratches without any directional pattern,
   no directional lighting, no highlights, no shadows, no glare, no vignette,
   no baked gradient, no seams, no pipe shape, no object edges, no props, no
   letters, no numbers, no words, no logos, no symbols, no labels, no stamps,
   no writing, no branding, flat matte color, physically plausible, perfectly
   tileable on all four edges.

`brass_dull` is the third pipeline addition but intentionally has no new image
prompt. It shares the existing `brass` photographed plate through
`catalog_mapping` and differs in runtime metallic/roughness response. Generating
another nearly identical source would add variation the fiction did not ask for
and make two finishes drift apart spatially.

The two generated source plates are stored at:

- `art/textures/ai_sources/zinc_liner.png`
- `art/textures/ai_sources/copper_aged.png`

## Stove pass

No generated texture prompt is warranted for this prop.

- `cast_iron` already has a period-appropriate ingested source family. The
  missing work was the Godot runtime stage and `MatLib.SETS` entry, not a new
  bitmap. Generating a second plate would fork the same material between the
  building and the functional prop.
- `fx_grease` already exists as a shaped, transparent authored overlay at
  `art/textures/generated/fx/wear_grease.png`. The stove pass preserves that
  alpha and synthesizes neutral roughness/normal companions for the runtime
  material. Re-prompting it as a seamless swatch would destroy its placed-
  decal framing.
- `enamel`, `bakelite` and `brass_dull` are existing sets.

This is an intentional zero-image batch: no letters, numbers, words, logos or
new visual source material were introduced.

## Plumbing fixture pass

1. **`nickel_plated.png`**

   Seamless PBR swatch: square, seamless, tileable aged nickel-plated brass
   plumbing hardware; warm silvery nickel, fine hand-polished micro-scratches,
   subtle cloudy oxidation, restrained pinprick tarnish, tiny warmer brass
   beginning to show. Generic uniform surface, flat diffuse evenly-lit
   document-scan, no object, no edge, no fitting, no screw, no seam, no
   highlight, no shadow, no landmark, no letters, no numbers, no words, no
   labels, no logos, no symbols, no watermark, no border, no baked lighting.

Generated source and processed set:

- `art/textures/ai_sources/nickel_plated.png`
- `art/textures/ai_materials/nickel_plated/`
- `game/assets/building/textures/T_ai_materials_nickel_plated_{albedo,rough,normal}.png`

This is a tiling finish, not a picture of a faucet. Exposed brass, mineral
bloom and rust are positioned geometry/deposits in `tap_prop.gd`, where hands
and standing water put them; baking those landmarks into the swatch would
repeat the same accident on every vertical riser and every valve.
