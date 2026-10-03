# Mina Vale regeneration reference

Evidence class: **INERT**

Requested by the owner on 2026-10-03: new A-pose art in a distinctive period-inspired outfit, plus a full animation list with short English action descriptions. This folder supplies source art and a commissioning brief. Animation clips, a new mesh and runtime acceptance are separate deliverables.

## Character and outfit

Mina is a caption editor and former certified court reporter. Twenty-two years of precision survive a missing four seconds in the record. The slate suit is kept carefully, as though she still has somewhere to appear. Her clothes carry discipline; her observant face and restrained motions carry fatigue, warmth and the possibility of connection.

The new design retains the established Grey Elegance hero's mature face, short dark hair, spectacles and grey felt bowler. The straight slate worsted jacket uses long geometric charcoal velvet-faced lapels, parallel stitching and a diagonal low fastening. An ivory cotton shirtwaist has vertical pintucks and a detachable collar. A small oxblood pocket-lining repair, walking pleats, grey stockings and resoled low T-strap shoes give the outfit a personal history. Her pencil remains behind her ear. Bare hands keep this indoor work reference useful for modeling.

The frontal image is a neutral, evenly lit A-pose on grey. It is concept/source art; the wool pattern, folded cloth and details should be reconstructed and mapped through the existing character pipeline rather than treated as proof of final geometry or materials. This concept step preserved the existing hero. The later owner-supplied Gray Resolve model replaces it, retaining the new export's body and proportions, as recorded below.

## Files

- **mina_vale_apose_front_v2.png** — selected source art, generated with the built-in imagegen tool and refined for a straighter period silhouette.
- **animation_brief.md** — 72 named actions with short English descriptions and delivery notes.
- **animation_brief.json** — the same commissioning list in a structured art-side file, not loaded by the game.
- **critical_20_animation_prompts.md** — the owner's revised priority list: 20 text-to-animation prompts, each exactly 400 characters, with separate 2–10 second durations.
- **critical_20_animation_prompts.json** — the same priority prompts, durations and playback metadata for production use.
- **next_20_animation_prompts.md** and **next_20_animation_prompts.json** — the next requested commissioning list; these proposals do not add clips to the installed twenty-animation batch.
- **generation_prompts.txt** — exact generation and refinement prompts.

## Sources

Character, wound and date: **design/ORISON_BIBLE.md**, especially the Mina entry and the 1928 ruling. Clothing language and A-pose contract: **design/ORISON_WARDROBE_BIBLE.md**. Current hero and retargeting history: **game/docs/mina_character_pipeline.md**. Identity reference: **art/blender/meshy/_previews/Meshy_AI_Grey_Elegance_biped.png**. Case performance: **game/data/case01_dialogue.json**, including its existing **strained** and **recognition** roles. Ordinary activity coverage follows the installed mail, laundry, doorway, lift and domestic routines. The older teal-trouser A-pose is superseded reference material and was not used for this design.

## Supplied replacement, 2026-10-03

The owner subsequently supplied Gray Resolve as the production replacement. Its mesh and actual twenty-clip batch are now ingested through **art/blender/scripts/ingest_mina_resolve.py**. The commissioning sheets remain historical proposals; the delivered clip map is **art/data/mina_resolve/clip_manifest.json**. See **game/docs/mina_character_pipeline.md** for behavior and rebuild instructions.
