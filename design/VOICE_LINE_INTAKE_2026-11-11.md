Evidence class: **INERT**

# Voice line intake and character direction

Codex owns work order **w55379c52f884**. Fable owns the character controller,
dialogue integration and its playback lifecycle. Lily expanded intake to
include official character voice descriptions and approved the Cal and Stacy
Omni voice experiments on November 11, 2026.

The authoring registry is `game/data/voice/voice_profiles.json`. Its entries
cover the eighteen resident identities, two separate guest variants, Stacy,
Adela, Mara, Lily, the companion and the silent player host. The cast voice
map supplies characterization. Physical timbre descriptions are casting
direction chosen for this pass. Two references have listening approval.
Remaining timbres await listening review. This does not establish final
performance or facial-animation acceptance for the cast.

The intake command exports exact dialogue text and stable tree/node IDs,
prepares Omni Studio requests from the character profile, and aligns named
WAVs through Rhubarb with GHX mouth shapes. Its recording sheet explicitly
marks written and silent material. The cue files use Rhubarb's JSON schema.
Selected voice references have hashes and transcripts. Their audio remains
in the external authoring bank and Omni Studio.

The registry has explicit authoring-data file and field exceptions in the
reader gate, with the Python intake tool as its consumer. The game receives authored
recordings and timing files. No speech model is added to the runtime.

Usage and reference recovery are documented in `game/data/voice/README.md`.
This delivery does not edit dialogue, cast meshes, rigs or runtime controllers.
