# Hearing presence: preserved runtime validation

Root applied the apartment hearing-presence correction and the focused/composed fixtures at HEAD `e72320288d256e4d20386e8f28c116fe962788fc` with the current foundation repairs. Exact records are aggregated in `design/astra/evidence/hearing_presence/validation.json`. This review and dream_forensics' independent evidence check used preserved files only; neither launched Godot or changed production code.

The ledger now checks the existing home-presence authority before granting `in_home_hearing` or `heating_riser` knowledge through an apartment, including the source-unit fallback. An absent resident cannot learn through an empty flat; the present riser neighbor can still hear when the acoustic path and threshold permit it. Returning home grants no missed-event knowledge. A later sound can produce a new observation with its supplied campaign time and proper evidence route. Explicit actor-reported direct observations remain separate, and old stored beliefs are preserved.

| Preserved run | Raw result | Native/forwarded exit | Expected exit | Diagnostic gate |
| --- | --- | --- | --- | --- |
| `original_focused_01` | FAIL 8/13; five failed assertions | 5 | 6, mismatch | 1 |
| `original_composed_01` | Four failures among 23 checks; 19 passes | 4 | 4 | 1 |
| `candidate_focused_01` | PASS 13/13 | 0 | 0 | 0 |
| `candidate_composed_01` | PASS checks=23; 23 raw passes | 0 | 0 | 0 |
| `regression_authority_01` | PASS; 21 raw pass lines, no count in footer | 0 | 0 | 0 |
| `regression_matrix_01` | PASS 17/17 | 0 | 0 | 0 |

The original focused invocation mistakenly configured expected exit 6. The actual receipt retains `actual_exit=5`, `expected_exit=6`, `expected_exit_matches=false` and diagnostic gate 1. Its raw log has eight passes and five failures. This is valid evidence of the hearing defect, but it is **not** an expected-exit-matched control. No receipt or claim was rewritten to turn five failures into six.

Those five focused failures concern the only-present listener set, the absent source-flat belief, return replay, the absent riser neighbor and the source-unit fallback. Existing threshold, local/propagated provenance, supplied clock, copied evidence, deduplication and explicit direct-observation checks already passed against the original. All 13 pass with the correction.

The original composed failures are absent hearing, retroactive learning on return, V2 reconstruction, and V1 reconstruction. Both original and corrected composed runs use the revised helper that actually loads saved state, constructs the requested real root, and inspects its root-owned ledger. The old helper merely accepted a root ID while reloading the same global store; its historical results are not upgraded by this change. Reconstruction remains within one process, not a cold-start/restart proof.

The composed fixture keeps the radiator situation unoffered initially and after every reconstruction. It injects neutral observed events, so an unrelated autonomous radiator sound cannot masquerade as evidence replay. No production coordinator is paused. Timestamp comparison uses fixed absolute tolerance and a one-minute shifted rejection control; it does not use permissive relative comparison at large Gregorian-minute values.

All six receipts' 198 artifact hashes, all selected source copies, and all 12 before/after runtime manifests were verified independently with no mismatch. Every run has exactly 1,160 hashed runtime inputs and stable before/after bindings. Green hearing runs bind digest `5f5be4ad80b969e319fcf6e5a8910afef6a87735d0cce37de61aed0ea8bcb267`; original-ledger runs bind `01cbcc54881d91b9b9f0ab1e116af415926cafecf8c48db9110923b7632d1dda`. All selected green production and hearing fixture copies still match current. The full current digest differs only in the subsequently revised MaintenanceJob and NightRegister test files. This remains an inherited-source proof, not an exact-current full-digest rerun.

Both composed runs retain one `WARNING: no legal wall for found piece cam_noel_witches`, with its actual found-art/BuildingRoot reconstruction stack. All other Godot stderr and all runner stdout/stderr streams are empty. There are no native error, script-error, object/resource/RID retention diagnostics in these runs. The gate permits warnings generally; the review does not claim a strict warning allowlist or a repaired found-art placement. The copied command and serial runner preserve actual process exits. Engine banners identify `4.7.1.stable.official.a13da4feb`; executable bytes were not bound by these run receipts.

This closes the demonstrated empty-apartment hearing path and strengthens actual-root reconstruction coverage. It does not locate listeners in corridors, visited flats or outdoor venues, prove complete embodied perception, or grant human listening/traversal/full-game acceptance. Existing direct observations, acoustic thresholds, prior memories and broader save/schema limits retain their existing owners and scope.
