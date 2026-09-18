#!/usr/bin/env python3
"""One command for every static gate, one file for the result.

Runs the completeness ledger, the spatial dependency audit, the systemic
authority audit, the period audit, the reader gate (against its frozen
baseline), the prompt-carrier audit and every tools/tests suite, then writes
a board: commit, tree, and per gate the real exit code, a severity, the
headline counts and the named defects behind them.

Two uses:

  python tools/gate_board.py --out <dir>
      writes <dir>/board.json and <dir>/board.md; prints the table.

  python tools/gate_board.py --out <dir> --baseline <old board.json>
      also compares against an earlier board (main's, usually) and prints
      what regressed and what improved.  Exit 1 if anything regressed.

Why a baseline and not "exit 0": main is not green and is not meant to be.
The ledger exits 2 while the rebuild is incomplete; the reader gate and the
carrier audit carry known debt.  A developer's gate is "nothing got worse and
the named things that were supposed to move moved", which is a comparison,
not a colour.  The board never manufactures a greener answer than a gate
gave: it records every exit code verbatim and derives severity from it.

Regression rules (all of them, so a reader can predict the verdict):
  - severity rose (PASS < INCOMPLETE < FAIL < ERROR);
  - a defect count rose (ledger blockers per scope, reader NEW findings,
    carrier forbidden, spatial/systemic drift, test failures);
  - a named defect appeared that the baseline did not have;
  - a ledger requirement's status fell, or a requirement disappeared;
  - a tools test file ran fewer tests than before (a deleted test is not a
    pass).
Everything else that moved is listed as a change or an improvement.

Exit codes: 0 no regressions (or no baseline given), 1 regressions,
3 usage error.  Gate failures without a baseline do not change the exit:
the board is a record, and the comparison is the verdict.
"""
from __future__ import annotations

import argparse
import datetime as _dt
import hashlib
import json
import re
import subprocess
import sys
import time
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

BOARD_SCHEMA = "orison.gate-board.v1"
TOOL_VERSION = 1
SEVERITY = ["PASS", "INCOMPLETE", "FAIL", "ERROR"]
# Ledger status ranks, read from the ledger itself when importable so this
# board can never disagree with it; the literal is only a fallback.
_FALLBACK_STATUS_ORDER = ["ABSENT", "ANCHOR_ONLY", "SHELL_ONLY", "PROGRAMMED",
                          "SPATIALLY_PROVEN", "RUNTIME_PROVEN", "HUMAN_ACCEPTED"]


def _status_order(root: Path) -> list[str]:
    try:
        sys.path.insert(0, str(root / "tools"))
        import audit_orison_v2_completeness as ledger  # noqa: E402
        return list(ledger.STATUS_ORDER)
    except Exception:
        return list(_FALLBACK_STATUS_ORDER)
    finally:
        if sys.path and sys.path[0] == str(root / "tools"):
            sys.path.pop(0)


# ---------------------------------------------------------------------------
# Gate definitions.  Each parser takes (exit_code, stdout, stderr) and returns
# {"counts": {name: int}, "info": {...}, "defects": [str], "states": {id: str}}.
# "counts" are defect counts (up = worse).  "info" is context only.
# ---------------------------------------------------------------------------

def _json(stdout: str) -> dict:
    return json.loads(stdout) if stdout.strip() else {}


def parse_ledger(code, out, err):
    data = _json(out)
    summary = data.get("summary", {})
    return {
        "counts": {f"blockers.{k}": int(v) for k, v in
                   summary.get("blockers_by_scope", {}).items()},
        "info": {"tool_version": data.get("tool_version"),
                 "requirements": summary.get("requirements"),
                 "by_status": summary.get("by_status", {}),
                 "v1_fallbacks": summary.get("v1_fallbacks"),
                 "stale_checkpoint_ids": summary.get("stale_checkpoint_ids")},
        "defects": [],
        "states": {r["id"]: r["status"] for r in data.get("requirements", [])},
    }


