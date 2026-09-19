# V2 terminal access: prepared production and focused proof

**Outside-game preparation only. No fixture installation or Godot run has occurred.** The required upcoming execution HEAD is `af9c5b6fdc42079d4bd64549b709a49ababa9e50`; preparation's earlier captured HEAD remains historical. Root must grant the exclusive source/engine lane before the commands below.

`terminal_access.patch` changes exactly two production files. The V2 runtime derives the mounted terminal's yaw from its actual operator anchor, then composes the existing DeskZone with the existing CallInterface. DeskZone gains a horizontal footprint setting whose default remains the V1 `1.6 × 1.8 m`; its height remains `1.6 m`. V2 binds the existing `F04_B_TERMINAL_USE` footprint, approximately `0.8 × 0.8 m`, at that reservation's XZ and the operator's floor height. The normal player ray starts 0.45 m outside this target; placing the large default zone at the operator would put its eye inside an Area, which the unchanged player ray does not hit from inside.

Adapter mounting still initially copies the semantic transform exactly. V2 composition subsequently turns the **mounted consumer only**. The original `F04_B_MONITOR_01_Semantic` transform, stable terminal ID, operator anchor, layout and selector remain unchanged. Acoustic binding is position-based. The focused fixture asserts the full original semantic basis/position and mounted position/scale. Its orientation oracle measures the exposed actual SignalScope cylinder cap, `-scope.global_basis.y` after the unchanged local Z90 rotation, rather than assuming a terminal root axis represents the geometry.

The 36-check `OrisonV2TerminalAccessTest` composes actual CampaignShell/V2 and the real player. It places the player at the authored operator, verifies the normal 2.1 m physics ray and actual prompt, injects the `interact` action for PlayerController's ordinary process polling, and checks reciprocal player/DeskZone/CallInterface ownership. It observes the real call panel, terminal stage and existing Telephone audio owner. Looking away then pressing interact proves seated E exits without reacquiring the ray. Reentry uses the physical ray; a real Escape key event exercises CallInterface's exit path. Missing entry prevents unrelated pause-UI activation and is recorded as a failed prerequisite, never a successful exit.

This exercises call opening and entry/exit only. The existing `fast_factor=0.05` test hook compresses narrative delays, and the fixture waits for the actual opener to finish before retirement. It does not route or complete a case, prove later V2 field-phase consumers, walk to the desk, measure body clearance, or establish performance/human acceptance. CallInterface, its audio release, Conductor, CaseLibrary and campaign authorities remain unchanged. All development reservation rendering also remains unchanged; its visual cleanup is separate.

## Source controls and execution

The original source is predicted to fail 20 of 36 checks (orientation plus missing access). Orientation omission removes only the consumer yaw operation and is predicted to fail the physical-front check. Desk omission removes only the complete desk creation/binding block while preserving orientation, predicting 19 access failures. Footprint omission removes only the V2 size assignment and predicts the authored-size failure. These are predictions until actual runtime evidence exists. Every omission uses exact candidate-byte replacement and preserves comment encoding and line endings.

Run only `runtime/run.py` as the controller. The byte-identical copied `core.py`, `support.py` and `runner_bridge.ps1` supply established snapshot, environment, engine/PID and JSON-array-splat mechanics. The controller explicitly overrides their repository/instrument locations and uses utility functions; `core.py`'s historical encroachment CLI is not a terminal entrypoint.

```powershell
python design/astra/work/v2_terminal_access_01/runtime/run.py install
python design/astra/work/v2_terminal_access_01/runtime/run.py 01_original
python design/astra/work/v2_terminal_access_01/runtime/run.py 02_candidate
python design/astra/work/v2_terminal_access_01/runtime/run.py 03_orientation_omission
python design/astra/work/v2_terminal_access_01/runtime/run.py 04_desk_omission
python design/astra/work/v2_terminal_access_01/runtime/run.py 05_footprint_omission
python design/astra/work/v2_terminal_access_01/runtime/run.py 06_restored_candidate
```

Inspect each actual result before continuing. All six requests are **windowed Vulkan Forward+**, with fresh APPDATA, Dummy audio output, a 60-second canonical serial cap and exact request equality checked before launch. A real display backend is required for mouse capture/release assertions. The unchanged canonical runner is invoked in isolated child PowerShell through the tested JSON/typed-array bridge, preserving its error/exit behavior.

Installation writes only the two new test files and preserves the two original owners. Each phase binds the actual execution HEAD, full game manifest, exactly 14 selected source copies, engine binaries, instruments, PID ancestry, raw logs, readable receipt, exact unique 36 ordered labels and footer, complete input/geometry facts and actual retirement. All artifact entries are verified, including required entries and manifest/source-copy equality. Each prior assessment is recomputed before the next phase. Exact source restoration is required and recorded after every phase; omissions restore candidate bytes in `finally`, after an empty process census. A failed candidate restores originals. Unexpected owned edits or a still-active process cause a refusal to overwrite.

`diagnostic_gate_exit` remains 1 for every ordinary failure. `control_contract_exit=0` on a declared omission means only that its exact negative contract was observed; it is not product acceptance. Runner refusal 73, cannot-run 78, timeout 124, parse errors, unknown native diagnostics, incomplete receipts and extra failures reject control progression. No unchanged retry is automatic.

The known native diagnostic pairs come from the preserved ordinary V2 diagnostic `terminal_operator_view_v2_01`: exact host-loader error/warning details and RGB8 conversion header/site pairs only. Counts remain in every receipt; new warnings, errors, pairing/retention findings reject admission. `offline_validation_01` retains the 15 passing synthetic tests for request equality, malformed/missing/altered receipts, changed source/PID/engine facts, exact negative failures, retirement, diagnostic debt, artifact omission/mutation and failed restoration. These tests do not parse GDScript or constitute runtime proof.

After a restored 36-check candidate, root still needs the separate actual windowed operator/phone capture and review. The prior ordinary 19/21 diagnostic, original fixture5ec, and raw evidence remain unchanged.
