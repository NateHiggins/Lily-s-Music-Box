---
name: machinima-production
description: Plan, voice, stage, capture and edit scripted films and music videos using existing game scenes and characters. Use for machinima, sung performances and voiced cinematic proofs; ordinary gameplay recordings do not need the full production workflow.
---

# Film the existing game

Deliver an actual movie at the requested level of finish. A proof of concept
can use existing rigs and scratch Foley; finished drama needs convincing acting
and a continuous audiovisual review. A timeline or technical pass is not a film
review. This skill does not authorize canon changes, cast rebuilding or upload.

Follow [godot-development](../godot-development/SKILL.md) for native capture.
Route necessary mesh/material repairs to existing asset/shader skills. Keep
private likeness sources, prompts and review media outside the public repo.

## Apply the game's cinematic style

For Please Stay on the Line, use **Neo-Noir Neon 1929**, adopted by Lily in
[the Bible](../../../design/ORISON_BIBLE.md), §VIII.5, dated 2026-11-12
(RUL-017). Read [the production style guide](references/neo-noir-neon-1929.md)
before a shot list, lighting pass or capture. It preserves the owner's numeric
targets and translates them into testable camera, lighting and edit decisions.
The style is adopted; a particular scene is not qualified merely by citing it.
For unrelated games, use their own visual direction rather than imposing this one.

For a music video, recover the exact approved full track, duration and available
lyric cues first. Cut picture to musical phrases without shortening the song or
inventing lyric timing. Keep the selected master unchanged; derive any delivery
gain in a separate mix. An audio-caption window is not phoneme alignment.
Read [music-video production](references/music-video-production.md) for singing,
backing vocals, instrument contacts and their combined proof before full capture.

## Prepare the production

- Recover the authored script, line IDs, shot budgets, cast references and latest
  owner decisions. Preserve words unless rewriting is requested. Separate film
  staging from gameplay/narrative authority.
- Inspect installed actors, skeletons, face shapes, material bindings and usable
  sets/footage before generating anything. Matching filenames do not establish
  matching rig capability. Use the imported result as the practical baseline.
- Choose resolution, frame rate, duration and critical visible story beats.
  Estimate time/storage from a representative short voiced proof. A word-light
  script padded to ten minutes is not automatically well paced: give silent
  holds intentional action and reactions, and preview them with sound.
- Use one integration owner. When independent agents are authorized, give audio,
  performance and editorial named output ownership and explicit dependencies.
  Freeze their common selected-take timeline before the expensive capture.

## Voice and edit are one source of timing

Use each approved character voice reference and its hash. A temporary film voice
does not replace the permanent game profile. Discover Omni's current Studio
capabilities; do not invent model parameters or promise unsupported acting control.
Batch lines with one model load where supported. Review a representative exchange
before generating every line.

Record line ID, exact text, voice reference, settings/seed, take path, hash,
sample format and measured duration. Keep original takes; trim into new files
with a quiet guard so initial consonants survive. ASR flags possible word errors;
it does not judge accents or acting. Inspect ambiguous short lines/contractions
before regenerating. Make selection explicit, then derive subtitles, duration
and mouth envelopes from those same selected WAVs. A take swap invalidates its
dependent timing and envelopes. Do not silently time-stretch dialogue to fit.

Compile actor events, cue markers, speech, pauses and physical business into one
edit. Evaluate the director at absolute movie time; a pickup or later chunk must
not depend on playback from zero. Use one ordered skeletal pose writer and one
face-shape writer. RMS jaw motion is a POC fallback, not phoneme-aligned lip-sync.

## Make the action readable

Use an isolated film fixture that borrows actual set/material presentation while
preserving save, clock, inventory and other gameplay owners. Restore borrowed
state on exit. Disable competing autonomous presentation only within the fixture.

Block actors, props and cameras together. Review the master and hardest close-up
early: eye lines, turn direction, foreground obstructions, gripping, cables,
cloth, hair and night contrast. An enabled action flag does not prove the audience
can see it. Hands hovering near keys or holding invisible brushes need better
staging. Detailed prop/instrument contact requires authored or contact-aware poses.

Support beats with gaze, blinks, breathing, expressions and restrained gestures.
Camera concealment of a broken seated rig may salvage a POC; it is not a repaired
production actor. State that limitation rather than silently promoting the workaround.

Establish story props in the image. Capture an in-story photograph from the actual
posed actors and reuse it later. If set geometry hides it, a brief editorial insert
can communicate the beat without reopening the full render. Inspect the inserted
image and both cut boundaries in the final encoded film.

## Capture and finish

Read [capture and delivery](references/capture-and-delivery.md) when implementing
timing, native recording, encoding or final QA.

1. Run a short voiced native proof through the patched engine and FIFO lane on
   the hidden desktop. Inspect frames, audio as capabilities allow, receipts and
   storage cost. Preserve Lily's mouse; recover process identity/custody after a
   reset instead of duplicating a live job.
2. Freeze consumed inputs and record their hashes. Capture bounded sections with
   explicit first/count/last frame and requeue between sections. Preserve failures;
   resume only unfinished ranges after confirming the earlier process ended.
3. Use Omni for missing title art, music or SFX when useful. Keep exact authored
   lettering separate from generated background art. Record provenance, inspect
   selected music intervals for clipping, and leave room for dialogue and silence.
4. Assemble from one edit. Reuse unchanged validated footage; a fresh stream-copy
   concat is often cheaper than an elaborate reuse comparison. Re-encode once
   where inserts/filters require it. Do not rerender for a report correction.
5. Verify exact duration/frame ranges, streams, full decode, subtitles, edit seams,
   title/date legibility and ending. Distinguish automated checks, sampled still
   review, continuous listening/viewing and artistic acceptance. Claim only what
   actually happened. Deliver movie, useful subtitle sidecar and concise limits.

Film receipts do not qualify ordinary gameplay, saves or the production rig.
Do not upload or publish without authorization.

## Retire an experiment

Preserve the authored script/shot data, reusable production sources and compact
provenance/review records. Treat intermediate movies, test takes, mixes, review
frames, copied assets and import caches as separate cleanup candidates. Check
live jobs, custody and external consumers; hash-check a retained source copy.
Resolve exact paths and reject junction/symlink traversal.

Use the project's retention workflow by default. If the owner explicitly asks
for immediate disposal, record that scoped exception and a path/hash/size manifest
before deletion. An old hold does not override the new request. Preserve unrelated
source art, approved voice references, game qualification evidence, model weights
and other agents' work. Delete only named eligible files, measure reclaimed bytes,
and mark old delivery links as retired without rewriting historical results.
Close the exercise in the tracker instead of leaving a phantom active production.

The [pilot lessons](references/pilot-lessons.md) explain the observed failures.
Their durations, shot counts and local techniques are examples, not universal rules.