def _drift_items(drift: dict, keys) -> tuple[dict, list]:
    counts, defects = {}, []
    for key in keys:
        rows = drift.get(key) or []
        counts[f"drift.{key}"] = len(rows)
        for row in rows:
            ident = row.get("id") if isinstance(row, dict) else None
            if not ident:
                ident = hashlib.sha256(json.dumps(row, sort_keys=True).encode()).hexdigest()[:16]
            defects.append(f"{key}:{ident}")
    return counts, defects


def parse_spatial(code, out, err):
    data = _json(out)
    counts, defects = _drift_items(data.get("drift", {}), (
        "new_failing", "new_reported", "class_changes", "target_vanished",
        "save_unresolved", "stale_preserved"))
    return {"counts": counts, "defects": defects, "states": {},
            "info": {"result": data.get("result"),
                     "records": data.get("summary", {}).get("records")}}


def parse_systemic(code, out, err):
    data = _json(out)
    counts, defects = _drift_items(data.get("drift", {}), ("new_actionable", "new_review"))
    return {"counts": counts, "defects": defects, "states": {},
            "info": {"findings": data.get("summary", {}).get("findings"),
                     "by_class": data.get("summary", {}).get("by_class", {})}}


def parse_period(code, out, err):
    fails = [line.strip() for line in out.splitlines() if " FAIL" in line]
    match = re.search(r"PERIOD DATE AUDIT: (\w+)(?: \((\d+) classified findings\))?", out)
    return {"counts": {"fail_lines": len(fails)}, "defects": fails, "states": {},
            "info": {"verdict": match.group(1) if match else None,
                     "classified": int(match.group(2)) if match and match.group(2) else None}}


def parse_reader(code, out, err):
    data = _json(out)
    base = data.get("baseline", {})
    return {"counts": {"new": len(base.get("new", []))},
            "defects": list(base.get("new", [])), "states": {},
            "info": {"known": base.get("known"), "resolved": len(base.get("resolved", [])),
                     "summary": data.get("summary", {})}}


def parse_carriers(code, out, err):
    data = _json(out)
    summary = data.get("summary", {})
    defects = [f"{row.get('file')}:{row.get('line')}:{row.get('token')}"
               for row in data.get("forbidden", [])]
    return {"counts": {k: int(summary.get(k, 0)) for k in
                       ("forbidden", "legacy_uncovered", "baseline_stale", "ambiguous_dynamic")},
            "defects": defects, "states": {},
            "info": {"prompt_methods": summary.get("prompt_methods"),
                     "legacy_covered": summary.get("legacy_covered")}}


def parse_unittest(code, out, err):
    text = err + out
    ran = re.findall(r"^Ran (\d+) tests?", text, re.MULTILINE)
    failed = re.search(r"FAILED \(([^)]*)\)", text)
    bad = 0
    if failed:
        bad = sum(int(n) for n in re.findall(r"(?:failures|errors)=(\d+)", failed.group(1)))
    names = re.findall(r"^(?:FAIL|ERROR): (\S+ \([^)]+\))", text, re.MULTILINE)
    return {"counts": {"failed": bad if ran else (0 if code == 0 else 1)},
            "defects": names, "states": {},
            "info": {"ran": int(ran[-1]) if ran else None}}


GATES = [
    {"id": "ledger", "argv": ["tools/audit_orison_v2_completeness.py", "--json"],
     "parse": parse_ledger, "incomplete": {2}, "error": {3, 4, 70}},
    {"id": "spatial", "argv": ["tools/audit_orison_spatial_dependencies.py", "--json"],
     "parse": parse_spatial, "incomplete": set(), "error": {3, 70}},
    {"id": "systemic", "argv": ["tools/audit_systemic_situation_authority.py", "--json"],
     "parse": parse_systemic, "incomplete": set(), "error": {3, 4, 70}},
    {"id": "period", "argv": ["tools/audit_period_dates.py"],
     "parse": parse_period, "incomplete": set(), "error": {2}},
    {"id": "reader", "argv": ["tools/audit_data_consumption.py", "--json", "--baseline"],
     "parse": parse_reader, "incomplete": set(), "error": {4}},
    {"id": "carriers", "argv": ["tools/audit_interaction_prompt_carriers.py", "--json"],
     "parse": parse_carriers, "incomplete": set(), "error": {3, 70}},
]


