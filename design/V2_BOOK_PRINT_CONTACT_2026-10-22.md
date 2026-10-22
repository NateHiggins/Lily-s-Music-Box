# Curved book print contact

Evidence class: **INERT**. Diagnostic repair report, 2026-10-22.
No runtime qualification or human acceptance.

Font triangles crossed native page-profile knots. Warping only their vertices
left triangle interiors beneath the bowed paper. Split font and illustration
streams at those knots once, then cache neutral transforms and share profile
samples while opening. Existing Label3D fonts, lighting, depth, cutout and
matte materials remain. No depth-test bypass or flattened paper is used.

| Location | Reproduction / severity | Evidence | Repair / verification |
|---|---|---|---|
| Library gathering | Open **missing** fully; medium, broken print | Original nine buried samples, minimum -43.618 micrometres; vertex-only checks missed it | Fit triangles to native strips; 30 titles at eight authored poses, 240 cases, minimum approximately +60 micrometres |
| First opening | First conforming candidate stutters; high | p95 50.952 ms, max 68.678 ms, eight frames above 50 ms | Cache samples/transforms; prepare hidden print during inspection; final p95 36.706 ms, max 47.712 ms, zero above 50 ms |
| Inspection entry | Preparation adds work; medium, open | Final p95 18.119 ms versus 15.345; max 49.416 versus 40.622 | Explicit tradeoff: preparation CPU 25.487 ms across frames, largest slice 5.895 ms, elapsed latency 180.573 ms |

The 2 ms budget is checked between font fields, not a hard per-frame ceiling.
A single field and final upload can exceed it. Newly created mesh RIDs are
owned immediately, including across yields. Print appears after all streams
are ready. Preparation occurs once per book; reopening reuses it.

## Played comparison

Same 1280 by 720 Forward+ world, uncapped, VSync off, RTX 4080, three nook
waypoints, actual pickup, Space, free cursor cover grip, mouse opening to pi
and next-click release. **world_before_v3** uses the exact preceding book
script; **world_after_v1** is the rejected conforming candidate;
**world_after_v2** is final. Source swaps were hash-guarded and restored.
Captures are outside timed phases. Action/boundary frames remain included.

| Phase | Before p50 / p95 / p99 / max ms | Final p50 / p95 / p99 / max ms |
|---|---|---|
| Enter inspection | 10.753 / 15.345 / 36.386 / 40.622 | 10.915 / 18.119 / 38.763 / 49.416 |
| First opening | 10.500 / 36.524 / 44.782 / 49.510 | 11.011 / 36.706 / 46.222 / 47.712 |
| Open, stationary | 10.529 / 14.708 / 16.006 / 16.221 | 10.534 / 14.111 / 15.824 / 17.239 |

All three final phases have zero frames above 50 ms. Opening still has ten
frames above 33.333 ms versus nine. This fixes contact/readability at near
baseline opening cost; it is not a general performance win. The representative
spread increases from 1,596 to 3,960 print triangles, 2,664 to 5,028 vertices.
Native physical geometry is unchanged.

**summarize.py** reproduces distributions, spikes, boundary samples, process,
physics, render CPU/GPU, pipeline and residency observations from retained
frame data. Counters overlap/lag and are not additive attribution. One baseline
and two candidates, no A/B/A; adaptive actual mouse cadence can vary. Cold I/O,
shader compilation and cross-cell streaming are not isolated. Startup remains
approximately 108-114 seconds. No broad world or cold-start win is claimed.

## Continuation report

REPORT - V2 book print contact - 2026-10-22.
Branch **codex/v2-acoustic-topology**; preceding HEAD
**48da899cac8565f69ab1ca264716e84e2be93ec0**; origin/main and merge-base
**21f0b1fc27ac8e25c8466fe1ed2ce64019ee7ede**. Canonical checkout, no new
worktree. Named staging only. Four earlier hose WIP files and unrelated
untracked files remain outside this checkpoint. Protected 17/17 unchanged;
V2 default and explicit V1 rollback unchanged.

Final **final_all_v1**: BOOK PRINT CONTACT PASS, 721 checks, zero failures.
**final_hand_v1**: BOOK SLOT HAND DIAGNOSTIC PASS, 76 checks, empty failures.
**final_nook_v1**: V2 NOOK LIBRARY BENCH PASS, 3,414 checks, zero failures.
**world_after_v2**: three waypoints, zero failures. Four stderr files empty;
wrapper receipts completed exit zero. Actual-input checks include pickup,
held view, wall blocking/reticle, Space, free cursor grip, cover movement,
physical limits, release, zoom and saves. They do not qualify the hose or V2.

Final focused source board passes physical imports, spatial, reader (zero
NEW unread fields) and four nook source tests. Exactly one print-camera
diagnostic dependency registered **TEST_CONTRACT / UPDATE_TEST_FIXTURE**;
seven prior report-only references remain. Native source bindings rebuilt in
one Blender batch. Exported nook glb and copy JSON byte-unchanged; reuse prior
native geometry/UV/PBR/mipmap checks and review new Godot print captures.
No new textures/material keys. Generated assets were not edited manually.

Prior full/effective gate comparison retained at
**art/reviews/v2_nook_revamp_20261022**: 107 PASS, two FAIL, one INCOMPLETE.
Only affected source gates and diagnostics rerun here; no new full board or
management candidate. Completeness statuses and expired surface/render
qualification remain open; no ledger promotion. New reports are inert.

Original parse-timeout **world_before_v1**, fixture assumption failure
**world_before_v2**, render controls and rejected slower **world_after_v1**
remain archived with original receipts. Wrapper **suite_run** is not a
test-written **runtime_contract**. Exact-byte archive manifest, selected
before/final captures and sources live under
**art/reviews/v2_book_print_contact_20261022**.

Remaining: inspection-entry/frame tails, wider world/cell coverage, installed
full-length hose aiming/spray/release/saves, renewed qualification and human
acceptance. Decision needed from owner: none.

BLOCKED - complete V2 and merge qualification remain incomplete; continue
authorized repairs.
