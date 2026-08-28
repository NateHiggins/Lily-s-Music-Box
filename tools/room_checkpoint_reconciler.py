#!/usr/bin/env python3
"""Read-only checkpoint reconciler: do room decisions survive regeneration?

The reconstruction records object-level KEEP / MOVE / REPAIR / REPLACE /
REMOVE / ADD decisions in `design/ORISON_*CHECKPOINT*.md` documents, then
changes art/data/gen_layout.py and regenerates the layout.  This tool checks
each parsed decision against the CURRENT building-layout JSON and reports
which decisions are demonstrably satisfied, contradicted, still open, or not
verifiable from layout data at all.  It never modifies production layout
data, checkpoint documents or verdicts.

Markdown is not a reliable database, so parsing is deliberately conservative:

  - only documents matching ORISON_*CHECKPOINT*.md are read as checkpoints;
  - only table rows with a recognized Verdict column become decisions;
  - object references are taken ONLY from backticked tokens; `stem0..3`
    numeric ranges are expanded and `*`/`?` globs are matched literally;
  - rows without any backticked object id become UNVERIFIABLE, never guessed;
  - missing coordinates/properties are never invented — a MOVE without a
    checkable target is UNVERIFIABLE, not an estimate;
  - malformed rows are reported with document and line number;
  - duplicate and conflicting decisions are surfaced, and no row is silently
    preferred over another.

Layout presence never proves visual, historical, interaction or mesh
correctness; SATISFIED means only that the layout JSON does not contradict
the decision's checkable facts.

For decisions richer than prose tables can carry, a small machine-readable
manifest format is supported (see design/ROOM_CHECKPOINT_RECONCILER_GUIDE.md):
any `*.decisions.json` file under --checkpoints is read alongside the
markdown checkpoints.

Exit codes (stable, tested):
  0   every parsed decision is SATISFIED, OPEN or explicitly UNVERIFIABLE
  1   at least one CONTRADICTED decision or cross-checkpoint conflict
  3   refused to overwrite existing output (pass --force)
  4   malformed decision rows were found (parse-level problems)
  5   both contradictions/conflicts (1) and malformed rows (4)
  2   command-line usage error (argparse default)
  70  unexpected internal failure
OPEN decisions alone do not fail the run: an ADD that has not landed yet is
normal mid-reconstruction state, not an error.

Usage:
  python tools/room_checkpoint_reconciler.py --output <dir>
  python tools/room_checkpoint_reconciler.py --layout art/data/building_layout.json \
      --checkpoints design --output <dir> [--force] [--no-git]
"""

from __future__ import annotations

import argparse
import fnmatch
import json
import math
import re
import subprocess
import sys
from collections import defaultdict
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audit_orison_rooms as audit          # noqa: E402
import room_layout_workbench as wb          # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_LAYOUT = ROOT / "art/data/building_layout.json"
DEFAULT_CHECKPOINTS = ROOT / "design"
CHECKPOINT_GLOB = "ORISON_*CHECKPOINT*.md"
MANIFEST_GLOB = "*.decisions.json"

VERDICTS = ("KEEP", "MOVE", "REPAIR", "REPLACE", "REMOVE", "ADD", "KEEP ABSENT")
SATISFIED, OPEN, CONTRADICTED, UNVERIFIABLE = (
    "SATISFIED", "OPEN", "CONTRADICTED", "UNVERIFIABLE")

DEFAULT_POS_TOL = 0.05      # metres, when a manifest supplies no tolerance
DEFAULT_YAW_TOL = 1.0       # degrees
ROOM_EDGE_PAD = 0.10        # membership slack for boundary-seated objects

ID_TOKEN = re.compile(r"^[A-Za-z0-9_.*?-]+$")
RANGE_TOKEN = re.compile(r"^(.*?)(\d+)\.\.(\d+)$")
BACKTICK = re.compile(r"`([^`]+)`")

# Sources scanned for evidence that an id is a runtime GDScript prop the
# layout JSON cannot represent.  building_layout.json is excluded on purpose:
# a substring hit there is layout data, not runtime evidence.
RUNTIME_SCAN_DIRS = (("game/scripts", "*.gd"), ("game/data", "*.json"))
RUNTIME_SCAN_EXCLUDE = ("building_layout.json",)


# ---------------------------------------------------------------------------
# Layout object index (reuses the workbench's record interpretation)
# ---------------------------------------------------------------------------

