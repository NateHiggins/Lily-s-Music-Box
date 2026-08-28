#!/usr/bin/env python3
"""T10 census audit: the interaction surface must not drift silently.

Source-only drift detector for the interaction-prompt implementor census
recorded in design/INTERACTION_CONTRACT_2026-08-27.md.  Every production
`interact_prompt` / `control_prompt` definition is classified in a
checked-in manifest (tools/interaction_implementor_manifest.json); this
audit compares source truth with that manifest and fails when the surface
changes without classification.

This is a DRIFT DETECTOR, not an engine interface: `has_method` dispatch
enforces spelling only, and the game intentionally runs on a stable
implicit protocol (contract SSA).  The manifest keeps the contract's census
true past its date; it authorizes nothing and refactors nothing.

Conservative relationship tracing (documented, testable):

  - same-file action methods (`interact`, `interact_control`,
    `interact_area`), at any indentation - inner-class implementors pair
    within their file, with a note;
  - inheritance through `extends ClassName` (resolved via `class_name`
    declarations) and `extends "res://...gd"` (resolved by path suffix);
  - parent delegation (`get_parent().interact...` inside the same-file
    action method);
  - the `PropControlArea` adapter pattern (invokes the parent mechanism's
    `control_prompt` and `interact_control`);
  - composed `interact_area` dispatch.

The two contract-resolved cases are preserved and pinned by tests:
`projector_prop.gd` inherits `TVProp.interact`; `wayfinding_signage_pass
.gd` composes through `interact_area`.  Neither is a prompt-without-action
defect.  No scene-tree or runtime reachability analysis is attempted; what
source tracing cannot establish is marked ACTION_UNRESOLVED.

Statuses: CLASSIFIED, UNCLASSIFIED, STALE, CLASSIFICATION_CHANGED,
ACTION_RESOLVED_SAME_FILE, ACTION_RESOLVED_INHERITED,
ACTION_RESOLVED_ADAPTER, ACTION_RESOLVED_COMPOSED, ACTION_UNRESOLVED,
DEBUG_ONLY, MALFORMED.

Exit codes (stable, tested):
  0   source and manifest agree
  1   source drift: unclassified implementor, stale entry, changed
      classification, missing adapter target, a named-control prompt
      without its `interact_control`, or a previously resolved
      relationship that no longer resolves
  4   malformed manifest (missing keys, invalid enums, duplicates)
  5   both 1 and 4
  3   usage error
  70  internal failure

An implementor deliberately removed from production is reported as STALE
with a cleanup instruction (rerun with --update-manifest after review);
stale entries are never accepted silently.

Usage:
  python tools/audit_interaction_implementors.py
      [--root game/scripts] [--manifest <json>] [--json] [--verbose]
      [--include-debug] [--update-manifest]
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_ROOT = ROOT / "game" / "scripts"
DEFAULT_MANIFEST = Path(__file__).resolve().parent / \
    "interaction_implementor_manifest.json"

FAMILIES = ("interact_prompt", "control_prompt")
ROLES = ("production", "debug-only", "adapter")
PROTOCOLS = ("whole-object", "named-control", "composed/interact-area")
ACTION_OWNERS = ("same node", "inherited base", "parent/delegate",
                 "adapter target", "intentionally non-player-driven",
                 "unresolved")
ACTION_METHODS = ("interact", "interact_control", "interact_area", "none")
EXTRACTIONS = ("game-only", "reusable-with-work", "infrastructure/adapter")

# Known non-production implementors (contract SSC.1); role defaults only -
# the manifest is authoritative and mismatches are reported as drift.
DEBUG_FILES = ("characters/npc_placeholder.gd",
               "building/light_debug_handle.gd")
ADAPTER_FILES = ("props/prop_control_area.gd",)

FUNC_RE = {
    "interact_prompt": re.compile(r"^\t*(?:static\s+)?func\s+interact_prompt\s*\(",
                                  re.M),
    "control_prompt": re.compile(r"^\t*(?:static\s+)?func\s+control_prompt\s*\(",
                                 re.M),
    "interact": re.compile(r"^\t*(?:static\s+)?func\s+interact\s*\(", re.M),
    "interact_control": re.compile(
        r"^\t*(?:static\s+)?func\s+interact_control\s*\(", re.M),
    "interact_area": re.compile(r"^\t*(?:static\s+)?func\s+interact_area\s*\(",
                                re.M),
}
CLASS_NAME_RE = re.compile(r"^class_name\s+([A-Za-z_]\w*)", re.M)
EXTENDS_RE = re.compile(r"^extends\s+(?:\"([^\"]+)\"|([A-Za-z_]\w*))", re.M)


# ---------------------------------------------------------------------------
# Source scanning
# ---------------------------------------------------------------------------

def scan_source(root):
    """Per-file interaction facts plus a class_name resolution map."""
    root = Path(root)
    files, class_map = {}, {}
    for path in sorted(root.rglob("*.gd")):
        rel = path.relative_to(root).as_posix()
        text = path.read_text(encoding="utf-8", errors="replace")
        defs = {name: bool(rx.search(text)) for name, rx in FUNC_RE.items()}
        indented_prompt = bool(re.search(
            r"^\t+(?:static\s+)?func\s+(?:interact_prompt|control_prompt)"
            r"\s*\(", text, re.M))
        m = EXTENDS_RE.search(text)
        extends_class = extends_path = None
        if m:
            if m.group(1):
                extends_path = m.group(1)
            else:
                extends_class = m.group(2)
        cm = CLASS_NAME_RE.search(text)
        if cm:
            class_map[cm.group(1)] = rel
        # Adapter delegation appears either as a direct call or as
        # string-dispatched `owner.call("control_prompt", ...)`.
        def _invokes(name):
            return bool(re.search(
                rf"(?:\.\s*{name}\s*\(|call\(\s*\"{name}\")", text))
        adapter_target = _invokes("control_prompt") \
            and _invokes("interact_control")
        parent_delegation = bool(re.search(
            r"func\s+interact\w*\s*\([^)]*\)[^\n]*:\n(?:[^\n]*\n){0,6}?"
            r"[^\n]*get_parent\(\)\.", text))
        files[rel] = {
            "defs": defs, "extends_class": extends_class,
            "extends_path": extends_path, "class_name":
                cm.group(1) if cm else None,
            "indented_prompt": indented_prompt,
            "adapter_target": adapter_target,
            "parent_delegation": parent_delegation,
        }
    return files, class_map


def resolve_extends(rel, files, class_map):
    """The parent file of `rel`, or None."""
    info = files.get(rel)
    if not info:
        return None
    if info["extends_class"] and info["extends_class"] in class_map:
        return class_map[info["extends_class"]]
    if info["extends_path"]:
        tail = info["extends_path"].removeprefix("res://")
        candidates = [f for f in files
                      if f == tail or f.endswith("/" + tail)
                      or f.endswith("/" + Path(tail).name)
                      or f == Path(tail).name]
        exact = [f for f in candidates if f == tail or f.endswith("/" + tail)]
        pool = exact or candidates
        if len(pool) == 1:
            return pool[0]
    return None


def trace_action(rel, family, files, class_map):
    """(status, action_method, source, note) for one implementor."""
    info = files[rel]
    action = "interact" if family == "interact_prompt" else "interact_control"
    if info["defs"][action]:
        note = ""
        if info["indented_prompt"]:
            note = ("inner-class implementor; same-file pairing assumed "
                    "(source tracing does not resolve inner-class scopes)")
        owner = "parent/delegate" if info["parent_delegation"] else "same node"
        return "ACTION_RESOLVED_SAME_FILE", action, rel, note, owner
    seen = set()
    current = rel
    while True:
        parent = resolve_extends(current, files, class_map)
        if not parent or parent in seen:
            break
        seen.add(parent)
        if files[parent]["defs"][action]:
            return ("ACTION_RESOLVED_INHERITED", action, parent,
                    f"inherited from {parent} via extends chain",
                    "inherited base")
        current = parent
    if family == "interact_prompt" and info["defs"]["interact_area"]:
        return ("ACTION_RESOLVED_COMPOSED", "interact_area", rel,
                "composed dispatch through interact_area", "same node")
    return ("ACTION_UNRESOLVED", "none", None,
            "no action method found in file, extends chain or composition; "
            "source tracing cannot establish the relationship",
            "unresolved")


def discover(root, include_debug=False):
    """All implementors with traced classification."""
    files, class_map = scan_source(root)
    implementors = []
    for rel in sorted(files):
        info = files[rel]
        for family in FAMILIES:
            if not info["defs"][family]:
                continue
            role = ("debug-only" if rel in DEBUG_FILES else
                    "adapter" if rel in ADAPTER_FILES else "production")
            status, method, source, note, owner = trace_action(
                rel, family, files, class_map)
            if role == "adapter":
                owner = "adapter target"
                method = "interact_control"
                source = "parent mechanism (runtime parent)"
                status = ("ACTION_RESOLVED_ADAPTER"
                          if info["adapter_target"] else "ACTION_UNRESOLVED")
                note = ("delegates prompt and action to the parent "
                        "mechanism's named-control protocol"
                        if info["adapter_target"] else
                        "adapter no longer invokes the parent's "
                        "control_prompt/interact_control")
            protocol = ("named-control" if family == "control_prompt"
                        else "composed/interact-area"
                        if status == "ACTION_RESOLVED_COMPOSED"
                        else "whole-object")
            implementors.append({
                "file": rel, "family": family, "method": family,
                "role": role, "protocol": protocol,
                "action_owner": owner, "action_method": method,
                "action_source": source, "action_status": status,
                "note": note,
                "adapter_target_present": info["adapter_target"],
            })
    return implementors


# ---------------------------------------------------------------------------
# Manifest
# ---------------------------------------------------------------------------

def build_manifest(implementors):
    entries = []
    for imp in implementors:
        extraction = ("infrastructure/adapter" if imp["role"] == "adapter"
                      else "game-only")
        entries.append({
            "file": imp["file"], "family": imp["family"],
            "method": imp["method"], "role": imp["role"],
            "protocol": imp["protocol"],
            "action_owner": imp["action_owner"],
            "action_method": imp["action_method"],
            "action_source": imp["action_source"],
            "rationale": imp["note"] or
                f"{imp['action_owner']} action ({imp['action_method']}) "
                "resolved by source tracing",
            "extraction": extraction,
            "identity": {"file": imp["file"], "family": imp["family"]},
        })
    entries.sort(key=lambda e: (e["file"], e["family"]))
    return {
        "version": 1,
        "contract": "design/INTERACTION_CONTRACT_2026-08-27.md (T10)",
        "policy": ("drift detector, not an interface; classifications "
                   "authorize nothing.  Extraction dispositions are "
                   "defaults for the post-EA boundary review."),
        "entries": entries,
    }


class ManifestError(Exception):
    pass


def load_manifest(path):
    if not Path(path).exists():
        raise ManifestError(f"manifest not found: {path} "
                            "(generate one with --update-manifest)")
    try:
        data = json.loads(Path(path).read_text(encoding="utf-8"))
        entries = data["entries"]
    except (OSError, json.JSONDecodeError, KeyError, TypeError) as exc:
        raise ManifestError(f"unreadable manifest {path}: {exc}")
    problems = []
    seen = set()
    for n, e in enumerate(entries):
        missing = [k for k in ("file", "family", "role", "protocol",
                               "action_owner", "action_method") if k not in e]
        if missing:
            problems.append(f"entry {n}: missing keys {missing}")
            continue
        if e["family"] not in FAMILIES:
            problems.append(f"entry {n}: invalid family {e['family']!r}")
        if e["role"] not in ROLES:
            problems.append(f"entry {n}: invalid role {e['role']!r}")
        if e["protocol"] not in PROTOCOLS:
            problems.append(f"entry {n}: invalid protocol "
                            f"{e['protocol']!r}")
        if e["action_owner"] not in ACTION_OWNERS:
            problems.append(f"entry {n}: invalid action_owner "
                            f"{e['action_owner']!r}")
        if e["action_method"] not in ACTION_METHODS:
            problems.append(f"entry {n}: invalid action_method "
                            f"{e['action_method']!r}")
        key = (e["file"], e["family"])
        if key in seen:
            problems.append(f"entry {n}: duplicate implementor "
                            f"{key[0]} / {key[1]}")
        seen.add(key)
    return entries, problems


# ---------------------------------------------------------------------------
# Comparison
# ---------------------------------------------------------------------------

def compare(implementors, entries):
    by_key_src = {(i["file"], i["family"]): i for i in implementors}
    by_key_man = {(e["file"], e["family"]): e for e in entries}

    unclassified = sorted(k for k in by_key_src if k not in by_key_man)
    stale = sorted(k for k in by_key_man if k not in by_key_src)
    family_flips = sorted(
        {f for f, _ in unclassified} & {f for f, _ in stale})

    changed, resolved_required_failures = [], []
    for key in sorted(set(by_key_src) & set(by_key_man)):
        src, man = by_key_src[key], by_key_man[key]
        diffs = []
        for field in ("role", "protocol", "action_owner", "action_method"):
            if man[field] != src[field]:
                # A manifest may deliberately keep 'unresolved' for a
                # whole-object implementor tracing cannot prove; every other
                # divergence is drift.
                if field == "action_owner" \
                        and man[field] == "unresolved" \
                        and src["action_status"] == "ACTION_UNRESOLVED":
                    continue
                diffs.append(f"{field}: manifest {man[field]!r} vs source "
                             f"{src[field]!r}")
        man_source = man.get("action_source")
        if man_source and src["action_source"] \
                and man_source != src["action_source"]:
            diffs.append(f"action_source: manifest {man_source!r} vs "
                         f"source {src['action_source']!r}")
        if diffs:
            changed.append({"file": key[0], "family": key[1],
                            "differences": diffs})
        if src["role"] == "adapter" and not src["adapter_target_present"]:
            resolved_required_failures.append(
                {"file": key[0], "family": key[1],
                 "problem": "adapter lost its declared target (no parent "
                            "control_prompt/interact_control invocation)"})
        if key[1] == "control_prompt" \
                and src["action_status"] == "ACTION_UNRESOLVED":
            resolved_required_failures.append(
                {"file": key[0], "family": key[1],
                 "problem": "named-control prompt without a resolvable "
                            "interact_control relationship"})
        if man.get("action_owner") in ("inherited base", "parent/delegate") \
                and src["action_status"] == "ACTION_UNRESOLVED":
            resolved_required_failures.append(
                {"file": key[0], "family": key[1],
                 "problem": "previously resolved action relationship no "
                            "longer resolves"})
    return {"unclassified": unclassified, "stale": stale,
            "family_flips": family_flips, "changed": changed,
            "required_failures": resolved_required_failures}


def summarize(implementors, entries, diff):
    def count(seq, key):
        out = {}
        for item in seq:
            out[item[key]] = out.get(item[key], 0) + 1
        return dict(sorted(out.items()))
    return {
        "discovered": len(implementors),
        "manifest": len(entries),
        "by_family": count(implementors, "family"),
        "by_role": count(implementors, "role"),
        "by_protocol": count(implementors, "protocol"),
        "by_action_status": count(implementors, "action_status"),
        "unclassified": len(diff["unclassified"]),
        "stale": len(diff["stale"]),
        "changed_classifications": len(diff["changed"]),
        "required_relationship_failures": len(diff["required_failures"]),
        "family_flips": len(diff["family_flips"]),
        "totals_agree": len(implementors) == len(entries),
    }


def exit_code(summary, manifest_problems):
    code = 0
    if (summary["unclassified"] or summary["stale"]
            or summary["changed_classifications"]
            or summary["required_relationship_failures"]
            or not summary["totals_agree"]):
        code |= 1
    if manifest_problems:
        code |= 4
    return code


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def main(argv=None):
    parser = argparse.ArgumentParser(
        description="T10 source-only census drift audit for interaction "
                    "prompt implementors")
    parser.add_argument("--root", type=Path, default=DEFAULT_ROOT)
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    parser.add_argument("--update-manifest", action="store_true",
                        help="rewrite the manifest from current source "
                             "truth (explicit only; review the diff)")
    parser.add_argument("--include-debug", action="store_true",
                        help="no effect on discovery (debug files are "
                             "always classified); reserved for symmetry "
                             "with the carrier audit")
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--verbose", action="store_true")
    args = parser.parse_args(argv)

    try:
        if not args.root.is_dir():
            print(f"error: root not found: {args.root}", file=sys.stderr)
            return 3
        implementors = discover(args.root,
                                include_debug=args.include_debug)
        if args.update_manifest:
            manifest = build_manifest(implementors)
            args.manifest.write_text(
                json.dumps(manifest, indent=1, sort_keys=True) + "\n",
                encoding="utf-8")
            print(f"manifest updated: {args.manifest} "
                  f"({len(manifest['entries'])} entries)")
        try:
            entries, problems = load_manifest(args.manifest)
        except ManifestError as exc:
            print(f"error: {exc}", file=sys.stderr)
            return 3
        diff = compare(implementors, entries)
        summary = summarize(implementors, entries, diff)
        code = exit_code(summary, problems)

        if args.json:
            print(json.dumps({
                "summary": summary, "exit": code,
                "unclassified": [list(k) for k in diff["unclassified"]],
                "stale": [list(k) for k in diff["stale"]],
                "family_flips": diff["family_flips"],
                "changed": diff["changed"],
                "required_failures": diff["required_failures"],
                "manifest_problems": problems,
                "implementors": (implementors if args.verbose else
                                 len(implementors)),
            }, indent=1, sort_keys=True))
            return code

        print("interaction implementor census audit (T10 drift detector)")
        for key, value in summary.items():
            print(f"- {key}: {value}")
        for k in diff["unclassified"]:
            print(f"UNCLASSIFIED {k[0]} / {k[1]} - a new implementor "
                  "appeared; classify it in the manifest deliberately")
        for k in diff["stale"]:
            print(f"STALE {k[0]} / {k[1]} - implementor no longer exists; "
                  "if removal was deliberate, rerun with --update-manifest "
                  "after review")
        for f in diff["family_flips"]:
            print(f"FAMILY CHANGED {f} - prompt family flipped; reconcile "
                  "the manifest")
        for c in diff["changed"]:
            print(f"CLASSIFICATION_CHANGED {c['file']} / {c['family']}: "
                  + "; ".join(c["differences"]))
        for f in diff["required_failures"]:
            print(f"REQUIRED {f['file']} / {f['family']}: {f['problem']}")
        for p in problems:
            print(f"MALFORMED MANIFEST: {p}")
        if args.verbose:
            for imp in implementors:
                print(f"  {imp['file']:48} {imp['family']:16} "
                      f"{imp['role']:10} {imp['protocol']:22} "
                      f"{imp['action_status']}")
        print(f"-> exit {code}")
        return code
    except Exception as exc:                # noqa: BLE001 - stable exit code
        print(f"internal failure: {type(exc).__name__}: {exc}",
              file=sys.stderr)
        return 70


if __name__ == "__main__":
    sys.exit(main())
