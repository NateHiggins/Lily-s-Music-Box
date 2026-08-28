#!/usr/bin/env python3
"""Opt-in pre-commit runner for the room reconstruction gate.

Runs tools/room_reconstruction_gate.py against the EXACT staged Git index -
not the working tree, not HEAD, not origin/main - so a reconstruction commit
is gated on precisely what Git would commit.  Nothing here installs itself:
the developer must wire it into .git/hooks/pre-commit deliberately (see
--print-hook and design/ROOM_GATE_HOOK_GUIDE.md).  The runner never
modifies the index, the working tree, Git configuration or any hook.

Staged-snapshot design
======================

1. Staged paths come from `git diff --cached --name-status` (against HEAD,
   or the empty tree before the first commit).
2. Relevant inputs are: design/ORISON_*CHECKPOINT*.md, design *.decisions
   .json / *.evidence.json manifests, the authoritative layout/generator
   inputs (art/data/building_layout.json, art/data/gen_layout.py,
   game/data/building_layout.json), and spatial-tool sources
   (tools/room_*.py, tools/audit_orison_rooms.py).  Unrelated staged files
   (renders, audio, scenes...) never trigger the hook.
3. A staged DELETION of a checkpoint document blocks as a mandatory review
   condition.
4. The index is materialized with `git ls-files -z | git checkout-index -z
   --stdin --prefix=<snapshot>/` for the directories the gate reads:
   design/, art/data/, game/data/, game/scripts/, game/docs/, tools/, and
   the checkpoint evidence root art/renders/orison_room_reconstruction/
   (~120 MB, exact index content).  The remaining art/renders/* subtrees
   (~4 GB of unrelated render history) are bridged into the snapshot as
   directory links; any index-vs-worktree divergence under art/renders is
   detected via `git status --porcelain` and reported.  `.git` is never
   copied or exposed.
5. The gate runs as a subprocess against the snapshot (`--repository-root
   <snapshot> --no-git`), preferring the SNAPSHOT's own
   tools/room_reconstruction_gate.py when present - so staged tool changes
   gate with their staged versions - and falling back to this runner's
   sibling gate otherwise (reported).
6. Selection: staged checkpoints/manifests are gated strictly (repeatable
   --checkpoint), each joined by its same-stem sibling manifests already in
   the index.  When ONLY layout/generator/tool inputs are staged, a
   whole-corpus safety gate runs instead, and the output states plainly
   that no new checkpoint accompanies the change - it does not pretend a
   strict checkpoint gate occurred.
7. The gate packet is preserved (default: a reported temporary directory;
   --keep-packet chooses where).  The snapshot is cleaned up unless
   --keep-snapshot; links are detached before removal, and if cleanup
   fails the exact path is reported rather than force-deleting an
   uncertain target.

Hook policy
===========

Allowed  (hook exit 0): gate exit 0 (LANDABLE) and gate exit 2
                        (LANDABLE_WITH_SYMBOLIC_EVIDENCE - symbolic debt is
                        reported, not blocking).
Blocking (hook exit = gate exit): 1 lint/drift/evidence/review blockers,
                        4 malformed data, 5 both, 70 internal failure.
Also blocking: staged checkpoint deletion (exit 1), inability to construct
a trustworthy snapshot (exit 70), usage/configuration errors (exit 3).
--advisory reports the real gate result and then always exits 0; its output
is clearly labelled ADVISORY.

Usage:
  python tools/room_gate_hook.py [--advisory] [--verbose]
      [--keep-packet DIR] [--keep-snapshot] [--repository-root DIR]
      [--no-color] [--print-hook]
"""

from __future__ import annotations

import argparse
import fnmatch
import json
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
EMPTY_TREE = "4b825dc642cb6eb9a060e54bf8d69288fbee4904"

SNAPSHOT_DIRS = ("design", "art/data", "game/data", "game/scripts",
                 "game/docs", "tools", "art/renders/orison_room_reconstruction")
