#!/usr/bin/env python3
"""Read-only evidence-receipt verifier: proof citations must resolve.

Room checkpoints cite proof-shot directories, capture receipts, metrics,
logs, scene/test names and recorded validation results.  This tool verifies
that the cited artifacts EXIST and what they RECORD - never what reality
"is".  It runs nothing: no Godot, no Blender, no tests, no captures.
An image that exists proves only that an image exists; a receipt that
records PASS proves only that a receipt records PASS.

Receipt semantics follow game/docs/CAPTURE_EVIDENCE_PROTOCOL.md; this tool
does not invent a competing capture-evidence contract.  Supported artifact
schemas (all schema_version 1):

  scene_capture_receipt.json   ShotHarness scene receipt: status, tag,
                               expected/actual_frames, captures[{file,...}]
  capture_receipt.json         wrapper receipt: status, scene, engine_exit,
                               expected/actual_frames, zero_byte_frames,
                               files, resolution, run_directory
  shot_metrics.json            offline analyzer: status, frames[{file,
                               sha256, luma...}], pairs, failures

Supported durable log verdict formats (the DECISIVE line is preserved):

  walk_fast.log                "WALKTEST RESULT: PASS|FAIL ..."
  godot.log (ShotHarness)      "[TAG] RESULT: PASS|FAIL captures=N expected=M"
  lighting_audit.log           "LIGHTING AUDIT: ... PASS|FAIL"
  *tests.log (unittest)        final "OK" / "FAILED (...)"

Absence of a failure line is NEVER interpreted as a pass.  Unknown receipt
schemas and unrecognized log dialects are reported UNSUPPORTED, not
reinterpreted.

Citation statuses:
  VERIFIED_PRESENT   the exact cited artifact exists and is readable (this
                     alone proves nothing about visual or test correctness)
  RECORDED_PASS      a supported receipt/log explicitly records success
  RECORDED_FAIL      a supported receipt/log explicitly records failure
  MISSING            an exactly-cited path does not exist
  AMBIGUOUS          a non-exact citation has several plausible artifacts,
                     or a log carries conflicting decisive lines
  SYMBOLIC_ONLY      a scene/test name or prose assertion with no durable
                     artifact attached (same line, or uniquely resolvable in
                     a directory this checkpoint cites)
  UNREADABLE         the artifact exists but cannot be read/parsed
  UNSUPPORTED        readable, but written under an unknown schema/dialect
  METADATA_MISMATCH  the artifact exists but its recorded frame counts,
                     resolution, outputs, scene or commit contradict the
                     checkpoint claim
  MALFORMED          an evidence-manifest claim that cannot be interpreted

Exit codes:
  0   verification completed; no MISSING, RECORDED_FAIL, METADATA_MISMATCH
      or MALFORMED records (SYMBOLIC_ONLY / UNSUPPORTED / UNREADABLE and
      inherently manual claims stay visible without failing the run)
  1   missing artifact, recorded failure or metadata mismatch
  3   refused to overwrite existing output (pass --force)
  4   malformed evidence record
  5   both 1 and 4
  2   command-line usage error
  70  internal failure

Usage:
  python tools/room_evidence_verifier.py --checkpoints design --output <dir>
  ... [--checkpoint <path>] [--floor F01] [--room F01_COMMON_B]
      [--json-only | --markdown-only] [--force] [--no-git] [--scaffold]
"""

from __future__ import annotations

import argparse
import json
import re
import struct
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import room_checkpoint_reconciler as rc   # noqa: E402
import room_layout_workbench as wb        # noqa: E402

ROOT = rc.ROOT
DEFAULT_LAYOUT = rc.DEFAULT_LAYOUT

(VERIFIED_PRESENT, RECORDED_PASS, RECORDED_FAIL, MISSING, AMBIGUOUS,
 SYMBOLIC_ONLY, UNREADABLE, UNSUPPORTED, METADATA_MISMATCH, MALFORMED) = (
    "VERIFIED_PRESENT", "RECORDED_PASS", "RECORDED_FAIL", "MISSING",
    "AMBIGUOUS", "SYMBOLIC_ONLY", "UNREADABLE", "UNSUPPORTED",
    "METADATA_MISMATCH", "MALFORMED")

FAILING_STATUSES = (MISSING, RECORDED_FAIL, METADATA_MISMATCH)

EVIDENCE_HEADING = re.compile(r"^##+\s.*(validation|evidence|proof)",
                              re.IGNORECASE)
BACKTICK = re.compile(r"`([^`]+)`")
SYMBOLIC_NAME = re.compile(r"^[A-Z][A-Za-z0-9]{3,}$")
COMMIT_TOKEN = re.compile(r"^[0-9a-f]{7,40}$")
RESOLUTION = re.compile(r"(\d{3,4})\s*[x×]\s*(\d{3,4})")
WORD_NUMBERS = {"one": 1, "two": 2, "three": 3, "four": 4, "five": 5,
                "six": 6, "seven": 7, "eight": 8, "nine": 9, "ten": 10,
                "eleven": 11, "twelve": 12}
