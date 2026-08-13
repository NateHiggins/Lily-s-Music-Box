# Mina Vale Character Pipeline

**Mina's model is the Meshy `Grey_Elegance` export — owner-designated FINAL
on 2026-08-13.** Bowler, glasses, gloves, white blouse under a grey suit
dress, satchel, T-strap heels. She is the standard for how a
new-generation character enters the game; the previous procedurally
generated Mina (teal cardigan, mustard shirt) is deleted, and
`tools/generate_mina_character.py` survives only as the base generator for
the generated resident cast (see `resident_character_cast.md`).

## Her model

Built by `art/blender/scripts/convert_dump_characters.py` from
`art/blender/meshy/Meshy_AI_Grey_Elegance_biped/` per the committed mapping
in `game/data/resident_hero_models.json`:

- `assets/characters/mina_vale/mina_vale.gltf` — the hero model, 14.7k
  tris, 1K graded texture, **motion-free by contract**;
- her mapping entry carries `keep_emission: true` (owner instruction): she
  keeps her self-illumination where every other figure receives scene
  light. The converter and `art/tools/strip_character_emissive.py` both
  honour the flag; the doubled-specular fix still applies to her.

## Her animation

Her rig is a newer Meshy generation than the 2026-08-02 cast — different
joint spacing AND bone axes — so the runtime graft's verbatim track copy
can never be correct on her. Instead she carries a personal library:

- `assets/characters/mina_vale/mina_vale_moves.glb` — the full 48-clip
  shared set (Evelyn's role clips + the gesture library) baked onto her
  own skeleton by `art/blender/scripts/bake_model_moves.py`;
- `ResidentMovesLibrary.apply` prefers a `<model>_moves.glb` sitting
  beside any model over the shared libraries;
- `AnimatedResident` grafts the library when a model ships without an
  AnimationPlayer, so the hero pipeline and the old generated cast run
  through one code path.

Rebake after any model change:

    "/c/Program Files/Blender Foundation/Blender 5.2/blender" -b -P \
        art/blender/scripts/bake_model_moves.py -- mina_vale

## Behaviour

`AnimatedResident` plays idle normally. During an active or reopened
Caption Crisis, Mina performs a restrained pacing loop inside the authored
clear area of apartment 2A and crossfades to the walking clip.
Stabilization returns her to her canonical position and idle.
`MinaCharacterTest.tscn` drives exactly this against her production model.