def test_gates(root: Path) -> list[dict]:
    return [{"id": f"test:{path.stem}", "argv": [str(path.relative_to(root).as_posix())],
             "parse": parse_unittest, "incomplete": set(), "error": set()}
            for path in sorted((root / "tools/tests").glob("test_*.py"))]


# ---------------------------------------------------------------------------
# Running
# ---------------------------------------------------------------------------

def _git(root: Path, *args) -> str:
    try:
        return subprocess.run(["git", "-C", str(root), *args], capture_output=True,
                              text=True, check=True).stdout.strip()
    except (OSError, subprocess.CalledProcessError):
        return ""


def run_gate(root: Path, gate: dict, timeout: int) -> dict:
    started = time.monotonic()
    try:
        proc = subprocess.run([sys.executable, *gate["argv"]], cwd=root, capture_output=True,
                              text=True, encoding="utf-8", errors="replace", timeout=timeout)
        code, out, err, timed_out = proc.returncode, proc.stdout, proc.stderr, False
    except subprocess.TimeoutExpired as exc:
        code, timed_out = None, True
        out = exc.stdout.decode("utf-8", "replace") if isinstance(exc.stdout, bytes) else (exc.stdout or "")
        err = exc.stderr.decode("utf-8", "replace") if isinstance(exc.stderr, bytes) else (exc.stderr or "")
    elapsed = round(time.monotonic() - started, 2)
    row = {"id": gate["id"], "argv": gate["argv"], "exit": code, "timed_out": timed_out,
           "elapsed_s": elapsed,
           "stdout_sha256": hashlib.sha256(out.encode("utf-8")).hexdigest()}
    if timed_out:
        severity = "ERROR"
    elif code == 0:
        severity = "PASS"
    elif code in gate["incomplete"]:
        severity = "INCOMPLETE"
    elif code in gate["error"]:
        severity = "ERROR"
    else:
        severity = "FAIL"
    try:
        parsed = gate["parse"](code, out, err)
    except (ValueError, KeyError, TypeError) as exc:
        parsed = {"counts": {}, "info": {"parse_error": str(exc)}, "defects": [], "states": {}}
        severity = "ERROR"
    row.update(severity=severity, **parsed)
    if severity in ("FAIL", "ERROR"):
        row["stderr_tail"] = err.strip().splitlines()[-6:]
    return row


