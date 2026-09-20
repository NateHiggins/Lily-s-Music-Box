# World timestamp provenance: preserved runtime validation

Root applied the five timestamp owners and ran the preserved cases at HEAD `e72320288d256e4d20386e8f28c116fe962788fc` with the current foundation repairs. This review aggregates existing evidence; it did not run Godot, edit game/tool code, or replace any earlier receipt. Exact source, receipt and diagnostic bindings are in `design/astra/evidence/world_timestamps/validation.json`.

New inventory, order, incident and register timestamps now declare `campaign_elapsed_minutes` through per-field basis metadata. They use accumulated campaign minutes, including after midnight and multiple days. An invalid/protected clock refuses timestamped mutation. Legacy unqualified host values retain their original numbers and units. WorkOrders preserves the exact legacy source and stable ID; adoption records `adopted_at` without inventing issuance. A conflicting archived source refuses retirement instead of deleting either history. ChirpHunt retains the real mapping and migration route. No duration, expiry or neglect consequence was added for these fields.

| Preserved run | Raw result | Native/forwarded exit | Diagnostic gate |
| --- | --- | --- | --- |
| `original_source_01` | FAIL 51/76; 25 timestamp, archive and protection failures | 1 | 1 |
| `candidate_01` | PASS 76/76 | 0 | 0 |
| `wrapped_minute_01` | FAIL 61/76; 15 exact timestamp-value failures | 1 | 1 |
| `mid_report_late_sample_01` | FAIL 75/76; only `reported_at` fails | 1 | 1 |
| `restored_candidate_01` | PASS 76/76 | 0 | 0 |
| `regression_jobs_01` | FAIL, one source-history assertion | 1 | 1 |
| `regression_register_01` | FAIL 145/148; three assertions | 3 | 1 |
| `final_jobs_01` | PASS; footer does not report a count | 0 | 0 |
| `final_register_01` | PASS 153/153 | 0 | 0 |
| `final_timestamps_01` | PASS 76/76 | 0 | 0 |
| `regression_errand_01` | PASS; footer does not report a count | 0 | 0 |
| `regression_incidents_01` | PASS 18/18; retained found-art warning | 0 | 0 |
| `regression_calendar_01` | PASS 52/52 | 0 | 0 |
| `regression_save_compat_01` | PASS 14/14 | 0 | 0 |

The original source run uses the same 76-check fixture as the green. Its actual five production source copies remain in that run. It is a real original-source red, not a test requiring the defect to remain in current code. Both controlled regressions have independent controller receipts with `intended_red=true` and `restored_exactly=true`. Their runtime receipts remain red. The wrapped-time control keeps the basis labels but substitutes minute-of-day; it demonstrates that labels alone cannot make the units correct. The single-owner late-sampling control exercises a real order-issued callback that raises the persistence protection latch before a later sample. Sampling the validated observed minute before that callback preserves the report's provenance. This is a callback/protection-window simulation, not a physical disk fault.

The first job regression is retained as an unexpected red. It demanded deletion of a newly reintroduced issued order even though the authored job already archived a different closed order. The revised fixture first verifies that conflict, then compares the complete authored job and exact incoming source after migration. It replaces one check with four without discarding earlier migration cases.

The register's first three failures were the newly qualified `at_basis` field plus two authority scans that included comment text because their literal CRLF delimiter did not split LF production text. The final fixture adds only `at_basis` to the record whitelist, separately requires its exact basis, and adds four LF/CRLF controls. Those controls remove whole comment lines while preserving executable foreign-owner calls and inline-comment code. The existing authority predicates and spine-method allowlist remain intact. The new basis assertion plus four controls account for 153 checks. Exact old and new fixture bytes in `work/world_timestamps/regression_fixture_revision` match their respective red and final-green runtime manifests; this is not a baseline update.

All 14 run receipts' 470 artifact hashes, source copies, and before/after runtime digests were checked with no mismatch. Every run preserved stable inputs during its process. Final timestamps/jobs/register match the complete 1,160-input current runtime manifest at the pre-profile verification point. Earlier errand/incidents/calendar/save-compatibility proofs precede the hearing ledger/composed fixture and two regression fixture revisions; the aggregate lists those differences instead of claiming their old full digest is current.

Early runs bind wrapper hash `2424ac5749145fdb7db6cf1f4bef2e0469aa36dbc85faa595dd848ed15e91ec2`. That version already used the strengthened diagnostic gate. Final runs bind `9f10ee311231207df997107c2a6cb1b2b7d4f1baab4e6a09324e916193bcda3b`, which additionally retains the selected regression scene and referenced script. The earlier regression source hashes were retained in the complete input manifest; separately preserved exact fixture originals match them. Each receipt keeps its own wrapper version. The three preserved Python parser tests passed and exercise exit/footer/source stability, wrong footer, zero-exit errors and retention diagnostics.

The only warning in these timestamp runs is `WARNING: no legal wall for found piece cam_noel_witches` in the incident regression. It remains in raw stderr and is not described as fixed. The wrappers admit warnings generally; this review checked that no other warning or native error/retention diagnostic appears. Engine banners identify Godot `4.7.1.stable.official.a13da4feb`; these receipts do not independently hash the engine executable. Recorded native exits are forwarded through the copied serial runner, not inferred from assertion totals.

The focused fixture uses actual owner APIs and actual RealityState disk save/load, with a bounded stand-in building for the register and supplied survey presence at the incident report callback. It proves the named state transitions, values, archival rules and protection behavior. It does not prove physical route traversal, a full-day soak, process-restart recovery or universal malformed-save safety. Version-0/default migration and deeper scalar/ID validation limits remain as documented in the save review. Host identifiers and dream-seed entropy exemptions are unchanged; root owns the separate audit/canonical closure.
