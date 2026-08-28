# Orison object-level spatial census

Generated read-only from `game/data/building_layout.json`. Candidates are
questions for visual inspection, not automatic deletion or relocation orders.
Door sweeps use deliberately conservative envelopes.

## B1

- Rooms: 8; doors: 7; unassigned records: 45
- Art faces: 2; frame-like records: 0
- Conservative door-sweep candidates: 12
- Wall endpoint near-misses (12–300 mm): 22

| Room | Kind | Unit | Records | Assemblies | Rect parts | Purpose status |
|---|---|---:|---:|---:|---:|---|
| B1_STORAGE_CAGES | storage_cages | — | 14 | 0 | 13 | kind only |
| B1_LAUNDRY | laundry | — | 15 | 2 | 9 | kind only |
| B1_BOILER | boiler | — | 14 | 1 | 11 | kind only |
| B1_ELECTRICAL | electrical | — | 8 | 0 | 7 | kind only |
| B1_HALL | hall | — | 5 | 1 | 3 | kind only |
| B1_ATRIUM | atrium | — | 66 | 47 | 17 | kind only |
| B1_UTILITY | utility | — | 8 | 1 | 5 | kind only |
| B1_COAL | coal | — | 4 | 2 | 0 | kind only |

### Wall endpoint candidates

- walls 2/4: 0.255 m between (-3.43, -6.93) and (-3.25, -6.75)
- walls 2/6: 0.255 m between (-3.43, 6.93) and (-3.25, 6.75)
- walls 3/5: 0.255 m between (3.43, -6.93) and (3.25, -6.75)
- walls 3/7: 0.255 m between (3.43, 6.93) and (3.25, 6.75)
- walls 5/13: 0.250 m between (3.25, -6.75) and (3.0, -6.75)
- walls 8/13: 0.250 m between (3.25, -6.75) and (3.0, -6.75)
- walls 15/16: 0.205 m between (-13.795, -9.65) and (-13.65, -9.795)
- walls 15/25: 0.157 m between (-13.795, -0.45) and (-13.65, -0.39)
- walls 16/28: 0.231 m between (-5.51, -9.795) and (-5.33, -9.65)
- walls 17/18: 0.205 m between (-13.795, 9.65) and (-13.65, 9.795)
- walls 17/26: 0.157 m between (-13.795, 2.67) and (-13.65, 2.61)
- walls 18/28: 0.231 m between (-5.51, 9.795) and (-5.33, 9.65)
- walls 19/20: 0.205 m between (13.795, 9.65) and (13.65, 9.795)
- walls 19/21: 0.120 m between (13.795, -0.88) and (13.795, -1.0)
- walls 20/29: 0.231 m between (5.51, 9.795) and (5.33, 9.65)
- walls 21/22: 0.205 m between (13.795, -9.65) and (13.65, -9.795)
- walls 21/27: 0.157 m between (13.795, -1.0) and (13.65, -0.94)
- walls 22/29: 0.231 m between (5.51, -9.795) and (5.33, -9.65)
- walls 23/28: 0.231 m between (-5.51, -9.795) and (-5.33, -9.65)
- walls 23/29: 0.231 m between (5.51, -9.795) and (5.33, -9.65)
- walls 24/28: 0.231 m between (-5.51, 9.795) and (-5.33, 9.65)
- walls 24/29: 0.231 m between (5.51, 9.795) and (5.33, 9.65)

### Door-sweep candidates

- `B1_DOOR_02` ↔ `ops_areaway_step00`
- `B1_DOOR_02` ↔ `ops_areaway_step01`
- `B1_DOOR_02` ↔ `ops_areaway_step02`
- `B1_DOOR_02` ↔ `ops_areaway_step03`
- `B1_DOOR_02` ↔ `ops_areaway_step04`
- `B1_DOOR_02` ↔ `ops_areaway_step05`
- `B1_DOOR_02` ↔ `ops_areaway_drain`
- `B1_DOOR_02` ↔ `ops_refuse_bin_2`
- `B1_DOOR_03` ↔ `beam_-1_-4`
- `B1_DOOR_03` ↔ `pier_-1_-4_-68`
- `B1_DOOR_05` ↔ `beam_1_-4`
- `B1_DOOR_06` ↔ `beam_1_4`

### Outside every declared room / unresolved

- `furniture` `ops_areaway_w`: (-1.365, 11.185)
- `furniture` `ops_areaway_e`: (1.365, 11.185)
- `furniture` `ops_areaway_step00`: (0.0, 10.239999999999998)
- `furniture` `ops_areaway_step01`: (0.0, 10.43)
- `furniture` `ops_areaway_step02`: (0.0, 10.620000000000001)
- `furniture` `ops_areaway_step03`: (0.0, 10.809999999999999)
- `furniture` `ops_areaway_step04`: (0.0, 11.0)
- `furniture` `ops_areaway_step05`: (0.0, 11.189999999999998)
- `furniture` `ops_areaway_step06`: (0.0, 11.379999999999999)
- `furniture` `ops_areaway_step07`: (0.0, 11.57)
- `furniture` `ops_areaway_step08`: (0.0, 11.759999999999998)
- `furniture` `ops_areaway_step09`: (0.0, 11.95)
- `furniture` `ops_areaway_step10`: (0.0, 12.14)
- `furniture` `ops_areaway_step11`: (0.0, 12.329999999999998)
- `furniture` `ops_areaway_drain`: (0.0, 10.18)
- `furniture` `ops_areaway_rail_l`: (-1.315, 11.225)
- `furniture` `ops_areaway_rail_r`: (1.315, 11.225)
- `furniture` `ops_compactor`: (2.2, 7.675)
- `furniture` `ops_refuse_bin_0`: (-2.515, 8.54)
- `furniture` `ops_refuse_bin_1`: (-1.6950000000000003, 8.54)
- `furniture` `ops_refuse_bin_2`: (-0.8750000000000002, 8.54)
- `furniture` `B1_SW_01_0`: (-1.29, 6.842)
- `furniture` `B1_SW_02_180`: (0.65, 9.588)
- `furniture` `B1_SW_03_90`: (-5.422, -4.4)
- `furniture` `B1_SW_03_270`: (-5.238, -4.4)
- `furniture` `B1_SW_04_90`: (-5.422, 6.81)
- `furniture` `B1_SW_04_270`: (-5.238, 6.81)
- `furniture` `B1_SW_05_90`: (5.238, -4.675)
- `furniture` `B1_SW_05_270`: (5.422, -4.675)
- `furniture` `B1_SW_06_90`: (5.238, 5.035)
- `furniture` `B1_SW_06_270`: (5.422, 5.035)
- `markers` `B1_ROOM0_DOOR`: (0.0, 6.9)
- `markers` `B1_DOOR_02`: (-0.48, 9.795)
- `markers` `B1_DOOR_03`: (-5.33, -5.529999999999999)
- `markers` `B1_DOOR_04`: (-5.33, 5.68)
- `markers` `B1_DOOR_05`: (5.33, -5.805)
- `markers` `B1_DOOR_06`: (5.33, 3.905)
- `markers` `B1_CORRIDOR_DOME_01`: (-4.35, -5.1)
- `markers` `B1_CORRIDOR_DOME_02`: (-4.35, 0.0)
- `markers` `B1_CORRIDOR_DOME_03`: (-4.35, 5.1)
- `markers` `B1_CORRIDOR_DOME_04`: (4.35, -5.1)
- `markers` `B1_CORRIDOR_DOME_05`: (4.35, 0.0)
- `markers` `B1_CORRIDOR_DOME_06`: (4.35, 5.1)
- `markers` `B1_CORRIDOR_DOME_07`: (0.0, -8.25)
- `markers` `B1_CORRIDOR_DOME_08`: (0.0, 8.25)

## F01

- Rooms: 16; doors: 29; unassigned records: 4394
- Art faces: 44; frame-like records: 19
- Conservative door-sweep candidates: 512
- Wall endpoint near-misses (12–300 mm): 21

| Room | Kind | Unit | Records | Assemblies | Rect parts | Purpose status |
|---|---|---:|---:|---:|---:|---|
| F01_LOBBY | lobby | — | 20 | 5 | 11 | kind only |
| F01_COMMON_B | common | — | 21 | 14 | 4 | kind only |
| F01_STORAGE_C | storage | — | 10 | 9 | 0 | kind only |
| F01_HALL | hall | — | 5 | 1 | 3 | kind only |
| F01_ATRIUM | atrium | — | 23 | 16 | 6 | kind only |
| F01_UTILITY | utility | — | 8 | 1 | 5 | kind only |
| F01_OFFICE | office | — | 6 | 3 | 0 | kind only |
| F01_PACKAGE | storage | — | 5 | 3 | 0 | kind only |
| F01_RESTROOM | bathroom | — | 11 | 2 | 2 | kind only |
| F01_A_BED | bedroom | 1A | 14 | 4 | 5 | kind only |
| F01_A_BATH | bathroom | 1A | 11 | 1 | 2 | kind only |
| F01_A_MAIN | living | 1A | 40 | 16 | 9 | kind only |
| F01_D_BED | bedroom | 1D | 14 | 4 | 5 | kind only |
| F01_D_BATH | bathroom | 1D | 10 | 1 | 2 | kind only |
| F01_D_MAIN | living | 1D | 36 | 13 | 9 | kind only |
| F01_D_OFFICE | office | 1D | 8 | 4 | 0 | kind only |

### Wall endpoint candidates

- walls 2/4: 0.255 m between (-3.43, -6.93) and (-3.25, -6.75)
- walls 2/6: 0.255 m between (-3.43, 6.93) and (-3.25, 6.75)
- walls 3/5: 0.255 m between (3.43, -6.93) and (3.25, -6.75)
- walls 3/7: 0.255 m between (3.43, 6.93) and (3.25, 6.75)
- walls 5/15: 0.250 m between (3.25, -6.75) and (3.0, -6.75)
- walls 8/15: 0.250 m between (3.25, -6.75) and (3.0, -6.75)
- walls 12/18: 0.231 m between (-5.33, -9.65) and (-5.51, -9.795)
- walls 12/20: 0.231 m between (-5.33, 9.65) and (-5.51, 9.795)
- walls 13/22: 0.231 m between (5.33, 9.65) and (5.51, 9.795)
- walls 13/24: 0.231 m between (5.33, -9.65) and (5.51, -9.795)
- walls 17/18: 0.205 m between (-13.795, -9.65) and (-13.65, -9.795)
- walls 17/27: 0.157 m between (-13.795, -0.45) and (-13.65, -0.39)
- walls 19/20: 0.205 m between (-13.795, 9.65) and (-13.65, 9.795)
- walls 19/28: 0.157 m between (-13.795, 2.67) and (-13.65, 2.61)
- walls 21/22: 0.205 m between (13.795, 9.65) and (13.65, 9.795)
- walls 21/23: 0.120 m between (13.795, -0.88) and (13.795, -1.0)
- walls 23/24: 0.205 m between (13.795, -9.65) and (13.65, -9.795)
- walls 23/29: 0.157 m between (13.795, -1.0) and (13.65, -0.94)
- walls 35/36: 0.100 m between (-7.81, -3.79) and (-7.71, -3.79)
- walls 38/39: 0.100 m between (7.81, -3.79) and (7.71, -3.79)
- walls 40/41: 0.100 m between (7.81, -2.84) and (7.71, -2.84)

### Door-sweep candidates

