Evidence class: **INERT**

# Voice line intake and character direction

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
Lily judges the performances. She selected the fresh Mina and Cal takes;
their registry references preserve exact WAV hashes, transcripts and prompts.
Remaining timbres await her listening review. The frozen first-round requests
stay unchanged as those decisions update the current registry.

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
