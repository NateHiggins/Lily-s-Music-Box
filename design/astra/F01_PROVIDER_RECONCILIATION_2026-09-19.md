# F01 provider reconciliation — 2026-09-19

Evidence class: **INERT — source retirement report; promotes nothing**

The reconciliation retained main's **BuildingRoot._build_floor01_geometry_provider**
and **Floor01CellRegistry** as the single geometry owner. The older optional
**Floor01GeometryProvider** wrapper was left in the merged tree but had no live
production caller. Its **configure(path)**, **configure_resource**,
**instantiate_into**, **release_references** and **public_census** interface no
longer exists on the accepted registry, which uses **configure(mode)**,
**mount_default** and **public_teardown**. Its logical resource and its two old
test entrypoints therefore could not exercise the current implementation.

This change retires those twelve tracked files. Git history at checkpoint
**65b5ebf1da857af3539ad2cd9535b3f6b283533a** retains their exact content; historical
reports, render packets and receipts remain untouched. It does not install a
second provider, change the selected geometry mode, change the world selector,
or change a protected asset.

Current test owners remain:

- **game/tests/orison_v2_m11c2_floor01_registry_test.gd**: configuration and
  manifest refusals, bound asset/alias identity, partial-mount rollback,
  semantic/alias resolution, both geometry modes, teardown and shared
  presentation cleanup.
- **game/tests/orison_v2_m11c2_production_matrix.gd**: composed production geometry
  and parity checks, using the actual BuildingRoot-owned registry.

Retirement is a source reconciliation, not a new pass for either retained suite.
The fresh lane receipts and complete candidate gate board are required before
claiming runtime verification.

| Retired tracked path | Git blob at the integration checkpoint |
| --- | --- |
| game/scripts/building/floor01_geometry_provider.gd | 37b48f2a4838ab76782df06401a538b1e4a53746 |
| game/scripts/building/floor01_geometry_provider.gd.uid | cab302336cafdac90e9f80080f9fc2b67270c6cb |
| game/scripts/building/floor01_registry_data.gd | aea6d07c63e6aed22cd0f7113524937b61429659 |
| game/scripts/building/floor01_registry_data.gd.uid | 115b4b5c9515a11628bb488ac0695594112ba4e5 |
| game/data/floor01_provider_registry.tres | 3678df31dc2974f1123ae0143ab654c660bbc869 |
| game/tests/floor01_registry_contract_test.gd | 53249acd387005d068382cbca3c9d81215e09058 |
| game/tests/floor01_registry_contract_test.gd.uid | 0c9e425faf6b747fff862e819555e74257e4c312 |
| game/tests/floor01_provider_parity_test.gd | 074bd9283fd209cc7d39e0d527181da639a4a716 |
| game/tests/floor01_provider_parity_test.gd.uid | d525336809f0ca560170dbcbcab4a5150d73e713 |
| game/tests/Floor01RegistryContractTest.tscn | 0af0b9e1ac4e4f38b55feebe6adc49c83ff03ba9 |
| game/tests/Floor01ProviderParityTest.tscn | b0cf74bff9afb00b38fbbedc8c87c4751e15fb88 |
| game/tests/fixtures/floor01_provider_candidate_root.tscn | 1617a13d1dfd62662e3a41c550311ea3099fe367 |
