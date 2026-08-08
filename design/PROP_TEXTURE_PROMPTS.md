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

