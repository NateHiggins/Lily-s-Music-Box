#!/usr/bin/env python3
"""Verify a merge candidate the way management does, mechanically.

    python tools/verify_candidate.py <candidate-ref> [--base origin/main]
        [--report reports/<task>.json] [--suite res://tests/X.tscn ...]
        [--long-suite res://tests/Y.tscn ...] [--windowed-suite res://tests/Z.tscn ...]
        [--no-godot] [--keep]

What it does, in order:

 1. Resolves candidate, base and their merge-base.
 2. Checks both out as FRESH detached worktrees at short paths
    (C:/ov/c-<sha8>, C:/ov/b-<sha8>) with the repository's ordinary
    configuration - autocrlf included - because the defects that reach main
    are the ones a fresh Windows checkout exposes (the M11C2 hash gap).
    A candidate whose fresh checkout is already dirty is BLOCKED.
 3. Runs THIS tree's gate board in both and compares them: every
    regression the board reports blocks.  Base boards are cached by commit.
 4. Lists what changed between merge-base and candidate, and flags any
    change to a gate (audits, their baselines and manifests, tools tests,
    the runners) for human review: a candidate must not quietly grade itself
    with an instrument it rewrote.
 5. Lints every changed design document for evidence class
    (tools/lint_design_doc.py) and blocks on a lint error.
 6. Checks the 17 protected paths (blob identity against the merge-base and
    SHA-256 against the M11C1 protected receipt) and the committed selector.
 7. Unless --no-godot: imports the candidate twice and runs each requested
    suite through THIS tree's runners (so every run gets a receipt), waiting
    for a busy lane up to --lane-wait minutes and never bypassing it; then
    verifies each receipt binds to the candidate tree.
 8. If --report names a report sidecar (JSON, orison.dispatch-report.v1,
    committed in the candidate), compares every claim in it with what was
    observed and blocks on any mismatch.
 9. Writes verification.json and verification.md and prints the table.
    The last line is MERGE-CANDIDATE <sha> or BLOCKED <reasons>.

Exit: 0 MERGE-CANDIDATE, 1 BLOCKED, 3 usage error.  Worktrees are removed
unless --keep.  Nothing here merges, pushes, or edits the candidate.
"""
from __future__ import annotations

import argparse
import datetime as _dt
import hashlib
import json
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path

TOOLS = Path(__file__).resolve().parent
REPO = TOOLS.parent
sys.path.insert(0, str(TOOLS))
import gate_board  # noqa: E402

REPORT_SCHEMA = "orison.dispatch-report.v1"
VERIFY_SCHEMA = "orison.candidate-verification.v1"
PROTECTED_RECEIPT = "design/ORISON_V2_M11C1_PROTECTED_FINAL_RECEIPT_2026-08-31.json"
SELECTOR_PATH = "game/scripts/building/building_root_selector.gd"
EXPECTED_SELECTOR = "v1"
GATE_PATH_RE = re.compile(
    r"^tools/(audit_[^/]+\.py|[^/]*baseline[^/]*\.json|[^/]*manifest[^/]*\.json|"
    r"[^/]*exceptions[^/]*\.json|tests/.+|run_godot_[^/]+\.ps1|lane_common\.ps1|"
    r"run_receipt\.py|gate_board\.py|verify_candidate\.py|lint_design_doc\.py)$")
EXIT_LANE_BUSY = 73


def git(*args, cwd: Path = REPO, check: bool = True) -> str:
    proc = subprocess.run(["git", "-C", str(cwd), *args], capture_output=True, text=True,
                          encoding="utf-8", errors="replace")
    if check and proc.returncode != 0:
        raise RuntimeError(f"git {' '.join(args)}: {proc.stderr.strip()}")
    return proc.stdout.strip()


def git_bytes(*args, cwd: Path = REPO) -> bytes | None:
    proc = subprocess.run(["git", "-C", str(cwd), *args], capture_output=True)
    return proc.stdout if proc.returncode == 0 else None


