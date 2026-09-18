#!/usr/bin/env python3
"""Make a design document say what it is, and check that the ledger agrees.

The completeness ledger admits a design document as evidence by its NAME:
an ORISON_V2_*.md whose filename carries CHECKPOINT, GRAYBOX, ACCEPTANCE,
RECEIPT, VERTICAL_CORE or SCHEMA_GENERATOR.  Nothing reads the document's
own claim about itself, so a management note that says "INERT" in its first
line is inert only because of its filename, and a checkpoint that forgot a
marker is silently ignored.  This lint closes that gap from the author's
side: every design document states its class in a header line

    Evidence class: **INERT**            (reports, briefs, dispatches, plans)
    Evidence class: **EVIDENCE**         (checkpoints and acceptance receipts)

and the lint checks the header against the name.

Findings (level, rule):
  ERROR  name admits it as evidence but the header says INERT (or the
         reverse): the two disagree and the ledger follows the name.
  ERROR  a document in the ledger family names ids in backticks while being
         evidence and the ledger's --evidence-impact says it changes a
         requirement status, when --strict-impact is given.
  WARN   no Evidence class header.
  WARN   an INERT document backticks tokens the ledger would read as ids if
         the document were ever renamed into evidence; write them in bold.
  INFO   an evidence document's --evidence-impact result (which requirement
         statuses it changes), when the ledger supports that flag.

Usage:
  python tools/lint_design_doc.py design/FOO.md [...]
  python tools/lint_design_doc.py --staged        (the staged design docs)
  python tools/lint_design_doc.py --changed-since origin/main
  python tools/lint_design_doc.py --print-hook    (a pre-commit hook body;
                                                   nothing installs itself)

Exit: 0 no errors, 1 errors, 3 usage.
"""
from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

FALLBACK_MARKERS = ("CHECKPOINT", "GRAYBOX", "ACCEPTANCE", "RECEIPT", "VERTICAL_CORE",
                    "SCHEMA_GENERATOR")
HEADER_RE = re.compile(r"^\s*(?:[-*]\s*)?Evidence class:", re.IGNORECASE)
BACKTICK_RE = re.compile(r"`([A-Za-z0-9_./-]+)`")
# Tokens the ledger treats as identifiers: v2 space/record ids (F01_..., B1_...),
# unit keys, and requirement ids (dimension.name).  File paths and code are not.
ID_LIKE_RE = re.compile(r"^(?:(?:F0\d|B\d)_[A-Z0-9_]+|unit\.[0-9A-Za-z]+|[a-z_]+\.[a-z0-9_]+)$")
HEADER_SCAN_LINES = 30


def _ledger_module(root: Path):
    tools = str(root / "tools")
    sys.path.insert(0, tools)
    try:
        import importlib
        return importlib.import_module("audit_orison_v2_completeness")
    except Exception:
        return None
    finally:
        if sys.path and sys.path[0] == tools:
            sys.path.pop(0)


def evidence_marker(name: str, root: Path) -> str | None:
    ledger = _ledger_module(root)
    fn = getattr(ledger, "evidence_marker", None) if ledger else None
    if callable(fn):
        return fn(name)
    return next((m for m in FALLBACK_MARKERS if m in name), None)


def admitted_by_name(path: Path, root: Path) -> tuple[bool, str | None]:
    marker = evidence_marker(path.name, root)
    return (marker is not None and path.name.startswith("ORISON_V2_") and path.suffix == ".md",
            marker)


INERT_WORDS = ("INERT", "REPORT ONLY", "NOT EVIDENCE", "PROMOTES NOTHING", "BRIEF", "DISPATCH",
               "EVALUATION", "PLAN", "GUIDE")
EVIDENCE_WORDS = ("CHECKPOINT", "RECEIPT", "ACCEPTANCE", "ACCEPTED", "EVIDENCE", "GRAYBOX",
                  "VERTICAL CORE", "SCHEMA GENERATOR")


def classify_header(value: str) -> str:
    """INERT, EVIDENCE or UNCLASSIFIED from the header's own words.

    The repository's headers are free prose ("TECHNICAL CHECKPOINT - NO
    STATUS PROMOTION", "REPORT ONLY", "DISPOSABLE REHEARSAL RECEIPT - NO
    PRODUCTION EVIDENCE").  An inert word wins, because a document that
    calls itself a report is never proof; otherwise an evidence word makes
    it evidence; a header with neither (e.g. "TECHNICAL BASELINE") is
    unclassified and only warned about.
    """
    upper = value.upper()
    if any(word in upper for word in INERT_WORDS):
        return "INERT"
    if any(word in upper for word in EVIDENCE_WORDS):
        return "EVIDENCE"
    return "UNCLASSIFIED"


def header_value(text: str) -> str | None:
    for line in text.splitlines()[:HEADER_SCAN_LINES]:
        match = HEADER_RE.match(line)
        if match:
            return line.split(":", 1)[1].strip().strip("*").strip()
    return None


def header_class(text: str) -> str | None:
    value = header_value(text)
    return None if value is None else classify_header(value)


FILE_SUFFIX_RE = re.compile(r"\.(?:py|json|md|gd|tscn|tres|ps1|gltf|glb|bin|png|jpg|txt|csv|"
                            r"cfg|godot|import|blend|sh|yml|yaml|toml)$", re.IGNORECASE)


def id_like_backticks(text: str) -> list[str]:
    return sorted({t for t in BACKTICK_RE.findall(text)
                   if ID_LIKE_RE.match(t) and not FILE_SUFFIX_RE.search(t)})


