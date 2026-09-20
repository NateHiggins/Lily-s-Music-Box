# Apartment material registration proposal

Status: prepared outside `game/`; no engine execution, live source change, staging, or acceptance claim. The production patch passes `git apply --check`. Eight pure Python wrapper-gate controls pass. The focused fixture currently has 36 assertions; GDScript compilation and all runtime results remain pending.

The original production file is preserved byte-for-byte in `originals/game/scripts/reality/apartment_encroachment.gd`. Its SHA256 is `c9892f684e081adf0ccdaeb38b44b5b48e8573b109d80fd8e6933e075f5ed4d5`. The proposed file is `proposed/game/scripts/reality/apartment_encroachment.gd`, SHA256 `69e28e38740f122fe5bfd47b9f8bc6194fd5e52dda2eae085163deee30977860`. `prepare.py` recreates that production proposal from the exact live anchors, writing only this package. The fixture and wrapper are maintained separately and are bound by `review_checks.json`.

## Evidence and scope

`design/astra/evidence/vulkan_composed/visibility_phase_census_summary.json` records a 618.869 ms median Street→Passage callback, including 523.6905 ms in encroachment, and 609.102 ms in the reverse direction, including 522.7545 ms in encroachment. The retained 296/296 run has no native unpair/underflow/retention failure. F02's registry grows from 686 to 2456 slots while remaining at 446 unique materials; F04 grows from 539 to 2429 slots while remaining at 283 unique materials. This attributes the dominant measured phase to the encroachment callback. It does not measure how much of that callback is explained by duplicate registration or predict the benefit of this patch.

Current `_bind_storey` obtains an array, `_bind_living` registers uniquely into the dictionary, and the caller appends again. On the first pass the local default array can differ from the array `_bind_living` creates. The replacement uses `_bind_living` as the only registration route and clears the existing authoritative array in place before rebuilding it. This preserves readers of that array while removing duplicate and retired entries. Pulse updates (`apartment_encroachment.gd` near 519) and `_push_living_lifecycle` consume this registry; no save or gameplay owner changes.

The same review found a separate immediate identity problem: `reach_props` stores a unique case material in its row, then `_bind_storey` can duplicate it again because it lacks a living owner marker. New case prop and finish materials receive the marker before installation. Existing case rows continue to refer to the installed object, and the registry includes still-installed `prop_rows` outside the glTF floor subtree. Refresh continues to use the original case order, state parameters, thresholds, rectangles, and metadata.

The shared helper `_living_candidate(mi: MeshInstance3D, scope: Node) -> bool` checks ancestry to the requested scope and excludes queued-deletion branches, SubViewport branches, CharacterBody3D, shipped resident groups, and `NPC_` branches. FunctionalProp and ordinary main-world props remain eligible. It is used by the existing finish scan, storey scan, and prop scan; this proposal does not rewrite the `reach_props` collection or spatial-selection loop. Private-world materials are not apartment-owned even when their local coordinates coincide with a flat.

## Cache and ownership contracts

- Full overrides retain the existing per-storey copy policy; foreign `living_storey` overrides must now be copied as well. Multiple draws using the same source reuse one owned copy within a floor, including later draws. The previous registry supplies only weak source aliases; there is no new persistent strong cache. Case-specific materials are excluded from this reuse map.
- Surface overrides preserve the existing first-owner in-place adoption. Another floor gets a copy. This retains SurfacePass's first-storey cached material reference and its existing direct governor budget updates. Case finish materials are already unique and retain their row identity.
- A non-layered full override hides surface overrides, so those inactive surface materials are excluded from the current registry. Removed/replaced nodes and materials are removed on the next registration sweep.
- The existing SurfacePass governor pushes `parallax_budget` only to its own `_cache`. Prop/foreign-floor copies do not gain a new budget propagation mechanism here. That pre-existing limitation remains explicit; copying every first-owner surface would have regressed the direct consumer that currently exists.
- The governor's tier-OFF path does not invoke `on_props_applied`; this patch does not add that callback. Registry retirement is proved after the next actual tier-ON callback or explicit sweep, not at the instant the OFF queue lands.