def fresh_worktree(sha: str, path: Path) -> Path:
    if path.exists():
        git("worktree", "remove", "--force", str(path), check=False)
        if path.exists():
            shutil.rmtree(path, ignore_errors=True)
    git("worktree", "prune", check=False)
    path.parent.mkdir(parents=True, exist_ok=True)
    git("worktree", "add", "--detach", str(path), sha)
    return path


def remove_worktree(path: Path) -> None:
    git("worktree", "remove", "--force", str(path), check=False)
    git("worktree", "prune", check=False)


# ---------------------------------------------------------------------------
# Static checks
# ---------------------------------------------------------------------------

def changed_files(base: str, cand: str) -> list[dict]:
    rows = []
    for line in git("diff", "--name-status", "--no-renames", f"{base}..{cand}").splitlines():
        parts = line.split("\t")
        if len(parts) >= 2:
            rows.append({"status": parts[0], "path": parts[-1]})
    return rows


def protected_check(merge_base: str, cand: str) -> dict:
    receipt_bytes = git_bytes("show", f"{cand}:{PROTECTED_RECEIPT}") or \
        git_bytes("show", f"{merge_base}:{PROTECTED_RECEIPT}")
    if receipt_bytes is None:
        return {"status": "UNKNOWN", "detail": f"{PROTECTED_RECEIPT} not found", "matched": 0,
                "expected": 0, "files": []}
    receipt = json.loads(receipt_bytes.decode("utf-8"))
    files = []
    for entry in receipt.get("files", []):
        path = entry["path"]
        base_oid = git("rev-parse", f"{merge_base}:{path}", check=False)
        cand_oid = git("rev-parse", f"{cand}:{path}", check=False)
        blob = git_bytes("show", f"{cand}:{path}")
        digest = hashlib.sha256(blob).hexdigest() if blob is not None else None
        files.append({"path": path, "unchanged_vs_merge_base": bool(cand_oid) and cand_oid == base_oid,
                      "matches_recorded_baseline": digest == entry.get("baseline_sha256")})
    matched = sum(1 for f in files if f["unchanged_vs_merge_base"])
    return {"status": "PASS" if matched == len(files) else "FAIL", "matched": matched,
            "expected": len(files),
            "recorded_baseline_matches": sum(1 for f in files if f["matches_recorded_baseline"]),
            "files": files}


def selector_check(cand: str) -> dict:
    text = (git_bytes("show", f"{cand}:{SELECTOR_PATH}") or b"").decode("utf-8", "replace")
    match = re.search(r'const DEFAULT_ID\s*:?=\s*"(\w+)"', text)
    value = match.group(1) if match else None
    return {"value": value, "status": "PASS" if value == EXPECTED_SELECTOR else "FAIL"}


def lint_docs(root: Path, changed: list[dict]) -> list[dict]:
    try:
        import lint_design_doc  # noqa: E402
    except ImportError:
        return [{"path": "-", "level": "WARN", "message": "tools/lint_design_doc.py unavailable"}]
    findings = []
    for row in changed:
        path = row["path"]
        if row["status"] != "D" and path.startswith("design/") and path.endswith(".md"):
            for finding in lint_design_doc.lint_file(root / path, root):
                findings.append({"path": path, **finding})
    return findings


# ---------------------------------------------------------------------------
# Godot
# ---------------------------------------------------------------------------

