# Paused composed Vulkan diagnostic review

Both executed V1 cases remain failed mixed-cause evidence. They are not valid intended-only renderer reds or current-source greens.

- Raw: engine 3221225477 (access violation), 75.514 s, diagnostic gate 1; two unpair errors, 2,222 independent soft-shadow underflows, one resident-route error. No final probe or retirement proof; 13 PNGs retained.
- Helper-only candidate: engine 1, 118.331 s, diagnostic gate 1; zero unpair/underflow/retention diagnostics, one resident-route error, 297 checks with 39 failed arcade labels. Actual shell/world retirement passed; all 16 PNGs retained.

The candidate red proves a real viewport-boundary defect: still-live ArcadeMachine geometry retained its own World3D but entered Passage foreign geometry indices and acquired mask 0 instead of 1. At the first failure the cabinet remained booted and its away timer was below the unload delay. This is independent of legitimate later app retirement. Later missing-ID observations in that old fixture must not be read as requiring immortal arcade meshes.

Only `_late_owner_is_dynamic` now refuses a SubViewport ancestor. Exact before/after bytes and the three-line repair are in `../evidence/vulkan_composed/viewport_boundary_repair`. It has not run yet. The fixture now retains observed legitimate retirement history through later reboot and separately checks the current own-world population. The viewport-omission control removes only the new guard; raw/helper-omission controls derive from the current candidate and retain the corrected viewport boundary and any unrelated current fixes.

The F04 route error is separate and remains fatal. Schedule dispatch and campaign time are frozen, but production ResidentRoutines timers remain live. Its shaft-interior wait target is suspect; the cause of graph disconnection is not established by these logs. Focused diagnosis owns the engine lane before the renderer matrix resumes.

Harukiya is exactly 247 eligible/indexed geometry nodes at the authored 03:00 time in the candidate census. The separate StreetCore `>250` contract remains unresolved and unchanged. The 1.6-second delay plus eight frames is a disclosed settle heuristic, not a builder-completion signal.

The candidate records 36 transitions and 144 following frames, with live SurfacePass governor state. `../evidence/vulkan_composed/candidate_diagnostic_cost_summary.json` retains station distributions. Raw timing arrays were lost in its crash; no valid matched performance comparison exists. Diagnostic logging and adaptive material state also limit future comparisons.

All 29 PNGs below were directly viewed. Verdicts are for composition inspection only. The initial raw/candidate frames show the same broad architecture; darkness, foreground obstructions, live state and failed runs preclude stronger equivalence. No human acceptance, traversal or final visual quality is claimed.

