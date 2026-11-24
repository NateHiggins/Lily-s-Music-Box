# NPC facial performance: capability audit and gaze, 2026-11-24

Evidence class: **INERT**. This is an audit and pilot report for Lily's work order **w8c788aec4db6**
(facial performance, part of the animation pilot). It is not acceptance. The captures it cites are review
evidence only, kept outside the repo.

The order asks for five things: a facial capability audit and repair per model, layered expression, gaze
with intention and blinks, lip-sync to the speech that is playing with a jaw fallback, and one facial
controller per actor, shown in a close conversation. Much of this already exists on main. This report
says what was found, what this branch adds, and what is still owed.

## 1. What was already on main

- **One controller per actor.** face_controller.gd is the only writer of an actor's face shapes. In a fixed
  order it composes expression, eyes, blink and speech, and it writes each shape once a frame.
  CastModelPresentation installs one per rebuilt body.
- **Blinks** run on the actor's own seeded clock, with double blinks.
- **Eyes** follow the attention layer: when a resident is looking at the player, the eyes are aimed at the
  camera ahead of the head.
- **Speech.** A timed line drives mouth shapes from a cue file, and an untimed line drives a restrained jaw.
  A written or silent line moves no mouth. Residents and the Harukiya staff call the untimed jaw while
  their own line is on the dialogue panel (order **w9189b10b24ac**).
- **Expression.** Eight named states exist. Only two are used today: "interest" when a conversation starts
  and "neutral" when it ends.

## 2. Capability audit

The audit was run on 22 bodies: the 20 rebuilt cast bodies, Lily and Stacy. It had two parts.

**Shape reach.** This was read from each glTF's morph-target bounds, with
`C:/ov/reports/npc_face_20261124/shape_reach.py`; the result is reach.json.

- All 20 cast bodies carry the same 67 face shapes on the same MPFB base head. They are identical in reach
  to 0.2 mm.
- Lily and Stacy carry 196 morph targets, because they have one extra lash-accent mesh.
- Every one of the 40 shapes the controller drives moves the skin.
- Eye turns move the eyeball mesh by up to 5.8 mm.
- The jaw and the open vowels move the teeth and tongue: jawOpen by 27 and 24 mm, viseme_aa by 14 and 13 mm.
- Blinks move the skin by 12.6 mm and the lashes by 15.5 mm.
- No shape the controller uses is empty on any body. The old shell bodies have no shapes and bind to
  nothing, as designed.

**Render.** The windowed NpcFaceAuditShot (this branch) frames every body at the head. It writes each shape
group directly, not through the controller, so easing and blink timing cannot hide a broken shape. There
were 17 beats per body: rest, blink, closed lips (PP), open jaw (aa), round (O), teeth on lip (FF), four
eye turns and seven expressions. That made 374 frames. Receipt:
C:/ov/logs/face_20261124/audit_shot.log.receipt.json. The contact sheets are in
C:/ov/reports/npc_face_20261124/sheets/, with all_overview.png showing every body.

What the frames show:

- **Lids close fully on every body.** Where a blink looked one-sided at small size (Juno, Nadia), the fringe
  covers one eye; both lids are shut.
- **Lips meet** on PP on every body. The open jaw shows teeth and tongue, and the eyes turn both ways
  together.
- **Defect: the closed upper lid.** When shut, the upper lid is a flat, smooth patch without the surrounding
  skin detail, and the lash strip lies across it as a striped band. It is plain on light and aged skin (Cal,
  Mae, Lena, Teresa, Mina, Lily, Adela) and barely visible on Malcolm and Sacha. It shows only close up; a
  blink lasts 0.2 s. It is a source repair, of the base head's lid UVs or texture and the lash card, in
  Blender. It is **not done here**.
- **Lash accents.** Lily's and Stacy's lash-accent mesh does not follow the squint shapes. It is not visible
  in these frames.
- **Expressions are restrained.** At conversation distance most read only faintly, by design of the
  current intensities in face_performance.json. Raising them changes how the cast act, which is Lily's call,
  so they are unchanged.

