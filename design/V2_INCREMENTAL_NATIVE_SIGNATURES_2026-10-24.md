# Incremental native signatures and canopy shader lifetime — 2026-10-24

Evidence class: **INERT**. Digest compatibility, actual-asset and played-world
diagnostics; no runtime_contract, surface promotion, human acceptance or V2 completion.

REPORT - remaining native hash/material stalls - 2026-10-24

Canonical checkout **C:/PleaseRemainOnTheLine**, branch
**codex/v2-acoustic-topology**, parent **62e81171**. Previous turn made verified
progress: five fitting families yield between parts. This batch addresses the
remaining whole-buffer hash within a part. Work began locally October23 and
continued into October24; wrapper receipts preserve exact UTC times. Shared bathroom manifest records
and unrelated street/tent/traffic/art/UID work remain outside the checkpoint.

| Location / reproduction | Severity | Evidence | Repair | Verification |
|---|---|---|---|---|
| Passage native throat reconstruction | Input stall | Prior played route records about50ms inside complete mesh-buffer hashing, after the renderer buffers are already available | Resume the identical SHA256 byte stream in bounded buffer updates | Complete byte compatibility and actual fittings pass; final hash slices peak3.472ms in the played route |
| Synchronous signature with an empty packed buffer | Error log | Frozen original calls HashingContext.update(empty), which logs FAILED while leaving the digest unchanged | Omit that empty update, preserving the original stream | Empty-buffer controls use independent full-stream concatenation; all nonempty controls compare the frozen original |
| One-microsecond fitting control | Progress failure | Pre-work deadline checks can indefinitely defer the same stage | Advance at least one hash unit; completed hash mounts on a subsequent call even with a tiny budget | Existing partial-publication and shape-mutation controls complete again |
| Diagnostic lifetime probes | False failure | Getter temporaries keep RefCounted contexts alive until their probing frame unwinds | Check weak references after the helper scope ends | Cancel/abandon during hashing prove both model and context release |
| Canopy material assignment on reload | About79ms main-thread stall | Moving the material into mesh construction only moves the cost into that call | Keep the existing canopy material alive while geometry is dormant; clear it on residency shutdown | Four warm assignments0.07–0.21ms; releasing it for an untimed reload restores74.579ms |

The synchronous signature API retains its byte order, five scalar/AABB headers,
five buffer names, lengths, full buffer contents and original non-packed fallback
encoding. Cooperative fitting uses a SignatureJob with at most256KiB in each
packed-buffer update. All chunks, including the final suffix, feed the same SHA256
context. No digest byte, header, channel or geometry check is omitted. This is
cooperative main-thread work, not a worker thread touching scene resources.

The job freezes the input dictionary/header/array values and copy-on-write
buffers. The mesh copy receives exactly that completed hash snapshot. A native
mesh identity change or source-resource mutation during the yield refuses
publication. Source boundaries, removed triangle counts, UV/normal buffers,
material fields, cached exact collision geometry, face-hash invalidation and
the bounded cache remain authoritative. Synchronous startup callers retain
their existing path, with only the empty-update error corrected.

Cancellation drops the unfinished hash and private model. Abandonment releases
both after the enclosing probe frame has unwound; no strong context reference
is hidden in a test's getter temporary. Existing source-pose/resource mutation,
same-RID collision changes, one-use handoff and all five fitting-family output
comparisons remain. Tiny budgets guarantee progress; a single mesh read/copy,
material assignment, source cut or publication can still exceed the frame budget.

**signature_final** reports60 checks with empty stderr: chunk boundaries,
all channels and headers, missing/non-packed fields, multi-surface/empty input,
caller mutation, completed-context stability and exact mesh-copy snapshot.
**fitting_v5** reports37 checks with empty stderr against actual authored cells
and the hash-bound frozen original fitter. **cache_final** reports73 checks,
0 failures and empty stderr. These are component diagnostics, not player-input
qualification or evidence that every existing V2 area is complete.

