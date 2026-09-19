#!/usr/bin/env python3
"""Receipts for Godot runs: what ran, against which tree, and how it ended.

tools/run_godot_serial.ps1 and tools/run_godot_long_suite.ps1 call
`write` after every launched run that was given -LogPath, producing
<LogPath>.receipt.json.  A report then cites a file instead of a typed exit
code, and a verifier can check that the file still binds to the tree.

What a receipt is, and is not
-----------------------------
It is the WRAPPER's record: the process was started, it ended this way,
against this commit, this test source and these runtime inputs, and its log
said these PASS/FAIL lines.  evidence_kind is "suite_run".

It is NOT a runtime_contract.  The completeness ledger grants runtime proof
only to a schema-2 receipt in which the test itself records executed
contracts (composition, save/rebuild, denial, teardown).  A wrapper cannot
know those.  The `execution` and `source` blocks here are written in exactly
the shape the ledger's runtime_receipt_errors() checks, with the same
runtime-input digest, so a contract-writing test can copy them verbatim
instead of reinventing them.  Nothing here upgrades a capture.

Subcommands
-----------
  write   --log L --scene S --runner serial|long --exit N|"" --elapsed F
          --started ISO [--timed-out] [--project P] [--windowed]
          [--shot-dir D] [--out R]
  verify  RECEIPT [--root R]   exit 0 if the receipt still binds to the
          tree (test source, runtime inputs, log bytes), 1 if stale, 3 if
          malformed.
  digest  [--root R]           print the runtime-inputs digest.
"""
from __future__ import annotations

import argparse
import datetime as _dt
import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path

RECEIPT_SCHEMA = "orison.run-receipt.v1"
# Identical to the ledger's RUNTIME_INPUT_GLOBS (claude/v2-ledger-runtime-
# contract, tools/audit_orison_v2_completeness.py).  If the ledger is
# importable and defines them, its definition wins; see _ledger_digest().
RUNTIME_INPUT_GLOBS = (
    "game/scripts/**/*.gd", "game/scenes/**/*.tscn", "game/scenes/**/*.tres",
    "game/data/**/*.json", "game/project.godot",
)
PASS_RE = re.compile(r"\bPASS(?:ED)?\b")
FAIL_RE = re.compile(r"\bFAIL(?:ED|URE)?\b")
# Signatures of a stale .godot import cache in a fresh or moved worktree: the
# scripts are fine, the cache is not, and the log looks like a code bug.
STALE_CACHE_RE = re.compile(
    r"Nonexistent function|Could not find base class|Could not resolve class|"
    r"Identifier \"\w+\" not declared in the current scope")
SCRIPT_ERROR_RE = re.compile(r"SCRIPT ERROR|Parse Error|Failed to load script")
MAX_LINES = 40


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def runtime_inputs_sha256(root: Path) -> str:
    """Same algorithm as the ledger: canonical compact JSON of sorted
    [posix_path, raw_bytes_sha256] pairs, UTF-8, ASCII-escaped."""
    ledger = _ledger_digest(root)
    if ledger is not None:
        return ledger
    paths = {path for pattern in RUNTIME_INPUT_GLOBS
             for path in root.glob(pattern) if path.is_file()}
    manifest = sorted([path.relative_to(root).as_posix(), sha256_file(path)] for path in paths)
    encoded = json.dumps(manifest, separators=(",", ":"), ensure_ascii=True).encode("utf-8")
    return hashlib.sha256(encoded).hexdigest()


def _ledger_digest(root: Path):
    """Use the ledger's own function when this tree's ledger has one, so the
    two can never drift apart."""
    tools = str(root / "tools")
    sys.path.insert(0, tools)
    try:
        import importlib
        ledger = importlib.import_module("audit_orison_v2_completeness")
        fn = getattr(ledger, "runtime_inputs_sha256", None)
        return fn(root) if callable(fn) else None
    except Exception:
        return None
    finally:
        if sys.path and sys.path[0] == tools:
            sys.path.pop(0)


def _git(root: Path, *args) -> str:
    try:
        return subprocess.run(["git", "-C", str(root), *args], capture_output=True, text=True,
                              check=True).stdout.strip()
    except (OSError, subprocess.CalledProcessError):
        return ""


