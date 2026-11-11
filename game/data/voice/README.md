# Character voices

The per-character entries in `voice_profiles.json` are the official authoring
voice directions requested by Lily on November 11, 2026. The descriptions
follow the cast voice map. New timbres need listening review. Cal and Stacy
have references selected by Lily from the Omni Studio experiments.

Each reference records its exact transcript, SHA-256, original voice-design
prompt and Studio job. Their WAV files are in the external authoring bank
`C:/ov/voice-references/20261111/`, named `cal_dwyer.wav` and `stacy.wav`.
The originals also remain in Omni Studio. Copy the two WAVs to another
authoring machine's reference folder and pass that folder explicitly.

## Recording sheet

Run from the repository root.

```powershell
python tools/voice/intake.py sheet --out C:/ov/reports/voice/recording_sheet.csv
```

The sheet covers `game/data/dialogue/*.json`. Every row preserves its tree,
node, speaker and exact text. A stable line ID combines the tree and node
with two underscores, for example `cal_dwyer__cd_open`. Reordering nodes
does not change IDs. The `delivery` column marks spoken, written and silent
content. Written and silent rows have no recording filename. Companion and
prologue messages stay written. The transient guests need separate A/B
performances for their marked turns. Choices and interface labels stay
outside the spoken recording list.

Mina, Adela and Lily have voice profiles even when their lines live outside
this dialogue folder. Other mystery trees and dynamically assembled lines
need a later explicit intake extension. The source dialogue is read only.

## Generate through Omni

Print a request for Omni's Studio voice tool.

```powershell
python tools/voice/intake.py request --line-id cal_dwyer__cd_open --reference-root C:/ov/voice-references/20261111
python tools/voice/intake.py request --profile-id mina_vale --text "The exact authored line."
```

Pass the printed `kind` and `args` to Omni's `studio` tool. It generates WAVs
through the local Qwen3-TTS authoring backend and queues on the shared GPU
lane. Respect test priority through `lane_priority.py` before submission.

Selected voices use their exact reference WAV and transcript with Qwen's
Base model. A missing or changed reference fails validation. Other voices
use their description, delivery direction and fixed seed with VoiceDesign
for a first audition. Select a reference after listening before generating
a production batch. Lily's own profile requires her recorded reference.
The transient guest group requires a distinct A or B profile.

## Mouth timing

Put one WAV per spoken line in a recording folder using the sheet's exact
filename. Then run the installed Rhubarb 1.14.0 executable.

```powershell
python tools/voice/intake.py cues --wavs C:/ov/recordings --rhubarb C:/ov/tools/rhubarb/Rhubarb-Lip-Sync-1.14.0-Windows/rhubarb.exe
```

The command writes `<line_id>.cues.json` here. It supplies the authored text
as a recognition hint and requests JSON with extended shapes GHX. Timings
and mouth shapes keep Rhubarb's schema. `metadata.soundFile` becomes the
source WAV basename so the output carries no machine-specific directory.
Each validated file is installed atomically. A failed line preserves its
previous cue file. A later failure leaves earlier successful lines available
and the command exits nonzero. Fix the cause and rerun the selected folder.

The runtime face controller reads `mouthCues` rows of `start`, `end`, `value`.
Fable owns connecting those cues to actual playback and its interruptions.
After recording approval, the matching runtime audio is `<line_id>.ogg`.
Recordings remain outside Git until Lily approves their inclusion. Runtime
speech uses authored audio and precomputed cues.
