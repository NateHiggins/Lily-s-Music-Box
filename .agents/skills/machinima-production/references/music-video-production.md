# Music-video production

Use this mode for a song performed by existing game characters. It extends the
shared cinematic style and capture guide; it does not replace the approved music,
change a character's permanent voice, qualify gameplay or authorize publishing.

## Recover the musical authority

Record the selected master hash, sample count, rate, channels and full duration.
Keep the master unchanged. Derive delivery gain and frame-grid tail padding in
separate files. Confirm who leads, who supports and who plays each instrument.
Carry those assignments through the shot list, performance cues and credits.

Inspect available stems and transcripts before generating anything. In the first
Pull Up a Chair pass, embedded captions began several seconds before singing.
They were useful lyric text, but not reliable singing timestamps. An intro with
music must not make the singer's mouth move.

## Derive singing and playing from the same recording

If stems are unavailable, a bounded separation pass can supply development-only
vocals, piano and drums. Recombine nothing into the selected master. Record model
and source hashes, tool versions and limits. Queue GPU separation/ASR on the same
lane as native rendering; CPU cue compilation can run independently. Reuse exact
unchanged stems and acoustic outputs after a cue-code correction.

Start with a short excerpt containing instrumental silence, sung words and a
held vowel. Compare actual recognition to the authored lyric, including repeated
words and contractions. Forced alignment alone can force the wrong words onto
sound. Preserve confidence and flag doubtful words or crop boundaries. Where
available, native ASR token durations provide an independent acoustic anchor.

For this project's A–H/X mouth cues, map pronunciation onto aligned word/character
intervals, extend the vowel through its measured sustain, and close through
instrumental gaps. Gate strength with isolated vocals rather than whole-mix RMS.
Character-to-phone interpolation remains an approximation; do not call it measured
phoneme alignment. Use absolute-time blending so pickups reproduce the same face.

Separate lead and harmony stems are ideal. A combined vocal stem cannot establish
which singer owns every note. If staging selected phrases as backing vocals,
record their exact intervals and this limitation; do not duplicate the lead mouth
through the whole song or claim to have generated a new harmony track.

Detect attacks from the appropriate instrument stems. Spectral-band drum events
can guide kick, snare and hi-hat choreography, but separation bleed and ambiguous
transients need inspection. Onset timing is not pitch transcription. Assign hands
and restrained key-range changes explicitly unless a reliable score/MIDI exists.

Keep one frozen cue artifact with:

- master path/hash, duration and analysis provenance;
- lead and harmony start/end/viseme/strength rows;
- vocal envelope, sample rate and silence policy;
- instrument time/type/strength and optional side rows;
- selected backing phrases, confidence findings and declared approximations.

## Fit the musicians to actual instruments

Inspect native meshes, contact markers, moving parts, skeletons and inverse binds.
The existing Harukiya kit already has sticks, pedals, beater and contact metadata;
reuse them. A merged keyboard finish is not automatically a set of movable keys.
Do not fake an independent key press by moving the whole keyboard.

Measure seated support, limb reach and finger endpoints from the loaded source.
Use a defensible weighted skin witness; an overly strict single-bone threshold
can exclude every pelvis sample. Preserve that failure rather than guessing a
generic seat height. A distal fingertip witness does not prove the whole finger
pad clears the key.

Set the actor's root from the actual seated base pose before gaze calculation.
Translating the hips after gaze makes the eyes aim from standing height. Compose
posture, bounded gaze, instrument contact and face through one ordered modifier
pipeline; keep one face writer. Inspect seated skirts separately: disabling an
observer that fans a skirt does not qualify the garment's skinning.

For hands, derive the across-palm axis and orientation from the rig. A world-axis
curl can twist fingers instead of closing them; a numerically perfect fingertip
can still belong to an upside-down palm. Test both hands visually. Keep grips and
actual native stick transforms together. Let the physical kit assign its hand and
foot targets; a generic audio-side hint must not silently suppress those events.
Use anticipation, contact at the measured
attack and a restrained rebound; silence returns to a natural rest position.

Use analytic reach limits without stretching bones. Repair an unreachable target
through measured seat placement, posture or instrument adjustment within the
physical set. Record residuals for both hands and feet. A wide camera does not
repair a miss. Pedal-board and shoe-sole contacts need their own close view.

## Qualify the combined performance before the expensive capture

1. Render stills of seated support, palms/keys, closed stick grips, both drum
   targets and pedal contact. Review front and oblique views under final lighting.
   Keep faces readable without washing out skin with practical spill.
2. At known song times, render an instrumental closed mouth, an open lead vowel,
   a closed consonant, a held vowel, a selected harmony phrase and its release.
   Inspect actual loaded blend-shape values as well as the requested cue.
3. Inspect contact immediately before, at and after a real attack. Numerical
   residuals supplement the pictures; a successful scene exit is not contact QA.
   For procedural contact, sweep the song's actual event domain and preserve the
   worst frame/time and target. Copy mutable telemetry when taking a snapshot;
   otherwise every witness can silently become the final frame's state.
4. Seek to a nonzero time, seek elsewhere and return. Compare final pose, mouth
   and prop state. Warm up without advancing movie time. Test section boundaries.
5. Capture a short moving proof with the exact matching audio interval. Then
   freeze director, edit, cues, actors, instruments, surfaces and encoder inputs.
   Capture bounded sections using the shared delivery guide.

Retain original failed proofs and source versions. After assembly, check every
shot, the section seam, credits, ending, exact frame/audio duration and full decode.
Distinguish source/cue checks, rendered still review, continuous audiovisual review
and the owner's artistic acceptance. Record inherited asset defects plainly.
Keep the reusable process in this skill and case-specific receipts outside it.
