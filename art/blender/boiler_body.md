# Boiler casing and service cavities

Evidence class: **INERT**

Rebuild **art/blender/boiler_body.blend** and
**game/assets/props/boiler_body.glb** with
**art/blender/scripts/build_boiler_body.py** in Blender. The source preserves
the original 1.16 by 1.02 metre plant, sectioned castings and lagging silhouette.
The firing and ash throats now cut through every casing layer. They contain
jointed firebrick, an internal seven-bar grate, an ash tray with side returns,
and recessed back walls. Hollow retaining straps and cast surrounds seat on
the casing; ties and nuts clear both openings.

The former body filled the open doors and the grate protruded through the
closed firing plate. Fixed collision now follows the merged static triangles,
including the open throats. Moving plate collision and outward pivots remain
separate. BoilerProp still owns every interaction, water-column control,
pressure/draft response, heat state, sound and persistence. Twenty-four shaped
coal lumps form one independent mesh with the original live emission material.

Material roles resolve through BoilerProp's existing colour-to-MatLib mapping:
cast iron, metal, linen lagging, soot and existing hearth finish. Firebrick
retains its existing soot/tint binding pending the coordinated material pass.
Metre UVs and baked transforms prepare the assembly without changing lighting,
catalogue keys or textures. The fixed plant has nine material batches and
13,248 triangles, plus the independent 480-triangle coal bed.

OrisonV2BoilerBodyTest checks twelve actual cavity/back-wall contacts, rejects
the former solid envelope, checks grate clearance, independent coal geometry
and closed moving-plate seals. Windowed player-height and detail renders live
under **tmp/boiler-firebox/shots**. Detail views add a small inspection fill;
the player view retains the production lamp. Final candidate verification,
double imports and route/mechanism suite receipts belong under
**tmp/boiler-firebox/verified**. These are scoped suite runs, not runtime-contract
or whole-building acceptance evidence.
