# Room gate pre-commit hook — opt-in usage and installation

`tools/room_gate_hook.py` runs the room reconstruction gate
(`tools/room_reconstruction_gate.py`) against the **exact staged Git
index** before a reconstruction commit.  It is strictly opt-in: nothing in
the repository installs, activates or modifies any hook, and the runner
never changes the index, the working tree, Git configuration or `.git`.

## Why index truth

A pre-commit check must verify the snapshot Git is about to commit — not
the working tree (which may hold unrelated or partially staged edits), not
HEAD, and not a changed-since range that misses newly staged content.  The
runner therefore materializes the index itself and gates that.

## What triggers it

Only room-reconstruction inputs staged in the index:

- `design/ORISON_*CHECKPOINT*.md`;
- `design/**` `*.decisions.json` / `*.evidence.json` manifests;
- the authoritative layout/generator inputs
  (`art/data/building_layout.json`, `art/data/gen_layout.py`,
  `game/data/building_layout.json`);
- spatial-tool sources (`tools/room_*.py`, `tools/audit_orison_rooms.py`).

Anything else staged — renders, audio, scenes, docs — is ignored, and with
no relevant staged path the hook skips cleanly (exit 0).  A staged
**deletion** of a checkpoint or manifest blocks as a mandatory review
condition; unstage it or commit only after deliberate review.

## Staged-snapshot design

The index is exported with `git ls-files -z | git checkout-index -z
--stdin --prefix=<snapshot>/` for everything the gate reads — `design/`,
`art/data/`, `game/data/`, `game/scripts/`, `game/docs/`, `tools/` and the
checkpoint evidence root `art/renders/orison_room_reconstruction/`
(~120 MB of exact index content, a few seconds).  The remaining
`art/renders/*` subtrees (~4 GB of unrelated render history) are bridged
into the snapshot as directory links (junctions on Windows); any
index-vs-worktree divergence under `art/renders` is detected with
`git status --porcelain` and reported as a warning.  `.git` is never
copied or exposed, no checkout/reset touches the real worktree, and the
snapshot is deleted afterwards (links detached first) unless
`--keep-snapshot`; if cleanup fails, the exact path is reported instead of
force-deleting an uncertain target.

The gate then runs as a subprocess against the snapshot
(`--repository-root <snapshot> --no-git`), preferring the **snapshot's
own** `tools/room_reconstruction_gate.py` so staged tool changes gate with
their staged versions (the summary states which tool source ran).

## Selection

Staged checkpoints and manifests are gated **strictly** (the gate's
repeatable `--checkpoint`), each joined by its same-stem sibling
`.md`/`.decisions.json`/`.evidence.json` documents already in the index.
When only layout/generator/tool inputs are staged, a **whole-corpus safety
gate** runs instead and the output says plainly that no new checkpoint
accompanies the change — it never pretends a strict checkpoint gate
occurred.

## Exit policy

| Situation | Hook exit |
|---|---:|
| nothing relevant staged | 0 (skip) |
| gate LANDABLE (0) or LANDABLE_WITH_SYMBOLIC_EVIDENCE (2) | 0 |
| gate blocked 1 / malformed 4 / both 5 / internal 70 | same code |
| staged checkpoint/manifest deletion | 1 |
| untrustworthy snapshot (missing/unreadable staged layout, export failure) | 70 |
| usage/configuration error (not a repo, bad flags) | 3 |
| `--advisory` (explicit, clearly labelled in output) | always 0 after reporting the real result |

The terminal summary is concise: staged relevant paths, selection,
snapshot source and tool provenance, gate result + exit, up to eight
blockers with next actions, symbolic-debt count, warnings, the preserved
packet location, and an explicit statement that the real index and
worktree were unchanged.  `--verbose` appends the gate's own output;
`--keep-packet <dir>` chooses where the full packet (with
`components/`) lands; `--no-color` disables the ANSI verdict colour.

## Opt-in installation (manual recipe — preferred)

Print the sample hook (installs nothing):

```bash
python tools/room_gate_hook.py --print-hook
```

To install, **check you have no existing pre-commit hook first**, then
write the sample to `.git/hooks/pre-commit` yourself:

```bash
test -e .git/hooks/pre-commit && echo "HOOK EXISTS - do not overwrite" \
  || python tools/room_gate_hook.py --print-hook > .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit    # POSIX; not needed on Windows Git
```

To try it gently first, edit the hook line to
`... room_gate_hook.py --advisory` — it reports the real gate result but
never blocks.  To uninstall, delete `.git/hooks/pre-commit` (or restore
your previous hook).  To bypass once, use `git commit --no-verify` —
the gate is a tool for the developer, not a lock against them.

No installer script is provided on purpose: a two-line manual recipe is
safer than installer machinery, cannot clobber an existing hook, and makes
the opt-in explicit.

## Limitations

- Evidence outside `art/renders/orison_room_reconstruction` is bridged
  from the working tree, not the index; divergence there is detected and
  warned about, not resolved.
- The corpus-safety mode for layout-only commits inherits the corpus
  policy: historical debt is reported, not blocking.
- Landability remains layout-and-artifact truth; visual, interaction and
  historical correctness stay human judgments.
- The hook runs the gate in a subprocess (~5–20 s on the real corpus);
  `--advisory` is the right mode for anyone who finds that too slow to
  block on.

## Tests

```
python tools/tests/test_room_gate_hook.py
```

24 tests in temporary Git repositories (never the real one): clean skip,
unrelated staged files, newly added and modified staged checkpoints,
staged manifests pulling sibling documents, staged deletions blocking,
layout-only corpus safety, unstaged edits excluded, staged-vs-worktree
divergence with the staged version winning, exits 0/1/2/4/5/70, advisory
mode, untrustworthy snapshots, packet preservation, snapshot cleanup and
`--keep-snapshot`, byte-identical index/worktree/status before and after,
repositories with spaces in their paths, pre-first-commit repositories,
snapshot-tool provenance, `--print-hook` installing nothing, deterministic
normalized output, and the gate's repeatable `--checkpoint` selection.
