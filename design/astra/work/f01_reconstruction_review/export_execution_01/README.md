# Clean C1 external export execution plan — prepared, unrun

This is a thin outer instrument for the exact clean C1 adapter and controller from `c34ad283df148496fbd98e68638470835c930c5c`. It does not rewrite those sources or install a geometry provider. The canonical ten-file source replay was installed and tested by root separately. C1 remains human-pending; generated output is disposable reconstruction evidence, not production F01 acceptance.

Root reviewed the current generator's dynamic input reads and every `_image` call family. The plan binds that exact generator, adapter, material catalog, texture mapping, layouts and exterior regions. No extra local module import was found beyond the ten replayed C1/C0 files; other imports are the Python standard library and Blender's `bpy`. The plan does not run or import `build_orison.py` or `gen_layout.py` during preparation. The latter, roof assets and master blend receive additional read-only protection.

## Bound inputs and executable

`plan.json` lists 2,071 unique input or absence paths: 1,325 existing files and 746 absent choices at preparation. This includes all 17 protected files, all 304 protected F01 image dependencies, the ten exact replay files, all 240 mapped material sets with both metadata alternatives, all overlay albedo/roughness choices, optional glass maps, ten FX albedos and their companion choices, and all 30 authored/fallback F01 wallfinish pairs. Input hashes are deliberately deferred to `bind`; their existence as well as bytes must then remain identical after both exports. The generator and material decision sources are pinned to their reviewed preparation hashes before binding, so a changed texture mapping cannot silently reuse an old path closure.

The located binary is `C:\Program Files\Blender Foundation\Blender 5.2\blender.exe` (112,975,320 bytes). Its path label is not a runtime version observation. `bind` freshly hashes this executable; the actual Blender startup text is retained when export runs. The Python executable in the reviewed environment is `C:\Users\nate_\AppData\Local\Programs\Python\Python312\python.exe`; binding records its actual path and hash too.

Each Blender child has a 1,200-second timeout. On expiration, the bridge terminates only the exact child it created, waits ten seconds, and kills only that same child if needed. It records the real child return code and forced termination separately; timeout is never an accepted export. No name-based process termination or output deletion exists. An external hard kill of the outer Python process is outside this cleanup guarantee: preserve the recorded Blender PID and partial files, inspect the process census, and resolve that exact owned process before another stage. Never start another exporter while a Godot or Blender process remains.

## Exact commands after review and exclusive-lane handoff

Run these serially from `C:\PleaseRemainOnTheLine-astra`, using the same Python executable throughout. `plan` is a compact read-only summary. `bind` hashes inputs and binaries but launches no engine. Stop after any nonzero exit; preserve the evidence and external output unchanged. Review export A's raw streams before permitting B.

```powershell
python -B design/astra/work/f01_reconstruction_review/export_execution_01/outer.py plan
python -B design/astra/work/f01_reconstruction_review/export_execution_01/outer.py bind
python -B design/astra/work/f01_reconstruction_review/export_execution_01/outer.py export_a
python -B design/astra/work/f01_reconstruction_review/export_execution_01/outer.py export_b
python -B design/astra/work/f01_reconstruction_review/export_execution_01/verify_outputs.py
```

Fresh external outputs are `C:\OrisonF01Reconstruction\astra_77dc_export_a_01` and `C:\OrisonF01Reconstruction\astra_77dc_export_b_01`. Neither existed at preparation. The wrapper refuses existing output directories and offers no cleanup action. Evidence goes to `design/astra/evidence/f01_source_export/export_01`, which must also be fresh at binding. For a retry after an observed failure, preserve this whole package/run and prepare a newly named revision/output pair; do not overwrite a receipt or relax an expected count.

The wrapper checks an empty Godot/Blender process census before binding, before each export, and after each child before the next stage. A census failure or active process refuses the stage. Before/after raw hashes cover the full closure and all 17 protected files; each protected file also has HEAD, index and clean-filtered working-tree Git blob IDs. Hashing or Git failures remain failures, including missing protected files. An exception after launch still enters the final snapshot and result path. Parent callers should additionally retain their outer command stdout/stderr and exact process exit to preserve preflight refusal tracebacks or a hard process interruption.

## Raw capture seam and limits of the original controller

The original controller guards only 34 paths: the F01 descriptor/BIN, both layouts and 30 wallfinish fallback images. It does not cover all 17 protected files or guarantee its post-checks after every early exception. It calls `subprocess.run(text=True, encoding="utf-8", errors="replace")`, hashes re-encoded normalized text, and retains only error tails. Its hashes are not raw byte evidence.

`child_capture_bridge.py` executes the exact installed controller using `runpy`. It intercepts only the one exact expected Blender `subprocess.run` command and keyword set. The real child writes directly to `blender.stdout.raw` and `blender.stderr.raw`. The bridge reconstructs the same UTF-8 replacement and universal-newline text for the unchanged controller. This is explicitly instrumented process capture, not an uninstrumented controller run. Unexpected or duplicate child calls refuse. `actual_blender_exit`, `actual_controller_exit`, `actual_bridge_exit` and `outer_contract_exit` remain distinct.

The bridge itself and `outer.py`, `verify_outputs.py`, `plan.json`, Python binary and exact C1 files are hash-bound. Each export retains command/config/environment, raw controller output, raw Blender output, the child's PID/exit/timing, controller status, input snapshots, process census and an artifact map. Every raw stream is retained even when the child or C1 rejects the output. The wrapper does not classify arbitrary Blender diagnostics: raw stdout and stderr require review, even if native exit is zero.

## Independent output checks and retained C1 proof

`verify_outputs.py` imports no generator or C1 implementation. It requires both successful source-stable outer runs and their mandatory raw/source artifacts. It independently rehashes every transaction artifact and generated file, verifies JSON closure and URI containment, resolves actual cell node/mesh/primitive addresses, derives aliases from contribution rows, and compares the 5,286 source identities/owners against the exact catalog. It requires all 17 cells, 189 distinct semantics, 531 legacy aliases including 47 multiple-target aliases, and the historical 609 primitives / 183,726 triangles / 345,536 referenced vertices. It verifies all three explicit supplemental sources and the separate bodega threshold semantics.

The candidate glTF/BIN and 17 cell glTF/BIN pairs are compared byte-for-byte across the two fresh output directories: 36 deterministic files. Full ownership/contribution/alias/semantic payloads must also match. Absolute output paths and their derived run IDs differ by design; process receipts are checked internally rather than falsely declared portable byte matches. Image URIs must resolve inside their respective disposable output. All output hashes are retained.

The exact C1 implementation still supplies its separate canonical material, collision, transform, vertex and triangle payload equivalence proof. The new checker does not claim to independently reimplement that geometry parser. Passing export checks establishes neither real root consumer integration, streaming/residency behavior, visual quality, player traversal nor human adoption. No Godot or Blender runtime has been performed by this preparation.

## Offline verification

`test_preparation.py` uses fake child objects and inert temporary files only. Ten controls cover raw-byte/newline separation, changed command and decode contract refusal, duplicate child refusal, owned timeout exit preservation, empty/live/failed census results, missing protected-file snapshot retention, and output escape/missing-file refusal. These are process-boundary controls, not export evidence or arbitrary-schema completeness. Syntax parsing of all five preparation Python files is recorded separately in `preparation_receipt.json`; no Blender source is imported by that check.
