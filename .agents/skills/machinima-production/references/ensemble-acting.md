# First Light and ensemble acting

## Establish the take

Start with the [installed First Light scene](../../../../game/film/first_light.tscn).
Use the [capture launcher](../../../../tools/render_first_light.py) for a new private
case. Its `--frames` option compresses the entire blocking into a short proof.
Use full-duration timing to judge a pause, the onset of a word or a hand landing.
The [cinema production plan](../../../../design/CINEMA_DUAL_PIPELINE_PLAN_2026-11-26.md)
identifies the working components and the proposed episode tools.

Give the film camera an explicit handoff from the current perspective camera.
Sample lens, focus target, dolly and handheld offsets from the absolute frame.
On a cut, cancellation or teardown, return the prior camera and HUD ownership.
The render manager counts consecutive movie frames and drains the last audio
block. Verify decoded first and last frames and PCM sample counts for each stem.
At 48 kHz the 45-second 1080p24 study yielded 1,080 frames and 2,160,000 samples
per channel. Match the selected WAV to mouth motion and the on-camera physical
act to its sound. Vantry's meter stayed still through the contact ticks in First
Light. Watch the take muted and ask a fresh viewer where the contact occurred.
Then listen without picture and check that rain leaves the onset audible.

Keep the native master and isolated buses. First Light recorded Weather,
Machinery and Dialogue. Some companion sounds reached the stereo master through
their own routes, so summing the stems cannot reconstruct that master. Grade
and gain the screening copy separately and verify delay compensation. The
reviewed copy measured −23.2 LUFS integrated and −2.1 dBTP. Set the target
for each delivery. This was an SDR Rec.709 workflow.

Measure a representative high-resolution sample before booking the lane. The
72-frame 4K60 lossless trial took 160 seconds. A different 48-frame 4K24
MJPEG/PCM trial took 14 seconds and occupied 23.3 MB. Use timings at the actual
delivery settings for estimates. For AVI, pass the same-resolution trial to
`--avi-reference` so the launcher checks the container size budget.

## Block the actors in the installed world

For a historical visit, start with the corresponding entry in the
[loop scene direction book](../../../../design/LOOP_SCENE_DIRECTION_2026-11-26.md).
It covers the thirteen destinations and the seven incidental exchanges. Read
the actual anchor steps and dated cast phases before changing the blocking.

Record the civil date, loop visit, current knowledge, available props, audience
position, actor ownership and wardrobe alongside the camera and audio inputs.
For the Harukiya, Adela sings lead at the piano, Lily plays bass and sings
harmony, and Stacy drums. The shared show transport owns the released song.
Let the actual stage approach finish before handing bones to instrument contact
and using song time for attacks and mouth cues. On interruption, release gaze,
voice, hands and instrument presentation back to their previous owners. Check
the actual inventory holder after a mid-song transfer.

Start an interactive rehearsal from outside the room once. Test the ordinary
door, player capsule, line of sight and conversation selection. For the March
18 rehearsal the public west aisle worked; a resident detour clipped the edge
of a newspaper stack under the player's wider capsule. For an ensemble, inspect
every performer's route, the return trip and the first audible downbeat.
A visible trio at their marks proves only the posed composition.

## Seek and compare

Bind a take to a civil timestamp, a loop identity, a stable actor ID and its
performance inputs. Preserve leap day, authored gaps, death cutoffs and the
campaign's protected hours. A film-only seek may place an actor at an authored
mark in a private preview. In gameplay the route and arrival owner controls
entry into a scene. Render the same frame after linear playback and after a
pickup. Check both sides of a blink, word onset, instrument attack and release.

Give the body one writer per channel. Stage or locomotion supplies the base.
Prop work owns the required upper-body bones, micro-acting adds breathing and
tension on available bones, and attention aims eyes ahead of the head at an
actual speaker or prop. A camera cut should leave the actor's gaze on the same
person. Direct averted eyes as a character choice. Only a witnessed game event
can produce knowledge. Time a listener's anticipatory movement from the chosen
take; adding a universal delay to audio would move it off subtitles and score.

For a 15-second repeatability check at 24 fps, use two fresh profiles with the
same committed inputs and 360 absolute frame indices. Compare actor silhouettes
with matched mattes, sampled gaze and mouth poses at the same indices, and
audio onset/sample counts. A matching movie duration cannot show a missed
blink. Run `python tools/compare_machinima_takes.py TAKE_A TAKE_B --count 360`
on the two native PNG directories or the two identically generated matte
directories. It returns the first differing frame and pixel bounds. Record
the actor, writer and input that explain the change. Whole-image
differences may originate in temporal lighting or particles; inspect them
separately. Report the actual target, renderer and result.