EVIDENCE_ROOT = "art/renders"
EVIDENCE_EXACT = "orison_room_reconstruction"

CHECKPOINT_PATTERN = "ORISON_*CHECKPOINT*.md"
MANIFEST_PATTERNS = ("*.decisions.json", "*.evidence.json")
LAYOUT_INPUTS = ("art/data/building_layout.json", "art/data/gen_layout.py",
                 "game/data/building_layout.json")
TOOL_PATTERNS = ("tools/room_*.py", "tools/audit_orison_rooms.py")

SAMPLE_HOOK = """#!/bin/sh
# Opt-in room reconstruction gate (pre-commit).  Installed deliberately by a
# developer; remove this file to uninstall.  See
# design/ROOM_GATE_HOOK_GUIDE.md.
exec python "$(git rev-parse --show-toplevel)/tools/room_gate_hook.py"
"""


class HookError(Exception):
    """Usage/configuration problem -> exit 3."""


class SnapshotError(Exception):
    """Untrustworthy snapshot -> exit 70."""


def git(root, *args, binary=False):
    proc = subprocess.run(["git", "-C", str(root), *args],
                          capture_output=True, timeout=120)
    out = proc.stdout if binary else proc.stdout.decode("utf-8",
                                                        errors="replace")
    err = proc.stderr.decode("utf-8", errors="replace")
    return proc.returncode, out, err


# ---------------------------------------------------------------------------
# Staged inspection
# ---------------------------------------------------------------------------

def staged_entries(root):
    """[(status, path)] from the index, against HEAD or the empty tree."""
    code, _, _ = git(root, "rev-parse", "--verify", "HEAD")
    base = "HEAD" if code == 0 else EMPTY_TREE
    code, out, err = git(root, "diff", "--cached", "--name-status", "-z",
                         base)
    if code != 0:
        raise HookError(f"git diff --cached failed: {err.strip()}")
    fields = [f for f in out.split("\0") if f]
    entries, i = [], 0
    while i < len(fields):
        status = fields[i]
        if status.startswith(("R", "C")) and i + 2 < len(fields):
            entries.append((status[0], fields[i + 2].replace("\\", "/")))
            i += 3
        elif i + 1 < len(fields):
            entries.append((status[0], fields[i + 1].replace("\\", "/")))
            i += 2
        else:
            break
    return entries


def classify_staged(entries):
    """Split staged paths into the classes the hook reacts to."""
    result = {"checkpoints": [], "manifests": [], "layout": [],
              "tools": [], "deleted_checkpoints": [], "other": []}
    for status, path in entries:
        name = Path(path).name
        is_checkpoint = (path.startswith("design/")
                         and fnmatch.fnmatchcase(name, CHECKPOINT_PATTERN))
        is_manifest = (path.startswith("design/") and any(
            fnmatch.fnmatchcase(name, p) for p in MANIFEST_PATTERNS))
        if is_checkpoint and status == "D":
            result["deleted_checkpoints"].append(path)
        elif is_checkpoint:
            result["checkpoints"].append(path)
        elif is_manifest and status != "D":
            result["manifests"].append(path)
        elif is_manifest:                       # deleted manifest: review too
            result["deleted_checkpoints"].append(path)
        elif path in LAYOUT_INPUTS and status != "D":
            result["layout"].append(path)
        elif any(fnmatch.fnmatchcase(path, p) for p in TOOL_PATTERNS) \
                and status != "D":
            result["tools"].append(path)
        else:
            result["other"].append(path)
    for key in result:
        result[key] = sorted(set(result[key]))
    return result


def associated_manifests(selection, index_paths):
    """Same-stem sibling checkpoints/manifests already present in the index."""
    out = set(selection)
    for path in list(selection):
        name = Path(path).name
        parent = str(Path(path).parent).replace("\\", "/")
        stem = name
        for suffix in (".md", ".decisions.json", ".evidence.json"):
            if stem.endswith(suffix):
                stem = stem[: -len(suffix)]
                break
        for suffix in (".md", ".decisions.json", ".evidence.json"):
            sibling = f"{parent}/{stem}{suffix}"
            if sibling in index_paths:
                out.add(sibling)
    return sorted(out)