def build_object_index(layout, tables):
    """id -> sorted list of occurrence dicts across the whole layout.

    Returns (index, rooms_by_id, kind_census) where kind_census counts the
    assembly and marker KIND names in use — a checkpoint token that names a
    kind (e.g. `arcade_cab`) must not be mistaken for a record id.
    """
    index = defaultdict(list)
    rooms_by_id = {}
    kind_census = defaultdict(int)
    for floor in layout.get("floors", []):
        rooms = floor.get("rooms", [])
        for room in rooms:
            rooms_by_id[room["id"]] = room
        categories = [("furniture", floor.get("furniture", [])),
                      ("markers", floor.get("markers", [])),
                      ("sockets", floor.get("sockets", [])),
                      ("vent_registers", floor.get("vent_registers", []))]
        for category, records in categories:
            for record in records:
                if record.get("asm"):
                    kind_census[record["asm"]] += 1
                if category == "markers" and record.get("kind"):
                    kind_census[record["kind"]] += 1
                rid = record.get("id")
                if not rid:
                    continue
                if category == "markers" and wb.is_room_door(record):
                    view = wb.door_view(record, rooms)
                    point = view["centre"]
                    door_rooms = sorted(set(
                        view["rooms_field"]
                        + [r for r in view["adjacent_rooms"] if r]))
                else:
                    interp = wb.interpret_record(category, record, tables)
                    point = interp["point"]
                    door_rooms = None
                containing = []
                if point is not None:
                    containing = sorted(
                        (r for r in rooms
                         if audit.inside(point, r["rect"], 0.001)),
                        key=lambda r: ((r["rect"][2] - r["rect"][0])
                                       * (r["rect"][3] - r["rect"][1])))
                index[rid].append({
                    "floor": floor["id"], "category": category,
                    "kind": record.get("kind"), "asm": record.get("asm"),
                    "yaw": record.get("yaw", record.get("yaw_deg")),
                    "point": tuple(point) if point else None,
                    "assigned_room": containing[0]["id"] if containing else None,
                    "containing_rooms": [r["id"] for r in containing],
                    "door_rooms": door_rooms,
                })
    for category, records in (("vantry_points", layout.get("vantry_points", [])),
                              ("bookshelves", layout.get("bookshelves", []))):
        for record in records:
            rid = record.get("id")
            if not rid:
                continue
            point = audit.object_point(record)
            index[rid].append({
                "floor": record.get("floor"), "category": category,
                "kind": record.get("kind"), "asm": None,
                "yaw": record.get("yaw_deg"),
                "point": tuple(point) if point else None,
                "assigned_room": record.get("room"),
                "containing_rooms": [record.get("room")] if record.get("room") else [],
                "door_rooms": None,
            })
    for occurrences in index.values():
        occurrences.sort(key=lambda o: (str(o["floor"]), o["category"],
                                        str(o["point"])))
    return dict(index), rooms_by_id, dict(kind_census)


def occurrence_in_room(occ, room_id, rooms_by_id):
    if room_id in occ["containing_rooms"]:
        return True
    if occ["door_rooms"] and room_id in occ["door_rooms"]:
        return True
    room = rooms_by_id.get(room_id)
    if room and occ["point"] is not None:
        return wb.point_rect_dist(*occ["point"], room["rect"]) <= ROOM_EDGE_PAD
    return False


def occurrence_summary(occ):
    return {"floor": occ["floor"], "category": occ["category"],
            "kind": occ["kind"], "asm": occ["asm"],
            "yaw_deg": wb.fnum(occ["yaw"]) if occ["yaw"] is not None else None,
            "position": wb.fpt(occ["point"]) if occ["point"] else None,
            "assigned_room": occ["assigned_room"]}


def build_runtime_evidence_scanner(root=ROOT):
    """Lazy substring scanner over runtime sources.  Returns fn(token)->paths."""
    cache = {}
    files = None

    def load():
        nonlocal files
        files = []
        for rel, pattern in RUNTIME_SCAN_DIRS:
            base = root / rel
            if not base.is_dir():
                continue
            for path in sorted(base.rglob(pattern)):
                if path.name in RUNTIME_SCAN_EXCLUDE:
                    continue
                try:
                    files.append((path.relative_to(root).as_posix(),
                                  path.read_text(encoding="utf-8",
                                                 errors="replace")))
                except OSError:
                    continue

    def scan(token):
        if token in cache:
            return cache[token]
        if files is None:
            load()
        hits = [name for name, text in files if token in text][:4]
        cache[token] = hits
        return hits

    return scan


# ---------------------------------------------------------------------------
# Checkpoint discovery and markdown parsing
# ---------------------------------------------------------------------------

def discover_checkpoints(checkpoints_dir):
    docs = sorted(Path(checkpoints_dir).rglob(CHECKPOINT_GLOB))
    manifests = sorted(Path(checkpoints_dir).rglob(MANIFEST_GLOB))
    return docs, manifests


def expand_object_token(token):
    """One backticked token -> (form, [ids-or-patterns]) or None if not id-like.

    Forms: 'literal', 'glob', 'range'.  Never invents anything: a range is a
    documented `stem<a>..<b>` expansion, a glob stays a pattern.
    """
    token = token.strip()
    if not token or " " in token or "/" in token or not ID_TOKEN.match(token):
        return None
    m = RANGE_TOKEN.match(token)
    if m and "*" not in token and "?" not in token:
        lo, hi = int(m.group(2)), int(m.group(3))
        if lo <= hi and hi - lo <= 200:
            return "range", [f"{m.group(1)}{n}" for n in range(lo, hi + 1)]
        return None
    if "*" in token or "?" in token:
        return "glob", [token]
    if "." in token:            # file-ish tokens (foo.png) are not object ids
        return None
    return "literal", [token]


def normalize_verdict(cell):
    cleaned = re.sub(r"[*_]", "", cell).strip().upper()
    cleaned = re.sub(r"\s+", " ", cleaned)
    return cleaned if cleaned in VERDICTS else None


