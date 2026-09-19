#!/usr/bin/env python3
"""Check design/RULINGS.json and every RUL-nnn citation in the repository.

Errors (exit 1):
  - schema: missing fields, bad id/date/authority, duplicate ids, ids out of
    order (the registry is append-only, so ids rise with position);
  - supersedes names an unknown id, or a later id;
  - a source path that names a file in this tree which does not exist;
  - a RUL-nnn cited in a tracked text file that the registry does not define.
Warnings (reported, exit unaffected):
  - a branch-qualified source (branch:<name>:<path>) whose branch or file
    cannot be found locally (fetch, or the branch was merged/renamed);
  - a cited ruling that a later ruling supersedes.

    python tools/check_rulings.py [--root .] [--json]
    python tools/check_rulings.py --show RUL-006     (the ruling and what cites it)
"""
from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

SCHEMA = "orison.rulings.v1"
REGISTRY = "design/RULINGS.json"
AUTHORITIES = {"owner", "astra", "management", "practice"}
ID_RE = re.compile(r"^RUL-\d{3}$")
CITE_RE = re.compile(r"\bRUL-\d{3}\b")
DATE_RE = re.compile(r"^\d{4}-\d{2}-\d{2}$")
PATH_TOKEN_RE = re.compile(r"(?:branch:(?P<branch>[^:\s;]+):)?(?P<path>[A-Za-z0-9_./-]+\.[A-Za-z0-9]+)")
TEXT_SUFFIXES = {".md", ".json", ".py", ".gd", ".ps1", ".txt"}


def git(root: Path, *args) -> subprocess.CompletedProcess:
    return subprocess.run(["git", "-C", str(root), *args], capture_output=True, text=True,
                          encoding="utf-8", errors="replace")


def check(root: Path) -> dict:
    errors, warnings = [], []
    try:
        data = json.loads((root / REGISTRY).read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return {"errors": [f"{REGISTRY}: {exc}"], "warnings": [], "citations": {}, "rulings": []}
    if data.get("schema") != SCHEMA:
        errors.append(f"{REGISTRY}: schema is not {SCHEMA}")
    rulings = data.get("rulings") or []
    ids, position = [], {}
    for index, entry in enumerate(rulings):
        rid = entry.get("id", f"#{index}")
        for field in ("id", "date", "authority", "summary", "source", "scope", "supersedes"):
            if field not in entry:
                errors.append(f"{rid}: missing {field}")
        if not ID_RE.match(str(entry.get("id", ""))):
            errors.append(f"{rid}: id must look like RUL-001")
        if not DATE_RE.match(str(entry.get("date", ""))):
            errors.append(f"{rid}: date must be YYYY-MM-DD")
        if entry.get("authority") not in AUTHORITIES:
            errors.append(f"{rid}: authority must be one of {sorted(AUTHORITIES)}")
        if rid in position:
            errors.append(f"{rid}: duplicate id")
        position[rid] = index
        ids.append(rid)
    if ids != sorted(ids):
        errors.append("ids are not in ascending order; the registry is append-only")
    superseded_by: dict[str, str] = {}
    for entry in rulings:
        for old in entry.get("supersedes") or []:
            if old not in position:
                errors.append(f"{entry['id']}: supersedes unknown {old}")
            elif position[old] >= position[entry["id"]]:
                errors.append(f"{entry['id']}: supersedes {old}, which is not earlier")
            else:
                superseded_by[old] = entry["id"]
        for token in re.split(r";\s*", str(entry.get("source", ""))):
            match = PATH_TOKEN_RE.fullmatch(token.strip())
            if not match or "/" not in match.group("path"):
                continue
            branch, path = match.group("branch"), match.group("path")
            if branch:
                ref = f"origin/{branch}" if git(root, "rev-parse", "--verify", "-q",
                                                  f"origin/{branch}").returncode == 0 else branch
                if git(root, "cat-file", "-e", f"{ref}:{path}").returncode != 0:
                    warnings.append(f"{entry['id']}: source {path} not found on branch {branch}")
            elif not (root / path).exists():
                errors.append(f"{entry['id']}: source {path} does not exist in this tree")

    citations: dict[str, list[str]] = {}
    listed = git(root, "ls-files")
    for rel in listed.stdout.splitlines():
        path = root / rel
        if rel == REGISTRY or path.suffix not in TEXT_SUFFIXES or not path.is_file():
            continue
        try:
            text = path.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue
        for rid in set(CITE_RE.findall(text)):
            citations.setdefault(rid, []).append(rel)
    for rid, files in sorted(citations.items()):
        if rid not in position:
            errors.append(f"{rid} is cited in {', '.join(sorted(files)[:5])} but not defined")
        elif rid in superseded_by:
            warnings.append(f"{rid} is cited in {', '.join(sorted(files)[:5])} but superseded by "
                            f"{superseded_by[rid]}")
    return {"errors": errors, "warnings": warnings, "citations": citations, "rulings": rulings,
            "superseded_by": superseded_by}


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--root", default=".")
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--show", metavar="RUL-nnn")
    args = parser.parse_args(argv)
    root = Path(args.root).resolve()
    result = check(root)
    if args.show:
        entry = next((r for r in result["rulings"] if r.get("id") == args.show), None)
        if entry is None:
            print(f"{args.show} is not defined", file=sys.stderr)
            return 3
        print(json.dumps(entry, indent=1))
        if args.show in result.get("superseded_by", {}):
            print(f"superseded by {result['superseded_by'][args.show]}")
        print("cited by:", ", ".join(sorted(result["citations"].get(args.show, []))) or "nothing")
        return 0
    if args.json:
        print(json.dumps({k: v for k, v in result.items() if k != "rulings"}, indent=1))
    else:
        print(f"rulings: {len(result['rulings'])} defined, "
              f"{sum(len(v) for v in result['citations'].values())} citations")
        for item in result["errors"]:
            print(f"  ERROR {item}")
        for item in result["warnings"]:
            print(f"  WARN  {item}")
    return 1 if result["errors"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