COUNT_CLAIM = re.compile(
    r"\b(" + "|".join(WORD_NUMBERS) + r"|\d{1,3})[- ]"
    r"(?:\d{3,4}\s*[x×]\s*\d{3,4}\s+)?"
    r"(?:player-height\s+)?(?:windowed\s+)?"
    r"(frames?|views?|captures?)\b", re.IGNORECASE)

# Symbolic-name kinds -> the durable artifact filenames that can carry their
# recorded result when a directory cited by the same checkpoint holds exactly
# one candidate.
SYMBOLIC_ARTIFACTS = (
    (re.compile(r"walk", re.IGNORECASE), ("walk_fast.log",)),
    (re.compile(r"lighting", re.IGNORECASE), ("lighting_audit.log",)),
    (re.compile(r"Shot$"), ("scene_capture_receipt.json",
                            "capture_receipt.json", "godot.log")),
)


def rel(path, root):
    try:
        return Path(path).resolve().relative_to(Path(root).resolve()).as_posix()
    except ValueError:
        return str(path).replace("\\", "/")


# ---------------------------------------------------------------------------
# Citation discovery
# ---------------------------------------------------------------------------

def evidence_items(text):
    """(line_no, item_text) for each bullet/paragraph in evidence sections.

    A bullet is one `- ` line plus its indented continuations, so citations
    wrapped onto the next line stay attached to their claim.
    """
    lines = text.splitlines()
    items, active = [], False
    current, current_line = None, None
    for n, line in enumerate(lines, 1):
        if line.startswith("#"):
            if current:
                items.append((current_line, current))
                current = None
            active = bool(EVIDENCE_HEADING.match(line))
            continue
        if not active:
            continue
        stripped = line.strip()
        if not stripped:
            if current:
                items.append((current_line, current))
                current = None
            continue
        if stripped.startswith("- "):
            if current:
                items.append((current_line, current))
            current, current_line = stripped[2:], n
        elif current is not None:
            current += " " + stripped
        else:
            current, current_line = stripped, n
    if current:
        items.append((current_line, current))
    return items


def claimed_result(text):
    if re.search(r"\bFAIL(?:ED)?\b", text):
        return "FAIL"
    if re.search(r"\bPASS\b", text):
        return "PASS"
    if "exit 0" in text:
        return "exit 0"
    return None


def claimed_count(text):
    m = COUNT_CLAIM.search(text)
    if not m:
        m2 = re.search(r"\b(" + "|".join(WORD_NUMBERS) + r")-view\b", text,
                       re.IGNORECASE)
        return WORD_NUMBERS[m2.group(1).lower()] if m2 else None
    token = m.group(1).lower()
    return WORD_NUMBERS.get(token, int(token) if token.isdigit() else None)


def claimed_resolution(text):
    m = RESOLUTION.search(text)
    return (int(m.group(1)), int(m.group(2))) if m else None


def parse_citations(path, root):
    """Conservative citation extraction from one checkpoint's evidence
    sections.  Every item is preserved; nothing is guessed from vague titles.
    """
    text = Path(path).read_text(encoding="utf-8")
    citations = []
    for line_no, item in evidence_items(text):
        tokens = BACKTICK.findall(item)
        base = {
            "checkpoint": rel(path, root), "line": line_no,
            "quote": item[:240],
            "claimed_result": claimed_result(item),
            "claimed_count": claimed_count(item),
            "claimed_resolution": claimed_resolution(item),
            "claimed_commit": next((t for t in tokens
                                    if COMMIT_TOKEN.match(t)), None),
        }
        made_one = False
        for token in tokens:
            if COMMIT_TOKEN.match(token):
                continue
            if "/" in token or "\\" in token:
                kind = "directory" if token.rstrip().endswith("/") else "path"
                citations.append(dict(base, kind=kind,
                                      cited=token.strip().rstrip("/")))
                made_one = True
            elif re.search(r"\.(json|log|md|png|txt)$", token):
                citations.append(dict(base, kind="basename",
                                      cited=token.strip()))
                made_one = True
            elif SYMBOLIC_NAME.match(token):
                citations.append(dict(base, kind="symbolic",
                                      cited=token.strip()))
                made_one = True
        if not made_one and base["claimed_result"]:
            citations.append(dict(base, kind="assertion", cited=None))
    return citations


# ---------------------------------------------------------------------------
# Artifact verification
# ---------------------------------------------------------------------------