Originals retained in **art/reviews/v2_incremental_hash_20261023/**:
**signature_v1** reports54 logical comparisons but logs five errors from the
frozen synchronous empty-buffer call; it is not a clean pass. Subsequent zero
controls build the complete byte stream independently rather than filtering
those errors. The old source remains unchanged and hash-bound.

**fitting_v1** hits the old1,000-step/one-microsecond drain limit, then the
diagnostic dereferences its unpublished model and idles until the runner ceiling;
no suite verdict. **fitting_v2** repeated before the intended harness edit took
effect and was stopped only after its exact owned engine/console/wrapper chain
and diagnostic error were verified; its exit-1 wrapper receipt is not a passing
suite. **fitting_v2_terminal.json** records that ownership and action.
**fitting_v3** exposes starvation in a tight one-microsecond shape control and
times out with no suite verdict. The progress fix is in production code;
the general drain now uses500us chunks and fails cleanly if it cannot publish.
**fitting_v4** passes geometry but fails two lifetime probes because the probe
frame retains getter temporaries. Repeat5 checks release outside that scope;
no cancellation assertion is removed. Failed sources and receipts remain.

The material-construction candidate is **rejected**, not installed. Upstream
[ArrayMesh code](https://raw.githubusercontent.com/godotengine/godot/master/scene/resources/mesh.cpp)
accepts a material in the serialized surface dictionary. This suggested avoiding
a later setter; the37-check actual-asset comparison and73-check cache suite pass
for that candidate. Its played run instead moves about79ms into construction
(82.241ms duplication,0.029ms slot assignment), with79.595ms peak fitting and
no loading-tail benefit. The original material-set path is restored. Raw source
and **material_played_v1** remain so a narrower timing field cannot suggest a
false speedup.

Upstream [BaseMaterial3D code](https://raw.githubusercontent.com/godotengine/godot/master/scene/resources/material.cpp)
shares shader variants by key and releases a variant when its material-user
count reaches zero. That supports the shader-lifetime hypothesis; master is
not asserted to be the exact installed revision. The installed4.7.1 windowed
controls supply the behavior evidence. Residency already visits source materials
for texture statistics; it now keeps the one existing **canopy__glassish**
material reference from that pass. It creates no extra visual surface or scan,
changes no material properties, and holds no imported mesh. Shutdown clears the
reference. The cache trades one dormant material/shader lifetime for avoiding
that repeated regeneration. It is scoped to the measured variant.

**warm_shader_v1** and **warm_shader_v3** both pass two timed played cycles,
54 waypoints/14 checks, ordinary gateway readiness and complete root/mesh
retirement. They each report58 total waypoints/0 failures after the existing
untimed lighting prefetch. The6,586-check fixed-light validator passes; its
circuit APIs are diagnostics, not primary-input switch qualification. Door
grabbing/mouse travel/release and normal movement use the unchanged inherited
route. These runs do not qualify all furnishings, book/inspection interactions,
procurement, save reconstruction or human acceptance.

Repeat3 reuses that required untimed prefetch as a negative control, after
timed traces freeze. It releases the retained material while DORMANT and proves
the weak reference is gone. That same-process cold reload returns canopy
assignment to74.579ms, versus0.072/0.205ms in its two warm cycles. The material
count goes1→0; retired mesh/root references stay0. No extra timed samples are
included. No heavy static work overlaps either the timed routes or this cold
performance control. **untimed_shader_control.json** records the distinction.
The additional control's first attempt **warm_shader_v2** fails to compile on
an inferred Variant; only its verified owned empty window is closed gracefully.
Wrapper exit0 is not a passing suite. Its source and terminal ownership record
remain; explicit WeakRef types correct the diagnostic.

All timing runs retain1280x720 Forward+, VSync disabled, authored20:00 start,
the same native/retirement profiling, screenshot exclusions and owned automatic
persistence. Analysis uses post-render signal intervals and active callback wall
time, not OS/display latency or exclusive CPU/GPU partitions.

| Interval / fitting work | Previous checkpoint | Hash only | Warm repeat1 | Warm repeat3 |
|---|---:|---:|---:|---:|
| Samples |3182|3188|3175|3187|
| p50 |24.951ms|24.655ms|24.962ms|24.907ms|
| p95 |38.968ms|38.776ms|38.645ms|38.964ms|
| p99 |52.516ms|52.432ms|52.233ms|51.243ms|
| Maximum |160.286ms|158.732ms|161.624ms|158.335ms|
| Above100ms |4|3|1|2|
| LOADING p99 |67.888ms|71.106ms|66.709ms|61.045ms|
| Peak fitting step |77.000ms|79.322ms|63.805ms|63.098ms|

Hash slicing alone is not a broad frame-time win: loading p99 worsens despite
removing its single long hash call. Total hash CPU time can increase from chunk
and snapshot overhead. Final hash slices peak3.472ms, with a complete throat
digest still taking about59ms across calls. Both warm repeats avoid the measured
canopy stall; overall tails vary and the median barely changes. The final run
still has63.098ms atomic fitting elsewhere and a158.335ms first-render interval,
including150.741ms render submission/wait and83 surface/96 specialization
increments. A96.785ms loading interval contains76.205ms outside observed callback
windows and remains unclassified. The107.033ms nave-turn interval includes
97.938ms submission/wait. Physics callbacks peak24.429ms and household commits
remain about22ms median; this does not establish solver work as the cause.

Background reconstruction stays about10.5–10.7s, versus10.55s at the preceding
checkpoint. Faster approaches remain unqualified. The bounded collision cache
stays1269 parts/88608528 bytes. Resource requests, retired roots and retired mesh
resources return to0. Owned primary/backup cleanup returns0. The seven existing
Texture RID teardown warnings remain on all complete runs. Rendering preserves
the detailed nave, shop fronts, furnishing, native fixtures, glass and materials;
no Blender geometry, UV, PBR map, loaded-mipmap policy or catalogue key changes.

Final full board **gates_final/board.json** reports no regressions against the
preceding shared-tree board:101 PASS,8 FAIL,1 INCOMPLETE;98 tools suites,
1194 tests and five existing failures. Spatial stays8 failing/39 advisory;
systemic26 reviews; reader1141 unread/33 NEW; physical source wrong4 and stale
surface qualifications2 unchanged. Ledger240 requirements, blocker counts
7/8/110/42/134/136 and requirements_changed empty. No audit baseline, field
exception, material catalogue entry or spatial-manifest record changes.

Protected17/17 match the preceding working hashes, with selector default V2
and explicit V1 rollback unchanged. Sixteen executed top-level sources match
their wrapper raw hashes. Raw/normalized source snapshots, original
failures, wrapper receipts and rendered captures remain in the packet. Wrapper
suite_run and INERT outputs are diagnostics, not runtime_contract evidence.
No clean merge-base board exists for in-place candidate verification; no
candidate-verifier pass or human acceptance is claimed.

Branch / HEAD / origin/main / merge-base: **codex/v2-acoustic-topology** /
**62e81171** / **dcf60cf0** / **21f0b1fc**, as observed at closeout. Worktree clean
at end: no. The two shared bathroom manifest records remain unstaged, along
with unrelated untracked street/tent/traffic/art/UID work. No worktree is created
or removed. All engine launches use shared-lane wrappers; only confirmed owned
failed diagnostics are stopped, with terminal ownership records retained.

Changes outside the three production fitting/cache/residency files: new
signature bench/scene, the existing fitting and streaming diagnostics, raw
byte-preservation rule, evidence packet and continuation documents. No geometry,
PBR map, physical authority, mechanical/NPC/inventory/save/case owner or targeting
scan changes. Reticle and direct-manipulation coverage, complete furnishing/
inspection routes, hose/books/bath/device/street/player work, startup latency,
remaining atomic calls and first-render/GPU/unclassified waits remain open in
the started-work queue. The retained shader's program-memory cost is not isolated
by these timing controls. This checkpoint does not complete V2.

Decision needed from owner: none.

BLOCKED remaining performance stalls and broader started-work/runtime/human coverage remain open