def split_table_row(line):
    body = line.strip()
    if body.startswith("|"):
        body = body[1:]
    if body.endswith("|"):
        body = body[:-1]
    return [cell.strip() for cell in body.split("|")]


def resolve_room_cell(cell, doc_rooms):
    """Map a table's Room cell (e.g. 'Office') onto a known room id that the
    same document names.  0 or >1 candidates -> unresolved."""
    token = re.sub(r"[^A-Za-z0-9]", "", cell).upper()
    if not token:
        return None
    exact = [r for r in doc_rooms if r.upper() == cell.strip().upper()]
    if len(exact) == 1:
        return exact[0]
    candidates = [r for r in doc_rooms if token in r.upper().split("_")
                  or token == r.upper().replace("_", "")]
    if len(candidates) == 1:
        return candidates[0]
    candidates = [r for r in doc_rooms if token in r.upper()]
    return candidates[0] if len(candidates) == 1 else None


def parse_checkpoint_markdown(path, known_rooms, root=ROOT):
    """Parse one checkpoint document.

    Returns (decisions, malformed, doc_report).  Decisions carry the exact
    source line and quoted row text for auditability.
    """
    rel = path.resolve()
    try:
        rel = rel.relative_to(root)
    except ValueError:
        pass
    rel = str(rel).replace("\\", "/")
    text = path.read_text(encoding="utf-8")
    doc_rooms = sorted({r for r in known_rooms if r in text})
    lines = text.splitlines()
    decisions, malformed = [], []
    tables = 0
    rows_parsed = 0
    i = 0
    while i < len(lines):
        line = lines[i]
        if not line.lstrip().startswith("|"):
            i += 1
            continue
        header = split_table_row(line)
        lowered = [h.lower() for h in header]
        if "verdict" not in lowered or i + 1 >= len(lines) \
                or not re.match(r"^\s*\|[\s:|-]+$", lines[i + 1]):
            i += 1
            continue
        tables += 1
        verdict_col = lowered.index("verdict")
        room_col = lowered.index("room") if "room" in lowered else None
        element_col = next((k for k, h in enumerate(lowered)
                            if h in ("element", "object", "objects", "item")),
                           None)
        if element_col is None:
            element_col = next(k for k in range(len(header))
                               if k not in (verdict_col, room_col))
        reason_col = next((k for k, h in enumerate(lowered)
                           if h in ("reason", "rationale", "why")), None)
        j = i + 2
        while j < len(lines) and lines[j].lstrip().startswith("|"):
            cells = split_table_row(lines[j])
            line_no = j + 1
            quote = lines[j].strip()
            if len(cells) != len(header):
                malformed.append({
                    "path": rel, "line": line_no, "quote": quote,
                    "problem": f"row has {len(cells)} cells, header has "
                               f"{len(header)}"})
                j += 1
                continue
            rows_parsed += 1
            verdict = normalize_verdict(cells[verdict_col])
            if verdict is None:
                malformed.append({
                    "path": rel, "line": line_no, "quote": quote,
                    "problem": f"unrecognized verdict "
                               f"'{cells[verdict_col].strip()}'"})
                j += 1
                continue
            if room_col is not None:
                room = resolve_room_cell(cells[room_col], doc_rooms)
                resolution = ("table-cell" if room else "unresolved")
            elif len(doc_rooms) == 1:
                room, resolution = doc_rooms[0], "document"
            else:
                room, resolution = None, "unresolved"
            element = cells[element_col]
            rationale = cells[reason_col] if reason_col is not None else ""
            refs = []
            for raw in BACKTICK.findall(element):
                expanded = expand_object_token(raw)
                if expanded:
                    refs.append((raw, *expanded))
            replacement = None
            if verdict == "REPLACE":
                arrow = re.search(r"`([^`]+)`\s*(?:->|→)\s*`([^`]+)`", element)
                if arrow:
                    old_t = expand_object_token(arrow.group(1))
                    new_t = expand_object_token(arrow.group(2))
                    if old_t and new_t and old_t[0] == new_t[0] == "literal":
                        refs = [(arrow.group(1), "literal", old_t[1])]
                        replacement = new_t[1][0]
            base = {
                "source": {"path": rel, "line": line_no, "quote": quote},
                "room": room, "room_resolution": resolution,
                "verdict": verdict, "rationale": rationale,
                "element_text": element, "replacement": replacement,
                "expected": {},
            }
            if not refs:
                decisions.append(dict(base, object=None, object_form="none"))
            for raw, form, ids in refs:
                for one in ids:
                    decisions.append(dict(base, object=one,
                                          object_form=form,
                                          object_source_token=raw))
            j += 1
        i = j
    doc_report = {
        "path": rel, "kind": "markdown-checkpoint",
        "rooms_named": doc_rooms, "verdict_tables": tables,
        "rows_parsed": rows_parsed, "decisions": 0,   # filled by caller
        "malformed_rows": len(malformed),
        "note": ("" if tables else
                 "prose-only checkpoint: no machine-readable verdict table; "
                 "consider adding a *.decisions.json manifest"),
    }
    return decisions, malformed, doc_report


