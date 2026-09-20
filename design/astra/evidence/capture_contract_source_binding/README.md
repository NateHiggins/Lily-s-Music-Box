# Runtime receipt source binding

`validation.json` records 105 passing selftests and 23 actual CLI red/green fixture pairs. It preserves all 13 earlier controls and adds arbitrary/non-test source rejection, missing runtime digest, changes to each runtime text input class, and input addition/removal. `negative_before.stderr.txt` records both new tests failing against the previous audit: a changed production script and an arbitrary JSON file both left the runtime gate falsely clear.

A schema-2 runtime contract must now name an existing root-relative `.gd` file under `game/tests`, match that file's SHA-256, and include `source.runtime_inputs_sha256`. The latter is SHA-256 of UTF-8 canonical JSON containing sorted `[relative_posix_path, raw_file_sha256]` pairs, with compact separators and no trailing newline. Its exact inputs are:

- `game/scripts/**/*.gd`
- `game/scenes/**/*.tscn`
- `game/scenes/**/*.tres`
- `game/data/**/*.json`
- `game/project.godot`

Changed bytes, names, additions, and removals change this digest. The repository head remains recorded provenance; current content hashes determine whether a receipt is stale. Texture and other asset hashes remain separate visual evidence. This runtime text digest does not establish visual equivalence or human acceptance.

The prior `capture_contract_repair` evidence, original historical capture receipt, and capture script remain unchanged. These runs did not invoke Godot or refresh the live ledger. Positive runtime receipts were confined to disposable synthetic fixtures; no production runtime PASS was created.
