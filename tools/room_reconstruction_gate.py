#!/usr/bin/env python3
"""One command to decide whether a room checkpoint is landable.

Read-only gate runner over the existing spatial toolchain, chained in order:

  1. checkpoint lint            tools/room_checkpoint_linter.py
  2. regeneration reconciliation tools/room_checkpoint_reconciler.py
  3. evidence verification       tools/room_evidence_verifier.py
  4. progress ledger             tools/room_reconstruction_progress.py
                                 (enriched with the evidence report)

The components are invoked in-process through their own CLIs, so their
parsers, statuses and conservative semantics are preserved exactly; this
wrapper composes their answers and never manufactures a greener one.  It
runs no Godot, Blender, captures, imports or production tests.

Selection is explicit - exactly one of:
  --checkpoint <path>        gate ONE checkpoint document (strict policy)
  --changed-since <git-ref>  gate the checkpoint/manifest documents added or
                             modified since <ref> (strict policy; requires
                             git; deleted checkpoints are surfaced as a
                             deliberate review condition, never ignored)
  --checkpoints <dir>        explicit whole-corpus audit (historical-debt
                             policy: known lint/OPEN/manual debt is reported
                             but does not block; contradictions, conflicts,
                             malformed records, missing exact evidence,
                             recorded failures and metadata mismatches still
                             block)

Gate results:
  LANDABLE                          every gate clean, no symbolic debt
  LANDABLE_WITH_SYMBOLIC_EVIDENCE   gates clean; SYMBOLIC_ONLY evidence debt
                                    remains visible (not evidence-clean)
  BLOCKED_LINT / BLOCKED_DRIFT / BLOCKED_EVIDENCE / BLOCKED_MALFORMED
  BLOCKED_REVIEW                    a checkpoint was deleted since the ref
  BLOCKED_INTERNAL                  a component failed; no LANDABLE verdict
                                    is published over a partial run

Exit codes (stable, tested):
  0   LANDABLE
  2   LANDABLE_WITH_SYMBOLIC_EVIDENCE
  1   blocked by lint, drift, evidence or deleted-checkpoint review
  3   overwrite refusal or gate-level usage error (bad selection, invalid
      git ref, --changed-since with --no-git).  Argparse's own bad-flag
      errors are also remapped to 3 so that 2 stays unambiguous.
  4   malformed checkpoint or evidence data
  5   ordinary blocker plus malformed data
  70  internal failure (component crash, missing/unparseable component
      output)

Strict landability policy (single checkpoint / --changed-since):
  lint            no malformed rows; every row READY (READY already covers
                  explicit [manual]/[visual] and declared-runtime rows)
  reconciliation  no CONTRADICTED decisions, no conflicts touching the
                  selection, no malformed rows; OPEN blocks; UNVERIFIABLE is
                  allowed only when the decision explicitly declares its
                  manual/visual/runtime proof (its lint row is READY, or the
                  reconciler flags a declared runtime scope)
  evidence        no MISSING cited artifact, no RECORDED_FAIL, no
                  METADATA_MISMATCH, no malformed evidence record.
                  VERIFIED_PRESENT is never treated as a recorded pass;
                  SYMBOLIC_ONLY stays visible as debt, split into
                  claimed-durable-proof-without-artifact vs intentionally
                  manual assertions
  progress        the ledger must generate, consume the evidence report,
                  show no DRIFT_RED for selected rooms, retain
                  manual/runtime evidence states, and (as always) contain
                  no COMPLETE state

Execution safety: all component reports are produced in a private staging
directory and published to --output only after every component finished,
its expected files exist and parse, and the summary composed.  A component
failure preserves its stdout/stderr in the gate report and returns
BLOCKED_INTERNAL instead of a partial LANDABLE packet.

Usage:
  python tools/room_reconstruction_gate.py \\
      --checkpoint design/ORISON_X_CHECKPOINT_2026-08-27.md \\
      --layout art/data/building_layout.json --output <dir>
"""

from __future__ import annotations

import argparse
import contextlib
import io
import json
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import room_checkpoint_linter as rl        # noqa: E402
import room_checkpoint_reconciler as rc    # noqa: E402
import room_evidence_verifier as ev        # noqa: E402
import room_layout_workbench as wb         # noqa: E402
import room_reconstruction_progress as rp  # noqa: E402

