#!/usr/bin/env python3
"""Read-only Git census. Rendered reports use this frozen, sorted input."""
from __future__ import annotations
import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
import os
from pathlib import Path
import subprocess


def git(repo, *args, check=True):
    proc = subprocess.run(["git", "--no-optional-locks", "-C", str(repo), *args],
                          capture_output=True, env={**os.environ, "GIT_OPTIONAL_LOCKS": "0"})
    if check and proc.returncode:
        raise RuntimeError(f"git {args}: {proc.stderr.decode('utf-8', 'replace')}")
    return proc


def out(repo, *args):
    return git(repo, *args).stdout.decode("utf-8", "replace").strip()


def parse_status(repo):
    raw = git(repo, "status", "--porcelain=v1", "-z", "--untracked-files=all").stdout
    parts = raw.decode("utf-8", "replace").split("\0")
    rows = []
    i = 0
    while i < len(parts) and parts[i]:
        val = parts[i]
        row = {"status": val[:2], "path": val[3:]}
        if "R" in val[:2] or "C" in val[:2]:
            i += 1
            row["original_path"] = parts[i]
        rows.append(row)
        i += 1
    return sorted(rows, key=lambda r: (r["path"], r["status"]))


def snapshot(repo, canonical, base):
    refs = []
    for line in out(repo, "for-each-ref", "--format=%(refname)\t%(objectname)\t%(committerdate:iso-strict)\t%(symref)", "refs/heads", "refs/remotes", "refs/tags").splitlines():
        fields = line.split("\t")
        name, sha = fields[:2]
        date = fields[2] if len(fields) > 2 else ""
        if not date:
            dated = git(repo, "show", "-s", "--format=%cI", sha + "^{commit}", check=False)
            date = dated.stdout.decode("utf-8", "replace").strip() if dated.returncode == 0 else ""
        if git(repo, "cat-file", "-e", sha + "^{commit}", check=False).returncode:
            refs.append({"ref": name, "hash": sha, "last_commit_date": date, "not_a_commit": True})
            continue
        behind, ahead = map(int, out(repo, "rev-list", "--left-right", "--count", base + "..." + sha).split())
        merge = git(repo, "merge-base", "--all", base, sha, check=False)
        refs.append({"ref": name, "hash": sha, "last_commit_date": date,
                     "symbolic_target": fields[3] if len(fields) > 3 else "",
                     "ahead_of_base": ahead, "behind_base": behind,
                     "merge_bases": merge.stdout.decode().splitlines(),
                     "tip_reachable_from_base": git(repo, "merge-base", "--is-ancestor", sha, base, check=False).returncode == 0,
                     "commits_outside_base": out(repo, "rev-list", "--reverse", sha, "--not", base).splitlines()})
    worktrees = []
    for block in out(repo, "worktree", "list", "--porcelain").split("\n\n"):
        row = dict(line.split(" ", 1) if " " in line else (line, True) for line in block.splitlines())
        worktrees.append(row)

    def inspect_worktree(row):
        path = Path(row["worktree"])
        if not path.exists():
            row["inspection"] = "PATH_MISSING"
            return row
        row["status_entries"] = parse_status(path)
        row["dirty"] = bool(row["status_entries"])
        row["tracked_changes"] = sum(r["status"] != "??" for r in row["status_entries"])
        row["untracked_files"] = sum(r["status"] == "??" for r in row["status_entries"])
        row["index_diff_sha256"] = hashlib.sha256(git(path, "diff", "--cached", "--binary").stdout).hexdigest()
        row["working_diff_sha256"] = hashlib.sha256(git(path, "diff", "--binary").stdout).hexdigest()
        if "m11c2-real-floor01-cut" in str(path):
            for entry in row["status_entries"]:
                file = path / entry["path"]
                if file.is_file():
                    with file.open("rb") as handle:
                        entry["sha256"] = hashlib.file_digest(handle, "sha256").hexdigest()
                    entry["size_bytes"] = file.stat().st_size
            row["provenance_note"] = "All present changed/untracked files hashed read-only; no bytes adopted."
        return row

    with ThreadPoolExecutor(max_workers=4) as pool:
        worktrees = list(pool.map(inspect_worktree, worktrees))
    outside = sorted({sha for ref in refs for sha in ref.get("commits_outside_base", [])})
    commits = []
    for sha in outside:
        fields = out(repo, "show", "-s", "--format=%H%n%P%n%cI%n%s", sha).splitlines()
        parent = fields[1].split()[0] if fields[1] else None
        paths = out(repo, "diff-tree", "--root", "--no-commit-id", "--name-only", "-r", sha, *( ["-m"] if len(fields[1].split()) > 1 else [])).splitlines()
        commits.append({"commit": sha, "parents": fields[1].split(), "date": fields[2], "subject": fields[3],
                        "changed_paths": sorted(set(paths)),
                        "containing_refs": sorted(r["ref"] for r in refs if sha in r.get("commits_outside_base", [])),
                        "parent_dependency": parent})
    stash = []
    for line in out(repo, "stash", "list", "--format=%gd\t%H\t%cI\t%s").splitlines():
        name, sha, date, subject = line.split("\t", 3)
        stash.append({"name": name, "hash": sha, "date": date, "subject": subject,
                      "changed_paths": out(repo, "stash", "show", "--include-untracked", "--name-only", name).splitlines()})
    protected = ["game/project.godot", "game/scripts/building/building_root_selector.gd",
                 "game/scripts/building/building_root.gd", "art/data/building_layout.json",
                 "game/data/building_layout.json", "game/data/acoustic_graph.json",
                 "game/scripts/game/reality_game_state.gd", "game/scripts/campaign/campaign_shell.gd"]
    protected_hashes = {}
    for path in protected:
        proc = git(repo, "show", f"{base}:{path}", check=False)
        protected_hashes[path] = hashlib.sha256(proc.stdout).hexdigest() if proc.returncode == 0 else None
    return {"schema_version": 1, "base_commit": base, "canonical_worktree": str(canonical),
            "canonical_branch": out(canonical, "branch", "--show-current"),
            "capture_policy": "Frozen read-only census; rebuild reports from this input without rescanning moving worktrees.",
            "remote_urls": out(repo, "remote", "-v").splitlines(),
            "refs": sorted(refs, key=lambda r: r["ref"]),
            "worktrees": sorted(worktrees, key=lambda r: r["worktree"]),
            "stash": stash, "commits_outside_base": commits,
            "protected_base_sha256": protected_hashes}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", type=Path, required=True)
    parser.add_argument("--canonical", type=Path, required=True)
    parser.add_argument("--base", required=True)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    if args.out.exists():
        raise SystemExit("Refusing to overwrite a frozen repository census.")
    payload = snapshot(args.repo, args.canonical, args.base)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(payload, sort_keys=True, indent=2) + "\n", encoding="utf-8", newline="\n")
    print(json.dumps({"refs": len(payload["refs"]), "worktrees": len(payload["worktrees"]),
                      "non_main_commits": len(payload["commits_outside_base"]),
                      "dirty_worktrees": sum(w.get("dirty", False) for w in payload["worktrees"]),
                      "output": str(args.out)}))


if __name__ == "__main__":
    main()
