The matching official source for the installed **Godot 4.7.1 `a13da4feb` lacks the geometry-layer unpair fix**. The V1 failure is a strong match for Godot issue [#121989](https://github.com/godotengine/godot/issues/121989), but no minimal reproduction or workaround has been run in this review. The candidate below must earn its own red/green proof before integration. No live game file, renderer setting, engine installation or Git state was changed, and no Godot process was launched.

The prior actual V1 capture identifies `v4.7.1.stable.official.a13da4feb` at [stdout line2](../evidence/historical_radio_notice/capture_03/godot.stdout.log), reports Vulkan 1.4.341 / Forward+ / RTX4080 at line39, and confirms `forward_plus` at line292. The installed GUI executable is178,997,256 bytes, SHA256 `323f9c4cc5db674e98815cdd8e69da007d5efc779abedc8c0e42883b7fdea12a`; its console launcher is198,152 bytes, SHA256 `35dab11e04ece16a2b93035e65204f4a944a3e00b020d43e54409193379d5eef`. These bind the inspected installation to the earlier execution. Matching source was fetched from the official repository at that self-reported revision; binary disassembly or a reproducible-build comparison was not performed.

[PR #122064](https://github.com/godotengine/godot/pull/122064) was merged to master on August11,2026, with milestone4.8. Its implementation commit is [`53ec17a1d2ae9a742ca5a2f65906f52604dfae6e`](https://github.com/godotengine/godot/commit/53ec17a1d2ae9a742ca5a2f65906f52604dfae6e); merge commit is [`299161177d17e7dd0c546233ea7b5ccbb35581f3`](https://github.com/godotengine/godot/commit/299161177d17e7dd0c546233ea7b5ccbb35581f3). The [five-line diff](https://github.com/godotengine/godot/pull/122064/files) makes geometry unpairing unconditional before changing its layer mask. A merged master fix does not establish inclusion in the installed stable build.

The source comparison is specific:

| Evidence | Finding |
| --- | --- |
| [Installed-revision cull source, lines923–940](https://github.com/godotengine/godot/blob/a13da4feb/servers/rendering/renderer_scene_cull.cpp#L923) | Geometry unpairing still depends on the LIGHT/DECAL bits of `geometry_instance_pair_mask`. The corrected condition is absent. |
| [Forward+ source, line4978](https://github.com/godotengine/godot/blob/a13da4feb/servers/rendering/renderer_rd/forward_clustered/render_forward_clustered.cpp#L4978) | Its pair mask contains only VOXEL_GI, so the old condition excludes ordinary meshes. |
| [Pair/unpair source, lines187 and309](https://github.com/godotengine/godot/blob/a13da4feb/servers/rendering/renderer_scene_cull.cpp#L187) | Light/geometry bookkeeping exists independently of that renderer mask. Unpairing tests the geometry's current layer against the light mask. |
| [Retained stderr](../evidence/historical_radio_notice/capture_03/godot.stdout.log.stderr) | Exact installed source locations match: soft-shadow underflow diagnostic at348; leftover light/geometry membership at844. Final capture counts were261 and1,252 respectively. |

Changing a previously paired mesh to layer0 can therefore make later cleanup skip the old membership. Restoring layers does not reconstruct the bookkeeping that should have been updated before the original mutation. This explains why extra teardown frames did not resolve the capture errors. It is a source-supported causal hypothesis for the game, not proof that every reported soft-shadow error has this single cause. The unrelated host Vulkan layer manifests, RGB8 conversions and found-art warning stay separately classified.

The concrete production consumer is [building_root.gd `_zone_toggle`](../../../game/scripts/building/building_root.gd#L2847). PASSAGE and STREET both call it; `_zone_layer_blocks` composes their blockers, and `passage_late_saved` preserves each authored mask. The two assignments at2863 and2867 restore that exact mask or apply0. The nearby comment documents a prior roughly2,000-object F04 regression when direct visibility restoration overrode other owners. **Keep the blocker tables, exact authored masks and the AND relationship with each node's own visibility.** A permanent `.visible = eligible` substitution, global shadow disabling or a renderer switch would violate those requirements.

The smallest candidate worth testing is an unchanged-layer guard plus a **same-scenario renderer rebind immediately before each real layer change**. At the installed revision, [`instance_set_scenario`](https://github.com/godotengine/godot/blob/a13da4feb/servers/rendering/renderer_scene_cull.cpp#L824) has no same-RID early return: it unpairs the indexed instance while its old layer is still intact, reattaches it and queues an update. [`VisualInstance3D`](https://github.com/godotengine/godot/blob/a13da4feb/scene/3d/visual_instance_3d.cpp#L91) normally uses `get_world_3d().scenario` for this binding and exposes its instance RID. This gives a public GDScript route to the missing pre-change operation without assigning the Node3D visibility property, reparenting nodes or replacing their mesh resources.

Proposed sequence only, not applied or tested:

```gdscript
# Candidate helper called by the two existing layer assignments.
# Only actual GeometryInstance3D consumers need the workaround.
if geometry.layers != target_layers:
    if geometry.is_inside_tree():
        var world: World3D = geometry.get_world_3d()
        if world != null:
            RenderingServer.instance_set_scenario(
                geometry.get_instance(), world.scenario)
    geometry.layers = target_layers
```

Keep these operations synchronous and ordered, without a frame wait between them. Use the geometry's own World3D, including a SubViewport's world where applicable. Do not apply this to lights, repeatedly rebind unchanged masks, or attempt to repair a scene after it has already accumulated stale pairs. Start a fresh process with the candidate active before the first mutation. This rebind queues more work than the upstream fix, including bounds/dependency refresh; its transition cost and any LOD/GI consequences require measurement. Directly toggling renderer visibility would be another possible unpair trigger, but adds a transient visibility writer and is not the preferred first experiment.

The next bounded proof should use an isolated windowed Forward+ fixture through the unchanged serial runner, after its owner releases the lane. A camera, box and nearby shadowed OmniLight are sufficient. Render several frames before mutation and after mutation/deletion; use a nonzero light size for the soft-shadow variant. Keep engine, resolution, source hashes and fresh profile explicit.

| Control | Required interpretation |
| --- | --- |
| Static matching layer, then delete light | Establish clean ordinary teardown on this installation. |
| Matching layer1 →0, then delete light; optionally restore1 before final teardown | Expect the upstream unpair signature on the unchanged engine. This adapts the official reproduction to the game's actual0-mask gate. |
| Identical sequence with the proposed pre-change rebind | Candidate only passes with zero pairing/underflow/retention errors, correct rendered absence/restoration and unchanged owner visibility. |
| Omit only the rebind from that fixture | The same log-aware gate must return to red. Preserve engine exit and validator exit separately; these engine diagnostics can accompany exit0. |

Only after that isolated proof should a small helper be proposed for `_zone_toggle`'s two assignments. Retain and run [StreetCoreVisibilityTest](../../../game/tests/StreetCoreVisibilityTest.tscn) and [PassageVisibilityTest](../../../game/tests/PassageVisibilityTest.tscn), especially overlapping blockers, exact restoration, hidden owner/parent states and the drain of saved masks. Add a changed-only call counter so repeated eligibility does not cause scenario churn. Then run a fresh V1 production transition/capture with STREET →PASSAGE →ORISON and F04 controls, followed by actual world retirement. Inspect the images and raw diagnostics, and compare transition frame cost to the original gate. The existing historical-notice capture is a concrete final smoke consumer, not a substitute for those visibility-ownership controls.

The other layer writes found by the bounded script census belong to device isolation, a mirror surface and dream presentation setup. They are not cleared by this hypothesis or included in the proposed helper automatically. If the controlled `_zone_toggle` treatment leaves residual pairing errors, trace those writes before expanding scope.

Official source copies with original MIT notices and byte hashes are retained in [source_review/sources.json](../evidence/vulkan_layer_pairing/source_review/sources.json). This review is an identified engine defect plus an unrun game-side candidate. It authorizes no installation, engine rebuild, renderer change or production acceptance.