ROOT = rc.ROOT
DEFAULT_LAYOUT = rc.DEFAULT_LAYOUT

RESULTS = ("LANDABLE", "LANDABLE_WITH_SYMBOLIC_EVIDENCE", "BLOCKED_LINT",
           "BLOCKED_DRIFT", "BLOCKED_EVIDENCE", "BLOCKED_MALFORMED",
           "BLOCKED_REVIEW", "BLOCKED_INTERNAL")

# In-process component entry points; tests may monkeypatch entries to
# simulate component failures without touching the real tools.
RUNNERS = {"lint": rl.main, "reconciliation": rc.main,
           "evidence": ev.main, "progress": rp.main}

SELECTABLE = ("ORISON_*CHECKPOINT*.md", "*.decisions.json", "*.evidence.json")


class GateUsageError(Exception):
    """Gate-level usage problem -> exit 3."""


class GateParser(argparse.ArgumentParser):
    def error(self, message):            # remap argparse's exit 2 -> 3
        self.print_usage(sys.stderr)
        print(f"error: {message}", file=sys.stderr)
        raise SystemExit(3)


def rel(path, root=ROOT):
    p = Path(path)
    if not p.is_absolute():
        p = Path(root) / p
    try:
        return p.resolve().relative_to(Path(root).resolve()).as_posix()
    except ValueError:
        return str(path).replace("\\", "/")


# ---------------------------------------------------------------------------
# Component execution
# ---------------------------------------------------------------------------

def run_component(name, argv):
    """Run one component CLI in-process, capturing output and exit code."""
    out, err = io.StringIO(), io.StringIO()
    code = 70
    error = None
    try:
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            code = RUNNERS[name](argv)
    except SystemExit as exc:            # argparse or explicit exits
        code = exc.code if isinstance(exc.code, int) else 70
    except Exception as exc:             # noqa: BLE001 - preserved verbatim
        error = f"{type(exc).__name__}: {exc}"
        code = 70
    return {"component": name, "argv": [str(a) for a in argv],
            "exit": code, "stdout": out.getvalue()[-4000:],
            "stderr": err.getvalue()[-4000:], "error": error}


def load_json(path):
    return json.loads(Path(path).read_text(encoding="utf-8"))


# ---------------------------------------------------------------------------
# Selection
# ---------------------------------------------------------------------------

def matches_selectable(name):
    import fnmatch
    return any(fnmatch.fnmatchcase(name, pattern) for pattern in SELECTABLE)


def changed_since_selection(root, corpus_dir, ref):
    """Checkpoint/manifest documents added or modified since <ref>, plus a
    list of deleted checkpoint documents (a deliberate review condition)."""
    def run(*args):
        proc = subprocess.run(["git", "-C", str(root), *args],
                              capture_output=True, text=True, timeout=30)
        return proc

    probe = run("rev-parse", "--verify", f"{ref}^{{commit}}")
    if probe.returncode != 0:
        raise GateUsageError(f"--changed-since ref '{ref}' cannot be "
                             f"resolved: {probe.stderr.strip()}")
    corpus_rel = rel(corpus_dir, root)
    diff = run("diff", "--name-status", ref, "--", corpus_rel)
    if diff.returncode != 0:
        raise GateUsageError(f"git diff against '{ref}' failed: "
                             f"{diff.stderr.strip()}")
    selected, deleted = [], []
    for line in diff.stdout.splitlines():
        parts = line.split("\t")
        if len(parts) < 2:
            continue
        status, paths = parts[0], parts[1:]
        name = Path(paths[-1]).name
        if not matches_selectable(name):
            continue
        if status.startswith("D"):
            deleted.append(paths[0])
        else:
            selected.append(paths[-1])
    untracked = run("ls-files", "--others", "--exclude-standard", "--",
                    corpus_rel)
    for line in untracked.stdout.splitlines():
        if matches_selectable(Path(line).name):
            selected.append(line)
    return sorted(set(selected)), sorted(set(deleted))


# ---------------------------------------------------------------------------
# Gate evaluation
# ---------------------------------------------------------------------------

