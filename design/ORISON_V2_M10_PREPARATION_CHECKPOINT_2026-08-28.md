# Orison v2 M10 preparation checkpoint — 2026-08-28

## Decision

The explicit-v2 human packet is ready, but M10 is not accepted. K2 is
INCOMPLETE and K3 is INCOMPLETE (0/11). No automated result below substitutes
for either observation gate. M09, selector cutover, and v1 retirement remain
unauthorized.

## Selector and save isolation

`BuildingRootSelector.DEFAULT_ID` remains `v1`. The M10 launcher sets
`ORISON_BUILDING_ROOT=v2` only in its child process and restores the caller's
environment. It also redirects child-process `APPDATA` into a gitignored,
packet-local profile. K2 uses `k2`; K3 uses `k3_01` through `k3_11`. Selector
identity is not serialized and save version remains 4.

The launcher writes the exact full commit, Git tree, project SHA-256, selected
scene, save version, profile identity, and UTC launch time at execution. This
avoids a self-referential committed manifest and records the actual human build.

## Preflight

- Completeness: first slice exit 0; golden shift exit 2 with exactly
  `golden.eleven_beats`; production cutover exit 2 with 95 blockers.
- Spatial audit clean (588 records); spatial, prompt-carrier, and completeness
  unit tests pass 140/140.
- M08F passes 29 checks with no retained-object/resource exit warning.
- M08E collision-bearing traversal, M08A integration, save compatibility
  14/14, two-root matrix 24 checks/all four directions, first-shift custody,
  service round, golden loop 87/87, core loop, and dream boundary 39 checks pass.
- Explicit environment selection starts `orison_v2_runtime.tscn`; an unset
  selector starts v1. Review-only cues are absent by M08F runtime assertion.

The standalone first-shift-custody process still emits the pre-existing
four-ObjectDB/two-resource shutdown warning after a passing result. The complete
M08F lifecycle/teardown transaction exits cleanly; this warning is recorded as
non-human-gate debt rather than hidden.

## Preflight repair

The M08F hash assertion referenced uncommitted layout bytes rather than the
layout committed on origin/main. The assertion was narrowed to the canonical
committed SHA-256 `68838c...`; production layout content was not changed.

## Performance watch

M08F measured cold startup 564.810 ms, reconstruction 189.133 ms, warm CPU
0.619 ms, and an immediate physics sample of 25.940 ms. The earlier
26.6–31.6 ms reconstruction-adjacent spike therefore remains reproducible.
Human perceptibility, maximum, duration, and frequency remain pending K2/K3 and
must not be inferred from this single automated sample.

## Human gate procedure

Use `tools/run_orison_v2_m10.ps1`. K2 is one fresh uninterrupted curb-to-wake
run under the canonical printed card. K3 is eleven separate save/quit/relaunch
checks. Fill the packet receipts, hash each preserved save, and stop at the
first ambiguous K2 transition or first defective K3 reconstruction.

No PASS receipt exists. The completeness ledger must not be changed until both
genuine human gates return admissible evidence.