def parse_manifest(path, root=ROOT):
    """Parse one *.decisions.json manifest (the documented forward format)."""
    rel = path.resolve()
    try:
        rel = rel.relative_to(root)
    except ValueError:
        pass
    rel = str(rel).replace("\\", "/")
    decisions, malformed = [], []
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        malformed.append({"path": rel, "line": 1, "quote": "",
                          "problem": f"unreadable manifest: {exc}"})
        return decisions, malformed, {
            "path": rel, "kind": "decisions-manifest", "verdict_tables": 0,
            "rows_parsed": 0, "decisions": 0, "malformed_rows": 1, "note": ""}
    entries = data.get("decisions", [])
    for n, entry in enumerate(entries):
        quote = json.dumps(entry, sort_keys=True)[:240]
        verdict = normalize_verdict(str(entry.get("verdict", "")))
        if verdict is None:
            malformed.append({"path": rel, "line": n + 1, "quote": quote,
                              "problem": "unrecognized verdict "
                                         f"'{entry.get('verdict')}'"})
            continue
        obj = entry.get("object")
        form = "none"
        if obj is not None:
            expanded = expand_object_token(str(obj))
            if not expanded:
                malformed.append({"path": rel, "line": n + 1, "quote": quote,
                                  "problem": f"object token '{obj}' is not a "
                                             "valid id/glob"})
                continue
            form = expanded[0]
        decisions.append({
            "source": {"path": rel, "line": n + 1, "quote": quote},
            "room": entry.get("room"),
            "room_resolution": "explicit" if entry.get("room") else "unresolved",
            "verdict": verdict, "rationale": str(entry.get("rationale", "")),
            "element_text": str(obj or ""),
            "replacement": entry.get("replacement"),
            "expected": dict(entry.get("expected", {})),
            "object": str(obj) if obj is not None else None,
            "object_form": form,
            "scope": entry.get("scope", "layout"),
            "base_commit": data.get("base_commit"),
        })
    return decisions, malformed, {
        "path": rel, "kind": "decisions-manifest", "verdict_tables": 1,
        "rows_parsed": len(entries), "decisions": len(decisions),
        "malformed_rows": len(malformed), "note": ""}


# ---------------------------------------------------------------------------
# Git provenance (optional; never required for classification)
# ---------------------------------------------------------------------------

def git_provenance(doc_paths, layout_path, root=ROOT):
    """Last commit touching each checkpoint + layout commits since then."""
    out = {}

    def run(*args):
        try:
            proc = subprocess.run(["git", "-C", str(root), *args],
                                  capture_output=True, text=True, timeout=30)
            return proc.stdout.strip() if proc.returncode == 0 else None
        except (OSError, subprocess.SubprocessError):
            return None

    try:
        layout_rel = Path(layout_path).resolve().relative_to(root).as_posix()
    except ValueError:
        layout_rel = None
    for path in doc_paths:
        p = Path(path)
        if not p.is_absolute():
            p = root / p
        try:
            rel = p.resolve().relative_to(root).as_posix()
        except ValueError:
            out[str(path)] = {"commit": None, "layout_commits_since": None,
                              "note": "outside the repository"}
            continue
        commit = run("log", "-n1", "--format=%H", "--", rel)
        since = None
        if commit and layout_rel:
            log = run("log", "--format=%H", f"{commit}..HEAD", "--", layout_rel)
            since = len(log.splitlines()) if log is not None else None
        out[rel] = {"commit": commit,
                    "layout_commits_since": since,
                    "note": "" if commit else "unknown base commit"}
    return out


# ---------------------------------------------------------------------------
# Classification
# ---------------------------------------------------------------------------

def match_occurrences(decision, index):
    obj = decision["object"]
    if obj is None:
        return []
    if decision["object_form"] == "glob":
        hits = []
        for rid in sorted(index):
            if fnmatch.fnmatchcase(rid, obj):
                hits.extend((rid, occ) for occ in index[rid])
        return hits
    return [(obj, occ) for occ in index.get(obj, [])]


def prefix_matches(token, index, limit=6):
    return sorted(rid for rid in index
                  if rid != token and rid.startswith(token + "_")
                  or (rid != token and rid.startswith(token)
                      and rid[len(token):len(token) + 1].isdigit()))[:limit]


def stem_matches(token, index, limit=6):
    stem = re.sub(r"[\d_]+$", "", token)
    if len(stem) < 4:
        return []
    return sorted(rid for rid in index
                  if rid != token and rid.startswith(stem))[:limit]


def check_expected(decision, occ, pos_tol, yaw_tol):
    """Verify manifest-supplied expected properties.  Returns list of
    mismatch strings (empty = all supplied invariants hold)."""
    exp = decision.get("expected") or {}
    problems = []
    if "assembly" in exp and occ["asm"] != exp["assembly"]:
        problems.append(f"assembly is '{occ['asm']}', expected "
                        f"'{exp['assembly']}'")
    if "position" in exp:
        tol = float(exp.get("tolerance_m", pos_tol))
        if occ["point"] is None:
            problems.append("no position in layout to compare")
        else:
            d = math.dist(occ["point"], tuple(map(float, exp["position"])))
            if d > tol:
                problems.append(f"position {wb.fpt(occ['point'])} is "
                                f"{d:.3f} m from expected "
                                f"{[float(v) for v in exp['position']]} "
                                f"(tolerance {tol})")
    if "yaw_deg" in exp:
        tol = float(exp.get("yaw_tolerance_deg", yaw_tol))
        if occ["yaw"] is None:
            problems.append("no yaw in layout to compare")
        else:
            diff = abs((float(occ["yaw"]) - float(exp["yaw_deg"]) + 180.0)
                       % 360.0 - 180.0)
            if diff > tol:
                problems.append(f"yaw {occ['yaw']} differs from expected "
                                f"{exp['yaw_deg']} by {diff:.1f} deg "
                                f"(tolerance {tol})")
    return problems


