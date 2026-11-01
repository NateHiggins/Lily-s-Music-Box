Evidence class: **INERT**

# Project size: a safe plan

For Lily, 2026-10-31. Task **K-OPS-SIZE**. Only the worktree sweep in section 2 has happened. Everything
else waits for approval.

## 1. Where the space is

The project took about 480 GB of drive C: before the sweep. The game itself is a small part of it.

| Place | Size | What it is |
|---|---|---|
| `C:/ov` | 241 GB | Worktrees (150), `reports` (46), scratch and old archives |
| `.claude/worktrees` in the main checkout | 56 GB | Four worktrees |
| `tmp/` in the main checkout | 50 GB | 306 ignored scratch folders of old captures |
| `.git` | 47 GB | History: 18 GB packed, 28 GB loose, 85,000 loose objects |
| `.codex/worktrees` | 44 GB | Codex's two worktrees |
| `art/` | 25 GB | 17 GB tracked, 8 GB ignored Blender and working files |
| `game/` | 16 GB | 8 GB `.godot` cache, 5 GB assets, 3 GB `game/tmp` |
| `C:/devkit/imagegen` | 12 GB | The local image model. Keep |

**The tracked tree is why every worktree costs over 21 GB.** It holds 70,805 files and 22.6 GB. The game
needs about 4 GB of that.

| Tracked | Files | Size |
|---|---|---|
| `art/reviews` | 27,300 | 7.1 GB |
| `art/renders` | 18,279 | 6.2 GB |
| `design/astra/evidence` | 7,075 | 1.4 GB |
| `.log`, `.stderr` and `.gz` anywhere | 12,138 | 0.5 GB |
| `game/` | 10,963 | 4.1 GB |

So review captures, renders and run logs make up most of the file count, and they are written once and rarely read.

## 2. Done: the worktree sweep

Six worktrees were removed. Each was checked first: its head is on a remote ref and it holds no real
change except deleted files. Any ignored or untracked file that isn't a cache, and isn't identical in
the main checkout, moved to `C:/ov/workspace-archive-20261031/<name>/` with a sha256 manifest.

- `C:/ov/c-209a32a9`, `C:/ov/c-4d26087a`: verifier leftovers from a run that died.
- `C:/ov/paper`, `C:/ov/myst`: this session's finished work, merged.
- `confident-shirley-3e7723`, `lily-fern-voice-guide-a163f9`: merged, and no open session uses them.

**Kept on purpose:**

- `xenodochial-clarke-9392ac` and `friendly-easley-282bd0` (42 GB). Open sessions still sit in them, and
  removing one means archiving its session, which is Lily's call.
- `C:/ov/bodies` (25 GB). It holds real uncommitted edits to ten resident routines. Not stale until those are
  saved or dropped.
- `C:/ov/city` and Codex's worktrees. Codex was active in `city` today.
- `C:/ov/shops`. Slices 4 to 6 are still running there.
- Four dead entries in git's worktree list point at Codex paths that no longer exist. They take no space, and
  they're locked, so Codex's owner decides.

## 3. The plan

Each tier is safer than the next and stops on its own. Nothing is deleted before it has a manifest, and
nothing touches the three rules below.

**Never without a named ruling.** The 17 protected paths and selector rollback (**RUL-004**). The hash-bound
floor 01 artefacts and anything listed `-text` in `.gitattributes`. Evidence documents and receipts the
completeness ledger reads (**RUL-003**, **RUL-011**). Files a tool, test or committed document cites. The shared
stash, the main checkout's dirty state and anyone else's branches (**RUL-010**).

### Tier 1: local scratch. No repository change. About 90 GB

1. **`tmp/` in the main checkout (50 GB) and `game/tmp` (3 GB).** Ignored. Check citations with `git grep -F`
   for each folder name. Compress cited folders to one archive and move the rest to an archive on another
   drive for 30 days, then delete on your say. Codex may be using recent ones, so anything touched in the last
   14 days stays.