- `F01_DOOR_02` ↔ `1A_k_lino`
- `F01_DOOR_02` ↔ `1A_k_linobar_e`
- `F01_DOOR_06` ↔ `entry_entablature`
- `F01_DOOR_06` ↔ `entry_door_step`
- `F01_DOOR_06` ↔ `water_table_s2`
- `F01_DOOR_06` ↔ `lobby_runner_rug`
- `F01_DOOR_06` ↔ `site_ground_3`
- `F01_DOOR_06` ↔ `site_sidewalk_joint_bed`
- `F01_DOOR_06` ↔ `site_sidewalk_53`
- `F01_DOOR_06` ↔ `storm_leaf78`
- `F01_DOOR_11` ↔ `1A_trail`
- `F01_DOOR_11` ↔ `1A_towel`
- `F01_DOOR_13` ↔ `1D_trail`
- `F01_DOOR_13` ↔ `1D_towel`
- `F01_BODEGA_DOOR` ↔ `site_ground_3`
- `F01_BODEGA_DOOR` ↔ `site_sidewalk_e`
- `F01_BODEGA_DOOR` ↔ `site_nbr_e_base0`
- `F01_BODEGA_DOOR` ↔ `site_nbr_e_soffit`
- `F01_BODEGA_DOOR` ↔ `site_nbr_e_bcorn`
- `F01_BODEGA_DOOR` ↔ `site_nbr_e_s0`
- `F01_BODEGA_DOOR` ↔ `site_nbr_e_c0`
- `F01_BODEGA_DOOR` ↔ `site_nbr_e_par_s`
- `F01_BODEGA_DOOR` ↔ `site_nbr_e_par_e`
- `F01_BODEGA_DOOR` ↔ `retail_bod_floor`
- `F01_BODEGA_DOOR` ↔ `retail_bod_ceil`
- `F01_BODEGA_DOOR` ↔ `retail_bod_wall_e`
- `F01_BODEGA_DOOR` ↔ `retail_bod_stall`
- `F01_BODEGA_DOOR` ↔ `retail_bod_glass`
- `F01_BODEGA_DOOR` ↔ `retail_bod_fascia`
- `F01_BODEGA_DOOR` ↔ `retail_bod_mull182`
- `F01_BODEGA_DOOR` ↔ `retail_bod_head`
- `F01_BODEGA_DOOR` ↔ `retail_bod_gate_box`
- `F01_BODEGA_DOOR` ↔ `retail_bod_gate`
- `F01_BODEGA_DOOR` ↔ `retail_bod_awning`
- `F01_BODEGA_DOOR` ↔ `retail_bod_ws_e0`
- `F01_BODEGA_DOOR` ↔ `retail_bod_ws_e1`
- `F01_BODEGA_DOOR` ↔ `retail_bod_ws_e2`
- `F01_BODEGA_DOOR` ↔ `retail_bod_stk225407783`
- `F01_BODEGA_DOOR` ↔ `storm_wet1`
- `F01_BODEGA_DOOR` ↔ `storm_pud28`
- `F01_BAR_WC_DOOR` ↔ `site_ground_0`
- `F01_BAR_WC_DOOR` ↔ `site_ground_1`
- `F01_BAR_WC_DOOR` ↔ `site_ground_7`
- `F01_BAR_WC_DOOR` ↔ `site_nbr_s2_base0`
- `F01_BAR_WC_DOOR` ↔ `site_nbr_s2_soffit`
- `F01_BAR_WC_DOOR` ↔ `site_nbr_s2_bcorn`
- `F01_BAR_WC_DOOR` ↔ `site_nbr_s2_s0`
- `F01_BAR_WC_DOOR` ↔ `site_nbr_s2_c0`
- `F01_BAR_WC_DOOR` ↔ `retail_bar_fill_w0`
- `F01_BAR_WC_DOOR` ↔ `retail_bar_fill_w2`
- `F01_BAR_WC_DOOR` ↔ `retail_bar_floor`
- `F01_BAR_WC_DOOR` ↔ `retail_bar_ceil0`
- `F01_BAR_WC_DOOR` ↔ `retail_bar_ceil2`
- `F01_BAR_WC_DOOR` ↔ `retail_bar_wc_wall_e`
- `F01_BAR_WC_DOOR` ↔ `retail_bar_wc_wall_n_w`
- `F01_BAR_WC_DOOR` ↔ `retail_bar_wc_wall_n_e`
- `F01_BAR_WC_DOOR` ↔ `retail_bar_wc_lintel`
- `F01_BAR_DOOR` ↔ `site_ground_3`
- `F01_BAR_DOOR` ↔ `site_ground_4`
- `F01_BAR_DOOR` ↔ `site_ground_10`
- `F01_BAR_DOOR` ↔ `site_sidewalk_s_w`
- `F01_BAR_DOOR` ↔ `site_nbr_s2_base0`
- `F01_BAR_DOOR` ↔ `site_nbr_s2_soffit`
- `F01_BAR_DOOR` ↔ `site_nbr_s2_bcorn`
- `F01_BAR_DOOR` ↔ `site_nbr_s2_s0`
- `F01_BAR_DOOR` ↔ `site_nbr_s2_c0`
- `F01_BAR_DOOR` ↔ `site_nbr_s2_par_n`
- `F01_BAR_DOOR` ↔ `retail_bar_lintel`
- `F01_BAR_DOOR` ↔ `retail_bar_lob_floor`
- `F01_BAR_DOOR` ↔ `retail_bar_acc_bill0`
- `F01_BAR_DOOR` ↔ `retail_bar_acc_bill1`
- `F01_BAR_DOOR` ↔ `retail_bar_acc_bill2`
- `F01_BAR_DOOR` ↔ `retail_bar_acc_umb_stand`
- `F01_BAR_DOOR` ↔ `retail_bar_acc_umb_ring`
- `F01_BAR_DOOR` ↔ `retail_bar_acc_news0`
- `F01_BAR_DOOR` ↔ `retail_bar_acc_news1`
- `F01_BAR_DOOR` ↔ `retail_bar_acc_news_twine`
- `F01_BAR_DOOR` ↔ `retail_bar_shaft_e`
- `F01_BAR_DOOR` ↔ `retail_bar_face_fascia`
- `F01_BAR_RED_DOOR` ↔ `site_ground_8`

### Outside every declared room / unresolved

- `furniture` `entry_marquee`: (0.0, -10.0)
- `furniture` `entry_pilaster_w`: (-1.2000000000000002, -10.05)
- `furniture` `entry_pilaster_e`: (1.2000000000000002, -10.05)
- `furniture` `entry_entablature`: (0.0, -10.05)
- `furniture` `entry_door_step`: (0.0, -10.190000000000001)
- `furniture` `water_table_s1`: (-7.3999999999999995, -10.030000000000001)
- `furniture` `water_table_s2`: (7.3999999999999995, -10.030000000000001)
- `furniture` `water_table_w`: (-14.030000000000001, 0.0)
- `furniture` `water_table_e`: (14.030000000000001, 0.0)
- `furniture` `1A_bl0_head`: (-13.835, -7.040000000000001)
- `furniture` `1A_bl0_s0`: (-13.834999999999999, -7.040000000000001)
- `furniture` `1A_bl0_s1`: (-13.834999999999999, -7.040000000000001)
- `furniture` `1A_bl0_s2`: (-13.834999999999999, -7.040000000000001)
- `furniture` `1A_bl0_s3`: (-13.834999999999999, -7.040000000000001)
- `furniture` `1A_bl0_s4`: (-13.834999999999999, -7.040000000000001)
- `furniture` `1A_bl0_s5`: (-13.834999999999999, -7.040000000000001)
- `furniture` `1A_bl0_s6`: (-13.834999999999999, -7.040000000000001)
- `furniture` `1A_bl0_s7`: (-13.834999999999999, -7.040000000000001)
- `furniture` `1A_bl0_s8`: (-13.834999999999999, -7.040000000000001)
- `furniture` `1A_bl0_s9`: (-13.834999999999999, -7.040000000000001)
- `furniture` `1A_bl0_s10`: (-13.834999999999999, -7.040000000000001)
- `furniture` `1A_bl0_s11`: (-13.834999999999999, -7.040000000000001)
- `furniture` `1A_bl0_s12`: (-13.834999999999999, -7.040000000000001)
- `furniture` `1A_bl0_s13`: (-13.834999999999999, -7.040000000000001)
- `furniture` `1A_bl0_s14`: (-13.834999999999999, -7.040000000000001)
- `furniture` `1A_bl0_s15`: (-13.834999999999999, -7.040000000000001)
- `furniture` `1A_bl0_s16`: (-13.834999999999999, -7.040000000000001)
- `furniture` `1A_bl0_s17`: (-13.834999999999999, -7.040000000000001)
- `furniture` `1A_bl0_s18`: (-13.834999999999999, -7.040000000000001)
- `furniture` `1A_bl0_s19`: (-13.834999999999999, -7.040000000000001)
- `furniture` `1A_bl0_s20`: (-13.834999999999999, -7.040000000000001)
- `furniture` `1A_bl0_s21`: (-13.834999999999999, -7.040000000000001)
- `furniture` `1A_bl0_s22`: (-13.834999999999999, -7.040000000000001)
- `furniture` `1A_bl0_s23`: (-13.834999999999999, -7.040000000000001)
- `furniture` `1A_bl0_rail`: (-13.84, -7.040000000000001)
- `furniture` `1A_bl1_head`: (-13.835, -3.21)
- `furniture` `1A_bl1_s0`: (-13.835, -3.21)
- `furniture` `1A_bl1_s1`: (-13.835, -3.21)
- `furniture` `1A_bl1_s2`: (-13.835, -3.21)
- `furniture` `1A_bl1_s3`: (-13.835, -3.21)
- `furniture` `1A_bl1_s4`: (-13.835, -3.21)
- `furniture` `1A_bl1_s5`: (-13.835, -3.21)
- `furniture` `1A_bl1_s6`: (-13.835, -3.21)
- `furniture` `1A_bl1_s7`: (-13.835, -3.21)
- `furniture` `1A_bl1_s8`: (-13.835, -3.21)
- `furniture` `1A_bl1_s9`: (-13.835, -3.21)
- `furniture` `1A_bl1_s10`: (-13.835, -3.21)
- `furniture` `1A_bl1_s11`: (-13.835, -3.21)
- `furniture` `1A_bl1_s12`: (-13.835, -3.21)
- `furniture` `1A_bl1_s13`: (-13.835, -3.21)
- `furniture` `1A_bl1_s14`: (-13.835, -3.21)
- `furniture` `1A_bl1_s15`: (-13.835, -3.21)
- `furniture` `1A_bl1_s16`: (-13.835, -3.21)
- `furniture` `1A_bl1_s17`: (-13.835, -3.21)
- `furniture` `1A_bl1_s18`: (-13.835, -3.21)
- `furniture` `1A_bl1_s19`: (-13.835, -3.21)
- `furniture` `1A_bl1_s20`: (-13.835, -3.21)
- `furniture` `1A_bl1_s21`: (-13.835, -3.21)
- `furniture` `1A_bl1_s22`: (-13.835, -3.21)
- `furniture` `1A_bl1_s23`: (-13.835, -3.21)
- `furniture` `1A_bl1_s24`: (-13.835, -3.21)
- `furniture` `1A_bl1_s25`: (-13.835, -3.21)
- `furniture` `1A_bl1_rail`: (-13.84, -3.21)
- `furniture` `1A_bl2_head`: (-9.58, -9.835)
- `furniture` `1A_bl2_s0`: (-9.579999999999998, -9.834999999999999)
- `furniture` `1A_bl2_s1`: (-9.579999999999998, -9.834999999999999)
- `furniture` `1A_bl2_s2`: (-9.579999999999998, -9.834999999999999)
- `furniture` `1A_bl2_s3`: (-9.579999999999998, -9.834999999999999)
- `furniture` `1A_bl2_s4`: (-9.579999999999998, -9.834999999999999)
- `furniture` `1A_bl2_s5`: (-9.579999999999998, -9.834999999999999)
- `furniture` `1A_bl2_s6`: (-9.579999999999998, -9.834999999999999)
- `furniture` `1A_bl2_s7`: (-9.579999999999998, -9.834999999999999)
- `furniture` `1A_bl2_s8`: (-9.579999999999998, -9.834999999999999)
- `furniture` `1A_bl2_s9`: (-9.579999999999998, -9.834999999999999)
- `furniture` `1A_bl2_s10`: (-9.579999999999998, -9.834999999999999)
- `furniture` `1A_bl2_s11`: (-9.579999999999998, -9.834999999999999)
- `furniture` `1A_bl2_s12`: (-9.579999999999998, -9.834999999999999)
- `furniture` `1A_bl2_s13`: (-9.579999999999998, -9.834999999999999)
- `furniture` `1A_bl2_s14`: (-9.579999999999998, -9.834999999999999)
- `furniture` `1A_bl2_s15`: (-9.579999999999998, -9.834999999999999)