def scene_test_script(project: Path, scene: str) -> str | None:
    """The root node's script of a res://tests scene, as a repo-relative path.

    Returns None when the scene has no root script or the script is not a
    game/tests .gd file; the receipt then says so rather than guessing.
    """
    if not scene or not scene.startswith("res://"):
        return None
    tscn = project / scene[len("res://"):]
    if tscn.suffix == ".gd":
        rel = tscn
    else:
        try:
            text = tscn.read_text(encoding="utf-8", errors="replace")
        except OSError:
            return None
        resources = {m.group("id"): m.group("path") for m in re.finditer(
            r'\[ext_resource[^\]]*?type="Script"[^\]]*?path="(?P<path>[^"]+)"[^\]]*?id="(?P<id>[^"]+)"',
            text)}
        resources.update({m.group("id"): m.group("path") for m in re.finditer(
            r'\[ext_resource[^\]]*?type="Script"[^\]]*?id="(?P<id>[^"]+)"[^\]]*?path="(?P<path>[^"]+)"',
            text)})
        root_node = re.search(r"\[node (?![^\]]*parent=)[^\]]*\](?P<body>.*?)(?=\n\[|\Z)", text, re.S)
        if not root_node:
            return None
        ref = re.search(r'script = ExtResource\("(?P<id>[^"]+)"\)', root_node.group("body"))
        if not ref or ref.group("id") not in resources:
            return None
        rel = project / resources[ref.group("id")][len("res://"):]
    return rel.as_posix() if rel.suffix == ".gd" else None