def build_board(root: Path, include_tests: bool, only: list[str], jobs: int, timeout: int) -> dict:
    gates = list(GATES) + (test_gates(root) if include_tests else [])
    if only:
        gates = [g for g in gates if any(g["id"] == o or g["id"].startswith(o + ":") for o in only)]
    with ThreadPoolExecutor(max_workers=max(1, jobs)) as pool:
        rows = list(pool.map(lambda g: run_gate(root, g, timeout), gates))
    dirty = [line for line in _git(root, "status", "--porcelain").splitlines() if line.strip()]
    return {
        "schema": BOARD_SCHEMA, "tool_version": TOOL_VERSION,
        "created_utc": _dt.datetime.now(_dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "commit": _git(root, "rev-parse", "HEAD"),
        "tree": _git(root, "rev-parse", "HEAD^{tree}"),
        "dirty_paths": dirty,
        "python": sys.version.split()[0],
        "status_order": _status_order(root),
        "gates": rows,
    }


# ---------------------------------------------------------------------------
# Comparison
# ---------------------------------------------------------------------------

def compare(old: dict, new: dict) -> dict:
    order = new.get("status_order") or _FALLBACK_STATUS_ORDER
    rank = {s: i for i, s in enumerate(order)}
    old_rows = {g["id"]: g for g in old.get("gates", [])}
    new_rows = {g["id"]: g for g in new.get("gates", [])}
    regressions, improvements, changes = [], [], []
    requirements_changed = []

    for gid in sorted(set(old_rows) | set(new_rows)):
        before, after = old_rows.get(gid), new_rows.get(gid)
        if before is None:
            changes.append(f"{gid}: new gate ({after['severity']}, exit {after['exit']})")
            if after["severity"] in ("FAIL", "ERROR"):
                regressions.append(f"{gid}: new gate is {after['severity']} (exit {after['exit']})")
            continue
        if after is None:
            changes.append(f"{gid}: not run on this board")
            continue
        sb, sa = SEVERITY.index(before["severity"]), SEVERITY.index(after["severity"])
        if sa > sb:
            regressions.append(f"{gid}: {before['severity']} -> {after['severity']} "
                               f"(exit {before['exit']} -> {after['exit']})")
        elif sa < sb:
            improvements.append(f"{gid}: {before['severity']} -> {after['severity']}")
        elif before["exit"] != after["exit"]:
            changes.append(f"{gid}: exit {before['exit']} -> {after['exit']}")
        for key in sorted(set(before.get("counts", {})) | set(after.get("counts", {}))):
            b, a = before.get("counts", {}).get(key, 0), after.get("counts", {}).get(key, 0)
            if a > b:
                regressions.append(f"{gid}: {key} {b} -> {a}")
            elif a < b:
                improvements.append(f"{gid}: {key} {b} -> {a}")
        bd, ad = set(before.get("defects", [])), set(after.get("defects", []))
        for item in sorted(ad - bd):
            regressions.append(f"{gid}: new defect {item}")
        for item in sorted(bd - ad):
            improvements.append(f"{gid}: resolved {item}")
        ran_b = before.get("info", {}).get("ran")
        ran_a = after.get("info", {}).get("ran")
        if isinstance(ran_b, int) and isinstance(ran_a, int) and ran_a < ran_b:
            regressions.append(f"{gid}: ran {ran_b} -> {ran_a} tests")
        bs, as_ = before.get("states", {}), after.get("states", {})
        for rid in sorted(set(bs) | set(as_)):
            if rid not in as_:
                regressions.append(f"{gid}: requirement {rid} disappeared (was {bs[rid]})")
                requirements_changed.append(rid)
            elif rid not in bs:
                changes.append(f"{gid}: requirement {rid} added ({as_[rid]})")
                requirements_changed.append(rid)
            elif bs[rid] != as_[rid]:
                requirements_changed.append(rid)
                line = f"{gid}: {rid} {bs[rid]} -> {as_[rid]}"
                if rank.get(as_[rid], -1) < rank.get(bs[rid], -1):
                    regressions.append(line)
                else:
                    improvements.append(line)
    return {"from_commit": old.get("commit"), "to_commit": new.get("commit"),
            "regressions": regressions, "improvements": improvements,
            "changes": changes, "requirements_changed": requirements_changed}


# ---------------------------------------------------------------------------
# Rendering
# ---------------------------------------------------------------------------

def _headline(row: dict) -> str:
    counts = {k: v for k, v in row.get("counts", {}).items() if v}
    info = row.get("info", {})
    if row["id"] == "ledger":
        return ("blockers " + " / ".join(
            str(row["counts"][k]) for k in row["counts"]) +
            f"; requirements {info.get('requirements')}")
    if row["id"].startswith("test:"):
        return f"ran {info.get('ran')}, failed {row['counts'].get('failed', 0)}"
    if row["id"] == "reader":
        return f"new {row['counts'].get('new', 0)}, known {info.get('known')}, resolved {info.get('resolved')}"
    parts = [f"{k} {v}" for k, v in counts.items()]
    return ", ".join(parts) if parts else "no defects counted"


def render_markdown(board: dict, comparison: dict | None) -> str:
    lines = [f"# Gate board - {board['commit'][:12] or 'no commit'}", "",
             f"- commit `{board['commit']}`", f"- tree `{board['tree']}`",
             f"- created {board['created_utc']}",
             f"- dirty paths: {len(board['dirty_paths'])}", "",
             "| gate | severity | exit | seconds | headline |",
             "|---|---|---:|---:|---|"]
    for row in board["gates"]:
        exit_text = "timeout" if row["timed_out"] else str(row["exit"])
        lines.append(f"| {row['id']} | {row['severity']} | {exit_text} | "
                     f"{row['elapsed_s']} | {_headline(row)} |")
    if comparison is not None:
        lines += ["", f"## Against {str(comparison['from_commit'])[:12]}", "",
                  f"Verdict: **{'REGRESSED' if comparison['regressions'] else 'NO REGRESSIONS'}**",
                  "", f"requirements_changed: {comparison['requirements_changed']}", ""]
        for title, key in (("Regressions", "regressions"), ("Improvements", "improvements"),
                           ("Other changes", "changes")):
            lines.append(f"### {title} ({len(comparison[key])})")
            lines.append("")
            lines += [f"- {item}" for item in comparison[key][:200]] or ["- none"]
            if len(comparison[key]) > 200:
                lines.append(f"- ... {len(comparison[key]) - 200} more in board.json")
            lines.append("")
    return "\n".join(lines) + "\n"


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--root", default=".")
    parser.add_argument("--out", help="directory for board.json and board.md")
    parser.add_argument("--baseline", help="an earlier board.json to compare against")
    parser.add_argument("--compare-only", nargs=2, metavar=("OLD", "NEW"),
                        help="compare two existing boards without running anything")
    parser.add_argument("--only", action="append", default=[],
                        help="run only these gate ids (e.g. ledger, reader, test)")
    parser.add_argument("--no-tests", action="store_true", help="skip tools/tests")
    parser.add_argument("--jobs", type=int, default=6)
    parser.add_argument("--timeout", type=int, default=600, help="seconds per gate")
    parser.add_argument("--json", action="store_true", help="print the board JSON")
    args = parser.parse_args(argv)

    try:
        if args.compare_only:
            old, new = (json.loads(Path(p).read_text(encoding="utf-8")) for p in args.compare_only)
            comparison = compare(old, new)
            print(render_markdown(new, comparison))
            return 1 if comparison["regressions"] else 0
        root = Path(args.root).resolve()
        if not (root / "tools/audit_orison_v2_completeness.py").is_file():
            print(f"usage: {root} is not an Orison checkout", file=sys.stderr)
            return 3
        baseline = json.loads(Path(args.baseline).read_text(encoding="utf-8")) if args.baseline else None
        if baseline is not None and baseline.get("schema") != BOARD_SCHEMA:
            print(f"usage: {args.baseline} is not a {BOARD_SCHEMA} board", file=sys.stderr)
            return 3
    except (OSError, json.JSONDecodeError) as exc:
        print(f"usage: {exc}", file=sys.stderr)
        return 3

    board = build_board(root, not args.no_tests, args.only, args.jobs, args.timeout)
    comparison = compare(baseline, board) if baseline is not None else None
    if comparison is not None:
        board["comparison"] = comparison
    markdown = render_markdown(board, comparison)
    if args.out:
        out = Path(args.out)
        out.mkdir(parents=True, exist_ok=True)
        (out / "board.json").write_text(json.dumps(board, indent=1, sort_keys=True) + "\n",
                                        encoding="utf-8", newline="\n")
        (out / "board.md").write_text(markdown, encoding="utf-8", newline="\n")
    print(json.dumps(board, indent=1, sort_keys=True) if args.json else markdown)
    return 1 if comparison and comparison["regressions"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