## F02

- Rooms: 20; doors: 15; unassigned records: 286
- Art faces: 50; frame-like records: 36
- Conservative door-sweep candidates: 33
- Wall endpoint near-misses (12–300 mm): 23

| Room | Kind | Unit | Records | Assemblies | Rect parts | Purpose status |
|---|---|---:|---:|---:|---:|---|
| F02_A_BED | bedroom | 2A | 14 | 4 | 5 | kind only |
| F02_A_BATH | bathroom | 2A | 11 | 1 | 2 | kind only |
| F02_A_MAIN | living | 2A | 53 | 23 | 10 | kind only |
| F02_B_ALCOVE | alcove | 2B | 8 | 4 | 0 | kind only |
| F02_B_BATH | bathroom | 2B | 13 | 2 | 2 | kind only |
| F02_B_KITCHEN | kitchen | 2B | 17 | 4 | 4 | kind only |
| F02_B_MAIN | living | 2B | 16 | 8 | 5 | kind only |
| F02_C_BED1 | bedroom | 2C | 14 | 4 | 5 | kind only |
| F02_C_BED2 | bedroom | 2C | 15 | 4 | 5 | kind only |
| F02_C_BATH | bathroom | 2C | 9 | 2 | 0 | kind only |
| F02_C_MAIN | living | 2C | 69 | 23 | 30 | kind only |
| F02_D_BED | bedroom | 2D | 2 | 1 | 0 | kind only |
| F02_D_BATH | bathroom | 2D | 9 | 1 | 2 | kind only |
| F02_D_MAIN | living | 2D | 8 | 5 | 0 | kind only |
| F02_D_OFFICE | office | 2D | 2 | 1 | 0 | kind only |
| F02_WSTOR | storage | — | 15 | 10 | 4 | kind only |
| F02_CORRIDOR | corridor | — | 22 | 5 | 3 | kind only |
| F02_HALL | hall | — | 5 | 1 | 3 | kind only |
| F02_ATRIUM | atrium | — | 23 | 16 | 6 | kind only |
| F02_UTILITY | utility | — | 8 | 1 | 5 | kind only |

### Wall endpoint candidates

- walls 2/4: 0.255 m between (-3.43, -6.93) and (-3.25, -6.75)
- walls 2/6: 0.255 m between (-3.43, 6.93) and (-3.25, 6.75)
- walls 3/5: 0.255 m between (3.43, -6.93) and (3.25, -6.75)
- walls 3/7: 0.255 m between (3.43, 6.93) and (3.25, 6.75)
- walls 5/15: 0.250 m between (3.25, -6.75) and (3.0, -6.75)
- walls 8/15: 0.250 m between (3.25, -6.75) and (3.0, -6.75)
- walls 12/18: 0.251 m between (-5.33, -9.65) and (-5.51, -9.825)
- walls 12/20: 0.251 m between (-5.33, 9.65) and (-5.51, 9.825)
- walls 13/22: 0.251 m between (5.33, 9.65) and (5.51, 9.825)
- walls 13/24: 0.251 m between (5.33, -9.65) and (5.51, -9.825)
- walls 17/18: 0.247 m between (-13.825, -9.65) and (-13.65, -9.825)
- walls 17/27: 0.185 m between (-13.825, -0.45) and (-13.65, -0.39)
- walls 19/20: 0.247 m between (-13.825, 9.65) and (-13.65, 9.825)
- walls 19/28: 0.185 m between (-13.825, 2.67) and (-13.65, 2.61)
- walls 21/22: 0.247 m between (13.825, 9.65) and (13.65, 9.825)
- walls 21/23: 0.120 m between (13.825, -0.88) and (13.825, -1.0)
- walls 23/24: 0.247 m between (13.825, -9.65) and (13.65, -9.825)
- walls 23/29: 0.185 m between (13.825, -1.0) and (13.65, -0.94)
- walls 31/32: 0.100 m between (-7.81, -3.79) and (-7.71, -3.79)
- walls 39/47: 0.277 m between (9.58, 9.65) and (9.55, 9.375)
- walls 40/41: 0.100 m between (7.81, 3.79) and (7.71, 3.79)
- walls 43/44: 0.100 m between (7.81, -3.79) and (7.71, -3.79)
- walls 45/46: 0.100 m between (7.81, -2.84) and (7.71, -2.84)

### Door-sweep candidates

- `F02_DOOR_02` ↔ `2A_k_lino`
- `F02_DOOR_02` ↔ `2A_k_linobar_e`
- `F02_DOOR_02` ↔ `sign_F02_apt_2A_back`
- `F02_DOOR_02` ↔ `sign_F02_apt_2A_face`
- `F02_DOOR_02` ↔ `age_lane_wF02`
- `F02_DOOR_03` ↔ `sign_F02_apt_2B_back`
- `F02_DOOR_03` ↔ `sign_F02_apt_2B_face`
- `F02_DOOR_03` ↔ `age_lane_wF02`
- `F02_DOOR_04` ↔ `F02_wstor_roll`
- `F02_DOOR_04` ↔ `age_lane_wF02`
- `F02_DOOR_05` ↔ `2C_k_lino`
- `F02_DOOR_05` ↔ `2C_k_linobar_s`
- `F02_DOOR_05` ↔ `sign_F02_apt_2C_back`
- `F02_DOOR_05` ↔ `sign_F02_apt_2C_face`
- `F02_DOOR_06` ↔ `2B_k_lino`
- `F02_DOOR_06` ↔ `2B_k_linobar_w`
- `F02_DOOR_06` ↔ `2B_k_linobar_n`
- `F02_DOOR_06` ↔ `F02_porch_deck`
- `F02_DOOR_06` ↔ `F02_porch_rail_e_top`
- `F02_DOOR_06` ↔ `F02_porch_rail_e_mid`
- `F02_DOOR_06` ↔ `F02_porch_step0`
- `F02_DOOR_06` ↔ `F02_porch_post_-77_100`
- `F02_DOOR_08` ↔ `2A_trail`
- `F02_DOOR_08` ↔ `2A_towel`
- `F02_DOOR_10` ↔ `2C_cablerug`
- `F02_DOOR_11` ↔ `2C_bart1_art`
- `F02_DOOR_11` ↔ `2C_bart1_artf`
- `F02_DOOR_11` ↔ `2C_bart1_artf2`
- `F02_DOOR_11` ↔ `2C_bart1_artfl`
- `F02_DOOR_12` ↔ `2C_bench`
- `F02_DOOR_12` ↔ `2C_cablerug`
- `F02_DOOR_14` ↔ `2D_trail`
- `F02_DOOR_14` ↔ `2D_towel`

### Outside every declared room / unresolved

- `furniture` `2C_trail`: (5.494999999999999, 5.699999999999999)
- `furniture` `2C_towel`: (5.49, 5.68)
- `furniture` `F02_porch_deck`: (-9.15, 10.7)
- `furniture` `F02_porch_rail_n_top`: (-9.15, 11.309999999999999)
- `furniture` `F02_porch_rail_n_mid`: (-9.15, 11.309999999999999)
- `furniture` `F02_porch_rail_w_top`: (-10.559999999999999, 10.7)
- `furniture` `F02_porch_rail_w_mid`: (-10.559999999999999, 10.7)
- `furniture` `F02_porch_rail_e_top`: (-7.74, 10.7)
- `furniture` `F02_porch_rail_e_mid`: (-7.74, 10.7)
- `furniture` `F02_porch_step0`: (-7.49, 10.65)
- `furniture` `F02_porch_step1`: (-7.2, 10.65)
- `furniture` `F02_porch_step2`: (-6.91, 10.65)
- `furniture` `F02_porch_step3`: (-6.62, 10.65)
- `furniture` `F02_porch_step4`: (-6.33, 10.65)
- `furniture` `F02_porch_step5`: (-6.04, 10.65)
- `furniture` `F02_porch_step6`: (-5.750000000000001, 10.65)
- `furniture` `F02_porch_step7`: (-5.46, 10.65)
- `furniture` `F02_porch_post_-106_100`: (-10.559999999999999, 10.14)
- `furniture` `F02_porch_post_-106_112`: (-10.559999999999999, 11.3)
- `furniture` `F02_porch_post_-77_100`: (-7.66, 10.14)
- `furniture` `F02_porch_post_-77_112`: (-7.66, 11.3)
- `furniture` `2A_bl0_head`: (-13.834999999999997, -7.040000000000001)
- `furniture` `2A_bl0_s0`: (-13.834999999999997, -7.040000000000001)
- `furniture` `2A_bl0_s1`: (-13.834999999999997, -7.040000000000001)
- `furniture` `2A_bl0_s2`: (-13.834999999999997, -7.040000000000001)
- `furniture` `2A_bl0_s3`: (-13.834999999999997, -7.040000000000001)
- `furniture` `2A_bl0_s4`: (-13.834999999999997, -7.040000000000001)
- `furniture` `2A_bl0_s5`: (-13.834999999999997, -7.040000000000001)
- `furniture` `2A_bl0_s6`: (-13.834999999999997, -7.040000000000001)
- `furniture` `2A_bl0_s7`: (-13.834999999999997, -7.040000000000001)
- `furniture` `2A_bl0_s8`: (-13.834999999999997, -7.040000000000001)
- `furniture` `2A_bl0_s9`: (-13.834999999999997, -7.040000000000001)
- `furniture` `2A_bl0_s10`: (-13.834999999999997, -7.040000000000001)
- `furniture` `2A_bl0_s11`: (-13.834999999999997, -7.040000000000001)
- `furniture` `2A_bl0_s12`: (-13.834999999999997, -7.040000000000001)
- `furniture` `2A_bl0_s13`: (-13.834999999999997, -7.040000000000001)
- `furniture` `2A_bl0_s14`: (-13.834999999999997, -7.040000000000001)
- `furniture` `2A_bl0_s15`: (-13.834999999999997, -7.040000000000001)
- `furniture` `2A_bl0_s16`: (-13.834999999999997, -7.040000000000001)
- `furniture` `2A_bl0_s17`: (-13.834999999999997, -7.040000000000001)
- `furniture` `2A_bl0_s18`: (-13.834999999999997, -7.040000000000001)
- `furniture` `2A_bl0_s19`: (-13.834999999999997, -7.040000000000001)
- `furniture` `2A_bl0_s20`: (-13.834999999999997, -7.040000000000001)
- `furniture` `2A_bl0_s21`: (-13.834999999999997, -7.040000000000001)
- `furniture` `2A_bl0_s22`: (-13.834999999999997, -7.040000000000001)
- `furniture` `2A_bl0_s23`: (-13.834999999999997, -7.040000000000001)
- `furniture` `2A_bl0_s24`: (-13.834999999999997, -7.040000000000001)
- `furniture` `2A_bl0_s25`: (-13.834999999999997, -7.040000000000001)
- `furniture` `2A_bl0_rail`: (-13.839999999999998, -7.040000000000001)
- `furniture` `2A_bl1_head`: (-13.834999999999997, -3.21)
- `furniture` `2A_bl1_s0`: (-13.834999999999997, -3.21)
- `furniture` `2A_bl1_s1`: (-13.834999999999997, -3.21)
- `furniture` `2A_bl1_s2`: (-13.834999999999997, -3.21)
- `furniture` `2A_bl1_s3`: (-13.834999999999997, -3.21)
- `furniture` `2A_bl1_s4`: (-13.834999999999997, -3.21)
- `furniture` `2A_bl1_s5`: (-13.834999999999997, -3.21)
- `furniture` `2A_bl1_s6`: (-13.834999999999997, -3.21)
- `furniture` `2A_bl1_s7`: (-13.834999999999997, -3.21)
- `furniture` `2A_bl1_s8`: (-13.834999999999997, -3.21)
- `furniture` `2A_bl1_s9`: (-13.834999999999997, -3.21)
- `furniture` `2A_bl1_s10`: (-13.834999999999997, -3.21)
- `furniture` `2A_bl1_s11`: (-13.834999999999997, -3.21)
- `furniture` `2A_bl1_s12`: (-13.834999999999997, -3.21)
- `furniture` `2A_bl1_s13`: (-13.834999999999997, -3.21)
- `furniture` `2A_bl1_s14`: (-13.834999999999997, -3.21)
- `furniture` `2A_bl1_s15`: (-13.834999999999997, -3.21)
- `furniture` `2A_bl1_s16`: (-13.834999999999997, -3.21)
- `furniture` `2A_bl1_s17`: (-13.834999999999997, -3.21)
- `furniture` `2A_bl1_s18`: (-13.834999999999997, -3.21)
- `furniture` `2A_bl1_s19`: (-13.834999999999997, -3.21)
- `furniture` `2A_bl1_s20`: (-13.834999999999997, -3.21)
- `furniture` `2A_bl1_s21`: (-13.834999999999997, -3.21)
- `furniture` `2A_bl1_s22`: (-13.834999999999997, -3.21)
- `furniture` `2A_bl1_s23`: (-13.834999999999997, -3.21)
- `furniture` `2A_bl1_s24`: (-13.834999999999997, -3.21)
- `furniture` `2A_bl1_s25`: (-13.834999999999997, -3.21)
- `furniture` `2A_bl1_s26`: (-13.834999999999997, -3.21)
- `furniture` `2A_bl1_rail`: (-13.839999999999998, -3.21)
- `furniture` `2A_bl2_head`: (-9.58, -9.834999999999997)
- `furniture` `2A_bl2_s0`: (-9.579999999999998, -9.834999999999997)

