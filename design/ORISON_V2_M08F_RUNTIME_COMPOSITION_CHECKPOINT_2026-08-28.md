# ORISON-V2-M08F runtime-composition checkpoint — 2026-08-28

Status: **TECHNICAL PASS**. M09 and cutover remain unauthorized.

## Composition topology

| Contract | v1 composition | v2 composition | Durable/save owner | Teardown owner |
|---|---|---|---|---|
| First-shift ritual | `BuildingRoot` mounts four SR7 props and signals `FirstShiftDirector` | `OrisonV2RuntimeRoot` mounts the same classes through semantic anchors and uses the same signals | `RealityState.first_shift`; `WorkOrders` for report lifecycle | Runtime root + anchor adapter |
| Watchman detector | `WatchmanClockProp` | Same class at `F01_WATCHMAN_DETECTOR` | `FirstShiftDirector` observes; prop owns mechanism facts | Mounted prop |
| Night register | `NightRegisterProp` | Same class at `F01_NIGHT_REGISTER` | Register receipt in `RealityState`; `WorkOrders` remains job owner | Mounted prop |
| Signal register | `WatchRegisterProp` + `WatchStationNetwork` | Same classes at `F01_SIGNAL_REGISTER` | Session signal facts only; no new save owner | Mounted prop/network |
| Tour-key custody | `TourKeyGuardProp` | Same class at `F01_TOUR_KEY_GUARD` | Transient guard custody; observed by `FirstShiftDirector` | Mounted prop |
| Porter comparison | `OtisProp` | Same class at `LobbyPorterBoard` | `ServiceRoundDirector` translates completion into `WorkOrders` evidence | Mounted prop |
| 2B radiator | `RadiatorProp` | Same class at `F02_B_RADIATOR_01` | `WorkOrders` job/repair facts | Mounted prop |
| B1 boiler | `BoilerProp` | Same class at `B1_BOILER_01` | `WorkOrders` comparison facts; prop owns mechanism state | Mounted prop |
| Round lifecycle | `ServiceRoundDirector` | Same class, bound to the six real v2 consumers | `WorkOrders` and existing case conversation fact | Runtime root |
| Save/wake | `CoreLoopDirector` + `CampaignShell` | Same authorities with semantic return resolver | `RealityState`; no selector/save duplication | Campaign shell/runtime root |

Review-only M08E cues are not instantiated by `orison_v2_runtime.tscn` and cannot register as interactions. The adapter moves production consumers to semantic transforms only; it never advances jobs, cases, custody, or repair state.

## Runtime proof

`OrisonV2M08FRuntimeTest` executes 29 checks against the selector-loaded production v2 root. It proves six unique spatial owners, six unique gameplay authorities, single lifecycle/save ownership, carrier-formatted prompts, denial states, one issued obligation, ordered radiator/porter/boiler evidence, duplicate refusal, repair, resident close, save/destroy/CampaignShell reconstruction, explicit v2 bedside return, byte-stable layout, v1 default, and deterministic teardown.

The event trace is exactly:

`call → resident → radiator_evidence → lobby_comparison → basement_comparison → diagnosis → repair → resident_return`

The genuine two-root matrix exits 0 and preserves v1→v1, v2→v2, v1→v2, and v2→v1 semantic reconstruction. The anonymous `bed` fallback remains v1-only; v2 resolves `F04_B_BED` through the explicit bedside contract.

## Evidence

Immutable packet: `art/renders/orison_v2/m08f_runtime_composition_01/`

The packet contains 15 rendered 1600×900 frames, `scene_capture_receipt.json`, and `runtime_authority_receipt.json`. The latter records carrier-free semantic prompt text, authority frame, pre/post save phase, and capture result. Capture result: 15/15 PASS in 2.817 s using the production-composed runtime under Vulkan on an NVIDIA GeForce RTX 4080.

## Validation and performance

- M08F focused runtime: 29/29 PASS; 0 retained ObjectDB instances and 0 retained resources.
- Orison v2 blockout: PASS.
- M08A integrated suite: PASS; startup 16.443 ms, 2,186 nodes, 523 collisions, warm CPU maximum 0.176 ms, warm physics maximum 0.526 ms (street cold CPU 129.703 ms).
- M08E collision-bearing route: PASS.
- Genuine two-root matrix: PASS (exit 0), all four reconstruction directions.
- Save compatibility: 14/14 PASS.
- First-shift custody: PASS; its historical immediate-exit one-shot audio decoder warning remains isolated legacy test debt and is not present in the composed M08F harness.
- Service-round lifecycle: PASS and now tears down cleanly.
- Spatial dependency audit: clean after adding only eleven genuine production records for the new v2 composition. Thirty-nine unrelated/test-only incidental records remain unblessed.
- Spatial audit self-tests: 48/48 PASS.
- Interaction prompt-carrier audit: all newly exposed M08F prompts are covered by the central player formatter. The repository-wide audit still reports two pre-existing `Hold E` strings in `clock_prop.gd` and one ambiguous mail-box prompt; none is an M08F surface.
- Production layout SHA-256 remains `9e6b4fa95a88e7ea23fe8bfac188fd094fd1cace628237010a683db7c0c4356e`.
- Selector default remains `v1`.
- Headless focused cold v2 startup: 555–566 ms; warm reconstruction composition: 171–178 ms; 2,970 nodes; 552 collision objects; save 0.572–0.716 ms; v2 reconstruction 184–190 ms; warm CPU 0.614–0.658 ms; warm physics 26.6–31.6 ms during immediate reconstruction sampling.
- Windowed evidence startup/composition: 771.281 ms. GPU device was available for capture, but no gameplay GPU timing instrument was used, so GPU timing is unavailable.
- Existing full-v1 cold matrix startup remains approximately 14.3 s on this host; no v1 production files or layout assets changed.

## Dependency delta and remaining debt

The manifest gains only the production semantic/runtime lookups introduced in `orison_v2_runtime_root.gd`. It does not bless unrelated F03/test drift or review-only cues.

Remaining non-blocking debt: the legacy `FirstShiftCustodyTest` immediate-exit one-shot decoder warning and repository-wide prompt debt outside M08F. The v1 anonymous-bed fallback remains intentionally supported and is not migrated. Final furnishing/art characterization remains outside this checkpoint.

## Disposition

The M08D first-shift/service-round composition blocker is **CLOSED**. Production v1 remains the default; M09 and cutover remain unauthorized.

**M08F is technically complete; request separate authorization for the next full-rebuild milestone.**
