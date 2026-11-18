# Capture and delivery mechanics

## One edit, two clocks

Use integer output frames. A shot covers `[first_frame, first_frame + frame_count)`;
its last frame is the end minus one. Adjacent chunks must have no gaps or repeated
frames. Global movie time is frame/fps, independent of wall time and chunk age.
Audio uses measured sample duration. Document rounding to the frame grid and do
not accumulate subtitle millisecond rounding across lines.

Bind actor events, selected take IDs/hashes, cue markers and persistent props to
the same timeline. Warm render resources without advancing movie time. Test one
nonzero chunk start; a director that only works from zero cannot resume safely.

## Native Godot capture

Read current AGENTS.md for runner flags/ceilings. Use the patched Vulkan engine,
logged FIFO jobs and hidden desktop. CPU FFmpeg does not need the GPU lane; GPU
encoding/generation does. Discover live Omni tools and jobs instead of assuming
old routes or worker availability.

`tools/encode_sky_film.py` is an existing RGB-pipe/FFmpeg example. Inspect its
current contract/output naming before adapting it; it is not a character director.
Advance the director deterministically, wait for completed viewport drawing, then
read back that frame. The first pilot used two render ticks per output frame as
a local settling choice, not a universal Godot requirement.

Proof the hardest pose, prop, mouth motion, reaction and lighting in a short native
exchange. Check a section seam too. Record resolution, fps, frame range, format,
encoder exit/hash, source manifest and engine/runner receipt. Screenshot/readback
timing is not a gameplay performance benchmark.

Freeze genuine consumed dependencies: director, actors, presentation scripts,
lights, selected audio/envelopes, timeline and inserts. Follow repository text
hash/attribute conventions. Check before/after capture. Do not refresh a freeze
silently after a source change; start a new case. Retain original failure logs.

## Sound and assembly

Keep source takes unmodified. Trim quiet padding to derived files with a guard
at each end, then recompute timing/envelopes. Avoid independent per-line loudness
normalization that destroys dynamics and distance. Inspect the selected interval
of generated music; a clean excerpt can be usable even if another interval clips.

Mix at a consistent sample rate/channel layout and choose a delivery-appropriate
loudness target. About -16 LUFS stereo was used for the first web POC; this is not
a universal broadcast requirement. Keep authored silent endings exact in PCM.
AAC may leave a few milliseconds of overlap residue at the boundary. Measure and
disclose it, distinguishing codec residue from a new sound cue; do not claim
nonzero encoded samples are exact zero or repeatedly re-encode needlessly.

Prefer a cut or existing plate to another full render where it preserves intent.
Disclose proxies: an editorial storm does not qualify the game's weather system.
Keep title lettering authored and editable. Preserve intentional black/silence;
do not add a sting, credits or joke that changes the dramatic ending.

Stream-copy concat matching section codec/layout/timebase; re-encode where filters
need it. Remuxing can change compressed packet headers without changing pictures.
Packet hashes are not an image-equivalence oracle. If equivalence is necessary,
compare decoded frames in a consistent format. Often a fresh cheap concat of
already validated/hash-matching sections is the simpler reliable path.

## Final verification

- Check expected frame count, fps, resolution, duration and audio/subtitle streams.
  Decode the complete final audio/video once and preserve the results.
- Compare embedded subtitle text/timing to the selected edit; include a matching
  SRT for later use. Do not burn text over faces unless requested.
- Inspect final native frames around inserts/seams, expressions and the ending.
  Verify every frame of a required black ending and measure decoded audio tails.
- For finished delivery, review the whole film with sound. If only automated
  decoding/ASR and sampled stills were possible, leave pacing, performance and
  artistic acceptance unclaimed.

Do not rerun unchanged full captures for documentation edits. An isolated private
film edit needs no whole-game qualification suite; actual gameplay/rig changes
retain their ordinary tests and acceptance gates.