def classify(decision, index, rooms_by_id, runtime_scan, pos_tol, yaw_tol,
             kind_census=None):
    """Classify one decision against the current layout.

    Mutates the decision dict: status, reason, current, flags.
    """
    verdict = decision["verdict"]
    room = decision["room"]
    flags = decision.setdefault("flags", [])
    if room and room not in rooms_by_id:
        flags.append(f"room '{room}' is not a declared layout room")
    if decision["room_resolution"] == "unresolved":
        flags.append("room not machine-resolved from the checkpoint")

    def finish(status, reason, occs=()):
        decision["status"] = status
        decision["reason"] = reason
        decision["current"] = [occurrence_summary(o) for _, o in occs]

    if decision.get("scope") == "runtime":
        finish(UNVERIFIABLE, "declared runtime-scope: invisible to layout JSON")
        flags.append("runtime-only dependency (declared)")
        return decision

    if decision["object"] is None:
        finish(UNVERIFIABLE, "no stable object id supplied "
               "(prose-only element); needs visual/manual confirmation")
        return decision

    occs = match_occurrences(decision, index)
    room_known = room in rooms_by_id if room else False

    def absent_disposition(present_status_reason):
        """Shared handling for a literal id with no layout occurrence."""
        token = decision["object"]
        if kind_census and token in kind_census:
            finish(UNVERIFIABLE, f"'{token}' names an assembly/marker KIND "
                   f"({kind_census[token]} record(s) of that kind exist), not "
                   "a record id; not treated as a decision target")
            flags.append("token is an assembly/marker kind, not an id")
            return True
        near = prefix_matches(token, index)
        if near:
            finish(UNVERIFIABLE, "imprecise id: no exact layout record, but "
                   f"prefix matches exist: {near}; the checkpoint may be "
                   "naming a family loosely")
            flags.append("imprecise object id")
            return True
        runtime = runtime_scan(token) if runtime_scan else []
        if runtime:
            finish(UNVERIFIABLE, "runtime GDScript prop: id appears in "
                   f"{runtime} but never in layout JSON; verify in scene")
            flags.append("runtime-only dependency (evidence-based)")
            return True
        if "runtime" in (decision["rationale"] + decision["element_text"]).lower():
            finish(UNVERIFIABLE, "checkpoint text marks this runtime; layout "
                   "JSON cannot verify it")
            flags.append("runtime-only dependency (text-declared)")
            return True
        finish(*present_status_reason)
        return True

    if verdict in ("REMOVE", "KEEP ABSENT"):
        if not occs:
            if kind_census and decision["object"] in kind_census:
                finish(UNVERIFIABLE, f"'{decision['object']}' names an "
                       "assembly/marker KIND "
                       f"({kind_census[decision['object']]} record(s) of that "
                       "kind exist), not a record id; not treated as a "
                       "decision target")
                flags.append("token is an assembly/marker kind, not an id")
                return decision
            finish(SATISFIED, "absent from the entire layout")
            successors = stem_matches(decision["object"].rstrip("*?"), index)
            if successors:
                flags.append("possible renamed equivalents exist (unproven, "
                             f"flagged only): {successors}")
            return decision
        finish(CONTRADICTED,
               f"{len(occs)} matching record(s) still present in the layout",
               occs)
        return decision

    if verdict == "REPLACE":
        old_occs = occs
        replacement = decision.get("replacement")
        if not replacement:
            finish(UNVERIFIABLE, "replacement id not machine-readable; use "
                   "`old` -> `new` in the element cell or a decisions "
                   "manifest", old_occs)
            return decision
        new_occs = [(replacement, o) for o in index.get(replacement, [])]
        if old_occs and new_occs:
            finish(CONTRADICTED, "both the replaced object and its "
                   "replacement exist", old_occs + new_occs)
        elif old_occs:
            finish(OPEN, "replacement not started: old object still present, "
                   f"replacement '{replacement}' absent", old_occs)
        elif new_occs:
            problems = [p for _, o in new_occs
                        for p in check_expected(decision, o, pos_tol, yaw_tol)]
            if problems:
                finish(CONTRADICTED, "replacement exists but violates "
                       "declared properties: " + "; ".join(problems), new_occs)
            else:
                finish(SATISFIED, "old object absent, replacement present",
                       new_occs)
        else:
            finish(OPEN, "half-complete: old object removed but replacement "
                   f"'{replacement}' not present yet")
            flags.append("half-complete replacement")
        return decision

    if verdict == "ADD":
        if not occs:
            finish(OPEN, "named addition not present in the layout yet")
            return decision
        problems = []
        if room_known and not any(occurrence_in_room(o, room, rooms_by_id)
                                  for _, o in occs):
            problems.append(f"present but not in room {room} "
                            f"(assigned: {sorted({o['assigned_room'] for _, o in occs})})")
        for _, o in occs:
            problems.extend(check_expected(decision, o, pos_tol, yaw_tol))
        if problems:
            finish(CONTRADICTED, "; ".join(problems), occs)
        else:
            finish(SATISFIED, "addition present"
                   + (f" in {room}" if room_known else ""), occs)
        return decision

    if verdict == "MOVE":
        # A table's Room column is decision CONTEXT, not a supplied target;
        # only explicit expected properties (manifest) make a MOVE checkable.
        exp = decision.get("expected") or {}
        if not occs:
            return absent_disposition((CONTRADICTED,
                                       "object to move has vanished"))
        if not exp:
            finish(UNVERIFIABLE, "MOVE with no checkable target (no expected "
                   "position/room/yaw supplied); needs visual confirmation",
                   occs)
            return decision
        problems = []
        target_room = exp.get("room")
        if target_room and not any(
                occurrence_in_room(o, target_room, rooms_by_id)
                for _, o in occs):
            problems.append(f"not inside target room {target_room}")
        for _, o in occs:
            problems.extend(check_expected(decision, o, pos_tol, yaw_tol))
        if problems:
            finish(CONTRADICTED, "; ".join(problems), occs)
        else:
            finish(SATISFIED, "matches every supplied target condition", occs)
        return decision

    if verdict == "REPAIR":
        if decision.get("expected"):
            if not occs:
                return absent_disposition((CONTRADICTED,
                                           "object to repair is absent"))
            problems = [p for _, o in occs
                        for p in check_expected(decision, o, pos_tol, yaw_tol)]
            if problems:
                finish(CONTRADICTED, "; ".join(problems), occs)
            else:
                finish(SATISFIED, "all supplied checkable properties hold",
                       occs)
            return decision
        if not occs:
            return absent_disposition((UNVERIFIABLE,
                                       "repair target absent from layout and "
                                       "no checkable properties supplied"))
        finish(UNVERIFIABLE, "repair has no layout-checkable properties; "
               "needs Blender/Godot or visual evidence", occs)
        return decision

    # KEEP
    if not occs:
        return absent_disposition((CONTRADICTED,
                                   "kept object is absent from the layout"))
    if decision["object_form"] == "glob":
        flags.append("pattern-based KEEP: existence checked, uniqueness not")
    elif len(occs) > 1:
        finish(CONTRADICTED,
               f"id occurs {len(occs)} times in the layout (duplicated)",
               occs)
        return decision
    problems = []
    if room_known and not any(occurrence_in_room(o, room, rooms_by_id)
                              for _, o in occs):
        if all(o["assigned_room"] is None for _, o in occs):
            # Facade/site dressing legitimately sits outside every declared
            # room rect; rectangles cannot decide its ownership.
            finish(UNVERIFIABLE, "exists, but outside every declared room "
                   "rect (likely exterior/facade or site dressing); room "
                   "membership is not decidable from room rectangles", occs)
            flags.append("outside every declared room rect")
            return decision
        problems.append(
            f"assigned outside {room} "
            f"(currently: {sorted({o['assigned_room'] for _, o in occs})})")
    for _, o in occs:
        problems.extend(check_expected(decision, o, pos_tol, yaw_tol))
    if problems:
        finish(CONTRADICTED, "; ".join(problems), occs)
    else:
        finish(SATISFIED, "present"
               + (f" in {room}" if room_known else "")
               + "; no supplied invariant contradicted", occs)
    return decision


