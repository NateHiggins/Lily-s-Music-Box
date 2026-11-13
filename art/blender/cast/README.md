# The cast pipeline

How a resident's body, hair and clothes are made and brought into the game.
Everything here is CPU work in Blender 5.2 and Python; nothing is generated in
the game. The wardrobe's authority for who wears what is
`design/ORISON_WARDROBE_BIBLE.md`.

## The stages

| Stage | Tool | Reads | Writes |
|---|---|---|---|
| 1. Tables | `art/blender/cast/make_cast_wardrobe.py` (uses `cast_parts.py`) | the tables in those two files | `cast_wardrobe.json`: each person's body, hair colour and three sets of parts |
| 2. Hair styles | `art/tools/card_hair_styles.py` | `card_hair/base_bob.json` | one style a person |
| 3. Hair | `art/blender/scripts/build_card_hair.py` | a body file, a style | hair model, three maps, a look file (see `card_hair/README.md`) |
| 4. Body and clothes | `art/blender/scripts/build_cast_wardrobe.py` | `cast_wardrobe.json`, the hair from stage 3 | `<id>.blend` (body, face, hair), `<id>__parts.blend` (every garment), a note a part |
| 5. Game files | `art/tools/cast_intake.py export` | the stage 4 folder | `<id>/<id>.gltf`, one `<id>__<part>.gltf` a part, pictures, notes, the look file, a manifest |

Stage 4 is run twice for a person the first time: once without hair, so the
hair has a head to be built on, then with `CARD_HAIR_DIR` set so the body
carries it.

```
python art/blender/cast/make_cast_wardrobe.py
python art/tools/card_hair_styles.py <styles>
blender -b --python art/blender/scripts/build_card_hair.py -- <build>/<id>.blend <styles>/<id>.json <hair>/<id>
CARD_HAIR_DIR=<hair> blender -b --python art/blender/scripts/build_cast_wardrobe.py -- <id> art/blender/cast/cast_wardrobe.json <build>
blender -b --python art/blender/scripts/build_cast_wardrobe.py -- <id> art/blender/cast/cast_wardrobe.json <build> parts
python art/tools/cast_intake.py export <build> <stage>
```

Generated models and pictures are not kept in `art/`. What the game loads is
installed from the stage 5 folder.

## What a person is, in the game

- One skeleton of 76 bones for everyone (the base rig, fingers, and eight
  chains of three skirt bones).
- The body once: skin in eight named parts (`Skin_head`, `Skin_chest`, ...),
  the face parts, and `Hair`, `HairCap` and `HatHair` (the same hair cut off
  inside a hat's crown).
- A wardrobe of small files, one a part: three sets (a home, b street, c
  occasion), each a top, a bottom, an outer layer, headwear and footwear. A
  whole outfit (a suit, a dress, a robe) fills one slot and its note says
  which others it stands for.
- Hair dressed for an occasion (`f_head`, table `FORMAL_HAIR` in
  `cast_parts.py`), for everyone but the two men who wear a close crop:
  sculpted and painted like the stage heads, where everyday hair is card
  hair. It is headwear whose note says `"hair": "replace"`, so it is worn in
  place of a hat and no other hair shows with it. `wardrobe_rules.gd` puts
  it on with the occasion outfit indoors.
- A note beside each part: its slot, its set, what it is for, and which skin
  parts it hides. Nothing hides the chest; a robe hides no trunk. A hidden
  part's edge follows the body's faces, so anything open at the neck would
  show it as a row of teeth.

`game/scripts/characters/cast_model_presentation.gd` loads a person and
refuses anything short of a whole outfit. `wardrobe_rules.gd` chooses parts
from the date, the hour, the place and the weather.

## Rules the builder holds, and why

Each of these cost a round of review; the code carries a line of comment
where it applies.

- **Garments are cut along a line through the body's faces**, not along the
  faces' own edges: a margin (metres, positive inside) is worked out at each
  point and the cloth is cut where it crosses zero. Read the margins before
  deleting anything; deleting renumbers the points.
- **An armhole** is the region past a plane across the arm, outboard of the
  chest and above the armpit, with the bottom corner rounded. It is sized to
  the shoulders and always leaves a strap beside the open neck. A sleeveless
  layer under another is cut narrower.
- **The skin's parts keep the whole body's normals.** Recomputed part by
  part, every cut between parts showed as flat facets.
- **Hats are placed from the top of the eye**, read before the body is
  trimmed (the eye helpers go with the trim). A turned-down brim clears the
  eye.
- **Pack garments** (the CC0 MakeHuman community packs) expect the body
  hidden under them. Here the body is whole, so they are given a floor of
  clearance, spread in their own layer order, their bone weights are evened
  out between neighbours, and both faces are drawn.
- **A top worn with a skirt is tucked**; an apron over a made skirt takes
  that skirt's flare and pleats; an outer layer over a pack garment stands
  further off.

## Game files and their checks

`art/tools/cast_intake.py export` runs `export_cast_actor.py` for each person
and then checks the result (`check` repeats the checks):

- every material is named `cast_<id>_...` and has a colour, a
  roughness-metal and a normal picture; a picture with no see-through pixel
  makes an opaque material;
- tangents are Blender's own, one frame a point, with the engine's
  handedness; `art/tools/check_cast_tangents.py` holds that, and
  `game/tests/tangent_convention_test.gd` is where the handedness comes
  from. The few corners that come out wrong-handed or far from their
  triangle are given that triangle's own frame;
- pictures two or more people share byte for byte are kept once, in
  `shared/`;
- `art/tools/compare_cast_exports.py` compares two exports of one model
  corner for corner (positions, normals, UVs, weights by bone name, face
  shapes by name, the skeleton), for when the way of exporting changes.

`cast_intake.py recipes --write` adds the material rows to
`art/data/material_registry.json` and regenerates the catalogues.

## Looking at them

Nothing here is accepted by a tool. Stand the people in the engine and look:
every set, front and back, the face close, and each hat.

## Clips

The twenty share one skeleton, so they share one clip library, baked once on Mina's body:

    KEEP_NAMES=1 blender -b --python art/blender/scripts/retarget_cast_moves.py -- <mina_vale.blend> <out>/cast_moves.glb \
        game/assets/characters/mina_vale/mina_vale_moves.glb 1.25 game/assets/characters/shared/biped_gestures.glb \
        game/assets/characters/evelyn_marsh/evelyn_marsh.gltf

It holds the names the residents ask for (`clip_01` to `clip_08`, `walk`, `run`, the twenty `mina_*`) and the 38
gestures. A clip whose feet go below where they rest is lifted whole by its deepest sink (`GROUNDED` in the log).
The file installs as `game/assets/characters/cast/shared/cast_moves.glb`. `ResidentMovesLibrary.apply` gives it to
any body carrying the skirt chains: rotations only, plus the hips' travel scaled to that body's hip height, so each
person keeps their own build. `game/tests/CastMovesLibraryTest.tscn` checks every installed body. Bodies of
another build than Mina's stand up to 2 cm low; the test allows 3.5 cm.