def run_runner(runner: str, project: Path, log: Path, scene: str, extra_import: bool,
               lane_wait_s: int, timeout: int, windowed: bool = False) -> dict:
    script = TOOLS / ("run_godot_serial.ps1" if runner == "serial" else "run_godot_long_suite.ps1")
    parts = [f"& '{script}'", f"-ProjectPath '{project}'", f"-LogPath '{log}'"]
    if scene:
        parts.append(f"-Scene '{scene}'")
    if runner == "serial":
        parts.append(f"-TimeoutSeconds {min(timeout, 180)}")
    else:
        parts.append(f"-TimeoutSeconds {timeout}")
    if extra_import:
        parts.append("-ExtraArgs @('--import')")
    if windowed:
        # Mouse capture does not exist headless: Input.mouse_mode stays
        # VISIBLE however a suite sets it, so any pointer or pause contract
        # fails for the harness's reason rather than the code's. Windowed
        # runs are also slower, so a suite with its own watchdog may need to
        # stay headless.
        parts.append("-Windowed")
    # Suites that write frames refuse to start without somewhere to write.
    shots = log.parent / (log.stem + "_shots")
    shots.mkdir(parents=True, exist_ok=True)
    parts.append(f"-ShotDir '{shots}'")
    command = " ".join(parts) + "; exit $LASTEXITCODE"
    deadline = time.monotonic() + lane_wait_s
    waited = 0
    while True:
        proc = subprocess.run(["pwsh", "-NoProfile", "-Command", command], capture_output=True,
                              text=True, encoding="utf-8", errors="replace")
        if proc.returncode != EXIT_LANE_BUSY or time.monotonic() >= deadline:
            break
        time.sleep(30)
        waited += 30
    receipt_path = Path(str(log) + ".receipt.json")
    result = {"runner": runner, "scene": scene or "(import)", "exit": proc.returncode,
              "lane_waited_s": waited, "log": log.as_posix(),
              "receipt": receipt_path.as_posix() if receipt_path.is_file() else None,
              "tail": (proc.stdout + proc.stderr).strip().splitlines()[-4:]}
    return result


def godot_phase(cand_root: Path, out: Path, suites: list[str], long_suites: list[str],
                lane_wait_s: int, windowed_suites: list[str] | None = None) -> list[dict]:
    import run_receipt  # noqa: E402
    logs = out / "godot"
    logs.mkdir(parents=True, exist_ok=True)
    project = cand_root / "game"
    runs = []
    for n in (1, 2):
        runs.append(run_runner("serial", project, logs / f"import{n}.log", "", True,
                               lane_wait_s, 180))
        if runs[-1]["exit"] != 0:
            return runs
    for scene in suites:
        name = re.sub(r"[^A-Za-z0-9_]+", "_", scene.split("/")[-1])
        runs.append(run_runner("serial", project, logs / f"{name}.log", scene, False,
                               lane_wait_s, 180))
    for scene in long_suites:
        name = re.sub(r"[^A-Za-z0-9_]+", "_", scene.split("/")[-1])
        runs.append(run_runner("long", project, logs / f"{name}.log", scene, False,
                               lane_wait_s, 1500))
    for scene in windowed_suites or []:
        name = re.sub(r"[^A-Za-z0-9_]+", "_", scene.split("/")[-1])
        runs.append(run_runner("serial", project, logs / f"{name}_windowed.log", scene, False,
                               lane_wait_s, 180, windowed=True))
    for run in runs[2:]:
        if run["receipt"]:
            code, problems = run_receipt.verify(Path(run["receipt"]), cand_root)
            run["receipt_binds"] = code == 0
            run["receipt_problems"] = problems
        else:
            run["receipt_binds"] = False
            run["receipt_problems"] = ["no receipt written"]
    return runs


# ---------------------------------------------------------------------------
# Report sidecar
# ---------------------------------------------------------------------------

