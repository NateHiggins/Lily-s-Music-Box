# Portrait reload cost and material restoration lifetime — 2026-10-24

Evidence class: **INERT**. Component and played-world diagnostics, not a
runtime_contract, surface qualification, human acceptance or V2 completion.

REPORT - portrait reload and retired-material ownership - 2026-10-24

Branch **codex/v2-acoustic-topology**, parent **29c88736**, canonical checkout
**C:/PleaseRemainOnTheLine**. Remote branch still matches the parent;
origin/main is **dcf60cf078b81ea7f51ed3e239a42d1274295aad**, merge-base
**21f0b1fc27ac8e25c8466fe1ed2ce64019ee7ede**. Main's newer unrelated work is not
reverted or claimed as integrated here. Shared bathroom manifest additions and unrelated
street/tent/traffic/art work remain preserved. The owner closed a window that
appeared stalled; the preceding run's receipt was already terminal. No process
was killed or failure relabeled because of that report.

| Location / reproduction | Severity | Evidence | Repair | Verification |
|---|---|---|---|---|
| Photography shop, return from the street | Input hitch | Original portrait wrapper takes61.0–61.7ms;34.7–35.0ms is its forced fresh atlas load | Keep one validated atlas for the passage world's lifetime | Warm reloads and complete pixel/mipmap comparisons; cold-load control retained |
| UV policy, retire local surface shaders | Retained resources | Clearing the atlas cache in the first candidate does not release its texture; original restoration ledger owns strong Material references | Weak restoration records; inspect four records per new correction to prune dead entries | Frozen-original negative control, live-default restoration and actual dormant texture release |
| Laundry, cobbler and locksmith native stock reload | Input hitch | Existing atomic fits remain beyond the cooperative budget | Use the existing private native fitting job for these three recipes |49 frozen-original/output/mutation/cancellation checks across eight families |
| Portrait diagnostic in a composed V2 world | False diagnostic failure | Historical check assumes shared catalogue triplanar defaults are active while the V2 UV policy owns those materials | Verify the original defaults in the live restoration record and retain exact map/finish comparisons | Original failed run retained; corrected diagnostic separately rerun |

No geometry, atlas pixels, catalogue keys, collision boundaries, wall-placement
law or mechanical/save authority changes. Initial world construction remains
synchronous. Additional cooperative work preserves exact original fitting
outputs and wrapper finishing; its elapsed reconstruction time may increase.

The single-atlas cache verifies the source PNG's complete raw SHA on every use.
It also hashes the LF-normalized import sidecar and every referenced imported
payload in full. Cache reuse requires unchanged signatures and an unchanged
Texture resource. Fresh loads repeat these checks afterward; a changed
generation is refused. An unverifiable import binding uses a fresh, uncached
load. There is no timestamp-only shortcut or skipped source validation.
Cold imports pay additional guard work. The retained1024×1536 RGB8 image with
all mip levels exposes6,291,453 bytes; this is image data, not a claim that GPU
allocation and driver overhead have been separately measured.

The UV policy still changes the same live materials in place and restores
their original shared UV modes on teardown, preserving V1 rollback. Its ledger
no longer owns local shaders or their texture dependencies after geometry
retires. Pruning is constant work per newly corrected material, without a new
per-frame full scan. The11-check lifetime bench demonstrates the original
retention, new release,512 retired materials and restoration of three live
records. The existing UV application suite also passes. The16-check atlas
bench covers source/import/payload mutation, same-length changes, CRLF-only
sidecars, live Texture mutation, invalid dimensions, concurrent modification,
fallback behavior and actual imported-resource lifetime; component stderr is
empty. These are diagnostics rather than player-input proof.