## F03

- Rooms: 20; doors: 14; unassigned records: 267
- Art faces: 31; frame-like records: 20
- Conservative door-sweep candidates: 27
- Wall endpoint near-misses (12–300 mm): 23

| Room | Kind | Unit | Records | Assemblies | Rect parts | Purpose status |
|---|---|---:|---:|---:|---:|---|
| F03_A_BED | bedroom | 3A | 14 | 4 | 5 | kind only |
| F03_A_BATH | bathroom | 3A | 11 | 1 | 2 | kind only |
| F03_A_MAIN | living | 3A | 35 | 13 | 9 | kind only |
| F03_B_ALCOVE | alcove | 3B | 8 | 4 | 0 | kind only |
| F03_B_BATH | bathroom | 3B | 13 | 2 | 2 | kind only |
| F03_B_KITCHEN | kitchen | 3B | 25 | 6 | 8 | kind only |
| F03_B_MAIN | living | 3B | 27 | 17 | 5 | kind only |
| F03_C_BED1 | bedroom | 3C | 5 | 1 | 3 | kind only |
| F03_C_BED2 | bedroom | 3C | 8 | 1 | 5 | kind only |
| F03_C_BATH | bathroom | 3C | 7 | 1 | 0 | kind only |
| F03_C_MAIN | living | 3C | 13 | 3 | 6 | kind only |
| F03_D_BED | bedroom | 3D | 15 | 4 | 5 | kind only |
| F03_D_BATH | bathroom | 3D | 10 | 1 | 2 | kind only |
| F03_D_MAIN | living | 3D | 58 | 18 | 23 | kind only |
| F03_D_OFFICE | office | 3D | 8 | 4 | 0 | kind only |
| F03_WSTOR | storage | — | 16 | 11 | 4 | kind only |
| F03_CORRIDOR | corridor | — | 25 | 6 | 3 | kind only |
| F03_HALL | hall | — | 5 | 1 | 3 | kind only |
| F03_ATRIUM | atrium | — | 23 | 16 | 6 | kind only |
| F03_UTILITY | utility | — | 8 | 1 | 5 | kind only |

### Wall endpoint candidates

- walls 2/4: 0.255 m between (-3.43, -6.93) and (-3.25, -6.75)
- walls 2/6: 0.255 m between (-3.43, 6.93) and (-3.25, 6.75)
- walls 3/5: 0.255 m between (3.43, -6.93) and (3.25, -6.75)
- walls 3/7: 0.255 m between (3.43, 6.93) and (3.25, 6.75)
- walls 5/15: 0.250 m between (3.25, -6.75) and (3.0, -6.75)
- walls 8/15: 0.250 m between (3.25, -6.75) and (3.0, -6.75)
- walls 12/18: 0.251 m between (-5.33, -9.65) and (-5.51, -9.825)
- walls 12/20: 0.251 m between (-5.33, 9.65) and (-5.51, 9.825)
- walls 13/22: 0.251 m between (5.33, 9.65) and (5.51, 9.825)
- walls 13/24: 0.251 m between (5.33, -9.65) and (5.51, -9.825)
- walls 17/18: 0.247 m between (-13.825, -9.65) and (-13.65, -9.825)
- walls 17/27: 0.185 m between (-13.825, -0.45) and (-13.65, -0.39)
- walls 19/20: 0.247 m between (-13.825, 9.65) and (-13.65, 9.825)
- walls 19/28: 0.185 m between (-13.825, 2.67) and (-13.65, 2.61)
- walls 21/22: 0.247 m between (13.825, 9.65) and (13.65, 9.825)
- walls 21/23: 0.120 m between (13.825, -0.88) and (13.825, -1.0)
- walls 23/24: 0.247 m between (13.825, -9.65) and (13.65, -9.825)
- walls 23/29: 0.185 m between (13.825, -1.0) and (13.65, -0.94)
- walls 31/32: 0.100 m between (-7.81, -3.79) and (-7.71, -3.79)
- walls 39/47: 0.277 m between (9.58, 9.65) and (9.55, 9.375)
- walls 40/41: 0.100 m between (7.81, 3.79) and (7.71, 3.79)
- walls 43/44: 0.100 m between (7.81, -3.79) and (7.71, -3.79)
- walls 45/46: 0.100 m between (7.81, -2.84) and (7.71, -2.84)

### Door-sweep candidates

- `F03_DOOR_02` ↔ `3A_k_lino`
- `F03_DOOR_02` ↔ `3A_k_linobar_e`
- `F03_DOOR_02` ↔ `sign_F03_apt_3A_back`
- `F03_DOOR_02` ↔ `sign_F03_apt_3A_face`
- `F03_DOOR_02` ↔ `age_lane_wF03`
- `F03_DOOR_03` ↔ `sign_F03_apt_3B_back`
- `F03_DOOR_03` ↔ `sign_F03_apt_3B_face`
- `F03_DOOR_03` ↔ `age_lane_wF03`
- `F03_DOOR_04` ↔ `F03_wstor_roll`
- `F03_DOOR_04` ↔ `age_lane_wF03`
- `F03_DOOR_05` ↔ `sign_F03_apt_3D_back`
- `F03_DOOR_05` ↔ `sign_F03_apt_3D_face`
- `F03_DOOR_06` ↔ `3C_bucket0`
- `F03_DOOR_06` ↔ `sign_F03_apt_3C_back`
- `F03_DOOR_06` ↔ `sign_F03_apt_3C_face`
- `F03_DOOR_07` ↔ `3B_k_lino`
- `F03_DOOR_07` ↔ `3B_k_linobar_w`
- `F03_DOOR_07` ↔ `3B_k_linobar_n`
- `F03_DOOR_07` ↔ `F03_porch_deck`
- `F03_DOOR_07` ↔ `F03_porch_rail_e_top`
- `F03_DOOR_07` ↔ `F03_porch_rail_e_mid`
- `F03_DOOR_07` ↔ `F03_porch_step0`
- `F03_DOOR_09` ↔ `3A_trail`
- `F03_DOOR_09` ↔ `3A_towel`
- `F03_DOOR_11` ↔ `3C_tarp`
- `F03_DOOR_13` ↔ `3D_trail`
- `F03_DOOR_13` ↔ `3D_towel`

### Outside every declared room / unresolved

- `furniture` `3C_trail`: (5.494999999999999, 5.699999999999999)
- `furniture` `3C_towel`: (5.49, 5.68)
- `furniture` `F03_porch_deck`: (-9.15, 10.7)
- `furniture` `F03_porch_rail_n_top`: (-9.15, 11.309999999999999)
- `furniture` `F03_porch_rail_n_mid`: (-9.15, 11.309999999999999)
- `furniture` `F03_porch_rail_w_top`: (-10.559999999999999, 10.7)
- `furniture` `F03_porch_rail_w_mid`: (-10.559999999999999, 10.7)
- `furniture` `F03_porch_rail_e_top`: (-7.74, 10.7)
- `furniture` `F03_porch_rail_e_mid`: (-7.74, 10.7)
- `furniture` `F03_porch_step0`: (-7.49, 10.65)
- `furniture` `F03_porch_step1`: (-7.2, 10.65)
- `furniture` `F03_porch_step2`: (-6.91, 10.65)
- `furniture` `F03_porch_step3`: (-6.62, 10.65)
- `furniture` `F03_porch_step4`: (-6.33, 10.65)
- `furniture` `F03_porch_step5`: (-6.04, 10.65)
- `furniture` `F03_porch_step6`: (-5.750000000000001, 10.65)
- `furniture` `F03_porch_step7`: (-5.46, 10.65)
- `furniture` `3A_bl0_head`: (-13.834999999999997, -7.040000000000001)
- `furniture` `3A_bl0_s0`: (-13.834999999999997, -7.040000000000001)
- `furniture` `3A_bl0_s1`: (-13.834999999999997, -7.040000000000001)
- `furniture` `3A_bl0_s2`: (-13.834999999999997, -7.040000000000001)
- `furniture` `3A_bl0_s3`: (-13.834999999999997, -7.040000000000001)
- `furniture` `3A_bl0_s4`: (-13.834999999999997, -7.040000000000001)
- `furniture` `3A_bl0_s5`: (-13.834999999999997, -7.040000000000001)
- `furniture` `3A_bl0_s6`: (-13.834999999999997, -7.040000000000001)
- `furniture` `3A_bl0_s7`: (-13.834999999999997, -7.040000000000001)
- `furniture` `3A_bl0_s8`: (-13.834999999999997, -7.040000000000001)
- `furniture` `3A_bl0_s9`: (-13.834999999999997, -7.040000000000001)
- `furniture` `3A_bl0_s10`: (-13.834999999999997, -7.040000000000001)
- `furniture` `3A_bl0_s11`: (-13.834999999999997, -7.040000000000001)
- `furniture` `3A_bl0_s12`: (-13.834999999999997, -7.040000000000001)
- `furniture` `3A_bl0_s13`: (-13.834999999999997, -7.040000000000001)
- `furniture` `3A_bl0_s14`: (-13.834999999999997, -7.040000000000001)
- `furniture` `3A_bl0_s15`: (-13.834999999999997, -7.040000000000001)
- `furniture` `3A_bl0_s16`: (-13.834999999999997, -7.040000000000001)
- `furniture` `3A_bl0_s17`: (-13.834999999999997, -7.040000000000001)
- `furniture` `3A_bl0_s18`: (-13.834999999999997, -7.040000000000001)
- `furniture` `3A_bl0_s19`: (-13.834999999999997, -7.040000000000001)
- `furniture` `3A_bl0_s20`: (-13.834999999999997, -7.040000000000001)
- `furniture` `3A_bl0_s21`: (-13.834999999999997, -7.040000000000001)
- `furniture` `3A_bl0_s22`: (-13.834999999999997, -7.040000000000001)
- `furniture` `3A_bl0_s23`: (-13.834999999999997, -7.040000000000001)
- `furniture` `3A_bl0_s24`: (-13.834999999999997, -7.040000000000001)
- `furniture` `3A_bl0_s25`: (-13.834999999999997, -7.040000000000001)
- `furniture` `3A_bl0_s26`: (-13.834999999999997, -7.040000000000001)
- `furniture` `3A_bl0_rail`: (-13.839999999999998, -7.040000000000001)
- `furniture` `3A_bl1_head`: (-13.834999999999997, -3.21)
- `furniture` `3A_bl1_s0`: (-13.834999999999997, -3.21)
- `furniture` `3A_bl1_s1`: (-13.834999999999997, -3.21)
- `furniture` `3A_bl1_s2`: (-13.834999999999997, -3.21)
- `furniture` `3A_bl1_s3`: (-13.834999999999997, -3.21)
- `furniture` `3A_bl1_s4`: (-13.834999999999997, -3.21)
- `furniture` `3A_bl1_s5`: (-13.834999999999997, -3.21)
- `furniture` `3A_bl1_s6`: (-13.834999999999997, -3.21)
- `furniture` `3A_bl1_s7`: (-13.834999999999997, -3.21)
- `furniture` `3A_bl1_s8`: (-13.834999999999997, -3.21)
- `furniture` `3A_bl1_s9`: (-13.834999999999997, -3.21)
- `furniture` `3A_bl1_s10`: (-13.834999999999997, -3.21)
- `furniture` `3A_bl1_s11`: (-13.834999999999997, -3.21)
- `furniture` `3A_bl1_s12`: (-13.834999999999997, -3.21)
- `furniture` `3A_bl1_s13`: (-13.834999999999997, -3.21)
- `furniture` `3A_bl1_s14`: (-13.834999999999997, -3.21)
- `furniture` `3A_bl1_s15`: (-13.834999999999997, -3.21)
- `furniture` `3A_bl1_s16`: (-13.834999999999997, -3.21)
- `furniture` `3A_bl1_s17`: (-13.834999999999997, -3.21)
- `furniture` `3A_bl1_s18`: (-13.834999999999997, -3.21)
- `furniture` `3A_bl1_rail`: (-13.839999999999998, -3.21)
- `furniture` `3A_bl2_head`: (-9.58, -9.834999999999997)
- `furniture` `3A_bl2_s0`: (-9.579999999999998, -9.834999999999997)
- `furniture` `3A_bl2_s1`: (-9.579999999999998, -9.834999999999997)
- `furniture` `3A_bl2_s2`: (-9.579999999999998, -9.834999999999997)
- `furniture` `3A_bl2_s3`: (-9.579999999999998, -9.834999999999997)
- `furniture` `3A_bl2_s4`: (-9.579999999999998, -9.834999999999997)
- `furniture` `3A_bl2_s5`: (-9.579999999999998, -9.834999999999997)
- `furniture` `3A_bl2_s6`: (-9.579999999999998, -9.834999999999997)
- `furniture` `3A_bl2_s7`: (-9.579999999999998, -9.834999999999997)
- `furniture` `3A_bl2_s8`: (-9.579999999999998, -9.834999999999997)
- `furniture` `3A_bl2_s9`: (-9.579999999999998, -9.834999999999997)
- `furniture` `3A_bl2_s10`: (-9.579999999999998, -9.834999999999997)
- `furniture` `3A_bl2_s11`: (-9.579999999999998, -9.834999999999997)