def png_dimensions(path):
    with open(path, "rb") as fh:
        header = fh.read(24)
    if len(header) < 24 or header[:8] != b"\x89PNG\r\n\x1a\n" \
            or header[12:16] != b"IHDR":
        raise ValueError("not a readable PNG")
    width, height = struct.unpack(">II", header[16:24])
    return width, height


def verify_scene_receipt(path, citation):
    """scene_capture_receipt.json / capture_receipt.json (schema_version 1)."""
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return UNREADABLE, {"error": str(exc)}, []
    required = {"schema_version", "status", "expected_frames", "actual_frames"}
    if not required.issubset(data) or data.get("schema_version") != 1:
        return UNSUPPORTED, {
            "note": "unknown receipt schema; not reinterpreted",
            "schema_version": data.get("schema_version")}, []
    facts = {
        "schema": path.name, "schema_version": 1,
        "status": data["status"],
        "expected_frames": data["expected_frames"],
        "actual_frames": data["actual_frames"],
        "elapsed_seconds": data.get("elapsed_seconds"),
        "tag": data.get("tag"), "scene": data.get("scene"),
        "engine_exit": data.get("engine_exit"),
        "resolution": data.get("resolution"),
        "zero_byte_frames": data.get("zero_byte_frames"),
        "commit": data.get("commit") or data.get("build_commit"),
    }
    mismatches = []
    if data["expected_frames"] != data["actual_frames"]:
        mismatches.append(f"receipt records {data['actual_frames']} frames "
                          f"against {data['expected_frames']} expected")
    outputs = [c.get("file") for c in data.get("captures", [])
               if isinstance(c, dict)] or \
              [Path(f).name for f in data.get("files", [])]
    missing_outputs = sorted(f for f in outputs
                             if f and not (path.parent / f).exists())
    if missing_outputs:
        mismatches.append(f"receipt-referenced outputs missing: "
                          f"{missing_outputs}")
    facts["outputs_recorded"] = len(outputs)
    if citation.get("claimed_count") is not None \
            and citation["claimed_count"] != data["actual_frames"]:
        mismatches.append(f"checkpoint claims {citation['claimed_count']} "
                          f"frames; receipt records {data['actual_frames']}")
    res = citation.get("claimed_resolution")
    if res and data.get("captures"):
        first = data["captures"][0]
        if (first.get("width"), first.get("height")) != res:
            mismatches.append(f"checkpoint claims {res[0]}x{res[1]}; receipt "
                              f"records {first.get('width')}x"
                              f"{first.get('height')}")
    if str(data["status"]).upper() == "FAIL":
        return RECORDED_FAIL, facts, mismatches
    if mismatches:
        return METADATA_MISMATCH, facts, mismatches
    if str(data["status"]).upper() == "PASS":
        return RECORDED_PASS, facts, []
    return UNSUPPORTED, dict(facts, note=f"status '{data['status']}' is not "
                             "a recognized verdict"), []


def verify_metrics(path, citation):
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return UNREADABLE, {"error": str(exc)}, []
    if data.get("schema_version") != 1 or "status" not in data \
            or "frames" not in data:
        return UNSUPPORTED, {"note": "unknown metrics schema"}, []
    facts = {"schema": "shot_metrics.json", "schema_version": 1,
             "status": data["status"], "frames": len(data["frames"]),
             "pairs": len(data.get("pairs", [])),
             "recorded_failures": data.get("failures", []),
             "thresholds_recorded_by_artifact": sorted(
                 {k for p in data.get("pairs", []) if isinstance(p, dict)
                  for k in p if k.startswith("min_")})}
    mismatches = []
    missing = sorted(f.get("file") for f in data["frames"]
                     if isinstance(f, dict) and f.get("file")
                     and not (path.parent / f["file"]).exists())
    if missing:
        mismatches.append(f"metrics-referenced frames missing: {missing}")
    if str(data["status"]).upper() == "FAIL" or data.get("failures"):
        return RECORDED_FAIL, facts, mismatches
    if mismatches:
        return METADATA_MISMATCH, facts, mismatches
    if str(data["status"]).upper() == "PASS":
        return RECORDED_PASS, facts, []
    return UNSUPPORTED, facts, []


LOG_VERDICTS = (
    ("walk", re.compile(r"^WALKTEST RESULT:\s*(PASS|FAIL)\b")),
    ("shot-harness", re.compile(r"^\[[^\]]+\]\s*RESULT:\s*(PASS|FAIL)\b"
                                r"(?:\s+captures=(\d+)\s+expected=(\d+))?")),
    ("lighting", re.compile(r"^LIGHTING AUDIT:.*\b(PASS|FAIL)\b")),
    ("unittest", re.compile(r"^(OK|FAILED)\b")),
)


