# V2 receiving programme panel - 2026-10-06

Evidence class: **INERT**

REPORT - V2-RECEIVING-PANEL - 2026-10-06

## Branch and verification

Branch **main**; verified source HEAD **99cb6efdfeaaad8f2b1471dc1fee927e6e08d14a**; base and merge-base **90e84d8caa6de196c7ceff3378b04e6afa609b1e**; origin/main **4c353a8d3e61ebfe783216900702e2219a15f533**. Candidate checkout and complete board clean at verification: **yes**. Protected **17/17 unchanged**; default **v2** and explicit **ORISON_BUILDING_ROOT=v1** rollback remain. Verification uses the canonical checkout and grants no fresh-checkout behaviour.

## Concrete change

The previous panel requires a fixed **960x720** picture plus title, spacing and controls. At the default **1280x720** client window its control hint sits at **y=784**, beyond the frame; at **640x360** and **800x1000** it also exceeds the width. A genuine before-run regression reports exactly these three margin failures, completes without script errors and releases every tracked owner.

A **24px** margin frame now reserves the title and controls first. The live picture fills the remaining space with centred **4:3** aspect and the existing nearest-filtered **480x360** texture. Title and hint wrap to the available width. The cabinet card, compiled programme, input, scope feed, world, player lock and close policy retain their existing owners. No geometry, material, utility or room authority changes.

## Executed and rendered checks

The committed native/inherited receiving test completes **586 checks**. It resizes the actual focused client window to **640x360 / 1280x720 / 1920x1080 / 800x1000** and checks the title, picture and controls inside the visible margins, ordering, readable source text, same board/world/player, original feed and player lock. It restores the original window before ordinary **Escape**, focused-parent protection, second keyboard session and teardown. Tracked panel/title/picture/hint nodes also retire; retained owned nodes/resources/playbacks are **0 / 0 / 0**. All **39** final captured frames were directly viewed.

The before diagnostic is an intentional regression failure, not a candidate verdict. The corrected pre-commit diagnostic passes; final proof is the separately verified committed source. Both exact logs/receipts, source snapshots and visual derivatives are retained. The scoped receiving contract leaves save/reconstruction unexecuted and grants no ledger promotion. The separate complete resident-key contract exercises actual permission, copying, saved locks, reconstruction and owned teardown on this source revision.

## Ledger and gates

Six blocker scopes before -> after: **[7, 8, 127, 42, 151, 153] -> [7, 8, 127, 42, 151, 153]**; requirements changed: **[]**. **48 gates/tools tests**, zero regression; reader **NEW 0**. Inert captures, reports and wrapper receipts grant no promotion. The separate complete key contract refreshes its existing authority only.

| Scene | Actual exit | Exact wrapper receipt |
| --- | --- | --- |
| (import) | 0 | **art/renders/orison_v2/receiving_panel_20261006/runs/import1.log.receipt.json** |
| (import) | 0 | **art/renders/orison_v2/receiving_panel_20261006/runs/import2.log.receipt.json** |
| res://tests/ArcadeTest.tscn | 0 | **art/renders/orison_v2/receiving_panel_20261006/runs/ArcadeTest_tscn.log.receipt.json** |
| res://tests/OrisonV2RadioReceivingTest.tscn | 0 | **art/renders/orison_v2/receiving_panel_20261006/runs/OrisonV2RadioReceivingTest_tscn_windowed.log.receipt.json** |
| res://tests/OrisonV2ResidentKeyRouteTest.tscn | 0 | **art/renders/orison_v2/receiving_panel_20261006/runs/OrisonV2ResidentKeyRouteTest_tscn_windowed.log.receipt.json** |

## Boundaries, open findings and owner decision

Source changes are the shared programme-panel layout, the existing composed receiving test and hash attributes for this review packet. Guide, document map, review and ledger edits record the checked revision. The Radio Service chassis was separately verified; six other receiving chassis and shop frontage/obstruction conflicts remain open. This four-size check grants no coverage for every possible screen size, every programme title, power capacity, continuous shop routes or human acceptance. V2 remains incomplete.

No owner decision is needed to continue local construction. Earlier exact Cobbler publication approval remains pending after automatic approval review; these later commits were not pushed under the Keys Cut approval.

MERGE-CANDIDATE **99cb6efdfeaaad8f2b1471dc1fee927e6e08d14a**
