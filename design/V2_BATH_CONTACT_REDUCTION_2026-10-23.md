# Bathroom contact reduction

Evidence class: **INERT**. Measured repair study, not V2 acceptance.

REPORT - fixed-bath-contacts - 2026-10-23

Branch **codex/v2-acoustic-topology**, parent **d88b4c14**. Canonical checkout
**C:/PleaseRemainOnTheLine**; unrelated spatial manifest and untracked street,
tent and traffic work remain preserved. Worktree is not clean. No requirement
promotion, clean candidate verification or human acceptance is claimed.

Origin/main **ad5b3899d532d2d0d7f0aecc7b344e5957040141**; merge-base
**21f0b1fc27ac8e25c8466fe1ed2ce64019ee7ede**. Protected 17/17 unchanged versus
parent; selector V2 retains explicit V1 rollback. Ledger counts were not rerun;
requirements_changed: [] (INERT documents do not promote requirements).
Focused gates retain reader33 NEW and four physical-import findings, with six
physical-import tools tests passing. Full board, completeness, spatial, systemic,
period and candidate verifier were not rerun; no green-main assertion is made.
Paths outside the narrow runtime repair are native owners, original diagnostic
packets, input synchronization in the existing toilet fixture and documentation;
they preserve the evidence and make the new contacts reproducible.

## Problem and change

Actual bathroom movement repeatedly takes hundreds of milliseconds per frame.
The retained v4 local exclusion diagnostic implicates detailed sink and toilet
fixed contact meshes; exact triangle chunking in v5 gives no steady query win.
See **V2_BATH_MOVEMENT_DIAGNOSIS_2026-10-23.md** for original failures and limits.

The native Blender sources generate separate hidden contact stock. The sink
retains 4,017 of 26,000 triangles. The final toilet retains 7,142 of 21,760
triangles. Visible geometry, UVs, finishes, glass, lights and articulated parts
are unchanged. Each accepted reduced mesh has bidirectional vertex/triangle
centroid distance samples no greater than 2 mm from its original native surface.
This is sampled error, not a formal whole-surface bound. Hollow castings remain
concave meshes; no convex fill or collision bypass is used.

The final native helper caches shape resources once per family and installs
them on the same fixed collision owners. Kitchen sinks retain their existing
collision path. Water, mechanism, care, NPC, inventory, case and save owners
are not replaced. All movable part targets and travel constraints remain.

## Repeatable comparison

