# Fresh-profile harness directory repair

Both save-bearing test harnesses now establish their own save parent directory at the start of `_ready()`, before changing campaign state. They use `ProjectSettings.globalize_path(...).get_base_dir()` and check `DirAccess.make_dir_recursive_absolute()`; creation failure reports the directory/error and exits with code 2. The serial runner and production persistence code were not changed by this repair.

Changed files:

- `game/tests/orison_v2_m08f_runtime_test.gd`
- `game/tests/orison_v2_m11a_first_exterior_cell_test.gd`

The earlier failures remain in `design/astra/evidence/base_runtime/receipt.json` (M08F, exit 1, 28/29) and `design/astra/evidence/m11b_runtime/receipt.json` (M11A, exit 3, 37/40). Those runs used fresh profiles without `user://tests`; the save operation failed because its parent did not exist. Earlier separately labelled directory-precreated controls passed, establishing the precise precondition defect.

The repaired harnesses ran serially on Godot 4.7.1, headless, with new separate process-local APPDATA profiles under `design/astra/evidence/harness_directory_repair/userdata`. The runner asserted each profile was absent, created only its APPDATA root, and confirmed the game test directory was absent before launch. Each harness created its directory; each removed its test save afterward. No user save directory was used.

| Harness | Actual process exit | Functional checks | Elapsed process time | Diagnostics |
| --- | ---: | ---: | ---: | --- |
| M08F production runtime fixture | 0 | 29/29 | 2.435 seconds | 4 ObjectDB instances leaked; 2 resources still in use at exit |
| M11A first exterior module | 0 | 40/40 | 21.507 seconds | None |

The directory repair passes. The M08F audio retention defect remains unresolved and is not an approved engine baseline. Its functional pass does not constitute lifecycle acceptance. M11A proves the isolated exterior-module consumer exercised by its harness; it does not establish a mounted BuildingRoot exterior route. Headless process elapsed times do not establish release graphics performance or human visual acceptance.

Exact source evidence is retained in `design/astra/evidence/harness_directory_repair/receipt.json`: HEAD `cc95005d2c24b6be5cb04e728c5229c5d416954b`, binary game/tools diff SHA-256 `f16e4cb6a97b39311bec66e706cd8e946071980eb9557e102464eeceb6f4996a`, and every changed/untracked game/tools file hash. Source snapshots before and after both runs match. The dirty source includes concurrently completed prompt repairs and packet-tool changes, all explicitly listed in the receipt. Raw stdout/stderr and objective receipts are preserved beside it. No commit or staging was performed by the repair agent.