def _read(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return ""


def summarise_log(log: Path) -> dict:
    stderr = Path(str(log) + ".stderr")
    out, err = _read(log), _read(stderr)
    lines = (out + "\n" + err).splitlines()
    passes = [l.strip() for l in lines if PASS_RE.search(l)]
    fails = [l.strip() for l in lines if FAIL_RE.search(l)]
    stale = [l.strip() for l in lines if STALE_CACHE_RE.search(l)]
    script_errors = [l.strip() for l in lines if SCRIPT_ERROR_RE.search(l)]
    return {
        "stdout": log.as_posix(), "stdout_sha256": sha256_file(log) if log.is_file() else None,
        "stderr": stderr.as_posix(),
        "stderr_sha256": sha256_file(stderr) if stderr.is_file() else None,
        "pass_count": len(passes), "fail_count": len(fails),
        "pass_lines": passes[-MAX_LINES:], "fail_lines": fails[:MAX_LINES],
        "script_error_count": len(script_errors), "script_error_lines": script_errors[:10],
        "stale_cache_suspect": bool(stale), "stale_cache_lines": stale[:10],
    }


def build_receipt(args) -> dict:
    log = Path(args.log).resolve()
    project = Path(args.project).resolve() if args.project else None
    toplevel = _git(project or log.parent, "rev-parse", "--show-toplevel")
    # Outside git (a copied tree), the project's parent is the repository root.
    root = Path(toplevel).resolve() if toplevel else (
        project.parent if project else Path(".").resolve())
    if project is None:
        project = root / "game"
    exit_code = int(args.exit) if str(args.exit).strip() not in ("", "None") else None
    test_rel_abs = scene_test_script(project, args.scene)
    test_rel = None
    test_sha = None
    if test_rel_abs:
        test_path = Path(test_rel_abs)
        try:
            test_rel = test_path.relative_to(root).as_posix()
            test_sha = sha256_file(test_path) if test_path.is_file() else None
        except ValueError:
            test_rel = None
    dirty = [l for l in _git(root, "status", "--porcelain").splitlines() if l.strip()]
    completed = exit_code is not None and not args.timed_out
    return {
        "schema": RECEIPT_SCHEMA,
        "schema_version": 1,
        "evidence_kind": "suite_run",
        "note": ("Wrapper receipt: proves the process ran and how it ended. It is not a "
                 "runtime_contract and grants no ledger proof by itself; a contract-writing "
                 "test may copy `execution` and `source` verbatim."),
        "runner": args.runner,
        "scene": args.scene,
        "windowed": bool(args.windowed),
        "shot_dir": args.shot_dir or None,
        "execution": {
            "completed": completed,
            "exit_code": exit_code,
            "timed_out": bool(args.timed_out),
            "elapsed_s": float(args.elapsed) if args.elapsed not in (None, "") else None,
            "started_utc": args.started,
            "finished_utc": _dt.datetime.now(_dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        },
        "source": {
            "repository_head": _git(root, "rev-parse", "HEAD"),
            "repository_tree": _git(root, "rev-parse", "HEAD^{tree}"),
            "dirty_paths": len(dirty),
            "dirty_sample": dirty[:20],
            "test_path": test_rel,
            "test_sha256": test_sha,
            "runtime_inputs_sha256": runtime_inputs_sha256(root),
        },
        "log": summarise_log(log),
    }


def verify(receipt_path: Path, root: Path) -> tuple[int, list[str]]:
    try:
        data = json.loads(receipt_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return 3, [f"unreadable receipt: {exc}"]
    if data.get("schema") != RECEIPT_SCHEMA:
        return 3, [f"not a {RECEIPT_SCHEMA} receipt"]
    problems = []
    source = data.get("source", {})
    if source.get("test_path"):
        test = root / source["test_path"]
        if not test.is_file():
            problems.append(f"test source {source['test_path']} no longer exists")
        elif sha256_file(test) != source.get("test_sha256"):
            problems.append("test source changed since the run")
    else:
        problems.append("receipt names no game/tests source (scene without a root test script)")
    if source.get("runtime_inputs_sha256") != runtime_inputs_sha256(root):
        problems.append("runtime inputs changed since the run")
    log = data.get("log", {})
    for key in ("stdout", "stderr"):
        path, digest = log.get(key), log.get(f"{key}_sha256")
        if path and digest and (not Path(path).is_file() or sha256_file(Path(path)) != digest):
            problems.append(f"{key} log missing or rewritten since the run")
    execution = data.get("execution", {})
    if not execution.get("completed"):
        problems.append("run did not complete (timeout or no exit code)")
    elif execution.get("exit_code") != 0:
        problems.append(f"run exited {execution.get('exit_code')}")
    if log.get("stale_cache_suspect"):
        problems.append("log shows stale-import-cache signatures; re-import and re-run")
    return (1 if problems else 0), problems


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    sub = parser.add_subparsers(dest="cmd", required=True)
    w = sub.add_parser("write")
    w.add_argument("--log", required=True)
    w.add_argument("--scene", default="")
    w.add_argument("--runner", required=True, choices=["serial", "long", "lane", "other"])
    w.add_argument("--exit", default="")
    w.add_argument("--elapsed", default="")
    w.add_argument("--started", default="")
    w.add_argument("--timed-out", action="store_true")
    w.add_argument("--project")
    w.add_argument("--windowed", action="store_true")
    w.add_argument("--shot-dir", default="")
    w.add_argument("--out")
    v = sub.add_parser("verify")
    v.add_argument("receipt")
    v.add_argument("--root", default=".")
    d = sub.add_parser("digest")
    d.add_argument("--root", default=".")
    args = parser.parse_args(argv)

    if args.cmd == "digest":
        print(runtime_inputs_sha256(Path(args.root).resolve()))
        return 0
    if args.cmd == "verify":
        code, problems = verify(Path(args.receipt), Path(args.root).resolve())
        print("RECEIPT " + ("BINDS" if code == 0 else "STALE" if code == 1 else "MALFORMED"))
        for problem in problems:
            print(f"  - {problem}")
        return code
    receipt = build_receipt(args)
    out = Path(args.out) if args.out else Path(str(args.log) + ".receipt.json")
    out.write_text(json.dumps(receipt, indent=1, sort_keys=True) + "\n", encoding="utf-8",
                   newline="\n")
    execution, log = receipt["execution"], receipt["log"]
    print(f"[RUN RECEIPT] {out} exit={execution['exit_code']} completed={execution['completed']} "
          f"pass_lines={log['pass_count']} fail_lines={log['fail_count']}"
          + (" STALE-CACHE-SUSPECT" if log["stale_cache_suspect"] else ""))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
