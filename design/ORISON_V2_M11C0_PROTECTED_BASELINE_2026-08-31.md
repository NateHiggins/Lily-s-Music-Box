# ORISON-V2-M11C0 protected baseline — 2026-08-31

## Repository state before the first M11C0 write

- requested M11B base: **0ea23bfd1296a3779773886b1fc062f10288fa23**;
- M11B human-acceptance parent: **a9e455bfede9f89193c9acd0796eb8fc5a0c3548**;
- M11C0 branch: **codex/orison-v2-m11c0-floor01-cut-rehearsal**;
- M11C0 worktree: **C:\PleaseRemainOnTheLine-v2-m11c0-floor01-cut-rehearsal**;
- merge base with the requested base: **0ea23bfd1296a3779773886b1fc062f10288fa23**;
- worktree status before the first M11C0 write: **clean**; and
- committed selector default: **v1**.

The remote **origin/main** was **c2dc01771bc25b07f5dcf7a6040102345b8c57d5**
when this baseline was recorded. M11C0 remains based on the explicitly supplied
M11B commit lineage; it does not merge or rebase unrelated mainline work.

## Protected hashes

| Protected path | Bytes | SHA-256 |
| --- | ---: | --- |
| art/data/building_layout.json | 2,624,829 | 68838c933c0954092c63403f36ec7fb26d6c0956c01c23109465c680608b399d |
| game/data/building_layout.json | 2,624,829 | 68838c933c0954092c63403f36ec7fb26d6c0956c01c23109465c680608b399d |
| game/scripts/building/building_root_selector.gd | 1,461 | d2b3db95d72e4a418c0e7184e6b3368da723a945192024a10ee937ea604c9802 |
| game/assets/building/floor_01.gltf | 682,906 | 906f1f48c2fc8ff6e6af3048d0abca46416cd103bee8d818606a3c32c71fe5b1 |
| game/assets/building/floor_01.bin | 12,020,428 | e1d3454afb6079602b8cfe0dcb00d255e6aa68f7f247c5ecc39bd5791cfdc477 |
| game/assets/building/floor_02.gltf | 166,867 | b3977546cabc72775ad63be53bfb2001ace51d13094b4ed8b719a979adc2d640 |
| game/assets/building/floor_02.bin | 6,144,948 | 4b7d16ae8ed7df4a90f0626746ca5987bd02c61268f372fced86a3782760b69e |
| game/assets/building/floor_03.gltf | 189,693 | 21c506695edf27effa20c711f1daed939c807a774f5076656e8ff3e8be898d3f |
| game/assets/building/floor_03.bin | 6,245,068 | 8f84cb67f5f2fa8f2c5a5e47fbc418630957dbc8d6a96576e005c92ac6fcc9f8 |
| game/assets/building/floor_04.gltf | 178,788 | c1a03abba15f481e6318e27d5035dae13e3e5173f16c2f208711769ce3bf8df1 |
| game/assets/building/floor_04.bin | 6,417,828 | f57f45d79738086a5da23afd7d9a04d6f5596641193ec22856929de30b03e266 |
| game/assets/building/floor_05.gltf | 184,558 | d5860b28c47a110fcced5b8cd22c0f5d4ae0fc036dfc0d44fbe884a2def41e7a |
| game/assets/building/floor_05.bin | 6,335,272 | a8e7f0fd106696a1c6c9823f30cf013b0f664e4dac5d763fc2c3d2c072dd54d8 |
| game/assets/building/floor_06.gltf | 175,408 | 96991ecf897b7882c68897eb9c8df5a678046e1567e8f59d51f21f6646209422 |
| game/assets/building/floor_06.bin | 6,391,960 | 8389d2264ea4c6e4eb59fb35b58d7480b3823641c1471b593a85613883bd9f5f |
| game/assets/building/floor_b1.gltf | 150,777 | f151ff10c8d2420340fc522df5e9eb2ffbdf200be6068b302c6769881af8eb3e |
| game/assets/building/floor_b1.bin | 2,778,748 | 226437a3e2816882c04749918a4d99540ff2a4714d0a914b2dd2606ace8c4449 |

## Baseline audits

| Audit | Exit | Baseline result |
| --- | ---: | --- |
| audit_orison_v2_completeness.py | 2 | 150 requirements: ABSENT 51, HUMAN_ACCEPTED 1, PROGRAMMED 44, RUNTIME_PROVEN 34, SHELL_ONLY 2, SPATIALLY_PROVEN 18 |
| audit_orison_spatial_dependencies.py | 0 | 3,684 records; zero new unclassified, changed classifications, vanished targets, or unresolved saves |
| audit_systemic_situation_authority.py | 0 | 59 findings; zero new actionable findings or policy violations |
| audit_data_consumption.py | 1 | reviewed debt: 1,289 unread fields, 11 unread files, 2 monotonic-only durable numbers, 1 malformed record |

Completeness blockers by scope were **0 / 1 / 86 / 45 / 101 / 103** for
first-slice technical, golden shift, full-building structural, full-building
runtime, production cutover, and v1 retirement respectively.

## Expected ledger movement

M11C0 is a disposable rehearsal and documentation checkpoint. Expected
completeness movement is **zero requirements and zero status promotions**.
Protected layouts, generated floor assets, selector, runtime ownership, and
historical evidence are expected to remain byte-identical.

The census is expected to expose more specific source-ownership and runtime
consumer debt. Such findings explain why a proposed cut is or is not safe; they
do not create evidence for promoting a completeness row.