def lint_rows_by_source(lint_dir):
    """(doc-path, line) -> row status, plus per-doc summaries."""
    rows, docs = {}, {}
    for path in sorted(Path(lint_dir).glob("*.lint.json")):
        doc = load_json(path)
        docs[doc["path"]] = doc["summary"] | {
            "document_diagnostics": doc["document_diagnostics"]}
        for row in doc["rows"]:
            rows[(row["source"]["path"], row["source"]["line"])] = row
    return rows, docs


def make_selector(root, selected_paths):
    """Path-membership predicate robust to relative/absolute report paths."""
    import os

    def norm(p):
        q = Path(p)
        if not q.is_absolute():
            q = Path(root) / q
        try:
            return os.path.normcase(str(q.resolve()))
        except OSError:
            return os.path.normcase(str(q))

    selected = {norm(p) for p in selected_paths}

    def is_selected(path):
        return norm(path) in selected
    return is_selected


def evaluate(selection, strict, reports, lint_rows, lint_docs, is_selected,
             room_filter=None, floor_filter=None, layout_rooms=None):
    """Compose blockers and debt from the component reports."""
    blockers, debt = [], []

    def block(category, gate, detail, source, action):
        blockers.append({"category": category, "gate": gate,
                         "detail": detail, "source": source,
                         "next_action": action})

    def in_scope(room):
        if room_filter:
            return room == room_filter
        if floor_filter and layout_rooms is not None:
            return layout_rooms.get(room) == floor_filter
        return True

    # ---- lint gate -------------------------------------------------------
    for doc_path in sorted(lint_docs):
        if not is_selected(doc_path):
            continue
        summary = lint_docs[doc_path]
        if summary["malformed"]:
            block("malformed", "lint",
                  f"{summary['malformed']} malformed verdict row(s)",
                  doc_path, "fix the malformed rows the lint report quotes")
        if summary["needs_attention"]:
            entry = {"kind": "lint-attention", "source": doc_path,
                     "detail": f"{summary['needs_attention']} row(s) not "
                               "machine-checkable"}
            if strict:
                block("lint", "lint", entry["detail"], doc_path,
                      "add exact IDs, supply MOVE/REPAIR/REPLACE/ADD "
                      "targets, or mark rows [manual]/[visual] explicitly")
            else:
                debt.append(dict(entry, note="historical lint debt "
                                             "(non-blocking in corpus mode)"))
        if "NO_VERDICT_TABLE" in summary.get("document_diagnostics", []):
            entry = {"kind": "prose-only-checkpoint", "source": doc_path,
                     "detail": "no machine-readable verdict table"}
            if strict:
                block("lint", "lint", entry["detail"], doc_path,
                      "add a verdict table or a decisions manifest")
            else:
                debt.append(dict(entry, note="historical debt"))

    # ---- reconciliation gate --------------------------------------------
    recon = reports["reconciliation"]
    selected_decisions = []
    for room, rows in recon["decisions_by_room"].items():
        for d in rows:
            if is_selected(d["source"]["path"]) \
                    and (d["room"] is None or in_scope(d["room"])):
                selected_decisions.append(d)
    for d in selected_decisions:
        src = f"{d['source']['path']}:{d['source']['line']}"
        if d["status"] == "CONTRADICTED":
            block("drift", "reconciliation",
                  f"`{d['object'] or '(no id)'}` {d['verdict']} contradicted: "
                  f"{d['reason']}", src,
                  "resolve the contradiction (or rerun after regeneration "
                  "if the layout moved underneath the checkpoint)")
        elif d["status"] == "OPEN" and strict:
            block("drift", "reconciliation",
                  f"`{d['object'] or '(no id)'}` {d['verdict']} still open: "
                  f"{d['reason']}", src,
                  "land the change the decision describes, or withdraw it")
        elif d["status"] == "OPEN":
            debt.append({"kind": "historical-open", "source": src,
                         "detail": f"`{d['object'] or '(no id)'}` {d['verdict']} open"})
        elif d["status"] == "UNVERIFIABLE":
            lint_row = lint_rows.get((d["source"]["path"],
                                      d["source"]["line"]))
            declared = (lint_row and lint_row["status"] == "READY") or any(
                "runtime-only dependency" in f and "declared" in f
                for f in d.get("flags", []))
            if declared or not strict:
                debt.append({"kind": "manual-runtime-decision",
                             "source": src,
                             "detail": f"`{d['object'] or '(no id)'}` {d['verdict']}: "
                                       f"{d['reason'][:120]}"})
            else:
                # Authoring-shaped unverifiables (no id, kind token,
                # imprecise id, unreadable target) are checkability
                # problems: block as lint so the fix is named correctly.
                authoring = any(marker in d["reason"] for marker in (
                    "no stable object id", "assembly/marker KIND",
                    "imprecise id", "not machine-readable",
                    "no checkable target"))
                block("lint" if authoring else "drift", "reconciliation",
                      f"`{d['object'] or '(no id)'}` {d['verdict']} unverifiable without "
                      f"an explicit manual/visual/runtime declaration: "
                      f"{d['reason'][:140]}", src,
                      "mark the decision [manual]/[visual], declare "
                      "scope: runtime in a manifest, or make it checkable")
    for conflict in recon["conflicts"]:
        touches = any(is_selected(s.rsplit(":", 1)[0])
                      for s in conflict["sources"])
        if touches or not strict:
            block("drift", "reconciliation",
                  f"`{conflict['object']}` has conflicting verdicts "
                  f"{conflict['verdicts']}", "; ".join(conflict["sources"]),
                  "resolve the presence-vs-absence conflict in the "
                  "checkpoints; no row is authoritative")
    for row in recon["malformed_rows"]:
        if is_selected(row["path"]) or not strict:
            block("malformed", "reconciliation", row["problem"],
                  f"{row['path']}:{row['line']}",
                  "fix the malformed decision record")

    # ---- evidence gate ---------------------------------------------------
    evidence = reports["evidence"]
    for doc in evidence["checkpoints"]:
        gated = is_selected(doc["checkpoint"]) or not strict
        for c in doc["citations"]:
            src = f"{doc['checkpoint']}:{c['line']}"
            if not gated:
                continue
            if c["status"] == "MISSING":
                block("evidence", "evidence",
                      f"cited artifact missing: `{c['cited']}`", src,
                      "attach the missing receipt/artifact or correct the "
                      "citation")
            elif c["status"] == "RECORDED_FAIL":
                block("evidence", "evidence",
                      f"artifact records FAILURE: `{c['resolved_path']}`",
                      src, "investigate the recorded failure; do not land "
                           "over failing evidence")
            elif c["status"] == "METADATA_MISMATCH":
                block("evidence", "evidence",
                      "; ".join(c["mismatches"])[:200], src,
                      "correct the mismatched metadata (frame counts, "
                      "resolution, outputs or commit)")
            elif c["status"] == "MALFORMED":
                block("malformed", "evidence",
                      "malformed evidence claim", src,
                      "fix the evidence manifest claim")
            elif c["status"] == "SYMBOLIC_ONLY":
                claimed_durable = (c["kind"] == "symbolic"
                                   and "receipt" in c["quote"].lower())
                debt.append({
                    "kind": ("claimed-durable-no-artifact" if claimed_durable
                             else "manual-assertion" if c["kind"] ==
                             "assertion" else "symbolic-evidence"),
                    "source": src,
                    "detail": (c["cited"] or c["quote"][:80])})
    for m in evidence["malformed"]:
        if is_selected(m["checkpoint"]) or not strict:
            block("malformed", "evidence", m["problem"],
                  f"{m['checkpoint']}:{m['line']}",
                  "fix the malformed evidence record")

    # ---- progress gate ---------------------------------------------------
    progress = reports["progress"]
    selected_rooms = sorted({r for r in selection["rooms"] if in_scope(r)})
    for room_record in progress["rooms"]:
        if room_record["room"] not in selected_rooms:
            continue
        if "DRIFT_RED" in room_record["states"]:
            block("drift", "progress",
                  f"room {room_record['room']} is DRIFT_RED in the ledger",
                  room_record["room"],
                  "resolve the contradiction feeding the ledger")
        if any("COMPLETE" in s for s in room_record["states"]):
            raise RuntimeError("ledger emitted a COMPLETE-like state; "
                               "toolchain invariant violated")
    return blockers, debt, selected_rooms


