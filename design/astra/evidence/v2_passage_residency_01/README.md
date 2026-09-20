# V2 Passage geometry residency

The production V2 root now retires twelve imported arcade/shop cells inside the named F01 public core and prefetches them at the vestibule. The entrance remains resident. Threaded resource requests feed one off-tree cell per frame, then activate together. A physical entrance barrier stays closed until activation succeeds. The sole hardware transaction service unregisters and remounts its counter.

Physical actors remain allocated, invisible and suspended while geometry is absent. Doors and moved handcarts retain their in-memory identities and state. This is geometry residency, not zero region memory, disk persistence for physical actors, or a full M08F retention receipt.

## Final evidence

- `cycle_03.log`: 42 continuous player-input waypoints, zero failures, empty stderr. Actual hardware acquisition and return, physical cart movement, two reload cycles, zero retired geometry-root and mesh-resource WeakRefs, counter removal/remount, duplicate purchase protection, unchanged door/cart identity and state. Every overridden shader parameter and texture path matches across reconstruction. The purchase image was inspected and retains the physically situated capsule prompt.
- `profile_03.log`: two further walk-driven cycles, 12 waypoints, zero failures, empty stderr. Peak cell preparation 6.813 ms; activation 2.575 ms. Final full route peaks are 7.311 ms and 2.695 ms respectively. These are instrumented CPU staging intervals, not whole-frame or GPU percentiles.
- `teardown_03.log`: five checks, zero failures, empty stderr. The production world is destroyed with issued, unconsumed threaded loads. Requests drain, off-tree staging and dependency references release, repeated shutdown is safe. Drain time 261.230 ms is recorded transition cost, not claimed hitch-free behavior. This fixture directly stimulates the load boundary; it is not traversal evidence.
- `composition.log`: 369 connected-world checks, zero failures, empty stderr. No ShotDir was requested; the five optional screenshot-save checks are absent, explaining the difference from the prior 374-check capture run.
- `save_matrix.log`: 34 checks and all four V1/V2 reconstruction directions pass through actual disk saves, including exact calendar and acquired capsule facts. Stderr contains the deliberate invalid-selector control and existing V1 found-art warning only.

## Measured corrections and retained failures

`route_01` exposed a typed-Variant parse error; `route_02` passes after repair. `cycle_01` exposed a boundary observation missed between draw frames; physics-frame observation repairs it in `cycle_02` and `cycle_03`. The older logs and captures remain.

`cycle_02` and `profile_01` passed functionally but measured 104–108 ms staging spikes. Breakdown located the cost in surface preparation. Numeric texture statistics from initial world construction now survive without retaining resource references. `profile_02` improves to 17.627 ms. Threaded prefetch of SurfacePass height dependencies removes synchronous material texture loads, producing `profile_03`. No original textures, recipes, or calibrated values were changed.

`teardown_01` exited before stopped audio decoders retired, yielding resource warnings despite the five lifecycle assertions passing. Verbose `teardown_02` has empty stderr. The final fixture uses the existing connected-world fixture's 0.25-second audio retirement interval; nonverbose `teardown_03` also has empty stderr. The original warning log is preserved.

## Remaining

Construction shed and world edges, full golden shift, remaining floors/apartments/cast, derived acoustic topology, exported gameplay, full resource/performance review and human acceptance remain open. The optional F01 provider and V1 selector defaults are unchanged. V2 is not finished or approved for default cutover.
