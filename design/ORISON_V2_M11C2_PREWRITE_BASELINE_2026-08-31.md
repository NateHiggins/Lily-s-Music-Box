# Orison v2 M11C2 pre-write baseline — 2026-08-31

Evidence class: **TECHNICAL BASELINE — NO COMPLETENESS MOVEMENT**

## Repository boundary

- Requested base and HEAD: **503465defa24d19d55b53c9a17bf8a4affdfb5eb**.
- Branch: **codex/orison-v2-m11c2-real-floor01-cut**.
- Recorded origin/main and merge base: **c2dc01771bc25b07f5dcf7a6040102345b8c57d5**.
- Worktree status before the first M11C2 file write: clean.
- Committed selector: **v1**.
- Expected completeness movement: zero requirements and zero promotions.

M11C2 is authorized to add the deterministic production owner-first cell
assets, registry and residency interfaces; adapt the reviewed production
consumers; and redirect only the F01 geometry provider in the production v1
root. The rollback monolith remains byte-identical and may never be composed
simultaneously with the cells. M11C2 is not authority for M09, selector cutover,
v1 retirement, layout mutation, unrelated floor export, or new gameplay, save,
or streaming authority.

## Protected hashes

| Path | Bytes | SHA-256 |
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

Every path above is expected to remain byte-identical. The authorized production
cell GLTF/BIN files and their registry/lineage manifests are new paths, so their
deterministic hashes will be recorded in the final receipt rather than treated
as protected-file changes.

## Baseline ledgers and audits

The completeness ledger contains **150** requirements: **ABSENT 51,
HUMAN_ACCEPTED 1, PROGRAMMED 44, RUNTIME_PROVEN 34, SHELL_ONLY 2, and
SPATIALLY_PROVEN 18**. Blocker scopes are **0 / 1 / 86 / 45 / 101 / 103**.

| Audit | Exit | Baseline |
| --- | ---: | --- |
| completeness | 1 | incomplete 150-row ledger; one stale checkpoint identifier |
| spatial | 0 | 3,727 classified records; no failing drift |
| systemic authority | 0 | 59 findings; no new actionable or policy violation |
| data consumption | 1 | 1,289 unread fields, 11 unread files, 2 monotonic-only values, 1 malformed record |

The four audit test suites pass: completeness **99/99**, spatial **51/51**,
systemic authority **34/34**, and data consumption **14/14**. The two nonzero
direct-audit exits are reviewed historical debt. M11C2 may not baseline or
relabel them to make a gate green.
