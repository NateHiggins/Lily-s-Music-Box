Evidence class: **INERT**

# Voice line intake and character direction

Status: authoring tools rebased onto current V2 main for intake closure. Lily
approved all twenty-two fresh auditions and ordered full authored dialogue
generation. That broader production and runtime integration remain unfinished.
The November 11 producer is no longer live; its frozen case and original partial
outputs are preserved, not silently restarted. This document is not runtime proof.

Codex owns work order **w55379c52f884**. Fable owns the character controller,
dialogue integration and its playback lifecycle. Lily expanded intake to
include official character voice descriptions and proposed dialogue punch-up
for casting. On November 11 she superseded her initial Cal and Stacy selection
and asked for fresh voices informed by the characters.

The authoring registry is `game/data/voice/voice_profiles.json`. Its entries
cover the eighteen resident identities, two separate guest variants, Stacy,
Adela, Mara, Lily, the companion and the silent player host. The cast voice
map supplies characterization. Timbre and regional directions are casting
choices for this pass. Stacy's New Orleans origin comes from her source
dialogue. Each eligible speaking profile carries a proposed audition line
and acting intent. Twenty-two voices are in the first casting round.
Lily selected all twenty-two fresh takes. Their registry references preserve
exact WAV hashes, transcripts and prompts. The frozen first-round requests stay
unchanged as those decisions update the current registry. Lily's own profile
still requires her recorded reference; the companion remains written.

The intake command exports exact dialogue text and stable tree/node IDs,
prepares Omni Studio requests from the character profile, and aligns named
WAVs through Rhubarb with GHX mouth shapes. Its recording sheet explicitly
marks written and silent material. The cue files use Rhubarb's JSON schema.
The reference workflow validates exact audio hashes and transcripts once a
voice is chosen. Audio remains in the external authoring bank and Omni Studio.

The registry has explicit authoring-data file and field exceptions in the
reader gate, with the Python intake tool as its consumer. The game receives authored
recordings and timing files. No speech model is added to the runtime.

Usage and reference recovery are documented in `game/data/voice/README.md`.
Casting drafts need contextual review against the scene's clues and choices
before integration. The recording sheet retains the source dialogue text.

## November 13 intake closure

The recording ID remains **tree__node.wav**. The repaired intake binds each cue
output to the recording bytes, exact UTF-8 dialogue hint, selected Rhubarb binary
and reported version. Matching inputs and cue hashes permit reuse; stale,
unreceipted or malformed prior outputs refuse replacement. New recordings belong
in a fresh output directory. Failed attempts preserve earlier successful cues.
This verifies provenance and timing structure, not whether the actor actually
said the intended words; listening and transcript judgment remain human review.

The offline authoring tools, approved profiles, exact guest turns and speech-span
maps are delivered together. No generated WAV/OGG, partial runtime manifest,
resident controller or dialogue text is installed by this change. Rhubarb is a
separately installed development dependency; the game does not load it or an LLM.

Original partial generation: **resident_static_02** beneath
**C:/ov/reports/voice_dialogue_20261111/**. Its last progress file says 847 of 2670
parts at November 11 22:02 UTC; a later file census finds 848 part receipts and
734 packed OGGs, while the partial manifest has 736 entries. Those are distinct
observations, not verified completion totals. Reconcile receipts, failed attempts,
source freezes and original backend before resuming. Do not alter that case's
catalog, profiles or generated evidence to match newer source.

Closure verification is recorded under **C:/ov/reports/order_closures_20261113/**:
78 passing voice tool tests; a native Rhubarb 1.14.0 run over a copied approved
Cal audition (71 cues, 10.96 seconds), exact reuse and changed-hint refusal with
unchanged outputs; a 678-row base-dialogue sheet (511 spoken, 167 written); and
the reader gate with zero new blockers. The candidate static comparison is a
separate report in **verification01/**; read its terminal verdict. This closes only
recording naming and safe cue intake once integrated; full corpus, missing cast
mappings/Lily reference, current-source dynamic inventory, shipped manifest,
playback interruption and played lip-sync remain under **K-VOICE-PRODUCTION**.
