# Integration register

Canonical development branch: `codex/astra-canonical-20260904` in `C:\PleaseRemainOnTheLine-astra`.

| Landing | Exact provenance | Status / consumer | Proof and limits |
| --- | --- | --- | --- |
| Verified canonical base | c2dc01771bc25b07f5dcf7a6040102345b8c57d5 | Fresh checkout, initially clean | Fetch exit 0. Existing main is not release-complete. |
| ASTRA-SANITIZE-0 | ae451f9552497126ecdfd83a84a1ce7016f2e1a8 | Committed; eight packet tests pass, 17 mutation reds and actual CLI red1/green0 retained | No player-facing feature changed. |
| M11 accepted boundary | a9e455bfede9f89193c9acd0796eb8fc5a0c3548 | Merged by cc95005d2c24b6be5cb04e728c5229c5d416954b; scoped runtime revalidation completed with repairs below | M11B 75/75, M11A 40/40. Isolated exterior module and F02/F04 openings only; no new human acceptance. |
| Prompt / fresh-profile repairs | 647c72d1740d106d51139dc8f7a1c5a82b078cb9 | Three semantic prompt corrections; M08F/M11A own their test-save parent | Prompt baseline unchanged; 28 selftests; independent fresh-profile 29/29 and 40/40. |
| Source-owned audio / fixture lifetime | ac40f163fc0be18bfd8cb5bb2ede2a6c4f5f3f54 | NightRegister retires pooled cues, pending decoders and late off-tree calls; matrix/NightRegister fixtures retire their own setup | Owner controls 20/20, composed M08F 29/29, genuine fresh-profile two-root 24/24, NightRegister 148/148. No audio shutdown warnings in final runs. |
| Evidence admissibility | fc359a687e069d0b2e2baa70d71c352da26fd87e | Capture inspection cannot stand in for executed runtime contracts; test and runtime text inputs bound by digest | 105 selftests, 23 CLI red/green pairs; 12 actual windowed inspection frames. Seven unsupported runtime tiers demoted; presentation/renderer debt remains. |
| Spatial record relocation | d4d1b01 (exact hash in LIVE_STATE) | Existing PolicyVoice%02d classification follows its constructor; one of 3,626 records moved | Old mapping fails, exact relocation passes, unrelated new family still fails. All other manifest bytes unchanged; 52 selftests. |
| M11C1/M11C2 and dream/lamp | Exact inventories in adoption matrix | NOT ADOPTED | Failed/dirty/human-pending dependencies preserved. |

Subsequent landings append exact hashes, named changes, protected-path verification, actual exits and rollback instructions. The frozen sanitation matrix remains an observation of the pre-integration base.

M11 landing changed exactly 75 paths listed in evidence/m11b_integration.json. Import exited 0. The original prompt regression, three independently exposed save-directory preconditions, audio retention and capture false claims retain their red evidence; fixes above do not rewrite those receipts. All 121 metadata entries flagged after final rendering were raw-byte identical to HEAD (evidence/final_import_metadata.json); explicit index refresh produced zero staged byte changes.

Rollback the merge with `git revert -m 1 cc95005d2c24b6be5cb04e728c5229c5d416954b`, or revert a later named repair commit independently after checking dependencies. No rollback executed. Remote main was rechecked and remains c2dc01771bc25b07f5dcf7a6040102345b8c57d5; no push, selector cutover, public release or v1 retirement occurred.
