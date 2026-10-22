# Retired stored-hose simulation diagnostics — 2026-10-22

Evidence class: **INERT**. Historical experiments and continuation only.
No installed hose deployment, water flow, runtime contract or human acceptance.

The owner directed that removing the hose from its rack replace the static
stored representation with a simple extended hose. The stored folds must not
run a hose simulation. The 610-section folded simulation is therefore retired.
Work on a separate, much simpler round hose continues independently. The
installed density, player-contact and step-query repairs remain in place.

| Location / reproduction | Severity / evidence | Repair / verification |
|---|---|---|
| 610-section stored cloth, 120-step floor release | High: the preceding release cost 5,070.653 ms total and peaked at 535.980 ms. | Trying global contact projection on the original target before the failed directional follower lowers the same isolated release to 2,781.597 ms total, max 248.226 ms. This is a solver diagnostic, not a world frame-time improvement. |
| Same release, friction and global-first projection | High: the first friction run fails at step 49 because velocity reprojection adds roundoff energy. | A velocity-only energy cap permits 120 steps: p50/p95/p99/max 10.800/57.240/102.811/120.520 ms, total 2,227.397 ms. This numerical PASS does not establish correct geometry. |
| Released native skin from that passing run | High: 115,404 crossing triangle pairs despite positive volume and zero nonmanifold edges. | Native classification identifies both local and nonlocal crossings. The original failed native batch and renders are retained. This candidate is not installed. |
| Pose-dependent anisotropic bend limits | High: the release fails at step 61, reaching its 32-response ceiling; max step 715.998 ms. | The partial native pose has 124,024 crossing triangle pairs. The failure remains historical evidence; this is not a completed repair. |
| Wide-precision continuation cache during held payout | High: no useful response improvement. | 224 cache reuses across 287 mouse events still yield pose-latency p50/p95/p99/max 4.118/8.804/321.082/325.835 ms. The cache was rejected and removed. Its source, DLL and manifest are retained. |
| Continued work on stored folds | Scope superseded by the owner's representation-swap direction. | Nine owned experimental runtime/build paths were archived byte-for-byte, then restored to pushed **69110c36**. The native source/binary binding was verified. The new round-hose work is separate and must qualify its own contacts, input, save behavior and water use. |

All times above come from isolated fixtures with the camera following and
player physics disabled. They do not replace the representative played-world
routes in **V2_HOSE_RESPONSIVENESS_2026-10-21.md** and
**V2_FIRE_PLAYER_CONTACT_2026-10-21.md**. No rendering, streaming or shader
improvement is inferred from these solver timings.

The exact original logs, wrapper receipts, solver records, native solids and
source snapshots are preserved under **art/reviews/v2_hose_friction_20261022**.
The archive manifest maps compressed files to original paths and SHA-256
digests. Gzip archives preserve bytes; original receipt contents are not repinned.
Wrapper receipts are **suite_run**, and Blender batch receipts are diagnostic.
Neither grants a runtime contract or a ledger promotion.

## Continuation report

Branch: **codex/v2-acoustic-topology**, canonical shared checkout.
Base pushed checkpoint: **69110c36**. Origin main / merge-base remains
**21f0b1fc27ac8e25c8466fe1ed2ce64019ee7ede**. No new worktree.
Named paths only; unrelated contributor changes are preserved.

Changes: retire stored-form simulation experiments; preserve their original
failures and source/binary versions. No experimental friction or directional
bend policy is installed by this archive. Full-length round hose removal,
handling and controllable spray remain active implementation work.

Tests: original isolated solver, actual-input and native geometry diagnostics
are retained with their original outcomes. Report-only archival changes do not
rerun those suites. The preceding complete clean-main gate baseline and the
non-green branch comparison remain in the preceding skin-repair report.

Open findings not fixed: arbitrary released cloth, installed hose removal and
save/rebuild qualification, working water supply/nozzle spray, renewed full V2
runtime cohorts, broader area coverage and human acceptance. The historical
seventeen protected paths and selector rollback are not changed here.

Decision needed from owner: none. The static-rack/simple-extended-hose direction
and controllable water spray are already authorized.

BLOCKED full V2 qualification remains incomplete; this is an INERT archive.