## F04

- Rooms: 22; doors: 21; unassigned records: 274
- Art faces: 41; frame-like records: 28
- Conservative door-sweep candidates: 95
- Wall endpoint near-misses (12–300 mm): 23

| Room | Kind | Unit | Records | Assemblies | Rect parts | Purpose status |
|---|---|---:|---:|---:|---:|---|
| F04_A_BED | bedroom | 4A | 14 | 4 | 5 | kind only |
| F04_A_BATH | bathroom | 4A | 11 | 1 | 2 | kind only |
| F04_A_MAIN | living | 4A | 34 | 12 | 9 | kind only |
| F04_B_VESTIBULE | vestibule | 4B | 4 | 2 | 0 | kind only |
| F04_B_BATH | bathroom | 4B | 11 | 2 | 2 | kind only |
| F04_B_CLOSET | closet | 4B | 2 | 1 | 0 | kind only |
| F04_B_KITCHEN | kitchen | 4B | 27 | 4 | 11 | kind only |
| F04_B_MAIN | living | 4B | 21 | 6 | 6 | kind only |
| F04_B_ALCOVE | alcove | 4B | 11 | 0 | 10 | kind only |
| F04_C_BED1 | bedroom | 4C | 14 | 4 | 5 | kind only |
| F04_C_BED2 | bedroom | 4C | 15 | 4 | 5 | kind only |
| F04_C_BATH | bathroom | 4C | 9 | 2 | 0 | kind only |
| F04_C_MAIN | living | 4C | 38 | 14 | 9 | kind only |
| F04_D_BED | bedroom | 4D | 14 | 4 | 5 | kind only |
| F04_D_BATH | bathroom | 4D | 10 | 1 | 2 | kind only |
| F04_D_MAIN | living | 4D | 34 | 13 | 9 | kind only |
| F04_D_OFFICE | office | 4D | 8 | 4 | 0 | kind only |
| F04_WSTOR | storage | — | 16 | 11 | 4 | kind only |
| F04_CORRIDOR | corridor | — | 24 | 6 | 3 | kind only |
| F04_HALL | hall | — | 5 | 1 | 3 | kind only |
| F04_ATRIUM | atrium | — | 23 | 16 | 6 | kind only |
| F04_UTILITY | utility | — | 8 | 1 | 5 | kind only |

### Wall endpoint candidates

- walls 2/4: 0.255 m between (-3.43, -6.93) and (-3.25, -6.75)
- walls 2/6: 0.255 m between (-3.43, 6.93) and (-3.25, 6.75)
- walls 3/5: 0.255 m between (3.43, -6.93) and (3.25, -6.75)
- walls 3/7: 0.255 m between (3.43, 6.93) and (3.25, 6.75)
- walls 5/15: 0.250 m between (3.25, -6.75) and (3.0, -6.75)
- walls 8/15: 0.250 m between (3.25, -6.75) and (3.0, -6.75)
- walls 12/18: 0.269 m between (-5.33, -9.65) and (-5.51, -9.85)
- walls 12/20: 0.269 m between (-5.33, 9.65) and (-5.51, 9.85)
- walls 13/22: 0.269 m between (5.33, 9.65) and (5.51, 9.85)
- walls 13/24: 0.269 m between (5.33, -9.65) and (5.51, -9.85)
- walls 17/18: 0.283 m between (-13.85, -9.65) and (-13.65, -9.85)
- walls 17/27: 0.209 m between (-13.85, -0.45) and (-13.65, -0.39)
- walls 19/20: 0.283 m between (-13.85, 9.65) and (-13.65, 9.85)
- walls 19/28: 0.209 m between (-13.85, 2.67) and (-13.65, 2.61)
- walls 21/22: 0.283 m between (13.85, 9.65) and (13.65, 9.85)
- walls 21/23: 0.120 m between (13.85, -0.88) and (13.85, -1.0)
- walls 23/24: 0.283 m between (13.85, -9.65) and (13.65, -9.85)
- walls 23/29: 0.209 m between (13.85, -1.0) and (13.65, -0.94)
- walls 31/32: 0.100 m between (-7.81, -3.79) and (-7.71, -3.79)
- walls 43/51: 0.277 m between (9.58, 9.65) and (9.55, 9.375)
- walls 44/45: 0.100 m between (7.81, 3.79) and (7.71, 3.79)
- walls 47/48: 0.100 m between (7.81, -3.79) and (7.71, -3.79)
- walls 49/50: 0.100 m between (7.81, -2.84) and (7.71, -2.84)

### Door-sweep candidates

- `F04_CAB_LOWER_1` ↔ `kitchen_counter_w`
- `F04_CAB_LOWER_1` ↔ `kitchen_counter_e`
- `F04_CAB_LOWER_1` ↔ `kitchen_counter_s`
- `F04_CAB_LOWER_1` ↔ `kitchen_counter_n`
- `F04_CAB_LOWER_1` ↔ `4B_kitchen_countertop_w`
- `F04_CAB_LOWER_1` ↔ `4B_kitchen_countertop_e`
- `F04_CAB_LOWER_1` ↔ `4B_kitchen_countertop_s`
- `F04_CAB_LOWER_1` ↔ `4B_kitchen_countertop_n`
- `F04_CAB_LOWER_1` ↔ `4B_uppers`
- `F04_CAB_LOWER_1` ↔ `4B_bl2_head`
- `F04_CAB_LOWER_1` ↔ `4B_bl2_s0`
- `F04_CAB_LOWER_1` ↔ `4B_bl2_s1`
- `F04_CAB_LOWER_1` ↔ `4B_bl2_s2`
- `F04_CAB_LOWER_1` ↔ `4B_bl2_s3`
- `F04_CAB_LOWER_1` ↔ `4B_bl2_s4`
- `F04_CAB_LOWER_1` ↔ `4B_bl2_s5`
- `F04_CAB_LOWER_1` ↔ `4B_bl2_s6`
- `F04_CAB_LOWER_1` ↔ `4B_bl2_s7`
- `F04_CAB_LOWER_1` ↔ `4B_bl2_s8`
- `F04_CAB_LOWER_1` ↔ `4B_bl2_s9`
- `F04_CAB_LOWER_1` ↔ `4B_bl2_s10`
- `F04_CAB_LOWER_1` ↔ `4B_bl2_rail`
- `F04_CAB_LOWER_2` ↔ `kitchen_counter_e`
- `F04_CAB_LOWER_2` ↔ `kitchen_counter_s`
- `F04_CAB_LOWER_2` ↔ `kitchen_counter_n`
- `F04_CAB_LOWER_2` ↔ `4B_kitchen_countertop_e`
- `F04_CAB_LOWER_2` ↔ `4B_kitchen_countertop_s`
- `F04_CAB_LOWER_2` ↔ `4B_kitchen_countertop_n`
- `F04_CAB_LOWER_2` ↔ `4B_stove_plinth`
- `F04_CAB_LOWER_2` ↔ `4B_splashback`
- `F04_CAB_LOWER_2` ↔ `4B_bl2_head`
- `F04_CAB_LOWER_2` ↔ `4B_bl2_s0`
- `F04_CAB_LOWER_2` ↔ `4B_bl2_s1`
- `F04_CAB_LOWER_2` ↔ `4B_bl2_s2`
- `F04_CAB_LOWER_2` ↔ `4B_bl2_s3`
- `F04_CAB_LOWER_2` ↔ `4B_bl2_s4`
- `F04_CAB_LOWER_2` ↔ `4B_bl2_s5`
- `F04_CAB_LOWER_2` ↔ `4B_bl2_s6`
- `F04_CAB_LOWER_2` ↔ `4B_bl2_s7`
- `F04_CAB_LOWER_2` ↔ `4B_bl2_s8`
- `F04_CAB_LOWER_2` ↔ `4B_bl2_s9`
- `F04_CAB_LOWER_2` ↔ `4B_bl2_s10`
- `F04_CAB_LOWER_2` ↔ `4B_bl2_rail`
- `F04_CAB_UPPER_1` ↔ `kitchen_counter_w`
- `F04_CAB_UPPER_1` ↔ `kitchen_counter_s`
- `F04_CAB_UPPER_1` ↔ `kitchen_counter_n`
- `F04_CAB_UPPER_1` ↔ `4B_kitchen_countertop_w`
- `F04_CAB_UPPER_1` ↔ `4B_kitchen_countertop_s`
- `F04_CAB_UPPER_1` ↔ `4B_kitchen_countertop_n`
- `F04_CAB_UPPER_1` ↔ `4B_uppers`
- `F04_CAB_UPPER_1` ↔ `F04_porch_deck`
- `F04_CAB_UPPER_1` ↔ `F04_porch_rail_w_top`
- `F04_CAB_UPPER_1` ↔ `F04_porch_rail_w_mid`
- `F04_CAB_UPPER_1` ↔ `4B_bl2_head`
- `F04_CAB_UPPER_1` ↔ `4B_bl2_s0`
- `F04_CAB_UPPER_1` ↔ `4B_bl2_s1`
- `F04_CAB_UPPER_1` ↔ `4B_bl2_s2`
- `F04_CAB_UPPER_1` ↔ `4B_bl2_s3`
- `F04_CAB_UPPER_1` ↔ `4B_bl2_s4`
- `F04_CAB_UPPER_1` ↔ `4B_bl2_s5`
- `F04_CAB_UPPER_1` ↔ `4B_bl2_s6`
- `F04_CAB_UPPER_1` ↔ `4B_bl2_s7`
- `F04_CAB_UPPER_1` ↔ `4B_bl2_s8`
- `F04_CAB_UPPER_1` ↔ `4B_bl2_s9`
- `F04_CAB_UPPER_1` ↔ `4B_bl2_s10`
- `F04_CAB_UPPER_1` ↔ `4B_bl2_rail`
- `F04_DOOR_02` ↔ `4A_k_lino`
- `F04_DOOR_02` ↔ `4A_k_linobar_e`
- `F04_DOOR_02` ↔ `sign_F04_apt_4A_back`
- `F04_DOOR_02` ↔ `sign_F04_apt_4A_face`
- `F04_DOOR_02` ↔ `age_lane_wF04`
- `F04_DOOR_03` ↔ `age_lane_wF04`
- `F04_DOOR_04` ↔ `F04_wstor_roll`
- `F04_DOOR_04` ↔ `age_lane_wF04`
- `F04_DOOR_05` ↔ `sign_F04_apt_4D_back`
- `F04_DOOR_05` ↔ `sign_F04_apt_4D_face`
- `F04_DOOR_06` ↔ `4C_k_lino`
- `F04_DOOR_06` ↔ `4C_k_linobar_s`
- `F04_DOOR_06` ↔ `sign_F04_apt_4C_back`
- `F04_DOOR_06` ↔ `sign_F04_apt_4C_face`

