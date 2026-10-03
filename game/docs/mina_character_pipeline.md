# Mina Vale Character Pipeline

Evidence class: **INERT**

Mina uses the owner-supplied **Meshy_AI_Gray_Resolve_biped** model and twenty-animation batch, replacing Grey Elegance and its donor library on 2026-10-03. Her exported proportions are retained: approximately 1.65 m tall, with a 28-bone rig and 1K textures. Her slate suit, walking skirt, bowler and mature face are the new production appearance.

## Rebuild

Extract the owner's zip into the ignored **art/blender/meshy/Meshy_AI_Gray_Resolve_biped/** directory. The committed **art/data/mina_resolve/clip_manifest.json** records each exact filename, its SHA-256, the corresponding English commissioning prompt and playback type. The owner supplied the Meshy action-list screenshot; UUID order, durations and four rendered poses per custom file confirmed the mapping.

Run Blender 5.2 with factory settings and **art/blender/scripts/ingest_mina_resolve.py**, then **art/blender/scripts/render_mina_resolve.py**. The old **bake_model_moves.py -- mina_vale** command delegates to this ingester for Gray Resolve, so it cannot restore the retired shared set.

Outputs:

- **art/blender/mina_resolve.blend**: packed textures, skinned mesh and exactly twenty editable actions. NLA tracks are muted in the saved source; choose an action to review it.
- **game/assets/characters/mina_vale/mina_vale.gltf** and its buffer/textures: motion-free hero, forty-thousand-triangle budget.
- **game/assets/characters/mina_vale/mina_vale_moves.glb**: only this model's twenty clips, on its own skeleton. No old donor motions or procedural idle remain.
- **mina_vale_preview.png** and **game/assets/npcs/mina_vale.png**: renders of the new figure, including the sprite fallback.
- **art/data/mina_resolve/bake_report.json**: actual export lengths and measured geometry. Requested prompt durations remain separate from the FBX's native durations.

Her existing **keep_emission** mapping ruling is retained. Metallic bodies and doubled specular are corrected by the same material convention as the cast. Imported scale tracks do not override the skeleton.

## First batch

The archive contains eighteen custom actions: calm idle, ordinary walk, hurried walk, turn around, stair ascent, push door, pull door, measured speech, strained explanation, recognition, stair descent, quiet thanks, begin walking, stop walking, close door, lock door, lift waiting and tired idle. Meshy's stock Walking and Running exports make twenty total. Their Rigify bone names are mapped to the new hero skeleton; the folded upper-body bind is aligned to her own calm pose before transferring their motion.

This is the actual delivered batch, which differs from the initial critical-twenty commissioning sheet. Unlocking, sitting, rising, writing captions, air annotation and anxious pacing were not supplied. They are not synthesized by borrowing retired clips. Turn, lift waiting and stock locomotion remain available for explicit role requests and review; her current timetable travels by stairs.

## Behavior

**MinaAnimationBehavior** owns playback independently of navigation. **AnimatedResident** installs it automatically for Mina; the V1 routine preserves its one-shot classifications too. Ordinary and hurried gaits match route speed. The late bodega run becomes hurried after 23:40. Walk starts and stops transition to their corresponding loop or idle. Authored route-edge slopes select stair motion without switching on every flat tread. Nighttime standing uses the supplied tired idle.

The bake strips horizontal hip travel and grounds the actual skinned shoes on the actor's floor. This prevents exported travel or stair rise from moving her through collision or adding a second vertical climb. Loop tails blend to their opening poses. Navigation retains all floor, capsule and door-leaf clearance checks.

The V2 route cues push/pull according to the door's real swing, waits for the reach beat before asking **DoorProp** to open, and holds navigation through the gesture. Closing uses the same real owner and sweep checks. A lock gesture follows a close that actually relocks; it does not grant access or change key permissions. Hand placement is still the supplied animation, without a finger rig or handle IK; precise handle contact needs a later calibration pass.

Dialogue nodes use measured speech by default. Existing **strained** and **recognition** roles play once and return to speech; stationary route calls cannot overwrite them. Conversation completion returns to idle, with quiet thanks after the earned silence/integration or resolved exchange. Body clips do not introduce face or lip-sync animation; the supplied FBXs have no facial control rig.

## Verification

Import twice through the repository's serial Godot lane. **MinaCharacterTest** checks twenty clips, loop/one-shot types, stair selection, case-role arbitration and the existing pacing behavior. **MinaPoseReview** renders four phases of every installed clip and the rest pose. The composed V2 mail, domestic, laundry, bodega, return, residue and off-map suites exercise the production actor and physical routes; the scoped door-safety suite also retains its mesh-free fixture.

The cast's other personal motion libraries retain their existing pipeline; see **resident_character_cast.md**.

The first-batch review gallery is **art/renders/mina_resolve_20261003/**. Its four contact sheets show four Godot poses per clip, and its domestic captures show the replacement in the actual V2 rooms with the handheld hidden. The gallery README records checked behavior and the remaining contact/cloth calibration limits.