Packet: **art/reviews/v2_portrait_reload_20261024/**. **before_v1** is the
instrumented original played baseline. **cached_v1** passes both timed routes
but fails the subsequent dormant-texture release assertion; it is not a full
pass. **weak_policy_v1** fixes that release and passes the timed route but
fails nine stale catalogue-default assertions in the untimed portrait validator.
The paper PBR assertion was also migrated from an older no-map expectation to
the production paper roughness/normal maps that were already installed. No
production maps were removed to satisfy historical tests. Raw sources, original
failures, stderr and wrapper receipts remain in the packet.

**final_v1** completes with exit0 in its wrapper receipt:54 timed waypoints,
14 route checks,58 total waypoints,6,586 untimed lighting checks and369 portrait
checks, with0 failures. Seven card views and the context view were rendered and
reviewed. Cache release frees the dormant atlas; a subsequent forced cold reload
returns78.983ms. All imported roots/meshes retire and pending requests return0.
The existing seven Texture RID teardown warnings remain; this is not a claim
that every resource leak has been removed.

| Same settings and inherited played route | Original before_v1 | Final final_v1 |
|---|---:|---:|
| Frame interval p50 / p95 / p99 / max, ms |24.658 /38.940 /51.880 /182.896 |24.685 /39.099 /50.872 /167.109 |
| Frame intervals above100ms |2 |3 |
| LOADING interval p99, ms |65.684 |51.528 |
| Peak main-thread residency stage, ms |62.933 |39.426 |
| Warm portrait wrapper calls, ms |61.735 /61.021 |32.964 /35.146 |
| LOADING endpoint interval sums per cycle, s |10.590 /10.482 |11.363 /11.003 |

The earlier same-production-source **weak_policy_v1** timed trace gives loading
p9951.916ms but whole-route max216.265ms and five intervals above100ms. The final
repeat does not establish a reliable whole-route tail improvement: median is
unchanged and the count above100ms rises versus baseline. The measured local
reload/loading-tail benefit trades roughly0.5–0.8s of background reconstruction
for shorter work slices. Faster approaches remain unqualified. Cold startup's
portrait fit also costs more because import generation is checked twice.

These are post-render signal intervals, not measured display/input latency.
State is assigned at interval endpoints; transitions can straddle states.
The largest final167.109ms interval includes155.343ms render submission/wait
and83 surface/96 specialization compilation increments. A153.819ms nave turn
contains145.917ms render submission/wait without compilation increments.
The106.489ms loading interval contains78.150ms outside the observed callback
spans. That time is unclassified; no claim attributes it solely to GPU, scripts,
asset IO or the physics solver. Physics callbacks peak25.285ms and include
nested gameplay/save work. Instrumentation separates native fitting, asset fetch,
texture load, source/import hashing, surface application, scripts/physics
callbacks and renderer submission, but it is not an exclusive GPU/CPU profiler.

No space is promoted and the broader started-work closure queue remains open.

Full board **gates/board.json** runs110 gates:101 PASS,8 FAIL,1 INCOMPLETE,
including98 tools suites/1194 tests. Its only new regressions are two added
locksmith/laundry test asset-path records. The first selective-registration
attempt safely refuses mismatched gate defect fingerprints; no manifest change
occurs. A full repeat had already launched before the corrected registration.
The complete repeat **gates_final/board.json** likewise has only those same
three spatial comparison messages; it finishes all98 tools suites and1194 tests.
Only the two live TEST_CONTRACT / UPDATE_TEST_FIXTURE asset records are then
appended, with the shared bathroom records left unstaged. The focused board
**gates_spatial_final/board.json** compares with exit0/no regressions and restores
8 failing/39 advisory spatial findings. It runs only spatial; other gates are
reused from the full board, not presented as rerun by that focused check.
Existing reader1141 unread/33 NEW, systemic26, physical imports wrong4, stale
surface qualifications2 and ledger240/blockers7/8/110/42/134/136 remain. No field
baseline or evidence status is relaxed. requirements_changed stays empty.

All nine executed top-level sources match retained archives/current source;
final source archives bind raw bytes and LF-normalized text. Protected17/17
match the previous checkpoint. Packet hashes are integrity diagnostics, not a
reconstruction of every unrelated dirty-world input. Changes outside the
production boundary are the new component benches, migrated historical
portrait diagnostic, two explicit test asset records, issue log and evidence.

Worktree clean at end: no; shared work remains. Protected17/17 and selector V2
with explicit V1 rollback must remain unchanged. No clean merge-base candidate
verification is claimed. Decision needed from owner: none.

Remaining: first-render compilation, renderer submission/waits, other atomic
fittings, startup, faster approaches and the outstanding hose/books/device/bath/
street/avatar qualification in **V2_STARTED_WORK_CLOSURE_2026-10-23.md**.

MERGE-CANDIDATE this source checkpoint; diagnostic scope only
