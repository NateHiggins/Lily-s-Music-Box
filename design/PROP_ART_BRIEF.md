# Brief: prop design pass — real-world accuracy, modelling, texturing

**For an agent with local access to this repository.** Read the files;
do not work from this document's description of them. Everything below
is context, constraint and deliverable — the facts are in the code.

---

## 0. What you are being asked to do

Take the props listed in §5, compare each against **real-world 1927 New
York** reference, and improve the modelling and the texturing.

Three outputs per prop:

1. **Reference comparison** — what the real object was, in that year,
   in that city, at that price point. Manufacturer and model where it
   matters. What our version gets wrong, in specifics: proportion,
   missing components, wrong period, wrong class of object.
2. **Modelling improvements** — concrete changes to the GDScript that
   builds it, in the primitives it already uses. Dimensions in metres.
3. **Texturing** — which material key each part should carry, and where
   a new texture is genuinely needed, an image-generation prompt for it
   written to the house rules in §4.

Work prop by prop. Do not restructure the prop system.

---

## 1. Read these first

| Path | Why |
|---|---|
| `game/scripts/props/functional_prop.gd` | The base class. `make_box`, `make_cyl`, `make_ring`, `make_emitter`, `smat`, `retexture`, `merge_static`. Every prop is built from these. |
| `game/scripts/props/*.gd` | The 50 props. Read the ones you are changing, in full. |
| `art/data/gen_layout.py` → `MATERIAL_CATALOG` | **The 95 material keys that exist.** Read this before naming any material. |
| `art/tools/ingest_material_sources.py` | How a generated image becomes a game material: `SLOTS`, `PRECROP`, `COLOR_ANCHORS`, `GRID_SLOTS`, `GODOT_STAGE`. |
| `design/MATERIAL_PROMPT_SHEET.md` | The house style for texture prompts, including "Talking to the generator". |
| `design/PROP_ACTIVITIES.md` | What each prop is going to be asked to DO. A crumb tray that will be pulled open needs to be modelled as a tray that opens. |
| `docs/` and `design/next_session_plan.md` | The building's fiction and current state. |

---

## 2. The world, precisely

**READ `design/ORISON_BIBLE.md` §VIII — THE DIVERGENCE FIRST.** This is
an alternate 1927 and the difference is not decorative. One rule governs
every object you will touch:

> **Does it carry, capture, switch, store or reproduce a signal?**
> If YES it is forty years ahead of its time. If NO it is 1927 and
> probably second-hand.

Signal technology diverged in 1873 and nothing else did. There is no
penicillin, there are horses on the street, and most flats keep their
food in an icebox — in a building wired past the standard of a
broadcast house, because the firm that built it was in the business.
Apply the rule before you reference anything.

- **The Orison Apartments, Queens, New York.** A 1927 walk-up: six
  storeys, basement, roof. Brick, plaster, oak, brass, cast iron.
- **The present is late 1927.** So every object is either NEW in the
  twenties, or older and surviving — a 1911 stove in a 1927 kitchen is
  correct and characterful; a 1950s one is wrong.
- **These are not wealthy homes.** Rented flats, some furnished, some
  not. Objects are mended, mismatched, and inherited. Where a real
  household would have bought the cheap version, we have the cheap
  version.
- **It is a horror game, and the horror is domestic.** Accuracy is what
  makes the wrongness land. A kettle that is exactly right is a kettle
  that can be made frightening.
- **True scale, always.** The player is 5'0" with a 1.41 m eye line.
  Doors, counters, handles and switches are all sized against that and
  must stay so. **Check any change against the eye line** — a worktop
  at the wrong height is felt immediately even when nobody can say why.

---

## 3. Hard technical constraints

Breaking any of these breaks the build. They were each learned
expensively.

- **Godot 4.7.1, `gl_compatibility` renderer.** Note: this renderer DOES
  support `light_projector` in 4.7, whatever older comments claim.
- **Props are built in GDScript from primitives.** Boxes, cylinders,
  rings. There is no mesh import path for props. Improvements are more
  and better-proportioned primitives, not an .obj.
