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
    # ------------------------------------------------------------ slice 2 (implementation/slice2)
    "BW-002": {"status": "implemented", "owner_notes": "2C_bed1, 5C_bed1 and 6C_bed1 (with nightstands) removed at their owners (completion source; domestic_furniture_source; blockout anchors); 4C keeps its two beds (re-templated on 5C_bed0). Conversions started with existing variants: 2C session table and chair under the window, 5C pigment table (TableRect09) on the inner wall with a stool, 6C archive table under the window and two shelves on the east wall. Hero props (blanket walls, easel, drying rack, catalogue drawers) stay open on their room entries. Bedding validator expects 19 beds; tables 64, seating 43, storage 45 instances rebuilt. Suites: OrisonV2BeddingTest passes; the fabrication batch for the twelve rebuilt families passes; OrisonV2UpperFurnitureTest stays red on a pre-existing check (mesh material overrides: 394 failures on main at 16f1d353, 400 here, the six new native meshes counted the same way); the C-unit completion route stops at the 2C bath leg exactly as on main."},
    "F02_C_BED2-001": {"status": "implemented", "owner_notes": "Removed with BW-002."},
    "F05_C_BED2-001": {"status": "implemented", "owner_notes": "Removed with BW-002."},
    "F06_C_BED2-001": {"status": "implemented", "owner_notes": "Removed with BW-002."},
    "BW-011": {"status": "implemented", "owner_notes": "DomesticRadio_1A/1D/2C/3D/4C/4D added to domestic_radios_source (families from the 1928 catalogue: radiola table, Crosley Pup, homebrew regenerative); wireless tables (TableRect07 template) added to 1A, 3D and 4D on the south wall between the doors; orison_v2_radios.gd now places 18 units; the apartment batch test expects 18 receivers. DomesticRadioTest passes; in OrisonV2ApartmentBatchTest the new receivers pass their clearance and operator-stance checks, and the only remaining receiver failures are the pre-existing texture-backed-parts check (98 on main for the twelve, 142 for eighteen); the other red groups (46 fixed-furniture collisions, 18 wood, 12 category, 10 plant, 6 coffee, 2 plant) are identical on main."},
    "F01_A_MAIN-001": {"status": "implemented", "owner_notes": "1A_wireless_table at (-12.0, -6.95) yaw 180 and DomesticRadio_1A on it (BW-011)."},
    "F01_D_MAIN-003": {"status": "implemented", "owner_notes": "DomesticRadio_1D on the existing 1D_wireless_table (BW-011)."},
    "F01_D_MAIN-001": {"status": "implemented", "owner_notes": "1D_fabric_worktable record and anchor removed; the 1D_story_pattern_board anchor had no consumer and is gone."},
    "F01_D_PRIVATE_HALL-002": {"status": "implemented", "owner_notes": "The 1D_fabric_shelf_01/02 anchors removed (they had no furniture consumer; the review's shelves were the baked template surfaces)."},
    "F04_D_BATH-003": {"status": "implemented", "owner_notes": "F04_D_BATH_SWITCH anchor moved to (-6.1, 1.12, -9.75) yaw 0: the north wall beside the bath door, off the basin wall."},
    "F05_C_BED1-002": {"status": "implemented", "owner_notes": "5C_w0_wardrobe and its stance moved to the bedroom's east wall (3.45, 9.3) facing west; 5C_w1_wardrobe stays in the closet for F05_C_STUDIO-001."},
    "F06_B_ALCOVE-001": {"status": "implemented", "owner_notes": "6B_abed turned to yaw -90 with its head at the west wall (-14.6, 9.9) so the foot faces the hall door; nightstand at the window side (-15.35, 11.2); stances moved."},
    "B1_RESIDENT_STORAGE-003": {"status": "implemented", "owner_notes": "Bay cage labels are single-sided (Label3D double_sided false) on the bay fronts."},
    "F01_VESTIBULE-002": {"status": "implemented", "owner_notes": "Entry sign labels single-sided; no mirrored read through the glass."},
    "ROOF_PUBLIC_CORE-004": {"status": "implemented", "owner_notes": "Lift-drive sign single-sided (the bulkhead finish part stays open)."},
    "BW-009": {"status": "implemented", "owner_notes": "The readability cues' nine ungoverned light pools (blue and orange OmniLights beside the stair on F01-F03, at the 2A/4B doors and the 4B terminal) are gated off in production (show_light_pools false in orison_v2_runtime_root). Remaining leaks, if any, need a capture to name."},
    "F01_PUBLIC_CORE-003": {"status": "implemented", "owner_notes": "The orange-tan plane was the readability cues' WARM light pool on the core wall; gated off with BW-009."},
    "F03_EAST_HALL-003": {"status": "implemented", "owner_notes": "The powder-blue plane was the readability cues' PUBLIC light pool beside the stair; gated off with BW-009."},
    "F05_B_BATH-003": {"status": "rejected", "owner_notes": "Misread: the 'column radiator standing mid-room' is the shower's closed curtain pose (the fluted cream cylinder on its enamel tray); the heating data places no radiator in 5B's bath. The curtain's look is BW-008's item."},
    "F03_B_ALCOVE-001": {"status": "rejected", "owner_notes": "Measured, not a bug: 3B_aw_wardrobe at yaw 0 on the north wall shows its two leaves and knobs to the room and the bed foot (implementation/slice2/images/F03_B_ALCOVE_DT3.jpg); the punchlist's back-to-room reading does not hold at this station. No data change."},
}
