# V2 reservation display proposal

Prepared outside game only. No live installation, Godot run, screenshot or acceptance is claimed. Both terminal packages remain sealed and unchanged.

The production root already disables tiny anchor proxy boxes with `show_clearance_anchors=false`, but that flag does not affect the 70 records constructed by `_build_envelopes()` or the eight landing `Clearance` meshes. They render as development use/clearance volumes around actual consumers, including the terminal. Each of these 78 meshes is explicitly constructed with `collision=false`.

The two-file proposal adds `show_reservation_volumes := true` to the blockout. `_build_envelopes()` and the named landing `Clearance` builder set only their resulting mesh's `visible` property from that flag. Production V2 sets the flag false before the blockout enters the tree. The dedicated blockout scene keeps its default display; the existing anchor-proxy option keeps its separate behavior. This is a construction-time option, not a runtime visibility coordinator.

No node is omitted or freed. IDs, hierarchy, transforms, mesh size/local AABB, material, render layers, `purpose` metadata and collision construction remain unchanged. Hidden terminal-use and stance bounds remain available to the adapter and DeskZone composition. The proposal does not select by a material class, name substring or absence of collision: non-colliding real fixture meshes also exist and must remain visible under their existing owners.

In particular, `_build_fixtures`, `_build_risers`, all walls, doors, windows, stairs, ramps and platform builders are byte-unchanged. The 15 fixture records include unresolved/gray-box bath, bed, boiler and other physical masses; they are not swept into this cleanup. Passenger/service shaft meshes and landing jamb/head geometry are also untouched. Existing `_retire_blockout_fixture` behavior still governs only masses replaced by actual production consumers. This proposal does not complete missing furniture, lift behavior or architectural detail.

The runtime source base is the already reviewed **terminal candidate**, SHA `03d68b7a8f55572c722bb97d0de8b6d1b6644b2072e4d10bfce2a7605c8fe955`, copied from the sealed terminal package. It is not a snapshot of whichever variant root currently runs. Installation must wait for the terminal sequence's review and exact source handoff. If the accepted terminal source differs, this one-line runtime hunk must be rebased and rebound before use. The independent blockout base is `0bdbb7df88d726c622e574a5c6dff30b630a2540aac1101ac9916de72844053e`.

The display distinction already exists in the source and design record:

- [M08A acceptance hardening](C:/PleaseRemainOnTheLine-astra/design/ORISON_V2_M08A_ACCEPTANCE_HARDENING_CHECKPOINT_2026-08-28.md:20) says the player terminal frame suppresses clearance/envelope overlays. Its ten omitted anchor proxies alone do not cover today's 78 volumes.
- [F04 gray-box checkpoint](C:/PleaseRemainOnTheLine-astra/design/ORISON_V2_F04_4B_GRAYBOX_CHECKPOINT_2026-08-28.md:128) retains semantic overlays for top-down review and suppresses them for player-height views.
- [M08E spatial checkpoint](C:/PleaseRemainOnTheLine-astra/design/ORISON_V2_M08E_SPATIAL_OWNERS_CHECKPOINT_2026-08-28.md:36) records the expansion to 70 envelopes; its player captures also hide the debug volumes at line 58.
- [M11B shot helper](C:/PleaseRemainOnTheLine-astra/game/tests/orison_v2_m11b_service_openings_shot.gd:223) already hides exactly the envelope and landing-clearance families for its scoped capture. This proposal does not adopt that helper's additional label/HUD suppression.
- [Vertical-core checkpoint](C:/PleaseRemainOnTheLine-astra/design/ORISON_V2_VERTICAL_CORE_CHECKPOINT_2026-08-28.md:30) distinguishes reservations from lift gameplay. The proposed flag keeps the dedicated review default and does not convert reservations into functioning lift hardware.

No verified material or canon authority conflicts with this bounded display change. Historical visual verdicts do not establish current runtime or perceptual acceptance; new proof remains necessary.

## Focused proof plan, not executed

Use the existing serial runner and source/artifact/PID/diagnostic assessor mechanics after an exclusive lane handoff. Preserve the original two files and exact current source manifest. Do not weaken the terminal fixture or import capture-only claims as interaction proof.

1. Build the actual blockout twice, sequentially and with identical options except the new flag. The untouched dedicated default must expose all 78 targets; the false variant must retain all 78 exact paths but render none. Record both `visible` and `is_visible_in_tree`, with the containing root visible.
2. Snapshot every node's relative path/type, transform, semantic metadata, mesh local/world AABB, mesh/material properties and render layers. Compare modes excluding only the 78 intended visibility bits. Procedurally allocated instance IDs are not equality oracles. Require all non-target visibility values, including the 15 fixture and seven riser families, to match.
3. Compare every CollisionObject/CollisionShape record, transforms, layer/mask and shape parameters across the two modes. Require zero collision descendants under each reservation target. Preserve the existing `OrisonV2BlockoutTest` assertions and run it unchanged as the geometry regression.
4. Compose actual V2 after the accepted terminal candidate. Assert the production flag is false, all 78 IDs still resolve with their recorded bounds, and the adapter's semantic/consumer identities remain unique. Re-run the unchanged 39-check terminal access fixture to prove hidden use bounds still produce the existing actual DeskZone footprint, ray, input, audio and retirement behavior.
5. Independent source omissions: remove only production's false assignment (78 unexpectedly visible); remove only the envelope visibility assignment (70 unexpectedly visible); remove only the landing visibility assignment (eight unexpectedly visible). A separate default-false mutation must fail dedicated-review display. Each stays an ordinary red with the exact source delta, native result and diagnostics retained. Restore exact candidate bytes and re-run the focused checks.

## Matched capture plan, not executed

Preserve an actual V2 baseline after terminal access succeeds but before this display change. Capture the actual operator eye and production phone view with exact matched camera/light/clock/source configuration, then the same views after the change. Include one lobby approach view to inspect the route/desk reservations and one lift-landing view to inspect clearance slabs. Directly inspect every PNG; a mesh visibility count cannot establish readability.

The capture must witness the deferred curb arrival before controlled operator placement, or independently prove the final actor/camera origin. Bind the current physical SignalScope front, actual scope sightline, reservation bounds and semantic transforms. Capture composition is not a walked route or input proof; the separate unchanged terminal fixture owns input/entry/exit assertions. Preserve unresolved real masses and report any remaining obstruction rather than hiding them. Queue root retirement, retain every native error and existing known warning count, and keep actual native exit separate from gate/control results. No performance acceptance follows from wall-clock duration.

`reservation_display.patch` is the complete two-file proposed change. `preparation.json` and `static_source_validation.json` bind the exact inputs, 78 paths and byte-preservation checks. No new runner or executable fixture is introduced by this proposal.