def gate_result(blockers, debt, deleted):
    categories = {b["category"] for b in blockers}
    if deleted:
        categories.add("review")
    if not categories:
        symbolic = any(d["kind"] in ("symbolic-evidence",
                                     "claimed-durable-no-artifact",
                                     "manual-assertion") for d in debt)
        return ("LANDABLE_WITH_SYMBOLIC_EVIDENCE" if symbolic
                else "LANDABLE")
    if categories == {"malformed"}:
        return "BLOCKED_MALFORMED"
    for category, label in (("drift", "BLOCKED_DRIFT"),
                            ("evidence", "BLOCKED_EVIDENCE"),
                            ("lint", "BLOCKED_LINT"),
                            ("review", "BLOCKED_REVIEW")):
        if category in categories:
            return label
    return "BLOCKED_MALFORMED"


def exit_code_for(result, blockers, deleted):
    if result == "BLOCKED_INTERNAL":
        return 70
    code = 0
    categories = {b["category"] for b in blockers}
    if (categories - {"malformed"}) or deleted:
        code |= 1
    if "malformed" in categories:
        code |= 4
    if code == 0 and result == "LANDABLE_WITH_SYMBOLIC_EVIDENCE":
        return 2
    return code


# ---------------------------------------------------------------------------
# Report emission
# ---------------------------------------------------------------------------