def verdict_outcome_class(verdict):
    """What a verdict asserts about the OBJECT ID it names.

    REMOVE / KEEP ABSENT assert the id is gone; REPLACE also asserts the old
    id is gone.  KEEP / ADD / MOVE / REPAIR all assert the id is present.
    Decisions in the same class are compatible restatements, not conflicts.
    """
    return ("absence" if verdict in ("REMOVE", "KEEP ABSENT", "REPLACE")
            else "presence")


def find_conflicts(decisions):
    """Cross-checkpoint conflicts (presence vs absence of one object) and
    compatible duplicates.  No row is ever silently preferred."""
    by_object = defaultdict(list)
    for d in decisions:
        if d["object"] and d["object_form"] in ("literal", "range"):
            by_object[d["object"]].append(d)
    conflicts, duplicates = [], []
    for obj in sorted(by_object):
        group = by_object[obj]
        verdicts = sorted({d["verdict"] for d in group})
        classes = sorted({verdict_outcome_class(v) for v in verdicts})
        sources = sorted({(d["source"]["path"], d["source"]["line"])
                          for d in group})
        if len(classes) > 1:
            conflicts.append({
                "object": obj, "verdicts": verdicts,
                "sources": [f"{p}:{ln}" for p, ln in sources],
                "note": "one checkpoint asserts presence, another absence; "
                        "no row is treated as authoritative — resolve in the "
                        "checkpoints"})
            for d in group:
                d.setdefault("flags", []).append(
                    f"conflicts with other verdict(s) {verdicts}")
        elif len(sources) > 1:
            duplicates.append({
                "object": obj, "verdicts": verdicts,
                "sources": [f"{p}:{ln}" for p, ln in sources]})
    return conflicts, duplicates


