# REPORT - DEBUG-MENU-INPUT - 2026-09-19

Evidence class: **INERT**. A bounded input repair and native test report; no runtime-contract or spatial-ledger promotion.

Branch / base HEAD / origin/main / merge-base: **codex/astra-reconcile-20260919** / **d8916966cbce41d9fd8517215f155a37bea3ebf2** / **e8b83a3f7a9546fe02a0dea9312b9efd85975beb** / **acdb4be42e5d973df623c3545aacde95855a1d07**. The containing commit records this repair. Tracked edits are committed together; historical untracked generated UIDs remain untouched.

## User-visible behavior

The previous debug panel expanded without releasing the captured mouse. Its obsolete Escape hint led into PauseServices. A second defect made an empty AudioCaptionLayer container intercept the lower screen, including GO, despite having no visible captions.

F1 now opens the controls with a visible pointer and holds player input while the world runs. GO → Dream ecology reaches the live warehouse. F1 or Escape exits inspection to the expanded debug controls; another closes debug and restores the prior player/camera input state. Escape during ordinary play still opens PauseServices. The visible header names the F1 pointer control.

The menu preserves nested ecology suspension, pre-disabled player callbacks, touch input and a pre-existing free pointer. It releases its focus and input ownership on close, teardown and the existing case/Dreamworld handoffs. The caption container and its text ignore pointer input; captions remain displayed normally.

## Native and source verification

All runs used the shared lane with logs. Exact wrapper receipts, stdout, stderr, two reviewed 1280×720 captures and LF-normalized source hashes are in **art/renders/debug_menu_input_20260919/**.

- **DreamEcologyEntryTest**: 28/28, windowed, exit 0. Uses viewport F1/Escape events and actual GUI mouse clicks for GO, opening ecology and reopening it; verifies live sixteen-species camera, zoom, nested exit, touch look and process-state restoration. The earlier emitted-button shortcut is removed.
- **AudioCaptionTest**: 6/6, exit 0. Actual clicks reach an underlying button through both empty caption rows and a populated caption label; four existing semantic checks remain. The fixture now declares its 1280×720 viewport and releases its semantic audio source.
- **PauseServicesTest**: 18/18, exit 0.
- **DebugDreamButtonTest**: 13/13, headless, exit 0. Now enters through F1 before arming the real onset and proves debug releases its player suspension; both production world swaps and campaign preservation pass.

The first two warehouse attempts retain the caption hit-test failure. The first caption attempt lacked a defined headless viewport; the corrected fixture passes. The first windowed Dreamworld regression reached its unchanged 50-second watchdog while rebuilding the world; the headless rerun passes without changing that limit. Failed attempts remain beside the successful runs.

Reader gate: **NEW 0**. Design-doc lint and diff whitespace checks pass. Protected paths: **17/17** committed blobs equal origin/main, with no working changes; selector remains **v1**. Completeness, spatial, systemic, period and full tools/candidate verification were not rerun for this UI-only repair. Ledger before → after: not remeasured; no ledger claim or changed requirement status is asserted.

Changes outside the expected debug file: AudioCaptionLayer required the two-line pointer fix because native hover diagnostics identified its invisible bottom strip as the blocker. The three focused tests, report, capture bundle and exact-byte attributes preserve the regression and its evidence.

## Open findings and continuation

Whole-building runs retain resident route refusals and found-art placement warnings. AudioCaptionTest still reports four ObjectDB instances and two resources at teardown; its six input/semantic assertions pass, but this is not a clean teardown claim. These diagnostics are preserved and not waived.

The Blender catalogue remains the accepted sixteen-species warehouse build from the preceding checkpoint. This repair changes no critter geometry, behavior, voxel ownership or floor provider. The V2 continuation still starts with the recorded **F06_DOOR_02** moving-leaf collision, then reviewed fixture evidence and fresh committed candidate verification. No merge or push was performed. Decision needed from owner: none for this fix.

**BLOCKED — broader V2 candidate still awaits door passage readiness and final fresh verification; the debug pointer/warehouse entry repair is complete.**
