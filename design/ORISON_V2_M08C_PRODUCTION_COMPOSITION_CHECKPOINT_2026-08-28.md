# ORISON-V2-M08C — Production composition checkpoint

Date: 2026-08-28. Base: `f4af33fcabe88d1601f3863a74b88f5d6c490ab5`.

## Selector and rollback

`BuildingRootSelector.DEFAULT_ID` is the sole committed default and remains `v1`. It maps v1 to `res://scenes/building/orison_root.tscn` and v2 to `res://scenes/building/orison_v2_runtime.tscn`. `ORISON_BUILDING_ROOT=v2` is an explicit non-persistent development/test request. Missing values use v1; invalid values warn and use v1. GameBoot and CampaignShell share the cached session decision. A future cutover and rollback each change only `DEFAULT_ID`; selector state never enters a save.

## v2 composition and ownership

The runtime scene composes the collision-bearing generated blockout with the production PlayerController, objective/work-order/inventory owners, the existing lobby props, Vantry/chirp/Mina route, SignalTerminal/CallInterface/VirusSoundDirector, CoreLoop wake resolver, SafetyNet, ServiceSetCarrier, and PlayerController-owned pause/accessibility surface. Existing gameplay classes retain authority. `OrisonV2AnchorAdapter` only resolves/mounts semantic identities and temporarily maps acoustics; startup rejects missing/duplicate required anchors and teardown restores state on success and failure.

The blockout adds non-visible collision ramps over the visible stair steps so the production controller can use continuous vertical circulation; no production asset or layout was changed.

## Matrix and measurements

Focused matrix result: 15/15 contract gates PASS. It proves explicit v1/v2 and absent/invalid selection, v2 production startup, unique anchors, production controller/services, F01/F02/F04 composition, explicit v2 bedside wake, single authorities, forced-failure and success acoustic restoration, and production-layout byte stability. Startup was 390.958 ms, below the established 1,000 ms proportional gate. GPU timing is unavailable headlessly.

The established M08A integrated suite remains the detailed public-behavior/save/traversal proof. However, the new matrix does not yet execute every historical/future save fixture under both fully composed roots, and shutdown still reports the previously observed four ObjectDB/two-resource retention warning. Those facts are not relabeled as passing.

## Blocker disposition

| Pre-M09 prerequisite | Classification |
|---|---|
| One shared selector for boot and reconstruction | PROVEN |
| Production-composed v2 first-slice root | PROVEN WITH TEMPORARY FALLBACK |
| Complete two-root consumer/save matrix | BLOCKING |
| Human route readability | MANUAL PASS |
| Production v1 default and layout bytes | PROVEN |
| Anonymous `bed` | PROVEN WITH TEMPORARY FALLBACK — v1 reconstruction only; not used by v2 wake |
| Debug-intro raw coordinates | OPEN NON-BLOCKING DEBT |
| Four ObjectDB/two-resource shutdown retention | BLOCKING |
| Full first-shift/service-round composition beyond first slice | BLOCKING |

The original dual-hardcode blocker is closed. The composition foundation exists, but production parity is not complete; the complete two-root matrix blocker is not closed. Therefore: **DO NOT AUTHORIZE M09**. M09 and selector cutover remain unauthorized.
