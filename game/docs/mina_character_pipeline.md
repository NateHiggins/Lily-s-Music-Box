# Mina Vale Character Pipeline

Mina uses a reproducible stylized low-poly character model designed to remain
readable in the Orison's low, warm lighting. Her deep-teal cardigan, mustard
shirt, charcoal trousers, oxide-red shoes, blue-black bob, and heavy brass
glasses give her a strong silhouette without requiring detailed textures.

Run `tools/generate_mina_character.py` through Blender 3.6 to regenerate:

- `mina_vale_rigged.blend` — editable source containing mesh, materials,
  armature, constraints, actions, and preview camera;
- `mina_vale_rigged.glb` — Godot production asset;
- `mina_vale_preview.png` — visual QA render.

The armature contains deform bones plus hand and foot IK targets. Both actions
are authored through those IK targets and visually baked to the skeleton:

- `Mina_Idle`, 80 frames at 30 fps: breathing, weight transfer, small hand
  movement, and furtive head glances;
- `Mina_Walk`, 32-frame loop at 30 fps: planted stance feet, lifted swing feet,
  counter-swinging hands, hip rise, torso counter-rotation, and stabilized head.

`AnimatedResident` plays idle normally. During an active or reopened Caption
Crisis, Mina performs a restrained 70-centimeter pacing loop inside the
authored clear area of apartment 2A and crossfades to the walking action.
Stabilization returns her to her canonical position and idle animation.
