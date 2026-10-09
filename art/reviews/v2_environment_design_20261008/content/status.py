"""Implementation status per change id, overlaid on the change register.

The builder (build_dossier.py, also `--register-only`) copies `status` and
`owner_notes` from here into change_register.{csv,json,xlsx}. Everything not
listed stays `proposed`. Statuses: proposed, implemented, verified, deferred,
rejected. Each entry names the commit and the evidence that shows the change
in the build; evidence packets live under implementation/<slice>/.
"""

SLICE1 = "implementation/slice1 (captures, batch.json, run receipts)"

STATUS = {
    # ------------------------------------------------------------ slice 1
    "F04_A_VESTIBULE-004": {"status": "verified", "owner_notes": "Blockout purpose text now reads 4A; the sweep caption shows it. " + SLICE1},
    "F04_D_STUDY-001": {"status": "verified", "owner_notes": "F04_D_BED_STORAGE_DOOR leaf_state locked in completion_interiors_source; the sweep's threshold opening was refused (threshold_door: locked) and OrisonV2CompletionInteriorsTest now expects the refusal and skips the closet: with V2_TEST_UNIT=4D the four lock checks pass (implementation/slice1b/receipts). The suite still ends in its kitchen-to-hall leg (12 waypoints), which fails identically on main at 16f1d353 for 1A (38 waypoints, same target) and for 3D on this branch (14 waypoints): the fridge beside the kitchen door blocks the route line, a pre-existing defect flagged separately. On main the 4D leg already failed earlier, at the walk into the closet after opening its door (7 waypoints; implementation/baseline_completion_4D), so the lock removes a broken step rather than adding one. " + SLICE1},
    "BW-012": {"status": "verified", "owner_notes": "2A, 3D, 4D fittings monitor_top false; household_fridges plan instances FridgeIcebox; family rebuilt in Blender; the fabrication batch counts 4 monitors of 18 (test expects 4); 2A native capture and 3D/4D sweep overviews show oak iceboxes. " + SLICE1},
    "F04_D_KITCHEN-003": {"status": "verified", "owner_notes": "Resolved by BW-012: F04_4D_FRIDGE_01 is a dry icebox (F04_D_KITCHEN_OV). " + SLICE1},
    "F04_D_KITCHEN-005": {"status": "verified", "owner_notes": "Keep note closed with the swap above."},
    "F04_D_KITCHEN-004": {"status": "verified", "owner_notes": "Runtime census lists F04_4D_STOVE_01 (orison_v2_stove.gd) with four grates and burner caps at (-10.6, -7.65) in F04_D_KITCHEN; the range mounts. The overview station does not frame it; no data change."},
    "BW-010": {"status": "verified", "owner_notes": "F01_A_MAIN_LT, F03_D_MAIN_LT, F04_D_MAIN_LT: completion lighting kind pendant_shade and fixed_lighting plan variant pendant_shade_rise100; family rebuilt; fixed_lighting validator 5971 checks, 0 failures on rerun (one contextual standing-view failure at F01_BAR_LT_DECK0 on the first run, absent on rerun and in the owner's final receipts); sweep overviews show the pendants. " + SLICE1},
    "F04_D_MAIN-004": {"status": "verified", "owner_notes": "Resolved by BW-010 (F04_D_MAIN_OV). " + SLICE1},
    "F02_C_KITCHEN-004": {"status": "rejected", "owner_notes": "Measured, not a bug: the runtime census records F02_2C_FRIDGE_01 at yaw 90.0 degrees exactly (square to the east wall, 0.46 m off it); the skew in the review tiles is wide-angle perspective near the frame edge. No data change. " + SLICE1},
    "F04_C_KITCHEN-004": {"status": "rejected", "owner_notes": "As F02_C_KITCHEN-004: F04_4C_FRIDGE_01 yaw 90.0 in the runtime census; no clipping in the data. " + SLICE1},
    "F05_C_KITCHEN-004": {"status": "rejected", "owner_notes": "As F02_C_KITCHEN-004: F05_5C_FRIDGE_01 yaw 90.0 in the runtime census. " + SLICE1},
    # ------------------------------------------------------------ water closets, measured (implementation/baths)
    "BW-018": {"status": "rejected", "owner_notes": "Measured, not missing: every one of the 19 water closets instantiates bath_water_closet.glb with LowCistern and RemovableCisternLid visible; the cistern is 0.46 x 0.22 x 0.31 m with its top 0.80 m above the floor and at least 0.11 m clear of every bath wall (sweep census probe, implementation/baths/receipts). The raised lid (top 0.94 m) hides it from front-on stations, which is what the review saw. No data change; a lid-down default in unoccupied flats is a possible P3 follow-up."},
    "F04_A_BATH-003": {"status": "rejected", "owner_notes": "Cistern present (BW-018 measurement: 4A_wc LowCistern visible, 0.42 m clear of the east wall). The curtain/receptor part stays with BW-008."},
    "F05_A_BATH-003": {"status": "rejected", "owner_notes": "Cistern present (BW-018 measurement: 5A_wc LowCistern visible, 0.15 m clear of the south wall). The pipe strip and register parts stay with BW-005 and heating_distribution."},
    "F03_D_BATH-003": {"status": "rejected", "owner_notes": "Not reproduced: the bath sweep at 49e5e3a1 renders 3D_wc's cistern in porcelain (implementation/baths/images/F03_D_BATH_OV.jpg); the magenta face in the review tile was transient."},
    "F04_B_BATH-003": {"status": "verified", "owner_notes": "Keep note confirmed by the same probe: 4B's cistern is the family's low cistern, identical to every other unit."},
}
