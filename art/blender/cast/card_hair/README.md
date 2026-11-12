# Card hair

Hair for the cast as layered cards: a solid cap in the darkest tone, and over
it tiers of cupped, tapering strips. Each strip shows a clump of strands that
splits into separate points over its last third, so the feathering is in the
texture and the silhouette, not in the triangle count. A head costs 3,700 to
12,700 triangles and one 1024 x 1024 atlas (colour with cut-out, normal,
roughness).

## Files

| File | What it is |
|---|---|
| `art/blender/scripts/build_card_hair.py` | The generator. Blender, CPU only. |
| `art/tools/card_hair_styles.py` | The cut library and who wears which cut. |
| `art/blender/cast/card_hair/base_bob.json` | The full bob every cut starts from. |
| `art/blender/cast/card_hair/card_hair_reference.gdshader` | The shader the cuts were reviewed under. |
| `tools/tests/test_card_hair_styles.py` | Holds the library whole and every setting read. |

Generated models, maps and review pictures are not kept here. A likeness
style (a head made to match one real person) is kept outside the repository.

## Making hair

```
python art/tools/card_hair_styles.py <styles_dir>
blender -b --python art/blender/scripts/build_card_hair.py -- <body.blend> <styles_dir>/<person>.json <out_dir>
```

The body file is opened and never saved. It needs a `Skin_head` mesh and an
armature with a `Head` bone. Styles are written for one size of head; with
`"fit": "head_bone"` the generator measures the head from that bone, builds
at the written size and carries the hair back, so one cut fits every head.

Out come `<person>_hair_cards.glb` (two meshes: `HairUnderCap` and
`HairCards`), the same as a `.blend`, three maps, `BUILD.json` (card counts
and each card's path, for diagnosis) and `<person>_hair_look.json`.

## What the engine must do

- Draw both meshes with one cut-out shader that writes depth, with
  alpha-to-coverage on and the viewport's multisampling on. No sorting.
- Set the look file's values on the material: `underside`, `roundness`,
  `gloss`, `hair_centre` (model space, Y up), and for the cap `cap_shade`,
  `cap_feather`, `cap_bald`. Set `is_cap` on the cap mesh.
- Keep both UV sets. The second runs root (0) to tip (1) along each card, and
  round the head and crown to edge on the cap; tip sway and the cap's
  feathered edge read it.
- Re-export through `art/blender/scripts/check_exported_tangents.py`'s owner
  before intake: stock Blender glTF export fails the tangent check for these
  meshes.
- The cuts were reviewed with the cards casting no shadow and the cap casting
  one. Cards that shadow each other have not been reviewed.

Rounded shading turns each card's normal toward "out of the head". A card
wound to face the head has the opposite normal; mixed raw, the two cancel and
the card is lit as if it faced the floor, which draws a dark band round fair
hanging hair. The shader turns the card's own normal outward first, and the
test holds that line.

## A new cut

Add it to `CUTS` in `card_hair_styles.py` with `cut(BOB, ...)`, `longer(...)`
or `fuller(...)`, give it to someone in `CAST`, and run the test. A setting
the generator does not read fails the test. Then build the head and look at
it in the engine from the front, three-quarter, side and back before
believing it.

Known weak cuts, as reviewed on 2026-11-12: the cropped fringe on a bald
crown reads as chunks, the close coil crop shows stripes on the cap from the
front, and the men's short cuts are hard to tell apart. No cut is made to sit
under a hat yet.
