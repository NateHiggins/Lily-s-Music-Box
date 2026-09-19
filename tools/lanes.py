#!/usr/bin/env python3
"""Every line of work in one table: worktrees and remote branches against main.

    python tools/lanes.py [--main origin/main] [--ledger] [--out DIR] [--json]

For each worktree: path, branch, HEAD, ahead/behind main, merged or not,
dirty path count, last commit date and subject.  For each remote branch
without a worktree: the same, minus dirtiness.  --ledger also runs the
completeness ledger inside each existing worktree (that tree's own ledger)
and records its six blocker counts, so "which lane moved the ledger" is a
column instead of an evening.

Every row gets a disposition, which is a suggestion for a person, never an
action:
  merged-clean      HEAD is in main and nothing is uncommitted: removable
  merged-dirty      HEAD is in main but the tree holds uncommitted work
  unmerged-stale    commits main lacks, last commit older than --stale-days
  unmerged-active   commits main lacks, recent
  missing           a registered worktree whose directory is gone (prunable)

Nothing here removes, prunes, fetches or checks anything out unless --fetch
is given, which runs `git fetch origin` first.  Exit 0 always (a report),
3 on usage error.
"""
from __future__ import annotations

import argparse
import datetime as _dt
import json
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
SCHEMA = "orison.lanes.v1"


def git(*args, cwd: Path = REPO) -> str:
    proc = subprocess.run(["git", "-C", str(cwd), *args], capture_output=True, text=True,
                          encoding="utf-8", errors="replace")
    if proc.returncode != 0:
        raise RuntimeError(f"git {' '.join(args)}: {proc.stderr.strip()}")
    return proc.stdout.strip()


def worktrees() -> list[dict]:
    rows, current = [], {}
    for line in git("worktree", "list", "--porcelain").splitlines() + [""]:
        if not line:
            if current:
                rows.append(current)
            current = {}
            continue
        key, _, value = line.partition(" ")
        if key == "worktree":
            current["path"] = value
        elif key == "HEAD":
            current["head"] = value
        elif key == "branch":
            current["branch"] = value.removeprefix("refs/heads/")
        elif key in ("detached", "bare", "locked", "prunable"):
            current[key] = value or True
    return rows


def remote_branches() -> list[dict]:
    out = git("for-each-ref", "refs/remotes/origin",
              "--format=%(refname:short)%09%(objectname)")
    rows = []
    for line in out.splitlines():
        name, sha = line.split("\t")
        if name.endswith("/HEAD") or name == "origin":
            continue
        rows.append({"branch": name, "head": sha})
    return rows


def commit_facts(sha: str, main: str) -> dict:
    behind, ahead = git("rev-list", "--left-right", "--count", f"{main}...{sha}").split()
    date, subject = git("log", "-1", "--format=%cI%x09%s", sha).split("\t", 1)
    return {"ahead": int(ahead), "behind": int(behind), "merged": int(ahead) == 0,
            "last_commit": date, "subject": subject}


def dirty_count(path: str) -> int | None:
    try:
        return len([l for l in git("status", "--porcelain", cwd=Path(path)).splitlines() if l.strip()])
    except RuntimeError:
        return None


def ledger_counts(path: str) -> dict | None:
    ledger = Path(path) / "tools/audit_orison_v2_completeness.py"
    if not ledger.is_file():
        return None
    proc = subprocess.run([sys.executable, str(ledger), "--root", path, "--json"],
                          capture_output=True, text=True, encoding="utf-8", errors="replace")
    try:
        return json.loads(proc.stdout)["summary"]["blockers_by_scope"]
    except (json.JSONDecodeError, KeyError):
        return {"error": (proc.stderr or "no JSON").strip()[-160:]}


def disposition(row: dict, stale_days: int, now: _dt.datetime) -> str:
    if row.get("kind") == "worktree" and not row.get("exists"):
        return "missing"
    if row["merged"]:
        if row.get("dirty"):
            return "merged-dirty"
        return "merged-clean" if row.get("kind") == "worktree" else "merged"
    age = now - _dt.datetime.fromisoformat(row["last_commit"])
    return "unmerged-stale" if age.days > stale_days else "unmerged-active"