# ---------------------------------------------------------------------------
# Report emission
# ---------------------------------------------------------------------------

def decision_sort_key(d):
    return (d["room"] or "~", d["object"] or "~", d["verdict"],
            d["source"]["path"], d["source"]["line"])


def build_report(decisions, malformed, doc_reports, conflicts, duplicates,
                 provenance, layout_path, args_echo):
    counts = {s: 0 for s in (SATISFIED, OPEN, CONTRADICTED, UNVERIFIABLE)}
    for d in decisions:
        counts[d["status"]] += 1
    counts["MALFORMED"] = len(malformed)
    by_room = defaultdict(list)
    for d in sorted(decisions, key=decision_sort_key):
        by_room[d["room"] or "(room unresolved)"].append(d)
    runtime_deps = sorted({d["object"] for d in decisions
                           if d["object"] and any(
                               "runtime-only" in f for f in d.get("flags", []))})
    actions = [d for d in sorted(decisions, key=decision_sort_key)
               if d["status"] in (OPEN, CONTRADICTED)]
    return {
        "reconciler": {
            "source_layout": str(layout_path).replace("\\", "/"),
            "arguments": args_echo,
            "semantics": "SATISFIED means only that layout JSON does not "
                         "contradict the decision's checkable facts; it never "
                         "proves visual, historical, interaction or mesh "
                         "correctness.",
        },
        "summary": counts,
        "documents": doc_reports,
        "provenance": provenance,
        "decisions_by_room": {room: rows for room, rows in
                              sorted(by_room.items())},
        "conflicts": conflicts,
        "duplicates": duplicates,
        "malformed_rows": sorted(malformed, key=lambda m: (m["path"],
                                                           m["line"])),
        "runtime_only_dependencies": runtime_deps,
        "next_reconstruction_actions": [
            {"room": d["room"], "object": d["object"],
             "verdict": d["verdict"], "status": d["status"],
             "reason": d["reason"],
             "source": f"{d['source']['path']}:{d['source']['line']}"}
            for d in actions],
    }


def report_markdown(report):
    s = report["summary"]
    lines = ["# Room checkpoint reconciliation", "",
             f"Layout: `{report['reconciler']['source_layout']}` (read-only).",
             f"> {report['reconciler']['semantics']}", "",
             "## Summary", "",
             f"- SATISFIED: {s['SATISFIED']}",
             f"- OPEN: {s['OPEN']}",
             f"- CONTRADICTED: {s['CONTRADICTED']}",
             f"- UNVERIFIABLE: {s['UNVERIFIABLE']}",
             f"- MALFORMED rows: {s['MALFORMED']}", "",
             "## Checkpoint documents", ""]
    for doc in report["documents"]:
        lines.append(f"- `{doc['path']}` ({doc['kind']}): "
                     f"{doc['verdict_tables']} verdict table(s), "
                     f"{doc['rows_parsed']} row(s), {doc['decisions']} "
                     f"decision(s), {doc['malformed_rows']} malformed")
        if doc["note"]:
            lines.append(f"  - {doc['note']}")
        prov = report["provenance"].get(doc["path"])
        if prov:
            if prov["commit"]:
                lines.append(f"  - last touched in `{prov['commit'][:12]}`; "
                             f"layout regenerated "
                             f"{prov['layout_commits_since']} time(s) since")
            else:
                lines.append("  - base commit unknown (git unavailable or "
                             "file untracked)")
    lines += ["", "## Status by room", ""]
    for room, rows in report["decisions_by_room"].items():
        lines += [f"### {room}", "",
                  "| Object | Verdict | Status | Reason | Source |",
                  "|---|---|---|---|---|"]
        for d in rows:
            obj = f"`{d['object']}`" if d["object"] else "(no id)"
            src = f"{d['source']['path']}:{d['source']['line']}"
            reason = d["reason"].replace("|", "\\|")
            lines.append(f"| {obj} | {d['verdict']} | **{d['status']}** | "
                         f"{reason} | {src} |")
        flagged = [d for d in rows if d.get("flags")]
        if flagged:
            lines.append("")
            for d in flagged:
                for f in d["flags"]:
                    lines.append(f"- `{d['object'] or '(no id)'}`: {f}")
        lines.append("")
    if report["conflicts"]:
        lines += ["## Conflicting decisions", ""]
        for c in report["conflicts"]:
            lines.append(f"- `{c['object']}`: verdicts {c['verdicts']} from "
                         f"{', '.join(c['sources'])} — {c['note']}")
        lines.append("")
    if report["duplicates"]:
        lines += ["## Duplicate (compatible) decisions", ""]
        for c in report["duplicates"]:
            lines.append(f"- `{c['object']}` {'/'.join(c['verdicts'])} "
                         f"appears in {', '.join(c['sources'])}")
        lines.append("")
    if report["malformed_rows"]:
        lines += ["## Malformed rows", ""]
        for m in report["malformed_rows"]:
            lines.append(f"- `{m['path']}:{m['line']}`: {m['problem']}")
            lines.append(f"  - quoted: `{m['quote'][:160]}`")
        lines.append("")
    if report["runtime_only_dependencies"]:
        lines += ["## Runtime-only dependencies (layout JSON cannot verify)",
                  ""]
        for rid in report["runtime_only_dependencies"]:
            lines.append(f"- `{rid}`")
        lines.append("")
    lines += ["## Next reconstruction actions", "",
              "Open or contradicted decisions only; this section adds no new "
              "design advice.", ""]
    if report["next_reconstruction_actions"]:
        for a in report["next_reconstruction_actions"]:
            lines.append(f"- [{a['status']}] {a['room'] or '(room?)'} "
                         f"`{a['object'] or '(no id)'}` {a['verdict']}: "
                         f"{a['reason']} ({a['source']})")
    else:
        lines.append("- none: every parsed decision is satisfied or "
                     "explicitly unverifiable")
    return "\n".join(lines) + "\n"


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def reconcile(layout_path, checkpoints_dir, tables=None, use_git=True,
              pos_tol=DEFAULT_POS_TOL, yaw_tol=DEFAULT_YAW_TOL,
              runtime_scan_root=ROOT):
    layout = json.loads(Path(layout_path).read_text(encoding="utf-8"))
    tables = tables if tables is not None else wb.load_footprint_tables()
    index, rooms_by_id, kind_census = build_object_index(layout, tables)
    docs, manifests = discover_checkpoints(checkpoints_dir)
    runtime_scan = build_runtime_evidence_scanner(runtime_scan_root)

    decisions, malformed, doc_reports = [], [], []
    for path in docs:
        d, m, rep = parse_checkpoint_markdown(path, set(rooms_by_id))
        rep["decisions"] = len(d)
        decisions += d
        malformed += m
        doc_reports.append(rep)
    for path in manifests:
        d, m, rep = parse_manifest(path)
        decisions += d
        malformed += m
        doc_reports.append(rep)

    for d in decisions:
        classify(d, index, rooms_by_id, runtime_scan, pos_tol, yaw_tol,
                 kind_census)
    conflicts, duplicates = find_conflicts(decisions)
    provenance = git_provenance([str(r["path"]) for r in doc_reports],
                                layout_path) if use_git else {}
    args_echo = {"checkpoints": str(checkpoints_dir).replace("\\", "/"),
                 "pos_tolerance_m": pos_tol, "yaw_tolerance_deg": yaw_tol,
                 "git_provenance": bool(use_git)}
    report = build_report(decisions, malformed, doc_reports, conflicts,
                          duplicates, provenance, layout_path, args_echo)
    return report


