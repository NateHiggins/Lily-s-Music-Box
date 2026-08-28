#!/usr/bin/env python3
"""T2 carrier audit: input carriers belong to the player, not the props.

Source-only audit of production `interact_prompt` and `control_prompt`
definitions under game/scripts.  The player/controller owns the input
carrier (`format_interaction_prompt` strips a legacy leading `[E]`/`[A]`/
`[TAP]` and prepends the active device's own); props and interaction owners
supply semantic action text.  This audit proves, at source level, that
prompt-returning methods do not author controller glyphs, touch carriers,
keyboard key names or mouse-button instructions - and it locks the existing
legacy `[E]` debt against multiplication via a checked-in baseline.

This is a HEURISTIC source scan, not GDScript semantic analysis:

  - method bodies are recovered by indentation; every string literal inside
    a prompt method's body (including literals assigned to locals that are
    later returned, ternary branches, concatenations and format strings) is
    treated as prompt content - a deliberate over-approximation on the safe
    side, applied only inside prompt methods;
  - file-level constants referenced from a prompt method contribute their
    literals too;
  - comments inside a prompt method are scanned separately and reported as
    COMMENT_ONLY (never failing);
  - a return whose value cannot be resolved statically (helper calls,
    non-literal formats) is reported as AMBIGUOUS_DYNAMIC (never failing;
    review by hand);
  - carrier-looking strings elsewhere in a scanned file are reported as
    NOT_A_PROMPT_RETURN in verbose output only.

Inherited implementations need no special handling here: prompt CONTENT
lives at its defining method, and this audit visits every definition.
Adapter infrastructure (props/prop_control_area.gd) and the two known
debug-only implementations are classified, not failed.

Classifications:
  CLEAN, LEGACY_E, FORBIDDEN_CONTROLLER, FORBIDDEN_TOUCH,
  FORBIDDEN_KEYBOARD, FORBIDDEN_MOUSE, FORBIDDEN_OTHER,
  AMBIGUOUS_DYNAMIC, COMMENT_ONLY, DEBUG_ONLY, NOT_A_PROMPT_RETURN

Carrier vocabulary (documented, testable):
  - a LEADING bracketed token classifies strongly: `[E]` is LEGACY_E;
    `[A]`/`[B]`/`[X]`/`[Y]`/sticks/bumpers/triggers are controller;
    `[TAP]`/`[HOLD]`/`[SWIPE]` are touch; `[SPACE]`/`[ENTER]`/`[F]`/other
    key names are keyboard; `[LMB]`/`[RMB]` are mouse; unknown bracket
    tokens are FORBIDDEN_OTHER;
  - known controller glyph characters anywhere in the string are
    controller carriers;
  - an INSTRUCTIONAL phrase requires an instruction verb bound to a KEY OR
    BUTTON NAME: "Press E", "press Escape", "hold Shift", "left click".
    "Press the carriage lever" and "Enter the apartment" are semantic
    prose and stay CLEAN - ambiguous key names (Enter, Escape, Space,
    Shift, Tab, Ctrl, Alt, E, F...) are never flagged without that
    instructional or bracket context, and period-fiction labels or object
    names are never flagged for sharing a key word.

Legacy `[E]` policy: every current occurrence is enumerated in the
checked-in baseline (tools/interaction_prompt_carrier_baseline.json) with a
line-independent identity (file, method, exact literal).  The audit FAILS
when a legacy occurrence appears that the baseline does not cover, when a
baseline literal turns into another device carrier, or when a baseline
entry goes stale (its file or method no longer exists).  A cleanly removed
legacy occurrence is reported as a baseline cleanup opportunity and does
NOT fail.  The baseline never covers `[A]`, `[TAP]`, glyphs or named
keyboard/mouse instructions.

Exit codes (stable, tested):
  0   clean (covered legacy, ambiguous-dynamic, comments, debug-only and
      cleanup opportunities are all reported without failing)
  1   forbidden carrier in a production prompt method, or a legacy `[E]`
      occurrence not covered by the baseline
  4   stale baseline entries (file or method vanished; update or clean the
      baseline deliberately)
  5   both 1 and 4
  3   malformed baseline or usage error
  70  internal failure

Usage:
  python tools/audit_interaction_prompt_carriers.py
      [--root game/scripts] [--json] [--baseline <manifest>]
      [--update-baseline] [--include-debug] [--verbose]
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_ROOT = ROOT / "game" / "scripts"
DEFAULT_BASELINE = Path(__file__).resolve().parent / \
    "interaction_prompt_carrier_baseline.json"

PROMPT_METHODS = ("interact_prompt", "control_prompt")

# Known non-production implementations (interaction contract SSC.1).
DEBUG_FILES = ("characters/npc_placeholder.gd",
               "building/light_debug_handle.gd")
ADAPTER_FILES = ("props/prop_control_area.gd",)

CONTROLLER_TOKENS = {
    "A", "B", "X", "Y", "LB", "RB", "LT", "RT", "L1", "L2", "L3",
    "R1", "R2", "R3", "ZL", "ZR", "START", "SELECT", "BACK", "VIEW",
    "MENU", "SHARE", "OPTIONS", "DPAD", "D-PAD", "LS", "RS"}
TOUCH_TOKENS = {"TAP", "HOLD", "SWIPE", "PINCH", "DOUBLE TAP", "DOUBLETAP"}
MOUSE_TOKENS = {"LMB", "RMB", "MMB", "MOUSE1", "MOUSE2", "MOUSE3",
                "WHEEL", "SCROLL"}
KEYBOARD_TOKENS = {
    "SPACE", "SPACEBAR", "ENTER", "RETURN", "ESC", "ESCAPE", "TAB",
    "SHIFT", "CTRL", "CONTROL", "ALT", "BACKSPACE", "DELETE", "DEL",
    "INSERT", "HOME", "END", "PGUP", "PGDN", "WASD",
    *{f"F{n}" for n in range(1, 13)}}
# Single letters as bracket carriers: E is the legacy carrier; A/B/X/Y are
# pad buttons; any other single letter reads as a keyboard key.
PAD_LETTERS = {"A", "B", "X", "Y"}

GLYPH_CHARS = ("ⒶⒷⓍⓎ"          # circled A B X Y
               "\U0001f170\U0001f171\U0001f187\U0001f188"  # squared a b x y
               "△▲○●□■✕✖❌")

LEADING_BRACKET = re.compile(r"^\s*\[([A-Za-z0-9 +/\-]{1,12})\]")

# Instruction verb bound to a key/button name.  The name group is the whole
# vocabulary; bare verbs with ordinary nouns never match.
_KEYNAMES = (r"(?:enter|return|escape|esc|space(?:bar)?|shift|tab|ctrl|"
             r"control|alt|backspace|delete|wasd|arrow keys?|"
             r"f1[0-2]|f[1-9])")
_PADNAMES = (r"(?:d-?pad(?:\s+\w+)?|left stick|right stick|"
             r"(?:left|right)\s+(?:bumper|trigger)|start button|"
             r"select button)")
_MOUSENAMES = (r"(?:lmb|rmb|mmb|mouse\s?[123]|"
               r"(?:left|right|middle)\s+mouse(?:\s+button)?)")
INSTRUCTION = re.compile(
    r"\b(press|hold|hit|tap)\s+(?:the\s+)?(" + _KEYNAMES + r")(?![\w'-])",
    re.IGNORECASE)
# Single letters need an UPPERCASE letter in source ("Press E"), so that
# "press a number" or "press each key gently" stays semantic prose.
LETTER_INSTRUCTION = re.compile(
    r"\b([Pp]ress|[Hh]old|[Hh]it|[Tt]ap)\s+(?:the\s+)?([A-Z])(?![\w'-])")
PAD_INSTRUCTION = re.compile(
    r"\b(press|hold|hit|tap|use|move|push)\s+(?:the\s+)?(" + _PADNAMES
    + r")(?![\w'-])", re.IGNORECASE)
MOUSE_INSTRUCTION = re.compile(
    r"\b(?:(?:press|hold|hit|tap|click)\s+(?:the\s+)?(" + _MOUSENAMES
    + r")|(left|right|middle)[- ]click)(?![\w'-])", re.IGNORECASE)
TOUCH_INSTRUCTION = re.compile(
    r"\b(?:double[- ]tap|swipe\s+(?:left|right|up|down)|pinch\s+to)\b",
    re.IGNORECASE)

CONST_DEF = re.compile(r"^const\s+([A-Za-z_]\w*)\s*(?::=|:\s*\w+\s*=|=)")
FUNC_DEF = re.compile(r"^(\t*)(?:static\s+)?func\s+([A-Za-z_]\w*)\s*\(")
CALLISH = re.compile(r"\b(?!str\b|int\b|float\b)[A-Za-z_]\w*\s*\(")

FAILING = ("FORBIDDEN_CONTROLLER", "FORBIDDEN_TOUCH", "FORBIDDEN_KEYBOARD",
           "FORBIDDEN_MOUSE", "FORBIDDEN_OTHER")


# ---------------------------------------------------------------------------
# Tokenizing helpers
# ---------------------------------------------------------------------------

def split_code_and_comment(line):
    """(code, comment) with GDScript string awareness."""
    out = []
    i, n = 0, len(line)
    while i < n:
        ch = line[i]
        if ch == "#":
            return "".join(out), line[i + 1:]
        if ch in "\"'":
            quote = ch
            out.append(ch)
            i += 1
            while i < n:
                if line[i] == "\\":
                    out.append(line[i:i + 2])
                    i += 2
                    continue
                out.append(line[i])
                if line[i] == quote:
                    i += 1
                    break
                i += 1
            continue
        out.append(ch)
        i += 1
    return "".join(out), None


def string_literals(code):
    """String literals in one code line (comment already stripped)."""
    literals = []
    i, n = 0, len(code)
    while i < n:
        ch = code[i]
        if ch in "\"'":
            quote = ch
            j = i + 1
            buf = []
            while j < n:
                if code[j] == "\\" and j + 1 < n:
                    buf.append({"n": "\n", "t": "\t", '"': '"', "'": "'",
                                "\\": "\\"}.get(code[j + 1], code[j + 1]))
                    j += 2
                    continue
                if code[j] == quote:
                    break
                buf.append(code[j])
                j += 1
            literals.append("".join(buf))
            i = j + 1
        else:
            i += 1
    return literals


# ---------------------------------------------------------------------------
# Carrier classification
# ---------------------------------------------------------------------------

def classify_literal(text):
    """(classification, token) for one string literal; CLEAN when semantic."""
    m = LEADING_BRACKET.match(text)
    if m:
        token = m.group(1).strip().upper()
        bracket = f"[{m.group(1)}]"
        if token == "E":
            return "LEGACY_E", "[E]"
        if token in CONTROLLER_TOKENS or token in PAD_LETTERS:
            return "FORBIDDEN_CONTROLLER", bracket
        if token in TOUCH_TOKENS:
            return "FORBIDDEN_TOUCH", bracket
        if token in MOUSE_TOKENS:
            return "FORBIDDEN_MOUSE", bracket
        if token in KEYBOARD_TOKENS or (len(token) == 1 and token.isalpha()):
            return "FORBIDDEN_KEYBOARD", bracket
        return "FORBIDDEN_OTHER", bracket
    for glyph in GLYPH_CHARS:
        if glyph in text:
            return "FORBIDDEN_CONTROLLER", glyph
    m = MOUSE_INSTRUCTION.search(text)
    if m:
        return "FORBIDDEN_MOUSE", m.group(0)
    m = PAD_INSTRUCTION.search(text)
    if m:
        return "FORBIDDEN_CONTROLLER", m.group(0)
    if TOUCH_INSTRUCTION.search(text):
        return "FORBIDDEN_TOUCH", TOUCH_INSTRUCTION.search(text).group(0)
    m = INSTRUCTION.search(text)
    if m:
        return "FORBIDDEN_KEYBOARD", m.group(0)
    m = LETTER_INSTRUCTION.search(text)
    if m:
        key = m.group(2).upper()
        if key in PAD_LETTERS:
            # "Press A" reads as the pad button; either way it is a carrier.
            return "FORBIDDEN_CONTROLLER", m.group(0)
        return "FORBIDDEN_KEYBOARD", m.group(0)
    return "CLEAN", None


ANYWHERE_BRACKET = re.compile(r"\[([A-Za-z0-9 +/\-]{1,12})\]")


def classify_comment(text):
    """Comments cite carriers mid-prose, so bracket tokens match anywhere."""
    cls, token = classify_literal(text)
    if cls != "CLEAN":
        return cls, token
    for m in ANYWHERE_BRACKET.finditer(text):
        cls, token = classify_literal(f"[{m.group(1)}] example")
        if cls != "CLEAN":
            return cls, token
    return "CLEAN", None


# ---------------------------------------------------------------------------
# File scanning
# ---------------------------------------------------------------------------

def scan_file(path, rel):
    """Findings for one .gd file.

    Returns dict with method findings, comment findings, dynamic notes and
    (verbose-only) out-of-method carrier sightings.
    """
    text = path.read_text(encoding="utf-8", errors="replace")
    lines = text.splitlines()
    consts = {}
    for line in lines:
        m = CONST_DEF.match(line.strip())
        if m:
            code, _ = split_code_and_comment(line)
            lits = string_literals(code)
            if lits:
                consts[m.group(1)] = lits

    methods = []          # (name, def_line, body_lines [(no, line)], indent)
    i = 0
    while i < len(lines):
        m = FUNC_DEF.match(lines[i])
        if m and m.group(2) in PROMPT_METHODS:
            indent = len(m.group(1))
            body = []
            j = i + 1
            while j < len(lines):
                raw = lines[j]
                stripped = raw.strip()
                if stripped and not stripped.startswith("#"):
                    lead = len(raw) - len(raw.lstrip("\t "))
                    if lead <= indent:
                        break
                body.append((j + 1, raw))
                j += 1
            methods.append((m.group(2), i + 1, body, indent))
            i = j
        else:
            i += 1

    findings, comments, dynamics = [], [], []
    covered_lines = set()
    for name, def_line, body, _ in methods:
        method_has_literal_finding = False
        method_has_any_literal = False
        method_has_dynamic = False
        for line_no, raw in body:
            covered_lines.add(line_no)
            code, comment = split_code_and_comment(raw)
            for literal in string_literals(code):
                method_has_any_literal = True
                cls, token = classify_literal(literal)
                if cls != "CLEAN":
                    findings.append({
                        "file": rel, "line": line_no, "method": name,
                        "family": name, "token": token,
                        "classification": cls,
                        "literal": literal[:120],
                        "excerpt": raw.strip()[:140],
                        "via": "body-literal"})
                    method_has_literal_finding = True
            if comment:
                cls, token = classify_comment(comment.strip())
                if cls != "CLEAN":
                    comments.append({
                        "file": rel, "line": line_no, "method": name,
                        "family": name, "token": token,
                        "classification": "COMMENT_ONLY",
                        "carrier_class": cls,
                        "excerpt": raw.strip()[:140]})
            stripped = code.strip()
            if stripped.startswith("return") and CALLISH.search(
                    stripped[6:]) and not string_literals(code):
                method_has_dynamic = True
            for const_name, lits in consts.items():
                if re.search(rf"\b{const_name}\b", code):
                    for literal in lits:
                        cls, token = classify_literal(literal)
                        if cls != "CLEAN":
                            findings.append({
                                "file": rel, "line": line_no,
                                "method": name, "family": name,
                                "token": token, "classification": cls,
                                "literal": literal[:120],
                                "excerpt": f"const {const_name} = ..."
                                           f" via {raw.strip()[:90]}",
                                "via": f"const {const_name}"})
                            method_has_literal_finding = True
        if method_has_dynamic and not method_has_any_literal                 and not method_has_literal_finding:
            dynamics.append({
                "file": rel, "line": def_line, "method": name,
                "family": name, "token": None,
                "classification": "AMBIGUOUS_DYNAMIC",
                "excerpt": "return value built by a call; not resolved "
                           "statically - review by hand"})

    outside = []
    for line_no, raw in enumerate(lines, 1):
        if line_no in covered_lines:
            continue
        code, _ = split_code_and_comment(raw)
        for literal in string_literals(code):
            cls, token = classify_literal(literal)
            if cls != "CLEAN":
                outside.append({
                    "file": rel, "line": line_no, "method": None,
                    "family": None, "token": token,
                    "classification": "NOT_A_PROMPT_RETURN",
                    "carrier_class": cls,
                    "excerpt": raw.strip()[:140]})
    return {"findings": findings, "comments": comments,
            "dynamics": dynamics, "outside": outside,
            "prompt_methods": [(n, l) for n, l, _, _ in methods]}


def scan_tree(root, include_debug=False):
    root = Path(root)
    results = {"files_scanned": 0, "prompt_methods": 0,
               "findings": [], "comments": [], "dynamics": [],
               "outside": [], "debug_findings": []}
    for path in sorted(root.rglob("*.gd")):
        rel = path.relative_to(root).as_posix()
        scanned = scan_file(path, rel)
        if not (scanned["prompt_methods"] or scanned["outside"]):
            continue
        results["files_scanned"] += 1
        results["prompt_methods"] += len(scanned["prompt_methods"])
        role = ("debug" if rel in DEBUG_FILES else
                "adapter" if rel in ADAPTER_FILES else "production")
        for f in scanned["findings"]:
            f["role"] = role
            if role == "debug" and not include_debug:
                f = dict(f, classification="DEBUG_ONLY",
                         carrier_class=f["classification"])
                results["debug_findings"].append(f)
            else:
                results["findings"].append(f)
        for bucket in ("comments", "dynamics", "outside"):
            for f in scanned[bucket]:
                f["role"] = role
                results[bucket].append(f)
    for bucket in ("findings", "comments", "dynamics", "outside",
                   "debug_findings"):
        results[bucket].sort(key=lambda f: (f["file"], f["line"],
                                            str(f["token"])))
    return results


# ---------------------------------------------------------------------------
# Baseline
# ---------------------------------------------------------------------------

def load_baseline(path):
    if not Path(path).exists():
        return []
    try:
        data = json.loads(Path(path).read_text(encoding="utf-8"))
        entries = data["entries"]
        for e in entries:
            if not all(k in e for k in ("file", "method", "token",
                                        "literal")):
                raise KeyError("entry missing required keys")
            if e["token"] != "[E]":
                raise ValueError(
                    "baseline may only cover legacy [E]; found "
                    f"{e['token']!r} - the baseline never suppresses "
                    "forbidden carriers")
        return entries
    except (OSError, json.JSONDecodeError, KeyError, TypeError,
            ValueError) as exc:
        raise SystemExit3(f"malformed baseline {path}: {exc}")


class SystemExit3(Exception):
    pass


def baseline_from_findings(findings):
    entries = []
    for f in findings:
        if f["classification"] != "LEGACY_E":
            continue
        entries.append({"file": f["file"], "method": f["method"],
                        "token": "[E]", "literal": f["literal"],
                        "justification": "pre-existing legacy carrier; "
                                         "migration debt, not approved new "
                                         "authoring"})
    entries.sort(key=lambda e: (e["file"], e["method"], e["literal"]))
    return {"version": 1,
            "policy": ("locks legacy [E] against multiplication; never "
                       "covers [A], [TAP], glyphs or named keyboard/mouse "
                       "instructions"),
            "entries": entries}


def reconcile_baseline(findings, entries, scanned_root):
    """(uncovered_legacy, stale_entries, cleanup_opportunities, covered)."""
    pool = {}
    for e in entries:
        key = (e["file"], e["method"], e["literal"])
        pool[key] = pool.get(key, 0) + 1
    uncovered, covered = [], []
    for f in findings:
        if f["classification"] != "LEGACY_E":
            continue
        key = (f["file"], f["method"], f["literal"][:120])
        if pool.get(key, 0) > 0:
            pool[key] -= 1
            f["baseline_covered"] = True
            covered.append(f)
        else:
            f["baseline_covered"] = False
            uncovered.append(f)
    stale, cleanup = [], []
    for (file, method, literal), remaining in sorted(pool.items()):
        if remaining <= 0:
            continue
        target = Path(scanned_root) / file
        entry = {"file": file, "method": method, "literal": literal,
                 "count": remaining}
        if not target.exists():
            stale.append(dict(entry, reason="file no longer exists"))
            continue
        text = target.read_text(encoding="utf-8", errors="replace")
        if not re.search(rf"func\s+{method}\s*\(", text):
            stale.append(dict(entry, reason="method no longer exists"))
        else:
            cleanup.append(dict(entry, reason="legacy occurrence removed; "
                                              "baseline entry can be "
                                              "deleted"))
    return uncovered, stale, cleanup, covered


# ---------------------------------------------------------------------------
# Reporting
# ---------------------------------------------------------------------------

def summarize(results, uncovered, stale, cleanup, covered):
    forbidden = [f for f in results["findings"]
                 if f["classification"] in FAILING]
    return {
        "files_scanned": results["files_scanned"],
        "prompt_methods": results["prompt_methods"],
        "forbidden": len(forbidden),
        "legacy_covered": len(covered),
        "legacy_uncovered": len(uncovered),
        "ambiguous_dynamic": len(results["dynamics"]),
        "comment_only": len(results["comments"]),
        "debug_only": len(results["debug_findings"]),
        "outside_prompt_methods": len(results["outside"]),
        "baseline_stale": len(stale),
        "baseline_cleanup_opportunities": len(cleanup),
    }


def exit_code(summary):
    code = 0
    if summary["forbidden"] or summary["legacy_uncovered"]:
        code |= 1
    if summary["baseline_stale"]:
        code |= 4
    return code


def main(argv=None):
    parser = argparse.ArgumentParser(
        description="Source-only audit: interaction prompts must not "
                    "author input carriers")
    parser.add_argument("--root", type=Path, default=DEFAULT_ROOT)
    parser.add_argument("--baseline", type=Path, default=DEFAULT_BASELINE)
    parser.add_argument("--update-baseline", action="store_true",
                        help="rewrite the baseline from current LEGACY_E "
                             "findings (explicit only)")
    parser.add_argument("--include-debug", action="store_true",
                        help="hold debug-only implementations to production "
                             "rules")
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--verbose", action="store_true")
    args = parser.parse_args(argv)

    try:
        if not args.root.is_dir():
            print(f"error: root not found: {args.root}", file=sys.stderr)
            return 3
        results = scan_tree(args.root, include_debug=args.include_debug)
        try:
            entries = load_baseline(args.baseline)
        except SystemExit3 as exc:
            print(f"error: {exc}", file=sys.stderr)
            return 3
        if args.update_baseline:
            manifest = baseline_from_findings(results["findings"])
            args.baseline.write_text(
                json.dumps(manifest, indent=1, sort_keys=True) + "\n",
                encoding="utf-8")
            print(f"baseline updated: {args.baseline} "
                  f"({len(manifest['entries'])} entries)")
            entries = manifest["entries"]
        uncovered, stale, cleanup, covered = reconcile_baseline(
            results["findings"], entries, args.root)
        summary = summarize(results, uncovered, stale, cleanup, covered)
        code = exit_code(summary)

        if args.json:
            print(json.dumps({
                "summary": summary, "exit": code,
                "forbidden": [f for f in results["findings"]
                              if f["classification"] in FAILING],
                "legacy_uncovered": uncovered,
                "ambiguous_dynamic": results["dynamics"],
                "comment_only": results["comments"],
                "debug_only": results["debug_findings"],
                "baseline_stale": stale,
                "baseline_cleanup_opportunities": cleanup,
                "outside_prompt_methods": (results["outside"]
                                           if args.verbose else
                                           len(results["outside"])),
            }, indent=1, sort_keys=True))
            return code

        print("interaction prompt carrier audit "
              "(source-only; carriers belong to the player)")
        for key, value in summary.items():
            print(f"- {key}: {value}")
        for f in results["findings"]:
            if f["classification"] in FAILING:
                print(f"FORBIDDEN {f['classification']} {f['file']}:"
                      f"{f['line']} {f['method']}() token={f['token']!r} "
                      f"| {f['excerpt']}")
        for f in uncovered:
            print(f"NEW LEGACY [E] (not in baseline) {f['file']}:"
                  f"{f['line']} {f['method']}() | {f['excerpt']}")
        for e in stale:
            print(f"STALE BASELINE {e['file']} {e['method']}() "
                  f"{e['literal'][:60]!r}: {e['reason']}")
        for e in cleanup:
            print(f"cleanup opportunity: {e['file']} {e['method']}() "
                  f"{e['literal'][:60]!r} no longer occurs")
        for f in results["dynamics"]:
            print(f"ambiguous dynamic: {f['file']}:{f['line']} "
                  f"{f['method']}() - review by hand")
        if args.verbose:
            for f in results["comments"]:
                print(f"comment-only: {f['file']}:{f['line']} "
                      f"{f['method']}() {f['token']!r}")
            for f in results["debug_findings"]:
                print(f"debug-only: {f['file']}:{f['line']} "
                      f"{f['method']}() {f['token']!r}")
            for f in results["outside"]:
                print(f"outside prompt methods: {f['file']}:{f['line']} "
                      f"{f['token']!r} | {f['excerpt']}")
        print(f"-> exit {code}")
        return code
    except Exception as exc:                # noqa: BLE001 - stable exit code
        print(f"internal failure: {type(exc).__name__}: {exc}",
              file=sys.stderr)
        return 70


if __name__ == "__main__":
    sys.exit(main())