### Outside every declared room / unresolved

- `furniture` `4A_story_deadlines`: (-13.695, -5.05)
- `furniture` `4C_trail`: (5.494999999999999, 5.699999999999999)
- `furniture` `4C_towel`: (5.49, 5.68)
- `furniture` `4C_story_familyboard`: (13.695, 4.385)
- `furniture` `F04_porch_deck`: (-9.15, 10.7)
- `furniture` `F04_porch_rail_n_top`: (-9.15, 11.309999999999999)
- `furniture` `F04_porch_rail_n_mid`: (-9.15, 11.309999999999999)
- `furniture` `F04_porch_rail_w_top`: (-10.559999999999999, 10.7)
- `furniture` `F04_porch_rail_w_mid`: (-10.559999999999999, 10.7)
- `furniture` `F04_porch_rail_e_top`: (-7.74, 10.7)
- `furniture` `F04_porch_rail_e_mid`: (-7.74, 10.7)
- `furniture` `F04_porch_step0`: (-7.49, 10.65)
- `furniture` `F04_porch_step1`: (-7.2, 10.65)
- `furniture` `F04_porch_step2`: (-6.91, 10.65)
- `furniture` `F04_porch_step3`: (-6.62, 10.65)
- `furniture` `F04_porch_step4`: (-6.33, 10.65)
- `furniture` `F04_porch_step5`: (-6.04, 10.65)
- `furniture` `F04_porch_step6`: (-5.750000000000001, 10.65)
- `furniture` `F04_porch_step7`: (-5.46, 10.65)
- `furniture` `4A_bl0_head`: (-13.835, -7.040000000000001)
- `furniture` `4A_bl0_s0`: (-13.835, -7.040000000000001)
- `furniture` `4A_bl0_s1`: (-13.835, -7.040000000000001)
- `furniture` `4A_bl0_s2`: (-13.835, -7.040000000000001)
- `furniture` `4A_bl0_s3`: (-13.835, -7.040000000000001)
- `furniture` `4A_bl0_s4`: (-13.835, -7.040000000000001)
- `furniture` `4A_bl0_s5`: (-13.835, -7.040000000000001)
- `furniture` `4A_bl0_s6`: (-13.835, -7.040000000000001)
- `furniture` `4A_bl0_s7`: (-13.835, -7.040000000000001)
- `furniture` `4A_bl0_s8`: (-13.835, -7.040000000000001)
- `furniture` `4A_bl0_s9`: (-13.835, -7.040000000000001)
- `furniture` `4A_bl0_s10`: (-13.835, -7.040000000000001)
- `furniture` `4A_bl0_s11`: (-13.835, -7.040000000000001)
- `furniture` `4A_bl0_s12`: (-13.835, -7.040000000000001)
- `furniture` `4A_bl0_s13`: (-13.835, -7.040000000000001)
- `furniture` `4A_bl0_s14`: (-13.835, -7.040000000000001)
- `furniture` `4A_bl0_s15`: (-13.835, -7.040000000000001)
- `furniture` `4A_bl0_s16`: (-13.835, -7.040000000000001)
- `furniture` `4A_bl0_s17`: (-13.835, -7.040000000000001)
- `furniture` `4A_bl0_s18`: (-13.835, -7.040000000000001)
- `furniture` `4A_bl0_rail`: (-13.84, -7.040000000000001)
- `furniture` `4A_bl1_head`: (-13.835, -3.21)
- `furniture` `4A_bl1_s0`: (-13.835, -3.21)
- `furniture` `4A_bl1_s1`: (-13.835, -3.21)
- `furniture` `4A_bl1_s2`: (-13.835, -3.21)
- `furniture` `4A_bl1_s3`: (-13.835, -3.21)
- `furniture` `4A_bl1_s4`: (-13.835, -3.21)
- `furniture` `4A_bl1_s5`: (-13.835, -3.21)
- `furniture` `4A_bl1_s6`: (-13.835, -3.21)
- `furniture` `4A_bl1_s7`: (-13.835, -3.21)
- `furniture` `4A_bl1_s8`: (-13.835, -3.21)
- `furniture` `4A_bl1_s9`: (-13.835, -3.21)
- `furniture` `4A_bl1_s10`: (-13.835, -3.21)
- `furniture` `4A_bl1_s11`: (-13.835, -3.21)
- `furniture` `4A_bl1_s12`: (-13.835, -3.21)
- `furniture` `4A_bl1_s13`: (-13.835, -3.21)
- `furniture` `4A_bl1_s14`: (-13.835, -3.21)
- `furniture` `4A_bl1_s15`: (-13.835, -3.21)
- `furniture` `4A_bl1_s16`: (-13.835, -3.21)
- `furniture` `4A_bl1_s17`: (-13.835, -3.21)
- `furniture` `4A_bl1_rail`: (-13.84, -3.21)
- `furniture` `4A_bl2_head`: (-9.58, -9.835)
- `furniture` `4A_bl2_s0`: (-9.579999999999998, -9.834999999999999)
- `furniture` `4A_bl2_s1`: (-9.579999999999998, -9.834999999999999)
- `furniture` `4A_bl2_s2`: (-9.579999999999998, -9.834999999999999)
- `furniture` `4A_bl2_s3`: (-9.579999999999998, -9.834999999999999)
- `furniture` `4A_bl2_s4`: (-9.579999999999998, -9.834999999999999)
- `furniture` `4A_bl2_s5`: (-9.579999999999998, -9.834999999999999)
- `furniture` `4A_bl2_s6`: (-9.579999999999998, -9.834999999999999)
- `furniture` `4A_bl2_s7`: (-9.579999999999998, -9.834999999999999)
- `furniture` `4A_bl2_s8`: (-9.579999999999998, -9.834999999999999)
- `furniture` `4A_bl2_s9`: (-9.579999999999998, -9.834999999999999)
- `furniture` `4A_bl2_s10`: (-9.579999999999998, -9.834999999999999)
- `furniture` `4A_bl2_s11`: (-9.579999999999998, -9.834999999999999)
- `furniture` `4A_bl2_rail`: (-9.579999999999998, -9.84)
- `furniture` `4B_bl0_head`: (-13.835, 4.763999999999999)
- `furniture` `4B_bl0_s0`: (-13.835, 4.763999999999999)
- `furniture` `4B_bl0_s1`: (-13.835, 4.763999999999999)
- `furniture` `4B_bl0_s2`: (-13.835, 4.763999999999999)
- `furniture` `4B_bl0_s3`: (-13.835, 4.763999999999999)
- `furniture` `4B_bl0_s4`: (-13.835, 4.763999999999999)

## F05

- Rooms: 20; doors: 16; unassigned records: 304
- Art faces: 36; frame-like records: 24
- Conservative door-sweep candidates: 36
- Wall endpoint near-misses (12–300 mm): 23

| Room | Kind | Unit | Records | Assemblies | Rect parts | Purpose status |
|---|---|---:|---:|---:|---:|---|
| F05_A_BED | bedroom | 5A | 14 | 4 | 5 | kind only |
| F05_A_BATH | bathroom | 5A | 11 | 1 | 2 | kind only |
| F05_A_MAIN | living | 5A | 46 | 20 | 10 | kind only |
| F05_B_ALCOVE | alcove | 5B | 8 | 4 | 0 | kind only |
| F05_B_BATH | bathroom | 5B | 13 | 2 | 2 | kind only |
| F05_B_KITCHEN | kitchen | 5B | 17 | 5 | 4 | kind only |
| F05_B_MAIN | living | 5B | 17 | 9 | 5 | kind only |
| F05_C_BED1 | bedroom | 5C | 14 | 4 | 5 | kind only |
| F05_C_BED2 | bedroom | 5C | 15 | 4 | 5 | kind only |
| F05_C_BATH | bathroom | 5C | 9 | 2 | 0 | kind only |
| F05_C_MAIN | living | 5C | 35 | 12 | 9 | kind only |
| F05_D_BED | bedroom | 5D | 6 | 1 | 4 | kind only |
| F05_D_BATH | bathroom | 5D | 9 | 1 | 2 | kind only |
| F05_D_MAIN | living | 5D | 12 | 5 | 4 | kind only |
| F05_D_OFFICE | office | 5D | 2 | 1 | 0 | kind only |
| F05_WSTOR | storage | — | 17 | 12 | 4 | kind only |
| F05_CORRIDOR | corridor | — | 24 | 6 | 3 | kind only |
| F05_HALL | hall | — | 5 | 1 | 3 | kind only |
| F05_ATRIUM | atrium | — | 26 | 19 | 6 | kind only |
| F05_UTILITY | utility | — | 8 | 1 | 5 | kind only |

### Wall endpoint candidates

- walls 2/4: 0.255 m between (-3.43, -6.93) and (-3.25, -6.75)
- walls 2/6: 0.255 m between (-3.43, 6.93) and (-3.25, 6.75)
- walls 3/5: 0.255 m between (3.43, -6.93) and (3.25, -6.75)
- walls 3/7: 0.255 m between (3.43, 6.93) and (3.25, 6.75)
- walls 5/15: 0.250 m between (3.25, -6.75) and (3.0, -6.75)
- walls 8/15: 0.250 m between (3.25, -6.75) and (3.0, -6.75)
- walls 12/18: 0.269 m between (-5.33, -9.65) and (-5.51, -9.85)
- walls 12/20: 0.269 m between (-5.33, 9.65) and (-5.51, 9.85)
- walls 13/22: 0.269 m between (5.33, 9.65) and (5.51, 9.85)
- walls 13/24: 0.269 m between (5.33, -9.65) and (5.51, -9.85)
- walls 17/18: 0.283 m between (-13.85, -9.65) and (-13.65, -9.85)
- walls 17/27: 0.209 m between (-13.85, -0.45) and (-13.65, -0.39)
- walls 19/20: 0.283 m between (-13.85, 9.65) and (-13.65, 9.85)
- walls 19/28: 0.209 m between (-13.85, 2.67) and (-13.65, 2.61)
- walls 21/22: 0.283 m between (13.85, 9.65) and (13.65, 9.85)
- walls 21/23: 0.120 m between (13.85, -0.88) and (13.85, -1.0)
- walls 23/24: 0.283 m between (13.85, -9.65) and (13.65, -9.85)
- walls 23/29: 0.209 m between (13.85, -1.0) and (13.65, -0.94)
- walls 31/32: 0.100 m between (-7.81, -3.79) and (-7.71, -3.79)
- walls 39/47: 0.277 m between (9.58, 9.65) and (9.55, 9.375)
- walls 40/41: 0.100 m between (7.81, 3.79) and (7.71, 3.79)
- walls 43/44: 0.100 m between (7.81, -3.79) and (7.71, -3.79)
- walls 45/46: 0.100 m between (7.81, -2.84) and (7.71, -2.84)

