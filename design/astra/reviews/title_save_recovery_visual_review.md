# Title recovery composition review — 2026-09-05

All ten final PNGs from `design/astra/evidence/title_save_recovery/runtime/title_capture_final/frames` were opened directly with `view_image`. The current title composition is readable at 1280×720: the wordmark, ordinary player actions, protected-save explanation, and both replacement choices remain on-screen without duplicate notices covering them. This is agent visual inspection of the actual title UI, not human acceptance or a destination gameplay observation.

The matching final runtime receipt records exit 0, ten correctly declared load/action states, ten successful image writes, and unchanged runtime source during the 12.295-second windowed process. Exact image/source hashes and the actual action traces are retained in its `receipt.json`, `visual_review.json`, and `frames/capture_receipt.json`. The capture suppresses title audio and intercepts only the explicitly declared failure scene operation; it does not prove audio listening quality or real scene entry. Final storage entry validation and interruption/restart changes were already applied before this capture.

| Frame | Agent composition verdict | Observed result |
|---|---|---|
| 01 missing Begin | Readable / in viewport | Begin and Building Services are clear; no fixed opening time or debug entry. Full title and hero remain visible. |
| 02 loaded Continue | Readable / in viewport | Continue has initial focus; New Campaign is visually secondary; Services and footer fit. |
| 03 recovered Continue | Readable / in viewport | Recovery message sits immediately above Continue without covering the wordmark. All player actions remain visible. The narrow scrollbar is available for longer content. |
| 04 protected save | Readable / in viewport | Protected explanation and explicit New are visible; Services has safe initial focus. No misleading Begin or Continue. |
| 05 loaded replacement | Readable / in viewport | Centered choice panel explains replacement/archive limits; Keep This Save has a clear focus border; Replace and Begin remains visible below it. |
| 06 protected replacement | Readable / in viewport | Protected-file replacement copy fits. Modal shade separates the choice from the background; no global notice intrudes over the panel. |
| 07 failed New | Readable / in viewport | Failure notice is directly above the restored New launcher, with Services available. Wordmark and hero remain intact. |
| 08 failed scene retry | Readable / in viewport | Saved campaign offers Continue with a truthful scene-opening failure notice; no blank screen or fake New retry. |
| 09 first-creation artifact retry | Readable / in viewport | Failure notice says no campaign has opened; Begin remains a retry and Continue is absent while no verified primary exists. |
| 10 artifacts protected after reload | Readable / in viewport | Actual reload exposes protected artifact recovery copy and explicit New; Continue remains absent and Services is focused. |

The root agent independently inspected frames 02, 04 and 05 of the earlier `title_capture_notice_owner` run and reported their wordmark, normal actions, protected copy, and modal readable with no overlap. That corroboration is another agent observation of the earlier run, not owner/human acceptance of this final run. Its three UI source hashes match the final capture; all ten final images were nevertheless opened and inspected separately.

The earlier `title_capture_typed` run also wrote ten images and exited 0, but direct inspection found duplicate global/inline notices over the wordmark and lower actions outside the initially visible menu area. It also preceded the title cleanup of the fixed 3:00 A.M. label and ordinary Debug Building entry, made under the existing time-of-day and production-presentation mandate. Those images remain correction evidence, not the current UI verdict. A still-earlier `title_capture_initial` run had a GDScript type-inference error in the capture harness and timed out with exit 124; it supplied no image evidence. The explicit `bool` annotation repaired that harness parse failure.

Current captures retain five Vulkan loader ERROR messages for missing TikTok/Epic overlay manifest files, one registry lookup warning, one duplicate OBS layer warning, and two RGB8-to-RGBA8 conversion warnings. No title script error, object/resource-retention diagnostic, or scene-pairing BUG occurred in this capture. This classification preserves the actual stderr; it is not a claim of a warning-free graphics environment.

The UI correction keeps the underlying structured notice and protection latch intact. A weak title presenter temporarily owns its inline display; the global notice is restored when the title retires. `ORISON_TITLE_DEBUG=1` is the explicit developer-only exposure switch. The ordinary captured title does not sample or invent a campaign opening time.

The final aggregate at `design/astra/evidence/title_save_recovery/receipt.json` binds this capture to the final 123-handler regression, real Continue into both roots, and the 30-check four-direction reconstruction matrix. It records raw copied-source hashes separately from unchanged committed dependency blobs and checks their content across the later production commit. No final capture has been relabeled from an earlier run.
