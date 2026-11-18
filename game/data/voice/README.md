# Character voices

The per-character entries in `voice_profiles.json` are the official authoring
voice directions requested by Lily on November 11, 2026. The descriptions
follow the cast voice map. Lily requested a fresh casting round and superseded
the initial Cal and Stacy selection. She approved all twenty-two fresh takes
and ordered authored dialogue generation and lip-sync integration. Each selected
take carries exact reference metadata in its character profile. The earlier
WAVs are retained as experiment history.

An active reference, once selected, records its exact transcript, SHA-256,
original voice-design prompt and Studio job. An authoring machine supplies
that exact WAV through an explicit reference folder. Reference validation
protects a chosen voice against accidental replacement between lines.
The selected November 11 references are currently stored at
`C:/ov/voice-references/20261111_cast_round01`. Restore those WAVs into an
explicit reference folder on another authoring machine and verify their registry
hashes. Generated requests fail safely if a selected reference is unavailable.
The round's frozen request sheet and profile snapshot stay unchanged when a
listening decision updates the current registry.

## Production batches

`tools/voice/catalog.py` inventories authored base, mystery, opinion and Mina
case nodes, including explicit speaker overrides. `guest_turns.json` attributes
exact Unicode character spans to the two approved guest voices without changing
the source text. Silent material, missing references and uncast speakers remain
explicit exclusions. Supplemental dynamic providers use exact source bindings.

```powershell
python tools/voice/produce.py plan --case C:/ov/reports/voice/new_case --reference-root C:/ov/voice-references/20261111_cast_round01
python tools/voice/produce.py run --case C:/ov/reports/voice/new_case --reference-root C:/ov/voice-references/20261111_cast_round01
```

Planning refuses to replace an existing freeze. The producer uses Omni's
installed clone backend, checks source and reference hashes, and queues bounded
same-voice batches at medium priority. A kernel-backed case lock prevents duplicate
producers. Completed audio is verified and reused; original attempt outputs and
failure receipts remain intact. Each batch records actual native exit, inputs,
reference/backend hashes and output hashes. Identical words from the same voice
share a recording. Individual scripts above the word target remain single takes;
they are never silently rewritten or split. No speech model ships in the game.

Generated WAVs are authoring inputs. OGG encoding, cue alignment, word screening,
runtime playback, interruption and played face review are separate qualification
steps. Variable lists and ticket numbers use source-backed component clips;
their runtime chain must stop as a whole on interruption.

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
python tools/voice/intake.py request --line-id cal_dwyer__cd_open --reference-root C:/ov/voice-references/20261111_cast_round01
python tools/voice/intake.py request --profile-id mina_vale --text "The exact authored line." --reference-root C:/ov/voice-references/20261111_cast_round01
python tools/voice/intake.py request --profile-id stacy --audition
```

Pass the printed `kind` and `args` to Omni's `studio` tool. It generates WAVs
through the local Qwen3-TTS authoring backend and queues on the shared GPU
lane. Respect test priority through `lane_priority.py` before submission.

Voices with an active reference use its exact WAV and transcript with Qwen's
Base model. A missing or changed reference fails validation. Fresh auditions
use the description, accent direction, delivery guidance and fixed seed with
VoiceDesign. Audition requests also include the proposed line's acting intent.
Select a reference after listening before generating a production batch.
Lily's own profile requires her recorded reference. The transient guest group
requires a distinct A or B profile.

The shared opening sentence lets Lily compare voices on the same words.
The following character lines are proposed casting drafts. Their source-node
links indicate writing inspiration. They need scene-context review before
integration with clues, choices and flag changes. Stacy's New Orleans origin
is explicit in her dialogue. Other regional directions are provisional
casting choices and establish no new biography. Accent and acting judgments
belong to Lily. Transcription and signal checks provide technical review.

## Mouth timing

Put one WAV per spoken line in a recording folder using the sheet's exact
filename. Then run the installed Rhubarb 1.14.0 executable.

```powershell
python tools/voice/intake.py cues --wavs C:/ov/recordings --out-dir C:/ov/reports/voice/new_intake/cues --rhubarb C:/ov/tools/rhubarb/Rhubarb-Lip-Sync-1.14.0-Windows/rhubarb.exe
```

The command writes `<line_id>.cues.json` here. It supplies the authored text
as a recognition hint and requests JSON with extended shapes GHX. Timings
and mouth shapes keep Rhubarb's schema. `metadata.soundFile` becomes the
source WAV basename so the output carries no machine-specific directory.
The output directory is required: intake never defaults to the production data
folder. Each cue has a matching `<line_id>.cues.receipt.json`, binding exact WAV
bytes, authored transcript bytes, Rhubarb executable SHA-256, verified 1.14.0
version, GHX options and output SHA-256. Optionally supply
`--expected-rhubarb-sha256 HASH` to require a previously approved binary hash.
The default records the observed binary hash; it does not authenticate its vendor.

Complete cue and receipt files are published exclusively, without replacement.
An exact receipted input/output match reuses the cues without realigning. Missing,
malformed, stale or changed receipts/output are refused. Keep the original case
and use a fresh output directory for changed writing, recordings or tool binaries;
do not delete the old evidence merely to make a rerun pass. A failure preserves
existing output and returns nonzero; earlier successful lines remain available.
If interrupted between cue and receipt publication, the incomplete pair is also
refused rather than guessed valid. Binary identity is rechecked after alignment.

Owner-recorded WAVs need no synthesized reference: named recordings enter directly
through `cues`. The transcript is an exact authored recognition hint, **not an
acoustic check that the performer said those words**. Listen/review separately.
The default sheet still covers the base dialogue folder; this intake does not
approve held Lily lines or automatically extend the full production catalog.

The runtime face controller reads `mouthCues` rows of `start`, `end`, `value`.
Fable owns connecting those cues to actual playback and its interruptions.
After recording approval, the matching runtime audio is `<line_id>.ogg`.
Recordings remain outside Git until Lily approves their inclusion. Runtime
speech uses authored audio and precomputed cues.
