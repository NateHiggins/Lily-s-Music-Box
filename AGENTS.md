# Working in this repository

Rules for every agent (Claude, Codex/Astra) and every person working in this
tree. They are the standing practice that was relearned the hard way. Where
a rule has an id (RUL-nnn), `design/RULINGS.json` has its source, and
`python tools/check_rulings.py --show RUL-nnn` prints it. For which document
wins a disagreement, read `DOCS.md` first: the Bible outranks everything here.

## Current checkout (2026-09-21)

The owner consolidated development into `C:/PleaseRemainOnTheLine` on
`main`. The former secondary checkouts are retired. Use this checkout for
normal development; clean up temporary verification checkouts after use.
See `design/WORKTREE_CONSOLIDATION_2026-09-21.md` for preserved work and recovery.

## Git in a shared tree (RUL-010)

- Several agents share this repository and its worktrees. Stage **named
  paths** only. Never `git add -A`, `git add .` or `git commit -a`.
- Never use a bare `git stash` or `git stash pop`; the stash stack is shared.
  Prefer a WIP commit.
- Godot rewrites `.import` files with line-ending-only changes on import.
  Check with `git diff --ignore-cr-at-eol --name-only` and restore them
  before committing. Never commit a `.uid` that `origin/main` already has
  under a different value.
- `core.autocrlf` is on for this machine. Anything hash-bound must be listed
  `-text` in `.gitattributes`, and any text you hash must be hashed
  LF-normalized, or a fresh checkout breaks it.
- Make fresh worktrees at short paths (`C:/ov/...`, `C:/orison-...`); deep
  paths break Godot's import cache.
- Branch from `origin/main`. main is the one integration line (RUL-002).

## The Godot lane (RUL-009)

- One Godot process at a time across every worktree. Run Godot only through
  `tools/run_godot_serial.ps1` (180 s ceiling), `tools/run_godot_long_suite.ps1`
  (1,500 s) or `tools/lane.ps1`. Never start Godot directly, and never close
  someone else's Godot process to free the lane.
- Exit 73 means the lane is busy and nothing started. Use
  `pwsh -File tools/lane.ps1 status` to see who holds it, and
  `tools/lane.ps1 run|batch -WaitMinutes N` to wait instead of failing.
- 124 means the runner killed a run at its ceiling. The suite reported
  nothing.
- A fresh worktree needs `--import` twice before any suite. "Nonexistent
  function" and "Could not find base class" in a fresh tree are a stale
  import cache, not a code bug; run receipts flag them.
- Screenshots need `-Windowed`; headless runs write no frames.
- Give every run a `-LogPath`. The runner then writes
  `<log>.receipt.json`; cite the receipt, not a typed exit code.

## Evidence and the ledger (RUL-003, RUL-011)

- The completeness ledger (`tools/audit_orison_v2_completeness.py`) admits a
  design document as evidence by its filename: an `ORISON_V2_*.md` carrying
  CHECKPOINT, GRAYBOX, ACCEPTANCE, RECEIPT, VERTICAL_CORE or
  SCHEMA_GENERATOR. Backticked ids in such a document can promote spaces.
- Every design document states its class in its first 30 lines:
  `Evidence class: **INERT**` for reports, briefs, dispatches and plans;
  a checkpoint or receipt names itself. The ledger refuses a marker-named
  document whose header says INERT. Inert documents write ids in **bold**.
- Before committing a design document, run
  `python tools/lint_design_doc.py <path>`; for an evidence document the
  lint also prints which requirement statuses it changes.
- Runtime proof comes only from a schema-2 `runtime_contract` receipt the
  test itself writes. A capture, a caption or a wrapper run receipt
  (`suite_run`) is not runtime proof.

## Gates and reports

- `python tools/gate_board.py --out <dir>` runs every static gate and every
  tools test and writes `board.json`. main is not green by design. The gate
  is `--baseline <main's board.json>`: nothing regressed.
- The reader gate holds new work to zero NEW unread fields:
  `python tools/audit_data_consumption.py --baseline`.
- Management verifies a candidate with
  `python tools/verify_candidate.py <sha> [--suite res://tests/X.tscn]`.
  For canonical-checkout work, add `--in-place --baseline-board <board.json>`
  with a complete clean board captured at the merge-base. This creates no
  secondary checkout. The verifier compares boards, checks the 17 protected
  paths and selector V2, and lints changed design documents.
- Reports use the section 7 format in
  `design/ORISON_V2_INTERIM_MANAGEMENT_DISPATCH_2026-09-13.md` and may add a
  committed JSON sidecar (`orison.dispatch-report.v1`, see
  `tools/PIPELINE_TOOLS.md`) that the verifier checks claim by claim.
- The owner authorized the selector's default V1-to-V2 change on 2026-09-21.
  Keep explicit `ORISON_BUILDING_ROOT=v1` rollback. The historical 17-path
  protected receipt stays unchanged; only the selector's default literal
  may differ at cutover. The other 16 paths and all other selector logic
  remain protected (RUL-004).

## Art

- No letters, numbers, words or logos in generated textures; lettering is
  Label3D. New material keys go through the catalogue (RUL-008).
- Reference photographs inform form only. They are never baked, projected or
  committed (RUL-007).
- Props are being regenerated in Blender (RUL-006). The prop script keeps
  every non-visual authority; generated glTF is never hand-edited.
- Verify by rendering, never by reading code.

## Tools

`tools/PIPELINE_TOOLS.md` describes the gate board, run receipts, the
candidate verifier, the design-doc lint, the lane broker, the lane ledger
and the rulings checker.