def compare_report(report: dict, observed: dict) -> list[str]:
    """Every claim the sidecar makes that observation contradicts."""
    mismatches = []
    if report.get("schema") != REPORT_SCHEMA:
        return [f"report sidecar is not {REPORT_SCHEMA}"]

    def claim(key, seen, label=None):
        if key in report and report[key] != seen:
            mismatches.append(f"{label or key}: report says {report[key]!r}, observed {seen!r}")

    # A sidecar committed in the candidate cannot name its own commit; when it
    # was written in that commit, its parent is an equally honest "head".
    aliases = [observed["candidate"]] + list(observed.get("candidate_aliases", []))
    if "head" in report and report["head"] not in aliases:
        mismatches.append(f"head: report says {report['head']!r}, observed {observed['candidate']!r}")
    claim("merge_base", observed["merge_base"])
    claim("selector", observed["selector"]["value"])
    claim("protected", f"{observed['protected']['matched']}/{observed['protected']['expected']}")
    claim("ledger_before", observed["ledger_before"])
    claim("ledger_after", observed["ledger_after"])
    if "requirements_changed" in report:
        seen = sorted(observed["comparison"]["requirements_changed"])
        if sorted(report["requirements_changed"]) != seen:
            mismatches.append(f"requirements_changed: report says "
                              f"{sorted(report['requirements_changed'])}, observed {seen}")
    gates = {g["id"]: g["exit"] for g in observed["candidate_board"]["gates"]}
    for gate_id, exit_code in (report.get("gates") or {}).items():
        if gate_id not in gates:
            mismatches.append(f"gate {gate_id}: reported but not run by the board")
        elif gates[gate_id] != exit_code:
            mismatches.append(f"gate {gate_id}: report says exit {exit_code}, observed {gates[gate_id]}")
    suites = {r["scene"]: r["exit"] for r in observed.get("godot", [])}
    for scene, exit_code in (report.get("suites") or {}).items():
        if scene not in suites:
            mismatches.append(f"suite {scene}: reported but not run here (pass --suite/--long-suite)")
        elif suites[scene] != exit_code:
            mismatches.append(f"suite {scene}: report says exit {exit_code}, observed {suites[scene]}")
    last = str(report.get("last_line", ""))
    if last.startswith("MERGE-CANDIDATE") and not any(a[:7] in last for a in aliases):
        mismatches.append(f"last_line names a different commit: {last!r}")
    return mismatches


def ledger_counts(board: dict) -> dict:
    for row in board.get("gates", []):
        if row["id"] == "ledger":
            return {k.split(".", 1)[1]: v for k, v in row.get("counts", {}).items()}
    return {}


# ---------------------------------------------------------------------------
# Rendering
# ---------------------------------------------------------------------------