## 3. What this branch adds: gaze with intention

Before this branch the eyes held perfectly still on whatever attention chose. The controller now keeps
attention's choice of target and changes only how the eyes behave around it. The new **gaze** block in
face_performance.json drives this, and each actor has its own seeded stream, so their blink timing is
unchanged:

- **Saccades.** Every 0.6 to 2.2 s the eyes jump up to 1.5 degrees about the target.
- **A glance away.** As a spoken turn begins, there is a 55% chance of a glance 7 to 14 degrees aside for
  0.5 to 1.6 s. The eyes always come back when the line ends.
- **A blink with any gaze shift larger than 10 degrees.**

Cost: a few random draws and vector sums per bound actor per frame, with no new nodes. Not measured
separately.

NpcFaceControllerTest went from 31 to 35 checks and is now 35/0, with receipt
C:/ov/logs/face_20261124/controller.log.receipt.json. The four new checks are:

- held on a point, the eyes make small saccades (spread 0.01–0.12 of reach);
- some turns, not all, begin with a glance away;
- every turn ends back on the listener;
- a large shift carries a blink.

**Hash cascade.** face_controller.gd and face_performance.json are digest-bound. The LF digests were renewed
in:

- harukiya_staff_standing_columns.json;
- the regenerated harukiya_staff_profile_binding.gd (by `tools/audit_staff_standing_columns.py
  --generate-binding`, which passes `--check`);
- adela_pose_source_bindings.json;
- bass_current_rig_fixture.json;
- bass_current_rig_sources.json;
- harukiya_physical_candidate_manifest.json.

The receipts that digest these sources need renewal by their owner.

## 4. Still owed

- **Lip-sync to played speech.** No dialogue audio plays in the game yet. The recordings are outside the
  repo until Lily approves them, and runtime voice playback is a separate qualification step (see
  game/data/voice/README.md). The controller already takes cue files (`speak_cues`). The wiring from a
  playing line to its cues waits on voice playback.
- **The closed-lid repair** in the base head, in Blender.
- **A close conversation** reviewed at conversation distance and close up (plan section 8). Most
  conversations happen at a closed door. The pilot needs the door open or a luncheonette seat.

## 5. Mood reading (ruling npc_face_mood_source_20261124)

Lily ruled that feelings are to be read from mood, trust, temperament and the subject at hand, with the face
exaggerated and stage-acting gestures added. This is now built: **MoodReading** (mood_reading.gd and
mood_reading.json). It uses rules and weights only; no model is involved (RUL-015). For each line a resident
says, it scores the eight expressions from:

- **the line itself:** word and phrase cues matched whole, and its punctuation;
- **trust:** the resident's trust in the player, warm at 3 and cold below 0;
- **temperament:** the resident's traits in resident_motives.json, centred so that 0.5 leans neither way;
- **the last exchange:** whether trust rose or fell since the previous line.

The strongest feeling is shown at up to 1.7 times its written size. The controller now accepts intensities up
to 2, and each shape still stops at its own full extent. Below the settle threshold the face rests on
interest, as it did before.

When a feeling is strong, the resident's actor plays a gesture from the shared cast clips. The new
AnimatedResident.stage_emote plays it only while the resident stands still, never more often than every
5 s, and returns to the clip it interrupted. Mina's gestures go through her own behaviour. The Harukiya staff
get the face reading only, because their bodies keep their staged show poses.

Over the 550 authored dialogue lines the reading gives:

| Feeling | Lines |
|---|---|
| interest (including the resting face) | 294 |
| recognition | 78 |
| frustration | 65 |
| sadness | 48 |
| concern | 41 |
| amusement | 19 |
| surprise | 5 |

46 lines carry a gesture. NpcMoodReadingTest is 17/0; its receipt is
C:/ov/logs/face_20261124/m_mood.log.receipt.json.

This is a first draft for Lily to read in play. Dry humour rarely uses joke words, so amusement is
under-read. All the weights are in the data file.
