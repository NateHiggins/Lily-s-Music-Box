# V2 terminal operator capture and accessibility diagnosis

Prepared outside the game; **not installed, parsed by Godot, or run**. Excluded from the current renderer/material foundation checkpoint. That checkpoint's completed 305-check V1 proof belongs to original fixture `5ec63c36c6181b33c02bd2255039e9bf4e8db0c4465a45ac641d1481f422d6d3`. The captured HEAD in `preparation.json` is historical; its named raw source hashes are the preparation bindings.

Only `game/tests/vulkan_composed_root_test.gd` would change. Its `_v2()` block gains three V2-only diagnostic helpers. `static_validation.json` proves the complete 20,001-byte prefix and 12,445-byte shared suffix remain identical, including every V1/shared function. The scene is unchanged. Candidate SHA256: `4607eca50a8e9758bcfcd9a2c218cbda6755ac81a1b3468eba46a92fab054b38`.

The old V2 capture placed the camera at the correct **bedside return** anchor and aimed approximately eight metres toward the terminal through the private hall. The original bed-anchor assertion remains. The two normal captures now use the actual `F04_B_MONITOR_STANCE` at `(-9.9, 9.6, 1.25)` and aim at the live `SignalScope` mesh. The fixture records a ray from the exact old eye/target and another from the current operator camera to that mesh. Rays inspect the actual camera World3D's bodies, including hits from inside, and exclude only the player RID. A clear segment proves neither visible readability nor interaction.

Authored sources are [operator/terminal anchors](../../../../../../game/data/orison_v2_blockout.json#L258), [stance and use envelopes](../../../../../../game/data/orison_v2_blockout.json#L181), [anchor mounting](../../../../../../game/scripts/building/orison_v2_anchor_adapter.gd#L74), and [SignalScope construction](../../../../../../game/scripts/props/signal_terminal_prop.gd#L113). The terminal's instrument face is local +X. Its current authored yaw of `-PI/2` maps that face approximately along +Z, while the operator is west of the terminal. The actual mounted face/operator dot is recorded and must be at least 0.5 (within 60 degrees horizontally); the source predicts this check will fail. No model is rotated to satisfy the fixture.

**The missing V2 DeskZone is an actual accessibility defect.** [DeskZone.interact](../../../../../../game/scripts/call/desk_zone.gd#L33) owns the production call entry. [V2 composition](../../../../../../game/scripts/building/orison_v2_runtime_root.gd#L110) mounts a terminal and CallInterface without this owner. SignalTerminalProp has no `interact` method; [FunctionalProp](../../../../../../game/scripts/props/functional_prop.gd#L56) consequently creates no primary interaction area. The new check requires a real DeskZone bound to this root's CallInterface. This is an owner-presence check: even a future pass would not establish stance reach, ray acquisition, seating or a completed call. No interaction is invoked by this fixture.

The receipt also records actual use/stance/semantic proxy meshes: world bounds, visibility, camera containment and cull-mask overlap, active material class/transparency/alpha, and collision descendants. Existing translucent proxies remain rendered. Their visual obstruction must be judged from the two PNGs even when a physics segment is clear.

## Later authorized execution

After root grants an exclusive lane and installs the reviewed candidate, use the existing unchanged runner and gate:

```powershell
python design/astra/work/vulkan_composed/run_case.py v2 candidate terminal_operator_view_v2_01
```

This proposes the fresh evidence directory `design/astra/evidence/vulkan_composed/runs/terminal_operator_view_v2_01`; it has not been created or run here. Require the candidate fixture hash in both source manifests, stable other inputs/engine, readable `frames/probe.json`, all 21 exact unique ordered labels from `preparation.json`, complete `v2_terminal_operator_view` diagnostics, the actual native outcome/raw diagnostics, and both retirement checks. Preserve any parse/setup/timeout or additional failure without relabeling it.

The unchanged gate's historical filenames remain `v2_actual_f04_semantic_stance.png` and `v2_actual_f04_phone.png`. These now mean the recorded **operator** capture; inspect both PNGs independently. The fixture still uses controlled teleport and a fixture-mounted production PhoneCamera, not walking or the physical handset flow. It makes no timing/performance acceptance claim.

The old 14 checks remain and seven are added, for 21 on a complete run. Source inspection predicts two failures: terminal-facing and missing bound DeskZone. If those are the only failures, the native exit and strict diagnostic gate should both be **1**. That is an unresolved candidate result, not an accepted negative-control exception. Other sightline, rendering, diagnostic or retirement failures remain failures. No wrapper/gate behavior or exception list changes in this proposal.
