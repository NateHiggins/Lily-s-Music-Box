# Visibility transition phase and material census

The diagnostic localizes most of the current Passage transition stall to the encroachment callback. It separately proves that material arrays grow by duplicate references while their unique material instance-ID sets remain identical across all 43 observations. No repair is included.

The actual V1 `root_retirement` run `visibility_phase_census_01` completed 296/296 renderer/owner checks and 15/15 captures, engine0/gate0 in 81.887 seconds, with native unpair0, soft-shadow underflow0 and retention0. This pass describes those existing checks; it does not clear the newly observed material-registration growth. Exact original BuildingRoot `cde44cd16b9ebdfedde0bcda34b404c2a675adffe106ba4ac0d576d26e8e1fd4` and fixture `5ec63c36c6181b33c02bd2255039e9bf4e8db0c4465a45ac641d1481f422d6d3` were restored in the outer driver finally block. The engine lane was then released to root.

Source-bound runtime result: `../evidence/vulkan_composed/runs/visibility_phase_census_01/result.json`. Independent two-file restoration: `../evidence/vulkan_composed/profile_transactions/visibility_phase_census_01/receipt.json`. Root-authored original diagnostic preparation remains unchanged; the added census and executable driver are separately retained under `work/visibility_transition_profile/revision_material_census`.

| Measured phase median | Street to Passage ms | Passage to Street ms |
| --- | ---: | ---: |
| Total apply |618.869|609.102|
| Encroachment callback |523.691|522.755|
| Surface pass including callbacks |549.169|547.937|
| Passage late-geometry index |22.967|22.319|
| Street geometry index |29.589|29.483|
| Helper pre-assignment region, accumulated |2.581|0.851|

Each direction has six measured transitions. Phase regions overlap: the surface total includes the callbacks, and the gate totals include their index/owner work. Do not sum the table as disjoint phases. Per-mask timers add overhead; the helper region includes type/world lookup and the same-scenario call, not a pure native benchmark. This diagnostic supports broad attribution only, not shipping frame cost or a guaranteed gain from a future fix. Exact medians are in `../evidence/vulkan_composed/visibility_phase_census_summary.json`.

| Floor | Initial slots | Final slots | Unique materials throughout | Added duplicate slots |
| --- | ---: | ---: | ---: | ---: |
|F02|686|2456|446|1770|
|F03|528|2343|282|1815|
|F04|539|2429|283|1890|
|F05|518|2423|260|1905|
|F06|493|2218|259|1725|

All unique instance-ID sets remain identical and all invalid-slot counts stay zero. This distinguishes duplicate registration from observed allocation of new unique resources. It is not a full process-wide resource census. Exact IDs accompany every transition in the raw probe; the summarized identity checks are in `../evidence/vulkan_composed/visibility_phase_census_material_identity.json`.

ApartmentEncroachment._bind_storey reuses its stored array, calls _bind_living (which already conditionally registers), then unconditionally appends the same material. The source mechanism agrees with this census. SurfacePass.apply_props also invokes its callback from the cumulative props_swapped count, even after a sweep with no new swaps. The probe has not separated every operation inside reach_props/_bind_storey, so deduplication alone is not proven to remove the whole callback cost. A repair must retain late-child, material-replacement and governor-change behavior while proving bounded owner registration and signal fanout.

All 15 diagnostic PNGs were directly inspected. Actual cabinet before/after, phone views and reflection contain rendered content; the broad Harukiya view remains too dark for apparatus inspection, and the device/street-panel occlusions remain. A live resident appears in the raw reflection. Hashes and scoped notes are in `../evidence/vulkan_composed/visibility_phase_census_visual_review.json`. No final art, play, period or human acceptance is inferred.

Still required after shared source decisions: the viewport-guard-only omission, applicable V2 control and final uninstrumented full V1 composition. The earlier source-bound paired renderer control remains valid for its recorded source; it is not final foundation binding after subsequent material/navigation changes.
