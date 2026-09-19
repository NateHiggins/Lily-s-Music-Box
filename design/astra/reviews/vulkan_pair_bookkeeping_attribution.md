# Layer-mask pair bookkeeping attribution

The two signatures are separate diagnostic invariants in the same geometry/light
pair bookkeeping. Retained engine source supports one missed pre-layer-change
unpair operation causing either stale set membership or a soft-shadow count
imbalance. It does **not** establish that every underflow in a broad composed run
has that cause. Calling the signatures independently counted is accurate; calling
their root causes necessarily independent is not supported.

No engine, source, gate, threshold or accepted diagnostic policy was changed by
this review. No new source download or search was needed. The retained source
receipt is `../evidence/vulkan_layer_pairing/source_review/sources.json`; engine
binary identities are in that directory's `comparison.json`.

| Retained source | Exact contract |
|---|---|
| `a13da4feb_servers__rendering__renderer_scene_cull.cpp:176` | `_instance_pair` sorts the two types, enters the geometry/light branch, and rejects a nonmatching current layer/cull mask at190. It inserts `geom->lights` and `light->geometries` at195–196. For a light with `uses_softshadow`, it increments `geom->softshadow_count` at215–220. |
| Same file:301 | `_instance_unpair` again rejects according to the **current** masks at315–317. It erases both sets at320–321. It tests count zero at347, emits `geom->softshadow_count==0 - BUG!` at348, then decrements the counter anyway at351. It does not require that either set erase succeeded before decrementing. |
| Same file:923 | `instance_set_layer_mask` returns for an unchanged mask. Its old condition at933–935 performs pre-change unpair for particles or geometry only when the renderer pair mask includes lights/decals; then it writes the new layer mask at939. The comment explicitly requires unpairing before the mask changes to avoid unpairing something never paired. |
| `a13da4feb_servers__rendering__renderer_rd__forward_clustered__render_forward_clustered.cpp:4978` | Forward+ returns only the VOXEL_GI bit from `geometry_instance_get_pair_mask`; ordinary geometry therefore misses that old lights/decals pre-change condition. |
| Scene-cull file:1872 | Its spatial pairing setup still adds INSTANCE_LIGHT for geometry at1873, independently of the optional renderer pair-mask bits added at1880. Light pairs and counters exist even though the layer setter's conditional omits their repair. |
| Scene-cull file:1916 | `_unpair_instance` iterates all recorded pairs, calls `_instance_unpair`, frees the pair records, and removes the instance from its spatial index. Thus a mask-dependent callback can disagree with eligibility at original pairing. |
| Scene-cull file:614 and842 | Light teardown/scenario removal checks whether `light->geometries` is still nonempty after unpairing, emitting `BUG, indexing did not unpair geometries from light.` at616/844. |
| Scene-cull file:1795 and3155 | `uses_softshadow` is enabled for area lights or a light size above epsilon. The count later controls `set_softshadow_projector_pairing` at3160. This is an active renderer invariant, not merely a cosmetic diagnostic. |
| Scene-cull file:824 | `instance_set_scenario` unpairs an indexed instance at831–833 before assigning/requeuing its scenario. The game helper uses this same-scenario route while the old mask is intact. |
| `53ec17a1d2ae9a742ca5a2f65906f52604dfae6e_servers__rendering__renderer_scene_cull.cpp:931` | The retained upstream correction removes the renderer light/decal-mask condition: all particles/geometry unpair before a layer-mask write. |

The current-mask test can differ between pair and unpair when the missing layer
operation changes eligibility. A pair whose bookkeeping was established under a
matching mask can later skip its set cleanup under a nonmatching mask. Conversely,
an unpair callback can become eligible under the new mask without the corresponding
counter increment having been performed under the old mask. These are
source-supported mechanisms, not reconstructed per-instance histories from the
retained logs; those logs contain no geometry/light instance IDs or counter trace.

The exact old-source broad run `../evidence/vulkan_composed/runs/raw_v1_01` retained
2,222 underflows, all naming native `_instance_unpair` at348. Their first GDScript
frames are 1,024 floor visibility writes at old BuildingRoot2678, 1,107 prop
visibility writes at2702, and91 Passage foreign visibility writes at2787. These
are later visibility/de-index operations, not the layer setter itself. The two
stale-light-set errors name `instance_set_scenario:844` and `instance_set_base:616`
immediately before the native crash. The root source for these line references is
the exact selected source in `variant_transactions/raw_v1_01.selected.gd.txt`.
Separate stdout/stderr buffering does not establish a finer total event order.

The helper-only candidate completed without either native signature but failed
arcade ownership and also reported a resident route error. The raw run crashed.
These mixed-cause runs strengthen the hypothesis but cannot become completed,
intended-only negative evidence.

A separately declared **paired-bookkeeping negative contract** would need all of
the following before any corresponding classification is justified:

1. Same actual production root, engine binaries, source/assets, authored light
   properties, frozen clock and fixture scope. Omit only the helper's single
   same-scenario operation; keep the viewport ownership correction and all other
   current repairs. Preserve exact before/after/restoration hashes.
2. A complete bounded process with engine exit0, every applicable functional
   check/capture, actual shell/world retirement and no retained objects/resources.
   A broad crash remains failed evidence; a fresh root-retirement scope may
   explicitly exclude the separate-world light-deletion case.
3. Native errors exclusively the two exact retained signatures, with their
   expected scene-cull functions/locations. Count each separately. No assertion,
   route, parse, unrelated native error, access violation or timeout is covered.
4. Both signatures reproducibly present in the same source-only omission scope,
   then absent after exact helper restoration, with equivalent functional and
   retirement proof. An additional repeat of the bounded omission may establish
   recurrence if the first control's occurrence is timing-dependent.
5. If attribution remains ambiguous, a focused owned soft-shadow light/geometry
   control exercising matching→nonmatching and nonmatching→matching masks and
   later hide/unpair would distinguish the counter paths. Any explicit light
   property variation belongs only to that separately declared focused fixture,
   not to a hidden change in the production-root comparison.

Even after that evidence, the combined field would identify an **observed negative
control**, never a green candidate or diagnostic suppression. Candidate green
must remain free of both signatures, and the strict unpair-only field must still
reject underflow. Matched costs may use only identical completed phases; heavy
native logging remains a disclosed confounder.