def summarize_counts(reports, is_selected):
    lint = {"READY": 0, "NEEDS_ATTENTION": 0}
    for doc_path, summary in reports["lint_docs"].items():
        if is_selected(doc_path):
            lint["READY"] += summary["ready"]
            lint["NEEDS_ATTENTION"] += summary["needs_attention"]
    recon = {s: 0 for s in ("SATISFIED", "OPEN", "CONTRADICTED",
                            "UNVERIFIABLE")}
    for room, rows in reports["reconciliation"]["decisions_by_room"].items():
        for d in rows:
            if is_selected(d["source"]["path"]):
                recon[d["status"]] += 1
    evidence = {s: 0 for s in ("RECORDED_PASS", "VERIFIED_PRESENT",
                               "SYMBOLIC_ONLY", "MISSING", "RECORDED_FAIL",
                               "METADATA_MISMATCH")}
    for doc in reports["evidence"]["checkpoints"]:
        if is_selected(doc["checkpoint"]):
            for c in doc["citations"]:
                if c["status"] in evidence:
                    evidence[c["status"]] += 1
    return {"lint": lint, "reconciliation": recon, "evidence": evidence}


def report_markdown(report):
    g = report["gate"]
    lines = [f"# Room reconstruction gate: {g['result']}", "",
             f"> {g['policy']}", "",
             f"- Selected checkpoints: "
             f"{', '.join(g['selection']['checkpoints']) or '(none)'}",
             f"- Selected rooms: "
             f"{', '.join(g['selection']['rooms']) or '(none resolved)'}",
             f"- Mode: {'strict new-checkpoint' if g['strict'] else 'whole-corpus (historical debt reported, not blocking)'}",
             f"- Result: **{g['result']}**  (exit {g['exit']})"]
    if g.get("commit"):
        lines.append(f"- Repository commit: `{g['commit'][:12]}`")
    if g.get("command"):
        lines.append(f"- Command: `{g['command']}`")
    c = report["counts"]
    lines += ["",
              f"- Lint: {c['lint']['READY']} READY / "
              f"{c['lint']['NEEDS_ATTENTION']} needing attention",
              f"- Reconciliation: {c['reconciliation']['SATISFIED']} "
              f"SATISFIED / {c['reconciliation']['OPEN']} OPEN / "
              f"{c['reconciliation']['CONTRADICTED']} CONTRADICTED / "
              f"{c['reconciliation']['UNVERIFIABLE']} UNVERIFIABLE",
              f"- Evidence: {c['evidence']['RECORDED_PASS']} recorded pass / "
              f"{c['evidence']['VERIFIED_PRESENT']} present / "
              f"{c['evidence']['SYMBOLIC_ONLY']} symbolic / "
              f"{c['evidence']['MISSING']} missing / "
              f"{c['evidence']['RECORDED_FAIL']} fail / "
              f"{c['evidence']['METADATA_MISMATCH']} mismatch"]
    if report["progress_states"]:
        lines += ["", "Progress states for selected rooms:", ""]
        for room, states in report["progress_states"].items():
            lines.append(f"- {room}: {', '.join(states)}")
    lines += ["", "## Blockers (priority order)", ""]
    if report["blockers"]:
        for b in report["blockers"]:
            lines.append(f"- [{b['category']}/{b['gate']}] {b['detail']}")
            lines.append(f"  - source: {b['source']}")
            lines.append(f"  - next: {b['next_action']}")
    else:
        lines.append("- none")
    if report["deleted_checkpoints"]:
        lines += ["", "## Deleted checkpoints (deliberate review required)",
                  ""]
        for d in report["deleted_checkpoints"]:
            lines.append(f"- {d}")
    lines += ["", "## Non-blocking debt", ""]
    if report["debt"]:
        for d in report["debt"][:40]:
            lines.append(f"- [{d['kind']}] {d['detail']}"
                         + (f" ({d['source']})" if d.get("source") else ""))
        if len(report["debt"]) > 40:
            lines.append(f"- ... {len(report['debt']) - 40} more in the "
                         "JSON report")
    else:
        lines.append("- none")
    lines += ["", "## Component reports", ""]
    for name, info in report["components"].items():
        lines.append(f"- {name}: exit {info['exit']} -> "
                     f"`components/{name}/`")
        if info.get("error"):
            lines.append(f"  - INTERNAL: {info['error']}")
            if info.get("stderr"):
                lines.append(f"  - stderr: {info['stderr'][-300:]}")
    return "\n".join(lines) + "\n"