- **`art/data/material_catalog.json` is GENERATED.** `gen_layout.py`
  writes it from its own `MATERIAL_CATALOG` dict. Hand-editing the JSON
  works until the next run silently discards it. **Add materials to
  `MATERIAL_CATALOG` in `gen_layout.py`, never to the JSON.**
- **A material key that is not in the catalog FAILS the Blender build**
  with `mapping key 'x' not in material_catalog` and exit 1. Check
  before you name.
- **A GDScript-built prop's textures never reach Godot via Blender.**
  Blender only bakes finishes its own geometry references. A material
  used only by a prop must be in `ingest_material_sources.py`'s
  `GODOT_STAGE` list AND exist in `MatLib.SETS`, or it stays flat
  colour. This has caught people repeatedly.
- **GDScript traps, all hit this month:** no tuple unpacking in `for`
  loops; multi-line lambdas do not parse (the error points at the line
  *after*); a new `class_name` does not exist until Godot rescans
  (`--headless --path game --editor --quit`); a test scene whose script
  fails to parse **hangs forever** rather than failing.
- **Verify by rendering, never by reading code.** `tests/Screenshot.tscn`
  with `SHOT_DIR` (a Windows path that must already exist) and
  `SCREENSHOT_ONLY`. Needs a real window — headless writes nothing and
  exits 0.
- **Judge rooms with `SHOT_LIGHTS=1 SHOT_TORCH=1`**, never the fill
  light. Merged meshes drop lights by AABB and the fill is a liar.
- **Flat metal reads black.** A high-`metallic` horizontal surface lit
  from above reflects away from the eye. Real floor-level brass carries
  oxide: use `brass_dull` (metallic 0.30) for anything horizontal,
  polished `brass` only for vertical or hand-touched parts. **Measure
  the render** — sample RGB against neighbouring materials — rather than
  judging a dark screenshot by eye.

---

## 4. Texture prompt rules

If a prop needs a texture that does not exist, write a prompt to these
rules. They are what the existing 90+ plates were made to.

- **Flat, evenly lit document-scan look.** No shadows, no glare, no
  vignette. Any gradient baked into a tile becomes a visible grid.
- **Seamless** for anything laid across a surface. Placed features (a
  decal, a label plate) are exempt and keep their framing.
- **NO LETTERS, NUMBERS, WORDS, LOGOS OR SYMBOLS**, anywhere, ever.
  Real objects are covered in printing and the generator will add it
  unless told repeatedly not to. This is the single most-broken rule.
- **Close crop, filling the frame edge to edge.** No object edges, no
  background, no props.
- **Period-correct wear**, described specifically: what dirtied it,
  where hands go, what the light did to it over twenty years.
- Square, high resolution, flat matte colour.
- Say what the thing IS and let the material follow, rather than
  describing a shader.

Deliver prompts as a **paste-ready numbered batch**, one image per
item, with the filename each output should take.

---

## 5. The props, in priority order

Priority follows `design/PROP_ACTIVITIES.md`: the ones that are about to
carry a game are the ones worth the modelling effort.

**Progress (2026-08-09): 11 of 24 review families complete.** The entire
first tier is finished; the second tier is halfway finished. Detailed evidence,
renders, pipeline notes and validation results live in
`design/PROP_REFERENCE_NOTES.md`. The next untouched family is
`mail_bank_prop`.

### First — these are getting games and will be looked at closely

1. **[COMPLETE] `fridge_prop`** (18 in the building) — an ICEBOX or an early
   electric? In 1927 Queens, in rented flats, most likely both exist in
   the building and that difference is characterful. Get the class of
   object right before the details. It opens, and its interior will be
   inventoried.
2. **[COMPLETE] `stove_prop`** (17) — gas range, four burners, oven below. The
   burners, jets, and the oven door are all about to become
   interactive.
3. **[COMPLETE] `tap_prop`** (23 sinks, 23 showers) — taps, spouts, and what a
   1927 rented-flat sink actually was. Dishes will be washed here.