### Door-sweep candidates

- `F05_DOOR_01` ↔ `age_linoF05`
- `F05_DOOR_02` ↔ `5A_k_lino`
- `F05_DOOR_02` ↔ `5A_k_linobar_e`
- `F05_DOOR_02` ↔ `sign_F05_apt_5A_back`
- `F05_DOOR_02` ↔ `sign_F05_apt_5A_face`
- `F05_DOOR_02` ↔ `age_lane_wF05`
- `F05_DOOR_03` ↔ `sign_F05_apt_5B_back`
- `F05_DOOR_03` ↔ `sign_F05_apt_5B_face`
- `F05_DOOR_03` ↔ `age_lane_wF05`
- `F05_DOOR_04` ↔ `F05_wstor_roll`
- `F05_DOOR_04` ↔ `age_lane_wF05`
- `F05_DOOR_05` ↔ `sign_F05_apt_5D_back`
- `F05_DOOR_05` ↔ `sign_F05_apt_5D_face`
- `F05_DOOR_06` ↔ `5C_k_lino`
- `F05_DOOR_06` ↔ `5C_k_linobar_s`
- `F05_DOOR_06` ↔ `sign_F05_apt_5C_back`
- `F05_DOOR_06` ↔ `sign_F05_apt_5C_face`
- `F05_DOOR_07` ↔ `5B_k_lino`
- `F05_DOOR_07` ↔ `5B_k_linobar_w`
- `F05_DOOR_07` ↔ `5B_k_linobar_n`
- `F05_DOOR_07` ↔ `F05_porch_deck`
- `F05_DOOR_07` ↔ `F05_porch_rail_e_top`
- `F05_DOOR_07` ↔ `F05_porch_rail_e_mid`
- `F05_DOOR_07` ↔ `F05_porch_step0`
- `F05_DOOR_09` ↔ `5A_trail`
- `F05_DOOR_09` ↔ `5A_towel`
- `F05_DOOR_12` ↔ `5C_bart1_art`
- `F05_DOOR_12` ↔ `5C_bart1_artf`
- `F05_DOOR_12` ↔ `5C_bart1_artf2`
- `F05_DOOR_12` ↔ `5C_bart1_artfl`
- `F05_DOOR_14` ↔ `5D_char1`
- `F05_DOOR_14` ↔ `age_char_ceiling`
- `F05_DOOR_15` ↔ `5D_trail`
- `F05_DOOR_15` ↔ `5D_towel`
- `F05_DOOR_15` ↔ `5D_char1`
- `F05_DOOR_15` ↔ `age_char_ceiling`

### Outside every declared room / unresolved

- `furniture` `5A_pins1`: (-13.695, -5.2)
- `furniture` `5A_pins2`: (-13.695, -1.7)
- `furniture` `5A_sheet0`: (-13.692, -4.4)
- `furniture` `5A_sheet1`: (-13.687999999999999, -4.325000000000001)
- `furniture` `5A_sheet2`: (-13.684000000000001, -4.25)
- `furniture` `5A_sheet3`: (-13.68, -4.175000000000001)
- `furniture` `5C_trail`: (5.494999999999999, 5.699999999999999)
- `furniture` `5C_towel`: (5.49, 5.68)
- `furniture` `5C_story_colorboard`: (13.695, 4.385)
- `furniture` `F05_porch_deck`: (-9.15, 10.7)
- `furniture` `F05_porch_rail_n_top`: (-9.15, 11.309999999999999)
- `furniture` `F05_porch_rail_n_mid`: (-9.15, 11.309999999999999)
- `furniture` `F05_porch_rail_w_top`: (-10.559999999999999, 10.7)
- `furniture` `F05_porch_rail_w_mid`: (-10.559999999999999, 10.7)
- `furniture` `F05_porch_rail_e_top`: (-7.74, 10.7)
- `furniture` `F05_porch_rail_e_mid`: (-7.74, 10.7)
- `furniture` `F05_porch_step0`: (-7.49, 10.65)
- `furniture` `F05_porch_step1`: (-7.2, 10.65)
- `furniture` `F05_porch_step2`: (-6.91, 10.65)
- `furniture` `F05_porch_step3`: (-6.62, 10.65)
- `furniture` `F05_porch_step4`: (-6.33, 10.65)
- `furniture` `F05_porch_step5`: (-6.04, 10.65)
- `furniture` `F05_porch_step6`: (-5.750000000000001, 10.65)
- `furniture` `F05_porch_step7`: (-5.46, 10.65)
- `furniture` `5A_bl0_head`: (-13.835, -7.040000000000001)
- `furniture` `5A_bl0_s0`: (-13.835, -7.040000000000001)
- `furniture` `5A_bl0_s1`: (-13.835, -7.040000000000001)
- `furniture` `5A_bl0_s2`: (-13.835, -7.040000000000001)
- `furniture` `5A_bl0_s3`: (-13.835, -7.040000000000001)
- `furniture` `5A_bl0_s4`: (-13.835, -7.040000000000001)
- `furniture` `5A_bl0_s5`: (-13.835, -7.040000000000001)
- `furniture` `5A_bl0_s6`: (-13.835, -7.040000000000001)
- `furniture` `5A_bl0_s7`: (-13.835, -7.040000000000001)
- `furniture` `5A_bl0_s8`: (-13.835, -7.040000000000001)
- `furniture` `5A_bl0_s9`: (-13.835, -7.040000000000001)
- `furniture` `5A_bl0_s10`: (-13.835, -7.040000000000001)
- `furniture` `5A_bl0_s11`: (-13.835, -7.040000000000001)
- `furniture` `5A_bl0_s12`: (-13.835, -7.040000000000001)
- `furniture` `5A_bl0_s13`: (-13.835, -7.040000000000001)
- `furniture` `5A_bl0_s14`: (-13.835, -7.040000000000001)
- `furniture` `5A_bl0_s15`: (-13.835, -7.040000000000001)
- `furniture` `5A_bl0_s16`: (-13.835, -7.040000000000001)
- `furniture` `5A_bl0_s17`: (-13.835, -7.040000000000001)
- `furniture` `5A_bl0_rail`: (-13.84, -7.040000000000001)
- `furniture` `5A_bl1_head`: (-13.835, -3.21)
- `furniture` `5A_bl1_s0`: (-13.834999999999999, -3.21)
- `furniture` `5A_bl1_s1`: (-13.834999999999999, -3.21)
- `furniture` `5A_bl1_s2`: (-13.834999999999999, -3.21)
- `furniture` `5A_bl1_s3`: (-13.834999999999999, -3.21)
- `furniture` `5A_bl1_s4`: (-13.834999999999999, -3.21)
- `furniture` `5A_bl1_s5`: (-13.834999999999999, -3.21)
- `furniture` `5A_bl1_s6`: (-13.834999999999999, -3.21)
- `furniture` `5A_bl1_s7`: (-13.834999999999999, -3.21)
- `furniture` `5A_bl1_s8`: (-13.834999999999999, -3.21)
- `furniture` `5A_bl1_s9`: (-13.834999999999999, -3.21)
- `furniture` `5A_bl1_s10`: (-13.834999999999999, -3.21)
- `furniture` `5A_bl1_s11`: (-13.834999999999999, -3.21)
- `furniture` `5A_bl1_rail`: (-13.84, -3.21)
- `furniture` `5A_bl2_head`: (-9.58, -9.835)
- `furniture` `5A_bl2_s0`: (-9.579999999999998, -9.835)
- `furniture` `5A_bl2_s1`: (-9.579999999999998, -9.835)
- `furniture` `5A_bl2_s2`: (-9.579999999999998, -9.835)
- `furniture` `5A_bl2_s3`: (-9.579999999999998, -9.835)
- `furniture` `5A_bl2_s4`: (-9.579999999999998, -9.835)
- `furniture` `5A_bl2_s5`: (-9.579999999999998, -9.835)
- `furniture` `5A_bl2_s6`: (-9.579999999999998, -9.835)
- `furniture` `5A_bl2_s7`: (-9.579999999999998, -9.835)
- `furniture` `5A_bl2_s8`: (-9.579999999999998, -9.835)
- `furniture` `5A_bl2_s9`: (-9.579999999999998, -9.835)
- `furniture` `5A_bl2_s10`: (-9.579999999999998, -9.835)
- `furniture` `5A_bl2_rail`: (-9.579999999999998, -9.84)
- `furniture` `5B_bl0_head`: (-13.835, 4.763999999999999)
- `furniture` `5B_bl0_s0`: (-13.834999999999999, 4.763999999999999)
- `furniture` `5B_bl0_s1`: (-13.834999999999999, 4.763999999999999)
- `furniture` `5B_bl0_s2`: (-13.834999999999999, 4.763999999999999)
- `furniture` `5B_bl0_s3`: (-13.834999999999999, 4.763999999999999)
- `furniture` `5B_bl0_s4`: (-13.834999999999999, 4.763999999999999)
- `furniture` `5B_bl0_s5`: (-13.834999999999999, 4.763999999999999)
- `furniture` `5B_bl0_s6`: (-13.834999999999999, 4.763999999999999)
- `furniture` `5B_bl0_s7`: (-13.834999999999999, 4.763999999999999)

## F06

- Rooms: 20; doors: 16; unassigned records: 334
- Art faces: 36; frame-like records: 24
- Conservative door-sweep candidates: 33
- Wall endpoint near-misses (12–300 mm): 23

| Room | Kind | Unit | Records | Assemblies | Rect parts | Purpose status |
|---|---|---:|---:|---:|---:|---|
| F06_A_BED | bedroom | 6A | 16 | 4 | 6 | kind only |
| F06_A_BATH | bathroom | 6A | 11 | 1 | 2 | kind only |
| F06_A_MAIN | living | 6A | 53 | 21 | 16 | kind only |
| F06_B_ALCOVE | alcove | 6B | 8 | 4 | 0 | kind only |
| F06_B_BATH | bathroom | 6B | 13 | 2 | 2 | kind only |
| F06_B_KITCHEN | kitchen | 6B | 16 | 3 | 4 | kind only |
| F06_B_MAIN | living | 6B | 17 | 8 | 5 | kind only |
| F06_C_BED1 | bedroom | 6C | 14 | 4 | 5 | kind only |
| F06_C_BED2 | bedroom | 6C | 15 | 4 | 5 | kind only |
| F06_C_BATH | bathroom | 6C | 9 | 2 | 0 | kind only |
| F06_C_MAIN | living | 6C | 40 | 15 | 9 | kind only |
| F06_D_BED | bedroom | 6D | 11 | 1 | 8 | kind only |
| F06_D_BATH | bathroom | 6D | 10 | 1 | 3 | kind only |
| F06_D_MAIN | living | 6D | 10 | 6 | 0 | kind only |
| F06_D_OFFICE | office | 6D | 4 | 2 | 0 | kind only |
| F06_WSTOR | storage | — | 16 | 11 | 4 | kind only |
| F06_CORRIDOR | corridor | — | 24 | 6 | 3 | kind only |
| F06_HALL | hall | — | 5 | 1 | 3 | kind only |
| F06_ATRIUM | atrium | — | 23 | 16 | 6 | kind only |
| F06_UTILITY | utility | — | 8 | 1 | 5 | kind only |

### Wall endpoint candidates