# ---------------------------------------------------------------------------
# Orchestration
# ---------------------------------------------------------------------------

def run_gate(args, argv_echo):
    root = Path(args.repository_root)
    corpus_dir = Path(args.checkpoints) if args.checkpoints else \
        (root / "design")
    strict = not bool(args.corpus_mode)

    deleted = []
    if args.changed_since:
        if args.no_git:
            raise GateUsageError("--changed-since requires git; it cannot "
                                 "be combined with --no-git")
        selected_files, deleted = changed_since_selection(
            root, corpus_dir, args.changed_since)
        selected_paths = [rel(root / f, root) for f in selected_files]
        if not selected_paths and not deleted:
            selected_paths = []
    elif args.checkpoint:
        selected_paths = [rel(args.checkpoint, root)]
        if not Path(args.checkpoint).exists():
            raise GateUsageError(f"checkpoint not found: {args.checkpoint}")
    else:
        selected_paths = sorted(
            rel(p, root) for p in corpus_dir.rglob(rc.CHECKPOINT_GLOB)
        ) + sorted(
            rel(p, root) for pattern in ("*.decisions.json",
                                         "*.evidence.json")
            for p in corpus_dir.rglob(pattern))

    staging = Path(tempfile.mkdtemp(prefix="room_gate_"))
    components = {}
    reports = {}
    try:
        comp_dir = staging / "components"
        git_flag = ["--no-git"] if args.no_git else []

        # 1. lint (selected documents only)
        lint_out = comp_dir / "lint"
        lint_targets = ([args.checkpoint] if args.checkpoint
                        else [root / p for p in selected_paths]
                        if args.changed_since else [corpus_dir])
        lint_codes = []
        for target in lint_targets or [corpus_dir]:
            info = run_component("lint", [
                "--checkpoint", str(target), "--layout", str(args.layout),
                "--scaffold-output", str(lint_out), "--force"])
            lint_codes.append(info)
        components["lint"] = {
            "exit": max((i["exit"] for i in lint_codes), default=0),
            "error": next((i["error"] for i in lint_codes if i["error"]),
                          None),
            "stderr": "\n".join(i["stderr"] for i in lint_codes if
                                i["stderr"]),
        }
        lint_rows, lint_docs = lint_rows_by_source(lint_out)

        # 2. reconciliation (whole corpus: regeneration truth and conflicts)
        recon_out = comp_dir / "reconciliation"
        info = run_component("reconciliation", [
            "--layout", str(args.layout), "--checkpoints", str(corpus_dir),
            "--output", str(recon_out), *git_flag])
        components["reconciliation"] = {k: info[k] for k in
                                        ("exit", "error", "stderr")}
        reports["reconciliation"] = load_json(
            recon_out / "room_checkpoint_status.json")

        # 3. evidence
        ev_out = comp_dir / "evidence"
        info = run_component("evidence", [
            "--checkpoints", str(corpus_dir),
            "--repository-root", str(root), "--layout", str(args.layout),
            "--output", str(ev_out), *git_flag])
        components["evidence"] = {k: info[k] for k in
                                  ("exit", "error", "stderr")}
        reports["evidence"] = load_json(ev_out / "room_evidence_status.json")

        # 4. progress ledger with the evidence report
        prog_out = comp_dir / "progress"
        prog_args = ["--layout", str(args.layout),
                     "--checkpoints", str(corpus_dir),
                     "--output", str(prog_out), *git_flag,
                     "--evidence-report",
                     str(ev_out / "room_evidence_status.json")]
        if args.floor:
            prog_args += ["--floor", args.floor]
        if args.room:
            prog_args += ["--room", args.room]
        info = run_component("progress", prog_args)
        components["progress"] = {k: info[k] for k in
                                   ("exit", "error", "stderr")}
        reports["progress"] = load_json(
            prog_out / "room_reconstruction_progress.json")
        reports["lint_docs"] = lint_docs

        internal = [n for n, i in components.items()
                    if i["error"] or i["exit"] == 70]
        if internal:
            raise RuntimeError(f"component failure: {internal}")

        layout = load_json(args.layout)
        layout_rooms = {r["id"]: fl["id"] for fl in layout.get("floors", [])
                        for r in fl.get("rooms", [])}
        is_selected = make_selector(root, selected_paths)
        selected_rooms = sorted({
            room
            for doc in reports["evidence"]["checkpoints"]
            if is_selected(doc["checkpoint"])
            for room in doc["rooms"]} | {
            room
            for room, rows in
            reports["reconciliation"]["decisions_by_room"].items()
            if room in layout_rooms
            for d in rows if is_selected(d["source"]["path"])})
        selection = {"checkpoints": selected_paths, "rooms": selected_rooms}

        blockers, debt, scoped_rooms = evaluate(
            selection, strict, reports, lint_rows, lint_docs, is_selected,
            room_filter=args.room, floor_filter=args.floor,
            layout_rooms=layout_rooms)
        blockers.sort(key=lambda b: (
            {"drift": 0, "malformed": 1, "evidence": 2, "review": 3,
             "lint": 4}.get(b["category"], 9), b["source"], b["detail"]))
        debt.sort(key=lambda d: (d["kind"], d.get("source", ""),
                                 d["detail"]))
        result = gate_result(blockers, debt, deleted)
        code = exit_code_for(result, blockers, deleted)

        commit = None
        if not args.no_git:
            proc = subprocess.run(["git", "-C", str(root), "rev-parse",
                                   "HEAD"], capture_output=True, text=True,
                                  timeout=30)
            commit = proc.stdout.strip() if proc.returncode == 0 else None

        progress_states = {
            r["room"]: r["states"] for r in reports["progress"]["rooms"]
            if r["room"] in scoped_rooms}
        report = {
            "gate": {
                "result": result, "exit": code, "strict": strict,
                "policy": ("wrapper preserves the component tools' "
                           "conservative meanings; LANDABLE never means "
                           "visually complete, and artifact existence is "
                           "never a recorded pass"),
                "selection": dict(selection, floor=args.floor,
                                  room=args.room,
                                  changed_since=args.changed_since),
                "commit": commit,
                "command": argv_echo,
            },
            "counts": summarize_counts(reports, is_selected),
            "progress_states": progress_states,
            "blockers": blockers,
            "debt": debt,
            "deleted_checkpoints": deleted,
            "components": components,
        }
        return report, staging, code
    except (RuntimeError, OSError, json.JSONDecodeError, KeyError) as exc:
        report = {
            "gate": {"result": "BLOCKED_INTERNAL", "exit": 70,
                     "strict": strict,
                     "policy": "a component failed; no LANDABLE verdict is "
                               "published over a partial run",
                     "selection": {"checkpoints": selected_paths,
                                   "rooms": [], "floor": args.floor,
                                   "room": args.room,
                                   "changed_since": args.changed_since},
                     "commit": None, "command": argv_echo,
                     "failure": f"{type(exc).__name__}: {exc}"},
            "counts": {"lint": {"READY": 0, "NEEDS_ATTENTION": 0},
                       "reconciliation": {s: 0 for s in
                                          ("SATISFIED", "OPEN",
                                           "CONTRADICTED", "UNVERIFIABLE")},
                       "evidence": {s: 0 for s in
                                    ("RECORDED_PASS", "VERIFIED_PRESENT",
                                     "SYMBOLIC_ONLY", "MISSING",
                                     "RECORDED_FAIL", "METADATA_MISMATCH")}},
            "progress_states": {}, "blockers": [], "debt": [],
            "deleted_checkpoints": deleted,
            "components": components,
        }
        return report, staging, 70


