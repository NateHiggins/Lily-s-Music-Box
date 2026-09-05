# NightRegisterTest exit diagnosis and fixture correction

## Captured failure

The original functional suite completes **148/148**, exit 0, yet reports 22 ObjectDB instances and six resources still in use. Its first packet (`evidence/audio_repair_runtime/night_register.stdout.log.stderr`) contains only totals. The subsequent verbose capture (`evidence/audio_ownership/night_suite_verbose.stdout.log:202-232`) identifies:

| Class | Count |
| --- | ---: |
| AudioStreamPlaybackOggVorbis | 8 |
| OggPacketSequencePlayback | 8 |
| OggPacketSequence | 3 |
| AudioStreamOggVorbis | 3 |

The six resource paths are the Ogg stream and packet sequence for each of `pipe_knock.ogg`, `appliance_pop.ogg`, and `metal_tick.ogg` under `res://assets/audio/freesound/processed/mechanical/`. `Interaction` is also an orphan StringName with total reference count 16; it is not an additional count of 16 leaked ObjectDB instances. There are no leaked Node or AudioStreamPlayer3D instances in this inventory.

These are the register's actual knock, paper and index sounds. The eight decoder pairs fit the four register cue families' two-instance limits, but the verbose log alone does not map each decoder identity to a particular register or cue. Do not promote that correspondence to a measured allocation trace.

## Fixture lifetime mismatch

Before correction, every section of `game/tests/night_register_test.gd` ran synchronously inside `_ready`, ending with `get_tree().quit(failures)` without an await or explicit fixture teardown. `_fresh_board` reset authoritative work facts and then queued its old board for deletion. Three additional reload sites also queued old boards. Thus superseded boards stayed in the scene tree and subscribed to the same WorkOrders signal throughout subsequent sections in that frame. An off-tree presentation guard cannot suppress a board that remains in-tree awaiting deletion.

This does not mean queued Nodes are never destroyed on quit. The installed Godot source calls `_flush_delete_queue()` before root exit during [SceneTree::finalize](https://raw.githubusercontent.com/godotengine/godot/a13da4feb/scene/main/scene_tree.cpp). [Node::_propagate_exit_tree](https://raw.githubusercontent.com/godotengine/godot/a13da4feb/scene/main/node.cpp) exits children in reverse order. The late-added main scene consequently retires while the earlier AudioPolicy autoload remains available; any idle replacement slot remains a child of that policy and is subsequently destroyed with it. That ownership order and the absence of leaked pooled player Nodes provide no evidence that slot replacement itself orphaned nodes. They do not prove decoder retirement has drained before AudioServer shutdown.

The known engine pending-playback issue remains separately established by the owner-control fixture: [AudioStreamPlayer3D::stop](https://raw.githubusercontent.com/godotengine/godot/a13da4feb/scene/3d/audio_stream_player_3d.cpp) cancels the pending start and stops internal playback but does not clear its `setplayback` reference. Production release therefore retires the owned player. The functional suite must also retire its fixtures while the application and audio server are still running, instead of making whole-application shutdown the first cleanup boundary.

## Bounded change made

Only `game/tests/night_register_test.gd` is changed by this assignment:

- All four board-replacement sites call `_retire_board`, which frees the superseded fixture immediately and clears its member reference. Fresh-section retirement occurs before resetting RealityState and WorkOrders.
- At the end of all existing assertions, `_teardown` retires the last board, frees the owned stand-in building and WorkOrders, clears their member references, and allows two process frames plus a 0.1-second audio retirement interval before the summary and quit.
- The test still creates and exercises real register sounds and the normal production source-release path. It does not silence sounds, clear the global pool/cache, change the catalog or waive leak diagnostics.

The existing assertion bodies and order are unchanged. Static inverse-patch verification reconstructs the exact normalized HEAD file; all 115 `_check(` sites (including the helper definition and loop-driven calls) remain unchanged. The captured runtime count is 148 checks, not 115.

Before source SHA256: `fb7cae48a09f52a2b321ed2d4bc4168f96a8cb4f9ed9c05313b4b14bc2fc663a`.

After source SHA256: `07fb7ba4af91173b3c18c14e764fa6fc76b628e25a6ab6fbe46411b468c78d26`.

`git diff --check -- game/tests/night_register_test.gd` passes. No Godot execution, production edits, staging or commit by this reviewer.

## Root-executed closure

Root reran NightRegisterTest in a fresh profile with verbose logging after the fixture correction: **148/148, exit 0, empty stderr**, with no leaked-instance, resource-in-use or orphan StringName lines. Evidence is `evidence/audio_ownership/night_suite_green.stdout.log` and `.stderr`. Root verified the corrected source hash above remained unchanged. The original verbose red remains available with the same 148 passing functional assertions and the 22-object/six-resource exit failure.

This controlled result supports the fixture cleanup correction; it does not replace the separate production owner-release and pending-playback controls. Root also executed the independent detached-owner guard regression: the guard-absent control fails 19/20 with an out-of-tree transform error, while the guarded source passes 20/20 with a clean exit (`off_tree_red` / `off_tree_green` logs). These runtime executions are attributed to root, not to this reviewer.
