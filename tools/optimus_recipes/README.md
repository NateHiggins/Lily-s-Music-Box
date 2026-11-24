# Optimus recipes

Order **w56fcf305624f** (Optimus B), under Lily's ruling **optimus_scope_20261112**. Optimus may run named
repository jobs. Its results are pre-checks only; the gate still runs on this PC. Each file here is one recipe
that Optimus's worker may run. The worker runs nothing outside this list: a job names a recipe and a commit,
never a command line. Adding or changing a recipe is a change to this folder plus a worker update, and
Optimus's custodian deploys it.

## Recipe manifest (`<recipe>.json`, schema `optimus.recipe.v1`)

| Field | Meaning |
|---|---|
| `recipe` | Name; must equal the file stem. |
| `role` | Always `precheck`. A recipe never produces a canonical gate result. |
| `source.tree` | `whole` (the commit's full tree, binaries included) or `text` (no binary files). |
| `tools` | Tool names the worker resolves from its own pinned toolchain table, e.g. `python`. Each resolved executable's sha256 goes in the receipt. A tool that is missing or has the wrong hash refuses the job. |
| `argv` | Fixed argument list, run from the checkout root. `{python}` and the other tool names resolve as above. `{out}` is the job's private output folder. Nothing else is substituted. |
| `env` | Fixed extra environment. The worker also sets an isolated profile (`APPDATA`, `TEMP`, `HOME`) per job. |
| `timeout_seconds` | Hard ceiling. A run past it is killed and reported as `timed_out`. |
| `outputs` | File names under `{out}` returned with the receipt. Each gets its sha256 and size. |
| `needs` | `ram_gb`, `disk_gb`, `gpu` (bool). The worker refuses a job it cannot host rather than pre-empting anything. |
| `exit_meaning` | How to read the exit code, for the reader of the receipt. The worker records the exit verbatim either way. |

## Job

`{"kind": "recipe", "recipe": "<name>", "commit": "<40-hex>", "id": "<job id>"}` and nothing else.

## Receipt (`optimus.cpu-precheck.v2`, a superset of v1)

These fields are kept from the 11-11 v1 receipt:

- `host`, `job_id`, `recipe`, `commit`
- `python_sha256`, `worker_sha256`, `recipe_runner_sha256`
- `started`, `finished`, `exit_code`, `timed_out`
- `peak_process_rss_bytes`, `gpu_used`, `peak_process_vram_bytes`, `vram_measurement`
- `profile`, `source`, `log_sha256`, `log_bytes`
- `role`, `canonical_gate: false`

New in v2:

- `manifest_sha256`: the LF-normalised recipe file at that commit.
- `source_route`: `fetch`, plus `source_tree_sha` (the checked-out tree's id) and `source_kind` (`whole` or
  `text`).
- `tools`: `{name: {path, sha256, version}}`.
- `outputs`: `[{name, sha256, bytes}]`.

## Source

Lily ruled **optimus_source_route_20261124**: Optimus keeps its GitHub sign-in, and jobs fetch exact commits
from origin into a clean worktree of its existing clone (E:\PleaseStayOnTheLine). The worker:

1. runs `git fetch origin <commit>`;
2. runs `git worktree add --detach <job dir> <commit>`;
3. confirms `git rev-parse HEAD` equals the job's commit;
4. runs the recipe;
5. removes the worktree afterwards.

A `text` recipe may use a sparse checkout that leaves out binary files; a `whole` recipe checks out
everything. The clone's history must be complete: one tools test (`test_m11c1_owner_first_export`) reads an
older commit's tree.

One heavy job at a time on this host (Claude@Optimus's host receipt: gate_board takes about 9 minutes and
false-timed-out when run alongside other heavy work).

## Acceptance

A recipe is accepted when the outputs Optimus produces for a commit match a run of the same recipe on this PC
at the same commit, compared as the recipe's `acceptance` field says. The receipt must be complete. For
`gate-board-static`, every gate's id, exit, severity, counts and defects must agree with a board made here.
`created_utc`, `elapsed_s` and the `python` path may differ.

## Evidence for gate-board-static

On iApricot, gate_board ran in a fresh checkout of f736d3494 made from a git bundle, with no history beyond
the snapshot. It was compared with Codex's board of the same commit made in the normal checkout. Evidence is in
D:/ov_reports/optimus_b_20261124/full_f736.

- 157 of 161 gates matched exactly.
- The ledger, rulings and test_orison_v2_completeness hit the 600 s gate ceiling while the disk was shared with
  another checkout. Run alone, the ledger took 161 s with exit 2 (as on main) and rulings took 103 s with
  exit 0.
- test_m11c1_owner_first_export needs history the snapshot did not carry. A full clone has it.

A text-only checkout matched only 118 of 161 gates: the ledger, surface, arcade and newspaper gates read
binaries. So gate-board-static is `whole`.