## Focused proof and red controls

`proposed/game/tests/apartment_material_binding_test.gd` and `ApartmentMaterialBindingTest.tscn` exercise the actual ApartmentEncroachment, LivingField, FunctionalProp and SurfacePass classes. The fixture owns two small storeys and actual materials. It does not call `build()` or run ecology. All assertions are valid against the original source: no new candidate helper is required just to execute the test.

| Contract | Meaningful original-source failure/control |
| --- | --- |
| Initial and repeated registration | Shared installed material on two meshes, twelve storey sweeps and eight full prop sweeps require one entry per current material and stable identities. A stale initial local array cannot satisfy the nonempty initial set. |
| Shared sources and late draws | Two full overrides and a later draw share one per-floor copy; cache source remains unbound; a neighbor floor retains its own field. |
| Foreign owner and inactive surfaces | An existing F04 material installed in F02 must be copied without changing the original field/owner. A shader surface beneath a StandardMaterial3D full override must remain unbound. |
| Private/dynamic ownership | Real SubViewport, resident group and CharacterBody3D branches remain untouched by both scans. An actual FunctionalProp case draw is still included. |
| First installed identity | The first queued SurfacePass callback must leave each case row pointing at its installed material. The test then changes Mina's forced intensity from 0.2 to 0.8 and checks the installed state immediately; an unchanged pre-copy value cannot create a false pass. |
| Root-level and neighbor consumers | A case draw parented directly to the fixture root stays registered and receives refresh/lifecycle; the other floor's case stays at zero. Existing array readers observe the refreshed registry. |
| Replacement and retirement | Four actual governor OFF/ON queue cycles run the real callback, retain cache cardinality, refresh the new installed material, and remove the retired material from the registry. A detached root-level prop is removed on the next sweep. |
| Field replacement | The same installed material identities sample the replacement field texture/origin, while the other floor remains unchanged. |

The fixture hand-constructs the unique finish row and owner marker. It therefore proves preservation of such a row, not execution of the new `build()` guard/marker. Before broader closure, the real-root ApartmentEncroachmentTest and composed material-row census must cover the actual build path, all six case finishes/props, private-world exclusions, and immediate CampaignShell retirement. Existing DreamArchitectureLifecycleLiveTest exercises the real field's registry consumer. These broader suites can expose independent retained failures; do not replace their raw results with this focused result.

## Execution after explicit handoff

1. Keep live `apartment_encroachment.gd` at the exact original hash. Install only the two new fixture files at their corresponding `game/tests/` paths. Run `python design/astra/work/apartment_material_binding/run_case.py original_01 --expect-red`. Preserve raw native failures even if they differ from expectation; the runner never hardcodes an unobserved original failure count.
2. After the original process and source capture finish, apply `apartment_material_binding.patch` or copy the exact proposed production bytes. Run `python design/astra/work/apartment_material_binding/run_case.py candidate_01`.
3. Retain the original failures for each broader ownership control above. If a purported original defect does not fail, narrow the claim or improve the control; do not infer it from a different failing assertion. Additional controlled omissions must preserve/restore exact production bytes and receive their own fresh receipt.
4. Run the affected real-root regressions and composed phase census under the team's single-engine lane. Root's separately prepared one-census `reach_props` optimization must be source-bound and measured separately or explicitly recorded as combined.

`run_case.py` never installs or edits production/fixture files. It uses the existing `tools/run_godot_serial.ps1` with a fresh APPDATA directory, captures native exit and all raw streams, copies selected source/wrapper bytes, and binds the full runtime-input manifest before/after. It rejects source drift, missing/duplicate/inconsistent footers, parse/runtime errors, leaks, timeout, and lane refusal. A deliberate red requires complete assertions, a positive native failure count matching the raw failed labels, stable source, and no project/native diagnostic. Warning lines are retained; the wrapper does not assert a universal warning allowlist. `test_gate.py` tests those parser boundaries without launching Godot.

No protected layout, asset, selector, baseline, ledger, or spatial record is part of this package.