def render(result: dict) -> str:
    comp = result["comparison"]
    lines = [f"# Candidate verification - {result['candidate'][:12]}", "",
             f"- candidate `{result['candidate']}`", f"- base `{result['base']}`",
             f"- merge-base `{result['merge_base']}`",
             f"- verified {result['created_utc']} from verifier `{result['verifier_commit'][:12]}`", "",
             "| check | result |", "|---|---|",
             f"| fresh checkout clean | {'yes' if not result['fresh_checkout_dirty'] else 'NO: ' + str(len(result['fresh_checkout_dirty'])) + ' paths'} |",
             f"| gate board vs merge-base | {len(comp['regressions'])} regressions, {len(comp['improvements'])} improvements |",
             f"| ledger before | {result['ledger_before']} |",
             f"| ledger after | {result['ledger_after']} |",
             f"| requirements_changed | {comp['requirements_changed']} |",
             f"| protected | {result['protected']['matched']}/{result['protected']['expected']} unchanged vs merge-base |",
             f"| selector | {result['selector']['value']} |",
             f"| design doc lint errors | {sum(1 for f in result['doc_lint'] if f['level'] == 'ERROR')} |",
             f"| gates changed by candidate | {len(result['gate_changes'])} |"]
    for run in result.get("godot", []):
        binds = run.get("receipt_binds")
        lines.append(f"| godot {run['scene']} | exit {run['exit']}"
                     + (f", receipt {'binds' if binds else 'STALE'}" if binds is not None else "")
                     + (f", waited {run['lane_waited_s']} s for lane" if run['lane_waited_s'] else "")
                     + " |")
    if result.get("report_mismatches") is not None:
        lines.append(f"| report sidecar claims contradicted | {len(result['report_mismatches'])} |")
    sections = [("Blocking reasons", result["blocking"]),
                ("Needs human review (not blocking)", result["review"]),
                ("Regressions", comp["regressions"]),
                ("Accepted regressions", result.get("accepted_regressions", {}).get("lines", [])),
                ("Improvements", comp["improvements"]),
                ("Report claims contradicted", result.get("report_mismatches") or []),
                ("Design doc lint", [f"{f['level']} {f['path']}: {f['message']}" for f in result["doc_lint"]]),
                ("Gates changed by the candidate", result["gate_changes"])]
    for title, items in sections:
        lines += ["", f"## {title} ({len(items)})", ""]
        lines += [f"- {item}" for item in items[:150]] or ["- none"]
    lines += ["", result["last_line"]]
    return "\n".join(lines) + "\n"


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("candidate")
    parser.add_argument("--base", default="origin/main")
    parser.add_argument("--report", help="report sidecar path inside the candidate tree")
    parser.add_argument("--suite", action="append", default=[], help="res:// scene, serial runner")
    parser.add_argument("--long-suite", action="append", default=[], help="res:// scene, long runner")
    parser.add_argument("--windowed-suite", action="append", default=[],
                        help="res:// scene that needs a real window (mouse capture, "
                             "pointer or screenshot contracts); runs with -Windowed and a ShotDir")
    parser.add_argument("--no-godot", action="store_true")
    parser.add_argument("--lane-wait", type=int, default=30, help="minutes to wait on a busy lane")
    parser.add_argument("--work-dir", default="C:/ov")
    parser.add_argument("--out")
    parser.add_argument("--keep", action="store_true", help="keep the worktrees")
    parser.add_argument("--accept-suite", action="append", default=[], metavar="TEXT",
                        help="a Godot suite whose scene contains TEXT may fail without "
                             "blocking (an owner-ruled seam between two lines of work); "
                             "every acceptance is printed and recorded")
    parser.add_argument("--accept-regression", action="append", default=[], metavar="TEXT",
                        help="a regression line containing TEXT is accepted, not blocking "
                             "(an owner-ruled recount such as a gate hardening); every "
                             "acceptance is printed and recorded")
    parser.add_argument("--no-fetch", action="store_true")
    args = parser.parse_args(argv)

    try:
        if not args.no_fetch:
            git("fetch", "--quiet", "origin", check=False)
        cand = git("rev-parse", "--verify", f"{args.candidate}^{{commit}}")
        base = git("rev-parse", "--verify", f"{args.base}^{{commit}}")
        merge_base = git("merge-base", base, cand)
    except RuntimeError as exc:
        print(f"usage: {exc}", file=sys.stderr)
        return 3
    work = Path(args.work_dir)
    out = Path(args.out) if args.out else work / "reports" / cand[:12]
    out.mkdir(parents=True, exist_ok=True)
    cand_root = fresh_worktree(cand, work / f"c-{cand[:8]}")
    base_root = None
    try:
        dirty = [l for l in git("status", "--porcelain", cwd=cand_root).splitlines() if l.strip()]
        cache = work / "boards" / f"{merge_base}.v{gate_board.TOOL_VERSION}.json"
        if cache.is_file():
            base_board = json.loads(cache.read_text(encoding="utf-8"))
        else:
            base_root = fresh_worktree(merge_base, work / f"b-{merge_base[:8]}")
            base_board = gate_board.build_board(base_root, True, [], 6, 600)
            cache.parent.mkdir(parents=True, exist_ok=True)
            cache.write_text(json.dumps(base_board, indent=1), encoding="utf-8")
        cand_board = gate_board.build_board(cand_root, True, [], 6, 600)
        comparison = gate_board.compare(base_board, cand_board)
        changed = changed_files(merge_base, cand)
        gate_changes = [f"{r['status']} {r['path']}" for r in changed if GATE_PATH_RE.match(r["path"])]
        blocking, review = [], []
        result = {
            "schema": VERIFY_SCHEMA,
            "created_utc": _dt.datetime.now(_dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
            "verifier_commit": git("rev-parse", "HEAD"),
            "candidate": cand, "base": base, "merge_base": merge_base,
            "fresh_checkout_dirty": dirty,
            "changed_files": changed,
            "gate_changes": gate_changes,
            "doc_lint": lint_docs(cand_root, changed),
            "protected": protected_check(merge_base, cand),
            "selector": selector_check(cand),
            "base_board": base_board, "candidate_board": cand_board,
            "comparison": comparison,
            "ledger_before": ledger_counts(base_board),
            "ledger_after": ledger_counts(cand_board),
        }
        if not args.no_godot:
            result["godot"] = godot_phase(cand_root, out, args.suite, args.long_suite,
                                          args.lane_wait * 60, args.windowed_suite)
        if args.report:
            raw = git_bytes("show", f"{cand}:{args.report}")
            if raw is None:
                result["report_mismatches"] = [f"report sidecar {args.report} is not committed in the candidate"]
            else:
                touched = git("diff", "--name-only", f"{cand}~1", cand, check=False).splitlines()
                if args.report in touched:
                    result["candidate_aliases"] = [git("rev-parse", f"{cand}~1")]
                try:
                    result["report"] = json.loads(raw.decode("utf-8"))
                    result["report_mismatches"] = compare_report(result["report"], result)
                except json.JSONDecodeError as exc:
                    result["report_mismatches"] = [f"report sidecar is not JSON: {exc}"]

        if dirty:
            blocking.append(f"fresh checkout is dirty ({len(dirty)} paths), e.g. {dirty[0]}")
        accepted = [r for r in comparison["regressions"]
                    if any(text in r for text in args.accept_regression)]
        blocking += [f"regression: {r}" for r in comparison["regressions"] if r not in accepted]
        result["accepted_regressions"] = {"patterns": args.accept_regression, "lines": accepted}
        if accepted:
            review.append(f"{len(accepted)} regression(s) accepted by --accept-regression "
                          f"{args.accept_regression}")
        if result["protected"]["status"] != "PASS":
            changed_protected = [f["path"] for f in result["protected"]["files"]
                                 if not f["unchanged_vs_merge_base"]]
            blocking.append(f"protected paths changed: {changed_protected or result['protected'].get('detail')}")
        if result["selector"]["status"] != "PASS":
            blocking.append(f"selector is {result['selector']['value']!r}, expected {EXPECTED_SELECTOR!r}")
        blocking += [f"doc lint: {f['path']}: {f['message']}" for f in result["doc_lint"]
                     if f["level"] == "ERROR"]
        accepted_suites = []
        for run in result.get("godot", []):
            if run["exit"] != 0:
                if any(text in run["scene"] for text in args.accept_suite):
                    accepted_suites.append(f"godot {run['scene']}: exit {run['exit']}")
                    continue
                blocking.append(f"godot {run['scene']}: exit {run['exit']}")
            elif run.get("receipt_binds") is False:
                blocking.append(f"godot {run['scene']}: receipt does not bind "
                                f"({'; '.join(run['receipt_problems'])})")
        blocking += [f"report: {m}" for m in result.get("report_mismatches") or []]
        if accepted_suites:
            result["accepted_suites"] = accepted_suites
            review.append(f"{len(accepted_suites)} suite failure(s) accepted by "
                          f"--accept-suite {args.accept_suite}: " + "; ".join(accepted_suites))
        if gate_changes:
            review.append(f"candidate changes {len(gate_changes)} gate file(s); "
                          "read those diffs before trusting the board")
        if comparison["requirements_changed"]:
            review.append(f"ledger requirements changed: {comparison['requirements_changed']}")
        if args.no_godot:
            review.append("Godot suites were not run (--no-godot)")
        result["blocking"], result["review"] = blocking, review
        result["last_line"] = (f"MERGE-CANDIDATE {cand}" if not blocking else
                               "BLOCKED " + "; ".join(blocking[:3]) +
                               (f" (+{len(blocking) - 3} more)" if len(blocking) > 3 else ""))
        markdown = render(result)
        (out / "verification.json").write_text(json.dumps(result, indent=1) + "\n", encoding="utf-8")
        (out / "verification.md").write_text(markdown, encoding="utf-8")
        print(markdown)
        print(f"written to {out}")
        return 0 if not blocking else 1
    finally:
        if not args.keep:
            remove_worktree(cand_root)
            if base_root is not None:
                remove_worktree(base_root)


if __name__ == "__main__":
    raise SystemExit(main())