def verify_log(path, citation):
    try:
        text = path.read_text(encoding="utf-8", errors="strict")
    except (OSError, UnicodeDecodeError) as exc:
        return UNREADABLE, {"error": str(exc)}, []
    decisive = []
    for line in text.splitlines():
        line = line.strip()
        for dialect, pattern in LOG_VERDICTS:
            m = pattern.match(line)
            if m:
                verdict = m.group(1)
                verdict = "PASS" if verdict in ("PASS", "OK") else "FAIL"
                decisive.append((dialect, verdict, line, m))
    if not decisive:
        return VERIFIED_PRESENT, {
            "note": "log present but records no supported verdict line; "
                    "absence of a failure line is not a pass"}, []
    verdicts = {v for _, v, _, _ in decisive}
    if len(verdicts) > 1:
        return AMBIGUOUS, {
            "note": "log records both pass and fail verdict lines",
            "decisive_lines": [l for _, _, l, _ in decisive][:4]}, []
    dialect, verdict, line, m = decisive[-1]
    facts = {"log_dialect": dialect, "decisive_line": line[:200]}
    mismatches = []
    if dialect == "shot-harness" and m.group(2) and m.group(3):
        captures, expected = int(m.group(2)), int(m.group(3))
        facts["captures"] = captures
        facts["expected"] = expected
        if captures != expected:
            mismatches.append(f"log records {captures}/{expected} captures")
        if citation.get("claimed_count") is not None \
                and citation["claimed_count"] != captures:
            mismatches.append(f"checkpoint claims "
                              f"{citation['claimed_count']} frames; log "
                              f"records {captures}")
    if verdict == "FAIL":
        return RECORDED_FAIL, facts, mismatches
    if mismatches:
        return METADATA_MISMATCH, facts, mismatches
    return RECORDED_PASS, facts, []


def verify_png(path, _citation):
    try:
        width, height = png_dimensions(path)
    except (OSError, ValueError) as exc:
        return UNREADABLE, {"error": str(exc)}, []
    return VERIFIED_PRESENT, {"width": width, "height": height,
                              "bytes": path.stat().st_size}, []


def verify_directory(path, citation):
    pngs = sorted(p.name for p in path.iterdir() if p.suffix == ".png")
    receipts = sorted(p.name for p in path.iterdir()
                      if p.name in ("scene_capture_receipt.json",
                                    "capture_receipt.json"))
    logs = sorted(p.name for p in path.iterdir() if p.suffix == ".log")
    facts = {"png_count": len(pngs), "receipts": receipts, "logs": logs,
             "note": ("a non-empty directory without a receipt is present "
                      "evidence, not a recorded pass" if not receipts else "")}
    mismatches = []
    if citation.get("claimed_count") is not None \
            and citation["claimed_count"] != len(pngs):
        mismatches.append(f"checkpoint claims {citation['claimed_count']} "
                          f"frames; directory holds {len(pngs)} PNG(s)")
    if mismatches:
        return METADATA_MISMATCH, facts, mismatches
    return VERIFIED_PRESENT, facts, []


def verify_artifact(path, citation):
    path = Path(path)
    if not path.exists():
        return MISSING, {}, []
    if path.is_dir():
        return verify_directory(path, citation)
    name = path.name
    if name in ("scene_capture_receipt.json", "capture_receipt.json"):
        return verify_scene_receipt(path, citation)
    if name == "shot_metrics.json":
        return verify_metrics(path, citation)
    if path.suffix == ".log":
        return verify_log(path, citation)
    if path.suffix == ".png":
        return verify_png(path, citation)
    if path.suffix == ".json":
        try:
            json.loads(path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError) as exc:
            return UNREADABLE, {"error": str(exc)}, []
        return UNSUPPORTED, {"note": "readable JSON under no supported "
                             "evidence schema"}, []
    try:
        path.read_bytes()
    except OSError as exc:
        return UNREADABLE, {"error": str(exc)}, []
    return VERIFIED_PRESENT, {"bytes": path.stat().st_size}, []


# ---------------------------------------------------------------------------
# Git provenance
# ---------------------------------------------------------------------------

def git_runner(root):
    def run(*args):
        try:
            proc = subprocess.run(["git", "-C", str(root), *args],
                                  capture_output=True, text=True, timeout=30)
            return proc.stdout.strip() if proc.returncode == 0 else None
        except (OSError, subprocess.SubprocessError):
            return None
    return run


def provenance_for(citation, artifact_rel, run):
    out = {}
    if artifact_rel:
        commit = run("log", "-n1", "--format=%H", "--", artifact_rel)
        out["artifact_last_commit"] = commit
    claimed = citation.get("claimed_commit")
    if claimed:
        resolved = run("rev-parse", "--verify", claimed + "^{commit}")
        out["claimed_commit_resolves"] = bool(resolved)
        out["claimed_commit"] = resolved or claimed
        if resolved and out.get("artifact_last_commit"):
            if resolved == out["artifact_last_commit"]:
                out["comparison"] = "artifact last modified at claimed commit"
            else:
                ancestor = run("merge-base", "--is-ancestor",
                               out["artifact_last_commit"], resolved)
                out["comparison"] = (
                    "artifact predates the claimed commit"
                    if ancestor is not None else
                    "artifact and claimed commit differ (relationship "
                    "not established)")
    return out


