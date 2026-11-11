# The cast's bodies, rigs and performance: plan

Evidence class: **INERT**. Plan, 2026-11-11, at Lily's direction (relayed through Codex in two notes: repair the NPC meshes, texture maps and rigs, then a procedural animation system; and facial performance as part of the pilot). Nothing here is proof of anything built. It revises Codex's six-step plan against a file inventory made the same day and unfiled in the repo: `C:/ov/reports/npc_rig/INVENTORY.md` and `inventory.json`, read at main **b8327f83**.

## 1. What the inventory found

Observed in the files, not inferred:

- **Twenty humanoid bodies in four skeleton families.** Seventeen residents share a 24-bone skeleton; Mina has 28; Adela has 28 under different names; the player's doodle has 52. Staff (Stacy, the porter, shopkeepers) have no body.
- **Every body is one fused shell.** Hair, glasses, clothes and face are a single mesh with one material. Hands are mittens on one bone. Evelyn's mesh has 17,770 open edges after welding.
- **No face can move.** There are no blend shapes and no eye, eyelid, jaw, lip, tongue or brow bones on any humanoid. Features are painted. Mouths are closed surfaces. Head edges run 4.5 to 10 mm with no loops around the eyes or lips.
- **There is no shared rest pose.** Arms rest 53 to 73 degrees below horizontal, joint spacing runs from 0.48 to 1.86 of Evelyn's, seven residents have a hips frame 114 to 147 degrees off the others, and Mina's arm axes are flipped.
- **Normal and roughness maps are blank** for seventeen of eighteen residents, and sixteen store their albedo twice.
- **Borrowed clips play about 1.25 times too fast** in all sixteen personal libraries (72 keys over 2.37 s where the source has 3.00 s).
- **V2 uses three clips per resident** of forty-nine shipped, forces every clip to loop including ones whose hips travel over three metres, and writes no bone after animation: no look-at, no IK.
- **The costumes are modern.** The bodies are generated models with names like "Neon Wave Operative"; only Adela's reads as 1929.
- **No line of dialogue has audio, a duration or an emotion tag,** and most resident conversations happen through a closed door, with no body in view.
- **There is no editable source** for seventeen of the residents: the repo holds converted downloads, not authored files.

Not as feared: the presentation script flattens nothing today, because every body already has a single surface. Jonah's UV repair is pinned to his file's hash and would be dropped by any re-export.

## 2. What that does to the plan

Codex's plan assumed bodies that could be repaired at source. For seventeen residents there is no source, and what is wrong (a fused shell, painted features, mitten hands, no loops) is not a repair but a rebuild. Three of Lily's wants cannot be met on the present bodies at all: expression, eye movement and lip-sync; a hand closing on a door handle; and period dress.

So the first decision is not how to animate but what to animate. It was Lily's, as ruling **npc_body_strategy_20261111**. **She ruled A on 2026-11-11: rebuild the cast on one authored base, proven on two residents first.** The three options were:

- **A. Rebuild the cast on one authored base (recommended).** One skeleton for everyone, with eyes, lids, jaw, a face that deforms, five-fingered hands, a common rest pose, and clothes as separate period garments. Each resident keeps their identity, proportions and face. This is the only option that delivers faces, hands and 1929 dress, and it removes the retargeting problem at its root.
- **B. New heads and hands on the present bodies.** Cheaper. Faces and hands work; the modern costumes, fused clothes and the four rest poses stay, with a seam at neck and wrist.
- **C. Keep the bodies; body performance only.** Posture, head turn, foot planting and gestures on the present rigs. No expression, no eye movement, no lip-sync, mitten hands.

## 3. The revised order

Work that does not depend on the ruling comes first, so nothing waits.

1. **Reproduce.** Capture each observed defect in the running game before touching anything: clip speed, looping travel clips, shading without maps, a conversation through a door. The inventory's "suspected, needs a render" list is settled here.
2. **Fix what is wrong whatever the bodies are.** The 1.25 times clip speed. Looping of clips that are not loops. Root travel that would move an actor twice. A resident id and a start and end on every spoken line, so a performance can follow it.
3. **The pose pipeline, built against a rig profile, not a skeleton.** One profile per skeleton family names the semantic joints, the rest-pose correction, limits and what the rig cannot do. The pipeline composes, in one fixed order, base locomotion, posture and gesture, gaze, contact correction and secondary motion, and **every bone has exactly one final writer per frame, checked by a test**. Navigation moves the actor; clips never do.
4. **Body pilot on the present rigs:** Mina (family B) and one family-A resident. Standing, walking, starting, stopping, turning, stairs, sitting, turning the head and chest to a speaker, reaching toward a door handle as far as a mitten allows. This proves the pipeline and the profiles before any new body exists, and it carries straight over to a rebuilt cast as a fifth profile.
5. **The bodies, by the ruling.** Under A: one base, proven on two residents first (one face that must be right: Mina; one from the largest family), each checked for identity against the present model before the rest follow in batches.
6. **The facial controller, one per actor,** on the first body that has a face. Expression, gaze, blinks and speech compose in a fixed order: gaze aims the eyes and then the head; expression sets the face; speech owns the jaw and lips while a line plays and releases them when it stops; blinks ride on top. Attention and emotion stay with the owners that hold them now (who is talking, trust, agenda, temperament); the controller only shows them. There is no mood owner today, so one small one is added beside the existing conversation state.
7. **Speech.** Lily will record the lines. Each recording gets a timing file of mouth shapes made offline, once, by an alignment tool, and stored beside the audio; nothing analyses speech while the game runs. A line without a recording uses a restrained jaw motion; a written line moves nothing. Recordings can arrive one at a time.
8. **A place to talk face to face.** Most conversations are at a closed door. The pilot's close conversation needs the resident in view: the door opened, or a seat in the luncheonette, where bodies already sit.
9. **Qualify the pilot,** then the rest of the cast in batches: maps close up, silhouette, joints, foot sliding, handle contact, transitions, interruption, unloading and rebuilding, save and load, a time jump mid-conversation. Measure groups of visible residents with skinning, textures and shadows before choosing what distant ones may skip.

## 4. What is judged

Codex's test stands: whether a character appears to notice, listen, think and respond, with stillness and silence allowed and different rhythms for different people. The pilot's close conversation shows listening, recognition, speaking, interruption and a return to rest, reviewed at conversation distance and close up, with eye alignment, lid closure, lip closure, teeth and tongue, timing and transitions checked.

## 5. Open for Lily

- The tools, as ruling **npc_tools_20261111**: MPFB2 (the MakeHuman add-on for Blender) for the base body, faces, hands and rig, and Rhubarb Lip Sync for mouth-shape timings from her recordings. Both are authoring-time installs; nothing is downloaded until she answers.
- Because the cast is being rebuilt, the present bodies' own faults (clip speed, blank maps, duplicate albedos, fixed heights) are corrected in the rebuild, not patched on bodies about to be replaced. The clips are retargeted once, to the new skeleton, at their true speed.
- Whose face is whose: under A each resident's face is rebuilt to match the present model, which she has already accepted as that person; she may want some changed while they are open.
- Staff with no body (Stacy, the porter): in or out of the first batches.