def collect(main: str, with_ledger: bool, stale_days: int) -> dict:
    now = _dt.datetime.now(_dt.timezone.utc)
    rows = []
    wts = worktrees()
    seen_heads = set()
    for wt in wts:
        path = wt["path"]
        row = {"kind": "worktree", "path": path, "branch": wt.get("branch") or "(detached)",
               "head": wt.get("head", ""), "exists": Path(path).is_dir()}
        if wt.get("branch"):
            seen_heads.add(wt["branch"])
        rows.append(row)
    for rb in remote_branches():
        local = rb["branch"].removeprefix("origin/")
        rows.append({"kind": "remote", "path": None, "branch": rb["branch"], "head": rb["head"],
                     "exists": True, "has_worktree": local in seen_heads})

    def fill(row):
        if row["head"]:
            row.update(commit_facts(row["head"], main))
        if row["kind"] == "worktree" and row["exists"]:
            row["dirty"] = dirty_count(row["path"])
            if with_ledger:
                row["ledger"] = ledger_counts(row["path"])
        row["disposition"] = disposition(row, stale_days, now) if "merged" in row else "missing"
        return row

    with ThreadPoolExecutor(max_workers=8) as pool:
        rows = list(pool.map(fill, rows))
    order = {"unmerged-active": 0, "unmerged-stale": 1, "merged-dirty": 2, "missing": 3,
             "merged-clean": 4, "merged": 5}
    rows.sort(key=lambda r: (order.get(r["disposition"], 9), r["kind"], r["branch"]))
    return {"schema": SCHEMA, "main": main, "main_commit": git("rev-parse", main),
            "created_utc": now.strftime("%Y-%m-%dT%H:%M:%SZ"), "rows": rows,
            "counts": {d: sum(1 for r in rows if r["disposition"] == d) for d in order}}


def render(report: dict) -> str:
    lines = [f"# Lanes against {report['main']} ({report['main_commit'][:12]})", "",
             f"created {report['created_utc']}", "",
             "| disposition | count |", "|---|---:|"]
    lines += [f"| {k} | {v} |" for k, v in report["counts"].items() if v]
    lines += ["", "| disposition | kind | branch | ahead | behind | dirty | last commit | ledger blockers | path / subject |",
              "|---|---|---|---:|---:|---:|---|---|---|"]
    for r in report["rows"]:
        ledger = r.get("ledger")
        ledger_text = ("error" if ledger and "error" in ledger else
                       " / ".join(str(v) for v in ledger.values()) if ledger else "")
        where = r["path"] if r["kind"] == "worktree" else (r.get("subject") or "")[:60]
        if r["kind"] == "remote" and r.get("has_worktree"):
            where += " (has worktree)"
        lines.append(f"| {r['disposition']} | {r['kind']} | {r['branch']} | {r.get('ahead', '')} | "
                     f"{r.get('behind', '')} | {'' if r.get('dirty') is None else r['dirty']} | "
                     f"{(r.get('last_commit') or '')[:10]} | {ledger_text} | {where} |")
    return "\n".join(lines) + "\n"


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--main", default="origin/main")
    parser.add_argument("--ledger", action="store_true")
    parser.add_argument("--stale-days", type=int, default=14)
    parser.add_argument("--fetch", action="store_true")
    parser.add_argument("--out")
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args(argv)
    try:
        if args.fetch:
            git("fetch", "--quiet", "origin")
        git("rev-parse", "--verify", args.main)
        report = collect(args.main, args.ledger, args.stale_days)
    except RuntimeError as exc:
        print(f"usage: {exc}", file=sys.stderr)
        return 3
    markdown = render(report)
    if args.out:
        out = Path(args.out)
        out.mkdir(parents=True, exist_ok=True)
        (out / "lanes.json").write_text(json.dumps(report, indent=1) + "\n", encoding="utf-8")
        (out / "lanes.md").write_text(markdown, encoding="utf-8")
    print(json.dumps(report, indent=1) if args.json else markdown)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