- walls 2/4: 0.255 m between (-3.43, -6.93) and (-3.25, -6.75)
- walls 2/6: 0.255 m between (-3.43, 6.93) and (-3.25, 6.75)
- walls 3/5: 0.255 m between (3.43, -6.93) and (3.25, -6.75)
- walls 3/7: 0.255 m between (3.43, 6.93) and (3.25, 6.75)
- walls 5/15: 0.250 m between (3.25, -6.75) and (3.0, -6.75)
- walls 8/15: 0.250 m between (3.25, -6.75) and (3.0, -6.75)
- walls 12/18: 0.269 m between (-5.33, -9.65) and (-5.51, -9.85)
- walls 12/20: 0.269 m between (-5.33, 9.65) and (-5.51, 9.85)
- walls 13/22: 0.269 m between (5.33, 9.65) and (5.51, 9.85)
- walls 13/24: 0.269 m between (5.33, -9.65) and (5.51, -9.85)
- walls 17/18: 0.283 m between (-13.85, -9.65) and (-13.65, -9.85)
- walls 17/27: 0.209 m between (-13.85, -0.45) and (-13.65, -0.39)
- walls 19/20: 0.283 m between (-13.85, 9.65) and (-13.65, 9.85)
- walls 19/28: 0.209 m between (-13.85, 2.67) and (-13.65, 2.61)
- walls 21/22: 0.283 m between (13.85, 9.65) and (13.65, 9.85)
- walls 21/23: 0.120 m between (13.85, -0.88) and (13.85, -1.0)
- walls 23/24: 0.283 m between (13.85, -9.65) and (13.65, -9.85)
- walls 23/29: 0.209 m between (13.85, -1.0) and (13.65, -0.94)
- walls 31/32: 0.100 m between (-7.81, -3.79) and (-7.71, -3.79)
- walls 39/47: 0.277 m between (9.58, 9.65) and (9.55, 9.375)
- walls 40/41: 0.100 m between (7.81, 3.79) and (7.71, 3.79)
- walls 43/44: 0.100 m between (7.81, -3.79) and (7.71, -3.79)
- walls 45/46: 0.100 m between (7.81, -2.84) and (7.71, -2.84)

### Door-sweep candidates

- `F06_DOOR_01` ↔ `age_linoF06`
- `F06_DOOR_02` ↔ `6A_k_lino`
- `F06_DOOR_02` ↔ `6A_k_linobar_e`
- `F06_DOOR_02` ↔ `sign_F06_apt_6A_back`
- `F06_DOOR_02` ↔ `sign_F06_apt_6A_face`
- `F06_DOOR_02` ↔ `age_lane_wF06`
- `F06_DOOR_03` ↔ `sign_F06_apt_6B_back`
- `F06_DOOR_03` ↔ `sign_F06_apt_6B_face`
- `F06_DOOR_03` ↔ `age_lane_wF06`
- `F06_DOOR_04` ↔ `F06_wstor_roll`
- `F06_DOOR_04` ↔ `age_lane_wF06`
- `F06_DOOR_05` ↔ `sign_F06_apt_6D_back`
- `F06_DOOR_05` ↔ `sign_F06_apt_6D_face`
- `F06_DOOR_06` ↔ `6C_k_lino`
- `F06_DOOR_06` ↔ `6C_k_linobar_s`
- `F06_DOOR_06` ↔ `sign_F06_apt_6C_back`
- `F06_DOOR_06` ↔ `sign_F06_apt_6C_face`
- `F06_DOOR_07` ↔ `6B_k_lino`
- `F06_DOOR_07` ↔ `6B_k_linobar_w`
- `F06_DOOR_07` ↔ `6B_k_linobar_n`
- `F06_DOOR_07` ↔ `F06_porch_deck`
- `F06_DOOR_07` ↔ `F06_porch_rail_e_top`
- `F06_DOOR_07` ↔ `F06_porch_rail_e_mid`
- `F06_DOOR_07` ↔ `F06_porch_step0`
- `F06_DOOR_09` ↔ `6A_trail`
- `F06_DOOR_09` ↔ `6A_towel`
- `F06_DOOR_12` ↔ `6C_bart1_art`
- `F06_DOOR_12` ↔ `6C_bart1_artf`
- `F06_DOOR_12` ↔ `6C_bart1_artf2`
- `F06_DOOR_12` ↔ `6C_bart1_artfl`
- `F06_DOOR_15` ↔ `6D_trail`
- `F06_DOOR_15` ↔ `6D_towel`
- `F06_DOOR_15` ↔ `6D_rolledrug`

### Outside every declared room / unresolved

- `furniture` `6A_foam0`: (-13.6695, -5.949999999999999)
- `furniture` `6A_foam1`: (-13.657, -5.35)
- `furniture` `6A_foam2`: (-13.6695, -4.749999999999999)
- `furniture` `6A_foam3`: (-13.657, -4.1499999999999995)
- `furniture` `6A_foam4`: (-13.657, -5.949999999999999)
- `furniture` `6A_foam5`: (-13.6695, -5.35)
- `furniture` `6A_foam6`: (-13.657, -4.749999999999999)
- `furniture` `6A_foam7`: (-13.6695, -4.1499999999999995)
- `furniture` `6A_foam8`: (-13.6695, -5.949999999999999)
- `furniture` `6A_foam9`: (-13.657, -5.35)
- `furniture` `6A_foam10`: (-13.6695, -4.749999999999999)
- `furniture` `6A_foam11`: (-13.657, -4.1499999999999995)
- `furniture` `6C_trail`: (5.494999999999999, 5.699999999999999)
- `furniture` `6C_towel`: (5.49, 5.68)
- `furniture` `F06_porch_deck`: (-9.15, 10.7)
- `furniture` `F06_porch_rail_n_top`: (-9.15, 11.309999999999999)
- `furniture` `F06_porch_rail_n_mid`: (-9.15, 11.309999999999999)
- `furniture` `F06_porch_rail_w_top`: (-10.559999999999999, 10.7)
- `furniture` `F06_porch_rail_w_mid`: (-10.559999999999999, 10.7)
- `furniture` `F06_porch_rail_e_top`: (-7.74, 10.7)
- `furniture` `F06_porch_rail_e_mid`: (-7.74, 10.7)
- `furniture` `F06_porch_step0`: (-7.49, 10.65)
- `furniture` `F06_porch_step1`: (-7.2, 10.65)
- `furniture` `F06_porch_step2`: (-6.91, 10.65)
- `furniture` `F06_porch_step3`: (-6.62, 10.65)
- `furniture` `F06_porch_step4`: (-6.33, 10.65)
- `furniture` `F06_porch_step5`: (-6.04, 10.65)
- `furniture` `F06_porch_step6`: (-5.750000000000001, 10.65)
- `furniture` `F06_porch_step7`: (-5.46, 10.65)
- `furniture` `6A_bl0_head`: (-13.835, -7.040000000000001)
- `furniture` `6A_bl0_s0`: (-13.834999999999999, -7.040000000000001)
- `furniture` `6A_bl0_s1`: (-13.834999999999999, -7.040000000000001)
- `furniture` `6A_bl0_s2`: (-13.834999999999999, -7.040000000000001)
- `furniture` `6A_bl0_s3`: (-13.834999999999999, -7.040000000000001)
- `furniture` `6A_bl0_s4`: (-13.834999999999999, -7.040000000000001)
- `furniture` `6A_bl0_s5`: (-13.834999999999999, -7.040000000000001)
- `furniture` `6A_bl0_s6`: (-13.834999999999999, -7.040000000000001)
- `furniture` `6A_bl0_s7`: (-13.834999999999999, -7.040000000000001)
- `furniture` `6A_bl0_s8`: (-13.834999999999999, -7.040000000000001)
- `furniture` `6A_bl0_s9`: (-13.834999999999999, -7.040000000000001)
- `furniture` `6A_bl0_s10`: (-13.834999999999999, -7.040000000000001)
- `furniture` `6A_bl0_s11`: (-13.834999999999999, -7.040000000000001)
- `furniture` `6A_bl0_rail`: (-13.84, -7.040000000000001)
- `furniture` `6A_bl1_head`: (-13.835, -3.21)
- `furniture` `6A_bl1_s0`: (-13.835, -3.21)
- `furniture` `6A_bl1_s1`: (-13.835, -3.21)
- `furniture` `6A_bl1_s2`: (-13.835, -3.21)
- `furniture` `6A_bl1_s3`: (-13.835, -3.21)
- `furniture` `6A_bl1_s4`: (-13.835, -3.21)
- `furniture` `6A_bl1_s5`: (-13.835, -3.21)
- `furniture` `6A_bl1_s6`: (-13.835, -3.21)
- `furniture` `6A_bl1_s7`: (-13.835, -3.21)
- `furniture` `6A_bl1_s8`: (-13.835, -3.21)
- `furniture` `6A_bl1_s9`: (-13.835, -3.21)
- `furniture` `6A_bl1_s10`: (-13.835, -3.21)
- `furniture` `6A_bl1_rail`: (-13.84, -3.21)
- `furniture` `6A_bl2_head`: (-9.58, -9.835)
- `furniture` `6A_bl2_s0`: (-9.579999999999998, -9.835)
- `furniture` `6A_bl2_s1`: (-9.579999999999998, -9.835)
- `furniture` `6A_bl2_s2`: (-9.579999999999998, -9.835)
- `furniture` `6A_bl2_s3`: (-9.579999999999998, -9.835)
- `furniture` `6A_bl2_s4`: (-9.579999999999998, -9.835)
- `furniture` `6A_bl2_s5`: (-9.579999999999998, -9.835)
- `furniture` `6A_bl2_s6`: (-9.579999999999998, -9.835)
- `furniture` `6A_bl2_s7`: (-9.579999999999998, -9.835)
- `furniture` `6A_bl2_s8`: (-9.579999999999998, -9.835)
- `furniture` `6A_bl2_s9`: (-9.579999999999998, -9.835)
- `furniture` `6A_bl2_s10`: (-9.579999999999998, -9.835)
- `furniture` `6A_bl2_s11`: (-9.579999999999998, -9.835)
- `furniture` `6A_bl2_s12`: (-9.579999999999998, -9.835)
- `furniture` `6A_bl2_s13`: (-9.579999999999998, -9.835)
- `furniture` `6A_bl2_s14`: (-9.579999999999998, -9.835)
- `furniture` `6A_bl2_s15`: (-9.579999999999998, -9.835)
- `furniture` `6A_bl2_s16`: (-9.579999999999998, -9.835)
- `furniture` `6A_bl2_s17`: (-9.579999999999998, -9.835)
- `furniture` `6A_bl2_s18`: (-9.579999999999998, -9.835)
- `furniture` `6A_bl2_s19`: (-9.579999999999998, -9.835)
- `furniture` `6A_bl2_s20`: (-9.579999999999998, -9.835)
- `furniture` `6A_bl2_s21`: (-9.579999999999998, -9.835)
- `furniture` `6A_bl2_s22`: (-9.579999999999998, -9.835)

## ROOF

- Rooms: 1; doors: 2; unassigned records: 8
- Art faces: 0; frame-like records: 0
- Conservative door-sweep candidates: 6
- Wall endpoint near-misses (12–300 mm): 0

| Room | Kind | Unit | Records | Assemblies | Rect parts | Purpose status |
|---|---|---:|---:|---:|---:|---|
| ROOF_OPEN | roof | — | 191 | 43 | 139 | kind only |

### Door-sweep candidates

- `ROOF_DOOR_01` ↔ `sky_glass`
- `ROOF_DOOR_01` ↔ `sky_rib_x2`
- `ROOF_DOOR_01` ↔ `sky_rib_x3`
- `ROOF_DOOR_01` ↔ `sky_rib_y0`
- `ROOF_DOOR_01` ↔ `sky_rib_y1`
- `ROOF_DOOR_01` ↔ `sky_kerb_s`

### Outside every declared room / unresolved

- `furniture` `coping_s`: (0.0, -10.0)
- `furniture` `coping_n`: (0.0, 10.0)
- `furniture` `coping_w`: (-14.0, 0.0)
- `furniture` `coping_e`: (14.0, 0.0)
- `furniture` `cornice_0`: (0.0, -10.0)
- `furniture` `cornice_1`: (0.0, -10.014999999999999)
- `furniture` `cornice_2`: (0.0, -10.03)
- `furniture` `age_coping_repair`: (3.3, -10.0)
