# Drapery: rings, period fabrics and glass curtains

Evidence class: **INERT - DESIGN NOTE**

*Owner direction 2026-10-24: "the drapes don't actually attach to the rings,
research and add a few drapery fabrics and treatments, use blender to generate
maybe one with lace edgework, that sort of thing, maybe a chiffon ethereal inner
drape."*

## 1. What was wrong

The overdrape (`PleatedSewnPanel`) waved its pleats about 42 mm front and back
all the way to its top edge, while the small sewn tabs that stood in for its
fixing sat in a straight line at one depth under a straight rod. The heading
never met the rod and nothing ringed it.

## 2. How a 1920s window was dressed

A modest New York flat of 1928 dressed a window in up to three layers, from the
glass inward:

- **The shade or blind**, against the sash. The Orison's are slatted wooden
  blinds (already modelled and operable).
- **The glass curtain**, a sheer hung on its own slim rod close to the glass,
  usually left drawn: it softened light and gave daytime privacy. Fabrics were
  voile, marquisette, scrim, net and **ninon**, a fine, almost weightless silk
  or rayon voile that is the chiffon of the window. Working-class windows often
  hung **machine lace** instead, Nottingham lace or lace-edged voile.
- **The overdrapery**, on rings over a rod, drawn at night. Common fabrics were
  **cretonne** (printed cotton), **monk's cloth** (coarse basket-weave cotton,
  an Arts and Crafts favourite of the 1920s), rep, damask and, in a parlour
  that wanted to look its best, **cotton velour**. Headings were gathered or
  pinch-pleated on buckram and hung from brass or wooden **rings** by sewn
  hooks.

## 3. What was built

**The heading is carried.** The overdrape's pleat wave now fades to nothing
across a flat buckram band at the top. Nine brass curtain rings per panel
(`CurtainRing`, a torus that encircles the rod) rest on the rod, and a sewn
hook (`RingHook`) joins each ring's foot to the heading. The rings spread and
gather with the panel as the drapes are drawn and opened. The overdrape rod
stands 140 mm into the room so the pleats' back folds clear the glass curtain.

**Three fabrics**, synthesized deterministically and seamlessly by
`art/tools/build_drapery_fabrics.py`, registered through the catalogue
(RUL-008: `material_catalog.json`, `catalog_mapping.json`, runtime policy,
`generate_runtime_materials.py`):

| Key | Fabric | Tile |
|---|---|---|
| `monks_cloth` | coarse 2x2 basket weave, oatmeal | 0.30 m |
| `velour` | cotton pile, neutral for tinting, soft crushed sheen | 0.40 m |
| `ninon` | fine open plain weave, near-white sheer | 0.12 m |

**Glass curtains.** `GatheredSheerPanel` is a finely gathered sheer;
`LaceEdgedSheerPanel` adds a modelled lace hem cut from the cloth in Blender:
a ruled openwork line, a round eyelet in each scallop with a smaller pair
flanking it, picot holes between scallops, and scalloped edges whose vertices
are snapped onto the true curves. Both hang on a slim inner rod with its own
brackets and smaller rings, drawn with `v2_window_sheer.gdshader`: translucent,
double-sided, backlit by the daylight through them, and stirring faintly at the
hem as if from a draughty sash. They stay drawn; a glass curtain's work is to
be there. Kitchens and bathrooms do not get them.

**Who hangs what** (`apartment_life_profiles.json`, `window_treatment.sheer`):

| Flat | Overdrape | Glass curtain |
|---|---|---|
| 1A Evelyn | ivory linen | lace-edged ninon |
| 2A Mina | neutral linen | plain ninon (glare at the caption desk) |
| 3D Rhea | wine-dark velour | none |
| 4A Peter | monk's cloth | none |
| 4B the player | worn linen | a yellowed ninon left by the last tenant |
| 5A Nadia | monk's cloth | none |
| 5B Cal | muted green velour | none |
| 5C Iris | ochre cotton | white ninon (studio daylight) |
| 6B Jonah | monk's cloth | none |
| 6C Mae | taupe velour | lace-edged ninon |

## 4. Not done

No cretonne: a convincing printed floral needs drawn artwork, not a synthesized
weave. No valances, swags or tiebacks. Glass curtains cannot be drawn by hand;
only the overdrape, blind lift and slat tilt are hand controls.