def publish(report, staging, out_dir, force):
    """Atomic publication: preflight everything, then copy the packet."""
    out_dir.mkdir(parents=True, exist_ok=True)
    targets = [out_dir / "room_reconstruction_gate.json",
               out_dir / "room_reconstruction_gate.md"]
    components_src = staging / "components"
    components_dst = out_dir / "components"
    if components_dst.exists() and not force:
        raise FileExistsError(
            f"refusing to overwrite existing generated file(s): "
            f"{components_dst} (pass --force to overwrite)")
    wb.preflight_overwrite(targets, force)
    if components_dst.exists():
        shutil.rmtree(components_dst)
    if components_src.exists():
        shutil.copytree(components_src, components_dst)
    targets[0].write_text(json.dumps(report, indent=1, sort_keys=True) + "\n",
                          encoding="utf-8")
    targets[1].write_text(report_markdown(report), encoding="utf-8")
    return targets


def main(argv=None):
    parser = GateParser(
        description="One command to decide whether a room checkpoint is "
                    "landable (read-only; runs no Godot/Blender/tests)")
    parser.add_argument("--checkpoint", type=Path,
                        help="gate one checkpoint document (strict policy)")
    parser.add_argument("--changed-since", metavar="GIT_REF",
                        help="gate checkpoint/manifest documents changed "
                             "since this ref (strict policy)")
    parser.add_argument("--checkpoints", type=Path,
                        help="explicit whole-corpus audit of this directory "
                             "(historical-debt policy)")
    parser.add_argument("--layout", type=Path, default=DEFAULT_LAYOUT)
    parser.add_argument("--repository-root", type=Path, default=ROOT)
    parser.add_argument("--floor")
    parser.add_argument("--room")
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--json-only", action="store_true")
    parser.add_argument("--markdown-only", action="store_true")
    parser.add_argument("--force", action="store_true")
    parser.add_argument("--no-git", action="store_true")
    args = parser.parse_args(argv)

    # --checkpoints names the corpus ROOT (default <root>/design); it is a
    # selection MODE only when neither --checkpoint nor --changed-since is
    # given.  --checkpoint and --changed-since are mutually exclusive.
    if args.checkpoint and args.changed_since:
        print("error: --checkpoint and --changed-since are mutually "
              "exclusive", file=sys.stderr)
        return 3
    if not (args.checkpoint or args.changed_since or args.checkpoints):
        print("error: selection must be explicit - pass --checkpoint, "
              "--changed-since, or --checkpoints for a whole-corpus audit",
              file=sys.stderr)
        return 3
    args.corpus_mode = not (args.checkpoint or args.changed_since)

    argv_echo = "room_reconstruction_gate.py " + " ".join(
        str(a) for a in (argv if argv is not None else sys.argv[1:]))
    staging = None
    try:
        try:
            report, staging, code = run_gate(args, argv_echo)
        except GateUsageError as exc:
            print(f"error: {exc}", file=sys.stderr)
            return 3
        # honor --json-only/--markdown-only by publishing both gate files
        # only when requested (component reports always accompany a packet)
        try:
            targets = publish(report, staging, args.output, args.force)
        except FileExistsError as exc:
            print(f"error: {exc}", file=sys.stderr)
            return 3
        for t in targets:
            if args.json_only and t.suffix == ".md":
                t.unlink()
                continue
            if args.markdown_only and t.suffix == ".json":
                t.unlink()
                continue
            print(t)
        print(f"result={report['gate']['result']} -> exit {code}",
              file=sys.stderr)
        return code
    except Exception as exc:                # noqa: BLE001 - stable exit code
        print(f"internal failure: {type(exc).__name__}: {exc}",
              file=sys.stderr)
        return 70
    finally:
        if staging is not None:
            shutil.rmtree(staging, ignore_errors=True)


if __name__ == "__main__":
    sys.exit(main())