**art/reviews/v2_bath_contact_20261023/world_v1/** uses the production occupied
world, 1280x720 Forward+, uncapped, VSync off, 60 Hz physics, the same 3B stance,
12 ticks each of A and D plus 48 paired turn events, and 240 physics ticks per
phase. Settle 20 ticks and eight rendered frames. Actual A/D
movement and paired mouse turns remain identical; captures and isolated queries
are outside samples. Original/candidate/restored contacts are interleaved in
one process, with ordinary collision protection enabled throughout.

| Phase | Frames | Wall p50 / p95 / p99 / max, ms | Frames >100 ms | Query median, ms |
|---|---:|---|---:|---:|
| Original | 28 | 168.657 / 245.080 / 477.013 / 477.013 | 28 | 8.807 |
| First reduced candidate | 54 | 65.669 / 122.432 / 137.124 / 141.805 | 6 | 2.219 |
| Original restored | 28 | 146.908 / 210.026 / 420.124 / 420.124 | 28 | 8.532 |

These exclude each phase's first incomplete wall sample. More candidate frames
occur within the same physics-tick interval. The original/restored difference
shows variability; the restored control nevertheless returns to severe stalls.
Maximum slide cost is 48.814 / 13.667 / 44.963 ms; these records include only
physics ticks exceeding one millisecond and are conditional distributions.
All phases end within .04 mm of each other.

Main render CPU medians are 28.223 / 25.309 / 25.000 ms; GPU medians are
27.033 / 17.705 / 31.407 ms. Render/process/physics monitors overlap and lag.
Surface pipeline count stays 325, while draw compilation rises 24 to 33 in the
first original phase and then stays 33. Restored stalls persist without that
compilation delta. Asset loading and streaming are not independently isolated;
no startup, general rendering or whole-world improvement is claimed. Substantial
rendering and remaining script/contact cost still prevent responsive frame times.

## Issue log and retained failures

| Location | Reproduction / severity | Evidence | Repair | Verification |
|---|---|---|---|---|
| 3B sink / toilet fixed collision | Standing A/D and turns; high | Original/restored route and v4 exclusions | Native contact reduction retaining hollow forms | Interleaved measured study; final installation check recorded separately |
| Lift rod guide | Free inspection pointer at discharge mechanism; high regression | First candidate yields 191 checks / four failures versus original 192 / three; trace hits **LiftGuide_001_Contact** | Preserve both thin **LiftGuide** meshes exactly | Corrected trace selects **FlushBall** and independent lift works; 192 checks / same three baseline failures |
| Existing toilet legacy suite | Door feedback / obsolete handheld layout assertions; existing failures | Original full-triangle control and final reduced-contact trace both fail the same three labels | Not hidden or reclassified as passes | Raw wrapper failure receipts remain; no whole-suite PASS claimed |
| Native candidate builder/reviewer | First builder references missing parent traversal API; first reviewer assumes a world resource | Original raw build and render logs retained | Traverse fixed owner's descendants; create review world when absent | Corrected native build and inspected front/back clay renders |

The three retained baseline labels concern rejected locked-door motion feedback,
one collapsed HUD line, and the device confined to the right third. These are
separate pending reconciliation under the current easy-door/physical-UI contract.
The failed legacy suite is not runtime qualification for this change.

The intermediate corrected-guide version retained 39 separate toilet shapes.
Its **world_v2/** control again gives original/candidate/restored query medians
8.595 / 2.019 / 8.614 ms and wall medians 150.869 / 58.705 / 148.789 ms. Its
candidate endpoint differs from the original by approximately .35 m, so final
camera visibility is different: those wall/GPU figures are not an identical-view
comparison. **installed_v1/** also has a changed endpoint; its 55.981 ms median
is an observation, not an independently matched before/after result. That run
passes all 17 sink checks: four actual valve grabs, motions and releases, valid
mechanism snapshots and clear exact plug targeting from a full-capsule stance.
No walked approach or full save reconstruction is established by those checks.

The final export retains the original three sink / five toilet shape grouping,
batching only fixed stock after native per-part reduction. It preserves the two
guides exactly. Intermediate source, native record and GLB remain under
**candidate_v3/**. Final comparison results are recorded separately; retain the
endpoint discrepancy rather than presenting only favorable timings.

## Final stock and remaining boundary

**world_v3.log.receipt.json** reports a completed 163-second diagnostic run,
**BATH CONTACT LOD STUDY: PASS**, followed by 17 successful ordinary installed
sink checks. This comparison reconstructs the old full-detail contacts locally,
uses the final reduced contacts, then restores the old contacts; diagnostic
stock is removed before the installed interaction checks. The retained production
owners use three / five shapes, matching the old family counts.

| Final phase | Frames | Wall p50 / p95 / p99 / max, ms | >100 ms | Query median, ms |
|---|---:|---|---:|---:|
| Original | 28 | 150.266 / 217.396 / 415.154 / 415.154 | 28 | 8.527 |
| Final reduced stock | 63 | 54.605 / 106.841 / 127.665 / 158.067 | 4 | 2.010 |
| Original restored | 28 | 146.115 / 214.446 / 417.865 / 417.865 | 28 | 8.612 |

The candidate endpoint is approximately .205 m from the original, despite the
same starting pose and input sequence. Original/restored endpoints differ only
about .1 mm. Thus the final moving camera follows a different path: collision
query reduction is directly established, but these wall/GPU improvements cannot
all be attributed independently to physics. Main render CPU remains approximately
24.5 ms in all phases; GPU medians change 32.07 / 16.61 / 31.02 ms with the changed
view. This is still poor responsiveness. Sparse 28-frame baseline tails provide
limited percentile resolution. Keep raw samples and continue longer actual routes.

**pick_trace_v3** retains an additional pointer timing failure: two distinct
window warps click the same stale ray. The fixture now waits for rendered-frame
cursor readback before clicking; it never overrides the authoritative ray or
target. Original fixture source is archived. **pick_trace_v4** reaches both
internal mechanisms and reports 192 checks / the same three original failures.
Its raw failure receipt is preserved; this is not a whole-suite PASS.

No final geometry or texture expansion is included. Reuse inspected native
geometry renders for unchanged fixed stock; the last export only batches its
collision partitions. Original visual GLBs and original native Blender files
are byte-identical to the parent. All 17 protected paths are unchanged after
LF normalization. Six physical-import tools tests pass; source retention keeps
only the four unrelated untracked street/traffic findings. Broader surface,
runtime, save/rebuild and human qualification remain incomplete.

The first candidate's toilet GLB, author script and construction record are
preserved under **candidate_v1/**. Final native renderings explicitly show hidden
contact stock, not new visible surfaces. The authoritative visual assets are
unchanged. All engine runs use shared-lane wrappers; their receipts are
**suite_run**, not test-written schema-2 runtime contracts.

Decision needed from owner: none. Continue existing measured repair scope.

BLOCKED broader V2 qualification and started-work closure remain incomplete
