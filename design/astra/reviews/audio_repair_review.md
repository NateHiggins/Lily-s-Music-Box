# Independent audio repair review

Read-only review of the candidate whose three source hashes match the `complete_owner_release` control in `design/astra/evidence/audio_ownership/owner_controls_v2/owner_controls.json`. No product edits or Godot execution by this reviewer.

## P2: prevent detached registers from reacquiring a pooled voice

`game/scripts/props/night_register_prop.gd:241–245` releases the source during `_exit_tree`, but the register remains subscribed to `WorkOrders.job_stage_changed` from `:258–261`. An existing register removed from the tree but not yet freed can still receive a presentable-job transition. That calls `_on_job_stage_changed():264–268`, then `_refresh_board():1310–1324`, then `_refresh_slip_visibility():996–998`, which calls `_present_register_sound():1282–1283` without a tree/lifetime guard. A fresh report can consequently allocate a new global voice after this owner has already released its source; its out-of-tree global-position query can also issue an engine diagnostic.

This lifetime exists in a production API, not just a hypothetical stale reference: `orison_v2_anchor_adapter.gd:87–98` removes and returns a live consumer; `restore_all():100–108` defaults to deferred deletion. `orison_v2_runtime_root.gd:329` uses that default in `_exit_tree`. Immediate destruction is separately used by `shutdown_for_tests():325`.

**Small correction:** guard source presentation against an out-of-tree/retired owner, or explicitly disconnect and correctly restore the job subscription at lifecycle boundaries. Keep the repair local to the source so an already-retired register cannot recreate a global voice. Do not broadly mute the policy or disconnect other residents/props.

**Decisive regression:** create and bind the real register with no available report; remove it from the tree without freeing it; issue a presentable job before deferred deletion; assert no new register-paper event, no active/reacquired source voice and no out-of-tree diagnostic; then free it. Retain an independent live neighbor to show that the neighbor still receives its legitimate report sound. The current fixture calls `first.free()`/`second.free()` immediately, so its strong pending-versus-mixer decoder proof does not cover this specific detached interval.

## Closure

Root added the local `is_inside_tree()` guard in `_present_register_sound` and extended the real-owner lifecycle fixture with the detached interval and a live neighbor. Root-executed evidence preserves the guard-absent failure at 19/20, exit 1, including the out-of-tree transform diagnostic (`evidence/audio_ownership/off_tree_red.stdout.log` and `.stderr`), and the guarded 20/20, exit 0, clean result (`off_tree_green.stdout.log` and `.stderr`). This resolves the issue above. The subsequent functional-suite shutdown finding and bounded test-only correction are documented separately in `night_register_exit_review.md`.