# ---------------------------------------------------------------------------
# Resolution and orchestration
# ---------------------------------------------------------------------------

def resolve_and_verify(citations, root, use_git=True):
    """Resolve every citation of one checkpoint and verify its artifact."""
    root = Path(root)
    run = git_runner(root) if use_git else None
    doc_dirs = sorted({c["cited"] for c in citations
                       if c["kind"] == "directory"
                       or (c["kind"] == "path"
                           and (root / c["cited"]).is_dir())})
    results = []
    for c in citations:
        entry = dict(c)
        entry["notes"] = []
        entry["mismatches"] = []
        entry["artifact"] = None
        entry["resolved_path"] = None
        if c["kind"] in ("path", "directory"):
            target = root / c["cited"]
            status, facts, mismatches = verify_artifact(target, c)
            entry["resolved_path"] = c["cited"]
            entry["status"] = status
            entry["artifact"] = facts
            entry["mismatches"] = mismatches
        elif c["kind"] == "basename":
            matches = sorted(
                rel(root / d / c["cited"], root) for d in doc_dirs
                if (root / d / c["cited"]).exists())
            if not matches:
                search = sorted(rel(p, root) for p in
                                (root / "art" / "renders").rglob(c["cited"])
                                )[:6] if (root / "art" / "renders").is_dir() \
                    else []
                if len(search) == 1:
                    matches = search
                elif search:
                    entry["status"] = AMBIGUOUS
                    entry["notes"].append(
                        f"basename matches several artifacts: {search}")
                    results.append(entry)
                    continue
            if len(matches) == 1:
                status, facts, mismatches = verify_artifact(
                    root / matches[0], c)
                entry["resolved_path"] = matches[0]
                entry["status"] = status
                entry["artifact"] = facts
                entry["mismatches"] = mismatches
            elif len(matches) > 1:
                entry["status"] = AMBIGUOUS
                entry["notes"].append(
                    f"basename resolves in several cited directories: "
                    f"{matches}")
            else:
                entry["status"] = MISSING
                entry["notes"].append(
                    "cited filename not found in any checkpoint-cited "
                    "directory or under art/renders")
        elif c["kind"] == "symbolic":
            entry["status"] = SYMBOLIC_ONLY
            candidates = []
            for pattern, names in SYMBOLIC_ARTIFACTS:
                if pattern.search(c["cited"]):
                    for d in doc_dirs:
                        for name in names:
                            p = root / d / name
                            if p.exists():
                                candidates.append(rel(p, root))
                    break
            candidates = sorted(set(candidates))
            preferred = [p for p in candidates
                         if p.endswith(("scene_capture_receipt.json",
                                        "capture_receipt.json"))] or candidates
            if len(preferred) == 1:
                status, facts, mismatches = verify_artifact(
                    root / preferred[0], c)
                entry["resolved_path"] = preferred[0]
                entry["status"] = status
                entry["artifact"] = facts
                entry["mismatches"] = mismatches
                entry["notes"].append(
                    "durable artifact resolved via a directory this "
                    "checkpoint cites; the citation itself is symbolic")
            elif len(preferred) > 1:
                entry["notes"].append(
                    f"several plausible durable artifacts: {preferred}; "
                    "left SYMBOLIC_ONLY rather than choosing")
            else:
                entry["notes"].append(
                    "no durable run receipt/log attached to this name")
        else:   # assertion
            entry["status"] = SYMBOLIC_ONLY
            entry["notes"].append(
                "recorded assertion with no cited artifact; remains a "
                "checkpoint claim")
        if entry.get("claimed_result") == "PASS" \
                and entry["status"] == VERIFIED_PRESENT:
            entry["notes"].append(
                "checkpoint claims PASS but the artifact records no "
                "verdict; the claim stays unverified (not a mismatch)")
        if run and entry.get("resolved_path"):
            entry["git"] = provenance_for(c, entry["resolved_path"], run)
        elif run and c.get("claimed_commit"):
            entry["git"] = provenance_for(c, None, run)
        results.append(entry)
    return results


# ---------------------------------------------------------------------------
# Evidence manifests (optional forward format)
# ---------------------------------------------------------------------------

MANIFEST_GLOB = "*.evidence.json"