def evidence_impact(path: Path, root: Path) -> dict | None:
    ledger = root / "tools/audit_orison_v2_completeness.py"
    try:
        if "--evidence-impact" not in ledger.read_text(encoding="utf-8"):
            return None
    except OSError:
        return None
    proc = subprocess.run([sys.executable, str(ledger), "--root", str(root), "--evidence-impact",
                           str(path), "--json"], capture_output=True, text=True,
                          encoding="utf-8", errors="replace")
    try:
        return json.loads(proc.stdout)
    except json.JSONDecodeError:
        return {"error": (proc.stderr or proc.stdout).strip()[-300:]}


def lint_file(path: Path, root: Path, strict_impact: bool = False) -> list[dict]:
    findings: list[dict] = []
    try:
        text = path.read_text(encoding="utf-8")
    except OSError as exc:
        return [{"level": "ERROR", "rule": "unreadable", "message": str(exc)}]
    admitted, marker = admitted_by_name(path, root)
    declared = header_class(text)
    family = path.name.startswith("ORISON_V2_")

    if declared is None:
        suggestion = "EVIDENCE" if admitted else "INERT"
        findings.append({"level": "WARN", "rule": "no-header",
                         "message": f"no 'Evidence class:' header; by its name this document is "
                                    f"{'evidence' if admitted else 'not evidence'}, so add "
                                    f"'Evidence class: **{suggestion}**' in the first "
                                    f"{HEADER_SCAN_LINES} lines"})
    elif declared == "INERT" and admitted:
        findings.append({"level": "ERROR", "rule": "header-contradicts-name",
                         "message": f"header says INERT but the filename marker {marker} makes "
                                    "the ledger admit it as evidence; rename it or change the header"})
    elif declared == "UNCLASSIFIED":
        findings.append({"level": "WARN", "rule": "unclassified-header",
                         "message": f"header '{header_value(text)}' says neither INERT nor "
                                    f"evidence; by its name the ledger "
                                    f"{'admits' if admitted else 'does not admit'} it"})
    elif declared == "EVIDENCE" and not admitted:
        why = ("its name carries no evidence marker" if marker is None else
               "only ORISON_V2_*.md documents are read by the ledger")
        findings.append({"level": "ERROR", "rule": "header-contradicts-name",
                         "message": f"header claims EVIDENCE but the ledger will not admit it: {why}"})

    ids = id_like_backticks(text)
    if ids and not admitted:
        findings.append({"level": "WARN", "rule": "inert-backticks",
                         "message": f"{len(ids)} backticked id-like token(s) in a non-evidence "
                                    f"document ({', '.join(ids[:8])}{', ...' if len(ids) > 8 else ''}); "
                                    "harmless under its current name, promoting if ever renamed. "
                                    "Write ids in bold."})
    if admitted and family:
        impact = evidence_impact(path, root)
        if impact is None:
            findings.append({"level": "INFO", "rule": "impact-unavailable",
                             "message": "this tree's ledger has no --evidence-impact; "
                                        f"{len(ids)} backticked id-like token(s) may promote"})
        elif "error" in impact:
            findings.append({"level": "WARN", "rule": "impact-error", "message": impact["error"]})
        else:
            changed = impact.get("requirements_changed", [])
            level = "ERROR" if (changed and strict_impact) else "INFO"
            summary = ", ".join(f"{c['id']} {c['status_before']}->{c['status_after']}"
                                for c in changed[:10]) or "no requirement status"
            findings.append({"level": level, "rule": "evidence-impact",
                             "message": f"this document changes {len(changed)} requirement "
                                        f"status(es): {summary}"})
    return findings


def _git_lines(root: Path, *args) -> list[str]:
    proc = subprocess.run(["git", "-C", str(root), *args], capture_output=True, text=True)
    if proc.returncode != 0:
        raise RuntimeError(proc.stderr.strip())
    return [l for l in proc.stdout.splitlines() if l.strip()]


def design_paths(paths: list[str]) -> list[str]:
    return [p for p in paths if p.startswith("design/") and p.endswith(".md")]


HOOK = """#!/bin/sh
# Orison design-doc evidence lint (opt-in; see tools/lint_design_doc.py).
python tools/lint_design_doc.py --staged || {
  echo "design doc lint failed: fix the Evidence class header or the filename" >&2
  exit 1
}
"""


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("paths", nargs="*")
    parser.add_argument("--root", default=".")
    parser.add_argument("--staged", action="store_true")
    parser.add_argument("--changed-since")
    parser.add_argument("--strict-impact", action="store_true",
                        help="an evidence document that changes a requirement status is an error "
                             "(use for documents that are meant to be inert records)")
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--print-hook", action="store_true")
    args = parser.parse_args(argv)
    if args.print_hook:
        print(HOOK, end="")
        return 0
    root = Path(args.root).resolve()
    try:
        paths = list(args.paths)
        if args.staged:
            paths += design_paths(_git_lines(root, "diff", "--cached", "--name-only",
                                             "--diff-filter=ACMR"))
        if args.changed_since:
            paths += design_paths(_git_lines(root, "diff", "--name-only", "--diff-filter=ACMR",
                                             f"{args.changed_since}...HEAD"))
    except RuntimeError as exc:
        print(f"usage: {exc}", file=sys.stderr)
        return 3
    if not paths:
        print("no design documents to lint")
        return 0
    report = {}
    for raw in dict.fromkeys(paths):
        path = Path(raw) if Path(raw).is_absolute() else root / raw
        report[raw] = lint_file(path, root, args.strict_impact)
    errors = sum(1 for fs in report.values() for f in fs if f["level"] == "ERROR")
    if args.json:
        print(json.dumps({"errors": errors, "documents": report}, indent=1))
    else:
        for raw, findings in report.items():
            print(f"{raw}: {'clean' if not findings else ''}")
            for f in findings:
                print(f"  {f['level']} [{f['rule']}] {f['message']}")
        print(f"{len(report)} document(s), {errors} error(s)")
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