4. **[COMPLETE] `toaster_prop`** (14) — and **the crumb tray must open**, because
   that is the game. What was a 1927 toaster, really?
5. **[COMPLETE] `radiator_prop`** (23) — cast-iron column radiator, valves, air
   vent. The bleed valve and the supply valve both become interactive,
   so both must be modelled and findable.
6. **[COMPLETE] `boiler_prop`** (1) — the building's heart. Gauges, sight glass,
   firebox, flue. It is going to be tended.
7. **[COMPLETE] `washer_prop`** (2) + **`laundry_airer_prop`** (1) — a 1927
   wringer washer is a very different object from a front-loading drum, and
   the room dries on a pulley airer rather than an automatic dryer.
8. **[COMPLETE] `vantry_point_prop`** (one per enclosed room) — **ruled and built.**
   The modern smoke detector was the fiction problem, not the reference.
   Its replacement is a 1912 Bakelite-and-brass Vantry fire/flood/listening
   head on a dedicated house signal circuit. The old `smoke_detector` key
   remains only as a serialized-data alias; never author a new one.

### Second — read closely, touched often

9. **[COMPLETE]** `kettle_prop`, `medicine_cabinet_prop`, `clock_prop`,
   `mail_bank_prop`; `bookshelf_prop`; **[NEXT]** `door_prop`.

### Third — a lighter pass

10. `boxfan_prop`, `exhaust_fan_prop`, `flue_breast_prop`,
    `lamp_prop`, `light_fixture_prop`, `monitor_prop`, `tv_prop`,
    `speaker_prop`, `arcade_cabinet_prop`, `lobby_bulletin_board`.

---

## 6. What "improved" means here

- **Proportion before detail.** A radiator with the wrong section
  count and the right valve is worse than the reverse.
- **The right object, not a nicer version of the wrong one.** If we
  have modelled a 1960s appliance, say so and replace it.
- **Wear that says who owns it.** Eighteen flats, eighteen households.
  A single grubby texture on every stove is worse than a clean one.
- **Model what will be touched.** Anything the activity list makes
  interactive must exist as geometry a hand could reach.
- **Do not gold-plate scenery.** Props on the leave-alone list in
  `PROP_ACTIVITIES.md` should get proportion fixes only.

---

## 7. Deliverables

1. `design/PROP_REFERENCE_NOTES.md` — the comparison, prop by prop:
   what the real object was, what we have, what is wrong.
2. Edits to the prop scripts, in the existing style, with comments
   explaining WHY a dimension is what it is. The house comment style
   explains reasoning and records what was tried and failed — match it.
3. Any new material keys added to `MATERIAL_CATALOG` in
   `gen_layout.py`, wired through `ingest_material_sources.py`
   (`SLOTS` + `GODOT_STAGE`) if a GDScript prop uses them.
4. A paste-ready texture prompt batch for anything new.
5. **Before/after renders** of every prop you touch. This project's
   rule is that visual work is verified by rendering, never by reading
   code, and it has caught a screen mounted inside its own casing, a
   mask that never drew, and a shelf hidden behind a bezel.

## 8. Two things already ruled — do not re-open

Both questions this brief originally raised have been answered in the
bible, §VIII.5:

- **THE FRIDGES ARE A MIX.** Most flats have an ICEBOX — oak carcass,
  zinc lining, brass latch, and a drip tray underneath that somebody has
  to empty. **Four flats only** have an electric monitor-top: white
  enamel with the compressor sitting on top like a hat, new, expensive
  and audibly running. Which a household has is characterisation. Model
  both.
- **THERE ARE NO SMOKE DETECTORS.** The ceiling device is a **Vantry
  point** — part of the house listening system, installed 1912 for fire
  and flood detection. Bakelite, perforated, saucer-sized, brass grille.
  It has no battery. Model it as what it is: an ear.

## 9. Ask before you assume

Anything else that would change the fiction rather than the model —
raise it. Per §VIII.6 the divergence is narrow: it does not license
anachronism at will, and an object that carries no signal is 1927,
second-hand, and probably a bit broken.