def verify_manifest(path, root, use_git=True):
    """Verify one machine-readable evidence manifest (documented format)."""
    run = git_runner(root) if use_git else None
    results, malformed = [], []
    try:
        data = json.loads(Path(path).read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        malformed.append({"checkpoint": rel(path, root), "line": 1,
                          "problem": f"unreadable manifest: {exc}"})
        return results, malformed
    for n, claim in enumerate(data.get("claims", [])):
        base = {
            "checkpoint": rel(path, root), "line": n + 1,
            "quote": json.dumps(claim, sort_keys=True)[:240],
            "kind": "manifest-claim",
            "cited": claim.get("artifact"),
            "claimed_result": claim.get("claimed_recorded_result"),
            "claimed_count": claim.get("expected_output_count"),
            "claimed_resolution": None,
            "claimed_commit": claim.get("expected_commit"),
            "claim_id": claim.get("claim_id"),
            "rooms": sorted(claim.get("rooms", [])),
            "notes": [], "mismatches": [], "artifact": None,
            "resolved_path": None,
        }
        if claim.get("manual_visual_proof_required"):
            base["status"] = SYMBOLIC_ONLY
            base["notes"].append("declared manual/visual proof requirement; "
                                 "outside artifact verification")
            results.append(base)
            continue
        if not claim.get("artifact"):
            base["status"] = MALFORMED
            base["notes"].append("claim names no artifact and no manual "
                                 "requirement")
            malformed.append({"checkpoint": base["checkpoint"],
                              "line": n + 1,
                              "problem": "claim without artifact or manual "
                                         "declaration"})
            results.append(base)
            continue
        target = Path(root) / claim["artifact"]
        status, facts, mismatches = verify_artifact(target, base)
        base["resolved_path"] = claim["artifact"] if target.exists() else None
        base["status"] = status
        base["artifact"] = facts
        base["mismatches"] = list(mismatches)
        expected_scene = claim.get("expected_scene")
        if expected_scene and facts and facts.get("scene") \
                and expected_scene not in str(facts["scene"]):
            base["mismatches"].append(
                f"manifest expects scene '{expected_scene}'; artifact "
                f"records '{facts['scene']}'")
            base["status"] = METADATA_MISMATCH
        if run and base["resolved_path"]:
            base["git"] = provenance_for(base, base["resolved_path"], run)
            claimed = base["git"].get("claimed_commit_resolves")
            if claimed is False:
                base["mismatches"].append("expected commit does not resolve "
                                          "in this repository")
                base["status"] = METADATA_MISMATCH
        results.append(base)
    return results, malformed


def proposed_manifest(checkpoint_rel, citations):
    claims = []
    for n, c in enumerate(citations):
        claims.append({
            "claim_id": f"C{n:02d}",
            "rooms": c.get("rooms", []),
            "artifact": c.get("resolved_path") or c.get("cited"),
            "artifact_kind": c["kind"],
            "expected_schema": (c.get("artifact") or {}).get("schema"),
            "expected_scene": None,
            "expected_commit": c.get("claimed_commit"),
            "expected_output_count": c.get("claimed_count"),
            "claimed_recorded_result": c.get("claimed_result"),
            "manual_visual_proof_required":
                c["status"] in (SYMBOLIC_ONLY,) and c["kind"] == "assertion",
            "source": {"line": c["line"], "quote": c["quote"]},
        })
    return {
        "version": 1,
        "PROPOSED": ("generated by room_evidence_verifier; NOT an approved "
                     "evidence manifest.  Review every claim, fill expected "
                     "fields, delete what you do not endorse, then rename "
                     "away the .proposed suffix."),
        "checkpoint": checkpoint_rel,
        "claims": claims,
    }


# ---------------------------------------------------------------------------
# Report assembly
# ---------------------------------------------------------------------------

def checkpoint_rooms(path, layout_rooms):
    try:
        text = Path(path).read_text(encoding="utf-8")
    except OSError:
        return []
    return sorted(r for r in layout_rooms if r in text)


def build_report(checkpoints_dir, root, layout_path=None, use_git=True,
                 only_checkpoint=None, floor=None, room=None):
    root = Path(root)
    layout_rooms = {}
    layout_path = layout_path or (root / "art/data/building_layout.json")
    try:
        layout = json.loads(Path(layout_path).read_text(encoding="utf-8"))
        layout_rooms = {r["id"]: fl["id"] for fl in layout.get("floors", [])
                       for r in fl.get("rooms", [])}
    except (OSError, json.JSONDecodeError):
        pass

    docs, malformed = [], []
    checkpoints_dir = Path(checkpoints_dir)
    md_paths = ([Path(only_checkpoint)] if only_checkpoint
                else sorted(checkpoints_dir.rglob(rc.CHECKPOINT_GLOB))
                if checkpoints_dir.is_dir() else [])
    manifest_paths = (sorted(checkpoints_dir.rglob(MANIFEST_GLOB))
                      if checkpoints_dir.is_dir() and not only_checkpoint
                      else [])
    for path in md_paths:
        if path.suffix != ".md":
            manifest_paths.append(path)
            continue
        rooms = checkpoint_rooms(path, layout_rooms)
        citations = parse_citations(path, root)
        for c in citations:
            c["rooms"] = rooms
        results = resolve_and_verify(citations, root, use_git=use_git)
        docs.append({"checkpoint": rel(path, root), "rooms": rooms,
                     "citations": results})
    for path in manifest_paths:
        results, bad = verify_manifest(path, root, use_git=use_git)
        malformed += bad
        docs.append({"checkpoint": rel(path, root),
                     "rooms": sorted({r for c in results
                                      for r in c.get("rooms", [])}),
                     "citations": results})

    if floor or room:
        def keep(doc):
            rooms = doc["rooms"]
            if room:
                return room in rooms
            return any(layout_rooms.get(r) == floor for r in rooms)
        docs = [d for d in docs if keep(d)]

    all_citations = [c for d in docs for c in d["citations"]]
    counts = {s: sum(1 for c in all_citations if c["status"] == s)
              for s in (VERIFIED_PRESENT, RECORDED_PASS, RECORDED_FAIL,
                        MISSING, AMBIGUOUS, SYMBOLIC_ONLY, UNREADABLE,
                        UNSUPPORTED, METADATA_MISMATCH, MALFORMED)}
    by_room = {}
    for c in all_citations:
        for r in c.get("rooms", []):
            by_room.setdefault(r, {s: 0 for s in counts})
            by_room[r][c["status"]] += 1
    manual_remainder = [
        {"checkpoint": c["checkpoint"], "line": c["line"],
         "quote": c["quote"][:140]}
        for c in all_citations if c["status"] == SYMBOLIC_ONLY]
    return {
        "verifier": {
            "semantics": ("statuses report what artifacts record, never what "
                          "reality is; VERIFIED_PRESENT proves existence "
                          "only, and no result here makes a room COMPLETE"),
            "protocol": "game/docs/CAPTURE_EVIDENCE_PROTOCOL.md",
            "supported_receipts": ["scene_capture_receipt.json (v1)",
                                   "capture_receipt.json (v1)",
                                   "shot_metrics.json (v1)"],
            "supported_logs": ["walk_fast.log", "shot-harness godot.log",
                               "lighting_audit.log", "unittest *.log"],
            "git_provenance": bool(use_git),
        },
        "summary": counts,
        "checkpoints": docs,
        "by_room": {r: by_room[r] for r in sorted(by_room)},
        "malformed": sorted(malformed, key=lambda m: (m["checkpoint"],
                                                      m["line"])),
        "manual_or_visual_remainder": sorted(
            manual_remainder, key=lambda m: (m["checkpoint"], m["line"])),
    }


def report_markdown(report):
    s = report["summary"]
    lines = ["# Room evidence verification", "",
             f"> {report['verifier']['semantics']}", "",
             "## Summary", ""]
    for status in (RECORDED_PASS, VERIFIED_PRESENT, SYMBOLIC_ONLY,
                   RECORDED_FAIL, MISSING, METADATA_MISMATCH, AMBIGUOUS,
                   UNREADABLE, UNSUPPORTED, MALFORMED):
        lines.append(f"- {status}: {s[status]}")
    lines += ["", "## Checkpoints", ""]
    for doc in report["checkpoints"]:
        rows = doc["citations"]
        lines += [f"### {doc['checkpoint']}", "",
                  f"Rooms: {', '.join(doc['rooms']) or '(none resolved)'}; "
                  f"citations: {len(rows)}", ""]
        for c in rows:
            head = (f"- line {c['line']} [{c['status']}] "
                    + (f"`{c['cited']}`" if c["cited"] else "(assertion)"))
            if c.get("resolved_path") and c["resolved_path"] != c.get("cited"):
                head += f" -> `{c['resolved_path']}`"
            lines.append(head)
            lines.append(f"  - quoted: {c['quote'][:150]}")
            art = c.get("artifact") or {}
            if art.get("decisive_line"):
                lines.append(f"  - decisive: `{art['decisive_line'][:130]}`")
            if art.get("status") and "decisive_line" not in art:
                lines.append(
                    f"  - artifact records: {art['status']}"
                    + (f", {art.get('actual_frames')}/"
                       f"{art.get('expected_frames')} frames"
                       if art.get("expected_frames") is not None else ""))
            if art.get("png_count") is not None:
                lines.append(f"  - directory: {art['png_count']} PNG(s), "
                             f"receipts {art['receipts'] or 'none'}, logs "
                             f"{art['logs'] or 'none'}")
            for m in c.get("mismatches", []):
                lines.append(f"  - MISMATCH: {m}")
            for n in c.get("notes", []):
                lines.append(f"  - note: {n}")
            git = c.get("git") or {}
            if git.get("comparison"):
                lines.append(f"  - git: {git['comparison']}")
        lines.append("")
    if report["by_room"]:
        lines += ["## Evidence by room (explicit mappings only)", "",
                  "| Room | PASS | PRESENT | SYMBOLIC | FAIL/MISSING/"
                  "MISMATCH |", "|---|---:|---:|---:|---:|"]
        for room, c in report["by_room"].items():
            bad = c[RECORDED_FAIL] + c[MISSING] + c[METADATA_MISMATCH]
            lines.append(f"| {room} | {c[RECORDED_PASS]} | "
                         f"{c[VERIFIED_PRESENT]} | {c[SYMBOLIC_ONLY]} | "
                         f"{bad} |")
        lines.append("")
    if report["malformed"]:
        lines += ["## Malformed evidence records", ""]
        for m in report["malformed"]:
            lines.append(f"- {m['checkpoint']}:{m['line']}: {m['problem']}")
        lines.append("")
    lines += ["## Remains manual or visual after artifact verification", ""]
    if report["manual_or_visual_remainder"]:
        for m in report["manual_or_visual_remainder"]:
            lines.append(f"- {m['checkpoint']}:{m['line']}: {m['quote']}")
    else:
        lines.append("- none recorded")
    return "\n".join(lines) + "\n"


def exit_code_for(report):
    code = 0
    s = report["summary"]
    if s[MISSING] or s[RECORDED_FAIL] or s[METADATA_MISMATCH]:
        code |= 1
    if s[MALFORMED] or report["malformed"]:
        code |= 4
    return code


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def main(argv=None):
    parser = argparse.ArgumentParser(
        description="Read-only evidence-receipt verifier for room "
                    "reconstruction checkpoints")
    parser.add_argument("--checkpoints", type=Path,
                        default=rc.DEFAULT_CHECKPOINTS)
    parser.add_argument("--checkpoint", type=Path,
                        help="verify a single checkpoint document")
    parser.add_argument("--repository-root", type=Path, default=ROOT)
    parser.add_argument("--layout", type=Path,
                        help="layout JSON for room/floor mapping (default "
                             "<root>/art/data/building_layout.json)")
    parser.add_argument("--floor")
    parser.add_argument("--room")
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--json-only", action="store_true")
    parser.add_argument("--markdown-only", action="store_true")
    parser.add_argument("--force", action="store_true")
    parser.add_argument("--no-git", action="store_true")
    parser.add_argument("--scaffold", action="store_true",
                        help="also emit <checkpoint>.evidence.json.proposed "
                             "scaffolds into --output")
    args = parser.parse_args(argv)

    args.output.mkdir(parents=True, exist_ok=True)
    targets = []
    if not args.markdown_only:
        targets.append(args.output / "room_evidence_status.json")
    if not args.json_only:
        targets.append(args.output / "room_evidence_status.md")
    try:
        wb.preflight_overwrite(targets, args.force)
    except FileExistsError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 3

    try:
        report = build_report(args.checkpoints, args.repository_root,
                              layout_path=args.layout,
                              use_git=not args.no_git,
                              only_checkpoint=args.checkpoint,
                              floor=args.floor, room=args.room)
    except Exception as exc:                # noqa: BLE001 - stable exit code
        print(f"internal failure: {type(exc).__name__}: {exc}",
              file=sys.stderr)
        return 70

    for path in targets:
        if path.suffix == ".json":
            path.write_text(json.dumps(report, indent=1, sort_keys=True)
                            + "\n", encoding="utf-8")
        else:
            path.write_text(report_markdown(report), encoding="utf-8")
        print(path)
    if args.scaffold:
        scaffold_targets = []
        for doc in report["checkpoints"]:
            name = Path(doc["checkpoint"]).name
            if name.endswith(".md"):
                name = name[:-3]
            scaffold_targets.append(
                (args.output / f"{name}.evidence.json.proposed", doc))
        try:
            wb.preflight_overwrite([t for t, _ in scaffold_targets],
                                   args.force)
        except FileExistsError as exc:
            print(f"error: {exc}", file=sys.stderr)
            return 3
        for path, doc in scaffold_targets:
            path.write_text(json.dumps(
                proposed_manifest(doc["checkpoint"], doc["citations"]),
                indent=1, sort_keys=True) + "\n", encoding="utf-8")
            print(path)
    code = exit_code_for(report)
    s = report["summary"]
    print(f"citations={sum(s.values())} recorded_pass={s[RECORDED_PASS]} "
          f"present={s[VERIFIED_PRESENT]} symbolic={s[SYMBOLIC_ONLY]} "
          f"missing={s[MISSING]} fail={s[RECORDED_FAIL]} "
          f"mismatch={s[METADATA_MISMATCH]} -> exit {code}", file=sys.stderr)
    return code


if __name__ == "__main__":
    sys.exit(main())
