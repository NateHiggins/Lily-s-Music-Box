# Editorial-pass proof renewal, 2026-10-22

Evidence class: **INERT**. Original wrapper receipts, compressed raw logs,
archived previous packets and board comparisons. Runtime proof lives only in
the test-written contracts installed under `art/renders/orison_v2/`; nothing
here grants a requirement status.

Why: the editorial pass (`4caac77a`) and the title ruling (`54915ec3`, merged to
main as `a8b2c80c`) edited string literals in six GDScript files and four JSON
data files; main then moved to `975da382` (PR 13, resident conversations),
which is the tree every published receipt here binds to. The completeness ledger binds every runtime receipt, and the surface
qualification binds its review, to one digest over all scripts and data, so the
first-slice authority receipt, the upper-apartment/roof access cohort and the
composed surface qualification all expired. This folder records their
re-execution from a short-path worktree (`C:/ov/edproof`) after two `--import`
passes through the long runner.

Contents:

- `board_pre_edit_21f0b1fc.json`: main's clean gate board before the edits (the
  baseline the renewed tree is compared against).
- `board_after/`: the renewed tree's board and its comparison against that
  baseline.
- `ledger_delta.json`: ledger after renewal compared with the pre-edit ledger.
- `runs/`: every runner receipt (`*.log.receipt.json`) on `975da382` with
  gzipped stdout and stderr: two import passes, nine headless suites, the
  windowed first-slice run, three upper-cohort runs (`p2_upper` failed the
  tank-wheel direction check, `p2_upper2` a lift-drive walk target,
  `p2_upper3` passed; nothing PR 13 touches lies on those paths) and two
  surface runs (`p2_surface` stopped at the fixture preflight before the
  frontage rebind, `p2_surface2` passed).
- `runs_pass1_a8b2c80c/`: the same programme first executed on `a8b2c80c`
  before PR 13 landed (first slice, upper cohort and eight headless suites
  passed; two surface attempts failed at the fire-hand cursor-warp step while
  the OS cursor was being moved). Superseded records, kept for the timeline.
- `frontage_regeneration.log`, `frontage_regeneration_comparison.json`: the
  owning Blender builder re-run that rebinds `orison_bodega_frontage.json`
  to the current `door_prop.gd`; asset bytes and the physical digest are
  unchanged.
- `previous_first_slice_packet/`, `previous_upper_packet/`,
  `previous_surface_packet/`: the packets that were current before this
  renewal, preserved byte-for-byte with publication manifests.

Known red retained, not repinned: `ServiceWireResponseTest` reads a property
removed from `MaintenanceShopCounter` on 2026-08-27 and hangs to the runner's
180 s ceiling (recorded as known red in
`design/ORISON_V2_INTERIM_MANAGEMENT_EVALUATION_2026-09-16.md`). Twelve of its
45 checks print before the crash; the edited sign-card text is never reached.