def exit_code_for(report):
    code = 0
    if report["summary"]["CONTRADICTED"] or report["conflicts"]:
        code |= 1
    if report["summary"]["MALFORMED"]:
        code |= 4
    return code


def main(argv=None):
    parser = argparse.ArgumentParser(
        description="Read-only reconciliation of room checkpoint decisions "
                    "against the current building layout")
    parser.add_argument("--layout", type=Path, default=DEFAULT_LAYOUT)
    parser.add_argument("--checkpoints", type=Path,
                        default=DEFAULT_CHECKPOINTS,
                        help="directory scanned for ORISON_*CHECKPOINT*.md "
                             "and *.decisions.json (default design/)")
    parser.add_argument("--output", type=Path, required=True,
                        help="explicit output directory (never defaults into "
                             "tracked directories)")
    parser.add_argument("--force", action="store_true",
                        help="overwrite existing generated reports")
    parser.add_argument("--no-git", action="store_true",
                        help="skip git provenance lookups (deterministic "
                             "output independent of repository state)")
    parser.add_argument("--pos-tolerance", type=float,
                        default=DEFAULT_POS_TOL, metavar="METRES")
    parser.add_argument("--yaw-tolerance", type=float,
                        default=DEFAULT_YAW_TOL, metavar="DEGREES")
    args = parser.parse_args(argv)

    args.output.mkdir(parents=True, exist_ok=True)
    targets = [args.output / "room_checkpoint_status.json",
               args.output / "room_checkpoint_status.md"]
    try:
        wb.preflight_overwrite(targets, args.force)
    except FileExistsError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 3
    try:
        report = reconcile(args.layout, args.checkpoints,
                           use_git=not args.no_git,
                           pos_tol=args.pos_tolerance,
                           yaw_tol=args.yaw_tolerance)
    except Exception as exc:                # noqa: BLE001 - stable exit code
        print(f"internal failure: {type(exc).__name__}: {exc}",
              file=sys.stderr)
        return 70
    targets[0].write_text(json.dumps(report, indent=1, sort_keys=True) + "\n",
                          encoding="utf-8")
    targets[1].write_text(report_markdown(report), encoding="utf-8")
    for t in targets:
        print(t)
    code = exit_code_for(report)
    s = report["summary"]
    print(f"satisfied={s['SATISFIED']} open={s['OPEN']} "
          f"contradicted={s['CONTRADICTED']} unverifiable={s['UNVERIFIABLE']} "
          f"malformed={s['MALFORMED']} conflicts={len(report['conflicts'])} "
          f"-> exit {code}")
    return code


if __name__ == "__main__":
    sys.exit(main())
