# Reviewed audio-name relocation

`ac40f16` extracts construction of the existing AudioPolicy player from `_build_voice_pool` into `_make_voice`. The old constructor names each slot `"PolicyVoice%02d" % i`; the helper names that same indexed slot `"PolicyVoice%02d" % slot`. Pool creation passes the existing loop index to the helper, and source retirement replaces only its existing slot. `VOICE_CAP` remains 16. This is a relocation and reuse of the established generated-name family, not a newly authored spatial identity.

The audit identifies generated-name records by containing function. Consequently the unchanged name family produces new key `0a3fa1b3f7fc3ddc` for `_make_voice`, while old key `95bf669490ffbd85` for `_build_voice_pool` becomes a cleanup opportunity. Its classification, disposition, confidence, target fields and original rationale are otherwise identical.

The manifest correction changes **one existing record out of 3,626**, updating only its key, token, symbols, line (383) and context, plus a relocation-evidence note. Every byte outside that record is preserved. No manifest regeneration was performed. The retained original rationale is the audit's existing generic generated-name explanation; this correction does not claim that the bounded audio pool itself comes from layout data.

## Evidence

- `production_old.stdout.json`: actual pre-correction CLI exit 1, exactly one new failing record (`_make_voice`) and exactly one cleanup record (`_build_voice_pool`).
- `production_new.stdout.txt`: corrected CLI exit 0; no new failing records, stale preserved records, cleanup opportunities, classification changes, vanished targets or unresolved save contracts. The same 58 informational new records remain reported; none were added to the manifest.
- `record_before.json` and `record_after.json`: exact reviewed records.
- `receipt.json`: manifest hashes, byte-preservation check, record count, commands, exits and unchanged production AudioPolicy source hash.
- `full_selftest.stderr.txt`: all **52 tests pass**.

The new test uses the existing copied mini-repository fixture. It starts with the original reviewed naming family, relocates it, and executes the real CLI: the old manifest fails (1), a targeted migration of that one fixture record passes (0), and a separate unreviewed `UnreviewedVoice%02d` production helper still fails (1). The fixture output for each phase is preserved. Reproduce with `python design/astra/evidence/spatial_audio_relocation/run_checks.py`.

## Scope of the guard

The negative control proves that this exact relocation does not authorize another production generated-name record. The existing scanner groups generated names by function and does not compare a same-function template mutation. This narrow manifest migration neither expands nor repairs that pre-existing heuristic limitation; it must not be described as proof that every possible generated-template edit is detected.

Only `tools/orison_spatial_dependency_manifest.json`, `tools/tests/test_orison_spatial_dependencies.py`, and this evidence directory were changed by this assignment. No production changes, Godot execution, staging or commits.