# ---------------------------------------------------------------------------
# Index snapshot
# ---------------------------------------------------------------------------

def make_link(target, link):
    """Directory link: junction on Windows, symlink elsewhere."""
    if os.name == "nt":
        import _winapi
        _winapi.CreateJunction(str(target), str(link))
    else:
        os.symlink(str(target), str(link), target_is_directory=True)


def detach_links(snapshot):
    """Remove directory links without touching their targets."""
    bridge = Path(snapshot) / EVIDENCE_ROOT
    if not bridge.is_dir():
        return
    for entry in bridge.iterdir():
        try:
            is_link = entry.is_symlink() or (
                os.name == "nt" and hasattr(os.path, "isjunction")
                and os.path.isjunction(entry))
        except OSError:
            is_link = False
        if is_link:
            os.rmdir(entry) if entry.is_dir() else entry.unlink()


def build_snapshot(root, snapshot):
    """Materialize the staged index for the gate's inputs.  Never touches
    the real worktree, never copies .git."""
    snapshot = Path(snapshot)
    code, listing, err = git(root, "ls-files", "-z", "--", *SNAPSHOT_DIRS)
    if code != 0:
        raise SnapshotError(f"git ls-files failed: {err.strip()}")
    proc = subprocess.run(
        ["git", "-C", str(root), "checkout-index", "-z", "--stdin",
         f"--prefix={snapshot}{os.sep}"],
        input=listing.encode("utf-8"), capture_output=True, timeout=600)
    if proc.returncode != 0:
        raise SnapshotError("git checkout-index failed: "
                            + proc.stderr.decode(errors="replace").strip())
    layout = snapshot / "art" / "data" / "building_layout.json"
    if not layout.exists():
        raise SnapshotError("snapshot is missing the authoritative layout "
                            "JSON; refusing to gate an untrustworthy "
                            "snapshot")
    try:
        json.loads(layout.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise SnapshotError(f"staged layout JSON is unreadable: {exc}")

    # Bridge the rest of art/renders (unrelated multi-GB render history)
    # with directory links; exact index content covers the checkpoint
    # evidence root above.
    bridge_warnings = []
    real_renders = Path(root) / EVIDENCE_ROOT
    snap_renders = snapshot / EVIDENCE_ROOT
    if real_renders.is_dir():
        snap_renders.mkdir(parents=True, exist_ok=True)
        for entry in sorted(real_renders.iterdir()):
            if entry.name == EVIDENCE_EXACT or not entry.is_dir():
                continue
            link = snap_renders / entry.name
            if link.exists():
                continue
            try:
                make_link(entry, link)
            except OSError as exc:
                bridge_warnings.append(
                    f"evidence bridge unavailable for {EVIDENCE_ROOT}/"
                    f"{entry.name}: {exc}")
    code, status_out, _ = git(root, "status", "--porcelain", "--",
                              EVIDENCE_ROOT)
    divergence = [line for line in status_out.splitlines()
                  if line.strip() and not line.startswith("??")]
    return bridge_warnings, divergence


# ---------------------------------------------------------------------------
# Gate invocation
# ---------------------------------------------------------------------------

def run_gate(snapshot, selection, corpus_only, packet_dir, verbose):
    snapshot = Path(snapshot)
    snap_gate = snapshot / "tools" / "room_reconstruction_gate.py"
    gate_tool = snap_gate if snap_gate.exists() else \
        HERE / "room_reconstruction_gate.py"
    argv = [sys.executable, str(gate_tool),
            "--repository-root", str(snapshot),
            "--layout", str(snapshot / "art" / "data"
                            / "building_layout.json"),
            "--checkpoints", str(snapshot / "design"),
            "--output", str(packet_dir), "--no-git", "--force"]
    if not corpus_only:
        for path in selection:
            argv += ["--checkpoint", str(snapshot / path)]
    proc = subprocess.run(argv, capture_output=True, text=True, timeout=1800)
    gate_exit = proc.returncode
    report = None
    report_path = Path(packet_dir) / "room_reconstruction_gate.json"
    if report_path.exists():
        try:
            report = json.loads(report_path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            report = None
    return {"exit": gate_exit, "report": report,
            "tool": ("staged snapshot tools" if gate_tool == snap_gate
                     else "working-tree tools (snapshot has none)"),
            "stdout": proc.stdout, "stderr": proc.stderr}


# ---------------------------------------------------------------------------
# Output
# ---------------------------------------------------------------------------

def paint(text, color, enabled):
    codes = {"green": "32", "red": "31", "yellow": "33"}
    if not enabled:
        return text
    return f"\x1b[{codes[color]}m{text}\x1b[0m"


def summarize(out, staged, selection, corpus_only, gate, packet_dir,
              snapshot_note, warnings, advisory, color):
    result = (gate["report"] or {}).get("gate", {}).get("result",
                                                        "(no report)")
    blockers = (gate["report"] or {}).get("blockers", [])
    debt = (gate["report"] or {}).get("debt", [])
    ok = gate["exit"] in (0, 2)
    print("room-gate pre-commit " + ("(ADVISORY MODE: reporting only, "
          "exit forced to 0)" if advisory else ""), file=out)
    print(f"- staged relevant paths: "
          f"{', '.join(staged) or '(none)'}", file=out)
    if corpus_only:
        print("- selection: NO checkpoint staged with this layout/"
              "generator/tool change; ran the whole-corpus safety gate "
              "(this is not a strict checkpoint gate)", file=out)
    else:
        print(f"- selected checkpoints/manifests: {', '.join(selection)}",
              file=out)
    print(f"- snapshot source: exact Git index export ({snapshot_note}); "
          f"gate ran with {gate['tool']}", file=out)
    verdict = f"{result} (gate exit {gate['exit']})"
    print("- gate result: "
          + paint(verdict, "green" if ok else "red", color), file=out)
    if blockers:
        print(f"- blockers ({len(blockers)}):", file=out)
        for b in blockers[:8]:
            print(f"    [{b['category']}/{b['gate']}] {b['detail'][:110]}",
                  file=out)
            print(f"      next: {b['next_action'][:110]}", file=out)
        if len(blockers) > 8:
            print(f"    ... {len(blockers) - 8} more in the packet", file=out)
    symbolic = [d for d in debt if d["kind"] in
                ("symbolic-evidence", "claimed-durable-no-artifact",
                 "manual-assertion")]
    if symbolic:
        print(f"- symbolic evidence debt: {len(symbolic)} item(s) "
              "(reported, not blocking)", file=out)
    for w in warnings:
        print("- " + paint(f"warning: {w}", "yellow", color), file=out)
    print(f"- full gate packet: {packet_dir}", file=out)
    print("- the real Git index and working tree were not modified",
          file=out)


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def main(argv=None):
    parser = argparse.ArgumentParser(
        description="Opt-in pre-commit runner: gate the exact staged index "
                    "with the room reconstruction gate")
    parser.add_argument("--repository-root", type=Path)
    parser.add_argument("--advisory", action="store_true",
                        help="report the real gate result but always exit 0")
    parser.add_argument("--verbose", action="store_true")
    parser.add_argument("--keep-packet", type=Path,
                        help="directory for the gate packet (default: a "
                             "reported temporary directory)")
    parser.add_argument("--keep-snapshot", action="store_true",
                        help="keep the index snapshot for diagnosis")
    parser.add_argument("--no-color", action="store_true")
    parser.add_argument("--print-hook", action="store_true",
                        help="print the sample opt-in pre-commit script and "
                             "exit (installs nothing)")
    args = parser.parse_args(argv)
    out = sys.stdout
    color = (not args.no_color) and hasattr(out, "isatty") and out.isatty()

    if args.print_hook:
        print(SAMPLE_HOOK, end="")
        return 0

    snapshot = None
    try:
        root = args.repository_root or Path.cwd()
        code, top, err = git(root, "rev-parse", "--show-toplevel")
        if code != 0:
            raise HookError(f"not a git repository: {root} ({err.strip()})")
        root = Path(top.strip())

        entries = staged_entries(root)
        staged = classify_staged(entries)
        relevant = (staged["checkpoints"] + staged["manifests"]
                    + staged["layout"] + staged["tools"])
        if staged["deleted_checkpoints"]:
            print("room-gate pre-commit: BLOCKED", file=out)
            print(f"- staged DELETION of checkpoint/manifest documents: "
                  f"{', '.join(staged['deleted_checkpoints'])}", file=out)
            print("- deleting recorded room decisions requires deliberate "
                  "review; commit the deletion only after that review, or "
                  "unstage it", file=out)
            print("- the real Git index and working tree were not modified",
                  file=out)
            return 0 if args.advisory else 1
        if not relevant:
            print("room-gate pre-commit: no room-reconstruction inputs "
                  "staged; nothing to gate (skipped cleanly)", file=out)
            return 0

        _, ls_out, _ = git(root, "ls-files", "-z", "--", "design")
        index_paths = {p.replace("\\", "/") for p in ls_out.split("\0") if p}
        selection = associated_manifests(
            staged["checkpoints"] + staged["manifests"], index_paths)
        corpus_only = not selection

        snapshot = Path(tempfile.mkdtemp(prefix="room_gate_snapshot_"))
        bridge_warnings, divergence = build_snapshot(root, snapshot)
        packet_dir = args.keep_packet or Path(
            tempfile.mkdtemp(prefix="room_gate_packet_"))
        Path(packet_dir).mkdir(parents=True, exist_ok=True)

        gate = run_gate(snapshot, selection, corpus_only, packet_dir,
                        args.verbose)
        warnings = list(bridge_warnings)
        if divergence:
            warnings.append(
                f"{len(divergence)} index-vs-worktree difference(s) under "
                f"{EVIDENCE_ROOT} (bridged evidence outside the exact "
                "orison_room_reconstruction export may differ from the "
                "index)")
        if staged["tools"]:
            warnings.append("spatial tool sources are staged; the gate ran "
                            f"with {gate['tool']}")
        if gate["report"] is None:
            warnings.append("gate produced no readable report; treating as "
                            "internal failure")
            gate["exit"] = 70

        summarize(out, relevant, selection, corpus_only, gate, packet_dir,
                  f"{snapshot}", warnings, args.advisory, color)
        if args.verbose:
            print("--- gate stdout ---", file=out)
            print(gate["stdout"], file=out)
            print("--- gate stderr ---", file=out)
            print(gate["stderr"], file=out)
        return 0 if args.advisory else (0 if gate["exit"] in (0, 2)
                                        else gate["exit"])
    except HookError as exc:
        print(f"room-gate pre-commit: configuration error: {exc}",
              file=sys.stderr)
        return 0 if args.advisory else 3
    except SnapshotError as exc:
        print(f"room-gate pre-commit: cannot construct a trustworthy "
              f"staged snapshot: {exc}", file=sys.stderr)
        return 0 if args.advisory else 70
    except Exception as exc:                # noqa: BLE001 - stable exit code
        print(f"room-gate pre-commit: internal failure: "
              f"{type(exc).__name__}: {exc}", file=sys.stderr)
        return 0 if args.advisory else 70
    finally:
        if snapshot is not None and not args.keep_snapshot:
            try:
                detach_links(snapshot)
                shutil.rmtree(snapshot)
            except OSError:
                print(f"note: could not fully clean the snapshot; inspect "
                      f"and remove it manually: {snapshot}",
                      file=sys.stderr)
        elif snapshot is not None:
            print(f"note: snapshot kept for diagnosis: {snapshot}",
                  file=sys.stderr)


if __name__ == "__main__":
    sys.exit(main())
