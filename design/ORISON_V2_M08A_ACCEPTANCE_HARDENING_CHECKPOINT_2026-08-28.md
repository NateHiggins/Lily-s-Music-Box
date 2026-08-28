# ORISON-V2-M08A — Acceptance-Hardening Checkpoint

Date: 2026-08-28

Base: `47da37a788554afc8e868d6c56d9bc587569a173`

Selector: explicit development scene `res://scenes/building/orison_v2_integrated_review.tscn`; production v1 remains default.

Status: automated hardening passes; **HUMAN ACCEPTANCE PASS**. Owner verdict
recorded 2026-08-28 in
`design/ORISON_V2_M08A_HUMAN_ACCEPTANCE_2026-08-28.json`.

## Readability findings and corrections

| M08 finding | Bounded M08A correction |
|---|---|
| Upward-transition frame was dark and occluded. | Three non-colliding stair light pools per storey expose the first flight, U-turn, second flight, and arrival; replacement cameras stand at player height on the approach and half landing. |
| Lobby did not reveal the primary upward route. | A blue architectural route band, illuminated stair aperture, and repeated core color establish the route from the natural lobby approach. |
| 2A and 4B thresholds were indistinguishable. | Each receives a contrasting non-colliding portal header, physical unit plate, matching floor band, and localized threshold light; F02/F04 floor plates confirm arrival. |
| Terminal frame was blocked by debug geometry and lacked context. | All clearance/envelope overlays are disabled; a schematic terminal cabinet, work surface, local light, and open domestic circulation establish the work/home volume. |
| Frames favored available area over player orientation. | All ten captures use realistic 1.41 m player-eye viewpoints; the one wide bedside view is still player-height and is explicitly composed to contain bed, route band, and doorway. |
| Bedside opening did not explain return direction. | A gray-box bed/headboard establishes home context while the orange floor band terminates at the visible domestic doorway toward the apartment exit. |

These are development-only, non-colliding architectural cues: portal hierarchy, unit/floor plates, floor bands, localized light, and schematic terminal/bed masses. They are not final decoration, resident dressing, materials, or a substitute interaction protocol.

## Strengthened runtime proof

- **F01:** `OtisProp`, `HouseSwitchboardProp`, and `DumbwaiterProp` are temporarily mounted at v2 semantic anchors through `OrisonV2AnchorAdapter`. Their public prompt, control, action-result, maintenance-snapshot, and position contracts are exercised. `LobbyMailBank` remains uniquely resolved; no duplicate implementation was created.
- **F02:** a real `MaintenanceJobLibrary`, `WorkOrders`, `MaintenanceInventory`, `VantryPointNetwork`, `VantryPointProp`, and `ChirpHunt` run together at the v2-selected point. The authored job resolves to case `mina_caption_crisis`; report → acknowledge → public grille interaction advances the existing job to `awaiting_part`, and the prompt reports the carbon-capsule need. The integrated controller route reaches the same position.
- **F04:** a real `SignalTerminalProp` is mounted as `F04_B_MONITOR_01`; public `CallInterface.enter`, isolate, capture, and route methods run the normal case path through response/outcome. The physical terminal stage changes and the temporarily selected acoustic origin equals the terminal position.
- **Wake/save:** `RealityState.save_game` writes a real temporary save, runtime data is cleared, `load_game` reloads it, the v2 review root is reconstructed, and `F04_B_BED` resolves as the saved return identity. The production-layout anonymous `bed` fallback is checked separately. The independent future-save suite also passes 14/14.
- **Restoration:** acoustic records are deep-snapshotted and compared after scoped override; every mounted consumer is unmounted; the promoted Vantry owner, job stack, CallInterface, and reconstructed root are freed; the final adapter asserts no retained mounts/overrides.

## Validation

| Gate | Result |
|---|---|
| Orison v2 schema and all milestone assertions (`OrisonV2BlockoutTest`) | PASS |
| Integrated scene startup and readability-cue construction | PASS |
| Twelve compatibility identities resolve uniquely | PASS |
| Continuous street → F01 → F02/2A → F04/4B → bedside controller travel | PASS |
| Strengthened F01 production-consumer behavior | PASS |
| Strengthened Mina/chirp/job/case/acoustic behavior | PASS |
| Strengthened signal-terminal/call/audio behavior | PASS |
| Real v2 save/reload/reconstruct plus separate v1 fallback | PASS |
| Independent future/legacy save compatibility | PASS 14/14 |
| Service and vertical-stack continuity | PASS |
| Production layout SHA-256 before/after | PASS, byte-stable |
| Adapter/acoustic teardown | PASS |
| Evidence receipt | PASS 10/10 at 1600×900 |

## Performance

The established 16.67 ms / 60 Hz proportional budget is unchanged. Final headless run: startup 13.829 ms, 1,706 blockout nodes, 411 collision objects. M08A intentionally omits ten debug anchor-envelope nodes in the integrated selector; cues themselves are outside the collision blockout. Warm fixed-station samples follow.

| Station | CPU ms | Physics ms |
|---|---:|---:|
| F01 threshold/lobby | 0.139 | 0.219 |
| Primary F01→F02 stair | 0.156 | 0.684 |
| F02 landing | 0.146 | 0.491 |
| 2A work position | 0.153 | 0.342 |
| Primary F02→F03 stair | 0.147 | 0.562 |
| Primary F03→F04 stair | 0.147 | 0.276 |
| F04 landing | 0.343 | 0.295 |
| 4B terminal | 0.316 | 2.382 |
| Bedside return | 0.125 | 0.364 |

The cold street sample (CPU 133.180 ms / physics 10.873 ms) includes runtime consumer construction and import warmup and is reported as startup work, not steady gameplay. GPU gameplay time remains unavailable in the headless traversal and is not inferred from composition capture speed.

## Leak disposition

The M08 four-ObjectDB/two-resource warning was reproduced and traced to focused-test teardown: mounted functional consumers, the Vantry owner promoted out of its temporary network, CallInterface, and the reconstructed review root survived until `quit()`. M08A explicitly removes/unmounts those owners, restores global acoustic state, frees both review roots, and waits two process frames. The final integrated run exits without ObjectDB or resource leak warnings.

## Evidence and human decision

Before: `art/renders/orison_v2/m08_integrated_checkpoint_01/`

Candidate after packet: `art/renders/orison_v2/m08a_readability_checkpoint_04/`

Receipt: `art/renders/orison_v2/m08a_readability_checkpoint_04/scene_capture_receipt.json`

Human checklist—without coordinates, identify:

1. Where do you enter the public building?
2. From the lobby, where do you go up?
3. Which threshold is apartment 2A?
4. From inside 2A, how do you return to the primary stair?
5. Which threshold is apartment 4B?
6. Where is the signal terminal within the work/home space?
7. From bedside, which route leads back toward the apartment exit?

The precise acceptance question is: **“Using only the ten M08A frames and no coordinate knowledge, can you correctly answer all seven checklist questions without ambiguity?”**

Owner verdict: **PASS** — “I can understand the layout.” The owner confirmed
that all seven checklist questions can be answered without ambiguity from the
ten-frame packet. This closes route-readability review only. M09, production
selection, v1 retirement, and cutover remain separately unauthorized.