| Run | Frame | Inspection verdict | Observation |
|---|---|---|---|
| raw_v1_01 | actual_f04_mirror.png | SALVAGEABLE | Actual cabinet mirror displays a reflection in its frame. Image is distorted/blurred and the carried device obscures the right; no helper-caused distortion is inferred. |
| raw_v1_01 | actual_f04_reflection.png | SALVAGEABLE | Borrowed reflection viewport contains door, toilet and partition geometry. This establishes visible content only; main-world borrowing is a separate runtime assertion. |
| raw_v1_01 | initial_f04.png | SALVAGEABLE | Continuous corridor walls, ceiling and lights are visible; carried device blocks the lower-right. A still does not prove actor ownership checks. |
| raw_v1_01 | initial_harukiya.png | REFINE | Very underexposed interior; bar, tables and floor are only partly discernible. Insufficient for detailed interior quality inspection. |
| raw_v1_01 | initial_orison.png | SALVAGEABLE | Door, mail bank and lobby remain visible. Repeating/warped surface appearance is conspicuous; no causal shader attribution is made. |
| raw_v1_01 | initial_orison_phone.png | SALVAGEABLE | Phone viewport shows the doorway/mail bank without the carried device; repeated surface appearance remains visible. |
| raw_v1_01 | initial_passage.png | SALVAGEABLE | Continuous hall, glazed roof, shop grilles and signs are legible. Carried device obscures lower-right architecture. |
| raw_v1_01 | initial_passage_phone.png | SALVAGEABLE | Phone viewport shows the shop corridor and signs without the carried device. Low resolution limits detail inspection. |
| raw_v1_01 | initial_street.png | REFINE | Facade and street remain visible, but the central utility structure/pole obscures much of the scene; dark image and carried device limit inspection. |
| raw_v1_01 | initial_street_phone.png | REFINE | Phone viewport renders the street without the carried device, but the central structure still obscures the architectural target. |
| raw_v1_01 | separate_world_blocked.png | SALVAGEABLE | Controlled own-world image is uniformly gray; orange geometry is absent as intended during the blocker control. |
| raw_v1_01 | separate_world_initial.png | SALVAGEABLE | Controlled own-world image contains the orange square against gray, matching the intended presence control. |
| raw_v1_01 | separate_world_restored.png | SALVAGEABLE | Orange square is visible again in the controlled own-world viewport. Full retirement is not established by this still. |
| candidate_v1_diag_01 | actual_f04_mirror.png | SALVAGEABLE | Actual cabinet mirror displays a reflection in its frame. Image is distorted/blurred and the carried device obscures the right; no helper-caused distortion is inferred. |
| candidate_v1_diag_01 | actual_f04_reflection.png | SALVAGEABLE | Borrowed reflection viewport contains door, toilet and partition geometry. This establishes visible content only; main-world borrowing is a separate runtime assertion. |
| candidate_v1_diag_01 | before_retirement_passage.png | SALVAGEABLE | Hall, shop grilles, signs and cart remain visible after repeated transitions. Device obscures lower-right; this precedes retirement. |
| candidate_v1_diag_01 | before_retirement_passage_phone.png | SALVAGEABLE | Phone viewport retains the hall/cart after repeated transitions. This is a shared-world content check, not physical handset operation. |
| candidate_v1_diag_01 | initial_f04.png | SALVAGEABLE | Continuous corridor walls, ceiling and lights are visible; carried device blocks the lower-right. A still does not prove actor ownership checks. |
| candidate_v1_diag_01 | initial_harukiya.png | REFINE | Very underexposed interior; bar, tables and floor are only partly discernible. Insufficient for detailed interior quality inspection. |
| candidate_v1_diag_01 | initial_orison.png | SALVAGEABLE | Door, mail bank and lobby remain visible. Repeating/warped surface appearance is conspicuous; no causal shader attribution is made. |
| candidate_v1_diag_01 | initial_orison_phone.png | SALVAGEABLE | Phone viewport shows the doorway/mail bank without the carried device; repeated surface appearance remains visible. |
| candidate_v1_diag_01 | initial_passage.png | SALVAGEABLE | Continuous hall, glazed roof, shop grilles and signs are legible. Carried device obscures lower-right architecture. |
| candidate_v1_diag_01 | initial_passage_phone.png | SALVAGEABLE | Phone viewport shows the shop corridor and signs without the carried device. Low resolution limits detail inspection. |
| candidate_v1_diag_01 | initial_street.png | REFINE | Facade and street remain visible, but the central utility structure/pole obscures much of the scene; dark image and carried device limit inspection. |
| candidate_v1_diag_01 | initial_street_phone.png | REFINE | Phone viewport renders the street without the carried device, but the central structure still obscures the architectural target. |
| candidate_v1_diag_01 | return_harukiya.png | REFINE | Returned bar/cafe composition is present but similarly underexposed. No arcade screen is legibly shown, so owner reactivation rests on runtime checks, not this image. |
| candidate_v1_diag_01 | separate_world_blocked.png | SALVAGEABLE | Controlled own-world image is uniformly gray; orange geometry is absent as intended during the blocker control. |
| candidate_v1_diag_01 | separate_world_initial.png | SALVAGEABLE | Controlled own-world image contains the orange square against gray, matching the intended presence control. |
| candidate_v1_diag_01 | separate_world_restored.png | SALVAGEABLE | Orange square is visible again in the controlled own-world viewport. Full retirement is not established by this still. |

The machine-readable image review retains every PNG hash and links the exact run receipts. No existing red receipt was rewritten or promoted. The Python parser/source-transform controls passed 25/25 with actual exit 0; that is a tool-control result, not a GDScript compilation or renderer result.