2. **`C:/ov/reports` (46 GB).** The same treatment. It's mostly captures of work that has since merged. This
   session's reports go first. A sweep manifest records what left.
3. **`C:/ov` loose files and old archives** (`envimpl_out`, `workspace-archive-20261020` and others). Citation
   check first, as on 25 October: four evidence folders there are cited by committed documents and stay.
4. **`.git` housekeeping.** Run `git gc` in a merge hold, because agents share this store. It should pack the
   28 GB of loose objects well, and it clears 59 garbage files (365 MB) and stale `index.lock.*` files. No
   history changes. Estimated saving 10 to 25 GB; the true figure comes from the run.

### Tier 2: lighter worktrees. Small tool change. About 15 GB per worktree

Use git's sparse checkout so agent and verifier worktrees skip `art/reviews`, `art/renders` and
`design/astra/evidence`. Those files stay in the repository and the main checkout keeps them. A 21 GB worktree
drops to roughly 7 GB, and to tens of thousands fewer files, which also speeds up `--import` and `git status`.

Prove it first: run the gate board and a route suite in a sparse worktree against one full worktree. If any
gate reads a skipped path, that path goes back in. Fix the verifier so a crash can't leave a worktree behind
(section 2's two leftovers cost 42 GB), and add a `tools/sweep_worktrees.py` that reports stale ones.

### Tier 3: fewer tracked files. Needs your approval by class. About 14 GB and 50,000 files at the tip

For each file in `art/reviews`, `art/renders`, `design/astra/evidence` and the tracked logs, classify:

- **Cited or hash-bound:** stays exactly where it is. 188 design and tool files cite `art/renders/orison_v2`
  alone, so expect a good share to stay.
- **Uncited, superseded captures:** pack per review folder into one `tar.zst`, in a separate archive store (a
  GitHub Release on this repo or a second drive), with a sha256 manifest committed in its place.
- **Duplicate zips of folders also tracked** (`art/reviews/city_streets_20261029` holds several at 80 to 95 MB):
  keep one form.

New rule, held by a gate: new review output goes to the archive store, not the tree, with a size budget per PR.
Also reviewed one by one: `Godot_v4.7.1-stable_win64.exe` and a screen recording in the root (both ignored
and local), and the side projects tracked here (`nomoretears` 123 files, `audio_virus_prototype` 32,
`legacy_mobile_mvp` 20), which could move to their own repositories.

Note the cost: the runtime receipts digest some of these files, and **design/** documents are evidence. Anything
the ledger reads gets re-earned or stays. The classification reports this before anything moves.

### Tier 4: rewriting history. Not recommended now

Only this shrinks the packed 18 GB. It rewrites every commit, breaks every open branch and every SHA cited in
receipts and rulings, and forces every agent to re-clone. Tiers 1 to 3 win far more for far less. Reconsider it
only at a release, with a full mirror kept offline.

## 4. Expected result

| After | Project on C: | Worktree | Tracked files |
|---|---|---|---|
| Now | about 480 GB | 21 GB | 70,805 |
| Sweep (done) | about 375 GB | 21 GB | 70,805 |
| Tier 1 | about 285 GB | 21 GB | 70,805 |
| Tier 2 | about 230 GB, depending on live worktrees | 7 GB | 70,805 |
| Tier 3 | less again, measured by the classification | 7 GB | about 20,000 |

Tier 1 and 3 figures are estimates until the citation checks run, and could fall well short if much is cited.

## 5. Decisions for the owner

1. **Approve tier 1?** Recommended first. Where should the 30-day archive go: drive D: or a second drive?
2. **Approve tier 2?** Recommended next. It removes nothing.
3. **Tier 3:** approve the classification run, which changes nothing. Moving files comes back to you with its list.
4. **The two open sessions (42 GB):** archive them? Their work is merged.
5. **`C:/ov/bodies`:** save its routine edits to a backup branch and remove it, or leave it?
