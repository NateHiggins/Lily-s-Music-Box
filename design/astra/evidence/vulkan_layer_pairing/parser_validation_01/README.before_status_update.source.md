This is an isolated Forward+ reproduction candidate for Godot issue [#121989](https://github.com/godotengine/godot/issues/121989) and fix [#122064](https://github.com/godotengine/godot/pull/122064). It does not load or modify the live game. Matching installed source and candidate limitations are recorded in [the source review](../../reviews/vulkan_layer_pairing_review.md).

No engine is installed or upgraded. `run_case.py` delegates exclusively to the unchanged repository serial runner, uses a new project copy and APPDATA for each run, and records both real engine exit and a separate diagnostic gate. Run names must be new; results are never overwritten. `--prepare-only` creates the exact run material without launching any process and cannot subsequently be promoted to an executed receipt.

Godot lane order is title/launch validation, storage interruption/restart validation, then these standalone cases. An explicit owner release is required before launch. The shared runner's mutex/process census is a second safeguard. Every case is windowed at 1280×720 on the installed Vulkan Forward+ engine. No renderer fallback or host layer-manifest change is allowed.

| Case | Controlled operation | Required evidence |
| --- | --- | --- |
| static | No layer or scenario changes; light deletion | Functional checks, target and neighbor visible, no pairing/retention diagnostics |
| raw | Exact repeated 1→0→1 layer sequence, then light deletion while hidden | Correct visible/hidden pixels and actual pairing diagnostic red |
| candidate | Same sequence with same-scenario rebind before each actual change | Correct draw states, 15 changes/15 rebinds, unchanged requests cause no rebind, zero pairing/retention diagnostics |
| omission | Candidate copy with only the rebind operation/counter removed | Preserved omission diff, same layer sequence/draw expectations, actual pairing diagnostic red |

Invocation after explicit lane release: `python design/astra/work/vulkan_pairing/run_case.py CASE UNIQUE_RUN_NAME`. Raw/omission are expected to return CLI exit1 with engine exit0 if the original defect reproduces. A red scene cannot be accepted as a green workaround because its engine exited0. Host loader JSON failures remain in raw logs and separately counted; unrelated errors still fail.

`passage` and `street_core` are independent blocker owners. Releasing one while the other remains cannot restore layers. The helper captures the exact authored mask, never changes Node3D.visible, and guards unchanged masks before scenario work. The primitive neighbor has separate layer and visibility ownership. Six rendered hide/restore cycles follow the overlapping-blocker/idempotency checks. Timings include known frame waits and are only descriptive smoke measurements, not a production performance benchmark.

Four PNGs and per-image orange/cyan sample counts bind the draw checks to rendered output. A reviewer must inspect all images before reporting the candidate visually consistent. These primitives do not validate the game, skeletal instances, GI/LOD, SubViewport worlds, or the previous F04 owner-visibility regression.

Only if all four controls produce their required results should root consider a source-native helper in `_zone_toggle`. Production follow-up must retain both blocker tables and original mask restoration, test hidden owners/parents and SubViewport scenario identity, and run StreetCoreVisibilityTest, PassageVisibilityTest, repeated STREET→PASSAGE→ORISON/F04 transitions, frame-cost comparison and fresh V1 capture/world retirement. Residual pairing errors belong to root's renderer integration investigation; no other layer writer is implicitly cleared by this isolated proof. Asset/texture hashes and human visual acceptance remain separate from this code-only primitive fixture.
